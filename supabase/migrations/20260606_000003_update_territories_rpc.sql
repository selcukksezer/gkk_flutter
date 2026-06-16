BEGIN;

CREATE OR REPLACE FUNCTION public.get_guild_war_territories()
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
      t.owner_guild_id,
      COALESCE(g.name, '—') AS "owner_guild",
      t.defense_power AS "defense_power",
      t.reward
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    ORDER BY t.name
  ) t;

  RETURN v_result;
END;
$$;

COMMIT;
