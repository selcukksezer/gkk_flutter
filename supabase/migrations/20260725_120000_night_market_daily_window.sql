-- Gece Pazarı: Cuma-only → her gün 20:00–22:00 Europe/Istanbul

ALTER TABLE public.night_market_schedule
  ALTER COLUMN weekday DROP NOT NULL;

UPDATE public.night_market_schedule
SET weekday = NULL,
    start_hour = 20,
    end_hour = 22,
    timezone = 'Europe/Istanbul'
WHERE id = 1;

CREATE OR REPLACE FUNCTION public._night_market_window(p_now TIMESTAMPTZ DEFAULT now())
RETURNS TABLE (
  active BOOLEAN,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  seconds_left INTEGER,
  rotation_week DATE
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_sched RECORD;
  v_local TIMESTAMP;
  v_hour INT;
  v_start_local TIMESTAMP;
  v_end_local TIMESTAMP;
  -- QA: test için true yap — pencere beklemeden pazar açık
  v_qa_force_open BOOLEAN := false;
BEGIN
  SELECT * INTO v_sched FROM public.night_market_schedule WHERE id = 1;

  v_local := (p_now AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul'));
  v_hour := EXTRACT(HOUR FROM v_local)::INT;

  v_start_local := date_trunc('day', v_local)
    + make_interval(hours => COALESCE(v_sched.start_hour, 20));
  v_end_local := date_trunc('day', v_local)
    + make_interval(hours => COALESCE(v_sched.end_hour, 22));

  -- Günlük pencere: bugünkü slot bittiyse yarın
  IF v_hour >= COALESCE(v_sched.end_hour, 22) THEN
    v_start_local := v_start_local + interval '1 day';
    v_end_local := v_end_local + interval '1 day';
  END IF;

  starts_at := v_start_local AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul');
  ends_at := v_end_local AT TIME ZONE COALESCE(v_sched.timezone, 'Europe/Istanbul');
  rotation_week := date_trunc('week', starts_at)::DATE;

  IF v_qa_force_open THEN
    active := true;
    seconds_left := GREATEST(0, EXTRACT(EPOCH FROM (ends_at - p_now))::INT);
  ELSE
    active := p_now >= starts_at AND p_now < ends_at;
    seconds_left := CASE
      WHEN active THEN GREATEST(0, EXTRACT(EPOCH FROM (ends_at - p_now))::INT)
      WHEN p_now < starts_at THEN GREATEST(0, EXTRACT(EPOCH FROM (starts_at - p_now))::INT)
      ELSE 0
    END;
  END IF;

  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.buy_night_market_item(
  p_offer_id UUID,
  p_quantity INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_win RECORD;
  v_offer RECORD;
  v_item RECORD;
  v_shadow BOOLEAN := false;
  v_discount NUMERIC := 0;
  v_stock INT;
  v_purchased INT;
  v_unit_price BIGINT;
  v_total BIGINT;
  v_gems NUMERIC;
  v_add JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_quantity < 1 OR p_quantity > 99 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
  END IF;

  SELECT * INTO v_win FROM public._night_market_window();
  IF NOT v_win.active THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gece Pazarı şu an kapalı. Her gün 20:00–22:00 (TR)');
  END IF;

  SELECT o.*, i.name, i.is_stackable, i.max_stack
  INTO v_offer
  FROM public.night_market_offers o
  JOIN public.items i ON i.id = o.item_id
  WHERE o.id = p_offer_id AND o.rotation_week = v_win.rotation_week;

  IF v_offer.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Offer not found');
  END IF;

  SELECT lower(character_class) = 'shadow' INTO v_shadow FROM public.users WHERE auth_id = v_user;
  IF v_shadow THEN v_discount := 0.05; END IF;

  v_stock := v_offer.stock_per_player + CASE WHEN v_shadow THEN 1 ELSE 0 END;
  SELECT COALESCE(quantity, 0) INTO v_purchased
  FROM public.night_market_purchases
  WHERE player_id = v_user AND offer_id = p_offer_id;

  IF v_purchased + p_quantity > v_stock THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz');
  END IF;

  v_unit_price := floor(v_offer.gem_price * (1 - v_discount))::BIGINT;
  v_total := v_unit_price * p_quantity;

  SELECT gems INTO v_gems FROM public.users WHERE auth_id = v_user;
  IF COALESCE(v_gems, 0) < v_total THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
  END IF;

  UPDATE public.users SET gems = gems - v_total WHERE auth_id = v_user;

  v_add := public.add_inventory_item_v2(
    jsonb_build_object('item_id', v_offer.item_id, 'quantity', p_quantity, 'allow_stack', true),
    NULL
  );

  IF COALESCE((v_add->>'success')::BOOLEAN, false) = false THEN
    UPDATE public.users SET gems = gems + v_total WHERE auth_id = v_user;
    RETURN jsonb_build_object('success', false, 'error', COALESCE(v_add->>'error', 'Inventory failed'));
  END IF;

  INSERT INTO public.night_market_purchases (player_id, offer_id, quantity)
  VALUES (v_user, p_offer_id, p_quantity)
  ON CONFLICT (player_id, offer_id) DO UPDATE SET
    quantity = night_market_purchases.quantity + EXCLUDED.quantity,
    purchased_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'item_id', v_offer.item_id,
    'quantity', p_quantity,
    'total_cost', v_total,
    'currency', 'gems'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._comeback_retention_items(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_items JSONB := '[]'::JSONB;
  v_discovered INT;
  v_claimable_codex INT;
  v_nem RECORD;
  v_rival RECORD;
  v_win RECORD;
BEGIN
  IF p_user_id IS NULL THEN RETURN v_items; END IF;

  v_discovered := public._codex_discovered_count(p_user_id);
  SELECT COUNT(*) INTO v_claimable_codex
  FROM (VALUES (10), (25), (50), (100)) AS t(th)
  WHERE v_discovered >= t.th
    AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = p_user_id AND m.threshold = t.th AND m.claimed_at IS NOT NULL
    );
  IF v_claimable_codex > 0 THEN
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', 'codex:milestone',
      'kind', 'codex_milestone',
      'title', 'Kodex kilometre taşı',
      'subtitle', v_claimable_codex::text || ' ödül alınabilir.',
      'route', '/character/codex?claim=1',
      'priority', 88,
      'cta_label', 'Al'
    ));
  END IF;

  PERFORM public.refresh_player_nemesis(p_user_id);
  SELECT * INTO v_nem FROM public.player_nemesis_state WHERE player_id = p_user_id;
  IF v_nem.nemesis_id IS NOT NULL AND v_nem.losses >= 1
     AND (v_nem.dismissed_until IS NULL OR v_nem.dismissed_until <= now()) THEN
    SELECT COALESCE(display_name, username) INTO v_rival FROM public.users WHERE auth_id = v_nem.nemesis_id;
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', 'nemesis:revenge',
      'kind', 'nemesis_revenge',
      'title', 'Nemesis intikamı',
      'subtitle', COALESCE(v_rival, 'Rakip') || ' — ' || v_nem.losses::text || ' yenilgi.',
      'route', '/pvp?revenge=' || v_nem.nemesis_id::text,
      'priority', 86,
      'cta_label', 'Düello'
    ));
  END IF;

  SELECT * INTO v_win FROM public._night_market_window();
  IF v_win.active THEN
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', 'night_market:open',
      'kind', 'night_market',
      'title', 'Gece Pazarı açık',
      'subtitle', 'Günlük gem teklifleri — sınırlı stok.',
      'route', '/shop?tab=night',
      'priority', 90,
      'cta_label', 'Git'
    ));
  END IF;

  RETURN v_items;
END;
$$;
