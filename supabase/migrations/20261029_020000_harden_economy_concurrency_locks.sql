-- ══════════════════════════════════════════════════════════════════════════════
-- Migration: 20261029_020000_harden_economy_concurrency_locks.sql
-- Description: Hardens core transactional economy and item functions against
--              race conditions and duplicate spending using atomic
--              SELECT ... FOR UPDATE row-level locks, negative quantity guards,
--              and search_path = public, pg_temp pinning.
-- ══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. deposit_to_bank with FOR UPDATE locking ──────────────────────────────
CREATE OR REPLACE FUNCTION public.deposit_to_bank(
  p_item_row_ids uuid[],
  p_quantities integer[] DEFAULT NULL
)
RETURNS TABLE (
  success boolean,
  message text,
  deposited_count integer,
  remaining_bank_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_item_row uuid;
  v_idx integer := 1;
  v_item_id text;
  v_inv_quantity integer;
  v_quantity integer;
  v_max_stack integer;
  v_item_category text;
  v_bank_row_id uuid;
  v_bank_row_qty integer;
  v_add integer;
  v_qty_left integer;
  v_max_slots integer;
  v_used_slots integer;
  v_deposited integer := 0;
  v_free_slot integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer;
    RETURN;
  END IF;

  INSERT INTO public.user_bank_account (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  -- Lock user bank account row
  SELECT total_slots, used_slots
  INTO v_max_slots, v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id
  FOR UPDATE;

  FOREACH v_item_row IN ARRAY p_item_row_ids
  LOOP
    -- Lock inventory row to prevent concurrent double-deposit
    SELECT inv.item_id, inv.quantity INTO v_item_id, v_inv_quantity
    FROM public.inventory inv
    WHERE inv.row_id = v_item_row AND inv.user_id = v_user_id
    FOR UPDATE;

    IF v_item_id IS NULL OR v_inv_quantity <= 0 THEN
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
    IF v_quantity <= 0 THEN
      v_idx := v_idx + 1;
      CONTINUE;
    END IF;
    v_quantity := LEAST(v_quantity, v_inv_quantity);
    v_qty_left := v_quantity;

    WHILE v_qty_left > 0 LOOP
      -- Lock matching existing bank stack row
      SELECT bi.id, bi.quantity
      INTO v_bank_row_id, v_bank_row_qty
      FROM public.bank_items bi
      WHERE bi.user_id = v_user_id
        AND bi.item_id = v_item_id
        AND bi.quantity < v_max_stack
      ORDER BY bi.stored_at NULLS LAST, bi.id
      LIMIT 1
      FOR UPDATE;

      IF v_bank_row_id IS NOT NULL THEN
        v_add := LEAST(v_qty_left, v_max_stack - v_bank_row_qty);
        UPDATE public.bank_items
        SET quantity = quantity + v_add,
            updated_at = now()
        WHERE id = v_bank_row_id;

        v_qty_left := v_qty_left - v_add;
        v_deposited := v_deposited + v_add;
      ELSE
        -- Needs new bank slot
        IF v_used_slots >= v_max_slots THEN
          EXIT; -- Bank full
        END IF;

        v_free_slot := public.bank_first_free_slot(v_user_id, v_max_slots);
        IF v_free_slot IS NULL THEN
          EXIT;
        END IF;

        v_add := LEAST(v_qty_left, v_max_stack);
        INSERT INTO public.bank_items (
          user_id, item_id, item_category, quantity, slot_position, stored_at
        ) VALUES (
          v_user_id, v_item_id, v_item_category, v_add, v_free_slot, now()
        );

        v_used_slots := v_used_slots + 1;
        UPDATE public.user_bank_account
        SET used_slots = v_used_slots,
            updated_at = now()
        WHERE user_id = v_user_id;

        v_qty_left := v_qty_left - v_add;
        v_deposited := v_deposited + v_add;
      END IF;
    END LOOP;

    -- Deduct deposited quantity from inventory
    IF v_quantity - v_qty_left > 0 THEN
      IF v_inv_quantity - (v_quantity - v_qty_left) <= 0 THEN
        DELETE FROM public.inventory WHERE row_id = v_item_row;
      ELSE
        UPDATE public.inventory
        SET quantity = quantity - (v_quantity - v_qty_left),
            updated_at = now()
        WHERE row_id = v_item_row;
      END IF;
    END IF;

    v_idx := v_idx + 1;
  END LOOP;

  RETURN QUERY SELECT
    (v_deposited > 0),
    CASE WHEN v_deposited > 0 THEN 'Items deposited successfully' ELSE 'No items could be deposited' END,
    v_deposited,
    GREATEST(0, v_max_slots - v_used_slots);
END;
$$;

GRANT EXECUTE ON FUNCTION public.deposit_to_bank(uuid[], integer[]) TO authenticated;

-- ── 2. withdraw_from_bank with FOR UPDATE locking ───────────────────────────
CREATE OR REPLACE FUNCTION public.withdraw_from_bank(
  p_bank_item_ids uuid[],
  p_quantities integer[] DEFAULT NULL
)
RETURNS TABLE (
  success boolean,
  message text,
  withdrawn_count integer,
  remaining_inventory_slots integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_bank_item_id uuid;
  v_item_id text;
  v_bank_quantity integer;
  v_requested_qty integer;
  v_max_stack integer;
  v_existing_inv_qty integer;
  v_can_stack integer;
  v_will_withdraw integer;
  v_will_remain integer;
  v_add_result jsonb;
  v_withdrawn_total integer := 0;
  v_used_slots integer;
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

  -- Lock bank account
  SELECT used_slots
  INTO v_used_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id
  FOR UPDATE;

  FOR i IN 1..array_length(p_bank_item_ids, 1) LOOP
    v_bank_item_id := p_bank_item_ids[i];

    -- Lock bank item row
    SELECT item_id, quantity INTO v_item_id, v_bank_quantity
    FROM public.bank_items
    WHERE id = v_bank_item_id AND user_id = v_user_id
    FOR UPDATE;

    IF v_item_id IS NULL OR v_bank_quantity <= 0 THEN
      CONTINUE;
    END IF;

    v_requested_qty := v_bank_quantity;
    IF p_quantities IS NOT NULL
       AND array_length(p_quantities, 1) IS NOT NULL
       AND i <= array_length(p_quantities, 1)
       AND p_quantities[i] IS NOT NULL THEN
      IF p_quantities[i] <= 0 THEN
        CONTINUE;
      END IF;
      v_requested_qty := LEAST(v_bank_quantity, p_quantities[i]);
    END IF;

    SELECT max_stack INTO v_max_stack
    FROM public.items
    WHERE id = v_item_id;
    v_max_stack := COALESCE(v_max_stack, 1);

    -- Lock candidate inventory rows for stack addition
    SELECT COALESCE(SUM(quantity), 0) INTO v_existing_inv_qty
    FROM public.inventory
    WHERE user_id = v_user_id
      AND item_id = v_item_id
      AND is_equipped = FALSE
    FOR UPDATE;

    v_can_stack := v_max_stack - (v_existing_inv_qty % v_max_stack);
    IF v_can_stack = v_max_stack AND v_existing_inv_qty > 0 THEN
      v_can_stack := v_max_stack;
    END IF;

    v_will_withdraw := LEAST(v_requested_qty, v_bank_quantity);
    IF v_will_withdraw <= 0 THEN
      CONTINUE;
    END IF;

    v_will_remain := v_bank_quantity - v_will_withdraw;

    -- Add to inventory using canonical helper
    v_add_result := public.add_inventory_item_v2(
      jsonb_build_object(
        'item_id', v_item_id,
        'quantity', v_will_withdraw
      )
    );

    IF (v_add_result->>'success')::boolean THEN
      IF v_will_remain <= 0 THEN
        DELETE FROM public.bank_items WHERE id = v_bank_item_id;
        UPDATE public.user_bank_account
        SET used_slots = GREATEST(0, used_slots - 1),
            updated_at = now()
        WHERE user_id = v_user_id;
      ELSE
        UPDATE public.bank_items
        SET quantity = v_will_remain,
            updated_at = now()
        WHERE id = v_bank_item_id;
      END IF;
      v_withdrawn_total := v_withdrawn_total + v_will_withdraw;
    END IF;
  END LOOP;

  RETURN QUERY SELECT
    (v_withdrawn_total > 0),
    CASE WHEN v_withdrawn_total > 0 THEN 'Items withdrawn successfully' ELSE 'Could not withdraw items' END,
    v_withdrawn_total,
    0::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.withdraw_from_bank(uuid[], integer[]) TO authenticated;

-- ── 3. swap_inventory_bank with FOR UPDATE locking ──────────────────────────
CREATE OR REPLACE FUNCTION public.swap_inventory_bank(
  p_source_id uuid,
  p_source_type text,
  p_target_id uuid DEFAULT NULL,
  p_target_type text DEFAULT 'bank',
  p_quantity integer DEFAULT NULL,
  p_target_slot integer DEFAULT NULL
)
RETURNS TABLE (
  success boolean,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

  -- Lock source item row
  IF p_source_type = 'inventory' THEN
    SELECT item_id, quantity, slot_position INTO v_source_item_id, v_source_qty, v_source_slot
    FROM public.inventory
    WHERE row_id = p_source_id AND user_id = v_user_id
    FOR UPDATE;
  ELSIF p_source_type = 'bank' THEN
    SELECT item_id, quantity, slot_position INTO v_source_item_id, v_source_qty, v_source_slot
    FROM public.bank_items
    WHERE id = p_source_id AND user_id = v_user_id
    FOR UPDATE;
  END IF;

  IF v_source_item_id IS NULL OR v_source_qty <= 0 THEN
    RETURN QUERY SELECT false, 'Source item not found or empty'::text;
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

  -- Lock target item row if specified
  IF p_target_id IS NOT NULL THEN
    IF p_target_type = 'inventory' THEN
      SELECT item_id, quantity, slot_position INTO v_target_item_id, v_target_qty, v_target_slot
      FROM public.inventory
      WHERE row_id = p_target_id AND user_id = v_user_id
      FOR UPDATE;
    ELSIF p_target_type = 'bank' THEN
      SELECT item_id, quantity, slot_position INTO v_target_item_id, v_target_qty, v_target_slot
      FROM public.bank_items
      WHERE id = p_target_id AND user_id = v_user_id
      FOR UPDATE;
    END IF;
  END IF;

  v_target_slot := COALESCE(v_target_slot, p_target_slot);

  IF p_target_type = 'bank'
     AND p_source_type = 'inventory'
     AND v_target_item_id IS NULL
     AND (v_target_slot IS NULL OR v_target_slot < 0) THEN
    SELECT total_slots INTO v_max_bank_slots
    FROM public.user_bank_account
    WHERE user_id = v_user_id
    FOR UPDATE;

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
  v_max_stack := GREATEST(COALESCE(v_max_stack, 1), 1);

  -- Merge stacks if items match
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

  -- Destination is empty slot
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

    -- Transfer between containers
    IF p_source_type = 'inventory' AND p_target_type = 'bank' THEN
      INSERT INTO public.bank_items (user_id, item_id, item_category, quantity, slot_position, stored_at)
      VALUES (v_user_id, v_source_item_id, 'material', v_actual_transfer, v_target_slot, now());

      UPDATE public.user_bank_account
      SET used_slots = used_slots + 1, updated_at = now()
      WHERE user_id = v_user_id;

      IF v_source_qty - v_actual_transfer <= 0 THEN
        DELETE FROM public.inventory WHERE row_id = p_source_id;
      ELSE
        UPDATE public.inventory SET quantity = quantity - v_actual_transfer, updated_at = now()
        WHERE row_id = p_source_id;
      END IF;

      RETURN QUERY SELECT true, 'Transferred to bank'::text;
      RETURN;
    ELSIF p_source_type = 'bank' AND p_target_type = 'inventory' THEN
      INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, is_equipped, updated_at)
      VALUES (v_user_id, v_source_item_id, v_actual_transfer, v_target_slot, false, now());

      IF v_source_qty - v_actual_transfer <= 0 THEN
        DELETE FROM public.bank_items WHERE id = p_source_id;
        UPDATE public.user_bank_account
        SET used_slots = GREATEST(0, used_slots - 1), updated_at = now()
        WHERE user_id = v_user_id;
      ELSE
        UPDATE public.bank_items SET quantity = quantity - v_actual_transfer, updated_at = now()
        WHERE id = p_source_id;
      END IF;

      RETURN QUERY SELECT true, 'Transferred to inventory'::text;
      RETURN;
    END IF;
  END IF;

  RETURN QUERY SELECT false, 'Unsupported swap operation'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.swap_inventory_bank(uuid, text, uuid, text, integer, integer) TO authenticated;

-- ── 4. expand_bank_slots with FOR UPDATE locking ────────────────────────────
CREATE OR REPLACE FUNCTION public.expand_bank_slots(p_num_expansions integer DEFAULT 1)
RETURNS TABLE (
  success boolean,
  message text,
  total_gems_spent integer,
  new_total_slots integer,
  player_gems_remaining integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_current_slots integer;
  v_slot_cost constant integer := 5;
  v_new_slots integer;
  v_current_gems integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Lock bank account
  SELECT total_slots INTO v_current_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_current_slots IS NULL THEN
    RETURN QUERY SELECT false, 'Bank account not found'::text, 0::integer, 0::integer, 0::integer;
    RETURN;
  END IF;

  -- Lock player gems
  SELECT gems INTO v_current_gems
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF v_current_slots >= 200 THEN
    RETURN QUERY SELECT false, 'Bank at maximum capacity (200 slots)'::text, 0::integer, 200::integer, v_current_gems;
    RETURN;
  END IF;

  IF v_current_gems < v_slot_cost THEN
    RETURN QUERY SELECT false,
      'Insufficient gems. Need ' || v_slot_cost || ', have ' || v_current_gems::text,
      0::integer,
      v_current_slots::integer,
      v_current_gems;
    RETURN;
  END IF;

  UPDATE public.users
  SET gems = gems - v_slot_cost
  WHERE auth_id = v_user_id;

  v_new_slots := v_current_slots + 1;

  UPDATE public.user_bank_account
  SET total_slots = v_new_slots,
      paid_slots_purchased = paid_slots_purchased + 1,
      updated_at = now()
  WHERE user_id = v_user_id;

  INSERT INTO public.bank_transactions (
    user_id, transaction_type, gem_cost, gems_before, gems_after, slots_before, slots_after, success
  ) VALUES (
    v_user_id, 'expand', v_slot_cost, v_current_gems, v_current_gems - v_slot_cost, v_current_slots, v_new_slots, true
  );

  RETURN QUERY SELECT true,
    'Unlocked slot ' || v_new_slots || ' for ' || v_slot_cost || ' gems'::text,
    v_slot_cost::integer,
    v_new_slots::integer,
    (v_current_gems - v_slot_cost)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.expand_bank_slots(integer) TO authenticated;

-- ── 5. bp_claim_reward with FOR UPDATE locking ──────────────────────────────
CREATE OR REPLACE FUNCTION public.bp_claim_reward(
  p_level integer,
  p_is_vip boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_active_season_id uuid;
  v_season_number integer := 1;
  v_status record;
  v_season_reward public.bp_season_rewards;
  v_track text;
  v_item_id text;
  v_qty integer;
  v_gold integer;
  v_gems integer;
  v_added boolean;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum açılmadı.');
  END IF;

  SELECT id, season_number INTO v_active_season_id, v_season_number
  FROM public.bp_seasons WHERE is_active = true
  ORDER BY start_at DESC LIMIT 1;

  IF v_active_season_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Aktif sezon bulunamadı.');
  END IF;

  PERFORM public.bp_ensure_player_initialized();

  -- Lock battle pass player status row to prevent double claims
  SELECT * FROM public.bp_player_status
  WHERE player_id = v_player_id AND season_id = v_active_season_id
  FOR UPDATE
  INTO v_status;

  IF v_status IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Sezon katılımı bulunamadı.');
  END IF;

  IF p_level > v_status.current_level THEN
    RETURN json_build_object('success', false, 'error', 'Bu seviyeye henüz ulaşmadınız.');
  END IF;

  IF p_is_vip THEN
    IF NOT v_status.has_vip THEN
      RETURN json_build_object('success', false, 'error', 'VIP Pass sahibi değilsiniz.');
    END IF;
    IF p_level = ANY(v_status.claimed_vip) THEN
      RETURN json_build_object('success', false, 'error', 'Bu ödül zaten alındı.');
    END IF;
  ELSE
    IF p_level = ANY(v_status.claimed_normal) THEN
      RETURN json_build_object('success', false, 'error', 'Bu ödül zaten alındı.');
    END IF;
  END IF;

  v_track := CASE WHEN p_is_vip THEN 'vip' ELSE 'free' END;
  SELECT * INTO v_season_reward
  FROM public.bp_resolve_season_reward(v_active_season_id, v_track, p_level);

  IF v_season_reward.id IS NOT NULL THEN
    v_gold := COALESCE((v_season_reward.reward_value->>'gold')::integer, 0);
    v_gems := COALESCE((v_season_reward.reward_value->>'gems')::integer, 0);
    v_qty := GREATEST(COALESCE((v_season_reward.reward_value->>'quantity')::integer, 1), 1);

    IF v_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_gold WHERE auth_id = v_player_id;
    END IF;
    IF v_gems > 0 THEN
      UPDATE public.users SET gems = gems + v_gems WHERE auth_id = v_player_id;
    END IF;

    IF NOT p_is_vip AND p_level = 20 THEN
      v_item_id := public.ensure_season_badge_item(v_season_number);
    ELSE
      v_item_id := v_season_reward.item_id;
    END IF;

    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_player_id, v_item_id, v_qty);
      IF NOT v_added THEN
        RETURN json_build_object('success', false, 'error', 'Envanter dolu — ödül alınamadı.');
      END IF;
    END IF;
  END IF;

  -- Atomically register claimed level
  IF p_is_vip THEN
    UPDATE public.bp_player_status
    SET claimed_vip = array_append(claimed_vip, p_level),
        updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  ELSE
    UPDATE public.bp_player_status
    SET claimed_normal = array_append(claimed_normal, p_level),
        updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  END IF;

  RETURN json_build_object('success', true, 'claimed_level', p_level, 'is_vip', p_is_vip);
END;
$$;

GRANT EXECUTE ON FUNCTION public.bp_claim_reward(integer, boolean) TO authenticated;

-- ── 6. claim_quest_reward with FOR UPDATE locking ───────────────────────────
CREATE OR REPLACE FUNCTION public.claim_quest_reward(p_quest_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_status text;
  v_gold integer;
  v_xp integer;
  v_gem integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Lock player quest row
  SELECT status INTO v_status
  FROM public.player_quests
  WHERE user_id = v_user_id AND quest_id = p_quest_id
  FOR UPDATE;

  IF NOT FOUND OR v_status != 'completed' THEN
    RAISE EXCEPTION 'Ödül alınabilir durumda değil.';
  END IF;

  -- Fetch reward quantities
  SELECT gold_reward, xp_reward, gem_reward
  INTO v_gold, v_xp, v_gem
  FROM public.quests
  WHERE quest_id = p_quest_id;

  -- Atomically lock and grant rewards to user
  UPDATE public.users
  SET gold = gold + COALESCE(v_gold, 0),
      xp = xp + COALESCE(v_xp, 0),
      gems = gems + COALESCE(v_gem, 0)
  WHERE auth_id = v_user_id;

  -- Transition status to claimed
  UPDATE public.player_quests
  SET status = 'claimed'
  WHERE user_id = v_user_id AND quest_id = p_quest_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_quest_reward(text) TO authenticated;

COMMIT;
