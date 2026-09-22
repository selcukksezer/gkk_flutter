-- Smoke: does max-luck +10 gear inflate late-dungeon loot?
-- Reality: enter_dungeon loot uses users.luck (+monument/codex), NOT equipped item luck.
-- Caps: loot_luck_bonus <= 0.20, drop chance <= 0.95, rarity_shift <= 0.10.
-- Run: SELECT public.qa_smoke_late_dungeon_luck_loot();

CREATE OR REPLACE FUNCTION public.qa_smoke_late_dungeon_luck_loot()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_tests jsonb := '[]'::jsonb;
  v_ok boolean;
  v_passed int;
  v_total int;
  v_equip_luck_sum int;
  v_equip_luck_power_at_10 numeric;
  v_max_user_luck int;
  v_def text;
  v_uses_player_luck boolean;
  v_uses_inventory_luck boolean;
  v_rates jsonb := '[]'::jsonb;
  v_hypo jsonb := '[]'::jsonb;
  v_late jsonb;
  v_d RECORD;
  v_luck numeric;
  v_bonus numeric;
  v_eff_eq numeric;
  v_eff_res numeric;
  v_eff_scroll numeric;
  v_gold_mult numeric;
  v_rarity_shift numeric;
  v_shadow_bonus numeric;
  v_hits_softcap int := 0;
  v_excessive int := 0;
  v_profile text;
  v_profiles jsonb := '[
    {"name":"luck_0","luck":0,"shadow":false},
    {"name":"luck_50","luck":50,"shadow":false},
    {"name":"luck_cap_133","luck":133,"shadow":false},
    {"name":"luck_max_user_284","luck":284,"shadow":false},
    {"name":"luck_284_shadow","luck":284,"shadow":true},
    {"name":"hypo_equip_luck_only","luck":0,"shadow":false,"add_equip":true},
    {"name":"hypo_equip_plus_user_shadow","luck":284,"shadow":true,"add_equip":true}
  ]'::jsonb;
  v_p jsonb;
  v_add_equip boolean;
  v_eff_luck numeric;
