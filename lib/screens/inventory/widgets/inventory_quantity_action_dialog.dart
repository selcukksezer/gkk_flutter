import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/universal_game_dialog.dart';
import '../../../core/utils/gold_format.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class InventoryQuantityActionDialog extends StatefulWidget {
  const InventoryQuantityActionDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.unitValue,
    required this.maxQuantity,
    this.showTotalValue = true,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final int unitValue;
  final int maxQuantity;
  final bool showTotalValue;

  @override
  State<InventoryQuantityActionDialog> createState() =>
      _InventoryQuantityActionDialogState();
}

class _InventoryQuantityActionDialogState
    extends State<InventoryQuantityActionDialog> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.maxQuantity < 1 ? 1 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.unitValue * _quantity;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: UniversalDialogPanel(
            borderColor: AppColors.liquidGold.withValues(alpha: 0.45),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  widget.title,
                  style: AppTextStyles.dialogTitle,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.subtitle,
                  style: AppTextStyles.dialogBody,
                ),
                const SizedBox(height: 12),
                Text(
                  'Miktar: $_quantity / ${widget.maxQuantity}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Slider(
                  value: _quantity.toDouble(),
                  min: 1,
                  max: widget.maxQuantity.toDouble(),
                  divisions: widget.maxQuantity > 1 ? widget.maxQuantity - 1 : null,
                  activeColor: AppColors.liquidGold,
                  onChanged: widget.maxQuantity <= 1
                      ? null
                      : (double value) {
                          setState(() {
                            _quantity = value.round();
                          });
                        },
                ),
                if (widget.showTotalValue)
                  Text(
                    '${formatCompactGold(total)} altin alacaksin',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.liquidGold,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ObsidianCancel(
                        label: 'Iptal',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GoldConfirm(
                        label: widget.confirmLabel,
                        onPressed: () => Navigator.of(context).pop(_quantity),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldConfirm extends StatelessWidget {
  const _GoldConfirm({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.liquidGoldGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.carbonVoid,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ObsidianCancel extends StatelessWidget {
  const _ObsidianCancel({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.darkObsidian,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.mutedTitanium.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedTitanium,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
