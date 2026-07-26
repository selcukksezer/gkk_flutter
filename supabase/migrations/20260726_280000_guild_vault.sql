-- Lonca kasası: birikim, toplama, gold/item dağıtım, ledger.

BEGIN;

ALTER TABLE public.guilds
  ADD COLUMN IF NOT EXISTS vault_gold BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vault_gold_pending BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vault_last_accrual_at TIMESTAMPTZ;

-- Migrate legacy territory_income into pending once
UPDATE public.guilds
SET vault_gold_pending = vault_gold_pending + COALESCE(territory_income, 0),
    territory_income = 0
WHERE COALESCE(territory_income, 0) > 0;

CREATE TABLE IF NOT EXISTS public.guild_vault_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL REFERENCES public.items(id),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  source_type TEXT NOT NULL DEFAULT 'territory_loot',
  source_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_guild_vault_items_guild
  ON public.guild_vault_items(guild_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.guild_vault_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id UUID NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_guild_vault_ledger_guild
  ON public.guild_vault_ledger(guild_id, created_at DESC);

ALTER TABLE public.guild_vault_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guild_vault_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS guild_vault_items_select ON public.guild_vault_items;
CREATE POLICY guild_vault_items_select ON public.guild_vault_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid() AND u.guild_id = guild_vault_items.guild_id
    )
  );

DROP POLICY IF EXISTS guild_vault_ledger_select ON public.guild_vault_ledger;
CREATE POLICY guild_vault_ledger_select ON public.guild_vault_ledger
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid() AND u.guild_id = guild_vault_ledger.guild_id
    )
  );

CREATE OR REPLACE FUNCTION public._accrue_guild_vault(p_guild_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_guild RECORD;
  v_now TIMESTAMPTZ := now();
  v_from TIMESTAMPTZ;
  v_hours NUMERIC;
  v_cap_hours NUMERIC := 168; -- 7 days
  v_delta BIGINT := 0;
  v_row RECORD;
BEGIN
  IF p_guild_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT id, vault_last_accrual_at, vault_gold_pending
  INTO v_guild
  FROM public.guilds
  WHERE id = p_guild_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  v_from := COALESCE(v_guild.vault_last_accrual_at, v_now - interval '1 hour');
  v_hours := EXTRACT(EPOCH FROM (v_now - v_from)) / 3600.0;
  IF v_hours <= 0 THEN
    RETURN v_guild.vault_gold_pending;
  END IF;
  v_hours := LEAST(v_hours, v_cap_hours);

  FOR v_row IN
    SELECT COALESCE(trade_income, 0) AS trade_income
    FROM public.guild_war_territories
    WHERE owner_guild_id = p_guild_id
  LOOP
    v_delta := v_delta + (v_row.trade_income * v_hours / 24.0)::BIGINT;
  END LOOP;

  IF v_delta > 0 THEN
    UPDATE public.guilds
    SET vault_gold_pending = vault_gold_pending + v_delta,
        vault_last_accrual_at = v_now
    WHERE id = p_guild_id;

    INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
    VALUES (
      p_guild_id,
      auth.uid(),
      'accrue',
      jsonb_build_object('amount', v_delta, 'hours', v_hours)
    );
  ELSE
    UPDATE public.guilds
    SET vault_last_accrual_at = v_now
    WHERE id = p_guild_id;
  END IF;

  SELECT vault_gold_pending INTO v_delta FROM public.guilds WHERE id = p_guild_id;
  RETURN COALESCE(v_delta, 0);
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
  v_items JSONB;
  v_ledger JSONB;
  v_territories JSONB;
  v_is_leader BOOLEAN;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT guild_id INTO v_guild_id FROM public.users WHERE auth_id = v_user;
  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  PERFORM public._accrue_guild_vault(v_guild_id);

  SELECT g.*, (g.leader_id = v_user) AS is_leader
  INTO v_guild
  FROM public.guilds g
  WHERE g.id = v_guild_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', vi.id,
    'item_id', vi.item_id,
    'item_name', COALESCE(i.name, vi.item_id),
    'rarity', i.rarity,
    'quantity', vi.quantity,
    'source_type', vi.source_type,
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
    'created_at', l.created_at
  ) ORDER BY l.created_at DESC), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT * FROM public.guild_vault_ledger
    WHERE guild_id = v_guild_id
    ORDER BY created_at DESC
    LIMIT 50
  ) l;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'name', t.name,
    'trade_income', COALESCE(t.trade_income, 0),
    'zone_number', t.zone_number
  ) ORDER BY t.zone_number NULLS LAST), '[]'::jsonb)
  INTO v_territories
  FROM public.guild_war_territories t
  WHERE t.owner_guild_id = v_guild_id;

  RETURN jsonb_build_object(
    'success', true,
    'guild_id', v_guild_id,
    'is_leader', v_guild.leader_id = v_user,
    'vault_gold', COALESCE(v_guild.vault_gold, 0),
    'vault_gold_pending', COALESCE(v_guild.vault_gold_pending, 0),
    'monument_gold_pool', COALESCE(v_guild.monument_gold_pool, 0),
    'items', v_items,
    'ledger', v_ledger,
    'territories', v_territories
  );
