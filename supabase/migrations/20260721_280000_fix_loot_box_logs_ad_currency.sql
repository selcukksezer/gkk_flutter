-- Allow ad-paid inventory box opens to log in player_loot_box_logs.
-- claim_box_reward writes spent_currency = box_openings.payment ('ad' | 'gems');
-- original CHECK only allowed ('gold', 'gems').

ALTER TABLE public.player_loot_box_logs
  DROP CONSTRAINT IF EXISTS player_loot_box_logs_spent_currency_check;

ALTER TABLE public.player_loot_box_logs
  ADD CONSTRAINT player_loot_box_logs_spent_currency_check
  CHECK (
    spent_currency IN ('gold', 'gems', 'ad')
    AND (spent_currency <> 'ad' OR spent_amount = 0)
  );

-- Explicit mapping so ad opens always log spent_amount = 0.
CREATE OR REPLACE FUNCTION public.claim_box_reward(p_opening_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_open RECORD;
  v_inv RECORD;
  v_box RECORD;
  v_drop RECORD;
  v_free_slots INT;
  v_reward_qty INT := 1;
  v_spent_currency TEXT;
  v_spent_amount INT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_open
  FROM public.box_openings
  WHERE id = p_opening_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND OR v_open.status != 'opening' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Açılma kaydı bulunamadı');
  END IF;

  IF now() < v_open.opens_at THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kutu henüz açılmadı');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = v_open.inventory_row_id AND user_id = v_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    UPDATE public.box_openings SET status = 'deleted' WHERE id = p_opening_id;
    RETURN jsonb_build_object('success', false, 'error', 'Kutu envanterde yok — ödül iptal');
  END IF;

  SELECT COUNT(*) INTO v_free_slots
  FROM generate_series(0, 19) s(slot)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.inventory inv
    WHERE inv.user_id = v_user_id
      AND inv.is_equipped = false
      AND inv.slot_position = s.slot
      AND inv.row_id != v_open.inventory_row_id
  );

  IF v_free_slots < 1 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'inventory_full',
      'message', 'Envanterin dolu! Ödülü almak için yer aç.'
    );
  END IF;

  SELECT * INTO v_box FROM public.loot_box_configs WHERE id = v_open.box_id;

  SELECT
    e.item_id, e.weight, e.min_quantity, e.max_quantity,
    i.name AS item_name, i.icon,
    COALESCE(i.is_stackable, false) AS is_stackable
  INTO v_drop
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  WHERE e.box_id = v_open.box_id AND e.is_active = TRUE
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu kutu için ödül tanımı yok');
  END IF;

  IF NOT public._consume_inventory_row(v_open.inventory_row_id, v_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kutu tüketilemedi');
  END IF;

  IF COALESCE(v_drop.is_stackable, false) THEN
    v_reward_qty := GREATEST(
      1,
      FLOOR(random() * (v_drop.max_quantity - v_drop.min_quantity + 1) + v_drop.min_quantity)::INT
    );
  END IF;

  IF NOT public.dungeon_add_item(v_user_id, v_drop.item_id, v_reward_qty) THEN
    INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, is_equipped)
    VALUES (v_user_id, v_open.box_id, 1, v_inv.slot_position, false);

    IF NOT EXISTS (SELECT 1 FROM public.items WHERE id = v_drop.item_id) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'reward_item_missing',
        'message', 'Ödül eşyası tanımlı değil. Kutu iade edildi.'
      );
    END IF;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'inventory_full',
      'message', 'Envanterin dolu! Ödülü almak için yer aç.'
    );
  END IF;

  IF v_open.payment = 'ad' THEN
    v_spent_currency := 'ad';
    v_spent_amount := 0;
  ELSE
    v_spent_currency := COALESCE(v_open.payment, 'gems');
    v_spent_amount := COALESCE(v_open.gems_spent, 0)::INT;
  END IF;

  UPDATE public.box_openings
  SET status = 'claimed', claimed_at = now()
  WHERE id = p_opening_id;

  INSERT INTO public.player_loot_box_logs (
    user_id, box_id, spent_currency, spent_amount,
    reward_type, reward_item_id, reward_amount, roll_weight, metadata
  )
  VALUES (
    v_user_id, v_open.box_id, v_spent_currency, v_spent_amount,
    'item', v_drop.item_id, v_reward_qty, v_drop.weight,
    jsonb_build_object(
      'source', 'box_opening',
      'opening_id', p_opening_id,
      'box_name', COALESCE(v_box.name, v_open.box_id),
      'item_name', v_drop.item_name,
      'payment', v_open.payment
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'box_id', v_open.box_id,
    'box_name', COALESCE(v_box.name, v_open.box_id),
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
