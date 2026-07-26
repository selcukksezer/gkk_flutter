-- Staff LiveOps wrapper RPCs (admin-gated).

BEGIN;

CREATE TABLE IF NOT EXISTS public.staff_broadcasts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message TEXT NOT NULL,
  created_by UUID REFERENCES public.users(auth_id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.staff_liveops_rotate_bp_season(p_reason TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.bp_season');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  PERFORM public.cron_bp_season_rotation();

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.bp_season', 'rotate_bp', 'bp_season', NULL,
    jsonb_build_object('reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'BP sezon döndürüldü.');
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_rotate_guild_war_season(p_reason TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.guild_war_season');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  PERFORM public.rotate_guild_war_season();

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.guild_war_season', 'rotate_gw', 'guild_war_season', NULL,
    jsonb_build_object('reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Lonca savaşı sezonu döndürüldü.');
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_get_daily_rewards()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.staff_has_permission(auth.uid(), 'liveops.daily_rewards') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(to_jsonb(c.*) ORDER BY c.cycle_day)
      FROM public.daily_reward_config c
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_upsert_daily_reward(
  p_cycle_day INT,
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
  v_guard := public.staff_require_permission(v_actor, 'liveops.daily_rewards');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  UPDATE public.daily_reward_config
  SET
    gold = COALESCE((p_payload->>'gold')::int, gold),
    gems = COALESCE((p_payload->>'gems')::int, gems),
    item_id = COALESCE(NULLIF(p_payload->>'item_id', ''), item_id),
    item_quantity = COALESCE((p_payload->>'item_quantity')::int, item_quantity)
  WHERE cycle_day = p_cycle_day;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.daily_rewards', 'upsert_daily', 'daily_reward_config', p_cycle_day::text,
    jsonb_build_object('payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_remove_market_listing(p_order_id UUID, p_reason TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'market.remove_listing');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  DELETE FROM public.market_orders WHERE id = p_order_id;

  PERFORM public.staff_write_audit(
    v_actor, 'market.remove_listing', 'remove_listing', 'market_order', p_order_id::text,
    jsonb_build_object('reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_create_broadcast(p_message TEXT, p_hours INT DEFAULT 24)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_id UUID;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.broadcast');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  UPDATE public.staff_broadcasts SET is_active = false WHERE is_active = true;

  INSERT INTO public.staff_broadcasts (message, created_by, expires_at)
  VALUES (left(btrim(p_message), 280), v_actor, now() + make_interval(hours => GREATEST(p_hours, 1)))
  RETURNING id INTO v_id;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.broadcast', 'create_broadcast', 'staff_broadcast', v_id::text,
    jsonb_build_object('message', p_message),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'broadcast_id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_get_bp_rewards(p_season_id UUID DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season UUID;
BEGIN
  IF NOT public.staff_has_permission(auth.uid(), 'liveops.bp_rewards') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  IF p_season_id IS NULL THEN
    SELECT id INTO v_season FROM public.bp_seasons WHERE is_active = true LIMIT 1;
  ELSE
    v_season := p_season_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'season_id', v_season,
    'items', COALESCE((
      SELECT jsonb_agg(to_jsonb(r.*) ORDER BY r.level)
      FROM public.bp_season_rewards r
      WHERE r.season_id = v_season
    ), '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_liveops_rotate_bp_season(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_rotate_guild_war_season(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_get_daily_rewards() TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_upsert_daily_reward(int, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_remove_market_listing(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_create_broadcast(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_get_bp_rewards(uuid) TO authenticated;

COMMIT;
