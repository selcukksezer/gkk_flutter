-- =========================================================================================
-- MEKAN REDESIGN - PHASE 1: update_mekan_stock with price-band + capacity enforcement.
-- Replaces the 5-arg core; the 4-arg auth wrapper (delegates here) is unchanged.
-- =========================================================================================

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
  v_band RECORD;
  v_capacity INT;
  v_other_stock INT;
BEGIN
  IF p_owner_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;

  IF NOT public.mekan_is_stock_eligible(p_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu esya mekan stoguna eklenemez (sadece iksir ve Han itemlari)');
  END IF;

  IF p_new_quantity < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Miktar 0''dan kucuk olamaz');
  END IF;

  IF p_price < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Fiyat 0''dan kucuk olamaz');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND owner_id = p_owner_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi veya size ait degil');
  END IF;

  -- Contraband can only be stocked in Yeralti (PLAN_07 section 8).
  IF public.mekan_is_contraband(p_item_id) AND v_mekan.mekan_type != 'yeralti' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kacak madde sadece Yeralti Imparatorlugunda satilabilir');
  END IF;

  -- Price band enforcement (only when quantity > 0, i.e. an active listing).
  IF p_new_quantity > 0 THEN
    SELECT * INTO v_band FROM public.mekan_price_band(p_item_id);
    IF FOUND THEN
      IF p_price < v_band.min_price THEN
        RETURN jsonb_build_object('success', false, 'error',
          'Fiyat cok dusuk. Min: ' || v_band.min_price);
      END IF;
      IF p_price > v_band.max_price THEN
        RETURN jsonb_build_object('success', false, 'error',
          'Fiyat cok yuksek. Max: ' || v_band.max_price);
      END IF;
    ELSIF p_price < 1 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Fiyat en az 1 olmali');
    END IF;
  END IF;

  SELECT * INTO v_old_stock FROM public.mekan_stock WHERE mekan_id = p_mekan_id AND item_id = p_item_id;
  IF FOUND THEN
    v_old_quantity := v_old_stock.quantity;
  END IF;

  v_diff := p_new_quantity - v_old_quantity;

  -- Capacity check: total units across all stock rows must stay within capacity.
  IF v_diff > 0 THEN
    v_capacity := public.mekan_total_capacity(v_mekan.mekan_type, v_mekan.level);
    SELECT COALESCE(SUM(quantity), 0) INTO v_other_stock
    FROM public.mekan_stock
    WHERE mekan_id = p_mekan_id AND item_id != p_item_id;

    IF (v_other_stock + p_new_quantity) > v_capacity THEN
      RETURN jsonb_build_object('success', false, 'error',
        'Stok kapasitesi asildi (' || v_capacity || '). Mekani yukseltin.');
    END IF;
  END IF;

  IF v_diff > 0 THEN
    SELECT COALESCE(SUM(quantity), 0) INTO v_total_inv
    FROM public.inventory
    WHERE user_id = p_owner_id AND item_id = p_item_id;

    IF v_total_inv < v_diff THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanterinizde yeterli esya yok');
    END IF;

    DECLARE
      v_remaining INT := v_diff;
      v_row RECORD;
    BEGIN
      FOR v_row IN
        SELECT row_id, quantity FROM public.inventory
        WHERE user_id = p_owner_id AND item_id = p_item_id AND quantity > 0 AND COALESCE(is_equipped, false) = false
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

      IF v_remaining > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Envanterinizde yeterli esya yok');
      END IF;
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

GRANT EXECUTE ON FUNCTION public.update_mekan_stock(UUID, UUID, TEXT, INT, BIGINT) TO authenticated;
