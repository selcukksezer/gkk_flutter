-- ECO-4: User-approved economy implementation
-- PLAN_06 aligned: 600 gold/gem anchor, 8×3 gem + 4×3 gold ladder,
-- RTP via pool weights + price, IAP TL catalog, catalog fixes.

BEGIN;

-- ── 1) Gem → gold @ 600 (fixed) ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.exchange_gems_for_gold(p_gems INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_auth_id UUID;
  v_gold BIGINT;
  v_gems INTEGER;
  v_current_gems NUMERIC;
  v_current_gold BIGINT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_gems := p_gems;
  v_gold := CASE v_gems
    WHEN 10 THEN 6000
    WHEN 25 THEN 15000
    WHEN 75 THEN 45000
    WHEN 200 THEN 120000
    ELSE NULL
  END;

  IF v_gold IS NULL OR v_gems IS NULL OR v_gems <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid package');
  END IF;

  SELECT gold, gems INTO v_current_gold, v_current_gems
  FROM public.users
  WHERE auth_id = v_auth_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_current_gems < v_gems THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
  END IF;

  UPDATE public.users
  SET gems = gems - v_gems,
      gold = gold + v_gold
  WHERE auth_id = v_auth_id;

  RETURN jsonb_build_object(
    'success', true,
    'gems_spent', v_gems,
    'gold_gained', v_gold,
    'gold_per_gem', 600,
    'gems', (v_current_gems - v_gems),
    'gold', (v_current_gold + v_gold)
  );
END;
$$;

-- ── 2) Shop catalog fix (PLAN_06: gem never buys direct gear power) ─────────
UPDATE public.items
SET shop_currency = 'gold',
    base_price = 868,
    updated_at = now()
WHERE id = 'boots_moccasins_common';

