-- +8/+9 enhancement → global chat (green success, red burn).

BEGIN;

CREATE OR REPLACE FUNCTION public._post_enhance_global_chat(
  p_player_auth_id UUID,
  p_player_name TEXT,
  p_item_name TEXT,
  p_previous_level INT,
  p_new_level INT,
  p_success BOOLEAN,
  p_destroyed BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_attempted INT := COALESCE(p_previous_level, 0) + 1;
  v_body TEXT;
  v_kind TEXT;
  v_tone TEXT;
BEGIN
  IF p_player_auth_id IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.qa_bot_profiles qb WHERE qb.bot_auth_id = p_player_auth_id
  ) THEN
    RETURN;
  END IF;

  IF COALESCE(p_destroyed, false) AND COALESCE(p_previous_level, 0) >= 8 THEN
    v_body := '💥 '
      || public._ticker_clip_name(COALESCE(p_player_name, 'Oyuncu'))
      || ' +' || p_previous_level::text || ' '
      || public._ticker_clip_label(COALESCE(p_item_name, 'eşya'), 'eşya')
      || ' yandı!';
    v_kind := 'enhance_burn';
    v_tone := 'danger';
  ELSIF COALESCE(p_success, false) AND v_attempted >= 8 THEN
    v_body := '✨ '
      || public._ticker_clip_name(COALESCE(p_player_name, 'Oyuncu'))
      || ' +' || COALESCE(p_new_level, v_attempted)::text || ' '
      || public._ticker_clip_label(COALESCE(p_item_name, 'eşya'), 'eşya')
      || ' güçlendirdi! (+'
      || p_previous_level::text
      || ' → +'
      || COALESCE(p_new_level, v_attempted)::text
      || ')';
    v_kind := 'enhance_success';
    v_tone := 'success';
  ELSE
    RETURN;
  END IF;

  PERFORM public._post_global_announcement_chat(
    p_player_auth_id,
    v_body,
    v_kind,
    jsonb_build_object(
      'tone', v_tone,
      'previous_level', p_previous_level,
      'new_level', p_new_level,
      'destroyed', COALESCE(p_destroyed, false),
      'success', COALESCE(p_success, false)
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public._post_enhance_global_chat(uuid, text, text, integer, integer, boolean, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._post_enhance_global_chat(uuid, text, text, integer, integer, boolean, boolean) FROM anon;
REVOKE ALL ON FUNCTION public._post_enhance_global_chat(uuid, text, text, integer, integer, boolean, boolean) FROM authenticated;

CREATE OR REPLACE FUNCTION public.enhance_item(
  p_player_id UUID,
  p_row_id UUID,
  p_rune_type TEXT DEFAULT 'none'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_item RECORD;
  v_player RECORD;
  v_rarity_mult NUMERIC;
  v_base_cost INTEGER;
  v_gold_cost INTEGER;
  v_success_rate NUMERIC;
  v_destroy_rate NUMERIC;
  v_success BOOLEAN;
  v_destroyed BOOLEAN := false;
  v_new_level INTEGER;
  v_scroll_id TEXT;
  v_has_scroll BOOLEAN;
  v_has_rune BOOLEAN;
  v_debug JSONB := '{}'::jsonb;
  v_catalog_can_enhance BOOLEAN;
  v_item_name TEXT;
BEGIN
  IF p_player_id != auth.uid() THEN
    v_debug := jsonb_build_object('player_id', p_player_id, 'auth_uid', auth.uid());
    RETURN jsonb_build_object('error', 'Yetkisiz işlem', 'debug', v_debug);
  END IF;

  SELECT inv.*, items.rarity, items.name AS catalog_name, items.can_enhance AS catalog_can_enhance
  INTO v_item
  FROM public.inventory inv
  JOIN public.items ON items.id = inv.item_id
  WHERE inv.row_id = p_row_id AND inv.user_id = p_player_id;

  v_catalog_can_enhance := COALESCE(v_item.catalog_can_enhance, v_item.can_enhance, false);
  v_item_name := COALESCE(v_item.catalog_name, v_item.item_id);

  IF NOT FOUND THEN
    v_debug := jsonb_build_object('player_id', p_player_id, 'row_id', p_row_id);
    RETURN jsonb_build_object('error', 'item_not_found', 'debug', v_debug);
  END IF;

  IF NOT v_catalog_can_enhance THEN
    v_debug := jsonb_build_object(
      'item_id', v_item.item_id,
      'catalog_id', v_item.item_id,
      'rarity', v_item.rarity,
      'inv_can_enhance', v_item.can_enhance,
      'catalog_can_enhance', v_catalog_can_enhance,
      'enhancement_level', v_item.enhancement_level
    );
    RETURN jsonb_build_object('error', 'cannot_enhance', 'debug', v_debug);
  END IF;

  IF v_item.enhancement_level >= 10 THEN
    v_debug := jsonb_build_object('item_id', v_item.item_id, 'enhancement_level', v_item.enhancement_level);
    RETURN jsonb_build_object('error', 'max_level', 'debug', v_debug);
  END IF;

  SELECT * INTO v_player FROM public.users WHERE auth_id = p_player_id;

  v_rarity_mult := CASE v_item.rarity
    WHEN 'common' THEN 1.0
    WHEN 'uncommon' THEN 1.5
    WHEN 'rare' THEN 2.5
    WHEN 'epic' THEN 4.0
    WHEN 'legendary' THEN 7.0
    WHEN 'mythic' THEN 12.0
    ELSE 1.0
  END;

  v_base_cost := (ARRAY[100000,200000,300000,500000,1500000,3500000,7500000,15000000,50000000,200000000,1000000000])[v_item.enhancement_level + 1];
  v_gold_cost := floor(v_base_cost * v_rarity_mult);
  v_gold_cost := floor(v_gold_cost * public._monument_enhancement_gold_multiplier(public._monument_level_for_auth(p_player_id)));

  IF v_player.gold < v_gold_cost THEN
    v_debug := jsonb_build_object('player_gold', v_player.gold, 'required_gold', v_gold_cost);
    RETURN jsonb_build_object('error', 'insufficient_gold', 'debug', v_debug);
  END IF;

  v_scroll_id := CASE
    WHEN v_item.rarity IN ('common', 'uncommon') THEN 'scroll_upgrade_low'
    WHEN v_item.rarity IN ('rare', 'epic') THEN 'scroll_upgrade_middle'
    ELSE 'scroll_upgrade_high'
  END;

  SELECT EXISTS(
    SELECT 1 FROM public.inventory
    WHERE user_id = p_player_id AND item_id = v_scroll_id AND quantity > 0
  ) INTO v_has_scroll;

  IF NOT v_has_scroll THEN
    v_debug := jsonb_build_object('scroll_id', v_scroll_id, 'has_scroll', v_has_scroll);
    RETURN jsonb_build_object('error', 'no_scroll', 'debug', v_debug);
  END IF;

  IF p_rune_type != 'none' THEN
    SELECT EXISTS(
      SELECT 1 FROM public.inventory
      WHERE user_id = p_player_id AND item_id = 'rune_' || p_rune_type AND quantity > 0
    ) INTO v_has_rune;

    IF NOT v_has_rune THEN
      v_debug := jsonb_build_object('requested_rune', p_rune_type, 'has_rune', v_has_rune);
      RETURN jsonb_build_object('error', 'no_rune', 'debug', v_debug);
    END IF;
  END IF;

  v_success_rate := (ARRAY[1.0,1.0,1.0,1.0,0.7,0.6,0.5,0.35,0.2,0.1,0.03])[v_item.enhancement_level + 1];
  v_destroy_rate := (ARRAY[0,0,0,0,0,0,1.0,1.0,1.0,1.0,1.0])[v_item.enhancement_level + 1];

  IF p_rune_type = 'basic' THEN v_success_rate := v_success_rate + 0.05;
  ELSIF p_rune_type = 'advanced' THEN v_success_rate := v_success_rate + 0.10;
  ELSIF p_rune_type = 'superior' THEN v_success_rate := v_success_rate + 0.15; v_destroy_rate := v_destroy_rate * 0.5;
  ELSIF p_rune_type = 'legendary' THEN v_success_rate := v_success_rate + 0.25; v_destroy_rate := v_destroy_rate * 0.25;
  ELSIF p_rune_type = 'protection' THEN v_destroy_rate := 0;
  ELSIF p_rune_type = 'blessed' THEN v_success_rate := v_success_rate + 0.20; v_destroy_rate := v_destroy_rate * 0.5;
  END IF;

  v_success_rate := LEAST(1.0, v_success_rate);
  IF v_item.enhancement_level >= 6 THEN
    v_destroy_rate := GREATEST(0, v_destroy_rate - public._monument_enhancement_destroy_reduction(public._monument_level_for_auth(p_player_id)));
  END IF;
  v_destroy_rate := GREATEST(0, v_destroy_rate);

  v_success := random() <= v_success_rate;
  v_new_level := v_item.enhancement_level;

  IF v_success THEN
    v_new_level := v_item.enhancement_level + 1;
  ELSE
    IF v_item.enhancement_level >= 6 AND p_rune_type != 'protection' AND p_rune_type != 'blessed' THEN
      IF random() <= v_destroy_rate THEN
        v_destroyed := true;
      ELSE
        v_new_level := GREATEST(0, v_item.enhancement_level - 1);
      END IF;
    ELSIF p_rune_type = 'blessed' THEN
      v_new_level := v_item.enhancement_level;
    ELSE
      v_new_level := GREATEST(0, v_item.enhancement_level - 1);
    END IF;
  END IF;

  IF NOT public._consume_inventory_item(p_player_id, v_scroll_id, 1) THEN
    v_debug := jsonb_build_object('scroll_id', v_scroll_id, 'expected_decrement', 1);
    RETURN jsonb_build_object('error', 'Geliştirme parşömeni yetersiz', 'debug', v_debug);
  END IF;

  IF p_rune_type != 'none' THEN
    IF NOT public._consume_inventory_item(p_player_id, 'rune_' || p_rune_type, 1) THEN
      RAISE EXCEPTION 'Seçilen rune yetersiz';
    END IF;
  END IF;

  UPDATE public.users SET gold = gold - v_gold_cost WHERE auth_id = p_player_id AND gold >= v_gold_cost;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'İşlem sırasında altın yetersiz kaldı';
  END IF;

  IF v_destroyed THEN
    DELETE FROM public.inventory WHERE row_id = p_row_id;
  ELSE
    UPDATE public.inventory SET enhancement_level = v_new_level WHERE row_id = p_row_id;
  END IF;

  INSERT INTO public.enhancement_history (
    player_id, item_id, item_row_id, previous_level, attempted_level, new_level,
    rune_used, scroll_used, gold_spent, success, destroyed, success_rate_at_attempt
  ) VALUES (
    p_player_id, v_item.item_id, p_row_id, v_item.enhancement_level, v_item.enhancement_level + 1, v_new_level,
    p_rune_type, v_scroll_id, v_gold_cost, v_success, v_destroyed, v_success_rate
  );

  PERFORM public._post_enhance_global_chat(
    p_player_id,
    COALESCE(v_player.display_name, v_player.username, 'Oyuncu'),
    v_item_name,
    v_item.enhancement_level,
    v_new_level,
    v_success,
    v_destroyed
  );

  v_debug := jsonb_build_object(
    'item_id', v_item.item_id,
    'previous_level', v_item.enhancement_level,
    'attempted_level', v_item.enhancement_level + 1,
    'new_level', v_new_level,
    'rune_used', p_rune_type,
    'scroll_used', v_scroll_id,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1),
    'inv_can_enhance', v_item.can_enhance,
    'catalog_can_enhance', v_catalog_can_enhance
  );

  RETURN jsonb_build_object(
    'success', v_success,
    'destroyed', v_destroyed,
    'new_level', v_new_level,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1),
    'debug', v_debug
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.enhance_item(uuid, uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.get_chat_history(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.get_chat_history(
  p_channel TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  channel TEXT,
  sender_id UUID,
  sender_name TEXT,
  content TEXT,
  "timestamp" TIMESTAMPTZ,
  is_system BOOLEAN,
  recipient_user_id UUID,
  guild_id UUID,
  sender_staff_badge TEXT,
  sender_king_badge TEXT,
  sender_guild_name TEXT,
  sender_auth_id UUID,
  deleted_at TIMESTAMPTZ,
  metadata JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  v_user := public.get_current_chat_user();

  IF p_channel NOT IN ('global', 'guild', 'dm', 'trade', 'system') THEN
    RAISE EXCEPTION 'Gecersiz kanal';
  END IF;

  IF p_channel = 'guild' AND v_user.guild_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    cm.id,
    cm.channel,
    cm.sender_user_id,
    cm.sender_name,
    CASE
      WHEN cm.deleted_at IS NOT NULL THEN COALESCE(
        NULLIF(btrim(cm.content), ''),
        public.format_chat_deleted_notice(cm.deleted_by_user_id)
      )
      ELSE cm.content
    END,
    cm.created_at,
    cm.is_system,
    cm.recipient_user_id,
    cm.guild_id,
    public.get_public_staff_badge(u.auth_id) AS sender_staff_badge,
    public.get_public_king_badge(u.auth_id) AS sender_king_badge,
    COALESCE(g.name, NULLIF(cm.metadata->>'sender_guild_name', '')) AS sender_guild_name,
    u.auth_id AS sender_auth_id,
    cm.deleted_at,
    COALESCE(cm.metadata, '{}'::jsonb) AS metadata
  FROM public.chat_messages cm
  LEFT JOIN public.users u ON u.id = cm.sender_user_id
  LEFT JOIN public.guilds g ON g.id = u.guild_id
  WHERE cm.channel = p_channel
    AND (
      p_channel IN ('global', 'trade', 'system')
      OR (p_channel = 'guild' AND cm.guild_id = v_user.guild_id)
      OR (p_channel = 'dm' AND (cm.sender_user_id = v_user.id OR cm.recipient_user_id = v_user.id))
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE cb.blocker_user_id = v_user.id
        AND cb.blocked_user_id = cm.sender_user_id
        AND cm.deleted_at IS NULL
    )
  ORDER BY cm.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_chat_history(text, integer) TO authenticated;

COMMIT;
