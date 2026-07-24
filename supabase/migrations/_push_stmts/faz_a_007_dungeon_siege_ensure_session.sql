CREATE OR REPLACE FUNCTION public.dungeon_siege_ensure_session(p_dungeon_id text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_session_id uuid;
  v_zone integer;
  v_i integer;
BEGIN
  PERFORM public.dungeon_siege_cleanup();

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_session_id
  FROM public.dungeon_siege_sessions
  WHERE dungeon_id = p_dungeon_id
    AND is_active = true
    AND ends_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_session_id IS NOT NULL THEN
    RETURN v_session_id;
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_zone := public.dungeon_siege_zone_for_dungeon(p_dungeon_id);

  INSERT INTO public.dungeon_siege_sessions (zone_number, dungeon_id, ends_at)
  VALUES (v_zone, p_dungeon_id, now() + interval '3 hours')
  RETURNING id INTO v_session_id;

  FOR v_i IN 1..v_cfg.slot_count LOOP
    INSERT INTO public.dungeon_siege_slots (session_id, slot_number)
    VALUES (v_session_id, v_i);
  END LOOP;

  RETURN v_session_id;
END;
$$;
