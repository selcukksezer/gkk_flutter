-- QA smoke: dungeon siege (Faz A/B) — safe pre-prod gate
-- Run: SELECT public.qa_smoke_dungeon_siege();

CREATE OR REPLACE FUNCTION public.qa_smoke_dungeon_siege()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth_a uuid := gen_random_uuid();
  v_auth_b uuid := gen_random_uuid();
  v_guild_a uuid := gen_random_uuid();
  v_guild_b uuid := gen_random_uuid();
  v_dungeon text := 'dng_010';
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_cfg jsonb;
  v_status jsonb;
  v_hub jsonb;
  v_lb jsonb;
  v_claim jsonb;
  v_release jsonb;
  v_challenge jsonb;
  v_notifs jsonb;
  v_slot_id uuid;
  v_prev_enabled boolean;
  v_prev_windows jsonb;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  -- cleanup prior run
  DELETE FROM public.dungeon_siege_notifications WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.dungeon_siege_challenges WHERE challenger_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  ) OR defender_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.dungeon_siege_bans WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_guild_a, v_guild_b);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id = v_dungeon
    AND created_at > now() - interval '1 hour';
  DELETE FROM public.guild_contributions WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.guilds WHERE leader_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM auth.users WHERE email LIKE 'qa_siege_smoke_%@sim.local';
  DELETE FROM public.users WHERE username LIKE 'qa_siege_smoke_%';

  SELECT is_enabled, prime_windows
  INTO v_prev_enabled, v_prev_windows
  FROM public.dungeon_siege_config
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  -- SIEGE-01: config table + default disabled
  v_ok := EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'dungeon_siege_config'
  ) AND COALESCE(v_prev_enabled, false) = false;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_default_disabled',
    'area', 'schema',
    'pass', v_ok
  ));

  -- SIEGE-02: core RPCs exist
  v_ok := to_regprocedure('public.get_dungeon_siege_config()') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_status(text)') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_hub()') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_leaderboard(integer)') IS NOT NULL
      AND to_regprocedure('public.claim_siege_slot(text)') IS NOT NULL
      AND to_regprocedure('public.challenge_siege_slot(uuid)') IS NOT NULL
      AND to_regprocedure('public.release_siege_slot(uuid)') IS NOT NULL;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_rpc_functions_exist',
    'area', 'schema',
    'pass', v_ok
  ));

  v_cfg := public.get_dungeon_siege_config();
  v_ok := v_cfg ? 'is_enabled'
      AND v_cfg ? 'slot_count'
      AND v_cfg ? 'siege_dungeon_ids'
      AND jsonb_typeof(v_cfg->'siege_dungeon_ids') = 'array';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_rpc_shape',
    'area', 'rpc',
    'pass', v_ok,
    'detail', v_cfg
  ));

  v_status := public.get_dungeon_siege_status(NULL);
  v_ok := v_status ? 'enabled'
      AND v_status ? 'sessions'
      AND v_status ? 'config';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_status_rpc_shape',
    'area', 'rpc',
    'pass', v_ok
  ));

  v_hub := public.get_dungeon_siege_hub();
  v_ok := v_hub ? 'status'
      AND v_hub ? 'leaderboard'
      AND v_hub ? 'territories';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_hub_rpc_shape',
    'area', 'rpc',
    'pass', v_ok
  ));

  v_lb := public.get_dungeon_siege_leaderboard(5);
  v_ok := v_lb ? 'week_key' AND v_lb ? 'entries';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_leaderboard_rpc_shape',
    'area', 'rpc',
    'pass', v_ok
  ));

  -- QA users + guilds (different guilds for challenge)
  INSERT INTO public.guilds (id, name, tag, leader_id, founder_id, member_count, created_at, updated_at)
  VALUES
    (v_guild_a, 'QA Siege A', 'QSA', v_auth_a, v_auth_a, 1, now(), now()),
    (v_guild_b, 'QA Siege B', 'QSB', v_auth_b, v_auth_b, 1, now(), now());

  INSERT INTO auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) VALUES
    (v_auth_a, 'authenticated', 'authenticated', 'qa_siege_smoke_a@sim.local', now(), now(), now(),
     jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
     jsonb_build_object('username', 'qa_siege_smoke_a', 'is_bot', true)),
    (v_auth_b, 'authenticated', 'authenticated', 'qa_siege_smoke_b@sim.local', now(), now(), now(),
     jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
     jsonb_build_object('username', 'qa_siege_smoke_b', 'is_bot', true));

  -- handle_new_user trigger auto-creates public.users rows
  UPDATE public.users
  SET username = 'qa_siege_smoke_a',
      email = 'qa_siege_smoke_a@sim.local',
      display_name = 'QA Siege A',
      level = 20,
      xp = 5000,
      gold = 500000,
      energy = 100,
      max_energy = 100,
      attack = 50,
      defense = 40,
      health = 200,
      max_health = 200,
      power = 500,
      gems = 50,
      guild_id = v_guild_a,
      updated_at = now()
  WHERE auth_id = v_auth_a;

  UPDATE public.users
  SET username = 'qa_siege_smoke_b',
      email = 'qa_siege_smoke_b@sim.local',
      display_name = 'QA Siege B',
      level = 20,
      xp = 5000,
      gold = 500000,
      energy = 100,
      max_energy = 100,
      attack = 45,
      defense = 38,
      health = 200,
      max_health = 200,
      power = 480,
      gems = 50,
      guild_id = v_guild_b,
      updated_at = now()
  WHERE auth_id = v_auth_b;

  INSERT INTO public.guild_contributions (guild_id, user_id)
  VALUES (v_guild_a, v_auth_a), (v_guild_b, v_auth_b)
  ON CONFLICT DO NOTHING;

  UPDATE public.users SET guild_id = v_guild_a, guild_role = 'leader' WHERE auth_id = v_auth_a;
  UPDATE public.users SET guild_id = v_guild_b, guild_role = 'leader' WHERE auth_id = v_auth_b;

  -- Enable siege for QA window only (24h prime)
  UPDATE public.dungeon_siege_config
  SET is_enabled = true,
      prime_windows = '[{"start":"00:00","end":"23:59"}]'::jsonb,
      challenge_cooldown_minutes = 1,
      power_band_pct = 1.0,
      updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_auth_a::text, true);
  v_claim := public.claim_siege_slot(v_dungeon);
  v_ok := COALESCE((v_claim->>'success')::boolean, false)
      AND v_claim ? 'slot_id';
  v_slot_id := NULLIF(v_claim->>'slot_id', '')::uuid;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_claim_slot',
    'area', 'gameplay',
    'pass', v_ok,
    'detail', v_claim
  ));

  PERFORM set_config('request.jwt.claim.sub', v_auth_b::text, true);
  v_challenge := public.challenge_siege_slot(v_slot_id);
  v_ok := COALESCE((v_challenge->>'success')::boolean, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_challenge_slot',
    'area', 'gameplay',
    'pass', v_ok,
    'detail', v_challenge
  ));

  PERFORM set_config('request.jwt.claim.sub', v_auth_a::text, true);
  v_notifs := public.get_dungeon_siege_notifications(10);
  v_ok := COALESCE((v_notifs->>'success')::boolean, false)
      AND v_notifs ? 'notifications';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_notifications_rpc',
    'area', 'rpc',
    'pass', v_ok
  ));

  -- Winner releases slot if still held
  PERFORM set_config('request.jwt.claim.sub', COALESCE(v_challenge->>'winner_id', v_auth_a::text), true);
  SELECT s.id INTO v_slot_id
  FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE sess.dungeon_id = v_dungeon
    AND s.holder_id IS NOT NULL
  ORDER BY s.claimed_at DESC NULLS LAST
  LIMIT 1;

  IF v_slot_id IS NOT NULL THEN
    v_release := public.release_siege_slot(v_slot_id);
    v_ok := COALESCE((v_release->>'success')::boolean, false);
  ELSE
    v_ok := true;
    v_release := jsonb_build_object('skipped', true);
  END IF;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_release_slot',
    'area', 'gameplay',
    'pass', v_ok,
    'detail', v_release
  ));

  -- Restore config (keep disabled for prod safety)
  UPDATE public.dungeon_siege_config
  SET is_enabled = COALESCE(v_prev_enabled, false),
      prime_windows = COALESCE(v_prev_windows, prime_windows),
      updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  v_ok := NOT public.dungeon_siege_is_enabled();
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_restored_disabled',
    'area', 'cleanup',
    'pass', v_ok
  ));

  -- cleanup QA rows
  DELETE FROM public.dungeon_siege_notifications WHERE player_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_challenges WHERE challenger_id IN (v_auth_a, v_auth_b)
    OR defender_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_bans WHERE player_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_guild_a, v_guild_b);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id = v_dungeon
    AND created_at > now() - interval '1 hour';
  DELETE FROM public.guild_contributions WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.guilds WHERE leader_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM auth.users WHERE id IN (v_auth_a, v_auth_b);
  DELETE FROM public.users WHERE auth_id IN (v_auth_a, v_auth_b);

  RETURN jsonb_build_object(
    'verdict', CASE WHEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) t
      WHERE NOT COALESCE((t->>'pass')::boolean, false)
    ) THEN 'FAIL' ELSE 'PASS' END,
    'total', jsonb_array_length(v_results),
    'passed', (
      SELECT COUNT(*)::integer FROM jsonb_array_elements(v_results) t
      WHERE COALESCE((t->>'pass')::boolean, false)
    ),
    'tests', v_results
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_smoke_dungeon_siege() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_dungeon_siege() TO service_role;
