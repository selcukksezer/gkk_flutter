import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/profile_avatar.dart';
import '../../../core/vfx/directional_camera_shake.dart';
import 'gladiator_tier_emblem.dart';

/// Cinematic clash painter drawing diagonal energetic lightning, slash waves,
/// high-velocity metallic sparks, parabolic embers, and central star flares.
class VersusClashPainter extends CustomPainter {
  const VersusClashPainter({
    required this.animationValue,
    this.accentColor = const Color(0xFFFFD700),
    this.secondaryColor = const Color(0xFFFF1744),
    this.challengerColor = const Color(0xFF00E5FF),
  });

  final double animationValue;
  final Color accentColor;
  final Color secondaryColor;
  final Color challengerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w * 0.5, h * 0.5);

    // Clash line anchors (angled diagonal slice)
    final Offset pTop = Offset(w * 0.44, 0);
    final Offset pBottom = Offset(w * 0.56, h);
    final Offset slashDir = pBottom - pTop;
    final double slashLen = slashDir.distance;
    final double slashAngle = math.atan2(slashDir.dy, slashDir.dx);

    // Normal vector perpendicular to slash line
    final Offset normal = Offset(-slashDir.dy / slashLen, slashDir.dx / slashLen);

    // -------------------------------------------------------------------------
    // 1. Diagonal Dynamic Energy Slash Band & Glow
    // -------------------------------------------------------------------------
    final Paint slashGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.transparent,
          challengerColor.withValues(alpha: 0.85),
          Colors.white,
          accentColor,
          secondaryColor.withValues(alpha: 0.85),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.28, 0.48, 0.52, 0.72, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final Path slashPath = Path()
      ..moveTo(pTop.dx, pTop.dy)
      ..lineTo(pBottom.dx, pBottom.dy);
    canvas.drawPath(slashPath, slashGlow);

    // Ultra-bright central blade core
    final Paint bladeCore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawPath(slashPath, bladeCore);

    // -------------------------------------------------------------------------
    // 2. Dual Elliptical Shockwave Compression Waves
    // -------------------------------------------------------------------------
    final double sw1 = (animationValue * 1.6) % 1.0;
    final double sw2 = (animationValue * 1.6 + 0.5) % 1.0;

    void drawShockwave(double progress, double maxRadius, Color color) {
      final double r = 8.0 + progress * maxRadius;
      final double alpha = ((1.0 - progress) * 0.75).clamp(0.0, 1.0);
      final Paint swPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 - progress) * 3.5
        ..color = color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(slashAngle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 0.85),
        swPaint,
      );
      canvas.restore();
    }

    drawShockwave(sw1, 80.0, accentColor);
    drawShockwave(sw2, 60.0, Colors.white);

    // -------------------------------------------------------------------------
    // 3. Procedural Jagged Branching Lightning Streaks
    // -------------------------------------------------------------------------
    final int cycleFrame = (animationValue * 14).floor();
    final double lightningFlicker =
        (math.sin(animationValue * 8 * math.pi) > 0.1) ? 1.0 : 0.35;

    final int segments = 8;
    final List<Offset> mainBolt = <Offset>[pTop];

    for (int s = 1; s < segments; s++) {
      final double t = s / segments;
      final Offset base = Offset.lerp(pTop, pBottom, t)!;
      final double jitterSeed =
          math.sin((s * 67 + cycleFrame * 179).toDouble());
      final double displacement =
          (1.0 - (t - 0.5).abs() * 1.6) * 22.0 * jitterSeed;
      mainBolt.add(Offset(
        base.dx + normal.dx * displacement,
        base.dy + normal.dy * displacement,
      ));
    }
    mainBolt.add(pBottom);

    final Path boltPath = Path()..moveTo(mainBolt[0].dx, mainBolt[0].dy);
    for (int i = 1; i < mainBolt.length; i++) {
      boltPath.lineTo(mainBolt[i].dx, mainBolt[i].dy);
    }

    // Outer Lightning Glow
    final Paint boltGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..color = accentColor.withValues(alpha: 0.45 * lightningFlicker);
    canvas.drawPath(boltPath, boltGlow);

    // Inner Lightning Core
    final Paint boltCore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.95 * lightningFlicker);
    canvas.drawPath(boltPath, boltCore);

    // Side Discharges (Arcing toward Challenger & Defender frames)
    if (mainBolt.length >= 6) {
      final double branchJitter1 = math.cos((cycleFrame * 97).toDouble());
      final Offset b1Start = mainBolt[2];
      final Path leftBranch = Path()
        ..moveTo(b1Start.dx, b1Start.dy)
        ..lineTo(b1Start.dx - 22, b1Start.dy + 8 + branchJitter1 * 6)
        ..lineTo(b1Start.dx - 44, b1Start.dy - 4 + branchJitter1 * 10);

      final Paint branchPaintLeft = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = challengerColor.withValues(alpha: 0.7 * lightningFlicker);
      canvas.drawPath(leftBranch, branchPaintLeft);

      final double branchJitter2 = math.sin((cycleFrame * 113).toDouble());
      final Offset b2Start = mainBolt[5];
      final Path rightBranch = Path()
        ..moveTo(b2Start.dx, b2Start.dy)
        ..lineTo(b2Start.dx + 22, b2Start.dy - 8 + branchJitter2 * 6)
        ..lineTo(b2Start.dx + 44, b2Start.dy + 4 + branchJitter2 * 10);

      final Paint branchPaintRight = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = secondaryColor.withValues(alpha: 0.7 * lightningFlicker);
      canvas.drawPath(rightBranch, branchPaintRight);
    }

    // -------------------------------------------------------------------------
    // 4. Clashing High-Velocity Metallic Projectile Sparks & Glowing Embers
    // -------------------------------------------------------------------------
    for (int i = 0; i < 30; i++) {
      final double seed = (i * 137.5 + 42) % 1000.0 / 1000.0;
      final double speed = 0.65 + 0.75 * ((i * 31) % 100 / 100.0);
      final double progress = (animationValue * speed + seed) % 1.0;

      final double side = (i % 2 == 0) ? 1.0 : -1.0;
      final double spreadAngle = ((i * 19) % 70 - 35) * math.pi / 180.0;

      final double cosA = math.cos(spreadAngle);
      final double sinA = math.sin(spreadAngle);
      final double dirX = side * (normal.dx * cosA - normal.dy * sinA);
      final double dirY = side * (normal.dx * sinA + normal.dy * cosA);

      final double distance = 10.0 + progress * (w * 0.42);
      final double gravity = progress * progress * 26.0;

      final Offset head = Offset(
        center.dx + dirX * distance,
        center.dy + dirY * distance + gravity,
      );

      final double streakLen =
          (6.0 + (1.0 - progress) * 16.0) * (1.0 - progress);
      final Offset tail = Offset(
        head.dx - dirX * streakLen,
        head.dy - dirY * streakLen - gravity * 0.2,
      );

      final double alpha = math.sin(progress * math.pi).clamp(0.0, 1.0);

      Color sparkColor;
      if (i % 4 == 0) {
        sparkColor = Colors.white;
      } else if (i % 4 == 1) {
        sparkColor = accentColor;
      } else if (i % 4 == 2) {
        sparkColor = challengerColor;
      } else {
        sparkColor = secondaryColor;
      }

      final Paint sparkPaint = Paint()
        ..color = sparkColor.withValues(alpha: alpha * 0.9)
        ..strokeWidth = (i % 3 == 0 ? 2.2 : 1.4) * (1.0 - progress * 0.5)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(tail, head, sparkPaint);

      // Searing white-hot dot at spark head
      if (progress < 0.65) {
        final Paint headDot = Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(head, 1.2 * (1.0 - progress * 0.6), headDot);
      }
    }

    // -------------------------------------------------------------------------
    // 5. Central Searing 4-Point Star Flare / Diamond Glint
    // -------------------------------------------------------------------------
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final double flareScale =
        0.75 + 0.45 * math.sin(animationValue * 4 * math.pi).abs();
    final double flareAngle = animationValue * math.pi * 0.5;
    canvas.rotate(flareAngle);

    final Path vFlare = Path()
      ..moveTo(0, -32 * flareScale)
      ..lineTo(3.5 * flareScale, 0)
      ..lineTo(0, 32 * flareScale)
      ..lineTo(-3.5 * flareScale, 0)
      ..close();

    final Path hFlare = Path()
      ..moveTo(-48 * flareScale, 0)
      ..lineTo(0, 3.0 * flareScale)
      ..lineTo(48 * flareScale, 0)
      ..lineTo(0, -3.0 * flareScale)
      ..close();

    final Paint flarePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.95),
          accentColor.withValues(alpha: 0.7),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 48 * flareScale));

    canvas.drawPath(vFlare, flarePaint);
    canvas.drawPath(hFlare, flarePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VersusClashPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.challengerColor != challengerColor;
  }
}

