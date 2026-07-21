-- ECO-2 compact: template boxes per theme + copy to price ladder boxes

BEGIN;

ALTER TABLE public.loot_box_drop_entries
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT FALSE;

-- Template ids (must match theme_id assignment from prior migration)
-- gem: box_01..box_08 = 8 themes; gold: box_26..box_29 = 4 themes

DELETE FROM public.loot_box_drop_entries e
USING public.loot_box_configs b
WHERE e.box_id = b.id
  AND b.id LIKE 'box\_%' ESCAPE '\'
  AND b.display_order BETWEEN 1 AND 50;

-- ── weapon (box_01) ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,''))='weapon' AND lower(COALESCE(i.equip_slot,''))='weapon'
    AND lower(COALESCE(i.rarity,'common')) IN ('common','uncommon','rare','epic','legendary')
), picked AS (
  SELECT id, rarity, (rarity='legendary' AND rn=1) feat,
    CASE rarity WHEN 'common' THEN rn<=6 WHEN 'uncommon' THEN rn<=5 WHEN 'rare' THEN rn<=4 WHEN 'epic' THEN rn<=3 WHEN 'legendary' THEN rn<=2 ELSE false END ok
  FROM ranked
)
SELECT 'box_01', id,
  CASE WHEN feat THEN 2.2 WHEN rarity='legendary' THEN 0.07 WHEN rarity='epic' THEN 0.42 WHEN rarity='rare' THEN 0.9 WHEN rarity='uncommon' THEN 1.25 ELSE 1.4 END,
  1,1, rarity IN ('rare','epic','legendary'), feat FROM picked WHERE ok;

-- ── armor (box_02) ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,''))='armor'
    AND lower(COALESCE(i.equip_slot,'')) IN ('chest','head','legs','boots','gloves','helmet')
    AND lower(COALESCE(i.rarity,'common')) IN ('common','uncommon','rare','epic','legendary')
), picked AS (
  SELECT id, rarity, (rarity='legendary' AND rn=1) feat,
    CASE rarity WHEN 'common' THEN rn<=6 WHEN 'uncommon' THEN rn<=5 WHEN 'rare' THEN rn<=4 WHEN 'epic' THEN rn<=3 WHEN 'legendary' THEN rn<=2 ELSE false END ok
  FROM ranked
)
SELECT 'box_02', id,
  CASE WHEN feat THEN 2.0 WHEN rarity='legendary' THEN 0.08 WHEN rarity='epic' THEN 0.45 WHEN rarity='rare' THEN 0.95 WHEN rarity='uncommon' THEN 1.3 ELSE 1.45 END,
  1,1, rarity IN ('rare','epic','legendary'), feat FROM picked WHERE ok;

-- ── jewelry (box_03) ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.equip_slot,'')) IN ('ring','necklace')
    AND lower(COALESCE(i.rarity,'common')) IN ('uncommon','rare','epic','legendary','mythic')
), picked AS (
  SELECT id, rarity, (rarity IN ('mythic','legendary') AND rn=1) feat,
    CASE rarity WHEN 'uncommon' THEN rn<=4 WHEN 'rare' THEN rn<=5 WHEN 'epic' THEN rn<=4 WHEN 'legendary' THEN rn<=3 WHEN 'mythic' THEN rn<=2 ELSE false END ok
  FROM ranked
)
SELECT 'box_03', id,
  CASE WHEN feat THEN 2.5 WHEN rarity='mythic' THEN 0.05 WHEN rarity='legendary' THEN 0.12 WHEN rarity='epic' THEN 0.55 WHEN rarity='rare' THEN 1.05 ELSE 1.35 END,
  1,1, rarity IN ('rare','epic','legendary','mythic'), feat FROM picked WHERE ok;

