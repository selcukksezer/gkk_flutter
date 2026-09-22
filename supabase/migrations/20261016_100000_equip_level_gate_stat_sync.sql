-- Equip level gate + equipment stat materialization (Model A).
-- Tracks equip_bonus_* so level-up / allocate / reset stay correct.

BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS equip_bonus_attack INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS equip_bonus_defense INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS equip_bonus_health INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS equip_bonus_luck INTEGER NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.sync_user_equipment_stats(p_auth_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_eq_atk INTEGER := 0;
  v_eq_def INTEGER := 0;
  v_eq_hp INTEGER := 0;
  v_eq_luck INTEGER := 0;
  v_base_atk INTEGER;
  v_base_def INTEGER;
  v_base_hp INTEGER;
  v_base_luck INTEGER;
  v_new_atk INTEGER;
  v_new_def INTEGER;
  v_new_hp INTEGER;
  v_new_luck INTEGER;
  v_cur_health INTEGER;
  v_new_power NUMERIC;
BEGIN
  IF p_auth_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = p_auth_id) THEN
    RETURN;
  END IF;

  SELECT
    COALESCE(SUM(floor(COALESCE(it.attack, 0) * (1.0 + COALESCE(i.enhancement_level, 0) * 0.15))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.defense, 0) * (1.0 + COALESCE(i.enhancement_level, 0) * 0.15))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.health, 0) * (1.0 + COALESCE(i.enhancement_level, 0) * 0.15))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.luck, 0) * (1.0 + COALESCE(i.enhancement_level, 0) * 0.15))), 0)::INTEGER
  INTO v_eq_atk, v_eq_def, v_eq_hp, v_eq_luck
  FROM public.inventory i
  JOIN public.items it ON it.id = i.item_id
  WHERE i.user_id = p_auth_id
    AND i.is_equipped = TRUE;

  SELECT
    GREATEST(0, COALESCE(attack, 0) - COALESCE(equip_bonus_attack, 0)),
    GREATEST(0, COALESCE(defense, 0) - COALESCE(equip_bonus_defense, 0)),
    GREATEST(1, COALESCE(max_health, 100) - COALESCE(equip_bonus_health, 0)),
    GREATEST(0, COALESCE(luck, 0) - COALESCE(equip_bonus_luck, 0)),
    COALESCE(health, 0)
  INTO v_base_atk, v_base_def, v_base_hp, v_base_luck, v_cur_health
  FROM public.users
  WHERE auth_id = p_auth_id
  FOR UPDATE;

  v_new_atk := v_base_atk + v_eq_atk;
  v_new_def := v_base_def + v_eq_def;
  v_new_hp := v_base_hp + v_eq_hp;
  v_new_luck := v_base_luck + v_eq_luck;
  v_new_power := public.calculate_user_total_power(p_auth_id);

  UPDATE public.users
  SET
    attack = v_new_atk,
    defense = v_new_def,
    max_health = v_new_hp,
    luck = v_new_luck,
    health = LEAST(GREATEST(1, v_cur_health), v_new_hp),
    equip_bonus_attack = v_eq_atk,
    equip_bonus_defense = v_eq_def,
    equip_bonus_health = v_eq_hp,
    equip_bonus_luck = v_eq_luck,
    power = v_new_power::INTEGER,
    health_last_updated = NOW(),
    updated_at = NOW()
  WHERE auth_id = p_auth_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.equip_item(p_row_id uuid, p_slot text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_item_record RECORD;
  v_player_level INTEGER;
  v_target_slot INTEGER;
  v_required_level INTEGER;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT
    inv.row_id,
    inv.item_id,
    inv.slot_position,
    inv.is_equipped,
    it.type,
    it.equip_slot,
    it.can_enhance,
    COALESCE(it.required_level, 1) AS required_level
  INTO v_item_record
  FROM public.inventory inv
  LEFT JOIN public.items it ON inv.item_id = it.id
  WHERE inv.row_id = p_row_id AND inv.user_id = v_user_id
  LIMIT 1;

  IF v_item_record.row_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned by player');
  END IF;

  IF lower(COALESCE(v_item_record.type, '')) IN (
    'potion', 'food', 'buff', 'consumable', 'resource', 'quest_item', 'misc'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu eşya kuşanılamaz (consumable)');
  END IF;

  IF v_item_record.equip_slot IS NULL OR v_item_record.equip_slot = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu eşya kuşanılamaz (equip_slot mismatch)');
  END IF;

  IF lower(COALESCE(v_item_record.equip_slot, '')) != lower(COALESCE(p_slot, '')) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yanlış slot. Bu eşya şuraya gidemez: ' || p_slot
    );
  END IF;

  SELECT COALESCE(level, 1) INTO v_player_level
  FROM public.users
  WHERE auth_id = v_user_id;

  v_required_level := COALESCE(v_item_record.required_level, 1);
  IF COALESCE(v_player_level, 1) < v_required_level THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Level yetersiz. Gereken: ' || v_required_level
    );
  END IF;

  v_target_slot := v_item_record.slot_position;

  UPDATE public.inventory
  SET slot_position = NULL,
      updated_at = NOW()
  WHERE row_id = p_row_id;

  UPDATE public.inventory
  SET is_equipped = FALSE,
      equip_slot = NULL,
      slot_position = v_target_slot,
      updated_at = NOW()
  WHERE user_id = v_user_id
    AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, ''))
    AND is_equipped = TRUE
    AND row_id != p_row_id;

  UPDATE public.inventory
  SET is_equipped = TRUE,
      equip_slot = p_slot,
      slot_position = NULL,
      updated_at = NOW()
  WHERE row_id = p_row_id;

  PERFORM public.sync_user_equipment_stats(v_user_id);

  RETURN jsonb_build_object('success', true, 'row_id', p_row_id, 'slot', p_slot);
