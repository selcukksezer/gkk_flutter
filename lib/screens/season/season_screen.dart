import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/item_icon_view.dart';
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

/// Savaş Geçidi renk paleti.
class _BpColors {
  static const Color gold = AppColors.liquidGold;
  static const Color cyan = AppColors.accentCyan;
  static const Color green = Color(0xFF4ADE80);
  static const Color textHi = Colors.white;
  static const Color textMid = Color(0xFFB8C0D4);
  static const Color textLow = Color(0xFF6B7488);
  static const Color cardBg = Color(0xE61A2032);
  static const Color cardBgDim = Color(0xB3121826);
}

class SeasonScreen extends ConsumerStatefulWidget {
  const SeasonScreen({super.key});

  @override
  ConsumerState<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends ConsumerState<SeasonScreen> {
  int _tabIndex = 0; // 0: Ödüller, 1: Görevler
  bool _vipBuying = false;
  bool _tutorialHooked = false;
  bool _autoScrolled = false;
  final Set<String> _claiming = <String>{};
  final ScrollController _rewardsController = ScrollController();

  /// Ödül satırı yaklaşık yüksekliği — auto-scroll hedefi için.
  static const double _rewardRowExtent = 132;

  @override
  void initState() {
    super.initState();
    deferProviderUpdate(() {
      ref.read(battlePassProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
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
    if (_autoScrolled || !_rewardsController.hasClients) return;
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

  /// Görevler tab tap → next coach is L20 on Ödüller; flip tab + scroll.
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
    if (!_rewardsController.hasClients) return;
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
        child: state.isLoading && state.activeSeason == null
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.activeSeason == null
                ? _errorState(state.error!)
                : state.activeSeason == null
                    ? _emptyState()
                    : Column(
                        children: <Widget>[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: _buildHeader(state),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 10, 12, 4),
                            child: _buildTabs(state),
                          ),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _refresh,
                              color: _BpColors.gold,
                              child: _tabIndex == 0
                                  ? _buildRewardsList(state)
                                  : _buildQuestsList(state),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: _BpColors.textLow),
          const SizedBox(height: 10),
          const Text(
            'Savaş Geçidi yüklenemedi.',
            style: TextStyle(color: _BpColors.textMid, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(context.l10n.commonRetry),
            style: OutlinedButton.styleFrom(
              foregroundColor: _BpColors.gold,
              side: BorderSide(color: _BpColors.gold.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.military_tech_outlined,
              size: 48, color: _BpColors.textLow),
          const SizedBox(height: 10),
          Text(
            context.l10n.aktif_sezon_bulunamad,
            style: const TextStyle(color: _BpColors.textMid, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BattlePassState state) {
    final status = state.status;
    final season = state.activeSeason!;
    final int currentBpp = status?.currentBpp ?? 0;
    final int level = status?.currentLevel ?? 0;
    final int xpInCurrentLevel = currentBpp % 1000;
    final double progress = xpInCurrentLevel / 1000.0;
    final bool hasVip = status?.hasVip ?? false;
    final int daysLeft =
        season.endAt.difference(DateTime.now()).inDays.clamp(0, 999);

    return TutorialAnchorScope(
      id: TutorialAnchorId.seasonHeader,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.seasonHeader),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _BpColors.cardBg,
                AppColors.carbonVoid.withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(
              color: _BpColors.gold.withValues(alpha: hasVip ? 0.55 : 0.3),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _BpColors.gold.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.military_tech_rounded,
                      color: _BpColors.gold, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'SEZON ${season.seasonNumber}',
                          style: GoogleFonts.urbanist(
                            color: _BpColors.gold,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          daysLeft > 0
                              ? '$daysLeft gün kaldı'
                              : 'Bugün bitiyor',
                          style: const TextStyle(
                            color: _BpColors.textMid,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasVip) _vipActiveBadge() else _buildVipBuyButton(),
                ],
              ),
              const SizedBox(height: 14),
              TutorialAnchorScope(
                id: TutorialAnchorId.seasonBppBar,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => TutorialTriggers.onAnchorTap(
                    ref,
                    TutorialAnchorId.seasonBppBar,
                  ),
                  child: Row(
                    children: <Widget>[
                      _levelRing(level, progress),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                const Text(
                                  'BPP İLERLEMESİ',
                                  style: TextStyle(
                                    color: _BpColors.textMid,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  '$xpInCurrentLevel / 1000',
                                  style: const TextStyle(
                                    color: _BpColors.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _gradientBar(
                              progress,
                              const <Color>[
                                Color(0xFFB8860B),
                                _BpColors.gold,
                                Color(0xFFFFE9A0),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _dailyCapBar(
                      icon: '🏰',
                      label: 'Zindan BPP',
                      current: status?.dailyGrindBppPool ?? 0,
                      max: 300,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dailyCapBar(
                      icon: '⚔️',
                      label: 'PvP BPP',
                      current: status?.dailyPvpBppPool ?? 0,
                      max: 200,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vipActiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: AppColors.liquidGoldGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _BpColors.gold.withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.workspace_premium_rounded,
              size: 14, color: AppColors.carbonVoid),
          SizedBox(width: 4),
          Text(
            'VIP AKTİF',
            style: TextStyle(
              color: AppColors.carbonVoid,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelRing(int level, double progress) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_BpColors.gold),
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _BpColors.gold.withValues(alpha: 0.12),
              border: Border.all(
                color: _BpColors.gold.withValues(alpha: 0.6),
              ),
            ),
            child: Center(
              child: Text(
                '$level',
                style: GoogleFonts.urbanist(
                  color: _BpColors.gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBar(double value, List<Color> colors, {double height = 9}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: <Widget>[
          Container(
            height: height,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyCapBar({
    required String icon,
    required String label,
    required int current,
    required int max,
  }) {
    final bool capped = current >= max;
    final Color color = capped ? AppColors.danger : _BpColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _BpColors.textMid,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                capped ? 'DOLDU' : '$current/$max',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _gradientBar(
            max > 0 ? current / max : 0,
            <Color>[color.withValues(alpha: 0.6), color],
            height: 5,
          ),
        ],
      ),
    );
  }

  // ─── VIP satın alma ──────────────────────────────────────────────────────

  Widget _buildVipBuyButton() {
    final int cost = EconomyConstants.battlePassVipGemCost;
    return GestureDetector(
      onTap: _vipBuying ? null : _buyVip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: _vipBuying ? null : AppColors.liquidGoldGradient,
          color: _vipBuying
              ? AppColors.darkObsidian.withValues(alpha: 0.6)
              : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: _vipBuying
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: _BpColors.gold.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: _vipBuying
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _BpColors.gold,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.diamond,
                      size: 14, color: AppColors.carbonVoid),
                  const SizedBox(width: 4),
                  Text(
                    'VIP AL · $cost',
                    style: const TextStyle(
                      color: AppColors.carbonVoid,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
      ),
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
      title: 'VIP Battle Pass',
      message: 'Sezon VIP Pass satın almak istediğine emin misin?\n'
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
        AppMessenger.showSuccess(context, 'VIP Pass başarıyla aktif edildi!');
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

  // ─── Tablar ──────────────────────────────────────────────────────────────

  Widget _buildTabs(BattlePassState state) {
    final status = state.status;
    final int currentLevel = status?.currentLevel ?? 0;
    final bool hasVip = status?.hasVip ?? false;

    int claimableRewards = 0;
    for (final BpLevelReward r in state.rewards) {
      if (r.level <= 0 || r.level > currentLevel) continue;
      if (!(status?.claimedNormal.contains(r.level) ?? false)) {
        claimableRewards++;
      }
      if (hasVip && !(status?.claimedVip.contains(r.level) ?? false)) {
        claimableRewards++;
      }
    }
    final int claimableQuests = state.quests
        .where((BpPlayerQuest q) => q.isCompleted && !q.rewardClaimed)
        .length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          _buildTabItem(0, 'ÖDÜLLER', claimableRewards),
          _buildTabItem(1, 'GÖREVLER', claimableQuests),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, int badgeCount) {
    final bool active = _tabIndex == index;
    Widget tab = GestureDetector(
      onTap: () async {
        setState(() => _tabIndex = index);
        if (index == 1) {
          await TutorialTriggers.onAnchorTap(
            ref,
            TutorialAnchorId.seasonQuestsTab,
          );
          if (!mounted) return;
          // L20 coach lives on Ödüller list — flip back after Görevler step.
          _ensureRewardsTabForL20Coach();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: active
              ? LinearGradient(
                  colors: <Color>[
                    _BpColors.gold.withValues(alpha: 0.25),
                    _BpColors.gold.withValues(alpha: 0.1),
                  ],
                )
              : null,
          border: Border.all(
            color: active
                ? _BpColors.gold.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                color: active ? _BpColors.gold : _BpColors.textLow,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
            if (badgeCount > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _BpColors.green.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _BpColors.green.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: _BpColors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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

  // ─── Ödül listesi ────────────────────────────────────────────────────────

  Widget _buildRewardsList(BattlePassState state) {
    final rewards = state.rewards;
    final status = state.status;

    if (rewards.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 120),
          Center(
            child: Text(
              'Sezon ödülleri henüz tanımlanmadı.',
              style: TextStyle(color: _BpColors.textLow, fontSize: 13),
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

        Widget row = _RewardLevelRow(
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
        AppMessenger.showSuccess(context, '🎁 Seviye $level ödülü alındı!');
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

  // ─── Görev listesi ───────────────────────────────────────────────────────

  Widget _buildQuestsList(BattlePassState state) {
    final quests = state.quests;
    if (quests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 120),
          Center(
            child: Text(
              'Aktif görev bulunamadı.',
              style: TextStyle(color: _BpColors.textLow, fontSize: 13),
            ),
          ),
        ],
      );
    }

    final sorted = <BpPlayerQuest>[...quests]..sort((a, b) {
        int rank(BpPlayerQuest q) {
          if (q.isCompleted && !q.rewardClaimed) return 0;
          if (!q.isCompleted) return 1;
          return 2;
        }

        final int cmp = rank(a).compareTo(rank(b));
        if (cmp != 0) return cmp;
        return b.currentProgress.compareTo(a.currentProgress);
      });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sorted.length,
      padding:
          GameScrollLayout.withClearance(context, const EdgeInsets.all(12)),
      itemBuilder: (BuildContext context, int index) {
        final BpPlayerQuest quest = sorted[index];
        return _QuestCard(
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
}

// ─── Ödül satırı ──────────────────────────────────────────────────────────

class _RewardLevelRow extends StatelessWidget {
  const _RewardLevelRow({
    required this.reward,
    required this.reached,
    required this.isCurrent,
    required this.claimedNormal,
    required this.claimedVip,
    required this.hasVip,
    required this.claimingFree,
    required this.claimingVip,
    required this.onClaimFree,
    required this.onClaimVip,
  });

  final BpLevelReward reward;
  final bool reached;
  final bool isCurrent;
  final bool claimedNormal;
  final bool claimedVip;
  final bool hasVip;
  final bool claimingFree;
  final bool claimingVip;
  final VoidCallback onClaimFree;
  final VoidCallback onClaimVip;

  @override
  Widget build(BuildContext context) {
    final bool freeClaimable = reached && !claimedNormal;
    final bool vipClaimable = reached && hasVip && !claimedVip;
    final bool anyClaimable = freeClaimable || vipClaimable;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: reached ? _BpColors.cardBg : _BpColors.cardBgDim,
        border: Border.all(
          color: isCurrent
              ? _BpColors.cyan.withValues(alpha: 0.7)
              : anyClaimable
                  ? _BpColors.gold.withValues(alpha: 0.55)
                  : reached
                      ? _BpColors.gold.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
          width: isCurrent ? 1.4 : 1,
        ),
        boxShadow: anyClaimable
            ? <BoxShadow>[
                BoxShadow(
                  color: _BpColors.gold.withValues(alpha: 0.14),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      // ListView → unbounded height. stretch için IntrinsicHeight şart.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Seviye madalyonu
            Container(
              width: 52,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(13),
                ),
                color: reached
                    ? _BpColors.gold.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.25),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'SV',
                    style: TextStyle(
                      color: reached ? _BpColors.gold : _BpColors.textLow,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${reward.level}',
                    style: GoogleFonts.urbanist(
                      color: reached ? _BpColors.gold : _BpColors.textLow,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (isCurrent)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.place_rounded,
                          size: 12, color: _BpColors.cyan),
                    )
                  else if (!reached)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.lock_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                ],
              ),
            ),
            // Ücretsiz hat
            Expanded(
              child: _RewardCell(
                title: 'ÜCRETSİZ',
                accent: _BpColors.cyan,
                gold: reward.normalRewardGold,
                itemId: reward.normalRewardItemId,
                item: reward.normalRewardItem,
                quantity: reward.normalRewardQuantity,
                reached: reached,
                claimed: claimedNormal,
                canClaim: freeClaimable,
                claiming: claimingFree,
                lockedByVip: false,
                onClaim: onClaimFree,
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.white.withValues(alpha: 0.07),
            ),
            // VIP hat
            Expanded(
              child: _RewardCell(
                title: 'VIP',
                accent: _BpColors.gold,
                gold: reward.vipRewardGold,
                itemId: reward.vipRewardItemId,
                item: reward.vipRewardItem,
                quantity: reward.vipRewardQuantity,
                reached: reached,
                claimed: claimedVip,
                canClaim: vipClaimable,
                claiming: claimingVip,
                lockedByVip: reached && !hasVip,
                onClaim: onClaimVip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCell extends StatelessWidget {
  const _RewardCell({
    required this.title,
    required this.accent,
    required this.gold,
    required this.itemId,
    required this.item,
    required this.quantity,
    required this.reached,
    required this.claimed,
    required this.canClaim,
    required this.claiming,
    required this.lockedByVip,
    required this.onClaim,
  });

  final String title;
  final Color accent;
  final int gold;
  final String? itemId;
  final Map<String, dynamic>? item;
  final int quantity;
  final bool reached;
  final bool claimed;
  final bool canClaim;
  final bool claiming;

  /// Seviyeye ulaşıldı ama VIP pass yok.
  final bool lockedByVip;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final String? itemName = item?['name'] as String?;
    final String? itemIcon = item?['icon'] as String?;
    final String rarity = (item?['rarity'] as String?) ?? 'common';
    final Color rarityColor = AppColors.forRarity(rarity);
    final bool hasContent = gold > 0 || itemId != null;

    return Opacity(
      opacity: reached ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                color: accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            if (!hasContent)
              const Text(
                '—',
                style: TextStyle(color: _BpColors.textLow, fontSize: 12),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (itemId != null)
                    ItemIconView(
                      itemId: itemId,
                      iconValue: itemIcon ?? '',
                      size: 32,
                    )
                  else
                    Icon(Icons.monetization_on_rounded,
                        color: _BpColors.gold, size: 26),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (gold > 0)
                          Text(
                            '+$gold Altın',
                            style: const TextStyle(
                              color: _BpColors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (itemId != null)
                          Text(
                            '${itemName ?? 'Eşya'} x$quantity',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            if (claimed)
              const Icon(Icons.check_circle_rounded,
                  color: _BpColors.green, size: 19)
            else if (canClaim)
              GestureDetector(
                onTap: claiming ? null : onClaim,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: claiming ? null : AppColors.liquidGoldGradient,
                    color: claiming
                        ? AppColors.darkObsidian.withValues(alpha: 0.5)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: claiming
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: _BpColors.gold.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ],
                  ),
                  child: claiming
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _BpColors.gold,
                          ),
                        )
                      : const Text(
                          'AL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.carbonVoid,
                          ),
                        ),
                ),
              )
            else if (lockedByVip)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.workspace_premium_rounded,
                      size: 13, color: _BpColors.gold.withValues(alpha: 0.6)),
                  const SizedBox(width: 3),
                  Text(
                    'VIP gerekli',
                    style: TextStyle(
                      color: _BpColors.gold.withValues(alpha: 0.6),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else
              Icon(Icons.lock_rounded,
                  color: Colors.white.withValues(alpha: 0.2), size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Görev kartı ──────────────────────────────────────────────────────────

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.claiming,
    required this.onClaim,
  });

  final BpPlayerQuest quest;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final BpQuestTemplate? template = quest.template;
    final bool isDaily = template?.questType == 'daily';
    final Color typeColor = isDaily ? _BpColors.cyan : AppColors.cyberFuchsia;
    final int target = template?.targetCount ?? 1;
    final double progress =
        target > 0 ? (quest.currentProgress / target).clamp(0.0, 1.0) : 0.0;
    final bool claimable = quest.isCompleted && !quest.rewardClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _BpColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claimable
              ? _BpColors.green.withValues(alpha: 0.55)
              : quest.rewardClaimed
                  ? Colors.white.withValues(alpha: 0.05)
                  : typeColor.withValues(alpha: 0.25),
        ),
        boxShadow: claimable
            ? <BoxShadow>[
                BoxShadow(
                  color: _BpColors.green.withValues(alpha: 0.12),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  isDaily ? 'GÜNLÜK' : 'HAFTALIK',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: typeColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              if (claimable)
                GestureDetector(
                  onTap: claiming ? null : onClaim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient:
                          claiming ? null : AppColors.liquidGoldGradient,
                      color: claiming
                          ? AppColors.darkObsidian.withValues(alpha: 0.5)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: claiming
                          ? null
                          : <BoxShadow>[
                              BoxShadow(
                                color:
                                    _BpColors.gold.withValues(alpha: 0.35),
                                blurRadius: 8,
                              ),
                            ],
                    ),
                    child: claiming
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _BpColors.gold,
                            ),
                          )
                        : Text(
                            '+${template?.bppReward ?? 0} BPP AL',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.carbonVoid,
                            ),
                          ),
                  ),
                )
              else if (quest.rewardClaimed)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.check_circle_rounded,
                        color: _BpColors.green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'ALINDI',
                      style: TextStyle(
                        color: _BpColors.green,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  '+${template?.bppReward ?? 0} BPP',
                  style: const TextStyle(
                    color: _BpColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            template?.description ?? '',
            style: const TextStyle(
              color: _BpColors.textHi,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: <Widget>[
                      Container(
                        height: 7,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: quest.isCompleted
                                  ? const <Color>[
                                      Color(0xFF16A34A),
                                      _BpColors.green,
                                    ]
                                  : <Color>[
                                      typeColor.withValues(alpha: 0.6),
                                      typeColor,
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${quest.currentProgress} / $target',
                style: TextStyle(
                  color:
                      quest.isCompleted ? _BpColors.green : _BpColors.textMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
