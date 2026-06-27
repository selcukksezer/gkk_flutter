-- Horse race RTP + gems fairness fix
-- house_edge = target RTP (0.92 => 92% return to player on any horse at true odds)
-- multiplier = (1 / win_probability) * house_edge
-- gem_multiplier uses same (1/p)*RTP formula with gem caps

COMMENT ON COLUMN public.horse_race_settings.house_edge IS
  'Target RTP for a single-horse bet when multipliers are uncapped (0.92 = 92% return).';

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
  v_house_edge NUMERIC := 0.92;
  v_count INTEGER;
  v_total_weight NUMERIC := 0;
  v_weight NUMERIC;
  v_win_prob NUMERIC;
  v_gold_mult NUMERIC;
  v_gem_mult NUMERIC;
  v_entries JSONB := '[]'::jsonb;
  v_row RECORD;
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
  v_house_edge := COALESCE(v_settings.house_edge, 0.92);

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
    v_weight := GREATEST(0.05, random());
    v_total_weight := v_total_weight + v_weight;

    v_entries := v_entries || jsonb_build_array(
      jsonb_build_object(
        'horse_id', v_horse.id,
        'win_weight', v_weight
      )
    );
  END LOOP;

  FOR v_row IN
    SELECT *
    FROM jsonb_to_recordset(v_entries) AS e(
      horse_id TEXT,
      win_weight NUMERIC
    )
  LOOP
    v_win_prob := v_row.win_weight / NULLIF(v_total_weight, 0);
    v_gold_mult := public._horse_race_clamp_mult(
      ((1 / NULLIF(v_win_prob, 0)) * v_house_edge)::DOUBLE PRECISION,
      v_gold_min::DOUBLE PRECISION,
      v_gold_max::DOUBLE PRECISION
    );
    v_gem_mult := public._horse_race_clamp_mult(
      ((1 / NULLIF(v_win_prob, 0)) * v_house_edge)::DOUBLE PRECISION,
      v_gem_min::DOUBLE PRECISION,
      v_gem_max::DOUBLE PRECISION
    );

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
      v_row.horse_id,
      v_gold_mult,
      v_gem_mult,
      v_row.win_weight,
      ROUND((v_win_prob * 100)::NUMERIC, 2),
      0
    );
  END LOOP;

  WITH ranked AS (
    SELECT
      e.id,
      ROW_NUMBER() OVER (ORDER BY e.gold_multiplier ASC) AS rn
    FROM public.horse_race_round_entries e
    WHERE e.round_id = v_round_id
  )
  UPDATE public.horse_race_round_entries e
  SET sort_order = ranked.rn
  FROM ranked
  WHERE e.id = ranked.id;

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
        v_payout := ROUND((v_bet.bet_amount::NUMERIC * v_mult)::NUMERIC, 2);
        UPDATE public.users SET gems = gems + v_payout WHERE auth_id = v_bet.user_id;
      ELSE
        v_payout := GREATEST(1, FLOOR(v_bet.bet_amount * v_mult)::INTEGER);
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

