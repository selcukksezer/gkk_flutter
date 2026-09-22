-- Stat inflation residual HP fix (RAPOR 20260731 §10 deferred).
-- 1) Further cut mythic gear HP (×0.50 on already-compressed catalog)
-- 2) Compress legendary gear HP (×0.40) — was skipped in phase2a → tankier than mythic
-- 3) Health potions heal % of max_health (scale-invariant)
-- 4) Mirror heal_amount → health_restore for client labels
-- 5) Resync equip_bonus_* + power

BEGIN;

-- Catalog HP cuts
UPDATE public.items
SET health = GREATEST(0, ROUND(COALESCE(health, 0) * 0.50)::integer)
WHERE lower(COALESCE(rarity, '')) = 'mythic';

UPDATE public.items
SET health = GREATEST(0, ROUND(COALESCE(health, 0) * 0.40)::integer)
WHERE lower(COALESCE(rarity, '')) = 'legendary';

-- Client reads health_restore; server historically used heal_amount.
UPDATE public.items
SET
  health_restore = GREATEST(COALESCE(health_restore, 0), COALESCE(heal_amount, 0)),
  potion_type = COALESCE(NULLIF(potion_type, ''), 'health')
WHERE COALESCE(heal_amount, 0) > 0
   OR id IN (
     'potion_health_minor',
     'potion_health_major',
     'potion_health_supreme',
     'han_item_restoration'
   );

