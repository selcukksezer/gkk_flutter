-- Strip already-equipped gear where required_level > users.level,
-- then resync equipment stats + power for affected / equipped users.

BEGIN;

UPDATE public.inventory AS i
SET
  is_equipped = false,
  equip_slot = NULL
FROM public.items AS it,
     public.users AS u
WHERE i.item_id = it.id
  AND i.user_id = u.auth_id
  AND i.is_equipped = true
  AND COALESCE(it.required_level, 1) > COALESCE(u.level, 1);

-- Resync stats/power for anyone with equipment or leftover equip_bonus_*.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT DISTINCT u.auth_id
    FROM public.users u
    WHERE EXISTS (
      SELECT 1
      FROM public.inventory i
      WHERE i.user_id = u.auth_id
        AND i.is_equipped = true
    )
    OR COALESCE(u.equip_bonus_luck, 0) > 0
    OR COALESCE(u.equip_bonus_attack, 0) > 0
    OR COALESCE(u.equip_bonus_defense, 0) > 0
    OR COALESCE(u.equip_bonus_health, 0) > 0
  LOOP
    PERFORM public.sync_user_equipment_stats(r.auth_id);
  END LOOP;
END;
$$;

-- Final power pass (sync updates power; recalculate after strip for safety).
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
OR COALESCE(u.equip_bonus_health, 0) > 0
OR u.username IN ('theking', 'gercek1');

COMMIT;
