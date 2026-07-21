-- ============================================================================
-- BOT KONTROLÜ: rate-limit + in-app captcha
-- Kritik RPC'lere (zindan, arena, market) pencere bazlı sayaç.
-- Eşik aşımında 'captcha_required' hatası; basit toplama sorusu ile çözülür.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.rpc_rate_limits (
  user_id UUID NOT NULL,
  action TEXT NOT NULL,
  window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  call_count INT NOT NULL DEFAULT 0,
  captcha_required BOOLEAN NOT NULL DEFAULT false,
  captcha_a INT,
  captcha_b INT,
  captcha_expires_at TIMESTAMPTZ,
  PRIMARY KEY (user_id, action)
);

ALTER TABLE public.rpc_rate_limits ENABLE ROW LEVEL SECURITY;
-- Politika yok: sadece SECURITY DEFINER fonksiyonlar erişir.

-- ── Sayaç + eşik kontrolü ───────────────────────────────────────────────────
-- NULL döner = devam; JSONB döner = engellendi (captcha_required).
CREATE OR REPLACE FUNCTION public.enforce_rate_limit(
  p_action TEXT,
  p_max INT,
  p_window_seconds INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_row public.rpc_rate_limits%ROWTYPE;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN NULL; -- auth katmanı zaten engeller
  END IF;

  INSERT INTO public.rpc_rate_limits AS r (user_id, action, window_start, call_count)
  VALUES (v_me, p_action, now(), 0)
  ON CONFLICT (user_id, action) DO NOTHING;

  SELECT * INTO v_row
  FROM public.rpc_rate_limits
  WHERE user_id = v_me AND action = p_action
  FOR UPDATE;

  -- Captcha bekliyor mu?
  IF v_row.captcha_required THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'captcha_required',
      'code', 'captcha_required',
      'action', p_action
    );
  END IF;

  -- Pencere sıfırlama
  IF v_row.window_start + make_interval(secs => p_window_seconds) <= now() THEN
    UPDATE public.rpc_rate_limits
    SET window_start = now(), call_count = 1
    WHERE user_id = v_me AND action = p_action;
    RETURN NULL;
  END IF;

  IF v_row.call_count + 1 > p_max THEN
    UPDATE public.rpc_rate_limits
    SET captcha_required = true,
        captcha_a = 1 + floor(random() * 20)::INT,
        captcha_b = 1 + floor(random() * 20)::INT,
        captcha_expires_at = now() + interval '10 minutes'
    WHERE user_id = v_me AND action = p_action;
    RETURN jsonb_build_object(
      'success', false,
      'error', 'captcha_required',
      'code', 'captcha_required',
      'action', p_action
    );
  END IF;

  UPDATE public.rpc_rate_limits
  SET call_count = call_count + 1
  WHERE user_id = v_me AND action = p_action;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_rate_limit(TEXT, INT, INT) FROM PUBLIC, anon, authenticated;

