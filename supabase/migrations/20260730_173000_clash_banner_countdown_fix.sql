-- Fix Clash hub banner: no more "Sonraki Clash 0:00" on stale start_at.
-- Prefer future events; active-without-my-match → waiting; expire past end_at.

BEGIN;

-- Close tournaments whose window already ended
UPDATE public.guild_war_tournaments
SET status = 'completed'
WHERE status IN ('active', 'upcoming', 'registration')
  AND end_at IS NOT NULL
  AND end_at < now();

-- Kill live/pending matches on expired tournaments (stale seed noise)
UPDATE public.guild_war_tournament_matches m
SET status = 'completed',
    window_end = COALESCE(m.window_end, now())
WHERE m.status IN ('live', 'pending')
  AND EXISTS (
    SELECT 1 FROM public.guild_war_tournaments t
    WHERE t.id = m.tournament_id
      AND (
        t.status = 'completed'
        OR (t.end_at IS NOT NULL AND t.end_at < now())
      )
  );

CREATE OR REPLACE FUNCTION public.cron_tournament_tick()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_t RECORD;
  v_m RECORD;
  v_opened INTEGER := 0;
  v_resolved INTEGER := 0;
  v_closed INTEGER := 0;
  v_expired INTEGER := 0;
  v_max_round INTEGER;
  v_pending_live INTEGER;
