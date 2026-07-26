-- LiveOps plan: BP upsert, market browse, GW force rotate, daily reward fields, night market edit.

BEGIN;

CREATE OR REPLACE FUNCTION public.staff_liveops_list_market_orders(
  p_query TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
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
  IF NOT (
    public.staff_has_permission(v_actor, 'market.remove_listing')
    OR public.staff_has_permission(v_actor, 'market.edit_listing')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', COALESCE((
      SELECT jsonb_agg(row ORDER BY row->>'created_at' DESC)
      FROM (
        SELECT jsonb_build_object(
          'id', mo.id,
          'seller_auth_id', u.auth_id,
          'seller_username', u.username,
          'item_id', mo.item_id,
          'item_name', i.name,
          'price', mo.price,
          'quantity', mo.quantity,
          'created_at', mo.created_at
        ) AS row
        FROM public.market_orders mo
        JOIN public.users u ON u.auth_id = mo.seller_id
        JOIN public.items i ON i.id = mo.item_id
        WHERE mo.status = 'open'
          AND (
            v_q = ''
            OR lower(u.username) LIKE '%' || v_q || '%'
            OR lower(i.name) LIKE '%' || v_q || '%'
            OR mo.id::text = v_q
          )
        ORDER BY mo.created_at DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 100)
        OFFSET GREATEST(p_offset, 0)
      ) sub
    ), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_upsert_bp_reward(
  p_season_id UUID,
  p_track TEXT,
  p_level INT,
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
  v_guard := public.staff_require_permission(v_actor, 'liveops.bp_rewards');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_track NOT IN ('free', 'vip') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Track free veya vip olmalı.');
  END IF;

  INSERT INTO public.bp_season_rewards (
    season_id, track, level, reward_type, reward_value, item_id, display_name
  )
  VALUES (
    p_season_id,
    p_track,
    p_level,
    COALESCE(p_payload->>'reward_type', 'gold'),
    COALESCE(p_payload->'reward_value', '{}'::jsonb),
    NULLIF(p_payload->>'item_id', ''),
    NULLIF(p_payload->>'display_name', '')
  )
  ON CONFLICT (season_id, track, level) DO UPDATE SET
    reward_type = EXCLUDED.reward_type,
    reward_value = EXCLUDED.reward_value,
    item_id = EXCLUDED.item_id,
    display_name = EXCLUDED.display_name,
    updated_at = now();

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.bp_rewards', 'upsert_bp_reward', 'bp_season', p_season_id::text,
    jsonb_build_object('track', p_track, 'level', p_level, 'payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_rotate_bp_season(p_reason TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_old_season UUID;
  v_new_season UUID;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.bp_season');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  SELECT id INTO v_old_season
  FROM public.bp_seasons
  WHERE is_active = true
  ORDER BY season_num DESC
  LIMIT 1;

  PERFORM public.cron_bp_season_rotation();

  SELECT id INTO v_new_season
  FROM public.bp_seasons
  WHERE is_active = true
  ORDER BY season_num DESC
  LIMIT 1;

  IF v_old_season IS NOT NULL AND v_new_season IS NOT NULL AND v_old_season <> v_new_season THEN
    INSERT INTO public.bp_season_rewards (
      season_id, track, level, reward_type, reward_value, item_id, display_name, is_active
    )
    SELECT
      v_new_season, r.track, r.level, r.reward_type, r.reward_value, r.item_id, r.display_name, r.is_active
    FROM public.bp_season_rewards r
    WHERE r.season_id = v_old_season
    ON CONFLICT (season_id, track, level) DO NOTHING;
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.bp_season', 'rotate_bp', 'bp_season', v_new_season::text,
    jsonb_build_object('reason', p_reason, 'old_season_id', v_old_season),
    jsonb_build_object('success', true, 'new_season_id', v_new_season)
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'BP sezon döndürüldü.',
    'old_season_id', v_old_season,
    'new_season_id', v_new_season
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_force_rotate_guild_war_season(
  p_force BOOLEAN DEFAULT false,
  p_reason TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_guard JSONB;
  v_rotated BOOLEAN := false;
BEGIN
  v_guard := public.staff_require_permission(v_actor, 'liveops.guild_war_season');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_force THEN
    UPDATE public.guild_war_seasons
    SET end_at = now() - interval '1 minute'
    WHERE is_active = true AND end_at > now();
    v_rotated := FOUND;
  END IF;

  PERFORM public.rotate_guild_war_season();

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.guild_war_season', 'rotate_gw', 'guild_war_season', NULL,
    jsonb_build_object('force', p_force, 'reason', p_reason, 'forced_end', v_rotated),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true, 'forced', p_force);
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

  INSERT INTO public.daily_reward_config (
    cycle_day, gold, gems, xp, energy, item_id, item_quantity,
    display_label, is_milestone, level_multiplier
  )
  VALUES (
    p_cycle_day,
    COALESCE((p_payload->>'gold')::int, 0),
    COALESCE((p_payload->>'gems')::int, 0),
    COALESCE((p_payload->>'xp')::int, 0),
    COALESCE((p_payload->>'energy')::int, 0),
    NULLIF(p_payload->>'item_id', ''),
    COALESCE((p_payload->>'item_quantity')::int, 0),
    NULLIF(p_payload->>'display_label', ''),
    COALESCE((p_payload->>'is_milestone')::boolean, false),
    COALESCE((p_payload->>'level_multiplier')::boolean, true)
  )
  ON CONFLICT (cycle_day) DO UPDATE SET
    gold = EXCLUDED.gold,
    gems = EXCLUDED.gems,
    xp = EXCLUDED.xp,
    energy = EXCLUDED.energy,
    item_id = EXCLUDED.item_id,
    item_quantity = EXCLUDED.item_quantity,
    display_label = EXCLUDED.display_label,
    is_milestone = EXCLUDED.is_milestone,
    level_multiplier = EXCLUDED.level_multiplier;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.daily_rewards', 'upsert_daily', 'daily_reward', p_cycle_day::text,
    jsonb_build_object('payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_upsert_night_market_offer(
  p_offer_id UUID,
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
  v_guard := public.staff_require_permission(v_actor, 'liveops.night_market');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  IF p_offer_id IS NULL THEN
    INSERT INTO public.night_market_offers (item_id, gem_price, stock_per_player, rotation_week)
    VALUES (
      p_payload->>'item_id',
      COALESCE((p_payload->>'price_gems')::bigint, 0),
      COALESCE((p_payload->>'stock')::int, 1),
      COALESCE((p_payload->>'rotation_week')::date, CURRENT_DATE)
    );
  ELSE
    UPDATE public.night_market_offers
    SET
      gem_price = COALESCE((p_payload->>'price_gems')::bigint, gem_price),
      stock_per_player = COALESCE((p_payload->>'stock')::int, stock_per_player),
      rotation_week = COALESCE((p_payload->>'rotation_week')::date, rotation_week)
    WHERE id = p_offer_id;
  END IF;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.night_market', 'upsert_night_market', 'night_market', COALESCE(p_offer_id::text, p_payload->>'item_id'),
    jsonb_build_object('payload', p_payload, 'reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_liveops_delete_night_market_offer(
  p_offer_id UUID,
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
  v_guard := public.staff_require_permission(v_actor, 'liveops.night_market');
  IF (v_guard->>'ok')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', v_guard->>'error');
  END IF;

  DELETE FROM public.night_market_offers WHERE id = p_offer_id;

  PERFORM public.staff_write_audit(
    v_actor, 'liveops.night_market', 'delete_night_market', 'night_market', p_offer_id::text,
    jsonb_build_object('reason', p_reason),
    jsonb_build_object('success', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.staff_liveops_list_market_orders(text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_upsert_bp_reward(uuid, text, int, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_force_rotate_guild_war_season(boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_upsert_night_market_offer(uuid, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_liveops_delete_night_market_offer(uuid, text) TO authenticated;

COMMIT;
