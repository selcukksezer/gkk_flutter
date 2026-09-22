-- Attack plans: no time window / no expires. Open until launched or cancelled.

BEGIN;

ALTER TABLE public.guild_war_attack_plan
  ALTER COLUMN closes_at DROP NOT NULL;

UPDATE public.guild_war_attack_plan
SET closes_at = NULL
WHERE status = 'open';

CREATE OR REPLACE FUNCTION public.guild_war_open_attack_plan(p_territory_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_leader UUID;
  v_terr RECORD;
  v_plan_id UUID;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  SELECT leader_id INTO v_leader FROM public.guilds WHERE id = v_guild_id;
  IF v_leader IS DISTINCT FROM v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lonca başkanı saldırı planı açabilir.');
  END IF;

  SELECT * INTO v_terr FROM public.guild_war_territories WHERE id = p_territory_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;
  IF v_terr.owner_guild_id = v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  IF v_terr.owner_guild_id IS NOT NULL
     AND v_terr.updated_at > now() - interval '2 hours' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yeni fetih koruması aktif.',
      'grace_until', v_terr.updated_at + interval '2 hours'
    );
  END IF;

  UPDATE public.guild_war_attack_plan
  SET status = 'cancelled'
  WHERE attacker_guild_id = v_guild_id AND status = 'open';

  INSERT INTO public.guild_war_attack_plan (
    territory_id, attacker_guild_id, leader_id, closes_at, status
  ) VALUES (
    p_territory_id, v_guild_id, v_user, NULL, 'open'
  ) RETURNING id INTO v_plan_id;

  INSERT INTO public.guild_war_attack_support (plan_id, user_id, power_snapshot)
  SELECT v_plan_id, v_user, COALESCE(power, 0)
  FROM public.users WHERE auth_id = v_user;

  RETURN jsonb_build_object(
    'success', true,
    'plan_id', v_plan_id,
    'message', 'Saldırı planı açıldı. Üyeler güç + elmas destekleyebilir; süre yok.'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.guild_war_pledge_attack_support(p_plan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_plan RECORD;
  v_power INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT * INTO v_plan FROM public.guild_war_attack_plan WHERE id = p_plan_id;
  IF NOT FOUND OR v_plan.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Plan açık değil.');
  END IF;

  SELECT guild_id, COALESCE(power, 0) INTO v_guild_id, v_power
  FROM public.users WHERE auth_id = v_user;

  IF v_guild_id IS DISTINCT FROM v_plan.attacker_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu plan sizin loncanızın değil.');
  END IF;

  INSERT INTO public.guild_war_attack_support (plan_id, user_id, power_snapshot)
  VALUES (p_plan_id, v_user, v_power)
  ON CONFLICT (plan_id, user_id) DO UPDATE
    SET power_snapshot = EXCLUDED.power_snapshot;

  RETURN jsonb_build_object('success', true, 'power_snapshot', v_power);
END;
$function$;

CREATE OR REPLACE FUNCTION public.add_attack_plan_gems(
  p_plan_id UUID,
  p_gems INTEGER
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_guild UUID;
  v_plan RECORD;
  v_player_gems INTEGER;
  v_boost INTEGER;
  v_min INTEGER := 5;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  IF p_gems IS NULL OR p_gems < v_min THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum ' || v_min || ' elmas.');
  END IF;
  IF p_gems > 500 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tek seferde en fazla 500 elmas.');
  END IF;

  SELECT guild_id, COALESCE(gems, 0)
  INTO v_guild, v_player_gems
  FROM public.users WHERE auth_id = v_uid FOR UPDATE;

  IF v_guild IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_plan
  FROM public.guild_war_attack_plan
  WHERE id = p_plan_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Plan bulunamadı.');
  END IF;
  IF v_plan.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Açık saldırı planı yok.');
  END IF;
  IF v_plan.attacker_guild_id IS DISTINCT FROM v_guild THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece saldıran lonca üyeleri elmas ekleyebilir.');
  END IF;

  IF v_player_gems < p_gems THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli elmasınız yok.');
  END IF;

  v_boost := p_gems * 10;

  UPDATE public.users
  SET gems = gems - p_gems, updated_at = now()
  WHERE auth_id = v_uid AND gems >= p_gems;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli elmasınız yok.');
  END IF;

  UPDATE public.guild_war_attack_plan
  SET gem_attack_boost = gem_attack_boost + v_boost
  WHERE id = p_plan_id
  RETURNING * INTO v_plan;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild, v_uid, 'attack_gem_boost',
    jsonb_build_object(
      'plan_id', p_plan_id,
      'territory_id', v_plan.territory_id,
      'gems', p_gems,
      'boost', v_boost,
      'gem_attack_boost', v_plan.gem_attack_boost
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Saldırıya +' || v_boost || ' elmas gücü eklendi (toplam elmas boost: '
               || v_plan.gem_attack_boost || ').',
    'gems_spent', p_gems,
    'boost_added', v_boost,
    'gem_attack_boost', v_plan.gem_attack_boost,
    'plan_id', p_plan_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_territory_attack_plan(p_territory_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_guild UUID;
  v_plan RECORD;
  v_supporters jsonb;
  v_support_sum INTEGER := 0;
  v_leader_power INTEGER := 0;
  v_gem INTEGER := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok');
  END IF;

  SELECT guild_id INTO v_guild FROM public.users WHERE auth_id = v_uid;

  SELECT p.* INTO v_plan
  FROM public.guild_war_attack_plan p
  WHERE p.territory_id = p_territory_id
    AND p.status = 'open'
    AND (v_guild IS NULL OR p.attacker_guild_id = v_guild)
  ORDER BY p.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', true, 'open', false);
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'user_id', s.user_id,
    'username', u.username,
    'power', s.power_snapshot,
    'is_leader', s.user_id = v_plan.leader_id
  ) ORDER BY s.power_snapshot DESC), '[]'::jsonb)
  INTO v_supporters
  FROM public.guild_war_attack_support s
  LEFT JOIN public.users u ON u.auth_id = s.user_id
  WHERE s.plan_id = v_plan.id;

  SELECT COALESCE(SUM(power_snapshot), 0)::INTEGER INTO v_support_sum
  FROM public.guild_war_attack_support WHERE plan_id = v_plan.id;

  SELECT COALESCE(power, 0) INTO v_leader_power
  FROM public.users WHERE auth_id = v_plan.leader_id;

  v_gem := COALESCE(v_plan.gem_attack_boost, 0);

  RETURN jsonb_build_object(
    'success', true,
    'open', true,
    'plan_id', v_plan.id,
    'territory_id', v_plan.territory_id,
    'attacker_guild_id', v_plan.attacker_guild_id,
    'leader_id', v_plan.leader_id,
    'opens_at', v_plan.opens_at,
    'status', v_plan.status,
    'supporters', v_supporters,
    'support_sum', v_support_sum,
    'leader_power', v_leader_power,
    'gem_attack_boost', v_gem,
    'estimated_attack_power', v_support_sum + v_gem,
    'i_pledged', EXISTS (
      SELECT 1 FROM public.guild_war_attack_support s
      WHERE s.plan_id = v_plan.id AND s.user_id = v_uid
    ),
    'is_leader', v_plan.leader_id = v_uid
  );
END;
$$;

-- Patch attack + preview: ignore closes_at
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
  v_vault BIGINT := 0;
  v_plan jsonb;
  v_plan_sum INTEGER := 0;
  v_gem INTEGER := 0;
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
    SELECT vault_gold INTO v_vault FROM public.guilds WHERE id = v_guild_id;
  END IF;

  IF v_territory.owner_guild_id = v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendi bölgenize saldıramazsınız.');
  END IF;

  v_cost := COALESCE(v_territory.attack_gold_cost, 10000000);

  SELECT COALESCE(power, 0) INTO v_attack_power
  FROM public.users WHERE auth_id = v_player_id;

  SELECT COALESCE(SUM(s.power_snapshot), 0)::INTEGER,
         COALESCE(MAX(p.gem_attack_boost), 0)::INTEGER
  INTO v_plan_sum, v_gem
  FROM public.guild_war_attack_plan p
  LEFT JOIN public.guild_war_attack_support s ON s.plan_id = p.id
  WHERE p.territory_id = p_territory_id
    AND p.attacker_guild_id = v_guild_id
    AND p.status = 'open';

  IF v_plan_sum > 0 THEN
    v_attack_power := v_plan_sum;
  END IF;
  v_attack_power := v_attack_power + COALESCE(v_gem, 0);

  v_effective_defense := public.guild_war_territory_effective_defense(
    v_territory.defense_power,
    v_territory.gem_defense_boost,
    v_territory.defense_line_level
  );

  v_win_chance := CASE
    WHEN v_attack_power + v_effective_defense <= 0 THEN 0.5
    ELSE ROUND((v_attack_power::NUMERIC / (v_attack_power + GREATEST(v_effective_defense, 1)))::NUMERIC, 3)
  END;

  v_plan := public.get_territory_attack_plan(p_territory_id);

  RETURN jsonb_build_object(
    'success', true,
    'territory_id', p_territory_id,
    'attack_power', v_attack_power,
    'defense_power', v_effective_defense,
    'gem_attack_boost', v_gem,
    'attack_gold_cost', v_cost,
    'vault_gold', COALESCE(v_vault, 0),
    'can_afford', COALESCE(v_vault, 0) >= v_cost,
    'trade_income', COALESCE(v_territory.trade_income, 0),
    'roi_days', CASE
      WHEN COALESCE(v_territory.trade_income, 0) > 0
      THEN ROUND(v_cost::NUMERIC / v_territory.trade_income, 1)
      ELSE NULL
    END,
    'win_chance', v_win_chance,
    'attack_plan', v_plan,
    'grace_until', CASE
      WHEN v_territory.updated_at > now() - interval '2 hours'
           AND v_territory.owner_guild_id IS NOT NULL
      THEN v_territory.updated_at + interval '2 hours'
      ELSE NULL
    END
  );
END;
$function$;

-- Only patch the plan lookup in attack (full fn from live + closes_at removed)
DO $$
DECLARE
  v_def TEXT;
BEGIN
  -- Replace attack plan filter via CREATE of full function below
  NULL;
END $$;

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
  v_gem_boost INTEGER := 0;
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

  v_cost := COALESCE(v_territory.attack_gold_cost, 10000000);

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
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    SELECT COALESCE(SUM(power_snapshot), 0)::INTEGER INTO v_support_sum
    FROM public.guild_war_attack_support
    WHERE plan_id = v_plan.id AND user_id <> v_player_id;
    v_gem_boost := COALESCE(v_plan.gem_attack_boost, 0);
    v_attack_power := v_attack_power + v_support_sum + v_gem_boost;
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
      'support_sum', v_support_sum,
      'gem_attack_boost', v_gem_boost
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
    'support_sum', v_support_sum,
    'gem_attack_boost', v_gem_boost
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.guild_war_open_attack_plan(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guild_war_pledge_attack_support(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_attack_plan_gems(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_territory_attack_plan(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_territory_attack_preview(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attack_guild_war_territory(uuid) TO authenticated;

COMMIT;
