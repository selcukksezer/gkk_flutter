-- ============================================================================
-- PVP DÜELLO SONUCU: davet eden (challenger) tarafına bildirim
-- Sonuç şu an sadece kabul eden oyuncuda gösteriliyordu. challenger_seen
-- bayrağı + poll RPC'si ile davet eden de sonucu (veya reddi) görür.
-- ============================================================================

ALTER TABLE public.pvp_invites
  ADD COLUMN IF NOT EXISTS challenger_seen BOOLEAN NOT NULL DEFAULT false;

-- Eski kayıtlar bildirim seli yaratmasın
UPDATE public.pvp_invites SET challenger_seen = true
WHERE status IN ('accepted', 'declined', 'expired');

CREATE INDEX IF NOT EXISTS pvp_invites_challenger_unseen_idx
  ON public.pvp_invites (challenger_id)
  WHERE challenger_seen = false AND status IN ('accepted', 'declined');

-- ── Görülmemiş sonuçlar (challenger poll) ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_unseen_pvp_results()
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

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'invite_id', i.id,
    'wager', i.wager,
    'status', i.status,
    'result', i.result,
    'opponent', jsonb_build_object(
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
  JOIN public.users u ON u.auth_id = i.target_id
  WHERE i.challenger_id = v_me
    AND i.challenger_seen = false
    AND i.status IN ('accepted', 'declined');

  RETURN v_rows;
END;
$$;

-- ── Sonucu görüldü işaretle ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_pvp_result_seen(p_invite_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.pvp_invites SET challenger_seen = true
  WHERE id = p_invite_id AND challenger_id = auth.uid();

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_unseen_pvp_results() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_pvp_result_seen(UUID) TO authenticated;
