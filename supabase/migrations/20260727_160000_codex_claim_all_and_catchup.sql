-- Codex claim-all + grant tracking + catch-up for pre-gold claims.
-- Root cause: claims before gold migration paid 0; 25→20 remap blocks re-claim;
-- button said "N ödül" but client only claimed 1.

BEGIN;

ALTER TABLE public.player_codex_milestones
  ADD COLUMN IF NOT EXISTS gold_granted BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gems_granted INTEGER NOT NULL DEFAULT 0;

-- ── Single claim: record grants, badge fail rolls back via exception ───────────
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

  IF p_threshold NOT IN (
    10, 20, 30, 40, 50, 75, 100, 125, 150, 200, 250, 300, 350, 400
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz eşik.');
  END IF;

  v_discovered := public._codex_discovered_count(v_user);
  IF v_discovered < p_threshold THEN
    RETURN jsonb_build_object('success', false, 'error', 'Henüz yeterli keşif yok.');
  END IF;

  SELECT cfg.gold_amount, cfg.gem_amount, cfg.reward_label, cfg.reward_kind
  INTO v_gold, v_gems, v_reward_label, v_reward_kind
  FROM public._codex_milestone_reward_config(p_threshold) cfg;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ödül yapılandırması yok.');
  END IF;

  INSERT INTO public.player_codex_milestones (
    player_id, threshold, claimed_at, gold_granted, gems_granted
  )
  VALUES (v_user, p_threshold, now(), COALESCE(v_gold, 0), COALESCE(v_gems, 0))
  ON CONFLICT (player_id, threshold) DO UPDATE
    SET
      claimed_at = COALESCE(player_codex_milestones.claimed_at, now()),
      gold_granted = CASE
        WHEN player_codex_milestones.claimed_at IS NULL
          THEN COALESCE(v_gold, 0)
        ELSE player_codex_milestones.gold_granted
      END,
      gems_granted = CASE
        WHEN player_codex_milestones.claimed_at IS NULL
          THEN COALESCE(v_gems, 0)
        ELSE player_codex_milestones.gems_granted
      END
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

  IF p_threshold = 10 THEN
    v_item_id := public.ensure_codex_badge_item('bronze');
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
      END IF;
    END IF;
  END IF;

  IF p_threshold = 400 THEN
    v_item_id := public.ensure_codex_badge_item('gold');
    IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
      END IF;
    END IF;

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
    'cosmetic_title', CASE WHEN p_threshold = 400 THEN 'kodex_ustasi' ELSE NULL END
  );
END;
$$;

