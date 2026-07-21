import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

Future<void> showLootRewardDialog(
  BuildContext context, {
  required String title,
  required String rewardName,
  required int rewardQuantity,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: const Color(0xFF141B2A),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.liquidGold,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.card_giftcard_rounded,
              size: 48, color: AppColors.liquidGold),
          const SizedBox(height: 12),
          Text(
            rewardName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (rewardQuantity > 1) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'x$rewardQuantity',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.liquidGold,
            foregroundColor: AppColors.carbonVoid,
          ),
          child: const Text('Harika!'),
        ),
      ],
    ),
  );
}
