-- Attack plan visibility + flat 10M attack cost + secure vault deposit
-- + monument gold → vault + monument upgrade spends vault.

BEGIN;

-- ── Flat attack cost 10M ────────────────────────────────────────────────────
UPDATE public.guild_war_territories
SET attack_gold_cost = 10000000;

-- ── Open attack plan for territory (my guild or any open plan on terr) ──────
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
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum yok');
  END IF;

  SELECT guild_id INTO v_guild FROM public.users WHERE auth_id = v_uid;

  SELECT p.* INTO v_plan
  FROM public.guild_war_attack_plan p
  WHERE p.territory_id = p_territory_id
    AND p.status = 'open'
    AND p.closes_at >= now()
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

  RETURN jsonb_build_object(
    'success', true,
    'open', true,
    'plan_id', v_plan.id,
    'territory_id', v_plan.territory_id,
    'attacker_guild_id', v_plan.attacker_guild_id,
    'leader_id', v_plan.leader_id,
    'opens_at', v_plan.opens_at,
    'closes_at', v_plan.closes_at,
    'status', v_plan.status,
    'supporters', v_supporters,
    'support_sum', v_support_sum,
    'leader_power', v_leader_power,
    'estimated_attack_power', v_support_sum,
    'i_pledged', EXISTS (
      SELECT 1 FROM public.guild_war_attack_support s
      WHERE s.plan_id = v_plan.id AND s.user_id = v_uid
    ),
    'is_leader', v_plan.leader_id = v_uid
  );
END;
$$;

-- Preview cost fallback 10M
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
  v_vault BIGINT := 0;
  v_plan jsonb;
  v_plan_sum INTEGER := 0;
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

  SELECT COALESCE(SUM(s.power_snapshot), 0)::INTEGER INTO v_plan_sum
  FROM public.guild_war_attack_plan p
  JOIN public.guild_war_attack_support s ON s.plan_id = p.id
  WHERE p.territory_id = p_territory_id
    AND p.attacker_guild_id = v_guild_id
    AND p.status = 'open'
    AND p.closes_at >= now();

  IF v_plan_sum > 0 THEN
    v_attack_power := v_plan_sum;
  END IF;

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

-- Attack uses 10M fallback
-- Patch only cost line via full replace of cost coalesce in live attack - use CREATE that mirrors BCD with 10M
CREATE OR REPLACE FUNCTION public._guild_war_attack_cost(p_territory public.guild_war_territories)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(p_territory.attack_gold_cost, 10000000);
$$;

-- ── Secure member deposit ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.guild_vault_deposits (
  id BIGSERIAL PRIMARY KEY,
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  amount BIGINT NOT NULL CHECK (amount > 0),
  balance_before BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  vault_before BIGINT NOT NULL,
  vault_after BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vault_deposits_user_day
  ON public.guild_vault_deposits (user_id, created_at DESC);

ALTER TABLE public.guild_vault_deposits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vault_deposits_select ON public.guild_vault_deposits;
CREATE POLICY vault_deposits_select ON public.guild_vault_deposits
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR guild_id IN (SELECT guild_id FROM public.users WHERE auth_id = auth.uid())
  );

