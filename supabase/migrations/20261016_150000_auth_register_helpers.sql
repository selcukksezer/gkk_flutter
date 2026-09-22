-- Auth register helpers:
-- 1) Public username availability check (pre-signup)
-- 2) Public referral code validate + bonus preview
-- 3) handle_new_user: username unique_violation fails signup (no orphan auth user)

CREATE OR REPLACE FUNCTION public.check_username_available(p_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_name text;
BEGIN
  v_name := btrim(COALESCE(p_username, ''));
  IF v_name = '' OR char_length(v_name) < 3 OR char_length(v_name) > 16 THEN
    RETURN jsonb_build_object('available', false, 'reason', 'invalid');
  END IF;
  IF v_name !~ '^[A-Za-z0-9_]+$' THEN
    RETURN jsonb_build_object('available', false, 'reason', 'invalid');
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.users u
    WHERE lower(u.username) = lower(v_name)
  ) THEN
    RETURN jsonb_build_object('available', false, 'reason', 'taken');
  END IF;
  RETURN jsonb_build_object('available', true);
END;
$$;

REVOKE ALL ON FUNCTION public.check_username_available(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_code text;
  v_valid boolean := false;
BEGIN
  v_code := upper(btrim(COALESCE(p_code, '')));
  IF v_code = '' THEN
    RETURN jsonb_build_object(
      'valid', false,
      'empty', true,
      'referred_gems', 25,
      'referrer_gems', 50,
      'unlock_level', 5
    );
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE upper(u.referral_code) = v_code
  ) INTO v_valid;

  RETURN jsonb_build_object(
    'valid', v_valid,
    'empty', false,
    'referred_gems', 25,
    'referrer_gems', 50,
    'unlock_level', 5
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_referral_code(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_ref_code TEXT;
  v_referrer UUID;
  v_username TEXT;
BEGIN
  v_ref_code := upper(btrim(COALESCE(NEW.raw_user_meta_data->>'referral_code', '')));
  IF v_ref_code <> '' THEN
    SELECT u.auth_id INTO v_referrer
    FROM public.users u
    WHERE upper(u.referral_code) = v_ref_code
    LIMIT 1;
    IF v_referrer IS NOT NULL AND v_referrer = NEW.id THEN
      v_referrer := NULL;
    END IF;
  END IF;

  v_username := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data->>'username'), ''),
    split_part(COALESCE(NEW.email, 'player'), '@', 1)
  );

  INSERT INTO public.users (
    auth_id, email, username, display_name, referral_code, referred_by, gold
  )
  VALUES (
    NEW.id,
    NEW.email,
    v_username,
    COALESCE(
      NULLIF(btrim(NEW.raw_user_meta_data->>'display_name'), ''),
      v_username
    ),
    upper(substr(md5(NEW.id::text || clock_timestamp()::text), 1, 8)),
    v_referrer,
    200000
  )
  ON CONFLICT (auth_id) DO UPDATE
  SET
    referred_by = COALESCE(public.users.referred_by, EXCLUDED.referred_by),
    username = COALESCE(NULLIF(public.users.username, ''), EXCLUDED.username),
    display_name = COALESCE(NULLIF(public.users.display_name, ''), EXCLUDED.display_name),
    email = COALESCE(public.users.email, EXCLUDED.email);

  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    IF SQLERRM ILIKE '%users_username_key%' OR SQLERRM ILIKE '%username%' THEN
      RAISE EXCEPTION 'USERNAME_TAKEN'
        USING ERRCODE = 'P0001',
              DETAIL = 'username already taken';
    END IF;
    RAISE;
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to create game profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;
