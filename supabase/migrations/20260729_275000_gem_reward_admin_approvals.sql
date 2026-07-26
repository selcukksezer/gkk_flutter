-- Admin-only gem reward approval queue + history.

BEGIN;

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
  v_report RECORD;
  v_month_total INT;
  v_gems INT := GREATEST(COALESCE(p_gems, 0), 0);
BEGIN
  IF NOT public.staff_is_admin(v_actor) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas onayı yalnızca admin tarafından yapılabilir.');
  END IF;

  SELECT * INTO v_report FROM public.bug_reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  IF v_report.status IN ('approved', 'rejected', 'duplicate') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor zaten kapatılmış.');
  END IF;

  IF v_report.suggested_gems IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Önce GM elmas önerisi kaydedilmeli.');
  END IF;

  IF v_gems < 100 OR v_gems > 5000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas 100–5000 arası olmalı.');
  END IF;

  IF v_gems <> v_report.suggested_gems THEN
    RETURN jsonb_build_object(
      'success', false,
      'error',
      format('Onay miktarı önerilen elmasla aynı olmalı (%s💎).', v_report.suggested_gems)
    );
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
    jsonb_build_object('gems', v_gems, 'player_id', v_report.player_id, 'suggested_gems', v_report.suggested_gems),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'gems_granted', v_gems);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_gem_reward_pending(p_limit INT DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_is_admin(v_actor) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'suggested_at' DESC NULLS LAST, row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', b.id,
          'player_id', b.player_id,
          'username', pu.username,
          'display_name', pu.display_name,
          'category', b.category,
          'title', b.title,
          'status', b.status,
          'suggested_gems', b.suggested_gems,
          'suggested_at', b.suggested_at,
          'suggested_by', b.suggested_by,
          'suggester_username', su.username,
          'created_at', b.created_at
        ) AS row
        FROM public.bug_reports b
        JOIN public.users pu ON pu.auth_id = b.player_id
        LEFT JOIN public.users su ON su.auth_id = b.suggested_by
        WHERE b.suggested_gems IS NOT NULL
          AND b.status NOT IN ('approved', 'rejected', 'duplicate')
        ORDER BY b.suggested_at DESC NULLS LAST, b.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_list_gem_reward_history(
  p_username_query TEXT DEFAULT NULL,
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
  v_q TEXT := lower(btrim(COALESCE(p_username_query, '')));
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
  v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
BEGIN
  IF NOT public.staff_is_admin(v_actor) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'reviewed_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', b.id,
          'player_id', b.player_id,
          'username', pu.username,
          'display_name', pu.display_name,
          'category', b.category,
          'title', b.title,
          'reward_gems_approved', b.reward_gems_approved,
          'suggested_gems', b.suggested_gems,
          'reviewed_at', b.reviewed_at,
          'reviewed_by', b.reviewed_by,
          'reviewer_username', ru.username,
          'suggester_username', su.username,
          'review_note', b.review_note
        ) AS row
        FROM public.bug_reports b
        JOIN public.users pu ON pu.auth_id = b.player_id
        LEFT JOIN public.users ru ON ru.auth_id = b.reviewed_by
        LEFT JOIN public.users su ON su.auth_id = b.suggested_by
        WHERE b.status = 'approved'
          AND COALESCE(b.reward_gems_approved, 0) > 0
          AND (
            v_q = ''
            OR lower(pu.username) LIKE '%' || v_q || '%'
            OR lower(COALESCE(pu.display_name, '')) LIKE '%' || v_q || '%'
          )
        ORDER BY b.reviewed_at DESC NULLS LAST
        LIMIT v_limit
        OFFSET v_offset
      ) sub
    ), '[]'::jsonb),
    'has_more', (
      SELECT COUNT(*) > v_limit + v_offset
      FROM public.bug_reports b
      JOIN public.users pu ON pu.auth_id = b.player_id
      WHERE b.status = 'approved'
        AND COALESCE(b.reward_gems_approved, 0) > 0
        AND (
          v_q = ''
          OR lower(pu.username) LIKE '%' || v_q || '%'
          OR lower(COALESCE(pu.display_name, '')) LIKE '%' || v_q || '%'
        )
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_reject_gem_reward_request(
  p_report_id UUID,
  p_note TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_report RECORD;
BEGIN
  IF NOT public.staff_is_admin(v_actor) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  SELECT * INTO v_report FROM public.bug_reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  IF v_report.suggested_gems IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas önerisi yok.');
  END IF;

  IF v_report.status IN ('approved', 'rejected', 'duplicate') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor zaten kapatılmış.');
  END IF;

  UPDATE public.bug_reports
  SET status = 'rejected',
      reviewed_by = v_actor,
      reviewed_at = now(),
      review_note = NULLIF(
        left(btrim(COALESCE(p_note, 'Elmas ödülü reddedildi.')), 500),
        ''
      )
  WHERE id = p_report_id;

  PERFORM public._notify_player_inbox(
    v_report.player_id,
    'bug_rejected',
    'Bug raporu reddedildi',
    COALESCE(
      NULLIF(left(btrim(COALESCE(p_note, '')), 500), ''),
      'Elmas ödülü talebi reddedildi.'
    ),
    jsonb_build_object('report_id', p_report_id)
  );

  PERFORM public.staff_write_audit(
    v_actor,
    'bug.approve_reward',
    'reject_gem_reward',
    'bug_report',
    p_report_id::text,
    jsonb_build_object(
      'player_id', v_report.player_id,
      'suggested_gems', v_report.suggested_gems
    ),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
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
    'open_tickets', (
      SELECT COUNT(*)
      FROM public.support_tickets
      WHERE status IN ('open', 'waiting_player')
    ),
    'pending_bugs', (
      SELECT COUNT(*)
      FROM public.bug_reports
      WHERE status IN ('submitted', 'needs_info')
    ),
    'pending_gem_rewards', (
      SELECT COUNT(*)
      FROM public.bug_reports
      WHERE suggested_gems IS NOT NULL
        AND status NOT IN ('approved', 'rejected', 'duplicate')
    ),
    'open_chat_reports', (
      SELECT COUNT(*)
      FROM public.chat_reports
      WHERE status = 'open'
    ),
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

GRANT EXECUTE ON FUNCTION public.staff_list_gem_reward_pending(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_list_gem_reward_history(text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_reject_gem_reward_request(uuid, text) TO authenticated;

COMMIT;
