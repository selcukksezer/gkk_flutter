import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../inventory/widgets/aion_rarity_glow.dart';

/// Supported particle geometry shapes.
enum CraftParticleShape {
  sparkCircle,
  star4,
  diamond,
  ring,
}

/// Simulated particle with physics kinematics and rendering characteristics.
class CraftParticle {
  CraftParticle({
    required this.origin,
    required this.velocity,
    required this.gravity,
    required this.drag,
    required this.rotation,
    required this.angularVelocity,
    required this.size,
    required this.color,
    required this.secondaryColor,
    required this.maxLifetime,
    required this.shape,
  })  : position = origin,
        lifetime = 0.0;

  final Offset origin;
  final Offset velocity;
  final double gravity;
  final double drag;
  final double angularVelocity;
  final double size;
  final Color color;
  final Color secondaryColor;
  final double maxLifetime;
  final CraftParticleShape shape;

  Offset position;
  double rotation;
  double lifetime;

  bool get isDead => lifetime >= maxLifetime;
  double get progress => (lifetime / maxLifetime).clamp(0.0, 1.0);
  double get opacity => (1.0 - progress).clamp(0.0, 1.0);
  double get currentScale => (1.0 - (progress * 0.4)).clamp(0.1, 1.2);

  void update(double dt) {
    lifetime += dt;
    final double t = progress;

    // Kinematic motion with drag and gravity:
    // v_effective = v0 * e^(-drag * t)
    final double dragFactor = math.exp(-drag * t);
    position = Offset(
      origin.dx + velocity.dx * t * dragFactor,
      origin.dy + velocity.dy * t * dragFactor + 0.5 * gravity * t * t,
    );

    rotation += angularVelocity * dt;
  }
}

/// Controller to trigger particle explosions on demand.
class CraftingParticleBurstController extends ChangeNotifier {
  void Function({
    Offset? origin,
    AionRarityTier? tier,
    int? count,
  })? _onBurst;

  VoidCallback? _onClear;

  void attach({
    required void Function({Offset? origin, AionRarityTier? tier, int? count}) onBurst,
    required VoidCallback onClear,
  }) {
    _onBurst = onBurst;
    _onClear = onClear;
  }

  void detach() {
    _onBurst = null;
    _onClear = null;
  }

  void burst({
    Offset? origin,
    AionRarityTier? tier,
    int? count,
  }) {
    _onBurst?.call(origin: origin, tier: tier, count: count);
  }

  void clear() {
    _onClear?.call();
  }
}

/// Full particle burst system on crafting completion / claiming.
///
/// Features:
/// - True physics simulation: gravity, radial velocity, drag resistance, and angular spin.
/// - Dynamic particle shapes: sparks, 4-point magical stars, crystal diamonds, and shock rings.
/// - Automatic Aion 2 rarity-driven color themes (common slate, rare azure, epic violet, mythic crimson, archon gold).
/// - Can wrap around any target widget (e.g. item slot / anvil / card) or render standalone.
/// - Static helper [burstOverlay] to trigger bursts anywhere over the screen.
class CraftingParticleBurst extends StatefulWidget {
  const CraftingParticleBurst({
    super.key,
    this.controller,
    this.child,
    this.tier = AionRarityTier.archon,
    this.particleCount = 42,
    this.autoBurst = false,
    this.burstDuration = const Duration(milliseconds: 950),
    this.gravity = 380.0,
    this.drag = 1.4,
    this.customColors,
    this.onCompleted,
  });

  final CraftingParticleBurstController? controller;
  final Widget? child;
  final AionRarityTier tier;
  final int particleCount;
  final bool autoBurst;
  final Duration burstDuration;
  final double gravity;
  final double drag;
  final List<Color>? customColors;
  final VoidCallback? onCompleted;

