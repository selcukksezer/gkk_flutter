-- Staff inventory editor: search items, view player inventory, safer adjust/set/remove.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_search_items(
  p_query TEXT DEFAULT NULL,
  p_limit INT DEFAULT 40
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_q TEXT := lower(btrim(COALESCE(p_query, '')));
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'player.adjust_inventory') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'name')
      FROM (
        SELECT jsonb_build_object(
          'id', i.id,
          'name', i.name,
          'item_type', lower(COALESCE(i.type, 'misc')),
          'rarity', lower(COALESCE(i.rarity, 'common')),
          'is_stackable', COALESCE(i.is_stackable, false),
          'max_stack', GREATEST(1, COALESCE(i.max_stack, 999))
        ) AS row
        FROM public.items i
        WHERE v_q = ''
           OR lower(i.id) LIKE '%' || v_q || '%'
           OR lower(COALESCE(i.name, '')) LIKE '%' || v_q || '%'
        ORDER BY i.name
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_get_player_inventory(p_target_user_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'player.adjust_inventory') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY (row->>'is_equipped')::boolean DESC, row->>'name')
      FROM (
        SELECT jsonb_build_object(
          'row_id', inv.row_id,
          'item_id', inv.item_id,
          'name', COALESCE(it.name, inv.item_id),
          'quantity', inv.quantity,
          'is_equipped', COALESCE(inv.is_equipped, false),
          'equipped_slot', COALESCE(inv.equip_slot, ''),
          'enhancement_level', COALESCE(inv.enhancement_level, 0),
          'is_stackable', COALESCE(it.is_stackable, false),
          'max_stack', GREATEST(1, COALESCE(it.max_stack, 999)),
          'rarity', lower(COALESCE(it.rarity, 'common')),
          'item_type', lower(COALESCE(it.type, 'misc'))
        ) AS row
        FROM public.inventory inv
        LEFT JOIN public.items it ON it.id = inv.item_id
        WHERE inv.user_id = p_target_user_id
          AND inv.quantity > 0
        ORDER BY COALESCE(inv.is_equipped, false) DESC, COALESCE(it.name, inv.item_id)
      ) sub
    ), '[]'::jsonb),
    'slot_count', (
      SELECT COUNT(*)::int
      FROM public.inventory inv
      WHERE inv.user_id = p_target_user_id
        AND inv.is_equipped = false
        AND inv.quantity > 0
    ),
    'capacity', 20
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_remove_inventory_row(
  p_target_user_id UUID,
  p_row_id UUID,
  p_reason TEXT,
  p_force_equipped BOOLEAN DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_row RECORD;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.adjust_inventory');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  SELECT inv.row_id, inv.item_id, inv.quantity, inv.is_equipped, it.name
  INTO v_row
  FROM public.inventory inv
  LEFT JOIN public.items it ON it.id = inv.item_id
  WHERE inv.row_id = p_row_id
    AND inv.user_id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Envanter satırı bulunamadı.');
  END IF;

  IF COALESCE(v_row.is_equipped, false) AND NOT COALESCE(p_force_equipped, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşanılmış eşya — zorla silme onayı gerekli.');
  END IF;

  DELETE FROM public.inventory WHERE row_id = p_row_id AND user_id = p_target_user_id;

  PERFORM public._notify_player_staff_action(
    p_target_user_id,
    'staff_inventory',
    'Envanteriniz düzenlendi',
    format('Silindi: %s x%s\nSebep: %s', COALESCE(v_row.name, v_row.item_id), v_row.quantity, left(p_reason, 300)),
    jsonb_build_object('row_id', p_row_id, 'item_id', v_row.item_id, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.adjust_inventory', 'adjust_inventory', 'user', p_target_user_id::text,
    jsonb_build_object('row_id', p_row_id, 'item_id', v_row.item_id, 'delta', -v_row.quantity, 'reason', p_reason, 'action', 'remove_row'),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_set_inventory_quantity(
  p_target_user_id UUID,
  p_item_id TEXT,
  p_quantity INT,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_target INT := GREATEST(COALESCE(p_quantity, 0), 0);
  v_current INT := 0;
  v_delta INT;
  v_stackable BOOLEAN;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.adjust_inventory');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.items WHERE id = p_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşya.');
  END IF;

  SELECT COALESCE(is_stackable, false) INTO v_stackable FROM public.items WHERE id = p_item_id;
  IF NOT v_stackable THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu eşya stack değil — satır sil/ekle kullanın.');
  END IF;

  SELECT COALESCE(SUM(quantity), 0) INTO v_current
  FROM public.inventory
  WHERE user_id = p_target_user_id
    AND item_id = p_item_id
    AND COALESCE(is_equipped, false) = false;

  v_delta := v_target - v_current;
  IF v_delta = 0 THEN
    RETURN jsonb_build_object('success', true, 'message', 'Değişiklik yok.');
  END IF;

  RETURN public.staff_adjust_inventory(
    p_target_user_id,
    p_item_id,
    v_delta,
    left(p_reason || format(' (hedef: %s)', v_target), 500)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_adjust_inventory(
  p_target_user_id UUID,
  p_item_id TEXT,
  p_quantity_delta INT,
  p_reason TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_delta INT := COALESCE(p_quantity_delta, 0);
  v_item RECORD;
  v_row_id UUID;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'player.adjust_inventory');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF char_length(btrim(COALESCE(p_reason, ''))) < 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Sebep gerekli (min 3 karakter).');
  END IF;

  IF v_delta = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Miktar değişimi 0 olamaz.');
  END IF;

  IF ABS(v_delta) > 9999 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Tek seferde en fazla ±9999.');
  END IF;

  SELECT id, COALESCE(name, id) AS name, COALESCE(is_stackable, false) AS is_stackable
  INTO v_item
  FROM public.items
  WHERE id = p_item_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşya ID.');
  END IF;

  IF v_delta > 0 THEN
    IF NOT public.market_give_items(p_target_user_id, p_item_id, v_delta, 0) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu veya eşya eklenemedi.');
    END IF;
  ELSE
    SELECT inv.row_id INTO v_row_id
    FROM public.inventory inv
    WHERE inv.user_id = p_target_user_id
      AND inv.item_id = p_item_id
      AND inv.quantity >= ABS(v_delta)
      AND COALESCE(inv.is_equipped, false) = false
    ORDER BY inv.quantity DESC
    LIMIT 1;

    IF v_row_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yeterli miktar yok veya eşya kuşanılmış.');
    END IF;

    UPDATE public.inventory
    SET quantity = quantity + v_delta,
        updated_at = now()
    WHERE row_id = v_row_id;

    DELETE FROM public.inventory
    WHERE row_id = v_row_id AND quantity <= 0;
  END IF;

  PERFORM public._notify_player_staff_action(
    p_target_user_id,
    'staff_inventory',
    'Envanteriniz düzenlendi',
    format('Eşya: %s (%s)\nDeğişim: %s\nSebep: %s', v_item.name, p_item_id, v_delta, left(p_reason, 300)),
    jsonb_build_object('item_id', p_item_id, 'delta', v_delta, 'reason', p_reason)
  );

  PERFORM public.staff_write_audit(
    v_actor, 'player.adjust_inventory', 'adjust_inventory', 'user', p_target_user_id::text,
    jsonb_build_object('item_id', p_item_id, 'delta', v_delta, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'delta', v_delta);
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_search_items(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_get_player_inventory(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_remove_inventory_row(uuid, uuid, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_set_inventory_quantity(uuid, text, int, text) TO authenticated;

COMMIT;
