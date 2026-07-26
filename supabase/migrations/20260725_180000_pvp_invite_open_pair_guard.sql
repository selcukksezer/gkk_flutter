-- Block spam PvP duel invites for the same opponent pair while an invite is
-- still open: pending, or accepted with challenger not yet having seen the result
-- (UI "enter duel" window). Authoritative RPC check + partial unique index.

-- Expire stale pendings so they do not collide with the unique index.
UPDATE public.pvp_invites
SET status = 'expired'
WHERE status = 'pending'
  AND expires_at <= now();

CREATE UNIQUE INDEX IF NOT EXISTS pvp_invites_one_open_pair_uidx
  ON public.pvp_invites (
    LEAST(challenger_id, target_id),
    GREATEST(challenger_id, target_id)
  )
  WHERE status = 'pending'
     OR (status = 'accepted' AND challenger_seen = false);

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
  v_open_status TEXT;
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

  -- Pair-open: either direction, pending OR accepted-unseen (duel in UI)
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

GRANT EXECUTE ON FUNCTION public.send_pvp_invite(UUID, BIGINT) TO authenticated;
