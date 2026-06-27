BEGIN;

-- Server-authoritative unlock meta (matches Flutter hub constants).
CREATE OR REPLACE FUNCTION public._plan2_facility_unlock_level(p_type text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_type
    WHEN 'mining' THEN 1
    WHEN 'quarry' THEN 2
    WHEN 'lumber_mill' THEN 3
    WHEN 'clay_pit' THEN 4
    WHEN 'sand_quarry' THEN 5
    WHEN 'farming' THEN 6
    WHEN 'herb_garden' THEN 7
    WHEN 'ranch' THEN 8
    WHEN 'apiary' THEN 9
    WHEN 'mushroom_farm' THEN 10
    WHEN 'rune_mine' THEN 15
    WHEN 'holy_spring' THEN 20
    WHEN 'shadow_pit' THEN 25
    WHEN 'elemental_forge' THEN 30
    WHEN 'time_well' THEN 40
    ELSE 99
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public._plan2_facility_unlock_cost(p_type text)
RETURNS bigint
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_type
    WHEN 'mining' THEN 50000
    WHEN 'quarry' THEN 80000
    WHEN 'lumber_mill' THEN 100000
    WHEN 'clay_pit' THEN 120000
    WHEN 'sand_quarry' THEN 150000
    WHEN 'farming' THEN 200000
    WHEN 'herb_garden' THEN 250000
    WHEN 'ranch' THEN 300000
    WHEN 'apiary' THEN 350000
    WHEN 'mushroom_farm' THEN 400000
    WHEN 'rune_mine' THEN 500000
    WHEN 'holy_spring' THEN 600000
    WHEN 'shadow_pit' THEN 700000
    WHEN 'elemental_forge' THEN 800000
    WHEN 'time_well' THEN 1000000
    ELSE 999999999
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public._plan2_facility_upgrade_cost(p_type text, p_current_level integer)
RETURNS bigint
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_base bigint;
  v_mult numeric;
  v_level integer := GREATEST(1, LEAST(COALESCE(p_current_level, 1), 10));
  v_cost numeric;
  v_i integer;
BEGIN
  SELECT base_cost, multiplier
  INTO v_base, v_mult
  FROM (VALUES
    ('mining', 100000::bigint, 1.5::numeric),
    ('quarry', 120000, 1.5),
    ('lumber_mill', 150000, 1.5),
    ('clay_pit', 180000, 1.5),
    ('sand_quarry', 200000, 1.5),
    ('farming', 250000, 1.5),
    ('herb_garden', 300000, 1.5),
    ('ranch', 350000, 1.5),
    ('apiary', 400000, 1.5),
    ('mushroom_farm', 450000, 1.5),
    ('rune_mine', 500000, 1.7),
    ('holy_spring', 600000, 1.7),
    ('shadow_pit', 700000, 1.7),
    ('elemental_forge', 800000, 1.7),
    ('time_well', 1000000, 1.7)
  ) AS t(facility_type, base_cost, multiplier)
  WHERE facility_type = p_type;

  IF v_base IS NULL THEN
    RETURN 0;
  END IF;

  v_cost := v_base;
  FOR v_i IN 2..v_level LOOP
    v_cost := v_cost * v_mult;
  END LOOP;

  RETURN FLOOR(v_cost)::bigint;
END;
$$;

CREATE OR REPLACE FUNCTION public._recompute_global_suspicion(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bribe_ts timestamptz;
  v_active_count integer := 0;
  v_level_sum integer := 0;
  v_risk integer;
BEGIN
  SELECT last_bribe_at INTO v_bribe_ts
  FROM public.users
  WHERE auth_id = p_user_id OR id = p_user_id
  LIMIT 1;

  SELECT
    COUNT(*)::integer,
    COALESCE(SUM(level), 0)::integer
  INTO v_active_count, v_level_sum
  FROM public.facilities f
  WHERE f.user_id = p_user_id
    AND COALESCE(f.is_active, true) = true
    AND f.production_started_at IS NOT NULL
    AND (v_bribe_ts IS NULL OR f.production_started_at >= v_bribe_ts);

  v_risk := (v_active_count * 5) + (v_level_sum / 2);
  v_risk := LEAST(100, GREATEST(0, v_risk));

  UPDATE public.users
  SET global_suspicion_level = v_risk,
      updated_at = now()
  WHERE auth_id = p_user_id OR id = p_user_id;

  RETURN v_risk;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_player_facilities_with_queue()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_rows jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', f.id,
      'facility_type', f.type,
      'type', f.type,
      'level', COALESCE(f.level, 1),
      'suspicion', COALESCE(f.suspicion_level, 0),
      'is_active', COALESCE(f.is_active, true),
      'production_started_at', f.production_started_at,
      'facility_queue', '[]'::jsonb
    )
    ORDER BY f.created_at NULLS LAST, f.type
  ), '[]'::jsonb)
  INTO v_rows
  FROM public.facilities f
  WHERE f.user_id = v_user_id
    AND COALESCE(f.is_active, true) = true;

  RETURN jsonb_build_object('success', true, 'data', v_rows);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_player_facilities_with_queue() TO authenticated;

