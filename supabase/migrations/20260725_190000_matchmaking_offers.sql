-- ============================================================
-- Matchmaking offers (Arena + PvP Duel)
-- Mobile-game pattern: server builds eligible pool, returns N
-- random offers with opaque offer_id. Fight/invite must consume
-- a valid unexpired offer (anti-cheat vs arbitrary UUID targeting).
-- ============================================================

BEGIN;

-- ── Tables ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.matchmaking_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seeker_id UUID NOT NULL,
  opponent_id UUID NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('arena', 'duel')),
  snapshot_level INT NOT NULL,
  snapshot_power INT NOT NULL,
  snapshot_rating INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'consumed', 'expired')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '5 minutes'),
  consumed_at TIMESTAMPTZ,
  CHECK (seeker_id <> opponent_id)
);

CREATE INDEX IF NOT EXISTS matchmaking_offers_seeker_mode_open_idx
  ON public.matchmaking_offers (seeker_id, mode, status, expires_at DESC);

CREATE INDEX IF NOT EXISTS matchmaking_offers_id_seeker_idx
  ON public.matchmaking_offers (id, seeker_id)
  WHERE status = 'open';

CREATE TABLE IF NOT EXISTS public.matchmaking_refresh_state (
  seeker_id UUID NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('arena', 'duel')),
  last_refresh_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (seeker_id, mode)
);

ALTER TABLE public.matchmaking_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matchmaking_refresh_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS matchmaking_offers_select_own ON public.matchmaking_offers;
CREATE POLICY matchmaking_offers_select_own ON public.matchmaking_offers
  FOR SELECT USING (auth.uid() = seeker_id);

DROP POLICY IF EXISTS matchmaking_refresh_select_own ON public.matchmaking_refresh_state;
CREATE POLICY matchmaking_refresh_select_own ON public.matchmaking_refresh_state
  FOR SELECT USING (auth.uid() = seeker_id);

-- No direct INSERT/UPDATE/DELETE for clients — SECURITY DEFINER RPCs only.

-- ── Consume / validate offer ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.consume_matchmaking_offer(
  p_offer_id UUID,
  p_mode TEXT,
  p_expected_opponent UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_me UUID := auth.uid();
  v_offer public.matchmaking_offers%ROWTYPE;
  v_opp RECORD;
  v_power INT;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF p_offer_id IS NULL OR p_mode IS NULL OR p_expected_opponent IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşleşme teklifi.');
  END IF;

  IF p_mode NOT IN ('arena', 'duel') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşleşme modu.');
  END IF;

  SELECT * INTO v_offer
  FROM public.matchmaking_offers
  WHERE id = p_offer_id
    AND seeker_id = v_me
    AND mode = p_mode
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşleşme teklifi bulunamadı.');
  END IF;

  IF v_offer.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşleşme teklifi kullanılmış.');
  END IF;

  IF v_offer.expires_at <= now() THEN
    UPDATE public.matchmaking_offers SET status = 'expired' WHERE id = p_offer_id;
    RETURN jsonb_build_object('success', false, 'error', 'Eşleşme teklifinin süresi doldu. Yenile.');
  END IF;

  IF v_offer.opponent_id <> p_expected_opponent THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakip teklifle uyuşmuyor.');
  END IF;

  SELECT auth_id, level, power, COALESCE(pvp_rating, 1000) AS pvp_rating,
         hospital_until, prison_until
  INTO v_opp
  FROM public.users
  WHERE auth_id = p_expected_opponent
  FOR SHARE;

  IF NOT FOUND THEN
    UPDATE public.matchmaking_offers SET status = 'expired' WHERE id = p_offer_id;
    RETURN jsonb_build_object('success', false, 'error', 'Rakip bulunamadı.');
  END IF;

  IF v_opp.hospital_until IS NOT NULL OR v_opp.prison_until IS NOT NULL THEN
    UPDATE public.matchmaking_offers SET status = 'expired' WHERE id = p_offer_id;
    RETURN jsonb_build_object('success', false, 'error', 'Rakip şu an müsait değil.');
  END IF;

  v_power := COALESCE(v_opp.power, 0);

  -- Snapshot drift guard (anti power-swap mid-offer)
  IF abs(v_opp.level - v_offer.snapshot_level) > 3
     OR abs(v_opp.pvp_rating - v_offer.snapshot_rating) > 200
     OR (
       v_offer.snapshot_power > 0
       AND abs(v_power - v_offer.snapshot_power)::NUMERIC
           > GREATEST(v_offer.snapshot_power * 0.30, 50)
     )
  THEN
    UPDATE public.matchmaking_offers SET status = 'expired' WHERE id = p_offer_id;
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Rakip gücü değişti. Listeyi yenile.'
    );
  END IF;

  UPDATE public.matchmaking_offers
  SET status = 'consumed', consumed_at = now()
  WHERE id = p_offer_id;

  RETURN jsonb_build_object(
    'success', true,
    'opponent_id', v_offer.opponent_id,
    'snapshot_level', v_offer.snapshot_level,
    'snapshot_power', v_offer.snapshot_power,
    'snapshot_rating', v_offer.snapshot_rating
  );
