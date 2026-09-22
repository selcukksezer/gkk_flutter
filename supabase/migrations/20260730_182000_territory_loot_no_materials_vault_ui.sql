-- Territory vault loot: never materials.
-- get_guild_vault items: icon + item_type for inventory-style UI.

BEGIN;

-- Purge existing material / resource rows from guild vaults (territory loot junk).
DELETE FROM public.guild_vault_items vi
USING public.items i
WHERE i.id = vi.item_id
  AND (
    lower(COALESCE(i.type, '')) IN ('material', 'resource')
    OR lower(vi.item_id) LIKE 'res\_%' ESCAPE '\'
    OR lower(vi.item_id) LIKE 'mat\_%' ESCAPE '\'
  );

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

  -- Gear / usable rewards only — materials/resources hard-banned.
  SELECT i.id INTO v_item_id
  FROM public.items i
  WHERE lower(COALESCE(i.rarity, '')) = v_rarity
    AND COALESCE(i.cosmetic_showcase_only, false) = false
    AND COALESCE(i.cosmetic_bind_on_pickup, false) = false
    AND lower(COALESCE(i.type, '')) IN (
      'weapon', 'armor', 'potion', 'consumable', 'scroll', 'rune', 'box', 'catalyst'
    )
    AND lower(COALESCE(i.id, '')) NOT LIKE 'res\_%' ESCAPE '\'
    AND lower(COALESCE(i.id, '')) NOT LIKE 'mat\_%' ESCAPE '\'
    AND lower(COALESCE(i.id, '')) NOT LIKE '%name_change%'
    AND lower(COALESCE(i.id, '')) NOT LIKE '%rename%'
    AND lower(COALESCE(i.id, '')) NOT LIKE '%junk%'
    AND lower(COALESCE(i.id, '')) NOT LIKE '%test\_%' ESCAPE '\'
    AND lower(COALESCE(i.name, '')) NOT LIKE '%isim değiştir%'
    AND lower(COALESCE(i.name, '')) NOT LIKE '%junk%'
    AND lower(COALESCE(i.name, '')) NOT LIKE '%test item%'
  ORDER BY random()
  LIMIT 1;

  IF v_item_id IS NULL THEN
    SELECT i.id INTO v_item_id
    FROM public.items i
    WHERE lower(COALESCE(i.rarity, '')) NOT IN ('common', '')
      AND COALESCE(i.cosmetic_showcase_only, false) = false
      AND lower(COALESCE(i.type, '')) IN (
        'weapon', 'armor', 'potion', 'consumable', 'scroll', 'rune', 'box', 'catalyst'
      )
      AND lower(COALESCE(i.id, '')) NOT LIKE 'res\_%' ESCAPE '\'
      AND lower(COALESCE(i.id, '')) NOT LIKE 'mat\_%' ESCAPE '\'
      AND lower(COALESCE(i.id, '')) NOT LIKE '%name_change%'
      AND lower(COALESCE(i.id, '')) NOT LIKE '%junk%'
      AND lower(COALESCE(i.name, '')) NOT LIKE '%isim değiştir%'
    ORDER BY random()
    LIMIT 1;
  END IF;

  RETURN v_item_id;
END;
$$;

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
$$;

GRANT EXECUTE ON FUNCTION public._pick_territory_loot_item_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_vault() TO authenticated;

COMMIT;
