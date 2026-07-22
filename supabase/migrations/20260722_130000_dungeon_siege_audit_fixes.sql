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
    'hold_min_members', v_cfg.hold_min_members,
    'hold_bonus_pct', v_cfg.hold_bonus_pct,
    'hold_break_wins_required', v_cfg.hold_break_wins_required,
    'territory_reserve_slot_count', v_cfg.territory_reserve_slot_count,
    'session_duration_minutes', v_cfg.session_duration_minutes,
    'hold_rehold_cooldown_minutes', v_cfg.hold_rehold_cooldown_minutes,
    'timezone', v_cfg.timezone,
    'prime_windows', v_cfg.prime_windows,
    'siege_dungeon_ids', v_cfg.siege_dungeon_ids,
    'in_prime_window', public.dungeon_siege_in_prime_window()
  );
END;
$$;

-- challenge_siege_slot: notify order, ban upsert, hold break notify, power align, result notify
CREATE OR REPLACE FUNCTION public.challenge_siege_slot(p_slot_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_cfg public.dungeon_siege_config;
  v_slot record;
  v_challenger record;
  v_defender record;
  v_att_power numeric;
  v_def_power numeric;
  v_win_chance numeric;
  v_winner_id uuid;
  v_loser_id uuid;
  v_ch_rating int;
  v_tg_rating int;
  v_hold public.dungeon_siege_holds;
  v_hold_broken boolean := false;
  v_ch_name text;
  v_def_name text;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_cfg := public.dungeon_siege_get_config();

  IF NOT v_cfg.is_enabled OR NOT public.dungeon_siege_in_prime_window() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  SELECT s.*, sess.dungeon_id, sess.id AS session_uuid
  INTO v_slot
  FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE s.id = p_slot_id
    AND sess.is_active = true
    AND sess.ends_at > now()
  FOR UPDATE OF s;

  IF NOT FOUND OR v_slot.holder_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Slot boş veya geçersiz.');
  END IF;

  IF v_slot.holder_id = v_me THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi slotuna meydan okuyamazsın.');
  END IF;

  IF public.dungeon_siege_is_banned(v_me, v_slot.dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindandan banlısın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastane/cezaevinde meydan okuyamazsın.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.dungeon_siege_challenges
    WHERE challenger_id = v_me
      AND created_at > now() - make_interval(mins => v_cfg.challenge_cooldown_minutes)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Meydan okuma bekleme süresindesin.');
  END IF;

  SELECT * INTO v_challenger FROM public.users WHERE auth_id = v_me FOR UPDATE;
  SELECT * INTO v_defender FROM public.users WHERE auth_id = v_slot.holder_id FOR UPDATE;

  IF v_challenger IS NULL OR v_defender IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  v_ch_name := COALESCE(v_challenger.display_name, v_challenger.username, 'Rakip');
  v_def_name := COALESCE(v_defender.display_name, v_defender.username, 'Rakip');

  IF v_challenger.guild_id IS NOT NULL AND v_challenger.guild_id = v_defender.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesine meydan okuyamazsın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_slot.holder_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakip hastane/cezaevinde.');
  END IF;

  IF v_challenger.gold < v_cfg.challenge_gold_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın.');
  END IF;

  v_att_power := COALESCE(public.calculate_user_total_power(v_me), v_challenger.power, 0);
  v_def_power := COALESCE(
    public.calculate_user_total_power(v_slot.holder_id),
    v_defender.power,
    0
  );

  IF v_att_power <= 0 THEN
    v_att_power := COALESCE(v_challenger.attack, 10) + COALESCE(v_challenger.defense, 10);
  END IF;
  IF v_def_power <= 0 THEN
    v_def_power := COALESCE(v_defender.attack, 10) + COALESCE(v_defender.defense, 10);
  END IF;
  IF COALESCE(v_challenger.character_class, '') = 'shadow' THEN v_att_power := v_att_power * 1.15; END IF;
  IF COALESCE(v_defender.character_class, '') = 'shadow' THEN v_def_power := v_def_power * 1.15; END IF;

  IF v_cfg.power_band_pct > 0 THEN
    IF abs(v_att_power - v_def_power)
       > GREATEST(v_def_power, 1) * v_cfg.power_band_pct THEN
      RETURN jsonb_build_object('success', false, 'error', 'Güç farkı çok yüksek (±30%).');
    END IF;
  END IF;

  UPDATE public.users
  SET gold = gold - v_cfg.challenge_gold_cost
  WHERE auth_id = v_me AND gold >= v_cfg.challenge_gold_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altın düşülemedi.');
  END IF;

  PERFORM public.dungeon_siege_notify(
    v_slot.holder_id,
    'slot_challenged',
    'Kuşatma meydan okuması',
    v_ch_name || ' slotuna meydan okudu.',
    jsonb_build_object('slot_id', p_slot_id, 'dungeon_id', v_slot.dungeon_id, 'challenger_id', v_me)
  );

  v_win_chance := v_att_power / NULLIF(v_att_power + v_def_power, 0);
  IF v_win_chance IS NULL THEN v_win_chance := 0.5; END IF;

  IF random() <= v_win_chance THEN
    v_winner_id := v_me;
    v_loser_id := v_slot.holder_id;
    v_ch_rating := 15 + floor(random() * 10)::INT;
    v_tg_rating := -(10 + floor(random() * 5)::INT);
  ELSE
    v_winner_id := v_slot.holder_id;
    v_loser_id := v_me;
    v_ch_rating := -(10 + floor(random() * 5)::INT);
    v_tg_rating := 15 + floor(random() * 10)::INT;
  END IF;

  UPDATE public.users SET
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_ch_rating),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_me THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_me THEN 1 ELSE 0 END
  WHERE auth_id = v_me;

  UPDATE public.users SET
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_tg_rating),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_slot.holder_id THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_slot.holder_id THEN 1 ELSE 0 END
  WHERE auth_id = v_slot.holder_id;

  IF v_winner_id = v_me THEN
    UPDATE public.dungeon_siege_slots
    SET holder_id = v_me,
        guild_id = v_challenger.guild_id,
        claimed_at = now(),
        expires_at = now() + make_interval(mins => v_cfg.slot_duration_minutes),
        last_active_at = now()
    WHERE id = p_slot_id;

    PERFORM public.dungeon_siege_apply_ban(
      v_loser_id, v_slot.dungeon_id, v_cfg.ban_duration_minutes, 'siege_challenge_loss'
    );

    PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 25, p_challenges_won => 1);
  ELSE
    PERFORM public.dungeon_siege_apply_ban(
      v_loser_id, v_slot.dungeon_id, v_cfg.ban_duration_minutes, 'siege_challenge_loss'
    );
  END IF;

  PERFORM public.dungeon_siege_notify(
    v_slot.holder_id,
    'challenge_result',
    CASE WHEN v_winner_id = v_slot.holder_id THEN 'Meydan okumayı savuşturdun' ELSE 'Slot kaybettin' END,
    CASE WHEN v_winner_id = v_slot.holder_id
      THEN v_ch_name || ' ile düelloda kazandın.'
      ELSE v_ch_name || ' slotunu aldı.'
    END,
    jsonb_build_object('dungeon_id', v_slot.dungeon_id, 'winner_id', v_winner_id)
  );

  PERFORM public.dungeon_siege_notify(
    v_me,
    'challenge_result',
    CASE WHEN v_winner_id = v_me THEN 'Meydan okumayı kazandın' ELSE 'Meydan okumayı kaybettin' END,
    CASE WHEN v_winner_id = v_me
      THEN v_def_name || ' slotunu aldın.'
      ELSE v_def_name || ' seni yendi. ' || v_cfg.ban_duration_minutes || ' dk ban.'
    END,
    jsonb_build_object('dungeon_id', v_slot.dungeon_id, 'winner_id', v_winner_id)
  );

  v_hold := public.dungeon_siege_active_hold(v_slot.session_id);

  IF v_hold.id IS NOT NULL
     AND v_winner_id = v_me
     AND v_challenger.guild_id IS NOT NULL
     AND v_challenger.guild_id IS DISTINCT FROM v_hold.guild_id
     AND v_defender.guild_id = v_hold.guild_id THEN
    UPDATE public.dungeon_siege_holds
    SET break_progress = break_progress + 1
    WHERE id = v_hold.id
    RETURNING * INTO v_hold;

    IF v_hold.break_progress >= v_cfg.hold_break_wins_required THEN
      UPDATE public.dungeon_siege_holds
      SET is_active = false,
          broken_at = now(),
          ended_at = now()
      WHERE id = v_hold.id;

      v_hold_broken := true;

      PERFORM public.dungeon_siege_notify_hold_guild(
        v_slot.session_id,
        v_hold.guild_id,
        'hold_broken',
        'Lonca hold kırıldı',
        v_slot.dungeon_id || ' kuşatmasında hold''unuz kırıldı.',
        jsonb_build_object('session_id', v_slot.session_id, 'dungeon_id', v_slot.dungeon_id)
      );

      PERFORM public.dungeon_siege_notify(
        v_me,
        'hold_break_success',
        'Hold kırıldı',
        v_slot.dungeon_id || ' kuşatmasında rakip lonca hold''unu kırdın.',
        jsonb_build_object('session_id', v_slot.session_id, 'dungeon_id', v_slot.dungeon_id)
      );
    END IF;
  END IF;

  INSERT INTO public.dungeon_siege_challenges (
    slot_id, session_id, dungeon_id,
    challenger_id, defender_id,
    status, winner_id, gold_spent, resolved_at
  ) VALUES (
    p_slot_id, v_slot.session_id, v_slot.dungeon_id,
    v_me, v_slot.holder_id,
    'resolved', v_winner_id, v_cfg.challenge_gold_cost, now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'winner_id', v_winner_id,
    'you_won', v_winner_id = v_me,
    'gold_spent', v_cfg.challenge_gold_cost,
    'ban_minutes', v_cfg.ban_duration_minutes,
    'hold_broken', v_hold_broken,
    'hold_break_progress', CASE WHEN v_hold.id IS NOT NULL THEN v_hold.break_progress ELSE NULL END,
    'message', CASE
      WHEN v_winner_id = v_me AND v_hold_broken THEN 'Kazandın! Rakip lonca hold''u kırıldı.'
      WHEN v_winner_id = v_me THEN 'Kazandın! Slot senin.'
      ELSE 'Kaybettin. Bu zindandan banlandın.'
    END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.start_siege_guild_hold(p_dungeon_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_player record;
  v_cfg public.dungeon_siege_config;
  v_session_id uuid;
  v_guild_slots integer;
  v_existing public.dungeon_siege_holds;
  v_new_hold_id uuid;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = v_me;

  IF v_player.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsin.');
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_session_id := public.dungeon_siege_ensure_session(p_dungeon_id);

  IF v_session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum oluşturulamadı.');
  END IF;

  v_existing := public.dungeon_siege_active_hold(v_session_id);
  IF v_existing.id IS NOT NULL THEN
    IF v_existing.guild_id = v_player.guild_id THEN
      RETURN jsonb_build_object(
        'success', true,
        'hold_id', v_existing.id,
        'message', 'Loncanın hold''u zaten aktif.',
        'hold', public.dungeon_siege_hold_json(v_session_id)
      );
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'Başka lonca hold tutuyor.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.dungeon_siege_holds h
    JOIN public.dungeon_siege_sessions sess ON sess.id = h.session_id
    WHERE sess.dungeon_id = p_dungeon_id
      AND h.guild_id = v_player.guild_id
      AND h.broken_at IS NOT NULL
      AND h.broken_at > now() - make_interval(mins => v_cfg.hold_rehold_cooldown_minutes)
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Hold kırıldıktan sonra %s dk beklemen gerek.', v_cfg.hold_rehold_cooldown_minutes)
    );
  END IF;

  v_guild_slots := public.dungeon_siege_count_guild_slots(v_session_id, v_player.guild_id);

  IF v_guild_slots < v_cfg.hold_min_members THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Hold için en az %s lonca üyesi slot tutmalı.', v_cfg.hold_min_members),
      'guild_slots', v_guild_slots,
      'required', v_cfg.hold_min_members
    );
  END IF;

  BEGIN
    INSERT INTO public.dungeon_siege_holds (session_id, guild_id, started_by)
    VALUES (v_session_id, v_player.guild_id, v_me)
    RETURNING id INTO v_new_hold_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hold zaten başlatıldı.');
  END;

  PERFORM public.dungeon_siege_notify_hold_guild(
    v_session_id,
    v_player.guild_id,
    'hold_started',
    'Lonca hold başladı',
    p_dungeon_id || ' kuşatmasında lonca hold aktif.',
    jsonb_build_object('dungeon_id', p_dungeon_id, 'hold_id', v_new_hold_id)
  );

  PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 50);

  RETURN jsonb_build_object(
    'success', true,
    'hold_id', v_new_hold_id,
    'message', format('Lonca hold başladı! +%s%% ek bonus.', round(v_cfg.hold_bonus_pct * 100)),
    'hold', public.dungeon_siege_hold_json(v_session_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.release_siege_slot(p_slot_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_slot record;
  v_dungeon_id text;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT s.*, sess.dungeon_id
  INTO v_slot
  FROM public.dungeon_siege_slots s
  JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
  WHERE s.id = p_slot_id
  FOR UPDATE OF s;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Slot bulunamadı.');
  END IF;

  v_dungeon_id := v_slot.dungeon_id;

  IF v_slot.holder_id IS DISTINCT FROM v_me THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu slot sana ait değil.');
  END IF;

  UPDATE public.dungeon_siege_slots
  SET holder_id = NULL,
      guild_id = NULL,
      claimed_at = NULL,
      expires_at = NULL,
      last_active_at = NULL
  WHERE id = p_slot_id;

  PERFORM public.dungeon_siege_cleanup();

  RETURN jsonb_build_object('success', true, 'message', 'Slot bırakıldı.');
END;
$$;

CREATE OR REPLACE FUNCTION public.get_dungeon_siege_hub()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status jsonb;
  v_recent jsonb;
  v_leaderboard jsonb;
  v_territories jsonb;
  v_week text := public.dungeon_siege_week_key();
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_status := public.get_dungeon_siege_status(NULL);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'dungeon_id', c.dungeon_id,
    'challenger_name', COALESCE(uc.display_name, uc.username, '—'),
    'defender_name', COALESCE(ud.display_name, ud.username, '—'),
    'winner_name', COALESCE(uw.display_name, uw.username, '—'),
    'you_were_involved', auth.uid() IN (c.challenger_id, c.defender_id),
    'resolved_at', c.resolved_at
  ) ORDER BY c.resolved_at DESC), '[]'::jsonb)
  INTO v_recent
  FROM (
    SELECT c.*
    FROM public.dungeon_siege_challenges c
    WHERE c.status = 'resolved'
      AND c.resolved_at > now() - interval '24 hours'
    ORDER BY c.resolved_at DESC
    LIMIT 30
  ) c
  LEFT JOIN public.users uc ON uc.auth_id = c.challenger_id
  LEFT JOIN public.users ud ON ud.auth_id = c.defender_id
  LEFT JOIN public.users uw ON uw.auth_id = c.winner_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'rank', s.row_number,
    'player_id', s.player_id,
    'player_name', COALESCE(u.display_name, u.username, '—'),
    'guild_name', g.name,
    'points', s.points,
    'challenges_won', s.challenges_won,
    'slot_minutes', s.slot_minutes
  ) ORDER BY s.row_number), '[]'::jsonb)
  INTO v_leaderboard
  FROM (
    SELECT
      player_id,
      points,
      challenges_won,
      slot_minutes,
      ROW_NUMBER() OVER (ORDER BY points DESC, challenges_won DESC) AS row_number
    FROM public.dungeon_siege_weekly_scores
    WHERE week_key = v_week
    ORDER BY points DESC, challenges_won DESC
    LIMIT 20
  ) s
  LEFT JOIN public.users u ON u.auth_id = s.player_id
  LEFT JOIN public.guilds g ON g.id = u.guild_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'zone_number', t.zone_number,
    'territory_id', t.id,
    'territory_name', t.name,
    'owner_guild_id', t.owner_guild_id,
    'owner_guild_name', COALESCE(g.name, 'Sahipsiz'),
    'siege_dungeon_id', CASE t.zone_number
      WHEN 1 THEN 'dng_010'
      WHEN 2 THEN 'dng_020'
      WHEN 3 THEN 'dng_030'
      WHEN 4 THEN 'dng_040'
      WHEN 5 THEN 'dng_050'
      WHEN 6 THEN 'dng_060'
      WHEN 7 THEN 'dng_065'
      ELSE NULL
    END
  ) ORDER BY t.zone_number), '[]'::jsonb)
  INTO v_territories
  FROM public.guild_war_territories t
  LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
  WHERE t.zone_number IS NOT NULL;

  RETURN jsonb_build_object(
    'week_key', v_week,
    'status', v_status,
    'recent_challenges', COALESCE(v_recent, '[]'::jsonb),
    'leaderboard', COALESCE(v_leaderboard, '[]'::jsonb),
    'territories', COALESCE(v_territories, '[]'::jsonb)
  );
END;
$$;

DROP FUNCTION IF EXISTS public.set_dungeon_siege_config(boolean, integer, integer, integer, integer, bigint, integer, numeric, numeric, numeric, numeric, jsonb);

GRANT EXECUTE ON FUNCTION public.set_dungeon_siege_config(
  boolean, integer, integer, integer, integer, bigint, integer,
  numeric, numeric, numeric, numeric, jsonb,
  integer, numeric, integer, integer, integer, integer, text, text[]
) TO service_role;

GRANT EXECUTE ON FUNCTION public.dungeon_siege_apply_ban(uuid, text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dungeon_siege_notify_hold_guild(uuid, uuid, text, text, text, jsonb) TO authenticated;

COMMIT;
