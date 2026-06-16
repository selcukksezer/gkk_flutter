BEGIN;

ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS hospital_escape_attempted BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS prison_escape_attempted BOOLEAN DEFAULT false;

CREATE OR REPLACE FUNCTION public.reset_hospital_prison_flags()
RETURNS trigger AS $$
BEGIN
  -- Check hospital status
  IF NEW.hospital_until IS NOT NULL AND NEW.hospital_until > now() AND (OLD.hospital_until IS NULL OR OLD.hospital_until <= now()) THEN
    NEW.hospital_escape_attempted = false;
  END IF;

  -- If explicitly healed
  IF NEW.hospital_until IS NULL THEN
    NEW.hospital_escape_attempted = false;
  END IF;

  -- Check prison status
  IF NEW.prison_until IS NOT NULL AND NEW.prison_until > now() AND (OLD.prison_until IS NULL OR OLD.prison_until <= now()) THEN
    NEW.prison_escape_attempted = false;
  END IF;

  -- If explicitly freed
  IF NEW.prison_until IS NULL THEN
    NEW.prison_escape_attempted = false;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_reset_escape_flags ON public.users;

CREATE TRIGGER trg_users_reset_escape_flags
BEFORE UPDATE OF hospital_until, prison_until ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.reset_hospital_prison_flags();

COMMIT;
