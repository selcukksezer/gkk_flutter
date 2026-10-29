import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../core/engine/zero_jank_preloader.dart';
import '../../../theme/app_colors.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';
import '../../settings/graphics_settings_service.dart';

/// Controller to trigger hammer strikes and sequences programmatically.
class AnvilHammerController extends ChangeNotifier {
  VoidCallback? _onTriggerStrike;
  void Function(int count)? _onTriggerSequence;
  VoidCallback? _onReset;
  bool _isStriking = false;

  bool get isStriking => _isStriking;

  void attach({
    required VoidCallback onTriggerStrike,
    required void Function(int count) onTriggerSequence,
    required VoidCallback onReset,
  }) {
    _onTriggerStrike = onTriggerStrike;
    _onTriggerSequence = onTriggerSequence;
    _onReset = onReset;
  }

  void detach() {
    _onTriggerStrike = null;
    _onTriggerSequence = null;
    _onReset = null;
  }

  void strike() {
    _onTriggerStrike?.call();
  }

  void strikeSequence([int count = 3]) {
    _onTriggerSequence?.call(count);
  }

  void reset() {
    _onReset?.call();
  }

  void _setStriking(bool val) {
    if (_isStriking != val) {
      _isStriking = val;
      notifyListeners();
    }
  }
}

/// A spark emitted from the hammer-anvil impact point.
class _StrikeSpark {
  _StrikeSpark({
    required this.origin,
    required this.velocity,
    required this.maxLife,
    required this.color,
    required this.size,
  }) : life = maxLife;

  final Offset origin;
  final Offset velocity;
  final double maxLife;
  final Color color;
  final double size;
  double life;

  Offset position(double progress) {
    // Kinematics: p = p0 + v*t + 0.5*g*t^2
    final double t = progress * maxLife;
    const double gravity = 420.0;
    return Offset(
      origin.dx + velocity.dx * t,
      origin.dy + velocity.dy * t + 0.5 * gravity * t * t,
    );
  }

  double opacity(double progress) => (1.0 - progress).clamp(0.0, 1.0);
}

/// Juicy Anvil Hammer Strike Impact Animation Widget.
///
/// Features:
/// - Dynamic hammer swing arc with anticipation, explosive strike, and elastic recoil.
/// - Vector-rendered blacksmith anvil with glowing molten workpiece.
/// - Impact shockwave ring expanding with alpha decay.
/// - Screen/recoil shake effect with decaying sinusoidal vibration.
/// - Radiant metallic spark burst spraying outward from the strike point.
/// - Haptic and audio hooks (`onImpact`, `onSequenceComplete`).
class AnvilHammerStrikeImpact extends StatefulWidget {
  const AnvilHammerStrikeImpact({
    super.key,
    this.controller,
    this.width = 240,
    this.height = 180,
    this.autoStart = false,
    this.sparkIntensity = 1.0,
    this.hotIngotColor = const Color(0xFFFF7A00),
    this.onImpact,
    this.onSequenceComplete,
    this.showWorkpiece = true,
    this.enableHaptics = true,
    this.scaler,
  });

  final AnvilHammerController? controller;
  final double width;
  final double height;
  final bool autoStart;
  final double sparkIntensity;
  final Color hotIngotColor;
  final VoidCallback? onImpact;
  final VoidCallback? onSequenceComplete;
  final bool showWorkpiece;
  final bool enableHaptics;
  final AdaptiveQualityScaler? scaler;

  @override
  State<AnvilHammerStrikeImpact> createState() => _AnvilHammerStrikeImpactState();
}

