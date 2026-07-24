CREATE INDEX IF NOT EXISTS idx_dungeon_siege_bans_player
  ON public.dungeon_siege_bans (player_id, dungeon_id, banned_until DESC);
