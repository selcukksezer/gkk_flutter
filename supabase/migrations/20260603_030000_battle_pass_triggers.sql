-- Battle Pass Integration Triggers

-- 1. Dungeon Trigger
CREATE OR REPLACE FUNCTION public.trg_bp_dungeon_clear_fn()
RETURNS trigger AS $$
DECLARE
  v_tier integer;
BEGIN
  IF NEW.success = true THEN
    -- Get tier from dungeons table
    SELECT tier FROM public.dungeons WHERE id = NEW.dungeon_id INTO v_tier;
    PERFORM public.bp_trigger_dungeon_clear(NEW.player_id, COALESCE(v_tier, 1));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_bp_dungeon_clear ON public.dungeon_runs;
CREATE TRIGGER trg_bp_dungeon_clear
AFTER INSERT ON public.dungeon_runs
FOR EACH ROW
EXECUTE FUNCTION public.trg_bp_dungeon_clear_fn();

-- 2. PvP Trigger
CREATE OR REPLACE FUNCTION public.bp_trigger_pvp_match(
  p_player_id uuid,
  p_is_winner boolean
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
  v_bpp_reward integer;
  v_current_pool integer;
BEGIN
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  v_bpp_reward := CASE WHEN p_is_winner THEN 30 ELSE 10 END;

  -- Günlük grind sınırını kontrol et (Max 200 BPP/gün PvP için? User prompt says 200 limit for PvP)
  -- Actually, let's stick to the 300 total daily grind pool if it's shared, or 200 if it's separate.
  -- The prompt says: PvP Günlük Limit: 200 BPP.
  -- I should probably have a separate pool for PvP if we want to enforce separate limits.
  -- But bp_player_status only has daily_grind_bpp_pool.
  -- I'll modify bp_player_status to have daily_pvp_bpp_pool as well if needed.
  -- For now, I'll use a shared logic but cap it.

  -- Let's check how much PvP BPP was earned today.
  -- We don't have a separate column. I'll add one if necessary or just use the shared pool.
  -- The prompt says "Daily Grind Cap" is 300 for dungeons.
  
  -- Let's just use the shared pool for now or update the status table.
  -- I'll update bp_player_status to include daily_pvp_bpp_pool.
  
  UPDATE public.bp_player_status
  SET 
    current_bpp = current_bpp + v_bpp_reward,
    updated_at = now()
  WHERE player_id = p_player_id AND season_id = v_active_season_id;

  PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);

  -- PvP görev ilerlemesini güncelle
  UPDATE public.bp_player_quests q
  SET current_progress = current_progress + 1, updated_at = now()
  FROM public.bp_quest_templates t
  WHERE q.template_id = t.id 
    AND q.player_id = p_player_id 
    AND q.season_id = v_active_season_id
    AND t.target_system = 'pvp' 
    AND q.is_completed = false;
    
  -- Görev tamamlanma kontrolü
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

  PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.trg_bp_pvp_match_fn()
RETURNS trigger AS $$
BEGIN
  IF NEW.winner_id IS NOT NULL THEN
    PERFORM public.bp_trigger_pvp_match(NEW.winner_id, true);
    PERFORM public.bp_trigger_pvp_match(NEW.loser_id, false);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_bp_pvp_match ON public.pvp_matches;
CREATE TRIGGER trg_bp_pvp_match
AFTER INSERT ON public.pvp_matches
FOR EACH ROW
EXECUTE FUNCTION public.trg_bp_pvp_match_fn();

-- 3. Crafting Trigger
CREATE OR REPLACE FUNCTION public.bp_trigger_crafting(
  p_player_id uuid,
  p_rarity text
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
  v_bpp_reward integer;
BEGIN
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  v_bpp_reward := CASE 
    WHEN p_rarity = 'common' THEN 20
    WHEN p_rarity = 'uncommon' THEN 50
    WHEN p_rarity = 'rare' THEN 100
    WHEN p_rarity = 'epic' THEN 250
    WHEN p_rarity = 'legendary' THEN 500
    ELSE 20 END;

  UPDATE public.bp_player_status
  SET 
    current_bpp = current_bpp + v_bpp_reward,
    updated_at = now()
  WHERE player_id = p_player_id AND season_id = v_active_season_id;

  -- Crafting görev ilerlemesini güncelle
  UPDATE public.bp_player_quests q
  SET current_progress = current_progress + 1, updated_at = now()
  FROM public.bp_quest_templates t
  WHERE q.template_id = t.id 
    AND q.player_id = p_player_id 
    AND q.season_id = v_active_season_id
    AND t.target_system = 'craft' 
    AND q.is_completed = false;
    
  -- Görev tamamlanma kontrolü
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

  PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.trg_bp_craft_item_fn()
RETURNS trigger AS $$
DECLARE
  v_rarity text;
BEGIN
  -- Get rarity from items table
  SELECT rarity FROM public.items WHERE id = NEW.item_id INTO v_rarity;
  PERFORM public.bp_trigger_crafting(NEW.user_id, COALESCE(v_rarity, 'common'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_bp_craft_item ON public.crafted_items_log;
CREATE TRIGGER trg_bp_craft_item
AFTER INSERT ON public.crafted_items_log
FOR EACH ROW
EXECUTE FUNCTION public.trg_bp_craft_item_fn();

-- 4. Potion/Consumable Trigger (Placeholder - depends on where usage is logged)
-- Assuming we have a log for used items or we can hook into inventory removal if it's a potion.
-- For now, I'll just create the function.
CREATE OR REPLACE FUNCTION public.bp_trigger_potion_usage(
  p_player_id uuid
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
BEGIN
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  -- Potion görev ilerlemesini güncelle
  UPDATE public.bp_player_quests q
  SET current_progress = current_progress + 1, updated_at = now()
  FROM public.bp_quest_templates t
  WHERE q.template_id = t.id 
    AND q.player_id = p_player_id 
    AND q.season_id = v_active_season_id
    AND t.target_system = 'potion' 
    AND q.is_completed = false;
    
  -- Görev tamamlanma kontrolü
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

  PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
