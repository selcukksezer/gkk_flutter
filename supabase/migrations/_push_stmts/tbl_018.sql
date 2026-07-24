CREATE POLICY "Anyone can view siege sessions"
  ON public.dungeon_siege_sessions FOR SELECT USING (true);
