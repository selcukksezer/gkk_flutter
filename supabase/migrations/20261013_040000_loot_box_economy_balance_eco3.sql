-- ECO-3: Loot box price/pool balance
--
-- Problems (vendor RTP @ 600 gold/gem):
--   prestige gem boxes ~4300–8400% (catalyst chase in pool)
--   craft gold boxes ~15% vs starter ~3% at same tier (relative bonkör)
--   dungeon/epic gem ~14–17% vs weapon ~10%
--   gold prices 780K–5.1M disconnected from exchange ladder
--
-- Targets:
--   gem boxes: 48–58% vendor RTP (tier scales with display_order)
--   gold boxes: 38–45% vendor RTP
--   anchor: 1 gem = 600 gold

BEGIN;

-- ── 1) Gold price ladder (80K → 848K, +32K/step) ───────────────────────────
UPDATE public.loot_box_configs
SET
  price = 80000 + (display_order - 26) * 32000,
  updated_at = now()
WHERE currency_type = 'gold'
  AND display_order BETWEEN 26 AND 50;

-- ── 2) Rebuild template pools (box_01..08, box_26..29) ─────────────────────
DELETE FROM public.loot_box_drop_entries e
USING public.loot_box_configs b
WHERE e.box_id = b.id
  AND b.id LIKE 'box\_%' ESCAPE '\'
  AND b.display_order BETWEEN 1 AND 50;

-- weapon (box_01)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,'')) = 'weapon' AND lower(COALESCE(i.equip_slot,'')) = 'weapon'
    AND lower(COALESCE(i.rarity,'common')) IN ('common','uncommon','rare','epic','legendary')
), picked AS (
  SELECT id, rarity, (rarity = 'legendary' AND rn = 1) feat,
    CASE rarity WHEN 'common' THEN rn <= 6 WHEN 'uncommon' THEN rn <= 5 WHEN 'rare' THEN rn <= 4
      WHEN 'epic' THEN rn <= 3 WHEN 'legendary' THEN rn <= 2 ELSE false END ok
  FROM ranked
)
SELECT 'box_01', id,
  CASE WHEN feat THEN 0.10 WHEN rarity = 'legendary' THEN 0.05 WHEN rarity = 'epic' THEN 0.35
    WHEN rarity = 'rare' THEN 0.85 WHEN rarity = 'uncommon' THEN 1.20 ELSE 1.35 END,
  1, 1, rarity IN ('rare','epic','legendary'), feat FROM picked WHERE ok;

-- armor (box_02)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,'')) = 'armor'
    AND lower(COALESCE(i.equip_slot,'')) IN ('chest','head','legs','boots','gloves','helmet')
    AND lower(COALESCE(i.rarity,'common')) IN ('common','uncommon','rare','epic','legendary')
), picked AS (
  SELECT id, rarity, (rarity = 'legendary' AND rn = 1) feat,
    CASE rarity WHEN 'common' THEN rn <= 6 WHEN 'uncommon' THEN rn <= 5 WHEN 'rare' THEN rn <= 4
      WHEN 'epic' THEN rn <= 3 WHEN 'legendary' THEN rn <= 2 ELSE false END ok
  FROM ranked
)
SELECT 'box_02', id,
  CASE WHEN feat THEN 0.10 WHEN rarity = 'legendary' THEN 0.05 WHEN rarity = 'epic' THEN 0.38
    WHEN rarity = 'rare' THEN 0.90 WHEN rarity = 'uncommon' THEN 1.15 ELSE 1.40 END,
  1, 1, rarity IN ('rare','epic','legendary'), feat FROM picked WHERE ok;

