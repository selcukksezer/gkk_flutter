-- Fractional gem payouts for horse race + decimal gems balance

ALTER TABLE public.users
  ALTER COLUMN gems TYPE NUMERIC(14, 2) USING gems::NUMERIC(14, 2);

ALTER TABLE public.horse_race_bets
  ALTER COLUMN payout_amount TYPE NUMERIC(14, 2) USING payout_amount::NUMERIC(14, 2);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'player_horse_race_logs'
      AND column_name = 'payout_amount'
  ) THEN
    ALTER TABLE public.player_horse_race_logs
      ALTER COLUMN payout_amount TYPE NUMERIC(14, 2) USING payout_amount::NUMERIC(14, 2);
  END IF;
END $$;

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
        UPDATE public.users
        SET gems = gems + v_payout
        WHERE auth_id = v_bet.user_id;
      ELSE
        v_payout := GREATEST(
          1,
          FLOOR(v_bet.bet_amount * v_mult * COALESCE(v_settings.house_edge, 0.92))::INTEGER
        );
        UPDATE public.users
        SET gold = gold + v_payout::INTEGER
        WHERE auth_id = v_bet.user_id;
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
      jsonb_build_object('source', 'global_scheduled_v2')
    );
  END LOOP;
END;
$$;
