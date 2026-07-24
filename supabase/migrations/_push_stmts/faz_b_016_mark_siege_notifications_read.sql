CREATE OR REPLACE FUNCTION public.mark_siege_notifications_read(p_notification_ids uuid[] DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_notification_ids IS NULL OR array_length(p_notification_ids, 1) IS NULL THEN
    UPDATE public.dungeon_siege_notifications
    SET read_at = now()
    WHERE player_id = v_me AND read_at IS NULL;
  ELSE
    UPDATE public.dungeon_siege_notifications
    SET read_at = now()
    WHERE player_id = v_me
      AND id = ANY(p_notification_ids)
      AND read_at IS NULL;
  END IF;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('success', true, 'marked_read', v_count);
END;
$$;
