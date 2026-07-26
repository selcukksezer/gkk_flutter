-- Bug: öneri kategorisi + aynı raporda ek bilgi (follow-up).

BEGIN;

ALTER TABLE public.bug_reports DROP CONSTRAINT IF EXISTS bug_reports_category_check;
ALTER TABLE public.bug_reports
  ADD CONSTRAINT bug_reports_category_check
  CHECK (category IN ('crash', 'ui', 'economy', 'chat', 'suggestion', 'other'));

CREATE TABLE IF NOT EXISTS public.bug_report_followups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES public.bug_reports(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  is_staff BOOLEAN NOT NULL DEFAULT false,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bug_report_followups_report
  ON public.bug_report_followups(report_id, created_at ASC);

ALTER TABLE public.bug_report_followups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bug_followups_select ON public.bug_report_followups;
CREATE POLICY bug_followups_select ON public.bug_report_followups
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bug_reports b
      WHERE b.id = report_id AND b.player_id = auth.uid()
    )
    OR public.staff_has_permission(auth.uid(), 'bug.view')
  );

DROP POLICY IF EXISTS bug_followups_insert_player ON public.bug_report_followups;
CREATE POLICY bug_followups_insert_player ON public.bug_report_followups
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND is_staff = false
    AND EXISTS (
      SELECT 1 FROM public.bug_reports b
      WHERE b.id = report_id
        AND b.player_id = auth.uid()
        AND b.status = 'needs_info'
    )
  );

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

  IF p_category NOT IN ('crash', 'ui', 'economy', 'chat', 'suggestion', 'other') THEN
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

CREATE OR REPLACE FUNCTION public.get_player_bug_report_detail(p_report_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_b RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT b.*
  INTO v_b
  FROM public.bug_reports b
  WHERE b.id = p_report_id AND b.player_id = v_user;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'report', jsonb_build_object(
      'id', v_b.id,
      'category', v_b.category,
      'title', v_b.title,
      'description', v_b.description,
      'repro_steps', v_b.repro_steps,
      'status', v_b.status,
      'reward_gems_approved', v_b.reward_gems_approved,
      'suggested_gems', v_b.suggested_gems,
      'review_note', v_b.review_note,
      'created_at', v_b.created_at
    ),
    'followups', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', f.id,
        'body', f.body,
        'is_staff', f.is_staff,
        'created_at', f.created_at
      ) ORDER BY f.created_at ASC)
      FROM public.bug_report_followups f
      WHERE f.report_id = p_report_id
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.append_bug_report_followup(
  p_report_id UUID,
  p_body TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_report RECORD;
  v_body TEXT := left(btrim(COALESCE(p_body, '')), 4000);
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF char_length(v_body) < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ek bilgi en az 10 karakter olmalı.');
  END IF;

  SELECT * INTO v_report
  FROM public.bug_reports
  WHERE id = p_report_id AND player_id = v_user
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  IF v_report.status <> 'needs_info' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu rapor için ek bilgi beklenmiyor.');
  END IF;

  INSERT INTO public.bug_report_followups (report_id, author_id, is_staff, body)
  VALUES (p_report_id, v_user, false, v_body);

  UPDATE public.bug_reports
  SET status = 'submitted',
      reviewed_at = now()
  WHERE id = p_report_id;

  RETURN jsonb_build_object('success', true);
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
    ),
    'followups', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', f.id,
        'body', f.body,
        'is_staff', f.is_staff,
        'author_id', f.author_id,
        'created_at', f.created_at
      ) ORDER BY f.created_at ASC)
      FROM public.bug_report_followups f
      WHERE f.report_id = p_report_id
    ), '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_player_bug_report_detail(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.append_bug_report_followup(uuid, text) TO authenticated;

COMMIT;
