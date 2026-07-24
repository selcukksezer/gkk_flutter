-- PvP retention fixes: weekly arena claim, quest/BP triggers, tournament close, arena notifications
BEGIN;

-- ── 1) Haftalık arena ödül snapshot + claim ─────────────────────────────────

CREATE TABLE IF NOT EXISTS public.pvp_arena_weekly_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start DATE NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rank INT NOT NULL CHECK (rank > 0),
  reward_gold BIGINT NOT NULL DEFAULT 0 CHECK (reward_gold >= 0),
  claimed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (week_start, user_id)
);

CREATE INDEX IF NOT EXISTS idx_pvp_arena_weekly_snapshots_user
  ON public.pvp_arena_weekly_snapshots (user_id, week_start DESC);

ALTER TABLE public.pvp_arena_weekly_snapshots ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pvp_arena_weekly_snapshots'
      AND policyname = 'pvp_arena_weekly_snapshots_own_read'
  ) THEN
    CREATE POLICY pvp_arena_weekly_snapshots_own_read
      ON public.pvp_arena_weekly_snapshots FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public._pvp_weekly_reward_for_rank(p_rank INT)
RETURNS BIGINT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_rank = 1 THEN RETURN 2000000; END IF;
  IF p_rank BETWEEN 2 AND 5 THEN RETURN 1000000; END IF;
  IF p_rank BETWEEN 6 AND 10 THEN RETURN 500000; END IF;
  IF p_rank BETWEEN 11 AND 25 THEN RETURN 200000; END IF;
  IF p_rank BETWEEN 26 AND 50 THEN RETURN 100000; END IF;
  RETURN 0;
END;
$$;

CREATE OR REPLACE FUNCTION public.snapshot_pvp_arena_weekly_rewards(p_week_start DATE DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_week_start DATE := COALESCE(p_week_start, (date_trunc('week', CURRENT_DATE)::DATE - 7));
  v_inserted INT := 0;
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.pvp_arena_weekly_snapshots WHERE week_start = v_week_start LIMIT 1
  ) THEN
    RETURN jsonb_build_object(
      'success', true,
      'week_start', v_week_start,
      'inserted', 0,
      'message', 'Snapshot already exists'
    );
  END IF;

  INSERT INTO public.pvp_arena_weekly_snapshots (week_start, user_id, rank, reward_gold)
  SELECT
    v_week_start,
    rnk.auth_id,
    rnk.rank::INT,
    public._pvp_weekly_reward_for_rank(rnk.rank::INT)
  FROM (
    SELECT auth_id, ROW_NUMBER() OVER (ORDER BY COALESCE(pvp_rating, 1000) DESC) AS rank
    FROM public.users
  ) rnk
  WHERE rnk.rank <= 50
    AND public._pvp_weekly_reward_for_rank(rnk.rank::INT) > 0;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'week_start', v_week_start,
    'inserted', v_inserted
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_arena_weekly_reward_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_claimable_week DATE;
  v_row RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadi');
  END IF;

  -- Claim window: Mon-Wed of current week for previous week's snapshot
  IF EXTRACT(ISODOW FROM CURRENT_DATE)::INT > 3 THEN
    RETURN jsonb_build_object(
      'success', true,
      'claim_open', false,
      'reward_gold', 0,
      'rank', 0,
      'week_start', NULL
    );
  END IF;

  v_claimable_week := date_trunc('week', CURRENT_DATE)::DATE - 7;

  SELECT * INTO v_row
  FROM public.pvp_arena_weekly_snapshots
  WHERE week_start = v_claimable_week
    AND user_id = v_uid
    AND reward_gold > 0
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'claim_open', true,
      'reward_gold', 0,
      'rank', 0,
      'week_start', v_claimable_week,
      'already_claimed', false
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'claim_open', true,
    'reward_gold', v_row.reward_gold,
    'rank', v_row.rank,
    'week_start', v_row.week_start,
    'already_claimed', v_row.claimed_at IS NOT NULL,
    'claimed_at', v_row.claimed_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_arena_weekly_reward()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_claimable_week DATE;
  v_row RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadi');
  END IF;

  IF EXTRACT(ISODOW FROM CURRENT_DATE)::INT > 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Odul alma suresi kapandi (Pzt-Car)');
  END IF;

  v_claimable_week := date_trunc('week', CURRENT_DATE)::DATE - 7;

  SELECT * INTO v_row
  FROM public.pvp_arena_weekly_snapshots
  WHERE week_start = v_claimable_week
    AND user_id = v_uid
    AND reward_gold > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu hafta odul hakkiniz yok');
  END IF;

  IF v_row.claimed_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Odul zaten alindi');
  END IF;

  UPDATE public.users
  SET gold = gold + v_row.reward_gold
  WHERE auth_id = v_uid;

  UPDATE public.pvp_arena_weekly_snapshots
  SET claimed_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'success', true,
    'reward_gold', v_row.reward_gold,
    'rank', v_row.rank,
    'week_start', v_row.week_start
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.snapshot_pvp_arena_weekly_rewards(DATE) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_arena_weekly_reward_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_arena_weekly_reward() TO authenticated;

