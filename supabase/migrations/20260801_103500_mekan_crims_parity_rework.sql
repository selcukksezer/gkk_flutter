-- =========================================================================================
-- MEKAN CRIMS PARITY REWORK
-- Polarity flip: club = energy/stamina REFILL via ticket + bar consumable (stock shelf).
-- Deprecate hang_out / join_party as core loop (RPCs kept, return deprecated).
-- Own mekan = safer/cheaper refill. Addiction/tolerance → price up + OD → hospital.
-- Respect/level gates by mekan type. Facilities untouched.
-- =========================================================================================

-- ── Ticket + session OD state ─────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_tickets integer NOT NULL DEFAULT 48;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_tickets_day date;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_refill_mekan_id uuid;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_refill_count integer NOT NULL DEFAULT 0;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nightlife_refill_session_until timestamptz;

COMMENT ON COLUMN public.users.nightlife_tickets IS 'Nightlife tickets: spent on energy refill at mekan (Crims-like).';
COMMENT ON COLUMN public.users.nightlife_refill_count IS 'Refills in current club session; 2nd at foreign club = OD.';

-- Cap existing rows gently
UPDATE public.users
SET nightlife_tickets = LEAST(GREATEST(COALESCE(nightlife_tickets, 48), 0), 100)
WHERE true;

-- ── Type gates + refill economy params ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._mekan_crims_type_params(p_type text)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- req_level = respect/level gate; own_safe = no OD at own venue; price_mult base
  RETURN CASE lower(COALESCE(p_type, 'bar'))
    WHEN 'bar' THEN jsonb_build_object(
      'req_level', 1, 'req_reputation', 0, 'price_mult', 1.0, 'own_discount', 0.35
    )
    WHEN 'kahvehane' THEN jsonb_build_object(
      'req_level', 3, 'req_reputation', 0, 'price_mult', 0.95, 'own_discount', 0.35
    )
    WHEN 'dovus_kulubu' THEN jsonb_build_object(
      'req_level', 8, 'req_reputation', 0, 'price_mult', 1.1, 'own_discount', 0.30
    )
    WHEN 'luks_lounge' THEN jsonb_build_object(
      'req_level', 15, 'req_reputation', 50, 'price_mult', 1.35, 'own_discount', 0.25
    )
    WHEN 'yeralti' THEN jsonb_build_object(
      'req_level', 10, 'req_reputation', 0, 'price_mult', 1.2, 'own_discount', 0.30
    )
    ELSE jsonb_build_object(
      'req_level', 1, 'req_reputation', 0, 'price_mult', 1.0, 'own_discount', 0.30
    )
  END;
END;
$$;

