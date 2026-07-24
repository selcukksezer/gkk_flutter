CREATE OR REPLACE FUNCTION public.dungeon_siege_active_hold(p_session_id uuid)
RETURNS public.dungeon_siege_holds
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT h.*
  FROM public.dungeon_siege_holds h
  WHERE h.session_id = p_session_id
    AND h.is_active = true
  ORDER BY h.started_at DESC
  LIMIT 1;
$$;
