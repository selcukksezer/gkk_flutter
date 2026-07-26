-- Support tickets with abuse limits.

BEGIN;

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('account', 'payment', 'bug', 'abuse', 'other')),
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN (
    'open', 'staff_reply', 'waiting_player', 'resolved', 'closed', 'spam'
  )),
  priority SMALLINT NOT NULL DEFAULT 0,
  assigned_staff_id UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  duplicate_of_ticket_id UUID REFERENCES public.support_tickets(id) ON DELETE SET NULL,
  abuse_score INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.support_ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  is_staff BOOLEAN NOT NULL DEFAULT false,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_player_status
  ON public.support_tickets(player_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_support_tickets_status
  ON public.support_tickets(status, updated_at DESC);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_tickets_own ON public.support_tickets;
CREATE POLICY support_tickets_own ON public.support_tickets
  FOR SELECT USING (player_id = auth.uid());

DROP POLICY IF EXISTS support_ticket_messages_own ON public.support_ticket_messages;
CREATE POLICY support_ticket_messages_own ON public.support_ticket_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.support_tickets t
      WHERE t.id = ticket_id AND t.player_id = auth.uid()
    )
    OR public.staff_has_permission(auth.uid(), 'ticket.view_all')
  );

CREATE OR REPLACE FUNCTION public.create_support_ticket(
  p_category TEXT,
  p_subject TEXT,
  p_body TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_policy JSONB;
  v_open INT;
  v_recent INT;
  v_daily INT;
  v_ticket_id UUID;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_policy := public.policy_require_acceptance(v_user);
  IF (v_policy->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_policy->>'error', 'policy_required', true);
  END IF;

  IF (public.assert_player_not_banned(v_user)->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hesap askıda.');
  END IF;

  IF p_category NOT IN ('account', 'payment', 'bug', 'abuse', 'other') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz kategori.');
  END IF;

  IF char_length(btrim(COALESCE(p_subject, ''))) < 5 OR char_length(btrim(COALESCE(p_body, ''))) < 20 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Konu ve açıklama yeterince uzun olmalı.');
  END IF;

  SELECT COUNT(*) INTO v_open
  FROM public.support_tickets
  WHERE player_id = v_user AND status IN ('open', 'staff_reply', 'waiting_player');

  IF v_open >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'En fazla 3 açık ticket olabilir.');
  END IF;

  SELECT COUNT(*) INTO v_recent
  FROM public.support_tickets
  WHERE player_id = v_user AND created_at > now() - interval '20 minutes';

  IF v_recent >= 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeni ticket için 20 dakika bekleyin.');
  END IF;

  SELECT COUNT(*) INTO v_daily
  FROM public.support_tickets
  WHERE player_id = v_user AND created_at > now() - interval '24 hours';

  IF v_daily >= 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Günlük ticket limitine ulaşıldı.');
  END IF;

  INSERT INTO public.support_tickets (player_id, category, subject, body)
  VALUES (v_user, p_category, left(btrim(p_subject), 120), left(btrim(p_body), 4000))
  RETURNING id INTO v_ticket_id;

  INSERT INTO public.support_ticket_messages (ticket_id, sender_id, is_staff, body)
  VALUES (v_ticket_id, v_user, false, left(btrim(p_body), 4000));

  RETURN jsonb_build_object('success', true, 'ticket_id', v_ticket_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_tickets()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', t.id,
        'category', t.category,
        'subject', t.subject,
        'status', t.status,
        'created_at', t.created_at,
        'updated_at', t.updated_at
      ) ORDER BY t.updated_at DESC)
      FROM public.support_tickets t
      WHERE t.player_id = v_user
      LIMIT 50
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_support_ticket_detail(p_ticket_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_ticket RECORD;
BEGIN
  SELECT * INTO v_ticket FROM public.support_tickets WHERE id = p_ticket_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket bulunamadı.');
  END IF;

  IF v_ticket.player_id <> v_user
     AND NOT public.staff_has_permission(v_user, 'ticket.view_all') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'ticket', jsonb_build_object(
      'id', v_ticket.id,
      'category', v_ticket.category,
      'subject', v_ticket.subject,
      'body', v_ticket.body,
      'status', v_ticket.status,
      'created_at', v_ticket.created_at,
      'updated_at', v_ticket.updated_at
    ),
    'messages', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', m.id,
        'sender_id', m.sender_id,
        'is_staff', m.is_staff,
        'body', m.body,
        'created_at', m.created_at
      ) ORDER BY m.created_at ASC)
      FROM public.support_ticket_messages m
      WHERE m.ticket_id = p_ticket_id
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.reply_support_ticket(p_ticket_id UUID, p_body TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_ticket RECORD;
BEGIN
  IF char_length(btrim(COALESCE(p_body, ''))) < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mesaj çok kısa.');
  END IF;

  SELECT * INTO v_ticket FROM public.support_tickets WHERE id = p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket bulunamadı.');
  END IF;

  IF v_ticket.player_id <> v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  IF v_ticket.status IN ('closed', 'spam', 'resolved') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket kapalı.');
  END IF;

  INSERT INTO public.support_ticket_messages (ticket_id, sender_id, is_staff, body)
  VALUES (p_ticket_id, v_user, false, left(btrim(p_body), 4000));

  UPDATE public.support_tickets
  SET status = 'waiting_player', updated_at = now()
  WHERE id = p_ticket_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_support_ticket(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_tickets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_support_ticket_detail(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reply_support_ticket(uuid, text) TO authenticated;

COMMIT;
