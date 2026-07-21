-- PLAN_06: Gems = premium sinks (loot, VIP, hospital, bank). Not micro-gold purchase.
-- Upgrade costs are 100K–1B+; 600 gold/gem exchange was meaningless.

BEGIN;

CREATE OR REPLACE FUNCTION public.exchange_gems_for_gold(p_gems INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'error', 'disabled',
    'message', 'Elmas ile altın satın alma kaldırıldı. Altın zindan, tesis, pazar ve satıştan kazanılır; elmas premium (kasa, VIP, hastane, banka) içindir.'
  );
END;
$$;

COMMIT;
