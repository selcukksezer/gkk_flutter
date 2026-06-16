-- =========================================================================================
-- MEKAN REDESIGN - PHASE 1: set_mekan_happy_hour + rebuilt buy_from_mekan.
-- buy_from_mekan now applies happy-hour discount, level profit bonus, fame formula,
-- revenue/sales tracking, and Yeralti contraband suspicion + police-raid risk.
-- =========================================================================================

-- Happy hour: owner activates a 1-hour window with 20% buyer discount (PLAN_07 section 7.1).
CREATE OR REPLACE FUNCTION public.set_mekan_happy_hour(p_mekan_id UUID, p_active BOOLEAN)
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_mekan RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND owner_id = v_auth_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi veya size ait degil');
  END IF;

  IF p_active THEN
    UPDATE public.mekans SET happy_hour_until = now() + INTERVAL '1 hour' WHERE id = p_mekan_id;
    RETURN jsonb_build_object('success', true, 'happy_hour_until', (now() + INTERVAL '1 hour'));
  ELSE
    UPDATE public.mekans SET happy_hour_until = NULL WHERE id = p_mekan_id;
    RETURN jsonb_build_object('success', true, 'happy_hour_until', NULL);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.set_mekan_happy_hour(UUID, BOOLEAN) TO authenticated;

-- Core buy. Wrappers (mekan_id+item_id / stock_id) delegate to this 4-arg form.
CREATE OR REPLACE FUNCTION public.buy_from_mekan(
  p_buyer_id UUID,
  p_mekan_id UUID,
  p_item_id TEXT,
  p_quantity INT
) RETURNS JSONB AS $$
DECLARE
  v_stock RECORD;
  v_mekan RECORD;
  v_gross BIGINT;
  v_buyer_pays BIGINT;
  v_owner_profit BIGINT;
  v_buyer_gold BIGINT;
  v_add_res JSONB;
  v_happy BOOLEAN := false;
  v_profit_bonus NUMERIC;
  v_is_contraband BOOLEAN;
  v_raid BOOLEAN := false;
  v_raid_chance NUMERIC;
  v_penalty BIGINT := 0;
  v_stock_value BIGINT;
BEGIN
  IF p_buyer_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;

  IF NOT public.mekan_is_stock_eligible(p_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu esya mekandan satilamaz');
  END IF;

  IF p_quantity IS NULL OR p_quantity < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz miktar');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND is_open = true FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan kapali veya bulunamadi');
  END IF;

  IF v_mekan.closed_until IS NOT NULL AND v_mekan.closed_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan polis baskini nedeniyle kapali');
  END IF;

  IF p_buyer_id = v_mekan.owner_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi mekaninizdan satin alamazsiniz');
  END IF;

  SELECT * INTO v_stock FROM public.mekan_stock
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id AND quantity >= p_quantity
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz');
  END IF;

  -- Pricing: gross -> happy-hour discount for buyer -> level profit bonus for owner.
  v_gross := v_stock.sell_price * p_quantity;
  v_happy := v_mekan.happy_hour_until IS NOT NULL AND v_mekan.happy_hour_until > now();
  IF v_happy THEN
    v_buyer_pays := floor(v_gross * 0.80)::BIGINT;
  ELSE
    v_buyer_pays := v_gross;
  END IF;

  v_profit_bonus := public.mekan_profit_bonus_pct(v_mekan.level);
  v_owner_profit := floor(v_buyer_pays * (1 + v_profit_bonus))::BIGINT;

  SELECT gold INTO v_buyer_gold FROM public.users WHERE auth_id = p_buyer_id FOR UPDATE;
  IF v_buyer_gold < v_buyer_pays THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gold yetersiz');
  END IF;

  -- Deliver item first (inventory may be full).
  v_add_res := public.add_inventory_item_v2(
    jsonb_build_object('item_id', p_item_id, 'quantity', p_quantity, 'allow_stack', true),
    NULL
  );
  IF v_add_res IS NULL OR (v_add_res->>'success')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_add_res->>'error', 'Envanter dolu'));
  END IF;

  UPDATE public.users SET gold = gold - v_buyer_pays WHERE auth_id = p_buyer_id AND gold >= v_buyer_pays;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda altin yetersiz kaldi');
  END IF;

  UPDATE public.users SET gold = gold + v_owner_profit WHERE auth_id = v_mekan.owner_id;

  UPDATE public.mekan_stock SET quantity = quantity - p_quantity
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id;

  INSERT INTO public.mekan_sales (mekan_id, buyer_id, item_id, quantity, price_per_unit, total_price, owner_profit)
  VALUES (p_mekan_id, p_buyer_id, p_item_id,
          p_quantity,
          CASE WHEN p_quantity > 0 THEN (v_buyer_pays / p_quantity) ELSE v_buyer_pays END,
          v_buyer_pays, v_owner_profit);

  -- Fame formula (PLAN_07 section 6.2 approximation): revenue + customer contribution + level weight.
  UPDATE public.mekans
  SET fame = fame + GREATEST(1, floor(v_buyer_pays * 0.001)::INT) + 1 + (level / 2),
      total_revenue = total_revenue + v_owner_profit,
      total_sales = total_sales + p_quantity
  WHERE id = p_mekan_id;

  -- Contraband: raise suspicion and roll for a police raid (PLAN_07 section 8).
  v_is_contraband := public.mekan_is_contraband(p_item_id);
  IF v_is_contraband AND v_mekan.mekan_type = 'yeralti' THEN
    UPDATE public.mekans
    SET suspicion = LEAST(100, suspicion + 5 * p_quantity)
    WHERE id = p_mekan_id
    RETURNING suspicion INTO v_mekan.suspicion;

    v_raid_chance := 0.02 + (v_mekan.suspicion::numeric / 100.0) * 0.30;
    IF random() <= v_raid_chance THEN
      v_raid := true;

      SELECT COALESCE(SUM(quantity * sell_price), 0) INTO v_stock_value
      FROM public.mekan_stock WHERE mekan_id = p_mekan_id;
      v_penalty := floor(v_stock_value * 0.50)::BIGINT;

      UPDATE public.users SET gold = GREATEST(0, gold - v_penalty) WHERE auth_id = v_mekan.owner_id;
      UPDATE public.mekans
      SET is_open = false,
          closed_until = now() + INTERVAL '48 hours',
          fame = GREATEST(0, fame - 500),
          suspicion = 0
      WHERE id = p_mekan_id;
      -- Owner also goes to prison for 24h (PLAN_07 section 8.3).
      UPDATE public.users
      SET prison_until = now() + INTERVAL '24 hours'
      WHERE auth_id = v_mekan.owner_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'total_price', v_buyer_pays,
    'happy_hour', v_happy,
    'police_raid', v_raid,
    'penalty', v_penalty
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.buy_from_mekan(UUID, UUID, TEXT, INT) TO authenticated;
