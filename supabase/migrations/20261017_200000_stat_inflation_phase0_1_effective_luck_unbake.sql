-- Stat inflation Faz 0+1 (RAPOR 20260731):
--   Faz 0: effective_player_luck softcap helper + enter_dungeon wiring
--   Faz 1: stop baking equip luck into users.luck; backfill whales
-- users.luck = class + allocate (+ level). equip_bonus_luck = raw gear (loot softcap input).

BEGIN;

-- ---------------------------------------------------------------------------
-- Faz 0: effective luck (base + softcapped equip; hard ≤1500)
-- equip_eff = 500 * (1 - exp(-raw/1000)); asymptote +500 from gear
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.equip_luck_effective(p_equip_luck_raw numeric)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN COALESCE(p_equip_luck_raw, 0) <= 0 THEN 0::numeric
    ELSE 500.0 * (1.0 - exp(-COALESCE(p_equip_luck_raw, 0) / 1000.0))
  END;
$$;

CREATE OR REPLACE FUNCTION public.effective_player_luck(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base numeric := 0;
  v_equip numeric := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT
    COALESCE(luck, 0)::numeric,
    COALESCE(equip_bonus_luck, 0)::numeric
  INTO v_base, v_equip
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- Post-Faz-1: users.luck is base-only; equip_bonus_luck is raw gear sum.
  RETURN LEAST(
    1500.0,
    GREATEST(0, v_base) + public.equip_luck_effective(v_equip)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.equip_luck_effective(numeric) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.effective_player_luck(uuid) TO authenticated, service_role, anon;

-- ---------------------------------------------------------------------------
-- Faz 1: sync — do NOT bake equip luck into users.luck
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_user_equipment_stats(p_auth_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_eq_atk INTEGER := 0;
  v_eq_def INTEGER := 0;
  v_eq_hp INTEGER := 0;
  v_eq_luck INTEGER := 0;
  v_base_atk INTEGER;
  v_base_def INTEGER;
  v_base_hp INTEGER;
  v_base_luck INTEGER;
  v_new_atk INTEGER;
  v_new_def INTEGER;
  v_new_hp INTEGER;
  v_new_luck INTEGER;
  v_cur_health INTEGER;
  v_new_power NUMERIC;
BEGIN
  IF p_auth_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = p_auth_id) THEN
    RETURN;
  END IF;

  SELECT
    COALESCE(SUM(floor(COALESCE(it.attack, 0) * (1.0 + COALESCE(i.enhancement_level, 0) * 0.15))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.defense, 0) * (1.0 + COALESCE(i.enhancement_level, 0) * 0.15))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.health, 0) * (1.0 + COALESCE(i.enhancement_level, 0) * 0.15))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.luck, 0) * (1.0 + COALESCE(i.enhancement_level, 0) * 0.15))), 0)::INTEGER
  INTO v_eq_atk, v_eq_def, v_eq_hp, v_eq_luck
  FROM public.inventory i
  JOIN public.items it ON it.id = i.item_id
  WHERE i.user_id = p_auth_id
    AND i.is_equipped = TRUE;

  SELECT
    GREATEST(0, COALESCE(attack, 0) - COALESCE(equip_bonus_attack, 0)),
    GREATEST(0, COALESCE(defense, 0) - COALESCE(equip_bonus_defense, 0)),
    GREATEST(1, COALESCE(max_health, 100) - COALESCE(equip_bonus_health, 0)),
    -- Luck already base-only after backfill; never subtract equip again.
    GREATEST(0, COALESCE(luck, 0)),
    COALESCE(health, 0)
  INTO v_base_atk, v_base_def, v_base_hp, v_base_luck, v_cur_health
  FROM public.users
  WHERE auth_id = p_auth_id
  FOR UPDATE;

  v_new_atk := v_base_atk + v_eq_atk;
  v_new_def := v_base_def + v_eq_def;
  v_new_hp := v_base_hp + v_eq_hp;
  -- Faz 1: sheet luck = base only (equip tracked separately for farm softcap).
  v_new_luck := v_base_luck;
  v_new_power := public.calculate_user_total_power(p_auth_id);

  UPDATE public.users
  SET
    attack = v_new_atk,
    defense = v_new_def,
    max_health = v_new_hp,
    luck = v_new_luck,
    health = LEAST(GREATEST(1, v_cur_health), v_new_hp),
    equip_bonus_attack = v_eq_atk,
    equip_bonus_defense = v_eq_def,
    equip_bonus_health = v_eq_hp,
    equip_bonus_luck = v_eq_luck,
    power = v_new_power::INTEGER,
    health_last_updated = NOW(),
    updated_at = NOW()
  WHERE auth_id = p_auth_id;
END;
$$;

-- Backfill: strip baked equip luck from users.luck (grandfather 45k → no).
UPDATE public.users
SET
  luck = GREATEST(0, COALESCE(luck, 0) - COALESCE(equip_bonus_luck, 0)),
  updated_at = NOW()
