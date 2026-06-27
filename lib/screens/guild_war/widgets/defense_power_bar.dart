import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'guild_war_design.dart';

class DefensePowerBar extends StatelessWidget {
  const DefensePowerBar({
    super.key,
    required this.current,
    required this.max,
    this.height = 8,
    this.showLabel = true,
  });

  final int current;
  final int max;
  final double height;
  final bool showLabel;

  Color get _barColor {
    final int safeMax = max <= 0 ? 1 : max;
    final double ratio = (current.clamp(0, safeMax) / safeMax).clamp(0.0, 1.0);
    if (ratio > 0.7) return WarPalette.ruby;
    if (ratio > 0.4) return WarPalette.coral;
    return WarPalette.neon;
  }

  @override
  Widget build(BuildContext context) {
    final int safeMax = max <= 0 ? 1 : max;
    final int displayCurrent = current.clamp(0, safeMax);
    final double ratio = (displayCurrent / safeMax).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Savunma: $displayCurrent',
                  style: const TextStyle(
                    color: WarPalette.titanium,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '/ $max',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: height,
            child: Stack(
              children: <Widget>[
                Container(color: WarPalette.obsidian),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[_barColor.withValues(alpha: 0.65), _barColor],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: _barColor.withValues(alpha: 0.35), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
