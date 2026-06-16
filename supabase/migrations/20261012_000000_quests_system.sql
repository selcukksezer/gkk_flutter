-- =========================================================================================
-- MIGRATION: Rewrite Achievements into Missions (Quests)
-- =========================================================================================

-- 1. Create Quests Table
CREATE TABLE IF NOT EXISTS public.quests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quest_id text UNIQUE NOT NULL,
  name text NOT NULL,
  description text NOT NULL,
  difficulty text NOT NULL DEFAULT 'medium',
  required_level integer NOT NULL DEFAULT 1,
  energy_cost integer NOT NULL DEFAULT 0,
  gold_reward integer NOT NULL DEFAULT 0,
  xp_reward integer NOT NULL DEFAULT 0,
  gem_reward integer NOT NULL DEFAULT 0,
  item_rewards jsonb NOT NULL DEFAULT '[]'::jsonb,
  target integer NOT NULL DEFAULT 1,
  quest_type text NOT NULL DEFAULT 'main', -- 'main', 'daily', 'weekly'
  trigger_event text, -- e.g. 'pvp_win', 'dungeon_complete'
  created_at timestamp with time zone DEFAULT now()
);

-- 2. Create Player Quests Table
CREATE TABLE IF NOT EXISTS public.player_quests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quest_id text NOT NULL REFERENCES public.quests(quest_id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active', -- 'active', 'completed', 'failed', 'claimed'
  progress integer NOT NULL DEFAULT 0,
  progress_max integer NOT NULL DEFAULT 1,
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  completed_at timestamp with time zone,
  UNIQUE(user_id, quest_id)
);

-- Enable RLS
ALTER TABLE public.quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_quests ENABLE ROW LEVEL SECURITY;

-- Policies for quests
CREATE POLICY "quests_select_all" ON public.quests FOR SELECT USING (true);

-- Policies for player_quests
CREATE POLICY "player_quests_select_own" ON public.player_quests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "player_quests_update_own" ON public.player_quests FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "player_quests_delete_own" ON public.player_quests FOR DELETE USING (auth.uid() = user_id);

-- 3. Initial Quests Data (Replacing old Achievements)
INSERT INTO public.quests (quest_id, name, description, difficulty, required_level, energy_cost, gold_reward, xp_reward, gem_reward, target, quest_type, trigger_event) VALUES
('q_first_step', 'İlk Adım', 'İlk görevini tamamla.', 'easy', 1, 5, 100, 50, 0, 1, 'main', 'complete_any_quest'),
('q_dungeon_runner', 'Zindan Kralı', '5 zindan tamamla.', 'dungeon', 2, 10, 500, 200, 10, 5, 'daily', 'dungeon_complete'),
('q_pvp_fighter', 'PvP Savaşçısı', '3 PvP maçı kazan.', 'hard', 3, 10, 300, 150, 5, 3, 'daily', 'pvp_win'),
('q_craft_master', 'Usta Zanaatkar', '1 eşya üret.', 'medium', 2, 5, 200, 100, 0, 1, 'daily', 'craft_item'),
('q_treasure_hunter', 'Hazine Avcısı', '5000 altın topla.', 'medium', 1, 0, 0, 500, 20, 5000, 'main', 'earn_gold'),
('q_elite_slayer', 'Elit Avcısı', '1 Elite zindan tamamla.', 'elite', 5, 20, 1000, 500, 50, 1, 'weekly', 'dungeon_elite_complete')
ON CONFLICT (quest_id) DO NOTHING;

-- 4. RPCs