END;
$$;

REVOKE ALL ON FUNCTION public.consume_matchmaking_offer(UUID, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.consume_matchmaking_offer(UUID, TEXT, UUID) TO authenticated;

-- ── Core offer sampler ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_matchmaking_offers(p_mode TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_me UUID := auth.uid();
  v_level INT;
  v_rating INT;
  v_power INT;
  v_guild UUID;
  v_limit INT := 6;
  v_refresh_cd INT := 45;
  v_last_refresh TIMESTAMPTZ;
  v_can_refresh BOOLEAN := true;
  v_next_refresh TIMESTAMPTZ;
  v_remaining INT := 0;
  v_band_used INT := 0;
  v_rows JSONB;
  v_gate JSONB;
  v_newbie_cap INT;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF p_mode IS NULL OR p_mode NOT IN ('arena', 'duel') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşleşme modu.');
  END IF;

  SELECT level,
         COALESCE(pvp_rating, 1000),
         COALESCE(power, 0),
         guild_id
  INTO v_level, v_rating, v_power, v_guild
  FROM public.users
  WHERE auth_id = v_me;

  IF v_level IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profil bulunamadı.');
  END IF;

  v_newbie_cap := CASE WHEN v_level < 5 THEN v_level + 2 ELSE 2147483647 END;

  SELECT last_refresh_at INTO v_last_refresh
  FROM public.matchmaking_refresh_state
  WHERE seeker_id = v_me AND mode = p_mode;

  IF v_last_refresh IS NOT NULL
     AND v_last_refresh > now() - make_interval(secs => v_refresh_cd)
  THEN
    v_can_refresh := false;
    v_next_refresh := v_last_refresh + make_interval(secs => v_refresh_cd);
    v_remaining := GREATEST(
      0,
      CEIL(EXTRACT(EPOCH FROM (v_next_refresh - now())))::INT
    );

    -- Serve cached open offers if still valid
    SELECT jsonb_agg(jsonb_build_object(
      'offer_id', o.id,
      'auth_id', u.auth_id,
      'username', u.username,
      'display_name', COALESCE(NULLIF(u.display_name, ''), u.username),
      'avatar_url', u.avatar_url,
      'level', u.level,
      'power', COALESCE(u.power, 0),
      'pvp_rating', COALESCE(u.pvp_rating, 1000),
      'attack', u.attack,
      'defense', u.defense,
      'expires_at', o.expires_at
    ) ORDER BY o.created_at)
    INTO v_rows
    FROM public.matchmaking_offers o
    JOIN public.users u ON u.auth_id = o.opponent_id
    WHERE o.seeker_id = v_me
      AND o.mode = p_mode
      AND o.status = 'open'
      AND o.expires_at > now();

    IF v_rows IS NOT NULL AND jsonb_array_length(v_rows) > 0 THEN
      RETURN jsonb_build_object(
        'success', true,
        'offers', v_rows,
        'opponents', v_rows,
        'refresh_cooldown_sec', v_refresh_cd,
        'can_refresh', false,
        'next_refresh_at', v_next_refresh,
        'refresh_in_sec', v_remaining,
        'band_tier_used', NULL
      );
    END IF;
    -- No cached offers left (all consumed/expired) but CD active → wait
    RETURN jsonb_build_object(
      'success', true,
      'offers', '[]'::jsonb,
      'opponents', '[]'::jsonb,
      'refresh_cooldown_sec', v_refresh_cd,
      'can_refresh', false,
      'next_refresh_at', v_next_refresh,
      'refresh_in_sec', v_remaining,
      'band_tier_used', NULL,
      'error', 'Yenileme beklemede'
    );
  END IF;

  -- Abuse cap only on real refresh (not cache hits)
  v_gate := public.enforce_rate_limit('matchmaking_refresh_' || p_mode, 25, 600);
  IF v_gate IS NOT NULL THEN
    RETURN v_gate;
  END IF;

  -- Expire stale open offers for this seeker+mode
  UPDATE public.matchmaking_offers
  SET status = 'expired'
  WHERE seeker_id = v_me
    AND mode = p_mode
    AND status = 'open';
  -- Sample with progressive band widen
  FOR v_band_used IN 0..2 LOOP
    WITH candidates AS (
      SELECT
        u.auth_id,
        u.username,
        u.display_name,
        u.avatar_url,
        u.level,
        COALESCE(u.power, 0) AS power,
        COALESCE(u.pvp_rating, 1000) AS pvp_rating,
        u.attack,
        u.defense,
        abs(u.level - v_level) AS lvl_gap,
        abs(COALESCE(u.pvp_rating, 1000) - v_rating) AS rating_gap,
        abs(COALESCE(u.power, 0) - v_power) AS power_gap
      FROM public.users u
      WHERE u.auth_id <> v_me
        AND u.level >= 1
        AND u.level <= v_newbie_cap
        AND u.hospital_until IS NULL
        AND u.prison_until IS NULL
        AND (v_guild IS NULL OR u.guild_id IS DISTINCT FROM v_guild)
        AND (
          v_band_used >= 2
          OR COALESCE(u.is_online, false)
          OR COALESCE(u.last_active_at, u.last_login_at, '1970-01-01'::timestamptz)
               > now() - interval '48 hours'
        )
        AND NOT EXISTS (
          SELECT 1 FROM public.mekan_pvp_matches m
          WHERE m.created_at > now() - interval '10 minutes'
            AND (
              (m.attacker_id = v_me AND m.defender_id = u.auth_id)
              OR (m.attacker_id = u.auth_id AND m.defender_id = v_me)
            )
        )
        AND NOT EXISTS (
          SELECT 1 FROM public.pvp_invites i
          WHERE i.created_at > now() - interval '10 minutes'
            AND i.status IN ('pending', 'accepted')
            AND (
              (i.challenger_id = v_me AND i.target_id = u.auth_id)
              OR (i.challenger_id = u.auth_id AND i.target_id = v_me)
            )
        )
        AND (
          CASE v_band_used
            WHEN 0 THEN
              abs(u.level - v_level) <= 5
              OR abs(COALESCE(u.pvp_rating, 1000) - v_rating) <= 250
              OR (
                v_power > 0
                AND abs(COALESCE(u.power, 0) - v_power)::NUMERIC <= GREATEST(v_power * 0.25, 40)
              )
            WHEN 1 THEN
              abs(u.level - v_level) <= 10
              OR abs(COALESCE(u.pvp_rating, 1000) - v_rating) <= 500
              OR (
                v_power > 0
                AND abs(COALESCE(u.power, 0) - v_power)::NUMERIC <= GREATEST(v_power * 0.50, 80)
              )
            ELSE TRUE
          END
        )
    ),
    picked AS (
      SELECT *
      FROM candidates
      ORDER BY random()
      LIMIT v_limit
    )
    INSERT INTO public.matchmaking_offers (
      seeker_id, opponent_id, mode,
      snapshot_level, snapshot_power, snapshot_rating
    )
    SELECT
      v_me, p.auth_id, p_mode,
      p.level, p.power, p.pvp_rating
    FROM picked p;

    IF (SELECT count(*) FROM public.matchmaking_offers
        WHERE seeker_id = v_me AND mode = p_mode AND status = 'open'
          AND created_at > now() - interval '5 seconds') >= LEAST(3, v_limit)
       OR v_band_used = 2
    THEN
      EXIT;
    END IF;

    -- Not enough → clear partial and widen
    IF (SELECT count(*) FROM public.matchmaking_offers
        WHERE seeker_id = v_me AND mode = p_mode AND status = 'open'
          AND created_at > now() - interval '5 seconds') < LEAST(3, v_limit)
       AND v_band_used < 2
    THEN
      UPDATE public.matchmaking_offers
      SET status = 'expired'
      WHERE seeker_id = v_me AND mode = p_mode AND status = 'open';
    END IF;
  END LOOP;

  SELECT count(*)::INT INTO v_remaining
  FROM public.matchmaking_offers
  WHERE seeker_id = v_me
    AND mode = p_mode
    AND status = 'open'
    AND expires_at > now();

  -- Empty pool → no refresh lock (retry OK)
  IF v_remaining > 0 THEN
    INSERT INTO public.matchmaking_refresh_state (seeker_id, mode, last_refresh_at)
    VALUES (v_me, p_mode, now())
    ON CONFLICT (seeker_id, mode)
    DO UPDATE SET last_refresh_at = excluded.last_refresh_at;
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'offer_id', o.id,
    'auth_id', u.auth_id,
    'username', u.username,
    'display_name', COALESCE(NULLIF(u.display_name, ''), u.username),
    'avatar_url', u.avatar_url,
    'level', u.level,
    'power', COALESCE(u.power, 0),
    'pvp_rating', COALESCE(u.pvp_rating, 1000),
    'attack', u.attack,
    'defense', u.defense,
    'expires_at', o.expires_at
  ) ORDER BY random())
  INTO v_rows
  FROM public.matchmaking_offers o
  JOIN public.users u ON u.auth_id = o.opponent_id
  WHERE o.seeker_id = v_me
    AND o.mode = p_mode
    AND o.status = 'open'
    AND o.expires_at > now();

  IF v_remaining > 0 THEN
    v_next_refresh := now() + make_interval(secs => v_refresh_cd);
    RETURN jsonb_build_object(
      'success', true,
      'offers', COALESCE(v_rows, '[]'::jsonb),
      'opponents', COALESCE(v_rows, '[]'::jsonb),
      'refresh_cooldown_sec', v_refresh_cd,
      'can_refresh', false,
      'next_refresh_at', v_next_refresh,
      'refresh_in_sec', v_refresh_cd,
      'band_tier_used', v_band_used
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'offers', '[]'::jsonb,
    'opponents', '[]'::jsonb,
    'refresh_cooldown_sec', v_refresh_cd,
    'can_refresh', true,
    'next_refresh_at', NULL,
    'refresh_in_sec', 0,
    'band_tier_used', v_band_used
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_matchmaking_offers(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_matchmaking_offers(TEXT) TO authenticated;

-- Thin wrappers
CREATE OR REPLACE FUNCTION public.get_arena_opponent_offers()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public.get_matchmaking_offers('arena');
$$;

CREATE OR REPLACE FUNCTION public.get_pvp_opponent_offers()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public.get_matchmaking_offers('duel');
$$;

REVOKE ALL ON FUNCTION public.get_arena_opponent_offers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_pvp_opponent_offers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_arena_opponent_offers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pvp_opponent_offers() TO authenticated;

-- Replace legacy arena list → offer-backed
CREATE OR REPLACE FUNCTION public.get_arena_opponents(p_limit integer DEFAULT 15)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- p_limit ignored (server fixed N=6). Kept for signature compat.
  RETURN public.get_matchmaking_offers('arena');
END;
$$;

-- Replace online dump → duel offers (anti full-player scrape)
CREATE OR REPLACE FUNCTION public.get_online_players(p_limit INT DEFAULT 30)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_res JSONB;
BEGIN
  -- p_limit ignored. Returns offer envelope (not raw online dump).
  v_res := public.get_matchmaking_offers('duel');
  -- Backward: some clients expected a bare array — keep envelope for new clients.
  RETURN v_res;
END;
$$;

-- ── Gate arena fight on offer ────────────────────────────────
DROP FUNCTION IF EXISTS public.mekan_pvp_bet(uuid, uuid, bigint);

CREATE OR REPLACE FUNCTION public.mekan_pvp_bet(
  p_defender_id uuid,
  p_mekan_id uuid,
  p_wager bigint,
  p_offer_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_gate JSONB;
  v_offer JSONB;
BEGIN
  IF p_offer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Eşleşme teklifi gerekli. Listeyi yenile.'
    );
  END IF;

  v_offer := public.consume_matchmaking_offer(p_offer_id, 'arena', p_defender_id);
  IF COALESCE(v_offer->>'success', 'false') <> 'true' THEN
    RETURN v_offer;
  END IF;

  v_gate := public.enforce_rate_limit('arena', 15, 300);
  IF v_gate IS NOT NULL THEN
    RETURN v_gate;
  END IF;

  RETURN public.mekan_pvp_bet_rl_inner(p_defender_id, p_mekan_id, p_wager);
END;
$$;

REVOKE ALL ON FUNCTION public.mekan_pvp_bet(uuid, uuid, bigint, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.mekan_pvp_bet(uuid, uuid, bigint, uuid) TO authenticated;

-- ── Gate duel invite: offer OR revenge/friend ────────────────
DROP FUNCTION IF EXISTS public.send_pvp_invite(uuid, bigint);

CREATE OR REPLACE FUNCTION public.send_pvp_invite(
  p_target UUID,
  p_wager BIGINT DEFAULT 0,
  p_offer_id UUID DEFAULT NULL,
  p_source TEXT DEFAULT 'discovery'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_challenger RECORD;
  v_target RECORD;
  v_invite_id UUID;
  v_open_status TEXT;
  v_source TEXT := lower(coalesce(p_source, 'discovery'));
  v_offer JSONB;
  v_nemesis UUID;
  v_is_friend BOOLEAN := false;
  v_gate JSONB;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_target = v_me THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendine davet gönderemezsin');
  END IF;

  IF p_wager < 0 OR p_wager > 5000000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz bahis (0 - 5.000.000)');
  END IF;

  IF v_source NOT IN ('discovery', 'revenge', 'friend') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz davet kaynağı');
  END IF;

  v_gate := public.enforce_rate_limit('pvp_invite', 20, 300);
  IF v_gate IS NOT NULL THEN
    RETURN v_gate;
  END IF;

  SELECT * INTO v_challenger FROM public.users WHERE auth_id = v_me;
  SELECT * INTO v_target FROM public.users WHERE auth_id = p_target;
  IF v_target IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı');
  END IF;

  IF p_wager > 0 AND v_challenger.gold < p_wager THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın');
  END IF;

  IF v_source = 'discovery' THEN
    IF p_offer_id IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Eşleşme teklifi gerekli. Listeyi yenile.'
      );
    END IF;
    v_offer := public.consume_matchmaking_offer(p_offer_id, 'duel', p_target);
    IF COALESCE(v_offer->>'success', 'false') <> 'true' THEN
      RETURN v_offer;
    END IF;
  ELSIF v_source = 'revenge' THEN
    SELECT nemesis_id INTO v_nemesis
    FROM public.player_nemesis_state
    WHERE player_id = v_me;
    IF v_nemesis IS NULL OR v_nemesis <> p_target THEN
      RETURN jsonb_build_object('success', false, 'error', 'Nemesis hedefi geçersiz');
    END IF;
  ELSIF v_source = 'friend' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.friendships f
      WHERE f.status = 'accepted'
        AND (
          (f.requester_id = v_me AND f.addressee_id = p_target)
          OR (f.requester_id = p_target AND f.addressee_id = v_me)
        )
    ) INTO v_is_friend;
    IF NOT v_is_friend THEN
      RETURN jsonb_build_object('success', false, 'error', 'Sadece arkadaşlara davet');
    END IF;
  END IF;

  UPDATE public.pvp_invites SET status = 'expired'
  WHERE status = 'pending' AND expires_at <= now();

  SELECT i.status INTO v_open_status
  FROM public.pvp_invites i
  WHERE (
      (i.challenger_id = v_me AND i.target_id = p_target)
      OR (i.challenger_id = p_target AND i.target_id = v_me)
    )
    AND (
      i.status = 'pending'
      OR (i.status = 'accepted' AND i.challenger_seen = false)
    )
  LIMIT 1;

  IF v_open_status IS NOT NULL THEN
    IF v_open_status = 'pending' THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Bu rakiple bekleyen düello daveti var'
      );
    END IF;
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bu rakiple düello devam ediyor'
    );
  END IF;

  BEGIN
    INSERT INTO public.pvp_invites (challenger_id, target_id, wager)
    VALUES (v_me, p_target, p_wager)
    RETURNING id INTO v_invite_id;
  EXCEPTION
    WHEN unique_violation THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Bu rakiple bekleyen düello daveti var'
      );
  END;

  RETURN jsonb_build_object('success', true, 'invite_id', v_invite_id);
END;
$$;

REVOKE ALL ON FUNCTION public.send_pvp_invite(UUID, BIGINT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_pvp_invite(UUID, BIGINT, UUID, TEXT) TO authenticated;

COMMIT;
