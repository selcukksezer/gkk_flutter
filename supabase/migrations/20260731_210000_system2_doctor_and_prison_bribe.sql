-- System 2 Hospital+Prison — B (doctor visit) + D (prison guard bribe) + P0-5 bribe_officials prison lock
-- + admit-minute snapshot floors for heal_with_gems / release_from_prison
-- Ad attestation: DEFERRED — keep existing reduce_timer_with_ad daily caps; no server attestation this ship.

BEGIN;

-- ── Columns ──────────────────────────────────────────────────────────────────

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_doctor_visit_on date,
  ADD COLUMN IF NOT EXISTS hospital_admit_minutes integer,
  ADD COLUMN IF NOT EXISTS prison_admit_minutes integer,
  ADD COLUMN IF NOT EXISTS prison_guard_bribe_attempted boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS prison_lawyer_used_this_stay boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS show_on_ward_board boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ward_board_friends_opt_in boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.users.last_doctor_visit_on IS
  'Europe/Istanbul calendar date of last attempt_doctor_visit';
COMMENT ON COLUMN public.users.hospital_admit_minutes IS
  'Snapshot minutes at hospital admit; gem floor = ceil(admit*0.5)';
COMMENT ON COLUMN public.users.prison_admit_minutes IS
  'Snapshot minutes at prison admit; gem floor = ceil(admit*0.5)';
COMMENT ON COLUMN public.users.prison_guard_bribe_attempted IS
  '1 guard bribe attempt per prison stay (System 2 D)';
COMMENT ON COLUMN public.users.prison_lawyer_used_this_stay IS
  'Guild clinic lawyer used this prison stay → +5% guard bribe';

-- Reset per-stay flags when restriction ends / new stay starts
CREATE OR REPLACE FUNCTION public._system2_restriction_admit_snapshot()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Hospital admit: null/expired → active
  IF NEW.hospital_until IS NOT NULL AND NEW.hospital_until > now()
     AND (OLD.hospital_until IS NULL OR OLD.hospital_until <= now()) THEN
    NEW.hospital_admit_minutes := GREATEST(
      1,
      CEIL(EXTRACT(EPOCH FROM (NEW.hospital_until - now())) / 60.0)::integer
    );
  END IF;

  IF NEW.hospital_until IS NULL OR NEW.hospital_until <= now() THEN
    IF OLD.hospital_until IS NOT NULL AND OLD.hospital_until > now() THEN
      NEW.hospital_admit_minutes := NULL;
    END IF;
  END IF;

  -- Prison admit
  IF NEW.prison_until IS NOT NULL AND NEW.prison_until > now()
     AND (OLD.prison_until IS NULL OR OLD.prison_until <= now()) THEN
    NEW.prison_admit_minutes := GREATEST(
      1,
      CEIL(EXTRACT(EPOCH FROM (NEW.prison_until - now())) / 60.0)::integer
    );
    NEW.prison_guard_bribe_attempted := false;
    NEW.prison_lawyer_used_this_stay := false;
  END IF;

  IF NEW.prison_until IS NULL OR NEW.prison_until <= now() THEN
    IF OLD.prison_until IS NOT NULL AND OLD.prison_until > now() THEN
      NEW.prison_admit_minutes := NULL;
      NEW.prison_guard_bribe_attempted := false;
      NEW.prison_lawyer_used_this_stay := false;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public._system2_restriction_admit_snapshot_ins()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.hospital_until IS NOT NULL AND NEW.hospital_until > now() THEN
    NEW.hospital_admit_minutes := GREATEST(
      1,
      CEIL(EXTRACT(EPOCH FROM (NEW.hospital_until - now())) / 60.0)::integer
    );
  END IF;
  IF NEW.prison_until IS NOT NULL AND NEW.prison_until > now() THEN
    NEW.prison_admit_minutes := GREATEST(
      1,
      CEIL(EXTRACT(EPOCH FROM (NEW.prison_until - now())) / 60.0)::integer
    );
    NEW.prison_guard_bribe_attempted := false;
    NEW.prison_lawyer_used_this_stay := false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_system2_restriction_admit_snapshot ON public.users;
CREATE TRIGGER trg_system2_restriction_admit_snapshot
  BEFORE UPDATE OF hospital_until, prison_until ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public._system2_restriction_admit_snapshot();

