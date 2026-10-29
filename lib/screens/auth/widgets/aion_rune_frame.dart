import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';

/// Luxury Aion-2 Runic Glassmorphism Card with animated glowing borders
/// and precision vector-drawn fantasy corner brackets.
class AionRuneCard extends StatefulWidget {
  const AionRuneCard({
    super.key,
    required this.child,
    this.accentColor = const Color(0xFFD4AF37), // Aion Celestial Gold
    this.glowColor = const Color(0xFF38BDF8), // Arcane Cyan
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = 22.0,
  });

  final Widget child;
  final Color accentColor;
  final Color glowColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  State<AionRuneCard> createState() => _AionRuneCardState();
}

class _AionRuneCardState extends State<AionRuneCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, Widget? _) {
        final double pulse = _pulseAnimation.value;
        return CustomPaint(
          foregroundPainter: _AionRuneBorderPainter(
            pulse: pulse,
            accentColor: widget.accentColor,
            glowColor: widget.glowColor,
            radius: widget.borderRadius,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xEE090E1D), // Obsidian Astral Navy
                      Color(0xF804060D), // Deep Celestial Void
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.08 + pulse * 0.10),
                      blurRadius: 32,
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    // Top specular highlight sheen
                    Positioned(
                      top: 0,
                      left: 20,
                      right: 20,
                      child: IgnorePointer(
                        child: Container(
                          height: 1.2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.transparent,
                                widget.accentColor.withValues(alpha: 0.35 + pulse * 0.35),
                                widget.glowColor.withValues(alpha: 0.25 + pulse * 0.25),
                                Colors.transparent,
                              ],
                              stops: const <double>[0.0, 0.45, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Card contents
                    Padding(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AionRuneBorderPainter extends CustomPainter {
  _AionRuneBorderPainter({
    required this.pulse,
    required this.accentColor,
    required this.glowColor,
    required this.radius,
  });

  final double pulse;
  final Color accentColor;
  final Color glowColor;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1. Soft breathing ambient border glow
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..color = glowColor.withValues(alpha: 0.15 + pulse * 0.20);
    canvas.drawRRect(rrect, glowPaint);

    // 2. Crisp perimeter frame with gold-to-cyan gradient
    final Paint framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accentColor.withValues(alpha: 0.55 + pulse * 0.35),
          glowColor.withValues(alpha: 0.25 + pulse * 0.20),
          accentColor.withValues(alpha: 0.30 + pulse * 0.30),
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, framePaint);

    // 3. Ornate Aion-2 fantasy corner brackets & runic chevrons
    final Paint runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = accentColor.withValues(alpha: 0.75 + pulse * 0.25);

    const double cornerArm = 24.0;
    const double inset = 6.0;

    // Top-Left corner bracket
    canvas.drawLine(
      const Offset(inset, inset + cornerArm),
      const Offset(inset, inset + 8),
      runePaint,
    );
    canvas.drawLine(
      const Offset(inset + 8, inset),
      const Offset(inset + cornerArm, inset),
      runePaint,
    );
    _drawRuneDiamond(canvas, const Offset(inset + 4, inset + 4), 3.0, runePaint);

    // Top-Right corner bracket
    canvas.drawLine(
      Offset(size.width - inset, inset + cornerArm),
      Offset(size.width - inset, inset + 8),
      runePaint,
    );
    canvas.drawLine(
      Offset(size.width - inset - 8, inset),
      Offset(size.width - inset - cornerArm, inset),
      runePaint,
    );
    _drawRuneDiamond(canvas, Offset(size.width - inset - 4, inset + 4), 3.0, runePaint);

    // Bottom-Left corner bracket
    canvas.drawLine(
      Offset(inset, size.height - inset - cornerArm),
      Offset(inset, size.height - inset - 8),
      runePaint,
    );
    canvas.drawLine(
      Offset(inset + 8, size.height - inset),
      Offset(inset + cornerArm, size.height - inset),
      runePaint,
    );
    _drawRuneDiamond(canvas, Offset(inset + 4, size.height - inset - 4), 3.0, runePaint);

    // Bottom-Right corner bracket
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - cornerArm),
      Offset(size.width - inset, size.height - inset - 8),
      runePaint,
    );
    canvas.drawLine(
      Offset(size.width - inset - 8, size.height - inset),
      Offset(size.width - inset - cornerArm, size.height - inset),
      runePaint,
    );
    _drawRuneDiamond(canvas, Offset(size.width - inset - 4, size.height - inset - 4), 3.0, runePaint);

    // Center runic diamond seals along the borders
    _drawRuneDiamond(canvas, Offset(size.width * 0.5, 0), 3.5, runePaint);
    _drawRuneDiamond(canvas, Offset(size.width * 0.5, size.height), 3.5, runePaint);
  }

  void _drawRuneDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final Path path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AionRuneBorderPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.glowColor != glowColor;
  }
}