-- ── Claim ALL pending milestones in one transaction ───────────────────────────
CREATE OR REPLACE FUNCTION public.claim_all_codex_milestones()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_discovered INT;
  v_th INT;
  v_gold BIGINT;
  v_gems INT;
  v_label TEXT;
  v_kind TEXT;
  v_item_id TEXT;
  v_added BOOLEAN;
  v_total_gold BIGINT := 0;
  v_total_gems INT := 0;
  v_count INT := 0;
  v_claimed JSONB := '[]'::JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  v_discovered := public._codex_discovered_count(v_user);

  FOR v_th IN
    SELECT th FROM public._codex_milestone_thresholds() AS th
    WHERE v_discovered >= th
      AND NOT EXISTS (
        SELECT 1 FROM public.player_codex_milestones m
        WHERE m.player_id = v_user
          AND m.threshold = th
          AND m.claimed_at IS NOT NULL
      )
    ORDER BY th
  LOOP
    SELECT cfg.gold_amount, cfg.gem_amount, cfg.reward_label, cfg.reward_kind
    INTO v_gold, v_gems, v_label, v_kind
    FROM public._codex_milestone_reward_config(v_th) cfg;

    INSERT INTO public.player_codex_milestones (
      player_id, threshold, claimed_at, gold_granted, gems_granted
    )
    VALUES (v_user, v_th, now(), COALESCE(v_gold, 0), COALESCE(v_gems, 0))
    ON CONFLICT (player_id, threshold) DO UPDATE
      SET
        claimed_at = COALESCE(player_codex_milestones.claimed_at, now()),
        gold_granted = CASE
          WHEN player_codex_milestones.claimed_at IS NULL
            THEN COALESCE(v_gold, 0)
          ELSE player_codex_milestones.gold_granted
        END,
        gems_granted = CASE
          WHEN player_codex_milestones.claimed_at IS NULL
            THEN COALESCE(v_gems, 0)
          ELSE player_codex_milestones.gems_granted
        END
    WHERE player_codex_milestones.claimed_at IS NULL;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    IF v_gold > 0 OR v_gems > 0 THEN
      UPDATE public.users
      SET
        gold = gold + v_gold,
        gems = gems + v_gems
      WHERE auth_id = v_user;
    END IF;

    IF v_th = 10 THEN
      v_item_id := public.ensure_codex_badge_item('bronze');
      IF v_item_id IS NOT NULL THEN
        v_added := public.dungeon_add_item(v_user, v_item_id, 1);
        IF NOT v_added THEN
          RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
        END IF;
      END IF;
    END IF;

    IF v_th = 400 THEN
      v_item_id := public.ensure_codex_badge_item('gold');
      IF v_item_id IS NOT NULL THEN
        v_added := public.dungeon_add_item(v_user, v_item_id, 1);
        IF NOT v_added THEN
          RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
        END IF;
      END IF;

      UPDATE public.users
      SET cosmetic_title = COALESCE(cosmetic_title, 'kodex_ustasi')
      WHERE auth_id = v_user
        AND (cosmetic_title IS NULL OR cosmetic_title = '');
    END IF;

    v_total_gold := v_total_gold + COALESCE(v_gold, 0);
    v_total_gems := v_total_gems + COALESCE(v_gems, 0);
    v_count := v_count + 1;
    v_claimed := v_claimed || jsonb_build_array(jsonb_build_object(
      'threshold', v_th,
      'reward_gold', v_gold,
      'reward_gems', v_gems,
      'reward_label', v_label
    ));
  END LOOP;

  IF v_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Alınacak ödül yok.');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'claimed_count', v_count,
    'reward_gold', v_total_gold,
    'reward_gems', v_total_gems,
    'reward_label', v_count::text || ' ödül',
    'claimed', v_claimed
  );
END;
$$;

-- ── Catch-up: pre-gold-migration claims paid 0 but now show new ladder ────────
-- Gold migration applied ~2026-07-24 19:22:40 UTC (remote version 20260724192240).
DO $$
DECLARE
  r RECORD;
  v_pay_gold BIGINT;
  v_pay_gems INT;
BEGIN
  FOR r IN
    SELECT
      m.player_id,
      m.threshold,
      cfg.gold_amount,
      cfg.gem_amount
    FROM public.player_codex_milestones m
    JOIN LATERAL public._codex_milestone_reward_config(m.threshold) cfg ON TRUE
    WHERE m.claimed_at IS NOT NULL
      AND m.claimed_at < TIMESTAMPTZ '2026-07-24 19:22:40+00'
      AND COALESCE(m.gold_granted, 0) = 0
      AND COALESCE(m.gems_granted, 0) = 0
      AND (cfg.gold_amount > 0 OR cfg.gem_amount > 0)
  LOOP
    v_pay_gold := COALESCE(r.gold_amount, 0);
    v_pay_gems := COALESCE(r.gem_amount, 0);

    UPDATE public.users
    SET
      gold = gold + v_pay_gold,
      gems = gems + v_pay_gems
    WHERE auth_id = r.player_id;

    UPDATE public.player_codex_milestones
    SET
      gold_granted = v_pay_gold,
      gems_granted = v_pay_gems
    WHERE player_id = r.player_id
      AND threshold = r.threshold;
  END LOOP;

  -- Mark post-gold claims as granted (already paid at claim time; no double pay).
  UPDATE public.player_codex_milestones m
  SET
    gold_granted = COALESCE(
      (SELECT c.gold_amount FROM public._codex_milestone_reward_config(m.threshold) c),
      0
    ),
    gems_granted = COALESCE(
      (SELECT c.gem_amount FROM public._codex_milestone_reward_config(m.threshold) c),
      0
    )
  WHERE m.claimed_at IS NOT NULL
    AND m.claimed_at >= TIMESTAMPTZ '2026-07-24 19:22:40+00'
    AND COALESCE(m.gold_granted, 0) = 0
    AND COALESCE(m.gems_granted, 0) = 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.claim_codex_milestone(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_all_codex_milestones() TO authenticated;

COMMIT;
