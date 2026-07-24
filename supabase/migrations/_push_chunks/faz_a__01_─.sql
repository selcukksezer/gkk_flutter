BEGIN;

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

COMMIT;
