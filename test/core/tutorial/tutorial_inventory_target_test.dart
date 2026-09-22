import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_inventory_target.dart';
import 'package:gkk_flutter/models/inventory_model.dart';
import 'package:gkk_flutter/models/item_model.dart';
import 'package:gkk_flutter/providers/inventory_provider.dart';

InventoryItem _item({
  required String rowId,
  required int slot,
  required ItemType itemType,
  required EquipSlot equipSlot,
  bool equipped = false,
}) {
  return InventoryItem(
    rowId: rowId,
    itemId: 'itm_$rowId',
    quantity: 1,
    slotPosition: slot,
    isEquipped: equipped,
    equippedSlot: equipped ? equipSlot.name : '',
    enhancementLevel: 0,
    isFavorite: false,
    pendingSync: false,
    name: 'Item $rowId',
    description: 'desc',
    icon: 'icon',
    itemType: itemType,
    rarity: Rarity.common,
    basePrice: 10,
    vendorSellPrice: 5,
    attack: 1,
    defense: 1,
    health: 1,
    power: 1,
    luck: 1,
    mana: 1,
    equipSlot: equipSlot,
    weaponType: WeaponType.none,
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

void main() {
  group('TutorialInventoryTarget', () {
    test('picks newest unequipped equippable by slot (armor/ring ok)', () {
      final InventoryState state = InventoryState(
        status: InventoryStatus.ready,
        items: <InventoryItem>[
          _item(
            rowId: 'potion',
            slot: 9,
            itemType: ItemType.potion,
            equipSlot: EquipSlot.none,
          ),
          _item(
            rowId: 'armor_old',
            slot: 2,
            itemType: ItemType.armor,
            equipSlot: EquipSlot.chest,
          ),
          _item(
            rowId: 'ring_new',
            slot: 7,
            itemType: ItemType.armor,
            equipSlot: EquipSlot.ring,
          ),
        ],
        equippedItems: const <String, InventoryItem?>{},
      );

      expect(TutorialInventoryTarget.lootEquippableRowId(state), 'ring_new');
    });

    test('ignores equipped gear', () {
      final InventoryState state = InventoryState(
        status: InventoryStatus.ready,
        items: <InventoryItem>[
          _item(
            rowId: 'equipped',
            slot: 9,
            itemType: ItemType.weapon,
            equipSlot: EquipSlot.weapon,
            equipped: true,
          ),
          _item(
            rowId: 'bag',
            slot: 3,
            itemType: ItemType.armor,
            equipSlot: EquipSlot.head,
          ),
        ],
        equippedItems: const <String, InventoryItem?>{},
      );

      expect(TutorialInventoryTarget.lootEquippableRowId(state), 'bag');
    });

    test('enhanceWeaponRowId prefers bag loot over equipped', () {
      final InventoryState state = InventoryState(
        status: InventoryStatus.ready,
        items: <InventoryItem>[
          _item(
            rowId: 'bag',
            slot: 8,
            itemType: ItemType.weapon,
            equipSlot: EquipSlot.weapon,
          ),
        ],
        equippedItems: <String, InventoryItem?>{
          'weapon': _item(
            rowId: 'equipped',
            slot: 1,
            itemType: ItemType.weapon,
            equipSlot: EquipSlot.weapon,
            equipped: true,
          ),
        },
      );

      expect(TutorialInventoryTarget.enhanceWeaponRowId(state), 'bag');
    });

    test('enhanceWeaponRowId falls back to equippedItems when bag empty', () {
      final InventoryState state = InventoryState(
        status: InventoryStatus.ready,
        items: const <InventoryItem>[],
        equippedItems: <String, InventoryItem?>{
          'weapon': _item(
            rowId: 'equipped',
            slot: 1,
            itemType: ItemType.weapon,
            equipSlot: EquipSlot.weapon,
            equipped: true,
          ),
        },
      );

      expect(TutorialInventoryTarget.enhanceWeaponRowId(state), 'equipped');
    });
  });
}
