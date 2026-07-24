CREATE POLICY "Players can view own siege bans"
  ON public.dungeon_siege_bans FOR SELECT
  USING (player_id = auth.uid());
