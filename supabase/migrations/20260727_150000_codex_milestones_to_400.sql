-- Codex: 14 milestone thresholds → 400; catalog trim 405 → 400.
BEGIN;

-- ── Threshold helper ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._codex_milestone_thresholds()
RETURNS SETOF INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT t.th FROM (VALUES
    (10), (20), (30), (40), (50), (75), (100),
    (125), (150), (200), (250), (300), (350), (400)
  ) AS t(th);
$$;

-- ── Constraint: drop → remap old 25 → 20 → new check ──────────────────────────
ALTER TABLE public.player_codex_milestones
  DROP CONSTRAINT IF EXISTS player_codex_milestones_threshold_check;

-- Players who claimed 25 keep credit as 20 (nearest new tier).
UPDATE public.player_codex_milestones pcm
SET threshold = 20
WHERE pcm.threshold = 25
  AND NOT EXISTS (
    SELECT 1 FROM public.player_codex_milestones x
    WHERE x.player_id = pcm.player_id AND x.threshold = 20
  );

DELETE FROM public.player_codex_milestones WHERE threshold = 25;

ALTER TABLE public.player_codex_milestones
  ADD CONSTRAINT player_codex_milestones_threshold_check
  CHECK (threshold IN (
    10, 20, 30, 40, 50, 75, 100, 125, 150, 200, 250, 300, 350, 400
  ));

-- ── Catalog: drop 5 unused far-future season badges → total 400 ───────────────
DELETE FROM public.player_codex_entries
WHERE entry_type = 'item'
  AND entry_key IN (
    'badge_season_08',
    'badge_season_09',
    'badge_season_10',
    'badge_season_11',
    'badge_season_12'
  );

DELETE FROM public.codex_catalog
WHERE entry_type = 'item'
  AND entry_key IN (
    'badge_season_08',
    'badge_season_09',
    'badge_season_10',
    'badge_season_11',
    'badge_season_12'
  );

-- ── Reward config ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._codex_milestone_reward_config(p_threshold INTEGER)
RETURNS TABLE (
  gold_amount BIGINT,
  gem_amount INT,
  reward_label TEXT,
  reward_kind TEXT
)
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT t.gold_amount, t.gem_amount, t.reward_label, t.reward_kind
  FROM (VALUES
    (10,   100000::BIGINT,  0,  '100.000 Altın',                          'gold'),
    (20,   150000::BIGINT,  0,  '150.000 Altın',                          'gold'),
    (30,   200000::BIGINT,  0,  '200.000 Altın',                          'gold'),
    (40,   300000::BIGINT,  1,  '300.000 Altın + 1 Elmas',                'mixed'),
    (50,   400000::BIGINT,  3,  '400.000 Altın + 3 Elmas + loot şansı',  'mixed'),
    (75,   500000::BIGINT,  5,  '500.000 Altın + 5 Elmas',                'mixed'),
    (100,  750000::BIGINT,  8,  '750.000 Altın + 8 Elmas',                'mixed'),
    (125, 1000000::BIGINT, 10,  '1M Altın + 10 Elmas',                    'mixed'),
    (150, 1250000::BIGINT, 12,  '1.25M Altın + 12 Elmas',                 'mixed'),
    (200, 1500000::BIGINT, 15,  '1.5M Altın + 15 Elmas',                  'mixed'),
    (250, 2000000::BIGINT, 18,  '2M Altın + 18 Elmas',                    'mixed'),
    (300, 2500000::BIGINT, 25,  '2.5M Altın + 25 Elmas',                  'mixed'),
    (350, 3500000::BIGINT, 30,  '3.5M Altın + 30 Elmas',                  'mixed'),
    (400, 5000000::BIGINT, 45,  '5M Altın + 45 Elmas + rozet + unvan',   'mixed')
  ) AS t(threshold, gold_amount, gem_amount, reward_label, reward_kind)
  WHERE t.threshold = p_threshold;
$$;

-- Luck still unlocks at 50 claim.
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

