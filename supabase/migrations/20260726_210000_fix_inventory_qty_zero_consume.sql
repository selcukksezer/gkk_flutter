-- inventory_quantity_check requires quantity > 0.
-- UPDATE-to-0 then DELETE fails CHECK before DELETE runs.
-- Fix enhance_item / use_han_item / start_facility_production(3-arg).

-- ---------------------------------------------------------------------------
-- enhance_item: consume scroll/rune via helper (never UPDATE to 0)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enhance_item(
  p_player_id UUID,
  p_row_id UUID,
  p_rune_type TEXT DEFAULT 'none'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_item RECORD;
  v_player RECORD;
  v_rarity_mult NUMERIC;
  v_base_cost INTEGER;
  v_gold_cost INTEGER;
  v_success_rate NUMERIC;
  v_destroy_rate NUMERIC;
  v_success BOOLEAN;
  v_destroyed BOOLEAN := false;
  v_new_level INTEGER;
  v_scroll_id TEXT;
  v_has_scroll BOOLEAN;
  v_has_rune BOOLEAN;
  v_debug JSONB := '{}'::jsonb;
  v_catalog_can_enhance BOOLEAN;
BEGIN
  IF p_player_id != auth.uid() THEN
    v_debug := jsonb_build_object('player_id', p_player_id, 'auth_uid', auth.uid());
    RETURN jsonb_build_object('error', 'Yetkisiz işlem', 'debug', v_debug);
  END IF;

  SELECT inv.*, items.rarity, items.can_enhance AS catalog_can_enhance
  INTO v_item
  FROM public.inventory inv
  JOIN public.items ON items.id = inv.item_id
  WHERE inv.row_id = p_row_id AND inv.user_id = p_player_id;

  v_catalog_can_enhance := COALESCE(v_item.catalog_can_enhance, v_item.can_enhance, false);

  IF NOT FOUND THEN
    v_debug := jsonb_build_object('player_id', p_player_id, 'row_id', p_row_id);
    RETURN jsonb_build_object('error', 'item_not_found', 'debug', v_debug);
  END IF;

  IF NOT v_catalog_can_enhance THEN
    v_debug := jsonb_build_object(
      'item_id', v_item.item_id,
      'catalog_id', v_item.item_id,
      'rarity', v_item.rarity,
      'inv_can_enhance', v_item.can_enhance,
      'catalog_can_enhance', v_catalog_can_enhance,
      'enhancement_level', v_item.enhancement_level
    );
    RETURN jsonb_build_object('error', 'cannot_enhance', 'debug', v_debug);
  END IF;

  IF v_item.enhancement_level >= 10 THEN
    v_debug := jsonb_build_object('item_id', v_item.item_id, 'enhancement_level', v_item.enhancement_level);
    RETURN jsonb_build_object('error', 'max_level', 'debug', v_debug);
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;

  v_rarity_mult := CASE v_item.rarity
    WHEN 'common' THEN 1.0
    WHEN 'uncommon' THEN 1.5
    WHEN 'rare' THEN 2.5
    WHEN 'epic' THEN 4.0
    WHEN 'legendary' THEN 7.0
    WHEN 'mythic' THEN 12.0
    ELSE 1.0
  END;

  v_base_cost := (ARRAY[100000,200000,300000,500000,1500000,3500000,7500000,15000000,50000000,200000000,1000000000])[v_item.enhancement_level + 1];
  v_gold_cost := floor(v_base_cost * v_rarity_mult);
  -- [GKK_MONUMENT_ENHANCE_BEGIN]
  v_gold_cost := floor(v_gold_cost * public._monument_enhancement_gold_multiplier(public._monument_level_for_auth(p_player_id)));
  -- [GKK_MONUMENT_ENHANCE_END]

  IF v_player.gold < v_gold_cost THEN
    v_debug := jsonb_build_object('player_gold', v_player.gold, 'required_gold', v_gold_cost);
    RETURN jsonb_build_object('error', 'insufficient_gold', 'debug', v_debug);
  END IF;

  v_scroll_id := CASE
    WHEN v_item.rarity IN ('common', 'uncommon') THEN 'scroll_upgrade_low'
    WHEN v_item.rarity IN ('rare', 'epic') THEN 'scroll_upgrade_middle'
    ELSE 'scroll_upgrade_high'
  END;

  SELECT EXISTS(
    SELECT 1 FROM public.inventory
    WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity > 0
  ) INTO v_has_scroll;

  IF NOT v_has_scroll THEN
    v_debug := jsonb_build_object('scroll_id', v_scroll_id, 'has_scroll', v_has_scroll);
    RETURN jsonb_build_object('error', 'no_scroll', 'debug', v_debug);
  END IF;

  IF p_rune_type != 'none' THEN
    SELECT EXISTS(
      SELECT 1 FROM public.inventory
      WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity > 0
    ) INTO v_has_rune;

    IF NOT v_has_rune THEN
      v_debug := jsonb_build_object('requested_rune', p_rune_type, 'has_rune', v_has_rune);
      RETURN jsonb_build_object('error', 'no_rune', 'debug', v_debug);
    END IF;
  END IF;

  v_success_rate := (ARRAY[1.0,1.0,1.0,1.0,0.7,0.6,0.5,0.35,0.2,0.1,0.03])[v_item.enhancement_level + 1];
  v_destroy_rate := (ARRAY[0,0,0,0,0,0,1.0,1.0,1.0,1.0,1.0])[v_item.enhancement_level + 1];

  IF p_rune_type = 'basic' THEN v_success_rate := v_success_rate + 0.05;
  ELSIF p_rune_type = 'advanced' THEN v_success_rate := v_success_rate + 0.10;
  ELSIF p_rune_type = 'superior' THEN v_success_rate := v_success_rate + 0.15; v_destroy_rate := v_destroy_rate * 0.5;
  ELSIF p_rune_type = 'legendary' THEN v_success_rate := v_success_rate + 0.25; v_destroy_rate := v_destroy_rate * 0.25;
  ELSIF p_rune_type = 'protection' THEN v_destroy_rate := 0;
  ELSIF p_rune_type = 'blessed' THEN v_success_rate := v_success_rate + 0.20; v_destroy_rate := v_destroy_rate * 0.5;
  END IF;

  v_success_rate := LEAST(1.0, v_success_rate);
  IF v_item.enhancement_level >= 6 THEN
    v_destroy_rate := GREATEST(0, v_destroy_rate - public._monument_enhancement_destroy_reduction(public._monument_level_for_auth(p_player_id)));
  END IF;
  v_destroy_rate := GREATEST(0, v_destroy_rate);

  v_success := random() <= v_success_rate;
  v_new_level := v_item.enhancement_level;

  IF v_success THEN
    v_new_level := v_item.enhancement_level + 1;
  ELSE
    IF v_item.enhancement_level >= 6 AND p_rune_type != 'protection' AND p_rune_type != 'blessed' THEN
      IF random() <= v_destroy_rate THEN
        v_destroyed := true;
      ELSE
        v_new_level := GREATEST(0, v_item.enhancement_level - 1);
      END IF;
    ELSIF p_rune_type = 'blessed' THEN
      v_new_level := v_item.enhancement_level;
    ELSE
      v_new_level := GREATEST(0, v_item.enhancement_level - 1);
    END IF;
  END IF;

  -- Consume scroll/rune BEFORE gold. Gold miss after consume → RAISE (rollback stack).
  IF NOT public._consume_inventory_item(p_player_id, v_scroll_id, 1) THEN
    v_debug := jsonb_build_object('scroll_id', v_scroll_id, 'expected_decrement', 1);
    RETURN jsonb_build_object('error', 'Geliştirme parşömeni yetersiz', 'debug', v_debug);
  END IF;

  IF p_rune_type != 'none' THEN
    IF NOT public._consume_inventory_item(p_player_id, 'rune_' || p_rune_type, 1) THEN
      -- Scroll already taken; force rollback.
      RAISE EXCEPTION 'Seçilen rune yetersiz';
    END IF;
  END IF;

  UPDATE public.users SET gold = gold - v_gold_cost WHERE auth_id = p_player_id AND gold >= v_gold_cost;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'İşlem sırasında altın yetersiz kaldı';
  END IF;

  IF v_destroyed THEN
    DELETE FROM public.inventory WHERE row_id = p_row_id;
  ELSE
    UPDATE public.inventory SET enhancement_level = v_new_level WHERE row_id = p_row_id;
  END IF;

  INSERT INTO public.enhancement_history (
    player_id, item_id, item_row_id, previous_level, attempted_level, new_level,
    rune_used, scroll_used, gold_spent, success, destroyed, success_rate_at_attempt
  ) VALUES (
    p_player_id, v_item.item_id, p_row_id, v_item.enhancement_level, v_item.enhancement_level + 1, v_new_level,
    p_rune_type, v_scroll_id, v_gold_cost, v_success, v_destroyed, v_success_rate
  );

  v_debug := jsonb_build_object(
    'item_id', v_item.item_id,
    'previous_level', v_item.enhancement_level,
    'attempted_level', v_item.enhancement_level + 1,
    'new_level', v_new_level,
    'rune_used', p_rune_type,
    'scroll_used', v_scroll_id,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1),
    'inv_can_enhance', v_item.can_enhance,
    'catalog_can_enhance', v_catalog_can_enhance
  );

  RETURN jsonb_build_object(
    'success', v_success,
    'destroyed', v_destroyed,
    'new_level', v_new_level,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1),
    'debug', v_debug
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.enhance_item(UUID, UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- use_han_item: last stack → DELETE via _consume_inventory_row
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.use_han_item(p_user_id uuid, p_row_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_overdose_chance NUMERIC;
  v_is_overdose BOOLEAN := false;
  v_tolerance_mult NUMERIC := 1.0;
  v_hospital_minutes INT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı');
  END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT v_item.is_han_only THEN
    RETURN jsonb_build_object('error', 'Bu bir Han eşyası değil, use_potion kullanın');
  END IF;

  IF COALESCE(v_user.tolerance, 0) > 60 AND COALESCE(v_item.overdose_risk, 0) > 0 THEN
    v_tolerance_mult := v_user.tolerance / 50.0;
    v_overdose_chance := v_item.overdose_risk * v_tolerance_mult;

    IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
      v_overdose_chance := v_overdose_chance * 0.80;
    END IF;

    IF random() <= v_overdose_chance THEN
      v_is_overdose := true;
    END IF;
  END IF;

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  IF v_is_overdose THEN
    v_hospital_minutes := 120 + floor(random() * 120);

    UPDATE public.users
    SET
      hospital_until = now() + (v_hospital_minutes || ' minutes')::INTERVAL,
      hospital_reason = 'Han İksiri Overdose',
      tolerance = LEAST(100, COALESCE(tolerance, 0) + 15)
    WHERE auth_id = p_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'overdose', true,
      'hospital_minutes', v_hospital_minutes
    );
  ELSE
    UPDATE public.users
    SET
      energy = LEAST(100, energy + COALESCE(v_item.energy_restore, 0)),
      health = LEAST(max_health, health + COALESCE(v_item.heal_amount, 0)),
      tolerance = GREATEST(0, LEAST(100, COALESCE(tolerance, 0) + COALESCE(v_item.tolerance_increase, 0)))
    WHERE auth_id = p_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'overdose', false,
      'energy_restored', COALESCE(v_item.energy_restore, 0),
      'new_tolerance', GREATEST(0, LEAST(100, COALESCE(v_user.tolerance, 0) + COALESCE(v_item.tolerance_increase, 0)))
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_han_item(UUID, UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- start_facility_production(3-arg): DELETE when stack empties (no UPDATE to 0)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_facility_production(
  p_facility_id uuid,
  p_recipe_id text,
  p_quantity integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id UUID;
  v_facility RECORD;
  v_recipe RECORD;
  v_total_gold INT;
  v_now BIGINT;
  v_duration INT;
  v_suspicion_inc INT;
  v_mat_id TEXT;
  v_mat_req_single INT;
  v_mat_total_needed INT;
  v_user_has INT;
BEGIN
  v_user_id := auth.uid();
  v_now := EXTRACT(EPOCH FROM NOW())::BIGINT;

  SELECT * INTO v_facility FROM public.facilities WHERE id = p_facility_id AND user_id = v_user_id;
  IF v_facility IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
  END IF;

  SELECT * INTO v_recipe FROM public.facility_recipes WHERE id = p_recipe_id;
  IF v_recipe IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recipe not found');
  END IF;

  IF v_facility.level < v_recipe.required_level THEN
    RETURN jsonb_build_object('success', false, 'error', 'Facility level too low');
  END IF;

  v_total_gold := v_recipe.gold_cost * p_quantity;

  IF (SELECT gold FROM public.users WHERE id = v_user_id) < v_total_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
  END IF;

  FOR v_mat_id, v_mat_req_single IN SELECT * FROM jsonb_each_text(v_recipe.input_materials)
  LOOP
    v_mat_total_needed := v_mat_req_single::INT * p_quantity;
    SELECT COALESCE(SUM(quantity), 0) INTO v_user_has
    FROM public.inventory
    WHERE user_id = v_user_id AND item_id = v_mat_id;
    IF v_user_has < v_mat_total_needed THEN
      RAISE EXCEPTION 'Insufficient material: %', v_mat_id;
    END IF;
  END LOOP;

  UPDATE public.users SET gold = gold - v_total_gold WHERE id = v_user_id;

  FOR v_mat_id, v_mat_req_single IN SELECT * FROM jsonb_each_text(v_recipe.input_materials)
  LOOP
    v_mat_total_needed := v_mat_req_single::INT * p_quantity;
    IF NOT public._consume_inventory_item(v_user_id, v_mat_id, v_mat_total_needed) THEN
      RAISE EXCEPTION 'Insufficient material: %', v_mat_id;
    END IF;
  END LOOP;

  v_suspicion_inc := v_recipe.base_suspicion_increase * p_quantity;
  UPDATE public.facilities
  SET suspicion = LEAST(100, suspicion + v_suspicion_inc)
  WHERE id = p_facility_id;

  v_duration := (v_recipe.duration_seconds * p_quantity);
  INSERT INTO public.facility_queue (facility_id, recipe_id, quantity, started_at, completed_at)
  VALUES (p_facility_id, p_recipe_id, p_quantity, v_now, v_now + v_duration);

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
