-- Crafting queue: base 1 concurrent slot, max 5 via permanent gem unlocks.
-- Slot costs: 1 free, 2=20, 3=40, 4=80, 5=160 gems.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS crafting_queue_slots integer NOT NULL DEFAULT 1;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_crafting_queue_slots_range;

ALTER TABLE public.users
  ADD CONSTRAINT users_crafting_queue_slots_range
  CHECK (crafting_queue_slots >= 1 AND crafting_queue_slots <= 5);

COMMENT ON COLUMN public.users.crafting_queue_slots IS
  'Max concurrent craft queue items. Slot 1 free; unlock slots 2-5 for 20/40/80/160 gems.';

CREATE OR REPLACE FUNCTION public.craft_queue_slot_unlock_cost(p_target_slots integer)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_target_slots
    WHEN 2 THEN 20
    WHEN 3 THEN 40
    WHEN 4 THEN 80
    WHEN 5 THEN 160
    ELSE NULL::integer
  END;
$$;

CREATE OR REPLACE FUNCTION public.expand_craft_queue_slot()
RETURNS TABLE (
  success boolean,
  message text,
  gems_spent integer,
  new_total_slots integer,
  player_gems_remaining numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_current_slots integer;
  v_next_slots integer;
  v_cost integer;
  v_current_gems numeric;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer, 0::numeric;
    RETURN;
  END IF;

  SELECT crafting_queue_slots, gems
  INTO v_current_slots, v_current_gems
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF v_current_slots IS NULL THEN
    RETURN QUERY SELECT false, 'User not found'::text, 0::integer, 0::integer, 0::numeric;
    RETURN;
  END IF;

  IF v_current_slots >= 5 THEN
    RETURN QUERY SELECT false,
      'Craft queue at maximum capacity (5 slots)'::text,
      0::integer,
      5::integer,
      v_current_gems;
    RETURN;
  END IF;

  v_next_slots := v_current_slots + 1;
  v_cost := public.craft_queue_slot_unlock_cost(v_next_slots);

  IF v_cost IS NULL THEN
    RETURN QUERY SELECT false, 'Invalid queue slot unlock'::text, 0::integer, v_current_slots::integer, v_current_gems;
    RETURN;
  END IF;

  IF v_current_gems < v_cost THEN
    RETURN QUERY SELECT false,
      'Insufficient gems. Need ' || v_cost || ', have ' || floor(v_current_gems)::text,
      0::integer,
      v_current_slots::integer,
      v_current_gems;
    RETURN;
  END IF;

  UPDATE public.users
  SET gems = gems - v_cost,
      crafting_queue_slots = v_next_slots,
      updated_at = now()
  WHERE auth_id = v_user_id;

  RETURN QUERY SELECT true,
    'Unlocked craft queue slot ' || v_next_slots || ' for ' || v_cost || ' gems'::text,
    v_cost::integer,
    v_next_slots::integer,
    (v_current_gems - v_cost)::numeric;
END;
$$;

GRANT EXECUTE ON FUNCTION public.expand_craft_queue_slot() TO authenticated;

COMMENT ON FUNCTION public.expand_craft_queue_slot() IS
  'Permanently unlock +1 craft queue slot. Costs: slot2=20, slot3=40, slot4=80, slot5=160 gems.';

DROP FUNCTION IF EXISTS public.craft_item_async(uuid, integer);

CREATE FUNCTION public.craft_item_async(
  p_recipe_id uuid,
  p_batch_count integer DEFAULT 1
)
RETURNS TABLE (
  success boolean,
  queue_item_id uuid,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_recipe crafting_recipes%ROWTYPE;
  v_queue_item craft_queue%ROWTYPE;
  v_completes_at timestamp with time zone;
  v_ingredient_item RECORD;
  v_required_qty integer;
  v_owned_qty integer;
  v_max_slots integer;
  v_active_count integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Not authenticated'::text;
    RETURN;
  END IF;

  SELECT COALESCE(crafting_queue_slots, 1)
  INTO v_max_slots
  FROM public.users
  WHERE auth_id = v_user_id;

  IF v_max_slots IS NULL THEN
    v_max_slots := 1;
  END IF;

  SELECT COUNT(*)::integer
  INTO v_active_count
  FROM public.craft_queue
  WHERE user_id = v_user_id
    AND claimed = false;

  IF v_active_count >= v_max_slots THEN
    RETURN QUERY SELECT false, NULL::uuid,
      ('Craft queue full (' || v_active_count || '/' || v_max_slots || '). Unlock more slots with gems.')::text;
    RETURN;
  END IF;

  SELECT * FROM public.crafting_recipes WHERE id = p_recipe_id INTO v_recipe;
  IF v_recipe.id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Recipe not found'::text;
    RETURN;
  END IF;

  IF v_recipe.ingredients IS NOT NULL AND v_recipe.ingredients != 'null'::jsonb THEN
    FOR v_ingredient_item IN
      SELECT
        jsonb_array_elements(v_recipe.ingredients) ->> 'item_id' as item_id,
        (jsonb_array_elements(v_recipe.ingredients) ->> 'quantity')::integer as quantity
    LOOP
      v_required_qty := (v_ingredient_item.quantity * p_batch_count);

      SELECT COALESCE(SUM(quantity), 0) INTO v_owned_qty
      FROM public.inventory
      WHERE user_id = v_user_id AND item_id = v_ingredient_item.item_id;

      IF v_owned_qty < v_required_qty THEN
        RETURN QUERY SELECT false, NULL::uuid,
          'Insufficient material: ' || v_ingredient_item.item_id || ' (need ' || v_required_qty || ', have ' || v_owned_qty || ')'::text;
        RETURN;
      END IF;
    END LOOP;
  END IF;

  IF v_recipe.ingredients IS NOT NULL AND v_recipe.ingredients != 'null'::jsonb THEN
    FOR v_ingredient_item IN
      SELECT
        jsonb_array_elements(v_recipe.ingredients) ->> 'item_id' as item_id,
        (jsonb_array_elements(v_recipe.ingredients) ->> 'quantity')::integer as quantity
    LOOP
      v_required_qty := (v_ingredient_item.quantity * p_batch_count);

      DECLARE
        v_remaining integer := v_required_qty;
        v_row RECORD;
        v_take integer;
      BEGIN
        FOR v_row IN
          SELECT row_id, quantity FROM public.inventory
          WHERE user_id = v_user_id AND item_id = v_ingredient_item.item_id
          ORDER BY created_at ASC
        LOOP
          EXIT WHEN v_remaining <= 0;
          v_take := LEAST(v_row.quantity, v_remaining);
          IF v_row.quantity > v_take THEN
            UPDATE public.inventory
            SET quantity = quantity - v_take, updated_at = now()
            WHERE row_id = v_row.row_id;
          ELSE
            DELETE FROM public.inventory WHERE row_id = v_row.row_id;
          END IF;
          v_remaining := v_remaining - v_take;
        END LOOP;
      END;
    END LOOP;
  END IF;

  v_completes_at := now() + (v_recipe.production_time_seconds * p_batch_count) * INTERVAL '1 second';

  INSERT INTO public.craft_queue (user_id, recipe_id, batch_count, completes_at, is_completed, claimed, failed)
  VALUES (v_user_id, p_recipe_id, p_batch_count, v_completes_at, false, false, false)
  RETURNING * INTO v_queue_item;

  RETURN QUERY SELECT true, v_queue_item.id, 'Craft started'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.craft_item_async(uuid, integer) TO authenticated;
