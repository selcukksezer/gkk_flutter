import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../screens/settings/graphics_settings_service.dart';
import '../../theme/app_colors.dart';

enum ComebackParticleKind {
  spark,
  star,
  confetti,
  glimmer,
}

class ComebackParticle {
  ComebackParticle({
    required this.kind,
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.gravity,
    required this.drag,
    required this.lifeSpan,
    this.enableTrails = false,
    this.maxTrailPoints = 6,
  });

  final ComebackParticleKind kind;
  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  double rotation;
  final double rotationSpeed;
  final double gravity;
  final double drag;
  final double lifeSpan;
  final bool enableTrails;
  final int maxTrailPoints;
  final List<Offset> trail = <Offset>[];

  /// Updates particle physics over time slice [dt].
  ///
  /// When [simplifyPhysics] is true (Eco/Low tiers <=2GB RAM),
  /// integration skips drag and rotational torque calculations,
  /// executing a pure linear Euler step to preserve CPU budget.
  void update(double dt, {bool simplifyPhysics = false}) {
    if (simplifyPhysics) {
      position += velocity * dt;
      return;
    }

    if (enableTrails) {
      trail.add(position);
      if (trail.length > maxTrailPoints) {
        trail.removeAt(0);
      }
    }

    velocity = Offset(
      velocity.dx * (1.0 - drag * dt),
      (velocity.dy + gravity * dt) * (1.0 - drag * dt),
    );
    position += velocity * dt;
    rotation += rotationSpeed * dt;
  }
}

class ComebackParticleBurstController {
  _ComebackParticleBurstState? _state;

  void _attach(_ComebackParticleBurstState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// Triggers a celebratory particle burst.
  ///
  /// If [count] is null or uses the default, particle count is adaptively
  /// scaled according to the hardware tier:
  /// - Eco / Low (<=2GB RAM): 25-35 particles
  /// - Mid: 70 particles
  /// - High / Ultra: 200+ particles
  void burst({Offset? origin, int? count}) {
    _state?.triggerBurst(origin: origin, count: count);
  }

  /// Current active particle count after tier adaptation.
  int? get activeParticleCount => _state?.currentParticleCount;
}

class ComebackParticleBurst extends StatefulWidget {
  const ComebackParticleBurst({
    super.key,
    this.controller,
    this.child,
    this.autoStart = false,
    this.particleCount = defaultParticleCount,
    this.scaler,
  });

  /// Baseline particle count before adaptive hardware scaling.
  static const int defaultParticleCount = 120;

  final ComebackParticleBurstController? controller;
  final Widget? child;
  final bool autoStart;
  final int particleCount;
  final AdaptiveQualityScaler? scaler;

  static bool _isPrewarmed = false;
  static Path? _cachedStarPath;
  static Path? _cachedDiamondPath;
  static AdaptiveQualityScaler? _fallbackScaler;

  /// Default scaler instance used across the game engine.
  static AdaptiveQualityScaler get defaultScaler {
    try {
      return GraphicsSettingsService.instance.scaler;
    } catch (_) {
      return _fallbackScaler ??= AdaptiveQualityScaler();
    }
  }

  /// Pre-warms geometric path caches, color lookup, and math constants.
  static void prewarmAssets() {
    if (_isPrewarmed) return;

    // 1. Pre-calculate unit star geometry (normalized to radius 10.0, 4 points)
    final Path star = Path();
    const int points = 4;
    const double step = math.pi / points;
    const double radius = 10.0;
    const double innerRadius = radius * 0.35;
    for (int i = 0; i < points * 2; i++) {
      final double r = i.isEven ? radius : innerRadius;
      final double angle = i * step;
      final double x = r * math.cos(angle);
      final double y = r * math.sin(angle);
      if (i == 0) {
        star.moveTo(x, y);
      } else {
        star.lineTo(x, y);
      }
    }
    star.close();
    _cachedStarPath = star;

    // 2. Pre-calculate unit diamond geometry (normalized to radius 10.0)
    final Path diamond = Path()
      ..moveTo(0, -10.0)
      ..lineTo(10.0 * 0.65, 0)
      ..lineTo(0, 10.0)
      ..lineTo(-10.0 * 0.65, 0)
      ..close();
    _cachedDiamondPath = diamond;

    _isPrewarmed = true;
  }

