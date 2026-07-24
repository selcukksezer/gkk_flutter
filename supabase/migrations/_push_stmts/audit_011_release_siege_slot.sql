CREATE OR REPLACE FUNCTION public.release_siege_slot(p_slot_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_slot record;
  v_dungeon_id text;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT s.*, sess.dungeon_id
  INTO v_slot
  FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE s.id = p_slot_id
  FOR UPDATE OF s;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Slot bulunamadı.');
  END IF;

  v_dungeon_id := v_slot.dungeon_id;

  IF v_slot.holder_id IS DISTINCT FROM v_me THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu slot sana ait değil.');
  END IF;

  UPDATE public.dungeon_siege_slots
  SET holder_id = NULL,
      guild_id = NULL,
      claimed_at = NULL,
      expires_at = NULL,
      last_active_at = NULL
  WHERE id = p_slot_id;

  PERFORM public.dungeon_siege_cleanup();

  RETURN jsonb_build_object('success', true, 'message', 'Slot bırakıldı.');
END;
$$;
