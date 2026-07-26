-- ============================================================
-- Shared hospital/prison combat gate + wire into fight RPCs
-- Authoritative: users.hospital_until / prison_until > now()
-- ============================================================

BEGIN;

-- ── Shared assert ────────────────────────────────────────────
-- Returns NULL when player is free to fight.
-- p_as_target=true → opponent-facing Turkish messages.
CREATE OR REPLACE FUNCTION public.assert_player_combat_ready(
  p_user_id UUID,
  p_as_target BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_hospital TIMESTAMPTZ;
  v_prison TIMESTAMPTZ;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Oturum bulunamadı.',
      'error_code', 'not_authenticated'
    );
  END IF;

  SELECT u.hospital_until, u.prison_until
  INTO v_hospital, v_prison
  FROM public.users u
  WHERE u.auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE WHEN p_as_target THEN 'Rakip bulunamadı.' ELSE 'Oyuncu bulunamadı.' END,
      'error_code', 'player_not_found'
    );
  END IF;

  IF v_hospital IS NOT NULL AND v_hospital > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN p_as_target THEN 'Rakip hastanede.'
        ELSE 'Hastanedeyken savaşamazsın.'
      END,
      'error_code', 'in_hospital',
      'hospital_until', v_hospital
    );
  END IF;

  IF v_prison IS NOT NULL AND v_prison > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN p_as_target THEN 'Rakip hapiste.'
        ELSE 'Hapisteyken savaşamazsın.'
      END,
      'error_code', 'in_prison',
      'prison_until', v_prison
    );
  END IF;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_player_combat_ready(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assert_player_combat_ready(UUID, BOOLEAN) TO authenticated;

-- Keep siege helper in sync with shared assert
CREATE OR REPLACE FUNCTION public.dungeon_siege_can_fight(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT public.assert_player_combat_ready(p_user_id, false) IS NULL;
$$;

-- ── send_pvp_invite: gate challenger + target ────────────────
CREATE OR REPLACE FUNCTION public.send_pvp_invite(
  p_target UUID,
  p_wager BIGINT DEFAULT 0,
  p_offer_id UUID DEFAULT NULL::UUID,
  p_source TEXT DEFAULT 'discovery'::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
  v_combat JSONB;
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

  v_combat := public.assert_player_combat_ready(v_me, false);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat;
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

  v_combat := public.assert_player_combat_ready(p_target, true);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat;
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

-- ── respond_pvp_invite: gate both sides on accept only ───────
CREATE OR REPLACE FUNCTION public.respond_pvp_invite(
  p_invite_id UUID,
  p_accept BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_me UUID;
  v_invite RECORD;
  v_challenger RECORD;
  v_target RECORD;
  v_att_power NUMERIC;
  v_def_power NUMERIC;
  v_win_chance NUMERIC;
  v_winner_id UUID;
  v_loser_id UUID;
  v_pool BIGINT := 0;
  v_tax BIGINT := 0;
  v_net_win BIGINT := 0;
  v_ch_rating INT;
  v_tg_rating INT;
  v_result JSONB;
  v_nemesis_bonus JSONB;
  v_combat JSONB;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_invite
  FROM public.pvp_invites
  WHERE id = p_invite_id AND target_id = v_me AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Davet bulunamadı');
  END IF;

  IF v_invite.expires_at <= now() THEN
    UPDATE public.pvp_invites SET status = 'expired' WHERE id = p_invite_id;
    RETURN jsonb_build_object('success', false, 'error', 'Davetin süresi doldu');
  END IF;

  -- Decline always allowed while restricted
  IF NOT p_accept THEN
    UPDATE public.pvp_invites SET status = 'declined' WHERE id = p_invite_id;
    RETURN jsonb_build_object('success', true, 'declined', true);
  END IF;

  v_combat := public.assert_player_combat_ready(v_me, false);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat;
  END IF;

  v_combat := public.assert_player_combat_ready(v_invite.challenger_id, true);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat;
  END IF;

  SELECT * INTO v_challenger FROM public.users WHERE auth_id = v_invite.challenger_id FOR UPDATE;
  SELECT * INTO v_target FROM public.users WHERE auth_id = v_me FOR UPDATE;

  IF v_challenger IS NULL OR v_target IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı');
  END IF;

  IF v_invite.wager > 0 THEN
    IF v_challenger.gold < v_invite.wager THEN
      UPDATE public.pvp_invites SET status = 'expired' WHERE id = p_invite_id;
      RETURN jsonb_build_object('success', false, 'error', 'Rakibin altını yetersiz');
    END IF;
    IF v_target.gold < v_invite.wager THEN
      RETURN jsonb_build_object('success', false, 'error', 'Bahis için altının yetersiz');
    END IF;
  END IF;

  v_att_power := COALESCE(v_challenger.attack, 10) + COALESCE(v_challenger.defense, 10);
  v_def_power := COALESCE(v_target.attack, 10) + COALESCE(v_target.defense, 10);
  IF COALESCE(v_challenger.character_class, '') = 'shadow' THEN v_att_power := v_att_power * 1.15; END IF;
  IF COALESCE(v_target.character_class, '') = 'shadow' THEN v_def_power := v_def_power * 1.15; END IF;

  v_win_chance := v_att_power / NULLIF(v_att_power + v_def_power, 0);
  IF v_win_chance IS NULL THEN v_win_chance := 0.5; END IF;

  IF random() <= v_win_chance THEN
    v_winner_id := v_invite.challenger_id;
    v_loser_id := v_me;
    v_ch_rating := 15 + floor(random() * 10)::INT;
    v_tg_rating := -(10 + floor(random() * 5)::INT);
  ELSE
    v_winner_id := v_me;
    v_loser_id := v_invite.challenger_id;
    v_ch_rating := -(10 + floor(random() * 5)::INT);
    v_tg_rating := 15 + floor(random() * 10)::INT;
  END IF;

  IF v_invite.wager > 0 THEN
    v_pool := v_invite.wager * 2;
    v_tax := floor(v_pool * 0.05)::BIGINT;
    v_net_win := v_pool - v_tax;

    UPDATE public.users SET gold = gold - v_invite.wager
    WHERE auth_id = v_invite.challenger_id AND gold >= v_invite.wager;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Rakibin altını yetersiz kaldı');
    END IF;

    UPDATE public.users SET gold = gold - v_invite.wager
    WHERE auth_id = v_me AND gold >= v_invite.wager;
    IF NOT FOUND THEN
      UPDATE public.users SET gold = gold + v_invite.wager WHERE auth_id = v_invite.challenger_id;
      RETURN jsonb_build_object('success', false, 'error', 'Altının yetersiz kaldı');
    END IF;

    UPDATE public.users SET gold = gold + v_net_win WHERE auth_id = v_winner_id;
  END IF;

  UPDATE public.users SET
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_ch_rating),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_invite.challenger_id THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_invite.challenger_id THEN 1 ELSE 0 END
  WHERE auth_id = v_invite.challenger_id;

  UPDATE public.users SET
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_tg_rating),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_me THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_me THEN 1 ELSE 0 END
  WHERE auth_id = v_me;

  v_result := jsonb_build_object(
    'winner_id', v_winner_id,
    'challenger_won', v_winner_id = v_invite.challenger_id,
    'wager', v_invite.wager,
    'net_win', v_net_win,
    'tax', v_tax,
    'challenger_rating_change', v_ch_rating,
    'target_rating_change', v_tg_rating,
    'challenger_name', COALESCE(v_challenger.display_name, v_challenger.username),
    'target_name', COALESCE(v_target.display_name, v_target.username)
  );

  -- [GKK_NEMESIS_REVENGE_GOLD_BEGIN]
  v_nemesis_bonus := public._nemesis_revenge_gold_bonus(v_winner_id, v_loser_id, p_invite_id);
  IF COALESCE(v_nemesis_bonus->>'granted', 'false') = 'true' THEN
    v_result := v_result || jsonb_build_object(
      'nemesis_revenge_granted', true,
      'nemesis_revenge_gold', (v_nemesis_bonus->>'gold')::BIGINT
    );
  END IF;
  -- [GKK_NEMESIS_REVENGE_GOLD_END]

  UPDATE public.pvp_invites
  SET status = 'accepted', result = v_result
  WHERE id = p_invite_id;

  RETURN jsonb_build_object('success', true, 'declined', false, 'duel', v_result);
END;
$$;

-- ── consume_matchmaking_offer: gate seeker + fix until>now ───
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
  v_combat JSONB;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_combat := public.assert_player_combat_ready(v_me, false);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat;
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

  v_combat := public.assert_player_combat_ready(p_expected_opponent, true);
  IF v_combat IS NOT NULL THEN
    UPDATE public.matchmaking_offers SET status = 'expired' WHERE id = p_offer_id;
    RETURN v_combat;
  END IF;

  v_power := COALESCE(v_opp.power, 0);

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

-- ── attack_guild_war_territory ───────────────────────────────
CREATE OR REPLACE FUNCTION public.attack_guild_war_territory(p_territory_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_player_id UUID := auth.uid();
  v_guild_id UUID;
  v_territory RECORD;
  v_attack_power INTEGER;
  v_effective_defense INTEGER;
  v_success BOOLEAN;
  v_points_gained INTEGER;
  v_active_season_id UUID;
  v_rep_gain INTEGER := 0;
  v_combat JSONB;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_combat := public.assert_player_combat_ready(v_player_id, false);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat::json;
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_player_id;
  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  SELECT COALESCE(level * 50, 100) INTO v_attack_power FROM public.users WHERE auth_id = v_player_id;
  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power,
    v_territory.gem_defense_boost
  );
  v_success := (random() * v_attack_power) > (random() * GREATEST(v_effective_defense, 1));
  v_points_gained := CASE WHEN v_success THEN 100 ELSE 10 END;
  v_rep_gain := CASE WHEN v_success THEN 20 ELSE 5 END;

  SELECT id INTO v_active_season_id
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_active_season_id IS NOT NULL THEN
    INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
    VALUES (
      v_active_season_id,
      v_guild_id,
      v_points_gained,
      CASE WHEN v_success THEN 1 ELSE 0 END,
      CASE WHEN v_success THEN 0 ELSE 1 END
    )
    ON CONFLICT (season_id, guild_id) DO UPDATE SET
      points = guild_war_rankings.points + v_points_gained,
      wins = guild_war_rankings.wins + (CASE WHEN v_success THEN 1 ELSE 0 END),
      losses = guild_war_rankings.losses + (CASE WHEN v_success THEN 0 ELSE 1 END),
      updated_at = now();
  END IF;

  IF v_success THEN
    UPDATE public.guild_war_territories
    SET owner_guild_id = v_guild_id,
        defense_power = v_attack_power,
        gem_defense_boost = 0,
        updated_at = now()
    WHERE id = p_territory_id;
  END IF;

  UPDATE public.users
  SET reputation = COALESCE(reputation, 0) + v_rep_gain
  WHERE auth_id = v_player_id;

  PERFORM public._log_reputation_activity(
    v_player_id, 'earn', 'guild_war', v_rep_gain, 'global', NULL,
    jsonb_build_object(
      'territory_id', p_territory_id,
      'attack_success', v_success,
      'points_gained', v_points_gained
    )
  );

  INSERT INTO public.guild_war_attack_logs (
    territory_id, attacker_guild_id, defender_guild_id,
    attack_power, defense_power, success, points_gained
  ) VALUES (
    p_territory_id, v_guild_id, v_territory.owner_guild_id,
    v_attack_power, v_effective_defense, v_success, v_points_gained
  );

  RETURN json_build_object(
    'success', v_success,
    'message', CASE WHEN v_success THEN 'Bölge ele geçirildi!' ELSE 'Saldırı başarısız!' END,
    'attack_power', v_attack_power,
    'defense_power', v_effective_defense,
    'points_gained', v_points_gained,
    'rep_gained', v_rep_gain
  );
END;
$$;

-- ── join_guild_war ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.join_guild_war(p_tournament_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_player_id UUID := auth.uid();
  v_guild_id UUID;
  v_combat JSONB;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_combat := public.assert_player_combat_ready(v_player_id, false);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat::json;
  END IF;

  SELECT guild_id INTO v_guild_id
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.guild_war_participants
    WHERE tournament_id = p_tournament_id AND guild_id = v_guild_id
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Zaten bu turnuvaya katıldınız.');
  END IF;

  INSERT INTO public.guild_war_participants (tournament_id, guild_id)
  VALUES (p_tournament_id, v_guild_id);

  UPDATE public.guild_war_tournaments
  SET guild_count = guild_count + 1
  WHERE id = p_tournament_id;

  RETURN json_build_object('success', true, 'message', 'Turnuvaya katıldınız!');
END;
$$;

-- ── Patch large bodies via string inject ─────────────────────
DO $$
DECLARE
  v_def TEXT;
BEGIN
  -- mekan_pvp_bet_rl_inner: attacker + defender
  SELECT pg_get_functiondef('public.mekan_pvp_bet_rl_inner(uuid, uuid, bigint)'::regprocedure)
  INTO v_def;

  IF v_def IS NOT NULL AND position('assert_player_combat_ready' IN v_def) = 0 THEN
    IF position('v_defender_name TEXT;' IN v_def) > 0 THEN
      v_def := replace(
        v_def,
        'v_defender_name TEXT;',
        E'v_defender_name TEXT;\n  v_combat JSONB;'
      );
    ELSIF position('v_defender_name text;' IN lower(v_def)) > 0 THEN
      v_def := regexp_replace(
        v_def,
        'v_defender_name\s+TEXT;',
        E'v_defender_name TEXT;\n  v_combat JSONB;',
        'i'
      );
    ELSE
      RAISE EXCEPTION 'mekan_pvp_bet_rl_inner: declare marker missing';
    END IF;

    IF position('Oyuncu bulunamadi' IN v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'IF v_attacker IS NULL OR v_defender IS NULL THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Oyuncu bulunamadi'');\n  END IF;',
        E'IF v_attacker IS NULL OR v_defender IS NULL THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Oyuncu bulunamadi'');\n  END IF;\n\n  v_combat := public.assert_player_combat_ready(v_attacker_id, false);\n  IF v_combat IS NOT NULL THEN RETURN v_combat; END IF;\n  v_combat := public.assert_player_combat_ready(p_defender_id, true);\n  IF v_combat IS NOT NULL THEN RETURN v_combat; END IF;'
      );
    ELSE
      RAISE EXCEPTION 'mekan_pvp_bet_rl_inner: player-null marker missing';
    END IF;

    EXECUTE v_def;
  END IF;

  -- get_matchmaking_offers: block seeker refresh while restricted
  SELECT pg_get_functiondef('public.get_matchmaking_offers(text)'::regprocedure)
  INTO v_def;

  IF v_def IS NOT NULL AND position('assert_player_combat_ready' IN v_def) = 0 THEN
    IF position('v_newbie_cap INT;' IN v_def) > 0 THEN
      v_def := replace(
        v_def,
        'v_newbie_cap INT;',
        E'v_newbie_cap INT;\n  v_combat JSONB;'
      );
    ELSE
      v_def := replace(
        v_def,
        'v_gate JSONB;',
        E'v_gate JSONB;\n  v_combat JSONB;'
      );
    END IF;

    v_def := replace(
      v_def,
      E'IF v_level IS NULL THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Profil bulunamadı.'');\n  END IF;',
      E'IF v_level IS NULL THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Profil bulunamadı.'');\n  END IF;\n\n  v_combat := public.assert_player_combat_ready(v_me, false);\n  IF v_combat IS NOT NULL THEN\n    RETURN v_combat;\n  END IF;'
    );

    -- Opponent pool: require until past / null (not mere IS NULL)
    v_def := replace(
      v_def,
      E'AND u.hospital_until IS NULL\n        AND u.prison_until IS NULL',
      E'AND (u.hospital_until IS NULL OR u.hospital_until <= now())\n        AND (u.prison_until IS NULL OR u.prison_until <= now())'
    );

    EXECUTE v_def;
  END IF;

  -- start_siege_guild_hold
  SELECT pg_get_functiondef('public.start_siege_guild_hold(text)'::regprocedure)
  INTO v_def;

  IF v_def IS NOT NULL AND position('assert_player_combat_ready' IN v_def) = 0 THEN
    v_def := replace(
      v_def,
      E'IF NOT FOUND THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Oyuncu profili bulunamadı.'');\n  END IF;\n\n  IF v_player.guild_id IS NULL THEN',
      E'IF NOT FOUND THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Oyuncu profili bulunamadı.'');\n  END IF;\n\n  IF NOT public.dungeon_siege_can_fight(v_me) THEN\n    RETURN jsonb_build_object(''success'', false, ''error'', ''Hastane/cezaevinde hold başlatamazsın.'');\n  END IF;\n\n  IF v_player.guild_id IS NULL THEN'
    );
    EXECUTE v_def;
  END IF;
END $$;

COMMIT;
