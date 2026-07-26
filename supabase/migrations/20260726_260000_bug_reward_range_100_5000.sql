-- Bug reward range: 100–5000 elmas (UI + staff onay).

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

  UPDATE public.bug_reports
  SET status = 'approved',
      reward_gems_approved = v_gems,
      reviewed_by = v_actor,
      reviewed_at = now(),
      review_note = NULLIF(left(btrim(COALESCE(p_note, '')), 500), '')
  WHERE id = p_report_id;

  PERFORM public.staff_write_audit(
    v_actor, 'bug.approve_reward', 'approve_bug', 'bug_report', p_report_id::text,
    jsonb_build_object('gems', v_gems, 'player_id', v_report.player_id),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'gems_granted', v_gems);
END;
$$;

COMMIT;
