import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Semantic types of restorative particles emitted in the hospital sanctuary.
enum HospitalParticleKind {
  /// Soft glowing emerald orb with radiant halo and bright restorative nucleus.
  emeraldOrb,

  /// Luminous 4-pointed celestial gold sparkle / starburst with harmonic spin.
  goldSparkle,

  /// Gentle divine restorative cross (+) motif symbolizing sanctuary blessing.
  healingCross,

  /// Ethereal expanding micro-halo / restorative ripple ring.
  etherealRing,
}

/// A pre-allocated particle instance operating with zero garbage collection overhead.
///
/// Particles cycle continuously in memory by resetting state rather than creating
/// new heap allocations, guaranteeing a sustained 60 FPS on mobile TBDR architectures.
class HospitalParticle {
  HospitalParticle({
    required this.x,
    required this.y,
    required this.baseX,
    required this.vy,
    required this.swayFrequency,
    required this.swayAmplitude,
    required this.swayPhase,
    required this.radius,
    required this.kind,
    required this.color,
    required this.rotation,
    required this.rotationalSpeed,
    required this.pulseFrequency,
    required this.pulsePhase,
    required this.maxLifetime,
    required this.layerParallax,
    this.lifetime = 0.0,
    this.isBurst = false,
    this.burstVx = 0.0,
    this.burstVy = 0.0,
  });

  /// Factory creating an ambient rising particle randomized across screen boundaries.
  factory HospitalParticle.random(Size size, math.Random rng, {bool randomizeY = false}) {
    final HospitalParticle p = HospitalParticle(
      x: 0,
      y: 0,
      baseX: 0,
      vy: 0,
      swayFrequency: 0,
      swayAmplitude: 0,
      swayPhase: 0,
      radius: 0,
      kind: HospitalParticleKind.emeraldOrb,
      color: Colors.white,
      rotation: 0,
      rotationalSpeed: 0,
      pulseFrequency: 0,
      pulsePhase: 0,
      maxLifetime: 1,
      layerParallax: 1,
    );
    p.reset(size, rng, randomizeY: randomizeY);
    return p;
  }

  // Position & motion
  double x;
  double y;
  double baseX;
  double vy;
  double swayFrequency;
  double swayAmplitude;
  double swayPhase;
  double radius;
  HospitalParticleKind kind;
  Color color;
  double rotation;
  double rotationalSpeed;
  double pulseFrequency;
  double pulsePhase;
  double lifetime;
  double maxLifetime;
  double layerParallax;

  // Burst dynamics
  bool isBurst;
  double burstVx;
  double burstVy;

