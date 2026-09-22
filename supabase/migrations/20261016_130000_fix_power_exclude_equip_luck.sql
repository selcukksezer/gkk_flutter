-- Fix power inflation: sync_user_equipment_stats bakes equip luck into users.luck,
-- but calculate_user_total_power also does luck*50 while calculate_item_power already
-- includes item luck*2*enh_mult. Subtract equip_bonus_luck from the luck term.
-- Also recompute users.power for anyone with equipment bonuses.

BEGIN;

CREATE OR REPLACE FUNCTION public.calculate_user_total_power(p_user_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
  v_equipment_power NUMERIC := 0;
  v_total_power NUMERIC := 0;
  v_monument_level INT := 0;
  v_stat_mult NUMERIC := 1.0;
  v_base_luck NUMERIC := 0;
BEGIN
  SELECT COALESCE(SUM(public.calculate_item_power(i.item_id, COALESCE(i.enhancement_level, 0))), 0)
  INTO v_equipment_power
  FROM public.inventory i
  WHERE i.user_id = p_user_id AND i.is_equipped = true;

  SELECT
    level,
    reputation,
    attack,
    defense,
    health,
    luck,
    guild_id,
    COALESCE(equip_bonus_luck, 0) AS equip_bonus_luck
  INTO v_user
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level
    FROM public.guilds
    WHERE id = v_user.guild_id;
  END IF;

  v_stat_mult := public._monument_stat_multiplier(COALESCE(v_monument_level, 0));

  -- Character-allocated luck only. Gear luck already lives in calculate_item_power.
  v_base_luck := GREATEST(0, COALESCE(v_user.luck, 0) - COALESCE(v_user.equip_bonus_luck, 0));

  v_total_power := (v_equipment_power * v_stat_mult)
    + (COALESCE(v_user.level, 1) * 500)
    + (COALESCE(v_user.reputation, 0) * 0.1)
    + (v_base_luck * 50 * v_stat_mult);

  RETURN v_total_power;
END;
$$;

-- Refresh cached power so UI / attack_dungeon stop using stale or soon-to-be-inflated values.
UPDATE public.users u
SET
  power = public.calculate_user_total_power(u.auth_id)::integer,
  updated_at = NOW()
WHERE EXISTS (
  SELECT 1
  FROM public.inventory i
  WHERE i.user_id = u.auth_id
    AND i.is_equipped = true
)
OR COALESCE(u.equip_bonus_luck, 0) > 0
OR COALESCE(u.equip_bonus_attack, 0) > 0
OR COALESCE(u.equip_bonus_defense, 0) > 0
OR COALESCE(u.equip_bonus_health, 0) > 0;

COMMIT;
