-- Retention trio: Kodex (#5) + Nemesis (#2) + Gece Pazarı (#10)
-- Ortak RPC: get_retention_promos()

-- ═══════════════════════════════════════════════════════════════════════════
-- Faz 0 — shop_offers fix (Flutter orphan)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.shop_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  item_id TEXT REFERENCES public.items(id),
  price BIGINT NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'gems',
  discount_pct INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.shop_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_offers_select_active ON public.shop_offers;
CREATE POLICY shop_offers_select_active ON public.shop_offers
  FOR SELECT TO authenticated
  USING (is_active = true);

-- ═══════════════════════════════════════════════════════════════════════════
-- Faz 1 — Kodex tables
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.codex_catalog (
  entry_type TEXT NOT NULL CHECK (entry_type IN ('item', 'boss', 'dungeon')),
  entry_key TEXT NOT NULL,
  display_name TEXT NOT NULL,
  rarity TEXT,
  zone TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (entry_type, entry_key)
);

CREATE TABLE IF NOT EXISTS public.player_codex_entries (
  player_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('item', 'boss', 'dungeon')),
  entry_key TEXT NOT NULL,
  discovered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (player_id, entry_type, entry_key)
);

CREATE TABLE IF NOT EXISTS public.player_codex_milestones (
  player_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  threshold INTEGER NOT NULL CHECK (threshold IN (10, 25, 50, 100)),
  claimed_at TIMESTAMPTZ,
  PRIMARY KEY (player_id, threshold)
);

ALTER TABLE public.player_codex_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_codex_milestones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS player_codex_entries_own ON public.player_codex_entries;
CREATE POLICY player_codex_entries_own ON public.player_codex_entries
  FOR ALL TO authenticated USING (player_id = auth.uid()) WITH CHECK (player_id = auth.uid());

DROP POLICY IF EXISTS player_codex_milestones_own ON public.player_codex_milestones;
CREATE POLICY player_codex_milestones_own ON public.player_codex_milestones
  FOR ALL TO authenticated USING (player_id = auth.uid()) WITH CHECK (player_id = auth.uid());

-- Seed catalog from items + dungeons
INSERT INTO public.codex_catalog (entry_type, entry_key, display_name, rarity, zone, sort_order)
SELECT 'item', i.id, COALESCE(i.name, i.id), i.rarity,
       COALESCE(NULLIF(i.type, ''), 'genel'), row_number() OVER (ORDER BY i.id)
FROM public.items i
ON CONFLICT (entry_type, entry_key) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  rarity = EXCLUDED.rarity,
  zone = EXCLUDED.zone;

INSERT INTO public.codex_catalog (entry_type, entry_key, display_name, rarity, zone, sort_order)
SELECT
  CASE WHEN COALESCE(d.is_boss, false) THEN 'boss' ELSE 'dungeon' END,
  d.id,
  COALESCE(d.name_tr, d.name, d.id),
  CASE WHEN COALESCE(d.is_boss, false) THEN 'boss' ELSE 'normal' END,
  'zone_' || COALESCE(d.zone, 1)::text,
  1000 + row_number() OVER (ORDER BY d.dungeon_order NULLS LAST, d.id)
FROM public.dungeons d
ON CONFLICT (entry_type, entry_key) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  rarity = EXCLUDED.rarity,
  zone = EXCLUDED.zone;

