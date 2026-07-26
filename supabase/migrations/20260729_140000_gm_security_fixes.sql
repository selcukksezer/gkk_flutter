-- GM security: block admin demote on assign; sync chat moderator on revoke.
BEGIN;

CREATE OR REPLACE FUNCTION public.staff_assign_gm(
  p_target_user_id UUID,
  p_permissions TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_sa_id UUID;
  v_perm TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'staff.manage_gm');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_target_user_id = v_actor THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize GM atayamazsınız.');
  END IF;

  IF public.staff_is_admin(p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin kullanıcıya GM atanamaz.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  UPDATE public.staff_assignments
  SET revoked_at = now(), revoke_reason = 'replaced'
  WHERE user_id = p_target_user_id AND revoked_at IS NULL;

  INSERT INTO public.staff_assignments (user_id, role, display_badge, granted_by)
  VALUES (p_target_user_id, 'gm', 'gm', v_actor)
  RETURNING id INTO v_sa_id;

  DELETE FROM public.staff_permissions WHERE staff_assignment_id = v_sa_id;

  FOREACH v_perm IN ARRAY COALESCE(p_permissions, ARRAY[]::TEXT[])
  LOOP
    IF EXISTS (SELECT 1 FROM public.staff_permission_catalog WHERE key = v_perm AND min_role = 'gm') THEN
      INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
      VALUES (v_sa_id, v_perm)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
  VALUES (v_sa_id, 'staff.view_hub')
  ON CONFLICT DO NOTHING;

  PERFORM public.staff_write_audit(
    v_actor, 'staff.manage_gm', 'assign_gm', 'user', p_target_user_id::text,
    jsonb_build_object('permissions', p_permissions),
    jsonb_build_object('assignment_id', v_sa_id)
  );

  PERFORM public.staff_sync_chat_moderator(p_target_user_id, true);

  RETURN jsonb_build_object('success', true, 'assignment_id', v_sa_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_revoke_gm(p_target_user_id UUID, p_reason TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'staff.manage_gm');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF public.staff_is_admin(p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin rolü kaldırılamaz.');
  END IF;

  UPDATE public.staff_assignments
  SET revoked_at = now(), revoke_reason = left(COALESCE(p_reason, 'revoked'), 200)
  WHERE user_id = p_target_user_id AND revoked_at IS NULL;

  PERFORM public.staff_sync_chat_moderator(p_target_user_id, false);

  PERFORM public.staff_write_audit(
    v_actor, 'staff.manage_gm', 'revoke_gm', 'user', p_target_user_id::text,
    jsonb_build_object('reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

COMMIT;
