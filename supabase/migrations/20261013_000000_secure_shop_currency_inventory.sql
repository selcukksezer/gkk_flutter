-- ============================================================================
-- P0 money/security hardening
-- 1) exchange_gems_for_gold — atomic gem→gold packages (server rates)
-- 2) buy_shop_item — catalog price/currency only (ignore client p_price)
-- 3) REVOKE add_inventory_item_v2 FROM authenticated/anon
-- 4) Block direct users.gems/gold UPDATE from authenticated/anon
-- ============================================================================

-- ── 1) Gem → gold exchange ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.exchange_gems_for_gold(p_gems INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_auth_id UUID;
  v_gold BIGINT;
  v_gems INTEGER;
  v_current_gems NUMERIC;
  v_current_gold BIGINT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_gems := p_gems;
  -- Fixed shop packages (must match client catalog)
  v_gold := CASE v_gems
    WHEN 10 THEN 5000
    WHEN 25 THEN 15000
    WHEN 75 THEN 50000
    WHEN 200 THEN 150000
    ELSE NULL
  END;

  IF v_gold IS NULL OR v_gems IS NULL OR v_gems <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid package');
  END IF;

  SELECT gold, gems INTO v_current_gold, v_current_gems
  FROM public.users
  WHERE auth_id = v_auth_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_current_gems < v_gems THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
  END IF;

  UPDATE public.users
  SET gems = gems - v_gems,
      gold = gold + v_gold
  WHERE auth_id = v_auth_id;

  RETURN jsonb_build_object(
    'success', true,
    'gems_spent', v_gems,
    'gold_gained', v_gold,
    'gems', (v_current_gems - v_gems),
    'gold', (v_current_gold + v_gold)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.exchange_gems_for_gold(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.exchange_gems_for_gold(INTEGER) TO authenticated;

-- ── 2) buy_shop_item: server catalog price ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.buy_shop_item(
    p_item_id TEXT,
    p_currency TEXT,
    p_price BIGINT,
    p_quantity INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id UUID;
    v_item RECORD;
    v_unit_price BIGINT;
    v_currency TEXT;
    v_total BIGINT;
    v_current_gold BIGINT;
    v_current_gems NUMERIC;
    v_old_gold BIGINT;
    v_old_gems NUMERIC;
    v_inventory_slot INT;
    v_existing_row RECORD;
    v_new_quantity INT;
    v_capacity INT := 20;
    v_occupied INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    IF p_quantity < 1 OR p_quantity > 999 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
    END IF;

    SELECT
        id,
        name,
        base_price,
        is_stackable,
        max_stack,
        COALESCE(shop_available, false) AS shop_available,
        COALESCE(NULLIF(shop_currency, ''), 'gold') AS shop_currency
    INTO v_item
    FROM public.items
    WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found');
    END IF;

    IF NOT v_item.shop_available THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not in shop');
    END IF;

    -- Client p_price is ignored — catalog is source of truth.
    v_unit_price := GREATEST(COALESCE(v_item.base_price, 0), 0);
    v_currency := v_item.shop_currency;

    IF p_currency IS NOT NULL
       AND lower(trim(p_currency)) <> ''
       AND lower(trim(p_currency)) <> lower(v_currency) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Currency mismatch');
    END IF;

    v_total := v_unit_price * p_quantity;

    SELECT gold, gems INTO v_current_gold, v_current_gems
    FROM public.users
    WHERE auth_id = v_user_id OR id = v_user_id
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not found');
    END IF;

    v_old_gold := v_current_gold;
    v_old_gems := v_current_gems;

    IF v_currency = 'gold' THEN
        IF v_current_gold < v_total THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
        END IF;
        UPDATE public.users
        SET gold = gold - v_total
        WHERE auth_id = v_user_id OR id = v_user_id;
    ELSIF v_currency = 'gems' THEN
        IF v_current_gems < v_total THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
        END IF;
        UPDATE public.users
        SET gems = gems - v_total
        WHERE auth_id = v_user_id OR id = v_user_id;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid currency');
    END IF;

    BEGIN
        IF v_item.is_stackable THEN
            SELECT row_id, quantity INTO v_existing_row
            FROM public.inventory
            WHERE user_id = v_user_id AND item_id = p_item_id AND NOT is_equipped
            LIMIT 1;

            IF v_existing_row.row_id IS NOT NULL THEN
                v_new_quantity := LEAST(
                    v_existing_row.quantity + p_quantity,
                    COALESCE(v_item.max_stack, 999)
                );
                UPDATE public.inventory
                SET quantity = v_new_quantity,
                    updated_at = NOW()
                WHERE row_id = v_existing_row.row_id;
            ELSE
                SELECT COUNT(*) INTO v_occupied
                FROM public.inventory
                WHERE user_id = v_user_id AND NOT is_equipped;

                IF v_occupied >= v_capacity THEN
                    IF v_currency = 'gold' THEN
                        UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
                    ELSE
                        UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
                    END IF;
                    RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
                END IF;

                SELECT s INTO v_inventory_slot
                FROM generate_series(0, v_capacity - 1) s
                WHERE s NOT IN (
                    SELECT slot_position FROM public.inventory
                    WHERE user_id = v_user_id AND slot_position IS NOT NULL
                )
                LIMIT 1;

                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, is_equipped
                ) VALUES (
                    v_user_id, p_item_id, p_quantity, COALESCE(v_inventory_slot, 0), false
                );
            END IF;
        ELSE
            SELECT COUNT(*) INTO v_occupied
            FROM public.inventory
            WHERE user_id = v_user_id AND NOT is_equipped;

            IF v_occupied + p_quantity > v_capacity THEN
                IF v_currency = 'gold' THEN
                    UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
                ELSE
                    UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
                END IF;
                RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
            END IF;

            FOR i IN 1..p_quantity LOOP
                SELECT s INTO v_inventory_slot
                FROM generate_series(0, v_capacity - 1) s
                WHERE s NOT IN (
                    SELECT slot_position FROM public.inventory
                    WHERE user_id = v_user_id AND slot_position IS NOT NULL
                )
                LIMIT 1;

                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, is_equipped
                ) VALUES (
                    v_user_id, p_item_id, 1, COALESCE(v_inventory_slot, i - 1), false
                );
            END LOOP;
        END IF;

    EXCEPTION WHEN OTHERS THEN
        IF v_currency = 'gold' THEN
            UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
        ELSE
            UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
        END IF;
        RETURN jsonb_build_object('success', false, 'error', 'Failed to add item to inventory: ' || SQLERRM);
    END;

    RETURN jsonb_build_object(
        'success', true,
        'item_id', p_item_id,
        'quantity', p_quantity,
        'unit_price', v_unit_price,
        'total_cost', v_total,
        'currency', v_currency
    );
END;
$$;

REVOKE ALL ON FUNCTION public.buy_shop_item(TEXT, TEXT, BIGINT, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.buy_shop_item(TEXT, TEXT, BIGINT, INTEGER) TO authenticated;

-- ── 3) Lock client mint RPC ──────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.add_inventory_item_v2(JSONB, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.add_inventory_item_v2(JSONB, INTEGER) FROM anon;
REVOKE ALL ON FUNCTION public.add_inventory_item_v2(JSONB, INTEGER) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.add_inventory_item_v2(JSONB, INTEGER) TO service_role;
-- Nested calls from SECURITY DEFINER RPCs still work (owner privileges).

-- ── 4) Block direct currency UPDATEs from client roles ───────────────────────

CREATE OR REPLACE FUNCTION public.enforce_users_currency_via_rpc_only()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND (
       NEW.gems IS DISTINCT FROM OLD.gems
       OR NEW.gold IS DISTINCT FROM OLD.gold
     )
     AND current_user IN ('authenticated', 'anon') THEN
    RAISE EXCEPTION 'Direct gems/gold updates are not allowed'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_currency_rpc_only ON public.users;
CREATE TRIGGER trg_users_currency_rpc_only
  BEFORE UPDATE OF gems, gold ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_users_currency_via_rpc_only();