END;
$$;

CREATE OR REPLACE FUNCTION public.unequip_item(
  p_slot text,
  p_target_slot integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
  v_row_id uuid;
  v_free_slot integer;
  v_capacity integer := 20;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT row_id
  INTO v_row_id
  FROM public.inventory
  WHERE user_id = v_user_id
    AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, ''))
    AND is_equipped = TRUE
  LIMIT 1;

  IF v_row_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Item not found, not owned, or not equipped'
    );
  END IF;

  IF p_target_slot IS NOT NULL THEN
    IF p_target_slot < 0 OR p_target_slot >= v_capacity THEN
      RETURN jsonb_build_object('success', false, 'error', 'Gecersiz envanter slotu');
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.inventory i
      WHERE i.user_id = v_user_id
        AND i.is_equipped = FALSE
        AND i.slot_position = p_target_slot
        AND i.row_id <> v_row_id
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Hedef slot dolu — benzer slottaki esyayla degistir'
      );
    END IF;

    v_free_slot := p_target_slot;
  ELSE
    SELECT s.slot
    INTO v_free_slot
    FROM generate_series(0, v_capacity - 1) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.inventory i
      WHERE i.user_id = v_user_id
        AND i.is_equipped = FALSE
        AND i.slot_position = s.slot
    )
    ORDER BY s.slot
    LIMIT 1;

    IF v_free_slot IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Envanter dolu — benzer slottaki esyayla degistir'
      );
    END IF;
  END IF;

  UPDATE public.inventory
  SET is_equipped = FALSE,
      equip_slot = NULL,
      slot_position = v_free_slot,
      updated_at = NOW()
  WHERE row_id = v_row_id;

  PERFORM public.sync_user_equipment_stats(v_user_id);

  RETURN jsonb_build_object(
    'success', true,
    'slot', p_slot,
    'slot_position', v_free_slot
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.swap_equip_with_slot(p_equip_slot text, p_target_slot integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_equip_row uuid;
  v_inv_row uuid;
  v_item_meta RECORD;
  v_player_level INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_equip_slot IS NULL OR p_target_slot IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid args');
  END IF;

  SELECT row_id INTO v_equip_row FROM public.inventory
    WHERE user_id = v_user_id AND is_equipped = TRUE
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_equip_slot, ''))
    LIMIT 1 FOR UPDATE;

  SELECT row_id INTO v_inv_row FROM public.inventory
    WHERE user_id = v_user_id AND slot_position = p_target_slot
    LIMIT 1 FOR UPDATE;

  IF v_inv_row IS NOT NULL THEN
    SELECT
      it.type,
      it.equip_slot,
      COALESCE(it.required_level, 1) AS required_level
    INTO v_item_meta
    FROM public.inventory inv
    LEFT JOIN public.items it ON inv.item_id = it.id
    WHERE inv.row_id = v_inv_row;

    IF lower(COALESCE(v_item_meta.type, '')) IN (
      'potion', 'food', 'buff', 'consumable', 'resource', 'quest_item', 'misc'
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Bu eşya kuşanılamaz (consumable)');
    END IF;

    IF v_item_meta.equip_slot IS NULL OR v_item_meta.equip_slot = '' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Bu eşya kuşanılamaz (equip_slot mismatch)');
    END IF;

    IF lower(COALESCE(v_item_meta.equip_slot, '')) != lower(COALESCE(p_equip_slot, '')) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Yanlış slot. Bu eşya şuraya gidemez: ' || p_equip_slot
      );
    END IF;

    SELECT COALESCE(level, 1) INTO v_player_level
    FROM public.users WHERE auth_id = v_user_id;

    IF COALESCE(v_player_level, 1) < COALESCE(v_item_meta.required_level, 1) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Level yetersiz. Gereken: ' || COALESCE(v_item_meta.required_level, 1)
      );
    END IF;
  END IF;

  IF v_equip_row IS NOT NULL AND v_inv_row IS NOT NULL THEN
    UPDATE public.inventory SET slot_position = NULL, updated_at = NOW()
      WHERE row_id = v_inv_row;

    UPDATE public.inventory
    SET slot_position = p_target_slot, is_equipped = FALSE, equip_slot = NULL, updated_at = NOW()
      WHERE row_id = v_equip_row;

    UPDATE public.inventory
    SET slot_position = NULL, is_equipped = TRUE, equip_slot = p_equip_slot, updated_at = NOW()
      WHERE row_id = v_inv_row;

    PERFORM public.sync_user_equipment_stats(v_user_id);

    RETURN jsonb_build_object('success', true, 'moved', jsonb_build_array(
      jsonb_build_object('row_id', v_inv_row, 'slot', NULL::int),
      jsonb_build_object('row_id', v_equip_row, 'slot', p_target_slot)
    ));
  END IF;

  IF v_equip_row IS NOT NULL AND v_inv_row IS NULL THEN
    UPDATE public.inventory
    SET slot_position = p_target_slot, is_equipped = FALSE, equip_slot = NULL, updated_at = NOW()
      WHERE row_id = v_equip_row;

    PERFORM public.sync_user_equipment_stats(v_user_id);

    RETURN jsonb_build_object(
      'success', true,
      'moved', jsonb_build_array(jsonb_build_object('row_id', v_equip_row, 'slot', p_target_slot))
    );
  END IF;

  IF v_equip_row IS NULL AND v_inv_row IS NOT NULL THEN
    UPDATE public.inventory
    SET is_equipped = FALSE, equip_slot = NULL, slot_position = NULL, updated_at = NOW()
    WHERE user_id = v_user_id
      AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_equip_slot, ''))
      AND is_equipped = TRUE
      AND row_id != v_inv_row;

    UPDATE public.inventory
    SET slot_position = NULL, is_equipped = TRUE, equip_slot = p_equip_slot, updated_at = NOW()
      WHERE row_id = v_inv_row;

    PERFORM public.sync_user_equipment_stats(v_user_id);

    RETURN jsonb_build_object(
      'success', true,
      'moved', jsonb_build_array(jsonb_build_object('row_id', v_inv_row, 'slot', NULL))
    );
  END IF;

  RETURN jsonb_build_object('success', false, 'error', 'No items to swap');
