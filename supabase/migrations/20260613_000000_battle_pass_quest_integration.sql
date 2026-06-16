-- Battle Pass fixes:
-- 1) player_id = auth.uid() (not users.id)
-- 2) Level 0 at start — level 1 rewards unlock at 1000 BPP
-- 3) Lazy init quests on season load
-- 4) Quest BPP claimed on season page (not auto)
-- 5) Season quests visible in general quests screen

BEGIN;

-- ── 1. Schema tweaks ────────────────────────────────────────────────────────
ALTER TABLE public.bp_player_quests
  ADD COLUMN IF NOT EXISTS reward_claimed boolean NOT NULL DEFAULT false;

ALTER TABLE public.bp_player_status
  DROP CONSTRAINT IF EXISTS bp_player_status_current_level_check;

ALTER TABLE public.bp_player_status
  ADD CONSTRAINT bp_player_status_current_level_check
  CHECK (current_level BETWEEN 0 AND 20);

ALTER TABLE public.bp_player_status
  ALTER COLUMN current_level SET DEFAULT 0;

-- Fix rows stored with users.id instead of auth_id
UPDATE public.bp_player_status bps
SET player_id = u.auth_id
FROM public.users u
WHERE bps.player_id = u.id
  AND u.auth_id IS NOT NULL
  AND bps.player_id IS DISTINCT FROM u.auth_id;

UPDATE public.bp_player_quests bpq
SET player_id = u.auth_id
FROM public.users u
WHERE bpq.player_id = u.id
  AND u.auth_id IS NOT NULL
  AND bpq.player_id IS DISTINCT FROM u.auth_id;

-- Recalculate levels: 0 BPP = level 0, 1000 BPP = level 1, ...
UPDATE public.bp_player_status
SET current_level = LEAST(current_bpp / 1000, 20);

-- ── 2. Level calculation ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.bp_check_level_up(p_player_id uuid, p_season_id uuid)
RETURNS void AS $$
DECLARE
  v_current_bpp integer;
  v_calculated_level integer;
BEGIN
  SELECT current_bpp FROM public.bp_player_status
  WHERE player_id = p_player_id AND season_id = p_season_id
  INTO v_current_bpp;

  IF v_current_bpp IS NULL THEN RETURN; END IF;

  v_calculated_level := LEAST(v_current_bpp / 1000, 20);

  UPDATE public.bp_player_status
  SET current_level = v_calculated_level,
      updated_at = now()
  WHERE player_id = p_player_id AND season_id = p_season_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 3. Quest progress — complete without auto BPP grant ───────────────────────
CREATE OR REPLACE FUNCTION public.bp_trigger_quest_progress(
  p_player_id uuid,
  p_target_system text,
  p_progress_amount integer DEFAULT 1
)
RETURNS void AS $$
DECLARE
  v_active_season_id uuid;
BEGIN
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN RETURN; END IF;

  UPDATE public.bp_player_quests q
  SET current_progress = LEAST(q.current_progress + p_progress_amount, t.target_count),
      updated_at = now()
  FROM public.bp_quest_templates t
  WHERE q.template_id = t.id
    AND q.player_id = p_player_id
    AND q.season_id = v_active_season_id
    AND t.target_system = p_target_system
    AND q.is_completed = false
    AND q.reward_claimed = false;

  UPDATE public.bp_player_quests q
  SET is_completed = true,
      updated_at = now()
  FROM public.bp_quest_templates t
  WHERE q.template_id = t.id
    AND q.current_progress >= t.target_count
    AND q.is_completed = false
    AND q.reward_claimed = false
    AND q.player_id = p_player_id
    AND q.season_id = v_active_season_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 4. Ensure player season + quests ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.bp_ensure_player_initialized()
RETURNS void AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_active_season_id uuid;
  v_existing_quests integer;
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

  SELECT COUNT(*) INTO v_existing_quests
  FROM public.bp_player_quests
  WHERE player_id = v_player_id AND season_id = v_active_season_id;

  IF v_existing_quests = 0 THEN
    INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
    SELECT v_player_id, v_active_season_id, t.id
    FROM (
      SELECT id FROM public.bp_quest_templates
      WHERE quest_type = 'daily'
      ORDER BY random() LIMIT 3
    ) t
    ON CONFLICT (player_id, season_id, template_id) DO NOTHING;

    INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
    SELECT v_player_id, v_active_season_id, id
    FROM public.bp_quest_templates
    WHERE quest_type = 'weekly'
    ON CONFLICT (player_id, season_id, template_id) DO NOTHING;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.bp_ensure_player_initialized() TO authenticated;

