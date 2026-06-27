-- Require explicit partner accept before active trade. Expire stale sessions.

BEGIN;

ALTER TABLE public.trade_sessions
  ADD COLUMN IF NOT EXISTS partner_accepted_at timestamptz;

-- Orphan active sessions (pre-invite system) → cancelled
UPDATE public.trade_sessions
SET status = 'cancelled', updated_at = now()
WHERE status = 'active' AND partner_accepted_at IS NULL;

CREATE OR REPLACE FUNCTION public._trade_expire_stale_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  UPDATE public.trade_sessions
  SET status = 'cancelled', updated_at = now()
  WHERE status = 'pending'
    AND created_at < now() - interval '15 minutes';

  UPDATE public.trade_sessions
  SET status = 'cancelled', updated_at = now()
  WHERE status = 'active'
    AND partner_accepted_at IS NULL;

  UPDATE public.trade_sessions ts
  SET status = 'cancelled', updated_at = now()
  WHERE ts.status = 'active'
    AND ts.updated_at < now() - interval '30 minutes'
    AND COALESCE(ts.initiator_gold, 0) = 0
    AND COALESCE(ts.partner_gold, 0) = 0
    AND NOT EXISTS (SELECT 1 FROM public.trade_items ti WHERE ti.session_id = ts.id);
END;
$$;

CREATE OR REPLACE FUNCTION public.initiate_trade(target_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_partner_id UUID;
  v_partner_name text;
  v_session_id UUID;
  v_status text;
  v_initiator_id UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  PERFORM public._trade_expire_stale_sessions();

  IF public._trade_is_banned(v_uid) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret yasağınız var. 12 saat sonra tekrar deneyin.');
  END IF;

  SELECT auth_id, username INTO v_partner_id, v_partner_name
  FROM public.users WHERE username = target_username;

  IF v_partner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı: ' || target_username);
  END IF;
  IF v_partner_id = v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinizle ticaret yapamazsınız.');
  END IF;

  IF public._trade_is_blocked(v_uid, v_partner_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu oyuncu ile ticaret engelli.');
  END IF;

  IF public._trade_is_banned(v_partner_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Karşı oyuncunun ticaret yasağı var.');
  END IF;

  SELECT id, status, initiator_id
  INTO v_session_id, v_status, v_initiator_id
  FROM public.trade_sessions
  WHERE (
      (status = 'pending')
      OR (status = 'active' AND partner_accepted_at IS NOT NULL)
    )
    AND ((initiator_id = v_uid AND partner_id = v_partner_id)
      OR (initiator_id = v_partner_id AND partner_id = v_uid))
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_session_id IS NOT NULL THEN
    IF v_status = 'pending' AND v_initiator_id <> v_uid THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Size gelen ticaret davetini popup üzerinden kabul edin.'
      );
    END IF;
    IF v_status = 'pending' AND v_initiator_id = v_uid THEN
      RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session_id,
        'partner_name', v_partner_name,
        'status', v_status,
        'is_initiator', true
      );
    END IF;
    IF v_status = 'active' THEN
      RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session_id,
        'partner_name', v_partner_name,
        'status', v_status,
        'is_initiator', v_initiator_id = v_uid
      );
    END IF;
  END IF;

  INSERT INTO public.trade_sessions (initiator_id, partner_id, status)
  VALUES (v_uid, v_partner_id, 'pending')
  RETURNING id, status INTO v_session_id, v_status;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'partner_name', v_partner_name,
    'status', v_status,
    'is_initiator', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_trade_invite(
  p_session_id uuid,
  p_accept boolean,
  p_block_sender boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_sess RECORD;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  PERFORM public._trade_expire_stale_sessions();

  SELECT * INTO v_sess FROM public.trade_sessions WHERE id = p_session_id FOR UPDATE;
  IF v_sess IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret oturumu bulunamadı.');
  END IF;
  IF v_sess.partner_id <> v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu davet size ait değil.');
  END IF;
  IF v_sess.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Davet artık geçerli değil.');
  END IF;
  IF v_sess.partner_accepted_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Davet zaten yanıtlandı.');
  END IF;

  IF p_accept THEN
    UPDATE public.trade_sessions
    SET status = 'active',
        partner_accepted_at = now(),
        initiator_confirmed = false,
        partner_confirmed = false,
        updated_at = now()
    WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'status', 'active');
  END IF;

  UPDATE public.trade_sessions SET status = 'cancelled', updated_at = now() WHERE id = p_session_id;

  INSERT INTO public.trade_rejection_events (rejector_id, initiator_id, session_id)
  VALUES (v_uid, v_sess.initiator_id, p_session_id);

  IF p_block_sender THEN
    INSERT INTO public.trade_blocks (blocker_id, blocked_id, blocked_until)
    VALUES (v_uid, v_sess.initiator_id, now() + interval '4 hours')
    ON CONFLICT (blocker_id, blocked_id)
    DO UPDATE SET blocked_until = EXCLUDED.blocked_until, created_at = now();
  END IF;

  PERFORM public._trade_apply_rejection_penalty(v_uid);

  RETURN jsonb_build_object('success', true, 'status', 'rejected');
