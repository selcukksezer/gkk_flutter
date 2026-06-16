import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../models/inventory_model.dart';
import '../models/item_model.dart';
import '../repositories/inventory_repository.dart';
import 'player_provider.dart';

enum InventoryStatus {
  initial,
  loading,
  ready,
  error,
}

class InventoryState {
  const InventoryState({
    required this.status,
    required this.items,
    required this.equippedItems,
    this.errorMessage,
  });

  final InventoryStatus status;
  final List<InventoryItem> items;
  final Map<String, InventoryItem?> equippedItems;
  final String? errorMessage;

  factory InventoryState.initial() => const InventoryState(
        status: InventoryStatus.initial,
        items: <InventoryItem>[],
        equippedItems: <String, InventoryItem?>{},
      );

  InventoryState copyWith({
    InventoryStatus? status,
    List<InventoryItem>? items,
    Map<String, InventoryItem?>? equippedItems,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InventoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      equippedItems: equippedItems ?? this.equippedItems,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class InventoryAddCheck {
  const InventoryAddCheck({required this.canAdd, this.reason, this.available});

  final bool canAdd;
  final String? reason;
  final int? available;
}

final Provider<InventoryRepository> inventoryRepositoryProvider =
    Provider<InventoryRepository>((Ref ref) {
  return SupabaseInventoryRepository();
});

class InventoryNotifier extends Notifier<InventoryState> {
  InventoryRepository get _repository => ref.read(inventoryRepositoryProvider);

  @override
  InventoryState build() => InventoryState.initial();

  Future<void> loadInventory({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(status: InventoryStatus.loading, clearError: true);
    } else {
      state = state.copyWith(clearError: true);
    }

    try {
      final snapshot = await _repository.fetchInventory();
      state = state.copyWith(
        status: InventoryStatus.ready,
        items: snapshot.items,
        equippedItems: snapshot.equippedItems,
      );
    } on AppException catch (e) {
      state = state.copyWith(status: InventoryStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        status: InventoryStatus.error,
        errorMessage: 'Envanter yuklenirken beklenmeyen bir hata olustu.',
      );
    }
  }

  Future<bool> equipItem({required String rowId, required String slot}) async {
    try {
      final success = await _repository.equipItem(rowId: rowId, slot: slot);
      if (success) {
        await loadInventory(silent: true);
        return true;
      }
      state = state.copyWith(errorMessage: 'Kusanma islemi basarisiz.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Kusanma sirasinda beklenmeyen bir hata olustu.');
      return false;
    }
  }

  InventoryAddCheck canAddItem({required String itemId, int quantity = 1}) {
    InventoryItem? template;
    for (final InventoryItem item in state.items) {
      if (item.itemId == itemId) {
        template = item;
        break;
      }
    }

    if (template != null && !template.isStackable) {
      if (quantity != 1) {
        return InventoryAddCheck(
          canAdd: false,
          reason: '${template.name} stackable degil, sadece 1 adet alinabilir',
        );
      }
      return InventoryAddCheck(
        canAdd: false,
        reason: '${template.name} envanterde zaten var (stackable degil)',
      );
    }

    final int maxStack = template?.maxStack ?? 999;
    final String itemName = template?.name ?? 'Esya';

    int remaining = quantity;
    int totalSpace = 0;

    for (final InventoryItem item in state.items) {
      if (item.itemId != itemId || item.isEquipped || !item.isStackable) {
        continue;
      }
      final int space = item.maxStack - item.quantity;
      if (space > 0) {
        totalSpace += space;
        remaining -= space;
        if (remaining <= 0) {
          return InventoryAddCheck(canAdd: true, available: totalSpace);
        }
      }
    }

    if (remaining <= 0) {
      return InventoryAddCheck(canAdd: true, available: totalSpace);
    }

    final Set<int> occupied = state.items
        .map((InventoryItem i) => i.slotPosition)
        .where((int pos) => pos >= 0)
        .toSet();

    final int freeSlots = inventoryCapacity - occupied.length;
    if (freeSlots <= 0) {
      return InventoryAddCheck(
        canAdd: false,
        reason: 'Envanter dolu (${occupied.length}/$inventoryCapacity)',
        available: totalSpace,
      );
    }

    final int slotsNeeded = (remaining / maxStack).ceil();
    if (slotsNeeded > freeSlots) {
      return InventoryAddCheck(
        canAdd: false,
        reason: '$itemName icin yeterli envanter alani yok ($quantity adet)',
        available: totalSpace + freeSlots * maxStack,
      );
    }

    return InventoryAddCheck(canAdd: true, available: totalSpace + freeSlots * maxStack);
  }

  int getItemQuantity(String itemId) {
    int total = 0;
    for (final InventoryItem item in state.items) {
      if (item.itemId == itemId) {
        total += item.quantity;
      }
    }
    return total;
  }

  Future<bool> addItemToServer({required String itemId, required int quantity, int? slotPosition}) async {
    if (quantity <= 0) {
      return true;
    }

    final InventoryAddCheck check = canAddItem(itemId: itemId, quantity: quantity);
    if (!check.canAdd) {
      state = state.copyWith(errorMessage: check.reason ?? 'Envanter dolu');
      return false;
    }

    try {
      final bool success = await _repository.addItemToServer(
        itemId: itemId,
        quantity: quantity,
        slotPosition: slotPosition,
      );
      if (success) {
        await loadInventory(silent: true);
        return true;
      }
      state = state.copyWith(errorMessage: 'Oge envantere eklenemedi.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Oge eklenirken beklenmeyen bir hata olustu.');
      return false;
    }
  }

  Future<bool> unequipItem({required String slot}) async {
    try {
      final success = await _repository.unequipItem(slot: slot);
      if (success) {
        await loadInventory(silent: true);
        return true;
      }
      state = state.copyWith(errorMessage: 'Kusani cikarma islemi basarisiz.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Kusani cikarirken beklenmeyen bir hata olustu.');
      return false;
    }
  }

  Future<bool> swapSlots({required int fromSlot, required int toSlot}) async {
    if (fromSlot == toSlot) {
      return true;
    }

    try {
      final success = await _repository.swapSlots(fromSlot: fromSlot, toSlot: toSlot);
      if (success) {
        await loadInventory(silent: true);
        return true;
      }
      state = state.copyWith(errorMessage: 'Slot degistirme islemi basarisiz.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Slot degistirirken beklenmeyen bir hata olustu.');
      return false;
    }
  }

  Future<bool> moveItemToSlot({required String rowId, required int targetSlot}) async {
    try {
      final bool success = await _repository.moveItemToSlot(rowId: rowId, targetSlot: targetSlot);
      if (success) {
        await loadInventory(silent: true);
        return true;
      }
      state = state.copyWith(errorMessage: 'Item tasima islemi basarisiz.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Item tasirken beklenmeyen bir hata olustu.');
      return false;
    }
  }

  Future<bool> unequipItemToSlot({required String rowId, required String slot, required int targetSlot}) async {
    try {
      final bool success = await _repository.unequipItemToSlot(
        rowId: rowId,
        slot: slot,
        targetSlot: targetSlot,
      );
      if (success) {
        await loadInventory(silent: true);
        return true;
      }
      state = state.copyWith(errorMessage: 'Kusanilan item hedef slota birakilamadi.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Kusanilan item birakilirken beklenmeyen bir hata olustu.');
      return false;
    }
  }

  Future<bool> swapEquipWithSlot({required String equipSlot, required int targetSlot}) async {
    try {
      final bool success = await _repository.swapEquipWithSlot(
        equipSlot: equipSlot,
        targetSlot: targetSlot,
      );
      if (success) {
        await loadInventory(silent: true);
        return true;
      }
      state = state.copyWith(errorMessage: 'Kusanilan item swap islemi basarisiz.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Kusanilan item swap sirasinda beklenmeyen bir hata olustu.');
      return false;
    }
  }

  Future<UseItemResult> useItem({required InventoryItem item}) async {
    try {
      String? successMessage;

      if (isInventoryLootBox(item.itemId)) {
        final OpenLootBoxResult result = await _repository.openLootBox(rowId: item.rowId);
        if (!result.success) {
          state = state.copyWith(errorMessage: result.error ?? 'Kasa acilamadi.');
          return UseItemResult(success: false, message: result.error);
        }
        final String rewardName = result.rewardItemName ?? result.rewardItemId ?? 'Odul';
        successMessage = 'Kasa acildi: $rewardName x${result.rewardQuantity}';
      } else if (item.subType == SubType.detox) {
        final bool success = await _repository.useDetox(rowId: item.rowId);
        if (!success) {
          state = state.copyWith(errorMessage: 'Item kullanimi basarisiz.');
          return const UseItemResult(success: false);
        }
        successMessage = '${item.name} kullanildi.';
      } else {
        final bool success = await _repository.usePotion(rowId: item.rowId);
        if (!success) {
          state = state.copyWith(errorMessage: 'Item kullanimi basarisiz.');
          return const UseItemResult(success: false);
        }
        if (item.energyRestore > 0) {
          successMessage = '${item.name} kullanildi.';
        } else {
          successMessage = '${item.name} kullanildi.';
        }
      }

      await Future.wait<void>(<Future<void>>[
        loadInventory(silent: true),
        ref.read(playerProvider.notifier).loadProfile(),
      ]);

      if (item.energyRestore > 0 && !isInventoryLootBox(item.itemId)) {
        final profile = ref.read(playerProvider).profile;
        if (profile != null) {
          successMessage = '${item.name} kullanildi. Enerji: ${profile.energy}/${profile.maxEnergy}';
        }
      }

      return UseItemResult(success: true, message: successMessage);
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return UseItemResult(success: false, message: e.message);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Item kullanimi sirasinda beklenmeyen bir hata olustu.');
      return const UseItemResult(success: false);
    }
  }

  Future<bool> splitStack({required String rowId, required int splitQuantity}) async {
    final int targetSlot = findFirstEmptySlot();
    if (targetSlot < 0) {
      state = state.copyWith(errorMessage: 'Envanter dolu, bolme yapilamadi.');
      return false;
    }

    try {
      final bool success = await _repository.splitStack(
        rowId: rowId,
        splitQuantity: splitQuantity,
        targetSlot: targetSlot,
      );
      if (success) {
        await loadInventory(silent: true);
        return true;
      }

      state = state.copyWith(errorMessage: 'Stack bolme islemi basarisiz.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Stack bolerken beklenmeyen bir hata olustu.');
      return false;
    }
  }

  Future<SellItemResult> sellItemByRow({required String rowId, required int quantity}) async {
    try {
      final SellItemResult result = await _repository.sellItemByRow(rowId: rowId, quantity: quantity);
      if (result.success) {
        await loadInventory(silent: true);
        return result;
      }

      state = state.copyWith(errorMessage: result.error ?? 'Satis islemi basarisiz.');
      return result;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return SellItemResult(success: false, error: e.message);
    } catch (_) {
      const String message = 'Satis sirasinda beklenmeyen bir hata olustu.';
      state = state.copyWith(errorMessage: message);
      return const SellItemResult(success: false, error: message);
    }
  }

  Future<bool> trashItem({required String rowId}) async {
    try {
      final bool success = await _repository.trashItem(rowId: rowId);
      if (success) {
        await loadInventory(silent: true);
        return true;
      }

      state = state.copyWith(errorMessage: 'Item silme islemi basarisiz.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Item silerken beklenmeyen bir hata olustu.');
      return false;
    }
  }

  Future<bool> toggleFavorite({required String rowId, required bool isFavorite}) async {
    try {
      final bool success = await _repository.toggleFavorite(rowId: rowId, isFavorite: isFavorite);
      if (success) {
        final List<InventoryItem> updatedItems = state.items
            .map((item) => item.rowId == rowId ? item.copyWith(isFavorite: isFavorite) : item)
            .toList();
        state = state.copyWith(items: updatedItems, clearError: true);
        return true;
      }

      state = state.copyWith(errorMessage: 'Favori guncelleme islemi basarisiz.');
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Favori guncellerken beklenmeyen bir hata olustu.');
      return false;
    }
  }

  InventoryItem? getItemBySlot(int slot) {
    for (final item in state.items) {
      if (item.slotPosition == slot) {
        return item;
      }
    }
    return null;
  }

  InventoryItem? getItemByRowId(String rowId) {
    for (final item in state.items) {
      if (item.rowId == rowId) {
        return item;
      }
    }
    return null;
  }

  InventoryItem? getEquippedItem(String slot) {
    return state.equippedItems[slot.toLowerCase()];
  }

  bool isFull() {
    final used = state.items.map((item) => item.slotPosition).toSet();
    return used.length >= inventoryCapacity;
  }

  int findFirstEmptySlot() {
    final used = state.items.map((item) => item.slotPosition).toSet();
    for (int i = 0; i < inventoryCapacity; i++) {
      if (!used.contains(i)) return i;
    }
    return -1;
  }

  void clear() {
    state = InventoryState.initial();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final NotifierProvider<InventoryNotifier, InventoryState> inventoryProvider =
    NotifierProvider<InventoryNotifier, InventoryState>(InventoryNotifier.new);
