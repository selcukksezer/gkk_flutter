-- Hotfix: legacy market_orders / market_history missing columns (created_at, seller_id, etc.)

-- ── market_orders: ensure columns ────────────────────────────────────────────────
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS order_id UUID DEFAULT gen_random_uuid();
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS seller_id UUID;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS player_id UUID;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS inventory_row_id UUID;
ALTER TABLE public.market_orders ADD COLUMN IF NOT EXISTS item_id TEXT;
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

-- Backfill legacy rows
UPDATE public.market_orders
SET order_id = id
WHERE order_id IS NULL AND id IS NOT NULL;

UPDATE public.market_orders
SET seller_id = player_id
WHERE seller_id IS NULL AND player_id IS NOT NULL;

UPDATE public.market_orders
SET created_at = COALESCE(updated_at, now())
WHERE created_at IS NULL;

UPDATE public.market_orders
SET updated_at = COALESCE(created_at, now())
WHERE updated_at IS NULL;

UPDATE public.market_orders
SET side = 'sell'
WHERE side IS NULL;

UPDATE public.market_orders
SET status = 'open'
WHERE status IS NULL;

-- ── market_history: ensure table + columns before indexes ──────────────────────
CREATE TABLE IF NOT EXISTS public.market_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL,
  buyer_id UUID NOT NULL,
  seller_id UUID NOT NULL,
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

UPDATE public.market_history
SET created_at = now()
WHERE created_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_market_history_buyer ON public.market_history(buyer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_market_history_seller ON public.market_history(seller_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_market_orders_order_id ON public.market_orders(order_id);
CREATE INDEX IF NOT EXISTS idx_market_orders_open_sell ON public.market_orders(status, side, item_id, price)
  WHERE status = 'open' AND side = 'sell';
CREATE INDEX IF NOT EXISTS idx_market_orders_seller ON public.market_orders(seller_id, status);
