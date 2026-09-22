-- Patch: Clash hook on territory attack + rank_score bump.

BEGIN;

CREATE OR REPLACE FUNCTION public.attack_guild_war_territory(p_territory_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_player_id UUID := auth.uid();
  v_guild_id UUID;
  v_leader UUID;
  v_guild RECORD;
  v_territory RECORD;
  v_attack_power INTEGER;
  v_support_sum INTEGER := 0;
  v_effective_defense INTEGER;
  v_garrison_def INTEGER;
  v_success BOOLEAN;
  v_points_gained INTEGER;
  v_active_season_id UUID;
  v_rep_gain INTEGER := 0;
  v_combat JSONB;
  v_cost INTEGER;
  v_defender_name TEXT;
  v_health INTEGER;
  v_max_health INTEGER;
  v_damage INTEGER;
  v_health_after INTEGER;
  v_plan RECORD;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_combat := public.assert_player_combat_ready(v_player_id, false);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat::json;
  END IF;

  v_combat := public.assert_player_pvp_health(v_player_id);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat::json;
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_player_id;
  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT leader_id INTO v_leader FROM public.guilds WHERE id = v_guild_id;
  IF v_leader IS DISTINCT FROM v_player_id THEN
    RETURN json_build_object('success', false, 'error', 'Sadece lonca başkanı bölgeye saldırabilir.');
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  IF v_territory.owner_guild_id IS NOT NULL
     AND v_territory.updated_at > now() - interval '2 hours' THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Yeni fetih koruması aktif (2 saat).',
      'grace_until', v_territory.updated_at + interval '2 hours'
    );
  END IF;

  v_cost := COALESCE(
    v_territory.attack_gold_cost,
    GREATEST(1000, (COALESCE(v_territory.trade_income, 0) * 1.5)::INTEGER)
  );

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_guild_id FOR UPDATE;
  IF COALESCE(v_guild.vault_gold, 0) < v_cost THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Lonca kasasında saldırı için yeterli altın yok (' || v_cost || 'g).'
    );
  END IF;

  SELECT COALESCE(g.name, g.tag, 'Sahipsiz') INTO v_defender_name
  FROM public.guilds g WHERE g.id = v_territory.owner_guild_id;

  IF v_territory.owner_guild_id IS NOT NULL THEN
    v_garrison_def := public._guild_war_recompute_defense(p_territory_id);
  ELSE
    v_garrison_def := 0;
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;

  SELECT COALESCE(power, 0) INTO v_attack_power FROM public.users WHERE auth_id = v_player_id;

  SELECT * INTO v_plan
  FROM public.guild_war_attack_plan
  WHERE attacker_guild_id = v_guild_id
    AND territory_id = p_territory_id
    AND status = 'open'
    AND closes_at >= now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    SELECT COALESCE(SUM(power_snapshot), 0)::INTEGER INTO v_support_sum
    FROM public.guild_war_attack_support
    WHERE plan_id = v_plan.id AND user_id <> v_player_id;
    v_attack_power := v_attack_power + v_support_sum;
  END IF;

  v_effective_defense := public.guild_war_territory_effective_defense(
    COALESCE(v_garrison_def, v_territory.defense_power),
    v_territory.gem_defense_boost
  );

  v_success := (random() * GREATEST(v_attack_power, 1)) > (random() * GREATEST(v_effective_defense, 1));
  v_points_gained := CASE WHEN v_success THEN 80 ELSE 8 END;
  v_rep_gain := CASE WHEN v_success THEN 20 ELSE 5 END;

  UPDATE public.guilds SET vault_gold = vault_gold - v_cost WHERE id = v_guild_id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild_id, v_player_id, 'attack_spend',
    jsonb_build_object(
      'territory_id', p_territory_id,
      'gold', v_cost,
      'success', v_success,
      'defender', v_defender_name,
      'attack_power', v_attack_power,
      'support_sum', v_support_sum
    )
  );

  IF v_plan.id IS NOT NULL THEN
    UPDATE public.guild_war_attack_plan SET status = 'launched' WHERE id = v_plan.id;
  END IF;

  SELECT id INTO v_active_season_id
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_active_season_id IS NOT NULL THEN
    INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses, rank_score)
    VALUES (
      v_active_season_id, v_guild_id, v_points_gained,
      CASE WHEN v_success THEN 1 ELSE 0 END,
      CASE WHEN v_success THEN 0 ELSE 1 END,
      v_points_gained
    )
    ON CONFLICT (season_id, guild_id) DO UPDATE SET
      points = guild_war_rankings.points + v_points_gained,
      wins = guild_war_rankings.wins + (CASE WHEN v_success THEN 1 ELSE 0 END),
      losses = guild_war_rankings.losses + (CASE WHEN v_success THEN 0 ELSE 1 END),
      rank_score = guild_war_rankings.points + v_points_gained
                 + FLOOR(guild_war_rankings.prestige * 0.25)::INTEGER,
      updated_at = now();
  END IF;

  IF v_success THEN
    PERFORM public._accrue_guild_vault(v_territory.owner_guild_id);
    PERFORM public._guild_war_clear_garrison(p_territory_id);
    UPDATE public.guild_war_territories
    SET owner_guild_id = v_guild_id,
        gem_defense_boost = 0,
        defense_power = 0,
        updated_at = now()
    WHERE id = p_territory_id;
  END IF;

  BEGIN
    PERFORM public._clash_hook_war(
      v_guild_id, v_success, v_player_id, v_territory.owner_guild_id
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  SELECT COALESCE(health, max_health, 100), GREATEST(COALESCE(max_health, 100), 1)
  INTO v_health, v_max_health
  FROM public.users WHERE auth_id = v_player_id;

  v_damage := CASE
    WHEN v_success THEN FLOOR(v_max_health * (0.05 + random() * 0.05))::INTEGER
    ELSE FLOOR(v_max_health * (0.12 + random() * 0.08))::INTEGER
  END;
  v_health_after := GREATEST(public.player_health_floor(v_max_health), v_health - v_damage);

  UPDATE public.users
  SET reputation = COALESCE(reputation, 0) + v_rep_gain,
      health = v_health_after,
      health_last_updated = now(),
      updated_at = now()
  WHERE auth_id = v_player_id;

  PERFORM public._log_reputation_activity(
    v_player_id, 'earn', 'guild_war', v_rep_gain, 'global', NULL,
    jsonb_build_object(
      'territory_id', p_territory_id,
      'attack_success', v_success,
      'points_gained', v_points_gained,
      'gold_spent', v_cost
    )
  );

  INSERT INTO public.guild_war_attack_logs (
    territory_id, attacker_guild_id, defender_guild_id,
    attack_power, defense_power, success, points_gained, gold_spent
  ) VALUES (
    p_territory_id, v_guild_id, v_territory.owner_guild_id,
    v_attack_power, v_effective_defense, v_success, v_points_gained, v_cost
  );

  RETURN json_build_object(
    'success', v_success,
    'message', CASE WHEN v_success THEN 'Bölge ele geçirildi!' ELSE 'Saldırı başarısız!' END,
    'attack_power', v_attack_power,
    'defense_power', v_effective_defense,
    'points_gained', v_points_gained,
    'rep_gained', v_rep_gain,
    'gold_spent', v_cost,
    'defender_guild_name', v_defender_name,
    'health_lost', v_health - v_health_after,
    'health_after', v_health_after,
    'max_health', v_max_health,
    'support_sum', v_support_sum
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.attack_guild_war_territory(uuid) TO authenticated;

COMMIT;