-- ── Captcha sorusunu getir ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_captcha_challenge(p_action TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_row public.rpc_rate_limits%ROWTYPE;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_row
  FROM public.rpc_rate_limits
  WHERE user_id = v_me AND action = p_action
  FOR UPDATE;

  IF NOT FOUND OR NOT v_row.captcha_required THEN
    RETURN jsonb_build_object('success', false, 'error', 'Captcha gerekli değil');
  END IF;

  -- Süresi geçtiyse yeni soru üret
  IF v_row.captcha_expires_at IS NULL OR v_row.captcha_expires_at <= now() THEN
    UPDATE public.rpc_rate_limits
    SET captcha_a = 1 + floor(random() * 20)::INT,
        captcha_b = 1 + floor(random() * 20)::INT,
        captcha_expires_at = now() + interval '10 minutes'
    WHERE user_id = v_me AND action = p_action
    RETURNING * INTO v_row;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'question', v_row.captcha_a || ' + ' || v_row.captcha_b || ' = ?'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_captcha_challenge(TEXT) TO authenticated;

-- ── Captcha çöz ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.solve_captcha(p_action TEXT, p_answer INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_row public.rpc_rate_limits%ROWTYPE;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_row
  FROM public.rpc_rate_limits
  WHERE user_id = v_me AND action = p_action
  FOR UPDATE;

  IF NOT FOUND OR NOT v_row.captcha_required THEN
    RETURN jsonb_build_object('success', true, 'message', 'Captcha gerekli değil');
  END IF;

  IF v_row.captcha_expires_at IS NULL OR v_row.captcha_expires_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sorunun süresi doldu, yenisini iste');
  END IF;

  IF v_row.captcha_a + v_row.captcha_b != p_answer THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yanlış cevap');
  END IF;

  UPDATE public.rpc_rate_limits
  SET captcha_required = false,
      captcha_a = NULL,
      captcha_b = NULL,
      captcha_expires_at = NULL,
      window_start = now(),
      call_count = 0
  WHERE user_id = v_me AND action = p_action;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.solve_captcha(TEXT, INT) TO authenticated;

-- ── Kritik RPC'leri sarmala ─────────────────────────────────────────────────
-- attack_dungeon: 20 koşu / 5 dk
ALTER FUNCTION public.attack_dungeon(TEXT) RENAME TO attack_dungeon_rl_inner;
REVOKE ALL ON FUNCTION public.attack_dungeon_rl_inner(TEXT) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.attack_dungeon(p_dungeon_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gate JSONB;
BEGIN
  v_gate := public.enforce_rate_limit('dungeon', 20, 300);
  IF v_gate IS NOT NULL THEN RETURN v_gate; END IF;
  RETURN public.attack_dungeon_rl_inner(p_dungeon_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.attack_dungeon(TEXT) TO authenticated;

-- mekan_pvp_bet (arena): 15 maç / 5 dk
ALTER FUNCTION public.mekan_pvp_bet(UUID, UUID, BIGINT) RENAME TO mekan_pvp_bet_rl_inner;
REVOKE ALL ON FUNCTION public.mekan_pvp_bet_rl_inner(UUID, UUID, BIGINT) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.mekan_pvp_bet(
  p_defender_id UUID,
  p_mekan_id UUID,
  p_wager BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gate JSONB;
BEGIN
  v_gate := public.enforce_rate_limit('arena', 15, 300);
  IF v_gate IS NOT NULL THEN RETURN v_gate; END IF;
  RETURN public.mekan_pvp_bet_rl_inner(p_defender_id, p_mekan_id, p_wager);
END;
$$;

GRANT EXECUTE ON FUNCTION public.mekan_pvp_bet(UUID, UUID, BIGINT) TO authenticated;

-- purchase_market_listing (2 arg): 30 alım / 5 dk
ALTER FUNCTION public.purchase_market_listing(UUID, INTEGER) RENAME TO purchase_market_listing_rl_inner;
REVOKE ALL ON FUNCTION public.purchase_market_listing_rl_inner(UUID, INTEGER) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.purchase_market_listing(p_order_id UUID, p_quantity INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gate JSONB;
BEGIN
  v_gate := public.enforce_rate_limit('market', 30, 300);
  IF v_gate IS NOT NULL THEN
    RAISE EXCEPTION 'captcha_required';
  END IF;
  RETURN public.purchase_market_listing_rl_inner(p_order_id, p_quantity);
END;
$$;

GRANT EXECUTE ON FUNCTION public.purchase_market_listing(UUID, INTEGER) TO authenticated;

-- market_list_item: 30 listeleme / 5 dk
ALTER FUNCTION public.market_list_item(UUID, INTEGER, INTEGER) RENAME TO market_list_item_rl_inner;
REVOKE ALL ON FUNCTION public.market_list_item_rl_inner(UUID, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.market_list_item(
  p_item_row_id UUID,
  p_quantity INTEGER,
  p_price INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gate JSONB;
BEGIN
  v_gate := public.enforce_rate_limit('market', 30, 300);
  IF v_gate IS NOT NULL THEN
    RAISE EXCEPTION 'captcha_required';
  END IF;
  RETURN public.market_list_item_rl_inner(p_item_row_id, p_quantity, p_price);
END;
$$;

GRANT EXECUTE ON FUNCTION public.market_list_item(UUID, INTEGER, INTEGER) TO authenticated;
