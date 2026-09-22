-- Faz G: Lonca Clash tournament lifecycle + prize mint (§16 / §17.7).
-- Window 12h, weekly 8 slots, prizes 100M / 300M+leg+7 (system mint).

BEGIN;

-- ── Match columns for live Clash ────────────────────────────────────────────
ALTER TABLE public.guild_war_tournament_matches
  DROP CONSTRAINT IF EXISTS guild_war_tournament_matches_status_check;

ALTER TABLE public.guild_war_tournament_matches
  ADD COLUMN IF NOT EXISTS window_start TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS window_end TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS guild1_clash_score INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS guild2_clash_score INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.guild_war_tournament_matches
  ALTER COLUMN status DROP DEFAULT;

UPDATE public.guild_war_tournament_matches
SET status = 'pending'
WHERE status IS NULL OR status NOT IN ('pending', 'live', 'completed', 'forfeit');

ALTER TABLE public.guild_war_tournament_matches
  ADD CONSTRAINT guild_war_tournament_matches_status_check
  CHECK (status IN ('pending', 'live', 'completed', 'forfeit'));

ALTER TABLE public.guild_war_tournament_matches
  ALTER COLUMN status SET DEFAULT 'pending';

-- Sync clash scores from legacy score cols when missing
UPDATE public.guild_war_tournament_matches
SET guild1_clash_score = COALESCE(guild1_score, 0),
    guild2_clash_score = COALESCE(guild2_score, 0)
WHERE guild1_clash_score = 0 AND guild2_clash_score = 0
  AND (COALESCE(guild1_score, 0) > 0 OR COALESCE(guild2_score, 0) > 0);

ALTER TABLE public.guild_war_tournaments
  ADD COLUMN IF NOT EXISTS prize_gold BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tournament_kind TEXT NOT NULL DEFAULT 'weekly',
  ADD COLUMN IF NOT EXISTS max_slots INTEGER NOT NULL DEFAULT 8,
  ADD COLUMN IF NOT EXISTS registration_opens_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS registration_closes_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS winner_guild_id UUID REFERENCES public.guilds(id),
  ADD COLUMN IF NOT EXISTS prize_paid_at TIMESTAMPTZ;

UPDATE public.guild_war_tournaments
SET prize_gold = 100000000,
    prize_pool = '100,000,000 Altın',
    tournament_kind = 'weekly',
    max_slots = 8
WHERE name ILIKE '%Haftalık%' OR name ILIKE '%Arena%';

UPDATE public.guild_war_tournaments
SET prize_gold = 300000000,
    prize_pool = '300,000,000 Altın + Efsanevi +7',
    tournament_kind = 'season_final',
    max_slots = 8
WHERE name ILIKE '%Final%' OR name ILIKE '%Sezon%';