  /// Helper to trigger a floating one-shot particle burst over any widget/position.
  static OverlayEntry burstOverlay(
    BuildContext context, {
    required Offset origin,
    AionRarityTier tier = AionRarityTier.archon,
    int particleCount = 48,
    Duration duration = const Duration(milliseconds: 1000),
  }) {
    final OverlayState overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (BuildContext ctx) => Positioned.fill(
        child: IgnorePointer(
          child: _OneShotBurstOverlay(
            origin: origin,
            tier: tier,
            particleCount: particleCount,
            duration: duration,
            onDone: () => entry.remove(),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    return entry;
  }

  @override
  State<CraftingParticleBurst> createState() => _CraftingParticleBurstState();
}

class _CraftingParticleBurstState extends State<CraftingParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final List<CraftParticle> _particles = <CraftParticle>[];
  final math.Random _rng = math.Random();
  double _lastElapsed = 0.0;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: widget.burstDuration,
    )..addListener(_tickPhysics);

    _animController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted?.call();
      }
    });

    widget.controller?.attach(
      onBurst: ({Offset? origin, AionRarityTier? tier, int? count}) {
        triggerBurst(origin: origin, tier: tier, count: count);
      },
      onClear: _clearParticles,
    );

    if (widget.autoBurst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) triggerBurst();
      });
    }
  }

  @override
  void didUpdateWidget(covariant CraftingParticleBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(
        onBurst: ({Offset? origin, AionRarityTier? tier, int? count}) {
          triggerBurst(origin: origin, tier: tier, count: count);
        },
        onClear: _clearParticles,
      );
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _animController.dispose();
    super.dispose();
  }

  void _clearParticles() {
    _particles.clear();
    _animController.reset();
    _lastElapsed = 0.0;
    if (mounted) setState(() {});
  }

  void _tickPhysics() {
    final double currentElapsed = _animController.value;
    final double dt = (currentElapsed - _lastElapsed).clamp(0.001, 0.08);
    _lastElapsed = currentElapsed;

    for (final CraftParticle particle in _particles) {
      particle.update(dt);
    }

    if (mounted) setState(() {});
  }

  List<Color> _paletteForTier(AionRarityTier tier) {
    if (widget.customColors != null && widget.customColors!.isNotEmpty) {
      return widget.customColors!;
    }
    return switch (tier) {
      AionRarityTier.common => const <Color>[
          Color(0xFFE2E8F0),
          Color(0xFF94A3B8),
          Color(0xFF64748B),
          Color(0xFFFFFFFF),
        ],
      AionRarityTier.rare => const <Color>[
          Color(0xFF38BDF8),
          Color(0xFF0284C7),
          Color(0xFF67E8F9),
          Color(0xFFE0F2FE),
        ],
      AionRarityTier.epic => const <Color>[
          Color(0xFFA855F7),
          Color(0xFF7E22CE),
          Color(0xFFC084FC),
          Color(0xFFF3E8FF),
        ],
      AionRarityTier.mythic => const <Color>[
          Color(0xFFF43F5E),
          Color(0xFFBE123C),
          Color(0xFFFB7185),
          Color(0xFFFFD166),
        ],
      AionRarityTier.archon => const <Color>[
          Color(0xFFFFB800),
          Color(0xFFFDE68A),
          Color(0xFF06D0D8),
          Color(0xFFFFFFFF),
        ],
    };
  }

  void triggerBurst({Offset? origin, AionRarityTier? tier, int? count}) {
    if (!mounted) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Size size = box?.hasSize == true ? box!.size : const Size(200, 200);
    final Offset burstCenter = origin ?? Offset(size.width * 0.5, size.height * 0.5);

    final AionRarityTier effectiveTier = tier ?? widget.tier;
    final List<Color> colors = _paletteForTier(effectiveTier);
    final int particleCount = count ?? widget.particleCount;

    _particles.clear();
    _lastElapsed = 0.0;

    for (int i = 0; i < particleCount; i++) {
      // 360 degree radial dispersion with slight upward bias
      final double angle = _rng.nextDouble() * 2 * math.pi;
      final double speed = 140.0 + _rng.nextDouble() * 280.0;
      final Offset initialVelocity = Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 60.0, // slight upward impulse
      );

      final Color mainColor = colors[_rng.nextInt(colors.length)];
      final Color secColor = colors[_rng.nextInt(colors.length)];

      final CraftParticleShape shape = switch (_rng.nextInt(10)) {
        0 || 1 || 2 || 3 => CraftParticleShape.star4,
        4 || 5 || 6 => CraftParticleShape.sparkCircle,
        7 || 8 => CraftParticleShape.diamond,
        _ => CraftParticleShape.ring,
      };

      _particles.add(
        CraftParticle(
          origin: burstCenter,
          velocity: initialVelocity,
          gravity: widget.gravity,
          drag: widget.drag,
          rotation: _rng.nextDouble() * 2 * math.pi,
          angularVelocity: (-6.0 + _rng.nextDouble() * 12.0),
          size: 4.0 + _rng.nextDouble() * 7.0,
          color: mainColor,
          secondaryColor: secColor,
          maxLifetime: 0.65 + _rng.nextDouble() * 0.35,
          shape: shape,
        ),
      );
    }

    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (widget.child != null) widget.child!,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: CraftingParticlePainter(particles: _particles),
            ),
          ),
        ),
      ],
    );
  }
}

