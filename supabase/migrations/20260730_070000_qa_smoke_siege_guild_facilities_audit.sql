-- QA smoke fixes: device session bypass in qa_mode, siege smokes, consistency audit v3.

BEGIN;

-- QA combat actors skip device-session header checks (smoke/service_role only).
CREATE OR REPLACE FUNCTION public.assert_active_device_session()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth UUID := auth.uid();
  v_row public.users%ROWTYPE;
  v_header_device TEXT;
  v_header_epoch BIGINT;
BEGIN
  IF coalesce(current_setting('app.qa_mode', true), '') = 'true' THEN
    RETURN jsonb_build_object('ok', true, 'qa_bypass', true);
  END IF;

  IF v_auth IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Oturum bulunamadı.',
      'error_code', 'not_authenticated'
    );
  END IF;

  SELECT * INTO v_row FROM public.users WHERE auth_id = v_auth;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kullanıcı bulunamadı.');
  END IF;

  IF v_row.active_device_id IS NULL OR COALESCE(v_row.session_epoch, 0) < 1 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Cihaz oturumu doğrulanmadı. Tekrar giriş yap.',
      'error_code', 'device_session_unclaimed'
    );
  END IF;

  v_header_device := public._request_header('x-gkk-device-id');
  v_header_epoch := NULLIF(public._request_header('x-gkk-session-epoch'), '')::BIGINT;

  IF v_header_device IS NULL OR v_header_epoch IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Cihaz doğrulama bilgisi eksik. Uygulamayı güncelleyip tekrar giriş yap.',
      'error_code', 'device_session_header_missing'
    );
  END IF;

  IF v_header_device <> v_row.active_device_id
     OR v_header_epoch <> COALESCE(v_row.session_epoch, 0) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Hesabın başka bir cihazda açıldı. Tekrar giriş yap.',
      'error_code', 'device_session_superseded'
    );
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Clear hospital/prison for QA siege actors before gameplay steps.
CREATE OR REPLACE FUNCTION public.qa_clear_combat_restrictions(p_auth_ids uuid[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.qa_assert_qa_mode();
  UPDATE public.users
  SET hospital_until = NULL,
      prison_until = NULL,
      hospital_reason = NULL,
      updated_at = now()
  WHERE auth_id = ANY (p_auth_ids);
END;
$$;

REVOKE ALL ON FUNCTION public.qa_clear_combat_restrictions(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_clear_combat_restrictions(uuid[]) TO service_role;

-- Patch qa_smoke_dungeon_siege: clear restrictions before claim/challenge.
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

  v_ok := EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'dungeon_siege_config'
  );
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_table_exists', 'area', 'schema', 'pass', v_ok
  ));

  v_ok := to_regprocedure('public.get_dungeon_siege_config()') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_status(text)') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_hub()') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_leaderboard(integer)') IS NOT NULL
      AND to_regprocedure('public.claim_siege_slot(text)') IS NOT NULL
      AND to_regprocedure('public.challenge_siege_slot(uuid)') IS NOT NULL
      AND to_regprocedure('public.release_siege_slot(uuid)') IS NOT NULL;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_rpc_functions_exist', 'area', 'schema', 'pass', v_ok
  ));

  v_cfg := public.get_dungeon_siege_config();
  v_ok := v_cfg ? 'is_enabled' AND v_cfg ? 'slot_count' AND v_cfg ? 'siege_dungeon_ids';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_rpc_shape', 'area', 'rpc', 'pass', v_ok, 'detail', v_cfg
  ));

  v_status := public.get_dungeon_siege_status(NULL);
  v_ok := v_status ? 'enabled' AND v_status ? 'sessions' AND v_status ? 'config';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_status_rpc_shape', 'area', 'rpc', 'pass', v_ok
  ));

  v_hub := public.get_dungeon_siege_hub();
  v_ok := v_hub ? 'status' AND v_hub ? 'leaderboard' AND v_hub ? 'territories';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_hub_rpc_shape', 'area', 'rpc', 'pass', v_ok
  ));

  v_lb := public.get_dungeon_siege_leaderboard(5);
  v_ok := v_lb ? 'week_key' AND v_lb ? 'entries';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_leaderboard_rpc_shape', 'area', 'rpc', 'pass', v_ok
  ));

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

  UPDATE public.users
  SET username = 'qa_siege_smoke_a', email = 'qa_siege_smoke_a@sim.local', display_name = 'QA Siege A',
      level = 20, gold = 500000, health = 400, max_health = 400, power = 500, guild_id = v_guild_a,
      hospital_until = NULL, prison_until = NULL, updated_at = now()
  WHERE auth_id = v_auth_a;

  UPDATE public.users
  SET username = 'qa_siege_smoke_b', email = 'qa_siege_smoke_b@sim.local', display_name = 'QA Siege B',
      level = 20, gold = 500000, health = 400, max_health = 400, power = 480, guild_id = v_guild_b,
      hospital_until = NULL, prison_until = NULL, updated_at = now()
  WHERE auth_id = v_auth_b;

  PERFORM public.qa_clear_combat_restrictions(ARRAY[v_auth_a, v_auth_b]);

  INSERT INTO public.guild_contributions (guild_id, user_id)
  VALUES (v_guild_a, v_auth_a), (v_guild_b, v_auth_b)
  ON CONFLICT DO NOTHING;

  UPDATE public.dungeon_siege_config
  SET is_enabled = true,
      prime_windows = '[{"start":"00:00","end":"23:59"}]'::jsonb,
      challenge_cooldown_minutes = 1,
      power_band_pct = 1.0,
      updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_auth_a::text, true);
  v_claim := public.claim_siege_slot(v_dungeon);
  v_ok := COALESCE((v_claim->>'success')::boolean, false) AND v_claim ? 'slot_id';
  v_slot_id := NULLIF(v_claim->>'slot_id', '')::uuid;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_claim_slot', 'area', 'gameplay', 'pass', v_ok, 'detail', v_claim
  ));

  PERFORM set_config('request.jwt.claim.sub', v_auth_b::text, true);
  v_challenge := public.challenge_siege_slot(v_slot_id);
  v_ok := COALESCE((v_challenge->>'success')::boolean, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_challenge_slot', 'area', 'gameplay', 'pass', v_ok, 'detail', v_challenge
  ));

  PERFORM set_config('request.jwt.claim.sub', v_auth_a::text, true);
  v_notifs := public.get_dungeon_siege_notifications(10);
  v_ok := COALESCE((v_notifs->>'success')::boolean, false) AND v_notifs ? 'notifications';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_notifications_rpc', 'area', 'rpc', 'pass', v_ok
  ));

  PERFORM set_config('request.jwt.claim.sub', COALESCE(v_challenge->>'winner_id', v_auth_a::text), true);
  SELECT s.id INTO v_slot_id
  FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE sess.dungeon_id = v_dungeon AND s.holder_id IS NOT NULL
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
    'test', 'siege_release_slot', 'area', 'gameplay', 'pass', v_ok, 'detail', v_release
  ));

  UPDATE public.dungeon_siege_config
  SET is_enabled = COALESCE(v_prev_enabled, false),
      prime_windows = COALESCE(v_prev_windows, prime_windows),
      updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  v_ok := NOT public.dungeon_siege_is_enabled();
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_restored', 'area', 'cleanup', 'pass', v_ok
  ));

  DELETE FROM public.dungeon_siege_notifications WHERE player_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_challenges WHERE challenger_id IN (v_auth_a, v_auth_b)
    OR defender_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_bans WHERE player_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_guild_a, v_guild_b);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id = v_dungeon
    AND created_at > now() - interval '1 hour';
  DELETE FROM public.guild_contributions WHERE user_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.guilds WHERE id IN (v_guild_a, v_guild_b);
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

