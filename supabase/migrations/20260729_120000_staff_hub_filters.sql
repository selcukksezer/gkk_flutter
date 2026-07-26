-- Staff hub: audit username/GM filters, ticket/bug/chat search.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_list_audit(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_action TEXT DEFAULT NULL,
  p_actor_user_id UUID DEFAULT NULL,
  p_target_type TEXT DEFAULT NULL,
  p_actor_query TEXT DEFAULT NULL,
  p_target_query TEXT DEFAULT NULL,
  p_actor_role TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_actor_q TEXT := lower(btrim(COALESCE(p_actor_query, '')));
  v_target_q TEXT := lower(btrim(COALESCE(p_target_query, '')));
  v_role TEXT := lower(btrim(COALESCE(p_actor_role, '')));
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'staff.view_audit') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  IF v_role NOT IN ('', 'admin', 'gm') THEN
    v_role := '';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', a.id,
          'actor_user_id', a.actor_user_id,
          'actor_username', u.username,
          'actor_display_name', u.display_name,
          'actor_role', sa.role,
          'actor_badge', sa.display_badge,
          'permission_key', a.permission_key,
          'action', a.action,
          'target_type', a.target_type,
          'target_id', a.target_id,
          'target_username', tu.username,
          'payload', a.payload,
          'result', a.result,
          'created_at', a.created_at
        ) AS row
        FROM public.staff_audit_log a
        LEFT JOIN public.users u ON u.auth_id = a.actor_user_id
        LEFT JOIN public.staff_assignments sa
          ON sa.user_id = a.actor_user_id AND sa.revoked_at IS NULL
        LEFT JOIN public.users tu
          ON a.target_type = 'user' AND tu.auth_id::text = a.target_id
        WHERE (p_action IS NULL OR a.action = p_action)
          AND (p_actor_user_id IS NULL OR a.actor_user_id = p_actor_user_id)
          AND (p_target_type IS NULL OR a.target_type = p_target_type)
          AND (
            v_actor_q = ''
            OR lower(u.username) LIKE '%' || v_actor_q || '%'
            OR lower(COALESCE(u.display_name, '')) LIKE '%' || v_actor_q || '%'
          )
          AND (
            v_target_q = ''
            OR (
              a.target_type = 'user'
              AND (
                lower(COALESCE(tu.username, '')) LIKE '%' || v_target_q || '%'
                OR lower(COALESCE(tu.display_name, '')) LIKE '%' || v_target_q || '%'
              )
            )
          )
          AND (
            v_role = ''
            OR (v_role = 'admin' AND sa.role = 'admin')
            OR (v_role = 'gm' AND sa.role = 'gm')
          )
        ORDER BY a.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
        OFFSET GREATEST(p_offset, 0)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_tickets(
  p_status TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_player_query TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_q TEXT := lower(btrim(COALESCE(p_player_query, '')));
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'ticket.view_all') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'updated_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', t.id,
          'player_id', t.player_id,
          'username', u.username,
          'category', t.category,
          'subject', t.subject,
          'status', t.status,
          'priority', t.priority,
          'assigned_staff_id', t.assigned_staff_id,
          'created_at', t.created_at,
          'updated_at', t.updated_at
        ) AS row
        FROM public.support_tickets t
        JOIN public.users u ON u.auth_id = t.player_id
        WHERE (p_status IS NULL OR t.status = p_status)
          AND (p_category IS NULL OR t.category = p_category)
          AND (
            v_q = ''
            OR lower(u.username) LIKE '%' || v_q || '%'
            OR lower(COALESCE(u.display_name, '')) LIKE '%' || v_q || '%'
            OR lower(t.subject) LIKE '%' || v_q || '%'
          )
        ORDER BY t.updated_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
        OFFSET GREATEST(p_offset, 0)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_bug_reports(
  p_status TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_player_query TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_q TEXT := lower(btrim(COALESCE(p_player_query, '')));
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'bug.view') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', b.id,
          'player_id', b.player_id,
          'username', u.username,
          'category', b.category,
          'title', b.title,
          'status', b.status,
          'reward_gems_approved', b.reward_gems_approved,
          'created_at', b.created_at
        ) AS row
        FROM public.bug_reports b
        JOIN public.users u ON u.auth_id = b.player_id
        WHERE (p_status IS NULL OR b.status = p_status)
          AND (
            v_q = ''
            OR lower(u.username) LIKE '%' || v_q || '%'
            OR lower(COALESCE(u.display_name, '')) LIKE '%' || v_q || '%'
            OR lower(b.title) LIKE '%' || v_q || '%'
          )
        ORDER BY b.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_chat_reports(
  p_status TEXT DEFAULT 'open',
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_sender_query TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_q TEXT := lower(btrim(COALESCE(p_sender_query, '')));
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'chat.view_reports') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', r.id,
          'message_id', r.message_id,
          'reason', r.reason,
          'details', r.details,
          'status', r.status,
          'created_at', r.created_at,
          'reporter_username', ru.username,
          'sender_username', su.username,
          'sender_auth_id', su.auth_id,
          'message_preview', left(COALESCE(cm.content, ''), 120),
          'channel', cm.channel
        ) AS row
        FROM public.chat_reports r
        JOIN public.chat_messages cm ON cm.id = r.message_id
        JOIN public.users ru ON ru.id = r.reporter_user_id
        JOIN public.users su ON su.id = cm.sender_user_id
        WHERE (p_status IS NULL OR r.status = p_status)
          AND (
            v_q = ''
            OR lower(su.username) LIKE '%' || v_q || '%'
            OR lower(COALESCE(su.display_name, '')) LIKE '%' || v_q || '%'
            OR lower(ru.username) LIKE '%' || v_q || '%'
          )
        ORDER BY r.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
        OFFSET GREATEST(p_offset, 0)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_list_audit(int, int, text, uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_tickets(text, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_bug_reports(text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_chat_reports(text, int, int, text) TO authenticated;

COMMIT;
