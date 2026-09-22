import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/power_formula.dart';
import '../core/utils/potion_health.dart';
import '../models/inventory_model.dart';
import '../models/item_model.dart';
import '../models/player_model.dart';
import '../repositories/inventory_repository.dart';
import 'player_provider.dart';
import 'power_change_provider.dart';

enum InventoryStatus {
  initial,
  loading,
  ready,
  error,
}

class InventoryState {
  InventoryState({
    required this.status,
    required this.items,
    required this.equippedItems,
    this.errorMessage,
    Map<int, InventoryItem>? itemsBySlot,
  }) : itemsBySlot = itemsBySlot ?? _buildSlotMap(items);

  final InventoryStatus status;
  final List<InventoryItem> items;
  final Map<String, InventoryItem?> equippedItems;
  final String? errorMessage;

  /// O(1) bag slot lookup.
  final Map<int, InventoryItem> itemsBySlot;

  factory InventoryState.initial() => InventoryState(
        status: InventoryStatus.initial,
        items: const <InventoryItem>[],
        equippedItems: const <String, InventoryItem?>{},
      );

  static Map<int, InventoryItem> _buildSlotMap(List<InventoryItem> items) {
    return <int, InventoryItem>{
      for (final InventoryItem item in items) item.slotPosition: item,
    };
  }

  InventoryState copyWith({
    InventoryStatus? status,
    List<InventoryItem>? items,
    Map<String, InventoryItem?>? equippedItems,
    String? errorMessage,
    bool clearError = false,
  }) {
    final List<InventoryItem> nextItems = items ?? this.items;
    return InventoryState(
      status: status ?? this.status,
      items: nextItems,
      equippedItems: equippedItems ?? this.equippedItems,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      itemsBySlot: items != null ? _buildSlotMap(nextItems) : itemsBySlot,
    );
  }
}

class InventoryAddCheck {
  const InventoryAddCheck({
    required this.canAdd,
    this.reason,
    this.available,
    this.remainingFreeSlots,
  });

  final bool canAdd;
  final String? reason;
  final int? available;
  final int? remainingFreeSlots;
}

final Provider<InventoryRepository> inventoryRepositoryProvider =
    Provider<InventoryRepository>((Ref ref) {
  return SupabaseInventoryRepository();
});

class InventoryNotifier extends Notifier<InventoryState> {
  InventoryRepository get _repository => ref.read(inventoryRepositoryProvider);

  /// Serializes mutations so double-tap can't race equip/sell/use.
  Future<void>? _mutationTail;

  @override
  InventoryState build() => InventoryState.initial();

  Future<T> _serializeMutation<T>(Future<T> Function() action) async {
    final Future<void>? previous = _mutationTail;
    final Completer<void> gate = Completer<void>();
    _mutationTail = gate.future;
    try {
      if (previous != null) {
        await previous;
      }
      return await action();
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
      if (identical(_mutationTail, gate.future)) {
        _mutationTail = null;
      }
    }
  }

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

  int _snapshotTotalPower() {
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    if (profile == null) return 0;
    // Same source as character screen / dungeon: users.power first.
    return resolveDungeonCombatPower(
      profile: profile,
      equippedItems: state.equippedItems.values,
    );
  }

  void _emitPowerChangeIfNeeded(int before) {
    final int after = _snapshotTotalPower();
    if (after != before) {
      ref.read(powerChangeProvider.notifier).emit(
            oldPower: before,
            newPower: after,
          );
    }
  }

  Future<bool> _runWithPowerTracking(Future<bool> Function() action) async {
    return _serializeMutation(() async {
      final int before = _snapshotTotalPower();
      final bool ok = await action();
      if (ok) {
        // Refresh users.power before overlay / badge — client calc misses monument.
        await ref.read(playerProvider.notifier).loadProfile();
        _emitPowerChangeIfNeeded(before);
      }
      return ok;
    });
  }

  Future<bool> equipItem({required String rowId, required String slot}) async {
    return _runWithPowerTracking(() async {
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
    });
  }

  InventoryAddCheck canAddItem({required String itemId, int quantity = 1}) {
    return _canAddItemWithSlotBudget(
      itemId: itemId,
      quantity: quantity,
      remainingFreeSlots: _countFreeInventorySlots(),
    );
  }

  InventoryAddCheck canAddBatch(Map<String, int> demandByItemId) {
    int remainingFreeSlots = _countFreeInventorySlots();

    for (final MapEntry<String, int> entry in demandByItemId.entries) {
      final InventoryAddCheck check = _canAddItemWithSlotBudget(
        itemId: entry.key,
        quantity: entry.value,
        remainingFreeSlots: remainingFreeSlots,
      );
      if (!check.canAdd) return check;
      remainingFreeSlots = check.remainingFreeSlots ?? remainingFreeSlots;
    }

    return InventoryAddCheck(
      canAdd: true,
      remainingFreeSlots: remainingFreeSlots,
    );
  }

