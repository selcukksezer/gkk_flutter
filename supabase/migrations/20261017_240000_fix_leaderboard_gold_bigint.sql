-- Fix: users.gold / dungeon_runs.gold_earned are BIGINT (20260731222000),
-- but get_leaderboard still returned value INTEGER →
-- ERROR 42804: Returned type bigint does not match expected type integer in column 3.
-- Default tab = gold → "Sıralama yüklenemedi" on every open.

DROP FUNCTION IF EXISTS public.get_leaderboard(text, integer, text);

CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_category text,
  p_limit integer DEFAULT 30,
  p_timeframe text DEFAULT 'alltime'::text
)
RETURNS TABLE(rank integer, username text, value bigint, level integer, guild text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_week_start DATE := date_trunc('week', now())::DATE;
BEGIN
  IF p_timeframe = 'weekly' AND p_category = 'pvp_rating' THEN
    IF EXISTS (SELECT 1 FROM public.pvp_leaderboard WHERE week_start = v_week_start) THEN
      RETURN QUERY
      SELECT pl.rank::INT, u.username, pl.rating::BIGINT AS value, u.level, g.name AS guild
      FROM public.pvp_leaderboard pl
      JOIN public.users u ON pl.user_id = u.id
      LEFT JOIN public.guilds g ON u.guild_id = g.id
      WHERE pl.week_start = v_week_start
      ORDER BY pl.rank ASC
      LIMIT p_limit;
      RETURN;
    END IF;
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'guild_power' THEN
    IF EXISTS (SELECT 1 FROM public.guild_leaderboard WHERE week_start = v_week_start) THEN
      RETURN QUERY
      SELECT gl.rank::INT, g.name AS username, gl.monument_level::BIGINT AS value, g.level, g.tag AS guild
      FROM public.guild_leaderboard gl
      JOIN public.guilds g ON gl.guild_id = g.id
      WHERE gl.week_start = v_week_start
      ORDER BY gl.rank ASC
      LIMIT p_limit;
      RETURN;
    END IF;
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'gold' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY COALESCE(w.metric, 0) DESC))::INT AS rank,
      u.username,
      COALESCE(w.metric, 0)::BIGINT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    LEFT JOIN (
      SELECT dr.player_id AS user_id, SUM(COALESCE(dr.gold_earned, 0)) AS metric
      FROM public.dungeon_runs dr
      WHERE dr.created_at >= now() - interval '7 days'
        AND COALESCE(dr.success, false) = true
      GROUP BY dr.player_id
    ) w ON w.user_id = u.auth_id
    WHERE COALESCE(w.metric, 0) > 0
    ORDER BY COALESCE(w.metric, 0) DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'level' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY COALESCE(w.metric, 0) DESC))::INT AS rank,
      u.username,
      COALESCE(w.metric, 0)::BIGINT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    LEFT JOIN (
      SELECT dr.player_id AS user_id, SUM(COALESCE(dr.xp_earned, 0)) AS metric
      FROM public.dungeon_runs dr
      WHERE dr.created_at >= now() - interval '7 days'
        AND COALESCE(dr.success, false) = true
      GROUP BY dr.player_id
    ) w ON w.user_id = u.auth_id
    WHERE COALESCE(w.metric, 0) > 0
    ORDER BY COALESCE(w.metric, 0) DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'power' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY COALESCE(w.metric, 0) DESC))::INT AS rank,
      u.username,
      COALESCE(w.metric, 0)::BIGINT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    LEFT JOIN (
      SELECT dr.player_id AS user_id, MAX(COALESCE(dr.player_power, 0)) AS metric
      FROM public.dungeon_runs dr
      WHERE dr.created_at >= now() - interval '7 days'
      GROUP BY dr.player_id
    ) w ON w.user_id = u.auth_id
    WHERE COALESCE(w.metric, 0) > 0
    ORDER BY COALESCE(w.metric, 0) DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  IF p_category = 'gold' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY u.gold DESC))::INT AS rank,
      u.username,
      u.gold::BIGINT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    ORDER BY u.gold DESC
    LIMIT p_limit;
  ELSIF p_category = 'pvp_rating' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY u.pvp_rating DESC))::INT AS rank,
      u.username,
      u.pvp_rating::BIGINT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    ORDER BY u.pvp_rating DESC
    LIMIT p_limit;
  ELSIF p_category = 'level' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY u.level DESC, u.xp DESC))::INT AS rank,
      u.username,
      u.level::BIGINT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    ORDER BY u.level DESC, u.xp DESC
    LIMIT p_limit;
  ELSIF p_category = 'power' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY u.power DESC))::INT AS rank,
      u.username,
      u.power::BIGINT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    ORDER BY u.power DESC
    LIMIT p_limit;
  ELSIF p_category = 'guild_power' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY g.xp DESC))::INT AS rank,
      g.name AS username,
      g.xp::BIGINT AS value,
      g.level,
      g.tag AS guild
    FROM public.guilds g
    ORDER BY g.xp DESC
    LIMIT p_limit;
  END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_leaderboard(text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(text, integer, text) TO anon;

-- Rank helper: gold metric must not cast through INT4 (overflow risk after BIGINT widen).
CREATE OR REPLACE FUNCTION public.get_leaderboard_rank(
  p_category text,
  p_timeframe text DEFAULT 'alltime'::text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_auth_id UUID := auth.uid();
  v_rank INT;
  v_value BIGINT;
  v_rival_value BIGINT;
  v_gap BIGINT;
BEGIN
  IF v_auth_id IS NULL THEN
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'gold' THEN
    WITH weekly AS (
      SELECT u.auth_id,
             COALESCE(SUM(dr.gold_earned), 0)::BIGINT AS metric
      FROM public.users u
      LEFT JOIN public.dungeon_runs dr
        ON dr.player_id = u.auth_id
       AND dr.created_at >= now() - interval '7 days'
       AND COALESCE(dr.success, false) = true
      GROUP BY u.auth_id
    ),
    ranked AS (
      SELECT auth_id, metric,
             ROW_NUMBER() OVER (ORDER BY metric DESC) AS rk
      FROM weekly
      WHERE metric > 0
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_timeframe = 'weekly' AND p_category = 'level' THEN
    WITH weekly AS (
      SELECT u.auth_id,
             COALESCE(SUM(dr.xp_earned), 0)::BIGINT AS metric
      FROM public.users u
      LEFT JOIN public.dungeon_runs dr
        ON dr.player_id = u.auth_id
       AND dr.created_at >= now() - interval '7 days'
       AND COALESCE(dr.success, false) = true
      GROUP BY u.auth_id
    ),
    ranked AS (
      SELECT auth_id, metric,
             ROW_NUMBER() OVER (ORDER BY metric DESC) AS rk
      FROM weekly
      WHERE metric > 0
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_timeframe = 'weekly' AND p_category = 'power' THEN
    WITH weekly AS (
      SELECT u.auth_id,
             COALESCE(MAX(dr.player_power), 0)::BIGINT AS metric
      FROM public.users u
      LEFT JOIN public.dungeon_runs dr
        ON dr.player_id = u.auth_id
       AND dr.created_at >= now() - interval '7 days'
      GROUP BY u.auth_id
    ),
    ranked AS (
      SELECT auth_id, metric,
             ROW_NUMBER() OVER (ORDER BY metric DESC) AS rk
      FROM weekly
      WHERE metric > 0
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'gold' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.gold::BIGINT AS metric,
             ROW_NUMBER() OVER (ORDER BY u.gold DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'pvp_rating' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.pvp_rating::BIGINT AS metric,
             ROW_NUMBER() OVER (ORDER BY u.pvp_rating DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'level' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.level::BIGINT AS metric,
             ROW_NUMBER() OVER (ORDER BY u.level DESC, u.xp DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'power' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.power::BIGINT AS metric,
             ROW_NUMBER() OVER (ORDER BY u.power DESC NULLS LAST) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'guild_power' THEN
    WITH ranked AS (
      SELECT g.id AS guild_id, g.xp::BIGINT AS metric,
             ROW_NUMBER() OVER (ORDER BY g.xp DESC) AS rk
      FROM public.guilds g
    ),
    me AS (
      SELECT r.rk, r.metric
      FROM ranked r
      JOIN public.users u ON u.guild_id = r.guild_id
      WHERE u.auth_id = v_auth_id
    )
    SELECT me.rk::INT, me.metric,
           (SELECT metric FROM ranked WHERE rk = me.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM me;

  ELSE
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF v_rank IS NULL THEN
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF v_rank <= 1 OR v_rival_value IS NULL OR v_value IS NULL THEN
    v_gap := 0;
  ELSE
    v_gap := GREATEST(0, v_rival_value - v_value);
  END IF;

  RETURN json_build_object(
    'rank', v_rank,
    'value', v_value,
    'rival_value', v_rival_value,
    'gap', v_gap
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_leaderboard_rank(text, text) TO authenticated;
