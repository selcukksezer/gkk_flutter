import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/gkk_tab_bar.dart';
import '../../components/common/gkk_tab_page_shell.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../models/quest_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_inbox_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'quest_banner_shader.dart';
import 'quest_card.dart';
import 'quest_detail_modal.dart';
import 'quest_logic.dart';

// ── Category tabs ─────────────────────────────────────────────────────────────
enum _QuestCategory { all, daily, weekly, main }

// ── Secondary status filter pills ─────────────────────────────────────────────
enum _StatusFilter { all, claimable, active }

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<QuestData> _quests = [];
  bool _loading = true;
  String? _error;
  _QuestCategory _category = _QuestCategory.all;
  _StatusFilter _statusFilter = _StatusFilter.all;
  bool _actionLoading = false;
  final Set<String> _knownCompletedSeasonQuests = {};

  late final TabController _tabCtrl;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      HapticFeedback.selectionClick();
      setState(() => _category = _QuestCategory.values[_tabCtrl.index]);
    });
    // 30-second tick to keep daily reset timer fresh
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _loadQuests();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadQuests(silent: true));
    }
  }

  Future<void> _loadQuests({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final level = ref.read(playerProvider).profile?.level ?? 1;
      final res = await SupabaseService.client.rpc(
        'get_available_quests',
        params: {'p_player_level': level},
      );
      final list = (res as List)
          .map((e) => QuestData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final redirectSeasonQuestId = QuestLogic.detectNewCompletedSeasonQuest(
        list,
        _knownCompletedSeasonQuests,
      );
      if (redirectSeasonQuestId != null) {
        _knownCompletedSeasonQuests.add(redirectSeasonQuestId);
      }

      if (mounted) {
        setState(() {
          _quests = list;
          _loading = false;
          _error = null;
        });
        if (redirectSeasonQuestId != null) {
          _snack('🏆 Sezon görevi tamamlandı! Ödülü sezon sayfasından al.');
          context.go(AppRoutes.season);
        }
        await TutorialTriggers.onRouteEnter(ref, AppRoutes.quests);
        unawaited(ref.read(notificationInboxProvider.notifier).refresh());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFacingErrorMessage(e, fallback: 'Görevler yüklenemedi.');
        });
      }
    }
  }

  Future<void> _claimReward(QuestData quest) async {
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client.rpc(
        'claim_quest_reward',
        params: {'p_quest_id': quest.questId},
      );
      HapticFeedback.heavyImpact();
      _snack(QuestLogic.formatClaimMessage(quest));
      _quests.removeWhere((q) => q.questId == quest.questId);
      if (mounted) setState(() {});
      ref.read(playerProvider.notifier).loadProfile();
    } catch (e) {
      _snack(
        userFacingErrorMessage(e, fallback: 'Ödül alınamadı.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  /// One-tap batch claim for all completed non-season quests.
  Future<void> _claimAllRewards() async {
    if (_actionLoading) return;
    final claimable = _quests
        .where((q) => q.status == QuestStatus.completed && !q.isSeasonQuest)
        .toList();
    if (claimable.isEmpty) return;

    setState(() => _actionLoading = true);
    HapticFeedback.mediumImpact();

    int claimedCount = 0;
    int totalGold = 0;
    int totalXp = 0;
    int totalGems = 0;
    final claimedIds = <String>{};
    String? lastError;

    for (final quest in claimable) {
      try {
        await SupabaseService.client.rpc(
          'claim_quest_reward',
          params: {'p_quest_id': quest.questId},
        );
        claimedCount++;
        totalGold += quest.goldReward;
        totalXp += quest.xpReward;
        totalGems += quest.gemReward;
        claimedIds.add(quest.questId);
      } catch (e) {
        lastError = userFacingErrorMessage(e, fallback: 'Bazı ödüller alınamadı.');
      }
    }

    if (claimedCount > 0) {
      HapticFeedback.heavyImpact();
      _quests.removeWhere((q) => claimedIds.contains(q.questId));

      final parts = <String>[];
      if (totalGold > 0) parts.add('🪙 +$totalGold Altın');
      if (totalXp > 0) parts.add('✨ +$totalXp XP');
      if (totalGems > 0) parts.add('💎 +$totalGems Elmas');

      final rewardText = parts.isNotEmpty ? ': ${parts.join(', ')}' : '!';
      _snack('🎉 $claimedCount Görev Ödülü Toplandı$rewardText');
      ref.read(playerProvider.notifier).loadProfile();
    } else if (lastError != null) {
      _snack(lastError, isError: true);
    }

    if (mounted) {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _completeQuest(QuestData quest) async {
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client.rpc(
        'complete_quest',
        params: {'p_quest_id': quest.questId},
      );
      HapticFeedback.mediumImpact();
      _snack('✅ Görev tamamlandı!');
      await _loadQuests();
      ref.read(playerProvider.notifier).loadProfile();
    } catch (e) {
      _snack(
        userFacingErrorMessage(e, fallback: 'Görev tamamlanamadı.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppMessenger.showError(context, msg);
    } else {
      AppMessenger.showSuccess(context, msg);
    }
  }

  List<QuestData> _questsForCategory(_QuestCategory cat) {
    return QuestLogic.filterByCategory(
      _quests,
      QuestCategory.values[cat.index],
    );
  }

  List<QuestData> get _filteredByCategory => _questsForCategory(_category);

  List<QuestData> get _filtered {
    final list = _filteredByCategory;
    return switch (_statusFilter) {
      _StatusFilter.all => list,
      _StatusFilter.claimable =>
        list.where((q) => q.status == QuestStatus.completed).toList(),
      _StatusFilter.active =>
        list.where((q) => q.status == QuestStatus.active).toList(),
    };
  }

  List<QuestData> get _sortedFiltered => QuestLogic.sortQuests(_filtered);

  double get _completionRate =>
      QuestLogic.calculateOverallCompletionRate(_quests);

  int get _completedOrReadyCount => QuestLogic.countCompletedOrReady(_quests);

  int get _allClaimableNonSeasonCount => _quests
      .where((q) => q.status == QuestStatus.completed && !q.isSeasonQuest)
      .length;

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _completedOrReadyCount;
    final sorted = _sortedFiltered;
    final claimableAllCount = _allClaimableNonSeasonCount;

    final int? claimTutorialIndex = () {
      for (int i = 0; i < sorted.length; i++) {
        if (sorted[i].status == QuestStatus.completed) return i;
      }
      return null;
    }();

    final sectionAccent = switch (_category) {
      _QuestCategory.all => const Color(0xFF818CF8),
      _QuestCategory.daily => const Color(0xFFFBBF24),
      _QuestCategory.weekly => const Color(0xFF38BDF8),
      _QuestCategory.main => const Color(0xFFA855F7),
    };

    final sectionTitle = switch (_category) {
      _QuestCategory.all => 'Tüm Görevler',
      _QuestCategory.daily => 'Günlük Keşifler',
      _QuestCategory.weekly => 'Haftalık Seferler',
      _QuestCategory.main => 'Destansı & Zindan Görevleri',
    };

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.screenTitleQuests,
        onLogout: _doLogout,
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.quests,
        onLogout: _doLogout,
      ),
      backgroundColor: AppColors.bgDeep,
      body: GameScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  // ── Animated Celestial Banner Shader ─────────────────────────
                  QuestBannerShader(
                    completionRate: _completionRate,
                    completedCount: completedCount,
                    totalQuests: _quests.length,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (_quests.isNotEmpty) {
                        _showDetail(_quests.first);
                      }
                    },
                  ),

                  // ── Cyber-Glass Status & Reset Sub-Header ────────────────────
                  _buildSubHeader(claimableAllCount),

                  // ── 2027 Aion 2 Category Tabs ────────────────────────────────
                  _buildCategoryTabs(),

                  // ── Secondary Quick Status Filter (Tümü / Hazır / Aktif) ─────
                  _buildStatusFilterRow(),

                  const SizedBox(height: 4),

                  // ── Quests List Body ─────────────────────────────────────────
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _tabCtrl,
                      builder: (context, _) {
                        return GkkTabPageShell(
                          tabIndex: _tabCtrl.index,
                          sectionTitle: sectionTitle,
                          sectionAccent: sectionAccent,
                          child: _loading
                              ? _buildSkeletonLoading()
                              : _error != null
                                  ? _buildError()
                                  : sorted.isEmpty
                                      ? _buildEmpty()
                                      : RefreshIndicator(
                                          onRefresh: _loadQuests,
                                          color: const Color(0xFF38BDF8),
                                          backgroundColor:
                                              const Color(0xFF0F172A),
                                          child: ListView.builder(
                                            padding: GameScrollLayout.fromLTRB(
                                              context,
                                              left: 0,
                                              top: 2,
                                              right: 0,
                                              bottomExtra:
                                                  claimableAllCount > 0
                                                      ? 72
                                                      : 16,
                                            ),
                                            itemCount: sorted.length,
                                            itemBuilder: (_, i) =>
                                                GkkTabStaggerItem(
                                              index: i,
                                              child: QuestCard(
                                                quest: sorted[i],
                                                actionLoading: _actionLoading,
                                                highlightClaimAnchor:
                                                    i == claimTutorialIndex,
                                                onComplete: () =>
                                                    _completeQuest(sorted[i]),
                                                onClaim: () =>
                                                    _claimReward(sorted[i]),
                                                onGoToSeason: () =>
                                                    context.go(AppRoutes.season),
                                                onDetail: () =>
                                                    _showDetail(sorted[i]),
                                              ),
                                            ),
                                          ),
                                        ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubHeader(int claimableCount) {
    final countdown = QuestLogic.formatDailyResetCountdown();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claimableCount > 0
              ? const Color(0xFF10B981).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: claimableCount > 0
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Daily reset countdown
          const Icon(
            Icons.schedule_rounded,
            size: 14,
            color: Color(0xFF38BDF8),
          ),
          const SizedBox(width: 5),
          Text(
            'Sıfırlanma: $countdown',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // If claimable quests exist, prominent "Claim All" button
          if (claimableCount > 0)
            GestureDetector(
              onTap: _actionLoading ? null : _claimAllRewards,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_actionLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Colors.white,
                        ),
                      )
                    else ...[
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tümünü Al ($claimableCount)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_completedOrReadyCount}/${_quests.length} Hazır',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final tabs = [
      (Icons.grid_view_rounded, 'Tümü', _QuestCategory.all),
      (Icons.wb_sunny_rounded, 'Günlük', _QuestCategory.daily),
      (Icons.date_range_rounded, 'Haftalık', _QuestCategory.weekly),
      (Icons.auto_awesome_rounded, 'Destansı', _QuestCategory.main),
    ];

    return GkkTabBar(
      controller: _tabCtrl,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      tabs: tabs.map((t) {
        final catQuests = _questsForCategory(t.$3);
        final count = catQuests.length;
        final hasClaimable =
            catQuests.any((q) => q.status == QuestStatus.completed);

        return GkkTabBar.labeledTab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(t.$1, size: 12.5),
              const SizedBox(width: 4),
              Text(t.$2),
              if (count > 0) ...[
                const SizedBox(width: 4.5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: hasClaimable
                        ? const Color(0xFF10B981).withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: hasClaimable
                        ? Border.all(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.7),
                            width: 0.8,
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasClaimable) ...[
                        const Icon(
                          Icons.circle,
                          size: 5,
                          color: Color(0xFF34D399),
                        ),
                        const SizedBox(width: 2.5),
                      ],
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: hasClaimable
                              ? const Color(0xFF34D399)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusFilterRow() {
    final catList = _filteredByCategory;
    final totalInCat = catList.length;
    final claimableInCat =
        catList.where((q) => q.status == QuestStatus.completed).length;
    final activeInCat =
        catList.where((q) => q.status == QuestStatus.active).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Tümü ($totalInCat)',
            selected: _statusFilter == _StatusFilter.all,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _statusFilter = _StatusFilter.all);
            },
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'Ödülü Hazır ($claimableInCat)',
            selected: _statusFilter == _StatusFilter.claimable,
            highlightBadge: claimableInCat > 0,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _statusFilter = _StatusFilter.claimable);
            },
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            label: 'Devam Eden ($activeInCat)',
            selected: _statusFilter == _StatusFilter.active,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _statusFilter = _StatusFilter.active);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool highlightBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected
              ? (highlightBadge
                  ? const Color(0xFF10B981).withValues(alpha: 0.22)
                  : const Color(0xFF38BDF8).withValues(alpha: 0.2))
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? (highlightBadge
                    ? const Color(0xFF10B981).withValues(alpha: 0.6)
                    : const Color(0xFF38BDF8).withValues(alpha: 0.6))
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.0 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected
                ? (highlightBadge
                    ? const Color(0xFF34D399)
                    : const Color(0xFF38BDF8))
                : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.25),
                    const Color(0xFF6366F1).withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aion Parşömenleri Taranıyor...',
              style: TextStyle(
                color: Color(0xFFF1F5F9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aktif ve bekleyen görevler senkronize ediliyor',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFF87171),
                size: 38,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _error ?? 'Görevler yüklenemedi.',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _loadQuests,
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: Colors.white),
                label: const Text(
                  'Tekrar Dene',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final isFiltered = _statusFilter != _StatusFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    const Color(0xFF6366F1).withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_list_off_rounded
                    : Icons.auto_awesome_rounded,
                color: const Color(0xFF38BDF8),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? 'Kriterlere Uygun Görev Yok'
                  : 'Aktif Keşif Bulunamadı',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Seçili filtrede ("${_statusFilter == _StatusFilter.claimable ? 'Ödülü Hazır' : 'Devam Eden'}") henüz görev yok.'
                  : 'Bu sekmede henüz görev yok. Diğer sekmeleri inceleyin veya yenileyin.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            if (isFiltered)
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _statusFilter = _StatusFilter.all);
                },
                icon: const Icon(Icons.clear_all_rounded, size: 15),
                label: const Text('Filtreyi Temizle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF38BDF8).withValues(alpha: 0.18),
                  foregroundColor: const Color(0xFF38BDF8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _loadQuests,
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Yenile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: BorderSide(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetail(QuestData quest) {
    showQuestDetailModal(
      context: context,
      quest: quest,
      actionLoading: _actionLoading,
      onClaim: () => _claimReward(quest),
      onComplete: () => _completeQuest(quest),
      onGoToSeason: () => context.go(AppRoutes.season),
    );
  }
}