-- jewelry (box_03)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.equip_slot,'')) IN ('ring','necklace')
    AND lower(COALESCE(i.rarity,'common')) IN ('uncommon','rare','epic','legendary','mythic')
), picked AS (
  SELECT id, rarity, (rarity IN ('mythic','legendary') AND rn = 1) feat,
    CASE rarity WHEN 'uncommon' THEN rn <= 4 WHEN 'rare' THEN rn <= 5 WHEN 'epic' THEN rn <= 4
      WHEN 'legendary' THEN rn <= 3 WHEN 'mythic' THEN rn <= 2 ELSE false END ok
  FROM ranked
)
SELECT 'box_03', id,
  CASE WHEN feat THEN 0.12 WHEN rarity = 'mythic' THEN 0.04 WHEN rarity = 'legendary' THEN 0.08
    WHEN rarity = 'epic' THEN 0.45 WHEN rarity = 'rare' THEN 0.95 ELSE 1.25 END,
  1, 1, rarity IN ('rare','epic','legendary','mythic'), feat FROM picked WHERE ok;

-- material (box_04)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE (lower(COALESCE(i.type,'')) IN ('material','consumable','scroll','rune')
      OR i.id ILIKE 'mat\_%' ESCAPE '\' OR i.id ILIKE '%rune%' OR i.id ILIKE '%scroll%')
    AND lower(COALESCE(i.rarity,'common')) IN ('common','uncommon','rare','epic')
    AND COALESCE(i.vendor_sell_price,0) <= 120000
), picked AS (
  SELECT id, rarity, (rarity = 'epic' AND rn = 1) feat,
    CASE rarity WHEN 'common' THEN rn <= 8 WHEN 'uncommon' THEN rn <= 6 WHEN 'rare' THEN rn <= 5
      WHEN 'epic' THEN rn <= 2 ELSE false END ok
  FROM ranked
)
SELECT 'box_04', id,
  CASE WHEN feat THEN 0.15 WHEN rarity = 'epic' THEN 0.25 WHEN rarity = 'rare' THEN 0.75
    WHEN rarity = 'uncommon' THEN 1.15 ELSE 1.40 END,
  1, CASE WHEN rarity IN ('common','uncommon') THEN 2 ELSE 1 END,
  rarity IN ('rare','epic'), feat FROM picked WHERE ok;

-- dungeon (box_05) — mixed pool, no leg chase spam
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH filler AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity, 1 AS tier
  FROM public.items i
  WHERE lower(COALESCE(i.rarity,'common')) IN ('common','uncommon')
    AND (lower(COALESCE(i.type,'')) IN ('consumable','material') OR i.id ILIKE '%potion%')
  ORDER BY COALESCE(i.vendor_sell_price,0) ASC, i.id
  LIMIT 10
), gear AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn,
    2 AS tier
  FROM public.items i
  WHERE (lower(COALESCE(i.type,'')) IN ('weapon','armor')
      OR lower(COALESCE(i.equip_slot,'')) IN ('weapon','chest','head','legs','boots','gloves','helmet'))
    AND lower(COALESCE(i.rarity,'common')) IN ('uncommon','rare','epic','legendary')
    AND COALESCE(i.vendor_sell_price,0) <= 200000
), picked AS (
  SELECT id, rarity, tier, (tier = 2 AND rn = 1) AS feat, rn FROM gear WHERE rn <= 16
  UNION ALL
  SELECT id, rarity, tier, false AS feat, NULL::bigint FROM filler
)
SELECT 'box_05', id,
  CASE WHEN feat THEN 0.08 WHEN tier = 2 AND rarity = 'legendary' THEN 0.03
    WHEN tier = 2 AND rarity = 'epic' THEN 0.22 WHEN tier = 2 AND rarity = 'rare' THEN 0.55
    WHEN tier = 2 THEN 0.75 ELSE 1.30 END,
  1, CASE WHEN tier = 1 AND rarity = 'common' THEN 2 ELSE 1 END,
  tier = 2 AND rarity IN ('rare','epic','legendary'), feat FROM picked;

