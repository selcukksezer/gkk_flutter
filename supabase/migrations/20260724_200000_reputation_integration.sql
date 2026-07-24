-- Reputation shop, activity log, timed buffs, overview RPCs.

BEGIN;

-- ── Activity log ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reputation_activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('earn', 'spend')),
  source text NOT NULL,
  amount integer NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'global' CHECK (currency IN ('global', 'faction')),
  faction_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reputation_activity_log_user_created_idx
  ON public.reputation_activity_log (user_id, created_at DESC);

ALTER TABLE public.reputation_activity_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS reputation_activity_log_select ON public.reputation_activity_log;
CREATE POLICY reputation_activity_log_select ON public.reputation_activity_log
  FOR SELECT USING (user_id = auth.uid());

-- ── Timed buffs from reputation shop ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.player_reputation_buffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  buff_key text NOT NULL,
  buff_value numeric NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS player_reputation_buffs_user_expires_idx
  ON public.player_reputation_buffs (user_id, expires_at DESC);

ALTER TABLE public.player_reputation_buffs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS player_reputation_buffs_select ON public.player_reputation_buffs;
CREATE POLICY player_reputation_buffs_select ON public.player_reputation_buffs
  FOR SELECT USING (user_id = auth.uid());

-- ── Shop catalog ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reputation_shop_catalog (
  id text PRIMARY KEY,
  name_tr text NOT NULL,
  description_tr text NOT NULL,
  icon_key text NOT NULL DEFAULT 'bolt',
  cost_type text NOT NULL CHECK (cost_type IN ('global', 'faction')),
  cost_amount integer NOT NULL CHECK (cost_amount > 0),
  rarity text NOT NULL DEFAULT 'common',
  effect_key text NOT NULL,
  effect_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  duration_minutes integer,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true
);

INSERT INTO public.reputation_shop_catalog (
  id, name_tr, description_tr, icon_key, cost_type, cost_amount, rarity,
  effect_key, effect_value, duration_minutes, sort_order
) VALUES
  (
    'energy_refill',
    'Enerji Yenileme',
    '+20 enerji — fraksiyon itibarı ile.',
    'bolt',
    'faction', 10, 'uncommon',
    'energy_refill', '{"energy_gain": 20}'::jsonb, NULL, 10
  ),
  (
    'gold_boost_30',
    'Altın Avcısı',
    '30 dk boyunca zindan altın ödülü +%15.',
    'gold',
    'global', 800, 'rare',
    'gold_boost', '{"pct": 15}'::jsonb, 30, 20
  ),
  (
    'drop_boost_30',
    'Ganimet Radarı',
    '30 dk boyunca zindan loot şansı +%10.',
    'loot',
    'global', 1000, 'epic',
    'drop_boost', '{"pct": 10}'::jsonb, 30, 30
  ),
  (
    'siege_morale_60',
    'Kuşatma Morali',
    '60 dk kuşatma zindanı itibar bonusu +%25.',
    'siege',
    'global', 600, 'rare',
    'siege_rep_boost', '{"pct": 25}'::jsonb, 60, 40
  ),
  (
    'honor_title_stub',
    'Onur Nişanı',
    'Profilinde görünen kozmetik unvan (yakında).',
    'title',
    'global', 2000, 'legendary',
    'cosmetic_title', '{"title_key": "onur_nisani"}'::jsonb, NULL, 50
  )
ON CONFLICT (id) DO UPDATE SET
  name_tr = EXCLUDED.name_tr,
  description_tr = EXCLUDED.description_tr,
  icon_key = EXCLUDED.icon_key,
  cost_type = EXCLUDED.cost_type,
  cost_amount = EXCLUDED.cost_amount,
  rarity = EXCLUDED.rarity,
  effect_key = EXCLUDED.effect_key,
  effect_value = EXCLUDED.effect_value,
  duration_minutes = EXCLUDED.duration_minutes,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