  /// Resets particle parameters in-place without heap re-allocation.
  void reset(Size size, math.Random rng, {bool randomizeY = false, Offset? origin}) {
    isBurst = origin != null;
    final double width = size.width > 0 ? size.width : 400;
    final double height = size.height > 0 ? size.height : 800;

    // Distribute particle kinds: 45% emerald orbs, 35% gold sparkles, 12% healing crosses, 8% rings
    final double roll = rng.nextDouble();
    if (roll < 0.45) {
      kind = HospitalParticleKind.emeraldOrb;
      // Emerald / Jade healing palette
      final double tint = rng.nextDouble();
      if (tint < 0.4) {
        color = const Color(0xFF10B981); // Emerald
      } else if (tint < 0.75) {
        color = const Color(0xFF34D399); // Mint / Jade
      } else {
        color = const Color(0xFF059669); // Deep restorative green
      }
      radius = 2.2 + rng.nextDouble() * 3.8;
    } else if (roll < 0.80) {
      kind = HospitalParticleKind.goldSparkle;
      // Celestial gold / stardust palette
      final double tint = rng.nextDouble();
      if (tint < 0.5) {
        color = const Color(0xFFFBBF24); // Amber gold
      } else if (tint < 0.8) {
        color = const Color(0xFFFDE68A); // Pale starlight
      } else {
        color = AppColors.liquidGold;
      }
      radius = 3.0 + rng.nextDouble() * 4.5;
    } else if (roll < 0.92) {
      kind = HospitalParticleKind.healingCross;
      color = const Color(0xFF6EE7B7); // Soft celestial cyan-green
      radius = 4.0 + rng.nextDouble() * 3.5;
    } else {
      kind = HospitalParticleKind.etherealRing;
      color = const Color(0xFF2DD4BF); // Ethereal teal halo
      radius = 6.0 + rng.nextDouble() * 6.0;
    }

    layerParallax = 0.5 + rng.nextDouble() * 0.7; // Depth scale 0.5 .. 1.2
    maxLifetime = 4.5 + rng.nextDouble() * 5.0; // 4.5s to 9.5s lifespan
    lifetime = randomizeY ? rng.nextDouble() * maxLifetime : 0.0;

    swayFrequency = 1.0 + rng.nextDouble() * 2.2;
    swayAmplitude = (8.0 + rng.nextDouble() * 18.0) * layerParallax;
    swayPhase = rng.nextDouble() * math.pi * 2;

    rotation = rng.nextDouble() * math.pi * 2;
    rotationalSpeed = (rng.nextDouble() - 0.5) * 2.5;

    pulseFrequency = 2.0 + rng.nextDouble() * 3.0;
    pulsePhase = rng.nextDouble() * math.pi * 2;

    if (isBurst && origin != null) {
      x = origin.dx;
      y = origin.dy;
      baseX = origin.dx;
      final double angle = rng.nextDouble() * math.pi * 2;
      final double speed = 40.0 + rng.nextDouble() * 120.0;
      burstVx = math.cos(angle) * speed;
      burstVy = math.sin(angle) * speed - 30.0; // Initial upward bias
      vy = 25.0 + rng.nextDouble() * 35.0;
      maxLifetime = 1.2 + rng.nextDouble() * 1.6; // Bursts are snappy
      lifetime = 0.0;
    } else {
      burstVx = 0.0;
      burstVy = 0.0;
      vy = (28.0 + rng.nextDouble() * 42.0) * layerParallax; // Rising speed
      baseX = rng.nextDouble() * width;
      x = baseX;
      if (randomizeY) {
        y = rng.nextDouble() * (height + 40);
      } else {
        y = height + 10.0 + rng.nextDouble() * 30.0;
      }
    }
  }

  /// Updates simulation state by [dt] seconds.
  ///
  /// Returns `true` if particle expired and was re-spawned.
  bool update(double dt, Size size, math.Random rng) {
    lifetime += dt;
    if (lifetime >= maxLifetime) {
      reset(size, rng, randomizeY: false);
      return true;
    }

    if (isBurst) {
      // Apply slight air resistance to burst velocity and transition to gentle float
      burstVx *= math.pow(0.88, dt * 60);
      burstVy = (burstVy * math.pow(0.88, dt * 60)) - (vy * 0.4 * dt);
      x += burstVx * dt;
      y += burstVy * dt;
      baseX = x;
    } else {
      // Natural vertical rise with sinusoidal horizontal drift
      y -= vy * dt;
      final double progress = lifetime / maxLifetime;
      final double wave = math.sin((progress * math.pi * 2 * swayFrequency) + swayPhase);
      x = baseX + (wave * swayAmplitude);

      // Screen boundary wrap
      if (size.width > 0) {
        if (x < -30) {
          x = size.width + 30;
          baseX = x;
        } else if (x > size.width + 30) {
          x = -30;
          baseX = x;
        }
      }
    }

    rotation += rotationalSpeed * dt;

    // Reset if floated above top screen boundary
    if (y < -40) {
      reset(size, rng, randomizeY: false);
      return true;
    }

    return false;
  }

  /// Calculates smooth non-linear alpha curve with soft fade-in and gentle fade-out.
  double get currentOpacity {
    final double progress = (lifetime / maxLifetime).clamp(0.0, 1.0);
    double alpha = 1.0;
    // Fade in during first 15% of lifetime
    if (progress < 0.15) {
      alpha = progress / 0.15;
    }
    // Fade out during last 25% of lifetime
    else if (progress > 0.75) {
      alpha = (1.0 - progress) / 0.25;
    }

    // Breathing pulse
    final double pulse = 0.85 + 0.15 * math.sin((lifetime * pulseFrequency) + pulsePhase);
    return (alpha * pulse * layerParallax).clamp(0.0, 1.0);
  }

  /// Current visual scale including breathing expansion.
  double get currentScale {
    final double pulse = 0.90 + 0.10 * math.sin((lifetime * pulseFrequency) + pulsePhase);
    return layerParallax * pulse;
  }
}

