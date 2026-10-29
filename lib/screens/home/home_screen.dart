import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../components/comeback/comeback_summary_dialog.dart';
import '../../components/daily_reward/daily_reward_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/inventory_model.dart';
import '../../models/comeback_summary_model.dart';
import '../../models/player_model.dart';
import '../../providers/comeback_summary_provider.dart';
import '../../providers/daily_reward_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/player_inbox_provider.dart';
import '../../providers/staff_provider.dart';
import '../../qa/qa_flags.dart';
import '../../routing/app_router.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/player_health.dart';
import '../../core/utils/power_formula.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

import '../inventory/widgets/inventory_item_detail_flow.dart';
import 'widgets/home_promo_carousel.dart';
import 'widgets/pantheon_board.dart';
import 'widgets/hero_showcase.dart';
import 'widgets/sticky_action_bar.dart';
import 'widgets/hub_scene_viewport.dart';
import '../../utils/logout_helper.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final HubSceneViewportController _viewportController;
  bool _deferredHomePromo = false;
  /// Claim → loadProfile → ready tekrar tetikler; oturumda bir kez.
  bool _homePromoHandled = false;
  bool _homePromoInFlight = false;

  @override
  void initState() {
    super.initState();
    _viewportController = HubSceneViewportController();
    ref.listenManual<PlayerState>(playerProvider, (
      PlayerState? prev,
      PlayerState next,
    ) {
      if (next.status == PlayerStatus.ready &&
          prev?.status != PlayerStatus.ready) {
        deferProviderUpdate(() {
          _enforceCharacterClassGate();
          _maybeShowComebackSummary();
        });
      }
    });
    ref.listenManual<TutorialState>(tutorialProvider, (
      TutorialState? prev,
      TutorialState next,
    ) {
      if (!_deferredHomePromo) return;
      if (_onboardingBlocksHomePromos()) return;
      _deferredHomePromo = false;
      deferProviderUpdate(_maybeShowComebackSummary);
    });
    deferProviderUpdate(() => _loadHomeData(isRefresh: false));
  }

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  /// Offline redirect hole: /home without class → force onboarding.
  void _enforceCharacterClassGate() {
    if (!mounted) return;
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    if (profile == null) return;
    if (profile.characterClass != null) return;
    context.go(AppRoutes.characterSelect);
  }

  bool _onboardingBlocksHomePromos() {
    final TutorialState tutorial = ref.read(tutorialProvider);
    if (!tutorial.loaded || tutorial.progress.skippedAll) return false;
    final TutorialController controller = ref.read(tutorialProvider.notifier);
    if (!controller.isTrackComplete(TutorialTrackId.onboarding)) return true;
    return tutorial.activeTrackId == TutorialTrackId.onboarding &&
        tutorial.activeStep != null;
  }

  Future<void> _loadHomeData({required bool isRefresh}) async {
    final bool profileReady =
        ref.read(playerProvider).status == PlayerStatus.ready &&
            ref.read(playerProvider).profile != null;

    await Future.wait<void>(<Future<void>>[
      // F2: select sonrası fresh profile varsa tekrar çekme (pull-refresh hariç).
      if (isRefresh || !profileReady)
        ref.read(playerProvider.notifier).loadProfile()
      else
        Future<void>.value(),
      ref.read(inventoryProvider.notifier).loadInventory(silent: true),
      ref.read(staffProvider.notifier).load(silent: !isRefresh),
      ref.read(playerInboxProvider.notifier).refresh(),
    ]);
    if (!mounted) return;

    _enforceCharacterClassGate();
    if (ref.read(playerProvider).profile?.characterClass == null) {
      return;
    }

    // G2: pull-refresh tutorial onRouteEnter tekrar tetiklemesin.
    if (!isRefresh) {
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.home);
      final PlayerProfile? profile = ref.read(playerProvider).profile;
      if (profile != null) {
        await TutorialTriggers.onEnergyLow(ref, energy: profile.energy);
      }
    }
  }

  /// Geri dönüş özeti — günlük ödülden önce; günlük satırı varsa ayrı popup atlanır.
  Future<void> _maybeShowComebackSummary() async {
    if (_homePromoHandled || _homePromoInFlight) return;
    if (_onboardingBlocksHomePromos()) {
      _deferredHomePromo = true;
      return;
    }
    _homePromoInFlight = true;
    try {
      if (QaFlags.skipComebackSummaryDialog) {
        await _maybeShowDailyReward();
        return;
      }

      final ComebackSummaryNotifier notifier = ref.read(
        comebackSummaryProvider.notifier,
      );
      if (ref.read(comebackSummaryProvider).shownThisSession) {
        await _maybeShowDailyReward();
        return;
      }

      await notifier.load();
      if (!mounted) return;

      final ComebackSummaryState comebackState = ref.read(
        comebackSummaryProvider,
      );
      final bool shouldShow = comebackState.summary?.showSummary ?? false;
      if (!shouldShow) {
        await _maybeShowDailyReward();
        return;
      }

      _homePromoHandled = true;
      await showComebackSummaryDialog(context, ref);
      if (!mounted) return;
      notifier.markShownThisSession();
    } finally {
      _homePromoInFlight = false;
    }
  }

  Future<void> _maybeShowDailyReward() async {
    if (QaFlags.skipDailyRewardDialog) return;
    if (_onboardingBlocksHomePromos()) {
      _deferredHomePromo = true;
      return;
    }
    // Günlük ödül comeback modalında satır olarak gösterildiyse tekrar açma.
    if (ref.read(comebackSummaryProvider).shownThisSession) {
      final bool hadDailyRow =
          ref
              .read(comebackSummaryProvider)
              .summary
              ?.items
              .any((item) => item.kind == ComebackItemKind.dailyReward) ??
          false;
      if (hadDailyRow) {
        _homePromoHandled = true;
        return;
      }
    }
    if (ref.read(dailyRewardProvider).didAutoPromptThisSession) {
      _homePromoHandled = true;
      return;
    }
    await ref.read(dailyRewardProvider.notifier).loadStatus();
    if (!mounted) return;
    final bool canClaim =
        ref.read(dailyRewardProvider).status?.canClaim ?? false;
    if (!canClaim) {
      _homePromoHandled = true;
      return;
    }
    ref.read(dailyRewardProvider.notifier).markAutoPromptedThisSession();
    _homePromoHandled = true;
    await showDailyRewardDialog(context, ref, viewOnly: false);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final inventoryState = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.routeHome,
        onLogout: () async {
          HapticFeedback.selectionClick();
          await performLogout(ref);
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.home,
        leadingOverlay: const StickyActionBar(),
        onLogout: () async {
          HapticFeedback.selectionClick();
          await performLogout(ref);
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ── 2027 AAA Visual Architecture Scene Viewport ───────────
          Positioned.fill(
            child: HubSceneViewport(
              controller: _viewportController,
            ),
          ),
          // ── Aion-2 Ethereal Mobile Vignette & Contrast Overlay ─────
          const Positioned.fill(
            child: IgnorePointer(
              child: _HubAion2BackdropOverlay(),
            ),
          ),
          // ── Dashboard and Screen Content Layer ────────────────────
          Positioned.fill(
            child: switch (playerState.status) {
              PlayerStatus.initial || PlayerStatus.loading => const _HomeSkeleton(),
              PlayerStatus.error => _HomeErrorView(
                message: playerState.errorMessage ?? 'Profil yüklenemedi.',
                onRetry: () => _loadHomeData(isRefresh: true),
              ),
              PlayerStatus.ready => RefreshIndicator(
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  await _loadHomeData(isRefresh: true);
                },
                child: _HomeDashboard(
                  profile: playerState.profile!,
                  inventoryState: inventoryState,
                  onRefresh: () => _loadHomeData(isRefresh: true),
                  viewportController: _viewportController,
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xEE141C2E),
                      Color(0xDD0C1322),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0x44F59E0B),
                    width: 1.2,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 38,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onRetry();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Progressive first paint — chrome already up; body placeholders while profile loads.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompact = screenWidth <= 390;
    final double horizontalPadding = isCompact ? 12.0 : AppSpacing.base;

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: GameScrollLayout.fromLTRB(
        context,
        left: horizontalPadding,
        top: AppSpacing.md,
        right: horizontalPadding,
        bottomExtra: AppSpacing.xl,
      ),
      children: const <Widget>[
        _SkeletonBlock(height: 140, radius: 20),
        SizedBox(height: AppSpacing.md),
        _SkeletonBlock(height: 220, radius: 24),
        SizedBox(height: AppSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(child: _SkeletonBlock(height: 72, radius: 16)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _SkeletonBlock(height: 72, radius: 16)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _SkeletonBlock(height: 72, radius: 16)),
          ],
        ),
        SizedBox(height: AppSpacing.xxl),
        _SkeletonBlock(height: 120, radius: 20),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0x660F172A),
                Color(0x331E293B),
                Color(0x440B1120),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: const Color(0x33F59E0B),
              width: 1.0,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x12F59E0B),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDashboard extends ConsumerStatefulWidget {
  const _HomeDashboard({
    required this.profile,
    required this.inventoryState,
    required this.onRefresh,
    required this.viewportController,
  });

  final PlayerProfile profile;
  final InventoryState inventoryState;
  final Future<void> Function() onRefresh;
  final HubSceneViewportController viewportController;

  @override
  ConsumerState<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<_HomeDashboard> {
  Future<void> _openSlotInfo(String slotLabel, InventoryItem? item) async {
    HapticFeedback.selectionClick();
    if (item != null) {
      await InventoryItemDetailFlow(
        context: context,
        ref: ref,
        source: 'home_equipped',
      ).openInfo(item);
      return;
    }
    await InventoryItemDetailFlow.showEmptyEquipSlotInfo(
      context,
      slotLabel: slotLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlayerProfile profile = widget.profile;

    bool isFuture(String? dateStr) {
      if (dateStr == null) return false;
      final d = DateTime.tryParse(dateStr);
      if (d == null) return false;
      return d.isAfter(DateTime.now());
    }

    final bool inHospital = isFuture(profile.hospitalUntil);
    final bool inPrison = isFuture(profile.prisonUntil);

    final int energy = profile.energy;
    final int maxEnergy = profile.maxEnergy;
    final int health = profile.health;
    final int maxHealth = profile.maxHealth;
    final bool lowHealth = isLowHealthAlert(health: health, maxHealth: maxHealth);
    final int tolerance = profile.addictionLevel;
    final int reputation = (profile.reputation ?? 0).clamp(0, 999999999);

    final int totalPower = resolveDungeonCombatPower(
      profile: profile,
      equippedItems: widget.inventoryState.equippedItems.values,
    );

    final TutorialState tutorial = ref.watch(tutorialProvider);
    final bool hideHomeExtras = tutorial.activeStep != null;
    // E3: promo gizle (homePromo adımı hariç — anchor lazım).
    final bool hidePromoCarousel = tutorial.activeStep != null &&
        tutorial.activeStep!.anchorId != TutorialAnchorId.homePromo;

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompact = screenWidth <= 390;
    final double horizontalPadding = isCompact ? 12.0 : AppSpacing.base;
    final double sectionGap = isCompact ? AppSpacing.md : AppSpacing.xl;

    return Stack(
      children: <Widget>[
        // ── Scrollable content with Camera Parallax Tracking ────────────
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              widget.viewportController.handleScroll(notification.metrics.pixels);
              return false;
            },
            child: ListView(
              clipBehavior: Clip.none,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: GameScrollLayout.fromLTRB(
                context,
                left: horizontalPadding,
                top: AppSpacing.md,
                right: horizontalPadding,
                bottomExtra: AppSpacing.xl,
              ),
              children: <Widget>[
                if (!hidePromoCarousel) ...<Widget>[
                  TutorialAnchorScope(
                    id: TutorialAnchorId.homePromo,
                    child: const HomePromoCarousel(),
                  ),
                  SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
                ] else
                  const TutorialAnchorScope(
                    id: TutorialAnchorId.homePromo,
                    child: SizedBox(height: 1),
                  ),

                TutorialAnchorScope(
                  id: TutorialAnchorId.homeHero,
                  child: HeroShowcase(
                    profile: profile,
                    inventoryState: widget.inventoryState,
                    totalPower: totalPower,
                    reputation: reputation,
                    onSlotTap: _openSlotInfo,
                  ),
                ),
                SizedBox(height: sectionGap),

                if (!hideHomeExtras) ...<Widget>[
                  const _QuickAccessGrid(),
                  SizedBox(height: isCompact ? AppSpacing.xl : AppSpacing.xxl),
                ],

                // Pantheon Leaderboard
                if (!hideHomeExtras) ...<Widget>[
                  const PantheonBoard(),
                  SizedBox(height: sectionGap),
                ],
              ],
            ),
          ),
        ),

        // Floating warning stack at top-right with responsive constraints
        if (inHospital || inPrison || energy < 20 || tolerance > 60 || lowHealth)
          Positioned(
            top: 8,
            right: isCompact ? 12 : 16,
            child: SafeArea(
              top: false,
              bottom: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * (isCompact ? 0.72 : 0.65),
                ),
                child: _WarningStack(
                  hospitalUntil: profile.hospitalUntil,
                  prisonUntil: profile.prisonUntil,
                  energy: energy,
                  maxEnergy: maxEnergy,
                  health: health,
                  maxHealth: maxHealth,
                  tolerance: tolerance,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ana ekran hızlı erişim kısayolları — bottom bar'da olmayan rotalar (Aion-2 mobile standard).
class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  static const List<(String, String, String, Color)> _shortcuts =
      <(String, String, String, Color)>[
    ('📋', 'Görevler', AppRoutes.quests, Color(0xFFC084FC)),
    ('🤝', 'Ticaret', AppRoutes.trade, Color(0xFF4ADE80)),
    ('⚔️', 'Lonca Savaşı', AppRoutes.guildWar, Color(0xFFF87171)),
    ('🏰', 'Zindan', AppRoutes.dungeon, Color(0xFF60A5FA)),
  ];

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompact = screenWidth <= 390;
    final double itemSpacing = isCompact ? 6.0 : 8.0;

    return Row(
      children: <Widget>[
        for (int i = 0; i < _shortcuts.length; i++) ...<Widget>[
          if (i > 0) SizedBox(width: itemSpacing),
          Expanded(child: _shortcutTile(context, _shortcuts[i], isCompact)),
        ],
      ],
    );
  }

  Widget _shortcutTile(
    BuildContext context,
    (String, String, String, Color) shortcut,
    bool isCompact,
  ) {
    final (String emoji, String label, String route, Color accent) = shortcut;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          GoRouter.of(context).push(route);
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: accent.withValues(alpha: 0.25),
        highlightColor: accent.withValues(alpha: 0.12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: isCompact ? 10 : 12,
                horizontal: isCompact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    const Color(0xCC0D1526),
                    accent.withValues(alpha: 0.14),
                    const Color(0xCC080D18),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accent.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.20),
                    blurRadius: 14,
                    spreadRadius: -2,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    emoji,
                    style: TextStyle(
                      fontSize: isCompact ? 20 : 22,
                      shadows: <Shadow>[
                        Shadow(
                          color: accent.withValues(alpha: 0.6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isCompact ? 4 : 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: accent,
                          fontSize: isCompact ? 10.0 : 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          shadows: const <Shadow>[
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
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
}

class _WarningStack extends StatelessWidget {
  const _WarningStack({
    required this.hospitalUntil,
    required this.prisonUntil,
    required this.energy,
    required this.maxEnergy,
    required this.health,
    required this.maxHealth,
    required this.tolerance,
  });

  final String? hospitalUntil;
  final String? prisonUntil;
  final int energy;
  final int maxEnergy;
  final int health;
  final int maxHealth;
  final int tolerance;

  bool _isFuture(String? dateStr) {
    if (dateStr == null) return false;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    return date.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> banners = <Widget>[];

    final bool inHospital = _isFuture(hospitalUntil);
    final bool inPrison = _isFuture(prisonUntil);

    if (inHospital || inPrison) {
      banners.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            GoRouter.of(context)
                .push(inHospital ? AppRoutes.hospital : AppRoutes.prison);
          },
          child: _ActiveStatusPill(
            icon: inHospital ? '🏥' : '👮',
            title: inHospital ? 'Hastanede' : 'Hapiste',
            until: inHospital
                ? DateTime.parse(hospitalUntil!).toLocal()
                : DateTime.parse(prisonUntil!).toLocal(),
            color: inHospital ? AppColors.danger : Colors.orangeAccent,
          ),
        ),
      );
    }

    if (energy < 20) {
      banners.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            GoRouter.of(context).push(AppRoutes.shop);
          },
          child: const _StaticStatusPill(
            icon: '⚡',
            text: 'Kritik Enerji',
            color: AppColors.warning,
          ),
        ),
      );
    }

    if (tolerance > 60) {
      banners.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            GoRouter.of(context).push(AppRoutes.hospital);
          },
          child: _StaticStatusPill(
            icon: '⚠️',
            text: 'Yüksek Tolerans',
            color: tolerance >= 80 ? AppColors.danger : AppColors.warning,
          ),
        ),
      );
    }

    if (maxHealth > 0 && !inHospital) {
      final PlayerHealthStatus healthStatus = resolveHealthStatus(
        health: health,
        maxHealth: maxHealth,
      );
      if (healthStatus == PlayerHealthStatus.critical ||
          healthStatus == PlayerHealthStatus.wounded) {
        banners.add(
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              GoRouter.of(context).push(AppRoutes.hospital);
            },
            child: _StaticStatusPill(
              icon: healthStatus == PlayerHealthStatus.critical ? '🩸' : '❤️',
              text: healthStatus == PlayerHealthStatus.critical
                  ? 'Kritik Can'
                  : 'Yaralı',
              color: healthStatus == PlayerHealthStatus.critical
                  ? AppColors.mysticRuby
                  : AppColors.warningSolar,
            ),
          ),
        );
      } else if (isLowHealthAlert(health: health, maxHealth: maxHealth)) {
        banners.add(
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              GoRouter.of(context).push(AppRoutes.hospital);
            },
            child: const _StaticStatusPill(
              icon: '❤️',
              text: 'Düşük Can',
              color: AppColors.warningSolar,
            ),
          ),
        );
      }
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: banners
          .map(
            (banner) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: banner,
            ),
          )
          .toList(),
    );
  }
}

