-- ECO-2 P0: Per-theme curated loot pools (replace 317-item shared CROSS JOIN dump)
-- 8 gem themes + 4 gold themes; featured chase weights; honest varying preview %

BEGIN;

ALTER TABLE public.loot_box_configs
  ADD COLUMN IF NOT EXISTS theme_id TEXT;

ALTER TABLE public.loot_box_drop_entries
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT FALSE;

-- Gem boxes 1–25 → 8 rotating themes; gold 26–50 → 4 themes
UPDATE public.loot_box_configs b
SET theme_id = CASE
  WHEN b.display_order BETWEEN 1 AND 25 THEN (
    CASE (b.display_order - 1) % 8
      WHEN 0 THEN 'weapon'
      WHEN 1 THEN 'armor'
      WHEN 2 THEN 'jewelry'
      WHEN 3 THEN 'material'
      WHEN 4 THEN 'dungeon'
      WHEN 5 THEN 'epic_weapon'
      WHEN 6 THEN 'epic_armor'
      WHEN 7 THEN 'prestige'
    END
  )
  WHEN b.display_order BETWEEN 26 AND 50 THEN (
    CASE (b.display_order - 26) % 4
      WHEN 0 THEN 'starter'
      WHEN 1 THEN 'craft'
      WHEN 2 THEN 'consumable'
      WHEN 3 THEN 'mid_gear'
    END
  )
  ELSE theme_id
END
WHERE b.id LIKE 'box\_%' ESCAPE '\'
  AND b.display_order BETWEEN 1 AND 50;

UPDATE public.loot_box_configs
SET description = CASE theme_id
  WHEN 'weapon' THEN 'Silah odaklı kasa — efsane silah chase.'
  WHEN 'armor' THEN 'Zırh parçaları — set tamamlama.'
  WHEN 'jewelry' THEN 'Yüzük ve kolye — nadir aksesuar.'
  WHEN 'material' THEN 'Malzeme ve craft kaynağı.'
  WHEN 'dungeon' THEN 'Zindan ganimeti — orta tier gear.'
  WHEN 'epic_weapon' THEN 'Epik+ silahlar — yüksek chase.'
  WHEN 'epic_armor' THEN 'Epik+ zırh — güçlü parçalar.'
  WHEN 'prestige' THEN 'Prestij kasası — efsane/mythic chase.'
  WHEN 'starter' THEN 'Başlangıç paketi — erken oyun.'
  WHEN 'craft' THEN 'Usta malzemeleri — üretim odaklı.'
  WHEN 'consumable' THEN 'İksir ve tüketilebilir.'
  WHEN 'mid_gear' THEN 'Orta seviye karışık ekipman.'
  ELSE description
