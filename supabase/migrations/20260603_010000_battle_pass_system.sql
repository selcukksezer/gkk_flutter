-- Battle Pass (BBP) System Migration

-- 1. SEZON KONTROLÜ
CREATE TABLE IF NOT EXISTS public.bp_seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_number integer NOT NULL,
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- 2. STATİK GÖREV ŞABLONLARI
CREATE TABLE IF NOT EXISTS public.bp_quest_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quest_type text CHECK (quest_type IN ('daily', 'weekly')),
  target_system text CHECK (target_system IN ('dungeon', 'pvp', 'craft', 'potion')),
  target_count integer NOT NULL,
  bpp_reward integer NOT NULL,
  description text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- 3. OYUNCU SEZON DURUMU
CREATE TABLE IF NOT EXISTS public.bp_player_status (
  player_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  season_id uuid REFERENCES public.bp_seasons(id) ON DELETE CASCADE,
  current_bpp integer DEFAULT 0 CHECK (current_bpp >= 0),
  current_level integer DEFAULT 1 CHECK (current_level BETWEEN 1 AND 20),
  daily_grind_bpp_pool integer DEFAULT 0 CHECK (daily_grind_bpp_pool <= 300),
  has_vip boolean DEFAULT false,
  claimed_normal integer[] DEFAULT '{}',
  claimed_vip integer[] DEFAULT '{}',
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (player_id, season_id)
);

-- 4. OYUNCU GÖREVLERİ
CREATE TABLE IF NOT EXISTS public.bp_player_quests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  season_id uuid REFERENCES public.bp_seasons(id) ON DELETE CASCADE,
  template_id uuid REFERENCES public.bp_quest_templates(id) ON DELETE CASCADE,
  current_progress integer DEFAULT 0 CHECK (current_progress >= 0),
  is_completed boolean DEFAULT false,
  updated_at timestamptz DEFAULT now()
);

-- 5. SEVİYE ÖDÜLLERİ TANIMLAMA
CREATE TABLE IF NOT EXISTS public.bp_level_rewards (
  level integer PRIMARY KEY CHECK (level BETWEEN 1 AND 20),
  normal_reward_item_id text REFERENCES public.items(id),
  normal_reward_quantity integer DEFAULT 1,
  normal_reward_gold integer DEFAULT 0,
  vip_reward_item_id text REFERENCES public.items(id),
  vip_reward_quantity integer DEFAULT 1,
  vip_reward_gold integer DEFAULT 0,
  description text
);

-- RLS Enablement
ALTER TABLE public.bp_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bp_quest_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bp_player_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bp_player_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bp_level_rewards ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Basic - can be refined later)
CREATE POLICY "Anyone can view active season" ON public.bp_seasons FOR SELECT USING (true);
CREATE POLICY "Anyone can view quest templates" ON public.bp_quest_templates FOR SELECT USING (true);
CREATE POLICY "Players can view their own status" ON public.bp_player_status FOR SELECT USING (auth.uid() = player_id);
CREATE POLICY "Players can view their own quests" ON public.bp_player_quests FOR SELECT USING (auth.uid() = player_id);
CREATE POLICY "Anyone can view level rewards" ON public.bp_level_rewards FOR SELECT USING (true);

-- 6. FUNCTIONS

-- A. Seviye Atlama Kontrolü
CREATE OR REPLACE FUNCTION public.bp_check_level_up(p_player_id uuid, p_season_id uuid)
RETURNS void AS $$
DECLARE
  v_current_bpp integer;
  v_calculated_level integer;
BEGIN
  SELECT current_bpp FROM public.bp_player_status 
  WHERE player_id = p_player_id AND season_id = p_season_id INTO v_current_bpp;

  -- Her 1,000 puan 1 seviye (Maksimum Seviye 20)
  v_calculated_level := LEAST((v_current_bpp / 1000) + 1, 20);

  UPDATE public.bp_player_status
  SET current_level = v_calculated_level,
      updated_at = now()
  WHERE player_id = p_player_id AND season_id = p_season_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- B. Zindan Bitiş Tetikleyicisi