/// Controller allowing programmatic interaction with the hospital particle emitter.
class HospitalParticleController extends ChangeNotifier {
  Offset? _burstOrigin;
  int _burstCount = 0;
  int _burstId = 0;
  double _intensity = 1.0;
  bool _isPaused = false;

  Offset? get burstOrigin => _burstOrigin;
  int get burstCount => _burstCount;
  int get burstId => _burstId;
  double get intensity => _intensity;
  bool get isPaused => _isPaused;

  /// Triggers a burst of restorative sparkles radiating from [origin].
  void triggerBurst({Offset? origin, int count = 16}) {
    _burstOrigin = origin;
    _burstCount = count;
    _burstId++;
    notifyListeners();
  }

  /// Sets emission intensity multiplier (0.0 = off, 1.0 = standard, 2.0 = high).
  void setIntensity(double value) {
    final double clamped = value.clamp(0.0, 3.0);
    if (_intensity != clamped) {
      _intensity = clamped;
      notifyListeners();
    }
  }

  /// Pauses particle simulation.
  void pause() {
    if (!_isPaused) {
      _isPaused = true;
      notifyListeners();
    }
  }

  /// Resumes particle simulation.
  void resume() {
    if (_isPaused) {
      _isPaused = false;
      notifyListeners();
    }
  }
}

/// High-performance CustomPainter rendering rising restorative particles.
class HospitalParticlesPainter extends CustomPainter {
  HospitalParticlesPainter({
    required this.particles,
    required this.celestialGlow,
    required this.intensity,
    required this.animationValue,
  })  : _glowPaint = Paint()..isAntiAlias = true,
        _corePaint = Paint()..isAntiAlias = true,
        _starPaint = Paint()..isAntiAlias = true,
        _crossPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
        _ringPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke;

  final List<HospitalParticle> particles;
  final bool celestialGlow;
  final double intensity;
  final double animationValue;

