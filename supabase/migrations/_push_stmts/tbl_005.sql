CREATE POLICY "Anyone can read siege config"
  ON public.dungeon_siege_config FOR SELECT USING (true);
