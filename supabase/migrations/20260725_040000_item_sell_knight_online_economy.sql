-- Knight Online style NPC vendor sell: server-side price, capped, no client trust.
-- Fixes inventory rows with vendor_sell_price=0 and inflated items.vendor_sell_price outliers.

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
  v_type text := lower(COALESCE(p_item_type, 'misc'));
  v_rarity text := lower(COALESCE(p_rarity, 'common'));
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
  ELSIF v_type IN ('recipe', 'scroll', 'rune') THEN
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

  v_sell := FLOOR(
    v_shop_ref * v_sell_pct * (1.0 + (GREATEST(COALESCE(p_enhancement_level, 0), 0) * 0.06))
  )::int;

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

  IF v_sell <= 0 THEN
    RETURN 0;
  END IF;

  RETURN GREATEST(1, v_sell);
END;
$$;

CREATE OR REPLACE FUNCTION public.sell_inventory_item_by_row(
  p_row_id uuid,
  p_quantity int DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_inv record;
  v_item record;
  v_sell_qty int;
  v_unit_sell int;
  v_gold_earned int := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
  END IF;

  SELECT inv.*
  INTO v_inv
  FROM public.inventory inv
  WHERE inv.row_id = p_row_id
    AND inv.user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned');
  END IF;

  IF COALESCE(v_inv.is_equipped, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kusanili esya satilamaz — once cikar');
  END IF;

  SELECT *
  INTO v_item
  FROM public.items
  WHERE id = v_inv.item_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item definition not found');
  END IF;

  v_unit_sell := public.compute_npc_sell_price(
    v_inv.item_id,
    lower(COALESCE(v_item.rarity, 'common')),
    lower(COALESCE(v_item.type, 'misc')),
    COALESCE(v_item.required_level, 1),
    COALESCE(v_item.base_price, 0),
    COALESCE(v_item.vendor_sell_price, 0),
    COALESCE(v_item.attack, 0),
    COALESCE(v_item.defense, 0),
    COALESCE(v_item.power, 0),
    COALESCE(v_item.luck, 0),
    COALESCE(v_item.energy_restore, 0),
    COALESCE(v_item.health_restore, 0),
    COALESCE(v_inv.is_tradeable, v_item.is_tradeable, true),
    COALESCE(v_item.is_han_only, false),
    COALESCE(v_inv.enhancement_level, 0)
  );

  IF v_unit_sell <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu esya NPC''ye satilamaz');
  END IF;

  v_sell_qty := LEAST(COALESCE(v_inv.quantity, 0), p_quantity);
  IF v_sell_qty <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
  END IF;

  v_gold_earned := v_unit_sell * v_sell_qty;

  IF v_sell_qty >= v_inv.quantity THEN
    DELETE FROM public.inventory
    WHERE row_id = p_row_id
      AND user_id = v_user_id;
  ELSE
    UPDATE public.inventory
    SET quantity = quantity - v_sell_qty,
        updated_at = NOW()
    WHERE row_id = p_row_id
      AND user_id = v_user_id;
  END IF;

  UPDATE public.users
  SET gold = COALESCE(gold, 0) + v_gold_earned
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'sold_quantity', v_sell_qty,
    'unit_sell_price', v_unit_sell,
    'currency', 'gold',
    'gold_earned', v_gold_earned,
    'gems_earned', 0
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_inventory()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_items jsonb;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  WITH free_slots AS (
    SELECT s.slot,
           row_number() OVER (ORDER BY s.slot) AS rn
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.inventory inv2
      WHERE inv2.user_id = v_user_id
        AND inv2.is_equipped = false
        AND inv2.slot_position = s.slot
    )
  ),
  unassigned_rows AS (
    SELECT inv1.row_id,
           row_number() OVER (ORDER BY inv1.created_at, inv1.row_id) AS rn
    FROM public.inventory inv1
    WHERE inv1.user_id = v_user_id
      AND inv1.is_equipped = false
      AND inv1.slot_position IS NULL
  )
  UPDATE public.inventory inv
  SET slot_position = fs.slot,
      updated_at = now()
  FROM unassigned_rows ur
  JOIN free_slots fs ON fs.rn = ur.rn
  WHERE inv.row_id = ur.row_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'row_id', inv.row_id,
      'user_id', inv.user_id,
      'item_id', inv.item_id,
      'quantity', inv.quantity,
      'slot_position', inv.slot_position,
      'is_equipped', COALESCE(inv.is_equipped, false),
      'equipped_slot', COALESCE(inv.equip_slot, ''),
      'equip_slot', COALESCE(it.equip_slot, 'none'),
      'created_at', inv.created_at,
      'updated_at', inv.updated_at,
      'enhancement_level', COALESCE(inv.enhancement_level, 0),
      'obtained_at', inv.obtained_at,
      'is_favorite', COALESCE(inv.is_favorite, false),
      'description', COALESCE(inv.description, it.description),
      'icon', COALESCE(inv.icon, it.icon),
      'name', COALESCE(it.name, inv.item_id),
      'item_type', lower(COALESCE(it.type, 'misc')),
      'rarity', lower(COALESCE(it.rarity, 'common')),
      'facility_type', it.facility_type,
      'attack', COALESCE(it.attack, 0),
      'defense', COALESCE(it.defense, 0),
      'health', COALESCE(it.health, 0),
      'power', COALESCE(it.power, 0),
      'luck', COALESCE(it.luck, 0),
      'required_level', COALESCE(it.required_level, 1),
      'required_class', it.required_class,
      'weapon_type', COALESCE(inv.weapon_type, it.weapon_type),
      'armor_type', COALESCE(inv.armor_type, it.armor_type),
      'material_type', COALESCE(inv.material_type, it.material_type),
      'potion_type', lower(COALESCE(inv.potion_type, it.potion_type, 'none')),
      'base_price', COALESCE(inv.base_price, it.base_price, 0),
      'vendor_sell_price', public.compute_npc_sell_price(
        inv.item_id,
        lower(COALESCE(it.rarity, 'common')),
        lower(COALESCE(it.type, 'misc')),
        COALESCE(it.required_level, 1),
        COALESCE(it.base_price, 0),
        COALESCE(it.vendor_sell_price, 0),
        COALESCE(it.attack, 0),
        COALESCE(it.defense, 0),
        COALESCE(it.power, 0),
        COALESCE(it.luck, 0),
        COALESCE(it.energy_restore, 0),
        COALESCE(it.health_restore, 0),
        COALESCE(inv.is_tradeable, it.is_tradeable, true),
        COALESCE(it.is_han_only, false),
        COALESCE(inv.enhancement_level, 0)
      ),
      'is_tradeable', COALESCE(inv.is_tradeable, it.is_tradeable, true),
      'is_stackable', COALESCE(inv.is_stackable, it.is_stackable, true),
      'max_stack', COALESCE(inv.max_stack, it.max_stack, 999),
      'max_enhancement', COALESCE(inv.max_enhancement, it.max_enhancement, 0),
      'can_enhance', COALESCE(inv.can_enhance, it.can_enhance, false),
      'heal_amount', COALESCE(inv.heal_amount, it.heal_amount, 0),
      'health_restore', COALESCE(it.health_restore, inv.heal_amount, it.heal_amount, 0),
      'energy_restore', COALESCE(it.energy_restore, 0),
      'tolerance_increase', COALESCE(inv.tolerance_increase, it.tolerance_increase, 0),
      'overdose_risk', COALESCE(inv.overdose_risk, it.overdose_risk, 0),
      'is_han_only', COALESCE(it.is_han_only, false),
      'is_market_tradeable', COALESCE(it.is_market_tradeable, true),
      'is_direct_tradeable', COALESCE(it.is_direct_tradeable, true),
      'pending_sync', COALESCE(inv.pending_sync, false)
    )
    ORDER BY COALESCE(inv.slot_position, 999), inv.created_at
  )
  INTO v_items
  FROM public.inventory inv
  LEFT JOIN public.items it ON inv.item_id = it.id
  WHERE inv.user_id = v_user_id AND inv.is_equipped = false;

  RETURN jsonb_build_object('success', true, 'items', COALESCE(v_items, '[]'::jsonb));
END;
$$;

GRANT EXECUTE ON FUNCTION public.compute_npc_sell_price(
  text, text, text, int, int, int, int, int, int, int, int, int, boolean, boolean, int
) TO authenticated, anon, service_role;

GRANT EXECUTE ON FUNCTION public.sell_inventory_item_by_row(uuid, int) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_inventory() TO anon, authenticated, service_role;

COMMIT;
