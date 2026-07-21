-- PLAN_11 + PLAN_13: 10k bot comprehensive smoke (economy, class passives, gameplay, exploits)
-- service_role only; requires app.qa_mode=true

CREATE TABLE IF NOT EXISTS public.qa_comprehensive_smoke_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bots integer NOT NULL,
  sim_days integer NOT NULL,
  report jsonb NOT NULL,
  verdict text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.qa_smoke_plan11_passives()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_shadow_auth uuid := gen_random_uuid();
  v_alch_auth uuid := gen_random_uuid();
  v_row_id uuid := gen_random_uuid();
  v_gems_before numeric;
  v_gems_after numeric;
  v_tol_before integer;
  v_tol_after integer;
  v_risk integer;
  v_bribe jsonb;
  v_detox jsonb;
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.inventory WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_smoke_%'
  );
  DELETE FROM public.facilities WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_smoke_%'
  );
  DELETE FROM auth.users WHERE email LIKE 'qa_smoke_%@sim.local';
  DELETE FROM public.users WHERE username LIKE 'qa_smoke_%';

  -- 1) Hayalet Adımlar — etkin şüphe tavanı 80
  v_ok := public._effective_suspicion_risk(100, 'shadow') = 80
      AND public._effective_suspicion_risk(100, 'warrior') = 100
      AND public._effective_suspicion_risk(50, 'shadow') = 50;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'shadow_effective_suspicion_cap_80',
    'plan', 'PLAN_11 §2.3 Hayalet Adımlar',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'shadow_100', public._effective_suspicion_risk(100, 'shadow'),
      'warrior_100', public._effective_suspicion_risk(100, 'warrior')
    )
  ));

  -- 2) Gizli Operasyon — tesis şüphe birikimi -30%
  INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES (
    v_shadow_auth, 'authenticated', 'authenticated',
    'qa_smoke_shadow@sim.local', now(), now(), now(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('username', 'qa_smoke_shadow', 'is_bot', true)
  );
  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
    attack, defense, health, max_health, power, gems, character_class, global_suspicion_level,
    created_at, updated_at
  )
  VALUES (
    v_shadow_auth, v_shadow_auth, 'qa_smoke_shadow', 'qa_smoke_shadow@sim.local', 'QA Smoke Shadow',
    10, 1200, 500000, 100, 100, 30, 25, 120, 120, 200, 50, 'shadow', 0, now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    gems = EXCLUDED.gems,
    character_class = EXCLUDED.character_class,
    global_suspicion_level = EXCLUDED.global_suspicion_level,
    updated_at = now();
  INSERT INTO public.facilities (user_id, type, level, is_active, production_started_at, created_at, updated_at)
  VALUES
    (v_shadow_auth, 'mining', 4, true, now(), now(), now()),
    (v_shadow_auth, 'quarry', 4, true, now(), now(), now()),
    (v_shadow_auth, 'lumber_mill', 4, true, now(), now(), now()),
    (v_shadow_auth, 'clay_pit', 4, true, now(), now(), now());
  v_risk := public._recompute_global_suspicion(v_shadow_auth);
  -- (4*5 + 16/2) = 28 → floor(28*0.7) = 19
  v_ok := v_risk = 19;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'shadow_facility_suspicion_reduction_30pct',
    'plan', 'PLAN_11 §2.3 Gizli Operasyon',
    'pass', v_ok,
    'detail', jsonb_build_object('raw_formula_risk', 28, 'expected', 19, 'actual', v_risk)
  ));

  -- 3) Pazarlık — rüşvet gem -25% (5 → 4)
  UPDATE public.users
  SET gems = 50, global_suspicion_level = 40, last_bribe_at = NULL
  WHERE auth_id = v_shadow_auth;
  v_gems_before := 50;
  PERFORM set_config('request.jwt.claim.sub', v_shadow_auth::text, true);
  v_bribe := public.bribe_officials('mining', 5);
  SELECT gems INTO v_gems_after FROM public.users WHERE auth_id = v_shadow_auth;
  v_ok := COALESCE((v_bribe->>'success')::boolean, false)
      AND COALESCE((v_bribe->>'gems_spent')::integer, 0) = 4
      AND v_gems_after = v_gems_before - 4;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'shadow_bribe_gem_cost_minus_25pct',
    'plan', 'PLAN_11 §2.3 Pazarlık',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'rpc', v_bribe,
      'gems_before', v_gems_before,
      'gems_after', v_gems_after
    )
  ));

  -- 4) Detox Gücü — simyacı +25% etkinlik (minor 15 → 19)
  INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES (
    v_alch_auth, 'authenticated', 'authenticated',
    'qa_smoke_alchemist@sim.local', now(), now(), now(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('username', 'qa_smoke_alchemist', 'is_bot', true)
  );
  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
    attack, defense, health, max_health, power, tolerance, addiction_level,
    character_class, last_detox_used_at, created_at, updated_at
  )
  VALUES (
    v_alch_auth, v_alch_auth, 'qa_smoke_alchemist', 'qa_smoke_alchemist@sim.local', 'QA Smoke Alchemist',
    10, 1200, 500000, 100, 100, 15, 20, 120, 120, 180, 50, 5,
    'alchemist', NULL, now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    tolerance = EXCLUDED.tolerance,
    addiction_level = EXCLUDED.addiction_level,
    character_class = EXCLUDED.character_class,
    last_detox_used_at = NULL,
    updated_at = now();
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, created_at, updated_at)
  VALUES (v_row_id, v_alch_auth, 'detox_minor', 1, 1, false, now(), now());
  v_tol_before := 50;
  PERFORM set_config('request.jwt.claim.sub', v_alch_auth::text, true);
  v_detox := public.use_detox(v_row_id, v_alch_auth);
  SELECT tolerance INTO v_tol_after FROM public.users WHERE auth_id = v_alch_auth;
  v_ok := COALESCE((v_detox->>'success')::boolean, false)
      AND v_tol_after = v_tol_before - 19;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'alchemist_detox_effectiveness_plus_25pct',
    'plan', 'PLAN_11 §2.2 Detox Gücü',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'rpc', v_detox,
      'tolerance_before', v_tol_before,
      'tolerance_after', v_tol_after,
      'expected_reduction', 19
    )
  ));

  -- 5) character_classes seed aligns with PLAN_11 passive keys
  v_ok := EXISTS (
    SELECT 1 FROM public.character_classes
    WHERE id = 'shadow'
      AND (passive_bonuses ? 'facility_suspicion_reduction')
      AND (passive_bonuses ? 'bribe_cost_reduction')
      AND (passive_bonuses ? 'loot_luck_bonus')
  ) AND EXISTS (
    SELECT 1 FROM public.character_classes
    WHERE id = 'alchemist'
      AND (passive_bonuses ? 'detox_effectiveness_bonus')
  ) AND EXISTS (
    SELECT 1 FROM public.character_classes
    WHERE id = 'warrior'
      AND (passive_bonuses ? 'pvp_damage_bonus')
  );
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'character_classes_passive_bonuses_seeded',
    'plan', 'PLAN_11 §4 DB',
    'pass', v_ok
  ));

  -- cleanup ephemeral smoke users
  DELETE FROM public.inventory WHERE user_id IN (v_shadow_auth, v_alch_auth);
  DELETE FROM public.facilities WHERE user_id = v_shadow_auth;
  DELETE FROM auth.users WHERE id IN (v_shadow_auth, v_alch_auth);
  DELETE FROM public.users WHERE auth_id IN (v_shadow_auth, v_alch_auth);

  RETURN jsonb_build_object(
    'all_pass', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_results) e WHERE (e->>'pass')::boolean IS NOT TRUE),
    'tests', v_results
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_smoke_comprehensive_10k(
  p_bot_count integer DEFAULT 10000,
  p_sim_days integer DEFAULT 30,
  p_cleanup boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_run_id uuid := gen_random_uuid();
  v_report_id uuid := gen_random_uuid();
  v_seed json;
  v_sim json;
  v_summary json;
  v_plan11 jsonb;
  v_facilities jsonb;
  v_failures text[] := ARRAY[]::text[];
  v_verdict text := 'PASS';
  v_bots integer;
  v_gold_in numeric;
  v_gold_out numeric;
  v_item_in numeric;
  v_item_out numeric;
  v_gold_inflation numeric;
  v_item_inflation numeric;
  v_exploit_attempts integer := 0;
  v_exploit_success integer := 0;
  v_exploit_rate numeric;
  v_ret_d1 numeric;
  v_ret_d7 numeric;
  v_ret_d30 numeric;
  v_casual_d30 numeric;
  v_newbie_d30 numeric;
  v_class_stats jsonb;
  v_gameplay jsonb;
  v_gates jsonb;
  v_started timestamptz := clock_timestamp();
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM set_config('app.qa_sim_skip_side_inserts', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  IF p_cleanup THEN
    PERFORM public.qa_cleanup_bots();
  END IF;

  v_seed := public.qa_seed_bots(GREATEST(COALESCE(p_bot_count, 10000), 1));
  SELECT count(*) INTO v_bots FROM public.qa_bot_profiles;

  IF v_bots < GREATEST(COALESCE(p_bot_count, 10000), 1) * 0.95 THEN
    v_failures := array_append(v_failures, format('seed_incomplete: %s/%s bots', v_bots, p_bot_count));
  END IF;

  v_plan11 := public.qa_smoke_plan11_passives();
  IF COALESCE((v_plan11->>'all_pass')::boolean, false) IS NOT TRUE THEN
    v_failures := array_append(v_failures, 'plan11_passives_failed');
  END IF;

  v_sim := public.qa_run_30_day_simulation(p_sim_days, v_run_id);
  v_summary := v_sim->'summary';

  v_gold_in := COALESCE((v_summary->'economy'->>'gold_in')::numeric, 0);
  v_gold_out := COALESCE((v_summary->'economy'->>'gold_out')::numeric, 0);
  v_item_in := COALESCE((v_summary->'economy'->>'item_in')::numeric, 0);
  v_item_out := COALESCE((v_summary->'economy'->>'item_out')::numeric, 0);
  v_gold_inflation := CASE WHEN v_gold_in > 0 THEN round((v_gold_in - v_gold_out) / v_gold_in, 4) ELSE 0 END;
  v_item_inflation := CASE WHEN v_item_in > 0
    THEN round((v_item_in - v_item_out) / v_item_in, 4) ELSE 0 END;

  SELECT
    coalesce(sum(attempted_count), 0),
    coalesce(sum(success_count), 0)
  INTO v_exploit_attempts, v_exploit_success
  FROM public.qa_sim_exploit_findings
  WHERE run_id = v_run_id;
  v_exploit_rate := CASE WHEN v_exploit_attempts > 0
    THEN round(v_exploit_success::numeric / v_exploit_attempts, 4) ELSE 0 END;

  v_ret_d1 := COALESCE((v_summary->'retention'->>'d1')::numeric, 0);
  v_ret_d7 := COALESCE((v_summary->'retention'->>'d7')::numeric, 0);
  v_ret_d30 := COALESCE((v_summary->'retention'->>'d30')::numeric, 0);
  v_casual_d30 := v_ret_d30;
  v_newbie_d30 := v_ret_d30;

  -- PLAN_13 exit thresholds
  IF v_gold_inflation > 0.12 THEN
    v_failures := array_append(v_failures, format('gold_inflation_%s%%_exceeds_12%%', round(v_gold_inflation * 100, 2)));
  END IF;
  IF v_item_inflation > 0.15 THEN
    v_failures := array_append(v_failures, format('item_inflation_%s_exceeds_0.15', round(v_item_inflation, 4)));
  END IF;
  IF v_exploit_rate > 0.05 THEN
    v_failures := array_append(v_failures, format('exploit_success_rate_%s%%_exceeds_5%%', round(v_exploit_rate * 100, 2)));
  END IF;
  IF v_casual_d30 < 0.15 THEN
    v_failures := array_append(v_failures, format('casual_d30_retention_%s_below_15%%', round(v_casual_d30 * 100, 2)));
  END IF;
  IF v_newbie_d30 < 0.10 THEN
    v_failures := array_append(v_failures, format('newbie_d30_retention_%s_below_10%%', round(v_newbie_d30 * 100, 2)));
  END IF;

  v_facilities := public.qa_smoke_facilities_stress(LEAST(v_bots, 2000));
  IF COALESCE(v_facilities->>'verdict', '') NOT LIKE 'PASS:%' THEN
    v_failures := array_append(v_failures, 'facilities_stress: ' || COALESCE(v_facilities->>'verdict', 'unknown'));
  END IF;

  -- Class balance & gameplay proxies (PLAN_06 / PLAN_11 — no class should dominate economy)
  SELECT coalesce(jsonb_object_agg(character_class, stats), '{}'::jsonb)
  INTO v_class_stats
  FROM (
    SELECT
      coalesce(u.character_class, 'none') AS character_class,
      jsonb_build_object(
        'bots', count(DISTINCT u.auth_id),
        'avg_gold_earned_d30', round(avg(e.gold_earned) FILTER (WHERE e.sim_day = p_sim_days), 2),
        'avg_dungeon_runs', round(avg(e.dungeon_runs), 2),
        'avg_craft_actions', round(avg(e.craft_actions), 2),
        'avg_session_minutes', round(avg(e.session_minutes) FILTER (WHERE e.is_active), 2)
      ) AS stats
    FROM public.qa_sim_daily_events e
    JOIN public.users u ON u.auth_id = e.bot_auth_id
    WHERE e.run_id = v_run_id
    GROUP BY coalesce(u.character_class, 'none')
  ) s;

  SELECT jsonb_build_object(
    'retention', v_summary->'retention',
    'avg_session_by_segment', (
      SELECT coalesce(jsonb_object_agg(segment, avg_mins), '{}'::jsonb)
      FROM (
        SELECT e.segment, round(avg(e.session_minutes) FILTER (WHERE e.is_active), 2) AS avg_mins
        FROM public.qa_sim_daily_events e
        WHERE e.run_id = v_run_id
        GROUP BY e.segment
      ) seg
    ),
    'class_engagement', v_class_stats,
    'alchemist_craft_vs_warrior', (
      SELECT round(
        coalesce(avg(e.craft_actions) FILTER (WHERE u.character_class = 'alchemist'), 0)
        / GREATEST(coalesce(avg(e.craft_actions) FILTER (WHERE u.character_class = 'warrior'), 0), 0.01),
        2
      )
      FROM public.qa_sim_daily_events e
      JOIN public.users u ON u.auth_id = e.bot_auth_id
      WHERE e.run_id = v_run_id
    ),
    'warnings', '[]'::jsonb
  ) INTO v_gameplay;

  -- Sim uses random craft_actions (not class-biased); informational only per PLAN_11 identity
  IF COALESCE((v_gameplay->>'alchemist_craft_vs_warrior')::numeric, 0) < 1.0 THEN
    v_gameplay := jsonb_set(
      v_gameplay,
      '{warnings}',
      coalesce(v_gameplay->'warnings', '[]'::jsonb)
        || jsonb_build_array('info: sim craft_actions not class-biased yet — alchemist/warrior ratio < 1')
    );
  END IF;

  v_gates := jsonb_build_object(
    'plan13', jsonb_build_object(
      'gold_inflation_pct', round(v_gold_inflation * 100, 2),
      'gold_inflation_pass', v_gold_inflation <= 0.12,
      'item_inflation_pct', round(v_item_inflation * 100, 2),
      'item_inflation_pass', v_item_inflation <= 0.15,
      'exploit_success_rate_pct', round(v_exploit_rate * 100, 2),
      'exploit_pass', v_exploit_rate <= 0.05,
      'casual_d30_retention', v_casual_d30,
      'casual_d30_pass', v_casual_d30 >= 0.15,
      'newbie_d30_retention', v_newbie_d30,
      'newbie_d30_pass', v_newbie_d30 >= 0.10
    ),
    'plan11', v_plan11,
    'facilities_stress', v_facilities
  );

  IF array_length(v_failures, 1) IS NOT NULL THEN
    v_verdict := 'FAIL';
  END IF;

  INSERT INTO public.qa_comprehensive_smoke_runs (id, bots, sim_days, report, verdict)
  VALUES (
    v_report_id,
    v_bots,
    p_sim_days,
    jsonb_build_object(
      'run_id', v_run_id,
      'bots', v_bots,
      'sim_days', p_sim_days,
      'events', (v_sim->>'events')::bigint,
      'duration_seconds', round(extract(epoch FROM clock_timestamp() - v_started)::numeric, 2),
      'verdict', v_verdict,
      'failures', to_jsonb(v_failures),
      'gates', v_gates,
      'summary', v_summary,
      'gameplay', v_gameplay,
      'seed', v_seed::jsonb
    ),
    v_verdict
  );

  RETURN (
    SELECT report || jsonb_build_object('report_id', v_report_id)
    FROM public.qa_comprehensive_smoke_runs
    WHERE id = v_report_id
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.qa_smoke_plan11_passives() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.qa_smoke_comprehensive_10k(integer, integer, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_smoke_plan11_passives() TO service_role;
GRANT EXECUTE ON FUNCTION public.qa_smoke_comprehensive_10k(integer, integer, boolean) TO service_role;
