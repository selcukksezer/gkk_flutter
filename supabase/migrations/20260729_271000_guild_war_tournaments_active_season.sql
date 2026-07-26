-- Turnuva listesi: yalnızca aktif sezon.

BEGIN;

DROP FUNCTION IF EXISTS public.get_guild_war_tournaments();

CREATE OR REPLACE FUNCTION public.get_guild_war_tournaments()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
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

  RETURN COALESCE((
    SELECT jsonb_agg(row ORDER BY (row->>'start_at') ASC NULLS LAST)
    FROM (
      SELECT jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'status', t.status,
        'guildCount', COALESCE(t.guild_count, 0),
        'prizePool', COALESCE(t.prize_pool, ''),
        'start_at', t.start_at,
        'end_at', t.end_at
      ) AS row
      FROM public.guild_war_tournaments t
      WHERE t.season_id = v_active_season_id
        AND t.status IN ('active', 'upcoming')
      ORDER BY t.start_at ASC NULLS LAST
    ) scoped
  ), '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_tournaments() TO authenticated;

COMMIT;
