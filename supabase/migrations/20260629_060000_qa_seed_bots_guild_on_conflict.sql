-- qa_seed_bots: purge QA loncalar before seed (orphan guild rows after partial runs)

CREATE OR REPLACE FUNCTION public.qa_seed_bots(p_bot_count integer DEFAULT 1000)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, auth
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
  v_guild_number integer;
  v_current_guild_id uuid;
  v_item_id text;
  v_equip_slot text;
  v_slot text;
BEGIN
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.guild_contributions
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %');
  DELETE FROM public.guild_activities
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %');
  DELETE FROM public.guild_blueprints
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %');
  DELETE FROM public.guild_daily_donations
  WHERE guild_id IN (SELECT id FROM public.guilds WHERE name LIKE 'QA Lonca %');
  DELETE FROM public.guilds WHERE name LIKE 'QA Lonca %';

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
      v_bot_auth, 'authenticated', 'authenticated',
      format('qa_bot_%s@sim.local', v_idx),
      now(), now(), now(),
      jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
      jsonb_build_object('username', format('qa_bot_%s', v_idx), 'is_bot', true)
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
      v_bot_user, v_bot_auth,
      format('qa_bot_%s', v_idx),
      format('qa_bot_%s@sim.local', v_idx),
      format('QA Bot %s', v_idx),
      v_level, v_level * 120 + floor(random() * 500)::int,
      v_gold, v_energy, 100,
      18 + v_level * 3 + floor(random() * 8)::int,
      16 + v_level * 2 + floor(random() * 8)::int,
      120 + v_level * 8, 120 + v_level * 8, 100 + v_level * 12,
      true, (600 + floor(random() * 12000)::int),
      v_gems, v_level * 120,
      floor(random() * 12)::int, floor(random() * 10)::int,
      floor(random() * 80)::int, floor(random() * 80)::int,
      850 + floor(random() * 700)::int,
      floor(random() * (v_level * 20))::int,
      v_class, floor(random() * (10 + v_level))::int,
      v_guild_id,
      CASE WHEN ((v_idx - 1) % 40) = 0 THEN 'leader' ELSE 'member' END,
      now() - (floor(random() * 40)::text || ' days')::interval,
      now(), now() - (floor(random() * 6)::text || ' days')::interval
    )
    ON CONFLICT (auth_id) DO UPDATE SET
      username = EXCLUDED.username, level = EXCLUDED.level, gold = EXCLUDED.gold,
      gems = EXCLUDED.gems, character_class = EXCLUDED.character_class,
      guild_id = EXCLUDED.guild_id, guild_role = EXCLUDED.guild_role,
      updated_at = now();

    IF ((v_idx - 1) % 40) = 0 AND v_guild_id IS NOT NULL THEN
      INSERT INTO public.guilds (
        id, name, tag, leader_id, description, level, max_members, monument_level
      )
      VALUES (
        v_guild_id,
        format('QA Lonca %s', lpad(v_guild_number::text, 2, '0')),
        format('Q%s', lpad(v_guild_number::text, 2, '0')),
        v_bot_auth, 'Solo test loncasi',
        1 + floor(random() * 5)::int, 50, floor(random() * 10)::int
      )
      ON CONFLICT (name) DO NOTHING;
    END IF;

    INSERT INTO public.qa_bot_profiles (bot_auth_id, bot_user_id, segment, behavior_model, level_seed)
    VALUES (v_bot_auth, v_bot_user, v_segment, v_behavior, v_level)
    ON CONFLICT (bot_auth_id) DO UPDATE SET
      segment = EXCLUDED.segment, behavior_model = EXCLUDED.behavior_model, level_seed = EXCLUDED.level_seed;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'seeded_bots', p_bot_count,
    'segments', (
      SELECT coalesce(json_object_agg(segment, cnt), '{}'::json)
      FROM (SELECT segment, count(*) AS cnt FROM public.qa_bot_profiles GROUP BY segment) s
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.qa_seed_bots(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_seed_bots(integer) TO service_role;
