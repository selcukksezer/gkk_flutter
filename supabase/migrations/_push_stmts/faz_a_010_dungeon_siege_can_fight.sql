CREATE OR REPLACE FUNCTION public.dungeon_siege_can_fight(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_id = p_user_id
      AND (
        (u.hospital_until IS NOT NULL AND u.hospital_until > now())
        OR (u.prison_until IS NOT NULL AND u.prison_until > now())
      )
  );
$$;
