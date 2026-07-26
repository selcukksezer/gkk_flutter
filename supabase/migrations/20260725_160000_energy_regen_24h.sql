-- Passive energy regen: empty → max over 24 hours (linear).
-- Example max=100 → ~1 energy / 14.4 dk (~4.17 / saat).

CREATE OR REPLACE FUNCTION public.apply_energy_regen(p_user_id uuid DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_energy INT;
  v_max INT;
  v_last TIMESTAMPTZ;
  v_elapsed NUMERIC;
  v_gained INT;
  v_new INT;
  v_actual INT;
  v_seconds_per_point NUMERIC;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  -- Caller must be the player (or internal via same uid).
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  SELECT
    COALESCE(u.energy, 0),
    GREATEST(COALESCE(u.max_energy, 100), 1),
    COALESCE(u.energy_last_updated, now())
  INTO v_energy, v_max, v_last
  FROM public.users u
  WHERE u.auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profil bulunamadı.');
  END IF;

  IF v_energy >= v_max THEN
    UPDATE public.users
    SET energy_last_updated = now()
    WHERE auth_id = p_user_id
      AND (energy_last_updated IS NULL OR energy_last_updated < now() - interval '30 seconds');
    RETURN jsonb_build_object(
      'success', true,
      'energy', v_energy,
      'max_energy', v_max,
      'gained', 0
    );
  END IF;

  v_elapsed := EXTRACT(EPOCH FROM (now() - v_last));
  IF v_elapsed IS NULL OR v_elapsed < 0 THEN
    v_elapsed := 0;
  END IF;

  -- Full pool in exactly 24h.
  v_gained := FLOOR(v_elapsed * v_max / 86400.0)::INT;
  IF v_gained <= 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'energy', v_energy,
      'max_energy', v_max,
      'gained', 0
    );
  END IF;

  v_new := LEAST(v_max, v_energy + v_gained);
  v_actual := v_new - v_energy;
  v_seconds_per_point := 86400.0 / v_max;

  UPDATE public.users
  SET
    energy = v_new,
    energy_last_updated = CASE
      WHEN v_new >= v_max THEN now()
      ELSE v_last + make_interval(secs => (v_actual * v_seconds_per_point))
    END,
    updated_at = now()
  WHERE auth_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'energy', v_new,
    'max_energy', v_max,
    'gained', v_actual
  );
END;
$$;

-- Heartbeat / presence already polls — apply regen there too.
CREATE OR REPLACE FUNCTION public.set_online_status(
  p_is_online boolean,
  p_mekan_id uuid DEFAULT NULL::uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    PERFORM public.apply_energy_regen(auth.uid());
  END IF;

  UPDATE public.users
  SET
    comeback_resume_from = CASE
      WHEN p_is_online
        AND comeback_resume_from IS NULL
        AND last_active_at IS NOT NULL
        AND last_active_at < now() - interval '5 minutes'
      THEN last_active_at
      WHEN NOT p_is_online THEN comeback_resume_from
      ELSE comeback_resume_from
    END,
    is_online = p_is_online,
    last_active_at = now(),
    current_mekan_id = CASE WHEN p_is_online THEN p_mekan_id ELSE NULL END
  WHERE auth_id = auth.uid();
END;
$$;

-- Start regen clocks from now so stale energy_last_updated does not instant-fill.
UPDATE public.users
SET energy_last_updated = now()
WHERE energy_last_updated IS NULL
   OR energy_last_updated < now() - interval '10 minutes';

GRANT EXECUTE ON FUNCTION public.apply_energy_regen(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_online_status(boolean, uuid) TO authenticated;

-- enter_dungeon: regen before energy spend check
DO $patch_dungeon$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef('public.enter_dungeon(uuid, text)'::regprocedure) INTO v_def;
  IF v_def IS NULL OR position('apply_energy_regen' IN v_def) > 0 THEN
    RETURN;
  END IF;
  IF position('IF p_player_id != auth.uid() THEN' IN v_def) = 0 THEN
    RAISE NOTICE 'enter_dungeon auth guard not found — skip';
    RETURN;
  END IF;
  v_def := replace(
    v_def,
    $a$IF p_player_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;$a$,
    $b$IF p_player_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  PERFORM public.apply_energy_regen(p_player_id);$b$
  );
  EXECUTE v_def;
END;
$patch_dungeon$;
