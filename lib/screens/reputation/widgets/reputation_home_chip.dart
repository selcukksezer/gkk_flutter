import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../mekans/widgets/mekan_design.dart';

/// Compact home hub chip linking to reputation screen.
class ReputationHomeChip extends StatelessWidget {
  const ReputationHomeChip({
    super.key,
    required this.reputation,
    required this.tierTitle,
    required this.tierColor,
  });

  final int reputation;
  final String tierTitle;
  final Color tierColor;

  String _compact(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push(AppRoutes.reputation),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              MekanPalette.navy.withValues(alpha: 0.92),
              MekanPalette.void_.withValues(alpha: 0.96),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MekanPalette.gold.withValues(alpha: 0.35)),
          boxShadow: <BoxShadow>[
            BoxShadow(color: MekanPalette.gold.withValues(alpha: 0.1), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.military_tech_rounded, color: MekanPalette.gold, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _compact(reputation),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: MekanPalette.textHi,
                    height: 1,
                  ),
                ),
                Text(
                  tierTitle,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tierColor),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 16, color: MekanPalette.textLow),
          ],
        ),
      ),
    );
  }
}
