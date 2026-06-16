-- Inventory reward boxes (box_weapon_*, box_armor_*, box_jewelry_*)
-- were routed through use_potion and consumed with zero reward.
-- Add drop pools + dedicated open RPC.

BEGIN;

INSERT INTO public.loot_box_configs (
  id, name, description, price, currency_type, is_active, display_order, reward_multiplier
)
VALUES
  ('box_weapon_common', 'Common Weapon Box', 'Random common weapon', 1, 'gems', false, 901, 1),
  ('box_weapon_rare', 'Rare Weapon Box', 'Random rare weapon', 1, 'gems', false, 902, 1),
  ('box_weapon_legendary', 'Legendary Weapon Box', 'Random legendary weapon', 1, 'gems', false, 903, 1),
  ('box_armor_rare', 'Rare Armor Box', 'Random rare armor', 1, 'gems', false, 904, 1),
  ('box_armor_epic', 'Epic Armor Box', 'Random epic armor', 1, 'gems', false, 905, 1),
  ('box_jewelry_rare', 'Rare Jewelry Box', 'Random rare jewelry', 1, 'gems', false, 906, 1),
  ('box_jewelry_epic', 'Epic Jewelry Box', 'Random epic jewelry', 1, 'gems', false, 907, 1)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = 1,
  currency_type = EXCLUDED.currency_type,
  is_active = EXCLUDED.is_active,
  display_order = EXCLUDED.display_order,
  reward_multiplier = EXCLUDED.reward_multiplier;

DELETE FROM public.loot_box_drop_entries
WHERE box_id IN (
  'box_weapon_common', 'box_weapon_rare', 'box_weapon_legendary',
  'box_armor_rare', 'box_armor_epic', 'box_jewelry_rare', 'box_jewelry_epic'
);

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, is_active)
SELECT 'box_weapon_common', i.id, 1, 1, 1, true
FROM public.items i
WHERE lower(i.rarity) = 'common'
  AND i.equip_slot = 'weapon'
  AND lower(COALESCE(i.type, '')) = 'weapon';

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, is_active)
SELECT 'box_weapon_rare', i.id, 1, 1, 1, true
FROM public.items i
WHERE lower(i.rarity) = 'rare'
  AND i.equip_slot = 'weapon'
  AND lower(COALESCE(i.type, '')) = 'weapon';

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, is_active)
SELECT 'box_weapon_legendary', i.id, 1, 1, 1, true
FROM public.items i
WHERE lower(i.rarity) = 'legendary'
  AND i.equip_slot = 'weapon'
  AND lower(COALESCE(i.type, '')) = 'weapon';

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, is_active)
SELECT 'box_armor_rare', i.id, 1, 1, 1, true
FROM public.items i
WHERE lower(i.rarity) = 'rare'
  AND lower(COALESCE(i.type, '')) = 'armor'
  AND i.equip_slot IN ('chest', 'head', 'legs', 'boots', 'gloves');

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, is_active)
SELECT 'box_armor_epic', i.id, 1, 1, 1, true
FROM public.items i
WHERE lower(i.rarity) = 'epic'
  AND lower(COALESCE(i.type, '')) = 'armor'
  AND i.equip_slot IN ('chest', 'head', 'legs', 'boots', 'gloves');

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, is_active)
SELECT 'box_jewelry_rare', i.id, 1, 1, 1, true
FROM public.items i
WHERE lower(i.rarity) = 'rare'
  AND i.equip_slot IN ('ring', 'necklace');

INSERT INTO public.loot_box_drop_entries (box_id, item_id, weight, min_quantity, max_quantity, is_active)
SELECT 'box_jewelry_epic', i.id, 1, 1, 1, true
FROM public.items i
WHERE lower(i.rarity) = 'epic'
  AND i.equip_slot IN ('ring', 'necklace');

