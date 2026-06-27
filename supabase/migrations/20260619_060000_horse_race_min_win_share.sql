-- Enforce minimum win share per horse so long-shot multipliers stay within caps
-- while preserving ~92% RTP on sort_order-6 (highest mult) bets.
-- Without a floor, raw random weights can yield ~1-5% tails needing 18x+ mult.

CREATE OR REPLACE FUNCTION public._horse_race_sample_entry_weights(p_count INTEGER DEFAULT 6)
RETURNS NUMERIC[]
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_weights NUMERIC[];
  v_total NUMERIC;
  v_min_prob NUMERIC;
  v_min_share CONSTANT NUMERIC := 0.08;
  v_i INTEGER;
  v_attempt INTEGER;
  v_w NUMERIC;
BEGIN
  IF p_count < 2 OR p_count > 12 THEN
    RAISE EXCEPTION 'p_count must be between 2 and 12';
  END IF;

  FOR v_attempt IN 1..64 LOOP
    v_weights := ARRAY[]::NUMERIC[];
    v_total := 0;

    FOR v_i IN 1..p_count LOOP
      v_w := GREATEST(0.05, random());
      v_weights := array_append(v_weights, v_w);
      v_total := v_total + v_w;
    END LOOP;

    SELECT MIN(w / NULLIF(v_total, 0))
    INTO v_min_prob
    FROM unnest(v_weights) AS w;

    IF COALESCE(v_min_prob, 0) >= v_min_share THEN
      RETURN v_weights;
    END IF;
  END LOOP;

  RETURN (
    SELECT ARRAY_AGG(v ORDER BY ord)
    FROM (
      VALUES
        (1, 0.30::NUMERIC),
        (2, 0.22::NUMERIC),
        (3, 0.18::NUMERIC),
        (4, 0.14::NUMERIC),
        (5, 0.10::NUMERIC),
        (6, 0.08::NUMERIC),
        (7, 0.06::NUMERIC),
        (8, 0.05::NUMERIC),
        (9, 0.04::NUMERIC),
        (10, 0.035::NUMERIC),
        (11, 0.03::NUMERIC),
        (12, 0.025::NUMERIC)
    ) AS ladder(ord, v)
    WHERE ord <= p_count
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
  v_house_edge NUMERIC := 0.92;
  v_count INTEGER;
  v_total_weight NUMERIC := 0;
  v_weight NUMERIC;
  v_win_prob NUMERIC;
  v_gold_mult NUMERIC;
  v_gem_mult NUMERIC;
  v_entries JSONB := '[]'::jsonb;
  v_row RECORD;
  v_weights NUMERIC[];
  v_idx INTEGER := 0;
BEGIN
  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default' AND is_active = TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'horse race settings missing';
  END IF;

  v_gold_max := COALESCE(v_settings.gold_max_multiplier, 12.00);
  v_gem_max := COALESCE(v_settings.gem_max_multiplier, 12.00);
  v_house_edge := COALESCE(v_settings.house_edge, 0.92);

  SELECT COUNT(*) INTO v_count
  FROM public.horse_race_templates
  WHERE is_active = TRUE;

  IF v_count < 2 THEN
    RAISE EXCEPTION 'not enough active horses';
  END IF;

  v_count := LEAST(v_count, 6);
  v_weights := public._horse_race_sample_entry_weights(v_count);

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
    LIMIT v_count
  LOOP
    v_idx := v_idx + 1;
    v_weight := v_weights[v_idx];
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
  v_entries JSONB := '[]'::jsonb;
  v_weights NUMERIC[];
  v_idx INTEGER := 0;
  v_weight NUMERIC;
BEGIN
  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default' AND is_active = TRUE
  LIMIT 1;

  IF FOUND THEN
    v_gold_max := COALESCE(v_settings.gold_max_multiplier, 12.00);
    v_gem_max := COALESCE(v_settings.gem_max_multiplier, 12.00);
    v_house_edge := COALESCE(v_settings.house_edge, 0.92);
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.horse_race_templates
  WHERE is_active = TRUE;

  IF v_count < 2 THEN
    RAISE EXCEPTION 'not enough active horses for smoke sim';
  END IF;

  v_count := LEAST(v_count, 6);
  v_weights := public._horse_race_sample_entry_weights(v_count);

  FOR v_horse IN
    SELECT id
    FROM public.horse_race_templates
    WHERE is_active = TRUE
    ORDER BY random()
    LIMIT v_count
  LOOP
    v_idx := v_idx + 1;
    v_weight := v_weights[v_idx];
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

UPDATE public.horse_race_settings
SET gem_max_multiplier = 12.00
WHERE id = 'default';

ALTER TABLE public.horse_race_settings
  ALTER COLUMN gem_max_multiplier SET DEFAULT 12.00;

GRANT EXECUTE ON FUNCTION public._horse_race_sample_entry_weights(INTEGER) TO authenticated, service_role;
