-- AI Live-Play v2: fix SKIPs + trade/PvP/GW/bank/craft + economy report
-- purchase_market_listing(uuid, int), allocate_stat_points(int...), DM uses users.id

CREATE OR REPLACE FUNCTION public.qa_live_play_economy_report()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bots int;
  v_gold_sum bigint;
  v_gems_sum bigint;
  v_gold_avg numeric;
  v_open int;
  v_filled int;
  v_cancelled int;
  v_fill_rate numeric;
  v_dungeon_runs int;
  v_chat_dm int;
  v_trades int;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  SELECT count(*)::int,
         coalesce(sum(gold), 0)::bigint,
         coalesce(sum(gems), 0)::bigint,
         coalesce(avg(gold), 0)
  INTO v_bots, v_gold_sum, v_gems_sum, v_gold_avg
  FROM public.users WHERE username LIKE 'qa_bot_%';

  SELECT count(*) FILTER (WHERE status = 'open')::int,
         count(*) FILTER (WHERE status IN ('filled', 'partial', 'completed', 'sold'))::int,
         count(*) FILTER (WHERE status IN ('cancelled', 'canceled'))::int
  INTO v_open, v_filled, v_cancelled
  FROM public.market_orders
  WHERE seller_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR buyer_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  -- buyer_id may not exist — fallback without it
  IF NOT FOUND THEN
    NULL;
  END IF;

  BEGIN
    SELECT count(*) FILTER (WHERE status = 'open')::int,
           count(*) FILTER (WHERE status IN ('filled', 'completed', 'sold', 'matched'))::int,
           count(*) FILTER (WHERE status IN ('cancelled', 'canceled'))::int
    INTO v_open, v_filled, v_cancelled
    FROM public.market_orders mo
    WHERE mo.seller_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');
  EXCEPTION WHEN OTHERS THEN
    SELECT count(*) FILTER (WHERE status = 'open')::int,
           0,
           count(*) FILTER (WHERE status IN ('cancelled', 'canceled'))::int
    INTO v_open, v_filled, v_cancelled
    FROM public.market_orders mo
    WHERE mo.seller_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');
  END;

  IF (v_open + v_filled) > 0 THEN
    v_fill_rate := round((v_filled::numeric / (v_open + v_filled)::numeric) * 100, 2);
  ELSE
    v_fill_rate := 0;
  END IF;

  SELECT count(*)::int INTO v_dungeon_runs
  FROM public.dungeon_runs
  WHERE player_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  SELECT count(*)::int INTO v_chat_dm
  FROM public.chat_messages
  WHERE channel = 'dm'
    AND sender_user_id IN (SELECT id FROM public.users WHERE username LIKE 'qa_bot_%');

  SELECT count(*)::int INTO v_trades
  FROM public.trade_sessions
  WHERE initiator_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR partner_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  RETURN jsonb_build_object(
    'bots', v_bots,
    'gold_sum', v_gold_sum,
    'gems_sum', v_gems_sum,
    'gold_avg', v_gold_avg,
    'market_open', v_open,
    'market_filled', v_filled,
    'market_cancelled', v_cancelled,
    'market_fill_rate_pct', v_fill_rate,
    'dungeon_runs', v_dungeon_runs,
    'chat_dm_count', v_chat_dm,
    'trade_sessions', v_trades,
    'seed_gold_per_bot', 25000000,
    'note', 'Compare gold_sum to bots*seed_gold for economy delta'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_live_play_economy_report() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_live_play_economy_report() TO service_role;

-- Boost seed gold for GW attack cost (10M)
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
    ) VALUES (
      v_bot_auth, 'authenticated', 'authenticated',
      format('qa_bot_%s@sim.local', lpad(v_idx::text, 3, '0')),
      crypt(v_password, gen_salt('bf')),
      now(), now(), now(),
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object('username', format('qa_bot_%s', lpad(v_idx::text, 3, '0')), 'is_bot', true)
    );

    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
      gen_random_uuid(), v_bot_auth,
      jsonb_build_object('sub', v_bot_auth::text, 'email', format('qa_bot_%s@sim.local', lpad(v_idx::text, 3, '0'))),
      'email', v_bot_auth::text, now(), now(), now()
    ) ON CONFLICT DO NOTHING;

    INSERT INTO public.users (
      id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
      attack, defense, health, max_health, power,
      tutorial_completed, total_playtime_seconds, gems, experience,
      addiction_level, tolerance,
      pvp_wins, pvp_losses, pvp_rating, reputation,
      character_class, luck, guild_id, guild_role,
      created_at, updated_at, last_login_at
    ) VALUES (
      v_bot_user, v_bot_auth,
      format('qa_bot_%s', lpad(v_idx::text, 3, '0')),
      format('qa_bot_%s@sim.local', lpad(v_idx::text, 3, '0')),
      format('QA Bot %s', lpad(v_idx::text, 3, '0')),
      v_level, v_level * 200,
      25000000, 100, 100,
      80, 70, 500, 500, 2000,
      true, 3600, 5000, v_level * 200,
      0, 0, 5, 2, 1200, 500,
      v_class, 20, v_guild_id,
      CASE WHEN ((v_idx - 1) % v_guild_size) = 0 THEN 'leader' ELSE 'member' END,
      now(), now(), now()
    )
    ON CONFLICT (auth_id) DO UPDATE SET
      username = EXCLUDED.username, gold = EXCLUDED.gold, gems = EXCLUDED.gems,
      energy = EXCLUDED.energy, guild_id = EXCLUDED.guild_id, guild_role = EXCLUDED.guild_role,
      tutorial_completed = true, updated_at = now();

    UPDATE public.users SET stat_points = GREATEST(COALESCE(stat_points, 0), 10) WHERE auth_id = v_bot_auth;

    IF ((v_idx - 1) % v_guild_size) = 0 THEN
      INSERT INTO public.guilds (id, name, tag, leader_id, description, level, max_members, monument_level, vault_gold)
      VALUES (
        v_guild_id,
        format('QA Lonca %s', lpad(v_guild_number::text, 2, '0')),
        format('Q%s', lpad(v_guild_number::text, 2, '0')),
        v_bot_auth, 'AI live-play loncasi', 3, 50, 2, 1000000
      ) ON CONFLICT (name) DO NOTHING;
    END IF;

    INSERT INTO public.qa_bot_profiles (bot_auth_id, bot_user_id, segment, behavior_model, level_seed)
    VALUES (v_bot_auth, v_bot_user, 'live_play', 'full_feature_marathon', v_level)
    ON CONFLICT (bot_auth_id) DO UPDATE SET
      segment = EXCLUDED.segment, behavior_model = EXCLUDED.behavior_model, level_seed = EXCLUDED.level_seed;

    v_slot := 1;
    FOREACH v_item IN ARRAY v_kit LOOP
      IF EXISTS (SELECT 1 FROM public.items WHERE id = v_item) THEN
        INSERT INTO public.inventory (
          row_id, user_id, item_id, quantity, slot_position, is_equipped, enhancement_level, created_at, updated_at
        ) VALUES (
          gen_random_uuid(), v_bot_auth, v_item,
          CASE WHEN v_item LIKE 'scroll_%' OR v_item LIKE 'catalyst_%' OR v_item LIKE 'potion_%' THEN 5 ELSE 1 END,
          v_slot, (v_item LIKE 'wpn_%' OR v_item LIKE 'chest_%'), 0, now(), now()
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
    'email_pattern', 'qa_bot_NNN@sim.local',
    'seed_gold', 25000000
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_seed_live_play_bots(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_seed_live_play_bots(integer) TO service_role;
