-- ============================================================
-- Migration: buy_vip_pass TOCTOU race fix (row lock)
-- ============================================================
-- QA audit bulgusu: has_vip okuma ile UPDATE arasında satır kilidi
-- yoktu. Eşzamanlı 2 çağrı çift VIP grant + çift gem düşümü
-- yapabilir. Kullanıcı satırını FOR UPDATE ile kilitliyoruz.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.buy_vip_pass()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_player_id UUID;
  v_active_season_id UUID;
  v_status RECORD;
  v_gems INTEGER;
  v_vip_cost CONSTANT INTEGER := 500;
BEGIN
  v_player_id := auth.uid();
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif sezon bulunamadı.');
  END IF;

  -- Kullanıcı satırını kilitle: eşzamanlı çift satın almayı engeller.
  SELECT gems INTO v_gems FROM public.users
  WHERE auth_id = v_player_id
  FOR UPDATE;

  IF v_gems IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı profili bulunamadı.');
  END IF;

  -- Durumu kilitle (yoksa oluştur).
  SELECT * FROM public.bp_player_status
  WHERE player_id = v_player_id AND season_id = v_active_season_id
  INTO v_status
  FOR UPDATE;

  IF v_status IS NULL THEN
    INSERT INTO public.bp_player_status (player_id, season_id, current_bpp, current_level, daily_grind_bpp_pool, daily_pvp_bpp_pool, has_vip, claimed_normal, claimed_vip)
    VALUES (v_player_id, v_active_season_id, 0, 1, 0, 0, false, '{}', '{}')
    RETURNING * INTO v_status;
  END IF;

  IF v_status.has_vip THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten VIP aktif.');
  END IF;

  IF v_gems < v_vip_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Yetersiz elmas! VIP Pass için ' || v_vip_cost || ' 💎 gerekiyor, ' || v_gems || ' 💎 var.',
      'required', v_vip_cost,
      'current', v_gems
    );
  END IF;

  UPDATE public.users
  SET gems = gems - v_vip_cost
  WHERE auth_id = v_player_id;

  UPDATE public.bp_player_status
  SET has_vip = true, updated_at = now()
  WHERE player_id = v_player_id AND season_id = v_active_season_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'VIP Pass başarıyla aktif edildi!',
    'new_gem_balance', v_gems - v_vip_cost
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.buy_vip_pass() TO authenticated;

COMMIT;
