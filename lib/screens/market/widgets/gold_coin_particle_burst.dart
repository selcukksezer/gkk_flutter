import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

/// Gold coin particle for genuine physics simulation.
class _CoinParticle {
  _CoinParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angularVelocity,
    required this.radius,
    required this.isSparkle,
  })  : spinAngle = math.Random().nextDouble() * math.pi * 2,
        currentX = x,
        currentY = y,
        alpha = 1.0;

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double angularVelocity;
  final double radius;
  final bool isSparkle;

  double currentX;
  double currentY;
  double spinAngle;
  double alpha;

  void update(double dt, double progress) {
    // Air resistance & gravity
    const double gravity = 980.0;
    const double drag = 0.98;

    currentX += vx * dt * math.pow(drag, progress * 40);
    currentY += (vy * dt * math.pow(drag, progress * 40)) + (0.5 * gravity * dt * dt);
    spinAngle += angularVelocity * dt;
    alpha = (1.0 - progress).clamp(0.0, 1.0);
  }
}

/// Controller to trigger burst animations programmatically.
class GoldCoinBurstController extends ChangeNotifier {
  Offset? _burstOrigin;
  int _burstId = 0;

  Offset? get burstOrigin => _burstOrigin;
  int get burstId => _burstId;

  void trigger({Offset? origin}) {
    _burstOrigin = origin;
    _burstId++;
    HapticFeedback.selectionClick();
    notifyListeners();
  }
}

/// Gold coin particle burst layer.
class GoldCoinParticleBurst extends StatefulWidget {
  const GoldCoinParticleBurst({
    super.key,
    this.controller,
    this.child,
  });

  final GoldCoinBurstController? controller;
  final Widget? child;

  /// Convenience method to trigger a coin burst overlay on any context.
  static void trigger(BuildContext context, {Offset? origin}) {
    HapticFeedback.selectionClick();
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) => _GoldCoinBurstSingleShot(
        origin: origin ??
            Offset(
              MediaQuery.of(ctx).size.width / 2,
              MediaQuery.of(ctx).size.height / 2,
            ),
        onComplete: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<GoldCoinParticleBurst> createState() => _GoldCoinParticleBurstState();
}

class _GoldCoinParticleBurstState extends State<GoldCoinParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final List<_CoinParticle> _particles = <_CoinParticle>[];
  Offset _center = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animController.addListener(() {
      final double dt = 0.016;
      final double progress = _animController.value;
      for (final _CoinParticle p in _particles) {
        p.update(dt, progress);
      }
      setState(() {});
    });

    widget.controller?.addListener(_onControllerTrigger);
  }

  @override
  void didUpdateWidget(covariant GoldCoinParticleBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerTrigger);
      widget.controller?.addListener(_onControllerTrigger);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerTrigger);
    _animController.dispose();
    super.dispose();
  }

  void _onControllerTrigger() {
    final Size size = MediaQuery.sizeOf(context);
    _spawnParticles(
      widget.controller?.burstOrigin ?? Offset(size.width / 2, size.height * 0.45),
    );
  }

  void _spawnParticles(Offset origin) {
    _center = origin;
    _particles.clear();
    final math.Random rnd = math.Random();
    const int coinCount = 36;

    for (int i = 0; i < coinCount; i++) {
      final double angle = rnd.nextDouble() * math.pi * 2;
      final double speed = rnd.nextDouble() * 420 + 200;
      final double vx = math.cos(angle) * speed;
      final double vy = math.sin(angle) * speed - 220; // Upward bias
      final bool isSparkle = i % 4 == 0;

      _particles.add(
        _CoinParticle(
          x: origin.dx,
          y: origin.dy,
          vx: vx,
          vy: vy,
          angularVelocity: (rnd.nextDouble() - 0.5) * 16,
          radius: isSparkle ? (rnd.nextDouble() * 3 + 2) : (rnd.nextDouble() * 6 + 7),
          isSparkle: isSparkle,
        ),
      );
    }

    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        if (widget.child != null) widget.child!,
        if (_animController.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CoinBurstPainter(
                  particles: _particles,
                  progress: _animController.value,
                  center: _center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoldCoinBurstSingleShot extends StatefulWidget {
  const _GoldCoinBurstSingleShot({
    required this.origin,
    required this.onComplete,
  });

  final Offset origin;
  final VoidCallback onComplete;

  @override
  State<_GoldCoinBurstSingleShot> createState() => _GoldCoinBurstSingleShotState();
}

class _GoldCoinBurstSingleShotState extends State<_GoldCoinBurstSingleShot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_CoinParticle> _particles = <_CoinParticle>[];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    final math.Random rnd = math.Random();
    const int count = 38;
    for (int i = 0; i < count; i++) {
      final double angle = rnd.nextDouble() * math.pi * 2;
      final double speed = rnd.nextDouble() * 460 + 220;
      final double vx = math.cos(angle) * speed;
      final double vy = math.sin(angle) * speed - 260; // Initial burst upwards
      final bool isSparkle = i % 4 == 0;

      _particles.add(
        _CoinParticle(
          x: widget.origin.dx,
          y: widget.origin.dy,
          vx: vx,
          vy: vy,
          angularVelocity: (rnd.nextDouble() - 0.5) * 18,
          radius: isSparkle ? (rnd.nextDouble() * 3.5 + 2) : (rnd.nextDouble() * 6 + 7),
          isSparkle: isSparkle,
        ),
      );
    }

    _controller.addListener(() {
      final double dt = 0.016;
      final double progress = _controller.value;
      for (final _CoinParticle p in _particles) {
        p.update(dt, progress);
      }
      setState(() {});
    });

    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CoinBurstPainter(
          particles: _particles,
          progress: _controller.value,
          center: widget.origin,
        ),
      ),
    );
  }
}

