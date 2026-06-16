-- Prevent loot-box opening when inventory has no free slot, even if reward could stack.
CREATE OR REPLACE FUNCTION public.open_loot_box(p_box_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_box RECORD;
  v_drop RECORD;
  v_balance_ok BOOLEAN := FALSE;
  v_reward_qty INTEGER;
  v_add_result JSONB;
  v_has_free_slot BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT *
  INTO v_box
  FROM public.loot_box_configs
  WHERE id = p_box_id
    AND is_active = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kasa bulunamadi veya pasif.');
  END IF;

  -- Hard rule: if there is no free inventory slot, opening is blocked.
  -- This intentionally ignores stack availability to prevent targeted farming exploits.
  SELECT EXISTS (
    SELECT 1
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.inventory i
      WHERE i.user_id = v_user_id
        AND i.slot_position = s.slot
        AND i.is_equipped = FALSE
    )
  )
  INTO v_has_free_slot;

  IF COALESCE(v_has_free_slot, FALSE) = FALSE THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Envanter dolu. Kasa acmak icin once bos slot acmalisin.'
    );
  END IF;

  IF v_box.currency_type = 'gems' THEN
    UPDATE public.users
    SET gems = gems - v_box.price
    WHERE auth_id = v_user_id
      AND gems >= v_box.price
    RETURNING TRUE INTO v_balance_ok;
  ELSE
    UPDATE public.users
    SET gold = gold - v_box.price
    WHERE auth_id = v_user_id
      AND gold >= v_box.price
    RETURNING TRUE INTO v_balance_ok;
  END IF;

  IF COALESCE(v_balance_ok, FALSE) = FALSE THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz bakiye.');
  END IF;

  SELECT
    e.item_id,
    e.weight,
    e.min_quantity,
    e.max_quantity,
    i.name AS item_name,
    i.icon,
    COALESCE(i.is_stackable, FALSE) AS is_stackable
  INTO v_drop
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  WHERE e.box_id = p_box_id
    AND e.is_active = TRUE
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    IF v_box.currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + v_box.price WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + v_box.price WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Bu kasa icin drop tanimi yok.');
  END IF;

  v_reward_qty := FLOOR(random() * (v_drop.max_quantity - v_drop.min_quantity + 1) + v_drop.min_quantity)::INTEGER;
  v_reward_qty := GREATEST(1, FLOOR(v_reward_qty * COALESCE(v_box.reward_multiplier, 1))::INTEGER);

  IF COALESCE(v_drop.is_stackable, FALSE) = FALSE THEN
    v_reward_qty := 1;
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
    IF v_box.currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + v_box.price WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + v_box.price WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Envanter dolu. Kasa ucreti iade edildi.');
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
  ) VALUES (
    v_user_id,
    v_box.id,
    v_box.currency_type,
    v_box.price,
    'item',
    v_drop.item_id,
    v_reward_qty,
    v_drop.weight,
    jsonb_build_object(
      'box_name', v_box.name,
      'item_name', v_drop.item_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Kasa acildi.',
    'box_id', v_box.id,
    'box_name', v_box.name,
    'spent_currency', v_box.currency_type,
    'spent_amount', v_box.price,
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
