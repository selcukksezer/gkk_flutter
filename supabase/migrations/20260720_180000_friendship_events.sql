-- ============================================================================
-- ARKADAŞLIK BİLDİRİMLERİ — istek gönderen tarafa kabul/red sonucu
-- PvP unseen results ile aynı poll + seen işaretleme modeli.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.friendship_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL,
  actor_id UUID NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('accepted', 'rejected')),
  friendship_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  seen_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS friendship_events_unseen_idx
  ON public.friendship_events (recipient_id, created_at DESC)
  WHERE seen_at IS NULL;

ALTER TABLE public.friendship_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friendship_events_select_own" ON public.friendship_events;
CREATE POLICY "friendship_events_select_own" ON public.friendship_events
  FOR SELECT USING (auth.uid() = recipient_id);

DROP POLICY IF EXISTS "friendship_events_update_own" ON public.friendship_events;
CREATE POLICY "friendship_events_update_own" ON public.friendship_events
  FOR UPDATE USING (auth.uid() = recipient_id);

-- ── İstek gönder ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_friend_request(p_username TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_target UUID;
  v_existing RECORD;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT auth_id INTO v_target
  FROM public.users
  WHERE lower(username) = lower(trim(p_username))
  LIMIT 1;

  IF v_target IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı');
  END IF;

  IF v_target = v_me THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendine istek gönderemezsin');
  END IF;

  SELECT * INTO v_existing
  FROM public.friendships
  WHERE (requester_id = v_me AND addressee_id = v_target)
     OR (requester_id = v_target AND addressee_id = v_me)
  LIMIT 1;

  IF FOUND THEN
    IF v_existing.status = 'accepted' THEN
      RETURN jsonb_build_object('success', false, 'error', 'Zaten arkadaşsınız');
    ELSIF v_existing.status = 'blocked' THEN
      RETURN jsonb_build_object('success', false, 'error', 'İstek gönderilemedi');
    ELSIF v_existing.requester_id = v_me THEN
      RETURN jsonb_build_object('success', false, 'error', 'İstek zaten gönderildi');
    ELSE
      UPDATE public.friendships
      SET status = 'accepted', responded_at = now()
      WHERE id = v_existing.id;

      INSERT INTO public.friendship_events (recipient_id, actor_id, event_type, friendship_id)
      VALUES (v_existing.requester_id, v_me, 'accepted', v_existing.id);

      RETURN jsonb_build_object('success', true, 'auto_accepted', true);
    END IF;
  END IF;

  INSERT INTO public.friendships (requester_id, addressee_id)
  VALUES (v_me, v_target);

  RETURN jsonb_build_object('success', true, 'auto_accepted', false);
END;
$$;

-- ── İsteğe yanıt ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.respond_friend_request(
  p_friendship_id UUID,
  p_accept BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_row RECORD;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_row
  FROM public.friendships
  WHERE id = p_friendship_id AND addressee_id = v_me AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'İstek bulunamadı');
  END IF;

  IF p_accept THEN
    UPDATE public.friendships
    SET status = 'accepted', responded_at = now()
    WHERE id = p_friendship_id;

    INSERT INTO public.friendship_events (recipient_id, actor_id, event_type, friendship_id)
    VALUES (v_row.requester_id, v_me, 'accepted', p_friendship_id);
  ELSE
    INSERT INTO public.friendship_events (recipient_id, actor_id, event_type, friendship_id)
    VALUES (v_row.requester_id, v_me, 'rejected', p_friendship_id);

    DELETE FROM public.friendships WHERE id = p_friendship_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'accepted', p_accept);
END;
$$;

-- ── Görülmemiş arkadaşlık olayları ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_unseen_friendship_events()
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
    'event_id', e.id,
    'event_type', e.event_type,
    'friendship_id', e.friendship_id,
    'created_at', e.created_at,
    'actor', jsonb_build_object(
      'auth_id', u.auth_id,
      'username', u.username,
      'display_name', u.display_name,
      'avatar_url', u.avatar_url,
      'level', u.level
    )
  ) ORDER BY e.created_at DESC), '[]'::JSONB)
  INTO v_rows
  FROM public.friendship_events e
  JOIN public.users u ON u.auth_id = e.actor_id
  WHERE e.recipient_id = v_me
    AND e.seen_at IS NULL;

  RETURN v_rows;
END;
$$;

-- ── Olay görüldü ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_friendship_event_seen(p_event_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.friendship_events
  SET seen_at = now()
  WHERE id = p_event_id AND recipient_id = auth.uid();

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_unseen_friendship_events() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_friendship_event_seen(UUID) TO authenticated;
