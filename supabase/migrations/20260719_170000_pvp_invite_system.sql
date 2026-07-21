-- ============================================================================
-- PVP DAVET SİSTEMİ
-- pvp_invites tablosu + send/get/respond RPC'leri.
-- Kabul edilince execute mantığı (mekan_pvp_bet'ten türetilmiş, mekansız):
-- bahisli veya bahissiz (p_wager = 0) düello; %5 arena vergisi; rating günceller.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.pvp_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id UUID NOT NULL,
  target_id UUID NOT NULL,
  wager BIGINT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
  result JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '2 minutes',
  CHECK (challenger_id != target_id)
);

CREATE INDEX IF NOT EXISTS pvp_invites_target_idx
  ON public.pvp_invites (target_id, status);

ALTER TABLE public.pvp_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pvp_invites_select_own" ON public.pvp_invites;
CREATE POLICY "pvp_invites_select_own" ON public.pvp_invites
  FOR SELECT USING (auth.uid() IN (challenger_id, target_id));

-- ── Davet gönder ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_pvp_invite(
  p_target UUID,
  p_wager BIGINT DEFAULT 0
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

  SELECT * INTO v_challenger FROM public.users WHERE auth_id = v_me;
  SELECT * INTO v_target FROM public.users WHERE auth_id = p_target;
  IF v_target IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı');
  END IF;

  IF p_wager > 0 AND v_challenger.gold < p_wager THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın');
  END IF;

  -- Süresi geçmiş bekleyenleri temizle
  UPDATE public.pvp_invites SET status = 'expired'
  WHERE status = 'pending' AND expires_at <= now();

  IF EXISTS (
    SELECT 1 FROM public.pvp_invites
    WHERE challenger_id = v_me AND target_id = p_target AND status = 'pending'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bekleyen davetin var');
  END IF;

  INSERT INTO public.pvp_invites (challenger_id, target_id, wager)
  VALUES (v_me, p_target, p_wager)
  RETURNING id INTO v_invite_id;

  RETURN jsonb_build_object('success', true, 'invite_id', v_invite_id);
END;
$$;

-- ── Bekleyen davetler (VS overlay verisi) ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_pending_pvp_invites()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_rows JSONB;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN '[]'::JSONB;
  END IF;

  UPDATE public.pvp_invites SET status = 'expired'
  WHERE status = 'pending' AND expires_at <= now();

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'invite_id', i.id,
    'wager', i.wager,
    'expires_at', i.expires_at,
    'challenger', jsonb_build_object(
      'auth_id', u.auth_id,
      'username', u.username,
      'display_name', u.display_name,
      'avatar_url', u.avatar_url,
      'level', u.level,
      'power', u.power,
      'pvp_rating', COALESCE(u.pvp_rating, 1000)
    )
  ) ORDER BY i.created_at ASC), '[]'::JSONB)
  INTO v_rows
  FROM public.pvp_invites i
  JOIN public.users u ON u.auth_id = i.challenger_id
  WHERE i.target_id = v_me AND i.status = 'pending';

  RETURN v_rows;
END;
$$;

-- ── Yanıtla (kabulde düello anında koşulur) ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.respond_pvp_invite(
  p_invite_id UUID,
  p_accept BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

  IF NOT p_accept THEN
    UPDATE public.pvp_invites SET status = 'declined' WHERE id = p_invite_id;
    RETURN jsonb_build_object('success', true, 'declined', true);
  END IF;

  SELECT * INTO v_challenger FROM public.users WHERE auth_id = v_invite.challenger_id FOR UPDATE;
  SELECT * INTO v_target FROM public.users WHERE auth_id = v_me FOR UPDATE;

  IF v_challenger IS NULL OR v_target IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı');
  END IF;

  -- Bahis kontrolleri
  IF v_invite.wager > 0 THEN
    IF v_challenger.gold < v_invite.wager THEN
      UPDATE public.pvp_invites SET status = 'expired' WHERE id = p_invite_id;
      RETURN jsonb_build_object('success', false, 'error', 'Rakibin altını yetersiz');
    END IF;
    IF v_target.gold < v_invite.wager THEN
      RETURN jsonb_build_object('success', false, 'error', 'Bahis için altının yetersiz');
    END IF;
  END IF;

  -- Güç: mekan_pvp_bet ile aynı formül
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
    v_tax := floor(v_pool * 0.05)::BIGINT; -- arena vergisi (yakılır)
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

  -- Rating + istatistik
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

  UPDATE public.pvp_invites
  SET status = 'accepted', result = v_result
  WHERE id = p_invite_id;

  RETURN jsonb_build_object('success', true, 'declined', false, 'duel', v_result);
END;
$$;

-- ── Online oyuncular (arena listesi) ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_online_players(p_limit INT DEFAULT 30)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_rows JSONB;
BEGIN
  v_me := auth.uid();

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
  FROM (
    SELECT * FROM public.users
    WHERE COALESCE(is_online, false) = true
      AND auth_id != COALESCE(v_me, '00000000-0000-0000-0000-000000000000'::uuid)
    LIMIT GREATEST(1, LEAST(p_limit, 100))
  ) u;

  RETURN v_rows;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_pvp_invite(UUID, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_pvp_invites() TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_pvp_invite(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_online_players(INT) TO authenticated;
