import 'package:flutter/material.dart';

import '../../core/utils/cosmetic_title.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Liquid-gold chip for reputation shop cosmetic titles (e.g. Onur Nişanı).
class CosmeticTitleBadge extends StatelessWidget {
  const CosmeticTitleBadge({
    super.key,
    required this.titleKey,
    this.compact = false,
  });

  final String? titleKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String? label = cosmeticTitleDisplayLabel(titleKey);
    if (label == null) return const SizedBox.shrink();

    final double fontSize = compact ? 9 : 11;
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.liquidGold.withValues(alpha: 0.18),
            AppColors.liquidGold.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.55),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.2),
            blurRadius: compact ? 4 : 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.workspace_premium_rounded,
            size: compact ? 11 : 14,
            color: AppColors.liquidGold,
          ),
          SizedBox(width: compact ? 3 : 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (compact ? AppTextStyles.micro : AppTextStyles.caption).copyWith(
                color: AppColors.liquidGold,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? 0.4 : 0.8,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
