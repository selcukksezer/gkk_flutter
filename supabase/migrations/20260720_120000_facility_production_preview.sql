-- Server-authoritative facility production preview + collect seed hardening.

CREATE OR REPLACE FUNCTION public._facility_production_seed(p_started_at timestamptz)
RETURNS bigint
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_text text := COALESCE(p_started_at::text, '');
  v_hash bigint := 0;
  v_i integer;
  v_code integer;
BEGIN
  FOR v_i IN 1..length(v_text) LOOP
    v_code := ascii(substr(v_text, v_i, 1));
    v_hash := mod(((v_hash << 5) - v_hash) + v_code, 2147483647);
  END LOOP;
  RETURN abs(v_hash);
END;
$$;

CREATE OR REPLACE FUNCTION public._facility_production_counts(
  p_started_at timestamptz,
  p_level integer,
  p_facility_type text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_base_rate numeric;
  v_elapsed_seconds numeric;
  v_max_count integer;
  v_base_count integer;
  v_upper_bound integer;
  v_clamped_count integer;
  v_jitter_step integer;
  v_seed bigint;
  v_remaining integer;
BEGIN
  IF p_started_at IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Production not active'
    );
  END IF;

  v_base_rate := public._plan2_facility_base_rate(p_facility_type);
  v_elapsed_seconds := EXTRACT(EPOCH FROM (now() - p_started_at));
  IF v_elapsed_seconds >= 115 THEN
    v_elapsed_seconds := 120;
  END IF;
  v_elapsed_seconds := LEAST(120, GREATEST(0, v_elapsed_seconds));
  v_remaining := GREATEST(0, CEIL(120 - v_elapsed_seconds))::integer;

  v_max_count := ROUND((v_elapsed_seconds / 3600.0) * (v_base_rate * GREATEST(p_level, 1) * 10))::integer;
  v_base_count := v_max_count;
  v_seed := public._facility_production_seed(p_started_at);

  IF v_base_count < 20 THEN
    v_clamped_count := v_base_count;
  ELSE
    v_jitter_step := ((abs(v_seed) % 11)::integer) - 5;
    v_clamped_count := ROUND(v_base_count::numeric * (1 + (v_jitter_step::numeric / 100.0)))::integer;
  END IF;

  v_upper_bound := GREATEST(v_max_count + CEIL(v_max_count::numeric * 0.10)::integer, 0);
  v_clamped_count := LEAST(GREATEST(v_clamped_count, 0), v_upper_bound);

  RETURN jsonb_build_object(
    'success', true,
    'seed', v_seed,
    'elapsed_seconds', v_elapsed_seconds,
    'remaining_seconds', v_remaining,
    'is_ready', v_elapsed_seconds >= 115,
    'max_count', v_max_count,
    'base_count', v_base_count,
    'total_count', v_clamped_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._facility_simulate_rarity_items(
  p_count integer,
  p_seed bigint,
  p_level integer
)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_lcg_mod bigint := 2147483647;
  v_lcg_mult bigint := 16807;
  v_rarity_state bigint;
  v_roll numeric;
  v_total_weight integer;
  v_common_weight integer;
  v_uncommon_weight integer;
  v_rare_weight integer;
  v_epic_weight integer;
  v_legendary_weight integer;
  v_mythic_weight integer;
  v_current_weight integer;
  v_selected_rarity text;
  v_i integer;
  v_quotas jsonb := jsonb_build_object(
    'common', 0, 'uncommon', 0, 'rare', 0, 'epic', 0, 'legendary', 0, 'mythic', 0
  );
  v_items jsonb := '[]'::jsonb;
  v_key text;
  v_val text;
  v_quota integer;
BEGIN
  IF p_count <= 0 THEN
    RETURN jsonb_build_object('items', '[]'::jsonb, 'quotas', v_quotas);
  END IF;

  v_rarity_state := mod(abs(COALESCE(p_seed, 0)) + 13579, v_lcg_mod);
  FOR v_i IN 1..5 LOOP
    v_rarity_state := mod(v_rarity_state * v_lcg_mult, v_lcg_mod);
  END LOOP;

  v_common_weight := public._plan2_rarity_weight(p_level, 'common');
  v_uncommon_weight := public._plan2_rarity_weight(p_level, 'uncommon');
  v_rare_weight := public._plan2_rarity_weight(p_level, 'rare');
  v_epic_weight := public._plan2_rarity_weight(p_level, 'epic');
  v_legendary_weight := public._plan2_rarity_weight(p_level, 'legendary');
  v_mythic_weight := public._plan2_rarity_weight(p_level, 'mythic');
  v_total_weight := v_common_weight + v_uncommon_weight + v_rare_weight + v_epic_weight + v_legendary_weight + v_mythic_weight;

  FOR v_i IN 1..p_count LOOP
    v_rarity_state := mod(v_rarity_state * v_lcg_mult, v_lcg_mod);
    v_roll := (v_rarity_state::numeric / v_lcg_mod::numeric) * v_total_weight;

    v_current_weight := 0;
    v_selected_rarity := 'common';

    v_current_weight := v_current_weight + v_common_weight;
    IF v_roll < v_current_weight AND v_selected_rarity = 'common' THEN v_selected_rarity := 'common'; END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_uncommon_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'uncommon'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_rare_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'rare'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_epic_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'epic'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_legendary_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'legendary'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_selected_rarity := 'mythic';
    END IF;

    IF GREATEST(p_level, 1) < public._plan2_rarity_unlock_level(v_selected_rarity) THEN
      v_selected_rarity := 'common';
    END IF;

    v_quotas := jsonb_set(
      v_quotas,
      ARRAY[v_selected_rarity],
      to_jsonb((COALESCE((v_quotas->>v_selected_rarity)::integer, 0) + 1))
    );
  END LOOP;

  FOR v_key, v_val IN SELECT * FROM jsonb_each_text(v_quotas)
  LOOP
    v_quota := v_val::integer;
    IF v_quota <= 0 THEN
      CONTINUE;
    END IF;
    v_items := v_items || jsonb_build_array(
      jsonb_build_object('rarity', v_key, 'quantity', v_quota)
    );
  END LOOP;

  RETURN jsonb_build_object('items', v_items, 'quotas', v_quotas);
END;
$$;

CREATE OR REPLACE FUNCTION public.preview_facility_production(p_facility_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_facility record;
  v_counts jsonb;
  v_sim jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT *
  INTO v_facility
  FROM public.facilities f
  WHERE f.id = p_facility_id
    AND f.user_id = v_user_id
    AND COALESCE(f.is_active, true) = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Facility not found');
  END IF;

  IF v_facility.production_started_at IS NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'production_started_at', NULL,
      'remaining_seconds', 0,
      'is_ready', false,
      'base_count', 0,
      'total_count', 0,
      'items', '[]'::jsonb
    );
  END IF;

  v_counts := public._facility_production_counts(
    v_facility.production_started_at,
    COALESCE(v_facility.level, 1),
    v_facility.type
  );

  IF COALESCE((v_counts->>'success')::boolean, false) = false THEN
    RETURN v_counts;
  END IF;

  v_sim := public._facility_simulate_rarity_items(
    COALESCE((v_counts->>'total_count')::integer, 0),
    COALESCE((v_counts->>'seed')::bigint, 0),
    COALESCE(v_facility.level, 1)
  );

  RETURN jsonb_build_object(
    'success', true,
    'production_started_at', v_facility.production_started_at,
    'remaining_seconds', COALESCE((v_counts->>'remaining_seconds')::integer, 0),
    'is_ready', COALESCE((v_counts->>'is_ready')::boolean, false),
    'base_count', COALESCE((v_counts->>'base_count')::integer, 0),
    'total_count', COALESCE((v_counts->>'total_count')::integer, 0),
    'items', COALESCE(v_sim->'items', '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.preview_facility_production(uuid) TO authenticated;

-- Collect: ignore client seed/count; derive from server production_started_at.
CREATE OR REPLACE FUNCTION public.collect_facility_resources_v2(
  p_facility_id uuid,
  p_seed bigint,
  p_total_count integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_facility record;
  v_base_rate numeric;
  v_elapsed_seconds numeric;
  v_max_count integer;
  v_base_count integer;
  v_upper_bound integer;
  v_clamped_count integer;
  v_jitter_step integer;
  v_server_seed bigint;
  
  v_lcg_mod bigint := 2147483647;
  v_lcg_mult bigint := 16807;
  v_rarity_state bigint;
  v_roll numeric;
  
  v_total_weight integer;
  v_common_weight integer;
  v_uncommon_weight integer;
  v_rare_weight integer;
  v_epic_weight integer;
  v_legendary_weight integer;
  v_mythic_weight integer;
  v_current_weight integer;
  
  v_selected_rarity text;
  v_effective_rarity text;
  
  v_i integer;
  
  v_quotas jsonb := '{}'::jsonb;
  
  v_item_id text;
  v_common_item_id text;
  v_add_result jsonb;
  v_items_generated jsonb := '[]'::jsonb;
  v_added_total integer := 0;
  v_global_suspicion numeric := 0;
  v_effective_risk numeric := 0;
  v_admission_roll numeric := 0;
  v_admission_occurred boolean := false;
  v_prison_minutes integer := 0;
  
  v_key text;
  v_val text;
  v_quota integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
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

  IF v_facility.production_started_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Production not active');
  END IF;

  v_base_rate := public._plan2_facility_base_rate(v_facility.type);
  
  v_elapsed_seconds := EXTRACT(EPOCH FROM (now() - v_facility.production_started_at));
  IF v_elapsed_seconds >= 115 THEN
    v_elapsed_seconds := 120;
  END IF;
  v_elapsed_seconds := LEAST(120, GREATEST(0, v_elapsed_seconds));
  
  v_max_count := ROUND((v_elapsed_seconds / 3600.0) * (v_base_rate * GREATEST(v_facility.level, 1) * 10))::integer;
  v_base_count := v_max_count;
  v_server_seed := public._facility_production_seed(v_facility.production_started_at);

  IF v_base_count < 20 THEN
    v_clamped_count := v_base_count;
  ELSE
    v_jitter_step := ((abs(v_server_seed) % 11)::integer) - 5;
    v_clamped_count := ROUND(v_base_count::numeric * (1 + (v_jitter_step::numeric / 100.0)))::integer;
  END IF;

  v_upper_bound := GREATEST(v_max_count + CEIL(v_max_count::numeric * 0.10)::integer, 0);
  v_clamped_count := LEAST(GREATEST(v_clamped_count, 0), v_upper_bound);

  IF v_clamped_count <= 0 THEN
    UPDATE public.facilities
    SET production_started_at = NULL, updated_at = now()
    WHERE id = p_facility_id;
    
    RETURN jsonb_build_object(
      'success', true,
      'count', 0,
      'items_generated', '[]'::jsonb,
      'admission_occurred', false
    );
  END IF;

  v_rarity_state := mod(abs(v_server_seed) + 13579, v_lcg_mod);
  
  FOR v_i IN 1..5 LOOP
    v_rarity_state := mod(v_rarity_state * v_lcg_mult, v_lcg_mod);
  END LOOP;
  
  v_common_weight := public._plan2_rarity_weight(v_facility.level, 'common');
  v_uncommon_weight := public._plan2_rarity_weight(v_facility.level, 'uncommon');
  v_rare_weight := public._plan2_rarity_weight(v_facility.level, 'rare');
  v_epic_weight := public._plan2_rarity_weight(v_facility.level, 'epic');
  v_legendary_weight := public._plan2_rarity_weight(v_facility.level, 'legendary');
  v_mythic_weight := public._plan2_rarity_weight(v_facility.level, 'mythic');
  
  v_total_weight := v_common_weight + v_uncommon_weight + v_rare_weight + v_epic_weight + v_legendary_weight + v_mythic_weight;
  
  v_quotas := jsonb_build_object(
    'common', 0, 'uncommon', 0, 'rare', 0, 'epic', 0, 'legendary', 0, 'mythic', 0
  );

  SELECT COALESCE(u.global_suspicion_level, 0)
  INTO v_global_suspicion
  FROM public.users u
  WHERE u.auth_id = v_user_id
  LIMIT 1;

  IF v_global_suspicion IS NULL THEN
    SELECT COALESCE(u.global_suspicion_level, 0)
    INTO v_global_suspicion
    FROM public.users u
    WHERE u.id = v_user_id
    LIMIT 1;
  END IF;

  v_effective_risk := public._effective_suspicion_risk(
    LEAST(100, GREATEST(COALESCE(v_global_suspicion, 0), 0))::integer,
    (SELECT u.character_class FROM public.users u WHERE u.auth_id = v_user_id OR u.id = v_user_id LIMIT 1)
  );
  v_admission_roll := random() * 100.0;
  v_admission_occurred := v_admission_roll < v_effective_risk;

  v_prison_minutes := LEAST(
    720,
    GREATEST(
      30,
      ROUND((20 + (v_effective_risk * 1.5) + (GREATEST(v_facility.level, 1) * 6)))::integer
    )
  );

  IF v_admission_occurred THEN
    UPDATE public.facilities
    SET production_started_at = NULL, updated_at = now()
    WHERE id = p_facility_id;

    UPDATE public.users
    SET prison_until = now() + make_interval(mins => v_prison_minutes),
      global_suspicion_level = 0,
      prison_reason = format('Collected at %s (risk %s, roll %s)', v_facility.type, ROUND(v_effective_risk::numeric,2)::text, ROUND(v_admission_roll::numeric,2)::text)
    WHERE auth_id = v_user_id;

    IF NOT FOUND THEN
      UPDATE public.users
      SET prison_until = now() + make_interval(mins => v_prison_minutes),
        global_suspicion_level = 0,
        prison_reason = format('Collected at %s (risk %s, roll %s)', v_facility.type, ROUND(v_effective_risk::numeric,2)::text, ROUND(v_admission_roll::numeric,2)::text)
      WHERE id = v_user_id;
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'count', 0,
      'items_generated', '[]'::jsonb,
      'admission_occurred', true,
      'admission_risk', ROUND(v_effective_risk::numeric, 2),
      'admission_roll', ROUND(v_admission_roll::numeric, 2),
      'prison_minutes', v_prison_minutes,
      'prison_reason', format('Collected at %s (risk %s, roll %s)', v_facility.type, ROUND(v_effective_risk::numeric,2)::text, ROUND(v_admission_roll::numeric,2)::text)
    );
  END IF;

  FOR v_i IN 1..v_clamped_count LOOP
    v_rarity_state := mod(v_rarity_state * v_lcg_mult, v_lcg_mod);
    v_roll := (v_rarity_state::numeric / v_lcg_mod::numeric) * v_total_weight;
    
    v_current_weight := 0;
    v_selected_rarity := 'common';
    
    v_current_weight := v_current_weight + v_common_weight;
    IF v_roll < v_current_weight AND v_selected_rarity = 'common' THEN v_selected_rarity := 'common'; END IF;
    
    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_uncommon_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'uncommon'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_rare_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'rare'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_epic_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'epic'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_current_weight := v_current_weight + v_legendary_weight;
      IF v_roll < v_current_weight THEN v_selected_rarity := 'legendary'; END IF;
    END IF;

    IF v_selected_rarity = 'common' AND v_roll >= v_current_weight THEN
      v_selected_rarity := 'mythic';
    END IF;

    IF GREATEST(v_facility.level, 1) < public._plan2_rarity_unlock_level(v_selected_rarity) THEN
      v_selected_rarity := 'common';
    END IF;
    
    v_quotas := jsonb_set(
      v_quotas,
      ARRAY[v_selected_rarity],
      to_jsonb((COALESCE((v_quotas->>v_selected_rarity)::integer, 0) + 1))
    );
  END LOOP;

  FOR v_key, v_val IN SELECT * FROM jsonb_each_text(v_quotas)
  LOOP
    v_quota := v_val::integer;
    IF v_quota <= 0 THEN
      CONTINUE;
    END IF;

    v_effective_rarity := v_key;

    v_item_id := format('res_%s_%s', lower(v_facility.type), lower(v_effective_rarity));
    v_common_item_id := format('res_%s_common', lower(v_facility.type));

    IF NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id = v_item_id) THEN
      SELECT i.id
      INTO v_item_id
      FROM public.items i
      WHERE i.facility_type = v_facility.type
        AND lower(i.type) = 'material'
        AND lower(COALESCE(i.material_type, '')) = 'resource'
        AND lower(i.rarity) = lower(v_effective_rarity)
      ORDER BY i.id
      LIMIT 1;
    END IF;

    IF v_item_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id = v_item_id) THEN
      v_item_id := v_common_item_id;
    END IF;

    IF v_item_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.items i WHERE i.id = v_item_id) THEN
      RAISE EXCEPTION 'Missing resource item id for facility %, rarity %', v_facility.type, v_effective_rarity;
    END IF;

    v_add_result := public.add_inventory_item_v2(
      jsonb_build_object(
        'item_id', v_item_id,
        'quantity', v_quota,
        'allow_stack', true
      ),
      NULL
    );

    IF COALESCE((v_add_result->>'success')::boolean, false) = false THEN
      RAISE EXCEPTION '%', COALESCE(v_add_result->>'error', 'Failed to add facility resources to inventory');
    END IF;

    v_added_total := v_added_total + v_quota;

    v_items_generated := v_items_generated || jsonb_build_array(
      jsonb_build_object(
        'item_id', v_item_id,
        'quantity', v_quota,
        'rarity', v_effective_rarity
      )
    );
  END LOOP;

  UPDATE public.facilities
  SET production_started_at = NULL, updated_at = now()
  WHERE id = p_facility_id;

  PERFORM public.grant_monument_facility_collect(v_user_id, COALESCE(v_facility.level, 1), v_added_total);

  RETURN jsonb_build_object(
    'success', true,
    'count', v_added_total,
    'total_count', v_added_total,
    'items_generated', v_items_generated,
    'admission_occurred', false,
    'admission_risk', ROUND(v_effective_risk::numeric, 2),
    'admission_roll', ROUND(v_admission_roll::numeric, 2),
    'prison_minutes', 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.collect_facility_resources_v2(uuid, bigint, integer) TO authenticated;
