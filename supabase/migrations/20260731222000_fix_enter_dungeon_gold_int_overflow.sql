-- Fix: late dungeons + high luck → INTEGER overflow ("integer out of range").
-- Root cause:
--   1) enter_dungeon v_gold is INTEGER; uncapped luck gold mult (1 + luck*0.002)
--      with luck~45k on dng_065 → ~2.4B > INT4 max.
--   2) users.gold / dungeon_runs.gold_earned are INTEGER; whales near INT_MAX
--      overflow on gold + reward even with modest payouts.
-- Fix: BIGINT columns + BIGINT v_gold; cap gold/xp luck bonus at +100%.

-- ── Drop gold-dependent triggers (PG blocks ALTER TYPE while attached) ────────
DROP TRIGGER IF EXISTS trg_users_quest_gold ON public.users;
DROP TRIGGER IF EXISTS trg_users_currency_rpc_only ON public.users;

-- ── Widen gold storage ────────────────────────────────────────────────────────
ALTER TABLE public.users
  ALTER COLUMN gold TYPE bigint
  USING gold::bigint;

ALTER TABLE public.dungeon_runs
  ALTER COLUMN gold_earned TYPE bigint
  USING gold_earned::bigint;

-- Quest trigger: clamp delta to INT4 (quest progress API still integer).
CREATE OR REPLACE FUNCTION public.trg_users_quest_gold_fn()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_delta bigint;
BEGIN
  IF NEW.gold > OLD.gold THEN
    v_delta := NEW.gold - OLD.gold;
    PERFORM public.increment_quest_progress(
      NEW.auth_id,
      'earn_gold',
      LEAST(v_delta, 2147483647)::integer
    );
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_users_quest_gold
  AFTER UPDATE OF gold ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_users_quest_gold_fn();

CREATE TRIGGER trg_users_currency_rpc_only
  BEFORE UPDATE OF gems, gold ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_users_currency_via_rpc_only();

-- ── Patch enter_dungeon reward path ───────────────────────────────────────────
DO $patch$
DECLARE
  v_def text;
  v_old_luck text := 'v_gold := floor(v_gold * (1 + v_luck_for_loot * 0.002));';
  v_new_luck text := $n$-- [GKK_DUNGEON_GOLD_BIGINT]
    v_gold := floor(v_gold * (1 + LEAST(1.0, v_luck_for_loot * 0.002)));$n$;
  v_old_xp text := 'v_xp   := floor(v_xp   * (1 + COALESCE(v_player.luck, 0) * 0.001));';
  v_new_xp text := 'v_xp   := floor(v_xp   * (1 + LEAST(1.0, COALESCE(v_player.luck, 0) * 0.001)));';
BEGIN
  SELECT pg_get_functiondef('public.enter_dungeon(uuid, text)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon(uuid, text) not found';
  END IF;

  IF position('[GKK_DUNGEON_GOLD_BIGINT]' in v_def) > 0 THEN
    RAISE NOTICE 'enter_dungeon already gold-bigint patched';
    RETURN;
  END IF;

  IF position('v_gold              INTEGER;' in v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon v_gold INTEGER decl not found — abort patch';
  END IF;

  IF position(v_old_luck in v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon gold-luck assign not found — abort patch';
  END IF;

  v_def := replace(v_def, 'v_gold              INTEGER;', 'v_gold              BIGINT;');
  v_def := replace(v_def, v_old_luck, v_new_luck);

  IF position(v_old_xp in v_def) > 0 THEN
    v_def := replace(v_def, v_old_xp, v_new_xp);
  END IF;

  -- Promote XP temps used in breakdown so farm/monument chain stays BIGINT-safe.
  v_def := replace(v_def, 'v_xp                INTEGER;', 'v_xp                BIGINT;');
  v_def := replace(v_def, 'v_xp_base           INTEGER := 0;', 'v_xp_base           BIGINT := 0;');
  v_def := replace(v_def, 'v_xp_after_luck     INTEGER := 0;', 'v_xp_after_luck     BIGINT := 0;');
  v_def := replace(v_def, 'v_xp_after_farm     INTEGER := 0;', 'v_xp_after_farm     BIGINT := 0;');
  v_def := replace(v_def, 'v_monument_xp_bonus INTEGER := 0;', 'v_monument_xp_bonus BIGINT := 0;');

  EXECUTE v_def;
END;
$patch$;

-- ── attack_dungeon_rl_inner: stop re-casting reward gold to INT4 ───────────────
DO $patch_rl$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef('public.attack_dungeon_rl_inner(text)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'attack_dungeon_rl_inner(text) not found';
  END IF;

  IF position('[GKK_DUNGEON_GOLD_BIGINT_RL]' in v_def) > 0 THEN
    RAISE NOTICE 'attack_dungeon_rl_inner already gold-bigint patched';
    RETURN;
  END IF;

  IF position('(v_result->>''gold_earned'')::INTEGER' in v_def) = 0
     AND position('(v_result->>''gold_earned'')::integer' in v_def) = 0 THEN
    RAISE NOTICE 'attack_dungeon_rl_inner gold_earned INT cast not found — skip';
    RETURN;
  END IF;

  v_def := replace(
    v_def,
    'COALESCE((v_result->>''gold_earned'')::INTEGER, 0)',
    '/* [GKK_DUNGEON_GOLD_BIGINT_RL] */ COALESCE((v_result->>''gold_earned'')::BIGINT, 0)'
  );
  v_def := replace(
    v_def,
    'COALESCE((v_result->>''gold_earned'')::integer, 0)',
    '/* [GKK_DUNGEON_GOLD_BIGINT_RL] */ COALESCE((v_result->>''gold_earned'')::BIGINT, 0)'
  );

  EXECUTE v_def;
END;
$patch_rl$;
