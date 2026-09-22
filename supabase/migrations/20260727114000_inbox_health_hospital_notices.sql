-- Inbox notices: hospital discharge (wounded) + health fully regenerated.

BEGIN;

-- ── sync_expired_hospital: notify on discharge ───────────────────────────────

CREATE OR REPLACE FUNCTION public.sync_expired_hospital(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_until TIMESTAMPTZ;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT hospital_until
  INTO v_until
  FROM public.users
  WHERE auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_until IS NOT NULL AND v_until <= now() THEN
    UPDATE public.users
    SET hospital_until = NULL,
        hospital_reason = NULL,
        updated_at = now()
    WHERE auth_id = p_user_id;

    PERFORM public.apply_hospital_wounded_state(p_user_id);

    BEGIN
      INSERT INTO public.player_inbox_notifications (user_id, kind, title, body)
      VALUES (
        p_user_id,
        'hospital_discharge',
        'Hastaneden çıktın',
        'Taburcu oldun ama hâlâ yaralısın — canın dolana kadar savaşta %15 zayıfsın.'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    RETURN true;
  END IF;

  RETURN false;
END;
$function$;

-- ── apply_health_regen: notify once when regen tops health off ───────────────

DO $patch$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('public.apply_health_regen(uuid)'::regprocedure) INTO v_def;
  IF v_def IS NULL OR position('health_full' IN v_def) > 0 THEN
    RETURN;
  END IF;

  v_def := replace(
    v_def,
    '  v_status := CASE
    WHEN v_new >= v_max THEN ''healthy''',
    '  IF v_new >= v_max AND v_health < v_max THEN
    BEGIN
      INSERT INTO public.player_inbox_notifications (user_id, kind, title, body)
      SELECT p_user_id, ''health_full'', ''Canın doldu'',
             ''Canın tamamen yenilendi — savaşa hazırsın.''
      WHERE NOT EXISTS (
        SELECT 1 FROM public.player_inbox_notifications n
        WHERE n.user_id = p_user_id
          AND n.kind = ''health_full''
          AND n.read_at IS NULL
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  v_status := CASE
    WHEN v_new >= v_max THEN ''healthy'''
  );

  IF position('health_full' IN v_def) > 0 THEN
    EXECUTE v_def;
  END IF;
END;
$patch$;

COMMIT;
