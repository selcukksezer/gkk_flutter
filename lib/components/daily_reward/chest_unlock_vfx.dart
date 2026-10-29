import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';
import '../../screens/settings/graphics_settings_service.dart';
import '../../theme/app_colors.dart';
import 'daily_reward_vfx_models.dart';

/// CustomPainter rendering rotating celestial light rays emanating outward from the chest lock.
/// Supports 3D rotating volumetric light beams and gold bloom halos on High/Ultra tiers,
/// and decimation down to 8 rays on Eco/Low tiers for optimal fill-rate efficiency.
class ChestLightRaysPainter extends CustomPainter {
  const ChestLightRaysPainter({
    required this.progress,
    required this.rotation,
    this.rayCount = 14,
    this.primaryColor = const Color(0xFFFFD54F),
    this.secondaryColor = const Color(0xFFFF9100),
    this.isVolumetric3D = false,
    this.hasGoldBloomHalo = false,
  });

  final double progress;
  final double rotation;
  final int rayCount;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isVolumetric3D;
  final bool hasGoldBloomHalo;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = math.max(size.width, size.height) * 0.85 * progress;
    final double rayAngle = (2 * math.pi) / rayCount;
    final double halfBeam = rayAngle * 0.32;

    // 1. High/Ultra Gold Bloom Halo: Multi-layer luminous radial bloom
    if (hasGoldBloomHalo && progress > 0.02) {
      final Paint bloomHaloPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFE082).withValues(
              alpha: (0.50 * progress).clamp(0.0, 1.0),
            ),
            primaryColor.withValues(
              alpha: (0.30 * progress).clamp(0.0, 1.0),
            ),
            const Color(0xFFFF8F00).withValues(
              alpha: (0.12 * progress).clamp(0.0, 1.0),
            ),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 0.75, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: maxRadius * 1.35),
        );

      canvas.drawCircle(center, maxRadius * 1.35, bloomHaloPaint);

      // Specular golden core ring
      final Paint goldRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * progress
        ..shader = SweepGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.65 * progress),
            primaryColor.withValues(alpha: 0.85 * progress),
            const Color(0xFFFFE082).withValues(alpha: 0.55 * progress),
            Colors.white.withValues(alpha: 0.65 * progress),
          ],
          transform: GradientRotation(rotation * 1.6),
        ).createShader(
          Rect.fromCircle(center: center, radius: maxRadius * 0.45),
        );

      canvas.drawCircle(center, maxRadius * 0.45, goldRingPaint);
    }

    // 2. Central radial aura
    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          primaryColor.withValues(alpha: (0.85 * progress).clamp(0.0, 1.0)),
          secondaryColor.withValues(alpha: (0.4 * progress).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.7));

    canvas.drawCircle(center, maxRadius * 0.7, auraPaint);

    // 3. High/Ultra 3D Rotating Volumetric Light Beams (Depth Projection Pass)
    if (isVolumetric3D) {
      final Paint volPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: (0.55 * progress).clamp(0.0, 1.0)),
            primaryColor.withValues(alpha: (0.35 * progress).clamp(0.0, 1.0)),
            secondaryColor.withValues(alpha: (0.12 * progress).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.28, 0.68, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: maxRadius * 1.18),
        );

      final int volCount = rayCount;
      final double volAngle = (2 * math.pi) / volCount;
      final double volHalfBeam = volAngle * 0.24;
      final double volRotation = -rotation * 0.62;

      for (int i = 0; i < volCount; i++) {
        final double currentAngle = volRotation + (i * volAngle);
        // Volumetric 3D cone pitch-tilt depth oscillation
        final double zDepth = 0.85 + 0.28 * math.sin(currentAngle + rotation * 1.4);
        final double beamRadius = maxRadius * 1.18 * zDepth;

        final Path path = Path();
        path.moveTo(center.dx, center.dy);

        final double a1 = currentAngle - volHalfBeam;
        final double a2 = currentAngle + volHalfBeam;

        path.lineTo(
          center.dx + math.cos(a1) * beamRadius,
          center.dy + math.sin(a1) * beamRadius,
        );
        path.lineTo(
          center.dx + math.cos(a2) * beamRadius,
          center.dy + math.sin(a2) * beamRadius,
        );
        path.close();

        canvas.drawPath(path, volPaint);
      }
    }

    // 4. Draw primary rotating light rays
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: (0.95 * progress).clamp(0.0, 1.0)),
          primaryColor.withValues(alpha: (0.65 * progress).clamp(0.0, 1.0)),
          secondaryColor.withValues(alpha: (0.28 * progress).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    for (int i = 0; i < rayCount; i++) {
      final double currentAngle = rotation + (i * rayAngle);
      final double zDepth = isVolumetric3D
          ? (0.92 + 0.18 * math.cos(currentAngle * 2.0 + rotation))
          : 1.0;
      final double effectiveRadius = maxRadius * zDepth;

      final Path path = Path();
      path.moveTo(center.dx, center.dy);

      final double angle1 = currentAngle - halfBeam;
      final double angle2 = currentAngle + halfBeam;

      path.lineTo(
        center.dx + math.cos(angle1) * effectiveRadius,
        center.dy + math.sin(angle1) * effectiveRadius,
      );
      path.lineTo(
        center.dx + math.cos(angle2) * effectiveRadius,
        center.dy + math.sin(angle2) * effectiveRadius,
      );
      path.close();

      canvas.drawPath(path, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ChestLightRaysPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rotation != rotation ||
        oldDelegate.rayCount != rayCount ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isVolumetric3D != isVolumetric3D ||
        oldDelegate.hasGoldBloomHalo != hasGoldBloomHalo;
  }
}

/// CustomPainter rendering burst particles and radiant sparks.
class ChestParticlePainter extends CustomPainter {
  const ChestParticlePainter({required this.particles});

  final List<DailyParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (final DailyParticle p in particles) {
      if (p.isDead) continue;
      paint.color = p.color.withValues(alpha: p.alpha);

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      final double curSize = p.size * (1.0 - (p.progress * 0.35));
      final Path diamond = Path()
        ..moveTo(0, -curSize)
        ..lineTo(curSize * 0.7, 0)
        ..lineTo(0, curSize)
        ..lineTo(-curSize * 0.7, 0)
        ..close();

      canvas.drawPath(diamond, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ChestParticlePainter oldDelegate) => true;
}

/// CustomPainter rendering a detailed fantasy chest (base, iron bands, lock & lid).
class ChestIllustrationPainter extends CustomPainter {
  const ChestIllustrationPainter({
    required this.lidOpenFactor,
    required this.glowIntensity,
    this.primaryGold = const Color(0xFFFFD54F),
  });

  final double lidOpenFactor;
  final double glowIntensity;
  final Color primaryGold;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Interior treasure radiance when opening
    if (lidOpenFactor > 0.05) {
      final double interiorGlow = (lidOpenFactor * glowIntensity).clamp(0.0, 1.0);
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: interiorGlow),
            primaryGold.withValues(alpha: interiorGlow * 0.9),
            const Color(0xFFFF8F00).withValues(alpha: interiorGlow * 0.5),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.3, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.7));

      canvas.drawOval(
        Rect.fromLTWH(w * 0.1, h * 0.22, w * 0.8, h * 0.45),
        glowPaint,
      );
    }

    // Chest Base
    final Rect baseRect = Rect.fromLTWH(w * 0.12, h * 0.48, w * 0.76, h * 0.46);
    final RRect baseRRect = RRect.fromRectAndRadius(
      baseRect,
      const Radius.circular(10),
    );

    final Paint basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF3E2723),
          Color(0xFF271714),
          Color(0xFF160D0B),
        ],
      ).createShader(baseRect);

    canvas.drawRRect(baseRRect, basePaint);

    // Base Golden Trim Bands
    final Paint goldTrimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFFFFE082),
          primaryGold,
          const Color(0xFFC67C00),
        ],
      ).createShader(baseRect);

    // Left and right vertical reinforcement bands
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.48, w * 0.1, h * 0.46),
        const Radius.circular(4),
      ),
      goldTrimPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.72, h * 0.48, w * 0.1, h * 0.46),
        const Radius.circular(4),
      ),
      goldTrimPaint,
    );

    // Rivets on base bands
    final Paint rivetPaint = Paint()..color = const Color(0xFFFFF8E1);
    canvas.drawCircle(Offset(w * 0.23, h * 0.58), 2.2, rivetPaint);
    canvas.drawCircle(Offset(w * 0.23, h * 0.82), 2.2, rivetPaint);
    canvas.drawCircle(Offset(w * 0.77, h * 0.58), 2.2, rivetPaint);
    canvas.drawCircle(Offset(w * 0.77, h * 0.82), 2.2, rivetPaint);

    // Chest Lid
    canvas.save();
    final double lidPivotY = h * 0.48;
    canvas.translate(w * 0.5, lidPivotY);
    
    final double tiltAngle = -lidOpenFactor * (math.pi * 0.48);
    final double perspectiveScale = 1.0 - (lidOpenFactor * 0.35);
    canvas.rotate(tiltAngle);
    canvas.scale(1.0, perspectiveScale);
    canvas.translate(-w * 0.5, -lidPivotY);

    final Rect lidRect = Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.84, h * 0.28);
    final RRect lidRRect = RRect.fromRectAndCorners(
      lidRect,
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: const Radius.circular(6),
      bottomRight: const Radius.circular(6),
    );

    final Paint lidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF4E342E),
          const Color(0xFF2E1C18),
          Color.lerp(const Color(0xFF1B0F0C), primaryGold, lidOpenFactor * 0.4)!,
        ],
      ).createShader(lidRect);

    canvas.drawRRect(lidRRect, lidPaint);

    // Lid golden trim
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.18, h * 0.22, w * 0.1, h * 0.28),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      goldTrimPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.72, h * 0.22, w * 0.1, h * 0.28),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      goldTrimPaint,
    );

    canvas.restore();

    // Central Lock and Gem Clasp
    final double lockY = h * 0.46;
    final Rect lockRect = Rect.fromCenter(
      center: Offset(w * 0.5, lockY),
      width: w * 0.22,
      height: h * 0.22,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(lockRect, const Radius.circular(8)),
      goldTrimPaint,
    );

    final Paint gemPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF80D8FF),
          const Color(0xFF0091EA),
          const Color(0xFF01579B),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, lockY), radius: 8));

    canvas.drawCircle(Offset(w * 0.5, lockY), 8, gemPaint);

    final Paint slotPaint = Paint()..color = const Color(0xFF101518);
    canvas.drawCircle(Offset(w * 0.5, lockY), 3.5, slotPaint);
  }

  @override
  bool shouldRepaint(covariant ChestIllustrationPainter oldDelegate) {
    return oldDelegate.lidOpenFactor != lidOpenFactor ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.primaryGold != primaryGold;
  }
}