CREATE OR REPLACE FUNCTION public.bp_trigger_dungeon_clear(
  p_player_id uuid,
  p_zone_tier integer
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
  v_bpp_reward integer;
  v_current_pool integer;
BEGIN
  -- Aktif sezonu al
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  -- Zone tier'a göre sabit BPP belirle (5, 10, 15, 20)
  v_bpp_reward := LEAST(p_zone_tier * 5, 20);

  -- Günlük grind sınırını kontrol et (Max 300 BPP/gün)
  SELECT daily_grind_bpp_pool FROM public.bp_player_status 
  WHERE player_id = p_player_id AND season_id = v_active_season_id INTO v_current_pool;

  IF v_current_pool < 300 THEN
    -- Eğer eklenen ödül sınırı aşacaksa, sadece kalan kadarını ver
    IF (v_current_pool + v_bpp_reward) > 300 THEN
      v_bpp_reward := 300 - v_current_pool;
    END IF;

    -- Durumu güncelle
    UPDATE public.bp_player_status
    SET 
      current_bpp = current_bpp + v_bpp_reward,
      daily_grind_bpp_pool = daily_grind_bpp_pool + v_bpp_reward,
      updated_at = now()
    WHERE player_id = p_player_id AND season_id = v_active_season_id;
    
    PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);
  END IF;

  -- Zindan görev ilerlemesini güncelle
  UPDATE public.bp_player_quests q
  SET current_progress = current_progress + 1, updated_at = now()
  FROM public.bp_quest_templates t
  WHERE q.template_id = t.id 
    AND q.player_id = p_player_id 
    AND q.season_id = v_active_season_id
    AND t.target_system = 'dungeon' 
    AND q.is_completed = false;
    
  -- Görev tamamlanma kontrolü ve ödül verme
  WITH completed_quests AS (
    UPDATE public.bp_player_quests q
    SET is_completed = true
    FROM public.bp_quest_templates t
    WHERE q.template_id = t.id 
      AND q.current_progress >= t.target_count 
      AND q.is_completed = false
      AND q.player_id = p_player_id
      AND q.season_id = v_active_season_id
    RETURNING t.bpp_reward
  )
  UPDATE public.bp_player_status
  SET current_bpp = current_bpp + (SELECT COALESCE(SUM(bpp_reward), 0) FROM completed_quests),
      updated_at = now()
  WHERE player_id = p_player_id AND season_id = v_active_season_id;

  -- Seviye kontrolünü tekrarla (eğer görevden puan geldiyse)
  PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- D. PvP Galibiyet Tetikleyicisi (Daily Cap: 200 BPP)