-- ── material (box_04) ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE (lower(COALESCE(i.type,'')) IN ('material','consumable','scroll','rune') OR i.id ILIKE 'mat\_%' ESCAPE '\' OR i.id ILIKE '%rune%' OR i.id ILIKE '%scroll%')
    AND lower(COALESCE(i.rarity,'common')) IN ('common','uncommon','rare','epic')
), picked AS (
  SELECT id, rarity, (rarity='epic' AND rn=1) feat,
    CASE rarity WHEN 'common' THEN rn<=8 WHEN 'uncommon' THEN rn<=6 WHEN 'rare' THEN rn<=5 WHEN 'epic' THEN rn<=3 ELSE false END ok
  FROM ranked
)
SELECT 'box_04', id,
  CASE WHEN feat THEN 1.8 WHEN rarity='epic' THEN 0.35 WHEN rarity='rare' THEN 0.85 WHEN rarity='uncommon' THEN 1.2 ELSE 1.5 END,
  1, CASE WHEN rarity IN ('common','uncommon') THEN 3 ELSE 1 END, rarity IN ('rare','epic'), feat FROM picked WHERE ok;

-- ── dungeon (box_05) ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE (lower(COALESCE(i.type,'')) IN ('weapon','armor') OR lower(COALESCE(i.equip_slot,'')) IN ('weapon','chest','head','legs','boots','gloves','helmet'))
    AND lower(COALESCE(i.rarity,'common')) IN ('uncommon','rare','epic','legendary')
), picked AS (SELECT id, rarity, (rn=1) feat FROM ranked WHERE rn<=28)
SELECT 'box_05', id, CASE WHEN feat THEN 2.1 WHEN rarity='legendary' THEN 0.1 WHEN rarity='epic' THEN 0.5 WHEN rarity='rare' THEN 1.0 ELSE 1.25 END,
  1,1, rarity IN ('rare','epic','legendary'), feat FROM picked;

-- ── epic_weapon (box_06) ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,''))='weapon' AND lower(COALESCE(i.equip_slot,''))='weapon'
    AND lower(COALESCE(i.rarity,'common')) IN ('rare','epic','legendary','mythic')
), picked AS (
  SELECT id, rarity, (rarity IN ('legendary','mythic') AND rn=1) feat,
    CASE rarity WHEN 'rare' THEN rn<=4 WHEN 'epic' THEN rn<=4 WHEN 'legendary' THEN rn<=3 WHEN 'mythic' THEN rn<=2 ELSE false END ok
  FROM ranked
)
SELECT 'box_06', id, CASE WHEN feat THEN 2.8 WHEN rarity='mythic' THEN 0.06 WHEN rarity='legendary' THEN 0.15 WHEN rarity='epic' THEN 0.6 ELSE 1.05 END,
  1,1,true, feat FROM picked WHERE ok;

-- ── epic_armor (box_07) ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (PARTITION BY lower(COALESCE(i.rarity,'common')) ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.type,''))='armor'
    AND lower(COALESCE(i.equip_slot,'')) IN ('chest','head','legs','boots','gloves','helmet')
    AND lower(COALESCE(i.rarity,'common')) IN ('rare','epic','legendary','mythic')
), picked AS (
  SELECT id, rarity, (rarity IN ('legendary','mythic') AND rn=1) feat,
    CASE rarity WHEN 'rare' THEN rn<=4 WHEN 'epic' THEN rn<=4 WHEN 'legendary' THEN rn<=3 WHEN 'mythic' THEN rn<=2 ELSE false END ok
  FROM ranked
)
SELECT 'box_07', id, CASE WHEN feat THEN 2.6 WHEN rarity='mythic' THEN 0.06 WHEN rarity='legendary' THEN 0.14 WHEN rarity='epic' THEN 0.58 ELSE 1.0 END,
  1,1,true, feat FROM picked WHERE ok;

-- ── prestige (box_08) ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) AS rarity,
    ROW_NUMBER() OVER (ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.rarity,'common')) IN ('legendary','mythic')
), picked AS (SELECT id, rarity, (rn<=2) feat FROM ranked WHERE rn<=14)
SELECT 'box_08', id, CASE WHEN feat THEN 3.2 WHEN rarity='mythic' THEN 0.12 ELSE 0.25 END, 1,1,true, feat FROM picked;

