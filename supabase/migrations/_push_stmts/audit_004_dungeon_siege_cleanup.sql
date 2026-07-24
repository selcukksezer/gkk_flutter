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
    AND public.dungeon_siege_count_guild_slots(sess.id, h.guild_id) < v_cfg.hold_min_members;

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
