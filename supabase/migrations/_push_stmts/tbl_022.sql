CREATE POLICY "Anyone can view siege challenges"
  ON public.dungeon_siege_challenges FOR SELECT USING (true);
