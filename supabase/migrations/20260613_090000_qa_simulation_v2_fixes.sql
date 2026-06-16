BEGIN;

-- ---------------------------------------------------------------------------
-- QA Simulation V2: proportional segments, measured exploits, cumulative KPIs
-- ---------------------------------------------------------------------------

ALTER TABLE public.qa_sim_checkpoints
  ADD COLUMN IF NOT EXISTS daily_gold_earned bigint,
  ADD COLUMN IF NOT EXISTS daily_gold_spent bigint,
  ADD COLUMN IF NOT EXISTS cumulative_gold_earned bigint,
  ADD COLUMN IF NOT EXISTS cumulative_gold_spent bigint,
  ADD COLUMN IF NOT EXISTS cumulative_gems_spent bigint,
  ADD COLUMN IF NOT EXISTS cumulative_items_minted bigint,
  ADD COLUMN IF NOT EXISTS cumulative_items_burned bigint;

CREATE TABLE IF NOT EXISTS public.qa_sim_exploit_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL,
  exploit_key text NOT NULL,
  bot_auth_id uuid,
  attempt_no integer NOT NULL DEFAULT 1,
  succeeded boolean NOT NULL,
  response jsonb,
  gold_delta bigint NOT NULL DEFAULT 0,
  gems_delta bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qa_sim_exploit_attempts_run
  ON public.qa_sim_exploit_attempts(run_id, exploit_key);

CREATE OR REPLACE FUNCTION public.qa_segment_for_bot(p_idx integer, p_total integer)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_slot integer;
BEGIN
  IF p_total IS NULL OR p_total < 1 THEN
    RETURN 'generic';
  END IF;

  v_slot := floor(((p_idx - 1)::numeric * 100.0) / p_total)::integer;

  RETURN CASE
    WHEN v_slot < 15 THEN 'newbie'
    WHEN v_slot < 35 THEN 'casual'
    WHEN v_slot < 55 THEN 'normal'
    WHEN v_slot < 70 THEN 'hardcore'
    WHEN v_slot < 80 THEN 'whale'
    WHEN v_slot < 88 THEN 'trader'
    WHEN v_slot < 94 THEN 'pvp'
    WHEN v_slot < 98 THEN 'guild'
    WHEN v_slot < 99 THEN 'multi'
    ELSE 'exploit'
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_assert_qa_mode()
RETURNS void
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF coalesce(current_setting('app.qa_mode', true), '') <> 'true' THEN
    RAISE EXCEPTION 'QA simulation blocked. Set app.qa_mode=true (staging) before seed/sim runs.';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_call_as_bot(p_bot_auth uuid, p_function_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result jsonb;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_bot_auth::text, true);
  EXECUTE format('SELECT to_jsonb(%I())', p_function_name) INTO v_result;
  RETURN coalesce(v_result, '{}'::jsonb);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_cleanup_bots()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted_users integer;
