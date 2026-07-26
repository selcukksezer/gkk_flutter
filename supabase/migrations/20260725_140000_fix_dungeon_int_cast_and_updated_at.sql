-- Fix dungeon crash + retention background errors:
-- 1) attack_dungeon_rl_inner: over-escaped '\D' left "dng_001" intact → ::integer boom
-- 2) refresh_player_nemesis: pvp_invites has no updated_at
-- 3) get_comeback_summary: player_quests has no updated_at

CREATE OR REPLACE FUNCTION public.attack_dungeon_rl_inner(p_dungeon_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_result           JSONB;
  v_items_raw        JSONB;
  v_hospital_until   TIMESTAMPTZ;
  v_hospital_secs    INTEGER := 0;
  v_player_id        UUID;
  v_run_count        INTEGER;
  v_dungeon_num      INTEGER;
  v_item             RECORD;
  v_qty              INTEGER;
  v_success          BOOLEAN;
BEGIN
  v_player_id := auth.uid();
  v_result := public.enter_dungeon(v_player_id, p_dungeon_id);

  IF v_result ? 'error' THEN
    RETURN v_result;
  END IF;

  v_success := COALESCE((v_result->>'success')::BOOLEAN, false);
  v_items_raw := COALESCE(v_result->'items', '[]'::JSONB);

  IF v_success THEN
    -- Use [^0-9] — avoids \D backslash escaping bugs across migrations.
    v_dungeon_num := COALESCE(
      NULLIF(regexp_replace(p_dungeon_id, '[^0-9]', '', 'g'), '')::INTEGER,
      0
    );

    SELECT COUNT(*) INTO v_run_count
    FROM public.dungeon_runs
    WHERE player_id = v_player_id;

    IF v_run_count <= 1 THEN
      SELECT id, name, type INTO v_item
      FROM public.items
      WHERE lower(rarity) = 'common'
        AND lower(type) IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY random()
      LIMIT 1;

      IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', v_item.id, 'name', v_item.name,
          'rarity', 'common', 'type', v_item.type, 'quantity', 1
        );
      END IF;

      IF public.dungeon_add_item(v_player_id, 'scroll_upgrade_low', 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', 'scroll_upgrade_low', 'name', 'Lesser Upgrade Scroll',
          'rarity', 'common', 'type', 'scroll', 'quantity', 1
        );
      END IF;
    END IF;

    IF v_dungeon_num BETWEEN 1 AND 10 AND random() < 0.40 THEN
      SELECT i.id, i.name, i.type INTO v_item
      FROM public.items i
      WHERE lower(i.rarity) = 'common'
        AND lower(i.type) IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY
        (EXISTS (
          SELECT 1 FROM public.inventory inv
          JOIN public.items it ON it.id = inv.item_id
          WHERE inv.user_id = v_player_id
            AND lower(it.type) = lower(i.type)
        )) ASC,
        (EXISTS (
          SELECT 1 FROM public.inventory inv
          WHERE inv.user_id = v_player_id AND inv.item_id = i.id
        )) ASC,
        random()
      LIMIT 1;

      IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, 1) THEN
        v_items_raw := v_items_raw || jsonb_build_object(
          'item_id', v_item.id, 'name', v_item.name,
          'rarity', 'common', 'type', v_item.type, 'quantity', 1
        );
      END IF;
    END IF;

    v_qty := 5 + floor(random() * 11)::INTEGER;
    SELECT id, name, type INTO v_item
    FROM public.items
    WHERE lower(rarity) = 'common'
      AND lower(type) = 'material'
      AND COALESCE(is_stackable, false)
    ORDER BY COALESCE(base_price, 0) ASC, random()
    LIMIT 1;

    IF FOUND AND public.dungeon_add_item(v_player_id, v_item.id, v_qty) THEN
      v_items_raw := v_items_raw || jsonb_build_object(
        'item_id', v_item.id, 'name', v_item.name,
        'rarity', 'common', 'type', v_item.type, 'quantity', v_qty
      );
    END IF;
  END IF;

  IF (v_result->>'hospital_until') IS NOT NULL THEN
    BEGIN
      v_hospital_until := (v_result->>'hospital_until')::TIMESTAMPTZ;
      v_hospital_secs := GREATEST(0, EXTRACT(EPOCH FROM (v_hospital_until - now()))::INTEGER);
    EXCEPTION WHEN OTHERS THEN
      v_hospital_secs := 0;
    END;
  END IF;

  RETURN jsonb_build_object(
    'success', v_success,
    'gold', COALESCE((v_result->>'gold_earned')::INTEGER, 0),
    'gold_earned', COALESCE((v_result->>'gold_earned')::INTEGER, 0),
    'xp', COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'xp_earned', COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'items', v_items_raw,
    'item_details', v_items_raw,
    'hospitalized', COALESCE((v_result->>'hospitalized')::BOOLEAN, false),
    'hospital_duration', v_hospital_secs,
    'hospital_until', v_result->>'hospital_until',
    'inventory_full', COALESCE((v_result->>'inventory_full')::BOOLEAN, false),
    'is_critical', COALESCE((v_result->>'is_critical')::BOOLEAN, false),
    'is_first_clear', COALESCE((v_result->>'is_first_clear')::BOOLEAN, false),
    'success_rate', COALESCE((v_result->>'success_rate')::NUMERIC, 0),
    'reward_multiplier', COALESCE((v_result->>'reward_multiplier')::NUMERIC, 1),
    'hospital_risk_pct', COALESCE((v_result->>'hospital_risk_pct')::NUMERIC, 0),
    'milestone_rewards', COALESCE(v_result->'milestone_rewards', '[]'::jsonb),
    'reputation_buffs', COALESCE(v_result->'reputation_buffs', '[]'::jsonb),
    'siege_bonus', public.dungeon_siege_run_bonus_for_result(v_player_id, p_dungeon_id, v_success)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_player_nemesis(p_player_id UUID DEFAULT auth.uid())
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_best RECORD;
  v_window_start TIMESTAMPTZ;
BEGIN
  IF p_player_id IS NULL THEN RETURN; END IF;

  v_window_start := (now() AT TIME ZONE 'Europe/Istanbul') - interval '7 days';

  WITH duel_matches AS (
    SELECT
      CASE
        WHEN (i.result->>'winner_id')::UUID = i.challenger_id THEN i.target_id
        ELSE i.challenger_id
      END AS opponent_id,
      CASE WHEN (i.result->>'winner_id')::UUID = p_player_id THEN 1 ELSE 0 END AS win,
      CASE WHEN (i.result->>'winner_id')::UUID = p_player_id THEN 0 ELSE 1 END AS loss,
      COALESCE(i.expires_at, i.created_at) AS matched_at
    FROM public.pvp_invites i
    WHERE i.status = 'accepted'
      AND i.result IS NOT NULL
      AND p_player_id IN (i.challenger_id, i.target_id)
      AND COALESCE(i.expires_at, i.created_at) >= v_window_start
    UNION ALL
    SELECT
      CASE WHEN m.winner_id = m.attacker_id THEN m.defender_id ELSE m.attacker_id END,
      CASE WHEN m.winner_id = p_player_id THEN 1 ELSE 0 END,
      CASE WHEN m.winner_id = p_player_id THEN 0 ELSE 1 END,
      m.created_at
    FROM public.mekan_pvp_matches m
    WHERE p_player_id IN (m.attacker_id, m.defender_id)
      AND m.winner_id IS NOT NULL
      AND m.created_at >= v_window_start
  ),
  agg AS (
    SELECT
      opponent_id,
      SUM(loss) AS losses,
      SUM(win) AS wins,
      MAX(matched_at) AS last_match_at,
      SUM(loss) * 3 + SUM(win) AS score
    FROM duel_matches
    WHERE opponent_id IS NOT NULL AND opponent_id <> p_player_id
    GROUP BY opponent_id
    HAVING SUM(loss) >= 1
  )
  SELECT * INTO v_best
  FROM agg
  ORDER BY score DESC, losses DESC, last_match_at DESC
  LIMIT 1;

  IF v_best.opponent_id IS NULL THEN
    DELETE FROM public.player_nemesis_state WHERE player_id = p_player_id;
    RETURN;
  END IF;

  INSERT INTO public.player_nemesis_state (player_id, nemesis_id, losses, wins, last_match_at, updated_at)
  VALUES (p_player_id, v_best.opponent_id, v_best.losses, v_best.wins, v_best.last_match_at, now())
  ON CONFLICT (player_id) DO UPDATE SET
    nemesis_id = EXCLUDED.nemesis_id,
    losses = EXCLUDED.losses,
    wins = EXCLUDED.wins,
    last_match_at = EXCLUDED.last_match_at,
    updated_at = now();
END;
$$;

-- Patch get_comeback_summary: player_quests has no updated_at
DO $$
DECLARE
  v_def TEXT;
BEGIN
  SELECT pg_get_functiondef('public.get_comeback_summary()'::regprocedure) INTO v_def;
  IF v_def IS NULL THEN
    RAISE NOTICE 'get_comeback_summary missing — skip';
    RETURN;
  END IF;
  IF position('pq.updated_at' IN v_def) = 0 THEN
    RAISE NOTICE 'get_comeback_summary already patched — skip';
    RETURN;
  END IF;
  v_def := replace(
    v_def,
    'ORDER BY pq.updated_at DESC NULLS LAST',
    'ORDER BY pq.completed_at DESC NULLS LAST, pq.created_at DESC'
  );
  EXECUTE v_def;
END;
$$;
