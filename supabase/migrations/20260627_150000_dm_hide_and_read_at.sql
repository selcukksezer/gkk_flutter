-- DM per-user hide (delete for me) + read_at in message fetch + unread excludes hidden

CREATE TABLE IF NOT EXISTS public.chat_dm_message_hides (
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  message_id UUID NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  hidden_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, message_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_dm_message_hides_message
  ON public.chat_dm_message_hides(message_id);

ALTER TABLE public.chat_dm_message_hides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chat_dm_message_hides_own ON public.chat_dm_message_hides;
CREATE POLICY chat_dm_message_hides_own ON public.chat_dm_message_hides
  FOR ALL
  USING (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()))
  WITH CHECK (user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid()));


DROP FUNCTION IF EXISTS public.hide_dm_message(UUID);
CREATE OR REPLACE FUNCTION public.hide_dm_message(p_message_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_message RECORD;
BEGIN
  v_user := public.get_current_chat_user();

  SELECT id, channel, sender_user_id, recipient_user_id, deleted_at, read_at
  INTO v_message
  FROM public.chat_messages
  WHERE id = p_message_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj bulunamadi');
  END IF;

  IF v_message.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj zaten silinmis');
  END IF;

  IF v_message.channel <> 'dm' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yalnizca ozel mesajlar silinebilir');
  END IF;

  IF v_user.id NOT IN (v_message.sender_user_id, v_message.recipient_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu mesaji silme yetkiniz yok');
  END IF;

  INSERT INTO public.chat_dm_message_hides (user_id, message_id)
  VALUES (v_user.id, p_message_id)
  ON CONFLICT (user_id, message_id) DO NOTHING;

  IF v_user.id = v_message.recipient_user_id AND v_message.read_at IS NULL THEN
    UPDATE public.chat_messages
    SET read_at = now()
    WHERE id = p_message_id;
  END IF;

  PERFORM public.write_chat_audit(
    v_user.id,
    'dm_message_hidden',
    CASE WHEN v_user.id = v_message.sender_user_id THEN v_message.recipient_user_id ELSE v_message.sender_user_id END,
    p_message_id,
    '{}'::jsonb
  );

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.hide_dm_message(UUID) TO authenticated;


DROP FUNCTION IF EXISTS public.get_dm_messages(UUID, INTEGER);
CREATE OR REPLACE FUNCTION public.get_dm_messages(
  p_peer_user_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  channel TEXT,
  sender_id UUID,
  sender_name TEXT,
  content TEXT,
  "timestamp" TIMESTAMPTZ,
  is_system BOOLEAN,
  recipient_user_id UUID,
  guild_id UUID,
  read_at TIMESTAMPTZ
) AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_peer_user_id IS NULL OR p_peer_user_id = v_user.id THEN
    RAISE EXCEPTION 'Gecersiz hedef kullanici';
  END IF;

  RETURN QUERY
  SELECT
    cm.id,
    cm.channel,
    cm.sender_user_id,
    cm.sender_name,
    cm.content,
    cm.created_at,
    cm.is_system,
    cm.recipient_user_id,
    cm.guild_id,
    cm.read_at
  FROM public.chat_messages cm
  WHERE cm.deleted_at IS NULL
    AND cm.channel = 'dm'
    AND (
      (cm.sender_user_id = v_user.id AND cm.recipient_user_id = p_peer_user_id)
      OR (cm.sender_user_id = p_peer_user_id AND cm.recipient_user_id = v_user.id)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE cb.blocker_user_id = v_user.id
        AND cb.blocked_user_id = cm.sender_user_id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_dm_message_hides h
      WHERE h.message_id = cm.id
        AND h.user_id = v_user.id
    )
  ORDER BY cm.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_dm_messages(UUID, INTEGER) TO authenticated;


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
) AS $$
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
  ORDER BY dm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_dm_conversations() TO authenticated;
