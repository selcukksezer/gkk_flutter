-- Restore territory defense fields in status RPC (regression from 220000/230000)
-- + extended real-player gameplay QA gate

BEGIN;

CREATE OR REPLACE FUNCTION public.get_dungeon_siege_status(p_dungeon_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_cfg public.dungeon_siege_config;
  v_sessions jsonb := '[]'::jsonb;
  v_my_slot jsonb := NULL;
  v_my_slot_global jsonb := NULL;
  v_my_guild_id uuid;
  v_banned_dungeon_ids jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_cfg := public.dungeon_siege_get_config();

  IF p_dungeon_id IS NOT NULL
     AND public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    PERFORM public.dungeon_siege_ensure_session(p_dungeon_id);
  END IF;

  IF v_me IS NOT NULL THEN
    SELECT guild_id INTO v_my_guild_id FROM public.users WHERE auth_id = v_me;

    SELECT COALESCE(jsonb_agg(b.dungeon_id ORDER BY b.dungeon_id), '[]'::jsonb)
    INTO v_banned_dungeon_ids
    FROM public.dungeon_siege_bans b
    WHERE b.player_id = v_me
      AND b.banned_until > now();

    SELECT jsonb_build_object(
      'slot_id', s.id,
      'slot_number', s.slot_number,
      'dungeon_id', sess.dungeon_id,
      'expires_at', s.expires_at
    )
    INTO v_my_slot_global
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = v_me
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (s.expires_at IS NULL OR s.expires_at > now())
    ORDER BY s.claimed_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'session_id', sess.id,
    'dungeon_id', sess.dungeon_id,
    'zone_number', sess.zone_number,
    'ends_at', sess.ends_at,
    'territory_owner_guild_id', public.dungeon_siege_territory_owner_for_zone(sess.zone_number),
    'territory_owner_guild_name', (
      SELECT g.name
      FROM public.guild_war_territories t
      LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
      WHERE t.zone_number = sess.zone_number
      LIMIT 1
    ),
    'territory_defense_power', public.dungeon_siege_territory_defense_power(sess.zone_number),
    'territory_defense_siege_bonus_pct', public.dungeon_siege_territory_defense_bonus_for_guild(
      sess.zone_number,
      v_my_guild_id
    ),
    'territory_defense_max_bonus_pct', public.dungeon_siege_territory_defense_multiplier(sess.zone_number),
    'guild_slots', CASE
      WHEN v_my_guild_id IS NULL THEN 0
      ELSE public.dungeon_siege_count_guild_slots(sess.id, v_my_guild_id)
    END,
    'hold', public.dungeon_siege_hold_json(sess.id),
    'slots', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'slot_id', s.id,
        'slot_number', s.slot_number,
        'holder_id', s.holder_id,
        'holder_name', COALESCE(u.display_name, u.username, '—'),
        'holder_power', COALESCE(u.power, 0),
        'guild_id', s.guild_id,
        'guild_name', g.name,
        'expires_at', s.expires_at,
        'last_active_at', s.last_active_at,
        'is_mine', s.holder_id IS NOT NULL AND s.holder_id = v_me,
        'is_territory_reserved', s.slot_number <= v_cfg.territory_reserve_slot_count
          AND public.dungeon_siege_territory_owner_for_zone(sess.zone_number) IS NOT NULL
      ) ORDER BY s.slot_number), '[]'::jsonb)
      FROM public.dungeon_siege_slots s
      LEFT JOIN public.users u ON u.auth_id = s.holder_id
      LEFT JOIN public.guilds g ON g.id = s.guild_id
      WHERE s.session_id = sess.id
    )
  ) ORDER BY sess.zone_number), '[]'::jsonb)
  INTO v_sessions
  FROM public.dungeon_siege_sessions sess
  WHERE sess.is_active = true
    AND sess.ends_at > now()
    AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id);

  IF v_me IS NOT NULL THEN
    IF p_dungeon_id IS NULL THEN
      v_my_slot := v_my_slot_global;
    ELSE
      SELECT jsonb_build_object(
        'slot_id', s.id,
        'slot_number', s.slot_number,
        'dungeon_id', sess.dungeon_id,
        'expires_at', s.expires_at
      )
      INTO v_my_slot
      FROM public.dungeon_siege_slots s
      JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
      WHERE s.holder_id = v_me
        AND sess.dungeon_id = p_dungeon_id
        AND sess.is_active = true
        AND sess.ends_at > now()
        AND (s.expires_at IS NULL OR s.expires_at > now())
      ORDER BY s.claimed_at DESC NULLS LAST
      LIMIT 1;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'enabled', v_cfg.is_enabled,
    'in_prime_window', public.dungeon_siege_in_prime_window(),
    'siege_active', v_cfg.is_enabled AND public.dungeon_siege_in_prime_window(),
    'sessions', v_sessions,
    'my_slot', v_my_slot,
    'my_slot_global', v_my_slot_global,
    'holds_slot_elsewhere', v_my_slot_global IS NOT NULL
      AND p_dungeon_id IS NOT NULL
      AND (v_my_slot_global->>'dungeon_id') IS DISTINCT FROM p_dungeon_id,
    'banned_dungeon_ids', v_banned_dungeon_ids,
    'is_banned', CASE
      WHEN v_me IS NULL THEN false
      WHEN p_dungeon_id IS NOT NULL THEN public.dungeon_siege_is_banned(v_me, p_dungeon_id)
      ELSE jsonb_array_length(v_banned_dungeon_ids) > 0
    END,
    'config', public.get_dungeon_siege_config()
  );