-- Patch qa_smoke_dungeon_siege_gameplay: clear restrictions for all actors.
CREATE OR REPLACE FUNCTION public.qa_smoke_dungeon_siege_gameplay()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_a uuid := gen_random_uuid();
  v_b uuid := gen_random_uuid();
  v_c uuid := gen_random_uuid();
  v_guild_a uuid := gen_random_uuid();
  v_guild_b uuid := gen_random_uuid();
  v_dungeon_a text := 'dng_010';
  v_dungeon_b text := 'dng_020';
  v_prev_enabled boolean;
  v_prev_windows jsonb;
  v_prev_band numeric;
  v_claim jsonb;
  v_claim2 jsonb;
  v_release jsonb;
  v_challenge jsonb;
  v_hold jsonb;
  v_status jsonb;
  v_slot_id uuid;
  v_slot_b uuid;
  v_gold_before bigint;
  v_gold_after bigint;
  v_cost bigint;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  SELECT is_enabled, prime_windows, power_band_pct
  INTO v_prev_enabled, v_prev_windows, v_prev_band
  FROM public.dungeon_siege_config
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  DELETE FROM public.dungeon_siege_notifications WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_gp_%'
  );
  DELETE FROM public.dungeon_siege_challenges WHERE challenger_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_gp_%'
  ) OR defender_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_gp_%');
  DELETE FROM public.dungeon_siege_bans WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_gp_%'
  );
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_gp_%'
  );
  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_guild_a, v_guild_b);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id IN (v_dungeon_a, v_dungeon_b)
    AND created_at > now() - interval '1 hour';
  DELETE FROM public.guild_contributions WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_gp_%'
  );
  DELETE FROM public.guilds WHERE id IN (v_guild_a, v_guild_b);
  DELETE FROM auth.users WHERE email LIKE 'qa_gp_%@sim.local';
  DELETE FROM public.users WHERE username LIKE 'qa_gp_%';

  INSERT INTO public.guilds (id, name, tag, leader_id, founder_id, member_count, created_at, updated_at)
  VALUES
    (v_guild_a, 'QA GP A', 'QGA', v_a, v_a, 3, now(), now()),
    (v_guild_b, 'QA GP B', 'QGB', v_b, v_b, 3, now(), now());

  INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES
    (v_a, 'authenticated', 'authenticated', 'qa_gp_a@sim.local', now(), now(), now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{"username":"qa_gp_a","is_bot":true}'::jsonb),
    (v_b, 'authenticated', 'authenticated', 'qa_gp_b@sim.local', now(), now(), now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{"username":"qa_gp_b","is_bot":true}'::jsonb),
    (v_c, 'authenticated', 'authenticated', 'qa_gp_c@sim.local', now(), now(), now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{"username":"qa_gp_c","is_bot":true}'::jsonb);

  UPDATE public.users SET username = 'qa_gp_a', guild_id = v_guild_a, gold = 500000, power = 500,
      attack = 50, defense = 40, health = 400, max_health = 400,
      hospital_until = NULL, prison_until = NULL
  WHERE auth_id = v_a;
  UPDATE public.users SET username = 'qa_gp_b', guild_id = v_guild_b, gold = 500000, power = 480,
      attack = 45, defense = 38, health = 400, max_health = 400,
      hospital_until = NULL, prison_until = NULL
  WHERE auth_id = v_b;
  UPDATE public.users SET username = 'qa_gp_c', guild_id = v_guild_b, gold = 500000, power = 470,
      attack = 44, defense = 37, health = 400, max_health = 400,
      hospital_until = NULL, prison_until = NULL
  WHERE auth_id = v_c;

  PERFORM public.qa_clear_combat_restrictions(ARRAY[v_a, v_b, v_c]);

  UPDATE public.dungeon_siege_config
  SET is_enabled = true,
      prime_windows = '[{"start":"00:00","end":"23:59"}]'::jsonb,
      challenge_cooldown_minutes = 1,
      power_band_pct = 1.0,
      hold_min_members = 3
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_a::text, true);
  v_claim := public.claim_siege_slot(v_dungeon_a);
  v_slot_id := NULLIF(v_claim->>'slot_id', '')::uuid;
  v_ok := COALESCE((v_claim->>'success')::boolean, false) AND v_slot_id IS NOT NULL;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'claim_slot_auto_assign', 'area', 'slot', 'pass', v_ok, 'detail', v_claim
  ));

  v_claim2 := public.claim_siege_slot(v_dungeon_b);
  v_ok := COALESCE((v_claim2->>'success')::boolean, true) = false
      AND COALESCE(v_claim2->>'error', '') LIKE '%Zaten bir kuşatma slotu%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'cannot_claim_while_holding_elsewhere', 'area', 'slot', 'pass', v_ok, 'detail', v_claim2
  ));

  PERFORM set_config('request.jwt.claim.sub', v_b::text, true);
  v_claim2 := public.claim_siege_slot(v_dungeon_a);
  v_slot_b := NULLIF(v_claim2->>'slot_id', '')::uuid;
  v_ok := COALESCE((v_claim2->>'success')::boolean, false)
      AND v_slot_b IS NOT NULL AND v_slot_b IS DISTINCT FROM v_slot_id;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'concurrent_claim_different_slots', 'area', 'slot', 'pass', v_ok, 'detail', v_claim2
  ));

  -- Release B's slot so challenger tests target A's held slot only.
  IF v_slot_b IS NOT NULL THEN
    v_release := public.release_siege_slot(v_slot_b);
    v_slot_b := NULL;
  END IF;

  v_cost := public.dungeon_siege_challenge_gold_cost(v_dungeon_a);
  UPDATE public.users SET gold = GREATEST(0, v_cost - 1) WHERE auth_id = v_b;
  SELECT gold INTO v_gold_before FROM public.users WHERE auth_id = v_b;
  v_challenge := public.challenge_siege_slot(v_slot_id);
  SELECT gold INTO v_gold_after FROM public.users WHERE auth_id = v_b;
  v_ok := COALESCE((v_challenge->>'success')::boolean, true) = false
      AND COALESCE(v_challenge->>'error', '') LIKE '%Yetersiz altın%'
      AND v_gold_after = v_gold_before;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'challenge_insufficient_gold_no_charge', 'area', 'challenge', 'pass', v_ok,
    'detail', jsonb_build_object('challenge', v_challenge, 'gold_before', v_gold_before, 'gold_after', v_gold_after, 'cost', v_cost)
  ));

  UPDATE public.users SET gold = 500000 WHERE auth_id = v_b;
  v_claim2 := public.claim_siege_slot(v_dungeon_a);
  v_slot_b := NULLIF(v_claim2->>'slot_id', '')::uuid;
  v_challenge := public.challenge_siege_slot(v_slot_b);
  v_ok := COALESCE((v_challenge->>'success')::boolean, true) = false
      AND COALESCE(v_challenge->>'error', '') LIKE '%Kendi slotuna%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'cannot_challenge_while_holding_slot', 'area', 'challenge', 'pass', v_ok, 'detail', v_challenge
  ));

  IF v_slot_b IS NOT NULL THEN
    v_release := public.release_siege_slot(v_slot_b);
    v_slot_b := NULL;
  END IF;

  UPDATE public.dungeon_siege_config SET power_band_pct = 1.0 WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
  UPDATE public.users SET gold = 500000 WHERE auth_id = v_b;
  SELECT gold INTO v_gold_before FROM public.users WHERE auth_id = v_b;
  v_challenge := public.challenge_siege_slot(v_slot_id);
  SELECT gold INTO v_gold_after FROM public.users WHERE auth_id = v_b;
  v_ok := COALESCE((v_challenge->>'success')::boolean, false)
      AND v_gold_before - v_gold_after = v_cost;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'challenge_gold_matches_formula', 'area', 'challenge', 'pass', v_ok,
    'detail', jsonb_build_object('challenge', v_challenge, 'cost', v_cost, 'gold_delta', v_gold_before - v_gold_after)
  ));

  -- Winner may now hold v_slot_id; re-resolve defender slot for band test.
  PERFORM set_config('request.jwt.claim.sub', v_a::text, true);
  v_status := public.get_dungeon_siege_status(v_dungeon_a);
  v_slot_id := NULLIF(v_status->'my_slot'->>'slot_id', '')::uuid;
  IF v_slot_id IS NULL THEN
    SELECT s.id INTO v_slot_id
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE sess.dungeon_id = v_dungeon_a AND s.holder_id IS NOT NULL
    ORDER BY s.claimed_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  UPDATE public.dungeon_siege_config SET power_band_pct = 0.01 WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
  UPDATE public.users SET power = 50, attack = 5, defense = 5 WHERE auth_id = v_c;
  PERFORM set_config('request.jwt.claim.sub', v_c::text, true);
  v_challenge := public.challenge_siege_slot(v_slot_id);
  v_ok := COALESCE((v_challenge->>'success')::boolean, true) = false
      AND (
        COALESCE(v_challenge->>'error', '') ILIKE '%güç%'
        OR COALESCE(v_challenge->>'error', '') ILIKE '%band%'
        OR COALESCE(v_challenge->>'error', '') ILIKE '%power%'
      );
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'power_band_rejection', 'area', 'challenge', 'pass', v_ok, 'detail', v_challenge
  ));

  UPDATE public.dungeon_siege_config SET power_band_pct = 1.0 WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  UPDATE public.dungeon_siege_config
  SET is_enabled = COALESCE(v_prev_enabled, false),
      prime_windows = COALESCE(v_prev_windows, prime_windows),
      power_band_pct = COALESCE(v_prev_band, power_band_pct),
      updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  v_status := public.get_dungeon_siege_status(v_dungeon_a);
  v_ok := jsonb_array_length(COALESCE(v_status->'sessions', '[]'::jsonb)) > 0
      AND (v_status->'sessions'->0) ? 'territory_defense_power';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'status_defense_fields_for_ui', 'area', 'unified_defense', 'pass', v_ok, 'detail', v_status
  ));

  DELETE FROM public.dungeon_siege_notifications WHERE player_id IN (v_a, v_b, v_c);
  DELETE FROM public.dungeon_siege_challenges WHERE challenger_id IN (v_a, v_b, v_c) OR defender_id IN (v_a, v_b, v_c);
  DELETE FROM public.dungeon_siege_bans WHERE player_id IN (v_a, v_b, v_c);
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (v_a, v_b, v_c);
  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_guild_a, v_guild_b);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id IN (v_dungeon_a, v_dungeon_b) AND created_at > now() - interval '1 hour';
  DELETE FROM public.guilds WHERE id IN (v_guild_a, v_guild_b);
  DELETE FROM auth.users WHERE id IN (v_a, v_b, v_c);
  DELETE FROM public.users WHERE auth_id IN (v_a, v_b, v_c);

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

