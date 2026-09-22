-- Battle Pass season quest pacing
-- Problem: tiny pool (3 daily + 4 weekly), no daily refresh, weekly 3000 BPP
--         → 1 weekly claim unlocks 3 levels (1000 BPP/level).
-- Fix: denser pool, daily/weekly refresh, lower quest BPP, craft no longer
--      auto-grants quest BPP (claim path only).

BEGIN;

-- ── 1. Refresh tracking on player season status ─────────────────────────────
ALTER TABLE public.bp_player_status
  ADD COLUMN IF NOT EXISTS daily_quests_date date,
  ADD COLUMN IF NOT EXISTS weekly_quests_week date;

-- ── 2. Dedupe templates (live DB has duplicate rows per type/system/count) ───
WITH keepers AS (
  SELECT DISTINCT ON (quest_type, target_system, target_count)
         id AS keep_id, quest_type, target_system, target_count
  FROM public.bp_quest_templates
  ORDER BY quest_type, target_system, target_count, created_at NULLS LAST, id
),
dupes AS (
  SELECT t.id AS dupe_id, k.keep_id
  FROM public.bp_quest_templates t
  JOIN keepers k
    ON k.quest_type = t.quest_type
   AND k.target_system = t.target_system
   AND k.target_count = t.target_count
  WHERE t.id <> k.keep_id
)
DELETE FROM public.bp_player_quests pq
USING dupes d
WHERE pq.template_id = d.dupe_id
  AND EXISTS (
    SELECT 1
    FROM public.bp_player_quests x
    WHERE x.player_id = pq.player_id
      AND x.season_id = pq.season_id
      AND x.template_id = d.keep_id
  );

WITH keepers AS (
  SELECT DISTINCT ON (quest_type, target_system, target_count)
         id AS keep_id, quest_type, target_system, target_count
  FROM public.bp_quest_templates
  ORDER BY quest_type, target_system, target_count, created_at NULLS LAST, id
),
dupes AS (
  SELECT t.id AS dupe_id, k.keep_id
  FROM public.bp_quest_templates t
  JOIN keepers k
    ON k.quest_type = t.quest_type
   AND k.target_system = t.target_system
   AND k.target_count = t.target_count
  WHERE t.id <> k.keep_id
)
UPDATE public.bp_player_quests pq
SET template_id = d.keep_id
FROM dupes d
WHERE pq.template_id = d.dupe_id;

WITH keepers AS (
  SELECT DISTINCT ON (quest_type, target_system, target_count)
         id AS keep_id, quest_type, target_system, target_count
  FROM public.bp_quest_templates
  ORDER BY quest_type, target_system, target_count, created_at NULLS LAST, id
),
dupes AS (
  SELECT t.id AS dupe_id
  FROM public.bp_quest_templates t
  JOIN keepers k
    ON k.quest_type = t.quest_type
   AND k.target_system = t.target_system
   AND k.target_count = t.target_count
  WHERE t.id <> k.keep_id
)
DELETE FROM public.bp_quest_templates t
USING dupes d
WHERE t.id = d.dupe_id;

-- ── 3. Lower existing template BPP (claim reads template live) ──────────────
UPDATE public.bp_quest_templates
SET bpp_reward = 200
WHERE quest_type = 'daily' AND bpp_reward > 200;

UPDATE public.bp_quest_templates
SET bpp_reward = 600
WHERE quest_type = 'weekly' AND bpp_reward > 600;

-- ── 4. Expand quest pool (idempotent on type+system+count) ──────────────────
INSERT INTO public.bp_quest_templates (quest_type, target_system, target_count, bpp_reward, description)
SELECT v.quest_type, v.target_system, v.target_count, v.bpp_reward, v.description
FROM (VALUES
  -- daily (new variants; existing 3/2/5 stay after UPDATE above)
  ('daily', 'dungeon', 1, 150, '1 zindan temizle'),
  ('daily', 'dungeon', 5, 250, '5 zindan temizle'),
  ('daily', 'pvp', 1, 150, '1 PvP maçı tamamla'),
  ('daily', 'pvp', 4, 250, '4 PvP maçı tamamla'),
  ('daily', 'craft', 3, 150, '3 eşya üret'),
  ('daily', 'craft', 10, 250, '10 eşya üret'),
  ('daily', 'potion', 5, 150, '5 iksir kullan'),
  ('daily', 'potion', 15, 250, '15 iksir kullan'),
  -- weekly variants
  ('weekly', 'dungeon', 10, 500, 'Haftalık: 10 zindan temizle'),
  ('weekly', 'dungeon', 30, 700, 'Haftalık: 30 zindan temizle'),
  ('weekly', 'pvp', 8, 500, 'Haftalık: 8 PvP maçı tamamla'),
  ('weekly', 'pvp', 25, 700, 'Haftalık: 25 PvP maçı tamamla'),
  ('weekly', 'craft', 25, 500, 'Haftalık: 25 eşya üret'),
  ('weekly', 'potion', 40, 500, 'Haftalık: 40 iksir kullan')
) AS v(quest_type, target_system, target_count, bpp_reward, description)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.bp_quest_templates t
  WHERE t.quest_type = v.quest_type
    AND t.target_system = v.target_system
    AND t.target_count = v.target_count
);

