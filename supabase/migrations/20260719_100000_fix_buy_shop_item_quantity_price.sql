-- ============================================================================
-- FIX: buy_shop_item çoklu alımda toplam fiyat düşmüyordu.
-- Kök neden: canlı DB'de iki overload vardı;
--   * (text,text,integer)        → qty yok, her zaman 1 adet
--   * (text,text,bigint,integer) → qty kadar item verir ama SADECE birim
--     fiyat (p_price) düşer — p_price * p_quantity hesabı yoktu.
-- Çözüm: eski 3-arg overload DROP, 4-arg fonksiyonda v_total := p_price *
-- p_quantity ile bakiye kontrolü + düşüş. Tek overload kalır.
-- ============================================================================

DROP FUNCTION IF EXISTS public.buy_shop_item(TEXT, TEXT, INTEGER);

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

    IF p_price < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid price');
    END IF;

    -- Toplam maliyet: birim fiyat × adet
    v_total := p_price * p_quantity;

    SELECT id, name, base_price, is_stackable, max_stack
    INTO v_item
    FROM public.items
    WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found');
    END IF;

    SELECT gold, gems INTO v_current_gold, v_current_gems
    FROM public.users
    WHERE auth_id = v_user_id OR id = v_user_id
    LIMIT 1;

    v_old_gold := v_current_gold;
    v_old_gems := v_current_gems;

    -- Bakiye kontrolü + düşüş (TOPLAM üzerinden)
    IF p_currency = 'gold' THEN
        IF v_current_gold < v_total THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
        END IF;
        UPDATE public.users
        SET gold = gold - v_total
        WHERE auth_id = v_user_id OR id = v_user_id;
    ELSIF p_currency = 'gems' THEN
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
                    IF p_currency = 'gold' THEN
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
                IF p_currency = 'gold' THEN
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
        IF p_currency = 'gold' THEN
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
        'total_cost', v_total,
        'currency', p_currency
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.buy_shop_item(TEXT, TEXT, BIGINT, INTEGER) TO authenticated;
