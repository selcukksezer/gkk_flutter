BEGIN;

-- Validate payload + update item_id; return errors instead of CHECK exceptions.
CREATE OR REPLACE FUNCTION public.staff_liveops_upsert_night_market_offer(
  p_offer_id UUID,
  p_payload JSONB,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_item_id TEXT;
  v_price BIGINT;
  v_stock INT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.night_market');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_item_id := NULLIF(trim(p_payload->>'item_id'), '');
  IF v_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya seçilmeli.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id = v_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşya.');
  END IF;

  v_price := COALESCE((p_payload->>'price_gems')::bigint, 0);
  IF v_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas fiyatı 1 veya üzeri olmalı.');
  END IF;

  v_stock := COALESCE((p_payload->>'stock')::int, 0);
  IF v_stock < 1 OR v_stock > 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok 1-3 arası olmalı.');
  END IF;

  IF p_offer_id IS NULL THEN
    INSERT INTO public.night_market_offers (item_id, gem_price, stock_per_player, rotation_week)
    VALUES (
      v_item_id,
      v_price,
      v_stock,
      COALESCE((p_payload->>'rotation_week')::date, CURRENT_DATE)
    );
  ELSE
    UPDATE public.night_market_offers
    SET
      item_id = v_item_id,
      gem_price = v_price,
      stock_per_player = v_stock,
      rotation_week = COALESCE((p_payload->>'rotation_week')::date, rotation_week)
    WHERE id = p_offer_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Teklif bulunamadı.');
    END IF;
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.night_market', 'upsert_night_market', 'night_market', COALESCE(p_offer_id::text, v_item_id),
    jsonb_build_object('payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

COMMIT;
