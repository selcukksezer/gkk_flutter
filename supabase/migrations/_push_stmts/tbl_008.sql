CREATE INDEX IF NOT EXISTS idx_dungeon_siege_slots_holder
  ON public.dungeon_siege_slots (holder_id)
  WHERE holder_id IS NOT NULL;
