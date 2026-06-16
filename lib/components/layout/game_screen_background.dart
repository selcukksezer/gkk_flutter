import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Dotted grid overlay — Carbon Void / Space Navy aesthetic.
class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    this.spacing = 16,
    this.dotRadius = 1.1,
    this.dotOpacity = 0.07,
  });

  final double spacing;
  final double dotRadius;
  final double dotOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: dotOpacity)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) =>
      spacing != oldDelegate.spacing ||
      dotRadius != oldDelegate.dotRadius ||
      dotOpacity != oldDelegate.dotOpacity;
}

/// Full-screen background — home-style gradient + dot grid + subtle ambient glow.
class GameScreenBackground extends StatelessWidget {
  const GameScreenBackground({
    super.key,
    required this.child,
    this.showAmbientGlow = true,
  });

  final Widget child;
  final bool showAmbientGlow;

  static const Color carbonVoid = Color(0xFF080B12);
  static const Color spaceNavy = Color(0xFF121826);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF070B14),
                  carbonVoid,
                  Color(0xFF030509),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: CustomPaint(painter: DotGridPainter()),
        ),
        if (showAmbientGlow) ...<Widget>[
          Positioned(
            top: -160,
            left: -120,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      spaceNavy.withValues(alpha: 0.45),
                      spaceNavy.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -140,
            child: IgnorePointer(
              child: Container(
                width: 460,
                height: 460,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.gold.withValues(alpha: 0.06),
                      AppColors.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

/// Card/panel shell with dotted dark surface (#121826 → #080B12).
class DottedPanel extends StatelessWidget {
  const DottedPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 14,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.06),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            GameScreenBackground.spaceNavy.withValues(alpha: 0.92),
            GameScreenBackground.carbonVoid.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(
                painter: DotGridPainter(spacing: 14, dotOpacity: 0.055),
              ),
            ),
            Padding(
              padding: padding ?? const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
