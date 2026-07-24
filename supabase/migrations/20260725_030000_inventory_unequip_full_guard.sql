-- Envanter doluyken direkt unequip engeli; bos slot veya hedef slot ile birakma.

DROP FUNCTION IF EXISTS public.unequip_item(text);

CREATE OR REPLACE FUNCTION public.unequip_item(
  p_slot text,
  p_target_slot integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
  v_row_id uuid;
  v_free_slot integer;
  v_capacity integer := 20;
  v_new_power numeric;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT row_id
  INTO v_row_id
  FROM public.inventory
  WHERE user_id = v_user_id
    AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, ''))
    AND is_equipped = TRUE
  LIMIT 1;

  IF v_row_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Item not found, not owned, or not equipped'
    );
  END IF;

  IF p_target_slot IS NOT NULL THEN
    IF p_target_slot < 0 OR p_target_slot >= v_capacity THEN
      RETURN jsonb_build_object('success', false, 'error', 'Gecersiz envanter slotu');
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.inventory i
      WHERE i.user_id = v_user_id
        AND i.is_equipped = FALSE
        AND i.slot_position = p_target_slot
        AND i.row_id <> v_row_id
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Hedef slot dolu — benzer slottaki esyayla degistir'
      );
    END IF;

    v_free_slot := p_target_slot;
  ELSE
    SELECT s.slot
    INTO v_free_slot
    FROM generate_series(0, v_capacity - 1) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.inventory i
      WHERE i.user_id = v_user_id
        AND i.is_equipped = FALSE
        AND i.slot_position = s.slot
    )
    ORDER BY s.slot
    LIMIT 1;

    IF v_free_slot IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Envanter dolu — benzer slottaki esyayla degistir'
      );
    END IF;
  END IF;

  UPDATE public.inventory
  SET is_equipped = FALSE,
      equip_slot = NULL,
      slot_position = v_free_slot,
      updated_at = NOW()
  WHERE row_id = v_row_id;

  v_new_power := public.calculate_user_total_power(v_user_id);
  UPDATE public.users
  SET power = v_new_power::integer
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'slot', p_slot,
    'slot_position', v_free_slot
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.unequip_item(text, integer) TO authenticated, anon, service_role;
