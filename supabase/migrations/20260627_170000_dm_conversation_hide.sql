-- Hide DM conversation from list (not per-message delete). New messages after hide restore the thread.

CREATE TABLE IF NOT EXISTS public.chat_dm_conversation_hides (
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  peer_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  hidden_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, peer_user_id),
  CONSTRAINT chat_dm_conversation_hides_no_self CHECK (user_id <> peer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_dm_conversation_hides_peer
  ON public.chat_dm_conversation_hides(peer_user_id);

ALTER TABLE public.chat_dm_conversation_hides ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.chat_dm_conversation_hides FROM PUBLIC;
REVOKE ALL ON TABLE public.chat_dm_conversation_hides FROM anon;
REVOKE ALL ON TABLE public.chat_dm_conversation_hides FROM authenticated;
GRANT SELECT ON TABLE public.chat_dm_conversation_hides TO authenticated;

DROP POLICY IF EXISTS chat_dm_conversation_hides_own ON public.chat_dm_conversation_hides;
CREATE POLICY chat_dm_conversation_hides_own ON public.chat_dm_conversation_hides
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));


DROP FUNCTION IF EXISTS public.hide_dm_conversation(UUID);
CREATE OR REPLACE FUNCTION public.hide_dm_conversation(p_peer_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_peer_user_id IS NULL OR p_peer_user_id = v_user.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz hedef');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_peer_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  INSERT INTO public.chat_dm_conversation_hides (user_id, peer_user_id, hidden_at)
  VALUES (v_user.id, p_peer_user_id, now())
  ON CONFLICT (user_id, peer_user_id) DO UPDATE SET hidden_at = excluded.hidden_at;

  UPDATE public.chat_messages
  SET read_at = now()
  WHERE channel = 'dm'
    AND recipient_user_id = v_user.id
    AND sender_user_id = p_peer_user_id
    AND read_at IS NULL
    AND deleted_at IS NULL;

  PERFORM public.write_chat_audit(
    v_user.id,
    'dm_conversation_hidden',
    p_peer_user_id,
    NULL,
    '{}'::jsonb
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hide_dm_conversation(UUID) TO authenticated;


DROP FUNCTION IF EXISTS public.get_dm_conversations();
CREATE OR REPLACE FUNCTION public.get_dm_conversations()
RETURNS TABLE (
  peer_user_id UUID,
  peer_username TEXT,
  peer_display_name TEXT,
  last_message_id UUID,
  last_message_content TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count BIGINT,
  last_sender_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  RETURN QUERY
  WITH dm_rows AS (
    SELECT
      CASE
        WHEN cm.sender_user_id = v_user.id THEN cm.recipient_user_id
        ELSE cm.sender_user_id
      END AS peer_id,
      cm.id,
      cm.content,
      cm.created_at,
      cm.sender_user_id,
      cm.recipient_user_id,
      cm.read_at,
      row_number() OVER (
        PARTITION BY CASE
          WHEN cm.sender_user_id = v_user.id THEN cm.recipient_user_id
          ELSE cm.sender_user_id
        END
        ORDER BY cm.created_at DESC
      ) AS row_num
    FROM public.chat_messages cm
    WHERE cm.deleted_at IS NULL
      AND cm.channel = 'dm'
      AND (cm.sender_user_id = v_user.id OR cm.recipient_user_id = v_user.id)
      AND NOT EXISTS (
        SELECT 1 FROM public.chat_dm_message_hides h
        WHERE h.message_id = cm.id
          AND h.user_id = v_user.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.chat_blocks cb
        WHERE cb.blocker_user_id = v_user.id
          AND cb.blocked_user_id = CASE
            WHEN cm.sender_user_id = v_user.id THEN cm.recipient_user_id
            ELSE cm.sender_user_id
          END
      )
  ), unread_totals AS (
    SELECT
      cm.sender_user_id AS peer_id,
      count(*) AS unread_count
    FROM public.chat_messages cm
    WHERE cm.deleted_at IS NULL
      AND cm.channel = 'dm'
      AND cm.recipient_user_id = v_user.id
      AND cm.read_at IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM public.chat_dm_message_hides h
        WHERE h.message_id = cm.id
          AND h.user_id = v_user.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.chat_dm_conversation_hides ch
        WHERE ch.user_id = v_user.id
          AND ch.peer_user_id = cm.sender_user_id
          AND cm.created_at <= ch.hidden_at
      )
    GROUP BY cm.sender_user_id
  )
  SELECT
    peer.id,
    peer.username,
    peer.display_name,
    dm.id,
    dm.content,
    dm.created_at,
    COALESCE(unread_totals.unread_count, 0),
    dm.sender_user_id
  FROM dm_rows dm
  JOIN public.users peer ON peer.id = dm.peer_id
  LEFT JOIN unread_totals ON unread_totals.peer_id = dm.peer_id
  WHERE dm.row_num = 1
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_dm_conversation_hides ch
      WHERE ch.user_id = v_user.id
        AND ch.peer_user_id = dm.peer_id
        AND dm.created_at <= ch.hidden_at
    )
  ORDER BY dm.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_dm_conversations() TO authenticated;
