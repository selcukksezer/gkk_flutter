CREATE OR REPLACE FUNCTION public.dungeon_siege_is_banned(
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
    SELECT 1 FROM public.dungeon_siege_bans
    WHERE player_id = p_player_id
      AND dungeon_id = p_dungeon_id
      AND banned_until > now()
  );
$$;
