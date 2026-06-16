-- ==================================================================================
-- Player-to-player market: escrow listings, purchase, cancel, price update, 5% fee
-- ==================================================================================

-- ── Table: market_orders ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.market_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL DEFAULT gen_random_uuid(),
  seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  inventory_row_id UUID,
  item_id TEXT NOT NULL REFERENCES public.items(id),
  item_name TEXT NOT NULL DEFAULT 'Bilinmeyen Esya',
  item_type TEXT NOT NULL DEFAULT '',
  rarity TEXT NOT NULL DEFAULT 'common',
  is_stackable BOOLEAN NOT NULL DEFAULT false,
  max_stack INTEGER NOT NULL DEFAULT 1,
  enhancement_level INTEGER NOT NULL DEFAULT 0,
  side TEXT NOT NULL DEFAULT 'sell' CHECK (side IN ('buy', 'sell')),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  price INTEGER NOT NULL CHECK (price > 0),
  fee INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'filled', 'cancelled', 'expired')),
  currency TEXT NOT NULL DEFAULT 'gold',
  region TEXT NOT NULL DEFAULT 'central',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  filled_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);

ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS order_id UUID DEFAULT gen_random_uuid();
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS player_id UUID;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS inventory_row_id UUID;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS item_id TEXT REFERENCES public.items(id);
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS item_name TEXT DEFAULT 'Bilinmeyen Esya';
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS item_type TEXT DEFAULT '';
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS rarity TEXT DEFAULT 'common';
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS is_stackable BOOLEAN DEFAULT false;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS max_stack INTEGER DEFAULT 1;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS enhancement_level INTEGER DEFAULT 0;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS side TEXT DEFAULT 'sell';
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS price INTEGER DEFAULT 1;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS fee INTEGER DEFAULT 0;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'open';
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'gold';
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS region TEXT DEFAULT 'central';
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS filled_at TIMESTAMPTZ;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Backfill legacy market_orders (player_id → seller_id, id → order_id, timestamps)
UPDATE public.market_orders
SET order_id = id
WHERE order_id IS NULL AND id IS NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'market_orders' AND column_name = 'player_id'
  ) THEN
    UPDATE public.market_orders
    SET seller_id = player_id
    WHERE seller_id IS NULL AND player_id IS NOT NULL;
  END IF;
END $$;

UPDATE public.market_orders
SET created_at = COALESCE(updated_at, now())
WHERE created_at IS NULL;

UPDATE public.market_orders
SET updated_at = COALESCE(created_at, now())
WHERE updated_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_market_orders_order_id ON public.market_orders(order_id);
CREATE INDEX IF NOT EXISTS idx_market_orders_open_sell ON public.market_orders(status, side, item_id, price)
  WHERE status = 'open' AND side = 'sell';
CREATE INDEX IF NOT EXISTS idx_market_orders_seller ON public.market_orders(seller_id, status);

-- ── Table: market_history (optional audit) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.market_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL,
  buyer_id UUID NOT NULL REFERENCES auth.users(id),
  seller_id UUID NOT NULL REFERENCES auth.users(id),
  item_id TEXT NOT NULL,
  item_name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price INTEGER NOT NULL,
  total_price INTEGER NOT NULL,
  fee INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS order_id UUID;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS buyer_id UUID;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS seller_id UUID;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS item_id TEXT;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS item_name TEXT;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS unit_price INTEGER DEFAULT 0;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS total_price INTEGER DEFAULT 0;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS fee INTEGER DEFAULT 0;
ALTER TABLE public.market_history ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

