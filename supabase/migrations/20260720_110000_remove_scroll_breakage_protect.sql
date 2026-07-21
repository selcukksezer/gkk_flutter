-- Upgrade Protection Scroll kaldırıldı — işlev rune_protection (Koruma Rune) ile zaten var.
-- scroll_breakage_protect hiç enhance_item RPC'sine bağlanmamıştı (ölü item).

-- Battle pass VIP ödülünü Koruma Rune'a çevir (Lv16).
UPDATE public.bp_level_rewards
SET
  vip_reward_item_id = 'rune_protection',
  vip_reward_quantity = 1,
  description = 'Level 16 Rewards'
WHERE level = 16
  AND vip_reward_item_id = 'scroll_breakage_protect';

-- Bekleyen craft kuyruğu
DELETE FROM public.craft_queue cq
USING public.crafting_recipes cr
WHERE cq.recipe_id = cr.id
  AND cr.output_item_id = 'scroll_breakage_protect';

-- Craft tarifi
DELETE FROM public.crafting_recipes
WHERE output_item_id = 'scroll_breakage_protect';

-- Pazar / banka / envanter
DELETE FROM public.market_orders WHERE item_id = 'scroll_breakage_protect';
DELETE FROM public.bank_items WHERE item_id = 'scroll_breakage_protect';
DELETE FROM public.inventory WHERE item_id = 'scroll_breakage_protect';

-- Item katalog
DELETE FROM public.items WHERE id = 'scroll_breakage_protect';
