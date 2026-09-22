-- Faz A: ROI 1.5x, gold def disable, preview/detail fix, siege credit /200,
-- ownership-aware accrual. (§17.7 defaults)

BEGIN;

-- ── ROI: attack_gold_cost ≈ 1.5 × daily income ─────────────────────────────
UPDATE public.guild_war_territories t
SET
  attack_gold_cost = GREATEST(1000, (COALESCE(t.trade_income, 0) * 1.5)::INTEGER),
  min_defense_gems = CASE
    WHEN COALESCE(t.zone_number, 0) >= 7 THEN 50
    WHEN COALESCE(t.zone_number, 0) >= 5 THEN 40
    WHEN COALESCE(t.zone_number, 0) >= 3 THEN 30
    ELSE 20
  END;

-- ── Gold defense: disable ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.add_territory_defense_gold(
  p_territory_id UUID,
  p_gold BIGINT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN jsonb_build_object(
    'success', false,
    'error', 'Altın ile savunma kaldırıldı. Elmas veya garnizon gücü kullanın.'
  );
END;
$$;

-- ── Accrual: ownership-aware (per-territory from updated_at) ────────────────
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
  v_terr_from TIMESTAMPTZ;
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

  IF EXTRACT(EPOCH FROM (v_now - v_from)) / 3600.0 <= 0 THEN
    PERFORM public._accrue_guild_vault_territory_loot(p_guild_id);
    SELECT vault_gold_pending INTO v_delta FROM public.guilds WHERE id = p_guild_id;
    RETURN COALESCE(v_delta, 0);
  END IF;

  FOR v_row IN
    SELECT COALESCE(trade_income, 0) AS trade_income,
           COALESCE(updated_at, v_from) AS owned_since
    FROM public.guild_war_territories
    WHERE owner_guild_id = p_guild_id
  LOOP
    v_terr_from := GREATEST(v_from, v_row.owned_since);
    v_hours := LEAST(EXTRACT(EPOCH FROM (v_now - v_terr_from)) / 3600.0, v_cap_hours);
    IF v_hours > 0 THEN
      v_delta := v_delta + (v_row.trade_income * v_hours / 24.0)::BIGINT;
    END IF;
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
      jsonb_build_object('amount', v_delta)
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

-- ── Attack preview fallback 1.5x ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_territory_attack_preview(uuid);
CREATE OR REPLACE FUNCTION public.get_territory_attack_preview(p_territory_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_player_id UUID := auth.uid();
  v_guild_id UUID;
  v_territory RECORD;
  v_attack_power INTEGER;
  v_effective_defense INTEGER;
  v_cost INTEGER;
  v_win_chance NUMERIC;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_player_id;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  IF v_territory IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_guild_id IS NOT NULL THEN
    PERFORM public._accrue_guild_vault(v_guild_id);
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  v_cost := COALESCE(
    v_territory.attack_gold_cost,
    GREATEST(1000, (COALESCE(v_territory.trade_income, 0) * 1.5)::INTEGER)
  );

  SELECT COALESCE(power, level * 50, 100) INTO v_attack_power
  FROM public.users WHERE auth_id = v_player_id;

  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power,
    v_territory.gem_defense_boost
  );

  v_win_chance := CASE
    WHEN v_attack_power + v_effective_defense <= 0 THEN 0.5
    ELSE ROUND((v_attack_power::NUMERIC / (v_attack_power + GREATEST(v_effective_defense, 1)))::NUMERIC, 3)
  END;

  RETURN jsonb_build_object(
    'success', true,
    'territory_id', p_territory_id,
    'attack_power', v_attack_power,
    'defense_power', v_effective_defense,
    'attack_gold_cost', v_cost,
    'trade_income', COALESCE(v_territory.trade_income, 0),
    'roi_days', CASE
      WHEN COALESCE(v_territory.trade_income, 0) > 0
      THEN ROUND(v_cost::NUMERIC / v_territory.trade_income, 1)
      ELSE NULL
    END,
    'win_chance', v_win_chance,
    'grace_until', CASE
      WHEN v_territory.updated_at > now() - interval '2 hours'
           AND v_territory.owner_guild_id IS NOT NULL
      THEN v_territory.updated_at + interval '2 hours'
      ELSE NULL
    END
  );
END;
$function$;

-- ── Detail: loot labels + cost fallback ────────────────────────────────────
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
      ROUND(COALESCE(t.trade_income, 0)::NUMERIC / 24.0, 1) AS trade_income_hourly,
      COALESCE(t.attack_gold_cost, GREATEST(1000, (COALESCE(t.trade_income, 0) * 1.5)::INTEGER)) AS attack_gold_cost,
      COALESCE(t.min_defense_gems, 5) AS min_defense_gems,
      t.defense_added_at,
      t.updated_at,
      t.zone_number,
      t.loot_item_id,
      '6-7 rastgele eşya (common hariç)' AS loot_item_name,
      1.0::NUMERIC AS loot_item_chance,
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

-- ── Hub list cost fallback 1.5x (loot label already set in 120000) ──────────
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
      COALESCE(t.attack_gold_cost, GREATEST(1000, (COALESCE(t.trade_income, 0) * 1.5)::INTEGER)) AS attack_gold_cost,
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

-- ── Siege claim credit: income/200 ─────────────────────────────────────────
-- Patch claim_siege_slot gold line via full replace of the gold SELECT only:
-- We recreate by wrapping: update the formula in a DO block using prosrc is fragile;
-- instead replace the whole function from live + /200.

CREATE OR REPLACE FUNCTION public.claim_siege_slot(p_dungeon_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_me uuid := auth.uid();
  v_player record;
  v_cfg public.dungeon_siege_config;
  v_session_id uuid;
  v_slot record;
  v_zone integer;
  v_territory_owner uuid;
  v_siege_gold BIGINT;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma şu an aktif değil.');
  END IF;

  IF public.dungeon_siege_is_banned(v_me, p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindandan banlısın.');
  END IF;

  IF NOT public.dungeon_siege_can_fight(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hastane/cezaevinde slot alamazsın.');
  END IF;

  IF public.dungeon_siege_player_holds_any_slot(v_me) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir kuşatma slotu tutuyorsun.');
  END IF;

  IF public.dungeon_siege_player_has_slot(v_me, p_dungeon_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu zindanda zaten slot tutuyorsun.');
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = v_me;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu profili bulunamadı.');
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_session_id := public.dungeon_siege_ensure_session(p_dungeon_id);
  IF v_session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşatma oturumu başlatılamadı.');
  END IF;

  v_zone := public.dungeon_siege_zone_for_dungeon(p_dungeon_id);
  v_territory_owner := public.dungeon_siege_territory_owner_for_zone(v_zone);

  SELECT * INTO v_slot
  FROM public.dungeon_siege_slots s
  WHERE s.session_id = v_session_id
    AND s.holder_id IS NULL
    AND (
      v_cfg.territory_reserve_slot_count <= 0
      OR v_territory_owner IS NULL
      OR s.slot_number > v_cfg.territory_reserve_slot_count
      OR v_player.guild_id IS NOT DISTINCT FROM v_territory_owner
    )
  ORDER BY s.slot_number
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', CASE
        WHEN v_territory_owner IS NOT NULL
             AND v_player.guild_id IS DISTINCT FROM v_territory_owner
        THEN 'Bölge sahibi lonca rezerv slotları dolu. Meydan oku.'
        ELSE 'Boş slot yok. Meydan oku.'
      END
    );
  END IF;

  UPDATE public.dungeon_siege_slots
  SET holder_id = v_me,
      guild_id = v_player.guild_id,
      claimed_at = now(),
      expires_at = now() + make_interval(mins => v_cfg.slot_duration_minutes),
      last_active_at = now()
  WHERE id = v_slot.id;

  PERFORM public.dungeon_siege_add_weekly_score(v_me, p_points => 5, p_slot_minutes => 0);

  IF v_player.guild_id IS NOT NULL THEN
    SELECT GREATEST(250, COALESCE(t.trade_income, 0) / 200)::BIGINT
    INTO v_siege_gold
    FROM public.guild_war_territories t
    WHERE t.zone_number = v_zone
    LIMIT 1;

    v_siege_gold := COALESCE(v_siege_gold, 250);
    PERFORM public.credit_guild_vault_pending(
      v_player.guild_id,
      v_siege_gold,
      'siege_reward',
      p_dungeon_id
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'slot_id', v_slot.id,
    'slot_number', v_slot.slot_number,
    'expires_at', now() + make_interval(mins => v_cfg.slot_duration_minutes),
    'territory_reserved', v_territory_owner IS NOT NULL
      AND v_slot.slot_number <= v_cfg.territory_reserve_slot_count,
    'message', 'Slot alındı! Bonus farm başladı.'
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.add_territory_defense_gold(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_territory_attack_preview(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_territory_detail(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_war_territories() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_siege_slot(text) TO authenticated;

COMMIT;
