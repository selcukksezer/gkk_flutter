-- Siege hold guards: session lock, idempotent concurrent start, distinct member count, cleanup hold_min.

BEGIN;

CREATE OR REPLACE FUNCTION public.dungeon_siege_count_guild_slots(
  p_session_id uuid,
  p_guild_id uuid
)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COUNT(DISTINCT s.holder_id)::integer
  FROM public.dungeon_siege_slots s
  WHERE s.session_id = p_session_id
    AND s.guild_id = p_guild_id
    AND s.holder_id IS NOT NULL
    AND (s.expires_at IS NULL OR s.expires_at > now());
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_hold_min_for_session(
  p_session_id uuid,
  p_guild_id uuid
)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_zone integer;
  v_territory_owner uuid;
BEGIN
  v_cfg := public.dungeon_siege_get_config();

  SELECT zone_number INTO v_zone
  FROM public.dungeon_siege_sessions
  WHERE id = p_session_id;

  IF v_zone IS NULL THEN
    RETURN v_cfg.hold_min_members;
  END IF;

  v_territory_owner := public.dungeon_siege_territory_owner_for_zone(v_zone);

  IF v_territory_owner IS NOT NULL AND p_guild_id = v_territory_owner THEN
    RETURN 1;
  END IF;

  RETURN v_cfg.hold_min_members;
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

  UPDATE public.dungeon_siege_holds h
  SET is_active = false,
      ended_at = now()
  FROM public.dungeon_siege_sessions sess
  WHERE h.session_id = sess.id
    AND h.is_active = true
    AND (NOT sess.is_active OR sess.ends_at <= now());

  UPDATE public.dungeon_siege_holds h
  SET is_active = false,
      ended_at = now()
  FROM public.dungeon_siege_sessions sess
  WHERE h.session_id = sess.id
    AND h.is_active = true
    AND sess.is_active = true
    AND sess.ends_at > now()
    AND public.dungeon_siege_count_guild_slots(sess.id, h.guild_id)
        < public.dungeon_siege_hold_min_for_session(sess.id, h.guild_id);

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

CREATE OR REPLACE FUNCTION public.start_siege_guild_hold(p_dungeon_id text)
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
  v_guild_slots integer;
  v_existing public.dungeon_siege_holds;
  v_new_hold_id uuid;
  v_zone integer;
  v_territory_owner uuid;
  v_hold_min integer;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = v_me;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu profili bulunamadı.');
  END IF;

  IF v_player.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsin.');
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_session_id := public.dungeon_siege_ensure_session(p_dungeon_id);

  IF v_session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum oluşturulamadı.');
  END IF;

  -- Serialize concurrent hold starts for the same session.
  PERFORM 1
  FROM public.dungeon_siege_sessions sess
  WHERE sess.id = v_session_id
  FOR UPDATE;

  v_zone := public.dungeon_siege_zone_for_dungeon(p_dungeon_id);
  v_territory_owner := public.dungeon_siege_territory_owner_for_zone(v_zone);

  IF v_territory_owner IS NOT NULL AND v_player.guild_id IS DISTINCT FROM v_territory_owner THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Hold yalnızca bölge sahibi lonca başlatabilir.'
    );
  END IF;

  v_hold_min := public.dungeon_siege_hold_min_for_session(v_session_id, v_player.guild_id);

  IF NOT EXISTS (
    SELECT 1
    FROM public.dungeon_siege_slots s
    WHERE s.session_id = v_session_id
      AND s.holder_id = v_me
      AND s.guild_id = v_player.guild_id
      AND (s.expires_at IS NULL OR s.expires_at > now())
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Hold başlatmak için bu zindanda lonca slotu tutmalısın.'
    );
  END IF;

  v_existing := public.dungeon_siege_active_hold(v_session_id);
  IF v_existing.id IS NOT NULL THEN
    IF v_existing.guild_id = v_player.guild_id THEN
      RETURN jsonb_build_object(
        'success', true,
        'hold_id', v_existing.id,
        'already_active', true,
        'message', 'Loncanın hold''u zaten aktif.',
        'hold', public.dungeon_siege_hold_json(v_session_id)
      );
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'Başka lonca hold tutuyor.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.dungeon_siege_holds h
    JOIN public.dungeon_siege_sessions sess ON sess.id = h.session_id
    WHERE sess.dungeon_id = p_dungeon_id
      AND h.guild_id = v_player.guild_id
      AND h.broken_at IS NOT NULL
      AND h.broken_at > now() - make_interval(mins => v_cfg.hold_rehold_cooldown_minutes)
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Hold kırıldıktan sonra %s dk beklemen gerek.', v_cfg.hold_rehold_cooldown_minutes)
    );
  END IF;

  v_guild_slots := public.dungeon_siege_count_guild_slots(v_session_id, v_player.guild_id);

  IF v_guild_slots < v_hold_min THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Hold için en az %s lonca üyesi slot tutmalı.', v_hold_min),
      'guild_slots', v_guild_slots,
      'required', v_hold_min
    );
  END IF;

  BEGIN
    INSERT INTO public.dungeon_siege_holds (session_id, guild_id, started_by)
    VALUES (v_session_id, v_player.guild_id, v_me)
    RETURNING id INTO v_new_hold_id;
  EXCEPTION WHEN unique_violation THEN
    v_existing := public.dungeon_siege_active_hold(v_session_id);
    IF v_existing.id IS NOT NULL AND v_existing.guild_id = v_player.guild_id THEN
      RETURN jsonb_build_object(
        'success', true,
        'hold_id', v_existing.id,
        'already_active', true,
        'message', 'Loncanın hold''u zaten aktif.',
        'hold', public.dungeon_siege_hold_json(v_session_id)
      );
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'Hold zaten başlatıldı.');
  END;

  PERFORM public.dungeon_siege_notify_hold_guild(
    v_session_id,
    v_player.guild_id,
    'hold_started',
    'Lonca hold başladı',
    p_dungeon_id || ' kuşatmasında lonca hold aktif.',
    jsonb_build_object('dungeon_id', p_dungeon_id, 'hold_id', v_new_hold_id)
  );

  PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 50);

  RETURN jsonb_build_object(
    'success', true,
    'hold_id', v_new_hold_id,
    'message', format('Lonca hold başladı! +%s%% ek bonus.', round(v_cfg.hold_bonus_pct * 100)),
    'hold', public.dungeon_siege_hold_json(v_session_id)
  );
END;
$$;

COMMIT;
