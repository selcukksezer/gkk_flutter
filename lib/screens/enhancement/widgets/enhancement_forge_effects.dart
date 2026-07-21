import 'dart:math' as math;

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

// ============================================================================
// GÜÇLENDİRME OCAĞI EFEKTLERİ
// Şans halkası, yörünge parçacıkları, kıvılcım patlaması, CTA shimmer.
// Hepsi forge alanına özel — ekran arka planı (dot pattern) sabittir.
// ============================================================================

/// Item çevresinde başarı şansını gösteren neon arc halkası.
/// [progress] 0..1 — şans yüzdesi; [rotation] 0..1 — hafif dönüş.
class ChanceRingPainter extends CustomPainter {
  const ChanceRingPainter({
    required this.progress,
    required this.rotation,
    required this.color,
    this.trackOpacity = 0.10,
  });

  final double progress;
  final double rotation;
  final Color color;
  final double trackOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 6;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    // Zemin halkası
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: trackOpacity);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    // Şans arc'ı — gradient + glow
    final double sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    final double start = -math.pi / 2 + rotation * math.pi * 2;

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..color = color.withValues(alpha: 0.45);
    canvas.drawArc(rect, start, sweep, false, glow);

    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(start),
        colors: <Color>[
          color.withValues(alpha: 0.25),
          color,
          Colors.white.withValues(alpha: 0.9),
        ],
        stops: const <double>[0.0, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arc);

    // Uç noktada parlak nokta
    if (progress > 0.02) {
      final double endAngle = start + sweep;
      final Offset tip = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );
      canvas.drawCircle(
        tip,
        4.5,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(tip, 2.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant ChanceRingPainter old) =>
      old.progress != progress || old.rotation != rotation || old.color != color;
}

/// Item etrafında dönen küçük ember/enerji parçacıkları.
class OrbitParticlesPainter extends CustomPainter {
  OrbitParticlesPainter({
    required this.t,
    required this.color,
    this.intensity = 1.0,
  });

  final double t; // 0..1 loop
  final Color color;
  final double intensity;

  static final List<_OrbitSpec> _specs = List<_OrbitSpec>.generate(14, (int i) {
    final math.Random rnd = math.Random(i * 97 + 13);
    return _OrbitSpec(
      radiusFactor: 0.62 + rnd.nextDouble() * 0.46,
      speed: (rnd.nextBool() ? 1 : -1) * (0.4 + rnd.nextDouble() * 0.9),
      phase: rnd.nextDouble() * math.pi * 2,
      size: 1.2 + rnd.nextDouble() * 2.0,
      wobble: rnd.nextDouble() * 6,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double base = math.min(size.width, size.height) / 2;

    for (final _OrbitSpec s in _specs) {
      final double angle = s.phase + t * math.pi * 2 * s.speed;
      final double r =
          base * s.radiusFactor + math.sin(t * math.pi * 4 + s.phase) * s.wobble;
      final Offset pos = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle) * 0.86,
      );
      final double alpha =
          (0.25 + 0.5 * (0.5 + 0.5 * math.sin(angle * 2))) * intensity;
      canvas.drawCircle(
        pos,
        s.size * intensity.clamp(0.6, 1.6),
        Paint()
          ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant OrbitParticlesPainter old) =>
      old.t != t || old.color != color || old.intensity != intensity;
}

class _OrbitSpec {
  const _OrbitSpec({
    required this.radiusFactor,
    required this.speed,
    required this.phase,
    required this.size,
    required this.wobble,
  });

  final double radiusFactor;
  final double speed;
  final double phase;
  final double size;
  final double wobble;
}

/// Sonuç anında merkezden dışa saçılan kıvılcım patlaması.
class SparkBurstPainter extends CustomPainter {
  SparkBurstPainter({required this.t, required this.color, this.seed = 7});

  final double t; // 0..1
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final math.Random rnd = math.Random(seed);
    final double maxR = math.min(size.width, size.height) * 0.62;

    for (int i = 0; i < 26; i++) {
      final double angle = rnd.nextDouble() * math.pi * 2;
      final double speed = 0.45 + rnd.nextDouble() * 0.55;
      final double dist = Curves.easeOutCubic.transform(t) * maxR * speed;
      final Offset pos = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );
      final double fade = (1 - t) * (0.5 + rnd.nextDouble() * 0.5);
      final double len = 3 + rnd.nextDouble() * 8 * (1 - t);

      // Kıvılcım çizgisi — hareket yönünde
      final Paint p = Paint()
        ..color = (rnd.nextDouble() > 0.35 ? color : Colors.white)
            .withValues(alpha: fade.clamp(0.0, 1.0))
        ..strokeWidth = 1.4 + rnd.nextDouble()
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        pos,
        Offset(pos.dx + len * math.cos(angle), pos.dy + len * math.sin(angle)),
        p,
      );
    }

