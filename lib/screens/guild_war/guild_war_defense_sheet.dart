import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../l10n/l10n.dart';

Future<int?> showGuildWarDefenseSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (ctx) => const _DefenseSheet(),
  );
}

class _DefenseSheet extends StatefulWidget {
  const _DefenseSheet();

  @override
  State<_DefenseSheet> createState() => _DefenseSheetState();
}

class _DefenseSheetState extends State<_DefenseSheet> {
  double _gems = 5;

  @override
  Widget build(BuildContext context) {
    final defenseGain = (_gems * 10).round();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
        MediaQuery.of(context).padding.bottom + AppSpacing.base,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🛡 Savunma Ekle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '1 Elmas = 10 Savunma Gücü',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💎 ${_gems.round()} Elmas',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                '+$defenseGain Savunma',
                style: const TextStyle(color: AppColors.success, fontSize: 14),
              ),
            ],
          ),
          Slider(
            value: _gems,
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: AppColors.gold,
            onChanged: (v) => setState(() => _gems = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _gems.round()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(context.l10n.savunma_ekle_2),
            ),
          ),
        ],
      ),
    );
  }
}
