-- enter_dungeon: deduct energy (row lock) BEFORE loot/hospital grants.
-- Prevents orphan loot when late energy UPDATE fails after dungeon_add_item.

DO $patch$
DECLARE
  v_def text;
  v_old_boss text;
  v_new_boss text;
  v_old_pay text;
  v_new_pay text;
BEGIN
  SELECT pg_get_functiondef(p.oid)
  INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'enter_dungeon'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon not found';
  END IF;

  -- Idempotent: already patched.
  IF position('[GKK_ENERGY_DEDUCT_BEFORE_LOOT]' in v_def) > 0 THEN
    RAISE NOTICE 'enter_dungeon already energy-before-loot patched';
    RETURN;
  END IF;

  v_old_boss := $old$IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN
    RETURN jsonb_build_object('error', 'boss_daily_limit');
  END IF;

  v_power := public.calculate_user_total_power(p_player_id)::INTEGER;$old$;

  v_new_boss := $new$IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN
    RETURN jsonb_build_object('error', 'boss_daily_limit');
  END IF;

  -- [GKK_ENERGY_DEDUCT_BEFORE_LOOT]
  SELECT * INTO v_player
  FROM public.users
  WHERE auth_id = p_player_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;

  IF v_player.energy < v_energy_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_energy');
  END IF;

  UPDATE public.users
  SET energy = energy - v_energy_cost
  WHERE auth_id = p_player_id AND energy >= v_energy_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'insufficient_energy');
  END IF;
  -- [/GKK_ENERGY_DEDUCT_BEFORE_LOOT]

  v_power := public.calculate_user_total_power(p_player_id)::INTEGER;$new$;

  IF position(v_old_boss in v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon boss-limit anchor not found — abort patch';
  END IF;
  v_def := replace(v_def, v_old_boss, v_new_boss);

  v_old_pay := $old$UPDATE public.users
  SET energy = energy - v_energy_cost,
      gold   = gold   + v_gold,
      xp     = xp     + v_xp
  WHERE auth_id = p_player_id AND energy >= v_energy_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Yetersiz enerji veya işlem çakışması');
  END IF;$old$;

  v_new_pay := $new$-- Energy already deducted before loot; apply rewards only.
  UPDATE public.users
  SET gold = gold + v_gold,
      xp   = xp   + v_xp
  WHERE auth_id = p_player_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'enter_dungeon_player_missing' USING ERRCODE = 'P0001';
  END IF;$new$;

  IF position(v_old_pay in v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon pay-update anchor not found — abort patch';
  END IF;
  v_def := replace(v_def, v_old_pay, v_new_pay);

  EXECUTE v_def;
END;
$patch$;
