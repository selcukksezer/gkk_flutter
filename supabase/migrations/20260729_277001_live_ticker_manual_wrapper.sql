-- Merge manual ticker events (king gifts, staff chat duplicates) into feed.

BEGIN;

ALTER FUNCTION public.get_live_ticker_feed(integer) RENAME TO get_live_ticker_feed_core;

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

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', e.event_type || ':' || e.id::text,
        'type', e.event_type,
        'text', e.message,
        'created_at', e.created_at
      )
      ORDER BY e.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_manual
  FROM (
    SELECT *
    FROM public.live_ticker_manual_events e
    WHERE e.expires_at > now()
    ORDER BY e.created_at DESC
    LIMIT 5
  ) e;

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

GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_live_ticker_feed_core(integer) TO authenticated;

COMMIT;
