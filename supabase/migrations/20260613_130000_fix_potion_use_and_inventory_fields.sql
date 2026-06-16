-- Fix energy potion use from inventory:
-- 1) Case-insensitive potion type check (items.type is often 'POTION')
-- 2) Default p_user_id := auth.uid() so mobile client can pass only p_row_id
-- 3) Restore tolerance / energy_restore logic + battle pass trigger
-- 4) get_inventory returns energy_restore / health_restore / luck / equip_slot

BEGIN;

DROP FUNCTION IF EXISTS public.use_potion(UUID, UUID);

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
  IF NOT FOUND OR lower(COALESCE(v_item.type, '')) NOT IN ('potion', 'consumable') THEN
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

  PERFORM public.bp_trigger_potion_usage(p_user_id);

  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = p_row_id AND quantity > 0;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  DELETE FROM public.inventory WHERE quantity <= 0 AND row_id = p_row_id;

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
      energy = LEAST(max_energy, energy + v_energy_gain),
      health = LEAST(max_health, health + v_heal_amount)
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

GRANT EXECUTE ON FUNCTION public.use_potion(UUID, UUID) TO authenticated;

DROP FUNCTION IF EXISTS public.use_detox(UUID, UUID);

CREATE OR REPLACE FUNCTION public.use_detox(
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
  v_tolerance_reduction INT;
  v_addiction_reduction INT;
  v_cooldown_hours INT;
  v_new_tolerance INT;
  v_new_addiction INT;
  v_detox_type TEXT;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR lower(COALESCE(v_item.sub_type, '')) <> 'detox' THEN
    RETURN jsonb_build_object('error', 'Geçersiz detox içeceği');
  END IF;

  IF v_item.id = 'detox_minor' THEN
    v_detox_type := 'minor'; v_tolerance_reduction := 15; v_addiction_reduction := 0; v_cooldown_hours := 4;
  ELSIF v_item.id = 'detox_major' THEN
    v_detox_type := 'major'; v_tolerance_reduction := 35; v_addiction_reduction := 1; v_cooldown_hours := 8;
  ELSIF v_item.id = 'detox_supreme' THEN
    v_detox_type := 'supreme'; v_tolerance_reduction := 60; v_addiction_reduction := 2; v_cooldown_hours := 12;
  ELSIF v_item.id = 'detox_full_cleanse' THEN
    v_detox_type := 'full_cleanse'; v_tolerance_reduction := 100; v_addiction_reduction := 10; v_cooldown_hours := 24;
  ELSE
    v_detox_type := 'minor'; v_tolerance_reduction := 15; v_addiction_reduction := 0; v_cooldown_hours := 4;
  END IF;

  IF v_user.last_detox_used_at IS NOT NULL
     AND v_user.last_detox_used_at + (v_cooldown_hours || ' hours')::interval > now() THEN
    RETURN jsonb_build_object('error', 'Detox cooldown aktif. Kalan süre için bekleyin.');
  END IF;

  v_new_tolerance := GREATEST(COALESCE(v_user.tolerance, 0) - v_tolerance_reduction, 0);
  v_new_addiction := GREATEST(COALESCE(v_user.addiction_level, 0) - v_addiction_reduction, 0);

  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = p_row_id AND quantity > 0;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  DELETE FROM public.inventory WHERE quantity <= 0 AND row_id = p_row_id;

  UPDATE public.users
  SET tolerance = v_new_tolerance,
      addiction_level = v_new_addiction,
      last_detox_used_at = now(),
      detox_type_last = v_detox_type
  WHERE auth_id = p_user_id;

  INSERT INTO public.tolerance_log (
    user_id, event_type, item_id,
    tolerance_before, tolerance_after,
    addiction_before, addiction_after
  )
  VALUES (
    p_user_id, 'detox', v_item.id,
    COALESCE(v_user.tolerance, 0), v_new_tolerance,
    COALESCE(v_user.addiction_level, 0), v_new_addiction
  );

  RETURN jsonb_build_object(
    'success', true,
    'detox_type', v_detox_type,
    'new_tolerance', v_new_tolerance,
    'new_addiction', v_new_addiction
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_detox(UUID, UUID) TO authenticated;

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
      'vendor_sell_price', COALESCE(inv.vendor_sell_price, it.vendor_sell_price, 0),
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

GRANT EXECUTE ON FUNCTION public.get_inventory() TO anon, authenticated, service_role;

COMMIT;
