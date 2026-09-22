-- Fix kingdom vote FK: users.guild_id may point to deleted guild.
-- voter_guild_id is optional metadata; vote is keyed by voter_user_id.

BEGIN;

UPDATE public.users u
SET guild_id = NULL,
    updated_at = now()
WHERE u.guild_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.guilds g WHERE g.id = u.guild_id
  );

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
  INNER JOIN public.guilds g ON g.id = u.guild_id
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
  EXCEPTION
    WHEN unique_violation THEN
      RETURN json_build_object('success', false, 'error', 'Bu seçimde zaten oy kullandınız.');
    WHEN foreign_key_violation THEN
      RETURN json_build_object('success', false, 'error', 'Oy kaydedilemedi. Lonca bilgisi geçersiz.');
  END;

  RETURN json_build_object('success', true, 'message', 'Oyunuz başarıyla kaydedildi.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.vote_in_election(uuid, uuid) TO authenticated;

COMMIT;
