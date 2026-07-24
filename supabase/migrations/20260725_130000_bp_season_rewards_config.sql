-- Battle Pass: per-season configurable reward catalog + shop showcase RPC
-- Edit rows in bp_season_rewards from Supabase Table Editor per season.

-- ── 1. Season-scoped reward catalog ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bp_season_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id uuid NOT NULL REFERENCES public.bp_seasons(id) ON DELETE CASCADE,
  track text NOT NULL CHECK (track IN ('free', 'vip')),
  level integer NOT NULL CHECK (level BETWEEN 1 AND 20),
  reward_type text NOT NULL DEFAULT 'mixed'
    CHECK (reward_type IN ('gold', 'gems', 'item', 'cosmetic', 'mixed', 'bpp')),
  reward_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  item_id text REFERENCES public.items(id),
  display_name text,
  display_rarity text,
  sort_order integer NOT NULL DEFAULT 0,
  is_featured boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (season_id, track, level)
);

CREATE INDEX IF NOT EXISTS idx_bp_season_rewards_season_track
  ON public.bp_season_rewards (season_id, track, level);

CREATE INDEX IF NOT EXISTS idx_bp_season_rewards_featured
  ON public.bp_season_rewards (season_id, is_featured)
  WHERE is_featured = true AND is_active = true;

ALTER TABLE public.bp_season_rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view season rewards"
  ON public.bp_season_rewards FOR SELECT USING (true);

-- ── 2. Seed current bp_level_rewards into every existing season ─────────────
INSERT INTO public.bp_season_rewards (
  season_id, track, level, reward_type, reward_value, item_id,
  display_name, display_rarity, sort_order, is_featured, is_active
)
SELECT
  s.id,
  'free',
  r.level,
  CASE
    WHEN r.normal_reward_item_id IS NOT NULL AND r.normal_reward_gold > 0 THEN 'mixed'
    WHEN r.normal_reward_item_id IS NOT NULL THEN 'item'
    WHEN r.normal_reward_gold > 0 THEN 'gold'
    ELSE 'mixed'
  END,
  jsonb_build_object(
    'gold', COALESCE(r.normal_reward_gold, 0),
    'gems', 0,
    'quantity', COALESCE(r.normal_reward_quantity, 1)
  ),
  CASE WHEN r.level = 20 THEN NULL ELSE r.normal_reward_item_id END,
  CASE
    WHEN r.level = 20 THEN 'Sezon Rozeti'
    ELSE COALESCE(i.name, CASE WHEN r.normal_reward_gold > 0 THEN r.normal_reward_gold || ' Altın' ELSE 'Ödül' END)
  END,
  COALESCE(i.rarity, CASE WHEN r.level = 20 THEN 'epic' WHEN r.normal_reward_gold >= 200000 THEN 'rare' ELSE 'common' END),
  r.level * 10,
  r.level IN (10, 15, 20),
  true
FROM public.bp_seasons s
CROSS JOIN public.bp_level_rewards r
LEFT JOIN public.items i ON i.id = r.normal_reward_item_id
ON CONFLICT (season_id, track, level) DO NOTHING;

INSERT INTO public.bp_season_rewards (
  season_id, track, level, reward_type, reward_value, item_id,
  display_name, display_rarity, sort_order, is_featured, is_active
)
SELECT
  s.id,
  'vip',
  r.level,
  CASE
    WHEN r.vip_reward_item_id IS NOT NULL AND r.vip_reward_gold > 0 THEN 'mixed'
    WHEN r.vip_reward_item_id IS NOT NULL THEN 'item'
    WHEN r.vip_reward_gold > 0 THEN 'gold'
    ELSE 'mixed'
  END,
  jsonb_build_object(
    'gold', COALESCE(r.vip_reward_gold, 0),
    'gems', 0,
    'quantity', COALESCE(r.vip_reward_quantity, 1)
  ),
  r.vip_reward_item_id,
  COALESCE(
    i.name,
    CASE WHEN r.vip_reward_gold > 0 THEN r.vip_reward_gold || ' Altın' ELSE 'VIP Ödül' END
  ),
  COALESCE(i.rarity, CASE WHEN r.vip_reward_gold >= 200000 THEN 'rare' ELSE 'common' END),
  r.level * 10 + 1,
  r.level IN (10, 15, 20),
  true
FROM public.bp_seasons s
CROSS JOIN public.bp_level_rewards r
LEFT JOIN public.items i ON i.id = r.vip_reward_item_id
ON CONFLICT (season_id, track, level) DO NOTHING;

-- ── 3. Helper: resolve one season reward row ────────────────────────────────
CREATE OR REPLACE FUNCTION public.bp_resolve_season_reward(
  p_season_id uuid,
  p_track text,
  p_level integer
)
RETURNS public.bp_season_rewards
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT sr.*
  FROM public.bp_season_rewards sr
  WHERE sr.season_id = p_season_id
    AND sr.track = p_track
    AND sr.level = p_level
    AND sr.is_active = true
  LIMIT 1;
$$;