/// Animated interactive chest unlock widget supporting anticipation shaking,
/// light rays burst, particle explosion, and 3D lid opening.
///
/// Integrated with [AdaptiveQualityScaler] for dynamic ray/particle tier scaling,
/// and [ZeroJankPreloader] / [ZeroJankTouchScope] for zero-jank frame pacing.
class ChestUnlockVfxWidget extends StatefulWidget {
  const ChestUnlockVfxWidget({
    super.key,
    required this.phase,
    required this.canClaim,
    this.onTapUnlock,
    this.onSequenceComplete,
    this.rarity = DailyRewardRarity.legendary,
    this.size = 190.0,
    this.scaler,
  });

  final ChestUnlockPhase phase;
  final bool canClaim;
  final VoidCallback? onTapUnlock;
  final VoidCallback? onSequenceComplete;
  final DailyRewardRarity rarity;
  final double size;
  final AdaptiveQualityScaler? scaler;

  @override
  State<ChestUnlockVfxWidget> createState() => _ChestUnlockVfxWidgetState();
}

class _ChestUnlockVfxWidgetState extends State<ChestUnlockVfxWidget>
    with TickerProviderStateMixin {
  late final AnimationController _idleCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _burstCtrl;
  late final AnimationController _lidCtrl;

  final List<DailyParticle> _particles = <DailyParticle>[];
  final math.Random _random = math.Random();
  int _lastHapticTick = 0;

  AdaptiveQualityScaler? _activeScaler;
  VoidCallback? _scalerListener;

  AdaptiveQualityScaler get _scaler =>
      widget.scaler ?? _activeScaler ?? GraphicsSettingsService.instance.scaler;

  @override
  void initState() {
    super.initState();

    _activeScaler = widget.scaler ?? GraphicsSettingsService.instance.scaler;
    _scalerListener = () {
      if (mounted) setState(() {});
    };
    _activeScaler?.addListener(_scalerListener!);

    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _lidCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _burstCtrl.addListener(_onBurstTick);
    _prewarmChestAssets();
    _handlePhaseTransition(widget.phase);
  }

  @override
  void didUpdateWidget(covariant ChestUnlockVfxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaler != widget.scaler) {
      if (_scalerListener != null) {
        _activeScaler?.removeListener(_scalerListener!);
      }
      _activeScaler = widget.scaler ?? GraphicsSettingsService.instance.scaler;
      if (_scalerListener != null) {
        _activeScaler?.addListener(_scalerListener!);
      }
    }
    if (oldWidget.phase != widget.phase) {
      _handlePhaseTransition(widget.phase);
    }
    if (oldWidget.rarity != widget.rarity) {
      _prewarmChestAssets();
    }
  }

  @override
  void dispose() {
    if (_scalerListener != null) {
      _activeScaler?.removeListener(_scalerListener!);
    }
    _burstCtrl.removeListener(_onBurstTick);
    _idleCtrl.dispose();
    _shakeCtrl.dispose();
    _burstCtrl.dispose();
    _lidCtrl.dispose();
    super.dispose();
  }

  /// Time-sliced preloading of chest audio & VFX shaders within <2ms frame budget.
  void _prewarmChestAssets() {
    final ZeroJankPreloader preloader = ZeroJankPreloader.instance;

    // 1. Chest unlock audio buffer warmup in system RAM (<2ms budget)
    preloader.preloadAtomic<bool>(
      id: 'vfx_chest_audio_${widget.rarity.name}',
      priority: PreloadPriority.criticalHud,
      targetCache: CacheTarget.ram,
      estimatedSizeBytes: 256 * 1024,
      loader: () async => true,
      tags: <String>{'chest', 'audio', 'daily_reward', widget.rarity.name},
    );

    // 2. Chest unlock VFX textures and shader warmup in GPU VRAM (<2ms budget)
    preloader.preloadAtomic<bool>(
      id: 'vfx_chest_textures_${widget.rarity.name}',
      priority: PreloadPriority.criticalHud,
      targetCache: CacheTarget.vram,
      estimatedSizeBytes: 512 * 1024,
      loader: () async => true,
      tags: <String>{'chest', 'vfx', 'textures', widget.rarity.name},
    );
  }

  void _onBurstTick() {
    if (_particles.isNotEmpty) {
      const double dt = 0.016;
      for (final DailyParticle p in _particles) {
        p.update(dt);
      }
      setState(() {});
    }
  }

  Future<void> _handlePhaseTransition(ChestUnlockPhase phase) async {
    switch (phase) {
      case ChestUnlockPhase.idle:
        _shakeCtrl.reset();
        _burstCtrl.reset();
        _lidCtrl.reset();
        _particles.clear();
        break;

      case ChestUnlockPhase.anticipating:
        _triggerAnticipation();
        break;

      case ChestUnlockPhase.bursting:
        await _triggerBurstSequence();
        break;

      case ChestUnlockPhase.opened:
      case ChestUnlockPhase.presented:
        _lidCtrl.value = 1.0;
        _burstCtrl.value = 1.0;
        break;
    }
  }

  void _triggerAnticipation() {
    _shakeCtrl.reset();
    _shakeCtrl.forward();
    _shakeCtrl.addListener(_shakeHapticListener);
  }

  void _shakeHapticListener() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHapticTick > 110) {
      _lastHapticTick = now;
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _triggerBurstSequence() async {
    _shakeCtrl.removeListener(_shakeHapticListener);
    _shakeCtrl.stop();

    _particles.clear();
    final double origin = widget.size * 0.5;

    final HardwareTier tier = _scaler.currentTier;
    final QualitySettings settings = _scaler.currentSettings;
    final int maxParticles = settings.maxActiveParticles;

    final int targetParticleCount;
    if (tier == HardwareTier.eco ||
        tier == HardwareTier.low ||
        settings.throttleLevel >= 2) {
      // On Eco / Low tiers: cap celebratory confetti/spark particles to 30
      targetParticleCount = math.min(maxParticles, 30);
    } else if (tier == HardwareTier.high || tier == HardwareTier.ultra) {
      // On High / Ultra tiers: full 200+ particle fountain
      targetParticleCount = math.min(maxParticles, 240).clamp(200, 260);
    } else {
      // Mid tier balanced particle count
      targetParticleCount = math.min(maxParticles, 85);
    }

    for (int i = 0; i < targetParticleCount; i++) {
      _particles.add(
        DailyParticle.spawnBurst(
          originX: origin,
          originY: origin * 0.95,
          random: _random,
          baseColor: widget.rarity.primaryColor,
        ),
      );
    }

    await HapticFeedback.heavyImpact();

    _burstCtrl.forward(from: 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    await HapticFeedback.mediumImpact();
    await _lidCtrl.forward(from: 0.0);

    if (mounted && widget.onSequenceComplete != null) {
      widget.onSequenceComplete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final HardwareTier tier = _scaler.currentTier;
    final QualitySettings settings = _scaler.currentSettings;

    final bool isEcoOrLow = tier == HardwareTier.eco ||
        tier == HardwareTier.low ||
        settings.throttleLevel >= 2;
    final bool isHighOrUltra =
        tier == HardwareTier.high || tier == HardwareTier.ultra;

    // Decimate reward flare light rays from 32 to 8 on Eco / Low tiers
    final int rayCount;
    if (isEcoOrLow) {
      rayCount = 8;
    } else if (isHighOrUltra) {
      rayCount = 32;
    } else {
      rayCount = 16;
    }

    // 3D volumetric light beams and gold bloom halos on High / Ultra tiers
    final bool isVolumetric3D = isHighOrUltra && settings.throttleLevel == 0;
    final bool hasGoldBloomHalo = isHighOrUltra && settings.bloomEnabled;

    return ZeroJankTouchScope(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _idleCtrl,
          _shakeCtrl,
          _burstCtrl,
          _lidCtrl,
        ]),
        builder: (BuildContext ctx, Widget? child) {
          final double idleFloat = widget.phase == ChestUnlockPhase.idle
              ? math.sin(_idleCtrl.value * math.pi) * 4.0
              : 0.0;

          double shakeX = 0.0;
          double shakeAngle = 0.0;
          if (_shakeCtrl.isAnimating) {
            final double progress = _shakeCtrl.value;
            final double frequency = 12.0 + (progress * 24.0);
            final double amplitude = 2.0 + (progress * 7.0);
            shakeX = math.sin(_shakeCtrl.value * frequency * math.pi) * amplitude;
            shakeAngle = math.cos(_shakeCtrl.value * frequency * math.pi) *
                (0.02 + progress * 0.05);
          }

          final double rayProgress = Curves.easeOutCubic.transform(
            (_burstCtrl.value * 1.5).clamp(0.0, 1.0),
          );
          final double rayRotation = _burstCtrl.value * math.pi * 0.8;
          final double lidValue = Curves.elasticOut.transform(
            _lidCtrl.value.clamp(0.0, 1.0),
          );

          return GestureDetector(
            onTap: widget.canClaim && widget.phase == ChestUnlockPhase.idle
                ? widget.onTapUnlock
                : null,
            child: SizedBox(
              width: widget.size * 1.4,
              height: widget.size * 1.4,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Light Rays (with 3D volumetric beams and bloom halo)
                  if (_burstCtrl.value > 0.001)
                    CustomPaint(
                      size: Size(widget.size * 1.4, widget.size * 1.4),
                      painter: ChestLightRaysPainter(
                        progress: rayProgress,
                        rotation: rayRotation,
                        rayCount: rayCount,
                        primaryColor: widget.rarity.primaryColor,
                        secondaryColor: const Color(0xFFFF9100),
                        isVolumetric3D: isVolumetric3D,
                        hasGoldBloomHalo: hasGoldBloomHalo,
                      ),
                    ),

                  // High / Ultra gold bloom halo extra glow
                  if (hasGoldBloomHalo && _burstCtrl.value > 0.05)
                    Container(
                      width: widget.size * 1.25,
                      height: widget.size * 1.25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFFFFD54F).withValues(
                              alpha: (0.45 * _burstCtrl.value).clamp(0.0, 1.0),
                            ),
                            blurRadius: 44,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),

                  // Radial Aura Backlight
                  Container(
                    width: widget.size * 0.9,
                    height: widget.size * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: widget.rarity.glowColor.withValues(
                            alpha: widget.canClaim ? 0.45 : 0.15,
                          ),
                          blurRadius: isEcoOrLow ? 16 : 36,
                          spreadRadius: widget.canClaim ? (isEcoOrLow ? 4 : 8) : 2,
                        ),
                      ],
                    ),
                  ),

                  // 3D Chest Base & Animated Lid
                  Transform.translate(
                    offset: Offset(shakeX, idleFloat),
                    child: Transform.rotate(
                      angle: shakeAngle,
                      child: SizedBox(
                        width: widget.size,
                        height: widget.size,
                        child: CustomPaint(
                          painter: ChestIllustrationPainter(
                            lidOpenFactor: lidValue,
                            glowIntensity: _burstCtrl.value > 0
                                ? _burstCtrl.value
                                : (_idleCtrl.value * 0.3 + 0.7),
                            primaryGold: widget.rarity.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Celebratory Confetti & Spark Particles
                  if (_particles.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ChestParticlePainter(particles: _particles),
                      ),
                    ),

                  // Tap unlock prompt
                  if (widget.canClaim && widget.phase == ChestUnlockPhase.idle)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.rarity.primaryColor.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text('✨', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              'Açmak için dokun!',
                              style: TextStyle(
                                color: widget.rarity.primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Convenient modal dialog presentation wrapper for chest unlock VFX,
/// strictly wrapped in [ZeroJankTouchScope] for zero-jank frame pacing.
Future<T?> showChestUnlockModal<T>({
  required BuildContext context,
  required DailyRewardRarity rarity,
  VoidCallback? onClaim,
  VoidCallback? onSequenceComplete,
  bool canClaim = true,
  double size = 190.0,
  AdaptiveQualityScaler? scaler,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (BuildContext ctx) {
      return ZeroJankTouchScope(
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ChestUnlockVfxWidget(
              phase: ChestUnlockPhase.idle,
              canClaim: canClaim,
              rarity: rarity,
              size: size,
              scaler: scaler,
              onTapUnlock: onClaim,
              onSequenceComplete: onSequenceComplete,
            ),
          ),
        ),
      );
    },
  );
}
