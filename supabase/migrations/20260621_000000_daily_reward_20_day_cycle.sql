-- =========================================================================================
-- MIGRATION: Daily Reward — extend to 20-day cycle with epic milestones
-- =========================================================================================

BEGIN;

-- 1. Widen cycle constraints (7 → 20)
ALTER TABLE public.daily_reward_config
  DROP CONSTRAINT IF EXISTS daily_reward_config_cycle_day_check;

ALTER TABLE public.daily_reward_config
  ADD CONSTRAINT daily_reward_config_cycle_day_check
  CHECK (cycle_day BETWEEN 1 AND 20);

ALTER TABLE public.daily_reward_claims
  DROP CONSTRAINT IF EXISTS daily_reward_claims_cycle_day_check;

ALTER TABLE public.daily_reward_claims
  ADD CONSTRAINT daily_reward_claims_cycle_day_check
  CHECK (cycle_day BETWEEN 1 AND 20);

-- 2. Seed 20-day reward track (escalating + epic spikes on 7, 10, 14, 20)
INSERT INTO public.daily_reward_config (
  cycle_day, gold, gems, xp, energy, item_id, item_quantity, display_label, is_milestone, level_multiplier
) VALUES
  (1,  1000,  0,  50, 0, NULL,                  0, 'Hoş Geldin',        false, true),
  (2,  2000,  0, 100, 0, 'potion_energy_minor', 2, 'Enerji Desteği',    false, true),
  (3,  3000,  0, 150, 0, NULL,                  0, 'Güçlenme',          false, true),
  (4,  4500,  1, 200, 0, NULL,                  0, 'Elmas Günü',        false, true),
  (5,  6000,  1, 220, 0, 'scroll_upgrade_low',  1, 'Usta Yolu',         false, true),
  (6,  8000,  2, 250, 0, 'potion_energy_minor', 2, 'Azim',              false, true),
  (7,  15000, 5, 350, 0, 'box_weapon_common',   1, 'Hafta 1 Ödülü',     true,  true),
  (8,  7000,  2, 280, 0, NULL,                  0, 'Devam',             false, true),
  (9,  9000,  2, 300, 0, 'scroll_upgrade_low',  2, 'Yükseliş',          false, true),
  (10, 20000, 8, 400, 0, 'box_armor_rare',      1, 'Efsane Gün',        true,  true),
  (11, 10000, 3, 320, 0, 'potion_energy_minor', 3, 'Dayanıklılık',      false, true),
  (12, 12000, 3, 340, 0, NULL,                  0, 'Güç Patlaması',     false, true),
  (13, 14000, 4, 360, 0, 'scroll_upgrade_middle', 1, 'Usta Zanaatkar',  false, true),
  (14, 22000, 7, 450, 0, 'box_weapon_rare',     1, 'Orta Boss',         true,  true),
  (15, 16000, 4, 380, 0, 'potion_energy_major', 1, 'Büyük Enerji',      false, true),
  (16, 18000, 5, 400, 0, NULL,                  0, 'Son Viraj',         false, true),
  (17, 20000, 5, 420, 0, 'scroll_upgrade_middle', 2, 'Efsane Yol',      false, true),
  (18, 22000, 6, 440, 0, 'potion_energy_major', 2, 'Kritik Gün',        false, true),
  (19, 28000, 8, 480, 0, 'scroll_upgrade_high', 1, 'Neredeyse Orada',   false, true),
  (20, 50000, 20, 800, 0, 'box_weapon_legendary', 1, 'EFSANE ÖDÜL',     true,  true)
ON CONFLICT (cycle_day) DO UPDATE SET
  gold = EXCLUDED.gold,
  gems = EXCLUDED.gems,
  xp = EXCLUDED.xp,
  energy = EXCLUDED.energy,
  item_id = EXCLUDED.item_id,
  item_quantity = EXCLUDED.item_quantity,
  display_label = EXCLUDED.display_label,
  is_milestone = EXCLUDED.is_milestone,
  level_multiplier = EXCLUDED.level_multiplier;

