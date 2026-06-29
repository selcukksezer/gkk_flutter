import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'bank_design.dart';

class BankSectionHeader extends StatelessWidget {
  const BankSectionHeader({
    super.key,
    required this.title,
    required this.actionText,
    required this.actionColor,
    required this.enabled,
    required this.loading,
    required this.onAction,
    required this.selectedCount,
    required this.onClear,
  });

  final String title;
  final String actionText;
  final Color actionColor;
  final bool enabled;
  final bool loading;
  final VoidCallback onAction;
  final int selectedCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: BankDesign.gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          if (selectedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: actionColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: actionColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                '$selectedCount seçili',
                style: TextStyle(color: actionColor, fontSize: 10),
              ),
            ),
          const Spacer(),
          if (selectedCount > 0)
            TextButton(
              onPressed: onClear,
              child: const Text(
                'Temizle',
                style: TextStyle(color: BankDesign.muted, fontSize: 12),
              ),
            ),
          FilledButton(
            onPressed: (!enabled || loading) ? null : onAction,
            style: FilledButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: AppColors.carbonVoid,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.carbonVoid,
                    ),
                  )
                : Text(
                    actionText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
