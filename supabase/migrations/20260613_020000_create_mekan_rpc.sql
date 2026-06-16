-- Flutter calls create_mekan(p_mekan_type, p_name); DB only had open_mekan(p_user_id, ...).
-- Wrapper uses auth.uid() like create_guild.

CREATE OR REPLACE FUNCTION public.create_mekan(
  p_mekan_type TEXT,
  p_name TEXT
) RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  p_name := trim(p_name);
  IF p_name IS NULL OR length(p_name) < 2 OR length(p_name) > 50 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan adi 2-50 karakter arasinda olmali');
  END IF;

  RETURN public.open_mekan(v_auth_id, p_mekan_type, p_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.create_mekan(TEXT, TEXT) TO authenticated;
