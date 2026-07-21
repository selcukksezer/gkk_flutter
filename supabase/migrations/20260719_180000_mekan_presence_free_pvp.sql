-- ============================================================================
-- MEKAN: presence ("şu an içeride") + ücretsiz PvP (p_wager = 0)
-- 1) users.current_mekan_id + set_online_status'a mekan parametresi
-- 2) get_mekan_presence RPC
-- 3) mekan_pvp_bet: wager = 0 → altınsız dostluk maçı (rating/istatistik yine işler)
-- ============================================================================

BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS current_mekan_id UUID;

CREATE INDEX IF NOT EXISTS users_current_mekan_idx
  ON public.users (current_mekan_id)
  WHERE current_mekan_id IS NOT NULL;

-- Eski tek parametreli imzayı kaldır (PostgREST overload karışıklığını önle)
DROP FUNCTION IF EXISTS public.set_online_status(boolean);

CREATE OR REPLACE FUNCTION public.set_online_status(
  p_is_online boolean,
  p_mekan_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  UPDATE public.users
  SET is_online = p_is_online,
      last_active_at = now(),
      current_mekan_id = CASE WHEN p_is_online THEN p_mekan_id ELSE NULL END
  WHERE auth_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_online_status(boolean, uuid) TO authenticated;

-- ── Mekanda kim var ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_mekan_presence(p_mekan_id uuid)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_rows JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'auth_id', u.auth_id,
    'username', u.username,
    'display_name', u.display_name,
    'avatar_url', u.avatar_url,
    'level', u.level,
    'power', u.power,
    'pvp_rating', COALESCE(u.pvp_rating, 1000)
  ) ORDER BY COALESCE(u.pvp_rating, 1000) DESC), '[]'::JSONB)
  INTO v_rows
  FROM public.users u
  WHERE u.current_mekan_id = p_mekan_id
    AND COALESCE(u.is_online, false) = true
    AND COALESCE(u.last_active_at, now() - interval '1 hour') > now() - interval '10 minutes';

  RETURN v_rows;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_mekan_presence(uuid) TO authenticated;

-- ── mekan_pvp_bet: wager = 0 dostluk maçı ───────────────────────────────────
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
BEGIN
  v_attacker_id := auth.uid();
  IF v_attacker_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  IF v_attacker_id = p_defender_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize saldiramazsiniz');
  END IF;

  -- wager = 0 → ücretsiz dostluk maçı; wager > 0 → min 10k kuralı korunur
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

  -- Saldıran: enerji her durumda; altın sadece bahisli maçta düşer.
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

COMMIT;
