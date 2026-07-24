CREATE OR REPLACE FUNCTION public.dungeon_siege_is_active_for_dungeon(p_dungeon_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.dungeon_siege_is_enabled()
     AND public.dungeon_siege_in_prime_window()
     AND public.dungeon_siege_is_target_dungeon(p_dungeon_id);
$$;
