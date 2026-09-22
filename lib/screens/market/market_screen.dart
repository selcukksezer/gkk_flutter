import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../components/kingdom/kingdom_market_blessing_banner.dart';
import '../../providers/kingdom_market_blessing_provider.dart';
import '../../providers/market_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../components/common/gkk_tab_page_shell.dart';
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
  }

  void _onTabChanged(MarketTab tab) {
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
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
    ref.read(inventoryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final int listingCount = ref.watch(marketProvider).totalListings;

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routeMarket, onLogout: _logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.market, onLogout: _logout),
      body: GameScreenBackground(
        child: ListView(
          padding: GameScrollLayout.fromLTRB(context, left: 12, top: 8, right: 12),
          children: <Widget>[
            MarketHeroBanner(listingCount: listingCount),
            const KingdomMarketBlessingBanner(locationLabel: 'Pazar'),
            const SizedBox(height: 10),
            MarketTabBar(activeTab: _tab, onTabChanged: _onTabChanged),
            const SizedBox(height: 10),
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
                      MarketTab.browse => 'Pazar Listeleri',
                      MarketTab.sell => 'Eşya Sat',
                      MarketTab.myMarket => 'Benim Pazarim',
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_tab == MarketTab.browse) const MarketBrowseTab(),
                  if (_tab == MarketTab.sell) const MarketSellTab(),
                  if (_tab == MarketTab.myMarket) const MarketMyMarketTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