  int _countFreeInventorySlots() {
    final Set<int> occupied = state.items
        .map((InventoryItem item) => item.slotPosition)
        .where((int pos) => pos >= 0)
        .toSet();
    return inventoryCapacity - occupied.length;
  }

  InventoryAddCheck _canAddItemWithSlotBudget({
    required String itemId,
    required int quantity,
    required int remainingFreeSlots,
  }) {
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
          return InventoryAddCheck(
            canAdd: true,
            available: totalSpace,
            remainingFreeSlots: remainingFreeSlots,
          );
        }
      }
    }

    if (remaining <= 0) {
      return InventoryAddCheck(
        canAdd: true,
        available: totalSpace,
        remainingFreeSlots: remainingFreeSlots,
      );
    }

    if (remainingFreeSlots <= 0) {
      return InventoryAddCheck(
        canAdd: false,
        reason: 'Envanter dolu ($inventoryCapacity/$inventoryCapacity)',
        available: totalSpace,
      );
    }

    final int slotsNeeded = (remaining / maxStack).ceil();
    if (slotsNeeded > remainingFreeSlots) {
      return InventoryAddCheck(
        canAdd: false,
        reason: '$itemName icin yeterli envanter alani yok ($quantity adet)',
        available: totalSpace + remainingFreeSlots * maxStack,
      );
    }

    return InventoryAddCheck(
      canAdd: true,
      available: totalSpace + remainingFreeSlots * maxStack,
      remainingFreeSlots: remainingFreeSlots - slotsNeeded,
    );
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

  @Deprecated('Client mint disabled — use server RPCs (shop/loot/craft).')
  Future<bool> addItemToServer({required String itemId, required int quantity, int? slotPosition}) async {
    state = state.copyWith(
      errorMessage: 'Envanter mint istemciden kapalı. Sunucu RPC kullan.',
    );
    return false;
  }

  bool canDirectUnequip() => findFirstEmptySlot() >= 0;

  Future<bool> unequipItem({required String slot}) async {
    if (!canDirectUnequip()) {
      state = state.copyWith(
        errorMessage: 'Envanter dolu — benzer slottaki esyayla degistir',
      );
      return false;
    }

    return _runWithPowerTracking(() async {
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
    });
  }

  Future<bool> swapSlots({required int fromSlot, required int toSlot}) async {
    if (fromSlot == toSlot) {
      return true;
    }

    return _serializeMutation(() async {
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
    });
  }

  Future<bool> moveItemToSlot({required String rowId, required int targetSlot}) async {
    return _serializeMutation(() async {
      try {
        final bool success =
            await _repository.moveItemToSlot(rowId: rowId, targetSlot: targetSlot);
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
    });
  }

  Future<bool> unequipItemToSlot({required String rowId, required String slot, required int targetSlot}) async {
    return _runWithPowerTracking(() async {
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
    });
  }

  Future<bool> swapEquipWithSlot({required String equipSlot, required int targetSlot}) async {
    return _runWithPowerTracking(() async {
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
    });
  }

  Future<UseItemResult> useItem({required InventoryItem item}) async {
    return _serializeMutation(() => _useItemBody(item: item));
  }

  Future<UseItemResult> _useItemBody({required InventoryItem item}) async {
    try {
      String? successMessage;
      final PlayerProfile? profileBefore = ref.read(playerProvider).profile;
      final int healthBefore = profileBefore?.health ?? 0;
      final int maxHealthBefore = profileBefore?.maxHealth ?? 0;
      int? healthPotionHealPreview;
      if (isHealthPotionItem(item) && profileBefore != null) {
        final int effective = effectiveHealthRestore(
          baseRestore: item.healthRestore,
          tolerance: profileBefore.tolerance,
          alchemistBonus: profileBefore.characterClass == CharacterClass.alchemist,
          maxHealth: maxHealthBefore,
          itemId: item.itemId,
        );
        if (effective > 0) {
          healthPotionHealPreview =
              effective.clamp(0, (maxHealthBefore - healthBefore).clamp(0, maxHealthBefore));
        }
      }

      if (isInventoryLootBox(item.itemId)) {
        final OpenLootBoxResult result = await _repository.openLootBox(rowId: item.rowId);
        if (!result.success) {
          state = state.copyWith(errorMessage: result.error ?? 'Kasa acilamadi.');
          return UseItemResult(success: false, message: result.error);
        }
        final String rewardName = result.rewardItemName ?? result.rewardItemId ?? 'Odul';
        successMessage = 'Kasa acildi: $rewardName x${result.rewardQuantity}';
      } else if (isStatResetScroll(item.itemId)) {
        final UseItemResult resetResult =
            await _repository.useStatResetScroll(rowId: item.rowId);
        if (!resetResult.success) {
          state = state.copyWith(
            errorMessage: resetResult.message ?? 'Stat sifirlama basarisiz.',
          );
          return UseItemResult(
            success: false,
            message: resetResult.message,
          );
        }
        successMessage = resetResult.message ?? 'Stat puanlari geri alindi.';
      } else if (isNameChangeScroll(item.itemId)) {
        return const UseItemResult(
          success: false,
          message: 'Yeni isim envanter akisindan secilmeli.',
        );
      } else if (item.subType == SubType.detox) {
        final bool success = await _repository.useDetox(rowId: item.rowId);
        if (!success) {
          state = state.copyWith(errorMessage: 'Item kullanimi basarisiz.');
          return const UseItemResult(success: false);
        }
        successMessage = '${item.name} kullanildi.';
      } else {
        final UsePotionResult potion =
            await _repository.usePotion(rowId: item.rowId);
        if (!potion.success) {
          state = state.copyWith(errorMessage: 'Item kullanimi basarisiz.');
          return const UseItemResult(success: false);
        }

        await Future.wait<void>(<Future<void>>[
          loadInventory(silent: true),
          ref.read(playerProvider.notifier).loadProfile(),
        ]);

        if (potion.overdose) {
          return UseItemResult(
            success: true,
            overdose: true,
            hospitalMinutes: potion.hospitalMinutes,
          );
        }

        successMessage = '${item.name} kullanildi.';
        final PlayerProfile? profile = ref.read(playerProvider).profile;
        if (item.energyRestore > 0 && profile != null) {
          successMessage =
              '${item.name} kullanildi. Enerji: ${profile.energy}/${profile.maxEnergy}';
        } else if (isHealthPotionItem(item) && profile != null) {
          final int healed = healthPotionHealPreview ??
              (profile.health - healthBefore).clamp(0, profile.maxHealth);
          successMessage = healthPotionUseMessage(
            itemName: item.name,
            health: profile.health,
            maxHealth: profile.maxHealth,
            healedAmount: healed,
          );
        }

        return UseItemResult(success: true, message: successMessage);
      }

      await Future.wait<void>(<Future<void>>[
        loadInventory(silent: true),
        ref.read(playerProvider.notifier).loadProfile(),
      ]);

      final PlayerProfile? profile = ref.read(playerProvider).profile;
      if (item.energyRestore > 0 && !isInventoryLootBox(item.itemId) && profile != null) {
        successMessage = '${item.name} kullanildi. Enerji: ${profile.energy}/${profile.maxEnergy}';
      } else if (isHealthPotionItem(item) && profile != null) {
        final int healed = healthPotionHealPreview ??
            (profile.health - healthBefore).clamp(0, profile.maxHealth);
        successMessage = healthPotionUseMessage(
          itemName: item.name,
          health: profile.health,
          maxHealth: profile.maxHealth,
          healedAmount: healed,
        );
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

  Future<UseItemResult> useNameChangeScroll({
    required InventoryItem item,
    required String newDisplayName,
  }) async {
    return _serializeMutation(() async {
      try {
        final UseItemResult result = await _repository.useNameChangeScroll(
          rowId: item.rowId,
          newDisplayName: newDisplayName,
        );
        if (!result.success) {
          state = state.copyWith(errorMessage: result.message);
          return result;
        }
        await Future.wait<void>(<Future<void>>[
          loadInventory(silent: true),
          ref.read(playerProvider.notifier).loadProfile(),
        ]);
        return result;
      } on AppException catch (e) {
        state = state.copyWith(errorMessage: e.message);
        return UseItemResult(success: false, message: e.message);
      } catch (_) {
        state = state.copyWith(errorMessage: 'Isim degistirme basarisiz.');
        return const UseItemResult(success: false);
      }
    });
  }

  Future<bool> splitStack({required String rowId, required int splitQuantity}) async {
    return _serializeMutation(() async {
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
    });
  }

  Future<SellItemResult> sellItemByRow({required String rowId, required int quantity}) async {
    return _serializeMutation(() async {
      try {
        final SellItemResult result =
            await _repository.sellItemByRow(rowId: rowId, quantity: quantity);
        if (result.success) {
          await Future.wait<void>(<Future<void>>[
            loadInventory(silent: true),
            ref.read(playerProvider.notifier).loadProfile(),
          ]);
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
    });
  }

  Future<bool> trashItem({required String rowId}) async {
    return _serializeMutation(() async {
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
    });
  }

  Future<bool> toggleFavorite({required String rowId, required bool isFavorite}) async {
    return _serializeMutation(() async {
      try {
        final bool success =
            await _repository.toggleFavorite(rowId: rowId, isFavorite: isFavorite);
        if (success) {
          final List<InventoryItem> updatedItems = state.items
              .map(
                (item) =>
                    item.rowId == rowId ? item.copyWith(isFavorite: isFavorite) : item,
              )
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
    });
  }

  InventoryItem? getItemBySlot(int slot) => state.itemsBySlot[slot];

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

  bool isFull() => findFirstEmptySlot() < 0;

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
