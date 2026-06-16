-- =========================================================================================
-- MEKAN REDESIGN - PHASE 1: mekan_pvp_bet (wagered arena fight) + get_mekan_arena_ranking.
-- PLAN_07 section 6 (PvP arena, betting, weekly ranking).
-- =========================================================================================

-- Wagered 1v1 fight hosted by a fighting-capable mekan. 8% commission to the owner.
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
  v_pool BIGINT;
  v_commission BIGINT;
  v_net_win BIGINT;
  v_att_rating_change INT;
  v_def_rating_change INT;
  v_hospitalized BOOLEAN := false;
BEGIN
  v_attacker_id := auth.uid();
  IF v_attacker_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  IF v_attacker_id = p_defender_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize saldiramazsiniz');
  END IF;

  IF p_wager IS NULL OR p_wager < 10000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum bahis 10000');
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

  IF v_attacker.energy < 15 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz enerji (15 gerekli)');
  END IF;
  IF v_attacker.gold < p_wager THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altin (bahis icin)');
  END IF;
  IF v_defender.gold < p_wager THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rakibin yeterli altini yok');
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

  v_pool := p_wager * 2;
  v_commission := floor(v_pool * 0.08)::BIGINT; -- 1v1 betting commission (PLAN_07 section 5.2)
  v_net_win := v_pool - v_commission;

  -- Both stake the wager; attacker also spends 15 energy.
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

  UPDATE public.users SET gold = gold + v_net_win WHERE auth_id = v_winner_id;
  UPDATE public.users SET gold = gold + v_commission WHERE auth_id = v_mekan.owner_id;

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
  );

  UPDATE public.mekans SET pvp_match_count = pvp_match_count + 1, fame = fame + 10 WHERE id = p_mekan_id;

  RETURN jsonb_build_object(
    'success', true,
    'winner_id', v_winner_id,
    'won', (v_winner_id = v_attacker_id),
    'net_win', v_net_win,
    'commission', v_commission,
    'hospitalized', v_hospitalized,
    'attacker_rating_change', v_att_rating_change,
    'defender_rating_change', v_def_rating_change
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.mekan_pvp_bet(UUID, UUID, BIGINT) TO authenticated;

-- Weekly arena ranking by pvp_rating with the PLAN_07 section 5.3 reward tiers (display only).
CREATE OR REPLACE FUNCTION public.get_mekan_arena_ranking(p_limit INT DEFAULT 50)
RETURNS JSONB AS $$
DECLARE
  v_rows JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) INTO v_rows
  FROM (
    SELECT
      u.auth_id,
      u.username,
      u.level,
      COALESCE(u.pvp_rating, 1000) AS pvp_rating,
      COALESCE(u.pvp_wins, 0) AS pvp_wins,
      COALESCE(u.pvp_losses, 0) AS pvp_losses,
      rnk.rank,
      CASE
        WHEN rnk.rank = 1 THEN 2000000
        WHEN rnk.rank BETWEEN 2 AND 5 THEN 1000000
        WHEN rnk.rank BETWEEN 6 AND 10 THEN 500000
        WHEN rnk.rank BETWEEN 11 AND 25 THEN 200000
        WHEN rnk.rank BETWEEN 26 AND 50 THEN 100000
        ELSE 0
      END AS weekly_reward
    FROM (
      SELECT auth_id, ROW_NUMBER() OVER (ORDER BY COALESCE(pvp_rating, 1000) DESC) AS rank
      FROM public.users
    ) rnk
    JOIN public.users u ON u.auth_id = rnk.auth_id
    ORDER BY rnk.rank
    LIMIT GREATEST(1, LEAST(p_limit, 100))
  ) t;

  RETURN jsonb_build_object('success', true, 'ranking', v_rows);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_mekan_arena_ranking(INT) TO authenticated;
