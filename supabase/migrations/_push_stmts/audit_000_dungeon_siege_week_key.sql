CREATE OR REPLACE FUNCTION public.dungeon_siege_week_key(p_at timestamptz DEFAULT now())
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tz text;
BEGIN
  v_tz := COALESCE((SELECT timezone FROM public.dungeon_siege_get_config()), 'Europe/Istanbul');
  RETURN to_char(timezone(v_tz, p_at), 'IYYY-"W"IW');
END;
$$;
