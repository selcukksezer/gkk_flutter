-- Policy acceptance fails when auth.users exists but public.users row missing
-- (handle_new_user trigger may have failed silently). Ensure profile before accept.

BEGIN;

CREATE OR REPLACE FUNCTION public.ensure_auth_user_profile(p_user_id UUID DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_auth RECORD;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = p_user_id) THEN
    RETURN jsonb_build_object('success', true, 'created', false);
  END IF;

  SELECT id, email, raw_user_meta_data
  INTO v_auth
  FROM auth.users
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Auth kaydı bulunamadı.');
  END IF;

  INSERT INTO public.users (auth_id, email, username, display_name, referral_code)
  VALUES (
    v_auth.id,
    v_auth.email,
    COALESCE(v_auth.raw_user_meta_data->>'username', split_part(v_auth.email, '@', 1)),
    COALESCE(v_auth.raw_user_meta_data->>'display_name', split_part(v_auth.email, '@', 1)),
    upper(substr(md5(v_auth.id::text || clock_timestamp()::text), 1, 8))
  )
  ON CONFLICT (auth_id) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu profili oluşturulamadı.');
  END IF;

  RETURN jsonb_build_object('success', true, 'created', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_legal_document(p_doc_type TEXT, p_locale TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_locale TEXT := lower(COALESCE(NULLIF(btrim(p_locale), ''), 'tr'));
  v_version INTEGER;
  v_ensure JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF p_doc_type NOT IN ('terms', 'privacy', 'community') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz belge türü.');
  END IF;

  v_ensure := public.ensure_auth_user_profile(v_user);
  IF COALESCE((v_ensure->>'success')::boolean, false) = false THEN
    RETURN v_ensure;
  END IF;

  SELECT version INTO v_version
  FROM public.legal_documents
  WHERE doc_type = p_doc_type AND is_active = true AND locale = v_locale
  LIMIT 1;

  IF v_version IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Belge bulunamadı.');
  END IF;

  INSERT INTO public.policy_acceptances (user_id, doc_type, version)
  VALUES (v_user, p_doc_type, v_version)
  ON CONFLICT (user_id, doc_type, version) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'status', public.get_my_policy_status(v_locale));
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_auth_user_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_legal_document(text, text) TO authenticated;

COMMIT;
