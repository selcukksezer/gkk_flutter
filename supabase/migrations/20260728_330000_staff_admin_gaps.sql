-- Admin gaps: chat moderator bridge, bug detail RPC, liveops shop/night market.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_sync_chat_moderator(
  p_target_user_id UUID,
  p_enable BOOLEAN DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_game_user_id UUID;
  v_has_chat BOOLEAN;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'staff.manage_gm');
  IF (v_guard->>'ok')::boolean IS NOT TRUE
     AND NOT public.staff_is_admin(v_actor) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  SELECT u.id INTO v_game_user_id FROM public.users u WHERE u.auth_id = p_target_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  IF NOT p_enable THEN
    UPDATE public.chat_moderators
    SET revoked_at = now()
    WHERE user_id = v_game_user_id AND revoked_at IS NULL;
    RETURN jsonb_build_object('success', true, 'enabled', false);
  END IF;

  v_has_chat := public.staff_has_permission(p_target_user_id, 'chat.delete_message')
    OR public.staff_has_permission(p_target_user_id, 'chat.manage_filters')
    OR public.staff_has_permission(p_target_user_id, 'chat.view_reports');

  IF NOT v_has_chat AND NOT public.staff_is_admin(p_target_user_id) THEN
    UPDATE public.chat_moderators
    SET revoked_at = now()
    WHERE user_id = v_game_user_id AND revoked_at IS NULL;
    RETURN jsonb_build_object('success', true, 'enabled', false);
  END IF;

  UPDATE public.chat_moderators
  SET revoked_at = now()
  WHERE user_id = v_game_user_id AND revoked_at IS NULL;

  INSERT INTO public.chat_moderators (
    user_id, scope, channel, guild_id,
    can_delete, can_ban, can_manage_filters, can_manage_moderators, assigned_by_user_id
  )
  SELECT
    v_game_user_id, 'channel', 'global', NULL,
    public.staff_has_permission(p_target_user_id, 'chat.delete_message') OR public.staff_is_admin(p_target_user_id),
    public.staff_has_permission(p_target_user_id, 'player.chat_mute') OR public.staff_is_admin(p_target_user_id),
    public.staff_has_permission(p_target_user_id, 'chat.manage_filters') OR public.staff_is_admin(p_target_user_id),
    false,
    (SELECT u.id FROM public.users u WHERE u.auth_id = v_actor);

  RETURN jsonb_build_object('success', true, 'enabled', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_get_bug_report_detail(p_report_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_b RECORD;
BEGIN
  IF NOT public.staff_has_permission(v_actor, 'bug.view') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  SELECT b.*, u.username
  INTO v_b
  FROM public.bug_reports b
  JOIN public.users u ON u.auth_id = b.player_id
  WHERE b.id = p_report_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rapor bulunamadı.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'report', jsonb_build_object(
      'id', v_b.id,
      'player_id', v_b.player_id,
      'username', v_b.username,
      'category', v_b.category,
      'title', v_b.title,
      'description', v_b.description,
      'repro_steps', v_b.repro_steps,
      'client_meta', v_b.client_meta,
      'status', v_b.status,
      'reward_gems_approved', v_b.reward_gems_approved,
      'review_note', v_b.review_note,
      'created_at', v_b.created_at
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_list_shop_items(p_limit INT DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.staff_has_permission(auth.uid(), 'liveops.shop_catalog') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', i.id,
        'name', i.name,
        'shop_available', i.shop_available,
        'shop_currency', i.shop_currency,
        'base_price', i.base_price
      ) ORDER BY i.name)
      FROM public.items i
      WHERE i.shop_available = true
      LIMIT LEAST(GREATEST(p_limit, 1), 200)
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_update_shop_item(
  p_item_id TEXT,
  p_payload JSONB,
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
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.shop_catalog');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  UPDATE public.items
  SET
    shop_available = COALESCE((p_payload->>'shop_available')::boolean, shop_available),
    shop_currency = COALESCE(NULLIF(p_payload->>'shop_currency', ''), shop_currency),
    base_price = COALESCE((p_payload->>'base_price')::int, base_price)
  WHERE id = p_item_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item bulunamadı.');
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.shop_catalog', 'update_shop_item', 'item', p_item_id,
    jsonb_build_object('payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_list_night_market_offers(p_limit INT DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.staff_has_permission(auth.uid(), 'liveops.night_market') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', o.id,
        'item_id', o.item_id,
        'item_name', i.name,
        'price_gems', o.gem_price,
        'stock', o.stock_per_player,
        'rotation_week', o.rotation_week
      ) ORDER BY o.rotation_week DESC, i.name)
      FROM public.night_market_offers o
      JOIN public.items i ON i.id = o.item_id
      LIMIT LEAST(GREATEST(p_limit, 1), 100)
    ), '[]'::jsonb)
  );
