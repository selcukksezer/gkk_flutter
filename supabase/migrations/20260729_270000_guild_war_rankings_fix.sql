-- Guild war rankings: backfill, jsonb RPC, ilk sezon seed.

BEGIN;

CREATE OR REPLACE FUNCTION public._ensure_guild_war_rankings(p_season_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_season_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
  SELECT p_season_id, g.id, 0, 0, 0
  FROM public.guilds g
  ON CONFLICT (season_id, guild_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.rotate_guild_war_season()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old RECORD;
  v_new_id UUID;
BEGIN
  SELECT id, season_number, end_at
  INTO v_old
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF v_old IS NULL THEN
    INSERT INTO public.guild_war_seasons (season_number, week_number, start_at, end_at, is_active)
    VALUES (1, 1, now(), now() + interval '7 days', true)
    RETURNING id INTO v_new_id;

    PERFORM public._ensure_guild_war_rankings(v_new_id);

    INSERT INTO public.guild_war_tournaments (season_id, name, status, guild_count, prize_pool, start_at, end_at)
    VALUES
      (v_new_id, 'Haftalık Arena', 'active', 0, '50,000 Altın', now(), now() + interval '7 days'),
      (v_new_id, 'Sezon Finali', 'upcoming', 0, '250,000 Altın + Efsanevi Eşya', now() + interval '7 days', now() + interval '14 days');

    RETURN v_new_id;
  END IF;

  IF v_old.end_at > now() THEN
    PERFORM public._ensure_guild_war_rankings(v_old.id);
    RETURN v_old.id;
  END IF;

  UPDATE public.guild_war_seasons
  SET is_active = false
  WHERE id = v_old.id;

  INSERT INTO public.guild_war_seasons (season_number, week_number, start_at, end_at, is_active)
  VALUES (v_old.season_number + 1, 1, now(), now() + interval '7 days', true)
  RETURNING id INTO v_new_id;

  PERFORM public._ensure_guild_war_rankings(v_new_id);

  INSERT INTO public.guild_war_tournaments (season_id, name, status, guild_count, prize_pool, start_at, end_at)
  VALUES
    (v_new_id, 'Haftalık Arena', 'active', 0, '50,000 Altın', now(), now() + interval '7 days'),
    (v_new_id, 'Sezon Finali', 'upcoming', 0, '250,000 Altın + Efsanevi Eşya', now() + interval '7 days', now() + interval '14 days');

  RETURN v_new_id;
END;
$$;

DROP FUNCTION IF EXISTS public.get_guild_war_rankings();

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

GRANT EXECUTE ON FUNCTION public._ensure_guild_war_rankings(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_war_rankings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rotate_guild_war_season() TO service_role;

-- Mevcut aktif sezon için eksik satırları doldur.
DO $$
DECLARE
  v_season UUID;
BEGIN
  SELECT id INTO v_season
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY season_number DESC
  LIMIT 1;

  IF v_season IS NOT NULL THEN
    PERFORM public._ensure_guild_war_rankings(v_season);
  END IF;
END $$;

COMMIT;
