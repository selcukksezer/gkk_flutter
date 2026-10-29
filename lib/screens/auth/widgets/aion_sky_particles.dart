import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Cinematic Aion-2 Atmospheric Sky & Celestial Particle Background.
/// Engineered for mobile 60 FPS performance on TBDR GPUs (Metal/Vulkan).
class AionSkyParticlesBackground extends StatefulWidget {
  const AionSkyParticlesBackground({
    super.key,
    required this.child,
    this.showRays = true,
    this.primaryAura = const Color(0xFF1E3A8A), // Astral Deep Blue
    this.secondaryAura = const Color(0xFF6B21A8), // Celestial Purple
    this.accentEmissive = const Color(0xFFD4AF37), // Aion Gold
  });

  final Widget child;
  final bool showRays;
  final Color primaryAura;
  final Color secondaryAura;
  final Color accentEmissive;

  @override
  State<AionSkyParticlesBackground> createState() =>
      _AionSkyParticlesBackgroundState();
}

class _AionSkyParticlesBackgroundState
    extends State<AionSkyParticlesBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<_AionParticle> _particles;
  final math.Random _random = math.Random(2027);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // Generate 48 pre-seeded floating celestial particles
    _particles = List<_AionParticle>.generate(48, (int index) {
      return _AionParticle(
        relativeX: _random.nextDouble(),
        relativeY: _random.nextDouble(),
        radius: 1.0 + _random.nextDouble() * 2.8,
        speed: 0.04 + _random.nextDouble() * 0.09,
        swayAmplitude: 0.015 + _random.nextDouble() * 0.035,
        swayFrequency: 1.0 + _random.nextDouble() * 2.5,
        phase: _random.nextDouble() * math.pi * 2,
        opacity: 0.25 + _random.nextDouble() * 0.65,
        isGold: index % 3 == 0,
        isCyan: index % 3 == 1,
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Deep cosmic sky base gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF04060E), // Void Night
                  Color(0xFF090D1C), // Deep Astral Navy
                  Color(0xFF0F172A), // Celestial Obsidian
                  Color(0xFF030712), // Abyssal Floor
                ],
                stops: <double>[0.0, 0.35, 0.72, 1.0],
              ),
            ),
          ),

          // Animated atmospheric sky layer (Auroral waves, God-rays, Ambient Nebulae)
          AnimatedBuilder(
            animation: _animController,
            builder: (BuildContext context, Widget? _) {
              return CustomPaint(
                painter: _AionAtmosphericSkyPainter(
                  progress: _animController.value,
                  primaryAura: widget.primaryAura,
                  secondaryAura: widget.secondaryAura,
                  accentEmissive: widget.accentEmissive,
                  showRays: widget.showRays,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),

          // Animated drifting mana particles & starlight embers
          AnimatedBuilder(
            animation: _animController,
            builder: (BuildContext context, Widget? _) {
              return CustomPaint(
                painter: _AionParticlePainter(
                  progress: _animController.value,
                  particles: _particles,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),

          // Content overlay
          widget.child,
        ],
      ),
    );
  }
}

class _AionParticle {
  _AionParticle({
    required this.relativeX,
    required this.relativeY,
    required this.radius,
    required this.speed,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.phase,
    required this.opacity,
    required this.isGold,
    required this.isCyan,
  });

  final double relativeX;
  final double relativeY;
  final double radius;
  final double speed;
  final double swayAmplitude;
  final double swayFrequency;
  final double phase;
  final double opacity;
  final bool isGold;
  final bool isCyan;
}

class _AionAtmosphericSkyPainter extends CustomPainter {
  _AionAtmosphericSkyPainter({
    required this.progress,
    required this.primaryAura,
    required this.secondaryAura,
    required this.accentEmissive,
    required this.showRays,
  });

  final double progress;
  final Color primaryAura;
  final Color secondaryAura;
  final Color accentEmissive;
  final bool showRays;

  @override
  void paint(Canvas canvas, Size size) {
    final double time = progress * math.pi * 2;

    // 1. Upper Celestial Sun/Nebula well
    final double sunX = size.width * (0.5 + 0.08 * math.sin(time * 0.7));
    final double sunY = size.height * (0.16 + 0.04 * math.cos(time * 0.5));
    final double sunRadius = size.width * 0.75;

    final Paint sunPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accentEmissive.withValues(alpha: 0.18 + 0.06 * math.sin(time)),
          primaryAura.withValues(alpha: 0.14),
          secondaryAura.withValues(alpha: 0.07),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(sunX, sunY), radius: sunRadius));

    canvas.drawCircle(Offset(sunX, sunY), sunRadius, sunPaint);

    // 2. Volumetric God-Rays radiating downward
    if (showRays) {
      final Paint rayPaint = Paint()
        ..blendMode = BlendMode.screen
        ..style = PaintingStyle.fill;

      const int rayCount = 7;
      for (int i = 0; i < rayCount; i++) {
        final double rayAngle = (i - rayCount / 2) * 0.18 + 0.03 * math.sin(time + i);
        final double alpha = (0.05 + 0.035 * math.cos(time * 1.5 + i)).clamp(0.01, 0.12);

        final Path rayPath = Path();
        rayPath.moveTo(sunX, sunY);
        final double spread = size.width * 0.12;
        final double bottomTargetX = size.width * 0.5 + math.tan(rayAngle) * size.height;
        rayPath.lineTo(bottomTargetX - spread, size.height);
        rayPath.lineTo(bottomTargetX + spread, size.height);
        rayPath.close();

        rayPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            accentEmissive.withValues(alpha: alpha * 1.5),
            primaryAura.withValues(alpha: alpha * 0.6),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, sunY, size.width, size.height - sunY));

        canvas.drawPath(rayPath, rayPaint);
      }
    }

    // 3. Lower Ethereal Horizon mist & celestial glow
    final double mistY = size.height * 0.88;
    final Rect mistRect = Rect.fromLTWH(0, mistY - 120, size.width, size.height - mistY + 120);
    final Paint mistPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          secondaryAura.withValues(alpha: 0.12 + 0.04 * math.sin(time * 0.9)),
          const Color(0xFF030712),
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(mistRect);

    canvas.drawRect(mistRect, mistPaint);
  }

  @override
  bool shouldRepaint(covariant _AionAtmosphericSkyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryAura != primaryAura ||
        oldDelegate.secondaryAura != secondaryAura ||
        oldDelegate.accentEmissive != accentEmissive;
  }
}

