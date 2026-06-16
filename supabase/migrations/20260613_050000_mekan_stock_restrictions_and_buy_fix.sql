-- Mekan stock: only potions + han-only items (PLAN_07 §4 + §5).
-- buy_from_mekan: use add_inventory_item_v2 (slot-aware) instead of raw insert.

CREATE OR REPLACE FUNCTION public.mekan_is_stock_eligible(p_item_id TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.items
    WHERE id = p_item_id
      AND (
        COALESCE(is_han_only, false) = true
        OR type = 'potion'
      )
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.update_mekan_stock(
  p_owner_id UUID,
  p_mekan_id UUID,
  p_item_id TEXT,
  p_new_quantity INT,
  p_price BIGINT
) RETURNS JSONB AS $$
DECLARE
  v_mekan RECORD;
  v_old_stock RECORD;
  v_old_quantity INT := 0;
  v_diff INT;
  v_total_inv INT;
BEGIN
  IF p_owner_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  IF NOT public.mekan_is_stock_eligible(p_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu esya mekan stoguna eklenemez (sadece iksir ve Han itemlari)');
  END IF;

  IF p_new_quantity < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Miktar 0''dan küçük olamaz');
  END IF;

  IF p_price < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Fiyat 0''dan küçük olamaz');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND owner_id = p_owner_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadı veya size ait değil');
  END IF;

  SELECT * INTO v_old_stock FROM public.mekan_stock WHERE mekan_id = p_mekan_id AND item_id = p_item_id;
  IF FOUND THEN
    v_old_quantity := v_old_stock.quantity;
  END IF;

  v_diff := p_new_quantity - v_old_quantity;

  IF v_diff > 0 THEN
    SELECT COALESCE(SUM(quantity), 0) INTO v_total_inv
    FROM public.inventory
    WHERE user_id = p_owner_id AND item_id = p_item_id;

    IF v_total_inv < v_diff THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanterinizde yeterli eşya yok');
    END IF;

    DECLARE
      v_remaining INT := v_diff;
      v_row RECORD;
    BEGIN
      FOR v_row IN
        SELECT row_id, quantity FROM public.inventory
        WHERE user_id = p_owner_id AND item_id = p_item_id AND quantity > 0
        ORDER BY quantity ASC
      LOOP
        IF v_remaining <= 0 THEN EXIT; END IF;

        IF v_row.quantity <= v_remaining THEN
          DELETE FROM public.inventory WHERE row_id = v_row.row_id;
          v_remaining := v_remaining - v_row.quantity;
        ELSE
          UPDATE public.inventory SET quantity = quantity - v_remaining WHERE row_id = v_row.row_id;
          v_remaining := 0;
        END IF;
      END LOOP;
    END;
  ELSIF v_diff < 0 THEN
    DECLARE
      v_add_res JSONB;
    BEGIN
      v_add_res := public.add_inventory_item_v2(
        jsonb_build_object('item_id', p_item_id, 'quantity', ABS(v_diff), 'allow_stack', true),
        NULL
      );
      IF v_add_res IS NULL OR (v_add_res->>'success')::boolean IS NOT TRUE THEN
        RETURN jsonb_build_object('success', false, 'error', COALESCE(v_add_res->>'error', 'Envantere geri eklenemedi'));
      END IF;
    END;
  END IF;

  IF p_new_quantity = 0 THEN
    DELETE FROM public.mekan_stock WHERE mekan_id = p_mekan_id AND item_id = p_item_id;
  ELSE
    INSERT INTO public.mekan_stock (mekan_id, item_id, quantity, sell_price, stocked_at)
    VALUES (p_mekan_id, p_item_id, p_new_quantity, p_price, now())
    ON CONFLICT (mekan_id, item_id) DO UPDATE SET
      quantity = EXCLUDED.quantity,
      sell_price = EXCLUDED.sell_price,
      stocked_at = now();
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.buy_from_mekan(
  p_buyer_id UUID,
  p_mekan_id UUID,
  p_item_id TEXT,
  p_quantity INT
) RETURNS JSONB AS $$
DECLARE
  v_stock RECORD;
  v_mekan RECORD;
  v_total_price BIGINT;
  v_owner_profit BIGINT;
  v_buyer_gold BIGINT;
  v_add_res JSONB;
BEGIN
  IF p_buyer_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  IF NOT public.mekan_is_stock_eligible(p_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu esya mekandan satilamaz');
  END IF;

  IF p_quantity IS NULL OR p_quantity < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz miktar');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan kapalı veya bulunamadı');
  END IF;

  SELECT * INTO v_stock FROM public.mekan_stock
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id AND quantity >= p_quantity
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz');
  END IF;

  v_total_price := v_stock.sell_price * p_quantity;

  SELECT gold INTO v_buyer_gold FROM public.users WHERE auth_id = p_buyer_id FOR UPDATE;
  IF v_buyer_gold < v_total_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gold yetersiz');
  END IF;

  IF p_buyer_id = v_mekan.owner_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi mekanınızdan satın alamazsınız');
  END IF;

  v_add_res := public.add_inventory_item_v2(
    jsonb_build_object('item_id', p_item_id, 'quantity', p_quantity, 'allow_stack', true),
    NULL
  );
  IF v_add_res IS NULL OR (v_add_res->>'success')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_add_res->>'error', 'Envanter dolu'));
  END IF;

  v_owner_profit := v_total_price;

  UPDATE public.users SET gold = gold - v_total_price WHERE auth_id = p_buyer_id AND gold >= v_total_price;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'İşlem sırasında altın yetersiz kaldı');
  END IF;

  UPDATE public.users SET gold = gold + v_owner_profit WHERE auth_id = v_mekan.owner_id;

  UPDATE public.mekan_stock SET quantity = quantity - p_quantity
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id;

  INSERT INTO public.mekan_sales (mekan_id, buyer_id, item_id, quantity, price_per_unit, total_price, owner_profit)
  VALUES (p_mekan_id, p_buyer_id, p_item_id, p_quantity, v_stock.sell_price, v_total_price, v_owner_profit);

  UPDATE public.mekans SET fame = fame + p_quantity WHERE id = p_mekan_id;

  RETURN jsonb_build_object('success', true, 'total_price', v_total_price);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
