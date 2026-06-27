-- Trade stack limits always resolve from items.max_stack (per-item Supabase config).

BEGIN;

CREATE OR REPLACE FUNCTION public._trade_resolve_max_stack(
  p_item_id text,
  p_inventory_max_stack integer DEFAULT NULL
)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  SELECT GREATEST(
    1,
    COALESCE(
      (SELECT i.max_stack FROM public.items i WHERE i.id = p_item_id),
      p_inventory_max_stack,
      1
    )
  );
$$;

CREATE OR REPLACE FUNCTION public._trade_validate_recipient_for_session(
  p_user_id uuid,
  p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_other_id uuid;
  v_free_slots integer;
  v_outgoing_count integer;
  v_remaining integer;
  v_needed_slots integer;
  v_absorb integer;
  v_inc RECORD;
  v_outgoing_ids uuid[];
  v_item_max_stack integer;
BEGIN
  SELECT CASE
    WHEN ts.initiator_id = p_user_id THEN ts.partner_id
    ELSE ts.initiator_id
  END
  INTO v_other_id
  FROM public.trade_sessions ts
  WHERE ts.id = p_session_id;

  IF v_other_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret oturumu bulunamadı.');
  END IF;

  SELECT COALESCE(array_agg(ti.inventory_row_id), ARRAY[]::uuid[])
  INTO v_outgoing_ids
  FROM public.trade_items ti
  WHERE ti.session_id = p_session_id
    AND ti.owner_id = p_user_id;

  v_free_slots := public.market_count_free_slots(p_user_id);

  SELECT COUNT(*)::integer
  INTO v_outgoing_count
  FROM public.trade_items ti
  JOIN public.inventory i ON i.row_id = ti.inventory_row_id
  WHERE ti.session_id = p_session_id
    AND ti.owner_id = p_user_id
    AND i.is_equipped = false;

  v_free_slots := v_free_slots + v_outgoing_count;

  FOR v_inc IN
    SELECT
      i.row_id,
      i.item_id,
      i.quantity,
      COALESCE(i.enhancement_level, 0) AS enhancement_level,
      COALESCE(it.is_stackable, false) AS is_stackable,
      i.max_stack AS row_max_stack
    FROM public.trade_items ti
    JOIN public.inventory i ON i.row_id = ti.inventory_row_id
    LEFT JOIN public.items it ON it.id = i.item_id
    WHERE ti.session_id = p_session_id
      AND ti.owner_id = v_other_id
  LOOP
    IF NOT v_inc.is_stackable THEN
      IF EXISTS (
        SELECT 1
        FROM public.inventory i2
        WHERE i2.user_id = p_user_id
          AND i2.item_id = v_inc.item_id
          AND i2.is_equipped = false
          AND NOT (i2.row_id = ANY (v_outgoing_ids))
      ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu.');
      END IF;

      IF v_free_slots < 1 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu.');
      END IF;

      v_free_slots := v_free_slots - 1;
      CONTINUE;
    END IF;

    v_item_max_stack := public._trade_resolve_max_stack(v_inc.item_id, v_inc.row_max_stack);
    v_remaining := v_inc.quantity;

    SELECT COALESCE(
      SUM(
        GREATEST(
          0,
          public._trade_resolve_max_stack(i.item_id, i.max_stack) - i.quantity
        )
      ),
      0
    )::integer
    INTO v_absorb
    FROM public.inventory i
    WHERE i.user_id = p_user_id
      AND i.item_id = v_inc.item_id
      AND i.is_equipped = false
      AND COALESCE(i.enhancement_level, 0) = v_inc.enhancement_level
      AND i.quantity < public._trade_resolve_max_stack(i.item_id, i.max_stack)
      AND NOT (i.row_id = ANY (v_outgoing_ids));

    v_remaining := GREATEST(0, v_remaining - COALESCE(v_absorb, 0));

    IF v_remaining <= 0 THEN
      CONTINUE;
    END IF;

    v_needed_slots := CEIL(v_remaining::numeric / v_item_max_stack::numeric)::integer;

    IF v_free_slots < v_needed_slots THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu.');
    END IF;

    v_free_slots := v_free_slots - v_needed_slots;
  END LOOP;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public._trade_transfer_inventory_row(
  p_row_id uuid,
  p_recipient_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_row public.inventory%ROWTYPE;
  v_is_stackable boolean;
  v_max_stack integer;
  v_remaining integer;
  v_rec RECORD;
  v_space integer;
  v_add integer;
  v_free_slot integer;
  v_stack_cap integer;
BEGIN
  SELECT i.*
  INTO v_row
  FROM public.inventory i
  WHERE i.row_id = p_row_id
  FOR UPDATE OF i;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticaret eşyası bulunamadı.';
  END IF;

  SELECT COALESCE(it.is_stackable, false)
  INTO v_is_stackable
  FROM public.items it
  WHERE it.id = v_row.item_id;

  v_max_stack := public._trade_resolve_max_stack(v_row.item_id, v_row.max_stack);

  IF NOT v_is_stackable THEN
    IF EXISTS (
      SELECT 1
      FROM public.inventory i2
      WHERE i2.user_id = p_recipient_id
        AND i2.item_id = v_row.item_id
        AND i2.is_equipped = false
    ) THEN
      RAISE EXCEPTION 'Envanter dolu.';
    END IF;

    SELECT s.slot
    INTO v_free_slot
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.inventory inv
      WHERE inv.user_id = p_recipient_id
        AND inv.slot_position = s.slot
        AND inv.is_equipped = false
    )
    ORDER BY s.slot
    LIMIT 1;

    IF v_free_slot IS NULL THEN
      RAISE EXCEPTION 'Envanter dolu.';
    END IF;

    UPDATE public.inventory
    SET user_id = p_recipient_id,
        slot_position = v_free_slot,
        is_equipped = false,
        updated_at = now()
    WHERE row_id = p_row_id;

    RETURN;
  END IF;

  v_remaining := v_row.quantity;

  FOR v_rec IN
    SELECT i.row_id, i.quantity, i.item_id, i.max_stack AS row_max_stack
    FROM public.inventory i
    WHERE i.user_id = p_recipient_id
      AND i.item_id = v_row.item_id
      AND i.is_equipped = false
      AND COALESCE(i.enhancement_level, 0) = COALESCE(v_row.enhancement_level, 0)
    ORDER BY i.obtained_at ASC NULLS LAST, i.row_id
    FOR UPDATE OF i
  LOOP
    EXIT WHEN v_remaining <= 0;

    v_stack_cap := public._trade_resolve_max_stack(v_rec.item_id, v_rec.row_max_stack);
    IF v_rec.quantity >= v_stack_cap THEN
      CONTINUE;
    END IF;

    v_space := v_stack_cap - v_rec.quantity;
    v_add := LEAST(v_space, v_remaining);

    UPDATE public.inventory
    SET quantity = quantity + v_add,
        updated_at = now()
    WHERE row_id = v_rec.row_id;

    v_remaining := v_remaining - v_add;
  END LOOP;

  WHILE v_remaining > 0 LOOP
    SELECT s.slot
    INTO v_free_slot
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.inventory inv
      WHERE inv.user_id = p_recipient_id
        AND inv.slot_position = s.slot
        AND inv.is_equipped = false
    )
    ORDER BY s.slot
    LIMIT 1;

    IF v_free_slot IS NULL THEN
      RAISE EXCEPTION 'Envanter dolu.';
    END IF;

    v_add := LEAST(v_max_stack, v_remaining);

    INSERT INTO public.inventory (
      user_id,
      item_id,
      quantity,
      slot_position,
      is_equipped,
      enhancement_level,
      obtained_at,
      max_stack
    ) VALUES (
      p_recipient_id,
      v_row.item_id,
      v_add,
      v_free_slot,
      false,
      COALESCE(v_row.enhancement_level, 0),
      COALESCE(v_row.obtained_at, EXTRACT(EPOCH FROM now())::BIGINT),
      v_max_stack
    );

    v_remaining := v_remaining - v_add;
  END LOOP;

  DELETE FROM public.inventory WHERE row_id = p_row_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_trade_inventory_smoke_test()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_results jsonb := '[]'::jsonb;
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_session_id uuid;
  v_row_stone_a uuid;
  v_row_wood_a uuid;
  v_row_stone_b uuid;
  v_row_wood_b uuid;
  v_row_extra uuid;
  v_check jsonb;
  v_item_stone text;
  v_item_wood text;
  v_item_extra text;
  v_stone_max integer;
  v_wood_max integer;
  v_stone_existing integer;
  v_wood_existing integer;
  v_stone_incoming integer;
  v_wood_incoming integer;
  v_stone_overflow integer;
  v_merged_qty integer;
BEGIN
  SELECT id, max_stack
  INTO v_item_stone, v_stone_max
  FROM public.items
  WHERE COALESCE(is_stackable, false) = true
    AND COALESCE(max_stack, 0) >= 10
  ORDER BY max_stack ASC, id ASC
  LIMIT 1;

  SELECT id, max_stack
  INTO v_item_wood, v_wood_max
  FROM public.items
  WHERE COALESCE(is_stackable, false) = true
    AND COALESCE(max_stack, 0) >= 10
    AND id <> COALESCE(v_item_stone, '')
  ORDER BY max_stack ASC, id ASC
  LIMIT 1;

  SELECT id INTO v_item_extra
  FROM public.items
  WHERE COALESCE(is_stackable, false) = false
    AND id <> ALL (ARRAY[COALESCE(v_item_stone, ''), COALESCE(v_item_wood, '')])
  ORDER BY id
  LIMIT 1;

  IF v_item_stone IS NULL OR v_item_wood IS NULL OR v_item_extra IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Smoke test items missing in catalog',
      'results', v_results
    );
  END IF;

  v_stone_max := public._trade_resolve_max_stack(v_item_stone, v_stone_max);
  v_wood_max := public._trade_resolve_max_stack(v_item_wood, v_wood_max);

  v_stone_incoming := GREATEST(1, v_stone_max / 3);
  v_wood_incoming := GREATEST(1, v_wood_max / 2);
  v_stone_existing := v_stone_max - v_stone_incoming;
  v_wood_existing := v_wood_max - v_wood_incoming;
  v_stone_overflow := v_stone_incoming + 1;

  INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES
    (
      v_user_a,
      'authenticated',
      'authenticated',
      'qa_trade_smoke_a_' || substr(v_user_a::text, 1, 8) || '@test.local',
      now(),
      now(),
      now(),
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object('username', 'qa_trade_smoke_a_' || substr(v_user_a::text, 1, 8))
    ),
    (
      v_user_b,
      'authenticated',
      'authenticated',
      'qa_trade_smoke_b_' || substr(v_user_b::text, 1, 8) || '@test.local',
      now(),
      now(),
      now(),
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object('username', 'qa_trade_smoke_b_' || substr(v_user_b::text, 1, 8))
    );

  v_row_stone_a := gen_random_uuid();
  v_row_wood_a := gen_random_uuid();
  v_row_stone_b := gen_random_uuid();
  v_row_wood_b := gen_random_uuid();

  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, obtained_at, max_stack)
  VALUES
    (v_row_stone_a, v_user_a, v_item_stone, v_stone_existing, 0, false, 0, 1, v_stone_max),
    (v_row_wood_a, v_user_a, v_item_wood, v_wood_existing, 1, false, 0, 2, v_wood_max);

  FOR i IN 2..19 LOOP
    INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, obtained_at)
    VALUES (gen_random_uuid(), v_user_a, v_item_extra, 1, i, false, 0, 10 + i);
  END LOOP;

  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, obtained_at, max_stack)
  VALUES
    (v_row_stone_b, v_user_b, v_item_stone, v_stone_incoming, 0, false, 0, 1, v_stone_max),
    (v_row_wood_b, v_user_b, v_item_wood, v_wood_incoming, 1, false, 0, 2, v_wood_max);

  INSERT INTO public.trade_sessions (id, initiator_id, partner_id, status, partner_accepted_at)
  VALUES (gen_random_uuid(), v_user_a, v_user_b, 'active', now())
  RETURNING id INTO v_session_id;

  INSERT INTO public.trade_items (session_id, owner_id, inventory_row_id)
  VALUES
    (v_session_id, v_user_b, v_row_stone_b),
    (v_session_id, v_user_b, v_row_wood_b);

  v_check := public._trade_validate_recipient_for_session(v_user_a, v_session_id);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'case', 'full_inventory_stack_merge_only',
    'expected', true,
    'actual', COALESCE((v_check->>'success')::boolean, false),
    'stone_max_stack', v_stone_max,
    'wood_max_stack', v_wood_max
  ));

  DELETE FROM public.trade_items WHERE session_id = v_session_id;

  v_row_extra := gen_random_uuid();
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, obtained_at)
  VALUES (v_row_extra, v_user_b, v_item_extra, 1, 2, false, 0, 99);

  INSERT INTO public.trade_items (session_id, owner_id, inventory_row_id)
  VALUES (v_session_id, v_user_b, v_row_extra);

  v_check := public._trade_validate_recipient_for_session(v_user_a, v_session_id);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'case', 'full_inventory_extra_non_stackable_item',
    'expected', false,
    'actual', COALESCE((v_check->>'success')::boolean, false)
  ));

  DELETE FROM public.trade_items WHERE session_id = v_session_id;
  DELETE FROM public.inventory WHERE row_id = v_row_extra;

  UPDATE public.inventory SET quantity = v_stone_overflow WHERE row_id = v_row_stone_b;

  INSERT INTO public.trade_items (session_id, owner_id, inventory_row_id)
  VALUES (v_session_id, v_user_b, v_row_stone_b);

  v_check := public._trade_validate_recipient_for_session(v_user_a, v_session_id);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'case', 'full_inventory_rejects_overflow_stack',
    'expected', false,
    'actual', COALESCE((v_check->>'success')::boolean, false),
    'incoming_qty', v_stone_overflow,
    'stack_room', v_stone_max - v_stone_existing
  ));

  DELETE FROM public.trade_items WHERE session_id = v_session_id;

  UPDATE public.inventory SET quantity = v_stone_incoming WHERE row_id = v_row_stone_b;

  INSERT INTO public.trade_items (session_id, owner_id, inventory_row_id)
  VALUES
    (v_session_id, v_user_a, v_row_stone_a),
    (v_session_id, v_user_b, v_row_stone_b);

  v_check := public._trade_validate_recipient_for_session(v_user_a, v_session_id);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'case', 'cross_trade_outgoing_frees_slot_for_incoming_stack',
    'expected', true,
    'actual', COALESCE((v_check->>'success')::boolean, false)
  ));

  v_check := public._trade_validate_recipient_for_session(v_user_b, v_session_id);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'case', 'partner_receives_outgoing_stone_merge',
    'expected', true,
    'actual', COALESCE((v_check->>'success')::boolean, false)
  ));

  v_merged_qty := LEAST(v_stone_max, v_stone_incoming + v_stone_existing);
  PERFORM public._trade_transfer_inventory_row(v_row_stone_a, v_user_b);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'case', 'transfer_stack_merge',
    'expected', true,
    'actual', EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = v_user_b AND item_id = v_item_stone AND quantity = v_merged_qty
    ),
    'expected_qty', v_merged_qty
  ));

  DELETE FROM public.trade_items WHERE session_id = v_session_id;
  DELETE FROM public.trade_sessions WHERE id = v_session_id;
  DELETE FROM auth.users WHERE id IN (v_user_a, v_user_b);

  RETURN jsonb_build_object(
    'success', NOT EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_results) e
      WHERE (e->>'expected')::boolean IS DISTINCT FROM (e->>'actual')::boolean
    ),
    'results', v_results
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public._trade_resolve_max_stack(text, integer) TO authenticated;

COMMIT;
