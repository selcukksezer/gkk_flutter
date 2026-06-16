-- =========================================================================================
-- MEKAN REDESIGN - PHASE 1: schema additions + pure helper functions
-- Adds tracking columns, happy hour, capacity/pricing/profit helpers, refined eligibility.
-- =========================================================================================

-- 1. New columns on mekans (idempotent)
ALTER TABLE public.mekans ADD COLUMN IF NOT EXISTS happy_hour_until TIMESTAMPTZ;
ALTER TABLE public.mekans ADD COLUMN IF NOT EXISTS total_revenue BIGINT NOT NULL DEFAULT 0;
ALTER TABLE public.mekans ADD COLUMN IF NOT EXISTS total_sales INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.mekans ADD COLUMN IF NOT EXISTS pvp_match_count INTEGER NOT NULL DEFAULT 0;

-- 2. Refined stock eligibility: potions (any case) + han-only items; exclude loot boxes / consumables.
CREATE OR REPLACE FUNCTION public.mekan_is_stock_eligible(p_item_id TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.items
    WHERE id = p_item_id
      AND (
        COALESCE(is_han_only, false) = true
        OR lower(COALESCE(type, '')) = 'potion'
      )
  );
$$ LANGUAGE sql STABLE;

-- 3. Base stock capacity by mekan type (PLAN_07 section 2.2).
CREATE OR REPLACE FUNCTION public.mekan_base_capacity(p_type TEXT)
RETURNS INTEGER AS $$
  SELECT CASE p_type
    WHEN 'bar' THEN 100
    WHEN 'kahvehane' THEN 100
    WHEN 'dovus_kulubu' THEN 50
    WHEN 'luks_lounge' THEN 200
    WHEN 'yeralti' THEN 300
    ELSE 100
  END;
$$ LANGUAGE sql IMMUTABLE;

-- 4. Cumulative extra stock capacity granted by level (PLAN_07 section 3.1).
CREATE OR REPLACE FUNCTION public.mekan_level_capacity_bonus(p_level INT)
RETURNS INTEGER AS $$
  SELECT CASE
    WHEN p_level >= 10 THEN 700
    WHEN p_level = 9 THEN 550
    WHEN p_level = 8 THEN 430
    WHEN p_level = 7 THEN 330
    WHEN p_level = 6 THEN 250
    WHEN p_level = 5 THEN 190
    WHEN p_level = 4 THEN 140
    WHEN p_level = 3 THEN 100
    WHEN p_level = 2 THEN 70
    ELSE 0
  END;
$$ LANGUAGE sql IMMUTABLE;

-- 5. Total stock capacity for a mekan = base(type) + cumulative level bonus.
CREATE OR REPLACE FUNCTION public.mekan_total_capacity(p_type TEXT, p_level INT)
RETURNS INTEGER AS $$
  SELECT public.mekan_base_capacity(p_type) + public.mekan_level_capacity_bonus(p_level);
$$ LANGUAGE sql IMMUTABLE;

-- 6. Owner profit bonus percent by level (PLAN_07 section 3.1).
CREATE OR REPLACE FUNCTION public.mekan_profit_bonus_pct(p_level INT)
RETURNS NUMERIC AS $$
  SELECT CASE
    WHEN p_level >= 10 THEN 0.80
    WHEN p_level = 9 THEN 0.65
    WHEN p_level = 8 THEN 0.50
    WHEN p_level = 7 THEN 0.40
    WHEN p_level = 6 THEN 0.30
    WHEN p_level = 5 THEN 0.20
    WHEN p_level = 4 THEN 0.15
    WHEN p_level = 3 THEN 0.10
    WHEN p_level = 2 THEN 0.05
    ELSE 0.0
  END;
$$ LANGUAGE sql IMMUTABLE;

-- 7. Sell-price band (min,max) per item (PLAN_07 sections 4.2 + 5.2).
--    Returns NULL bounds when item is unbanded (treated as unrestricted by callers).
CREATE OR REPLACE FUNCTION public.mekan_price_band(p_item_id TEXT)
RETURNS TABLE(min_price BIGINT, max_price BIGINT) AS $$
  SELECT bands.min_price, bands.max_price FROM (VALUES
    ('potion_health_minor',     7500::BIGINT,    25000::BIGINT),
    ('potion_health_major',     150000,          500000),
    ('potion_health_supreme',   300000,          1000000),
    ('potion_energy_minor',     7500,            50000),
    ('potion_energy_major',     50000,           300000),
    ('potion_energy_supreme',   150000,          1000000),
    ('potion_attack_buff',      300000,          1000000),
    ('potion_defense_buff',     300000,          1000000),
    ('potion_luck_buff',        750000,          2500000),
    ('potion_xp_buff',          300000,          1500000),
    ('detox_minor',             75000,           250000),
    ('detox_major',             300000,          1000000),
    ('detox_supreme',           750000,          2500000),
    ('han_item_vigor_minor',    80000,           200000),
    ('han_item_vigor_major',    300000,          800000),
    ('han_item_elixir_purge',   150000,          400000),
    ('han_item_clarity',        700000,          2000000),
    ('han_item_berserk',        1500000,         5000000),
    ('han_item_shadow_brew',    1200000,         3500000),
    ('han_item_restoration',    1200000,         3500000)
  ) AS bands(item_id, min_price, max_price)
  WHERE bands.item_id = p_item_id;
$$ LANGUAGE sql STABLE;

-- 8. Which item ids count as contraband (Yeralti-only smuggling, PLAN_07 section 8).
CREATE OR REPLACE FUNCTION public.mekan_is_contraband(p_item_id TEXT)
RETURNS BOOLEAN AS $$
  SELECT p_item_id IN ('han_item_berserk', 'han_item_shadow_brew');
$$ LANGUAGE sql IMMUTABLE;