UPDATE public.market_history SET created_at = now() WHERE created_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_market_history_buyer ON public.market_history(buyer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_market_history_seller ON public.market_history(seller_id, created_at DESC);

-- ── RLS ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.market_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS market_orders_select_open ON public.market_orders;
CREATE POLICY market_orders_select_open ON public.market_orders
  FOR SELECT TO authenticated
  USING (
    status = 'open'
    OR seller_id = auth.uid()
    OR (
      seller_id IS NULL
      AND player_id IS NOT NULL
      AND player_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS market_history_select_own ON public.market_history;
CREATE POLICY market_history_select_own ON public.market_history
  FOR SELECT TO authenticated
  USING (buyer_id = auth.uid() OR seller_id = auth.uid());

-- ── Helpers ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.market_count_free_slots(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_occupied INTEGER;
BEGIN
  SELECT COUNT(DISTINCT slot_position)
  INTO v_occupied
  FROM public.inventory
  WHERE user_id = p_user_id
    AND is_equipped = false
    AND slot_position IS NOT NULL
    AND slot_position BETWEEN 0 AND 19;

  RETURN GREATEST(0, 20 - COALESCE(v_occupied, 0));
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION public.market_can_add_items(
  p_user_id UUID,
  p_item_id TEXT,
  p_quantity INTEGER,
  p_enhancement_level INTEGER DEFAULT 0
) RETURNS BOOLEAN AS $$
DECLARE
  v_is_stackable BOOLEAN;
  v_max_stack INTEGER;
  v_remaining INTEGER;
  v_row RECORD;
  v_space INTEGER;
  v_free_slots INTEGER;
  v_needed_slots INTEGER;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN false;
  END IF;

  SELECT
    COALESCE(i.is_stackable, false),
    GREATEST(1, COALESCE(i.max_stack, inv.max_stack, 999))
  INTO v_is_stackable, v_max_stack
  FROM public.items i
  LEFT JOIN public.inventory inv ON inv.item_id = i.id AND inv.user_id = p_user_id
  WHERE i.id = p_item_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT v_is_stackable THEN
    IF p_quantity <> 1 THEN
      RETURN false;
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = p_user_id AND item_id = p_item_id AND is_equipped = false
    ) THEN
      RETURN false;
    END IF;
    RETURN public.market_count_free_slots(p_user_id) >= 1;
  END IF;

  v_remaining := p_quantity;

  FOR v_row IN
    SELECT quantity
    FROM public.inventory
    WHERE user_id = p_user_id
      AND item_id = p_item_id
      AND is_equipped = false
      AND COALESCE(enhancement_level, 0) = p_enhancement_level
      AND quantity < v_max_stack
    ORDER BY obtained_at ASC NULLS LAST
  LOOP
    EXIT WHEN v_remaining <= 0;
    v_space := v_max_stack - v_row.quantity;
    v_remaining := v_remaining - LEAST(v_space, v_remaining);
  END LOOP;

  IF v_remaining <= 0 THEN
    RETURN true;
  END IF;

  v_free_slots := public.market_count_free_slots(p_user_id);
  v_needed_slots := CEIL(v_remaining::NUMERIC / v_max_stack::NUMERIC)::INTEGER;
  RETURN v_free_slots >= v_needed_slots;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.market_give_items(
  p_user_id UUID,
  p_item_id TEXT,
  p_quantity INTEGER,
  p_enhancement_level INTEGER DEFAULT 0
) RETURNS BOOLEAN AS $$
DECLARE
  v_is_stackable BOOLEAN;
  v_max_stack INTEGER;
  v_remaining INTEGER;
  v_row RECORD;
  v_space INTEGER;
  v_add INTEGER;
  v_free_slot INTEGER;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN true;
  END IF;

  SELECT
    COALESCE(is_stackable, false),
    GREATEST(1, COALESCE(max_stack, 999))
  INTO v_is_stackable, v_max_stack
  FROM public.items
  WHERE id = p_item_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT v_is_stackable THEN
    SELECT s.slot INTO v_free_slot
    FROM generate_series(0, 19) s(slot)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = p_user_id AND slot_position = s.slot AND is_equipped = false
    )
    ORDER BY s.slot
    LIMIT 1;

    IF v_free_slot IS NULL THEN
      RETURN false;
    END IF;

    INSERT INTO public.inventory (
      user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, obtained_at
    ) VALUES (
      p_user_id, p_item_id, 1, v_free_slot, false, p_enhancement_level,
      EXTRACT(EPOCH FROM now())::BIGINT
    );
    RETURN true;
  END IF;

  v_remaining := p_quantity;

  FOR v_row IN
    SELECT row_id, quantity
    FROM public.inventory
    WHERE user_id = p_user_id
      AND item_id = p_item_id
      AND is_equipped = false
      AND COALESCE(enhancement_level, 0) = p_enhancement_level
      AND quantity < v_max_stack
    ORDER BY obtained_at ASC NULLS LAST
    FOR UPDATE
  LOOP
    EXIT WHEN v_remaining <= 0;
    v_space := v_max_stack - v_row.quantity;
    v_add := LEAST(v_space, v_remaining);
    UPDATE public.inventory SET quantity = quantity + v_add, updated_at = now()
    WHERE row_id = v_row.row_id;
    v_remaining := v_remaining - v_add;
  END LOOP;

  WHILE v_remaining > 0 LOOP
    SELECT s.slot INTO v_free_slot
    FROM generate_series(0, 19) s(slot)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = p_user_id AND slot_position = s.slot AND is_equipped = false
    )
    ORDER BY s.slot
    LIMIT 1;

    IF v_free_slot IS NULL THEN
      RETURN false;
    END IF;

    v_add := LEAST(v_max_stack, v_remaining);
    INSERT INTO public.inventory (
      user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, obtained_at
    ) VALUES (
      p_user_id, p_item_id, v_add, v_free_slot, false, p_enhancement_level,
      EXTRACT(EPOCH FROM now())::BIGINT
    );
    v_remaining := v_remaining - v_add;
  END LOOP;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── place_sell_order ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.place_sell_order(
  p_item_row_id UUID,
  p_quantity INT,
  p_price INT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_row RECORD;
  v_item RECORD;
  v_qty INT;
  v_order_id UUID;
  v_total INT;
  v_seller_receives INT;
  v_fee INT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Giris yapmalisiniz';
  END IF;

  IF p_price IS NULL OR p_price <= 0 THEN
    RAISE EXCEPTION 'Gecerli bir fiyat girin';
  END IF;

  SELECT inv.*,
         i.name AS catalog_name,
         COALESCE(i.type::TEXT, '') AS catalog_type,
         COALESCE(i.rarity::TEXT, 'common') AS catalog_rarity,
         COALESCE(i.is_market_tradeable, true) AS catalog_market_tradeable,
         COALESCE(i.is_han_only, false) AS catalog_han_only,
         COALESCE(i.is_stackable, inv.is_stackable, false) AS catalog_stackable,
         GREATEST(1, COALESCE(i.max_stack, inv.max_stack, 999)) AS catalog_max_stack
  INTO v_row
  FROM public.inventory inv
  JOIN public.items i ON i.id = inv.item_id
  WHERE inv.row_id = p_item_row_id
    AND inv.user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Esya bulunamadi veya size ait degil';
  END IF;

  IF COALESCE(v_row.is_equipped, false) THEN
    RAISE EXCEPTION 'Kuşanili esya pazara konulamaz';
  END IF;

  IF COALESCE(v_row.is_tradeable, true) = false THEN
    RAISE EXCEPTION 'Bu esya takas edilemez';
  END IF;

  IF v_row.catalog_market_tradeable = false OR v_row.catalog_han_only = true THEN
    RAISE EXCEPTION 'Bu esya pazarda satilamaz';
  END IF;

  IF v_row.catalog_stackable THEN
    v_qty := GREATEST(1, COALESCE(p_quantity, 1));
    IF v_qty > v_row.quantity THEN
      RAISE EXCEPTION 'Yeterli adet yok (max %)', v_row.quantity;
    END IF;
  ELSE
    v_qty := 1;
    IF v_row.quantity <> 1 THEN
      RAISE EXCEPTION 'Gecersiz envanter satiri';
    END IF;
  END IF;

  v_total := p_price * v_qty;
  v_fee := FLOOR(v_total * 0.05);
  v_seller_receives := v_total - v_fee;
  v_order_id := gen_random_uuid();

  IF v_row.catalog_stackable AND v_qty < v_row.quantity THEN
    UPDATE public.inventory
    SET quantity = quantity - v_qty, updated_at = now()
    WHERE row_id = p_item_row_id AND user_id = v_user_id;
  ELSE
    DELETE FROM public.inventory
    WHERE row_id = p_item_row_id AND user_id = v_user_id;
  END IF;

  INSERT INTO public.market_orders (
    order_id, seller_id, inventory_row_id, item_id, item_name, item_type, rarity,
    is_stackable, max_stack, enhancement_level, side, quantity, price, status, currency
  ) VALUES (
    v_order_id, v_user_id, p_item_row_id, v_row.item_id,
    COALESCE(v_row.catalog_name, 'Bilinmeyen Esya'),
    COALESCE(v_row.catalog_type::TEXT, ''),
    COALESCE(v_row.catalog_rarity::TEXT, 'common'),
    v_row.catalog_stackable, v_row.catalog_max_stack,
    COALESCE(v_row.enhancement_level, 0),
    'sell', v_qty, p_price, 'open', 'gold'
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'quantity', v_qty,
    'unit_price', p_price,
    'total', v_total,
    'fee', v_fee,
    'seller_receives', v_seller_receives
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.place_sell_order(UUID, INT, INT) TO authenticated;

-- ── market_list_item wrapper ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.market_list_item(
  p_item_row_id UUID,
  p_quantity INT,
  p_price INT
) RETURNS JSONB AS $$
BEGIN
  RETURN public.place_sell_order(p_item_row_id, p_quantity, p_price);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.market_list_item(UUID, INT, INT) TO authenticated;

-- ── cancel_sell_order ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_sell_order(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_order RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Giris yapmalisiniz';
  END IF;

  SELECT * INTO v_order
  FROM public.market_orders
  WHERE order_id = p_order_id
    AND seller_id = v_user_id
    AND status = 'open'
    AND side = 'sell'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ilan bulunamadi veya iptal edilemez';
  END IF;

  IF NOT public.market_give_items(
    v_user_id, v_order.item_id, v_order.quantity, v_order.enhancement_level
  ) THEN
    RAISE EXCEPTION 'Envanter dolu, ilan geri cekilemedi';
  END IF;

  UPDATE public.market_orders
  SET status = 'cancelled', updated_at = now()
  WHERE order_id = p_order_id;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.cancel_sell_order(UUID) TO authenticated;

-- ── update_market_listing_price ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_market_listing_price(
  p_order_id UUID,
  p_new_price INT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Giris yapmalisiniz';
  END IF;

  IF p_new_price IS NULL OR p_new_price <= 0 THEN
    RAISE EXCEPTION 'Gecerli bir fiyat girin';
  END IF;

  UPDATE public.market_orders
  SET price = p_new_price, updated_at = now()
  WHERE order_id = p_order_id
    AND seller_id = v_user_id
    AND status = 'open'
    AND side = 'sell';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ilan bulunamadi veya guncellenemez';
  END IF;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id, 'new_price', p_new_price);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_market_listing_price(UUID, INT) TO authenticated;

-- ── purchase_market_listing ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.purchase_market_listing(
  p_order_id UUID,
  p_quantity INT
) RETURNS JSONB AS $$
DECLARE
  v_buyer_id UUID := auth.uid();
  v_order RECORD;
  v_buy_qty INT;
  v_total INT;
  v_fee INT;
  v_seller_credit INT;
  v_buyer_gold INT;
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

  v_total := v_order.price * v_buy_qty;
  v_fee := FLOOR(v_total * 0.05);
  v_seller_credit := v_total - v_fee;

  SELECT COALESCE(gold, 0) INTO v_buyer_gold
  FROM public.users
  WHERE auth_id = v_buyer_id
  FOR UPDATE;

  IF v_buyer_gold IS NULL THEN
    RAISE EXCEPTION 'Oyuncu bulunamadi';
  END IF;

  IF v_buyer_gold < v_total THEN
    RAISE EXCEPTION 'Yeterli altin yok';
  END IF;

  UPDATE public.users
  SET gold = gold - v_total
  WHERE auth_id = v_buyer_id;

  UPDATE public.users
  SET gold = COALESCE(gold, 0) + v_seller_credit
  WHERE auth_id = v_order.seller_id;

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
    v_buy_qty, v_order.price, v_total, v_fee
  );

  RETURN jsonb_build_object(
    'success', true,
    'quantity', v_buy_qty,
    'total', v_total,
    'fee', v_fee,
    'seller_credit', v_seller_credit
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.purchase_market_listing(UUID, INT) TO authenticated;

GRANT EXECUTE ON FUNCTION public.market_can_add_items(UUID, TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.market_count_free_slots(UUID) TO authenticated;
