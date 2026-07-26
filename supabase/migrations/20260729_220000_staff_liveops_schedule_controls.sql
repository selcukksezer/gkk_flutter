-- Staff LiveOps: sezon tarihleri, gece pazarı aç/kapa, takvim özeti.

BEGIN;

ALTER TABLE public.night_market_schedule
  ADD COLUMN IF NOT EXISTS staff_force_closed BOOLEAN NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public._night_market_window(p_now TIMESTAMPTZ DEFAULT now())
RETURNS TABLE (
  active BOOLEAN,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  seconds_left INTEGER,
  rotation_week DATE
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_sched RECORD;
  v_local TIMESTAMP;
  v_hour INT;
  v_start_local TIMESTAMP;
  v_end_local TIMESTAMP;
BEGIN
  SELECT * INTO v_sched FROM public.night_market_schedule WHERE id = 1;

  IF COALESCE(v_sched.staff_force_closed, false) THEN
    active := false;
    starts_at := p_now;
    ends_at := p_now;
    seconds_left := 0;
    rotation_week := date_trunc('week', p_now)::DATE;
    RETURN NEXT;
    RETURN;
  END IF;

  v_local := (p_now AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul'));
  v_hour := EXTRACT(HOUR FROM v_local)::INT;

  v_start_local := date_trunc('day', v_local)
    + make_interval(hours => COALESCE(v_sched.start_hour, 20));
  v_end_local := date_trunc('day', v_local)
    + make_interval(hours => COALESCE(v_sched.end_hour, 22));

  IF v_hour >= COALESCE(v_sched.end_hour, 22) THEN
    v_start_local := v_start_local + interval '1 day';
    v_end_local := v_end_local + interval '1 day';
  END IF;

  starts_at := v_start_local AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul');
  ends_at := v_end_local AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul');
  rotation_week := date_trunc('week', starts_at)::DATE;

  IF COALESCE(v_sched.qa_force_open, false) THEN
    active := true;
    seconds_left := GREATEST(0, EXTRACT(EPOCH FROM (ends_at - p_now))::INT);
  ELSE
    active := p_now >= starts_at AND p_now < ends_at;
    seconds_left := CASE
      WHEN active THEN GREATEST(0, EXTRACT(EPOCH FROM (ends_at - p_now))::INT)
      WHEN p_now < starts_at THEN GREATEST(0, EXTRACT(EPOCH FROM (starts_at - p_now))::INT)
      ELSE 0
    END;
  END IF;

  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_get_schedules()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_bp RECORD;
  v_gw RECORD;
  v_nm RECORD;
  v_win RECORD;
BEGIN
  IF NOT (
    public.staff_is_admin(v_actor)
    OR public.staff_has_permission(v_actor, 'liveops.bp_season')
    OR public.staff_has_permission(v_actor, 'liveops.guild_war_season')
    OR public.staff_has_permission(v_actor, 'liveops.night_market')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'LiveOps takvim yetkisi yok.');
  END IF;

  SELECT s.id, s.season_number, s.start_at, s.end_at, s.is_active
  INTO v_bp
  FROM public.bp_seasons s
  WHERE s.is_active = true
  ORDER BY s.season_number DESC
  LIMIT 1;

  SELECT s.id, s.season_number, s.week_number, s.start_at, s.end_at, s.is_active
  INTO v_gw
  FROM public.guild_war_seasons s
  WHERE s.is_active = true
  ORDER BY s.season_number DESC, s.week_number DESC
  LIMIT 1;

  SELECT *
  INTO v_nm
  FROM public.night_market_schedule
  WHERE id = 1;

  SELECT * INTO v_win FROM public._night_market_window();

  RETURN jsonb_build_object(
    'success', true,
    'bp_season', CASE WHEN v_bp.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', v_bp.id,
      'season_number', v_bp.season_number,
      'start_at', v_bp.start_at,
      'end_at', v_bp.end_at,
      'is_active', v_bp.is_active
    ) END,
    'guild_war_season', CASE WHEN v_gw.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', v_gw.id,
      'season_number', v_gw.season_number,
      'week_number', v_gw.week_number,
      'start_at', v_gw.start_at,
      'end_at', v_gw.end_at,
      'is_active', v_gw.is_active
    ) END,
    'night_market_schedule', jsonb_build_object(
      'start_hour', COALESCE(v_nm.start_hour, 20),
      'end_hour', COALESCE(v_nm.end_hour, 22),
      'weekday', v_nm.weekday,
      'timezone', COALESCE(v_nm.timezone, 'Europe/Istanbul'),
      'qa_force_open', COALESCE(v_nm.qa_force_open, false),
      'staff_force_closed', COALESCE(v_nm.staff_force_closed, false)
    ),
    'night_market_window', jsonb_build_object(
      'active', v_win.active,
      'starts_at', v_win.starts_at,
      'ends_at', v_win.ends_at,
      'seconds_left', v_win.seconds_left
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_update_bp_season(
  p_season_id UUID,
  p_start_at TIMESTAMPTZ,
  p_end_at TIMESTAMPTZ,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.bp_season');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_end_at <= p_start_at THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bitiş, başlangıçtan sonra olmalı.');
  END IF;

  UPDATE public.bp_seasons
  SET start_at = p_start_at, end_at = p_end_at
  WHERE id = p_season_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'BP sezonu bulunamadı.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.bp_season', 'update_bp_dates', 'bp_season', p_season_id::text,
    jsonb_build_object('start_at', p_start_at, 'end_at', p_end_at, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_update_guild_war_season(
  p_season_id UUID,
  p_start_at TIMESTAMPTZ,
  p_end_at TIMESTAMPTZ,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.guild_war_season');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_end_at <= p_start_at THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bitiş, başlangıçtan sonra olmalı.');
  END IF;

  UPDATE public.guild_war_seasons
  SET start_at = p_start_at, end_at = p_end_at
  WHERE id = p_season_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'GW sezonu bulunamadı.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.guild_war_season', 'update_gw_dates', 'guild_war_season', p_season_id::text,
    jsonb_build_object('start_at', p_start_at, 'end_at', p_end_at, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_update_night_market_schedule(
  p_payload JSONB,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_start INT := COALESCE((p_payload->>'start_hour')::int, 20);
  v_end INT := COALESCE((p_payload->>'end_hour')::int, 22);
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.night_market');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF v_start < 0 OR v_start > 23 OR v_end < 1 OR v_end > 24 OR v_end <= v_start THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz saat aralığı (0–23 başlangıç, bitiş > başlangıç).');
  END IF;

  UPDATE public.night_market_schedule
  SET
    start_hour = v_start,
    end_hour = v_end,
    timezone = COALESCE(NULLIF(p_payload->>'timezone', ''), timezone),
    qa_force_open = COALESCE((p_payload->>'qa_force_open')::boolean, qa_force_open),
    staff_force_closed = COALESCE((p_payload->>'staff_force_closed')::boolean, staff_force_closed)
  WHERE id = 1;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.night_market', 'update_schedule', 'night_market_schedule', '1',
    jsonb_build_object('payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_liveops_get_schedules() TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_update_bp_season(uuid, timestamptz, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_update_guild_war_season(uuid, timestamptz, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_update_night_market_schedule(jsonb, text) TO authenticated;

COMMIT;
