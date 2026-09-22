-- Daily 5% tax on guild vault_gold holdings → kingdom treasury.

BEGIN;

ALTER TABLE public.guilds
  ADD COLUMN IF NOT EXISTS vault_last_tax_at TIMESTAMPTZ;

-- Existing guilds: start clock now (no retroactive wipe)
UPDATE public.guilds
SET vault_last_tax_at = now()
WHERE vault_last_tax_at IS NULL;

-- Allow treasury ledger kind
ALTER TABLE public.kingdom_treasury_ledger
  DROP CONSTRAINT IF EXISTS kingdom_treasury_ledger_kind_check;

ALTER TABLE public.kingdom_treasury_ledger
  ADD CONSTRAINT kingdom_treasury_ledger_kind_check
  CHECK (kind IN (
    'tax_market', 'tax_shop', 'tax_guild_vault', 'king_gift', 'system_adjust'
  ));

CREATE OR REPLACE FUNCTION public._apply_guild_vault_daily_tax(p_guild_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_guild RECORD;
  v_now TIMESTAMPTZ := now();
  v_from TIMESTAMPTZ;
  v_days INTEGER;
  v_i INTEGER;
  v_rate NUMERIC;
  v_tax BIGINT;
  v_total BIGINT := 0;
  v_bal BIGINT;
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT id, COALESCE(vault_gold, 0) AS vault_gold,
         vault_last_tax_at,
         COALESCE(tax_rate, 0.05) AS tax_rate
  INTO v_guild
  FROM public.guilds
  WHERE id = p_guild_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  v_from := COALESCE(v_guild.vault_last_tax_at, v_now);
  v_days := FLOOR(EXTRACT(EPOCH FROM (v_now - v_from)) / 86400.0)::INTEGER;
  -- Cap catch-up (avoid wiping idle guilds after long offline)
  v_days := LEAST(GREATEST(v_days, 0), 7);

  IF v_days <= 0 THEN
    RETURN 0;
  END IF;

  v_rate := GREATEST(LEAST(COALESCE(v_guild.tax_rate, 0.05), 0.50), 0);
  IF v_rate <= 0 THEN
    UPDATE public.guilds SET vault_last_tax_at = v_now WHERE id = p_guild_id;
    RETURN 0;
  END IF;

  v_bal := GREATEST(v_guild.vault_gold, 0);

  FOR v_i IN 1..v_days LOOP
    EXIT WHEN v_bal <= 0;
    v_tax := FLOOR(v_bal * v_rate)::BIGINT;
    IF v_tax <= 0 THEN
      EXIT;
    END IF;
    IF v_tax > v_bal THEN
      v_tax := v_bal;
    END IF;
    v_bal := v_bal - v_tax;
    v_total := v_total + v_tax;
  END LOOP;

  IF v_total > 0 THEN
    UPDATE public.guilds
    SET vault_gold = GREATEST(vault_gold - v_total, 0),
        vault_last_tax_at = v_from + (v_days * interval '1 day')
    WHERE id = p_guild_id;

    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      p_guild_id,
      NULL,
      'vault_tax',
      jsonb_build_object(
        'amount', v_total,
        'days', v_days,
        'rate', v_rate,
        'destination', 'kingdom_treasury'
      )
    );

    BEGIN
      PERFORM public._kingdom_treasury_credit(
        'gold',
        v_total::NUMERIC,
        'tax_guild_vault',
        NULL,
        NULL,
        'guild',
        p_guild_id::text,
        'Günlük lonca kasası vergisi'
      );
    EXCEPTION WHEN OTHERS THEN
      NULL; -- tax already deducted from guild; don't roll back guild side
    END;
  ELSE
    UPDATE public.guilds
    SET vault_last_tax_at = v_from + (v_days * interval '1 day')
    WHERE id = p_guild_id;
  END IF;

  RETURN v_total;
END;
$$;

-- Hook into accrual so any vault touch applies tax
CREATE OR REPLACE FUNCTION public._accrue_guild_vault(p_guild_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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

  -- Tax first (uses own FOR UPDATE)
  PERFORM public._apply_guild_vault_daily_tax(p_guild_id);

  SELECT id, vault_last_accrual_at, vault_gold
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
    SELECT vault_gold INTO v_delta FROM public.guilds WHERE id = p_guild_id;
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
    SET vault_gold = vault_gold + v_delta,
        vault_gold_pending = 0,
        vault_last_accrual_at = v_now
    WHERE id = p_guild_id;

    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      p_guild_id,
      auth.uid(),
      'accrue',
      jsonb_build_object('amount', v_delta, 'direct_to_vault', true)
    );
  ELSE
    UPDATE public.guilds
    SET vault_last_accrual_at = v_now,
        vault_gold_pending = 0
    WHERE id = p_guild_id;
  END IF;

  PERFORM public._accrue_guild_vault_territory_loot(p_guild_id);

  SELECT vault_gold INTO v_delta FROM public.guilds WHERE id = p_guild_id;
  RETURN COALESCE(v_delta, 0);
END;
$function$;

-- Batch cron (optional scheduler)
CREATE OR REPLACE FUNCTION public.cron_guild_vault_daily_tax()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_g RECORD;
  v_n INTEGER := 0;
  v_sum BIGINT := 0;
  v_tax BIGINT;
BEGIN
  FOR v_g IN
    SELECT id FROM public.guilds
    WHERE COALESCE(vault_gold, 0) > 0
       OR vault_last_tax_at IS NULL
       OR vault_last_tax_at < now() - interval '1 day'
  LOOP
    v_tax := public._apply_guild_vault_daily_tax(v_g.id);
    IF v_tax > 0 THEN
      v_n := v_n + 1;
      v_sum := v_sum + v_tax;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('guilds_taxed', v_n, 'total_tax', v_sum);
END;
$$;

-- Expose rate on get_guild_vault
CREATE OR REPLACE FUNCTION public.get_guild_vault()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
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

  UPDATE public.guilds
  SET vault_gold = vault_gold + COALESCE(vault_gold_pending, 0),
      vault_gold_pending = 0
  WHERE id = v_guild_id;

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
    'can_collect', false,
    'guild_role', v_role,
    'vault_auto_payout_weekly', COALESCE(v_guild.vault_auto_payout_weekly, false),
    'vault_gold', COALESCE(v_guild.vault_gold, 0),
    'vault_gold_pending', 0,
    'vault_tax_rate', COALESCE(v_guild.tax_rate, 0.05),
    'vault_last_tax_at', v_guild.vault_last_tax_at,
    'monument_gold_pool', COALESCE(v_guild.monument_gold_pool, 0),
    'items', v_items,
    'ledger', v_ledger,
    'territories', v_territories
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public._apply_guild_vault_daily_tax(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._accrue_guild_vault(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_vault() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cron_guild_vault_daily_tax() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cron_guild_vault_daily_tax() TO service_role;

COMMIT;
