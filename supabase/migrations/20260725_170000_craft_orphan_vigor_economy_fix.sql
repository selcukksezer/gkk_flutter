-- Craft orphan coverage + vigor recipe split + craft→vendor economy nerfs.
-- Reversible UPDATEs only (no DROP/TRUNCATE/DELETE).

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Vigor: restore distinct minor vs major recipes (apiary lows for minor)
-- ---------------------------------------------------------------------------
UPDATE public.crafting_recipes
SET
  required_level = 1,
  production_time_seconds = 1800,
  success_rate = 0.95,
  xp_reward = 90,
  gold_cost = 25000,
  ingredients = '[
    {"item_id":"res_apiary_common","quantity":4},
    {"item_id":"res_apiary_uncommon","quantity":2},
    {"item_id":"res_herb_common","quantity":3}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_apiary_common","quantity":4},
    {"item_id":"res_apiary_uncommon","quantity":2},
    {"item_id":"res_herb_common","quantity":3}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'han_item_vigor_minor';

UPDATE public.crafting_recipes
SET
  required_level = 15,
  production_time_seconds = 7200,
  success_rate = 0.85,
  xp_reward = 200,
  gold_cost = 220000,
  ingredients = '[
    {"item_id":"res_apiary_rare","quantity":4},
    {"item_id":"res_apiary_legendary","quantity":2},
    {"item_id":"res_herb_rare","quantity":3},
    {"item_id":"catalyst_rare","quantity":1}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_apiary_rare","quantity":4},
    {"item_id":"res_apiary_legendary","quantity":2},
    {"item_id":"res_herb_rare","quantity":3},
    {"item_id":"catalyst_rare","quantity":1}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'han_item_vigor_major';

-- ---------------------------------------------------------------------------
-- 2) Wire mushroom orphans → detox / han
-- ---------------------------------------------------------------------------
UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_herb_common","quantity":4},
    {"item_id":"res_mushroom_uncommon","quantity":3},
    {"item_id":"catalyst_common","quantity":1}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_common","quantity":4},
    {"item_id":"res_mushroom_uncommon","quantity":3},
    {"item_id":"catalyst_common","quantity":1}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'detox_minor';

UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_herb_rare","quantity":4},
    {"item_id":"res_mushroom_rare","quantity":3},
    {"item_id":"catalyst_rare","quantity":2}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_rare","quantity":4},
    {"item_id":"res_mushroom_rare","quantity":3},
    {"item_id":"catalyst_rare","quantity":2}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'detox_major';

UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_herb_epic","quantity":4},
    {"item_id":"res_mushroom_epic","quantity":3},
    {"item_id":"catalyst_epic","quantity":2}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_epic","quantity":4},
    {"item_id":"res_mushroom_epic","quantity":3},
    {"item_id":"catalyst_epic","quantity":2}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'detox_supreme';

UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_shadow_epic","quantity":4},
    {"item_id":"res_shadow_common","quantity":3},
    {"item_id":"res_mushroom_legendary","quantity":2}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_shadow_epic","quantity":4},
    {"item_id":"res_shadow_common","quantity":3},
    {"item_id":"res_mushroom_legendary","quantity":2}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'han_item_shadow_brew';

UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_herb_legendary","quantity":4},
    {"item_id":"res_herb_mythic","quantity":2},
    {"item_id":"res_apiary_legendary","quantity":3},
    {"item_id":"res_apiary_mythic","quantity":2},
    {"item_id":"res_mushroom_mythic","quantity":2},
    {"item_id":"res_holy_common","quantity":3}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_legendary","quantity":4},
    {"item_id":"res_herb_mythic","quantity":2},
    {"item_id":"res_apiary_legendary","quantity":3},
    {"item_id":"res_apiary_mythic","quantity":2},
    {"item_id":"res_mushroom_mythic","quantity":2},
    {"item_id":"res_holy_common","quantity":3}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'han_item_restoration';