-- 3. Max cycle helper (config-driven wrap)
CREATE OR REPLACE FUNCTION public.daily_reward_cycle_max()
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(MAX(cycle_day), 20) FROM public.daily_reward_config;
$$;

-- 4. Resolve state — wrap at cycle max (20)
CREATE OR REPLACE FUNCTION public.daily_reward_resolve_state(
  p_user_id UUID,
  p_today DATE
)
RETURNS TABLE (
  can_claim BOOLEAN,
  next_cycle_day INTEGER,
  streak_length INTEGER,
  claimed_today BOOLEAN,
  today_cycle_day INTEGER
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_last RECORD;
  v_cycle_max INTEGER;
BEGIN
  v_cycle_max := public.daily_reward_cycle_max();

  SELECT c.claim_date, c.cycle_day, c.streak_length
  INTO v_last
  FROM public.daily_reward_claims c
  WHERE c.user_id = p_user_id
  ORDER BY c.claim_date DESC
  LIMIT 1;

  claimed_today := (v_last.claim_date IS NOT NULL AND v_last.claim_date = p_today);

  IF claimed_today THEN
    can_claim := false;
    next_cycle_day := v_last.cycle_day;
    today_cycle_day := v_last.cycle_day;
    streak_length := v_last.streak_length;
    RETURN NEXT;
    RETURN;
  END IF;

  can_claim := true;

  IF v_last.claim_date IS NULL OR v_last.claim_date < (p_today - 1) THEN
    next_cycle_day := 1;
    today_cycle_day := 1;
    streak_length := 0;
    RETURN NEXT;
    RETURN;
  END IF;

  next_cycle_day := (v_last.cycle_day % v_cycle_max) + 1;
  today_cycle_day := next_cycle_day;
  streak_length := v_last.streak_length;
  RETURN NEXT;
END;
$$;

-- 5. Status RPC — include cycle_length
CREATE OR REPLACE FUNCTION public.get_daily_reward_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id UUID;
  v_today DATE;
  v_player RECORD;
  v_state RECORD;
  v_calendar JSONB := '[]'::jsonb;
  v_config RECORD;
  v_day_status TEXT;
  v_target_day INTEGER;
  v_grant JSONB;
  v_today_grant JSONB;
  v_next_reset TIMESTAMPTZ;
  v_cycle_max INTEGER;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_today := (now() AT TIME ZONE 'UTC')::date;
  v_next_reset := ((v_today + 1)::timestamp AT TIME ZONE 'UTC');
  v_cycle_max := public.daily_reward_cycle_max();

  SELECT level INTO v_player
  FROM public.users
  WHERE auth_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı profili bulunamadı.');
  END IF;

  SELECT * INTO v_state
  FROM public.daily_reward_resolve_state(v_user_id, v_today);

  v_target_day := CASE
    WHEN v_state.can_claim THEN v_state.next_cycle_day
    ELSE v_state.today_cycle_day
  END;

  FOR v_config IN
    SELECT * FROM public.daily_reward_config ORDER BY cycle_day
  LOOP
    IF v_config.cycle_day < v_target_day THEN
      v_day_status := 'completed';
    ELSIF v_config.cycle_day = v_target_day THEN
      v_day_status := CASE WHEN v_state.can_claim THEN 'today' ELSE 'completed' END;
    ELSE
      v_day_status := 'locked';
    END IF;

    v_grant := public.daily_reward_build_grant(v_config.cycle_day, v_player.level);

    v_calendar := v_calendar || jsonb_build_array(
      jsonb_build_object(
        'cycle_day', v_config.cycle_day,
        'status', v_day_status,
        'reward', v_grant
      )
    );
  END LOOP;

  v_today_grant := public.daily_reward_build_grant(v_target_day, v_player.level);

  RETURN jsonb_build_object(
    'success', true,
    'can_claim', v_state.can_claim,
    'cycle_day', v_target_day,
    'cycle_length', v_cycle_max,
    'streak_length', v_state.streak_length,
    'claimed_today', v_state.claimed_today,
    'today_reward', v_today_grant,
    'week_calendar', v_calendar,
    'next_reset_at', v_next_reset,
    'timezone', 'UTC'
  );
END;
$$;

COMMIT;
