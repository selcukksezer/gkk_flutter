import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/market_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import 'widgets/market_browse_tab.dart';
import 'widgets/market_helpers.dart';
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
    ]);
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
    final int gold = ref.watch(playerProvider).profile?.gold ?? 0;

    return Scaffold(
      appBar: GameTopBar(title: context.l10n.routeMarket, onLogout: _logout),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(currentRoute: AppRoutes.market, onLogout: _logout),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[AppColors.bgDeep, AppColors.bgBase],
          ),
        ),
        child: ListView(
          padding: GameScrollLayout.fromLTRB(context, left: 12, top: 8, right: 12),
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Oyuncu Pazari',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldGlow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.goldDim.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    formatMarketGold(gold),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MarketTabBar(activeTab: _tab, onTabChanged: _onTabChanged),
            const SizedBox(height: 8),
            if (_tab == MarketTab.browse) const MarketBrowseTab(),
            if (_tab == MarketTab.sell) const MarketSellTab(),
            if (_tab == MarketTab.myMarket) const MarketMyMarketTab(),
          ],
        ),
      ),
    );
  }
}