-- ── 2) Quest + Battle Pass — arena + davet maçları ──────────────────────────

CREATE OR REPLACE FUNCTION public._pvp_apply_match_progress(p_winner_id UUID, p_loser_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_winner_id IS NULL THEN
    RETURN;
  END IF;

  PERFORM public.increment_quest_progress(p_winner_id, 'pvp_win', 1);

  IF p_loser_id IS NOT NULL AND p_loser_id <> p_winner_id THEN
    PERFORM public.bp_trigger_pvp_match(p_winner_id, true);
    PERFORM public.bp_trigger_pvp_match(p_loser_id, false);
  ELSE
    PERFORM public.bp_trigger_pvp_match(p_winner_id, true);
  END IF;

  PERFORM public.bp_trigger_pvp_win(p_winner_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_mekan_pvp_matches_progress_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_loser UUID;
BEGIN
  IF NEW.winner_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_loser := CASE
    WHEN NEW.winner_id = NEW.attacker_id THEN NEW.defender_id
    ELSE NEW.attacker_id
  END;

  PERFORM public._pvp_apply_match_progress(NEW.winner_id, v_loser);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mekan_pvp_matches_progress ON public.mekan_pvp_matches;
CREATE TRIGGER trg_mekan_pvp_matches_progress
AFTER INSERT ON public.mekan_pvp_matches
FOR EACH ROW
EXECUTE FUNCTION public.trg_mekan_pvp_matches_progress_fn();

CREATE OR REPLACE FUNCTION public.trg_pvp_invite_progress_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_winner UUID;
  v_loser UUID;
BEGIN
  IF NEW.status = 'accepted'
     AND NEW.result IS NOT NULL
     AND (OLD.result IS DISTINCT FROM NEW.result)
  THEN
    v_winner := NULLIF(NEW.result->>'winner_id', '')::UUID;
    IF v_winner IS NULL THEN
      RETURN NEW;
    END IF;

    IF v_winner = NEW.challenger_id THEN
      v_loser := NEW.target_id;
    ELSE
      v_loser := NEW.challenger_id;
    END IF;

    PERFORM public._pvp_apply_match_progress(v_winner, v_loser);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pvp_invite_progress ON public.pvp_invites;
CREATE TRIGGER trg_pvp_invite_progress
AFTER UPDATE OF status, result ON public.pvp_invites
FOR EACH ROW
EXECUTE FUNCTION public.trg_pvp_invite_progress_fn();

-- ── 3) Turnuva — kayıt kapanışı + boş bracket mesajı ───────────────────────

ALTER TABLE public.pvp_tournaments
  ADD COLUMN IF NOT EXISTS cancel_reason TEXT;

CREATE OR REPLACE FUNCTION public.maybe_close_pvp_tournament_registration(p_tournament_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tournament RECORD;
  v_count INT;
BEGIN
  SELECT * INTO v_tournament
  FROM public.pvp_tournaments
  WHERE id = p_tournament_id;

  IF NOT FOUND OR v_tournament.status <> 'registration' THEN
    RETURN;
  END IF;

  IF CURRENT_TIMESTAMP < (v_tournament.week_start + INTERVAL '3 days') THEN
    RETURN;
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.pvp_tournament_participants
  WHERE tournament_id = p_tournament_id;

  IF v_count >= 2 THEN
    PERFORM public.seed_pvp_tournament_bracket(p_tournament_id);
    UPDATE public.pvp_tournaments
    SET registration_open = false,
        status = 'active',
        cancel_reason = NULL,
        updated_at = now()
    WHERE id = p_tournament_id;
  ELSE
    UPDATE public.pvp_tournaments
    SET registration_open = false,
        status = 'completed',
        cancel_reason = 'insufficient_players',
        updated_at = now()
    WHERE id = p_tournament_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_tournament_bracket()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tournament_id UUID;
  v_tournament RECORD;
  v_rounds JSONB := '[]'::jsonb;
  v_champion_name TEXT := '';
  rec_round RECORD;
  v_matches JSONB;
  v_participant_count INT;
BEGIN
  v_tournament_id := public.ensure_current_pvp_tournament();

  SELECT * INTO v_tournament
  FROM public.pvp_tournaments
  WHERE id = v_tournament_id;

  PERFORM public.maybe_close_pvp_tournament_registration(v_tournament_id);

  SELECT * INTO v_tournament
  FROM public.pvp_tournaments
  WHERE id = v_tournament_id;

  SELECT COUNT(*) INTO v_participant_count
  FROM public.pvp_tournament_participants
  WHERE tournament_id = v_tournament_id;

  IF v_tournament.status = 'registration' AND v_participant_count >= 2 THEN
    PERFORM public.seed_pvp_tournament_bracket(v_tournament_id);
  END IF;

  IF v_tournament.champion_user_id IS NOT NULL THEN
    SELECT username INTO v_champion_name
    FROM public.users
    WHERE auth_id = v_tournament.champion_user_id;
  ELSIF EXISTS (
    SELECT 1 FROM public.pvp_tournament_matches
    WHERE tournament_id = v_tournament_id AND round_number = (
      SELECT MAX(round_number) FROM public.pvp_tournament_matches WHERE tournament_id = v_tournament_id
    ) AND status = 'completed' AND winner_id IS NOT NULL
  ) THEN
    SELECT u.username INTO v_champion_name
    FROM public.pvp_tournament_matches m
    JOIN public.users u ON u.auth_id = m.winner_id
    WHERE m.tournament_id = v_tournament_id
      AND m.round_number = (SELECT MAX(round_number) FROM public.pvp_tournament_matches WHERE tournament_id = v_tournament_id)
      AND m.status = 'completed'
    ORDER BY m.match_order
    LIMIT 1;
  END IF;

  FOR rec_round IN
    SELECT DISTINCT round_number, round_name
    FROM public.pvp_tournament_matches
    WHERE tournament_id = v_tournament_id
    ORDER BY round_number
  LOOP
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', m.id,
      'player1_name', COALESCE(u1.username, CASE WHEN m.player1_id IS NULL THEN 'BYE' ELSE '?' END),
      'player2_name', COALESCE(u2.username, CASE WHEN m.player2_id IS NULL THEN 'BYE' ELSE '?' END),
      'player1_score', m.player1_score,
      'player2_score', m.player2_score,
      'winner_name', COALESCE(uw.username, ''),
      'status', m.status
    ) ORDER BY m.match_order), '[]'::jsonb)
    INTO v_matches
    FROM public.pvp_tournament_matches m
    LEFT JOIN public.users u1 ON u1.auth_id = m.player1_id
    LEFT JOIN public.users u2 ON u2.auth_id = m.player2_id
    LEFT JOIN public.users uw ON uw.auth_id = m.winner_id
    WHERE m.tournament_id = v_tournament_id
      AND m.round_number = rec_round.round_number;

    v_rounds := v_rounds || jsonb_build_array(jsonb_build_object(
      'title', rec_round.round_name,
      'round_number', rec_round.round_number,
      'matches', v_matches
    ));
  END LOOP;

  RETURN jsonb_build_object(
    'tournament_id', v_tournament_id,
    'tournament_name', v_tournament.name,
    'champion_name', COALESCE(v_champion_name, ''),
    'registration_open', v_tournament.registration_open,
    'status', v_tournament.status,
    'participant_count', v_participant_count,
    'min_participants', 2,
    'cancel_reason', v_tournament.cancel_reason,
    'prize_pool', v_tournament.prize_pool,
    'rounds', v_rounds
  );
