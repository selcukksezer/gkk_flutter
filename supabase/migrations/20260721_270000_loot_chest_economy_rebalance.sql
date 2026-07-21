-- Loot chest economy rebalance + drop-rate honesty
--
-- Problems:
-- 1) jackpot_rate is 0–1 fraction; Flutter loot hub showed N:%0.0 (fixed in Dart)
-- 2) get_loot_box_drops computed % only among preview rows (leg/myth only) → inflated
-- 3) Gem chest weights ~62% common → ~200💎 opens feel worthless vs gem packs
--
-- Targets (gem shop boxes box_01..box_25):
--   common 35% | uncommon 28% | rare 22% | epic 10% | legendary 3.5% | mythic 1.5%
-- Soft pity (gems only): after 8 consecutive common/uncommon opens on same box → force rare+

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Rebalance weights for active shop gem boxes
-- ---------------------------------------------------------------------------
UPDATE public.loot_box_drop_entries e
SET
  weight = (
    CASE COALESCE(i.rarity, 'common')
      WHEN 'mythic' THEN 0.082
      WHEN 'legendary' THEN 0.180
      WHEN 'epic' THEN 0.495
      WHEN 'rare' THEN 1.085
      WHEN 'uncommon' THEN 1.435
      ELSE 1.500
    END
  ) * (1.0 + (b.display_order::numeric / 260.0)),
  show_in_preview = (COALESCE(i.rarity, 'common') IN ('rare', 'epic', 'legendary', 'mythic')),
  updated_at = now()
FROM public.loot_box_configs b, public.items i
WHERE e.box_id = b.id
  AND e.item_id = i.id
  AND b.is_active = TRUE
  AND b.currency_type = 'gems'
  AND b.id LIKE 'box_%'
  AND b.display_order BETWEEN 1 AND 25;

-- Mild gold-box mid-tier lift (still a sink vs gem boxes)
UPDATE public.loot_box_drop_entries e
SET
  weight = (
    CASE COALESCE(i.rarity, 'common')
      WHEN 'mythic' THEN 0.012
      WHEN 'legendary' THEN 0.035
      WHEN 'epic' THEN 0.140
      WHEN 'rare' THEN 0.550
      WHEN 'uncommon' THEN 1.400
      ELSE 5.500
    END
  ) * (1.0 + (b.display_order::numeric / 260.0)),
  show_in_preview = (COALESCE(i.rarity, 'common') IN ('rare', 'epic', 'legendary', 'mythic')),
  updated_at = now()
FROM public.loot_box_configs b, public.items i
WHERE e.box_id = b.id
  AND e.item_id = i.id
  AND b.is_active = TRUE
  AND b.currency_type = 'gold'
  AND b.id LIKE 'box_%'
  AND b.display_order BETWEEN 26 AND 50;

-- ---------------------------------------------------------------------------
-- 2) Honest drop_rate: % of FULL active pool, not preview-only window
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_loot_box_drops(p_box_id text)
 RETURNS TABLE(
   item_id text,
   item_name text,
   icon text,
   rarity text,
   min_quantity integer,
   max_quantity integer,
   weight numeric,
   drop_rate numeric
 )
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH pool AS (
    SELECT COALESCE(SUM(e.weight), 0)::numeric AS total_weight
    FROM public.loot_box_drop_entries e
    WHERE e.box_id = p_box_id
      AND e.is_active = TRUE
  )
  SELECT
    e.item_id,
    i.name AS item_name,
    i.icon,
    COALESCE(i.rarity, 'common') AS rarity,
    e.min_quantity,
    e.max_quantity,
    e.weight,
    (e.weight / NULLIF(pool.total_weight, 0) * 100)::numeric AS drop_rate
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  CROSS JOIN pool
  WHERE e.box_id = p_box_id
    AND e.is_active = TRUE
    AND e.show_in_preview = TRUE
  ORDER BY drop_rate DESC, item_name ASC;
$function$;

