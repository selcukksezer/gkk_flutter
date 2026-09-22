-- Live ticker: dungeon siege prime T-15 warning + siege started (once per window).

BEGIN;

CREATE OR REPLACE FUNCTION public._siege_prime_ticker_state(p_now TIMESTAMPTZ DEFAULT now())
RETURNS TABLE (
  phase TEXT,
  slot_key TEXT,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  minutes_until_start INTEGER,
  minutes_since_start INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_tz TEXT;
  v_local TIMESTAMP;
  v_local_date TIMESTAMP;
  v_now_tod TIME;
  v_window JSONB;
  v_start TIME;
  v_end TIME;
  v_start_local TIMESTAMP;
  v_end_local TIMESTAMP;
  v_best_until INTERVAL;
  v_best_start_local TIMESTAMP;
  v_best_end_local TIMESTAMP;
  v_candidate_until INTERVAL;
  v_mins INT;
BEGIN
  phase := 'idle';
  slot_key := NULL;
  starts_at := NULL;
  ends_at := NULL;
  minutes_until_start := NULL;
  minutes_since_start := NULL;

  BEGIN
    v_cfg := public.dungeon_siege_get_config();
  EXCEPTION WHEN OTHERS THEN
    RETURN NEXT;
    RETURN;
  END;

  IF NOT COALESCE(v_cfg.is_enabled, false) THEN
    RETURN NEXT;
    RETURN;
  END IF;

  v_tz := COALESCE(NULLIF(btrim(v_cfg.timezone), ''), 'Europe/Istanbul');
  v_local := p_now AT TIME ZONE v_tz;
  v_local_date := date_trunc('day', v_local);
  v_now_tod := v_local::time;

  -- Active prime window?
  FOR v_window IN
    SELECT value FROM jsonb_array_elements(COALESCE(v_cfg.prime_windows, '[]'::jsonb))
  LOOP
    BEGIN
      v_start := (v_window->>'start')::time;
      v_end := (v_window->>'end')::time;
    EXCEPTION WHEN OTHERS THEN
      CONTINUE;
    END;

    IF v_end = v_start THEN
      CONTINUE;
    END IF;

    IF v_end > v_start THEN
      IF v_now_tod >= v_start AND v_now_tod < v_end THEN
        v_start_local := v_local_date + v_start;
        v_end_local := v_local_date + v_end;
        phase := 'open';
        slot_key := to_char(v_start_local, 'YYYY-MM-DD"T"HH24:MI');
        starts_at := v_start_local AT TIME ZONE v_tz;
        ends_at := v_end_local AT TIME ZONE v_tz;
        minutes_since_start := GREATEST(0, floor(EXTRACT(EPOCH FROM (p_now - starts_at)) / 60)::int);
        minutes_until_start := 0;
        RETURN NEXT;
        RETURN;
      END IF;
    ELSE
      -- Midnight wrap (e.g. 22:00 → 00:00 / 02:00)
      IF v_now_tod >= v_start OR v_now_tod < v_end THEN
        IF v_now_tod >= v_start THEN
          v_start_local := v_local_date + v_start;
          v_end_local := v_local_date + interval '1 day' + v_end;
        ELSE
          v_start_local := v_local_date - interval '1 day' + v_start;
          v_end_local := v_local_date + v_end;
        END IF;
        phase := 'open';
        slot_key := to_char(v_start_local, 'YYYY-MM-DD"T"HH24:MI');
        starts_at := v_start_local AT TIME ZONE v_tz;
        ends_at := v_end_local AT TIME ZONE v_tz;
        minutes_since_start := GREATEST(0, floor(EXTRACT(EPOCH FROM (p_now - starts_at)) / 60)::int);
        minutes_until_start := 0;
        RETURN NEXT;
        RETURN;
      END IF;
    END IF;
  END LOOP;

  -- Next start among windows
  v_best_until := NULL;
  FOR v_window IN
    SELECT value FROM jsonb_array_elements(COALESCE(v_cfg.prime_windows, '[]'::jsonb))
  LOOP
    BEGIN
      v_start := (v_window->>'start')::time;
      v_end := (v_window->>'end')::time;
    EXCEPTION WHEN OTHERS THEN
      CONTINUE;
    END;

    IF v_end = v_start THEN
      CONTINUE;
    END IF;

    IF v_end > v_start THEN
      IF v_now_tod < v_start THEN
        v_start_local := v_local_date + v_start;
        v_end_local := v_local_date + v_end;
      ELSE
        v_start_local := v_local_date + interval '1 day' + v_start;
        v_end_local := v_local_date + interval '1 day' + v_end;
      END IF;
    ELSE
      -- Gap between end and start on same calendar day
      IF v_now_tod < v_start THEN
        v_start_local := v_local_date + v_start;
        v_end_local := v_local_date + interval '1 day' + v_end;
      ELSE
        v_start_local := v_local_date + interval '1 day' + v_start;
        v_end_local := v_local_date + interval '2 day' + v_end;
      END IF;
    END IF;

    v_candidate_until := (v_start_local AT TIME ZONE v_tz) - p_now;
    IF v_candidate_until <= interval '0' THEN
      CONTINUE;
    END IF;
    IF v_best_until IS NULL OR v_candidate_until < v_best_until THEN
      v_best_until := v_candidate_until;
      v_best_start_local := v_start_local;
      v_best_end_local := v_end_local;
    END IF;
  END LOOP;

  IF v_best_until IS NULL THEN
    RETURN NEXT;
    RETURN;
  END IF;

  v_mins := GREATEST(0, ceil(EXTRACT(EPOCH FROM v_best_until) / 60.0)::int);
  starts_at := v_best_start_local AT TIME ZONE v_tz;
  ends_at := v_best_end_local AT TIME ZONE v_tz;
  slot_key := to_char(v_best_start_local, 'YYYY-MM-DD"T"HH24:MI');
  minutes_until_start := v_mins;
  minutes_since_start := NULL;

  IF v_mins > 0 AND v_mins <= 15 THEN
    phase := 'soon';
  ELSE
    phase := 'idle';
  END IF;

  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public._live_ticker_prepend_capped(
  p_items JSONB,
  p_item JSONB,
  p_limit INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_items JSONB;
  v_limit INT := GREATEST(3, LEAST(COALESCE(p_limit, 10), 20));
BEGIN
  v_items := jsonb_build_array(p_item) || COALESCE(p_items, '[]'::jsonb);
  IF jsonb_array_length(v_items) > v_limit THEN
    SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT elem
      FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
      WHERE ord <= v_limit
    ) x;
  END IF;
  RETURN v_items;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_live_ticker_feed(p_limit integer DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_base JSONB;
  v_manual JSONB;
  v_items JSONB;
  v_limit INT := GREATEST(3, LEAST(COALESCE(p_limit, 10), 20));
  v_siege RECORD;
  v_ticker_id TEXT;
  v_item JSONB;
  v_q public.live_ticker_queue_state%ROWTYPE;
BEGIN
  v_base := public.get_live_ticker_feed_core(p_limit);
  IF COALESCE((v_base->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_base;
  END IF;

  v_items := COALESCE(v_base->'items', '[]'::jsonb);

  -- Manual events: king gifts etc. Staff uses staff_broadcasts only (no duplicate manual rows).
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', e.event_type || ':' || e.id::text,
        'type', e.event_type,
        'text', e.message,
        'created_at', e.created_at,
        'max_passes', COALESCE(q.max_passes, 3),
        'passes_remaining', GREATEST(COALESCE(q.max_passes, 3) - COALESCE(q.passes_completed, 0), 0)
      )
      ORDER BY e.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_manual
  FROM (
    SELECT e.*
    FROM public.live_ticker_manual_events e
    WHERE e.expires_at > now()
      AND e.event_type <> 'staff_broadcast'
    ORDER BY e.created_at DESC
    LIMIT 5
  ) e
  LEFT JOIN public.live_ticker_queue_state q
    ON q.ticker_id = e.event_type || ':' || e.id::text
  WHERE COALESCE(q.retired_at, NULL) IS NULL
    AND COALESCE(q.passes_completed, 0) < COALESCE(q.max_passes, 3);

  IF jsonb_array_length(v_manual) > 0 THEN
    v_items := v_manual || v_items;
    IF jsonb_array_length(v_items) > v_limit THEN
      SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT elem
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_limit
      ) x;
    END IF;
  END IF;

  -- Siege prime schedule: T-15 soon + started (dedupe via slot_key + queue retire).
  BEGIN
    SELECT * INTO v_siege FROM public._siege_prime_ticker_state();
    IF COALESCE(v_siege.phase, 'idle') IN ('soon', 'open') AND v_siege.slot_key IS NOT NULL THEN
      IF v_siege.phase = 'soon' THEN
        v_ticker_id := 'siege_soon:' || v_siege.slot_key;
        v_item := jsonb_build_object(
          'id', v_ticker_id,
          'type', 'siege_soon',
          'text', '🛡️ Kuşatmaya 15 dk kaldı! Slot kapışmasına hazırlan.',
          'created_at', now(),
          'max_passes', 3,
          'passes_remaining', 3
        );
      ELSE
        v_ticker_id := 'siege_start:' || v_siege.slot_key;
        v_item := jsonb_build_object(
          'id', v_ticker_id,
          'type', 'siege_start',
          'text', '🔥 Kuşatma başladı! Prime penceresi açık — slot kapış!',
          'created_at', COALESCE(v_siege.starts_at, now()),
          'max_passes', 3,
          'passes_remaining', 3
        );
      END IF;

      SELECT * INTO v_q
      FROM public.live_ticker_queue_state q
      WHERE q.ticker_id = v_ticker_id;

      IF NOT FOUND
         OR (v_q.retired_at IS NULL AND COALESCE(v_q.passes_completed, 0) < COALESCE(v_q.max_passes, 3))
      THEN
        IF FOUND THEN
          v_item := v_item || jsonb_build_object(
            'max_passes', COALESCE(v_q.max_passes, 3),
            'passes_remaining', GREATEST(COALESCE(v_q.max_passes, 3) - COALESCE(v_q.passes_completed, 0), 0)
          );
        END IF;
        v_items := public._live_ticker_prepend_capped(v_items, v_item, v_limit);
      END IF;
    END IF;
  EXCEPTION WHEN undefined_function THEN
    NULL;
  END;

  RETURN jsonb_set(
    jsonb_set(v_base, '{items}', v_items, true),
    '{count}',
    to_jsonb(jsonb_array_length(v_items)),
    true
  );
END;
$$;

REVOKE ALL ON FUNCTION public._siege_prime_ticker_state(timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._live_ticker_prepend_capped(jsonb, jsonb, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed(integer) TO authenticated;

COMMIT;
