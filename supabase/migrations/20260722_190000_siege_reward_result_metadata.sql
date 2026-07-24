-- Kuşatma prime ödül metadata → attack_dungeon sonuç JSON + sonuç ekranı
BEGIN;

CREATE OR REPLACE FUNCTION public.dungeon_siege_run_bonus_for_result(
  p_player_id uuid,
  p_dungeon_id text,
  p_success boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_siege jsonb;
  v_loot_pct integer;
  v_gold_pct integer;
  v_slot_loot_pct integer;
  v_slot_gold_pct integer;
  v_hold_pct integer := 0;
  v_rep integer := 0;
BEGIN
  IF p_player_id IS NULL OR p_dungeon_id IS NULL OR btrim(p_dungeon_id) = '' THEN
    RETURN jsonb_build_object('active', false);
  END IF;

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object(
      'active', false,
      'prime_active', false,
      'has_slot', false,
      'applied', false
    );
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_siege := public.dungeon_siege_reward_multipliers(p_player_id, p_dungeon_id);

  IF NOT COALESCE((v_siege->>'has_slot')::boolean, false) THEN
    RETURN jsonb_build_object(
      'active', true,
      'prime_active', true,
      'has_slot', false,
      'applied', false,
      'slot_loot_bonus_pct', round(COALESCE(v_cfg.loot_bonus_pct, 0) * 100),
      'slot_gold_bonus_pct', round(COALESCE(v_cfg.gold_bonus_pct, 0) * 100),
      'hold_bonus_pct', round(COALESCE(v_cfg.hold_bonus_pct, 0) * 100)
    );
  END IF;

  v_loot_pct := round((COALESCE((v_siege->>'loot_mult')::numeric, 1) - 1) * 100);
  v_gold_pct := round((COALESCE((v_siege->>'gold_mult')::numeric, 1) - 1) * 100);
  v_slot_loot_pct := round(COALESCE(v_cfg.loot_bonus_pct, 0) * 100);
  v_slot_gold_pct := round(COALESCE(v_cfg.gold_bonus_pct, 0) * 100);

  IF COALESCE((v_siege->>'has_hold_bonus')::boolean, false) THEN
    v_hold_pct := round(COALESCE(v_cfg.hold_bonus_pct, 0) * 100);
  END IF;

  IF p_success THEN
    v_rep := GREATEST(
      1,
      floor(20 * COALESCE((v_siege->>'rep_bonus_pct')::numeric, COALESCE(v_cfg.rep_bonus_pct, 0.15)))
    );
  END IF;

  RETURN jsonb_build_object(
    'active', true,
    'prime_active', true,
    'has_slot', true,
    'applied', p_success,
    'has_hold_bonus', COALESCE((v_siege->>'has_hold_bonus')::boolean, false),
    'loot_bonus_pct', v_loot_pct,
    'gold_bonus_pct', v_gold_pct,
    'slot_loot_bonus_pct', v_slot_loot_pct,
    'slot_gold_bonus_pct', v_slot_gold_pct,
    'hold_bonus_pct', v_hold_pct,
    'rep_gained', v_rep,
    'loot_mult', COALESCE((v_siege->>'loot_mult')::numeric, 1),
    'gold_mult', COALESCE((v_siege->>'gold_mult')::numeric, 1)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dungeon_siege_run_bonus_for_result(uuid, text, boolean) TO authenticated;

-- attack_dungeon_rl_inner = tutorial wrapper (rate-limit shell dışında)
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
BEGIN
  v_player_id := auth.uid();
  v_result := public.enter_dungeon(v_player_id, p_dungeon_id);

  IF v_result ? 'error' THEN
    RETURN v_result;
  END IF;

  v_success := COALESCE((v_result->>'success')::BOOLEAN, false);
  v_items_raw := COALESCE(v_result->'items', '[]'::JSONB);

  IF v_success THEN
    v_dungeon_num := COALESCE(NULLIF(regexp_replace(p_dungeon_id, '\D', '', 'g'), '')::INTEGER, 0);

    SELECT COUNT(*) INTO v_run_count
    FROM public.dungeon_runs
    WHERE player_id = v_player_id;

    IF v_run_count <= 1 THEN
      SELECT id, name, type INTO v_item
      FROM public.items
      WHERE lower(rarity) = 'common'
        AND lower(type) IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY random()
      LIMIT 1;

      IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', v_item.id, 'name', v_item.name,
          'rarity', 'common', 'type', v_item.type, 'quantity', 1
        );
      END IF;

      IF public.dungeon_add_item(v_player_id, 'scroll_upgrade_low', 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', 'scroll_upgrade_low', 'name', 'Lesser Upgrade Scroll',
          'rarity', 'common', 'type', 'scroll', 'quantity', 1
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
          'rarity', 'common', 'type', v_item.type, 'quantity', 1
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
        'rarity', 'common', 'type', v_item.type, 'quantity', v_qty
      );
    END IF;
  END IF;

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
    'reward_multiplier',   COALESCE((v_result->>'reward_multiplier')::NUMERIC, 1),
    'hospital_risk_pct',   COALESCE((v_result->>'hospital_risk_pct')::NUMERIC, 0),
    'milestone_rewards',   COALESCE(v_result->'milestone_rewards', '[]'::jsonb),
    'siege_bonus',         public.dungeon_siege_run_bonus_for_result(v_player_id, p_dungeon_id, v_success)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.attack_dungeon_rl_inner(TEXT) TO authenticated;

COMMIT;
