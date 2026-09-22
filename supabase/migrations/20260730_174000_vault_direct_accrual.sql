-- Territory income accrues directly into vault_gold (no pending collect step).

BEGIN;

-- Fold any leftover pending into spendable vault
UPDATE public.guilds
SET vault_gold = COALESCE(vault_gold, 0) + COALESCE(vault_gold_pending, 0),
    vault_gold_pending = 0
WHERE COALESCE(vault_gold_pending, 0) > 0;

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

-- Siege / tournament credits → spendable vault
CREATE OR REPLACE FUNCTION public.credit_guild_vault_pending(
  p_guild_id uuid,
  p_amount bigint,
  p_source_type text,
  p_ref text DEFAULT NULL::text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_amount BIGINT := GREATEST(COALESCE(p_amount, 0), 0);
BEGIN
  IF p_guild_id IS NULL OR v_amount <= 0 THEN
    RETURN 0;
  END IF;

  UPDATE public.guilds
  SET vault_gold = vault_gold + v_amount,
      vault_gold_pending = 0
  WHERE id = p_guild_id;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    p_guild_id,
    auth.uid(),
    COALESCE(p_source_type, 'credit'),
    jsonb_build_object('amount', v_amount, 'ref', p_ref, 'direct_to_vault', true)
  );

  RETURN v_amount;
END;
$function$;

-- Collect deprecated: accrue only (pending already folded)
CREATE OR REPLACE FUNCTION public.collect_guild_vault_rewards()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_guild_id UUID;
  v_gold BIGINT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  PERFORM public._accrue_guild_vault(v_guild_id);

  -- Safety: fold any residual pending
  UPDATE public.guilds
  SET vault_gold = vault_gold + COALESCE(vault_gold_pending, 0),
      vault_gold_pending = 0
  WHERE id = v_guild_id
  RETURNING vault_gold INTO v_gold;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Gelir otomatik kasaya işlenir — toplama gerekmez.',
    'collected', 0,
    'vault_gold', v_gold,
    'collect_removed', true
  );
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
  v_spend BIGINT;
  v_members INTEGER;
  v_per BIGINT;
BEGIN
  FOR v_g IN
    SELECT * FROM public.guilds WHERE vault_auto_payout_weekly = true FOR UPDATE
  LOOP
    PERFORM public._accrue_guild_vault(v_g.id);

    -- Residual pending safety
    UPDATE public.guilds
    SET vault_gold = vault_gold + COALESCE(vault_gold_pending, 0),
        vault_gold_pending = 0
    WHERE id = v_g.id;

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

-- get_guild_vault: keep live shape; can_collect=false; fold residual pending
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
    'monument_gold_pool', COALESCE(v_guild.monument_gold_pool, 0),
    'items', v_items,
    'ledger', v_ledger,
    'territories', v_territories
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public._accrue_guild_vault(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.credit_guild_vault_pending(uuid, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.collect_guild_vault_rewards() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_vault() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cron_guild_vault_weekly_payout() TO service_role;

COMMIT;