  /// Pre-warms particle burst assets via [ZeroJankPreloader] adhering strictly to <2ms budget.
  static Future<bool> prewarm({ZeroJankPreloader? preloader}) {
    final ZeroJankPreloader target = preloader ?? ZeroJankPreloader.instance;
    return target.preloadAtomic<bool>(
      id: 'asset_comeback_particle_burst_cache',
      priority: PreloadPriority.criticalHud,
      targetCache: CacheTarget.ram,
      estimatedSizeBytes: 16 * 1024,
      tags: const <String>{'comeback', 'vfx', 'particles', 'geometry'},
      loader: () async {
        prewarmAssets();
        return true;
      },
    );
  }

  @override
  State<ComebackParticleBurst> createState() => _ComebackParticleBurstState();
}

class _ComebackParticleBurstState extends State<ComebackParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  final List<ComebackParticle> _particles = <ComebackParticle>[];
  final math.Random _random = math.Random();
  double _lastT = 0;

  static const List<Color> _palette = <Color>[
    AppColors.liquidGold,
    AppColors.warningSolar,
    AppColors.accentCyan,
    AppColors.cyberFuchsia,
    AppColors.mysticRuby,
    Colors.white,
  ];

  AdaptiveQualityScaler get _activeScaler =>
      widget.scaler ?? ComebackParticleBurst.defaultScaler;

  int get currentParticleCount => _particles.length;

  bool get _shouldSimplifyPhysics {
    final HardwareTier tier = _activeScaler.currentTier;
    return tier == HardwareTier.eco || tier == HardwareTier.low;
  }

  bool get _shouldEnableTrails {
    final HardwareTier tier = _activeScaler.currentTier;
    return tier == HardwareTier.high || tier == HardwareTier.ultra;
  }

  /// Resolves particle count adaptively against hardware tier and active scaler constraints.
  int resolveTierParticleCount({int? requestedCount}) {
    final AdaptiveQualityScaler scaler = _activeScaler;
    final HardwareTier tier = scaler.currentTier;
    final int maxParticlesCap = scaler.currentSettings.maxActiveParticles;

    int baseTierCount;
    switch (tier) {
      case HardwareTier.eco:
        baseTierCount = 28;
      case HardwareTier.low:
        baseTierCount = 32;
      case HardwareTier.mid:
        baseTierCount = 70;
      case HardwareTier.high:
        baseTierCount = 200;
      case HardwareTier.ultra:
        baseTierCount = 240;
    }

    int resolved;
    if (requestedCount == null ||
        requestedCount == ComebackParticleBurst.defaultParticleCount) {
      resolved = baseTierCount;
    } else {
      final double ratio =
          baseTierCount / ComebackParticleBurst.defaultParticleCount;
      resolved = (requestedCount * ratio).round();

      if (tier == HardwareTier.eco || tier == HardwareTier.low) {
        resolved = resolved.clamp(25, 35);
      } else if (tier == HardwareTier.mid) {
        resolved = resolved.clamp(40, 70);
      } else {
        resolved = math.max(200, resolved);
      }
    }

    // Check scaler.currentSettings.maxActiveParticles ceiling
    if (resolved > maxParticlesCap) {
      resolved = maxParticlesCap;
    }

    return math.max(10, resolved);
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    ComebackParticleBurst.prewarm();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(_onTick)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          _particles.clear();
        }
      });

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) triggerBurst(count: widget.particleCount);
      });
    }
  }

  @override
  void didUpdateWidget(ComebackParticleBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _animCtrl.dispose();
    _particles.clear();
    super.dispose();
  }

  void triggerBurst({Offset? origin, int? count}) {
    if (!mounted) return;
    _particles.clear();
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Size size = box?.size ?? const Size(390, 400);
    final Offset center = origin ?? Offset(size.width / 2, size.height / 2);

    final int resolvedCount = resolveTierParticleCount(requestedCount: count);
    final bool enableTrails = _shouldEnableTrails;

    for (int i = 0; i < resolvedCount; i++) {
      final double angle = _random.nextDouble() * 2 * math.pi;
      final double speed = 120.0 + _random.nextDouble() * 320.0;
      final ComebackParticleKind kind = ComebackParticleKind.values[
          _random.nextInt(ComebackParticleKind.values.length)];
      final Color color = _palette[_random.nextInt(_palette.length)];
      final double pSize = 4.0 + _random.nextDouble() * 7.0;

      _particles.add(
        ComebackParticle(
          kind: kind,
          position: center,
          velocity:
              Offset(math.cos(angle) * speed, math.sin(angle) * speed - 60),
          color: color,
          size: pSize,
          rotation: _random.nextDouble() * 2 * math.pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 8.0,
          gravity: 280.0 + _random.nextDouble() * 120.0,
          drag: 0.85,
          lifeSpan: 0.8 + _random.nextDouble() * 0.6,
          enableTrails: enableTrails,
        ),
      );
    }

    _lastT = 0;
    _animCtrl.forward(from: 0);
  }

  void _onTick() {
    final double t = _animCtrl.value;
    final double dt = (t - _lastT).clamp(0.001, 0.05);
    _lastT = t;

    final bool simplify = _shouldSimplifyPhysics;
    for (final ComebackParticle p in _particles) {
      p.update(dt, simplifyPhysics: simplify);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _animCtrl.isAnimating && _particles.isNotEmpty
          ? _ComebackParticlePainter(
              particles: _particles,
              progress: _animCtrl.value,
            )
          : null,
      child: widget.child,
    );
  }
}

