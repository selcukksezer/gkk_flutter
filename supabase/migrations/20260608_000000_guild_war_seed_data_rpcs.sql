BEGIN;

-- Tournament RPC: include schedule fields for UI progress
CREATE OR REPLACE FUNCTION public.get_guild_war_tournaments()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
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
    ORDER BY t.created_at DESC
  ) t;

  RETURN v_result;
END;
$$;

COMMIT;