class _AnvilHammerStrikeImpactState extends State<AnvilHammerStrikeImpact>
    with TickerProviderStateMixin {
  late final AnimationController _strikeController;
  late final AnimationController _shakeController;
  late final AnimationController _sparkController;
  late final AnimationController _ingotGlowController;

  late final Animation<double> _hammerRotation;
  late final Animation<Offset> _hammerTranslation;
  late final Animation<double> _shockwaveProgress;

  final List<_StrikeSpark> _sparks = <_StrikeSpark>[];
  final math.Random _rng = math.Random();

  int _remainingStrikesInSequence = 0;
  bool _impactDispatched = false;

  AdaptiveQualityScaler get _activeScaler =>
      widget.scaler ?? GraphicsSettingsService.instance.scaler;

  void _onScalerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();

    // Zero-Jank pre-warm of strike VFX assets (<2ms budget)
    ZeroJankPreloader.instance.preloadAtomic<bool>(
      id: 'vfx_anvil_hammer_strike_impact',
      priority: PreloadPriority.criticalHud,
      loader: () async => true,
      tags: const <String>{'vfx', 'crafting', 'anvil', 'strike'},
    );

    _activeScaler.addListener(_onScalerChanged);

    _strikeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _ingotGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Hammer swing curve:
    // 0.0 -> 0.2: Anticipation pull back (rotate backwards)
    // 0.2 -> 0.45: Downward strike (hits anvil at ~0.45)
    // 0.45 -> 0.75: Elastic bounce / recoil
    // 0.75 -> 1.0: Settle back to resting pose
    _hammerRotation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: -0.45)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 20,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -0.45, end: 0.82)
            .chain(CurveTween(curve: Curves.easeInExpo)),
        weight: 25,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.82, end: -0.08)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -0.08, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
    ]).animate(_strikeController);

    _hammerTranslation = TweenSequence<Offset>(<TweenSequenceItem<Offset>>[
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(-8, -14))
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: const Offset(-8, -14), end: const Offset(4, 18))
            .chain(CurveTween(curve: Curves.easeInExpo)),
        weight: 25,
      ),
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: const Offset(4, 18), end: const Offset(0, -3))
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: const Offset(0, -3), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
    ]).animate(_strikeController);

    _shockwaveProgress = CurvedAnimation(
      parent: _sparkController,
      curve: Curves.easeOutCubic,
    );

    _strikeController.addListener(_handleStrikeProgress);
    _strikeController.addStatusListener(_handleStrikeStatus);

    widget.controller?.attach(
      onTriggerStrike: triggerStrike,
      onTriggerSequence: triggerSequence,
      onReset: resetAnimation,
    );

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) triggerStrike();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AnvilHammerStrikeImpact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scaler != oldWidget.scaler) {
      (oldWidget.scaler ?? GraphicsSettingsService.instance.scaler)
          .removeListener(_onScalerChanged);
      _activeScaler.addListener(_onScalerChanged);
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(
        onTriggerStrike: triggerStrike,
        onTriggerSequence: triggerSequence,
        onReset: resetAnimation,
      );
    }
  }

  @override
  void dispose() {
    _activeScaler.removeListener(_onScalerChanged);
    widget.controller?.detach();
    _strikeController.removeListener(_handleStrikeProgress);
    _strikeController.removeStatusListener(_handleStrikeStatus);
    _strikeController.dispose();
    _shakeController.dispose();
    _sparkController.dispose();
    _ingotGlowController.dispose();
    super.dispose();
  }

  void _handleStrikeProgress() {
    // Impact happens at frame progress ~0.45
    if (!_impactDispatched && _strikeController.value >= 0.44) {
      _impactDispatched = true;
      _triggerImpactEffects();
    }
  }

  void _handleStrikeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_remainingStrikesInSequence > 0) {
        _remainingStrikesInSequence--;
        _impactDispatched = false;
        _strikeController.forward(from: 0.0);
      } else {
        widget.controller?._setStriking(false);
        widget.onSequenceComplete?.call();
      }
    }
  }

  void _triggerImpactEffects() {
    // 1. Screen shake
    _shakeController.forward(from: 0.0);

    // 2. Generate sparks
    _generateSparks();
    _sparkController.forward(from: 0.0);

    // 3. Haptic feedback
    if (widget.enableHaptics) {
      AionHaptics.craftSuccess();
    }

    // 4. Callback
    widget.onImpact?.call();
  }

  void _generateSparks() {
    _sparks.clear();
    final AdaptiveQualityScaler scaler = _activeScaler;
    final HardwareTier tier = scaler.currentTier;
    final int throttle = scaler.currentThrottleLevel;

    final bool isLowSpec =
        tier == HardwareTier.eco || tier == HardwareTier.low || throttle >= 2;
    final bool isUltra =
        tier == HardwareTier.ultra && throttle == 0;

    final int count;
    if (isLowSpec) {
      // On Eco / Low tiers (or throttled >= 2): decimate impact spark count from 48 to 12 sparks
      count = (12 * widget.sparkIntensity).clamp(4, 12).toInt();
    } else if (isUltra) {
      // On Ultra tier: rich spark volume (up to 48 sparks) with 360-degree radial dispersion
      count = (48 * widget.sparkIntensity).clamp(24, 48).toInt();
    } else {
      // Mid / High tiers: balanced spark count (12-32 sparks)
      count = (28 * widget.sparkIntensity).clamp(12, 32).toInt();
    }

    // Strike coordinate centered relative to the anvil surface
    final Offset strikeCenter = Offset(widget.width * 0.48, widget.height * 0.52);

    for (int i = 0; i < count; i++) {
      final double angle;
      final double speed;

      if (isUltra) {
        // Ultra tier: full radial spark dispersion around impact epicenter
        angle = _rng.nextDouble() * 2 * math.pi;
        speed = 100.0 + _rng.nextDouble() * 260.0;
      } else if (isLowSpec) {
        // Eco / Low tiers: constrained upward fan (-140 to -40 deg) with uniform speed
        angle = (-140 + _rng.nextDouble() * 100) * (math.pi / 180.0);
        speed = 100.0 + _rng.nextDouble() * 140.0;
      } else {
        // Mid / High tiers: fan spraying upward and outward (-165 to -15 deg)
        angle = (-165 + _rng.nextDouble() * 150) * (math.pi / 180.0);
        speed = 120.0 + _rng.nextDouble() * 220.0;
      }

      final Color sparkColor = switch (_rng.nextInt(4)) {
        0 => const Color(0xFFFFFFFF),
        1 => const Color(0xFFFFD54F),
        2 => const Color(0xFFFF8A00),
        _ => const Color(0xFFFF3D00),
      };

      _sparks.add(
        _StrikeSpark(
          origin: strikeCenter,
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          maxLife: isLowSpec
              ? 0.30 + _rng.nextDouble() * 0.15
              : 0.35 + _rng.nextDouble() * 0.25,
          color: sparkColor,
          size: isLowSpec
              ? 1.8 + _rng.nextDouble() * 1.5
              : 1.8 + _rng.nextDouble() * 2.4,
        ),
      );
    }
  }

  void triggerStrike() {
    if (!mounted) return;
    _remainingStrikesInSequence = 0;
    _impactDispatched = false;
    widget.controller?._setStriking(true);
    _strikeController.forward(from: 0.0);
  }

  void triggerSequence(int count) {
    if (!mounted || count <= 0) return;
    _remainingStrikesInSequence = count - 1;
    _impactDispatched = false;
    widget.controller?._setStriking(true);
    _strikeController.forward(from: 0.0);
  }

  void resetAnimation() {
    _remainingStrikesInSequence = 0;
    _impactDispatched = false;
    _strikeController.reset();
    _shakeController.reset();
    _sparkController.reset();
    _sparks.clear();
    widget.controller?._setStriking(false);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AdaptiveQualityScaler scaler = _activeScaler;
    final HardwareTier tier = scaler.currentTier;
    final int throttle = scaler.currentThrottleLevel;
    final bool isLowSpec =
        tier == HardwareTier.eco || tier == HardwareTier.low || throttle >= 2;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _strikeController,
          _shakeController,
          _sparkController,
          _ingotGlowController,
        ]),
        builder: (BuildContext context, Widget? child) {
          // Shake calculation: decaying sinusoidal oscillation
          final double shakeProgress = _shakeController.value;
          final double shakeDecay = 1.0 - shakeProgress;
          final double shakeOffset = math.sin(shakeProgress * math.pi * 8) * 6.0 * shakeDecay;

          return Transform.translate(
            offset: Offset(shakeOffset, shakeOffset * 0.4),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // 1. Anvil base & workpiece
                Positioned.fill(
                  child: CustomPaint(
                    painter: _AnvilPainter(
                      showWorkpiece: widget.showWorkpiece,
                      hotIngotColor: widget.hotIngotColor,
                      glowIntensity: _ingotGlowController.value,
                      isLowSpec: isLowSpec,
                    ),
                  ),
                ),

                // 2. Hammer with dynamic swing transform
                Positioned(
                  top: widget.height * 0.12,
                  right: widget.width * 0.24,
                  child: Transform.translate(
                    offset: _hammerTranslation.value,
                    child: Transform.rotate(
                      angle: _hammerRotation.value,
                      alignment: const Alignment(0.6, -0.7), // pivot at hammer grip
                      child: _HammerWidget(
                        width: widget.width * 0.48,
                        height: widget.height * 0.52,
                      ),
                    ),
                  ),
                ),

                // 3. Shockwave & Sparks impact layer
                if (_sparkController.isAnimating || _sparks.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ImpactVfxPainter(
                          sparks: _sparks,
                          progress: _sparkController.value,
                          shockwaveProgress: _shockwaveProgress.value,
                          impactPoint: Offset(widget.width * 0.48, widget.height * 0.52),
                          tier: tier,
                          throttleLevel: throttle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Stylized vector hammer with steel head, golden reinforced banding, and wooden shaft.
class _HammerWidget extends StatelessWidget {
  const _HammerWidget({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _HammerPainter(),
      ),
    );
  }
}

class _HammerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Shaft (handle)
    final Paint shaftPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF5D4037), Color(0xFF8D6E63), Color(0xFF3E2723)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.46, h * 0.2, w * 0.14, h * 0.78));

    final RRect shaftRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.46, h * 0.2, w * 0.12, h * 0.78),
      const Radius.circular(3),
    );
    canvas.drawRRect(shaftRRect, shaftPaint);

    // Grip wrapping bands
    final Paint gripPaint = Paint()
      ..color = const Color(0xFF2D1E18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (double y = h * 0.55; y < h * 0.9; y += 6.0) {
      canvas.drawLine(Offset(w * 0.46, y), Offset(w * 0.58, y + 2.5), gripPaint);
    }

    // Heavy Metal Hammer Head
    final Rect headRect = Rect.fromLTWH(w * 0.16, h * 0.05, w * 0.72, h * 0.28);
    final Paint headPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF90A4AE),
          Color(0xFF455A64),
          Color(0xFF263238),
          Color(0xFF1B2428),
        ],
        stops: <double>[0.0, 0.4, 0.8, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(headRect);

    final RRect headRRect = RRect.fromRectAndRadius(headRect, const Radius.circular(5));
    canvas.drawRRect(headRRect, headPaint);

    // Specular highlight on top edge
    final Paint highlightPaint = Paint()
      ..color = const Color(0xFFECEFF1).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(w * 0.18, h * 0.06),
      Offset(w * 0.86, h * 0.06),
      highlightPaint,
    );

    // Gold reinforcement band around center of hammer head
    final Rect goldBand = Rect.fromLTWH(w * 0.44, h * 0.04, w * 0.16, h * 0.30);
    final Paint goldPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[AppColors.goldLight, AppColors.liquidGold, AppColors.goldDim],
      ).createShader(goldBand);
    canvas.drawRRect(RRect.fromRectAndRadius(goldBand, const Radius.circular(2)), goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// High-detail blacksmith anvil with glowing hot metal workpiece.
class _AnvilPainter extends CustomPainter {
  _AnvilPainter({
    required this.showWorkpiece,
    required this.hotIngotColor,
    required this.glowIntensity,
    this.isLowSpec = false,
  });

  final bool showWorkpiece;
  final Color hotIngotColor;
  final double glowIntensity;
  final bool isLowSpec;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Ground shadow beneath anvil
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.90),
      width: w * 0.75,
      height: h * 0.14,
    );
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isLowSpec ? 3 : 8);
    canvas.drawOval(shadowRect, shadowPaint);

    // Anvil base pedestal
    final Path basePedestal = Path()
      ..moveTo(w * 0.22, h * 0.88)
      ..lineTo(w * 0.78, h * 0.88)
      ..lineTo(w * 0.72, h * 0.76)
      ..lineTo(w * 0.28, h * 0.76)
      ..close();

    final Paint basePaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFF37474F), Color(0xFF212121)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.2, h * 0.76, w * 0.6, h * 0.12));
    canvas.drawPath(basePedestal, basePaint);

    // Anvil waist / body
    final Path waistPath = Path()
      ..moveTo(w * 0.32, h * 0.76)
      ..lineTo(w * 0.68, h * 0.76)
      ..cubicTo(w * 0.64, h * 0.66, w * 0.62, h * 0.58, w * 0.72, h * 0.50)
      ..lineTo(w * 0.84, h * 0.50) // right horn
      ..lineTo(w * 0.78, h * 0.44) // face right
      ..lineTo(w * 0.26, h * 0.44) // face left
      ..cubicTo(w * 0.18, h * 0.45, w * 0.10, h * 0.48, w * 0.08, h * 0.52) // conical horn
      ..cubicTo(w * 0.16, h * 0.54, w * 0.24, h * 0.55, w * 0.28, h * 0.64)
      ..lineTo(w * 0.32, h * 0.76)
      ..close();

    final Paint anvilPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF78909C),
          Color(0xFF455A64),
          Color(0xFF263238),
          Color(0xFF172024),
        ],
        stops: <double>[0.0, 0.3, 0.7, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.08, h * 0.44, w * 0.78, h * 0.44));
    canvas.drawPath(waistPath, anvilPaint);

    // Anvil Face (Flat top striking surface)
    final Path facePath = Path()
      ..moveTo(w * 0.25, h * 0.44)
      ..lineTo(w * 0.76, h * 0.44)
      ..lineTo(w * 0.74, h * 0.47)
      ..lineTo(w * 0.27, h * 0.47)
      ..close();
    final Paint faceHighlight = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[Color(0xFFCFD8DC), Color(0xFF90A4AE)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.25, h * 0.44, w * 0.52, h * 0.03));
    canvas.drawPath(facePath, faceHighlight);

    // Hardy hole on anvil face
    canvas.drawRect(
      Rect.fromLTWH(w * 0.68, h * 0.445, 6, 6),
      Paint()..color = const Color(0xFF10161A),
    );

    // Molten Workpiece / Heated Ingot on anvil
    if (showWorkpiece) {
      final Rect ingotRect = Rect.fromLTWH(w * 0.40, h * 0.42, w * 0.20, h * 0.038);

      // Radial heat glow around workpiece
      final Paint heatGlowPaint = Paint()
        ..color = hotIngotColor.withValues(alpha: 0.35 + glowIntensity * 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isLowSpec ? 4 : 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(ingotRect.inflate(6), const Radius.circular(6)),
        heatGlowPaint,
      );

      // Heated ingot body
      final Paint ingotPaint = Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            const Color(0xFFFFF9C4), // White-hot core
            hotIngotColor,
            const Color(0xFFD84315),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(ingotRect);

      final RRect ingotRRect = RRect.fromRectAndRadius(ingotRect, const Radius.circular(2.5));
      canvas.drawRRect(ingotRRect, ingotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnvilPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.showWorkpiece != showWorkpiece ||
        oldDelegate.hotIngotColor != hotIngotColor ||
        oldDelegate.isLowSpec != isLowSpec;
  }
}

