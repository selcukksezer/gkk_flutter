CREATE OR REPLACE FUNCTION public.dungeon_siege_notify_hold_guild(
  p_session_id uuid,
  p_guild_id uuid,
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
DECLARE
  v_member uuid;
BEGIN
  FOR v_member IN
    SELECT DISTINCT s.holder_id
    FROM public.dungeon_siege_slots s
    WHERE s.session_id = p_session_id
      AND s.guild_id = p_guild_id
      AND s.holder_id IS NOT NULL
  LOOP
    PERFORM public.dungeon_siege_notify(v_member, p_type, p_title, p_body, p_payload);
  END LOOP;
END;
$$;
