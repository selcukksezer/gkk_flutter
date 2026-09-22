-- Ward chat realtime: RLS SELECT for ward_* + publish chat_messages to Realtime.
-- History already works via SECURITY DEFINER RPCs; postgres_changes needs SELECT RLS + publication.

BEGIN;

-- ── RLS: ward channels visible only while in matching restriction ───────────
DROP POLICY IF EXISTS "chat_messages_select_visible" ON public.chat_messages;
CREATE POLICY "chat_messages_select_visible"
  ON public.chat_messages FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      channel IN ('global', 'trade', 'system')
      OR (
        channel = 'guild'
        AND guild_id = (SELECT guild_id FROM public.users WHERE auth_id = auth.uid())
      )
      OR (
        channel = 'dm'
        AND (
          sender_user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
          OR recipient_user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
        )
      )
      OR (
        channel = 'ward_hospital'
        AND EXISTS (
          SELECT 1
          FROM public.users u
          WHERE u.auth_id = auth.uid()
            AND u.hospital_until IS NOT NULL
            AND u.hospital_until > now()
        )
      )
      OR (
        channel = 'ward_prison'
        AND EXISTS (
          SELECT 1
          FROM public.users u
          WHERE u.auth_id = auth.uid()
            AND u.prison_until IS NOT NULL
            AND u.prison_until > now()
        )
      )
    )
  );

-- ── Realtime publication (was missing chat_messages entirely) ───────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'chat_messages'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
    END IF;
  END IF;
END $$;

COMMIT;
