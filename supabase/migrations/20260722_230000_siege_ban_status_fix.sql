-- Siege ban: always return banned_dungeon_ids so global status poll does not wipe ban state.

BEGIN;

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
  v_my_slot_global jsonb := NULL;
  v_my_guild_id uuid;
  v_banned_dungeon_ids jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_cfg := public.dungeon_siege_get_config();

  IF p_dungeon_id IS NOT NULL
     AND public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    PERFORM public.dungeon_siege_ensure_session(p_dungeon_id);
  END IF;

  IF v_me IS NOT NULL THEN
    SELECT guild_id INTO v_my_guild_id FROM public.users WHERE auth_id = v_me;

    SELECT COALESCE(jsonb_agg(b.dungeon_id ORDER BY b.dungeon_id), '[]'::jsonb)
    INTO v_banned_dungeon_ids
    FROM public.dungeon_siege_bans b
    WHERE b.player_id = v_me
      AND b.banned_until > now();

    SELECT jsonb_build_object(
      'slot_id', s.id,
      'slot_number', s.slot_number,
      'dungeon_id', sess.dungeon_id,
      'expires_at', s.expires_at
    )
    INTO v_my_slot_global
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = v_me
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (s.expires_at IS NULL OR s.expires_at > now())
    ORDER BY s.claimed_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'session_id', sess.id,
    'dungeon_id', sess.dungeon_id,
    'zone_number', sess.zone_number,
    'ends_at', sess.ends_at,
    'territory_owner_guild_id', public.dungeon_siege_territory_owner_for_zone(sess.zone_number),
    'territory_owner_guild_name', (
      SELECT g.name
      FROM public.guild_war_territories t
      LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
      WHERE t.zone_number = sess.zone_number
      LIMIT 1
    ),
    'guild_slots', CASE
      WHEN v_my_guild_id IS NULL THEN 0
      ELSE public.dungeon_siege_count_guild_slots(sess.id, v_my_guild_id)
    END,
    'hold', public.dungeon_siege_hold_json(sess.id),
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
        'is_mine', s.holder_id IS NOT NULL AND s.holder_id = v_me,
        'is_territory_reserved', s.slot_number <= v_cfg.territory_reserve_slot_count
          AND public.dungeon_siege_territory_owner_for_zone(sess.zone_number) IS NOT NULL
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
    IF p_dungeon_id IS NULL THEN
      v_my_slot := v_my_slot_global;
    ELSE
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
        AND sess.dungeon_id = p_dungeon_id
        AND sess.is_active = true
        AND sess.ends_at > now()
        AND (s.expires_at IS NULL OR s.expires_at > now())
      ORDER BY s.claimed_at DESC NULLS LAST
      LIMIT 1;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'enabled', v_cfg.is_enabled,
    'in_prime_window', public.dungeon_siege_in_prime_window(),
    'siege_active', v_cfg.is_enabled AND public.dungeon_siege_in_prime_window(),
    'sessions', v_sessions,
    'my_slot', v_my_slot,
    'my_slot_global', v_my_slot_global,
    'holds_slot_elsewhere', v_my_slot_global IS NOT NULL
      AND p_dungeon_id IS NOT NULL
      AND (v_my_slot_global->>'dungeon_id') IS DISTINCT FROM p_dungeon_id,
    'banned_dungeon_ids', v_banned_dungeon_ids,
    'is_banned', CASE
      WHEN v_me IS NULL THEN false
      WHEN p_dungeon_id IS NOT NULL THEN public.dungeon_siege_is_banned(v_me, p_dungeon_id)
      ELSE jsonb_array_length(v_banned_dungeon_ids) > 0
    END,
    'config', public.get_dungeon_siege_config()
  );
END;
$$;

COMMIT;
