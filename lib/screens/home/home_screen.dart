import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/provider_scheduling.dart';
import '../../components/daily_reward/daily_reward_dialog.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/inventory_model.dart';
import '../../models/player_model.dart';
import '../../providers/daily_reward_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../qa/qa_flags.dart';
import '../../routing/app_router.dart';
import '../../l10n/l10n.dart';
import '../../core/utils/reputation_tier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

import '../inventory/widgets/inventory_item_detail_flow.dart';
import 'widgets/home_promo_carousel.dart';
import 'widgets/pantheon_board.dart';
import 'widgets/hero_showcase.dart';
import 'widgets/sticky_action_bar.dart';
import '../reputation/widgets/reputation_home_chip.dart';
import '../../utils/logout_helper.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<PlayerState>(playerProvider, (
      PlayerState? prev,
      PlayerState next,
    ) {
      if (next.status == PlayerStatus.ready &&
          prev?.status != PlayerStatus.ready) {
        deferProviderUpdate(_maybeShowDailyReward);
      }
    });
    deferProviderUpdate(_loadHomeData);
  }

  Future<void> _loadHomeData() async {
    await Future.wait<void>(<Future<void>>[
      ref.read(playerProvider.notifier).loadProfile(),
      ref.read(inventoryProvider.notifier).loadInventory(silent: true),
    ]);
    if (!mounted) return;
    await TutorialTriggers.onRouteEnter(ref, AppRoutes.home);
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    if (profile != null) {
      await TutorialTriggers.onEnergyLow(ref, energy: profile.energy);
    }
  }

  Future<void> _maybeShowDailyReward() async {
    if (QaFlags.skipDailyRewardDialog) return;
    await ref.read(dailyRewardProvider.notifier).loadStatus();
    if (!mounted) return;
    final bool canClaim =
        ref.read(dailyRewardProvider).status?.canClaim ?? false;
    if (!canClaim) return;
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
          await performLogout(ref);
        },
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.home,
        leadingOverlay: StickyActionBar(),
        onLogout: () async {
          await performLogout(ref);
        },
      ),
      body: switch (playerState.status) {
        PlayerStatus.initial || PlayerStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PlayerStatus.error => _HomeErrorView(
          message: playerState.errorMessage ?? 'Profil yüklenemedi.',
          onRetry: _loadHomeData,
        ),
        PlayerStatus.ready => RefreshIndicator(
          onRefresh: _loadHomeData,
          child: _HomeDashboard(
            profile: playerState.profile!,
            inventoryState: inventoryState,
            onRefresh: _loadHomeData,
          ),
        ),
      },
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
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
  });

  final PlayerProfile profile;
  final InventoryState inventoryState;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<_HomeDashboard> {
  Future<void> _openEquippedItemInfo(InventoryItem item) async {
    await InventoryItemDetailFlow(
      context: context,
      ref: ref,
      source: 'home_equipped',
    ).open(item);
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
    final int tolerance = profile.addictionLevel;
    final int reputation = (profile.reputation ?? 0).clamp(0, 999999999);

    final _EquipmentStats eqStats = _calculateEquipmentStats(
      widget.inventoryState.equippedItems,
    );
    final int totalPower = _calculateTotalPower(
      eqStats: eqStats,
      level: profile.level,
      reputation: reputation,
    );

    return Stack(
      children: <Widget>[
        // ── Deep background gradient ────────────────────────────────────
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF070B14), Color(0xFF030509)],
              ),
            ),
          ),
        ),
        // ── Ambient glow orbs ───────────────────────────────────────────
        Positioned(
          top: -180,
          left: -140,
          child: IgnorePointer(
            child: Container(
              width: 480,
              height: 480,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0x2A5B8FFF), Color(0x005B8FFF)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -220,
          right: -160,
          child: IgnorePointer(
            child: Container(
              width: 520,
              height: 520,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0x2234D399), Color(0x0034D399)],
                ),
              ),
            ),
          ),
        ),
        // ── Scrollable content ──────────────────────────────────────────
        Positioned.fill(
          child: ListView(
            // Promo crate art overflows card; must not hard-clip children.
            clipBehavior: Clip.none,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: GameScrollLayout.fromLTRB(
              context,
              left: AppSpacing.base,
              top: AppSpacing.md,
              right: AppSpacing.base,
              bottomExtra: kGameChatFabSize + AppSpacing.md,
            ),
            children: <Widget>[
              const HomePromoCarousel(),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: ReputationHomeChip(
                  reputation: reputation,
                  tierTitle: reputationTierFor(reputation).title,
                  tierColor: reputationTierFor(reputation).color,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Hero Showcase (Character & Equip)
              HeroShowcase(
                profile: profile,
                inventoryState: widget.inventoryState,
                totalPower: totalPower,
                reputation: reputation,
                onEquippedTap: _openEquippedItemInfo,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Pantheon Leaderboard
              const PantheonBoard(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),

        // Floating warning stack at top-right
        if (inHospital || inPrison || energy < 20 || tolerance > 60)
          Positioned(
            top: 0,
            right: 16,
            child: SafeArea(
              child: _WarningStack(
                hospitalUntil: profile.hospitalUntil,
                prisonUntil: profile.prisonUntil,
                energy: energy,
                maxEnergy: maxEnergy,
                tolerance: tolerance,
              ),
            ),
          ),
      ],
    );
  }
}

class _WarningStack extends StatelessWidget {
  const _WarningStack({
    required this.hospitalUntil,
    required this.prisonUntil,
    required this.energy,
    required this.maxEnergy,
    required this.tolerance,
  });

  final String? hospitalUntil;
  final String? prisonUntil;
  final int energy;
  final int maxEnergy;
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
        _ActiveStatusPill(
          icon: inHospital ? '🏥' : '👮',
          title: inHospital ? 'Hastanede' : 'Hapiste',
          until: inHospital
              ? DateTime.parse(hospitalUntil!).toLocal()
              : DateTime.parse(prisonUntil!).toLocal(),
          color: inHospital ? AppColors.danger : Colors.orangeAccent,
        ),
      );
    }

    if (energy < 20) {
      banners.add(
        _StaticStatusPill(
          icon: '⚡',
          text: 'Kritik Enerji',
          color: AppColors.warning,
        ),
      );
    }

    if (tolerance > 60) {
      banners.add(
        _StaticStatusPill(
          icon: '⚠️',
          text: 'Yüksek Tolerans',
          color: tolerance >= 80 ? AppColors.danger : AppColors.warning,
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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

    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
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
        return Container(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.color.withValues(alpha: _pulseAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: _pulseAnimation.value * 0.5,
                ),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(widget.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CountdownText(until: widget.until),
                  ],
                ),
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
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 1), _tick);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    Future<void>.delayed(const Duration(seconds: 1), _tick);
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
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

class _EquipmentStats {
  const _EquipmentStats({
    required this.attack,
    required this.defense,
    required this.hp,
    required this.luck,
  });

  final int attack;
  final int defense;
  final int hp;
  final int luck;

  double get powerFromEquipment => attack + defense + (hp / 10) + (luck * 2);
}

_EquipmentStats _calculateEquipmentStats(
  Map<String, InventoryItem?> equippedItems,
) {
  int attack = 0;
  int defense = 0;
  int hp = 0;
  int luck = 0;

  for (final item in equippedItems.values) {
    if (item == null) continue;
    attack += item.attack;
    defense += item.defense;
    hp += item.health;
    luck += item.luck;
  }

  return _EquipmentStats(attack: attack, defense: defense, hp: hp, luck: luck);
}

int _calculateTotalPower({
  required _EquipmentStats eqStats,
  required int level,
  required int reputation,
}) {
  final int equipmentPower = eqStats.powerFromEquipment.round();
  final int levelPower = level * 500;
  final int reputationPower = (reputation * 0.1).floor();
  return equipmentPower + levelPower + reputationPower;
}
