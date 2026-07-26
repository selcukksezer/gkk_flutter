-- Chat history: add sender_staff_badge column (preserve TABLE return type).

BEGIN;

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
  sender_staff_badge TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
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
    public.get_public_staff_badge(u.auth_id) AS sender_staff_badge
  FROM public.chat_messages cm
  LEFT JOIN public.users u ON u.id = cm.sender_user_id
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

COMMIT;
