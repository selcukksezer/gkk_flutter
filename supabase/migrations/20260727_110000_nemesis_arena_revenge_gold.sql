-- Nemesis revenge gold: extend to arena (mekan_pvp_bet) + surface in duel result JSON
BEGIN;

-- ── mekan_pvp_bet: grant nemesis revenge bonus on arena win ───────────────────
DO $arena_patch$
DECLARE
  v_def TEXT;
  v_return_marker TEXT := E'  RETURN jsonb_build_object(\n    ''success'', true,';
  v_bonus_block TEXT := E'  v_nemesis_bonus := public._nemesis_revenge_gold_bonus(v_winner_id, v_loser_id, NULL);\n\n  RETURN jsonb_build_object(\n    ''success'', true,';
  v_declare_marker TEXT := '  v_match_id UUID;';
  v_declare_add TEXT := E'  v_match_id UUID;\n  v_nemesis_bonus JSONB;';
  v_fields_marker TEXT := E'''match_id'', v_match_id\n  );';
  v_fields_add TEXT := E'''match_id'', v_match_id,\n    ''nemesis_revenge_granted'', COALESCE((v_nemesis_bonus->>''granted'')::BOOLEAN, false),\n    ''nemesis_revenge_gold'', COALESCE((v_nemesis_bonus->>''gold'')::BIGINT, 0)\n  );';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'mekan_pvp_bet'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'mekan_pvp_bet not found; skipping arena nemesis gold patch';
    RETURN;
  END IF;

  IF position('v_nemesis_bonus' in v_def) = 0 THEN
    IF position(v_declare_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_declare_marker, v_declare_add);
    END IF;
    IF position(v_return_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_return_marker, v_bonus_block);
    END IF;
    IF position(v_fields_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_fields_marker, v_fields_add);
    END IF;
    EXECUTE v_def;
  END IF;
END;
$arena_patch$;

-- ── respond_pvp_invite: merge nemesis bonus into duel result ──────────────────
DO $invite_patch$
DECLARE
  v_def TEXT;
  v_perform TEXT := E'  PERFORM public._nemesis_revenge_gold_bonus(v_winner_id, v_loser_id, p_invite_id);';
  v_assign TEXT := E'  v_nemesis_bonus := public._nemesis_revenge_gold_bonus(v_winner_id, v_loser_id, p_invite_id);\n  IF COALESCE(v_nemesis_bonus->>''granted'', ''false'') = ''true'' THEN\n    v_result := v_result || jsonb_build_object(\n      ''nemesis_revenge_granted'', true,\n      ''nemesis_revenge_gold'', (v_nemesis_bonus->>''gold'')::BIGINT\n    );\n  END IF;';
  v_declare_marker TEXT := '  v_result JSONB;';
  v_declare_add TEXT := E'  v_result JSONB;\n  v_nemesis_bonus JSONB;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'respond_pvp_invite'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'respond_pvp_invite not found; skipping duel nemesis gold patch';
    RETURN;
  END IF;

  IF position('v_nemesis_bonus' in v_def) = 0 THEN
    IF position(v_declare_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_declare_marker, v_declare_add);
    END IF;
  END IF;

  IF position(v_perform in v_def) > 0 THEN
    v_def := replace(v_def, v_perform, v_assign);
    EXECUTE v_def;
  ELSIF position('v_nemesis_bonus := public._nemesis_revenge_gold_bonus' in v_def) = 0
        AND position('[GKK_NEMESIS_REVENGE_GOLD_BEGIN]' in v_def) > 0 THEN
    v_def := replace(
      v_def,
      E'  -- [GKK_NEMESIS_REVENGE_GOLD_BEGIN]\n  PERFORM public._nemesis_revenge_gold_bonus(v_winner_id, v_loser_id, p_invite_id);\n  -- [GKK_NEMESIS_REVENGE_GOLD_END]\n',
      E'  -- [GKK_NEMESIS_REVENGE_GOLD_BEGIN]\n  v_nemesis_bonus := public._nemesis_revenge_gold_bonus(v_winner_id, v_loser_id, p_invite_id);\n  IF COALESCE(v_nemesis_bonus->>''granted'', ''false'') = ''true'' THEN\n    v_result := v_result || jsonb_build_object(\n      ''nemesis_revenge_granted'', true,\n      ''nemesis_revenge_gold'', (v_nemesis_bonus->>''gold'')::BIGINT\n    );\n  END IF;\n  -- [GKK_NEMESIS_REVENGE_GOLD_END]\n'
    );
    IF position('v_nemesis_bonus JSONB' in v_def) = 0 AND position(v_declare_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_declare_marker, v_declare_add);
    END IF;
    EXECUTE v_def;
  END IF;
END;
$invite_patch$;

COMMIT;
