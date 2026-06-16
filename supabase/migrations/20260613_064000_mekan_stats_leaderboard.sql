-- =========================================================================================
-- MEKAN REDESIGN - PHASE 1: get_mekan_stats + get_mekan_fame_leaderboard.
-- =========================================================================================

-- Owner-only rich stats for the management dashboard.
CREATE OR REPLACE FUNCTION public.get_mekan_stats(p_mekan_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_auth_id UUID;
  v_mekan RECORD;
  v_used INT;
  v_capacity INT;
  v_today_sales INT;
  v_today_revenue BIGINT;
  v_week_customers INT;
  v_top_item TEXT;
  v_top_item_qty INT;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id AND owner_id = v_auth_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi veya size ait degil');
  END IF;

  SELECT COALESCE(SUM(quantity), 0) INTO v_used FROM public.mekan_stock WHERE mekan_id = p_mekan_id;
  v_capacity := public.mekan_total_capacity(v_mekan.mekan_type, v_mekan.level);

  SELECT COALESCE(SUM(quantity), 0), COALESCE(SUM(owner_profit), 0)
    INTO v_today_sales, v_today_revenue
  FROM public.mekan_sales
  WHERE mekan_id = p_mekan_id AND created_at >= (now() - INTERVAL '24 hours');

  SELECT COUNT(DISTINCT buyer_id) INTO v_week_customers
  FROM public.mekan_sales
  WHERE mekan_id = p_mekan_id AND created_at >= (now() - INTERVAL '7 days');

  SELECT item_id, SUM(quantity) INTO v_top_item, v_top_item_qty
  FROM public.mekan_sales
  WHERE mekan_id = p_mekan_id
  GROUP BY item_id
  ORDER BY SUM(quantity) DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'success', true,
    'level', v_mekan.level,
    'fame', v_mekan.fame,
    'suspicion', v_mekan.suspicion,
    'total_revenue', v_mekan.total_revenue,
    'total_sales', v_mekan.total_sales,
    'pvp_match_count', v_mekan.pvp_match_count,
    'used_capacity', v_used,
    'capacity', v_capacity,
    'today_sales', v_today_sales,
    'today_revenue', v_today_revenue,
    'week_customers', v_week_customers,
    'top_item', v_top_item,
    'top_item_qty', COALESCE(v_top_item_qty, 0),
    'monthly_rent', public.mekan_monthly_rent(v_mekan.mekan_type),
    'monthly_rent_paid_at', v_mekan.monthly_rent_paid_at,
    'happy_hour_until', v_mekan.happy_hour_until,
    'next_upgrade_cost', public.mekan_upgrade_cost(v_mekan.level)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_mekan_stats(UUID) TO authenticated;

-- Public fame leaderboard with owner display name.
CREATE OR REPLACE FUNCTION public.get_mekan_fame_leaderboard(p_limit INT DEFAULT 20)
RETURNS JSONB AS $$
DECLARE
  v_rows JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) INTO v_rows
  FROM (
    SELECT
      m.id,
      m.name,
      m.mekan_type,
      m.level,
      m.fame,
      m.is_open,
      u.username AS owner_name,
      ROW_NUMBER() OVER (ORDER BY m.fame DESC, m.level DESC) AS rank
    FROM public.mekans m
    LEFT JOIN public.users u ON u.auth_id = m.owner_id
    ORDER BY m.fame DESC, m.level DESC
    LIMIT GREATEST(1, LEAST(p_limit, 100))
  ) t;

  RETURN jsonb_build_object('success', true, 'leaderboard', v_rows);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_mekan_fame_leaderboard(INT) TO authenticated;
