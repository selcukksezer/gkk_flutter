-- Staff RBAC core: assignments, permissions catalog, audit, helper guards.

BEGIN;

DO $$ BEGIN
  CREATE TYPE public.staff_role AS ENUM ('admin', 'gm');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.staff_badge AS ENUM ('admin', 'gm');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.staff_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(auth_id) ON DELETE CASCADE,
  role public.staff_role NOT NULL DEFAULT 'gm',
  display_badge public.staff_badge NOT NULL DEFAULT 'gm',
  granted_by UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ,
  revoke_reason TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_assignments_active_user
  ON public.staff_assignments(user_id)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS public.staff_permission_catalog (
  key TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  label_tr TEXT NOT NULL,
  description_tr TEXT NOT NULL DEFAULT '',
  min_role public.staff_role NOT NULL DEFAULT 'gm',
  is_dangerous BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.staff_permissions (
  staff_assignment_id UUID NOT NULL REFERENCES public.staff_assignments(id) ON DELETE CASCADE,
  permission_key TEXT NOT NULL REFERENCES public.staff_permission_catalog(key) ON DELETE CASCADE,
  PRIMARY KEY (staff_assignment_id, permission_key)
);

CREATE TABLE IF NOT EXISTS public.staff_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  permission_key TEXT,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  result JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_staff_audit_created
  ON public.staff_audit_log(created_at DESC);

ALTER TABLE public.staff_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_audit_log ENABLE ROW LEVEL SECURITY;

-- Seed permission catalog
INSERT INTO public.staff_permission_catalog (key, category, label_tr, description_tr, min_role, is_dangerous)
VALUES
  ('staff.view_hub', 'staff', 'Staff Hub', 'Staff paneline erişim', 'gm', false),
  ('staff.view_audit', 'staff', 'Audit log', 'Staff işlem geçmişi', 'gm', false),
  ('staff.manage_gm', 'staff', 'GM yönetimi', 'GM atama ve izin', 'admin', true),
  ('player.view_detail', 'player', 'Oyuncu detay', 'Profil ve ekonomi görüntüle', 'gm', false),
  ('player.rename', 'player', 'İsim değiştir', 'Görünen ad düzenle', 'gm', true),
  ('player.ban', 'player', 'Hesap ban', 'Oyuncuyu banla', 'gm', true),
  ('player.unban', 'player', 'Ban kaldır', 'Ban kaldır', 'gm', true),
  ('player.chat_mute', 'player', 'Chat sustur', 'Süreli chat ban', 'gm', true),
  ('player.restrict_hospital', 'player', 'Hastane', 'hospital_until ayarla', 'gm', true),
  ('player.restrict_prison', 'player', 'Hapishane', 'prison_until ayarla', 'gm', true),
  ('player.restrict_trade', 'player', 'Trade ban', 'trade_banned_until ayarla', 'gm', true),
  ('player.grant_gems', 'player', 'Elmas ver', 'Manuel elmas', 'admin', true),
  ('player.grant_gold', 'player', 'Altın ver', 'Manuel altın', 'gm', true),
  ('player.adjust_inventory', 'player', 'Envanter', 'Item ekle/çıkar', 'gm', true),
  ('chat.delete_message', 'chat', 'Mesaj sil', 'Chat mesajı sil', 'gm', false),
  ('chat.view_reports', 'chat', 'Chat raporları', 'Rapor kuyruğu', 'gm', false),
  ('chat.manage_filters', 'chat', 'Filtreler', 'Kelime filtresi', 'gm', false),
  ('ticket.view_all', 'ticket', 'Ticketler', 'Tüm destek talepleri', 'gm', false),
  ('ticket.reply', 'ticket', 'Ticket yanıt', 'Oyuncuya yanıt', 'gm', false),
  ('ticket.close', 'ticket', 'Ticket kapat', 'Talebi kapat', 'gm', false),
  ('bug.view', 'bug', 'Bug listesi', 'Bug raporları', 'gm', false),
  ('bug.triage', 'bug', 'Bug triage', 'Durum güncelle', 'gm', false),
  ('bug.approve_reward', 'bug', 'Bug elmas onay', 'Onaylı elmas ödülü', 'admin', true),
  ('market.remove_listing', 'market', 'İlan kaldır', 'Pazar ilanı sil', 'gm', true),
  ('market.edit_listing', 'market', 'İlan düzenle', 'Pazar fiyat/adet', 'gm', true),
  ('liveops.bp_season', 'liveops', 'BP sezon', 'Battle pass sezon', 'admin', true),
  ('liveops.bp_rewards', 'liveops', 'BP ödüller', 'Ödül tablosu', 'admin', true),
  ('liveops.daily_rewards', 'liveops', 'Günlük ödül', 'Daily reward config', 'admin', true),
  ('liveops.guild_war_season', 'liveops', 'Lonca savaşı', 'GW sezon/territory', 'admin', true),
  ('liveops.shop_catalog', 'liveops', 'Mağaza', 'Shop item config', 'admin', true),
  ('liveops.night_market', 'liveops', 'Gece pazarı', 'Night market config', 'admin', true),
  ('liveops.broadcast', 'liveops', 'Duyuru', 'Live ticker broadcast', 'gm', false)
ON CONFLICT (key) DO UPDATE SET
  label_tr = EXCLUDED.label_tr,
  description_tr = EXCLUDED.description_tr,
  min_role = EXCLUDED.min_role,
  is_dangerous = EXCLUDED.is_dangerous;

CREATE OR REPLACE FUNCTION public.staff_active_assignment(p_user_id UUID DEFAULT auth.uid())
RETURNS public.staff_assignments
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT sa.*
  FROM public.staff_assignments sa
  WHERE sa.user_id = p_user_id AND sa.revoked_at IS NULL
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.staff_is_admin(p_user_id UUID DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.staff_assignments sa
    WHERE sa.user_id = p_user_id AND sa.revoked_at IS NULL AND sa.role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.staff_has_permission(
  p_user_id UUID,
  p_permission_key TEXT
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sa public.staff_assignments;
BEGIN
  IF p_user_id IS NULL OR p_permission_key IS NULL THEN
    RETURN false;
  END IF;

  v_sa := public.staff_active_assignment(p_user_id);
  IF v_sa.id IS NULL THEN
    RETURN false;
  END IF;

  IF v_sa.role = 'admin' THEN
    RETURN true;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.staff_permissions sp
    WHERE sp.staff_assignment_id = v_sa.id
      AND sp.permission_key = p_permission_key
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_require_permission(
  p_user_id UUID,
  p_permission_key TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.staff_has_permission(p_user_id, p_permission_key) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Bu işlem için yetkiniz yok.');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_write_audit(
  p_actor UUID,
  p_permission_key TEXT,
  p_action TEXT,
  p_target_type TEXT,
  p_target_id TEXT,
  p_payload JSONB DEFAULT '{}'::jsonb,
  p_result JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.staff_audit_log (
    actor_user_id, permission_key, action, target_type, target_id, payload, result
  ) VALUES (
    p_actor, p_permission_key, p_action, p_target_type, p_target_id,
    COALESCE(p_payload, '{}'::jsonb), COALESCE(p_result, '{}'::jsonb)
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_staff_badge(p_user_id UUID)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE sa.display_badge
    WHEN 'admin' THEN 'admin'
    WHEN 'gm' THEN 'gm'
    ELSE NULL
  END
  FROM public.staff_assignments sa
  WHERE sa.user_id = p_user_id AND sa.revoked_at IS NULL
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_my_staff_profile()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_sa public.staff_assignments;
  v_perms JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'is_staff', false);
  END IF;

  v_sa := public.staff_active_assignment(v_user);
  IF v_sa.id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'is_staff', false);
  END IF;

  IF v_sa.role = 'admin' THEN
    SELECT COALESCE(jsonb_agg(key ORDER BY category, key), '[]'::jsonb)
    INTO v_perms
    FROM public.staff_permission_catalog;
  ELSE
    SELECT COALESCE(jsonb_agg(sp.permission_key ORDER BY sp.permission_key), '[]'::jsonb)
    INTO v_perms
    FROM public.staff_permissions sp
    WHERE sp.staff_assignment_id = v_sa.id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'is_staff', true,
    'role', v_sa.role::text,
    'badge', v_sa.display_badge::text,
    'assignment_id', v_sa.id,
    'permissions', v_perms
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_staff_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_staff_badge(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_has_permission(uuid, text) TO authenticated;

COMMIT;
