-- Guild war attack economy: gold cost from vault, preview RPC, gold defense boost.

BEGIN;

ALTER TABLE public.guild_war_territories
  ADD COLUMN IF NOT EXISTS attack_gold_cost INTEGER,
  ADD COLUMN IF NOT EXISTS min_defense_gems INTEGER DEFAULT 5,
  ADD COLUMN IF NOT EXISTS loot_item_id TEXT REFERENCES public.items(id),
  ADD COLUMN IF NOT EXISTS loot_item_chance NUMERIC DEFAULT 0;

UPDATE public.guild_war_territories t
SET
  attack_gold_cost = GREATEST(1000, (COALESCE(t.trade_income, 0) * 0.55)::INTEGER),
  min_defense_gems = CASE
    WHEN COALESCE(t.trade_income, 0) >= 12000 THEN 30
    WHEN COALESCE(t.trade_income, 0) >= 5000 THEN 15
    ELSE 5
  END
WHERE t.attack_gold_cost IS NULL;

ALTER TABLE public.guild_war_attack_logs
  ADD COLUMN IF NOT EXISTS gold_spent INTEGER DEFAULT 0;

CREATE OR REPLACE FUNCTION public.add_territory_defense_gold(
  p_territory_id UUID,
  p_gold BIGINT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_territory RECORD;
  v_guild RECORD;
  v_gold BIGINT := GREATEST(COALESCE(p_gold, 0), 0);
  v_defense_gain INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id IS DISTINCT FROM v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece kendi bölgenize savunma ekleyebilirsiniz.');
  END IF;

  IF v_gold < 500 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum 500 altın gerekli.');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_guild_id FOR UPDATE;
  IF COALESCE(v_guild.vault_gold, 0) < v_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca kasasında yeterli altın yok.');
  END IF;

  v_defense_gain := (v_gold / 10)::INTEGER; -- 500g = +50 def

  UPDATE public.guilds SET vault_gold = vault_gold - v_gold WHERE id = v_guild_id;
  UPDATE public.guild_war_territories
  SET defense_power = defense_power + v_defense_gain,
      defense_added_at = now(),
      updated_at = now()
  WHERE id = p_territory_id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild_id, v_user, 'defense_gold',
    jsonb_build_object('territory_id', p_territory_id, 'gold', v_gold, 'defense_gain', v_defense_gain)
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Kalıcı savunma eklendi.',
    'defense_gain', v_defense_gain,
    'new_defense', v_territory.defense_power + v_defense_gain,
    'vault_gold', (SELECT vault_gold FROM public.guilds WHERE id = v_guild_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_territory_attack_preview(p_territory_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_territory RECORD;
  v_guild RECORD;
  v_defender RECORD;
  v_attack_power INTEGER;
  v_effective_defense INTEGER;
  v_cost INTEGER;
  v_win_pct NUMERIC;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  PERFORM public._accrue_guild_vault(v_guild_id);

  SELECT g.id, g.name, g.tag, g.vault_gold, g.vault_gold_pending, g.leader_id
  INTO v_guild
  FROM public.guilds g WHERE g.id = v_guild_id;

  IF v_territory.owner_guild_id IS NOT NULL THEN
    SELECT g.id, g.name, g.tag INTO v_defender
    FROM public.guilds g WHERE g.id = v_territory.owner_guild_id;
  END IF;

  SELECT COALESCE(level * 50, 100) INTO v_attack_power FROM public.users WHERE auth_id = v_user;
  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power, v_territory.gem_defense_boost
  );
  v_cost := COALESCE(
    v_territory.attack_gold_cost,
    GREATEST(1000, (COALESCE(v_territory.trade_income, 0) * 0.55)::INTEGER)
  );
  v_win_pct := ROUND(
    (v_attack_power::NUMERIC / GREATEST(v_attack_power + v_effective_defense, 1)) * 100,
    1
  );

  RETURN jsonb_build_object(
    'success', true,
    'territory_id', v_territory.id,
    'territory_name', v_territory.name,
    'trade_income', COALESCE(v_territory.trade_income, 0),
    'attack_gold_cost', v_cost,
    'roi_days', CASE
      WHEN COALESCE(v_territory.trade_income, 0) > 0
      THEN ROUND(v_cost::NUMERIC / v_territory.trade_income, 1)
      ELSE NULL
    END,
    'attack_power', v_attack_power,
    'defense_power', v_effective_defense,
    'win_chance_pct', v_win_pct,
    'vault_gold', COALESCE(v_guild.vault_gold, 0),
    'vault_gold_pending', COALESCE(v_guild.vault_gold_pending, 0),
    'can_afford', COALESCE(v_guild.vault_gold, 0) >= v_cost,
    'attacker_guild', jsonb_build_object(
      'id', v_guild.id,
      'name', v_guild.name,
      'tag', v_guild.tag
    ),
    'defender_guild', CASE
      WHEN v_defender.id IS NULL THEN NULL
      ELSE jsonb_build_object('id', v_defender.id, 'name', v_defender.name, 'tag', v_defender.tag)
    END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.attack_guild_war_territory(p_territory_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id UUID := auth.uid();
  v_guild_id UUID;
  v_guild RECORD;
  v_territory RECORD;
  v_attack_power INTEGER;
  v_effective_defense INTEGER;
  v_success BOOLEAN;
  v_points_gained INTEGER;
  v_active_season_id UUID;
  v_rep_gain INTEGER := 0;
  v_combat JSONB;
  v_cost INTEGER;
  v_defender_name TEXT;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_combat := public.assert_player_combat_ready(v_player_id, false);
  IF v_combat IS NOT NULL THEN
    RETURN v_combat::json;
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_player_id;
  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  v_cost := COALESCE(
    v_territory.attack_gold_cost,
    GREATEST(1000, (COALESCE(v_territory.trade_income, 0) * 0.55)::INTEGER)
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

  SELECT COALESCE(level * 50, 100) INTO v_attack_power FROM public.users WHERE auth_id = v_player_id;
  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power,
    v_territory.gem_defense_boost
  );
  v_success := (random() * v_attack_power) > (random() * GREATEST(v_effective_defense, 1));
  v_points_gained := CASE WHEN v_success THEN 100 ELSE 10 END;
  v_rep_gain := CASE WHEN v_success THEN 20 ELSE 5 END;

  UPDATE public.guilds SET vault_gold = vault_gold - v_cost WHERE id = v_guild_id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild_id, v_player_id, 'attack_spend',
    jsonb_build_object(
      'territory_id', p_territory_id,
      'gold', v_cost,
      'success', v_success,
      'defender', v_defender_name
    )
  );

  SELECT id INTO v_active_season_id
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_active_season_id IS NOT NULL THEN
    INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
    VALUES (
      v_active_season_id,
      v_guild_id,
      v_points_gained,
      CASE WHEN v_success THEN 1 ELSE 0 END,
      CASE WHEN v_success THEN 0 ELSE 1 END
    )
    ON CONFLICT (season_id, guild_id) DO UPDATE SET
      points = guild_war_rankings.points + v_points_gained,
      wins = guild_war_rankings.wins + (CASE WHEN v_success THEN 1 ELSE 0 END),
      losses = guild_war_rankings.losses + (CASE WHEN v_success THEN 0 ELSE 1 END),
      updated_at = now();
  END IF;

  IF v_success THEN
    PERFORM public._accrue_guild_vault(v_territory.owner_guild_id);
    UPDATE public.guild_war_territories
    SET owner_guild_id = v_guild_id,
        defense_power = v_attack_power,
        gem_defense_boost = 0,
        updated_at = now()
    WHERE id = p_territory_id;
  END IF;

  UPDATE public.users
  SET reputation = COALESCE(reputation, 0) + v_rep_gain
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
    'defender_guild_name', v_defender_name
  );
END;
$$;

-- Extend territory list/detail with economy columns
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
        WHERE d.dungeon_id = public.guild_war_siege_dungeon_id(t.zone_number)
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
        WHERE d.dungeon_id = public.guild_war_siege_dungeon_id(t.zone_number)
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

GRANT EXECUTE ON FUNCTION public.get_territory_attack_preview(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_territory_defense_gold(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attack_guild_war_territory(uuid) TO authenticated;

COMMIT;
