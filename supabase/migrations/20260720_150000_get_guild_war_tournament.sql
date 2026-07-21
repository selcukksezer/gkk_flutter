-- Single tournament fetch for deep links when hub cache misses the ID.

CREATE OR REPLACE FUNCTION public.get_guild_war_tournament(p_tournament_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT row_to_json(t)
  INTO v_result
  FROM (
    SELECT
      t.id,
      t.name,
      t.status,
      COALESCE(t.guild_count, 0) AS "guildCount",
      t.prize_pool AS "prizePool",
      t.start_at,
      t.end_at
    FROM public.guild_war_tournaments t
    WHERE t.id = p_tournament_id
    LIMIT 1
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_tournament(uuid) TO authenticated;
