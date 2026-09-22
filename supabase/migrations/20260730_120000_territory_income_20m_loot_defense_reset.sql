-- Bölge ekonomisi: ~20M günlük gelir, 6-7 rastgele non-common loot/gün,
-- fetihte savunma sıfırlanır. Saldırı maliyeti + altın→savunma oranı yeniden ayarlanır.

BEGIN;

-- ── 1) Gelir / maliyet seed (zone bazlı ~20M bandı) ──────────────────────────
UPDATE public.guild_war_territories t
SET
  trade_income = v.trade_income,
  attack_gold_cost = v.attack_gold_cost,
  min_defense_gems = v.min_defense_gems,
  reward = v.reward,
  loot_item_chance = 1.0
FROM (
  VALUES
    (1, 12000000, 600000, 20, '12,000,000 Altın/gün + 6-7 eşya'),
    (2, 14000000, 700000, 25, '14,000,000 Altın/gün + 6-7 eşya'),
    (3, 16000000, 800000, 30, '16,000,000 Altın/gün + 6-7 eşya'),
    (4, 18000000, 900000, 35, '18,000,000 Altın/gün + 6-7 eşya'),
    (5, 20000000, 1000000, 40, '20,000,000 Altın/gün + 6-7 eşya'),
    (6, 22000000, 1100000, 45, '22,000,000 Altın/gün + 6-7 eşya'),
    (7, 25000000, 1250000, 50, '25,000,000 Altın/gün + 6-7 eşya')
) AS v(zone_number, trade_income, attack_gold_cost, min_defense_gems, reward)
WHERE t.zone_number = v.zone_number;

-- ── 2) Günlük loot: bölge başına 6-7 rastgele non-common item ───────────────
CREATE OR REPLACE FUNCTION public._pick_territory_loot_item_id()
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_roll NUMERIC := random();
  v_rarity TEXT;
  v_item_id TEXT;
BEGIN
  -- Ağırlık: uncommon 40% / rare 30% / epic 18% / legendary 8% / mythic 4%
  v_rarity := CASE
    WHEN v_roll < 0.40 THEN 'uncommon'
    WHEN v_roll < 0.70 THEN 'rare'
    WHEN v_roll < 0.88 THEN 'epic'
    WHEN v_roll < 0.96 THEN 'legendary'
    ELSE 'mythic'
  END;

  SELECT i.id INTO v_item_id
  FROM public.items i
  WHERE lower(COALESCE(i.rarity, '')) = v_rarity
  ORDER BY random()
  LIMIT 1;

  IF v_item_id IS NULL THEN
    SELECT i.id INTO v_item_id
    FROM public.items i
    WHERE lower(COALESCE(i.rarity, '')) NOT IN ('common', '')
    ORDER BY random()
    LIMIT 1;
  END IF;

  RETURN v_item_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._accrue_guild_vault_territory_loot(p_guild_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row RECORD;
  v_state RECORD;
  v_added INTEGER := 0;
  v_loot_cooldown INTERVAL := interval '24 hours';
  v_drop_count INTEGER;
  v_i INTEGER;
  v_item_id TEXT;
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  FOR v_row IN
    SELECT t.id AS territory_id
    FROM public.guild_war_territories t
    WHERE t.owner_guild_id = p_guild_id
  LOOP
    SELECT * INTO v_state
    FROM public.guild_vault_territory_loot_state
    WHERE guild_id = p_guild_id AND territory_id = v_row.territory_id;

    IF FOUND AND v_state.last_loot_at > now() - v_loot_cooldown THEN
      CONTINUE;
    END IF;

    -- En az 6, %50 ihtimalle 7
    v_drop_count := 6 + CASE WHEN random() < 0.5 THEN 1 ELSE 0 END;

    FOR v_i IN 1..v_drop_count LOOP
      v_item_id := public._pick_territory_loot_item_id();
      IF v_item_id IS NULL THEN
        CONTINUE;
      END IF;

      INSERT INTO public.guild_vault_items (guild_id, item_id, quantity, source_type, source_ref)
      VALUES (p_guild_id, v_item_id, 1, 'territory_loot', v_row.territory_id::text);

      INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
      VALUES (
        p_guild_id,
        auth.uid(),
        'territory_loot',
        jsonb_build_object(
          'territory_id', v_row.territory_id,
          'item_id', v_item_id
        )
      );

      v_added := v_added + 1;
    END LOOP;

    INSERT INTO public.guild_vault_territory_loot_state (guild_id, territory_id, last_loot_at)
    VALUES (p_guild_id, v_row.territory_id, now())
    ON CONFLICT (guild_id, territory_id) DO UPDATE
      SET last_loot_at = EXCLUDED.last_loot_at;
  END LOOP;

  RETURN v_added;
END;
$$;

-- ── 3) Altın→savunma oranı: yeni ekonomiye göre (1000g = +1 def) ────────────
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

  IF v_gold < 1000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum 1000 altın gerekli.');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_guild_id FOR UPDATE;
  IF COALESCE(v_guild.vault_gold, 0) < v_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca kasasında yeterli altın yok.');
  END IF;

  v_defense_gain := (v_gold / 1000)::INTEGER; -- 1000g = +1 def

  IF v_defense_gain <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Savunma artışı hesaplanamadı.');
  END IF;

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

