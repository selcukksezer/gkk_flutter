-- Dungeon experience: player stats in get_dungeons, milestone rewards, attack_dungeon passthrough

BEGIN;

ALTER TABLE public.player_dungeon_stats
  ADD COLUMN IF NOT EXISTS claimed_milestones INTEGER[] NOT NULL DEFAULT '{}';

CREATE OR REPLACE FUNCTION public._dungeon_runs_since_best_rarity(
  p_player_id UUID,
  p_dungeon_id TEXT
) RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(COUNT(*)::INTEGER, 0)
  FROM public.dungeon_runs dr
  WHERE dr.player_id = p_player_id
    AND dr.dungeon_id = p_dungeon_id
    AND dr.created_at > COALESCE(
      (
        SELECT MAX(dr2.created_at)
        FROM public.dungeon_runs dr2
        WHERE dr2.player_id = p_player_id
          AND dr2.dungeon_id = p_dungeon_id
          AND dr2.success = true
          AND EXISTS (
            SELECT 1
            FROM jsonb_array_elements(COALESCE(dr2.items_dropped, '[]'::jsonb)) elem
            WHERE lower(COALESCE(elem->>'rarity', '')) IN ('epic', 'legendary', 'mythic')
          )
      ),
      '1970-01-01'::timestamptz
    );
$$;

