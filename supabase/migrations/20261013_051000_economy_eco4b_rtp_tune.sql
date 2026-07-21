-- ECO-4b: Relative pool RTP tuning (non-uniform weights — uniform scale does not move EV)

BEGIN;

UPDATE public.loot_box_drop_entries e
SET weight = e.weight * CASE lower(COALESCE(i.rarity, 'common'))
  WHEN 'mythic' THEN 4.0
  WHEN 'legendary' THEN 3.5
  WHEN 'epic' THEN 3.0
  WHEN 'rare' THEN 1.8
  ELSE 1.0
END,
updated_at = now()
FROM public.items i, public.loot_box_configs b
WHERE e.item_id = i.id AND e.box_id = b.id
  AND b.is_active AND b.currency_type = 'gems';

UPDATE public.loot_box_drop_entries e
SET
  weight = e.weight * (1.0 + (COALESCE(i.vendor_sell_price, 0)::numeric / 15000.0)),
  max_quantity = GREATEST(
    e.max_quantity,
    CASE
      WHEN b.theme_id IN ('starter', 'consumable') THEN 5
      WHEN b.theme_id = 'craft' AND lower(COALESCE(i.rarity, 'common')) IN ('common', 'uncommon') THEN 6
      ELSE e.max_quantity
    END
  ),
  updated_at = now()
FROM public.items i, public.loot_box_configs b
WHERE e.item_id = i.id AND e.box_id = b.id
  AND b.is_active AND b.currency_type = 'gold';

DELETE FROM public.loot_box_drop_entries e
USING public.loot_box_configs b
WHERE e.box_id = b.id AND b.theme_id = 'starter' AND b.is_active;

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured, is_active)
SELECT b.id, s.item_id, s.weight, s.min_quantity, s.max_quantity, s.show_in_preview, s.is_featured, true
FROM public.loot_box_configs b
JOIN public.loot_box_drop_entries s ON s.box_id = 'box_28' AND s.is_active
WHERE b.theme_id = 'starter' AND b.is_active;

UPDATE public.loot_box_drop_entries e
SET
  weight = e.weight * CASE lower(COALESCE(i.rarity, 'common'))
    WHEN 'epic' THEN 15
    WHEN 'rare' THEN 10
    WHEN 'uncommon' THEN 3
    ELSE 0.2
  END,
  max_quantity = GREATEST(
    e.max_quantity,
    CASE lower(COALESCE(i.rarity, 'common'))
      WHEN 'common' THEN 10
      WHEN 'uncommon' THEN 8
      ELSE 4
    END
  ),
  updated_at = now()
FROM public.items i, public.loot_box_configs b
WHERE e.item_id = i.id AND e.box_id = b.id AND b.theme_id = 'craft' AND b.is_active;

UPDATE public.loot_box_drop_entries e
SET weight = e.weight * CASE
  WHEN COALESCE(i.vendor_sell_price, 0) >= 15000 THEN 15
  WHEN COALESCE(i.vendor_sell_price, 0) >= 5000 THEN 8
  ELSE 0.15
END,
updated_at = now()
FROM public.items i, public.loot_box_configs b
WHERE e.item_id = i.id AND e.box_id = b.id AND b.theme_id = 'mid_gear' AND b.is_active;

UPDATE public.loot_box_drop_entries e
SET weight = e.weight * CASE lower(COALESCE(i.rarity, 'common'))
  WHEN 'legendary' THEN 12
  WHEN 'epic' THEN 9
  WHEN 'rare' THEN 3
  ELSE 0.25
END,
updated_at = now()
FROM public.items i, public.loot_box_configs b
WHERE e.item_id = i.id AND e.box_id = b.id
  AND b.currency_type = 'gems'
  AND b.theme_id IN ('weapon', 'armor', 'jewelry', 'dungeon', 'epic_weapon', 'epic_armor')
  AND b.is_active;

COMMIT;
