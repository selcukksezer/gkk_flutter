-- Player ban enforcement + staff ban/unban RPCs.

BEGIN;

CREATE OR REPLACE FUNCTION public.assert_player_not_banned(p_user_id UUID DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_u RECORD;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT is_banned, ban_reason, banned_until
  INTO v_u
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kullanıcı bulunamadı.');
  END IF;

  IF COALESCE(v_u.is_banned, false) = true
     AND (v_u.banned_until IS NULL OR v_u.banned_until > now()) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', COALESCE(v_u.ban_reason, 'Hesabınız askıya alındı.'),
      'banned_until', v_u.banned_until
    );
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_ban_player(
  p_target_user_id UUID,
  p_reason TEXT,
  p_until TIMESTAMPTZ DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.ban');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_target_user_id IS NULL OR btrim(COALESCE(p_reason, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef ve sebep gerekli.');
  END IF;

  IF public.staff_is_admin(p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin hesabı banlanamaz.');
  END IF;

  UPDATE public.users
  SET is_banned = true,
      ban_reason = left(p_reason, 500),
      banned_until = p_until
  WHERE auth_id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'player.ban', 'ban_player', 'user', p_target_user_id::text,
    jsonb_build_object('reason', p_reason, 'until', p_until),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Oyuncu banlandı.');
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_unban_player(p_target_user_id UUID, p_note TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.unban');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  UPDATE public.users
  SET is_banned = false, ban_reason = NULL, banned_until = NULL
  WHERE auth_id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'player.unban', 'unban_player', 'user', p_target_user_id::text,
    jsonb_build_object('note', p_note),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Ban kaldırıldı.');
END;
$$;

-- Patch send_chat_message: policy + account ban
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

  INSERT INTO public.chat_messages (
    channel, sender_user_id, recipient_user_id, guild_id, sender_name, content, metadata
  ) VALUES (
    p_channel, v_user.id, p_recipient_user_id,
    CASE WHEN p_channel = 'guild' THEN v_user.guild_id ELSE NULL END,
    v_sender_name, v_filtered,
    jsonb_build_object('original_length', char_length(v_clean))
  )
  RETURNING id INTO v_message_id;

  PERFORM public.write_chat_audit(v_user.id, 'message_sent', NULL, v_message_id, jsonb_build_object('channel', p_channel));

  RETURN jsonb_build_object(
    'success', true,
    'message_id', v_message_id,
    'content', v_filtered,
    'sender_staff_badge', public.get_public_staff_badge(v_user.auth_id)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_ban_player(uuid, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_unban_player(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assert_player_not_banned(uuid) TO authenticated;

COMMIT;
