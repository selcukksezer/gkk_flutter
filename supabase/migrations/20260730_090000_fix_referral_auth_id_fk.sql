-- Fix referral register: referred_by must reference users.auth_id (auth.uid()),
-- not users.id. Old FK caused handle_new_user INSERT to fail whenever a valid
-- referral code was supplied → auth user created, public.users missing →
-- later RPCs return "User not found".
-- Also harden set_referral_code (was querying game.users) and enrich
-- get_referral_info for referrer progress UI.

BEGIN;

-- 1) Drop wrong FK (id-based)
ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_referred_by_fkey;

-- 2) Normalize any id-based referred_by values → auth_id
UPDATE public.users u
SET referred_by = r.auth_id
FROM public.users r
WHERE u.referred_by IS NOT NULL
  AND u.referred_by = r.id
  AND r.auth_id IS DISTINCT FROM r.id;

-- Orphans that match neither auth_id nor convertible id
UPDATE public.users u
SET referred_by = NULL
WHERE u.referred_by IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.users r WHERE r.auth_id = u.referred_by
  );

-- 3) Correct FK: referred_by → users.auth_id
ALTER TABLE public.users
  ADD CONSTRAINT users_referred_by_fkey
  FOREIGN KEY (referred_by) REFERENCES public.users (auth_id);

-- 4) set_referral_code: uniqueness against public.users (not game.users)
CREATE OR REPLACE FUNCTION public.set_referral_code()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.referral_code IS NULL OR btrim(NEW.referral_code) = '' THEN
    NEW.referral_code := upper(substr(md5(NEW.auth_id::text || clock_timestamp()::text), 1, 8));
    WHILE EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.referral_code = NEW.referral_code
        AND u.auth_id IS DISTINCT FROM NEW.auth_id
    ) LOOP
      NEW.referral_code := upper(substr(md5(NEW.auth_id::text || clock_timestamp()::text || random()::text), 1, 8));
    END LOOP;
  ELSE
    NEW.referral_code := upper(btrim(NEW.referral_code));
  END IF;
  RETURN NEW;
END;
$$;

-- 5) handle_new_user: valid referral → auth_id; invalid code → still create profile
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
    -- Never self-refer (shouldn't happen on insert) / ignore unknown codes.
    IF v_referrer IS NOT NULL AND v_referrer = NEW.id THEN
      v_referrer := NULL;
    END IF;
  END IF;

  v_username := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data->>'username'), ''),
    split_part(COALESCE(NEW.email, 'player'), '@', 1)
  );

  INSERT INTO public.users (
    auth_id, email, username, display_name, referral_code, referred_by
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
    v_referrer
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

-- 6) ensure_auth_user_profile: also wire referral if still missing
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
    -- Backfill referred_by from metadata when profile exists but link missing.
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

  INSERT INTO public.users (auth_id, email, username, display_name, referral_code, referred_by)
  VALUES (
    v_auth.id,
    v_auth.email,
    COALESCE(NULLIF(btrim(v_auth.raw_user_meta_data->>'username'), ''), split_part(v_auth.email, '@', 1)),
    COALESCE(
      NULLIF(btrim(v_auth.raw_user_meta_data->>'display_name'), ''),
      COALESCE(NULLIF(btrim(v_auth.raw_user_meta_data->>'username'), ''), split_part(v_auth.email, '@', 1))
    ),
    upper(substr(md5(v_auth.id::text || clock_timestamp()::text), 1, 8)),
    v_referrer
  )
  ON CONFLICT (auth_id) DO NOTHING;

  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu profili oluşturulamadı.');
  END IF;

  RETURN jsonb_build_object('success', true, 'created', true);
END;
$$;

-- 7) Richer referral dashboard for referrer
CREATE OR REPLACE FUNCTION public.get_referral_info()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_code TEXT;
  v_referred JSONB;
  v_claimable INTEGER := 0;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT referral_code INTO v_code FROM public.users WHERE auth_id = v_me;

  IF v_code IS NULL OR v_code = '' THEN
    v_code := upper(substr(md5(v_me::text || clock_timestamp()::text), 1, 8));
    UPDATE public.users SET referral_code = v_code WHERE auth_id = v_me;
  END IF;

  SELECT COALESCE(jsonb_agg(row_data ORDER BY sort_level DESC, sort_name), '[]'::jsonb)
  INTO v_referred
  FROM (
    SELECT
      jsonb_build_object(
        'auth_id', u.auth_id,
        'username', u.username,
        'display_name', COALESCE(NULLIF(u.display_name, ''), u.username),
        'level', COALESCE(u.level, 1),
        'power', COALESCE(u.power, 0),
        'character_class', u.character_class,
        'eligible', COALESCE(u.level, 1) >= 5,
        'claimed', rr.referrer_claimed_at IS NOT NULL,
        'reward_ready', COALESCE(u.level, 1) >= 5 AND rr.referrer_claimed_at IS NULL,
        'referrer_gems', COALESCE(rr.referrer_gems, 50),
        'progress_pct', LEAST(100, GREATEST(0, (COALESCE(u.level, 1) * 100) / 5)),
        'created_at', u.created_at
      ) AS row_data,
      COALESCE(u.level, 1) AS sort_level,
      lower(COALESCE(u.username, '')) AS sort_name
    FROM public.users u
    LEFT JOIN public.referral_rewards rr ON rr.referred_id = u.auth_id
    WHERE u.referred_by = v_me
  ) sub;

  SELECT COALESCE(SUM(sub.gems), 0)::INT INTO v_claimable FROM (
    SELECT rr.referrer_gems AS gems
    FROM public.referral_rewards rr
    WHERE rr.referrer_id = v_me AND rr.referrer_claimed_at IS NULL
    UNION ALL
    SELECT 50 FROM public.users u
    WHERE u.referred_by = v_me AND u.level >= 5
      AND NOT EXISTS (SELECT 1 FROM public.referral_rewards r2 WHERE r2.referred_id = u.auth_id)
    UNION ALL
    SELECT rr.referred_gems
    FROM public.referral_rewards rr
    WHERE rr.referred_id = v_me AND rr.referred_claimed_at IS NULL
    UNION ALL
    SELECT 25 FROM public.users me
    WHERE me.auth_id = v_me AND me.referred_by IS NOT NULL AND me.level >= 5
      AND NOT EXISTS (SELECT 1 FROM public.referral_rewards r3 WHERE r3.referred_id = v_me)
  ) sub;

  RETURN jsonb_build_object(
    'success', true,
    'referral_code', v_code,
    'referred', v_referred,
    'claimable_gems', v_claimable,
    'reward_level', 5,
    'referrer_gem_reward', 50,
    'referred_gem_reward', 25
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_auth_user_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referral_info() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_referral_rewards() TO authenticated;

COMMIT;
