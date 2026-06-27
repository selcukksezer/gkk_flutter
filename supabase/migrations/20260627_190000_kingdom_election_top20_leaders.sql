-- Krallık oylaması: yalnızca aktif sezon sıralamasında ilk 20 loncanın liderleri oy kullanabilir.

BEGIN;

CREATE OR REPLACE FUNCTION public._guild_war_season_rank(p_guild_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
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
      ROW_NUMBER() OVER (
        ORDER BY r.points DESC, r.wins DESC, g.name ASC
      )::integer AS rank
    FROM public.guild_war_rankings r
    JOIN public.guilds g ON g.id = r.guild_id
    WHERE r.season_id = (SELECT id FROM active_season)
  )
  SELECT rank FROM ranked WHERE guild_id = p_guild_id;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_election_voter_context(p_election_id uuid, p_voting_open boolean)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_id uuid := auth.uid();
  v_guild_id uuid;
  v_is_leader boolean := false;
  v_guild_rank integer;
  v_already_voted boolean := false;
  v_can_vote boolean := false;
BEGIN
  IF v_auth_id IS NULL THEN
    RETURN json_build_object(
      'is_leader', false,
      'guild_rank', NULL,
      'can_vote', false,
      'already_voted', false,
      'max_rank', 20
    );
  END IF;

  SELECT g.id, (g.leader_id = v_auth_id)
  INTO v_guild_id, v_is_leader
  FROM public.guilds g
  JOIN public.users u ON u.guild_id = g.id
  WHERE u.auth_id = v_auth_id;

  IF v_guild_id IS NOT NULL THEN
    v_guild_rank := public._guild_war_season_rank(v_guild_id);

    IF p_election_id IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1
        FROM public.kingdom_election_votes
        WHERE election_id = p_election_id
          AND voter_guild_id = v_guild_id
      ) INTO v_already_voted;
    END IF;

    v_can_vote := COALESCE(p_voting_open, false)
      AND v_is_leader
      AND v_guild_rank IS NOT NULL
      AND v_guild_rank <= 20
      AND NOT v_already_voted;
  END IF;

  RETURN json_build_object(
    'is_leader', v_is_leader,
    'guild_rank', v_guild_rank,
    'can_vote', v_can_vote,
    'already_voted', v_already_voted,
    'max_rank', 20
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.vote_in_election(
  p_election_id uuid,
  p_candidate_guild_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_voter_guild_id uuid;
  v_is_leader boolean;
  v_guild_rank integer;
  v_election record;
BEGIN
  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE id = p_election_id;

  IF v_election IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Seçim bulunamadı.');
  END IF;

  IF v_election.status != 'active' THEN
    RETURN json_build_object('success', false, 'error', 'Bu seçim artık aktif değil.');
  END IF;

  IF v_election.start_at IS NOT NULL AND v_election.start_at > now() THEN
    RETURN json_build_object('success', false, 'error', 'Seçim henüz başlamadı.');
  END IF;

  IF v_election.end_at IS NOT NULL AND v_election.end_at <= now() THEN
    PERFORM public.finalize_kingdom_election(p_election_id);
    RETURN json_build_object('success', false, 'error', 'Seçim süresi doldu.');
  END IF;

  SELECT g.id, (g.leader_id = v_player_id)
  INTO v_voter_guild_id, v_is_leader
  FROM public.guilds g
  JOIN public.users u ON u.guild_id = g.id
  WHERE u.auth_id = v_player_id;

  IF v_voter_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  IF NOT v_is_leader THEN
    RETURN json_build_object('success', false, 'error', 'Sadece lonca liderleri oy kullanabilir.');
  END IF;

  v_guild_rank := public._guild_war_season_rank(v_voter_guild_id);

  IF v_guild_rank IS NULL OR v_guild_rank > 20 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Krallık oylamasına yalnızca sezon sıralamasında ilk 20 loncanın liderleri katılabilir.'
    );
  END IF;

  BEGIN
    INSERT INTO public.kingdom_election_votes (election_id, voter_guild_id, candidate_guild_id)
    VALUES (p_election_id, v_voter_guild_id, p_candidate_guild_id);
  EXCEPTION WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'error', 'Bu seçimde zaten oy kullandınız.');
  END;

  RETURN json_build_object('success', true, 'message', 'Oyunuz başarıyla kaydedildi.');
END;
$$;

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
  v_voter json;
BEGIN
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
        'voter', v_voter
      );
    END IF;
  END IF;

  v_election := NULL;

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
      'voter', v_voter
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
    ) END,
    'voter', v_voter
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public._guild_war_season_rank(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._kingdom_election_voter_context(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vote_in_election(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_election() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_election() TO anon;

COMMIT;
