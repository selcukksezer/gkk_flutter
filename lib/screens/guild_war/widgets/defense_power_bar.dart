import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

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
    final ratio = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    if (ratio > 0.7) return AppColors.danger;
    if (ratio > 0.4) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Savunma: $current',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '/ $max',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Container(color: AppColors.borderFaint),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_barColor.withValues(alpha: 0.7), _barColor],
                      ),
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
