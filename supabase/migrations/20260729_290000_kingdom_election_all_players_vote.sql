-- Krallık oylaması: tüm oyuncular oy kullanabilir (lonca/lider kısıtı kaldırıldı).

BEGIN;

ALTER TABLE public.kingdom_election_votes
  ADD COLUMN IF NOT EXISTS voter_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

UPDATE public.kingdom_election_votes kev
SET voter_user_id = g.leader_id
FROM public.guilds g
WHERE kev.voter_user_id IS NULL
  AND kev.voter_guild_id = g.id
  AND g.leader_id IS NOT NULL;

ALTER TABLE public.kingdom_election_votes
  DROP CONSTRAINT IF EXISTS kingdom_election_votes_election_id_voter_guild_id_key;

DROP INDEX IF EXISTS public.kingdom_election_votes_election_voter_user_uidx;
CREATE UNIQUE INDEX kingdom_election_votes_election_voter_user_uidx
  ON public.kingdom_election_votes (election_id, voter_user_id)
  WHERE voter_user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public._kingdom_election_voter_context(
  p_election_id uuid,
  p_voting_open boolean
)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
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

  IF p_election_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.kingdom_election_votes
      WHERE election_id = p_election_id
        AND voter_user_id = v_auth_id
    ) INTO v_already_voted;
  END IF;

  SELECT u.guild_id, (g.leader_id = v_auth_id)
  INTO v_guild_id, v_is_leader
  FROM public.users u
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE u.auth_id = v_auth_id;

  IF v_guild_id IS NOT NULL THEN
    v_guild_rank := public._guild_war_season_rank(v_guild_id);
  END IF;

  v_can_vote := COALESCE(p_voting_open, false) AND NOT v_already_voted;

  RETURN json_build_object(
    'is_leader', COALESCE(v_is_leader, false),
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
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_voter_guild_id uuid;
  v_candidate_rank integer;
  v_election record;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

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

  IF EXISTS (
    SELECT 1
    FROM public.kingdom_election_votes
    WHERE election_id = p_election_id
      AND voter_user_id = v_player_id
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Bu seçimde zaten oy kullandınız.');
  END IF;

  SELECT cg.season_rank
  INTO v_candidate_rank
  FROM public._kingdom_election_candidate_guilds(20) cg
  WHERE cg.guild_id = p_candidate_guild_id;

  IF v_candidate_rank IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Yalnızca sezon sıralamasında ilk 20 lonca aday olabilir.'
    );
  END IF;

  SELECT u.guild_id
  INTO v_voter_guild_id
  FROM public.users u
  WHERE u.auth_id = v_player_id;

  BEGIN
    INSERT INTO public.kingdom_election_votes (
      election_id,
      voter_user_id,
      voter_guild_id,
      candidate_guild_id
    )
    VALUES (
      p_election_id,
      v_player_id,
      v_voter_guild_id,
      p_candidate_guild_id
    );
  EXCEPTION WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'error', 'Bu seçimde zaten oy kullandınız.');
  END;

  RETURN json_build_object('success', true, 'message', 'Oyunuz başarıyla kaydedildi.');
END;
$$;

GRANT EXECUTE ON FUNCTION public._kingdom_election_voter_context(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vote_in_election(uuid, uuid) TO authenticated;

COMMIT;
