-- Add last_active_at for trade online checks + presence heartbeat.

BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_active_at timestamptz;

UPDATE public.users
SET last_active_at = COALESCE(last_login_at, updated_at, now())
WHERE last_active_at IS NULL;

CREATE OR REPLACE FUNCTION public.set_online_status(p_is_online boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  UPDATE public.users
  SET is_online = p_is_online,
      last_active_at = now()
  WHERE auth_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_online_status(boolean) TO authenticated;

COMMIT;