-- ═══════════════════════════════════════════════════════════════════════════
-- Faz 2 — Nemesis tables
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.player_nemesis_state (
  player_id UUID PRIMARY KEY REFERENCES public.users(auth_id) ON DELETE CASCADE,
  nemesis_id UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  losses INTEGER NOT NULL DEFAULT 0,
  wins INTEGER NOT NULL DEFAULT 0,
  last_match_at TIMESTAMPTZ,
  dismissed_until TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.nemesis_revenge_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  avenger_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  nemesis_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  invite_id UUID,
  won BOOLEAN,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.player_nemesis_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nemesis_revenge_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS player_nemesis_state_own ON public.player_nemesis_state;
CREATE POLICY player_nemesis_state_own ON public.player_nemesis_state
  FOR ALL TO authenticated USING (player_id = auth.uid()) WITH CHECK (player_id = auth.uid());

DROP POLICY IF EXISTS nemesis_revenge_log_own ON public.nemesis_revenge_log;
CREATE POLICY nemesis_revenge_log_own ON public.nemesis_revenge_log
  FOR SELECT TO authenticated USING (avenger_id = auth.uid() OR nemesis_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════
-- Faz 3 — Night Market tables
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.night_market_schedule (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  weekday SMALLINT NOT NULL DEFAULT 5,
  start_hour SMALLINT NOT NULL DEFAULT 20,
  end_hour SMALLINT NOT NULL DEFAULT 22,
  timezone TEXT NOT NULL DEFAULT 'Europe/Istanbul'
);

INSERT INTO public.night_market_schedule (id, weekday, start_hour, end_hour, timezone)
VALUES (1, 5, 20, 22, 'Europe/Istanbul')
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.night_market_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rotation_week DATE NOT NULL,
  item_id TEXT NOT NULL REFERENCES public.items(id),
  gem_price BIGINT NOT NULL,
  stock_per_player INTEGER NOT NULL DEFAULT 1 CHECK (stock_per_player BETWEEN 1 AND 3),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.night_market_purchases (
  player_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  offer_id UUID NOT NULL REFERENCES public.night_market_offers(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1,
  purchased_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (player_id, offer_id)
);

ALTER TABLE public.night_market_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.night_market_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS night_market_offers_select ON public.night_market_offers;
CREATE POLICY night_market_offers_select ON public.night_market_offers
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS night_market_purchases_own ON public.night_market_purchases;
CREATE POLICY night_market_purchases_own ON public.night_market_purchases
  FOR ALL TO authenticated USING (player_id = auth.uid()) WITH CHECK (player_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════════════════════════════════════
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
  -- QA: test için true yap — Cuma beklemeden pazar açık
  v_qa_force_open BOOLEAN := false;
BEGIN
  SELECT * INTO v_sched FROM public.night_market_schedule WHERE id = 1;

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

CREATE OR REPLACE FUNCTION public._ensure_night_market_offers(p_rotation_week DATE)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.night_market_offers WHERE rotation_week = p_rotation_week LIMIT 1) THEN
    RETURN;
  END IF;

  INSERT INTO public.night_market_offers (rotation_week, item_id, gem_price, stock_per_player, sort_order)
  SELECT
    p_rotation_week,
    sub.item_id,
    sub.gem_price,
    sub.stock_per_player,
    sub.ord
  FROM (
    SELECT
      i.id AS item_id,
      GREATEST(50, COALESCE(i.base_price, 100) / 1000)::BIGINT AS gem_price,
      1 + (abs(hashtext(i.id || p_rotation_week::text)) % 3)::INT AS stock_per_player,
      row_number() OVER (ORDER BY random()) AS ord
    FROM public.items i
    WHERE COALESCE(i.base_price, 0) > 0
    LIMIT 8
  ) sub;
END;
$$;

CREATE OR REPLACE FUNCTION public._codex_discovered_count(p_player_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
  SELECT COUNT(*)::INTEGER FROM public.player_codex_entries WHERE player_id = p_player_id;
$$;

CREATE OR REPLACE FUNCTION public._codex_luck_bonus_raw(p_player_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
  SELECT CASE WHEN public._codex_discovered_count(p_player_id) >= 50 THEN 1 ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public.get_codex_luck_bonus(p_player_id UUID DEFAULT auth.uid())
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_bonus INT := 0;
  v_monument INT := 0;
BEGIN
  IF p_player_id IS NULL THEN RETURN 0; END IF;
  v_bonus := public._codex_luck_bonus_raw(p_player_id);
  SELECT COALESCE(level, 0) INTO v_monument
  FROM public.guild_monuments gm
  JOIN public.users u ON u.guild_id = gm.guild_id
  WHERE u.auth_id = p_player_id
  LIMIT 1;
  IF v_monument >= 30 THEN
    v_bonus := LEAST(v_bonus + 10, 11);
  END IF;
  RETURN LEAST(v_bonus, 11);
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Codex RPCs
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.discover_codex_entry(
  p_type TEXT,
  p_key TEXT,
  p_player_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inserted BOOLEAN := false;
  v_display_name TEXT;
  v_rarity TEXT;
  v_zone TEXT;
BEGIN
  IF p_player_id IS NULL OR p_type IS NULL OR p_key IS NULL THEN
    RETURN jsonb_build_object('discovered', false);
  END IF;

  INSERT INTO public.player_codex_entries (player_id, entry_type, entry_key)
  VALUES (p_player_id, p_type, p_key)
  ON CONFLICT DO NOTHING
  RETURNING true INTO v_inserted;

  v_inserted := COALESCE(v_inserted, false);

  SELECT cc.display_name, cc.rarity, cc.zone
  INTO v_display_name, v_rarity, v_zone
  FROM public.codex_catalog cc
  WHERE cc.entry_type = p_type AND cc.entry_key = p_key;

  RETURN jsonb_build_object(
    'discovered', v_inserted,
    'entry_type', p_type,
    'entry_key', p_key,
    'display_name', COALESCE(v_display_name, p_key),
    'rarity', v_rarity,
    'zone', v_zone
  );
END;
$$;

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
  FROM (VALUES (10), (25), (50), (100)) AS t(th)
  WHERE v_discovered >= t.th
    AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = t.th AND m.claimed_at IS NOT NULL
    );

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'threshold', th,
    'claimed', EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = t.th AND m.claimed_at IS NOT NULL
    ),
    'claimable', v_discovered >= t.th AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = t.th AND m.claimed_at IS NOT NULL
    )
  ) ORDER BY th), '[]'::JSONB)
  INTO v_milestones
  FROM (VALUES (10), (25), (50), (100)) AS t(th);

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

