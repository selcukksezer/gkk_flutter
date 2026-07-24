CREATE OR REPLACE FUNCTION public.dungeon_siege_week_key(p_at timestamptz DEFAULT now())
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT to_char(timezone('Europe/Istanbul', p_at), 'IYYY-"W"IW');
$$;
