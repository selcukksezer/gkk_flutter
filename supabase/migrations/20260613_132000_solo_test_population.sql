-- Solo test population: 1000 bots with varied level/gold/class/guild/equipped gear.
-- Runs automatically on migration apply (service role bypasses qa_mode guard).

BEGIN;

CREATE OR REPLACE FUNCTION public.qa_seed_bots(p_bot_count integer DEFAULT 1000)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_idx integer;
  v_bot_auth uuid;
  v_bot_user uuid;
  v_segment text;
  v_behavior text;
  v_level integer;
  v_gold bigint;
  v_gems integer;
  v_energy integer;
  v_class text;
  v_guild_id uuid;
  v_current_guild_id uuid := NULL;
  v_guild_number integer;
  v_slot text;
  v_item_id text;
  v_equip_slot text;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.market_orders
  WHERE seller_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR buyer_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.mekan_pvp_matches
  WHERE attacker_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR defender_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.pvp_matches
  WHERE attacker_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR defender_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR winner_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.pvp_tournament_matches
  WHERE player1_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR player2_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR winner_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.pvp_tournament_participants
  WHERE user_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.dungeon_runs
  WHERE player_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.trade_items
  WHERE session_id IN (
    SELECT id FROM public.trade_sessions
    WHERE initiator_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
       OR partner_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
  );

  DELETE FROM public.trade_sessions
  WHERE initiator_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR partner_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.mekans
  WHERE owner_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.inventory
  WHERE user_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.trade_sessions
  WHERE initiator_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%')
     OR partner_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.bp_player_quests
  WHERE player_id IN (SELECT id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.bp_player_status
  WHERE player_id IN (SELECT id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.guild_contributions
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %')
     OR user_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.guilds
  WHERE name LIKE 'QA Lonca %'
     OR leader_id IN (SELECT auth_id FROM public.users WHERE username LIKE 'qa_bot_%');

  DELETE FROM public.users WHERE username LIKE 'qa_bot_%';

  DELETE FROM auth.users WHERE email LIKE 'qa_bot_%@sim.local';

  DELETE FROM public.qa_bot_profiles;

  FOR v_idx IN 1..p_bot_count LOOP
    v_bot_auth := gen_random_uuid();
    v_bot_user := gen_random_uuid();

    v_segment := public.qa_segment_for_bot(v_idx, p_bot_count);

    v_behavior := CASE v_segment
      WHEN 'newbie' THEN 'first_time_no_guide_fast_bored'
      WHEN 'casual' THEN 'daily_15_min'
      WHEN 'normal' THEN 'daily_60_120_min'
      WHEN 'hardcore' THEN 'full_energy_optimizer'
      WHEN 'whale' THEN 'vip_premium_spender'
      WHEN 'trader' THEN 'buy_sell_flip_market'
      WHEN 'pvp' THEN 'constant_attack'
      WHEN 'guild' THEN 'social_coop'
      WHEN 'multi' THEN 'alt_account_farmer'
      WHEN 'exploit' THEN 'abuse_hunter'
      ELSE 'generic'
    END;

    -- Spread levels 1..65 across the whole population
    v_level := 1 + ((v_idx - 1) * 64 / GREATEST(p_bot_count - 1, 1));
    v_level := LEAST(65, GREATEST(1, v_level + floor(random() * 3)::int));

    v_gold := floor((1500 + power(v_level::numeric, 1.85) * 650) * (0.45 + random() * 1.10))::bigint;
    v_gems := floor((v_level * 2) * (0.5 + random()))::int;
    v_energy := 15 + floor(random() * 85)::int;

    v_class := (ARRAY['warrior', 'alchemist', 'shadow'])[1 + (v_idx % 3)];

    INSERT INTO auth.users (
      id, aud, role, email, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data
    )
    VALUES (
      v_bot_auth,
      'authenticated',
      'authenticated',
      format('qa_bot_%s@sim.local', lpad(v_idx::text, 4, '0')),
      now(),
      now(),
      now(),
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object('username', format('qa_bot_%s', lpad(v_idx::text, 4, '0')), 'is_bot', true)
    );

    IF ((v_idx - 1) % 40) = 0 THEN
      v_current_guild_id := gen_random_uuid();
    END IF;

    v_guild_id := v_current_guild_id;
    v_guild_number := 1 + ((v_idx - 1) / 40);

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
      v_bot_user,
      v_bot_auth,
      format('qa_bot_%s', lpad(v_idx::text, 4, '0')),
      format('qa_bot_%s@sim.local', lpad(v_idx::text, 4, '0')),
      format('QA Bot %s', v_idx),
      v_level,
      v_level * 120 + floor(random() * 500)::int,
      v_gold,
      v_energy,
      100,
      18 + v_level * 3 + floor(random() * 8)::int,
      16 + v_level * 2 + floor(random() * 8)::int,
      120 + v_level * 8,
      120 + v_level * 8,
      100 + v_level * 12,
      true,
      (600 + floor(random() * 12000)::int),
      v_gems,
      v_level * 120,
      floor(random() * 12)::int,
      floor(random() * 10)::int,
      floor(random() * 80)::int,
      floor(random() * 80)::int,
      850 + floor(random() * 700)::int,
      floor(random() * (v_level * 20))::int,
      v_class,
      floor(random() * (10 + v_level))::int,
      v_guild_id,
      CASE WHEN ((v_idx - 1) % 40) = 0 THEN 'leader' ELSE 'member' END,
      now() - (floor(random() * 40)::text || ' days')::interval,
      now(),
      now() - (floor(random() * 6)::text || ' days')::interval
    )
    ON CONFLICT (auth_id) DO UPDATE
    SET
      username = EXCLUDED.username,
      email = EXCLUDED.email,
      display_name = EXCLUDED.display_name,
      level = EXCLUDED.level,
      xp = EXCLUDED.xp,
      gold = EXCLUDED.gold,
      energy = EXCLUDED.energy,
      max_energy = EXCLUDED.max_energy,
      attack = EXCLUDED.attack,
      defense = EXCLUDED.defense,
      health = EXCLUDED.health,
      max_health = EXCLUDED.max_health,
      power = EXCLUDED.power,
      tutorial_completed = EXCLUDED.tutorial_completed,
      total_playtime_seconds = EXCLUDED.total_playtime_seconds,
      gems = EXCLUDED.gems,
      experience = EXCLUDED.experience,
      addiction_level = EXCLUDED.addiction_level,
      tolerance = EXCLUDED.tolerance,
      pvp_wins = EXCLUDED.pvp_wins,
      pvp_losses = EXCLUDED.pvp_losses,
      pvp_rating = EXCLUDED.pvp_rating,
      reputation = EXCLUDED.reputation,
      character_class = EXCLUDED.character_class,
      luck = EXCLUDED.luck,
      guild_id = EXCLUDED.guild_id,
      guild_role = EXCLUDED.guild_role,
      updated_at = EXCLUDED.updated_at,
      last_login_at = EXCLUDED.last_login_at;

    IF ((v_idx - 1) % 40) = 0 AND v_guild_id IS NOT NULL THEN
      INSERT INTO public.guilds (
        id, name, tag, leader_id, description, level, max_members, monument_level
      )
      VALUES (
        v_guild_id,
        format('QA Lonca %s', lpad(v_guild_number::text, 2, '0')),
        format('Q%s', lpad(v_guild_number::text, 2, '0')),
        v_bot_auth,
        'Solo test loncasi',
        1 + floor(random() * 5)::int,
        50,
        floor(random() * 10)::int
      );
    END IF;

    INSERT INTO public.qa_bot_profiles (bot_auth_id, bot_user_id, segment, behavior_model, level_seed)
    VALUES (v_bot_auth, v_bot_user, v_segment, v_behavior, v_level);

    -- Random inventory consumables/materials
    INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, created_at, updated_at)
    SELECT
      gen_random_uuid(),
      v_bot_auth,
      x.item_id,
      GREATEST(1, floor(random() * 8)::int),
      x.slot_position,
      false,
      now(),
      now()
    FROM (
      SELECT i.id AS item_id,
             row_number() OVER () - 1 AS slot_position
      FROM public.items i
      WHERE coalesce(i.required_level, 1) <= v_level
        AND lower(coalesce(i.type, '')) IN ('material', 'consumable', 'potion', 'scroll')
      ORDER BY random()
      LIMIT (4 + floor(random() * 8)::int)
    ) x;

    -- Equipped gear per slot
    FOREACH v_slot IN ARRAY ARRAY['weapon', 'chest', 'head', 'boots', 'gloves', 'ring', 'necklace'] LOOP
      SELECT i.id, lower(i.equip_slot)
      INTO v_item_id, v_equip_slot
      FROM public.items i
      WHERE lower(coalesce(i.equip_slot, '')) = v_slot
        AND lower(coalesce(i.type, '')) IN ('weapon', 'armor', 'accessory', 'helmet', 'gloves', 'boots')
        AND coalesce(i.required_level, 1) <= v_level
      ORDER BY random()
      LIMIT 1;

      IF v_item_id IS NOT NULL THEN
        INSERT INTO public.inventory (
          row_id, user_id, item_id, quantity, slot_position,
          is_equipped, equip_slot, enhancement_level, created_at, updated_at
        )
        VALUES (
          gen_random_uuid(),
          v_bot_auth,
          v_item_id,
          1,
          NULL,
          true,
          COALESCE(v_equip_slot, v_slot),
          floor(random() * LEAST(3, v_level / 10 + 1))::int,
          now(),
          now()
        );
      END IF;
    END LOOP;

    UPDATE public.users
    SET power = GREATEST(
      100,
      public.calculate_user_total_power(v_bot_auth)::integer
    )
    WHERE auth_id = v_bot_auth;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'seeded_bots', p_bot_count,
    'guilds_created', (SELECT count(*) FROM public.guilds WHERE name LIKE 'QA Lonca %'),
    'segments', (
      SELECT coalesce(json_object_agg(segment, cnt), '{}'::json)
      FROM (
        SELECT segment, count(*) AS cnt
        FROM public.qa_bot_profiles
        GROUP BY segment
      ) s
    )
  );
END;
$$;

-- Seed 1000 solo-test players on deploy
SELECT set_config('app.qa_mode', 'true', true);
SELECT public.qa_seed_bots(1000);

COMMIT;
