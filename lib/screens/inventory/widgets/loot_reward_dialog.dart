import 'package:flutter/material.dart';

import '../../../components/common/universal_game_dialog.dart';
import '../../../theme/app_colors.dart';

Future<void> showLootRewardDialog(
  BuildContext context, {
  required String title,
  required String rewardName,
  required int rewardQuantity,
}) {
  return UniversalGameDialog.showInfo(
    context,
    title: title,
    message: '',
    confirmLabel: 'Harika!',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.card_giftcard_rounded,
          size: 48,
          color: AppColors.liquidGold,
        ),
        const SizedBox(height: 12),
        Text(
          rewardName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (rewardQuantity > 1) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'x$rewardQuantity',
            style: const TextStyle(color: AppColors.mutedTitanium),
          ),
        ],
      ],
    ),
  );
}