CREATE OR REPLACE FUNCTION public.unlock_facility(p_type text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_player record;
  v_required_level integer;
  v_required_cost bigint;
  v_existing uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_required_level := public._plan2_facility_unlock_level(p_type);
  v_required_cost := public._plan2_facility_unlock_cost(p_type);

  SELECT * INTO v_player
  FROM public.users u
  WHERE u.auth_id = v_user_id OR u.id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player not found');
  END IF;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cezaevindeyken tesis acilamaz');
  END IF;

  IF COALESCE(v_player.level, 1) < v_required_level THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seviye yetersiz');
  END IF;

  IF COALESCE(v_player.gold, 0) < v_required_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altin yetersiz');
  END IF;

  SELECT f.id INTO v_existing
  FROM public.facilities f
  WHERE f.user_id = v_user_id
    AND f.type = p_type
    AND COALESCE(f.is_active, true) = true
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tesis zaten acik');
  END IF;

  UPDATE public.users
  SET gold = gold - v_required_cost,
      updated_at = now()
  WHERE (auth_id = v_user_id OR id = v_user_id)
    AND gold >= v_required_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altin yetersiz');
  END IF;

  INSERT INTO public.facilities (user_id, type, level, is_active, created_at, updated_at)
  VALUES (v_user_id, p_type, 1, true, now(), now());

  RETURN jsonb_build_object('success', true, 'facility_type', p_type);
END;
$$;

GRANT EXECUTE ON FUNCTION public.unlock_facility(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.upgrade_facility(p_facility_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_facility record;
  v_cost bigint;
  v_player record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_facility
  FROM public.facilities
  WHERE id = p_facility_id
    AND user_id = v_user_id
    AND COALESCE(is_active, true) = true
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
  END IF;

  IF v_facility.production_started_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Uretim varken yukseltilemez');
  END IF;

  IF COALESCE(v_facility.level, 1) >= 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Maksimum seviye');
  END IF;

  v_cost := public._plan2_facility_upgrade_cost(v_facility.type, COALESCE(v_facility.level, 1));

  SELECT * INTO v_player
  FROM public.users u
  WHERE u.auth_id = v_user_id OR u.id = v_user_id
  FOR UPDATE;

  IF COALESCE(v_player.gold, 0) < v_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altin yetersiz');
  END IF;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cezaevindeyken yukseltilemez');
  END IF;

  UPDATE public.users
  SET gold = gold - v_cost,
      updated_at = now()
  WHERE (auth_id = v_user_id OR id = v_user_id)
    AND gold >= v_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altin yetersiz');
  END IF;

  UPDATE public.facilities
  SET level = COALESCE(level, 1) + 1,
      updated_at = now()
  WHERE id = p_facility_id;

  RETURN jsonb_build_object('success', true, 'facility_id', p_facility_id, 'new_level', COALESCE(v_facility.level, 1) + 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.upgrade_facility(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.bribe_officials(p_facility_type text, p_amount_gems integer DEFAULT 5)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_player record;
  v_facility record;
  v_gem_cost integer := GREATEST(COALESCE(p_amount_gems, 5), 5);
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_player
  FROM public.users u
  WHERE u.auth_id = v_user_id OR u.id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player not found');
  END IF;

  IF COALESCE(v_player.global_suspicion_level, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Suphe 0 iken rusvet verilemez');
  END IF;

  IF COALESCE(v_player.gems, 0) < v_gem_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gem yetersiz');
  END IF;

  SELECT * INTO v_facility
  FROM public.facilities
  WHERE user_id = v_user_id
    AND type = p_facility_type
    AND COALESCE(is_active, true) = true
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tesis bulunamadi');
  END IF;

  UPDATE public.users
  SET gems = gems - v_gem_cost,
      global_suspicion_level = GREATEST(0, COALESCE(global_suspicion_level, 0) - 15),
      last_bribe_at = now(),
      updated_at = now()
  WHERE (auth_id = v_user_id OR id = v_user_id)
    AND gems >= v_gem_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gem yetersiz');
  END IF;

  UPDATE public.facilities
  SET suspicion_level = GREATEST(0, COALESCE(suspicion_level, 0) - 20),
      updated_at = now()
  WHERE id = v_facility.id;

  PERFORM public._recompute_global_suspicion(v_user_id);

  RETURN jsonb_build_object('success', true, 'gems_spent', v_gem_cost);
END;
$$;

GRANT EXECUTE ON FUNCTION public.bribe_officials(text, integer) TO authenticated;

-- Client can no longer push arbitrary suspicion; server recomputes only.
CREATE OR REPLACE FUNCTION public.update_global_suspicion_level(p_global_suspicion integer DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_risk integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_risk := public._recompute_global_suspicion(v_user_id);
  RETURN jsonb_build_object('success', true, 'global_suspicion_level', v_risk);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_global_suspicion_level(integer) TO authenticated;

-- Harden production start: prison + energy gate.
CREATE OR REPLACE FUNCTION public.start_facility_production(p_facility_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_facility record;
  v_player record;
  v_energy_cost integer := 50;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_player
  FROM public.users u
  WHERE u.auth_id = v_user_id OR u.id = v_user_id
  FOR UPDATE;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cezaevindeyken uretim baslatilamaz');
  END IF;

  IF COALESCE(v_player.energy, 0) < v_energy_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Enerji yetersiz');
  END IF;

  SELECT *
  INTO v_facility
  FROM public.facilities
  WHERE id = p_facility_id
    AND user_id = v_user_id
    AND COALESCE(is_active, true) = true
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
  END IF;

  IF v_facility.production_started_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Production already active');
  END IF;

  UPDATE public.users
  SET energy = energy - v_energy_cost,
      updated_at = now()
  WHERE (auth_id = v_user_id OR id = v_user_id)
    AND energy >= v_energy_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Enerji yetersiz');
  END IF;

  UPDATE public.facilities
  SET production_started_at = now(),
      updated_at = now()
  WHERE id = p_facility_id;

  PERFORM public._recompute_global_suspicion(v_user_id);

  RETURN jsonb_build_object('success', true, 'facility_id', p_facility_id, 'production_started_at', now());
END;
$$;

-- 1000-bot facilities stress smoke (QA mode only).
CREATE OR REPLACE FUNCTION public.qa_smoke_facilities_stress(p_bot_count integer DEFAULT 1000)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bot record;
  v_idx integer := 0;
  v_unlock_ok integer := 0;
  v_unlock_fail integer := 0;
  v_fetch_ok integer := 0;
  v_fetch_fail integer := 0;
  v_double_unlock_blocked integer := 0;
  v_result jsonb;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  FOR v_bot IN
    SELECT u.auth_id, u.username, u.level, u.gold
    FROM public.users u
    WHERE u.username LIKE 'qa_bot_%'
    ORDER BY u.username
    LIMIT GREATEST(COALESCE(p_bot_count, 1000), 1)
  LOOP
    v_idx := v_idx + 1;

    BEGIN
      PERFORM set_config('request.jwt.claim.sub', v_bot.auth_id::text, true);
      v_result := public.get_player_facilities_with_queue();
      IF COALESCE((v_result->>'success')::boolean, false) THEN
        v_fetch_ok := v_fetch_ok + 1;
      ELSE
        v_fetch_fail := v_fetch_fail + 1;
      END IF;

      IF COALESCE(v_bot.gold, 0) >= 50000 AND COALESCE(v_bot.level, 1) >= 1 THEN
        v_result := public.unlock_facility('mining');
        IF COALESCE((v_result->>'success')::boolean, false) THEN
          v_unlock_ok := v_unlock_ok + 1;
        ELSE
          v_unlock_fail := v_unlock_fail + 1;
        END IF;

        v_result := public.unlock_facility('mining');
        IF COALESCE((v_result->>'success')::boolean, false) = false THEN
          v_double_unlock_blocked := v_double_unlock_blocked + 1;
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fetch_fail := v_fetch_fail + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', v_fetch_fail = 0 AND v_double_unlock_blocked >= v_unlock_ok,
    'bots_tested', v_idx,
    'fetch_ok', v_fetch_ok,
    'fetch_fail', v_fetch_fail,
    'unlock_ok', v_unlock_ok,
    'unlock_fail', v_unlock_fail,
    'double_unlock_blocked', v_double_unlock_blocked,
    'verdict', CASE
      WHEN v_idx = 0 THEN 'FAIL: no qa bots found — run qa_seed_bots(1000) first'
      WHEN v_fetch_fail > 0 THEN 'FAIL: fetch RPC errors under load'
      WHEN v_double_unlock_blocked < v_unlock_ok THEN 'FAIL: duplicate unlock not blocked'
      ELSE 'PASS: facilities RPCs stable under ' || v_idx || ' bots'
    END
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.qa_smoke_facilities_stress(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_smoke_facilities_stress(integer) TO service_role;

COMMIT;
