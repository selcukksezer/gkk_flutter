BEGIN;

CREATE OR REPLACE FUNCTION public.attempt_hospital_escape(
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user record;
  v_base_chance numeric := 0.15;
  v_roll numeric;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.hospital_until IS NULL OR v_user.hospital_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'You are not in the hospital');
  END IF;

  v_roll := random();

  IF v_roll <= v_base_chance THEN
    -- Success
    UPDATE public.users
    SET hospital_until = NULL
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', true, 'message', 'Gizlice hastaneden kaçmayı başardın! Artık özgürsün.');
  ELSE
    -- Fail
    UPDATE public.users
    SET hospital_until = v_user.hospital_until + interval '15 minutes'
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', false, 'message', 'Doktorlar seni koridorda yakaladı! Tedavin uzatıldı (+15 Dakika).');
  END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.attempt_hospital_escape() TO authenticated;

COMMIT;
