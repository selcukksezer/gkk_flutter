import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/gkk_tab_page_shell.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/utils/reputation_tier.dart';
import '../../l10n/l10n.dart';
import '../../models/reputation_model.dart';
import '../../providers/player_provider.dart';
import '../../providers/reputation_provider.dart';
import '../../routing/app_router.dart';
import '../../utils/logout_helper.dart';
import '../mekans/widgets/mekan_design.dart';
import 'widgets/reputation_activity_log.dart';
import 'widgets/reputation_design.dart';
import 'widgets/reputation_earn_section.dart';
import 'widgets/reputation_shop_grid.dart';

class ReputationScreen extends ConsumerStatefulWidget {
  const ReputationScreen({super.key});

  @override
  ConsumerState<ReputationScreen> createState() => _ReputationScreenState();
}

class _ReputationScreenState extends ConsumerState<ReputationScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _tabAnimController;
  late final Animation<double> _tabFadeAnimation;
  late final Animation<Offset> _tabSlideAnimation;

  @override
  void initState() {
    super.initState();
    _tabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _tabFadeAnimation = CurvedAnimation(
      parent: _tabAnimController,
      curve: Curves.easeOutCubic,
    );
    _tabSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _tabAnimController,
      curve: Curves.easeOutCubic,
    ));
    _tabAnimController.forward();
    Future<void>.microtask(() => ref.read(reputationProvider.notifier).load());
  }

  @override
  void dispose() {
    _tabAnimController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    _tabAnimController.forward(from: 0.0);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    await Future.wait<void>(<Future<void>>[
      ref.read(reputationProvider.notifier).load(),
      ref.read(playerProvider.notifier).loadProfile(),
    ]);
  }

  (double progress, String nextTier, int remaining) _tierProgress(int rep) {
    final int safeRep = rep < 0 ? 0 : rep;
    const List<int> thresholds = <int>[5000, 20000, 80000, 170000, 280000, 356000];
    const List<String> names = <String>[
      'Tanınan',
      'Saygın',
      'Ünlü',
      'Efsanevi',
      'Destansı',
      'İmparator',
    ];
    if (safeRep >= 356000) return (1.0, 'Maksimum', 0);
    int prev = 0;
    for (int i = 0; i < thresholds.length; i++) {
      if (safeRep < thresholds[i]) {
        final int span = thresholds[i] - prev;
        final double p = span > 0 ? (safeRep - prev) / span : 0.0;
        return (p.clamp(0.0, 1.0), names[i], thresholds[i] - safeRep);
      }
      prev = thresholds[i];
    }
    return (1.0, 'İmparator', 0);
  }

  Future<void> _purchase(ReputationShopItem item) async {
    final String? err = await ref.read(reputationProvider.notifier).purchase(item: item);
    if (!mounted) return;
    if (err != null) {
      AppMessenger.showError(context, err);
      return;
    }
    await ref.read(playerProvider.notifier).loadProfile();
    if (!mounted) return;
    AppMessenger.showSuccess(context, '${item.name} satın alındı!');
  }

  Color _tierColor(FactionStandingTier tier) {
    switch (tier) {
      case FactionStandingTier.neutral:
        return const Color(0xFF94A3B8);
      case FactionStandingTier.friendly:
        return const Color(0xFF38BDF8);
      case FactionStandingTier.honored:
        return const Color(0xFF818CF8);
      case FactionStandingTier.revered:
        return const Color(0xFFFBBF24);
      case FactionStandingTier.exalted:
        return const Color(0xFFFFD700);
    }
  }

  void _showStandingTiersInfoModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext modalCtx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: MekanPalette.void_.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MekanPalette.textLow.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: <Widget>[
                      Icon(Icons.military_tech_rounded, color: MekanPalette.gold, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Fraksiyon Kademeleri & Satıcı İndirimleri',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: MekanPalette.textHi,
                              ),
                            ),
                            Text(
                              'Aion realm birlikleri kademe ve sadakat ayrıcalıkları',
                              style: TextStyle(fontSize: 11, color: MekanPalette.textMid),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...FactionStandingTier.values.map((FactionStandingTier t) {
                    final Color c = _tierColor(t);
                    final String desc = switch (t) {
                      FactionStandingTier.neutral => 'Başlangıç derecesi (0 - 3,000 İtibar). Standart satıcı fiyatları.',
                      FactionStandingTier.friendly => 'Dost kademesi (3,000 - 9,000). %5 Satıcı İndirimi ve temel ayrıcalıklar.',
                      FactionStandingTier.honored => 'Saygıdeğer kademesi (9,000 - 25,000). %10 Satıcı İndirimi ve savunma takviyeleri.',
                      FactionStandingTier.revered => 'Hürmetli kademesi (25,000 - 50,000). %15 Satıcı İndirimi ve destansı teçhizat erişimi.',
                      FactionStandingTier.exalted => 'Yüce kademe (50,000+). %20 Satıcı İndirimi, mitik baş melek kanatları ve auralar.',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: c),
                              ),
                              child: Text(
                                t.romanBadge,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: c,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        t.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: c,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '-${t.vendorDiscountPct}% İndirim',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: MekanPalette.gold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: MekanPalette.textMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ReputationState state = ref.watch(reputationProvider);
    final ReputationOverview overview = state.overview;
    final int globalRep = overview.globalReputation;
    final ReputationTier tier = reputationTierFor(globalRep);
    final (double progress, String nextTier, int remaining) =
        _tierProgress(globalRep);
    final List<String> buffLabels =
        overview.activeBuffs.map((ReputationActiveBuff b) => b.label()).toList();

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isNarrow = screenWidth < 360;

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.i_tibar,
        onLogout: () async => performLogout(ref),
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.reputation,
        onLogout: () async => performLogout(ref),
      ),
      body: MekanBackdrop(
        accent: MekanPalette.gold,
        child: SafeArea(
          bottom: false,
          child: state.loading && overview.shopItems.isEmpty && overview.activity.isEmpty
              ? const Center(child: CircularProgressIndicator(color: MekanPalette.gold))
              : RefreshIndicator(
                  color: MekanPalette.gold,
                  onRefresh: _refresh,
                  child: ListView(
                    padding: GameScrollLayout.fromLTRB(
                      context,
                      left: isNarrow ? 12 : 16,
                      top: 12,
                      right: isNarrow ? 12 : 16,
                    ),
                    children: <Widget>[
                      ReputationVaultHeader(
                        totalRep: globalRep,
                        tierTitle: tier.title,
                        tierColor: tier.color,
                        nextTierTitle: nextTier,
                        progress: progress,
                        activeBuffs: buffLabels,
                        remainingToNext: remaining,
                      ),
                      const SizedBox(height: 16),
                      ReputationTabBar(
                        index: _tab,
                        onChanged: _onTabChanged,
                      ),
                      if (state.error != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: MekanPalette.ruby.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: MekanPalette.ruby.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.error_outline_rounded, color: MekanPalette.ruby, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.error!,
                                  style: const TextStyle(
                                    color: MekanPalette.textHi,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _refresh,
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  foregroundColor: MekanPalette.gold,
                                ),
                                child: const Text(
                                  'Yeniden Dene',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FadeTransition(
                        opacity: _tabFadeAnimation,
                        child: SlideTransition(
                          position: _tabSlideAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              GkkTabSectionTitle(
                                switch (_tab) {
                                  0 => 'Hanedanlar & Birlikler',
                                  1 => 'İtibar Kazan',
                                  2 => 'İtibar Dükkanı',
                                  _ => 'Aktivite Geçmişi',
                                },
                                accent: MekanPalette.gold,
                                trailing: _tab == 0
                                    ? InkWell(
                                        onTap: () => _showStandingTiersInfoModal(context),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const <Widget>[
                                              Icon(Icons.military_tech_rounded, size: 14, color: MekanPalette.gold),
                                              SizedBox(width: 4),
                                              Text(
                                                'Kademeler',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: MekanPalette.gold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              if (_tab == 0) ...<Widget>[
                                _StandingTiersStrip(
                                  onInfoTap: () => _showStandingTiersInfoModal(context),
                                ),
                                const SizedBox(height: 12),
                                const FactionStandingsHub(),
                              ] else if (_tab == 1) ...<Widget>[
                                ReputationEarnSection(),
                                const SizedBox(height: 16),
                                ReputationTierLadder(currentRep: globalRep),
                              ] else if (_tab == 2) ...<Widget>[
                                ReputationShopGrid(
                                  items: overview.shopItems,
                                  globalRep: globalRep,
                                  purchasingId: state.purchasingId,
                                  onPurchase: _purchase,
                                ),
                              ] else ...<Widget>[
                                ReputationActivityLog(entries: overview.activity),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Aion Faction Standing Tiers Quick Legend Strip (Neutral -> Friendly -> Honored -> Revered -> Exalted)
class _StandingTiersStrip extends StatelessWidget {
  const _StandingTiersStrip({required this.onInfoTap});

  final VoidCallback onInfoTap;

  Color _tierColor(FactionStandingTier tier) {
    switch (tier) {
      case FactionStandingTier.neutral:
        return const Color(0xFF94A3B8);
      case FactionStandingTier.friendly:
        return const Color(0xFF38BDF8);
      case FactionStandingTier.honored:
        return const Color(0xFF818CF8);
      case FactionStandingTier.revered:
        return const Color(0xFFFBBF24);
      case FactionStandingTier.exalted:
        return const Color(0xFFFFD700);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MekanPalette.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.shield_rounded, color: MekanPalette.gold, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'FRAKSİYON KADEMELERİ & SATICI İNDİRİMLERİ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: MekanPalette.textMid,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onInfoTap,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.info_outline_rounded, size: 14, color: MekanPalette.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double itemWidth = (constraints.maxWidth - (FactionStandingTier.values.length - 1) * 6) /
                  FactionStandingTier.values.length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: FactionStandingTier.values.map((FactionStandingTier t) {
                  final Color c = _tierColor(t);
                  return SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            t.romanBadge,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c),
                          ),
                          Text(
                            t.title,
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: c),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '-%${t.vendorDiscountPct}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: MekanPalette.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

