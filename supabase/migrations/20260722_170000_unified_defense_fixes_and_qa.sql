-- Unified defense: bonus yalnız bölge sahibi lonca slot savunucularına
-- + genişletilmiş QA smoke

BEGIN;

-- 1000 savunma = +25% kuşatma (100 elmas), tavan %25
CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_defense_multiplier(p_zone_number integer)
RETURNS numeric
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT LEAST(COALESCE(t.defense_power, 0)::numeric / 4000.0, 0.25)
  FROM public.guild_war_territories t
  WHERE t.zone_number = p_zone_number
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_defense_bonus_for_guild(
  p_zone_number integer,
  p_guild_id uuid
)
RETURNS numeric
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p_guild_id IS NULL THEN 0::numeric
    WHEN p_guild_id IS DISTINCT FROM public.dungeon_siege_territory_owner_for_zone(p_zone_number) THEN 0::numeric
    ELSE public.dungeon_siege_territory_defense_multiplier(p_zone_number)
  END;
$$;

CREATE OR REPLACE FUNCTION public.challenge_siege_slot(p_slot_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_cfg public.dungeon_siege_config;
  v_slot record;
  v_challenger record;
  v_defender record;
  v_att_power numeric;
  v_def_power numeric;
  v_defense_mult numeric := 0;
  v_win_chance numeric;
  v_winner_id uuid;
  v_loser_id uuid;
  v_ch_rating int;
  v_tg_rating int;
  v_hold public.dungeon_siege_holds;
  v_hold_broken boolean := false;
  v_ch_name text;
  v_def_name text;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_cfg := public.dungeon_siege_get_config();

  IF NOT v_cfg.is_enabled OR NOT public.dungeon_siege_in_prime_window() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  SELECT s.*, sess.dungeon_id, sess.id AS session_uuid, sess.zone_number
  INTO v_slot
  FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE s.id = p_slot_id
    AND sess.is_active = true
    AND sess.ends_at > now()
  FOR UPDATE OF s;

  IF NOT FOUND OR v_slot.holder_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Slot boş veya geçersiz.');
  END IF;

  IF v_slot.holder_id = v_me THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi slotuna meydan okuyamazsın.');
  END IF;

  IF public.dungeon_siege_is_banned(v_me, v_slot.dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindandan banlısın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastane/cezaevinde meydan okuyamazsın.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.dungeon_siege_challenges
    WHERE challenger_id = v_me
      AND created_at > now() - make_interval(mins => v_cfg.challenge_cooldown_minutes)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Meydan okuma bekleme süresindesin.');
  END IF;

  SELECT * INTO v_challenger FROM public.users WHERE auth_id = v_me FOR UPDATE;
  SELECT * INTO v_defender FROM public.users WHERE auth_id = v_slot.holder_id FOR UPDATE;

  IF v_challenger IS NULL OR v_defender IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  v_ch_name := COALESCE(v_challenger.display_name, v_challenger.username, 'Rakip');
  v_def_name := COALESCE(v_defender.display_name, v_defender.username, 'Rakip');

  IF v_challenger.guild_id IS NOT NULL AND v_challenger.guild_id = v_defender.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesine meydan okuyamazsın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_slot.holder_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakip hastane/cezaevinde.');
  END IF;

  IF v_challenger.gold < v_cfg.challenge_gold_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın.');
  END IF;

  v_att_power := COALESCE(public.calculate_user_total_power(v_me), v_challenger.power, 0);
  v_def_power := COALESCE(
    public.calculate_user_total_power(v_slot.holder_id),
    v_defender.power,
    0
  );

  IF v_att_power <= 0 THEN
    v_att_power := COALESCE(v_challenger.attack, 10) + COALESCE(v_challenger.defense, 10);
  END IF;
  IF v_def_power <= 0 THEN
    v_def_power := COALESCE(v_defender.attack, 10) + COALESCE(v_defender.defense, 10);
  END IF;
  IF COALESCE(v_challenger.character_class, '') = 'shadow' THEN v_att_power := v_att_power * 1.15; END IF;
  IF COALESCE(v_defender.character_class, '') = 'shadow' THEN v_def_power := v_def_power * 1.15; END IF;

  v_defense_mult := public.dungeon_siege_territory_defense_bonus_for_guild(
    v_slot.zone_number,
    v_defender.guild_id
  );
  IF v_defense_mult > 0 THEN
    v_def_power := v_def_power * (1 + v_defense_mult);
  END IF;

  IF v_cfg.power_band_pct > 0 THEN
    IF abs(v_att_power - v_def_power)
       > GREATEST(v_def_power, 1) * v_cfg.power_band_pct THEN
      RETURN jsonb_build_object('success', false, 'error', 'Güç farkı çok yüksek (±30%).');
    END IF;
  END IF;

  UPDATE public.users
  SET gold = gold - v_cfg.challenge_gold_cost
  WHERE auth_id = v_me AND gold >= v_cfg.challenge_gold_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altın düşülemedi.');
  END IF;

  PERFORM public.dungeon_siege_notify(
    v_slot.holder_id,
    'slot_challenged',
    'Kuşatma meydan okuması',
    v_ch_name || ' slotuna meydan okudu.',
    jsonb_build_object('slot_id', p_slot_id, 'dungeon_id', v_slot.dungeon_id, 'challenger_id', v_me)
  );

  v_win_chance := v_att_power / NULLIF(v_att_power + v_def_power, 0);
  IF v_win_chance IS NULL THEN v_win_chance := 0.5; END IF;

  IF random() <= v_win_chance THEN
    v_winner_id := v_me;
    v_loser_id := v_slot.holder_id;
    v_ch_rating := 15 + floor(random() * 10)::INT;
    v_tg_rating := -(10 + floor(random() * 5)::INT);
  ELSE
    v_winner_id := v_slot.holder_id;
    v_loser_id := v_me;
    v_ch_rating := -(10 + floor(random() * 5)::INT);
    v_tg_rating := 15 + floor(random() * 10)::INT;
  END IF;

  UPDATE public.users SET
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_ch_rating),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_me THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_me THEN 1 ELSE 0 END
  WHERE auth_id = v_me;

  UPDATE public.users SET
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_tg_rating),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_slot.holder_id THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_slot.holder_id THEN 1 ELSE 0 END
  WHERE auth_id = v_slot.holder_id;

  IF v_winner_id = v_me THEN
    UPDATE public.dungeon_siege_slots
    SET holder_id = v_me,
        guild_id = v_challenger.guild_id,
        claimed_at = now(),
        expires_at = now() + make_interval(mins => v_cfg.slot_duration_minutes),
        last_active_at = now()
    WHERE id = p_slot_id;

    PERFORM public.dungeon_siege_apply_ban(
      v_loser_id, v_slot.dungeon_id, v_cfg.ban_duration_minutes, 'siege_challenge_loss'
    );

    PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 25, p_challenges_won => 1);
  ELSE
    PERFORM public.dungeon_siege_apply_ban(
      v_loser_id, v_slot.dungeon_id, v_cfg.ban_duration_minutes, 'siege_challenge_loss'
    );
  END IF;

  PERFORM public.dungeon_siege_notify(
    v_slot.holder_id,
    'challenge_result',
    CASE WHEN v_winner_id = v_slot.holder_id THEN 'Meydan okumayı savuşturdun' ELSE 'Slot kaybettin' END,
    CASE WHEN v_winner_id = v_slot.holder_id
      THEN v_ch_name || ' ile düelloda kazandın.'
      ELSE v_ch_name || ' slotunu aldı.'
    END,
    jsonb_build_object('dungeon_id', v_slot.dungeon_id, 'winner_id', v_winner_id)
  );

  PERFORM public.dungeon_siege_notify(
    v_me,
    'challenge_result',
    CASE WHEN v_winner_id = v_me THEN 'Meydan okumayı kazandın' ELSE 'Meydan okumayı kaybettin' END,
    CASE WHEN v_winner_id = v_me
      THEN v_def_name || ' slotunu aldın.'
      ELSE v_def_name || ' seni yendi. ' || v_cfg.ban_duration_minutes || ' dk ban.'
    END,
    jsonb_build_object('dungeon_id', v_slot.dungeon_id, 'winner_id', v_winner_id)
  );

  v_hold := public.dungeon_siege_active_hold(v_slot.session_id);

  IF v_hold.id IS NOT NULL
     AND v_winner_id = v_me
     AND v_challenger.guild_id IS NOT NULL
     AND v_challenger.guild_id IS DISTINCT FROM v_hold.guild_id
     AND v_defender.guild_id = v_hold.guild_id THEN
    UPDATE public.dungeon_siege_holds
    SET break_progress = break_progress + 1
    WHERE id = v_hold.id
    RETURNING * INTO v_hold;

    IF v_hold.break_progress >= v_cfg.hold_break_wins_required THEN
      UPDATE public.dungeon_siege_holds
      SET is_active = false,
          broken_at = now(),
          ended_at = now()
      WHERE id = v_hold.id;

      v_hold_broken := true;

      PERFORM public.dungeon_siege_notify_hold_guild(
        v_slot.session_id,
        v_hold.guild_id,
        'hold_broken',
        'Lonca hold kırıldı',
        v_slot.dungeon_id || ' kuşatmasında hold''unuz kırıldı.',
        jsonb_build_object('session_id', v_slot.session_id, 'dungeon_id', v_slot.dungeon_id)
      );

      PERFORM public.dungeon_siege_notify(
        v_me,
        'hold_break_success',
        'Hold kırıldı',
        v_slot.dungeon_id || ' kuşatmasında rakip lonca hold''unu kırdın.',
        jsonb_build_object('session_id', v_slot.session_id, 'dungeon_id', v_slot.dungeon_id)
      );
    END IF;
  END IF;

  INSERT INTO public.dungeon_siege_challenges (
    slot_id, session_id, dungeon_id,
    challenger_id, defender_id,
    status, winner_id, gold_spent, resolved_at
  ) VALUES (
    p_slot_id, v_slot.session_id, v_slot.dungeon_id,
    v_me, v_slot.holder_id,
    'resolved', v_winner_id, v_cfg.challenge_gold_cost, now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'winner_id', v_winner_id,
    'you_won', v_winner_id = v_me,
    'gold_spent', v_cfg.challenge_gold_cost,
    'ban_minutes', v_cfg.ban_duration_minutes,
    'hold_broken', v_hold_broken,
    'hold_break_progress', CASE WHEN v_hold.id IS NOT NULL THEN v_hold.break_progress ELSE NULL END,
    'territory_defense_bonus_pct', v_defense_mult,
    'message', CASE
      WHEN v_winner_id = v_me AND v_hold_broken THEN 'Kazandın! Rakip lonca hold''u kırıldı.'
      WHEN v_winner_id = v_me THEN 'Kazandın! Slot senin.'
      ELSE 'Kaybettin. Bu zindandan banlandın.'
    END
  );
