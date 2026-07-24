CREATE OR REPLACE FUNCTION public.dungeon_siege_reward_multipliers(
  p_player_id uuid,
  p_dungeon_id text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_has_slot boolean;
  v_session_id uuid;
  v_player record;
  v_hold public.dungeon_siege_holds;
  v_gold_mult numeric := 1;
  v_loot_mult numeric := 1;
  v_has_hold_bonus boolean := false;
BEGIN
  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object(
      'siege_active', false,
      'has_slot', false,
      'gold_mult', 1,
      'loot_mult', 1
    );
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_has_slot := public.dungeon_siege_player_has_slot(p_player_id, p_dungeon_id);

  IF NOT v_has_slot THEN
    RETURN jsonb_build_object(
      'siege_active', true,
      'has_slot', false,
      'gold_mult', 1,
      'loot_mult', 1
    );
  END IF;

  v_gold_mult := 1 + COALESCE(v_cfg.gold_bonus_pct, 0);
  v_loot_mult := 1 + COALESCE(v_cfg.loot_bonus_pct, 0);

  SELECT sess.id INTO v_session_id
  FROM public.dungeon_siege_sessions sess
  WHERE sess.dungeon_id = p_dungeon_id
    AND sess.is_active = true
    AND sess.ends_at > now()
  ORDER BY sess.created_at DESC
  LIMIT 1;

  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  v_hold := public.dungeon_siege_active_hold(v_session_id);

  IF v_hold.id IS NOT NULL
     AND v_player.guild_id IS NOT NULL
     AND v_player.guild_id = v_hold.guild_id THEN
    v_gold_mult := v_gold_mult + COALESCE(v_cfg.hold_bonus_pct, 0);
    v_loot_mult := v_loot_mult + COALESCE(v_cfg.hold_bonus_pct, 0);
    v_has_hold_bonus := true;
  END IF;

  RETURN jsonb_build_object(
    'siege_active', true,
    'has_slot', true,
    'has_hold_bonus', v_has_hold_bonus,
    'gold_mult', v_gold_mult,
    'loot_mult', v_loot_mult,
    'rep_bonus_pct', COALESCE(v_cfg.rep_bonus_pct, 0.15)
  );
END;
$$;
