-- ══════════════════════════════════════════════════════════════════════════════
-- Migration: 20261029_040000_add_missing_rpcs.sql
-- Description: Implements missing RPC functions called in Dart repositories
--              and screens to achieve 100% backend contract parity and eliminate
--              PGRST202 runtime errors:
--              1. split_stack_item(p_row_id, p_split_quantity, p_target_slot)
--              2. trash_item(p_row_id)
--              3. toggle_item_favorite(p_row_id, p_is_favorite)
--              4. send_notification(p_username, p_type, p_message)
--              5. collect_facility_production(p_facility_id) wrapper
-- ══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. split_stack_item ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.split_stack_item(
  p_row_id uuid,
  p_split_quantity integer,
  p_target_slot integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_item_id text;
  v_quantity integer;
  v_is_equipped boolean;
  v_metadata jsonb;
  v_resolved_slot integer;
  v_new_row_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Lock source item row
  SELECT item_id, quantity, is_equipped, metadata
  INTO v_item_id, v_quantity, v_is_equipped, v_metadata
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user_id
  FOR UPDATE;

  IF v_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item bulunamadı.');
  END IF;

  IF v_is_equipped THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşanılmış item bölünemez.');
  END IF;

  IF p_split_quantity <= 0 OR p_split_quantity >= v_quantity THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz bölme miktarı.');
  END IF;

  -- Determine target slot
  v_resolved_slot := p_target_slot;
  IF v_resolved_slot IS NULL OR v_resolved_slot < 0 THEN
    -- Find lowest free inventory slot position (0..199)
    SELECT s.slot INTO v_resolved_slot
    FROM generate_series(0, 199) AS s(slot)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = v_user_id
        AND slot_position = s.slot
        AND is_equipped = false
    )
    ORDER BY s.slot
    LIMIT 1;

    IF v_resolved_slot IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Envanterde boş slot bulunamadı.');
    END IF;
  ELSE
    -- Verify explicitly chosen slot is not occupied
    IF EXISTS (
      SELECT 1 FROM public.inventory
      WHERE user_id = v_user_id
        AND slot_position = v_resolved_slot
        AND is_equipped = false
        AND row_id <> p_row_id
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hedef slot dolu.');
    END IF;
  END IF;

  -- Deduct split quantity from source
  UPDATE public.inventory
  SET quantity = quantity - p_split_quantity,
      updated_at = now()
  WHERE row_id = p_row_id;

  -- Insert new stack row
  INSERT INTO public.inventory (
    user_id, item_id, quantity, slot_position, is_equipped, is_favorite, metadata, created_at, updated_at
  ) VALUES (
    v_user_id, v_item_id, p_split_quantity, v_resolved_slot, false, false, v_metadata, now(), now()
  ) RETURNING row_id INTO v_new_row_id;

  RETURN jsonb_build_object(
    'success', true,
    'new_row_id', v_new_row_id,
    'target_slot', v_resolved_slot,
    'remaining_quantity', v_quantity - p_split_quantity
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.split_stack_item(uuid, integer, integer) TO authenticated;

-- ── 2. trash_item ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trash_item(p_row_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_equipped boolean;
  v_item_id text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Lock row
  SELECT is_equipped, item_id
  INTO v_is_equipped, v_item_id
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user_id
  FOR UPDATE;

  IF v_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item bulunamadı.');
  END IF;

  IF v_is_equipped THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kuşanılmış item silinemez.');
  END IF;

  DELETE FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'Item başarıyla silindi.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.trash_item(uuid) TO authenticated;

-- ── 3. toggle_item_favorite ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_item_favorite(
  p_row_id uuid,
  p_is_favorite boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  UPDATE public.inventory
  SET is_favorite = p_is_favorite,
      updated_at = now()
  WHERE row_id = p_row_id AND user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item bulunamadı.');
  END IF;

  RETURN jsonb_build_object('success', true, 'is_favorite', p_is_favorite);
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_item_favorite(uuid, boolean) TO authenticated;

-- ── 4. send_notification ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.send_notification(
  p_username text,
  p_type text,
  p_message text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sender_id uuid := auth.uid();
  v_target_user_id uuid;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Resolve recipient user
  SELECT auth_id INTO v_target_user_id
  FROM public.users
  WHERE lower(username) = lower(p_username)
  LIMIT 1;

  IF v_target_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı: ' || p_username);
  END IF;

  -- Ensure inbox table exists and record notification
  INSERT INTO public.player_inbox_notifications (
    user_id, kind, title, body, payload
  ) VALUES (
    v_target_user_id,
    COALESCE(p_type, 'party_invite'),
    'Parti Daveti',
    COALESCE(p_message, ''),
    jsonb_build_object('sender_auth_id', v_sender_id)
  );

  RETURN jsonb_build_object('success', true, 'recipient_id', v_target_user_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_notification(text, text, text) TO authenticated;

-- ── 5. collect_facility_production wrapper ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.collect_facility_production(p_facility_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Delegate directly to the canonical 3-argument collector
  RETURN public.collect_facility_resources_v2(p_facility_id, 0, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.collect_facility_production(uuid) TO authenticated;

COMMIT;
