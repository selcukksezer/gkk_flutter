-- Chat report queue: staff delete path + realtime + resolve hardening.

BEGIN;

-- Staff/admin bypass for chat moderation permissions.
CREATE OR REPLACE FUNCTION public.has_chat_permission(
  p_actor_user_id UUID,
  p_permission TEXT,
  p_channel TEXT,
  p_guild_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor RECORD;
  v_auth_id UUID;
BEGIN
  SELECT id, guild_id, guild_role, auth_id INTO v_actor FROM public.users WHERE id = p_actor_user_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  v_auth_id := v_actor.auth_id;

  IF v_auth_id IS NOT NULL THEN
    IF p_permission = 'delete'
       AND public.staff_has_permission(v_auth_id, 'chat.delete_message') THEN
      RETURN true;
    END IF;
    IF p_permission = 'ban'
       AND public.staff_has_permission(v_auth_id, 'player.chat_mute') THEN
      RETURN true;
    END IF;
    IF p_permission = 'manage_filters'
       AND public.staff_has_permission(v_auth_id, 'chat.manage_filters') THEN
      RETURN true;
    END IF;
    IF p_permission = 'manage_moderators'
       AND public.staff_has_permission(v_auth_id, 'staff.manage_gm') THEN
      RETURN true;
    END IF;
  END IF;

  IF p_channel = 'guild'
     AND v_actor.guild_id = p_guild_id
     AND COALESCE(v_actor.guild_role, '') IN ('leader', 'commander')
  THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.chat_moderators cm
    WHERE cm.user_id = p_actor_user_id
      AND cm.revoked_at IS NULL
      AND (
        cm.scope = 'global'
        OR (cm.scope = 'channel' AND cm.channel = p_channel)
        OR (cm.scope = 'guild' AND p_channel = 'guild' AND cm.guild_id = p_guild_id)
      )
      AND (
        p_permission = 'delete' AND cm.can_delete
        OR p_permission = 'ban' AND cm.can_ban
        OR p_permission = 'manage_filters' AND cm.can_manage_filters
        OR p_permission = 'manage_moderators' AND cm.can_manage_moderators
      )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_resolve_chat_report(
  p_report_id UUID,
  p_action TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_actor_game_id UUID;
  v_report RECORD;
  v_delete_result JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'chat.view_reports');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_action NOT IN ('reviewed', 'action_taken', 'dismissed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz aksiyon.');
  END IF;

  SELECT r.*, cm.sender_user_id, cm.channel, cm.guild_id
  INTO v_report
  FROM public.chat_reports r
  JOIN public.chat_messages cm ON cm.id = r.message_id
  WHERE r.id = p_report_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  IF v_report.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor zaten sonuçlandırılmış.');
  END IF;

  SELECT u.id INTO v_actor_game_id FROM public.users u WHERE u.auth_id = v_actor;

  IF p_action = 'action_taken' THEN
    IF NOT public.staff_has_permission(v_actor, 'chat.delete_message') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Mesaj silme yetkisi yok.');
    END IF;

    v_delete_result := public.delete_chat_message(
      v_report.message_id,
      COALESCE(NULLIF(btrim(p_note), ''), 'report_action')
    );

    IF COALESCE((v_delete_result->>'success')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', COALESCE(v_delete_result->>'error', 'Mesaj silinemedi.')
      );
    END IF;
  END IF;

  UPDATE public.chat_reports
  SET status = p_action,
      resolved_at = now(),
      resolved_by = v_actor_game_id,
      resolution_note = NULLIF(left(btrim(COALESCE(p_note, '')), 400), '')
  WHERE id = p_report_id;

  PERFORM public.staff_write_audit(
    v_actor, 'chat.view_reports', 'resolve_report', 'chat_report', p_report_id::text,
    jsonb_build_object('action', p_action, 'note', p_note),
    jsonb_build_object('success', true, 'message_deleted', p_action = 'action_taken')
  );

  RETURN jsonb_build_object('success', true, 'status', p_action);
END;
$$;

-- Realtime for staff chat report queue auto-refresh.
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_reports;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;

COMMIT;
