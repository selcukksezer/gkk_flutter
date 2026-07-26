-- Monthly kingdom election auto-start, rank-#1 fallback, KING badge, market blessing powers.

BEGIN;

-- ── Reign helpers ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public._kingdom_calendar_month(p_now TIMESTAMPTZ DEFAULT now())
RETURNS date
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT date_trunc('month', timezone('Europe/Istanbul', p_now))::date;
$$;

CREATE OR REPLACE FUNCTION public.get_current_king_auth_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT g.leader_id
  FROM public.kingdom_elections ke
  JOIN public.guilds g ON g.id = ke.winner_guild_id
  WHERE ke.status = 'completed'
    AND ke.winner_guild_id IS NOT NULL
  ORDER BY ke.end_at DESC NULLS LAST, ke.created_at DESC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_current_king(p_auth_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p_auth_id IS NOT NULL
    AND p_auth_id = public.get_current_king_auth_id();
$$;

CREATE OR REPLACE FUNCTION public.get_public_king_badge(p_auth_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN public.is_current_king(p_auth_id) THEN 'king' ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_reign_info()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_king uuid := public.get_current_king_auth_id();
  v_row record;
BEGIN
  IF v_king IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT
    ke.id AS election_id,
    ke.month,
    g.id AS guild_id,
    g.name AS guild_name,
    u.auth_id AS leader_auth_id,
    u.username AS leader_username
  INTO v_row
  FROM public.kingdom_elections ke
  JOIN public.guilds g ON g.id = ke.winner_guild_id
  LEFT JOIN public.users u ON u.auth_id = g.leader_id
  WHERE ke.status = 'completed'
    AND ke.winner_guild_id IS NOT NULL
  ORDER BY ke.end_at DESC NULLS LAST, ke.created_at DESC
  LIMIT 1;

  IF v_row.guild_id IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'election_id', v_row.election_id,
    'month', v_row.month,
    'guild_id', v_row.guild_id,
    'guild_name', v_row.guild_name,
    'leader_auth_id', v_row.leader_auth_id,
    'leader_username', v_row.leader_username
  );
END;
$$;

-- ── Market blessing (global 30 min buff, 1/day) ─────────────────────────────

CREATE TABLE IF NOT EXISTS public.kingdom_market_blessings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activated_by uuid NOT NULL REFERENCES auth.users(id),
  gold_discount_pct numeric(5,2) NOT NULL DEFAULT 0
    CHECK (gold_discount_pct >= 0 AND gold_discount_pct <= 20),
  gem_discount_pct numeric(5,2) NOT NULL DEFAULT 0
    CHECK (gem_discount_pct >= 0 AND gem_discount_pct <= 10),
  started_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  blessing_day date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT kingdom_market_blessings_discount_positive CHECK (
    gold_discount_pct > 0 OR gem_discount_pct > 0
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS kingdom_market_blessings_day_uidx
  ON public.kingdom_market_blessings (blessing_day);

CREATE INDEX IF NOT EXISTS kingdom_market_blessings_active_idx
  ON public.kingdom_market_blessings (expires_at DESC);

ALTER TABLE public.kingdom_market_blessings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS kingdom_market_blessings_select ON public.kingdom_market_blessings;
CREATE POLICY kingdom_market_blessings_select
  ON public.kingdom_market_blessings FOR SELECT USING (true);

CREATE OR REPLACE FUNCTION public._kingdom_blessing_day(p_now TIMESTAMPTZ DEFAULT now())
RETURNS date
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT (timezone('Europe/Istanbul', p_now))::date;
$$;

CREATE OR REPLACE FUNCTION public._active_kingdom_market_blessing()
RETURNS TABLE (
  gold_discount_pct numeric,
  gem_discount_pct numeric,
  expires_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT b.gold_discount_pct, b.gem_discount_pct, b.expires_at
  FROM public.kingdom_market_blessings b
  WHERE b.expires_at > now()
  ORDER BY b.started_at DESC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public._kingdom_king_powers_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_is_king boolean := false;
  v_active record;
  v_used_today boolean := false;
  v_day date := public._kingdom_blessing_day();
BEGIN
  IF v_user IS NOT NULL THEN
    v_is_king := public.is_current_king(v_user);
  END IF;

  SELECT * INTO v_active FROM public._active_kingdom_market_blessing() LIMIT 1;

  SELECT EXISTS (
    SELECT 1 FROM public.kingdom_market_blessings b WHERE b.blessing_day = v_day
  ) INTO v_used_today;

  RETURN jsonb_build_object(
    'is_king', v_is_king,
    'blessing_active', v_active.expires_at IS NOT NULL,
    'blessing_expires_at', v_active.expires_at,
    'active_gold_pct', COALESCE(v_active.gold_discount_pct, 0),
    'active_gem_pct', COALESCE(v_active.gem_discount_pct, 0),
    'blessing_used_today', v_used_today,
    'max_gold_pct', 20,
    'max_gem_pct', 10,
    'duration_minutes', 30
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.king_activate_market_blessing(
  p_gold_discount_pct numeric DEFAULT 0,
  p_gem_discount_pct numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_day date := public._kingdom_blessing_day();
  v_gold numeric := COALESCE(p_gold_discount_pct, 0);
  v_gem numeric := COALESCE(p_gem_discount_pct, 0);
  v_expires timestamptz;
  v_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF NOT public.is_current_king(v_user) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yalnızca krallık lideri bu yetkiyi kullanabilir.');
  END IF;

  IF v_gold < 0 OR v_gold > 20 OR v_gem < 0 OR v_gem > 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'İndirim oranları geçersiz.');
  END IF;

  IF v_gold <= 0 AND v_gem <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'En az bir indirim oranı seçmelisin.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.kingdom_market_blessings b WHERE b.blessing_day = v_day) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bugünkü kral indirimi zaten kullanıldı.');
  END IF;

  v_expires := now() + interval '30 minutes';

  INSERT INTO public.kingdom_market_blessings (
    activated_by, gold_discount_pct, gem_discount_pct, expires_at, blessing_day
  ) VALUES (
    v_user, v_gold, v_gem, v_expires, v_day
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'success', true,
    'blessing_id', v_id,
    'gold_discount_pct', v_gold,
    'gem_discount_pct', v_gem,
    'expires_at', v_expires
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bugünkü kral indirimi zaten kullanıldı.');
END;
$$;

-- ── Auto-start monthly election ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.ensure_monthly_kingdom_election()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_month date := public._kingdom_calendar_month();
  v_loop_id uuid;
  v_active uuid;
  v_start timestamptz;
  v_end timestamptz;
BEGIN
  FOR v_loop_id IN
    SELECT id FROM public.kingdom_elections
    WHERE status = 'active'
      AND end_at IS NOT NULL
      AND end_at <= now()
  LOOP
    PERFORM public.finalize_kingdom_election(v_loop_id);
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM public.kingdom_elections
    WHERE month = v_month AND status = 'completed'
  ) THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_active
  FROM public.kingdom_elections
  WHERE month = v_month AND status = 'active'
  ORDER BY start_at DESC NULLS LAST
  LIMIT 1;

  IF v_active IS NOT NULL THEN
    RETURN v_active;
  END IF;

  FOR v_loop_id IN
    SELECT id FROM public.kingdom_elections
    WHERE status = 'active' AND month IS DISTINCT FROM v_month
  LOOP
    PERFORM public.finalize_kingdom_election(v_loop_id);
  END LOOP;

  v_start := timezone('Europe/Istanbul', v_month::timestamptz);
  v_end := v_start + interval '7 days';

  IF v_end <= now() THEN
    v_start := now();
    v_end := now() + interval '7 days';
  END IF;

  INSERT INTO public.kingdom_elections (month, status, start_at, end_at, winner_guild_id)
  VALUES (v_month, 'active', v_start, v_end, NULL)
  ON CONFLICT (month) DO UPDATE SET
    status = 'active',
    start_at = EXCLUDED.start_at,
    end_at = EXCLUDED.end_at,
    winner_guild_id = NULL
  WHERE public.kingdom_elections.status <> 'completed'
  RETURNING id INTO v_active;

  RETURN v_active;
END;
$$;

-- ── Finalize: vote winner or season rank #1 fallback ────────────────────────

CREATE OR REPLACE FUNCTION public.finalize_kingdom_election(p_election_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_winner_id uuid;
  v_winner_name text;
  v_vote_count integer;
BEGIN
  SELECT
    v.candidate_guild_id,
    g.name,
    COUNT(*)::integer
  INTO v_winner_id, v_winner_name, v_vote_count
  FROM public.kingdom_election_votes v
  JOIN public.guilds g ON g.id = v.candidate_guild_id
  WHERE v.election_id = p_election_id
  GROUP BY v.candidate_guild_id, g.name
  ORDER BY COUNT(*) DESC, v.candidate_guild_id
  LIMIT 1;

  IF v_winner_id IS NULL THEN
    SELECT cg.guild_id, cg.guild_name, 0
    INTO v_winner_id, v_winner_name, v_vote_count
    FROM public._kingdom_election_candidate_guilds(1) cg
    ORDER BY cg.season_rank
    LIMIT 1;
  END IF;

  UPDATE public.kingdom_elections
  SET
    status = 'completed',
    winner_guild_id = v_winner_id,
    end_at = COALESCE(end_at, now())
  WHERE id = p_election_id
    AND status = 'active';

  RETURN json_build_object(
    'success', true,
    'winner_guild_id', v_winner_id,
    'winner_guild_name', v_winner_name,
    'vote_count', COALESCE(v_vote_count, 0),
    'fallback_rank_one', COALESCE(v_vote_count, 0) = 0
  );
END;
$$;

-- ── get_current_election (monthly ensure + reign + powers) ────────────────────

CREATE OR REPLACE FUNCTION public.get_current_election()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_election public.kingdom_elections%ROWTYPE;
  v_loop_id uuid;
  v_candidates json;
  v_winner record;
  v_voting_open boolean;
  v_voter json;
  v_reign jsonb := public._kingdom_reign_info();
  v_powers jsonb := public._kingdom_king_powers_context();
  v_auto_started uuid;
BEGIN
  v_auto_started := public.ensure_monthly_kingdom_election();

  FOR v_loop_id IN
    SELECT id FROM public.kingdom_elections
    WHERE status = 'active'
      AND end_at IS NOT NULL
      AND end_at <= now()
  LOOP
    PERFORM public.finalize_kingdom_election(v_loop_id);
  END LOOP;

  v_election := NULL;

  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE status = 'active'
  ORDER BY start_at DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_voting_open := (v_election.start_at IS NULL OR v_election.start_at <= now())
      AND (v_election.end_at IS NULL OR v_election.end_at > now());

    SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) INTO v_candidates
    FROM (
      SELECT
        cg.guild_id AS id,
        cg.guild_name AS name,
        cg.season_rank AS rank,
        COUNT(v.id)::integer AS vote_count,
        (cg.season_rank = 1) AS is_rank_one
      FROM public._kingdom_election_candidate_guilds(20) cg
      LEFT JOIN public.kingdom_election_votes v
        ON v.candidate_guild_id = cg.guild_id AND v.election_id = v_election.id
      GROUP BY cg.guild_id, cg.guild_name, cg.season_rank
      ORDER BY cg.season_rank
    ) c;

    IF v_election.end_at IS NOT NULL AND v_election.end_at <= now() THEN
      PERFORM public.finalize_kingdom_election(v_election.id);
    ELSE
      v_voter := public._kingdom_election_voter_context(v_election.id, v_voting_open);

      RETURN json_build_object(
        'active', true,
        'status', 'active',
        'voting_open', v_voting_open,
        'id', v_election.id,
        'month', v_election.month,
        'start_at', v_election.start_at,
        'end_at', v_election.end_at,
        'candidates', v_candidates,
        'winner', NULL,
        'voter', v_voter,
        'reigning_king', v_reign,
        'king_powers', v_powers,
        'auto_started_election_id', v_auto_started
      );
    END IF;
  END IF;

  v_election := NULL;
  v_reign := public._kingdom_reign_info();
  v_powers := public._kingdom_king_powers_context();

  SELECT * INTO v_election
  FROM public.kingdom_elections
  WHERE status = 'completed'
  ORDER BY end_at DESC NULLS LAST, created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT * INTO v_election
    FROM public.kingdom_elections
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'active', false,
      'status', 'none',
      'reigning_king', v_reign,
      'king_powers', v_powers
    );
  END IF;

  SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) INTO v_candidates
  FROM (
    SELECT
      cg.guild_id AS id,
      cg.guild_name AS name,
      cg.season_rank AS rank,
      COUNT(v.id)::integer AS vote_count,
      (cg.season_rank = 1) AS is_rank_one
    FROM public._kingdom_election_candidate_guilds(20) cg
    LEFT JOIN public.kingdom_election_votes v
      ON v.candidate_guild_id = cg.guild_id AND v.election_id = v_election.id
    GROUP BY cg.guild_id, cg.guild_name, cg.season_rank
    ORDER BY cg.season_rank
  ) c;

  v_voter := public._kingdom_election_voter_context(v_election.id, false);

  IF v_election.status = 'active' THEN
    RETURN json_build_object(
      'active', true,
      'status', 'active',
      'voting_open', false,
      'id', v_election.id,
      'month', v_election.month,
      'start_at', v_election.start_at,
      'end_at', v_election.end_at,
      'candidates', v_candidates,
      'winner', NULL,
      'voter', v_voter,
      'reigning_king', v_reign,
      'king_powers', v_powers
    );
  END IF;

  SELECT g.id, g.name, COUNT(v.id)::integer AS vote_count
  INTO v_winner
  FROM public.guilds g
  LEFT JOIN public.kingdom_election_votes v
    ON v.candidate_guild_id = g.id AND v.election_id = v_election.id
  WHERE g.id = v_election.winner_guild_id
  GROUP BY g.id, g.name;

  IF v_winner IS NULL AND v_election.winner_guild_id IS NOT NULL THEN
    SELECT g.id, g.name, 0 AS vote_count
    INTO v_winner
    FROM public.guilds g
    WHERE g.id = v_election.winner_guild_id;
  END IF;

  IF v_winner IS NULL THEN
    SELECT g.id, g.name, COUNT(v.id)::integer AS vote_count
    INTO v_winner
    FROM public.kingdom_election_votes v
    JOIN public.guilds g ON g.id = v.candidate_guild_id
    WHERE v.election_id = v_election.id
    GROUP BY g.id, g.name
    ORDER BY COUNT(*) DESC, g.id
    LIMIT 1;
  END IF;

  RETURN json_build_object(
    'active', false,
    'status', 'completed',
    'voting_open', false,
    'id', v_election.id,
    'month', v_election.month,
    'start_at', v_election.start_at,
    'end_at', v_election.end_at,
    'candidates', v_candidates,
    'winner', CASE WHEN v_winner IS NULL THEN NULL ELSE json_build_object(
      'id', v_winner.id,
      'name', v_winner.name,
      'vote_count', v_winner.vote_count
    ) END,
    'voter', v_voter,
    'reigning_king', v_reign,
    'king_powers', v_powers
  );
END;
$$;

-- ── Shop / night market: apply active blessing ──────────────────────────────

CREATE OR REPLACE FUNCTION public.buy_shop_item(
    p_item_id TEXT,
    p_currency TEXT,
    p_price BIGINT,
    p_quantity INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id UUID;
    v_item RECORD;
    v_unit_price BIGINT;
    v_currency TEXT;
    v_total BIGINT;
    v_current_gold BIGINT;
    v_current_gems NUMERIC;
    v_old_gold BIGINT;
    v_old_gems NUMERIC;
    v_inventory_slot INT;
    v_existing_row RECORD;
    v_new_quantity INT;
    v_capacity INT := 20;
    v_occupied INT;
    v_blessing RECORD;
    v_discount_pct NUMERIC := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    IF p_quantity < 1 OR p_quantity > 999 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity');
    END IF;

    SELECT
        id,
        name,
        base_price,
        is_stackable,
        max_stack,
        COALESCE(shop_available, false) AS shop_available,
        COALESCE(NULLIF(shop_currency, ''), 'gold') AS shop_currency
    INTO v_item
    FROM public.items
    WHERE id = p_item_id;

    IF v_item.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found');
    END IF;

    IF NOT v_item.shop_available THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not in shop');
    END IF;

    v_unit_price := GREATEST(COALESCE(v_item.base_price, 0), 0);
    v_currency := v_item.shop_currency;

    IF p_currency IS NOT NULL
       AND lower(trim(p_currency)) <> ''
       AND lower(trim(p_currency)) <> lower(v_currency) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Currency mismatch');
    END IF;

    SELECT * INTO v_blessing FROM public._active_kingdom_market_blessing() LIMIT 1;
    IF v_blessing.expires_at IS NOT NULL THEN
      IF lower(v_currency) = 'gold' AND COALESCE(v_blessing.gold_discount_pct, 0) > 0 THEN
        v_discount_pct := v_blessing.gold_discount_pct;
      ELSIF lower(v_currency) = 'gems' AND COALESCE(v_blessing.gem_discount_pct, 0) > 0 THEN
        v_discount_pct := v_blessing.gem_discount_pct;
      END IF;
      v_unit_price := GREATEST(
        floor(v_unit_price * (1 - v_discount_pct / 100.0))::bigint,
        0
      );
    END IF;

    v_total := v_unit_price * p_quantity;

    SELECT gold, gems INTO v_current_gold, v_current_gems
    FROM public.users
    WHERE auth_id = v_user_id OR id = v_user_id
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User not found');
    END IF;

    v_old_gold := v_current_gold;
    v_old_gems := v_current_gems;

    IF v_currency = 'gold' THEN
        IF v_current_gold < v_total THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gold');
        END IF;
        UPDATE public.users
        SET gold = gold - v_total
        WHERE auth_id = v_user_id OR id = v_user_id;
    ELSIF v_currency = 'gems' THEN
        IF v_current_gems < v_total THEN
            RETURN jsonb_build_object('success', false, 'error', 'Insufficient gems');
        END IF;
        UPDATE public.users
        SET gems = gems - v_total
        WHERE auth_id = v_user_id OR id = v_user_id;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid currency');
    END IF;

    BEGIN
        IF v_item.is_stackable THEN
            SELECT row_id, quantity INTO v_existing_row
            FROM public.inventory
            WHERE user_id = v_user_id AND item_id = p_item_id AND NOT is_equipped
            LIMIT 1;

            IF v_existing_row.row_id IS NOT NULL THEN
                v_new_quantity := LEAST(
                    v_existing_row.quantity + p_quantity,
                    COALESCE(v_item.max_stack, 999)
                );
                UPDATE public.inventory
                SET quantity = v_new_quantity,
                    updated_at = NOW()
                WHERE row_id = v_existing_row.row_id;
            ELSE
                SELECT COUNT(*) INTO v_occupied
                FROM public.inventory
                WHERE user_id = v_user_id AND NOT is_equipped;

                IF v_occupied >= v_capacity THEN
                    IF v_currency = 'gold' THEN
                        UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
                    ELSE
                        UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
                    END IF;
                    RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
                END IF;

                SELECT s INTO v_inventory_slot
                FROM generate_series(0, v_capacity - 1) s
                WHERE s NOT IN (
                    SELECT slot_position FROM public.inventory
                    WHERE user_id = v_user_id AND slot_position IS NOT NULL
                )
                LIMIT 1;

                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, is_equipped
                ) VALUES (
                    v_user_id, p_item_id, p_quantity, COALESCE(v_inventory_slot, 0), false
                );
            END IF;
        ELSE
            SELECT COUNT(*) INTO v_occupied
            FROM public.inventory
            WHERE user_id = v_user_id AND NOT is_equipped;

            IF v_occupied + p_quantity > v_capacity THEN
                IF v_currency = 'gold' THEN
                    UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
                ELSE
                    UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
                END IF;
                RETURN jsonb_build_object('success', false, 'error', 'Inventory full');
            END IF;

            FOR i IN 1..p_quantity LOOP
                SELECT s INTO v_inventory_slot
                FROM generate_series(0, v_capacity - 1) s
                WHERE s NOT IN (
                    SELECT slot_position FROM public.inventory
                    WHERE user_id = v_user_id AND slot_position IS NOT NULL
                )
                LIMIT 1;

                INSERT INTO public.inventory (
                    user_id, item_id, quantity, slot_position, is_equipped
                ) VALUES (
                    v_user_id, p_item_id, 1, COALESCE(v_inventory_slot, i - 1), false
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'item_id', p_item_id,
            'quantity', p_quantity,
            'total_cost', v_total,
            'currency', v_currency,
            'king_discount_pct', v_discount_pct
        );
    EXCEPTION WHEN OTHERS THEN
        IF v_currency = 'gold' THEN
            UPDATE public.users SET gold = v_old_gold WHERE auth_id = v_user_id OR id = v_user_id;
        ELSE
            UPDATE public.users SET gems = v_old_gems WHERE auth_id = v_user_id OR id = v_user_id;
        END IF;
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
    END;
END;
$$;

CREATE OR REPLACE FUNCTION public.buy_night_market_item(p_offer_id uuid, p_quantity integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_win RECORD;
  v_offer RECORD;
  v_item RECORD;
  v_shadow BOOLEAN := false;
  v_discount NUMERIC := 0;
  v_king_discount NUMERIC := 0;
  v_stock INT;
  v_purchased INT;
  v_unit_price BIGINT;
  v_total BIGINT;
  v_gems NUMERIC;
  v_add JSONB;
  v_blessing RECORD;
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

  SELECT * INTO v_blessing FROM public._active_kingdom_market_blessing() LIMIT 1;
  IF v_blessing.expires_at IS NOT NULL AND COALESCE(v_blessing.gem_discount_pct, 0) > 0 THEN
    v_king_discount := v_blessing.gem_discount_pct / 100.0;
  END IF;

  v_stock := v_offer.stock_per_player + CASE WHEN v_shadow THEN 1 ELSE 0 END;
  SELECT COALESCE(quantity, 0) INTO v_purchased
  FROM public.night_market_purchases
  WHERE player_id = v_user AND offer_id = p_offer_id;

  IF v_purchased + p_quantity > v_stock THEN
    RETURN jsonb_build_object('success', false, 'error', 'Stok yetersiz');
  END IF;

  v_unit_price := floor(v_offer.gem_price * (1 - v_discount) * (1 - v_king_discount))::BIGINT;
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
    'currency', 'gems',
    'king_discount_pct', COALESCE(v_blessing.gem_discount_pct, 0)
  );
END;
$function$;

-- ── Chat: KING badge on sender ───────────────────────────────────────────────

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
  sender_auth_id UUID,
  deleted_at TIMESTAMPTZ
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
    u.auth_id AS sender_auth_id,
    cm.deleted_at
  FROM public.chat_messages cm
  LEFT JOIN public.users u ON u.id = cm.sender_user_id
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

DROP FUNCTION IF EXISTS public.get_dm_messages(UUID, INTEGER);

CREATE OR REPLACE FUNCTION public.get_dm_messages(
  p_peer_user_id UUID,
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
  read_at TIMESTAMPTZ,
  sender_is_online BOOLEAN,
  sender_staff_badge TEXT,
  sender_king_badge TEXT,
  sender_auth_id UUID,
  deleted_at TIMESTAMPTZ
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

  IF p_peer_user_id IS NULL OR p_peer_user_id = v_user.id THEN
    RAISE EXCEPTION 'Gecersiz hedef kullanici';
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
    cm.read_at,
    public.is_user_online(u.is_online, u.last_active_at),
    public.get_public_staff_badge(u.auth_id) AS sender_staff_badge,
    public.get_public_king_badge(u.auth_id) AS sender_king_badge,
    u.auth_id AS sender_auth_id,
    cm.deleted_at
  FROM public.chat_messages cm
  JOIN public.users u ON u.id = cm.sender_user_id
  WHERE cm.channel = 'dm'
    AND (
      (cm.sender_user_id = v_user.id AND cm.recipient_user_id = p_peer_user_id)
      OR (cm.sender_user_id = p_peer_user_id AND cm.recipient_user_id = v_user.id)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE cb.blocker_user_id = v_user.id
        AND cb.blocked_user_id = cm.sender_user_id
        AND cm.deleted_at IS NULL
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_dm_message_hides h
      WHERE h.message_id = cm.id
        AND h.user_id = v_user.id
    )
  ORDER BY cm.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_monthly_kingdom_election() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_king_auth_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_king(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_king_badge(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.king_activate_market_blessing(numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_election() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_election() TO anon;
GRANT EXECUTE ON FUNCTION public.finalize_kingdom_election(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.buy_shop_item(text, text, bigint, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.buy_night_market_item(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_history(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_dm_messages(uuid, integer) TO authenticated;

COMMIT;