/// Custom painter for crossed duel blades silhouette behind the central VS medallion.
class _VsCrossedBladesPainter extends CustomPainter {
  const _VsCrossedBladesPainter({required this.animationValue});

  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double bladeLen = size.width * 0.55;

    final double pulse =
        0.96 + 0.08 * math.sin(animationValue * 2 * math.pi).abs();

    void drawBlade(double angle) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.scale(pulse);

      // Steel Blade Silhouette
      final Path bladePath = Path()
        ..moveTo(0, -bladeLen)
        ..lineTo(3.2, -bladeLen * 0.85)
        ..lineTo(2.4, bladeLen * 0.35)
        ..lineTo(6.0, bladeLen * 0.38)
        ..lineTo(6.0, bladeLen * 0.44)
        ..lineTo(1.8, bladeLen * 0.44)
        ..lineTo(1.8, bladeLen * 0.72)
        ..lineTo(3.5, bladeLen * 0.76)
        ..lineTo(0, bladeLen * 0.82)
        ..lineTo(-3.5, bladeLen * 0.76)
        ..lineTo(-1.8, bladeLen * 0.72)
        ..lineTo(-1.8, bladeLen * 0.44)
        ..lineTo(-6.0, bladeLen * 0.44)
        ..lineTo(-6.0, bladeLen * 0.38)
        ..lineTo(-2.4, bladeLen * 0.35)
        ..lineTo(-3.2, -bladeLen * 0.85)
        ..close();

