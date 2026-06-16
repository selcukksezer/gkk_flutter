-- Fix get_current_election: record pollution + FOUND checks + grant

BEGIN;

CREATE OR REPLACE FUNCTION public.get_current_election()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_election public.kingdom_elections%ROWTYPE;
  v_loop_id uuid;
  v_candidates json;
  v_winner record;
  v_voting_open boolean;
BEGIN
  -- Auto-finalize overdue elections
  FOR v_loop_id IN
    SELECT id FROM public.kingdom_elections
    WHERE status = 'active'
      AND end_at IS NOT NULL
      AND end_at <= now()
  LOOP
    PERFORM public.finalize_kingdom_election(v_loop_id);
  END LOOP;

  v_election := NULL;

  -- Prefer active election
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
        g.id,
        g.name,
        COUNT(v.id)::integer AS vote_count
      FROM public.guilds g
      LEFT JOIN public.kingdom_election_votes v
        ON v.candidate_guild_id = g.id AND v.election_id = v_election.id
      GROUP BY g.id, g.name
      ORDER BY COUNT(v.id) DESC, g.name
    ) c;

    IF v_election.end_at IS NOT NULL AND v_election.end_at <= now() THEN
      PERFORM public.finalize_kingdom_election(v_election.id);
    ELSE
      RETURN json_build_object(
        'active', true,
        'status', 'active',
        'voting_open', v_voting_open,
        'id', v_election.id,
        'month', v_election.month,
        'start_at', v_election.start_at,
        'end_at', v_election.end_at,
        'candidates', v_candidates,
        'winner', NULL
      );
    END IF;
  END IF;

  v_election := NULL;

  -- Latest completed election → show king
  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE status = 'completed'
  ORDER BY end_at DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- Fallback: latest row (e.g. active missed by race)
    SELECT * INTO v_election
    FROM public.kingdom_elections
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN json_build_object('active', false, 'status', 'none');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) INTO v_candidates
  FROM (
    SELECT
      g.id,
      g.name,
      COUNT(v.id)::integer AS vote_count
    FROM public.guilds g
    LEFT JOIN public.kingdom_election_votes v
      ON v.candidate_guild_id = g.id AND v.election_id = v_election.id
    GROUP BY g.id, g.name
    ORDER BY COUNT(v.id) DESC, g.name
  ) c;

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
      'winner', NULL
    );
  END IF;

  SELECT g.id, g.name, COUNT(v.id)::integer AS vote_count
  INTO v_winner
  FROM public.guilds g
  LEFT JOIN public.kingdom_election_votes v
    ON v.candidate_guild_id = g.id AND v.election_id = v_election.id
  WHERE g.id = v_election.winner_guild_id
  GROUP BY g.id, g.name;

  IF v_winner IS NULL AND v_election.winner_guild_id IS NOT NULL THEN
    SELECT g.id, g.name, 0 AS vote_count
    INTO v_winner
    FROM public.guilds g
    WHERE g.id = v_election.winner_guild_id;
  END IF;

  IF v_winner IS NULL THEN
    SELECT g.id, g.name, COUNT(v.id)::integer AS vote_count
    INTO v_winner
    FROM public.kingdom_election_votes v
    JOIN public.guilds g ON g.id = v.candidate_guild_id
    WHERE v.election_id = v_election.id
    GROUP BY g.id, g.name
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
      'name', v_winner.name,
      'vote_count', v_winner.vote_count
    ) END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_current_election() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_election() TO anon;

COMMIT;