BEGIN
  -- Expire tournaments past end_at
  UPDATE public.guild_war_tournaments
  SET status = 'completed'
  WHERE status IN ('active', 'upcoming', 'registration')
    AND end_at IS NOT NULL
    AND end_at < now();
  GET DIAGNOSTICS v_expired = ROW_COUNT;

  -- Seed brackets for tournaments past start (still within end)
  FOR v_t IN
    SELECT * FROM public.guild_war_tournaments
    WHERE status IN ('upcoming', 'active', 'registration')
      AND start_at IS NOT NULL AND start_at <= now()
      AND (end_at IS NULL OR end_at > now())
  LOOP
    BEGIN
      PERFORM public.seed_guild_war_tournament_bracket(v_t.id);
      UPDATE public.guild_war_tournaments SET status = 'active' WHERE id = v_t.id AND status <> 'active';
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;

  -- Open next pending matches only on non-expired active tournaments
  FOR v_t IN
    SELECT id FROM public.guild_war_tournaments
    WHERE status = 'active'
      AND (end_at IS NULL OR end_at > now())
  LOOP
    SELECT COUNT(*) INTO v_pending_live
    FROM public.guild_war_tournament_matches
    WHERE tournament_id = v_t.id AND status = 'live';

    IF v_pending_live = 0 THEN
      FOR v_m IN
        SELECT *
        FROM public.guild_war_tournament_matches
        WHERE tournament_id = v_t.id
          AND status = 'pending'
          AND guild1_id IS NOT NULL
          AND guild2_id IS NOT NULL
        ORDER BY round_number ASC, match_order ASC
        LIMIT 4
      LOOP
        PERFORM public.open_tournament_match(v_m.id);
        v_opened := v_opened + 1;
      END LOOP;

      FOR v_m IN
        SELECT id FROM public.guild_war_tournament_matches
        WHERE tournament_id = v_t.id AND status = 'pending'
          AND (guild1_id IS NULL OR guild2_id IS NULL)
          AND (guild1_id IS NOT NULL OR guild2_id IS NOT NULL)
      LOOP
        PERFORM public.open_tournament_match(v_m.id);
      END LOOP;
    END IF;
  END LOOP;

  -- Resolve expired live windows
  FOR v_m IN
    SELECT id FROM public.guild_war_tournament_matches
    WHERE status = 'live'
      AND window_end IS NOT NULL
      AND window_end <= now()
  LOOP
    PERFORM public.resolve_tournament_match(v_m.id);
    v_resolved := v_resolved + 1;
  END LOOP;

  -- Close finished tournaments
  FOR v_t IN
    SELECT * FROM public.guild_war_tournaments
    WHERE status = 'active'
      AND (end_at IS NULL OR end_at > now())
  LOOP
    SELECT MAX(round_number) INTO v_max_round
    FROM public.guild_war_tournament_matches WHERE tournament_id = v_t.id;

    IF v_max_round IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.guild_war_tournament_matches
      WHERE tournament_id = v_t.id
        AND (status IN ('pending', 'live') OR winner_guild_id IS NULL)
    ) THEN
      PERFORM public.grant_guild_war_tournament_prize(v_t.id);
      v_closed := v_closed + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'opened', v_opened,
    'resolved', v_resolved,
    'closed', v_closed,
    'expired', v_expired
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_live_guild_war_clash(p_guild_id UUID DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_guild UUID := p_guild_id;
  v_row jsonb;
  v_t RECORD;
  v_next_at TIMESTAMPTZ;
  v_phase TEXT;
BEGIN
  IF v_guild IS NULL AND v_uid IS NOT NULL THEN
    SELECT guild_id INTO v_guild FROM public.users WHERE auth_id = v_uid;
  END IF;

  -- 1) My live match
  SELECT jsonb_build_object(
    'match_id', m.id,
    'tournament_id', m.tournament_id,
    'tournament_name', t.name,
    'round_name', m.round_name,
    'status', 'live',
    'window_start', m.window_start,
    'window_end', m.window_end,
    'guild1_id', m.guild1_id,
    'guild1_name', g1.name,
    'guild1_score', COALESCE(m.guild1_clash_score, m.guild1_score, 0),
    'guild2_id', m.guild2_id,
    'guild2_name', g2.name,
    'guild2_score', COALESCE(m.guild2_clash_score, m.guild2_score, 0),
    'prize_pool', t.prize_pool
  )
  INTO v_row
  FROM public.guild_war_tournament_matches m
  JOIN public.guild_war_tournaments t ON t.id = m.tournament_id
  LEFT JOIN public.guilds g1 ON g1.id = m.guild1_id
  LEFT JOIN public.guilds g2 ON g2.id = m.guild2_id
  WHERE m.status = 'live'
    AND (m.window_end IS NULL OR m.window_end > now())
    AND (v_guild IS NULL OR m.guild1_id = v_guild OR m.guild2_id = v_guild)
  ORDER BY m.window_end ASC NULLS LAST
  LIMIT 1;

  IF v_row IS NOT NULL THEN
    RETURN v_row;
  END IF;

  -- 2) Active tournament in season but my match not live yet
  SELECT t.* INTO v_t
  FROM public.guild_war_tournaments t
  WHERE t.status = 'active'
    AND (t.end_at IS NULL OR t.end_at > now())
  ORDER BY t.start_at DESC NULLS LAST
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'status', 'waiting',
      'phase', 'bracket',
      'next_tournament_id', v_t.id,
      'next_tournament_name', v_t.name,
      'next_start_at', NULL,
      'prize_pool', v_t.prize_pool,
      'message', 'Clash aktif — senin maç penceren açılınca burada görünür.'
    );
  END IF;

  -- 3) Future registration / start (real countdown)
  SELECT t.* INTO v_t
  FROM public.guild_war_tournaments t
  WHERE t.status IN ('upcoming', 'registration')
    AND (
      (t.registration_opens_at IS NOT NULL AND t.registration_opens_at > now())
      OR (t.registration_closes_at IS NOT NULL AND t.registration_closes_at > now())
      OR (t.start_at IS NOT NULL AND t.start_at > now())
    )
    AND (t.end_at IS NULL OR t.end_at > now())
  ORDER BY COALESCE(t.registration_opens_at, t.start_at) ASC NULLS LAST
  LIMIT 1;

  IF FOUND THEN
    IF v_t.registration_opens_at IS NOT NULL AND v_t.registration_opens_at > now() THEN
      v_next_at := v_t.registration_opens_at;
      v_phase := 'registration_opens';
    ELSIF v_t.registration_closes_at IS NOT NULL
          AND v_t.status = 'registration'
          AND v_t.registration_closes_at > now() THEN
      v_next_at := v_t.registration_closes_at;
      v_phase := 'registration_closes';
    ELSIF v_t.start_at IS NOT NULL AND v_t.start_at > now() THEN
      v_next_at := v_t.start_at;
      v_phase := 'starts';
    ELSE
      v_next_at := COALESCE(v_t.start_at, v_t.registration_opens_at);
      v_phase := 'upcoming';
    END IF;

    RETURN jsonb_build_object(
      'status', 'idle',
      'phase', v_phase,
      'next_tournament_id', v_t.id,
      'next_tournament_name', v_t.name,
      'next_start_at', v_next_at,
      'registration_opens_at', v_t.registration_opens_at,
      'registration_closes_at', v_t.registration_closes_at,
      'prize_pool', v_t.prize_pool
    );
  END IF;

  -- 4) Spectator: any live clash elsewhere
  SELECT jsonb_build_object(
    'match_id', m.id,
    'tournament_id', m.tournament_id,
    'tournament_name', t.name,
    'round_name', m.round_name,
    'status', 'spectator',
    'window_start', m.window_start,
    'window_end', m.window_end,
    'guild1_id', m.guild1_id,
    'guild1_name', g1.name,
    'guild1_score', COALESCE(m.guild1_clash_score, m.guild1_score, 0),
    'guild2_id', m.guild2_id,
    'guild2_name', g2.name,
    'guild2_score', COALESCE(m.guild2_clash_score, m.guild2_score, 0),
    'prize_pool', t.prize_pool,
    'message', 'Canlı Clash var (senin loncan maçta değil).'
  )
  INTO v_row
  FROM public.guild_war_tournament_matches m
  JOIN public.guild_war_tournaments t ON t.id = m.tournament_id
  LEFT JOIN public.guilds g1 ON g1.id = m.guild1_id
  LEFT JOIN public.guilds g2 ON g2.id = m.guild2_id
  WHERE m.status = 'live'
    AND (m.window_end IS NULL OR m.window_end > now())
  ORDER BY m.window_end ASC NULLS LAST
  LIMIT 1;

  IF v_row IS NOT NULL THEN
    RETURN v_row;
  END IF;

  RETURN jsonb_build_object(
    'status', 'idle',
    'phase', 'none',
    'message', 'Yakında yeni Clash açılacak.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cron_tournament_tick() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cron_tournament_tick() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_live_guild_war_clash(uuid) TO authenticated;

-- One tick to expire stale + open valid windows
SELECT public.cron_tournament_tick();

COMMIT;