CREATE OR REPLACE FUNCTION public.deposit_guild_vault_gold(p_amount BIGINT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_user RECORD;
  v_guild RECORD;
  v_amount BIGINT := COALESCE(p_amount, 0);
  v_day_sum BIGINT;
  v_max_tx BIGINT := 50000000;      -- 50M / tx
  v_max_day BIGINT := 200000000;    -- 200M / day / user
  v_vault_before BIGINT;
  v_vault_after BIGINT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF v_amount < 1000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum yatırma 1.000g.');
  END IF;

  IF v_amount > v_max_tx THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tek seferde en fazla 50.000.000g.');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_uid FOR UPDATE;
  IF NOT FOUND OR v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  IF COALESCE(v_user.gold, 0) < v_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın.');
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_day_sum
  FROM public.guild_vault_deposits
  WHERE user_id = v_uid
    AND created_at >= date_trunc('day', now());

  IF v_day_sum + v_amount > v_max_day THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Günlük yatırma limiti (200M) aşıldı.',
      'remaining', GREATEST(v_max_day - v_day_sum, 0)
    );
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id FOR UPDATE;
  v_vault_before := COALESCE(v_guild.vault_gold, 0);

  UPDATE public.users
  SET gold = gold - v_amount, updated_at = now()
  WHERE auth_id = v_uid AND gold >= v_amount;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın.');
  END IF;

  UPDATE public.guilds
  SET vault_gold = vault_gold + v_amount
  WHERE id = v_user.guild_id
  RETURNING vault_gold INTO v_vault_after;

  INSERT INTO public.guild_vault_deposits (
    guild_id, user_id, amount, balance_before, balance_after, vault_before, vault_after
  ) VALUES (
    v_user.guild_id, v_uid, v_amount,
    v_user.gold, v_user.gold - v_amount,
    v_vault_before, v_vault_after
  );

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_user.guild_id, v_uid, 'member_deposit',
    jsonb_build_object(
      'amount', v_amount,
      'vault_before', v_vault_before,
      'vault_after', v_vault_after
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Kasaya yatırıldı.',
    'amount', v_amount,
    'vault_gold', v_vault_after,
    'player_gold', v_user.gold - v_amount
  );
END;
$$;

-- ── Monument gold donate → also vault ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.donate_to_monument(
  p_structural INT DEFAULT 0,
  p_mystical INT DEFAULT 0,
  p_critical INT DEFAULT 0,
  p_gold BIGINT DEFAULT 0
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_user RECORD;
  v_guild_id UUID;
  v_daily RECORD;
  v_contribution_score BIGINT;
  v_limits JSONB := public._monument_daily_limits();
  v_max_structural INT := COALESCE((v_limits->>'structural')::INT, 500);
  v_max_mystical INT := COALESCE((v_limits->>'mystical')::INT, 200);
  v_max_critical INT := COALESCE((v_limits->>'critical')::INT, 50);
  v_max_gold BIGINT := COALESCE((v_limits->>'gold')::BIGINT, 10000000);
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz');
  END IF;
  v_guild_id := v_user.guild_id;

  SELECT * INTO v_daily
  FROM public.guild_daily_donations
  WHERE guild_id = v_guild_id AND user_id = v_user_id AND donation_date = CURRENT_DATE
  FOR UPDATE;

  IF FOUND THEN
    IF v_daily.structural_today + p_structural > v_max_structural OR
       v_daily.mystical_today + p_mystical > v_max_mystical OR
       v_daily.critical_today + p_critical > v_max_critical OR
       v_daily.gold_today + p_gold > v_max_gold THEN
      RETURN jsonb_build_object('success', false, 'error', 'Günlük bağış sınırını aştınız');
    END IF;
  ELSE
    IF p_structural > v_max_structural OR p_mystical > v_max_mystical OR p_critical > v_max_critical OR p_gold > v_max_gold THEN
      RETURN jsonb_build_object('success', false, 'error', 'Günlük bağış sınırını aştınız');
    END IF;
  END IF;

  IF p_gold > 0 AND v_user.gold < p_gold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli altınınız yok');
  END IF;

  IF p_structural > 0 AND NOT public._consume_inventory_item(v_user_id, 'resource_structural', p_structural) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli yapısal kaynağınız yok');
  END IF;

  IF p_mystical > 0 AND NOT public._consume_inventory_item(v_user_id, 'resource_mystical', p_mystical) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli mistik kaynağınız yok');
  END IF;

  IF p_critical > 0 AND NOT public._consume_inventory_item(v_user_id, 'resource_critical', p_critical) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yeterli kritik kaynağınız yok');
  END IF;

  IF p_gold > 0 THEN
    UPDATE public.users SET gold = gold - p_gold WHERE auth_id = v_user_id AND gold >= p_gold;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yeterli altınınız yok');
    END IF;
  END IF;

  v_contribution_score := p_structural * 10 + p_mystical * 25 + p_critical * 100 + p_gold / 1000;

  -- Gold bağış: anıt havuzu + lonca kasası (savaş/anıt ortak kasa)
  UPDATE public.guilds SET
    monument_structural = monument_structural + p_structural,
    monument_mystical = monument_mystical + p_mystical,
    monument_critical = monument_critical + p_critical,
    monument_gold_pool = monument_gold_pool + p_gold,
    vault_gold = vault_gold + GREATEST(p_gold, 0)
  WHERE id = v_guild_id;

  IF p_gold > 0 THEN
    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      v_guild_id, v_user_id, 'monument_gold_to_vault',
      jsonb_build_object('amount', p_gold)
    );
  END IF;

  INSERT INTO public.guild_contributions (
    guild_id, user_id, structural_donated, mystical_donated, critical_donated,
    gold_donated, contribution_score, last_donated_at
  )
  VALUES (v_guild_id, v_user_id, p_structural, p_mystical, p_critical, p_gold, v_contribution_score, now())
  ON CONFLICT (guild_id, user_id) DO UPDATE SET
    structural_donated = public.guild_contributions.structural_donated + EXCLUDED.structural_donated,
    mystical_donated = public.guild_contributions.mystical_donated + EXCLUDED.mystical_donated,
    critical_donated = public.guild_contributions.critical_donated + EXCLUDED.critical_donated,
    gold_donated = public.guild_contributions.gold_donated + EXCLUDED.gold_donated,
    contribution_score = public.guild_contributions.contribution_score + EXCLUDED.contribution_score,
    last_donated_at = now();

  INSERT INTO public.guild_daily_donations (
    guild_id, user_id, donation_date, structural_today, mystical_today, critical_today, gold_today
  )
  VALUES (v_guild_id, v_user_id, CURRENT_DATE, p_structural, p_mystical, p_critical, p_gold)
  ON CONFLICT (guild_id, user_id, donation_date) DO UPDATE SET
    structural_today = public.guild_daily_donations.structural_today + EXCLUDED.structural_today,
    mystical_today = public.guild_daily_donations.mystical_today + EXCLUDED.mystical_today,
    critical_today = public.guild_daily_donations.critical_today + EXCLUDED.critical_today,
    gold_today = public.guild_daily_donations.gold_today + EXCLUDED.gold_today;

  RETURN jsonb_build_object(
    'success', true,
    'score_added', v_contribution_score,
    'vault_credited', GREATEST(p_gold, 0)
  );
