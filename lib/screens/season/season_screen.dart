import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/universal_game_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/constants/economy_constants.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_anchor_registry.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../l10n/l10n.dart';
import '../../models/battle_pass.dart';
import '../../providers/auth_provider.dart';
import '../../providers/battle_pass_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'season_pass_logic.dart';
import 'widgets/season_banner_shader.dart';
import 'widgets/season_quest_card.dart';
import 'widgets/season_tier_track.dart';

/// 2027 Aion 2 Mobile Season Screen.
/// Modernized dual-tier battle pass track, cosmic animated banner shader,
/// real reward illustrations, responsive 390x844 layout, and full state preservation.
class SeasonScreen extends ConsumerStatefulWidget {
  const SeasonScreen({super.key});

  @override
  ConsumerState<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends ConsumerState<SeasonScreen>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0; // 0: Ödüller, 1: Görevler
  bool _vipBuying = false;
  bool _tutorialHooked = false;
  bool _autoScrolled = false;
  bool _claimingAll = false;
  final Set<String> _claiming = <String>{};
  final ScrollController _rewardsController = ScrollController();
  late final AnimationController _pulseController;
  Timer? _countdownTicker;

  /// Ödül satırı yaklaşık yüksekliği — auto-scroll hedefi için.
  static const double _rewardRowExtent = 148;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _countdownTicker = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) setState(() {});
    });

    deferProviderUpdate(() {
      ref.read(battlePassProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _pulseController.dispose();
    _rewardsController.dispose();
    super.dispose();
  }

  Future<void> _runSeasonTutorialHooks() async {
    if (_tutorialHooked || !mounted) return;
    final state = ref.read(battlePassProvider);
    if (state.isLoading || state.activeSeason == null) return;
    _tutorialHooked = true;
    final int level = state.status?.currentLevel ?? 0;
    TutorialTriggers.setPlayerLevelHint(ref, level);
    await TutorialTriggers.onRouteEnter(ref, AppRoutes.season);
  }

  /// İlk açılışta listeyi oyuncunun bulunduğu seviyeye kaydır.
  void _autoScrollToCurrentLevel(BattlePassState state) {
    if (!mounted || _autoScrolled || !_rewardsController.hasClients) return;
    final int currentLevel = state.status?.currentLevel ?? 0;
    if (currentLevel <= 2) {
      _autoScrolled = true;
      return;
    }
    final int index = state.rewards
        .indexWhere((BpLevelReward r) => r.level == currentLevel);
    if (index <= 0) return;
    _autoScrolled = true;
    final double target = ((index - 1) * _rewardRowExtent).clamp(
      0.0,
      _rewardsController.position.maxScrollExtent,
    );
    _rewardsController.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  /// Görevler tab tap -> next coach is L20 on Ödüller; flip tab + scroll.
  void _ensureRewardsTabForL20Coach() {
    final String? stepId = ref.read(tutorialProvider).activeStep?.id;
    if (stepId != 'season_l20_badge') return;
    if (_tabIndex != 0) {
      setState(() => _tabIndex = 0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToLevel20(ref.read(battlePassProvider));
    });
  }

  void _scrollToLevel20(BattlePassState state) {
    if (!mounted || !_rewardsController.hasClients) return;
    final int index =
        state.rewards.indexWhere((BpLevelReward r) => r.level == 20);
    if (index < 0) return;
    final double target = (index * _rewardRowExtent).clamp(
      0.0,
      _rewardsController.position.maxScrollExtent,
    );
    _rewardsController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    TutorialAnchorRegistry.instance.scheduleRefresh();
  }

  Future<void> _refresh() => ref.read(battlePassProvider.notifier).loadAll();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(battlePassProvider);
    ref.listen<TutorialState>(tutorialProvider, (
      TutorialState? prev,
      TutorialState next,
    ) {
      if (next.activeStep?.id == 'season_l20_badge' &&
          prev?.activeStep?.id != 'season_l20_badge') {
        _ensureRewardsTabForL20Coach();
      }
    });

    if (!state.isLoading && state.activeSeason != null && !_tutorialHooked) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _runSeasonTutorialHooks());
    }
    if (!state.isLoading && state.rewards.isNotEmpty && !_autoScrolled) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _autoScrollToCurrentLevel(state));
    }

    Future<void> logout() async {
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
      body: GameScreenBackground(
        child: SafeArea(
          bottom: false,
          child: state.isLoading && state.activeSeason == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.liquidGold),
                )
              : state.error != null && state.activeSeason == null
                  ? _errorState(state.error!)
                  : state.activeSeason == null
                      ? _emptyState()
                      : Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                              child: _buildBannerHeader(state),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                              child: _buildTabs(state),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: _buildClaimActionBar(state),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _refresh,
                                color: AppColors.liquidGold,
                                child: _tabIndex == 0
                                    ? _buildRewardsList(state)
                                    : _buildQuestsList(state),
                              ),
                            ),
                          ],
                        ),
        ),
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xE6141A28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.12),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: Color(0xFFF87171),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Savaş Geçidi Yüklenemedi',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(context.l10n.commonRetry),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.liquidGold,
                side: BorderSide(
                  color: AppColors.liquidGold.withValues(alpha: 0.6),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xE6141A28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.accentCyan.withValues(alpha: 0.1),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentCyan.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.military_tech_outlined,
                size: 42,
                color: AppColors.accentCyan,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.aktif_sezon_bulunamad,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Yeni sezon hazırlıkları sürüyor. Çok yakında Atreia semalarında!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header: Modern Animated Banner Shader ────────────────────────────────
  Widget _buildBannerHeader(BattlePassState state) {
    final season = state.activeSeason!;
    final Duration remaining = season.endAt.difference(DateTime.now());
    final int daysLeft = remaining.isNegative
        ? 0
        : (remaining.inHours > 0 && remaining.inDays == 0
            ? 1
            : remaining.inDays.clamp(0, 999));

    return SeasonBannerShader(
      state: state,
      daysLeft: daysLeft,
      onBuyVip: _buyVip,
      isVipBuying: _vipBuying,
    );
  }

  Future<void> _buyVip() async {
    final int cost = EconomyConstants.battlePassVipGemCost;
    final int gems = (ref.read(playerProvider).profile?.gems ?? 0).toInt();
    if (gems < cost) {
      AppMessenger.showError(
        context,
        'Yetersiz elmas ($gems/$cost). Mağazadan elmas alabilirsin.',
      );
      return;
    }

    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Daeva VIP Battle Pass',
      message: 'Sezon VIP Pass satın almak istediğine emin misin?\n'
          'Tüm Daeva özel ödüllerinin kilidi açılacaktır.\n\n'
          'Maliyet: $cost 💎',
      confirmLabel: 'Satın Al',
      cancelLabel: 'İptal',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _vipBuying = true);
    try {
      final result = await ref.read(battlePassProvider.notifier).buyVipPass();
      if (!mounted) return;

      if (result['success'] == true) {
        AppMessenger.showSuccess(
            context, '✨ Daeva VIP Pass başarıyla aktif edildi!');
        unawaited(ref.read(playerProvider.notifier).loadProfile());
      } else {
        AppMessenger.showError(
          context,
          result['error']?.toString() ?? 'Satın alma başarısız.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Bağlantı hatası — tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _vipBuying = false);
    }
  }

  // ─── Tabs: 2027 Aion 2 Frosted Glass Segmented Control ─────────────────────
  Widget _buildTabs(BattlePassState state) {
    final int claimableRewards = SeasonPassLogic.countClaimableRewards(
      status: state.status,
      rewards: state.rewards,
    );
    final int claimableQuests = state.quests
        .where((BpPlayerQuest q) => q.isCompleted && !q.rewardClaimed)
        .length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          _buildTabItem(0, 'ÖDÜL PARKURU', claimableRewards),
          _buildTabItem(1, 'SEZON GÖREVLERİ', claimableQuests),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, int badgeCount) {
    final bool active = _tabIndex == index;
    Widget tab = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        setState(() => _tabIndex = index);
        if (index == 1) {
          await TutorialTriggers.onAnchorTap(
            ref,
            TutorialAnchorId.seasonQuestsTab,
          );
          if (!mounted) return;
          _ensureRewardsTabForL20Coach();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: active
              ? LinearGradient(
                  colors: <Color>[
                    AppColors.liquidGold.withValues(alpha: 0.28),
                    AppColors.liquidGold.withValues(alpha: 0.10),
                  ],
                )
              : null,
          border: Border.all(
            color: active
                ? AppColors.liquidGold.withValues(alpha: 0.6)
                : Colors.transparent,
            width: active ? 1.0 : 0.0,
          ),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.liquidGold : const Color(0xFF64748B),
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 0.7,
              ),
            ),
            if (badgeCount > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (index == 1) {
      tab = TutorialAnchorScope(
        id: TutorialAnchorId.seasonQuestsTab,
        child: tab,
      );
    }
    return Expanded(child: tab);
  }

  // ─── Quick Actions & Pass Progress Bar ────────────────────────────────────
  Widget _buildClaimActionBar(BattlePassState state) {
    final status = state.status;
    final int currentLevel = status?.currentLevel ?? 0;
    final int currentBpp = status?.currentBpp ?? 0;
    final double levelProgress =
        SeasonPassLogic.calculateLevelProgress(currentBpp);
    final int inLevel = SeasonPassLogic.calculateXpInCurrentLevel(currentBpp);

    if (_tabIndex == 0) {
      final int claimable = SeasonPassLogic.countClaimableRewards(
        status: status,
        rewards: state.rewards,
      );

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xE6141A28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: claimable > 0
                ? AppColors.liquidGold.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            if (claimable > 0)
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: <Widget>[
            // Left: Level badge & Progress
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                'SV $currentLevel',
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    claimable > 0
                        ? '$claimable Ödül Alınabilir!'
                        : 'Seviye $currentLevel ($inLevel/1000 BPP)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: claimable > 0
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight:
                          claimable > 0 ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: levelProgress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        claimable > 0
                            ? const Color(0xFF4ADE80)
                            : AppColors.liquidGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right: Claim All Button or Status Pill
            if (claimable > 0)
              GestureDetector(
                onTap: _claimingAll ? null : () => _claimAllRewards(state),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (BuildContext context, Widget? child) {
                    final double glow = 0.2 + (_pulseController.value * 0.25);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFFFFD700),
                            Color(0xFFF59E0B),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.liquidGold.withValues(alpha: glow),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: _claimingAll
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1E1B18),
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 13,
                                  color: Color(0xFF1E1B18),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'TÜMÜNÜ AL',
                                  style: TextStyle(
                                    color: Color(0xFF1E1B18),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 11,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'TÜMÜ ALINDI',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 9.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } else {
      // Görevler Tab
      final int completedCount =
          state.quests.where((BpPlayerQuest q) => q.isCompleted).length;
      final int claimableQuests = state.quests
          .where((BpPlayerQuest q) => q.isCompleted && !q.rewardClaimed)
          .length;
      final int totalQuests = state.quests.length;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xE6141A28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: claimableQuests > 0
                ? const Color(0xFF4ADE80).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            if (claimableQuests > 0)
              BoxShadow(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFC084FC).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFC084FC).withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: const Text(
                'GÖREVLER',
                style: TextStyle(
                  color: Color(0xFFC084FC),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    claimableQuests > 0
                        ? '$claimableQuests Görev Ödülü Hazır!'
                        : '$completedCount / $totalQuests Görev Tamamlandı',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: claimableQuests > 0
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight:
                          claimableQuests > 0 ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value:
                          totalQuests > 0 ? (completedCount / totalQuests) : 0,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        claimableQuests > 0
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFC084FC),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (claimableQuests > 0)
              GestureDetector(
                onTap: _claimingAll ? null : () => _claimAllQuests(state),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (BuildContext context, Widget? child) {
                    final double glow = 0.2 + (_pulseController.value * 0.25);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[
                            Color(0xFF22C55E),
                            Color(0xFF16A34A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: glow),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: _claimingAll
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'GÖREVLERİ AL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 11,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'GÜNCEL',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 9.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
  }

  // ─── Dual-Tier Battle Pass Rewards List ────────────────────────────────────
  Widget _buildRewardsList(BattlePassState state) {
    final rewards = state.rewards;
    final status = state.status;

    if (rewards.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 120),
          Center(
            child: Text(
              'Sezon ödülleri henüz tanımlanmadı.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _rewardsController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rewards.length,
      padding:
          GameScrollLayout.withClearance(context, const EdgeInsets.all(12)),
      itemBuilder: (BuildContext context, int index) {
        final BpLevelReward reward = rewards[index];
        final int level = reward.level;
        final int currentLevel = status?.currentLevel ?? 0;
        final bool reached = currentLevel >= level && level > 0;
        final bool isCurrent = currentLevel == level;
        final bool claimedNormal =
            status?.claimedNormal.contains(level) ?? false;
        final bool claimedVip = status?.claimedVip.contains(level) ?? false;
        final bool hasVip = status?.hasVip ?? false;

        Widget row = SeasonTierTrackRow(
          reward: reward,
          reached: reached,
          isCurrent: isCurrent,
          claimedNormal: claimedNormal,
          claimedVip: claimedVip,
          hasVip: hasVip,
          claimingFree: _claiming.contains('r_${level}_free'),
          claimingVip: _claiming.contains('r_${level}_vip'),
          onClaimFree: () => _claim(level, false),
          onClaimVip: () => _claim(level, true),
          isLast: index == rewards.length - 1,
        );

        if (level == 20) {
          row = TutorialAnchorScope(
            id: TutorialAnchorId.seasonL20Reward,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => TutorialTriggers.onAnchorTap(
                ref,
                TutorialAnchorId.seasonL20Reward,
              ),
              child: row,
            ),
          );
        }
        return row;
      },
    );
  }

  Future<void> _claim(int level, bool isVip) async {
    final String key = 'r_${level}_${isVip ? 'vip' : 'free'}';
    if (_claiming.contains(key)) return;
    setState(() => _claiming.add(key));
    try {
      final bool success =
          await ref.read(battlePassProvider.notifier).claimReward(level, isVip);
      if (!mounted) return;

      if (success) {
        AppMessenger.showSuccess(
            context, '🎁 Seviye $level ${isVip ? 'Daeva VIP ' : ''}ödülü alındı!');
        if (level == 20 && !isVip) {
          AppMessenger.show(
            context,
            'Rozet envanterinde — Karakter ekranındaki Rozet Vitrini\'nde görünür.',
          );
        }
      } else {
        AppMessenger.showError(context, 'Ödül alınamadı — tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _claiming.remove(key));
    }
  }

  Future<void> _claimAllRewards(BattlePassState state) async {
    if (_claimingAll || !mounted) return;
    final status = state.status;
    if (status == null) return;

    final int currentLevel = status.currentLevel;
    final bool hasVip = status.hasVip;
    final Set<int> claimedNormal = status.claimedNormal.toSet();
    final Set<int> claimedVip = status.claimedVip.toSet();

    final List<MapEntry<int, bool>> toClaim = <MapEntry<int, bool>>[];
    for (final BpLevelReward r in state.rewards) {
      if (r.level <= 0 || r.level > currentLevel) continue;
      if (!claimedNormal.contains(r.level)) {
        toClaim.add(MapEntry<int, bool>(r.level, false));
      }
      if (hasVip && !claimedVip.contains(r.level)) {
        toClaim.add(MapEntry<int, bool>(r.level, true));
      }
    }

    if (toClaim.isEmpty) {
      AppMessenger.show(context, 'Alınabilecek yeni ödül bulunmuyor.');
      return;
    }

    setState(() => _claimingAll = true);
    int claimedCount = 0;
    bool claimedL20 = false;

    try {
      for (final MapEntry<int, bool> entry in toClaim) {
        if (!mounted) break;
        final int level = entry.key;
        final bool isVip = entry.value;
        final String key = 'r_${level}_${isVip ? 'vip' : 'free'}';
        _claiming.add(key);

        final bool ok = await ref
            .read(battlePassProvider.notifier)
            .claimReward(level, isVip);
        if (ok) {
          claimedCount++;
          if (level == 20 && !isVip) claimedL20 = true;
        }
        _claiming.remove(key);
      }

      if (!mounted) return;

      if (claimedCount > 0) {
        AppMessenger.showSuccess(
          context,
          '✨ $claimedCount adet sezon ödülü başarıyla toplandı!',
        );
        if (claimedL20) {
          AppMessenger.show(
            context,
            'Rozet envanterinde — Karakter ekranındaki Rozet Vitrini\'nde görünür.',
          );
        }
      } else {
        AppMessenger.showError(context, 'Ödüller toplanamadı — tekrar deneyin.');
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Bağlantı hatası oluştu.');
      }
    } finally {
      if (mounted) {
        setState(() => _claimingAll = false);
      }
    }
  }

  // ─── Quests List ──────────────────────────────────────────────────────────
  Widget _buildQuestsList(BattlePassState state) {
    final quests = state.quests;
    if (quests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 120),
          Center(
            child: Text(
              'Aktif sezon görevi bulunamadı.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
        ],
      );
    }

    final List<BpPlayerQuest> sorted = SeasonPassLogic.sortQuests(quests);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sorted.length,
      padding:
          GameScrollLayout.withClearance(context, const EdgeInsets.all(12)),
      itemBuilder: (BuildContext context, int index) {
        final BpPlayerQuest quest = sorted[index];
        return SeasonQuestCard(
          quest: quest,
          claiming: _claiming.contains('q_${quest.id}'),
          onClaim: () => _claimQuest(quest.id),
        );
      },
    );
  }

  Future<void> _claimQuest(String questId) async {
    final String key = 'q_$questId';
    if (_claiming.contains(key)) return;
    setState(() => _claiming.add(key));
    try {
      final bool success = await ref
          .read(battlePassProvider.notifier)
          .claimQuestReward(questId);
      if (!mounted) return;

      if (success) {
        AppMessenger.showSuccess(context, '🎁 Sezon görev ödülü alındı!');
      } else {
        AppMessenger.showError(context, 'Ödül alınamadı — tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _claiming.remove(key));
    }
  }

  Future<void> _claimAllQuests(BattlePassState state) async {
    if (_claimingAll || !mounted) return;
    final List<BpPlayerQuest> toClaim = state.quests
        .where((BpPlayerQuest q) => q.isCompleted && !q.rewardClaimed)
        .toList();

    if (toClaim.isEmpty) {
      AppMessenger.show(context, 'Alınabilecek görev ödülü bulunmuyor.');
      return;
    }

    setState(() => _claimingAll = true);
    int claimedCount = 0;

    try {
      for (final BpPlayerQuest quest in toClaim) {
        if (!mounted) break;
        final String key = 'q_${quest.id}';
        _claiming.add(key);

        final bool ok = await ref
            .read(battlePassProvider.notifier)
            .claimQuestReward(quest.id);
        if (ok) {
          claimedCount++;
        }
        _claiming.remove(key);
      }

      if (!mounted) return;

      if (claimedCount > 0) {
        AppMessenger.showSuccess(
          context,
          '✨ $claimedCount adet sezon görevi ödülü toplandı!',
        );
      } else {
        AppMessenger.showError(context, 'Görev ödülleri toplanamadı.');
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Bağlantı hatası oluştu.');
      }
    } finally {
      if (mounted) {
        setState(() => _claimingAll = false);
      }
    }
  }
}
