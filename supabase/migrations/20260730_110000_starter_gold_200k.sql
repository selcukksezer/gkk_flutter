-- Starter gold 1k → 200k so first enhance (+0 cost 100k) is affordable in tutorial.

ALTER TABLE public.users
  ALTER COLUMN gold SET DEFAULT 200000;

-- Top up early accounts still below first-enhance cost (old 1k starter / dungeon crumbs).
UPDATE public.users
SET gold = 200000
WHERE gold < 100000
  AND COALESCE(level, 1) <= 15;

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
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to create game profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_auth_user_profile(p_user_id UUID DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_auth RECORD;
  v_ref_code TEXT;
  v_referrer UUID;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = p_user_id) THEN
    SELECT raw_user_meta_data INTO v_auth
    FROM auth.users WHERE id = p_user_id;
    IF FOUND THEN
      v_ref_code := upper(btrim(COALESCE(v_auth.raw_user_meta_data->>'referral_code', '')));
      IF v_ref_code <> '' THEN
        SELECT u.auth_id INTO v_referrer
        FROM public.users u
        WHERE upper(u.referral_code) = v_ref_code
          AND u.auth_id IS DISTINCT FROM p_user_id
        LIMIT 1;
        IF v_referrer IS NOT NULL THEN
          UPDATE public.users
          SET referred_by = COALESCE(referred_by, v_referrer)
          WHERE auth_id = p_user_id AND referred_by IS NULL;
        END IF;
      END IF;
    END IF;
    RETURN jsonb_build_object('success', true, 'created', false);
  END IF;

  SELECT id, email, raw_user_meta_data
  INTO v_auth
  FROM auth.users
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Auth kaydı bulunamadı.');
  END IF;

  v_ref_code := upper(btrim(COALESCE(v_auth.raw_user_meta_data->>'referral_code', '')));
  IF v_ref_code <> '' THEN
    SELECT u.auth_id INTO v_referrer
    FROM public.users u
    WHERE upper(u.referral_code) = v_ref_code
      AND u.auth_id IS DISTINCT FROM p_user_id
    LIMIT 1;
  END IF;

  INSERT INTO public.users (
    auth_id, email, username, display_name, referral_code, referred_by, gold
  )
  VALUES (
    v_auth.id,
    v_auth.email,
    COALESCE(NULLIF(btrim(v_auth.raw_user_meta_data->>'username'), ''), split_part(v_auth.email, '@', 1)),
    COALESCE(
      NULLIF(btrim(v_auth.raw_user_meta_data->>'display_name'), ''),
      COALESCE(NULLIF(btrim(v_auth.raw_user_meta_data->>'username'), ''), split_part(v_auth.email, '@', 1))
    ),
    upper(substr(md5(v_auth.id::text || clock_timestamp()::text), 1, 8)),
    v_referrer,
    200000
  )
  ON CONFLICT (auth_id) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu profili oluşturulamadı.');
  END IF;

  RETURN jsonb_build_object('success', true, 'created', true);
END;
$$;
