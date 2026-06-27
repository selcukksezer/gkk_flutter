-- Trade block list/unblock, online guard, single active trade guard.

BEGIN;

CREATE OR REPLACE FUNCTION public.set_online_status(p_is_online boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  UPDATE public.users
  SET is_online = p_is_online,
      last_active_at = now()
  WHERE auth_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_online_status(boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_blocked_trade_users()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid;
  v_rows jsonb;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN RETURN '[]'::jsonb; END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'blocked_id', tb.blocked_id,
    'username', u.username,
    'blocked_until', tb.blocked_until,
    'created_at', tb.created_at
  ) ORDER BY tb.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM public.trade_blocks tb
  JOIN public.users u ON u.auth_id = tb.blocked_id
  WHERE tb.blocker_id = v_uid
    AND tb.blocked_until > now();

  RETURN v_rows;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_blocked_trade_users() TO authenticated;

CREATE OR REPLACE FUNCTION public.unblock_trade_user(p_blocked_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid;
  v_deleted int;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;
  IF p_blocked_id IS NULL OR p_blocked_id = v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz oyuncu.');
  END IF;

  DELETE FROM public.trade_blocks
  WHERE blocker_id = v_uid AND blocked_id = p_blocked_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('success', v_deleted > 0, 'deleted_count', v_deleted);
END;
$$;

GRANT EXECUTE ON FUNCTION public.unblock_trade_user(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public._trade_user_is_busy(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.trade_sessions ts
    WHERE (
        (ts.initiator_id = p_uid AND ts.status = 'pending')
        OR (ts.partner_id = p_uid AND ts.status = 'pending' AND ts.partner_accepted_at IS NULL)
        OR (
          (ts.initiator_id = p_uid OR ts.partner_id = p_uid)
          AND ts.status = 'active'
          AND ts.partner_accepted_at IS NOT NULL
        )
      )
  );
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

  -- Hide incoming invites only when user already initiated or is in active trade.
  IF EXISTS (
    SELECT 1 FROM public.trade_sessions ts
    WHERE ts.initiator_id = v_uid AND ts.status = 'pending'
  ) OR EXISTS (
    SELECT 1 FROM public.trade_sessions ts
    WHERE (ts.initiator_id = v_uid OR ts.partner_id = v_uid)
      AND ts.status = 'active'
      AND ts.partner_accepted_at IS NOT NULL
  ) THEN
    RETURN '[]'::jsonb;
  END IF;

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
  v_partner_online boolean;
  v_last_active timestamptz;
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

  IF EXISTS (
    SELECT 1 FROM public.trade_sessions ts
    WHERE (
        (ts.initiator_id = v_uid AND ts.status = 'pending')
        OR (ts.partner_id = v_uid AND ts.status = 'pending' AND ts.partner_accepted_at IS NULL)
        OR (
          (ts.initiator_id = v_uid OR ts.partner_id = v_uid)
          AND ts.status = 'active'
          AND ts.partner_accepted_at IS NOT NULL
        )
      )
      AND NOT (
        (ts.initiator_id = v_uid AND ts.partner_id = v_partner_id)
        OR (ts.initiator_id = v_partner_id AND ts.partner_id = v_uid)
      )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten aktif bir ticaretiniz var.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.trade_sessions ts
    WHERE (
        (ts.initiator_id = v_partner_id AND ts.status = 'pending')
        OR (ts.partner_id = v_partner_id AND ts.status = 'pending' AND ts.partner_accepted_at IS NULL)
        OR (
          (ts.initiator_id = v_partner_id OR ts.partner_id = v_partner_id)
          AND ts.status = 'active'
          AND ts.partner_accepted_at IS NOT NULL
        )
      )
      AND NOT (
        (ts.initiator_id = v_uid AND ts.partner_id = v_partner_id)
        OR (ts.initiator_id = v_partner_id AND ts.partner_id = v_uid)
      )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncunun zaten aktif bir ticareti var.');
  END IF;

  SELECT COALESCE(u.is_online, false), u.last_active_at
  INTO v_partner_online, v_last_active
  FROM public.users u
  WHERE u.auth_id = v_partner_id;

  IF NOT v_partner_online
     OR v_last_active IS NULL
     OR v_last_active < now() - interval '5 minutes' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu çevrimiçi değil.');
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

COMMIT;
