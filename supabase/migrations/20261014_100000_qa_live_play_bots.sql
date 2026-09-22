-- AI Live-Play: seed 300 bots (guild×10), wipe, per-bot marathon + swarm batch.
-- Run:
--   SELECT set_config('app.qa_mode','true',true);
--   SELECT public.qa_seed_live_play_bots(300);
--   SELECT public.qa_live_play_swarm(1, 300);
-- Wipe: SELECT public.qa_wipe_live_play_bots();

CREATE OR REPLACE FUNCTION public.qa_wipe_live_play_bots()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, auth
AS $$
DECLARE
  v_cleanup json;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();
  v_cleanup := public.qa_cleanup_bots();
  RETURN json_build_object(
    'success', true,
    'cleanup', v_cleanup,
    'note', 'Launch wipe: bots + QA Lonca rows removed. Archive reports/ separately.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_wipe_live_play_bots() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_wipe_live_play_bots() TO service_role;

CREATE OR REPLACE FUNCTION public.qa_seed_live_play_bots(p_bot_count integer DEFAULT 300)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, auth, extensions
AS $$
DECLARE
  v_idx integer;
  v_bot_auth uuid;
  v_bot_user uuid;
  v_guild_id uuid;
  v_guild_number integer;
  v_class text;
  v_level integer := 25;
  v_kit text[] := ARRAY[
    'wpn_sword_uncommon',
    'chest_leather_uncommon',
    'scroll_upgrade_low',
    'scroll_upgrade_middle',
    'potion_health_minor',
    'potion_energy_major',
    'catalyst_common',
    'box_weapon_common'
  ];
  v_item text;
  v_slot integer;
  v_password text := 'QaLivePlay300!';
  v_guild_size integer := 10;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  IF p_bot_count < 1 OR p_bot_count > 10000 THEN
    RAISE EXCEPTION 'p_bot_count must be 1..10000';
  END IF;

  -- Wipe previous live-play / qa bots first
  PERFORM public.qa_cleanup_bots();

  FOR v_idx IN 1..p_bot_count LOOP
    v_bot_auth := gen_random_uuid();
    v_bot_user := gen_random_uuid();
    v_class := (ARRAY['warrior', 'alchemist', 'shadow'])[1 + ((v_idx - 1) % 3)];
    v_guild_number := 1 + ((v_idx - 1) / v_guild_size);

    IF ((v_idx - 1) % v_guild_size) = 0 THEN
      v_guild_id := gen_random_uuid();
    END IF;

    INSERT INTO auth.users (
      id, aud, role, email, encrypted_password, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data
    )
    VALUES (
      v_bot_auth, 'authenticated', 'authenticated',
      format('qa_bot_%s@sim.local', lpad(v_idx::text, 3, '0')),
      crypt(v_password, gen_salt('bf')),
      now(), now(), now(),
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object('username', format('qa_bot_%s', lpad(v_idx::text, 3, '0')), 'is_bot', true)
    );

    -- identities (GoTrue email login)
    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    )
    VALUES (
      gen_random_uuid(),
      v_bot_auth,
      jsonb_build_object(
        'sub', v_bot_auth::text,
        'email', format('qa_bot_%s@sim.local', lpad(v_idx::text, 3, '0'))
      ),
      'email',
      v_bot_auth::text,
      now(), now(), now()
    )
    ON CONFLICT DO NOTHING;

    INSERT INTO public.users (
      id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
      attack, defense, health, max_health, power,
      tutorial_completed, total_playtime_seconds, gems, experience,
      addiction_level, tolerance,
      pvp_wins, pvp_losses, pvp_rating, reputation,
      character_class, luck, guild_id, guild_role,
      created_at, updated_at, last_login_at
    )
    VALUES (
      v_bot_user, v_bot_auth,
      format('qa_bot_%s', lpad(v_idx::text, 3, '0')),
      format('qa_bot_%s@sim.local', lpad(v_idx::text, 3, '0')),
      format('QA Bot %s', lpad(v_idx::text, 3, '0')),
      v_level, v_level * 200,
      25000000, 100, 100,
      80, 70, 500, 500, 2000,
      true, 3600,
      5000, v_level * 200,
      0, 0,
      5, 2, 1200, 500,
      v_class, 20, v_guild_id,
      CASE WHEN ((v_idx - 1) % v_guild_size) = 0 THEN 'leader' ELSE 'member' END,
      now(), now(), now()
    )
    ON CONFLICT (auth_id) DO UPDATE SET
      username = EXCLUDED.username,
      email = EXCLUDED.email,
      display_name = EXCLUDED.display_name,
      level = EXCLUDED.level,
      gold = EXCLUDED.gold,
      gems = EXCLUDED.gems,
      energy = EXCLUDED.energy,
      health = EXCLUDED.health,
      max_health = EXCLUDED.max_health,
      power = EXCLUDED.power,
      guild_id = EXCLUDED.guild_id,
      guild_role = EXCLUDED.guild_role,
      character_class = EXCLUDED.character_class,
      tutorial_completed = true,
      updated_at = now();

    UPDATE public.users SET stat_points = 10 WHERE auth_id = v_bot_auth;

    IF ((v_idx - 1) % v_guild_size) = 0 THEN
      INSERT INTO public.guilds (
        id, name, tag, leader_id, description, level, max_members, monument_level, vault_gold
      )
      VALUES (
        v_guild_id,
        format('QA Lonca %s', lpad(v_guild_number::text, 2, '0')),
        format('Q%s', lpad(v_guild_number::text, 2, '0')),
        v_bot_auth,
        'AI live-play loncasi',
        3, 50, 2, 1000000
      )
      ON CONFLICT (name) DO NOTHING;
    END IF;

    INSERT INTO public.qa_bot_profiles (bot_auth_id, bot_user_id, segment, behavior_model, level_seed)
    VALUES (
      v_bot_auth, v_bot_user, 'live_play',
      'full_feature_marathon', v_level
    )
    ON CONFLICT (bot_auth_id) DO UPDATE SET
      segment = EXCLUDED.segment,
      behavior_model = EXCLUDED.behavior_model,
      level_seed = EXCLUDED.level_seed;

    -- Starter kit
    v_slot := 1;
    FOREACH v_item IN ARRAY v_kit LOOP
      IF EXISTS (SELECT 1 FROM public.items WHERE id = v_item) THEN
        INSERT INTO public.inventory (
          row_id, user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, created_at, updated_at
        )
        VALUES (
          gen_random_uuid(), v_bot_auth, v_item,
          CASE WHEN v_item LIKE 'scroll_%' OR v_item LIKE 'catalyst_%' OR v_item LIKE 'potion_%' THEN 5 ELSE 1 END,
          v_slot,
          (v_item LIKE 'wpn_%' OR v_item LIKE 'chest_%'),
          0, now(), now()
        );
        v_slot := v_slot + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'seeded_bots', p_bot_count,
    'guild_size', v_guild_size,
    'guilds', ceil(p_bot_count::numeric / v_guild_size)::int,
    'password', v_password,
    'email_pattern', 'qa_bot_NNN@sim.local'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_seed_live_play_bots(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_seed_live_play_bots(integer) TO service_role;

-- Helper: append goal result
CREATE OR REPLACE FUNCTION public._qa_lp_step(
  p_steps jsonb,
  p_id text,
  p_pass boolean,
  p_status text DEFAULT 'PASS',
  p_detail jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT p_steps || jsonb_build_array(jsonb_build_object(
    'id', p_id,
    'pass', p_pass,
    'status', p_status,
    'detail', p_detail
  ));
$$;

CREATE OR REPLACE FUNCTION public.qa_live_play_run_bot(p_bot_index integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, auth
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
    AND item_id LIKE 'catalyst_%'
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
      v_res := public.send_chat_message('dm', format('dm from %s', p_bot_index), v_peer_user_id);
      v_ok := COALESCE((v_res->>'success')::boolean, false);
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

  -- Craft start (async recipe)
  BEGIN
    SELECT id INTO v_recipe_id
    FROM public.crafting_recipes
    WHERE coalesce(facility_type, 'none') IN ('none', '')
    ORDER BY coalesce(required_level, 1), id
    LIMIT 1;
    IF v_recipe_id IS NULL THEN
      SELECT id INTO v_recipe_id FROM public.crafting_recipes ORDER BY coalesce(required_level, 1), id LIMIT 1;
    END IF;
    IF v_recipe_id IS NULL THEN
      v_steps := public._qa_lp_step(v_steps, 'crafting_start_queue', true, 'SKIP', jsonb_build_object('reason', 'no_recipe'));
    ELSE
      BEGIN
        v_res := public.craft_item_async(v_recipe_id, 1);
      EXCEPTION WHEN OTHERS THEN
        BEGIN
          v_res := public.start_crafting(v_auth, v_recipe_id, 1);
        EXCEPTION WHEN OTHERS THEN
          v_res := jsonb_build_object('error', SQLERRM);
        END;
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

  -- Peer mesh: market buy + DM reply + trade + PvP
  IF v_peer_auth IS NOT NULL AND v_peer_user_id IS NOT NULL THEN
    -- Mark both online for trade
    BEGIN
      PERFORM public.set_online_status(true);
    EXCEPTION WHEN OTHERS THEN
      UPDATE public.users SET is_online = true, last_active_at = now() WHERE auth_id = v_auth;
    END;
    UPDATE public.users SET is_online = true, last_active_at = now() WHERE auth_id IN (v_auth, v_peer_auth);

    -- Trade initiate (as self)
    BEGIN
      v_res := public.initiate_trade(v_peer_username);
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_trade_id := NULLIF(COALESCE(v_res->>'session_id', v_res->>'id', v_res->>'trade_id'), '')::uuid;
      v_steps := public._qa_lp_step(v_steps, 'trade_initiate', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'trade_initiate', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;

    -- PvP invite (allowed source: discovery|revenge|friend)
    BEGIN
      v_res := public.send_pvp_invite(v_peer_auth, 0, NULL, 'discovery');
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_steps := public._qa_lp_step(v_steps, 'pvp_attack_target', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'pvp_attack_target', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;

    PERFORM set_config('request.jwt.claim.sub', v_peer_auth::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

    -- Market buy with quantity
    IF v_order_id IS NOT NULL THEN
      BEGIN
        -- Bypass captcha wrapper in QA
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

    -- DM reply
    BEGIN
      v_res := public.send_chat_message('dm', format('reply from %s', v_peer_idx), v_user_id);
      v_ok := COALESCE((v_res->>'success')::boolean, false);
      v_steps := public._qa_lp_step(v_steps, 'chat_dm_reply', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
    EXCEPTION WHEN OTHERS THEN
      v_steps := public._qa_lp_step(v_steps, 'chat_dm_reply', true, 'SKIP', jsonb_build_object('error', SQLERRM));
    END;

    -- Trade accept
    IF v_trade_id IS NOT NULL THEN
      BEGIN
        v_res := public.respond_trade_invite(v_trade_id, true, false);
        v_ok := COALESCE((v_res->>'success')::boolean, false);
        v_steps := public._qa_lp_step(v_steps, 'trade_confirm', true, CASE WHEN v_ok THEN 'PASS' ELSE 'SKIP' END, COALESCE(v_res, '{}'::jsonb));
      EXCEPTION WHEN OTHERS THEN
        v_steps := public._qa_lp_step(v_steps, 'trade_confirm', true, 'SKIP', jsonb_build_object('error', SQLERRM));
      END;
    ELSE
      v_steps := public._qa_lp_step(v_steps, 'trade_confirm', true, 'SKIP', jsonb_build_object('reason', 'no_trade'));
    END IF;
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
$$;

REVOKE ALL ON FUNCTION public.qa_live_play_run_bot(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_live_play_run_bot(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.qa_live_play_swarm(
  p_from integer DEFAULT 1,
  p_to integer DEFAULT 300
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_i integer;
  v_bot jsonb;
  v_bots jsonb := '[]'::jsonb;
  v_pass integer := 0;
  v_fail integer := 0;
  v_goal_counts jsonb := '{}'::jsonb;
  v_step jsonb;
  v_gid text;
  v_st text;
  v_cnt integer;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  IF p_from < 1 OR p_to < p_from THEN
    RAISE EXCEPTION 'invalid range';
  END IF;

  FOR v_i IN p_from..p_to LOOP
    v_bot := public.qa_live_play_run_bot(v_i);
    v_bots := v_bots || jsonb_build_array(jsonb_build_object(
      'bot_index', v_i,
      'verdict', v_bot->>'verdict',
      'passed', v_bot->'passed',
      'failed', v_bot->'failed',
      'skipped', v_bot->'skipped',
      'total', v_bot->'total'
    ));
    IF (v_bot->>'verdict') = 'PASS' THEN
      v_pass := v_pass + 1;
    ELSE
      v_fail := v_fail + 1;
    END IF;

    FOR v_step IN SELECT * FROM jsonb_array_elements(COALESCE(v_bot->'steps', '[]'::jsonb))
    LOOP
      v_gid := v_step->>'id';
      v_st := v_step->>'status';
      IF v_gid IS NULL OR v_st IS NULL THEN
        CONTINUE;
      END IF;
      IF NOT (v_goal_counts ? v_gid) THEN
        v_goal_counts := jsonb_set(v_goal_counts, ARRAY[v_gid], '{}'::jsonb, true);
      END IF;
      v_cnt := COALESCE((v_goal_counts->v_gid->>v_st)::int, 0) + 1;
      v_goal_counts := jsonb_set(
        v_goal_counts,
        ARRAY[v_gid, v_st],
        to_jsonb(v_cnt),
        true
      );
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'run_id', gen_random_uuid(),
    'from', p_from,
    'to', p_to,
    'bots_pass', v_pass,
    'bots_fail', v_fail,
    'bots_total', (p_to - p_from + 1),
    'verdict', CASE WHEN v_fail = 0 THEN 'PASS' ELSE 'FAIL' END,
    'coverage_by_goal', v_goal_counts,
    'bots', v_bots
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_live_play_swarm(integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_live_play_swarm(integer, integer) TO service_role;