END;
$$;

-- ── Monument upgrade: gold from vault_gold (+ pool mirror) ──────────────────
CREATE OR REPLACE FUNCTION public.upgrade_monument(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user RECORD;
  v_guild RECORD;
  v_next_level INT;
  v_cost RECORD;
  v_members INT;
  v_mult NUMERIC;
  v_req_structural BIGINT;
  v_req_mystical BIGINT;
  v_req_critical BIGINT;
  v_req_gold BIGINT;
  v_available_gold BIGINT;
  v_from_pool BIGINT;
  v_from_vault BIGINT;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;
  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF v_user.guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bir loncaya uye degilsiniz');
  END IF;
  IF COALESCE(v_user.guild_role, '') NOT IN ('leader', 'officer', 'commander') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkiniz yok (Lider veya Subay gerekli)');
  END IF;
  SELECT * INTO v_guild FROM public.guilds WHERE id = v_user.guild_id FOR UPDATE;
  v_next_level := v_guild.monument_level + 1;
  IF v_next_level > 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Anit zaten maksimum seviyede');
  END IF;
  SELECT * INTO v_cost FROM public.monument_level_costs WHERE level = v_next_level;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seviye maliyeti tanimli degil');
  END IF;
  SELECT COUNT(*)::INT INTO v_members FROM public.users WHERE guild_id = v_guild.id;
  v_mult := public.guild_size_multiplier(v_members);
  v_req_structural := CEIL(v_cost.structural * v_mult)::BIGINT;
  v_req_mystical := CEIL(v_cost.mystical * v_mult)::BIGINT;
  v_req_critical := CEIL(v_cost.critical * v_mult)::BIGINT;
  v_req_gold := CEIL(v_cost.gold * v_mult)::BIGINT;
  IF v_cost.blueprint_type IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.guild_blueprints
      WHERE guild_id = v_guild.id AND blueprint_type = v_cost.blueprint_type AND is_complete = true
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', v_cost.blueprint_type || ' blueprint tamamlanmali');
    END IF;
  END IF;

  -- Gold: vault + monument pool (bağışlar her ikisine yazıldığı için double-count riski var)
  -- Güvenli: harcama SADECE vault_gold'tan; pool görüntü/istatistik için düşülür (aynı miktar, vault'tan).
  v_available_gold := COALESCE(v_guild.vault_gold, 0);

  IF v_guild.monument_structural < v_req_structural OR
     v_guild.monument_mystical < v_req_mystical OR
     v_guild.monument_critical < v_req_critical OR
     v_available_gold < v_req_gold THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yeterli kaynak yok (altın: lonca kasası)',
      'vault_gold', v_available_gold,
      'required_gold', v_req_gold
    );
  END IF;

  v_from_vault := v_req_gold;
  v_from_pool := LEAST(COALESCE(v_guild.monument_gold_pool, 0), v_req_gold);

  UPDATE public.guilds SET
    monument_level = v_next_level,
    monument_structural = monument_structural - v_req_structural,
    monument_mystical = monument_mystical - v_req_mystical,
    monument_critical = monument_critical - v_req_critical,
    monument_gold_pool = GREATEST(monument_gold_pool - v_from_pool, 0),
    vault_gold = vault_gold - v_from_vault,
    monument_100_first = CASE WHEN v_next_level = 100 AND NOT EXISTS (SELECT 1 FROM public.guilds WHERE monument_level >= 100 AND id != v_guild.id) THEN true ELSE monument_100_first END,
    monument_100_at = CASE WHEN v_next_level = 100 THEN now() ELSE monument_100_at END
  WHERE id = v_guild.id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild.id, p_user_id, 'monument_upgrade_spend',
    jsonb_build_object(
      'amount', v_from_vault,
      'level', v_next_level,
      'pool_mirrored', v_from_pool
    )
  );

  INSERT INTO public.monument_upgrades (guild_id, from_level, to_level, structural_spent, mystical_spent, critical_spent, gold_spent, upgraded_by)
  VALUES (v_guild.id, v_guild.monument_level, v_next_level, v_req_structural, v_req_mystical, v_req_critical, v_req_gold, p_user_id);
  PERFORM public.sync_guild_member_monument_stats(v_guild.id);
  RETURN jsonb_build_object(
    'success', true,
    'new_level', v_next_level,
    'gold_from_vault', v_from_vault
  );
END;
$function$;

-- Fix double-count on donate: gold should go to vault OR pool, not both for spend purposes.
-- User asked donations enter vault AND monument can spend from vault.
-- So donate: vault only for spendable gold; pool tracks "monument dedicated" as mirror of vault credits from monument.
-- Simpler fix to avoid double: donate gold → ONLY vault_gold; monument_gold_pool += gold for UI progress display
-- Upgrade spends vault only and mirrors deduct pool.
-- But then pool and vault grow together on donate, upgrade deducts both → OK if always equal for gold path.
-- Problem: territory income also fills vault without pool → vault > pool. Upgrade uses vault. Good.
-- Donate adds both → vault and pool increase. Upgrade deducts vault full + pool min. Pool can go lower than "donated" tracking. OK.

GRANT EXECUTE ON FUNCTION public.get_territory_attack_plan(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_territory_attack_preview(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deposit_guild_vault_gold(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.donate_to_monument(INT, INT, INT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upgrade_monument(uuid) TO authenticated;

COMMIT;
