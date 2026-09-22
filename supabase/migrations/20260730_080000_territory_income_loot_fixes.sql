-- Bölge geliri + loot: accrual backfill, günlük loot, hub accrue, z1-2 loot seed.

BEGIN;

-- Z1-2: düşük tier loot (önceden hiç yoktu → item hiç düşmüyordu)
UPDATE public.guild_war_territories t
SET
  loot_item_id = COALESCE(t.loot_item_id, 'scroll_upgrade_low'),
  loot_item_chance = COALESCE(NULLIF(t.loot_item_chance, 0), 0.20)
WHERE COALESCE(t.zone_number, 0) IN (1, 2)
  AND t.loot_item_id IS NULL;

UPDATE public.guild_war_territories t
SET loot_item_chance = GREATEST(COALESCE(t.loot_item_chance, 0), 0.25)
WHERE COALESCE(t.zone_number, 0) IN (3, 4);

UPDATE public.guild_war_territories t
SET loot_item_chance = GREATEST(COALESCE(t.loot_item_chance, 0), 0.35)
WHERE COALESCE(t.zone_number, 0) >= 5;

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
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  FOR v_row IN
    SELECT t.id AS territory_id, t.loot_item_id, COALESCE(t.loot_item_chance, 0) AS loot_chance
    FROM public.guild_war_territories t
    WHERE t.owner_guild_id = p_guild_id
      AND t.loot_item_id IS NOT NULL
      AND COALESCE(t.loot_item_chance, 0) > 0
  LOOP
    SELECT * INTO v_state
    FROM public.guild_vault_territory_loot_state
    WHERE guild_id = p_guild_id AND territory_id = v_row.territory_id;

    IF FOUND AND v_state.last_loot_at > now() - v_loot_cooldown THEN
      CONTINUE;
    END IF;

    IF random() <= v_row.loot_chance THEN
      INSERT INTO public.guild_vault_items (guild_id, item_id, quantity, source_type, source_ref)
      VALUES (p_guild_id, v_row.loot_item_id, 1, 'territory_loot', v_row.territory_id::text);

      INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
      VALUES (
        p_guild_id,
        auth.uid(),
        'territory_loot',
        jsonb_build_object(
          'territory_id', v_row.territory_id,
          'item_id', v_row.loot_item_id
        )
      );

      v_added := v_added + 1;
    END IF;

    INSERT INTO public.guild_vault_territory_loot_state (guild_id, territory_id, last_loot_at)
    VALUES (p_guild_id, v_row.territory_id, now())
    ON CONFLICT (guild_id, territory_id) DO UPDATE
      SET last_loot_at = EXCLUDED.last_loot_at;
  END LOOP;

  RETURN v_added;
END;
$$;

CREATE OR REPLACE FUNCTION public._accrue_guild_vault(p_guild_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_guild RECORD;
  v_now TIMESTAMPTZ := now();
  v_from TIMESTAMPTZ;
  v_hours NUMERIC;
  v_cap_hours NUMERIC := 168;
  v_delta BIGINT := 0;
  v_row RECORD;
  v_first_owned TIMESTAMPTZ;
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT id, vault_last_accrual_at, vault_gold_pending
  INTO v_guild
  FROM public.guilds
  WHERE id = p_guild_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  SELECT MIN(t.updated_at) INTO v_first_owned
  FROM public.guild_war_territories t
  WHERE t.owner_guild_id = p_guild_id;

  v_from := COALESCE(
    v_guild.vault_last_accrual_at,
    GREATEST(v_now - interval '24 hours', COALESCE(v_first_owned, v_now - interval '24 hours'))
  );

  v_hours := EXTRACT(EPOCH FROM (v_now - v_from)) / 3600.0;
  IF v_hours <= 0 THEN
    PERFORM public._accrue_guild_vault_territory_loot(p_guild_id);
    SELECT vault_gold_pending INTO v_delta FROM public.guilds WHERE id = p_guild_id;
    RETURN COALESCE(v_delta, 0);
  END IF;
  v_hours := LEAST(v_hours, v_cap_hours);

  FOR v_row IN
    SELECT COALESCE(trade_income, 0) AS trade_income
    FROM public.guild_war_territories
    WHERE owner_guild_id = p_guild_id
  LOOP
    v_delta := v_delta + (v_row.trade_income * v_hours / 24.0)::BIGINT;
  END LOOP;

  IF v_delta > 0 THEN
    UPDATE public.guilds
    SET vault_gold_pending = vault_gold_pending + v_delta,
        vault_last_accrual_at = v_now
    WHERE id = p_guild_id;

    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      p_guild_id,
      auth.uid(),
      'accrue',
      jsonb_build_object('amount', v_delta, 'hours', v_hours)
    );
  ELSE
    UPDATE public.guilds
    SET vault_last_accrual_at = v_now
    WHERE id = p_guild_id;
  END IF;

  PERFORM public._accrue_guild_vault_territory_loot(p_guild_id);

  SELECT vault_gold_pending INTO v_delta FROM public.guilds WHERE id = p_guild_id;
  RETURN COALESCE(v_delta, 0);
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
      COALESCE(i.name, i.name_tr, t.loot_item_id) AS loot_item_name,
      COALESCE(t.loot_item_chance, 0) AS loot_item_chance,
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
    LEFT JOIN public.items i ON i.id = t.loot_item_id
    ORDER BY t.zone_number NULLS LAST, t.name
  ) t;

  RETURN v_result;
END;
$$;

COMMIT;
