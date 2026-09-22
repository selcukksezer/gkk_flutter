-- Faz F: Guild prestige + season score events + rankings breakdown.

BEGIN;

CREATE TABLE IF NOT EXISTS public.guild_season_score_events (
  id BIGSERIAL PRIMARY KEY,
  season_id UUID NOT NULL REFERENCES public.guild_war_seasons(id) ON DELETE CASCADE,
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  points INTEGER NOT NULL,
  actor_id UUID,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_season_score_events_guild
  ON public.guild_season_score_events (season_id, guild_id, created_at DESC);

ALTER TABLE public.guild_war_rankings
  ADD COLUMN IF NOT EXISTS prestige INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rank_score INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS breakdown JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION public._guild_season_add_points(
  p_guild_id UUID,
  p_kind TEXT,
  p_points INTEGER,
  p_actor UUID DEFAULT NULL,
  p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season UUID;
BEGIN
  IF p_guild_id IS NULL OR COALESCE(p_points, 0) = 0 THEN
    RETURN;
  END IF;

  SELECT id INTO v_season
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_season IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.guild_season_score_events (season_id, guild_id, kind, points, actor_id, payload)
  VALUES (v_season, p_guild_id, p_kind, p_points, p_actor, COALESCE(p_payload, '{}'::jsonb));

  INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses, rank_score)
  VALUES (v_season, p_guild_id, p_points, 0, 0, p_points)
  ON CONFLICT (season_id, guild_id) DO UPDATE SET
    points = guild_war_rankings.points + p_points,
    rank_score = guild_war_rankings.points + p_points + FLOOR(guild_war_rankings.prestige * 0.25)::INTEGER,
    updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.recompute_guild_prestige(p_guild_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season UUID;
  v_power_raw BIGINT := 0;
  v_power_extra BIGINT := 0;
  v_p_power INTEGER;
  v_active_7d INTEGER := 0;
  v_member_count INTEGER := 0;
  v_p_activity INTEGER;
  v_hold NUMERIC := 0;
  v_p_hold INTEGER;
  v_avg_rating NUMERIC := 0;
  v_pvp_count INTEGER := 0;
  v_p_pvp INTEGER;
  v_vault BIGINT := 0;
  v_pending BIGINT := 0;
  v_monument INTEGER := 0;
  v_p_econ INTEGER;
  v_prestige INTEGER;
  v_breakdown JSONB;
  v_points INTEGER := 0;
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT id INTO v_season FROM public.guild_war_seasons
  WHERE is_active = true ORDER BY created_at DESC LIMIT 1;

  -- Top-15 power
  SELECT COALESCE(SUM(p), 0) INTO v_power_raw FROM (
    SELECT COALESCE(power, 0) AS p
    FROM public.users WHERE guild_id = p_guild_id
    ORDER BY COALESCE(power, 0) DESC
    LIMIT 15
  ) t;

  SELECT COALESCE(SUM(p), 0) INTO v_power_extra FROM (
    SELECT COALESCE(power, 0) AS p
    FROM public.users WHERE guild_id = p_guild_id
    ORDER BY COALESCE(power, 0) DESC
    OFFSET 15
  ) t;

  v_p_power := (LN(1 + v_power_raw + (v_power_extra * 0.30)) / LN(2) * 120)::INTEGER;

  SELECT COUNT(*) INTO v_member_count FROM public.users WHERE guild_id = p_guild_id;
  SELECT COUNT(*) INTO v_active_7d FROM public.users
  WHERE guild_id = p_guild_id AND last_active_at > now() - interval '7 days';

  v_p_activity := (
    (v_active_7d::NUMERIC / GREATEST(v_member_count, 1)) * 800
    + LEAST(v_active_7d, 20) * 25
  )::INTEGER;

  SELECT COALESCE(SUM(
    CASE COALESCE(t.zone_number, 1)
      WHEN 1 THEN 1.0 WHEN 2 THEN 1.1 WHEN 3 THEN 1.2 WHEN 4 THEN 1.35
      WHEN 5 THEN 1.5 WHEN 6 THEN 1.65 ELSE 1.8
    END * (1.0 + LEAST(
      (SELECT COUNT(*)::NUMERIC FROM public.guild_war_garrison g WHERE g.territory_id = t.id)
        / GREATEST((SELECT COUNT(*)::NUMERIC FROM public.users u WHERE u.guild_id = p_guild_id), 1),
      1.0
    ))
  ), 0) INTO v_hold
  FROM public.guild_war_territories t
  WHERE t.owner_guild_id = p_guild_id;

  v_p_hold := (v_hold * 180)::INTEGER;

  SELECT COALESCE(AVG(pvp_rating), 0), COUNT(*) FILTER (WHERE COALESCE(pvp_rating, 0) > 0)
  INTO v_avg_rating, v_pvp_count
  FROM public.users WHERE guild_id = p_guild_id;

  v_p_pvp := (
    LN(1 + GREATEST(v_avg_rating, 0)) / LN(2) * 90
    + LEAST(v_pvp_count, 15) * 20
  )::INTEGER;

  SELECT COALESCE(vault_gold, 0), COALESCE(vault_gold_pending, 0), COALESCE(monument_level, 0)
  INTO v_vault, v_pending, v_monument
  FROM public.guilds WHERE id = p_guild_id;

  v_p_econ := (
    LN(1 + v_vault + v_pending / 2) / LN(2) * 40
    + v_monument * 30
  )::INTEGER;

  v_prestige := GREATEST(0, v_p_power + v_p_activity + v_p_hold + v_p_pvp + v_p_econ);
  v_breakdown := jsonb_build_object(
    'power', v_p_power,
    'activity', v_p_activity,
    'hold', v_p_hold,
    'pvp', v_p_pvp,
    'economy', v_p_econ
  );

  IF v_season IS NOT NULL THEN
    PERFORM public._ensure_guild_war_rankings(v_season);
    SELECT points INTO v_points FROM public.guild_war_rankings
    WHERE season_id = v_season AND guild_id = p_guild_id;

    UPDATE public.guild_war_rankings
    SET prestige = v_prestige,
        breakdown = v_breakdown,
        rank_score = COALESCE(v_points, 0) + FLOOR(v_prestige * 0.25)::INTEGER,
        updated_at = now()
    WHERE season_id = v_season AND guild_id = p_guild_id;
  END IF;

  RETURN v_prestige;
END;
$$;

CREATE OR REPLACE FUNCTION public.recompute_all_guild_prestige()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row RECORD;
  v_n INTEGER := 0;
BEGIN
  FOR v_row IN SELECT id FROM public.guilds LOOP
    PERFORM public.recompute_guild_prestige(v_row.id);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
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
  v_season UUID;
BEGIN
  SELECT id INTO v_season FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY season_number DESC, created_at DESC
  LIMIT 1;

  IF v_season IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  PERFORM public._ensure_guild_war_rankings(v_season);
  PERFORM public.recompute_all_guild_prestige();

  RETURN COALESCE((
    SELECT jsonb_agg(row ORDER BY (row->>'rank_score')::int DESC, (row->>'prestige')::int DESC)
    FROM (
      SELECT jsonb_build_object(
        'rank', ROW_NUMBER() OVER (ORDER BY rk.rank_score DESC, rk.prestige DESC, g.name ASC),
        'guild_id', g.id,
        'guild_name', g.name,
        'guild_tag', g.tag,
        'points', COALESCE(rk.points, 0),
        'prestige', COALESCE(rk.prestige, 0),
        'rank_score', COALESCE(rk.rank_score, 0),
        'breakdown', COALESCE(rk.breakdown, '{}'::jsonb),
        'wins', COALESCE(rk.wins, 0),
        'losses', COALESCE(rk.losses, 0)
      ) AS row
      FROM public.guild_war_rankings rk
      JOIN public.guilds g ON g.id = rk.guild_id
      WHERE rk.season_id = v_season
      ORDER BY rk.rank_score DESC, rk.prestige DESC, g.name ASC
      LIMIT 100
    ) ranked
  ), '[]'::jsonb);
END;
$$;

-- Note: conquest points still written by attack_guild_war_territory.
-- _guild_season_add_points used by Clash (Faz G) to avoid double-count.

GRANT EXECUTE ON FUNCTION public.recompute_guild_prestige(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_all_guild_prestige() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_war_rankings() TO authenticated;

COMMIT;
