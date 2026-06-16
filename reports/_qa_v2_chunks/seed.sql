CREATE OR REPLACE FUNCTION public.qa_seed_bots(p_bot_count integer DEFAULT 100)
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
  v_gold integer;
  v_gems integer;
  v_energy integer;
  v_class text;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM auth.users au
  USING public.users u
  WHERE au.id = u.auth_id
    AND u.username LIKE 'qa_bot_%';

  DELETE FROM public.users WHERE username LIKE 'qa_bot_%';
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

    v_level := CASE v_segment
      WHEN 'newbie' THEN 1 + floor(random() * 6)::int
      WHEN 'casual' THEN 5 + floor(random() * 16)::int
      WHEN 'normal' THEN 12 + floor(random() * 20)::int
      WHEN 'hardcore' THEN 22 + floor(random() * 25)::int
      WHEN 'whale' THEN 30 + floor(random() * 35)::int
      WHEN 'trader' THEN 15 + floor(random() * 25)::int
      WHEN 'pvp' THEN 18 + floor(random() * 27)::int
      WHEN 'guild' THEN 10 + floor(random() * 22)::int
      WHEN 'multi' THEN 8 + floor(random() * 18)::int
      WHEN 'exploit' THEN 16 + floor(random() * 20)::int
      ELSE 1 + floor(random() * 10)::int
    END;

    v_gold := CASE v_segment
      WHEN 'newbie' THEN 500 + floor(random() * 5000)::int
      WHEN 'casual' THEN 3000 + floor(random() * 18000)::int
      WHEN 'normal' THEN 10000 + floor(random() * 50000)::int
      WHEN 'hardcore' THEN 25000 + floor(random() * 120000)::int
      WHEN 'whale' THEN 75000 + floor(random() * 450000)::int
      ELSE 8000 + floor(random() * 80000)::int
    END;

    v_gems := CASE v_segment
      WHEN 'newbie' THEN 0 + floor(random() * 35)::int
      WHEN 'casual' THEN 10 + floor(random() * 80)::int
      WHEN 'normal' THEN 15 + floor(random() * 120)::int
      WHEN 'hardcore' THEN 20 + floor(random() * 180)::int
      WHEN 'whale' THEN 120 + floor(random() * 900)::int
      ELSE 15 + floor(random() * 150)::int
    END;

    v_energy := 20 + floor(random() * 80)::int;

    v_class := CASE floor(random() * 3)::int
      WHEN 0 THEN 'warrior'
      WHEN 1 THEN 'alchemist'
      ELSE 'shadow'
    END;

    INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES (
      v_bot_auth,
      'authenticated',
      'authenticated',
      format('qa_bot_%s@sim.local', v_idx),
      now(),
      now(),
      now(),
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object('username', format('qa_bot_%s', v_idx), 'is_bot', true)
    );

    INSERT INTO public.users (
      id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
      attack, defense, health, max_health, power,
      tutorial_completed, total_playtime_seconds, gems, experience,
      addiction_level, tolerance,
      pvp_wins, pvp_losses, pvp_rating, reputation,
      character_class, luck,
      created_at, updated_at, last_login_at
    )
    VALUES (
      v_bot_user,
      v_bot_auth,
      format('qa_bot_%s', v_idx),
      format('qa_bot_%s@sim.local', v_idx),
      format('QA Bot %s', v_idx),
      v_level,
      v_level * 120,
      v_gold,
      v_energy,
      100,
      20 + v_level * 2,
      18 + v_level * 2,
      120 + v_level * 6,
      120 + v_level * 6,
      120 + v_level * 10,
      CASE WHEN v_segment = 'newbie' THEN false ELSE true END,
      (300 + floor(random() * 7000)::int),
      v_gems,
      v_level * 120,
      floor(random() * 20)::int,
      floor(random() * 15)::int,
      floor(random() * 120)::int,
      floor(random() * 120)::int,
      900 + floor(random() * 500)::int,
      floor(random() * 120)::int,
      v_class,
      floor(random() * 40)::int,
      now() - (floor(random() * 25)::text || ' days')::interval,
      now(),
      now() - (floor(random() * 4)::text || ' days')::interval
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
      created_at = LEAST(public.users.created_at, EXCLUDED.created_at),
      updated_at = EXCLUDED.updated_at,
      last_login_at = EXCLUDED.last_login_at;

    INSERT INTO public.qa_bot_profiles (bot_auth_id, bot_user_id, segment, behavior_model, level_seed)
    VALUES (v_bot_auth, v_bot_user, v_segment, v_behavior, v_level);
  END LOOP;

  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped, created_at, updated_at)
  SELECT
    gen_random_uuid(),
    b.bot_auth_id,
    x.item_id,
    GREATEST(1, floor(random() * 6)::int),
    x.slot_position,
    (x.slot_position <= 4),
    now(),
    now()
  FROM public.qa_bot_profiles b
  JOIN LATERAL (
    SELECT i.id AS item_id,
           row_number() OVER () AS slot_position
    FROM public.items i
    WHERE coalesce(i.required_level, 1) <= b.level_seed
    ORDER BY random()
    LIMIT (3 + floor(random() * 12)::int)
  ) x ON true;

  RETURN json_build_object(
    'success', true,
    'seeded_bots', p_bot_count,
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