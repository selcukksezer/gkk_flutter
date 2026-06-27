-- Trade invites (pending accept), 4h blocks, rejection spam ban, gold offers.

BEGIN;

ALTER TABLE public.trade_sessions DROP CONSTRAINT IF EXISTS trade_sessions_status_check;
ALTER TABLE public.trade_sessions
  ADD CONSTRAINT trade_sessions_status_check
  CHECK (status IN ('pending', 'active', 'completed', 'cancelled'));

ALTER TABLE public.trade_sessions
  ADD COLUMN IF NOT EXISTS initiator_gold bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS partner_gold bigint NOT NULL DEFAULT 0;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS trade_banned_until timestamptz;

CREATE TABLE IF NOT EXISTS public.trade_blocks (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id   uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  blocked_id   uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  blocked_until timestamptz NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS public.trade_rejection_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rejector_id  uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  initiator_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  session_id   uuid REFERENCES public.trade_sessions(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trade_blocks_pair ON public.trade_blocks(blocker_id, blocked_id, blocked_until);
CREATE INDEX IF NOT EXISTS idx_trade_rejection_rejector ON public.trade_rejection_events(rejector_id, created_at);

ALTER TABLE public.trade_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_rejection_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS trade_blocks_own_read ON public.trade_blocks;
CREATE POLICY trade_blocks_own_read ON public.trade_blocks
  FOR SELECT TO authenticated USING (auth.uid() = blocker_id OR auth.uid() = blocked_id);

-- ── Helpers ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._trade_is_banned(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (SELECT trade_banned_until > now() FROM public.users WHERE auth_id = p_uid),
    false
  );
$$;

CREATE OR REPLACE FUNCTION public._trade_is_blocked(p_from uuid, p_to uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.trade_blocks
    WHERE blocked_until > now()
      AND (
        (blocker_id = p_to AND blocked_id = p_from)
        OR (blocker_id = p_from AND blocked_id = p_to)
      )
  );
$$;

CREATE OR REPLACE FUNCTION public._trade_apply_rejection_penalty(p_rejector uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_reject_count int;
  v_distinct_initiators int;
BEGIN
  SELECT COUNT(*), COUNT(DISTINCT initiator_id)
  INTO v_reject_count, v_distinct_initiators
  FROM public.trade_rejection_events
  WHERE rejector_id = p_rejector
    AND created_at > now() - interval '24 hours';

  IF v_reject_count >= 5 AND v_distinct_initiators >= 3 THEN
    UPDATE public.users
    SET trade_banned_until = GREATEST(COALESCE(trade_banned_until, now()), now()) + interval '12 hours'
    WHERE auth_id = p_rejector;
  END IF;
END;
$$;

-- ── initiate_trade (pending invite) ────────────────────────────────────────

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
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

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

  SELECT id, status INTO v_session_id, v_status FROM public.trade_sessions
  WHERE status IN ('pending', 'active')
    AND ((initiator_id = v_uid AND partner_id = v_partner_id)
      OR (initiator_id = v_partner_id AND partner_id = v_uid))
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_session_id IS NULL THEN
    INSERT INTO public.trade_sessions (initiator_id, partner_id, status)
    VALUES (v_uid, v_partner_id, 'pending')
    RETURNING id, status INTO v_session_id, v_status;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'partner_name', v_partner_name,
    'status', v_status,
    'is_initiator', (v_uid = (SELECT initiator_id FROM public.trade_sessions WHERE id = v_session_id))
  );
END;
$$;

-- ── Pending invites for partner ────────────────────────────────────────────

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

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'session_id', ts.id,
    'initiator_name', u.username,
    'initiator_id', ts.initiator_id,
    'created_at', ts.created_at
  ) ORDER BY ts.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM public.trade_sessions ts
  JOIN public.users u ON u.auth_id = ts.initiator_id
  WHERE ts.partner_id = v_uid AND ts.status = 'pending';

  RETURN v_rows;
END;
$$;

-- ── Accept / reject invite ─────────────────────────────────────────────────

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

  IF p_accept THEN
    UPDATE public.trade_sessions
    SET status = 'active', updated_at = now()
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

-- ── Gold offer ─────────────────────────────────────────────────────────────

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
  IF v_sess IS NULL OR v_sess.status <> 'active' THEN
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

-- ── Remove trade item ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.remove_trade_item(p_session_id uuid, p_item_row_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid UUID;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  DELETE FROM public.trade_items ti
  USING public.trade_sessions ts
  WHERE ti.session_id = p_session_id
    AND ti.inventory_row_id = p_item_row_id
    AND ti.owner_id = v_uid
    AND ts.id = p_session_id
    AND ts.status = 'active'
    AND (ts.initiator_id = v_uid OR ts.partner_id = v_uid);

  UPDATE public.trade_sessions
  SET initiator_confirmed = false, partner_confirmed = false, updated_at = now()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── Session details (+ gold) ───────────────────────────────────────────────

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
    'partner_items', v_partner_items,
    'my_gold', COALESCE(v_my_gold, 0),
    'partner_gold', COALESCE(v_partner_gold, 0),
    'is_initiator', v_uid = v_sess.initiator_id
  );
END;
$$;

-- ── Active session for current user ────────────────────────────────────────

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

  SELECT * INTO v_sess FROM public.trade_sessions
  WHERE status IN ('pending', 'active')
    AND (initiator_id = v_uid OR partner_id = v_uid)
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_sess IS NULL THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_sess.id,
    'status', v_sess.status,
    'is_initiator', v_sess.initiator_id = v_uid
  );
END;
$$;

-- ── confirm_trade (+ gold transfer) ────────────────────────────────────────

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
  v_both boolean;
  v_init_gold bigint;
  v_part_gold bigint;
  v_init_balance bigint;
  v_part_balance bigint;
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

  v_init_gold := COALESCE(v_sess.initiator_gold, 0);
  v_part_gold := COALESCE(v_sess.partner_gold, 0);

  SELECT gold INTO v_init_balance FROM public.users WHERE auth_id = v_sess.initiator_id FOR UPDATE;
  SELECT gold INTO v_part_balance FROM public.users WHERE auth_id = v_sess.partner_id FOR UPDATE;

  IF COALESCE(v_init_balance, 0) < v_init_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Başlatıcıda yetersiz altın.');
  END IF;
  IF COALESCE(v_part_balance, 0) < v_part_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Partnerde yetersiz altın.');
  END IF;

  FOR v_item IN
    SELECT ti.inventory_row_id, ti.owner_id,
           CASE WHEN ti.owner_id = v_sess.initiator_id
                THEN v_sess.partner_id ELSE v_sess.initiator_id END AS recipient_id
    FROM public.trade_items ti
    WHERE ti.session_id = p_session_id
  LOOP
    PERFORM 1 FROM public.inventory
      WHERE row_id = v_item.inventory_row_id AND user_id = v_item.owner_id
      FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Eşya artık sahibinde değil: %', v_item.inventory_row_id;
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

GRANT EXECUTE ON FUNCTION public.get_pending_trade_invites() TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_trade_invite(uuid, boolean, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_trade_gold(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_trade_item(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_active_trade_session() TO authenticated;

COMMIT;
