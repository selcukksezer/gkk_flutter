-- Staff plan: chat reports queue, GM roster, bug suggest, gem ledger, tickets, inbox, audit filters.

BEGIN;

-- Gem transaction ledger (promo / bug rewards — not IAP).
CREATE TABLE IF NOT EXISTS public.gem_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  amount INT NOT NULL,
  reason TEXT NOT NULL,
  reference_type TEXT,
  reference_id TEXT,
  created_by UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gem_transactions_user
  ON public.gem_transactions(user_id, created_at DESC);

ALTER TABLE public.gem_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS gem_transactions_own ON public.gem_transactions;
CREATE POLICY gem_transactions_own ON public.gem_transactions
  FOR SELECT USING (user_id = auth.uid());

-- Player inbox (bug/ticket staff events).
CREATE TABLE IF NOT EXISTS public.player_inbox_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_player_inbox_user
  ON public.player_inbox_notifications(user_id, created_at DESC);

ALTER TABLE public.player_inbox_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS player_inbox_own ON public.player_inbox_notifications;
CREATE POLICY player_inbox_own ON public.player_inbox_notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public._notify_player_inbox(
  p_user_id UUID,
  p_kind TEXT,
  p_title TEXT,
  p_body TEXT,
  p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.player_inbox_notifications (user_id, kind, title, body, payload)
  VALUES (p_user_id, p_kind, left(p_title, 200), left(COALESCE(p_body, ''), 1000), COALESCE(p_payload, '{}'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_inbox_notifications(p_limit INT DEFAULT 30)
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
        'id', n.id,
        'kind', n.kind,
        'title', n.title,
        'body', n.body,
        'payload', n.payload,
        'read_at', n.read_at,
        'created_at', n.created_at
      ) ORDER BY n.created_at DESC)
      FROM (
        SELECT * FROM public.player_inbox_notifications
        WHERE user_id = v_user
        ORDER BY created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
      ) n
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_inbox_notification_read(p_notification_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.player_inbox_notifications
  SET read_at = now()
  WHERE id = p_notification_id AND user_id = auth.uid();
  RETURN jsonb_build_object('success', true);
END;
$$;

-- Bug suggest reward columns.
ALTER TABLE public.bug_reports
  ADD COLUMN IF NOT EXISTS suggested_gems INT,
  ADD COLUMN IF NOT EXISTS suggested_by UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS suggested_at TIMESTAMPTZ;

-- Chat report resolution queue.
ALTER TABLE public.chat_reports
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS resolved_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS resolution_note TEXT;

DO $$ BEGIN
  ALTER TABLE public.chat_reports
    ADD CONSTRAINT chat_reports_status_check
    CHECK (status IN ('open', 'reviewed', 'action_taken', 'dismissed'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_chat_reports_status
  ON public.chat_reports(status, created_at DESC);

-- Rate limit chat reports (10/day).
CREATE OR REPLACE FUNCTION public.report_chat_message(
  p_message_id UUID,
  p_reason TEXT,
  p_details TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
  v_daily INT;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_message_id IS NULL OR public.normalize_chat_content(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz rapor');
  END IF;

  SELECT COUNT(*) INTO v_daily
  FROM public.chat_reports
  WHERE reporter_user_id = v_user.id
    AND created_at > now() - interval '1 day';

  IF v_daily >= 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Günlük rapor limitine ulaştınız.');
  END IF;

  INSERT INTO public.chat_reports (message_id, reporter_user_id, reason, details, status)
  VALUES (
    p_message_id,
    v_user.id,
    left(public.normalize_chat_content(p_reason), 120),
    left(public.normalize_chat_content(COALESCE(p_details, '')), 400),
    'open'
  )
  ON CONFLICT (message_id, reporter_user_id)
  DO UPDATE SET
    reason = EXCLUDED.reason,
    details = EXCLUDED.details,
    status = 'open',
    created_at = now(),
    resolved_at = NULL,
    resolved_by = NULL,
    resolution_note = NULL;

  PERFORM public.write_chat_audit(v_user.id, 'message_reported', NULL, p_message_id, jsonb_build_object('reason', p_reason));

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_chat_reports(
  p_status TEXT DEFAULT 'open',
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'chat.view_reports') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', r.id,
          'message_id', r.message_id,
          'reason', r.reason,
          'details', r.details,
          'status', r.status,
          'created_at', r.created_at,
          'reporter_username', ru.username,
          'sender_username', su.username,
          'sender_auth_id', su.auth_id,
          'message_preview', left(COALESCE(cm.content, ''), 120),
          'channel', cm.channel
        ) AS row
        FROM public.chat_reports r
        JOIN public.chat_messages cm ON cm.id = r.message_id
        JOIN public.users ru ON ru.id = r.reporter_user_id
        JOIN public.users su ON su.id = cm.sender_user_id
        WHERE p_status IS NULL OR r.status = p_status
        ORDER BY r.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
        OFFSET GREATEST(p_offset, 0)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_resolve_chat_report(
  p_report_id UUID,
  p_action TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_actor_game_id UUID;
  v_report RECORD;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'chat.view_reports');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_action NOT IN ('reviewed', 'action_taken', 'dismissed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz aksiyon.');
  END IF;

  SELECT r.*, cm.sender_user_id INTO v_report
  FROM public.chat_reports r
  JOIN public.chat_messages cm ON cm.id = r.message_id
  WHERE r.id = p_report_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  SELECT u.id INTO v_actor_game_id FROM public.users u WHERE u.auth_id = v_actor;

  IF p_action = 'action_taken'
     AND public.staff_has_permission(v_actor, 'chat.delete_message') THEN
    PERFORM public.delete_chat_message(v_report.message_id, COALESCE(p_note, 'report_action'));
  END IF;

  UPDATE public.chat_reports
  SET status = p_action,
      resolved_at = now(),
      resolved_by = v_actor_game_id,
      resolution_note = NULLIF(left(btrim(COALESCE(p_note, '')), 400), '')
  WHERE id = p_report_id;

  PERFORM public.staff_write_audit(
    v_actor, 'chat.view_reports', 'resolve_report', 'chat_report', p_report_id::text,
    jsonb_build_object('action', p_action),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_active_gms()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'staff.manage_gm')
     AND NOT public.staff_is_admin(v_actor) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'auth_id', sa.user_id,
        'username', u.username,
        'display_name', u.display_name,
        'granted_at', sa.granted_at,
        'permissions', COALESCE((
          SELECT jsonb_agg(sp.permission_key ORDER BY sp.permission_key)
          FROM public.staff_permissions sp
          WHERE sp.staff_assignment_id = sa.id
        ), '[]'::jsonb)
      ) ORDER BY u.username)
      FROM public.staff_assignments sa
      JOIN public.users u ON u.auth_id = sa.user_id
      WHERE sa.revoked_at IS NULL AND sa.role = 'gm'
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_suggest_bug_reward(
  p_report_id UUID,
  p_gems INT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_gems INT := GREATEST(COALESCE(p_gems, 0), 0);
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'bug.triage');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF v_gems < 100 OR v_gems > 5000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas 100–5000 arası olmalı.');
  END IF;

  UPDATE public.bug_reports
  SET suggested_gems = v_gems,
      suggested_by = v_actor,
      suggested_at = now(),
      status = CASE WHEN status = 'submitted' THEN 'triaged' ELSE status END,
      review_note = COALESCE(NULLIF(left(btrim(COALESCE(p_note, '')), 500), ''), review_note)
  WHERE id = p_report_id AND status NOT IN ('approved', 'rejected', 'duplicate');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı veya kapatılmış.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'bug.triage', 'suggest_reward', 'bug_report', p_report_id::text,
    jsonb_build_object('gems', v_gems),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'suggested_gems', v_gems);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_approve_bug_report(
  p_report_id UUID,
  p_gems INT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_report RECORD;
  v_month_total INT;
  v_gems INT := GREATEST(COALESCE(p_gems, 0), 0);
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'bug.approve_reward');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF v_gems < 100 OR v_gems > 5000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas 100–5000 arası olmalı.');
  END IF;

  SELECT * INTO v_report FROM public.bug_reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  IF v_report.status IN ('approved', 'rejected', 'duplicate') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor zaten kapatılmış.');
  END IF;

  IF v_report.player_id = v_actor THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi raporunuzu onaylayamazsınız.');
  END IF;

  SELECT COALESCE(SUM(reward_gems_approved), 0) INTO v_month_total
  FROM public.bug_reports
  WHERE player_id = v_report.player_id
    AND status = 'approved'
    AND reviewed_at > now() - interval '30 days';

  IF v_month_total + v_gems > 10000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aylık ödül limiti (10000💎) aşıldı.');
  END IF;

  UPDATE public.users
  SET gems = COALESCE(gems, 0) + v_gems
  WHERE auth_id = v_report.player_id;

  INSERT INTO public.gem_transactions (user_id, amount, reason, reference_type, reference_id, created_by)
  VALUES (v_report.player_id, v_gems, 'bug_reward', 'bug_report', p_report_id::text, v_actor);

  UPDATE public.bug_reports
  SET status = 'approved',
      reward_gems_approved = v_gems,
      reviewed_by = v_actor,
      reviewed_at = now(),
      review_note = NULLIF(left(btrim(COALESCE(p_note, '')), 500), '')
  WHERE id = p_report_id;

  PERFORM public._notify_player_inbox(
    v_report.player_id,
    'bug_approved',
    'Bug raporu onaylandı',
    format('+%s elmas hesabınıza eklendi.', v_gems),
    jsonb_build_object('report_id', p_report_id, 'gems', v_gems)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'bug.approve_reward', 'approve_bug', 'bug_report', p_report_id::text,
    jsonb_build_object('gems', v_gems, 'player_id', v_report.player_id),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'gems_granted', v_gems);
END;
$$;

-- needs_info notifies player.
CREATE OR REPLACE FUNCTION public.staff_update_bug_report(
  p_report_id UUID,
  p_status TEXT,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_player_id UUID;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'bug.triage');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_status NOT IN ('submitted', 'triaged', 'needs_info', 'rejected', 'duplicate') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz durum (onay ayrı RPC).');
  END IF;

  UPDATE public.bug_reports
  SET status = p_status,
      review_note = COALESCE(NULLIF(left(btrim(COALESCE(p_note, '')), 500), ''), review_note),
      reviewed_by = v_actor,
      reviewed_at = now()
  WHERE id = p_report_id
  RETURNING player_id INTO v_player_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  IF p_status = 'needs_info' THEN
    PERFORM public._notify_player_inbox(
      v_player_id,
      'bug_needs_info',
      'Bug raporu — ek bilgi gerekli',
      COALESCE(NULLIF(left(btrim(COALESCE(p_note, '')), 500), ''), 'Lütfen bug raporunuza ek bilgi ekleyin.'),
      jsonb_build_object('report_id', p_report_id)
    );
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'bug.triage', 'update_bug', 'bug_report', p_report_id::text,
    jsonb_build_object('status', p_status),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Ticket: default assign to theking admin on create.
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
  v_admin UUID;
  v_subject_hash TEXT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_policy := public.policy_require_acceptance(v_user);
  IF (v_policy->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_policy->>'error', 'policy_required', true);
  END IF;

  IF p_category NOT IN ('account', 'payment', 'bug', 'abuse', 'other') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz kategori.');
  END IF;

  IF char_length(btrim(COALESCE(p_subject, ''))) < 3 OR char_length(btrim(COALESCE(p_body, ''))) < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Konu ve mesaj yeterli olmalı.');
  END IF;

  SELECT COUNT(*) INTO v_open
  FROM public.support_tickets
  WHERE player_id = v_user AND status IN ('open', 'staff_reply', 'waiting_player');

  IF v_open >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'En fazla 3 açık ticket olabilir.');
  END IF;

  SELECT COUNT(*) INTO v_daily
  FROM public.support_tickets
  WHERE player_id = v_user AND created_at > now() - interval '1 day';

  IF v_daily >= 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Günlük ticket limitine ulaştınız.');
  END IF;

  v_subject_hash := md5(lower(btrim(p_subject)));

  SELECT COUNT(*) INTO v_recent
  FROM public.support_tickets
  WHERE player_id = v_user
    AND md5(lower(btrim(subject))) = v_subject_hash
    AND created_at > now() - interval '24 hours';

  IF v_recent > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aynı konuda kısa sürede tekrar ticket açılamaz.');
  END IF;

  SELECT u.auth_id INTO v_admin
  FROM public.users u
  JOIN public.staff_assignments sa ON sa.user_id = u.auth_id AND sa.revoked_at IS NULL AND sa.role = 'admin'
  WHERE lower(u.username) = 'theking'
  LIMIT 1;

  INSERT INTO public.support_tickets (
    player_id, category, subject, body, status, assigned_staff_id
  )
  VALUES (
    v_user, p_category, left(btrim(p_subject), 120), left(btrim(p_body), 4000), 'open', v_admin
  )
  RETURNING id INTO v_ticket_id;

  INSERT INTO public.support_ticket_messages (ticket_id, sender_id, is_staff, body)
  VALUES (v_ticket_id, v_user, false, left(btrim(p_body), 4000));

  RETURN jsonb_build_object('success', true, 'ticket_id', v_ticket_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_assign_ticket(
  p_ticket_id UUID,
  p_staff_auth_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'ticket.view_all');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.staff_assignments sa
    WHERE sa.user_id = p_staff_auth_id AND sa.revoked_at IS NULL
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Staff bulunamadı.');
  END IF;

  UPDATE public.support_tickets
  SET assigned_staff_id = p_staff_auth_id, updated_at = now()
  WHERE id = p_ticket_id;

  PERFORM public.staff_write_audit(
    v_actor, 'ticket.view_all', 'assign_ticket', 'ticket', p_ticket_id::text,
    jsonb_build_object('assigned_to', p_staff_auth_id),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_reply_ticket(p_ticket_id UUID, p_body TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_player_id UUID;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'ticket.reply');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  SELECT player_id INTO v_player_id FROM public.support_tickets WHERE id = p_ticket_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ticket yok.');
  END IF;

  INSERT INTO public.support_ticket_messages (ticket_id, sender_id, is_staff, body)
  VALUES (p_ticket_id, v_actor, true, left(btrim(p_body), 4000));

  UPDATE public.support_tickets
  SET status = 'staff_reply', assigned_staff_id = v_actor, updated_at = now()
  WHERE id = p_ticket_id;

  PERFORM public._notify_player_inbox(
    v_player_id,
    'ticket_reply',
    'Destek talebinize yanıt',
    left(btrim(p_body), 200),
    jsonb_build_object('ticket_id', p_ticket_id)
  );

  PERFORM public.staff_write_audit(v_actor, 'ticket.reply', 'reply_ticket', 'ticket', p_ticket_id::text, '{}'::jsonb, '{"success":true}'::jsonb);

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_tickets(
  p_status TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'ticket.view_all') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'updated_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', t.id,
          'player_id', t.player_id,
          'username', u.username,
          'category', t.category,
          'subject', t.subject,
          'status', t.status,
          'priority', t.priority,
          'assigned_staff_id', t.assigned_staff_id,
          'created_at', t.created_at,
          'updated_at', t.updated_at
        ) AS row
        FROM public.support_tickets t
        JOIN public.users u ON u.auth_id = t.player_id
        WHERE (p_status IS NULL OR t.status = p_status)
          AND (p_category IS NULL OR t.category = p_category)
        ORDER BY t.updated_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
        OFFSET GREATEST(p_offset, 0)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_audit(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_action TEXT DEFAULT NULL,
  p_actor_user_id UUID DEFAULT NULL,
  p_target_type TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'staff.view_audit') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', a.id,
          'actor_user_id', a.actor_user_id,
          'actor_username', u.username,
          'permission_key', a.permission_key,
          'action', a.action,
          'target_type', a.target_type,
          'target_id', a.target_id,
          'payload', a.payload,
          'result', a.result,
          'created_at', a.created_at
        ) AS row
        FROM public.staff_audit_log a
        LEFT JOIN public.users u ON u.auth_id = a.actor_user_id
        WHERE (p_action IS NULL OR a.action = p_action)
          AND (p_actor_user_id IS NULL OR a.actor_user_id = p_actor_user_id)
          AND (p_target_type IS NULL OR a.target_type = p_target_type)
        ORDER BY a.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
        OFFSET GREATEST(p_offset, 0)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_get_dashboard()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'staff.view_hub') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'open_tickets', (SELECT COUNT(*) FROM public.support_tickets WHERE status IN ('open', 'waiting_player')),
    'pending_bugs', (SELECT COUNT(*) FROM public.bug_reports WHERE status IN ('submitted', 'triaged', 'needs_info')),
    'open_chat_reports', (SELECT COUNT(*) FROM public.chat_reports WHERE status = 'open'),
    'recent_audit', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'action', a.action,
          'created_at', a.created_at,
          'target_type', a.target_type,
          'actor_username', u.username
        ) AS row
        FROM public.staff_audit_log a
        LEFT JOIN public.users u ON u.auth_id = a.actor_user_id
        ORDER BY a.created_at DESC
        LIMIT 8
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_get_bug_report_detail(p_report_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_b RECORD;
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'bug.view') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  SELECT b.*, u.username
  INTO v_b
  FROM public.bug_reports b
  JOIN public.users u ON u.auth_id = b.player_id
  WHERE b.id = p_report_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'report', jsonb_build_object(
      'id', v_b.id,
      'player_id', v_b.player_id,
      'username', v_b.username,
      'category', v_b.category,
      'title', v_b.title,
      'description', v_b.description,
      'repro_steps', v_b.repro_steps,
      'client_meta', v_b.client_meta,
      'status', v_b.status,
      'reward_gems_approved', v_b.reward_gems_approved,
      'suggested_gems', v_b.suggested_gems,
      'suggested_by', v_b.suggested_by,
      'suggested_at', v_b.suggested_at,
      'review_note', v_b.review_note,
      'duplicate_of', v_b.duplicate_of,
      'created_at', v_b.created_at
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_edit_market_listing(
  p_order_id UUID,
  p_payload JSONB,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'market.edit_listing');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  UPDATE public.market_orders
  SET
    price = COALESCE((p_payload->>'price')::int, price),
    quantity = COALESCE((p_payload->>'quantity')::int, quantity)
  WHERE id = p_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'İlan bulunamadı.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'market.edit_listing', 'edit_listing', 'market_order', p_order_id::text,
    jsonb_build_object('payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_inbox_notifications(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_inbox_notification_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_chat_reports(text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_resolve_chat_report(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_active_gms() TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_suggest_bug_reward(uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_assign_ticket(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_edit_market_listing(uuid, jsonb, text) TO authenticated;

COMMIT;
