import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

class GuildWarTabBar extends StatelessWidget {
  const GuildWarTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: tabs.length > 3,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        indicator: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.goldLight,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}