  final Paint _glowPaint;
  final Paint _corePaint;
  final Paint _starPaint;
  final Paint _crossPaint;
  final Paint _ringPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || intensity <= 0) return;

    // 1. Celestial background atmosphere (ambient divine aura)
    if (celestialGlow) {
      _drawCelestialAtmosphere(canvas, size);
    }

    // 2. Render all particles using layered soft alpha blending
    for (int i = 0; i < particles.length; i++) {
      final HospitalParticle p = particles[i];
      final double opacity = p.currentOpacity * intensity;
      if (opacity <= 0.01) continue;

      final double scale = p.currentScale;
      final Offset center = Offset(p.x, p.y);

      switch (p.kind) {
        case HospitalParticleKind.emeraldOrb:
          _drawEmeraldOrb(canvas, center, p.radius * scale, p.color, opacity);
          break;
        case HospitalParticleKind.goldSparkle:
          _drawGoldSparkle(
            canvas,
            center,
            p.radius * scale,
            p.rotation,
            p.color,
            opacity,
          );
          break;
        case HospitalParticleKind.healingCross:
          _drawHealingCross(canvas, center, p.radius * scale, p.color, opacity);
          break;
        case HospitalParticleKind.etherealRing:
          _drawEtherealRing(
            canvas,
            center,
            p.radius * scale * (0.8 + 0.4 * (p.lifetime / p.maxLifetime)),
            p.color,
            opacity,
          );
          break;
      }
    }
  }

  /// Ambient restorative halo in the sanctuary background.
  void _drawCelestialAtmosphere(Canvas canvas, Size size) {
    final Rect topRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.25),
      width: size.width * 1.4,
      height: size.height * 0.7,
    );

    final Paint ambientPaint = Paint()
      ..isAntiAlias = true
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF10B981).withValues(alpha: 0.07 * intensity),
          const Color(0xFFFBBF24).withValues(alpha: 0.03 * intensity),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(topRect);

    canvas.drawOval(topRect, ambientPaint);
  }

  /// Soft glowing emerald restorative mote with bright nucleus.
  void _drawEmeraldOrb(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    // Outer radial halo
    final Rect haloRect = Rect.fromCircle(center: center, radius: radius * 2.8);
    _glowPaint.shader = RadialGradient(
      colors: <Color>[
        color.withValues(alpha: opacity * 0.45),
        color.withValues(alpha: opacity * 0.15),
        Colors.transparent,
      ],
      stops: const <double>[0.0, 0.5, 1.0],
    ).createShader(haloRect);
    canvas.drawCircle(center, radius * 2.8, _glowPaint);

    // Inner bright core
    _corePaint.shader = null;
    _corePaint.color = Color.lerp(color, Colors.white, 0.65)!.withValues(alpha: opacity * 0.95);
    canvas.drawCircle(center, radius * 0.75, _corePaint);
  }

  /// 4-pointed radiant celestial starburst with rotational flair.
  void _drawGoldSparkle(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Color color,
    double opacity,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final double len = radius * 2.4;
    final double thin = radius * 0.35;

    final Path starPath = Path()
      ..moveTo(0, -len)
      ..quadraticBezierTo(0, -thin, thin, 0)
      ..quadraticBezierTo(0, thin, 0, len)
      ..quadraticBezierTo(0, thin, -thin, 0)
      ..quadraticBezierTo(0, -thin, 0, -len)
      ..close();

    // Soft sparkle glow
    _starPaint.color = color.withValues(alpha: opacity * 0.4);
    canvas.drawCircle(Offset.zero, radius * 1.5, _starPaint);

    // Star diamond cross
    _starPaint.color = Color.lerp(color, Colors.white, 0.7)!.withValues(alpha: opacity * 0.95);
    canvas.drawPath(starPath, _starPaint);

    // Minor diagonal micro-cross for AAA celestial glint
    final Path minorPath = Path()
      ..moveTo(0, -len * 0.45)
      ..lineTo(0, len * 0.45)
      ..moveTo(-len * 0.45, 0)
      ..lineTo(len * 0.45, 0);

    final Paint minorPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.rotate(math.pi / 4);
    canvas.drawPath(minorPath, minorPaint);

    canvas.restore();
  }

  /// Divine restorative cross (+) motif.
  void _drawHealingCross(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final double arm = radius * 1.4;
    final double stroke = (radius * 0.55).clamp(1.5, 3.5);

    // Soft glow behind cross
    _glowPaint.shader = null;
    _glowPaint.color = color.withValues(alpha: opacity * 0.3);
    canvas.drawCircle(center, radius * 1.6, _glowPaint);

    // Cross arms
    _crossPaint.color = Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: opacity * 0.9);
    _crossPaint.strokeWidth = stroke;

    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      _crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      _crossPaint,
    );
  }

  /// Expanding ethereal halo ripple ring.
  void _drawEtherealRing(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    _ringPaint.color = color.withValues(alpha: opacity * 0.35);
    _ringPaint.strokeWidth = 1.2;
    canvas.drawCircle(center, radius, _ringPaint);

    // Soft outer blur ring
    _ringPaint.color = color.withValues(alpha: opacity * 0.15);
    _ringPaint.strokeWidth = 2.4;
    canvas.drawCircle(center, radius + 1.2, _ringPaint);
  }

  @override
  bool shouldRepaint(covariant HospitalParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.intensity != intensity ||
        oldDelegate.celestialGlow != celestialGlow;
  }
}

/// 60 FPS Restorative Floating Particle Emitter Widget for the Hospital Sanctuary.
///
/// Emits emerald and gold healing motes and sparkles that float upwards through the screen,
/// creating a living celestial atmosphere with zero touch interference.
class HospitalRestorativeParticles extends StatefulWidget {
  const HospitalRestorativeParticles({
    super.key,
    this.controller,
    this.particleCount = 42,
    this.speedMultiplier = 1.0,
    this.celestialGlow = true,
    this.interactive = false,
    this.child,
  });

  /// External controller for triggering bursts or adjusting intensity.
  final HospitalParticleController? controller;

  /// Number of active particles floating simultaneously (default: 42).
  final int particleCount;

  /// Speed scaling factor for vertical rise and harmonic sway.
  final double speedMultiplier;

  /// Whether to render the celestial ambient background glow.
  final bool celestialGlow;

  /// When true, tapping the surface emits restorative sparkle bursts at tap location.
  final bool interactive;

  /// Optional child rendered below or above particles.
  final Widget? child;

  @override
  State<HospitalRestorativeParticles> createState() =>
      _HospitalRestorativeParticlesState();
}

