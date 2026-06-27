-- Horse race fairness smoke: 500-run Monte Carlo using production odds + payout rules

CREATE TABLE IF NOT EXISTS public.qa_horse_race_smoke_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  runs INTEGER NOT NULL,
  report JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

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
  v_count INTEGER;
  v_idx INTEGER := 0;
  v_gold_mult NUMERIC;
  v_gem_mult NUMERIC;
  v_entries JSONB := '[]'::jsonb;
  v_sorted RECORD;
BEGIN
  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default' AND is_active = TRUE
  LIMIT 1;

  IF FOUND THEN
    v_gold_max := COALESCE(v_settings.gold_max_multiplier, 5.00);
    v_gem_max := COALESCE(v_settings.gem_max_multiplier, 2.00);
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

    v_entries := v_entries || jsonb_build_array(
      jsonb_build_object(
        'horse_id', v_horse.id,
        'gold_multiplier', v_gold_mult,
        'gem_multiplier', v_gem_mult,
        'win_weight', 1 / POWER(v_gold_mult, 2)
      )
    );
  END LOOP;

  RETURN QUERY
  SELECT
    e.horse_id,
    e.gold_multiplier,
    e.gem_multiplier,
    e.win_weight,
    ROW_NUMBER() OVER (ORDER BY e.gold_multiplier ASC)::INTEGER AS sort_order
  FROM jsonb_to_recordset(v_entries) AS e(
    horse_id TEXT,
    gold_multiplier NUMERIC,
    gem_multiplier NUMERIC,
    win_weight NUMERIC
  );
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
  v_entry RECORD;
  v_house_edge NUMERIC := 0.92;
  v_gold_bet INTEGER := 10000;
  v_gem_bet INTEGER := 1;

  v_winner_sort_counts JSONB := '{}'::jsonb;
  v_winner_gold_mult_sum NUMERIC := 0;
  v_lowest_gold_wins INTEGER := 0;
  v_lowest_gem_wins INTEGER := 0;

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
  IF p_runs < 1 OR p_runs > 5000 THEN
    RAISE EXCEPTION 'p_runs must be between 1 and 5000';
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
    sort_order INTEGER NOT NULL
  ) ON COMMIT DROP;

  FOR v_run IN 1..p_runs LOOP
    TRUNCATE _qa_round_entries;

    INSERT INTO _qa_round_entries (horse_id, gold_multiplier, gem_multiplier, win_weight, sort_order)
    SELECT horse_id, gold_multiplier, gem_multiplier, win_weight, sort_order
    FROM public._qa_horse_race_sim_entries();

    SELECT horse_id, gold_multiplier
    INTO v_low_gold_horse, v_low_gold_mult
    FROM _qa_round_entries
    ORDER BY sort_order ASC
    LIMIT 1;

    SELECT horse_id, gold_multiplier
    INTO v_high_gold_horse, v_high_gold_mult
    FROM _qa_round_entries
    ORDER BY sort_order DESC
    LIMIT 1;

    SELECT horse_id, gem_multiplier
    INTO v_low_gem_horse, v_low_gem_mult
    FROM _qa_round_entries
    ORDER BY gem_multiplier ASC
    LIMIT 1;

    SELECT horse_id, gem_multiplier
    INTO v_high_gem_horse, v_high_gem_mult
    FROM _qa_round_entries
    ORDER BY gem_multiplier DESC
    LIMIT 1;

    SELECT
      e.horse_id,
      e.sort_order,
      e.gold_multiplier,
      e.gem_multiplier
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

    IF v_winner.horse_id = v_low_gold_horse THEN
      v_lowest_gold_wins := v_lowest_gold_wins + 1;
    END IF;
    IF v_winner.horse_id = v_low_gem_horse THEN
      v_lowest_gem_wins := v_lowest_gem_wins + 1;
    END IF;

    -- Gold: always bet lowest gold mult
    v_gold_low_wagered := v_gold_low_wagered + v_gold_bet;
    IF v_winner.horse_id = v_low_gold_horse THEN
      v_gold_low_wins := v_gold_low_wins + 1;
      v_payout := GREATEST(1, FLOOR(v_gold_bet * v_low_gold_mult * v_house_edge)::INTEGER);
      v_gold_low_payout := v_gold_low_payout + v_payout::BIGINT;
    ELSE
      v_gold_low_losses := v_gold_low_losses + 1;
    END IF;

    -- Gold: always bet highest gold mult
    v_gold_high_wagered := v_gold_high_wagered + v_gold_bet;
    IF v_winner.horse_id = v_high_gold_horse THEN
      v_gold_high_wins := v_gold_high_wins + 1;
      v_payout := GREATEST(1, FLOOR(v_gold_bet * v_high_gold_mult * v_house_edge)::INTEGER);
      v_gold_high_payout := v_gold_high_payout + v_payout::BIGINT;
    ELSE
      v_gold_high_losses := v_gold_high_losses + 1;
    END IF;

    -- Gems: always bet lowest gem mult
    v_gems_low_wagered := v_gems_low_wagered + v_gem_bet;
    IF v_winner.horse_id = v_low_gem_horse THEN
      v_gems_low_wins := v_gems_low_wins + 1;
      v_payout := ROUND((v_gem_bet::NUMERIC * v_low_gem_mult * v_house_edge)::NUMERIC, 2);
      v_gems_low_payout := v_gems_low_payout + v_payout;
    ELSE
      v_gems_low_losses := v_gems_low_losses + 1;
    END IF;

    -- Gems: always bet highest gem mult
    v_gems_high_wagered := v_gems_high_wagered + v_gem_bet;
    IF v_winner.horse_id = v_high_gem_horse THEN
      v_gems_high_wins := v_gems_high_wins + 1;
      v_payout := ROUND((v_gem_bet::NUMERIC * v_high_gem_mult * v_house_edge)::NUMERIC, 2);
      v_gems_high_payout := v_gems_high_payout + v_payout;
    ELSE
      v_gems_high_losses := v_gems_high_losses + 1;
    END IF;

    IF v_run <= 5 THEN
      v_samples := v_samples || jsonb_build_array(
        jsonb_build_object(
          'run', v_run,
          'winner_horse_id', v_winner.horse_id,
          'winner_sort_order', v_winner.sort_order,
          'winner_gold_mult', v_winner.gold_multiplier,
          'winner_gem_mult', v_winner.gem_multiplier,
          'lowest_gold_horse_id', v_low_gold_horse,
          'lowest_gold_mult', v_low_gold_mult,
          'lowest_gem_horse_id', v_low_gem_horse,
          'lowest_gem_mult', v_low_gem_mult,
          'entries', (
            SELECT COALESCE(jsonb_agg(
              jsonb_build_object(
                'horse_id', e.horse_id,
                'sort_order', e.sort_order,
                'gold_mult', e.gold_multiplier,
                'gem_mult', e.gem_multiplier,
                'win_weight', ROUND(e.win_weight::NUMERIC, 6)
              )
              ORDER BY e.sort_order
            ), '[]'::jsonb)
            FROM _qa_round_entries e
          )
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
      'gold_bet_per_round', v_gold_bet,
      'gem_bet_per_round', v_gem_bet,
      'winner_algorithm', 'weighted by 1/gold_multiplier^2 (production)'
    ),
    'fairness_check', jsonb_build_object(
      'lowest_gold_mult_wins', v_lowest_gold_wins,
      'lowest_gold_mult_win_pct', ROUND((v_lowest_gold_wins::NUMERIC / p_runs * 100), 2),
      'lowest_gem_mult_wins', v_lowest_gem_wins,
      'lowest_gem_mult_win_pct', ROUND((v_lowest_gem_wins::NUMERIC / p_runs * 100), 2),
      'always_lowest_gold_wins', v_lowest_gold_wins = p_runs,
      'always_lowest_gem_wins', v_lowest_gem_wins = p_runs,
      'avg_winner_gold_mult', ROUND(v_winner_gold_mult_sum / p_runs, 2),
      'verdict', CASE
        WHEN v_lowest_gold_wins = p_runs OR v_lowest_gem_wins = p_runs THEN
          'FAIL: lowest multiplier horse wins every round'
        WHEN (v_lowest_gold_wins::NUMERIC / p_runs) >= 0.95 THEN
          'WARN: lowest gold mult wins >= 95% — investigate weighting'
        WHEN (v_lowest_gem_wins::NUMERIC / p_runs) >= 0.95 THEN
          'WARN: lowest gem mult wins >= 95% — investigate weighting'
        ELSE
          'PASS: winner distribution is probabilistic, not fixed'
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
          ),
          'note', CASE s.sort_order
            WHEN 1 THEN 'lowest gold mult lane'
            WHEN 6 THEN 'highest gold mult lane'
            ELSE 'middle lane'
          END
        )
        ORDER BY s.sort_order
      ), '[]'::jsonb)
      FROM generate_series(1, 6) AS s(sort_order)
    ),
    'gold_lowest_mult_strategy', jsonb_build_object(
      'label', 'Her tur en dusuk altin carpani ata bahis',
      'bet_per_round', v_gold_bet,
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
      )
    ),
    'gold_highest_mult_strategy', jsonb_build_object(
      'label', 'Her tur en yuksek altin carpani ata bahis',
      'bet_per_round', v_gold_bet,
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
      )
    ),
    'gems_lowest_mult_strategy', jsonb_build_object(
      'label', 'Her tur en dusuk elmas carpani ata bahis',
      'bet_per_round', v_gem_bet,
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
      )
    ),
    'gems_highest_mult_strategy', jsonb_build_object(
      'label', 'Her tur en yuksek elmas carpani ata bahis',
      'bet_per_round', v_gem_bet,
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
      )
    ),
    'sample_rounds', v_samples
  );

  INSERT INTO public.qa_horse_race_smoke_runs (runs, report)
  VALUES (p_runs, v_report);

  RETURN v_report;
END;
$$;

GRANT EXECUTE ON FUNCTION public.qa_smoke_horse_race_fairness(INTEGER) TO authenticated, service_role;
