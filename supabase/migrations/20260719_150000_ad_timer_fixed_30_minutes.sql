-- Her tamamlanan ödüllü reklam, aktif hastane/cezaevi süresini 30 dakika azaltır.
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
  v_reduction CONSTANT INTERVAL := INTERVAL '30 minutes';
  v_until TIMESTAMPTZ;
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

  v_new_until := v_until - v_reduction;
  IF v_new_until <= now() THEN
    v_new_until := NULL;
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
    'reduction_minutes', 30,
    'uses_left', v_daily_limit - COALESCE(v_uses, 0) - 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.reduce_timer_with_ad(TEXT) TO authenticated;