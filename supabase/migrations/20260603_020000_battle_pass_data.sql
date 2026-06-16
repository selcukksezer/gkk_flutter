-- Missing Items for Battle Pass Rewards

-- Detox Potions
INSERT INTO public.items (id, name, type, description, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable)
VALUES 
('detox_minor', 'Minor Detox Potion', 'potion', 'Cleanses minor toxicity and reduces tolerance.', 'common', 500, 100, true, true),
('detox_major', 'Major Detox Potion', 'potion', 'Cleanses significant toxicity and reduces tolerance.', 'rare', 2000, 400, true, true),
('detox_supreme', 'Supreme Detox Potion', 'potion', 'Immediately resets toxicity and tolerance to zero.', 'epic', 10000, 2000, true, true)
ON CONFLICT (id) DO NOTHING;

-- Protection Scrolls
INSERT INTO public.items (id, name, type, description, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable)
VALUES 
('scroll_breakage_protect', 'Upgrade Protection Scroll', 'scroll', 'Prevents item breakage during a failed upgrade attempt.', 'rare', 50000, 5000, true, true)
ON CONFLICT (id) DO NOTHING;

-- Reward Boxes
INSERT INTO public.items (id, name, type, description, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable)
VALUES 
('box_weapon_common', 'Common Weapon Box', 'consumable', 'Contains a random common weapon.', 'common', 1000, 200, true, false),
('box_weapon_rare', 'Rare Weapon Box', 'consumable', 'Contains a random rare weapon.', 'rare', 5000, 1000, true, false),
('box_weapon_legendary', 'Legendary Weapon Box', 'consumable', 'Contains a random legendary weapon.', 'legendary', 100000, 20000, true, false),
('box_armor_rare', 'Rare Armor Box', 'consumable', 'Contains a random rare armor piece.', 'rare', 5000, 1000, true, false),
('box_armor_epic', 'Epic Armor Box', 'consumable', 'Contains a random epic armor piece.', 'epic', 25000, 5000, true, false),
('box_jewelry_rare', 'Rare Jewelry Box', 'consumable', 'Contains a random rare jewelry piece.', 'rare', 5000, 1000, true, false),
('box_jewelry_epic', 'Epic Jewelry Box', 'consumable', 'Contains a random epic jewelry piece.', 'epic', 25000, 5000, true, false)
ON CONFLICT (id) DO NOTHING;

-- Permanent Season Badge (Cosmetic)
INSERT INTO public.items (id, name, type, description, rarity, base_price, vendor_sell_price, is_tradeable, is_stackable)
VALUES 
('badge_season_01', 'Season 1 Veteran Badge', 'cosmetic', 'A permanent badge for completing Season 1.', 'epic', 0, 0, false, false)
ON CONFLICT (id) DO NOTHING;

-- 2. Populate BP Level Rewards
INSERT INTO public.bp_level_rewards (level, normal_reward_item_id, normal_reward_quantity, normal_reward_gold, vip_reward_item_id, vip_reward_quantity, vip_reward_gold, description)
VALUES 
(1, 'scroll_upgrade_low', 5, 20000, 'scroll_upgrade_low', 10, 50000, 'Level 1 Rewards'),
(2, 'res_mining_common', 30, 0, 'potion_energy_minor', 5, 0, 'Level 2 Rewards'),
(3, 'potion_health_minor', 10, 0, NULL, 0, 100000, 'Level 3 Rewards'),
(4, 'catalyst_common', 3, 0, 'catalyst_uncommon', 3, 0, 'Level 4 Rewards'),
(5, 'box_weapon_common', 1, 0, 'box_weapon_rare', 1, 0, 'Level 5 Rewards'),
(6, NULL, 0, 50000, 'scroll_upgrade_middle', 3, 0, 'Level 6 Rewards'),
(7, 'res_lumber_uncommon', 20, 0, 'detox_minor', 3, 0, 'Level 7 Rewards'),
(8, 'potion_luck_buff', 2, 0, 'potion_energy_major', 3, 0, 'Level 8 Rewards'),
(9, 'res_quarry_rare', 10, 0, 'catalyst_rare', 2, 0, 'Level 9 Rewards'),
(10, 'box_armor_rare', 1, 0, 'box_armor_epic', 1, 0, 'Level 10 Rewards'),
(11, NULL, 0, 100000, 'potion_attack_buff', 3, 0, 'Level 11 Rewards'),
(12, 'res_mining_rare', 15, 0, 'scroll_upgrade_high', 1, 0, 'Level 12 Rewards'),
(13, 'potion_health_major', 5, 0, NULL, 0, 250000, 'Level 13 Rewards'),
(14, 'catalyst_epic', 1, 0, 'detox_major', 2, 0, 'Level 14 Rewards'),
(15, 'box_jewelry_rare', 1, 0, 'box_jewelry_epic', 1, 0, 'Level 15 Rewards'),
(16, NULL, 0, 150000, 'scroll_breakage_protect', 1, 0, 'Level 16 Rewards'),
(17, 'potion_xp_buff', 2, 0, 'potion_energy_supreme', 2, 0, 'Level 17 Rewards'),
(18, 'res_mining_epic', 5, 0, 'catalyst_legendary', 1, 0, 'Level 18 Rewards'),
(19, NULL, 0, 250000, 'detox_supreme', 1, 0, 'Level 19 Rewards'),
(20, 'badge_season_01', 1, 0, 'box_weapon_legendary', 1, 0, 'Level 20 Rewards')
ON CONFLICT (level) DO UPDATE SET
  normal_reward_item_id = EXCLUDED.normal_reward_item_id,
  normal_reward_quantity = EXCLUDED.normal_reward_quantity,
  normal_reward_gold = EXCLUDED.normal_reward_gold,
  vip_reward_item_id = EXCLUDED.vip_reward_item_id,
  vip_reward_quantity = EXCLUDED.vip_reward_quantity,
  vip_reward_gold = EXCLUDED.vip_reward_gold;

-- 3. Static Quest Templates
INSERT INTO public.bp_quest_templates (quest_type, target_system, target_count, bpp_reward, description)
VALUES 
('daily', 'dungeon', 3, 400, 'Complete 3 dungeon runs'),
('daily', 'pvp', 2, 400, 'Complete 2 PvP matches'),
('daily', 'craft', 5, 400, 'Successfully craft 5 items'),
('weekly', 'dungeon', 20, 3000, 'Weekly: Complete 20 dungeon runs'),
('weekly', 'pvp', 15, 3000, 'Weekly: Complete 15 PvP matches'),
('weekly', 'craft', 50, 3000, 'Weekly: Successfully craft 50 items'),
('weekly', 'potion', 100, 3000, 'Weekly: Consume 100 potions');

-- 4. Start Initial Season
SELECT public.cron_bp_season_rotation();
