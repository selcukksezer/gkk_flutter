-- Player health system: passive regen, PvP persist, hospital wounded, combat gate.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS health_last_updated TIMESTAMPTZ DEFAULT now();

UPDATE public.users
SET health_last_updated = COALESCE(updated_at, now())
WHERE health_last_updated IS NULL;

-- ── Helpers ───────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.player_combat_min_health(p_max INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT GREATEST(1, FLOOR(GREATEST(COALESCE(p_max, 100), 1) * 0.20)::INT);
$$;

CREATE OR REPLACE FUNCTION public.player_wounded_health(p_max INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT GREATEST(1, FLOOR(GREATEST(COALESCE(p_max, 100), 1) * 0.50)::INT);
$$;

CREATE OR REPLACE FUNCTION public.player_health_floor(p_max INT)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT GREATEST(1, FLOOR(GREATEST(COALESCE(p_max, 100), 1) * 0.15)::INT);
$$;

CREATE OR REPLACE FUNCTION public.apply_hospital_wounded_state(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_max INT;
  v_wounded INT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  SELECT GREATEST(COALESCE(max_health, 100), 1)
  INTO v_max
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_wounded := public.player_wounded_health(v_max);

  UPDATE public.users
  SET
    health = v_wounded,
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = p_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_expired_hospital(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_until TIMESTAMPTZ;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT hospital_until
  INTO v_until
  FROM public.users
  WHERE auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_until IS NOT NULL AND v_until <= now() THEN
    UPDATE public.users
    SET hospital_until = NULL,
        hospital_reason = NULL,
        updated_at = now()
    WHERE auth_id = p_user_id;

    PERFORM public.apply_hospital_wounded_state(p_user_id);
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_arena_pvp_health_damage(
  p_winner_id UUID,
  p_loser_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_w_health INT;
  v_w_max INT;
  v_l_health INT;
  v_l_max INT;
  v_w_dmg INT;
  v_l_dmg INT;
BEGIN
  SELECT COALESCE(health, max_health, 100), GREATEST(COALESCE(max_health, 100), 1)
  INTO v_w_health, v_w_max
  FROM public.users
  WHERE auth_id = p_winner_id;

  SELECT COALESCE(health, max_health, 100), GREATEST(COALESCE(max_health, 100), 1)
  INTO v_l_health, v_l_max
  FROM public.users
  WHERE auth_id = p_loser_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_w_dmg := FLOOR(v_w_max * (0.10 + random() * 0.15))::INT;
  v_l_dmg := FLOOR(v_l_max * (0.35 + random() * 0.20))::INT;

  UPDATE public.users
  SET
    health = GREATEST(public.player_health_floor(v_w_max), v_w_health - v_w_dmg),
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = p_winner_id;

  UPDATE public.users
  SET
    health = GREATEST(public.player_health_floor(v_l_max), v_l_health - v_l_dmg),
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = p_loser_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.persist_pvp_sim_health(
  p_attacker_id UUID,
  p_defender_id UUID,
  p_attacker_hp INT,
  p_defender_hp INT,
  p_attacker_max INT,
  p_defender_max INT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.users
  SET
    health = GREATEST(public.player_health_floor(GREATEST(COALESCE(p_attacker_max, 100), 1)), GREATEST(p_attacker_hp, 0)),
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = p_attacker_id;

  UPDATE public.users
  SET
    health = GREATEST(public.player_health_floor(GREATEST(COALESCE(p_defender_max, 100), 1)), GREATEST(p_defender_hp, 0)),
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = p_defender_id;
END;
$$;

-- ── Passive health regen (5%/hour base; alchemist +50%) ───────────────────────

CREATE OR REPLACE FUNCTION public.apply_health_regen(p_user_id uuid DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_health INT;
  v_max INT;
  v_last TIMESTAMPTZ;
  v_elapsed NUMERIC;
  v_gained INT;
  v_new INT;
  v_actual INT;
  v_seconds_per_point NUMERIC;
  v_hospital TIMESTAMPTZ;
  v_prison TIMESTAMPTZ;
  v_class TEXT;
  v_rate_mult NUMERIC := 1.0;
  v_full_seconds NUMERIC;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadi.');
  END IF;

  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  PERFORM public.sync_expired_hospital(p_user_id);

  SELECT
    COALESCE(u.health, 0),
    GREATEST(COALESCE(u.max_health, 100), 1),
    COALESCE(u.health_last_updated, now()),
    u.hospital_until,
    u.prison_until,
    COALESCE(u.character_class, '')
  INTO v_health, v_max, v_last, v_hospital, v_prison, v_class
  FROM public.users u
  WHERE u.auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profil bulunamadi.');
  END IF;

  IF (v_hospital IS NOT NULL AND v_hospital > now())
     OR (v_prison IS NOT NULL AND v_prison > now()) THEN
    RETURN jsonb_build_object(
      'success', true,
      'health', v_health,
      'max_health', v_max,
      'gained', 0,
      'restricted', true
    );
  END IF;

  IF v_health >= v_max THEN
    UPDATE public.users
    SET health_last_updated = now()
    WHERE auth_id = p_user_id
      AND (health_last_updated IS NULL OR health_last_updated < now() - interval '30 seconds');
    RETURN jsonb_build_object(
      'success', true,
      'health', v_health,
      'max_health', v_max,
      'gained', 0
    );
  END IF;

  IF v_class = 'alchemist' THEN
    v_rate_mult := 1.5;
  END IF;

  v_elapsed := EXTRACT(EPOCH FROM (now() - v_last));
  IF v_elapsed IS NULL OR v_elapsed < 0 THEN
    v_elapsed := 0;
  END IF;

  -- Full pool in 20h base (5%/hour); alchemist 13.33h.
  v_full_seconds := 72000.0 / v_rate_mult;
  v_gained := FLOOR(v_elapsed * v_max / v_full_seconds)::INT;

  IF v_gained <= 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'health', v_health,
      'max_health', v_max,
      'gained', 0
    );
  END IF;

  v_new := LEAST(v_max, v_health + v_gained);
  v_actual := v_new - v_health;
  v_seconds_per_point := v_full_seconds / v_max;

  UPDATE public.users
  SET
    health = v_new,
    health_last_updated = CASE
      WHEN v_new >= v_max THEN now()
      ELSE v_last + make_interval(secs => (v_actual * v_seconds_per_point))
    END,
    updated_at = now()
  WHERE auth_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'health', v_new,
    'max_health', v_max,
    'gained', v_actual
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_health_regen(uuid) TO authenticated;

-- ── Heartbeat: energy + health regen ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_online_status(
  p_is_online boolean,
  p_mekan_id uuid DEFAULT NULL::uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    PERFORM public.apply_energy_regen(auth.uid());
    PERFORM public.apply_health_regen(auth.uid());
  END IF;

  UPDATE public.users
  SET
    comeback_resume_from = CASE
      WHEN p_is_online
        AND comeback_resume_from IS NULL
        AND last_active_at IS NOT NULL
        AND last_active_at < now() - interval '5 minutes'
      THEN last_active_at
      WHEN NOT p_is_online THEN comeback_resume_from
      ELSE comeback_resume_from
    END,
    is_online = p_is_online,
    current_mekan_id = CASE WHEN p_is_online THEN p_mekan_id ELSE NULL END,
    last_active_at = CASE WHEN p_is_online THEN now() ELSE last_active_at END,
    updated_at = now()
  WHERE auth_id = auth.uid();
END;
$$;

-- ── Hospital gem heal → wounded on discharge ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.heal_with_gems()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_hospital_until timestamptz;
  v_gems int;
  v_minutes_left int;
  v_gem_cost int;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  PERFORM public.sync_expired_hospital(v_user_id);

  SELECT hospital_until, gems
  INTO v_hospital_until, v_gems
  FROM public.users
  WHERE auth_id = v_user_id;

  IF v_hospital_until IS NULL OR v_hospital_until <= now() THEN
    UPDATE public.users
    SET hospital_until = NULL, hospital_reason = NULL
    WHERE auth_id = v_user_id;
    RETURN json_build_object('success', true);
  END IF;

  v_minutes_left := CEIL(EXTRACT(EPOCH FROM (v_hospital_until - now())) / 60.0);
  IF v_minutes_left < 1 THEN
    v_minutes_left := 1;
  END IF;

  v_gem_cost := v_minutes_left * 3;

  IF v_gems < v_gem_cost THEN
    RETURN json_build_object('success', false, 'error', 'Yetersiz elmas. Gerekli: ' || v_gem_cost);
  END IF;

  UPDATE public.users
  SET gems = gems - v_gem_cost,
      hospital_until = NULL,
      hospital_reason = NULL
  WHERE auth_id = v_user_id;

  PERFORM public.apply_hospital_wounded_state(v_user_id);

  RETURN json_build_object('success', true, 'cost', v_gem_cost, 'wounded', true);
END;
$$;

-- ── Combat ready gate (+ low health for attacker) ─────────────────────────────

CREATE OR REPLACE FUNCTION public.assert_player_combat_ready(
  p_user_id UUID,
  p_as_target BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', pg_temp
AS $$
DECLARE
  v_hospital TIMESTAMPTZ;
  v_prison TIMESTAMPTZ;
  v_ban JSONB;
  v_sess JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Oturum bulunamadi.',
      'error_code', 'not_authenticated'
    );
  END IF;

  v_ban := public.assert_player_not_banned(p_user_id);
  IF COALESCE((v_ban->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_ban->>'error',
      'error_code', COALESCE(v_ban->>'error_code', 'account_banned')
    );
  END IF;

  IF NOT p_as_target AND p_user_id = auth.uid() THEN
    v_sess := public.assert_active_device_session();
    IF COALESCE((v_sess->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', v_sess->>'error',
        'error_code', COALESCE(v_sess->>'error_code', 'device_session_superseded')
      );
    END IF;
  END IF;

  SELECT u.hospital_until, u.prison_until
  INTO v_hospital, v_prison
  FROM public.users u
  WHERE u.auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE WHEN p_as_target THEN 'Rakip bulunamadi.' ELSE 'Oyuncu bulunamadi.' END,
      'error_code', 'player_not_found'
    );
  END IF;

  IF v_hospital IS NOT NULL AND v_hospital > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN p_as_target THEN 'Rakip hastanede.'
        ELSE 'Hastanedesiniz.'
      END,
      'error_code', 'hospital'
    );
  END IF;

  IF v_prison IS NOT NULL AND v_prison > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN p_as_target THEN 'Rakip hapishanede.'
        ELSE 'Hapishanedesiniz.'
      END,
      'error_code', 'prison'
    );
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_player_pvp_health(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', pg_temp
AS $$
DECLARE
  v_health INT;
  v_max INT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Oturum bulunamadi.',
      'error_code', 'not_authenticated'
    );
  END IF;

  SELECT COALESCE(u.health, 0), GREATEST(COALESCE(u.max_health, 100), 1)
  INTO v_health, v_max
  FROM public.users u
  WHERE u.auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Oyuncu bulunamadi.',
      'error_code', 'player_not_found'
    );
  END IF;

  IF v_health < public.player_combat_min_health(v_max) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Canin cok dusuk — iksir kullan veya dinlen.',
      'error_code', 'low_health'
    );
  END IF;

  RETURN NULL;
END;
$$;

-- ── Patch PvP RPC bodies: persist / damage health ────────────────────────────

DO $$
DECLARE
  v_def TEXT;
BEGIN
  -- pvp_attack: gate + persist sim HP
  SELECT pg_get_functiondef('public.pvp_attack(uuid, uuid, uuid)'::regprocedure) INTO v_def;
  IF v_def IS NOT NULL THEN
    IF position('Canin cok dusuk' IN v_def) = 0 AND position('PvP icin minimum level 10' IN v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'IF COALESCE(v_attacker.level, 1) < 10 OR COALESCE(v_defender.level, 1) < 10 THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''PvP icin minimum level 10'');\n  END IF;',
        E'IF COALESCE(v_attacker.level, 1) < 10 OR COALESCE(v_defender.level, 1) < 10 THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''PvP icin minimum level 10'');\n  END IF;\n\n  IF COALESCE(v_attacker.health, v_attacker.max_health, 100) < public.player_combat_min_health(COALESCE(v_attacker.max_health, 100)) THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Canin cok dusuk — iksir kullan veya dinlen.'');\n  END IF;'
      );
    END IF;

    IF position('persist_pvp_sim_health' IN v_def) = 0 AND position('INSERT INTO public.pvp_matches' IN v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'  INSERT INTO public.pvp_matches (',
        E'  v_attacker_hp := GREATEST(public.player_health_floor(COALESCE(v_attacker.max_health, 100)), v_attacker_hp);\n  v_defender_hp := GREATEST(public.player_health_floor(COALESCE(v_defender.max_health, 100)), v_defender_hp);\n  PERFORM public.persist_pvp_sim_health(\n    p_attacker_id,\n    p_defender_id,\n    v_attacker_hp,\n    v_defender_hp,\n    COALESCE(v_attacker.max_health, 100),\n    COALESCE(v_defender.max_health, 100)\n  );\n\n  INSERT INTO public.pvp_matches ('
      );
    END IF;

    IF position('persist_pvp_sim_health' IN v_def) > 0 OR position('Canin cok dusuk' IN v_def) > 0 THEN
      EXECUTE v_def;
    END IF;
  END IF;

  -- mekan_pvp_bet_rl_inner: PvP health gate + arena damage
  SELECT pg_get_functiondef('public.mekan_pvp_bet_rl_inner(uuid, uuid, bigint)'::regprocedure) INTO v_def;
  IF v_def IS NOT NULL THEN
    IF position('assert_player_pvp_health' IN v_def) = 0 AND position('assert_player_combat_ready(v_attacker_id, false)' IN v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'v_combat := public.assert_player_combat_ready(p_defender_id, true);\n  IF v_combat IS NOT NULL THEN RETURN v_combat; END IF;',
        E'v_combat := public.assert_player_combat_ready(p_defender_id, true);\n  IF v_combat IS NOT NULL THEN RETURN v_combat; END IF;\n\n  v_combat := public.assert_player_pvp_health(v_attacker_id);\n  IF v_combat IS NOT NULL THEN RETURN v_combat; END IF;'
      );
    END IF;

    IF position('apply_arena_pvp_health_damage' IN v_def) = 0 THEN
      IF position('INSERT INTO public.mekan_pvp_matches' IN v_def) > 0 THEN
        v_def := replace(
          v_def,
          E'  INSERT INTO public.mekan_pvp_matches (',
          E'  PERFORM public.apply_arena_pvp_health_damage(v_winner_id, v_loser_id);\n\n  INSERT INTO public.mekan_pvp_matches ('
        );
      ELSIF position('INSERT INTO public.pvp_arena_notifications' IN v_def) > 0 THEN
        v_def := replace(
          v_def,
          E'  INSERT INTO public.pvp_arena_notifications (',
          E'  PERFORM public.apply_arena_pvp_health_damage(v_winner_id, v_loser_id);\n\n  INSERT INTO public.pvp_arena_notifications ('
        );
      END IF;
    END IF;

    IF position('assert_player_pvp_health' IN v_def) > 0 OR position('apply_arena_pvp_health_damage' IN v_def) > 0 THEN
      EXECUTE v_def;
    END IF;
  END IF;

  -- respond_pvp_invite: PvP health gate + damage
  SELECT pg_get_functiondef('public.respond_pvp_invite(uuid, boolean)'::regprocedure) INTO v_def;
  IF v_def IS NOT NULL THEN
    IF position('assert_player_pvp_health' IN v_def) = 0 AND position('assert_player_combat_ready(v_invite.challenger_id, true)' IN v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'v_combat := public.assert_player_combat_ready(v_invite.challenger_id, true);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;',
        E'v_combat := public.assert_player_combat_ready(v_invite.challenger_id, true);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;\n\n  v_combat := public.assert_player_pvp_health(v_me);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;'
      );
    END IF;

    IF position('apply_arena_pvp_health_damage' IN v_def) = 0 THEN
      IF position('-- [GKK_NEMESIS_REVENGE_GOLD_BEGIN]' IN v_def) > 0 THEN
        v_def := replace(
          v_def,
          E'  -- [GKK_NEMESIS_REVENGE_GOLD_BEGIN]',
          E'  PERFORM public.apply_arena_pvp_health_damage(v_winner_id, v_loser_id);\n\n  -- [GKK_NEMESIS_REVENGE_GOLD_BEGIN]'
        );
      ELSIF position('UPDATE public.pvp_invites' IN v_def) > 0 AND position('SET status = ''accepted''' IN v_def) > 0 THEN
        v_def := replace(
          v_def,
          E'  UPDATE public.pvp_invites\n  SET status = ''accepted'', result = v_result',
          E'  PERFORM public.apply_arena_pvp_health_damage(v_winner_id, v_loser_id);\n\n  UPDATE public.pvp_invites\n  SET status = ''accepted'', result = v_result'
        );
      END IF;
    END IF;

    IF position('assert_player_pvp_health' IN v_def) > 0 OR position('apply_arena_pvp_health_damage' IN v_def) > 0 THEN
      EXECUTE v_def;
    END IF;
  END IF;

  SELECT pg_get_functiondef('public.get_matchmaking_offers(text)'::regprocedure) INTO v_def;
  IF v_def IS NOT NULL AND position('assert_player_pvp_health' IN v_def) = 0 AND position('assert_player_combat_ready(v_me, false)' IN v_def) > 0 THEN
    v_def := replace(
      v_def,
      E'v_combat := public.assert_player_combat_ready(v_me, false);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;',
      E'v_combat := public.assert_player_combat_ready(v_me, false);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;\n\n  v_combat := public.assert_player_pvp_health(v_me);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;'
    );
    EXECUTE v_def;
  END IF;

  SELECT pg_get_functiondef('public.consume_matchmaking_offer(uuid, text, uuid)'::regprocedure) INTO v_def;
  IF v_def IS NOT NULL AND position('assert_player_pvp_health' IN v_def) = 0 AND position('assert_player_combat_ready(v_me, false)' IN v_def) > 0 THEN
    v_def := replace(
      v_def,
      E'v_combat := public.assert_player_combat_ready(v_me, false);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;',
      E'v_combat := public.assert_player_combat_ready(v_me, false);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;\n\n  v_combat := public.assert_player_pvp_health(v_me);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;'
    );
    EXECUTE v_def;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.apply_health_regen(uuid) IS
  'Passive health regen: 5%/hour base (20h full pool). Alchemist +50% rate. Skips hospital/prison.';
