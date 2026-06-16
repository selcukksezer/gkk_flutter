-- =========================================================================================
-- MIGRATION: Robust Escape Flags Reset
-- =========================================================================================
-- Simplifies and consolidates the hospital/prison escape flags and in_hospital status trigger.
-- Instead of column-restricted triggers, this runs on any INSERT or UPDATE of public.users,
-- ensuring that natural healing, explicit healing, and new visits are always correctly synchronized.
-- =========================================================================================

BEGIN;

-- Drop old triggers to avoid conflict
DROP TRIGGER IF EXISTS trg_users_reset_escape_flags ON public.users;
DROP TRIGGER IF EXISTS trg_users_sync_hospital_state ON public.users;
DROP TRIGGER IF EXISTS trg_users_sync_hospital_prison_states ON public.users;

-- Drop old trigger functions
DROP FUNCTION IF EXISTS public.reset_hospital_prison_flags();
DROP FUNCTION IF EXISTS public.sync_user_hospital_state_trigger();

-- Create consolidated trigger function
CREATE OR REPLACE FUNCTION public.sync_user_hospital_prison_states()
RETURNS trigger AS $$
BEGIN
  -- 1. If hospital duration has expired, clean up status and reset escape flag
  IF NEW.hospital_until IS NOT NULL AND NEW.hospital_until <= now() THEN
    NEW.hospital_until := NULL;
    NEW.hospital_reason := NULL;
    NEW.hospital_escape_attempted := false;
  END IF;

  -- 2. If prison duration has expired, clean up status and reset escape flag
  IF NEW.prison_until IS NOT NULL AND NEW.prison_until <= now() THEN
    NEW.prison_until := NULL;
    NEW.prison_reason := NULL;
    NEW.prison_escape_attempted := false;
  END IF;

  -- 3. If explicitly healed (hospital_until is NULL), reset escape flag
  IF NEW.hospital_until IS NULL THEN
    NEW.hospital_escape_attempted := false;
  END IF;

  -- 4. If explicitly freed (prison_until is NULL), reset escape flag
  IF NEW.prison_until IS NULL THEN
    NEW.prison_escape_attempted := false;
  END IF;

  -- 5. If they just entered the hospital (hospital_until changed from NULL/past to future)
  -- Note: We only reset it if the transition is from non-hospital to hospital,
  -- so extending the time (e.g. failing escape) won't reset the flag.
  IF NEW.hospital_until IS NOT NULL AND NEW.hospital_until > now() THEN
    IF OLD IS NULL OR OLD.hospital_until IS NULL OR OLD.hospital_until <= now() THEN
      NEW.hospital_escape_attempted := false;
    END IF;
  END IF;

  -- 6. If they just entered the prison (prison_until changed from NULL/past to future)
  IF NEW.prison_until IS NOT NULL AND NEW.prison_until > now() THEN
    IF OLD IS NULL OR OLD.prison_until IS NULL OR OLD.prison_until <= now() THEN
      NEW.prison_escape_attempted := false;
    END IF;
  END IF;

  -- 7. Sync in_hospital column if it exists in the table
  BEGIN
    NEW.in_hospital := (NEW.hospital_until IS NOT NULL AND NEW.hospital_until > now());
  EXCEPTION
    WHEN undefined_column THEN
      NULL;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create consolidated trigger
CREATE TRIGGER trg_users_sync_hospital_prison_states
BEFORE INSERT OR UPDATE
ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_user_hospital_prison_states();

COMMIT;
