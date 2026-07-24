-- QA smoke: F2P player journey — energy, dungeon validation, quests, reputation
-- Run: SELECT public.qa_player_journey_f2p();

CREATE OR REPLACE FUNCTION public.qa_player_journey_f2p()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := gen_random_uuid();
  v_steps jsonb := '[]'::jsonb;
  v_ok boolean;
  v_energy integer;
  v_dungeons jsonb;
  v_enter jsonb;
  v_quests jsonb;
  v_claim jsonb;
  v_overview jsonb;
  v_dungeon_id text;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.dungeon_runs WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_journey_f2p'
  );
  DELETE FROM auth.users WHERE email = 'qa_journey_f2p@sim.local';
  DELETE FROM public.users WHERE username = 'qa_journey_f2p';

  INSERT INTO auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) VALUES (
    v_auth, 'authenticated', 'authenticated',
    'qa_journey_f2p@sim.local', now(), now(), now(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('username', 'qa_journey_f2p', 'is_bot', true)
  );

  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
    attack, defense, health, max_health, power, gems, reputation, created_at, updated_at
  ) VALUES (
    v_auth, v_auth, 'qa_journey_f2p', 'qa_journey_f2p@sim.local', 'QA Journey F2P',
    5, 500, 10000, 100, 100, 20, 15, 100, 100, 150, 10, 100, now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    level = 5,
    energy = 100,
    reputation = 100,
    updated_at = now();

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);

  -- STEP 1: energy check
  SELECT energy INTO v_energy FROM public.users WHERE auth_id = v_auth;
  v_ok := COALESCE(v_energy, 0) > 0;
  v_steps := v_steps || jsonb_build_array(jsonb_build_object(
    'step', 'energy_check',
    'pass', v_ok,
    'detail', jsonb_build_object('energy', v_energy)
  ));

  -- STEP 2: dungeon list shape
  v_dungeons := public.get_dungeons();
  v_ok := v_dungeons IS NOT NULL
      AND (
        jsonb_typeof(v_dungeons) = 'array'
        OR (v_dungeons ? 'dungeons' AND jsonb_typeof(v_dungeons->'dungeons') = 'array')
      );
  v_steps := v_steps || jsonb_build_array(jsonb_build_object(
    'step', 'dungeon_list_shape',
    'pass', v_ok
  ));

  -- STEP 3: dungeon entry validation (zero energy → structured error, no crash)
  UPDATE public.users SET energy = 0 WHERE auth_id = v_auth;
  SELECT id INTO v_dungeon_id FROM public.dungeons ORDER BY dungeon_order NULLS FIRST, id LIMIT 1;
  IF v_dungeon_id IS NULL THEN
    v_dungeon_id := 'dng_001';
  END IF;

  v_enter := public.enter_dungeon(v_auth, v_dungeon_id);
  v_ok := v_enter IS NOT NULL
      AND (v_enter ? 'error' OR v_enter ? 'success');
  v_steps := v_steps || jsonb_build_array(jsonb_build_object(
    'step', 'dungeon_entry_validation',
    'pass', v_ok,
    'detail', v_enter
  ));

  UPDATE public.users SET energy = 100 WHERE auth_id = v_auth;

  -- STEP 4: quest list shape
  v_quests := public.get_available_quests(5);
  v_ok := v_quests IS NOT NULL
      AND (
        jsonb_typeof(v_quests) = 'array'
        OR (v_quests ? 'quests' AND jsonb_typeof(v_quests->'quests') = 'array')
        OR v_quests ? 'success'
      );
  v_steps := v_steps || jsonb_build_array(jsonb_build_object(
    'step', 'quest_list_shape',
    'pass', v_ok
  ));

  -- STEP 5: quest claim error shape (invalid id — catch RAISE, no side effects)
  BEGIN
    v_claim := public.claim_quest_reward('qa_nonexistent_quest_id');
  EXCEPTION WHEN OTHERS THEN
    v_claim := jsonb_build_object('success', false, 'error', SQLERRM);
  END;
  v_ok := v_claim IS NOT NULL
      AND (
        COALESCE((v_claim->>'success')::boolean, true) = false
        OR v_claim ? 'error'
      );
  v_steps := v_steps || jsonb_build_array(jsonb_build_object(
    'step', 'quest_claim_shape',
    'pass', v_ok,
    'detail', v_claim
  ));

  -- STEP 6: reputation overview
  v_overview := public.get_reputation_overview();
  v_ok := COALESCE((v_overview->>'success')::boolean, false)
      AND v_overview ? 'global_reputation';
  v_steps := v_steps || jsonb_build_array(jsonb_build_object(
    'step', 'reputation_overview',
    'pass', v_ok,
    'detail', jsonb_build_object('global_reputation', v_overview->'global_reputation')
  ));

  -- cleanup
  DELETE FROM public.dungeon_runs WHERE player_id = v_auth;
  DELETE FROM public.reputation_activity_log WHERE user_id = v_auth;
  DELETE FROM public.player_faction_reputation WHERE user_id = v_auth;
  DELETE FROM auth.users WHERE id = v_auth;
  DELETE FROM public.users WHERE auth_id = v_auth;

  RETURN jsonb_build_object(
    'verdict', CASE WHEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_steps) t
      WHERE NOT COALESCE((t->>'pass')::boolean, false)
    ) THEN 'FAIL' ELSE 'PASS' END,
    'total', jsonb_array_length(v_steps),
    'passed', (
      SELECT COUNT(*)::integer FROM jsonb_array_elements(v_steps) t
      WHERE COALESCE((t->>'pass')::boolean, false)
    ),
    'steps', v_steps
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_player_journey_f2p() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_player_journey_f2p() TO service_role;
