-- Stat inflation Faz 2 (RAPOR 20260731) — applied live as:
--   2026073119xxxx / MCP: stat_inflation_phase2a_enhance_catalog
--   MCP: stat_inflation_phase2b_resync_equip_power
-- Piecewise enhance + mythic catalog compress + set-based resync.

BEGIN;

CREATE OR REPLACE FUNCTION public.enhancement_stat_multiplier(p_enhancement_level integer)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN COALESCE(p_enhancement_level, 0) <= 0 THEN 1.0
    WHEN p_enhancement_level <= 6 THEN 1.0 + (p_enhancement_level * 0.12)
    WHEN p_enhancement_level <= 10 THEN 1.72 + ((p_enhancement_level - 6) * 0.08)
    ELSE 2.04
  END;
$$;

GRANT EXECUTE ON FUNCTION public.enhancement_stat_multiplier(integer) TO authenticated, service_role, anon;

CREATE OR REPLACE FUNCTION public.calculate_item_power(p_item_id text, p_enhancement_level integer)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_item RECORD;
  v_base_stat_sum NUMERIC;
  v_enhancement_mult NUMERIC;
BEGIN
  SELECT * INTO v_item FROM public.items WHERE id = p_item_id;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  v_base_stat_sum := COALESCE(v_item.attack, 0)
                   + COALESCE(v_item.defense, 0)
                   + (COALESCE(v_item.health, 0) / 10.0)
                   + (COALESCE(v_item.luck, 0) * 2.0);

  v_enhancement_mult := public.enhancement_stat_multiplier(COALESCE(p_enhancement_level, 0));
  RETURN v_base_stat_sum * v_enhancement_mult;
END;
$function$;

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
  IF p_auth_id IS NULL THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE auth_id = p_auth_id) THEN RETURN; END IF;

  SELECT
    COALESCE(SUM(floor(COALESCE(it.attack, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.defense, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.health, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::INTEGER,
    COALESCE(SUM(floor(COALESCE(it.luck, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::INTEGER
  INTO v_eq_atk, v_eq_def, v_eq_hp, v_eq_luck
  FROM public.inventory i
  JOIN public.items it ON it.id = i.item_id
  WHERE i.user_id = p_auth_id AND i.is_equipped = TRUE;

  SELECT
    GREATEST(0, COALESCE(attack, 0) - COALESCE(equip_bonus_attack, 0)),
    GREATEST(0, COALESCE(defense, 0) - COALESCE(equip_bonus_defense, 0)),
    GREATEST(1, COALESCE(max_health, 100) - COALESCE(equip_bonus_health, 0)),
    GREATEST(0, COALESCE(luck, 0)),
    COALESCE(health, 0)
  INTO v_base_atk, v_base_def, v_base_hp, v_base_luck, v_cur_health
  FROM public.users WHERE auth_id = p_auth_id FOR UPDATE;

  v_new_atk := v_base_atk + v_eq_atk;
  v_new_def := v_base_def + v_eq_def;
  v_new_hp := v_base_hp + v_eq_hp;
  v_new_luck := v_base_luck;
  v_new_power := public.calculate_user_total_power(p_auth_id);

  UPDATE public.users SET
    attack = v_new_atk, defense = v_new_def, max_health = v_new_hp, luck = v_new_luck,
    health = LEAST(GREATEST(1, v_cur_health), v_new_hp),
    equip_bonus_attack = v_eq_atk, equip_bonus_defense = v_eq_def,
    equip_bonus_health = v_eq_hp, equip_bonus_luck = v_eq_luck,
    power = v_new_power::INTEGER, health_last_updated = NOW(), updated_at = NOW()
  WHERE auth_id = p_auth_id;
END;
$$;

UPDATE public.items
SET
  luck = GREATEST(0, ROUND(COALESCE(luck, 0) * 0.35)::integer),
  health = GREATEST(0, ROUND(COALESCE(health, 0) * 0.40)::integer),
  attack = GREATEST(0, ROUND(COALESCE(attack, 0) * 0.70)::integer),
  defense = GREATEST(0, ROUND(COALESCE(defense, 0) * 0.70)::integer)
WHERE lower(COALESCE(rarity, '')) = 'mythic';

-- Set-based resync (avoid per-row sync loop timeouts on live).
WITH eq AS (
  SELECT
    i.user_id,
    COALESCE(SUM(floor(COALESCE(it.attack, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::integer AS eq_atk,
    COALESCE(SUM(floor(COALESCE(it.defense, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::integer AS eq_def,
    COALESCE(SUM(floor(COALESCE(it.health, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::integer AS eq_hp,
    COALESCE(SUM(floor(COALESCE(it.luck, 0) * public.enhancement_stat_multiplier(COALESCE(i.enhancement_level, 0)))), 0)::integer AS eq_luck
  FROM public.inventory i
  JOIN public.items it ON it.id = i.item_id
  WHERE i.is_equipped = TRUE
  GROUP BY i.user_id
),
base AS (
  SELECT
    u.auth_id,
    GREATEST(0, COALESCE(u.attack, 0) - COALESCE(u.equip_bonus_attack, 0)) AS base_atk,
    GREATEST(0, COALESCE(u.defense, 0) - COALESCE(u.equip_bonus_defense, 0)) AS base_def,
    GREATEST(1, COALESCE(u.max_health, 100) - COALESCE(u.equip_bonus_health, 0)) AS base_hp,
    GREATEST(0, COALESCE(u.luck, 0)) AS base_luck,
    COALESCE(u.health, 0) AS cur_health,
    COALESCE(eq.eq_atk, 0) AS eq_atk,
    COALESCE(eq.eq_def, 0) AS eq_def,
    COALESCE(eq.eq_hp, 0) AS eq_hp,
    COALESCE(eq.eq_luck, 0) AS eq_luck
  FROM public.users u
  LEFT JOIN eq ON eq.user_id = u.auth_id
  WHERE eq.user_id IS NOT NULL
     OR COALESCE(u.equip_bonus_luck, 0) > 0
     OR COALESCE(u.equip_bonus_attack, 0) > 0
     OR COALESCE(u.equip_bonus_defense, 0) > 0
     OR COALESCE(u.equip_bonus_health, 0) > 0
)
UPDATE public.users u
SET
  attack = b.base_atk + b.eq_atk,
  defense = b.base_def + b.eq_def,
  max_health = b.base_hp + b.eq_hp,
  luck = b.base_luck,
  health = LEAST(GREATEST(1, b.cur_health), b.base_hp + b.eq_hp),
  equip_bonus_attack = b.eq_atk,
  equip_bonus_defense = b.eq_def,
  equip_bonus_health = b.eq_hp,
  equip_bonus_luck = b.eq_luck,
  updated_at = NOW()
FROM base b
WHERE u.auth_id = b.auth_id;

UPDATE public.users u
SET
  power = public.calculate_user_total_power(u.auth_id)::integer,
  updated_at = NOW()
WHERE EXISTS (
  SELECT 1 FROM public.inventory i
  WHERE i.user_id = u.auth_id AND i.is_equipped = true
)
OR COALESCE(u.equip_bonus_luck, 0) > 0
OR COALESCE(u.equip_bonus_attack, 0) > 0
OR COALESCE(u.equip_bonus_defense, 0) > 0
OR COALESCE(u.equip_bonus_health, 0) > 0;

COMMIT;