END;
$$;

-- After GM permission changes, sync chat_moderators bridge.
CREATE OR REPLACE FUNCTION public.staff_assign_gm(
  p_target_user_id UUID,
  p_permissions TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_sa_id UUID;
  v_perm TEXT;
  v_result JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'staff.manage_gm');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_target_user_id = v_actor THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kendinize GM atayamazsınız.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadı.');
  END IF;

  UPDATE public.staff_assignments
  SET revoked_at = now(), revoke_reason = 'replaced'
  WHERE user_id = p_target_user_id AND revoked_at IS NULL;

  INSERT INTO public.staff_assignments (user_id, role, display_badge, granted_by)
  VALUES (p_target_user_id, 'gm', 'gm', v_actor)
  RETURNING id INTO v_sa_id;

  DELETE FROM public.staff_permissions WHERE staff_assignment_id = v_sa_id;

  FOREACH v_perm IN ARRAY COALESCE(p_permissions, ARRAY[]::TEXT[])
  LOOP
    IF EXISTS (SELECT 1 FROM public.staff_permission_catalog WHERE key = v_perm AND min_role = 'gm') THEN
      INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
      VALUES (v_sa_id, v_perm)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
  VALUES (v_sa_id, 'staff.view_hub')
  ON CONFLICT DO NOTHING;

  PERFORM public.staff_write_audit(
    v_actor, 'staff.manage_gm', 'assign_gm', 'user', p_target_user_id::text,
    jsonb_build_object('permissions', p_permissions),
    jsonb_build_object('assignment_id', v_sa_id)
  );

  PERFORM public.staff_sync_chat_moderator(p_target_user_id, true);

  RETURN jsonb_build_object('success', true, 'assignment_id', v_sa_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_set_gm_permissions(
  p_target_user_id UUID,
  p_permissions TEXT[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_sa_id UUID;
  v_perm TEXT;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'staff.manage_gm');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF public.staff_is_admin(p_target_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin izinleri değiştirilemez.');
  END IF;

  SELECT id INTO v_sa_id
  FROM public.staff_assignments
  WHERE user_id = p_target_user_id AND revoked_at IS NULL AND role = 'gm'
  LIMIT 1;

  IF v_sa_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif GM ataması yok.');
  END IF;

  DELETE FROM public.staff_permissions WHERE staff_assignment_id = v_sa_id;

  FOREACH v_perm IN ARRAY COALESCE(p_permissions, ARRAY[]::TEXT[])
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.staff_permission_catalog
      WHERE key = v_perm AND min_role = 'gm'
    ) THEN
      INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
      VALUES (v_sa_id, v_perm)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  INSERT INTO public.staff_permissions (staff_assignment_id, permission_key)
  VALUES (v_sa_id, 'staff.view_hub')
  ON CONFLICT DO NOTHING;

  PERFORM public.staff_write_audit(
    v_actor, 'staff.manage_gm', 'set_permissions', 'user', p_target_user_id::text,
    jsonb_build_object('permissions', p_permissions),
    jsonb_build_object('success', true)
  );

  PERFORM public.staff_sync_chat_moderator(p_target_user_id, true);

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_sync_chat_moderator(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_get_bug_report_detail(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_list_shop_items(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_update_shop_item(text, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_list_night_market_offers(int) TO authenticated;

COMMIT;
