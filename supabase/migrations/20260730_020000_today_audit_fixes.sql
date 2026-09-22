-- Audit fixes: crafting RPC schema, queue slots, health PvP, hospital heal, kingdom vote.

BEGIN;

-- ── Craft queue: count only unclaimed rows ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.craft_item_async(
  p_recipe_id uuid,
  p_batch_count integer DEFAULT 1
)
RETURNS TABLE (
  success boolean,
  queue_item_id uuid,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_recipe crafting_recipes%ROWTYPE;
  v_queue_item craft_queue%ROWTYPE;
  v_completes_at timestamp with time zone;
  v_ingredient_item RECORD;
  v_required_qty integer;
  v_owned_qty integer;
  v_max_slots integer;
  v_active_count integer;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Not authenticated'::text;
    RETURN;
  END IF;

  SELECT COALESCE(crafting_queue_slots, 1)
  INTO v_max_slots
  FROM public.users
  WHERE auth_id = v_user_id;

  IF v_max_slots IS NULL THEN
    v_max_slots := 1;
  END IF;

  SELECT COUNT(*)::integer
  INTO v_active_count
  FROM public.craft_queue
  WHERE user_id = v_user_id
    AND claimed = false;

  IF v_active_count >= v_max_slots THEN
    RETURN QUERY SELECT false, NULL::uuid,
      ('Craft queue full (' || v_active_count || '/' || v_max_slots || '). Unlock more slots with gems.')::text;
    RETURN;
  END IF;

  SELECT * FROM public.crafting_recipes WHERE id = p_recipe_id INTO v_recipe;
  IF v_recipe.id IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, 'Recipe not found'::text;
    RETURN;
  END IF;

  IF v_recipe.ingredients IS NOT NULL AND v_recipe.ingredients != 'null'::jsonb THEN
    FOR v_ingredient_item IN
      SELECT
        jsonb_array_elements(v_recipe.ingredients) ->> 'item_id' as item_id,
        (jsonb_array_elements(v_recipe.ingredients) ->> 'quantity')::integer as quantity
    LOOP
      v_required_qty := (v_ingredient_item.quantity * p_batch_count);

      SELECT COALESCE(SUM(quantity), 0) INTO v_owned_qty
      FROM public.inventory
      WHERE user_id = v_user_id AND item_id = v_ingredient_item.item_id;

      IF v_owned_qty < v_required_qty THEN
        RETURN QUERY SELECT false, NULL::uuid,
          'Insufficient material: ' || v_ingredient_item.item_id || ' (need ' || v_required_qty || ', have ' || v_owned_qty || ')'::text;
        RETURN;
      END IF;
    END LOOP;
  END IF;

  IF v_recipe.ingredients IS NOT NULL AND v_recipe.ingredients != 'null'::jsonb THEN
    FOR v_ingredient_item IN
      SELECT
        jsonb_array_elements(v_recipe.ingredients) ->> 'item_id' as item_id,
        (jsonb_array_elements(v_recipe.ingredients) ->> 'quantity')::integer as quantity
    LOOP
      v_required_qty := (v_ingredient_item.quantity * p_batch_count);

      DECLARE
        v_remaining integer := v_required_qty;
        v_row RECORD;
        v_take integer;
      BEGIN
        FOR v_row IN
          SELECT row_id, quantity FROM public.inventory
          WHERE user_id = v_user_id AND item_id = v_ingredient_item.item_id
          ORDER BY created_at ASC
        LOOP
          EXIT WHEN v_remaining <= 0;
          v_take := LEAST(v_row.quantity, v_remaining);
          IF v_row.quantity > v_take THEN
            UPDATE public.inventory
            SET quantity = quantity - v_take, updated_at = now()
            WHERE row_id = v_row.row_id;
          ELSE
            DELETE FROM public.inventory WHERE row_id = v_row.row_id;
          END IF;
          v_remaining := v_remaining - v_take;
        END LOOP;
      END;
    END LOOP;
  END IF;

  v_completes_at := now() + (v_recipe.production_time_seconds * p_batch_count) * INTERVAL '1 second';

  INSERT INTO public.craft_queue (user_id, recipe_id, batch_count, completes_at, is_completed, claimed, failed)
  VALUES (v_user_id, p_recipe_id, p_batch_count, v_completes_at, false, false, false)
  RETURNING * INTO v_queue_item;

  RETURN QUERY SELECT true, v_queue_item.id, 'Craft started'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.craft_item_async(uuid, integer) TO authenticated;

-- ── start_crafting: live schema (crafting_recipes + craft_queue) ──────────────

CREATE OR REPLACE FUNCTION public.start_crafting(
  p_user_id uuid,
  p_recipe_id uuid,
  p_quantity integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_recipe RECORD;
  v_user RECORD;
  v_facility RECORD;
  v_total_gold bigint;
  v_total_duration int;
  v_materials jsonb;
  v_key text;
  v_val int;
  v_inv_qty int;
  v_monument_level int := 0;
  v_max_slots int;
  v_active_count int;
  v_qty int := GREATEST(COALESCE(p_quantity, 1), 1);
BEGIN
  IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;

  SELECT * INTO v_recipe FROM public.crafting_recipes WHERE id = p_recipe_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tarif bulunamadi');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi');
  END IF;

  IF v_user.level < COALESCE(v_recipe.required_level, 1) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seviyeniz yetersiz');
  END IF;

  SELECT COALESCE(crafting_queue_slots, 1) INTO v_max_slots FROM public.users WHERE auth_id = p_user_id;
  SELECT COUNT(*)::integer INTO v_active_count
  FROM public.craft_queue
  WHERE user_id = p_user_id AND claimed = false;

  IF v_active_count >= v_max_slots THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Uretim kuyrugu dolu (' || v_active_count || '/' || v_max_slots || ')'
    );
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_user.guild_id;
  END IF;

  v_total_gold := (COALESCE(v_recipe.gold_cost, 0) * v_qty)::bigint;
  IF v_user.gold < v_total_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altininiz yetersiz');
  END IF;

  IF COALESCE(v_recipe.facility_type, 'none') <> 'none' THEN
    SELECT * INTO v_facility
    FROM public.player_facilities
    WHERE user_id = p_user_id AND facility_type = v_recipe.facility_type;
    IF NOT FOUND OR COALESCE(v_facility.level, 0) < 1 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Gerekli tesis yetersiz');
    END IF;
  END IF;

  v_materials := COALESCE(v_recipe.materials, '{}'::jsonb);
  IF v_materials <> '{}'::jsonb THEN
    FOR v_key, v_val IN SELECT * FROM jsonb_each_text(v_materials) LOOP
      SELECT COALESCE(SUM(quantity), 0) INTO v_inv_qty
      FROM public.inventory
      WHERE user_id = p_user_id AND item_id = v_key;
      IF v_inv_qty < (v_val::int * v_qty) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Gerekli materyaller eksik');
      END IF;
    END LOOP;
  END IF;

  UPDATE public.users
  SET gold = gold - v_total_gold
  WHERE auth_id = p_user_id AND gold >= v_total_gold;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda altin yetersiz kaldi');
  END IF;

  IF v_materials <> '{}'::jsonb THEN
    FOR v_key, v_val IN SELECT * FROM jsonb_each_text(v_materials) LOOP
      DECLARE
        v_needed int := v_val::int * v_qty;
        v_row record;
      BEGIN
        FOR v_row IN
          SELECT row_id, quantity FROM public.inventory
          WHERE user_id = p_user_id AND item_id = v_key AND quantity > 0
          ORDER BY quantity ASC
        LOOP
          EXIT WHEN v_needed <= 0;
          IF v_row.quantity <= v_needed THEN
            DELETE FROM public.inventory WHERE row_id = v_row.row_id;
            v_needed := v_needed - v_row.quantity;
          ELSE
            UPDATE public.inventory SET quantity = quantity - v_needed WHERE row_id = v_row.row_id;
            v_needed := 0;
          END IF;
        END LOOP;
      END;
    END LOOP;
  END IF;

  v_total_duration := COALESCE(v_recipe.production_time_seconds, 3600) * v_qty;
  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_total_duration := floor(v_total_duration * 0.80)::int;
  END IF;

  INSERT INTO public.craft_queue (
    user_id, recipe_id, batch_count, started_at, completes_at, is_completed, claimed, failed
  )
  VALUES (
    p_user_id,
    p_recipe_id,
    v_qty,
    now(),
    now() + (v_total_duration || ' seconds')::interval,
    false,
    false,
    false
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_crafting(uuid, uuid, integer) TO authenticated;

-- ── Arena PvP health: require both players ────────────────────────────────────

CREATE OR REPLACE FUNCTION public.apply_arena_pvp_health_damage(
  p_winner_id UUID,
  p_loser_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_w_health INT;
  v_w_max INT;
  v_l_health INT;
  v_l_max INT;
  v_w_dmg INT;
  v_l_dmg INT;
BEGIN
  SELECT COALESCE(health, max_health, 100), GREATEST(COALESCE(max_health, 100), 1)
  INTO v_w_health, v_w_max
  FROM public.users
  WHERE auth_id = p_winner_id;

  IF NOT FOUND OR v_w_max IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(health, max_health, 100), GREATEST(COALESCE(max_health, 100), 1)
  INTO v_l_health, v_l_max
  FROM public.users
  WHERE auth_id = p_loser_id;

  IF NOT FOUND OR v_l_max IS NULL THEN
    RETURN;
  END IF;

  v_w_dmg := FLOOR(v_w_max * (0.10 + random() * 0.15))::INT;
  v_l_dmg := FLOOR(v_l_max * (0.35 + random() * 0.20))::INT;

  UPDATE public.users
  SET
    health = GREATEST(public.player_health_floor(v_w_max), v_w_health - v_w_dmg),
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = p_winner_id;

  UPDATE public.users
  SET
    health = GREATEST(public.player_health_floor(v_l_max), v_l_health - v_l_dmg),
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = p_loser_id;
END;
$$;

-- ── Hospital gem heal: level-scaled + free discharges + wounded exit ───────────

CREATE OR REPLACE FUNCTION public.heal_with_gems()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_hospital_until timestamptz;
  v_gems int;
  v_hospital_count int;
  v_level int;
  v_rate int;
  v_minutes_left int;
  v_gem_cost int;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  PERFORM public.sync_expired_hospital(v_user_id);

  SELECT hospital_until, gems, COALESCE(hospital_lifetime_count, 0), COALESCE(level, 1)
  INTO v_hospital_until, v_gems, v_hospital_count, v_level
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF v_hospital_until IS NULL OR v_hospital_until <= now() THEN
    UPDATE public.users SET hospital_until = NULL, hospital_reason = NULL WHERE auth_id = v_user_id;
    RETURN json_build_object('success', true);
  END IF;

  IF v_hospital_count <= 2 THEN
    UPDATE public.users
    SET hospital_until = NULL, hospital_reason = NULL
    WHERE auth_id = v_user_id;
    PERFORM public.apply_hospital_wounded_state(v_user_id);
    RETURN json_build_object(
      'success', true,
      'was_free', true,
      'cost', 0,
      'wounded', true,
      'free_discharges_remaining', GREATEST(0, 2 - v_hospital_count)
    );
  END IF;

  v_minutes_left := CEIL(EXTRACT(EPOCH FROM (v_hospital_until - now())) / 60.0);
  IF v_minutes_left < 1 THEN
    v_minutes_left := 1;
  END IF;

  v_rate := CASE WHEN v_level < 10 THEN 1 WHEN v_level < 20 THEN 2 ELSE 3 END;
  v_gem_cost := v_minutes_left * v_rate;

  IF v_gems < v_gem_cost THEN
    RETURN json_build_object('success', false, 'error', 'Yetersiz elmas. Gerekli: ' || v_gem_cost);
  END IF;

  UPDATE public.users
  SET gems = gems - v_gem_cost,
      hospital_until = NULL,
      hospital_reason = NULL
  WHERE auth_id = v_user_id;

  PERFORM public.apply_hospital_wounded_state(v_user_id);

  RETURN json_build_object(
    'success', true,
    'was_free', false,
    'cost', v_gem_cost,
    'wounded', true,
    'free_discharges_remaining', 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.heal_with_gems() TO authenticated;

-- ── Kingdom vote: orphan guild cleanup + FK-safe insert ───────────────────────

UPDATE public.users u
SET guild_id = NULL,
    updated_at = now()
WHERE u.guild_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.guilds g WHERE g.id = u.guild_id
  );

CREATE OR REPLACE FUNCTION public.vote_in_election(
  p_election_id uuid,
  p_candidate_guild_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_voter_guild_id uuid;
  v_candidate_rank integer;
  v_election record;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum bulunamadi.');
  END IF;

  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE id = p_election_id;

  IF v_election IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Secim bulunamadi.');
  END IF;

  IF v_election.status != 'active' THEN
    RETURN json_build_object('success', false, 'error', 'Bu secim artik aktif degil.');
  END IF;

  IF v_election.start_at IS NOT NULL AND v_election.start_at > now() THEN
    RETURN json_build_object('success', false, 'error', 'Secim henuz baslamadi.');
  END IF;

  IF v_election.end_at IS NOT NULL AND v_election.end_at <= now() THEN
    PERFORM public.finalize_kingdom_election(p_election_id);
    RETURN json_build_object('success', false, 'error', 'Secim suresi doldu.');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.kingdom_election_votes
    WHERE election_id = p_election_id
      AND voter_user_id = v_player_id
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Bu secimde zaten oy kullandiniz.');
  END IF;

  SELECT cg.season_rank
  INTO v_candidate_rank
  FROM public._kingdom_election_candidate_guilds(20) cg
  WHERE cg.guild_id = p_candidate_guild_id;

  IF v_candidate_rank IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Yalnizca sezon siralamasinda ilk 20 lonca aday olabilir.'
    );
  END IF;

  SELECT u.guild_id
  INTO v_voter_guild_id
  FROM public.users u
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE u.auth_id = v_player_id;

  IF v_voter_guild_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.guilds g WHERE g.id = v_voter_guild_id
  ) THEN
    v_voter_guild_id := NULL;
    UPDATE public.users SET guild_id = NULL, updated_at = now() WHERE auth_id = v_player_id;
  END IF;

  BEGIN
    INSERT INTO public.kingdom_election_votes (
      election_id,
      voter_user_id,
      voter_guild_id,
      candidate_guild_id
    )
    VALUES (
      p_election_id,
      v_player_id,
      v_voter_guild_id,
      p_candidate_guild_id
    );
  EXCEPTION
    WHEN unique_violation THEN
      RETURN json_build_object('success', false, 'error', 'Bu secimde zaten oy kullandiniz.');
    WHEN foreign_key_violation THEN
      RETURN json_build_object('success', false, 'error', 'Oy kaydedilemedi. Lonca bilgisi gecersiz.');
  END;

  RETURN json_build_object('success', true, 'message', 'Oyunuz basariyla kaydedildi.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.vote_in_election(uuid, uuid) TO authenticated;

COMMIT;
