-- Backfill + auto-default hospital_reason / prison_reason when missing.

BEGIN;

UPDATE public.users
SET hospital_reason = 'dungeon_failure'
WHERE hospital_until IS NOT NULL
  AND hospital_until > now()
  AND (hospital_reason IS NULL OR btrim(hospital_reason) = '');

UPDATE public.users
SET prison_reason = 'legal_violation'
WHERE prison_until IS NOT NULL
  AND prison_until > now()
  AND (prison_reason IS NULL OR btrim(prison_reason) = '');

CREATE OR REPLACE FUNCTION public.sync_user_hospital_prison_states()
RETURNS trigger AS $$
BEGIN
  IF NEW.hospital_until IS NOT NULL AND NEW.hospital_until <= now() THEN
    NEW.hospital_until := NULL;
    NEW.hospital_reason := NULL;
    NEW.hospital_escape_attempted := false;
  END IF;

  IF NEW.prison_until IS NOT NULL AND NEW.prison_until <= now() THEN
    NEW.prison_until := NULL;
    NEW.prison_reason := NULL;
    NEW.prison_escape_attempted := false;
  END IF;

  IF NEW.hospital_until IS NULL THEN
    NEW.hospital_escape_attempted := false;
  END IF;

  IF NEW.prison_until IS NULL THEN
    NEW.prison_escape_attempted := false;
  END IF;

  IF NEW.hospital_until IS NOT NULL AND NEW.hospital_until > now() THEN
    IF NEW.hospital_reason IS NULL OR btrim(NEW.hospital_reason) = '' THEN
      NEW.hospital_reason := 'dungeon_failure';
    END IF;

    IF OLD IS NULL OR OLD.hospital_until IS NULL OR OLD.hospital_until <= now() THEN
      NEW.hospital_escape_attempted := false;
    END IF;
  END IF;

  IF NEW.prison_until IS NOT NULL AND NEW.prison_until > now() THEN
    IF NEW.prison_reason IS NULL OR btrim(NEW.prison_reason) = '' THEN
      NEW.prison_reason := 'legal_violation';
    END IF;

    IF OLD IS NULL OR OLD.prison_until IS NULL OR OLD.prison_until <= now() THEN
      NEW.prison_escape_attempted := false;
    END IF;
  END IF;

  BEGIN
    NEW.in_hospital := (NEW.hospital_until IS NOT NULL AND NEW.hospital_until > now());
  EXCEPTION
    WHEN undefined_column THEN
      NULL;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
