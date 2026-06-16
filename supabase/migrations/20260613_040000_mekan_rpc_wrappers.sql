-- Missing Flutter-facing RPC wrappers for mekan system.

-- 1. toggle_mekan_status — owner opens/closes their mekan
CREATE OR REPLACE FUNCTION public.toggle_mekan_status(
  p_mekan_id UUID,
  p_is_open BOOLEAN
) RETURNS JSONB AS $$
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

  IF v_mekan.closed_until IS NOT NULL AND v_mekan.closed_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan polis baskini nedeniyle kapali');
  END IF;

  UPDATE public.mekans SET is_open = p_is_open WHERE id = p_mekan_id AND owner_id = v_auth_id;

  RETURN jsonb_build_object('success', true, 'is_open', p_is_open);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.toggle_mekan_status(UUID, BOOLEAN) TO authenticated;

-- 2. buy_from_mekan — stock row id wrapper (Flutter detail screen)
CREATE OR REPLACE FUNCTION public.buy_from_mekan(
  p_mekan_stock_id UUID,
  p_quantity INT
) RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_stock RECORD;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  IF p_quantity IS NULL OR p_quantity < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz miktar');
  END IF;

  SELECT * INTO v_stock FROM public.mekan_stock WHERE id = p_mekan_stock_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok bulunamadi');
  END IF;

  RETURN public.buy_from_mekan(v_auth_id, v_stock.mekan_id, v_stock.item_id, p_quantity);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.buy_from_mekan(UUID, INT) TO authenticated;

-- 3. buy_from_mekan — simplified wrapper (MASTER_GAMEPLAN / PLAN_07)
CREATE OR REPLACE FUNCTION public.buy_from_mekan(
  p_mekan_id UUID,
  p_item_id TEXT,
  p_quantity INT
) RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  IF p_quantity IS NULL OR p_quantity < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz miktar');
  END IF;

  RETURN public.buy_from_mekan(v_auth_id, p_mekan_id, p_item_id, p_quantity);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.buy_from_mekan(UUID, TEXT, INT) TO authenticated;
