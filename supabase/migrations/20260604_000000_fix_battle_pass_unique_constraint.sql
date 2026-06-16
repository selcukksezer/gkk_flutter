-- Comprehensive Fix for Battle Pass (Season) System
-- Resolves: 
-- 1. Error 42P10 (Missing unique constraint for inventory upsert)
-- 2. Missing bp_trigger_quest_progress function
-- 3. Robust daily pool reset logic
-- 4. Correct season numbering and rotation

-- ====================================================================
-- 1. INVENTORY UNIQUE INDEX
-- ====================================================================
-- This index is required for the ON CONFLICT clause in bp_claim_reward
CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory_user_item_unslotted_unique 
ON public.inventory (user_id, item_id) 
WHERE (slot_position IS NULL);

-- ====================================================================
-- 2. PLAYER STATUS IMPROVEMENTS
-- ====================================================================
-- Add PvP specific daily cap tracking
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bp_player_status' AND column_name='daily_pvp_bpp_pool') THEN
    ALTER TABLE public.bp_player_status ADD COLUMN daily_pvp_bpp_pool integer DEFAULT 0;
    -- Add check constraint for PvP limit (200 BPP)
    ALTER TABLE public.bp_player_status ADD CONSTRAINT daily_pvp_bpp_pool_check CHECK (daily_pvp_bpp_pool <= 300);
  END IF;
END $$;

