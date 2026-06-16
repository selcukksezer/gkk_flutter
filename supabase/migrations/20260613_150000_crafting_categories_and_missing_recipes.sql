-- Crafting workshop: fix tab categories, English rune names, enrich ingredient names,
-- and seed recipes for all non-material items missing from crafting_recipes.

BEGIN;

-- 1) English rune names
UPDATE public.items SET
  name = CASE id
    WHEN 'rune_basic' THEN 'Basic Rune'
    WHEN 'rune_advanced' THEN 'Advanced Rune'
    WHEN 'rune_superior' THEN 'Superior Rune'
    WHEN 'rune_legendary' THEN 'Legendary Rune'
    WHEN 'rune_protection' THEN 'Protection Rune'
    WHEN 'rune_blessed' THEN 'Blessed Rune'
    ELSE name
  END,
  description = CASE id
    WHEN 'rune_basic' THEN 'Increases enhancement success chance.'
    WHEN 'rune_advanced' THEN 'Strong enhancement aid.'
    WHEN 'rune_superior' THEN 'High success rate and reduced destruction.'
    WHEN 'rune_legendary' THEN 'Exceptional success and damage reduction.'
    WHEN 'rune_protection' THEN 'Prevents item destruction on failure.'
    WHEN 'rune_blessed' THEN 'Prevents level loss on failure.'
    ELSE description
  END,
  type = 'rune'
WHERE id IN (
  'rune_basic', 'rune_advanced', 'rune_superior',
  'rune_legendary', 'rune_protection', 'rune_blessed'
);

CREATE OR REPLACE FUNCTION public._craft_workshop_category(
  p_type text,
  p_equip_slot text,
  p_item_id text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN lower(COALESCE(p_type, '')) = 'weapon' OR p_equip_slot = 'weapon' THEN 'weapon'
    WHEN p_equip_slot IN ('ring', 'necklace') THEN 'accessory'
    WHEN lower(COALESCE(p_type, '')) = 'armor'
      AND COALESCE(p_equip_slot, 'none') IN ('chest', 'head', 'legs', 'boots', 'gloves') THEN 'armor'
    WHEN lower(COALESCE(p_type, '')) IN ('potion', 'catalyst')
      OR (
        lower(COALESCE(p_type, '')) = 'consumable'
        AND COALESCE(p_item_id, '') NOT LIKE 'box\_%' ESCAPE '\'
      ) THEN 'potion'
    WHEN lower(COALESCE(p_type, '')) = 'rune' THEN 'rune'
    WHEN lower(COALESCE(p_type, '')) = 'scroll' THEN 'scroll'
    WHEN COALESCE(p_item_id, '') LIKE 'box\_%' ESCAPE '\' THEN 'other'
    ELSE 'other'
  END;
$$;

CREATE OR REPLACE FUNCTION public._enrich_craft_ingredients(p_ingredients jsonb)
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object(
          'item_id', ing->>'item_id',
          'item_name', COALESCE(it.name, ing->>'item_id'),
          'quantity', GREATEST(1, COALESCE((ing->>'quantity')::int, 1))
        )
        ORDER BY ing->>'item_id'
      )
      FROM jsonb_array_elements(COALESCE(p_ingredients, '[]'::jsonb)) ing
      LEFT JOIN public.items it ON it.id = ing->>'item_id'
    ),
    '[]'::jsonb
  );
$$;

DROP FUNCTION IF EXISTS public.get_craft_recipes(integer);

