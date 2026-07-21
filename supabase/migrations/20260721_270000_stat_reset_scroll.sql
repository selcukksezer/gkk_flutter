-- Stat sıfırlama kağıdı (gem shop) + allocated stat tracking.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS stat_allocated_attack INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stat_allocated_defense INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stat_allocated_luck INTEGER NOT NULL DEFAULT 0;

-- Legacy dağıtımlar için yaklaşık backfill (eşit böl).
UPDATE public.users u
SET
  stat_allocated_attack = s.spent / 3,
  stat_allocated_defense = s.spent / 3,
  stat_allocated_luck = s.spent - (2 * (s.spent / 3))
FROM (
  SELECT
    auth_id,
    GREATEST(0, (GREATEST(level, 1) - 1) * 3 - stat_points) AS spent
  FROM public.users
) s
WHERE u.auth_id = s.auth_id
  AND s.spent > 0
  AND (u.stat_allocated_attack + u.stat_allocated_defense + u.stat_allocated_luck) = 0;

INSERT INTO public.items (
  id, name, type, description, rarity,
  base_price, vendor_sell_price,
  is_tradeable, is_stackable, max_stack,
  shop_available, shop_currency, icon
) VALUES (
  'scroll_stat_reset',
  'Stat Sıfırlama Kağıdı',
  'consumable',
  'Dağıttığın stat puanlarını geri alır. Saldırı, Savunma ve Şans bonusları sıfırlanır.',
  'epic',
  199, 0,
  false, true, 5,
  true, 'gems', '📜'
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  type = EXCLUDED.type,
  base_price = EXCLUDED.base_price,
  shop_available = EXCLUDED.shop_available,
  shop_currency = EXCLUDED.shop_currency,
  icon = EXCLUDED.icon;

CREATE OR REPLACE FUNCTION public.allocate_stat_points(
  p_attack INTEGER DEFAULT 0,
  p_defense INTEGER DEFAULT 0,
  p_luck INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_id UUID;
  v_total INTEGER;
  v_available INTEGER;
BEGIN
  v_auth_id := auth.uid();
  IF v_auth_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  IF p_attack < 0 OR p_defense < 0 OR p_luck < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid allocation');
  END IF;

  v_total := p_attack + p_defense + p_luck;
  IF v_total <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Nothing to allocate');
  END IF;

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
  SET attack = COALESCE(attack, 0) + p_attack,
      defense = COALESCE(defense, 0) + p_defense,
      luck = COALESCE(luck, 0) + p_luck,
      stat_points = stat_points - v_total,
      stat_allocated_attack = COALESCE(stat_allocated_attack, 0) + p_attack,
      stat_allocated_defense = COALESCE(stat_allocated_defense, 0) + p_defense,
      stat_allocated_luck = COALESCE(stat_allocated_luck, 0) + p_luck,
      updated_at = NOW()
  WHERE auth_id = v_auth_id;

  RETURN jsonb_build_object(
    'success', true,
    'spent', v_total,
    'remaining', v_available - v_total
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.use_stat_reset_scroll(
  p_row_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inv RECORD;
  v_user RECORD;
  v_refund INTEGER;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id
    AND user_id = p_user_id
    AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya bulunamadı');
  END IF;

  IF v_inv.item_id <> 'scroll_stat_reset' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşya');
  END IF;

  v_refund := COALESCE(v_user.stat_allocated_attack, 0)
            + COALESCE(v_user.stat_allocated_defense, 0)
            + COALESCE(v_user.stat_allocated_luck, 0);

  IF v_refund <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Sıfırlanacak dağıtılmış stat puanı yok'
    );
  END IF;

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eşya tüketilemedi');
  END IF;

  UPDATE public.users
  SET attack = GREATEST(0, COALESCE(attack, 0) - COALESCE(stat_allocated_attack, 0)),
      defense = GREATEST(0, COALESCE(defense, 0) - COALESCE(stat_allocated_defense, 0)),
      luck = GREATEST(0, COALESCE(luck, 0) - COALESCE(stat_allocated_luck, 0)),
      stat_points = COALESCE(stat_points, 0) + v_refund,
      stat_allocated_attack = 0,
      stat_allocated_defense = 0,
      stat_allocated_luck = 0,
      updated_at = NOW()
  WHERE auth_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'refunded', v_refund,
    'message', format('%s stat puanı geri alındı', v_refund)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.use_stat_reset_scroll(UUID, UUID) TO authenticated;
