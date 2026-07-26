-- Bug approve requires GM suggest first; expose suggest on player list.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_my_bug_reports()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', b.id,
        'category', b.category,
        'title', b.title,
        'status', b.status,
        'suggested_gems', b.suggested_gems,
        'reward_gems_approved', b.reward_gems_approved,
        'review_note', b.review_note,
        'created_at', b.created_at
      ) ORDER BY b.created_at DESC)
      FROM public.bug_reports b
      WHERE b.player_id = auth.uid()
      LIMIT 50
    ), '[]'::jsonb)
  );
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

COMMIT;