END
WHERE theme_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.populate_curated_loot_pool(p_box_id TEXT, p_theme_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM public.loot_box_drop_entries WHERE box_id = p_box_id;

  IF p_theme_id = 'weapon' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (
          PARTITION BY lower(COALESCE(i.rarity, 'common'))
          ORDER BY COALESCE(i.base_price, 0) DESC, i.id
        ) AS rn
      FROM public.items i
      WHERE lower(COALESCE(i.type, '')) = 'weapon'
        AND lower(COALESCE(i.equip_slot, '')) = 'weapon'
        AND lower(COALESCE(i.rarity, 'common')) IN (
          'common', 'uncommon', 'rare', 'epic', 'legendary'
        )
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT
        id,
        rarity,
        rn,
        (rarity = 'legendary' AND rn = 1) AS feat,
        CASE rarity
          WHEN 'common' THEN rn <= 6
          WHEN 'uncommon' THEN rn <= 5
          WHEN 'rare' THEN rn <= 4
          WHEN 'epic' THEN rn <= 3
          WHEN 'legendary' THEN rn <= 2
          ELSE FALSE
        END AS ok
      FROM ranked
    )
    SELECT
      p_box_id,
      id,
      CASE
        WHEN feat THEN 2.20
        WHEN rarity = 'legendary' THEN 0.07
        WHEN rarity = 'epic' THEN 0.42
        WHEN rarity = 'rare' THEN 0.90
        WHEN rarity = 'uncommon' THEN 1.25
        ELSE 1.40
      END,
      1,
      1,
      rarity IN ('rare', 'epic', 'legendary'),
      feat
    FROM picked
    WHERE ok;

  ELSIF p_theme_id = 'armor' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (
          PARTITION BY lower(COALESCE(i.rarity, 'common'))
          ORDER BY COALESCE(i.base_price, 0) DESC, i.id
        ) AS rn
      FROM public.items i
      WHERE lower(COALESCE(i.type, '')) = 'armor'
        AND lower(COALESCE(i.equip_slot, '')) IN (
          'chest', 'head', 'legs', 'boots', 'gloves', 'helmet'
        )
        AND lower(COALESCE(i.rarity, 'common')) IN (
          'common', 'uncommon', 'rare', 'epic', 'legendary'
        )
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT
        id,
        rarity,
        (rarity = 'legendary' AND rn = 1) AS feat,
        CASE rarity
          WHEN 'common' THEN rn <= 6
          WHEN 'uncommon' THEN rn <= 5
          WHEN 'rare' THEN rn <= 4
          WHEN 'epic' THEN rn <= 3
          WHEN 'legendary' THEN rn <= 2
          ELSE FALSE
        END AS ok
      FROM ranked
    )
    SELECT
      p_box_id,
      id,
      CASE
        WHEN feat THEN 2.00
        WHEN rarity = 'legendary' THEN 0.08
        WHEN rarity = 'epic' THEN 0.45
        WHEN rarity = 'rare' THEN 0.95
        WHEN rarity = 'uncommon' THEN 1.30
        ELSE 1.45
      END,
      1,
      1,
      rarity IN ('rare', 'epic', 'legendary'),
      feat
    FROM picked
    WHERE ok;

  ELSIF p_theme_id = 'jewelry' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (
          PARTITION BY lower(COALESCE(i.rarity, 'common'))
          ORDER BY COALESCE(i.base_price, 0) DESC, i.id
        ) AS rn
      FROM public.items i
      WHERE lower(COALESCE(i.equip_slot, '')) IN ('ring', 'necklace')
        AND lower(COALESCE(i.rarity, 'common')) IN (
          'uncommon', 'rare', 'epic', 'legendary', 'mythic'
        )
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT
        id,
        rarity,
        (rarity IN ('mythic', 'legendary') AND rn = 1) AS feat,
        CASE rarity
          WHEN 'uncommon' THEN rn <= 4
          WHEN 'rare' THEN rn <= 5
          WHEN 'epic' THEN rn <= 4
          WHEN 'legendary' THEN rn <= 3
          WHEN 'mythic' THEN rn <= 2
          ELSE FALSE
        END AS ok
      FROM ranked
    )
    SELECT
      p_box_id,
      id,
      CASE
        WHEN feat THEN 2.50
        WHEN rarity = 'mythic' THEN 0.05
        WHEN rarity = 'legendary' THEN 0.12
        WHEN rarity = 'epic' THEN 0.55
        WHEN rarity = 'rare' THEN 1.05
        ELSE 1.35
      END,
      1,
      1,
      rarity IN ('rare', 'epic', 'legendary', 'mythic'),
      feat
    FROM picked
    WHERE ok;

  ELSIF p_theme_id = 'material' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (
          PARTITION BY lower(COALESCE(i.rarity, 'common'))
          ORDER BY COALESCE(i.base_price, 0) DESC, i.id
        ) AS rn
      FROM public.items i
      WHERE (
          lower(COALESCE(i.type, '')) IN ('material', 'consumable', 'scroll', 'rune')
          OR i.id ILIKE 'mat\_%' ESCAPE '\'
          OR i.id ILIKE '%rune%'
          OR i.id ILIKE '%scroll%'
        )
        AND lower(COALESCE(i.rarity, 'common')) IN (
          'common', 'uncommon', 'rare', 'epic'
        )
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT
        id,
        rarity,
        (rarity = 'epic' AND rn = 1) AS feat,
        CASE rarity
          WHEN 'common' THEN rn <= 8
          WHEN 'uncommon' THEN rn <= 6
          WHEN 'rare' THEN rn <= 5
          WHEN 'epic' THEN rn <= 3
          ELSE FALSE
        END AS ok
      FROM ranked
    )
    SELECT
      p_box_id,
      id,
      CASE
        WHEN feat THEN 1.80
        WHEN rarity = 'epic' THEN 0.35
        WHEN rarity = 'rare' THEN 0.85
        WHEN rarity = 'uncommon' THEN 1.20
        ELSE 1.50
      END,
      1,
      CASE WHEN rarity IN ('common', 'uncommon') THEN 3 ELSE 1 END,
      rarity IN ('rare', 'epic'),
      feat
    FROM picked
    WHERE ok;

  ELSIF p_theme_id = 'dungeon' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (
          ORDER BY COALESCE(i.base_price, 0) DESC, i.id
        ) AS rn
      FROM public.items i
      WHERE (
          lower(COALESCE(i.type, '')) IN ('weapon', 'armor')
          OR lower(COALESCE(i.equip_slot, '')) IN (
            'weapon', 'chest', 'head', 'legs', 'boots', 'gloves', 'helmet'
          )
        )
        AND lower(COALESCE(i.rarity, 'common')) IN (
          'uncommon', 'rare', 'epic', 'legendary'
        )
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT id, rarity, rn, (rn = 1) AS feat
      FROM ranked
      WHERE rn <= 28
    )
    SELECT
      p_box_id,
      id,
      CASE
        WHEN feat THEN 2.10
        WHEN rarity = 'legendary' THEN 0.10
        WHEN rarity = 'epic' THEN 0.50
        WHEN rarity = 'rare' THEN 1.00
        ELSE 1.25
      END,
      1,
      1,
      rarity IN ('rare', 'epic', 'legendary'),
      feat
    FROM picked;

  ELSIF p_theme_id = 'epic_weapon' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (
          PARTITION BY lower(COALESCE(i.rarity, 'common'))
          ORDER BY COALESCE(i.base_price, 0) DESC, i.id
        ) AS rn
      FROM public.items i
      WHERE lower(COALESCE(i.type, '')) = 'weapon'
        AND lower(COALESCE(i.equip_slot, '')) = 'weapon'
        AND lower(COALESCE(i.rarity, 'common')) IN (
          'rare', 'epic', 'legendary', 'mythic'
        )
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT
        id,
        rarity,
        (rarity IN ('legendary', 'mythic') AND rn = 1) AS feat,
        CASE rarity
          WHEN 'rare' THEN rn <= 4
          WHEN 'epic' THEN rn <= 4
          WHEN 'legendary' THEN rn <= 3
          WHEN 'mythic' THEN rn <= 2
          ELSE FALSE
        END AS ok
      FROM ranked
    )
    SELECT
      p_box_id,
      id,
      CASE
        WHEN feat THEN 2.80
        WHEN rarity = 'mythic' THEN 0.06
        WHEN rarity = 'legendary' THEN 0.15
        WHEN rarity = 'epic' THEN 0.60
        ELSE 1.05
      END,
      1,
      1,
      TRUE,
      feat
    FROM picked
    WHERE ok;

  ELSIF p_theme_id = 'epic_armor' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (
          PARTITION BY lower(COALESCE(i.rarity, 'common'))
          ORDER BY COALESCE(i.base_price, 0) DESC, i.id
        ) AS rn
      FROM public.items i
      WHERE lower(COALESCE(i.type, '')) = 'armor'
        AND lower(COALESCE(i.equip_slot, '')) IN (
          'chest', 'head', 'legs', 'boots', 'gloves', 'helmet'
        )
        AND lower(COALESCE(i.rarity, 'common')) IN (
          'rare', 'epic', 'legendary', 'mythic'
        )
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT
        id,
        rarity,
        (rarity IN ('legendary', 'mythic') AND rn = 1) AS feat,
        CASE rarity
          WHEN 'rare' THEN rn <= 4
          WHEN 'epic' THEN rn <= 4
          WHEN 'legendary' THEN rn <= 3
          WHEN 'mythic' THEN rn <= 2
          ELSE FALSE
        END AS ok
      FROM ranked
    )
    SELECT
      p_box_id,
      id,
      CASE
        WHEN feat THEN 2.60
        WHEN rarity = 'mythic' THEN 0.06
        WHEN rarity = 'legendary' THEN 0.14
        WHEN rarity = 'epic' THEN 0.58
        ELSE 1.00
      END,
      1,
      1,
      TRUE,
      feat
    FROM picked
    WHERE ok;

  ELSIF p_theme_id = 'prestige' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (
          ORDER BY COALESCE(i.base_price, 0) DESC, i.id
        ) AS rn
      FROM public.items i
      WHERE lower(COALESCE(i.rarity, 'common')) IN ('legendary', 'mythic')
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT id, rarity, rn, (rn <= 2) AS feat
      FROM ranked
      WHERE rn <= 14
    )
    SELECT
      p_box_id,
      id,
      CASE WHEN feat THEN 3.20 WHEN rarity = 'mythic' THEN 0.12 ELSE 0.25 END,
      1,
      1,
      TRUE,
      feat
    FROM picked;

  ELSIF p_theme_id = 'starter' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH gear AS (
      SELECT i.id, lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (ORDER BY i.id) AS rn
      FROM public.items i
      WHERE lower(COALESCE(i.rarity, 'common')) IN ('common', 'uncommon')
        AND (
          lower(COALESCE(i.type, '')) IN ('weapon', 'armor', 'consumable')
          OR i.id ILIKE '%potion%'
        )
        AND COALESCE(i.is_visible, TRUE)
      LIMIT 18
    )
    SELECT
      p_box_id,
      id,
      CASE rarity WHEN 'uncommon' THEN 1.10 ELSE 1.45 END,
      1,
      CASE WHEN id ILIKE '%potion%' THEN 3 ELSE 1 END,
      rarity = 'uncommon',
      FALSE
    FROM gear;

  ELSIF p_theme_id = 'craft' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH mats AS (
      SELECT i.id, lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (ORDER BY COALESCE(i.base_price, 0) DESC, i.id) AS rn
      FROM public.items i
      WHERE (
          lower(COALESCE(i.type, '')) IN ('material', 'scroll', 'rune')
          OR i.id ILIKE 'mat\_%' ESCAPE '\'
        )
        AND COALESCE(i.is_visible, TRUE)
      LIMIT 22
    )
    SELECT
      p_box_id,
      id,
      CASE rarity
        WHEN 'epic' THEN 0.40
        WHEN 'rare' THEN 0.90
        WHEN 'uncommon' THEN 1.20
        ELSE 1.50
      END,
      1,
      CASE WHEN rarity IN ('common', 'uncommon') THEN 5 ELSE 2 END,
      rarity IN ('rare', 'epic'),
      rn = 1
    FROM mats;

  ELSIF p_theme_id = 'consumable' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH cons AS (
      SELECT i.id, lower(COALESCE(i.rarity, 'common')) AS rarity
      FROM public.items i
      WHERE (
          lower(COALESCE(i.type, '')) = 'consumable'
          OR i.id ILIKE '%potion%'
          OR i.id ILIKE '%elixir%'
        )
        AND COALESCE(i.is_visible, TRUE)
      LIMIT 16
    )
    SELECT
      p_box_id,
      id,
      1.35,
      1,
      5,
      rarity IN ('rare', 'uncommon'),
      FALSE
    FROM cons;

  ELSIF p_theme_id = 'mid_gear' THEN
    INSERT INTO public.loot_box_drop_entries (
      box_id, item_id, weight, min_quantity, max_quantity, show_in_preview, is_featured
    )
    WITH ranked AS (
      SELECT
        i.id,
        lower(COALESCE(i.rarity, 'common')) AS rarity,
        ROW_NUMBER() OVER (ORDER BY COALESCE(i.base_price, 0) DESC, i.id) AS rn
      FROM public.items i
      WHERE lower(COALESCE(i.rarity, 'common')) IN ('rare', 'epic')
        AND (
          lower(COALESCE(i.type, '')) IN ('weapon', 'armor')
          OR lower(COALESCE(i.equip_slot, '')) IN (
            'weapon', 'chest', 'head', 'legs', 'boots', 'gloves', 'helmet'
          )
        )
        AND COALESCE(i.is_visible, TRUE)
    ),
    picked AS (
      SELECT id, rarity, (rn = 1) AS feat
      FROM ranked
      WHERE rn <= 24
    )
    SELECT
      p_box_id,
      id,
      CASE WHEN feat THEN 1.90 WHEN rarity = 'epic' THEN 0.55 ELSE 1.05 END,
      1,
      1,
      TRUE,
      feat
    FROM picked;

  END IF;
