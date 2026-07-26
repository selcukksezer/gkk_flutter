-- Fix stuck staff ticker: manual staff_broadcast rows duplicate feed + wrong pass tracking.
-- staff_broadcasts table is the single source of truth for staff announcements.

BEGIN;

-- Purge ghost manual staff rows (they use staff_broadcast:{manual_uuid} ids, never retire).
UPDATE public.live_ticker_manual_events
SET expires_at = now()
WHERE event_type = 'staff_broadcast';

CREATE OR REPLACE FUNCTION public.staff_liveops_create_broadcast(
  p_message TEXT,
  p_max_passes INT DEFAULT 3
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_id UUID;
  v_passes INT := GREATEST(1, LEAST(COALESCE(p_max_passes, 3), 500));
  v_body TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.broadcast');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF btrim(COALESCE(p_message, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duyuru metni gerekli.');
  END IF;

  UPDATE public.staff_broadcasts SET is_active = false WHERE is_active = true;

  UPDATE public.live_ticker_manual_events
  SET expires_at = now()
  WHERE event_type = 'staff_broadcast';

  INSERT INTO public.staff_broadcasts (
    message, created_by, is_active, expires_at, max_passes, passes_completed
  )
  VALUES (
    left(btrim(p_message), 280),
    v_actor,
    true,
    now() + interval '7 days',
    v_passes,
    0
  )
  RETURNING id INTO v_id;

  v_body := CASE
    WHEN left(btrim(p_message), 2) = '📣' THEN left(btrim(p_message), 200)
    ELSE '📣 ' || left(btrim(p_message), 180)
  END;

  PERFORM public._post_global_announcement_chat(
    v_actor,
    v_body,
    'staff_broadcast',
    jsonb_build_object('broadcast_id', v_id)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.broadcast', 'create_broadcast', 'staff_broadcast', v_id::text,
    jsonb_build_object('message', p_message, 'max_passes', v_passes),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object(
    'success', true,
    'broadcast_id', v_id,
    'max_passes', v_passes
  );
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

  RETURN jsonb_set(v_base, '{items}', v_items, true);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_staff_broadcast_pass(p_broadcast_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row public.staff_broadcasts%ROWTYPE;
BEGIN
  IF p_broadcast_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz duyuru.');
  END IF;

  UPDATE public.staff_broadcasts b
  SET
    passes_completed = b.passes_completed + 1,
    is_active = CASE
      WHEN b.passes_completed + 1 >= b.max_passes THEN false
      ELSE b.is_active
    END
  WHERE b.id = p_broadcast_id
    AND b.is_active = true
    AND b.passes_completed < b.max_passes
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'inactive', true);
  END IF;

  IF NOT v_row.is_active OR v_row.passes_completed >= v_row.max_passes THEN
    UPDATE public.live_ticker_manual_events
    SET expires_at = now()
    WHERE event_type = 'staff_broadcast'
      AND reference_id = p_broadcast_id::text;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'passes_completed', v_row.passes_completed,
    'max_passes', v_row.max_passes,
    'is_active', v_row.is_active,
    'passes_remaining', GREATEST(v_row.max_passes - v_row.passes_completed, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_liveops_create_broadcast(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_staff_broadcast_pass(uuid) TO authenticated;

COMMIT;
