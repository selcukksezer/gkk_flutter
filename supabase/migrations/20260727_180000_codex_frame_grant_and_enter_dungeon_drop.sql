-- Codex frame@50 grant + backfill; drop enter_dungeon(text);
-- nemesis online notice 1/day; qa_force revoke check.

BEGIN;

-- ── Nemesis: 1 online notice / Istanbul day ───────────────────────────────────
ALTER TABLE public.player_nemesis_state
  ADD COLUMN IF NOT EXISTS last_online_notice_at TIMESTAMPTZ;

-- ── Drop text-only enter_dungeon (uuid+text is canonical; luck/codex live there)
-- Note: pg_get_function_identity_arguments includes names (p_dungeon_id text),
-- so DROP by type signature — do not gate on idargs = 'text'.
DROP FUNCTION IF EXISTS public.enter_dungeon(text);

DO $$
BEGIN
  IF position(
    'discover_codex_entry' IN
    pg_get_functiondef('public.enter_dungeon(uuid, text)'::regprocedure)
  ) = 0 THEN
    RAISE WARNING
      'enter_dungeon(uuid,text) missing discover_codex_entry — re-apply luck/codex patch';
  END IF;
END;
$$;

-- ── claim_codex_milestone: grant avatar_frame='codex' at 50 if empty ──────────
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
  v_gold BIGINT := 0;
  v_gems INT := 0;
  v_reward_label TEXT;
  v_reward_kind TEXT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF p_threshold NOT IN (
    10, 20, 30, 40, 50, 75, 100, 125, 150, 200, 250, 300, 350, 400
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşik.');
  END IF;

  v_discovered := public._codex_discovered_count(v_user);
  IF v_discovered < p_threshold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Henüz yeterli keşif yok.');
  END IF;

  SELECT cfg.gold_amount, cfg.gem_amount, cfg.reward_label, cfg.reward_kind
  INTO v_gold, v_gems, v_reward_label, v_reward_kind
  FROM public._codex_milestone_reward_config(p_threshold) cfg;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül yapılandırması yok.');
  END IF;

  INSERT INTO public.player_codex_milestones (
    player_id, threshold, claimed_at, gold_granted, gems_granted
  )
  VALUES (v_user, p_threshold, now(), COALESCE(v_gold, 0), COALESCE(v_gems, 0))
  ON CONFLICT (player_id, threshold) DO UPDATE
    SET
      claimed_at = COALESCE(player_codex_milestones.claimed_at, now()),
      gold_granted = CASE
        WHEN player_codex_milestones.claimed_at IS NULL
          THEN COALESCE(v_gold, 0)
        ELSE player_codex_milestones.gold_granted
      END,
      gems_granted = CASE
        WHEN player_codex_milestones.claimed_at IS NULL
          THEN COALESCE(v_gems, 0)
        ELSE player_codex_milestones.gems_granted
      END
  WHERE player_codex_milestones.claimed_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül zaten alındı.');
  END IF;

  IF v_gold > 0 OR v_gems > 0 THEN
    UPDATE public.users
    SET
      gold = gold + v_gold,
      gems = gems + v_gems
    WHERE auth_id = v_user;
  END IF;

  IF p_threshold = 10 THEN
    v_item_id := public.ensure_codex_badge_item('bronze');
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
      END IF;
    END IF;
  END IF;

  -- Frame unlock @50: only if player has no frame yet (do not overwrite choice).
  IF p_threshold = 50 THEN
    UPDATE public.users
    SET avatar_frame = COALESCE(NULLIF(avatar_frame, ''), 'codex')
    WHERE auth_id = v_user
      AND (avatar_frame IS NULL OR avatar_frame = '');
  END IF;

  IF p_threshold = 400 THEN
    v_item_id := public.ensure_codex_badge_item('gold');
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
      END IF;
    END IF;

    UPDATE public.users
    SET cosmetic_title = COALESCE(cosmetic_title, 'kodex_ustasi')
    WHERE auth_id = v_user
      AND (cosmetic_title IS NULL OR cosmetic_title = '');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'threshold', p_threshold,
    'reward_gold', v_gold,
    'reward_gems', v_gems,
    'reward_label', v_reward_label,
    'reward_kind', v_reward_kind,
    'milestone_label', v_reward_label,
    'item_id', v_item_id,
    'cosmetic_title', CASE WHEN p_threshold = 400 THEN 'kodex_ustasi' ELSE NULL END
  );
