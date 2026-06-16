-- Tüm görevler otomatik aktif + sezon görev metinleri Türkçe

BEGIN;

UPDATE public.bp_quest_templates SET description = '3 zindan temizle'
WHERE target_system = 'dungeon' AND quest_type = 'daily' AND target_count = 3;

UPDATE public.bp_quest_templates SET description = '2 PvP maçı tamamla'
WHERE target_system = 'pvp' AND quest_type = 'daily' AND target_count = 2;

UPDATE public.bp_quest_templates SET description = '5 eşya üret'
WHERE target_system = 'craft' AND quest_type = 'daily' AND target_count = 5;

UPDATE public.bp_quest_templates SET description = 'Haftalık: 20 zindan temizle'
WHERE target_system = 'dungeon' AND quest_type = 'weekly' AND target_count = 20;

UPDATE public.bp_quest_templates SET description = 'Haftalık: 15 PvP maçı tamamla'
WHERE target_system = 'pvp' AND quest_type = 'weekly' AND target_count = 15;

UPDATE public.bp_quest_templates SET description = 'Haftalık: 50 eşya üret'
WHERE target_system = 'craft' AND quest_type = 'weekly' AND target_count = 50;

UPDATE public.bp_quest_templates SET description = 'Haftalık: 100 iksir kullan'
WHERE target_system = 'potion' AND quest_type = 'weekly' AND target_count = 100;

CREATE OR REPLACE FUNCTION public.get_available_quests(p_player_level integer)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result json;
BEGIN
  PERFORM public.bp_ensure_player_initialized();

  -- Tüm uygun görevleri otomatik aktif et (enerji düşmez)
  INSERT INTO public.player_quests (user_id, quest_id, status, progress, progress_max)
  SELECT v_user_id, q.quest_id, 'active', 0, q.target
  FROM public.quests q
  WHERE q.required_level <= p_player_level
    AND NOT EXISTS (
      SELECT 1 FROM public.player_quests pq
      WHERE pq.user_id = v_user_id AND pq.quest_id = q.quest_id
    )
  ON CONFLICT (user_id, quest_id) DO NOTHING;

  SELECT json_agg(row ORDER BY row.sort_order, row.name) INTO v_result
  FROM (
    SELECT
      q.id,
      q.quest_id,
      q.name,
      q.description,
      q.difficulty,
      q.required_level,
      q.energy_cost,
      q.gold_reward,
      q.xp_reward,
      q.gem_reward,
      q.item_rewards,
      q.target,
      COALESCE(pq.status, 'active') AS status,
      COALESCE(pq.progress, 0) AS progress,
      q.target AS progress_max,
      pq.expires_at,
      false AS is_season_quest,
      0 AS bpp_reward,
      NULL::uuid AS bp_player_quest_id,
      q.quest_type,
      CASE COALESCE(pq.status, 'active')
        WHEN 'completed' THEN 0
        WHEN 'active' THEN 1
        ELSE 2
      END AS sort_order
    FROM public.quests q
    LEFT JOIN public.player_quests pq
      ON pq.quest_id = q.quest_id AND pq.user_id = v_user_id
    WHERE q.required_level <= p_player_level
      AND COALESCE(pq.status, 'active') != 'claimed'

    UNION ALL

    SELECT
      bpq.id,
      'bp_' || bpq.id::text AS quest_id,
      CASE
        WHEN t.quest_type = 'daily' THEN 'Günlük Sezon Görevi'
        ELSE 'Haftalık Sezon Görevi'
      END AS name,
      t.description,
      CASE WHEN t.quest_type = 'daily' THEN 'easy' ELSE 'hard' END AS difficulty,
      1 AS required_level,
      0 AS energy_cost,
      0 AS gold_reward,
      0 AS xp_reward,
      0 AS gem_reward,
      '[]'::jsonb AS item_rewards,
      t.target_count AS target,
      CASE
        WHEN bpq.reward_claimed THEN 'claimed'
        WHEN bpq.is_completed THEN 'completed'
        ELSE 'active'
      END AS status,
      bpq.current_progress AS progress,
      t.target_count AS progress_max,
      NULL::timestamptz AS expires_at,
      true AS is_season_quest,
      t.bpp_reward AS bpp_reward,
      bpq.id AS bp_player_quest_id,
      t.quest_type,
      CASE
        WHEN bpq.is_completed AND NOT bpq.reward_claimed THEN 0
        WHEN bpq.is_completed AND bpq.reward_claimed THEN 2
        ELSE 1
      END AS sort_order
    FROM public.bp_player_quests bpq
    JOIN public.bp_quest_templates t ON t.id = bpq.template_id
    JOIN public.bp_seasons s ON s.id = bpq.season_id AND s.is_active = true
    WHERE bpq.player_id = v_user_id
      AND bpq.reward_claimed = false
  ) row;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

COMMIT;
