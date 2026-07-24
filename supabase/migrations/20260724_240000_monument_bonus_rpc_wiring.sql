-- Wire PLAN_10 guild monument milestone bonuses into gameplay RPCs.
-- Canonical effects: mdplans and prompts/PLAN_10_GUILD_MONUMENT.md + get_guild_monument_bonuses.

BEGIN;

-- ── Monument bonus helpers ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._monument_xp_bonus_pct(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (
    (CASE WHEN p_level >= 5 THEN 5 ELSE 0 END)
    + (CASE WHEN p_level >= 50 THEN 5 ELSE 0 END)
    + (CASE WHEN p_level >= 75 THEN 8 ELSE 0 END)
    + (p_level / 5) * 0.2
  )::NUMERIC;
$$;

CREATE OR REPLACE FUNCTION public._monument_gold_bonus_pct(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (
    (CASE WHEN p_level >= 10 THEN 3 ELSE 0 END)
    + (p_level / 5) * 0.2
  )::NUMERIC;
$$;

CREATE OR REPLACE FUNCTION public._monument_xp_multiplier(p_auth_id UUID)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 1 + public._monument_xp_bonus_pct(public._monument_level_for_auth(p_auth_id)) / 100.0;
$$;

CREATE OR REPLACE FUNCTION public._monument_gold_multiplier(p_auth_id UUID)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 1 + public._monument_gold_bonus_pct(public._monument_level_for_auth(p_auth_id)) / 100.0;
$$;

CREATE OR REPLACE FUNCTION public._monument_enhancement_gold_discount_pct(p_level INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_level >= 90 THEN 5
    WHEN p_level >= 45 THEN 3
    ELSE 0
  END;
$$;

CREATE OR REPLACE FUNCTION public._monument_enhancement_gold_multiplier(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 1 - public._monument_enhancement_gold_discount_pct(p_level) / 100.0;
$$;

CREATE OR REPLACE FUNCTION public._monument_stat_bonus_pct(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (
    (p_level / 5) * 0.5
    + (CASE WHEN p_level >= 95 THEN 3 ELSE 0 END)
    + (CASE WHEN p_level >= 100 THEN 5 ELSE 0 END)
  )::NUMERIC;
$$;

CREATE OR REPLACE FUNCTION public._monument_stat_multiplier(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 1 + public._monument_stat_bonus_pct(p_level) / 100.0;
$$;

CREATE OR REPLACE FUNCTION public._monument_reputation_multiplier(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 70 THEN 1.05 ELSE 1.0 END;
$$;

CREATE OR REPLACE FUNCTION public._monument_reputation_amount(p_auth_id UUID, p_base INT)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT GREATEST(
    0,
    floor(p_base * public._monument_reputation_multiplier(public._monument_level_for_auth(p_auth_id)))
  )::INT;
$$;

CREATE OR REPLACE FUNCTION public._monument_energy_cost_multiplier(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 85 THEN 0.98 ELSE 1.0 END;
$$;

CREATE OR REPLACE FUNCTION public._monument_craft_success_bonus(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 35 THEN 0.03 ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public._monument_pvp_gold_loss_multiplier(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 40 THEN 0.90 ELSE 1.0 END;
$$;

CREATE OR REPLACE FUNCTION public._monument_facility_speed_multiplier(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 25 THEN 1.05 ELSE 1.0 END;
$$;

CREATE OR REPLACE FUNCTION public._monument_loot_luck_bonus(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 30 THEN 10 ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public._monument_boss_success_bonus(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 55 THEN 0.05 ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public._monument_hospital_reduction_multiplier(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 60 THEN 0.90 ELSE 1.0 END;
$$;

CREATE OR REPLACE FUNCTION public._monument_enhancement_destroy_reduction(p_level INT)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE WHEN p_level >= 65 THEN 0.02 ELSE 0 END;
$$;

-- Align preview RPC with helper fns (L90 = 5% total, not cumulative 8%).
CREATE OR REPLACE FUNCTION public.get_guild_monument_bonuses(p_auth_id UUID DEFAULT auth.uid())
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_level INT;
BEGIN
  v_level := public._monument_level_for_auth(p_auth_id);
  RETURN jsonb_build_object(
    'monument_level', v_level,
    'xp_bonus_pct', public._monument_xp_bonus_pct(v_level),
    'gold_bonus_pct', public._monument_gold_bonus_pct(v_level),
    'max_energy_bonus', public._monument_energy_bonus(v_level),
    'overdose_reduction_pct', CASE WHEN v_level >= 20 THEN 10 ELSE 0 END,
    'facility_speed_pct', CASE WHEN v_level >= 25 THEN 5 ELSE 0 END,
    'loot_luck_bonus', public._monument_loot_luck_bonus(v_level),
    'craft_success_pct', CASE WHEN v_level >= 35 THEN 3 ELSE 0 END,
    'pvp_gold_loss_reduction_pct', CASE WHEN v_level >= 40 THEN 10 ELSE 0 END,
    'enhancement_gold_reduction_pct', public._monument_enhancement_gold_discount_pct(v_level),
    'boss_success_pct', CASE WHEN v_level >= 55 THEN 5 ELSE 0 END,
    'hospital_reduction_pct', CASE WHEN v_level >= 60 THEN 10 ELSE 0 END,
    'enhancement_destroy_reduction_pct', CASE WHEN v_level >= 65 THEN 2 ELSE 0 END,
    'reputation_bonus_pct', CASE WHEN v_level >= 70 THEN 5 ELSE 0 END,
    'dungeon_energy_reduction_pct', CASE WHEN v_level >= 85 THEN 2 ELSE 0 END,
    'stat_bonus_pct', public._monument_stat_bonus_pct(v_level)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_monument_bonuses(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_enhancement_config()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_player RECORD;
  v_monument_level INT := 0;
  v_gold_discount_pct INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('error', 'unauthorized');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = auth.uid();

  IF v_player.guild_id IS NOT NULL THEN
    SELECT monument_level
    INTO v_monument_level
    FROM public.guilds
    WHERE id = v_player.guild_id;
  END IF;

  v_gold_discount_pct := public._monument_enhancement_gold_discount_pct(COALESCE(v_monument_level, 0));

  RETURN jsonb_build_object(
    'base_costs', jsonb_build_array(
      100000, 200000, 300000, 500000, 1500000, 3500000,
      7500000, 15000000, 50000000, 200000000, 1000000000
    ),
    'success_rates', jsonb_build_array(100, 100, 100, 100, 70, 60, 50, 35, 20, 10, 3),
    'destroy_rates', jsonb_build_array(0, 0, 0, 0, 0, 0, 100, 100, 100, 100, 100),
    'rarity_multipliers', jsonb_build_object(
      'common', 1.0,
      'uncommon', 1.5,
      'rare', 2.5,
      'epic', 4.0,
      'legendary', 7.0,
      'mythic', 12.0
    ),
    'gold_discount_pct', v_gold_discount_pct,
    'monument_level', COALESCE(v_monument_level, 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_enhancement_config() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_enhancement_config() TO authenticated;

CREATE OR REPLACE FUNCTION public.calculate_user_total_power(p_user_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
  v_equipment_power NUMERIC := 0;
  v_total_power NUMERIC := 0;
  v_monument_level INT := 0;
  v_stat_mult NUMERIC := 1.0;
BEGIN
  SELECT COALESCE(SUM(public.calculate_item_power(i.item_id, COALESCE(i.enhancement_level, 0))), 0)
  INTO v_equipment_power
  FROM public.inventory i
  WHERE i.user_id = p_user_id AND i.is_equipped = true;

  SELECT level, reputation, attack, defense, health, luck, guild_id
  INTO v_user
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level
    FROM public.guilds
    WHERE id = v_user.guild_id;
  END IF;

  v_stat_mult := public._monument_stat_multiplier(COALESCE(v_monument_level, 0));

  v_total_power := (v_equipment_power * v_stat_mult)
    + (COALESCE(v_user.level, 1) * 500)
    + (COALESCE(v_user.reputation, 0) * 0.1)
    + (COALESCE(v_user.luck, 0) * 50 * v_stat_mult);

  RETURN v_total_power;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_crafted_item(p_queue_item_id uuid)
RETURNS TABLE (
  processed boolean,
  message text,
  success boolean,
  success_rate double precision,
  roll double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_queue public.craft_queue%ROWTYPE;
  v_recipe public.crafting_recipes%ROWTYPE;
  v_success_rate double precision;
  v_roll double precision;
  v_monument_level INT := 0;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_queue
  FROM public.craft_queue
  WHERE id = p_queue_item_id AND user_id = v_user_id
  FOR UPDATE;

  IF v_queue.id IS NULL THEN
    RETURN QUERY SELECT false, 'Queue item not found or unauthorized'::text, NULL::boolean, NULL::double precision, NULL::double precision;
    RETURN;
  END IF;

  IF v_queue.failed THEN
    RETURN QUERY SELECT true, 'Already failed'::text, false, NULL::double precision, NULL::double precision;
    RETURN;
  END IF;

  IF v_queue.is_completed THEN
    RETURN QUERY SELECT true, 'Already completed'::text, true, NULL::double precision, NULL::double precision;
    RETURN;
  END IF;

  IF v_queue.completes_at > now() THEN
    RETURN QUERY SELECT false, 'Not ready'::text, NULL::boolean, NULL::double precision, NULL::double precision;
    RETURN;
  END IF;

  SELECT monument_level INTO v_monument_level
  FROM public.users u
  JOIN public.guilds g ON g.id = u.guild_id
  WHERE u.auth_id = v_user_id;

  SELECT * INTO v_recipe FROM public.crafting_recipes WHERE id = v_queue.recipe_id;

  v_success_rate := COALESCE(v_recipe.success_rate, 1.0);
  IF v_success_rate > 1 THEN
    v_success_rate := v_success_rate / 100.0;
  END IF;

  IF COALESCE((SELECT character_class FROM public.users WHERE auth_id = v_user_id), '') = 'alchemist' THEN
    v_success_rate := v_success_rate + 0.15;
  END IF;

  v_success_rate := v_success_rate + public._monument_craft_success_bonus(COALESCE(v_monument_level, 0));
  v_success_rate := LEAST(v_success_rate, 1.0);

  v_roll := random();

  IF v_roll > v_success_rate THEN
    UPDATE public.craft_queue SET failed = true WHERE id = p_queue_item_id;
    RETURN QUERY SELECT true, 'Üretim başarısız'::text, false, v_success_rate, v_roll;
    RETURN;
  END IF;

  UPDATE public.craft_queue SET is_completed = true WHERE id = p_queue_item_id;
  RETURN QUERY SELECT true, 'Üretim tamamlandı'::text, true, v_success_rate, v_roll;
  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION public.finalize_crafted_item(uuid) TO authenticated;

-- ── Patch enter_dungeon(uuid,text) ────────────────────────────────────────────
DO $patch$
DECLARE
  v_def text;
  v_args constant text := 'p_player_id uuid, p_dungeon_id text';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'enter_dungeon'
    AND pg_get_function_identity_arguments(p.oid) = v_args;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon(uuid,text) not found for monument patch';
  END IF;

  IF position('[GKK_MONUMENT_BEGIN]' in v_def) = 0 THEN
    IF position('v_siege_rep_buff    NUMERIC := 0;' in v_def) > 0
       AND position('v_monument_level' in v_def) = 0 THEN
      v_def := replace(
        v_def,
        E'  v_siege_rep_buff    NUMERIC := 0;',
        E'  v_siege_rep_buff    NUMERIC := 0;\n  v_monument_level    INT := 0;\n  v_energy_cost       INT := 0;'
      );
    END IF;

    IF position('player_not_found' in v_def) > 0
       AND position('v_monument_level := public._monument_level_for_auth' in v_def) = 0 THEN
      v_def := replace(
        v_def,
        E'  IF NOT FOUND THEN\n    RETURN jsonb_build_object(''error'', ''player_not_found'');\n  END IF;\n',
        E'  IF NOT FOUND THEN\n    RETURN jsonb_build_object(''error'', ''player_not_found'');\n  END IF;\n\n  v_monument_level := public._monument_level_for_auth(p_player_id);\n  v_energy_cost := GREATEST(1, floor(v_dungeon.energy_cost * public._monument_energy_cost_multiplier(v_monument_level))::INT);\n'
      );
    END IF;

    IF position('insufficient_energy' in v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'  IF v_player.energy < v_dungeon.energy_cost THEN\n    RETURN jsonb_build_object(''error'', ''insufficient_energy'');\n  END IF;\n',
        E'  IF v_player.energy < v_energy_cost THEN\n    RETURN jsonb_build_object(''error'', ''insufficient_energy'');\n  END IF;\n'
      );
    END IF;

    IF position('v_success_rate := v_success_rate + 0.05;' in v_def) > 0
       AND position('_monument_boss_success_bonus' in v_def) = 0 THEN
      v_def := replace(
        v_def,
        E'    IF COALESCE(v_player.character_class, '''') = ''warrior'' THEN\n      v_success_rate := v_success_rate + 0.05;\n    END IF;\n    v_success_rate := LEAST(0.95, GREATEST(0.05, v_success_rate));',
        E'    IF COALESCE(v_player.character_class, '''') = ''warrior'' THEN\n      v_success_rate := v_success_rate + 0.05;\n    END IF;\n    IF v_dungeon.is_boss THEN\n      v_success_rate := v_success_rate + public._monument_boss_success_bonus(v_monument_level);\n    END IF;\n    v_success_rate := LEAST(0.95, GREATEST(0.05, v_success_rate));'
      );
    END IF;

    IF position('v_luck_for_loot := COALESCE(v_player.luck, 0);' in v_def) > 0
       AND position('_monument_loot_luck_bonus' in v_def) = 0 THEN
      v_def := replace(
        v_def,
        E'    v_luck_for_loot := COALESCE(v_player.luck, 0);',
        E'    v_luck_for_loot := COALESCE(v_player.luck, 0) + public._monument_loot_luck_bonus(v_monument_level);'
      );
    END IF;

    IF position('_monument_level_for_auth(p_player_id) >= 5' in v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'    IF public._monument_level_for_auth(p_player_id) >= 5 THEN\n      v_xp := floor(v_xp * (1.05 + (public._monument_level_for_auth(p_player_id) / 5) * 0.002));\n    END IF;\n    IF public._monument_level_for_auth(p_player_id) >= 10 THEN\n      v_gold := floor(v_gold * (1.03 + (public._monument_level_for_auth(p_player_id) / 5) * 0.002));\n    END IF;',
        E'    -- [GKK_MONUMENT_BEGIN]\n    v_xp := floor(v_xp * public._monument_xp_multiplier(p_player_id));\n    v_gold := floor(v_gold * public._monument_gold_multiplier(p_player_id));\n    -- [GKK_MONUMENT_END]'
      );
    ELSIF position('[GKK_MONUMENT_BEGIN]' in v_def) = 0
      AND position('v_gold := floor(v_gold * v_reward_mult);' in v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'    v_gold := floor(v_gold * v_reward_mult);\n    v_xp   := floor(v_xp   * v_reward_mult);',
        E'    v_gold := floor(v_gold * v_reward_mult);\n    v_xp   := floor(v_xp   * v_reward_mult);\n    -- [GKK_MONUMENT_BEGIN]\n    v_xp := floor(v_xp * public._monument_xp_multiplier(p_player_id));\n    v_gold := floor(v_gold * public._monument_gold_multiplier(p_player_id));\n    -- [GKK_MONUMENT_END]'
      );
    END IF;

    IF position('v_hospital_minutes := floor(v_hospital_minutes * 0.80);' in v_def) > 0
       AND position('_monument_hospital_reduction_multiplier' in v_def) = 0 THEN
      v_def := replace(
        v_def,
        E'      IF COALESCE(v_player.character_class, '''') = ''warrior'' THEN\n        v_hospital_minutes := floor(v_hospital_minutes * 0.80);\n      END IF;\n',
        E'      IF COALESCE(v_player.character_class, '''') = ''warrior'' THEN\n        v_hospital_minutes := floor(v_hospital_minutes * 0.80);\n      END IF;\n      v_hospital_minutes := floor(v_hospital_minutes * public._monument_hospital_reduction_multiplier(v_monument_level));\n'
      );
    END IF;

    IF position('energy = energy - v_dungeon.energy_cost' in v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'  SET energy = energy - v_dungeon.energy_cost,\n      gold   = gold   + v_gold,\n      xp     = xp     + v_xp\n  WHERE auth_id = p_player_id AND energy >= v_dungeon.energy_cost;',
        E'  SET energy = energy - v_energy_cost,\n      gold   = gold   + v_gold,\n      xp     = xp     + v_xp\n  WHERE auth_id = p_player_id AND energy >= v_energy_cost;'
      );
    END IF;

    IF position('v_siege_rep_gain := GREATEST(1, floor(20 * COALESCE((v_siege->>''rep_bonus_pct'')::numeric, 0.15) * (1 + v_siege_rep_buff / 100.0)));' in v_def) > 0
       AND position('_monument_reputation_amount(p_player_id' in v_def) = 0 THEN
      v_def := replace(
        v_def,
        E'      v_siege_rep_gain := GREATEST(1, floor(20 * COALESCE((v_siege->>''rep_bonus_pct'')::numeric, 0.15) * (1 + v_siege_rep_buff / 100.0)));',
        E'      v_siege_rep_gain := public._monument_reputation_amount(\n        p_player_id,\n        GREATEST(1, floor(20 * COALESCE((v_siege->>''rep_bonus_pct'')::numeric, 0.15) * (1 + v_siege_rep_buff / 100.0)))::INT\n      );'
      );
    END IF;
  END IF;

  EXECUTE v_def;
END;
$patch$;

-- ── Patch enhance_item ────────────────────────────────────────────────────────
DO $patch$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'enhance_item'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enhance_item not found for monument patch';
  END IF;

  IF position('[GKK_MONUMENT_ENHANCE_BEGIN]' in v_def) = 0 THEN
    IF position('v_gold_cost := floor(v_base_cost * v_rarity_mult);' in v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'  v_gold_cost := floor(v_base_cost * v_rarity_mult);',
        E'  v_gold_cost := floor(v_base_cost * v_rarity_mult);\n  -- [GKK_MONUMENT_ENHANCE_BEGIN]\n  v_gold_cost := floor(v_gold_cost * public._monument_enhancement_gold_multiplier(public._monument_level_for_auth(p_player_id)));\n  -- [GKK_MONUMENT_ENHANCE_END]'
      );
    END IF;

    IF position('v_destroy_rate := GREATEST(0, v_destroy_rate);' in v_def) > 0
       AND position('_monument_enhancement_destroy_reduction' in v_def) = 0 THEN
      v_def := replace(
        v_def,
        E'  v_destroy_rate := GREATEST(0, v_destroy_rate);',
        E'  IF v_item.enhancement_level >= 6 THEN\n    v_destroy_rate := GREATEST(0, v_destroy_rate - public._monument_enhancement_destroy_reduction(public._monument_level_for_auth(p_player_id)));\n  END IF;\n  v_destroy_rate := GREATEST(0, v_destroy_rate);'
      );
    END IF;
  END IF;

  EXECUTE v_def;
END;
$patch$;

-- ── Patch pvp_attack (L40 gold shield + L70 rep) ─────────────────────────────
DO $patch$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'pvp_attack'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'pvp_attack not found; skipping monument patch';
    RETURN;
  END IF;

  IF position('_monument_pvp_gold_loss_multiplier' in v_def) = 0 THEN
    v_def := regexp_replace(
      v_def,
      'v_gold_stolen := GREATEST\(\s*LEAST\(\(v_defender\.gold \* v_steal_rate\)::BIGINT, 5000000::BIGINT\),\s*10000::BIGINT\s*\);',
      'v_gold_stolen := GREATEST(LEAST((v_defender.gold * v_steal_rate)::BIGINT, 5000000::BIGINT), 10000::BIGINT);' || E'\n    v_gold_stolen := floor(v_gold_stolen * public._monument_pvp_gold_loss_multiplier(public._monument_level_for_auth(p_defender_id)))::BIGINT;',
      'n'
    );
  END IF;

  IF position('_monument_reputation_amount' in v_def) = 0 THEN
    v_def := regexp_replace(
      v_def,
      'v_rep_change_winner := CASE WHEN v_winner_id = p_attacker_id THEN 3 ELSE 2 END;\s*v_rep_change_loser := -2;',
      E'v_rep_change_winner := public._monument_reputation_amount(\n    CASE WHEN v_winner_id = p_attacker_id THEN p_attacker_id ELSE p_defender_id END,\n    CASE WHEN v_winner_id = p_attacker_id THEN 3 ELSE 2 END\n  );\n  v_rep_change_loser := -public._monument_reputation_amount(\n    CASE WHEN v_winner_id = p_attacker_id THEN p_defender_id ELSE p_attacker_id END,\n    2\n  );',
      'n'
    );

    v_def := regexp_replace(
      v_def,
      'UPDATE public\.users SET reputation = reputation \+ 2 WHERE auth_id = p_defender_id;\s*UPDATE public\.users SET reputation = reputation - 2 WHERE auth_id = p_attacker_id;',
      E'UPDATE public.users SET reputation = reputation + public._monument_reputation_amount(p_defender_id, 2) WHERE auth_id = p_defender_id;\n    UPDATE public.users SET reputation = reputation - public._monument_reputation_amount(p_attacker_id, 2) WHERE auth_id = p_attacker_id;',
      'n'
    );
  END IF;

  EXECUTE v_def;
END;
$patch$;

-- ── Patch collect_facility_resources_v2 (3-arg) ─────────────────────────────
DO $patch$
DECLARE
  v_def text;
  v_args constant text := 'p_facility_id uuid, p_seed bigint, p_total_count integer';
  v_marker text := E'  v_elapsed_seconds := LEAST(120, GREATEST(0, v_elapsed_seconds));';
  v_block text := E'  v_elapsed_seconds := LEAST(120, GREATEST(0, v_elapsed_seconds));\n  v_elapsed_seconds := LEAST(\n    120,\n    v_elapsed_seconds * public._monument_facility_speed_multiplier(public._monument_level_for_auth(v_user_id))\n  );';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'collect_facility_resources_v2'
    AND pg_get_function_identity_arguments(p.oid) = v_args;

  IF v_def IS NULL THEN
    RAISE NOTICE 'collect_facility_resources_v2(3-arg) not found; skipping facility speed patch';
    RETURN;
  END IF;

  IF position('_monument_facility_speed_multiplier' in v_def) = 0
     AND position(v_marker in v_def) > 0 THEN
    v_def := replace(v_def, v_marker, v_block);
    EXECUTE v_def;
  END IF;
END;
$patch$;

COMMIT;
