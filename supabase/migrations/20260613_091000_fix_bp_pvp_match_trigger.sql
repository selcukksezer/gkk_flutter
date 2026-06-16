BEGIN;

CREATE OR REPLACE FUNCTION public.trg_bp_pvp_match_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_loser_id uuid;
BEGIN
  IF NEW.winner_id IS NOT NULL THEN
    v_loser_id := CASE
      WHEN NEW.winner_id = NEW.attacker_id THEN NEW.defender_id
      ELSE NEW.attacker_id
    END;
    PERFORM public.bp_trigger_pvp_match(NEW.winner_id, true);
    PERFORM public.bp_trigger_pvp_match(v_loser_id, false);
  END IF;
  RETURN NEW;
END;
$$;

COMMIT;
