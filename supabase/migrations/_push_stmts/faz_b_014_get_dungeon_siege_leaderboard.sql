CREATE OR REPLACE FUNCTION public.get_dungeon_siege_leaderboard(p_limit integer DEFAULT 20)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_week text := public.dungeon_siege_week_key();
  v_rows jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'rank', row_number,
    'player_id', s.player_id,
    'player_name', COALESCE(u.display_name, u.username, '—'),
    'guild_name', g.name,
    'points', s.points,
    'challenges_won', s.challenges_won,
    'slot_minutes', s.slot_minutes
  ) ORDER BY row_number), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      player_id,
      points,
      challenges_won,
      slot_minutes,
      ROW_NUMBER() OVER (ORDER BY points DESC, challenges_won DESC) AS row_number
    FROM public.dungeon_siege_weekly_scores
    WHERE week_key = v_week
    ORDER BY points DESC, challenges_won DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100))
  ) s
  LEFT JOIN public.users u ON u.auth_id = s.player_id
  LEFT JOIN public.guilds g ON g.id = u.guild_id;

  RETURN jsonb_build_object('week_key', v_week, 'entries', COALESCE(v_rows, '[]'::jsonb));
END;
$$;