REVOKE ALL ON FUNCTION public._mekan_crims_type_params(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._mekan_crims_type_params(text) TO authenticated, service_role;

-- Daily ticket grant (UTC day). Returns tickets after grant.
CREATE OR REPLACE FUNCTION public._nightlife_grant_tickets(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_day date := (timezone('utc', now()))::date;
  v_tickets int;
  v_tickets_day date;
  v_daily int := 24;
  v_max int := 100;
BEGIN
  SELECT nightlife_tickets, nightlife_tickets_day
  INTO v_tickets, v_tickets_day
  FROM public.users
  WHERE auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  v_tickets := COALESCE(v_tickets, 0);

  IF v_tickets_day IS DISTINCT FROM v_day THEN
    v_tickets := LEAST(v_max, v_tickets + v_daily);
    UPDATE public.users
    SET nightlife_tickets = v_tickets,
        nightlife_tickets_day = v_day,
        updated_at = now()
    WHERE auth_id = p_user_id;
  END IF;

  RETURN v_tickets;
END;
$$;

REVOKE ALL ON FUNCTION public._nightlife_grant_tickets(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._nightlife_grant_tickets(uuid) TO service_role;

-- Addiction → price multiplier (reuse addiction_level + tolerance).
CREATE OR REPLACE FUNCTION public._nightlife_addiction_price_mult(p_addiction int, p_tolerance int)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RETURN GREATEST(
    1.0,
    1.0
      + (GREATEST(0, COALESCE(p_addiction, 0)) * 0.12)
      + (GREATEST(0, COALESCE(p_tolerance, 0)) / 200.0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public._nightlife_addiction_price_mult(int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._nightlife_addiction_price_mult(int, int) TO authenticated, service_role;

-- Item eligible for bar refill shelf?
CREATE OR REPLACE FUNCTION public._mekan_refill_item_ok(p_item_id text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_item record;
BEGIN
  SELECT energy_restore, is_han_only, type, lower(COALESCE(sub_type, '')) AS sub_type
  INTO v_item
  FROM public.items
  WHERE id = p_item_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT public.mekan_is_stock_eligible(p_item_id) THEN
    RETURN false;
  END IF;

  -- Energy drinks / potions / han-only bar goods
  IF COALESCE(v_item.energy_restore, 0) > 0 THEN
    RETURN true;
  END IF;
  IF COALESCE(v_item.is_han_only, false) THEN
    RETURN true;
  END IF;
  IF lower(COALESCE(v_item.type, '')) = 'potion' THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

REVOKE ALL ON FUNCTION public._mekan_refill_item_ok(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public._mekan_refill_item_ok(text) TO authenticated, service_role;

-- ── Status / preview (enter club, ticket count, gates, price hint) ────────────
CREATE OR REPLACE FUNCTION public.get_nightlife_status(p_mekan_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_user record;
  v_mekan record;
  v_params jsonb;
  v_tickets int;
  v_addict_mult numeric;
  v_can_enter boolean := true;
  v_gate_error text := NULL;
  v_own boolean := false;
  v_party boolean := false;
  v_session_refills int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli', 'error_code', 'not_authenticated');
  END IF;

  v_tickets := public._nightlife_grant_tickets(v_uid);

  SELECT
    level, reputation, addiction_level, tolerance, energy, max_energy,
    nightlife_vibe, nightlife_tickets,
    nightlife_refill_mekan_id, nightlife_refill_count, nightlife_refill_session_until,
    hospital_until, prison_until
  INTO v_user
  FROM public.users
  WHERE auth_id = v_uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi', 'error_code', 'no_user');
  END IF;

  v_addict_mult := public._nightlife_addiction_price_mult(v_user.addiction_level, v_user.tolerance);

  IF v_user.nightlife_refill_session_until IS NOT NULL
     AND v_user.nightlife_refill_session_until > now() THEN
    v_session_refills := COALESCE(v_user.nightlife_refill_count, 0);
  END IF;

  IF p_mekan_id IS NOT NULL THEN
    SELECT * INTO v_mekan FROM public.mekans WHERE id = p_mekan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi', 'error_code', 'no_mekan');
    END IF;

    v_params := public._mekan_crims_type_params(v_mekan.mekan_type);
    v_own := (v_mekan.owner_id = v_uid);
    v_party := v_mekan.happy_hour_until IS NOT NULL AND v_mekan.happy_hour_until > now();

    IF COALESCE(v_mekan.is_open, false) IS NOT TRUE THEN
      v_can_enter := false;
      v_gate_error := 'Mekan kapali';
    ELSIF v_mekan.closed_until IS NOT NULL AND v_mekan.closed_until > now() THEN
      v_can_enter := false;
      v_gate_error := 'Baskin nedeniyle kapali';
    ELSIF COALESCE(v_user.level, 1) < COALESCE((v_params->>'req_level')::int, 1) THEN
      v_can_enter := false;
      v_gate_error := format('Seviye kapisi: %s gerekli', v_params->>'req_level');
    ELSIF COALESCE(v_user.reputation, 0) < COALESCE((v_params->>'req_reputation')::int, 0) THEN
      v_can_enter := false;
      v_gate_error := format('Itibar kapisi: %s gerekli', v_params->>'req_reputation');
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'tickets', v_tickets,
      'tickets_max', 100,
      'daily_grant', 24,
      'addiction_level', COALESCE(v_user.addiction_level, 0),
      'tolerance', COALESCE(v_user.tolerance, 0),
      'addiction_price_mult', v_addict_mult,
      'energy', COALESCE(v_user.energy, 0),
      'max_energy', COALESCE(v_user.max_energy, 100),
      'nightlife_vibe', COALESCE(v_user.nightlife_vibe, 0),
      'session_refills', v_session_refills,
      'session_mekan_id', v_user.nightlife_refill_mekan_id,
      'can_enter', v_can_enter,
      'gate_error', v_gate_error,
      'is_own', v_own,
      'party_active', v_party,
      'req_level', COALESCE((v_params->>'req_level')::int, 1),
      'req_reputation', COALESCE((v_params->>'req_reputation')::int, 0),
      'own_discount', COALESCE((v_params->>'own_discount')::numeric, 0.30),
      'type_price_mult', COALESCE((v_params->>'price_mult')::numeric, 1.0),
      'mekan_id', p_mekan_id,
      'mekan_type', v_mekan.mekan_type,
      'loop', 'enter_free_buy_refill_ticket'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'tickets', v_tickets,
    'tickets_max', 100,
    'daily_grant', 24,
    'addiction_level', COALESCE(v_user.addiction_level, 0),
    'tolerance', COALESCE(v_user.tolerance, 0),
    'addiction_price_mult', v_addict_mult,
    'energy', COALESCE(v_user.energy, 0),
    'max_energy', COALESCE(v_user.max_energy, 100),
    'nightlife_vibe', COALESCE(v_user.nightlife_vibe, 0),
    'session_refills', v_session_refills,
    'loop', 'enter_free_buy_refill_ticket'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_nightlife_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_nightlife_status(uuid) TO authenticated;

-- Preview price for one refill item
CREATE OR REPLACE FUNCTION public.mekan_refill_quote(p_mekan_id uuid, p_item_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_status jsonb;
  v_stock record;
  v_base bigint;
  v_price bigint;
  v_mult numeric;
  v_type_mult numeric;
  v_own_disc numeric := 0;
  v_party_disc numeric := 1.0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli');
  END IF;

  v_status := public.get_nightlife_status(p_mekan_id);
  IF COALESCE((v_status->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_status;
  END IF;

  IF NOT public._mekan_refill_item_ok(p_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu icecek enerji doldurmaz', 'error_code', 'not_refill');
  END IF;

  SELECT sell_price, quantity INTO v_stock
  FROM public.mekan_stock
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id;

  IF NOT FOUND OR COALESCE(v_stock.quantity, 0) < 1 OR COALESCE(v_stock.sell_price, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stokta yok', 'error_code', 'no_stock');
  END IF;

  v_base := v_stock.sell_price;
  v_mult := COALESCE((v_status->>'addiction_price_mult')::numeric, 1.0);
  v_type_mult := COALESCE((v_status->>'type_price_mult')::numeric, 1.0);

  IF COALESCE((v_status->>'is_own')::boolean, false) THEN
    v_own_disc := COALESCE((v_status->>'own_discount')::numeric, 0.30);
  END IF;

  IF COALESCE((v_status->>'party_active')::boolean, false) THEN
    v_party_disc := 0.80;
  END IF;

  -- Own venue: ticket-only (gold burned 0) — safer/cheaper Crims feel
  IF COALESCE((v_status->>'is_own')::boolean, false) THEN
    v_price := 0;
  ELSE
    v_price := GREATEST(
      1,
      floor(v_base * v_mult * v_type_mult * v_party_disc * (1.0 - v_own_disc))::bigint
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'item_id', p_item_id,
    'base_price', v_base,
    'final_price', v_price,
    'ticket_cost', 1,
    'addiction_price_mult', v_mult,
    'party_discount', v_party_disc < 1.0,
    'is_own', COALESCE((v_status->>'is_own')::boolean, false),
    'energy_to', 'max',
    'stock_qty', v_stock.quantity,
    'can_enter', COALESCE((v_status->>'can_enter')::boolean, false),
    'tickets', COALESCE((v_status->>'tickets')::int, 0),
    'od_warning', COALESCE((v_status->>'session_refills')::int, 0) >= 1
      AND COALESCE((v_status->>'is_own')::boolean, false) IS NOT TRUE
      AND (v_status->>'session_mekan_id') IS NOT DISTINCT FROM p_mekan_id::text
  );
END;
$$;

REVOKE ALL ON FUNCTION public.mekan_refill_quote(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mekan_refill_quote(uuid, text) TO authenticated;

-- ── CORE: buy drink/ticket → energy to max (Crims polarity) ───────────────────
CREATE OR REPLACE FUNCTION public.mekan_refill(p_mekan_id uuid, p_item_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_gate jsonb;
  v_rate jsonb;
  v_mekan record;
  v_stock record;
  v_item record;
  v_user record;
  v_params jsonb;
  v_tickets int;
  v_is_own boolean;
  v_party boolean;
  v_addict_mult numeric;
  v_price bigint;
  v_owner_profit bigint := 0;
  v_session_count int := 0;
  v_same_session boolean := false;
  v_od boolean := false;
  v_hospital_minutes int := 45;
  v_tol_gain int;
  v_new_tol int;
  v_new_addict int;
  v_energy_before int;
  v_energy_after int;
  v_vibe_gain int := 2;
  v_raid boolean := false;
  v_raid_chance numeric;
  v_penalty bigint := 0;
  v_stock_value bigint;
  v_profit_bonus numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli', 'error_code', 'not_authenticated');
  END IF;

  v_gate := public.assert_player_combat_ready(v_uid, false);
  IF COALESCE((v_gate->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_gate;
  END IF;

  v_rate := public.enforce_rate_limit('mekan_refill', 30, 600);
  IF v_rate IS NOT NULL THEN
    RETURN v_rate;
  END IF;

  IF NOT public._mekan_refill_item_ok(p_item_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu icecek enerji doldurmaz', 'error_code', 'not_refill');
  END IF;

  SELECT * INTO v_mekan
  FROM public.mekans
  WHERE id = p_mekan_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi', 'error_code', 'no_mekan');
  END IF;

  IF COALESCE(v_mekan.is_open, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan kapali', 'error_code', 'mekan_closed');
  END IF;
  IF v_mekan.closed_until IS NOT NULL AND v_mekan.closed_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Baskin nedeniyle kapali', 'error_code', 'mekan_raid');
  END IF;

  v_params := public._mekan_crims_type_params(v_mekan.mekan_type);
  v_is_own := (v_mekan.owner_id = v_uid);
  v_party := v_mekan.happy_hour_until IS NOT NULL AND v_mekan.happy_hour_until > now();

  SELECT
    level, reputation, addiction_level, tolerance, energy, max_energy, gold,
    nightlife_vibe, nightlife_tickets,
    nightlife_refill_mekan_id, nightlife_refill_count, nightlife_refill_session_until
  INTO v_user
  FROM public.users
  WHERE auth_id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oyuncu bulunamadi', 'error_code', 'no_user');
  END IF;

  -- Respect / level gates
  IF COALESCE(v_user.level, 1) < COALESCE((v_params->>'req_level')::int, 1) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Seviye kapisi: %s gerekli', v_params->>'req_level'),
      'error_code', 'level_gate',
      'req_level', (v_params->>'req_level')::int
    );
  END IF;
  IF COALESCE(v_user.reputation, 0) < COALESCE((v_params->>'req_reputation')::int, 0) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Itibar kapisi: %s gerekli', v_params->>'req_reputation'),
      'error_code', 'reputation_gate',
      'req_reputation', (v_params->>'req_reputation')::int
    );
  END IF;

  -- Tickets (daily grant)
  v_tickets := public._nightlife_grant_tickets(v_uid);
  SELECT nightlife_tickets INTO v_tickets FROM public.users WHERE auth_id = v_uid;
  IF COALESCE(v_tickets, 0) < 1 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bilet yok — yarin yenilenir', 'error_code', 'no_tickets');
  END IF;

  SELECT ms.*, i.energy_restore, i.is_han_only, i.type AS item_type
  INTO v_stock
  FROM public.mekan_stock ms
  JOIN public.items i ON i.id = ms.item_id
  WHERE ms.mekan_id = p_mekan_id AND ms.item_id = p_item_id AND ms.quantity >= 1
  FOR UPDATE OF ms;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz', 'error_code', 'no_stock');
  END IF;
  IF COALESCE(v_stock.sell_price, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Fiyat ayarli degil', 'error_code', 'no_price');
  END IF;

  -- Session tracking
  IF v_user.nightlife_refill_session_until IS NOT NULL
     AND v_user.nightlife_refill_session_until > now()
     AND v_user.nightlife_refill_mekan_id IS NOT DISTINCT FROM p_mekan_id THEN
    v_same_session := true;
    v_session_count := COALESCE(v_user.nightlife_refill_count, 0);
  ELSE
    v_session_count := 0;
  END IF;

  -- OD: 2nd refill same foreign club session (Crims). Own club = safer (no OD).
  IF v_same_session AND v_session_count >= 1 AND NOT v_is_own THEN
    v_od := true;
  END IF;

  v_addict_mult := public._nightlife_addiction_price_mult(v_user.addiction_level, v_user.tolerance);

  IF v_is_own THEN
    v_price := 0; -- own = ticket-only safer refill
  ELSE
    v_price := GREATEST(
      1,
      floor(
        v_stock.sell_price
        * v_addict_mult
        * COALESCE((v_params->>'price_mult')::numeric, 1.0)
        * CASE WHEN v_party THEN 0.80 ELSE 1.0 END
      )::bigint
    );
  END IF;

  IF NOT v_is_own AND COALESCE(v_user.gold, 0) < v_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gold yetersiz', 'error_code', 'no_gold', 'price', v_price);
  END IF;

  -- Consume ticket + stock first
  UPDATE public.users
  SET nightlife_tickets = nightlife_tickets - 1,
      updated_at = now()
  WHERE auth_id = v_uid AND nightlife_tickets >= 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bilet yok', 'error_code', 'no_tickets');
  END IF;

  UPDATE public.mekan_stock
  SET quantity = quantity - 1
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id AND quantity >= 1;
  IF NOT FOUND THEN
    -- refund ticket
    UPDATE public.users SET nightlife_tickets = nightlife_tickets + 1 WHERE auth_id = v_uid;
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz', 'error_code', 'no_stock');
  END IF;

  -- Overdose path: hospital, addiction spike, no energy fill
  IF v_od THEN
    v_hospital_minutes := 30 + LEAST(90, COALESCE(v_user.tolerance, 0));
    v_new_tol := LEAST(100, COALESCE(v_user.tolerance, 0) + 8);
    v_new_addict := LEAST(10, COALESCE(v_user.addiction_level, 0) + 1);

    IF NOT v_is_own AND v_price > 0 THEN
      UPDATE public.users SET gold = gold - v_price WHERE auth_id = v_uid AND gold >= v_price;
      v_profit_bonus := public.mekan_profit_bonus_pct(v_mekan.level);
      v_owner_profit := floor(v_price * (1 + v_profit_bonus))::bigint;
      UPDATE public.users SET gold = gold + v_owner_profit WHERE auth_id = v_mekan.owner_id;
      INSERT INTO public.mekan_sales (mekan_id, buyer_id, item_id, quantity, price_per_unit, total_price, owner_profit)
      VALUES (p_mekan_id, v_uid, p_item_id, 1, v_price, v_price, v_owner_profit);
      UPDATE public.mekans
      SET fame = fame + 1,
          total_revenue = total_revenue + v_owner_profit,
          total_sales = total_sales + 1
      WHERE id = p_mekan_id;
    END IF;

    UPDATE public.users
    SET hospital_until = now() + (v_hospital_minutes || ' minutes')::interval,
        hospital_reason = 'Gece asiri doz',
        tolerance = v_new_tol,
        addiction_level = v_new_addict,
        nightlife_refill_mekan_id = p_mekan_id,
        nightlife_refill_count = v_session_count + 1,
        nightlife_refill_session_until = now() + interval '45 minutes',
        nightlife_vibe = COALESCE(nightlife_vibe, 0) + 1,
        updated_at = now()
    WHERE auth_id = v_uid;

    RETURN jsonb_build_object(
      'success', true,
      'outcome', 'overdose',
      'message', 'Fazla kacti — hastanesin. Kendi mekaninda doldurmak daha guvenli.',
      'hospital', true,
      'hospital_minutes', v_hospital_minutes,
      'hospital_reason', 'Gece asiri doz',
      'energy_before', v_user.energy,
      'energy_after', v_user.energy,
      'energy_delta', 0,
      'gold_paid', CASE WHEN v_is_own THEN 0 ELSE v_price END,
      'ticket_spent', 1,
      'tickets_left', v_tickets - 1,
      'addiction_level', v_new_addict,
      'tolerance', v_new_tol,
      'addiction_price_mult', public._nightlife_addiction_price_mult(v_new_addict, v_new_tol),
      'is_own', v_is_own,
      'party_active', v_party,
      'vibe_delta', 1,
      'nightlife_vibe', COALESCE(v_user.nightlife_vibe, 0) + 1
    );
  END IF;

  -- Normal refill → energy to max (Crims first-buy feel)
  v_energy_before := COALESCE(v_user.energy, 0);
  v_energy_after := GREATEST(v_energy_before, COALESCE(v_user.max_energy, 100));

  -- Mild tolerance/addiction climb (not full potion OD table)
  v_tol_gain := CASE
    WHEN v_is_own THEN 2
    WHEN v_party THEN 3
    ELSE 4
  END;
  v_new_tol := LEAST(100, COALESCE(v_user.tolerance, 0) + v_tol_gain);
  v_new_addict := CASE
    WHEN v_new_tol >= 80 AND COALESCE(v_user.addiction_level, 0) < 10
      THEN LEAST(10, COALESCE(v_user.addiction_level, 0) + 1)
    WHEN NOT v_is_own AND random() < 0.15
      THEN LEAST(10, COALESCE(v_user.addiction_level, 0) + 1)
    ELSE COALESCE(v_user.addiction_level, 0)
  END;

  IF v_party THEN
    v_vibe_gain := 4;
  ELSIF v_is_own THEN
    v_vibe_gain := 3;
  END IF;

  IF NOT v_is_own AND v_price > 0 THEN
    UPDATE public.users
    SET gold = gold - v_price
    WHERE auth_id = v_uid AND gold >= v_price;
    IF NOT FOUND THEN
      -- rollback stock + ticket
      UPDATE public.mekan_stock SET quantity = quantity + 1
      WHERE mekan_id = p_mekan_id AND item_id = p_item_id;
      UPDATE public.users SET nightlife_tickets = nightlife_tickets + 1 WHERE auth_id = v_uid;
      RETURN jsonb_build_object('success', false, 'error', 'Gold yetersiz', 'error_code', 'no_gold');
    END IF;

    v_profit_bonus := public.mekan_profit_bonus_pct(v_mekan.level);
    v_owner_profit := floor(v_price * (1 + v_profit_bonus))::bigint;
    UPDATE public.users SET gold = gold + v_owner_profit WHERE auth_id = v_mekan.owner_id;

    INSERT INTO public.mekan_sales (mekan_id, buyer_id, item_id, quantity, price_per_unit, total_price, owner_profit)
    VALUES (p_mekan_id, v_uid, p_item_id, 1, v_price, v_price, v_owner_profit);

    UPDATE public.mekans
    SET fame = fame + GREATEST(1, floor(v_price * 0.001)::int) + 1,
        total_revenue = total_revenue + v_owner_profit,
        total_sales = total_sales + 1
    WHERE id = p_mekan_id;

    -- Yeralti contraband raid (same spirit as buy_from_mekan)
    IF public.mekan_is_contraband(p_item_id) AND v_mekan.mekan_type = 'yeralti' THEN
      UPDATE public.mekans
      SET suspicion = LEAST(100, suspicion + 5)
      WHERE id = p_mekan_id
      RETURNING suspicion INTO v_mekan.suspicion;

      v_raid_chance := 0.02 + (v_mekan.suspicion::numeric / 100.0) * 0.30;
      IF random() <= v_raid_chance THEN
        v_raid := true;
        SELECT COALESCE(SUM(quantity * sell_price), 0) INTO v_stock_value
        FROM public.mekan_stock WHERE mekan_id = p_mekan_id;
        v_penalty := floor(v_stock_value * 0.50)::bigint;
        UPDATE public.users SET gold = GREATEST(0, gold - v_penalty) WHERE auth_id = v_mekan.owner_id;
        UPDATE public.mekans
        SET is_open = false,
            closed_until = now() + interval '48 hours',
            fame = GREATEST(0, fame - 500),
            suspicion = 0
        WHERE id = p_mekan_id;
        UPDATE public.users
        SET prison_until = now() + interval '24 hours'
        WHERE auth_id = v_mekan.owner_id;
      END IF;
    END IF;
  ELSE
    -- Own refill still bumps fame lightly (hosting vibe)
    UPDATE public.mekans
    SET fame = fame + 1
    WHERE id = p_mekan_id;
  END IF;

  UPDATE public.users
  SET energy = v_energy_after,
      tolerance = v_new_tol,
      addiction_level = v_new_addict,
      nightlife_vibe = COALESCE(nightlife_vibe, 0) + v_vibe_gain,
      nightlife_refill_mekan_id = p_mekan_id,
      nightlife_refill_count = v_session_count + 1,
      nightlife_refill_session_until = now() + interval '45 minutes',
      updated_at = now()
  WHERE auth_id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'outcome', 'refill',
    'message', CASE
      WHEN v_is_own THEN 'Kendi mekaninda doldurdun — guvenli ve ucuz.'
      WHEN v_party THEN 'Parti icecegi ise yaradi — enerji full.'
      ELSE 'Bilet + icecek — enerji doldu.'
    END,
    'hospital', false,
    'hospital_minutes', 0,
    'energy_before', v_energy_before,
    'energy_after', v_energy_after,
    'energy_delta', v_energy_after - v_energy_before,
    'gold_paid', v_price,
    'owner_profit', v_owner_profit,
    'ticket_spent', 1,
    'tickets_left', v_tickets - 1,
    'addiction_level', v_new_addict,
    'tolerance', v_new_tol,
    'addiction_price_mult', public._nightlife_addiction_price_mult(v_new_addict, v_new_tol),
    'is_own', v_is_own,
    'party_active', v_party,
    'vibe_delta', v_vibe_gain,
    'nightlife_vibe', COALESCE(v_user.nightlife_vibe, 0) + v_vibe_gain,
    'od_next_warning', (NOT v_is_own),
    'police_raid', v_raid,
    'penalty', v_penalty,
    'item_id', p_item_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.mekan_refill(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mekan_refill(uuid, text) TO authenticated;

-- ── Deprecate hang_out / join_party as core loop ──────────────────────────────
CREATE OR REPLACE FUNCTION public.mekan_hang_out(p_mekan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RETURN jsonb_build_object(
    'success', false,
    'error', 'Takil kaldirildi — icecek/bilet ile enerji doldur',
    'error_code', 'deprecated_use_refill',
    'hint', 'mekan_refill'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.mekan_join_party(p_mekan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RETURN jsonb_build_object(
    'success', false,
    'error', 'Partiye katil kaldirildi — parti indirimi refill fiyatina yansir',
    'error_code', 'deprecated_use_refill',
    'hint', 'mekan_refill'
  );
END;
$$;

-- Owner party host message tweak (same mechanics)
CREATE OR REPLACE FUNCTION public.mekan_start_party(
  p_mekan_id uuid,
  p_duration_minutes integer DEFAULT 60
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_mekan record;
  v_mins int;
  v_until timestamptz;
  v_rate jsonb;
  v_cost bigint := 500;
  v_gate jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kimlik dogrulama gerekli', 'error_code', 'not_authenticated');
  END IF;

  v_gate := public.assert_player_combat_ready(v_uid, false);
  IF COALESCE((v_gate->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_gate;
  END IF;

  v_rate := public.enforce_rate_limit('mekan_start_party', 3, 86400);
  IF v_rate IS NOT NULL THEN
    RETURN v_rate;
  END IF;

  v_mins := GREATEST(30, LEAST(120, COALESCE(p_duration_minutes, 60)));

  SELECT * INTO v_mekan
  FROM public.mekans
  WHERE id = p_mekan_id AND owner_id = v_uid
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mekan bulunamadi veya size ait degil', 'error_code', 'not_owner');
  END IF;

  IF COALESCE(v_mekan.is_open, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Once mekani ac', 'error_code', 'mekan_closed');
  END IF;

  IF v_mekan.closed_until IS NOT NULL AND v_mekan.closed_until > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Baskin nedeniyle kapali', 'error_code', 'mekan_raid');
  END IF;

  IF v_mekan.happy_hour_until IS NOT NULL AND v_mekan.happy_hour_until > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Parti zaten canli',
      'error_code', 'party_active',
      'happy_hour_until', v_mekan.happy_hour_until
    );
  END IF;

  UPDATE public.users
  SET gold = gold - v_cost,
      updated_at = now()
  WHERE auth_id = v_uid AND gold >= v_cost;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Parti baslatmak icin 500 altin gerekli', 'error_code', 'no_gold');
  END IF;

  v_until := now() + (v_mins || ' minutes')::interval;

  UPDATE public.mekans
  SET happy_hour_until = v_until,
      fame = fame + 5,
      suspicion = CASE
        WHEN mekan_type = 'yeralti' THEN LEAST(100, suspicion + 5)
        ELSE suspicion
      END
  WHERE id = p_mekan_id;

  RETURN jsonb_build_object(
    'success', true,
    'happy_hour_until', v_until,
    'party_until', v_until,
    'duration_minutes', v_mins,
    'gold_cost', v_cost,
    'message', 'Rave/parti acik — ziyaretciler burada guvenli refill + %20 indirim.'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.mekan_hang_out(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mekan_join_party(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mekan_start_party(uuid, integer) TO authenticated;