CREATE OR REPLACE FUNCTION public._dungeon_grant_milestones(
  p_player_id UUID,
  p_dungeon_id TEXT,
  p_total_attempts INTEGER,
  p_zone INTEGER
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_milestone INTEGER;
  v_rewards JSONB := '[]'::JSONB;
  v_claimed INTEGER[];
  v_gold_bonus INTEGER;
  v_loot_item RECORD;
  v_item_added BOOLEAN;
  v_label TEXT;
BEGIN
  SELECT COALESCE(claimed_milestones, '{}') INTO v_claimed
  FROM public.player_dungeon_stats
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  IF NOT FOUND THEN
    RETURN '[]'::JSONB;
  END IF;

  FOREACH v_milestone IN ARRAY ARRAY[10, 25, 50] LOOP
    IF p_total_attempts < v_milestone THEN
      CONTINUE;
    END IF;

    IF v_milestone = ANY(v_claimed) THEN
      CONTINUE;
    END IF;

    IF v_milestone = 10 THEN
      v_gold_bonus := 5000 + GREATEST(1, p_zone) * 2000;
      UPDATE public.users SET gold = gold + v_gold_bonus WHERE auth_id = p_player_id;
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE lower(type) = 'scroll'
      ORDER BY random()
      LIMIT 1;
      v_label := '10. koşu: +' || v_gold_bonus || ' altın';
    ELSIF v_milestone = 25 THEN
      v_gold_bonus := 15000 + GREATEST(1, p_zone) * 5000;
      UPDATE public.users SET gold = gold + v_gold_bonus WHERE auth_id = p_player_id;
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE lower(type) IN ('material', 'consumable')
      ORDER BY random()
      LIMIT 1;
      v_label := '25. koşu: +' || v_gold_bonus || ' altın';
    ELSE
      v_gold_bonus := 40000 + GREATEST(1, p_zone) * 10000;
      UPDATE public.users SET gold = gold + v_gold_bonus WHERE auth_id = p_player_id;
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE lower(type) IN ('material', 'consumable', 'scroll')
      ORDER BY random()
      LIMIT 1;
      v_label := '50. koşu: +' || v_gold_bonus || ' altın';
    END IF;

    IF FOUND THEN
      v_item_added := public.dungeon_add_item(p_player_id, v_loot_item.id, 1);
      IF v_item_added THEN
        v_label := v_label || ' + ' || v_loot_item.name;
      END IF;
    END IF;

    UPDATE public.player_dungeon_stats
    SET claimed_milestones = array_append(COALESCE(claimed_milestones, '{}'), v_milestone)
    WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

    v_rewards := v_rewards || jsonb_build_object(
      'milestone', v_milestone,
      'label', v_label,
      'gold', v_gold_bonus,
      'item_name', CASE WHEN FOUND THEN v_loot_item.name ELSE NULL END
    );
  END LOOP;

  RETURN v_rewards;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_dungeons()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_player_id UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', d.id,
      'dungeon_id', d.id,
      'name', COALESCE(NULLIF(d.name_tr, ''), d.name),
      'description', COALESCE(d.description, ''),
      'difficulty', CASE
        WHEN d.is_boss THEN 'dungeon'
        WHEN COALESCE(d.power_requirement, 0) < 15000 THEN 'easy'
        WHEN COALESCE(d.power_requirement, 0) < 45000 THEN 'medium'
        ELSE 'hard'
      END,
      'required_level', GREATEST(1, floor(COALESCE(d.power_requirement, 0) / 500.0)::INT),
      'min_level', GREATEST(1, floor(COALESCE(d.power_requirement, 0) / 500.0)::INT),
      'power_requirement', COALESCE(d.power_requirement, 0),
      'max_players', 1,
      'energy_cost', COALESCE(d.energy_cost, 0),
      'min_gold', COALESCE(d.gold_min, 0),
      'max_gold', COALESCE(d.gold_max, 0),
      'xp_reward', COALESCE(d.xp_reward, 0),
      'base_gold_reward', floor((COALESCE(d.gold_min, 0) + COALESCE(d.gold_max, 0)) / 2.0)::INT,
      'base_xp_reward', COALESCE(d.xp_reward, 0),
      'is_group', false,
      'loot_table', '[]'::jsonb,
      'equipment_drop_chance', COALESCE(d.equipment_drop_chance, 0),
      'resource_drop_chance', COALESCE(d.resource_drop_chance, 0),
      'catalyst_drop_chance', COALESCE(d.catalyst_drop_chance, 0),
      'scroll_drop_chance', COALESCE(d.scroll_drop_chance, 0),
      'loot_rarity_weights', COALESCE(d.loot_rarity_weights, '{}'::jsonb),
      'boss_name', CASE WHEN COALESCE(d.is_boss, false) THEN COALESCE(d.name_tr, d.name) ELSE NULL END,
      'zone', COALESCE(d.zone, 1),
      'zone_name', COALESCE(d.zone_name, ''),
      'dungeon_order', COALESCE(d.dungeon_order, 0),
      'is_boss', COALESCE(d.is_boss, false),
      'daily_boss_limit', COALESCE(d.daily_boss_limit, 3),
      'total_attempts', COALESCE(pds.total_attempts, 0),
      'total_successes', COALESCE(pds.total_successes, 0),
      'first_clear_at', pds.first_clear_at,
      'today_attempts', COALESCE(pds.today_attempts, 0),
      'today_boss_attempts', COALESCE(pds.today_boss_attempts, 0),
      'runs_since_best_rarity', CASE
        WHEN v_player_id IS NULL THEN 0
        ELSE public._dungeon_runs_since_best_rarity(v_player_id, d.id)
      END
    )
    ORDER BY COALESCE(d.dungeon_order, 0)
  ), '[]'::JSONB)
  INTO v_result
  FROM public.dungeons d
  LEFT JOIN public.player_dungeon_stats pds
    ON pds.dungeon_id = d.id
   AND pds.player_id = v_player_id;

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