CREATE OR REPLACE FUNCTION public.get_codex_entries(
  p_type TEXT DEFAULT 'item',
  p_offset INTEGER DEFAULT 0,
  p_limit INTEGER DEFAULT 60
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_rows JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(sub)::JSONB ORDER BY sub.sort_order, sub.entry_key), '[]'::JSONB)
  INTO v_rows
  FROM (
    SELECT
      c.entry_type,
      c.entry_key,
      c.display_name,
      c.rarity,
      c.zone,
      c.sort_order,
      (e.discovered_at IS NOT NULL) AS is_discovered,
      e.discovered_at
    FROM public.codex_catalog c
    LEFT JOIN public.player_codex_entries e
      ON e.player_id = v_user AND e.entry_type = c.entry_type AND e.entry_key = c.entry_key
    WHERE c.entry_type = p_type
    ORDER BY c.sort_order, c.entry_key
    OFFSET GREATEST(p_offset, 0)
    LIMIT LEAST(GREATEST(p_limit, 1), 120)
  ) sub;

  RETURN jsonb_build_object('success', true, 'entries', COALESCE(v_rows, '[]'::JSONB));
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

  RETURN jsonb_build_object(
    'success', true,
    'threshold', p_threshold,
    'reward', CASE p_threshold
      WHEN 10 THEN 'bronze_badge'
      WHEN 25 THEN 'frame_unlock'
      WHEN 50 THEN 'loot_luck_plus_one'
      WHEN 100 THEN 'gold_badge_title'
    END
  );
END;
$$;

-- Backfill existing players
INSERT INTO public.player_codex_entries (player_id, entry_type, entry_key, discovered_at)
SELECT DISTINCT inv.user_id, 'item', inv.item_id, COALESCE(inv.created_at, now())
FROM public.inventory inv
ON CONFLICT DO NOTHING;

INSERT INTO public.player_codex_entries (player_id, entry_type, entry_key, discovered_at)
SELECT DISTINCT ds.player_id,
  CASE WHEN COALESCE(d.is_boss, false) THEN 'boss' ELSE 'dungeon' END,
  ds.dungeon_id,
  COALESCE(ds.first_clear_at, now())
