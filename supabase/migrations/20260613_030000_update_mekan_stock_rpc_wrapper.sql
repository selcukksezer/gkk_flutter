-- Flutter calls update_mekan_stock(p_mekan_id, p_item_id, p_quantity, p_sell_price).
-- Existing RPC uses p_owner_id + p_new_quantity + p_price. Wrapper delegates with auth.uid().

CREATE OR REPLACE FUNCTION public.update_mekan_stock(
  p_mekan_id UUID,
  p_item_id TEXT,
  p_quantity INT,
  p_sell_price BIGINT
) RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  RETURN public.update_mekan_stock(
    v_auth_id,
    p_mekan_id,
    p_item_id,
    p_quantity,
    p_sell_price
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.update_mekan_stock(UUID, TEXT, INT, BIGINT) TO authenticated;
