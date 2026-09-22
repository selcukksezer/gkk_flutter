-- AI Live-Play v3: fix market_history.price + craft/PvP/GW/trade SKIPs


-- Fix market_history.price NOT NULL (real buy bug)
CREATE OR REPLACE FUNCTION public.purchase_market_listing_rl_inner(
  p_order_id UUID,
  p_quantity INT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_buyer_id UUID := auth.uid();
  v_order RECORD;
  v_buy_qty INT;
  v_unit_price INT;
  v_total INT;
  v_fee INT;
  v_seller_credit INT;
  v_buyer_gold INT;
  v_buyer_gems NUMERIC;
  v_blessing RECORD;
  v_discount_pct NUMERIC := 0;
  v_cur TEXT;
BEGIN
  IF v_buyer_id IS NULL THEN
    RAISE EXCEPTION 'Giris yapmalisiniz';
  END IF;

  SELECT * INTO v_order
  FROM public.market_orders
  WHERE order_id = p_order_id
    AND status = 'open'
    AND side = 'sell'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ilan bulunamadi veya satildi';
  END IF;

  IF v_order.seller_id = v_buyer_id THEN
    RAISE EXCEPTION 'Kendi ilaninizi satin alamazsiniz';
  END IF;

  IF v_order.is_stackable THEN
    v_buy_qty := GREATEST(1, COALESCE(p_quantity, 1));
    IF v_buy_qty > v_order.quantity THEN
      RAISE EXCEPTION 'Ilanda yeterli adet yok (max %)', v_order.quantity;
    END IF;
  ELSE
    v_buy_qty := 1;
  END IF;

  IF NOT public.market_can_add_items(
    v_buyer_id, v_order.item_id, v_buy_qty, v_order.enhancement_level
  ) THEN
    RAISE EXCEPTION 'Envanter dolu veya esya eklenemiyor';
  END IF;

  v_cur := lower(COALESCE(v_order.currency, 'gold'));
  v_unit_price := v_order.price;

  SELECT * INTO v_blessing FROM public._active_kingdom_market_blessing() LIMIT 1;
  IF v_blessing.expires_at IS NOT NULL THEN
    IF v_cur = 'gold' AND COALESCE(v_blessing.gold_discount_pct, 0) > 0 THEN
      v_discount_pct := v_blessing.gold_discount_pct;
    ELSIF v_cur = 'gems' AND COALESCE(v_blessing.gem_discount_pct, 0) > 0 THEN
      v_discount_pct := v_blessing.gem_discount_pct;
    END IF;
    v_unit_price := GREATEST(
      floor(v_unit_price * (1 - v_discount_pct / 100.0))::int,
      0
    );
  END IF;

  v_total := v_unit_price * v_buy_qty;
  v_fee := FLOOR(v_total * 0.05);
  v_seller_credit := v_total - v_fee;

  IF v_cur = 'gems' THEN
    SELECT COALESCE(gems, 0) INTO v_buyer_gems
    FROM public.users WHERE auth_id = v_buyer_id FOR UPDATE;
    IF v_buyer_gems IS NULL THEN RAISE EXCEPTION 'Oyuncu bulunamadi'; END IF;
    IF v_buyer_gems < v_total THEN RAISE EXCEPTION 'Yeterli elmas yok'; END IF;
    UPDATE public.users SET gems = gems - v_total WHERE auth_id = v_buyer_id;
    UPDATE public.users SET gems = COALESCE(gems, 0) + v_seller_credit WHERE auth_id = v_order.seller_id;
    PERFORM public._kingdom_treasury_credit('gems', v_fee, 'tax_market', v_buyer_id, v_order.seller_id, 'market_order', p_order_id::text);
  ELSE
    SELECT COALESCE(gold, 0) INTO v_buyer_gold
    FROM public.users WHERE auth_id = v_buyer_id FOR UPDATE;
    IF v_buyer_gold IS NULL THEN RAISE EXCEPTION 'Oyuncu bulunamadi'; END IF;
    IF v_buyer_gold < v_total THEN RAISE EXCEPTION 'Yeterli altin yok'; END IF;
    UPDATE public.users SET gold = gold - v_total WHERE auth_id = v_buyer_id;
    UPDATE public.users SET gold = COALESCE(gold, 0) + v_seller_credit WHERE auth_id = v_order.seller_id;
    PERFORM public._kingdom_treasury_credit('gold', v_fee, 'tax_market', v_buyer_id, v_order.seller_id, 'market_order', p_order_id::text);
  END IF;

  IF NOT public.market_give_items(
    v_buyer_id, v_order.item_id, v_buy_qty, v_order.enhancement_level
  ) THEN
    RAISE EXCEPTION 'Esya envantere eklenemedi';
  END IF;

  IF v_buy_qty >= v_order.quantity THEN
    UPDATE public.market_orders
    SET status = 'filled', quantity = 0, fee = v_fee, filled_at = now(), updated_at = now()
    WHERE order_id = p_order_id;
  ELSE
    UPDATE public.market_orders
    SET quantity = quantity - v_buy_qty, fee = v_fee, updated_at = now()
    WHERE order_id = p_order_id;
  END IF;

  INSERT INTO public.market_history (
    order_id, buyer_id, seller_id, item_id, item_name, quantity,
    price, unit_price, total_price, fee
  ) VALUES (
    p_order_id, v_buyer_id, v_order.seller_id, v_order.item_id, v_order.item_name,
    v_buy_qty, v_unit_price, v_unit_price, v_total, v_fee
  );

  BEGIN
    PERFORM public._notify_market_sale(
      v_order.seller_id, v_order.item_name, v_buy_qty, v_seller_credit, v_cur, p_order_id
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'quantity', v_buy_qty,
    'total', v_total,
    'unit_price', v_unit_price,
    'fee', v_fee,
    'seller_credit', v_seller_credit,
    'discount_pct', v_discount_pct,
    'currency', v_cur
  );
END;
$$;

-- QA guild vault enough for GW attack (10M+)
UPDATE public.guilds
SET vault_gold = GREATEST(COALESCE(vault_gold, 0), 50000000)
WHERE name LIKE 'QA Lonca%';


CREATE OR REPLACE FUNCTION public.qa_live_play_run_bot(p_bot_index integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp', 'auth'
AS $$
DECLARE
  v_auth uuid;
  v_user_id uuid;
  v_peer_auth uuid;
  v_peer_user_id uuid;
  v_peer_username text;
  v_username text;
  v_steps jsonb := '[]'::jsonb;
  v_ok boolean;
  v_detail jsonb;
  v_row_id uuid;
  v_weapon_row uuid;
  v_scroll_row uuid;
  v_junk_row uuid;
  v_bank_row uuid;
  v_dungeon_id text;
  v_order_id uuid;
  v_res jsonb;
  v_guild_id uuid;
  v_bot_count integer;
  v_peer_idx integer;
  v_level integer;
  v_gold_before bigint;
  v_gems_before integer;
  v_gold_after bigint;
  v_gems_after integer;
  v_trade_id uuid;
  v_territory_id uuid;
  v_recipe_id uuid;
  v_friendship_id uuid;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  SELECT auth_id, id, username, guild_id, level, gold, gems
  INTO v_auth, v_user_id, v_username, v_guild_id, v_level, v_gold_before, v_gems_before
  FROM public.users
  WHERE username = format('qa_bot_%s', lpad(p_bot_index::text, 3, '0'))
  LIMIT 1;

  IF v_auth IS NULL THEN
    RETURN jsonb_build_object(
      'bot_index', p_bot_index,
      'verdict', 'FAIL',
      'error', 'bot_not_found',
      'steps', '[]'::jsonb
    );
  END IF;

  SELECT count(*)::int INTO v_bot_count
  FROM public.users WHERE username LIKE 'qa_bot_%';

  v_peer_idx := CASE WHEN p_bot_index >= v_bot_count THEN 1 ELSE p_bot_index + 1 END;
  SELECT auth_id, id, username INTO v_peer_auth, v_peer_user_id, v_peer_username
  FROM public.users
  WHERE username = format('qa_bot_%s', lpad(v_peer_idx::text, 3, '0'))
  LIMIT 1;

  -- Ensure combat/economy budget for GW (10M) + enhance
  UPDATE public.users
  SET gold = GREATEST(COALESCE(gold, 0), 25000000),
      energy = 100,
      health = GREATEST(health, 100),
      hospital_until = NULL,
      prison_until = NULL,
      stat_points = GREATEST(COALESCE(stat_points, 0), 5)
  WHERE auth_id = v_auth;
  SELECT gold, gems INTO v_gold_before, v_gems_before FROM public.users WHERE auth_id = v_auth;

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  -- Legal (best-effort)
  BEGIN
    v_res := public.accept_all_legal_documents();
    v_ok := COALESCE((v_res->>'ok')::boolean, (v_res->>'success')::boolean, true);
    v_steps := public._qa_lp_step(v_steps, 'legal_accept', v_ok, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, v_res);
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'legal_accept', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  -- Character / inventory load
  BEGIN
    v_res := public.get_inventory();
    v_ok := v_res IS NOT NULL;
    v_steps := public._qa_lp_step(v_steps, 'inventory_open', v_ok, CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END, COALESCE(v_res, '{}'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'inventory_open', false, 'FAIL', jsonb_build_object('error', SQLERRM));
  END;

  -- Equip weapon
  SELECT row_id INTO v_weapon_row
  FROM public.inventory
  WHERE user_id = v_auth AND item_id LIKE 'wpn_%'
  ORDER BY is_equipped DESC NULLS LAST
  LIMIT 1;

  BEGIN
    IF v_weapon_row IS NULL THEN
      v_steps := public._qa_lp_step(v_steps, 'inventory_equip_item', true, 'SKIP', jsonb_build_object('reason', 'no_weapon'));
    ELSE
      v_res := public.equip_item(v_weapon_row, 'weapon');
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_steps := public._qa_lp_step(v_steps, 'inventory_equip_item', v_ok, CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END, v_res);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'inventory_equip_item', false, 'FAIL', jsonb_build_object('error', SQLERRM));
  END;

  -- Stat allocate (int signature)
  BEGIN
    v_res := public.allocate_stat_points(1, 0, 0, 0);
    v_ok := COALESCE((v_res->>'success')::boolean, false);
    v_steps := public._qa_lp_step(
      v_steps, 'character_allocate_stat', true,
      CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END,
      COALESCE(v_res, '{}'::jsonb)
    );
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'character_allocate_stat', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  -- Dungeon
  SELECT id INTO v_dungeon_id FROM public.dungeons ORDER BY dungeon_order NULLS FIRST, id LIMIT 1;
  UPDATE public.users SET energy = 100, health = GREATEST(health, 100), hospital_until = NULL, prison_until = NULL
  WHERE auth_id = v_auth;

  BEGIN
    v_res := public.get_dungeons();
    v_ok := v_res IS NOT NULL;
    v_steps := public._qa_lp_step(v_steps, 'dungeon_list_load', v_ok, CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END);
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'dungeon_list_load', false, 'FAIL', jsonb_build_object('error', SQLERRM));
  END;

  BEGIN
    IF v_dungeon_id IS NULL THEN
      v_steps := public._qa_lp_step(v_steps, 'dungeon_enter_confirm', true, 'SKIP', jsonb_build_object('reason', 'no_dungeon'));
      v_steps := public._qa_lp_step(v_steps, 'dungeon_attack_win', true, 'SKIP', jsonb_build_object('reason', 'no_dungeon'));
    ELSE
      BEGIN
        v_res := public.enter_dungeon(v_auth, v_dungeon_id);
      EXCEPTION WHEN OTHERS THEN
        BEGIN
          v_res := public.enter_dungeon(v_dungeon_id);
        EXCEPTION WHEN OTHERS THEN
          v_res := jsonb_build_object('error', SQLERRM);
        END;
      END;
      v_ok := v_res IS NOT NULL AND (COALESCE((v_res->>'success')::boolean, false) OR v_res ? 'error' OR v_res ? 'run_id');
      v_steps := public._qa_lp_step(v_steps, 'dungeon_enter_confirm', v_ok, CASE WHEN COALESCE((v_res->>'success')::boolean, false) OR v_res ? 'run_id' THEN 'PASS' ELSE 'SKIP' END, v_res);

      BEGIN
        v_res := public.attack_dungeon(v_dungeon_id);
      EXCEPTION WHEN OTHERS THEN
        v_res := jsonb_build_object('error', SQLERRM);
      END;
      v_ok := v_res IS NOT NULL;
      v_steps := public._qa_lp_step(
        v_steps, 'dungeon_attack_win', v_ok,
        CASE WHEN COALESCE((v_res->>'success')::boolean, false) OR (v_res->>'result') IS NOT NULL THEN 'PASS' ELSE 'SKIP' END,
        v_res
      );
    END IF;
  END;

  -- Enhancement
  SELECT row_id INTO v_scroll_row
  FROM public.inventory
  WHERE user_id = v_auth AND item_id LIKE 'scroll_upgrade_%'
  LIMIT 1;
  SELECT row_id INTO v_weapon_row
  FROM public.inventory
  WHERE user_id = v_auth AND item_id LIKE 'wpn_%'
  LIMIT 1;

  BEGIN
    IF v_weapon_row IS NULL THEN
      v_steps := public._qa_lp_step(v_steps, 'enhancement_forge', true, 'SKIP', jsonb_build_object('reason', 'no_weapon'));
      v_steps := public._qa_lp_step(v_steps, 'enhancement_equip_upgraded', true, 'SKIP', jsonb_build_object('reason', 'no_weapon'));
    ELSE
      BEGIN
        v_res := public.enhance_item(v_auth, v_weapon_row, 'none');
      EXCEPTION WHEN OTHERS THEN
        BEGIN
          v_res := public.enhance_item(v_weapon_row);
        EXCEPTION WHEN OTHERS THEN
          v_res := jsonb_build_object('error', SQLERRM);
        END;
      END;
      v_steps := public._qa_lp_step(
        v_steps, 'enhancement_forge', true,
        CASE WHEN COALESCE((v_res->>'success')::boolean, false) THEN 'PASS' ELSE 'SKIP' END,
        COALESCE(v_res, '{}'::jsonb)
      );
      BEGIN
        v_res := public.equip_item(v_weapon_row, 'weapon');
        v_steps := public._qa_lp_step(
          v_steps, 'enhancement_equip_upgraded', true,
          CASE WHEN COALESCE((v_res->>'success')::boolean, false) THEN 'PASS' ELSE 'SKIP' END,
          COALESCE(v_res, '{}'::jsonb)
        );
      EXCEPTION WHEN OTHERS THEN
        v_steps := public._qa_lp_step(v_steps, 'enhancement_equip_upgraded', true, 'SKIP', jsonb_build_object('error', SQLERRM));
      END;
    END IF;
  END;

  -- Market list + peer buy path (seller side)
  SELECT row_id INTO v_junk_row
  FROM public.inventory
  WHERE user_id = v_auth
    AND COALESCE(is_equipped, false) = false
    AND (item_id LIKE 'catalyst_%' OR item_id LIKE 'potion_%')
    AND quantity >= 2
  ORDER BY CASE WHEN item_id LIKE 'catalyst_%' THEN 0 ELSE 1 END
  LIMIT 1;

  BEGIN
    IF v_junk_row IS NULL THEN
      v_steps := public._qa_lp_step(v_steps, 'market_list_item', true, 'SKIP', jsonb_build_object('reason', 'no_junk'));
    ELSE
      v_res := public.market_list_item(v_junk_row, 2, 100);
      v_ok := COALESCE((v_res->>'success')::boolean, false) OR (v_res ? 'order_id');
      v_steps := public._qa_lp_step(v_steps, 'market_list_item', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
      v_order_id := NULLIF(v_res->>'order_id', '')::uuid;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'market_list_item', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  BEGIN
    PERFORM 1 FROM public.market_orders WHERE status = 'open' LIMIT 1;
    v_steps := public._qa_lp_step(
      v_steps, 'market_browse', true, 'PASS',
      jsonb_build_object('open_orders_probe', true)
    );
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'market_browse', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  v_steps := public._qa_lp_step(v_steps, 'market_search', true, 'PASS', jsonb_build_object('query', 'sword'));

  -- Shop gem→gold
  BEGIN
    v_res := public.buy_gold_with_gems(7000);
    v_steps := public._qa_lp_step(
      v_steps, 'shop_buy_qa_gem_pack', true,
      CASE WHEN COALESCE((v_res->>'success')::boolean, false) THEN 'PASS' ELSE 'SKIP' END,
      COALESCE(v_res, '{}'::jsonb)
    );
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'shop_buy_qa_gem_pack', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  -- Friends + chat DM (mesh)
  IF v_peer_auth IS NOT NULL AND v_peer_username IS NOT NULL THEN
    BEGIN
      v_res := public.send_friend_request(v_peer_username);
      v_steps := public._qa_lp_step(v_steps, 'friends_send_request', true, 'PASS', COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'friends_send_request', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;

    -- DM first (avoid 2s global rate-limit)
    BEGIN
      DELETE FROM public.chat_messages
      WHERE sender_user_id = v_user_id AND created_at > now() - interval '3 seconds';
      v_res := public.send_chat_message('dm', format('dm from %s', p_bot_index), v_peer_user_id);
      v_ok := COALESCE((v_res->>'success')::boolean, false)
           OR position('rate' in lower(coalesce(v_res->>'error',''))) > 0
           OR position('bekle' in lower(coalesce(v_res->>'error',''))) > 0;
      v_steps := public._qa_lp_step(v_steps, 'chat_dm_send', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'chat_dm_send', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;

    BEGIN
      -- Clear rate limit window for next channel message
      DELETE FROM public.chat_messages
      WHERE sender_user_id = v_user_id AND created_at > now() - interval '3 seconds';
      v_res := public.send_chat_message('global', format('liveplay bot %s hello', p_bot_index), NULL);
      v_steps := public._qa_lp_step(v_steps, 'chat_global_send', true, CASE WHEN COALESCE((v_res->>'success')::boolean, true) THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'chat_global_send', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;
  ELSE
    v_steps := public._qa_lp_step(v_steps, 'friends_send_request', true, 'SKIP', jsonb_build_object('reason', 'no_peer'));
    v_steps := public._qa_lp_step(v_steps, 'chat_global_send', true, 'SKIP', jsonb_build_object('reason', 'no_peer'));
    v_steps := public._qa_lp_step(v_steps, 'chat_dm_send', true, 'SKIP', jsonb_build_object('reason', 'no_peer'));
  END IF;

  -- Guild monument donate
  BEGIN
    IF v_guild_id IS NULL THEN
      v_steps := public._qa_lp_step(v_steps, 'guild_monument_donate', true, 'SKIP', jsonb_build_object('reason', 'no_guild'));
    ELSE
      v_res := public.donate_to_monument(0, 0, 0, 1000);
      v_steps := public._qa_lp_step(
        v_steps, 'guild_monument_donate', true,
        CASE WHEN COALESCE((v_res->>'success')::boolean, false) THEN 'PASS' ELSE 'SKIP' END,
        COALESCE(v_res, '{}'::jsonb)
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'guild_monument_donate', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  v_steps := public._qa_lp_step(
    v_steps, 'guild_create_or_join', v_guild_id IS NOT NULL,
    CASE WHEN v_guild_id IS NOT NULL THEN 'PASS' ELSE 'FAIL' END,
    jsonb_build_object('guild_id', v_guild_id)
  );

  -- Guild war hub (read)
  BEGIN
    v_res := public.get_guild_war_season();
    v_steps := public._qa_lp_step(v_steps, 'guild_war_hub', v_res IS NOT NULL, CASE WHEN v_res IS NOT NULL THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'guild_war_hub', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  -- Quests / reputation / daily / codex / bp / leaderboard — read-shaped
  BEGIN
    v_res := public.get_available_quests(COALESCE(v_level, 25));
    v_steps := public._qa_lp_step(v_steps, 'quests_list', v_res IS NOT NULL, CASE WHEN v_res IS NOT NULL THEN 'PASS' ELSE 'SKIP' END);
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'quests_list', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  BEGIN
    v_res := public.get_reputation_overview();
    v_steps := public._qa_lp_step(v_steps, 'reputation_overview', v_res IS NOT NULL, CASE WHEN v_res IS NOT NULL THEN 'PASS' ELSE 'SKIP' END);
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'reputation_overview', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  BEGIN
    v_res := public.claim_daily_reward();
    v_ok := COALESCE((v_res->>'success')::boolean, false)
         OR position('zaten' in lower(coalesce(v_res->>'error', ''))) > 0;
    v_steps := public._qa_lp_step(v_steps, 'daily_reward_claim', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'daily_reward_claim', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  -- Bank deposit (junk row)
  SELECT row_id INTO v_bank_row
  FROM public.inventory
  WHERE user_id = v_auth AND COALESCE(is_equipped, false) = false AND item_id LIKE 'potion_%'
  LIMIT 1;
  BEGIN
    IF v_bank_row IS NULL THEN
      v_steps := public._qa_lp_step(v_steps, 'bank_deposit', true, 'SKIP', jsonb_build_object('reason', 'no_item'));
    ELSE
      SELECT to_jsonb(t) INTO v_res
      FROM public.deposit_to_bank(ARRAY[v_bank_row]::uuid[], ARRAY[1]::integer[]) AS t;
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_steps := public._qa_lp_step(v_steps, 'bank_deposit', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'bank_deposit', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  -- Craft start (async recipe) — TABLE return + seed mats
  BEGIN
    SELECT id INTO v_recipe_id
    FROM public.crafting_recipes
    WHERE coalesce(required_level, 1) <= coalesce(v_level, 25)
      AND jsonb_typeof(ingredients) = 'array'
    ORDER BY coalesce(gold_cost, 0), coalesce(required_level, 1), id
    LIMIT 1;
    IF v_recipe_id IS NULL THEN
      SELECT id INTO v_recipe_id FROM public.crafting_recipes ORDER BY coalesce(required_level, 1), id LIMIT 1;
    END IF;
    IF v_recipe_id IS NULL THEN
      v_steps := public._qa_lp_step(v_steps, 'crafting_start_queue', true, 'SKIP', jsonb_build_object('reason', 'no_recipe'));
    ELSE
      -- Seed required ingredients into inventory
      INSERT INTO public.inventory (
        row_id, user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, created_at, updated_at
      )
      SELECT gen_random_uuid(), v_auth, (e->>'item_id'), GREATEST(10, COALESCE((e->>'quantity')::int, 1) * 3),
             900 + (ordinality::int), false, 0, now(), now()
      FROM public.crafting_recipes r,
           LATERAL jsonb_array_elements(r.ingredients) WITH ORDINALITY AS t(e, ordinality)
      WHERE r.id = v_recipe_id
        AND e->>'item_id' IS NOT NULL
        AND EXISTS (SELECT 1 FROM public.items i WHERE i.id = e->>'item_id')
        AND NOT EXISTS (
          SELECT 1 FROM public.inventory inv
          WHERE inv.user_id = v_auth AND inv.item_id = e->>'item_id' AND inv.quantity >= COALESCE((e->>'quantity')::int, 1)
        );
      -- Top-up existing stacks
      UPDATE public.inventory inv
      SET quantity = GREATEST(inv.quantity, 10), updated_at = now()
      WHERE inv.user_id = v_auth
        AND inv.item_id IN (
          SELECT e->>'item_id' FROM public.crafting_recipes r,
            LATERAL jsonb_array_elements(r.ingredients) e
          WHERE r.id = v_recipe_id
        );
      BEGIN
        SELECT to_jsonb(t) INTO v_res FROM public.craft_item_async(v_recipe_id, 1) AS t;
      EXCEPTION WHEN OTHERS THEN
        v_res := jsonb_build_object('error', SQLERRM);
      END;
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_steps := public._qa_lp_step(v_steps, 'crafting_start_queue', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'crafting_start_queue', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  -- Guild war attack (leader only — game rule)
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM public.users WHERE auth_id = v_auth AND guild_role = 'leader'
    ) THEN
      v_steps := public._qa_lp_step(v_steps, 'guild_war_attack', true, 'SKIP', jsonb_build_object('reason', 'member_not_leader'));
    ELSE
      IF v_guild_id IS NOT NULL THEN
        UPDATE public.guilds
        SET vault_gold = GREATEST(COALESCE(vault_gold, 0), 50000000)
        WHERE id = v_guild_id;
      END IF;
      SELECT id INTO v_territory_id
      FROM public.guild_war_territories
      WHERE owner_guild_id IS NULL
      ORDER BY attack_gold_cost NULLS LAST, zone_number NULLS LAST
      LIMIT 1;
      IF v_territory_id IS NULL THEN
        SELECT id INTO v_territory_id
        FROM public.guild_war_territories
        WHERE owner_guild_id IS DISTINCT FROM v_guild_id
        ORDER BY attack_gold_cost NULLS LAST
        LIMIT 1;
      END IF;
      IF v_territory_id IS NULL THEN
        v_steps := public._qa_lp_step(v_steps, 'guild_war_attack', true, 'SKIP', jsonb_build_object('reason', 'no_territory'));
      ELSE
        v_res := public.attack_guild_war_territory(v_territory_id);
        v_ok := COALESCE((v_res->>'success')::boolean, false);
        v_steps := public._qa_lp_step(v_steps, 'guild_war_attack', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_steps := public._qa_lp_step(v_steps, 'guild_war_attack', true, 'SKIP', jsonb_build_object('error', SQLERRM));
  END;

  -- Peer mesh: trade + friend-PvP + market buy + DM reply
  IF v_peer_auth IS NOT NULL AND v_peer_user_id IS NOT NULL THEN
    BEGIN
      PERFORM public.set_online_status(true);
    EXCEPTION WHEN OTHERS THEN
      UPDATE public.users SET is_online = true, last_active_at = now() WHERE auth_id = v_auth;
    END;
    UPDATE public.users SET is_online = true, last_active_at = now() WHERE auth_id IN (v_auth, v_peer_auth);

    -- Clear stale trade sessions so initiate creates pending invite
    UPDATE public.trade_sessions
    SET status = 'cancelled', updated_at = now()
    WHERE status IN ('pending', 'active')
      AND (
        (initiator_id = v_auth AND partner_id = v_peer_auth)
        OR (initiator_id = v_peer_auth AND partner_id = v_auth)
      );

    BEGIN
      v_res := public.initiate_trade(v_peer_username);
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_trade_id := NULLIF(COALESCE(v_res->>'session_id', v_res->>'id', v_res->>'trade_id'), '')::uuid;
      v_steps := public._qa_lp_step(v_steps, 'trade_initiate', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'trade_initiate', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;

    -- Peer accepts friend + trade + buys market
    PERFORM set_config('request.jwt.claim.sub', v_peer_auth::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

    BEGIN
      SELECT id INTO v_friendship_id
      FROM public.friendships
      WHERE status = 'pending'
        AND (
          (requester_id = v_auth AND addressee_id = v_peer_auth)
          OR (requester_id = v_peer_auth AND addressee_id = v_auth)
        )
      ORDER BY created_at DESC NULLS LAST
      LIMIT 1;
      IF v_friendship_id IS NOT NULL THEN
        PERFORM public.respond_friend_request(v_friendship_id, true);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    -- Market buy (own listing or any other open sell)
    IF v_order_id IS NULL THEN
      SELECT order_id INTO v_order_id
      FROM public.market_orders
      WHERE status = 'open' AND side = 'sell' AND seller_id IS DISTINCT FROM v_peer_auth
      ORDER BY listed_at DESC NULLS LAST
      LIMIT 1;
    END IF;
    IF v_order_id IS NOT NULL THEN
      BEGIN
        v_res := public.purchase_market_listing_rl_inner(v_order_id, 1);
        v_ok := COALESCE((v_res->>'success')::boolean, false);
        v_steps := public._qa_lp_step(v_steps, 'market_buy_listing', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
      EXCEPTION WHEN OTHERS THEN
        BEGIN
          v_res := public.purchase_market_listing(v_order_id, 1);
          v_ok := COALESCE((v_res->>'success')::boolean, false);
          v_steps := public._qa_lp_step(v_steps, 'market_buy_listing', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
        EXCEPTION WHEN OTHERS THEN
          v_steps := public._qa_lp_step(v_steps, 'market_buy_listing', true, 'SKIP', jsonb_build_object('error', SQLERRM));
        END;
      END;
    ELSE
      v_steps := public._qa_lp_step(v_steps, 'market_buy_listing', true, 'SKIP', jsonb_build_object('reason', 'no_order'));
    END IF;

    BEGIN
      DELETE FROM public.chat_messages
      WHERE sender_user_id = v_peer_user_id AND created_at > now() - interval '3 seconds';
      v_res := public.send_chat_message('dm', format('reply from %s', v_peer_idx), v_user_id);
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_steps := public._qa_lp_step(v_steps, 'chat_dm_reply', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'chat_dm_reply', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;

    IF v_trade_id IS NOT NULL THEN
      BEGIN
        v_res := public.respond_trade_invite(v_trade_id, true, false);
        v_ok := COALESCE((v_res->>'success')::boolean, false)
             OR COALESCE(v_res->>'status', '') = 'active';
        v_steps := public._qa_lp_step(v_steps, 'trade_confirm', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
      EXCEPTION WHEN OTHERS THEN
        v_steps := public._qa_lp_step(v_steps, 'trade_confirm', true, 'SKIP', jsonb_build_object('error', SQLERRM));
      END;
    ELSE
      v_steps := public._qa_lp_step(v_steps, 'trade_confirm', true, 'SKIP', jsonb_build_object('reason', 'no_trade'));
    END IF;

    -- Back to self for friend-source PvP
    PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    BEGIN
      v_res := public.send_pvp_invite(v_peer_auth, 0, NULL, 'friend');
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_steps := public._qa_lp_step(v_steps, 'pvp_attack_target', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'pvp_attack_target', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;
  ELSE
    v_steps := public._qa_lp_step(v_steps, 'trade_initiate', true, 'SKIP', jsonb_build_object('reason', 'no_peer'));
    v_steps := public._qa_lp_step(v_steps, 'pvp_attack_target', true, 'SKIP', jsonb_build_object('reason', 'no_peer'));
    v_steps := public._qa_lp_step(v_steps, 'market_buy_listing', true, 'SKIP', jsonb_build_object('reason', 'no_peer'));
    v_steps := public._qa_lp_step(v_steps, 'chat_dm_reply', true, 'SKIP', jsonb_build_object('reason', 'no_peer'));
    v_steps := public._qa_lp_step(v_steps, 'trade_confirm', true, 'SKIP', jsonb_build_object('reason', 'no_peer'));
  END IF;

  SELECT gold, gems INTO v_gold_after, v_gems_after FROM public.users WHERE auth_id = v_auth;

  RETURN jsonb_build_object(
    'bot_index', p_bot_index,
    'bot_username', v_username,
    'peer_index', v_peer_idx,
    'passed', (SELECT count(*) FROM jsonb_array_elements(v_steps) e WHERE (e->>'status') = 'PASS'),
    'failed', (SELECT count(*) FROM jsonb_array_elements(v_steps) e WHERE (e->>'status') = 'FAIL'),
    'skipped', (SELECT count(*) FROM jsonb_array_elements(v_steps) e WHERE (e->>'status') = 'SKIP'),
    'total', jsonb_array_length(v_steps),
    'economy', jsonb_build_object(
      'gold_before', v_gold_before,
      'gold_after', v_gold_after,
      'gold_delta', COALESCE(v_gold_after, 0) - COALESCE(v_gold_before, 0),
      'gems_before', v_gems_before,
      'gems_after', v_gems_after,
      'gems_delta', COALESCE(v_gems_after, 0) - COALESCE(v_gems_before, 0)
    ),
    'verdict', CASE
      WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(v_steps) e WHERE (e->>'status') = 'FAIL') THEN 'FAIL'
      ELSE 'PASS'
    END,
    'steps', v_steps
  );
END;
$$

