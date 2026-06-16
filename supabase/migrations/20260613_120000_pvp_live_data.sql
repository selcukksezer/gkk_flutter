-- PvP live data: dashboard, history, weekly tournament bracket RPCs.
-- Flutter screens call get_pvp_dashboard / get_pvp_history / get_tournament_bracket.

BEGIN;

-- ── Tournament schema ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.pvp_tournaments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  week_start DATE NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'registration'
    CHECK (status IN ('registration', 'active', 'completed')),
  registration_open BOOLEAN NOT NULL DEFAULT true,
  champion_user_id UUID REFERENCES auth.users(id),
  prize_pool BIGINT NOT NULL DEFAULT 10000,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.pvp_tournament_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES public.pvp_tournaments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  seed INT,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tournament_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.pvp_tournament_matches (
  id SERIAL PRIMARY KEY,
  tournament_id UUID NOT NULL REFERENCES public.pvp_tournaments(id) ON DELETE CASCADE,
  round_number INT NOT NULL,
  round_name TEXT NOT NULL,
  match_order INT NOT NULL,
  player1_id UUID REFERENCES auth.users(id),
  player2_id UUID REFERENCES auth.users(id),
  player1_score INT NOT NULL DEFAULT 0,
  player2_score INT NOT NULL DEFAULT 0,
  winner_id UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tournament_id, round_number, match_order)
);

ALTER TABLE public.pvp_tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pvp_tournament_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pvp_tournament_matches ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pvp_tournaments' AND policyname = 'pvp_tournaments_public_read'
  ) THEN
    CREATE POLICY pvp_tournaments_public_read ON public.pvp_tournaments FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pvp_tournament_participants' AND policyname = 'pvp_tournament_participants_public_read'
  ) THEN
    CREATE POLICY pvp_tournament_participants_public_read ON public.pvp_tournament_participants FOR SELECT USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pvp_tournament_matches' AND policyname = 'pvp_tournament_matches_public_read'
  ) THEN
    CREATE POLICY pvp_tournament_matches_public_read ON public.pvp_tournament_matches FOR SELECT USING (true);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_pvp_tournament_matches_tournament
  ON public.pvp_tournament_matches (tournament_id, round_number, match_order);

CREATE INDEX IF NOT EXISTS idx_pvp_tournament_participants_tournament
  ON public.pvp_tournament_participants (tournament_id, joined_at);

