-- Exhaustive enhancement matrix smoke: every gear item × +0..+10,
-- luck share, and full-set +10 power by rarity.
-- Run: SELECT public.qa_smoke_item_enhancement_matrix();

CREATE OR REPLACE FUNCTION public.qa_smoke_item_enhancement_matrix()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_tests jsonb := '[]'::jsonb;
  v_ok boolean;
  v_n int;
  v_passed int;
  v_total int;
  v_item_count int;
  v_combo_count int;
  v_bad_curve int;
  v_bad_ratio int;
  v_luck_heavy int;
  v_neg_or_nan int;
  v_sets jsonb := '[]'::jsonb;
  v_top_items jsonb;
  v_worst_luck jsonb;
  v_rarity text;
  v_set_power_0 numeric;
  v_set_power_10 numeric;
  v_set_luck_share numeric;
  v_mythic_set_10 numeric;
  v_common_set_0 numeric;
  v_cross_ratio numeric;
  v_sample jsonb;
BEGIN
  SELECT count(*) INTO v_item_count
  FROM public.items
  WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace','shield');

  -- Expand every item × enhancement 0..10
  WITH gear AS (
    SELECT
      id,
      name,
      lower(rarity) AS rarity,
      equip_slot,
      COALESCE(attack,0) AS attack,
      COALESCE(defense,0) AS defense,
      COALESCE(health,0) AS health,
      COALESCE(luck,0) AS luck,
      COALESCE(max_enhancement, 10) AS max_enhancement,
      (COALESCE(attack,0) + COALESCE(defense,0)
        + (COALESCE(health,0) / 10.0)
        + (COALESCE(luck,0) * 2.0)) AS base_power
    FROM public.items
    WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace','shield')
  ),
  levels AS (
    SELECT generate_series(0, 10) AS enh
  ),
  matrix AS (
    SELECT
      g.*,
      l.enh,
      floor(g.base_power * (1 + l.enh * 0.15))::bigint AS power_at,
      CASE WHEN g.base_power > 0
        THEN round(((g.luck * 2.0) / g.base_power) * 100.0, 2)
        ELSE 0
      END AS luck_share_pct,
      CASE WHEN g.base_power > 0
        THEN round((floor(g.base_power * (1 + l.enh * 0.15))::numeric / g.base_power), 4)
        ELSE NULL
      END AS ratio_vs_base
    FROM gear g
    CROSS JOIN levels l
    WHERE l.enh <= GREATEST(g.max_enhancement, 10)
  ),
  stepped AS (
    SELECT
      id, enh, power_at, base_power, ratio_vs_base, luck_share_pct,
      lag(power_at) OVER (PARTITION BY id ORDER BY enh) AS prev_power
    FROM matrix
  )
  SELECT
    count(*),
    count(*) FILTER (WHERE enh > 0 AND prev_power IS NOT NULL AND power_at < prev_power),
    count(*) FILTER (
      WHERE enh = 10
        AND base_power > 0
        AND abs(ratio_vs_base - 2.5) > 0.02
    ),
    count(DISTINCT id) FILTER (
      WHERE enh = 0 AND luck_share_pct >= 55
    ),
    count(*) FILTER (
      WHERE power_at IS NULL OR power_at < 0 OR base_power < 0
    )
  INTO v_combo_count, v_bad_curve, v_bad_ratio, v_luck_heavy, v_neg_or_nan
  FROM stepped;

  v_ok := v_item_count >= 100 AND v_combo_count = v_item_count * 11;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'matrix',
    'test', 'all_gear_times_plus0_to_plus10',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'gear_items', v_item_count,
      'combinations', v_combo_count,
      'expected', v_item_count * 11
    )
  ));

  v_ok := v_bad_curve = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'curve',
    'test', 'power_monotonic_per_enhancement_step',
    'pass', v_ok,
    'detail', jsonb_build_object('non_monotonic_steps', v_bad_curve)
  ));

  v_ok := v_bad_ratio = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'curve',
    'test', 'plus10_is_approx_2_5x_base',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'bad_ratio_count', v_bad_ratio,
      'expected_multiplier', 2.5,
      'note', 'floor(base*(1+10*0.15))=floor(base*2.5)'
    )
  ));

  v_ok := v_neg_or_nan = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'safety',
    'test', 'no_negative_or_null_powers',
    'pass', v_ok,
    'detail', jsonb_build_object('bad_rows', v_neg_or_nan)
  ));

  -- Luck dominance inventory (warn threshold >=55% of base from luck*2)
  WITH gear AS (
    SELECT
      id, name, lower(rarity) AS rarity, equip_slot,
      attack, defense, health, luck,
      (COALESCE(attack,0)+COALESCE(defense,0)+(COALESCE(health,0)/10.0)+(COALESCE(luck,0)*2.0)) AS base_power
    FROM public.items
    WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace','shield')
  )
  SELECT count(*) INTO v_luck_heavy
  FROM gear
  WHERE base_power > 0 AND ((luck * 2.0) / base_power) >= 0.55;

  SELECT coalesce(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.luck_share_pct DESC), '[]'::jsonb)
  INTO v_worst_luck
  FROM (
    SELECT
      id, name, rarity, equip_slot, luck, attack, defense, health,
      round(((luck * 2.0) / NULLIF(base_power,0)) * 100.0, 2) AS luck_share_pct,
      floor(base_power)::bigint AS base_power,
      floor(base_power * 2.5)::bigint AS power_plus10
    FROM (
      SELECT
        id, name, lower(rarity) AS rarity, equip_slot,
        COALESCE(attack,0) AS attack,
        COALESCE(defense,0) AS defense,
        COALESCE(health,0) AS health,
        COALESCE(luck,0) AS luck,
        (COALESCE(attack,0)+COALESCE(defense,0)+(COALESCE(health,0)/10.0)+(COALESCE(luck,0)*2.0)) AS base_power
      FROM public.items
      WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace','shield')
    ) g
    WHERE base_power > 0
    ORDER BY ((luck * 2.0) / base_power) DESC
    LIMIT 15
  ) t;

  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'luck',
    'test', 'luck_share_audit_ge_55pct',
    'pass', true, -- informational; still listed
    'detail', jsonb_build_object(
      'luck_heavy_items', v_luck_heavy,
      'top_luck_share_items', v_worst_luck,
      'warn', CASE WHEN v_luck_heavy > 0
        THEN 'Luck*2 contributes >=55% base on some items — enhance ×2.5 amplifies luck hard'
        ELSE 'No item luck-share >=55%'
      END
    )
  ));

  -- Per-enhancement step sample for common sword/axe (role extras)
  SELECT coalesce(jsonb_agg(row_to_json(s)::jsonb ORDER BY s.id, s.enh), '[]'::jsonb)
  INTO v_sample
  FROM (
    SELECT
      id,
      enh,
      floor(base * (1 + enh * 0.15))::bigint AS power,
      round((1 + enh * 0.15)::numeric, 2) AS mult,
      luck,
      round(((luck * 2.0) / NULLIF(base,0)) * 100.0, 2) AS luck_share_pct
    FROM (
      SELECT id, COALESCE(luck,0) AS luck,
        (COALESCE(attack,0)+COALESCE(defense,0)+(COALESCE(health,0)/10.0)+(COALESCE(luck,0)*2.0)) AS base
      FROM public.items
      WHERE id IN ('wpn_sword_common','wpn_axe_common','wpn_staff_common','wpn_dagger_common')
    ) i
    CROSS JOIN generate_series(0, 10) enh
  ) s;

  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'sample',
    'test', 'common_weapon_roles_full_plus_curve',
    'pass', true,
    'detail', jsonb_build_object('curves', v_sample)
  ));

  -- Full sets: for each rarity, best power-per-slot at +0 and +10
  v_mythic_set_10 := NULL;
  v_common_set_0 := NULL;

  FOR v_rarity IN
    SELECT unnest(ARRAY['common','uncommon','rare','epic','legendary','mythic'])
  LOOP
    WITH ranked AS (
      SELECT
        id, equip_slot,
        (COALESCE(attack,0)+COALESCE(defense,0)+(COALESCE(health,0)/10.0)+(COALESCE(luck,0)*2.0)) AS base_power,
        COALESCE(luck,0) AS luck,
        row_number() OVER (
          PARTITION BY equip_slot
          ORDER BY (COALESCE(attack,0)+COALESCE(defense,0)+(COALESCE(health,0)/10.0)+(COALESCE(luck,0)*2.0)) DESC, id
        ) AS rn
      FROM public.items
      WHERE lower(rarity) = v_rarity
        AND equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace')
    ),
    best AS (
      SELECT * FROM ranked WHERE rn = 1
    )
    SELECT
      coalesce(sum(base_power), 0),
      coalesce(sum(floor(base_power * 2.5)), 0),
      CASE WHEN sum(base_power) > 0
        THEN round((sum(luck * 2.0) / sum(base_power)) * 100.0, 2)
        ELSE 0
      END,
      coalesce(jsonb_agg(jsonb_build_object(
        'slot', equip_slot,
        'id', id,
        'base', floor(base_power),
        'plus10', floor(base_power * 2.5),
        'luck', luck
      ) ORDER BY equip_slot), '[]'::jsonb)
    INTO v_set_power_0, v_set_power_10, v_set_luck_share, v_top_items
    FROM best;

    IF v_rarity = 'common' THEN
      v_common_set_0 := v_set_power_0;
    END IF;
    IF v_rarity = 'mythic' THEN
      v_mythic_set_10 := v_set_power_10;
    END IF;

    v_sets := v_sets || jsonb_build_array(jsonb_build_object(
      'rarity', v_rarity,
      'slots', 8,
      'set_power_plus0', v_set_power_0,
      'set_power_plus10', v_set_power_10,
      'set_multiplier', CASE WHEN v_set_power_0 > 0
        THEN round(v_set_power_10 / v_set_power_0, 4)
        ELSE NULL END,
      'set_luck_share_pct', v_set_luck_share,
      'pieces', v_top_items
    ));
  END LOOP;

  v_ok := jsonb_array_length(v_sets) = 6;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'full_set',
    'test', 'best_power_set_each_rarity_plus0_and_plus10',
    'pass', v_ok,
    'detail', jsonb_build_object('sets', v_sets)
  ));

  -- Cross-tier: mythic +10 best set vs common +0 best set
  IF v_common_set_0 IS NOT NULL AND v_common_set_0 > 0 AND v_mythic_set_10 IS NOT NULL THEN
    v_cross_ratio := round(v_mythic_set_10 / v_common_set_0, 2);
  ELSE
    v_cross_ratio := NULL;
  END IF;

  -- Soft balance gate: mythic+10 / common+0 should be large but not absurd (>500x = red flag)
  v_ok := v_cross_ratio IS NOT NULL AND v_cross_ratio BETWEEN 5 AND 500;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'balance',
    'test', 'mythic_plus10_set_vs_common_plus0_set_ratio',
    'pass', v_ok,
    'detail', jsonb_build_object(
      'common_set_plus0', v_common_set_0,
      'mythic_set_plus10', v_mythic_set_10,
      'ratio', v_cross_ratio,
      'band', '5..500'
    )
  ));

  -- Full luck-max set at +10 (worst-case luck amplify)
  WITH ranked AS (
    SELECT
      id, lower(rarity) AS rarity, equip_slot, luck,
      (COALESCE(attack,0)+COALESCE(defense,0)+(COALESCE(health,0)/10.0)+(COALESCE(luck,0)*2.0)) AS base_power,
      row_number() OVER (
        PARTITION BY lower(rarity), equip_slot
        ORDER BY luck DESC, id
      ) AS rn
    FROM public.items
    WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace')
  ),
  best AS (
    SELECT * FROM ranked WHERE rn = 1
  ),
  agg AS (
    SELECT
      rarity,
      sum(floor(base_power * 2.5)) AS set_plus10,
      CASE WHEN sum(base_power) > 0
        THEN round((sum(luck * 2.0) / sum(base_power)) * 100.0, 2)
        ELSE 0 END AS luck_share_pct
    FROM best
    GROUP BY rarity
  )
  SELECT coalesce(jsonb_agg(row_to_json(a)::jsonb ORDER BY a.rarity), '[]'::jsonb)
  INTO v_top_items
  FROM agg a;

  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'luck',
    'test', 'max_luck_full_sets_at_plus10',
    'pass', true,
    'detail', jsonb_build_object('sets', v_top_items)
  ));

  -- Client/DB formula parity: calculate_item_power exists and matches floor formula
  SELECT count(*) INTO v_n
  FROM public.items i
  CROSS JOIN generate_series(0, 10) enh
  WHERE i.equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace','shield')
    AND floor(public.calculate_item_power(i.id, enh))
      IS DISTINCT FROM
      floor(
        (COALESCE(i.attack,0)+COALESCE(i.defense,0)+(COALESCE(i.health,0)/10.0)+(COALESCE(i.luck,0)*2.0))
        * (1 + enh * 0.15)
      );
  v_ok := v_n = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'parity',
    'test', 'calculate_item_power_matches_client_formula_all_plus',
    'pass', v_ok,
    'detail', jsonb_build_object('mismatches', v_n, 'checked', v_item_count * 11)
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
    'gear_items', v_item_count,
    'combinations_checked', v_combo_count,
    'enhancement_mult_table', jsonb_build_object(
      '+0', 1.00, '+1', 1.15, '+2', 1.30, '+3', 1.45, '+4', 1.60,
      '+5', 1.75, '+6', 1.90, '+7', 2.05, '+8', 2.20, '+9', 2.35, '+10', 2.50
    ),
    'tests', v_tests,
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_smoke_item_enhancement_matrix() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_item_enhancement_matrix() TO service_role;
GRANT EXECUTE ON FUNCTION public.qa_smoke_item_enhancement_matrix() TO authenticated;
