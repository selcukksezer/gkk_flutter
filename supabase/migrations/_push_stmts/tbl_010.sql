CREATE INDEX IF NOT EXISTS idx_dungeon_siege_challenges_challenger
  ON public.dungeon_siege_challenges (challenger_id, created_at DESC);
