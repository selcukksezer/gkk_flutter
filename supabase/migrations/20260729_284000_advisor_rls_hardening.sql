-- Supabase Advisor: rls_disabled_in_public (19 CRITICAL)
-- Pattern matches 20260613_100000_security_rls_hardening.sql:
--   • Reference catalogs → RLS + read policy
--   • Internal / legacy / QA → RLS only (no client policies; RPC/service_role OK)

BEGIN;

-- ── Legacy game.* mirror tables (app uses public.*; block direct PostgREST) ──
ALTER TABLE game.battle_pass_progress   ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.dungeon_runs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.dungeons               ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.enhancement_history    ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.items                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.purchases              ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.quests                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.season_leaderboards    ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.seasons                ENABLE ROW LEVEL SECURITY;
ALTER TABLE game.sessions               ENABLE ROW LEVEL SECURITY;

-- ── Public reference catalogs (read-only client access OK) ──
ALTER TABLE public.gem_iap_packages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gem_iap_packages_read ON public.gem_iap_packages;
CREATE POLICY gem_iap_packages_read ON public.gem_iap_packages
  FOR SELECT TO anon, authenticated
  USING (COALESCE(is_active, true));

ALTER TABLE public.codex_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS codex_catalog_read ON public.codex_catalog;
CREATE POLICY codex_catalog_read ON public.codex_catalog
  FOR SELECT TO authenticated
  USING (true);

ALTER TABLE public.reputation_shop_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS reputation_shop_catalog_read ON public.reputation_shop_catalog;
CREATE POLICY reputation_shop_catalog_read ON public.reputation_shop_catalog
  FOR SELECT TO authenticated
  USING (COALESCE(is_active, true));

-- ── Internal / staff / QA — RLS on, no policies ──
ALTER TABLE public.night_market_schedule          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_permission_catalog       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_vault_territory_loot_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._gkk_migration_backups         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qa_horse_race_smoke_runs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qa_comprehensive_smoke_runs    ENABLE ROW LEVEL SECURITY;

COMMIT;