-- ====================================================================
-- 3. CORE UTILITY: bp_trigger_quest_progress
-- ====================================================================
-- Unified function to handle quest progress across different systems
CREATE OR REPLACE FUNCTION public.bp_trigger_quest_progress(
  p_player_id uuid,
  p_target_system text,
  p_progress_amount integer DEFAULT 1
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
BEGIN
  -- Get active season
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  -- Update progress for active quests of the matching system
  UPDATE public.bp_player_quests q
  SET current_progress = current_progress + p_progress_amount, 
      updated_at = now()
  FROM public.bp_quest_templates t
  WHERE q.template_id = t.id 
    AND q.player_id = p_player_id 
    AND q.season_id = v_active_season_id
    AND t.target_system = p_target_system 
    AND q.is_completed = false;
    
  -- Check for completion and award BPP reward
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

  -- Refresh level if BPP was added
  PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================================================
-- 4. REFACTORED DUNGEON TRIGGER
-- ====================================================================
CREATE OR REPLACE FUNCTION public.bp_trigger_dungeon_clear(
  p_player_id uuid,
  p_zone_tier integer
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
  v_bpp_reward integer;
BEGIN
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  -- Points based on tier (5, 10, 15, 20)
  v_bpp_reward := LEAST(p_zone_tier * 5, 20);

  -- Handle daily reset and point addition in one robust update
  UPDATE public.bp_player_status
  SET 
    daily_grind_bpp_pool = CASE WHEN updated_at::date < now()::date THEN 0 ELSE daily_grind_bpp_pool END,
    daily_pvp_bpp_pool = CASE WHEN updated_at::date < now()::date THEN 0 ELSE daily_pvp_bpp_pool END
  WHERE player_id = p_player_id AND season_id = v_active_season_id;

  -- Attempt to add reward if under 300 limit
  UPDATE public.bp_player_status
  SET 
    current_bpp = current_bpp + LEAST(v_bpp_reward, GREATEST(300 - daily_grind_bpp_pool, 0)),
    daily_grind_bpp_pool = daily_grind_bpp_pool + LEAST(v_bpp_reward, GREATEST(300 - daily_grind_bpp_pool, 0)),
    updated_at = now()
  WHERE player_id = p_player_id AND season_id = v_active_season_id
    AND daily_grind_bpp_pool < 300;

  -- Always trigger quest progress
  PERFORM public.bp_trigger_quest_progress(p_player_id, 'dungeon', 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================================================
-- 5. REFACTORED PVP TRIGGER
-- ====================================================================
CREATE OR REPLACE FUNCTION public.bp_trigger_pvp_match(
  p_player_id uuid,
  p_is_winner boolean
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
  v_bpp_reward integer;
BEGIN
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  v_bpp_reward := CASE WHEN p_is_winner THEN 30 ELSE 10 END;

  -- Handle daily reset
  UPDATE public.bp_player_status
  SET 
    daily_grind_bpp_pool = CASE WHEN updated_at::date < now()::date THEN 0 ELSE daily_grind_bpp_pool END,
    daily_pvp_bpp_pool = CASE WHEN updated_at::date < now()::date THEN 0 ELSE daily_pvp_bpp_pool END
  WHERE player_id = p_player_id AND season_id = v_active_season_id;

  -- Attempt to add reward if under 200 PvP limit
  UPDATE public.bp_player_status
  SET 
    current_bpp = current_bpp + LEAST(v_bpp_reward, GREATEST(200 - daily_pvp_bpp_pool, 0)),
    daily_pvp_bpp_pool = daily_pvp_bpp_pool + LEAST(v_bpp_reward, GREATEST(200 - daily_pvp_bpp_pool, 0)),
    updated_at = now()
  WHERE player_id = p_player_id AND season_id = v_active_season_id
    AND daily_pvp_bpp_pool < 200;

  -- Always trigger quest progress
  PERFORM public.bp_trigger_quest_progress(p_player_id, 'pvp', 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================================================
-- 6. REFACTORED PVP WIN TRIGGER (From system file)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.bp_trigger_pvp_win(p_player_id uuid)
RETURNS void AS $$
BEGIN
  -- Simply call the match trigger with winner=true
  PERFORM public.bp_trigger_pvp_match(p_player_id, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================================================
-- 7. SEASON ROTATION (Cron)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.cron_bp_season_rotation()
RETURNS void AS $$
DECLARE
  v_max_season_num integer;
  v_new_season_id uuid;
BEGIN
  -- 1. Close all active seasons
  UPDATE public.bp_seasons SET is_active = false WHERE is_active = true;

  -- 2. Find next season number
  SELECT COALESCE(MAX(season_number), 0) FROM public.bp_seasons INTO v_max_season_num;

  -- 3. Create New Season (14 days)
  INSERT INTO public.bp_seasons (season_number, start_at, end_at, is_active)
  VALUES (v_max_season_num + 1, now(), now() + interval '14 days', true)
  RETURNING id INTO v_new_season_id;

  -- 4. Fast status initialization for all players
  INSERT INTO public.bp_player_status (player_id, season_id, current_bpp, current_level, daily_grind_bpp_pool, daily_pvp_bpp_pool, updated_at)
  SELECT id, v_new_season_id, 0, 1, 0, 0, now() FROM public.users
  ON CONFLICT DO NOTHING;

  -- 5. Assign daily quests
  INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
  SELECT u.id, v_new_season_id, t.id
  FROM public.users u
  CROSS JOIN LATERAL (
    SELECT id FROM public.bp_quest_templates 
    WHERE quest_type = 'daily' 
    ORDER BY random() LIMIT 3
  ) t
  ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ====================================================================
-- 8. CONSTRAINTS & CLEANUP
-- ====================================================================
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bp_player_quests_unique') THEN
    ALTER TABLE public.bp_player_quests ADD CONSTRAINT bp_player_quests_unique UNIQUE (player_id, season_id, template_id);
  END IF;
END $$;

-- 8. REFACTORED POTION TRIGGER
CREATE OR REPLACE FUNCTION public.bp_trigger_potion_usage(
  p_player_id uuid
)
RETURNS void AS $$
BEGIN
  PERFORM public.bp_trigger_quest_progress(p_player_id, 'potion', 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Integration with use_potion
-- We recreate use_potion with the BP trigger call
CREATE OR REPLACE FUNCTION public.use_potion(p_user_id UUID, p_row_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_inv RECORD;
  v_item RECORD;
  v_user RECORD;
  v_monument_level INT := 0;
  v_new_tolerance INT;
  v_efficiency NUMERIC;
  v_overdose_chance NUMERIC;
  v_roll NUMERIC;
  v_overdose BOOLEAN := false;
  v_hospital_minutes INT;
  v_saved_from_overdose BOOLEAN := false;
BEGIN
  IF p_user_id != auth.uid() THEN
    RETURN jsonb_build_object('error', 'Yetkisiz işlem');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE auth_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'Kullanıcı bulunamadı'); END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level FROM public.guilds WHERE id = v_user.guild_id;
  END IF;

  SELECT * INTO v_inv FROM public.inventory WHERE row_id = p_row_id AND user_id = p_user_id AND quantity > 0 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'Eşya bulunamadı veya miktar yetersiz'); END IF;

  SELECT * INTO v_item FROM public.items WHERE id = v_inv.item_id;
  IF NOT FOUND OR v_item.type != 'potion' THEN RETURN jsonb_build_object('error', 'Geçersiz iksir'); END IF;

  -- BATTLE PASS TRIGGER
  PERFORM public.bp_trigger_potion_usage(p_user_id);

  UPDATE public.inventory SET quantity = quantity - 1 WHERE row_id = p_row_id AND quantity > 0;
  DELETE FROM public.inventory WHERE quantity <= 0 AND row_id = p_row_id;

  -- Add your recovery logic here (Health, Energy, etc.)
  IF v_item.potion_type = 'health' THEN
    UPDATE public.users SET health = LEAST(max_health, health + COALESCE(v_item.heal_amount, 50)) WHERE auth_id = p_user_id;
  ELSIF v_item.potion_type = 'energy' THEN
    UPDATE public.users SET energy = LEAST(100, energy + COALESCE(v_item.heal_amount, 30)) WHERE auth_id = p_user_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'message', 'İksir kullanıldı');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. FIXED CLAIM REWARD FUNCTION
-- Corrects the user identification (auth_id vs id) and uses the unique inventory index
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
BEGIN
  -- Aktif sezonu al
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Aktif sezon bulunamadı.');
  END IF;

  -- Oyuncu durumunu kontrol et
  SELECT * FROM public.bp_player_status 
  WHERE player_id = v_player_id AND season_id = v_active_season_id INTO v_status;

  IF v_status IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Sezon katılımı bulunamadı.');
  END IF;

  -- Seviye kontrolü
  IF p_level > v_status.current_level THEN
    RETURN json_build_object('success', false, 'error', 'Bu seviyeye henüz ulaşmadınız.');
  END IF;

  -- Daha önce talep edilmiş mi?
  IF p_is_vip THEN
    IF NOT v_status.has_vip THEN 
      RETURN json_build_object('success', false, 'error', 'VIP Pass sahibi değilsiniz.'); 
    END IF;
    IF p_level = ANY(v_status.claimed_vip) THEN 
      RETURN json_build_object('success', false, 'error', 'Bu ödül zaten alındı.'); 
    END IF;
  ELSE
    IF p_level = ANY(v_status.claimed_normal) THEN 
      RETURN json_build_object('success', false, 'error', 'Bu ödül zaten alındı.'); 
    END IF;
  END IF;

  -- Ödül bilgilerini al
  SELECT * FROM public.bp_level_rewards WHERE level = p_level INTO v_reward;
  IF v_reward IS NULL THEN 
    RETURN json_build_object('success', false, 'error', 'Ödül tanımı bulunamadı.'); 
  END IF;

  -- Ödülü ver (Gold ve Item)
  IF p_is_vip THEN
    -- VIP Gold
    IF v_reward.vip_reward_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_reward.vip_reward_gold WHERE auth_id = v_player_id;
    END IF;
    -- VIP Item
    IF v_reward.vip_reward_item_id IS NOT NULL THEN
      INSERT INTO public.inventory (user_id, item_id, quantity)
      VALUES (v_player_id, v_reward.vip_reward_item_id, v_reward.vip_reward_quantity)
      ON CONFLICT (user_id, item_id) WHERE slot_position IS NULL
      DO UPDATE SET quantity = inventory.quantity + v_reward.vip_reward_quantity, updated_at = now();
    END IF;
    
    -- Claimed listesini güncelle
    UPDATE public.bp_player_status 
    SET claimed_vip = array_append(claimed_vip, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  ELSE
    -- Normal Gold
    IF v_reward.normal_reward_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_reward.normal_reward_gold WHERE auth_id = v_player_id;
    END IF;
    -- Normal Item
    IF v_reward.normal_reward_item_id IS NOT NULL THEN
      INSERT INTO public.inventory (user_id, item_id, quantity)
      VALUES (v_player_id, v_reward.normal_reward_item_id, v_reward.normal_reward_quantity)
      ON CONFLICT (user_id, item_id) WHERE slot_position IS NULL
      DO UPDATE SET quantity = inventory.quantity + v_reward.normal_reward_quantity, updated_at = now();
    END IF;

    -- Claimed listesini güncelle
    UPDATE public.bp_player_status 
    SET claimed_normal = array_append(claimed_normal, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  END IF;

  RETURN json_build_object('success', true, 'message', 'Ödül başarıyla alındı.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. REFACTORED DUNGEON TRIGGER FUNCTION (Fixing column "tier" error)
-- We use "zone" instead of "tier" as the dungeons table uses "zone"
CREATE OR REPLACE FUNCTION public.trg_bp_dungeon_clear_fn()
RETURNS trigger AS $$
DECLARE
  v_zone integer;
BEGIN
  IF NEW.success = true THEN
    -- Get zone from dungeons table
    SELECT zone FROM public.dungeons WHERE id = NEW.dungeon_id INTO v_zone;
    PERFORM public.bp_trigger_dungeon_clear(NEW.player_id, COALESCE(v_zone, 1));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-apply trigger to ensure it uses the updated function
DROP TRIGGER IF EXISTS trg_bp_dungeon_clear ON public.dungeon_runs;
CREATE TRIGGER trg_bp_dungeon_clear
AFTER INSERT ON public.dungeon_runs
FOR EACH ROW
EXECUTE FUNCTION public.trg_bp_dungeon_clear_fn();