-- ── gold templates ──
INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH gear AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) rarity FROM public.items i
  WHERE lower(COALESCE(i.rarity,'common')) IN ('common','uncommon')
    AND (lower(COALESCE(i.type,'')) IN ('weapon','armor','consumable') OR i.id ILIKE '%potion%')
 LIMIT 18
)
SELECT 'box_26', id, CASE rarity WHEN 'uncommon' THEN 1.1 ELSE 1.45 END, 1, CASE WHEN id ILIKE '%potion%' THEN 3 ELSE 1 END, rarity='uncommon', false FROM gear;

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH mats AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) rarity,
    ROW_NUMBER() OVER (ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE (lower(COALESCE(i.type,'')) IN ('material','scroll','rune') OR i.id ILIKE 'mat\_%' ESCAPE '\') LIMIT 22
)
SELECT 'box_27', id, CASE rarity WHEN 'epic' THEN 0.4 WHEN 'rare' THEN 0.9 WHEN 'uncommon' THEN 1.2 ELSE 1.5 END,
  1, CASE WHEN rarity IN ('common','uncommon') THEN 5 ELSE 2 END, rarity IN ('rare','epic'), rn=1 FROM mats;

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH cons AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) rarity FROM public.items i
  WHERE (lower(COALESCE(i.type,''))='consumable' OR i.id ILIKE '%potion%' OR i.id ILIKE '%elixir%') LIMIT 16
)
SELECT 'box_28', id, 1.35, 1, 5, rarity IN ('rare','uncommon'), false FROM cons;

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured)
WITH ranked AS (
  SELECT i.id, lower(COALESCE(i.rarity,'common')) rarity,
    ROW_NUMBER() OVER (ORDER BY COALESCE(i.base_price,0) DESC, i.id) rn
  FROM public.items i
  WHERE lower(COALESCE(i.rarity,'common')) IN ('rare','epic')
    AND (lower(COALESCE(i.type,'')) IN ('weapon','armor') OR lower(COALESCE(i.equip_slot,'')) IN ('weapon','chest','head','legs','boots','gloves','helmet'))
), picked AS (SELECT id, rarity, (rn=1) feat FROM ranked WHERE rn<=24)
SELECT 'box_29', id, CASE WHEN feat THEN 1.9 WHEN rarity='epic' THEN 0.55 ELSE 1.05 END, 1,1,true, feat FROM picked;

-- Copy template pools to all boxes sharing theme_id
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

CREATE OR REPLACE FUNCTION public.get_loot_box_drops(p_box_id text)
 RETURNS TABLE(item_id text, item_name text, icon text, rarity text, min_quantity integer, max_quantity integer, weight numeric, drop_rate numeric, is_featured boolean)
 LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
  WITH pool AS (SELECT COALESCE(SUM(e.weight),0)::numeric total_weight FROM public.loot_box_drop_entries e WHERE e.box_id=p_box_id AND e.is_active=true)
  SELECT e.item_id, i.name, i.icon, COALESCE(i.rarity,'common'), e.min_quantity, e.max_quantity, e.weight,
    (e.weight/NULLIF(pool.total_weight,0)*100)::numeric, COALESCE(e.is_featured,false)
  FROM public.loot_box_drop_entries e JOIN public.items i ON i.id=e.item_id CROSS JOIN pool
  WHERE e.box_id=p_box_id AND e.is_active=true AND e.show_in_preview=true
  ORDER BY e.is_featured DESC, drop_rate DESC, item_name ASC;
$function$;

CREATE OR REPLACE FUNCTION public.get_loot_boxes_with_stats()
RETURNS TABLE (id text, name text, description text, currency_type text, price integer, reward_multiplier numeric, art_asset text,
  drop_count integer, total_weight numeric, jackpot_rate numeric, display_order integer, theme_id text)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $$
  SELECT b.id, b.name, b.description, b.currency_type, b.price, b.reward_multiplier, b.art_asset,
    COUNT(e.id)::int, COALESCE(SUM(e.weight),0)::numeric,
    COALESCE(SUM(e.weight) FILTER (WHERE COALESCE(i.rarity,'common') IN ('legendary','mythic'))/NULLIF(SUM(e.weight),0),0)::numeric,
    b.display_order, b.theme_id
  FROM public.loot_box_configs b
  LEFT JOIN public.loot_box_drop_entries e ON e.box_id=b.id AND e.is_active=true
  LEFT JOIN public.items i ON i.id=e.item_id
  WHERE b.is_active=true GROUP BY b.id ORDER BY b.display_order, b.id;
$$;

COMMIT;
