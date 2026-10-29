import 'package:flutter/material.dart';

import '../../../components/layout/game_chrome.dart';
import 'leaderboard_design.dart';

/// 2027 Aion 2 Sticky "My Rank" Footer Card adhering to 390x844 SafeArea.
/// Floats pinned above [GameBottomBar] with authentic frosted glassmorphism,
/// glowing Daeva avatar frame, Combat Power (CP), and rank status.
class LeaderboardStickyPlayerFooter extends StatelessWidget {
  const LeaderboardStickyPlayerFooter({
    super.key,
    required this.username,
    required this.subtitle,
    required this.valueLabel,
    required this.rankLabel,
    required this.categoryKey,
    this.playerLevel = 1,
    this.onTap,
  });

  final String username;
  final String subtitle;
  final String valueLabel;
  final String rankLabel;
  final String categoryKey;
  final int playerLevel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double bottomOffset = gameBottomBarClearance(context) + 6.0;

    return Positioned(
      left: 14,
      right: 14,
      bottom: bottomOffset,
      child: LeaderboardPlayerCard(
        username: username,
        subtitle: subtitle,
        valueLabel: valueLabel,
        rankLabel: rankLabel,
        categoryKey: categoryKey,
      ),
    );
  }
}
