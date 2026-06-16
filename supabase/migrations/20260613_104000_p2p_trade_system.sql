-- ============================================================
-- Migration: P2P Trade System (escrow + iki taraflı onay)
-- ============================================================
-- QA audit bulgusu: trade_screen.dart şu RPC'leri çağırıyor
-- ama hiçbiri DB'de yoktu → ticaret özelliği tamamen kırık:
--   initiate_trade(target_username), add_trade_item(session_id, item_row_id),
--   confirm_trade(p_session_id), cancel_trade(p_session_id), get_trade_history()
-- Bu migration eksik backend'i kurar.
-- Güvenlik: eşya transferi yalnızca İKİ taraf da onayladığında,
-- atomik + FOR UPDATE kilidiyle yapılır.
-- ============================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- Tablolar
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.trade_sessions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  initiator_id        uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  partner_id          uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  status              text NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','completed','cancelled')),
  initiator_confirmed boolean NOT NULL DEFAULT false,
  partner_confirmed   boolean NOT NULL DEFAULT false,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trade_items (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id       uuid NOT NULL REFERENCES public.trade_sessions(id) ON DELETE CASCADE,
  owner_id         uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  inventory_row_id uuid NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id, inventory_row_id)
);

CREATE INDEX IF NOT EXISTS idx_trade_sessions_initiator ON public.trade_sessions(initiator_id);
CREATE INDEX IF NOT EXISTS idx_trade_sessions_partner   ON public.trade_sessions(partner_id);
CREATE INDEX IF NOT EXISTS idx_trade_items_session      ON public.trade_items(session_id);

-- RLS: katılımcılar kendi oturumlarını okuyabilir; yazma RPC ile.
ALTER TABLE public.trade_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_items    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trade_sessions_participant_read" ON public.trade_sessions;
CREATE POLICY "trade_sessions_participant_read" ON public.trade_sessions
  FOR SELECT TO authenticated
  USING (auth.uid() = initiator_id OR auth.uid() = partner_id);

DROP POLICY IF EXISTS "trade_items_participant_read" ON public.trade_items;
CREATE POLICY "trade_items_participant_read" ON public.trade_items
  FOR SELECT TO authenticated
  USING (
    session_id IN (
      SELECT id FROM public.trade_sessions
      WHERE auth.uid() = initiator_id OR auth.uid() = partner_id
    )
  );

-- ─────────────────────────────────────────────────────────────
-- initiate_trade(target_username text)
-- ─────────────────────────────────────────────────────────────
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
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT auth_id, username INTO v_partner_id, v_partner_name
  FROM public.users WHERE username = target_username;

  IF v_partner_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı: ' || target_username);
  END IF;
  IF v_partner_id = v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinizle ticaret yapamazsınız.');
  END IF;

  -- Aktif oturum varsa onu döndür (çift oturum engeli).
  SELECT id INTO v_session_id FROM public.trade_sessions
  WHERE status = 'active'
    AND ((initiator_id = v_uid AND partner_id = v_partner_id)
      OR (initiator_id = v_partner_id AND partner_id = v_uid))
  LIMIT 1;

  IF v_session_id IS NULL THEN
    INSERT INTO public.trade_sessions (initiator_id, partner_id)
    VALUES (v_uid, v_partner_id)
    RETURNING id INTO v_session_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'session_id', v_session_id,
    'partner_name', v_partner_name
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- add_trade_item(session_id uuid, item_row_id uuid)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.add_trade_item(session_id uuid, item_row_id uuid)
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

  SELECT * INTO v_sess FROM public.trade_sessions WHERE id = session_id;
  IF v_sess IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret oturumu bulunamadı.');
  END IF;
  IF v_sess.status <> 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticaret aktif değil.');
  END IF;
  IF v_uid <> v_sess.initiator_id AND v_uid <> v_sess.partner_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu ticaretin katılımcısı değilsiniz.');
  END IF;

  -- Eşya gerçekten çağırana ait + takılı değil + tradeable mı?
  SELECT i.row_id, i.is_equipped, COALESCE(it.is_tradeable, true) AS is_tradeable
  INTO v_inv
  FROM public.inventory i
  LEFT JOIN public.items it ON it.id = i.item_id
  WHERE i.row_id = item_row_id AND i.user_id = v_uid;

  IF v_inv IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya envanterinizde yok.');
  END IF;
  IF v_inv.is_equipped THEN
    RETURN jsonb_build_object('success', false, 'error', 'Takılı eşya takas edilemez.');
  END IF;
  IF NOT v_inv.is_tradeable THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu eşya takas edilemez.');
  END IF;

  -- Teklif değişince iki onayı da sıfırla (güvenlik: bait-and-switch engeli).
  INSERT INTO public.trade_items (session_id, owner_id, inventory_row_id)
  VALUES (session_id, v_uid, item_row_id)
  ON CONFLICT (session_id, inventory_row_id) DO NOTHING;

  UPDATE public.trade_sessions
  SET initiator_confirmed = false, partner_confirmed = false, updated_at = now()
  WHERE id = session_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- confirm_trade(p_session_id uuid)
--   İki taraf da onaylayınca eşyaları atomik transfer eder.
-- ─────────────────────────────────────────────────────────────
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

  -- İki taraf da onayladı → eşyaları kilitle, sahipliği doğrula, transfer et.
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

  UPDATE public.trade_sessions SET status = 'completed', updated_at = now()
  WHERE id = p_session_id;

  RETURN jsonb_build_object('success', true, 'status', 'completed');
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- cancel_trade(p_session_id uuid)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_trade(p_session_id uuid)
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
  IF v_uid <> v_sess.initiator_id AND v_uid <> v_sess.partner_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu ticaretin katılımcısı değilsiniz.');
  END IF;

  IF v_sess.status = 'active' THEN
    UPDATE public.trade_sessions SET status = 'cancelled', updated_at = now()
    WHERE id = p_session_id;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- get_trade_history()
-- ─────────────────────────────────────────────────────────────
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
        'my_items', COALESCE((
          SELECT jsonb_agg(COALESCE(it.name_tr, it.name, i.item_id))
          FROM public.trade_items ti
          JOIN public.inventory i ON i.row_id = ti.inventory_row_id
          LEFT JOIN public.items it ON it.id = i.item_id
          WHERE ti.session_id = ts.id AND ti.owner_id = v_uid
        ), '[]'::jsonb),
        'their_items', COALESCE((
          SELECT jsonb_agg(COALESCE(it.name_tr, it.name, i.item_id))
          FROM public.trade_items ti
          JOIN public.inventory i ON i.row_id = ti.inventory_row_id
          LEFT JOIN public.items it ON it.id = i.item_id
          WHERE ti.session_id = ts.id AND ti.owner_id <> v_uid
        ), '[]'::jsonb)
      ) AS row_json
    FROM public.trade_sessions ts
    WHERE (ts.initiator_id = v_uid OR ts.partner_id = v_uid)
      AND ts.status IN ('completed','cancelled')
    ORDER BY ts.updated_at DESC
    LIMIT 30
  ) sub;

  RETURN COALESCE(v_rows, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.initiate_trade(text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_trade_item(uuid, uuid)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_trade(uuid)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_trade(uuid)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_trade_history()         TO authenticated;

COMMIT;
