import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/battle_pass.dart';
import '../repositories/battle_pass_repository.dart';
class BattlePassState {
  final bool isLoading;
  final BpSeason? activeSeason;
  final BpPlayerStatus? status;
  final List<BpPlayerQuest> quests;
  final List<BpLevelReward> rewards;
  final String? error;

  const BattlePassState({
    this.isLoading = false,
    this.activeSeason,
    this.status,
    this.quests = const [],
    this.rewards = const [],
    this.error,
  });

  BattlePassState copyWith({
    bool? isLoading,
    BpSeason? activeSeason,
    BpPlayerStatus? status,
    List<BpPlayerQuest>? quests,
    List<BpLevelReward>? rewards,
    String? error,
  }) {
    return BattlePassState(
      isLoading: isLoading ?? this.isLoading,
      activeSeason: activeSeason ?? this.activeSeason,
      status: status ?? this.status,
      quests: quests ?? this.quests,
      rewards: rewards ?? this.rewards,
      error: error ?? this.error,
    );
  }
}

final battlePassRepositoryProvider = Provider((ref) => BattlePassRepository());

class BattlePassNotifier extends Notifier<BattlePassState> {
  BattlePassRepository get _repository => ref.read(battlePassRepositoryProvider);

  @override
  BattlePassState build() {
    return const BattlePassState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final season = await _repository.getActiveSeason();
      if (season == null) {
        state = state.copyWith(isLoading: false, activeSeason: null);
        return;
      }

      await _repository.ensureInitialized();

      final playerId = Supabase.instance.client.auth.currentUser?.id;
      if (playerId == null) {
        state = state.copyWith(isLoading: false, error: 'User not logged in');
        return;
      }

      final results = await Future.wait([
        _repository.getPlayerStatus(playerId, season.id),
        _repository.getPlayerQuests(playerId, season.id),
        _repository.getLevelRewards(),
      ]);

      state = state.copyWith(
        isLoading: false,
        activeSeason: season,
        status: results[0] as BpPlayerStatus?,
        quests: results[1] as List<BpPlayerQuest>,
        rewards: results[2] as List<BpLevelReward>,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> claimReward(int level, bool isVip) async {
    try {
      final result = await _repository.claimReward(level, isVip);
      if (result['success'] == true) {
        await loadAll(); // Refresh data
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// VIP Pass satın alır — gem bakiyesinden düşer, has_vip = true yapar
  Future<bool> claimQuestReward(String questId) async {
    try {
      final result = await _repository.claimQuestReward(questId);
      if (result['success'] == true) {
        await loadAll();
        return true;
      }
      state = state.copyWith(error: result['error']?.toString());
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> buyVipPass() async {
    try {
      final result = await _repository.buyVipPass();
      if (result['success'] == true) {
        await loadAll(); // Verileri tazele (hasVip güncellenecek)
      }
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }
}

final battlePassProvider = NotifierProvider<BattlePassNotifier, BattlePassState>(() {
  return BattlePassNotifier();
});

