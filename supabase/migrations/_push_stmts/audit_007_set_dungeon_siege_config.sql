CREATE OR REPLACE FUNCTION public.set_dungeon_siege_config(
  p_is_enabled boolean DEFAULT NULL,
  p_slot_count integer DEFAULT NULL,
  p_slot_duration_minutes integer DEFAULT NULL,
  p_inactive_release_minutes integer DEFAULT NULL,
  p_challenge_cooldown_minutes integer DEFAULT NULL,
  p_challenge_gold_cost bigint DEFAULT NULL,
  p_ban_duration_minutes integer DEFAULT NULL,
  p_loot_bonus_pct numeric DEFAULT NULL,
  p_gold_bonus_pct numeric DEFAULT NULL,
  p_rep_bonus_pct numeric DEFAULT NULL,
  p_power_band_pct numeric DEFAULT NULL,
  p_prime_windows jsonb DEFAULT NULL,
  p_hold_min_members integer DEFAULT NULL,
  p_hold_bonus_pct numeric DEFAULT NULL,
  p_hold_break_wins_required integer DEFAULT NULL,
  p_territory_reserve_slot_count integer DEFAULT NULL,
  p_session_duration_minutes integer DEFAULT NULL,
  p_hold_rehold_cooldown_minutes integer DEFAULT NULL,
  p_timezone text DEFAULT NULL,
  p_siege_dungeon_ids text[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF COALESCE(current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bu ayar sadece service_role veya SQL Editor ile degistirilebilir.'
    );
  END IF;

  UPDATE public.dungeon_siege_config
  SET
    is_enabled = COALESCE(p_is_enabled, is_enabled),
    slot_count = COALESCE(p_slot_count, slot_count),
    slot_duration_minutes = COALESCE(p_slot_duration_minutes, slot_duration_minutes),
    inactive_release_minutes = COALESCE(p_inactive_release_minutes, inactive_release_minutes),
    challenge_cooldown_minutes = COALESCE(p_challenge_cooldown_minutes, challenge_cooldown_minutes),
    challenge_gold_cost = COALESCE(p_challenge_gold_cost, challenge_gold_cost),
    ban_duration_minutes = COALESCE(p_ban_duration_minutes, ban_duration_minutes),
    loot_bonus_pct = COALESCE(p_loot_bonus_pct, loot_bonus_pct),
    gold_bonus_pct = COALESCE(p_gold_bonus_pct, gold_bonus_pct),
    rep_bonus_pct = COALESCE(p_rep_bonus_pct, rep_bonus_pct),
    power_band_pct = COALESCE(p_power_band_pct, power_band_pct),
    prime_windows = COALESCE(p_prime_windows, prime_windows),
    hold_min_members = COALESCE(p_hold_min_members, hold_min_members),
    hold_bonus_pct = COALESCE(p_hold_bonus_pct, hold_bonus_pct),
    hold_break_wins_required = COALESCE(p_hold_break_wins_required, hold_break_wins_required),
    territory_reserve_slot_count = COALESCE(p_territory_reserve_slot_count, territory_reserve_slot_count),
    session_duration_minutes = COALESCE(p_session_duration_minutes, session_duration_minutes),
    hold_rehold_cooldown_minutes = COALESCE(p_hold_rehold_cooldown_minutes, hold_rehold_cooldown_minutes),
    timezone = COALESCE(p_timezone, timezone),
    siege_dungeon_ids = COALESCE(p_siege_dungeon_ids, siege_dungeon_ids),
    updated_at = now()
  WHERE id = '00000000-0000-0000-0000-000000000001'::uuid;

  RETURN public.get_dungeon_siege_config();
END;
$$;
