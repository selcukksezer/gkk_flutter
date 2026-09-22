-- Legal doc bodies live in app (LegalDocumentContent). DB keeps metadata only.

BEGIN;

UPDATE public.legal_documents
SET body_md = ''
WHERE doc_type IN ('terms', 'privacy', 'community');

COMMIT;
