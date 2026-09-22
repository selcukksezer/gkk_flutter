import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/inventory_provider.dart';

/// Tutorial inventory coach-mark target — first-run dungeon loot (any gear).
abstract final class TutorialInventoryTarget {
  static bool _isUnequippedEquippable(InventoryItem item) =>
      item.equipSlot != EquipSlot.none &&
      !item.isEquipped &&
      item.quantity > 0;

  /// Newest unequipped equippable loot (weapon / armor / ring / …).
  static String? lootEquippableRowId(InventoryState state) {
    final List<InventoryItem> gear = state.items
        .where(_isUnequippedEquippable)
        .toList(growable: false);
    if (gear.isEmpty) return null;
    gear.sort(
      (InventoryItem a, InventoryItem b) =>
          b.slotPosition.compareTo(a.slotPosition),
    );
    return gear.first.rowId;
  }

  /// @Deprecated — use [lootEquippableRowId] (first dungeon may drop non-weapons).
  static String? lootWeaponRowId(InventoryState state) =>
      lootEquippableRowId(state);

  /// Newest unequipped enhanceable loot first (equipped rows are not in
  /// `items` — enhance UI cannot select them until unequipped).
  static String? enhanceWeaponRowId(InventoryState state) {
    final List<InventoryItem> bag = state.items
        .where(_isUnequippedEquippable)
        .where((InventoryItem item) => item.enhancementLevel < 10)
        .toList(growable: false);
    if (bag.isNotEmpty) {
      bag.sort(
        (InventoryItem a, InventoryItem b) =>
            b.slotPosition.compareTo(a.slotPosition),
      );
      return bag.first.rowId;
    }
    final List<InventoryItem> equipped = state.equippedItems.values
        .whereType<InventoryItem>()
        .where(
          (InventoryItem item) =>
              item.equipSlot != EquipSlot.none &&
              item.quantity > 0 &&
              item.enhancementLevel < 10,
        )
        .toList(growable: false);
    if (equipped.isEmpty) return null;
    equipped.sort(
      (InventoryItem a, InventoryItem b) =>
          b.slotPosition.compareTo(a.slotPosition),
    );
    return equipped.first.rowId;
  }
}
