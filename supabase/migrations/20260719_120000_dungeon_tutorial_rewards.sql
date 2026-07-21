-- ============================================================================
-- ZİNDAN ÖĞRETİCİ ÖDÜLLERİ + DEĞERSİZ KAYNAK LOOT (attack_dungeon wrapper)
-- 1) İlk zindan koşusu: garantili 1 rastgele common ekipman + 1 scroll_upgrade_low
-- 2) Zindan 1-10: ~%40 şansla common set parçası (oyuncuda olmayan tip öncelikli)
-- 3) Her başarılı koşu: 5-15x ucuz common materyal (odun, taş, cevher vb.)
-- enter_dungeon core'una dokunulmaz; ekstra droplar wrapper'da eklenir.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.attack_dungeon(p_dungeon_id text)
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
BEGIN
  v_player_id := auth.uid();
  v_result := public.enter_dungeon(v_player_id, p_dungeon_id);

  IF v_result ? 'error' THEN
    RETURN v_result;
  END IF;

  v_items_raw := COALESCE(v_result->'items', '[]'::JSONB);

  IF COALESCE((v_result->>'success')::BOOLEAN, false) THEN
    v_dungeon_num := COALESCE(NULLIF(regexp_replace(p_dungeon_id, '\D', '', 'g'), '')::INTEGER, 0);

    -- ── 1) İlk koşu garantili öğretici drop ────────────────────────────────
    -- enter_dungeon az önce run insert etti; toplam 1 ise bu ilk koşuydu.
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

    -- ── 2) Zindan 1-10: common set parçası (~%40, eksik tip öncelikli) ─────
    IF v_dungeon_num BETWEEN 1 AND 10 AND random() < 0.40 THEN
      SELECT i.id, i.name, i.type INTO v_item
      FROM public.items i
      WHERE lower(i.rarity) = 'common'
        AND lower(i.type) IN ('weapon', 'armor', 'helmet', 'gloves', 'boots', 'accessory')
      ORDER BY
        -- Önce oyuncuda hiç olmayan ekipman tipleri
        (EXISTS (
          SELECT 1 FROM public.inventory inv
          JOIN public.items it ON it.id = inv.item_id
          WHERE inv.user_id = v_player_id
            AND lower(it.type) = lower(i.type)
        )) ASC,
        -- Sonra oyuncuda olmayan itemler
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

    -- ── 3) Değersiz kaynak loot: her başarılı koşuda 5-15x ─────────────────
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
      v_hospital_secs  := GREATEST(0, EXTRACT(EPOCH FROM (v_hospital_until - now()))::INTEGER);
    EXCEPTION WHEN OTHERS THEN
      v_hospital_secs := 0;
    END;
  END IF;

  RETURN jsonb_build_object(
    'success',             COALESCE((v_result->>'success')::BOOLEAN, false),
    'gold',                COALESCE((v_result->>'gold_earned')::INTEGER, 0),
    'gold_earned',         COALESCE((v_result->>'gold_earned')::INTEGER, 0),
    'xp',                  COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'xp_earned',           COALESCE((v_result->>'xp_earned')::INTEGER, 0),
    'items',               v_items_raw,
    'item_details',        v_items_raw,
    'hospitalized',        COALESCE((v_result->>'hospitalized')::BOOLEAN, false),
    'hospital_duration',   v_hospital_secs,
    'hospital_until',      v_result->>'hospital_until',
    'inventory_full',      COALESCE((v_result->>'inventory_full')::BOOLEAN, false),
    'is_critical',         COALESCE((v_result->>'is_critical')::BOOLEAN, false),
    'is_first_clear',      COALESCE((v_result->>'is_first_clear')::BOOLEAN, false),
    'success_rate',        COALESCE((v_result->>'success_rate')::NUMERIC, 0),
    'reward_multiplier',   COALESCE((v_result->>'reward_multiplier')::NUMERIC, 1),
    'hospital_risk_pct',   COALESCE((v_result->>'hospital_risk_pct')::NUMERIC, 0),
    'milestone_rewards',   COALESCE(v_result->'milestone_rewards', '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.attack_dungeon(TEXT) TO authenticated;
