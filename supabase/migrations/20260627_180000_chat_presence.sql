-- Chat presence: shared online check + RPC batch lookup + chat API fields.

CREATE OR REPLACE FUNCTION public.is_user_online(
  p_is_online boolean,
  p_last_active_at timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(p_is_online, false)
    AND p_last_active_at IS NOT NULL
    AND p_last_active_at >= (now() - interval '5 minutes');
$$;


DROP FUNCTION IF EXISTS public.get_chat_presence(UUID[]);
CREATE OR REPLACE FUNCTION public.get_chat_presence(p_user_ids UUID[])
RETURNS TABLE (
  user_id UUID,
  is_online BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.get_current_chat_user();

  IF p_user_ids IS NULL OR cardinality(p_user_ids) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    public.is_user_online(u.is_online, u.last_active_at)
  FROM public.users u
  WHERE u.id = ANY(p_user_ids);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_chat_presence(UUID[]) TO authenticated;


DROP FUNCTION IF EXISTS public.search_chat_users(TEXT, INTEGER);
CREATE OR REPLACE FUNCTION public.search_chat_users(
  p_query TEXT,
  p_limit INTEGER DEFAULT 8
)
RETURNS TABLE (
  id UUID,
  username TEXT,
  display_name TEXT,
  is_online BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_query TEXT;
BEGIN
  v_user := public.get_current_chat_user();
  v_query := lower(btrim(COALESCE(p_query, '')));

  IF char_length(v_query) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.username,
    u.display_name,
    public.is_user_online(u.is_online, u.last_active_at)
  FROM public.users u
  WHERE u.id <> v_user.id
    AND (
      lower(u.username) LIKE v_query || '%'
      OR lower(COALESCE(u.display_name, '')) LIKE '%' || v_query || '%'
    )
  ORDER BY
    CASE WHEN lower(u.username) = v_query THEN 0 ELSE 1 END,
    CASE WHEN lower(u.username) LIKE v_query || '%' THEN 0 ELSE 1 END,
    u.username ASC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 8), 1), 20);
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_chat_users(TEXT, INTEGER) TO authenticated;


DROP FUNCTION IF EXISTS public.get_chat_history(TEXT, INTEGER);
CREATE OR REPLACE FUNCTION public.get_chat_history(
  p_channel TEXT,
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
  sender_is_online BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade', 'system') THEN
    RAISE EXCEPTION 'Gecersiz kanal';
  END IF;

  IF p_channel = 'guild' AND v_user.guild_id IS NULL THEN
    RETURN;
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
    public.is_user_online(u.is_online, u.last_active_at)
  FROM public.chat_messages cm
  JOIN public.users u ON u.id = cm.sender_user_id
  WHERE cm.deleted_at IS NULL
    AND cm.channel = p_channel
    AND (
      p_channel IN ('global', 'trade', 'system')
      OR (p_channel = 'guild' AND cm.guild_id = v_user.guild_id)
      OR (p_channel = 'dm' AND (cm.sender_user_id = v_user.id OR cm.recipient_user_id = v_user.id))
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE cb.blocker_user_id = v_user.id
        AND cb.blocked_user_id = cm.sender_user_id
    )
  ORDER BY cm.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_chat_history(TEXT, INTEGER) TO authenticated;


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
  read_at TIMESTAMPTZ,
  sender_is_online BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
    cm.read_at,
    public.is_user_online(u.is_online, u.last_active_at)
  FROM public.chat_messages cm
  JOIN public.users u ON u.id = cm.sender_user_id
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
$$;

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
  last_sender_id UUID,
  peer_is_online BOOLEAN
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
    dm.sender_user_id,
    public.is_user_online(peer.is_online, peer.last_active_at)
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
