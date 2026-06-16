-- Fix potion/detox consume: inventory CHECK requires quantity > 0 (cannot UPDATE to 0).
-- Fix get_leaderboard_rank: match auth.uid() via users.auth_id + return rival gap.

BEGIN;

CREATE OR REPLACE FUNCTION public._consume_inventory_row(
  p_row_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_qty INT;
BEGIN
  SELECT quantity INTO v_qty
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND OR v_qty IS NULL OR v_qty <= 0 THEN
    RETURN false;
  END IF;

  IF v_qty = 1 THEN
    DELETE FROM public.inventory
    WHERE row_id = p_row_id AND user_id = p_user_id;
  ELSE
    UPDATE public.inventory
    SET quantity = quantity - 1,
        updated_at = now()
    WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 1;
  END IF;

  RETURN true;
END;
$$;

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
      health = LEAST(max_health, health + v_heal_amount)
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

DROP FUNCTION IF EXISTS public.get_leaderboard_rank(text);

CREATE OR REPLACE FUNCTION public.get_leaderboard_rank(
  p_category text,
  p_timeframe text DEFAULT 'alltime'::text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_id UUID := auth.uid();
  v_rank INT;
  v_value INT;
  v_rival_value INT;
  v_gap INT;
BEGIN
  IF v_auth_id IS NULL THEN
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF p_category = 'gold' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.gold AS metric,
             ROW_NUMBER() OVER (ORDER BY u.gold DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'pvp_rating' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.pvp_rating AS metric,
             ROW_NUMBER() OVER (ORDER BY u.pvp_rating DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'level' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.level AS metric,
             ROW_NUMBER() OVER (ORDER BY u.level DESC, u.xp DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'power' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.power AS metric,
             ROW_NUMBER() OVER (ORDER BY u.power DESC NULLS LAST) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'guild_power' THEN
    WITH ranked AS (
      SELECT g.id AS guild_id, g.xp AS metric,
             ROW_NUMBER() OVER (ORDER BY g.xp DESC) AS rk
      FROM public.guilds g
    ),
    me AS (
      SELECT r.rk, r.metric
      FROM ranked r
      JOIN public.users u ON u.guild_id = r.guild_id
      WHERE u.auth_id = v_auth_id
    )
    SELECT me.rk::INT, me.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = me.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM me;

  ELSE
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF v_rank IS NULL THEN
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF v_rank <= 1 OR v_rival_value IS NULL OR v_value IS NULL THEN
    v_gap := 0;
  ELSE
    v_gap := GREATEST(0, v_rival_value - v_value);
  END IF;

  RETURN json_build_object(
    'rank', v_rank,
    'value', v_value,
    'rival_value', v_rival_value,
    'gap', v_gap
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_potion(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.use_detox(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard_rank(text, text) TO authenticated;

COMMIT;