DROP TRIGGER IF EXISTS trg_system2_restriction_admit_snapshot_ins ON public.users;
CREATE TRIGGER trg_system2_restriction_admit_snapshot_ins
  BEFORE INSERT ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public._system2_restriction_admit_snapshot_ins();

-- Helper: Istanbul today
CREATE OR REPLACE FUNCTION public._istanbul_today()
RETURNS date
LANGUAGE sql
STABLE
AS $$
  SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date;
$$;

-- ── B) attempt_doctor_visit ──────────────────────────────────────────────────
-- Outcomes: 45% −20m / 30% −10m / 25% noop. No +10m. Skip HP heal (v1).
-- 1/day calendar Europe/Istanbul. FOR UPDATE. Stacks with ads/gems.

CREATE OR REPLACE FUNCTION public.attempt_doctor_visit()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user record;
  v_today date := public._istanbul_today();
  v_roll numeric;
  v_cut_minutes integer := 0;
  v_outcome text;
  v_remaining_mins integer;
  v_new_until timestamptz;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.hospital_until IS NULL OR v_user.hospital_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastanede degilsin');
  END IF;

  IF v_user.last_doctor_visit_on IS NOT NULL AND v_user.last_doctor_visit_on = v_today THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'daily_limit',
      'message', 'Bugun zaten doktor ziyareti yaptin'
    );
  END IF;

  v_roll := random();
  IF v_roll < 0.45 THEN
    v_cut_minutes := 20;
    v_outcome := 'cut_20';
  ELSIF v_roll < 0.75 THEN
    v_cut_minutes := 10;
    v_outcome := 'cut_10';
  ELSE
    v_cut_minutes := 0;
    v_outcome := 'noop';
  END IF;

  IF v_cut_minutes > 0 THEN
    v_new_until := v_user.hospital_until - make_interval(mins => v_cut_minutes);
    IF v_new_until <= now() THEN
      v_new_until := NULL;
    END IF;
  ELSE
    v_new_until := v_user.hospital_until;
  END IF;

  UPDATE public.users
  SET hospital_until = v_new_until,
      last_doctor_visit_on = v_today,
      hospital_reason = CASE WHEN v_new_until IS NULL THEN NULL ELSE hospital_reason END,
      updated_at = now()
  WHERE auth_id = v_user_id;

  IF v_new_until IS NULL THEN
    PERFORM public.apply_hospital_wounded_state(v_user_id);
  END IF;

  v_remaining_mins := CASE
    WHEN v_new_until IS NULL THEN 0
    ELSE GREATEST(0, CEIL(EXTRACT(EPOCH FROM (v_new_until - now())) / 60.0)::integer)
  END;

  RETURN jsonb_build_object(
    'success', true,
    'outcome', v_outcome,
    'cut_minutes', v_cut_minutes,
    'released', v_new_until IS NULL,
    'new_until', v_new_until,
    'remaining_minutes', v_remaining_mins,
    'heal_skipped', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.attempt_doctor_visit() TO authenticated;

-- ── D) bribe_prison_guard ────────────────────────────────────────────────────
-- Cost max(25000, remaining*1500) gold
-- Base 45% + Shadow 10% + lawyer 5% if flag; suspicion penalty; softcap 60%
-- 1 attempt / stay. Success: −20% remaining clamp 10..60 min. Fail: +8 suspicion; 30% +15m

