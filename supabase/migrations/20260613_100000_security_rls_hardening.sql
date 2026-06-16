-- ============================================================
-- Migration: Security RLS Hardening
-- ============================================================
-- QA audit bulgusu: public şemada 12 tabloda RLS kapalıydı.
-- Bu migration RLS'i açar ve uygun erişim policy'leri ekler.
-- Yazma işlemleri SECURITY DEFINER RPC'ler ile yapıldığından
-- (RLS bypass), bu policy'ler oyun yazma akışını bozmaz; sadece
-- doğrudan client okuma/yazmasını kısıtlar.
-- ============================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 1) character_classes — referans veri, herkese okuma
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.character_classes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "character_classes_read" ON public.character_classes;
CREATE POLICY "character_classes_read" ON public.character_classes
  FOR SELECT TO anon, authenticated USING (true);

-- ─────────────────────────────────────────────────────────────
-- 2) pvp_battles — sadece kendi savaşları okunabilir
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.pvp_battles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pvp_battles_own_read" ON public.pvp_battles;
CREATE POLICY "pvp_battles_own_read" ON public.pvp_battles
  FOR SELECT TO authenticated
  USING (auth.uid() = attacker_id OR auth.uid() = defender_id);

-- ─────────────────────────────────────────────────────────────
-- 3) hospital_records — sadece kendi kayıtları
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.hospital_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "hospital_records_own_read" ON public.hospital_records;
CREATE POLICY "hospital_records_own_read" ON public.hospital_records
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- 4) guild_activities — sadece kendi loncasının aktiviteleri
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.guild_activities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "guild_activities_member_read" ON public.guild_activities;
CREATE POLICY "guild_activities_member_read" ON public.guild_activities
  FOR SELECT TO authenticated
  USING (
    guild_id IN (
      SELECT u.guild_id FROM public.users u WHERE u.auth_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 5) guild_wars — savaş panosu, giriş yapmışlara okuma
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.guild_wars ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "guild_wars_read" ON public.guild_wars;
CREATE POLICY "guild_wars_read" ON public.guild_wars
  FOR SELECT TO authenticated USING (true);

-- ─────────────────────────────────────────────────────────────
-- 6) QA altyapı tabloları — RLS aç, policy YOK
--    (yalnızca service_role / SECURITY DEFINER erişir, client kilitli)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.qa_backup_registry      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qa_backup_table_stats   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qa_bot_profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qa_sim_checkpoints      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qa_sim_daily_events     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qa_sim_exploit_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qa_sim_exploit_findings ENABLE ROW LEVEL SECURITY;

COMMIT;
