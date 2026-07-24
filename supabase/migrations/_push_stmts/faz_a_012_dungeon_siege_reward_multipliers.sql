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

  RETURN jsonb_build_object(
    'siege_active', true,
    'has_slot', true,
    'gold_mult', 1 + COALESCE(v_cfg.gold_bonus_pct, 0),
    'loot_mult', 1 + COALESCE(v_cfg.loot_bonus_pct, 0),
    'rep_bonus_pct', COALESCE(v_cfg.rep_bonus_pct, 0.15)
  );
END;
$$;
