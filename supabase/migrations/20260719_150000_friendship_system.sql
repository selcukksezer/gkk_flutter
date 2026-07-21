-- ============================================================================
-- ARKADAŞLIK SİSTEMİ
-- friendships tablosu + send/respond/remove/get RPC'leri (RLS'li)
-- Kimlikler auth_id (users.auth_id) üzerinden yürür.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID NOT NULL,
  addressee_id UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ,
  UNIQUE (requester_id, addressee_id),
  CHECK (requester_id != addressee_id)
);

CREATE INDEX IF NOT EXISTS friendships_addressee_idx
  ON public.friendships (addressee_id, status);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "friendships_select_own" ON public.friendships;
CREATE POLICY "friendships_select_own" ON public.friendships
  FOR SELECT USING (auth.uid() IN (requester_id, addressee_id));

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
      -- Karşı taraf bize zaten istek atmış → otomatik kabul
      UPDATE public.friendships
      SET status = 'accepted', responded_at = now()
      WHERE id = v_existing.id;
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
  ELSE
    DELETE FROM public.friendships WHERE id = p_friendship_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'accepted', p_accept);
END;
$$;

-- ── Arkadaşlıktan çıkar ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.remove_friend(p_friendship_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  DELETE FROM public.friendships
  WHERE id = p_friendship_id AND auth.uid() IN (requester_id, addressee_id);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── Liste ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_friends()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me UUID;
  v_friends JSONB;
  v_incoming JSONB;
  v_outgoing JSONB;
BEGIN
  v_me := auth.uid();
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('friends', '[]'::jsonb, 'incoming', '[]'::jsonb, 'outgoing', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'friendship_id', f.id,
    'auth_id', u.auth_id,
    'username', u.username,
    'display_name', u.display_name,
    'avatar_url', u.avatar_url,
    'level', u.level,
    'power', u.power,
    'is_online', COALESCE(u.is_online, false)
  ) ORDER BY COALESCE(u.is_online, false) DESC, u.username), '[]'::jsonb)
  INTO v_friends
  FROM public.friendships f
  JOIN public.users u
    ON u.auth_id = CASE WHEN f.requester_id = v_me THEN f.addressee_id ELSE f.requester_id END
  WHERE f.status = 'accepted' AND v_me IN (f.requester_id, f.addressee_id);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'friendship_id', f.id,
    'auth_id', u.auth_id,
    'username', u.username,
    'display_name', u.display_name,
    'avatar_url', u.avatar_url,
    'level', u.level
  ) ORDER BY f.created_at DESC), '[]'::jsonb)
  INTO v_incoming
  FROM public.friendships f
  JOIN public.users u ON u.auth_id = f.requester_id
  WHERE f.status = 'pending' AND f.addressee_id = v_me;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'friendship_id', f.id,
    'auth_id', u.auth_id,
    'username', u.username,
    'display_name', u.display_name,
    'avatar_url', u.avatar_url,
    'level', u.level
  ) ORDER BY f.created_at DESC), '[]'::jsonb)
  INTO v_outgoing
  FROM public.friendships f
  JOIN public.users u ON u.auth_id = f.addressee_id
  WHERE f.status = 'pending' AND f.requester_id = v_me;

  RETURN jsonb_build_object(
    'friends', v_friends,
    'incoming', v_incoming,
    'outgoing', v_outgoing
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_friend_request(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_friend_request(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_friend(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_friends() TO authenticated;
