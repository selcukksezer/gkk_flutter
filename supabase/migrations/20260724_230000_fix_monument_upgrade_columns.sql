-- Fix upgrade_monument: guilds.monument_100_first / monument_100_at were defined in
-- CREATE TABLE IF NOT EXISTS (20260307) but never added via ALTER for existing DBs.

BEGIN;

ALTER TABLE public.guilds
  ADD COLUMN IF NOT EXISTS monument_100_first BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.guilds
  ADD COLUMN IF NOT EXISTS monument_100_at TIMESTAMPTZ;

COMMENT ON COLUMN public.guilds.monument_100_first IS
  'True when this guild was first server-wide to reach monument level 100.';
COMMENT ON COLUMN public.guilds.monument_100_at IS
  'Timestamp when monument reached level 100.';

COMMIT;
