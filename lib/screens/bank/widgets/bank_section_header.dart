import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'bank_design.dart';

/// Luxury Aion 2 section header with runic emblems, crystal selection pills,
/// and metallic action button.
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
    this.icon,
  });

  final String title;
  final String actionText;
  final Color actionColor;
  final bool enabled;
  final bool loading;
  final VoidCallback onAction;
  final int selectedCount;
  final VoidCallback onClear;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final IconData effectiveIcon = icon ??
        (title.toLowerCase().contains('kasa') ||
                title.toLowerCase().contains('banka')
            ? Icons.account_balance_rounded
            : Icons.backpack_rounded);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
      decoration: BoxDecoration(
        color: BankDesign.royalObsidian.withValues(alpha: 0.55),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          // Runic Section Emblem
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: actionColor.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Icon(
              effectiveIcon,
              size: 14,
              color: actionColor,
            ),
          ),
          const SizedBox(width: 8),

          // Title
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),

          // Crystal Selection Count Pill
          if (selectedCount > 0) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    actionColor.withValues(alpha: 0.25),
                    actionColor.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: actionColor.withValues(alpha: 0.6),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: actionColor.withValues(alpha: 0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: actionColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$selectedCount seçili',
                    style: TextStyle(
                      color: actionColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),

          // Clear Button
          if (selectedCount > 0) ...<Widget>[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Temizle',
                    style: TextStyle(
                      color: AppColors.mutedTitanium.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Primary Transfer Action Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (!enabled || loading) ? null : onAction,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: (!enabled || loading)
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            actionColor,
                            actionColor.withValues(alpha: 0.75),
                          ],
                        ),
                  color: (!enabled || loading) ? AppColors.darkObsidian : null,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (!enabled || loading)
                        ? Colors.white.withValues(alpha: 0.08)
                        : actionColor.withValues(alpha: 0.8),
                    width: 1.0,
                  ),
                  boxShadow: (!enabled || loading)
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color: actionColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: loading
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.carbonVoid,
                        ),
                      )
                    : Text(
                        actionText,
                        style: TextStyle(
                          color: (!enabled || loading)
                              ? AppColors.mutedTitanium
                              : AppColors.carbonVoid,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
