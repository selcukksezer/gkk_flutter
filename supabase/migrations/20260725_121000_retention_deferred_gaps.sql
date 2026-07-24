-- Retention plan deferred gaps:
-- 1) claim_codex_milestone → badge / frame / title grants
-- 2) get_codex_luck_bonus wired into enter_dungeon loot roll
-- 3) Nemesis revenge gold bonus (1/day, 1000–5000g)
-- 4) Night market QA force-open column on schedule

BEGIN;

-- ── Codex milestone items ─────────────────────────────────────────────────────
INSERT INTO public.items (id, name, type, description, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable)
VALUES
  (
    'badge_codex_bronze',
    'Kodex Kaşifi Rozeti',
    'cosmetic',
    'Koleksiyon Kodex — 10 keşif ödülü.',
    'rare',
    0,
    0,
    false,
    false
  ),
  (
    'badge_codex_gold',
    'Kodex Ustası Rozeti',
    'cosmetic',
    'Koleksiyon Kodex — 100 keşif ödülü.',
    'legendary',
    0,
    0,
    false,
    false
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  type = EXCLUDED.type,
  rarity = EXCLUDED.rarity;

CREATE OR REPLACE FUNCTION public.ensure_codex_badge_item(p_kind TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id TEXT;
BEGIN
  v_id := CASE p_kind
    WHEN 'bronze' THEN 'badge_codex_bronze'
    WHEN 'gold' THEN 'badge_codex_gold'
    ELSE NULL
  END;

  IF v_id IS NULL THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.items (id, name, type, description, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable)
  VALUES (
    v_id,
    CASE p_kind
      WHEN 'bronze' THEN 'Kodex Kaşifi Rozeti'
      ELSE 'Kodex Ustası Rozeti'
    END,
    'cosmetic',
    CASE p_kind
      WHEN 'bronze' THEN 'Koleksiyon Kodex — 10 keşif ödülü.'
      ELSE 'Koleksiyon Kodex — 100 keşif ödülü.'
    END,
    CASE p_kind WHEN 'bronze' THEN 'rare' ELSE 'legendary' END,
    0,
    0,
    false,
    false
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._codex_luck_bonus_raw(p_player_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = p_player_id
        AND m.threshold = 50
        AND m.claimed_at IS NOT NULL
    ) THEN 1
    ELSE 0
  END;
$$;

CREATE OR REPLACE FUNCTION public.claim_codex_milestone(p_threshold INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_discovered INT;
  v_item_id TEXT;
  v_added BOOLEAN;
  v_reward TEXT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF p_threshold NOT IN (10, 25, 50, 100) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşik.');
  END IF;

  v_discovered := public._codex_discovered_count(v_user);
  IF v_discovered < p_threshold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Henüz yeterli keşif yok.');
  END IF;

  INSERT INTO public.player_codex_milestones (player_id, threshold, claimed_at)
  VALUES (v_user, p_threshold, now())
  ON CONFLICT (player_id, threshold) DO UPDATE SET claimed_at = COALESCE(player_codex_milestones.claimed_at, now())
  WHERE player_codex_milestones.claimed_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül zaten alındı.');
  END IF;

  v_reward := CASE p_threshold
    WHEN 10 THEN 'bronze_badge'
    WHEN 25 THEN 'frame_unlock'
    WHEN 50 THEN 'loot_luck_plus_one'
    WHEN 100 THEN 'gold_badge_title'
  END;

  IF p_threshold IN (10, 100) THEN
    v_item_id := public.ensure_codex_badge_item(CASE WHEN p_threshold = 10 THEN 'bronze' ELSE 'gold' END);
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu — rozet verilemedi.');
      END IF;
    END IF;
  END IF;

  IF p_threshold = 100 THEN
    UPDATE public.users
    SET cosmetic_title = COALESCE(cosmetic_title, 'kodex_ustasi')
    WHERE auth_id = v_user
      AND (cosmetic_title IS NULL OR cosmetic_title = '');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'threshold', p_threshold,
    'reward', v_reward,
    'item_id', v_item_id,
    'cosmetic_title', CASE WHEN p_threshold = 100 THEN 'kodex_ustasi' ELSE NULL END
  );
END;
$$;

-- ── Night market QA force-open (schedule column) ──────────────────────────────
ALTER TABLE public.night_market_schedule
  ADD COLUMN IF NOT EXISTS qa_force_open BOOLEAN NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public._night_market_window(p_now TIMESTAMPTZ DEFAULT now())
RETURNS TABLE (
  active BOOLEAN,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  seconds_left INTEGER,
  rotation_week DATE
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_sched RECORD;
  v_local TIMESTAMP;
  v_weekday INT;
  v_hour INT;
  v_start_local TIMESTAMP;
  v_end_local TIMESTAMP;
  -- QA: night_market_schedule.qa_force_open = true → Cuma beklemeden pazar açık
  v_qa_force_open BOOLEAN := false;
BEGIN
  SELECT * INTO v_sched FROM public.night_market_schedule WHERE id = 1;
  v_qa_force_open := COALESCE(v_sched.qa_force_open, false);

  v_local := (p_now AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul'));
  v_weekday := EXTRACT(ISODOW FROM v_local)::INT;
  v_hour := EXTRACT(HOUR FROM v_local)::INT;

  v_start_local := date_trunc('day', v_local)
    + make_interval(hours => COALESCE(v_sched.start_hour, 20));
  v_end_local := date_trunc('day', v_local)
    + make_interval(hours => COALESCE(v_sched.end_hour, 22));

  IF v_weekday > COALESCE(v_sched.weekday, 5)
     OR (v_weekday = COALESCE(v_sched.weekday, 5) AND v_hour >= COALESCE(v_sched.end_hour, 22)) THEN
    v_start_local := v_start_local + interval '7 days';
    v_end_local := v_end_local + interval '7 days';
  ELSIF v_weekday < COALESCE(v_sched.weekday, 5)
     OR (v_weekday = COALESCE(v_sched.weekday, 5) AND v_hour < COALESCE(v_sched.start_hour, 20)) THEN
    v_start_local := v_start_local
      - ((v_weekday - COALESCE(v_sched.weekday, 5) + 7) % 7) * interval '1 day';
    v_end_local := v_end_local
      - ((v_weekday - COALESCE(v_sched.weekday, 5) + 7) % 7) * interval '1 day';
  END IF;

  starts_at := v_start_local AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul');
  ends_at := v_end_local AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul');
  rotation_week := date_trunc('week', starts_at)::DATE;

  IF v_qa_force_open THEN
    active := true;
    seconds_left := GREATEST(0, EXTRACT(EPOCH FROM (ends_at - p_now))::INT);
  ELSE
    active := p_now >= starts_at AND p_now < ends_at;
    seconds_left := CASE
      WHEN active THEN GREATEST(0, EXTRACT(EPOCH FROM (ends_at - p_now))::INT)
      WHEN p_now < starts_at THEN GREATEST(0, EXTRACT(EPOCH FROM (starts_at - p_now))::INT)
      ELSE 0
    END;
  END IF;

  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.qa_force_night_market(p_open BOOLEAN DEFAULT true)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.night_market_schedule
  SET qa_force_open = COALESCE(p_open, true)
  WHERE id = 1;

  RETURN jsonb_build_object('success', true, 'qa_force_open', COALESCE(p_open, true));
END;
$$;

REVOKE ALL ON FUNCTION public.qa_force_night_market(BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_force_night_market(BOOLEAN) TO authenticated;

-- ── Nemesis revenge gold on PvP duel win ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public._nemesis_revenge_gold_bonus(
  p_winner_id UUID,
  p_loser_id UUID,
  p_invite_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nemesis_id UUID;
  v_bonus BIGINT;
BEGIN
  IF p_winner_id IS NULL OR p_loser_id IS NULL THEN
    RETURN jsonb_build_object('granted', false);
  END IF;

  PERFORM public.refresh_player_nemesis(p_winner_id);

  SELECT nemesis_id INTO v_nemesis_id
  FROM public.player_nemesis_state
  WHERE player_id = p_winner_id;

  IF v_nemesis_id IS NULL OR v_nemesis_id <> p_loser_id THEN
    RETURN jsonb_build_object('granted', false);
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.nemesis_revenge_log
    WHERE avenger_id = p_winner_id
      AND won = true
      AND created_at >= date_trunc('day', now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul'
  ) THEN
    RETURN jsonb_build_object('granted', false, 'reason', 'daily_cap');
  END IF;

  v_bonus := 1000 + floor(random() * 4001)::BIGINT;

  UPDATE public.users
  SET gold = gold + v_bonus
  WHERE auth_id = p_winner_id;

  INSERT INTO public.nemesis_revenge_log (avenger_id, nemesis_id, invite_id, won)
  VALUES (p_winner_id, p_loser_id, p_invite_id, true);

  RETURN jsonb_build_object('granted', true, 'gold', v_bonus);
END;
$$;

DO $pvp_patch$
DECLARE
  v_def TEXT;
  v_marker TEXT := E'  UPDATE public.pvp_invites\n  SET status = ''accepted'', result = v_result\n  WHERE id = p_invite_id;\n';
  v_block TEXT := E'  -- [GKK_NEMESIS_REVENGE_GOLD_BEGIN]\n  PERFORM public._nemesis_revenge_gold_bonus(v_winner_id, v_loser_id, p_invite_id);\n  -- [GKK_NEMESIS_REVENGE_GOLD_END]\n\n  UPDATE public.pvp_invites\n  SET status = ''accepted'', result = v_result\n  WHERE id = p_invite_id;\n';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'respond_pvp_invite'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'respond_pvp_invite not found; skipping nemesis gold patch';
    RETURN;
  END IF;

  IF position('[GKK_NEMESIS_REVENGE_GOLD_BEGIN]' in v_def) = 0
     AND position(v_marker in v_def) > 0 THEN
    v_def := replace(v_def, v_marker, v_block);
    EXECUTE v_def;
  END IF;
END;
$pvp_patch$;

-- ── enter_dungeon: add codex luck to loot roll ────────────────────────────────
DO $codex_luck_patch$
DECLARE
  v_def TEXT;
  v_marker TEXT := E'    v_luck_for_loot := COALESCE(v_player.luck, 0) + public._monument_loot_luck_bonus(v_monument_level);';
  v_replacement TEXT := E'    v_luck_for_loot := COALESCE(v_player.luck, 0) + public._monument_loot_luck_bonus(v_monument_level) + public._codex_luck_bonus_raw(p_player_id);';
  v_fallback_marker TEXT := E'    v_luck_for_loot := COALESCE(v_player.luck, 0);';
  v_fallback_replacement TEXT := E'    v_luck_for_loot := COALESCE(v_player.luck, 0) + public._codex_luck_bonus_raw(p_player_id);';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'enter_dungeon'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'enter_dungeon not found; skipping codex luck patch';
    RETURN;
  END IF;

  IF position('_codex_luck_bonus_raw' in v_def) = 0 THEN
    IF position(v_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_marker, v_replacement);
    ELSIF position(v_fallback_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_fallback_marker, v_fallback_replacement);
    END IF;
    EXECUTE v_def;
  END IF;
END;
$codex_luck_patch$;

GRANT EXECUTE ON FUNCTION public.ensure_codex_badge_item(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public._nemesis_revenge_gold_bonus(UUID, UUID, UUID) TO authenticated;

COMMIT;
