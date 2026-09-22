import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/power_formula.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/models/player_model.dart';

/// Catalog snapshot matching post role-extra migration (common weapons).
const List<({String id, int atk, int def, int hp, int luck})> kCommonWeapons =
    <({String id, int atk, int def, int hp, int luck})>[
  (id: 'wpn_sword_common', atk: 1100, def: 0, hp: 0, luck: 80),
  (id: 'wpn_axe_common', atk: 850, def: 0, hp: 0, luck: 280),
  (id: 'wpn_dagger_common', atk: 720, def: 0, hp: 0, luck: 220),
  (id: 'wpn_staff_common', atk: 620, def: 50, hp: 320, luck: 90),
];

InventoryItem _gear({
  required String id,
  required int attack,
  required int defense,
  required int health,
  required int luck,
  required int enhancement,
  EquipSlot slot = EquipSlot.weapon,
}) {
  return InventoryItem(
    rowId: 'row_${id}_$enhancement',
    itemId: id,
    quantity: 1,
    slotPosition: 0,
    isEquipped: true,
    equippedSlot: slot.name,
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
    equipSlot: slot,
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

PlayerProfile _player({int level = 1, int luck = 0}) {
  return PlayerProfile.fromJson(<String, dynamic>{
    'id': 'p1',
    'auth_id': 'a1',
    'username': 'smoke',
    'email': 'smoke@test',
    'level': level,
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
    'luck': luck,
    'stat_points': 0,
  });
}

int _base(int atk, int def, int hp, int luck) =>
    atk + def + (hp ~/ 10) + (luck * 2);

void main() {
  group('enhancement matrix +0..+10', () {
    test('every common weapon × every plus is monotonic ~2.04x at +10', () {
      final PlayerProfile player = _player();
      for (final w in kCommonWeapons) {
        int? prev;
        for (int enh = 0; enh <= 10; enh++) {
          final int eq = calculateTotalPower(
            player: player,
            equippedItems: <InventoryItem?>[
              _gear(
                id: w.id,
                attack: w.atk,
                defense: w.def,
                health: w.hp,
                luck: w.luck,
                enhancement: enh,
              ),
            ],
          ).equipmentPower;
          final double mult = enh <= 0
              ? 1.0
              : enh <= 6
                  ? 1.0 + enh * 0.12
                  : 1.72 + (enh - 6) * 0.08;
          final int expected = (_base(w.atk, w.def, w.hp, w.luck) * mult).floor();
          expect(eq, expected, reason: '${w.id} +$enh');
          if (prev != null) {
            expect(eq, greaterThanOrEqualTo(prev), reason: '${w.id} +$enh mono');
          }
          prev = eq;
        }
        final int p0 = (_base(w.atk, w.def, w.hp, w.luck) * 1.0).floor();
        final int p10 = (_base(w.atk, w.def, w.hp, w.luck) * 2.04).floor();
        expect(p10 / p0, closeTo(2.04, 0.02), reason: '${w.id} +10 ratio');
      }
    });

    test('luck-heavy axe stays stronger than sword across all plus levels', () {
      final PlayerProfile player = _player();
      for (int enh = 0; enh <= 10; enh++) {
        final int sword = calculateTotalPower(
          player: player,
          equippedItems: <InventoryItem?>[
            _gear(
              id: 'sword',
              attack: 1100,
              defense: 0,
              health: 0,
              luck: 80,
              enhancement: enh,
            ),
          ],
        ).equipmentPower;
        final int axe = calculateTotalPower(
          player: player,
          equippedItems: <InventoryItem?>[
            _gear(
              id: 'axe',
              attack: 850,
              defense: 0,
              health: 0,
              luck: 280,
              enhancement: enh,
            ),
          ],
        ).equipmentPower;
        expect(axe, greaterThan(sword), reason: 'axe>sword at +$enh');
      }
    });

    test('full 8-slot common set at +10 is ~2.04x set at +0', () {
      final PlayerProfile player = _player(level: 10);
      // Synthetic balanced set (one piece / slot).
      final List<({EquipSlot slot, int atk, int def, int hp, int luck})> set =
          <({EquipSlot slot, int atk, int def, int hp, int luck})>[
        (slot: EquipSlot.weapon, atk: 1100, def: 0, hp: 0, luck: 80),
        (slot: EquipSlot.head, atk: 400, def: 400, hp: 0, luck: 100),
        (slot: EquipSlot.chest, atk: 0, def: 700, hp: 200, luck: 100),
        (slot: EquipSlot.legs, atk: 0, def: 600, hp: 100, luck: 100),
        (slot: EquipSlot.boots, atk: 0, def: 350, hp: 300, luck: 180),
        (slot: EquipSlot.gloves, atk: 520, def: 120, hp: 0, luck: 180),
        (slot: EquipSlot.ring, atk: 200, def: 200, hp: 0, luck: 150),
        (slot: EquipSlot.necklace, atk: 100, def: 150, hp: 0, luck: 150),
      ];

      List<InventoryItem?> build(int enh) => set
          .map(
            (e) => _gear(
              id: e.slot.name,
              attack: e.atk,
              defense: e.def,
              health: e.hp,
              luck: e.luck,
              enhancement: enh,
              slot: e.slot,
            ),
          )
          .toList(growable: false);

      final int eq0 = calculateTotalPower(player: player, equippedItems: build(0))
          .equipmentPower;
      final int eq10 =
          calculateTotalPower(player: player, equippedItems: build(10))
              .equipmentPower;
      expect(eq10 / eq0, closeTo(2.04, 0.02));
      expect(eq10, greaterThan(eq0 * 1.9));
    });
  });
}
