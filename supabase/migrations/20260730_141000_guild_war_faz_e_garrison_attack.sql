-- Faz E: Garrison defense + leader-only attack + support pledges + grace 2h.
-- Defense = Σ garrison power + gem. Gold def already disabled in Faz A.

BEGIN;

-- ── Tables ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guild_war_garrison (
  user_id UUID PRIMARY KEY REFERENCES public.users(auth_id) ON DELETE CASCADE,
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  territory_id UUID NOT NULL REFERENCES public.guild_war_territories(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_garrison_territory ON public.guild_war_garrison (territory_id);
CREATE INDEX IF NOT EXISTS idx_garrison_guild ON public.guild_war_garrison (guild_id);

CREATE TABLE IF NOT EXISTS public.guild_war_attack_plan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  territory_id UUID NOT NULL REFERENCES public.guild_war_territories(id) ON DELETE CASCADE,
  attacker_guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  leader_id UUID NOT NULL,
  opens_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closes_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'launched', 'cancelled', 'expired')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attack_plan_open
  ON public.guild_war_attack_plan (territory_id, status)
  WHERE status = 'open';

CREATE TABLE IF NOT EXISTS public.guild_war_attack_support (
  plan_id UUID NOT NULL REFERENCES public.guild_war_attack_plan(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  power_snapshot INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (plan_id, user_id)
);

ALTER TABLE public.guild_war_garrison ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_war_attack_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_war_attack_support ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS garrison_select ON public.guild_war_garrison;
CREATE POLICY garrison_select ON public.guild_war_garrison FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS attack_plan_select ON public.guild_war_attack_plan;
CREATE POLICY attack_plan_select ON public.guild_war_attack_plan FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS attack_support_select ON public.guild_war_attack_support;
CREATE POLICY attack_support_select ON public.guild_war_attack_support FOR SELECT TO authenticated USING (true);

-- ── Helpers ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._guild_war_recompute_defense(p_territory_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sum INTEGER := 0;
BEGIN
  SELECT COALESCE(SUM(GREATEST(COALESCE(u.power, 0), 0)), 0)::INTEGER
  INTO v_sum
  FROM public.guild_war_garrison g
  JOIN public.users u ON u.auth_id = g.user_id
  WHERE g.territory_id = p_territory_id
    AND u.guild_id = g.guild_id;

  UPDATE public.guild_war_territories
  SET defense_power = v_sum,
      updated_at = updated_at
  WHERE id = p_territory_id;

  RETURN v_sum;
END;
$$;

CREATE OR REPLACE FUNCTION public._guild_war_clear_garrison(p_territory_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  DELETE FROM public.guild_war_garrison WHERE territory_id = p_territory_id;
  UPDATE public.guild_war_territories
  SET defense_power = 0
  WHERE id = p_territory_id;
END;
$$;

-- ── Garrison RPCs ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.guild_war_garrison_join(p_territory_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_terr RECORD;
  v_def INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_terr FROM public.guild_war_territories WHERE id = p_territory_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;
  IF v_terr.owner_guild_id IS DISTINCT FROM v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece kendi bölgenize nöbet yazılabilir.');
  END IF;

  INSERT INTO public.guild_war_garrison (user_id, guild_id, territory_id)
  VALUES (v_user, v_guild_id, p_territory_id)
  ON CONFLICT (user_id) DO UPDATE
    SET territory_id = EXCLUDED.territory_id,
        guild_id = EXCLUDED.guild_id,
        joined_at = now();

  -- Recompute old + new if moved
  PERFORM public._guild_war_recompute_defense(p_territory_id);
  v_def := public._guild_war_recompute_defense(p_territory_id);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Nöbete yazıldın.',
    'defense_power', v_def
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.guild_war_garrison_leave()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_terr UUID;
  v_def INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT territory_id INTO v_terr FROM public.guild_war_garrison WHERE user_id = v_user;
  IF v_terr IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Nöbette değilsin.');
  END IF;

  DELETE FROM public.guild_war_garrison WHERE user_id = v_user;
  v_def := public._guild_war_recompute_defense(v_terr);

  RETURN jsonb_build_object('success', true, 'message', 'Nöbetten ayrıldın.', 'defense_power', v_def);
END;
$$;

CREATE OR REPLACE FUNCTION public.guild_war_garrison_assign(
  p_territory_id UUID,
  p_user_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_leader UUID;
  v_terr RECORD;
  v_target_guild UUID;
  v_def INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  SELECT leader_id INTO v_leader FROM public.guilds WHERE id = v_guild_id;
  IF v_leader IS DISTINCT FROM v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lonca başkanı atayabilir.');
  END IF;

  SELECT * INTO v_terr FROM public.guild_war_territories WHERE id = p_territory_id;
  IF v_terr.owner_guild_id IS DISTINCT FROM v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bölge sizin değil.');
  END IF;

  SELECT guild_id INTO v_target_guild FROM public.users WHERE auth_id = p_user_id;
  IF v_target_guild IS DISTINCT FROM v_guild_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef üye loncada değil.');
  END IF;

  INSERT INTO public.guild_war_garrison (user_id, guild_id, territory_id)
  VALUES (p_user_id, v_guild_id, p_territory_id)
  ON CONFLICT (user_id) DO UPDATE
    SET territory_id = EXCLUDED.territory_id,
        guild_id = EXCLUDED.guild_id,
        joined_at = now();

  v_def := public._guild_war_recompute_defense(p_territory_id);
  RETURN jsonb_build_object('success', true, 'defense_power', v_def);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_territory_garrison(p_territory_id UUID)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(row_to_json(x)), '[]'::json)
  INTO v_result
  FROM (
    SELECT
      g.user_id,
      u.username,
      COALESCE(u.power, 0) AS power,
      g.joined_at
    FROM public.guild_war_garrison g
    JOIN public.users u ON u.auth_id = g.user_id
    WHERE g.territory_id = p_territory_id
    ORDER BY COALESCE(u.power, 0) DESC
  ) x;
  RETURN v_result;
END;
$$;

-- ── Attack plan + support ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.guild_war_open_attack_plan(p_territory_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

  -- Grace 2h
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
    p_territory_id, v_guild_id, v_user, now() + interval '45 minutes', 'open'
  ) RETURNING id INTO v_plan_id;

  -- Auto-support leader
  INSERT INTO public.guild_war_attack_support (plan_id, user_id, power_snapshot)
  SELECT v_plan_id, v_user, COALESCE(power, 0)
  FROM public.users WHERE auth_id = v_user;

  RETURN jsonb_build_object(
    'success', true,
    'plan_id', v_plan_id,
    'closes_at', now() + interval '45 minutes',
    'message', 'Saldırı planı açıldı. Üyeler destek verebilir.'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.guild_war_pledge_attack_support(p_plan_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
  IF NOT FOUND OR v_plan.status <> 'open' OR v_plan.closes_at < now() THEN
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
$$;

-- ── Attack: leader-only, power+support, grace, garrison wipe, gem wipe ─────
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

  -- Grace 2h after conquest
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

  -- Recompute defender garrison
  IF v_territory.owner_guild_id IS NOT NULL THEN
    v_garrison_def := public._guild_war_recompute_defense(p_territory_id);
  ELSE
    v_garrison_def := 0;
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id;

  -- Attack power: leader power + open plan support (cap 50% of guild top sum)
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
    UPDATE public.guild_war_attack_plan
    SET status = CASE WHEN v_success THEN 'launched' ELSE 'launched' END
    WHERE id = v_plan.id;
  END IF;

  SELECT id INTO v_active_season_id
  FROM public.guild_war_seasons
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_active_season_id IS NOT NULL THEN
    INSERT INTO public.guild_war_rankings (season_id, guild_id, points, wins, losses)
    VALUES (
      v_active_season_id, v_guild_id, v_points_gained,
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
    PERFORM public._guild_war_clear_garrison(p_territory_id);
    UPDATE public.guild_war_territories
    SET owner_guild_id = v_guild_id,
        gem_defense_boost = 0,
        defense_power = 0,
        updated_at = now()
    WHERE id = p_territory_id;
  END IF;

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

-- Gem defense: any guild member (own gems)
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
BEGIN
  IF p_gems IS NULL OR p_gems <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'Geçersiz elmas miktarı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_player_id;
  IF v_guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz.');
  END IF;

  SELECT * INTO v_territory FROM public.guild_war_territories WHERE id = p_territory_id FOR UPDATE;
  IF v_territory IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bölge bulunamadı.');
  END IF;
  IF v_territory.owner_guild_id != v_guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Sadece kendi bölgenize savunma ekleyebilirsiniz.');
  END IF;

  SELECT gems INTO v_player_gems FROM public.users WHERE auth_id = v_player_id;
  IF v_player_gems < p_gems THEN
    RETURN json_build_object('success', false, 'error', 'Yeterli elmasınız yok.');
  END IF;

  v_defense_increase := p_gems * 10;

  UPDATE public.users SET gems = gems - p_gems WHERE auth_id = v_player_id;
  UPDATE public.guild_war_territories
  SET gem_defense_boost = gem_defense_boost + v_defense_increase,
      defense_added_at = now(),
      updated_at = now()
  WHERE id = p_territory_id
  RETURNING * INTO v_territory;

  v_garrison := public._guild_war_recompute_defense(p_territory_id);
  v_effective_defense := public.guild_war_territory_effective_defense(
    v_garrison, v_territory.gem_defense_boost
  );

  RETURN json_build_object(
    'success', true,
    'message', format(
      'Elmas savunması +%s (etkili %s). Bölge kaybedilirse yalnız elmas sıfırlanır.',
      v_defense_increase, v_effective_defense
    ),
    'gem_defense_boost', v_territory.gem_defense_boost,
    'effective_defense', v_effective_defense,
    'defense_power', v_garrison
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.guild_war_garrison_join(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guild_war_garrison_leave() TO authenticated;
GRANT EXECUTE ON FUNCTION public.guild_war_garrison_assign(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_territory_garrison(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guild_war_open_attack_plan(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guild_war_pledge_attack_support(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attack_guild_war_territory(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_territory_defense(uuid, integer) TO authenticated;

COMMIT;