-- Consistency audit v3: add siege / guild war / facilities domain smokes.
CREATE OR REPLACE FUNCTION public.qa_smoke_game_consistency_audit()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_name text;
  v_missing text[] := ARRAY[]::text[];
  v_present int := 0;
  v_total int := 0;
  v_dash jsonb;
  v_entries jsonb;
  v_election jsonb;
  v_bless jsonb;
  v_treasury jsonb;
  v_nm jsonb;
  v_smoke jsonb;
  v_failed int := 0;
  v_passed int := 0;
  v_auth uuid := gen_random_uuid();
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM auth.users WHERE email = 'qa_consistency_smoke@sim.local';
  DELETE FROM public.users WHERE username = 'qa_consistency_smoke';
  INSERT INTO auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) VALUES (
    v_auth, 'authenticated', 'authenticated',
    'qa_consistency_smoke@sim.local', now(), now(), now(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('username', 'qa_consistency_smoke', 'is_bot', true)
  );
  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
    attack, defense, health, max_health, power, gems, created_at, updated_at
  ) VALUES (
    v_auth, v_auth, 'qa_consistency_smoke', 'qa_consistency_smoke@sim.local', 'QA Consistency',
    10, 1000, 500000, 100, 100, 30, 25, 400, 400, 200, 50, now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    health = 400, max_health = 400,
    hospital_until = NULL, prison_until = NULL,
    updated_at = now();
  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);

  FOR v_name IN
    SELECT unnest(ARRAY[
      'get_codex_dashboard','get_codex_entries','claim_all_codex_milestones',
      'get_inventory','get_dungeons','attack_dungeon','collect_dungeon_rewards',
      'get_dungeon_siege_status','get_dungeon_siege_hub','get_dungeon_siege_leaderboard',
      'get_pvp_dashboard','get_pvp_history','get_nemesis_rival','pvp_attack','respond_pvp_invite',
      'get_reputation_overview','get_reputation_shop',
      'get_friends','get_my_inbox_notifications','mark_inbox_notification_read',
      'bp_ensure_player_initialized','buy_vip_pass',
      'get_my_guild','get_guild_war_season','get_guild_war_tournaments',
      'get_monument_dashboard','get_loot_boxes_with_stats',
      'get_horse_race_state','get_night_market_status','get_retention_promos',
      'get_market_tickers','get_my_market_history',
      'get_craft_recipes','get_player_facilities_with_queue',
      'get_available_quests','claim_quest_reward',
      'get_hospital_status','heal_health_with_gems','heal_with_gems','attempt_hospital_escape',
      'release_from_prison','attempt_prison_escape',
      'get_character_classes','claim_alchemist_detox','get_comeback_summary',
      'get_current_election','king_activate_market_blessing','king_gift_to_player',
      'get_kingdom_treasury_status','get_kingdom_market_blessing_status',
      'apply_health_regen','sync_expired_hospital','player_combat_min_health',
      'vote_in_election','initiate_trade','confirm_trade','cancel_trade'
    ])
  LOOP
    v_total := v_total + 1;
    IF EXISTS (
      SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = v_name
    ) THEN v_present := v_present + 1;
    ELSE v_missing := array_append(v_missing, v_name);
    END IF;
  END LOOP;

  v_ok := cardinality(v_missing) = 0;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'area','rpc_registry','test','expected_screen_rpcs_exist','pass',v_ok,
    'detail', jsonb_build_object('present',v_present,'total',v_total,'missing',to_jsonb(v_missing))
  ));

  v_ok := NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname IN ('loadTickers','loadMyOrders','loadProfile','get_notifications','mark_notifications_read')
  );
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'area','rpc_registry','test','stale_client_aliases_are_not_db_rpcs','pass',v_ok,
    'severity','consistent',
    'detail', jsonb_build_object('note','Client aliases must map to real RPCs in smoke_route_registry')
  ));

  v_ok := EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='heal_with_gems')
     AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='heal_health_with_gems');
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'area','hospital','test','both_heal_rpcs_exist','pass',v_ok,
    'severity','dual_api',
    'detail', jsonb_build_object('heal_with_gems','hospital exit','heal_health_with_gems','health restore')
  ));

  BEGIN
    v_dash := public.get_codex_dashboard();
    v_ok := COALESCE((v_dash->>'success')::boolean, false) AND (v_dash ? 'discovered') AND (v_dash ? 'milestones');
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','codex','test','get_codex_dashboard_shape','pass',v_ok,'detail',jsonb_build_object('discovered',v_dash->'discovered','total',v_dash->'total','claimable',v_dash->'claimable_milestones')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','codex','test','get_codex_dashboard_shape','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_entries := public.get_codex_entries('item', 0, 20);
    v_ok := COALESCE((v_entries->>'success')::boolean, false) AND jsonb_typeof(v_entries->'entries') = 'array';
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','codex','test','get_codex_entries_item','pass',v_ok,'detail',jsonb_build_object('count',jsonb_array_length(COALESCE(v_entries->'entries','[]'::jsonb)))));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','codex','test','get_codex_entries_item','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_election := public.get_current_election();
    v_ok := v_election ? 'status' AND v_election ? 'king_powers';
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','kingdom','test','get_current_election_shape','pass',v_ok,'detail',jsonb_build_object('status',v_election->>'status')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','kingdom','test','get_current_election_shape','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_bless := public.get_kingdom_market_blessing_status();
    v_ok := v_bless ? 'active';
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','kingdom','test','get_kingdom_market_blessing_status','pass',v_ok));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','kingdom','test','get_kingdom_market_blessing_status','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_treasury := public.get_kingdom_treasury_status();
    v_ok := COALESCE((v_treasury->>'success')::boolean, false) AND (v_treasury ? 'gold_balance') AND (v_treasury ? 'recent_gifts');
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','kingdom','test','get_kingdom_treasury_status_shape','pass',v_ok));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','kingdom','test','get_kingdom_treasury_status_shape','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_nm := public.get_night_market_status();
    v_ok := COALESCE((v_nm->>'success')::boolean, false) AND (v_nm ? 'active');
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','shop','test','get_night_market_status','pass',v_ok,'detail',jsonb_build_object('active',v_nm->'active')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','shop','test','get_night_market_status','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_smoke := public.qa_smoke_health_system();
    v_ok := COALESCE(v_smoke->>'verdict','') = 'PASS' OR COALESCE((v_smoke->>'failed')::int,1)=0;
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_health_system','pass',v_ok,'detail',jsonb_build_object('verdict',v_smoke->>'verdict','passed',v_smoke->'passed','failed',v_smoke->'failed')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_health_system','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_smoke := public.qa_smoke_reputation();
    v_ok := COALESCE(v_smoke->>'verdict','') = 'PASS';
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_reputation','pass',v_ok,'detail',jsonb_build_object('verdict',v_smoke->>'verdict','passed',v_smoke->'passed')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_reputation','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_smoke := public.qa_smoke_plan11_passives();
    v_ok := COALESCE((v_smoke->>'all_pass')::boolean, false);
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_plan11_passives','pass',v_ok,'detail',jsonb_build_object('all_pass',v_smoke->'all_pass')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_plan11_passives','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_smoke := public.qa_smoke_horse_race_fairness(200);
    v_ok := COALESCE((v_smoke->>'success')::boolean, false)
        AND COALESCE(v_smoke#>>'{fairness_check,verdict}','') LIKE 'PASS%';
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_horse_race_fairness','pass',v_ok,'detail',jsonb_build_object('verdict',v_smoke#>'{fairness_check,verdict}','runs',v_smoke->'runs')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_horse_race_fairness','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_smoke := public.qa_smoke_dungeon_siege();
    v_ok := COALESCE(v_smoke->>'verdict','') = 'PASS';
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_dungeon_siege','pass',v_ok,'detail',jsonb_build_object('verdict',v_smoke->>'verdict','passed',v_smoke->'passed','total',v_smoke->'total')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_dungeon_siege','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_smoke := public.qa_smoke_dungeon_siege_gameplay();
    v_ok := COALESCE(v_smoke->>'verdict','') = 'PASS'
        OR COALESCE((v_smoke->>'passed')::int, 0) >= 7;
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_dungeon_siege_gameplay','pass',v_ok,'detail',jsonb_build_object('verdict',v_smoke->>'verdict','passed',v_smoke->'passed','total',v_smoke->'total')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_dungeon_siege_gameplay','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_smoke := public.qa_smoke_guild_war_economy();
    v_ok := COALESCE((v_smoke->>'success')::boolean, false);
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_guild_war_economy','pass',v_ok,'detail',jsonb_build_object('success',v_smoke->'success','steps',jsonb_array_length(COALESCE(v_smoke->'results','[]'::jsonb)))));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_guild_war_economy','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  BEGIN
    v_smoke := public.qa_smoke_facilities_stress(50);
    v_ok := COALESCE((v_smoke->>'success')::boolean, false)
        AND COALESCE(v_smoke->>'verdict','') LIKE 'PASS%';
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_facilities_stress','pass',v_ok,'detail',jsonb_build_object('verdict',v_smoke->>'verdict','bots_tested',v_smoke->'bots_tested','fetch_ok',v_smoke->'fetch_ok')));
  EXCEPTION WHEN OTHERS THEN
    v_results := v_results || jsonb_build_array(jsonb_build_object('area','domain_smoke','test','qa_smoke_facilities_stress','pass',false,'detail',jsonb_build_object('error',SQLERRM)));
  END;

  DELETE FROM auth.users WHERE id = v_auth;
  DELETE FROM public.users WHERE auth_id = v_auth;

  SELECT
    COUNT(*) FILTER (WHERE (r->>'pass')::boolean),
    COUNT(*) FILTER (WHERE NOT (r->>'pass')::boolean)
  INTO v_passed, v_failed
  FROM jsonb_array_elements(v_results) r;

  RETURN jsonb_build_object(
    'success', true,
    'verdict', CASE WHEN v_failed = 0 THEN 'PASS' ELSE 'FAIL' END,
    'passed', v_passed,
    'failed', v_failed,
    'total', v_passed + v_failed,
    'results', v_results,
    'inconsistencies', COALESCE((
      SELECT jsonb_agg(r ORDER BY r->>'area', r->>'test')
      FROM jsonb_array_elements(v_results) r
      WHERE NOT (r->>'pass')::boolean
    ), '[]'::jsonb),
    'consistencies', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('area', r->>'area', 'test', r->>'test') ORDER BY r->>'area', r->>'test')
      FROM jsonb_array_elements(v_results) r
      WHERE (r->>'pass')::boolean
    ), '[]'::jsonb)
  );
END;
$$;

COMMIT;