-- epic_weapon (box_06)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,'')) = 'weapon' AND lower(COALESCE(i.equip_slot,'')) = 'weapon'
    AND lower(COALESCE(i.rarity,'common')) IN ('rare','epic','legendary','mythic')
    AND COALESCE(i.vendor_sell_price,0) <= 250000
), picked AS (
  SELECT id, rarity, (rarity IN ('legendary','mythic') AND rn = 1) feat,
    CASE rarity WHEN 'rare' THEN rn <= 4 WHEN 'epic' THEN rn <= 4
      WHEN 'legendary' THEN rn <= 2 WHEN 'mythic' THEN rn <= 1 ELSE false END ok
  FROM ranked
)
SELECT 'box_06', id,
  CASE WHEN feat THEN 0.10 WHEN rarity = 'mythic' THEN 0.03 WHEN rarity = 'legendary' THEN 0.06
    WHEN rarity = 'epic' THEN 0.35 ELSE 0.80 END,
  1, 1, true, feat FROM picked WHERE ok;

-- epic_armor (box_07)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,'')) = 'armor'
    AND lower(COALESCE(i.equip_slot,'')) IN ('chest','head','legs','boots','gloves','helmet')
    AND lower(COALESCE(i.rarity,'common')) IN ('rare','epic','legendary','mythic')
    AND COALESCE(i.vendor_sell_price,0) <= 250000
), picked AS (
  SELECT id, rarity, (rarity IN ('legendary','mythic') AND rn = 1) feat,
    CASE rarity WHEN 'rare' THEN rn <= 4 WHEN 'epic' THEN rn <= 4
      WHEN 'legendary' THEN rn <= 2 WHEN 'mythic' THEN rn <= 1 ELSE false END ok
  FROM ranked
)
SELECT 'box_07', id,
  CASE WHEN feat THEN 0.10 WHEN rarity = 'mythic' THEN 0.03 WHEN rarity = 'legendary' THEN 0.06
    WHEN rarity = 'epic' THEN 0.33 ELSE 0.78 END,
  1, 1, true, feat FROM picked WHERE ok;

-- prestige (box_08) — equippable leg/myth ONLY, no catalysts/mats
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.rarity,'common')) IN ('legendary','mythic')
    AND (
      lower(COALESCE(i.type,'')) IN ('weapon','armor')
      OR lower(COALESCE(i.equip_slot,'')) IN ('weapon','chest','head','legs','boots','gloves','helmet','ring','necklace')
    )
    AND i.id NOT LIKE 'catalyst%'
    AND COALESCE(i.vendor_sell_price,0) BETWEEN 1 AND 450000
), picked AS (
  SELECT id, rarity, (rn = 1) feat,
    CASE rarity WHEN 'legendary' THEN rn <= 8 WHEN 'mythic' THEN rn <= 4 ELSE false END ok
  FROM ranked
)
SELECT 'box_08', id,
  CASE WHEN feat THEN 0.10 WHEN rarity = 'mythic' THEN 0.04 WHEN rarity = 'legendary' THEN 0.14 ELSE 0.22 END,
  1, 1, true, feat FROM picked WHERE ok;

-- gold starter (box_26)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH gear AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity
  FROM public.items i
  WHERE lower(COALESCE(i.rarity,'common')) IN ('common','uncommon')
    AND (lower(COALESCE(i.type,'')) IN ('weapon','armor','consumable') OR i.id ILIKE '%potion%')
  ORDER BY COALESCE(i.vendor_sell_price,0) ASC, i.id
  LIMIT 18
)
SELECT 'box_26', id,
  CASE rarity WHEN 'uncommon' THEN 1.05 ELSE 1.35 END,
  1, CASE WHEN id ILIKE '%potion%' THEN 2 ELSE 1 END,
  rarity = 'uncommon', false FROM gear;

