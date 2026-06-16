-- ============================================================
-- Migration: Kingdom election — start/end times, finalize, start RPC
-- ============================================================

BEGIN;

ALTER TABLE public.kingdom_elections
  ADD COLUMN IF NOT EXISTS start_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS end_at timestamptz;

-- ─────────────────────────────────────────────────────────────
-- Finalize election: set winner = top vote guild, mark completed
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.finalize_kingdom_election(p_election_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_winner_id uuid;
  v_winner_name text;
  v_vote_count integer;
BEGIN
  SELECT
    v.candidate_guild_id,
    g.name,
    COUNT(*)::integer
  INTO v_winner_id, v_winner_name, v_vote_count
  FROM public.kingdom_election_votes v
  JOIN public.guilds g ON g.id = v.candidate_guild_id
  WHERE v.election_id = p_election_id
  GROUP BY v.candidate_guild_id, g.name
  ORDER BY COUNT(*) DESC, v.candidate_guild_id
  LIMIT 1;

  UPDATE public.kingdom_elections
  SET
    status = 'completed',
    winner_guild_id = v_winner_id,
    end_at = COALESCE(end_at, now())
  WHERE id = p_election_id
    AND status = 'active';

  RETURN json_build_object(
    'success', true,
    'winner_guild_id', v_winner_id,
    'winner_guild_name', v_winner_name,
    'vote_count', COALESCE(v_vote_count, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.finalize_kingdom_election(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- Start a new kingdom election (Supabase SQL / RPC)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.start_kingdom_election(
  p_end_at timestamptz,
  p_month date DEFAULT date_trunc('month', now())::date,
  p_start_at timestamptz DEFAULT now()
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_election_id uuid;
  v_active record;
BEGIN
  IF p_end_at IS NULL OR p_end_at <= p_start_at THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Bitiş zamanı başlangıçtan sonra olmalıdır.'
    );
  END IF;

  -- Finalize overdue active elections first
  FOR v_active IN
    SELECT id FROM public.kingdom_elections
    WHERE status = 'active'
      AND end_at IS NOT NULL
      AND end_at <= now()
  LOOP
    PERFORM public.finalize_kingdom_election(v_active.id);
  END LOOP;

  -- Close any still-active election before starting new one
  FOR v_active IN
    SELECT id FROM public.kingdom_elections WHERE status = 'active'
  LOOP
    PERFORM public.finalize_kingdom_election(v_active.id);
  END LOOP;

  INSERT INTO public.kingdom_elections (month, status, start_at, end_at, winner_guild_id)
  VALUES (p_month, 'active', p_start_at, p_end_at, NULL)
  ON CONFLICT (month) DO UPDATE SET
    status = 'active',
    start_at = EXCLUDED.start_at,
    end_at = EXCLUDED.end_at,
    winner_guild_id = NULL
  RETURNING id INTO v_election_id;

  RETURN json_build_object(
    'success', true,
    'election_id', v_election_id,
    'month', p_month,
    'start_at', p_start_at,
    'end_at', p_end_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_kingdom_election(timestamptz, date, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_kingdom_election(timestamptz, date, timestamptz) TO service_role;

-- ─────────────────────────────────────────────────────────────
-- get_current_election — auto-finalize + king display
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_current_election()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_election record;
  v_candidates json;
  v_winner record;
  v_voting_open boolean;
BEGIN
  -- Auto-finalize overdue elections
  FOR v_election IN
    SELECT id FROM public.kingdom_elections
    WHERE status = 'active'
      AND end_at IS NOT NULL
      AND end_at <= now()
  LOOP
    PERFORM public.finalize_kingdom_election(v_election.id);
  END LOOP;

  -- Prefer active election
  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE status = 'active'
  ORDER BY start_at DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF v_election IS NOT NULL THEN
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
      ORDER BY vote_count DESC, g.name
    ) c;

    IF NOT v_voting_open AND v_election.end_at IS NOT NULL AND v_election.end_at <= now() THEN
      PERFORM public.finalize_kingdom_election(v_election.id);
      -- fall through to completed branch below
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

  -- Latest completed election → show king
  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE status = 'completed'
  ORDER BY end_at DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF v_election IS NULL THEN
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
    ORDER BY vote_count DESC, g.name
  ) c;

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

-- ─────────────────────────────────────────────────────────────
-- vote_in_election — respect start/end window
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.vote_in_election(
  p_election_id uuid,
  p_candidate_guild_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_voter_guild_id uuid;
  v_is_leader boolean;
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

  SELECT g.id, (g.leader_id = v_player_id) INTO v_voter_guild_id, v_is_leader
  FROM public.guilds g
  JOIN public.users u ON u.guild_id = g.id
  WHERE u.auth_id = v_player_id;

  IF v_voter_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  IF NOT v_is_leader THEN
    RETURN json_build_object('success', false, 'error', 'Sadece lonca liderleri oy kullanabilir.');
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

COMMIT;
