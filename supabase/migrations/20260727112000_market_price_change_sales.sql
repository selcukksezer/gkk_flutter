-- Market: 24h price change in tickers, seller sale inbox notification,
-- and personal trade history RPC.

BEGIN;

-- ── get_market_tickers: price_change from market_history ─────────────────────

CREATE OR REPLACE FUNCTION public.get_market_tickers(
  p_limit integer DEFAULT 48,
  p_offset integer DEFAULT 0,
  p_search text DEFAULT NULL,
  p_item_type text DEFAULT NULL,
  p_rarity text DEFAULT NULL,
  p_sort text DEFAULT 'price_asc'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 48), 1), 100);
  v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_search text := NULLIF(trim(COALESCE(p_search, '')), '');
  v_item_type text := NULLIF(trim(COALESCE(p_item_type, '')), '');
  v_rarity text := NULLIF(trim(COALESCE(p_rarity, '')), '');
  v_sort text := COALESCE(NULLIF(trim(p_sort), ''), 'price_asc');
  v_items jsonb;
  v_total integer;
  v_total_listings integer;
BEGIN
  WITH order_rows AS (
    SELECT
      mo.item_id,
      mo.item_name,
      mo.item_type,
      mo.rarity,
      mo.is_stackable,
      mo.price,
      mo.quantity,
      COALESCE(mo.order_id, mo.id) AS order_id,
      COALESCE(mo.seller_id, mo.player_id) AS seller_id,
      mo.created_at
    FROM public.market_orders mo
    WHERE mo.status = 'open'
      AND mo.side = 'sell'
  ),
  agg AS (
    SELECT
      item_id,
      MIN(item_name) AS item_name,
      MIN(item_type) AS item_type,
      MIN(rarity) AS rarity,
      BOOL_OR(is_stackable) AS is_stackable,
      MIN(price) AS lowest_price,
      SUM(quantity)::integer AS volume
    FROM order_rows
    GROUP BY item_id
  ),
  recent_sales AS (
    SELECT item_id, AVG(unit_price)::numeric AS avg_price
    FROM public.market_history
    WHERE COALESCE(sold_at, created_at) >= now() - interval '24 hours'
    GROUP BY item_id
  ),
  prev_sales AS (
    SELECT item_id, AVG(unit_price)::numeric AS avg_price
    FROM public.market_history
    WHERE COALESCE(sold_at, created_at) >= now() - interval '48 hours'
      AND COALESCE(sold_at, created_at) < now() - interval '24 hours'
    GROUP BY item_id
  ),
  cheapest AS (
    SELECT DISTINCT ON (o.item_id)
      o.item_id,
      o.order_id AS cheapest_order_id,
      o.seller_id AS cheapest_seller_id,
      o.quantity AS max_available_qty
    FROM order_rows o
    INNER JOIN agg a ON a.item_id = o.item_id AND o.price = a.lowest_price
    ORDER BY o.item_id, o.created_at ASC
  ),
  merged AS (
    SELECT
      a.item_id,
      a.item_name,
      a.item_type,
      a.rarity,
      a.is_stackable,
      a.lowest_price,
      a.volume,
      c.cheapest_order_id,
      c.cheapest_seller_id,
      c.max_available_qty,
      CASE
        WHEN p.avg_price IS NOT NULL AND p.avg_price > 0 AND r.avg_price IS NOT NULL
          THEN ROUND(((r.avg_price - p.avg_price) / p.avg_price) * 100)::integer
        WHEN r.avg_price IS NOT NULL AND r.avg_price > 0
          THEN ROUND(((a.lowest_price - r.avg_price) / r.avg_price) * 100)::integer
        ELSE 0
      END AS price_change
    FROM agg a
    INNER JOIN cheapest c ON c.item_id = a.item_id
    LEFT JOIN recent_sales r ON r.item_id = a.item_id
    LEFT JOIN prev_sales p ON p.item_id = a.item_id
  ),
  filtered AS (
    SELECT *
    FROM merged m
    WHERE (v_search IS NULL OR m.item_name ILIKE '%' || v_search || '%' OR m.item_type ILIKE '%' || v_search || '%')
      AND (v_item_type IS NULL OR m.item_type = v_item_type)
      AND (v_rarity IS NULL OR m.rarity = v_rarity)
  )
  SELECT
    (SELECT COUNT(*)::integer FROM filtered),
    COALESCE(
      (
        SELECT jsonb_agg(to_jsonb(page_row))
        FROM (
          SELECT
            f.item_id,
            f.item_name,
            f.item_type,
            f.rarity,
            f.is_stackable,
            f.lowest_price,
            f.volume,
            f.max_available_qty,
            f.cheapest_order_id,
            f.cheapest_seller_id,
            f.price_change
          FROM filtered f
          ORDER BY
            CASE WHEN v_sort = 'price_desc' THEN f.lowest_price END DESC NULLS LAST,
            CASE WHEN v_sort != 'price_desc' THEN f.lowest_price END ASC NULLS LAST,
            f.item_name ASC
          LIMIT v_limit OFFSET v_offset
        ) page_row
      ),
      '[]'::jsonb
    )
  INTO v_total, v_items;

  SELECT COUNT(*)::integer INTO v_total_listings
  FROM public.market_orders
  WHERE status = 'open' AND side = 'sell';

  RETURN jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'total_listings', v_total_listings
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_market_tickers(integer, integer, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_market_tickers(integer, integer, text, text, text, text) TO anon;

-- ── purchase: notify seller via player inbox ─────────────────────────────────

CREATE OR REPLACE FUNCTION public._notify_market_sale(
  p_seller_id uuid,
  p_item_name text,
  p_quantity integer,
  p_seller_credit integer,
  p_currency text,
  p_order_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.player_inbox_notifications (user_id, kind, title, body, payload)
  VALUES (
    p_seller_id,
    'market_sale',
    'İlanın satıldı',
    p_item_name || ' x' || p_quantity || ' satıldı — ' || p_seller_credit ||
      CASE WHEN lower(COALESCE(p_currency, 'gold')) = 'gems' THEN ' elmas' ELSE ' altın' END ||
      ' hesabına geçti.',
    jsonb_build_object(
      'order_id', p_order_id,
      'item_name', p_item_name,
      'quantity', p_quantity,
      'seller_credit', p_seller_credit,
      'currency', lower(COALESCE(p_currency, 'gold'))
    )
  );
EXCEPTION WHEN OTHERS THEN
  NULL; -- notification failure must never break the purchase
END;
$$;

DO $patch$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('public.purchase_market_listing_rl_inner(uuid, integer)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL OR position('_notify_market_sale' IN v_def) > 0 THEN
    RETURN;
  END IF;

  v_def := replace(
    v_def,
    'RETURN jsonb_build_object(
    ''success'', true,
    ''quantity'', v_buy_qty,',
    'PERFORM public._notify_market_sale(
    v_order.seller_id, v_order.item_name, v_buy_qty, v_seller_credit, v_cur, p_order_id
  );

  RETURN jsonb_build_object(
    ''success'', true,
    ''quantity'', v_buy_qty,'
  );

  IF position('_notify_market_sale' IN v_def) > 0 THEN
    EXECUTE v_def;
  END IF;
END;
$patch$;

-- ── get_my_market_history: sales + purchases of the caller ───────────────────

CREATE OR REPLACE FUNCTION public.get_my_market_history(
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 30), 1), 100);
  v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_rows jsonb;
  v_total integer;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT COUNT(*)::integer INTO v_total
  FROM public.market_history h
  WHERE h.seller_id = v_me OR h.buyer_id = v_me;

  SELECT COALESCE(jsonb_agg(to_jsonb(row_data)), '[]'::jsonb) INTO v_rows
  FROM (
    SELECT
      h.id,
      h.item_id,
      h.item_name,
      h.quantity,
      h.unit_price,
      h.total_price,
      COALESCE(h.fee, h.market_fee, 0) AS fee,
      CASE WHEN h.seller_id = v_me THEN 'sale' ELSE 'purchase' END AS role,
      CASE
        WHEN h.seller_id = v_me
          THEN COALESCE(b.display_name, b.username, 'Oyuncu')
        ELSE COALESCE(s.display_name, s.username, 'Oyuncu')
      END AS counterparty,
      COALESCE(h.sold_at, h.created_at) AS traded_at
    FROM public.market_history h
    LEFT JOIN public.users b ON b.auth_id = h.buyer_id
    LEFT JOIN public.users s ON s.auth_id = h.seller_id
    WHERE h.seller_id = v_me OR h.buyer_id = v_me
    ORDER BY COALESCE(h.sold_at, h.created_at) DESC
    LIMIT v_limit OFFSET v_offset
  ) row_data;

  RETURN jsonb_build_object(
    'success', true,
    'total', v_total,
    'items', v_rows
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_market_history(integer, integer) TO authenticated;

COMMIT;