class _ComebackParticlePainter extends CustomPainter {
  _ComebackParticlePainter({
    required this.particles,
    required this.progress,
  });

  final List<ComebackParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    for (final ComebackParticle p in particles) {
      final double progressRatio = (progress / p.lifeSpan).clamp(0.0, 1.0);
      if (progressRatio >= 1.0) continue;

      final double alpha = (1.0 - progressRatio).clamp(0.0, 1.0);

      // Render fading trails on High/Ultra tiers
      if (p.enableTrails && p.trail.length > 1) {
        final Paint trailPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        for (int i = 1; i < p.trail.length; i++) {
          final double segmentRatio = i / p.trail.length;
          final double trailAlpha = alpha * segmentRatio * 0.45;
          if (trailAlpha <= 0.01) continue;

          trailPaint.color = p.color.withValues(alpha: trailAlpha);
          trailPaint.strokeWidth = math.max(1.0, p.size * segmentRatio * 0.5);
          canvas.drawLine(p.trail[i - 1], p.trail[i], trailPaint);
        }
      }

      fillPaint.color = p.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);

      switch (p.kind) {
        case ComebackParticleKind.spark:
          canvas.drawCircle(
              Offset.zero, p.size * (1.0 - progressRatio * 0.4), fillPaint);
        case ComebackParticleKind.star:
          _drawStar(canvas, p.size * (1.0 - progressRatio * 0.3), fillPaint);
        case ComebackParticleKind.confetti:
          final double aspectScale =
              math.cos(p.rotation * 1.5).abs().clamp(0.15, 1.0);
          final Rect rect = Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.6,
            height: p.size * 0.9 * aspectScale,
          );
          canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(2)),
              fillPaint);
        case ComebackParticleKind.glimmer:
          _drawDiamond(
              canvas, p.size * 1.2 * (1.0 - progressRatio * 0.5), fillPaint);
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double radius, Paint paint) {
    final Path? template = ComebackParticleBurst._cachedStarPath;
    if (template != null) {
      canvas.save();
      final double s = radius / 10.0;
      canvas.scale(s, s);
      canvas.drawPath(template, paint);
      canvas.restore();
      return;
    }

    final Path path = Path();
    const int points = 4;
    const double step = math.pi / points;
    final double innerRadius = radius * 0.35;

    for (int i = 0; i < points * 2; i++) {
      final double r = i.isEven ? radius : innerRadius;
      final double angle = i * step;
      final double x = r * math.cos(angle);
      final double y = r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, double radius, Paint paint) {
    final Path? template = ComebackParticleBurst._cachedDiamondPath;
    if (template != null) {
      canvas.save();
      final double s = radius / 10.0;
      canvas.scale(s, s);
      canvas.drawPath(template, paint);
      canvas.restore();
      return;
    }

    final Path path = Path()
      ..moveTo(0, -radius)
      ..lineTo(radius * 0.65, 0)
      ..lineTo(0, radius)
      ..lineTo(-radius * 0.65, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ComebackParticlePainter oldDelegate) => true;
}

