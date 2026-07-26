-- Staff/GM chat message delete with visible notice + optional mute presets.

BEGIN;

CREATE OR REPLACE FUNCTION public.format_chat_deleted_notice(p_deleted_by_user_id UUID)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    CASE public.get_public_staff_badge(u.auth_id)
      WHEN 'admin' THEN 'Admin ' || COALESCE(NULLIF(btrim(u.display_name), ''), u.username)
      WHEN 'gm' THEN 'GM ' || COALESCE(NULLIF(btrim(u.display_name), ''), u.username)
      ELSE COALESCE(NULLIF(btrim(u.display_name), ''), u.username)
    END || ' tarafından silindi'
  FROM public.users u
  WHERE u.id = p_deleted_by_user_id;
$$;

CREATE OR REPLACE FUNCTION public.delete_chat_message(
  p_message_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor public.users%ROWTYPE;
  v_message RECORD;
  v_notice TEXT;
BEGIN
  v_actor := public.get_current_chat_user();

  SELECT id, channel, guild_id, sender_user_id, deleted_at
  INTO v_message
  FROM public.chat_messages
  WHERE id = p_message_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj bulunamadi');
  END IF;

  IF v_message.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj zaten silinmis');
  END IF;

  IF NOT public.has_chat_permission(v_actor.id, 'delete', v_message.channel, v_message.guild_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu mesaji silme yetkiniz yok');
  END IF;

  v_notice := public.format_chat_deleted_notice(v_actor.id);

  UPDATE public.chat_messages
  SET deleted_at = now(),
      deleted_by_user_id = v_actor.id,
      deleted_reason = left(public.normalize_chat_content(COALESCE(p_reason, v_notice)), 200),
      content = v_notice
  WHERE id = p_message_id;

  PERFORM public.write_chat_audit(
    v_actor.id,
    'message_deleted',
    v_message.sender_user_id,
    p_message_id,
    jsonb_build_object('reason', p_reason, 'notice', v_notice)
  );

  RETURN jsonb_build_object(
    'success', true,
    'notice', v_notice,
    'message_id', p_message_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_moderate_chat_message(
  p_message_id UUID,
  p_mute_minutes INTEGER DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_message RECORD;
  v_sender_auth UUID;
  v_sender_user UUID;
  v_actor_user UUID;
  v_delete JSONB;
  v_notice TEXT;
  v_reason TEXT := COALESCE(NULLIF(btrim(p_reason), ''), 'moderator_delete');
  v_until TIMESTAMPTZ;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum gerekli.');
  END IF;

  v_guard := public.staff_require_permission(v_actor, 'chat.delete_message');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  SELECT cm.id, cm.channel, cm.guild_id, cm.sender_user_id, cm.deleted_at, u.auth_id
  INTO v_message
  FROM public.chat_messages cm
  JOIN public.users u ON u.id = cm.sender_user_id
  WHERE cm.id = p_message_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj bulunamadi');
  END IF;

  IF v_message.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj zaten silinmis');
  END IF;

  v_delete := public.delete_chat_message(p_message_id, v_reason);
  IF (v_delete->>'success')::boolean IS NOT TRUE THEN
    RETURN v_delete;
  END IF;

  v_notice := v_delete->>'notice';

  IF p_mute_minutes IS NOT NULL AND p_mute_minutes > 0 THEN
    v_guard := public.staff_require_permission(v_actor, 'player.chat_mute');
    IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', true,
        'notice', v_notice,
        'message_id', p_message_id,
        'warning', 'Mesaj silindi ancak susturma yetkisi yok.'
      );
    END IF;

    v_sender_auth := v_message.auth_id;
    IF v_sender_auth IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Gonderici bulunamadi.');
    END IF;

    IF public.staff_is_admin(v_sender_auth)
       OR public.staff_active_assignment(v_sender_auth) IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'notice', v_notice,
        'message_id', p_message_id,
        'warning', 'Yetkili oyuncu susturulamaz.'
      );
    END IF;

    v_until := now() + make_interval(mins => LEAST(p_mute_minutes, 525600));

    SELECT u.id INTO v_sender_user FROM public.users u WHERE u.auth_id = v_sender_auth;
    SELECT u.id INTO v_actor_user FROM public.users u WHERE u.auth_id = v_actor;

    IF v_sender_user IS NULL OR v_actor_user IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi.');
    END IF;

    UPDATE public.chat_bans
    SET revoked_at = now(), revoked_by_user_id = v_actor_user
    WHERE user_id = v_sender_user
      AND revoked_at IS NULL
      AND expires_at > now()
      AND scope = 'global';

    INSERT INTO public.chat_bans (user_id, scope, channel, guild_id, reason, expires_at, created_by_user_id)
    VALUES (
      v_sender_user,
      'global',
      NULL,
      NULL,
      left(v_reason, 200),
      v_until,
      v_actor_user
    );

    PERFORM public.staff_write_audit(
      v_actor,
      'player.chat_mute',
      'chat_mute_with_delete',
      'user',
      v_sender_auth::text,
      jsonb_build_object('message_id', p_message_id, 'minutes', p_mute_minutes, 'reason', v_reason),
      jsonb_build_object('success', true)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'notice', v_notice,
    'message_id', p_message_id,
    'muted_minutes', CASE WHEN p_mute_minutes IS NOT NULL AND p_mute_minutes > 0 THEN p_mute_minutes ELSE NULL END
  );
END;
$$;

DROP FUNCTION IF EXISTS public.get_chat_history(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.get_chat_history(
  p_channel TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  channel TEXT,
  sender_id UUID,
  sender_name TEXT,
  content TEXT,
  "timestamp" TIMESTAMPTZ,
  is_system BOOLEAN,
  recipient_user_id UUID,
  guild_id UUID,
  sender_staff_badge TEXT,
  sender_auth_id UUID,
  deleted_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade', 'system') THEN
    RAISE EXCEPTION 'Gecersiz kanal';
  END IF;

  IF p_channel = 'guild' AND v_user.guild_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    cm.id,
    cm.channel,
    cm.sender_user_id,
    cm.sender_name,
    CASE
      WHEN cm.deleted_at IS NOT NULL THEN COALESCE(
        NULLIF(btrim(cm.content), ''),
        public.format_chat_deleted_notice(cm.deleted_by_user_id)
      )
      ELSE cm.content
    END,
    cm.created_at,
    cm.is_system,
    cm.recipient_user_id,
    cm.guild_id,
    public.get_public_staff_badge(u.auth_id) AS sender_staff_badge,
    u.auth_id AS sender_auth_id,
    cm.deleted_at
  FROM public.chat_messages cm
  LEFT JOIN public.users u ON u.id = cm.sender_user_id
  WHERE cm.channel = p_channel
    AND (
      p_channel IN ('global', 'trade', 'system')
      OR (p_channel = 'guild' AND cm.guild_id = v_user.guild_id)
      OR (p_channel = 'dm' AND (cm.sender_user_id = v_user.id OR cm.recipient_user_id = v_user.id))
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE cb.blocker_user_id = v_user.id
        AND cb.blocked_user_id = cm.sender_user_id
        AND cm.deleted_at IS NULL
    )
  ORDER BY cm.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$;

DROP FUNCTION IF EXISTS public.get_dm_messages(UUID, INTEGER);

CREATE OR REPLACE FUNCTION public.get_dm_messages(
  p_peer_user_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  channel TEXT,
  sender_id UUID,
  sender_name TEXT,
  content TEXT,
  "timestamp" TIMESTAMPTZ,
  is_system BOOLEAN,
  recipient_user_id UUID,
  guild_id UUID,
  read_at TIMESTAMPTZ,
  sender_is_online BOOLEAN,
  sender_staff_badge TEXT,
  sender_auth_id UUID,
  deleted_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_peer_user_id IS NULL OR p_peer_user_id = v_user.id THEN
    RAISE EXCEPTION 'Gecersiz hedef kullanici';
  END IF;

  RETURN QUERY
  SELECT
    cm.id,
    cm.channel,
    cm.sender_user_id,
    cm.sender_name,
    CASE
      WHEN cm.deleted_at IS NOT NULL THEN COALESCE(
        NULLIF(btrim(cm.content), ''),
        public.format_chat_deleted_notice(cm.deleted_by_user_id)
      )
      ELSE cm.content
    END,
    cm.created_at,
    cm.is_system,
    cm.recipient_user_id,
    cm.guild_id,
    cm.read_at,
    public.is_user_online(u.is_online, u.last_active_at),
    public.get_public_staff_badge(u.auth_id) AS sender_staff_badge,
    u.auth_id AS sender_auth_id,
    cm.deleted_at
  FROM public.chat_messages cm
  JOIN public.users u ON u.id = cm.sender_user_id
  WHERE cm.channel = 'dm'
    AND (
      (cm.sender_user_id = v_user.id AND cm.recipient_user_id = p_peer_user_id)
      OR (cm.sender_user_id = p_peer_user_id AND cm.recipient_user_id = v_user.id)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE cb.blocker_user_id = v_user.id
        AND cb.blocked_user_id = cm.sender_user_id
        AND cm.deleted_at IS NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_dm_message_hides h
      WHERE h.message_id = cm.id
        AND h.user_id = v_user.id
    )
  ORDER BY cm.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$;

GRANT EXECUTE ON FUNCTION public.format_chat_deleted_notice(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_chat_message(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_moderate_chat_message(uuid, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_history(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dm_messages(uuid, integer) TO authenticated;

COMMIT;