class _CoinBurstPainter extends CustomPainter {
  const _CoinBurstPainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  final List<_CoinParticle> particles;
  final double progress;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Initial Shockwave Aura Ring
    if (progress < 0.45) {
      final double ringProgress = progress / 0.45;
      final double ringRadius = ringProgress * 120;
      final Paint auraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 - ringProgress) * 4.0
        ..color = AppColors.liquidGold.withValues(alpha: (1.0 - ringProgress) * 0.7);
      canvas.drawCircle(center, ringRadius, auraPaint);
    }

    // 2. Draw Simulated 3D Gold Coins & Sparkles
    for (final _CoinParticle p in particles) {
      if (p.alpha <= 0.01) continue;

      if (p.isSparkle) {
        // Star sparkle
        final Paint sparklePaint = Paint()
          ..color = Colors.white.withValues(alpha: p.alpha * 0.95);
        final double s = p.radius * (1.0 - progress * 0.5);
        canvas.drawCircle(Offset(p.currentX, p.currentY), s, sparklePaint);

        final Paint sparkleGlow = Paint()
          ..color = AppColors.liquidGold.withValues(alpha: p.alpha * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(p.currentX, p.currentY), s * 2, sparkleGlow);
      } else {
        // 3D Tumbling Coin
        final double spinScale = math.cos(p.spinAngle).abs();
        final double coinWidth = math.max(1.8, p.radius * 2 * spinScale);
        final double coinHeight = p.radius * 2;

        final Rect coinRect = Rect.fromCenter(
          center: Offset(p.currentX, p.currentY),
          width: coinWidth,
          height: coinHeight,
        );

        // Drop shadow
        final Paint shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: p.alpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawOval(coinRect.translate(0, 3), shadowPaint);

        // Gold Gradient Body
        final Paint coinPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFFFFF0A0).withValues(alpha: p.alpha),
              AppColors.liquidGold.withValues(alpha: p.alpha),
              const Color(0xFFC78200).withValues(alpha: p.alpha),
            ],
            stops: const <double>[0.0, 0.45, 1.0],
          ).createShader(coinRect);
        canvas.drawOval(coinRect, coinPaint);

        // Metallic Rim
        final Paint rimPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFFFFEFA8).withValues(alpha: p.alpha * 0.85);
        canvas.drawOval(coinRect, rimPaint);

        // Specular glint
        if (spinScale > 0.6) {
          final Paint glintPaint = Paint()
            ..color = Colors.white.withValues(alpha: p.alpha * 0.7);
          canvas.drawCircle(
            Offset(p.currentX - coinWidth * 0.2, p.currentY - coinHeight * 0.2),
            coinWidth * 0.15,
            glintPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CoinBurstPainter oldDelegate) => true;
}
