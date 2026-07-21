-- detox_minor/major/supreme: catalog rows lack sub_type='detox' but are valid detox drinks (PLAN_08)

CREATE OR REPLACE FUNCTION public.use_detox(
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
  v_item RECORD;
  v_user RECORD;
  v_tolerance_reduction INT;
  v_addiction_reduction INT;
  v_cooldown_hours INT;
  v_new_tolerance INT;
  v_new_addiction INT;
  v_detox_type TEXT;
  v_detox_mult numeric := 1.0;
BEGIN
  IF p_user_id IS NULL OR p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı');
  END IF;

  SELECT * INTO v_inv
  FROM public.inventory
  WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR NOT (
    lower(COALESCE(v_item.sub_type, '')) = 'detox'
    OR v_item.id LIKE 'detox_%'
  ) THEN
    RETURN jsonb_build_object('error', 'Geçersiz detox içeceği');
  END IF;

  IF v_item.id = 'detox_minor' THEN
    v_detox_type := 'minor'; v_tolerance_reduction := 15; v_addiction_reduction := 0; v_cooldown_hours := 4;
  ELSIF v_item.id = 'detox_major' THEN
    v_detox_type := 'major'; v_tolerance_reduction := 35; v_addiction_reduction := 1; v_cooldown_hours := 8;
  ELSIF v_item.id = 'detox_supreme' THEN
    v_detox_type := 'supreme'; v_tolerance_reduction := 60; v_addiction_reduction := 2; v_cooldown_hours := 12;
  ELSIF v_item.id = 'detox_full_cleanse' THEN
    v_detox_type := 'full_cleanse'; v_tolerance_reduction := 100; v_addiction_reduction := 10; v_cooldown_hours := 24;
  ELSE
    v_detox_type := 'minor'; v_tolerance_reduction := 15; v_addiction_reduction := 0; v_cooldown_hours := 4;
  END IF;

  IF COALESCE(v_user.character_class, '') = 'alchemist' THEN
    v_detox_mult := 1 + public._passive_bonus('alchemist', 'detox_effectiveness_bonus', 0.25);
    v_tolerance_reduction := CEIL(v_tolerance_reduction * v_detox_mult)::integer;
    v_addiction_reduction := CEIL(v_addiction_reduction * v_detox_mult)::integer;
  END IF;

  IF v_user.last_detox_used_at IS NOT NULL
     AND v_user.last_detox_used_at + (v_cooldown_hours || ' hours')::interval > now() THEN
    RETURN jsonb_build_object('error', 'Detox cooldown aktif. Kalan süre için bekleyin.');
  END IF;

  v_new_tolerance := GREATEST(COALESCE(v_user.tolerance, 0) - v_tolerance_reduction, 0);
  v_new_addiction := GREATEST(COALESCE(v_user.addiction_level, 0) - v_addiction_reduction, 0);

  IF NOT public._consume_inventory_row(p_row_id, p_user_id) THEN
    RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz');
  END IF;

  UPDATE public.users
  SET tolerance = v_new_tolerance,
      addiction_level = v_new_addiction,
      last_detox_used_at = now(),
      detox_type_last = v_detox_type
  WHERE auth_id = p_user_id;

  INSERT INTO public.tolerance_log (
    user_id, event_type, item_id,
    tolerance_before, tolerance_after,
    addiction_before, addiction_after
  )
  VALUES (
    p_user_id, 'detox', v_item.id,
    COALESCE(v_user.tolerance, 0), v_new_tolerance,
    COALESCE(v_user.addiction_level, 0), v_new_addiction
  );

  RETURN jsonb_build_object(
    'success', true,
    'detox_type', v_detox_type,
    'new_tolerance', v_new_tolerance,
    'new_addiction', v_new_addiction
  );
END;
$$;

UPDATE public.items
SET sub_type = 'detox'
WHERE id IN ('detox_minor', 'detox_major', 'detox_supreme', 'detox_full_cleanse')
  AND COALESCE(sub_type, '') = '';

GRANT EXECUTE ON FUNCTION public.use_detox(UUID, UUID) TO authenticated;