END;
$$;

-- ── 4) Arena kaybı / savunma bildirimi ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.pvp_arena_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  match_id UUID REFERENCES public.mekan_pvp_matches(id) ON DELETE CASCADE,
  opponent_name TEXT NOT NULL DEFAULT 'Rakip',
  wager BIGINT NOT NULL DEFAULT 0,
  rating_change INT NOT NULL DEFAULT 0,
  won BOOLEAN NOT NULL DEFAULT false,
  seen BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pvp_arena_notifications_unseen
  ON public.pvp_arena_notifications (user_id, created_at DESC)
  WHERE seen = false;

ALTER TABLE public.pvp_arena_notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pvp_arena_notifications'
      AND policyname = 'pvp_arena_notifications_own'
  ) THEN
    CREATE POLICY pvp_arena_notifications_own
      ON public.pvp_arena_notifications
      USING (auth.uid() = user_id);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.get_unseen_arena_pvp_results()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me UUID := auth.uid();
  v_rows JSONB;
BEGIN
  IF v_me IS NULL THEN
    RETURN '[]'::JSONB;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'notification_id', n.id,
    'match_id', n.match_id,
    'opponent_name', n.opponent_name,
    'wager', n.wager,
    'rating_change', n.rating_change,
    'won', n.won,
    'created_at', n.created_at
  ) ORDER BY n.created_at ASC), '[]'::JSONB)
  INTO v_rows
  FROM public.pvp_arena_notifications n
  WHERE n.user_id = v_me
    AND n.seen = false;

  RETURN v_rows;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_arena_pvp_result_seen(p_notification_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.pvp_arena_notifications
  SET seen = true
  WHERE id = p_notification_id AND user_id = auth.uid();

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_unseen_arena_pvp_results() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_arena_pvp_result_seen(UUID) TO authenticated;

-- mekan_pvp_bet: savunmaciya bildirim + match id don
CREATE OR REPLACE FUNCTION public.mekan_pvp_bet(
  p_defender_id UUID,
  p_mekan_id UUID,
  p_wager BIGINT
) RETURNS JSONB AS $$
DECLARE
  v_attacker_id UUID;
  v_attacker RECORD;
  v_defender RECORD;
  v_mekan RECORD;
  v_winner_id UUID;
  v_loser_id UUID;
  v_att_power NUMERIC;
  v_def_power NUMERIC;
  v_win_chance NUMERIC;
  v_pool BIGINT := 0;
  v_commission BIGINT := 0;
  v_net_win BIGINT := 0;
  v_att_rating_change INT;
  v_def_rating_change INT;
  v_hospitalized BOOLEAN := false;
  v_match_id UUID;
  v_attacker_name TEXT;
  v_defender_name TEXT;
BEGIN
  v_attacker_id := auth.uid();
  IF v_attacker_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  IF v_attacker_id = p_defender_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize saldiramazsiniz');
  END IF;

  IF p_wager IS NULL OR p_wager < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz bahis');
  END IF;
  IF p_wager > 0 AND p_wager < 10000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum bahis 10000 (veya 0 = dostluk maci)');
  END IF;
  IF p_wager > 5000000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Maksimum bahis 5000000');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan kapali veya gecersiz');
  END IF;

  IF v_mekan.mekan_type NOT IN ('dovus_kulubu', 'luks_lounge', 'yeralti') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu mekan turunde PvP yapilamaz');
  END IF;

  SELECT * INTO v_attacker FROM public.users WHERE auth_id = v_attacker_id FOR UPDATE;
  SELECT * INTO v_defender FROM public.users WHERE auth_id = p_defender_id FOR UPDATE;
  IF v_attacker IS NULL OR v_defender IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi');
  END IF;

  v_attacker_name := COALESCE(v_attacker.display_name, v_attacker.username, 'Rakip');
  v_defender_name := COALESCE(v_defender.display_name, v_defender.username, 'Rakip');

  IF v_attacker.energy < 15 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz enerji (15 gerekli)');
  END IF;
  IF p_wager > 0 THEN
    IF v_attacker.gold < p_wager THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altin (bahis icin)');
    END IF;
    IF v_defender.gold < p_wager THEN
      RETURN jsonb_build_object('success', false, 'error', 'Rakibin yeterli altini yok');
    END IF;
  END IF;

  v_att_power := COALESCE(v_attacker.attack, 10) + COALESCE(v_attacker.defense, 10);
  v_def_power := COALESCE(v_defender.attack, 10) + COALESCE(v_defender.defense, 10);
  IF COALESCE(v_attacker.character_class, '') = 'shadow' THEN v_att_power := v_att_power * 1.15; END IF;
  IF COALESCE(v_defender.character_class, '') = 'shadow' THEN v_def_power := v_def_power * 1.15; END IF;

  v_win_chance := v_att_power / NULLIF(v_att_power + v_def_power, 0);
  IF v_win_chance IS NULL THEN v_win_chance := 0.5; END IF;

  IF random() <= v_win_chance THEN
    v_winner_id := v_attacker_id;
    v_loser_id := p_defender_id;
    v_att_rating_change := 15 + floor(random() * 10)::INT;
    v_def_rating_change := -(10 + floor(random() * 5)::INT);
  ELSE
    v_winner_id := p_defender_id;
    v_loser_id := v_attacker_id;
    v_att_rating_change := -(10 + floor(random() * 5)::INT);
    v_def_rating_change := 15 + floor(random() * 10)::INT;
  END IF;

  IF p_wager > 0 THEN
    v_pool := p_wager * 2;
    v_commission := floor(v_pool * 0.08)::BIGINT;
    v_net_win := v_pool - v_commission;
  END IF;

  UPDATE public.users SET
    gold = gold - p_wager,
    energy = energy - 15,
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_att_rating_change),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = v_attacker_id THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = v_attacker_id THEN 1 ELSE 0 END
  WHERE auth_id = v_attacker_id AND gold >= p_wager AND energy >= 15;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Islem sirasinda enerji veya altin yetersiz kaldi');
  END IF;

  UPDATE public.users SET
    gold = gold - p_wager,
    pvp_rating = GREATEST(0, COALESCE(pvp_rating, 1000) + v_def_rating_change),
    pvp_wins = COALESCE(pvp_wins, 0) + CASE WHEN v_winner_id = p_defender_id THEN 1 ELSE 0 END,
    pvp_losses = COALESCE(pvp_losses, 0) + CASE WHEN v_loser_id = p_defender_id THEN 1 ELSE 0 END
  WHERE auth_id = p_defender_id AND gold >= p_wager;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakibin islemi sirasinda hata (altin yetersiz)');
  END IF;

  IF p_wager > 0 THEN
    UPDATE public.users SET gold = gold + v_net_win WHERE auth_id = v_winner_id;
    UPDATE public.users SET gold = gold + v_commission WHERE auth_id = v_mekan.owner_id;
  END IF;

  IF random() <= 0.10 THEN
    v_hospitalized := true;
    UPDATE public.users SET
      hospital_until = now() + INTERVAL '30 minutes',
      hospital_reason = 'Arena Maci Kaybi'
    WHERE auth_id = v_loser_id;
  END IF;

  INSERT INTO public.mekan_pvp_matches (
    mekan_id, attacker_id, defender_id, winner_id,
    gold_wagered, gold_won, mekan_commission,
    attacker_rating_change, defender_rating_change
  ) VALUES (
    p_mekan_id, v_attacker_id, p_defender_id, v_winner_id,
    p_wager, v_net_win, v_commission,
    v_att_rating_change, v_def_rating_change
  )
  RETURNING id INTO v_match_id;

  UPDATE public.mekans SET pvp_match_count = pvp_match_count + 1, fame = fame + 10 WHERE id = p_mekan_id;

  -- Savunmaci saldirgan degil — sonucu uygulama acik olmasa da gorsun
  INSERT INTO public.pvp_arena_notifications (
    user_id, match_id, opponent_name, wager, rating_change, won
  ) VALUES (
    p_defender_id,
    v_match_id,
    v_attacker_name,
    p_wager,
    v_def_rating_change,
    v_winner_id = p_defender_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'winner_id', v_winner_id,
    'won', (v_winner_id = v_attacker_id),
    'net_win', v_net_win,
    'commission', v_commission,
    'hospitalized', v_hospitalized,
    'attacker_rating_change', v_att_rating_change,
    'defender_rating_change', v_def_rating_change,
    'match_id', v_match_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.mekan_pvp_bet(UUID, UUID, BIGINT) TO authenticated;

COMMIT;
