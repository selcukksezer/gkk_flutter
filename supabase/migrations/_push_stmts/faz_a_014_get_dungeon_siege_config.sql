CREATE OR REPLACE FUNCTION public.get_dungeon_siege_config()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
BEGIN
  v_cfg := public.dungeon_siege_get_config();
  RETURN jsonb_build_object(
    'is_enabled', v_cfg.is_enabled,
    'slot_count', v_cfg.slot_count,
    'slot_duration_minutes', v_cfg.slot_duration_minutes,
    'inactive_release_minutes', v_cfg.inactive_release_minutes,
    'challenge_cooldown_minutes', v_cfg.challenge_cooldown_minutes,
    'challenge_gold_cost', v_cfg.challenge_gold_cost,
    'ban_duration_minutes', v_cfg.ban_duration_minutes,
    'loot_bonus_pct', v_cfg.loot_bonus_pct,
    'gold_bonus_pct', v_cfg.gold_bonus_pct,
    'rep_bonus_pct', v_cfg.rep_bonus_pct,
    'power_band_pct', v_cfg.power_band_pct,
    'timezone', v_cfg.timezone,
    'prime_windows', v_cfg.prime_windows,
    'siege_dungeon_ids', v_cfg.siege_dungeon_ids,
    'in_prime_window', public.dungeon_siege_in_prime_window()
  );
END;
$$;