    // Merkez şok halkası
    final double ringR = Curves.easeOutQuart.transform(t) * maxR;
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * (1 - t)
        ..color = color.withValues(alpha: (0.5 * (1 - t)).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant SparkBurstPainter old) =>
      old.t != t || old.color != color;
}

/// Butonun üstünden geçen ışık süpürmesi (shimmer sweep).
class ShimmerSweep extends StatelessWidget {
  const ShimmerSweep({
    super.key,
    required this.t,
    required this.borderRadius,
  });

  final double t; // 0..1 loop
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double w = c.maxWidth;
            // -0.6..1.6 arası kaydır — kenarlardan tamamen çıksın
            final double dx = (t * 2.2 - 0.6) * w;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: w * 0.28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Güçlendirme ocağı dış çerçevesinde saat yönünde dönen parlayan arc.
class RotatingForgeBorderPainter extends CustomPainter {
  const RotatingForgeBorderPainter({
    required this.rotation,
    required this.color,
    this.borderRadius = 14,
    this.padding = 1.5,
    this.arcFraction = 0.24,
  });

  final double rotation;
  final Color color;
  final double borderRadius;
  final double padding;
  final double arcFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        padding,
        padding,
        size.width - padding * 2,
        size.height - padding * 2,
      ),
      Radius.circular(borderRadius),
    );
    final Path path = Path()..addRRect(rrect);
    final PathMetric metric = path.computeMetrics().first;
    final double length = metric.length;
    if (length <= 0) return;

    final Paint dimTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.18);
    canvas.drawPath(path, dimTrack);

    final double arcLen = length * arcFraction;
    final double start = (rotation % 1.0) * length;
    final Path arcPath = metric.extractPath(start, start + arcLen);

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(arcPath, glow);

    final Paint core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawPath(arcPath, core);
  }

  @override
  bool shouldRepaint(covariant RotatingForgeBorderPainter old) =>
      old.rotation != rotation || old.color != color;
}

class ForgeRotatingBorderGlow extends StatelessWidget {
  const ForgeRotatingBorderGlow({
    super.key,
    required this.rotation,
    required this.color,
    required this.child,
    this.borderRadius = 14,
  });

  final double rotation;
  final Color color;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: RotatingForgeBorderPainter(
        rotation: rotation,
        color: color,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// Sonuç fazı — tam çerçeve sabit parlar (dönmez).
class StaticForgeBorderPainter extends CustomPainter {
  const StaticForgeBorderPainter({
    required this.color,
    this.borderRadius = 14,
    this.padding = 1.5,
  });

  final Color color;
  final double borderRadius;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        padding,
        padding,
        size.width - padding * 2,
        size.height - padding * 2,
      ),
      Radius.circular(borderRadius),
    );
    final Path path = Path()..addRRect(rrect);

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = color.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(path, glow);

    final Paint core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.95);
    canvas.drawPath(path, core);
  }

  @override
  bool shouldRepaint(covariant StaticForgeBorderPainter old) => old.color != color;
}

class ForgeStaticBorderGlow extends StatelessWidget {
  const ForgeStaticBorderGlow({
    super.key,
    required this.color,
    required this.child,
    this.borderRadius = 14,
  });

  final Color color;
  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: StaticForgeBorderPainter(
        color: color,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// Sonuç flaşı — tüm forge alanını renkle yıkayıp söner.
class ResultFlash extends StatelessWidget {
  const ResultFlash({super.key, required this.t, required this.color});

  final double t; // 0..1
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    final double alpha = (1 - Curves.easeOutQuad.transform(t)) * 0.5;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