/// Painter for shockwaves, flash flare/bloom, and metal sparks adapting dynamically to hardware tiers.
class _ImpactVfxPainter extends CustomPainter {
  _ImpactVfxPainter({
    required this.sparks,
    required this.progress,
    required this.shockwaveProgress,
    required this.impactPoint,
    required this.tier,
    required this.throttleLevel,
  });

  final List<_StrikeSpark> sparks;
  final double progress;
  final double shockwaveProgress;
  final Offset impactPoint;
  final HardwareTier tier;
  final int throttleLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final bool isLowSpec =
        tier == HardwareTier.eco || tier == HardwareTier.low || throttleLevel >= 2;
    final bool isUltra =
        tier == HardwareTier.ultra && throttleLevel == 0;

    // 1. Expanding shockwave ring(s)
    if (shockwaveProgress > 0.0 && shockwaveProgress < 1.0) {
      if (isLowSpec) {
        // Eco / Low tiers: simplify radial shockwave ring to single stroke pass (0 blur passes)
        final double ringRadius = 10.0 + shockwaveProgress * 48.0;
        final double ringAlpha = (1.0 - shockwaveProgress).clamp(0.0, 1.0);
        final Paint ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.5 * (1.0 - shockwaveProgress)).clamp(0.5, 3.0)
          ..color = const Color(0xFFFFD54F).withValues(alpha: ringAlpha * 0.75);

        canvas.drawCircle(impactPoint, ringRadius, ringPaint);
      } else if (isUltra) {
        // Ultra tier: multi-ring shockwaves (primary ring + glow aura, compression ring, harmonic pulse)
        final double p = shockwaveProgress;
        final double alpha = (1.0 - p).clamp(0.0, 1.0);

        // Ring 1: Primary high-energy shockwave ring with outer glow
        final double r1 = 10.0 + p * 62.0;
        final Paint glowPaint1 = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0 * (1.0 - p)
          ..color = const Color(0xFFFFD54F).withValues(alpha: alpha * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(impactPoint, r1, glowPaint1);

        final Paint corePaint1 = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.5 * (1.0 - p)).clamp(0.8, 4.0)
          ..color = const Color(0xFFFFF9C4).withValues(alpha: alpha * 0.95);
        canvas.drawCircle(impactPoint, r1, corePaint1);

        // Ring 2: Secondary compression ring expanding with slight delay
        final double p2 = (p * 1.25).clamp(0.0, 1.0);
        final double r2 = 6.0 + p2 * 42.0;
        final double alpha2 = (1.0 - p2).clamp(0.0, 1.0);
        final Paint corePaint2 = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.0 * (1.0 - p2)).clamp(0.5, 2.5)
          ..color = const Color(0xFFFF8A00).withValues(alpha: alpha2 * 0.70);
        canvas.drawCircle(impactPoint, r2, corePaint2);

