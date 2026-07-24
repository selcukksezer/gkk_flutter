CREATE OR REPLACE FUNCTION public.dungeon_siege_get_config()
RETURNS public.dungeon_siege_config
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM public.dungeon_siege_config
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;
$$;
