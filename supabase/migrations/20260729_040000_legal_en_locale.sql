-- Legal documents EN locale column + seed English versions.

BEGIN;

ALTER TABLE public.legal_documents
  ADD COLUMN IF NOT EXISTS locale TEXT NOT NULL DEFAULT 'tr';

ALTER TABLE public.legal_documents
  DROP CONSTRAINT IF EXISTS legal_documents_doc_type_version_key;

ALTER TABLE public.legal_documents
  ADD CONSTRAINT legal_documents_doc_type_version_locale_key
  UNIQUE (doc_type, version, locale);

CREATE INDEX IF NOT EXISTS idx_legal_documents_active_locale
  ON public.legal_documents(doc_type, locale, is_active);

INSERT INTO public.legal_documents (doc_type, version, title, body_md, is_active, locale)
VALUES
  ('terms', 1, 'Terms of Service', E'# Terms of Service\n\nBy using this game you agree to these terms.\n\n## Virtual Currency\nIn-app purchases and promotional gems (e.g. bug bounties) are separate. Promotional gems are not guaranteed.\n\n## Prohibited Conduct\nNo cheating, harassment, or review-for-reward manipulation.\n\n## Account\nYou may delete your account in Settings.', true, 'en'),
  ('privacy', 1, 'Privacy Policy', E'# Privacy Policy\n\nWe process account data (email, username), gameplay stats, and support messages.\n\n## Storage\nData is stored on Supabase (EU region where configured).\n\n## Deletion\nYou may request account deletion in Settings.\n\n## Contact\nUse in-app support tickets.', true, 'en'),
  ('community', 1, 'Community Guidelines', E'# Community Guidelines\n\n## Respect\nTreat other players with respect. No hate speech, threats, or scams.\n\n## UGC\nChat content may be moderated. Report messages via long-press.\n\n## Enforcement\nViolations may result in mute, ban, or account termination.', true, 'en')
ON CONFLICT (doc_type, version, locale) DO UPDATE SET
  title = EXCLUDED.title,
  body_md = EXCLUDED.body_md,
  is_active = EXCLUDED.is_active;

CREATE OR REPLACE FUNCTION public.get_active_legal_documents(p_locale TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_locale TEXT := lower(COALESCE(NULLIF(btrim(p_locale), ''), 'tr'));
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'type', d.doc_type,
      'doc_type', d.doc_type,
      'version', d.version,
      'title', d.title,
      'body_md', d.body_md,
      'locale', d.locale,
      'published_at', d.published_at
    ) ORDER BY d.doc_type)
    FROM public.legal_documents d
    WHERE d.is_active = true AND d.locale = v_locale
  ), '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_policy_status(p_locale TEXT DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_locale TEXT := lower(COALESCE(NULLIF(btrim(p_locale), ''), 'tr'));
  v_missing JSONB := '[]'::jsonb;
  v_doc RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  FOR v_doc IN
    SELECT doc_type, version
    FROM public.legal_documents
    WHERE is_active = true AND locale = v_locale
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.policy_acceptances pa
      WHERE pa.user_id = v_user
        AND pa.doc_type = v_doc.doc_type
        AND pa.version = v_doc.version
    ) THEN
      v_missing := v_missing || jsonb_build_array(v_doc.doc_type);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'all_accepted', jsonb_array_length(v_missing) = 0,
    'missing', v_missing,
    'locale', v_locale
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_legal_documents(text) TO authenticated, anon;

COMMIT;
