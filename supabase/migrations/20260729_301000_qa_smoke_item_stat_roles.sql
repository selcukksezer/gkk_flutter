-- Smoke: item role extras / catalog diversity / inventory join / power formula.
-- Run: SELECT public.qa_smoke_item_stat_roles();

CREATE OR REPLACE FUNCTION public.qa_smoke_item_stat_roles()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_tests jsonb := '[]'::jsonb;
  v_ok boolean;
  v_n int;
  v_sword_atk int;
  v_axe_luck int;
  v_staff_hp int;
  v_dagger_luck int;
  v_sword_luck int;
  v_mitts_luck int;
  v_bracers_atk int;
  v_qa_auth uuid;
  v_row_id uuid;
  v_inv_atk int;
  v_cat_atk int;
  v_inv_desc text;
  v_eq_sword int;
  v_eq_axe int;
  v_passed int;
  v_total int;
BEGIN
  -- 1) rarity+slot unique tuples
  SELECT count(*) INTO v_n
  FROM (
    SELECT lower(rarity), equip_slot
    FROM public.items
    WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace','shield')
    GROUP BY 1, 2
    HAVING count(*) >= 2
      AND count(DISTINCT (attack, defense, health, luck)) < count(*)
  ) bad;
  v_ok := v_n = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'catalog',
    'test', 'rarity_slot_groups_unique_stat_tuples',
    'pass', v_ok,
    'detail', jsonb_build_object('duplicate_groups', v_n)
  ));

  -- 2) common weapons unique
  SELECT count(DISTINCT (attack, defense, health, luck)) INTO v_n
  FROM public.items
  WHERE lower(rarity) = 'common' AND equip_slot = 'weapon';
  v_ok := v_n >= 4;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'catalog',
    'test', 'common_weapons_four_unique_roles',
    'pass', v_ok,
    'detail', jsonb_build_object('unique_combos', v_n)
  ));

  SELECT attack, luck INTO v_sword_atk, v_sword_luck FROM public.items WHERE id = 'wpn_sword_common';
  SELECT luck INTO v_axe_luck FROM public.items WHERE id = 'wpn_axe_common';
  SELECT health INTO v_staff_hp FROM public.items WHERE id = 'wpn_staff_common';
  SELECT luck INTO v_dagger_luck FROM public.items WHERE id = 'wpn_dagger_common';
  SELECT luck INTO v_mitts_luck FROM public.items WHERE id = 'gloves_mitts_common';
  SELECT attack INTO v_bracers_atk FROM public.items WHERE id = 'gloves_bracers_common';

  -- 3) sword highest atk
  v_ok := v_sword_atk IS NOT NULL AND v_sword_atk = (
    SELECT max(attack) FROM public.items WHERE lower(rarity)='common' AND equip_slot='weapon'
  );
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'roles',
    'test', 'sword_highest_common_weapon_attack',
    'pass', v_ok,
    'detail', jsonb_build_object('sword_attack', v_sword_atk)
  ));

  -- 4) axe highest luck
  v_ok := v_axe_luck IS NOT NULL AND v_axe_luck = (
    SELECT max(luck) FROM public.items WHERE lower(rarity)='common' AND equip_slot='weapon'
  );
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'roles',
    'test', 'axe_highest_common_weapon_luck',
    'pass', v_ok,
    'detail', jsonb_build_object('axe_luck', v_axe_luck)
  ));

  -- 5) staff health
  v_ok := coalesce(v_staff_hp, 0) >= 200;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'roles',
    'test', 'staff_has_health_extra',
    'pass', v_ok,
    'detail', jsonb_build_object('staff_health', v_staff_hp)
  ));

  -- 6) dagger luck > sword luck
  v_ok := coalesce(v_dagger_luck, 0) > coalesce(v_sword_luck, 0);
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'roles',
    'test', 'dagger_luck_above_sword',
    'pass', v_ok,
    'detail', jsonb_build_object('dagger_luck', v_dagger_luck, 'sword_luck', v_sword_luck)
  ));

  -- 7) gloves not identical
  v_ok := EXISTS (
    SELECT 1
    FROM public.items a
    JOIN public.items b ON b.id = 'gloves_bracers_common'
    WHERE a.id = 'gloves_mitts_common'
      AND (a.attack, a.defense, a.health, a.luck)
       IS DISTINCT FROM (b.attack, b.defense, b.health, b.luck)
  );
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'roles',
    'test', 'gloves_mitts_vs_bracers_not_identical',
    'pass', v_ok,
    'detail', jsonb_build_object('mitts_luck', v_mitts_luck, 'bracers_attack', v_bracers_atk)
  ));

  -- 8) Ekstra description lines
  SELECT count(*) INTO v_n
  FROM public.items
  WHERE id IN (
    'wpn_sword_common','wpn_axe_common','wpn_dagger_common','wpn_staff_common',
    'gloves_mitts_common','gloves_bracers_common'
  )
    AND description ILIKE '%Ekstra:%';
  v_ok := v_n = 6;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'flavor',
    'test', 'seeded_items_have_ekstra_description',
    'pass', v_ok,
    'detail', jsonb_build_object('with_extra_line', v_n, 'expected', 6)
  ));

  -- 9) power formula
  SELECT count(*) INTO v_n
  FROM public.items
  WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace','shield')
    AND power IS DISTINCT FROM (attack + defense + (health / 10) + (luck * 2));
  v_ok := v_n = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'power',
    'test', 'catalog_power_matches_formula',
    'pass', v_ok,
    'detail', jsonb_build_object('mismatches', v_n)
  ));

  -- 10) no exact clones
  SELECT count(*) INTO v_n
  FROM (
    SELECT lower(rarity), equip_slot, attack, defense, health, luck
    FROM public.items
    WHERE equip_slot IN ('weapon','head','chest','legs','boots','gloves','ring','necklace','shield')
    GROUP BY 1,2,3,4,5,6
    HAVING count(*) > 1
  ) d;
  v_ok := v_n = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'catalog',
    'test', 'no_exact_stat_clones',
    'pass', v_ok,
    'detail', jsonb_build_object('clone_groups', v_n)
  ));

  -- 11) all rarity weapons unique
  SELECT count(*) INTO v_n
  FROM (
    SELECT lower(rarity)
    FROM public.items
    WHERE equip_slot = 'weapon'
    GROUP BY 1
    HAVING count(DISTINCT (attack, defense, health, luck)) < count(*)
  ) bad;
  v_ok := v_n = 0;
  v_tests := v_tests || jsonb_build_array(jsonb_build_object(
    'area', 'catalog',
    'test', 'all_rarity_weapons_unique',
    'pass', v_ok,
    'detail', jsonb_build_object('bad_rarities', v_n)
  ));

  -- 12-13) live inventory join + equip power diff
  SELECT auth_id INTO v_qa_auth
  FROM public.users
  WHERE email IN (
      'qa_smoke_p0@gkk.test',
      'qa_smoke_primary@gkk.test',
      'qa_bot_1@sim.local'
    )
    OR username IN ('qa_smoke_p0', 'qa_smoke_primary', 'qa_bot_1')
  ORDER BY CASE
    WHEN username = 'qa_smoke_p0' THEN 0
    WHEN username = 'qa_smoke_primary' THEN 1
    ELSE 2
  END
  LIMIT 1;

  IF v_qa_auth IS NULL THEN
    v_tests := v_tests || jsonb_build_array(jsonb_build_object(
      'area', 'inventory',
      'test', 'qa_user_present_for_live_join',
      'pass', false,
      'detail', jsonb_build_object('error', 'qa_smoke_p0 missing')
    ));
  ELSE
    DECLARE
      v_free_slot int;
    BEGIN
      SELECT s.slot INTO v_free_slot
      FROM generate_series(0, 19) AS s(slot)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.inventory inv
        WHERE inv.user_id = v_qa_auth
          AND coalesce(inv.is_equipped, false) = false
          AND inv.slot_position = s.slot
      )
      ORDER BY s.slot
      LIMIT 1;

      IF v_free_slot IS NULL THEN
        v_tests := v_tests || jsonb_build_array(jsonb_build_object(
          'area', 'inventory',
          'test', 'inventory_join_returns_catalog_attack_and_extra',
          'pass', false,
          'detail', jsonb_build_object('error', 'no free inventory slot on QA user')
        ));
      ELSE
        INSERT INTO public.inventory (user_id, item_id, quantity, is_equipped, enhancement_level, slot_position)
        VALUES (v_qa_auth, 'wpn_axe_common', 1, false, 0, v_free_slot)
        RETURNING row_id INTO v_row_id;

        SELECT COALESCE(it.attack, 0), it.description
        INTO v_inv_atk, v_inv_desc
        FROM public.inventory inv
        JOIN public.items it ON it.id = inv.item_id
        WHERE inv.row_id = v_row_id;

        SELECT attack INTO v_cat_atk FROM public.items WHERE id = 'wpn_axe_common';
        v_ok := v_inv_atk = v_cat_atk AND v_inv_atk = 850 AND coalesce(v_inv_desc,'') ILIKE '%Ekstra:%';
        v_tests := v_tests || jsonb_build_array(jsonb_build_object(
          'area', 'inventory',
          'test', 'inventory_join_returns_catalog_attack_and_extra',
          'pass', v_ok,
          'detail', jsonb_build_object(
            'inventory_attack', v_inv_atk,
            'catalog_attack', v_cat_atk,
            'slot', v_free_slot,
            'has_extra_in_desc', coalesce(v_inv_desc,'') ILIKE '%Ekstra:%'
          )
        ));

        SELECT (attack + defense + (health / 10) + (luck * 2)) INTO v_eq_sword
        FROM public.items WHERE id = 'wpn_sword_common';
        SELECT (attack + defense + (health / 10) + (luck * 2)) INTO v_eq_axe
        FROM public.items WHERE id = 'wpn_axe_common';
        v_ok := v_eq_sword IS DISTINCT FROM v_eq_axe AND v_eq_axe > v_eq_sword;
        v_tests := v_tests || jsonb_build_array(jsonb_build_object(
          'area', 'combat',
          'test', 'equip_power_differs_between_common_weapons',
          'pass', v_ok,
          'detail', jsonb_build_object(
            'sword_equip_power', v_eq_sword,
            'axe_equip_power', v_eq_axe
          )
        ));

        DELETE FROM public.inventory WHERE row_id = v_row_id;
      END IF;
    END;
  END IF;

  SELECT
    count(*) FILTER (WHERE (t->>'pass')::boolean),
    count(*)
  INTO v_passed, v_total
  FROM jsonb_array_elements(v_tests) t;

  RETURN jsonb_build_object(
    'verdict', CASE WHEN v_passed = v_total THEN 'PASS' ELSE 'FAIL' END,
    'passed', v_passed,
    'total', v_total,
    'tests', v_tests,
    'checked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_smoke_item_stat_roles() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_item_stat_roles() TO service_role;
GRANT EXECUTE ON FUNCTION public.qa_smoke_item_stat_roles() TO authenticated;
