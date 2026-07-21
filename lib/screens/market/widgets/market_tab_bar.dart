import 'package:flutter/material.dart';

import 'market_design.dart';

enum MarketTab { browse, sell, myMarket }

/// Legacy wrapper — delegates to [MarketTabStrip] design system.
class MarketTabBar extends StatelessWidget {
  const MarketTabBar({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  final MarketTab activeTab;
  final ValueChanged<MarketTab> onTabChanged;

  int _index(MarketTab tab) => switch (tab) {
        MarketTab.browse => 0,
        MarketTab.sell => 1,
        MarketTab.myMarket => 2,
      };

  MarketTab _tab(int index) => switch (index) {
        0 => MarketTab.browse,
        1 => MarketTab.sell,
        _ => MarketTab.myMarket,
      };

  @override
  Widget build(BuildContext context) {
    return MarketTabStrip(
      labels: const <String>['Gozat', 'Sat', 'Pazarim'],
      activeIndex: _index(activeTab),
      onChanged: (int index) => onTabChanged(_tab(index)),
    );
  }
}
