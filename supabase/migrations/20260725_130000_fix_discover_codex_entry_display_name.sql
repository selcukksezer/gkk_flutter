-- Fix discover_codex_entry: v_row from INSERT RETURNING has no display_name.
-- When catalog miss (or conflict path), accessing v_row.display_name crashed dungeon runs.
CREATE OR REPLACE FUNCTION public.discover_codex_entry(
  p_type TEXT,
  p_key TEXT,
  p_player_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inserted BOOLEAN := false;
  v_display_name TEXT;
  v_rarity TEXT;
  v_zone TEXT;
BEGIN
  IF p_player_id IS NULL OR p_type IS NULL OR p_key IS NULL THEN
    RETURN jsonb_build_object('discovered', false);
  END IF;

  INSERT INTO public.player_codex_entries (player_id, entry_type, entry_key)
  VALUES (p_player_id, p_type, p_key)
  ON CONFLICT DO NOTHING
  RETURNING true INTO v_inserted;

  v_inserted := COALESCE(v_inserted, false);

  SELECT cc.display_name, cc.rarity, cc.zone
  INTO v_display_name, v_rarity, v_zone
  FROM public.codex_catalog cc
  WHERE cc.entry_type = p_type AND cc.entry_key = p_key;

  RETURN jsonb_build_object(
    'discovered', v_inserted,
    'entry_type', p_type,
    'entry_key', p_key,
    'display_name', COALESCE(v_display_name, p_key),
    'rarity', v_rarity,
    'zone', v_zone
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.discover_codex_entry(TEXT, TEXT, UUID) TO authenticated;
