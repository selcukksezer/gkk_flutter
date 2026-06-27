import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'guild_war_design.dart';

class GuildWarTabBar extends StatelessWidget {
  const GuildWarTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    required this.icons,
  });

  final TabController controller;
  final List<String> tabs;
  final List<String> icons;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
      child: WarNeonCard(
        accent: WarPalette.gold,
        padding: const EdgeInsets.all(5),
        radius: 14,
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 10),
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                WarPalette.gold.withValues(alpha: 0.22),
                WarPalette.fuchsia.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: WarPalette.gold.withValues(alpha: 0.45)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: WarPalette.gold.withValues(alpha: 0.12), blurRadius: 10),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: WarPalette.titanium,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: List<Tab>.generate(tabs.length, (int i) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(icons[i], style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(tabs[i]),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
