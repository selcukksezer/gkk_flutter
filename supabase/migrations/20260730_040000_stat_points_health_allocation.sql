-- Stat points → max health: 1 point = +10 max/current health (multiplier).

BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS stat_allocated_health INTEGER NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.stat_point_health_multiplier()
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 10;
$$;

CREATE OR REPLACE FUNCTION public.stat_point_health_gain(p_points integer)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT GREATEST(0, COALESCE(p_points, 0)) * public.stat_point_health_multiplier();
$$;

DROP FUNCTION IF EXISTS public.allocate_stat_points(integer, integer, integer);

CREATE OR REPLACE FUNCTION public.allocate_stat_points(
  p_attack integer DEFAULT 0,
  p_defense integer DEFAULT 0,
  p_luck integer DEFAULT 0,
  p_health integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_id uuid;
  v_total integer;
  v_available integer;
  v_health_gain integer;
  v_new_max integer;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_attack < 0 OR p_defense < 0 OR p_luck < 0 OR p_health < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid allocation');
  END IF;

  v_total := p_attack + p_defense + p_luck + p_health;
  IF v_total <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Nothing to allocate');
  END IF;

  v_health_gain := public.stat_point_health_gain(p_health);

  SELECT stat_points INTO v_available
  FROM public.users
  WHERE auth_id = v_auth_id
  FOR UPDATE;

  IF v_available IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_available < v_total THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient stat points');
  END IF;

  UPDATE public.users
  SET
    attack = COALESCE(attack, 0) + p_attack,
    defense = COALESCE(defense, 0) + p_defense,
    luck = COALESCE(luck, 0) + p_luck,
    max_health = COALESCE(max_health, 100) + v_health_gain,
    health = LEAST(
      COALESCE(max_health, 100) + v_health_gain,
      COALESCE(health, 0) + v_health_gain
    ),
    stat_points = stat_points - v_total,
    stat_allocated_attack = COALESCE(stat_allocated_attack, 0) + p_attack,
    stat_allocated_defense = COALESCE(stat_allocated_defense, 0) + p_defense,
    stat_allocated_luck = COALESCE(stat_allocated_luck, 0) + p_luck,
    stat_allocated_health = COALESCE(stat_allocated_health, 0) + p_health,
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = v_auth_id
  RETURNING max_health INTO v_new_max;

  RETURN jsonb_build_object(
    'success', true,
    'spent', v_total,
    'remaining', v_available - v_total,
    'health_gain', v_health_gain,
    'max_health', v_new_max,
    'health_multiplier', public.stat_point_health_multiplier()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.allocate_stat_points(integer, integer, integer, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.use_stat_reset_scroll(
  p_row_id uuid,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inv record;
  v_user record;
  v_refund integer;
  v_health_bonus integer;
  v_new_max integer;
  v_new_health integer;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz islem');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanici bulunamadi');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id
    AND user_id = p_user_id
    AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Esya bulunamadi');
  END IF;

  IF v_inv.item_id <> 'scroll_stat_reset' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Gecersiz esya');
  END IF;

  v_refund := COALESCE(v_user.stat_allocated_attack, 0)
            + COALESCE(v_user.stat_allocated_defense, 0)
            + COALESCE(v_user.stat_allocated_luck, 0)
            + COALESCE(v_user.stat_allocated_health, 0);

  IF v_refund <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Sifirlanacak dagitilmis stat puani yok'
    );
  END IF;

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Esya tuketilemedi');
  END IF;

  v_health_bonus := public.stat_point_health_gain(COALESCE(v_user.stat_allocated_health, 0));
  v_new_max := GREATEST(100, COALESCE(v_user.max_health, 100) - v_health_bonus);
  v_new_health := LEAST(
    GREATEST(1, COALESCE(v_user.health, 0) - v_health_bonus),
    v_new_max
  );

  UPDATE public.users
  SET
    attack = GREATEST(0, COALESCE(attack, 0) - COALESCE(stat_allocated_attack, 0)),
    defense = GREATEST(0, COALESCE(defense, 0) - COALESCE(stat_allocated_defense, 0)),
    luck = GREATEST(0, COALESCE(luck, 0) - COALESCE(stat_allocated_luck, 0)),
    max_health = v_new_max,
    health = v_new_health,
    stat_points = COALESCE(stat_points, 0) + v_refund,
    stat_allocated_attack = 0,
    stat_allocated_defense = 0,
    stat_allocated_luck = 0,
    stat_allocated_health = 0,
    health_last_updated = now(),
    updated_at = now()
  WHERE auth_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'refunded', v_refund,
    'message', format('%s stat puani geri alindi', v_refund)
  );
END;
$$;

UPDATE public.items
SET description = 'Dagittigin stat puanlarini geri alir. Saldirı, Savunma, Sans ve Can bonuslari sifirlanir.'
WHERE id = 'scroll_stat_reset';

COMMIT;
