import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

export 'trade_countdown_seal.dart';
export 'trade_filigree_frame.dart';
export 'trade_lock_in_aura.dart';
export 'trade_log_card.dart';

/// 2027 Aion 2 Mobile — Dotted grid + celestial dark fantasy nebula backdrop.
class TradeBackdrop extends StatelessWidget {
  const TradeBackdrop({
    super.key,
    required this.child,
    this.accent = AppColors.liquidGold,
  });

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.carbonVoid,
            AppColors.spaceNavy,
            AppColors.carbonVoid,
          ],
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _TradeGridPainter(accent: accent),
        child: child,
      ),
    );
  }
}

class _TradeGridPainter extends CustomPainter {
  _TradeGridPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Primary Celestial Gold / Toxic Nebula
    final Paint orb = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accent.withValues(alpha: 0.16),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.88, size.height * 0.08),
        radius: 220,
      ));
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), 220, orb);

    // 2. Astral Fuchsia Deep Glow
    final Paint orb2 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.cyberFuchsia.withValues(alpha: 0.10),
          AppColors.cyberFuchsia.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.06, size.height * 0.72),
        radius: 240,
      ));
    canvas.drawCircle(Offset(size.width * 0.06, size.height * 0.72), 240, orb2);

    // 3. Central Dark Fantasy Trade Altar Ring
    final Paint altarRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.liquidGold.withValues(alpha: 0.05);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.42), 160, altarRingPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.42), 210, altarRingPaint);

    // 4. Dot Grid
    final Paint dot = Paint()..color = AppColors.mutedTitanium.withValues(alpha: 0.12);
    const double gap = 26;
    for (double y = 10; y < size.height; y += gap) {
      for (double x = 10; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.0, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TradeGridPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Ornate Neon Panel with tactile metallic edge bevels.
class TradeNeonPanel extends StatelessWidget {
  const TradeNeonPanel({
    super.key,
    required this.child,
    this.accent = AppColors.liquidGold,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.spaceNavy.withValues(alpha: 0.94),
            AppColors.carbonVoid.withValues(alpha: 0.92),
            AppColors.darkObsidian.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.carbonVoid.withValues(alpha: 0.8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

Color _tradeButtonGradientEnd(Color color) {
  if (color == AppColors.liquidGold) {
    return AppColors.warningSolar.withValues(alpha: 0.85);
  }
  if (color == AppColors.mysticRuby) {
    return AppColors.coralFlare.withValues(alpha: 0.9);
  }
  if (color == AppColors.toxicNeon) {
    return AppColors.liquidGold.withValues(alpha: 0.75);
  }
  if (color == AppColors.cyberFuchsia) {
    return AppColors.mysticRuby.withValues(alpha: 0.85);
  }
  return color.withValues(alpha: 0.55);
}

class TradePrimaryButton extends StatelessWidget {
  const TradePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.liquidGold,
    this.textColor = AppColors.carbonVoid,
    this.height = 48,
    this.fontSize = 13,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double height;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: disabled
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[color, _tradeButtonGradientEnd(color)],
                  ),
            color: disabled ? AppColors.darkObsidian : null,
            boxShadow: disabled
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.38),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: Border.all(
              color: disabled
                  ? AppColors.mutedTitanium.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: fontSize + 3, color: disabled ? AppColors.mutedTitanium : textColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: disabled ? AppColors.mutedTitanium : textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TradeSecondaryButton extends StatelessWidget {
  const TradeSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.mysticRuby,
    this.textColor = AppColors.textPrimary,
    this.height = 48,
    this.fontSize = 13,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double height;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: disabled
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      color.withValues(alpha: 0.72),
                      _tradeButtonGradientEnd(color).withValues(alpha: 0.55),
                    ],
                  ),
            color: disabled ? AppColors.darkObsidian : null,
            border: Border.all(color: color.withValues(alpha: disabled ? 0.25 : 0.55)),
            boxShadow: disabled
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: fontSize + 3, color: disabled ? AppColors.mutedTitanium : textColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: disabled ? AppColors.mutedTitanium : textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
