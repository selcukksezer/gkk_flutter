import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

/// Dotted grid + glow backdrop (Mekan / character neon style, GKK palette).
class TradeBackdrop extends StatelessWidget {
  const TradeBackdrop({super.key, required this.child, this.accent = AppColors.liquidGold});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.carbonVoid, AppColors.spaceNavy, AppColors.carbonVoid],
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
    final Paint orb = Paint()
      ..shader = RadialGradient(
        colors: <Color>[accent.withValues(alpha: 0.14), accent.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.88, size.height * 0.08), radius: 200));
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), 200, orb);

    final Paint orb2 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.cyberFuchsia.withValues(alpha: 0.08),
          AppColors.cyberFuchsia.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.06, size.height * 0.72), radius: 220));
    canvas.drawCircle(Offset(size.width * 0.06, size.height * 0.72), 220, orb2);

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
            AppColors.carbonVoid.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.32), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 6)),
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
    this.height = 46,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
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
                    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: disabled ? AppColors.mutedTitanium : textColor,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.6,
            ),
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
    this.height = 46,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
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
            border: Border.all(color: color.withValues(alpha: disabled ? 0.25 : 0.45)),
            boxShadow: disabled
                ? null
                : <BoxShadow>[
                    BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: disabled ? AppColors.mutedTitanium : textColor,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
