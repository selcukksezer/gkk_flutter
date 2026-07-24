INSERT INTO public._gkk_migration_backups (backup_key, object_type, object_name, definition)
SELECT
  'enter_dungeon_pre_siege',
  'function',
  'public.enter_dungeon(uuid,text)',
  pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'enter_dungeon'
  AND pg_get_function_identity_arguments(p.oid) = 'p_player_id uuid, p_dungeon_id text'
ON CONFLICT (backup_key) DO UPDATE
SET definition = EXCLUDED.definition,
    created_at = now();
