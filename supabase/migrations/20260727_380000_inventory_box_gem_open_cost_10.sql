-- Envanter odul kutulari: gem ile acma maliyeti 10 elmas + client preview RPC

BEGIN;

UPDATE public.loot_box_configs
SET
  price = 10,
  updated_at = now()
WHERE id IN (
  'box_weapon_common',
  'box_weapon_rare',
  'box_weapon_legendary',
  'box_armor_rare',
  'box_armor_epic',
  'box_jewelry_rare',
  'box_jewelry_epic'
);

CREATE OR REPLACE FUNCTION public.get_inventory_box_gem_cost(p_box_id text)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT GREATEST(
    COALESCE(
      (SELECT price FROM public.loot_box_configs WHERE id = p_box_id),
      10
    ),
    1
  )::integer;
$$;

GRANT EXECUTE ON FUNCTION public.get_inventory_box_gem_cost(text) TO authenticated;

COMMIT;
