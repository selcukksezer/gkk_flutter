-- Legal documents + policy acceptance gate (App Store / Play UGC compliance).

BEGIN;

CREATE TABLE IF NOT EXISTS public.legal_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_type TEXT NOT NULL CHECK (doc_type IN ('terms', 'privacy', 'community')),
  version INTEGER NOT NULL DEFAULT 1,
  title TEXT NOT NULL,
  body_md TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (doc_type, version)
);

CREATE TABLE IF NOT EXISTS public.policy_acceptances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL CHECK (doc_type IN ('terms', 'privacy', 'community')),
  version INTEGER NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, doc_type, version)
);

CREATE INDEX IF NOT EXISTS idx_policy_acceptances_user
  ON public.policy_acceptances(user_id, doc_type);

ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_acceptances ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS legal_documents_select ON public.legal_documents;
CREATE POLICY legal_documents_select ON public.legal_documents
  FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS policy_acceptances_own ON public.policy_acceptances;
CREATE POLICY policy_acceptances_own ON public.policy_acceptances
  FOR SELECT USING (user_id = auth.uid());

-- Deactivate old versions when seeding new
UPDATE public.legal_documents SET is_active = false WHERE doc_type IN ('terms', 'privacy', 'community');

INSERT INTO public.legal_documents (doc_type, version, title, body_md, is_active)
VALUES
(
  'terms',
  1,
  'Kullanım Koşulları',
  E'# Kullanım Koşulları\n\nGKK oyununu kullanarak bu koşulları kabul etmiş olursunuz.\n\n## Hesap\n- Hesabınız size aittir; paylaşmayın.\n- Hile, exploit ve kötüye kullanım kalıcı ban sebebidir.\n\n## Sanal para\n- Elmas ve altın oyun içi sanal varlıktır; gerçek para iadesi yoktur.\n- Promosyon elmasları (bug bildirimi vb.) mağaza satın alımı değildir.\n\n## Bug bildirimi\n- Bug bildirimi için **App Store / Play Store yorumu veya puan karşılığı ödül talep edilemez**.\n- Doğrulama sonrası uygun bulunan raporlara oyun içi elmas verilebilir; garanti yoktur.\n\n## İletişim\nDestek: uygulama içi ticket veya support@gkk.game',
  true
),
(
  'privacy',
  1,
  'Gizlilik Politikası',
  E'# Gizlilik Politikası\n\n## Topladığımız veriler\n- Hesap bilgileri (e-posta, kullanıcı adı, görünen ad)\n- Oyun ilerlemesi ve envanter\n- Bug bildiriminde: uygulama sürümü, platform, dil (cihaz tanımlayıcısı toplanmaz)\n\n## Kullanım\n- Oyun hizmeti, destek ve güvenlik\n- Moderasyon ve kötüye kullanım önleme\n\n## Saklama\nHesap silme talebinde kişisel veriler silinir; yasal zorunlu loglar saklanabilir.\n\n## İletişim\nsupport@gkk.game',
  true
),
(
  'community',
  1,
  'Topluluk Kuralları',
  E'# Topluluk Kuralları\n\n## Yasak\n- Hakaret, taciz, nefret söylemi\n- Dolandırıcı trade / scam\n- Spam, reklam, NSFW içerik\n- Gerçek dünya tehditleri\n\n## Moderasyon\n- Mesaj silme, susturma, hesap ban uygulanabilir\n- İtiraz: destek ticket\n\n## Raporlama\nUygunsuz içerik ve oyuncuları sohbetten raporlayın veya engelleyin.',
  true
)
ON CONFLICT (doc_type, version) DO UPDATE SET
  title = EXCLUDED.title,
  body_md = EXCLUDED.body_md,
  is_active = EXCLUDED.is_active;

CREATE OR REPLACE FUNCTION public.get_active_legal_documents()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'type', doc_type,
        'version', version,
        'title', title,
        'body_md', body_md,
        'published_at', published_at
      )
      ORDER BY doc_type
    ),
    '[]'::jsonb
  )
  FROM public.legal_documents
  WHERE is_active = true;
$$;

CREATE OR REPLACE FUNCTION public.get_my_policy_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_missing JSONB := '[]'::jsonb;
  v_doc RECORD;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  FOR v_doc IN
    SELECT doc_type, version FROM public.legal_documents WHERE is_active = true
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
    'missing', v_missing
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.policy_require_acceptance(p_user_id UUID DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status JSONB;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT public.get_my_policy_status() INTO v_status;
  IF COALESCE((v_status->>'all_accepted')::boolean, false) = false THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Devam etmek için Kullanım Koşulları, Gizlilik ve Topluluk Kurallarını kabul edin.',
      'missing', v_status->'missing'
    );
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_legal_document(p_doc_type TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_version INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF p_doc_type NOT IN ('terms', 'privacy', 'community') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz belge türü.');
  END IF;

  SELECT version INTO v_version
  FROM public.legal_documents
  WHERE doc_type = p_doc_type AND is_active = true
  LIMIT 1;

  IF v_version IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Belge bulunamadı.');
  END IF;

  INSERT INTO public.policy_acceptances (user_id, doc_type, version)
  VALUES (v_user, p_doc_type, v_version)
  ON CONFLICT (user_id, doc_type, version) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'status', public.get_my_policy_status());
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_all_legal_documents()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_doc RECORD;
BEGIN
  FOR v_doc IN SELECT doc_type FROM public.legal_documents WHERE is_active = true
  LOOP
    PERFORM public.accept_legal_document(v_doc.doc_type);
  END LOOP;
  RETURN jsonb_build_object('success', true, 'status', public.get_my_policy_status());
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_legal_documents() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_policy_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_legal_document(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_all_legal_documents() TO authenticated;

COMMIT;