-- % of max_health heals (tolerance efficiency still applies).
CREATE OR REPLACE FUNCTION public.use_potion(
  p_row_id uuid,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_new_tolerance INT;
  v_overdose BOOLEAN := false;
  v_hard_force_od BOOLEAN := false;
  v_efficiency NUMERIC;
  v_overdose_chance NUMERIC;
  v_roll NUMERIC;
  v_hospital_minutes INT;
  v_heal_amount INT;
  v_heal_pct NUMERIC;
  v_energy_gain INT;
  v_monument_level INT := 0;
  v_saved_from_overdose BOOLEAN := false;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_user.guild_id;
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR lower(COALESCE(v_item.type, '')) NOT IN ('potion', 'consumable') THEN
    RETURN jsonb_build_object('error', 'Geçersiz iksir');
  END IF;

  v_new_tolerance := COALESCE(v_user.tolerance, 0) + COALESCE(v_item.tolerance_increase, 0);
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_new_tolerance := COALESCE(v_user.tolerance, 0)
      + floor(COALESCE(v_item.tolerance_increase, 0) * 0.75);
  END IF;
  v_new_tolerance := GREATEST(0, LEAST(v_new_tolerance, 100));

  v_efficiency := CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 20 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.85
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 0.65
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 0.45
    ELSE 0.25
  END;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_efficiency := LEAST(1.0, v_efficiency * 1.30);
  END IF;

  v_hard_force_od :=
    lower(COALESCE(v_item.type, '')) = 'potion'
    AND COALESCE(v_item.tolerance_increase, 0) >= 0
    AND COALESCE(v_item.id, '') NOT LIKE 'detox%'
    AND (
      COALESCE(v_user.tolerance, 0) >= 100
      OR v_new_tolerance >= 100
    );

  IF v_hard_force_od THEN
    v_overdose := true;
  ELSE
    v_overdose_chance := COALESCE(v_item.overdose_risk, 0) * CASE
      WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.0
      WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 1.0
      WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 2.0
      WHEN COALESCE(v_user.tolerance, 0) <= 90 THEN 4.0
      ELSE 8.0
    END;

    IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
      v_overdose_chance := v_overdose_chance * 0.80;
    END IF;

    IF v_monument_level >= 20 THEN
      v_overdose_chance := v_overdose_chance * 0.90;
    END IF;

    v_roll := random();
    IF v_roll <= v_overdose_chance THEN
      v_overdose := true;

      IF v_monument_level >= 80 AND (
        v_user.last_overdose_save_at IS NULL OR
        v_user.last_overdose_save_at::date < CURRENT_DATE
      ) THEN
        v_overdose := false;
        v_saved_from_overdose := true;
      END IF;
    END IF;
  END IF;

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  PERFORM public.bp_trigger_potion_usage(p_user_id);

  IF v_overdose THEN
    v_hospital_minutes := 30 + (COALESCE(v_user.tolerance, 0) * 2);

    UPDATE public.users
    SET addiction_level = LEAST(COALESCE(addiction_level, 0) + 1, 10),
        tolerance = LEAST(v_new_tolerance + 10, 100),
        hospital_until = now() + (v_hospital_minutes || ' minutes')::interval,
        hospital_reason = 'Overdose',
        last_potion_used_at = now()
    WHERE auth_id = p_user_id;

    INSERT INTO public.tolerance_log (
      user_id, event_type, item_id,
      tolerance_before, tolerance_after,
      addiction_before, addiction_after
    )
    VALUES (
      p_user_id, 'overdose', v_inv.item_id,
      COALESCE(v_user.tolerance, 0), LEAST(v_new_tolerance + 10, 100),
      COALESCE(v_user.addiction_level, 0), LEAST(COALESCE(v_user.addiction_level, 0) + 1, 10)
    );

    RETURN jsonb_build_object(
      'success', true,
      'overdose', true,
      'hospital_minutes', v_hospital_minutes,
      'hard_force', v_hard_force_od,
      'efficiency', 0
    );
  END IF;

  -- Scale-invariant health potions (% of max_health).
  v_heal_pct := CASE lower(COALESCE(v_item.id, ''))
    WHEN 'potion_health_minor' THEN 0.25
    WHEN 'potion_health_major' THEN 0.50
    WHEN 'potion_health_supreme' THEN 1.00
    WHEN 'han_item_restoration' THEN 0.40
    ELSE NULL
  END;

  IF v_heal_pct IS NOT NULL THEN
    v_heal_amount := floor(GREATEST(1, COALESCE(v_user.max_health, 1)) * v_heal_pct * v_efficiency);
  ELSE
    v_heal_amount := floor(COALESCE(v_item.heal_amount, v_item.health_restore, 0) * v_efficiency);
  END IF;

  v_energy_gain := floor(COALESCE(v_item.energy_restore, 0) * v_efficiency);

  IF lower(COALESCE(v_item.potion_type, '')) = 'health' AND v_heal_amount = 0 AND v_heal_pct IS NULL THEN
    v_heal_amount := floor(COALESCE(v_item.heal_amount, v_item.health_restore, 50) * v_efficiency);
  END IF;

  IF lower(COALESCE(v_item.potion_type, '')) = 'energy' AND v_energy_gain = 0 THEN
    v_energy_gain := floor(COALESCE(v_item.energy_restore, 20) * v_efficiency);
  END IF;

  UPDATE public.users
  SET tolerance = v_new_tolerance,
      last_potion_used_at = now(),
      last_overdose_save_at = CASE WHEN v_saved_from_overdose THEN now() ELSE last_overdose_save_at END,
      energy = LEAST(max_energy, energy + v_energy_gain),
      health = LEAST(max_health, health + v_heal_amount),
      health_last_updated = CASE
        WHEN v_heal_amount > 0 THEN now()
        ELSE health_last_updated
      END,
      updated_at = now()
  WHERE auth_id = p_user_id;

  INSERT INTO public.tolerance_log (
    user_id, event_type, item_id,
    tolerance_before, tolerance_after,
    addiction_before, addiction_after
  )
  VALUES (
    p_user_id, 'potion_use', v_inv.item_id,
    COALESCE(v_user.tolerance, 0), v_new_tolerance,
    COALESCE(v_user.addiction_level, 0), COALESCE(v_user.addiction_level, 0)
  );

  RETURN jsonb_build_object(
    'success', true,
    'overdose', false,
    'saved_from_overdose', v_saved_from_overdose,
    'efficiency', v_efficiency,
    'new_tolerance', v_new_tolerance,
    'heal_amount', v_heal_amount,
    'heal_pct', v_heal_pct,
    'energy_restored', v_energy_gain
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.use_potion(UUID, UUID) TO authenticated;

-- Resync equip HP/ATK/DEF/luck + power after catalog cut
WITH eq AS (
  SELECT
    i.user_id,
    COALESCE(SUM(floor(COALESCE(it.attack, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::integer AS eq_atk,
    COALESCE(SUM(floor(COALESCE(it.defense, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::integer AS eq_def,
    COALESCE(SUM(floor(COALESCE(it.health, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::integer AS eq_hp,
    COALESCE(SUM(floor(COALESCE(it.luck, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::integer AS eq_luck
  FROM public.inventory i
  JOIN public.items it ON it.id = i.item_id
  WHERE i.is_equipped = TRUE
  GROUP BY i.user_id
),
base AS (
  SELECT
    u.auth_id,
    GREATEST(0, COALESCE(u.attack, 0) - COALESCE(u.equip_bonus_attack, 0)) AS base_atk,
    GREATEST(0, COALESCE(u.defense, 0) - COALESCE(u.equip_bonus_defense, 0)) AS base_def,
    GREATEST(1, COALESCE(u.max_health, 100) - COALESCE(u.equip_bonus_health, 0)) AS base_hp,
    GREATEST(0, COALESCE(u.luck, 0)) AS base_luck,
    COALESCE(u.health, 0) AS cur_health,
    COALESCE(eq.eq_atk, 0) AS eq_atk,
    COALESCE(eq.eq_def, 0) AS eq_def,
    COALESCE(eq.eq_hp, 0) AS eq_hp,
    COALESCE(eq.eq_luck, 0) AS eq_luck
  FROM public.users u
  LEFT JOIN eq ON eq.user_id = u.auth_id
  WHERE eq.user_id IS NOT NULL
     OR COALESCE(u.equip_bonus_luck, 0) > 0
     OR COALESCE(u.equip_bonus_attack, 0) > 0
     OR COALESCE(u.equip_bonus_defense, 0) > 0
     OR COALESCE(u.equip_bonus_health, 0) > 0
)
UPDATE public.users u
SET
  attack = b.base_atk + b.eq_atk,
  defense = b.base_def + b.eq_def,
  max_health = b.base_hp + b.eq_hp,
  luck = b.base_luck,
  health = LEAST(GREATEST(1, b.cur_health), b.base_hp + b.eq_hp),
  equip_bonus_attack = b.eq_atk,
  equip_bonus_defense = b.eq_def,
  equip_bonus_health = b.eq_hp,
  equip_bonus_luck = b.eq_luck,
  updated_at = NOW()
FROM base b
WHERE u.auth_id = b.auth_id;

UPDATE public.users u
SET
  power = public.calculate_user_total_power(u.auth_id)::integer,
  updated_at = NOW()
WHERE EXISTS (
  SELECT 1 FROM public.inventory i
  WHERE i.user_id = u.auth_id AND i.is_equipped = true
)
OR COALESCE(u.equip_bonus_luck, 0) > 0
OR COALESCE(u.equip_bonus_attack, 0) > 0
OR COALESCE(u.equip_bonus_defense, 0) > 0
OR COALESCE(u.equip_bonus_health, 0) > 0;

COMMIT;
