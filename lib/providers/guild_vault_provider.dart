import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/guild_vault_model.dart';
import '../repositories/guild_vault_repository.dart';

final guildVaultRepositoryProvider = Provider<GuildVaultRepository>((Ref ref) {
  return GuildVaultRepository();
});

class GuildVaultNotifier extends Notifier<GuildVaultState> {
  GuildVaultRepository get _repo => ref.read(guildVaultRepositoryProvider);

  @override
  GuildVaultState build() => GuildVaultState.initial();

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final Map<String, dynamic> map = await _repo.getVault();
      if (map['success'] == false) {
        state = state.copyWith(
          isLoading: false,
          error: map['error']?.toString(),
        );
        return;
      }
      state = GuildVaultState.fromJson(map).copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Instant UI update after vault spend/credit (then [load] for truth).
  void applyGoldDelta(int delta) {
    final int next = (state.vaultGold + delta).clamp(0, 1 << 62);
    state = state.copyWith(vaultGold: next, hydrated: true);
  }

  void applyGoldAbsolute(int gold) {
    state = state.copyWith(vaultGold: gold.clamp(0, 1 << 62), hydrated: true);
  }

  Future<String?> collectRewards() async {
    try {
      final Map<String, dynamic> raw = await _repo.collectRewards();
      if (raw['success'] == false) return raw['error']?.toString();
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> distributeGoldEqual(int amount) async {
    return _distributeGold(<String, dynamic>{'mode': 'equal', 'amount': amount});
  }

  Future<String?> distributeGoldTargeted({
    required int totalAmount,
    required List<Map<String, dynamic>> allocations,
  }) async {
    return _distributeGold(<String, dynamic>{
      'mode': 'allocations',
      'amount': totalAmount,
      'allocations': allocations,
    });
  }

  Future<String?> _distributeGold(Map<String, dynamic> payload) async {
    try {
      final Map<String, dynamic> raw = await _repo.distributeGold(payload);
      if (raw['success'] == false) return raw['error']?.toString();
      final int? vaultAfter = raw['vault_gold'] is num ? (raw['vault_gold'] as num).toInt() : null;
      final int? amount = payload['amount'] is num ? (payload['amount'] as num).toInt() : null;
      if (vaultAfter != null) {
        applyGoldAbsolute(vaultAfter);
      } else if (amount != null && amount > 0) {
        applyGoldDelta(-amount);
      }
      await load(silent: true);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> distributeItem({
    required String vaultItemId,
    required String userId,
    required int quantity,
  }) async {
    try {
      final Map<String, dynamic> raw = await _repo.distributeItem(
        vaultItemId: vaultItemId,
        userId: userId,
        quantity: quantity,
      );
      if (raw['success'] == false) return raw['error']?.toString();
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setAutoPayout(bool enabled) async {
    try {
      final Map<String, dynamic> raw = await _repo.setAutoPayout(enabled);
      if (raw['success'] == false) return raw['error']?.toString();
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> depositGold(int amount) async {
    try {
      final Map<String, dynamic> raw = await _repo.depositGold(amount);
      if (raw['success'] == false) return raw['error']?.toString();
      final int? vaultAfter = raw['vault_gold'] is num ? (raw['vault_gold'] as num).toInt() : null;
      if (vaultAfter != null) {
        applyGoldAbsolute(vaultAfter);
      } else {
        applyGoldDelta(amount);
      }
      await load(silent: true);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final guildVaultProvider =
    NotifierProvider<GuildVaultNotifier, GuildVaultState>(GuildVaultNotifier.new);
