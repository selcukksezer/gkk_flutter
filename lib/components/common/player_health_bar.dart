import 'package:flutter/material.dart';

import '../../core/utils/player_health.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Compact current/max health bar for PvP, character, home warnings.
class PlayerHealthBar extends StatelessWidget {
  const PlayerHealthBar({
    super.key,
    required this.health,
    required this.maxHealth,
    this.height = 8,
    this.showLabel = true,
    this.compactLabel = false,
    this.status,
  });

  final int health;
  final int maxHealth;
  final double height;
  final bool showLabel;
  final bool compactLabel;
  final PlayerHealthStatus? status;

  @override
  Widget build(BuildContext context) {
    final PlayerHealthStatus resolved = status ??
        resolveHealthStatus(health: health, maxHealth: maxHealth);
    final double fraction = healthFraction(health: health, maxHealth: maxHealth);
    final Color fill = healthStatusColor(resolved);
    final bool critical = resolved == PlayerHealthStatus.critical;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                Icon(Icons.favorite_rounded, size: compactLabel ? 12 : 14, color: fill),
                const SizedBox(width: 4),
                Text(
                  compactLabel
                      ? formatHealthRatio(health, maxHealth)
                      : 'Can ${formatHealthRatio(health, maxHealth)}',
                  style: (compactLabel ? AppTextStyles.micro : AppTextStyles.captionBold).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (critical) ...<Widget>[
                  const Spacer(),
                  Text(
                    'PvP için yetersiz',
                    style: AppTextStyles.micro.copyWith(color: AppColors.mysticRuby),
                  ),
                ],
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: LinearProgressIndicator(
            minHeight: height,
            value: fraction,
            backgroundColor: AppColors.darkObsidian.withValues(alpha: 0.85),
            valueColor: AlwaysStoppedAnimation<Color>(fill),
          ),
        ),
      ],
    );
  }
}
