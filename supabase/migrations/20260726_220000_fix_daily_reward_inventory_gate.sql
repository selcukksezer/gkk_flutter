-- claim_daily_reward: inventory check ONLY when an item is actually granted.
-- Currency/XP/energy always grant. Full inventory → skip item + warn, do not block claim.

CREATE OR REPLACE FUNCTION public.claim_daily_reward()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id UUID;
  v_today DATE;
  v_player RECORD;
  v_state RECORD;
  v_config public.daily_reward_config%ROWTYPE;
  v_grant JSONB;
  v_gold INTEGER;
  v_gems INTEGER;
  v_xp INTEGER;
  v_energy INTEGER;
  v_new_streak INTEGER;
  v_add_result JSONB;
  v_rewards_granted JSONB;
  v_item_id TEXT;
  v_item_qty INTEGER;
  v_item_granted BOOLEAN := false;
  v_item_skipped BOOLEAN := false;
  v_warning TEXT := NULL;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_today := (now() AT TIME ZONE 'UTC')::date;

  SELECT * INTO v_player
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı profili bulunamadı.');
  END IF;

  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastanedeyken günlük ödül alınamaz.');
  END IF;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hapishanedeyken günlük ödül alınamaz.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.daily_reward_claims
    WHERE user_id = v_user_id AND claim_date = v_today
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bugünkü ödül zaten alındı.');
  END IF;

  SELECT * INTO v_state
  FROM public.daily_reward_resolve_state(v_user_id, v_today);

  IF NOT v_state.can_claim THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül alınamaz durumda.');
  END IF;

  SELECT * INTO v_config
  FROM public.daily_reward_config
  WHERE cycle_day = v_state.next_cycle_day;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül konfigürasyonu bulunamadı.');
  END IF;

  v_grant := public.daily_reward_build_grant(v_state.next_cycle_day, v_player.level);
  v_gold := COALESCE((v_grant->>'gold')::INTEGER, 0);
  v_gems := COALESCE((v_grant->>'gems')::INTEGER, 0);
  v_xp := COALESCE((v_grant->>'xp')::INTEGER, 0);
  v_energy := COALESCE((v_grant->>'energy')::INTEGER, 0);

  v_item_id := NULLIF(BTRIM(COALESCE(v_config.item_id, '')), '');
  v_item_qty := COALESCE(v_config.item_quantity, 0);
  IF v_item_id IS NULL OR v_item_qty <= 0 THEN
    v_item_id := NULL;
    v_item_qty := 0;
  END IF;

  v_new_streak := CASE
    WHEN v_state.next_cycle_day = 1 AND (v_state.streak_length = 0) THEN 1
    ELSE v_state.streak_length + 1
  END;

  -- Currencies first — never gated by inventory.
  UPDATE public.users
  SET
    gold = COALESCE(gold, 0) + v_gold,
    gems = COALESCE(gems, 0) + v_gems,
    xp = COALESCE(xp, 0) + v_xp,
    energy = CASE
      WHEN v_energy > 0 THEN LEAST(COALESCE(max_energy, 100), COALESCE(energy, 0) + v_energy)
      ELSE energy
    END,
    updated_at = now()
  WHERE auth_id = v_user_id;

  -- Inventory touch ONLY when an item is part of the reward.
  IF v_item_id IS NOT NULL AND v_item_qty > 0 THEN
    v_add_result := public.add_inventory_item_v2(
      jsonb_build_object(
        'item_id', v_item_id,
        'quantity', v_item_qty,
        'allow_stack', true
      ),
      NULL
    );

    IF COALESCE((v_add_result->>'success')::BOOLEAN, FALSE) THEN
      v_item_granted := true;
    ELSE
      v_item_skipped := true;
      v_warning := 'Envanter dolu — eşya verilemedi. Altın/elmas/XP alındı; yer açıp bir sonraki ödülü kaçırma.';
    END IF;
  END IF;

  v_rewards_granted := v_grant;
  IF v_item_skipped THEN
    v_rewards_granted := v_rewards_granted
      || jsonb_build_object(
        'item_id', NULL,
        'item_name', NULL,
        'item_quantity', 0,
        'item_skipped', true,
        'item_skip_reason', COALESCE(v_add_result->>'error', 'Envanter dolu')
      );
  ELSIF v_item_id IS NULL THEN
    v_rewards_granted := v_rewards_granted
      || jsonb_build_object('item_id', NULL, 'item_name', NULL, 'item_quantity', 0);
  END IF;

  INSERT INTO public.daily_reward_claims (
    user_id, claim_date, cycle_day, streak_length, rewards_granted
  ) VALUES (
    v_user_id, v_today, v_state.next_cycle_day, v_new_streak, v_rewards_granted
  );

  SELECT gold, gems, xp, energy
  INTO v_player.gold, v_player.gems, v_player.xp, v_player.energy
  FROM public.users
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE
      WHEN v_item_skipped THEN v_warning
      ELSE 'Günlük ödül alındı!'
    END,
    'cycle_day', v_state.next_cycle_day,
    'streak_length', v_new_streak,
    'rewards_granted', v_rewards_granted,
    'item_granted', v_item_granted,
    'item_skipped', v_item_skipped,
    'warning', v_warning,
    'new_balances', jsonb_build_object(
      'gold', v_player.gold,
      'gems', v_player.gems,
      'xp', v_player.xp,
      'energy', v_player.energy
    )
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bugünkü ödül zaten alındı.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_daily_reward() TO authenticated;
