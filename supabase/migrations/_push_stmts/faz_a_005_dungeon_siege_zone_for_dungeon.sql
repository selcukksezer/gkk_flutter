CREATE OR REPLACE FUNCTION public.dungeon_siege_zone_for_dungeon(p_dungeon_id text)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_num integer;
BEGIN
  v_num := CAST(SUBSTRING(p_dungeon_id FROM 5) AS integer);
  IF v_num IS NULL THEN
    RETURN 0;
  END IF;
  RETURN ((v_num - 1) / 10) + 1;
END;
$$;
