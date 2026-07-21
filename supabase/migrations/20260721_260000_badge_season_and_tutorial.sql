-- Product decision: Option C (hybrid) — manual L20 claim, badge_season_{NN} per active season.
-- Season badge (hybrid per-season item) + tutorial_progress + QA smoke.

-- ── Tutorial progress on users ───────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS tutorial_progress JSONB NOT NULL DEFAULT '{}'::jsonb;

-- ── Season badge items (seasons 1–12) ────────────────────────────────────────
INSERT INTO public.items (id, name, type, description, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable)
SELECT
  'badge_season_' || LPAD(gs::text, 2, '0'),
  'Season ' || gs || ' Veteran Badge',
  'cosmetic',
  'BP Sezon ' || gs || ' — L20 free track rozeti.',
  'epic',
  0,
  0,
  false,
  false
FROM generate_series(1, 12) gs
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  type = EXCLUDED.type;

CREATE OR REPLACE FUNCTION public.ensure_season_badge_item(p_season_number integer)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_badge_id text := 'badge_season_' || LPAD(GREATEST(p_season_number, 1)::text, 2, '0');
BEGIN
  INSERT INTO public.items (id, name, type, description, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable)
  VALUES (
    v_badge_id,
    'Season ' || GREATEST(p_season_number, 1) || ' Veteran Badge',
    'cosmetic',
    'BP Sezon ' || GREATEST(p_season_number, 1) || ' — L20 free track rozeti.',
    'epic', 0, 0, false, false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN v_badge_id;
END;
$$;

-- ── Sync tutorial progress from client ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_tutorial_progress(p_progress jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_merged jsonb;
  v_completed boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  v_merged := COALESCE(
    (SELECT tutorial_progress FROM public.users WHERE auth_id = v_user_id),
    '{}'::jsonb
  ) || COALESCE(p_progress, '{}'::jsonb);

  v_completed := COALESCE((v_merged->>'core_completed')::boolean, false)
    OR COALESCE((v_merged->>'skipped_all')::boolean, false);

  UPDATE public.users
  SET tutorial_progress = v_merged,
      tutorial_completed = CASE WHEN v_completed THEN true ELSE tutorial_completed END,
      updated_at = now()
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'tutorial_progress', v_merged,
    'tutorial_completed', v_completed
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_tutorial_progress(jsonb) TO authenticated;

-- ── bp_claim_reward: season-specific L20 badge + slot-aware item grant ───────
CREATE OR REPLACE FUNCTION public.bp_claim_reward(
  p_level integer,
  p_is_vip boolean
)
RETURNS json AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_active_season_id uuid;
  v_season_number integer := 1;
  v_status record;
  v_reward record;
  v_item_id text;
  v_qty integer;
  v_added boolean;
BEGIN
  SELECT id, season_number INTO v_active_season_id, v_season_number
  FROM public.bp_seasons WHERE is_active = true;
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
    v_item_id := v_reward.vip_reward_item_id;
    v_qty := COALESCE(v_reward.vip_reward_quantity, 1);
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_player_id, v_item_id, v_qty);
      IF NOT v_added THEN
        RETURN json_build_object('success', false, 'error', 'Envanter dolu — ödül alınamadı.');
      END IF;
    END IF;
    UPDATE public.bp_player_status
    SET claimed_vip = array_append(claimed_vip, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  ELSE
    IF v_reward.normal_reward_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_reward.normal_reward_gold WHERE auth_id = v_player_id;
    END IF;
    IF p_level = 20 THEN
      v_item_id := public.ensure_season_badge_item(v_season_number);
    ELSE
      v_item_id := v_reward.normal_reward_item_id;
    END IF;
    v_qty := COALESCE(v_reward.normal_reward_quantity, 1);
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_player_id, v_item_id, v_qty);
      IF NOT v_added THEN
        RETURN json_build_object('success', false, 'error', 'Envanter dolu — ödül alınamadı.');
      END IF;
    END IF;
    UPDATE public.bp_player_status
    SET claimed_normal = array_append(claimed_normal, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', 'Ödül başarıyla alındı.',
    'item_id', v_item_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── QA: badge season smoke BADGE-01..06 ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.qa_badge_season_smoke()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_auth uuid := gen_random_uuid();
  v_season_id uuid;
  v_season_num integer;
  v_results jsonb := '[]'::jsonb;
  v_ok boolean;
  v_claim json;
  v_claim2 json;
  v_claim_vip json;
  v_claim_low json;
  v_badge_id text;
  v_has_badge boolean;
  v_i integer;
BEGIN
  PERFORM set_config('app.qa_mode', 'true', true);

  DELETE FROM public.bp_player_quests WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_badge_smoke'
  );
  DELETE FROM public.bp_player_status WHERE player_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_badge_smoke'
  );
  DELETE FROM public.inventory WHERE user_id IN (
    SELECT auth_id FROM public.users WHERE username = 'qa_badge_smoke'
  );
  DELETE FROM auth.users WHERE email = 'qa_badge_smoke@sim.local';
  DELETE FROM public.users WHERE username = 'qa_badge_smoke';

  INSERT INTO auth.users (
    id, aud, role, email, email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) VALUES (
    v_auth, 'authenticated', 'authenticated',
    'qa_badge_smoke@sim.local', now(), now(), now(),
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('username', 'qa_badge_smoke', 'is_bot', true)
  );

  INSERT INTO public.users (
    id, auth_id, username, email, display_name, level, xp, gold, energy, max_energy,
    attack, defense, health, max_health, power, gems, created_at, updated_at
  ) VALUES (
    v_auth, v_auth, 'qa_badge_smoke', 'qa_badge_smoke@sim.local', 'QA Badge Smoke',
    10, 1000, 500000, 100, 100, 30, 25, 120, 120, 200, 500, now(), now()
  )
  ON CONFLICT (auth_id) DO UPDATE SET username = EXCLUDED.username;

  SELECT id, season_number INTO v_season_id, v_season_num
  FROM public.bp_seasons WHERE is_active = true LIMIT 1;

  IF v_season_id IS NULL THEN
    PERFORM public.cron_bp_season_rotation();
    SELECT id, season_number INTO v_season_id, v_season_num
    FROM public.bp_seasons WHERE is_active = true LIMIT 1;
  END IF;

  v_badge_id := public.ensure_season_badge_item(v_season_num);

  PERFORM set_config('request.jwt.claim.sub', v_auth::text, true);
  PERFORM public.bp_ensure_player_initialized();

  UPDATE public.bp_player_status
  SET current_bpp = 20000, current_level = 20, has_vip = true, updated_at = now()
  WHERE player_id = v_auth AND season_id = v_season_id;

  -- BADGE-01
  v_claim := public.bp_claim_reward(20, false);
  SELECT EXISTS (
    SELECT 1 FROM public.inventory WHERE user_id = v_auth AND item_id = v_badge_id
  ) INTO v_has_badge;
  v_ok := COALESCE((v_claim->>'success')::boolean, false) AND v_has_badge;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'BADGE-01_l20_normal_claim', 'area', 'badge', 'pass', v_ok,
    'detail', jsonb_build_object('claim', v_claim::jsonb, 'badge_id', v_badge_id, 'has_badge', v_has_badge)
  ));

  -- BADGE-02 duplicate
  v_claim2 := public.bp_claim_reward(20, false);
  v_ok := COALESCE((v_claim2->>'success')::boolean, true) = false
      AND (v_claim2->>'error') = 'Bu ödül zaten alındı.';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'BADGE-02_duplicate_claim', 'area', 'badge', 'pass', v_ok,
    'detail', v_claim2::jsonb
  ));

  -- BADGE-03 level 19
  DELETE FROM public.inventory WHERE user_id = v_auth AND item_id = v_badge_id;
  UPDATE public.bp_player_status
  SET current_bpp = 19000, current_level = 19,
      claimed_normal = '{}', claimed_vip = '{}', updated_at = now()
  WHERE player_id = v_auth AND season_id = v_season_id;
  v_claim_low := public.bp_claim_reward(20, false);
  v_ok := COALESCE((v_claim_low->>'success')::boolean, true) = false;
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'BADGE-03_level_19_blocked', 'area', 'badge', 'pass', v_ok,
    'detail', v_claim_low::jsonb
  ));

  -- BADGE-04 VIP L20
  UPDATE public.bp_player_status
  SET current_bpp = 20000, current_level = 20, has_vip = true,
      claimed_normal = '{}', claimed_vip = '{}', updated_at = now()
  WHERE player_id = v_auth AND season_id = v_season_id;
  v_claim_vip := public.bp_claim_reward(20, true);
  v_ok := COALESCE((v_claim_vip->>'success')::boolean, false)
      AND NOT EXISTS (SELECT 1 FROM public.inventory WHERE user_id = v_auth AND item_id = v_badge_id)
      AND EXISTS (SELECT 1 FROM public.inventory WHERE user_id = v_auth AND item_id = 'box_weapon_legendary');
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'BADGE-04_vip_legendary_not_badge', 'area', 'badge', 'pass', v_ok,
    'detail', v_claim_vip::jsonb
  ));

  -- BADGE-05 season rotation keeps badge, new season re-grind
  INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped)
  SELECT gen_random_uuid(), v_auth, v_badge_id, 1,
    COALESCE((SELECT MAX(slot_position) + 1 FROM public.inventory WHERE user_id = v_auth), 0),
    false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.inventory WHERE user_id = v_auth AND item_id = v_badge_id
  );
  UPDATE public.bp_player_status
  SET current_bpp = 20000, current_level = 20, claimed_normal = array[20], updated_at = now()
  WHERE player_id = v_auth AND season_id = v_season_id;
  PERFORM public.cron_bp_season_rotation();
  SELECT id, season_number INTO v_season_id, v_season_num
  FROM public.bp_seasons WHERE is_active = true LIMIT 1;
  PERFORM public.bp_ensure_player_initialized();
  v_ok := EXISTS (SELECT 1 FROM public.inventory WHERE user_id = v_auth AND item_id LIKE 'badge_season_%')
      AND EXISTS (
        SELECT 1 FROM public.bp_player_status
        WHERE player_id = v_auth AND season_id = v_season_id AND current_level = 0
      );
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'BADGE-05_rotation_reset_status_keeps_badge', 'area', 'badge', 'pass', v_ok,
    'detail', jsonb_build_object('new_season', v_season_num)
  ));

  -- BADGE-06 full inventory blocks claim
  DELETE FROM public.inventory WHERE user_id = v_auth;
  FOR v_i IN 0..19 LOOP
    INSERT INTO public.inventory (row_id, user_id, item_id, quantity, slot_position, is_equipped)
    VALUES (gen_random_uuid(), v_auth, 'scroll_upgrade_low', 1, v_i, false);
  END LOOP;
  UPDATE public.bp_player_status
  SET current_bpp = 20000, current_level = 20, claimed_normal = '{}', updated_at = now()
  WHERE player_id = v_auth AND season_id = v_season_id;
  v_claim := public.bp_claim_reward(20, false);
  v_ok := COALESCE((v_claim->>'success')::boolean, true) = false
      AND (v_claim->>'error') ILIKE '%envanter%';
  v_results := v_results || jsonb_build_array(jsonb_build_object(
    'test', 'BADGE-06_full_inventory_blocked', 'area', 'badge', 'pass', v_ok,
    'detail', v_claim::jsonb
  ));

  DELETE FROM public.bp_player_quests WHERE player_id = v_auth;
  DELETE FROM public.bp_player_status WHERE player_id = v_auth;
  DELETE FROM public.inventory WHERE user_id = v_auth;
  DELETE FROM auth.users WHERE id = v_auth;
  DELETE FROM public.users WHERE auth_id = v_auth;

  RETURN jsonb_build_object(
    'verdict', CASE WHEN NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_results) t
      WHERE COALESCE((t->>'pass')::boolean, false) = false
    ) THEN 'PASS' ELSE 'FAIL' END,
    'tests', v_results,
    'passed', (SELECT COUNT(*) FROM jsonb_array_elements(v_results) t WHERE (t->>'pass')::boolean),
    'failed', (SELECT COUNT(*) FROM jsonb_array_elements(v_results) t WHERE NOT COALESCE((t->>'pass')::boolean, false)),
    'total', jsonb_array_length(v_results),
    'generated_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.qa_badge_season_smoke() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qa_badge_season_smoke() TO service_role;
