-- Health system smoke fixes: pvp_attack gate, knockout hospital, potion timestamp, QA smoke.

BEGIN;

-- ── use_potion: bump health_last_updated on heal ─────────────────────────────

CREATE OR REPLACE FUNCTION public.use_potion(
  p_row_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_new_tolerance INT;
  v_overdose BOOLEAN := false;
  v_efficiency NUMERIC;
  v_overdose_chance NUMERIC;
  v_roll NUMERIC;
  v_hospital_minutes INT;
  v_heal_amount INT;
  v_energy_gain INT;
  v_monument_level INT := 0;
  v_saved_from_overdose BOOLEAN := false;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_user.guild_id;
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR lower(COALESCE(v_item.type, '')) NOT IN ('potion', 'consumable') THEN
    RETURN jsonb_build_object('error', 'Geçersiz iksir');
  END IF;

  v_new_tolerance := COALESCE(v_user.tolerance, 0) + COALESCE(v_item.tolerance_increase, 0);
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_new_tolerance := COALESCE(v_user.tolerance, 0)
      + floor(COALESCE(v_item.tolerance_increase, 0) * 0.75);
  END IF;
  v_new_tolerance := GREATEST(0, LEAST(v_new_tolerance, 100));

  v_efficiency := CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 20 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.85
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 0.65
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 0.45
    ELSE 0.25
  END;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_efficiency := LEAST(1.0, v_efficiency * 1.30);
  END IF;

  v_overdose_chance := COALESCE(v_item.overdose_risk, 0) * CASE
    WHEN COALESCE(v_user.tolerance, 0) <= 40 THEN 0.0
    WHEN COALESCE(v_user.tolerance, 0) <= 60 THEN 1.0
    WHEN COALESCE(v_user.tolerance, 0) <= 80 THEN 2.0
    WHEN COALESCE(v_user.tolerance, 0) <= 90 THEN 4.0
    ELSE 8.0
  END;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_overdose_chance := v_overdose_chance * 0.80;
  END IF;

  IF v_monument_level >= 20 THEN
    v_overdose_chance := v_overdose_chance * 0.90;
  END IF;

  v_roll := random();
  IF v_roll <= v_overdose_chance THEN
    v_overdose := true;

    IF v_monument_level >= 80 AND (
      v_user.last_overdose_save_at IS NULL OR
      v_user.last_overdose_save_at::date < CURRENT_DATE
    ) THEN
      v_overdose := false;
      v_saved_from_overdose := true;
    END IF;
  END IF;

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  PERFORM public.bp_trigger_potion_usage(p_user_id);

  IF v_overdose THEN
    v_hospital_minutes := 30 + (COALESCE(v_user.tolerance, 0) * 2);

    UPDATE public.users
    SET addiction_level = LEAST(COALESCE(addiction_level, 0) + 1, 10),
        tolerance = LEAST(v_new_tolerance + 10, 100),
        hospital_until = now() + (v_hospital_minutes || ' minutes')::interval,
        hospital_reason = 'Overdose',
        last_potion_used_at = now()
    WHERE auth_id = p_user_id;

    INSERT INTO public.tolerance_log (
      user_id, event_type, item_id,
      tolerance_before, tolerance_after,
      addiction_before, addiction_after
    )
    VALUES (
      p_user_id, 'overdose', v_inv.item_id,
      COALESCE(v_user.tolerance, 0), LEAST(v_new_tolerance + 10, 100),
      COALESCE(v_user.addiction_level, 0), LEAST(COALESCE(v_user.addiction_level, 0) + 1, 10)
    );

    RETURN jsonb_build_object(
      'success', true,
      'overdose', true,
      'hospital_minutes', v_hospital_minutes,
      'efficiency', 0
    );
  END IF;

  v_heal_amount := floor(COALESCE(v_item.heal_amount, v_item.health_restore, 0) * v_efficiency);
  v_energy_gain := floor(COALESCE(v_item.energy_restore, 0) * v_efficiency);

  IF lower(COALESCE(v_item.potion_type, '')) = 'health' AND v_heal_amount = 0 THEN
    v_heal_amount := floor(COALESCE(v_item.heal_amount, 50) * v_efficiency);
  END IF;

  IF lower(COALESCE(v_item.potion_type, '')) = 'energy' AND v_energy_gain = 0 THEN
    v_energy_gain := floor(COALESCE(v_item.heal_amount, 20) * v_efficiency);
  END IF;

  UPDATE public.users
  SET tolerance = v_new_tolerance,
      last_potion_used_at = now(),
      last_overdose_save_at = CASE WHEN v_saved_from_overdose THEN now() ELSE last_overdose_save_at END,
      energy = LEAST(max_energy, energy + v_energy_gain),
      health = LEAST(max_health, health + v_heal_amount),
      health_last_updated = CASE
        WHEN v_heal_amount > 0 THEN now()
        ELSE health_last_updated
      END,
      updated_at = now()
  WHERE auth_id = p_user_id;

  INSERT INTO public.tolerance_log (
    user_id, event_type, item_id,
    tolerance_before, tolerance_after,
    addiction_before, addiction_after
  )
  VALUES (
    p_user_id, 'potion_use', v_inv.item_id,
    COALESCE(v_user.tolerance, 0), v_new_tolerance,
    COALESCE(v_user.addiction_level, 0), COALESCE(v_user.addiction_level, 0)
  );

  RETURN jsonb_build_object(
    'success', true,
    'overdose', false,
    'saved_from_overdose', v_saved_from_overdose,
    'efficiency', v_efficiency,
    'new_tolerance', v_new_tolerance,
    'heal_amount', v_heal_amount,
    'energy_restored', v_energy_gain
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_potion(UUID, UUID) TO authenticated;

-- ── pvp_attack: low-health gate + knockout → hospital ────────────────────────

DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('public.pvp_attack(uuid, uuid, uuid)'::regprocedure) INTO v_def;
  IF v_def IS NULL THEN
    RAISE NOTICE 'pvp_attack not found — skip patch';
    RETURN;
  END IF;

  v_def := replace(v_def, E'\r\n', E'\n');

  IF position('player_combat_min_health' IN v_def) = 0
     AND position('PvP icin minimum level 10' IN v_def) > 0 THEN
    v_def := replace(
      v_def,
      E'  IF COALESCE(v_attacker.level, 1) < 10 OR COALESCE(v_defender.level, 1) < 10 THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''PvP icin minimum level 10'');\n  END IF;',
      E'  IF COALESCE(v_attacker.level, 1) < 10 OR COALESCE(v_defender.level, 1) < 10 THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''PvP icin minimum level 10'');\n  END IF;\n\n  IF COALESCE(v_attacker.health, v_attacker.max_health, 100) < public.player_combat_min_health(COALESCE(v_attacker.max_health, 100)) THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Canin cok dusuk — iksir kullan veya dinlen.'', ''error_code'', ''low_health'');\n  END IF;'
    );
  END IF;

  IF position('Knockout' IN v_def) = 0
     AND position('v_hospital_chance := CASE' IN v_def) > 0 THEN
    v_def := replace(
      v_def,
      E'  v_hospital_chance := CASE\n    WHEN v_winner_id = p_attacker_id THEN 0.05\n    ELSE 0.25\n  END;\n\n  IF random() < v_hospital_chance THEN',
      E'  v_hospital_chance := CASE\n    WHEN v_winner_id = p_attacker_id THEN 0.05\n    ELSE 0.25\n  END;\n\n  IF (v_winner_id = p_attacker_id AND v_defender_hp <= 0)\n     OR (v_winner_id = p_defender_id AND v_attacker_hp <= 0) THEN\n    v_hospital_triggered := true;\n    v_hospital_minutes := GREATEST(30, floor(45 + random() * 45)::INT);\n    UPDATE public.users\n    SET hospital_until = now() + (v_hospital_minutes || '' minutes'')::INTERVAL,\n        hospital_reason = ''Knockout'',\n        hospital_lifetime_count = COALESCE(hospital_lifetime_count, 0) + 1,\n        updated_at = now()\n    WHERE auth_id = CASE WHEN v_winner_id = p_attacker_id THEN p_defender_id ELSE p_attacker_id END;\n  ELSIF random() < v_hospital_chance THEN'
    );
  END IF;

  IF position('player_combat_min_health' IN v_def) > 0 OR position('Knockout' IN v_def) > 0 THEN
    EXECUTE v_def;
  END IF;
END;
$$;

-- ── QA smoke: full health system ─────────────────────────────────────────────
-- Run: SELECT public.qa_smoke_health_system();

CREATE OR REPLACE FUNCTION public.qa_smoke_health_system()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := gen_random_uuid();
  v_auth_b uuid := gen_random_uuid();
  v_row_id uuid := gen_random_uuid();
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_regen jsonb;
  v_heal jsonb;
  v_hosp jsonb;
  v_gate jsonb;
  v_health int;
  v_max int;
  v_floor int;
  v_wounded int;
  v_combat_min int;
  v_before timestamptz;
  v_def_health int;
  v_stat_alloc int;
  v_after_ts timestamptz;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.inventory WHERE user_id IN (v_auth, v_auth_b);
  DELETE FROM public.users WHERE auth_id IN (v_auth, v_auth_b);
  DELETE FROM auth.users WHERE id IN (v_auth, v_auth_b);

  INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at)
  VALUES
    (v_auth, 'authenticated', 'authenticated', 'qa_health_smoke@sim.local', now(), now(), now()),
    (v_auth_b, 'authenticated', 'authenticated', 'qa_health_smoke_b@sim.local', now(), now(), now());

  INSERT INTO public.users (
    id, auth_id, username, email, level, gold, gems, energy, max_energy,
    attack, defense, health, max_health, health_last_updated, stat_points,
    character_class, created_at, updated_at
  ) VALUES (
    v_auth, v_auth, 'qa_health_smoke', 'qa_health_smoke@sim.local',
    15, 100000, 500, 100, 100, 50, 40, 250, 400,
    now() - interval '2 hours', 5, 'warrior', now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    level = EXCLUDED.level,
    gold = EXCLUDED.gold,
    gems = EXCLUDED.gems,
    energy = EXCLUDED.energy,
    max_energy = EXCLUDED.max_energy,
    attack = EXCLUDED.attack,
    defense = EXCLUDED.defense,
    health = EXCLUDED.health,
    max_health = EXCLUDED.max_health,
    health_last_updated = EXCLUDED.health_last_updated,
    stat_points = EXCLUDED.stat_points,
    character_class = EXCLUDED.character_class,
    hospital_until = NULL,
    prison_until = NULL,
    updated_at = now();

  INSERT INTO public.users (
    id, auth_id, username, email, level, gold, gems, energy, max_energy,
    attack, defense, health, max_health, health_last_updated,
    character_class, created_at, updated_at
  ) VALUES (
    v_auth_b, v_auth_b, 'qa_health_smoke_b', 'qa_health_smoke_b@sim.local',
    15, 100000, 500, 100, 100, 50, 40, 400, 400,
    now(), 'warrior', now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET
    username = EXCLUDED.username,
    health = EXCLUDED.health,
    max_health = EXCLUDED.max_health,
    health_last_updated = EXCLUDED.health_last_updated,
    hospital_until = NULL,
    prison_until = NULL,
    updated_at = now();

  v_max := 400;
  v_combat_min := public.player_combat_min_health(v_max);
  v_wounded := public.player_wounded_health(v_max);
  v_floor := public.player_health_floor(v_max);

  v_ok := v_combat_min = 80 AND v_wounded = 200 AND v_floor = 60;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'health_threshold_helpers',
    'pass', v_ok,
    'detail', jsonb_build_object('combat_min', v_combat_min, 'wounded', v_wounded, 'floor', v_floor)
  ));

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);

  UPDATE public.users
  SET health = 250,
      max_health = 400,
      health_last_updated = now() - interval '2 hours'
  WHERE auth_id = v_auth;

  v_regen := public.apply_health_regen(v_auth);
  v_ok := COALESCE((v_regen->>'success')::boolean, false)
      AND COALESCE((v_regen->>'gained')::int, 0) > 0
      AND (v_regen ? 'status')
      AND (v_regen ? 'seconds_to_full');
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'apply_health_regen_passive_gain',
    'pass', v_ok,
    'detail', v_regen
  ));

  UPDATE public.users
  SET hospital_until = now() + interval '30 minutes', health = 100
  WHERE auth_id = v_auth;

  v_regen := public.apply_health_regen(v_auth);
  v_ok := COALESCE((v_regen->>'restricted')::boolean, false)
      AND COALESCE((v_regen->>'gained')::int, 0) = 0;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'apply_health_regen_blocked_in_hospital',
    'pass', v_ok,
    'detail', v_regen
  ));

  UPDATE public.users
  SET hospital_until = now() - interval '5 minutes',
      health = 350,
      max_health = 400,
      gems = 500
  WHERE auth_id = v_auth;

  v_ok := public.sync_expired_hospital(v_auth);
  SELECT health INTO v_health FROM public.users WHERE auth_id = v_auth;
  v_ok := v_ok AND v_health = v_wounded;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'sync_expired_hospital_wounded_discharge',
    'pass', v_ok,
    'detail', jsonb_build_object('health_after', v_health, 'expected_wounded', v_wounded)
  ));

  UPDATE public.users
  SET health = 150, max_health = 400, gems = 500,
      hospital_until = NULL, prison_until = NULL
  WHERE auth_id = v_auth;

  v_heal := public.heal_health_with_gems();
  v_ok := COALESCE((v_heal->>'success')::boolean, false)
      AND COALESCE((v_heal->>'health')::int, 0) = 400;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'heal_health_with_gems_full_restore',
    'pass', v_ok,
    'detail', v_heal
  ));

  UPDATE public.users
  SET health = 200, hospital_until = now() + interval '60 minutes',
      hospital_lifetime_count = 3, gems = 500
  WHERE auth_id = v_auth;

  v_hosp := public.heal_with_gems();
  SELECT health INTO v_health FROM public.users WHERE auth_id = v_auth;
  v_ok := COALESCE((v_hosp->>'success')::boolean, false)
      AND v_health = v_wounded;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'heal_with_gems_hospital_exit_wounded',
    'pass', v_ok,
    'detail', jsonb_build_object('rpc', v_hosp, 'health_after', v_health)
  ));

  UPDATE public.users
  SET health = v_combat_min - 1, max_health = 400,
      hospital_until = NULL, prison_until = NULL
  WHERE auth_id = v_auth;

  v_gate := public.assert_player_pvp_health(v_auth);
  v_ok := v_gate IS NOT NULL
      AND v_gate->>'error_code' = 'low_health';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'assert_player_pvp_health_blocks_critical',
    'pass', v_ok,
    'detail', v_gate
  ));

  UPDATE public.users SET health = 400, max_health = 400 WHERE auth_id = v_auth;
  UPDATE public.users SET health = 400, max_health = 400 WHERE auth_id = v_auth_b;

  PERFORM public.persist_pvp_sim_health(v_auth, v_auth_b, 0, 0, 400, 400);
  SELECT health INTO v_health FROM public.users WHERE auth_id = v_auth;
  SELECT health INTO v_def_health FROM public.users WHERE auth_id = v_auth_b;
  v_ok := v_health = v_floor AND v_def_health = v_floor;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'persist_pvp_sim_health_floors_at_15pct',
    'pass', v_ok,
    'detail', jsonb_build_object('attacker_health', v_health, 'defender_health', v_def_health, 'floor', v_floor)
  ));

  PERFORM public.apply_arena_pvp_health_damage(v_auth, gen_random_uuid());
  SELECT health INTO v_health FROM public.users WHERE auth_id = v_auth;
  v_ok := v_health = v_floor;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'apply_arena_pvp_health_damage_missing_opponent_noop',
    'pass', v_ok
  ));

  UPDATE public.users SET health = 400, max_health = 400 WHERE auth_id = v_auth;
  UPDATE public.users SET health = 400, max_health = 400 WHERE auth_id = v_auth_b;
  PERFORM public.apply_arena_pvp_health_damage(v_auth, v_auth_b);
  SELECT health INTO v_health FROM public.users WHERE auth_id = v_auth_b;
  v_ok := v_health >= v_floor AND v_health < 400;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'apply_arena_pvp_health_damage_reduces_loser',
    'pass', v_ok,
    'detail', jsonb_build_object('loser_health', v_health, 'floor', v_floor)
  ));

  UPDATE public.users
  SET health = 100, max_health = 400, stat_points = 3,
      hospital_until = NULL, prison_until = NULL
  WHERE auth_id = v_auth;

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);
  v_heal := public.allocate_stat_points(0, 0, 0, 1);
  SELECT health, max_health, stat_allocated_health
  INTO v_health, v_max, v_stat_alloc
  FROM public.users WHERE auth_id = v_auth;
  v_ok := COALESCE((v_heal->>'success')::boolean, false)
      AND v_max = 410 AND v_health = 110 AND v_stat_alloc = 1;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'allocate_stat_points_health_plus_10',
    'pass', v_ok,
    'detail', jsonb_build_object('rpc', v_heal, 'health', v_health, 'max_health', v_max)
  ));

  UPDATE public.users
  SET health = 80, max_health = 410, health_last_updated = now() - interval '1 day'
  WHERE auth_id = v_auth;

  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, created_at, updated_at)
  VALUES (v_row_id, v_auth, 'potion_health_minor', 1, now(), now());

  v_before := (SELECT health_last_updated FROM public.users WHERE auth_id = v_auth);
  v_heal := public.use_potion(v_row_id, v_auth);
  SELECT health, health_last_updated INTO v_health, v_after_ts FROM public.users WHERE auth_id = v_auth;
  v_ok := COALESCE((v_heal->>'success')::boolean, false)
      AND COALESCE((v_heal->>'heal_amount')::int, 0) > 0
      AND v_health > 80
      AND v_after_ts > v_before;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'use_potion_heals_and_updates_health_timestamp',
    'pass', v_ok,
    'detail', jsonb_build_object('rpc', v_heal, 'health', v_health)
  ));

  v_ok := pg_get_functiondef('public.pvp_attack(uuid,uuid,uuid)'::regprocedure)
      LIKE '%player_combat_min_health%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'pvp_attack_has_low_health_gate',
    'pass', v_ok
  ));

  v_ok := pg_get_functiondef('public.pvp_attack(uuid,uuid,uuid)'::regprocedure)
      LIKE '%Knockout%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'pvp_attack_knockout_hospital_patch',
    'pass', v_ok
  ));

  UPDATE public.users
  SET health = v_floor, max_health = 400, hospital_until = NULL
  WHERE auth_id = v_auth;

  v_ok := NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE auth_id = v_auth
      AND hospital_until IS NOT NULL
      AND hospital_until > now()
  );
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'health_at_floor_alone_does_not_auto_hospitalize',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'note', 'Floor=15%% max; hospital requires knockout/PvP RNG/dungeon/overdose',
      'health', v_floor
    )
  ));

  DELETE FROM public.inventory WHERE user_id IN (v_auth, v_auth_b);
  DELETE FROM auth.users WHERE id IN (v_auth, v_auth_b);
  DELETE FROM public.users WHERE auth_id IN (v_auth, v_auth_b);

  RETURN jsonb_build_object(
    'verdict', CASE
      WHEN EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_results) elem
        WHERE COALESCE((elem->>'pass')::boolean, false) IS NOT TRUE
      ) THEN 'FAIL'
      ELSE 'PASS'
    END,
    'passed', (
      SELECT count(*) FROM jsonb_array_elements(v_results) elem
      WHERE COALESCE((elem->>'pass')::boolean, false)
    ),
    'failed', (
      SELECT count(*) FROM jsonb_array_elements(v_results) elem
      WHERE COALESCE((elem->>'pass')::boolean, false) IS NOT TRUE
    ),
    'total', jsonb_array_length(v_results),
    'results', v_results
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_smoke_health_system() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_health_system() TO service_role;

COMMIT;