-- ── 5. Claim season quest BPP reward ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.bp_claim_quest_reward(p_quest_id uuid)
RETURNS json AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_active_season_id uuid;
  v_quest record;
  v_template record;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Aktif sezon bulunamadı.');
  END IF;

  SELECT q.*, t.bpp_reward, t.description
  INTO v_quest
  FROM public.bp_player_quests q
  JOIN public.bp_quest_templates t ON t.id = q.template_id
  WHERE q.id = p_quest_id
    AND q.player_id = v_player_id
    AND q.season_id = v_active_season_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Görev bulunamadı.');
  END IF;

  IF NOT v_quest.is_completed THEN
    RETURN json_build_object('success', false, 'error', 'Görev henüz tamamlanmadı.');
  END IF;

  IF v_quest.reward_claimed THEN
    RETURN json_build_object('success', false, 'error', 'Ödül zaten alındı.');
  END IF;

  UPDATE public.bp_player_status
  SET current_bpp = current_bpp + v_quest.bpp_reward,
      updated_at = now()
  WHERE player_id = v_player_id AND season_id = v_active_season_id;

  UPDATE public.bp_player_quests
  SET reward_claimed = true,
      updated_at = now()
  WHERE id = p_quest_id;

  PERFORM public.bp_check_level_up(v_player_id, v_active_season_id);

  RETURN json_build_object(
    'success', true,
    'bpp_reward', v_quest.bpp_reward,
    'message', 'Sezon görev ödülü alındı.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.bp_claim_quest_reward(uuid) TO authenticated;

-- ── 6. Level reward claim — level 1 needs 1000 BPP ──────────────────────────
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
  SELECT id FROM public.bp_seasons WHERE is_active = true INTO v_active_season_id;
  IF v_active_season_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Aktif sezon bulunamadı.');
  END IF;

  PERFORM public.bp_ensure_player_initialized();

  SELECT * FROM public.bp_player_status
  WHERE player_id = v_player_id AND season_id = v_active_season_id
  INTO v_status;

  IF v_status IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Sezon katılımı bulunamadı.');
  END IF;

  IF p_level > v_status.current_level THEN
    RETURN json_build_object('success', false, 'error', 'Bu seviyeye henüz ulaşmadınız.');
  END IF;

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

  SELECT * FROM public.bp_level_rewards WHERE level = p_level INTO v_reward;
  IF v_reward IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Ödül tanımı bulunamadı.');
  END IF;

  IF p_is_vip THEN
    IF v_reward.vip_reward_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_reward.vip_reward_gold WHERE auth_id = v_player_id;
    END IF;
    IF v_reward.vip_reward_item_id IS NOT NULL THEN
      INSERT INTO public.inventory (user_id, item_id, quantity)
      VALUES (v_player_id, v_reward.vip_reward_item_id, v_reward.vip_reward_quantity)
      ON CONFLICT (user_id, item_id) WHERE slot_position IS NULL
      DO UPDATE SET quantity = inventory.quantity + v_reward.vip_reward_quantity, updated_at = now();
    END IF;
    UPDATE public.bp_player_status
    SET claimed_vip = array_append(claimed_vip, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  ELSE
    IF v_reward.normal_reward_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_reward.normal_reward_gold WHERE auth_id = v_player_id;
    END IF;
    IF v_reward.normal_reward_item_id IS NOT NULL THEN
      INSERT INTO public.inventory (user_id, item_id, quantity)
      VALUES (v_player_id, v_reward.normal_reward_item_id, v_reward.normal_reward_quantity)
      ON CONFLICT (user_id, item_id) WHERE slot_position IS NULL
      DO UPDATE SET quantity = inventory.quantity + v_reward.normal_reward_quantity, updated_at = now();
    END IF;
    UPDATE public.bp_player_status
    SET claimed_normal = array_append(claimed_normal, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  END IF;

  RETURN json_build_object('success', true, 'message', 'Ödül başarıyla alındı.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 7. Season rotation — use auth_id ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cron_bp_season_rotation()
RETURNS void AS $$
DECLARE
  v_max_season_num integer;
  v_new_season_id uuid;
BEGIN
  UPDATE public.bp_seasons SET is_active = false WHERE is_active = true;

  SELECT COALESCE(MAX(season_number), 0) FROM public.bp_seasons INTO v_max_season_num;

  INSERT INTO public.bp_seasons (season_number, start_at, end_at, is_active)
  VALUES (v_max_season_num + 1, now(), now() + interval '14 days', true)
  RETURNING id INTO v_new_season_id;

  INSERT INTO public.bp_player_status (
    player_id, season_id, current_bpp, current_level,
    daily_grind_bpp_pool, daily_pvp_bpp_pool, updated_at
  )
  SELECT u.auth_id, v_new_season_id, 0, 0, 0, 0, now()
  FROM public.users u
  WHERE u.auth_id IS NOT NULL
  ON CONFLICT DO NOTHING;

  INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
  SELECT u.auth_id, v_new_season_id, t.id
  FROM public.users u
  CROSS JOIN LATERAL (
    SELECT id FROM public.bp_quest_templates
    WHERE quest_type = 'daily'
    ORDER BY random() LIMIT 3
  ) t
  WHERE u.auth_id IS NOT NULL
  ON CONFLICT DO NOTHING;

  INSERT INTO public.bp_player_quests (player_id, season_id, template_id)
  SELECT u.auth_id, v_new_season_id, t.id
  FROM public.users u
  CROSS JOIN public.bp_quest_templates t
  WHERE u.auth_id IS NOT NULL
    AND t.quest_type = 'weekly'
  ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 8. General quests — include season quests ───────────────────────────────
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

  SELECT json_agg(row ORDER BY row.is_season_quest DESC, row.name) INTO v_result
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
      COALESCE(pq.status, 'available') AS status,
      COALESCE(pq.progress, 0) AS progress,
      q.target AS progress_max,
      pq.expires_at,
      false AS is_season_quest,
      0 AS bpp_reward,
      NULL::uuid AS bp_player_quest_id,
      q.quest_type
    FROM public.quests q
    LEFT JOIN public.player_quests pq
      ON pq.quest_id = q.quest_id AND pq.user_id = v_user_id
    WHERE q.required_level <= p_player_level
      AND COALESCE(pq.status, 'available') != 'claimed'

    UNION ALL

    SELECT
      bpq.id,
      'bp_' || bpq.id::text AS quest_id,
      CASE
        WHEN t.quest_type = 'daily' THEN '🏆 Günlük Sezon Görevi'
        ELSE '🏆 Haftalık Sezon Görevi'
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
      t.quest_type
    FROM public.bp_player_quests bpq
    JOIN public.bp_quest_templates t ON t.id = bpq.template_id
    JOIN public.bp_seasons s ON s.id = bpq.season_id AND s.is_active = true
    WHERE bpq.player_id = v_user_id
      AND bpq.reward_claimed = false
  ) row;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

-- Season quests cannot be started/abandoned via general quest RPCs
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
  IF p_quest_id LIKE 'bp_%' THEN
    RAISE EXCEPTION 'Sezon görevleri otomatik takip edilir.';
  END IF;

  SELECT energy_cost, target INTO v_energy_cost, v_target
  FROM public.quests WHERE quest_id = p_quest_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev bulunamadı.';
  END IF;

  SELECT energy INTO v_current_energy
  FROM public.users WHERE auth_id = v_user_id;

  IF v_current_energy < v_energy_cost THEN
    RAISE EXCEPTION 'Yetersiz enerji.';
  END IF;

  IF v_energy_cost > 0 THEN
    UPDATE public.users SET energy = energy - v_energy_cost WHERE auth_id = v_user_id;
  END IF;

  INSERT INTO public.player_quests (user_id, quest_id, status, progress, progress_max)
  VALUES (v_user_id, p_quest_id, 'active', 0, v_target)
  ON CONFLICT (user_id, quest_id) DO UPDATE
  SET status = 'active', progress = 0, progress_max = v_target;
END;
$$;

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
  IF p_quest_id LIKE 'bp_%' THEN
    RAISE EXCEPTION 'Sezon görev ödülü sezon sayfasından alınır.';
  END IF;

  SELECT status INTO v_status
  FROM public.player_quests
  WHERE user_id = v_user_id AND quest_id = p_quest_id;

  IF NOT FOUND OR v_status != 'completed' THEN
    RAISE EXCEPTION 'Ödül alınabilir durumda değil.';
  END IF;

  SELECT gold_reward, xp_reward, gem_reward INTO v_gold, v_xp, v_gem
  FROM public.quests WHERE quest_id = p_quest_id;

  UPDATE public.users
  SET gold = gold + v_gold, xp = xp + v_xp, gems = gems + v_gem
  WHERE auth_id = v_user_id;

  UPDATE public.player_quests
  SET status = 'claimed'
  WHERE user_id = v_user_id AND quest_id = p_quest_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.abandon_quest(p_quest_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF p_quest_id LIKE 'bp_%' THEN
    RAISE EXCEPTION 'Sezon görevleri iptal edilemez.';
  END IF;

  DELETE FROM public.player_quests
  WHERE user_id = v_user_id AND quest_id = p_quest_id AND status = 'active';
END;
$$;

-- buy_vip_pass init — level 0 + quest assign
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

  PERFORM public.bp_ensure_player_initialized();

  SELECT * FROM public.bp_player_status
  WHERE player_id = v_player_id AND season_id = v_active_season_id
  INTO v_status;

  IF v_status.has_vip THEN
    RETURN jsonb_build_object('success', false, 'error', 'Zaten VIP aktif.');
  END IF;

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

  UPDATE public.users SET gems = gems - v_vip_cost WHERE auth_id = v_player_id;

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

COMMIT;
