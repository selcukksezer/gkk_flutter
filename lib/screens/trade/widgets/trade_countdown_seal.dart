import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'trade_filigree_frame.dart';

/// 2027 Aion 2 Mobile — Ornate Countdown Confirmation Seal.
/// A high-drama 3-second runic countdown with rotating arcane rings,
/// pulsating countdown digits, frosted dark-glass core lens, and immediate cancel safeguard.
class TradeCountdownSeal extends StatefulWidget {
  const TradeCountdownSeal({
    super.key,
    required this.onComplete,
    required this.onCancel,
    this.durationSeconds = 3,
    this.title = 'TİCARET MÜHÜRLENİYOR',
    this.subtitle = 'Son kontrol! İptal etmek için dokunun.',
    this.accent,
    this.secondaryAccent,
  });

  final FutureOr<void> Function() onComplete;
  final VoidCallback onCancel;
  final int durationSeconds;
  final String title;
  final String subtitle;
  final Color? accent;
  final Color? secondaryAccent;

  @override
  State<TradeCountdownSeal> createState() => _TradeCountdownSealState();
}

class _TradeCountdownSealState extends State<TradeCountdownSeal>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late int _secondsRemaining;
  Timer? _countdownTimer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationSeconds;
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _pulseAnimation = Tween<double>(begin: 1.24, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );

    _pulseController.forward(from: 0.0);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _completed = true;
        });
        _pulseController.forward(from: 0.0);
        widget.onComplete();
      } else {
        setState(() {
          _secondsRemaining -= 1;
        });
        _pulseController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveAccent = widget.accent ?? AppColors.liquidGold;
    final Color effectiveSecondaryAccent =
        widget.secondaryAccent ?? AppColors.accentCyan;
    final double progress = widget.durationSeconds > 0
        ? (_secondsRemaining / widget.durationSeconds).clamp(0.0, 1.0)
        : 0.0;

    return TradeFiligreePanel(
      accent: effectiveAccent,
      secondaryAccent: effectiveSecondaryAccent,
      glowRadius: 18.0,
      glowOpacity: 0.22,
      fillGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppColors.spaceNavy.withValues(alpha: 0.88),
          AppColors.carbonVoid.withValues(alpha: 0.94),
          AppColors.darkObsidian.withValues(alpha: 0.85),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxW = constraints.maxWidth;
          final double sealSize = maxW < 260 ? 98.0 : 116.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Header with glowing arcane icons & overflow safeguard
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome,
                    color: effectiveAccent,
                    size: 14,
                    shadows: <Shadow>[
                      Shadow(
                        color: effectiveAccent.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        style: TextStyle(
                          color: effectiveAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          shadows: <Shadow>[
                            Shadow(
                              color: effectiveAccent.withValues(alpha: 0.55),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.auto_awesome,
                    color: effectiveAccent,
                    size: 14,
                    shadows: <Shadow>[
                      Shadow(
                        color: effectiveAccent.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedTitanium.withValues(alpha: 0.9),
                    fontSize: 11,
                    height: 1.25,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),

              // Arcane Rotating Seal with Countdown Digits
              AnimatedBuilder(
                animation: _rotationController,
                builder: (BuildContext context, Widget? child) {
                  return SizedBox(
                    width: sealSize,
                    height: sealSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // Frosted Glass Core Lens Backing
                        Container(
                          width: sealSize - 20,
                          height: sealSize - 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                AppColors.spaceNavy.withValues(alpha: 0.72),
                                AppColors.carbonVoid.withValues(alpha: 0.92),
                              ],
                              stops: const <double>[0.3, 1.0],
                            ),
                            border: Border.all(
                              color: effectiveSecondaryAccent.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: effectiveAccent.withValues(alpha: 0.16),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),

                        // Glass Specular Crescent Reflection
                        Positioned(
                          top: (sealSize - 20) * 0.12,
                          child: Container(
                            width: (sealSize - 20) * 0.64,
                            height: (sealSize - 20) * 0.26,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.elliptical(
                                  (sealSize - 20) * 0.64,
                                  (sealSize - 20) * 0.26,
                                ),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Rotating Arcane Runic Dial Painter
                        CustomPaint(
                          size: Size(sealSize, sealSize),
                          painter: _ArcaneCountdownPainter(
                            rotation: _rotationController.value * 2 * math.pi,
                            progress: progress,
                            accent: effectiveAccent,
                            secondaryAccent: effectiveSecondaryAccent,
                            completed: _completed,
                          ),
                        ),

                        // Countdown Number / Checkmark
                        SizedBox(
                          width: sealSize * 0.62,
                          height: sealSize * 0.62,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (_completed)
                                  Icon(
                                    Icons.check_circle,
                                    color: effectiveAccent,
                                    size: 40,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: effectiveAccent.withValues(alpha: 0.8),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  )
                                else
                                  ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Text(
                                      '$_secondsRemaining',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        fontFeatures: const <FontFeature>[
                                          FontFeature.tabularFigures(),
                                        ],
                                        shadows: <Shadow>[
                                          Shadow(
                                            color: effectiveAccent,
                                            blurRadius: 16,
                                          ),
                                          Shadow(
                                            color: effectiveSecondaryAccent
                                                .withValues(alpha: 0.8),
                                            blurRadius: 26,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 1),
                                Text(
                                  _completed ? 'TAMAMLANDI' : 'SANİYE',
                                  style: TextStyle(
                                    color: _completed
                                        ? effectiveAccent
                                        : effectiveSecondaryAccent.withValues(alpha: 0.95),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: (_completed
                                                ? effectiveAccent
                                                : effectiveSecondaryAccent)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.base),

              // Cancel Action Safeguard
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _completed
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            _countdownTimer?.cancel();
                            _pulseController.stop();
                            _rotationController.stop();
                            widget.onCancel();
                          },
                    icon: Icon(
                      _completed ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: _completed
                          ? AppColors.mutedTitanium
                          : AppColors.mysticRuby,
                      size: 16,
                    ),
                    label: Text(
                      _completed ? 'İşlem Onaylandı' : 'Mührü İptal Et',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _completed
                            ? AppColors.mutedTitanium
                            : AppColors.mysticRuby,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      side: BorderSide(
                        color: _completed
                            ? AppColors.mutedTitanium.withValues(alpha: 0.25)
                            : AppColors.mysticRuby.withValues(alpha: 0.85),
                        width: 1.2,
                      ),
                      backgroundColor: _completed
                          ? Colors.transparent
                          : AppColors.mysticRuby.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArcaneCountdownPainter extends CustomPainter {
  const _ArcaneCountdownPainter({
    required this.rotation,
    required this.progress,
    required this.accent,
    required this.secondaryAccent,
    required this.completed,
  });

  final double rotation;
  final double progress;
  final Color accent;
  final Color secondaryAccent;
  final bool completed;

  @override
  void paint(Canvas canvas, Size size) {
    final double dim = math.min(size.width, size.height);
    if (dim <= 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (dim / 2) - 6.0;
    if (radius <= 0) return;

    // 1. Frosted Core Glow Aura
    final Paint coreGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          (completed ? accent : secondaryAccent).withValues(alpha: 0.12),
          AppColors.carbonVoid.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 4));
    canvas.drawCircle(center, radius + 4, coreGlow);

    // 2. Outer Track Trench (Metallic dark obsidian with hairline highlight)
    final Paint outerTrack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = AppColors.darkObsidian.withValues(alpha: 0.7);
    canvas.drawCircle(center, radius, outerTrack);

    final Paint innerHairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = secondaryAccent.withValues(alpha: 0.18);
    canvas.drawCircle(center, radius - 4.0, innerHairline);

    // 3. Counter-Rotating Inner Runic Orbit (8 miniature starlight diamonds)
    final double innerRadius = radius - 8.5;
    if (innerRadius > 0) {
      final Paint innerOrbit = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = accent.withValues(alpha: 0.22);
      canvas.drawCircle(center, innerRadius, innerOrbit);

      final double counterRot = -rotation * 0.75;
      const int pipCount = 8;
      final Paint pipPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = (completed ? accent : secondaryAccent).withValues(alpha: 0.65);

      for (int i = 0; i < pipCount; i++) {
        final double pipAngle = counterRot + (i * (2 * math.pi / pipCount));
        final Offset pipPos = Offset(
          center.dx + innerRadius * math.cos(pipAngle),
          center.dy + innerRadius * math.sin(pipAngle),
        );
        _drawSmallDiamond(canvas, pipPos.dx, pipPos.dy, 1.8, pipPaint);
      }
    }

    // 4. Rotating Arcane Rune Compass Ticks (16 divisions with 4 major cardinal diamonds)
    const int tickCount = 16;
    final Paint tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = secondaryAccent.withValues(alpha: 0.65);

    final Paint cardinalDiamondPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: 0.85);

    for (int i = 0; i < tickCount; i++) {
      final double angle = rotation + (i * (2 * math.pi / tickCount));
      final bool isCardinal = (i % 4 == 0);
      final double innerR = radius - (isCardinal ? 9.0 : 6.0);
      final double outerR = radius - (isCardinal ? 2.5 : 4.0);

      final Offset p1 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );
      final Offset p2 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );

      canvas.drawLine(
        p1,
        p2,
        isCardinal
            ? (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = accent)
            : tickPaint,
      );

      if (isCardinal) {
        _drawSmallDiamond(canvas, p1.dx, p1.dy, 1.6, cardinalDiamondPaint);
      }
    }

    // 5. Active Progress Arc (Luxury Cyan -> Liquid Gold -> Gold Light)
    if (progress > 0.001) {
      final double sweepAngle = 2 * math.pi * progress;
      final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

      final Paint progressGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..color = (completed ? accent : secondaryAccent).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweepAngle,
        false,
        progressGlowPaint,
      );

      final Paint progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: (3 * math.pi) / 2,
          colors: <Color>[
            secondaryAccent.withValues(alpha: 0.3),
            secondaryAccent,
            accent,
            AppColors.goldLight,
          ],
          stops: const <double>[0.0, 0.35, 0.80, 1.0],
        ).createShader(arcRect);

      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );

      // 6. Glowing Comet Head / Starlight Node at Arc Tip
      final double headAngle = -math.pi / 2 + sweepAngle;
      final Offset headPos = Offset(
        center.dx + radius * math.cos(headAngle),
        center.dy + radius * math.sin(headAngle),
      );

      final Paint sparkHalo = Paint()
        ..style = PaintingStyle.fill
        ..color = accent.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(headPos, 5.0, sparkHalo);

      final Paint sparkCore = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white;
      canvas.drawCircle(headPos, 2.2, sparkCore);
    }

    // 7. Completed State Celestial Aura
    if (completed) {
      final Paint completedAura = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = accent.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawCircle(center, radius, completedAura);
    }
  }

  void _drawSmallDiamond(Canvas canvas, double cx, double cy, double r, Paint paint) {
    final Path path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcaneCountdownPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.secondaryAccent != secondaryAccent ||
      oldDelegate.completed != completed;
}
