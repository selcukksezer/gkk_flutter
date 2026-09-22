-- Fix vault item distribute: obtained_at is bigint (epoch), not timestamptz.
-- Also enforce recipient free inventory slots before granting (no orphan consume).

BEGIN;

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
  v_remaining INTEGER;
  v_row RECORD;
  v_space INTEGER;
  v_add INTEGER;
  v_existing_space INTEGER := 0;
  v_required_slots INTEGER := 0;
  v_free_slots INTEGER := 0;
  v_slot INTEGER;
  v_now_epoch BIGINT := EXTRACT(EPOCH FROM now())::BIGINT;
BEGIN
  IF p_auth_id IS NULL OR p_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef/eşya eksik.');
  END IF;

  -- Target must exist
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = p_auth_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef oyuncu bulunamadı.');
  END IF;

  SELECT COALESCE(is_stackable, false), COALESCE(max_stack, 999999)
  INTO v_stackable, v_max_stack
  FROM public.items WHERE id = p_item_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya kataloğunda yok.');
  END IF;

  IF v_max_stack IS NULL OR v_max_stack <= 0 THEN
    v_max_stack := 999999;
  END IF;

  -- Non-stackable / enhanced: each unit needs its own slot (or stack only enh=0 stackables)
  IF v_stackable AND COALESCE(p_enhancement, 0) = 0 THEN
    SELECT COALESCE(SUM(GREATEST(0, v_max_stack - quantity)), 0)
    INTO v_existing_space
    FROM public.inventory
    WHERE user_id = p_auth_id
      AND item_id = p_item_id
      AND COALESCE(is_equipped, false) = false
      AND COALESCE(enhancement_level, 0) = 0;

    IF v_qty > v_existing_space THEN
      v_required_slots := CEIL((v_qty - v_existing_space)::numeric / v_max_stack::numeric)::integer;
    ELSE
      v_required_slots := 0;
    END IF;
  ELSE
    v_existing_space := 0;
    v_required_slots := v_qty; -- one slot per unit
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_free_slots
  FROM generate_series(0, 19) AS s(slot)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.inventory i
    WHERE i.user_id = p_auth_id
      AND i.slot_position = s.slot
      AND COALESCE(i.is_equipped, false) = false
  );

  IF v_free_slots < v_required_slots THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Hedef oyuncunun envanteri dolu.',
      'free_slots', v_free_slots,
      'required_slots', v_required_slots
    );
  END IF;

  v_remaining := v_qty;

  -- Fill existing stacks first
  IF v_stackable AND COALESCE(p_enhancement, 0) = 0 THEN
    FOR v_row IN
      SELECT row_id, quantity FROM public.inventory
      WHERE user_id = p_auth_id
        AND item_id = p_item_id
        AND COALESCE(is_equipped, false) = false
        AND COALESCE(enhancement_level, 0) = 0
      ORDER BY created_at ASC NULLS LAST
    LOOP
      EXIT WHEN v_remaining <= 0;
      v_space := GREATEST(v_max_stack - v_row.quantity, 0);
      IF v_space > 0 THEN
        v_add := LEAST(v_space, v_remaining);
        UPDATE public.inventory
        SET quantity = quantity + v_add, updated_at = now()
        WHERE row_id = v_row.row_id;
        v_remaining := v_remaining - v_add;
      END IF;
    END LOOP;
  END IF;

  -- New rows into free slots
  WHILE v_remaining > 0 LOOP
    v_add := CASE
      WHEN v_stackable AND COALESCE(p_enhancement, 0) = 0 THEN LEAST(v_remaining, v_max_stack)
      ELSE 1
    END;

    SELECT s.slot INTO v_slot
    FROM generate_series(0, 19) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.inventory i
      WHERE i.user_id = p_auth_id
        AND i.slot_position = s.slot
        AND COALESCE(i.is_equipped, false) = false
    )
    ORDER BY s.slot
    LIMIT 1;

    IF v_slot IS NULL THEN
      RAISE EXCEPTION 'Hedef oyuncunun envanteri dolu.'
        USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.inventory (
      user_id, item_id, quantity, enhancement_level, slot_position, obtained_at
    ) VALUES (
      p_auth_id,
      p_item_id,
      v_add,
      COALESCE(p_enhancement, 0),
      v_slot,
      v_now_epoch
    );

    v_remaining := v_remaining - v_add;
  END LOOP;

  RETURN jsonb_build_object('success', true);
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

  -- Grant first (slot check inside). Only then remove from vault.
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

  INSERT INTO public.guild_vault_ledger (guild_id, actor_id, action, payload)
  VALUES (
    v_guild_id, v_leader, 'distribute_item',
    jsonb_build_object(
      'vault_item_id', p_vault_item_id,
      'user_id', v_resolved,
      'quantity', v_qty,
      'item_id', v_item.item_id
    )
  );

  RETURN jsonb_build_object('success', true, 'message', 'Eşya dağıtıldı.');
END;
$$;

GRANT EXECUTE ON FUNCTION public._guild_vault_grant_item(uuid, text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.distribute_guild_vault_item(uuid, uuid, integer) TO authenticated;

COMMIT;