-- ── Internal helpers ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._log_reputation_activity(
  p_user_id uuid,
  p_activity_type text,
  p_source text,
  p_amount integer,
  p_currency text DEFAULT 'global',
  p_faction_id text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.reputation_activity_log (
    user_id, activity_type, source, amount, currency, faction_id, metadata
  ) VALUES (
    p_user_id, p_activity_type, p_source, p_amount, p_currency, p_faction_id, p_metadata
  );
END;
$$;

REVOKE ALL ON FUNCTION public._log_reputation_activity(uuid, text, text, integer, text, text, jsonb)
  FROM PUBLIC, anon, authenticated;

-- ── Shop listing ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_reputation_shop()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_global_rep integer := 0;
  v_faction_reps jsonb := '[]'::jsonb;
  v_active_buffs jsonb := '[]'::jsonb;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT COALESCE(reputation, 0) INTO v_global_rep
  FROM public.users WHERE auth_id = v_me;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'faction_id', pfr.faction_id,
    'reputation', pfr.reputation
  ) ORDER BY pfr.faction_id), '[]'::jsonb)
  INTO v_faction_reps
  FROM public.player_faction_reputation pfr
  WHERE pfr.user_id = v_me;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'buff_key', prb.buff_key,
    'buff_value', prb.buff_value,
    'expires_at', prb.expires_at
  ) ORDER BY prb.expires_at DESC), '[]'::jsonb)
  INTO v_active_buffs
  FROM public.player_reputation_buffs prb
  WHERE prb.user_id = v_me AND prb.expires_at > now();

  RETURN jsonb_build_object(
    'success', true,
    'global_reputation', v_global_rep,
    'faction_reputations', v_faction_reps,
    'active_buffs', v_active_buffs,
    'items', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'name', c.name_tr,
        'description', c.description_tr,
        'icon_key', c.icon_key,
        'cost_type', c.cost_type,
        'cost_amount', c.cost_amount,
        'rarity', c.rarity,
        'effect_key', c.effect_key,
        'effect_value', c.effect_value,
        'duration_minutes', c.duration_minutes,
        'sort_order', c.sort_order
      ) ORDER BY c.sort_order), '[]'::jsonb)
      FROM public.reputation_shop_catalog c
      WHERE c.is_active
    )
  );
END;
$$;

