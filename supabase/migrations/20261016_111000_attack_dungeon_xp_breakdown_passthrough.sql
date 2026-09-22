-- battle UI path: attack_dungeon_rl_inner rebuilds JSON — pass xp_breakdown through.

DO $$
DECLARE
  v_def TEXT;
  v_old TEXT := $old$'xp_earned', COALESCE((v_result->>'xp_earned')::INTEGER, 0),$old$;
  v_new TEXT := $new$'xp_earned', COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'xp_breakdown', COALESCE(v_result->'xp_breakdown', '{}'::JSONB),$new$;
BEGIN
  SELECT pg_get_functiondef('public.attack_dungeon_rl_inner(text)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'attack_dungeon_rl_inner(text) not found';
  END IF;

  IF position('''xp_breakdown''' in v_def) > 0 OR position('xp_breakdown' in v_def) > 0 THEN
    RAISE NOTICE 'attack_dungeon_rl_inner already has xp_breakdown — skip';
    RETURN;
  END IF;

  IF position(v_old in v_def) = 0 THEN
    RAISE EXCEPTION 'attack_dungeon_rl_inner xp_earned marker not found';
  END IF;

  v_def := replace(v_def, v_old, v_new);
  EXECUTE v_def;
END;
$$;
