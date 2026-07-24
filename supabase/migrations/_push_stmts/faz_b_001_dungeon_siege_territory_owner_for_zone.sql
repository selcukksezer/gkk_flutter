CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_owner_for_zone(p_zone_number integer)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT t.owner_guild_id
  FROM public.guild_war_territories t
  WHERE t.zone_number = p_zone_number
  ORDER BY t.created_at NULLS LAST
  LIMIT 1;
$$;
