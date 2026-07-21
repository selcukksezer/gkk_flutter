-- Batch gameplay fixes: equip slot collision, one box opening, weekly leaderboard.

-- ── equip_item: clear incoming slot before moving old equip ─────────────────
CREATE OR REPLACE FUNCTION public.equip_item(p_row_id uuid, p_slot text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_item_record RECORD;
  v_target_slot INTEGER;
  v_new_power NUMERIC;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT row_id, item_id INTO v_item_record
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user_id
  LIMIT 1;

  IF v_item_record IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Item not found or not owned by player');
  END IF;

  SELECT slot_position INTO v_target_slot
  FROM public.inventory
  WHERE row_id = p_row_id
  LIMIT 1;

  -- Free inventory grid slot first (avoid unique slot_position collision).
  UPDATE public.inventory
  SET slot_position = NULL,
      updated_at = NOW()
  WHERE row_id = p_row_id;

  UPDATE public.inventory
  SET is_equipped = FALSE,
      equip_slot = NULL,
      slot_position = v_target_slot,
      updated_at = NOW()
  WHERE user_id = v_user_id
    AND lower(COALESCE(equip_slot, '')) = lower(COALESCE(p_slot, ''))
    AND is_equipped = TRUE
    AND row_id != p_row_id;

  UPDATE public.inventory
  SET is_equipped = TRUE,
      equip_slot = p_slot,
      slot_position = NULL,
      updated_at = NOW()
  WHERE row_id = p_row_id;

    v_new_power := public.calculate_user_total_power(v_user_id);
  UPDATE public.users SET power = v_new_power::integer WHERE auth_id = v_user_id;

  RETURN jsonb_build_object('success', true, 'row_id', p_row_id, 'slot', p_slot);
END;
$$;

-- ── start_box_opening: only one active opening per user ─────────────────────
CREATE OR REPLACE FUNCTION public.start_box_opening(
  p_row_id UUID,
  p_payment TEXT DEFAULT 'gems'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_inv RECORD;
  v_cfg RECORD;
  v_cost NUMERIC := 0;
  v_gems NUMERIC;
  v_opens_at TIMESTAMPTZ;
  v_opening_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_payment NOT IN ('gems', 'ad') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid payment');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.box_openings
    WHERE user_id = v_user_id AND status = 'opening'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten bir kutu açılıyor');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = v_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kutu bulunamadı');
  END IF;

  IF v_inv.item_id NOT LIKE 'box\_%' ESCAPE '\' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu eşya açılabilir bir kutu değil');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.box_openings
    WHERE inventory_row_id = p_row_id AND status = 'opening'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu kutu zaten açılıyor');
  END IF;

  SELECT * INTO v_cfg FROM public.loot_box_configs WHERE id = v_inv.item_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kutu ödül havuzu tanımlı değil');
  END IF;

  IF p_payment = 'gems' THEN
    v_cost := GREATEST(COALESCE(v_cfg.price, 1), 1);
    SELECT gems INTO v_gems FROM public.users WHERE auth_id = v_user_id FOR UPDATE;
    IF COALESCE(v_gems, 0) < v_cost THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz gem');
    END IF;
    UPDATE public.users SET gems = gems - v_cost WHERE auth_id = v_user_id;
    v_opens_at := now();
  ELSE
    v_opens_at := now() + interval '30 minutes';
  END IF;

  INSERT INTO public.box_openings (user_id, inventory_row_id, box_id, payment, gems_spent, opens_at)
  VALUES (v_user_id, p_row_id, v_inv.item_id, p_payment, v_cost, v_opens_at)
  RETURNING id INTO v_opening_id;

  RETURN jsonb_build_object(
    'success', true,
    'opening_id', v_opening_id,
    'opens_at', v_opens_at,
    'gems_spent', v_cost
  );
END;
$$;

