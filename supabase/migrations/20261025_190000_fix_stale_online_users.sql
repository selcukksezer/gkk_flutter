-- Fix Stale / Ghost Online Users (`users.is_online`)
-- 1. Sweeps stale `is_online = true` rows whose `last_active_at` is older than 2m 30s
--    so closed browser tabs, crashed sessions, or old test accounts never stay stuck online.
-- 2. Tightens `public.is_user_online` helper to 2m 30s (matching 45s client heartbeat).
-- 3. Runs `sweep_stale_online_users()` automatically inside `set_online_status`,
--    `claim_device_session`, `get_online_ward_players`, and `get_ward_board`.

BEGIN;

-- ── 1. Reusable Stale-Online Reaper ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sweep_stale_online_users()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cleaned integer := 0;
BEGIN
  UPDATE public.users
  SET
    is_online = false,
    current_mekan_id = NULL
  WHERE COALESCE(is_online, false) = true
    AND (
      last_active_at IS NULL
      OR last_active_at < (now() - interval '2 minutes 30 seconds')
    );

  GET DIAGNOSTICS v_cleaned = ROW_COUNT;
  RETURN v_cleaned;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sweep_stale_online_users() TO authenticated;

-- Immediate cleanup of all currently stuck ghost/test accounts:
SELECT public.sweep_stale_online_users();

-- ── 2. Shared Online Predicate (2m 30s Fresh Heartbeat Window) ───────────────
CREATE OR REPLACE FUNCTION public.is_user_online(
  p_is_online boolean,
  p_last_active_at timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(p_is_online, false)
    AND p_last_active_at IS NOT NULL
    AND p_last_active_at >= (now() - interval '2 minutes 30 seconds');
$$;

-- ── 3. Heartbeat & Logout RPC (`set_online_status`) with Auto-Sweep ──────────
CREATE OR REPLACE FUNCTION public.set_online_status(
  p_is_online boolean,
  p_mekan_id uuid DEFAULT NULL::uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.sweep_stale_online_users();

  IF auth.uid() IS NOT NULL THEN
    PERFORM public.apply_energy_regen(auth.uid());
  END IF;

  UPDATE public.users
  SET
    comeback_resume_from = CASE
      WHEN p_is_online
        AND comeback_resume_from IS NULL
        AND last_active_at IS NOT NULL
        AND last_active_at < now() - interval '5 minutes'
      THEN last_active_at
      WHEN NOT p_is_online THEN comeback_resume_from
      ELSE comeback_resume_from
    END,
    is_online = COALESCE(p_is_online, false),
    last_active_at = now(),
    current_mekan_id = CASE WHEN COALESCE(p_is_online, false) THEN p_mekan_id ELSE NULL END
  WHERE auth_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_online_status(boolean, uuid) TO authenticated;

-- ── 4. Single-Device Session Claim Also Sweeps Stale Accounts & Marks Online ─
CREATE OR REPLACE FUNCTION public.claim_device_session(
  p_device_id TEXT,
  p_platform TEXT DEFAULT 'mobile'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_device TEXT := NULLIF(btrim(p_device_id), '');
  v_platform TEXT := COALESCE(NULLIF(btrim(p_platform), ''), 'mobile');
  v_epoch BIGINT;
  v_prev_device TEXT;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF v_device IS NULL OR length(v_device) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid device id');
  END IF;

  PERFORM public.sweep_stale_online_users();

  SELECT active_device_id INTO v_prev_device
  FROM public.users WHERE auth_id = v_auth FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  UPDATE public.users
  SET
    active_device_id = v_device,
    session_epoch = COALESCE(session_epoch, 0) + 1,
    is_online = true,
    last_active_at = now(),
    last_login_at = now(),
    updated_at = now()
  WHERE auth_id = v_auth
  RETURNING session_epoch INTO v_epoch;

  INSERT INTO public.user_device_login_log (
    auth_id, device_id, platform, session_epoch, action
  ) VALUES (
    v_auth, v_device, v_platform, v_epoch,
    CASE WHEN v_prev_device IS NOT NULL AND v_prev_device <> v_device THEN 'superseded' ELSE 'claim' END
  );

  RETURN jsonb_build_object(
    'success', true,
    'device_id', v_device,
    'session_epoch', v_epoch,
    'superseded_previous', v_prev_device IS NOT NULL AND v_prev_device <> v_device
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_device_session(text, text) TO authenticated;

-- ── 5. Ward Online Peers & Ward Board Use 2m 30s Fresh Window + Sweep ────────
CREATE OR REPLACE FUNCTION public.get_online_ward_players(p_ward_type text)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_me record;
  v_rows jsonb := '[]'::jsonb;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_ward_type NOT IN ('hospital', 'prison') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid ward');
  END IF;

  PERFORM public.sweep_stale_online_users();

  SELECT * INTO v_me FROM public.users WHERE auth_id = v_auth;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF p_ward_type = 'hospital' THEN
    IF v_me.hospital_until IS NULL OR v_me.hospital_until <= now() THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hastanede degilsin');
    END IF;
  ELSE
    IF v_me.prison_until IS NULL OR v_me.prison_until <= now() THEN
      RETURN jsonb_build_object('success', false, 'error', 'Cezaevinde degilsin');
    END IF;
  END IF;

  WITH online_peers AS (
    SELECT
      u.id AS user_id,
      COALESCE(NULLIF(u.username, ''), 'Gezgin') AS username,
      COALESCE(NULLIF(u.display_name, ''), NULLIF(u.username, ''), 'Oyuncu') AS display_name,
      COALESCE(u.character_class, 'savasci') AS character_class,
      COALESCE(u.level, 1) AS level,
      COALESCE(u.power, 100) AS power,
      g.name AS guild_name,
      u.cosmetic_title,
      u.avatar_url,
      CASE
        WHEN p_ward_type = 'hospital' THEN u.hospital_until
        ELSE u.prison_until
      END AS until_ts,
      CASE
        WHEN p_ward_type = 'hospital' THEN u.hospital_reason
        ELSE u.prison_reason
      END AS reason,
      u.last_active_at,
      (u.guild_id IS NOT NULL AND u.guild_id = v_me.guild_id) AS same_guild
    FROM public.users u
    LEFT JOIN public.guilds g ON g.id = u.guild_id
    WHERE u.auth_id <> v_auth
      AND public.is_user_online(u.is_online, u.last_active_at)
      AND (
        (p_ward_type = 'hospital' AND u.hospital_until IS NOT NULL AND u.hospital_until > now())
        OR (p_ward_type = 'prison' AND u.prison_until IS NOT NULL AND u.prison_until > now())
      )
    ORDER BY
      (u.guild_id IS NOT NULL AND u.guild_id = v_me.guild_id) DESC,
      u.last_active_at DESC
    LIMIT 40
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', user_id,
      'username', username,
      'display_name', display_name,
      'character_class', character_class,
      'level', level,
      'power', power,
      'guild_name', guild_name,
      'cosmetic_title', cosmetic_title,
      'avatar_url', avatar_url,
      'until_ts', until_ts,
      'remaining_seconds', GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (until_ts - now())))::int),
      'reason', reason,
      'is_online', true,
      'same_guild', same_guild,
      'last_active_at', last_active_at
    )
  ), '[]'::jsonb)
  INTO v_rows
  FROM online_peers;

  RETURN jsonb_build_object(
    'success', true,
    'ward_type', p_ward_type,
    'entries', v_rows
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_online_ward_players(text) TO authenticated;

COMMIT;
