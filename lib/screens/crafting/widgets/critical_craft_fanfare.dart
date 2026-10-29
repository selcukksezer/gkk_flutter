import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';

/// Stat multiplier or perk callout displayed during critical craft fanfare.
class CriticalBonusCallout {
  const CriticalBonusCallout({
    required this.label,
    required this.value,
    this.icon = Icons.auto_awesome,
    this.color = AppColors.liquidGold,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

/// Dynamic celebratory fanfare widget displayed when a critical craft occurs.
///
/// Features:
/// - Rotating 16-ray celestial golden sunburst background with radial gradient.
/// - Elastic bounce entrance with scale & 3D tilt sensation.
/// - Shimmering Archon gold & astral cyan header banner with crown/flame icon.
/// - Ambient drifting starry motes.
/// - Stat bonus badges (e.g., "+50% Ekstra Eşya", "2x Miktar", "Kusursuz Kalite").
/// - Built-in haptic vibration trigger and audio playback hook.
/// - Configurable auto-dismiss or interactive dismiss button.
class CriticalCraftFanfare extends StatefulWidget {
  const CriticalCraftFanfare({
    super.key,
    this.title = 'KRİTİK BAŞARI!',
    this.subtitle = 'Kusursuz İşçilik ile Üretildi',
    this.bonusCallouts = const <CriticalBonusCallout>[
      CriticalBonusCallout(
        label: 'Verim Artışı',
        value: '+50%',
        icon: Icons.trending_up,
      ),
      CriticalBonusCallout(
        label: 'Zanaat Deneyimi',
        value: '2x DP',
        icon: Icons.bolt,
        color: AppColors.accentCyan,
      ),
    ],
    this.autoDismissDuration,
    this.onDismiss,
    this.onPlaySound,
    this.enableHaptics = true,
    this.showDismissButton = true,
  });

  final String title;
  final String subtitle;
  final List<CriticalBonusCallout> bonusCallouts;
  final Duration? autoDismissDuration;
  final VoidCallback? onDismiss;
  final VoidCallback? onPlaySound;
  final bool enableHaptics;
  final bool showDismissButton;

  @override
  State<CriticalCraftFanfare> createState() => _CriticalCraftFanfareState();
}

class _CriticalCraftFanfareState extends State<CriticalCraftFanfare>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _motesController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  final List<_MoteParticle> _motes = <_MoteParticle>[];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _motesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _initMotes();

    // Trigger entrance & haptics
    _entranceController.forward();
    if (widget.enableHaptics) {
      AionHaptics.craftSuccess();
    }
    widget.onPlaySound?.call();

    if (widget.autoDismissDuration != null) {
      Future<void>.delayed(widget.autoDismissDuration!, () {
        if (mounted) widget.onDismiss?.call();
      });
    }
  }

  void _initMotes() {
    for (int i = 0; i < 24; i++) {
      _motes.add(
        _MoteParticle(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          speed: 0.15 + _rng.nextDouble() * 0.35,
          size: 2.0 + _rng.nextDouble() * 3.5,
          alpha: 0.2 + _rng.nextDouble() * 0.7,
        ),
      );
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _motesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // 1. Rotating sunburst rays behind banner
            AnimatedBuilder(
              animation: _rotationController,
              builder: (BuildContext context, Widget? child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: CustomPaint(
                    size: const Size(360, 360),
                    painter: _SunburstRaysPainter(
                      rayCount: 16,
                      primaryColor: AppColors.liquidGold.withValues(alpha: 0.22),
                      secondaryColor: AppColors.accentCyan.withValues(alpha: 0.12),
                    ),
                  ),
                );
              },
            ),

            // 2. Drifting magical motes
            AnimatedBuilder(
              animation: _motesController,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  size: const Size(340, 280),
                  painter: _MotesPainter(
                    motes: _motes,
                    progress: _motesController.value,
                  ),
                );
              },
            ),

