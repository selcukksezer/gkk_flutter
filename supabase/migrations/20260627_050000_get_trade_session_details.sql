-- Live trade session sync for both clients (items + confirm flags).

BEGIN;

CREATE OR REPLACE FUNCTION public.get_trade_session_details(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_sess RECORD;
  v_my_items jsonb;
  v_partner_items jsonb;
  v_partner_name text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT * INTO v_sess FROM public.trade_sessions WHERE id = p_session_id;
  IF v_sess IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret oturumu bulunamadı.');
  END IF;
  IF v_uid <> v_sess.initiator_id AND v_uid <> v_sess.partner_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu ticaretin katılımcısı değilsiniz.');
  END IF;

  IF v_uid = v_sess.initiator_id THEN
    SELECT username INTO v_partner_name FROM public.users WHERE auth_id = v_sess.partner_id;
  ELSE
    SELECT username INTO v_partner_name FROM public.users WHERE auth_id = v_sess.initiator_id;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'row_id', i.row_id,
    'item_id', i.item_id,
    'name', COALESCE(it.name_tr, it.name, i.item_id),
    'quantity', COALESCE(i.quantity, 1),
    'rarity', COALESCE(it.rarity, 'common')
  ) ORDER BY ti.created_at), '[]'::jsonb)
  INTO v_my_items
  FROM public.trade_items ti
  JOIN public.inventory i ON i.row_id = ti.inventory_row_id
  LEFT JOIN public.items it ON it.id = i.item_id
  WHERE ti.session_id = p_session_id AND ti.owner_id = v_uid;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'row_id', i.row_id,
    'item_id', i.item_id,
    'name', COALESCE(it.name_tr, it.name, i.item_id),
    'quantity', COALESCE(i.quantity, 1),
    'rarity', COALESCE(it.rarity, 'common')
  ) ORDER BY ti.created_at), '[]'::jsonb)
  INTO v_partner_items
  FROM public.trade_items ti
  JOIN public.inventory i ON i.row_id = ti.inventory_row_id
  LEFT JOIN public.items it ON it.id = i.item_id
  WHERE ti.session_id = p_session_id AND ti.owner_id <> v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_sess.status,
    'my_confirmed', CASE
      WHEN v_uid = v_sess.initiator_id THEN v_sess.initiator_confirmed
      ELSE v_sess.partner_confirmed
    END,
    'partner_confirmed', CASE
      WHEN v_uid = v_sess.initiator_id THEN v_sess.partner_confirmed
      ELSE v_sess.initiator_confirmed
    END,
    'partner_name', COALESCE(v_partner_name, ''),
    'my_items', v_my_items,
    'partner_items', v_partner_items
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_trade_session_details(uuid) TO authenticated;

COMMIT;
