-- Mağaza alımlarından %%3 krallık vergisi (mevcut buy_shop_item gövdesine dokunmadan sona ek).

BEGIN;

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
    v_tax BIGINT;
    v_current_gold BIGINT;
    v_current_gems NUMERIC;
    v_old_gold BIGINT;
    v_old_gems NUMERIC;
    v_inventory_slot INT;
    v_existing_row RECORD;
    v_new_quantity INT;
    v_capacity INT := 20;
    v_occupied INT;
    v_blessing RECORD;
    v_discount_pct NUMERIC := 0;
    v_result JSONB;
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

    v_unit_price := GREATEST(COALESCE(v_item.base_price, 0), 0);
    v_currency := v_item.shop_currency;

    IF p_currency IS NOT NULL
       AND lower(trim(p_currency)) <> ''
       AND lower(trim(p_currency)) <> lower(v_currency) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Currency mismatch');
    END IF;

    SELECT * INTO v_blessing FROM public._active_kingdom_market_blessing() LIMIT 1;
    IF v_blessing.expires_at IS NOT NULL THEN
      IF lower(v_currency) = 'gold' AND COALESCE(v_blessing.gold_discount_pct, 0) > 0 THEN
        v_discount_pct := v_blessing.gold_discount_pct;
      ELSIF lower(v_currency) = 'gems' AND COALESCE(v_blessing.gem_discount_pct, 0) > 0 THEN
        v_discount_pct := v_blessing.gem_discount_pct;
      END IF;
      v_unit_price := GREATEST(
        floor(v_unit_price * (1 - v_discount_pct / 100.0))::bigint,
        0
      );
    END IF;

    v_total := v_unit_price * p_quantity;
    v_tax := GREATEST(floor(v_total * 0.03)::bigint, 0);

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

        IF v_tax > 0 THEN
          PERFORM public._kingdom_treasury_credit(
            v_currency, v_tax, 'tax_shop', v_user_id, NULL, 'shop_item', p_item_id,
            format('Mağaza vergisi %s', p_item_id)
          );
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'item_id', p_item_id,
            'quantity', p_quantity,
            'total_cost', v_total,
            'currency', v_currency,
            'king_discount_pct', v_discount_pct,
            'kingdom_tax', v_tax
        );
    EXCEPTION WHEN OTHERS THEN
        IF v_currency = 'gold' THEN
            UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
        ELSE
            UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
        END IF;
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
    END;
END;
$$;

COMMIT;
