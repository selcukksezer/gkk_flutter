-- ============================================================================
-- REFERRAL GEM ÖDÜL SİSTEMİ
-- - Kayıttaki referral_code metadata'sı artık referred_by'a bağlanıyor
--   (handle_new_user güncellendi; önceden yok sayılıyordu).
-- - Her kullanıcıya referral_code üretilir (yoksa).
-- - Davet edilen Level 5'e ulaşınca: davet eden +50 gem, edilen +25 gem.
-- - claim_referral_rewards ile toplu tahsil; get_referral_info ile ekran verisi.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.referral_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL,
  referred_id UUID NOT NULL UNIQUE,
  referrer_gems INTEGER NOT NULL DEFAULT 50,
  referred_gems INTEGER NOT NULL DEFAULT 25,
  referrer_claimed_at TIMESTAMPTZ,
  referred_claimed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS referral_rewards_referrer_idx
  ON public.referral_rewards (referrer_id);

ALTER TABLE public.referral_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referral_rewards_select_own" ON public.referral_rewards;
CREATE POLICY "referral_rewards_select_own" ON public.referral_rewards
  FOR SELECT USING (auth.uid() IN (referrer_id, referred_id));

-- Kod olmayan kullanıcılara üret
UPDATE public.users
SET referral_code = upper(substr(md5(auth_id::text || now()::text), 1, 8))
WHERE referral_code IS NULL OR referral_code = '';

-- Kayıtta referral bağlama + kod üretimi
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_ref_code TEXT;
    v_referrer UUID;
BEGIN
    v_ref_code := NEW.raw_user_meta_data->>'referral_code';
    IF v_ref_code IS NOT NULL AND trim(v_ref_code) != '' THEN
        SELECT auth_id INTO v_referrer
        FROM public.users
        WHERE upper(referral_code) = upper(trim(v_ref_code))
        LIMIT 1;
    END IF;

    INSERT INTO public.users (auth_id, email, username, display_name, referral_code, referred_by)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        upper(substr(md5(NEW.id::text || now()::text), 1, 8)),
        v_referrer
    )
    ON CONFLICT (auth_id) DO NOTHING;
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to create game profile for user %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

-- ── Ödülleri tahsil et ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.claim_referral_rewards()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_row RECORD;
  v_total INTEGER := 0;
  v_count INTEGER := 0;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Level 5+ olan ama henüz ödül kaydı olmayan davetliler için kayıt oluştur
  INSERT INTO public.referral_rewards (referrer_id, referred_id)
  SELECT u.referred_by, u.auth_id
  FROM public.users u
  WHERE u.referred_by IS NOT NULL
    AND u.level >= 5
    AND (u.referred_by = v_me OR u.auth_id = v_me)
  ON CONFLICT (referred_id) DO NOTHING;

  -- Davet eden payı
  FOR v_row IN
    SELECT id, referrer_gems FROM public.referral_rewards
    WHERE referrer_id = v_me AND referrer_claimed_at IS NULL
    FOR UPDATE
  LOOP
    UPDATE public.referral_rewards
    SET referrer_claimed_at = now()
    WHERE id = v_row.id;
    v_total := v_total + v_row.referrer_gems;
    v_count := v_count + 1;
  END LOOP;

  -- Davet edilen payı (kendi bonusum)
  FOR v_row IN
    SELECT id, referred_gems FROM public.referral_rewards
    WHERE referred_id = v_me AND referred_claimed_at IS NULL
    FOR UPDATE
  LOOP
    UPDATE public.referral_rewards
    SET referred_claimed_at = now()
    WHERE id = v_row.id;
    v_total := v_total + v_row.referred_gems;
    v_count := v_count + 1;
  END LOOP;

  IF v_total > 0 THEN
    UPDATE public.users
    SET gems = COALESCE(gems, 0) + v_total,
        updated_at = now()
    WHERE auth_id = v_me;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'gems_earned', v_total,
    'rewards_claimed', v_count
  );
END;
$$;

-- ── Ekran verisi ────────────────────────────────────────────────────────────
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

  -- Kod hâlâ yoksa üret
  IF v_code IS NULL OR v_code = '' THEN
    v_code := upper(substr(md5(v_me::text || now()::text), 1, 8));
    UPDATE public.users SET referral_code = v_code WHERE auth_id = v_me;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'username', u.username,
    'level', u.level,
    'eligible', u.level >= 5,
    'claimed', rr.referrer_claimed_at IS NOT NULL
  ) ORDER BY u.level DESC), '[]'::jsonb)
  INTO v_referred
  FROM public.users u
  LEFT JOIN public.referral_rewards rr ON rr.referred_id = u.auth_id
  WHERE u.referred_by = v_me;

  -- Tahsil edilebilir gem: davet eden payı
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
    'claimable_gems', v_claimable
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_referral_rewards() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referral_info() TO authenticated;
