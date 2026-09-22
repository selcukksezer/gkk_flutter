-- First dungeon clear: guarantee a common weapon for inventory tutorial (not random armor).

CREATE OR REPLACE FUNCTION public.attack_dungeon_rl_inner(p_dungeon_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_result           JSONB;
  v_items_raw        JSONB;
  v_hospital_until   TIMESTAMPTZ;
  v_hospital_secs    INTEGER := 0;
  v_player_id        UUID;
  v_run_count        INTEGER;
  v_dungeon_num      INTEGER;
  v_item             RECORD;
  v_qty              INTEGER;
  v_success          BOOLEAN;
  v_items_before_count INTEGER := 0;
  v_wrapper_loot_count INTEGER := 0;
  v_farm_mult        NUMERIC := 1;
BEGIN
  v_player_id := auth.uid();
  v_result := public.enter_dungeon(v_player_id, p_dungeon_id);

  IF v_result ? 'error' THEN
    RETURN v_result;
  END IF;

  v_success := COALESCE((v_result->>'success')::BOOLEAN, false);
  v_items_raw := COALESCE(v_result->'items', '[]'::JSONB);
  v_items_before_count := jsonb_array_length(v_items_raw);
  v_farm_mult := COALESCE((v_result->>'reward_multiplier')::NUMERIC, 1);

  IF v_success THEN
    v_dungeon_num := COALESCE(
      NULLIF(regexp_replace(p_dungeon_id, '[^0-9]', '', 'g'), '')::INTEGER,
      0
    );

    SELECT COUNT(*) INTO v_run_count
    FROM public.dungeon_runs
    WHERE player_id = v_player_id;

    IF v_run_count <= 1 THEN
      SELECT id, name, type INTO v_item
      FROM public.items
      WHERE lower(rarity) = 'common'
        AND lower(type) = 'weapon'
      ORDER BY random()
      LIMIT 1;

      IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', v_item.id, 'name', v_item.name,
          'rarity', 'common', 'type', v_item.type, 'quantity', 1,
          'source', 'tutorial_wrapper'
        );
      END IF;

      IF public.dungeon_add_item(v_player_id, 'scroll_upgrade_low', 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', 'scroll_upgrade_low', 'name', 'Lesser Upgrade Scroll',
          'rarity', 'common', 'type', 'scroll', 'quantity', 1,
          'source', 'tutorial_wrapper'
        );
      END IF;
    END IF;

    IF v_dungeon_num BETWEEN 1 AND 10 AND random() < 0.40 THEN
      SELECT i.id, i.name, i.type INTO v_item
      FROM public.items i
      WHERE lower(i.rarity) = 'common'
        AND lower(i.type) IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY
        (EXISTS (
          SELECT 1 FROM public.inventory inv
          JOIN public.items it ON it.id = inv.item_id
          WHERE inv.user_id = v_player_id
            AND lower(it.type) = lower(i.type)
        )) ASC,
        (EXISTS (
          SELECT 1 FROM public.inventory inv
          WHERE inv.user_id = v_player_id AND inv.item_id = i.id
        )) ASC,
        random()
      LIMIT 1;

      IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', v_item.id, 'name', v_item.name,
          'rarity', 'common', 'type', v_item.type, 'quantity', 1,
          'source', 'tutorial_wrapper'
        );
      END IF;
    END IF;

    v_qty := 5 + floor(random() * 11)::INTEGER;

    SELECT id, name, type INTO v_item
    FROM public.items
    WHERE lower(rarity) = 'common'
      AND lower(type) = 'material'
      AND COALESCE(is_stackable, false)
    ORDER BY COALESCE(base_price, 0) ASC, random()
    LIMIT 1;

    IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, v_qty) THEN
      v_items_raw := v_items_raw || jsonb_build_object(
        'item_id', v_item.id, 'name', v_item.name,
        'rarity', 'common', 'type', v_item.type, 'quantity', v_qty,
        'source', 'tutorial_wrapper'
      );
    END IF;
  END IF;

  v_wrapper_loot_count := GREATEST(0, jsonb_array_length(v_items_raw) - v_items_before_count);

  IF (v_result->>'hospital_until') IS NOT NULL THEN
    BEGIN
      v_hospital_until := (v_result->>'hospital_until')::TIMESTAMPTZ;
      v_hospital_secs  := GREATEST(0, EXTRACT(EPOCH FROM (v_hospital_until - now()))::INTEGER);
    EXCEPTION WHEN OTHERS THEN
      v_hospital_secs := 0;
    END;
  END IF;

  RETURN jsonb_build_object(
    'success',             v_success,
    'gold',                COALESCE((v_result->>'gold_earned')::INTEGER, 0),
    'gold_earned',         COALESCE((v_result->>'gold_earned')::INTEGER, 0),
    'xp',                  COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'xp_earned',           COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'items',               v_items_raw,
    'item_details',        v_items_raw,
    'hospitalized',        COALESCE((v_result->>'hospitalized')::BOOLEAN, false),
    'hospital_duration',   v_hospital_secs,
    'hospital_until',      v_result->>'hospital_until',
    'inventory_full',      COALESCE((v_result->>'inventory_full')::BOOLEAN, false),
    'is_critical',         COALESCE((v_result->>'is_critical')::BOOLEAN, false),
    'is_first_clear',      COALESCE((v_result->>'is_first_clear')::BOOLEAN, false),
    'success_rate',        COALESCE((v_result->>'success_rate')::NUMERIC, 0),
    'reward_multiplier',   v_farm_mult,
    'hospital_risk_pct',   COALESCE((v_result->>'hospital_risk_pct')::NUMERIC, 0),
    'milestone_rewards',   COALESCE(v_result->'milestone_rewards', '[]'::jsonb),
    'siege_bonus',         public.dungeon_siege_run_bonus_for_result(v_player_id, p_dungeon_id, v_success),
    'tutorial_wrapper_loot_count', v_wrapper_loot_count,
    'balance_notes', jsonb_build_object(
      'farm_penalty_independent', true,
      'wrapper_loot_additive', v_wrapper_loot_count > 0,
      'siege_requires_slot', true,
      'hold_requires_members', COALESCE(
        (SELECT hold_min_members FROM public.dungeon_siege_config ORDER BY id LIMIT 1),
        3
      )
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.attack_dungeon_rl_inner(TEXT) TO authenticated;
