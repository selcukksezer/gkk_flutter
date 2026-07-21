-- ============================================================================
-- REKLAMLA SÜRE KISALTMA (hapishane + hastane) + release_from_prison fix
-- - reduce_timer_with_ad(p_timer): kalan süreyi %25 kısaltır, günde 3 hak/timer
-- - release_from_prison: repo'da eksikti (audit); ayrıca bailsiz çağrının
--   süresi dolmadan salıverme exploiti kapatıldı.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ad_timer_reductions (
  user_id UUID NOT NULL,
  timer_type TEXT NOT NULL CHECK (timer_type IN ('prison', 'hospital')),
  used_on DATE NOT NULL DEFAULT CURRENT_DATE,
  uses INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, timer_type, used_on)
);

ALTER TABLE public.ad_timer_reductions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ad_timer_reductions_select_own" ON public.ad_timer_reductions;
CREATE POLICY "ad_timer_reductions_select_own" ON public.ad_timer_reductions
  FOR SELECT USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.reduce_timer_with_ad(p_timer TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user RECORD;
  v_uses INTEGER := 0;
  v_daily_limit CONSTANT INTEGER := 3;
  v_until TIMESTAMPTZ;
  v_remaining INTERVAL;
  v_new_until TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_timer NOT IN ('prison', 'hospital') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid timer');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  v_until := CASE p_timer
    WHEN 'prison' THEN v_user.prison_until
    ELSE v_user.hospital_until
  END;

  IF v_until IS NULL OR v_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif süre yok');
  END IF;

  SELECT uses INTO v_uses
  FROM public.ad_timer_reductions
  WHERE user_id = v_user_id AND timer_type = p_timer AND used_on = CURRENT_DATE;

  IF COALESCE(v_uses, 0) >= v_daily_limit THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'daily_limit',
      'message', 'Bugünlük reklam hakkın bitti (3/3).'
    );
  END IF;

  -- Kalan sürenin %25'ini düş
  v_remaining := v_until - now();
  v_new_until := v_until - (v_remaining * 0.25);
  IF v_new_until <= now() THEN
    v_new_until := NULL; -- kısaltma süreyi bitirdiyse tamamen serbest
  END IF;

  IF p_timer = 'prison' THEN
    UPDATE public.users
    SET prison_until = v_new_until,
        in_prison = (v_new_until IS NOT NULL),
        prison_reason = CASE WHEN v_new_until IS NULL THEN NULL ELSE prison_reason END,
        updated_at = now()
    WHERE auth_id = v_user_id;
  ELSE
    UPDATE public.users
    SET hospital_until = v_new_until,
        updated_at = now()
    WHERE auth_id = v_user_id;
  END IF;

  INSERT INTO public.ad_timer_reductions (user_id, timer_type, used_on, uses)
  VALUES (v_user_id, p_timer, CURRENT_DATE, 1)
  ON CONFLICT (user_id, timer_type, used_on)
  DO UPDATE SET uses = public.ad_timer_reductions.uses + 1;

  RETURN jsonb_build_object(
    'success', true,
    'new_until', v_new_until,
    'released', v_new_until IS NULL,
    'uses_left', v_daily_limit - COALESCE(v_uses, 0) - 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reduce_timer_with_ad(TEXT) TO authenticated;

-- ── release_from_prison: repo kaydı + bailsiz erken çıkış exploiti fix ──────
CREATE OR REPLACE FUNCTION public.release_from_prison(p_use_bail BOOLEAN DEFAULT false)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id UUID;
    v_user RECORD;
    v_now TIMESTAMPTZ;
    v_bail_gems INT;
    v_remaining_mins INT;
BEGIN
    v_user_id := auth.uid();
    v_now := NOW();

    SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id;

    IF v_user IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'User not found in public.users');
    END IF;

    IF v_user.prison_until IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not in prison');
    END IF;

    IF p_use_bail THEN
        IF v_user.prison_until <= v_now THEN
            -- Süre zaten dolmuş; gem almadan temizle
            UPDATE public.users SET
                in_prison = false, prison_until = NULL, prison_reason = NULL,
                updated_at = v_now
            WHERE auth_id = v_user_id;
            RETURN jsonb_build_object('success', true, 'message', 'Prison time served');
        END IF;

        v_remaining_mins := CEIL(EXTRACT(EPOCH FROM (v_user.prison_until - v_now)) / 60);
        v_bail_gems := GREATEST(1, v_remaining_mins);

        IF v_user.gems < v_bail_gems THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems', 'cost', v_bail_gems);
        END IF;

        UPDATE public.users SET
            gems = gems - v_bail_gems,
            in_prison = false,
            prison_until = NULL,
            prison_reason = NULL,
            updated_at = v_now
        WHERE auth_id = v_user_id;

        RETURN jsonb_build_object('success', true, 'message', 'Released from prison via bail', 'gems_spent', v_bail_gems);
    ELSE
        -- Bailsiz salıverme SADECE süre dolduysa
        IF v_user.prison_until > v_now THEN
            RETURN jsonb_build_object('success', false, 'error', 'Süre henüz dolmadı');
        END IF;

        UPDATE public.users SET
            in_prison = false,
            prison_until = NULL,
            prison_reason = NULL,
            updated_at = v_now
        WHERE auth_id = v_user_id;

        RETURN jsonb_build_object('success', true, 'message', 'Prison time served');
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.release_from_prison(BOOLEAN) TO authenticated;
