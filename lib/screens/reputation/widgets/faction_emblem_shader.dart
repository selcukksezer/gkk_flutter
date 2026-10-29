import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'faction_standing_model.dart';

/// Animated Emblem Shader rendering authentic 2027 Aion 2 Mobile faction crests.
class FactionEmblemShaderWidget extends StatefulWidget {
  const FactionEmblemShaderWidget({
    super.key,
    required this.paletteType,
    this.category = FactionCategory.order,
    this.size = 54.0,
    this.showGlow = true,
    this.isInteractive = true,
  });

  final FactionPaletteType paletteType;
  final FactionCategory category;
  final double size;
  final bool showGlow;
  final bool isInteractive;

  @override
  State<FactionEmblemShaderWidget> createState() => _FactionEmblemShaderWidgetState();
}

class _FactionEmblemShaderWidgetState extends State<FactionEmblemShaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _flareScale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    if (!widget.isInteractive) return;
    setState(() => _flareScale = 1.15);
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _flareScale = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerPulse,
      child: AnimatedScale(
        scale: _flareScale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: FactionEmblemPainter(
                palette: widget.paletteType,
                category: widget.category,
                animationValue: _controller.value,
                showGlow: widget.showGlow,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Vector FX Painter executing shader-like lighting, rune rotations, and faction crests.
class FactionEmblemPainter extends CustomPainter {
  FactionEmblemPainter({
    required this.palette,
    required this.category,
    required this.animationValue,
    this.showGlow = true,
  });

  final FactionPaletteType palette;
  final FactionCategory category;
  final double animationValue; // 0.0 to 1.0
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = math.min(cx, cy);

    // 1. Dynamic Breathing Pulse
    final double pulse = 0.88 + 0.12 * math.sin(animationValue * 2 * math.pi);

    // 2. Outer Radial Glow Aura
    if (showGlow) {
      final Paint auraPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.primary.withValues(alpha: 0.38 * pulse),
            palette.secondary.withValues(alpha: 0.18 * pulse),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius * 1.35));

      canvas.drawCircle(Offset(cx, cy), radius * 1.3, auraPaint);
    }

    // 3. Rotating Celestial Rune Ring
    _drawRunicRings(canvas, cx, cy, radius, pulse);

    // 4. Orbiting Specular Particle Sparks
    _drawParticleSparks(canvas, cx, cy, radius);

    // 5. Category / Palette specific Emblem Geometry
    switch (palette) {
      case FactionPaletteType.deepAzure:
        _drawAzureDivineCrest(canvas, size, cx, cy, radius, pulse);
        break;
      case FactionPaletteType.abyssalCrimson:
        _drawCrimsonAbyssalCrest(canvas, size, cx, cy, radius, pulse);
        break;
      case FactionPaletteType.emeraldAura:
        _drawEmeraldArtisanCrest(canvas, size, cx, cy, radius, pulse);
        break;
    }

    // 6. Specular Shimmer Sweep
    _drawShimmerSweep(canvas, size, cx, cy, radius);
  }

  void _drawRunicRings(Canvas canvas, double cx, double cy, double r, double pulse) {
    // Outer Border Ring
    final Paint outerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = SweepGradient(
        colors: <Color>[
          palette.primary,
          palette.accent,
          palette.secondary,
          palette.primary,
        ],
        transform: GradientRotation(animationValue * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.88));

    canvas.drawCircle(Offset(cx, cy), r * 0.88, outerRing);

    // Etched Astrological Rune Ticks
    final Paint tickPaint = Paint()
      ..color = palette.accent.withValues(alpha: 0.55 * pulse)
      ..strokeWidth = 1.2;

    const int totalTicks = 8;
    for (int i = 0; i < totalTicks; i++) {
      final double angle = (i * 2 * math.pi / totalTicks) - (animationValue * 2 * math.pi * 0.4);
      final double innerR = (i % 2 == 0) ? r * 0.78 : r * 0.82;
      final double outerR = r * 0.87;
      final double x1 = cx + math.cos(angle) * innerR;
      final double y1 = cy + math.sin(angle) * innerR;
      final double x2 = cx + math.cos(angle) * outerR;
      final double y2 = cy + math.sin(angle) * outerR;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
    }
  }

  void _drawParticleSparks(Canvas canvas, double cx, double cy, double r) {
    final Paint sparkPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double phase = (animationValue + (i * 0.25)) % 1.0;
      final double angle = phase * 2 * math.pi;
      final double dist = r * (0.65 + 0.2 * math.sin(phase * 4 * math.pi));
      final double px = cx + math.cos(angle) * dist;
      final double py = cy + math.sin(angle) * dist;
      final double sparkSize = 1.6 + 0.8 * math.sin(phase * 2 * math.pi);

      sparkPaint.color = palette.glow.withValues(alpha: (1.0 - (dist / r) * 0.5).clamp(0.2, 0.9));
      canvas.drawCircle(Offset(px, py), sparkSize, sparkPaint);
    }
  }


  void _drawAzureDivineCrest(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double r,
    double pulse,
  ) {
    // Archangel Wings
    final Paint wingFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFFFFFFFF),
          palette.primary,
          palette.secondary,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint wingOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFE0F7FA);

    // Left Wing
    final Path left = Path();
    left.moveTo(cx - r * 0.06, cy + r * 0.28);
    left.cubicTo(cx - r * 0.35, cy + r * 0.15, cx - r * 0.75, cy - r * 0.05, cx - r * 0.8, cy - r * 0.5);
    left.cubicTo(cx - r * 0.55, cy - r * 0.3, cx - r * 0.35, cy - r * 0.2, cx - r * 0.12, cy - r * 0.25);
    left.cubicTo(cx - r * 0.4, cy - r * 0.02, cx - r * 0.28, cy + r * 0.12, cx - r * 0.06, cy + r * 0.28);
    left.close();

    canvas.drawPath(left, wingFill);
    canvas.drawPath(left, wingOutline);

    // Right Wing
    final Path right = Path();
    right.moveTo(cx + r * 0.06, cy + r * 0.28);
    right.cubicTo(cx + r * 0.35, cy + r * 0.15, cx + r * 0.75, cy - r * 0.05, cx + r * 0.8, cy - r * 0.5);
    right.cubicTo(cx + r * 0.55, cy - r * 0.3, cx + r * 0.35, cy - r * 0.2, cx + r * 0.12, cy - r * 0.25);
    right.cubicTo(cx + r * 0.4, cy - r * 0.02, cx + r * 0.28, cy + r * 0.12, cx + r * 0.06, cy + r * 0.28);
    right.close();

    canvas.drawPath(right, wingFill);
    canvas.drawPath(right, wingOutline);

    // Center Crystal Spire
    final Path crystal = Path();
    crystal.moveTo(cx, cy - r * 0.62);
    crystal.lineTo(cx + r * 0.15, cy - r * 0.08);
    crystal.lineTo(cx, cy + r * 0.48);
    crystal.lineTo(cx - r * 0.15, cy - r * 0.08);
    crystal.close();

    final Paint crystalPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFFFFFF),
          Color(0xFF00E5FF),
          Color(0xFFFFD54F),
        ],
      ).createShader(Rect.fromLTWH(cx - r * 0.2, cy - r * 0.62, r * 0.4, r * 1.1));

    canvas.drawPath(crystal, crystalPaint);
    canvas.drawPath(crystal, wingOutline);

    // Core Star Glow
    canvas.drawCircle(
      Offset(cx, cy - r * 0.08),
      r * 0.08 * pulse,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }

  void _drawCrimsonAbyssalCrest(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double r,
    double pulse,
  ) {
    // Dread Horns
    final Paint hornPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          palette.accent,
          palette.primary,
          const Color(0xFF1A000A),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint hornBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFFF8A80);

    // Left Horn
    final Path leftHorn = Path();
    leftHorn.moveTo(cx - r * 0.1, cy - r * 0.08);
    leftHorn.cubicTo(cx - r * 0.3, cy - r * 0.35, cx - r * 0.65, cy - r * 0.65, cx - r * 0.8, cy - r * 0.72);
    leftHorn.cubicTo(cx - r * 0.58, cy - r * 0.48, cx - r * 0.35, cy - r * 0.18, cx - r * 0.08, cy + r * 0.04);
    leftHorn.close();

    canvas.drawPath(leftHorn, hornPaint);
    canvas.drawPath(leftHorn, hornBorder);

    // Right Horn
    final Path rightHorn = Path();
    rightHorn.moveTo(cx + r * 0.1, cy - r * 0.08);
    rightHorn.cubicTo(cx + r * 0.3, cy - r * 0.35, cx + r * 0.65, cy - r * 0.65, cx + r * 0.8, cy - r * 0.72);
    rightHorn.cubicTo(cx + r * 0.58, cy - r * 0.48, cx + r * 0.35, cy - r * 0.18, cx + r * 0.08, cy + r * 0.04);
    rightHorn.close();

    canvas.drawPath(rightHorn, hornPaint);
    canvas.drawPath(rightHorn, hornBorder);

    // Bottom Shadow Talons
    final Path talons = Path();
    talons.moveTo(cx, cy + r * 0.52);
    talons.lineTo(cx - r * 0.35, cy + r * 0.22);
    talons.lineTo(cx, cy + r * 0.15);
    talons.lineTo(cx + r * 0.35, cy + r * 0.22);
    talons.close();

    canvas.drawPath(
      talons,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          colors: <Color>[palette.secondary, const Color(0xFF0F0006)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
    );
    canvas.drawPath(talons, hornBorder);

    // Center Abyssal Dragon Core & Slit Iris
    final Path diamond = Path();
    diamond.moveTo(cx, cy - r * 0.25);
    diamond.lineTo(cx + r * 0.18, cy);
    diamond.lineTo(cx, cy + r * 0.28);
    diamond.lineTo(cx - r * 0.18, cy);
    diamond.close();

    canvas.drawPath(diamond, Paint()..color = const Color(0xFF880E4F));
    canvas.drawPath(diamond, hornBorder);

    // Slit Eye pupil
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 0.06 * pulse, height: r * 0.2),
      Paint()..color = const Color(0xFFFFEA00),
    );
  }

  void _drawEmeraldArtisanCrest(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double r,
    double pulse,
  ) {
    // Hexagonal Runic Gear Outline
    final Path hex = Path();
    const int sides = 6;
    for (int i = 0; i < sides; i++) {
      final double angle = i * 2 * math.pi / sides;
      final double x = cx + math.cos(angle) * (r * 0.65);
      final double y = cy + math.sin(angle) * (r * 0.65);
      if (i == 0) {
        hex.moveTo(x, y);
      } else {
        hex.lineTo(x, y);
      }
    }
    hex.close();

    final Paint hexPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          palette.primary,
          palette.secondary,
          const Color(0xFF011C11),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.65));

    canvas.drawPath(hex, hexPaint);

    final Paint hexBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFA7F3D0);
    canvas.drawPath(hex, hexBorder);

    // Sacred Lotus / Aetheric Leaf Petals
    final Path lotus = Path();
    lotus.moveTo(cx, cy - r * 0.55);
    lotus.cubicTo(cx + r * 0.35, cy - r * 0.3, cx + r * 0.35, cy + r * 0.15, cx, cy + r * 0.42);
    lotus.cubicTo(cx - r * 0.35, cy + r * 0.15, cx - r * 0.35, cy - r * 0.3, cx, cy - r * 0.55);
    lotus.close();

    final Paint lotusPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFE8F5E9),
          Color(0xFF00E676),
          Color(0xFFFFD700),
        ],
      ).createShader(Rect.fromLTWH(cx - r * 0.4, cy - r * 0.6, r * 0.8, r * 1.1));

    canvas.drawPath(lotus, lotusPaint);
    canvas.drawPath(lotus, hexBorder);

    // Central Alchemy Gold Gem
    final Path gem = Path();
    gem.moveTo(cx, cy - r * 0.16);
    gem.lineTo(cx + r * 0.12, cy + r * 0.08);
    gem.lineTo(cx - r * 0.12, cy + r * 0.08);
    gem.close();

    canvas.drawPath(gem, Paint()..color = const Color(0xFFFFD700));
    canvas.drawCircle(Offset(cx, cy), r * 0.05 * pulse, Paint()..color = const Color(0xFFFFFFFF));
  }

  void _drawShimmerSweep(Canvas canvas, Size size, double cx, double cy, double r) {
    // 2027 Aion 2 Specular Highlight Band passing diagonally
    final double shimmerOffset = (animationValue * 2.4 - 0.7);
    final Paint shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.transparent,
          Colors.white.withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: <double>[
          (shimmerOffset - 0.2).clamp(0.0, 1.0),
          shimmerOffset.clamp(0.0, 1.0),
          (shimmerOffset + 0.2).clamp(0.0, 1.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    canvas.drawCircle(Offset(cx, cy), r * 0.85, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant FactionEmblemPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.category != category ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.showGlow != showGlow;
  }
}
