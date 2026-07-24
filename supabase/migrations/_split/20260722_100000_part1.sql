-- ============================================================
-- Zindan Kuşatması — Faz A (forward)
-- Varsayılan: is_enabled = false (sistem kapalı)
-- Geri alma: supabase/manual_rollbacks/20260722_100001_dungeon_siege_rollback.sql
-- ============================================================

BEGIN;

-- ── Migration backup store ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public._gkk_migration_backups (
  backup_key text PRIMARY KEY,
  object_type text NOT NULL,
  object_name text NOT NULL,
  definition text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public._gkk_migration_backups (backup_key, object_type, object_name, definition)
SELECT
  'enter_dungeon_pre_siege',
  'function',
  'public.enter_dungeon(uuid,text)',
  pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'enter_dungeon'
  AND pg_get_function_identity_arguments(p.oid) = 'p_player_id uuid, p_dungeon_id text'
ON CONFLICT (backup_key) DO UPDATE
SET definition = EXCLUDED.definition,
    created_at = now();

-- ── Config (singleton) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.dungeon_siege_config (
  id uuid PRIMARY KEY DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
  is_enabled boolean NOT NULL DEFAULT false,
  slot_count integer NOT NULL DEFAULT 5 CHECK (slot_count BETWEEN 1 AND 12),
  slot_duration_minutes integer NOT NULL DEFAULT 20 CHECK (slot_duration_minutes BETWEEN 5 AND 120),
  inactive_release_minutes integer NOT NULL DEFAULT 10 CHECK (inactive_release_minutes BETWEEN 3 AND 60),
  challenge_cooldown_minutes integer NOT NULL DEFAULT 10 CHECK (challenge_cooldown_minutes BETWEEN 1 AND 120),
  challenge_gold_cost bigint NOT NULL DEFAULT 500 CHECK (challenge_gold_cost >= 0),
  ban_duration_minutes integer NOT NULL DEFAULT 45 CHECK (ban_duration_minutes BETWEEN 5 AND 240),
  loot_bonus_pct numeric NOT NULL DEFAULT 0.40 CHECK (loot_bonus_pct >= 0 AND loot_bonus_pct <= 2),
  gold_bonus_pct numeric NOT NULL DEFAULT 0.25 CHECK (gold_bonus_pct >= 0 AND gold_bonus_pct <= 2),
  rep_bonus_pct numeric NOT NULL DEFAULT 0.15 CHECK (rep_bonus_pct >= 0 AND rep_bonus_pct <= 2),
  power_band_pct numeric NOT NULL DEFAULT 0.30 CHECK (power_band_pct >= 0 AND power_band_pct <= 1),
  timezone text NOT NULL DEFAULT 'Europe/Istanbul',
  prime_windows jsonb NOT NULL DEFAULT '[{"start":"19:00","end":"21:00"},{"start":"22:00","end":"00:00"}]'::jsonb,
  siege_dungeon_ids text[] NOT NULL DEFAULT ARRAY[
    'dng_010','dng_020','dng_030','dng_040','dng_050','dng_060','dng_065'
  ],
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.dungeon_siege_config (id)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.dungeon_siege_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read siege config" ON public.dungeon_siege_config;
CREATE POLICY "Anyone can read siege config"
  ON public.dungeon_siege_config FOR SELECT USING (true);

-- Faz B hazırlığı: territory ↔ zone
ALTER TABLE public.guild_war_territories
  ADD COLUMN IF NOT EXISTS zone_number integer;

-- ── Sessions / slots / challenges / bans ────────────────────
CREATE TABLE IF NOT EXISTS public.dungeon_siege_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_number integer NOT NULL,
  dungeon_id text NOT NULL REFERENCES public.dungeons(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_sessions_active
  ON public.dungeon_siege_sessions (dungeon_id, is_active, ends_at DESC);

CREATE TABLE IF NOT EXISTS public.dungeon_siege_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.dungeon_siege_sessions(id) ON DELETE CASCADE,
  slot_number integer NOT NULL CHECK (slot_number >= 1),
  holder_id uuid REFERENCES public.users(auth_id) ON DELETE SET NULL,
  guild_id uuid REFERENCES public.guilds(id) ON DELETE SET NULL,
  claimed_at timestamptz,
  expires_at timestamptz,
  last_active_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, slot_number)
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_slots_holder
  ON public.dungeon_siege_slots (holder_id)
  WHERE holder_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.dungeon_siege_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id uuid NOT NULL REFERENCES public.dungeon_siege_slots(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.dungeon_siege_sessions(id) ON DELETE CASCADE,
  dungeon_id text NOT NULL REFERENCES public.dungeons(id) ON DELETE CASCADE,
  challenger_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  defender_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'resolved'
    CHECK (status IN ('pending', 'resolved', 'expired', 'cancelled')),
  winner_id uuid REFERENCES public.users(auth_id) ON DELETE SET NULL,
  gold_spent bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_challenges_challenger
  ON public.dungeon_siege_challenges (challenger_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.dungeon_siege_bans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  dungeon_id text NOT NULL REFERENCES public.dungeons(id) ON DELETE CASCADE,
  banned_until timestamptz NOT NULL,
  reason text NOT NULL DEFAULT 'siege_challenge_loss',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_bans_player
  ON public.dungeon_siege_bans (player_id, dungeon_id, banned_until DESC);

ALTER TABLE public.dungeon_siege_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_siege_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_siege_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_siege_bans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view siege sessions" ON public.dungeon_siege_sessions;
CREATE POLICY "Anyone can view siege sessions"
  ON public.dungeon_siege_sessions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view siege slots" ON public.dungeon_siege_slots;
CREATE POLICY "Anyone can view siege slots"
  ON public.dungeon_siege_slots FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view siege challenges" ON public.dungeon_siege_challenges;
CREATE POLICY "Anyone can view siege challenges"
  ON public.dungeon_siege_challenges FOR SELECT USING (true);

DROP POLICY IF EXISTS "Players can view own siege bans" ON public.dungeon_siege_bans;
CREATE POLICY "Players can view own siege bans"
  ON public.dungeon_siege_bans FOR SELECT
  USING (player_id = auth.uid());

-- ── Helpers ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dungeon_siege_get_config()
RETURNS public.dungeon_siege_config
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.dungeon_siege_config
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_is_enabled()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE((SELECT is_enabled FROM public.dungeon_siege_get_config()), false);
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_is_target_dungeon(p_dungeon_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_dungeon_id = ANY(COALESCE((SELECT siege_dungeon_ids FROM public.dungeon_siege_get_config()), ARRAY[]::text[]));
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_in_prime_window()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_now time;
  v_window jsonb;
  v_start time;
  v_end time;
BEGIN
  v_cfg := public.dungeon_siege_get_config();
  v_now := (now() AT TIME ZONE COALESCE(v_cfg.timezone, 'Europe/Istanbul'))::time;

  FOR v_window IN
    SELECT value FROM jsonb_array_elements(COALESCE(v_cfg.prime_windows, '[]'::jsonb))
  LOOP
    BEGIN
      v_start := (v_window->>'start')::time;
      v_end := (v_window->>'end')::time;
    EXCEPTION WHEN OTHERS THEN
      CONTINUE;
    END;

    IF v_end = v_start THEN
      CONTINUE;
    ELSIF v_end > v_start THEN
      IF v_now >= v_start AND v_now < v_end THEN
        RETURN true;
      END IF;
    ELSE
      -- midnight wrap (e.g. 22:00 -> 00:00)
      IF v_now >= v_start OR v_now < v_end THEN
        RETURN true;
      END IF;
    END IF;
  END LOOP;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_is_active_for_dungeon(p_dungeon_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.dungeon_siege_is_enabled()
     AND public.dungeon_siege_in_prime_window()
     AND public.dungeon_siege_is_target_dungeon(p_dungeon_id);
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_zone_for_dungeon(p_dungeon_id text)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_num integer;
BEGIN
  v_num := CAST(SUBSTRING(p_dungeon_id FROM 5) AS integer);
  IF v_num IS NULL THEN
    RETURN 0;
  END IF;
  RETURN ((v_num - 1) / 10) + 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_cleanup()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
BEGIN
  v_cfg := public.dungeon_siege_get_config();

  UPDATE public.dungeon_siege_sessions
  SET is_active = false
  WHERE is_active = true AND ends_at <= now();

  UPDATE public.dungeon_siege_slots s
  SET holder_id = NULL,
      guild_id = NULL,
      claimed_at = NULL,
      expires_at = NULL,
      last_active_at = NULL
  FROM public.dungeon_siege_sessions sess
  WHERE s.session_id = sess.id
    AND s.holder_id IS NOT NULL
    AND (
      (s.expires_at IS NOT NULL AND s.expires_at <= now())
      OR (
        s.last_active_at IS NOT NULL
        AND s.last_active_at <= now() - make_interval(mins => v_cfg.inactive_release_minutes)
      )
    );

  DELETE FROM public.dungeon_siege_bans WHERE banned_until <= now();
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_ensure_session(p_dungeon_id text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_session_id uuid;
  v_zone integer;
  v_i integer;
BEGIN
  PERFORM public.dungeon_siege_cleanup();

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_session_id
  FROM public.dungeon_siege_sessions
  WHERE dungeon_id = p_dungeon_id
    AND is_active = true
    AND ends_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_session_id IS NOT NULL THEN
    RETURN v_session_id;
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_zone := public.dungeon_siege_zone_for_dungeon(p_dungeon_id);

  INSERT INTO public.dungeon_siege_sessions (zone_number, dungeon_id, ends_at)
  VALUES (v_zone, p_dungeon_id, now() + interval '3 hours')
  RETURNING id INTO v_session_id;

  FOR v_i IN 1..v_cfg.slot_count LOOP
    INSERT INTO public.dungeon_siege_slots (session_id, slot_number)
    VALUES (v_session_id, v_i);
  END LOOP;

  RETURN v_session_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_player_has_slot(
  p_player_id uuid,
  p_dungeon_id text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = p_player_id
      AND sess.dungeon_id = p_dungeon_id
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (s.expires_at IS NULL OR s.expires_at > now())
  );
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_player_holds_any_slot(p_player_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = p_player_id
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (s.expires_at IS NULL OR s.expires_at > now())
  );
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_can_fight(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_id = p_user_id
      AND (
        (u.hospital_until IS NOT NULL AND u.hospital_until > now())
        OR (u.prison_until IS NOT NULL AND u.prison_until > now())
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_touch_slot_activity(
  p_player_id uuid,
  p_dungeon_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.dungeon_siege_slots s
  SET last_active_at = now()
  FROM public.dungeon_siege_sessions sess
  WHERE s.session_id = sess.id
    AND s.holder_id = p_player_id
    AND sess.dungeon_id = p_dungeon_id
    AND sess.is_active = true
    AND sess.ends_at > now();
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_reward_multipliers(
  p_player_id uuid,
  p_dungeon_id text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_has_slot boolean;
BEGIN
  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object(
      'siege_active', false,
      'has_slot', false,
      'gold_mult', 1,
      'loot_mult', 1
    );
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_has_slot := public.dungeon_siege_player_has_slot(p_player_id, p_dungeon_id);

  IF NOT v_has_slot THEN
    RETURN jsonb_build_object(
      'siege_active', true,
      'has_slot', false,
      'gold_mult', 1,
      'loot_mult', 1
    );
  END IF;

  RETURN jsonb_build_object(
    'siege_active', true,
    'has_slot', true,
    'gold_mult', 1 + COALESCE(v_cfg.gold_bonus_pct, 0),
    'loot_mult', 1 + COALESCE(v_cfg.loot_bonus_pct, 0),
    'rep_bonus_pct', COALESCE(v_cfg.rep_bonus_pct, 0.15)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_is_banned(
  p_player_id uuid,
  p_dungeon_id text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.dungeon_siege_bans
    WHERE player_id = p_player_id
      AND dungeon_id = p_dungeon_id
      AND banned_until > now()
  );
$$;

-- ── Public RPCs ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_dungeon_siege_config()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
BEGIN
  v_cfg := public.dungeon_siege_get_config();
  RETURN jsonb_build_object(
    'is_enabled', v_cfg.is_enabled,
    'slot_count', v_cfg.slot_count,
    'slot_duration_minutes', v_cfg.slot_duration_minutes,
    'inactive_release_minutes', v_cfg.inactive_release_minutes,
    'challenge_cooldown_minutes', v_cfg.challenge_cooldown_minutes,
    'challenge_gold_cost', v_cfg.challenge_gold_cost,
    'ban_duration_minutes', v_cfg.ban_duration_minutes,
    'loot_bonus_pct', v_cfg.loot_bonus_pct,
    'gold_bonus_pct', v_cfg.gold_bonus_pct,
    'rep_bonus_pct', v_cfg.rep_bonus_pct,
    'power_band_pct', v_cfg.power_band_pct,
    'timezone', v_cfg.timezone,
    'prime_windows', v_cfg.prime_windows,
    'siege_dungeon_ids', v_cfg.siege_dungeon_ids,
    'in_prime_window', public.dungeon_siege_in_prime_window()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_dungeon_siege_config(
  p_is_enabled boolean DEFAULT NULL,
  p_slot_count integer DEFAULT NULL,
  p_slot_duration_minutes integer DEFAULT NULL,
  p_inactive_release_minutes integer DEFAULT NULL,
  p_challenge_cooldown_minutes integer DEFAULT NULL,
  p_challenge_gold_cost bigint DEFAULT NULL,
  p_ban_duration_minutes integer DEFAULT NULL,
  p_loot_bonus_pct numeric DEFAULT NULL,
  p_gold_bonus_pct numeric DEFAULT NULL,
  p_rep_bonus_pct numeric DEFAULT NULL,
  p_power_band_pct numeric DEFAULT NULL,
  p_prime_windows jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF COALESCE(current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bu ayar sadece service_role veya SQL Editor ile degistirilebilir.'
    );
  END IF;

  UPDATE public.dungeon_siege_config
  SET
    is_enabled = COALESCE(p_is_enabled, is_enabled),
    slot_count = COALESCE(p_slot_count, slot_count),
    slot_duration_minutes = COALESCE(p_slot_duration_minutes, slot_duration_minutes),
    inactive_release_minutes = COALESCE(p_inactive_release_minutes, inactive_release_minutes),
    challenge_cooldown_minutes = COALESCE(p_challenge_cooldown_minutes, challenge_cooldown_minutes),
    challenge_gold_cost = COALESCE(p_challenge_gold_cost, challenge_gold_cost),
    ban_duration_minutes = COALESCE(p_ban_duration_minutes, ban_duration_minutes),
    loot_bonus_pct = COALESCE(p_loot_bonus_pct, loot_bonus_pct),
    gold_bonus_pct = COALESCE(p_gold_bonus_pct, gold_bonus_pct),
    rep_bonus_pct = COALESCE(p_rep_bonus_pct, rep_bonus_pct),
    power_band_pct = COALESCE(p_power_band_pct, power_band_pct),
    prime_windows = COALESCE(p_prime_windows, prime_windows),
    updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  RETURN public.get_dungeon_siege_config();
END;
$$;

CREATE OR REPLACE FUNCTION public.get_dungeon_siege_status(p_dungeon_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_cfg public.dungeon_siege_config;
  v_sessions jsonb := '[]'::jsonb;
  v_my_slot jsonb := NULL;
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_cfg := public.dungeon_siege_get_config();

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'session_id', sess.id,
    'dungeon_id', sess.dungeon_id,
    'zone_number', sess.zone_number,
    'ends_at', sess.ends_at,
    'slots', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'slot_id', s.id,
        'slot_number', s.slot_number,
        'holder_id', s.holder_id,
        'holder_name', COALESCE(u.display_name, u.username, '—'),
        'holder_power', COALESCE(u.power, 0),
        'guild_id', s.guild_id,
        'guild_name', g.name,
        'expires_at', s.expires_at,
        'last_active_at', s.last_active_at,
        'is_mine', s.holder_id = v_me
      ) ORDER BY s.slot_number), '[]'::jsonb)
      FROM public.dungeon_siege_slots s
      LEFT JOIN public.users u ON u.auth_id = s.holder_id
      LEFT JOIN public.guilds g ON g.id = s.guild_id
      WHERE s.session_id = sess.id
    )
  ) ORDER BY sess.zone_number), '[]'::jsonb)
  INTO v_sessions
  FROM public.dungeon_siege_sessions sess
  WHERE sess.is_active = true
    AND sess.ends_at > now()
    AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id);

  IF v_me IS NOT NULL THEN
    SELECT jsonb_build_object(
      'slot_id', s.id,
      'slot_number', s.slot_number,
      'dungeon_id', sess.dungeon_id,
      'expires_at', s.expires_at
    )
    INTO v_my_slot
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = v_me
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id)
    ORDER BY s.claimed_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'enabled', v_cfg.is_enabled,
    'in_prime_window', public.dungeon_siege_in_prime_window(),
    'siege_active', v_cfg.is_enabled AND public.dungeon_siege_in_prime_window(),
    'sessions', v_sessions,
    'my_slot', v_my_slot,
    'is_banned', CASE
      WHEN v_me IS NULL OR p_dungeon_id IS NULL THEN false
      ELSE public.dungeon_siege_is_banned(v_me, p_dungeon_id)
    END,
    'config', public.get_dungeon_siege_config()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_siege_slot(p_dungeon_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_player record;
  v_cfg public.dungeon_siege_config;
  v_session_id uuid;
  v_slot record;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  IF public.dungeon_siege_is_banned(v_me, p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindandan banlısın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastane/cezaevinde slot alamazsın.');
  END IF;

  IF public.dungeon_siege_player_holds_any_slot(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir kuşatma slotu tutuyorsun.');
  END IF;

  IF public.dungeon_siege_player_has_slot(v_me, p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindanda zaten slot tutuyorsun.');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = v_me;
  v_cfg := public.dungeon_siege_get_config();
  v_session_id := public.dungeon_siege_ensure_session(p_dungeon_id);

  SELECT * INTO v_slot
  FROM public.dungeon_siege_slots
  WHERE session_id = v_session_id
    AND holder_id IS NULL
  ORDER BY slot_number
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Boş slot yok. Meydan oku.');
  END IF;

  UPDATE public.dungeon_siege_slots
  SET holder_id = v_me,
      guild_id = v_player.guild_id,
      claimed_at = now(),
      expires_at = now() + make_interval(mins => v_cfg.slot_duration_minutes),
      last_active_at = now()
  WHERE id = v_slot.id;

  RETURN jsonb_build_object(
    'success', true,
    'slot_id', v_slot.id,
    'slot_number', v_slot.slot_number,
    'expires_at', now() + make_interval(mins => v_cfg.slot_duration_minutes),
    'message', 'Slot alındı! Bonus farm başladı.'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.release_siege_slot(p_slot_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_slot record;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_slot
  FROM public.dungeon_siege_slots
  WHERE id = p_slot_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Slot bulunamadı.');
  END IF;

  IF v_slot.holder_id IS DISTINCT FROM v_me THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu slot sana ait değil.');
  END IF;

  UPDATE public.dungeon_siege_slots
  SET holder_id = NULL,
      guild_id = NULL,
      claimed_at = NULL,
      expires_at = NULL,
      last_active_at = NULL
  WHERE id = p_slot_id;

  RETURN jsonb_build_object('success', true, 'message', 'Slot bırakıldı.');
END;
$$;

CREATE OR REPLACE FUNCTION public.challenge_siege_slot(p_slot_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_cfg public.dungeon_siege_config;
  v_slot record;
  v_sess record;
  v_challenger record;
  v_defender record;
  v_att_power numeric;
  v_def_power numeric;
  v_win_chance numeric;
  v_winner_id uuid;
  v_loser_id uuid;
  v_ch_rating int;
  v_tg_rating int;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_cfg := public.dungeon_siege_get_config();

  IF NOT v_cfg.is_enabled OR NOT public.dungeon_siege_in_prime_window() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  SELECT s.*, sess.dungeon_id, sess.id AS session_uuid
  INTO v_slot
  FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE s.id = p_slot_id
    AND sess.is_active = true
    AND sess.ends_at > now()
  FOR UPDATE OF s;

  IF NOT FOUND OR v_slot.holder_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Slot boş veya geçersiz.');
  END IF;

  IF v_slot.holder_id = v_me THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi slotuna meydan okuyamazsın.');
  END IF;

  IF public.dungeon_siege_is_banned(v_me, v_slot.dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindandan banlısın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastane/cezaevinde meydan okuyamazsın.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.dungeon_siege_challenges
    WHERE challenger_id = v_me
      AND created_at > now() - make_interval(mins => v_cfg.challenge_cooldown_minutes)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Meydan okuma bekleme süresindesin.');
  END IF;

  SELECT * INTO v_challenger FROM public.users WHERE auth_id = v_me FOR UPDATE;
  SELECT * INTO v_defender FROM public.users WHERE auth_id = v_slot.holder_id FOR UPDATE;

  IF v_challenger IS NULL OR v_defender IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  IF v_challenger.guild_id IS NOT NULL AND v_challenger.guild_id = v_defender.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesine meydan okuyamazsın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_slot.holder_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakip hastane/cezaevinde.');
  END IF;

  IF v_challenger.gold < v_cfg.challenge_gold_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın.');
  END IF;

  IF v_cfg.power_band_pct > 0 THEN
    IF abs(
      COALESCE(public.calculate_user_total_power(v_me), v_challenger.power, 0)
      - COALESCE(public.calculate_user_total_power(v_slot.holder_id), v_defender.power, 0)
    )::numeric
       > GREATEST(COALESCE(public.calculate_user_total_power(v_slot.holder_id), v_defender.power, 1), 1)
         * v_cfg.power_band_pct THEN
      RETURN jsonb_build_object('success', false, 'error', 'Güç farkı çok yüksek (±30%).');
    END IF;
  END IF;

  UPDATE public.users
  SET gold = gold - v_cfg.challenge_gold_cost
  WHERE auth_id = v_me AND gold >= v_cfg.challenge_gold_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altın düşülemedi.');
  END IF;

  v_att_power := COALESCE(v_challenger.attack, 10) + COALESCE(v_challenger.defense, 10);
  v_def_power := COALESCE(v_defender.attack, 10) + COALESCE(v_defender.defense, 10);
  IF COALESCE(v_challenger.character_class, '') = 'shadow' THEN v_att_power := v_att_power * 1.15; END IF;
  IF COALESCE(v_defender.character_class, '') = 'shadow' THEN v_def_power := v_def_power * 1.15; END IF;

  v_win_chance := v_att_power / NULLIF(v_att_power + v_def_power, 0);
  IF v_win_chance IS NULL THEN v_win_chance := 0.5; END IF;

  IF random() <= v_win_chance THEN
    v_winner_id := v_me;
    v_loser_id := v_slot.holder_id;
    v_ch_rating := 15 + floor(random() * 10)::INT;
    v_tg_rating := -(10 + floor(random() * 5)::INT);
  ELSE
    v_winner_id := v_slot.holder_id;
    v_loser_id := v_me;
    v_ch_rating := -(10 + floor(random() * 5)::INT);
    v_tg_rating := 15 + floor(random() * 10)::INT;
  END IF;

  UPDATE public.users SET
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_ch_rating),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_me THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_me THEN 1 ELSE 0 END
  WHERE auth_id = v_me;

  UPDATE public.users SET
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_tg_rating),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_slot.holder_id THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_slot.holder_id THEN 1 ELSE 0 END
  WHERE auth_id = v_slot.holder_id;

  IF v_winner_id = v_me THEN
    UPDATE public.dungeon_siege_slots
    SET holder_id = v_me,
        guild_id = v_challenger.guild_id,
        claimed_at = now(),
        expires_at = now() + make_interval(mins => v_cfg.slot_duration_minutes),
        last_active_at = now()
    WHERE id = p_slot_id;

    INSERT INTO public.dungeon_siege_bans (player_id, dungeon_id, banned_until, reason)
    VALUES (
      v_loser_id,
      v_slot.dungeon_id,
      now() + make_interval(mins => v_cfg.ban_duration_minutes),
      'siege_challenge_loss'
    );
  ELSE
    INSERT INTO public.dungeon_siege_bans (player_id, dungeon_id, banned_until, reason)
    VALUES (
      v_loser_id,
      v_slot.dungeon_id,
      now() + make_interval(mins => v_cfg.ban_duration_minutes),
      'siege_challenge_loss'
    );
  END IF;

  INSERT INTO public.dungeon_siege_challenges (
    slot_id, session_id, dungeon_id,
    challenger_id, defender_id,
    status, winner_id, gold_spent, resolved_at
  ) VALUES (
    p_slot_id, v_slot.session_id, v_slot.dungeon_id,
    v_me, v_slot.holder_id,
    'resolved', v_winner_id, v_cfg.challenge_gold_cost, now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'winner_id', v_winner_id,
    'you_won', v_winner_id = v_me,
    'gold_spent', v_cfg.challenge_gold_cost,
    'ban_minutes', v_cfg.ban_duration_minutes,
    'message', CASE
      WHEN v_winner_id = v_me THEN 'Kazandın! Slot senin.'
      ELSE 'Kaybettin. Bu zindandan banlandın.'
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_dungeon_siege_config() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_dungeon_siege_config(boolean, integer, integer, integer, integer, bigint, integer, numeric, numeric, numeric, numeric, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_dungeon_siege_status(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_siege_slot(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_siege_slot(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.challenge_siege_slot(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dungeon_siege_is_enabled() TO authenticated;
GRANT EXECUTE ON FUNCTION public.dungeon_siege_reward_multipliers(uuid, text) TO authenticated;
COMMIT;