END;
$$;

-- ── claim_all: same frame grant when loop hits 50 ─────────────────────────────
CREATE OR REPLACE FUNCTION public.claim_all_codex_milestones()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_discovered INT;
  v_th INT;
  v_gold BIGINT;
  v_gems INT;
  v_label TEXT;
  v_kind TEXT;
  v_item_id TEXT;
  v_added BOOLEAN;
  v_total_gold BIGINT := 0;
  v_total_gems INT := 0;
  v_count INT := 0;
  v_claimed JSONB := '[]'::JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_discovered := public._codex_discovered_count(v_user);

  FOR v_th IN
    SELECT th FROM public._codex_milestone_thresholds() AS th
    WHERE v_discovered >= th
      AND NOT EXISTS (
        SELECT 1 FROM public.player_codex_milestones m
        WHERE m.player_id = v_user
          AND m.threshold = th
          AND m.claimed_at IS NOT NULL
      )
    ORDER BY th
  LOOP
    SELECT cfg.gold_amount, cfg.gem_amount, cfg.reward_label, cfg.reward_kind
    INTO v_gold, v_gems, v_label, v_kind
    FROM public._codex_milestone_reward_config(v_th) cfg;

    INSERT INTO public.player_codex_milestones (
      player_id, threshold, claimed_at, gold_granted, gems_granted
    )
    VALUES (v_user, v_th, now(), COALESCE(v_gold, 0), COALESCE(v_gems, 0))
    ON CONFLICT (player_id, threshold) DO UPDATE
      SET
        claimed_at = COALESCE(player_codex_milestones.claimed_at, now()),
        gold_granted = CASE
          WHEN player_codex_milestones.claimed_at IS NULL
            THEN COALESCE(v_gold, 0)
          ELSE player_codex_milestones.gold_granted
        END,
        gems_granted = CASE
          WHEN player_codex_milestones.claimed_at IS NULL
            THEN COALESCE(v_gems, 0)
          ELSE player_codex_milestones.gems_granted
        END
    WHERE player_codex_milestones.claimed_at IS NULL;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    IF v_gold > 0 OR v_gems > 0 THEN
      UPDATE public.users
      SET
        gold = gold + v_gold,
        gems = gems + v_gems
      WHERE auth_id = v_user;
    END IF;

    IF v_th = 10 THEN
      v_item_id := public.ensure_codex_badge_item('bronze');
      IF v_item_id IS NOT NULL THEN
        v_added := public.dungeon_add_item(v_user, v_item_id, 1);
        IF NOT v_added THEN
          RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
        END IF;
      END IF;
    END IF;

    IF v_th = 50 THEN
      UPDATE public.users
      SET avatar_frame = COALESCE(NULLIF(avatar_frame, ''), 'codex')
      WHERE auth_id = v_user
        AND (avatar_frame IS NULL OR avatar_frame = '');
    END IF;

    IF v_th = 400 THEN
      v_item_id := public.ensure_codex_badge_item('gold');
      IF v_item_id IS NOT NULL THEN
        v_added := public.dungeon_add_item(v_user, v_item_id, 1);
        IF NOT v_added THEN
          RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
        END IF;
      END IF;

      UPDATE public.users
      SET cosmetic_title = COALESCE(cosmetic_title, 'kodex_ustasi')
      WHERE auth_id = v_user
        AND (cosmetic_title IS NULL OR cosmetic_title = '');
    END IF;

    v_total_gold := v_total_gold + COALESCE(v_gold, 0);
    v_total_gems := v_total_gems + COALESCE(v_gems, 0);
    v_count := v_count + 1;
    v_claimed := v_claimed || jsonb_build_array(jsonb_build_object(
      'threshold', v_th,
      'reward_gold', v_gold,
      'reward_gems', v_gems,
      'reward_label', v_label
    ));
  END LOOP;

  IF v_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Alınacak ödül yok.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'claimed_count', v_count,
    'reward_gold', v_total_gold,
    'reward_gems', v_total_gems,
    'reward_label', v_count::text || ' ödül',
    'claimed', v_claimed
  );
