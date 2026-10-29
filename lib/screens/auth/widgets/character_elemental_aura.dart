import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Class elemental affinity configuration for Aion-2 Mobile visual effects.
class ElementalAffinity {
  const ElementalAffinity({
    required this.name,
    required this.elementTitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.ambientColor,
    required this.insigniaIcon,
    required this.auraStyle,
  });

  final String name;
  final String elementTitle;
  final Color primaryColor;
  final Color secondaryColor;
  final Color ambientColor;
  final IconData insigniaIcon;
  final String auraStyle;

  static const ElementalAffinity ignis = ElementalAffinity(
    name: 'İgnis',
    elementTitle: 'Güneş & Alev Muhafızı',
    primaryColor: Color(0xFFFFB300),
    secondaryColor: Color(0xFFFF4500),
    ambientColor: Color(0x33FF6D00),
    insigniaIcon: Icons.shield_rounded,
    auraStyle: 'Solar Flare Bastion',
  );

  static const ElementalAffinity aether = ElementalAffinity(
    name: 'Eter',
    elementTitle: 'Gök & Simya Özü',
    primaryColor: Color(0xFF00E5FF),
    secondaryColor: Color(0xFF63D1C5),
    ambientColor: Color(0x3300E5FF),
    insigniaIcon: Icons.auto_fix_high_rounded,
    auraStyle: 'Arcane Transmutation',
  );

  static const ElementalAffinity abyss = ElementalAffinity(
    name: 'Hiçlik',
    elementTitle: 'Karanlık & Gölge Suikastı',
    primaryColor: Color(0xFFBF55EC),
    secondaryColor: Color(0xFF8E93FF),
    ambientColor: Color(0x339B51E0),
    insigniaIcon: Icons.gps_fixed_rounded,
    auraStyle: 'Abyssal Eclipse',
  );

  static ElementalAffinity forClass(String classId) {
    switch (classId.toLowerCase()) {
      case 'warrior':
        return ignis;
      case 'alchemist':
        return aether;
      case 'shadow':
        return abyss;
      default:
        return ignis;
    }
  }
}

/// Multi-layered animated elemental aura:
/// 1. Rotating runic concentric rings with tick marks.
/// 2. Radiating energy corona.
/// 3. Elemental summoning dais (pedestal) ellipse at base.
/// 4. Floating glowing energy sparks/embers.
class CharacterElementalAura extends StatefulWidget {
  const CharacterElementalAura({
    super.key,
    required this.affinity,
    this.disableAnimations = false,
    this.child,
  });

  final ElementalAffinity affinity;
  final bool disableAnimations;
  final Widget? child;

  @override
  State<CharacterElementalAura> createState() => _CharacterElementalAuraState();
}

