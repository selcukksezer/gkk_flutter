-- Health system phase E: status metadata, gem heal, regen ETA fields.

BEGIN;

CREATE OR REPLACE FUNCTION public.apply_health_regen(p_user_id uuid DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_health INT;
  v_max INT;
  v_last TIMESTAMPTZ;
  v_elapsed NUMERIC;
  v_gained INT;
  v_new INT;
  v_actual INT;
  v_seconds_per_point NUMERIC;
  v_hospital TIMESTAMPTZ;
  v_prison TIMESTAMPTZ;
  v_class TEXT;
  v_rate_mult NUMERIC := 1.0;
  v_full_seconds NUMERIC;
  v_status TEXT;
  v_seconds_to_full INT;
  v_regen_pct NUMERIC;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadi.');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  PERFORM public.sync_expired_hospital(p_user_id);

  SELECT
    COALESCE(u.health, 0),
    GREATEST(COALESCE(u.max_health, 100), 1),
    COALESCE(u.health_last_updated, now()),
    u.hospital_until,
    u.prison_until,
    COALESCE(u.character_class, '')
  INTO v_health, v_max, v_last, v_hospital, v_prison, v_class
  FROM public.users u
  WHERE u.auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profil bulunamadi.');
  END IF;

  IF (v_hospital IS NOT NULL AND v_hospital > now())
     OR (v_prison IS NOT NULL AND v_prison > now()) THEN
    v_status := CASE
      WHEN v_health < public.player_combat_min_health(v_max) THEN 'critical'
      WHEN v_health < public.player_wounded_health(v_max) THEN 'wounded'
      ELSE 'restricted'
    END;
    RETURN jsonb_build_object(
      'success', true,
      'health', v_health,
      'max_health', v_max,
      'gained', 0,
      'restricted', true,
      'status', v_status,
      'seconds_to_full', 0,
      'regen_per_hour_pct', 0,
      'health_last_updated', v_last
    );
  END IF;

  IF v_class = 'alchemist' THEN
    v_rate_mult := 1.5;
  END IF;

  v_full_seconds := 72000.0 / v_rate_mult;
  v_regen_pct := ROUND(100.0 / (v_full_seconds / 3600.0), 2);

  IF v_health >= v_max THEN
    UPDATE public.users
    SET health_last_updated = now()
    WHERE auth_id = p_user_id
      AND (health_last_updated IS NULL OR health_last_updated < now() - interval '30 seconds');
    RETURN jsonb_build_object(
      'success', true,
      'health', v_health,
      'max_health', v_max,
      'gained', 0,
      'status', 'healthy',
      'seconds_to_full', 0,
      'regen_per_hour_pct', v_regen_pct,
      'health_last_updated', now()
    );
  END IF;

  v_elapsed := EXTRACT(EPOCH FROM (now() - v_last));
  IF v_elapsed IS NULL OR v_elapsed < 0 THEN
    v_elapsed := 0;
  END IF;

  v_gained := FLOOR(v_elapsed * v_max / v_full_seconds)::INT;

  IF v_gained <= 0 THEN
    v_status := CASE
      WHEN v_health < public.player_combat_min_health(v_max) THEN 'critical'
      WHEN v_health < public.player_wounded_health(v_max) THEN 'wounded'
      ELSE 'recovering'
    END;
    v_seconds_to_full := CEIL((v_max - v_health) * v_full_seconds / v_max)::INT;
    RETURN jsonb_build_object(
      'success', true,
      'health', v_health,
      'max_health', v_max,
      'gained', 0,
      'status', v_status,
      'seconds_to_full', v_seconds_to_full,
      'regen_per_hour_pct', v_regen_pct,
      'health_last_updated', v_last
    );
  END IF;

  v_new := LEAST(v_max, v_health + v_gained);
  v_actual := v_new - v_health;
  v_seconds_per_point := v_full_seconds / v_max;

  UPDATE public.users
  SET
    health = v_new,
    health_last_updated = CASE
      WHEN v_new >= v_max THEN now()
      ELSE v_last + make_interval(secs => (v_actual * v_seconds_per_point))
    END,
    updated_at = now()
  WHERE auth_id = p_user_id
  RETURNING health_last_updated INTO v_last;

  v_status := CASE
    WHEN v_new >= v_max THEN 'healthy'
    WHEN v_new < public.player_combat_min_health(v_max) THEN 'critical'
    WHEN v_new < public.player_wounded_health(v_max) THEN 'wounded'
    ELSE 'recovering'
  END;

  v_seconds_to_full := CASE
    WHEN v_new >= v_max THEN 0
    ELSE CEIL((v_max - v_new) * v_full_seconds / v_max)::INT
  END;

  RETURN jsonb_build_object(
    'success', true,
    'health', v_new,
    'max_health', v_max,
    'gained', v_actual,
    'status', v_status,
    'seconds_to_full', v_seconds_to_full,
    'regen_per_hour_pct', v_regen_pct,
    'health_last_updated', v_last
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_health_regen(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.heal_health_with_gems()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_health int;
  v_max int;
  v_gems numeric;
  v_level int;
  v_missing int;
  v_tier_cost int;
  v_gem_cost int;
  v_hospital timestamptz;
  v_prison timestamptz;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum bulunamadi.');
  END IF;

  PERFORM public.sync_expired_hospital(v_user_id);

  SELECT
    COALESCE(health, 0),
    GREATEST(COALESCE(max_health, 100), 1),
    COALESCE(gems, 0),
    COALESCE(level, 1),
    hospital_until,
    prison_until
  INTO v_health, v_max, v_gems, v_level, v_hospital, v_prison
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Oyuncu bulunamadi.');
  END IF;

  IF (v_hospital IS NOT NULL AND v_hospital > now())
     OR (v_prison IS NOT NULL AND v_prison > now()) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Hastane veya hapishane sirasinda elmas ile can yenilenemez.'
    );
  END IF;

  IF v_health >= v_max THEN
    RETURN json_build_object('success', false, 'error', 'Canin zaten dolu.');
  END IF;

  v_missing := v_max - v_health;
  v_tier_cost := CASE
    WHEN v_level < 10 THEN 8
    WHEN v_level < 20 THEN 12
    ELSE 18
  END;
  v_gem_cost := GREATEST(
    1,
    CEIL((v_missing::numeric / v_max::numeric) * v_tier_cost)::int
  );

  IF v_gems < v_gem_cost THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Yetersiz elmas. Gerekli: ' || v_gem_cost
    );
  END IF;

  UPDATE public.users
  SET
    gems = gems - v_gem_cost,
    health = v_max,
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = v_user_id;

  RETURN json_build_object(
    'success', true,
    'cost', v_gem_cost,
    'health', v_max,
    'max_health', v_max,
    'healed', v_missing
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.heal_health_with_gems() TO authenticated;

COMMENT ON FUNCTION public.heal_health_with_gems() IS
  'Instant full health restore with gems when not hospitalized/imprisoned. Cost scales with missing HP and player level.';

COMMIT;