FROM public.player_dungeon_stats ds
JOIN public.dungeons d ON d.id = ds.dungeon_id
WHERE ds.first_clear_at IS NOT NULL
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
-- Nemesis RPCs
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.refresh_player_nemesis(p_player_id UUID DEFAULT auth.uid())
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_best RECORD;
  v_window_start TIMESTAMPTZ;
BEGIN
  IF p_player_id IS NULL THEN RETURN; END IF;

  v_window_start := (now() AT TIME ZONE 'Europe/Istanbul') - interval '7 days';

  WITH duel_matches AS (
    SELECT
      CASE WHEN (i.result->>'winner_id')::UUID = i.challenger_id THEN i.target_id ELSE i.challenger_id END AS opponent_id,
      CASE WHEN (i.result->>'winner_id')::UUID = p_player_id THEN 1 ELSE 0 END AS win,
      CASE WHEN (i.result->>'winner_id')::UUID = p_player_id THEN 0 ELSE 1 END AS loss,
      i.updated_at AS matched_at
    FROM public.pvp_invites i
    WHERE i.status = 'accepted'
      AND i.result IS NOT NULL
      AND p_player_id IN (i.challenger_id, i.target_id)
      AND i.updated_at >= v_window_start
    UNION ALL
    SELECT
      CASE WHEN m.winner_id = m.attacker_id THEN m.defender_id ELSE m.attacker_id END,
      CASE WHEN m.winner_id = p_player_id THEN 1 ELSE 0 END,
      CASE WHEN m.winner_id = p_player_id THEN 0 ELSE 1 END,
      m.created_at
    FROM public.mekan_pvp_matches m
    WHERE p_player_id IN (m.attacker_id, m.defender_id)
      AND m.winner_id IS NOT NULL
      AND m.created_at >= v_window_start
  ),
  agg AS (
    SELECT
      opponent_id,
      SUM(loss) AS losses,
      SUM(win) AS wins,
      MAX(matched_at) AS last_match_at,
      SUM(loss) * 3 + SUM(win) AS score
    FROM duel_matches
    WHERE opponent_id IS NOT NULL AND opponent_id <> p_player_id
    GROUP BY opponent_id
    HAVING SUM(loss) >= 1
  )
  SELECT * INTO v_best
  FROM agg
  ORDER BY score DESC, losses DESC, last_match_at DESC
  LIMIT 1;

  IF v_best.opponent_id IS NULL THEN
    DELETE FROM public.player_nemesis_state WHERE player_id = p_player_id;
    RETURN;
  END IF;

  INSERT INTO public.player_nemesis_state (player_id, nemesis_id, losses, wins, last_match_at, updated_at)
  VALUES (p_player_id, v_best.opponent_id, v_best.losses, v_best.wins, v_best.last_match_at, now())
  ON CONFLICT (player_id) DO UPDATE SET
    nemesis_id = EXCLUDED.nemesis_id,
    losses = EXCLUDED.losses,
    wins = EXCLUDED.wins,
    last_match_at = EXCLUDED.last_match_at,
    updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.get_nemesis_rival()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_state RECORD;
  v_rival RECORD;
  v_rank JSON;
  v_gap INT;
  v_dismissed BOOLEAN;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  PERFORM public.refresh_player_nemesis(v_user);

  SELECT * INTO v_state FROM public.player_nemesis_state WHERE player_id = v_user;

  IF v_state.nemesis_id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'has_rival', false);
  END IF;

  SELECT auth_id, username, display_name, avatar_url, level, power,
         COALESCE(is_online, false) AS is_online, pvp_rating
  INTO v_rival
  FROM public.users WHERE auth_id = v_state.nemesis_id;

  v_rank := public.get_leaderboard_rank('power', 'alltime');
  v_gap := COALESCE((v_rank->>'gap')::INT, 0);
  v_dismissed := v_state.dismissed_until IS NOT NULL AND v_state.dismissed_until > now();

  RETURN jsonb_build_object(
    'success', true,
    'has_rival', true,
    'rival_id', v_rival.auth_id,
    'rival_username', COALESCE(v_rival.display_name, v_rival.username),
    'losses', v_state.losses,
    'wins', v_state.wins,
    'online', v_rival.is_online,
    'level', v_rival.level,
    'power', v_rival.power,
    'pvp_rating', COALESCE(v_rival.pvp_rating, 1000),
    'leaderboard_gap', v_gap,
    'last_match_at', v_state.last_match_at,
    'dismissed', v_dismissed,
    'dismissed_until', v_state.dismissed_until
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.dismiss_nemesis_banner()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  INSERT INTO public.player_nemesis_state (player_id, dismissed_until)
  VALUES (v_user, now() + interval '24 hours')
  ON CONFLICT (player_id) DO UPDATE SET dismissed_until = now() + interval '24 hours';

  RETURN jsonb_build_object('success', true, 'dismissed_until', now() + interval '24 hours');
END;
$$;

CREATE OR REPLACE FUNCTION public._nemesis_after_pvp_match(p_a UUID, p_b UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_a IS NOT NULL THEN PERFORM public.refresh_player_nemesis(p_a); END IF;
  IF p_b IS NOT NULL AND p_b <> p_a THEN PERFORM public.refresh_player_nemesis(p_b); END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_nemesis_pvp_invite_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status = 'accepted' AND NEW.result IS NOT NULL THEN
    PERFORM public._nemesis_after_pvp_match(NEW.challenger_id, NEW.target_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS nemesis_pvp_invite_refresh ON public.pvp_invites;
CREATE TRIGGER nemesis_pvp_invite_refresh
  AFTER UPDATE OF status, result ON public.pvp_invites
  FOR EACH ROW EXECUTE FUNCTION public.trg_nemesis_pvp_invite_refresh();

CREATE OR REPLACE FUNCTION public.trg_nemesis_mekan_match_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public._nemesis_after_pvp_match(NEW.attacker_id, NEW.defender_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS nemesis_mekan_match_refresh ON public.mekan_pvp_matches;
CREATE TRIGGER nemesis_mekan_match_refresh
  AFTER INSERT ON public.mekan_pvp_matches
  FOR EACH ROW EXECUTE FUNCTION public.trg_nemesis_mekan_match_refresh();

-- ═══════════════════════════════════════════════════════════════════════════
-- Night Market RPCs
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_night_market_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_win RECORD;
  v_offers JSONB;
  v_shadow BOOLEAN := false;
  v_discount NUMERIC := 0;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT * INTO v_win FROM public._night_market_window();
  PERFORM public._ensure_night_market_offers(v_win.rotation_week);

  SELECT lower(character_class) = 'shadow' INTO v_shadow
  FROM public.users WHERE auth_id = v_user;
  IF v_shadow THEN v_discount := 0.05; END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'offer_id', o.id,
    'item_id', o.item_id,
    'item_name', COALESCE(i.name, o.item_id),
    'rarity', i.rarity,
    'icon', i.icon,
    'gem_price', floor(o.gem_price * (1 - v_discount))::BIGINT,
    'base_gem_price', o.gem_price,
    'stock_per_player', o.stock_per_player + CASE WHEN v_shadow THEN 1 ELSE 0 END,
    'purchased', COALESCE(p.quantity, 0),
    'remaining', GREATEST(0, o.stock_per_player + CASE WHEN v_shadow THEN 1 ELSE 0 END - COALESCE(p.quantity, 0))
  ) ORDER BY o.sort_order), '[]'::JSONB)
  INTO v_offers
  FROM public.night_market_offers o
  JOIN public.items i ON i.id = o.item_id
  LEFT JOIN public.night_market_purchases p
    ON p.offer_id = o.id AND p.player_id = v_user
  WHERE o.rotation_week = v_win.rotation_week;

  RETURN jsonb_build_object(
    'success', true,
    'active', v_win.active,
    'starts_at', v_win.starts_at,
    'ends_at', v_win.ends_at,
    'seconds_left', v_win.seconds_left,
    'rotation_week', v_win.rotation_week,
    'shadow_bonus', v_shadow,
    'shadow_discount_pct', CASE WHEN v_shadow THEN 5 ELSE 0 END,
    'offers', COALESCE(v_offers, '[]'::JSONB)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.buy_night_market_item(
  p_offer_id UUID,
  p_quantity INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_win RECORD;
  v_offer RECORD;
  v_item RECORD;
  v_shadow BOOLEAN := false;
  v_discount NUMERIC := 0;
  v_stock INT;
  v_purchased INT;
  v_unit_price BIGINT;
  v_total BIGINT;
  v_gems NUMERIC;
  v_add JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_quantity < 1 OR p_quantity > 99 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
  END IF;

  SELECT * INTO v_win FROM public._night_market_window();
  IF NOT v_win.active THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gece Pazarı şu an kapalı. Cuma 20:00–22:00');
  END IF;

  SELECT o.*, i.name, i.is_stackable, i.max_stack
  INTO v_offer
  FROM public.night_market_offers o
  JOIN public.items i ON i.id = o.item_id
  WHERE o.id = p_offer_id AND o.rotation_week = v_win.rotation_week;

  IF v_offer.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Offer not found');
  END IF;

  SELECT lower(character_class) = 'shadow' INTO v_shadow FROM public.users WHERE auth_id = v_user;
  IF v_shadow THEN v_discount := 0.05; END IF;

  v_stock := v_offer.stock_per_player + CASE WHEN v_shadow THEN 1 ELSE 0 END;
  SELECT COALESCE(quantity, 0) INTO v_purchased
  FROM public.night_market_purchases
  WHERE player_id = v_user AND offer_id = p_offer_id;

  IF v_purchased + p_quantity > v_stock THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz');
  END IF;

  v_unit_price := floor(v_offer.gem_price * (1 - v_discount))::BIGINT;
  v_total := v_unit_price * p_quantity;

  SELECT gems INTO v_gems FROM public.users WHERE auth_id = v_user;
  IF COALESCE(v_gems, 0) < v_total THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
  END IF;

  UPDATE public.users SET gems = gems - v_total WHERE auth_id = v_user;

  v_add := public.add_inventory_item_v2(
    jsonb_build_object('item_id', v_offer.item_id, 'quantity', p_quantity, 'allow_stack', true),
    NULL
  );

  IF COALESCE((v_add->>'success')::BOOLEAN, false) = false THEN
    UPDATE public.users SET gems = gems + v_total WHERE auth_id = v_user;
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_add->>'error', 'Inventory failed'));
  END IF;

  INSERT INTO public.night_market_purchases (player_id, offer_id, quantity)
  VALUES (v_user, p_offer_id, p_quantity)
  ON CONFLICT (player_id, offer_id) DO UPDATE SET
    quantity = night_market_purchases.quantity + EXCLUDED.quantity,
    purchased_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'item_id', v_offer.item_id,
    'quantity', p_quantity,
    'total_cost', v_total,
    'currency', 'gems'
  );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- get_retention_promos — carousel + inbox + sticky tek kaynak
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_retention_promos()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
  FROM (VALUES (10), (25), (50), (100)) AS t(th)
  WHERE v_discovered >= t.th
    AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = t.th AND m.claimed_at IS NOT NULL
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
$$;

