-- Kingdom treasury, king gifts, market blessing on P2P, taxes, chat announcements.

BEGIN;

-- ── Treasury ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.kingdom_treasury (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  gold_balance BIGINT NOT NULL DEFAULT 0 CHECK (gold_balance >= 0),
  gems_balance NUMERIC NOT NULL DEFAULT 0 CHECK (gems_balance >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.kingdom_treasury (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.kingdom_treasury_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind TEXT NOT NULL CHECK (kind IN (
    'tax_market', 'tax_shop', 'king_gift', 'system_adjust'
  )),
  currency TEXT NOT NULL CHECK (currency IN ('gold', 'gems')),
  amount NUMERIC NOT NULL,
  balance_after NUMERIC NOT NULL,
  actor_auth_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  target_auth_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reference_type TEXT,
  reference_id TEXT,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kingdom_treasury_ledger_created
  ON public.kingdom_treasury_ledger (created_at DESC);

CREATE TABLE IF NOT EXISTS public.kingdom_king_gifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  king_auth_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_auth_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  currency TEXT NOT NULL CHECK (currency IN ('gold', 'gems')),
  amount BIGINT NOT NULL CHECK (amount > 0 AND amount <= 1000000),
  gift_week DATE NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS kingdom_king_gifts_recipient_week_uidx
  ON public.kingdom_king_gifts (recipient_auth_id, gift_week);

CREATE INDEX IF NOT EXISTS kingdom_king_gifts_created_idx
  ON public.kingdom_king_gifts (created_at DESC);

CREATE TABLE IF NOT EXISTS public.live_ticker_manual_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  message TEXT NOT NULL,
  actor_auth_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reference_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '48 hours'
);

CREATE INDEX IF NOT EXISTS live_ticker_manual_events_created_idx
  ON public.live_ticker_manual_events (created_at DESC);

ALTER TABLE public.live_ticker_manual_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS live_ticker_manual_events_select ON public.live_ticker_manual_events;
CREATE POLICY live_ticker_manual_events_select
  ON public.live_ticker_manual_events FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION public._push_live_ticker_manual_event(
  p_event_type TEXT,
  p_message TEXT,
  p_actor_auth_id UUID DEFAULT NULL,
  p_reference_id TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.live_ticker_manual_events (
    event_type, message, actor_auth_id, reference_id
  ) VALUES (
    p_event_type,
    left(btrim(COALESCE(p_message, '')), 280),
    p_actor_auth_id,
    p_reference_id
  );
END;
$$;

ALTER TABLE public.kingdom_treasury ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kingdom_treasury_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kingdom_king_gifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kingdom_treasury_select ON public.kingdom_treasury;
CREATE POLICY kingdom_treasury_select
  ON public.kingdom_treasury FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS kingdom_treasury_ledger_select ON public.kingdom_treasury_ledger;
CREATE POLICY kingdom_treasury_ledger_select
  ON public.kingdom_treasury_ledger FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS kingdom_king_gifts_select ON public.kingdom_king_gifts;
CREATE POLICY kingdom_king_gifts_select
  ON public.kingdom_king_gifts FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION public._kingdom_gift_week(p_now TIMESTAMPTZ DEFAULT now())
RETURNS date
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT date_trunc('week', timezone('Europe/Istanbul', p_now))::date;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_treasury_credit(
  p_currency TEXT,
  p_amount NUMERIC,
  p_kind TEXT,
  p_actor_auth_id UUID DEFAULT NULL,
  p_target_auth_id UUID DEFAULT NULL,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id TEXT DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_amt NUMERIC := GREATEST(COALESCE(p_amount, 0), 0);
  v_after NUMERIC;
BEGIN
  IF v_amt <= 0 THEN
    RETURN;
  END IF;

  IF lower(p_currency) = 'gems' THEN
    UPDATE public.kingdom_treasury
    SET gems_balance = gems_balance + v_amt, updated_at = now()
    WHERE id = 1
    RETURNING gems_balance INTO v_after;
  ELSE
    UPDATE public.kingdom_treasury
    SET gold_balance = gold_balance + v_amt::bigint, updated_at = now()
    WHERE id = 1
    RETURNING gold_balance::numeric INTO v_after;
  END IF;

  INSERT INTO public.kingdom_treasury_ledger (
    kind, currency, amount, balance_after, actor_auth_id, target_auth_id,
    reference_type, reference_id, note
  ) VALUES (
    p_kind, lower(p_currency), v_amt, v_after, p_actor_auth_id, p_target_auth_id,
    p_reference_type, p_reference_id, NULLIF(left(btrim(COALESCE(p_note, '')), 300), '')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_treasury_debit(
  p_currency TEXT,
  p_amount NUMERIC,
  p_kind TEXT,
  p_actor_auth_id UUID,
  p_target_auth_id UUID DEFAULT NULL,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id TEXT DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_amt NUMERIC := GREATEST(COALESCE(p_amount, 0), 0);
  v_after NUMERIC;
  v_updated INT;
BEGIN
  IF v_amt <= 0 THEN
    RETURN false;
  END IF;

  IF lower(p_currency) = 'gems' THEN
    UPDATE public.kingdom_treasury
    SET gems_balance = gems_balance - v_amt, updated_at = now()
    WHERE id = 1 AND gems_balance >= v_amt;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated = 0 THEN RETURN false; END IF;
    SELECT gems_balance INTO v_after FROM public.kingdom_treasury WHERE id = 1;
  ELSE
    UPDATE public.kingdom_treasury
    SET gold_balance = gold_balance - v_amt::bigint, updated_at = now()
    WHERE id = 1 AND gold_balance >= v_amt::bigint;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated = 0 THEN RETURN false; END IF;
    SELECT gold_balance::numeric INTO v_after FROM public.kingdom_treasury WHERE id = 1;
  END IF;

  INSERT INTO public.kingdom_treasury_ledger (
    kind, currency, amount, balance_after, actor_auth_id, target_auth_id,
    reference_type, reference_id, note
  ) VALUES (
    p_kind, lower(p_currency), -v_amt, v_after, p_actor_auth_id, p_target_auth_id,
    p_reference_type, p_reference_id, NULLIF(left(btrim(COALESCE(p_note, '')), 300), '')
  );

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public._post_global_announcement_chat(
  p_sender_auth_id UUID,
  p_content TEXT,
  p_kind TEXT DEFAULT 'announcement',
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user RECORD;
  v_id UUID;
  v_body TEXT := left(btrim(COALESCE(p_content, '')), 200);
BEGIN
  IF p_sender_auth_id IS NULL OR v_body = '' THEN
    RETURN NULL;
  END IF;

  SELECT u.id, COALESCE(u.display_name, u.username, 'Sistem') AS sender_name
  INTO v_user
  FROM public.users u
  WHERE u.auth_id = p_sender_auth_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.chat_messages (
    channel, sender_user_id, sender_name, content, is_system, metadata
  ) VALUES (
    'global',
    v_user.id,
    v_user.sender_name,
    v_body,
    true,
    COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object('kind', p_kind)
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_kingdom_treasury_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_row public.kingdom_treasury%ROWTYPE;
  v_is_king BOOLEAN := false;
BEGIN
  SELECT * INTO v_row FROM public.kingdom_treasury WHERE id = 1;
  IF v_actor IS NOT NULL THEN
    v_is_king := public.is_current_king(v_actor);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'gold_balance', COALESCE(v_row.gold_balance, 0),
    'gems_balance', COALESCE(v_row.gems_balance, 0),
    'max_gift_amount', 1000000,
    'is_king', v_is_king,
    'recent_gifts', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', g.id,
          'king_username', ku.username,
          'recipient_username', ru.username,
          'currency', g.currency,
          'amount', g.amount,
          'created_at', g.created_at
        ) AS row
        FROM public.kingdom_king_gifts g
        JOIN public.users ku ON ku.auth_id = g.king_auth_id
        JOIN public.users ru ON ru.auth_id = g.recipient_auth_id
        ORDER BY g.created_at DESC
        LIMIT 12
      ) sub
    ), '[]'::jsonb),
    'recent_ledger', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'kind', l.kind,
          'currency', l.currency,
          'amount', l.amount,
          'created_at', l.created_at,
          'note', l.note
        ) AS row
        FROM public.kingdom_treasury_ledger l
        ORDER BY l.created_at DESC
        LIMIT 8
      ) sub2
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.king_gift_to_player(
  p_recipient_username TEXT,
  p_currency TEXT,
  p_amount BIGINT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_king UUID := auth.uid();
  v_king_username TEXT;
  v_recipient RECORD;
  v_amt BIGINT := COALESCE(p_amount, 0);
  v_cur TEXT := lower(btrim(COALESCE(p_currency, 'gold')));
  v_week date := public._kingdom_gift_week();
  v_gift_id UUID;
  v_chat TEXT;
BEGIN
  IF v_king IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF NOT public.is_current_king(v_king) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yalnızca krallık lideri hediye verebilir.');
  END IF;

  IF v_cur NOT IN ('gold', 'gems') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz para birimi.');
  END IF;

  IF v_amt < 1 OR v_amt > 1000000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hediye 1–1.000.000 arası olmalı.');
  END IF;

  SELECT u.auth_id, u.username, u.display_name
  INTO v_recipient
  FROM public.users u
  WHERE lower(u.username) = lower(btrim(COALESCE(p_recipient_username, '')))
  LIMIT 1;

  IF v_recipient.auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  IF v_recipient.auth_id = v_king THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize hediye veremezsiniz.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.kingdom_king_gifts g
    WHERE g.recipient_auth_id = v_recipient.auth_id
      AND g.gift_week = v_week
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',
      'Bu oyuncu bu hafta zaten kral hediyesi aldı.'
    );
  END IF;

  IF NOT public._kingdom_treasury_debit(
    v_cur, v_amt, 'king_gift', v_king, v_recipient.auth_id,
    'king_gift', NULL, p_note
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Krallık kasasında yeterli bakiye yok.');
  END IF;

  IF v_cur = 'gems' THEN
    UPDATE public.users SET gems = COALESCE(gems, 0) + v_amt WHERE auth_id = v_recipient.auth_id;
  ELSE
    UPDATE public.users SET gold = COALESCE(gold, 0) + v_amt::int WHERE auth_id = v_recipient.auth_id;
  END IF;

  INSERT INTO public.kingdom_king_gifts (
    king_auth_id, recipient_auth_id, currency, amount, gift_week, note
  ) VALUES (
    v_king, v_recipient.auth_id, v_cur, v_amt, v_week,
    NULLIF(left(btrim(COALESCE(p_note, '')), 300), '')
  )
  RETURNING id INTO v_gift_id;

  SELECT u.username INTO v_king_username FROM public.users u WHERE u.auth_id = v_king;

  v_chat := format(
    '👑 Kral @%s → @%s hediye: +%s %s',
    COALESCE(v_king_username, 'kral'),
    v_recipient.username,
    v_amt,
    CASE WHEN v_cur = 'gems' THEN '💎' ELSE '🪙' END
  );

  PERFORM public._post_global_announcement_chat(
    v_king,
    left(v_chat, 200),
    'king_gift',
    jsonb_build_object(
      'gift_id', v_gift_id,
      'recipient_auth_id', v_recipient.auth_id,
      'currency', v_cur,
      'amount', v_amt
    )
  );

  PERFORM public._push_live_ticker_manual_event(
    'king_gift',
    v_chat,
    v_king,
    v_gift_id::text
  );

  PERFORM public._notify_player_inbox(
    v_recipient.auth_id,
    'king_gift',
    'Krallık hediyesi',
    format('Kraldan +%s %s aldınız.', v_amt, CASE WHEN v_cur = 'gems' THEN 'elmas' ELSE 'altın' END),
    jsonb_build_object('amount', v_amt, 'currency', v_cur)
  );

  RETURN jsonb_build_object(
    'success', true,
    'gift_id', v_gift_id,
    'amount', v_amt,
    'currency', v_cur,
    'recipient_username', v_recipient.username
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_king_powers_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_is_king boolean := false;
  v_active record;
  v_used_today boolean := false;
  v_day date := public._kingdom_blessing_day();
  v_treasury public.kingdom_treasury%ROWTYPE;
BEGIN
  IF v_user IS NOT NULL THEN
    v_is_king := public.is_current_king(v_user);
  END IF;

  SELECT * INTO v_treasury FROM public.kingdom_treasury WHERE id = 1;

  SELECT
    b.gold_discount_pct,
    b.gem_discount_pct,
    b.started_at,
    b.expires_at,
    u.username AS activated_by_username,
    g.name AS activated_by_guild_name
  INTO v_active
  FROM public.kingdom_market_blessings b
  LEFT JOIN public.users u ON u.auth_id = b.activated_by
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE b.expires_at > now()
  ORDER BY b.started_at DESC
  LIMIT 1;

  SELECT EXISTS (
    SELECT 1 FROM public.kingdom_market_blessings b WHERE b.blessing_day = v_day
  ) INTO v_used_today;

  RETURN jsonb_build_object(
    'is_king', v_is_king,
    'blessing_active', v_active.expires_at IS NOT NULL,
    'blessing_expires_at', v_active.expires_at,
    'blessing_started_at', v_active.started_at,
    'active_gold_pct', COALESCE(v_active.gold_discount_pct, 0),
    'active_gem_pct', COALESCE(v_active.gem_discount_pct, 0),
    'blessing_used_today', v_used_today,
    'blessing_activated_by_username', v_active.activated_by_username,
    'blessing_activated_by_guild_name', v_active.activated_by_guild_name,
    'max_gold_pct', 20,
    'max_gem_pct', 10,
    'duration_minutes', 30,
    'treasury_gold', COALESCE(v_treasury.gold_balance, 0),
    'treasury_gems', COALESCE(v_treasury.gems_balance, 0),
    'max_gift_amount', 1000000
  );
END;
$$;

-- ── P2P market: blessing + tax to treasury ──────────────────────────────────

CREATE OR REPLACE FUNCTION public.purchase_market_listing_rl_inner(
  p_order_id UUID,
  p_quantity INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_buyer_id UUID := auth.uid();
  v_order RECORD;
  v_buy_qty INT;
  v_unit_price INT;
  v_total INT;
  v_fee INT;
  v_seller_credit INT;
  v_buyer_gold INT;
  v_buyer_gems NUMERIC;
  v_blessing RECORD;
  v_discount_pct NUMERIC := 0;
  v_cur TEXT;
BEGIN
  IF v_buyer_id IS NULL THEN
    RAISE EXCEPTION 'Giris yapmalisiniz';
  END IF;

  SELECT * INTO v_order
  FROM public.market_orders
  WHERE order_id = p_order_id
    AND status = 'open'
    AND side = 'sell'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ilan bulunamadi veya satildi';
  END IF;

  IF v_order.seller_id = v_buyer_id THEN
    RAISE EXCEPTION 'Kendi ilaninizi satin alamazsiniz';
  END IF;

  IF v_order.is_stackable THEN
    v_buy_qty := GREATEST(1, COALESCE(p_quantity, 1));
    IF v_buy_qty > v_order.quantity THEN
      RAISE EXCEPTION 'Ilanda yeterli adet yok (max %)', v_order.quantity;
    END IF;
  ELSE
    v_buy_qty := 1;
  END IF;

  IF NOT public.market_can_add_items(
    v_buyer_id, v_order.item_id, v_buy_qty, v_order.enhancement_level
  ) THEN
    RAISE EXCEPTION 'Envanter dolu veya esya eklenemiyor';
  END IF;

  v_cur := lower(COALESCE(v_order.currency, 'gold'));
  v_unit_price := v_order.price;

  SELECT * INTO v_blessing FROM public._active_kingdom_market_blessing() LIMIT 1;
  IF v_blessing.expires_at IS NOT NULL THEN
    IF v_cur = 'gold' AND COALESCE(v_blessing.gold_discount_pct, 0) > 0 THEN
      v_discount_pct := v_blessing.gold_discount_pct;
    ELSIF v_cur = 'gems' AND COALESCE(v_blessing.gem_discount_pct, 0) > 0 THEN
      v_discount_pct := v_blessing.gem_discount_pct;
    END IF;
    v_unit_price := GREATEST(
      floor(v_unit_price * (1 - v_discount_pct / 100.0))::int,
      0
    );
  END IF;

  v_total := v_unit_price * v_buy_qty;
  v_fee := FLOOR(v_total * 0.05);
  v_seller_credit := v_total - v_fee;

  IF v_cur = 'gems' THEN
    SELECT COALESCE(gems, 0) INTO v_buyer_gems
    FROM public.users WHERE auth_id = v_buyer_id FOR UPDATE;
    IF v_buyer_gems IS NULL THEN RAISE EXCEPTION 'Oyuncu bulunamadi'; END IF;
    IF v_buyer_gems < v_total THEN RAISE EXCEPTION 'Yeterli elmas yok'; END IF;
    UPDATE public.users SET gems = gems - v_total WHERE auth_id = v_buyer_id;
    UPDATE public.users SET gems = COALESCE(gems, 0) + v_seller_credit WHERE auth_id = v_order.seller_id;
    PERFORM public._kingdom_treasury_credit('gems', v_fee, 'tax_market', v_buyer_id, v_order.seller_id, 'market_order', p_order_id::text);
  ELSE
    SELECT COALESCE(gold, 0) INTO v_buyer_gold
    FROM public.users WHERE auth_id = v_buyer_id FOR UPDATE;
    IF v_buyer_gold IS NULL THEN RAISE EXCEPTION 'Oyuncu bulunamadi'; END IF;
    IF v_buyer_gold < v_total THEN RAISE EXCEPTION 'Yeterli altin yok'; END IF;
    UPDATE public.users SET gold = gold - v_total WHERE auth_id = v_buyer_id;
    UPDATE public.users SET gold = COALESCE(gold, 0) + v_seller_credit WHERE auth_id = v_order.seller_id;
    PERFORM public._kingdom_treasury_credit('gold', v_fee, 'tax_market', v_buyer_id, v_order.seller_id, 'market_order', p_order_id::text);
  END IF;

  IF NOT public.market_give_items(
    v_buyer_id, v_order.item_id, v_buy_qty, v_order.enhancement_level
  ) THEN
    RAISE EXCEPTION 'Esya envantere eklenemedi';
  END IF;

  IF v_buy_qty >= v_order.quantity THEN
    UPDATE public.market_orders
    SET status = 'filled', quantity = 0, fee = v_fee, filled_at = now(), updated_at = now()
    WHERE order_id = p_order_id;
  ELSE
    UPDATE public.market_orders
    SET quantity = quantity - v_buy_qty, fee = v_fee, updated_at = now()
    WHERE order_id = p_order_id;
  END IF;

  INSERT INTO public.market_history (
    order_id, buyer_id, seller_id, item_id, item_name, quantity, unit_price, total_price, fee
  ) VALUES (
    p_order_id, v_buyer_id, v_order.seller_id, v_order.item_id, v_order.item_name,
    v_buy_qty, v_unit_price, v_total, v_fee
  );

  RETURN jsonb_build_object(
    'success', true,
    'quantity', v_buy_qty,
    'total', v_total,
    'unit_price', v_unit_price,
    'fee', v_fee,
    'seller_credit', v_seller_credit,
    'discount_pct', v_discount_pct,
    'currency', v_cur
  );
END;
$$;

-- Staff broadcast → global chat
CREATE OR REPLACE FUNCTION public.staff_liveops_create_broadcast(
  p_message TEXT,
  p_max_passes INT DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_id UUID;
  v_passes INT := GREATEST(1, LEAST(COALESCE(p_max_passes, 10), 500));
  v_body TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.broadcast');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF btrim(COALESCE(p_message, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duyuru metni gerekli.');
  END IF;

  UPDATE public.staff_broadcasts SET is_active = false WHERE is_active = true;

  INSERT INTO public.staff_broadcasts (
    message, created_by, is_active, expires_at, max_passes, passes_completed
  )
  VALUES (
    left(btrim(p_message), 280),
    v_actor,
    true,
    now() + interval '7 days',
    v_passes,
    0
  )
  RETURNING id INTO v_id;

  v_body := '📣 ' || left(btrim(p_message), 180);
  PERFORM public._post_global_announcement_chat(
    v_actor,
    v_body,
    'staff_broadcast',
    jsonb_build_object('broadcast_id', v_id)
  );
  PERFORM public._push_live_ticker_manual_event(
    'staff_broadcast',
    v_body,
    v_actor,
    v_id::text
  );

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.broadcast', 'create_broadcast', 'staff_broadcast', v_id::text,
    jsonb_build_object('message', p_message, 'max_passes', v_passes),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object(
    'success', true,
    'broadcast_id', v_id,
    'max_passes', v_passes
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_kingdom_treasury_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.king_gift_to_player(text, text, bigint, text) TO authenticated;

COMMIT;