-- ── 4) Fetih → savunma sıfır ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.attack_guild_war_territory(p_territory_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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
  v_health INTEGER;
  v_max_health INTEGER;
  v_damage INTEGER;
  v_health_after INTEGER;
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

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  v_cost := COALESCE(
    v_territory.attack_gold_cost,
    GREATEST(1000, (COALESCE(v_territory.trade_income, 0) * 0.05)::INTEGER)
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
        defense_power = 0,
        gem_defense_boost = 0,
        defense_line_level = 0,
        updated_at = now()
    WHERE id = p_territory_id;
  END IF;

  SELECT COALESCE(health, max_health, 100), GREATEST(COALESCE(max_health, 100), 1)
  INTO v_health, v_max_health
  FROM public.users
  WHERE auth_id = v_player_id;

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
    'max_health', v_max_health
  );
END;
$function$;

-- ── 5) Hub listesi: loot etiketi ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_guild_war_territories()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result json;
  v_user UUID := auth.uid();
  v_guild_id UUID;
BEGIN
  PERFORM public.guild_war_reset_gem_defense_outside_prime();

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NOT NULL THEN
    PERFORM public._accrue_guild_vault(v_guild_id);
  END IF;

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
      ROUND(COALESCE(t.trade_income, 0)::NUMERIC / 24.0, 1) AS trade_income_hourly,
      t.zone_number,
      t.loot_item_id,
      '6-7 rastgele eşya (common hariç)' AS loot_item_name,
      1.0::NUMERIC AS loot_item_chance,
      COALESCE(t.attack_gold_cost, GREATEST(1000, (COALESCE(t.trade_income, 0) * 0.05)::INTEGER)) AS attack_gold_cost,
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
      ) AS has_active_siege_session,
      CASE
        WHEN v_guild_id IS NOT NULL AND t.owner_guild_id = v_guild_id THEN (
          SELECT json_build_object(
            'vault_gold', COALESCE(g2.vault_gold, 0),
            'vault_gold_pending', COALESCE(g2.vault_gold_pending, 0),
            'is_leader', g2.leader_id = v_user,
            'can_collect', g2.leader_id = v_user AND COALESCE(g2.vault_gold_pending, 0) > 0
          )
          FROM public.guilds g2
          WHERE g2.id = v_guild_id
        )
        ELSE NULL
      END AS vault_summary
    FROM public.guild_war_territories t
    LEFT JOIN public.guilds g ON g.id = t.owner_guild_id
    ORDER BY t.zone_number NULLS LAST, t.name
  ) t;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public._pick_territory_loot_item_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_territory_defense_gold(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attack_guild_war_territory(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_war_territories() TO authenticated;

COMMIT;