END;
$$;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT id, theme_id
    FROM public.loot_box_configs
    WHERE theme_id IS NOT NULL
      AND display_order BETWEEN 1 AND 50
      AND id LIKE 'box\_%' ESCAPE '\'
  LOOP
    PERFORM public.populate_curated_loot_pool(r.id, r.theme_id);
  END LOOP;
END $$;

-- Preview RPC: featured first, honest %, is_featured flag
CREATE OR REPLACE FUNCTION public.get_loot_box_drops(p_box_id text)
 RETURNS TABLE(
   item_id text,
   item_name text,
   icon text,
   rarity text,
   min_quantity integer,
   max_quantity integer,
   weight numeric,
   drop_rate numeric,
   is_featured boolean
 )
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH pool AS (
    SELECT COALESCE(SUM(e.weight), 0)::numeric AS total_weight
    FROM public.loot_box_drop_entries e
    WHERE e.box_id = p_box_id
      AND e.is_active = TRUE
  )
  SELECT
    e.item_id,
    i.name AS item_name,
    i.icon,
    COALESCE(i.rarity, 'common') AS rarity,
    e.min_quantity,
    e.max_quantity,
    e.weight,
    (e.weight / NULLIF(pool.total_weight, 0) * 100)::numeric AS drop_rate,
    COALESCE(e.is_featured, FALSE) AS is_featured
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  CROSS JOIN pool
  WHERE e.box_id = p_box_id
    AND e.is_active = TRUE
    AND e.show_in_preview = TRUE
  ORDER BY e.is_featured DESC, drop_rate DESC, item_name ASC;
