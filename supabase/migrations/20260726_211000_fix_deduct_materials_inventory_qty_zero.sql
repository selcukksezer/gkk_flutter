-- Same inventory_quantity_check bug: UPDATE-to-0 then DELETE.
CREATE OR REPLACE FUNCTION public.deduct_materials_from_inventory(
  p_user_id uuid,
  p_ingredients jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_ingredient jsonb;
  v_item_id text;
  v_quantity int;
BEGIN
  FOR v_ingredient IN SELECT jsonb_array_elements(p_ingredients)
  LOOP
    v_item_id := v_ingredient->>'item_id';
    v_quantity := (v_ingredient->>'quantity')::INT;
    IF v_item_id IS NULL OR v_quantity IS NULL OR v_quantity <= 0 THEN
      CONTINUE;
    END IF;
    IF NOT public._consume_inventory_item(p_user_id, v_item_id, v_quantity) THEN
      RAISE EXCEPTION 'Insufficient material: %', v_item_id;
    END IF;
  END LOOP;
END;
$$;
