-- Staff: altın/elmas eksiltme izinleri + RPC.

BEGIN;

INSERT INTO public.staff_permission_catalog (key, category, label_tr, description_tr, min_role, is_dangerous)
VALUES
  ('player.deduct_gold', 'player', 'Altın eksilt', 'Manuel altın düşür', 'gm', true),
  ('player.deduct_gems', 'player', 'Elmas eksilt', 'Manuel elmas düşür', 'admin', true)
ON CONFLICT (key) DO UPDATE SET
  label_tr = EXCLUDED.label_tr,
  description_tr = EXCLUDED.description_tr,
  min_role = EXCLUDED.min_role,
  is_dangerous = EXCLUDED.is_dangerous;

CREATE OR REPLACE FUNCTION public.staff_deduct_currency(
  p_target_user_id UUID,
  p_currency TEXT,
  p_amount BIGINT,
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
  v_mutable JSONB;
  v_auth UUID;
  v_perm TEXT;
  v_amt BIGINT := GREATEST(COALESCE(p_amount, 0), 0);
  v_before BIGINT;
  v_after BIGINT;
BEGIN
  v_perm := CASE lower(COALESCE(p_currency, ''))
    WHEN 'gold' THEN 'player.deduct_gold'
    WHEN 'gems' THEN 'player.deduct_gems'
    ELSE NULL
  END;

  IF v_perm IS NULL OR v_amt <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz para birimi veya miktar.');
  END IF;

  v_guard := public.staff_require_permission(v_actor, v_perm);
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF lower(p_currency) = 'gold' THEN
    SELECT COALESCE(gold, 0) INTO v_before FROM public.users WHERE auth_id = v_auth FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
    END IF;
    v_after := GREATEST(v_before - v_amt, 0);
    UPDATE public.users SET gold = v_after WHERE auth_id = v_auth;
  ELSE
    SELECT COALESCE(gems, 0) INTO v_before FROM public.users WHERE auth_id = v_auth FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
    END IF;
    v_after := GREATEST(v_before - v_amt, 0);
    UPDATE public.users SET gems = v_after WHERE auth_id = v_auth;
  END IF;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'staff_deduct',
    CASE WHEN lower(p_currency) = 'gems' THEN 'Elmas düşürüldü' ELSE 'Altın düşürüldü' END,
    format('Miktar: %s\nÖnce: %s → Sonra: %s\nSebep: %s', v_amt, v_before, v_after, left(p_reason, 300)),
    jsonb_build_object('currency', p_currency, 'amount', v_amt, 'before', v_before, 'after', v_after, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'deduct_currency', 'user', v_auth::text,
    jsonb_build_object('currency', p_currency, 'amount', v_amt, 'before', v_before, 'after', v_after, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object(
    'success', true,
    'before', v_before,
    'after', v_after,
    'deducted', LEAST(v_amt, v_before)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_deduct_currency(uuid, text, bigint, text) TO authenticated;

COMMIT;