-- ── 4. RPC: fetch season rewards for UI ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_battle_pass_season_rewards(p_season_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_season_id uuid := p_season_id;
  v_season_number integer;
  v_rows jsonb;
  v_featured_free jsonb;
  v_featured_vip jsonb;
BEGIN
  IF v_season_id IS NULL THEN
    SELECT id, season_number INTO v_season_id, v_season_number
    FROM public.bp_seasons
    WHERE is_active = true
    ORDER BY start_at DESC
    LIMIT 1;
  ELSE
    SELECT season_number INTO v_season_number
    FROM public.bp_seasons
    WHERE id = v_season_id;
  END IF;

  IF v_season_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Aktif sezon bulunamadı.');
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.level), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      lvl.level,
      (
        SELECT jsonb_build_object(
          'id', f.id,
          'track', f.track,
          'level', f.level,
          'reward_type', f.reward_type,
          'reward_value', f.reward_value,
          'item_id', f.item_id,
          'display_name', f.display_name,
          'display_rarity', f.display_rarity,
          'is_featured', f.is_featured,
          'item_name', i.name,
          'item_rarity', i.rarity,
          'item_icon', i.icon
        )
        FROM public.bp_season_rewards f
        LEFT JOIN public.items i ON i.id = f.item_id
        WHERE f.season_id = v_season_id AND f.track = 'free' AND f.level = lvl.level AND f.is_active
      ) AS free_reward,
      (
        SELECT jsonb_build_object(
          'id', v.id,
          'track', v.track,
          'level', v.level,
          'reward_type', v.reward_type,
          'reward_value', v.reward_value,
          'item_id', v.item_id,
          'display_name', v.display_name,
          'display_rarity', v.display_rarity,
          'is_featured', v.is_featured,
          'item_name', i.name,
          'item_rarity', i.rarity,
          'item_icon', i.icon
        )
        FROM public.bp_season_rewards v
        LEFT JOIN public.items i ON i.id = v.item_id
        WHERE v.season_id = v_season_id AND v.track = 'vip' AND v.level = lvl.level AND v.is_active
      ) AS vip_reward
    FROM generate_series(1, 20) AS lvl(level)
  ) t;

  SELECT COALESCE(jsonb_agg(row_to_json(x)::jsonb ORDER BY x.level DESC), '[]'::jsonb)
  INTO v_featured_free
  FROM (
    SELECT sr.level, sr.display_name, sr.display_rarity, sr.item_id, sr.reward_value,
           sr.reward_type, i.name AS item_name, i.rarity AS item_rarity, i.icon AS item_icon
    FROM public.bp_season_rewards sr
    LEFT JOIN public.items i ON i.id = sr.item_id
    WHERE sr.season_id = v_season_id AND sr.track = 'free' AND sr.is_featured AND sr.is_active
    ORDER BY sr.level DESC
    LIMIT 3
  ) x;

  SELECT COALESCE(jsonb_agg(row_to_json(x)::jsonb ORDER BY x.level DESC), '[]'::jsonb)
  INTO v_featured_vip
  FROM (
    SELECT sr.level, sr.display_name, sr.display_rarity, sr.item_id, sr.reward_value,
           sr.reward_type, i.name AS item_name, i.rarity AS item_rarity, i.icon AS item_icon
    FROM public.bp_season_rewards sr
    LEFT JOIN public.items i ON i.id = sr.item_id
    WHERE sr.season_id = v_season_id AND sr.track = 'vip' AND sr.is_featured AND sr.is_active
    ORDER BY sr.level DESC
    LIMIT 3
  ) x;

  RETURN jsonb_build_object(
    'success', true,
    'season_id', v_season_id,
    'season_number', v_season_number,
    'levels', v_rows,
    'featured_free', v_featured_free,
    'featured_vip', v_featured_vip
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_battle_pass_season_rewards(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_battle_pass_season_rewards(uuid) TO anon;

-- ── 5. bp_claim_reward reads season config first ────────────────────────────
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
  v_season_reward public.bp_season_rewards;
  v_track text;
  v_item_id text;
  v_qty integer;
  v_gold integer;
  v_gems integer;
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

  v_track := CASE WHEN p_is_vip THEN 'vip' ELSE 'free' END;
  SELECT * INTO v_season_reward
  FROM public.bp_resolve_season_reward(v_active_season_id, v_track, p_level);

  IF v_season_reward.id IS NOT NULL THEN
    v_gold := COALESCE((v_season_reward.reward_value->>'gold')::integer, 0);
    v_gems := COALESCE((v_season_reward.reward_value->>'gems')::integer, 0);
    v_qty := COALESCE((v_season_reward.reward_value->>'quantity')::integer, 1);

    IF v_gold > 0 THEN
      UPDATE public.users SET gold = gold + v_gold WHERE auth_id = v_player_id;
    END IF;
    IF v_gems > 0 THEN
      UPDATE public.users SET gems = gems + v_gems WHERE auth_id = v_player_id;
    END IF;

    IF NOT p_is_vip AND p_level = 20 THEN
      v_item_id := public.ensure_season_badge_item(v_season_number);
    ELSE
      v_item_id := v_season_reward.item_id;
    END IF;

    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_player_id, v_item_id, v_qty);
      IF NOT v_added THEN
        RETURN json_build_object('success', false, 'error', 'Envanter dolu — ödül alınamadı.');
      END IF;
    END IF;
  ELSE
    -- Legacy fallback: bp_level_rewards
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
    END IF;

    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_player_id, v_item_id, v_qty);
      IF NOT v_added THEN
        RETURN json_build_object('success', false, 'error', 'Envanter dolu — ödül alınamadı.');
      END IF;
    END IF;
  END IF;

  IF p_is_vip THEN
    UPDATE public.bp_player_status
    SET claimed_vip = array_append(claimed_vip, p_level), updated_at = now()
    WHERE player_id = v_player_id AND season_id = v_active_season_id;
  ELSE
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
