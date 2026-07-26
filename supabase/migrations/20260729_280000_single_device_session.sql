-- Single active device session: new login revokes other refresh tokens + DB epoch bump.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS active_device_id TEXT,
  ADD COLUMN IF NOT EXISTS session_epoch BIGINT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_users_active_device_id
  ON public.users (active_device_id)
  WHERE active_device_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.user_device_login_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  auth_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'mobile',
  session_epoch BIGINT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('claim', 'verify_fail', 'superseded')),
  ip_hint TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_device_login_log_auth_created
  ON public.user_device_login_log (auth_id, created_at DESC);

ALTER TABLE public.user_device_login_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_device_login_log_select_own ON public.user_device_login_log;
CREATE POLICY user_device_login_log_select_own
  ON public.user_device_login_log FOR SELECT TO authenticated
  USING (auth_id = auth.uid());

CREATE OR REPLACE FUNCTION public.get_my_device_session()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_row public.users%ROWTYPE;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_row FROM public.users WHERE auth_id = v_auth;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'device_id', v_row.active_device_id,
    'session_epoch', COALESCE(v_row.session_epoch, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_device_session(
  p_device_id TEXT,
  p_platform TEXT DEFAULT 'mobile'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_device TEXT := NULLIF(btrim(p_device_id), '');
  v_platform TEXT := COALESCE(NULLIF(btrim(p_platform), ''), 'mobile');
  v_epoch BIGINT;
  v_prev_device TEXT;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  IF v_device IS NULL OR length(v_device) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid device id');
  END IF;

  SELECT active_device_id INTO v_prev_device
  FROM public.users WHERE auth_id = v_auth FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  UPDATE public.users
  SET
    active_device_id = v_device,
    session_epoch = COALESCE(session_epoch, 0) + 1,
    last_login_at = now(),
    updated_at = now()
  WHERE auth_id = v_auth
  RETURNING session_epoch INTO v_epoch;

  INSERT INTO public.user_device_login_log (
    auth_id, device_id, platform, session_epoch, action
  ) VALUES (
    v_auth, v_device, v_platform, v_epoch,
    CASE WHEN v_prev_device IS NOT NULL AND v_prev_device <> v_device THEN 'superseded' ELSE 'claim' END
  );

  RETURN jsonb_build_object(
    'success', true,
    'device_id', v_device,
    'session_epoch', v_epoch,
    'superseded_previous', v_prev_device IS NOT NULL AND v_prev_device <> v_device
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_device_session(
  p_device_id TEXT,
  p_session_epoch BIGINT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_device TEXT := NULLIF(btrim(p_device_id), '');
  v_epoch BIGINT := COALESCE(p_session_epoch, 0);
  v_row public.users%ROWTYPE;
BEGIN
  IF v_auth IS NULL THEN
    RETURN jsonb_build_object('success', false, 'valid', false, 'reason', 'not_authenticated');
  END IF;
  IF v_device IS NULL THEN
    RETURN jsonb_build_object('success', false, 'valid', false, 'reason', 'invalid_device');
  END IF;

  SELECT * INTO v_row FROM public.users WHERE auth_id = v_auth;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'valid', false, 'reason', 'user_not_found');
  END IF;

  IF v_row.active_device_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'valid', true,
      'reason', 'unclaimed',
      'session_epoch', COALESCE(v_row.session_epoch, 0)
    );
  END IF;

  IF v_row.active_device_id <> v_device THEN
    INSERT INTO public.user_device_login_log (
      auth_id, device_id, platform, session_epoch, action
    ) VALUES (
      v_auth, v_device, 'mobile', COALESCE(v_row.session_epoch, 0), 'verify_fail'
    );
    RETURN jsonb_build_object(
      'success', true,
      'valid', false,
      'reason', 'other_device_active',
      'active_device_id', v_row.active_device_id,
      'session_epoch', COALESCE(v_row.session_epoch, 0)
    );
  END IF;

  IF COALESCE(v_row.session_epoch, 0) <> v_epoch THEN
    RETURN jsonb_build_object(
      'success', true,
      'valid', false,
      'reason', 'session_superseded',
      'session_epoch', COALESCE(v_row.session_epoch, 0)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'valid', true,
    'reason', 'ok',
    'session_epoch', COALESCE(v_row.session_epoch, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_device_session() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_device_session(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_device_session(text, bigint) TO authenticated;