CREATE OR REPLACE FUNCTION public.open_inventory_loot_box(
  p_row_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inv RECORD;
  v_box RECORD;
  v_drop RECORD;
  v_add_result JSONB;
  v_reward_qty INT := 1;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;

  SELECT inv.*, it.name AS item_name
  INTO v_inv
  FROM public.inventory inv
  JOIN public.items it ON it.id = inv.item_id
  WHERE inv.row_id = p_row_id
    AND inv.user_id = p_user_id
    AND inv.quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kasa bulunamadi veya miktar yetersiz');
  END IF;

  IF v_inv.item_id NOT LIKE 'box\_%' ESCAPE '\' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu esya acilabilir bir kasa degil');
  END IF;

  SELECT *
  INTO v_box
  FROM public.loot_box_configs
  WHERE id = v_inv.item_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kasa odul havuzu tanimli degil');
  END IF;

  SELECT
    e.item_id,
    e.weight,
    e.min_quantity,
    e.max_quantity,
    i.name AS item_name,
    i.icon,
    COALESCE(i.is_stackable, false) AS is_stackable
  INTO v_drop
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  WHERE e.box_id = v_inv.item_id
    AND e.is_active = TRUE
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu kasa icin odul tanimi yok');
  END IF;

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kasa tuketilemedi');
  END IF;

  IF COALESCE(v_drop.is_stackable, false) = FALSE THEN
    v_reward_qty := 1;
  ELSE
    v_reward_qty := GREATEST(
      1,
      FLOOR(random() * (v_drop.max_quantity - v_drop.min_quantity + 1) + v_drop.min_quantity)::INT
    );
  END IF;

  v_add_result := public.add_inventory_item_v2(
    jsonb_build_object(
      'item_id', v_drop.item_id,
      'quantity', v_reward_qty,
      'allow_stack', true
    ),
    NULL
  );

  IF COALESCE((v_add_result->>'success')::BOOLEAN, FALSE) = FALSE THEN
    INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, is_equipped)
    VALUES (p_user_id, v_inv.item_id, 1, v_inv.slot_position, false);

    RETURN jsonb_build_object(
      'success', false,
      'error', COALESCE(v_add_result->>'error', 'Envanter dolu. Kasa iade edildi.')
    );
  END IF;

  INSERT INTO public.player_loot_box_logs (
    user_id,
    box_id,
    spent_currency,
    spent_amount,
    reward_type,
    reward_item_id,
    reward_amount,
    roll_weight,
    metadata
  )
  VALUES (
    p_user_id,
    v_inv.item_id,
    'gems',
    0,
    'item',
    v_drop.item_id,
    v_reward_qty,
    v_drop.weight,
    jsonb_build_object(
      'source', 'inventory',
      'box_name', v_box.name,
      'item_name', v_drop.item_name,
      'inventory_row_id', p_row_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'box_id', v_inv.item_id,
    'box_name', v_box.name,
    'reward', jsonb_build_object(
      'type', 'item',
      'item_id', v_drop.item_id,
      'name', v_drop.item_name,
      'icon', v_drop.icon,
      'quantity', v_reward_qty
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.open_inventory_loot_box(UUID, UUID) TO authenticated;

-- Prevent reward boxes from being silently consumed as potions.
CREATE OR REPLACE FUNCTION public.use_potion(
  p_row_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_new_tolerance INT;
  v_overdose BOOLEAN := false;
  v_efficiency NUMERIC;
  v_overdose_chance NUMERIC;
  v_roll NUMERIC;
  v_hospital_minutes INT;
  v_heal_amount INT;
  v_energy_gain INT;
  v_monument_level INT := 0;
  v_saved_from_overdose BOOLEAN := false;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_user.guild_id;
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Geçersiz iksir');
  END IF;

  IF v_item.id LIKE 'box\_%' ESCAPE '\' THEN
    RETURN jsonb_build_object('error', 'Odul kasasi icin envanterden Ac kullanin');
  END IF;

  IF lower(COALESCE(v_item.type, '')) NOT IN ('potion', 'consumable') THEN
    RETURN jsonb_build_object('error', 'Geçersiz iksir');
  END IF;

  v_new_tolerance := COALESCE(v_user.tolerance, 0) + COALESCE(v_item.tolerance_increase, 0);
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_new_tolerance := COALESCE(v_user.tolerance, 0)
      + floor(COALESCE(v_item.tolerance_increase, 0) * 0.75);
  END IF;
  v_new_tolerance := GREATEST(0, LEAST(v_new_tolerance, 100));

  v_efficiency := CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 20 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.85
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 0.65
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 0.45
    ELSE 0.25
  END;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_efficiency := LEAST(1.0, v_efficiency * 1.30);
  END IF;

  v_overdose_chance := COALESCE(v_item.overdose_risk, 0) * CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.0
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 2.0
    WHEN COALESCE(v_user.tolerance, 0) <= 90 THEN 4.0
    ELSE 8.0
  END;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_overdose_chance := v_overdose_chance * 0.80;
  END IF;

  IF v_monument_level >= 20 THEN
    v_overdose_chance := v_overdose_chance * 0.90;
  END IF;

  v_roll := random();
  IF v_roll <= v_overdose_chance THEN
    v_overdose := true;

    IF v_monument_level >= 80 AND (
      v_user.last_overdose_save_at IS NULL OR
      v_user.last_overdose_save_at::date < CURRENT_DATE
    ) THEN
      v_overdose := false;
      v_saved_from_overdose := true;
    END IF;
  END IF;

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  PERFORM public.bp_trigger_potion_usage(p_user_id);

  IF v_overdose THEN
    v_hospital_minutes := 30 + (COALESCE(v_user.tolerance, 0) * 2);

    UPDATE public.users
    SET addiction_level = LEAST(COALESCE(addiction_level, 0) + 1, 10),
        tolerance = LEAST(v_new_tolerance + 10, 100),
        hospital_until = now() + (v_hospital_minutes || ' minutes')::interval,
        hospital_reason = 'Overdose',
        last_potion_used_at = now()
    WHERE auth_id = p_user_id;

    INSERT INTO public.tolerance_log (
      user_id, event_type, item_id,
      tolerance_before, tolerance_after,
      addiction_before, addiction_after
    )
    VALUES (
      p_user_id, 'overdose', v_inv.item_id,
      COALESCE(v_user.tolerance, 0), LEAST(v_new_tolerance + 10, 100),
      COALESCE(v_user.addiction_level, 0), LEAST(COALESCE(v_user.addiction_level, 0) + 1, 10)
    );

    RETURN jsonb_build_object(
      'success', true,
      'overdose', true,
      'hospital_minutes', v_hospital_minutes,
      'efficiency', 0
    );
  END IF;

  v_heal_amount := floor(COALESCE(v_item.heal_amount, v_item.health_restore, 0) * v_efficiency);
  v_energy_gain := floor(COALESCE(v_item.energy_restore, 0) * v_efficiency);

  IF lower(COALESCE(v_item.potion_type, '')) = 'health' AND v_heal_amount = 0 THEN
    v_heal_amount := floor(COALESCE(v_item.heal_amount, 50) * v_efficiency);
  END IF;

  IF lower(COALESCE(v_item.potion_type, '')) = 'energy' AND v_energy_gain = 0 THEN
    v_energy_gain := floor(COALESCE(v_item.heal_amount, 20) * v_efficiency);
  END IF;

  UPDATE public.users
  SET tolerance = v_new_tolerance,
      last_potion_used_at = now(),
      last_overdose_save_at = CASE WHEN v_saved_from_overdose THEN now() ELSE last_overdose_save_at END,
      energy = LEAST(max_energy, COALESCE(energy, 0) + v_energy_gain),
      health = LEAST(max_health, COALESCE(health, 0) + v_heal_amount)
  WHERE auth_id = p_user_id;

  INSERT INTO public.tolerance_log (
    user_id, event_type, item_id,
    tolerance_before, tolerance_after,
    addiction_before, addiction_after
  )
  VALUES (
    p_user_id, 'potion_use', v_inv.item_id,
    COALESCE(v_user.tolerance, 0), v_new_tolerance,
    COALESCE(v_user.addiction_level, 0), COALESCE(v_user.addiction_level, 0)
  );

  RETURN jsonb_build_object(
    'success', true,
    'overdose', false,
    'saved_from_overdose', v_saved_from_overdose,
    'efficiency', v_efficiency,
    'new_tolerance', v_new_tolerance,
    'heal_amount', v_heal_amount,
    'energy_restored', v_energy_gain
  );
END;
$$;

COMMIT;