-- ── Helpers ───────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._pvp_round_name(p_participants INT, p_round INT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_rounds INT;
BEGIN
  v_rounds := CEIL(LOG(2, GREATEST(p_participants, 2)))::INT;
  IF p_round = v_rounds THEN RETURN 'Final'; END IF;
  IF p_round = v_rounds - 1 THEN RETURN 'Yarı Final'; END IF;
  IF p_round = v_rounds - 2 THEN RETURN 'Çeyrek Final'; END IF;
  RETURN 'Tur ' || p_round;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_current_pvp_tournament()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_week_start DATE := date_trunc('week', CURRENT_DATE)::DATE;
  v_tournament_id UUID;
  v_name TEXT;
BEGIN
  SELECT id INTO v_tournament_id
  FROM public.pvp_tournaments
  WHERE week_start = v_week_start;

  IF v_tournament_id IS NOT NULL THEN
    UPDATE public.pvp_tournaments
    SET registration_open = (CURRENT_TIMESTAMP < (week_start + INTERVAL '3 days')),
        updated_at = now()
    WHERE id = v_tournament_id;
    RETURN v_tournament_id;
  END IF;

  v_name := 'Haftalık PvP Şampiyonası — ' || to_char(v_week_start, 'DD Mon YYYY');

  INSERT INTO public.pvp_tournaments (name, week_start, status, registration_open, prize_pool)
  VALUES (v_name, v_week_start, 'registration', true, 10000)
  RETURNING id INTO v_tournament_id;

  RETURN v_tournament_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.seed_pvp_tournament_bracket(p_tournament_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_participant_count INT;
  v_bracket_size INT;
  v_rounds INT;
  v_round INT;
  v_match_order INT;
  v_slot INT;
  v_p1 UUID;
  v_p2 UUID;
  rec RECORD;
BEGIN
  SELECT COUNT(*) INTO v_participant_count
  FROM public.pvp_tournament_participants
  WHERE tournament_id = p_tournament_id;

  IF v_participant_count < 2 THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pvp_tournament_matches WHERE tournament_id = p_tournament_id
  ) THEN
    RETURN;
  END IF;

  v_bracket_size := 1;
  WHILE v_bracket_size < v_participant_count LOOP
    v_bracket_size := v_bracket_size * 2;
  END LOOP;

  v_rounds := CEIL(LOG(2, v_bracket_size))::INT;

  -- Round 1 pairings from seeded participants (rating DESC).
  v_match_order := 0;
  FOR rec IN
    SELECT p.user_id,
           ROW_NUMBER() OVER (
             ORDER BY COALESCE(u.pvp_rating, 1000) DESC, p.joined_at ASC
           ) AS rn
    FROM public.pvp_tournament_participants p
    JOIN public.users u ON u.auth_id = p.user_id
    WHERE p.tournament_id = p_tournament_id
  LOOP
    IF rec.rn % 2 = 1 THEN
      v_p1 := rec.user_id;
      v_p2 := NULL;
    ELSE
      v_p2 := rec.user_id;
      v_match_order := v_match_order + 1;
      INSERT INTO public.pvp_tournament_matches (
        tournament_id, round_number, round_name, match_order,
        player1_id, player2_id, status
      ) VALUES (
        p_tournament_id,
        1,
        public._pvp_round_name(v_bracket_size, 1),
        v_match_order,
        v_p1,
        v_p2,
        'pending'
      );
      v_p1 := NULL;
      v_p2 := NULL;
    END IF;
  END LOOP;

  IF v_p1 IS NOT NULL THEN
    v_match_order := v_match_order + 1;
    INSERT INTO public.pvp_tournament_matches (
      tournament_id, round_number, round_name, match_order,
      player1_id, player2_id, status
    ) VALUES (
      p_tournament_id,
      1,
      public._pvp_round_name(v_bracket_size, 1),
      v_match_order,
      v_p1,
      NULL,
      'pending'
    );
  END IF;

  -- Placeholder slots for later rounds.
  FOR v_round IN 2..v_rounds LOOP
    FOR v_match_order IN 1..(v_bracket_size / (2 ^ v_round)) LOOP
      INSERT INTO public.pvp_tournament_matches (
        tournament_id, round_number, round_name, match_order, status
      ) VALUES (
        p_tournament_id,
        v_round,
        public._pvp_round_name(v_bracket_size, v_round),
        v_match_order,
        'pending'
      );
    END LOOP;
  END LOOP;

  UPDATE public.pvp_tournaments
  SET status = 'active', registration_open = false, updated_at = now()
  WHERE id = p_tournament_id;
END;
$$;

-- ── Public RPCs ───────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_pvp_dashboard(p_match_limit INT DEFAULT 8)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_arenas JSONB;
  v_matches JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'name', m.name,
    'mekan_type', m.mekan_type
  ) ORDER BY m.name), '[]'::jsonb)
  INTO v_arenas
  FROM public.mekans m
  WHERE m.mekan_type IN ('dovus_kulubu', 'luks_lounge', 'yeralti')
    AND m.is_open = true;

  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('arenas', v_arenas, 'recent_matches', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
  INTO v_matches
  FROM (
    SELECT
      pm.id,
      pm.attacker_id,
      pm.defender_id,
      pm.winner_id,
      pm.gold_stolen,
      pm.rep_change_winner,
      pm.rep_change_loser,
      pm.is_critical_success,
      pm.attacker_hp_remaining,
      pm.created_at,
      ua.username AS attacker_username,
      ud.username AS defender_username
    FROM public.pvp_matches pm
    LEFT JOIN public.users ua ON ua.auth_id = pm.attacker_id
    LEFT JOIN public.users ud ON ud.auth_id = pm.defender_id
    WHERE pm.attacker_id = v_uid OR pm.defender_id = v_uid
    ORDER BY pm.created_at DESC
    LIMIT GREATEST(p_match_limit, 1)
  ) t;

  RETURN jsonb_build_object(
    'arenas', v_arenas,
    'recent_matches', v_matches
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_pvp_history(p_limit INT DEFAULT 50)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rows JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.', 'matches', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      pm.id,
      pm.attacker_id,
      pm.defender_id,
      pm.winner_id,
      pm.gold_stolen,
      pm.rep_change_winner,
      pm.rep_change_loser,
      pm.is_critical_success,
      pm.created_at,
      ua.username AS attacker_username,
      ud.username AS defender_username
    FROM public.pvp_matches pm
    LEFT JOIN public.users ua ON ua.auth_id = pm.attacker_id
    LEFT JOIN public.users ud ON ud.auth_id = pm.defender_id
    WHERE pm.attacker_id = v_uid OR pm.defender_id = v_uid
    ORDER BY pm.created_at DESC
    LIMIT GREATEST(p_limit, 1)
  ) t;

  RETURN jsonb_build_object('success', true, 'matches', v_rows);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_tournament_bracket()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_tournament_id UUID;
  v_tournament RECORD;
  v_rounds JSONB := '[]'::jsonb;
  v_champion_name TEXT := '';
  rec_round RECORD;
  v_matches JSONB;
BEGIN
  v_tournament_id := public.ensure_current_pvp_tournament();

  SELECT * INTO v_tournament
  FROM public.pvp_tournaments
  WHERE id = v_tournament_id;

  PERFORM public.seed_pvp_tournament_bracket(v_tournament_id);

  IF v_tournament.champion_user_id IS NOT NULL THEN
    SELECT username INTO v_champion_name
    FROM public.users
    WHERE auth_id = v_tournament.champion_user_id;
  ELSIF EXISTS (
    SELECT 1 FROM public.pvp_tournament_matches
    WHERE tournament_id = v_tournament_id AND round_number = (
      SELECT MAX(round_number) FROM public.pvp_tournament_matches WHERE tournament_id = v_tournament_id
    ) AND status = 'completed' AND winner_id IS NOT NULL
  ) THEN
    SELECT u.username INTO v_champion_name
    FROM public.pvp_tournament_matches m
    JOIN public.users u ON u.auth_id = m.winner_id
    WHERE m.tournament_id = v_tournament_id
      AND m.round_number = (SELECT MAX(round_number) FROM public.pvp_tournament_matches WHERE tournament_id = v_tournament_id)
      AND m.status = 'completed'
    ORDER BY m.match_order
    LIMIT 1;
  END IF;

  FOR rec_round IN
    SELECT DISTINCT round_number, round_name
    FROM public.pvp_tournament_matches
    WHERE tournament_id = v_tournament_id
    ORDER BY round_number
  LOOP
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', m.id,
      'player1_name', COALESCE(u1.username, CASE WHEN m.player1_id IS NULL THEN 'BYE' ELSE '?' END),
      'player2_name', COALESCE(u2.username, CASE WHEN m.player2_id IS NULL THEN 'BYE' ELSE '?' END),
      'player1_score', m.player1_score,
      'player2_score', m.player2_score,
      'winner_name', COALESCE(uw.username, ''),
      'status', m.status
    ) ORDER BY m.match_order), '[]'::jsonb)
    INTO v_matches
    FROM public.pvp_tournament_matches m
    LEFT JOIN public.users u1 ON u1.auth_id = m.player1_id
    LEFT JOIN public.users u2 ON u2.auth_id = m.player2_id
    LEFT JOIN public.users uw ON uw.auth_id = m.winner_id
    WHERE m.tournament_id = v_tournament_id
      AND m.round_number = rec_round.round_number;

    v_rounds := v_rounds || jsonb_build_array(jsonb_build_object(
      'title', rec_round.round_name,
      'round_number', rec_round.round_number,
      'matches', v_matches
    ));
  END LOOP;

  RETURN jsonb_build_object(
    'tournament_id', v_tournament_id,
    'tournament_name', v_tournament.name,
    'champion_name', COALESCE(v_champion_name, ''),
    'registration_open', v_tournament.registration_open,
    'status', v_tournament.status,
    'participant_count', (
      SELECT COUNT(*) FROM public.pvp_tournament_participants WHERE tournament_id = v_tournament_id
    ),
    'prize_pool', v_tournament.prize_pool,
    'rounds', v_rounds
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.join_pvp_tournament()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_user RECORD;
  v_tournament_id UUID;
  v_tournament RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_uid;
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profil bulunamadı.');
  END IF;

  IF v_user.level < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Turnuva için minimum seviye 10.');
  END IF;

  IF v_user.hospital_until IS NOT NULL AND v_user.hospital_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastanedeyken turnuvaya katılamazsınız.');
  END IF;

  IF v_user.prison_until IS NOT NULL AND v_user.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hapishanedeyken turnuvaya katılamazsınız.');
  END IF;

  v_tournament_id := public.ensure_current_pvp_tournament();

  SELECT * INTO v_tournament FROM public.pvp_tournaments WHERE id = v_tournament_id;

  IF NOT v_tournament.registration_open THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kayıtlar kapalı.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pvp_tournament_participants
    WHERE tournament_id = v_tournament_id AND user_id = v_uid
  ) THEN
    RETURN jsonb_build_object('success', true, 'message', 'Zaten kayıtlısınız.');
  END IF;

  INSERT INTO public.pvp_tournament_participants (tournament_id, user_id)
  VALUES (v_tournament_id, v_uid);

  RETURN jsonb_build_object('success', true, 'message', 'Turnuvaya katıldınız.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_pvp_dashboard(INT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_pvp_history(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tournament_bracket() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.join_pvp_tournament() TO authenticated;

COMMIT;
