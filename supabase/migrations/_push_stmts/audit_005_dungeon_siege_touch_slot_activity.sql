CREATE OR REPLACE FUNCTION public.dungeon_siege_touch_slot_activity(
  p_player_id uuid,
  p_dungeon_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player record;
BEGIN
  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;

  UPDATE public.dungeon_siege_slots s
  SET last_active_at = now(),
      guild_id = COALESCE(v_player.guild_id, s.guild_id)
  FROM public.dungeon_siege_sessions sess
  WHERE s.session_id = sess.id
    AND s.holder_id = p_player_id
    AND sess.dungeon_id = p_dungeon_id
    AND sess.is_active = true
    AND sess.ends_at > now();

  IF FOUND THEN
    PERFORM public.dungeon_siege_add_weekly_score(
      p_player_id,
      p_points => 2,
      p_slot_minutes => 1
    );
  END IF;
END;
$$;
