-- PLAN_11: wire character_classes.passive_bonuses into live RPCs

CREATE OR REPLACE FUNCTION public._passive_bonus(
  p_class text,
  p_key text,
  p_default numeric DEFAULT 0
)
RETURNS numeric
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (cc.passive_bonuses ->> p_key)::numeric,
    p_default
  )
  FROM public.character_classes cc
  WHERE cc.id = p_class
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public._effective_suspicion_risk(
  p_raw integer,
  p_class text
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN COALESCE(p_class, '') = 'shadow' THEN LEAST(80, GREATEST(0, p_raw))
    ELSE LEAST(100, GREATEST(0, p_raw))
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
  v_class text;
  v_reduction numeric;
BEGIN
  SELECT last_bribe_at, character_class
  INTO v_bribe_ts, v_class
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

  IF COALESCE(v_class, '') = 'shadow' THEN
    v_reduction := public._passive_bonus('shadow', 'facility_suspicion_reduction', 0.30);
    v_risk := floor(v_risk * (1 - v_reduction));
  END IF;

  v_risk := LEAST(100, GREATEST(0, v_risk));

  UPDATE public.users
  SET global_suspicion_level = v_risk,
      updated_at = now()
  WHERE auth_id = p_user_id OR id = p_user_id;

  RETURN v_risk;
END;
$$;

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
  v_reduction numeric;
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

  IF COALESCE(v_player.character_class, '') = 'shadow' THEN
    v_reduction := public._passive_bonus('shadow', 'bribe_cost_reduction', 0.25);
    v_gem_cost := GREATEST(1, CEIL(v_gem_cost * (1 - v_reduction))::integer);
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

CREATE OR REPLACE FUNCTION public.use_detox(
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
  v_tolerance_reduction INT;
  v_addiction_reduction INT;
  v_cooldown_hours INT;
  v_new_tolerance INT;
  v_new_addiction INT;
  v_detox_type TEXT;
  v_detox_mult numeric := 1.0;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR lower(COALESCE(v_item.sub_type, '')) <> 'detox' THEN
    RETURN jsonb_build_object('error', 'Geçersiz detox içeceği');
  END IF;

  IF v_item.id = 'detox_minor' THEN
    v_detox_type := 'minor'; v_tolerance_reduction := 15; v_addiction_reduction := 0; v_cooldown_hours := 4;
  ELSIF v_item.id = 'detox_major' THEN
    v_detox_type := 'major'; v_tolerance_reduction := 35; v_addiction_reduction := 1; v_cooldown_hours := 8;
  ELSIF v_item.id = 'detox_supreme' THEN
    v_detox_type := 'supreme'; v_tolerance_reduction := 60; v_addiction_reduction := 2; v_cooldown_hours := 12;
  ELSIF v_item.id = 'detox_full_cleanse' THEN
    v_detox_type := 'full_cleanse'; v_tolerance_reduction := 100; v_addiction_reduction := 10; v_cooldown_hours := 24;
  ELSE
    v_detox_type := 'minor'; v_tolerance_reduction := 15; v_addiction_reduction := 0; v_cooldown_hours := 4;
  END IF;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_detox_mult := 1 + public._passive_bonus('alchemist', 'detox_effectiveness_bonus', 0.25);
    v_tolerance_reduction := CEIL(v_tolerance_reduction * v_detox_mult)::integer;
    v_addiction_reduction := CEIL(v_addiction_reduction * v_detox_mult)::integer;
  END IF;

  IF v_user.last_detox_used_at IS NOT NULL
     AND v_user.last_detox_used_at + (v_cooldown_hours || ' hours')::interval > now() THEN
    RETURN jsonb_build_object('error', 'Detox cooldown aktif. Kalan süre için bekleyin.');
  END IF;

  v_new_tolerance := GREATEST(COALESCE(v_user.tolerance, 0) - v_tolerance_reduction, 0);
  v_new_addiction := GREATEST(COALESCE(v_user.addiction_level, 0) - v_addiction_reduction, 0);

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  UPDATE public.users
  SET tolerance = v_new_tolerance,
      addiction_level = v_new_addiction,
      last_detox_used_at = now(),
      detox_type_last = v_detox_type
  WHERE auth_id = p_user_id;

  INSERT INTO public.tolerance_log (
    user_id, event_type, item_id,
    tolerance_before, tolerance_after,
    addiction_before, addiction_after
  )
  VALUES (
    p_user_id, 'detox', v_item.id,
    COALESCE(v_user.tolerance, 0), v_new_tolerance,
    COALESCE(v_user.addiction_level, 0), v_new_addiction
  );

  RETURN jsonb_build_object(
    'success', true,
    'detox_type', v_detox_type,
    'new_tolerance', v_new_tolerance,
    'new_addiction', v_new_addiction
  );
END;
$$;

-- collect_facility_resources_v2: shadow effective suspicion cap 80
DO $do$
DECLARE
  v_def TEXT;
  v_old TEXT := E'  v_effective_risk := LEAST(100, GREATEST(COALESCE(v_global_suspicion, 0), 0));';
  v_new TEXT := E'  v_effective_risk := public._effective_suspicion_risk(\n    LEAST(100, GREATEST(COALESCE(v_global_suspicion, 0), 0))::integer,\n    (SELECT u.character_class FROM public.users u WHERE u.auth_id = v_user_id OR u.id = v_user_id LIMIT 1)\n  );';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'collect_facility_resources_v2'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NOT NULL AND position(v_new in v_def) = 0 THEN
    IF position(v_old in v_def) > 0 THEN
      v_def := replace(v_def, v_old, v_new);
      EXECUTE v_def;
    END IF;
  END IF;
END $do$;

-- buy_from_mekan: shadow black_market_risk_reduction on contraband
DO $do$
DECLARE
  v_def TEXT;
  v_old TEXT := E'    UPDATE public.mekans\n    SET suspicion = LEAST(100, suspicion + 5 * p_quantity)\n    WHERE id = p_mekan_id\n    RETURNING suspicion INTO v_mekan.suspicion;\n\n    v_raid_chance := 0.02 + (v_mekan.suspicion::numeric / 100.0) * 0.30;';
  v_new TEXT := E'    UPDATE public.mekans\n    SET suspicion = LEAST(100, suspicion + CASE\n      WHEN COALESCE((SELECT character_class FROM public.users WHERE auth_id = v_mekan.owner_id LIMIT 1), '''') = ''shadow''\n      THEN GREATEST(1, floor(5 * p_quantity * (1 - public._passive_bonus(''shadow'', ''black_market_risk_reduction'', 0.20)))::integer)\n      ELSE 5 * p_quantity\n    END)\n    WHERE id = p_mekan_id\n    RETURNING suspicion INTO v_mekan.suspicion;\n\n    v_raid_chance := (0.02 + (v_mekan.suspicion::numeric / 100.0) * 0.30) * CASE\n      WHEN COALESCE((SELECT character_class FROM public.users WHERE auth_id = v_mekan.owner_id LIMIT 1), '''') = ''shadow''\n      THEN (1 - public._passive_bonus(''shadow'', ''black_market_risk_reduction'', 0.20))\n      ELSE 1\n    END;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'buy_from_mekan'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NOT NULL AND position('black_market_risk_reduction' in v_def) = 0 THEN
    IF position(v_old in v_def) > 0 THEN
      v_def := replace(v_def, v_old, v_new);
      EXECUTE v_def;
    END IF;
  END IF;
END $do$;

-- enter_dungeon: shadow loot_luck_bonus 40%
DO $do$
DECLARE
  v_def TEXT;
  v_old TEXT := E'    IF COALESCE(v_player.character_class, '''') = ''shadow'' THEN\n      v_shadow_loot_bonus := 0.20;\n    END IF;';
  v_new TEXT := E'    IF COALESCE(v_player.character_class, '''') = ''shadow'' THEN\n      v_shadow_loot_bonus := public._passive_bonus(''shadow'', ''loot_luck_bonus'', 0.40);\n    END IF;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'enter_dungeon'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NOT NULL AND position('loot_luck_bonus' in v_def) = 0 THEN
    IF position('v_shadow_loot_bonus := 0.20' in v_def) > 0 THEN
      v_def := replace(v_def, v_old, v_new);
      EXECUTE v_def;
    ELSE
      v_def := replace(
        v_def,
        E'      v_shadow_loot_bonus := 0.20;',
        E'      v_shadow_loot_bonus := public._passive_bonus(''shadow'', ''loot_luck_bonus'', 0.40);'
      );
      EXECUTE v_def;
    END IF;
  END IF;
END $do$;

GRANT EXECUTE ON FUNCTION public._passive_bonus(text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public._effective_suspicion_risk(integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.use_detox(UUID, UUID) TO authenticated;