CREATE OR REPLACE FUNCTION public.bribe_prison_guard()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user record;
  v_remaining_mins integer;
  v_cost bigint;
  v_success_chance numeric;
  v_suspicion_pen numeric;
  v_roll numeric;
  v_cut_minutes integer;
  v_new_until timestamptz;
  v_extra_penalty boolean := false;
  v_won boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.prison_until IS NULL OR v_user.prison_until <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cezaevinde degilsin');
  END IF;

  IF COALESCE(v_user.prison_guard_bribe_attempted, false) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_attempted',
      'message', 'Bu hapiste gardiyan ikna hakkin bitti'
    );
  END IF;

  v_remaining_mins := GREATEST(
    1,
    CEIL(EXTRACT(EPOCH FROM (v_user.prison_until - now())) / 60.0)::integer
  );
  v_cost := GREATEST(25000, v_remaining_mins * 1500);

  IF COALESCE(v_user.gold, 0) < v_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yetersiz altin',
      'cost', v_cost,
      'gold', COALESCE(v_user.gold, 0)
    );
  END IF;

  -- Base 45%; Shadow +10pp; lawyer +5pp if clinic lawyer this stay
  v_success_chance := 0.45;
  IF COALESCE(v_user.character_class, '') = 'shadow' THEN
    v_success_chance := v_success_chance + 0.10;
  END IF;
  IF COALESCE(v_user.prison_lawyer_used_this_stay, false) THEN
    v_success_chance := v_success_chance + 0.05;
  END IF;

  -- Suspicion penalty: −1pp per 10 global suspicion
  v_suspicion_pen := (GREATEST(0, COALESCE(v_user.global_suspicion_level, 0)) / 10.0) * 0.01;
  v_success_chance := v_success_chance - v_suspicion_pen;

  -- Softcap 60%
  v_success_chance := LEAST(0.60, GREATEST(0.05, v_success_chance));

  -- Mark attempt + debit gold atomically
  UPDATE public.users
  SET gold = gold - v_cost,
      prison_guard_bribe_attempted = true,
      updated_at = now()
  WHERE auth_id = v_user_id
    AND gold >= v_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altin', 'cost', v_cost);
  END IF;

  v_roll := random();
  v_won := v_roll < v_success_chance;

  IF v_won THEN
    -- −20% remaining, clamp cut to 10..60 minutes
    v_cut_minutes := GREATEST(10, LEAST(60, CEIL(v_remaining_mins * 0.20)::integer));
    v_new_until := v_user.prison_until - make_interval(mins => v_cut_minutes);
    IF v_new_until <= now() THEN
      v_new_until := NULL;
    END IF;

    UPDATE public.users
    SET prison_until = v_new_until,
        in_prison = (v_new_until IS NOT NULL),
        prison_reason = CASE WHEN v_new_until IS NULL THEN NULL ELSE prison_reason END,
        updated_at = now()
    WHERE auth_id = v_user_id;

    RETURN jsonb_build_object(
      'success', true,
      'bribed', true,
      'cost', v_cost,
      'cut_minutes', v_cut_minutes,
      'success_chance', round(v_success_chance::numeric, 4),
      'released', v_new_until IS NULL,
      'new_until', v_new_until
    );
  END IF;

  -- Fail: +8 suspicion; 30% +15 min
  IF random() < 0.30 THEN
    v_extra_penalty := true;
    v_new_until := v_user.prison_until + interval '15 minutes';
  ELSE
    v_new_until := v_user.prison_until;
  END IF;

  UPDATE public.users
  SET global_suspicion_level = LEAST(100, COALESCE(global_suspicion_level, 0) + 8),
      prison_until = v_new_until,
      updated_at = now()
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'bribed', false,
    'cost', v_cost,
    'success_chance', round(v_success_chance::numeric, 4),
    'suspicion_added', 8,
    'extra_penalty_minutes', CASE WHEN v_extra_penalty THEN 15 ELSE 0 END,
    'new_until', v_new_until
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.bribe_prison_guard() TO authenticated;

-- ── P0-5: bribe_officials hard-fail in prison ────────────────────────────────