-- ── Purchase ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.purchase_reputation_item(
  p_item_id text,
  p_faction_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_item record;
  v_global_rep integer;
  v_faction_rep integer;
  v_energy_gain integer := 20;
  v_duration interval;
  v_buff_value numeric;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_item
  FROM public.reputation_shop_catalog
  WHERE id = p_item_id AND is_active;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ürün bulunamadı');
  END IF;

  IF v_item.cost_type = 'faction' THEN
    IF p_faction_id IS NULL OR p_faction_id NOT IN (
      'tuccarlar', 'zanaatkarlar', 'maceracilar', 'muhafizlar', 'suc_orgutu'
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Fraksiyon seçmelisin');
    END IF;

    INSERT INTO public.player_faction_reputation (user_id, faction_id, reputation)
    VALUES (v_me, p_faction_id, 0)
    ON CONFLICT (user_id, faction_id) DO NOTHING;

    SELECT reputation INTO v_faction_rep
    FROM public.player_faction_reputation
    WHERE user_id = v_me AND faction_id = p_faction_id
    FOR UPDATE;

    IF COALESCE(v_faction_rep, 0) < v_item.cost_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz fraksiyon itibarı');
    END IF;

    UPDATE public.player_faction_reputation
    SET reputation = reputation - v_item.cost_amount, updated_at = now()
    WHERE user_id = v_me AND faction_id = p_faction_id;

    PERFORM public._log_reputation_activity(
      v_me, 'spend', 'shop:' || p_item_id, v_item.cost_amount, 'faction', p_faction_id,
      jsonb_build_object('item_id', p_item_id, 'effect_key', v_item.effect_key)
    );
  ELSE
    SELECT COALESCE(reputation, 0) INTO v_global_rep
    FROM public.users WHERE auth_id = v_me FOR UPDATE;

    IF COALESCE(v_global_rep, 0) < v_item.cost_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Yetersiz itibar');
    END IF;

    UPDATE public.users
    SET reputation = GREATEST(0, COALESCE(reputation, 0) - v_item.cost_amount)
    WHERE auth_id = v_me;

    PERFORM public._log_reputation_activity(
      v_me, 'spend', 'shop:' || p_item_id, v_item.cost_amount, 'global', NULL,
      jsonb_build_object('item_id', p_item_id, 'effect_key', v_item.effect_key)
    );
  END IF;

  -- Apply effect
  IF v_item.effect_key = 'energy_refill' THEN
    v_energy_gain := COALESCE((v_item.effect_value->>'energy_gain')::integer, 20);
    UPDATE public.users
    SET energy = LEAST(COALESCE(max_energy, 100), COALESCE(energy, 0) + v_energy_gain)
    WHERE auth_id = v_me;
    RETURN jsonb_build_object(
      'success', true,
      'item_id', p_item_id,
      'effect', 'energy_refill',
      'energy_gain', v_energy_gain
    );
  ELSIF v_item.effect_key IN ('gold_boost', 'drop_boost', 'siege_rep_boost') THEN
    v_duration := make_interval(mins => COALESCE(v_item.duration_minutes, 30));
    v_buff_value := COALESCE((v_item.effect_value->>'pct')::numeric, 0);
    INSERT INTO public.player_reputation_buffs (user_id, buff_key, buff_value, expires_at)
    VALUES (v_me, v_item.effect_key, v_buff_value, now() + v_duration);
    RETURN jsonb_build_object(
      'success', true,
      'item_id', p_item_id,
      'effect', v_item.effect_key,
      'buff_value', v_buff_value,
      'expires_at', (now() + v_duration)
    );
  ELSIF v_item.effect_key = 'cosmetic_title' THEN
    RETURN jsonb_build_object(
      'success', true,
      'item_id', p_item_id,
      'effect', 'cosmetic_title',
      'title_key', v_item.effect_value->>'title_key',
      'message', 'Onur Nişanı kaydedildi — profil entegrasyonu yakında.'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'item_id', p_item_id);
END;
$$;

-- ── Overview (global + factions + activity) ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_reputation_overview()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_global_rep integer := 0;
  v_factions jsonb := '[]'::jsonb;
  v_activity jsonb := '[]'::jsonb;
  v_buffs jsonb := '[]'::jsonb;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Ensure faction rows exist (reuse get_reputation seed logic)
  INSERT INTO public.player_faction_reputation (user_id, faction_id, reputation)
  SELECT v_me, f.id, 0
  FROM (
    VALUES
      ('tuccarlar'),
      ('zanaatkarlar'),
      ('maceracilar'),
      ('muhafizlar'),
      ('suc_orgutu')
  ) AS f(id)
  ON CONFLICT (user_id, faction_id) DO NOTHING;

  SELECT COALESCE(reputation, 0) INTO v_global_rep
  FROM public.users WHERE auth_id = v_me;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'faction_id', pfr.faction_id,
    'id', pfr.faction_id,
    'reputation', pfr.reputation,
    'rep', pfr.reputation
  ) ORDER BY pfr.faction_id), '[]'::jsonb)
  INTO v_factions
  FROM public.player_faction_reputation pfr
  WHERE pfr.user_id = v_me;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', ral.id,
    'activity_type', ral.activity_type,
    'source', ral.source,
    'amount', ral.amount,
    'currency', ral.currency,
    'faction_id', ral.faction_id,
    'metadata', ral.metadata,
    'created_at', ral.created_at
  ) ORDER BY ral.created_at DESC), '[]'::jsonb)
  INTO v_activity
  FROM (
    SELECT * FROM public.reputation_activity_log
    WHERE user_id = v_me
    ORDER BY created_at DESC
    LIMIT 25
  ) ral;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'buff_key', prb.buff_key,
    'buff_value', prb.buff_value,
    'expires_at', prb.expires_at
  ) ORDER BY prb.expires_at DESC), '[]'::jsonb)
  INTO v_buffs
  FROM public.player_reputation_buffs prb
  WHERE prb.user_id = v_me AND prb.expires_at > now();

  RETURN jsonb_build_object(
    'success', true,
    'global_reputation', v_global_rep,
    'factions', v_factions,
    'activity', v_activity,
    'active_buffs', v_buffs
  );