END;
$$;

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
  v_amount BIGINT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT u.guild_id INTO v_guild_id FROM public.users u WHERE u.auth_id = v_user;
  IF v_guild_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Lonca üyesi değilsiniz.');
  END IF;

  SELECT * INTO v_guild FROM public.guilds WHERE id = v_guild_id FOR UPDATE;
  IF v_guild.leader_id IS DISTINCT FROM v_user THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sadece lonca lideri toplayabilir.');
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
  VALUES (v_guild_id, v_user, 'collect', jsonb_build_object('amount', v_amount));

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Gelir lonca kasasına aktarıldı.',
    'collected', v_amount,
    'vault_gold', (SELECT vault_gold FROM public.guilds WHERE id = v_guild_id)
  );
END;
$$;

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
  v_amount BIGINT;
  v_spent BIGINT := 0;
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
    FOR v_entry IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'allocations', '[]'::jsonb))
    LOOP
      v_target := (v_entry->>'user_id')::UUID;
      v_amount := COALESCE((v_entry->>'amount')::BIGINT, 0);
      IF v_target IS NULL OR v_amount <= 0 THEN
        CONTINUE;
      END IF;
      IF NOT EXISTS (
        SELECT 1 FROM public.users u WHERE u.auth_id = v_target AND u.guild_id = v_guild_id
      ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Hedef üye loncada değil.');
      END IF;
      UPDATE public.users SET gold = COALESCE(gold, 0) + v_amount WHERE auth_id = v_target;
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

  IF NOT EXISTS (
    SELECT 1 FROM public.users u WHERE u.auth_id = p_user_id AND u.guild_id = v_guild_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef üye loncada değil.');
  END IF;

  v_add := public.add_inventory_item_v2(
    jsonb_build_object('item_id', v_item.item_id, 'quantity', v_qty, 'allow_stack', true),
    p_user_id
  );

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
    jsonb_build_object('vault_item_id', p_vault_item_id, 'user_id', p_user_id, 'quantity', v_qty, 'item_id', v_item.item_id)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Eşya dağıtıldı.');
END;
$$;

-- Backward compat wrapper
CREATE OR REPLACE FUNCTION public.distribute_territory_income(p_amount INTEGER)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result JSONB;
BEGIN
  v_result := public.distribute_guild_vault_gold(
    jsonb_build_object('mode', 'equal', 'amount', GREATEST(COALESCE(p_amount, 0), 0))
  );
  RETURN v_result::json;
END;
$$;

CREATE OR REPLACE FUNCTION public.collect_territory_income()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Deprecated: accrual is on-demand via _accrue_guild_vault / get_guild_vault.
  NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_guild_vault() TO authenticated;
GRANT EXECUTE ON FUNCTION public.collect_guild_vault_rewards() TO authenticated;
GRANT EXECUTE ON FUNCTION public.distribute_guild_vault_gold(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.distribute_guild_vault_item(uuid, uuid, integer) TO authenticated;

COMMIT;