-- ── 3) IAP gem packages (TL + USD catalog; grant via StoreKit later) ──────────
CREATE TABLE IF NOT EXISTS public.gem_iap_packages (
  id TEXT PRIMARY KEY,
  gems INTEGER NOT NULL CHECK (gems > 0),
  price_usd_cents INTEGER NOT NULL CHECK (price_usd_cents > 0),
  price_try INTEGER NOT NULL CHECK (price_try > 0),
  store_product_id TEXT NOT NULL UNIQUE,
  is_best_value BOOLEAN NOT NULL DEFAULT FALSE,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.gem_iap_packages (id, gems, price_usd_cents, price_try, store_product_id, is_best_value, display_order)
VALUES
  ('gem_starter', 100, 99, 39, 'com.gkk.gems.starter', false, 1),
  ('gem_standard', 500, 499, 199, 'com.gkk.gems.standard', false, 2),
  ('gem_best_value', 1200, 999, 399, 'com.gkk.gems.best_value', true, 3),
  ('gem_mega', 2600, 1999, 799, 'com.gkk.gems.mega', false, 4)
ON CONFLICT (id) DO UPDATE SET
  gems = EXCLUDED.gems,
  price_usd_cents = EXCLUDED.price_usd_cents,
  price_try = EXCLUDED.price_try,
  store_product_id = EXCLUDED.store_product_id,
  is_best_value = EXCLUDED.is_best_value,
  display_order = EXCLUDED.display_order,
  is_active = TRUE,
  updated_at = now();

CREATE OR REPLACE FUNCTION public.get_gem_iap_packages()
RETURNS TABLE(
  id TEXT,
  gems INTEGER,
  price_usd_cents INTEGER,
  price_try INTEGER,
  store_product_id TEXT,
  is_best_value BOOLEAN,
  display_order INTEGER
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT id, gems, price_usd_cents, price_try, store_product_id, is_best_value, display_order
  FROM public.gem_iap_packages
  WHERE is_active = TRUE
  ORDER BY display_order, id;
$$;

GRANT EXECUTE ON FUNCTION public.get_gem_iap_packages() TO authenticated;

-- ── 4) Loot ladder collapse ─────────────────────────────────────────────────
-- Gem: 8 themes × 3 tiers (box_01..24). Deactivate box_25.
UPDATE public.loot_box_configs SET is_active = FALSE, updated_at = now()
WHERE id = 'box_25';

-- Gem tier prices (600 anchor RTP targets)
UPDATE public.loot_box_configs SET
  price = CASE
    WHEN display_order BETWEEN 1 AND 8 THEN CASE theme_id WHEN 'prestige' THEN 100 ELSE 50 END
    WHEN display_order BETWEEN 9 AND 16 THEN CASE theme_id WHEN 'prestige' THEN 200 ELSE 100 END
    WHEN display_order BETWEEN 17 AND 24 THEN CASE theme_id WHEN 'prestige' THEN 300 ELSE 200 END
    ELSE price
  END,
  reward_multiplier = CASE
    WHEN display_order BETWEEN 1 AND 8 THEN 1.12
    WHEN display_order BETWEEN 9 AND 16 THEN 1.08
    WHEN display_order BETWEEN 17 AND 24 THEN 1.04
    ELSE reward_multiplier
  END,
  updated_at = now()
WHERE currency_type = 'gems' AND display_order BETWEEN 1 AND 24;

-- Gold: 4 themes × 3 tiers (box_26..37). Band 80K / 140K / 200K.
UPDATE public.loot_box_configs SET is_active = FALSE, updated_at = now()
WHERE currency_type = 'gold' AND display_order BETWEEN 38 AND 50;

UPDATE public.loot_box_configs SET
  price = CASE
    WHEN display_order BETWEEN 26 AND 29 THEN 80000
    WHEN display_order BETWEEN 30 AND 33 THEN 140000
    WHEN display_order BETWEEN 34 AND 37 THEN 200000
    ELSE price
  END,
  reward_multiplier = 1.0,
  updated_at = now()
WHERE currency_type = 'gold' AND display_order BETWEEN 26 AND 37 AND is_active = TRUE;

-- ── 5) RTP tune — rarity lift (gem) + vendor/qty lift (gold) ────────────────
UPDATE public.loot_box_drop_entries e
SET weight = e.weight * (
  CASE lower(COALESCE(i.rarity, 'common'))
    WHEN 'mythic' THEN 1.6
    WHEN 'legendary' THEN 2.0
    WHEN 'epic' THEN 2.6
    WHEN 'rare' THEN 1.5
    WHEN 'uncommon' THEN 0.9
    ELSE 0.5
  END
)::numeric,
updated_at = now()
FROM public.items i, public.loot_box_configs b
WHERE e.item_id = i.id
  AND e.box_id = b.id
  AND b.is_active = TRUE
  AND b.currency_type = 'gems';

UPDATE public.loot_box_drop_entries e
SET
  weight = e.weight * (
    CASE
      WHEN COALESCE(i.vendor_sell_price, 0) >= 25000 THEN 2.8
      WHEN COALESCE(i.vendor_sell_price, 0) >= 8000 THEN 2.2
      WHEN COALESCE(i.vendor_sell_price, 0) >= 2000 THEN 1.7
      ELSE 1.3
    END
  )::numeric,
  max_quantity = GREATEST(
    e.max_quantity,
    CASE
      WHEN b.theme_id IN ('starter', 'consumable', 'craft')
        AND lower(COALESCE(i.rarity, 'common')) IN ('common', 'uncommon') THEN 4
      ELSE e.max_quantity
    END
  ),
  updated_at = now()
FROM public.items i, public.loot_box_configs b
WHERE e.item_id = i.id
  AND e.box_id = b.id
  AND b.is_active = TRUE
  AND b.currency_type = 'gold';

-- Cap prestige chase (no catalyst-style EV spikes)
UPDATE public.loot_box_drop_entries e
SET weight = LEAST(e.weight, 0.12),
    is_featured = (e.is_featured AND COALESCE(i.vendor_sell_price, 0) <= 120000),
    updated_at = now()
FROM public.items i, public.loot_box_configs b
WHERE e.item_id = i.id
  AND e.box_id = b.id
  AND b.theme_id = 'prestige'
  AND b.is_active = TRUE;

COMMIT;
