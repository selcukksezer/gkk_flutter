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