class _CharacterElementalAuraState extends State<CharacterElementalAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    if (!widget.disableAnimations) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CharacterElementalAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disableAnimations != oldWidget.disableAnimations) {
      if (widget.disableAnimations) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.disableAnimations) {
      return CustomPaint(
        painter: _ElementalAuraPainter(
          affinity: widget.affinity,
          rotation: 0.0,
          pulse: 0.5,
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final double pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        return CustomPaint(
          painter: _ElementalAuraPainter(
            affinity: widget.affinity,
            rotation: t * 2 * math.pi,
            pulse: pulse,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _ElementalAuraPainter extends CustomPainter {
  _ElementalAuraPainter({
    required this.affinity,
    required this.rotation,
    required this.pulse,
  });

  final ElementalAffinity affinity;
  final double rotation;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.46);
    final double baseRadius = math.min(size.width, size.height) * 0.42;

    // ── 1. Soft Radial Corona Aura ───────────────────────────────────────────
    final Paint coronaPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          affinity.primaryColor.withValues(alpha: 0.22 + 0.12 * pulse),
          affinity.secondaryColor.withValues(alpha: 0.10 + 0.08 * pulse),
          affinity.ambientColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.35));

    canvas.drawCircle(center, baseRadius * 1.35, coronaPaint);

    // ── 2. Inner Rotating Runic Ring ─────────────────────────────────────────
    final Paint innerRingPaint = Paint()
      ..color = affinity.primaryColor.withValues(alpha: 0.35 + 0.25 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawCircle(center, baseRadius * 0.85, innerRingPaint);

    // Inner ring tick marks
    final int tickCount = 12;
    for (int i = 0; i < tickCount; i++) {
      final double angle = rotation + (i * 2 * math.pi / tickCount);
      final double r1 = baseRadius * 0.82;
      final double r2 = baseRadius * 0.88;
      final Offset p1 = center + Offset(math.cos(angle) * r1, math.sin(angle) * r1);
      final Offset p2 = center + Offset(math.cos(angle) * r2, math.sin(angle) * r2);
      canvas.drawLine(p1, p2, innerRingPaint);
    }

    // ── 3. Outer Counter-Rotating Segmented Orbit Ring ──────────────────────
    final Paint outerRingPaint = Paint()
      ..color = affinity.secondaryColor.withValues(alpha: 0.28 + 0.20 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    const int segments = 4;
    const double arcLength = math.pi * 0.35;
    for (int i = 0; i < segments; i++) {
      final double startAngle = -rotation * 0.7 + (i * 2 * math.pi / segments);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius * 1.08),
        startAngle,
        arcLength,
        false,
        outerRingPaint,
      );
    }

    // ── 4. Runic Cardinal Diamonds ──────────────────────────────────────────
    final Paint diamondPaint = Paint()
      ..color = affinity.primaryColor.withValues(alpha: 0.70 + 0.30 * pulse)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double angle = -rotation * 0.7 + (i * math.pi / 2);
      final Offset diamondCenter =
          center + Offset(math.cos(angle) * baseRadius * 1.08, math.sin(angle) * baseRadius * 1.08);
      _drawDiamond(canvas, diamondCenter, 4.5, diamondPaint);
    }

    // ── 5. Summoning Dais Pedestal (3D Perspective Ellipse) ─────────────────
    final Rect daisRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.84),
      width: size.width * 0.75,
      height: size.height * 0.16,
    );

    // Glowing dais platform fill
    final Paint daisFill = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          affinity.primaryColor.withValues(alpha: 0.24 + 0.14 * pulse),
          affinity.secondaryColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.65, 1.0],
      ).createShader(daisRect);

    canvas.drawOval(daisRect, daisFill);

    // Dais perimeter ring
    final Paint daisBorder = Paint()
      ..color = affinity.primaryColor.withValues(alpha: 0.50 + 0.35 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawOval(daisRect, daisBorder);

    // Inner concentric dais ring
    final Rect innerDaisRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.84),
      width: size.width * 0.55,
      height: size.height * 0.11,
    );
    final Paint innerDaisBorder = Paint()
      ..color = affinity.secondaryColor.withValues(alpha: 0.30 + 0.20 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(innerDaisRect, innerDaisBorder);

    // ── 6. Floating Energy Embers / Motes ────────────────────────────────────
    final Paint emberPaint = Paint()..style = PaintingStyle.fill;
    const int emberCount = 9;
    for (int i = 0; i < emberCount; i++) {
      final double phase = (rotation + i * (2 * math.pi / emberCount)) % (2 * math.pi);
      final double normPhase = phase / (2 * math.pi); // 0.0 -> 1.0
      // Embers float upwards from dais toward center
      final double startY = size.height * 0.84;
      final double endY = size.height * 0.38;
      final double y = startY - (startY - endY) * normPhase;
      final double xOffset = math.sin(normPhase * 4 * math.pi + i) * (size.width * 0.22);
      final double x = (size.width / 2) + xOffset;
      final double emberAlpha = math.sin(normPhase * math.pi) * (0.55 + 0.35 * pulse);

      emberPaint.color = i.isEven
          ? affinity.primaryColor.withValues(alpha: emberAlpha.clamp(0.0, 1.0))
          : affinity.secondaryColor.withValues(alpha: emberAlpha.clamp(0.0, 1.0));

      final double emberRadius = 1.4 + 1.8 * math.sin(normPhase * math.pi);
      canvas.drawCircle(Offset(x, y), emberRadius, emberPaint);
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final Path path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ElementalAuraPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.affinity != affinity;
  }
}

/// Glowing insignia badge for the class
class ClassInsigniaBadge extends StatelessWidget {
  const ClassInsigniaBadge({
    super.key,
    required this.affinity,
    required this.icon,
    required this.size,
  });

  final ElementalAffinity affinity;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            affinity.primaryColor.withValues(alpha: 0.35),
            affinity.secondaryColor.withValues(alpha: 0.15),
            const Color(0xCC0E1015),
          ],
        ),
        border: Border.all(
          color: affinity.primaryColor.withValues(alpha: 0.65),
          width: 1.6,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: affinity.primaryColor.withValues(alpha: 0.45),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: size * 0.52,
          color: affinity.primaryColor,
        ),
      ),
    );
  }
}
