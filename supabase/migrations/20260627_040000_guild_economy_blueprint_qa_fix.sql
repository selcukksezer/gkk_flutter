-- Align boss blueprint drops with PLAN_10 gates (L80 phoenix … L100 eternal)
-- Backfill empty monument pools for guilds with seeded levels

CREATE OR REPLACE FUNCTION public.grant_monument_boss_blueprint(p_guild_id UUID, p_zone INT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_chance NUMERIC;
  v_bp_type TEXT;
  v_roll NUMERIC;
BEGIN
  IF p_guild_id IS NULL OR COALESCE(p_zone, 0) < 5 THEN
    RETURN;
  END IF;

  v_chance := 0.005 + (p_zone - 5) * 0.015;
  IF random() > v_chance THEN
    RETURN;
  END IF;

  IF p_zone = 5 THEN
    v_bp_type := 'phoenix';
  ELSIF p_zone = 6 THEN
    v_bp_type := 'leviathan';
  ELSE
    v_roll := random();
    IF v_roll < 0.40 THEN
      v_bp_type := 'titan';
    ELSIF v_roll < 0.70 THEN
      v_bp_type := 'world_eater';
    ELSE
      v_bp_type := 'eternal';
    END IF;
  END IF;

  INSERT INTO public.guild_blueprints (guild_id, blueprint_type, fragments, fragments_required)
  VALUES (p_guild_id, v_bp_type, 1, 100)
  ON CONFLICT (guild_id, blueprint_type)
  DO UPDATE SET fragments = public.guild_blueprints.fragments + 1;
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.grant_monument_boss_blueprint(UUID, INT) TO authenticated;

DO $do$
DECLARE
  v_def TEXT;
  v_marker TEXT := E'    IF COALESCE(v_player.character_class, '''') = ''warrior'' AND v_dungeon.is_boss THEN\n      v_gold := floor(v_gold * 1.15);\n    END IF;';
  v_patch TEXT := E'    IF COALESCE(v_player.character_class, '''') = ''warrior'' AND v_dungeon.is_boss THEN\n      v_gold := floor(v_gold * 1.15);\n    END IF;\n\n    IF v_dungeon.is_boss AND COALESCE(v_dungeon.zone, 1) >= 5 AND v_player.guild_id IS NOT NULL THEN\n      PERFORM public.grant_monument_boss_blueprint(v_player.guild_id, COALESCE(v_dungeon.zone, 1));\n    END IF;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'enter_dungeon'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NOT NULL AND v_def NOT LIKE '%grant_monument_boss_blueprint%' THEN
    IF position(v_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_marker, v_patch);
    ELSE
      v_def := replace(
        v_def,
        E'    IF COALESCE(v_player.character_class, '''') = ''warrior'' AND v_dungeon.is_boss THEN\n      v_gold := floor(v_gold * 1.15);\n    END IF;\n\n    v_rec_level :=',
        E'    IF COALESCE(v_player.character_class, '''') = ''warrior'' AND v_dungeon.is_boss THEN\n      v_gold := floor(v_gold * 1.15);\n    END IF;\n\n    IF v_dungeon.is_boss AND COALESCE(v_dungeon.zone, 1) >= 5 AND v_player.guild_id IS NOT NULL THEN\n      PERFORM public.grant_monument_boss_blueprint(v_player.guild_id, COALESCE(v_dungeon.zone, 1));\n    END IF;\n\n    v_rec_level :='
      );
    END IF;
    EXECUTE v_def;
  END IF;
END $do$;

-- QA / seeded guilds: fill monument pool to 150% of next-level cost (size-adjusted)
UPDATE public.guilds g
SET
  monument_structural = sub.structural,
  monument_mystical = sub.mystical,
  monument_critical = sub.critical,
  monument_gold_pool = sub.gold
FROM (
  SELECT
    g2.id,
    CEIL(c.structural * public.guild_size_multiplier(mc.cnt) * 1.5)::bigint AS structural,
    CEIL(c.mystical * public.guild_size_multiplier(mc.cnt) * 1.5)::bigint AS mystical,
    CEIL(c.critical * public.guild_size_multiplier(mc.cnt) * 1.5)::bigint AS critical,
    CEIL(c.gold * public.guild_size_multiplier(mc.cnt) * 1.5)::bigint AS gold
  FROM public.guilds g2
  JOIN public.monument_level_costs c ON c.level = g2.monument_level + 1
  JOIN LATERAL (
    SELECT COUNT(*)::int AS cnt FROM public.users u WHERE u.guild_id = g2.id
  ) mc ON true
  WHERE g2.monument_level > 0
    AND g2.monument_level < 100
    AND g2.monument_structural = 0
    AND g2.monument_mystical = 0
    AND g2.monument_critical = 0
    AND g2.monument_gold_pool = 0
) sub
WHERE g.id = sub.id;
