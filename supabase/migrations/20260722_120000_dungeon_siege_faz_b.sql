-- ============================================================
-- Zindan Kuşatması — Faz B (lonca hold, bölge rezerv, hub, bildirim, sıralama)
-- Geri alma: supabase/manual_rollbacks/20260722_120001_dungeon_siege_faz_b_rollback.sql
-- ============================================================

BEGIN;

-- ── Config extensions ───────────────────────────────────────
ALTER TABLE public.dungeon_siege_config
  ADD COLUMN IF NOT EXISTS hold_min_members integer NOT NULL DEFAULT 3
    CHECK (hold_min_members BETWEEN 2 AND 12),
  ADD COLUMN IF NOT EXISTS hold_bonus_pct numeric NOT NULL DEFAULT 0.15
    CHECK (hold_bonus_pct >= 0 AND hold_bonus_pct <= 2),
  ADD COLUMN IF NOT EXISTS hold_break_wins_required integer NOT NULL DEFAULT 3
    CHECK (hold_break_wins_required BETWEEN 1 AND 10),
  ADD COLUMN IF NOT EXISTS territory_reserve_slot_count integer NOT NULL DEFAULT 1
    CHECK (territory_reserve_slot_count BETWEEN 0 AND 5);

-- Bölge ↔ zone eşlemesi (seed id'leri)
UPDATE public.guild_war_territories
SET zone_number = CASE id::text
  WHEN '00000000-0000-0000-0000-000000030001' THEN 1
  WHEN '00000000-0000-0000-0000-000000030002' THEN 2
  WHEN '00000000-0000-0000-0000-000000030003' THEN 3
  WHEN '00000000-0000-0000-0000-000000030004' THEN 4
  ELSE zone_number
END
WHERE id IN (
  '00000000-0000-0000-0000-000000030001',
  '00000000-0000-0000-0000-000000030002',
  '00000000-0000-0000-0000-000000030003',
  '00000000-0000-0000-0000-000000030004'
);

-- ── Faz B tabloları ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.dungeon_siege_holds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.dungeon_siege_sessions(id) ON DELETE CASCADE,
  guild_id uuid NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  started_by uuid REFERENCES public.users(auth_id) ON DELETE SET NULL,
  break_progress integer NOT NULL DEFAULT 0 CHECK (break_progress >= 0),
  is_active boolean NOT NULL DEFAULT true,
  started_at timestamptz NOT NULL DEFAULT now(),
  broken_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_dungeon_siege_holds_active_session
  ON public.dungeon_siege_holds (session_id)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_holds_guild
  ON public.dungeon_siege_holds (guild_id, is_active, started_at DESC);

CREATE TABLE IF NOT EXISTS public.dungeon_siege_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  notif_type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_notifications_player
  ON public.dungeon_siege_notifications (player_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.dungeon_siege_weekly_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_key text NOT NULL,
  guild_id uuid REFERENCES public.guilds(id) ON DELETE SET NULL,
  player_id uuid NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  points integer NOT NULL DEFAULT 0 CHECK (points >= 0),
  slot_minutes integer NOT NULL DEFAULT 0 CHECK (slot_minutes >= 0),
  challenges_won integer NOT NULL DEFAULT 0 CHECK (challenges_won >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (week_key, player_id)
);

CREATE INDEX IF NOT EXISTS idx_dungeon_siege_weekly_scores_week
  ON public.dungeon_siege_weekly_scores (week_key, points DESC);

ALTER TABLE public.dungeon_siege_holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_siege_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dungeon_siege_weekly_scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read siege holds" ON public.dungeon_siege_holds;
CREATE POLICY "Anyone can read siege holds"
  ON public.dungeon_siege_holds FOR SELECT USING (true);

DROP POLICY IF EXISTS "Players read own siege notifications" ON public.dungeon_siege_notifications;
CREATE POLICY "Players read own siege notifications"
  ON public.dungeon_siege_notifications FOR SELECT
  USING (player_id = auth.uid());

DROP POLICY IF EXISTS "Anyone can read siege weekly scores" ON public.dungeon_siege_weekly_scores;
CREATE POLICY "Anyone can read siege weekly scores"
  ON public.dungeon_siege_weekly_scores FOR SELECT USING (true);

-- ── Helpers ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.dungeon_siege_week_key(p_at timestamptz DEFAULT now())
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT to_char(timezone('Europe/Istanbul', p_at), 'IYYY-"W"IW');
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_territory_owner_for_zone(p_zone_number integer)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT t.owner_guild_id
  FROM public.guild_war_territories t
  WHERE t.zone_number = p_zone_number
  ORDER BY t.created_at NULLS LAST
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_count_guild_slots(
  p_session_id uuid,
  p_guild_id uuid
)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COUNT(*)::integer
  FROM public.dungeon_siege_slots s
  WHERE s.session_id = p_session_id
    AND s.guild_id = p_guild_id
    AND s.holder_id IS NOT NULL
    AND (s.expires_at IS NULL OR s.expires_at > now());
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_active_hold(p_session_id uuid)
RETURNS public.dungeon_siege_holds
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT h.*
  FROM public.dungeon_siege_holds h
  WHERE h.session_id = p_session_id
    AND h.is_active = true
  ORDER BY h.started_at DESC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_notify(
  p_player_id uuid,
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
BEGIN
  IF p_player_id IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.dungeon_siege_notifications (
    player_id, notif_type, title, body, payload
  ) VALUES (
    p_player_id, p_type, p_title, p_body, COALESCE(p_payload, '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_add_weekly_score(
  p_player_id uuid,
  p_points integer DEFAULT 0,
  p_slot_minutes integer DEFAULT 0,
  p_challenges_won integer DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_week text := public.dungeon_siege_week_key();
  v_guild_id uuid;
BEGIN
  IF p_player_id IS NULL THEN
    RETURN;
  END IF;

  SELECT guild_id INTO v_guild_id
  FROM public.users
  WHERE auth_id = p_player_id;

  INSERT INTO public.dungeon_siege_weekly_scores (
    week_key, guild_id, player_id, points, slot_minutes, challenges_won
  ) VALUES (
    v_week, v_guild_id, p_player_id,
    GREATEST(0, COALESCE(p_points, 0)),
    GREATEST(0, COALESCE(p_slot_minutes, 0)),
    GREATEST(0, COALESCE(p_challenges_won, 0))
  )
  ON CONFLICT (week_key, player_id) DO UPDATE
  SET
    guild_id = EXCLUDED.guild_id,
    points = public.dungeon_siege_weekly_scores.points + EXCLUDED.points,
    slot_minutes = public.dungeon_siege_weekly_scores.slot_minutes + EXCLUDED.slot_minutes,
    challenges_won = public.dungeon_siege_weekly_scores.challenges_won + EXCLUDED.challenges_won,
    updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.dungeon_siege_hold_json(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hold public.dungeon_siege_holds;
  v_cfg public.dungeon_siege_config;
BEGIN
  v_hold := public.dungeon_siege_active_hold(p_session_id);
  IF v_hold.id IS NULL THEN
    RETURN NULL;
  END IF;

  v_cfg := public.dungeon_siege_get_config();

  RETURN jsonb_build_object(
    'hold_id', v_hold.id,
    'guild_id', v_hold.guild_id,
    'guild_name', (SELECT name FROM public.guilds WHERE id = v_hold.guild_id),
    'break_progress', v_hold.break_progress,
    'break_required', v_cfg.hold_break_wins_required,
    'started_at', v_hold.started_at,
    'member_slots', public.dungeon_siege_count_guild_slots(p_session_id, v_hold.guild_id)
  );
END;
$$;

-- ── Reward multipliers (+ hold bonus) ───────────────────────
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

-- ── claim_siege_slot (+ bölge rezerv slot) ───────────────────
CREATE OR REPLACE FUNCTION public.claim_siege_slot(p_dungeon_id text)
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
  v_slot record;
  v_zone integer;
  v_territory_owner uuid;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  IF public.dungeon_siege_is_banned(v_me, p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindandan banlısın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastane/cezaevinde slot alamazsın.');
  END IF;

  IF public.dungeon_siege_player_holds_any_slot(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir kuşatma slotu tutuyorsun.');
  END IF;

  IF public.dungeon_siege_player_has_slot(v_me, p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindanda zaten slot tutuyorsun.');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = v_me;
  v_cfg := public.dungeon_siege_get_config();
  v_session_id := public.dungeon_siege_ensure_session(p_dungeon_id);
  v_zone := public.dungeon_siege_zone_for_dungeon(p_dungeon_id);
  v_territory_owner := public.dungeon_siege_territory_owner_for_zone(v_zone);

  SELECT * INTO v_slot
  FROM public.dungeon_siege_slots s
  WHERE s.session_id = v_session_id
    AND s.holder_id IS NULL
    AND (
      v_cfg.territory_reserve_slot_count <= 0
      OR v_territory_owner IS NULL
      OR s.slot_number > v_cfg.territory_reserve_slot_count
      OR v_player.guild_id IS NOT DISTINCT FROM v_territory_owner
    )
  ORDER BY s.slot_number
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN v_territory_owner IS NOT NULL
             AND v_player.guild_id IS DISTINCT FROM v_territory_owner
        THEN 'Bölge sahibi lonca rezerv slotları dolu. Meydan oku.'
        ELSE 'Boş slot yok. Meydan oku.'
      END
    );
  END IF;

  UPDATE public.dungeon_siege_slots
  SET holder_id = v_me,
      guild_id = v_player.guild_id,
      claimed_at = now(),
      expires_at = now() + make_interval(mins => v_cfg.slot_duration_minutes),
      last_active_at = now()
  WHERE id = v_slot.id;

  PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 5, p_slot_minutes => 0);

  RETURN jsonb_build_object(
    'success', true,
    'slot_id', v_slot.id,
    'slot_number', v_slot.slot_number,
    'expires_at', now() + make_interval(mins => v_cfg.slot_duration_minutes),
    'territory_reserved', v_territory_owner IS NOT NULL
      AND v_slot.slot_number <= v_cfg.territory_reserve_slot_count,
    'message', 'Slot alındı! Bonus farm başladı.'
  );
END;
$$;

-- ── challenge_siege_slot (+ hold kırma + bildirim + puan) ───
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
  v_defender_name text;
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

  v_defender_name := COALESCE(v_defender.display_name, v_defender.username, 'Rakip');

  IF v_challenger.guild_id IS NOT NULL AND v_challenger.guild_id = v_defender.guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesine meydan okuyamazsın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_slot.holder_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakip hastane/cezaevinde.');
  END IF;

  IF v_challenger.gold < v_cfg.challenge_gold_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın.');
  END IF;

  IF v_cfg.power_band_pct > 0 THEN
    IF abs(
      COALESCE(public.calculate_user_total_power(v_me), v_challenger.power, 0)
      - COALESCE(public.calculate_user_total_power(v_slot.holder_id), v_defender.power, 0)
    )::numeric
       > GREATEST(COALESCE(public.calculate_user_total_power(v_slot.holder_id), v_defender.power, 1), 1)
         * v_cfg.power_band_pct THEN
      RETURN jsonb_build_object('success', false, 'error', 'Güç farkı çok yüksek (±30%).');
    END IF;
  END IF;

  PERFORM public.dungeon_siege_notify(
    v_slot.holder_id,
    'slot_challenged',
    'Kuşatma meydan okuması',
    COALESCE(v_challenger.display_name, v_challenger.username, 'Bir oyuncu')
      || ' slotuna meydan okudu.',
    jsonb_build_object('slot_id', p_slot_id, 'dungeon_id', v_slot.dungeon_id, 'challenger_id', v_me)
  );

  UPDATE public.users
  SET gold = gold - v_cfg.challenge_gold_cost
  WHERE auth_id = v_me AND gold >= v_cfg.challenge_gold_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Altın düşülemedi.');
  END IF;

  v_att_power := COALESCE(v_challenger.attack, 10) + COALESCE(v_challenger.defense, 10);
  v_def_power := COALESCE(v_defender.attack, 10) + COALESCE(v_defender.defense, 10);
  IF COALESCE(v_challenger.character_class, '') = 'shadow' THEN v_att_power := v_att_power * 1.15; END IF;
  IF COALESCE(v_defender.character_class, '') = 'shadow' THEN v_def_power := v_def_power * 1.15; END IF;

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

    INSERT INTO public.dungeon_siege_bans (player_id, dungeon_id, banned_until, reason)
    VALUES (
      v_loser_id,
      v_slot.dungeon_id,
      now() + make_interval(mins => v_cfg.ban_duration_minutes),
      'siege_challenge_loss'
    );

    PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 25, p_challenges_won => 1);
  ELSE
    INSERT INTO public.dungeon_siege_bans (player_id, dungeon_id, banned_until, reason)
    VALUES (
      v_loser_id,
      v_slot.dungeon_id,
      now() + make_interval(mins => v_cfg.ban_duration_minutes),
      'siege_challenge_loss'
    );
  END IF;

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

      PERFORM public.dungeon_siege_notify(
        v_me,
        'hold_broken',
        'Lonca hold kırıldı',
        v_slot.dungeon_id || ' kuşatmasında rakip lonca hold''u kırdı.',
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

-- ── get_dungeon_siege_config (+ Faz B alanları) ─────────────
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
    'timezone', v_cfg.timezone,
    'prime_windows', v_cfg.prime_windows,
    'siege_dungeon_ids', v_cfg.siege_dungeon_ids,
    'in_prime_window', public.dungeon_siege_in_prime_window()
  );
END;
$$;

-- ── get_dungeon_siege_status (+ hold + territory) ────────────
CREATE OR REPLACE FUNCTION public.get_dungeon_siege_status(p_dungeon_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_cfg public.dungeon_siege_config;
  v_sessions jsonb := '[]'::jsonb;
  v_my_slot jsonb := NULL;
  v_my_guild_id uuid;
BEGIN
  PERFORM public.dungeon_siege_cleanup();
  v_cfg := public.dungeon_siege_get_config();

  IF v_me IS NOT NULL THEN
    SELECT guild_id INTO v_my_guild_id FROM public.users WHERE auth_id = v_me;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'session_id', sess.id,
    'dungeon_id', sess.dungeon_id,
    'zone_number', sess.zone_number,
    'ends_at', sess.ends_at,
    'territory_owner_guild_id', public.dungeon_siege_territory_owner_for_zone(sess.zone_number),
    'territory_owner_guild_name', (
      SELECT g.name
      FROM public.guild_war_territories t
      LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
      WHERE t.zone_number = sess.zone_number
      LIMIT 1
    ),
    'guild_slots', CASE
      WHEN v_my_guild_id IS NULL THEN 0
      ELSE public.dungeon_siege_count_guild_slots(sess.id, v_my_guild_id)
    END,
    'hold', public.dungeon_siege_hold_json(sess.id),
    'slots', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'slot_id', s.id,
        'slot_number', s.slot_number,
        'holder_id', s.holder_id,
        'holder_name', COALESCE(u.display_name, u.username, '—'),
        'holder_power', COALESCE(u.power, 0),
        'guild_id', s.guild_id,
        'guild_name', g.name,
        'expires_at', s.expires_at,
        'last_active_at', s.last_active_at,
        'is_mine', s.holder_id = v_me,
        'is_territory_reserved', s.slot_number <= v_cfg.territory_reserve_slot_count
          AND public.dungeon_siege_territory_owner_for_zone(sess.zone_number) IS NOT NULL
      ) ORDER BY s.slot_number), '[]'::jsonb)
      FROM public.dungeon_siege_slots s
      LEFT JOIN public.users u ON u.auth_id = s.holder_id
      LEFT JOIN public.guilds g ON g.id = s.guild_id
      WHERE s.session_id = sess.id
    )
  ) ORDER BY sess.zone_number), '[]'::jsonb)
  INTO v_sessions
  FROM public.dungeon_siege_sessions sess
  WHERE sess.is_active = true
    AND sess.ends_at > now()
    AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id);

  IF v_me IS NOT NULL THEN
    SELECT jsonb_build_object(
      'slot_id', s.id,
      'slot_number', s.slot_number,
      'dungeon_id', sess.dungeon_id,
      'expires_at', s.expires_at
    )
    INTO v_my_slot
    FROM public.dungeon_siege_slots s
    JOIN public.dungeon_siege_sessions sess ON sess.id = s.session_id
    WHERE s.holder_id = v_me
      AND sess.is_active = true
      AND sess.ends_at > now()
      AND (p_dungeon_id IS NULL OR sess.dungeon_id = p_dungeon_id)
    ORDER BY s.claimed_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'enabled', v_cfg.is_enabled,
    'in_prime_window', public.dungeon_siege_in_prime_window(),
    'siege_active', v_cfg.is_enabled AND public.dungeon_siege_in_prime_window(),
    'sessions', v_sessions,
    'my_slot', v_my_slot,
    'is_banned', CASE
      WHEN v_me IS NULL OR p_dungeon_id IS NULL THEN false
      ELSE public.dungeon_siege_is_banned(v_me, p_dungeon_id)
    END,
    'config', public.get_dungeon_siege_config()
  );
