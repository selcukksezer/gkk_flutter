-- Fix box claim inventory check (slot-based, not row count) + QA smoke for drop/open/claim.

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

  -- Slot-based free space (box row excluded — its slot frees on consume).
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

  UPDATE public.box_openings
  SET status = 'claimed', claimed_at = now()
  WHERE id = p_opening_id;

  INSERT INTO public.player_loot_box_logs (
    user_id, box_id, spent_currency, spent_amount,
    reward_type, reward_item_id, reward_amount, roll_weight, metadata
  )
  VALUES (
    v_user_id, v_open.box_id, v_open.payment,
    COALESCE(v_open.gems_spent, 0),
    'item', v_drop.item_id, v_reward_qty, v_drop.weight,
    jsonb_build_object(
      'source', 'box_opening',
      'opening_id', p_opening_id,
      'box_name', COALESCE(v_box.name, v_open.box_id),
      'item_name', v_drop.item_name
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

-- QA: drop box into inventory, gem-open, claim, double-claim guard.
CREATE OR REPLACE FUNCTION public.qa_box_opening_smoke()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := gen_random_uuid();
  v_row_box uuid := gen_random_uuid();
  v_row uuid;
  v_i int;
  v_start jsonb;
  v_claim jsonb;
  v_claim2 jsonb;
  v_opening_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);

  DELETE FROM public.box_openings WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_box_open'
  );
  DELETE FROM public.inventory WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_box_open'
  );
  DELETE FROM auth.users WHERE email = 'qa_box_open@sim.local';
  DELETE FROM public.users WHERE username = 'qa_box_open';

  INSERT INTO auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) VALUES (
    v_auth, 'authenticated', 'authenticated',
    'qa_box_open@sim.local', now(), now(), now(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('username', 'qa_box_open', 'is_bot', true)
  );

  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
    attack, defense, health, max_health, power, gems, created_at, updated_at
  ) VALUES (
    v_auth, v_auth, 'qa_box_open', 'qa_box_open@sim.local', 'QA Box Open',
    10, 1000, 500000, 100, 100, 30, 25, 120, 120, 200, 500, now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET gems = 500, username = EXCLUDED.username;

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);

  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped)
  VALUES (v_row_box, v_auth, 'box_weapon_common', 1, 0, false);
  v_start := public.start_box_opening(v_row_box, 'gems');
  v_opening_id := (v_start->>'opening_id')::uuid;
  v_claim := public.claim_box_reward(v_opening_id);
  v_ok := COALESCE((v_start->>'success')::boolean, false)
      AND COALESCE((v_claim->>'success')::boolean, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'sparse_gem_open_claim', 'area', 'loot_box', 'pass', v_ok,
    'detail', jsonb_build_object('start', v_start, 'claim', v_claim)
  ));

  DELETE FROM public.box_openings WHERE user_id = v_auth;
  DELETE FROM public.inventory WHERE user_id = v_auth;

  v_row_box := gen_random_uuid();
  FOR v_i IN 0..18 LOOP
    INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped)
    VALUES (gen_random_uuid(), v_auth, 'scroll_upgrade_low', 1, v_i, false);
  END LOOP;
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped)
  VALUES (v_row_box, v_auth, 'box_weapon_common', 1, 19, false);
  v_start := public.start_box_opening(v_row_box, 'gems');
  v_opening_id := (v_start->>'opening_id')::uuid;
  v_claim := public.claim_box_reward(v_opening_id);
  v_ok := COALESCE((v_start->>'success')::boolean, false)
      AND COALESCE((v_claim->>'success')::boolean, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'full_grid_19_plus_box', 'area', 'loot_box', 'pass', v_ok,
    'detail', jsonb_build_object('start', v_start, 'claim', v_claim)
  ));

  DELETE FROM public.box_openings WHERE user_id = v_auth;
  DELETE FROM public.inventory WHERE user_id = v_auth;

  v_ok := public.dungeon_add_item(v_auth, 'box_weapon_common', 1);
  SELECT row_id INTO v_row FROM public.inventory
  WHERE user_id = v_auth AND item_id = 'box_weapon_common' LIMIT 1;
  v_start := public.start_box_opening(v_row, 'gems');
  v_opening_id := (v_start->>'opening_id')::uuid;
  v_claim := public.claim_box_reward(v_opening_id);
  v_ok := v_ok
      AND COALESCE((v_start->>'success')::boolean, false)
      AND COALESCE((v_claim->>'success')::boolean, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'dungeon_drop_then_open', 'area', 'loot_box', 'pass', v_ok,
    'detail', jsonb_build_object('start', v_start, 'claim', v_claim)
  ));

  DELETE FROM public.box_openings WHERE user_id = v_auth;
  DELETE FROM public.inventory WHERE user_id = v_auth;

  v_row_box := gen_random_uuid();
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped)
  VALUES (v_row_box, v_auth, 'box_weapon_common', 1, 0, false);
  v_start := public.start_box_opening(v_row_box, 'gems');
  v_opening_id := (v_start->>'opening_id')::uuid;
  v_claim := public.claim_box_reward(v_opening_id);
  v_claim2 := public.claim_box_reward(v_opening_id);
  v_ok := COALESCE((v_claim->>'success')::boolean, false)
      AND COALESCE((v_claim2->>'success')::boolean, true) = false
      AND v_claim2->>'error' = 'Açılma kaydı bulunamadı';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'double_claim_not_found', 'area', 'loot_box', 'pass', v_ok,
    'detail', jsonb_build_object('first', v_claim, 'second', v_claim2)
  ));

  DELETE FROM public.box_openings WHERE user_id = v_auth;
  DELETE FROM public.inventory WHERE user_id = v_auth;
  DELETE FROM auth.users WHERE id = v_auth;
  DELETE FROM public.users WHERE auth_id = v_auth;

  RETURN jsonb_build_object(
    'verdict', CASE WHEN NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) t
      WHERE COALESCE((t->>'pass')::boolean, false) = false
    ) THEN 'PASS' ELSE 'FAIL' END,
    'tests', v_results,
    'passed', (SELECT COUNT(*) FROM jsonb_array_elements(v_results) t WHERE (t->>'pass')::boolean),
    'failed', (SELECT COUNT(*) FROM jsonb_array_elements(v_results) t WHERE NOT COALESCE((t->>'pass')::boolean, false)),
    'total', jsonb_array_length(v_results),
    'generated_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_box_opening_smoke() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_box_opening_smoke() TO service_role;
