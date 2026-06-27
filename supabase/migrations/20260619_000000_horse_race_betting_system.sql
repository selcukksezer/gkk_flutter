-- =====================================================
-- At Yarışı — gold + gem betting, modest gem multipliers
-- =====================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.horse_race_horses (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '🐴',
  lane_color TEXT NOT NULL DEFAULT '#94A3B8',
  win_weight NUMERIC(10,4) NOT NULL CHECK (win_weight > 0),
  gold_multiplier NUMERIC(6,2) NOT NULL CHECK (gold_multiplier > 0),
  gem_multiplier NUMERIC(6,2) NOT NULL CHECK (gem_multiplier > 0),
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.horse_race_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  gold_min_bet INTEGER NOT NULL DEFAULT 10000 CHECK (gold_min_bet > 0),
  gold_max_bet INTEGER NOT NULL DEFAULT 5000000 CHECK (gold_max_bet >= gold_min_bet),
  gem_min_bet INTEGER NOT NULL DEFAULT 1 CHECK (gem_min_bet > 0),
  gem_max_bet INTEGER NOT NULL DEFAULT 50 CHECK (gem_max_bet >= gem_min_bet),
  daily_bet_limit INTEGER CHECK (daily_bet_limit IS NULL OR daily_bet_limit > 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.player_horse_race_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  horse_id TEXT NOT NULL REFERENCES public.horse_race_horses(id) ON DELETE RESTRICT,
  picked_horse_id TEXT NOT NULL REFERENCES public.horse_race_horses(id) ON DELETE RESTRICT,
  winner_horse_id TEXT NOT NULL REFERENCES public.horse_race_horses(id) ON DELETE RESTRICT,
  currency_type TEXT NOT NULL CHECK (currency_type IN ('gold', 'gems')),
  bet_amount INTEGER NOT NULL CHECK (bet_amount > 0),
  multiplier NUMERIC(6,2) NOT NULL CHECK (multiplier > 0),
  won BOOLEAN NOT NULL DEFAULT FALSE,
  payout_amount INTEGER NOT NULL DEFAULT 0 CHECK (payout_amount >= 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_horse_race_horses_active_order
  ON public.horse_race_horses (is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_player_horse_race_logs_user_time
  ON public.player_horse_race_logs (user_id, created_at DESC);

ALTER TABLE public.horse_race_horses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horse_race_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_horse_race_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS horse_race_horses_select_auth ON public.horse_race_horses;
CREATE POLICY horse_race_horses_select_auth
ON public.horse_race_horses
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS horse_race_settings_select_auth ON public.horse_race_settings;
CREATE POLICY horse_race_settings_select_auth
ON public.horse_race_settings
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS player_horse_race_logs_select_own ON public.player_horse_race_logs;
CREATE POLICY player_horse_race_logs_select_own
ON public.player_horse_race_logs
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

INSERT INTO public.horse_race_settings (id)
VALUES ('default')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.horse_race_horses (
  id, name, emoji, lane_color, win_weight, gold_multiplier, gem_multiplier, display_order
) VALUES
  ('hr_lightning', 'Şimşek', '⚡', '#FBBF24', 28, 2.50, 1.25, 1),
  ('hr_storm', 'Fırtına', '🌪️', '#60A5FA', 22, 3.20, 1.35, 2),
  ('hr_shadow', 'Karadul', '🌑', '#A78BFA', 18, 4.00, 1.45, 3),
  ('hr_golden', 'Altıntoz', '✨', '#F59E0B', 14, 5.50, 1.55, 4),
  ('hr_night', 'Gece Ayazı', '🌙', '#818CF8', 10, 7.50, 1.70, 5),
  ('hr_legend', 'Efsane Tay', '👑', '#F472B6', 8, 10.00, 2.00, 6)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  emoji = EXCLUDED.emoji,
  lane_color = EXCLUDED.lane_color,
  win_weight = EXCLUDED.win_weight,
  gold_multiplier = EXCLUDED.gold_multiplier,
  gem_multiplier = EXCLUDED.gem_multiplier,
  display_order = EXCLUDED.display_order,
  is_active = EXCLUDED.is_active,
  updated_at = now();

CREATE OR REPLACE FUNCTION public.get_horse_race_board()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT jsonb_build_object(
    'success', true,
    'settings', (
      SELECT jsonb_build_object(
        'gold_min_bet', s.gold_min_bet,
        'gold_max_bet', s.gold_max_bet,
        'gem_min_bet', s.gem_min_bet,
        'gem_max_bet', s.gem_max_bet,
        'daily_bet_limit', s.daily_bet_limit
      )
      FROM public.horse_race_settings s
      WHERE s.id = 'default'
        AND s.is_active = TRUE
      LIMIT 1
    ),
    'horses', COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', h.id,
            'name', h.name,
            'emoji', h.emoji,
            'lane_color', h.lane_color,
            'win_weight', h.win_weight,
            'gold_multiplier', h.gold_multiplier,
            'gem_multiplier', h.gem_multiplier,
            'display_order', h.display_order
          )
          ORDER BY h.display_order
        )
        FROM public.horse_race_horses h
        WHERE h.is_active = TRUE
      ),
      '[]'::jsonb
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.place_horse_race_bet(
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
  v_picked RECORD;
  v_winner RECORD;
  v_balance_ok BOOLEAN := FALSE;
  v_multiplier NUMERIC(6,2);
  v_payout INTEGER := 0;
  v_won BOOLEAN := FALSE;
  v_today_count INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum gerekli.');
  END IF;

  IF p_currency_type NOT IN ('gold', 'gems') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz para birimi.');
  END IF;

  IF COALESCE(p_bet_amount, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bahis tutari gecersiz.');
  END IF;

  SELECT *
  INTO v_settings
  FROM public.horse_race_settings
  WHERE id = 'default'
    AND is_active = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'At yarisi su an kapali.');
  END IF;

  SELECT *
  INTO v_picked
  FROM public.horse_race_horses
  WHERE id = p_horse_id
    AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'At bulunamadi.');
  END IF;

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
    WHERE auth_id = v_user_id
      AND gems >= p_bet_amount
    RETURNING TRUE INTO v_balance_ok;

    v_multiplier := v_picked.gem_multiplier;
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
    WHERE auth_id = v_user_id
      AND gold >= p_bet_amount
    RETURNING TRUE INTO v_balance_ok;

    v_multiplier := v_picked.gold_multiplier;
  END IF;

  IF COALESCE(v_balance_ok, FALSE) = FALSE THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz bakiye.');
  END IF;

  IF v_settings.daily_bet_limit IS NOT NULL THEN
    SELECT COUNT(*)
    INTO v_today_count
    FROM public.player_horse_race_logs
    WHERE user_id = v_user_id
      AND created_at::date = (now() AT TIME ZONE 'utc')::date;

    IF v_today_count >= v_settings.daily_bet_limit THEN
      IF p_currency_type = 'gems' THEN
        UPDATE public.users SET gems = gems + p_bet_amount WHERE auth_id = v_user_id;
      ELSE
        UPDATE public.users SET gold = gold + p_bet_amount WHERE auth_id = v_user_id;
      END IF;
      RETURN jsonb_build_object('success', false, 'message', 'Gunluk at yarisi limiti doldu.');
    END IF;
  END IF;

  SELECT *
  INTO v_winner
  FROM public.horse_race_horses h
  WHERE h.is_active = TRUE
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(h.win_weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    IF p_currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + p_bet_amount WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + p_bet_amount WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Yaris atlari tanimli degil.');
  END IF;

  v_won := v_winner.id = v_picked.id;

  IF v_won THEN
    v_payout := GREATEST(1, FLOOR(p_bet_amount * v_multiplier)::INTEGER);

    IF p_currency_type = 'gems' THEN
      UPDATE public.users
      SET gems = gems + v_payout
      WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users
      SET gold = gold + v_payout
      WHERE auth_id = v_user_id;
    END IF;
  END IF;

  INSERT INTO public.player_horse_race_logs (
    user_id,
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
    v_user_id,
    v_picked.id,
    v_picked.id,
    v_winner.id,
    p_currency_type,
    p_bet_amount,
    v_multiplier,
    v_won,
    v_payout,
    jsonb_build_object(
      'picked_name', v_picked.name,
      'winner_name', v_winner.name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN v_won THEN 'Kazandin!' ELSE 'Kaybettin.' END,
    'won', v_won,
    'currency_type', p_currency_type,
    'bet_amount', p_bet_amount,
    'multiplier', v_multiplier,
    'payout_amount', v_payout,
    'picked_horse', jsonb_build_object(
      'id', v_picked.id,
      'name', v_picked.name,
      'emoji', v_picked.emoji,
      'lane_color', v_picked.lane_color
    ),
    'winner_horse', jsonb_build_object(
      'id', v_winner.id,
      'name', v_winner.name,
      'emoji', v_winner.emoji,
      'lane_color', v_winner.lane_color
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_horse_race_board() TO authenticated;
GRANT EXECUTE ON FUNCTION public.place_horse_race_bet(TEXT, TEXT, INTEGER) TO authenticated;

COMMIT;