class _StaticStatusPill extends StatelessWidget {
  const _StaticStatusPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xEE0D1526),
                color.withValues(alpha: 0.12),
                const Color(0xEE080D18),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 14,
                spreadRadius: -1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: color,
                    fontSize: 12,
                    letterSpacing: 0.3,
                    shadows: <Shadow>[
                      Shadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveStatusPill extends StatefulWidget {
  const _ActiveStatusPill({
    required this.icon,
    required this.title,
    required this.until,
    required this.color,
  });

  final String icon;
  final String title;
  final DateTime until;
  final Color color;

  @override
  State<_ActiveStatusPill> createState() => _ActiveStatusPillState();
}

class _ActiveStatusPillState extends State<_ActiveStatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.45, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xEE0D1526),
                    widget.color.withValues(
                      alpha: 0.16 * _pulseAnimation.value,
                    ),
                    const Color(0xEE080D18),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: widget.color.withValues(alpha: _pulseAnimation.value),
                  width: 1.8,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.color.withValues(
                      alpha: _pulseAnimation.value * 0.55,
                    ),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(widget.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.6,
                        shadows: <Shadow>[
                          Shadow(color: widget.color, blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CountdownText(until: widget.until),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.until});

  final DateTime until;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Duration diff = widget.until.difference(DateTime.now());
    final bool isFinished = diff.isNegative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x33F59E0B),
          width: 0.8,
        ),
      ),
      child: Text(
        isFinished ? 'BİTTİ' : _formatDuration(diff),
        style: AppTextStyles.caption.copyWith(
          color: isFinished ? AppColors.success : Colors.white,
          fontWeight: FontWeight.bold,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Ethereal mobile vignette and arcane border overlay for Main Hub (Aion-2 mobile standard).
class _HubAion2BackdropOverlay extends StatelessWidget {
  const _HubAion2BackdropOverlay();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _HubVignettePainter(),
    );
  }
}

class _HubVignettePainter extends CustomPainter {
  const _HubVignettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Top status bar & app bar vignette for high outdoor mobile contrast
    final Paint topVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.65),
          Colors.black.withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 140));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 140), topVignette);

    // 2. Celestial ethereal upper glow (Aion-2 dark fantasy celestial atmosphere)
    final Paint celestialGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.9),
        radius: 0.9,
        colors: <Color>[
          const Color(0x12F59E0B), // subtle celestial gold starlight
          Colors.transparent,
        ],
        stops: const <double>[0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 240));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 240), celestialGlow);

    // 3. Bottom navigation & sticky action bar vignette
    final Paint bottomVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.72),
          Colors.black.withValues(alpha: 0.28),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, size.height - 180, size.width, 180));
    canvas.drawRect(Rect.fromLTWH(0, size.height - 180, size.width, 180), bottomVignette);

    // 4. Subtle radial rim shadow preserving center plaza / hero clarity
    final Paint rimVignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.1),
        radius: 1.1,
        colors: <Color>[
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.42),
        ],
        stops: const <double>[0.0, 0.68, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), rimVignette);
  }

  @override
  bool shouldRepaint(covariant _HubVignettePainter oldDelegate) => false;
}