-- ── get_leaderboard: weekly branches for all categories ─────────────────────
CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_category text,
  p_limit integer DEFAULT 30,
  p_timeframe text DEFAULT 'alltime'::text
)
RETURNS TABLE(rank integer, username text, value integer, level integer, guild text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_week_start DATE := date_trunc('week', now())::DATE;
BEGIN
  IF p_timeframe = 'weekly' AND p_category = 'pvp_rating' THEN
    IF EXISTS (SELECT 1 FROM public.pvp_leaderboard WHERE week_start = v_week_start) THEN
      RETURN QUERY
      SELECT pl.rank::INT, u.username, pl.rating AS value, u.level, g.name AS guild
      FROM public.pvp_leaderboard pl
      JOIN public.users u ON pl.user_id = u.id
      LEFT JOIN public.guilds g ON u.guild_id = g.id
      WHERE pl.week_start = v_week_start
      ORDER BY pl.rank ASC
      LIMIT p_limit;
      RETURN;
    END IF;
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'guild_power' THEN
    IF EXISTS (SELECT 1 FROM public.guild_leaderboard WHERE week_start = v_week_start) THEN
      RETURN QUERY
      SELECT gl.rank::INT, g.name AS username, gl.monument_level AS value, g.level, g.tag AS guild
      FROM public.guild_leaderboard gl
      JOIN public.guilds g ON gl.guild_id = g.id
      WHERE gl.week_start = v_week_start
      ORDER BY gl.rank ASC
      LIMIT p_limit;
      RETURN;
    END IF;
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'gold' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY COALESCE(w.metric, 0) DESC))::INT AS rank,
      u.username,
      COALESCE(w.metric, 0)::INT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    LEFT JOIN (
      SELECT dr.player_id AS user_id, SUM(COALESCE(dr.gold_earned, 0)) AS metric
      FROM public.dungeon_runs dr
      WHERE dr.created_at >= now() - interval '7 days'
        AND COALESCE(dr.success, false) = true
      GROUP BY dr.player_id
    ) w ON w.user_id = u.auth_id
    WHERE COALESCE(w.metric, 0) > 0
    ORDER BY COALESCE(w.metric, 0) DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'level' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY COALESCE(w.metric, 0) DESC))::INT AS rank,
      u.username,
      COALESCE(w.metric, 0)::INT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    LEFT JOIN (
      SELECT dr.player_id AS user_id, SUM(COALESCE(dr.xp_earned, 0)) AS metric
      FROM public.dungeon_runs dr
      WHERE dr.created_at >= now() - interval '7 days'
        AND COALESCE(dr.success, false) = true
      GROUP BY dr.player_id
    ) w ON w.user_id = u.auth_id
    WHERE COALESCE(w.metric, 0) > 0
    ORDER BY COALESCE(w.metric, 0) DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'power' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY COALESCE(w.metric, 0) DESC))::INT AS rank,
      u.username,
      COALESCE(w.metric, 0)::INT AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    LEFT JOIN (
      SELECT dr.player_id AS user_id, MAX(COALESCE(dr.player_power, 0)) AS metric
      FROM public.dungeon_runs dr
      WHERE dr.created_at >= now() - interval '7 days'
      GROUP BY dr.player_id
    ) w ON w.user_id = u.auth_id
    WHERE COALESCE(w.metric, 0) > 0
    ORDER BY COALESCE(w.metric, 0) DESC
    LIMIT p_limit;
    RETURN;
  END IF;

  IF p_category = 'gold' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY u.gold DESC))::INT AS rank,
      u.username,
      u.gold AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    ORDER BY u.gold DESC
    LIMIT p_limit;
  ELSIF p_category = 'pvp_rating' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY u.pvp_rating DESC))::INT AS rank,
      u.username,
      u.pvp_rating AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    ORDER BY u.pvp_rating DESC
    LIMIT p_limit;
  ELSIF p_category = 'level' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY u.level DESC, u.xp DESC))::INT AS rank,
      u.username,
      u.level AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    ORDER BY u.level DESC, u.xp DESC
    LIMIT p_limit;
  ELSIF p_category = 'power' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY u.power DESC))::INT AS rank,
      u.username,
      u.power AS value,
      u.level,
      g.name AS guild
    FROM public.users u
    LEFT JOIN public.guilds g ON u.guild_id = g.id
    ORDER BY u.power DESC
    LIMIT p_limit;
  ELSIF p_category = 'guild_power' THEN
    RETURN QUERY
    SELECT
      (ROW_NUMBER() OVER (ORDER BY g.xp DESC))::INT AS rank,
      g.name AS username,
      g.xp::INT AS value,
      g.level,
      g.tag AS guild
    FROM public.guilds g
    ORDER BY g.xp DESC
    LIMIT p_limit;
  END IF;
END;
$$;

