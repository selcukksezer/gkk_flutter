import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/gkk_tab_page_shell.dart';
import '../../components/kingdom/kingdom_market_blessing_banner.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../models/inventory_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/kingdom_market_blessing_provider.dart';
import '../../providers/market_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import 'widgets/economy_atmosphere_overlay.dart';
import 'widgets/gold_coin_particle_burst.dart';
import 'widgets/market_browse_tab.dart';
import 'widgets/market_design.dart';
import 'widgets/market_my_market_tab.dart';
import 'widgets/market_sell_tab.dart';
import 'widgets/market_tab_bar.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  MarketTab _tab = MarketTab.browse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    try {
      await Future.wait(<Future<void>>[
        ref.read(inventoryProvider.notifier).loadInventory(silent: false),
        ref.read(playerProvider.notifier).loadProfile(),
        ref.read(marketProvider.notifier).loadTickers(),
        ref.read(marketProvider.notifier).loadMyOrders(),
        ref.read(kingdomMarketBlessingProvider.notifier).load(),
      ]);
      if (mounted) {
        await TutorialTriggers.onRouteEnter(ref, AppRoutes.market);
      }
    } catch (_) {
      // Handled by individual providers
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    try {
      await Future.wait(<Future<void>>[
        ref.read(inventoryProvider.notifier).loadInventory(silent: true),
        ref.read(playerProvider.notifier).loadProfile(),
        ref.read(marketProvider.notifier).loadTickers(force: true),
        ref.read(marketProvider.notifier).loadMyOrders(force: true),
        ref.read(kingdomMarketBlessingProvider.notifier).load(),
      ]);
    } catch (_) {
      // Retain state on refresh error
    }
  }

  void _onTabChanged(MarketTab tab) {
    if (_tab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
    if (tab == MarketTab.browse) {
      ref.read(marketProvider.notifier).loadTickers();
    } else if (tab == MarketTab.myMarket) {
      ref.read(marketProvider.notifier).loadMyOrders();
    } else if (tab == MarketTab.sell) {
      ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    }
  }

  Future<void> _logout() async {
    await performLogout(ref);
  }

  @override
  Widget build(BuildContext context) {
    final marketState = ref.watch(marketProvider);
    final int listingCount = marketState.totalListings;
    final int myOrdersCount = marketState.myOrders.length;
    final int tradeableCount = ref
        .watch(inventoryProvider)
        .items
        .where((InventoryItem item) => item.isTradeable && !item.isEquipped)
        .length;

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routeMarket, onLogout: _logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.market, onLogout: _logout),
      body: GameScreenBackground(
        child: EconomyAtmosphereOverlay(
          heatIntensity: 0.28,
          child: GoldCoinParticleBurst(
            child: SafeArea(
              top: false,
              bottom: true,
              child: RefreshIndicator(
                color: AppColors.liquidGold,
                backgroundColor: AppColors.spaceNavy,
                strokeWidth: 2.5,
                onRefresh: _onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: GameScrollLayout.fromLTRB(context, left: 12, top: 8, right: 12),
                  children: <Widget>[
                    MarketHeroBanner(listingCount: listingCount),
                    const SizedBox(height: 10),
                    const KingdomMarketBlessingBanner(locationLabel: 'Pazar'),
                    MarketTabBar(activeTab: _tab, onTabChanged: _onTabChanged),
                    const SizedBox(height: 12),
                    TweenAnimationBuilder<double>(
                      key: ValueKey<MarketTab>(_tab),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      builder: (BuildContext context, double value, Widget? child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          GkkTabSectionTitle(
                            switch (_tab) {
                              MarketTab.browse => 'Pazar Vitrini',
                              MarketTab.sell => 'Eşya Sat',
                              MarketTab.myMarket => 'Benim Pazarım',
                            },
                            accent: switch (_tab) {
                              MarketTab.browse => AppColors.liquidGold,
                              MarketTab.sell => AppColors.accentCyan,
                              MarketTab.myMarket => AppColors.accentPurple,
                            },
                            trailing: switch (_tab) {
                              MarketTab.browse => _MarketCountBadge(
                                  label: '$listingCount İlan',
                                  icon: Icons.local_fire_department_rounded,
                                  color: AppColors.liquidGold,
                                ),
                              MarketTab.sell => _MarketCountBadge(
                                  label: '$tradeableCount Satılabilir',
                                  icon: Icons.inventory_2_outlined,
                                  color: AppColors.accentCyan,
                                ),
                              MarketTab.myMarket => _MarketCountBadge(
                                  label: '$myOrdersCount Aktif',
                                  icon: Icons.storefront_rounded,
                                  color: AppColors.accentPurple,
                                ),
                            },
                          ),
                          const SizedBox(height: 8),
                          switch (_tab) {
                            MarketTab.browse => const MarketBrowseTab(),
                            MarketTab.sell => const MarketSellTab(),
                            MarketTab.myMarket => const MarketMyMarketTab(),
                          },
                        ],
                      ),
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

/// Compact dark-glass badge showing tab-specific counts with glowing borders.
class _MarketCountBadge extends StatelessWidget {
  const _MarketCountBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
