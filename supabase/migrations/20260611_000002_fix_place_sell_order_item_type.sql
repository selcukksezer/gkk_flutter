-- Hotfix: items table uses "type", not "item_type" (COALESCE still fails if column missing)

CREATE OR REPLACE FUNCTION public.place_sell_order(
  p_item_row_id UUID,
  p_quantity INT,
  p_price INT
) RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_row RECORD;
  v_qty INT;
  v_order_id UUID;
  v_total INT;
  v_seller_receives INT;
  v_fee INT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Giris yapmalisiniz';
  END IF;

  IF p_price IS NULL OR p_price <= 0 THEN
    RAISE EXCEPTION 'Gecerli bir fiyat girin';
  END IF;

  SELECT inv.*,
         i.name AS catalog_name,
         COALESCE(i.type::TEXT, '') AS catalog_type,
         COALESCE(i.rarity::TEXT, 'common') AS catalog_rarity,
         COALESCE(i.is_market_tradeable, true) AS catalog_market_tradeable,
         COALESCE(i.is_han_only, false) AS catalog_han_only,
         COALESCE(i.is_stackable, inv.is_stackable, false) AS catalog_stackable,
         GREATEST(1, COALESCE(i.max_stack, inv.max_stack, 999)) AS catalog_max_stack
  INTO v_row
  FROM public.inventory inv
  JOIN public.items i ON i.id = inv.item_id
  WHERE inv.row_id = p_item_row_id
    AND inv.user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Esya bulunamadi veya size ait degil';
  END IF;

  IF COALESCE(v_row.is_equipped, false) THEN
    RAISE EXCEPTION 'Kusanili esya pazara konulamaz';
  END IF;

  IF COALESCE(v_row.is_tradeable, true) = false THEN
    RAISE EXCEPTION 'Bu esya takas edilemez';
  END IF;

  IF v_row.catalog_market_tradeable = false OR v_row.catalog_han_only = true THEN
    RAISE EXCEPTION 'Bu esya pazarda satilamaz';
  END IF;

  IF v_row.catalog_stackable THEN
    v_qty := GREATEST(1, COALESCE(p_quantity, 1));
    IF v_qty > v_row.quantity THEN
      RAISE EXCEPTION 'Yeterli adet yok (max %)', v_row.quantity;
    END IF;
  ELSE
    v_qty := 1;
    IF v_row.quantity <> 1 THEN
      RAISE EXCEPTION 'Gecersiz envanter satiri';
    END IF;
  END IF;

  v_total := p_price * v_qty;
  v_fee := FLOOR(v_total * 0.05);
  v_seller_receives := v_total - v_fee;
  v_order_id := gen_random_uuid();

  IF v_row.catalog_stackable AND v_qty < v_row.quantity THEN
    UPDATE public.inventory
    SET quantity = quantity - v_qty, updated_at = now()
    WHERE row_id = p_item_row_id AND user_id = v_user_id;
  ELSE
    DELETE FROM public.inventory
    WHERE row_id = p_item_row_id AND user_id = v_user_id;
  END IF;

  INSERT INTO public.market_orders (
    order_id, seller_id, inventory_row_id, item_id, item_name, item_type, rarity,
    is_stackable, max_stack, enhancement_level, side, quantity, price, status, currency
  ) VALUES (
    v_order_id, v_user_id, p_item_row_id, v_row.item_id,
    COALESCE(v_row.catalog_name, 'Bilinmeyen Esya'),
    COALESCE(v_row.catalog_type, ''),
    COALESCE(v_row.catalog_rarity, 'common'),
    v_row.catalog_stackable, v_row.catalog_max_stack,
    COALESCE(v_row.enhancement_level, 0),
    'sell', v_qty, p_price, 'open', 'gold'
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'quantity', v_qty,
    'unit_price', p_price,
    'total', v_total,
    'fee', v_fee,
    'seller_receives', v_seller_receives
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.place_sell_order(UUID, INT, INT) TO authenticated;

CREATE OR REPLACE FUNCTION public.market_list_item(
  p_item_row_id UUID,
  p_quantity INT,
  p_price INT
) RETURNS JSONB AS $$
BEGIN
  RETURN public.place_sell_order(p_item_row_id, p_quantity, p_price);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.market_list_item(UUID, INT, INT) TO authenticated;
