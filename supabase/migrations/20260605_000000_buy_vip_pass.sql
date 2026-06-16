-- ============================================================
-- Migration: buy_vip_pass RPC — VIP Battle Pass Purchase
-- ============================================================
-- This migration:
--   1) Adds UPDATE RLS policy for bp_player_status so users can
--      only update their own status row (needed for VIP purchase).
--   2) Creates buy_vip_pass RPC: Gem bakiye kontrolü → düş → VIP aktif et
-- ============================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 1: bp_player_status UPDATE RLS Policy
-- ─────────────────────────────────────────────────────────────
-- Mevcut policy sadece SELECT'e izin veriyor. UPDATE policy ekliyoruz.
DROP POLICY IF EXISTS "Players can update their own status" ON public.bp_player_status;

CREATE POLICY "Players can update their own status" ON public.bp_player_status
  FOR UPDATE
  USING (auth.uid() = player_id)
  WITH CHECK (auth.uid() = player_id);

-- ─────────────────────────────────────────────────────────────
-- BÖLÜM 2: buy_vip_pass RPC
-- ─────────────────────────────────────────────────────────────
-- Bu RPC, VIP Battle Pass satın alımını sunucu tarafında halleder:
--   1) Aktif sezonu bul
--   2) Oyuncunun zaten VIP olup olmadığını kontrol et
--   3) Gem bakiyesini kontrol et ve düş
--   4) bp_player_status.has_vip = true yap
--   5) Başarılı / hata dönüşü

CREATE OR REPLACE FUNCTION public.buy_vip_pass()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id UUID;
  v_active_season_id UUID;
  v_status RECORD;
  v_gems INTEGER;
  v_vip_cost CONSTANT INTEGER := 500; -- VIP için 500 gem
BEGIN
  -- 1) Kimlik doğrula
  v_player_id := auth.uid();
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  -- 2) Aktif sezonu bul
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif sezon bulunamadı.');
  END IF;

  -- 3) Oyuncu sezon durumunu kontrol et
  SELECT * FROM public.bp_player_status 
  WHERE player_id = v_player_id AND season_id = v_active_season_id 
  INTO v_status;

  IF v_status IS NULL THEN
    -- İlk defa giriş: durumu oluştur
    INSERT INTO public.bp_player_status (player_id, season_id, current_bpp, current_level, daily_grind_bpp_pool, daily_pvp_bpp_pool, has_vip, claimed_normal, claimed_vip)
    VALUES (v_player_id, v_active_season_id, 0, 1, 0, 0, false, '{}', '{}')
    RETURNING * INTO v_status;
  END IF;

  -- 4) Zaten VIP mi?
  IF v_status.has_vip THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten VIP aktif.');
  END IF;

  -- 5) Gem bakiyesini kontrol et
  SELECT gems INTO v_gems FROM public.users WHERE auth_id = v_player_id;
  IF v_gems IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı profili bulunamadı.');
  END IF;

  IF v_gems < v_vip_cost THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Yetersiz elmas! VIP Pass için ' || v_vip_cost || ' 💎 gerekiyor, ' || v_gems || ' 💎 var.',
      'required', v_vip_cost,
      'current', v_gems
    );
  END IF;

  -- 6) Gem bakiyesini düş ve VIP'yi aktifleştir (transactional)
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

-- Grant: authenticated kullanıcılar çağırabilsin
GRANT EXECUTE ON FUNCTION public.buy_vip_pass() TO authenticated;

COMMIT;

-- ============================================================
-- ÖZET:
-- ✅ bp_player_status UPDATE RLS policy eklendi
-- ✅ buy_vip_pass RPC: Gem kontrolü → düş → VIP aktif
-- ==============================================================