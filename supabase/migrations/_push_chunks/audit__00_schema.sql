BEGIN;

-- ============================================================
-- Zindan Kuşatması — audit fix (hub, hold, scores, config, cleanup)
-- Geri alma: supabase/manual_rollbacks/20260722_130001_dungeon_siege_audit_fixes_rollback.sql
-- ÖNEMLİ: Faz A rollback öncesi Faz B + audit fix rollback çalıştır.
-- ============================================================

BEGIN;

ALTER TABLE public.dungeon_siege_config
  ADD COLUMN IF NOT EXISTS session_duration_minutes integer NOT NULL DEFAULT 180
    CHECK (session_duration_minutes BETWEEN 30 AND 720),
  ADD COLUMN IF NOT EXISTS hold_rehold_cooldown_minutes integer NOT NULL DEFAULT 15
    CHECK (hold_rehold_cooldown_minutes BETWEEN 0 AND 120);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_challenges_resolved
  ON public.dungeon_siege_challenges (status, resolved_at DESC);

CREATE INDEX IF NOT EXISTS idx_guild_war_territories_zone
  ON public.guild_war_territories (zone_number)
  WHERE zone_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_sessions_active_ends
  ON public.dungeon_siege_sessions (is_active, ends_at DESC);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_slots_session_num
  ON public.dungeon_siege_slots (session_id, slot_number);

-- Zone 5–7: mevcut 4 bölgeye fallback eşleme (tam territory yoksa)
-- dng_050→zone5 uses zone4 territory owner for reserve until new territories added

CREATE OR REPLACE FUNCTION public.dungeon_siege_week_key(p_at timestamptz DEFAULT now())
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tz text;
BEGIN
  v_tz := COALESCE((SELECT timezone FROM public.dungeon_siege_get_config()), 'Europe/Istanbul');
  RETURN to_char(timezone(v_tz, p_at), 'IYYY-"W"IW');
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_owner_for_zone(p_zone_number integer)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner uuid;
  v_lookup integer;
BEGIN
  IF p_zone_number IS NULL OR p_zone_number <= 0 THEN
    RETURN NULL;
  END IF;

  v_lookup := LEAST(p_zone_number, 4);

  SELECT t.owner_guild_id INTO v_owner
  FROM public.guild_war_territories t
  WHERE t.zone_number = v_lookup
  ORDER BY t.created_at NULLS LAST
  LIMIT 1;

  RETURN v_owner;
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_apply_ban(
  p_player_id uuid,
  p_dungeon_id text,
  p_minutes integer,
  p_reason text DEFAULT 'siege_challenge_loss'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_until timestamptz := now() + make_interval(mins => GREATEST(1, p_minutes));
BEGIN
  UPDATE public.dungeon_siege_bans
  SET banned_until = GREATEST(banned_until, v_until),
      reason = p_reason
  WHERE player_id = p_player_id
    AND dungeon_id = p_dungeon_id
    AND banned_until > now();

  IF NOT FOUND THEN
    INSERT INTO public.dungeon_siege_bans (player_id, dungeon_id, banned_until, reason)
    VALUES (p_player_id, p_dungeon_id, v_until, p_reason);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_notify_hold_guild(
  p_session_id uuid,
  p_guild_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_member uuid;
BEGIN
  FOR v_member IN
    SELECT DISTINCT s.holder_id
    FROM public.dungeon_siege_slots s
    WHERE s.session_id = p_session_id
      AND s.guild_id = p_guild_id
      AND s.holder_id IS NOT NULL
  LOOP
    PERFORM public.dungeon_siege_notify(v_member, p_type, p_title, p_body, p_payload);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_cleanup()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
BEGIN
  v_cfg := public.dungeon_siege_get_config();

  UPDATE public.dungeon_siege_sessions
  SET is_active = false
  WHERE is_active = true AND ends_at <= now();

  UPDATE public.dungeon_siege_holds h
  SET is_active = false,
      ended_at = now()
  FROM public.dungeon_siege_sessions sess
  WHERE h.session_id = sess.id
    AND h.is_active = true
    AND (NOT sess.is_active OR sess.ends_at <= now());

  UPDATE public.dungeon_siege_holds h
  SET is_active = false,
      ended_at = now()
  FROM public.dungeon_siege_sessions sess
  WHERE h.session_id = sess.id
    AND h.is_active = true
    AND sess.is_active = true
    AND sess.ends_at > now()
    AND public.dungeon_siege_count_guild_slots(sess.id, h.guild_id) < v_cfg.hold_min_members;

  UPDATE public.dungeon_siege_slots s
  SET holder_id = NULL,
      guild_id = NULL,
      claimed_at = NULL,
      expires_at = NULL,
      last_active_at = NULL
  FROM public.dungeon_siege_sessions sess
  WHERE s.session_id = sess.id
    AND s.holder_id IS NOT NULL
    AND (
      (s.expires_at IS NOT NULL AND s.expires_at <= now())
      OR (
        s.last_active_at IS NOT NULL
        AND s.last_active_at <= now() - make_interval(mins => v_cfg.inactive_release_minutes)
      )
    );

  DELETE FROM public.dungeon_siege_bans WHERE banned_until <= now();
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_touch_slot_activity(
  p_player_id uuid,
  p_dungeon_id text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player record;
BEGIN
  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;

  UPDATE public.dungeon_siege_slots s
  SET last_active_at = now(),
      guild_id = COALESCE(v_player.guild_id, s.guild_id)
  FROM public.dungeon_siege_sessions sess
  WHERE s.session_id = sess.id
    AND s.holder_id = p_player_id
    AND sess.dungeon_id = p_dungeon_id
    AND sess.is_active = true
    AND sess.ends_at > now();

  IF FOUND THEN
    PERFORM public.dungeon_siege_add_weekly_score(
      p_player_id,
      p_points => 2,
      p_slot_minutes => 1
    );
  END IF;
END;
$$;

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
  VALUES (
    v_zone,
    p_dungeon_id,
    now() + make_interval(mins => COALESCE(v_cfg.session_duration_minutes, 180))
  )
  RETURNING id INTO v_session_id;

  FOR v_i IN 1..v_cfg.slot_count LOOP
    INSERT INTO public.dungeon_siege_slots (session_id, slot_number)
    VALUES (v_session_id, v_i);
  END LOOP;

  RETURN v_session_id;
END;
$$;

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

COMMIT;
