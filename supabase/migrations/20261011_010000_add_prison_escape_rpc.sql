BEGIN;

CREATE OR REPLACE FUNCTION public.attempt_prison_escape(
)
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
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.prison_until IS NULL OR v_user.prison_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'You are not in prison');
  END IF;

  IF v_user.character_class IS NOT NULL THEN
     SELECT * INTO v_class FROM public.character_classes WHERE id = v_user.character_class;
     IF FOUND AND v_class.passive_bonuses ? 'prison_escape_bonus' THEN
        v_escape_bonus := (v_class.passive_bonuses->>'prison_escape_bonus')::numeric;
     END IF;
  END IF;

  v_total_chance := v_base_chance + v_escape_bonus;
  v_roll := random();

  IF v_roll <= v_total_chance THEN
    -- Success
    UPDATE public.users
    SET prison_until = NULL, prison_reason = NULL
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', true, 'message', 'Hapishaneden başarılı bir şekilde kaçtın!');
  ELSE
    -- Fail
    UPDATE public.users
    SET prison_until = v_user.prison_until + interval '15 minutes'
    WHERE id = v_user_id;

    RETURN jsonb_build_object('success', true, 'escaped', false, 'message', 'Kaçma planın suya düştü! Gardiyanlar seni yakaladı ve cezana 15 dakika eklendi.');
  END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.attempt_prison_escape() TO authenticated;

COMMIT;