-- Patch enter_dungeon: append milestone rewards after stats update
CREATE OR REPLACE FUNCTION public.enter_dungeon(
  p_player_id UUID,
  p_dungeon_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_dungeon           RECORD;
  v_player            RECORD;
  v_power             INTEGER;
  v_success_rate      NUMERIC;
  v_success           BOOLEAN;
  v_is_critical       BOOLEAN;
  v_gold              INTEGER;
  v_xp                INTEGER;
  v_hospitalized      BOOLEAN := false;
  v_hospital_until    TIMESTAMPTZ;
  v_hospital_minutes  INTEGER;
  v_is_first          BOOLEAN := false;
  v_items             JSONB := '[]'::JSONB;
  v_today_boss        INTEGER;
  v_luck_for_loot     NUMERIC;
  v_loot_luck_bonus   NUMERIC;
  v_shadow_loot_bonus NUMERIC := 0;
  v_effective_equipment_drop NUMERIC;
  v_effective_resource_drop  NUMERIC;
  v_effective_scroll_drop    NUMERIC;
  v_rarity_luck_shift NUMERIC;
  v_ratio             NUMERIC;
  v_hospital_chance   NUMERIC;
  v_hospital_risk_pct NUMERIC := 0;
  v_defense_mitigation NUMERIC;
  v_inventory_full    BOOLEAN := false;
  v_loot_item         RECORD;
  v_loot_rarity       TEXT;
  v_rarity_roll       NUMERIC;
  v_rarity_weights    JSONB;
  v_item_added        BOOLEAN;
  v_dungeon_num       INTEGER;
  v_rec_level         INTEGER := 1;
  v_level_gap         INTEGER := 0;
  v_reward_mult       NUMERIC := 1.0;
  v_total_attempts    INTEGER := 0;
  v_milestone_rewards JSONB := '[]'::JSONB;
BEGIN
  IF p_player_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_dungeon FROM public.dungeons WHERE id = p_dungeon_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'dungeon_not_found');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;

  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('error', 'in_hospital');
  END IF;

  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('error', 'in_prison');
  END IF;

  IF v_player.energy < v_dungeon.energy_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_energy');
  END IF;

  v_dungeon_num := CAST(SUBSTRING(p_dungeon_id FROM 5) AS INTEGER);

  INSERT INTO public.player_dungeon_stats (player_id, dungeon_id)
  VALUES (p_player_id, p_dungeon_id)
  ON CONFLICT (player_id, dungeon_id) DO NOTHING;

  UPDATE public.player_dungeon_stats
  SET today_attempts = 0, today_boss_attempts = 0, today_date = CURRENT_DATE
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id AND today_date < CURRENT_DATE;

  SELECT today_boss_attempts INTO v_today_boss
  FROM public.player_dungeon_stats
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN
    RETURN jsonb_build_object('error', 'boss_daily_limit');
  END IF;

  v_power := public.calculate_user_total_power(p_player_id)::INTEGER;
  IF v_power IS NULL OR v_power = 0 THEN
    v_power := v_player.level * 500
             + floor(COALESCE(v_player.reputation, 0) * 0.1)
             + floor(COALESCE(v_player.luck, 0) * 50);
  END IF;
  UPDATE public.users SET power = v_power WHERE auth_id = p_player_id;

  IF v_dungeon.power_requirement = 0 THEN
    v_success_rate := 1.0;
  ELSE
    v_ratio := v_power::NUMERIC / v_dungeon.power_requirement;
    IF    v_ratio >= 1.5  THEN v_success_rate := 0.95;
    ELSIF v_ratio >= 1.0  THEN v_success_rate := 0.70 + (v_ratio - 1.0) * 0.50;
    ELSIF v_ratio >= 0.5  THEN v_success_rate := 0.25 + (v_ratio - 0.5) * 0.90;
    ELSIF v_ratio >= 0.25 THEN v_success_rate := 0.10 + (v_ratio - 0.25) * 0.60;
    ELSE                       v_success_rate := GREATEST(0.05, v_ratio * 0.40);
    END IF;

    v_success_rate := v_success_rate + LEAST(0.05, COALESCE(v_player.luck, 0) * 0.001);
    v_success_rate := v_success_rate + LEAST(0.025, COALESCE(v_player.reputation, 0) * 0.0005);
    IF COALESCE(v_player.character_class, '') = 'warrior' THEN
      v_success_rate := v_success_rate + 0.05;
    END IF;
    v_success_rate := LEAST(0.95, GREATEST(0.05, v_success_rate));
  END IF;

  IF v_dungeon_num <= 3 THEN
    v_hospital_risk_pct := 0;
  ELSE
    v_hospital_chance := GREATEST(0.05, LEAST(0.90, 1.0 - v_success_rate));
    v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);
    v_hospital_risk_pct := round(v_hospital_chance * 100, 1);
  END IF;

  SELECT (first_clear_at IS NULL) INTO v_is_first
  FROM public.player_dungeon_stats
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  v_success     := random() <= v_success_rate;
  v_is_critical := v_success AND random() <= 0.10;

  IF v_success THEN
    v_gold := v_dungeon.gold_min + floor(random() * (v_dungeon.gold_max - v_dungeon.gold_min));
    v_xp   := v_dungeon.xp_reward;

    IF v_is_critical THEN
      v_gold := floor(v_gold * 1.5);
      v_xp   := floor(v_xp   * 1.5);
    END IF;

    v_luck_for_loot := COALESCE(v_player.luck, 0);
    v_gold := floor(v_gold * (1 + v_luck_for_loot * 0.002));
    v_xp   := floor(v_xp   * (1 + COALESCE(v_player.luck, 0) * 0.001));

    IF COALESCE(v_player.character_class, '') = 'shadow' THEN
      v_shadow_loot_bonus := 0.20;
    END IF;
    v_loot_luck_bonus := LEAST(0.20, v_luck_for_loot * 0.0015);
    v_effective_equipment_drop := LEAST(0.95, GREATEST(0, v_dungeon.equipment_drop_chance * (1 + v_loot_luck_bonus + v_shadow_loot_bonus)));
    v_effective_resource_drop  := LEAST(0.95, GREATEST(0, v_dungeon.resource_drop_chance  * (1 + v_loot_luck_bonus + v_shadow_loot_bonus)));
    v_effective_scroll_drop    := LEAST(0.95, GREATEST(0, v_dungeon.scroll_drop_chance    * (1 + v_loot_luck_bonus + v_shadow_loot_bonus)));

    IF COALESCE(v_player.character_class, '') = 'warrior' AND v_dungeon.is_boss THEN
      v_gold := floor(v_gold * 1.15);
    END IF;

    v_rec_level := GREATEST(1, FLOOR(COALESCE(v_dungeon.power_requirement, 0) / 500.0));
    v_level_gap := GREATEST(0, v_player.level - v_rec_level);

    v_reward_mult := public._dungeon_farm_reward_multiplier(
      v_player.level,
      v_dungeon.power_requirement,
      v_success_rate,
      v_is_first
    );

    v_gold := floor(v_gold * v_reward_mult);
    v_xp   := floor(v_xp   * v_reward_mult);
    v_effective_equipment_drop := LEAST(0.95, GREATEST(0, v_effective_equipment_drop * v_reward_mult));
    v_effective_resource_drop  := LEAST(0.95, GREATEST(0, v_effective_resource_drop  * v_reward_mult));
    v_effective_scroll_drop    := LEAST(0.95, GREATEST(0, v_effective_scroll_drop    * v_reward_mult));

    v_rarity_weights := v_dungeon.loot_rarity_weights;
    v_rarity_luck_shift := LEAST(0.10, v_luck_for_loot * 0.0008 + CASE WHEN COALESCE(v_player.character_class, '') = 'shadow' THEN 0.05 ELSE 0 END);
    v_rarity_roll := GREATEST(0, random() - v_rarity_luck_shift);

    IF v_rarity_weights IS NOT NULL AND v_rarity_weights != '{}'::jsonb THEN
      IF v_rarity_roll < COALESCE((v_rarity_weights->>'legendary')::NUMERIC, 0) THEN
        v_loot_rarity := 'legendary';
      ELSIF v_rarity_roll < COALESCE((v_rarity_weights->>'epic')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'legendary')::NUMERIC, 0) THEN
        v_loot_rarity := 'epic';
      ELSIF v_rarity_roll < COALESCE((v_rarity_weights->>'rare')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'epic')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'legendary')::NUMERIC, 0) THEN
        v_loot_rarity := 'rare';
      ELSIF v_rarity_roll < COALESCE((v_rarity_weights->>'uncommon')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'rare')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'epic')::NUMERIC, 0)
                           + COALESCE((v_rarity_weights->>'legendary')::NUMERIC, 0) THEN
        v_loot_rarity := 'uncommon';
      ELSE
        v_loot_rarity := 'common';
      END IF;
    ELSE
      v_loot_rarity := 'common';
    END IF;

    IF random() <= v_effective_equipment_drop THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE lower(rarity) = v_loot_rarity
        AND lower(type) IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_item_added := public.dungeon_add_item(p_player_id, v_loot_item.id, 1);
        IF v_item_added THEN
          v_items := v_items || jsonb_build_object(
            'item_id', v_loot_item.id,
            'name',    v_loot_item.name,
            'rarity',  v_loot_rarity,
            'type',    v_loot_item.type
          );
        ELSE
          v_inventory_full := true;
        END IF;
      END IF;
    END IF;

    IF random() <= v_effective_resource_drop THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE lower(rarity) = v_loot_rarity
        AND lower(type) IN ('material', 'consumable')
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_item_added := public.dungeon_add_item(p_player_id, v_loot_item.id, 1);
        IF v_item_added THEN
          v_items := v_items || jsonb_build_object(
            'item_id', v_loot_item.id,
            'name',    v_loot_item.name,
            'rarity',  v_loot_rarity,
            'type',    v_loot_item.type
          );
        ELSE
          v_inventory_full := true;
        END IF;
      END IF;
    END IF;

    IF random() <= v_effective_scroll_drop THEN
      SELECT * INTO v_loot_item
      FROM public.items
      WHERE lower(type) = 'scroll'
      ORDER BY random()
      LIMIT 1;

      IF FOUND THEN
        v_item_added := public.dungeon_add_item(p_player_id, v_loot_item.id, 1);
        IF v_item_added THEN
          v_items := v_items || jsonb_build_object(
            'item_id', v_loot_item.id,
            'name',    v_loot_item.name,
            'rarity',  v_loot_rarity,
            'type',    'scroll'
          );
        ELSE
          v_inventory_full := true;
        END IF;
      END IF;
    END IF;

  ELSE
    v_gold := floor(v_dungeon.gold_min * 0.3);
    v_xp   := floor(v_dungeon.xp_reward * 0.2);
    v_reward_mult := 1.0;

    IF v_dungeon_num <= 3 THEN
      v_hospital_chance := 0.0;
    ELSE
      v_hospital_chance := GREATEST(0.05, LEAST(0.90, 1.0 - v_success_rate));
      v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);
    END IF;

    IF random() <= v_hospital_chance THEN
      v_hospitalized     := true;
      v_hospital_minutes := v_dungeon.hospital_min_minutes
        + floor(random() * GREATEST(0, v_dungeon.hospital_max_minutes - v_dungeon.hospital_min_minutes));

      v_defense_mitigation := LEAST(0.30, COALESCE(v_player.defense, 0) * 0.001);
      v_hospital_minutes   := floor(v_hospital_minutes * (1 - v_defense_mitigation));

      IF COALESCE(v_player.character_class, '') = 'warrior' THEN
        v_hospital_minutes := floor(v_hospital_minutes * 0.80);
      END IF;

      v_hospital_until := now() + (v_hospital_minutes || ' minutes')::INTERVAL;
      UPDATE public.users
      SET hospital_until = v_hospital_until,
          hospital_lifetime_count = COALESCE(hospital_lifetime_count, 0) + 1
      WHERE auth_id = p_player_id;
    END IF;

    IF v_hospitalized THEN
      v_gold  := 0;
      v_xp    := 0;
      v_items := '[]'::JSONB;
    END IF;
  END IF;

  UPDATE public.users
  SET energy = energy - v_dungeon.energy_cost,
      gold   = gold   + v_gold,
      xp     = xp     + v_xp
  WHERE auth_id = p_player_id AND energy >= v_dungeon.energy_cost;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Yetersiz enerji veya işlem çakışması');
  END IF;

  UPDATE public.player_dungeon_stats
  SET total_attempts      = total_attempts  + 1,
      total_successes     = total_successes + CASE WHEN v_success THEN 1 ELSE 0 END,
      total_failures      = total_failures  + CASE WHEN v_success THEN 0 ELSE 1 END,
      first_clear_at      = CASE WHEN v_success AND first_clear_at IS NULL THEN now() ELSE first_clear_at END,
      today_attempts      = today_attempts  + 1,
      today_boss_attempts = today_boss_attempts + CASE WHEN v_dungeon.is_boss THEN 1 ELSE 0 END,
      today_date          = CURRENT_DATE,
      best_power_at_clear = CASE WHEN v_success AND v_power > best_power_at_clear
                                 THEN v_power ELSE best_power_at_clear END
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  SELECT total_attempts INTO v_total_attempts
  FROM public.player_dungeon_stats
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;

  v_milestone_rewards := public._dungeon_grant_milestones(
    p_player_id,
    p_dungeon_id,
    v_total_attempts,
    COALESCE(v_dungeon.zone, 1)
  );

  INSERT INTO public.dungeon_runs (
    player_id, dungeon_id, success, is_critical,
    gold_earned, xp_earned, items_dropped,
    hospitalized, hospital_until,
    player_power, success_rate_at_run, is_first_clear
  ) VALUES (
    p_player_id, p_dungeon_id, v_success, v_is_critical,
    v_gold, v_xp, v_items,
    v_hospitalized, v_hospital_until,
    v_power, v_success_rate, v_is_first
  );

  RETURN jsonb_build_object(
    'success',            v_success,
    'is_critical',        v_is_critical,
    'gold_earned',        v_gold,
    'xp_earned',          v_xp,
    'items',              v_items,
    'items_dropped',      v_items,
    'hospitalized',       v_hospitalized,
    'hospital_until',     v_hospital_until,
    'is_first_clear',     v_is_first,
    'success_rate',       round(v_success_rate * 100, 1),
    'hospital_risk_pct',  v_hospital_risk_pct,
    'reward_multiplier',  round(v_reward_mult, 3),
    'recommended_level',  v_rec_level,
    'level_gap',          v_level_gap,
    'inventory_full',     v_inventory_full,
    'milestone_rewards',  v_milestone_rewards,
    'free_discharges_remaining', GREATEST(0, 2 - COALESCE(
      (SELECT hospital_lifetime_count FROM public.users WHERE auth_id = p_player_id), 0
    ))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.attack_dungeon(
  p_dungeon_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_result           JSONB;
  v_items_raw        JSONB;
  v_hospital_until   TIMESTAMPTZ;
  v_hospital_secs    INTEGER := 0;
BEGIN
  v_result := public.enter_dungeon(auth.uid(), p_dungeon_id);

  IF v_result ? 'error' THEN
    RETURN v_result;
  END IF;

  v_items_raw := COALESCE(v_result->'items', '[]'::JSONB);

  IF (v_result->>'hospital_until') IS NOT NULL THEN
    BEGIN
      v_hospital_until := (v_result->>'hospital_until')::TIMESTAMPTZ;
      v_hospital_secs  := GREATEST(0, EXTRACT(EPOCH FROM (v_hospital_until - now()))::INTEGER);
    EXCEPTION WHEN OTHERS THEN
      v_hospital_secs := 0;
    END;
  END IF;

  RETURN jsonb_build_object(
    'success',             COALESCE((v_result->>'success')::BOOLEAN, false),
    'gold',                COALESCE((v_result->>'gold_earned')::INTEGER, 0),
    'gold_earned',         COALESCE((v_result->>'gold_earned')::INTEGER, 0),
    'xp',                  COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'xp_earned',           COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'items',               v_items_raw,
    'item_details',        v_items_raw,
    'hospitalized',        COALESCE((v_result->>'hospitalized')::BOOLEAN, false),
    'hospital_duration',   v_hospital_secs,
    'hospital_until',      v_result->>'hospital_until',
    'inventory_full',      COALESCE((v_result->>'inventory_full')::BOOLEAN, false),
    'is_critical',         COALESCE((v_result->>'is_critical')::BOOLEAN, false),
    'is_first_clear',      COALESCE((v_result->>'is_first_clear')::BOOLEAN, false),
    'success_rate',        COALESCE((v_result->>'success_rate')::NUMERIC, 0),
    'reward_multiplier',   COALESCE((v_result->>'reward_multiplier')::NUMERIC, 1),
    'hospital_risk_pct',   COALESCE((v_result->>'hospital_risk_pct')::NUMERIC, 0),
    'milestone_rewards',   COALESCE(v_result->'milestone_rewards', '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_dungeons() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.enter_dungeon(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attack_dungeon(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public._dungeon_runs_since_best_rarity(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public._dungeon_grant_milestones(UUID, TEXT, INTEGER, INTEGER) TO authenticated;

COMMIT;
