-- Vault history feed: up to 500 rows for client search/filter/pagination.

BEGIN;

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
    'icon', COALESCE(i.icon, ''),
    'item_type', lower(COALESCE(i.type, 'misc')),
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
    'payload', COALESCE(l.payload, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
      'item_name', COALESCE(NULLIF(l.payload->>'item_name', ''), it.name),
      'to_username', COALESCE(NULLIF(l.payload->>'to_username', ''), ru.username),
      'territory_name', COALESCE(NULLIF(l.payload->>'territory_name', ''), tt.name)
    )),
    'actor_id', l.actor_id,
    'actor_name', au.username,
    'created_at', l.created_at
  ) ORDER BY l.created_at DESC), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT *
    FROM public.guild_vault_ledger
    WHERE guild_id = v_guild_id
    ORDER BY created_at DESC
    LIMIT 500
  ) l
  LEFT JOIN public.users au ON au.auth_id = l.actor_id
  LEFT JOIN public.items it ON it.id = l.payload->>'item_id'
  LEFT JOIN public.users ru ON ru.auth_id::text = l.payload->>'user_id'
  LEFT JOIN public.guild_war_territories tt ON tt.id::text = l.payload->>'territory_id';

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
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_vault() TO authenticated;

COMMIT;
