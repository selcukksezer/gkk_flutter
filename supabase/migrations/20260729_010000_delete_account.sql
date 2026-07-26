-- Account deletion RPC (App Store 5.1.1 / Play account deletion).

BEGIN;

CREATE OR REPLACE FUNCTION public.delete_account(p_username TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth UUID := auth.uid();
  v_username TEXT;
  v_expected TEXT := lower(btrim(COALESCE(p_username, '')));
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT lower(u.username) INTO v_username
  FROM public.users u
  WHERE u.auth_id = v_auth;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu kaydı bulunamadı.');
  END IF;

  IF v_expected = '' OR v_expected <> v_username THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı adı eşleşmiyor.');
  END IF;

  IF public.staff_is_admin(v_auth) OR public.staff_active_assignment(v_auth) IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Staff hesapları uygulama üzerinden silinemez.');
  END IF;

  -- Revoke any stale staff rows (should not exist for normal players).
  UPDATE public.staff_assignments
  SET revoked_at = now(), revoke_reason = 'account_deleted'
  WHERE user_id = v_auth AND revoked_at IS NULL;

  -- auth.users delete cascades to public.users via auth_id FK.
  DELETE FROM auth.users WHERE id = v_auth;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Auth kaydı silinemedi.');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_account(text) TO authenticated;

COMMIT;
