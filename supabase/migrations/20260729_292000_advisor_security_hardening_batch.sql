-- Supabase Advisor hardening batch:
--   • security_definer_view (2 ERROR) → security_invoker views
--   • anon/authenticated SD function exposure → revoke + least-privilege grants
--   • function_search_path_mutable (64 WARN) → SET search_path
--   • rls_enabled_no_policy (31 INFO) → explicit deny policies for internal tables

BEGIN;

-- ── 1) SECURITY DEFINER views → SECURITY INVOKER ───────────────────────────

ALTER VIEW public.active_production_queue SET (security_invoker = true);
ALTER VIEW public.player_prison_status SET (security_invoker = true);

-- ── 2) SECURITY DEFINER function execute privileges ─────────────────────────
-- Pattern: revoke PUBLIC/anon everywhere; internal (_/trg/cron/trigger) also from authenticated;
-- re-grant authenticated only on client-facing RPCs; tiny anon allowlist for pre-login reads.

DO $$
DECLARE
  r RECORD;
  v_args TEXT;
BEGIN
  FOR r IN
    SELECT
      p.oid,
      p.proname,
      pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND p.prosecdef
  LOOP
    v_args := r.args;
    EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC', r.proname, v_args);
    EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM anon', r.proname, v_args);

    IF r.proname LIKE '\_%'
       OR r.proname LIKE 'trg\_%' ESCAPE '\'
       OR r.proname LIKE 'cron\_%' ESCAPE '\'
       OR r.proname IN (
         'handle_new_user',
         'handle_xp_level_progression',
         'get_live_ticker_feed_core',
         'mekan_pvp_bet_rl_inner'
       )
    THEN
      EXECUTE format(
        'REVOKE ALL ON FUNCTION public.%I(%s) FROM authenticated',
        r.proname,
        v_args
      );
    ELSE
      EXECUTE format(
        'GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated',
        r.proname,
        v_args
      );
    END IF;
  END LOOP;
END $$;

-- Pre-login read-only RPC allowlist (registration / legal gate / public catalogs)
GRANT EXECUTE ON FUNCTION public.get_character_classes() TO anon;
GRANT EXECUTE ON FUNCTION public.get_dungeons() TO anon;
GRANT EXECUTE ON FUNCTION public.get_current_election() TO anon;
GRANT EXECUTE ON FUNCTION public.get_kingdom_market_blessing_status() TO anon;
GRANT EXECUTE ON FUNCTION public.get_craft_recipes(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.get_battle_pass_season_rewards(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_active_legal_documents(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_gem_iap_packages() TO anon;

-- ── 3) Mutable search_path on SECURITY DEFINER / trigger functions ───────────

DO $$
DECLARE
  r RECORD;
  v_path TEXT;
BEGIN
  FOR r IN
    SELECT
      n.nspname,
      p.proname,
      pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'game')
      AND p.prokind = 'f'
      AND (
        p.proconfig IS NULL
        OR NOT EXISTS (
          SELECT 1
          FROM unnest(p.proconfig) cfg
          WHERE cfg LIKE 'search_path=%'
        )
      )
  LOOP
    v_path := CASE
      WHEN r.nspname = 'game' THEN 'game, public, pg_temp'
      ELSE 'public, pg_temp'
    END;

    EXECUTE format(
      'ALTER FUNCTION %I.%I(%s) SET search_path = %L',
      r.nspname,
      r.proname,
      r.args,
      v_path
    );
  END LOOP;
END $$;

-- ── 4) RLS enabled, no policy → explicit deny for direct PostgREST access ────

DO $$
DECLARE
  r RECORD;
  v_policy TEXT;
BEGIN
  FOR r IN
    SELECT n.nspname AS schemaname, c.relname AS tablename
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r'
      AND c.relrowsecurity
      AND n.nspname IN ('public', 'game')
      AND NOT EXISTS (
        SELECT 1
        FROM pg_policies pol
        WHERE pol.schemaname = n.nspname
          AND pol.tablename = c.relname
      )
  LOOP
    v_policy := 'rls_deny_direct_' || replace(r.tablename, '-', '_');

    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', v_policy, r.schemaname, r.tablename);
    EXECUTE format(
      'CREATE POLICY %I ON %I.%I FOR ALL TO anon, authenticated USING (false) WITH CHECK (false)',
      v_policy,
      r.schemaname,
      r.tablename
    );
  END LOOP;
END $$;

COMMIT;