END;
$$;

-- get_dungeon_siege_status: owner lonca için geçerli bonus alanı
CREATE OR REPLACE FUNCTION public.get_dungeon_siege_status(p_dungeon_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_cfg public.dungeon_siege_config;
  v_sessions jsonb := '[]'::jsonb;
  v_my_slot jsonb := NULL;
  v_my_guild_id uuid;
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_cfg := public.dungeon_siege_get_config();

  IF v_me IS NOT NULL THEN
    SELECT guild_id INTO v_my_guild_id FROM public.users WHERE auth_id = v_me;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'session_id', sess.id,
    'dungeon_id', sess.dungeon_id,
    'zone_number', sess.zone_number,
    'ends_at', sess.ends_at,
    'territory_owner_guild_id', public.dungeon_siege_territory_owner_for_zone(sess.zone_number),
    'territory_owner_guild_name', (
      SELECT COALESCE(g.name, 'Sahipsiz')
      FROM public.guilds g
      WHERE g.id = public.dungeon_siege_territory_owner_for_zone(sess.zone_number)
    ),
    'territory_defense_power', public.dungeon_siege_territory_defense_power(sess.zone_number),
    'territory_defense_siege_bonus_pct', public.dungeon_siege_territory_defense_bonus_for_guild(
      sess.zone_number,
      v_my_guild_id
    ),
    'territory_defense_max_bonus_pct', public.dungeon_siege_territory_defense_multiplier(sess.zone_number),
    'guild_slots', CASE
      WHEN v_my_guild_id IS NULL THEN 0
      ELSE public.dungeon_siege_count_guild_slots(sess.id, v_my_guild_id)
    END,
    'hold', public.dungeon_siege_hold_json(sess.id),
    'slots', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'slot_id', s.id,
        'slot_number', s.slot_number,
        'holder_id', s.holder_id,
        'holder_name', COALESCE(u.display_name, u.username, '—'),
        'holder_power', COALESCE(u.power, 0),
        'guild_id', s.guild_id,
        'guild_name', g.name,
        'expires_at', s.expires_at,
        'last_active_at', s.last_active_at,
        'is_mine', s.holder_id = v_me,
        'is_territory_reserved', s.slot_number <= v_cfg.territory_reserve_slot_count
          AND public.dungeon_siege_territory_owner_for_zone(sess.zone_number) IS NOT NULL
      ) ORDER BY s.slot_number), '[]'::jsonb)
      FROM public.dungeon_siege_slots s
      LEFT JOIN public.users u ON u.auth_id = s.holder_id
      LEFT JOIN public.guilds g ON g.id = s.guild_id
      WHERE s.session_id = sess.id
    )
  ) ORDER BY sess.zone_number), '[]'::jsonb)
  INTO v_sessions
  FROM public.dungeon_siege_sessions sess
  WHERE sess.is_active = true
    AND sess.ends_at > now()
    AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id);

  IF v_me IS NOT NULL THEN
    SELECT jsonb_build_object(
      'slot_id', s.id,
      'slot_number', s.slot_number,
      'dungeon_id', sess.dungeon_id,
      'expires_at', s.expires_at
    )
    INTO v_my_slot
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = v_me
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id)
    ORDER BY s.claimed_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'enabled', v_cfg.is_enabled,
    'in_prime_window', public.dungeon_siege_in_prime_window(),
    'siege_active', v_cfg.is_enabled AND public.dungeon_siege_in_prime_window(),
    'sessions', v_sessions,
    'my_slot', v_my_slot,
    'is_banned', CASE
      WHEN v_me IS NULL OR p_dungeon_id IS NULL THEN false
      ELSE public.dungeon_siege_is_banned(v_me, p_dungeon_id)
    END,
    'config', public.get_dungeon_siege_config()
  );