ALTER TABLE public.guild_vault_items
  ADD COLUMN IF NOT EXISTS enhancement_level INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bind_on_pickup BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS payload JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.guild_war_tournament_contributions (
  id BIGSERIAL PRIMARY KEY,
  match_id INTEGER NOT NULL REFERENCES public.guild_war_tournament_matches(id) ON DELETE CASCADE,
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  user_id UUID,
  kind TEXT NOT NULL,
  points INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clash_contrib_match
  ON public.guild_war_tournament_contributions (match_id, guild_id, kind);

CREATE TABLE IF NOT EXISTS public.guild_war_clash_rally (
  match_id INTEGER NOT NULL REFERENCES public.guild_war_tournament_matches(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  power_snapshot INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, user_id)
);

ALTER TABLE public.guild_war_tournament_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_war_clash_rally ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS clash_contrib_select ON public.guild_war_tournament_contributions;
CREATE POLICY clash_contrib_select ON public.guild_war_tournament_contributions
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS clash_rally_select ON public.guild_war_clash_rally;
CREATE POLICY clash_rally_select ON public.guild_war_clash_rally
  FOR SELECT TO authenticated USING (true);

-- ── Season rotate: big prizes ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rotate_guild_war_season()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old RECORD;
  v_new_id UUID;
  v_reg_open TIMESTAMPTZ;
  v_reg_close TIMESTAMPTZ;
  v_start TIMESTAMPTZ;
  v_end TIMESTAMPTZ;
BEGIN
  SELECT id, season_number, end_at
  INTO v_old
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF v_old IS NULL THEN
    INSERT INTO public.guild_war_seasons (season_number, week_number, start_at, end_at, is_active)
    VALUES (1, 1, now(), now() + interval '7 days', true)
    RETURNING id INTO v_new_id;

    PERFORM public._ensure_guild_war_rankings(v_new_id);

    v_reg_open := date_trunc('day', now());
    v_reg_close := v_reg_open + interval '24 hours';
    v_start := v_reg_close;
    v_end := v_start + interval '5 days';

    INSERT INTO public.guild_war_tournaments (
      season_id, name, status, guild_count, prize_pool, prize_gold,
      tournament_kind, max_slots, start_at, end_at,
      registration_opens_at, registration_closes_at
    ) VALUES
      (v_new_id, 'Haftalık Arena', 'upcoming', 0, '100,000,000 Altın', 100000000,
       'weekly', 8, v_start, v_end, v_reg_open, v_reg_close),
      (v_new_id, 'Sezon Finali', 'upcoming', 0, '300,000,000 Altın + Efsanevi +7', 300000000,
       'season_final', 8, v_end + interval '1 day', v_end + interval '6 days',
       NULL, NULL);

    RETURN v_new_id;
  END IF;

  IF v_old.end_at > now() THEN
    PERFORM public._ensure_guild_war_rankings(v_old.id);
    RETURN v_old.id;
  END IF;

  UPDATE public.guild_war_seasons SET is_active = false WHERE id = v_old.id;

  INSERT INTO public.guild_war_seasons (season_number, week_number, start_at, end_at, is_active)
  VALUES (v_old.season_number + 1, 1, now(), now() + interval '7 days', true)
  RETURNING id INTO v_new_id;

  PERFORM public._ensure_guild_war_rankings(v_new_id);

  v_reg_open := date_trunc('day', now());
  v_reg_close := v_reg_open + interval '24 hours';
  v_start := v_reg_close;
  v_end := v_start + interval '5 days';

  INSERT INTO public.guild_war_tournaments (
    season_id, name, status, guild_count, prize_pool, prize_gold,
    tournament_kind, max_slots, start_at, end_at,
    registration_opens_at, registration_closes_at
  ) VALUES
    (v_new_id, 'Haftalık Arena', 'upcoming', 0, '100,000,000 Altın', 100000000,
     'weekly', 8, v_start, v_end, v_reg_open, v_reg_close),
    (v_new_id, 'Sezon Finali', 'upcoming', 0, '300,000,000 Altın + Efsanevi +7', 300000000,
     'season_final', 8, v_end + interval '1 day', v_end + interval '6 days',
     NULL, NULL);

  RETURN v_new_id;
END;
$$;

-- ── Clash score helper ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._tournament_clash_add(
  p_match_id INTEGER,
  p_guild_id UUID,
  p_kind TEXT,
  p_points INTEGER,
  p_actor UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_m RECORD;
  v_cap INTEGER;
  v_used INTEGER;
  v_add INTEGER;
  v_new INTEGER;
BEGIN
  IF p_match_id IS NULL OR p_guild_id IS NULL OR COALESCE(p_points, 0) <= 0 THEN
    RETURN 0;
  END IF;

  SELECT * INTO v_m
  FROM public.guild_war_tournament_matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND OR v_m.status <> 'live' THEN
    RETURN 0;
  END IF;

  IF p_guild_id IS DISTINCT FROM v_m.guild1_id AND p_guild_id IS DISTINCT FROM v_m.guild2_id THEN
    RETURN 0;
  END IF;

  -- New member <48h ignored
  IF p_actor IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = p_actor
        AND u.guild_id = p_guild_id
        AND u.created_at > now() - interval '48 hours'
    ) THEN
      RETURN 0;
    END IF;
  END IF;

  v_cap := CASE p_kind
    WHEN 'pvp_win' THEN 180
    WHEN 'pvp_lose' THEN 40
    WHEN 'dungeon' THEN 120
    WHEN 'war_win' THEN 75
    WHEN 'war_lose' THEN 25
    WHEN 'garrison' THEN 30
    WHEN 'active' THEN 120
    ELSE 999999
  END;

  SELECT COALESCE(SUM(points), 0) INTO v_used
  FROM public.guild_war_tournament_contributions
  WHERE match_id = p_match_id AND guild_id = p_guild_id AND kind = p_kind;

  v_add := LEAST(p_points, GREATEST(v_cap - v_used, 0));
  IF v_add <= 0 THEN
    RETURN 0;
  END IF;

  INSERT INTO public.guild_war_tournament_contributions (match_id, guild_id, user_id, kind, points)
  VALUES (p_match_id, p_guild_id, p_actor, p_kind, v_add);

  IF p_guild_id = v_m.guild1_id THEN
    UPDATE public.guild_war_tournament_matches
    SET guild1_clash_score = guild1_clash_score + v_add,
        guild1_score = guild1_clash_score + v_add
    WHERE id = p_match_id
    RETURNING guild1_clash_score INTO v_new;
  ELSE
    UPDATE public.guild_war_tournament_matches
    SET guild2_clash_score = guild2_clash_score + v_add,
        guild2_score = guild2_clash_score + v_add
    WHERE id = p_match_id
    RETURNING guild2_clash_score INTO v_new;
  END IF;

  RETURN v_add;
END;
$$;

CREATE OR REPLACE FUNCTION public._live_clash_match_ids_for_guild(p_guild_id UUID)
RETURNS INTEGER[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(array_agg(m.id), '{}'::INTEGER[])
  FROM public.guild_war_tournament_matches m
  WHERE m.status = 'live'
    AND (m.guild1_id = p_guild_id OR m.guild2_id = p_guild_id)
    AND (m.window_end IS NULL OR m.window_end > now());
$$;

-- ── Rally ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rally_guild_war_clash(p_match_id INTEGER)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_user RECORD;
  v_m RECORD;
  v_pts INTEGER;
  v_rally_sum BIGINT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum gerekli');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_uid;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca gerekli');
  END IF;

  SELECT * INTO v_m FROM public.guild_war_tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND OR v_m.status <> 'live' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Canlı Clash yok');
  END IF;

  IF v_user.guild_id IS DISTINCT FROM v_m.guild1_id
     AND v_user.guild_id IS DISTINCT FROM v_m.guild2_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu maçta değilsin');
  END IF;

  IF EXISTS (SELECT 1 FROM public.guild_war_clash_rally WHERE match_id = p_match_id AND user_id = v_uid) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten rally oldun');
  END IF;

  INSERT INTO public.guild_war_clash_rally (match_id, user_id, guild_id, power_snapshot)
  VALUES (p_match_id, v_uid, v_user.guild_id, GREATEST(COALESCE(v_user.power, 0), 0));

  SELECT COALESCE(SUM(power_snapshot), 0) INTO v_rally_sum
  FROM public.guild_war_clash_rally
  WHERE match_id = p_match_id AND guild_id = v_user.guild_id;

  -- Fixed +15 token + small log2 power bonus (anti AFK pure power)
  v_pts := 15 + (LN(1 + v_rally_sum) / LN(2) * 2)::INTEGER;
  v_pts := LEAST(v_pts, 40);

  PERFORM public._tournament_clash_add(p_match_id, v_user.guild_id, 'rally', v_pts, v_uid);
  PERFORM public._tournament_clash_add(p_match_id, v_user.guild_id, 'active', 8, v_uid);

  RETURN jsonb_build_object('success', true, 'points', v_pts);
END;
$$;

-- ── Open / resolve match ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.open_tournament_match(p_match_id INTEGER)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_m RECORD;
  v_start TIMESTAMPTZ := now();
  v_end TIMESTAMPTZ := now() + interval '12 hours';
BEGIN
  SELECT * INTO v_m FROM public.guild_war_tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Maç yok');
  END IF;

  IF v_m.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Maç pending değil');
  END IF;

  -- Bye auto-complete
  IF v_m.guild1_id IS NULL OR v_m.guild2_id IS NULL THEN
    UPDATE public.guild_war_tournament_matches
    SET status = 'completed',
        winner_guild_id = COALESCE(guild1_id, guild2_id),
        window_start = v_start,
        window_end = v_start
    WHERE id = p_match_id;
    RETURN jsonb_build_object('success', true, 'bye', true);
  END IF;

  UPDATE public.guild_war_tournament_matches
  SET status = 'live',
      window_start = v_start,
      window_end = v_end,
      guild1_clash_score = 0,
      guild2_clash_score = 0,
      guild1_score = 0,
      guild2_score = 0
  WHERE id = p_match_id;

  RETURN jsonb_build_object(
    'success', true,
    'window_start', v_start,
    'window_end', v_end
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_tournament_match(p_match_id INTEGER)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_m RECORD;
  v_winner UUID;
  v_g1_seed INTEGER := 0;
  v_g2_seed INTEGER := 0;
  v_next RECORD;
  v_season UUID;
BEGIN
  SELECT * INTO v_m FROM public.guild_war_tournament_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Maç yok');
  END IF;

  IF v_m.status <> 'live' AND v_m.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Resolve edilemez');
  END IF;

  IF v_m.guild1_id IS NULL OR v_m.guild2_id IS NULL THEN
    v_winner := COALESCE(v_m.guild1_id, v_m.guild2_id);
  ELSIF v_m.guild1_clash_score > v_m.guild2_clash_score THEN
    v_winner := v_m.guild1_id;
  ELSIF v_m.guild2_clash_score > v_m.guild1_clash_score THEN
    v_winner := v_m.guild2_id;
  ELSE
    -- Tie → higher rank_score seed
    SELECT id INTO v_season FROM public.guild_war_seasons
    WHERE is_active = true ORDER BY created_at DESC LIMIT 1;

    SELECT COALESCE(rank_score, 0) INTO v_g1_seed FROM public.guild_war_rankings
    WHERE season_id = v_season AND guild_id = v_m.guild1_id;
    SELECT COALESCE(rank_score, 0) INTO v_g2_seed FROM public.guild_war_rankings
    WHERE season_id = v_season AND guild_id = v_m.guild2_id;

    IF v_g1_seed >= v_g2_seed THEN
      v_winner := v_m.guild1_id;
    ELSE
      v_winner := v_m.guild2_id;
    END IF;
  END IF;

  UPDATE public.guild_war_tournament_matches
  SET status = 'completed',
      winner_guild_id = v_winner,
      guild1_score = guild1_clash_score,
      guild2_score = guild2_clash_score
  WHERE id = p_match_id;

  -- Season points
  IF v_winner = v_m.guild1_id THEN
    PERFORM public._guild_season_add_points(v_m.guild1_id, 'clash_win', 50, NULL,
      jsonb_build_object('match_id', p_match_id));
    PERFORM public._guild_season_add_points(v_m.guild2_id, 'clash_lose', 12, NULL,
      jsonb_build_object('match_id', p_match_id));
  ELSE
    PERFORM public._guild_season_add_points(v_m.guild2_id, 'clash_win', 50, NULL,
      jsonb_build_object('match_id', p_match_id));
    PERFORM public._guild_season_add_points(v_m.guild1_id, 'clash_lose', 12, NULL,
      jsonb_build_object('match_id', p_match_id));
  END IF;

  -- Advance to next round
  SELECT * INTO v_next
  FROM public.guild_war_tournament_matches
  WHERE tournament_id = v_m.tournament_id
    AND round_number = v_m.round_number + 1
    AND match_order = CEIL(v_m.match_order / 2.0)::INTEGER
  FOR UPDATE;

  IF FOUND THEN
    IF (v_m.match_order % 2) = 1 THEN
      UPDATE public.guild_war_tournament_matches SET guild1_id = v_winner WHERE id = v_next.id;
    ELSE
      UPDATE public.guild_war_tournament_matches SET guild2_id = v_winner WHERE id = v_next.id;
    END IF;
  END IF;

  RETURN jsonb_build_object('success', true, 'winner_guild_id', v_winner);
END;
$$;

-- ── Prize mint ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._mint_noncommon_vault_items(
  p_guild_id UUID,
  p_count INTEGER,
  p_source_ref TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_i INTEGER;
  v_item TEXT;
  v_n INTEGER := 0;
BEGIN
  FOR v_i IN 1..GREATEST(p_count, 0) LOOP
    SELECT i.id INTO v_item
    FROM public.items i
    WHERE COALESCE(i.rarity, 'common') NOT IN ('common', 'Common')
      AND COALESCE(i.is_active, true) = true
    ORDER BY random()
    LIMIT 1;

    IF v_item IS NULL THEN
      EXIT;
    END IF;

    INSERT INTO public.guild_vault_items (
      guild_id, item_id, quantity, source_type, source_ref, bind_on_pickup
    ) VALUES (
      p_guild_id, v_item, 1, 'tournament_prize', p_source_ref, true
    );
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$$;

CREATE OR REPLACE FUNCTION public._mint_enhanced_equipment(
  p_guild_id UUID,
  p_enhancement INTEGER,
  p_min_rarity TEXT,
  p_source_ref TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_item TEXT;
BEGIN
  SELECT i.id INTO v_item
  FROM public.items i
  WHERE COALESCE(i.can_enhance, false) = true
    AND COALESCE(i.max_enhancement, 0) >= p_enhancement
    AND (
      (p_min_rarity = 'legendary' AND lower(COALESCE(i.rarity, '')) = 'legendary')
      OR (p_min_rarity = 'epic' AND lower(COALESCE(i.rarity, '')) IN ('epic', 'legendary'))
    )
    AND (
      COALESCE(i.equip_slot, '') <> ''
      OR COALESCE(i.slot, '') <> ''
      OR lower(COALESCE(i.item_type, '')) IN ('weapon', 'armor', 'helmet', 'boots', 'gloves', 'accessory')
    )
  ORDER BY random()
  LIMIT 1;

  IF v_item IS NULL THEN
    -- Fallback any legendary/epic
    SELECT i.id INTO v_item
    FROM public.items i
    WHERE lower(COALESCE(i.rarity, '')) IN ('legendary', 'epic')
    ORDER BY random()
    LIMIT 1;
  END IF;

  IF v_item IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.guild_vault_items (
    guild_id, item_id, quantity, source_type, source_ref,
    enhancement_level, bind_on_pickup, payload
  ) VALUES (
    p_guild_id, v_item, 1, 'tournament_prize', p_source_ref,
    p_enhancement, true,
    jsonb_build_object('enhancement_level', p_enhancement, 'bind_on_pickup', true)
  );

  RETURN v_item;
END;
$$;

CREATE OR REPLACE FUNCTION public.grant_guild_war_tournament_prize(p_tournament_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_t RECORD;
  v_final RECORD;
  v_sf RECORD;
  v_pool BIGINT;
  v_kind TEXT;
  v_ref TEXT;
BEGIN
  SELECT * INTO v_t FROM public.guild_war_tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Turnuva yok');
  END IF;

  IF v_t.prize_paid_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül zaten verildi');
  END IF;

  SELECT * INTO v_final
  FROM public.guild_war_tournament_matches
  WHERE tournament_id = p_tournament_id
  ORDER BY round_number DESC, match_order ASC
  LIMIT 1;

  IF v_final.winner_guild_id IS NULL OR v_final.status <> 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Final tamamlanmadı');
  END IF;

  v_pool := COALESCE(NULLIF(v_t.prize_gold, 0), CASE
    WHEN v_t.tournament_kind = 'season_final' THEN 300000000
    ELSE 100000000
  END);
  v_kind := COALESCE(v_t.tournament_kind, 'weekly');
  v_ref := p_tournament_id::TEXT;

  -- 1st: 60%
  UPDATE public.guilds
  SET vault_gold = vault_gold + (v_pool * 0.60)::BIGINT
  WHERE id = v_final.winner_guild_id;

  IF v_kind = 'season_final' THEN
    PERFORM public._mint_enhanced_equipment(v_final.winner_guild_id, 7, 'legendary', v_ref);
    PERFORM public._mint_noncommon_vault_items(v_final.winner_guild_id, 2, v_ref);
    PERFORM public._guild_season_add_points(v_final.winner_guild_id, 'tournament_1st', 500, NULL,
      jsonb_build_object('tournament_id', p_tournament_id));
  ELSE
    PERFORM public._mint_noncommon_vault_items(v_final.winner_guild_id, 3, v_ref);
    PERFORM public._guild_season_add_points(v_final.winner_guild_id, 'tournament_1st', 200, NULL,
      jsonb_build_object('tournament_id', p_tournament_id));
  END IF;

  -- 2nd: loser of final = 25%
  IF v_final.guild1_id IS NOT NULL AND v_final.guild2_id IS NOT NULL THEN
    DECLARE
      v_second UUID := CASE
        WHEN v_final.winner_guild_id = v_final.guild1_id THEN v_final.guild2_id
        ELSE v_final.guild1_id
      END;
    BEGIN
      UPDATE public.guilds
      SET vault_gold = vault_gold + (v_pool * 0.25)::BIGINT
      WHERE id = v_second;

      IF v_kind = 'season_final' THEN
        PERFORM public._mint_enhanced_equipment(v_second, 5, 'legendary', v_ref);
        PERFORM public._mint_noncommon_vault_items(v_second, 1, v_ref);
        PERFORM public._guild_season_add_points(v_second, 'tournament_2nd', 250, NULL,
          jsonb_build_object('tournament_id', p_tournament_id));
      ELSE
        PERFORM public._mint_noncommon_vault_items(v_second, 2, v_ref);
        PERFORM public._guild_season_add_points(v_second, 'tournament_2nd', 100, NULL,
          jsonb_build_object('tournament_id', p_tournament_id));
      END IF;
    END;
  END IF;

  -- SF losers: 7.5% each
  FOR v_sf IN
    SELECT m.*
    FROM public.guild_war_tournament_matches m
    WHERE m.tournament_id = p_tournament_id
      AND m.round_name ILIKE '%Yarı%'
      AND m.status = 'completed'
  LOOP
    IF v_sf.guild1_id IS NOT NULL AND v_sf.guild1_id IS DISTINCT FROM v_sf.winner_guild_id THEN
      UPDATE public.guilds SET vault_gold = vault_gold + (v_pool * 0.075)::BIGINT WHERE id = v_sf.guild1_id;
      IF v_kind = 'season_final' THEN
        PERFORM public._mint_enhanced_equipment(v_sf.guild1_id, 3, 'epic', v_ref);
        PERFORM public._guild_season_add_points(v_sf.guild1_id, 'tournament_sf', 80, NULL,
          jsonb_build_object('tournament_id', p_tournament_id));
      ELSE
        PERFORM public._mint_noncommon_vault_items(v_sf.guild1_id, 1, v_ref);
        PERFORM public._guild_season_add_points(v_sf.guild1_id, 'tournament_sf', 40, NULL,
          jsonb_build_object('tournament_id', p_tournament_id));
      END IF;
    END IF;
    IF v_sf.guild2_id IS NOT NULL AND v_sf.guild2_id IS DISTINCT FROM v_sf.winner_guild_id THEN
      UPDATE public.guilds SET vault_gold = vault_gold + (v_pool * 0.075)::BIGINT WHERE id = v_sf.guild2_id;
      IF v_kind = 'season_final' THEN
        PERFORM public._mint_enhanced_equipment(v_sf.guild2_id, 3, 'epic', v_ref);
        PERFORM public._guild_season_add_points(v_sf.guild2_id, 'tournament_sf', 80, NULL,
          jsonb_build_object('tournament_id', p_tournament_id));
      ELSE
        PERFORM public._mint_noncommon_vault_items(v_sf.guild2_id, 1, v_ref);
        PERFORM public._guild_season_add_points(v_sf.guild2_id, 'tournament_sf', 40, NULL,
          jsonb_build_object('tournament_id', p_tournament_id));
      END IF;
    END IF;
  END LOOP;

  -- Participation points (system mint already credited gold/items above)
  PERFORM public._guild_season_add_points(
    p.guild_id,
    CASE WHEN v_kind = 'season_final' THEN 'tournament_join_final' ELSE 'tournament_join' END,
    CASE WHEN v_kind = 'season_final' THEN 30 ELSE 15 END,
    NULL,
    jsonb_build_object('tournament_id', p_tournament_id)
  )
  FROM public.guild_war_participants p
  WHERE p.tournament_id = p_tournament_id;

  UPDATE public.guild_war_tournaments
  SET status = 'completed',
      winner_guild_id = v_final.winner_guild_id,
      prize_paid_at = now(),
      prize_gold = v_pool,
      prize_pool = CASE
        WHEN v_kind = 'season_final' THEN '300,000,000 Altın + Efsanevi +7'
        ELSE '100,000,000 Altın'
      END
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true,
    'winner_guild_id', v_final.winner_guild_id,
    'prize_gold', v_pool
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.close_guild_war_tournament(p_tournament_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN public.grant_guild_war_tournament_prize(p_tournament_id);
END;
$$;

-- ── Cron tick ───────────────────────────────────────────────────────────────
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
  v_max_round INTEGER;
  v_pending_live INTEGER;
BEGIN
  -- Seed brackets for tournaments past start
  FOR v_t IN
    SELECT * FROM public.guild_war_tournaments
    WHERE status IN ('upcoming', 'active', 'registration')
      AND start_at IS NOT NULL AND start_at <= now()
  LOOP
    BEGIN
      PERFORM public.seed_guild_war_tournament_bracket(v_t.id);
      UPDATE public.guild_war_tournaments SET status = 'active' WHERE id = v_t.id AND status <> 'active';
    EXCEPTION WHEN OTHERS THEN
      NULL; -- continue
    END;
  END LOOP;

  -- Open next pending matches when no live match in that tournament round stream
  FOR v_t IN SELECT id FROM public.guild_war_tournaments WHERE status = 'active' LOOP
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

      -- Bye pending
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
  FOR v_t IN SELECT * FROM public.guild_war_tournaments WHERE status = 'active' LOOP
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
    'closed', v_closed
  );
END;
$$;

-- ── Seed by rank_score ──────────────────────────────────────────────────────
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
  v_max_slots INT;
  v_season UUID;
BEGIN
  SELECT t.* INTO v_tournament
  FROM public.guild_war_tournaments t
  WHERE t.id = p_tournament_id;

  IF v_tournament.id IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.guild_war_tournament_matches WHERE tournament_id = p_tournament_id
  ) THEN
    RETURN;
  END IF;

  v_max_slots := COALESCE(NULLIF(v_tournament.max_slots, 0), 8);
  v_season := v_tournament.season_id;

  SELECT COALESCE(array_agg(x.guild_id ORDER BY x.rank_score DESC, x.prestige DESC, random()), '{}')
  INTO v_guild_ids
  FROM (
    SELECT p.guild_id,
           COALESCE(r.rank_score, 0) AS rank_score,
           COALESCE(r.prestige, 0) AS prestige
    FROM public.guild_war_participants p
    LEFT JOIN public.guild_war_rankings r
      ON r.guild_id = p.guild_id AND r.season_id = v_season
    WHERE p.tournament_id = p_tournament_id
    ORDER BY COALESCE(r.rank_score, 0) DESC, COALESCE(r.prestige, 0) DESC, random()
    LIMIT v_max_slots
  ) x;

  v_participant_count := COALESCE(array_length(v_guild_ids, 1), 0);
  IF v_participant_count < 2 THEN
    RETURN;
  END IF;

  v_bracket_size := 1;
  WHILE v_bracket_size < v_participant_count LOOP
    v_bracket_size := v_bracket_size * 2;
  END LOOP;
  IF v_bracket_size > v_max_slots THEN
    v_bracket_size := v_max_slots;
  END IF;

  v_rounds := CEIL(LOG(2, GREATEST(v_bracket_size, 2)))::INT;
  v_seed_order := public._guild_war_bracket_seed_order(v_bracket_size);
  v_slots := array_fill(NULL::UUID, ARRAY[v_bracket_size]);

  FOR v_slot IN 1..LEAST(v_participant_count, v_bracket_size) LOOP
    v_seed := v_seed_order[v_slot];
    v_slots[v_seed] := v_guild_ids[v_slot];
  END LOOP;

  FOR v_match_order IN 1..(v_bracket_size / 2) LOOP
    v_g1 := v_slots[v_match_order * 2 - 1];
    v_g2 := v_slots[v_match_order * 2];
    INSERT INTO public.guild_war_tournament_matches (
      tournament_id, round_number, round_name, match_order,
      guild1_id, guild2_id, status
    ) VALUES (
      p_tournament_id, 1,
      public._guild_war_round_name(v_bracket_size, 1),
      v_match_order, v_g1, v_g2,
      CASE WHEN v_g1 IS NULL OR v_g2 IS NULL THEN 'completed' ELSE 'pending' END
    );
  END LOOP;

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
        p_tournament_id, v_round,
        public._guild_war_round_name(v_bracket_size, v_round),
        v_match_order, 'pending'
      );
    END LOOP;
  END LOOP;

  -- Advance bye winners
  FOR v_match_order IN 1..(v_bracket_size / 2) LOOP
    DECLARE
      v_bye UUID;
    BEGIN
      SELECT winner_guild_id INTO v_bye
      FROM public.guild_war_tournament_matches
      WHERE tournament_id = p_tournament_id
        AND round_number = 1 AND match_order = v_match_order
        AND status = 'completed';
      IF v_bye IS NOT NULL THEN
        UPDATE public.guild_war_tournament_matches
        SET guild1_id = CASE WHEN (v_match_order % 2) = 1 THEN v_bye ELSE guild1_id END,
            guild2_id = CASE WHEN (v_match_order % 2) = 0 THEN v_bye ELSE guild2_id END
        WHERE tournament_id = p_tournament_id
          AND round_number = 2
          AND match_order = CEIL(v_match_order / 2.0)::INTEGER;
      END IF;
    END;
  END LOOP;
END;
$$;

-- ── Live Clash hub RPC ──────────────────────────────────────────────────────
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
BEGIN
  IF v_guild IS NULL AND v_uid IS NOT NULL THEN
    SELECT guild_id INTO v_guild FROM public.users WHERE auth_id = v_uid;
  END IF;

  SELECT jsonb_build_object(
    'match_id', m.id,
    'tournament_id', m.tournament_id,
    'tournament_name', t.name,
    'round_name', m.round_name,
    'status', m.status,
    'window_start', m.window_start,
    'window_end', m.window_end,
    'guild1_id', m.guild1_id,
    'guild1_name', g1.name,
    'guild1_score', m.guild1_clash_score,
    'guild2_id', m.guild2_id,
    'guild2_name', g2.name,
    'guild2_score', m.guild2_clash_score
  )
  INTO v_row
  FROM public.guild_war_tournament_matches m
  JOIN public.guild_war_tournaments t ON t.id = m.tournament_id
  LEFT JOIN public.guilds g1 ON g1.id = m.guild1_id
  LEFT JOIN public.guilds g2 ON g2.id = m.guild2_id
  WHERE m.status = 'live'
    AND (v_guild IS NULL OR m.guild1_id = v_guild OR m.guild2_id = v_guild)
  ORDER BY m.window_end ASC NULLS LAST
  LIMIT 1;

  IF v_row IS NULL THEN
    -- Next upcoming / registration
    SELECT jsonb_build_object(
      'status', 'idle',
      'next_tournament_id', t.id,
      'next_tournament_name', t.name,
      'next_start_at', t.start_at,
      'registration_opens_at', t.registration_opens_at,
      'registration_closes_at', t.registration_closes_at,
      'prize_pool', t.prize_pool
    )
    INTO v_row
    FROM public.guild_war_tournaments t
    WHERE t.status IN ('upcoming', 'active', 'registration')
    ORDER BY COALESCE(t.registration_opens_at, t.start_at) ASC NULLS LAST
    LIMIT 1;
  END IF;

  RETURN COALESCE(v_row, jsonb_build_object('status', 'idle'));
END;
$$;

-- Update matches getter to expose clash fields
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
        COALESCE(m.guild1_clash_score, m.guild1_score) AS "guild1Score",
        COALESCE(m.guild2_clash_score, m.guild2_score) AS "guild2Score",
        m.winner_guild_id AS "winnerGuildId",
        COALESCE(gw.name, '') AS "winnerGuildName",
        m.status,
        m.window_start AS "windowStart",
        m.window_end AS "windowEnd"
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

-- Hook war attacks into live clash
CREATE OR REPLACE FUNCTION public._clash_hook_war(
  p_guild_id UUID,
  p_success BOOLEAN,
  p_actor UUID,
  p_defender_guild UUID DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ids INTEGER[];
  v_id INTEGER;
  v_pts INTEGER;
  v_kind TEXT;
  v_m RECORD;
BEGIN
  v_ids := public._live_clash_match_ids_for_guild(p_guild_id);
  IF array_length(v_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  v_kind := CASE WHEN p_success THEN 'war_win' ELSE 'war_lose' END;
  v_pts := CASE WHEN p_success THEN 25 ELSE 5 END;

  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT * INTO v_m FROM public.guild_war_tournament_matches WHERE id = v_id;
    -- Rival territory bonus ×1.5
    IF p_success AND p_defender_guild IS NOT NULL
       AND (p_defender_guild = v_m.guild1_id OR p_defender_guild = v_m.guild2_id)
       AND p_defender_guild IS DISTINCT FROM p_guild_id THEN
      v_pts := (v_pts * 1.5)::INTEGER;
    END IF;
    PERFORM public._tournament_clash_add(v_id, p_guild_id, v_kind, v_pts, p_actor);
    PERFORM public._tournament_clash_add(v_id, p_guild_id, 'active', 8, p_actor);
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rally_guild_war_clash(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_tournament_match(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_tournament_match(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_guild_war_tournament_prize(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_guild_war_tournament(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cron_tournament_tick() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cron_tournament_tick() TO service_role;
GRANT EXECUTE ON FUNCTION public.get_live_guild_war_clash(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.seed_guild_war_tournament_bracket(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rotate_guild_war_season() TO service_role;

COMMIT;
