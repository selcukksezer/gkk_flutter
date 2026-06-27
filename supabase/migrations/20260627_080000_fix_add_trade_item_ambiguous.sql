-- Fix add_trade_item: session_id param shadows table column (42702 ambiguous).

BEGIN;

DROP FUNCTION IF EXISTS public.add_trade_item(uuid, uuid);

CREATE OR REPLACE FUNCTION public.add_trade_item(p_session_id uuid, p_item_row_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_sess RECORD;
  v_inv RECORD;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT * INTO v_sess FROM public.trade_sessions WHERE id = p_session_id FOR UPDATE;
  IF v_sess IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret oturumu bulunamadı.');
  END IF;
  IF v_sess.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret aktif değil.');
  END IF;
  IF v_uid <> v_sess.initiator_id AND v_uid <> v_sess.partner_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu ticaretin katılımcısı değilsiniz.');
  END IF;

  SELECT i.row_id, i.user_id, i.is_equipped,
         COALESCE(it.is_tradeable, true) AS is_tradeable,
         COALESCE(it.is_direct_tradeable, true) AS is_direct_tradeable
  INTO v_inv
  FROM public.inventory i
  LEFT JOIN public.items it ON it.id = i.item_id
  WHERE i.row_id = p_item_row_id
  FOR UPDATE OF i;

  IF v_inv IS NULL OR v_inv.user_id <> v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya envanterinizde yok.');
  END IF;
  IF v_inv.is_equipped THEN
    RETURN jsonb_build_object('success', false, 'error', 'Takılı eşya takas edilemez.');
  END IF;
  IF NOT v_inv.is_tradeable OR NOT v_inv.is_direct_tradeable THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu eşya takas edilemez.');
  END IF;
  IF public._trade_item_in_open_session(p_item_row_id, p_session_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya başka bir ticarette kullanılıyor.');
  END IF;

  INSERT INTO public.trade_items (session_id, owner_id, inventory_row_id)
  VALUES (p_session_id, v_uid, p_item_row_id)
  ON CONFLICT (session_id, inventory_row_id) DO NOTHING;

  UPDATE public.trade_sessions
  SET initiator_confirmed = false,
      partner_confirmed = false,
      updated_at = now()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_trade_item(uuid, uuid) TO authenticated;

COMMIT;