CREATE OR REPLACE FUNCTION public.get_craft_recipes(p_user_level integer DEFAULT 1)
RETURNS TABLE(
  id uuid,
  recipe_id uuid,
  name text,
  output_item_id text,
  output_name text,
  output_quantity integer,
  output_rarity text,
  item_type text,
  recipe_type text,
  required_level integer,
  production_time_seconds integer,
  success_rate double precision,
  xp_reward integer,
  ingredients jsonb,
  gold_cost bigint,
  gem_cost integer,
  description text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cr.id,
    cr.id AS recipe_id,
    COALESCE(ii.name, cr.output_item_id) AS name,
    cr.output_item_id,
    COALESCE(ii.name, cr.output_item_id) AS output_name,
    1 AS output_quantity,
    lower(COALESCE(ii.rarity, 'common')) AS output_rarity,
    lower(COALESCE(ii.type, 'misc')) AS item_type,
    public._craft_workshop_category(ii.type, ii.equip_slot, ii.id) AS recipe_type,
    cr.required_level,
    COALESCE(cr.production_time_seconds, 30) AS production_time_seconds,
    cr.success_rate,
    cr.xp_reward,
    public._enrich_craft_ingredients(cr.ingredients) AS ingredients,
    COALESCE(cr.gold_cost, 0) AS gold_cost,
    0 AS gem_cost,
    COALESCE(ii.description, '') AS description
  FROM public.crafting_recipes cr
  LEFT JOIN public.items ii ON ii.id = cr.output_item_id
  WHERE cr.required_level <= p_user_level
  ORDER BY public._craft_workshop_category(ii.type, ii.equip_slot, ii.id), cr.required_level, cr.output_item_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_craft_recipes(integer) TO anon, authenticated, service_role;

-- 2) Seed missing recipes (non-material craft outputs)
WITH rarity_cfg AS (
  SELECT *
  FROM (VALUES
    ('common', 1, 300, 0.95::numeric, 50, 5000),
    ('uncommon', 3, 900, 0.90::numeric, 90, 25000),
    ('rare', 5, 3600, 0.85::numeric, 180, 250000),
    ('epic', 8, 14400, 0.75::numeric, 320, 1000000),
    ('legendary', 12, 43200, 0.60::numeric, 520, 5000000),
    ('mythic', 15, 86400, 0.45::numeric, 800, 25000000)
  ) AS t(rarity, required_level, production_time_seconds, success_rate, xp_reward, gold_cost)
),
potion_targets AS (
  SELECT i.id, lower(COALESCE(i.rarity, 'common')) AS rarity,
    CASE
      WHEN i.id LIKE 'box\_%' ESCAPE '\' THEN 'box'
      WHEN i.id LIKE 'detox\_%' ESCAPE '\' THEN replace(i.id, 'detox_', '')
      WHEN i.id LIKE 'han\_%' ESCAPE '\' THEN 'han'
      WHEN i.id LIKE '%\_minor' ESCAPE '\' OR i.id LIKE '%\_low' ESCAPE '\' THEN 'minor'
      WHEN i.id LIKE '%\_major' ESCAPE '\' OR i.id LIKE '%\_middle' ESCAPE '\' THEN 'major'
      WHEN i.id LIKE '%\_supreme' ESCAPE '\' OR i.id LIKE '%\_high' ESCAPE '\' THEN 'supreme'
      WHEN i.id LIKE '%\_buff' ESCAPE '\' THEN 'buff'
      ELSE 'standard'
    END AS potion_tier,
    lower(COALESCE(i.type, '')) AS item_type
  FROM public.items i
  WHERE lower(COALESCE(i.type, '')) IN ('potion', 'catalyst')
     OR (lower(COALESCE(i.type, '')) = 'consumable' AND i.id LIKE 'box\_%' ESCAPE '\')
),
potion_recipes AS (
  SELECT
    pt.id AS output_item_id,
    CASE pt.potion_tier
      WHEN 'minor' THEN 1
      WHEN 'major' THEN 5
      WHEN 'supreme' THEN 10
      WHEN 'buff' THEN 3
      WHEN 'han' THEN 12
      WHEN 'box' THEN rc.required_level
      ELSE rc.required_level
    END AS required_level,
    CASE pt.potion_tier
      WHEN 'minor' THEN 120
      WHEN 'major' THEN 1800
      WHEN 'supreme' THEN 7200
      WHEN 'buff' THEN 900
      WHEN 'han' THEN 3600
      WHEN 'box' THEN rc.production_time_seconds
      ELSE rc.production_time_seconds
    END AS production_time_seconds,
    CASE pt.potion_tier
      WHEN 'supreme' THEN 0.80
      WHEN 'han' THEN 0.85
      ELSE rc.success_rate
    END AS success_rate,
    CASE pt.potion_tier
      WHEN 'minor' THEN 40
      WHEN 'major' THEN 120
      WHEN 'supreme' THEN 250
      WHEN 'buff' THEN 80
      WHEN 'han' THEN 200
      ELSE rc.xp_reward
    END AS xp_reward,
    CASE
      WHEN pt.id LIKE 'box\_%' ESCAPE '\' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_mining_' || pt.rarity, 'quantity', 8),
        jsonb_build_object('item_id', 'res_quarry_' || pt.rarity, 'quantity', 6),
        jsonb_build_object('item_id', 'catalyst_' || pt.rarity, 'quantity', 2)
      )
      WHEN pt.potion_tier = 'han' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_epic', 'quantity', 5),
        jsonb_build_object('item_id', 'res_holy_rare', 'quantity', 4),
        jsonb_build_object('item_id', 'catalyst_rare', 'quantity', 2)
      )
      WHEN pt.potion_tier = 'minor' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_common', 'quantity', 5),
        jsonb_build_object('item_id', 'catalyst_common', 'quantity', 1)
      )
      WHEN pt.potion_tier = 'major' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_rare', 'quantity', 4),
        jsonb_build_object('item_id', 'catalyst_rare', 'quantity', 2)
      )
      WHEN pt.potion_tier = 'supreme' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_epic', 'quantity', 4),
        jsonb_build_object('item_id', 'catalyst_epic', 'quantity', 2)
      )
      WHEN pt.potion_tier = 'buff' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_uncommon', 'quantity', 4),
        jsonb_build_object('item_id', 'catalyst_uncommon', 'quantity', 2)
      )
      WHEN pt.id LIKE 'detox\_minor' ESCAPE '\' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_uncommon', 'quantity', 4),
        jsonb_build_object('item_id', 'catalyst_uncommon', 'quantity', 2)
      )
      WHEN pt.id LIKE 'detox\_major' ESCAPE '\' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_rare', 'quantity', 5),
        jsonb_build_object('item_id', 'catalyst_rare', 'quantity', 2)
      )
      WHEN pt.id LIKE 'detox\_supreme' ESCAPE '\' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_epic', 'quantity', 5),
        jsonb_build_object('item_id', 'catalyst_epic', 'quantity', 3)
      )
      WHEN pt.item_type = 'catalyst' THEN jsonb_build_array(
        jsonb_build_object('item_id', 'res_mining_' || pt.rarity, 'quantity', 8),
        jsonb_build_object('item_id', 'res_quarry_' || pt.rarity, 'quantity', 5)
      )
      ELSE jsonb_build_array(
        jsonb_build_object('item_id', 'res_herb_common', 'quantity', 4),
        jsonb_build_object('item_id', 'catalyst_common', 'quantity', 1)
      )
    END AS ingredients,
    CASE
      WHEN pt.id LIKE 'box\_%' ESCAPE '\' THEN rc.gold_cost * 2
      WHEN pt.potion_tier = 'han' THEN 500000
      WHEN pt.potion_tier = 'supreme' THEN rc.gold_cost
      WHEN pt.potion_tier = 'major' THEN rc.gold_cost / 2
      ELSE rc.gold_cost / 5
    END AS gold_cost,
    CASE
      WHEN pt.id LIKE 'box\_%' ESCAPE '\' THEN 'consumable_box'
      WHEN pt.item_type = 'catalyst' THEN 'catalyst'
      ELSE 'potion'
    END AS recipe_type,
    CASE
      WHEN pt.id LIKE 'box\_%' ESCAPE '\' THEN 'workbench'
      WHEN pt.potion_tier = 'han' THEN 'herb_garden'
      ELSE 'herb_garden'
    END AS facility_type
  FROM potion_targets pt
  JOIN rarity_cfg rc ON rc.rarity = pt.rarity
),
rune_targets AS (
  SELECT *
  FROM (VALUES
    ('rune_basic', 10, 180, 0.95::numeric, 50, 50000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_common', 'quantity', 5),
        jsonb_build_object('item_id', 'res_holy_common', 'quantity', 2)
      )),
    ('rune_advanced', 15, 600, 0.92::numeric, 100, 200000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_uncommon', 'quantity', 4),
        jsonb_build_object('item_id', 'res_holy_uncommon', 'quantity', 2)
      )),
    ('rune_superior', 25, 1800, 0.88::numeric, 150, 500000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_rare', 'quantity', 4),
        jsonb_build_object('item_id', 'catalyst_rare', 'quantity', 1)
      )),
    ('rune_protection', 35, 3600, 0.82::numeric, 220, 1200000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_epic', 'quantity', 4),
        jsonb_build_object('item_id', 'res_shadow_epic', 'quantity', 2)
      )),
    ('rune_blessed', 35, 3600, 0.82::numeric, 220, 1200000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_epic', 'quantity', 3),
        jsonb_build_object('item_id', 'res_holy_epic', 'quantity', 3)
      )),
    ('rune_legendary', 45, 7200, 0.70::numeric, 300, 2500000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_legendary', 'quantity', 3),
        jsonb_build_object('item_id', 'catalyst_legendary', 'quantity', 1)
      ))
  ) AS t(output_item_id, required_level, production_time_seconds, success_rate, xp_reward, gold_cost, ingredients)
),
scroll_targets AS (
  SELECT *
  FROM (VALUES
    ('scroll_upgrade_low', 5, 900, 0.95::numeric, 80, 50000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_common', 'quantity', 3),
        jsonb_build_object('item_id', 'res_mining_common', 'quantity', 5)
      )),
    ('scroll_upgrade_middle', 15, 3600, 0.88::numeric, 180, 250000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_rare', 'quantity', 2),
        jsonb_build_object('item_id', 'res_mining_rare', 'quantity', 4)
      )),
    ('scroll_upgrade_high', 25, 7200, 0.75::numeric, 320, 1000000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_epic', 'quantity', 2),
        jsonb_build_object('item_id', 'res_mining_epic', 'quantity', 3)
      )),
    ('scroll_breakage_protect', 20, 5400, 0.80::numeric, 250, 750000,
      jsonb_build_array(
        jsonb_build_object('item_id', 'res_rune_rare', 'quantity', 3),
        jsonb_build_object('item_id', 'res_holy_rare', 'quantity', 2)
      ))
  ) AS t(output_item_id, required_level, production_time_seconds, success_rate, xp_reward, gold_cost, ingredients)
),
all_new AS (
  SELECT output_item_id, required_level, production_time_seconds, success_rate, xp_reward, ingredients, gold_cost, recipe_type, facility_type
  FROM potion_recipes
  UNION ALL
  SELECT output_item_id, required_level, production_time_seconds, success_rate, xp_reward, ingredients, gold_cost, 'rune', 'rune_mine'
  FROM rune_targets
  UNION ALL
  SELECT output_item_id, required_level, production_time_seconds, success_rate, xp_reward, ingredients, gold_cost, 'scroll', 'rune_mine'
  FROM scroll_targets
)
INSERT INTO public.crafting_recipes (
  output_item_id,
  required_level,
  production_time_seconds,
  success_rate,
  xp_reward,
  ingredients,
  item_id,
  recipe_type,
  facility_type,
  materials,
  gold_cost
)
SELECT
  n.output_item_id,
  n.required_level,
  n.production_time_seconds,
  n.success_rate,
  n.xp_reward,
  n.ingredients,
  n.output_item_id,
  n.recipe_type,
  n.facility_type,
  n.ingredients,
  n.gold_cost
FROM all_new n
JOIN public.items i ON i.id = n.output_item_id
WHERE NOT EXISTS (
  SELECT 1 FROM public.crafting_recipes cr WHERE cr.output_item_id = n.output_item_id
);

COMMIT;