      final Paint bladePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[
            Color(0xFFFFFFFF),
            Color(0xFFCFD8DC),
            Color(0xFF78909C),
            Color(0xFFFFD700),
            Color(0xFF263238),
            Color(0xFFFFD700),
          ],
          stops: const <double>[0.0, 0.4, 0.7, 0.72, 0.85, 1.0],
        ).createShader(Rect.fromLTWH(-6, -bladeLen, 12, bladeLen * 1.82));

      canvas.drawPath(bladePath, bladePaint);

      // Fuller center gleam
      final Paint fullerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, -bladeLen * 0.9),
        Offset(0, bladeLen * 0.3),
        fullerPaint,
      );

      canvas.restore();
    }

    drawBlade(-math.pi / 4);
    drawBlade(math.pi / 4);
  }

  @override
  bool shouldRepaint(covariant _VsCrossedBladesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Mobile PvP Match Intro Versus Splash Banner.
///
/// Features high-impact dynamic clash animations, clashing metallic sparks,
/// branching lightning streaks, dual combatant presentation frames, and
/// directional camera micro-shake + impact flash cues.
class PvpVersusSplashBanner extends StatefulWidget {
  const PvpVersusSplashBanner({
    super.key,
    required this.challengerName,
    required this.challengerRating,
    this.challengerPower = 0,
    this.challengerAvatarUrl = '',
    this.challengerLevel = 1,
    required this.defenderName,
    required this.defenderRating,
    this.defenderPower = 0,
    this.defenderAvatarUrl = '',
    this.defenderLevel = 1,
    this.arenaTitle = 'Uçurum Gladyatör Koloseumu',
    this.wager = 0,
    this.compact = false,
    this.enableShake = true,
    this.enableImpactFlash = true,
    this.onClashImpact,
  });

  final String challengerName;
  final int challengerRating;
  final int challengerPower;
  final String challengerAvatarUrl;
  final int challengerLevel;

  final String defenderName;
  final int defenderRating;
  final int defenderPower;
  final String defenderAvatarUrl;
  final int defenderLevel;

  final String arenaTitle;
  final int wager;
  final bool compact;
  final bool enableShake;
  final bool enableImpactFlash;
  final VoidCallback? onClashImpact;

  @override
  State<PvpVersusSplashBanner> createState() => _PvpVersusSplashBannerState();
}

class _PvpVersusSplashBannerState extends State<PvpVersusSplashBanner>
    with TickerProviderStateMixin {
  late final AnimationController _anim;
  late final AnimationController _flashAnim;
  late final Animation<double> _flashCurve;
  late final DirectionalCameraShake _shakeController;

  DateTime _lastTickTime = DateTime.now();
  double _lastAnimValue = 0.0;

  @override
  void initState() {
    super.initState();
    _shakeController = DirectionalCameraShake();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _flashAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _flashCurve = CurvedAnimation(
      parent: _flashAnim,
      curve: Curves.easeOutQuad,
    );

    _anim.addListener(_onAnimTick);
    _anim.repeat();

    // Trigger initial impact juice on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerClashImpact();
      }
    });
  }

  void _onAnimTick() {
    final DateTime now = DateTime.now();
    final double dt =
        (now.difference(_lastTickTime).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
    _lastTickTime = now;

    if (_shakeController.isActive) {
      _shakeController.update(dt);
    }

    // Trigger clash strike on cycle wrap (t = 0.0) or mid-cycle confrontation (t = 0.5)
    final double currentVal = _anim.value;
    if ((_lastAnimValue > 0.85 && currentVal < 0.15) ||
        (_lastAnimValue < 0.5 && currentVal >= 0.5)) {
      _triggerClashImpact();
    }
    _lastAnimValue = currentVal;
  }

  void _triggerClashImpact() {
    if (!mounted) return;

    if (widget.enableShake) {
      _shakeController.triggerPreset(
        CameraShakePreset(
          name: 'pvpBannerClash',
          trauma: widget.compact ? 0.22 : 0.32,
          config: const CameraShakeConfig(
            traumaExponent: 2.0,
            decayRate: 4.5,
            decayMode: CameraShakeDecayMode.quadratic,
            maxTranslation: Offset(4.0, 3.0),
            maxRoll: 0.012,
            maxPitch: 0.005,
            maxYaw: 0.005,
            baseFrequency: 30.0,
            frequencyModulation: 6.0,
            noiseOctaves: 2,
            directionalBiasWeight: 0.6,
            harmonicDamping: 14.0,
            harmonicFrequency: 28.0,
          ),
        ),
        hitDirection: const Offset(-0.8, -0.4),
      );
    }

    if (widget.enableImpactFlash) {
      _flashAnim.forward(from: 0.0);
    }

    widget.onClashImpact?.call();
  }

  @override
  void dispose() {
    _anim.removeListener(_onAnimTick);
    _anim.dispose();
    _flashAnim.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GladiatorTier challengerTier =
        GladiatorTier.fromRating(widget.challengerRating);
    final GladiatorTier defenderTier =
        GladiatorTier.fromRating(widget.defenderRating);

    final Widget bannerContent = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF080B14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          // 1. Dual Background Gradient (Challenger Cyan vs Defender Crimson)
          Positioned.fill(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          challengerTier.primaryColor.withValues(alpha: 0.28),
                          const Color(0xFF0D1424),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          const Color(0xFF1E0E18),
                          defenderTier.primaryColor.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Dynamic Animated Clash Slash, Sparks, Lightning & Shockwaves
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: VersusClashPainter(
                    animationValue: _anim.value,
                    accentColor: const Color(0xFFFFD700),
                    secondaryColor: const Color(0xFFFF1744),
                    challengerColor: const Color(0xFF00E5FF),
                  ),
                );
              },
            ),
          ),

          // 3. Foreground Duelist Content
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: widget.compact ? 10 : 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Header: Arena Title & Stakes Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.stadium_rounded,
                            size: 13,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.arenaTitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.wager > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.amber.withValues(alpha: 0.25),
                              Colors.amber.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.amber, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text('🪙', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            Text(
                              '${widget.wager} Altın Bahis',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.6,
                          ),
                        ),
                        child: const Text(
                          'Dostluk Maçı',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Main Duelists Confrontation Row
                AnimatedBuilder(
                  animation: _anim,
                  builder: (BuildContext context, Widget? child) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // Left: Challenger Presentation Frame
                        Expanded(
                          child: _FighterProfileBlock(
                            name: widget.challengerName,
                            rating: widget.challengerRating,
                            power: widget.challengerPower,
                            level: widget.challengerLevel,
                            avatarUrl: widget.challengerAvatarUrl,
                            tier: challengerTier,
                            alignLeft: true,
                            compact: widget.compact,
                            animationValue: _anim.value,
                          ),
                        ),

                        // Center: High-Impact VS Badge with Crossed Blades
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _VsBadge(
                            animationProgress: _anim.value,
                            compact: widget.compact,
                          ),
                        ),

                        // Right: Defender Presentation Frame
                        Expanded(
                          child: _FighterProfileBlock(
                            name: widget.defenderName,
                            rating: widget.defenderRating,
                            power: widget.defenderPower,
                            level: widget.defenderLevel,
                            avatarUrl: widget.defenderAvatarUrl,
                            tier: defenderTier,
                            alignLeft: false,
                            compact: widget.compact,
                            animationValue: _anim.value,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. Combat Juice Impact Flash Overlay
          AnimatedBuilder(
            animation: _flashCurve,
            builder: (BuildContext context, Widget? child) {
              final double flashVal = 1.0 - _flashCurve.value;
              if (flashVal <= 0.01) return const SizedBox.shrink();

              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.95,
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.42 * flashVal),
                          const Color(0xFFFFD700).withValues(alpha: 0.22 * flashVal),
                          Colors.transparent,
                        ],
                        stops: const <double>[0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    if (widget.enableShake) {
      return DirectionalCameraShakeHost(
        controller: _shakeController,
        child: bannerContent,
      );
    }

    return bannerContent;
  }
}

/// Ornate dual combatant presentation frame with faceted dark-fantasy borders,
/// tier runic glow, level badges, and dynamic confrontation stance.
class _FighterProfileBlock extends StatelessWidget {
  const _FighterProfileBlock({
    required this.name,
    required this.rating,
    required this.power,
    required this.level,
    required this.avatarUrl,
    required this.tier,
    required this.alignLeft,
    required this.compact,
    this.animationValue = 0.0,
  });

  final String name;
  final int rating;
  final int power;
  final int level;
  final String avatarUrl;
  final GladiatorTier tier;
  final bool alignLeft;
  final bool compact;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final CrossAxisAlignment align =
        alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final TextAlign textAlignment =
        alignLeft ? TextAlign.left : TextAlign.right;

    // Subtle breathing presentation shift towards clash center
    final double breathShift = (alignLeft ? 1.0 : -1.0) *
        1.2 *
        math.sin(animationValue * 2 * math.pi);

    final Color roleColor = alignLeft
        ? const Color(0xFF00E5FF)
        : const Color(0xFFFF5252);

    return Transform.translate(
      offset: Offset(breathShift, 0),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: (alignLeft ? const Color(0xFF0C1424) : const Color(0xFF1E0E18))
              .withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tier.primaryColor.withValues(alpha: 0.28),
            width: 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tier.glowColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Faction / Role Stance Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
                  end: alignLeft ? Alignment.centerRight : Alignment.centerLeft,
                  colors: <Color>[
                    roleColor.withValues(alpha: 0.3),
                    roleColor.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: roleColor.withValues(alpha: 0.6),
                  width: 0.7,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (alignLeft) ...<Widget>[
                    const Text('⚔️', style: TextStyle(fontSize: 8)),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    alignLeft ? 'MEYDAN OKUYAN' : 'SAVUNAN ŞAMPİYON',
                    style: TextStyle(
                      color: roleColor,
                      fontSize: compact ? 7.5 : 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (!alignLeft) ...<Widget>[
                    const SizedBox(width: 3),
                    const Text('🛡️', style: TextStyle(fontSize: 8)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Avatar & Tier Emblem Confrontation Stance
            Row(
              mainAxisAlignment:
                  alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: <Widget>[
                if (!alignLeft) ...<Widget>[
                  GladiatorTierEmblem(tier: tier, size: compact ? 26 : 32),
                  const SizedBox(width: 6),
                ],
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    // Multi-layer Ornate Ring Frame
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: <Color>[
                            tier.primaryColor,
                            Colors.white70,
                            tier.primaryColor,
                            Colors.black54,
                            tier.primaryColor,
                          ],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: tier.glowColor.withValues(alpha: 0.55),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF080C16),
                        ),
                        padding: const EdgeInsets.all(2.0),
                        child: ProfileAvatar(
                          size: compact ? 36 : 46,
                          avatarUrl: avatarUrl,
                        ),
                      ),
                    ),
                    // Level Badge
                    Positioned(
                      bottom: -2,
                      right: alignLeft ? -4 : null,
                      left: alignLeft ? null : -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xEE090D18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: tier.primaryColor.withValues(alpha: 0.8),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Lv.$level',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (alignLeft) ...<Widget>[
                  const SizedBox(width: 6),
                  GladiatorTierEmblem(tier: tier, size: compact ? 26 : 32),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Fighter Name
            Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
                shadows: const <Shadow>[
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlignment,
            ),

            const SizedBox(height: 1),

            // Tier Title
            Text(
              tier.title,
              style: TextStyle(
                color: tier.primaryColor,
                fontSize: compact ? 9.5 : 10,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlignment,
            ),

            const SizedBox(height: 3),

            // MMR and Combat Power
            Wrap(
              alignment: alignLeft ? WrapAlignment.start : WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    '$rating MMR',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: compact ? 9.5 : 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (power > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.white24,
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      '⚔️ $power',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: compact ? 9 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// High-Impact Center VS Badge with crossed swords silhouette, beveled gold rim,
/// and dynamic scale-punch animation.
class _VsBadge extends StatelessWidget {
  const _VsBadge({
    required this.animationProgress,
    this.compact = false,
  });

  final double animationProgress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 42.0 : 50.0;
    // Impact scale bounce
    final double scalePunch =
        1.0 + 0.10 * math.sin(animationProgress * 2 * math.pi).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scalePunch,
      child: SizedBox(
        width: size + 16,
        height: size + 16,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Crossed Gladius Blades Silhouette
            Positioned.fill(
              child: CustomPaint(
                painter: _VsCrossedBladesPainter(
                  animationValue: animationProgress,
                ),
              ),
            ),

            // Outer Fiery Energy Corona
            Container(
              width: size + 4,
              height: size + 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.65),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),

            // Central Medallion
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.2, -0.3),
                  radius: 0.85,
                  colors: <Color>[
                    Color(0xFFFF3D00),
                    Color(0xFFD50000),
                    Color(0xFF880E4F),
                    Color(0xFF1A0006),
                  ],
                  stops: <double>[0.0, 0.4, 0.75, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFFFFD700),
                  width: compact ? 1.6 : 2.0,
                ),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Specular Glint Sweep
                  Transform.rotate(
                    angle: animationProgress * 2 * math.pi,
                    child: Container(
                      width: size * 0.85,
                      height: 2.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // High-Contrast 'VS' Text
                  Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 14 : 17,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.0,
                      shadows: const <Shadow>[
                        Shadow(
                          color: Color(0xFFFF1744),
                          blurRadius: 8,
                        ),
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(1.5, 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mobile Dialog / Bottom Sheet for initiating or previewing a PvP Duel with full versus splash art.
Future<bool?> showPvpVersusSplashModal({
  required BuildContext context,
  required String challengerName,
  required int challengerRating,
  int challengerPower = 0,
  String challengerAvatarUrl = '',
  int challengerLevel = 1,
  required String defenderName,
  required int defenderRating,
  int defenderPower = 0,
  String defenderAvatarUrl = '',
  int defenderLevel = 1,
  String arenaTitle = 'Uçurum Gladyatör Koloseumu',
  int wager = 0,
  String actionButtonText = '⚔️ Düelloyu Başlat!',
  bool enableShake = true,
}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: const Color(0xFF0A0E1A),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: Colors.white24, width: 1.0),
    ),
    builder: (BuildContext ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Sheet Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'DÜELLO EŞLEŞMESİ',
                style: TextStyle(
                  color: Colors.amber.shade400,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              PvpVersusSplashBanner(
                challengerName: challengerName,
                challengerRating: challengerRating,
                challengerPower: challengerPower,
                challengerAvatarUrl: challengerAvatarUrl,
                challengerLevel: challengerLevel,
                defenderName: defenderName,
                defenderRating: defenderRating,
                defenderPower: defenderPower,
                defenderAvatarUrl: defenderAvatarUrl,
                defenderLevel: defenderLevel,
                arenaTitle: arenaTitle,
                wager: wager,
                enableShake: enableShake,
              ),

              const SizedBox(height: 18),

              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Geri'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.of(ctx).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF1744),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        actionButtonText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
