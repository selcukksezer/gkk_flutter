-- Bank deposit used COUNT(*) for slot_position → collisions / stacked UI overlap.
-- Fix: first-free-slot helper, stack-aware deposit, unique index, repair existing rows.

CREATE OR REPLACE FUNCTION public.bank_first_free_slot(
  p_user_id uuid,
  p_max_slots integer DEFAULT 200
)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT s.slot
  FROM generate_series(0, GREATEST(p_max_slots, 1) - 1) AS s(slot)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.bank_items bi
    WHERE bi.user_id = p_user_id
      AND bi.slot_position = s.slot
  )
  ORDER BY s.slot
  LIMIT 1;
$$;

-- Repair duplicate slot assignments (keep oldest row per slot).
DO $$
DECLARE
  rec RECORD;
  v_new_slot integer;
  v_max_slots integer;
BEGIN
  FOR rec IN
    SELECT d.id, d.user_id
    FROM (
      SELECT
        bi.id,
        bi.user_id,
        ROW_NUMBER() OVER (
          PARTITION BY bi.user_id, bi.slot_position
          ORDER BY bi.stored_at NULLS LAST, bi.id
        ) AS rn
      FROM public.bank_items bi
      WHERE bi.slot_position IS NOT NULL
    ) d
    WHERE d.rn > 1
  LOOP
    SELECT COALESCE(uba.total_slots, 200)
    INTO v_max_slots
    FROM public.user_bank_account uba
    WHERE uba.user_id = rec.user_id;

    v_max_slots := COALESCE(v_max_slots, 200);
    v_new_slot := public.bank_first_free_slot(rec.user_id, v_max_slots);

    IF v_new_slot IS NOT NULL THEN
      UPDATE public.bank_items
      SET slot_position = v_new_slot,
          updated_at = now()
      WHERE id = rec.id;
    END IF;
  END LOOP;
END $$;

