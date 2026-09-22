-- Inventory: client REST mutate kapat. SELECT (own) kalır — mekan stock picker.
-- Mutasyon yalnız SECURITY DEFINER RPC (postgres owner) üzerinden.

BEGIN;

-- Drop broad / mutate policies (keep SELECT).
DROP POLICY IF EXISTS "Users manage own inventory" ON public.inventory;
DROP POLICY IF EXISTS "inventory_insert_own" ON public.inventory;
DROP POLICY IF EXISTS "inventory_update_own" ON public.inventory;
DROP POLICY IF EXISTS "inventory_delete_own" ON public.inventory;
DROP POLICY IF EXISTS "Users can update own inventory" ON public.inventory;

-- Ensure SELECT-own remains (mekan + any direct reads).
DROP POLICY IF EXISTS "Users can view own inventory" ON public.inventory;
DROP POLICY IF EXISTS "inventory_select_own" ON public.inventory;
CREATE POLICY "inventory_select_own" ON public.inventory
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Table privileges: no client INSERT/UPDATE/DELETE/TRUNCATE.
REVOKE ALL ON TABLE public.inventory FROM PUBLIC;
REVOKE ALL ON TABLE public.inventory FROM anon;
REVOKE ALL ON TABLE public.inventory FROM authenticated;

GRANT SELECT ON TABLE public.inventory TO authenticated;
GRANT ALL ON TABLE public.inventory TO service_role;
GRANT ALL ON TABLE public.inventory TO postgres;

COMMIT;
