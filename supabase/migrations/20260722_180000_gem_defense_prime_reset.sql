-- Elmas savunması: geçici katman (gem_defense_boost), prime time dışında sıfırlanır

BEGIN;

ALTER TABLE public.guild_war_territories
  ADD COLUMN IF NOT EXISTS gem_defense_boost integer NOT NULL DEFAULT 0;

ALTER TABLE public.guild_war_territories
  DROP CONSTRAINT IF EXISTS guild_war_territories_gem_defense_boost_nonneg;

ALTER TABLE public.guild_war_territories
  ADD CONSTRAINT guild_war_territories_gem_defense_boost_nonneg
  CHECK (gem_defense_boost >= 0);

CREATE OR REPLACE FUNCTION public.guild_war_territory_effective_defense(
  p_defense_power integer,
  p_gem_defense_boost integer
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT GREATEST(COALESCE(p_defense_power, 0), 0) + GREATEST(COALESCE(p_gem_defense_boost, 0), 0);
$$;

CREATE OR REPLACE FUNCTION public.guild_war_reset_gem_defense_outside_prime()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_reset integer;
BEGIN
  IF public.dungeon_siege_in_prime_window() THEN
    RETURN 0;
  END IF;

  UPDATE public.guild_war_territories
  SET gem_defense_boost = 0,
      updated_at = now()
  WHERE gem_defense_boost > 0;

  GET DIAGNOSTICS v_reset = ROW_COUNT;
  RETURN v_reset;
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_defense_multiplier(p_zone_number integer)
RETURNS numeric
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT LEAST(
    public.guild_war_territory_effective_defense(t.defense_power, t.gem_defense_boost)::numeric / 4000.0,
    0.25
  )
  FROM public.guild_war_territories t
  WHERE t.zone_number = p_zone_number
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_defense_power(p_zone_number integer)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT public.guild_war_territory_effective_defense(t.defense_power, t.gem_defense_boost)
  FROM public.guild_war_territories t
  WHERE t.zone_number = p_zone_number
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_cleanup()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
BEGIN
  PERFORM public.guild_war_reset_gem_defense_outside_prime();

  v_cfg := public.dungeon_siege_get_config();

  UPDATE public.dungeon_siege_sessions
  SET is_active = false
  WHERE is_active = true AND ends_at <= now();

  UPDATE public.dungeon_siege_holds h
  SET is_active = false,
      ended_at = now()
  FROM public.dungeon_siege_sessions sess
  WHERE h.session_id = sess.id
    AND h.is_active = true
    AND (NOT sess.is_active OR sess.ends_at <= now());

  UPDATE public.dungeon_siege_holds h
  SET is_active = false,
      ended_at = now()
  FROM public.dungeon_siege_sessions sess
  WHERE h.session_id = sess.id
    AND h.is_active = true
    AND sess.is_active = true
    AND sess.ends_at > now()
    AND public.dungeon_siege_count_guild_slots(sess.id, h.guild_id) < v_cfg.hold_min_members;

  UPDATE public.dungeon_siege_slots s
  SET holder_id = NULL,
      guild_id = NULL,
      claimed_at = NULL,
      expires_at = NULL,
      last_active_at = NULL
  FROM public.dungeon_siege_sessions sess
  WHERE s.session_id = sess.id
    AND s.holder_id IS NOT NULL
    AND (
      (s.expires_at IS NOT NULL AND s.expires_at <= now())
      OR (
        s.last_active_at IS NOT NULL
        AND s.last_active_at <= now() - make_interval(mins => v_cfg.inactive_release_minutes)
      )
    );

  DELETE FROM public.dungeon_siege_bans WHERE banned_until <= now();
END;
$$;

CREATE OR REPLACE FUNCTION public.add_territory_defense(
  p_territory_id uuid,
  p_gems integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_guild_id uuid;
  v_territory record;
  v_player_gems integer;
  v_defense_increase integer;
  v_siege_bonus_pct numeric;
  v_effective_defense integer;
BEGIN
  IF p_gems IS NULL OR p_gems <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'Geçersiz elmas miktarı.');
  END IF;

  IF NOT public.dungeon_siege_is_enabled() OR NOT public.dungeon_siege_in_prime_window() THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Elmas savunması yalnızca kuşatma prime time''ında eklenebilir.'
    );
  END IF;

  SELECT guild_id INTO v_guild_id
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT * INTO v_territory
  FROM public.guild_war_territories
  WHERE id = p_territory_id
  FOR UPDATE;

  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id != v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Sadece kendi bölgenize savunma ekleyebilirsiniz.');
  END IF;

  SELECT gems INTO v_player_gems
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_player_gems < p_gems THEN
    RETURN json_build_object('success', false, 'error', 'Yeterli elmasınız yok.');
  END IF;

  v_defense_increase := p_gems * 10;

  UPDATE public.users
  SET gems = gems - p_gems
  WHERE auth_id = v_player_id;

  UPDATE public.guild_war_territories
  SET gem_defense_boost = gem_defense_boost + v_defense_increase,
      defense_added_at = now(),
      updated_at = now()
  WHERE id = p_territory_id
  RETURNING * INTO v_territory;

  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power,
    v_territory.gem_defense_boost
  );
  v_siege_bonus_pct := public.dungeon_siege_territory_defense_multiplier(v_territory.zone_number);

  RETURN json_build_object(
    'success', true,
    'message', format(
      'Prime time savunması +%s (toplam %s). Prime bitince elmas savunması sıfırlanır. Kuşatma +%s%%.',
      v_defense_increase,
      v_effective_defense,
      round(v_siege_bonus_pct * 100)
    ),
    'gem_defense_boost', v_territory.gem_defense_boost,
    'effective_defense', v_effective_defense,
    'siege_bonus_pct', v_siege_bonus_pct
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.attack_guild_war_territory(
  p_territory_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_guild_id uuid;
  v_territory record;
  v_attack_power integer;
  v_effective_defense integer;
  v_success boolean;
  v_points_gained integer;
  v_active_season_id uuid;
BEGIN
  SELECT guild_id INTO v_guild_id
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT * INTO v_territory
  FROM public.guild_war_territories
  WHERE id = p_territory_id;

  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  SELECT COALESCE(level * 50, 100) INTO v_attack_power
  FROM public.users WHERE auth_id = v_player_id;

  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power,
    v_territory.gem_defense_boost
  );

  v_success := (random() * v_attack_power) > (random() * GREATEST(v_effective_defense, 1));
  v_points_gained := CASE WHEN v_success THEN 100 ELSE 10 END;

  SELECT id INTO v_active_season_id
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_active_season_id IS NOT NULL THEN
    INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
    VALUES (
      v_active_season_id,
      v_guild_id,
      v_points_gained,
      CASE WHEN v_success THEN 1 ELSE 0 END,
      CASE WHEN v_success THEN 0 ELSE 1 END
    )
    ON CONFLICT (season_id, guild_id)
    DO UPDATE SET
      points = guild_war_rankings.points + v_points_gained,
      wins = guild_war_rankings.wins + (CASE WHEN v_success THEN 1 ELSE 0 END),
      losses = guild_war_rankings.losses + (CASE WHEN v_success THEN 0 ELSE 1 END),
      updated_at = now();
  END IF;

  IF v_success THEN
    UPDATE public.guild_war_territories
    SET owner_guild_id = v_guild_id,
        defense_power = v_attack_power,
        gem_defense_boost = 0,
        updated_at = now()
    WHERE id = p_territory_id;
  END IF;

  INSERT INTO public.guild_war_attack_logs (
    territory_id,
    attacker_guild_id,
    defender_guild_id,
    attack_power,
    defense_power,
    success,
    points_gained
  ) VALUES (
    p_territory_id,
    v_guild_id,
    v_territory.owner_guild_id,
    v_attack_power,
    v_effective_defense,
    v_success,
    v_points_gained
  );

  RETURN json_build_object(
    'success', v_success,
    'message', CASE WHEN v_success THEN 'Bölge ele geçirildi!' ELSE 'Saldırı başarısız!' END,
    'attack_power', v_attack_power,
    'defense_power', v_effective_defense,
    'points_gained', v_points_gained
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_guild_war_territories()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result json;
BEGIN
  PERFORM public.guild_war_reset_gem_defense_outside_prime();

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      t.id,
      t.name,
      t.owner_guild_id,
      COALESCE(g.name, 'Sahipsiz') AS "owner_guild",
      t.defense_power,
      t.gem_defense_boost,
      public.guild_war_territory_effective_defense(t.defense_power, t.gem_defense_boost) AS effective_defense_power,
      t.base_defense_power,
      t.defense_line_level,
      t.reward,
      COALESCE(t.trade_income, 0) AS trade_income,
      t.zone_number
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    ORDER BY t.zone_number NULLS LAST, t.name
  ) t;

  RETURN v_result;
END;
$$;

-- Hub bölge satırında elmas savunması görünsün
CREATE OR REPLACE FUNCTION public.get_dungeon_siege_hub()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_week text := public.dungeon_siege_week_key();
  v_status jsonb;
  v_recent jsonb;
  v_leaderboard jsonb;
  v_territories jsonb;
BEGIN
  PERFORM public.dungeon_siege_cleanup();

  v_status := public.get_dungeon_siege_status(NULL);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'dungeon_id', c.dungeon_id,
    'challenger_name', COALESCE(uc.display_name, uc.username, '—'),
    'defender_name', COALESCE(ud.display_name, ud.username, '—'),
    'winner_name', COALESCE(uw.display_name, uw.username, '—'),
    'you_were_involved', auth.uid() IN (c.challenger_id, c.defender_id),
    'resolved_at', c.resolved_at
  ) ORDER BY c.resolved_at DESC), '[]'::jsonb)
  INTO v_recent
  FROM (
    SELECT c.*
    FROM public.dungeon_siege_challenges c
    WHERE c.status = 'resolved'
      AND c.resolved_at > now() - interval '24 hours'
    ORDER BY c.resolved_at DESC
    LIMIT 30
  ) c
  LEFT JOIN public.users uc ON uc.auth_id = c.challenger_id
  LEFT JOIN public.users ud ON ud.auth_id = c.defender_id
  LEFT JOIN public.users uw ON uw.auth_id = c.winner_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'rank', s.row_number,
    'player_id', s.player_id,
    'player_name', COALESCE(u.display_name, u.username, '—'),
    'guild_name', g.name,
    'points', s.points,
    'challenges_won', s.challenges_won,
    'slot_minutes', s.slot_minutes
  ) ORDER BY s.row_number), '[]'::jsonb)
  INTO v_leaderboard
  FROM (
    SELECT
      player_id,
      points,
      challenges_won,
      slot_minutes,
      ROW_NUMBER() OVER (ORDER BY points DESC, challenges_won DESC) AS row_number
    FROM public.dungeon_siege_weekly_scores
    WHERE week_key = v_week
    ORDER BY points DESC, challenges_won DESC
    LIMIT 20
  ) s
  LEFT JOIN public.users u ON u.auth_id = s.player_id
  LEFT JOIN public.guilds g ON g.id = u.guild_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'zone_number', t.zone_number,
    'territory_id', t.id,
    'territory_name', t.name,
    'owner_guild_id', t.owner_guild_id,
    'owner_guild_name', COALESCE(g.name, 'Sahipsiz'),
    'defense_power', public.guild_war_territory_effective_defense(t.defense_power, t.gem_defense_boost),
    'base_defense_power', t.defense_power,
    'gem_defense_boost', COALESCE(t.gem_defense_boost, 0),
    'defense_siege_bonus_pct', public.dungeon_siege_territory_defense_multiplier(t.zone_number),
    'siege_dungeon_id', CASE t.zone_number
      WHEN 1 THEN 'dng_010'
      WHEN 2 THEN 'dng_020'
      WHEN 3 THEN 'dng_030'
      WHEN 4 THEN 'dng_040'
      WHEN 5 THEN 'dng_050'
      WHEN 6 THEN 'dng_060'
      WHEN 7 THEN 'dng_065'
      ELSE NULL
    END
  ) ORDER BY t.zone_number), '[]'::jsonb)
  INTO v_territories
  FROM public.guild_war_territories t
  LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
  WHERE t.zone_number IS NOT NULL;

  RETURN jsonb_build_object(
    'week_key', v_week,
    'status', v_status,
    'recent_challenges', COALESCE(v_recent, '[]'::jsonb),
    'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb),
    'territories', COALESCE(v_territories, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.guild_war_territory_effective_defense(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guild_war_reset_gem_defense_outside_prime() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_territory_detail(
  p_territory_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_territory json;
  v_recent_attacks json;
BEGIN
  PERFORM public.guild_war_reset_gem_defense_outside_prime();

  SELECT row_to_json(t)
  INTO v_territory
  FROM (
    SELECT
      t.id,
      t.name,
      t.owner_guild_id,
      COALESCE(g.name, 'Sahipsiz') AS owner_guild,
      t.defense_power,
      t.gem_defense_boost,
      public.guild_war_territory_effective_defense(t.defense_power, t.gem_defense_boost) AS effective_defense_power,
      t.base_defense_power,
      t.defense_line_level,
      t.reward,
      COALESCE(t.trade_income, 0) AS trade_income,
      t.defense_added_at,
      t.updated_at,
      t.zone_number
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    WHERE t.id = p_territory_id
  ) t;

  IF v_territory IS NULL THEN
    RETURN json_build_object('error', 'Bölge bulunamadı.');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json)
  INTO v_recent_attacks
  FROM (
    SELECT
      l.id,
      l.attacker_guild_id,
      l.defender_guild_id,
      l.attack_power,
      l.defense_power,
      l.success,
      l.points_gained,
      l.created_at,
      ag.name AS attacker_guild_name,
      dg.name AS defender_guild_name
    FROM public.guild_war_attack_logs l
    LEFT JOIN public.guilds ag ON ag.id = l.attacker_guild_id
    LEFT JOIN public.guilds dg ON dg.id = l.defender_guild_id
    WHERE l.territory_id = p_territory_id
    ORDER BY l.created_at DESC
    LIMIT 20
  ) a;

  RETURN json_build_object(
    'territory', v_territory,
    'recent_attacks', v_recent_attacks
  );
END;
$$;

-- QA unified: elmas katmanı gem_defense_boost üzerinden
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
  v_prev_gem integer;
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

  SELECT id, owner_guild_id, defense_power, gem_defense_boost
  INTO v_territory_id, v_prev_owner, v_prev_defense, v_prev_gem
  FROM public.guild_war_territories
  WHERE zone_number = 3
  LIMIT 1;

  UPDATE public.guild_war_territories
  SET gem_defense_boost = 0
  WHERE id = v_territory_id;

  v_ok := public.dungeon_siege_territory_defense_multiplier(3)
      = LEAST(COALESCE(v_prev_defense, 0)::numeric / 4000.0, 0.25);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'defense_multiplier_formula',
    'area', 'math',
    'pass', v_ok
  ));

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
      gem_defense_boost = 800,
      defense_power = 0
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

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  v_claim := public.claim_siege_slot(v_dungeon);
  v_slot_id := NULLIF(v_claim->>'slot_id', '')::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_intruder::text, true);
  v_hold := public.start_siege_guild_hold(v_dungeon);
  v_ok := COALESCE((v_hold->>'success')::boolean, true) = false;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'hold_blocked_for_non_owner', 'area', 'hold', 'pass', v_ok, 'detail', v_hold
  ));

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  v_hold := public.start_siege_guild_hold(v_dungeon);
  v_ok := COALESCE((v_hold->>'success')::boolean, false);
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'hold_allowed_for_territory_owner_one_slot', 'area', 'hold', 'pass', v_ok, 'detail', v_hold
  ));

  PERFORM set_config('request.jwt.claim.sub', v_intruder::text, true);
  v_challenge := public.challenge_siege_slot(v_slot_id);
  v_ok := COALESCE((v_challenge->>'success')::boolean, false)
      AND COALESCE((v_challenge->>'territory_defense_bonus_pct')::numeric, 0) = 0.2;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'challenge_applies_bonus_to_owner_guild_defender', 'area', 'unified_defense', 'pass', v_ok, 'detail', v_challenge
  ));

  PERFORM set_config('request.jwt.claim.sub', v_owner::text, true);
  v_status := public.get_dungeon_siege_status(v_dungeon);
  SELECT elem INTO v_session FROM jsonb_array_elements(v_status->'sessions') elem
  WHERE elem->>'dungeon_id' = v_dungeon LIMIT 1;
  v_ok := v_session ? 'territory_defense_power'
      AND COALESCE((v_session->>'territory_defense_siege_bonus_pct')::numeric, 0) = 0.2;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'status_includes_owner_applicable_bonus', 'area', 'rpc', 'pass', v_ok, 'detail', v_session
  ));

  UPDATE public.dungeon_siege_config
  SET prime_windows = '[{"start":"03:00","end":"04:00"}]'::jsonb
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
  PERFORM public.guild_war_reset_gem_defense_outside_prime();
  SELECT gem_defense_boost = 0 INTO v_ok FROM public.guild_war_territories WHERE id = v_territory_id;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'gem_defense_resets_outside_prime', 'area', 'cleanup', 'pass', v_ok
  ));

  UPDATE public.dungeon_siege_config
  SET prime_windows = '[{"start":"00:00","end":"23:59"}]'::jsonb
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  UPDATE public.guild_war_territories
  SET owner_guild_id = v_prev_owner,
      defense_power = v_prev_defense,
      gem_defense_boost = COALESCE(v_prev_gem, 0)
  WHERE id = v_territory_id;

  DELETE FROM public.dungeon_siege_holds WHERE guild_id IN (v_owner_guild, v_intruder_guild);
  DELETE FROM public.dungeon_siege_slots WHERE holder_id IN (v_owner, v_intruder);
  DELETE FROM public.dungeon_siege_sessions WHERE dungeon_id = v_dungeon AND created_at > now() - interval '1 hour';
  DELETE FROM public.guilds WHERE id IN (v_owner_guild, v_intruder_guild);
  DELETE FROM auth.users WHERE id IN (v_owner, v_intruder);
  DELETE FROM public.users WHERE auth_id IN (v_owner, v_intruder);

  RETURN jsonb_build_object(
    'verdict', CASE WHEN EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) t WHERE NOT COALESCE((t->>'pass')::boolean, false)
    ) THEN 'FAIL' ELSE 'PASS' END,
    'total', jsonb_array_length(v_results),
    'passed', (SELECT COUNT(*)::integer FROM jsonb_array_elements(v_results) t WHERE COALESCE((t->>'pass')::boolean, false)),
    'tests', v_results
  );
END;
$$;

COMMIT;
