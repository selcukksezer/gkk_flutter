-- get_dungeons referenced non-existent columns d.max_players and d.loot_table.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_dungeons()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', d.id,
      'dungeon_id', d.id,
      'name', COALESCE(NULLIF(d.name_tr, ''), d.name),
      'description', COALESCE(d.description, ''),
      'difficulty', CASE
        WHEN d.is_boss THEN 'dungeon'
        WHEN COALESCE(d.power_requirement, 0) < 15000 THEN 'easy'
        WHEN COALESCE(d.power_requirement, 0) < 45000 THEN 'medium'
        ELSE 'hard'
      END,
      'required_level', GREATEST(1, floor(COALESCE(d.power_requirement, 0) / 500.0)::INT),
      'min_level', GREATEST(1, floor(COALESCE(d.power_requirement, 0) / 500.0)::INT),
      'power_requirement', COALESCE(d.power_requirement, 0),
      'max_players', 1,
      'energy_cost', COALESCE(d.energy_cost, 0),
      'min_gold', COALESCE(d.gold_min, 0),
      'max_gold', COALESCE(d.gold_max, 0),
      'xp_reward', COALESCE(d.xp_reward, 0),
      'base_gold_reward', floor((COALESCE(d.gold_min, 0) + COALESCE(d.gold_max, 0)) / 2.0)::INT,
      'base_xp_reward', COALESCE(d.xp_reward, 0),
      'is_group', false,
      'loot_table', '[]'::jsonb,
      'equipment_drop_chance', COALESCE(d.equipment_drop_chance, 0),
      'resource_drop_chance', COALESCE(d.resource_drop_chance, 0),
      'catalyst_drop_chance', COALESCE(d.catalyst_drop_chance, 0),
      'scroll_drop_chance', COALESCE(d.scroll_drop_chance, 0),
      'loot_rarity_weights', COALESCE(d.loot_rarity_weights, '{}'::jsonb),
      'boss_name', CASE WHEN COALESCE(d.is_boss, false) THEN COALESCE(d.name_tr, d.name) ELSE NULL END,
      'zone', COALESCE(d.zone, 1),
      'zone_name', COALESCE(d.zone_name, ''),
      'dungeon_order', COALESCE(d.dungeon_order, 0),
      'is_boss', COALESCE(d.is_boss, false),
      'daily_boss_limit', COALESCE(d.daily_boss_limit, 3)
    )
    ORDER BY COALESCE(d.dungeon_order, 0)
  ), '[]'::JSONB)
  INTO v_result
  FROM public.dungeons d;

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_dungeons() TO authenticated, anon;

COMMIT;
