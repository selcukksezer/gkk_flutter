-- Faction reputation RPCs: get_reputation, donate_to_faction (gold sink), spend_faction_reputation (rep sink).

BEGIN;

CREATE TABLE IF NOT EXISTS public.player_faction_reputation (
  user_id uuid NOT NULL REFERENCES auth.users (auth_id) ON DELETE CASCADE,
  faction_id text NOT NULL,
  reputation integer NOT NULL DEFAULT 0 CHECK (reputation BETWEEN 0 AND 100),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, faction_id)
);

ALTER TABLE public.player_faction_reputation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS player_faction_rep_select ON public.player_faction_reputation;
CREATE POLICY player_faction_rep_select ON public.player_faction_reputation
  FOR SELECT USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.get_reputation()
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

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

  RETURN QUERY
  SELECT jsonb_build_object(
    'faction_id', pfr.faction_id,
    'id', pfr.faction_id,
    'reputation', pfr.reputation,
    'rep', pfr.reputation,
    'tasks', '[]'::jsonb
  )
  FROM public.player_faction_reputation pfr
  WHERE pfr.user_id = v_me
  ORDER BY pfr.faction_id;
END;
$$;

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
  WHERE auth_id = v_me
    AND gold >= p_gold_amount;

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

  RETURN jsonb_build_object(
    'success', true,
    'rep_gain', v_new_rep - COALESCE(v_current, 0),
    'reputation', v_new_rep,
    'gold_spent', p_gold_amount
  );
END;
$$;

-- Reputation sink: spend faction rep for a small energy refill (inflation / rep sink).
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

  RETURN jsonb_build_object(
    'success', true,
    'rep_spent', p_rep_cost,
    'energy_gain', v_energy_gain,
    'perk', p_perk_key
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_reputation() TO authenticated;
GRANT EXECUTE ON FUNCTION public.donate_to_faction(text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.spend_faction_reputation(text, integer, text) TO authenticated;

COMMIT;
