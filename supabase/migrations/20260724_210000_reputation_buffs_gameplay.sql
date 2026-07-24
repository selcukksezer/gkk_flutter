-- Reputation shop buffs → enter_dungeon gameplay, activity log hooks, cosmetic title.
BEGIN;

-- Optional profile title from shop (Onur Nişanı).
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS cosmetic_title text;

-- ── Buff helpers ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._cleanup_expired_reputation_buffs(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  DELETE FROM public.player_reputation_buffs
  WHERE user_id = p_user_id AND expires_at <= now();
END;
$$;

REVOKE ALL ON FUNCTION public._cleanup_expired_reputation_buffs(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public._reputation_buff_pct(p_user_id uuid, p_buff_key text)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pct numeric := 0;
BEGIN
  IF p_user_id IS NULL OR p_buff_key IS NULL OR btrim(p_buff_key) = '' THEN
    RETURN 0;
  END IF;

  SELECT COALESCE(SUM(buff_value), 0) INTO v_pct
  FROM public.player_reputation_buffs
  WHERE user_id = p_user_id
    AND buff_key = p_buff_key
    AND expires_at > now();

  RETURN COALESCE(v_pct, 0);
END;
$$;

REVOKE ALL ON FUNCTION public._reputation_buff_pct(uuid, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public._reputation_buffs_snapshot(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'buff_key', prb.buff_key,
      'buff_value', prb.buff_value,
      'expires_at', prb.expires_at
    ) ORDER BY prb.expires_at DESC)
    FROM public.player_reputation_buffs prb
    WHERE prb.user_id = p_user_id AND prb.expires_at > now()
  ), '[]'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public._reputation_buffs_snapshot(uuid)
  FROM PUBLIC, anon, authenticated;

-- ── Quest rep reward column + claim hook ─────────────────────────────────────
ALTER TABLE public.quests
  ADD COLUMN IF NOT EXISTS rep_reward integer NOT NULL DEFAULT 0;

UPDATE public.quests SET rep_reward = CASE quest_id
  WHEN 'q_first_step' THEN 50
  WHEN 'q_dungeon_runner' THEN 100
  WHEN 'q_pvp_fighter' THEN 120
  WHEN 'q_craft_master' THEN 80
  WHEN 'q_treasure_hunter' THEN 150
  WHEN 'q_elite_slayer' THEN 200
  ELSE rep_reward
END
WHERE rep_reward = 0;

CREATE OR REPLACE FUNCTION public.claim_quest_reward(p_quest_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_status text;
  v_gold integer;
  v_xp integer;
  v_gem integer;
  v_rep integer := 0;
BEGIN
  SELECT status INTO v_status
  FROM public.player_quests
  WHERE user_id = v_user_id AND quest_id = p_quest_id;

  IF NOT FOUND OR v_status != 'completed' THEN
    RAISE EXCEPTION 'Ödül alınabilir durumda değil.';
  END IF;

  SELECT gold_reward, xp_reward, gem_reward, COALESCE(rep_reward, 0)
  INTO v_gold, v_xp, v_gem, v_rep
  FROM public.quests WHERE quest_id = p_quest_id;

  UPDATE public.users
  SET gold = gold + v_gold,
      xp = xp + v_xp,
      gems = gems + v_gem,
      reputation = COALESCE(reputation, 0) + v_rep
  WHERE auth_id = v_user_id;

  IF v_rep > 0 THEN
    PERFORM public._log_reputation_activity(
      v_user_id, 'earn', 'quest', v_rep, 'global', NULL,
      jsonb_build_object('quest_id', p_quest_id)
    );
  END IF;

  UPDATE public.player_quests
  SET status = 'claimed'
  WHERE user_id = v_user_id AND quest_id = p_quest_id;
END;
$$;

-- ── Cosmetic title purchase + activity on spend already in 200000 ──────────────
CREATE OR REPLACE FUNCTION public.purchase_reputation_item(
  p_item_id text,
  p_faction_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_item record;
  v_global_rep integer;
  v_faction_rep integer;
  v_energy_gain integer := 20;
  v_duration interval;
  v_buff_value numeric;
  v_title_key text;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_item
  FROM public.reputation_shop_catalog
  WHERE id = p_item_id AND is_active;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ürün bulunamadı');
  END IF;

  IF v_item.cost_type = 'faction' THEN
    IF p_faction_id IS NULL OR p_faction_id NOT IN (
      'tuccarlar', 'zanaatkarlar', 'maceracilar', 'muhafizlar', 'suc_orgutu'
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Fraksiyon seçmelisin');
    END IF;

    INSERT INTO public.player_faction_reputation (user_id, faction_id, reputation)
    VALUES (v_me, p_faction_id, 0)
    ON CONFLICT (user_id, faction_id) DO NOTHING;

    SELECT reputation INTO v_faction_rep
    FROM public.player_faction_reputation
    WHERE user_id = v_me AND faction_id = p_faction_id
    FOR UPDATE;

    IF COALESCE(v_faction_rep, 0) < v_item.cost_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz fraksiyon itibarı');
    END IF;

    UPDATE public.player_faction_reputation
    SET reputation = reputation - v_item.cost_amount, updated_at = now()
    WHERE user_id = v_me AND faction_id = p_faction_id;

    PERFORM public._log_reputation_activity(
      v_me, 'spend', 'shop:' || p_item_id, v_item.cost_amount, 'faction', p_faction_id,
      jsonb_build_object('item_id', p_item_id, 'effect_key', v_item.effect_key)
    );
  ELSE
    SELECT COALESCE(reputation, 0) INTO v_global_rep
    FROM public.users WHERE auth_id = v_me FOR UPDATE;

    IF COALESCE(v_global_rep, 0) < v_item.cost_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz itibar');
    END IF;

    UPDATE public.users
    SET reputation = GREATEST(0, COALESCE(reputation, 0) - v_item.cost_amount)
    WHERE auth_id = v_me;

    PERFORM public._log_reputation_activity(
      v_me, 'spend', 'shop:' || p_item_id, v_item.cost_amount, 'global', NULL,
      jsonb_build_object('item_id', p_item_id, 'effect_key', v_item.effect_key)
    );
  END IF;

  IF v_item.effect_key = 'energy_refill' THEN
    v_energy_gain := COALESCE((v_item.effect_value->>'energy_gain')::integer, 20);
    UPDATE public.users
    SET energy = LEAST(COALESCE(max_energy, 100), COALESCE(energy, 0) + v_energy_gain)
    WHERE auth_id = v_me;
    RETURN jsonb_build_object(
      'success', true,
      'item_id', p_item_id,
      'effect', 'energy_refill',
      'energy_gain', v_energy_gain
    );
  ELSIF v_item.effect_key IN ('gold_boost', 'drop_boost', 'siege_rep_boost') THEN
    v_duration := make_interval(mins => COALESCE(v_item.duration_minutes, 30));
    v_buff_value := COALESCE((v_item.effect_value->>'pct')::numeric, 0);
    INSERT INTO public.player_reputation_buffs (user_id, buff_key, buff_value, expires_at)
    VALUES (v_me, v_item.effect_key, v_buff_value, now() + v_duration);
    RETURN jsonb_build_object(
      'success', true,
      'item_id', p_item_id,
      'effect', v_item.effect_key,
      'buff_value', v_buff_value,
      'expires_at', (now() + v_duration)
    );
  ELSIF v_item.effect_key = 'cosmetic_title' THEN
    v_title_key := COALESCE(v_item.effect_value->>'title_key', 'onur_nisani');
    UPDATE public.users SET cosmetic_title = v_title_key WHERE auth_id = v_me;
    RETURN jsonb_build_object(
      'success', true,
      'item_id', p_item_id,
      'effect', 'cosmetic_title',
      'title_key', v_title_key,
      'message', 'Onur Nişanı profiline kaydedildi.'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'item_id', p_item_id);
END;
$$;

-- ── Siege result metadata: include shop morale buff ────────────────────────────
CREATE OR REPLACE FUNCTION public.dungeon_siege_run_bonus_for_result(
  p_player_id uuid,
  p_dungeon_id text,
  p_success boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cfg public.dungeon_siege_config;
  v_siege jsonb;
  v_loot_pct integer;
  v_gold_pct integer;
  v_slot_loot_pct integer;
  v_slot_gold_pct integer;
  v_hold_pct integer := 0;
  v_rep integer := 0;
  v_rep_base numeric;
  v_morale_pct numeric := 0;
BEGIN
  IF p_player_id IS NULL OR p_dungeon_id IS NULL OR btrim(p_dungeon_id) = '' THEN
    RETURN jsonb_build_object('active', false);
  END IF;

  IF NOT public.dungeon_siege_is_active_for_dungeon(p_dungeon_id) THEN
    RETURN jsonb_build_object(
      'active', false,
      'prime_active', false,
      'has_slot', false,
      'applied', false
    );
  END IF;

  v_cfg := public.dungeon_siege_get_config();
  v_siege := public.dungeon_siege_reward_multipliers(p_player_id, p_dungeon_id);
  v_morale_pct := public._reputation_buff_pct(p_player_id, 'siege_rep_boost');

  IF NOT COALESCE((v_siege->>'has_slot')::boolean, false) THEN
    RETURN jsonb_build_object(
      'active', true,
      'prime_active', true,
      'has_slot', false,
      'applied', false,
      'slot_loot_bonus_pct', round(COALESCE(v_cfg.loot_bonus_pct, 0) * 100),
      'slot_gold_bonus_pct', round(COALESCE(v_cfg.gold_bonus_pct, 0) * 100),
      'hold_bonus_pct', round(COALESCE(v_cfg.hold_bonus_pct, 0) * 100),
      'siege_morale_pct', v_morale_pct
    );
  END IF;

  v_loot_pct := round((COALESCE((v_siege->>'loot_mult')::numeric, 1) - 1) * 100);
  v_gold_pct := round((COALESCE((v_siege->>'gold_mult')::numeric, 1) - 1) * 100);
  v_slot_loot_pct := round(COALESCE(v_cfg.loot_bonus_pct, 0) * 100);
  v_slot_gold_pct := round(COALESCE(v_cfg.gold_bonus_pct, 0) * 100);

  IF COALESCE((v_siege->>'has_hold_bonus')::boolean, false) THEN
    v_hold_pct := round(COALESCE(v_cfg.hold_bonus_pct, 0) * 100);
  END IF;

  IF p_success THEN
    v_rep_base := COALESCE((v_siege->>'rep_bonus_pct')::numeric, COALESCE(v_cfg.rep_bonus_pct, 0.15));
    v_rep := GREATEST(1, floor(20 * v_rep_base * (1 + v_morale_pct / 100.0)));
  END IF;

  RETURN jsonb_build_object(
    'active', true,
    'prime_active', true,
    'has_slot', true,
    'applied', p_success,
    'has_hold_bonus', COALESCE((v_siege->>'has_hold_bonus')::boolean, false),
    'loot_bonus_pct', v_loot_pct,
    'gold_bonus_pct', v_gold_pct,
    'slot_loot_bonus_pct', v_slot_loot_pct,
    'slot_gold_bonus_pct', v_slot_gold_pct,
    'hold_bonus_pct', v_hold_pct,
    'rep_gained', v_rep,
    'siege_morale_pct', v_morale_pct,
    'loot_mult', COALESCE((v_siege->>'loot_mult')::numeric, 1),
    'gold_mult', COALESCE((v_siege->>'gold_mult')::numeric, 1)
  );
END;
$$;

-- ── Guild war attack: grant rep + log ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.attack_guild_war_territory(
  p_territory_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_guild_id uuid;
  v_territory record;
  v_attack_power integer;
  v_effective_defense integer;
  v_success boolean;
  v_points_gained integer;
  v_active_season_id uuid;
  v_rep_gain integer := 0;
BEGIN
  SELECT guild_id INTO v_guild_id
  FROM public.users
  WHERE auth_id = v_player_id;

  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT * INTO v_territory
  FROM public.guild_war_territories
  WHERE id = p_territory_id;

  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  SELECT COALESCE(level * 50, 100) INTO v_attack_power
  FROM public.users WHERE auth_id = v_player_id;

  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power,
    v_territory.gem_defense_boost
  );

  v_success := (random() * v_attack_power) > (random() * GREATEST(v_effective_defense, 1));
  v_points_gained := CASE WHEN v_success THEN 100 ELSE 10 END;
  v_rep_gain := CASE WHEN v_success THEN 20 ELSE 5 END;

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
    ON CONFLICT (season_id, guild_id)
    DO UPDATE SET
      points = guild_war_rankings.points + v_points_gained,
      wins = guild_war_rankings.wins + (CASE WHEN v_success THEN 1 ELSE 0 END),
      losses = guild_war_rankings.losses + (CASE WHEN v_success THEN 0 ELSE 1 END),
      updated_at = now();
  END IF;

  IF v_success THEN
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
      'points_gained', v_points_gained
    )
  );

  INSERT INTO public.guild_war_attack_logs (
    territory_id,
    attacker_guild_id,
    defender_guild_id,
    attack_power,
    defense_power,
    success,
    points_gained
  ) VALUES (
    p_territory_id,
    v_guild_id,
    v_territory.owner_guild_id,
    v_attack_power,
    v_effective_defense,
    v_success,
    v_points_gained
  );

  RETURN json_build_object(
    'success', v_success,
    'message', CASE WHEN v_success THEN 'Bölge ele geçirildi!' ELSE 'Saldırı başarısız!' END,
    'attack_power', v_attack_power,
    'defense_power', v_effective_defense,
    'points_gained', v_points_gained,
    'rep_gained', v_rep_gain
  );
END;
$$;

-- ── Patch enter_dungeon: shop buffs + siege rep logging ────────────────────────
DO $patch$
DECLARE
  v_def text;
  v_declare_anchor text := E'  v_siege             JSONB;';
  v_declare_new text := E'  v_siege             JSONB;\n  v_rep_gold_pct      NUMERIC := 0;\n  v_rep_loot_pct      NUMERIC := 0;\n  v_rep_buffs         JSONB := ''[]''::JSONB;\n  v_siege_rep_gain    INTEGER := 0;\n  v_siege_rep_buff    NUMERIC := 0;';
  v_rep_buff_marker text := E'    -- [GKK_SIEGE_BONUS_END]\n';
  v_rep_buff_block text := E'    -- [GKK_SIEGE_BONUS_END]\n\n    -- [GKK_REP_BUFF_BEGIN]\n    PERFORM public._cleanup_expired_reputation_buffs(p_player_id);\n    v_rep_gold_pct := public._reputation_buff_pct(p_player_id, ''gold_boost'');\n    v_rep_loot_pct := public._reputation_buff_pct(p_player_id, ''drop_boost'');\n    IF v_rep_gold_pct > 0 THEN\n      v_gold := floor(v_gold * (1 + v_rep_gold_pct / 100.0));\n    END IF;\n    IF v_rep_loot_pct > 0 THEN\n      v_effective_equipment_drop := LEAST(0.95, v_effective_equipment_drop * (1 + v_rep_loot_pct / 100.0));\n      v_effective_resource_drop  := LEAST(0.95, v_effective_resource_drop  * (1 + v_rep_loot_pct / 100.0));\n      v_effective_scroll_drop    := LEAST(0.95, v_effective_scroll_drop    * (1 + v_rep_loot_pct / 100.0));\n    END IF;\n    v_rep_buffs := public._reputation_buffs_snapshot(p_player_id);\n    -- [GKK_REP_BUFF_END]\n';
  v_fallback_marker text := E'    v_effective_scroll_drop    := LEAST(0.95, GREATEST(0, v_effective_scroll_drop    * v_reward_mult));\n';
  v_fallback_block text := E'    v_effective_scroll_drop    := LEAST(0.95, GREATEST(0, v_effective_scroll_drop    * v_reward_mult));\n\n    -- [GKK_REP_BUFF_BEGIN]\n    PERFORM public._cleanup_expired_reputation_buffs(p_player_id);\n    v_rep_gold_pct := public._reputation_buff_pct(p_player_id, ''gold_boost'');\n    v_rep_loot_pct := public._reputation_buff_pct(p_player_id, ''drop_boost'');\n    IF v_rep_gold_pct > 0 THEN\n      v_gold := floor(v_gold * (1 + v_rep_gold_pct / 100.0));\n    END IF;\n    IF v_rep_loot_pct > 0 THEN\n      v_effective_equipment_drop := LEAST(0.95, v_effective_equipment_drop * (1 + v_rep_loot_pct / 100.0));\n      v_effective_resource_drop  := LEAST(0.95, v_effective_resource_drop  * (1 + v_rep_loot_pct / 100.0));\n      v_effective_scroll_drop    := LEAST(0.95, v_effective_scroll_drop    * (1 + v_rep_loot_pct / 100.0));\n    END IF;\n    v_rep_buffs := public._reputation_buffs_snapshot(p_player_id);\n    -- [GKK_REP_BUFF_END]\n';
  v_old_siege_rep text := E'  -- [GKK_SIEGE_REP_BEGIN]\n  IF v_success AND public.dungeon_siege_is_enabled() THEN\n    v_siege := public.dungeon_siege_reward_multipliers(p_player_id, p_dungeon_id);\n    IF COALESCE((v_siege->>''has_slot'')::boolean, false) THEN\n      UPDATE public.users\n      SET reputation = COALESCE(reputation, 0)\n        + GREATEST(1, floor(20 * COALESCE((v_siege->>''rep_bonus_pct'')::numeric, 0.15)))\n      WHERE auth_id = p_player_id;\n    END IF;\n  END IF;\n  -- [GKK_SIEGE_REP_END]\n';
  v_new_siege_rep text := E'  -- [GKK_SIEGE_REP_BEGIN]\n  IF v_success AND public.dungeon_siege_is_enabled() THEN\n    v_siege := public.dungeon_siege_reward_multipliers(p_player_id, p_dungeon_id);\n    IF COALESCE((v_siege->>''has_slot'')::boolean, false) THEN\n      v_siege_rep_buff := public._reputation_buff_pct(p_player_id, ''siege_rep_boost'');\n      v_siege_rep_gain := GREATEST(\n        1,\n        floor(\n          20 * COALESCE((v_siege->>''rep_bonus_pct'')::numeric, 0.15)\n          * (1 + v_siege_rep_buff / 100.0)\n        )\n      );\n      UPDATE public.users\n      SET reputation = COALESCE(reputation, 0) + v_siege_rep_gain\n      WHERE auth_id = p_player_id;\n      PERFORM public._log_reputation_activity(\n        p_player_id, ''earn'', ''siege'', v_siege_rep_gain, ''global'', NULL,\n        jsonb_build_object(\n          ''dungeon_id'', p_dungeon_id,\n          ''siege_morale_pct'', v_siege_rep_buff\n        )\n      );\n    END IF;\n  END IF;\n  -- [GKK_SIEGE_REP_END]\n';
  v_return_marker text := E'    ''milestone_rewards'',  v_milestone_rewards,\n';
  v_return_block text := E'    ''milestone_rewards'',  v_milestone_rewards,\n    ''reputation_buffs'',   COALESCE(v_rep_buffs, ''[]''::jsonb),\n';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'enter_dungeon'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon not found for reputation buff patch';
  END IF;

  IF position('v_rep_gold_pct' in v_def) = 0 THEN
    IF position(v_declare_anchor in v_def) > 0 THEN
      v_def := replace(v_def, v_declare_anchor, v_declare_new);
    ELSIF position('v_milestone_rewards JSONB' in v_def) > 0 THEN
      v_def := replace(
        v_def,
        E'  v_milestone_rewards JSONB := ''[]''::JSONB;',
        E'  v_milestone_rewards JSONB := ''[]''::JSONB;\n  v_rep_gold_pct      NUMERIC := 0;\n  v_rep_loot_pct      NUMERIC := 0;\n  v_rep_buffs         JSONB := ''[]''::JSONB;\n  v_siege_rep_gain    INTEGER := 0;\n  v_siege_rep_buff    NUMERIC := 0;'
      );
    END IF;
  END IF;

  IF position('[GKK_REP_BUFF_BEGIN]' in v_def) = 0 THEN
    IF position(v_rep_buff_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_rep_buff_marker, v_rep_buff_block);
    ELSIF position(v_fallback_marker in v_def) > 0 THEN
      v_def := replace(v_def, v_fallback_marker, v_fallback_block);
    ELSE
      RAISE EXCEPTION 'enter_dungeon rep buff patch marker not found';
    END IF;
  END IF;

  IF position(v_old_siege_rep in v_def) > 0 THEN
    v_def := replace(v_def, v_old_siege_rep, v_new_siege_rep);
  ELSIF position('[GKK_SIEGE_REP_BEGIN]' in v_def) = 0 THEN
    RAISE NOTICE 'enter_dungeon missing siege rep block; skipping siege rep upgrade';
  END IF;

  IF position('''reputation_buffs''' in v_def) = 0 AND position(v_return_marker in v_def) > 0 THEN
    v_def := replace(v_def, v_return_marker, v_return_block);
  END IF;

  EXECUTE v_def;
END;
$patch$;

-- ── attack_dungeon_rl_inner: pass reputation_buffs ─────────────────────────────
CREATE OR REPLACE FUNCTION public.attack_dungeon_rl_inner(p_dungeon_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_result           JSONB;
  v_items_raw        JSONB;
  v_hospital_until   TIMESTAMPTZ;
  v_hospital_secs    INTEGER := 0;
  v_player_id        UUID;
  v_run_count        INTEGER;
  v_dungeon_num      INTEGER;
  v_item             RECORD;
  v_qty              INTEGER;
  v_success          BOOLEAN;
BEGIN
  v_player_id := auth.uid();
  v_result := public.enter_dungeon(v_player_id, p_dungeon_id);

  IF v_result ? 'error' THEN
    RETURN v_result;
  END IF;

  v_success := COALESCE((v_result->>'success')::BOOLEAN, false);
  v_items_raw := COALESCE(v_result->'items', '[]'::JSONB);

  IF v_success THEN
    v_dungeon_num := COALESCE(NULLIF(regexp_replace(p_dungeon_id, '\D', '', 'g'), '')::INTEGER, 0);

    SELECT COUNT(*) INTO v_run_count
    FROM public.dungeon_runs
    WHERE player_id = v_player_id;

    IF v_run_count <= 1 THEN
      SELECT id, name, type INTO v_item
      FROM public.items
      WHERE lower(rarity) = 'common'
        AND lower(type) IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY random()
      LIMIT 1;

      IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', v_item.id, 'name', v_item.name,
          'rarity', 'common', 'type', v_item.type, 'quantity', 1
        );
      END IF;

      IF public.dungeon_add_item(v_player_id, 'scroll_upgrade_low', 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', 'scroll_upgrade_low', 'name', 'Lesser Upgrade Scroll',
          'rarity', 'common', 'type', 'scroll', 'quantity', 1
        );
      END IF;
    END IF;

    IF v_dungeon_num BETWEEN 1 AND 10 AND random() < 0.40 THEN
      SELECT i.id, i.name, i.type INTO v_item
      FROM public.items i
      WHERE lower(i.rarity) = 'common'
        AND lower(i.type) IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY
        (EXISTS (
          SELECT 1 FROM public.inventory inv
          JOIN public.items it ON it.id = inv.item_id
          WHERE inv.user_id = v_player_id
            AND lower(it.type) = lower(i.type)
        )) ASC,
        (EXISTS (
          SELECT 1 FROM public.inventory inv
          WHERE inv.user_id = v_player_id AND inv.item_id = i.id
        )) ASC,
        random()
      LIMIT 1;

      IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', v_item.id, 'name', v_item.name,
          'rarity', 'common', 'type', v_item.type, 'quantity', 1
        );
      END IF;
    END IF;

    v_qty := 5 + floor(random() * 11)::INTEGER;

    SELECT id, name, type INTO v_item
    FROM public.items
    WHERE lower(rarity) = 'common'
      AND lower(type) = 'material'
      AND COALESCE(is_stackable, false)
    ORDER BY COALESCE(base_price, 0) ASC, random()
    LIMIT 1;

    IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, v_qty) THEN
      v_items_raw := v_items_raw || jsonb_build_object(
        'item_id', v_item.id, 'name', v_item.name,
        'rarity', 'common', 'type', v_item.type, 'quantity', v_qty
      );
    END IF;
  END IF;

  IF (v_result->>'hospital_until') IS NOT NULL THEN
    BEGIN
      v_hospital_until := (v_result->>'hospital_until')::TIMESTAMPTZ;
      v_hospital_secs  := GREATEST(0, EXTRACT(EPOCH FROM (v_hospital_until - now()))::INTEGER);
    EXCEPTION WHEN OTHERS THEN
      v_hospital_secs := 0;
    END;
  END IF;

  RETURN jsonb_build_object(
    'success',             v_success,
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
    'milestone_rewards',   COALESCE(v_result->'milestone_rewards', '[]'::jsonb),
    'reputation_buffs',    COALESCE(v_result->'reputation_buffs', '[]'::jsonb),
    'siege_bonus',         public.dungeon_siege_run_bonus_for_result(v_player_id, p_dungeon_id, v_success)
  );
END;
$$;

-- ── PvP reputation activity logging (patch latest pvp_attack body) ─────────────
DO $pvp_patch$
DECLARE
  v_def text;
  v_old text := E'  IF v_winner_id = p_attacker_id THEN\n    UPDATE public.users SET reputation = reputation + v_rep_change_winner WHERE auth_id = p_attacker_id;\n    UPDATE public.users SET reputation = reputation + v_rep_change_loser WHERE auth_id = p_defender_id;\n  ELSE\n    UPDATE public.users SET reputation = reputation + 2 WHERE auth_id = p_defender_id;\n    UPDATE public.users SET reputation = reputation - 2 WHERE auth_id = p_attacker_id;\n  END IF;\n';
  v_new text := E'  IF v_winner_id = p_attacker_id THEN\n    UPDATE public.users SET reputation = reputation + v_rep_change_winner WHERE auth_id = p_attacker_id;\n    UPDATE public.users SET reputation = reputation + v_rep_change_loser WHERE auth_id = p_defender_id;\n    IF v_rep_change_winner > 0 THEN\n      PERFORM public._log_reputation_activity(\n        p_attacker_id, ''earn'', ''pvp'', v_rep_change_winner, ''global'', NULL,\n        jsonb_build_object(''role'', ''winner'', ''opponent_id'', p_defender_id)\n      );\n    END IF;\n    IF v_rep_change_loser < 0 THEN\n      PERFORM public._log_reputation_activity(\n        p_defender_id, ''spend'', ''pvp'', abs(v_rep_change_loser), ''global'', NULL,\n        jsonb_build_object(''role'', ''loser'', ''opponent_id'', p_attacker_id)\n      );\n    END IF;\n  ELSE\n    UPDATE public.users SET reputation = reputation + 2 WHERE auth_id = p_defender_id;\n    UPDATE public.users SET reputation = reputation - 2 WHERE auth_id = p_attacker_id;\n    PERFORM public._log_reputation_activity(\n      p_defender_id, ''earn'', ''pvp'', 2, ''global'', NULL,\n      jsonb_build_object(''role'', ''winner'', ''opponent_id'', p_attacker_id)\n    );\n    PERFORM public._log_reputation_activity(\n      p_attacker_id, ''spend'', ''pvp'', 2, ''global'', NULL,\n      jsonb_build_object(''role'', ''loser'', ''opponent_id'', p_defender_id)\n    );\n  END IF;\n';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'pvp_attack'
  ORDER BY p.oid DESC
  LIMIT 1;

  IF v_def IS NULL THEN
    RAISE NOTICE 'pvp_attack not found; skipping rep activity patch';
    RETURN;
  END IF;

  IF position('_log_reputation_activity' in v_def) > 0 THEN
    RETURN;
  END IF;

  IF position(v_old in v_def) = 0 THEN
    RAISE NOTICE 'pvp_attack rep block marker not found; skipping';
    RETURN;
  END IF;

  v_def := replace(v_def, v_old, v_new);
  EXECUTE v_def;
END;
$pvp_patch$;

COMMIT;
