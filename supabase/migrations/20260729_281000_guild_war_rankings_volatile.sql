-- get_guild_war_rankings calls _ensure_guild_war_rankings (INSERT).
-- STABLE → PostgREST read-only tx → INSERT fails → client "rankings" error.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_guild_war_rankings()
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_active_season_id UUID;
BEGIN
  SELECT id INTO v_active_season_id
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY season_number DESC, created_at DESC
  LIMIT 1;

  IF v_active_season_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  PERFORM public._ensure_guild_war_rankings(v_active_season_id);

  RETURN COALESCE((
    SELECT jsonb_agg(row ORDER BY (row->>'points')::int DESC, (row->>'wins')::int DESC, row->>'guild_name')
    FROM (
      SELECT jsonb_build_object(
        'rank', ROW_NUMBER() OVER (ORDER BY r.points DESC, r.wins DESC, g.name ASC),
        'guild_id', g.id,
        'guild_name', g.name,
        'points', COALESCE(r.points, 0),
        'wins', COALESCE(r.wins, 0),
        'losses', COALESCE(r.losses, 0)
      ) AS row
      FROM public.guild_war_rankings r
      JOIN public.guilds g ON g.id = r.guild_id
      WHERE r.season_id = v_active_season_id
      ORDER BY r.points DESC, r.wins DESC, g.name ASC
      LIMIT 100
    ) ranked
  ), '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_rankings() TO authenticated;

COMMIT;