            // 3. Main Fanfare Badge & Banner
            ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (BuildContext context, Widget? child) {
                  final double pulse = _pulseController.value;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.carbonVoid.withValues(alpha: 0.94),
                          AppColors.spaceNavy.withValues(alpha: 0.96),
                          AppColors.carbonVoid.withValues(alpha: 0.94),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Color.lerp(
                          AppColors.liquidGold,
                          AppColors.accentCyan,
                          pulse * 0.5,
                        )!,
                        width: 1.8,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.liquidGold.withValues(alpha: 0.35 + pulse * 0.25),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.accentCyan.withValues(alpha: 0.2),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Glowing Archon Emblem / Crown
                        _FanfareEmblem(pulse: pulse),

                        const SizedBox(height: 12),

                        // Title with gold gradient
                        ShaderMask(
                          shaderCallback: (Rect bounds) => LinearGradient(
                            colors: <Color>[
                              AppColors.goldLight,
                              AppColors.liquidGold,
                              const Color(0xFFFFD54F),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            widget.title,
                            style: AppTextStyles.h1.copyWith(
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: <Shadow>[
                                Shadow(
                                  color: AppColors.liquidGold.withValues(alpha: 0.8),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Subtitle
                        Text(
                          widget.subtitle,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.mutedTitanium,
                            letterSpacing: 0.6,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Bonus Callout Badges
                        if (widget.bonusCallouts.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: widget.bonusCallouts.map((CriticalBonusCallout bonus) {
                              return _BonusBadge(bonus: bonus);
                            }).toList(),
                          ),
                        ],

                        // Optional Dismiss Button
                        if (widget.showDismissButton) ...<Widget>[
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              AionHaptics.slotSelect();
                              widget.onDismiss?.call();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: <Color>[
                                    AppColors.liquidGold,
                                    AppColors.goldLight,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.liquidGold.withValues(alpha: 0.45),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Devam Et',
                                style: AppTextStyles.dialogButton.copyWith(
                                  color: AppColors.bgDeep,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glowing Emblem for the Fanfare banner.
class _FanfareEmblem extends StatelessWidget {
  const _FanfareEmblem({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            AppColors.liquidGold.withValues(alpha: 0.35 + pulse * 0.35),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.military_tech_rounded,
          color: AppColors.liquidGold,
          size: 32 + pulse * 2.5,
        ),
      ),
    );
  }
}

/// Callout badge rendering an individual bonus stat.
class _BonusBadge extends StatelessWidget {
  const _BonusBadge({required this.bonus});

  final CriticalBonusCallout bonus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkObsidian.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: bonus.color.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(bonus.icon, size: 16, color: bonus.color),
          const SizedBox(width: 6),
          Text(
            '${bonus.label}: ',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            bonus.value,
            style: AppTextStyles.caption.copyWith(
              color: bonus.color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter for rotating celestial light beams.
class _SunburstRaysPainter extends CustomPainter {
  _SunburstRaysPainter({
    required this.rayCount,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final int rayCount;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    final double radius = size.width * 0.5;
    final double angleStep = (2 * math.pi) / rayCount;

    for (int i = 0; i < rayCount; i++) {
      if (i.isOdd) continue; // alternating rays for high-contrast fan pattern

      final double startAngle = i * angleStep;
      final double sweepAngle = angleStep * 0.65;

      final Path path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            i % 4 == 0 ? primaryColor : secondaryColor,
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunburstRaysPainter oldDelegate) => false;
}

class _MoteParticle {
  _MoteParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.alpha,
  });

  final double x;
  final double y;
  final double speed;
  final double size;
  final double alpha;
}

class _MotesPainter extends CustomPainter {
  _MotesPainter({
    required this.motes,
    required this.progress,
  });

  final List<_MoteParticle> motes;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    for (final _MoteParticle mote in motes) {
      final double currentY = (mote.y - progress * mote.speed) % 1.0;
      final double dy = currentY * size.height;
      final double dx = mote.x * size.width + math.sin((progress + mote.x) * math.pi * 2) * 12.0;

      paint
        ..color = AppColors.goldLight.withValues(alpha: mote.alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(dx, dy), mote.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MotesPainter oldDelegate) => true;
}