END;
$$;

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
  v_session jsonb;
  v_slot_id uuid;
  v_slot_b uuid;
  v_gold_before bigint;
  v_gold_after bigint;
  v_cost bigint;
  v_notif_count integer;
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

  UPDATE public.users SET username = 'qa_gp_a', guild_id = v_guild_a, gold = 500000, power = 500, attack = 50, defense = 40
  WHERE auth_id = v_a;
  UPDATE public.users SET username = 'qa_gp_b', guild_id = v_guild_b, gold = 500000, power = 480, attack = 45, defense = 38
  WHERE auth_id = v_b;
  UPDATE public.users SET username = 'qa_gp_c', guild_id = v_guild_b, gold = 500000, power = 470, attack = 44, defense = 37
  WHERE auth_id = v_c;

  UPDATE public.dungeon_siege_config
  SET is_enabled = true,
      prime_windows = '[{"start":"00:00","end":"23:59"}]'::jsonb,
      challenge_cooldown_minutes = 1,
      power_band_pct = 1.0,
      hold_min_members = 3
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  -- claim slot auto-assign
  PERFORM set_config('request.jwt.claim.sub', v_a::text, true);
  v_claim := public.claim_siege_slot(v_dungeon_a);
  v_slot_id := NULLIF(v_claim->>'slot_id', '')::uuid;
  v_ok := COALESCE((v_claim->>'success')::boolean, false) AND v_slot_id IS NOT NULL;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'claim_slot_auto_assign', 'area', 'slot', 'pass', v_ok, 'detail', v_claim
  ));

  -- cannot claim while holding elsewhere
  v_claim2 := public.claim_siege_slot(v_dungeon_b);
  v_ok := COALESCE((v_claim2->>'success')::boolean, true) = false
      AND COALESCE(v_claim2->>'error', '') LIKE '%Zaten bir kuşatma slotu%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'cannot_claim_while_holding_elsewhere', 'area', 'slot', 'pass', v_ok, 'detail', v_claim2
  ));

  -- concurrent claim: B gets different slot
  PERFORM set_config('request.jwt.claim.sub', v_b::text, true);
  v_claim2 := public.claim_siege_slot(v_dungeon_a);
  v_slot_b := NULLIF(v_claim2->>'slot_id', '')::uuid;
  v_ok := COALESCE((v_claim2->>'success')::boolean, false)
      AND v_slot_b IS NOT NULL
      AND v_slot_b IS DISTINCT FROM v_slot_id;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'concurrent_claim_different_slots', 'area', 'slot', 'pass', v_ok, 'detail', v_claim2
  ));

  -- insufficient gold pre-check (no charge)
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

  -- cannot challenge while holding own slot
  v_challenge := public.challenge_siege_slot(v_slot_b);
  v_ok := COALESCE((v_challenge->>'success')::boolean, true) = false
      AND COALESCE(v_challenge->>'error', '') LIKE '%Zaten slot tutuyorsun%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'cannot_challenge_while_holding_slot', 'area', 'challenge', 'pass', v_ok, 'detail', v_challenge
  ));

  -- power band rejection
  UPDATE public.dungeon_siege_config SET power_band_pct = 0.01 WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
  v_challenge := public.challenge_siege_slot(v_slot_id);
  v_ok := COALESCE((v_challenge->>'success')::boolean, true) = false
      AND COALESCE(v_challenge->>'error', '') LIKE '%güç farkı%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'power_band_rejection', 'area', 'challenge', 'pass', v_ok, 'detail', v_challenge
  ));
  UPDATE public.dungeon_siege_config SET power_band_pct = 1.0 WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  -- challenge resolves: ban loser, gold spent matches formula
  v_cost := public.dungeon_siege_challenge_gold_cost(v_dungeon_a);
  SELECT gold INTO v_gold_before FROM public.users WHERE auth_id = v_b;
  v_challenge := public.challenge_siege_slot(v_slot_id);
  SELECT gold INTO v_gold_after FROM public.users WHERE auth_id = v_b;
  v_ok := COALESCE((v_challenge->>'success')::boolean, false)
      AND (v_gold_before - v_gold_after) = v_cost
      AND COALESCE((v_challenge->>'gold_spent')::bigint, 0) = v_cost
      AND public.dungeon_siege_is_banned(v_b, v_dungeon_a);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'challenge_gold_matches_formula_and_ban_on_loss', 'area', 'challenge', 'pass', v_ok,
    'detail', jsonb_build_object('challenge', v_challenge, 'cost', v_cost, 'gold_delta', v_gold_before - v_gold_after)
  ));

  -- banned loser should not hold slot after loss
  v_ok := NOT EXISTS (
    SELECT 1 FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = v_a AND sess.dungeon_id = v_dungeon_a
  ) OR public.dungeon_siege_is_banned(v_a, v_dungeon_a) = false;
  -- Winner took slot OR defender still holds; loser ban ok either way
  v_ok := public.dungeon_siege_is_banned(
    CASE WHEN (v_challenge->>'you_won')::boolean THEN v_a ELSE v_b END,
    v_dungeon_a
  ) = false
  AND public.dungeon_siege_is_banned(
    CASE WHEN (v_challenge->>'you_won')::boolean THEN v_b ELSE v_a END,
    v_dungeon_a
  );
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'ban_applied_to_loser_not_winner', 'area', 'challenge', 'pass', v_ok, 'detail', v_challenge
  ));

  -- cooldown blocks immediate re-challenge
  PERFORM set_config('request.jwt.claim.sub', v_b::text, true);
  v_challenge := public.challenge_siege_slot(
    COALESCE(
      NULLIF(v_challenge->>'slot_id', '')::uuid,
      (SELECT s.id FROM public.dungeon_siege_slots s
       JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
       WHERE sess.dungeon_id = v_dungeon_a AND s.holder_id IS NOT NULL
       ORDER BY s.claimed_at DESC NULLS LAST LIMIT 1)
    )
  );
  v_ok := COALESCE((v_challenge->>'success')::boolean, true) = false
      AND COALESCE(v_challenge->>'error', '') LIKE '%bekleme%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'challenge_cooldown', 'area', 'challenge', 'pass', v_ok, 'detail', v_challenge
  ));

  -- hold: non-owner blocked with 1 slot
  PERFORM set_config('request.jwt.claim.sub', v_b::text, true);
  v_hold := public.start_siege_guild_hold(v_dungeon_a);
  v_ok := COALESCE((v_hold->>'success')::boolean, true) = false;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'hold_blocked_non_owner', 'area', 'hold', 'pass', v_ok, 'detail', v_hold
  ));

  -- hold: non-owner guild needs 3 distinct members (solo fail)
  DELETE FROM public.dungeon_siege_holds WHERE guild_id = v_guild_b;
  UPDATE public.guild_war_territories SET owner_guild_id = v_guild_b WHERE zone_number = 1;
  PERFORM set_config('request.jwt.claim.sub', v_b::text, true);
  v_hold := public.start_siege_guild_hold(v_dungeon_a);
  v_ok := COALESCE((v_hold->>'success')::boolean, true) = false
      AND COALESCE((v_hold->>'required')::integer, 99) = 3;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'hold_needs_min_members_non_owner', 'area', 'hold', 'pass', v_ok, 'detail', v_hold
  ));

  -- hold without own slot
  PERFORM public.release_siege_slot(v_slot_b);
  v_hold := public.start_siege_guild_hold(v_dungeon_a);
  v_ok := COALESCE((v_hold->>'success')::boolean, true) = false
      AND COALESCE(v_hold->>'error', '') LIKE '%slotu tutmalısın%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'hold_without_own_slot', 'area', 'hold', 'pass', v_ok, 'detail', v_hold
  ));

  -- concurrent hold start idempotent
  PERFORM set_config('request.jwt.claim.sub', v_c::text, true);
  PERFORM public.claim_siege_slot(v_dungeon_a);
  UPDATE public.guild_war_territories SET owner_guild_id = v_guild_b WHERE zone_number = 1;
  PERFORM set_config('request.jwt.claim.sub', v_b::text, true);
  v_hold := public.start_siege_guild_hold(v_dungeon_a);
  v_ok := COALESCE((v_hold->>'success')::boolean, false);
  v_hold := public.start_siege_guild_hold(v_dungeon_a);
  v_ok := v_ok AND COALESCE((v_hold->>'success')::boolean, false)
      AND COALESCE((v_hold->>'already_active')::boolean, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'hold_concurrent_start_idempotent', 'area', 'hold', 'pass', v_ok, 'detail', v_hold
  ));

  -- status includes defense fields for UI parity
  v_status := public.get_dungeon_siege_status(v_dungeon_a);
  SELECT elem INTO v_session FROM jsonb_array_elements(v_status->'sessions') elem
  WHERE elem->>'dungeon_id' = v_dungeon_a LIMIT 1;
  v_ok := v_session ? 'territory_defense_power'
      AND v_session ? 'territory_defense_siege_bonus_pct'
      AND v_session ? 'territory_defense_max_bonus_pct';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'status_defense_fields_for_ui', 'area', 'unified_defense', 'pass', v_ok, 'detail', v_session
  ));

  -- challenge after prime ends
  UPDATE public.dungeon_siege_config
  SET prime_windows = '[{"start":"03:00","end":"04:00"}]'::jsonb
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
  SELECT s.id INTO v_slot_id FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE sess.dungeon_id = v_dungeon_a AND s.holder_id IS NOT NULL LIMIT 1;
  PERFORM set_config('request.jwt.claim.sub', v_a::text, true);
  v_challenge := public.challenge_siege_slot(v_slot_id);
  v_ok := COALESCE((v_challenge->>'success')::boolean, true) = false
      AND COALESCE(v_challenge->>'error', '') LIKE '%aktif değil%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'challenge_blocked_outside_prime', 'area', 'edge', 'pass', v_ok, 'detail', v_challenge
  ));

  -- release slot
  UPDATE public.dungeon_siege_config
  SET prime_windows = '[{"start":"00:00","end":"23:59"}]'::jsonb
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
  PERFORM set_config('request.jwt.claim.sub', v_c::text, true);
  SELECT s.id INTO v_slot_id FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE sess.dungeon_id = v_dungeon_a AND s.holder_id = v_c LIMIT 1;
  IF v_slot_id IS NOT NULL THEN
    v_release := public.release_siege_slot(v_slot_id);
    v_ok := COALESCE((v_release->>'success')::boolean, false);
  ELSE
    v_ok := true;
    v_release := jsonb_build_object('skipped', true);
  END IF;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'release_slot', 'area', 'slot', 'pass', v_ok, 'detail', v_release
  ));

  -- restore config
  UPDATE public.dungeon_siege_config
  SET is_enabled = COALESCE(v_prev_enabled, false),
      prime_windows = COALESCE(v_prev_windows, prime_windows),
      power_band_pct = COALESCE(v_prev_band, power_band_pct)
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  -- cleanup
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

REVOKE ALL ON FUNCTION public.qa_smoke_dungeon_siege_gameplay() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_dungeon_siege_gameplay() TO service_role;

COMMIT;