WHERE COALESCE(equip_bonus_luck, 0) > 0
  AND COALESCE(luck, 0) >= COALESCE(equip_bonus_luck, 0);

-- Power: luck column is base-only now — do not subtract equip_bonus_luck.
CREATE OR REPLACE FUNCTION public.calculate_user_total_power(p_user_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
  v_equipment_power NUMERIC := 0;
  v_total_power NUMERIC := 0;
  v_monument_level INT := 0;
  v_stat_mult NUMERIC := 1.0;
  v_base_luck NUMERIC := 0;
BEGIN
  SELECT COALESCE(SUM(public.calculate_item_power(i.item_id, COALESCE(i.enhancement_level, 0))), 0)
  INTO v_equipment_power
  FROM public.inventory i
  WHERE i.user_id = p_user_id AND i.is_equipped = true;

  SELECT
    level,
    reputation,
    attack,
    defense,
    health,
    luck,
    guild_id
  INTO v_user
  FROM public.users
  WHERE auth_id = p_user_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  IF v_user.guild_id IS NOT NULL THEN
    SELECT monument_level INTO v_monument_level
    FROM public.guilds
    WHERE id = v_user.guild_id;
  END IF;

  v_stat_mult := public._monument_stat_multiplier(COALESCE(v_monument_level, 0));

  -- Character-allocated / class luck only. Gear luck lives in calculate_item_power.
  v_base_luck := GREATEST(0, COALESCE(v_user.luck, 0));

  v_total_power := (v_equipment_power * v_stat_mult)
    + (COALESCE(v_user.level, 1) * 500)
    + (COALESCE(v_user.reputation, 0) * 0.1)
    + (v_base_luck * 50 * v_stat_mult);

  RETURN v_total_power;
END;
$$;

-- ---------------------------------------------------------------------------
-- Wire enter_dungeon farm/success/hospital to effective_player_luck
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef('public.enter_dungeon(uuid, text)'::regprocedure)
  INTO v_def;

  IF v_def IS NULL THEN
    RAISE EXCEPTION 'enter_dungeon(uuid, text) not found';
  END IF;

  IF position('public.effective_player_luck(p_player_id)' in v_def) > 0 THEN
    RAISE NOTICE 'enter_dungeon already uses effective_player_luck — skip wire';
    RETURN;
  END IF;

  v_def := replace(
    v_def,
    'v_success_rate := v_success_rate + LEAST(0.05, COALESCE(v_player.luck, 0) * 0.001);',
    'v_success_rate := v_success_rate + LEAST(0.05, public.effective_player_luck(p_player_id) * 0.001);'
  );

  v_def := replace(
    v_def,
    'v_hospital_chance := v_hospital_chance * (1 - LEAST(0.30, COALESCE(v_player.luck, 0) * 0.003));',
    'v_hospital_chance := v_hospital_chance * (1 - LEAST(0.30, public.effective_player_luck(p_player_id) * 0.003));'
  );

  v_def := replace(
    v_def,
    'v_luck_for_loot := COALESCE(v_player.luck, 0) + public._monument_loot_luck_bonus(v_monument_level) + public._codex_luck_bonus_raw(p_player_id);',
    'v_luck_for_loot := public.effective_player_luck(p_player_id) + public._monument_loot_luck_bonus(v_monument_level) + public._codex_luck_bonus_raw(p_player_id);'
  );

  v_def := replace(
    v_def,
    'v_xp   := floor(v_xp   * (1 + LEAST(1.0, COALESCE(v_player.luck, 0) * 0.001)));',
    'v_xp   := floor(v_xp   * (1 + LEAST(1.0, public.effective_player_luck(p_player_id) * 0.001)));'
  );

  v_def := replace(
    v_def,
    'v_xp_luck_mult := (1 + COALESCE(v_player.luck, 0) * 0.001);',
    'v_xp_luck_mult := (1 + LEAST(1.0, public.effective_player_luck(p_player_id) * 0.001));'
  );

  -- Fallback power path: base luck *50 (users.luck no longer includes equip).
  -- Leave as v_player.luck * 50 — correct post-unbake.

  IF position('public.effective_player_luck(p_player_id)' in v_def) = 0 THEN
    RAISE EXCEPTION 'enter_dungeon effective_player_luck wire failed — abort';
  END IF;

  EXECUTE v_def;
  RAISE NOTICE 'enter_dungeon wired to effective_player_luck';
END $$;

-- Refresh cached power after luck unbake (power formula unchanged for whales).
UPDATE public.users u
SET
  power = public.calculate_user_total_power(u.auth_id)::integer,
  updated_at = NOW()
WHERE EXISTS (
  SELECT 1
  FROM public.inventory i
  WHERE i.user_id = u.auth_id
    AND i.is_equipped = true
)
OR COALESCE(u.equip_bonus_luck, 0) > 0
OR COALESCE(u.equip_bonus_attack, 0) > 0
OR COALESCE(u.equip_bonus_defense, 0) > 0
OR COALESCE(u.equip_bonus_health, 0) > 0;

COMMIT;
