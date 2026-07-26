-- Bootstrap theking as sole admin.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_ensure_theking_admin()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth UUID;
  v_existing UUID;
BEGIN
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
    VALUES (v_auth, 'admin', 'admin', v_auth);
  END IF;

  RETURN jsonb_build_object('success', true, 'user_id', v_auth, 'role', 'admin');
END;
$$;

SELECT public.staff_ensure_theking_admin();

GRANT EXECUTE ON FUNCTION public.staff_ensure_theking_admin() TO authenticated;

COMMIT;