-- ── get_leaderboard_rank: respect weekly timeframe ──────────────────────────
CREATE OR REPLACE FUNCTION public.get_leaderboard_rank(
  p_category text,
  p_timeframe text DEFAULT 'alltime'::text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_id UUID := auth.uid();
  v_rank INT;
  v_value INT;
  v_rival_value INT;
  v_gap INT;
BEGIN
  IF v_auth_id IS NULL THEN
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF p_timeframe = 'weekly' AND p_category = 'gold' THEN
    WITH weekly AS (
      SELECT u.auth_id,
             COALESCE(SUM(dr.gold_earned), 0)::INT AS metric
      FROM public.users u
      LEFT JOIN public.dungeon_runs dr
        ON dr.player_id = u.auth_id
       AND dr.created_at >= now() - interval '7 days'
       AND COALESCE(dr.success, false) = true
      GROUP BY u.auth_id
    ),
    ranked AS (
      SELECT auth_id, metric,
             ROW_NUMBER() OVER (ORDER BY metric DESC) AS rk
      FROM weekly
      WHERE metric > 0
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_timeframe = 'weekly' AND p_category = 'level' THEN
    WITH weekly AS (
      SELECT u.auth_id,
             COALESCE(SUM(dr.xp_earned), 0)::INT AS metric
      FROM public.users u
      LEFT JOIN public.dungeon_runs dr
        ON dr.player_id = u.auth_id
       AND dr.created_at >= now() - interval '7 days'
       AND COALESCE(dr.success, false) = true
      GROUP BY u.auth_id
    ),
    ranked AS (
      SELECT auth_id, metric,
             ROW_NUMBER() OVER (ORDER BY metric DESC) AS rk
      FROM weekly
      WHERE metric > 0
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_timeframe = 'weekly' AND p_category = 'power' THEN
    WITH weekly AS (
      SELECT u.auth_id,
             COALESCE(MAX(dr.player_power), 0)::INT AS metric
      FROM public.users u
      LEFT JOIN public.dungeon_runs dr
        ON dr.player_id = u.auth_id
       AND dr.created_at >= now() - interval '7 days'
      GROUP BY u.auth_id
    ),
    ranked AS (
      SELECT auth_id, metric,
             ROW_NUMBER() OVER (ORDER BY metric DESC) AS rk
      FROM weekly
      WHERE metric > 0
    )
    SELECT r.rk::INT, r.metric,
           (SELECT metric FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'gold' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.gold AS metric,
             ROW_NUMBER() OVER (ORDER BY u.gold DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'pvp_rating' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.pvp_rating AS metric,
             ROW_NUMBER() OVER (ORDER BY u.pvp_rating DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'level' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.level AS metric,
             ROW_NUMBER() OVER (ORDER BY u.level DESC, u.xp DESC) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'power' THEN
    WITH ranked AS (
      SELECT u.auth_id, u.power AS metric,
             ROW_NUMBER() OVER (ORDER BY u.power DESC NULLS LAST) AS rk
      FROM public.users u
    )
    SELECT r.rk::INT, r.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = r.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM ranked r WHERE r.auth_id = v_auth_id;

  ELSIF p_category = 'guild_power' THEN
    WITH ranked AS (
      SELECT g.id AS guild_id, g.xp AS metric,
             ROW_NUMBER() OVER (ORDER BY g.xp DESC) AS rk
      FROM public.guilds g
    ),
    me AS (
      SELECT r.rk, r.metric
      FROM ranked r
      JOIN public.users u ON u.guild_id = r.guild_id
      WHERE u.auth_id = v_auth_id
    )
    SELECT me.rk::INT, me.metric::INT,
           (SELECT metric::INT FROM ranked WHERE rk = me.rk - 1)
    INTO v_rank, v_value, v_rival_value
    FROM me;

  ELSE
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF v_rank IS NULL THEN
    RETURN json_build_object('rank', NULL, 'value', NULL, 'rival_value', NULL, 'gap', NULL);
  END IF;

  IF v_rank <= 1 OR v_rival_value IS NULL OR v_value IS NULL THEN
    v_gap := 0;
  ELSE
    v_gap := GREATEST(0, v_rival_value - v_value);
  END IF;

  RETURN json_build_object(
    'rank', v_rank,
    'value', v_value,
    'rival_value', v_rival_value,
    'gap', v_gap
  );
END;
$$;