END;
$$;

-- One-time backfill: 50+ claimed, empty frame → codex
UPDATE public.users u
SET avatar_frame = 'codex'
WHERE (u.avatar_frame IS NULL OR u.avatar_frame = '')
  AND EXISTS (
    SELECT 1
    FROM public.player_codex_milestones m
    WHERE m.player_id = u.auth_id
      AND m.threshold >= 50
      AND m.claimed_at IS NOT NULL
  );

-- ── get_retention_promos: should_notify_online (1/Istanbul day) ───────────────
CREATE OR REPLACE FUNCTION public.get_retention_promos()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_codex JSONB;
  v_nemesis JSONB;
  v_night JSONB;
  v_win RECORD;
  v_discovered INT;
  v_total INT;
  v_new_24h INT;
  v_claimable INT;
  v_nem RECORD;
  v_rival RECORD;
  v_rank JSON;
  v_dismissed BOOLEAN;
  v_should_notify_online BOOLEAN := false;
  v_today_tr DATE;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT COUNT(*) INTO v_total FROM public.codex_catalog;
  v_discovered := public._codex_discovered_count(v_user);
  SELECT COUNT(*) INTO v_new_24h
  FROM public.player_codex_entries
  WHERE player_id = v_user AND discovered_at >= now() - interval '24 hours';
  SELECT COUNT(*) INTO v_claimable
  FROM public._codex_milestone_thresholds() AS th
  WHERE v_discovered >= th
    AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = th AND m.claimed_at IS NOT NULL
    );

  v_codex := jsonb_build_object(
    'discovered', v_discovered,
    'total', v_total,
    'new_entries_24h', v_new_24h,
    'claimable_milestones', v_claimable
  );

  PERFORM public.refresh_player_nemesis(v_user);
  SELECT * INTO v_nem FROM public.player_nemesis_state WHERE player_id = v_user;
  v_dismissed := v_nem.dismissed_until IS NOT NULL AND v_nem.dismissed_until > now();

  IF v_nem.nemesis_id IS NOT NULL THEN
    SELECT auth_id, username, display_name, COALESCE(is_online, false) AS is_online
    INTO v_rival FROM public.users WHERE auth_id = v_nem.nemesis_id;
    v_rank := public.get_leaderboard_rank('power', 'alltime');

    v_today_tr := (now() AT TIME ZONE 'Europe/Istanbul')::date;
    IF COALESCE(v_rival.is_online, false)
       AND COALESCE(v_nem.losses, 0) >= 1
       AND NOT v_dismissed
       AND (
         v_nem.last_online_notice_at IS NULL
         OR (v_nem.last_online_notice_at AT TIME ZONE 'Europe/Istanbul')::date < v_today_tr
       )
    THEN
      v_should_notify_online := true;
      UPDATE public.player_nemesis_state
      SET last_online_notice_at = now()
      WHERE player_id = v_user;
    END IF;

    v_nemesis := jsonb_build_object(
      'has_rival', true,
      'rival_id', v_rival.auth_id,
      'rival_username', COALESCE(v_rival.display_name, v_rival.username),
      'losses', v_nem.losses,
      'wins', v_nem.wins,
      'online', v_rival.is_online,
      'leaderboard_gap', COALESCE((v_rank->>'gap')::INT, 0),
      'dismissed', v_dismissed,
      'last_match_at', v_nem.last_match_at,
      'should_notify_online', v_should_notify_online
    );
  ELSE
    v_nemesis := jsonb_build_object(
      'has_rival', false,
      'should_notify_online', false
    );
  END IF;

  SELECT * INTO v_win FROM public._night_market_window();
  v_night := jsonb_build_object(
    'active', v_win.active,
    'starts_at', v_win.starts_at,
    'ends_at', v_win.ends_at,
    'seconds_left', v_win.seconds_left
  );

  RETURN jsonb_build_object(
    'success', true,
    'codex', v_codex,
    'nemesis', v_nemesis,
    'night_market', v_night
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.qa_force_night_market(boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.qa_force_night_market(boolean) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qa_force_night_market(boolean) TO service_role;

GRANT EXECUTE ON FUNCTION public.claim_codex_milestone(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_all_codex_milestones() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_retention_promos() TO authenticated;

COMMIT;