        // Ring 3: Tertiary inner harmonic pulse ring
        final double p3 = (p * 0.75).clamp(0.0, 1.0);
        final double r3 = 4.0 + p3 * 24.0;
        final double alpha3 = (1.0 - p3).clamp(0.0, 1.0);
        final Paint corePaint3 = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.5 * (1.0 - p3)).clamp(0.5, 2.0)
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha3 * 0.60);
        canvas.drawCircle(impactPoint, r3, corePaint3);
      } else {
        // Mid / High tiers: balanced single/dual ring
        final double ringRadius = 10.0 + shockwaveProgress * 54.0;
        final double ringAlpha = (1.0 - shockwaveProgress).clamp(0.0, 1.0);
        final Paint ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.5 * (1.0 - shockwaveProgress)).clamp(0.5, 4.0)
          ..color = const Color(0xFFFFD54F).withValues(alpha: ringAlpha * 0.85);

        canvas.drawCircle(impactPoint, ringRadius, ringPaint);

        if (tier == HardwareTier.high && throttleLevel == 0) {
          final double r2 = 6.0 + shockwaveProgress * 38.0;
          final Paint echoPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * (1.0 - shockwaveProgress)
            ..color = const Color(0xFFFF8A00).withValues(alpha: ringAlpha * 0.50);
          canvas.drawCircle(impactPoint, r2, echoPaint);
        }
      }
    }

    // 2. Center impact hit flash flare & bloom
    if (isLowSpec) {
      if (progress < 0.25) {
        final double flashAlpha = (1.0 - (progress / 0.25)).clamp(0.0, 1.0);
        final Paint flashPaint = Paint()
          ..color = Colors.white.withValues(alpha: flashAlpha * 0.85);
        // Single draw without mask filter to avoid off-screen buffer allocation
        canvas.drawCircle(impactPoint, 10.0 * (1.0 - progress), flashPaint);
      }
    } else if (isUltra) {
      // Ultra tier: multi-stage flash bloom with radial bloom aura & specular star rays
      if (progress < 0.38) {
        final double flashAlpha = (1.0 - (progress / 0.38)).clamp(0.0, 1.0);

        // Stage 1: Wide diffuse flash bloom aura
        final Paint bloomAuraPaint = Paint()
          ..color = const Color(0xFFFFAB00).withValues(alpha: flashAlpha * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
        canvas.drawCircle(impactPoint, 32.0 * (1.0 - progress), bloomAuraPaint);

        // Stage 2: Intermediate radiant amber bloom halo
        final Paint innerBloomPaint = Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: flashAlpha * 0.80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(impactPoint, 20.0 * (1.0 - progress), innerBloomPaint);

        // Stage 3: Ultra white-hot specular impact core
        final Paint coreFlashPaint = Paint()
          ..color = Colors.white.withValues(alpha: flashAlpha * 0.98)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(impactPoint, 12.0 * (1.0 - progress), coreFlashPaint);

        // Stage 4: Specular cross-bloom rays
        final Paint rayPaint = Paint()
          ..color = Colors.white.withValues(alpha: flashAlpha * 0.70)
          ..strokeWidth = 1.5 * (1.0 - progress)
          ..strokeCap = StrokeCap.round;
        final double rayLen = 28.0 * (1.0 - progress);
        canvas.drawLine(
          Offset(impactPoint.dx - rayLen, impactPoint.dy),
          Offset(impactPoint.dx + rayLen, impactPoint.dy),
          rayPaint,
        );
        canvas.drawLine(
          Offset(impactPoint.dx, impactPoint.dy - rayLen * 0.7),
          Offset(impactPoint.dx, impactPoint.dy + rayLen * 0.7),
          rayPaint,
        );
      }
    } else {
      // Mid / High tiers: standard flash flare
      if (progress < 0.3) {
        final double flashAlpha = (1.0 - (progress / 0.3)).clamp(0.0, 1.0);
        final Paint flashPaint = Paint()
          ..color = Colors.white.withValues(alpha: flashAlpha * 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(impactPoint, 14.0 * (1.0 - progress), flashPaint);
      }
    }

    // 3. Render sparks with motion blur trails
    for (final _StrikeSpark spark in sparks) {
      final double p = progress.clamp(0.0, 1.0);
      final Offset currentPos = spark.position(p);
      final Offset prevPos = spark.position((p - (isLowSpec ? 0.03 : 0.04)).clamp(0.0, 1.0));
      final double alpha = spark.opacity(p);

      if (alpha <= 0.01) continue;

      if (isLowSpec) {
        // Eco / Low tiers: direct streak line pass (zero mask blur filter passes)
        final Paint streakPaint = Paint()
          ..color = spark.color.withValues(alpha: alpha)
          ..strokeWidth = spark.size
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(prevPos, currentPos, streakPaint);
      } else if (isUltra) {
        // Ultra tier: glow halo + specular streak + leading incandescent bead
        final Paint glowPaint = Paint()
          ..color = spark.color.withValues(alpha: alpha * 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(currentPos, spark.size * 2.0, glowPaint);

        final Paint streakPaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = spark.size
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(prevPos, currentPos, streakPaint);

        final Paint beadPaint = Paint()
          ..color = const Color(0xFFFFF9C4).withValues(alpha: alpha * 0.95);
        canvas.drawCircle(currentPos, spark.size * 0.7, beadPaint);
      } else {
        // Mid / High tiers: glow halo + core streak line
        final Paint glowPaint = Paint()
          ..color = spark.color.withValues(alpha: alpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(currentPos, spark.size * 1.5, glowPaint);

        final Paint streakPaint = Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = spark.size
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(prevPos, currentPos, streakPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactVfxPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shockwaveProgress != shockwaveProgress ||
        oldDelegate.tier != tier ||
        oldDelegate.throttleLevel != throttleLevel ||
        oldDelegate.sparks != sparks;
  }
}
