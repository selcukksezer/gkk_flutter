-- Fix guild war territory RPCs: dungeons PK is id, not dungeon_id.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_dungeon_by_id(p_dungeon_id text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row jsonb;
BEGIN
  IF p_dungeon_id IS NULL OR btrim(p_dungeon_id) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zindan id gerekli.');
  END IF;

  SELECT to_jsonb(d.*) INTO v_row
  FROM public.dungeons d
  WHERE d.id = p_dungeon_id
  LIMIT 1;

  IF v_row IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zindan bulunamadı.');
  END IF;

  RETURN jsonb_build_object('success', true, 'dungeon', v_row);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_guild_war_territories()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result json;
BEGIN
  PERFORM public.guild_war_reset_gem_defense_outside_prime();

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      t.id,
      t.name,
      t.owner_guild_id,
      COALESCE(g.name, 'Sahipsiz') AS "owner_guild",
      t.defense_power,
      t.gem_defense_boost,
      public.guild_war_territory_effective_defense(t.defense_power, t.gem_defense_boost) AS effective_defense_power,
      t.base_defense_power,
      t.defense_line_level,
      t.reward,
      COALESCE(t.trade_income, 0) AS trade_income,
      t.zone_number,
      COALESCE(t.attack_gold_cost, GREATEST(1000, (COALESCE(t.trade_income, 0) * 0.55)::INTEGER)) AS attack_gold_cost,
      COALESCE(t.min_defense_gems, 5) AS min_defense_gems,
      public.guild_war_siege_dungeon_id(t.zone_number) AS siege_dungeon_id,
      (
        SELECT COALESCE(d.name_tr, d.name)
        FROM public.dungeons d
        WHERE d.id = public.guild_war_siege_dungeon_id(t.zone_number)
        LIMIT 1
      ) AS siege_dungeon_name,
      EXISTS (
        SELECT 1 FROM public.dungeon_siege_sessions s
        WHERE s.zone_number = t.zone_number AND s.is_active = true AND s.ends_at > now()
      ) AS has_active_siege_session
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    ORDER BY t.zone_number NULLS LAST, t.name
  ) t;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_territory_detail(p_territory_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_territory json;
  v_recent_attacks json;
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_vault JSONB;
BEGIN
  PERFORM public.guild_war_reset_gem_defense_outside_prime();

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NOT NULL THEN
    PERFORM public._accrue_guild_vault(v_guild_id);
  END IF;

  SELECT row_to_json(t)
  INTO v_territory
  FROM (
    SELECT
      t.id,
      t.name,
      t.owner_guild_id,
      COALESCE(g.name, 'Sahipsiz') AS owner_guild,
      g.tag AS owner_guild_tag,
      t.defense_power,
      t.gem_defense_boost,
      public.guild_war_territory_effective_defense(t.defense_power, t.gem_defense_boost) AS effective_defense_power,
      t.base_defense_power,
      t.defense_line_level,
      t.reward,
      COALESCE(t.trade_income, 0) AS trade_income,
      COALESCE(t.attack_gold_cost, GREATEST(1000, (COALESCE(t.trade_income, 0) * 0.55)::INTEGER)) AS attack_gold_cost,
      COALESCE(t.min_defense_gems, 5) AS min_defense_gems,
      t.defense_added_at,
      t.updated_at,
      t.zone_number,
      public.guild_war_siege_dungeon_id(t.zone_number) AS siege_dungeon_id,
      (
        SELECT COALESCE(d.name_tr, d.name)
        FROM public.dungeons d
        WHERE d.id = public.guild_war_siege_dungeon_id(t.zone_number)
        LIMIT 1
      ) AS siege_dungeon_name,
      EXISTS (
        SELECT 1 FROM public.dungeon_siege_sessions s
        WHERE s.zone_number = t.zone_number AND s.is_active = true AND s.ends_at > now()
      ) AS has_active_siege_session,
      CASE WHEN v_guild_id IS NOT NULL THEN (
        SELECT json_build_object(
          'vault_gold', COALESCE(g2.vault_gold, 0),
          'vault_gold_pending', COALESCE(g2.vault_gold_pending, 0),
          'is_leader', g2.leader_id = v_user,
          'can_collect', g2.leader_id = v_user AND COALESCE(g2.vault_gold_pending, 0) > 0
        )
        FROM public.guilds g2 WHERE g2.id = v_guild_id
      ) ELSE NULL END AS vault_summary
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    WHERE t.id = p_territory_id
  ) t;

  IF v_territory IS NULL THEN
    RETURN json_build_object('error', 'Bölge bulunamadı.');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json)
  INTO v_recent_attacks
  FROM (
    SELECT
      l.id,
      l.attacker_guild_id,
      l.defender_guild_id,
      l.attack_power,
      l.defense_power,
      l.success,
      l.points_gained,
      l.gold_spent,
      l.created_at,
      ag.name AS attacker_guild_name,
      ag.tag AS attacker_guild_tag,
      dg.name AS defender_guild_name,
      dg.tag AS defender_guild_tag
    FROM public.guild_war_attack_logs l
    LEFT JOIN public.guilds ag ON ag.id = l.attacker_guild_id
    LEFT JOIN public.guilds dg ON dg.id = l.defender_guild_id
    WHERE l.territory_id = p_territory_id
    ORDER BY l.created_at DESC
    LIMIT 20
  ) a;

  RETURN json_build_object(
    'territory', v_territory,
    'recent_attacks', v_recent_attacks
  );
END;
$$;

COMMIT;
