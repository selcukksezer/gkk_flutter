CREATE OR REPLACE FUNCTION public.dungeon_siege_apply_ban(
  p_player_id uuid,
  p_dungeon_id text,
  p_minutes integer,
  p_reason text DEFAULT 'siege_challenge_loss'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_until timestamptz := now() + make_interval(mins => GREATEST(1, p_minutes));
BEGIN
  UPDATE public.dungeon_siege_bans
  SET banned_until = GREATEST(banned_until, v_until),
      reason = p_reason
  WHERE player_id = p_player_id
    AND dungeon_id = p_dungeon_id
    AND banned_until > now();

  IF NOT FOUND THEN
    INSERT INTO public.dungeon_siege_bans (player_id, dungeon_id, banned_until, reason)
    VALUES (p_player_id, p_dungeon_id, v_until, p_reason);
  END IF;
END;
$$;
