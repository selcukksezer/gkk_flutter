-- LiveOps: admin-only. GM liveops izinlerini kaldır.

BEGIN;

UPDATE public.staff_permission_catalog
SET min_role = 'admin', is_dangerous = true
WHERE key LIKE 'liveops.%';

DELETE FROM public.staff_permissions sp
USING public.staff_assignments sa
WHERE sp.staff_assignment_id = sa.id
  AND sa.revoked_at IS NULL
  AND sa.role = 'gm'
  AND sp.permission_key LIKE 'liveops.%';

CREATE OR REPLACE FUNCTION public.staff_has_permission(
  p_user_id UUID,
  p_permission_key TEXT
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sa public.staff_assignments;
BEGIN
  IF p_user_id IS NULL OR p_permission_key IS NULL THEN
    RETURN false;
  END IF;

  v_sa := public.staff_active_assignment(p_user_id);
  IF v_sa.id IS NULL THEN
    RETURN false;
  END IF;

  IF p_permission_key LIKE 'liveops.%' AND v_sa.role <> 'admin' THEN
    RETURN false;
  END IF;

  IF v_sa.role = 'admin' THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.staff_permissions sp
    WHERE sp.staff_assignment_id = v_sa.id
      AND sp.permission_key = p_permission_key
  );
END;
$$;

COMMIT;
