-- Legal consent is register-screen only. Do not block gameplay RPCs.
CREATE OR REPLACE FUNCTION public.policy_require_acceptance(p_user_id UUID DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN jsonb_build_object('ok', true, 'register_only', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.policy_require_acceptance(uuid) TO authenticated;