BEGIN
  DELETE FROM public.market_orders
  WHERE seller_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.pvp_matches
  WHERE attacker_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR defender_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.dungeon_runs
  WHERE player_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM auth.users au
  USING public.users u
  WHERE au.id = u.auth_id
    AND u.username LIKE 'qa_bot_%';

  GET DIAGNOSTICS v_deleted_users = ROW_COUNT;

  DELETE FROM public.users WHERE username LIKE 'qa_bot_%';
  DELETE FROM public.qa_bot_profiles;

  DELETE FROM public.mekans m
  USING public.users u
  WHERE m.name LIKE 'QA Mekan %'
    AND u.auth_id = m.owner_id
    AND u.username LIKE 'qa_bot_%';

  RETURN json_build_object('success', true, 'deleted_auth_users', v_deleted_users);
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_seed_mekans(p_count integer DEFAULT 1000)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_types text[] := ARRAY['bar', 'kahvehane', 'dovus_kulubu', 'luks_lounge', 'yeralti'];
  v_inserted integer := 0;
  v_bot record;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.mekans WHERE name LIKE 'QA Mekan %';

  FOR v_bot IN
    SELECT b.bot_auth_id, b.level_seed, row_number() OVER (ORDER BY b.bot_auth_id) AS rn
    FROM public.qa_bot_profiles b
    ORDER BY b.bot_auth_id
    LIMIT p_count
  LOOP
    INSERT INTO public.mekans (
      owner_id, mekan_type, name, level, fame, suspicion, is_open, created_at
    )
    VALUES (
      v_bot.bot_auth_id,
      v_types[1 + floor(random() * array_length(v_types, 1))::int],
      format('QA Mekan %s', v_bot.rn),
      GREATEST(1, LEAST(10, 1 + floor(random() * LEAST(10, v_bot.level_seed / 3 + 1))::int)),
      floor(random() * 500)::int,
      floor(random() * 40)::int,
      random() > 0.08,
      now() - (floor(random() * 20)::text || ' days')::interval
    )
    ON CONFLICT (owner_id) DO UPDATE
    SET
      name = EXCLUDED.name,
      mekan_type = EXCLUDED.mekan_type,
      level = EXCLUDED.level,
      fame = EXCLUDED.fame,
      suspicion = EXCLUDED.suspicion,
      is_open = EXCLUDED.is_open;

    v_inserted := v_inserted + 1;
  END LOOP;

  RETURN json_build_object('success', true, 'seeded_mekans', v_inserted);
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_run_exploit_battery(p_run_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_run_start timestamptz;
  v_run_end timestamptz;
  v_bot uuid;
  v_gold_before bigint;
  v_gold_after bigint;
  v_gems_before bigint;
  v_gems_after bigint;
  v_resp jsonb;
  v_attempt integer;
  v_success integer;
  v_out json;
BEGIN
  DELETE FROM public.qa_sim_exploit_attempts WHERE run_id = p_run_id;
  DELETE FROM public.qa_sim_exploit_findings WHERE run_id = p_run_id;

  SELECT min(created_at), max(created_at)
  INTO v_run_start, v_run_end
  FROM public.qa_sim_daily_events
  WHERE run_id = p_run_id;

  IF v_run_start IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'run_not_found');
  END IF;

  -- E01 multi_account_gold_funnel (PvP gold extraction by multi segment)
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'multi_account_gold_funnel',
    pm.attacker_id,
    row_number() OVER (PARTITION BY pm.attacker_id ORDER BY pm.created_at),
    pm.gold_stolen > 300,
    jsonb_build_object('gold_stolen', pm.gold_stolen, 'defender', pm.defender_id),
    pm.gold_stolen,
    0
  FROM public.pvp_matches pm
  JOIN public.qa_bot_profiles b ON b.bot_auth_id = pm.attacker_id AND b.segment = 'multi'
  WHERE pm.created_at BETWEEN v_run_start AND v_run_end + interval '1 hour'
  LIMIT 400;

  -- E02 market_price_manipulation (inflated listings during run)
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'market_price_manipulation',
    mo.seller_id,
    row_number() OVER (PARTITION BY mo.seller_id ORDER BY mo.created_at),
    mo.price > GREATEST(100, i.base_price * 2),
    jsonb_build_object('price', mo.price, 'base_price', i.base_price, 'item', i.name),
    mo.price,
    0
  FROM public.market_orders mo
  JOIN public.items i ON i.id = mo.item_id
  JOIN public.qa_bot_profiles b ON b.bot_auth_id = mo.seller_id
  WHERE mo.created_at BETWEEN v_run_start AND v_run_end + interval '1 hour'
  LIMIT 400;

  -- E03 hospital_escape_abuse (cheap skip pattern from sim telemetry)
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'hospital_escape_abuse',
    e.bot_auth_id,
    e.sim_day,
    e.hospital_escape_auto AND e.hospital_minutes > 0 AND e.gems_spent > 0
      AND (e.gems_spent::numeric / GREATEST(e.hospital_minutes, 1)) > 0.5,
    jsonb_build_object(
      'minutes', e.hospital_minutes,
      'gems_spent', e.gems_spent,
      'segment', e.segment
    ),
    0,
    e.gems_spent
  FROM public.qa_sim_daily_events e
  WHERE e.run_id = p_run_id
    AND e.hospital_minutes > 0
    AND e.hospital_escape_auto
  LIMIT 400;

  -- E04 prison_escape_abuse
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'prison_escape_abuse',
    e.bot_auth_id,
    e.sim_day,
    e.prison_escape_auto AND e.prison_minutes > 0 AND e.gems_spent > 0
      AND (e.gems_spent::numeric / GREATEST(e.prison_minutes, 1)) > 0.4,
    jsonb_build_object(
      'minutes', e.prison_minutes,
      'gems_spent', e.gems_spent,
      'segment', e.segment
    ),
    0,
    e.gems_spent
  FROM public.qa_sim_daily_events e
  WHERE e.run_id = p_run_id
    AND e.prison_minutes > 0
    AND e.prison_escape_auto
  LIMIT 400;

  -- E05 cooldown_bypass (excessive dungeon runs in one sim day)
  INSERT INTO public.qa_sim_exploit_attempts (
    run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
  )
  SELECT
    p_run_id,
    'cooldown_bypass',
    e.bot_auth_id,
    e.sim_day,
    e.dungeon_runs >= 4,
    jsonb_build_object('dungeon_runs', e.dungeon_runs, 'segment', e.segment),
    e.gold_earned,
    0
  FROM public.qa_sim_daily_events e
  WHERE e.run_id = p_run_id
    AND e.is_active
    AND e.dungeon_runs >= 3
  LIMIT 300;

  -- E06 premium_stack_abuse (live RPC replay on whale bots)
  v_attempt := 0;
  FOR v_bot IN
    SELECT bot_auth_id
    FROM public.qa_bot_profiles
    WHERE segment = 'whale'
    ORDER BY random()
    LIMIT 15
  LOOP
    SELECT gold, gems INTO v_gold_before, v_gems_before
    FROM public.users WHERE auth_id = v_bot;

    v_resp := public.qa_call_as_bot(v_bot, 'buy_vip_pass');
    v_attempt := v_attempt + 1;

    INSERT INTO public.qa_sim_exploit_attempts (
      run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
    )
    VALUES (
      p_run_id,
      'premium_stack_abuse',
      v_bot,
      v_attempt,
      coalesce(v_resp->>'success', 'false') = 'true',
      v_resp,
      0,
      -coalesce((v_resp->>'cost')::bigint, 0)
    );

    v_resp := public.qa_call_as_bot(v_bot, 'buy_vip_pass');
    v_attempt := v_attempt + 1;

    INSERT INTO public.qa_sim_exploit_attempts (
      run_id, exploit_key, bot_auth_id, attempt_no, succeeded, response, gold_delta, gems_delta
    )
    VALUES (
      p_run_id,
      'premium_stack_abuse',
      v_bot,
      v_attempt,
      coalesce(v_resp->>'success', 'false') = 'true',
      v_resp,
      0,
      0
    );
  END LOOP;

  -- Aggregate findings from measured attempts
  INSERT INTO public.qa_sim_exploit_findings (
    run_id, exploit_key, attempted_count, success_count,
    estimated_impact_gold, estimated_impact_gems, severity, mitigation
  )
  SELECT
    p_run_id,
    a.exploit_key,
    count(*)::integer,
    count(*) FILTER (WHERE a.succeeded)::integer,
    coalesce(sum(a.gold_delta) FILTER (WHERE a.succeeded), 0),
    coalesce(sum(a.gems_delta) FILTER (WHERE a.succeeded), 0),
    CASE a.exploit_key
      WHEN 'multi_account_gold_funnel' THEN 'critical'
      WHEN 'premium_stack_abuse' THEN 'critical'
      WHEN 'market_price_manipulation' THEN 'high'
      WHEN 'cooldown_bypass' THEN 'high'
      WHEN 'prison_escape_abuse' THEN 'high'
      ELSE 'medium'
    END,
    CASE a.exploit_key
      WHEN 'multi_account_gold_funnel' THEN 'Device fingerprint + transfer graph + delayed escrow'
      WHEN 'market_price_manipulation' THEN 'Median band guardrails + listing caps'
      WHEN 'cooldown_bypass' THEN 'Server-side cooldown nonce enforcement'
      WHEN 'hospital_escape_abuse' THEN 'Escalating gem cost + daily cap'
      WHEN 'prison_escape_abuse' THEN 'Progressive bail cost + alt linkage penalties'
      WHEN 'premium_stack_abuse' THEN 'Idempotent VIP grant + single entitlement source'
      ELSE 'Review exploit attempt logs'
    END
  FROM public.qa_sim_exploit_attempts a
  WHERE a.run_id = p_run_id
  GROUP BY a.exploit_key
  ON CONFLICT (run_id, exploit_key)
  DO UPDATE SET
    attempted_count = EXCLUDED.attempted_count,
    success_count = EXCLUDED.success_count,
    estimated_impact_gold = EXCLUDED.estimated_impact_gold,
    estimated_impact_gems = EXCLUDED.estimated_impact_gems,
    severity = EXCLUDED.severity,
    mitigation = EXCLUDED.mitigation,
    created_at = now();

  SELECT json_build_object(
    'success', true,
    'run_id', p_run_id,
    'exploit_types', (SELECT count(DISTINCT exploit_key) FROM public.qa_sim_exploit_findings WHERE run_id = p_run_id),
    'total_attempts', (SELECT count(*) FROM public.qa_sim_exploit_attempts WHERE run_id = p_run_id)
  ) INTO v_out;

  RETURN v_out;
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_export_run_summary(p_run_id uuid)
RETURNS json
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bots integer;
  v_d1 integer;
  v_d7 integer;
  v_d30 integer;
  v_base integer;
