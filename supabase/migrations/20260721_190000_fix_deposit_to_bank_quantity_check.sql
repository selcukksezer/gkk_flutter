-- deposit_to_bank: full deposit set inventory quantity=0 before DELETE → violates inventory_quantity_check.

DROP FUNCTION IF EXISTS public.deposit_to_bank(uuid[]);
DROP FUNCTION IF EXISTS public.deposit_to_bank(uuid[], integer[]);

CREATE FUNCTION public.deposit_to_bank(p_item_row_ids uuid[], p_quantities integer[] DEFAULT NULL)
RETURNS TABLE (
  success boolean,
  message text,
  items_deposited integer,
  new_used_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_deposit_count integer := 0;
  v_used_slots integer;
  v_max_slots integer;
  v_item_row uuid;
  v_quantity integer;
  v_idx integer := 1;
  v_inv_quantity integer;
  v_max_stack integer;
  v_existing_bank_qty integer;
  v_can_stack integer;
  v_will_deposit integer;
  v_will_remain integer;
  v_item_id text;
  v_item_category text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  INSERT INTO public.user_bank_account (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT total_slots, used_slots
  INTO v_max_slots, v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  FOREACH v_item_row IN ARRAY p_item_row_ids
  LOOP
    SELECT inv.item_id, inv.quantity INTO v_item_id, v_inv_quantity
    FROM public.inventory inv
    WHERE inv.row_id = v_item_row AND inv.user_id = v_user_id;

    IF v_item_id IS NULL THEN
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    SELECT max_stack,
      CASE
        WHEN type = 'equipment' THEN 'equipment'
        WHEN type = 'consumable' THEN 'consumable'
        WHEN type = 'special' THEN 'special'
        ELSE 'material'
      END
    INTO v_max_stack, v_item_category
    FROM public.items
    WHERE id = v_item_id;

    v_max_stack := COALESCE(v_max_stack, 1);

    v_quantity := COALESCE(p_quantities[v_idx], v_inv_quantity);
    v_quantity := LEAST(v_quantity, v_inv_quantity);

    SELECT COALESCE(SUM(quantity), 0) INTO v_existing_bank_qty
    FROM public.bank_items
    WHERE user_id = v_user_id AND item_id = v_item_id;

    v_can_stack := v_max_stack - v_existing_bank_qty;

    IF v_can_stack <= 0 THEN
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    v_will_deposit := LEAST(v_quantity, v_can_stack);
    v_will_remain := v_inv_quantity - v_will_deposit;

    IF v_will_deposit <= 0 THEN
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    IF v_existing_bank_qty = 0 AND v_used_slots >= v_max_slots THEN
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    IF v_existing_bank_qty > 0 THEN
      UPDATE public.bank_items
      SET quantity = quantity + v_will_deposit,
          updated_at = now()
      WHERE user_id = v_user_id AND item_id = v_item_id;
    ELSE
      INSERT INTO public.bank_items (user_id, item_id, category, slot_position, quantity)
      VALUES (v_user_id, v_item_id, v_item_category,
        (SELECT COUNT(*) FROM public.bank_items WHERE user_id = v_user_id),
        v_will_deposit);
      v_deposit_count := v_deposit_count + 1;
    END IF;

    IF v_will_remain > 0 THEN
      UPDATE public.inventory
      SET quantity = v_will_remain,
          updated_at = now()
      WHERE row_id = v_item_row;
    ELSE
      DELETE FROM public.inventory
      WHERE row_id = v_item_row;
    END IF;

    v_idx := v_idx + 1;
  END LOOP;

  UPDATE public.user_bank_account
  SET used_slots = used_slots + v_deposit_count,
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT true,
    'Deposited successfully'::text,
    v_deposit_count::integer,
    (v_used_slots + v_deposit_count)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deposit_to_bank(uuid[], integer[]) TO authenticated;
