CREATE OR REPLACE FUNCTION public.dungeon_siege_in_prime_window()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_now time;
  v_window jsonb;
  v_start time;
  v_end time;
BEGIN
  v_cfg := public.dungeon_siege_get_config();
  v_now := (now() AT TIME ZONE COALESCE(v_cfg.timezone, 'Europe/Istanbul'))::time;

  FOR v_window IN
    SELECT value FROM jsonb_array_elements(COALESCE(v_cfg.prime_windows, '[]'::jsonb))
  LOOP
    BEGIN
      v_start := (v_window->>'start')::time;
      v_end := (v_window->>'end')::time;
    EXCEPTION WHEN OTHERS THEN
      CONTINUE;
    END;

    IF v_end = v_start THEN
      CONTINUE;
    ELSIF v_end > v_start THEN
      IF v_now >= v_start AND v_now < v_end THEN
        RETURN true;
      END IF;
    ELSE
      -- midnight wrap (e.g. 22:00 -> 00:00)
      IF v_now >= v_start OR v_now < v_end THEN
        RETURN true;
      END IF;
    END IF;
  END LOOP;

  RETURN false;
END;
$$;
