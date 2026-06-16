BEGIN;

ALTER TABLE public.users
  ALTER COLUMN hospital_escape_attempted SET DEFAULT false,
  ALTER COLUMN prison_escape_attempted SET DEFAULT false;

UPDATE public.users
SET
  hospital_escape_attempted = COALESCE(hospital_escape_attempted, false),
  prison_escape_attempted = COALESCE(prison_escape_attempted, false)
WHERE
  hospital_escape_attempted IS NULL
  OR prison_escape_attempted IS NULL;

ALTER TABLE public.users
  ALTER COLUMN hospital_escape_attempted SET NOT NULL,
  ALTER COLUMN prison_escape_attempted SET NOT NULL;

CREATE OR REPLACE FUNCTION public.attempt_hospital_escape()
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user record;
  v_base_chance numeric := 0.15;
  v_roll numeric;
  v_locked_until timestamptz;
BEGIN
  v_user_id := auth.uid();
  RAISE LOG 'attempt_hospital_escape start uid=%', v_user_id;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE LOG 'attempt_hospital_escape user not found uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.hospital_until IS NULL OR v_user.hospital_until <= now() THEN
    RAISE LOG 'attempt_hospital_escape not in hospital uid=% hospital_until=%', v_user_id, v_user.hospital_until;
    RETURN jsonb_build_object('success', false, 'error', 'You are not in the hospital');
  END IF;

  IF COALESCE(v_user.hospital_escape_attempted, false) THEN
    RAISE LOG 'attempt_hospital_escape already attempted uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'Bu hastane sürecinde kaçmayı zaten denedin.');
  END IF;

  UPDATE public.users
  SET hospital_escape_attempted = true
  WHERE auth_id = v_user_id
    AND COALESCE(hospital_escape_attempted, false) = false
  RETURNING hospital_until INTO v_locked_until;

  IF NOT FOUND THEN
    RAISE LOG 'attempt_hospital_escape atomic guard blocked uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'Bu hastane sürecinde kaçma hakkın tükendi.');
  END IF;

  v_roll := random();
  RAISE LOG 'attempt_hospital_escape roll uid=% roll=% chance=%', v_user_id, v_roll, v_base_chance;

  IF v_roll <= v_base_chance THEN
    UPDATE public.users
    SET hospital_until = NULL,
        hospital_reason = NULL,
        hospital_escape_attempted = false
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', true, 'message', 'Gizlice hastaneden kacmayi basardin! Artik ozgursun.');
  END IF;

  UPDATE public.users
  SET hospital_until = COALESCE(v_locked_until, v_user.hospital_until, now()) + interval '15 minutes'
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object('success', true, 'escaped', false, 'message', 'Doktorlar seni koridorda yakaladi! Bu hastane surecinde tekrar kacamazsin. Tedavin +15 dakika uzatildi.');
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'attempt_hospital_escape exception uid=% err=%', v_user_id, SQLERRM;
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.attempt_hospital_escape() TO authenticated;

CREATE OR REPLACE FUNCTION public.attempt_prison_escape()
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user record;
  v_class record;
  v_base_chance numeric := 0.15;
  v_total_chance numeric;
  v_roll numeric;
  v_escape_bonus numeric := 0;
  v_locked_until timestamptz;
BEGIN
  v_user_id := auth.uid();
  RAISE LOG 'attempt_prison_escape start uid=%', v_user_id;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE LOG 'attempt_prison_escape user not found uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.prison_until IS NULL OR v_user.prison_until <= now() THEN
    RAISE LOG 'attempt_prison_escape not in prison uid=% prison_until=%', v_user_id, v_user.prison_until;
    RETURN jsonb_build_object('success', false, 'error', 'You are not in prison');
  END IF;

  IF COALESCE(v_user.prison_escape_attempted, false) THEN
    RAISE LOG 'attempt_prison_escape already attempted uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'Bu hapis surecinde kacmayi zaten denedin.');
  END IF;

  IF v_user.character_class IS NOT NULL THEN
    SELECT * INTO v_class FROM public.character_classes WHERE id = v_user.character_class;
    IF FOUND AND v_class.passive_bonuses ? 'prison_escape_bonus' THEN
      v_escape_bonus := (v_class.passive_bonuses->>'prison_escape_bonus')::numeric;
    END IF;
  END IF;

  v_total_chance := v_base_chance + v_escape_bonus;

  UPDATE public.users
  SET prison_escape_attempted = true
  WHERE auth_id = v_user_id
    AND COALESCE(prison_escape_attempted, false) = false
  RETURNING prison_until INTO v_locked_until;

  IF NOT FOUND THEN
    RAISE LOG 'attempt_prison_escape atomic guard blocked uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'Bu hapis surecinde kacma hakkin tukendi.');
  END IF;

  v_roll := random();
  RAISE LOG 'attempt_prison_escape roll uid=% roll=% chance=% bonus=%', v_user_id, v_roll, v_total_chance, v_escape_bonus;

  IF v_roll <= v_total_chance THEN
    UPDATE public.users
    SET prison_until = NULL,
        prison_reason = NULL,
        prison_escape_attempted = false
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', true, 'message', 'Hapishaneden basarili bir sekilde kactin!');
  END IF;

  UPDATE public.users
  SET prison_until = COALESCE(v_locked_until, v_user.prison_until, now()) + interval '15 minutes'
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object('success', true, 'escaped', false, 'message', 'Kacma plani basarisiz oldu! Bu hapis surecinde tekrar kacamazsin ve cezana 15 dakika eklendi.');
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'attempt_prison_escape exception uid=% err=%', v_user_id, SQLERRM;
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.attempt_prison_escape() TO authenticated;

COMMIT;