CREATE OR REPLACE FUNCTION public.bp_trigger_pvp_win(
  p_player_id uuid
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
  v_status record;
  v_bpp_to_add integer := 20; -- Her PvP galibiyeti 20 BPP (Ayarlanabilir)
  v_daily_cap integer := 200;
  v_current_grind integer;
BEGIN
  -- Aktif sezonu al
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  -- Oyuncu durumunu al (yoksa oluştur)
  SELECT current_bpp, daily_grind_bpp_pool, updated_at 
  FROM public.bp_player_status 
  WHERE player_id = p_player_id AND season_id = v_active_season_id 
  FOR UPDATE INTO v_status;

  IF v_status IS NULL THEN
    INSERT INTO public.bp_player_status (player_id, season_id, current_bpp, daily_grind_bpp_pool)
    VALUES (p_player_id, v_active_season_id, 0, 0)
    RETURNING * INTO v_status;
  END IF;

  -- Günlük pool sıfırlama (Eğer son güncelleme dün ise)
  IF v_status.updated_at::date < now()::date THEN
    v_current_grind := 0;
  ELSE
    v_current_grind := v_status.daily_grind_bpp_pool;
  END IF;

  -- Cap kontrolü
  IF v_current_grind >= v_daily_cap THEN
    RETURN; -- Günlük limite ulaşıldı
  END IF;

  -- Eklenecek puanı sınırla
  IF (v_current_grind + v_bpp_to_add) > v_daily_cap THEN
    v_bpp_to_add := v_daily_cap - v_current_grind;
  END IF;

  -- Puan ekle ve quest ilerlet
  UPDATE public.bp_player_status
  SET current_bpp = current_bpp + v_bpp_to_add,
      daily_grind_bpp_pool = CASE WHEN updated_at::date < now()::date THEN v_bpp_to_add ELSE daily_grind_bpp_pool + v_bpp_to_add END,
      updated_at = now()
  WHERE player_id = p_player_id AND season_id = v_active_season_id;

  -- Quest sistemini tetikle
  PERFORM public.bp_trigger_quest_progress(p_player_id, 'pvp', 1);
  
  -- Seviye kontrolü
  PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- C. Ödül Talep Etme Fonksiyonu
CREATE OR REPLACE FUNCTION public.bp_claim_reward(
  p_level integer,
  p_is_vip boolean
)
RETURNS json AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_active_season_id uuid;
  v_status record;
  v_reward record;
  v_item_name text;
BEGIN
  -- Aktif sezonu al
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN
    RAISE EXCEPTION 'Aktif sezon bulunamadı.';
  END IF;

  -- Oyuncu durumunu kontrol et (yoksa oluştur)
  SELECT * FROM public.bp_player_status 
  WHERE player_id = v_player_id AND season_id = v_active_season_id INTO v_status;

  IF v_status IS NULL THEN
    INSERT INTO public.bp_player_status (player_id, season_id, current_bpp, current_level, daily_grind_bpp_pool, has_vip, claimed_normal, claimed_vip)
    VALUES (v_player_id, v_active_season_id, 0, 1, 0, false, '{}', '{}')
    RETURNING * INTO v_status;

    -- Görevleri de ata
    INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
    SELECT v_player_id, v_active_season_id, id FROM public.bp_quest_templates 
    WHERE quest_type = 'daily' 
    ORDER BY random() LIMIT 3
    ON CONFLICT DO NOTHING;
  END IF;

  -- Seviye kontrolü
  IF p_level > v_status.current_level THEN
    RAISE EXCEPTION 'Bu seviyeye henüz ulaşmadınız.';
  END IF;

  -- Daha önce talep edilmiş mi?
  IF p_is_vip THEN
    IF NOT v_status.has_vip THEN RAISE EXCEPTION 'VIP Pass sahibi değilsiniz.'; END IF;
    IF p_level = ANY(v_status.claimed_vip) THEN RAISE EXCEPTION 'Bu ödül zaten alındı.'; END IF;
  ELSE
    IF p_level = ANY(v_status.claimed_normal) THEN RAISE EXCEPTION 'Bu ödül zaten alındı.'; END IF;
  END IF;

  -- Ödül bilgilerini al
  SELECT * FROM public.bp_level_rewards WHERE level = p_level INTO v_reward;
  IF v_reward IS NULL THEN RAISE EXCEPTION 'Ödül tanımı bulunamadı.'; END IF;

  -- Ödülü ver (Gold ve Item)
  IF p_is_vip THEN
    -- VIP Ödülleri
    IF v_reward.vip_reward_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_reward.vip_reward_gold WHERE id = v_player_id;
    END IF;
    IF v_reward.vip_reward_item_id IS NOT NULL THEN
      -- Envanter ekleme mantığı (Basitçe inventory tablosuna ekleme veya bir helper function kullanımı)
      -- Burada projedeki mevcut inventory ekleme mantığınızı bilmediğim için direkt insert yapıyorum
      -- Varsayılan: public.inventory tablosuna ekle
      INSERT INTO public.inventory (user_id, item_id, quantity)
      VALUES (v_player_id, v_reward.vip_reward_item_id, v_reward.vip_reward_quantity)
      ON CONFLICT (user_id, item_id) WHERE slot_position IS NULL -- Eğer stackable ise quantity artır, değilse yeni slot?
      DO UPDATE SET quantity = inventory.quantity + v_reward.vip_reward_quantity;
    END IF;
    
    -- Claimed listesini güncelle
    UPDATE public.bp_player_status 
    SET claimed_vip = array_append(claimed_vip, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  ELSE
    -- Normal Ödülleri
    IF v_reward.normal_reward_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_reward.normal_reward_gold WHERE id = v_player_id;
    END IF;
    IF v_reward.normal_reward_item_id IS NOT NULL THEN
      INSERT INTO public.inventory (user_id, item_id, quantity)
      VALUES (v_player_id, v_reward.normal_reward_item_id, v_reward.normal_reward_quantity)
      ON CONFLICT (user_id, item_id) WHERE slot_position IS NULL
      DO UPDATE SET quantity = inventory.quantity + v_reward.normal_reward_quantity;
    END IF;

    -- Claimed listesini güncelle
    UPDATE public.bp_player_status 
    SET claimed_normal = array_append(claimed_normal, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  END IF;

  RETURN json_build_object('success', true, 'message', 'Ödül başarıyla alındı.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- D. Sezon Rotasyonu (Cron)
CREATE OR REPLACE FUNCTION public.cron_bp_season_rotation()
RETURNS void AS $$
DECLARE
  v_old_season_id uuid;
  v_new_season_num integer;
  v_new_season_id uuid;
BEGIN
  -- 1. Eski aktif sezonu bul ve kapat
  SELECT id, season_number FROM public.bp_seasons WHERE is_active = true INTO v_old_season_id, v_new_season_num;
  
  IF v_old_season_id IS NOT NULL THEN
    UPDATE public.bp_seasons SET is_active = false WHERE id = v_old_season_id;
  ELSE
    v_new_season_num := 0;
  END IF;

  -- 2. Yeni Sezonu Yarat (Tam 14 Gün Süreli)
  INSERT INTO public.bp_seasons (season_number, start_at, end_at, is_active)
  VALUES (COALESCE(v_new_season_num, 0) + 1, now(), now() + interval '14 days', true)
  RETURNING id INTO v_new_season_id;

  -- 3. Oyuncuların Tamamını Yeni Sezona Bağla ve Günlük Grind Pool'u Temizle
  INSERT INTO public.bp_player_status (player_id, season_id, current_bpp, current_level, daily_grind_bpp_pool, has_vip, claimed_normal, claimed_vip)
  SELECT id, v_new_season_id, 0, 1, 0, false, '{}', '{}' FROM public.users
  ON CONFLICT (player_id, season_id) DO NOTHING;

  -- 4. Aktif görevleri temizle ve yeni şablonlardan rastgele ata
  -- Burada eski görevleri silmiyoruz ama yeni sezona geçişte oyuncuya yeni görevler veriyoruz.
  INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
  SELECT u.id, v_new_season_id, t.id
  FROM public.users u
  CROSS JOIN LATERAL (
    SELECT id FROM public.bp_quest_templates 
    WHERE quest_type = 'daily' 
    ORDER BY random() LIMIT 3
  ) t;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