BEGIN
  SELECT count(*) INTO v_bots FROM public.qa_bot_profiles;

  SELECT active_users INTO v_d1
  FROM public.qa_sim_checkpoints
  WHERE run_id = p_run_id AND checkpoint_day = 1;

  SELECT active_users INTO v_d7
  FROM public.qa_sim_checkpoints
  WHERE run_id = p_run_id AND checkpoint_day = 7;

  SELECT active_users INTO v_d30
  FROM public.qa_sim_checkpoints
  WHERE run_id = p_run_id AND checkpoint_day = 30;

  v_base := GREATEST(v_bots, 1);

  RETURN json_build_object(
    'run_id', p_run_id,
    'bots', v_bots,
    'retention', json_build_object(
      'd1', round(coalesce(v_d1, 0)::numeric / v_base, 4),
      'd7', round(coalesce(v_d7, 0)::numeric / v_base, 4),
      'd30', round(coalesce(v_d30, 0)::numeric / v_base, 4)
    ),
    'economy', (
      SELECT json_build_object(
        'gold_in', coalesce(sum(gold_earned), 0),
        'gold_out', coalesce(sum(gold_spent), 0),
        'item_in', coalesce(sum(items_minted), 0),
        'item_out', coalesce(sum(items_burned), 0),
        'gems_out', coalesce(sum(gems_spent), 0)
      )
      FROM public.qa_sim_daily_events
      WHERE run_id = p_run_id
    ),
    'exploits', (
      SELECT coalesce(json_agg(json_build_object(
        'key', exploit_key,
        'attempts', attempted_count,
        'success', success_count,
        'impact_gold', estimated_impact_gold,
        'impact_gems', estimated_impact_gems,
        'severity', severity
      )), '[]'::json)
      FROM public.qa_sim_exploit_findings
      WHERE run_id = p_run_id
    ),
    'segments', (
      SELECT coalesce(json_object_agg(segment, cnt), '{}'::json)
      FROM (
        SELECT segment, count(*) AS cnt
        FROM public.qa_bot_profiles
        GROUP BY segment
      ) s
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_seed_bots(p_bot_count integer DEFAULT 100)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_idx integer;
  v_bot_auth uuid;
  v_bot_user uuid;
  v_segment text;
  v_behavior text;
  v_level integer;
  v_gold integer;
  v_gems integer;
  v_energy integer;
  v_class text;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM auth.users au
  USING public.users u
  WHERE au.id = u.auth_id
    AND u.username LIKE 'qa_bot_%';

  DELETE FROM public.users WHERE username LIKE 'qa_bot_%';
  DELETE FROM public.qa_bot_profiles;

  FOR v_idx IN 1..p_bot_count LOOP
    v_bot_auth := gen_random_uuid();
    v_bot_user := gen_random_uuid();

    v_segment := public.qa_segment_for_bot(v_idx, p_bot_count);

    v_behavior := CASE v_segment
      WHEN 'newbie' THEN 'first_time_no_guide_fast_bored'
      WHEN 'casual' THEN 'daily_15_min'
      WHEN 'normal' THEN 'daily_60_120_min'
      WHEN 'hardcore' THEN 'full_energy_optimizer'
      WHEN 'whale' THEN 'vip_premium_spender'
      WHEN 'trader' THEN 'buy_sell_flip_market'
      WHEN 'pvp' THEN 'constant_attack'
      WHEN 'guild' THEN 'social_coop'
      WHEN 'multi' THEN 'alt_account_farmer'
      WHEN 'exploit' THEN 'abuse_hunter'
      ELSE 'generic'
    END;

    v_level := CASE v_segment
      WHEN 'newbie' THEN 1 + floor(random() * 6)::int
      WHEN 'casual' THEN 5 + floor(random() * 16)::int
      WHEN 'normal' THEN 12 + floor(random() * 20)::int
      WHEN 'hardcore' THEN 22 + floor(random() * 25)::int
      WHEN 'whale' THEN 30 + floor(random() * 35)::int
      WHEN 'trader' THEN 15 + floor(random() * 25)::int
      WHEN 'pvp' THEN 18 + floor(random() * 27)::int
      WHEN 'guild' THEN 10 + floor(random() * 22)::int
      WHEN 'multi' THEN 8 + floor(random() * 18)::int
      WHEN 'exploit' THEN 16 + floor(random() * 20)::int
      ELSE 1 + floor(random() * 10)::int
    END;

    v_gold := CASE v_segment
      WHEN 'newbie' THEN 500 + floor(random() * 5000)::int
      WHEN 'casual' THEN 3000 + floor(random() * 18000)::int
      WHEN 'normal' THEN 10000 + floor(random() * 50000)::int
      WHEN 'hardcore' THEN 25000 + floor(random() * 120000)::int
      WHEN 'whale' THEN 75000 + floor(random() * 450000)::int
      ELSE 8000 + floor(random() * 80000)::int
    END;

    v_gems := CASE v_segment
      WHEN 'newbie' THEN 0 + floor(random() * 35)::int
      WHEN 'casual' THEN 10 + floor(random() * 80)::int
      WHEN 'normal' THEN 15 + floor(random() * 120)::int
      WHEN 'hardcore' THEN 20 + floor(random() * 180)::int
      WHEN 'whale' THEN 120 + floor(random() * 900)::int
      ELSE 15 + floor(random() * 150)::int
    END;

    v_energy := 20 + floor(random() * 80)::int;

    v_class := CASE floor(random() * 3)::int
      WHEN 0 THEN 'warrior'
      WHEN 1 THEN 'alchemist'
      ELSE 'shadow'
    END;

    INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES (
      v_bot_auth,
      'authenticated',
      'authenticated',
      format('qa_bot_%s@sim.local', v_idx),
      now(),
      now(),
      now(),
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object('username', format('qa_bot_%s', v_idx), 'is_bot', true)
    );

    INSERT INTO public.users (
      id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
      attack, defense, health, max_health, power,
      tutorial_completed, total_playtime_seconds, gems, experience,
      addiction_level, tolerance,
      pvp_wins, pvp_losses, pvp_rating, reputation,
      character_class, luck,
      created_at, updated_at, last_login_at
    )
    VALUES (
      v_bot_user,
      v_bot_auth,
      format('qa_bot_%s', v_idx),
      format('qa_bot_%s@sim.local', v_idx),
      format('QA Bot %s', v_idx),
      v_level,
      v_level * 120,
      v_gold,
      v_energy,
      100,
      20 + v_level * 2,
      18 + v_level * 2,
      120 + v_level * 6,
      120 + v_level * 6,
      120 + v_level * 10,
      CASE WHEN v_segment = 'newbie' THEN false ELSE true END,
      (300 + floor(random() * 7000)::int),
      v_gems,
      v_level * 120,
      floor(random() * 20)::int,
      floor(random() * 15)::int,
      floor(random() * 120)::int,
      floor(random() * 120)::int,
      900 + floor(random() * 500)::int,
      floor(random() * 120)::int,
      v_class,
      floor(random() * 40)::int,
      now() - (floor(random() * 25)::text || ' days')::interval,
      now(),
      now() - (floor(random() * 4)::text || ' days')::interval
    )
    ON CONFLICT (auth_id) DO UPDATE
    SET
      username = EXCLUDED.username,
      email = EXCLUDED.email,
      display_name = EXCLUDED.display_name,
      level = EXCLUDED.level,
      xp = EXCLUDED.xp,
      gold = EXCLUDED.gold,
      energy = EXCLUDED.energy,
      max_energy = EXCLUDED.max_energy,
      attack = EXCLUDED.attack,
      defense = EXCLUDED.defense,
      health = EXCLUDED.health,
      max_health = EXCLUDED.max_health,
      power = EXCLUDED.power,
      tutorial_completed = EXCLUDED.tutorial_completed,
      total_playtime_seconds = EXCLUDED.total_playtime_seconds,
      gems = EXCLUDED.gems,
      experience = EXCLUDED.experience,
      addiction_level = EXCLUDED.addiction_level,
      tolerance = EXCLUDED.tolerance,
      pvp_wins = EXCLUDED.pvp_wins,
      pvp_losses = EXCLUDED.pvp_losses,
      pvp_rating = EXCLUDED.pvp_rating,
      reputation = EXCLUDED.reputation,
      character_class = EXCLUDED.character_class,
      luck = EXCLUDED.luck,
      created_at = LEAST(public.users.created_at, EXCLUDED.created_at),
      updated_at = EXCLUDED.updated_at,
      last_login_at = EXCLUDED.last_login_at;

    INSERT INTO public.qa_bot_profiles (bot_auth_id, bot_user_id, segment, behavior_model, level_seed)
    VALUES (v_bot_auth, v_bot_user, v_segment, v_behavior, v_level);
  END LOOP;

  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, created_at, updated_at)
  SELECT
    gen_random_uuid(),
    b.bot_auth_id,
    x.item_id,
    GREATEST(1, floor(random() * 6)::int),
    x.slot_position,
    (x.slot_position <= 4),
    now(),
    now()
  FROM public.qa_bot_profiles b
  JOIN LATERAL (
    SELECT i.id AS item_id,
           row_number() OVER () AS slot_position
    FROM public.items i
    WHERE coalesce(i.required_level, 1) <= b.level_seed
    ORDER BY random()
    LIMIT (3 + floor(random() * 12)::int)
  ) x ON true;

  RETURN json_build_object(
    'success', true,
    'seeded_bots', p_bot_count,
    'segments', (
      SELECT coalesce(json_object_agg(segment, cnt), '{}'::json)
      FROM (
        SELECT segment, count(*) AS cnt
        FROM public.qa_bot_profiles
        GROUP BY segment
      ) s
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_run_30_day_simulation(
  p_days integer DEFAULT 30,
  p_run_id uuid DEFAULT gen_random_uuid()
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_day integer;
  v_day_ts timestamptz;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.qa_sim_daily_events WHERE run_id = p_run_id;
  DELETE FROM public.qa_sim_checkpoints WHERE run_id = p_run_id;
  DELETE FROM public.qa_sim_exploit_findings WHERE run_id = p_run_id;
  DELETE FROM public.qa_sim_exploit_attempts WHERE run_id = p_run_id;

  FOR v_day IN 1..p_days LOOP
    v_day_ts := now() - ((p_days - v_day) || ' days')::interval;

    INSERT INTO public.qa_sim_daily_events (
      run_id, sim_day, bot_auth_id, segment, is_active, session_minutes,
      quests_done, dungeon_runs, pvp_attacks, market_buys, market_sells,
      craft_actions, guild_actions, mekan_actions,
      hospital_minutes, prison_minutes, hospital_escape_auto, prison_escape_auto,
      gold_earned, gold_spent, gems_earned, gems_spent, xp_earned,
      items_minted, items_burned, churn_risk, created_at
    )
    SELECT
      p_run_id,
      v_day,
      b.bot_auth_id,
      b.segment,
      (random() < public.qa_active_probability(b.segment, v_day)) AS is_active,
      0,0,0,0,0,0,0,0,0,0,0,false,false,0,0,0,0,0,0,0,0,
      v_day_ts
    FROM public.qa_bot_profiles b;

    UPDATE public.qa_sim_daily_events e
    SET
      session_minutes = CASE
        WHEN NOT e.is_active THEN 0
        WHEN e.segment = 'newbie' THEN 3 + floor(random() * 14)::int
        WHEN e.segment = 'casual' THEN 8 + floor(random() * 20)::int
        WHEN e.segment = 'normal' THEN 45 + floor(random() * 75)::int
        WHEN e.segment = 'hardcore' THEN 110 + floor(random() * 130)::int
        WHEN e.segment = 'whale' THEN 70 + floor(random() * 160)::int
        WHEN e.segment = 'trader' THEN 35 + floor(random() * 80)::int
        WHEN e.segment = 'pvp' THEN 40 + floor(random() * 110)::int
        WHEN e.segment = 'guild' THEN 30 + floor(random() * 90)::int
        WHEN e.segment = 'multi' THEN 30 + floor(random() * 100)::int
        ELSE 25 + floor(random() * 110)::int
      END,
      quests_done = CASE WHEN e.is_active THEN floor(random() * 5)::int ELSE 0 END,
      dungeon_runs = CASE WHEN e.is_active THEN floor(random() * 4)::int ELSE 0 END,
      pvp_attacks = CASE
        WHEN NOT e.is_active THEN 0
        WHEN e.segment IN ('pvp','hardcore','exploit') THEN 2 + floor(random() * 8)::int
        ELSE floor(random() * 4)::int
      END,
      market_buys = CASE WHEN e.is_active THEN floor(random() * 4)::int ELSE 0 END,
      market_sells = CASE WHEN e.is_active THEN floor(random() * 5)::int ELSE 0 END,
      craft_actions = CASE WHEN e.is_active THEN floor(random() * 4)::int ELSE 0 END,
      guild_actions = CASE WHEN e.is_active AND e.segment IN ('guild','hardcore','whale') THEN 1 + floor(random() * 4)::int ELSE floor(random() * 2)::int END,
      mekan_actions = CASE WHEN e.is_active THEN floor(random() * 3)::int ELSE 0 END,
      hospital_minutes = CASE
        WHEN NOT e.is_active THEN 0
        WHEN random() < 0.11 THEN 20 + floor(random() * 140)::int
        ELSE 0
      END,
      prison_minutes = CASE
        WHEN NOT e.is_active THEN 0
        WHEN random() < 0.07 THEN 30 + floor(random() * 180)::int
        ELSE 0
      END,
      hospital_escape_auto = CASE
        WHEN NOT e.is_active THEN false
        WHEN e.segment IN ('whale','hardcore') THEN random() < 0.78
        WHEN e.segment IN ('normal','pvp') THEN random() < 0.45
        ELSE random() < 0.20
      END,
      prison_escape_auto = CASE
        WHEN NOT e.is_active THEN false
        WHEN e.segment IN ('whale','hardcore') THEN random() < 0.66
        WHEN e.segment IN ('normal','pvp') THEN random() < 0.38
        ELSE random() < 0.16
      END,
      gold_earned = CASE
        WHEN NOT e.is_active THEN 0
        ELSE (300 + e.quests_done * 220 + e.dungeon_runs * 650 + e.market_sells * 380 + e.mekan_actions * 300 + floor(random() * 500)::int)
      END,
      gold_spent = CASE
        WHEN NOT e.is_active THEN 0
        ELSE (120 + e.market_buys * 350 + e.craft_actions * 180 + e.guild_actions * 120 + floor(random() * 350)::int)
      END,
      gems_earned = CASE WHEN e.is_active THEN floor(random() * 5)::int ELSE 0 END,
      gems_spent = CASE
        WHEN NOT e.is_active THEN 0
        ELSE
          (CASE WHEN e.hospital_minutes > 0 AND e.hospital_escape_auto THEN GREATEST(2, ceil(e.hospital_minutes / 25.0)::int) ELSE 0 END)
          +
          (CASE WHEN e.prison_minutes > 0 AND e.prison_escape_auto THEN GREATEST(3, ceil(e.prison_minutes / 30.0)::int) ELSE 0 END)
          + (CASE WHEN e.segment = 'whale' THEN floor(random() * 20)::int ELSE floor(random() * 4)::int END)
      END,
      xp_earned = CASE WHEN e.is_active THEN (40 + e.quests_done * 55 + e.dungeon_runs * 120 + e.pvp_attacks * 35) ELSE 0 END,
      items_minted = CASE WHEN e.is_active THEN (e.dungeon_runs + e.craft_actions + floor(random() * 3)::int) ELSE 0 END,
      items_burned = CASE WHEN e.is_active THEN floor((e.market_sells + e.craft_actions) * 0.55)::int ELSE 0 END,
      churn_risk = CASE
        WHEN NOT e.is_active THEN LEAST(1.0, 0.35 + v_day * 0.015)
        WHEN e.session_minutes < 10 THEN LEAST(1.0, 0.30 + v_day * 0.010)
        WHEN e.gold_earned < e.gold_spent THEN LEAST(1.0, 0.25 + v_day * 0.008)
        ELSE GREATEST(0.02, 0.18 - v_day * 0.002)
      END
    WHERE e.run_id = p_run_id AND e.sim_day = v_day;

    UPDATE public.users u
    SET
      gold = GREATEST(0, u.gold + agg.gold_in - agg.gold_out),
      gems = GREATEST(0, u.gems + agg.gems_in - agg.gems_out),
      xp = u.xp + agg.xp_in,
      experience = u.experience + agg.xp_in,
      level = LEAST(120, u.level + floor((u.xp + agg.xp_in) / 5000)::int - floor(u.xp / 5000)::int),
      total_playtime_seconds = u.total_playtime_seconds + agg.play_sec,
      updated_at = v_day_ts,
      last_login_at = CASE WHEN agg.active_cnt > 0 THEN v_day_ts ELSE u.last_login_at END,
      hospital_until = CASE
        WHEN agg.hospital_left_minutes > 0 THEN v_day_ts + make_interval(mins => agg.hospital_left_minutes::int)
        ELSE NULL
      END,
      prison_until = CASE
        WHEN agg.prison_left_minutes > 0 THEN v_day_ts + make_interval(mins => agg.prison_left_minutes::int)
        ELSE NULL
      END,
      in_hospital = (agg.hospital_left_minutes > 0),
      in_prison = (agg.prison_left_minutes > 0),
      pvp_wins = u.pvp_wins + agg.pvp_wins_add,
      pvp_losses = u.pvp_losses + agg.pvp_losses_add
    FROM (
      SELECT
        e.bot_auth_id,
        sum(e.gold_earned) AS gold_in,
        sum(e.gold_spent) AS gold_out,
        sum(e.gems_earned) AS gems_in,
        sum(e.gems_spent) AS gems_out,
        sum(e.xp_earned) AS xp_in,
        sum(e.session_minutes * 60) AS play_sec,
        sum(CASE WHEN e.is_active THEN 1 ELSE 0 END) AS active_cnt,
        sum(CASE WHEN e.hospital_minutes > 0 AND NOT e.hospital_escape_auto THEN e.hospital_minutes ELSE 0 END) AS hospital_left_minutes,
        sum(CASE WHEN e.prison_minutes > 0 AND NOT e.prison_escape_auto THEN e.prison_minutes ELSE 0 END) AS prison_left_minutes,
        sum(CASE WHEN e.pvp_attacks > 0 THEN floor(e.pvp_attacks * 0.52)::int ELSE 0 END) AS pvp_wins_add,
        sum(CASE WHEN e.pvp_attacks > 0 THEN floor(e.pvp_attacks * 0.48)::int ELSE 0 END) AS pvp_losses_add
      FROM public.qa_sim_daily_events e
      WHERE e.run_id = p_run_id
        AND e.sim_day = v_day
      GROUP BY e.bot_auth_id
    ) agg
    WHERE u.auth_id = agg.bot_auth_id;

    INSERT INTO public.dungeon_runs (
      id, player_id, dungeon_id, success, is_critical,
      gold_earned, xp_earned, items_dropped, hospitalized,
      hospital_until, player_power, success_rate_at_run, is_first_clear, created_at
    )
    SELECT
      gen_random_uuid(),
      e.bot_auth_id,
      d.id,
      (random() < LEAST(0.92, 0.45 + (u.level * 0.01))) AS success,
      (random() < 0.08),
      (220 + floor(random() * 900)::int),
      (50 + floor(random() * 220)::int),
      '[]'::jsonb,
      (e.hospital_minutes > 0),
      CASE WHEN e.hospital_minutes > 0 AND NOT e.hospital_escape_auto THEN v_day_ts + make_interval(mins => e.hospital_minutes) ELSE NULL END,
      u.power,
      LEAST(0.95, 0.40 + (u.level * 0.008)),
      false,
      v_day_ts
    FROM public.qa_sim_daily_events e
    JOIN public.users u ON u.auth_id = e.bot_auth_id
    JOIN LATERAL (
      SELECT id FROM public.dungeons ORDER BY random() LIMIT 1
    ) d ON true
    WHERE e.run_id = p_run_id
      AND e.sim_day = v_day
      AND e.is_active
      AND e.dungeon_runs > 0;

    INSERT INTO public.pvp_matches (
      id, attacker_id, defender_id,
      winner_id, attacker_power, defender_power,
      attacker_hp_remaining, defender_hp_remaining,
      gold_stolen, rep_change_winner, rep_change_loser,
      attacker_rating_before, attacker_rating_after,
      defender_rating_before, defender_rating_after,
      is_critical_success, hospital_triggered, rounds, created_at
    )
    SELECT
      gen_random_uuid(),
      e.bot_auth_id,
      target.bot_auth_id,
      CASE WHEN random() < 0.55 THEN e.bot_auth_id ELSE target.bot_auth_id END,
      ua.power,
      ud.power,
      floor(20 + random() * 80)::int,
      floor(10 + random() * 75)::int,
      floor(150 + random() * 1200)::int,
      2,
      -2,
      ua.pvp_rating,
      ua.pvp_rating + floor(random() * 20)::int,
      ud.pvp_rating,
      GREATEST(100, ud.pvp_rating - floor(random() * 20)::int),
      (random() < 0.10),
      (random() < 0.09),
      2 + floor(random() * 5)::int,
      v_day_ts
    FROM public.qa_sim_daily_events e
    JOIN public.users ua ON ua.auth_id = e.bot_auth_id
    JOIN LATERAL (
      SELECT b.bot_auth_id
      FROM public.qa_bot_profiles b
      WHERE b.bot_auth_id <> e.bot_auth_id
      ORDER BY random()
      LIMIT 1
    ) target ON true
    JOIN public.users ud ON ud.auth_id = target.bot_auth_id
    WHERE e.run_id = p_run_id
      AND e.sim_day = v_day
      AND e.is_active
      AND e.pvp_attacks > 0;

    INSERT INTO public.market_orders (
      id, seller_id, item_id, quantity, price,
      region_id, listed_at, item_data, status, total_price,
      currency, player_id, item_name, item_type, rarity,
      is_stackable, max_stack, enhancement_level, side, fee, region,
      created_at
    )
    SELECT
      gen_random_uuid(),
      e.bot_auth_id,
      i.id,
      GREATEST(1, floor(random() * 5)::int),
      GREATEST(50, i.base_price + floor(random() * i.base_price * 0.45)::int),
      1,
      floor(extract(epoch from v_day_ts) * 1000)::bigint,
      jsonb_build_object('name', i.name, 'rarity', i.rarity),
      CASE WHEN random() < 0.72 THEN 'filled' ELSE 'open' END,
      GREATEST(50, i.base_price + floor(random() * i.base_price * 0.45)::int),
      'gold',
      e.bot_auth_id,
      i.name,
      i.type,
      i.rarity,
      i.is_stackable,
      i.max_stack,
      0,
      'sell',
      floor((i.base_price * 0.05))::int,
      'global',
      v_day_ts
    FROM public.qa_sim_daily_events e
    JOIN LATERAL (
      SELECT id, name, rarity, type, base_price, is_stackable, max_stack
      FROM public.items
      WHERE coalesce(is_market_tradeable, true) = true
      ORDER BY random()
      LIMIT 1
    ) i ON true
    WHERE e.run_id = p_run_id
      AND e.sim_day = v_day
      AND e.is_active
      AND e.market_sells > 0;

    IF v_day IN (1, 3, 7, 14, 30) THEN
      INSERT INTO public.qa_sim_checkpoints (
        run_id, checkpoint_day, active_users, retained_users, avg_session_minutes,
        total_gold_earned, total_gold_spent, total_gems_spent,
        total_items_minted, total_items_burned,
        daily_gold_earned, daily_gold_spent,
        cumulative_gold_earned, cumulative_gold_spent,
        cumulative_gems_spent, cumulative_items_minted, cumulative_items_burned,
        created_at
      )
      SELECT
        p_run_id,
        v_day,
        count(*) FILTER (WHERE e.is_active),
        count(*) FILTER (WHERE e.sim_day = 1 OR (e.is_active AND e.churn_risk < 0.80)),
        coalesce(avg(e.session_minutes), 0),
        coalesce(sum(e.gold_earned), 0),
        coalesce(sum(e.gold_spent), 0),
        coalesce(sum(e.gems_spent), 0),
        coalesce(sum(e.items_minted), 0),
        coalesce(sum(e.items_burned), 0),
        coalesce(sum(e.gold_earned), 0),
        coalesce(sum(e.gold_spent), 0),
        coalesce((
          SELECT sum(gold_earned)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        coalesce((
          SELECT sum(gold_spent)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        coalesce((
          SELECT sum(gems_spent)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        coalesce((
          SELECT sum(items_minted)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        coalesce((
          SELECT sum(items_burned)
          FROM public.qa_sim_daily_events x
          WHERE x.run_id = p_run_id AND x.sim_day <= v_day
        ), 0),
        v_day_ts
      FROM public.qa_sim_daily_events e
      WHERE e.run_id = p_run_id
        AND e.sim_day = v_day
      ON CONFLICT (run_id, checkpoint_day)
      DO UPDATE SET
        active_users = EXCLUDED.active_users,
        retained_users = EXCLUDED.retained_users,
        avg_session_minutes = EXCLUDED.avg_session_minutes,
        total_gold_earned = EXCLUDED.total_gold_earned,
        total_gold_spent = EXCLUDED.total_gold_spent,
        total_gems_spent = EXCLUDED.total_gems_spent,
        total_items_minted = EXCLUDED.total_items_minted,
        total_items_burned = EXCLUDED.total_items_burned,
        daily_gold_earned = EXCLUDED.daily_gold_earned,
        daily_gold_spent = EXCLUDED.daily_gold_spent,
        cumulative_gold_earned = EXCLUDED.cumulative_gold_earned,
        cumulative_gold_spent = EXCLUDED.cumulative_gold_spent,
        cumulative_gems_spent = EXCLUDED.cumulative_gems_spent,
        cumulative_items_minted = EXCLUDED.cumulative_items_minted,
        cumulative_items_burned = EXCLUDED.cumulative_items_burned,
        created_at = EXCLUDED.created_at;
    END IF;
  END LOOP;

  PERFORM public.qa_run_exploit_battery(p_run_id);

  RETURN json_build_object(
    'success', true,
    'run_id', p_run_id,
    'days', p_days,
    'bots', (SELECT count(*) FROM public.qa_bot_profiles),
    'events', (SELECT count(*) FROM public.qa_sim_daily_events WHERE run_id = p_run_id),
    'summary', public.qa_export_run_summary(p_run_id)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.qa_segment_for_bot(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_assert_qa_mode() TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_call_as_bot(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_cleanup_bots() TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_seed_mekans(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_run_exploit_battery(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qa_export_run_summary(uuid) TO authenticated;

COMMIT;