class _HospitalRestorativeParticlesState
    extends State<HospitalRestorativeParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _rng = math.Random();
  final List<HospitalParticle> _particles = <HospitalParticle>[];

  Duration _lastTick = Duration.zero;
  Size _lastSize = Size.zero;
  int _lastBurstId = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(_onTick);

    widget.controller?.addListener(_onExternalControllerChanged);
    _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant HospitalRestorativeParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onExternalControllerChanged);
      widget.controller?.addListener(_onExternalControllerChanged);
    }

    if (oldWidget.particleCount != widget.particleCount) {
      _adjustParticleCount();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onExternalControllerChanged);
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _onExternalControllerChanged() {
    final HospitalParticleController? c = widget.controller;
    if (c == null) return;

    if (c.isPaused && _controller.isAnimating) {
      _controller.stop();
    } else if (!c.isPaused && !_controller.isAnimating) {
      _controller.repeat();
    }

    if (c.burstId != _lastBurstId) {
      _lastBurstId = c.burstId;
      _spawnBurst(c.burstOrigin, count: c.burstCount);
    }
    setState(() {});
  }

  void _spawnBurst(Offset? origin, {int count = 16}) {
    if (_lastSize.isEmpty) return;
    final Offset burstCenter = origin ?? Offset(_lastSize.width / 2, _lastSize.height / 2);
    final int toSpawn = math.min(count, 32);

    for (int i = 0; i < toSpawn; i++) {
      // Find an ambient particle or oldest to convert to burst
      if (_particles.length < widget.particleCount + 24) {
        final HospitalParticle p = HospitalParticle.random(_lastSize, _rng);
        p.reset(_lastSize, _rng, origin: burstCenter);
        _particles.add(p);
      } else {
        final HospitalParticle p = _particles[i % _particles.length];
        p.reset(_lastSize, _rng, origin: burstCenter);
      }
    }
  }

  void _adjustParticleCount() {
    if (_lastSize.isEmpty) return;
    while (_particles.length < widget.particleCount) {
      _particles.add(HospitalParticle.random(_lastSize, _rng, randomizeY: true));
    }
    while (_particles.length > widget.particleCount && _particles.isNotEmpty) {
      _particles.removeLast();
    }
  }

  void _ensureInitialized(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (_particles.isEmpty || _lastSize != size) {
      _lastSize = size;
      _particles.clear();
      for (int i = 0; i < widget.particleCount; i++) {
        _particles.add(HospitalParticle.random(size, _rng, randomizeY: true));
      }
    }
  }

  void _onTick() {
    if (!mounted) return;
    final Duration current = _controller.lastElapsedDuration ?? Duration.zero;
    if (_lastTick == Duration.zero) {
      _lastTick = current;
      return;
    }

    double dt = (current - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = current;

    // Handle loop wrap or frame drop clamp (lock to max 1/30s step)
    if (dt < 0 || dt > 0.05) {
      dt = 0.016;
    }

    final double effectiveDt = dt * widget.speedMultiplier;
    if (_lastSize.width > 0 && _lastSize.height > 0) {
      for (int i = 0; i < _particles.length; i++) {
        _particles[i].update(effectiveDt, _lastSize, _rng);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget particleLayer = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureInitialized(size);

        return CustomPaint(
          size: size,
          painter: HospitalParticlesPainter(
            particles: _particles,
            celestialGlow: widget.celestialGlow,
            intensity: widget.controller?.intensity ?? 1.0,
            animationValue: _controller.value,
          ),
        );
      },
    );

    Widget content = widget.child != null
        ? Stack(
            fit: StackFit.expand,
            children: <Widget>[
              widget.child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: particleLayer,
                ),
              ),
            ],
          )
        : particleLayer;

    if (widget.interactive) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (TapDownDetails details) {
          _spawnBurst(details.localPosition, count: 18);
        },
        child: content,
      );
    }

    return content;
  }
}

/// Seamless high-level sanctuary atmosphere backdrop combining soft celestial glow
/// and rising emerald & gold restorative particles.
class HospitalSanctuaryAtmosphere extends StatelessWidget {
  const HospitalSanctuaryAtmosphere({
    super.key,
    required this.child,
    this.controller,
    this.particleCount = 42,
    this.celestialGlow = true,
  });

  final Widget child;
  final HospitalParticleController? controller;
  final int particleCount;
  final bool celestialGlow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: HospitalRestorativeParticles(
              controller: controller,
              particleCount: particleCount,
              celestialGlow: celestialGlow,
            ),
          ),
        ),
      ],
    );
  }
}
