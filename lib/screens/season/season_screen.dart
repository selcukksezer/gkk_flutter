import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../components/layout/game_chrome.dart';
import '../../l10n/l10n.dart';
import '../../providers/battle_pass_provider.dart';
import '../../models/battle_pass.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import '../../theme/app_colors.dart';

class SeasonScreen extends ConsumerStatefulWidget {
  const SeasonScreen({super.key});

  @override
  ConsumerState<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends ConsumerState<SeasonScreen> {
  int _tabIndex = 0; // 0: Rewards, 1: Quests
  bool _vipBuying = false;

  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() {
      ref.read(battlePassProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(battlePassProvider);

    logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routeSeason, onLogout: logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.season,
        onLogout: logout,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? Center(child: Text('Hata: ${state.error}'))
          : state.activeSeason == null
          ? Center(child: Text(context.l10n.aktif_sezon_bulunamad))
          : Column(
              children: [
                _buildHeader(state),
                _buildTabs(),
                Expanded(
                  child: _tabIndex == 0
                      ? _buildRewardsList(state)
                      : _buildQuestsList(state),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(BattlePassState state) {
    final status = state.status;
    final season = state.activeSeason;
    final currentBpp = status?.currentBpp ?? 0;
    final level = status?.currentLevel ?? 0;
    final xpInCurrentLevel = currentBpp % 1000;
    final progress = xpInCurrentLevel / 1000.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: const Border(bottom: BorderSide(color: Colors.amber, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEZON ${season?.seasonNumber ?? 1}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Bitiş: ${season?.endAt.day}/${season?.endAt.month}/${season?.endAt.year}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              if (status?.hasVip ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VIP ACTIVE',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                _buildVipBuyButton(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BPP İlerlemesi',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          '$xpInCurrentLevel / 1000',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.amber,
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDailyCapItem(
                'Dungeon Limit',
                status?.dailyGrindBppPool ?? 0,
                300,
              ),
              _buildDailyCapItem(
                'PvP Limit',
                status?.dailyPvpBppPool ?? 0,
                200,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVipBuyButton() {
    return ElevatedButton.icon(
      onPressed: _vipBuying ? null : _buyVip,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.liquidGold,
        foregroundColor: AppColors.bgDeep,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: _vipBuying
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.diamond, size: 16),
      label: Text(
        _vipBuying ? 'SATIN ALINIYOR...' : 'VIP SATIN AL (500 💎)',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Future<void> _buyVip() async {
    setState(() => _vipBuying = true);
    try {
      final result = await ref.read(battlePassProvider.notifier).buyVipPass();
      if (!mounted) return;

      if (result['success'] == true) {
        AppMessenger.showSuccess(context, 'VIP Pass başarıyla aktif edildi!');
        // Player profilini de tazele (gem bakiyesi değişti)
        ref.read(playerProvider.notifier).loadProfile();
      } else {
        AppMessenger.showError(context, result['error'] ?? 'Bir hata oluştu.');
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(context, 'Hata: $e');
      }
    } finally {
      if (mounted) setState(() => _vipBuying = false);
    }
  }

  Widget _buildDailyCapItem(String label, int current, int max) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
        Text(
          '$current / $max',
          style: TextStyle(
            color: current >= max ? Colors.red : Colors.greenAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.black38,
      child: Row(
        children: [_buildTabItem(0, 'ÖDÜLLER'), _buildTabItem(1, 'GÖREVLER')],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? Colors.amber : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.amber : Colors.white60,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardsList(BattlePassState state) {
    final rewards = state.rewards;
    final status = state.status;

    return ListView.builder(
      itemCount: rewards.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final reward = rewards[index];
        final level = reward.level;
        final currentLevel = status?.currentLevel ?? 0;
        final reached = currentLevel >= level && level > 0;
        final claimedNormal = status?.claimedNormal.contains(level) ?? false;
        final claimedVip = status?.claimedVip.contains(level) ?? false;
        final hasVip = status?.hasVip ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: reached ? Colors.white.withOpacity(0.05) : Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: reached ? Colors.amber.withOpacity(0.3) : Colors.white10,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: reached
                      ? Colors.amber.withOpacity(0.1)
                      : Colors.black38,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'SEVİYE $level',
                      style: TextStyle(
                        color: reached ? Colors.amber : Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (!reached)
                      const Text(
                        'KİLİTLİ',
                        style: TextStyle(color: Colors.white24, fontSize: 10),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  // Normal Reward
                  Expanded(
                    child: _buildRewardCell(
                      title: 'ÜCRETSİZ',
                      reward: reward,
                      isVip: false,
                      isReached: reached,
                      isClaimed: claimedNormal,
                      canClaim: reached && !claimedNormal,
                    ),
                  ),
                  Container(width: 1, height: 80, color: Colors.white10),
                  // VIP Reward
                  Expanded(
                    child: _buildRewardCell(
                      title: 'VIP',
                      reward: reward,
                      isVip: true,
                      isReached: reached,
                      isClaimed: claimedVip,
                      canClaim: reached && hasVip && !claimedVip,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRewardCell({
    required String title,
    required BpLevelReward reward,
    required bool isVip,
    required bool isReached,
    required bool isClaimed,
    required bool canClaim,
  }) {
    final gold = isVip ? reward.vipRewardGold : reward.normalRewardGold;
    final itemName = isVip
        ? (reward.vipRewardItem?['name'] ?? 'Eşya')
        : (reward.normalRewardItem?['name'] ?? 'Eşya');
    final itemId = isVip ? reward.vipRewardItemId : reward.normalRewardItemId;
    final quantity = isVip
        ? reward.vipRewardQuantity
        : reward.normalRewardQuantity;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: isVip ? Colors.amber : Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (gold > 0)
            Text(
              '+$gold Gold',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
            ),
          if (itemId != null)
            Text(
              '$itemName x$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          const SizedBox(height: 8),
          if (isClaimed)
            const Icon(Icons.check_circle, color: Colors.green, size: 20)
          else if (canClaim)
            ElevatedButton(
              onPressed: () => _claim(reward.level, isVip),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 24),
              ),
              child: const Text(
                'AL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          else
            const Icon(Icons.lock, color: Colors.white24, size: 18),
        ],
      ),
    );
  }

  Widget _buildQuestsList(BattlePassState state) {
    final quests = state.quests;
    if (quests.isEmpty) {
      return const Center(child: Text('Aktif görev bulunamadı.'));
    }

    final sorted = [...quests]
      ..sort((a, b) {
        int rank(BpPlayerQuest q) {
          if (q.isCompleted && !q.rewardClaimed) return 0;
          if (!q.isCompleted) return 1;
          return 2;
        }

        final cmp = rank(a).compareTo(rank(b));
        if (cmp != 0) return cmp;
        return (b.currentProgress).compareTo(a.currentProgress);
      });

    return ListView.builder(
      itemCount: sorted.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final quest = sorted[index];
        final template = quest.template;
        final progress = (template?.targetCount ?? 1) > 0
            ? quest.currentProgress / template!.targetCount
            : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: quest.isCompleted
                  ? Colors.green.withOpacity(0.3)
                  : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: template?.questType == 'daily'
                          ? Colors.blue
                          : AppColors.cyberFuchsia,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      template?.questType == 'daily' ? 'GÜNLÜK' : 'HAFTALIK',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (quest.isCompleted && !quest.rewardClaimed)
                    ElevatedButton(
                      onPressed: () => _claimQuest(quest.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 28),
                      ),
                      child: Text(
                        '+${template?.bppReward ?? 0} BPP AL',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (quest.rewardClaimed)
                    const Text(
                      'ALINDI',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    )
                  else
                    Text(
                      '+${template?.bppReward ?? 0} BPP',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                template?.description ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          quest.isCompleted ? Colors.green : Colors.blue,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${quest.currentProgress} / ${template?.targetCount ?? 0}',
                    style: TextStyle(
                      color: quest.isCompleted ? Colors.green : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _claimQuest(String questId) async {
    final success = await ref
        .read(battlePassProvider.notifier)
        .claimQuestReward(questId);
    if (!mounted) return;

    if (success) {
      AppMessenger.showSuccess(context, 'Sezon görev ödülü alındı!');
    } else {
      AppMessenger.showError(context, 'Hata oluştu.');
    }
  }

  Future<void> _claim(int level, bool isVip) async {
    final success = await ref
        .read(battlePassProvider.notifier)
        .claimReward(level, isVip);
    if (!mounted) return;

    if (success) {
      AppMessenger.showSuccess(context, 'Ödül alındı!');
    } else {
      AppMessenger.showError(context, 'Hata oluştu.');
    }
  }
}