-- Comeback summary retention rows helper
CREATE OR REPLACE FUNCTION public._comeback_retention_items(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
  FROM (VALUES (10), (25), (50), (100)) AS t(th)
  WHERE v_discovered >= t.th
    AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = p_user_id AND m.threshold = t.th AND m.claimed_at IS NOT NULL
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
      'subtitle', 'Cuma özel gem teklifleri — sınırlı stok.',
      'route', '/shop?tab=night',
      'priority', 90,
      'cta_label', 'Git'
    ));
  END IF;

  RETURN v_items;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Patch get_comeback_summary — codex / nemesis / night_market rows
-- ═══════════════════════════════════════════════════════════════════════════
DO $comeback_patch$
DECLARE
  v_def text;
  v_energy_marker text := E'  -- ── Enerji durumu (her zaman) ─────────────────────────────────────────────';
  v_retention_block text := E'  -- [GKK_RETENTION_COME_BACK_BEGIN]\n  v_items := v_items || public._comeback_retention_items(v_user_id);\n  -- [GKK_RETENTION_COME_BACK_END]\n\n';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'get_comeback_summary'
  ORDER BY p.oid DESC LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'get_comeback_summary not found; skipping retention patch';
    RETURN;
  END IF;

  IF position('[GKK_RETENTION_COME_BACK_BEGIN]' in v_def) = 0
     AND position(v_energy_marker in v_def) > 0 THEN
    v_def := replace(v_def, v_energy_marker, v_retention_block || v_energy_marker);
    EXECUTE v_def;
  END IF;
