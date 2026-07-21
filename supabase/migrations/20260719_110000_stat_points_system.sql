-- ============================================================================
-- STAT POINTS SİSTEMİ
-- Level atlayınca +3 stat puanı; oyuncu Saldırı/Savunma/Şans'a manuel dağıtır.
-- Sınıf bazlı otomatik büyüme (PLAN_11) aynen devam eder — puanlar üstüne gelir.
-- ============================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS stat_points INTEGER NOT NULL DEFAULT 0;

-- ── Level trigger'ı: her level +3 stat puanı ────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_xp_level_progression()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_level integer;
  v_new_level integer;
  v_levels_gained integer;
  v_next_level_total_xp integer;
  v_class_key text;
  v_attack_gain integer := 0;
  v_defense_gain integer := 0;
  v_health_gain integer := 0;
  v_luck_gain integer := 0;
  v_level_cap constant integer := 70;
BEGIN
  IF COALESCE(NEW.xp, 0) <= COALESCE(OLD.xp, 0) THEN
    RETURN NEW;
  END IF;

  v_old_level := GREATEST(COALESCE(OLD.level, 1), 1);
  v_new_level := v_old_level;

  IF v_old_level >= v_level_cap THEN
    NEW.level := v_old_level;
    RETURN NEW;
  END IF;

  LOOP
    EXIT WHEN v_new_level >= v_level_cap;
    v_next_level_total_xp := public.total_xp_for_level(v_new_level + 1);
    EXIT WHEN COALESCE(NEW.xp, 0) < v_next_level_total_xp;
    v_new_level := v_new_level + 1;
  END LOOP;

  v_levels_gained := v_new_level - v_old_level;

  IF v_levels_gained <= 0 THEN
    RETURN NEW;
  END IF;

  NEW.level := v_new_level;

  -- Her level 3 dağıtılabilir stat puanı verir (sınıftan bağımsız).
  NEW.stat_points := COALESCE(NEW.stat_points, 0) + (3 * v_levels_gained);

  v_class_key := lower(COALESCE(NEW.character_class, OLD.character_class, ''));
  IF v_class_key <> '' THEN
    SELECT
      COALESCE(attack_per_level, 0),
      COALESCE(defense_per_level, 0),
      COALESCE(health_per_level, 0),
      COALESCE(luck_per_level, 0)
    INTO
      v_attack_gain,
      v_defense_gain,
      v_health_gain,
      v_luck_gain
    FROM public.character_classes
    WHERE id = v_class_key
    LIMIT 1;

    IF NOT FOUND THEN
      CASE v_class_key
        WHEN 'warrior' THEN
          v_attack_gain := 3; v_defense_gain := 2; v_health_gain := 15; v_luck_gain := 1;
        WHEN 'alchemist' THEN
          v_attack_gain := 1; v_defense_gain := 2; v_health_gain := 20; v_luck_gain := 2;
        WHEN 'shadow' THEN
          v_attack_gain := 2; v_defense_gain := 1; v_health_gain := 12; v_luck_gain := 3;
        ELSE
          v_attack_gain := 0; v_defense_gain := 0; v_health_gain := 0; v_luck_gain := 0;
      END CASE;
    END IF;

    NEW.attack := COALESCE(NEW.attack, 0) + (v_attack_gain * v_levels_gained);
    NEW.defense := COALESCE(NEW.defense, 0) + (v_defense_gain * v_levels_gained);
    NEW.max_health := COALESCE(NEW.max_health, 0) + (v_health_gain * v_levels_gained);
    NEW.health := COALESCE(NEW.health, 0) + (v_health_gain * v_levels_gained);
    NEW.luck := COALESCE(NEW.luck, 0) + (v_luck_gain * v_levels_gained);
  END IF;

  RETURN NEW;
END;
$$;

-- ── Backfill: mevcut oyunculara geçmiş levelleri için puan ver ─────────────
UPDATE public.users
SET stat_points = GREATEST(level - 1, 0) * 3
WHERE stat_points = 0
  AND level > 1;

-- ── Dağıtım RPC ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.allocate_stat_points(
  p_attack INTEGER DEFAULT 0,
  p_defense INTEGER DEFAULT 0,
  p_luck INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_id UUID;
  v_total INTEGER;
  v_available INTEGER;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_attack < 0 OR p_defense < 0 OR p_luck < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid allocation');
  END IF;

  v_total := p_attack + p_defense + p_luck;
  IF v_total <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Nothing to allocate');
  END IF;

  SELECT stat_points INTO v_available
  FROM public.users
  WHERE auth_id = v_auth_id
  FOR UPDATE;

  IF v_available IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_available < v_total THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient stat points');
  END IF;

  UPDATE public.users
  SET attack = COALESCE(attack, 0) + p_attack,
      defense = COALESCE(defense, 0) + p_defense,
      luck = COALESCE(luck, 0) + p_luck,
      stat_points = stat_points - v_total,
      updated_at = NOW()
  WHERE auth_id = v_auth_id;

  RETURN jsonb_build_object(
    'success', true,
    'spent', v_total,
    'remaining', v_available - v_total
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.allocate_stat_points(INTEGER, INTEGER, INTEGER) TO authenticated;
