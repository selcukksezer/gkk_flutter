-- Faz B/C/D: conquest base_def, line→combat, min gems, curated loot,
-- vault 40% cap + officer collect + weekly payout + target resolve.

BEGIN;

-- ── B: Garrison recompute keeps base when empty ─────────────────────────────
CREATE OR REPLACE FUNCTION public._guild_war_recompute_defense(p_territory_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sum INTEGER := 0;
  v_base INTEGER := 0;
  v_final INTEGER;
BEGIN
  SELECT COALESCE(SUM(GREATEST(COALESCE(u.power, 0), 0)), 0)::INTEGER
  INTO v_sum
  FROM public.guild_war_garrison g
  JOIN public.users u ON u.auth_id = g.user_id
  WHERE g.territory_id = p_territory_id
    AND u.guild_id = g.guild_id;

  SELECT COALESCE(base_defense_power, 0) INTO v_base
  FROM public.guild_war_territories WHERE id = p_territory_id;

  v_final := CASE WHEN v_sum > 0 THEN v_sum ELSE GREATEST(v_base, 0) END;

  UPDATE public.guild_war_territories
  SET defense_power = v_final
  WHERE id = p_territory_id;

  RETURN v_final;
END;
$$;

CREATE OR REPLACE FUNCTION public._guild_war_clear_garrison(p_territory_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_base INTEGER := 0;
BEGIN
  DELETE FROM public.guild_war_garrison WHERE territory_id = p_territory_id;
  SELECT COALESCE(base_defense_power, 0) INTO v_base
  FROM public.guild_war_territories WHERE id = p_territory_id;
  UPDATE public.guild_war_territories
  SET defense_power = GREATEST(v_base, 0)
  WHERE id = p_territory_id;
END;
$$;

-- ── D: defense_line_level → combat ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.guild_war_territory_effective_defense(integer, integer);
CREATE OR REPLACE FUNCTION public.guild_war_territory_effective_defense(
  p_defense_power integer,
  p_gem_defense_boost integer,
  p_defense_line_level integer DEFAULT 0
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT GREATEST(COALESCE(p_defense_power, 0), 0)
       + GREATEST(COALESCE(p_gem_defense_boost, 0), 0)
       + (GREATEST(COALESCE(p_defense_line_level, 0), 0) * 200);
$$;

-- Patch attack conquest: base starter (garrison clear already sets base)
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
  IF v_combat IS NOT NULL THEN RETURN v_combat::json; END IF;
  v_combat := public.assert_player_pvp_health(v_player_id);
  IF v_combat IS NOT NULL THEN RETURN v_combat::json; END IF;

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
    v_garrison_def := COALESCE(v_territory.base_defense_power, v_territory.defense_power, 0);
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
    v_territory.gem_defense_boost,
    v_territory.defense_line_level
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
        defense_power = COALESCE(base_defense_power, 1000),
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

-- ── D: min_defense_gems enforce ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.add_territory_defense(
  p_territory_id uuid,
  p_gems integer
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
  v_player_gems integer;
  v_defense_increase integer;
  v_effective_defense integer;
  v_garrison INTEGER;
  v_min INTEGER;
BEGIN
  IF p_gems IS NULL OR p_gems <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'Geçersiz elmas miktarı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_player_id;
  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;

  IF v_territory.owner_guild_id IS DISTINCT FROM v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Sadece sahip lonca üyeleri savunma ekleyebilir.');
  END IF;

  v_min := COALESCE(v_territory.min_defense_gems, 5);
  IF p_gems < v_min THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Minimum ' || v_min || ' elmas gerekli.',
      'min_defense_gems', v_min
    );
  END IF;

  SELECT FLOOR(COALESCE(gems, 0))::INTEGER INTO v_player_gems
  FROM public.users WHERE auth_id = v_player_id FOR UPDATE;

  IF COALESCE(v_player_gems, 0) < p_gems THEN
    RETURN json_build_object('success', false, 'error', 'Yetersiz elmas.');
  END IF;

  v_defense_increase := p_gems * 10;

  UPDATE public.users SET gems = gems - p_gems WHERE auth_id = v_player_id;
  UPDATE public.guild_war_territories
  SET gem_defense_boost = gem_defense_boost + v_defense_increase,
      updated_at = updated_at
  WHERE id = p_territory_id;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;
  v_garrison := public._guild_war_recompute_defense(p_territory_id);
  v_effective_defense := public.guild_war_territory_effective_defense(
    v_garrison, v_territory.gem_defense_boost, v_territory.defense_line_level
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Elmas savunma eklendi.',
    'gems_spent', p_gems,
    'defense_increase', v_defense_increase,
    'gem_defense_boost', v_territory.gem_defense_boost,
    'effective_defense', v_effective_defense,
    'defense_power', v_garrison
  );
END;
$$;

-- ── D: curated loot (no junk / cosmetic / name-change) ──────────────────────
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
    AND COALESCE(i.cosmetic_showcase_only, false) = false
    AND COALESCE(i.cosmetic_bind_on_pickup, false) = false
    AND lower(COALESCE(i.type, '')) NOT IN ('cosmetic', 'consumable_name', 'name_change')
    AND lower(COALESCE(i.id, '')) NOT LIKE '%name_change%'
    AND lower(COALESCE(i.id, '')) NOT LIKE '%rename%'
    AND lower(COALESCE(i.id, '')) NOT LIKE '%junk%'
    AND lower(COALESCE(i.id, '')) NOT LIKE '%test_%'
    AND lower(COALESCE(i.name, '')) NOT LIKE '%isim değiştir%'
    AND lower(COALESCE(i.name, '')) NOT LIKE '%junk%'
    AND lower(COALESCE(i.name, '')) NOT LIKE '%test item%'
    AND (i.equip_slot IS NOT NULL OR i.weapon_type IS NOT NULL OR i.armor_type IS NOT NULL
         OR lower(COALESCE(i.type, '')) IN ('material', 'MATERIAL', 'potion', 'POTION', 'rune', 'RUNE', 'box', 'BOX', 'weapon', 'WEAPON', 'armor', 'ARMOR'))
  ORDER BY random()
  LIMIT 1;

  IF v_item_id IS NULL THEN
    SELECT i.id INTO v_item_id
    FROM public.items i
    WHERE lower(COALESCE(i.rarity, '')) NOT IN ('common', '')
      AND COALESCE(i.cosmetic_showcase_only, false) = false
      AND lower(COALESCE(i.id, '')) NOT LIKE '%name_change%'
      AND lower(COALESCE(i.id, '')) NOT LIKE '%junk%'
      AND lower(COALESCE(i.name, '')) NOT LIKE '%isim değiştir%'
    ORDER BY random()
    LIMIT 1;
  END IF;

  RETURN v_item_id;
END;
$$;

-- ── C: guild weekly payout flag ─────────────────────────────────────────────
ALTER TABLE public.guilds
  ADD COLUMN IF NOT EXISTS vault_auto_payout_weekly BOOLEAN NOT NULL DEFAULT false;

-- Resolve member target: auth_id OR users.id
CREATE OR REPLACE FUNCTION public._guild_vault_resolve_member(
  p_guild_id UUID,
  p_target UUID
)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.auth_id
  FROM public.users u
  WHERE u.guild_id = p_guild_id
    AND (u.auth_id = p_target OR u.id = p_target)
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public._guild_vault_grant_item(
  p_auth_id UUID,
  p_item_id TEXT,
  p_qty INTEGER,
  p_enhancement INTEGER DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_stackable BOOLEAN;
  v_max_stack INTEGER;
  v_qty INTEGER := GREATEST(p_qty, 1);
  v_row RECORD;
  v_space INTEGER;
  v_add INTEGER;
BEGIN
  IF p_auth_id IS NULL OR p_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef/eşya eksik.');
  END IF;

  SELECT COALESCE(is_stackable, false), COALESCE(max_stack, 999999)
  INTO v_stackable, v_max_stack
  FROM public.items WHERE id = p_item_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya kataloğunda yok.');
  END IF;

  IF v_stackable AND COALESCE(p_enhancement, 0) = 0 THEN
    FOR v_row IN
      SELECT row_id, quantity FROM public.inventory
      WHERE user_id = p_auth_id AND item_id = p_item_id AND COALESCE(is_equipped, false) = false
        AND COALESCE(enhancement_level, 0) = 0
      ORDER BY created_at ASC
    LOOP
      EXIT WHEN v_qty <= 0;
      v_space := GREATEST(v_max_stack - v_row.quantity, 0);
      IF v_space > 0 THEN
        v_add := LEAST(v_space, v_qty);
        UPDATE public.inventory SET quantity = quantity + v_add, updated_at = now()
        WHERE row_id = v_row.row_id;
        v_qty := v_qty - v_add;
      END IF;
    END LOOP;
  END IF;

  WHILE v_qty > 0 LOOP
    v_add := CASE WHEN v_stackable THEN LEAST(v_qty, v_max_stack) ELSE 1 END;
    INSERT INTO public.inventory (user_id, item_id, quantity, enhancement_level, obtained_at, created_at, updated_at)
    VALUES (p_auth_id, p_item_id, v_add, COALESCE(p_enhancement, 0), now(), now(), now());
    v_qty := v_qty - v_add;
  END LOOP;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Collect: leader OR officer
CREATE OR REPLACE FUNCTION public.collect_guild_vault_rewards()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_guild RECORD;
  v_role TEXT;
  v_amount BIGINT;
  v_ok BOOLEAN := false;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT u.guild_id, COALESCE(u.guild_role, 'member')
  INTO v_guild_id, v_role
  FROM public.users u WHERE u.auth_id = v_user;

  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_guild_id FOR UPDATE;
  v_ok := (v_guild.leader_id = v_user) OR (v_role IN ('officer', 'commander'));
  IF NOT v_ok THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lider veya officer toplayabilir.');
  END IF;

  PERFORM public._accrue_guild_vault(v_guild_id);
  SELECT vault_gold_pending INTO v_amount FROM public.guilds WHERE id = v_guild_id;

  IF COALESCE(v_amount, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Toplanacak gelir yok.');
  END IF;

  UPDATE public.guilds
  SET vault_gold = vault_gold + v_amount,
      vault_gold_pending = 0
  WHERE id = v_guild_id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (v_guild_id, v_user, 'collect', jsonb_build_object('amount', v_amount, 'by_role', v_role));

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Gelir lonca kasasına aktarıldı.',
    'collected', v_amount,
    'vault_gold', (SELECT vault_gold FROM public.guilds WHERE id = v_guild_id)
  );
END;
$$;

-- Distribute gold: leader only + 40% cap + resolve target
CREATE OR REPLACE FUNCTION public.distribute_guild_vault_gold(p_payload JSONB)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_guild RECORD;
  v_mode TEXT;
  v_total BIGINT;
  v_member_count INTEGER;
  v_per_member BIGINT;
  v_entry JSONB;
  v_target UUID;
  v_resolved UUID;
  v_amount BIGINT;
  v_spent BIGINT := 0;
  v_cap BIGINT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_guild_id FOR UPDATE;
  IF v_guild.leader_id IS DISTINCT FROM v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lonca lideri dağıtabilir.');
  END IF;

  v_mode := COALESCE(p_payload->>'mode', 'equal');
  v_total := COALESCE((p_payload->>'amount')::BIGINT, 0);

  IF v_total <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçerli miktar girin.');
  END IF;

  IF COALESCE(v_guild.vault_gold, 0) < v_total THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca kasasında yeterli altın yok.');
  END IF;

  IF v_mode = 'equal' THEN
    SELECT COUNT(*) INTO v_member_count FROM public.users WHERE guild_id = v_guild_id;
    IF v_member_count <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Loncada üye yok.');
    END IF;
    v_per_member := v_total / v_member_count;
    IF v_per_member <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Pay çok küçük.');
    END IF;
    UPDATE public.users
    SET gold = COALESCE(gold, 0) + v_per_member
    WHERE guild_id = v_guild_id;
    v_spent := v_per_member * v_member_count;
  ELSIF v_mode = 'allocations' THEN
    v_cap := FLOOR(v_total * 0.40);
    IF v_cap < 1 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Dağıtım tutarı çok düşük.');
    END IF;
    FOR v_entry IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'allocations', '[]'::jsonb))
    LOOP
      v_target := (v_entry->>'user_id')::UUID;
      v_amount := COALESCE((v_entry->>'amount')::BIGINT, 0);
      IF v_target IS NULL OR v_amount <= 0 THEN
        CONTINUE;
      END IF;
      IF v_amount > v_cap THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'Üye başına en fazla %40 (' || v_cap || 'g) verilebilir.'
        );
      END IF;
      v_resolved := public._guild_vault_resolve_member(v_guild_id, v_target);
      IF v_resolved IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Hedef üye loncada değil.');
      END IF;
      UPDATE public.users SET gold = COALESCE(gold, 0) + v_amount WHERE auth_id = v_resolved;
      v_spent := v_spent + v_amount;
    END LOOP;
    IF v_spent <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Dağıtım listesi boş.');
    END IF;
    IF v_spent <> v_total THEN
      RETURN jsonb_build_object('success', false, 'error', 'Toplam ile dağıtım uyuşmuyor.');
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz dağıtım modu.');
  END IF;

  UPDATE public.guilds SET vault_gold = vault_gold - v_spent WHERE id = v_guild_id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (v_guild_id, v_user, 'distribute_gold', jsonb_build_object('mode', v_mode, 'amount', v_spent));

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Altın dağıtıldı.',
    'distributed', v_spent,
    'vault_gold', (SELECT vault_gold FROM public.guilds WHERE id = v_guild_id)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.distribute_guild_vault_item(
  p_vault_item_id UUID,
  p_user_id UUID,
  p_quantity INTEGER DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_leader UUID := auth.uid();
  v_guild_id UUID;
  v_guild RECORD;
  v_item RECORD;
  v_add JSONB;
  v_qty INTEGER := GREATEST(COALESCE(p_quantity, 1), 1);
  v_resolved UUID;
  v_enh INTEGER := 0;
BEGIN
  IF v_leader IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_leader;
  SELECT * INTO v_guild FROM public.guilds WHERE id = v_guild_id FOR UPDATE;
  IF v_guild.leader_id IS DISTINCT FROM v_leader THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lonca lideri dağıtabilir.');
  END IF;

  SELECT * INTO v_item
  FROM public.guild_vault_items
  WHERE id = p_vault_item_id AND guild_id = v_guild_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kasa eşyası bulunamadı.');
  END IF;

  IF v_qty > v_item.quantity THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz kasa miktarı.');
  END IF;

  v_resolved := public._guild_vault_resolve_member(v_guild_id, p_user_id);
  IF v_resolved IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef üye loncada değil.');
  END IF;

  v_enh := COALESCE(v_item.enhancement_level, 0);

  v_add := public._guild_vault_grant_item(v_resolved, v_item.item_id, v_qty, v_enh);
  IF NOT COALESCE((v_add->>'success')::BOOLEAN, false) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', COALESCE(v_add->>'error', 'Envanter dolu — eşya verilemedi.')
    );
  END IF;

  IF v_qty = v_item.quantity THEN
    DELETE FROM public.guild_vault_items WHERE id = v_item.id;
  ELSE
    UPDATE public.guild_vault_items SET quantity = quantity - v_qty WHERE id = v_item.id;
  END IF;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild_id, v_leader, 'distribute_item',
    jsonb_build_object('vault_item_id', p_vault_item_id, 'user_id', v_resolved, 'quantity', v_qty, 'item_id', v_item.item_id)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Eşya dağıtıldı.');
END;
$$;

-- Toggle weekly payout (leader)
CREATE OR REPLACE FUNCTION public.set_guild_vault_auto_payout(p_enabled BOOLEAN)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_leader UUID;
BEGIN
  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  SELECT leader_id INTO v_leader FROM public.guilds WHERE id = v_guild_id;
  IF v_leader IS DISTINCT FROM v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lider ayarlayabilir.');
  END IF;
  UPDATE public.guilds SET vault_auto_payout_weekly = COALESCE(p_enabled, false) WHERE id = v_guild_id;
  RETURN jsonb_build_object('success', true, 'vault_auto_payout_weekly', COALESCE(p_enabled, false));
END;
$$;

CREATE OR REPLACE FUNCTION public.cron_guild_vault_weekly_payout()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_g RECORD;
  v_n INTEGER := 0;
  v_pending BIGINT;
  v_members INTEGER;
  v_per BIGINT;
  v_spend BIGINT;
BEGIN
  FOR v_g IN
    SELECT * FROM public.guilds WHERE vault_auto_payout_weekly = true FOR UPDATE
  LOOP
    PERFORM public._accrue_guild_vault(v_g.id);
    SELECT vault_gold_pending INTO v_pending FROM public.guilds WHERE id = v_g.id;
    IF COALESCE(v_pending, 0) > 0 THEN
      UPDATE public.guilds
      SET vault_gold = vault_gold + v_pending, vault_gold_pending = 0
      WHERE id = v_g.id;
      INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
      VALUES (v_g.id, NULL, 'collect', jsonb_build_object('amount', v_pending, 'auto', true));
    END IF;

    SELECT vault_gold INTO v_spend FROM public.guilds WHERE id = v_g.id;
    IF COALESCE(v_spend, 0) < 100 THEN
      CONTINUE;
    END IF;

    SELECT COUNT(*) INTO v_members FROM public.users WHERE guild_id = v_g.id;
    IF v_members <= 0 THEN CONTINUE; END IF;
    v_per := v_spend / v_members;
    IF v_per <= 0 THEN CONTINUE; END IF;

    UPDATE public.users SET gold = COALESCE(gold, 0) + v_per WHERE guild_id = v_g.id;
    UPDATE public.guilds SET vault_gold = vault_gold - (v_per * v_members) WHERE id = v_g.id;
    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (v_g.id, NULL, 'distribute_gold', jsonb_build_object('mode', 'equal', 'amount', v_per * v_members, 'auto_weekly', true));
    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('guilds_paid', v_n);
END;
$$;

-- Enrich get_guild_vault ledger + can_collect + auto payout flag
CREATE OR REPLACE FUNCTION public.get_guild_vault()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_guild RECORD;
  v_role TEXT;
  v_items JSONB;
  v_ledger JSONB;
  v_territories JSONB;
  v_is_leader BOOLEAN;
  v_is_officer BOOLEAN;
  v_can_collect BOOLEAN;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT u.guild_id, COALESCE(u.guild_role, 'member')
  INTO v_guild_id, v_role
  FROM public.users u
  WHERE u.auth_id = v_user;

  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  PERFORM public._accrue_guild_vault(v_guild_id);

  -- Idempotent: settle finished tournaments still unpaid
  BEGIN
    PERFORM public.grant_guild_war_tournament_prize(t.id)
    FROM public.guild_war_tournaments t
    WHERE t.status IN ('active', 'completed')
      AND t.end_at IS NOT NULL AND t.end_at <= now()
      AND t.prize_paid_at IS NULL
      AND COALESCE(t.prize_gold, 0) > 0
    LIMIT 5;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  SELECT g.* INTO v_guild FROM public.guilds g WHERE g.id = v_guild_id;

  v_is_leader := v_guild.leader_id = v_user;
  v_is_officer := v_role IN ('officer', 'commander') AND NOT v_is_leader;
  v_can_collect := v_is_leader OR v_is_officer;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', vi.id,
    'item_id', vi.item_id,
    'item_name', COALESCE(i.name, vi.item_id),
    'rarity', i.rarity,
    'quantity', vi.quantity,
    'source_type', vi.source_type,
    'enhancement_level', COALESCE(vi.enhancement_level, 0),
    'created_at', vi.created_at
  ) ORDER BY vi.created_at DESC), '[]'::jsonb)
  INTO v_items
  FROM public.guild_vault_items vi
  LEFT JOIN public.items i ON i.id = vi.item_id
  WHERE vi.guild_id = v_guild_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', l.id,
    'action', l.action,
    'payload', l.payload,
    'actor_id', l.actor_id,
    'actor_name', u.username,
    'created_at', l.created_at
  ) ORDER BY l.created_at DESC), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT * FROM public.guild_vault_ledger
    WHERE guild_id = v_guild_id
    ORDER BY created_at DESC
    LIMIT 50
  ) l
  LEFT JOIN public.users u ON u.auth_id = l.actor_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'name', t.name,
    'trade_income', COALESCE(t.trade_income, 0),
    'zone_number', t.zone_number,
    'loot_item_id', t.loot_item_id,
    'loot_item_chance', t.loot_item_chance
  ) ORDER BY t.zone_number NULLS LAST), '[]'::jsonb)
  INTO v_territories
  FROM public.guild_war_territories t
  WHERE t.owner_guild_id = v_guild_id;

  RETURN jsonb_build_object(
    'success', true,
    'guild_id', v_guild_id,
    'is_leader', v_is_leader,
    'is_officer', v_is_officer,
    'can_manage', v_is_leader,
    'can_collect', v_can_collect,
    'guild_role', v_role,
    'vault_auto_payout_weekly', COALESCE(v_guild.vault_auto_payout_weekly, false),
    'vault_gold', COALESCE(v_guild.vault_gold, 0),
    'vault_gold_pending', COALESCE(v_guild.vault_gold_pending, 0),
    'monument_gold_pool', COALESCE(v_guild.monument_gold_pool, 0),
    'items', v_items,
    'ledger', v_ledger,
    'territories', v_territories
  );
END;
$$;

-- Preview/list effective defense includes line (best-effort via detail already computing)
-- Update get_territory_attack_preview to pass line
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
    v_territory.gem_defense_boost,
    v_territory.defense_line_level
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

GRANT EXECUTE ON FUNCTION public.attack_guild_war_territory(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_territory_defense(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.collect_guild_vault_rewards() TO authenticated;
GRANT EXECUTE ON FUNCTION public.distribute_guild_vault_gold(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.distribute_guild_vault_item(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_guild_vault_auto_payout(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cron_guild_vault_weekly_payout() TO service_role;
GRANT EXECUTE ON FUNCTION public.cron_guild_vault_weekly_payout() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_vault() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_territory_attack_preview(uuid) TO authenticated;

COMMIT;
