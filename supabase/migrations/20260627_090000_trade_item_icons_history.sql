-- Trade item icons in session details + history with gold amounts.

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
  v_my_gold bigint;
  v_partner_gold bigint;
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
    v_my_gold := v_sess.initiator_gold;
    v_partner_gold := v_sess.partner_gold;
  ELSE
    SELECT username INTO v_partner_name FROM public.users WHERE auth_id = v_sess.initiator_id;
    v_my_gold := v_sess.partner_gold;
    v_partner_gold := v_sess.initiator_gold;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'row_id', i.row_id,
    'item_id', i.item_id,
    'name', COALESCE(it.name_tr, it.name, i.item_id),
    'icon', COALESCE(it.icon, ''),
    'item_type', lower(COALESCE(it.type, 'misc')),
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
    'icon', COALESCE(it.icon, ''),
    'item_type', lower(COALESCE(it.type, 'misc')),
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
    'partner_items', v_partner_items,
    'my_gold', COALESCE(v_my_gold, 0),
    'partner_gold', COALESCE(v_partner_gold, 0),
    'is_initiator', v_uid = v_sess.initiator_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_trade_history()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_rows jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT jsonb_agg(row_json ORDER BY updated_at DESC)
  INTO v_rows
  FROM (
    SELECT
      ts.updated_at,
      jsonb_build_object(
        'id', ts.id,
        'date', to_char(ts.updated_at, 'YYYY-MM-DD'),
        'partner', CASE WHEN ts.initiator_id = v_uid
                        THEN (SELECT username FROM public.users WHERE auth_id = ts.partner_id)
                        ELSE (SELECT username FROM public.users WHERE auth_id = ts.initiator_id) END,
        'status', CASE WHEN ts.status = 'completed' THEN 'completed' ELSE 'cancelled' END,
        'my_gold', CASE WHEN ts.initiator_id = v_uid
                        THEN COALESCE(ts.initiator_gold, 0)
                        ELSE COALESCE(ts.partner_gold, 0) END,
        'their_gold', CASE WHEN ts.initiator_id = v_uid
                           THEN COALESCE(ts.partner_gold, 0)
                           ELSE COALESCE(ts.initiator_gold, 0) END,
        'my_items', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'name', COALESCE(it.name_tr, it.name, i.item_id),
            'item_id', i.item_id,
            'icon', COALESCE(it.icon, ''),
            'item_type', lower(COALESCE(it.type, 'misc')),
            'quantity', COALESCE(i.quantity, 1),
            'rarity', COALESCE(it.rarity, 'common')
          ) ORDER BY ti.created_at)
          FROM public.trade_items ti
          JOIN public.inventory i ON i.row_id = ti.inventory_row_id
          LEFT JOIN public.items it ON it.id = i.item_id
          WHERE ti.session_id = ts.id AND ti.owner_id = v_uid
        ), '[]'::jsonb),
        'their_items', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'name', COALESCE(it.name_tr, it.name, i.item_id),
            'item_id', i.item_id,
            'icon', COALESCE(it.icon, ''),
            'item_type', lower(COALESCE(it.type, 'misc')),
            'quantity', COALESCE(i.quantity, 1),
            'rarity', COALESCE(it.rarity, 'common')
          ) ORDER BY ti.created_at)
          FROM public.trade_items ti
          JOIN public.inventory i ON i.row_id = ti.inventory_row_id
          LEFT JOIN public.items it ON it.id = i.item_id
          WHERE ti.session_id = ts.id AND ti.owner_id <> v_uid
        ), '[]'::jsonb)
      ) AS row_json
    FROM public.trade_sessions ts
    WHERE (ts.initiator_id = v_uid OR ts.partner_id = v_uid)
      AND ts.status IN ('completed', 'cancelled')
    ORDER BY ts.updated_at DESC
    LIMIT 30
  ) sub;

  RETURN COALESCE(v_rows, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_trade_session_details(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_trade_history() TO authenticated;

COMMIT;