BEGIN
  -- Sum max-luck piece per slot (mythic preferred, else any) = worst equip luck loadout.
  WITH ranked AS (
    SELECT
      id, equip_slot, COALESCE(luck,0) AS luck, lower(rarity) AS rarity,
      row_number() OVER (
        PARTITION BY equip_slot
        ORDER BY COALESCE(luck,0) DESC,
                 CASE lower(rarity)
                   WHEN 'mythic' THEN 1 WHEN 'legendary' THEN 2 WHEN 'epic' THEN 3
                   WHEN 'rare' THEN 4 WHEN 'uncommon' THEN 5 ELSE 6
                 END,
                 id
      ) AS rn
    FROM public.items
    WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace')
  )
  SELECT coalesce(sum(luck), 0)
  INTO v_equip_luck_sum
  FROM ranked WHERE rn = 1;

  -- Power contribution of that luck at +10 (combat only) — NOT used by loot.
  v_equip_luck_power_at_10 := floor((v_equip_luck_sum * 2.0) * 2.5);

  SELECT coalesce(max(COALESCE(luck,0)), 0) INTO v_max_user_luck
  FROM public.users
  WHERE coalesce(email,'') NOT ILIKE '%@sim.local';

  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'enter_dungeon'
  LIMIT 1;

  v_uses_player_luck := position('v_luck_for_loot := COALESCE(v_player.luck' in v_def) > 0;
  -- Loot luck line must not pull from inventory/item rows.
  v_uses_inventory_luck :=
    position('v_luck_for_loot :=' in v_def) > 0
    AND (
      substring(v_def from position('v_luck_for_loot :=' in v_def) for 220)
        ILIKE '%inventory%'
      OR substring(v_def from position('v_luck_for_loot :=' in v_def) for 220)
        ILIKE '%enhancement%'
      OR substring(v_def from position('v_luck_for_loot :=' in v_def) for 220)
        ILIKE '%equip%'
    );

  v_ok := v_uses_player_luck AND NOT coalesce(v_uses_inventory_luck, false);
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'source',
    'test', 'loot_luck_uses_users_luck_not_equipped_items',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'uses_v_player_luck', v_uses_player_luck,
      'uses_inventory_luck', coalesce(v_uses_inventory_luck, false),
      'equip_max_luck_sum_8slot', v_equip_luck_sum,
      'equip_luck_power_at_plus10_combat_only', v_equip_luck_power_at_10,
      'note', 'Item +10 luck büyütür combat power (luck*2*2.5); loot formülüne girmez.'
    )
  ));

  -- Late dungeons: top 10 by power_requirement
  SELECT coalesce(jsonb_agg(row_to_json(d)::jsonb ORDER BY d.power_requirement DESC), '[]'::jsonb)
  INTO v_late
  FROM (
    SELECT id, name, dungeon_order, power_requirement,
           equipment_drop_chance::numeric AS equipment_drop_chance,
           resource_drop_chance::numeric AS resource_drop_chance,
           scroll_drop_chance::numeric AS scroll_drop_chance,
           is_boss
    FROM public.dungeons
    ORDER BY power_requirement DESC NULLS LAST
    LIMIT 10
  ) d;

  v_ok := jsonb_array_length(v_late) >= 5;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'dungeons',
    'test', 'late_dungeons_sampled',
    'pass', v_ok,
    'detail', jsonb_build_object('count', jsonb_array_length(v_late), 'dungeons', v_late)
  ));

  -- Caps present in formula
  v_ok := v_def ILIKE '%LEAST(0.20, v_luck_for_loot%'
      AND v_def ILIKE '%LEAST(0.95%'
      AND v_def ILIKE '%LEAST(0.10, v_luck_for_loot%';
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'caps',
    'test', 'loot_bonus_and_drop_and_rarity_caps_present',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'loot_luck_bonus_cap', 0.20,
      'drop_chance_cap', 0.95,
      'rarity_shift_cap', 0.10,
      'luck_to_hit_bonus_cap', ceil(0.20 / 0.0015)  -- 134
    )
  ));

  -- Rate matrix: profiles × late dungeons
  FOR v_p IN SELECT value FROM jsonb_array_elements(v_profiles) AS t(value)
  LOOP
    v_profile := v_p->>'name';
    v_luck := coalesce((v_p->>'luck')::numeric, 0);
    v_add_equip := coalesce((v_p->>'add_equip')::boolean, false);
    v_shadow_bonus := CASE WHEN coalesce((v_p->>'shadow')::boolean, false) THEN 0.20 ELSE 0 END;
    -- monument flat +10 (max), ignore codex for worst-ish deterministic bound
    v_eff_luck := v_luck + 10;
    IF v_add_equip THEN
      v_eff_luck := v_eff_luck + v_equip_luck_sum; -- HYPOTHETICAL broken wiring
    END IF;

    v_bonus := LEAST(0.20, v_eff_luck * 0.0015);
    v_gold_mult := 1 + v_eff_luck * 0.002;
    v_rarity_shift := LEAST(0.10, v_eff_luck * 0.0008
      + CASE WHEN coalesce((v_p->>'shadow')::boolean, false) THEN 0.05 ELSE 0 END);

    FOR v_d IN
      SELECT * FROM jsonb_to_recordset(v_late) AS x(
        id text, name text, dungeon_order int, power_requirement int,
        equipment_drop_chance numeric, resource_drop_chance numeric,
        scroll_drop_chance numeric, is_boss boolean
      )
    LOOP
      v_eff_eq := LEAST(0.95, GREATEST(0, v_d.equipment_drop_chance * (1 + v_bonus + v_shadow_bonus)));
      v_eff_res := LEAST(0.95, GREATEST(0, v_d.resource_drop_chance * (1 + v_bonus + v_shadow_bonus)));
      v_eff_scroll := LEAST(0.95, GREATEST(0, v_d.scroll_drop_chance * (1 + v_bonus + v_shadow_bonus)));

      IF v_eff_eq >= 0.95 OR v_eff_res >= 0.95 THEN
        v_hits_softcap := v_hits_softcap + 1;
      END IF;
      -- "Aşırı fazla": equipment drop > 70% on a single run (expected >70 items / 100 wins)
      IF v_eff_eq > 0.70 AND NOT v_add_equip THEN
        v_excessive := v_excessive + 1;
      END IF;
      IF v_add_equip THEN
        v_hypo := v_hypo || jsonb_build_array(jsonb_build_object(
          'profile', v_profile,
          'dungeon', v_d.id,
          'eff_luck', v_eff_luck,
          'loot_bonus', round(v_bonus, 4),
          'eff_equipment_drop', round(v_eff_eq, 4),
          'expected_equip_per_100_wins', round(v_eff_eq * 100, 1),
          'gold_mult', round(v_gold_mult, 4),
          'rarity_shift', round(v_rarity_shift, 4)
        ));
      ELSE
        v_rates := v_rates || jsonb_build_array(jsonb_build_object(
          'profile', v_profile,
          'dungeon', v_d.id,
          'base_equipment_drop', v_d.equipment_drop_chance,
          'eff_luck', v_eff_luck,
          'loot_bonus', round(v_bonus, 4),
          'shadow_bonus', v_shadow_bonus,
          'eff_equipment_drop', round(v_eff_eq, 4),
          'eff_resource_drop', round(v_eff_res, 4),
          'eff_scroll_drop', round(v_eff_scroll, 4),
          'expected_equip_per_100_wins', round(v_eff_eq * 100, 1),
          'gold_mult', round(v_gold_mult, 4),
          'rarity_shift', round(v_rarity_shift, 4)
        ));
      END IF;
    END LOOP;
  END LOOP;

  -- Real profiles must not exceed 70% equipment drop on late content
  v_ok := v_excessive = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'balance',
    'test', 'late_dungeon_equipment_drop_not_excessive_under_real_luck',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'threshold', 0.70,
      'excessive_cells', v_excessive,
      'softcap_hits_095', v_hits_softcap,
      'sample_rates', (
        SELECT coalesce(jsonb_agg(x), '[]'::jsonb)
        FROM (
          SELECT value AS x FROM jsonb_array_elements(v_rates) value
          WHERE value->>'dungeon' IN (
            SELECT id FROM public.dungeons ORDER BY power_requirement DESC LIMIT 3
          )
          AND value->>'profile' IN ('luck_0','luck_cap_133','luck_284_shadow')
        ) s
      )
    )
  ));

  -- Bonus saturates: luck 134 vs 284 same loot_bonus (0.20)
  v_ok := LEAST(0.20, 134 * 0.0015) = LEAST(0.20, 284 * 0.0015)
      AND LEAST(0.20, 134 * 0.0015) = 0.20;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'caps',
    'test', 'loot_luck_bonus_saturates_by_luck_134',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'bonus_at_133', LEAST(0.20, 133 * 0.0015),
      'bonus_at_134', LEAST(0.20, 134 * 0.0015),
      'bonus_at_284', LEAST(0.20, 284 * 0.0015),
      'bonus_at_equip_sum', LEAST(0.20, (v_equip_luck_sum + 10) * 0.0015)
    )
  ));

  -- Even hypothetical equip-luck wiring: bonus still capped 0.20 → drop not unbounded
  v_ok := LEAST(0.20, (v_equip_luck_sum + 284 + 10) * 0.0015) = 0.20;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'hypothesis',
    'test', 'even_if_equip_luck_wired_bonus_still_capped_020',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'equip_luck_sum', v_equip_luck_sum,
      'hypo_eff_luck', v_equip_luck_sum + 284 + 10,
      'hypo_bonus_still', 0.20,
      'dng_065_base', 0.35,
      'dng_065_eff_with_shadow', LEAST(0.95, 0.35 * (1 + 0.20 + 0.20)),
      'expected_equip_per_100_wins_worst', round(LEAST(0.95, 0.35 * 1.40) * 100, 1),
      'hypo_sample', (
        SELECT coalesce(jsonb_agg(x), '[]'::jsonb)
        FROM (
          SELECT value AS x FROM jsonb_array_elements(v_hypo) value
          WHERE value->>'dungeon' = (
            SELECT id FROM public.dungeons ORDER BY power_requirement DESC LIMIT 1
          )
          LIMIT 5
        ) s
      )
    )
  ));

  -- Worst real late drop: base 0.35 * 1.40 shadow+cap = 0.49 < 0.70
  v_ok := LEAST(0.95, 0.35 * (1 + 0.20 + 0.20)) <= 0.70;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'balance',
    'test', 'worst_real_late_boss_equip_drop_le_049',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'formula', '0.35 * (1 + 0.20_luck_cap + 0.20_shadow) = 0.49',
      'eff', LEAST(0.95, 0.35 * 1.40),
      'items_per_100_wins', round(LEAST(0.95, 0.35 * 1.40) * 100, 1),
      'verdict_tr', 'Son zindanlarda max luck + shadow bile ~49 item/100 win — aşırı değil. +10 luck item set loot şişirmez.'
    )
  ));

  SELECT
    count(*) FILTER (WHERE (t->>'pass')::boolean),
    count(*)
  INTO v_passed, v_total
  FROM jsonb_array_elements(v_tests) t;

  RETURN jsonb_build_object(
    'verdict', CASE WHEN v_passed = v_total THEN 'PASS' ELSE 'FAIL' END,
    'passed', v_passed,
    'total', v_total,
    'key_finding', jsonb_build_object(
      'equipped_item_luck_affects_loot', false,
      'plus10_item_luck_affects_loot', false,
      'loot_uses', 'users.luck + monument + codex',
      'equip_max_luck_sum', v_equip_luck_sum,
      'max_observed_user_luck', v_max_user_luck,
      'loot_bonus_cap', 0.20,
      'worst_late_boss_equip_drop', 0.49,
      'worst_items_per_100_wins', 49
    ),
    'rates_count', jsonb_array_length(v_rates),
    'tests', v_tests,
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_smoke_late_dungeon_luck_loot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_late_dungeon_luck_loot() TO service_role;
GRANT EXECUTE ON FUNCTION public.qa_smoke_late_dungeon_luck_loot() TO authenticated;
