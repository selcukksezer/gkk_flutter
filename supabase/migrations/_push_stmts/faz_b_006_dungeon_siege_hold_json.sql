CREATE OR REPLACE FUNCTION public.dungeon_siege_hold_json(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hold public.dungeon_siege_holds;
  v_cfg public.dungeon_siege_config;
BEGIN
  v_hold := public.dungeon_siege_active_hold(p_session_id);
  IF v_hold.id IS NULL THEN
    RETURN NULL;
  END IF;

  v_cfg := public.dungeon_siege_get_config();

  RETURN jsonb_build_object(
    'hold_id', v_hold.id,
    'guild_id', v_hold.guild_id,
    'guild_name', (SELECT name FROM public.guilds WHERE id = v_hold.guild_id),
    'break_progress', v_hold.break_progress,
    'break_required', v_cfg.hold_break_wins_required,
    'started_at', v_hold.started_at,
    'member_slots', public.dungeon_siege_count_guild_slots(p_session_id, v_hold.guild_id)
  );
END;
$$;
