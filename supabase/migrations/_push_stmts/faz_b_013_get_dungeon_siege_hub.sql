CREATE OR REPLACE FUNCTION public.get_dungeon_siege_hub()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status jsonb;
  v_recent jsonb;
  v_leaderboard jsonb;
  v_territories jsonb;
  v_week text := public.dungeon_siege_week_key();
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_status := public.get_dungeon_siege_status(NULL);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'dungeon_id', c.dungeon_id,
    'challenger_name', COALESCE(uc.display_name, uc.username, '—'),
    'defender_name', COALESCE(ud.display_name, ud.username, '—'),
    'winner_name', COALESCE(uw.display_name, uw.username, '—'),
    'you_were_involved', auth.uid() IN (c.challenger_id, c.defender_id),
    'resolved_at', c.resolved_at
  ) ORDER BY c.resolved_at DESC), '[]'::jsonb)
  INTO v_recent
  FROM public.dungeon_siege_challenges c
  LEFT JOIN public.users uc ON uc.auth_id = c.challenger_id
  LEFT JOIN public.users ud ON ud.auth_id = c.defender_id
  LEFT JOIN public.users uw ON uw.auth_id = c.winner_id
  WHERE c.status = 'resolved'
    AND c.resolved_at > now() - interval '24 hours'
  LIMIT 30;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'rank', row_number,
    'player_id', s.player_id,
    'player_name', COALESCE(u.display_name, u.username, '—'),
    'guild_name', g.name,
    'points', s.points,
    'challenges_won', s.challenges_won,
    'slot_minutes', s.slot_minutes
  ) ORDER BY row_number), '[]'::jsonb)
  INTO v_leaderboard
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
    LIMIT 20
  ) s
  LEFT JOIN public.users u ON u.auth_id = s.player_id
  LEFT JOIN public.guilds g ON g.id = u.guild_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'zone_number', t.zone_number,
    'territory_name', t.name,
    'owner_guild_id', t.owner_guild_id,
    'owner_guild_name', COALESCE(g.name, 'Sahipsiz')
  ) ORDER BY t.zone_number), '[]'::jsonb)
  INTO v_territories
  FROM public.guild_war_territories t
  LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
  WHERE t.zone_number IS NOT NULL;

  RETURN jsonb_build_object(
    'week_key', v_week,
    'status', v_status,
    'recent_challenges', COALESCE(v_recent, '[]'::jsonb),
    'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb),
    'territories', COALESCE(v_territories, '[]'::jsonb)
  );
END;
$$;