DROP INDEX IF EXISTS idx_bank_items_user_slot_unique;
CREATE UNIQUE INDEX idx_bank_items_user_slot_unique
  ON public.bank_items (user_id, slot_position)
  WHERE slot_position IS NOT NULL;

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
  v_new_slots integer := 0;
  v_used_slots integer;
  v_max_slots integer;
  v_item_row uuid;
  v_quantity integer;
  v_idx integer := 1;
  v_inv_quantity integer;
  v_max_stack integer;
  v_item_id text;
  v_item_category text;
  v_qty_left integer;
  v_add integer;
  v_bank_row_id uuid;
  v_bank_row_qty integer;
  v_free_slot integer;
  v_deposited integer;
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

    v_max_stack := GREATEST(COALESCE(v_max_stack, 1), 1);

    v_quantity := COALESCE(p_quantities[v_idx], v_inv_quantity);
    v_quantity := LEAST(v_quantity, v_inv_quantity);
    v_qty_left := v_quantity;
    v_deposited := 0;

    WHILE v_qty_left > 0 LOOP
      SELECT bi.id, bi.quantity
      INTO v_bank_row_id, v_bank_row_qty
      FROM public.bank_items bi
      WHERE bi.user_id = v_user_id
        AND bi.item_id = v_item_id
        AND bi.quantity < v_max_stack
      ORDER BY bi.stored_at NULLS LAST, bi.id
      LIMIT 1;

      IF v_bank_row_id IS NOT NULL THEN
        v_add := LEAST(v_qty_left, v_max_stack - v_bank_row_qty);
        UPDATE public.bank_items
        SET quantity = quantity + v_add,
            updated_at = now()
        WHERE id = v_bank_row_id;
        v_deposited := v_deposited + v_add;
        v_qty_left := v_qty_left - v_add;
        CONTINUE;
      END IF;

      IF v_used_slots >= v_max_slots THEN
        EXIT;
      END IF;

      v_free_slot := public.bank_first_free_slot(v_user_id, v_max_slots);
      IF v_free_slot IS NULL THEN
        EXIT;
      END IF;

      v_add := LEAST(v_qty_left, v_max_stack);
      INSERT INTO public.bank_items (user_id, item_id, category, slot_position, quantity)
      VALUES (v_user_id, v_item_id, v_item_category, v_free_slot, v_add);

      v_new_slots := v_new_slots + 1;
      v_used_slots := v_used_slots + 1;
      v_deposited := v_deposited + v_add;
      v_qty_left := v_qty_left - v_add;
    END LOOP;

    IF v_deposited <= 0 THEN
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;

    IF v_inv_quantity - v_deposited > 0 THEN
      UPDATE public.inventory
      SET quantity = v_inv_quantity - v_deposited,
          updated_at = now()
      WHERE row_id = v_item_row;
    ELSE
      DELETE FROM public.inventory
      WHERE row_id = v_item_row;
    END IF;

    v_idx := v_idx + 1;
  END LOOP;

  UPDATE public.user_bank_account uba
  SET used_slots = (
        SELECT COUNT(*)::integer
        FROM public.bank_items bi
        WHERE bi.user_id = uba.user_id
      ),
      updated_at = now()
  WHERE user_id = v_user_id;

  SELECT used_slots INTO v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  RETURN QUERY SELECT true,
    'Deposited successfully'::text,
    v_new_slots::integer,
    COALESCE(v_used_slots, 0)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.deposit_to_bank(uuid[], integer[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bank_first_free_slot(uuid, integer) TO authenticated;

-- swap_inventory_bank: auto-pick bank slot when p_target_slot < 0 (quick deposit).
CREATE OR REPLACE FUNCTION public.swap_inventory_bank(
  p_source_type text,
  p_source_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_quantity integer DEFAULT NULL,
  p_target_slot integer DEFAULT NULL
)
RETURNS TABLE (success boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_source_item_id text;
  v_source_qty integer;
  v_source_slot integer;
  v_target_item_id text;
  v_target_qty integer;
  v_target_slot integer;
  v_max_stack integer;
  v_transfer_qty integer;
  v_remaining_qty integer;
  v_actual_transfer integer;
  v_max_bank_slots integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text;
    RETURN;
  END IF;

  IF p_source_type = 'inventory' THEN
    SELECT item_id, quantity, slot_position INTO v_source_item_id, v_source_qty, v_source_slot
    FROM public.inventory
    WHERE row_id = p_source_id AND user_id = v_user_id;
  ELSIF p_source_type = 'bank' THEN
    SELECT item_id, quantity, slot_position INTO v_source_item_id, v_source_qty, v_source_slot
    FROM public.bank_items
    WHERE id = p_source_id AND user_id = v_user_id;
  END IF;

  IF v_source_item_id IS NULL THEN
    RETURN QUERY SELECT false, 'Source item not found'::text;
    RETURN;
  END IF;

  v_actual_transfer := COALESCE(p_quantity, v_source_qty);
  v_actual_transfer := LEAST(v_actual_transfer, v_source_qty);
  IF v_actual_transfer <= 0 THEN
    RETURN QUERY SELECT false, 'Invalid transfer quantity'::text;
    RETURN;
  END IF;

  IF p_target_id IS NOT NULL AND p_source_type = p_target_type AND p_source_id = p_target_id THEN
    RETURN QUERY SELECT true, 'Source and target are the same slot'::text;
    RETURN;
  END IF;

  IF p_target_id IS NOT NULL THEN
    IF p_target_type = 'inventory' THEN
      SELECT item_id, quantity, slot_position INTO v_target_item_id, v_target_qty, v_target_slot
      FROM public.inventory
      WHERE row_id = p_target_id AND user_id = v_user_id;
    ELSIF p_target_type = 'bank' THEN
      SELECT item_id, quantity, slot_position INTO v_target_item_id, v_target_qty, v_target_slot
      FROM public.bank_items
      WHERE id = p_target_id AND user_id = v_user_id;
    END IF;
  END IF;

  v_target_slot := COALESCE(v_target_slot, p_target_slot);

  IF p_target_type = 'bank'
     AND p_source_type = 'inventory'
     AND v_target_item_id IS NULL
     AND (v_target_slot IS NULL OR v_target_slot < 0) THEN
    SELECT total_slots INTO v_max_bank_slots
    FROM public.user_bank_account
    WHERE user_id = v_user_id;
    v_max_bank_slots := COALESCE(v_max_bank_slots, 100);
    v_target_slot := public.bank_first_free_slot(v_user_id, v_max_bank_slots);
    IF v_target_slot IS NULL THEN
      RETURN QUERY SELECT false, 'Bank is full'::text;
      RETURN;
    END IF;
  END IF;

  IF v_target_slot IS NULL THEN
    RETURN QUERY SELECT false, 'Target slot is required'::text;
    RETURN;
  END IF;

  SELECT max_stack INTO v_max_stack
  FROM public.items WHERE id = v_source_item_id;
  v_max_stack := COALESCE(v_max_stack, 1);

  IF v_target_item_id IS NOT NULL AND v_target_item_id = v_source_item_id THEN
    v_transfer_qty := LEAST(v_actual_transfer, v_max_stack - v_target_qty);
    IF v_transfer_qty <= 0 THEN
      RETURN QUERY SELECT false, 'Target stack is full'::text;
      RETURN;
    END IF;

    v_remaining_qty := v_source_qty - v_transfer_qty;

    IF p_target_type = 'inventory' THEN
      UPDATE public.inventory SET quantity = quantity + v_transfer_qty, updated_at = now()
      WHERE row_id = p_target_id;
    ELSIF p_target_type = 'bank' THEN
      UPDATE public.bank_items SET quantity = quantity + v_transfer_qty, updated_at = now()
      WHERE id = p_target_id;
    END IF;

    IF v_remaining_qty > 0 THEN
      IF p_source_type = 'inventory' THEN
        UPDATE public.inventory SET quantity = v_remaining_qty, updated_at = now()
        WHERE row_id = p_source_id;
      ELSIF p_source_type = 'bank' THEN
        UPDATE public.bank_items SET quantity = v_remaining_qty, updated_at = now()
        WHERE id = p_source_id;
      END IF;
    ELSE
      IF p_source_type = 'inventory' THEN
        DELETE FROM public.inventory WHERE row_id = p_source_id;
      ELSIF p_source_type = 'bank' THEN
        DELETE FROM public.bank_items WHERE id = p_source_id;
        UPDATE public.user_bank_account
        SET used_slots = GREATEST(0, used_slots - 1), updated_at = now()
        WHERE user_id = v_user_id;
      END IF;
    END IF;

    RETURN QUERY SELECT true, 'Items merged successfully'::text;
    RETURN;
  END IF;

  IF v_target_item_id IS NULL THEN
    IF p_target_type = 'inventory' THEN
      IF EXISTS (
        SELECT 1 FROM public.inventory
        WHERE user_id = v_user_id
          AND is_equipped = FALSE
          AND slot_position = v_target_slot
          AND row_id <> p_source_id
      ) THEN
        RETURN QUERY SELECT false, 'Target inventory slot is occupied'::text;
        RETURN;
      END IF;
    ELSIF p_target_type = 'bank' THEN
      IF EXISTS (
        SELECT 1 FROM public.bank_items
        WHERE user_id = v_user_id
          AND slot_position = v_target_slot
          AND id <> p_source_id
      ) THEN
        RETURN QUERY SELECT false, 'Target bank slot is occupied'::text;
        RETURN;
      END IF;
    END IF;

    IF p_source_type = 'inventory' AND p_target_type = 'bank' THEN
      INSERT INTO public.bank_items (user_id, item_id, quantity, category, slot_position)
      SELECT v_user_id, inv.item_id, v_actual_transfer,
        CASE
          WHEN it.type = 'equipment' THEN 'equipment'
          WHEN it.type = 'consumable' THEN 'consumable'
          WHEN it.type = 'special' THEN 'special'
          ELSE 'material'
        END,
        v_target_slot
      FROM public.inventory inv
      JOIN public.items it ON inv.item_id = it.id
      WHERE inv.row_id = p_source_id;

      IF v_source_qty - v_actual_transfer > 0 THEN
        UPDATE public.inventory SET quantity = v_source_qty - v_actual_transfer, updated_at = now()
        WHERE row_id = p_source_id;
      ELSE
        DELETE FROM public.inventory WHERE row_id = p_source_id;
      END IF;

      UPDATE public.user_bank_account
      SET used_slots = (
            SELECT COUNT(*)::integer
            FROM public.bank_items bi
            WHERE bi.user_id = v_user_id
          ),
          updated_at = now()
      WHERE user_id = v_user_id;

    ELSIF p_source_type = 'bank' AND p_target_type = 'inventory' THEN
      INSERT INTO public.inventory (user_id, item_id, quantity, slot_position)
      SELECT v_user_id, b.item_id, v_actual_transfer, v_target_slot
      FROM public.bank_items b
      WHERE b.id = p_source_id;

      IF v_source_qty - v_actual_transfer > 0 THEN
        UPDATE public.bank_items SET quantity = v_source_qty - v_actual_transfer, updated_at = now()
        WHERE id = p_source_id;
      ELSE
        DELETE FROM public.bank_items WHERE id = p_source_id;
        UPDATE public.user_bank_account
        SET used_slots = (
              SELECT COUNT(*)::integer
              FROM public.bank_items bi
              WHERE bi.user_id = v_user_id
            ),
            updated_at = now()
        WHERE user_id = v_user_id;
      END IF;

    ELSIF p_source_type = 'inventory' AND p_target_type = 'inventory' THEN
      IF v_actual_transfer < v_source_qty THEN
        RETURN QUERY SELECT false, 'Partial move is only allowed between inventory and bank'::text;
        RETURN;
      END IF;

      UPDATE public.inventory
      SET slot_position = v_target_slot,
          updated_at = now()
      WHERE row_id = p_source_id;

    ELSIF p_source_type = 'bank' AND p_target_type = 'bank' THEN
      IF v_actual_transfer < v_source_qty THEN
        RETURN QUERY SELECT false, 'Partial move is only allowed between inventory and bank'::text;
        RETURN;
      END IF;

      UPDATE public.bank_items
      SET slot_position = v_target_slot,
          updated_at = now()
      WHERE id = p_source_id;
    END IF;

    RETURN QUERY SELECT true, 'Item moved to empty slot'::text;
    RETURN;
  END IF;

  IF v_actual_transfer < v_source_qty THEN
    RETURN QUERY SELECT false, 'Partial swap is not allowed on different items'::text;
    RETURN;
  END IF;

  IF p_source_type = 'inventory' AND p_target_type = 'bank' THEN
    UPDATE public.inventory SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE row_id = p_source_id;

    UPDATE public.bank_items SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE id = p_target_id;
  ELSIF p_source_type = 'bank' AND p_target_type = 'inventory' THEN
    UPDATE public.bank_items SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE id = p_source_id;

    UPDATE public.inventory SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE row_id = p_target_id;
  ELSIF p_source_type = 'inventory' AND p_target_type = 'inventory' THEN
    UPDATE public.inventory SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE row_id = p_source_id;

    UPDATE public.inventory SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE row_id = p_target_id;
  ELSIF p_source_type = 'bank' AND p_target_type = 'bank' THEN
    UPDATE public.bank_items SET item_id = v_target_item_id, quantity = v_target_qty, updated_at = now()
    WHERE id = p_source_id;

    UPDATE public.bank_items SET item_id = v_source_item_id, quantity = v_source_qty, updated_at = now()
    WHERE id = p_target_id;
  END IF;

  RETURN QUERY SELECT true, 'Items swapped successfully'::text;
END;
$$;
