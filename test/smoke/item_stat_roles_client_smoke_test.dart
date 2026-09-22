import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/power_formula.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/player_model.dart';

InventoryItem _gear({
  required String id,
  required int attack,
  required int defense,
  required int health,
  required int luck,
  int enhancement = 0,
}) {
  return InventoryItem(
    rowId: 'row_$id',
    itemId: id,
    quantity: 1,
    slotPosition: 0,
    isEquipped: true,
    equippedSlot: 'weapon',
    enhancementLevel: enhancement,
    isFavorite: false,
    pendingSync: false,
    name: id,
    description: 'Ekstra: smoke',
    icon: '',
    itemType: ItemType.weapon,
    rarity: Rarity.common,
    basePrice: 0,
    vendorSellPrice: 0,
    attack: attack,
    defense: defense,
    health: health,
    power: attack + defense + (health ~/ 10) + (luck * 2),
    luck: luck,
    mana: 0,
    equipSlot: EquipSlot.weapon,
    weaponType: WeaponType.sword,
    armorType: ArmorType.none,
    requiredLevel: 1,
    canEnhance: true,
    maxEnhancement: 10,
    isStackable: false,
    maxStack: 1,
    isTradeable: true,
    potionType: PotionType.none,
    energyRestore: 0,
    healthRestore: 0,
    toleranceIncrease: 0,
  );
}

PlayerProfile _player() {
  return PlayerProfile.fromJson(<String, dynamic>{
    'id': 'p1',
    'auth_id': 'a1',
    'username': 'smoke',
    'email': 'smoke@test',
    'level': 1,
    'xp': 0,
    'gold': 0,
    'gems': 0.0,
    'energy': 100,
    'max_energy': 100,
    'attack': 10,
    'defense': 10,
    'health': 100,
    'max_health': 100,
    'power': 0,
    'is_online': true,
    'is_banned': false,
    'tutorial_completed': true,
    'pvp_rating': 1000,
    'pvp_wins': 0,
    'pvp_losses': 0,
    'addiction_level': 0,
    'tolerance': 0,
    'hospital_lifetime_count': 0,
    'global_suspicion_level': 0,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
    'reputation': 0,
    'luck': 0,
    'stat_points': 0,
  });
}

void main() {
  group('item role extras → client power', () {
    test('common weapon roles produce different equipment power', () {
      final PlayerProfile player = _player();
      final int sword = calculateTotalPower(
        player: player,
        equippedItems: <InventoryItem?>[
          _gear(id: 'wpn_sword_common', attack: 1100, defense: 0, health: 0, luck: 80),
        ],
      ).equipmentPower;
      final int axe = calculateTotalPower(
        player: player,
        equippedItems: <InventoryItem?>[
          _gear(id: 'wpn_axe_common', attack: 850, defense: 0, health: 0, luck: 280),
        ],
      ).equipmentPower;
      final int staff = calculateTotalPower(
        player: player,
        equippedItems: <InventoryItem?>[
          _gear(id: 'wpn_staff_common', attack: 620, defense: 50, health: 320, luck: 90),
        ],
      ).equipmentPower;

      expect(sword, 1260);
      expect(axe, 1410);
      expect(staff, 882);
      expect(axe, greaterThan(sword));
      expect(sword, greaterThan(staff));
    });

    test('enhancement multiplies role extras', () {
      final PlayerProfile player = _player();
      final int base = calculateTotalPower(
        player: player,
        equippedItems: <InventoryItem?>[
          _gear(id: 'axe', attack: 850, defense: 0, health: 0, luck: 280),
        ],
      ).equipmentPower;
      final int plus1 = calculateTotalPower(
        player: player,
        equippedItems: <InventoryItem?>[
          _gear(
            id: 'axe',
            attack: 850,
            defense: 0,
            health: 0,
            luck: 280,
            enhancement: 1,
          ),
        ],
      ).equipmentPower;
      expect(plus1, (base * 1.15).floor());
    });
  });
}
