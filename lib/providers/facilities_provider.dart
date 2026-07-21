import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/character_class_abilities.dart';
import '../models/facility_model.dart';
import '../models/facility_production_preview_model.dart';
import '../models/player_model.dart';
import 'inventory_provider.dart';
import 'player_provider.dart';
import '../repositories/facilities_repository.dart';

enum FacilitiesStatus {
  initial,
  loading,
  ready,
  error,
}

class FacilitiesState {
  const FacilitiesState({
    required this.status,
    required this.facilities,
    required this.productionPreviews,
    required this.isMutating,
    this.errorMessage,
  });

  final FacilitiesStatus status;
  final List<PlayerFacility> facilities;
  final Map<String, FacilityProductionPreview> productionPreviews;
  final bool isMutating;
  final String? errorMessage;

  factory FacilitiesState.initial() => const FacilitiesState(
        status: FacilitiesStatus.initial,
        facilities: <PlayerFacility>[],
        productionPreviews: <String, FacilityProductionPreview>{},
        isMutating: false,
      );

  FacilitiesState copyWith({
    FacilitiesStatus? status,
    List<PlayerFacility>? facilities,
    Map<String, FacilityProductionPreview>? productionPreviews,
    bool? isMutating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FacilitiesState(
      status: status ?? this.status,
      facilities: facilities ?? this.facilities,
      productionPreviews: productionPreviews ?? this.productionPreviews,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final Provider<FacilitiesRepository> facilitiesRepositoryProvider =
    Provider<FacilitiesRepository>((Ref ref) {
  return SupabaseFacilitiesRepository();
});

class FacilitiesNotifier extends Notifier<FacilitiesState> {
  FacilitiesRepository get _repository => ref.read(facilitiesRepositoryProvider);

  @override
  FacilitiesState build() => FacilitiesState.initial();

  Future<void> loadFacilities() async {
    state = state.copyWith(status: FacilitiesStatus.loading, clearError: true);

    try {
      final List<PlayerFacility> facilities = await _repository.fetchFacilities();
      state = state.copyWith(status: FacilitiesStatus.ready, facilities: facilities);
    } on AppException catch (e) {
      state = state.copyWith(status: FacilitiesStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(status: FacilitiesStatus.error, errorMessage: 'Tesisler yüklenemedi');
    }
  }

  Future<bool> unlockFacility({required String facilityType}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final bool ok = await _repository.unlockFacility(facilityType: facilityType);
      if (ok) {
        await loadFacilities();
      }
      state = state.copyWith(isMutating: false);
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isMutating: false, errorMessage: 'Tesis açılamadı');
      return false;
    }
  }

  Future<bool> bribeOfficials({required String facilityType, required int gemAmount}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final profile = ref.read(playerProvider).profile;
      final int currentSuspicion = effectiveSuspicionLevel(profile);
      if (currentSuspicion <= 0) {
        state = state.copyWith(isMutating: false, errorMessage: 'Genel şüphe 0 iken rüşvet verilemez');
        return false;
      }

      final bool ok = await _repository.bribeOfficials(
        facilityType: facilityType,
        gemAmount: gemAmount,
      );
      if (ok) {
        await loadFacilities();
        await _syncGlobalSuspicionToServer();
      }
      state = state.copyWith(isMutating: false);
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isMutating: false, errorMessage: 'Rüşvet verilemedi');
      return false;
    }
  }

  Future<bool> upgradeFacility({required String facilityId}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final bool ok = await _repository.upgradeFacility(facilityId: facilityId);
      if (ok) {
        await loadFacilities();
      }
      state = state.copyWith(isMutating: false);
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isMutating: false, errorMessage: 'Yükseltme başarısız');
      return false;
    }
  }

  Future<bool> startProduction({required String facilityId}) async {
    PlayerFacility? existing;
    for (final PlayerFacility row in state.facilities) {
      if (row.id == facilityId) {
        existing = row;
        break;
      }
    }
    if (existing != null &&
        existing.productionStartedAt != null &&
        existing.productionStartedAt!.isNotEmpty) {
      state = state.copyWith(errorMessage: 'Üretim zaten devam ediyor');
      return false;
    }

    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final bool ok = await _repository.startProduction(facilityId: facilityId);
      if (ok) {
        await loadFacilities();
        await loadProductionPreview(facilityId);
        await _syncGlobalSuspicionToServer();
      }
      state = state.copyWith(isMutating: false);
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isMutating: false, errorMessage: 'Üretim başlatılamadı');
      return false;
    }
  }

  Future<void> loadProductionPreview(String facilityId) async {
    if (facilityId.isEmpty) return;

    try {
      final FacilityProductionPreview preview =
          await _repository.fetchProductionPreview(facilityId: facilityId);
      final Map<String, FacilityProductionPreview> next =
          Map<String, FacilityProductionPreview>.from(state.productionPreviews);
      next[facilityId] = preview;
      state = state.copyWith(productionPreviews: next);
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Üretim önizlemesi alınamadı');
    }
  }

  Future<Map<String, dynamic>?> collectResourcesV2({
    required String facilityId,
    required int expectedCount,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final InventoryNotifier inventory = ref.read(inventoryProvider.notifier);
      await inventory.loadInventory(silent: true);

      final InventoryAddCheck capacityCheck =
          inventory.canAddItem(itemId: 'resource_placeholder', quantity: expectedCount);
      if (expectedCount > 0 && !capacityCheck.canAdd) {
        state = state.copyWith(
          isMutating: false,
          errorMessage: capacityCheck.reason ?? 'Envanter dolu! Kapasite yetersiz.',
        );
        return null;
      }

      final Map<String, int> inventoryBefore = <String, int>{};
      for (final item in ref.read(inventoryProvider).items) {
        inventoryBefore[item.itemId] = inventory.getItemQuantity(item.itemId);
      }

      final Map<String, dynamic>? result = await _repository.collectResourcesV2(
        facilityId: facilityId,
      );
      if (result == null) {
        state = state.copyWith(isMutating: false, errorMessage: 'Toplama başarısız');
        return null;
      }

      await loadFacilities();
      await loadProductionPreview(facilityId);
      await _syncGlobalSuspicionToServer();

      await inventory.loadInventory(silent: true);

      final bool admissionOccurred = result['admission_occurred'] == true;
      final dynamic rawGenerated = result['items_generated'];

      if (!admissionOccurred && rawGenerated is List) {
        final Map<String, int> generatedAgg = <String, int>{};
        for (final dynamic entry in rawGenerated) {
          if (entry is Map) {
            final Map<dynamic, dynamic> row = entry;
            final String itemId =
                (row['item_id'] ?? row['itemId'] ?? row['id'] ?? '').toString();
            if (itemId.isEmpty) continue;
            final int qty = (row['quantity'] as num?)?.toInt() ?? 1;
            generatedAgg[itemId] = (generatedAgg[itemId] ?? 0) + qty;
          }
        }

        final Map<String, int> afterCounts = <String, int>{};
        for (final item in ref.read(inventoryProvider).items) {
          afterCounts[item.itemId] = inventory.getItemQuantity(item.itemId);
        }

        // Server collect RPC must grant items; client mint fallback removed (P0-4).
        final bool missingItems = generatedAgg.entries.any((MapEntry<String, int> e) {
          final int before = inventoryBefore[e.key] ?? 0;
          final int after = afterCounts[e.key] ?? 0;
          return e.value - (after - before) > 0;
        });
        if (missingItems) {
          state = state.copyWith(
            errorMessage: 'Toplama tamamlandı ama bazı eşyalar envantere düşmedi. Yenile.',
          );
        }

        await inventory.loadInventory(silent: true);
      }

      state = state.copyWith(isMutating: false);
      return result;
    } on AppException catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(isMutating: false, errorMessage: 'Toplama başarısız');
      return null;
    }
  }

  /// Rüşvet için açık tesis — en yüksek şüpheli aktif tesis.
  PlayerFacility? pickBribeTarget() {
    final List<PlayerFacility> active = state.facilities
        .where((PlayerFacility f) => f.isActive)
        .toList();
    if (active.isEmpty) return null;

    active.sort((PlayerFacility a, PlayerFacility b) => b.suspicion.compareTo(a.suspicion));
    return active.first;
  }

  Future<void> _syncGlobalSuspicionToServer() async {
    final int rawRisk = _calculateGlobalSuspicionRisk();
    await _repository.syncGlobalSuspicionLevel(globalSuspicion: rawRisk);
    await ref.read(playerProvider.notifier).loadProfile();
  }

  int _calculateGlobalSuspicionRisk() {
    final String? lastBribeAt = ref.read(playerProvider).profile?.lastBribeAt;
    final int bribeTs = DateTime.tryParse(lastBribeAt ?? '')?.millisecondsSinceEpoch ?? 0;

    int activeCount = 0;
    int levelSum = 0;

    for (final PlayerFacility facility in state.facilities) {
      final int? startedTs = DateTime.tryParse(facility.productionStartedAt ?? '')?.millisecondsSinceEpoch;
      if (startedTs != null && startedTs >= bribeTs) {
        activeCount++;
        levelSum += facility.level;
      }
    }

    int risk = (activeCount * 5) + (levelSum ~/ 2);
    final CharacterClass? charClass =
        ref.read(playerProvider).profile?.characterClass;
    if (charClass == CharacterClass.shadow) {
      risk = (risk * 0.70).floor();
    }
    if (risk < 0) return 0;
    if (risk > 100) return 100;
    return risk;
  }

  void clear() {
    state = FacilitiesState.initial();
  }
}

final NotifierProvider<FacilitiesNotifier, FacilitiesState> facilitiesProvider =
    NotifierProvider<FacilitiesNotifier, FacilitiesState>(FacilitiesNotifier.new);
