import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/restriction/restriction_screen_ui.dart';
import '../../../core/utils/player_health.dart';
import '../../../core/utils/restriction_reason_labels.dart';
import '../../../models/player_model.dart';
import '../../../theme/app_colors.dart';

/// Aion 2 Sanctuary Glass Container with translucent frosted layers,
/// restorative cyan/emerald luminous borders, subtle inner glow, and ornate Aion 2 HUD ornamentation.
class SanctuaryGlassCard extends StatelessWidget {
  const SanctuaryGlassCard({
    super.key,
    required this.child,
    this.accent = AppColors.accentCyan,
    this.secondaryAccent = const Color(0xFF10B981),
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 18.0,
    this.showGlow = true,
    this.isRestorative = true,
    this.showOrnateCorners = true,
  });

  final Widget child;
  final Color accent;
  final Color secondaryAccent;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool showGlow;
  final bool isRestorative;
  final bool showOrnateCorners;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accent.withValues(alpha: isRestorative ? 0.42 : 0.35),
          width: 1.2,
        ),
        boxShadow: showGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
                if (isRestorative)
                  BoxShadow(
                    color: secondaryAccent.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 2),
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isRestorative
              ? <Color>[
                  accent.withValues(alpha: 0.12),
                  AppColors.spaceNavy.withValues(alpha: 0.88),
                  AppColors.carbonVoid.withValues(alpha: 0.96),
                ]
              : <Color>[
                  AppColors.spaceNavy.withValues(alpha: 0.90),
                  AppColors.carbonVoid.withValues(alpha: 0.96),
                ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 14, dotOpacity: 0.05),
                ),
              ),
              Positioned.fill(
                child: Image.asset(
                  'assets/images/aion2_ui/hud_tooltip_frame.png',
                  fit: BoxFit.cover,
                  opacity: const AlwaysStoppedAnimation<double>(0.07),
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              if (showOrnateCorners) ...<Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  child: _GlassCornerOrnament(color: accent),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.flip(
                    flipX: true,
                    child: _GlassCornerOrnament(color: secondaryAccent),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Transform.flip(
                    flipY: true,
                    child: _GlassCornerOrnament(color: secondaryAccent),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Transform.flip(
                    flipX: true,
                    flipY: true,
                    child: _GlassCornerOrnament(color: accent),
                  ),
                ),
              ],
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCornerOrnament extends StatelessWidget {
  const _GlassCornerOrnament({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(18, 18),
      painter: _CornerBracketPainter(color: color),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    path.moveTo(size.width, 2);
    path.lineTo(2, 2);
    path.lineTo(2, size.height);
    canvas.drawPath(path, paint);

    final Paint pipPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(3, 3), 1.2, pipPaint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Dynamic animated liquid recovery gauge with simulated fluid physics,
/// two sine-wave layers, floating bubbles, live ECG cardiac waveform pulse,
/// and status threshold markers.
class LiquidRecoveryGauge extends StatefulWidget {
  const LiquidRecoveryGauge({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentValue,
    required this.maxValue,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentGlow,
    this.unit = '',
    this.showThresholds = false,
    this.combatThreshold = 0.20,
    this.woundedThreshold = 0.50,
    this.height = 80.0,
    this.auxiliaryTag,
    this.statusColor,
    this.showEcgWave = true,
  });

  final String title;
  final String subtitle;
  final int currentValue;
  final int maxValue;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentGlow;
  final String unit;
  final bool showThresholds;
  final double combatThreshold;
  final double woundedThreshold;
  final double height;
  final String? auxiliaryTag;
  final Color? statusColor;
  final bool showEcgWave;

  @override
  State<LiquidRecoveryGauge> createState() => _LiquidRecoveryGaugeState();
}

class _LiquidRecoveryGaugeState extends State<LiquidRecoveryGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getCardiacBpm(double fraction) {
    if (fraction < 0.20) return '122 BPM · Kritik / Aritmi';
    if (fraction < 0.50) return '94 BPM · Doku Hasarı';
    return '72 BPM · Stabil Sinüs Ritmi';
  }

  @override
  Widget build(BuildContext context) {
    final double safeMax = math.max(1.0, widget.maxValue.toDouble());
    final double fraction =
        (widget.currentValue / safeMax).clamp(0.0, 1.0);
    final int percent = (fraction * 100).round();
    final String cardiacStatus = _getCardiacBpm(fraction);

    return Semantics(
      label:
          '${widget.title}: ${widget.currentValue}/${widget.maxValue}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''} ($percent%). ${widget.subtitle}. $cardiacStatus',
      value: '$percent%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.monitor_heart_rounded,
                    size: 16,
                    color: widget.statusColor ?? widget.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (widget.auxiliaryTag != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (widget.statusColor ?? widget.primaryColor)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (widget.statusColor ?? widget.primaryColor)
                              .withValues(alpha: 0.40),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.auxiliaryTag!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.statusColor ?? widget.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.statusColor ?? widget.primaryColor,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (widget.statusColor ?? widget.primaryColor)
                              .withValues(alpha: 0.8),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.currentValue}/${widget.maxValue}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''} ($percent%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: widget.statusColor ?? widget.primaryColor,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.accentGlow.withValues(alpha: 0.35),
                width: 1.0,
              ),
              color: AppColors.carbonVoid.withValues(alpha: 0.85),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: widget.accentGlow.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (BuildContext context, _) {
                      return CustomPaint(
                        size: Size(double.infinity, widget.height),
                        painter: _LiquidWavePainter(
                          progress: fraction,
                          wavePhase: _animController.value * 2 * math.pi,
                          primaryColor: widget.primaryColor,
                          secondaryColor: widget.secondaryColor,
                        ),
                      );
                    },
                  ),
                  if (widget.showEcgWave)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (BuildContext context, _) {
                          return CustomPaint(
                            painter: _EcgWaveformPainter(
                              phase: _animController.value,
                              color: widget.accentGlow,
                            ),
                          );
                        },
                      ),
                    ),
                  if (widget.showThresholds) ...<Widget>[
                    Positioned(
                      left: 0,
                      right: 0,
                      top: widget.height * (1.0 - widget.combatThreshold),
                      child: Container(
                        height: 1,
                        color: AppColors.coralFlare.withValues(alpha: 0.45),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: widget.height * (1.0 - widget.woundedThreshold),
                      child: Container(
                        height: 1,
                        color: AppColors.liquidGold.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.10),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                          stops: const <double>[0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                            shadows: const <Shadow>[
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '·  $cardiacStatus',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: widget.accentGlow.withValues(alpha: 0.90),
                            shadows: const <Shadow>[
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
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
  }
}

class _EcgWaveformPainter extends CustomPainter {
  _EcgWaveformPainter({
    required this.phase,
    required this.color,
    this.strokeWidth = 1.4,
  });

  final double phase;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double midY = h * 0.5;

    final Paint linePaint = Paint()
      ..color = color.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path();
    bool first = true;

    const double cycleWidth = 140.0;
    final double offset = phase * cycleWidth;

    for (double x = 0; x <= w + 4; x += 3) {
      final double cycleX = (x + offset) % cycleWidth;
      final double normalizedX = cycleX / cycleWidth;

      double yOffset = 0.0;
      if (normalizedX > 0.15 && normalizedX <= 0.25) {
        yOffset = -math.sin((normalizedX - 0.15) / 0.10 * math.pi) * (h * 0.16);
      } else if (normalizedX > 0.32 && normalizedX <= 0.35) {
        yOffset = ((normalizedX - 0.32) / 0.03) * (h * 0.12);
      } else if (normalizedX > 0.35 && normalizedX <= 0.42) {
        final double rProg = (normalizedX - 0.35) / 0.07;
        if (rProg < 0.5) {
          yOffset = (h * 0.12) - (rProg * 2.0) * (h * 0.50);
        } else {
          yOffset = -(h * 0.38) + ((rProg - 0.5) * 2.0) * (h * 0.60);
        }
      } else if (normalizedX > 0.42 && normalizedX <= 0.46) {
        final double sProg = (normalizedX - 0.42) / 0.04;
        yOffset = (h * 0.22) * (1.0 - sProg);
      } else if (normalizedX > 0.55 && normalizedX <= 0.72) {
        yOffset = -math.sin((normalizedX - 0.55) / 0.17 * math.pi) * (h * 0.20);
      }

      final double y = (midY + yOffset).clamp(2.0, h - 2.0);
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    final double dotX = ((w * 0.70) + offset) % w;
    final Paint dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawCircle(Offset(dotX, midY), 3.0, glowPaint);
    canvas.drawCircle(Offset(dotX, midY), 1.6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _EcgWaveformPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.color != color;
  }
}

class _LiquidWavePainter extends CustomPainter {
  _LiquidWavePainter({
    required this.progress,
    required this.wavePhase,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final double progress;
  final double wavePhase;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final double width = size.width;
    final double height = size.height;
    final double baseWaterY = height * (1.0 - progress);

    final Path backPath = Path();
    final double backAmp = math.min(5.0, height * 0.08);
    backPath.moveTo(0, height);
    backPath.lineTo(0, baseWaterY);
    for (double x = 0; x <= width; x += 4) {
      final double y = baseWaterY +
          math.sin((x / width * 3 * math.pi) + wavePhase + 1.2) * backAmp;
      backPath.lineTo(x, y);
    }
    backPath.lineTo(width, height);
    backPath.close();

    final Paint backPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          secondaryColor.withValues(alpha: 0.55),
          secondaryColor.withValues(alpha: 0.80),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(backPath, backPaint);

    final Path frontPath = Path();
    final double frontAmp = math.min(6.5, height * 0.10);
    frontPath.moveTo(0, height);
    frontPath.lineTo(0, baseWaterY);
    for (double x = 0; x <= width; x += 4) {
      final double y = baseWaterY +
          math.sin((x / width * 2.5 * math.pi) + wavePhase) * frontAmp;
      frontPath.lineTo(x, y);
    }
    frontPath.lineTo(width, height);
    frontPath.close();

    final Paint frontPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          primaryColor.withValues(alpha: 0.85),
          secondaryColor.withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(frontPath, frontPaint);

    final Paint crestPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Path crestPath = Path();
    crestPath.moveTo(0, baseWaterY + math.sin(wavePhase) * frontAmp);
    for (double x = 0; x <= width; x += 4) {
      final double y = baseWaterY +
          math.sin((x / width * 2.5 * math.pi) + wavePhase) * frontAmp;
      crestPath.lineTo(x, y);
    }
    canvas.drawPath(crestPath, crestPaint);

    // Bioluminescent rising micro-bubbles
    final Paint bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    const List<double> bubbleXFractions = <double>[0.16, 0.35, 0.52, 0.70, 0.86];
    for (int i = 0; i < bubbleXFractions.length; i++) {
      final double bx = width * bubbleXFractions[i];
      final double bSpeed = 0.7 + (i % 3) * 0.35;
      final double bPhase = (wavePhase * 0.22 * bSpeed + i * 0.28) % 1.0;
      final double by = height - bPhase * (height - baseWaterY);
      if (by > baseWaterY + 3 && by < height) {
        final double bRadius = 1.0 + (i % 2) * 0.8;
        canvas.drawCircle(Offset(bx, by), bRadius, bubblePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

/// Circular / Orb vital sign gauge framed by authentic Aion 2 HUD health orb frame asset.
class GlowingVitalOrbGauge extends StatefulWidget {
  const GlowingVitalOrbGauge({
    super.key,
    required this.currentHealth,
    required this.maxHealth,
    this.isHealing = false,
    this.size = 68.0,
  });

  final int currentHealth;
  final int maxHealth;
  final bool isHealing;
  final double size;

  @override
  State<GlowingVitalOrbGauge> createState() => _GlowingVitalOrbGaugeState();
}

class _GlowingVitalOrbGaugeState extends State<GlowingVitalOrbGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeMax = math.max(1.0, widget.maxHealth.toDouble());
    final double fraction = (widget.currentHealth / safeMax).clamp(0.0, 1.0);
    final int percent = (fraction * 100).round();

    final Color coreColor = fraction < 0.20
        ? const Color(0xFFEA2143)
        : (fraction < 0.50
            ? const Color(0xFFF97316)
            : const Color(0xFF10B981));

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, _) {
        final double pulse = _pulseAnimation.value;
        final double glowAlpha = (0.22 + 0.22 * pulse).clamp(0.0, 1.0);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: widget.size * (0.82 + 0.16 * pulse),
                height: widget.size * (0.82 + 0.16 * pulse),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: coreColor.withValues(alpha: glowAlpha),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Container(
                width: widget.size * 0.70,
                height: widget.size * 0.70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.carbonVoid.withValues(alpha: 0.90),
                  border: Border.all(
                    color: coreColor.withValues(alpha: 0.50),
                    width: 1.0,
                  ),
                ),
                child: ClipOval(
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: widget.size * 0.70 * fraction,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                coreColor.withValues(alpha: 0.85),
                                coreColor.withValues(alpha: 0.98),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Image.asset(
                'assets/images/aion2_ui/hud_health_orb_frame.png',
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Visual cost badge indicating resource requirements (gems, free allowance,
/// time speedup, ads, or guild doctor assistance) with AAA neon styling.
class HealingCostBadge extends StatelessWidget {
  const HealingCostBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.backgroundColor,
    this.isGlowing = false,
    this.fontSize = 10.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
  });

  factory HealingCostBadge.free({
    required int remaining,
    int total = 2,
    double fontSize = 10.0,
  }) {
    return HealingCostBadge(
      label: 'ÜCRETSİZ ($remaining/$total Hak)',
      icon: Icons.auto_awesome_rounded,
      accentColor: AppColors.toxicNeon,
      backgroundColor: AppColors.toxicNeon.withValues(alpha: 0.16),
      isGlowing: true,
      fontSize: fontSize,
    );
  }

  factory HealingCostBadge.gems({
    required int gems,
    bool affordable = true,
    double fontSize = 10.0,
  }) {
    final Color color =
        affordable ? AppColors.accentPurple : AppColors.coralFlare;
    return HealingCostBadge(
      label: '$gems Elmas',
      icon: Icons.diamond_rounded,
      accentColor: color,
      backgroundColor: color.withValues(alpha: 0.16),
      isGlowing: affordable,
      fontSize: fontSize,
    );
  }

  factory HealingCostBadge.adBypass({
    String label = '−30 Dk Hızlandırma',
    double fontSize = 10.0,
  }) {
    return HealingCostBadge(
      label: label,
      icon: Icons.play_circle_fill_rounded,
      accentColor: AppColors.liquidGold,
      backgroundColor: AppColors.liquidGold.withValues(alpha: 0.16),
      isGlowing: true,
      fontSize: fontSize,
    );
  }

  factory HealingCostBadge.guild({
    String label = 'Lonca Protokolü',
    double fontSize = 10.0,
  }) {
    return HealingCostBadge(
      label: label,
      icon: Icons.shield_rounded,
      accentColor: AppColors.accentCyan,
      backgroundColor: AppColors.accentCyan.withValues(alpha: 0.16),
      fontSize: fontSize,
    );
  }

  factory HealingCostBadge.time({
    required String duration,
    String? delta,
    double fontSize = 10.0,
  }) {
    return HealingCostBadge(
      label: delta != null ? '$duration ($delta)' : duration,
      icon: Icons.timer_rounded,
      accentColor: AppColors.accentBlue,
      backgroundColor: AppColors.accentBlue.withValues(alpha: 0.16),
      fontSize: fontSize,
    );
  }

  factory HealingCostBadge.risk({
    required String label,
    double fontSize = 10.0,
  }) {
    return HealingCostBadge(
      label: label,
      icon: Icons.warning_amber_rounded,
      accentColor: AppColors.coralFlare,
      backgroundColor: AppColors.coralFlare.withValues(alpha: 0.18),
      fontSize: fontSize,
    );
  }

  final String label;
  final IconData icon;
  final Color accentColor;
  final Color? backgroundColor;
  final bool isGlowing;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: isGlowing ? 0.65 : 0.35),
          width: 0.9,
        ),
        boxShadow: isGlowing
            ? <BoxShadow>[
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: fontSize + 2, color: accentColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// AAA Doctor Advisory Notes with clinical severity codes, class-specific
/// physiological prognosis, hospital reason context, and expandable vital report.
class DoctorAdvisoryNotes extends StatefulWidget {
  const DoctorAdvisoryNotes({
    super.key,
    required this.healthStatus,
    required this.inHospital,
    required this.healthRatio,
    this.hospitalReason,
    this.characterClass,
    this.alchemistRegenBonus = false,
  });

  final PlayerHealthStatus healthStatus;
  final bool inHospital;
  final double healthRatio;
  final String? hospitalReason;
  final CharacterClass? characterClass;
  final bool alchemistRegenBonus;

  @override
  State<DoctorAdvisoryNotes> createState() => _DoctorAdvisoryNotesState();
}

class _DoctorAdvisoryNotesState extends State<DoctorAdvisoryNotes> {
  bool _expandedVitals = false;

  String _getTriageCode() {
    if (widget.inHospital ||
        widget.healthStatus == PlayerHealthStatus.critical) {
      return 'KOD KIRMIZI: Hayati Risk';
    }
    if (widget.healthStatus == PlayerHealthStatus.wounded) {
      return 'KOD TURUNCU: Ağır Doku Zedelenmesi';
    }
    if (widget.healthStatus == PlayerHealthStatus.recovering) {
      return 'KOD SARI: İyileşme / Rejenerasyon';
    }
    return 'KOD YEŞİL: Muharebeye Hazır';
  }

  Color _getTriageColor() {
    if (widget.inHospital ||
        widget.healthStatus == PlayerHealthStatus.critical) {
      return const Color(0xFFEA2143);
    }
    if (widget.healthStatus == PlayerHealthStatus.wounded) {
      return const Color(0xFFE89558);
    }
    if (widget.healthStatus == PlayerHealthStatus.recovering) {
      return AppColors.accentBlue;
    }
    return AppColors.toxicNeon;
  }

  String _getClassSpecificDiagnosis() {
    return switch (widget.characterClass) {
      CharacterClass.alchemist =>
        'Simyager metabolizması tespit edildi: Pasif hücre yenilenme hızı +%50 daha yüksek. Şifa iksirlerinin vücutta emilimi mükemmel.',
      CharacterClass.warrior =>
        'Savaşçı fizyolojisi: Ağır zırh darbe izleri ve kas travması mevcut. Kemik çatlakları dinlenmeyle kaynaşacaktır.',
      CharacterClass.shadow =>
        'Gölge / Suikastçı sinir sistemi: Refleks sinapsları sağlam. Ani hareketler doku kanamasına yol açabileceğinden dikkatli olunuz.',
      null =>
        'Standart macera bünyesi: Vital bulgular kararlı ritimde toparlanma eğiliminde.',
    };
  }

  String _getClinicalAdvisory() {
    if (widget.inHospital) {
      final String reason = labelHospitalReason(widget.hospitalReason);
      return 'Klinik Protokolü devrede ($reason). Hücre yapısı yeniden organize ediliyor; pasif can yenilenmesi hastane süresince duraklatılmıştır.';
    }
    if (widget.healthStatus == PlayerHealthStatus.critical) {
      return 'Vital değerler tehlikeli düzeyde düşmüş (%${(widget.healthRatio * 100).round()}). Savaşa veya arenaya giriş yasaklanmıştır.';
    }
    if (widget.healthStatus == PlayerHealthStatus.wounded) {
      return 'Orta şiddette travma tablosu mevcut. PvP saldırı etkinliğinde %5 güç kaybı yaşanmaktadır. Acil pansuman veya iksir tavsiye edilir.';
    }
    if (widget.healthStatus == PlayerHealthStatus.recovering) {
      return 'Hücresel toparlanma devam ediyor. Beden doğal akışında sağlığına kavuşmakta. Süreci elmas veya dinlenmeyle kısaltabilirsiniz.';
    }
    return 'Beden ve ruh formunun zirvesinde. Hiçbir akut veya kronik zedelenme kalmamıştır. Zindanlara ve turnuvaya hazırsınız.';
  }

  @override
  Widget build(BuildContext context) {
    final Color triageClr = _getTriageColor();
    final String triageCode = _getTriageCode();

    return SanctuaryGlassCard(
      accent: triageClr,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: triageClr.withValues(alpha: 0.18),
                  border: Border.all(color: triageClr.withValues(alpha: 0.40)),
                ),
                child: Icon(
                  Icons.monitor_heart_rounded,
                  size: 18,
                  color: triageClr,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Başhekim Teşhis & Klinik Notu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      triageCode,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: triageClr,
                      ),
                    ),
                  ],
                ),
              ),
              RestrictionPressable(
                onTap: () {
                  if (!mounted) return;
                  setState(() => _expandedVitals = !_expandedVitals);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: triageClr.withValues(alpha: 0.12),
                    border: Border.all(
                      color: triageClr.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _expandedVitals ? 'Gizle' : 'Vital Rapor',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: triageClr,
                        ),
                      ),
                      Icon(
                        _expandedVitals
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: triageClr,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.carbonVoid.withValues(alpha: 0.65),
              border: Border.all(
                color: AppColors.borderFaint,
                width: 0.8,
              ),
            ),
            child: Text(
              _getClinicalAdvisory(),
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (_expandedVitals) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: triageClr.withValues(alpha: 0.06),
                border: Border.all(
                  color: triageClr.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _getClassSpecificDiagnosis(),
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: triageClr.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _VitalMetricItem(
                        label: 'Kalp Ritmi',
                        value: widget.healthRatio < 0.20
                            ? '122 BPM (Aritmik)'
                            : (widget.healthRatio < 0.50
                                ? '98 BPM'
                                : '72 BPM (Stabil)'),
                        color: triageClr,
                      ),
                      _VitalMetricItem(
                        label: 'Doku Onarımı',
                        value: widget.alchemistRegenBonus
                            ? '+7.5%/saat'
                            : '+5.0%/saat',
                        color: AppColors.toxicNeon,
                      ),
                      _VitalMetricItem(
                        label: 'Toksisite',
                        value: '%0 (Temiz)',
                        color: AppColors.accentCyan,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VitalMetricItem extends StatelessWidget {
  const _VitalMetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Animated Healing Progress Pulse indicator demonstrating active restorative
/// metabolic cycles, cellular regeneration rate, and ETA to full restoration.
class HealingProgressPulse extends StatefulWidget {
  const HealingProgressPulse({
    super.key,
    required this.inHospital,
    required this.isHealing,
    required this.regenPerHour,
    required this.regenEta,
    required this.healthRatio,
    this.characterClass,
  });

  final bool inHospital;
  final bool isHealing;
  final double regenPerHour;
  final String regenEta;
  final double healthRatio;
  final CharacterClass? characterClass;

  @override
  State<HealingProgressPulse> createState() => _HealingProgressPulseState();
}

class _HealingProgressPulseState extends State<HealingProgressPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _expandedDetails = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color activeGreen = Color(0xFF10B981);
    const Color activeCyan = Color(0xFF06D0D8);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, _) {
        final double pulse = _pulseAnimation.value;

        return SanctuaryGlassCard(
          accent: activeCyan,
          secondaryAccent: activeGreen,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Container(
                        width: 32 + 10 * pulse,
                        height: 32 + 10 * pulse,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeCyan.withValues(
                              alpha: (0.20 * (1.0 - pulse * 0.5)).clamp(0.0, 1.0)),
                          border: Border.all(
                            color: activeGreen.withValues(
                                alpha: 0.35 * (1.0 - pulse * 0.3)),
                            width: 1.0,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeGreen.withValues(alpha: 0.18),
                          border: Border.all(
                            color: activeCyan.withValues(alpha: 0.60),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          widget.inHospital
                              ? Icons.hourglass_top_rounded
                              : (widget.isHealing
                                  ? Icons.auto_awesome_rounded
                                  : Icons.spa_rounded),
                          size: 16,
                          color: activeCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              widget.inHospital
                                  ? 'Klinik İyileşme Protokolü'
                                  : 'Hücresel Rejenerasyon Nabzı',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: activeGreen.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: activeGreen.withValues(alpha: 0.40),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                widget.inHospital ? 'KLİNİK' : 'CANLI AKIŞ',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: activeGreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.inHospital
                              ? 'Hastane gözetiminde arınma sürüyor'
                              : 'Rejenerasyon Hızı: +${widget.regenPerHour.toStringAsFixed(1)}%/saat · Tam Dolum: ${widget.regenEta}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary.withValues(alpha: 0.90),
                          ),
                        ),
                      ],
                    ),
                  ),
                  RestrictionPressable(
                    onTap: () {
                      if (!mounted) return;
                      HapticFeedback.lightImpact();
                      setState(() => _expandedDetails = !_expandedDetails);
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: activeCyan.withValues(alpha: 0.12),
                        border: Border.all(
                          color: activeCyan.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _expandedDetails ? 'Kapat' : 'Detay',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: activeCyan,
                            ),
                          ),
                          Icon(
                            _expandedDetails
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: activeCyan,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_expandedDetails) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.carbonVoid.withValues(alpha: 0.65),
                    border: Border.all(
                      color: activeCyan.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _VitalMetricItem(
                            label: 'Metabolik Hız',
                            value: '+${widget.regenPerHour.toStringAsFixed(1)}%/saat',
                            color: activeGreen,
                          ),
                          _VitalMetricItem(
                            label: 'Tam İyileşme ETA',
                            value: widget.regenEta,
                            color: activeCyan,
                          ),
                          _VitalMetricItem(
                            label: 'Rejenerasyon Katsayısı',
                            value: widget.characterClass == CharacterClass.alchemist
                                ? '1.5x (Simyager)'
                                : '1.0x (Normal)',
                            color: AppColors.liquidGold,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.inHospital
                            ? 'Klinik yatağında pasif can yenilenmesi askıya alınmış olup, kutsal taburcu ve doktor muayenesi ile bu süre doğrudan kısaltılabilir.'
                            : 'Bedeniniz doğanın saf enerjisiyle saniyede kesintisiz hücre onarımı yapmaktadır. Dinlenirken veya iksir içerek süreci katlayabilirsiniz.',
                        style: const TextStyle(
                          fontSize: 9.5,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Interactive Elixir Dosage Selector with haptic touches, real-time restorative
/// gain preview (HP / Energy), dosage potency tiers, and tactile dosage administration.
class ElixirDosageSelector extends StatefulWidget {
  const ElixirDosageSelector({
    super.key,
    required this.currentHealth,
    required this.maxHealth,
    required this.currentEnergy,
    required this.maxEnergy,
    required this.inHospital,
    required this.isHealing,
    this.onApplyDosage,
  });

  final int currentHealth;
  final int maxHealth;
  final int currentEnergy;
  final int maxEnergy;
  final bool inHospital;
  final bool isHealing;
  final void Function(int dosagePercent)? onApplyDosage;

  @override
  State<ElixirDosageSelector> createState() => _ElixirDosageSelectorState();
}

class _ElixirDosageSelectorState extends State<ElixirDosageSelector> {
  int _selectedPercent = 50;
  bool _isApplying = false;
  bool _justApplied = false;

  void _selectDosage(int percent) {
    if (_selectedPercent == percent) return;
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      _selectedPercent = percent;
      _justApplied = false;
    });
  }

  Future<void> _handleApply() async {
    if (_isApplying || widget.isHealing) return;
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _isApplying = true);

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    setState(() {
      _isApplying = false;
      _justApplied = true;
    });
    HapticFeedback.heavyImpact();
    widget.onApplyDosage?.call(_selectedPercent);
  }

  @override
  Widget build(BuildContext context) {
    final int missingHp = math.max(0, widget.maxHealth - widget.currentHealth);
    final int restoredHp = (missingHp * (_selectedPercent / 100.0)).round();
    final int projectedHp = math.min(widget.maxHealth, widget.currentHealth + restoredHp);

    final int missingEnergy = math.max(0, widget.maxEnergy - widget.currentEnergy);
    final int restoredEnergy = (missingEnergy * (_selectedPercent / 100.0)).round();
    final int projectedEnergy = math.min(widget.maxEnergy, widget.currentEnergy + restoredEnergy);

    return SanctuaryGlassCard(
      accent: const Color(0xFF06D0D8),
      secondaryAccent: const Color(0xFF10B981),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.science_rounded,
                    size: 16,
                    color: Color(0xFF06D0D8),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Kutsal İksir Dozaj Seçici',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF06D0D8).withValues(alpha: 0.16),
                  border: Border.all(
                    color: const Color(0xFF06D0D8).withValues(alpha: 0.40),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '%$_selectedPercent DOZ',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF06D0D8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _DosagePill(
                percent: 25,
                label: 'Mikro',
                selected: _selectedPercent == 25,
                color: const Color(0xFF06D0D8),
                onTap: () => _selectDosage(25),
              ),
              const SizedBox(width: 6),
              _DosagePill(
                percent: 50,
                label: 'Standart',
                selected: _selectedPercent == 50,
                color: const Color(0xFF10B981),
                onTap: () => _selectDosage(50),
              ),
              const SizedBox(width: 6),
              _DosagePill(
                percent: 75,
                label: 'Yoğun',
                selected: _selectedPercent == 75,
                color: const Color(0xFF3B82F6),
                onTap: () => _selectDosage(75),
              ),
              const SizedBox(width: 6),
              _DosagePill(
                percent: 100,
                label: 'Aion Kutsal',
                selected: _selectedPercent == 100,
                color: const Color(0xFFFFB800),
                onTap: () => _selectDosage(100),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.carbonVoid.withValues(alpha: 0.70),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.30),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Öngörülen Sağlık (HP)',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Text(
                          '$projectedHp/${widget.maxHealth}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        if (restoredHp > 0) ...<Widget>[
                          const SizedBox(width: 4),
                          Text(
                            '(+$restoredHp)',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF06D0D8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.borderFaint,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Öngörülen Enerji',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Text(
                          '$projectedEnergy/${widget.maxEnergy}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        if (restoredEnergy > 0) ...<Widget>[
                          const SizedBox(width: 4),
                          Text(
                            '(+$restoredEnergy)',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF06D0D8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          RestrictionPressable(
            onTap: _handleApply,
            enabled: !_isApplying && !widget.isHealing,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF06D0D8),
                    Color(0xFF10B981),
                  ],
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x3306D0D8),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: _isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _justApplied
                                ? Icons.check_circle_rounded
                                : Icons.water_drop_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _justApplied
                                ? 'Dozaj Hazırlandı ve Uygulandı!'
                                : '%$_selectedPercent Kutsal İksir Dozajını Uygula',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DosagePill extends StatelessWidget {
  const _DosagePill({
    required this.percent,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final int percent;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RestrictionPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: selected
                ? color.withValues(alpha: 0.22)
                : AppColors.carbonVoid.withValues(alpha: 0.60),
            border: Border.all(
              color: selected ? color : AppColors.borderFaint,
              width: selected ? 1.4 : 0.8,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: <Widget>[
              Text(
                '%$percent',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Treatment Procedure Card with cost badge, prognosis,
/// tactile feedback, and optional loading indicator.
class TreatmentOptionCard extends StatelessWidget {
  const TreatmentOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.prognosis,
    required this.icon,
    required this.accentColor,
    required this.costBadge,
    required this.onTap,
    this.isProminent = false,
    this.loading = false,
    this.tag,
  });

  final String title;
  final String subtitle;
  final String prognosis;
  final IconData icon;
  final Color accentColor;
  final Widget costBadge;
  final VoidCallback? onTap;
  final bool isProminent;
  final bool loading;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !loading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $subtitle. $prognosis',
      child: RestrictionPressable(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        enabled: enabled,
        child: Container(
          padding: EdgeInsets.all(isProminent ? 14 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: isProminent
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accentColor.withValues(alpha: 0.28),
                      accentColor.withValues(alpha: 0.08),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.spaceNavy.withValues(alpha: 0.85),
                      AppColors.carbonVoid.withValues(alpha: 0.95),
                    ],
                  ),
            border: Border.all(
              color: accentColor.withValues(alpha: isProminent ? 0.65 : 0.32),
              width: isProminent ? 1.4 : 1.0,
            ),
            boxShadow: isProminent
                ? <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withValues(alpha: 0.16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.45),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accentColor,
                              ),
                            )
                          : Icon(icon, size: 18, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: isProminent ? 13 : 12,
                                  fontWeight: FontWeight.w800,
                                  color: enabled
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (tag != null) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: accentColor.withValues(alpha: 0.18),
                                ),
                                child: Text(
                                  tag!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            color: enabled
                                ? accentColor.withValues(alpha: 0.9)
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                prognosis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  costBadge,
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: enabled
                        ? accentColor.withValues(alpha: 0.8)
                        : AppColors.textSecondary.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive AAA Treatment Options Layout presenting available clinical procedures.
class HospitalTreatmentOptionsGrid extends StatelessWidget {
  const HospitalTreatmentOptionsGrid({
    super.key,
    required this.inHospital,
    required this.isHealing,
    required this.gemDischargeCost,
    required this.canFreeDischarge,
    required this.freeDischargesRemaining,
    required this.onHealWithGems,
    required this.onDoctorVisit,
    required this.onGuildDoctor,
    this.onWatchAd,
    this.onAttemptEscape,
    this.adActionWrapper,
  });

  final bool inHospital;
  final bool isHealing;
  final int gemDischargeCost;
  final bool canFreeDischarge;
  final int freeDischargesRemaining;
  final VoidCallback onHealWithGems;
  final VoidCallback onDoctorVisit;
  final VoidCallback onGuildDoctor;
  final VoidCallback? onWatchAd;
  final VoidCallback? onAttemptEscape;
  final Widget Function(Widget child)? adActionWrapper;

  @override
  Widget build(BuildContext context) {
    final Widget heroRejuvenationCard = TreatmentOptionCard(
      title: inHospital
          ? (canFreeDischarge
              ? 'Ücretsiz Kutsal Taburcu'
              : 'Kutsal Arınma & Elmas Taburcu')
          : 'Kutsal Şifa & Tam Yenilenme',
      subtitle: inHospital
          ? (canFreeDischarge
              ? '$freeDischargesRemaining Günlük Taburcu Hakkı Mevcut'
              : '$gemDischargeCost Elmas Enerjisi')
          : 'Tüm Can ve Enerjiyi Anında Restorasyon',
      prognosis: inHospital
          ? 'Beden ve ruh kutsanarak derhal taburcu edilir. Hastane cezası kalkar, can %100 doldurulur.'
          : 'Işık aurası tüm yorgunluğu ve doku hasarlarını anında giderir. Maksimum cana kavuşursunuz.',
      icon: Icons.auto_awesome_rounded,
      accentColor:
          canFreeDischarge ? AppColors.toxicNeon : AppColors.accentPurple,
      costBadge: canFreeDischarge
          ? HealingCostBadge.free(remaining: freeDischargesRemaining)
          : HealingCostBadge.gems(gems: gemDischargeCost),
      isProminent: true,
      loading: isHealing,
      tag: canFreeDischarge ? 'GÜNLÜK HAK' : 'TAM ŞİFA',
      onTap: isHealing ? null : onHealWithGems,
    );

    final Widget doctorVisitCard = TreatmentOptionCard(
      title: 'Klinik Muayene',
      subtitle: 'Başhekim Alistair Triage',
      prognosis:
          'Klinik muayene ve şans bazlı yatış süresi indirimi (−15 ile 45 dakika arası kazanç).',
      icon: Icons.medical_services_rounded,
      accentColor: AppColors.accentCyan,
      costBadge: HealingCostBadge.time(
        duration: 'Şans Faktörü',
        delta: '−15~45 Dk',
      ),
      loading: isHealing,
      onTap: isHealing ? null : onDoctorVisit,
    );

    final Widget guildClinicCard = TreatmentOptionCard(
      title: 'Lonca Kliniği',
      subtitle: 'Lonca Hekimi Desteği',
      prognosis:
          'Loncanızın anlaşmalı hekimi tarafından özel bakım ve moral takviyesi sağlanır.',
      icon: Icons.shield_rounded,
      accentColor: AppColors.toxicNeon,
      costBadge: HealingCostBadge.guild(),
      loading: isHealing,
      onTap: isHealing ? null : onGuildDoctor,
    );

    Widget? adSpeedupCard;
    if (onWatchAd != null) {
      final Widget innerCard = TreatmentOptionCard(
        title: 'Gözlem Reklamı',
        subtitle: 'Astral Boyut Bağlantısı',
        prognosis:
            'Astral frekans gözlemi yaparak hastane süresini anında 30 dakika kısaltın.',
        icon: Icons.play_circle_fill_rounded,
        accentColor: AppColors.liquidGold,
        costBadge: HealingCostBadge.adBypass(),
        loading: isHealing,
        onTap: isHealing ? null : onWatchAd,
      );
      adSpeedupCard =
          adActionWrapper != null ? adActionWrapper!(innerCard) : innerCard;
    }

    Widget? escapeCard;
    if (inHospital && onAttemptEscape != null) {
      escapeCard = TreatmentOptionCard(
        title: 'Gizli Kaçış',
        subtitle: 'Riskli Tahliye Girişimi',
        prognosis:
            '%50 şansla hemen firar edin. Yakalanırsanız karantina sürenize 15 dakika eklenir.',
        icon: Icons.directions_run_rounded,
        accentColor: AppColors.coralFlare,
        costBadge: HealingCostBadge.risk(label: '%50 Şans · +15 Dk Ceza Riski'),
        loading: isHealing,
        tag: 'YÜKSEK RİSK',
        onTap: isHealing ? null : onAttemptEscape,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isCompact = constraints.maxWidth < 460;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            heroRejuvenationCard,
            const SizedBox(height: 10),
            if (isCompact) ...<Widget>[
              doctorVisitCard,
              const SizedBox(height: 10),
              guildClinicCard,
              if (adSpeedupCard != null) ...<Widget>[
                const SizedBox(height: 10),
                adSpeedupCard,
              ],
              if (escapeCard != null) ...<Widget>[
                const SizedBox(height: 10),
                escapeCard,
              ],
            ] else ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: doctorVisitCard),
                  const SizedBox(width: 10),
                  Expanded(child: guildClinicCard),
                ],
              ),
              if (adSpeedupCard != null || escapeCard != null) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (adSpeedupCard != null)
                      Expanded(child: adSpeedupCard)
                    else
                      const Spacer(),
                    if (adSpeedupCard != null && escapeCard != null)
                      const SizedBox(width: 10),
                    if (escapeCard != null)
                      Expanded(child: escapeCard)
                    else if (adSpeedupCard != null)
                      const Spacer(),
                  ],
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Consultation role toggle for Doctor vs Sanctuary Priestess.
enum SanctuaryConsultant {
  doctor,
  priestess,
}

/// Interactive Doctor & Priest Consultation card with dynamic dialogue
/// reflecting patient status, treatment actions, and sanctum blessings.
class DoctorPriestConsultationCard extends StatefulWidget {
  const DoctorPriestConsultationCard({
    super.key,
    required this.inHospital,
    required this.isHealing,
    required this.healthStatus,
    required this.gemDischargeCost,
    required this.canFreeDischarge,
    required this.freeDischargesRemaining,
    required this.onDoctorVisit,
    required this.onGuildDoctor,
    required this.onDischarge,
    this.onWatchAd,
    this.onAttemptEscape,
    this.adActionWrapper,
  });

  final bool inHospital;
  final bool isHealing;
  final PlayerHealthStatus healthStatus;
  final int gemDischargeCost;
  final bool canFreeDischarge;
  final int freeDischargesRemaining;
  final VoidCallback onDoctorVisit;
  final VoidCallback onGuildDoctor;
  final VoidCallback onDischarge;
  final VoidCallback? onWatchAd;
  final VoidCallback? onAttemptEscape;
  final Widget Function(Widget child)? adActionWrapper;

  @override
  State<DoctorPriestConsultationCard> createState() =>
      _DoctorPriestConsultationCardState();
}

class _DoctorPriestConsultationCardState
    extends State<DoctorPriestConsultationCard> {
  SanctuaryConsultant _consultant = SanctuaryConsultant.doctor;

  String _getDoctorDialogue() {
    if (widget.inHospital) {
      return 'Durumun ciddi savaşçı. Derin yara ve kemik kırıkları tespit ettim. Dinlenmen gerekiyor; şanslıysan muayene ile yatış süreni kısaltabiliriz.';
    }
    return switch (widget.healthStatus) {
      PlayerHealthStatus.critical =>
        'Kritik eşiğin altına inmişsin! Bu halde savaşa girmek intihardır. Hemen can iksiri kullanmalı veya revirde tedavi olmalısın.',
      PlayerHealthStatus.wounded =>
        'Bedeninde taze darbeler var. Ağır yaralısın ve PvP gücün %5 düşmüş durumda. Önleyici pansuman yapabiliriz.',
      PlayerHealthStatus.recovering =>
        'Yaraların kabuk bağlıyor. Doğal can yenilenmen sürüyor; hızlandırmak istersen iksir desteği yazabilirim.',
      PlayerHealthStatus.healthy =>
        'Nabzın ve reflekslerin zirvede! Hiçbir klinik semptomun yok. Arenaya ve zindanlara tam güçle hazırsın.',
      PlayerHealthStatus.restricted =>
        'Karantina altındasın. İyileşme sürecini izliyorum.',
    };
  }

  String _getPriestessDialogue() {
    if (widget.inHospital) {
      return 'Kutsal Aion Işığı ruhunu sarsın evlat. Sunak dualarımız bedenindeki karanlık zehirleri ve sızıları arındırıyor. Acele etmek istersen arınma ayini yapabiliriz.';
    }
    return switch (widget.healthStatus) {
      PlayerHealthStatus.critical =>
        'Ruh ışığın solmak üzere! Kutsal sunak seni bekliyor; dualarımız ve kutsanmış suyla hayata dönebilirsin.',
      PlayerHealthStatus.wounded =>
        'Işığın zırhı hasar görmüş. Kutsal elmas enerjisiyle tüm hasarı anında onarabiliriz.',
      PlayerHealthStatus.recovering =>
        'Sanctuary aurası seni koruyor. İyileşme ışınları hücrelerini canlandırıyor.',
      PlayerHealthStatus.healthy =>
        'Aion’un bereketi üzerinde olsun! Ruhun berrak, adımların sarsılmaz.',
      PlayerHealthStatus.restricted =>
        'Kutsal sığınaktasın. Işık yaralarını sarmaya devam ediyor.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool isDoc = _consultant == SanctuaryConsultant.doctor;
    final Color consultantAccent =
        isDoc ? AppColors.accentCyan : AppColors.liquidGold;

    return SanctuaryGlassCard(
      accent: consultantAccent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _ConsultantTabButton(
                  title: 'Başhekim Alistair',
                  subtitle: 'Klinik & Teşhis',
                  icon: Icons.medical_services_rounded,
                  selected: isDoc,
                  accentColor: AppColors.accentCyan,
                  onTap: () {
                    if (!mounted) return;
                    HapticFeedback.selectionClick();
                    setState(() => _consultant = SanctuaryConsultant.doctor);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConsultantTabButton(
                  title: 'Rahibe Aurelia',
                  subtitle: 'Işık Ayini & Şifa',
                  icon: Icons.auto_awesome_rounded,
                  selected: !isDoc,
                  accentColor: AppColors.liquidGold,
                  onTap: () {
                    if (!mounted) return;
                    HapticFeedback.selectionClick();
                    setState(
                        () => _consultant = SanctuaryConsultant.priestess);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: consultantAccent.withValues(alpha: 0.08),
              border: Border.all(
                color: consultantAccent.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        consultantAccent.withValues(alpha: 0.35),
                        consultantAccent.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: consultantAccent.withValues(alpha: 0.50),
                    ),
                  ),
                  child: Icon(
                    isDoc
                        ? Icons.health_and_safety_rounded
                        : Icons.brightness_high_rounded,
                    color: consultantAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isDoc ? 'Dr. Alistair' : 'Yüce Rahibe Aurelia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: consultantAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDoc
                            ? _getDoctorDialogue()
                            : _getPriestessDialogue(),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (isDoc) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _SanctuaryActionButton(
                    label: 'Doktor Ziyareti',
                    subtitle: 'Şans · Süre Kesintisi',
                    icon: Icons.medical_services_outlined,
                    accentColor: AppColors.accentCyan,
                    loading: widget.isHealing,
                    onTap: widget.isHealing ? null : widget.onDoctorVisit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SanctuaryActionButton(
                    label: 'Lonca Kliniği',
                    subtitle: 'Lonca Hekimi Desteği',
                    icon: Icons.shield_rounded,
                    accentColor: AppColors.toxicNeon,
                    loading: widget.isHealing,
                    onTap: widget.isHealing ? null : widget.onGuildDoctor,
                  ),
                ),
              ],
            ),
            if (widget.onWatchAd != null || widget.onAttemptEscape != null) ...<
                Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  if (widget.onWatchAd != null)
                    Expanded(
                      child: widget.adActionWrapper != null
                          ? widget.adActionWrapper!(
                              _SanctuaryActionButton(
                                label: 'Gözlem Reklamı',
                                subtitle: '−30 Dk Hızlandırma',
                                icon: Icons.play_circle_fill_rounded,
                                accentColor: AppColors.liquidGold,
                                loading: widget.isHealing,
                                onTap: widget.isHealing
                                    ? null
                                    : widget.onWatchAd,
                              ),
                            )
                          : _SanctuaryActionButton(
                              label: 'Gözlem Reklamı',
                              subtitle: '−30 Dk Hızlandırma',
                              icon: Icons.play_circle_fill_rounded,
                              accentColor: AppColors.liquidGold,
                              loading: widget.isHealing,
                              onTap: widget.isHealing
                                  ? null
                                  : widget.onWatchAd,
                            ),
                    ),
                  if (widget.onWatchAd != null &&
                      widget.onAttemptEscape != null)
                    const SizedBox(width: 8),
                  if (widget.onAttemptEscape != null)
                    Expanded(
                      child: _SanctuaryActionButton(
                        label: 'Gizli Kaçış',
                        subtitle: 'Riskli Girişim (+15dk)',
                        icon: Icons.directions_run_rounded,
                        accentColor: AppColors.coralFlare,
                        loading: widget.isHealing,
                        onTap: widget.isHealing
                            ? null
                            : widget.onAttemptEscape,
                      ),
                    ),
                ],
              ),
            ],
          ] else ...<Widget>[
            _SanctuaryActionButton(
              label: widget.inHospital
                  ? (widget.canFreeDischarge
                      ? 'Ücretsiz Kutsal Taburcu (${widget.freeDischargesRemaining} Hak)'
                      : '${widget.gemDischargeCost} Elmas · Kutsal Arınma & Taburcu')
                  : 'Kutsal Şifa Duası & Anında İyileşme',
              subtitle: widget.inHospital
                  ? (widget.canFreeDischarge
                      ? 'Günlük taburcu hakkını kullan'
                      : 'Elmas enerjisiyle hemen sağlığına kavuş')
                  : 'Bedenini ve ruhunu kutsayarak canını doldur',
              icon: Icons.healing_rounded,
              accentColor: widget.canFreeDischarge
                  ? AppColors.toxicNeon
                  : AppColors.accentPurple,
              isProminent: true,
              loading: widget.isHealing,
              onTap: widget.isHealing ? null : widget.onDischarge,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsultantTabButton extends StatelessWidget {
  const _ConsultantTabButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RestrictionPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? accentColor.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? accentColor.withValues(alpha: 0.50)
                : AppColors.borderFaint,
            width: 1.0,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? accentColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: selected
                          ? accentColor
                          : AppColors.textSecondary.withValues(alpha: 0.7),
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

class _SanctuaryActionButton extends StatelessWidget {
  const _SanctuaryActionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.isProminent = false,
    this.loading = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool isProminent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !loading;

    return RestrictionPressable(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      enabled: enabled,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isProminent ? 12 : 10,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isProminent
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    accentColor.withValues(alpha: 0.35),
                    accentColor.withValues(alpha: 0.15),
                  ],
                )
              : null,
          color: isProminent
              ? null
              : accentColor.withValues(alpha: 0.08),
          border: Border.all(
            color: accentColor.withValues(alpha: isProminent ? 0.60 : 0.30),
            width: isProminent ? 1.4 : 1.0,
          ),
          boxShadow: isProminent
              ? <BoxShadow>[
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: <Widget>[
            if (loading)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: accentColor,
                ),
              )
            else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.15),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isProminent ? 13 : 11,
                      fontWeight: FontWeight.w800,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: accentColor.withValues(alpha: 0.85),
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

/// Aion 2 Sanctuary Status Ailments and Diagnosis Panel.
/// Displays current health debuffs/penalties with interactive cure buttons.
class StatusAilmentsPanel extends StatelessWidget {
  const StatusAilmentsPanel({
    super.key,
    required this.healthStatus,
    required this.inHospital,
    required this.hospitalReason,
    this.energyRatio = 1.0,
    this.onCurePressed,
  });

  final PlayerHealthStatus healthStatus;
  final bool inHospital;
  final String? hospitalReason;
  final double energyRatio;
  final VoidCallback? onCurePressed;

  @override
  Widget build(BuildContext context) {
    final List<_AilmentInfo> ailments = <_AilmentInfo>[];

    if (inHospital) {
      ailments.add(
        _AilmentInfo(
          title: 'Hastane Karantinası',
          severity: 'Yatış Protokolü',
          description: labelHospitalReason(hospitalReason),
          effectText: 'Pasif can ve enerji yenilenmesi durduruldu',
          accentColor: AppColors.mysticRuby,
          icon: Icons.local_hospital_rounded,
          recommendedTreatment: 'Kutsal Taburcu veya Doktor Ziyareti',
        ),
      );
    }

    if (healthStatus == PlayerHealthStatus.critical) {
      ailments.add(
        const _AilmentInfo(
          title: 'Kritik Travma',
          severity: 'Hayati Tehlike (<%20 Can)',
          description: 'Hayati organlar ağır hasarlı',
          effectText: 'Savaş ve arena katılımı kilitlendi',
          accentColor: Color(0xFFEA2143),
          icon: Icons.warning_amber_rounded,
          recommendedTreatment: 'Kutsal Şifa veya Acil Can İksiri',
        ),
      );
    } else if (healthStatus == PlayerHealthStatus.wounded) {
      ailments.add(
        const _AilmentInfo(
          title: 'Ağır Yara',
          severity: 'Yaralı Durum (<%50 Can)',
          description: 'Kas ve doku zedelenmesi',
          effectText: 'PvP saldırı gücünde %5 ceza',
          accentColor: Color(0xFFE89558),
          icon: Icons.healing_rounded,
          recommendedTreatment: 'Pansuman / Doğal Dinlenme',
        ),
      );
    }

    if (energyRatio < 0.20) {
      ailments.add(
        const _AilmentInfo(
          title: 'Aşırı Yorgunluk',
          severity: 'Tükenmiş Enerji',
          description: 'Büyü ve astral rezervler boşaldı',
          effectText: 'Zindan ve macera eylemleri kısıtlı',
          accentColor: AppColors.liquidGold,
          icon: Icons.battery_alert_rounded,
          recommendedTreatment: 'Astral Dinlenme veya Enerji İksiri',
        ),
      );
    }

    if (ailments.isEmpty) {
      return SanctuaryGlassCard(
        accent: AppColors.toxicNeon,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.toxicNeon.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppColors.toxicNeon,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Aktif İllet Yok (Arınmış Durum)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.toxicNeon,
                    ),
                  ),
                  Text(
                    'Bedeninde zehir, lanet veya savaş kısıtlaması bulunmuyor.',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SanctuaryGlassCard(
      accent: ailments.first.accentColor,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Teşhis Edilen İlletler & Cezalar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: ailments.first.accentColor.withValues(alpha: 0.20),
                ),
                child: Text(
                  '${ailments.length} Belirti',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: ailments.first.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...ailments.map(
            (_AilmentInfo info) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: info.accentColor.withValues(alpha: 0.08),
                border: Border.all(
                  color: info.accentColor.withValues(alpha: 0.30),
                  width: 0.9,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(info.icon, size: 20, color: info.accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              info.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${info.severity})',
                              style: TextStyle(
                                fontSize: 10,
                                color: info.accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          info.effectText,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (info.recommendedTreatment != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.medical_information_outlined,
                                size: 12,
                                color: info.accentColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Önerilen: ${info.recommendedTreatment!}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: info.accentColor
                                        .withValues(alpha: 0.95),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
  }
}

class _AilmentInfo {
  const _AilmentInfo({
    required this.title,
    required this.severity,
    required this.description,
    required this.effectText,
    required this.accentColor,
    required this.icon,
    this.recommendedTreatment,
  });

  final String title;
  final String severity;
  final String description;
  final String effectText;
  final Color accentColor;
  final IconData icon;
  final String? recommendedTreatment;
}

/// Comprehensive Master Hospital Treatment & Sanctuary Panel.
/// Unifies Liquid Gauges, Doctor/Priest Consultations, Status Ailments,
/// and Ward Panel in an Aion 2 sanctuary glass presentation.
class HospitalTreatmentPanel extends StatelessWidget {
  const HospitalTreatmentPanel({
    super.key,
    required this.profile,
    required this.inHospital,
    required this.isHealing,
    required this.remainingDuration,
    required this.progress,
    required this.gemDischargeCost,
    required this.canFreeDischarge,
    required this.freeDischargesRemaining,
    required this.onHealWithGems,
    required this.onDoctorVisit,
    required this.onGuildDoctor,
    this.onWatchAd,
    this.onAttemptEscape,
    this.adActionWrapper,
    this.wardPanel,
  });

  final PlayerProfile profile;
  final bool inHospital;
  final bool isHealing;
  final Duration remainingDuration;
  final double progress;
  final int gemDischargeCost;
  final bool canFreeDischarge;
  final int freeDischargesRemaining;
  final VoidCallback onHealWithGems;
  final VoidCallback onDoctorVisit;
  final VoidCallback onGuildDoctor;
  final VoidCallback? onWatchAd;
  final VoidCallback? onAttemptEscape;
  final Widget Function(Widget child)? adActionWrapper;
  final Widget? wardPanel;

  @override
  Widget build(BuildContext context) {
    final PlayerHealthStatus status = resolveHealthStatus(
      health: profile.health,
      maxHealth: profile.maxHealth,
      restricted: inHospital,
    );

    final bool isAlchemist = profile.characterClass == CharacterClass.alchemist;
    final double regenPerHour =
        healthRegenPercentPerHour(alchemistBonus: isAlchemist);
    final int secondsToFull = estimateSecondsToFullHealth(
      health: profile.health,
      maxHealth: profile.maxHealth,
      alchemistBonus: isAlchemist,
    );
    final String regenEta = formatRegenDuration(secondsToFull);

    final Color statusClr = healthStatusColor(status);
    final String statusLbl = healthStatusLabel(status);
    final double healthRatio = profile.maxHealth > 0
        ? (profile.health / profile.maxHealth).clamp(0.0, 1.0)
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SanctuaryGlassCard(
          accent: statusClr,
          secondaryAccent: const Color(0xFF10B981),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  GlowingVitalOrbGauge(
                    currentHealth: profile.health,
                    maxHealth: profile.maxHealth,
                    isHealing: isHealing,
                    size: 70,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              inHospital ? 'Kutsal Şifa Kliniği' : 'Hayati Vital Durum',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: statusClr.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: statusClr.withValues(alpha: 0.45),
                                  width: 0.9,
                                ),
                              ),
                              child: Text(
                                statusLbl,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusClr,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inHospital
                              ? 'Aion 2 Kutsal Işığı hücrelerinizi onarıyor. Can rejenerasyonu hızlandırma seçeneklerini aşağıdan yönetebilirsiniz.'
                              : 'Can yenilenmesi aktif (+${regenPerHour.toStringAsFixed(1)}%/saat). Tam doluma tahmini $regenEta kaldı.',
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LiquidRecoveryGauge(
                title: 'Hayatiyet (Can / HP)',
                subtitle: inHospital
                    ? 'Hastane yatışında pasif yenilenme duraklatıldı'
                    : 'Pasif Hız: +${regenPerHour.toStringAsFixed(1)}%/saat · Tam Dolum: $regenEta',
                currentValue: profile.health,
                maxValue: profile.maxHealth,
                primaryColor: status == PlayerHealthStatus.critical
                    ? const Color(0xFFEA2143)
                    : (status == PlayerHealthStatus.wounded
                        ? const Color(0xFFF97316)
                        : const Color(0xFF10B981)),
                secondaryColor: status == PlayerHealthStatus.critical
                    ? const Color(0xFF991B1B)
                    : (status == PlayerHealthStatus.wounded
                        ? const Color(0xFFEA580C)
                        : const Color(0xFF047857)),
                accentGlow: statusClr,
                height: 52,
                showThresholds: true,
                showEcgWave: true,
                auxiliaryTag: statusLbl,
                statusColor: statusClr,
              ),
              const SizedBox(height: 12),
              LiquidRecoveryGauge(
                title: 'Astral Enerji (Mana / Energy)',
                subtitle: 'Savaş & Zindan Keşfi Güç Kaynağı',
                currentValue: profile.energy,
                maxValue: profile.maxEnergy,
                primaryColor: const Color(0xFF3B82F6),
                secondaryColor: const Color(0xFF1D4ED8),
                accentGlow: AppColors.accentBlue,
                height: 44,
                showEcgWave: false,
                auxiliaryTag: '${profile.energy}/${profile.maxEnergy}',
                statusColor: AppColors.accentBlue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        HealingProgressPulse(
          inHospital: inHospital,
          isHealing: isHealing,
          regenPerHour: regenPerHour,
          regenEta: regenEta,
          healthRatio: healthRatio,
          characterClass: profile.characterClass,
        ),
        const SizedBox(height: 12),
        DoctorAdvisoryNotes(
          healthStatus: status,
          inHospital: inHospital,
          healthRatio: healthRatio,
          hospitalReason: profile.hospitalReason,
          characterClass: profile.characterClass,
          alchemistRegenBonus: isAlchemist,
        ),
        const SizedBox(height: 12),
        ElixirDosageSelector(
          currentHealth: profile.health,
          maxHealth: profile.maxHealth,
          currentEnergy: profile.energy,
          maxEnergy: profile.maxEnergy,
          inHospital: inHospital,
          isHealing: isHealing,
        ),
        const SizedBox(height: 12),
        StatusAilmentsPanel(
          healthStatus: status,
          inHospital: inHospital,
          hospitalReason: profile.hospitalReason,
          energyRatio: profile.maxEnergy > 0
              ? profile.energy / profile.maxEnergy
              : 1.0,
        ),
        const SizedBox(height: 12),
        HospitalTreatmentOptionsGrid(
          inHospital: inHospital,
          isHealing: isHealing,
          gemDischargeCost: gemDischargeCost,
          canFreeDischarge: canFreeDischarge,
          freeDischargesRemaining: freeDischargesRemaining,
          onHealWithGems: onHealWithGems,
          onDoctorVisit: onDoctorVisit,
          onGuildDoctor: onGuildDoctor,
          onWatchAd: onWatchAd,
          onAttemptEscape: onAttemptEscape,
          adActionWrapper: adActionWrapper,
        ),
        const SizedBox(height: 12),
        DoctorPriestConsultationCard(
          inHospital: inHospital,
          isHealing: isHealing,
          healthStatus: status,
          gemDischargeCost: gemDischargeCost,
          canFreeDischarge: canFreeDischarge,
          freeDischargesRemaining: freeDischargesRemaining,
          onDoctorVisit: onDoctorVisit,
          onGuildDoctor: onGuildDoctor,
          onDischarge: onHealWithGems,
          onWatchAd: onWatchAd,
          onAttemptEscape: onAttemptEscape,
          adActionWrapper: adActionWrapper,
        ),
        if (wardPanel != null) ...<Widget>[
          const SizedBox(height: 12),
          wardPanel!,
        ],
      ],
    );
  }
}
