BEGIN;

-- ── Patch enter_dungeon (marker-based, reversible via backup) ─
DO $patch$
DECLARE
  v_def text;
  v_marker text := E'    v_effective_scroll_drop    := LEAST(0.95, GREATEST(0, v_effective_scroll_drop    * v_reward_mult));\n';
  v_block text := E'    v_effective_scroll_drop    := LEAST(0.95, GREATEST(0, v_effective_scroll_drop    * v_reward_mult));\n\n    -- [GKK_SIEGE_BONUS_BEGIN]\n    IF public.dungeon_siege_is_enabled() THEN\n      PERFORM public.dungeon_siege_touch_slot_activity(p_player_id, p_dungeon_id);\n      v_siege := public.dungeon_siege_reward_multipliers(p_player_id, p_dungeon_id);\n      IF COALESCE((v_siege->>''has_slot'')::boolean, false) THEN\n        v_gold := floor(v_gold * COALESCE((v_siege->>''gold_mult'')::numeric, 1));\n        v_effective_equipment_drop := LEAST(0.95, v_effective_equipment_drop * COALESCE((v_siege->>''loot_mult'')::numeric, 1));\n        v_effective_resource_drop  := LEAST(0.95, v_effective_resource_drop  * COALESCE((v_siege->>''loot_mult'')::numeric, 1));\n        v_effective_scroll_drop    := LEAST(0.95, v_effective_scroll_drop    * COALESCE((v_siege->>''loot_mult'')::numeric, 1));\n      END IF;\n    END IF;\n    -- [GKK_SIEGE_BONUS_END]\n';
  v_declare_old text := E'  v_milestone_rewards JSONB := ''[]''::JSONB;';
  v_declare_new text := E'  v_milestone_rewards JSONB := ''[]''::JSONB;\n  v_siege             JSONB;';
  v_ban_marker text := E'  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN\n    RETURN jsonb_build_object(''error'', ''in_prison'');\n  END IF;\n';
  v_ban_block text := E'  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN\n    RETURN jsonb_build_object(''error'', ''in_prison'');\n  END IF;\n\n  -- [GKK_SIEGE_BAN_BEGIN]\n  IF public.dungeon_siege_is_enabled()\n     AND public.dungeon_siege_is_target_dungeon(p_dungeon_id)\n     AND public.dungeon_siege_is_banned(p_player_id, p_dungeon_id) THEN\n    RETURN jsonb_build_object(''error'', ''siege_banned'', ''message'', ''Kuşatma kaybından dolayı bu zindana giremezsiniz.'');\n  END IF;\n  -- [GKK_SIEGE_BAN_END]\n';
  v_rep_marker text := E'  IF NOT FOUND THEN\n    RETURN jsonb_build_object(''error'', ''Yetersiz enerji veya işlem çakışması'');\n  END IF;\n';
  v_rep_block text := E'  IF NOT FOUND THEN\n    RETURN jsonb_build_object(''error'', ''Yetersiz enerji veya işlem çakışması'');\n  END IF;\n\n  -- [GKK_SIEGE_REP_BEGIN]\n  IF v_success AND public.dungeon_siege_is_enabled() THEN\n    v_siege := public.dungeon_siege_reward_multipliers(p_player_id, p_dungeon_id);\n    IF COALESCE((v_siege->>''has_slot'')::boolean, false) THEN\n      UPDATE public.users\n      SET reputation = COALESCE(reputation, 0)\n        + GREATEST(1, floor(20 * COALESCE((v_siege->>''rep_bonus_pct'')::numeric, 0.15)))\n      WHERE auth_id = p_player_id;\n    END IF;\n  END IF;\n  -- [GKK_SIEGE_REP_END]\n';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'enter_dungeon'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon not found for siege patch';
  END IF;

  IF position('[GKK_SIEGE_BONUS_BEGIN]' in v_def) = 0 THEN
    IF position(v_declare_old in v_def) > 0 AND position('v_siege' in v_def) = 0 THEN
      v_def := replace(v_def, v_declare_old, v_declare_new);
    END IF;

    IF position(v_marker in v_def) = 0 THEN
      RAISE EXCEPTION 'enter_dungeon siege patch marker not found';
    END IF;
    v_def := replace(v_def, v_marker, v_block);
  END IF;

  IF position('[GKK_SIEGE_BAN_BEGIN]' in v_def) = 0 THEN
    IF position(v_ban_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_ban_marker, v_ban_block);
    END IF;
  END IF;

  IF position('[GKK_SIEGE_REP_BEGIN]' in v_def) = 0 THEN
    IF position(v_rep_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_rep_marker, v_rep_block);
    END IF;
  END IF;

  EXECUTE v_def;
END;
$patch$;

COMMIT;