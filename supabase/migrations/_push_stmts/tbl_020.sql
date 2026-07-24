CREATE POLICY "Anyone can view siege slots"
  ON public.dungeon_siege_slots FOR SELECT USING (true);
