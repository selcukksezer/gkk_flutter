-- Online-only Hospital & Prison Ward Players + Board
-- Ensures players who fall into Hospital or Prison see ONLY currently ONLINE
-- fellow patients/inmates who are in the exact same active restriction.

BEGIN;

-- ── 1. Live Online Ward Players RPC (for 2.5D Home Ward/Prison Scene) ────────
CREATE OR REPLACE FUNCTION public.get_online_ward_players(p_ward_type text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
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
      AND COALESCE(u.is_online, false) = true
      AND u.last_active_at IS NOT NULL
      AND u.last_active_at > (now() - interval '5 minutes')
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

-- ── 2. Update get_ward_board so WardPanel also shows ONLY ONLINE peers ───────
CREATE OR REPLACE FUNCTION public.get_ward_board(p_ward_type text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_me record;
  v_rows jsonb := '[]'::jsonb;
  v_self jsonb;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_ward_type NOT IN ('hospital', 'prison') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid ward');
  END IF;

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

  WITH candidates AS (
    SELECT
      u.id AS user_id,
      u.auth_id,
      COALESCE(NULLIF(u.display_name, ''), NULLIF(u.username, ''), 'Oyuncu') AS display_name,
      COALESCE(u.character_class, '') AS character_class,
      COALESCE(u.level, 1) AS level,
      CASE
        WHEN p_ward_type = 'hospital' THEN u.hospital_until
        ELSE u.prison_until
      END AS until_ts,
      p_ward_type AS reason_tag,
      CASE
        WHEN u.guild_id IS NOT NULL AND u.guild_id = v_me.guild_id THEN 1
        WHEN EXISTS (
          SELECT 1 FROM public.friendships f
          WHERE f.status = 'accepted'
            AND (
              (f.requester_id = v_me.auth_id AND f.addressee_id = u.auth_id)
              OR (f.addressee_id = v_me.auth_id AND f.requester_id = u.auth_id)
            )
        ) THEN 2
        ELSE 3
      END AS visibility_rank
    FROM public.users u
    WHERE u.auth_id <> v_auth
      AND COALESCE(u.is_online, false) = true
      AND u.last_active_at IS NOT NULL
      AND u.last_active_at > (now() - interval '5 minutes')
      AND (
        (p_ward_type = 'hospital' AND u.hospital_until IS NOT NULL AND u.hospital_until > now())
        OR (p_ward_type = 'prison' AND u.prison_until IS NOT NULL AND u.prison_until > now())
      )
  ),
  ranked AS (
    SELECT
      user_id,
      display_name,
      character_class,
      level,
      until_ts,
      reason_tag,
      CASE
        WHEN EXTRACT(EPOCH FROM (until_ts - now())) < 3600 THEN '<1h'
        WHEN EXTRACT(EPOCH FROM (until_ts - now())) < 10800 THEN '1-3h'
        ELSE '3h+'
      END AS time_band,
      visibility_rank
    FROM candidates
    ORDER BY
      visibility_rank ASC,
      until_ts ASC
    LIMIT 40
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', user_id,
      'display_name', display_name,
      'character_class', character_class,
      'level', level,
      'until_ts', until_ts,
      'reason_tag', reason_tag,
      'time_band', time_band,
      'is_online', true,
      'scope', CASE visibility_rank
        WHEN 1 THEN 'guild'
        WHEN 2 THEN 'friends'
        ELSE 'city'
      END,
      'is_self', false
    )
  ), '[]'::jsonb)
  INTO v_rows
  FROM ranked;

  v_self := jsonb_build_object(
    'user_id', v_me.id,
    'display_name', COALESCE(NULLIF(v_me.display_name, ''), v_me.username, 'Sen'),
    'character_class', COALESCE(v_me.character_class, ''),
    'level', COALESCE(v_me.level, 1),
    'reason_tag', p_ward_type,
    'time_band', CASE
      WHEN EXTRACT(EPOCH FROM (
        CASE WHEN p_ward_type = 'hospital' THEN v_me.hospital_until ELSE v_me.prison_until END - now()
      )) < 3600 THEN '<1h'
      WHEN EXTRACT(EPOCH FROM (
        CASE WHEN p_ward_type = 'hospital' THEN v_me.hospital_until ELSE v_me.prison_until END - now()
      )) < 10800 THEN '1-3h'
      ELSE '3h+'
    END,
    'is_online', true,
    'scope', 'self',
    'is_self', true
  );

  RETURN jsonb_build_object(
    'success', true,
    'ward_type', p_ward_type,
    'self', v_self,
    'entries', v_rows,
    'show_on_city', COALESCE(v_me.show_on_ward_board, true),
    'friends_opt_in', COALESCE(v_me.ward_board_friends_opt_in, true)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_ward_board(text) TO authenticated;

COMMIT;
