-- Expose XP multiplier breakdown from enter_dungeon for result UI.

DO $$
DECLARE
  v_def TEXT;
  v_marker_old TEXT := $old$
    v_gold := floor(v_gold * v_reward_mult);
    v_xp   := floor(v_xp   * v_reward_mult);
    -- [GKK_MONUMENT_BEGIN]
    v_xp := floor(v_xp * public._monument_xp_multiplier(p_player_id));
    v_gold := floor(v_gold * public._monument_gold_multiplier(p_player_id));
    -- [GKK_MONUMENT_END]
$old$;
  v_marker_new TEXT := $new$
    v_xp_base := v_xp;
    v_xp_crit_mult := CASE WHEN v_is_critical THEN 1.5 ELSE 1.0 END;
    v_xp_luck_mult := (1 + COALESCE(v_player.luck, 0) * 0.001);
    -- Reconstruct pre-farm XP for breakdown (current v_xp already includes crit+luck).
    v_xp_after_luck := v_xp;
    v_gold := floor(v_gold * v_reward_mult);
    v_xp   := floor(v_xp   * v_reward_mult);
    v_xp_after_farm := v_xp;
    -- [GKK_MONUMENT_BEGIN]
    v_monument_xp_pct := public._monument_xp_bonus_pct(public._monument_level_for_auth(p_player_id));
    v_xp := floor(v_xp * public._monument_xp_multiplier(p_player_id));
    v_gold := floor(v_gold * public._monument_gold_multiplier(p_player_id));
    v_monument_xp_bonus := GREATEST(0, v_xp - v_xp_after_farm);
    -- [GKK_MONUMENT_END]
    v_xp_breakdown := jsonb_build_object(
      'base', v_dungeon.xp_reward,
      'critical_mult', round(v_xp_crit_mult::numeric, 3),
      'luck_mult', round(v_xp_luck_mult::numeric, 4),
      'farm_mult', round(v_reward_mult::numeric, 3),
      'monument_pct', round(COALESCE(v_monument_xp_pct, 0)::numeric, 2),
      'monument_xp', v_monument_xp_bonus,
      'final', v_xp
    );
$new$;
  v_decl_old TEXT := 'v_reward_mult       NUMERIC := 1.0;';
  v_decl_new TEXT := $d$v_reward_mult       NUMERIC := 1.0;
  v_xp_base           INTEGER := 0;
  v_xp_after_luck     INTEGER := 0;
  v_xp_after_farm     INTEGER := 0;
  v_xp_crit_mult      NUMERIC := 1.0;
  v_xp_luck_mult      NUMERIC := 1.0;
  v_monument_xp_pct   NUMERIC := 0;
  v_monument_xp_bonus INTEGER := 0;
  v_xp_breakdown      JSONB := '{}'::JSONB;$d$;
  v_ret_old TEXT := '''xp_earned'',          v_xp,';
  v_ret_new TEXT := $r$'xp_earned',          v_xp,
    'xp_breakdown',      COALESCE(v_xp_breakdown, '{}'::JSONB),$r$;
BEGIN
  SELECT pg_get_functiondef('public.enter_dungeon(uuid, text)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon(uuid,text) not found for xp breakdown patch';
  END IF;

  IF position('xp_breakdown' in v_def) > 0 THEN
    RAISE NOTICE 'enter_dungeon already has xp_breakdown — skip';
    RETURN;
  END IF;

  IF position(v_decl_old in v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon decl marker not found';
  END IF;
  v_def := replace(v_def, v_decl_old, v_decl_new);

  IF position(v_marker_old in v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon monument/farm marker not found';
  END IF;
  v_def := replace(v_def, v_marker_old, v_marker_new);

  IF position(v_ret_old in v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon xp_earned return marker not found';
  END IF;
  v_def := replace(v_def, v_ret_old, v_ret_new);

  EXECUTE v_def;
END;
$$;