-- Tier BPP by difficulty (overrides step 3 defaults for consistency)
UPDATE public.bp_quest_templates
SET bpp_reward = CASE
  WHEN quest_type = 'daily' AND target_count <= 2 THEN 150
  WHEN quest_type = 'daily' AND target_count <= 5 THEN 200
  WHEN quest_type = 'daily' THEN 250
  WHEN quest_type = 'weekly' AND target_count <= 15 THEN 500
  WHEN quest_type = 'weekly' AND target_count <= 30 THEN 600
  ELSE 700
END
WHERE quest_type IN ('daily', 'weekly');

-- ── 5. Helper: assign / refresh quest slots for one player ──────────────────
CREATE OR REPLACE FUNCTION public.bp_refresh_player_quests(
  p_player_id uuid,
  p_season_id uuid,
  p_force_daily boolean DEFAULT false,
  p_force_weekly boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status public.bp_player_status%ROWTYPE;
  v_today date := (timezone('utc', now()))::date;
  v_week date := date_trunc('week', timezone('utc', now()))::date;
  v_daily_slots integer := 5;
  v_weekly_slots integer := 4;
  v_kept integer;
  v_need integer;
BEGIN
  SELECT * INTO v_status
  FROM public.bp_player_status
  WHERE player_id = p_player_id AND season_id = p_season_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Daily refresh / top-up
  IF p_force_daily
     OR v_status.daily_quests_date IS NULL
     OR v_status.daily_quests_date < v_today THEN
    IF v_status.daily_quests_date IS NOT NULL AND v_status.daily_quests_date < v_today THEN
      -- Day rolled: drop claimed + incomplete; keep claimable completed
      DELETE FROM public.bp_player_quests q
      USING public.bp_quest_templates t
      WHERE q.template_id = t.id
        AND q.player_id = p_player_id
        AND q.season_id = p_season_id
        AND t.quest_type = 'daily'
        AND (q.reward_claimed = true OR q.is_completed = false);
    END IF;

    SELECT COUNT(*) INTO v_kept
    FROM public.bp_player_quests q
    JOIN public.bp_quest_templates t ON t.id = q.template_id
    WHERE q.player_id = p_player_id
      AND q.season_id = p_season_id
      AND t.quest_type = 'daily'
      AND q.reward_claimed = false;

    v_need := GREATEST(v_daily_slots - v_kept, 0);

    IF v_need > 0 THEN
      INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
      SELECT p_player_id, p_season_id, t.id
      FROM (
        SELECT id
        FROM public.bp_quest_templates
        WHERE quest_type = 'daily'
          AND id NOT IN (
            SELECT q.template_id
            FROM public.bp_player_quests q
            WHERE q.player_id = p_player_id
              AND q.season_id = p_season_id
          )
        ORDER BY random()
        LIMIT v_need
      ) t
      ON CONFLICT (player_id, season_id, template_id) DO NOTHING;
    END IF;

    UPDATE public.bp_player_status
    SET daily_quests_date = v_today,
        updated_at = now()
    WHERE player_id = p_player_id AND season_id = p_season_id;
  END IF;

  -- Weekly refresh / top-up
  IF p_force_weekly
     OR v_status.weekly_quests_week IS NULL
     OR v_status.weekly_quests_week < v_week THEN
    IF v_status.weekly_quests_week IS NOT NULL AND v_status.weekly_quests_week < v_week THEN
      DELETE FROM public.bp_player_quests q
      USING public.bp_quest_templates t
      WHERE q.template_id = t.id
        AND q.player_id = p_player_id
        AND q.season_id = p_season_id
        AND t.quest_type = 'weekly'
        AND (q.reward_claimed = true OR q.is_completed = false);
    END IF;

    SELECT COUNT(*) INTO v_kept
    FROM public.bp_player_quests q
    JOIN public.bp_quest_templates t ON t.id = q.template_id
    WHERE q.player_id = p_player_id
      AND q.season_id = p_season_id
      AND t.quest_type = 'weekly'
      AND q.reward_claimed = false;

    v_need := GREATEST(v_weekly_slots - v_kept, 0);

    IF v_need > 0 THEN
      INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
      SELECT p_player_id, p_season_id, t.id
      FROM (
        SELECT id
        FROM public.bp_quest_templates
        WHERE quest_type = 'weekly'
          AND id NOT IN (
            SELECT q.template_id
            FROM public.bp_player_quests q
            WHERE q.player_id = p_player_id
              AND q.season_id = p_season_id
          )
        ORDER BY random()
        LIMIT v_need
      ) t
      ON CONFLICT (player_id, season_id, template_id) DO NOTHING;
    END IF;

    UPDATE public.bp_player_status
    SET weekly_quests_week = v_week,
        updated_at = now()
    WHERE player_id = p_player_id AND season_id = p_season_id;
  END IF;
END;
$$;

-- ── 6. Lazy init + refresh on season load ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.bp_ensure_player_initialized()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_active_season_id uuid;
BEGIN
  IF v_player_id IS NULL THEN RETURN; END IF;

  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  INSERT INTO public.bp_player_status (
    player_id, season_id, current_bpp, current_level,
    daily_grind_bpp_pool, daily_pvp_bpp_pool, has_vip,
    claimed_normal, claimed_vip
  )
  VALUES (v_player_id, v_active_season_id, 0, 0, 0, 0, false, '{}', '{}')
  ON CONFLICT (player_id, season_id) DO NOTHING;

  PERFORM public.bp_refresh_player_quests(v_player_id, v_active_season_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.bp_ensure_player_initialized() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bp_refresh_player_quests(uuid, uuid, boolean, boolean) TO service_role;

-- ── 7. Season rotation — 5 daily + 4 weekly (not all weeklies) ──────────────
CREATE OR REPLACE FUNCTION public.cron_bp_season_rotation()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_max_season_num integer;
  v_new_season_id uuid;
  v_today date := (timezone('utc', now()))::date;
  v_week date := date_trunc('week', timezone('utc', now()))::date;
BEGIN
  UPDATE public.bp_seasons SET is_active = false WHERE is_active = true;

  SELECT COALESCE(MAX(season_number), 0) FROM public.bp_seasons INTO v_max_season_num;

  INSERT INTO public.bp_seasons (season_number, start_at, end_at, is_active)
  VALUES (v_max_season_num + 1, now(), now() + interval '14 days', true)
  RETURNING id INTO v_new_season_id;

  INSERT INTO public.bp_player_status (
    player_id, season_id, current_bpp, current_level,
    daily_grind_bpp_pool, daily_pvp_bpp_pool, updated_at,
    daily_quests_date, weekly_quests_week
  )
  SELECT u.auth_id, v_new_season_id, 0, 0, 0, 0, now(), v_today, v_week
  FROM public.users u
  WHERE u.auth_id IS NOT NULL
  ON CONFLICT DO NOTHING;

  INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
  SELECT u.auth_id, v_new_season_id, t.id
  FROM public.users u
  CROSS JOIN LATERAL (
    SELECT id FROM public.bp_quest_templates
    WHERE quest_type = 'daily'
    ORDER BY random() LIMIT 5
  ) t
  WHERE u.auth_id IS NOT NULL
  ON CONFLICT DO NOTHING;

  INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
  SELECT u.auth_id, v_new_season_id, t.id
  FROM public.users u
  CROSS JOIN LATERAL (
    SELECT id FROM public.bp_quest_templates
    WHERE quest_type = 'weekly'
    ORDER BY random() LIMIT 4
  ) t
  WHERE u.auth_id IS NOT NULL
  ON CONFLICT DO NOTHING;
END;
$$;

-- ── 8. Craft: rarity BPP only; quest progress via claim path (no double grant)
CREATE OR REPLACE FUNCTION public.bp_trigger_crafting(
  p_player_id uuid,
  p_rarity text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
    ELSE 20
  END;

  UPDATE public.bp_player_status
  SET current_bpp = current_bpp + v_bpp_reward,
      updated_at = now()
  WHERE player_id = p_player_id AND season_id = v_active_season_id;

  PERFORM public.bp_trigger_quest_progress(p_player_id, 'craft', 1);
  PERFORM public.bp_check_level_up(p_player_id, v_active_season_id);
END;
$$;

COMMIT;
