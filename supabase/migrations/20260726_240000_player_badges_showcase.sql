-- Rozet vitrini SoT: player_badges (inventory'den bağımsız).
-- Kazanılan rozet her zaman vitrinde; envanter silinse bile kalır.

CREATE TABLE IF NOT EXISTS public.player_badges (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id text NOT NULL REFERENCES public.items(id),
  source text NOT NULL DEFAULT 'grant',
  earned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_player_badges_user_earned
  ON public.player_badges (user_id, earned_at DESC);

ALTER TABLE public.player_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS player_badges_select_own ON public.player_badges;
CREATE POLICY player_badges_select_own
  ON public.player_badges FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.record_player_badge(
  p_user_id uuid,
  p_item_id text,
  p_source text DEFAULT 'grant'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF p_user_id IS NULL OR p_item_id IS NULL OR btrim(p_item_id) = '' THEN
    RETURN;
  END IF;
  IF p_item_id NOT LIKE 'badge_%' THEN
    RETURN;
  END IF;

  INSERT INTO public.player_badges (user_id, item_id, source, earned_at)
  VALUES (p_user_id, p_item_id, COALESCE(NULLIF(btrim(p_source), ''), 'grant'), now())
  ON CONFLICT (user_id, item_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.record_player_badge(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_player_badge(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_player_badge(uuid, text, text) TO service_role;

CREATE OR REPLACE FUNCTION public.get_player_badges()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_items jsonb;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Oturum bulunamadı.');
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'item_id', b.item_id,
        'name', COALESCE(i.name, b.item_id),
        'rarity', lower(COALESCE(i.rarity, 'epic')),
        'icon', COALESCE(i.icon, '🏅'),
        'source', b.source,
        'earned_at', b.earned_at
      )
      ORDER BY b.earned_at DESC, b.item_id
    ),
    '[]'::jsonb
  )
  INTO v_items
  FROM public.player_badges b
  LEFT JOIN public.items i ON i.id = b.item_id
  WHERE b.user_id = v_user;

  RETURN jsonb_build_object(
    'success', true,
    'items', v_items,
    'count', jsonb_array_length(v_items)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_player_badges() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_player_badges() TO authenticated;

-- Inventory'ye badge girince de kaydet (eski grant path'leri kapsar).
CREATE OR REPLACE FUNCTION public._trg_inventory_record_badge()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.item_id LIKE 'badge_%' AND NEW.user_id IS NOT NULL THEN
    PERFORM public.record_player_badge(NEW.user_id, NEW.item_id, 'inventory');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_record_badge ON public.inventory;
CREATE TRIGGER trg_inventory_record_badge
  AFTER INSERT ON public.inventory
  FOR EACH ROW
  EXECUTE FUNCTION public._trg_inventory_record_badge();

-- Backfill: mevcut envanter
INSERT INTO public.player_badges (user_id, item_id, source, earned_at)
SELECT DISTINCT ON (inv.user_id, inv.item_id)
  inv.user_id,
  inv.item_id,
  'backfill_inventory',
  COALESCE(inv.created_at, now())
FROM public.inventory inv
WHERE inv.item_id LIKE 'badge_%'
ORDER BY inv.user_id, inv.item_id, COALESCE(inv.created_at, now()) ASC
ON CONFLICT (user_id, item_id) DO NOTHING;

-- Backfill: kodex milestone claims
INSERT INTO public.player_badges (user_id, item_id, source, earned_at)
SELECT
  m.player_id,
  CASE
    WHEN m.threshold = 10 THEN 'badge_codex_bronze'
    WHEN m.threshold = 400 THEN 'badge_codex_gold'
  END,
  'backfill_codex',
  COALESCE(m.claimed_at, now())
FROM public.player_codex_milestones m
WHERE m.claimed_at IS NOT NULL
  AND m.threshold IN (10, 400)
ON CONFLICT (user_id, item_id) DO NOTHING;

-- Backfill: BP L20 free claim → season badge
INSERT INTO public.player_badges (user_id, item_id, source, earned_at)
SELECT
  s.player_id,
  public.ensure_season_badge_item(COALESCE(se.season_number, 1)),
  'backfill_battle_pass',
  COALESCE(s.updated_at, now())
FROM public.bp_player_status s
JOIN public.bp_seasons se ON se.id = s.season_id
WHERE 20 = ANY (s.claimed_normal)
ON CONFLICT (user_id, item_id) DO NOTHING;

-- Patch claim_codex_milestone: record badge; inventory full soft for badges
DO $patch$
DECLARE
  v_def text;
  v_oid oid;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'claim_codex_milestone'
  LIMIT 1;
  IF v_oid IS NULL THEN
    RAISE NOTICE 'claim_codex_milestone missing';
    RETURN;
  END IF;
  v_def := pg_get_functiondef(v_oid);
  v_def := replace(
    v_def,
    $old$v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
      END IF;$old$,
    $new$PERFORM public.record_player_badge(v_user, v_item_id, 'codex');
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      -- Vitrin kaydı inventory'den bağımsız; doluysa envanter kopyası atlanır.$new$
  );
  EXECUTE v_def;
END;
$patch$;

DO $patch_all$
DECLARE
  v_def text;
  v_oid oid;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'claim_all_codex_milestones'
  LIMIT 1;
  IF v_oid IS NULL THEN
    RETURN;
  END IF;
  v_def := pg_get_functiondef(v_oid);
  v_def := replace(
    v_def,
    $old$v_added := public.dungeon_add_item(v_user, v_item_id, 1);
      IF NOT v_added THEN
        RAISE EXCEPTION 'Envanter dolu — rozet verilemedi.';
      END IF;$old$,
    $new$PERFORM public.record_player_badge(v_user, v_item_id, 'codex');
      v_added := public.dungeon_add_item(v_user, v_item_id, 1);$new$
  );
  EXECUTE v_def;
END;
$patch_all$;

DO $patch_bp$
DECLARE
  v_def text;
  v_oid oid;
BEGIN
  SELECT p.oid INTO v_oid
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'bp_claim_reward'
    AND pg_get_function_identity_arguments(p.oid) = 'p_level integer, p_is_vip boolean'
  LIMIT 1;
  IF v_oid IS NULL THEN
    RETURN;
  END IF;
  v_def := pg_get_functiondef(v_oid);
  -- Two identical inventory-full blocks in season + legacy paths.
  v_def := replace(
    v_def,
    $old$IF v_item_id IS NOT NULL THEN
      v_added := public.dungeon_add_item(v_player_id, v_item_id, v_qty);
      IF NOT v_added THEN
        RETURN json_build_object('success', false, 'error', 'Envanter dolu — ödül alınamadı.');
      END IF;
    END IF;$old$,
    $new$IF v_item_id IS NOT NULL THEN
      IF v_item_id LIKE 'badge_%' THEN
        PERFORM public.record_player_badge(v_player_id, v_item_id, 'battle_pass');
      END IF;
      v_added := public.dungeon_add_item(v_player_id, v_item_id, v_qty);
      IF NOT v_added THEN
        IF v_item_id LIKE 'badge_%' THEN
          NULL; -- rozet vitrinde; envanter opsiyonel
        ELSE
          RETURN json_build_object('success', false, 'error', 'Envanter dolu — ödül alınamadı.');
        END IF;
      END IF;
    END IF;$new$
  );
  EXECUTE v_def;
END;
$patch_bp$;
