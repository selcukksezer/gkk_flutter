-- Krallık UI: aday + kral = lonca lideri adı; lonca adı ayrı alan.

DROP FUNCTION IF EXISTS public._kingdom_election_candidate_guilds(integer);

CREATE OR REPLACE FUNCTION public._kingdom_election_candidate_guilds(p_limit INT DEFAULT 20)
RETURNS TABLE(
  guild_id uuid,
  guild_name text,
  leader_username text,
  season_rank integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH active_season AS (
    SELECT id
    FROM public.guild_war_seasons
    WHERE is_active = true
    ORDER BY created_at DESC
    LIMIT 1
  ),
  ranked AS (
    SELECT
      r.guild_id,
      g.name AS guild_name,
      u.username AS leader_username,
      ROW_NUMBER() OVER (
        ORDER BY r.points DESC, r.wins DESC, g.name ASC
      )::integer AS season_rank
    FROM public.guild_war_rankings r
    JOIN public.guilds g ON g.id = r.guild_id
    LEFT JOIN public.users u ON u.auth_id = g.leader_id
    WHERE r.season_id = (SELECT id FROM active_season)
  )
  SELECT guild_id, guild_name, leader_username, season_rank
  FROM ranked
  WHERE season_rank <= GREATEST(p_limit, 1)
  ORDER BY season_rank;
$$;

CREATE OR REPLACE FUNCTION public.get_current_election()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_election public.kingdom_elections%ROWTYPE;
  v_candidates json;
  v_winner record;
  v_voter jsonb;
  v_voting_open boolean := false;
  v_reign jsonb := public._kingdom_reign_info();
  v_powers jsonb := public._kingdom_king_powers_context();
  v_auto_started uuid;
  v_loop_id uuid;
BEGIN
  v_auto_started := public.ensure_monthly_kingdom_election();

  FOR v_loop_id IN
    SELECT id FROM public.kingdom_elections
    WHERE status = 'active'
      AND end_at IS NOT NULL
      AND end_at <= now()
  LOOP
    PERFORM public.finalize_kingdom_election(v_loop_id);
  END LOOP;

  v_election := NULL;

  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE status = 'active'
  ORDER BY start_at DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_voting_open := (v_election.start_at IS NULL OR v_election.start_at <= now())
      AND (v_election.end_at IS NULL OR v_election.end_at > now());

    SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) INTO v_candidates
    FROM (
      SELECT
        cg.guild_id AS id,
        cg.guild_name,
        cg.leader_username,
        COALESCE(NULLIF(btrim(cg.leader_username), ''), cg.guild_name) AS name,
        cg.season_rank AS rank,
        COUNT(v.id)::integer AS vote_count,
        (cg.season_rank = 1) AS is_rank_one
      FROM public._kingdom_election_candidate_guilds(20) cg
      LEFT JOIN public.kingdom_election_votes v
        ON v.candidate_guild_id = cg.guild_id AND v.election_id = v_election.id
      GROUP BY cg.guild_id, cg.guild_name, cg.leader_username, cg.season_rank
      ORDER BY cg.season_rank
    ) c;

    IF v_election.end_at IS NOT NULL AND v_election.end_at <= now() THEN
      PERFORM public.finalize_kingdom_election(v_election.id);
    ELSE
      v_voter := public._kingdom_election_voter_context(v_election.id, v_voting_open);

      RETURN json_build_object(
        'active', true,
        'status', 'active',
        'voting_open', v_voting_open,
        'id', v_election.id,
        'month', v_election.month,
        'start_at', v_election.start_at,
        'end_at', v_election.end_at,
        'candidates', v_candidates,
        'winner', NULL,
        'voter', v_voter,
        'reigning_king', v_reign,
        'king_powers', v_powers,
        'auto_started_election_id', v_auto_started
      );
    END IF;
  END IF;

  v_election := NULL;
  v_reign := public._kingdom_reign_info();
  v_powers := public._kingdom_king_powers_context();

  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE status = 'completed'
  ORDER BY end_at DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT * INTO v_election
    FROM public.kingdom_elections
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'active', false,
      'status', 'none',
      'reigning_king', v_reign,
      'king_powers', v_powers
    );
  END IF;

  SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) INTO v_candidates
  FROM (
    SELECT
      cg.guild_id AS id,
      cg.guild_name,
      cg.leader_username,
      COALESCE(NULLIF(btrim(cg.leader_username), ''), cg.guild_name) AS name,
      cg.season_rank AS rank,
      COUNT(v.id)::integer AS vote_count,
      (cg.season_rank = 1) AS is_rank_one
    FROM public._kingdom_election_candidate_guilds(20) cg
    LEFT JOIN public.kingdom_election_votes v
      ON v.candidate_guild_id = cg.guild_id AND v.election_id = v_election.id
    GROUP BY cg.guild_id, cg.guild_name, cg.leader_username, cg.season_rank
    ORDER BY cg.season_rank
  ) c;

  v_voter := public._kingdom_election_voter_context(v_election.id, false);

  IF v_election.status = 'active' THEN
    RETURN json_build_object(
      'active', true,
      'status', 'active',
      'voting_open', false,
      'id', v_election.id,
      'month', v_election.month,
      'start_at', v_election.start_at,
      'end_at', v_election.end_at,
      'candidates', v_candidates,
      'winner', NULL,
      'voter', v_voter,
      'reigning_king', v_reign,
      'king_powers', v_powers
    );
  END IF;

  SELECT
    g.id,
    g.name AS guild_name,
    u.username AS leader_username,
    COUNT(v.id)::integer AS vote_count
  INTO v_winner
  FROM public.guilds g
  LEFT JOIN public.users u ON u.auth_id = g.leader_id
  LEFT JOIN public.kingdom_election_votes v
    ON v.candidate_guild_id = g.id AND v.election_id = v_election.id
  WHERE g.id = v_election.winner_guild_id
  GROUP BY g.id, g.name, u.username;

  IF v_winner IS NULL AND v_election.winner_guild_id IS NOT NULL THEN
    SELECT
      g.id,
      g.name AS guild_name,
      u.username AS leader_username,
      0 AS vote_count
    INTO v_winner
    FROM public.guilds g
    LEFT JOIN public.users u ON u.auth_id = g.leader_id
    WHERE g.id = v_election.winner_guild_id;
  END IF;

  IF v_winner IS NULL THEN
    SELECT
      g.id,
      g.name AS guild_name,
      u.username AS leader_username,
      COUNT(v.id)::integer AS vote_count
    INTO v_winner
    FROM public.kingdom_election_votes v
    JOIN public.guilds g ON g.id = v.candidate_guild_id
    LEFT JOIN public.users u ON u.auth_id = g.leader_id
    WHERE v.election_id = v_election.id
    GROUP BY g.id, g.name, u.username
    ORDER BY COUNT(*) DESC, g.id
    LIMIT 1;
  END IF;

  RETURN json_build_object(
    'active', false,
    'status', 'completed',
    'voting_open', false,
    'id', v_election.id,
    'month', v_election.month,
    'start_at', v_election.start_at,
    'end_at', v_election.end_at,
    'candidates', v_candidates,
    'winner', CASE WHEN v_winner IS NULL THEN NULL ELSE json_build_object(
      'id', v_winner.id,
      'guild_name', v_winner.guild_name,
      'leader_username', v_winner.leader_username,
      'name', COALESCE(NULLIF(btrim(v_winner.leader_username), ''), v_winner.guild_name),
      'vote_count', v_winner.vote_count
    ) END,
    'voter', v_voter,
    'reigning_king', v_reign,
    'king_powers', v_powers
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_current_election() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_election() TO anon;
