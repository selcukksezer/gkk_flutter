CREATE OR REPLACE FUNCTION public.dungeon_siege_is_enabled()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE((SELECT is_enabled FROM public.dungeon_siege_get_config()), false);
$$;
