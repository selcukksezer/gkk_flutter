-- =====================================================
-- At Yarışı v2 — global scheduled races, dynamic odds
-- Supersedes 20260619_000000_horse_race_betting_system.sql
-- =====================================================

BEGIN;

-- -----------------------------------------------------
-- Templates (identity only — no static multipliers)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.horse_race_templates (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '🐴',
  lane_color TEXT NOT NULL DEFAULT '#94A3B8',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.horse_race_templates (id, name, emoji, lane_color)
SELECT id, name, emoji, lane_color
FROM public.horse_race_horses
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  emoji = EXCLUDED.emoji,
  lane_color = EXCLUDED.lane_color,
  updated_at = now();

INSERT INTO public.horse_race_templates (id, name, emoji, lane_color) VALUES
  ('hr_lightning', 'Şimşek', '⚡', '#FBBF24'),
  ('hr_storm', 'Fırtına', '🌪️', '#60A5FA'),
  ('hr_shadow', 'Karadul', '🌑', '#A78BFA'),
  ('hr_golden', 'Altıntoz', '✨', '#F59E0B'),
  ('hr_night', 'Gece Ayazı', '🌙', '#818CF8'),
  ('hr_legend', 'Efsane Tay', '👑', '#F472B6')
ON CONFLICT (id) DO NOTHING;

-- Settings extension
ALTER TABLE public.horse_race_settings
  ADD COLUMN IF NOT EXISTS betting_seconds INTEGER NOT NULL DEFAULT 90 CHECK (betting_seconds > 0),
  ADD COLUMN IF NOT EXISTS racing_seconds INTEGER NOT NULL DEFAULT 8 CHECK (racing_seconds > 0),
  ADD COLUMN IF NOT EXISTS finished_seconds INTEGER NOT NULL DEFAULT 10 CHECK (finished_seconds > 0),
  ADD COLUMN IF NOT EXISTS gold_max_multiplier NUMERIC(6,2) NOT NULL DEFAULT 5.00 CHECK (gold_max_multiplier > 0),
  ADD COLUMN IF NOT EXISTS gem_max_multiplier NUMERIC(6,2) NOT NULL DEFAULT 2.00 CHECK (gem_max_multiplier > 0),
  ADD COLUMN IF NOT EXISTS house_edge NUMERIC(4,2) NOT NULL DEFAULT 0.92 CHECK (house_edge > 0 AND house_edge <= 1);

-- Global rounds
CREATE TABLE IF NOT EXISTS public.horse_race_rounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status TEXT NOT NULL DEFAULT 'betting'
    CHECK (status IN ('betting', 'locked', 'racing', 'finished')),
  betting_ends_at TIMESTAMPTZ NOT NULL,
  racing_ends_at TIMESTAMPTZ,
  finished_ends_at TIMESTAMPTZ,
  winner_horse_id TEXT REFERENCES public.horse_race_templates(id),
  race_script JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.horse_race_round_entries (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  round_id UUID NOT NULL REFERENCES public.horse_race_rounds(id) ON DELETE CASCADE,
  horse_id TEXT NOT NULL REFERENCES public.horse_race_templates(id) ON DELETE RESTRICT,
  gold_multiplier NUMERIC(6,2) NOT NULL CHECK (gold_multiplier > 0),
  gem_multiplier NUMERIC(6,2) NOT NULL CHECK (gem_multiplier > 0),
  win_weight NUMERIC(16,8) NOT NULL CHECK (win_weight > 0),
  win_chance_pct NUMERIC(6,2) NOT NULL CHECK (win_chance_pct >= 0),
  sort_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE (round_id, horse_id)
);

CREATE TABLE IF NOT EXISTS public.horse_race_bets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id UUID NOT NULL REFERENCES public.horse_race_rounds(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  horse_id TEXT NOT NULL REFERENCES public.horse_race_templates(id) ON DELETE RESTRICT,
  currency_type TEXT NOT NULL CHECK (currency_type IN ('gold', 'gems')),
  bet_amount INTEGER NOT NULL CHECK (bet_amount > 0),
  multiplier NUMERIC(6,2) NOT NULL CHECK (multiplier > 0),
  won BOOLEAN,
  payout_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (payout_amount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (round_id, user_id)
);

-- Extend logs
ALTER TABLE public.player_horse_race_logs
  ADD COLUMN IF NOT EXISTS round_id UUID REFERENCES public.horse_race_rounds(id);

-- Re-point FKs from horse_race_horses to horse_race_templates if old table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'horse_race_horses'
  ) THEN
    ALTER TABLE public.player_horse_race_logs
      DROP CONSTRAINT IF EXISTS player_horse_race_logs_horse_id_fkey;
    ALTER TABLE public.player_horse_race_logs
      DROP CONSTRAINT IF EXISTS player_horse_race_logs_picked_horse_id_fkey;
    ALTER TABLE public.player_horse_race_logs
      DROP CONSTRAINT IF EXISTS player_horse_race_logs_winner_horse_id_fkey;

    ALTER TABLE public.player_horse_race_logs
      ADD CONSTRAINT player_horse_race_logs_horse_id_fkey
      FOREIGN KEY (horse_id) REFERENCES public.horse_race_templates(id) ON DELETE RESTRICT;
    ALTER TABLE public.player_horse_race_logs
      ADD CONSTRAINT player_horse_race_logs_picked_horse_id_fkey
      FOREIGN KEY (picked_horse_id) REFERENCES public.horse_race_templates(id) ON DELETE RESTRICT;
    ALTER TABLE public.player_horse_race_logs
      ADD CONSTRAINT player_horse_race_logs_winner_horse_id_fkey
      FOREIGN KEY (winner_horse_id) REFERENCES public.horse_race_templates(id) ON DELETE RESTRICT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_horse_race_rounds_status_created
  ON public.horse_race_rounds (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_horse_race_round_entries_round_sort
  ON public.horse_race_round_entries (round_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_horse_race_bets_round_user
  ON public.horse_race_bets (round_id, user_id);

ALTER TABLE public.horse_race_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horse_race_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horse_race_round_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horse_race_bets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS horse_race_templates_select_auth ON public.horse_race_templates;
CREATE POLICY horse_race_templates_select_auth
ON public.horse_race_templates FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS horse_race_rounds_select_auth ON public.horse_race_rounds;
CREATE POLICY horse_race_rounds_select_auth
ON public.horse_race_rounds FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS horse_race_round_entries_select_auth ON public.horse_race_round_entries;
CREATE POLICY horse_race_round_entries_select_auth
ON public.horse_race_round_entries FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS horse_race_bets_select_own ON public.horse_race_bets;
CREATE POLICY horse_race_bets_select_own
ON public.horse_race_bets FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- -----------------------------------------------------
-- Helpers
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION public._horse_race_clamp_mult(
  p_value DOUBLE PRECISION,
  p_min DOUBLE PRECISION,
  p_max DOUBLE PRECISION
)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT ROUND(LEAST(p_max, GREATEST(p_min, p_value))::NUMERIC, 2);
$$;

CREATE OR REPLACE FUNCTION public._horse_race_generate_race_script(
  p_winner_id TEXT,
  p_horse_ids TEXT[],
  p_duration_ms INTEGER DEFAULT 8000
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_finish_order TEXT[] := ARRAY[]::TEXT[];
  v_remaining TEXT[];
  v_leader TEXT;
  v_hid TEXT;
  v_positions JSONB := '{}'::jsonb;
  v_keyframes JSONB := '[]'::jsonb;
  v_t NUMERIC;
  v_progress NUMERIC;
  v_winner_progress NUMERIC;
  v_i INTEGER;
  v_j INTEGER;
  v_times NUMERIC[] := ARRAY[0.0, 0.18, 0.38, 0.58, 0.78, 1.0];
BEGIN
  v_remaining := ARRAY(SELECT unnest(p_horse_ids) EXCEPT SELECT unnest(ARRAY[p_winner_id]));
  v_remaining := ARRAY(SELECT x FROM unnest(v_remaining) AS x ORDER BY random());
  v_finish_order := v_remaining || ARRAY[p_winner_id];

  FOREACH v_t IN ARRAY v_times LOOP
    v_positions := '{}'::jsonb;
    v_leader := v_finish_order[1 + (FLOOR(v_t * 3)::INTEGER % GREATEST(array_length(v_finish_order, 1), 1))];

    FOR v_i IN 1..array_length(p_horse_ids, 1) LOOP
      v_hid := p_horse_ids[v_i];
      v_j := array_position(v_finish_order, v_hid);
      IF v_j IS NULL THEN
        v_j := array_length(v_finish_order, 1);
      END IF;

      v_progress := GREATEST(0, LEAST(1, v_t * (0.55 + (array_length(v_finish_order, 1) - v_j + 1)::NUMERIC * 0.08)));

      IF v_hid = p_winner_id AND v_t >= 0.82 THEN
        v_winner_progress := 0.70 + (v_t - 0.82) / 0.18 * 0.30;
        v_progress := GREATEST(v_progress, LEAST(1, v_winner_progress));
      END IF;

      IF v_hid = v_leader AND v_t < 0.82 THEN
        v_progress := v_progress + 0.06;
      END IF;

      v_positions := v_positions || jsonb_build_object(v_hid, ROUND(LEAST(1, v_progress)::NUMERIC, 4));
    END LOOP;

    v_keyframes := v_keyframes || jsonb_build_array(
      jsonb_build_object('t', v_t, 'positions', v_positions, 'leader_id', v_leader)
    );
  END LOOP;

  RETURN jsonb_build_object(
    'duration_ms', p_duration_ms,
    'finish_order', to_jsonb(v_finish_order),
    'winner_id', p_winner_id,
    'keyframes', v_keyframes
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._horse_race_create_round()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_settings RECORD;
  v_round_id UUID;
  v_horse RECORD;
  v_gold_min NUMERIC := 1.20;
  v_gold_max NUMERIC := 5.00;
  v_gem_min NUMERIC := 1.10;
  v_gem_max NUMERIC := 2.00;
  v_count INTEGER;
  v_idx INTEGER := 0;
  v_gold_mult NUMERIC;
  v_gem_mult NUMERIC;
  v_total_weight NUMERIC := 0;
  v_weight NUMERIC;
  v_entries JSONB := '[]'::jsonb;
  v_sorted RECORD;
BEGIN
  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default' AND is_active = TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'horse race settings missing';
  END IF;

  v_gold_max := COALESCE(v_settings.gold_max_multiplier, 5.00);
  v_gem_max := COALESCE(v_settings.gem_max_multiplier, 2.00);

  SELECT COUNT(*) INTO v_count
  FROM public.horse_race_templates
  WHERE is_active = TRUE;

  IF v_count < 2 THEN
    RAISE EXCEPTION 'not enough active horses';
  END IF;

  INSERT INTO public.horse_race_rounds (
    status,
    betting_ends_at
  ) VALUES (
    'betting',
    now() + make_interval(secs => v_settings.betting_seconds)
  )
  RETURNING id INTO v_round_id;

  FOR v_horse IN
    SELECT id
    FROM public.horse_race_templates
    WHERE is_active = TRUE
    ORDER BY random()
    LIMIT 6
  LOOP
    v_idx := v_idx + 1;
    v_gold_mult := public._horse_race_clamp_mult(
      (v_gold_min + (v_gold_max - v_gold_min) * ((v_idx - 1)::NUMERIC / GREATEST(LEAST(v_count, 6) - 1, 1)::NUMERIC)
        + (random() * 0.18 - 0.09))::DOUBLE PRECISION,
      v_gold_min::DOUBLE PRECISION,
      v_gold_max::DOUBLE PRECISION
    );
    v_gem_mult := public._horse_race_clamp_mult(
      (v_gem_min + random() * (v_gem_max - v_gem_min))::DOUBLE PRECISION,
      v_gem_min::DOUBLE PRECISION,
      v_gem_max::DOUBLE PRECISION
    );
    v_weight := 1 / POWER(v_gold_mult, 2);
    v_total_weight := v_total_weight + v_weight;

    v_entries := v_entries || jsonb_build_array(
      jsonb_build_object(
        'horse_id', v_horse.id,
        'gold_multiplier', v_gold_mult,
        'gem_multiplier', v_gem_mult,
        'win_weight', v_weight
      )
    );
  END LOOP;

  FOR v_sorted IN
    SELECT *
    FROM jsonb_to_recordset(v_entries) AS e(
      horse_id TEXT,
      gold_multiplier NUMERIC,
      gem_multiplier NUMERIC,
      win_weight NUMERIC
    )
    ORDER BY gold_multiplier ASC
  LOOP
    INSERT INTO public.horse_race_round_entries (
      round_id,
      horse_id,
      gold_multiplier,
      gem_multiplier,
      win_weight,
      win_chance_pct,
      sort_order
    ) VALUES (
      v_round_id,
      v_sorted.horse_id,
      v_sorted.gold_multiplier,
      v_sorted.gem_multiplier,
      v_sorted.win_weight,
      ROUND((v_sorted.win_weight / NULLIF(v_total_weight, 0) * 100)::NUMERIC, 2),
      (SELECT COUNT(*) FROM public.horse_race_round_entries WHERE round_id = v_round_id) + 1
    );
  END LOOP;

  RETURN v_round_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._horse_race_resolve_round(p_round_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_settings RECORD;
  v_winner_id TEXT;
  v_horse_ids TEXT[];
  v_race_script JSONB;
  v_bet RECORD;
  v_entry RECORD;
  v_mult NUMERIC;
  v_payout NUMERIC(14,2);
  v_won BOOLEAN;
BEGIN
  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default'
  LIMIT 1;

  SELECT e.horse_id
  INTO v_winner_id
  FROM public.horse_race_round_entries e
  WHERE e.round_id = p_round_id
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.win_weight, 1e-9)
  LIMIT 1;

  SELECT ARRAY_AGG(e.horse_id ORDER BY e.sort_order)
  INTO v_horse_ids
  FROM public.horse_race_round_entries e
  WHERE e.round_id = p_round_id;

  v_race_script := public._horse_race_generate_race_script(
    v_winner_id,
    v_horse_ids,
    COALESCE(v_settings.racing_seconds, 8) * 1000
  );

  UPDATE public.horse_race_rounds
  SET
    status = 'racing',
    winner_horse_id = v_winner_id,
    race_script = v_race_script,
    racing_ends_at = now() + make_interval(secs => COALESCE(v_settings.racing_seconds, 8)),
    finished_ends_at = now()
      + make_interval(secs => COALESCE(v_settings.racing_seconds, 8) + COALESCE(v_settings.finished_seconds, 10)),
    updated_at = now()
  WHERE id = p_round_id;

  FOR v_bet IN
    SELECT *
    FROM public.horse_race_bets
    WHERE round_id = p_round_id
      AND won IS NULL
  LOOP
    SELECT *
    INTO v_entry
    FROM public.horse_race_round_entries
    WHERE round_id = p_round_id
      AND horse_id = v_bet.horse_id;

    v_mult := CASE
      WHEN v_bet.currency_type = 'gems' THEN v_entry.gem_multiplier
      ELSE v_entry.gold_multiplier
    END;

    v_won := v_bet.horse_id = v_winner_id;
    v_payout := 0;

    IF v_won THEN
      IF v_bet.currency_type = 'gems' THEN
        v_payout := ROUND(
          (v_bet.bet_amount::NUMERIC * v_mult * COALESCE(v_settings.house_edge, 0.92))::NUMERIC,
          2
        );
        UPDATE public.users SET gems = gems + v_payout WHERE auth_id = v_bet.user_id;
      ELSE
        v_payout := GREATEST(
          1,
          FLOOR(v_bet.bet_amount * v_mult * COALESCE(v_settings.house_edge, 0.92))::INTEGER
        );
        UPDATE public.users SET gold = gold + v_payout::INTEGER WHERE auth_id = v_bet.user_id;
      END IF;
    END IF;

    UPDATE public.horse_race_bets
    SET won = v_won, payout_amount = v_payout, multiplier = v_mult
    WHERE id = v_bet.id;

    INSERT INTO public.player_horse_race_logs (
      user_id,
      round_id,
      horse_id,
      picked_horse_id,
      winner_horse_id,
      currency_type,
      bet_amount,
      multiplier,
      won,
      payout_amount,
      metadata
    ) VALUES (
      v_bet.user_id,
      p_round_id,
      v_bet.horse_id,
      v_bet.horse_id,
      v_winner_id,
      v_bet.currency_type,
      v_bet.bet_amount,
      v_mult,
      v_won,
      v_payout,
      jsonb_build_object('race_script', v_race_script)
    );
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.tick_horse_race_engine()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_round RECORD;
BEGIN
  SELECT *
  INTO v_round
  FROM public.horse_race_rounds
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    PERFORM public._horse_race_create_round();
    RETURN;
  END IF;

  IF v_round.status = 'betting' AND now() >= v_round.betting_ends_at THEN
    UPDATE public.horse_race_rounds
    SET status = 'locked', updated_at = now()
    WHERE id = v_round.id;

    PERFORM public._horse_race_resolve_round(v_round.id);
    RETURN;
  END IF;

  IF v_round.status = 'racing' AND v_round.racing_ends_at IS NOT NULL AND now() >= v_round.racing_ends_at THEN
    UPDATE public.horse_race_rounds
    SET status = 'finished', updated_at = now()
    WHERE id = v_round.id;
    RETURN;
  END IF;

  IF v_round.status = 'finished'
     AND v_round.finished_ends_at IS NOT NULL
     AND now() >= v_round.finished_ends_at THEN
    PERFORM public._horse_race_create_round();
    RETURN;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_horse_race_state()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_round RECORD;
  v_settings RECORD;
  v_my_bet JSONB;
  v_horses JSONB;
  v_recent JSONB;
  v_seconds_left INTEGER;
BEGIN
  PERFORM public.tick_horse_race_engine();

  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default' AND is_active = TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'At yarisi kapali.');
  END IF;

  SELECT *
  INTO v_round
  FROM public.horse_race_rounds
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Aktif tur yok.');
  END IF;

  v_seconds_left := CASE v_round.status
    WHEN 'betting' THEN GREATEST(0, EXTRACT(EPOCH FROM (v_round.betting_ends_at - now()))::INTEGER)
    WHEN 'racing' THEN GREATEST(0, EXTRACT(EPOCH FROM (v_round.racing_ends_at - now()))::INTEGER)
    WHEN 'finished' THEN GREATEST(0, EXTRACT(EPOCH FROM (v_round.finished_ends_at - now()))::INTEGER)
    ELSE 0
  END;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'horse_id', e.horse_id,
      'name', t.name,
      'emoji', t.emoji,
      'lane_color', t.lane_color,
      'gold_multiplier', e.gold_multiplier,
      'gem_multiplier', e.gem_multiplier,
      'win_chance_pct', e.win_chance_pct,
      'sort_order', e.sort_order
    )
    ORDER BY e.sort_order ASC
  ), '[]'::jsonb)
  INTO v_horses
  FROM public.horse_race_round_entries e
  JOIN public.horse_race_templates t ON t.id = e.horse_id
  WHERE e.round_id = v_round.id;

  IF v_user_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'horse_id', b.horse_id,
      'currency_type', b.currency_type,
      'bet_amount', b.bet_amount,
      'multiplier', b.multiplier,
      'won', b.won,
      'payout_amount', b.payout_amount
    )
    INTO v_my_bet
    FROM public.horse_race_bets b
    WHERE b.round_id = v_round.id
      AND b.user_id = v_user_id
    LIMIT 1;
  END IF;

  SELECT COALESCE(jsonb_agg(x ORDER BY x->>'finished_at' DESC), '[]'::jsonb)
  INTO v_recent
  FROM (
    SELECT jsonb_build_object(
      'round_id', r.id,
      'winner_horse_id', r.winner_horse_id,
      'winner_name', t.name,
      'winner_emoji', t.emoji,
      'finished_at', r.racing_ends_at
    ) AS x
    FROM public.horse_race_rounds r
    LEFT JOIN public.horse_race_templates t ON t.id = r.winner_horse_id
    WHERE r.status = 'finished'
      AND r.winner_horse_id IS NOT NULL
    ORDER BY r.racing_ends_at DESC NULLS LAST
    LIMIT 30
  ) sub;

  RETURN jsonb_build_object(
    'success', true,
    'settings', jsonb_build_object(
      'gold_min_bet', v_settings.gold_min_bet,
      'gold_max_bet', v_settings.gold_max_bet,
      'gem_min_bet', v_settings.gem_min_bet,
      'gem_max_bet', v_settings.gem_max_bet,
      'gold_max_multiplier', v_settings.gold_max_multiplier,
      'gem_max_multiplier', v_settings.gem_max_multiplier,
      'betting_seconds', v_settings.betting_seconds,
      'racing_seconds', v_settings.racing_seconds,
      'finished_seconds', v_settings.finished_seconds
    ),
    'round', jsonb_build_object(
      'id', v_round.id,
      'status', v_round.status,
      'seconds_left', v_seconds_left,
      'betting_ends_at', v_round.betting_ends_at,
      'racing_ends_at', v_round.racing_ends_at,
      'finished_ends_at', v_round.finished_ends_at,
      'winner_horse_id', v_round.winner_horse_id,
      'race_script', COALESCE(v_round.race_script, '{}'::jsonb)
    ),
    'horses', v_horses,
    'my_bet', COALESCE(v_my_bet, 'null'::jsonb),
    'recent_winners', v_recent
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.place_horse_race_bet(
  p_round_id UUID,
  p_horse_id TEXT,
  p_currency_type TEXT,
  p_bet_amount INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_settings RECORD;
  v_round RECORD;
  v_entry RECORD;
  v_balance_ok BOOLEAN := FALSE;
  v_mult NUMERIC;
  v_existing UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum gerekli.');
  END IF;

  PERFORM public.tick_horse_race_engine();

  IF p_currency_type NOT IN ('gold', 'gems') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz para birimi.');
  END IF;

  IF COALESCE(p_bet_amount, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bahis tutari gecersiz.');
  END IF;

  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default' AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'At yarisi kapali.');
  END IF;

  SELECT *
  INTO v_round
  FROM public.horse_race_rounds
  WHERE id = p_round_id;

  IF NOT FOUND OR v_round.status <> 'betting' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bahis suresi kapandi.');
  END IF;

  SELECT id INTO v_existing
  FROM public.horse_race_bets
  WHERE round_id = p_round_id AND user_id = v_user_id;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu turda zaten bahis yaptin.');
  END IF;

  SELECT *
  INTO v_entry
  FROM public.horse_race_round_entries
  WHERE round_id = p_round_id AND horse_id = p_horse_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'At bu turda yok.');
  END IF;

  v_mult := CASE
    WHEN p_currency_type = 'gems' THEN v_entry.gem_multiplier
    ELSE v_entry.gold_multiplier
  END;

  IF p_currency_type = 'gems' THEN
    IF p_bet_amount < v_settings.gem_min_bet OR p_bet_amount > v_settings.gem_max_bet THEN
      RETURN jsonb_build_object(
        'success', false,
        'message',
        format('Elmas bahis %s-%s arasi olmali.', v_settings.gem_min_bet, v_settings.gem_max_bet)
      );
    END IF;

    UPDATE public.users
    SET gems = gems - p_bet_amount
    WHERE auth_id = v_user_id AND gems >= p_bet_amount
    RETURNING TRUE INTO v_balance_ok;
  ELSE
    IF p_bet_amount < v_settings.gold_min_bet OR p_bet_amount > v_settings.gold_max_bet THEN
      RETURN jsonb_build_object(
        'success', false,
        'message',
        format('Altin bahis %s-%s arasi olmali.', v_settings.gold_min_bet, v_settings.gold_max_bet)
      );
    END IF;

    UPDATE public.users
    SET gold = gold - p_bet_amount
    WHERE auth_id = v_user_id AND gold >= p_bet_amount
    RETURNING TRUE INTO v_balance_ok;
  END IF;

  IF COALESCE(v_balance_ok, FALSE) = FALSE THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz bakiye.');
  END IF;

  INSERT INTO public.horse_race_bets (
    round_id,
    user_id,
    horse_id,
    currency_type,
    bet_amount,
    multiplier
  ) VALUES (
    p_round_id,
    v_user_id,
    p_horse_id,
    p_currency_type,
    p_bet_amount,
    v_mult
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Bahis alindi.',
    'horse_id', p_horse_id,
    'currency_type', p_currency_type,
    'bet_amount', p_bet_amount,
    'multiplier', v_mult
  );
END;
$$;

-- Drop legacy RPCs / table
DROP FUNCTION IF EXISTS public.get_horse_race_board();
DROP FUNCTION IF EXISTS public.place_horse_race_bet(TEXT, TEXT, INTEGER);

GRANT EXECUTE ON FUNCTION public.get_horse_race_state() TO authenticated;
GRANT EXECUTE ON FUNCTION public.place_horse_race_bet(UUID, TEXT, TEXT, INTEGER) TO authenticated;

-- Bootstrap first round if none exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.horse_race_rounds) THEN
    PERFORM public._horse_race_create_round();
  END IF;
END $$;

COMMIT;
