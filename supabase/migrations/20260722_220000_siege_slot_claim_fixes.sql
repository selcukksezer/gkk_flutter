-- Siege slot claim UX fixes:
-- 1) status auto-creates session during prime so slots always visible
-- 2) global my_slot + holds_slot_elsewhere for cross-dungeon gating
-- 3) claim_siege_slot handles missing users row safely

BEGIN;

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
  v_zone integer;
  v_territory_owner uuid;
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
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu profili bulunamadı.');
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_session_id := public.dungeon_siege_ensure_session(p_dungeon_id);
  IF v_session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma oturumu başlatılamadı.');
  END IF;

  v_zone := public.dungeon_siege_zone_for_dungeon(p_dungeon_id);
  v_territory_owner := public.dungeon_siege_territory_owner_for_zone(v_zone);

  SELECT * INTO v_slot
  FROM public.dungeon_siege_slots s
  WHERE s.session_id = v_session_id
    AND s.holder_id IS NULL
    AND (
      v_cfg.territory_reserve_slot_count <= 0
      OR v_territory_owner IS NULL
      OR s.slot_number > v_cfg.territory_reserve_slot_count
      OR v_player.guild_id IS NOT DISTINCT FROM v_territory_owner
    )
  ORDER BY s.slot_number
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN v_territory_owner IS NOT NULL
             AND v_player.guild_id IS DISTINCT FROM v_territory_owner
        THEN 'Bölge sahibi lonca rezerv slotları dolu. Meydan oku.'
        ELSE 'Boş slot yok. Meydan oku.'
      END
    );
  END IF;

  UPDATE public.dungeon_siege_slots
  SET holder_id = v_me,
      guild_id = v_player.guild_id,
      claimed_at = now(),
      expires_at = now() + make_interval(mins => v_cfg.slot_duration_minutes),
      last_active_at = now()
  WHERE id = v_slot.id;

  PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 5, p_slot_minutes => 0);

  RETURN jsonb_build_object(
    'success', true,
    'slot_id', v_slot.id,
    'slot_number', v_slot.slot_number,
    'expires_at', now() + make_interval(mins => v_cfg.slot_duration_minutes),
    'territory_reserved', v_territory_owner IS NOT NULL
      AND v_slot.slot_number <= v_cfg.territory_reserve_slot_count,
    'message', 'Slot alındı! Bonus farm başladı.'
  );
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
  v_my_slot_global jsonb := NULL;
  v_my_guild_id uuid;
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_cfg := public.dungeon_siege_get_config();

  IF p_dungeon_id IS NOT NULL
     AND public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    PERFORM public.dungeon_siege_ensure_session(p_dungeon_id);
  END IF;

  IF v_me IS NOT NULL THEN
    SELECT guild_id INTO v_my_guild_id FROM public.users WHERE auth_id = v_me;

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
    'is_banned', CASE
      WHEN v_me IS NULL OR p_dungeon_id IS NULL THEN false
      ELSE public.dungeon_siege_is_banned(v_me, p_dungeon_id)
    END,
    'config', public.get_dungeon_siege_config()
  );
END;
$$;

UPDATE public.dungeon_siege_config
SET prime_windows = '[
  {"start": "19:00", "end": "21:00"},
  {"start": "22:00", "end": "00:00"}
]'::jsonb,
    updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

COMMIT;
