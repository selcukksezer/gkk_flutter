-- =========================================================================================
-- MEKAN REDESIGN - PHASE 1: upgrade_mekan + monthly rent (PLAN_07 sections 3.1 + 2.1).
-- =========================================================================================

-- Monthly rent per type.
CREATE OR REPLACE FUNCTION public.mekan_monthly_rent(p_type TEXT)
RETURNS BIGINT AS $$
  SELECT CASE p_type
    WHEN 'bar' THEN 500000::BIGINT
    WHEN 'kahvehane' THEN 800000
    WHEN 'dovus_kulubu' THEN 1500000
    WHEN 'luks_lounge' THEN 5000000
    WHEN 'yeralti' THEN 15000000
    ELSE 500000
  END;
$$ LANGUAGE sql IMMUTABLE;

-- Cost to upgrade FROM current level TO current+1 (PLAN_07 section 3.1).
CREATE OR REPLACE FUNCTION public.mekan_upgrade_cost(p_current_level INT)
RETURNS BIGINT AS $$
  SELECT CASE p_current_level
    WHEN 1 THEN 2000000::BIGINT
    WHEN 2 THEN 5000000
    WHEN 3 THEN 10000000
    WHEN 4 THEN 25000000
    WHEN 5 THEN 50000000
    WHEN 6 THEN 100000000
    WHEN 7 THEN 250000000
    WHEN 8 THEN 500000000
    WHEN 9 THEN 1000000000
    ELSE NULL
  END;
$$ LANGUAGE sql IMMUTABLE;

-- Upgrade the caller's mekan by one level.
CREATE OR REPLACE FUNCTION public.upgrade_mekan(p_mekan_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_mekan RECORD;
  v_cost BIGINT;
  v_gold BIGINT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND owner_id = v_auth_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi veya size ait degil');
  END IF;

  IF v_mekan.level >= 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan zaten maksimum seviyede');
  END IF;

  v_cost := public.mekan_upgrade_cost(v_mekan.level);
  IF v_cost IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yukseltme maliyeti hesaplanamadi');
  END IF;

  SELECT gold INTO v_gold FROM public.users WHERE auth_id = v_auth_id FOR UPDATE;
  IF v_gold < v_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gold yetersiz. Gereken: ' || v_cost);
  END IF;

  UPDATE public.users SET gold = gold - v_cost WHERE auth_id = v_auth_id AND gold >= v_cost;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda altin yetersiz kaldi');
  END IF;

  UPDATE public.mekans
  SET level = level + 1,
      fame = fame + 100
  WHERE id = p_mekan_id;

  RETURN jsonb_build_object(
    'success', true,
    'new_level', v_mekan.level + 1,
    'cost', v_cost,
    'new_capacity', public.mekan_total_capacity(v_mekan.mekan_type, v_mekan.level + 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.upgrade_mekan(UUID) TO authenticated;

-- Pay one month of rent; resets the rent clock.
CREATE OR REPLACE FUNCTION public.pay_mekan_rent(p_mekan_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_mekan RECORD;
  v_rent BIGINT;
  v_gold BIGINT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND owner_id = v_auth_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi veya size ait degil');
  END IF;

  v_rent := public.mekan_monthly_rent(v_mekan.mekan_type);

  SELECT gold INTO v_gold FROM public.users WHERE auth_id = v_auth_id FOR UPDATE;
  IF v_gold < v_rent THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gold yetersiz. Kira: ' || v_rent);
  END IF;

  UPDATE public.users SET gold = gold - v_rent WHERE auth_id = v_auth_id AND gold >= v_rent;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda altin yetersiz kaldi');
  END IF;

  -- Extend the rent clock by 30 days from the later of now / current paid_at.
  UPDATE public.mekans
  SET monthly_rent_paid_at = GREATEST(now(), monthly_rent_paid_at)
  WHERE id = p_mekan_id;

  RETURN jsonb_build_object('success', true, 'rent', v_rent);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.pay_mekan_rent(UUID) TO authenticated;
