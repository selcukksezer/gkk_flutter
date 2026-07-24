CREATE OR REPLACE FUNCTION public.get_dungeon_siege_notifications(p_limit integer DEFAULT 20)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_rows jsonb;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', n.id,
    'type', n.notif_type,
    'title', n.title,
    'body', n.body,
    'payload', n.payload,
    'read_at', n.read_at,
    'created_at', n.created_at,
    'is_unread', n.read_at IS NULL
  ) ORDER BY n.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT *
    FROM public.dungeon_siege_notifications
    WHERE player_id = v_me
    ORDER BY created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 50))
  ) n;

  RETURN jsonb_build_object(
    'success', true,
    'notifications', COALESCE(v_rows, '[]'::jsonb),
    'unread_count', (
      SELECT COUNT(*)::integer
      FROM public.dungeon_siege_notifications
      WHERE player_id = v_me AND read_at IS NULL
    )
  );
END;
$$;