END;
$$;

-- Log on existing spend_faction_reputation
CREATE OR REPLACE FUNCTION public.spend_faction_reputation(
  p_faction_id text,
  p_rep_cost integer DEFAULT 10,
  p_perk_key text DEFAULT 'energy_refill'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_current integer;
  v_energy_gain integer := 20;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_faction_id NOT IN ('tuccarlar', 'zanaatkarlar', 'maceracilar', 'muhafizlar', 'suc_orgutu') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz fraksiyon');
  END IF;

  IF p_rep_cost IS NULL OR p_rep_cost < 5 OR p_rep_cost > 50 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz itibar maliyeti');
  END IF;

  INSERT INTO public.player_faction_reputation (user_id, faction_id, reputation)
  VALUES (v_me, p_faction_id, 0)
  ON CONFLICT (user_id, faction_id) DO NOTHING;

  SELECT reputation INTO v_current
  FROM public.player_faction_reputation
  WHERE user_id = v_me AND faction_id = p_faction_id
  FOR UPDATE;

  IF COALESCE(v_current, 0) < p_rep_cost THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz fraksiyon itibarı');
  END IF;

  UPDATE public.player_faction_reputation
  SET reputation = reputation - p_rep_cost, updated_at = now()
  WHERE user_id = v_me AND faction_id = p_faction_id;

  UPDATE public.users
  SET energy = LEAST(COALESCE(max_energy, 100), COALESCE(energy, 0) + v_energy_gain)
  WHERE auth_id = v_me;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;

  PERFORM public._log_reputation_activity(
    v_me, 'spend', 'perk:' || COALESCE(p_perk_key, 'energy_refill'),
    p_rep_cost, 'faction', p_faction_id,
    jsonb_build_object('perk', p_perk_key, 'energy_gain', v_energy_gain)
  );

  RETURN jsonb_build_object(
    'success', true,
    'rep_spent', p_rep_cost,
    'energy_gain', v_energy_gain,
    'perk', p_perk_key
  );
END;
$$;

-- Log donation activity
CREATE OR REPLACE FUNCTION public.donate_to_faction(
  p_faction_id text,
  p_gold_amount bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_rep_gain integer;
  v_current integer;
  v_new_rep integer;
BEGIN
  IF v_me IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_faction_id NOT IN ('tuccarlar', 'zanaatkarlar', 'maceracilar', 'muhafizlar', 'suc_orgutu') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz fraksiyon');
  END IF;

  IF p_gold_amount IS NULL OR p_gold_amount < 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum bağış 100 altın');
  END IF;

  v_rep_gain := (p_gold_amount / 100)::integer;
  IF v_rep_gain <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bağış miktarı yetersiz');
  END IF;

  UPDATE public.users
  SET gold = gold - p_gold_amount
  WHERE auth_id = v_me AND gold >= p_gold_amount;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetersiz altın');
  END IF;

  INSERT INTO public.player_faction_reputation (user_id, faction_id, reputation)
  VALUES (v_me, p_faction_id, 0)
  ON CONFLICT (user_id, faction_id) DO NOTHING;

  SELECT reputation INTO v_current
  FROM public.player_faction_reputation
  WHERE user_id = v_me AND faction_id = p_faction_id
  FOR UPDATE;

  v_new_rep := LEAST(100, COALESCE(v_current, 0) + v_rep_gain);

  UPDATE public.player_faction_reputation
  SET reputation = v_new_rep, updated_at = now()
  WHERE user_id = v_me AND faction_id = p_faction_id;

  PERFORM public._log_reputation_activity(
    v_me, 'earn', 'donation', v_new_rep - COALESCE(v_current, 0), 'faction', p_faction_id,
    jsonb_build_object('gold_spent', p_gold_amount)
  );

  RETURN jsonb_build_object(
    'success', true,
    'rep_gain', v_new_rep - COALESCE(v_current, 0),
    'reputation', v_new_rep,
    'gold_spent', p_gold_amount
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_reputation_shop() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reputation_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_reputation_item(text, text) TO authenticated;

COMMIT;