/// Standalone overlay for one-shot burst animations.
class _OneShotBurstOverlay extends StatefulWidget {
  const _OneShotBurstOverlay({
    required this.origin,
    required this.tier,
    required this.particleCount,
    required this.duration,
    required this.onDone,
  });

  final Offset origin;
  final AionRarityTier tier;
  final int particleCount;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_OneShotBurstOverlay> createState() => _OneShotBurstOverlayState();
}

class _OneShotBurstOverlayState extends State<_OneShotBurstOverlay> {
  final CraftingParticleBurstController _controller = CraftingParticleBurstController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.burst(
        origin: widget.origin,
        tier: widget.tier,
        count: widget.particleCount,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CraftingParticleBurst(
      controller: _controller,
      tier: widget.tier,
      particleCount: widget.particleCount,
      burstDuration: widget.duration,
      onCompleted: widget.onDone,
    );
  }
}

/// Canvas painter that draws all active particles with appropriate geometries and glows.
class CraftingParticlePainter extends CustomPainter {
  CraftingParticlePainter({required this.particles});

  final List<CraftParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final CraftParticle p in particles) {
      if (p.isDead || p.opacity <= 0.01) continue;

      final double alpha = p.opacity;
      final double s = p.size * p.currentScale;

      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case CraftParticleShape.sparkCircle:
          _drawSpark(canvas, s, p.color, alpha);
        case CraftParticleShape.star4:
          _drawStar4(canvas, s, p.color, p.secondaryColor, alpha);
        case CraftParticleShape.diamond:
          _drawDiamond(canvas, s, p.color, alpha);
        case CraftParticleShape.ring:
          _drawRing(canvas, s, p.color, alpha);
      }

      canvas.restore();
    }
  }

  void _drawSpark(Canvas canvas, double size, Color color, double alpha) {
    // Outer radial glow
    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset.zero, size * 1.6, glowPaint);

    // Inner bright core
    final Paint corePaint = Paint()
      ..color = Colors.white.withValues(alpha: alpha);
    canvas.drawCircle(Offset.zero, size * 0.65, corePaint);
  }

  void _drawStar4(Canvas canvas, double size, Color primary, Color secondary, double alpha) {
    final Path path = Path();
    final double rOuter = size * 1.5;
    final double rInner = size * 0.38;

    for (int i = 0; i < 8; i++) {
      final double r = i.isEven ? rOuter : rInner;
      final double theta = (i * math.pi / 4.0);
      final double x = r * math.cos(theta);
      final double y = r * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Outer glow
    final Paint glowPaint = Paint()
      ..color = secondary.withValues(alpha: alpha * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path, glowPaint);

    // Main fill
    final Paint fillPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[Colors.white.withValues(alpha: alpha), primary.withValues(alpha: alpha)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: rOuter));
    canvas.drawPath(path, fillPaint);
  }

  void _drawDiamond(Canvas canvas, double size, Color color, double alpha) {
    final Path path = Path()
      ..moveTo(0, -size * 1.4)
      ..lineTo(size * 0.9, 0)
      ..lineTo(0, size * 1.4)
      ..lineTo(-size * 0.9, 0)
      ..close();

    final Paint paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Specular center streak
    final Paint streak = Paint()
      ..color = Colors.white.withValues(alpha: alpha * 0.9)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, -size * 0.9), Offset(0, size * 0.9), streak);
  }

  void _drawRing(Canvas canvas, double size, Color color, double alpha) {
    final Paint ringPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(Offset.zero, size * 1.3, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CraftingParticlePainter oldDelegate) => true;
}
