CREATE OR REPLACE FUNCTION public.dungeon_siege_player_has_slot(
  p_player_id uuid,
  p_dungeon_id text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = p_player_id
      AND sess.dungeon_id = p_dungeon_id
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (s.expires_at IS NULL OR s.expires_at > now())
  );
$$;
