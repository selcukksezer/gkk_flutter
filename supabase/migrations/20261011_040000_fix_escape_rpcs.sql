BEGIN;

CREATE OR REPLACE FUNCTION public.attempt_hospital_escape()
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user record;
  v_base_chance numeric := 0.15;
  v_roll numeric;
BEGIN
  v_user_id := auth.uid();
  RAISE LOG 'attempt_hospital_escape started for uid: %', v_user_id;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE LOG 'User not found for uid: %', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.hospital_until IS NULL OR v_user.hospital_until <= now() THEN
    RAISE LOG 'User % is not in hospital', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'You are not in the hospital');
  END IF;

  IF v_user.hospital_escape_attempted = true THEN
    RAISE LOG 'User % already attempted hospital escape', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'Daha önce kaçmayı denedin, artık çok geç!');
  END IF;

  v_roll := random();
  RAISE LOG 'User % hospital escape roll: % vs chance %', v_user_id, v_roll, v_base_chance;

  IF v_roll <= v_base_chance THEN
    -- Success
    UPDATE public.users
    SET hospital_until = NULL, hospital_escape_attempted = false
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', true, 'message', 'Gizlice hastaneden kaçmayı başardın! Artık özgürsün.');
  ELSE
    -- Fail
    UPDATE public.users
    SET hospital_until = v_user.hospital_until + interval '15 minutes', hospital_escape_attempted = true
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', false, 'message', 'Doktorlar seni koridorda yakaladı! Tedavin uzatıldı (+15 Dakika).');
  END IF;

EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Exception in attempt_hospital_escape: %', SQLERRM;
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
BEGIN
  v_user_id := auth.uid();
  RAISE LOG 'attempt_prison_escape started for uid: %', v_user_id;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE LOG 'User not found for uid: %', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.prison_until IS NULL OR v_user.prison_until <= now() THEN
    RAISE LOG 'User % is not in prison', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'You are not in prison');
  END IF;

  IF v_user.prison_escape_attempted = true THEN
    RAISE LOG 'User % already attempted prison escape', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'Daha önce kaçmayı denedin, çok dikkat çekiyorsun!');
  END IF;

  IF v_user.character_class IS NOT NULL THEN
     SELECT * INTO v_class FROM public.character_classes WHERE id = v_user.character_class;
     IF FOUND AND v_class.passive_bonuses ? 'prison_escape_bonus' THEN
        v_escape_bonus := (v_class.passive_bonuses->>'prison_escape_bonus')::numeric;
     END IF;
  END IF;

  v_total_chance := v_base_chance + v_escape_bonus;
  v_roll := random();
  RAISE LOG 'User % prison escape roll: % vs chance % (bonus %)', v_user_id, v_roll, v_total_chance, v_escape_bonus;

  IF v_roll <= v_total_chance THEN
    -- Success
    UPDATE public.users
    SET prison_until = NULL, prison_reason = NULL, prison_escape_attempted = false
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', true, 'message', 'Hapishaneden başarılı bir şekilde kaçtın!');
  ELSE
    -- Fail
    UPDATE public.users
    SET prison_until = v_user.prison_until + interval '15 minutes', prison_escape_attempted = true
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', false, 'message', 'Kaçma planın suya düştü! Gardiyanlar seni yakaladı ve cezana 15 dakika eklendi.');
  END IF;

EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'Exception in attempt_prison_escape: %', SQLERRM;
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.attempt_prison_escape() TO authenticated;

COMMIT;