-- ---------------------------------------------------------------------------
-- 3) Wire time_well orphans → scrolls
-- ---------------------------------------------------------------------------
UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_rune_common","quantity":3},
    {"item_id":"res_mining_common","quantity":5},
    {"item_id":"res_time_common","quantity":3}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_rune_common","quantity":3},
    {"item_id":"res_mining_common","quantity":5},
    {"item_id":"res_time_common","quantity":3}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'scroll_upgrade_low';

UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_rune_rare","quantity":2},
    {"item_id":"res_mining_rare","quantity":4},
    {"item_id":"res_time_rare","quantity":3}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_rune_rare","quantity":2},
    {"item_id":"res_mining_rare","quantity":4},
    {"item_id":"res_time_rare","quantity":3}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'scroll_upgrade_middle';

UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_rune_epic","quantity":2},
    {"item_id":"res_mining_epic","quantity":3},
    {"item_id":"res_time_epic","quantity":3},
    {"item_id":"res_time_legendary","quantity":1}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_rune_epic","quantity":2},
    {"item_id":"res_mining_epic","quantity":3},
    {"item_id":"res_time_epic","quantity":3},
    {"item_id":"res_time_legendary","quantity":1}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'scroll_upgrade_high';

-- ---------------------------------------------------------------------------
-- 4) Buff potions: raise craft cost + wire time/apiary; nerf vendor sell
-- ---------------------------------------------------------------------------
UPDATE public.crafting_recipes
SET
  gold_cost = 90000,
  required_level = 5,
  production_time_seconds = 1800,
  ingredients = '[
    {"item_id":"res_herb_uncommon","quantity":5},
    {"item_id":"res_apiary_uncommon","quantity":2},
    {"item_id":"catalyst_uncommon","quantity":2},
    {"item_id":"res_time_common","quantity":2}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_uncommon","quantity":5},
    {"item_id":"res_apiary_uncommon","quantity":2},
    {"item_id":"catalyst_uncommon","quantity":2},
    {"item_id":"res_time_common","quantity":2}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id IN ('potion_attack_buff', 'potion_defense_buff');

UPDATE public.crafting_recipes
SET
  gold_cost = 110000,
  required_level = 5,
  production_time_seconds = 1800,
  ingredients = '[
    {"item_id":"res_herb_uncommon","quantity":5},
    {"item_id":"res_apiary_rare","quantity":2},
    {"item_id":"catalyst_rare","quantity":1},
    {"item_id":"res_time_uncommon","quantity":3}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_uncommon","quantity":5},
    {"item_id":"res_apiary_rare","quantity":2},
    {"item_id":"catalyst_rare","quantity":1},
    {"item_id":"res_time_uncommon","quantity":3}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'potion_luck_buff';

UPDATE public.crafting_recipes
SET
  gold_cost = 160000,
  required_level = 8,
  production_time_seconds = 3600,
  ingredients = '[
    {"item_id":"res_herb_rare","quantity":4},
    {"item_id":"res_time_uncommon","quantity":4},
    {"item_id":"res_time_rare","quantity":2},
    {"item_id":"catalyst_rare","quantity":2}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_rare","quantity":4},
    {"item_id":"res_time_uncommon","quantity":4},
    {"item_id":"res_time_rare","quantity":2},
    {"item_id":"catalyst_rare","quantity":2}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'potion_xp_buff';

UPDATE public.items
SET
  vendor_sell_price = CASE id
    WHEN 'potion_attack_buff' THEN 12000
    WHEN 'potion_defense_buff' THEN 12000
    WHEN 'potion_luck_buff' THEN 15000
    WHEN 'potion_xp_buff' THEN 22000
    ELSE vendor_sell_price
  END,
  updated_at = NOW()
WHERE id IN (
  'potion_attack_buff',
  'potion_defense_buff',
  'potion_luck_buff',
  'potion_xp_buff'
);

-- ---------------------------------------------------------------------------
-- 5) Energy potions: wire apiary tiers
-- ---------------------------------------------------------------------------
UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_herb_common","quantity":4},
    {"item_id":"res_apiary_common","quantity":3},
    {"item_id":"catalyst_common","quantity":1}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_common","quantity":4},
    {"item_id":"res_apiary_common","quantity":3},
    {"item_id":"catalyst_common","quantity":1}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'potion_energy_minor';

UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_herb_rare","quantity":3},
    {"item_id":"res_apiary_rare","quantity":2},
    {"item_id":"catalyst_rare","quantity":2}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_rare","quantity":3},
    {"item_id":"res_apiary_rare","quantity":2},
    {"item_id":"catalyst_rare","quantity":2}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'potion_energy_major';

UPDATE public.crafting_recipes
SET
  ingredients = '[
    {"item_id":"res_herb_epic","quantity":3},
    {"item_id":"res_apiary_legendary","quantity":2},
    {"item_id":"catalyst_epic","quantity":2}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_herb_epic","quantity":3},
    {"item_id":"res_apiary_legendary","quantity":2},
    {"item_id":"catalyst_epic","quantity":2}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'potion_energy_supreme';

-- ---------------------------------------------------------------------------
-- 6) Catalysts: absorb high-tier orphans + close craft→sell profit
-- ---------------------------------------------------------------------------
UPDATE public.crafting_recipes
SET
  gold_cost = 250000,
  ingredients = '[
    {"item_id":"res_mining_epic","quantity":8},
    {"item_id":"res_quarry_epic","quantity":5}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_mining_epic","quantity":8},
    {"item_id":"res_quarry_epic","quantity":5}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'catalyst_epic';

UPDATE public.crafting_recipes
SET
  gold_cost = 2500000,
  ingredients = '[
    {"item_id":"res_mining_legendary","quantity":6},
    {"item_id":"res_quarry_legendary","quantity":4},
    {"item_id":"res_clay_legendary","quantity":2},
    {"item_id":"res_sand_legendary","quantity":2},
    {"item_id":"res_elemental_legendary","quantity":2},
    {"item_id":"res_shadow_legendary","quantity":2}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_mining_legendary","quantity":6},
    {"item_id":"res_quarry_legendary","quantity":4},
    {"item_id":"res_clay_legendary","quantity":2},
    {"item_id":"res_sand_legendary","quantity":2},
    {"item_id":"res_elemental_legendary","quantity":2},
    {"item_id":"res_shadow_legendary","quantity":2}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'catalyst_legendary';

UPDATE public.crafting_recipes
SET
  gold_cost = 10000000,
  ingredients = '[
    {"item_id":"res_mining_mythic","quantity":5},
    {"item_id":"res_quarry_mythic","quantity":4},
    {"item_id":"res_clay_mythic","quantity":2},
    {"item_id":"res_sand_mythic","quantity":2},
    {"item_id":"res_elemental_mythic","quantity":2},
    {"item_id":"res_shadow_mythic","quantity":2},
    {"item_id":"res_time_mythic","quantity":1},
    {"item_id":"res_farming_mythic","quantity":1},
    {"item_id":"res_lumber_mythic","quantity":1}
  ]'::jsonb,
  materials = '[
    {"item_id":"res_mining_mythic","quantity":5},
    {"item_id":"res_quarry_mythic","quantity":4},
    {"item_id":"res_clay_mythic","quantity":2},
    {"item_id":"res_sand_mythic","quantity":2},
    {"item_id":"res_elemental_mythic","quantity":2},
    {"item_id":"res_shadow_mythic","quantity":2},
    {"item_id":"res_time_mythic","quantity":1},
    {"item_id":"res_farming_mythic","quantity":1},
    {"item_id":"res_lumber_mythic","quantity":1}
  ]'::jsonb,
  updated_at = NOW()
WHERE output_item_id = 'catalyst_mythic';

UPDATE public.items
SET
  vendor_sell_price = CASE id
    WHEN 'catalyst_legendary' THEN 1200000
    WHEN 'catalyst_mythic' THEN 5500000
    WHEN 'catalyst_epic' THEN 280000
    ELSE vendor_sell_price
  END,
  updated_at = NOW()
WHERE id IN ('catalyst_legendary', 'catalyst_mythic', 'catalyst_epic');

COMMIT;
