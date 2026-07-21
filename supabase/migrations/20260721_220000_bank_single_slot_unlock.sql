-- Bank slot unlock: 5 gems per slot, +1 slot per purchase (sequential).
-- Replaces batch +25 expansion with tiered pricing.

DROP FUNCTION IF EXISTS public.expand_bank_slots(integer);

CREATE FUNCTION public.expand_bank_slots(p_num_expansions integer DEFAULT 1)
RETURNS TABLE (
  success boolean,
  message text,
  total_gems_spent integer,
  new_total_slots integer,
  player_gems_remaining integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_current_slots integer;
  v_slot_cost constant integer := 5;
  v_new_slots integer;
  v_current_gems integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::text, 0::integer, 0::integer, 0::integer;
    RETURN;
  END IF;

  SELECT total_slots INTO v_current_slots
  FROM public.user_bank_account
  WHERE user_id = v_user_id;

  IF v_current_slots IS NULL THEN
    RETURN QUERY SELECT false, 'Bank account not found'::text, 0::integer, 0::integer, 0::integer;
    RETURN;
  END IF;

  SELECT gems INTO v_current_gems
  FROM public.users
  WHERE auth_id = v_user_id;

  IF v_current_slots >= 200 THEN
    RETURN QUERY SELECT false, 'Bank at maximum capacity (200 slots)'::text, 0::integer, 200::integer, v_current_gems;
    RETURN;
  END IF;

  IF v_current_gems < v_slot_cost THEN
    RETURN QUERY SELECT false,
      'Insufficient gems. Need ' || v_slot_cost || ', have ' || v_current_gems::text,
      0::integer,
      v_current_slots::integer,
      v_current_gems;
    RETURN;
  END IF;

  UPDATE public.users
  SET gems = gems - v_slot_cost
  WHERE auth_id = v_user_id;

  v_new_slots := v_current_slots + 1;

  UPDATE public.user_bank_account
  SET total_slots = v_new_slots,
      paid_slots_purchased = paid_slots_purchased + 1,
      updated_at = now()
  WHERE user_id = v_user_id;

  INSERT INTO public.bank_transactions
    (user_id, transaction_type, gem_cost, gems_before, gems_after, slots_before, slots_after, success)
  VALUES (
    v_user_id,
    'expand',
    v_slot_cost,
    v_current_gems,
    v_current_gems - v_slot_cost,
    v_current_slots,
    v_new_slots,
    true
  );

  RETURN QUERY SELECT true,
    'Unlocked slot ' || v_new_slots || ' for ' || v_slot_cost || ' gems'::text,
    v_slot_cost::integer,
    v_new_slots::integer,
    (v_current_gems - v_slot_cost)::integer;
END;
$$;

GRANT EXECUTE ON FUNCTION public.expand_bank_slots(integer) TO authenticated;

COMMENT ON FUNCTION public.expand_bank_slots(integer) IS
  'Unlock one bank slot for 5 gems. p_num_expansions is ignored (legacy param).';
