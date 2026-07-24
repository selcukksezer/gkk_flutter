CREATE INDEX IF NOT EXISTS idx_dungeon_siege_sessions_active
  ON public.dungeon_siege_sessions (dungeon_id, is_active, ends_at DESC);
