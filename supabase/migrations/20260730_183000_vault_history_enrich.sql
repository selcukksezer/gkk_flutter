-- Vault history: enrich ledger payloads (who/what/where) + longer feed.

BEGIN;

-- Territory loot ledger: item + territory names
CREATE OR REPLACE FUNCTION public._accrue_guild_vault_territory_loot(p_guild_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row RECORD;
  v_state RECORD;
  v_added INTEGER := 0;
  v_loot_cooldown INTERVAL := interval '24 hours';
  v_drop_count INTEGER;
  v_i INTEGER;
  v_item_id TEXT;
  v_item_name TEXT;
  v_territory_name TEXT;
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  FOR v_row IN
    SELECT t.id AS territory_id, t.name AS territory_name
    FROM public.guild_war_territories t
    WHERE t.owner_guild_id = p_guild_id
  LOOP
    SELECT * INTO v_state
    FROM public.guild_vault_territory_loot_state
    WHERE guild_id = p_guild_id AND territory_id = v_row.territory_id;

    IF FOUND AND v_state.last_loot_at > now() - v_loot_cooldown THEN
      CONTINUE;
    END IF;

    v_drop_count := 6 + CASE WHEN random() < 0.5 THEN 1 ELSE 0 END;
    v_territory_name := COALESCE(v_row.territory_name, 'Bölge');

    FOR v_i IN 1..v_drop_count LOOP
      v_item_id := public._pick_territory_loot_item_id();
      IF v_item_id IS NULL THEN
        CONTINUE;
      END IF;

      SELECT COALESCE(name, v_item_id) INTO v_item_name
      FROM public.items WHERE id = v_item_id;

      INSERT INTO public.guild_vault_items (guild_id, item_id, quantity, source_type, source_ref)
      VALUES (p_guild_id, v_item_id, 1, 'territory_loot', v_row.territory_id::text);

      INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
      VALUES (
        p_guild_id,
        auth.uid(),
        'territory_loot',
        jsonb_build_object(
          'territory_id', v_row.territory_id,
          'territory_name', v_territory_name,
          'item_id', v_item_id,
          'item_name', COALESCE(v_item_name, v_item_id),
          'quantity', 1
        )
      );

      v_added := v_added + 1;
    END LOOP;

    INSERT INTO public.guild_vault_territory_loot_state (guild_id, territory_id, last_loot_at)
    VALUES (p_guild_id, v_row.territory_id, now())
    ON CONFLICT (guild_id, territory_id) DO UPDATE
      SET last_loot_at = EXCLUDED.last_loot_at;
  END LOOP;

  RETURN v_added;
END;
$$;

-- Item distribute: store recipient + item name
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
  v_item_name TEXT;
  v_to_username TEXT;
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
      'error', COALESCE(v_add->>'error', 'Hedef oyuncunun envanteri dolu — eşya verilemedi.'),
      'free_slots', v_add->'free_slots',
      'required_slots', v_add->'required_slots'
    );
  END IF;

  IF v_qty = v_item.quantity THEN
    DELETE FROM public.guild_vault_items WHERE id = v_item.id;
  ELSE
    UPDATE public.guild_vault_items SET quantity = quantity - v_qty WHERE id = v_item.id;
  END IF;

  SELECT COALESCE(name, v_item.item_id) INTO v_item_name FROM public.items WHERE id = v_item.item_id;
  SELECT username INTO v_to_username FROM public.users WHERE auth_id = v_resolved;

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild_id, v_leader, 'distribute_item',
    jsonb_build_object(
      'vault_item_id', p_vault_item_id,
      'user_id', v_resolved,
      'to_username', COALESCE(v_to_username, 'üye'),
      'quantity', v_qty,
      'item_id', v_item.item_id,
      'item_name', COALESCE(v_item_name, v_item.item_id),
      'enhancement_level', v_enh
    )
  );

  RETURN jsonb_build_object('success', true, 'message', 'Eşya dağıtıldı.');
END;
$$;

-- Gold distribute: store recipients
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
  v_recipients JSONB := '[]'::jsonb;
  v_uname TEXT;
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

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'user_id', u.auth_id,
      'username', u.username,
      'amount', v_per_member
    ) ORDER BY u.username), '[]'::jsonb)
    INTO v_recipients
    FROM public.users u
    WHERE u.guild_id = v_guild_id;
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
      SELECT username INTO v_uname FROM public.users WHERE auth_id = v_resolved;
      v_recipients := v_recipients || jsonb_build_array(jsonb_build_object(
        'user_id', v_resolved,
        'username', COALESCE(v_uname, 'üye'),
        'amount', v_amount
      ));
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
  VALUES (
    v_guild_id, v_user, 'distribute_gold',
    jsonb_build_object(
      'mode', v_mode,
      'amount', v_spent,
      'per_member', v_per_member,
      'member_count', v_member_count,
      'recipients', v_recipients
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Altın dağıtıldı.',
    'distributed', v_spent,
    'vault_gold', (SELECT vault_gold FROM public.guilds WHERE id = v_guild_id)
  );
END;
$$;

-- get_guild_vault: enrich history for old + new rows, longer feed
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
    LIMIT 150
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

GRANT EXECUTE ON FUNCTION public._accrue_guild_vault_territory_loot(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.distribute_guild_vault_item(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.distribute_guild_vault_gold(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_guild_vault() TO authenticated;

COMMIT;