CREATE OR REPLACE FUNCTION public.bribe_officials(p_facility_type text, p_amount_gems integer DEFAULT 5)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_player record;
  v_facility record;
  v_gem_cost integer := GREATEST(COALESCE(p_amount_gems, 5), 5);
  v_reduction numeric;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_player
  FROM public.users u
  WHERE u.auth_id = v_user_id OR u.id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player not found');
  END IF;

  -- P0-5: cannot facility-bribe while imprisoned
  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'in_prison',
      'message', 'Cezaevindeyken tesis rusveti verilemez'
    );
  END IF;

  IF COALESCE(v_player.global_suspicion_level, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Suphe 0 iken rusvet verilemez');
  END IF;

  IF COALESCE(v_player.character_class, '') = 'shadow' THEN
    v_reduction := public._passive_bonus('shadow', 'bribe_cost_reduction', 0.25);
    v_gem_cost := GREATEST(1, CEIL(v_gem_cost * (1 - v_reduction))::integer);
  END IF;

  IF COALESCE(v_player.gems, 0) < v_gem_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gem yetersiz');
  END IF;

  SELECT * INTO v_facility
  FROM public.facilities
  WHERE user_id = v_user_id
    AND type = p_facility_type
    AND COALESCE(is_active, true) = true
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tesis bulunamadi');
  END IF;

  UPDATE public.users
  SET gems = gems - v_gem_cost,
      global_suspicion_level = GREATEST(0, COALESCE(global_suspicion_level, 0) - 15),
      last_bribe_at = now(),
      updated_at = now()
  WHERE (auth_id = v_user_id OR id = v_user_id)
    AND gems >= v_gem_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gem yetersiz');
  END IF;

  UPDATE public.facilities
  SET suspicion_level = GREATEST(0, COALESCE(suspicion_level, 0) - 20),
      updated_at = now()
  WHERE id = v_facility.id;

  PERFORM public._recompute_global_suspicion(v_user_id);

  RETURN jsonb_build_object('success', true, 'gems_spent', v_gem_cost);
END;
$$;

-- ── Gem/bail floor from admit snapshot ───────────────────────────────────────

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
    UPDATE public.users SET hospital_until = NULL, hospital_reason = NULL WHERE auth_id = v_user_id;
    RETURN json_build_object('success', true);
  END IF;

  IF v_hospital_count <= 2 THEN
    UPDATE public.users
    SET hospital_until = NULL, hospital_reason = NULL
    WHERE auth_id = v_user_id;
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

  -- Floor: max(remaining, ceil(admit*0.5))
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
  SET gems = gems - v_gem_cost,
      hospital_until = NULL,
      hospital_reason = NULL
  WHERE auth_id = v_user_id;

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

CREATE OR REPLACE FUNCTION public.release_from_prison(p_use_bail BOOLEAN DEFAULT false)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id UUID;
    v_user RECORD;
    v_now TIMESTAMPTZ;
    v_bail_gems INT;
    v_remaining_mins INT;
    v_billable INT;
BEGIN
    v_user_id := auth.uid();
    v_now := NOW();

    SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;

    IF v_user IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'User not found in public.users');
    END IF;

    IF v_user.prison_until IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not in prison');
    END IF;

    IF p_use_bail THEN
        IF v_user.prison_until <= v_now THEN
            UPDATE public.users SET
                in_prison = false, prison_until = NULL, prison_reason = NULL,
                prison_guard_bribe_attempted = false,
                prison_lawyer_used_this_stay = false,
                updated_at = v_now
            WHERE auth_id = v_user_id;
            RETURN jsonb_build_object('success', true, 'message', 'Prison time served');
        END IF;

        v_remaining_mins := CEIL(EXTRACT(EPOCH FROM (v_user.prison_until - v_now)) / 60);
        IF v_remaining_mins < 1 THEN v_remaining_mins := 1; END IF;

        v_billable := v_remaining_mins;
        IF v_user.prison_admit_minutes IS NOT NULL AND v_user.prison_admit_minutes > 0 THEN
          v_billable := GREATEST(v_remaining_mins, CEIL(v_user.prison_admit_minutes * 0.5)::integer);
        END IF;

        v_bail_gems := GREATEST(1, v_billable);

        IF v_user.gems < v_bail_gems THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems', 'cost', v_bail_gems);
        END IF;

        UPDATE public.users SET
            gems = gems - v_bail_gems,
            in_prison = false,
            prison_until = NULL,
            prison_reason = NULL,
            prison_guard_bribe_attempted = false,
            prison_lawyer_used_this_stay = false,
            updated_at = v_now
        WHERE auth_id = v_user_id;

        RETURN jsonb_build_object(
          'success', true,
          'message', 'Released from prison via bail',
          'gems_spent', v_bail_gems,
          'billable_minutes', v_billable
        );
    ELSE
        IF v_user.prison_until > v_now THEN
            RETURN jsonb_build_object('success', false, 'error', 'Süre henüz dolmadı');
        END IF;

        UPDATE public.users SET
            in_prison = false,
            prison_until = NULL,
            prison_reason = NULL,
            prison_guard_bribe_attempted = false,
            prison_lawyer_used_this_stay = false,
            updated_at = v_now
        WHERE auth_id = v_user_id;

        RETURN jsonb_build_object('success', true, 'message', 'Prison time served');
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.release_from_prison(BOOLEAN) TO authenticated;

COMMIT;
