-- Guild war tournament bracket matches (single elimination, rank-based seeding).

CREATE TABLE IF NOT EXISTS public.guild_war_tournament_matches (
  id SERIAL PRIMARY KEY,
  tournament_id UUID NOT NULL REFERENCES public.guild_war_tournaments(id) ON DELETE CASCADE,
  round_number INT NOT NULL,
  round_name TEXT NOT NULL,
  match_order INT NOT NULL,
  guild1_id UUID REFERENCES public.guilds(id) ON DELETE SET NULL,
  guild2_id UUID REFERENCES public.guilds(id) ON DELETE SET NULL,
  guild1_score INT NOT NULL DEFAULT 0,
  guild2_score INT NOT NULL DEFAULT 0,
  winner_guild_id UUID REFERENCES public.guilds(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tournament_id, round_number, match_order)
);

ALTER TABLE public.guild_war_tournament_matches ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'guild_war_tournament_matches'
      AND policyname = 'guild_war_tournament_matches_public_read'
  ) THEN
    CREATE POLICY guild_war_tournament_matches_public_read
      ON public.guild_war_tournament_matches
      FOR SELECT
      USING (true);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_guild_war_tournament_matches_tournament
  ON public.guild_war_tournament_matches (tournament_id, round_number, match_order);

CREATE OR REPLACE FUNCTION public._guild_war_round_name(p_bracket_size INT, p_round INT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_rounds INT;
BEGIN
  v_rounds := CEIL(LOG(2, GREATEST(p_bracket_size, 2)))::INT;
  IF p_round = v_rounds THEN RETURN 'Final'; END IF;
  IF p_round = v_rounds - 1 THEN RETURN 'Yarı Final'; END IF;
  IF p_round = v_rounds - 2 THEN RETURN 'Çeyrek Final'; END IF;
  RETURN 'Tur ' || p_round;
END;
$$;

CREATE OR REPLACE FUNCTION public._guild_war_bracket_seed_order(p_size INT)
RETURNS INT[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_half INT[];
  v_result INT[] := '{}';
  v_s INT;
BEGIN
  IF p_size <= 1 THEN
    RETURN ARRAY[1];
  END IF;
  IF p_size = 2 THEN
    RETURN ARRAY[1, 2];
  END IF;

  v_half := public._guild_war_bracket_seed_order(p_size / 2);
  FOREACH v_s IN ARRAY v_half LOOP
    v_result := v_result || v_s || (p_size + 1 - v_s);
  END LOOP;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.seed_guild_war_tournament_bracket(p_tournament_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_tournament RECORD;
  v_participant_count INT;
  v_bracket_size INT;
  v_rounds INT;
  v_round INT;
  v_match_order INT;
  v_seed_order INT[];
  v_guild_ids UUID[];
  v_slots UUID[];
  v_slot INT;
  v_seed INT;
  v_g1 UUID;
  v_g2 UUID;
BEGIN
  SELECT t.id, t.status, t.season_id
  INTO v_tournament
  FROM public.guild_war_tournaments t
  WHERE t.id = p_tournament_id;

  IF v_tournament.id IS NULL OR v_tournament.status <> 'active' THEN
    RETURN;
  END IF;

  SELECT COUNT(*) INTO v_participant_count
  FROM public.guild_war_participants
  WHERE tournament_id = p_tournament_id;

  IF v_participant_count < 2 THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.guild_war_tournament_matches
    WHERE tournament_id = p_tournament_id
  ) THEN
    RETURN;
  END IF;

  v_bracket_size := 1;
  WHILE v_bracket_size < v_participant_count LOOP
    v_bracket_size := v_bracket_size * 2;
  END LOOP;

  v_rounds := CEIL(LOG(2, v_bracket_size))::INT;
  v_seed_order := public._guild_war_bracket_seed_order(v_bracket_size);
  v_slots := ARRAY_FILL(NULL::UUID, ARRAY[v_bracket_size]);

  SELECT COALESCE(array_agg(p.guild_id ORDER BY p.seed_rank), '{}'::uuid[])
  INTO v_guild_ids
  FROM (
    SELECT
      gp.guild_id,
      ROW_NUMBER() OVER (
        ORDER BY
          COALESCE(r.points, 0) DESC,
          gp.joined_at ASC
      ) AS seed_rank
    FROM public.guild_war_participants gp
    LEFT JOIN public.guild_war_rankings r
      ON r.guild_id = gp.guild_id
     AND r.season_id = v_tournament.season_id
    WHERE gp.tournament_id = p_tournament_id
  ) p;

  FOR v_slot IN 1..v_bracket_size LOOP
    v_seed := v_seed_order[v_slot];
    IF v_seed <= v_participant_count THEN
      v_slots[v_slot] := v_guild_ids[v_seed];
    END IF;
  END LOOP;

  v_match_order := 0;
  FOR v_slot IN 1..(v_bracket_size / 2) LOOP
    v_g1 := v_slots[(v_slot * 2) - 1];
    v_g2 := v_slots[v_slot * 2];
    v_match_order := v_match_order + 1;
    INSERT INTO public.guild_war_tournament_matches (
      tournament_id, round_number, round_name, match_order,
      guild1_id, guild2_id, status
    ) VALUES (
      p_tournament_id,
      1,
      public._guild_war_round_name(v_bracket_size, 1),
      v_match_order,
      v_g1,
      v_g2,
      CASE
        WHEN v_g1 IS NOT NULL AND v_g2 IS NULL THEN 'completed'
        WHEN v_g1 IS NULL AND v_g2 IS NOT NULL THEN 'completed'
        ELSE 'pending'
      END
    );
  END LOOP;

  -- Auto-advance BYE winners in round 1.
  UPDATE public.guild_war_tournament_matches m
  SET winner_guild_id = COALESCE(m.guild1_id, m.guild2_id)
  WHERE m.tournament_id = p_tournament_id
    AND m.round_number = 1
    AND m.status = 'completed'
    AND m.winner_guild_id IS NULL;

  FOR v_round IN 2..v_rounds LOOP
    FOR v_match_order IN 1..(v_bracket_size / (2 ^ v_round)) LOOP
      INSERT INTO public.guild_war_tournament_matches (
        tournament_id, round_number, round_name, match_order, status
      ) VALUES (
        p_tournament_id,
        v_round,
        public._guild_war_round_name(v_bracket_size, v_round),
        v_match_order,
        'pending'
      );
    END LOOP;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_guild_war_tournament_matches(p_tournament_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_rounds json := '[]'::json;
  rec_round RECORD;
  v_matches json;
BEGIN
  PERFORM public.seed_guild_war_tournament_bracket(p_tournament_id);

  FOR rec_round IN
    SELECT DISTINCT round_number, round_name
    FROM public.guild_war_tournament_matches
    WHERE tournament_id = p_tournament_id
    ORDER BY round_number
  LOOP
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."matchOrder"), '[]'::json)
    INTO v_matches
    FROM (
      SELECT
        m.id,
        m.round_number AS "roundNumber",
        m.round_name AS "roundName",
        m.match_order AS "matchOrder",
        m.guild1_id AS "guild1Id",
        COALESCE(g1.name, CASE WHEN m.guild1_id IS NULL THEN 'BYE' ELSE '?' END) AS "guild1Name",
        m.guild2_id AS "guild2Id",
        COALESCE(g2.name, CASE WHEN m.guild2_id IS NULL THEN 'BYE' ELSE '?' END) AS "guild2Name",
        m.guild1_score AS "guild1Score",
        m.guild2_score AS "guild2Score",
        m.winner_guild_id AS "winnerGuildId",
        COALESCE(gw.name, '') AS "winnerGuildName",
        m.status
      FROM public.guild_war_tournament_matches m
      LEFT JOIN public.guilds g1 ON g1.id = m.guild1_id
      LEFT JOIN public.guilds g2 ON g2.id = m.guild2_id
      LEFT JOIN public.guilds gw ON gw.id = m.winner_guild_id
      WHERE m.tournament_id = p_tournament_id
        AND m.round_number = rec_round.round_number
    ) t;

    v_rounds := v_rounds::jsonb || jsonb_build_array(
      jsonb_build_object(
        'title', rec_round.round_name,
        'roundNumber', rec_round.round_number,
        'matches', v_matches::jsonb
      )
    );
  END LOOP;

  RETURN v_rounds;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_war_tournament_matches(uuid) TO authenticated;