CREATE OR REPLACE FUNCTION public._qa_horse_race_sim_entries()
RETURNS TABLE (
  horse_id TEXT,
  gold_multiplier NUMERIC,
  gem_multiplier NUMERIC,
  win_weight NUMERIC,
  sort_order INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_settings RECORD;
  v_horse RECORD;
  v_gold_min NUMERIC := 1.20;
  v_gold_max NUMERIC := 5.00;
  v_gem_min NUMERIC := 1.10;
  v_gem_max NUMERIC := 2.00;
  v_house_edge NUMERIC := 0.92;
  v_count INTEGER;
  v_total_weight NUMERIC := 0;
  v_weight NUMERIC;
  v_win_prob NUMERIC;
  v_gold_mult NUMERIC;
  v_gem_mult NUMERIC;
  v_entries JSONB := '[]'::jsonb;
BEGIN
  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default' AND is_active = TRUE
  LIMIT 1;

  IF FOUND THEN
    v_gold_max := COALESCE(v_settings.gold_max_multiplier, 5.00);
    v_gem_max := COALESCE(v_settings.gem_max_multiplier, 2.00);
    v_house_edge := COALESCE(v_settings.house_edge, 0.92);
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.horse_race_templates
  WHERE is_active = TRUE;

  IF v_count < 2 THEN
    RAISE EXCEPTION 'not enough active horses for smoke sim';
  END IF;

  FOR v_horse IN
    SELECT id
    FROM public.horse_race_templates
    WHERE is_active = TRUE
    ORDER BY random()
    LIMIT 6
  LOOP
    v_weight := GREATEST(0.05, random());
    v_total_weight := v_total_weight + v_weight;
    v_entries := v_entries || jsonb_build_array(
      jsonb_build_object('horse_id', v_horse.id, 'win_weight', v_weight)
    );
  END LOOP;

  RETURN QUERY
  WITH base AS (
    SELECT
      e.horse_id,
      e.win_weight,
      (e.win_weight / NULLIF(v_total_weight, 0)) AS win_prob
    FROM jsonb_to_recordset(v_entries) AS e(
      horse_id TEXT,
      win_weight NUMERIC
    )
  ),
  priced AS (
    SELECT
      b.horse_id,
      b.win_weight,
      b.win_prob,
      public._horse_race_clamp_mult(
        ((1 / NULLIF(b.win_prob, 0)) * v_house_edge)::DOUBLE PRECISION,
        v_gold_min::DOUBLE PRECISION,
        v_gold_max::DOUBLE PRECISION
      ) AS gold_multiplier,
      public._horse_race_clamp_mult(
        ((1 / NULLIF(b.win_prob, 0)) * v_house_edge)::DOUBLE PRECISION,
        v_gem_min::DOUBLE PRECISION,
        v_gem_max::DOUBLE PRECISION
      ) AS gem_multiplier
    FROM base b
  )
  SELECT
    p.horse_id,
    p.gold_multiplier,
    p.gem_multiplier,
    p.win_weight,
    ROW_NUMBER() OVER (ORDER BY p.gold_multiplier ASC)::INTEGER AS sort_order
  FROM priced p;
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_smoke_horse_race_fairness(
  p_runs INTEGER DEFAULT 500
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_settings RECORD;
  v_run INTEGER;
  v_winner RECORD;
  v_house_edge NUMERIC := 0.92;
  v_gold_bet INTEGER := 10000;
  v_gem_bet INTEGER := 1;

  v_winner_sort_counts JSONB := '{}'::jsonb;
  v_winner_gold_mult_sum NUMERIC := 0;
  v_lowest_gold_wins INTEGER := 0;
  v_lowest_gem_wins INTEGER := 0;
  v_highest_gem_wins INTEGER := 0;

  v_gold_low_wins INTEGER := 0;
  v_gold_low_losses INTEGER := 0;
  v_gold_low_wagered BIGINT := 0;
  v_gold_low_payout BIGINT := 0;

  v_gold_high_wins INTEGER := 0;
  v_gold_high_losses INTEGER := 0;
  v_gold_high_wagered BIGINT := 0;
  v_gold_high_payout BIGINT := 0;

  v_gems_low_wins INTEGER := 0;
  v_gems_low_losses INTEGER := 0;
  v_gems_low_wagered NUMERIC := 0;
  v_gems_low_payout NUMERIC := 0;

  v_gems_high_wins INTEGER := 0;
  v_gems_high_losses INTEGER := 0;
  v_gems_high_wagered NUMERIC := 0;
  v_gems_high_payout NUMERIC := 0;

  v_low_gold_horse TEXT;
  v_high_gold_horse TEXT;
  v_low_gem_horse TEXT;
  v_high_gem_horse TEXT;
  v_low_gold_mult NUMERIC;
  v_high_gold_mult NUMERIC;
  v_low_gem_mult NUMERIC;
  v_high_gem_mult NUMERIC;
  v_payout NUMERIC;
  v_sort_key TEXT;
  v_samples JSONB := '[]'::jsonb;
  v_report JSONB;
BEGIN
  IF p_runs < 1 OR p_runs > 100000 THEN
    RAISE EXCEPTION 'p_runs must be between 1 and 100000';
  END IF;

  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default' AND is_active = TRUE
  LIMIT 1;

  IF FOUND THEN
    v_house_edge := COALESCE(v_settings.house_edge, 0.92);
    v_gold_bet := COALESCE(v_settings.gold_min_bet, 10000);
    v_gem_bet := COALESCE(v_settings.gem_min_bet, 1);
  END IF;

  CREATE TEMP TABLE _qa_round_entries (
    horse_id TEXT PRIMARY KEY,
    gold_multiplier NUMERIC NOT NULL,
    gem_multiplier NUMERIC NOT NULL,
    win_weight NUMERIC NOT NULL,
    win_chance_pct NUMERIC NOT NULL,
    sort_order INTEGER NOT NULL
  ) ON COMMIT DROP;

  FOR v_run IN 1..p_runs LOOP
    TRUNCATE _qa_round_entries;

    INSERT INTO _qa_round_entries (
      horse_id,
      gold_multiplier,
      gem_multiplier,
      win_weight,
      win_chance_pct,
      sort_order
    )
    SELECT
      horse_id,
      gold_multiplier,
      gem_multiplier,
      win_weight,
      ROUND((win_weight / NULLIF(SUM(win_weight) OVER (), 0) * 100)::NUMERIC, 2),
      sort_order
    FROM public._qa_horse_race_sim_entries();

    SELECT horse_id, gold_multiplier
    INTO v_low_gold_horse, v_low_gold_mult
    FROM _qa_round_entries ORDER BY sort_order ASC LIMIT 1;

    SELECT horse_id, gold_multiplier
    INTO v_high_gold_horse, v_high_gold_mult
    FROM _qa_round_entries ORDER BY sort_order DESC LIMIT 1;

    SELECT horse_id, gem_multiplier
    INTO v_low_gem_horse, v_low_gem_mult
    FROM _qa_round_entries ORDER BY sort_order ASC LIMIT 1;

    SELECT horse_id, gem_multiplier
    INTO v_high_gem_horse, v_high_gem_mult
    FROM _qa_round_entries ORDER BY sort_order DESC LIMIT 1;

    SELECT e.horse_id, e.sort_order, e.gold_multiplier, e.gem_multiplier
    INTO v_winner
    FROM _qa_round_entries e
    ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.win_weight, 1e-9)
    LIMIT 1;

    v_sort_key := v_winner.sort_order::TEXT;
    v_winner_sort_counts := jsonb_set(
      v_winner_sort_counts,
      ARRAY[v_sort_key],
      to_jsonb(COALESCE((v_winner_sort_counts ->> v_sort_key)::INTEGER, 0) + 1),
      TRUE
    );
    v_winner_gold_mult_sum := v_winner_gold_mult_sum + v_winner.gold_multiplier;

    IF v_winner.horse_id = v_low_gold_horse THEN v_lowest_gold_wins := v_lowest_gold_wins + 1; END IF;
    IF v_winner.horse_id = v_low_gem_horse THEN v_lowest_gem_wins := v_lowest_gem_wins + 1; END IF;
    IF v_winner.horse_id = v_high_gem_horse THEN v_highest_gem_wins := v_highest_gem_wins + 1; END IF;

    v_gold_low_wagered := v_gold_low_wagered + v_gold_bet;
    IF v_winner.horse_id = v_low_gold_horse THEN
      v_gold_low_wins := v_gold_low_wins + 1;
      v_payout := GREATEST(1, FLOOR(v_gold_bet * v_low_gold_mult)::INTEGER);
      v_gold_low_payout := v_gold_low_payout + v_payout::BIGINT;
    ELSE
      v_gold_low_losses := v_gold_low_losses + 1;
    END IF;

    v_gold_high_wagered := v_gold_high_wagered + v_gold_bet;
    IF v_winner.horse_id = v_high_gold_horse THEN
      v_gold_high_wins := v_gold_high_wins + 1;
      v_payout := GREATEST(1, FLOOR(v_gold_bet * v_high_gold_mult)::INTEGER);
      v_gold_high_payout := v_gold_high_payout + v_payout::BIGINT;
    ELSE
      v_gold_high_losses := v_gold_high_losses + 1;
    END IF;

    v_gems_low_wagered := v_gems_low_wagered + v_gem_bet;
    IF v_winner.horse_id = v_low_gem_horse THEN
      v_gems_low_wins := v_gems_low_wins + 1;
      v_payout := ROUND((v_gem_bet::NUMERIC * v_low_gem_mult)::NUMERIC, 2);
      v_gems_low_payout := v_gems_low_payout + v_payout;
    ELSE
      v_gems_low_losses := v_gems_low_losses + 1;
    END IF;

    v_gems_high_wagered := v_gems_high_wagered + v_gem_bet;
    IF v_winner.horse_id = v_high_gem_horse THEN
      v_gems_high_wins := v_gems_high_wins + 1;
      v_payout := ROUND((v_gem_bet::NUMERIC * v_high_gem_mult)::NUMERIC, 2);
      v_gems_high_payout := v_gems_high_payout + v_payout;
    ELSE
      v_gems_high_losses := v_gems_high_losses + 1;
    END IF;

    IF v_run <= 5 THEN
      v_samples := v_samples || jsonb_build_array(
        jsonb_build_object(
          'run', v_run,
          'winner_sort_order', v_winner.sort_order,
          'winner_gold_mult', v_winner.gold_multiplier,
          'lowest_gold_mult', v_low_gold_mult,
          'lowest_gem_mult', v_low_gem_mult,
          'highest_gem_mult', v_high_gem_mult
        )
      );
    END IF;
  END LOOP;

  v_report := jsonb_build_object(
    'success', TRUE,
    'runs', p_runs,
    'generated_at', now(),
    'config', jsonb_build_object(
      'house_edge', v_house_edge,
      'house_edge_meaning', 'target RTP (0.92 = 92% player return)',
      'gold_bet_per_round', v_gold_bet,
      'gem_bet_per_round', v_gem_bet,
      'multiplier_formula', '(1 / win_probability) * house_edge',
      'payout_formula', 'bet_amount * multiplier (RTP already in multiplier)'
    ),
    'fairness_check', jsonb_build_object(
      'lowest_gold_mult_wins', v_lowest_gold_wins,
      'lowest_gold_mult_win_pct', ROUND((v_lowest_gold_wins::NUMERIC / p_runs * 100), 2),
      'lowest_gem_mult_wins', v_lowest_gem_wins,
      'lowest_gem_mult_win_pct', ROUND((v_lowest_gem_wins::NUMERIC / p_runs * 100), 2),
      'highest_gem_mult_wins', v_highest_gem_wins,
      'highest_gem_mult_win_pct', ROUND((v_highest_gem_wins::NUMERIC / p_runs * 100), 2),
      'gems_low_beats_high', v_lowest_gem_wins > v_highest_gem_wins,
      'always_lowest_gold_wins', v_lowest_gold_wins = p_runs,
      'avg_winner_gold_mult', ROUND(v_winner_gold_mult_sum / p_runs, 2),
      'verdict', CASE
        WHEN v_lowest_gold_wins = p_runs THEN 'FAIL: lowest gold mult wins every round'
        WHEN v_lowest_gem_wins <= v_highest_gem_wins THEN 'FAIL: gems low mult does not beat high mult win rate'
        WHEN (v_lowest_gold_wins::NUMERIC / p_runs) < 0.15 THEN 'WARN: lowest gold mult win rate unusually low'
        ELSE 'PASS: inverse odds + aligned gem ranks'
      END
    ),
    'winner_distribution_by_sort_order', (
      SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
          'sort_order', s.sort_order,
          'wins', COALESCE((v_winner_sort_counts ->> s.sort_order::TEXT)::INTEGER, 0),
          'win_pct', ROUND(
            COALESCE((v_winner_sort_counts ->> s.sort_order::TEXT)::NUMERIC, 0) / p_runs * 100,
            2
          )
        )
        ORDER BY s.sort_order
      ), '[]'::jsonb)
      FROM generate_series(1, 6) AS s(sort_order)
    ),
    'gold_lowest_mult_strategy', jsonb_build_object(
      'rounds', p_runs,
      'wins', v_gold_low_wins,
      'losses', v_gold_low_losses,
      'win_rate_pct', ROUND(v_gold_low_wins::NUMERIC / p_runs * 100, 2),
      'total_wagered', v_gold_low_wagered,
      'total_payout', v_gold_low_payout,
      'net_profit', v_gold_low_payout - v_gold_low_wagered,
      'rtp_pct', ROUND(
        CASE WHEN v_gold_low_wagered > 0 THEN v_gold_low_payout::NUMERIC / v_gold_low_wagered * 100 ELSE 0 END,
        2
      ),
      'target_rtp_pct', ROUND(v_house_edge * 100, 2)
    ),
    'gold_highest_mult_strategy', jsonb_build_object(
      'rounds', p_runs,
      'wins', v_gold_high_wins,
      'losses', v_gold_high_losses,
      'win_rate_pct', ROUND(v_gold_high_wins::NUMERIC / p_runs * 100, 2),
      'total_wagered', v_gold_high_wagered,
      'total_payout', v_gold_high_payout,
      'net_profit', v_gold_high_payout - v_gold_high_wagered,
      'rtp_pct', ROUND(
        CASE WHEN v_gold_high_wagered > 0 THEN v_gold_high_payout::NUMERIC / v_gold_high_wagered * 100 ELSE 0 END,
        2
      ),
      'target_rtp_pct', ROUND(v_house_edge * 100, 2)
    ),
    'gems_lowest_mult_strategy', jsonb_build_object(
      'rounds', p_runs,
      'wins', v_gems_low_wins,
      'losses', v_gems_low_losses,
      'win_rate_pct', ROUND(v_gems_low_wins::NUMERIC / p_runs * 100, 2),
      'total_wagered', v_gems_low_wagered,
      'total_payout', v_gems_low_payout,
      'net_profit', v_gems_low_payout - v_gems_low_wagered,
      'rtp_pct', ROUND(
        CASE WHEN v_gems_low_wagered > 0 THEN v_gems_low_payout / v_gems_low_wagered * 100 ELSE 0 END,
        2
      ),
      'target_rtp_pct', ROUND(v_house_edge * 100, 2)
    ),
    'gems_highest_mult_strategy', jsonb_build_object(
      'rounds', p_runs,
      'wins', v_gems_high_wins,
      'losses', v_gems_high_losses,
      'win_rate_pct', ROUND(v_gems_high_wins::NUMERIC / p_runs * 100, 2),
      'total_wagered', v_gems_high_wagered,
      'total_payout', v_gems_high_payout,
      'net_profit', v_gems_high_payout - v_gems_high_wagered,
      'rtp_pct', ROUND(
        CASE WHEN v_gems_high_wagered > 0 THEN v_gems_high_payout / v_gems_high_wagered * 100 ELSE 0 END,
        2
      ),
      'target_rtp_pct', ROUND(v_house_edge * 100, 2)
    ),
    'sample_rounds', v_samples
  );

  INSERT INTO public.qa_horse_race_smoke_runs (runs, report)
  VALUES (p_runs, v_report);

  RETURN v_report;
END;
$$;

UPDATE public.horse_race_settings
SET gem_max_multiplier = 3.50
WHERE id = 'default'
  AND gem_max_multiplier <= 2.00;

GRANT EXECUTE ON FUNCTION public.qa_smoke_horse_race_fairness(INTEGER) TO authenticated, service_role;
