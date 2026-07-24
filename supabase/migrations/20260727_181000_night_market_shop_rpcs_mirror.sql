-- Mirror remote night_market shop RPCs (idempotent).
BEGIN;

CREATE OR REPLACE FUNCTION public.buy_night_market_item(p_offer_id uuid, p_quantity integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_win RECORD;
  v_offer RECORD;
  v_item RECORD;
  v_shadow BOOLEAN := false;
  v_discount NUMERIC := 0;
  v_stock INT;
  v_purchased INT;
  v_unit_price BIGINT;
  v_total BIGINT;
  v_gems NUMERIC;
  v_add JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_quantity < 1 OR p_quantity > 99 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
  END IF;

  SELECT * INTO v_win FROM public._night_market_window();
  IF NOT v_win.active THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gece Pazarı şu an kapalı. Her gün 20:00–22:00 (TR)');
  END IF;

  SELECT o.*, i.name, i.is_stackable, i.max_stack
  INTO v_offer
  FROM public.night_market_offers o
  JOIN public.items i ON i.id = o.item_id
  WHERE o.id = p_offer_id AND o.rotation_week = v_win.rotation_week;

  IF v_offer.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Offer not found');
  END IF;

  SELECT lower(character_class) = 'shadow' INTO v_shadow FROM public.users WHERE auth_id = v_user;
  IF v_shadow THEN v_discount := 0.05; END IF;

  v_stock := v_offer.stock_per_player + CASE WHEN v_shadow THEN 1 ELSE 0 END;
  SELECT COALESCE(quantity, 0) INTO v_purchased
  FROM public.night_market_purchases
  WHERE player_id = v_user AND offer_id = p_offer_id;

  IF v_purchased + p_quantity > v_stock THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz');
  END IF;

  v_unit_price := floor(v_offer.gem_price * (1 - v_discount))::BIGINT;
  v_total := v_unit_price * p_quantity;

  SELECT gems INTO v_gems FROM public.users WHERE auth_id = v_user;
  IF COALESCE(v_gems, 0) < v_total THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
  END IF;

  UPDATE public.users SET gems = gems - v_total WHERE auth_id = v_user;

  v_add := public.add_inventory_item_v2(
    jsonb_build_object('item_id', v_offer.item_id, 'quantity', p_quantity, 'allow_stack', true),
    NULL
  );

  IF COALESCE((v_add->>'success')::BOOLEAN, false) = false THEN
    UPDATE public.users SET gems = gems + v_total WHERE auth_id = v_user;
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_add->>'error', 'Inventory failed'));
  END IF;

  INSERT INTO public.night_market_purchases (player_id, offer_id, quantity)
  VALUES (v_user, p_offer_id, p_quantity)
  ON CONFLICT (player_id, offer_id) DO UPDATE SET
    quantity = night_market_purchases.quantity + EXCLUDED.quantity,
    purchased_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'item_id', v_offer.item_id,
    'quantity', p_quantity,
    'total_cost', v_total,
    'currency', 'gems'
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.get_night_market_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_win RECORD;
  v_offers JSONB;
  v_shadow BOOLEAN := false;
  v_discount NUMERIC := 0;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT * INTO v_win FROM public._night_market_window();
  PERFORM public._ensure_night_market_offers(v_win.rotation_week);

  SELECT lower(character_class) = 'shadow' INTO v_shadow
  FROM public.users WHERE auth_id = v_user;
  IF v_shadow THEN v_discount := 0.05; END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'offer_id', o.id,
    'item_id', o.item_id,
    'item_name', COALESCE(i.name, o.item_id),
    'rarity', i.rarity,
    'icon', i.icon,
    'gem_price', floor(o.gem_price * (1 - v_discount))::BIGINT,
    'base_gem_price', o.gem_price,
    'stock_per_player', o.stock_per_player + CASE WHEN v_shadow THEN 1 ELSE 0 END,
    'purchased', COALESCE(p.quantity, 0),
    'remaining', GREATEST(0, o.stock_per_player + CASE WHEN v_shadow THEN 1 ELSE 0 END - COALESCE(p.quantity, 0))
  ) ORDER BY o.sort_order), '[]'::JSONB)
  INTO v_offers
  FROM public.night_market_offers o
  JOIN public.items i ON i.id = o.item_id
  LEFT JOIN public.night_market_purchases p
    ON p.offer_id = o.id AND p.player_id = v_user
  WHERE o.rotation_week = v_win.rotation_week;

  RETURN jsonb_build_object(
    'success', true,
    'active', v_win.active,
    'starts_at', v_win.starts_at,
    'ends_at', v_win.ends_at,
    'seconds_left', v_win.seconds_left,
    'rotation_week', v_win.rotation_week,
    'shadow_bonus', v_shadow,
    'shadow_discount_pct', CASE WHEN v_shadow THEN 5 ELSE 0 END,
    'offers', COALESCE(v_offers, '[]'::JSONB)
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.qa_force_night_market(p_open boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.night_market_schedule
  SET qa_force_open = COALESCE(p_open, true)
  WHERE id = 1;

  RETURN jsonb_build_object('success', true, 'qa_force_open', COALESCE(p_open, true));
END;
$function$
;


REVOKE ALL ON FUNCTION public.qa_force_night_market(boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.qa_force_night_market(boolean) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_force_night_market(boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_night_market_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.buy_night_market_item(uuid, integer) TO authenticated;

COMMIT;
