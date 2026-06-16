BEGIN;

-- Table for kingdom elections
CREATE TABLE IF NOT EXISTS public.kingdom_elections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month date NOT NULL, -- e.g., '2026-06-01' for June 2026
  status text DEFAULT 'active' CHECK (status IN ('active', 'completed')),
  winner_guild_id uuid REFERENCES public.guilds(id),
  created_at timestamptz DEFAULT now(),
  UNIQUE (month)
);

ALTER TABLE public.kingdom_elections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view elections" ON public.kingdom_elections FOR SELECT USING (true);

-- Table for election votes
CREATE TABLE IF NOT EXISTS public.kingdom_election_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  election_id uuid REFERENCES public.kingdom_elections(id) ON DELETE CASCADE,
  voter_guild_id uuid REFERENCES public.guilds(id) ON DELETE CASCADE,
  candidate_guild_id uuid REFERENCES public.guilds(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE (election_id, voter_guild_id)
);

ALTER TABLE public.kingdom_election_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view votes" ON public.kingdom_election_votes FOR SELECT USING (true);

-- RPC to get current election
CREATE OR REPLACE FUNCTION public.get_current_election()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_election record;
  v_candidates json;
BEGIN
  -- Get active election
  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE status = 'active'
  ORDER BY month DESC
  LIMIT 1;

  IF v_election IS NULL THEN
    RETURN json_build_object('active', false);
  END IF;

  -- Get candidates and vote counts
  SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) INTO v_candidates
  FROM (
    SELECT 
      g.id,
      g.name,
      COUNT(v.id) as vote_count
    FROM public.guilds g
    LEFT JOIN public.kingdom_election_votes v ON v.candidate_guild_id = g.id AND v.election_id = v_election.id
    GROUP BY g.id, g.name
    ORDER BY vote_count DESC
  ) c;

  RETURN json_build_object(
    'active', true,
    'id', v_election.id,
    'month', v_election.month,
    'candidates', v_candidates
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_current_election() TO authenticated;

-- RPC to vote in election
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
BEGIN
  -- Get player's guild and check if leader
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

  -- Insert vote
  BEGIN
    INSERT INTO public.kingdom_election_votes (election_id, voter_guild_id, candidate_guild_id)
    VALUES (p_election_id, v_voter_guild_id, p_candidate_guild_id);
  EXCEPTION WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'error', 'Bu seçimde zaten oy kullandınız.');
  END;

  RETURN json_build_object('success', true, 'message', 'Oyunuz başarıyla kaydedildi.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.vote_in_election(uuid, uuid) TO authenticated;

COMMIT;
