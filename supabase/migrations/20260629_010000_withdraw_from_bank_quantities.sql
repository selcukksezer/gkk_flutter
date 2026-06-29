-- Allow partial withdraw amounts from bank (pairs with Flutter qty dialog).

DROP FUNCTION IF EXISTS public.withdraw_from_bank(uuid[]);

CREATE FUNCTION public.withdraw_from_bank(
  p_bank_item_ids uuid[],
  p_quantities integer[] DEFAULT NULL
)
RETURNS TABLE (
  success boolean,
  message text,
  items_withdrawn integer,
  new_used_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_withdraw_count integer := 0;
  v_used_slots integer;
  v_bank_item_id uuid;
  v_item_id text;
  v_bank_quantity integer;
  v_requested_qty integer;
  v_max_stack integer;
  v_existing_inv_qty integer;
  v_can_stack integer;
  v_will_withdraw integer;
  v_will_remain integer;
  i integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  IF p_bank_item_ids IS NULL OR array_length(p_bank_item_ids, 1) IS NULL THEN
    RETURN QUERY SELECT false, 'No bank items specified'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  SELECT used_slots
  INTO v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  FOR i IN 1..array_length(p_bank_item_ids, 1) LOOP
    v_bank_item_id := p_bank_item_ids[i];

    SELECT item_id, quantity INTO v_item_id, v_bank_quantity
    FROM public.bank_items
    WHERE id = v_bank_item_id AND user_id = v_user_id;

    IF v_item_id IS NULL THEN
      CONTINUE;
    END IF;

    v_requested_qty := v_bank_quantity;
    IF p_quantities IS NOT NULL
       AND array_length(p_quantities, 1) IS NOT NULL
       AND i <= array_length(p_quantities, 1)
       AND p_quantities[i] IS NOT NULL THEN
      v_requested_qty := LEAST(v_bank_quantity, GREATEST(1, p_quantities[i]));
    END IF;

    SELECT max_stack INTO v_max_stack
    FROM public.items
    WHERE id = v_item_id;

    v_max_stack := COALESCE(v_max_stack, 1);

    SELECT COALESCE(SUM(quantity), 0) INTO v_existing_inv_qty
    FROM public.inventory
    WHERE user_id = v_user_id
      AND item_id = v_item_id
      AND is_equipped = FALSE;

    v_can_stack := v_max_stack - v_existing_inv_qty;

    IF v_can_stack <= 0 THEN
      CONTINUE;
    END IF;

    v_will_withdraw := LEAST(v_requested_qty, v_can_stack);
    v_will_remain := v_bank_quantity - v_will_withdraw;

    IF v_will_withdraw <= 0 THEN
      CONTINUE;
    END IF;

    IF v_existing_inv_qty > 0 THEN
      UPDATE public.inventory
      SET quantity = quantity + v_will_withdraw,
          updated_at = now()
      WHERE user_id = v_user_id
        AND item_id = v_item_id
        AND is_equipped = FALSE;
    ELSE
      INSERT INTO public.inventory (user_id, item_id, quantity, is_equipped, equip_slot, slot_position)
      SELECT v_user_id, v_item_id, v_will_withdraw, false, 'none',
        (SELECT MIN(slot_num)
         FROM generate_series(0, 19) AS t(slot_num)
         WHERE NOT EXISTS (
           SELECT 1 FROM public.inventory
           WHERE user_id = v_user_id AND slot_position = t.slot_num AND is_equipped = FALSE
         ));
    END IF;

    IF v_will_remain > 0 THEN
      UPDATE public.bank_items
      SET quantity = v_will_remain,
          updated_at = now()
      WHERE id = v_bank_item_id;
    ELSE
      DELETE FROM public.bank_items WHERE id = v_bank_item_id;
      v_withdraw_count := v_withdraw_count + 1;
    END IF;
  END LOOP;

  UPDATE public.user_bank_account
  SET used_slots = GREATEST(0, used_slots - v_withdraw_count),
      updated_at = now()
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT true,
    'Withdrawn successfully'::text,
    v_withdraw_count::integer,
    GREATEST(0, v_used_slots - v_withdraw_count)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.withdraw_from_bank(uuid[], integer[]) TO authenticated;
