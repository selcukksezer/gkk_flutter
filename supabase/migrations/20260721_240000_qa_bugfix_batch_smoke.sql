-- QA smoke: bugfix batch (bank 5gem/slot, deposit slots, equip, box limit, weekly LB)
-- Run: SELECT public.qa_smoke_bugfix_batch();

CREATE OR REPLACE FUNCTION public.qa_smoke_bugfix_batch()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := gen_random_uuid();
  v_row_mat uuid := gen_random_uuid();
  v_row_wpn1 uuid := gen_random_uuid();
  v_row_wpn2 uuid := gen_random_uuid();
  v_row_box1 uuid := gen_random_uuid();
  v_row_box2 uuid := gen_random_uuid();
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_gems_before integer;
  v_gems_after integer;
  v_slots_before integer;
  v_slots_after integer;
  v_total integer;
  v_free integer;
  v_bad_slots integer;
  v_dup_slots integer;
  v_dep_hits integer;
  v_inv_qty integer;
  v_remain_qty integer;
  v_withdraw_ok boolean;
  v_expected_slot integer;
  v_expand record;
  v_dep record;
  v_equip jsonb;
  v_box1 jsonb;
  v_box2 jsonb;
  v_lb_cnt integer;
  v_lb_weekly_cnt integer;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  -- cleanup prior run (fixed QA identity)
  DELETE FROM public.box_openings WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_bugfix_smoke'
  );
  DELETE FROM public.bank_items WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_bugfix_smoke'
  );
  DELETE FROM public.user_bank_account WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_bugfix_smoke'
  );
  DELETE FROM public.inventory WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_bugfix_smoke'
  );
  DELETE FROM public.dungeon_runs WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_bugfix_smoke'
  );
  DELETE FROM auth.users WHERE email = 'qa_bugfix_smoke@sim.local';
  DELETE FROM public.users WHERE username = 'qa_bugfix_smoke';

  INSERT INTO auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) VALUES (
    v_auth, 'authenticated', 'authenticated',
    'qa_bugfix_smoke@sim.local', now(), now(), now(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('username', 'qa_bugfix_smoke', 'is_bot', true)
  );

  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
    attack, defense, health, max_health, power, gems, created_at, updated_at
  ) VALUES (
    v_auth, v_auth, 'qa_bugfix_smoke', 'qa_bugfix_smoke@sim.local', 'QA Bugfix Smoke',
    10, 1000, 500000, 100, 100, 30, 25, 120, 120, 200, 100, now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    gems = EXCLUDED.gems,
    updated_at = now();

  INSERT INTO public.user_bank_account (user_id, total_slots, used_slots, free_slots_remaining)
  VALUES (v_auth, 100, 0, 100);

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);

  -- BANK-01: expand costs 5 gems, +1 slot
  SELECT gems INTO v_gems_before FROM public.users WHERE auth_id = v_auth;
  SELECT total_slots INTO v_slots_before FROM public.user_bank_account WHERE user_id = v_auth;
  SELECT * INTO v_expand FROM public.expand_bank_slots(1);
  SELECT gems INTO v_gems_after FROM public.users WHERE auth_id = v_auth;
  SELECT total_slots INTO v_slots_after FROM public.user_bank_account WHERE user_id = v_auth;
  v_ok := COALESCE(v_expand.success, false)
      AND COALESCE(v_expand.total_gems_spent, 0) = 5
      AND v_gems_after = v_gems_before - 5
      AND v_slots_after = v_slots_before + 1;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_expand_5_gems_one_slot',
    'area', 'bank',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'gems_before', v_gems_before, 'gems_after', v_gems_after,
      'slots_before', v_slots_before, 'slots_after', v_slots_after,
      'rpc', row_to_json(v_expand)
    )
  ));

  -- BANK-02: first free slot always < total_slots
  SELECT total_slots INTO v_total FROM public.user_bank_account WHERE user_id = v_auth;
  v_free := public.bank_first_free_slot(v_auth, v_total);
  v_ok := v_free IS NOT NULL AND v_free < v_total;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_first_free_slot_within_unlocked',
    'area', 'bank',
    'pass', v_ok,
    'detail', jsonb_build_object('total_slots', v_total, 'free_slot', v_free)
  ));

  -- BANK-03: fill all unlocked slots; full bank rejects new stack (no locked-slot writes)
  SELECT total_slots INTO v_total FROM public.user_bank_account WHERE user_id = v_auth;
  DELETE FROM public.bank_items WHERE user_id = v_auth;
  INSERT INTO public.bank_items (user_id, item_id, category, slot_position, quantity)
  SELECT v_auth, 'res_mining_common', 'material', gs - 1, 1
  FROM generate_series(1, v_total) gs;
  UPDATE public.user_bank_account
  SET used_slots = v_total, updated_at = now()
  WHERE user_id = v_auth;

  DELETE FROM public.inventory WHERE row_id = v_row_mat;
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped)
  VALUES (v_row_mat, v_auth, 'potion_energy_minor', 10, 1, false);

  SELECT * INTO v_dep FROM public.deposit_to_bank(ARRAY[v_row_mat], ARRAY[5]);
  SELECT COUNT(*) INTO v_bad_slots
  FROM public.bank_items
  WHERE user_id = v_auth AND slot_position >= v_total;

  SELECT quantity INTO v_inv_qty FROM public.inventory WHERE row_id = v_row_mat;
  v_ok := v_bad_slots = 0 AND COALESCE(v_inv_qty, 0) = 10;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_full_no_deposit_to_locked_slots',
    'area', 'bank',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'total_slots', v_total,
      'bad_slots_gte_total', v_bad_slots,
      'inventory_qty_unchanged', v_inv_qty,
      'deposit_rpc', row_to_json(v_dep)
    )
  ));

  -- BANK-04: unlock one slot then deposit lands in new slot index
  SELECT * INTO v_expand FROM public.expand_bank_slots(1);
  SELECT total_slots INTO v_total FROM public.user_bank_account WHERE user_id = v_auth;
  v_expected_slot := v_total - 1;
  SELECT * INTO v_dep FROM public.deposit_to_bank(ARRAY[v_row_mat], ARRAY[3]);
  SELECT COUNT(*) INTO v_dep_hits FROM public.bank_items
  WHERE user_id = v_auth AND slot_position = v_expected_slot AND quantity >= 3;
  v_ok := COALESCE(v_dep_hits, 0) >= 1;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_unlock_then_deposit_new_slot',
    'area', 'bank',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'total_slots_after_unlock', v_total,
      'expected_slot', v_expected_slot,
      'deposit_rpc', row_to_json(v_dep)
    )
  ));

  -- BANK-05: no duplicate slot_position per user
  SELECT COUNT(*) INTO v_dup_slots
  FROM (
    SELECT slot_position, COUNT(*) c
    FROM public.bank_items
    WHERE user_id = v_auth AND slot_position IS NOT NULL
    GROUP BY slot_position
    HAVING COUNT(*) > 1
  ) d;
  v_ok := v_dup_slots = 0;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_no_duplicate_slot_positions',
    'area', 'bank',
    'pass', v_ok,
    'detail', jsonb_build_object('duplicate_slot_groups', v_dup_slots)
  ));

  -- BANK-06: second expand +5 gems, +1 slot
  SELECT gems INTO v_gems_before FROM public.users WHERE auth_id = v_auth;
  SELECT total_slots INTO v_slots_before FROM public.user_bank_account WHERE user_id = v_auth;
  SELECT * INTO v_expand FROM public.expand_bank_slots(1);
  SELECT gems INTO v_gems_after FROM public.users WHERE auth_id = v_auth;
  SELECT total_slots INTO v_slots_after FROM public.user_bank_account WHERE user_id = v_auth;
  v_ok := COALESCE(v_expand.success, false)
      AND v_gems_after = v_gems_before - 5
      AND v_slots_after = v_slots_before + 1;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_second_expand_5_gems',
    'area', 'bank',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'slots_before', v_slots_before, 'slots_after', v_slots_after,
      'gems_spent', v_expand.total_gems_spent
    )
  ));

  -- BANK-09: expand blocked when insufficient gems
  UPDATE public.users SET gems = 2 WHERE auth_id = v_auth;
  SELECT * INTO v_expand FROM public.expand_bank_slots(1);
  v_ok := COALESCE(v_expand.success, false) = false;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_expand_blocked_insufficient_gems',
    'area', 'bank',
    'pass', v_ok,
    'detail', row_to_json(v_expand)
  ));
  UPDATE public.users SET gems = 500 WHERE auth_id = v_auth;

  -- BANK-07: at max slots expand fails
  DELETE FROM public.bank_items WHERE user_id = v_auth;
  UPDATE public.user_bank_account
  SET total_slots = 200, used_slots = 0, updated_at = now()
  WHERE user_id = v_auth;
  SELECT * INTO v_expand FROM public.expand_bank_slots(1);
  v_ok := COALESCE(v_expand.success, false) = false;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_expand_blocked_at_max_200',
    'area', 'bank',
    'pass', v_ok,
    'detail', row_to_json(v_expand)
  ));

  -- Reset bank for withdraw test
  UPDATE public.user_bank_account
  SET total_slots = 100, used_slots = 1, updated_at = now()
  WHERE user_id = v_auth;
  DELETE FROM public.bank_items WHERE user_id = v_auth;
  INSERT INTO public.bank_items (user_id, item_id, category, slot_position, quantity)
  VALUES (v_auth, 'res_mining_common', 'material', 0, 5);

  -- BANK-08: withdraw reduces bank qty
  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);
  SELECT w.success INTO v_withdraw_ok
  FROM public.withdraw_from_bank(
    (SELECT ARRAY_AGG(id) FROM public.bank_items WHERE user_id = v_auth),
    ARRAY[2]
  ) w
  LIMIT 1;
  SELECT bi.quantity INTO v_remain_qty
  FROM public.bank_items bi
  WHERE bi.user_id = v_auth AND bi.slot_position = 0;
  v_ok := COALESCE(v_withdraw_ok, false) AND COALESCE(v_remain_qty, 0) = 3;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'bank_withdraw_partial_qty',
    'area', 'bank',
    'pass', v_ok,
    'detail', jsonb_build_object('remaining_bank_qty', v_remain_qty, 'withdraw_ok', v_withdraw_ok)
  ));

  -- EQUIP-01: swap weapon without slot collision
  DELETE FROM public.inventory WHERE user_id = v_auth;
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, equip_slot)
  VALUES
    (v_row_wpn1, v_auth, 'wpn_axe_common', 1, 1, false, NULL),
    (v_row_wpn2, v_auth, 'wpn_axe_common', 1, 2, true, 'weapon');

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);
  v_equip := public.equip_item(v_row_wpn1, 'weapon');
  v_ok := COALESCE((v_equip->>'success')::boolean, false)
      AND (
        SELECT COUNT(*)::integer FROM public.inventory
        WHERE user_id = v_auth AND is_equipped = true AND equip_slot = 'weapon'
      ) = 1;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'equip_replace_same_slot_no_collision',
    'area', 'equip',
    'pass', v_ok,
    'detail', v_equip
  ));

  -- BOX-01: only one active opening per user
  DELETE FROM public.box_openings WHERE user_id = v_auth;
  DELETE FROM public.inventory WHERE user_id = v_auth;
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped)
  VALUES
    (v_row_box1, v_auth, 'box_weapon_common', 1, 1, false),
    (v_row_box2, v_auth, 'box_armor_rare', 1, 2, false);
  UPDATE public.users SET gems = 500 WHERE auth_id = v_auth;

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);
  v_box1 := public.start_box_opening(v_row_box1, 'gems');
  v_box2 := public.start_box_opening(v_row_box2, 'gems');
  v_ok := COALESCE((v_box1->>'success')::boolean, false)
      AND COALESCE((v_box2->>'success')::boolean, true) = false;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'box_one_active_opening_per_user',
    'area', 'loot_box',
    'pass', v_ok,
    'detail', jsonb_build_object('first', v_box1, 'second', v_box2)
  ));

  -- LB-01: weekly gold uses dungeon_runs
  DELETE FROM public.dungeon_runs WHERE player_id = v_auth;
  INSERT INTO public.dungeon_runs (
    player_id, dungeon_id, success, gold_earned, xp_earned, player_power, created_at
  ) VALUES (v_auth, 'dng_001', true, 777, 50, 200, now());

  SELECT COUNT(*) INTO v_lb_weekly_cnt
  FROM public.get_leaderboard('gold', 30, 'weekly') lb
  WHERE lb.username = 'qa_bugfix_smoke' AND lb.value = 777;

  SELECT COUNT(*) INTO v_lb_cnt
  FROM public.get_leaderboard('gold', 30, 'alltime') lb
  WHERE lb.username = 'qa_bugfix_smoke';

  v_ok := v_lb_weekly_cnt >= 1;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'leaderboard_weekly_gold_from_dungeon_runs',
    'area', 'leaderboard',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'weekly_hits', v_lb_weekly_cnt,
      'alltime_hits', v_lb_cnt
    )
  ));

  -- cleanup temp QA user
  DELETE FROM public.box_openings WHERE user_id = v_auth;
  DELETE FROM public.bank_items WHERE user_id = v_auth;
  DELETE FROM public.user_bank_account WHERE user_id = v_auth;
  DELETE FROM public.inventory WHERE user_id = v_auth;
  DELETE FROM public.dungeon_runs WHERE player_id = v_auth;
  DELETE FROM auth.users WHERE id = v_auth;
  DELETE FROM public.users WHERE auth_id = v_auth;

  RETURN jsonb_build_object(
    'verdict', CASE WHEN NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) t WHERE COALESCE((t->>'pass')::boolean, false) = false
    ) THEN 'PASS' ELSE 'FAIL' END,
    'tests', v_results,
    'passed', (SELECT COUNT(*) FROM jsonb_array_elements(v_results) t WHERE (t->>'pass')::boolean),
    'failed', (SELECT COUNT(*) FROM jsonb_array_elements(v_results) t WHERE NOT COALESCE((t->>'pass')::boolean, false)),
    'total', jsonb_array_length(v_results),
    'generated_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_smoke_bugfix_batch() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_bugfix_batch() TO service_role;
