-- QA smoke: reputation overview + shop + purchase shape
-- Run: SELECT public.qa_smoke_reputation();

CREATE OR REPLACE FUNCTION public.qa_smoke_reputation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := gen_random_uuid();
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_overview jsonb;
  v_shop jsonb;
  v_purchase jsonb;
  v_items jsonb;
  v_global_count integer;
  v_rep_before integer;
  v_rep_after integer;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  -- cleanup prior run
  DELETE FROM public.reputation_activity_log WHERE user_id = v_auth;
  DELETE FROM public.player_reputation_buffs WHERE user_id = v_auth;
  DELETE FROM public.player_faction_reputation WHERE user_id = v_auth;
  DELETE FROM auth.users WHERE email = 'qa_rep_smoke@sim.local';
  DELETE FROM public.users WHERE username = 'qa_rep_smoke';

  -- REP-01: core RPCs exist
  v_ok := to_regprocedure('public.get_reputation_overview()') IS NOT NULL
      AND to_regprocedure('public.get_reputation_shop()') IS NOT NULL
      AND to_regprocedure('public.purchase_reputation_item(text,text)') IS NOT NULL;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'rep_rpc_functions_exist',
    'area', 'schema',
    'pass', v_ok
  ));

  INSERT INTO auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) VALUES (
    v_auth, 'authenticated', 'authenticated',
    'qa_rep_smoke@sim.local', now(), now(), now(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('username', 'qa_rep_smoke', 'is_bot', true)
  );

  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
    attack, defense, health, max_health, power, gems, reputation, created_at, updated_at
  ) VALUES (
    v_auth, v_auth, 'qa_rep_smoke', 'qa_rep_smoke@sim.local', 'QA Rep Smoke',
    10, 1000, 500000, 100, 100, 30, 25, 120, 120, 200, 50, 0, now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    reputation = 0,
    energy = 100,
    updated_at = now();

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);

  -- REP-02: overview shape + global rep field
  v_overview := public.get_reputation_overview();
  v_ok := COALESCE((v_overview->>'success')::boolean, false)
      AND v_overview ? 'global_reputation'
      AND v_overview ? 'factions'
      AND v_overview ? 'activity'
      AND v_overview ? 'active_buffs'
      AND jsonb_typeof(v_overview->'factions') = 'array';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'rep_overview_rpc_shape',
    'area', 'rpc',
    'pass', v_ok,
    'detail', jsonb_build_object('global_reputation', v_overview->'global_reputation')
  ));

  -- REP-03: shop shape + items array
  v_shop := public.get_reputation_shop();
  v_items := COALESCE(v_shop->'items', '[]'::jsonb);
  v_ok := COALESCE((v_shop->>'success')::boolean, false)
      AND v_shop ? 'global_reputation'
      AND jsonb_typeof(v_items) = 'array'
      AND jsonb_array_length(v_items) > 0;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'rep_shop_rpc_shape',
    'area', 'rpc',
    'pass', v_ok,
    'detail', jsonb_build_object('item_count', jsonb_array_length(v_items))
  ));

  -- REP-04: shop has global-cost items (no faction id required)
  SELECT COUNT(*)::integer INTO v_global_count
  FROM jsonb_array_elements(v_items) elem
  WHERE elem->>'cost_type' = 'global';
  v_ok := v_global_count >= 1;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'rep_shop_has_global_items',
    'area', 'rpc',
    'pass', v_ok,
    'detail', jsonb_build_object('global_item_count', v_global_count)
  ));

  -- REP-05: purchase rejects insufficient global rep (shape check)
  v_purchase := public.purchase_reputation_item('gold_boost_30', NULL);
  v_ok := COALESCE((v_purchase->>'success')::boolean, true) = false
      AND v_purchase ? 'error';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'rep_purchase_insufficient_funds',
    'area', 'gameplay',
    'pass', v_ok,
    'detail', v_purchase
  ));

  -- REP-06: purchase success shape with funded account
  UPDATE public.users SET reputation = 5000 WHERE auth_id = v_auth;
  SELECT reputation INTO v_rep_before FROM public.users WHERE auth_id = v_auth;

  v_purchase := public.purchase_reputation_item('gold_boost_30', NULL);
  SELECT reputation INTO v_rep_after FROM public.users WHERE auth_id = v_auth;

  v_ok := COALESCE((v_purchase->>'success')::boolean, false)
      AND v_purchase ? 'item_id'
      AND v_purchase ? 'effect'
      AND v_rep_after < v_rep_before;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'rep_purchase_success_shape',
    'area', 'gameplay',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'rep_before', v_rep_before,
      'rep_after', v_rep_after,
      'purchase', v_purchase
    )
  ));

  -- REP-07: overview reflects spend activity
  v_overview := public.get_reputation_overview();
  v_ok := COALESCE((v_overview->>'success')::boolean, false)
      AND jsonb_array_length(COALESCE(v_overview->'activity', '[]'::jsonb)) >= 1;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'rep_activity_logged_after_purchase',
    'area', 'rpc',
    'pass', v_ok
  ));

  -- cleanup
  DELETE FROM public.reputation_activity_log WHERE user_id = v_auth;
  DELETE FROM public.player_reputation_buffs WHERE user_id = v_auth;
  DELETE FROM public.player_faction_reputation WHERE user_id = v_auth;
  DELETE FROM auth.users WHERE id = v_auth;
  DELETE FROM public.users WHERE auth_id = v_auth;

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

REVOKE ALL ON FUNCTION public.qa_smoke_reputation() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_reputation() TO service_role;
