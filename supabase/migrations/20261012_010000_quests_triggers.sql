-- =========================================================================================
-- MIGRATION: Quest Progression Triggers
-- =========================================================================================
-- Wire up the game events to automatically progress the quests.

-- 1. Gold Earned Trigger
CREATE OR REPLACE FUNCTION public.trg_users_quest_gold_fn()
RETURNS trigger AS $$
BEGIN
  IF NEW.gold > OLD.gold THEN
    PERFORM public.increment_quest_progress(NEW.auth_id, 'earn_gold', (NEW.gold - OLD.gold)::integer);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_users_quest_gold ON public.users;
CREATE TRIGGER trg_users_quest_gold
AFTER UPDATE OF gold ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.trg_users_quest_gold_fn();


-- 2. Dungeon Complete Trigger
CREATE OR REPLACE FUNCTION public.trg_dungeon_runs_quest_fn()
RETURNS trigger AS $$
BEGIN
  IF NEW.success = true THEN
    -- Progress normal dungeon quest
    PERFORM public.increment_quest_progress(NEW.player_id, 'dungeon_complete', 1);
    
    -- Check if it was a boss dungeon for elite quests
    IF (SELECT is_boss FROM public.dungeons WHERE id = NEW.dungeon_id) THEN
      PERFORM public.increment_quest_progress(NEW.player_id, 'dungeon_elite_complete', 1);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_dungeon_runs_quest ON public.dungeon_runs;
CREATE TRIGGER trg_dungeon_runs_quest
AFTER INSERT ON public.dungeon_runs
FOR EACH ROW
EXECUTE FUNCTION public.trg_dungeon_runs_quest_fn();


-- 3. PvP Win Trigger
CREATE OR REPLACE FUNCTION public.trg_pvp_matches_quest_fn()
RETURNS trigger AS $$
BEGIN
  IF NEW.winner_id IS NOT NULL THEN
    PERFORM public.increment_quest_progress(NEW.winner_id, 'pvp_win', 1);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_pvp_matches_quest ON public.pvp_matches;
CREATE TRIGGER trg_pvp_matches_quest
AFTER INSERT ON public.pvp_matches
FOR EACH ROW
EXECUTE FUNCTION public.trg_pvp_matches_quest_fn();


-- 4. Craft Item Trigger
CREATE OR REPLACE FUNCTION public.trg_crafted_items_quest_fn()
RETURNS trigger AS $$
BEGIN
  PERFORM public.increment_quest_progress(NEW.user_id, 'craft_item', NEW.quantity);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_crafted_items_quest ON public.crafted_items_log;
CREATE TRIGGER trg_crafted_items_quest
AFTER INSERT ON public.crafted_items_log
FOR EACH ROW
EXECUTE FUNCTION public.trg_crafted_items_quest_fn();


-- 5. Complete Any Quest Trigger (For the "First Step" quest)
CREATE OR REPLACE FUNCTION public.trg_player_quests_complete_fn()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    PERFORM public.increment_quest_progress(NEW.user_id, 'complete_any_quest', 1);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_player_quests_complete ON public.player_quests;
CREATE TRIGGER trg_player_quests_complete
AFTER UPDATE OF status ON public.player_quests
FOR EACH ROW
EXECUTE FUNCTION public.trg_player_quests_complete_fn();
