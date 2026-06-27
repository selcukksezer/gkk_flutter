-- Trade security hardening: dupe prevention, tradable locks, one-sided gift trades.

BEGIN;

CREATE OR REPLACE FUNCTION public._trade_item_in_open_session(p_row_id uuid, p_exclude_session uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.trade_items ti
    JOIN public.trade_sessions ts ON ts.id = ti.session_id
    WHERE ti.inventory_row_id = p_row_id
      AND ts.status IN ('pending', 'active')
      AND (p_exclude_session IS NULL OR ti.session_id <> p_exclude_session)
  );
$$;

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

CREATE OR REPLACE FUNCTION public.confirm_trade(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_sess RECORD;
  v_item RECORD;
  v_inv RECORD;
  v_both boolean;
  v_init_gold bigint;
  v_part_gold bigint;
  v_init_balance bigint;
  v_part_balance bigint;
  v_item_count int;
  v_has_value boolean;
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

  IF v_uid = v_sess.initiator_id THEN
    UPDATE public.trade_sessions SET initiator_confirmed = true, updated_at = now()
    WHERE id = p_session_id;
  ELSE
    UPDATE public.trade_sessions SET partner_confirmed = true, updated_at = now()
    WHERE id = p_session_id;
  END IF;

  SELECT (initiator_confirmed AND partner_confirmed) INTO v_both
  FROM public.trade_sessions WHERE id = p_session_id;

  IF NOT v_both THEN
    RETURN jsonb_build_object('success', true, 'status', 'waiting_partner');
  END IF;

  SELECT COUNT(*) INTO v_item_count FROM public.trade_items WHERE session_id = p_session_id;
  v_init_gold := COALESCE(v_sess.initiator_gold, 0);
  v_part_gold := COALESCE(v_sess.partner_gold, 0);
  v_has_value := v_item_count > 0 OR v_init_gold > 0 OR v_part_gold > 0;

  IF NOT v_has_value THEN
    UPDATE public.trade_sessions
    SET initiator_confirmed = false, partner_confirmed = false, updated_at = now()
    WHERE id = p_session_id;
    RETURN jsonb_build_object('success', false, 'error', 'Ticarette en az bir teklif olmalı.');
  END IF;

  SELECT gold INTO v_init_balance FROM public.users WHERE auth_id = v_sess.initiator_id FOR UPDATE;
  SELECT gold INTO v_part_balance FROM public.users WHERE auth_id = v_sess.partner_id FOR UPDATE;

  IF COALESCE(v_init_balance, 0) < v_init_gold THEN
    UPDATE public.trade_sessions
    SET initiator_confirmed = false, partner_confirmed = false, updated_at = now()
    WHERE id = p_session_id;
    RETURN jsonb_build_object('success', false, 'error', 'Başlatıcıda yetersiz altın.');
  END IF;
  IF COALESCE(v_part_balance, 0) < v_part_gold THEN
    UPDATE public.trade_sessions
    SET initiator_confirmed = false, partner_confirmed = false, updated_at = now()
    WHERE id = p_session_id;
    RETURN jsonb_build_object('success', false, 'error', 'Partnerde yetersiz altın.');
  END IF;

  FOR v_item IN
    SELECT ti.inventory_row_id, ti.owner_id,
           CASE WHEN ti.owner_id = v_sess.initiator_id
                THEN v_sess.partner_id ELSE v_sess.initiator_id END AS recipient_id
    FROM public.trade_items ti
    WHERE ti.session_id = p_session_id
  LOOP
    SELECT i.row_id, i.user_id, i.is_equipped,
           COALESCE(it.is_tradeable, true) AS is_tradeable,
           COALESCE(it.is_direct_tradeable, true) AS is_direct_tradeable
    INTO v_inv
    FROM public.inventory i
    LEFT JOIN public.items it ON it.id = i.item_id
    WHERE i.row_id = v_item.inventory_row_id
    FOR UPDATE OF i;

    IF v_inv IS NULL OR v_inv.user_id <> v_item.owner_id THEN
      UPDATE public.trade_sessions
      SET initiator_confirmed = false, partner_confirmed = false, updated_at = now()
      WHERE id = p_session_id;
      RETURN jsonb_build_object('success', false, 'error', 'Eşya artık sahibinde değil.');
    END IF;
    IF v_inv.is_equipped OR NOT v_inv.is_tradeable OR NOT v_inv.is_direct_tradeable THEN
      UPDATE public.trade_sessions
      SET initiator_confirmed = false, partner_confirmed = false, updated_at = now()
      WHERE id = p_session_id;
      RETURN jsonb_build_object('success', false, 'error', 'Eşya artık takas edilemez.');
    END IF;

    UPDATE public.inventory
    SET user_id = v_item.recipient_id,
        is_equipped = false,
        slot_position = NULL,
        updated_at = now()
    WHERE row_id = v_item.inventory_row_id;
  END LOOP;

  UPDATE public.users
  SET gold = gold - v_init_gold + v_part_gold, updated_at = now()
  WHERE auth_id = v_sess.initiator_id;

  UPDATE public.users
  SET gold = gold - v_part_gold + v_init_gold, updated_at = now()
  WHERE auth_id = v_sess.partner_id;

  UPDATE public.trade_sessions SET status = 'completed', updated_at = now()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true, 'status', 'completed');
END;
$$;

GRANT EXECUTE ON FUNCTION public._trade_item_in_open_session(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_trade_item(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_trade(uuid) TO authenticated;

COMMIT;
