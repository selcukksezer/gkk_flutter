import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/common/item_icon_view.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'loot_chest_theme.dart';
import 'loot_chest_widgets.dart';
import 'loot_models.dart';
import 'loot_reel_controller.dart';

/// Clean chip displaying box drop rates, multipliers and currency cost.
Widget lootOpenInfoChip(String label, String value, LootChestTheme theme) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm + 2,
      vertical: AppSpacing.xs + 2,
    ),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
      color: AppColors.bgDeep.withValues(alpha: 0.65),
      border: Border.all(color: theme.borderColor.withValues(alpha: 0.5)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: theme.accentColor.withValues(alpha: 0.15),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ],
    ),
    child: RichText(
      text: TextSpan(
        children: <InlineSpan>[
          if (label.isNotEmpty)
            TextSpan(
              text: '$label: ',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          TextSpan(
            text: value,
            style: AppTextStyles.label.copyWith(
              color: theme.accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dynamic Volumetric God-Rays Painter for dramatic chest burst and reward celebration.
class _GodRaysPainter extends CustomPainter {
  _GodRaysPainter({
    required this.rotation,
    required this.rayColor,
    required this.intensity,
  });

  final double rotation;
  final Color rayColor;
  final double intensity;
  static const int rayCount = 20;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0.001) return;

    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double radius = math.max(size.width, size.height) * 0.95;
    final double angleStep = (2 * math.pi) / rayCount;

    final Paint rayPaint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    for (int i = 0; i < rayCount; i++) {
      final double angle = (i * angleStep) + rotation;
      final double halfWidth = angleStep * 0.32;

      final Path path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + (math.cos(angle - halfWidth) * radius),
          center.dy + (math.sin(angle - halfWidth) * radius),
        )
        ..lineTo(
          center.dx + (math.cos(angle + halfWidth) * radius),
          center.dy + (math.sin(angle + halfWidth) * radius),
        )
        ..close();

      final double rayAlpha = (0.32 * intensity).clamp(0.0, 1.0);
      rayPaint.shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: <Color>[
          rayColor.withValues(alpha: rayAlpha),
          rayColor.withValues(alpha: rayAlpha * 0.4),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawPath(path, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GodRaysPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.intensity != intensity ||
        oldDelegate.rayColor != rayColor;
  }
}

/// Runic Pedestal & Magic Circle Painter with celestial marks.
class _RunicPedestalPainter extends CustomPainter {
  _RunicPedestalPainter({
    required this.pulse,
    required this.accentColor,
  });

  final double pulse;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double maxR = math.min(size.width, size.height) / 2.0;

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accentColor.withValues(
        alpha: (0.30 + (pulse * 0.35)).clamp(0.0, 1.0),
      );

    // Outer runic ring
    canvas.drawCircle(center, maxR * 0.88, ringPaint);

    // Inner ring
    ringPaint.strokeWidth = 0.9;
    canvas.drawCircle(center, maxR * 0.65, ringPaint);

    // 8 radial celestial marks
    final double markAlpha = (0.40 + (pulse * 0.40)).clamp(0.0, 1.0);
    final Paint markPaint = Paint()
      ..color = accentColor.withValues(alpha: markAlpha)
      ..strokeWidth = 1.6;

    for (int i = 0; i < 8; i++) {
      final double a = (i * math.pi / 4.0) + (pulse * 0.25);
      final Offset p1 = Offset(
        center.dx + (math.cos(a) * maxR * 0.65),
        center.dy + (math.sin(a) * maxR * 0.65),
      );
      final Offset p2 = Offset(
        center.dx + (math.cos(a) * maxR * 0.88),
        center.dy + (math.sin(a) * maxR * 0.88),
      );
      canvas.drawLine(p1, p2, markPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RunicPedestalPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.accentColor != accentColor;
  }
}

/// Divine Piercing Light Beam Painter focused down onto the chest lock.
class _DivineBeamPainter extends CustomPainter {
  _DivineBeamPainter({
    required this.beamIntensity,
    required this.beamColor,
  });

  final double beamIntensity;
  final Color beamColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (beamIntensity <= 0.001) return;

    final Paint paint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(
            alpha: (0.80 * beamIntensity).clamp(0.0, 1.0),
          ),
          beamColor.withValues(alpha: (0.55 * beamIntensity).clamp(0.0, 1.0)),
          beamColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path path = Path()
      ..moveTo(size.width * 0.32, 0)
      ..lineTo(size.width * 0.68, 0)
      ..lineTo(size.width * 0.88, size.height)
      ..lineTo(size.width * 0.12, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DivineBeamPainter oldDelegate) {
    return oldDelegate.beamIntensity != beamIntensity ||
        oldDelegate.beamColor != beamColor;
  }
}

/// Expanding shockwave ring emitted at the exact moment of chest unlock.
class _ChestShockwaveRingPainter extends CustomPainter {
  _ChestShockwaveRingPainter({
    required this.progress,
    required this.ringColor,
  });

  final double progress;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 1.0) return;

    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double maxRadius = math.max(size.width, size.height) * 0.75;
    final double currentRadius = maxRadius * Curves.easeOutCubic.transform(progress);
    final double alpha = (1.0 - progress).clamp(0.0, 1.0);

    // Primary shockwave ring
    final Paint wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * (1.0 - progress)
      ..color = ringColor.withValues(alpha: alpha * 0.85);

    canvas.drawCircle(center, currentRadius, wavePaint);

    // Inner bright harmonic ring
    final Paint innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * (1.0 - progress)
      ..color = Colors.white.withValues(alpha: alpha * 0.95);

    canvas.drawCircle(center, currentRadius * 0.85, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _ChestShockwaveRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ringColor != ringColor;
  }
}

/// Floating ambient celestial dust motes and rising aether sparks.
class _AmbientLootParticlesPainter extends CustomPainter {
  _AmbientLootParticlesPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  static final List<_LootMote> _motes = List<_LootMote>.generate(28, (int i) {
    final math.Random rng = math.Random(i * 37 + 11);
    return _LootMote(
      xRatio: rng.nextDouble(),
      yRatio: rng.nextDouble(),
      radius: 1.2 + (rng.nextDouble() * 2.2),
      speed: 0.35 + (rng.nextDouble() * 0.65),
      driftAngle: rng.nextDouble() * 2 * math.pi,
      alpha: 0.3 + (rng.nextDouble() * 0.5),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (final _LootMote mote in _motes) {
      final double yShift = (mote.yRatio - (progress * mote.speed)) % 1.0;
      final double actualY = (yShift < 0 ? yShift + 1.0 : yShift) * size.height;
      final double actualX =
          (mote.xRatio * size.width) +
          (math.sin((progress * 2 * math.pi) + mote.driftAngle) * 14.0);

      final double fade = math.sin(yShift * math.pi).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: mote.alpha * fade);

      canvas.drawCircle(Offset(actualX, actualY), mote.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientLootParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _LootMote {
  const _LootMote({
    required this.xRatio,
    required this.yRatio,
    required this.radius,
    required this.speed,
    required this.driftAngle,
    required this.alpha,
  });

  final double xRatio;
  final double yRatio;
  final double radius;
  final double speed;
  final double driftAngle;
  final double alpha;
}

/// Blinding radial chromatic flash burst with explosive particle shards.
class _ParticleFlashPainter extends CustomPainter {
  _ParticleFlashPainter({
    required this.progress,
    required this.burstColor,
  });

  final double progress;
  final Color burstColor;

  static final List<_FlashParticle> _particles = List<_FlashParticle>.generate(
    36,
    (int i) {
      final math.Random rng = math.Random(i * 59 + 7);
      final double angle = rng.nextDouble() * 2 * math.pi;
      final double speed = 90 + (rng.nextDouble() * 160);
      return _FlashParticle(
        dx: math.cos(angle) * speed,
        dy: math.sin(angle) * speed,
        size: 1.5 + (rng.nextDouble() * 3.0),
        isSecondary: i.isEven,
      );
    },
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 1.0) return;

    final Offset center = Offset(size.width / 2.0, size.height * 0.28);
    final double alpha = (1.0 - progress).clamp(0.0, 1.0);

    // 1. Radial screen bloom
    final Paint bloomPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: <Color>[
          Colors.white.withValues(alpha: alpha * 0.95),
          burstColor.withValues(alpha: alpha * 0.65),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.85));

    canvas.drawPaint(bloomPaint);

    // 2. High-speed explosive particle shards
    final double tEase = Curves.easeOutCubic.transform(progress);
    final Paint particlePaint = Paint()..style = PaintingStyle.fill;

    for (final _FlashParticle p in _particles) {
      final Offset currentPos = Offset(
        center.dx + (p.dx * tEase),
        center.dy + (p.dy * tEase),
      );
      final Color pColor = p.isSecondary ? burstColor : Colors.white;
      particlePaint.color = pColor.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(currentPos, p.size * (1.0 - (progress * 0.5)), particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFlashPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.burstColor != burstColor;
  }
}

class _FlashParticle {
  const _FlashParticle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.isSecondary,
  });

  final double dx;
  final double dy;
  final double size;
  final bool isSecondary;
}

/// Holographic chromatic foil shimmer sweep over revealed collectible cards.
class _HolographicCardShimmerPainter extends CustomPainter {
  const _HolographicCardShimmerPainter({
    required this.progress,
    required this.accentColor,
  });

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double diagonal = math.sqrt(
      (size.width * size.width) + (size.height * size.height),
    );
    final double sweepOffset = ((progress * 2.4) - 0.7) * diagonal;

    final Paint shimmerPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        transform: const GradientRotation(math.pi / 4),
        colors: <Color>[
          Colors.transparent,
          accentColor.withValues(alpha: 0.08),
          AppColors.accentCyan.withValues(alpha: 0.30),
          AppColors.gold.withValues(alpha: 0.40),
          AppColors.accentPurple.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.50),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.2, 0.4, 0.5, 0.6, 0.75, 1.0],
      ).createShader(
        Rect.fromLTWH(sweepOffset - 80, sweepOffset - 80, 160, 160),
      );

    canvas.drawRect(Offset.zero & size, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _HolographicCardShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
  }
}

/// Dissolution particle aura surrounding cards undergoing duplicate essence conversion.
class _DuplicateDissolvePainter extends CustomPainter {
  _DuplicateDissolvePainter({
    required this.progress,
    required this.accentColor,
  });

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 1.0) return;

    final Paint paint = Paint()..style = PaintingStyle.fill;
    final double alpha = (1.0 - progress).clamp(0.0, 1.0);
    final math.Random rng = math.Random(1337);

    for (int i = 0; i < 24; i++) {
      final double startX = rng.nextDouble() * size.width;
      final double startY = rng.nextDouble() * size.height;
      final double lift = progress * 40.0 * (0.6 + (rng.nextDouble() * 0.8));
      final double currentY = startY - lift;
      final double radius = 1.0 + (rng.nextDouble() * 2.4);

      paint.color = i.isEven
          ? accentColor.withValues(alpha: alpha * 0.85)
          : AppColors.liquidGold.withValues(alpha: alpha * 0.95);

      canvas.drawCircle(Offset(startX, currentY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DuplicateDissolvePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
  }
}

class LootBoxOpenPage extends StatefulWidget {
  const LootBoxOpenPage({
    super.key,
    required this.box,
    required this.theme,
    required this.displayName,
    required this.drops,
    required this.targetIndex,
    required this.resultPayload,
    this.multiRewards,
  });

  final LootBoxView box;
  final LootChestTheme theme;
  final String displayName;
  final List<LootDropView> drops;
  final int targetIndex;
  final Map<String, dynamic> resultPayload;
  final List<Map<String, dynamic>>? multiRewards;

  @override
  State<LootBoxOpenPage> createState() => _LootBoxOpenPageState();
}

class _LootBoxOpenPageState extends State<LootBoxOpenPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const double _itemWidth = 142;
  static const double _itemGap = 12;

  // Primary Reel Spin Controller
  late final AnimationController _reelController;
  late final LootReelController _reel;

  // Cinematic Chest Suspense, Light Beam & Particle Controllers
  late final AnimationController _suspenseController;
  late final AnimationController _shockwaveController;
  late final AnimationController _godRaysController;
  late final AnimationController _ambientController;
  late final AnimationController _flashController;
  late final AnimationController _revealController;
  late final AnimationController _duplicateConvertController;
  late final AnimationController _shimmerController;

  bool _chestBurst = false;
  bool _finished = false;
  bool _cardRevealed = false;
  bool _hasTriggeredRarityFanfare = false;
  int _lastTickItem = -1;
  bool _duplicateConverted = false;
  bool _previewDuplicate = false;

  // Track multi-reward revealed indices
  final Set<int> _revealedMultiIndices = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _reel = LootReelController(
      source: widget.drops,
      targetIndex: widget.targetIndex,
    );

    // Continuous god-rays rotating loop
    _godRaysController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    // Floating ambient dust motes loop
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Chest anticipation suspense & lock vibration
    _suspenseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Expanding shockwave on lock crack
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Opening explosive particle flash
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // 3D Card Flip and Reveal sequence
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Duplicate essence conversion sequence
    _duplicateConvertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Holographic card sheen sweep loop
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // Reel spin controller
    _reelController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _reel.totalSpinMs),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) {
          _onReelSpinCompleted();
        }
      });

    // Start cinematic sequence
    _playCinematicSequence();
  }

  Future<void> _playCinematicSequence() async {
    // 1. Suspense build-up: chest vibrates, divine light descends onto lock
    _suspenseController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;

    // 2. Lock bursts open! Shockwave, particle flash, and haptic impact
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);

    _shockwaveController.forward(from: 0.0);
    _flashController.forward(from: 0.0);
    setState(() => _chestBurst = true);

    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    // 3. Launch physics reel spin
    _reelController.forward();
  }

  void _onReelSpinCompleted() {
    setState(() => _finished = true);

    final Map<String, dynamic> reward = _extractSingleReward();
    final String rarity = reward['rarity']?.toString().toLowerCase() ?? 'common';

    // Trigger rarity fanfare and haptics
    _triggerRarityCelebration(rarity);

    // Begin dramatic 3D Card flip reveal
    _revealController.forward(from: 0.0);

    // At 450ms into the flip (face-up transition), trigger second tactile confirm
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() => _cardRevealed = true);
        HapticFeedback.mediumImpact();
      }
    });

    // If reward is duplicate, orchestrate duplicate conversion sequence
    if (_isDuplicateReward(reward) || _previewDuplicate) {
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) {
          _duplicateConvertController.forward(from: 0.0);
          HapticFeedback.mediumImpact();
          setState(() => _duplicateConverted = true);
        }
      });
    }

    // If multi-rewards exist, trigger staggered cascade flip
    if (widget.multiRewards != null && widget.multiRewards!.isNotEmpty) {
      _startMultiRewardCascade();
    }
  }

  void _startMultiRewardCascade() {
    final int count = widget.multiRewards!.length;
    for (int i = 0; i < count; i++) {
      Future<void>.delayed(Duration(milliseconds: 350 + (i * 90)), () {
        if (mounted) {
          setState(() => _revealedMultiIndices.add(i));
          HapticFeedback.selectionClick();
        }
      });
    }
  }

  Future<void> _triggerRarityCelebration(String rarity) async {
    if (_hasTriggeredRarityFanfare) return;
    _hasTriggeredRarityFanfare = true;

    try {
      final LootChestTier tier = widget.theme.tier;
      // Trigger companion audio/haptic chime
      await LootRarityChime.trigger(context, tier);

      // Deep tactile scaling based on rolled item tier
      switch (rarity) {
        case 'mythic':
        case 'eternal':
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.vibrate();
        case 'legendary':
        case 'fabled':
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          await HapticFeedback.heavyImpact();
        case 'epic':
        case 'heroic':
          await HapticFeedback.heavyImpact();
        case 'rare':
          await HapticFeedback.mediumImpact();
        default:
          await HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  void _checkHapticTick(int currentItemIndex) {
    if (currentItemIndex != _lastTickItem) {
      _lastTickItem = currentItemIndex;

      // Card passing haptic click
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);

      // Check if item crossing center is a suspenseful legendary/mythic
      if (currentItemIndex >= 0 && currentItemIndex < _reel.items.length) {
        final String rarity = _reel.items[currentItemIndex].rarity.toLowerCase();
        if (rarity == 'legendary' || rarity == 'mythic') {
          HapticFeedback.mediumImpact();
        }
      }
    }
  }

  Map<String, dynamic> _extractSingleReward() {
    if (widget.resultPayload['reward'] is Map) {
      return Map<String, dynamic>.from(widget.resultPayload['reward'] as Map);
    }
    return <String, dynamic>{};
  }

  bool _isDuplicateReward(Map<String, dynamic> reward) {
    if (_previewDuplicate) return true;
    if (reward['is_duplicate'] == true) return true;
    if (reward['duplicate'] == true) return true;
    if (reward['is_converted'] == true) return true;
    if (reward['duplicate_converted'] == true) return true;
    if (reward['converted_gold'] != null && lootToInt(reward['converted_gold']) > 0) {
      return true;
    }
    if (reward['converted_shards'] != null &&
        lootToInt(reward['converted_shards']) > 0) {
      return true;
    }
    return false;
  }

  int _calculateConvertedGold(Map<String, dynamic> reward, String rarity) {
    final int explicit = lootToInt(
      reward['converted_gold'],
      fallback: lootToInt(reward['duplicate_gold']),
    );
    if (explicit > 0) return explicit;
    return switch (rarity.toLowerCase()) {
      'mythic' => 50000,
      'legendary' => 20000,
      'epic' => 8000,
      'rare' => 2500,
      'uncommon' => 800,
      _ => 300,
    };
  }

  int _calculateConvertedShards(Map<String, dynamic> reward, String rarity) {
    final int explicit = lootToInt(
      reward['converted_shards'],
      fallback: lootToInt(reward['shards']),
    );
    if (explicit > 0) return explicit;
    return switch (rarity.toLowerCase()) {
      'mythic' => 100,
      'legendary' => 45,
      'epic' => 18,
      'rare' => 6,
      'uncommon' => 2,
      _ => 1,
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finished) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (_reelController.isAnimating) {
          _reelController.stop(canceled: false);
        }
      case AppLifecycleState.resumed:
        if (_reelController.value >= 1.0) {
          if (!_finished) _onReelSpinCompleted();
        } else if (_chestBurst && !_reelController.isAnimating) {
          _reelController.forward();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reelController.dispose();
    _suspenseController.dispose();
    _shockwaveController.dispose();
    _godRaysController.dispose();
    _ambientController.dispose();
    _flashController.dispose();
    _revealController.dispose();
    _duplicateConvertController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, dynamic> reward = _extractSingleReward();

    final String resultName = reward['name']?.toString() ?? l10n.loot_odul;
    final String resultItemId = reward['item_id']?.toString() ?? '';
    final int qty = lootToInt(
      reward['quantity'],
      fallback: lootToInt(reward['amount'], fallback: 1),
    );

    final LootChestTheme theme = widget.theme;

    return Scaffold(
      backgroundColor: theme.fullscreenBgEnd,
      body: Stack(
        children: <Widget>[
          // 1. Background atmospheric gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    theme.fullscreenBgStart,
                    theme.fullscreenBgEnd,
                  ],
                ),
              ),
            ),
          ),

          // 2. Ambient celestial dust motes layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (BuildContext context, _) {
                return CustomPaint(
                  painter: _AmbientLootParticlesPainter(
                    progress: _ambientController.value,
                    color: theme.accentColor,
                  ),
                );
              },
            ),
          ),

          // 3. Volumetric God-Rays layer (flares during chest opening & reward celebration)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _godRaysController,
                _suspenseController,
                _reelController,
                _revealController,
              ]),
              builder: (BuildContext context, _) {
                final double burstFactor = _finished
                    ? (0.75 + (_revealController.value * 0.25))
                    : (_chestBurst ? 0.68 : (_suspenseController.value * 0.42));
                return CustomPaint(
                  painter: _GodRaysPainter(
                    rotation: _godRaysController.value * 2 * math.pi,
                    rayColor: theme.accentColor,
                    intensity: burstFactor,
                  ),
                );
              },
            ),
          ),

          // 4. Main Interactive Cinematic Content
          SafeArea(
            child: Column(
              children: <Widget>[
                // Header Navigation & Status Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.sm + 2,
                    AppSpacing.sm + 2,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.displayName,
                              style: AppTextStyles.h1.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs - 1),
                            Text(
                              _finished
                                  ? l10n.loot_open_finished_subtitle
                                  : (_chestBurst
                                      ? l10n.loot_open_spinning_subtitle
                                      : 'Kasa açılıyor, nefesler tutuldu...'),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _finished
                            ? () => Navigator.of(context).pop()
                            : null,
                        icon: const Icon(Icons.close),
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),

                // 3D Chest Showcase with Divine Light Beam, Lock Shudder & Shockwave
                SizedBox(
                  height: 164,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Ethereal Runic Pedestal
                      Positioned(
                        bottom: 4,
                        child: SizedBox(
                          width: 230,
                          height: 64,
                          child: AnimatedBuilder(
                            animation: _suspenseController,
                            builder: (BuildContext context, _) {
                              return CustomPaint(
                                painter: _RunicPedestalPainter(
                                  pulse: _suspenseController.value,
                                  accentColor: theme.accentColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Piercing Divine Light Beam (descends onto the chest lock)
                      Positioned(
                        top: 0,
                        bottom: 22,
                        child: SizedBox(
                          width: 96,
                          child: AnimatedBuilder(
                            animation: _suspenseController,
                            builder: (BuildContext context, _) {
                              final double beamProg = _finished
                                  ? 0.35
                                  : (_chestBurst
                                      ? 1.0
                                      : _suspenseController.value);
                              return CustomPaint(
                                painter: _DivineBeamPainter(
                                  beamIntensity: beamProg,
                                  beamColor: theme.accentColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Lock Burst Shockwave Ring
                      Positioned(
                        child: SizedBox(
                          width: 220,
                          height: 160,
                          child: AnimatedBuilder(
                            animation: _shockwaveController,
                            builder: (BuildContext context, _) {
                              return CustomPaint(
                                painter: _ChestShockwaveRingPainter(
                                  progress: _shockwaveController.value,
                                  ringColor: theme.accentColor,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // 3D Chest with Suspense Shudder & Perspective Recoil
                      AnimatedBuilder(
                        animation: Listenable.merge(<Listenable>[
                          _suspenseController,
                          _reelController,
                          _shockwaveController,
                        ]),
                        builder: (BuildContext context, Widget? child) {
                          double vibeX = 0.0;
                          double vibeY = 0.0;
                          double scale = 1.0;

                          if (!_chestBurst) {
                            final double s = _suspenseController.value;
                            vibeX = math.sin(s * math.pi * 26.0) * (s * 4.0);
                            vibeY = math.cos(s * math.pi * 18.0) * (s * 2.0);
                            scale = 1.0 + (s * 0.09);
                          } else if (!_finished) {
                            // Upward recoil jump transitioning to levitation
                            final double jumpProg = _shockwaveController.value;
                            final double recoil = math.sin(jumpProg * math.pi) * 12.0;

                            final double shudder = _reel.anticipationShudderOffset(
                              _reelController.value,
                            );
                            vibeX = shudder;
                            vibeY = -recoil + (math.sin(_reelController.value * 24.0) * 2.5);
                            scale = 1.05;
                          } else {
                            // Finished celebratory hover
                            vibeY = math.sin(_godRaysController.value * 2 * math.pi) * 3.5;
                            scale = 1.09;
                          }

                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0018)
                              ..rotateX(-0.10)
                              ..translate(vibeX, vibeY),
                            child: Transform.scale(
                              scale: scale,
                              child: child,
                            ),
                          );
                        },
                        child: Image.asset(
                          theme.assetPath,
                          height: 142,
                          fit: BoxFit.contain,
                          errorBuilder: (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) => const SizedBox(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chest Information Chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    0,
                    AppSpacing.base,
                    AppSpacing.xs + 2,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      lootOpenInfoChip('D', '${widget.box.dropCount}', theme),
                      lootOpenInfoChip(
                        'N',
                        lootJackpotPercentLabel(widget.box.jackpotRate),
                        theme,
                      ),
                      lootOpenInfoChip(
                        '',
                        'x${widget.box.rewardMultiplier.toStringAsFixed(1)}',
                        theme,
                      ),
                      lootOpenInfoChip(
                        widget.box.currencyType == 'gems'
                            ? l10n.loot_elmas
                            : l10n.loot_altin,
                        lootCompactNum(widget.box.price),
                        theme,
                      ),
                    ],
                  ),
                ),

                // Main Stage: Cinematic Reel or Multi-Open Deck Grid
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final double viewportWidth = constraints.maxWidth - 28;
                      final double itemExtent = _itemWidth + _itemGap;
                      final double stripWidth = _reel.items.length * itemExtent;
                      final double rawTargetOffset =
                          (_reel.targetReelIndex * itemExtent) -
                          ((viewportWidth - _itemWidth) / 2);
                      final double maxOffset = math.max(
                        0,
                        (_reel.items.length * itemExtent) - viewportWidth,
                      );
                      final double targetOffset = rawTargetOffset.clamp(
                        0,
                        maxOffset,
                      );

                      final Widget reelStrip = RepaintBoundary(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: stripWidth,
                          maxWidth: stripWidth,
                          child: SizedBox(
                            width: stripWidth,
                            height: 200,
                            child: Row(
                              children: List<Widget>.generate(
                                _reel.items.length,
                                (int index) {
                                  final bool hit =
                                      index == _reel.targetReelIndex && _finished;
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      right: _itemGap,
                                    ),
                                    child: _LootReelCard(
                                      drop: _reel.items[index],
                                      width: _itemWidth,
                                      highlighted: hit,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );

                      return Column(
                        children: <Widget>[
                          const SizedBox(height: AppSpacing.xs),

                          // Reel Container with Holographic Depth & Precision Indicator
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md + 2,
                            ),
                            padding: const EdgeInsets.fromLTRB(
                              10,
                              AppSpacing.base,
                              10,
                              AppSpacing.md + 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusLg + 2,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  AppColors.spaceNavy.withValues(alpha: 0.95),
                                  AppColors.bgDeep.withValues(alpha: 0.98),
                                ],
                              ),
                              border: Border.all(
                                color: theme.accentColor.withValues(alpha: 0.38),
                                width: 1.3,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: theme.accentColor.withValues(alpha: 0.22),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: viewportWidth,
                                  height: 210,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd + 2,
                                    ),
                                    child: Stack(
                                      children: <Widget>[
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: <Color>[
                                                  Colors.white.withValues(
                                                    alpha: 0.05,
                                                  ),
                                                  Colors.transparent,
                                                  Colors.white.withValues(
                                                    alpha: 0.03,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        AnimatedBuilder(
                                          animation: _reelController,
                                          child: reelStrip,
                                          builder: (
                                            BuildContext context,
                                            Widget? child,
                                          ) {
                                            final double eased = _reel.spinProgress(
                                              _reelController.value,
                                              targetOffset,
                                              itemExtent,
                                            );
                                            final double currentOffset =
                                                targetOffset * eased;

                                            // Check item crossing for haptic audio/feel
                                            final int curIdx = _reel.itemIndexAt(
                                              _reelController.value,
                                              targetOffset,
                                              itemExtent,
                                              viewportWidth,
                                              _itemWidth,
                                            );
                                            _checkHapticTick(curIdx);

                                            return Transform.translate(
                                              offset: Offset(-currentOffset, 0),
                                              child: child,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Reticle Center Target Line
                                Container(
                                  width: 4,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusFull,
                                    ),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: <Color>[
                                        AppColors.goldLight,
                                        AppColors.liquidGold,
                                        AppColors.goldLight,
                                      ],
                                    ),
                                    boxShadow: const <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.liquidGold,
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const Positioned(
                                  top: 0,
                                  child: Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.goldLight,
                                    size: 38,
                                  ),
                                ),
                                const Positioned(
                                  bottom: 0,
                                  child: Icon(
                                    Icons.arrow_drop_up,
                                    color: AppColors.goldLight,
                                    size: 38,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Multi-Reward Deck Grid or Single Reward 3D Showcase
                          Expanded(
                            child: widget.multiRewards != null &&
                                    widget.multiRewards!.isNotEmpty &&
                                    _finished
                                ? _buildMultiRewardDeck(
                                    widget.multiRewards!,
                                    theme,
                                  )
                                : _buildSingleRewardShowcase(
                                    l10n: l10n,
                                    reward: reward,
                                    resultName: resultName,
                                    resultItemId: resultItemId,
                                    qty: qty,
                                    theme: theme,
                                  ),
                          ),

                          // Bottom Primary Action Button
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.base,
                              AppSpacing.xs + 2,
                              AppSpacing.base,
                              AppSpacing.md,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _finished
                                    ? () => Navigator.of(context).pop()
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.accentColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.md + 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusLg,
                                    ),
                                  ),
                                  shadowColor: theme.accentColor.withValues(
                                    alpha: 0.55,
                                  ),
                                  elevation: 6,
                                ),
                                child: Text(
                                  _finished
                                      ? (widget.multiRewards != null &&
                                              widget.multiRewards!.length > 1
                                          ? 'TÜM ÖDÜLLERİ AL (${widget.multiRewards!.length}x)'
                                          : l10n.loot_odulu_al)
                                      : (_chestBurst
                                          ? l10n.loot_aciliyor
                                          : 'KASA AÇILIYOR...'),
                                  style: AppTextStyles.bodyBold.copyWith(
                                    fontSize: 16,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 5. Explosive Particle Flash Overlay on Burst
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashController,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: _ParticleFlashPainter(
                      progress: _flashController.value,
                      burstColor: theme.accentColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3D Flip Card Showcase with Holographic Foil and Duplicate Conversion.
  Widget _buildSingleRewardShowcase({
    required AppLocalizations l10n,
    required Map<String, dynamic> reward,
    required String resultName,
    required String resultItemId,
    required int qty,
    required LootChestTheme theme,
  }) {
    final String rarity =
        reward['rarity']?.toString().toLowerCase() ?? 'common';
    final Color rarityColor = AppColors.forRarity(rarity);
    final bool isDuplicate = _isDuplicateReward(reward);
    final int convertedGold = _calculateConvertedGold(reward, rarity);
    final int convertedShards = _calculateConvertedShards(reward, rarity);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _revealController,
        _duplicateConvertController,
        _shimmerController,
      ]),
      builder: (BuildContext context, _) {
        final double flipVal = _revealController.value;
        final double angle = flipVal * math.pi;
        final bool isFaceUp = flipVal >= 0.5;

        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0022)
          ..rotateY(angle);

        return Center(
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: SizedBox(
              width: 320,
              height: 104,
              child: isFaceUp
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _buildSingleCardFront(
                        l10n: l10n,
                        reward: reward,
                        resultName: resultName,
                        resultItemId: resultItemId,
                        qty: qty,
                        rarity: rarity,
                        rarityColor: rarityColor,
                        theme: theme,
                        isDuplicate: isDuplicate,
                        convertedGold: convertedGold,
                        convertedShards: convertedShards,
                      ),
                    )
                  : _buildSingleCardBack(theme),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleCardBack(LootChestTheme theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: AppColors.bgSurface.withValues(alpha: 0.90),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.60),
          width: 1.4,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.accentColor.withValues(alpha: 0.20),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              theme.tier.runicGlyphs.first,
              style: TextStyle(
                color: theme.accentColor.withValues(alpha: 0.85),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'KİLİTLENİYOR...',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleCardFront({
    required AppLocalizations l10n,
    required Map<String, dynamic> reward,
    required String resultName,
    required String resultItemId,
    required int qty,
    required String rarity,
    required Color rarityColor,
    required LootChestTheme theme,
    required bool isDuplicate,
    required int convertedGold,
    required int convertedShards,
  }) {
    final double convertProgress = _duplicateConvertController.value;

    return Stack(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            color: AppColors.bgSurface.withValues(alpha: 0.92),
            border: Border.all(
              color: rarityColor.withValues(alpha: 0.85),
              width: 1.6,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: rarityColor.withValues(alpha: 0.35),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg - 2),
            child: Stack(
              children: <Widget>[
                // Holographic foil sheen
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HolographicCardShimmerPainter(
                      progress: _shimmerController.value,
                      accentColor: theme.accentColor,
                    ),
                  ),
                ),

                // Duplicate dissolution vfx
                if (isDuplicate)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DuplicateDissolvePainter(
                        progress: convertProgress,
                        accentColor: theme.accentColor,
                      ),
                    ),
                  ),

                Row(
                  children: <Widget>[
                    // Item Icon with Rarity Backdrop
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                        color: AppColors.bgDeep.withValues(alpha: 0.55),
                        border: Border.all(
                          color: rarityColor.withValues(alpha: 0.80),
                        ),
                      ),
                      child: ItemIconView(
                        iconValue: reward['icon']?.toString() ?? '',
                        itemId: resultItemId.isNotEmpty ? resultItemId : null,
                        size: 58,
                        expand: true,
                        fallback: '◻',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Details Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                l10n.loot_kazandin,
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.success,
                                  fontSize: 12,
                                ),
                              ),
                              if (isDuplicate) ...<Widget>[
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.25,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.warning,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'KOPYA',
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.warning,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$resultName  x$qty',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (isDuplicate && _duplicateConverted)
                            Text(
                              'DÖNÜŞTÜ: +$convertedShards Ruh Taşı · +${lootCompactNum(convertedGold)} Altın',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.liquidGold,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else
                            Text(
                              '${rarity.toUpperCase()} · ${lootDropCategoryLabel(resultItemId)}',
                              style: AppTextStyles.label.copyWith(
                                color: rarityColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Interactive Duplicate Preview Pill Toggle
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() => _previewDuplicate = !_previewDuplicate);
              if (_previewDuplicate) {
                _duplicateConvertController.forward(from: 0.0);
                HapticFeedback.lightImpact();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _previewDuplicate ? Icons.sync_rounded : Icons.sync_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 10x Multi-Open Deck Grid with 3D Flip Cascade and Duplicate Conversion.
  Widget _buildMultiRewardDeck(
    List<Map<String, dynamic>> rewards,
    LootChestTheme theme,
  ) {
    // Find best jackpot item in bundle
    int bestIndex = 0;
    int highestScore = -1;
    final Map<String, int> ranks = <String, int>{
      'mythic': 5,
      'legendary': 4,
      'epic': 3,
      'rare': 2,
      'uncommon': 1,
      'common': 0,
    };

    for (int i = 0; i < rewards.length; i++) {
      final String r =
          (rewards[i]['rarity']?.toString() ?? 'common').toLowerCase();
      final int score = ranks[r] ?? 0;
      if (score > highestScore) {
        highestScore = score;
        bestIndex = i;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: AppColors.bgDeep.withValues(alpha: 0.85),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        children: <Widget>[
          // Header info strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '10x AÇILIŞ SONUÇLARI',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    for (int i = 0; i < rewards.length; i++) {
                      _revealedMultiIndices.add(i);
                    }
                  });
                  HapticFeedback.mediumImpact();
                },
                child: Text(
                  'TÜMÜNÜ AÇ',
                  style: AppTextStyles.label.copyWith(
                    color: theme.accentColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          // 10x Grid
          Expanded(
            child: GridView.builder(
              itemCount: rewards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.72,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (BuildContext context, int idx) {
                final Map<String, dynamic> item = rewards[idx];
                final String rarity =
                    item['rarity']?.toString().toLowerCase() ?? 'common';
                final Color rarityColor = AppColors.forRarity(rarity);
                final int amt = lootToInt(
                  item['quantity'],
                  fallback: lootToInt(item['amount'], fallback: 1),
                );
                final bool isJackpot = idx == bestIndex;
                final bool isRevealed = _revealedMultiIndices.contains(idx);

                return GestureDetector(
                  onTap: () {
                    if (!isRevealed) {
                      setState(() => _revealedMultiIndices.add(idx));
                      HapticFeedback.selectionClick();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      color: isRevealed
                          ? rarityColor.withValues(
                              alpha: isJackpot ? 0.30 : 0.16,
                            )
                          : AppColors.spaceNavy.withValues(alpha: 0.75),
                      border: Border.all(
                        color: isRevealed
                            ? rarityColor.withValues(
                                alpha: isJackpot ? 0.95 : 0.65,
                              )
                            : theme.borderColor.withValues(alpha: 0.40),
                        width: isJackpot ? 1.8 : 1.1,
                      ),
                      boxShadow: isRevealed && isJackpot
                          ? <BoxShadow>[
                              BoxShadow(
                                color: rarityColor.withValues(alpha: 0.45),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        if (isRevealed)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              ItemIconView(
                                iconValue: item['icon']?.toString() ?? '',
                                itemId: item['item_id']?.toString(),
                                size: 34,
                                expand: false,
                                fallback: '◻',
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'x$amt',
                                style: AppTextStyles.label.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            theme.tier.runicGlyphs.first,
                            style: TextStyle(
                              color: theme.accentColor.withValues(alpha: 0.70),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (isJackpot && isRevealed)
                          Positioned(
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.liquidGold,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'EN İYİ',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LootReelCard extends StatelessWidget {
  const _LootReelCard({
    required this.drop,
    required this.width,
    required this.highlighted,
  });

  final LootDropView drop;
  final double width;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color rarity = AppColors.forRarity(drop.rarity);

    return Container(
      width: width,
      height: 200,
      padding: const EdgeInsets.all(AppSpacing.sm + 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            rarity.withValues(alpha: highlighted ? 0.48 : 0.24),
            AppColors.spaceNavy,
          ],
        ),
        border: Border.all(
          color: rarity.withValues(alpha: highlighted ? 0.98 : 0.65),
          width: highlighted ? 2.2 : 1.1,
        ),
        boxShadow: highlighted
            ? <BoxShadow>[
                BoxShadow(
                  color: rarity.withValues(alpha: 0.60),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(
            alignment: Alignment.topRight,
            child: Text(
              drop.rarity.toUpperCase(),
              style: AppTextStyles.label.copyWith(
                color: rarity.withValues(alpha: 0.95),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: Center(
              child: ItemIconView(
                iconValue: drop.icon,
                itemId: drop.itemId,
                size: 74,
                expand: true,
                fallback: '◻',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            drop.itemName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '%${drop.dropRate.toStringAsFixed(2)}  x${drop.minQuantity}-${drop.maxQuantity}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
