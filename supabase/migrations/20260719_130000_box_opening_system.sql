-- ============================================================================
-- KUTU AÇMA SİSTEMİ (zamanlı açılma)
-- - start_box_opening: gem öde (anında açılır) VEYA reklam izle (30 dk sayaç)
-- - claim_box_reward: süre dolunca ödül; envanter dolu ise claim engellenir
-- - cancel_box_opening: kutu silinir, açılma 'deleted' olur — ödül iptal
-- - get_box_openings: oyuncunun aktif/claim bekleyen açılmaları
-- Açılmadaki kutu kilitlidir (client aksiyonları kapatır; claim/cancel dışında
-- satır tüketilmez).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.box_openings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  inventory_row_id UUID NOT NULL,
  box_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'opening'
    CHECK (status IN ('opening', 'claimed', 'deleted')),
  payment TEXT NOT NULL DEFAULT 'gems' CHECK (payment IN ('gems', 'ad')),
  gems_spent NUMERIC NOT NULL DEFAULT 0,
  opens_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  claimed_at TIMESTAMPTZ
);

-- Aynı kutu satırı için tek aktif açılma
CREATE UNIQUE INDEX IF NOT EXISTS box_openings_active_row_uidx
  ON public.box_openings (inventory_row_id)
  WHERE status = 'opening';

CREATE INDEX IF NOT EXISTS box_openings_user_idx
  ON public.box_openings (user_id, status);

ALTER TABLE public.box_openings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "box_openings_select_own" ON public.box_openings;
CREATE POLICY "box_openings_select_own" ON public.box_openings
  FOR SELECT USING (auth.uid() = user_id);

-- ── START ───────────────────────────────────────────────────────────────────
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
    v_opens_at := now(); -- gem ödemesi anında açar
  ELSE
    v_opens_at := now() + interval '30 minutes'; -- reklam yolu: 30 dk sayaç
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

-- ── CLAIM ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.claim_box_reward(p_opening_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_open RECORD;
  v_inv RECORD;
  v_box RECORD;
  v_drop RECORD;
  v_occupied INT;
  v_reward_qty INT := 1;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_open
  FROM public.box_openings
  WHERE id = p_opening_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND OR v_open.status != 'opening' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Açılma kaydı bulunamadı');
  END IF;

  IF now() < v_open.opens_at THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kutu henüz açılmadı');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = v_open.inventory_row_id AND user_id = v_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Kutu satırı yok (silinmiş) — açılmayı geçersiz kıl
    UPDATE public.box_openings SET status = 'deleted' WHERE id = p_opening_id;
    RETURN jsonb_build_object('success', false, 'error', 'Kutu envanterde yok — ödül iptal');
  END IF;

  -- Envanter dolu kontrolü (kutu satırı hariç)
  SELECT COUNT(*) INTO v_occupied
  FROM public.inventory
  WHERE user_id = v_user_id
    AND NOT is_equipped
    AND row_id != v_open.inventory_row_id;

  IF v_occupied >= 20 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'inventory_full',
      'message', 'Envanterin dolu! Ödülü almak için yer aç.'
    );
  END IF;

  SELECT * INTO v_box FROM public.loot_box_configs WHERE id = v_open.box_id;

  SELECT
    e.item_id, e.weight, e.min_quantity, e.max_quantity,
    i.name AS item_name, i.icon,
    COALESCE(i.is_stackable, false) AS is_stackable
  INTO v_drop
  FROM public.loot_box_drop_entries e
  JOIN public.items i ON i.id = e.item_id
  WHERE e.box_id = v_open.box_id AND e.is_active = TRUE
  ORDER BY -LN(GREATEST(random(), 1e-9)) / GREATEST(e.weight, 1e-9)
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu kutu için ödül tanımı yok');
  END IF;

  IF NOT public._consume_inventory_row(v_open.inventory_row_id, v_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kutu tüketilemedi');
  END IF;

  IF COALESCE(v_drop.is_stackable, false) THEN
    v_reward_qty := GREATEST(
      1,
      FLOOR(random() * (v_drop.max_quantity - v_drop.min_quantity + 1) + v_drop.min_quantity)::INT
    );
  END IF;

  IF NOT public.dungeon_add_item(v_user_id, v_drop.item_id, v_reward_qty) THEN
    -- Ödül sığmadı — kutuyu geri ver, açılma devam etsin
    INSERT INTO public.inventory (user_id, item_id, quantity, slot_position, is_equipped)
    VALUES (v_user_id, v_open.box_id, 1, v_inv.slot_position, false);
    RETURN jsonb_build_object(
      'success', false,
      'error', 'inventory_full',
      'message', 'Envanterin dolu! Ödülü almak için yer aç.'
    );
  END IF;

  UPDATE public.box_openings
  SET status = 'claimed', claimed_at = now()
  WHERE id = p_opening_id;

  INSERT INTO public.player_loot_box_logs (
    user_id, box_id, spent_currency, spent_amount,
    reward_type, reward_item_id, reward_amount, roll_weight, metadata
  )
  VALUES (
    v_user_id, v_open.box_id, v_open.payment,
    COALESCE(v_open.gems_spent, 0),
    'item', v_drop.item_id, v_reward_qty, v_drop.weight,
    jsonb_build_object(
      'source', 'box_opening',
      'opening_id', p_opening_id,
      'box_name', COALESCE(v_box.name, v_open.box_id),
      'item_name', v_drop.item_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'box_id', v_open.box_id,
    'box_name', COALESCE(v_box.name, v_open.box_id),
    'reward', jsonb_build_object(
      'type', 'item',
      'item_id', v_drop.item_id,
      'name', v_drop.item_name,
      'icon', v_drop.icon,
      'quantity', v_reward_qty
    )
  );
END;
$$;

-- ── CANCEL / SİL ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_box_opening(p_opening_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_open RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_open
  FROM public.box_openings
  WHERE id = p_opening_id AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND OR v_open.status != 'opening' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Açılma kaydı bulunamadı');
  END IF;

  -- Kutu satırını sil — ödül süresi dolmuş olsa bile verilmez
  DELETE FROM public.inventory
  WHERE row_id = v_open.inventory_row_id AND user_id = v_user_id;

  UPDATE public.box_openings SET status = 'deleted' WHERE id = p_opening_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── LİSTE ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_box_openings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_rows JSONB;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN '[]'::JSONB;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'opening_id', bo.id,
    'inventory_row_id', bo.inventory_row_id,
    'box_id', bo.box_id,
    'box_name', COALESCE(cfg.name, bo.box_id),
    'opens_at', bo.opens_at,
    'ready', now() >= bo.opens_at,
    'payment', bo.payment
  ) ORDER BY bo.opens_at ASC), '[]'::JSONB)
  INTO v_rows
  FROM public.box_openings bo
  LEFT JOIN public.loot_box_configs cfg ON cfg.id = bo.box_id
  WHERE bo.user_id = v_user_id AND bo.status = 'opening';

  RETURN v_rows;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_box_opening(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_box_reward(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_box_opening(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_box_openings() TO authenticated;
