-- ══════════════════════════════════════════════════════════════════════════════
-- Migration: 20261029_030000_harden_rls_policies_and_missing_tables.sql
-- Description: Enables Row Level Security (RLS) on all previously unconfigured
--              operational tables (including public.users), establishes strict
--              auth.uid() ownership policies to prevent IDOR vulnerabilities,
--              and creates indexes for unindexed foreign keys to prevent table
--              locks and slow sequential scans.
-- ══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Enable RLS on public.users and establish policies ────────────────────
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_all ON public.users;
CREATE POLICY users_select_all ON public.users
  FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = auth_id)
  WITH CHECK (auth.uid() = auth_id);

DROP POLICY IF EXISTS users_insert_own ON public.users;
CREATE POLICY users_insert_own ON public.users
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = auth_id);

-- ── 2. Enable RLS on catalog and operational tables ─────────────────────────

-- clinic_level_costs (reference catalog)
ALTER TABLE IF EXISTS public.clinic_level_costs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS clinic_level_costs_read ON public.clinic_level_costs;
CREATE POLICY clinic_level_costs_read ON public.clinic_level_costs
  FOR SELECT TO authenticated, anon
  USING (true);

-- monument_level_costs (reference catalog)
ALTER TABLE IF EXISTS public.monument_level_costs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS monument_level_costs_read ON public.monument_level_costs;
CREATE POLICY monument_level_costs_read ON public.monument_level_costs
  FOR SELECT TO authenticated, anon
  USING (true);

-- crafting_recipes (reference catalog)
ALTER TABLE IF EXISTS public.crafting_recipes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS crafting_recipes_read ON public.crafting_recipes;
CREATE POLICY crafting_recipes_read ON public.crafting_recipes
  FOR SELECT TO authenticated, anon
  USING (true);

-- crafted_items_log (user operational log)
ALTER TABLE IF EXISTS public.crafted_items_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS crafted_items_log_own ON public.crafted_items_log;
CREATE POLICY crafted_items_log_own ON public.crafted_items_log
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- guild_season_score_events (guild operational log)
ALTER TABLE IF EXISTS public.guild_season_score_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS guild_season_score_events_read ON public.guild_season_score_events;
CREATE POLICY guild_season_score_events_read ON public.guild_season_score_events
  FOR SELECT TO authenticated
  USING (true);

-- ── 3. High-Traffic Foreign Key Indexes (Eliminate Table Locks) ──────────────

CREATE INDEX IF NOT EXISTS idx_dungeon_runs_dungeon_id ON public.dungeon_runs(dungeon_id);
CREATE INDEX IF NOT EXISTS idx_player_dungeon_stats_dungeon_id ON public.player_dungeon_stats(dungeon_id);
CREATE INDEX IF NOT EXISTS idx_enhancement_history_item_id ON public.enhancement_history(item_id);
CREATE INDEX IF NOT EXISTS idx_mekans_owner_id ON public.mekans(owner_id);
CREATE INDEX IF NOT EXISTS idx_mekan_stock_mekan_id ON public.mekan_stock(mekan_id);
CREATE INDEX IF NOT EXISTS idx_mekan_stock_item_id ON public.mekan_stock(item_id);
CREATE INDEX IF NOT EXISTS idx_mekan_sales_mekan_id ON public.mekan_sales(mekan_id);
CREATE INDEX IF NOT EXISTS idx_mekan_sales_buyer_id ON public.mekan_sales(buyer_id);
CREATE INDEX IF NOT EXISTS idx_mekan_pvp_matches_mekan_id ON public.mekan_pvp_matches(mekan_id);
CREATE INDEX IF NOT EXISTS idx_mekan_pvp_matches_attacker_id ON public.mekan_pvp_matches(attacker_id);
CREATE INDEX IF NOT EXISTS idx_mekan_pvp_matches_defender_id ON public.mekan_pvp_matches(defender_id);
CREATE INDEX IF NOT EXISTS idx_mekan_pvp_matches_winner_id ON public.mekan_pvp_matches(winner_id);
CREATE INDEX IF NOT EXISTS idx_pvp_matches_mekan_id ON public.pvp_matches(mekan_id);
CREATE INDEX IF NOT EXISTS idx_pvp_matches_attacker_id ON public.pvp_matches(attacker_id);
CREATE INDEX IF NOT EXISTS idx_pvp_matches_defender_id ON public.pvp_matches(defender_id);
CREATE INDEX IF NOT EXISTS idx_pvp_daily_attacks_attacker_id ON public.pvp_daily_attacks(attacker_id);
CREATE INDEX IF NOT EXISTS idx_guild_blueprints_guild_id ON public.guild_blueprints(guild_id);
CREATE INDEX IF NOT EXISTS idx_guild_contributions_guild_id ON public.guild_contributions(guild_id);
CREATE INDEX IF NOT EXISTS idx_guild_contributions_user_id ON public.guild_contributions(user_id);
CREATE INDEX IF NOT EXISTS idx_guild_facilities_guild_id ON public.guild_facilities(guild_id);
CREATE INDEX IF NOT EXISTS idx_guild_vault_transactions_guild_id ON public.guild_vault_transactions(guild_id);
CREATE INDEX IF NOT EXISTS idx_trade_sessions_initiator_id ON public.trade_sessions(initiator_id);
CREATE INDEX IF NOT EXISTS idx_trade_sessions_partner_id ON public.trade_sessions(partner_id);
CREATE INDEX IF NOT EXISTS idx_trade_items_session_id ON public.trade_items(session_id);
CREATE INDEX IF NOT EXISTS idx_craft_queue_user_id ON public.craft_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_bank_items_user_id ON public.bank_items(user_id);
CREATE INDEX IF NOT EXISTS idx_bank_transactions_user_id ON public.bank_transactions(user_id);

COMMIT;
