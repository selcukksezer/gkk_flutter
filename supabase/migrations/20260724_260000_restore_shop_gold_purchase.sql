-- Restore gem→gold shop purchase (server-side rate; client sends gold amount only).
-- Rate: 600 gold per gem (PLAN_06 / EconomyConstants.shopGoldPerGem).

BEGIN;

CREATE OR REPLACE FUNCTION public.buy_gold_with_gems(p_gold_amount BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_auth_id UUID;
  v_rate CONSTANT BIGINT := 600;
  v_min_gold CONSTANT BIGINT := 600;
  v_max_gold CONSTANT BIGINT := 10000000;
  v_gems INTEGER;
  v_current_gems NUMERIC;
  v_current_gold BIGINT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_gold_amount IS NULL OR p_gold_amount < v_min_gold OR p_gold_amount > v_max_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  v_gems := CEIL(p_gold_amount::NUMERIC / v_rate::NUMERIC)::INTEGER;

  SELECT gold, gems INTO v_current_gold, v_current_gems
  FROM public.users
  WHERE auth_id = v_auth_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_current_gems < v_gems THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
  END IF;

  UPDATE public.users
  SET gems = gems - v_gems,
      gold = gold + p_gold_amount
  WHERE auth_id = v_auth_id;

  RETURN jsonb_build_object(
    'success', true,
    'gems_spent', v_gems,
    'gold_gained', p_gold_amount,
    'gold_per_gem', v_rate,
    'gems', (v_current_gems - v_gems),
    'gold', (v_current_gold + p_gold_amount)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.buy_gold_with_gems(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.buy_gold_with_gems(BIGINT) TO authenticated;

COMMIT;
