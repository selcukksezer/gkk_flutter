-- Drop legacy purchase_market_listing(uuid, int, boolean) overload.
-- PostgREST returned HTTP 300 (ambiguous) when client called with 2 args because
-- both (uuid,int) and (uuid,int,bool default) matched. Legacy fn also used
-- market_orders.id + status='active' instead of order_id + status='open'.

DROP FUNCTION IF EXISTS public.purchase_market_listing(uuid, integer, boolean);

COMMENT ON FUNCTION public.purchase_market_listing(uuid, integer) IS
  'Rate-limited market purchase wrapper; delegates to purchase_market_listing_rl_inner.';