END;
$comeback_patch$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Patch enter_dungeon — codex discovery + codex_new in result
-- ═══════════════════════════════════════════════════════════════════════════
DO $codex_patch$
DECLARE
  v_def text;
  v_declare text := E'  v_codex_new         JSONB := ''[]''::JSONB;\n  v_codex_hit         JSONB;\n';
  v_success_marker text := E'  IF v_success THEN\n';
  v_codex_block text := E'  IF v_success THEN\n    -- [GKK_CODEX_BEGIN]\n    v_codex_hit := public.discover_codex_entry(\n      CASE WHEN COALESCE(v_dungeon.is_boss, false) THEN ''boss'' ELSE ''dungeon'' END,\n      p_dungeon_id,\n      p_player_id\n    );\n    IF COALESCE((v_codex_hit->>''discovered'')::boolean, false) THEN\n      v_codex_new := v_codex_new || jsonb_build_array(v_codex_hit);\n    END IF;\n    -- [GKK_CODEX_END]\n';
  v_return_marker text := E'    ''success'', v_success,\n';
  v_return_add text := E'    ''success'', v_success,\n    ''codex_new'', COALESCE(v_codex_new, ''[]''::jsonb),\n';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'enter_dungeon'
  ORDER BY p.oid DESC LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'enter_dungeon not found; skipping codex patch';
    RETURN;
  END IF;

  IF position('v_codex_new' in v_def) = 0 THEN
    IF position('v_milestone_rewards JSONB' in v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'  v_milestone_rewards JSONB := ''[]''::JSONB;',
        E'  v_milestone_rewards JSONB := ''[]''::JSONB;\n' || v_declare
      );
    END IF;
  END IF;

  IF position('[GKK_CODEX_BEGIN]' in v_def) = 0 AND position(v_success_marker in v_def) > 0 THEN
    v_def := replace(v_def, v_success_marker, v_codex_block);
  END IF;

  IF position('''codex_new''' in v_def) = 0 AND position(v_return_marker in v_def) > 0 THEN
    v_def := replace(v_def, v_return_marker, v_return_add);
  END IF;

  EXECUTE v_def;
END;
$codex_patch$;

-- Inventory hook: discover items on add
CREATE OR REPLACE FUNCTION public.trg_codex_inventory_discover()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  PERFORM public.discover_codex_entry('item', NEW.item_id, NEW.user_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS codex_inventory_discover ON public.inventory;
CREATE TRIGGER codex_inventory_discover
  AFTER INSERT ON public.inventory
  FOR EACH ROW EXECUTE FUNCTION public.trg_codex_inventory_discover();

-- Grants
GRANT EXECUTE ON FUNCTION public.get_retention_promos() TO authenticated;
GRANT EXECUTE ON FUNCTION public.discover_codex_entry(TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_codex_dashboard() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_codex_entries(TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_codex_milestone(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_codex_luck_bonus(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_player_nemesis(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_nemesis_rival() TO authenticated;
GRANT EXECUTE ON FUNCTION public.dismiss_nemesis_banner() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_night_market_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.buy_night_market_item(UUID, INTEGER) TO authenticated;