-- ---------------------------------------------------------------------------
-- 3) open_loot_box: soft pity for gem chests
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.open_loot_box(p_box_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_box RECORD;
  v_drop RECORD;
  v_balance_ok BOOLEAN := FALSE;
  v_reward_qty INTEGER;
  v_add_result JSONB;
  v_has_free_slot BOOLEAN := FALSE;
  v_force_rare_plus BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT *
  INTO v_box
  FROM public.loot_box_configs
  WHERE id = p_box_id
    AND is_active = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kasa bulunamadi veya pasif.');
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.inventory i
      WHERE i.user_id = v_user_id
        AND i.slot_position = s.slot
        AND i.is_equipped = FALSE
    )
  )
  INTO v_has_free_slot;

  IF COALESCE(v_has_free_slot, FALSE) = FALSE THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Envanter dolu. Kasa acmak icin once bos slot acmalisin.'
    );
  END IF;

  IF v_box.currency_type = 'gems' THEN
    UPDATE public.users
    SET gems = gems - v_box.price
    WHERE auth_id = v_user_id
      AND gems >= v_box.price
    RETURNING TRUE INTO v_balance_ok;
  ELSE
    UPDATE public.users
    SET gold = gold - v_box.price
    WHERE auth_id = v_user_id
      AND gold >= v_box.price
    RETURNING TRUE INTO v_balance_ok;
  END IF;

  IF COALESCE(v_balance_ok, FALSE) = FALSE THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz bakiye.');
  END IF;

  -- Soft pity: 8 consecutive common/uncommon on this gem box → force rare+
  IF v_box.currency_type = 'gems' THEN
    SELECT
      COUNT(*) = 8
      AND COUNT(*) FILTER (
        WHERE recent.rarity IN ('common', 'uncommon')
      ) = 8
    INTO v_force_rare_plus
    FROM (
      SELECT COALESCE(i.rarity, 'common') AS rarity
      FROM public.player_loot_box_logs l
      LEFT JOIN public.items i ON i.id = l.reward_item_id
      WHERE l.user_id = v_user_id
        AND l.box_id = p_box_id
      ORDER BY l.created_at DESC
      LIMIT 8
    ) recent;

    v_force_rare_plus := COALESCE(v_force_rare_plus, FALSE);
  END IF;

  SELECT
    e.item_id,
    e.weight,
    e.min_quantity,
    e.max_quantity,
    i.name AS item_name,
    i.icon,
    COALESCE(i.is_stackable, FALSE) AS is_stackable,
    COALESCE(i.rarity, 'common') AS rarity
  INTO v_drop
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  WHERE e.box_id = p_box_id
    AND e.is_active = TRUE
    AND (
      NOT v_force_rare_plus
      OR COALESCE(i.rarity, 'common') IN ('rare', 'epic', 'legendary', 'mythic')
    )
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    -- Pity filter emptied pool (should not happen); fall back to full pool
    SELECT
      e.item_id,
      e.weight,
      e.min_quantity,
      e.max_quantity,
      i.name AS item_name,
      i.icon,
      COALESCE(i.is_stackable, FALSE) AS is_stackable,
      COALESCE(i.rarity, 'common') AS rarity
    INTO v_drop
    FROM public.loot_box_drop_entries e
    JOIN public.items i ON i.id = e.item_id
    WHERE e.box_id = p_box_id
      AND e.is_active = TRUE
    ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.weight, 1e-9)
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    IF v_box.currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + v_box.price WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + v_box.price WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Bu kasa icin drop tanimi yok.');
  END IF;

  v_reward_qty := FLOOR(random() * (v_drop.max_quantity - v_drop.min_quantity + 1) + v_drop.min_quantity)::INTEGER;
  v_reward_qty := GREATEST(1, FLOOR(v_reward_qty * COALESCE(v_box.reward_multiplier, 1))::INTEGER);

  IF COALESCE(v_drop.is_stackable, FALSE) = FALSE THEN
    v_reward_qty := 1;
  END IF;

  v_add_result := public.add_inventory_item_v2(
    jsonb_build_object(
      'item_id', v_drop.item_id,
      'quantity', v_reward_qty,
      'allow_stack', true
    ),
    NULL
  );

  IF COALESCE((v_add_result->>'success')::BOOLEAN, FALSE) = FALSE THEN
    IF v_box.currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + v_box.price WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + v_box.price WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Envanter dolu. Kasa ucreti iade edildi.');
  END IF;

  INSERT INTO public.player_loot_box_logs (
    user_id,
    box_id,
    spent_currency,
    spent_amount,
    reward_type,
    reward_item_id,
    reward_amount,
    roll_weight,
    metadata
  ) VALUES (
    v_user_id,
    v_box.id,
    v_box.currency_type,
    v_box.price,
    'item',
    v_drop.item_id,
    v_reward_qty,
    v_drop.weight,
    jsonb_build_object(
      'box_name', v_box.name,
      'item_name', v_drop.item_name,
      'rarity', v_drop.rarity,
      'pity_forced', v_force_rare_plus
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Kasa acildi.',
    'box_id', v_box.id,
    'box_name', v_box.name,
    'spent_currency', v_box.currency_type,
    'spent_amount', v_box.price,
    'pity_forced', v_force_rare_plus,
    'reward', jsonb_build_object(
      'type', 'item',
      'item_id', v_drop.item_id,
      'name', v_drop.item_name,
      'icon', v_drop.icon,
      'rarity', v_drop.rarity,
      'quantity', v_reward_qty
    )
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_loot_box_drops(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_loot_box(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4) QA helper: theoretical rarity mix + EV for a box (no inventory writes)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qa_loot_box_ev(p_box_id text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH drops AS (
    SELECT
      e.weight,
      e.min_quantity,
      e.max_quantity,
      COALESCE(i.rarity, 'common') AS rarity,
      COALESCE(i.base_price, 0) AS base_price,
      COALESCE(i.vendor_sell_price, 0) AS vendor_sell,
      COALESCE(i.power, 0) AS power
    FROM public.loot_box_drop_entries e
    JOIN public.items i ON i.id = e.item_id
    WHERE e.box_id = p_box_id
      AND e.is_active = TRUE
  ),
  box AS (
    SELECT * FROM public.loot_box_configs WHERE id = p_box_id
  ),
  agg AS (
    SELECT
      SUM(weight) AS tw,
      SUM(weight * ((min_quantity + max_quantity) / 2.0) * base_price)
        / NULLIF(SUM(weight), 0) AS ev_base,
      SUM(weight * ((min_quantity + max_quantity) / 2.0) * vendor_sell)
        / NULLIF(SUM(weight), 0) AS ev_vendor,
      SUM(weight * power) / NULLIF(SUM(weight), 0) AS ev_power,
      SUM(CASE WHEN rarity = 'common' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_common,
      SUM(CASE WHEN rarity = 'uncommon' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_uncommon,
      SUM(CASE WHEN rarity = 'rare' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_rare,
      SUM(CASE WHEN rarity = 'epic' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_epic,
      SUM(CASE WHEN rarity = 'legendary' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_legendary,
      SUM(CASE WHEN rarity = 'mythic' THEN weight ELSE 0 END)
        / NULLIF(SUM(weight), 0) * 100 AS pct_mythic
    FROM drops
  )
  SELECT jsonb_build_object(
    'box_id', b.id,
    'name', b.name,
    'currency', b.currency_type,
    'price', b.price,
    'reward_multiplier', b.reward_multiplier,
    'jackpot_rate_pct', ROUND(((a.pct_legendary + a.pct_mythic))::numeric, 3),
    'rarity_pct', jsonb_build_object(
      'common', ROUND(a.pct_common::numeric, 2),
      'uncommon', ROUND(a.pct_uncommon::numeric, 2),
      'rare', ROUND(a.pct_rare::numeric, 2),
      'epic', ROUND(a.pct_epic::numeric, 2),
      'legendary', ROUND(a.pct_legendary::numeric, 2),
      'mythic', ROUND(a.pct_mythic::numeric, 2)
    ),
    'ev_base_price', ROUND((a.ev_base * b.reward_multiplier)::numeric, 0),
    'ev_vendor_sell', ROUND((a.ev_vendor * b.reward_multiplier)::numeric, 0),
    'ev_power', ROUND(a.ev_power::numeric, 1),
    'gold_per_gem_ref', 750,
    'gem_cost_in_gold_ref', CASE
      WHEN b.currency_type = 'gems' THEN b.price * 750
      ELSE b.price
    END,
    'vendor_rtp_vs_gem_gold', CASE
      WHEN b.currency_type = 'gems' AND b.price > 0 THEN
        ROUND(((a.ev_vendor * b.reward_multiplier) / (b.price * 750.0) * 100)::numeric, 1)
      ELSE NULL
    END
  )
  FROM box b
  CROSS JOIN agg a;
$function$;

GRANT EXECUTE ON FUNCTION public.qa_loot_box_ev(text) TO authenticated;

COMMIT;
