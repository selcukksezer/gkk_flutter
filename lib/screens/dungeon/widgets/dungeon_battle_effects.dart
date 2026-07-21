import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design-system palette for the battle screen (tasarim skill).
abstract final class BattlePalette {
  static const Color carbonVoid = Color(0xFF080B12);
  static const Color spaceNavy = Color(0xFF121826);
  static const Color darkObsidian = Color(0xFF2A3042);
  static const Color liquidGold = Color(0xFFFFB800);
  static const Color cyberFuchsia = Color(0xFFE01E5A);
  static const Color mutedTitanium = Color(0xFF8E9CAE);
  static const Color mysticRuby = Color(0xFFE52E2E);
  static const Color toxicNeon = Color(0xFF00FF66);
  static const Color warningSolar = Color(0xFFFFD700);
  static const Color coralFlare = Color(0xFFFF6B35);
}

// =============================================================================
// Dot pattern — subtle mesh texture over the whole screen.
// =============================================================================
class DotPatternPainter extends CustomPainter {
  const DotPatternPainter({
    this.color = BattlePalette.mutedTitanium,
    this.opacity = 0.07,
    this.spacing = 22,
    this.radius = 1.0,
  });

  final Color color;
  final double opacity;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color.withValues(alpha: opacity);
    for (double y = spacing / 2; y < size.height; y += spacing) {
      // Offset every other row for a mesh feel instead of a grid.
      final bool odd = ((y / spacing).floor()) % 2 == 1;
      for (double x = odd ? spacing : spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity ||
      oldDelegate.spacing != spacing;
}

// =============================================================================
// Ember field — rising particles, deterministic per index (no per-frame rand).
// =============================================================================
class EmberFieldPainter extends CustomPainter {
  const EmberFieldPainter({
    required this.progress,
    required this.color,
    this.count = 26,
    this.maxOpacity = 0.55,
  });

  /// Looping 0..1 value from an ambient controller.
  final double progress;
  final Color color;
  final int count;
  final double maxOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < count; i++) {
      final double seed = (i * 127.31) % 1000 / 1000;
      final double speed = 0.35 + ((i * 53) % 100) / 100 * 0.65;
      final double phase = (progress * speed + seed) % 1.0;
      final double x = size.width * ((seed * 7.7) % 1.0) +
          math.sin((phase * 4 + i) * math.pi) * 14;
      final double y = size.height * (1.05 - phase * 1.1);
      final double r = 0.8 + ((i * 37) % 100) / 100 * 2.2;
      // Fade in at bottom, fade out near top.
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Paint paint = Paint()
        ..color = color.withValues(alpha: maxOpacity * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(EmberFieldPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// =============================================================================
// Countdown ring — rotating gradient arc with glow.
// =============================================================================
class CountdownRingPainter extends CustomPainter {
  const CountdownRingPainter({
    required this.rotation,
    required this.color,
    this.secondary = BattlePalette.liquidGold,
    this.strokeWidth = 5,
  });

  final double rotation;
  final Color color;
  final Color secondary;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.5
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(center, radius, track);

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: <Color>[
          color.withValues(alpha: 0),
          color,
          secondary,
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0.0, 0.35, 0.65, 1.0],
        transform: GradientRotation(rotation),
      ).createShader(rect);
    canvas.drawArc(rect, rotation, math.pi * 1.35, false, arc);

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = color.withValues(alpha: 0.22);
    canvas.drawArc(rect, rotation + 0.4, math.pi * 0.8, false, glow);
  }

  @override
  bool shouldRepaint(CountdownRingPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.color != color;
}

// =============================================================================
// Shockwave — expanding rings bursting outward from center (VS slam).
// =============================================================================
class ShockwavePainter extends CustomPainter {
  const ShockwavePainter({
    required this.progress,
    required this.color,
    this.ringCount = 3,
  });

  /// 0..1 — rings expand and fade as it grows.
  final double progress;
  final Color color;
  final int ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = math.min(size.width, size.height) / 2;

    for (int i = 0; i < ringCount; i++) {
      final double delay = i * 0.18;
      final double t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final double radius = maxRadius * Curves.easeOutCubic.transform(t);
      final double fade = (1 - t) * 0.6;
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 - i * 0.7
        ..color = color.withValues(alpha: fade);
      canvas.drawCircle(center, radius, ring);

      final Paint glowRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = color.withValues(alpha: fade * 0.5);
      canvas.drawCircle(center, radius, glowRing);
    }
  }

  @override
  bool shouldRepaint(ShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// =============================================================================
// Speed lines — radial anime-style dash burst (countdown tension).
// =============================================================================
class SpeedLinesPainter extends CustomPainter {
  const SpeedLinesPainter({
    required this.progress,
    required this.color,
    this.count = 22,
    this.opacity = 0.20,
  });

  /// Looping 0..1 value; lines slowly rotate and flicker.
  final double progress;
  final Color color;
  final int count;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double diagonal =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final double rotation = progress * 2 * math.pi * 0.15;

    for (int i = 0; i < count; i++) {
      final double angle = (i / count) * 2 * math.pi + rotation;
      final double flicker =
          0.4 + 0.6 * math.sin(i * 2.3 + progress * 2 * math.pi * 3).abs();
      final double inner = diagonal * (0.52 + 0.06 * math.sin(i * 1.3));
      final double outer = diagonal * 1.05;
      final Paint paint = Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: <Color>[
            color.withValues(alpha: 0),
            color.withValues(alpha: opacity * flicker),
          ],
        ).createShader(
          Rect.fromPoints(
            center + Offset(math.cos(angle), math.sin(angle)) * inner,
            center + Offset(math.cos(angle), math.sin(angle)) * outer,
          ),
        );
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SpeedLinesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// =============================================================================
// Radiant rays — rotating light wedges behind result emblems.
// =============================================================================
class RadiantRaysPainter extends CustomPainter {
  const RadiantRaysPainter({
    required this.progress,
    required this.color,
    this.rayCount = 16,
    this.maxOpacity = 0.16,
  });

  /// Looping 0..1 value; rays slowly rotate and breathe.
  final double progress;
  final Color color;
  final int rayCount;
  final double maxOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final double rotation = progress * 2 * math.pi * 0.12;

    for (int i = 0; i < rayCount; i++) {
      final double angle = (i / rayCount) * 2 * math.pi + rotation;
      final double breathe =
          0.5 + 0.5 * math.sin(i * 1.9 + progress * 2 * math.pi);
      const double halfAngle = 0.07;
      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: maxOpacity * breathe),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      final Path path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(angle - halfAngle) * radius,
          center.dy + math.sin(angle - halfAngle) * radius,
        )
        ..lineTo(
          center.dx + math.cos(angle + halfAngle) * radius,
          center.dy + math.sin(angle + halfAngle) * radius,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(RadiantRaysPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// =============================================================================
// Confetti field — falling, spinning colored shards (victory celebration).
// =============================================================================
class ConfettiFieldPainter extends CustomPainter {
  const ConfettiFieldPainter({
    required this.progress,
    this.count = 30,
  });

  /// Looping 0..1 value.
  final double progress;
  final int count;

  static const List<Color> _colors = <Color>[
    BattlePalette.liquidGold,
    BattlePalette.cyberFuchsia,
    BattlePalette.toxicNeon,
    BattlePalette.coralFlare,
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < count; i++) {
      final double seed = (i * 269.13) % 1000 / 1000;
      final double speed = 0.4 + ((i * 71) % 100) / 100 * 0.6;
      final double phase = (progress * speed + seed) % 1.0;
      final double x = size.width * ((seed * 13.7) % 1.0) +
          math.sin((phase * 3 + i) * math.pi * 2) * 22;
      final double y = size.height * (phase * 1.15 - 0.08);
      final double rot = (phase * 6 + i) * math.pi;
      final double fade =
          phase < 0.1 ? phase / 0.1 : (1 - ((phase - 0.75) / 0.25)).clamp(0.0, 1.0);
      final Color color = _colors[i % _colors.length];

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      final Paint paint = Paint()
        ..color = color.withValues(alpha: 0.85 * fade);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero,
              width: 3.2,
              height: 8 + ((i * 29) % 100) / 100 * 4),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiFieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =============================================================================
// FadeSlideIn — list-entry animation (fade + rise), optional delay.
// =============================================================================
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.durationMs = 420,
    this.offsetY = 18,
  });

  final Widget child;
  final int delayMs;
  final int durationMs;
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.delayMs <= 0) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _anim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _anim.value) * widget.offsetY),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// =============================================================================
// PressableScale — micro-interaction: shrink on press, spring back.
// =============================================================================
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.95,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// BattleCtaButton — gold gradient CTA with pulsing neon glow.
// =============================================================================
class BattleCtaButton extends StatefulWidget {
  const BattleCtaButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.colors = const <Color>[Color(0xFFFFD700), Color(0xFFFFB800)],
    this.glowColor = BattlePalette.liquidGold,
    this.foreground = const Color(0xFF080B12),
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final List<Color> colors;
  final Color glowColor;
  final Color foreground;

  @override
  State<BattleCtaButton> createState() => _BattleCtaButtonState();
}

class _BattleCtaButtonState extends State<BattleCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return PressableScale(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? child) {
          final double glow = enabled ? 0.25 + _pulse.value * 0.35 : 0.0;
          return Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: enabled
                    ? widget.colors
                    : <Color>[
                        BattlePalette.darkObsidian,
                        BattlePalette.darkObsidian,
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: enabled ? 0.25 : 0.08),
              ),
              boxShadow: enabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: glow),
                        blurRadius: 22,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              widget.icon,
              size: 22,
              color: enabled
                  ? widget.foreground
                  : BattlePalette.mutedTitanium,
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                color: enabled
                    ? widget.foreground
                    : BattlePalette.mutedTitanium,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// GlassPanel — Space Navy translucent surface with luminous border.
// =============================================================================
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.accent = BattlePalette.cyberFuchsia,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.borderOpacity = 0.35,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            BattlePalette.spaceNavy.withValues(alpha: 0.92),
            BattlePalette.carbonVoid.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: borderOpacity)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// BattleChip — small stat chip (icon + label + value).
// =============================================================================
class BattleChip extends StatelessWidget {
  const BattleChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: BattlePalette.mutedTitanium,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EnergySweepBar — indeterminate battle progress, gold→fuchsia sweep.
// =============================================================================
class EnergySweepBar extends StatelessWidget {
  const EnergySweepBar({
    super.key,
    required this.progress,
    this.height = 6,
  });

  /// Looping 0..1 value.
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SweepBarPainter(progress: progress)),
      ),
    );
  }
}

class _SweepBarPainter extends CustomPainter {
  const _SweepBarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint track = Paint()..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawRect(Offset.zero & size, track);

    final double bandWidth = size.width * 0.38;
    final double x = -bandWidth + (size.width + bandWidth * 2) * progress;
    final Rect band = Rect.fromLTWH(x, 0, bandWidth, size.height);
    final Paint paint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0x00FFB800),
          BattlePalette.liquidGold,
          BattlePalette.cyberFuchsia,
          Color(0x00E01E5A),
        ],
        stops: <double>[0.0, 0.35, 0.65, 1.0],
      ).createShader(band);
    canvas.drawRect(band, paint);
  }

  @override
  bool shouldRepaint(_SweepBarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
