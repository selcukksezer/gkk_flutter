-- =========================================================================================
-- MIGRATION: Daily Reward System
-- =========================================================================================
-- Server-authoritative 7-day login reward cycle with UTC day boundaries.
-- Hard streak reset on missed days. All grants via claim_daily_reward() RPC.
-- =========================================================================================

BEGIN;

-- 1. Config table (server-owned reward amounts)
CREATE TABLE IF NOT EXISTS public.daily_reward_config (
  cycle_day         INTEGER PRIMARY KEY CHECK (cycle_day BETWEEN 1 AND 7),
  gold              INTEGER NOT NULL DEFAULT 0 CHECK (gold >= 0),
  gems              INTEGER NOT NULL DEFAULT 0 CHECK (gems >= 0),
  xp                INTEGER NOT NULL DEFAULT 0 CHECK (xp >= 0),
  energy            INTEGER NOT NULL DEFAULT 0 CHECK (energy >= 0),
  item_id           TEXT REFERENCES public.items(id) ON DELETE SET NULL,
  item_quantity     INTEGER NOT NULL DEFAULT 0 CHECK (item_quantity >= 0),
  display_label     TEXT NOT NULL DEFAULT '',
  is_milestone      BOOLEAN NOT NULL DEFAULT false,
  level_multiplier  BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Immutable claim log (anti-double-claim via PK)
CREATE TABLE IF NOT EXISTS public.daily_reward_claims (
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  claim_date        DATE NOT NULL,
  cycle_day         INTEGER NOT NULL CHECK (cycle_day BETWEEN 1 AND 7),
  streak_length     INTEGER NOT NULL DEFAULT 1 CHECK (streak_length >= 1),
  rewards_granted   JSONB NOT NULL DEFAULT '{}'::jsonb,
  claimed_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, claim_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_reward_claims_user_claimed_at
  ON public.daily_reward_claims (user_id, claimed_at DESC);

-- 3. Seed rewards (economy-calibrated)
INSERT INTO public.daily_reward_config (
  cycle_day, gold, gems, xp, energy, item_id, item_quantity, display_label, is_milestone, level_multiplier
) VALUES
  (1, 1000,  0,  50, 0, NULL,                 0, 'Hoş Geldin',       false, true),
  (2, 2000,  0, 100, 0, 'potion_energy_minor', 2, 'Enerji Desteği',   false, true),
  (3, 3500,  0, 150, 0, NULL,                 0, 'Güçlenme',         false, true),
  (4, 5000,  1, 200, 0, NULL,                 0, 'Elmas Günü',       false, true),
  (5, 8000,  2, 250, 0, 'scroll_upgrade_low',  2, 'Usta Yolu',        false, true),
  (6, 12000, 3, 300, 0, 'potion_energy_minor', 3, 'Son Adım',         false, true),
  (7, 25000, 10, 500, 0, 'box_weapon_common',  1, 'Haftalık Jackpot', true,  true)
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

-- 4. RLS
ALTER TABLE public.daily_reward_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_reward_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS daily_reward_config_select ON public.daily_reward_config;
CREATE POLICY daily_reward_config_select ON public.daily_reward_config
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS daily_reward_claims_select_own ON public.daily_reward_claims;
CREATE POLICY daily_reward_claims_select_own ON public.daily_reward_claims
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- 5. Helper: scale gold/xp by player level
CREATE OR REPLACE FUNCTION public.daily_reward_scaled_amount(
  p_base INTEGER,
  p_level INTEGER,
  p_apply_multiplier BOOLEAN
)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN NOT p_apply_multiplier OR p_base <= 0 THEN GREATEST(p_base, 0)
    ELSE GREATEST(
      FLOOR(p_base * (1.0 + LEAST(GREATEST(p_level, 1), 70) * 0.02))::INTEGER,
      0
    )
  END;
$$;

-- 6. Helper: build reward JSON from config row + level
CREATE OR REPLACE FUNCTION public.daily_reward_build_grant(
  p_cycle_day INTEGER,
  p_level INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_config public.daily_reward_config%ROWTYPE;
  v_gold INTEGER;
  v_xp INTEGER;
  v_item_name TEXT;
BEGIN
  SELECT * INTO v_config
  FROM public.daily_reward_config
  WHERE cycle_day = p_cycle_day;

  IF NOT FOUND THEN
    RETURN '{}'::jsonb;
  END IF;

  v_gold := public.daily_reward_scaled_amount(v_config.gold, p_level, v_config.level_multiplier);
  v_xp := public.daily_reward_scaled_amount(v_config.xp, p_level, v_config.level_multiplier);

  IF v_config.item_id IS NOT NULL THEN
    SELECT name INTO v_item_name FROM public.items WHERE id = v_config.item_id;
  END IF;

  RETURN jsonb_build_object(
    'cycle_day', v_config.cycle_day,
    'display_label', v_config.display_label,
    'is_milestone', v_config.is_milestone,
    'gold', v_gold,
    'gems', v_config.gems,
    'xp', v_xp,
    'energy', v_config.energy,
    'item_id', v_config.item_id,
    'item_name', v_item_name,
    'item_quantity', CASE WHEN v_config.item_id IS NULL THEN 0 ELSE v_config.item_quantity END
  );
END;
$$;

-- 7. Helper: resolve cycle state for a user
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
BEGIN
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

  -- Last claim was yesterday — continue streak
  next_cycle_day := (v_last.cycle_day % 7) + 1;
  today_cycle_day := next_cycle_day;
  streak_length := v_last.streak_length;
  RETURN NEXT;
END;
$$;

-- 8. Status RPC (read-only)
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
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_today := (now() AT TIME ZONE 'UTC')::date;
  v_next_reset := ((v_today + 1)::timestamp AT TIME ZONE 'UTC');

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
    'streak_length', CASE
      WHEN v_state.can_claim THEN v_state.streak_length
      ELSE v_state.streak_length
    END,
    'claimed_today', v_state.claimed_today,
    'today_reward', v_today_grant,
    'week_calendar', v_calendar,
    'next_reset_at', v_next_reset,
    'timezone', 'UTC'
  );
END;
$$;

-- 9. Claim RPC (write, secured)
CREATE OR REPLACE FUNCTION public.claim_daily_reward()
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
  v_config public.daily_reward_config%ROWTYPE;
  v_grant JSONB;
  v_gold INTEGER;
  v_xp INTEGER;
  v_energy INTEGER;
  v_new_streak INTEGER;
  v_add_result JSONB;
  v_rewards_granted JSONB;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_today := (now() AT TIME ZONE 'UTC')::date;

  SELECT * INTO v_player
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı profili bulunamadı.');
  END IF;

  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastanedeyken günlük ödül alınamaz.');
  END IF;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hapishanedeyken günlük ödül alınamaz.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.daily_reward_claims
    WHERE user_id = v_user_id AND claim_date = v_today
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bugünkü ödül zaten alındı.');
  END IF;

  SELECT * INTO v_state
  FROM public.daily_reward_resolve_state(v_user_id, v_today);

  IF NOT v_state.can_claim THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül alınamaz durumda.');
  END IF;

  SELECT * INTO v_config
  FROM public.daily_reward_config
  WHERE cycle_day = v_state.next_cycle_day;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül konfigürasyonu bulunamadı.');
  END IF;

  v_grant := public.daily_reward_build_grant(v_state.next_cycle_day, v_player.level);
  v_gold := (v_grant->>'gold')::INTEGER;
  v_xp := (v_grant->>'xp')::INTEGER;
  v_energy := (v_grant->>'energy')::INTEGER;

  v_new_streak := CASE
    WHEN v_state.next_cycle_day = 1 AND (v_state.streak_length = 0) THEN 1
    ELSE v_state.streak_length + 1
  END;

  -- Grant item first so a full inventory rolls back the entire claim.
  IF v_config.item_id IS NOT NULL AND v_config.item_quantity > 0 THEN
    v_add_result := public.add_inventory_item_v2(
      jsonb_build_object(
        'item_id', v_config.item_id,
        'quantity', v_config.item_quantity,
        'allow_stack', true
      ),
      NULL
    );

    IF COALESCE((v_add_result->>'success')::BOOLEAN, FALSE) = FALSE THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Envanter dolu. Ödül verilemedi: ' || COALESCE(v_add_result->>'error', 'unknown')
      );
    END IF;
  END IF;

  v_rewards_granted := v_grant;

  -- Grant currencies
  UPDATE public.users
  SET
    gold = COALESCE(gold, 0) + v_gold,
    gems = COALESCE(gems, 0) + (v_grant->>'gems')::INTEGER,
    xp = COALESCE(xp, 0) + v_xp,
    energy = CASE
      WHEN v_energy > 0 THEN LEAST(COALESCE(max_energy, 100), COALESCE(energy, 0) + v_energy)
      ELSE energy
    END,
    updated_at = now()
  WHERE auth_id = v_user_id;

  INSERT INTO public.daily_reward_claims (
    user_id, claim_date, cycle_day, streak_length, rewards_granted
  ) VALUES (
    v_user_id, v_today, v_state.next_cycle_day, v_new_streak, v_rewards_granted
  );

  SELECT gold, gems, xp, energy
  INTO v_player.gold, v_player.gems, v_player.xp, v_player.energy
  FROM public.users
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Günlük ödül alındı!',
    'cycle_day', v_state.next_cycle_day,
    'streak_length', v_new_streak,
    'rewards_granted', v_rewards_granted,
    'new_balances', jsonb_build_object(
      'gold', v_player.gold,
      'gems', v_player.gems,
      'xp', v_player.xp,
      'energy', v_player.energy
    )
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bugünkü ödül zaten alındı.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_daily_reward_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward() TO authenticated;

-- Remove legacy overload that caused record->composite cast errors.
DROP FUNCTION IF EXISTS public.daily_reward_build_grant(public.daily_reward_config, integer);

COMMIT;
