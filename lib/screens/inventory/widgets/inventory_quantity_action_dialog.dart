import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/universal_game_dialog.dart';
import '../../../core/utils/gold_format.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Modal dialog for choosing a stack or currency item quantity (e.g. Selling, Splitting).
///
/// Designed to AAA mobile standards:
/// - Precise +/- step controls with tactile haptics
/// - Min, 25%, 50%, Max quick preset selectors
/// - Safe boundary clamping preventing zero/negative division assert crashes
/// - Custom gold slider with glow track
/// - Dynamic financial breakdown / stack remaining indicator
/// - Tactile Liquid Gold confirmation CTA & Obsidian cancellation button
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

  int get _effectiveMax => math.max(1, widget.maxQuantity);

  @override
  void initState() {
    super.initState();
    _quantity = 1.clamp(1, _effectiveMax);
  }

  void _setQuantity(int nextVal) {
    final int clamped = nextVal.clamp(1, _effectiveMax);
    if (clamped != _quantity) {
      HapticFeedback.selectionClick();
      setState(() {
        _quantity = clamped;
      });
    }
  }

  void _step(int delta) {
    _setQuantity(_quantity + delta);
  }

  void _setPercentage(double fraction) {
    if (_effectiveMax <= 1) {
      _setQuantity(1);
      return;
    }
    final int target = (fraction * _effectiveMax).round();
    _setQuantity(target);
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.unitValue * _quantity;
    final bool canDecrement = _quantity > 1;
    final bool canIncrement = _quantity < _effectiveMax;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: UniversalDialogPanel(
            borderColor: AppColors.liquidGold.withValues(alpha: 0.45),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.base,
              AppSpacing.lg,
              AppSpacing.base,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header Row (Title, Subtitle, Close)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: AppTextStyles.dialogTitle,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.subtitle,
                            style: AppTextStyles.dialogBody,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.mutedTitanium,
                      splashRadius: 18,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),

                // Stepper + Quantity Display Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: AppColors.borderDefault.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          // Decrement Stepper
                          _StepperButton(
                            icon: Icons.remove_rounded,
                            enabled: canDecrement,
                            onPressed: () => _step(-1),
                            tooltip: '1 Azalt',
                          ),

                          // Quantity readout
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '$_quantity',
                                style: AppTextStyles.h1.copyWith(
                                  color: AppColors.liquidGold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '/ $_effectiveMax',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),

                          // Increment Stepper
                          _StepperButton(
                            icon: Icons.add_rounded,
                            enabled: canIncrement,
                            onPressed: () => _step(1),
                            tooltip: '1 Arttır',
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: AppColors.liquidGold,
                          inactiveTrackColor: AppColors.darkObsidian,
                          thumbColor: AppColors.goldLight,
                          overlayColor: AppColors.goldGlow,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                            elevation: 3,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                        ),
                        child: Slider(
                          value: _quantity.toDouble(),
                          min: 1.0,
                          max: _effectiveMax.toDouble(),
                          divisions:
                              _effectiveMax > 1 ? _effectiveMax - 1 : null,
                          onChanged: _effectiveMax <= 1
                              ? null
                              : (double value) {
                                  final int rounded = value.round();
                                  if (rounded != _quantity) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _quantity = rounded;
                                    });
                                  }
                                },
                        ),
                      ),

                      // Preset Quick Action Buttons (Min, 25%, 50%, Max)
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _PresetPill(
                              label: 'Min',
                              isSelected: _quantity == 1,
                              onPressed: () => _setQuantity(1),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          if (_effectiveMax >= 4) ...<Widget>[
                            Expanded(
                              child: _PresetPill(
                                label: '25%',
                                isSelected: _quantity ==
                                    (0.25 * _effectiveMax).round().clamp(1, _effectiveMax),
                                onPressed: () => _setPercentage(0.25),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          if (_effectiveMax >= 2) ...<Widget>[
                            Expanded(
                              child: _PresetPill(
                                label: '50%',
                                isSelected: _quantity ==
                                    (0.50 * _effectiveMax).round().clamp(1, _effectiveMax),
                                onPressed: () => _setPercentage(0.50),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Expanded(
                            child: _PresetPill(
                              label: 'Max',
                              isSelected: _quantity == _effectiveMax,
                              isAccent: true,
                              onPressed: () => _setQuantity(_effectiveMax),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Breakdown Panel (Total Gold or Stack Split Remaining)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: widget.showTotalValue
                          ? AppColors.liquidGold.withValues(alpha: 0.25)
                          : AppColors.borderFaint,
                    ),
                  ),
                  child: widget.showTotalValue
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  size: 16,
                                  color: AppColors.liquidGold,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Toplam Kazanç:',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${formatCompactGold(total)} Altın',
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.liquidGold,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Ayrılan: $_quantity',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Kalan: ${math.max(0, widget.maxQuantity - _quantity)}',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.mutedTitanium,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Confirmation / Cancellation CTAs
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ObsidianCancel(
                        label: 'İptal',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _GoldConfirm(
                        label: widget.confirmLabel,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop(_quantity);
                        },
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

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.darkObsidian
                  : AppColors.bgDeep.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: enabled
                    ? AppColors.borderBright.withValues(alpha: 0.6)
                    : AppColors.borderFaint.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? AppColors.textPrimary
                  : AppColors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({
    required this.label,
    required this.isSelected,
    required this.onPressed,
    this.isAccent = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isSelected
        ? (isAccent
            ? AppColors.liquidGold.withValues(alpha: 0.3)
            : AppColors.accentBlue.withValues(alpha: 0.25))
        : AppColors.darkObsidian.withValues(alpha: 0.7);

    final Color borderColor = isSelected
        ? (isAccent ? AppColors.liquidGold : AppColors.accentBlue)
        : AppColors.borderDefault.withValues(alpha: 0.5);

    final Color textColor = isSelected
        ? (isAccent ? AppColors.liquidGold : AppColors.accentBlue)
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.liquidGoldGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.liquidGold.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.md,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.dialogButton,
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
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.darkObsidian,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: AppColors.mutedTitanium.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.md,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.dialogButtonMuted,
            ),
          ),
        ),
      ),
    );
  }
}
