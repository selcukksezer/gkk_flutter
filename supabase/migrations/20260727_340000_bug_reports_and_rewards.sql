-- Bug reports + gem reward approval flow.

BEGIN;

CREATE TABLE IF NOT EXISTS public.bug_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN ('crash', 'ui', 'economy', 'chat', 'other')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  repro_steps TEXT,
  client_meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  content_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN (
    'submitted', 'triaged', 'needs_info', 'approved', 'rejected', 'duplicate'
  )),
  reward_gems_approved INT,
  reviewed_by UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  review_note TEXT,
  duplicate_of UUID REFERENCES public.bug_reports(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bug_reports_player ON public.bug_reports(player_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON public.bug_reports(status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_bug_reports_hash_player
  ON public.bug_reports(player_id, content_hash)
  WHERE status NOT IN ('rejected', 'duplicate');

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bug_reports_own ON public.bug_reports;
CREATE POLICY bug_reports_own ON public.bug_reports
  FOR SELECT USING (player_id = auth.uid());

CREATE OR REPLACE FUNCTION public.submit_bug_report(
  p_category TEXT,
  p_title TEXT,
  p_description TEXT,
  p_repro_steps TEXT DEFAULT NULL,
  p_client_meta JSONB DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_policy JSONB;
  v_hash TEXT;
  v_daily INT;
  v_id UUID;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_policy := public.policy_require_acceptance(v_user);
  IF (v_policy->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_policy->>'error', 'policy_required', true);
  END IF;

  IF p_category NOT IN ('crash', 'ui', 'economy', 'chat', 'other') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz kategori.');
  END IF;

  IF char_length(btrim(COALESCE(p_title, ''))) < 5 OR char_length(btrim(COALESCE(p_description, ''))) < 30 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Başlık ve açıklama yeterli olmalı.');
  END IF;

  v_hash := md5(lower(btrim(p_title)) || '|' || lower(left(btrim(p_description), 500)));

  IF EXISTS (
    SELECT 1 FROM public.bug_reports
    WHERE player_id = v_user AND content_hash = v_hash
      AND status NOT IN ('rejected', 'duplicate')
      AND created_at > now() - interval '30 days'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Benzer bir rapor zaten mevcut.');
  END IF;

  SELECT COUNT(*) INTO v_daily
  FROM public.bug_reports
  WHERE player_id = v_user AND created_at > now() - interval '24 hours';

  IF v_daily >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Günlük bug rapor limitine ulaşıldı.');
  END IF;

  INSERT INTO public.bug_reports (
    player_id, category, title, description, repro_steps, client_meta, content_hash
  ) VALUES (
    v_user, p_category, left(btrim(p_title), 120), left(btrim(p_description), 4000),
    NULLIF(left(btrim(COALESCE(p_repro_steps, '')), 2000), ''),
    COALESCE(p_client_meta, '{}'::jsonb), v_hash
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'report_id', v_id);
END;
$$;

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

  IF v_gems <= 0 OR v_gems > 500 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Elmas 1–500 arası olmalı.');
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

  IF v_month_total + v_gems > 2000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aylık ödül limiti (2000💎) aşıldı.');
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

GRANT EXECUTE ON FUNCTION public.submit_bug_report(text, text, text, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_bug_reports() TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_approve_bug_report(uuid, int, text) TO authenticated;

COMMIT;