-- gold craft (box_27) — no mythic stacks, capped vendor
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH mats AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.vendor_sell_price,0) ASC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,'')) IN ('material','scroll','rune')
    AND lower(COALESCE(i.rarity,'common')) IN ('common','uncommon','rare','epic')
    AND COALESCE(i.vendor_sell_price,0) <= 35000
    AND i.id NOT IN ('scroll_upgrade_high')
), picked AS (
  SELECT id, rarity, (rarity = 'epic' AND rn = 1) feat,
    CASE rarity WHEN 'common' THEN rn <= 8 WHEN 'uncommon' THEN rn <= 6
      WHEN 'rare' THEN rn <= 4 WHEN 'epic' THEN rn <= 2 ELSE false END ok
  FROM mats
)
SELECT 'box_27', id,
  CASE WHEN feat THEN 0.12 WHEN rarity = 'epic' THEN 0.10 WHEN rarity = 'rare' THEN 0.45
    WHEN rarity = 'uncommon' THEN 0.95 ELSE 1.15 END,
  1, CASE WHEN rarity IN ('common','uncommon') THEN 2 ELSE 1 END,
  rarity IN ('rare','epic'), feat FROM picked WHERE ok;

-- gold consumable (box_28)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH cons AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity
  FROM public.items i
  WHERE (lower(COALESCE(i.type,'')) = 'consumable' OR i.id ILIKE '%potion%' OR i.id ILIKE '%elixir%')
    AND COALESCE(i.vendor_sell_price,0) <= 25000
  ORDER BY COALESCE(i.vendor_sell_price,0) ASC, i.id
  LIMIT 16
)
SELECT 'box_28', id, 1.20, 1, 3, rarity IN ('rare','uncommon'), false FROM cons;

-- gold mid_gear (box_29)
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (ORDER BY COALESCE(i.vendor_sell_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.rarity,'common')) IN ('uncommon','rare','epic')
    AND (lower(COALESCE(i.type,'')) IN ('weapon','armor')
      OR lower(COALESCE(i.equip_slot,'')) IN ('weapon','chest','head','legs','boots','gloves','helmet'))
    AND COALESCE(i.vendor_sell_price,0) BETWEEN 500 AND 45000
), picked AS (SELECT id, rarity, (rn = 1) feat FROM ranked WHERE rn <= 20)
SELECT 'box_29', id,
  CASE WHEN feat THEN 0.15 WHEN rarity = 'epic' THEN 0.18 WHEN rarity = 'rare' THEN 0.55 ELSE 0.95 END,
  1, 1, rarity IN ('rare','epic'), feat FROM picked;

-- Copy templates to themed siblings
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured, is_active)
SELECT b.id, e.item_id, e.weight, e.min_quantity, e.max_quantity, e.show_in_preview, e.is_featured, true
FROM public.loot_box_configs b
JOIN public.loot_box_configs t ON t.theme_id = b.theme_id
JOIN public.loot_box_drop_entries e ON e.box_id = t.id AND e.is_active = true
WHERE b.display_order BETWEEN 1 AND 50
  AND b.id LIKE 'box\_%' ESCAPE '\'
  AND t.id = CASE b.theme_id
    WHEN 'weapon' THEN 'box_01' WHEN 'armor' THEN 'box_02' WHEN 'jewelry' THEN 'box_03'
    WHEN 'material' THEN 'box_04' WHEN 'dungeon' THEN 'box_05' WHEN 'epic_weapon' THEN 'box_06'
    WHEN 'epic_armor' THEN 'box_07' WHEN 'prestige' THEN 'box_08' WHEN 'starter' THEN 'box_26'
    WHEN 'craft' THEN 'box_27' WHEN 'consumable' THEN 'box_28' WHEN 'mid_gear' THEN 'box_29'
  END
  AND b.id <> t.id;