$function$;

CREATE OR REPLACE FUNCTION public.get_loot_boxes_with_stats()
RETURNS TABLE (
  id TEXT,
  name TEXT,
  description TEXT,
  currency_type TEXT,
  price INTEGER,
  reward_multiplier NUMERIC,
  art_asset TEXT,
  drop_count INTEGER,
  total_weight NUMERIC,
  jackpot_rate NUMERIC,
  display_order INTEGER,
  theme_id TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT
    b.id,
    b.name,
    b.description,
    b.currency_type,
    b.price,
    b.reward_multiplier,
    b.art_asset,
    COUNT(e.id)::INTEGER AS drop_count,
    COALESCE(SUM(e.weight), 0)::NUMERIC AS total_weight,
    COALESCE(
      SUM(e.weight) FILTER (
        WHERE COALESCE(i.rarity, 'common') IN ('legendary', 'mythic')
      ) / NULLIF(SUM(e.weight), 0),
      0
    )::NUMERIC AS jackpot_rate,
    b.display_order,
    b.theme_id
  FROM public.loot_box_configs b
  LEFT JOIN public.loot_box_drop_entries e
    ON e.box_id = b.id AND e.is_active = TRUE
  LEFT JOIN public.items i ON i.id = e.item_id
  WHERE b.is_active = TRUE
  GROUP BY b.id
  ORDER BY b.display_order ASC, b.id ASC;
$$;

COMMIT;
