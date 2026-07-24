CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_owner_for_zone(p_zone_number integer)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner uuid;
  v_lookup integer;
BEGIN
  IF p_zone_number IS NULL OR p_zone_number <= 0 THEN
    RETURN NULL;
  END IF;

  v_lookup := LEAST(p_zone_number, 4);

  SELECT t.owner_guild_id INTO v_owner
  FROM public.guild_war_territories t
  WHERE t.zone_number = v_lookup
  ORDER BY t.created_at NULLS LAST
  LIMIT 1;

  RETURN v_owner;
END;
$$;
