CREATE OR REPLACE FUNCTION public.dungeon_siege_is_target_dungeon(p_dungeon_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_dungeon_id = ANY(COALESCE((SELECT siege_dungeon_ids FROM public.dungeon_siege_get_config()), ARRAY[]::text[]));
$$;
