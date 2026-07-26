-- Hub banner: sadece gerçekten açık kuyruk sayıları (triaged hariç).

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_get_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'staff.view_hub') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'open_tickets', (
      SELECT COUNT(*)
      FROM public.support_tickets
      WHERE status IN ('open', 'waiting_player')
    ),
    'pending_bugs', (
      SELECT COUNT(*)
      FROM public.bug_reports
      WHERE status IN ('submitted', 'needs_info')
    ),
    'open_chat_reports', (
      SELECT COUNT(*)
      FROM public.chat_reports
      WHERE status = 'open'
    ),
    'recent_audit', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'action', a.action,
          'created_at', a.created_at,
          'target_type', a.target_type,
          'actor_username', u.username
        ) AS row
        FROM public.staff_audit_log a
        LEFT JOIN public.users u ON u.auth_id = a.actor_user_id
        ORDER BY a.created_at DESC
        LIMIT 8
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

COMMIT;
