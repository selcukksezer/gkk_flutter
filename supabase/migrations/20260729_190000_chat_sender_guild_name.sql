-- Chat: show sender guild name in history, DM, and new message metadata.

BEGIN;

CREATE OR REPLACE FUNCTION public.send_chat_message(
  p_channel TEXT,
  p_content TEXT,
  p_recipient_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_recipient public.users%ROWTYPE;
  v_clean TEXT;
  v_filtered TEXT;
  v_last_message_at TIMESTAMPTZ;
  v_ban public.chat_bans%ROWTYPE;
  v_message_id UUID;
  v_sender_name TEXT;
  v_sender_guild_name TEXT;
  v_policy JSONB;
  v_acct JSONB;
BEGIN
  v_policy := public.policy_require_acceptance();
  IF (v_policy->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_policy->>'error', 'policy_required', true);
  END IF;

  v_acct := public.assert_player_not_banned();
  IF (v_acct->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_acct->>'error');
  END IF;

  v_user := public.get_current_chat_user();

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz kanal');
  END IF;

  v_clean := public.normalize_chat_content(p_content);
  IF char_length(v_clean) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bos mesaj gonderilemez');
  END IF;

  IF char_length(v_clean) > 200 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj en fazla 200 karakter olabilir');
  END IF;

  IF p_channel = 'guild' AND v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca sohbeti icin bir loncaya ait olmalisiniz');
  END IF;

  IF p_channel = 'dm' AND p_recipient_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ozel mesaj icin hedef kullanici gerekli');
  END IF;

  IF p_channel = 'dm' THEN
    SELECT * INTO v_recipient FROM public.users WHERE id = p_recipient_user_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hedef oyuncu bulunamadi');
    END IF;

    IF v_recipient.id = v_user.id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Kendinize ozel mesaj gonderemezsiniz');
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE (cb.blocker_user_id = v_user.id AND cb.blocked_user_id = v_recipient.id)
         OR (cb.blocker_user_id = v_recipient.id AND cb.blocked_user_id = v_user.id)
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Bu oyuncu ile ozel mesaj kullanilamiyor');
    END IF;
  END IF;

  SELECT created_at INTO v_last_message_at
  FROM public.chat_messages
  WHERE sender_user_id = v_user.id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_message_at IS NOT NULL AND v_last_message_at > now() - interval '2 seconds' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cok hizli mesaj gonderiyorsunuz');
  END IF;

  v_ban := public.get_active_chat_ban(v_user.id, p_channel, v_user.guild_id);
  IF v_ban.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Sohbetten gecici olarak uzaklastirildiniz',
      'ban_expires_at', v_ban.expires_at,
      'ban_reason', v_ban.reason
    );
  END IF;

  v_filtered := public.apply_chat_filters(v_clean, p_channel, v_user.guild_id);
  v_sender_name := COALESCE(NULLIF(v_user.display_name, ''), v_user.username);

  SELECT g.name
  INTO v_sender_guild_name
  FROM public.guilds g
  WHERE g.id = v_user.guild_id;

  INSERT INTO public.chat_messages (
    channel, sender_user_id, recipient_user_id, guild_id, sender_name, content, metadata
  ) VALUES (
    p_channel, v_user.id, p_recipient_user_id,
    CASE WHEN p_channel = 'guild' THEN v_user.guild_id ELSE NULL END,
    v_sender_name, v_filtered,
    jsonb_build_object(
      'original_length', char_length(v_clean),
      'sender_guild_name', v_sender_guild_name
    )
  )
  RETURNING id INTO v_message_id;

  PERFORM public.write_chat_audit(v_user.id, 'message_sent', NULL, v_message_id, jsonb_build_object('channel', p_channel));

  RETURN jsonb_build_object(
    'success', true,
    'message_id', v_message_id,
    'content', v_filtered,
    'sender_staff_badge', public.get_public_staff_badge(v_user.auth_id),
    'sender_king_badge', public.get_public_king_badge(v_user.auth_id),
    'sender_guild_name', v_sender_guild_name
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
  sender_king_badge TEXT,
  sender_guild_name TEXT,
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
    public.get_public_king_badge(u.auth_id) AS sender_king_badge,
    COALESCE(g.name, NULLIF(cm.metadata->>'sender_guild_name', '')) AS sender_guild_name,
    u.auth_id AS sender_auth_id,
    cm.deleted_at
  FROM public.chat_messages cm
  LEFT JOIN public.users u ON u.id = cm.sender_user_id
  LEFT JOIN public.guilds g ON g.id = u.guild_id
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
  sender_king_badge TEXT,
  sender_guild_name TEXT,
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
    public.get_public_king_badge(u.auth_id) AS sender_king_badge,
    COALESCE(g.name, NULLIF(cm.metadata->>'sender_guild_name', '')) AS sender_guild_name,
    u.auth_id AS sender_auth_id,
    cm.deleted_at
  FROM public.chat_messages cm
  JOIN public.users u ON u.id = cm.sender_user_id
  LEFT JOIN public.guilds g ON g.id = u.guild_id
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

GRANT EXECUTE ON FUNCTION public.send_chat_message(text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_history(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dm_messages(uuid, integer) TO authenticated;

COMMIT;