END;
$$;

-- ── start_siege_guild_hold ──────────────────────────────────
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

  v_guild_slots := public.dungeon_siege_count_guild_slots(v_session_id, v_player.guild_id);

  IF v_guild_slots < v_cfg.hold_min_members THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Hold için en az %s lonca üyesi slot tutmalı.', v_cfg.hold_min_members),
      'guild_slots', v_guild_slots,
      'required', v_cfg.hold_min_members
    );
  END IF;

  INSERT INTO public.dungeon_siege_holds (session_id, guild_id, started_by)
  VALUES (v_session_id, v_player.guild_id, v_me);

  PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 50);

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Lonca hold başladı! +%s%% ek bonus.', round(v_cfg.hold_bonus_pct * 100)),
    'hold', public.dungeon_siege_hold_json(v_session_id)
  );
END;
$$;

-- ── Hub + leaderboard + notifications ───────────────────────
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
  FROM public.dungeon_siege_challenges c
  LEFT JOIN public.users uc ON uc.auth_id = c.challenger_id
  LEFT JOIN public.users ud ON ud.auth_id = c.defender_id
  LEFT JOIN public.users uw ON uw.auth_id = c.winner_id
  WHERE c.status = 'resolved'
    AND c.resolved_at > now() - interval '24 hours'
  LIMIT 30;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'rank', row_number,
    'player_id', s.player_id,
    'player_name', COALESCE(u.display_name, u.username, '—'),
    'guild_name', g.name,
    'points', s.points,
    'challenges_won', s.challenges_won,
    'slot_minutes', s.slot_minutes
  ) ORDER BY row_number), '[]'::jsonb)
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
    'territory_name', t.name,
    'owner_guild_id', t.owner_guild_id,
    'owner_guild_name', COALESCE(g.name, 'Sahipsiz')
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

