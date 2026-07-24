CREATE TABLE IF NOT EXISTS public._gkk_migration_backups (
  backup_key text PRIMARY KEY,
  object_type text NOT NULL,
  object_name text NOT NULL,
  definition text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
