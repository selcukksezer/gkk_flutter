-- Fix: enter_dungeon hospital luck mitigation had no cap.
-- Comment/intent since 20260503: max -30% (luck * 0.003).
-- Client already clamps; server did not → high luck (e.g. 45k) →
-- v_hospital_chance negative → random() never triggers hospital on defeat.
-- Align server with client calculateHospitalRiskPct.

DO $$
DECLARE
  v_def text;
  v_old text :=
    'v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);';
  v_new text :=
    'v_hospital_chance := v_hospital_chance * (1 - LEAST(0.30, COALESCE(v_player.luck, 0) * 0.003));';
  v_count int;
BEGIN
  SELECT pg_get_functiondef('public.enter_dungeon(uuid, text)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon(uuid, text) not found';
  END IF;

  IF position(v_new in v_def) > 0
     AND position(v_old in v_def) = 0 THEN
    RAISE NOTICE 'enter_dungeon hospital luck already capped — skip';
    RETURN;
  END IF;

  v_count := (
    length(v_def) - length(replace(v_def, v_old, ''))
  ) / length(v_old);

  IF v_count < 2 THEN
    RAISE EXCEPTION
      'enter_dungeon expected 2 uncapped hospital luck lines, found % — abort',
      v_count;
  END IF;

  v_def := replace(v_def, v_old, v_new);
  EXECUTE v_def;

  RAISE NOTICE 'enter_dungeon hospital luck cap applied (% sites)', v_count;
END $$;
