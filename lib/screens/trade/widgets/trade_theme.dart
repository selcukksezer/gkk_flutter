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

class TradePrimaryButton extends StatelessWidget {
  const TradePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.liquidGold,
    this.textColor = AppColors.carbonVoid,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;

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
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: disabled
                ? null
                : LinearGradient(colors: <Color>[color, AppColors.warningSolar.withValues(alpha: 0.85)]),
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
              fontSize: 13,
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
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.55)),
            color: color.withValues(alpha: 0.12),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
