-- Player market browse: server-side aggregation + pagination (avoids loading all open orders).

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
      c.max_available_qty
    FROM agg a
    INNER JOIN cheapest c ON c.item_id = a.item_id
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
            f.cheapest_seller_id
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

COMMENT ON FUNCTION public.get_market_tickers(integer, integer, text, text, text, text) IS
  'Aggregated market browse rows (one per item_id) with pagination and filters.';