END;
$$;

CREATE OR REPLACE FUNCTION public.get_pending_trade_invites()
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
  IF v_uid IS NULL THEN RETURN '[]'::jsonb; END IF;

  PERFORM public._trade_expire_stale_sessions();

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'session_id', ts.id,
    'initiator_name', u.username,
    'initiator_id', ts.initiator_id,
    'created_at', ts.created_at
  ) ORDER BY ts.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM public.trade_sessions ts
  JOIN public.users u ON u.auth_id = ts.initiator_id
  WHERE ts.partner_id = v_uid
    AND ts.status = 'pending'
    AND ts.partner_accepted_at IS NULL;

  RETURN v_rows;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_active_trade_session()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_sess RECORD;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RETURN jsonb_build_object('success', false); END IF;

  PERFORM public._trade_expire_stale_sessions();

  SELECT * INTO v_sess FROM public.trade_sessions
  WHERE (initiator_id = v_uid OR partner_id = v_uid)
    AND (
      (status = 'pending' AND initiator_id = v_uid)
      OR (status = 'active' AND partner_accepted_at IS NOT NULL)
    )
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_sess IS NULL THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_sess.id,
    'status', v_sess.status,
    'is_initiator', v_sess.initiator_id = v_uid,
    'partner_accepted', v_sess.partner_accepted_at IS NOT NULL
  );
END;
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
  IF v_sess.status <> 'active' OR v_sess.partner_accepted_at IS NULL THEN
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

CREATE OR REPLACE FUNCTION public.set_trade_gold(p_session_id uuid, p_amount bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
  v_sess RECORD;
  v_balance bigint;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;
  IF p_amount < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz altın miktarı.');
  END IF;

  SELECT * INTO v_sess FROM public.trade_sessions WHERE id = p_session_id FOR UPDATE;
  IF v_sess IS NULL OR v_sess.status <> 'active' OR v_sess.partner_accepted_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif ticaret yok.');
  END IF;
  IF v_uid <> v_sess.initiator_id AND v_uid <> v_sess.partner_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu ticaretin katılımcısı değilsiniz.');
  END IF;

  SELECT gold INTO v_balance FROM public.users WHERE auth_id = v_uid;
  IF COALESCE(v_balance, 0) < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın.');
  END IF;

  IF v_uid = v_sess.initiator_id THEN
    UPDATE public.trade_sessions SET initiator_gold = p_amount, initiator_confirmed = false, partner_confirmed = false, updated_at = now()
    WHERE id = p_session_id;
  ELSE
    UPDATE public.trade_sessions SET partner_gold = p_amount, initiator_confirmed = false, partner_confirmed = false, updated_at = now()
    WHERE id = p_session_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'gold', p_amount);
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
  IF v_sess.status <> 'active' OR v_sess.partner_accepted_at IS NULL THEN
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

GRANT EXECUTE ON FUNCTION public._trade_expire_stale_sessions() TO authenticated;

COMMIT;