CREATE OR REPLACE FUNCTION public.get_dungeon_siege_leaderboard(p_limit integer DEFAULT 20)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_week text := public.dungeon_siege_week_key();
  v_rows jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'rank', row_number,
    'player_id', s.player_id,
    'player_name', COALESCE(u.display_name, u.username, '—'),
    'guild_name', g.name,
    'points', s.points,
    'challenges_won', s.challenges_won,
    'slot_minutes', s.slot_minutes
  ) ORDER BY row_number), '[]'::jsonb)
  INTO v_rows
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
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 100))
  ) s
  LEFT JOIN public.users u ON u.auth_id = s.player_id
  LEFT JOIN public.guilds g ON g.id = u.guild_id;

  RETURN jsonb_build_object('week_key', v_week, 'entries', COALESCE(v_rows, '[]'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.get_dungeon_siege_notifications(p_limit integer DEFAULT 20)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_rows jsonb;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', n.id,
    'type', n.notif_type,
    'title', n.title,
    'body', n.body,
    'payload', n.payload,
    'read_at', n.read_at,
    'created_at', n.created_at,
    'is_unread', n.read_at IS NULL
  ) ORDER BY n.created_at DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT *
    FROM public.dungeon_siege_notifications
    WHERE player_id = v_me
    ORDER BY created_at DESC
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 50))
  ) n;

  RETURN jsonb_build_object(
    'success', true,
    'notifications', COALESCE(v_rows, '[]'::jsonb),
    'unread_count', (
      SELECT COUNT(*)::integer
      FROM public.dungeon_siege_notifications
      WHERE player_id = v_me AND read_at IS NULL
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_siege_notifications_read(p_notification_ids uuid[] DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_notification_ids IS NULL OR array_length(p_notification_ids, 1) IS NULL THEN
    UPDATE public.dungeon_siege_notifications
    SET read_at = now()
    WHERE player_id = v_me AND read_at IS NULL;
  ELSE
    UPDATE public.dungeon_siege_notifications
    SET read_at = now()
    WHERE player_id = v_me
      AND id = ANY(p_notification_ids)
      AND read_at IS NULL;
  END IF;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  RETURN jsonb_build_object('success', true, 'marked_read', v_count);
END;
$$;

-- ── get_guild_war_territories (+ zone_number) ───────────────
CREATE OR REPLACE FUNCTION public.get_guild_war_territories()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      t.id,
      t.name,
      t.owner_guild_id,
      COALESCE(g.name, 'Sahipsiz') AS "owner_guild",
      t.defense_power,
      t.base_defense_power,
      t.defense_line_level,
      t.reward,
      COALESCE(t.trade_income, 0) AS trade_income,
      t.zone_number
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    ORDER BY t.zone_number NULLS LAST, t.name
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_siege_guild_hold(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dungeon_siege_hub() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dungeon_siege_leaderboard(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dungeon_siege_notifications(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_siege_notifications_read(uuid[]) TO authenticated;

COMMIT;
