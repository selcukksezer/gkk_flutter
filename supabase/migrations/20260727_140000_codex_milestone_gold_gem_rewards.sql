-- Codex milestones: meaningful gold (early) + gems (late) rewards.
BEGIN;

CREATE OR REPLACE FUNCTION public._codex_milestone_reward_config(p_threshold INTEGER)
RETURNS TABLE (
  gold_amount BIGINT,
  gem_amount INT,
  reward_label TEXT,
  reward_kind TEXT
)
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT t.gold_amount, t.gem_amount, t.reward_label, t.reward_kind
  FROM (VALUES
    (10,  200000::BIGINT, 0,  '200.000 Altın',                    'gold'),
    (25,  500000::BIGINT, 0,  '500.000 Altın',                    'gold'),
    (50,  0::BIGINT,       5,  '5 Elmas + kalıcı +1 loot şansı', 'gems'),
    (100, 1000000::BIGINT, 15, '1M Altın + 15 Elmas + rozet',    'mixed')
  ) AS t(threshold, gold_amount, gem_amount, reward_label, reward_kind)
  WHERE t.threshold = p_threshold;
$$;

CREATE OR REPLACE FUNCTION public.get_codex_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_discovered INT;
  v_total INT;
  v_new_24h INT;
  v_claimable INT;
  v_milestones JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT COUNT(*) INTO v_total FROM public.codex_catalog;
  v_discovered := public._codex_discovered_count(v_user);

  SELECT COUNT(*) INTO v_new_24h
  FROM public.player_codex_entries
  WHERE player_id = v_user AND discovered_at >= now() - interval '24 hours';

  SELECT COUNT(*) INTO v_claimable
  FROM (VALUES (10), (25), (50), (100)) AS t(th)
  WHERE v_discovered >= t.th
    AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = t.th AND m.claimed_at IS NOT NULL
    );

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'threshold', t.th,
    'claimed', EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = t.th AND m.claimed_at IS NOT NULL
    ),
    'claimable', v_discovered >= t.th AND NOT EXISTS (
      SELECT 1 FROM public.player_codex_milestones m
      WHERE m.player_id = v_user AND m.threshold = t.th AND m.claimed_at IS NOT NULL
    ),
    'reward_gold', cfg.gold_amount,
    'reward_gems', cfg.gem_amount,
    'reward_label', cfg.reward_label,
    'reward_kind', cfg.reward_kind
  ) ORDER BY t.th), '[]'::JSONB)
  INTO v_milestones
  FROM (VALUES (10), (25), (50), (100)) AS t(th)
  JOIN LATERAL public._codex_milestone_reward_config(t.th) cfg ON TRUE;

  RETURN jsonb_build_object(
    'success', true,
    'discovered', v_discovered,
    'total', v_total,
    'new_entries_24h', v_new_24h,
    'claimable_milestones', v_claimable,
    'luck_bonus', public.get_codex_luck_bonus(v_user),
    'milestones', v_milestones
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_codex_milestone(p_threshold INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_discovered INT;
  v_item_id TEXT;
  v_added BOOLEAN;
  v_gold BIGINT := 0;
  v_gems INT := 0;
  v_reward_label TEXT;
  v_reward_kind TEXT;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  IF p_threshold NOT IN (10, 25, 50, 100) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşik.');
  END IF;

  v_discovered := public._codex_discovered_count(v_user);
  IF v_discovered < p_threshold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Henüz yeterli keşif yok.');
  END IF;

  SELECT cfg.gold_amount, cfg.gem_amount, cfg.reward_label, cfg.reward_kind
  INTO v_gold, v_gems, v_reward_label, v_reward_kind
  FROM public._codex_milestone_reward_config(p_threshold) cfg;

  INSERT INTO public.player_codex_milestones (player_id, threshold, claimed_at)
  VALUES (v_user, p_threshold, now())
  ON CONFLICT (player_id, threshold) DO UPDATE SET claimed_at = COALESCE(player_codex_milestones.claimed_at, now())
  WHERE player_codex_milestones.claimed_at IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül zaten alındı.');
  END IF;

  IF v_gold > 0 OR v_gems > 0 THEN
    UPDATE public.users
    SET
      gold = gold + v_gold,
      gems = gems + v_gems
    WHERE auth_id = v_user;
  END IF;

  IF p_threshold IN (10, 100) THEN
    v_item_id := public.ensure_codex_badge_item(CASE WHEN p_threshold = 10 THEN 'bronze' ELSE 'gold' END);
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RETURN jsonb_build_object('success', false, 'error', 'Envanter dolu — rozet verilemedi.');
      END IF;
    END IF;
  END IF;

  IF p_threshold = 100 THEN
    UPDATE public.users
    SET cosmetic_title = COALESCE(cosmetic_title, 'kodex_ustasi')
    WHERE auth_id = v_user
      AND (cosmetic_title IS NULL OR cosmetic_title = '');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'threshold', p_threshold,
    'reward_gold', v_gold,
    'reward_gems', v_gems,
    'reward_label', v_reward_label,
    'reward_kind', v_reward_kind,
    'milestone_label', v_reward_label,
    'item_id', v_item_id,
    'cosmetic_title', CASE WHEN p_threshold = 100 THEN 'kodex_ustasi' ELSE NULL END
  );
END;
$$;

COMMIT;