-- ── Dashboard ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_codex_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_discovered INT;
  v_total INT;
  v_new_24h INT;
  v_claimable INT;
  v_milestones JSONB;
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

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'threshold', th,
    'claimed', EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = th AND m.claimed_at IS NOT NULL
    ),
    'claimable', v_discovered >= th AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = th AND m.claimed_at IS NOT NULL
    ),
    'reward_gold', cfg.gold_amount,
    'reward_gems', cfg.gem_amount,
    'reward_label', cfg.reward_label,
    'reward_kind', cfg.reward_kind
  ) ORDER BY th), '[]'::JSONB)
  INTO v_milestones
  FROM public._codex_milestone_thresholds() AS th
  JOIN LATERAL public._codex_milestone_reward_config(th) cfg ON TRUE;

  RETURN jsonb_build_object(
    'success', true,
    'discovered', v_discovered,
    'total', v_total,
    'new_entries_24h', v_new_24h,
    'claimable_milestones', v_claimable,
    'luck_bonus', public.get_codex_luck_bonus(v_user),
    'milestones', v_milestones
  );
END;
$$;

-- ── Claim ─────────────────────────────────────────────────────────────────────
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

  INSERT INTO public.player_codex_milestones (player_id, threshold, claimed_at)
  VALUES (v_user, p_threshold, now())
  ON CONFLICT (player_id, threshold) DO UPDATE
    SET claimed_at = COALESCE(player_codex_milestones.claimed_at, now())
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
        RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu — rozet verilemedi.');
      END IF;
    END IF;
  END IF;

  IF p_threshold = 400 THEN
    v_item_id := public.ensure_codex_badge_item('gold');
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu — rozet verilemedi.');
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

-- ── Retention / comeback claimable counts ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_retention_promos()
RETURNS JSONB
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
    v_nemesis := jsonb_build_object(
      'has_rival', true,
      'rival_id', v_rival.auth_id,
      'rival_username', COALESCE(v_rival.display_name, v_rival.username),
      'losses', v_nem.losses,
      'wins', v_nem.wins,
      'online', v_rival.is_online,
      'leaderboard_gap', COALESCE((v_rank->>'gap')::INT, 0),
      'dismissed', v_dismissed,
      'last_match_at', v_nem.last_match_at
    );
  ELSE
    v_nemesis := jsonb_build_object('has_rival', false);
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

CREATE OR REPLACE FUNCTION public._comeback_retention_items(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_items JSONB := '[]'::JSONB;
  v_discovered INT;
  v_claimable_codex INT;
  v_nem RECORD;
  v_rival RECORD;
  v_win RECORD;
BEGIN
  IF p_user_id IS NULL THEN RETURN v_items; END IF;

  v_discovered := public._codex_discovered_count(p_user_id);
  SELECT COUNT(*) INTO v_claimable_codex
  FROM public._codex_milestone_thresholds() AS th
  WHERE v_discovered >= th
    AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = p_user_id AND m.threshold = th AND m.claimed_at IS NOT NULL
    );
  IF v_claimable_codex > 0 THEN
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', 'codex:milestone',
      'kind', 'codex_milestone',
      'title', 'Kodex kilometre taşı',
      'subtitle', v_claimable_codex::text || ' ödül alınabilir.',
      'route', '/character/codex?claim=1',
      'priority', 88,
      'cta_label', 'Al'
    ));
  END IF;

  PERFORM public.refresh_player_nemesis(p_user_id);
  SELECT * INTO v_nem FROM public.player_nemesis_state WHERE player_id = p_user_id;
  IF v_nem.nemesis_id IS NOT NULL AND v_nem.losses >= 1
     AND (v_nem.dismissed_until IS NULL OR v_nem.dismissed_until <= now()) THEN
    SELECT COALESCE(display_name, username) INTO v_rival FROM public.users WHERE auth_id = v_nem.nemesis_id;
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', 'nemesis:revenge',
      'kind', 'nemesis_revenge',
      'title', 'Nemesis intikamı',
      'subtitle', COALESCE(v_rival, 'Rakip') || ' — ' || v_nem.losses::text || ' yenilgi.',
      'route', '/pvp?revenge=' || v_nem.nemesis_id::text,
      'priority', 86,
      'cta_label', 'Düello'
    ));
  END IF;

  SELECT * INTO v_win FROM public._night_market_window();
  IF v_win.active THEN
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', 'night_market:open',
      'kind', 'night_market',
      'title', 'Gece Pazarı açık',
      'subtitle', 'Günlük gem teklifleri — sınırlı stok.',
      'route', '/shop?tab=night',
      'priority', 90,
      'cta_label', 'Git'
    ));
  END IF;

  RETURN v_items;
END;
$function$;

GRANT EXECUTE ON FUNCTION public._codex_milestone_thresholds() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_codex_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_codex_milestone(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_retention_promos() TO authenticated;

COMMIT;