class _AionParticlePainter extends CustomPainter {
  _AionParticlePainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_AionParticle> particles;

  final Paint _goldPaint = Paint()..color = const Color(0xFFFFDF7A);
  final Paint _cyanPaint = Paint()..color = const Color(0xFF67E8F9);
  final Paint _whitePaint = Paint()..color = const Color(0xFFF8FAFC);
  final Paint _glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

  @override
  void paint(Canvas canvas, Size size) {
    final double time = progress * math.pi * 2;

    for (final _AionParticle p in particles) {
      // Ascending motion with vertical wrap
      final double currentY = (p.relativeY - progress * p.speed * 8.0) % 1.0;
      final double posY = (currentY < 0 ? currentY + 1.0 : currentY) * size.height;

      // Sinusoidal lateral drift
      final double sway = math.sin(time * p.swayFrequency + p.phase) * p.swayAmplitude;
      final double posX = (p.relativeX + sway) * size.width;

      // Fade in at bottom, fade out at top
      final double edgeFade = (posY / size.height).clamp(0.0, 1.0);
      final double breathing = 0.7 + 0.3 * math.sin(time * 2.0 + p.phase);
      final double currentAlpha = (p.opacity * breathing * (1.0 - math.pow(1.0 - edgeFade, 2.0))).clamp(0.0, 1.0);

      final Color baseColor = p.isGold
          ? const Color(0xFFFFD700)
          : (p.isCyan ? const Color(0xFF38BDF8) : const Color(0xFFFFFFFF));

      final Paint paint = p.isGold
          ? _goldPaint
          : (p.isCyan ? _cyanPaint : _whitePaint);
      paint.color = baseColor.withValues(alpha: currentAlpha);

      // Draw subtle glowing halo around larger particles
      if (p.radius > 2.0 && currentAlpha > 0.3) {
        _glowPaint.color = baseColor.withValues(alpha: currentAlpha * 0.4);
        canvas.drawCircle(Offset(posX, posY), p.radius * 2.2, _glowPaint);
      }

      // Draw particle core
      canvas.drawCircle(Offset(posX, posY), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AionParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
