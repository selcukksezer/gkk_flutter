CREATE OR REPLACE FUNCTION public.dungeon_siege_count_guild_slots(
  p_session_id uuid,
  p_guild_id uuid
)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COUNT(*)::integer
  FROM public.dungeon_siege_slots s
  WHERE s.session_id = p_session_id
    AND s.guild_id = p_guild_id
    AND s.holder_id IS NOT NULL
    AND (s.expires_at IS NULL OR s.expires_at > now());
$$;
