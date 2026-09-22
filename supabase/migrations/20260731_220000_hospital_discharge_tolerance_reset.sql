-- Hospital discharge → tolerance = 0 on every clear path.
-- Also keeps overdose hospital_minutes in use_potion response (already present).

BEGIN;

CREATE OR REPLACE FUNCTION public._clear_hospital_admission(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.users
  SET hospital_until = NULL,
      hospital_reason = NULL,
      tolerance = 0,
      hospital_escape_attempted = false,
      updated_at = now()
  WHERE auth_id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public._clear_hospital_admission(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._clear_hospital_admission(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._clear_hospital_admission(uuid) TO service_role;

-- ── Timer expiry ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sync_expired_hospital(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
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
    PERFORM public._clear_hospital_admission(p_user_id);

    PERFORM public.apply_hospital_wounded_state(p_user_id);

    BEGIN
      INSERT INTO public.player_inbox_notifications (user_id, kind, title, body)
      VALUES (
        p_user_id,
        'hospital_discharge',
        'Hastaneden çıktın',
        'Taburcu oldun ama hâlâ yaralısın — canın dolana kadar savaşta %15 zayıfsın.'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- ── Gem / free discharge ─────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.heal_with_gems()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id uuid;
  v_hospital_until timestamptz;
  v_gems int;
  v_hospital_count int;
  v_level int;
  v_rate int;
  v_minutes_left int;
  v_admit int;
  v_billable int;
  v_gem_cost int;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  PERFORM public.sync_expired_hospital(v_user_id);

  SELECT hospital_until, gems, COALESCE(hospital_lifetime_count, 0), COALESCE(level, 1),
         hospital_admit_minutes
  INTO v_hospital_until, v_gems, v_hospital_count, v_level, v_admit
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF v_hospital_until IS NULL OR v_hospital_until <= now() THEN
    PERFORM public._clear_hospital_admission(v_user_id);
    RETURN json_build_object('success', true);
  END IF;

  IF v_hospital_count <= 2 THEN
    PERFORM public._clear_hospital_admission(v_user_id);
    PERFORM public.apply_hospital_wounded_state(v_user_id);
    RETURN json_build_object(
      'success', true,
      'was_free', true,
      'cost', 0,
      'wounded', true,
      'free_discharges_remaining', GREATEST(0, 2 - v_hospital_count)
    );
  END IF;

  v_minutes_left := CEIL(EXTRACT(EPOCH FROM (v_hospital_until - now())) / 60.0);
  IF v_minutes_left < 1 THEN
    v_minutes_left := 1;
  END IF;

  v_billable := v_minutes_left;
  IF v_admit IS NOT NULL AND v_admit > 0 THEN
    v_billable := GREATEST(v_minutes_left, CEIL(v_admit * 0.5)::integer);
  END IF;

  v_rate := CASE WHEN v_level < 10 THEN 1 WHEN v_level < 20 THEN 2 ELSE 3 END;
  v_gem_cost := v_billable * v_rate;

  IF v_gems < v_gem_cost THEN
    RETURN json_build_object('success', false, 'error', 'Yetersiz elmas. Gerekli: ' || v_gem_cost);
  END IF;

  UPDATE public.users
  SET gems = gems - v_gem_cost
  WHERE auth_id = v_user_id;

  PERFORM public._clear_hospital_admission(v_user_id);
  PERFORM public.apply_hospital_wounded_state(v_user_id);

  RETURN json_build_object(
    'success', true,
    'was_free', false,
    'cost', v_gem_cost,
    'wounded', true,
    'free_discharges_remaining', 0,
    'billable_minutes', v_billable
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.heal_with_gems() TO authenticated;

-- ── Escape success ───────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.attempt_hospital_escape()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user_id uuid;
  v_user record;
  v_base_chance numeric := 0.15;
  v_roll numeric;
  v_locked_until timestamptz;
  v_penalty_minutes int;
BEGIN
  v_user_id := auth.uid();
  RAISE LOG 'attempt_hospital_escape start uid=%', v_user_id;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE LOG 'attempt_hospital_escape user not found uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.hospital_until IS NULL OR v_user.hospital_until <= now() THEN
    RAISE LOG 'attempt_hospital_escape not in hospital uid=% hospital_until=%', v_user_id, v_user.hospital_until;
    RETURN jsonb_build_object('success', false, 'error', 'You are not in the hospital');
  END IF;

  IF COALESCE(v_user.hospital_escape_attempted, false) THEN
    RAISE LOG 'attempt_hospital_escape already attempted uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'Bu hastane sürecinde kaçmayı zaten denedin.');
  END IF;

  UPDATE public.users
  SET hospital_escape_attempted = true
  WHERE auth_id = v_user_id
    AND COALESCE(hospital_escape_attempted, false) = false
  RETURNING hospital_until INTO v_locked_until;

  IF NOT FOUND THEN
    RAISE LOG 'attempt_hospital_escape atomic guard blocked uid=%', v_user_id;
    RETURN jsonb_build_object('success', false, 'error', 'Bu hastane sürecinde kaçma hakkın tükendi.');
  END IF;

  v_roll := random();
  RAISE LOG 'attempt_hospital_escape roll uid=% roll=% chance=%', v_user_id, v_roll, v_base_chance;

  IF v_roll <= v_base_chance THEN
    PERFORM public._clear_hospital_admission(v_user_id);

    RETURN jsonb_build_object('success', true, 'escaped', true, 'message', 'Gizlice hastaneden kacmayi basardin! Artik ozgursun.');
  END IF;

  v_penalty_minutes := floor(random() * 46 + 15)::int;

  UPDATE public.users
  SET hospital_until = COALESCE(v_locked_until, v_user.hospital_until, now()) + (v_penalty_minutes || ' minutes')::interval
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object('success', true, 'escaped', false, 'message', 'Doktorlar seni koridorda yakaladi! Bu hastane surecinde tekrar kacamazsin. Tedavin +' || v_penalty_minutes || ' dakika uzatildi.');
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'attempt_hospital_escape exception uid=% err=%', v_user_id, SQLERRM;
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.attempt_hospital_escape() TO authenticated;

-- ── Legacy release RPC ───────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.release_from_hospital(p_auth_id uuid, p_method text, p_cost integer DEFAULT 0)
RETURNS TABLE(success boolean, new_gems integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_current_gems INT;
BEGIN
  SELECT gems INTO v_current_gems
  FROM public.users
  WHERE auth_id = p_auth_id;

  IF p_method = 'gems' AND v_current_gems < p_cost THEN
    RETURN QUERY SELECT FALSE, v_current_gems;
    RETURN;
  END IF;

  IF p_method = 'gems' THEN
    UPDATE public.users
    SET gems = gems - p_cost
    WHERE auth_id = p_auth_id;
  END IF;

  PERFORM public._clear_hospital_admission(p_auth_id);

  SELECT gems INTO v_current_gems
  FROM public.users
  WHERE auth_id = p_auth_id;

  RETURN QUERY SELECT TRUE, v_current_gems;
END;
$$;

-- ── Staff clear hospital ─────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.staff_clear_restriction(
  p_target_user_id uuid,
  p_restriction text,
  p_note text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_perm TEXT;
  v_guard JSONB;
  v_mutable JSONB;
  v_auth UUID;
  v_target_user UUID;
  v_actor_user UUID;
  v_label TEXT;
  v_count INT := 0;
BEGIN
  v_perm := CASE p_restriction
    WHEN 'hospital' THEN 'player.restrict_hospital'
    WHEN 'prison' THEN 'player.restrict_prison'
    WHEN 'trade' THEN 'player.restrict_trade'
    WHEN 'chat' THEN 'player.chat_mute'
    WHEN 'account_ban' THEN 'player.unban'
    ELSE NULL
  END;

  IF v_perm IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz kısıt.');
  END IF;

  v_guard := public.staff_require_permission(v_actor, v_perm);
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  v_mutable := public.staff_require_mutable_player(p_target_user_id);
  IF (v_mutable->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_mutable->>'error');
  END IF;
  v_auth := (v_mutable->>'auth_id')::uuid;

  v_label := CASE p_restriction
    WHEN 'chat' THEN 'Chat susturma'
    WHEN 'hospital' THEN 'Hastane'
    WHEN 'prison' THEN 'Hapishane'
    WHEN 'trade' THEN 'Ticaret yasağı'
    WHEN 'account_ban' THEN 'Hesap banı'
    ELSE p_restriction
  END;

  IF p_restriction = 'account_ban' THEN
    RETURN public.staff_unban_player(v_auth, COALESCE(p_note, 'Ban kaldırıldı'));
  ELSIF p_restriction = 'chat' THEN
    SELECT u.id INTO v_target_user FROM public.users u WHERE u.auth_id = v_auth;
    SELECT u.id INTO v_actor_user FROM public.users u WHERE u.auth_id = v_actor;
    UPDATE public.chat_bans
    SET revoked_at = now(), revoked_by_user_id = v_actor_user
    WHERE user_id = v_target_user
      AND revoked_at IS NULL
      AND expires_at > now();
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_restriction = 'hospital' THEN
    PERFORM public._clear_hospital_admission(v_auth);
    GET DIAGNOSTICS v_count = ROW_COUNT;
    -- PERFORM does not set ROW_COUNT from UPDATE; treat as 1 if user exists
    v_count := CASE WHEN v_auth IS NOT NULL THEN 1 ELSE 0 END;
  ELSIF p_restriction = 'prison' THEN
    UPDATE public.users SET prison_until = NULL, prison_reason = NULL WHERE auth_id = v_auth;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  ELSIF p_restriction = 'trade' THEN
    UPDATE public.users SET trade_banned_until = NULL WHERE auth_id = v_auth;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;

  PERFORM public._notify_player_staff_action(
    v_auth,
    'staff_restriction_lift',
    format('%s kaldırıldı', v_label),
    format('Not: %s', COALESCE(NULLIF(btrim(p_note), ''), 'Kısıtınız kaldırıldı.')),
    jsonb_build_object('restriction', p_restriction, 'note', p_note)
  );

  PERFORM public.staff_write_audit(
    v_actor, v_perm, 'clear_restriction', 'user', v_auth::text,
    jsonb_build_object('restriction', p_restriction, 'note', p_note, 'affected', v_count),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Kısıt kaldırıldı.');
END;
$$;

COMMIT;