END;
$$;

-- Ana smoke: prod is_enabled=true uyumlu restore
CREATE OR REPLACE FUNCTION public.qa_smoke_dungeon_siege()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth_a uuid := gen_random_uuid();
  v_auth_b uuid := gen_random_uuid();
  v_guild_a uuid := gen_random_uuid();
  v_guild_b uuid := gen_random_uuid();
  v_dungeon text := 'dng_010';
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_cfg jsonb;
  v_status jsonb;
  v_hub jsonb;
  v_lb jsonb;
  v_claim jsonb;
  v_release jsonb;
  v_challenge jsonb;
  v_notifs jsonb;
  v_slot_id uuid;
  v_prev_enabled boolean;
  v_prev_windows jsonb;
  v_prev_gold_cost integer;
  v_prev_power_band numeric;
  v_prev_cooldown integer;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  DELETE FROM public.dungeon_siege_notifications WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.dungeon_siege_challenges WHERE challenger_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  ) OR defender_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.dungeon_siege_bans WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_guild_a, v_guild_b);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id = v_dungeon
    AND created_at > now() - interval '1 hour';
  DELETE FROM public.guild_contributions WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM public.guilds WHERE leader_id IN (
    SELECT auth_id FROM public.users WHERE username LIKE 'qa_siege_smoke_%'
  );
  DELETE FROM auth.users WHERE email LIKE 'qa_siege_smoke_%@sim.local';
  DELETE FROM public.users WHERE username LIKE 'qa_siege_smoke_%';

  SELECT is_enabled, prime_windows, challenge_gold_cost, power_band_pct, challenge_cooldown_minutes
  INTO v_prev_enabled, v_prev_windows, v_prev_gold_cost, v_prev_power_band, v_prev_cooldown
  FROM public.dungeon_siege_config
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  v_ok := EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'dungeon_siege_config'
  );
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_table_exists',
    'area', 'schema',
    'pass', v_ok
  ));

  v_ok := to_regprocedure('public.get_dungeon_siege_config()') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_status(text)') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_hub()') IS NOT NULL
      AND to_regprocedure('public.get_dungeon_siege_leaderboard(integer)') IS NOT NULL
      AND to_regprocedure('public.claim_siege_slot(text)') IS NOT NULL
      AND to_regprocedure('public.challenge_siege_slot(uuid)') IS NOT NULL
      AND to_regprocedure('public.release_siege_slot(uuid)') IS NOT NULL
      AND to_regprocedure('public.dungeon_siege_territory_defense_bonus_for_guild(integer,uuid)') IS NOT NULL;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_rpc_functions_exist',
    'area', 'schema',
    'pass', v_ok
  ));

  v_cfg := public.get_dungeon_siege_config();
  v_ok := v_cfg ? 'is_enabled'
      AND v_cfg ? 'slot_count'
      AND v_cfg ? 'siege_dungeon_ids'
      AND jsonb_typeof(v_cfg->'siege_dungeon_ids') = 'array';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_rpc_shape',
    'area', 'rpc',
    'pass', v_ok,
    'detail', v_cfg
  ));

  v_status := public.get_dungeon_siege_status(NULL);
  v_ok := v_status ? 'enabled'
      AND v_status ? 'sessions'
      AND v_status ? 'config';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_status_rpc_shape',
    'area', 'rpc',
    'pass', v_ok
  ));

  v_hub := public.get_dungeon_siege_hub();
  v_ok := v_hub ? 'status'
      AND v_hub ? 'leaderboard'
      AND v_hub ? 'territories';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_hub_rpc_shape',
    'area', 'rpc',
    'pass', v_ok
  ));

  v_lb := public.get_dungeon_siege_leaderboard(5);
  v_ok := v_lb ? 'week_key' AND v_lb ? 'entries';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_leaderboard_rpc_shape',
    'area', 'rpc',
    'pass', v_ok
  ));

  INSERT INTO public.guilds (id, name, tag, leader_id, founder_id, member_count, created_at, updated_at)
  VALUES
    (v_guild_a, 'QA Siege A', 'QSA', v_auth_a, v_auth_a, 1, now(), now()),
    (v_guild_b, 'QA Siege B', 'QSB', v_auth_b, v_auth_b, 1, now(), now());

  INSERT INTO auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) VALUES
    (v_auth_a, 'authenticated', 'authenticated', 'qa_siege_smoke_a@sim.local', now(), now(), now(),
     jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
     jsonb_build_object('username', 'qa_siege_smoke_a', 'is_bot', true)),
    (v_auth_b, 'authenticated', 'authenticated', 'qa_siege_smoke_b@sim.local', now(), now(), now(),
     jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
     jsonb_build_object('username', 'qa_siege_smoke_b', 'is_bot', true));

  UPDATE public.users
  SET username = 'qa_siege_smoke_a', email = 'qa_siege_smoke_a@sim.local', display_name = 'QA Siege A',
      level = 20, gold = 500000, power = 500, gems = 50, guild_id = v_guild_a, updated_at = now()
  WHERE auth_id = v_auth_a;

  UPDATE public.users
  SET username = 'qa_siege_smoke_b', email = 'qa_siege_smoke_b@sim.local', display_name = 'QA Siege B',
      level = 20, gold = 500000, power = 480, gems = 50, guild_id = v_guild_b, updated_at = now()
  WHERE auth_id = v_auth_b;

  INSERT INTO public.guild_contributions (guild_id, user_id)
  VALUES (v_guild_a, v_auth_a), (v_guild_b, v_auth_b)
  ON CONFLICT DO NOTHING;

  UPDATE public.dungeon_siege_config
  SET is_enabled = true,
      prime_windows = '[{"start":"00:00","end":"23:59"}]'::jsonb,
      challenge_gold_cost = 100,
      challenge_cooldown_minutes = 1,
      power_band_pct = 1.0,
      updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_auth_a::text, true);
  v_claim := public.claim_siege_slot(v_dungeon);
  v_ok := COALESCE((v_claim->>'success')::boolean, false) AND v_claim ? 'slot_id';
  v_slot_id := NULLIF(v_claim->>'slot_id', '')::uuid;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_claim_slot',
    'area', 'gameplay',
    'pass', v_ok,
    'detail', v_claim
  ));

  PERFORM set_config('request.jwt.claim.sub', v_auth_b::text, true);
  v_challenge := public.challenge_siege_slot(v_slot_id);
  v_ok := COALESCE((v_challenge->>'success')::boolean, false)
      AND COALESCE((v_challenge->>'territory_defense_bonus_pct')::numeric, -1) = 0;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_challenge_no_bonus_for_non_owner_guild',
    'area', 'unified_defense',
    'pass', v_ok,
    'detail', v_challenge
  ));

  PERFORM set_config('request.jwt.claim.sub', v_auth_a::text, true);
  v_notifs := public.get_dungeon_siege_notifications(10);
  v_ok := COALESCE((v_notifs->>'success')::boolean, false) AND v_notifs ? 'notifications';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_notifications_rpc',
    'area', 'rpc',
    'pass', v_ok
  ));

  PERFORM set_config('request.jwt.claim.sub', COALESCE(v_challenge->>'winner_id', v_auth_a::text), true);
  SELECT s.id INTO v_slot_id
  FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE sess.dungeon_id = v_dungeon AND s.holder_id IS NOT NULL
  ORDER BY s.claimed_at DESC NULLS LAST
  LIMIT 1;

  IF v_slot_id IS NOT NULL THEN
    v_release := public.release_siege_slot(v_slot_id);
    v_ok := COALESCE((v_release->>'success')::boolean, false);
  ELSE
    v_ok := true;
    v_release := jsonb_build_object('skipped', true);
  END IF;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_release_slot',
    'area', 'gameplay',
    'pass', v_ok,
    'detail', v_release
  ));

  UPDATE public.dungeon_siege_config
  SET is_enabled = COALESCE(v_prev_enabled, false),
      prime_windows = COALESCE(v_prev_windows, prime_windows),
      challenge_gold_cost = COALESCE(v_prev_gold_cost, challenge_gold_cost),
      power_band_pct = COALESCE(v_prev_power_band, power_band_pct),
      challenge_cooldown_minutes = COALESCE(v_prev_cooldown, challenge_cooldown_minutes),
      updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  v_ok := public.dungeon_siege_is_enabled() = COALESCE(v_prev_enabled, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'siege_config_restored',
    'area', 'cleanup',
    'pass', v_ok
  ));

  DELETE FROM public.dungeon_siege_notifications WHERE player_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_challenges WHERE challenger_id IN (v_auth_a, v_auth_b)
    OR defender_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_bans WHERE player_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_guild_a, v_guild_b);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id = v_dungeon
    AND created_at > now() - interval '1 hour';
  DELETE FROM public.guild_contributions WHERE user_id IN (v_auth_a, v_auth_b);
  DELETE FROM public.guilds WHERE id IN (v_guild_a, v_guild_b);
  DELETE FROM auth.users WHERE id IN (v_auth_a, v_auth_b);
  DELETE FROM public.users WHERE auth_id IN (v_auth_a, v_auth_b);

  RETURN jsonb_build_object(
    'verdict', CASE WHEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) t
      WHERE NOT COALESCE((t->>'pass')::boolean, false)
    ) THEN 'FAIL' ELSE 'PASS' END,
    'total', jsonb_array_length(v_results),
    'passed', (
      SELECT COUNT(*)::integer FROM jsonb_array_elements(v_results) t
      WHERE COALESCE((t->>'pass')::boolean, false)
    ),
    'tests', v_results
  );
