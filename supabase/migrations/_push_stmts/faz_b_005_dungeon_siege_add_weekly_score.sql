CREATE OR REPLACE FUNCTION public.dungeon_siege_add_weekly_score(
  p_player_id uuid,
  p_points integer DEFAULT 0,
  p_slot_minutes integer DEFAULT 0,
  p_challenges_won integer DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_week text := public.dungeon_siege_week_key();
  v_guild_id uuid;
BEGIN
  IF p_player_id IS NULL THEN
    RETURN;
  END IF;

  SELECT guild_id INTO v_guild_id
  FROM public.users
  WHERE auth_id = p_player_id;

  INSERT INTO public.dungeon_siege_weekly_scores (
    week_key, guild_id, player_id, points, slot_minutes, challenges_won
  ) VALUES (
    v_week, v_guild_id, p_player_id,
    GREATEST(0, COALESCE(p_points, 0)),
    GREATEST(0, COALESCE(p_slot_minutes, 0)),
    GREATEST(0, COALESCE(p_challenges_won, 0))
  )
  ON CONFLICT (week_key, player_id) DO UPDATE
  SET
    guild_id = EXCLUDED.guild_id,
    points = public.dungeon_siege_weekly_scores.points + EXCLUDED.points,
    slot_minutes = public.dungeon_siege_weekly_scores.slot_minutes + EXCLUDED.slot_minutes,
    challenges_won = public.dungeon_siege_weekly_scores.challenges_won + EXCLUDED.challenges_won,
    updated_at = now();
END;
$$;
