-- Wire assert_player_not_banned into combat/trade/market + staff_adjust_inventory.

BEGIN;

CREATE OR REPLACE FUNCTION public.assert_player_combat_ready(
  p_user_id UUID,
  p_as_target BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_hospital TIMESTAMPTZ;
  v_prison TIMESTAMPTZ;
  v_ban JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Oturum bulunamadı.',
      'error_code', 'not_authenticated'
    );
  END IF;

  v_ban := public.assert_player_not_banned(p_user_id);
  IF (v_ban->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_ban->>'error',
      'error_code', 'account_banned'
    );
  END IF;

  SELECT u.hospital_until, u.prison_until
  INTO v_hospital, v_prison
  FROM public.users u
  WHERE u.auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE WHEN p_as_target THEN 'Rakip bulunamadı.' ELSE 'Oyuncu bulunamadı.' END,
      'error_code', 'player_not_found'
    );
  END IF;

  IF v_hospital IS NOT NULL AND v_hospital > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN p_as_target THEN 'Rakip hastanede.'
        ELSE 'Hastanedesiniz.'
      END,
      'error_code', 'hospital'
    );
  END IF;

  IF v_prison IS NOT NULL AND v_prison > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN p_as_target THEN 'Rakip hapishanede.'
        ELSE 'Hapishanedesiniz.'
      END,
      'error_code', 'prison'
    );
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.initiate_trade(target_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_partner_id UUID;
  v_partner_name text;
  v_session_id UUID;
  v_status text;
  v_initiator_id UUID;
  v_partner_online boolean;
  v_last_active timestamptz;
  v_ban JSONB;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_ban := public.assert_player_not_banned(v_uid);
  IF (v_ban->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_ban->>'error');
  END IF;

  PERFORM public._trade_expire_stale_sessions();

  IF public._trade_is_banned(v_uid) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret yasağınız var. 12 saat sonra tekrar deneyin.');
  END IF;

  SELECT auth_id, username INTO v_partner_id, v_partner_name
  FROM public.users WHERE username = target_username;

  IF v_partner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı: ' || target_username);
  END IF;
  IF v_partner_id = v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinizle ticaret yapamazsınız.');
  END IF;

  v_ban := public.assert_player_not_banned(v_partner_id);
  IF (v_ban->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Karşı oyuncunun hesabı askıda.');
  END IF;

  IF public._trade_is_blocked(v_uid, v_partner_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu oyuncu ile ticaret engelli.');
  END IF;

  IF public._trade_is_banned(v_partner_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Karşı oyuncunun ticaret yasağı var.');
  END IF;

  SELECT id, status, initiator_id
  INTO v_session_id, v_status, v_initiator_id
  FROM public.trade_sessions
  WHERE (
      (status = 'pending')
      OR (status = 'active' AND partner_accepted_at IS NOT NULL)
    )
    AND ((initiator_id = v_uid AND partner_id = v_partner_id)
      OR (initiator_id = v_partner_id AND partner_id = v_uid))
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_session_id IS NOT NULL THEN
    IF v_status = 'pending' AND v_initiator_id = v_uid THEN
      RETURN jsonb_build_object('success', false, 'error', 'Zaten bekleyen bir ticaret davetiniz var.');
    ELSIF v_status = 'active' THEN
      RETURN jsonb_build_object('success', true, 'session_id', v_session_id, 'status', v_status);
    ELSE
      RETURN jsonb_build_object('success', true, 'session_id', v_session_id, 'status', v_status);
    END IF;
  END IF;

  SELECT is_online, last_active_at INTO v_partner_online, v_last_active
  FROM public.users WHERE auth_id = v_partner_id;

  IF COALESCE(v_partner_online, false) = false
     OR v_last_active IS NULL
     OR v_last_active < now() - interval '5 minutes' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu çevrimdışı.');
  END IF;

  INSERT INTO public.trade_sessions (initiator_id, partner_id, status)
  VALUES (v_uid, v_partner_id, 'pending')
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'partner_name', v_partner_name,
    'status', 'pending'
  );
END;
$$;

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
  v_ban JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Giris yapmalisiniz';
  END IF;

  v_ban := public.assert_player_not_banned(v_user_id);
  IF (v_ban->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION '%', v_ban->>'error';
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
  END IF;

  IF NOT public.market_can_add_items(v_user_id, 1) THEN
    RAISE EXCEPTION 'Pazar slot limiti dolu';
  END IF;

  v_total := v_qty * p_price;
  v_fee := GREATEST(1, (v_total * 0.05)::INT);
  v_seller_receives := v_total - v_fee;

  IF v_row.catalog_stackable AND v_qty < v_row.quantity THEN
    UPDATE public.inventory SET quantity = quantity - v_qty WHERE row_id = p_item_row_id;
  ELSE
    DELETE FROM public.inventory WHERE row_id = p_item_row_id;
  END IF;

  INSERT INTO public.market_orders (
    seller_id, inventory_row_id, item_id, item_name, item_type, rarity,
    is_stackable, max_stack, enhancement_level, side, quantity, price, fee, status
  ) VALUES (
    v_user_id, p_item_row_id, v_row.item_id, COALESCE(v_row.catalog_name, v_row.item_name, 'Esya'),
    v_row.catalog_type, v_row.catalog_rarity, v_row.catalog_stackable, v_row.catalog_max_stack,
    COALESCE(v_row.enhancement_level, 0), 'sell', v_qty, p_price, v_fee, 'open'
  ) RETURNING order_id INTO v_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'fee', v_fee,
    'seller_receives', v_seller_receives
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.staff_adjust_inventory(
  p_target_user_id UUID,
  p_item_id TEXT,
  p_quantity_delta INT,
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
  v_delta INT := COALESCE(p_quantity_delta, 0);
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.adjust_inventory');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF v_delta > 0 THEN
    IF NOT public.market_give_items(p_target_user_id, p_item_id, v_delta, 0) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu.');
    END IF;
  ELSIF v_delta < 0 THEN
    UPDATE public.inventory
    SET quantity = quantity + v_delta
    WHERE user_id = p_target_user_id
      AND item_id = p_item_id
      AND quantity >= ABS(v_delta);
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yeterli item yok.');
    END IF;
    DELETE FROM public.inventory WHERE user_id = p_target_user_id AND item_id = p_item_id AND quantity <= 0;
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'player.adjust_inventory', 'adjust_inventory', 'user', p_target_user_id::text,
    jsonb_build_object('item_id', p_item_id, 'delta', v_delta, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_adjust_inventory(uuid, text, int, text) TO authenticated;

COMMIT;
