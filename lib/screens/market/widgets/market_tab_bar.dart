import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

enum MarketTab { browse, sell, myMarket }

class MarketTabBar extends StatelessWidget {
  const MarketTabBar({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  final MarketTab activeTab;
  final ValueChanged<MarketTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: <Widget>[
          _tab(MarketTab.browse, 'Gozat'),
          _tab(MarketTab.sell, 'Sat'),
          _tab(MarketTab.myMarket, 'Pazarim'),
        ],
      ),
    );
  }

  Expanded _tab(MarketTab tab, String label) {
    final bool active = activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: active ? AppColors.accentBlue : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