END;
$$;

-- enhance_item: resync stats when enhanced row is equipped / destroyed
DO $$
DECLARE
  v_def TEXT;
  v_old TEXT := $old$
  RETURN jsonb_build_object(
    'success', v_success,
    'destroyed', v_destroyed,
    'new_level', v_new_level,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1),
    'debug', v_debug
  );
END;
$old$;
  v_new TEXT := $new$
  IF EXISTS (
    SELECT 1 FROM public.inventory
    WHERE row_id = p_row_id AND is_equipped = TRUE
  ) OR v_destroyed THEN
    PERFORM public.sync_user_equipment_stats(p_player_id);
  END IF;

  RETURN jsonb_build_object(
    'success', v_success,
    'destroyed', v_destroyed,
    'new_level', v_new_level,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1),
    'debug', v_debug
  );
END;
$new$;
BEGIN
  SELECT pg_get_functiondef('public.enhance_item(uuid, uuid, text)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL THEN
    RAISE NOTICE 'enhance_item not found — skip sync patch';
    RETURN;
  END IF;

  IF position('sync_user_equipment_stats(p_player_id)' in v_def) > 0 THEN
    RAISE NOTICE 'enhance_item already patched for equip sync';
    RETURN;
  END IF;

  IF position(v_old in v_def) = 0 THEN
    RAISE NOTICE 'enhance_item return marker not found — skip sync patch';
    RETURN;
  END IF;

  v_def := replace(v_def, v_old, v_new);
  EXECUTE v_def;
END;
$$;

-- One-shot backfill for currently equipped gear.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT DISTINCT user_id AS auth_id
    FROM public.inventory
    WHERE is_equipped = TRUE
  LOOP
    PERFORM public.sync_user_equipment_stats(r.auth_id);
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_user_equipment_stats(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.equip_item(uuid, text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.unequip_item(text, integer) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.swap_equip_with_slot(text, integer) TO authenticated, anon, service_role;

COMMIT;
