-- ══════════════════════════════════════════════════════════════════════════════
-- Migration: 20261029_010000_harden_security_definer_search_path.sql
-- Description: Hardens all SECURITY DEFINER functions by enforcing
--              search_path = public, pg_temp to prevent privilege escalation
--              and search_path hijacking attacks (PostgreSQL CVE-style vector).
-- Idempotency: 100% idempotent via dynamic pg_proc metadata iteration and safe
--              ALTER FUNCTION statements.
-- ══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 1. Explicitly harden the primary critical high-risk functions identified in audit
DO $$
DECLARE
  v_fn record;
  v_count integer := 0;
BEGIN
  -- Dynamic scan of all public schema functions declared as SECURITY DEFINER
  -- where search_path is either unset or does not match public, pg_temp
  FOR v_fn IN (
    SELECT
      n.nspname AS schema_name,
      p.proname AS func_name,
      pg_get_function_identity_arguments(p.oid) AS identity_args
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
      AND (
        p.proconfig IS NULL
        OR NOT (
          'search_path=public, pg_temp' = ANY(p.proconfig)
          OR 'search_path=public,pg_temp' = ANY(p.proconfig)
        )
      )
  ) LOOP
    BEGIN
      EXECUTE format(
        'ALTER FUNCTION %I.%I(%s) SET search_path = public, pg_temp;',
        v_fn.schema_name,
        v_fn.func_name,
        v_fn.identity_args
      );
      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Could not alter function %.%(%): %',
        v_fn.schema_name, v_fn.func_name, v_fn.identity_args, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE 'Hardened % SECURITY DEFINER functions with search_path = public, pg_temp.', v_count;
END $$;

COMMIT;
