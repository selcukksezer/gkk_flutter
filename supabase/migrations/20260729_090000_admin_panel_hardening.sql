-- Admin panel hardening: bootstrap guard + dashboard ticket count alignment.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_ensure_theking_admin()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_auth UUID;
  v_existing UUID;
BEGIN
  IF v_actor IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik doğrulama gerekli.');
  END IF;

  IF NOT public.staff_is_admin(v_actor) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece mevcut admin çalıştırabilir.');
  END IF;

  SELECT auth_id INTO v_auth
  FROM public.users
  WHERE lower(username) = 'theking'
  LIMIT 1;

  IF v_auth IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'theking kullanıcısı bulunamadı. Önce hesap oluşturun.'
    );
  END IF;

  SELECT id INTO v_existing
  FROM public.staff_assignments
  WHERE user_id = v_auth AND revoked_at IS NULL
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    UPDATE public.staff_assignments
    SET role = 'admin', display_badge = 'admin'
    WHERE id = v_existing;
  ELSE
    INSERT INTO public.staff_assignments (user_id, role, display_badge, granted_by)
    VALUES (v_auth, 'admin', 'admin', v_actor);
  END IF;

  RETURN jsonb_build_object('success', true, 'user_id', v_auth, 'role', 'admin');
END;
$$;

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
      WHERE status IN ('open', 'waiting_player', 'staff_reply')
    ),
    'pending_bugs', (
      SELECT COUNT(*)
      FROM public.bug_reports
      WHERE status IN ('submitted', 'triaged', 'needs_info')
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
