-- Equip NPC sell: weapon/armor at least 6× prior +0 price; sell scales with enhancement
-- like combat stats (×(1 + enh×0.15)). Materials / potions / craft mats unchanged.

BEGIN;

CREATE OR REPLACE FUNCTION public.compute_npc_sell_price(
  p_item_id text,
  p_rarity text,
  p_item_type text,
  p_required_level int,
  p_base_price int,
  p_table_sell_price int,
  p_attack int,
  p_defense int,
  p_power int,
  p_luck int,
  p_energy_restore int,
  p_health_restore int,
  p_is_tradeable boolean,
  p_is_han_only boolean,
  p_enhancement_level int DEFAULT 0
)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public, pg_temp'
AS $$
DECLARE
  v_level int;
  v_stat int;
  v_worth int;
  v_shop_cap int;
  v_sell_pct numeric;
  v_shop_ref int;
  v_sell int;
  v_max_sell int;
  v_enh int;
  v_type text := lower(COALESCE(p_item_type, 'misc'));
  v_rarity text := lower(COALESCE(p_rarity, 'common'));
  v_is_equip boolean := v_type IN ('weapon', 'armor');
BEGIN
  IF COALESCE(p_is_tradeable, true) = false
     OR COALESCE(p_is_han_only, false) = true
     OR v_type = 'cosmetic'
     OR COALESCE(p_item_id, '') LIKE 'box\_%' ESCAPE '\'
     OR COALESCE(p_item_id, '') LIKE 'badge\_%' ESCAPE '\'
  THEN
    RETURN 0;
  END IF;

  v_level := GREATEST(1, COALESCE(p_required_level, 1));
  v_enh := LEAST(10, GREATEST(0, COALESCE(p_enhancement_level, 0)));
  v_stat := GREATEST(
    0,
    COALESCE(p_attack, 0) + COALESCE(p_defense, 0)
      + COALESCE(p_power, 0) + COALESCE(p_luck, 0)
  );

  v_worth := GREATEST(
    10,
    (v_stat / 15) + (v_level * 6)
  );

  IF v_type IN ('potion', 'consumable') THEN
    v_worth := GREATEST(
      v_worth,
      (COALESCE(p_energy_restore, 0) * 3)
        + (COALESCE(p_health_restore, 0) * 2)
        + (v_level * 2)
    );
  ELSIF v_type = 'material' THEN
    v_worth := GREATEST(v_worth, 12 + (v_level * 8));
  ELSIF v_type IN ('recipe', 'scroll', 'rune', 'catalyst') THEN
    v_worth := GREATEST(v_worth, 20 + (v_level * 10));
  END IF;

  v_shop_cap := CASE v_rarity
    WHEN 'common' THEN 280 + (v_level * 220)
    WHEN 'uncommon' THEN 240 + (v_level * 180)
    WHEN 'rare' THEN 200 + (v_level * 160)
    WHEN 'epic' THEN 180 + (v_level * 130)
    WHEN 'legendary' THEN 150 + (v_level * 100)
    WHEN 'mythic' THEN 120 + (v_level * 75)
    ELSE 200 + (v_level * 150)
  END;

  v_sell_pct := CASE v_rarity
    WHEN 'common' THEN 0.35
    WHEN 'uncommon' THEN 0.30
    WHEN 'rare' THEN 0.25
    WHEN 'epic' THEN 0.20
    WHEN 'legendary' THEN 0.15
    WHEN 'mythic' THEN 0.12
    ELSE 0.25
  END;

  v_shop_ref := LEAST(
    GREATEST(COALESCE(p_base_price, 0), v_worth),
    v_shop_cap
  );

  -- +0 floor sell (enhancement applied after equip bump / material path)
  v_sell := FLOOR(v_shop_ref * v_sell_pct)::int;

  v_max_sell := CASE v_rarity
    WHEN 'common' THEN 80 + (v_level * 85)
    WHEN 'uncommon' THEN 70 + (v_level * 70)
    WHEN 'rare' THEN 60 + (v_level * 58)
    WHEN 'epic' THEN 50 + (v_level * 45)
    WHEN 'legendary' THEN 40 + (v_level * 35)
    WHEN 'mythic' THEN 30 + (v_level * 28)
    ELSE 60 + (v_level * 58)
  END;

  v_sell := LEAST(v_sell, v_max_sell);

  IF v_is_equip THEN
    -- Equip sink was too harsh; raise +0 payout ≥6× prior cap path.
    v_sell := v_sell * 6;
    -- Match combat enhancement: +10 → ×2.50 on sell too.
    v_sell := FLOOR(v_sell * (1.0 + (v_enh * 0.15)))::int;
  ELSE
    -- Materials / potions / scrolls: keep prior mild enh bonus.
    v_sell := FLOOR(v_sell * (1.0 + (v_enh * 0.06)))::int;
    v_sell := LEAST(v_sell, v_max_sell);
  END IF;

  IF v_sell <= 0 THEN
    RETURN 0;
  END IF;

  RETURN GREATEST(1, v_sell);
END;
$$;

COMMENT ON FUNCTION public.compute_npc_sell_price(
  text, text, text, int, int, int, int, int, int, int, int, int, boolean, boolean, int
) IS
  'NPC vendor sell. weapon/armor: ×6 on +0 then ×(1+enh×0.15). materials unchanged caps.';

COMMIT;