-- ── 3) QA EV helper — 600 gold/gem + direct RTP field ───────────────────────
CREATE OR REPLACE FUNCTION public.qa_loot_box_ev(p_box_id text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH drops AS (
    SELECT
      e.weight,
      e.min_quantity,
      e.max_quantity,
      COALESCE(i.rarity, 'common') AS rarity,
      COALESCE(i.base_price, 0) AS base_price,
      COALESCE(i.vendor_sell_price, 0) AS vendor_sell,
      COALESCE(i.power, 0) AS power
    FROM public.loot_box_drop_entries e
    JOIN public.items i ON i.id = e.item_id
    WHERE e.box_id = p_box_id
      AND e.is_active = TRUE
  ),
  box AS (
    SELECT * FROM public.loot_box_configs WHERE id = p_box_id
  ),
  agg AS (
    SELECT
      SUM(weight) AS tw,
      SUM(weight * ((min_quantity + max_quantity) / 2.0) * base_price)
        / NULLIF(SUM(weight), 0) AS ev_base,
      SUM(weight * ((min_quantity + max_quantity) / 2.0) * vendor_sell)
        / NULLIF(SUM(weight), 0) AS ev_vendor,
      SUM(weight * power) / NULLIF(SUM(weight), 0) AS ev_power,
      SUM(CASE WHEN rarity = 'common' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_common,
      SUM(CASE WHEN rarity = 'uncommon' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_uncommon,
      SUM(CASE WHEN rarity = 'rare' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_rare,
      SUM(CASE WHEN rarity = 'epic' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_epic,
      SUM(CASE WHEN rarity = 'legendary' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_legendary,
      SUM(CASE WHEN rarity = 'mythic' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_mythic
    FROM drops
  )
  SELECT jsonb_build_object(
    'box_id', b.id,
    'name', b.name,
    'theme_id', b.theme_id,
    'currency', b.currency_type,
    'price', b.price,
    'reward_multiplier', b.reward_multiplier,
    'jackpot_rate_pct', ROUND(((a.pct_legendary + a.pct_mythic))::numeric, 3),
    'rarity_pct', jsonb_build_object(
      'common', ROUND(a.pct_common::numeric, 2),
      'uncommon', ROUND(a.pct_uncommon::numeric, 2),
      'rare', ROUND(a.pct_rare::numeric, 2),
      'epic', ROUND(a.pct_epic::numeric, 2),
      'legendary', ROUND(a.pct_legendary::numeric, 2),
      'mythic', ROUND(a.pct_mythic::numeric, 2)
    ),
    'ev_base_price', ROUND((a.ev_base * b.reward_multiplier)::numeric, 0),
    'ev_vendor_sell', ROUND((a.ev_vendor * b.reward_multiplier)::numeric, 0),
    'ev_power', ROUND(a.ev_power::numeric, 1),
    'gold_per_gem_ref', 600,
    'cost_gold_equiv', CASE
      WHEN b.currency_type = 'gems' THEN b.price * 600
      ELSE b.price
    END,
    'vendor_rtp_pct', ROUND((
      (a.ev_vendor * b.reward_multiplier)
      / NULLIF(CASE WHEN b.currency_type = 'gems' THEN b.price * 600.0 ELSE b.price END, 0)
      * 100
    )::numeric, 1)
  )
  FROM box b
  CROSS JOIN agg a;
$function$;

GRANT EXECUTE ON FUNCTION public.qa_loot_box_ev(text) TO authenticated;

-- ── 4) Theme-specific price corrections ───────────────────────────────────────
-- Prestige chase pool avg vendor ~9K; 2× gem price → ~8% RTP (was ~17% @ 91💎)
UPDATE public.loot_box_configs
SET price = CASE id
  WHEN 'box_08' THEN 182
  WHEN 'box_16' THEN 294
  WHEN 'box_24' THEN 406
  ELSE price
END,
updated_at = now()
WHERE theme_id = 'prestige';

-- Material stacks inflated EV (qty 2–3 on commons)
UPDATE public.loot_box_drop_entries e
SET max_quantity = 1
FROM public.loot_box_configs b
WHERE e.box_id = b.id
  AND b.theme_id = 'material'
  AND e.max_quantity > 1;

COMMIT;