-- Get Available Quests
CREATE OR REPLACE FUNCTION public.get_available_quests(p_player_level integer)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result json;
BEGIN
  -- We return quests that the player meets the level for, AND whose status is not 'claimed'
  -- If it's not in player_quests, we treat it as 'available'
  SELECT json_agg(
    json_build_object(
      'id', q.id,
      'quest_id', q.quest_id,
      'name', q.name,
      'description', q.description,
      'difficulty', q.difficulty,
      'required_level', q.required_level,
      'energy_cost', q.energy_cost,
      'gold_reward', q.gold_reward,
      'xp_reward', q.xp_reward,
      'gem_reward', q.gem_reward,
      'item_rewards', q.item_rewards,
      'target', q.target,
      'status', COALESCE(pq.status, 'available'),
      'progress', COALESCE(pq.progress, 0),
      'progress_max', q.target,
      'expires_at', pq.expires_at
    )
  ) INTO v_result
  FROM public.quests q
  LEFT JOIN public.player_quests pq ON pq.quest_id = q.quest_id AND pq.user_id = v_user_id
  WHERE q.required_level <= p_player_level
    AND COALESCE(pq.status, 'available') != 'claimed';

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- Start Quest
CREATE OR REPLACE FUNCTION public.start_quest(p_quest_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_energy_cost integer;
  v_current_energy integer;
  v_target integer;
BEGIN
  -- Get quest details
  SELECT energy_cost, target INTO v_energy_cost, v_target
  FROM public.quests WHERE quest_id = p_quest_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev bulunamadı.';
  END IF;

  -- Check energy
  SELECT energy INTO v_current_energy
  FROM public.users WHERE auth_id = v_user_id;

  IF v_current_energy < v_energy_cost THEN
    RAISE EXCEPTION 'Yetersiz enerji.';
  END IF;

  -- Deduct energy
  IF v_energy_cost > 0 THEN
    UPDATE public.users SET energy = energy - v_energy_cost WHERE auth_id = v_user_id;
  END IF;

  -- Insert or update player_quests
  INSERT INTO public.player_quests (user_id, quest_id, status, progress, progress_max)
  VALUES (v_user_id, p_quest_id, 'active', 0, v_target)
  ON CONFLICT (user_id, quest_id) DO UPDATE
  SET status = 'active', progress = 0, progress_max = v_target;
END;
$$;

-- Complete Quest
CREATE OR REPLACE FUNCTION public.complete_quest(p_quest_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_status text;
  v_progress integer;
  v_progress_max integer;
BEGIN
  SELECT status, progress, progress_max INTO v_status, v_progress, v_progress_max
  FROM public.player_quests
  WHERE user_id = v_user_id AND quest_id = p_quest_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev kaydı bulunamadı.';
  END IF;

  IF v_status != 'active' THEN
    RAISE EXCEPTION 'Görev aktif değil.';
  END IF;

  IF v_progress < v_progress_max THEN
    RAISE EXCEPTION 'Görev hedefine henüz ulaşılmadı.';
  END IF;

  UPDATE public.player_quests
  SET status = 'completed', completed_at = now()
  WHERE user_id = v_user_id AND quest_id = p_quest_id;
END;
$$;

-- Claim Quest Reward
CREATE OR REPLACE FUNCTION public.claim_quest_reward(p_quest_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_status text;
  v_gold integer;
  v_xp integer;
  v_gem integer;
BEGIN
  SELECT status INTO v_status
  FROM public.player_quests
  WHERE user_id = v_user_id AND quest_id = p_quest_id;

  IF NOT FOUND OR v_status != 'completed' THEN
    RAISE EXCEPTION 'Ödül alınabilir durumda değil.';
  END IF;

  -- Get rewards
  SELECT gold_reward, xp_reward, gem_reward INTO v_gold, v_xp, v_gem
  FROM public.quests WHERE quest_id = p_quest_id;

  -- Grant rewards
  UPDATE public.users
  SET gold = gold + v_gold, xp = xp + v_xp, gems = gems + v_gem
  WHERE auth_id = v_user_id;

  -- Set status to claimed so it disappears from UI
  UPDATE public.player_quests
  SET status = 'claimed'
  WHERE user_id = v_user_id AND quest_id = p_quest_id;
END;
$$;

-- Abandon Quest
CREATE OR REPLACE FUNCTION public.abandon_quest(p_quest_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  -- We just delete it so it becomes available again
  DELETE FROM public.player_quests
  WHERE user_id = v_user_id AND quest_id = p_quest_id AND status = 'active';
END;
$$;

-- Increment Quest Progress (Helper for DB Triggers or Server Logic)
CREATE OR REPLACE FUNCTION public.increment_quest_progress(p_user_id uuid, p_trigger_event text, p_amount integer DEFAULT 1)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.player_quests pq
  SET progress = LEAST(pq.progress + p_amount, pq.progress_max)
  FROM public.quests q
  WHERE pq.quest_id = q.quest_id
    AND pq.user_id = p_user_id
    AND pq.status = 'active'
    AND q.trigger_event = p_trigger_event;
END;
$$;
