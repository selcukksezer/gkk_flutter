-- Harden spin_wheel against full-inventory stack exploit and return richer reward fields.
CREATE OR REPLACE FUNCTION public.spin_wheel(p_wheel_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wheel RECORD;
  v_reward RECORD;
  v_balance_ok BOOLEAN := FALSE;
  v_today_count INTEGER := 0;
  v_reward_amount INTEGER;
  v_add_result JSONB;
  v_has_free_slot BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT *
  INTO v_wheel
  FROM public.spin_wheel_configs
  WHERE id = p_wheel_id
    AND is_active = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Cark bulunamadi veya pasif.');
  END IF;

  IF v_wheel.daily_limit IS NOT NULL THEN
    SELECT COUNT(*)
    INTO v_today_count
    FROM public.player_spin_wheel_logs
    WHERE user_id = v_user_id
      AND wheel_id = v_wheel.id
      AND created_at::date = (now() at time zone 'utc')::date;

    IF v_today_count >= v_wheel.daily_limit THEN
      RETURN jsonb_build_object('success', false, 'message', 'Gunluk cark limiti doldu.');
    END IF;
  END IF;

  -- Hard rule: when inventory has no free slot, spinning is blocked.
  -- This intentionally ignores stack availability to prevent targeted farming exploits.
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
      'message', 'Envanter dolu. Cark cevirmek icin once bos slot acmalisin.'
    );
  END IF;

  IF v_wheel.currency_type = 'gems' THEN
    UPDATE public.users
    SET gems = gems - v_wheel.price
    WHERE auth_id = v_user_id
      AND gems >= v_wheel.price
    RETURNING TRUE INTO v_balance_ok;
  ELSE
    UPDATE public.users
    SET gold = gold - v_wheel.price
    WHERE auth_id = v_user_id
      AND gold >= v_wheel.price
    RETURNING TRUE INTO v_balance_ok;
  END IF;

  IF COALESCE(v_balance_ok, FALSE) = FALSE THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz bakiye.');
  END IF;

  SELECT
    r.id AS reward_id,
    r.reward_type,
    r.item_id,
    r.amount_min,
    r.amount_max,
    r.weight,
    r.is_jackpot,
    COALESCE(r.label, '') AS reward_label,
    i.name AS item_name,
    i.icon,
    COALESCE(i.is_stackable, FALSE) AS is_stackable,
    COALESCE(i.rarity, 'common') AS rarity
  INTO v_reward
  FROM public.spin_wheel_reward_entries r
  LEFT JOIN public.items i ON i.id = r.item_id
  WHERE r.wheel_id = p_wheel_id
    AND r.is_active = TRUE
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(r.weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    IF v_wheel.currency_type = 'gems' THEN
      UPDATE public.users SET gems = gems + v_wheel.price WHERE auth_id = v_user_id;
    ELSE
      UPDATE public.users SET gold = gold + v_wheel.price WHERE auth_id = v_user_id;
    END IF;
    RETURN jsonb_build_object('success', false, 'message', 'Bu cark icin odul tanimi yok.');
  END IF;

  v_reward_amount := FLOOR(random() * (v_reward.amount_max - v_reward.amount_min + 1) + v_reward.amount_min)::INTEGER;
  v_reward_amount := GREATEST(v_reward_amount, 0);

  IF v_reward.reward_type = 'item' THEN
    IF COALESCE(v_reward.is_stackable, FALSE) = FALSE THEN
      v_reward_amount := 1;
    END IF;

    v_add_result := public.add_inventory_item_v2(
      jsonb_build_object(
        'item_id', v_reward.item_id,
        'quantity', v_reward_amount,
        'allow_stack', true
      ),
      NULL
    );

    IF COALESCE((v_add_result->>'success')::BOOLEAN, FALSE) = FALSE THEN
      IF v_wheel.currency_type = 'gems' THEN
        UPDATE public.users SET gems = gems + v_wheel.price WHERE auth_id = v_user_id;
      ELSE
        UPDATE public.users SET gold = gold + v_wheel.price WHERE auth_id = v_user_id;
      END IF;
      RETURN jsonb_build_object('success', false, 'message', 'Envanter dolu. Cark ucreti iade edildi.');
    END IF;
  ELSIF v_reward.reward_type = 'gold' THEN
    UPDATE public.users
    SET gold = gold + v_reward_amount
    WHERE auth_id = v_user_id;
  ELSE
    UPDATE public.users
    SET gems = gems + v_reward_amount
    WHERE auth_id = v_user_id;
  END IF;

  INSERT INTO public.player_spin_wheel_logs (
    user_id,
    wheel_id,
    spent_currency,
    spent_amount,
    reward_type,
    reward_item_id,
    reward_amount,
    roll_weight,
    metadata
  ) VALUES (
    v_user_id,
    v_wheel.id,
    v_wheel.currency_type,
    v_wheel.price,
    v_reward.reward_type,
    v_reward.item_id,
    v_reward_amount,
    v_reward.weight,
    jsonb_build_object(
      'wheel_name', v_wheel.name,
      'reward_label', v_reward.reward_label,
      'item_name', v_reward.item_name,
      'is_jackpot', v_reward.is_jackpot,
      'reward_id', v_reward.reward_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Cark cevrildi.',
    'wheel_id', v_wheel.id,
    'wheel_name', v_wheel.name,
    'spent_currency', v_wheel.currency_type,
    'spent_amount', v_wheel.price,
    'reward', jsonb_build_object(
      'reward_entry_id', v_reward.reward_id,
      'reward_label', v_reward.reward_label,
      'type', v_reward.reward_type,
      'item_id', v_reward.item_id,
      'name',
        CASE
          WHEN v_reward.reward_type = 'item' THEN COALESCE(v_reward.item_name, 'Item')
          WHEN v_reward.reward_type = 'gold' THEN 'Gold'
          ELSE 'Elmas'
        END,
      'icon', COALESCE(v_reward.icon, ''),
      'rarity', COALESCE(v_reward.rarity, 'common'),
      'quantity', v_reward_amount,
      'amount', v_reward_amount,
      'is_jackpot', v_reward.is_jackpot
    )
  );
END;
$$;
