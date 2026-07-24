CREATE OR REPLACE FUNCTION public.dungeon_siege_notify(
  p_player_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_player_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.dungeon_siege_notifications (
    player_id, notif_type, title, body, payload
  ) VALUES (
    p_player_id, p_type, p_title, p_body, COALESCE(p_payload, '{}'::jsonb)
  );
END;
$$;