END;
$$;

-- Unified defense odaklı smoke
CREATE OR REPLACE FUNCTION public.qa_smoke_unified_defense()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_owner uuid := gen_random_uuid();
  v_intruder uuid := gen_random_uuid();
  v_owner_guild uuid := gen_random_uuid();
  v_intruder_guild uuid := gen_random_uuid();
  v_territory_id uuid;
  v_prev_owner uuid;
  v_prev_defense integer;
  v_dungeon text := 'dng_030';
  v_claim jsonb;
  v_hold jsonb;
  v_challenge jsonb;
  v_slot_id uuid;
  v_bonus numeric;
  v_status jsonb;
  v_session jsonb;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);
  PERFORM public.qa_assert_qa_mode();

  SELECT id, owner_guild_id, defense_power
  INTO v_territory_id, v_prev_owner, v_prev_defense
  FROM public.guild_war_territories
  WHERE zone_number = 3
  LIMIT 1;

  v_ok := public.dungeon_siege_territory_defense_multiplier(3)
      = LEAST(COALESCE(v_prev_defense, 0)::numeric / 4000.0, 0.25);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'defense_multiplier_formula',
    'area', 'math',
    'pass', v_ok
  ));

  v_ok := public.dungeon_siege_territory_defense_bonus_for_guild(3, gen_random_uuid()) = 0;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'defense_bonus_zero_for_non_owner',
    'area', 'math',
    'pass', v_ok
  ));

  -- cleanup
  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_owner_guild, v_intruder_guild);
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (v_owner, v_intruder);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id = v_dungeon AND created_at > now() - interval '1 hour';
  DELETE FROM public.guilds WHERE id IN (v_owner_guild, v_intruder_guild);
  DELETE FROM auth.users WHERE id IN (v_owner, v_intruder);
  DELETE FROM public.users WHERE auth_id IN (v_owner, v_intruder);

  INSERT INTO public.guilds (id, name, tag, leader_id, founder_id, member_count, created_at, updated_at)
  VALUES
    (v_owner_guild, 'QA Def Owner', 'QDO', v_owner, v_owner, 1, now(), now()),
    (v_intruder_guild, 'QA Def Intruder', 'QDI', v_intruder, v_intruder, 1, now(), now());

  INSERT INTO auth.users (id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES
    (v_owner, 'authenticated', 'authenticated', 'qa_unified_owner@sim.local', now(), now(), now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{"username":"qa_unified_owner","is_bot":true}'::jsonb),
    (v_intruder, 'authenticated', 'authenticated', 'qa_unified_intruder@sim.local', now(), now(), now(),
     '{"provider":"email","providers":["email"]}'::jsonb, '{"username":"qa_unified_intruder","is_bot":true}'::jsonb);

  UPDATE public.users SET username = 'qa_unified_owner', guild_id = v_owner_guild, gold = 500000, power = 500, gems = 100
  WHERE auth_id = v_owner;
  UPDATE public.users SET username = 'qa_unified_intruder', guild_id = v_intruder_guild, gold = 500000, power = 480, gems = 100
  WHERE auth_id = v_intruder;

  UPDATE public.guild_war_territories
  SET owner_guild_id = v_owner_guild,
      defense_power = 800
  WHERE id = v_territory_id;

  v_bonus := public.dungeon_siege_territory_defense_bonus_for_guild(3, v_owner_guild);
  v_ok := v_bonus = 0.2;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'defense_bonus_for_owner_guild',
    'area', 'math',
    'pass', v_ok,
    'detail', jsonb_build_object('bonus', v_bonus)
  ));

  UPDATE public.dungeon_siege_config
  SET is_enabled = true,
      prime_windows = '[{"start":"00:00","end":"23:59"}]'::jsonb,
      challenge_gold_cost = 100,
      challenge_cooldown_minutes = 1,
      power_band_pct = 1.0
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  -- owner claims + hold (1 slot yeter)
  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  v_claim := public.claim_siege_slot(v_dungeon);
  v_slot_id := NULLIF(v_claim->>'slot_id', '')::uuid;

  -- intruder hold blocked (owner henüz hold başlatmadı)
  PERFORM set_config('request.jwt.claim.sub', v_intruder::text, true);
  v_hold := public.start_siege_guild_hold(v_dungeon);
  v_ok := COALESCE((v_hold->>'success')::boolean, true) = false
      AND COALESCE(v_hold->>'error', '') LIKE '%bölge sahibi%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'hold_blocked_for_non_owner',
    'area', 'hold',
    'pass', v_ok,
    'detail', v_hold
  ));

  -- owner hold (1 slot yeter)
  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  v_hold := public.start_siege_guild_hold(v_dungeon);
  v_ok := COALESCE((v_hold->>'success')::boolean, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'hold_allowed_for_territory_owner_one_slot',
    'area', 'hold',
    'pass', v_ok,
    'detail', v_hold
  ));

  -- intruder challenges owner: owner guild gets bonus
  PERFORM set_config('request.jwt.claim.sub', v_intruder::text, true);
  v_challenge := public.challenge_siege_slot(v_slot_id);
  v_ok := COALESCE((v_challenge->>'success')::boolean, false)
      AND COALESCE((v_challenge->>'territory_defense_bonus_pct')::numeric, 0) = 0.2;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'challenge_applies_bonus_to_owner_guild_defender',
    'area', 'unified_defense',
    'pass', v_ok,
    'detail', v_challenge
  ));

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  v_status := public.get_dungeon_siege_status(v_dungeon);
  SELECT elem INTO v_session
  FROM jsonb_array_elements(v_status->'sessions') elem
  WHERE elem->>'dungeon_id' = v_dungeon
  LIMIT 1;
  v_ok := v_session ? 'territory_defense_power'
      AND v_session ? 'territory_defense_siege_bonus_pct'
      AND COALESCE((v_session->>'territory_defense_siege_bonus_pct')::numeric, 0) = 0.2;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'status_includes_owner_applicable_bonus',
    'area', 'rpc',
    'pass', v_ok,
    'detail', v_session
  ));

  -- restore territory + cleanup
  UPDATE public.guild_war_territories
  SET owner_guild_id = v_prev_owner,
      defense_power = v_prev_defense
  WHERE id = v_territory_id;

  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_owner_guild, v_intruder_guild);
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (v_owner, v_intruder);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id = v_dungeon AND created_at > now() - interval '1 hour';
  DELETE FROM public.guilds WHERE id IN (v_owner_guild, v_intruder_guild);
  DELETE FROM auth.users WHERE id IN (v_owner, v_intruder);
  DELETE FROM public.users WHERE auth_id IN (v_owner, v_intruder);

  RETURN jsonb_build_object(
    'verdict', CASE WHEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) t
      WHERE NOT COALESCE((t->>'pass')::boolean, false)
    ) THEN 'FAIL' ELSE 'PASS' END,
    'total', jsonb_array_length(v_results),
    'passed', (
      SELECT COUNT(*)::integer FROM jsonb_array_elements(v_results) t
      WHERE COALESCE((t->>'pass')::boolean, false)
    ),
    'tests', v_results
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dungeon_siege_territory_defense_bonus_for_guild(integer, uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.qa_smoke_unified_defense() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_smoke_unified_defense() TO service_role;

COMMIT;
