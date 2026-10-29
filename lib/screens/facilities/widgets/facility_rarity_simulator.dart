import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import '../facility_detail_data.dart';
import 'facilities_ui.dart';
import 'facility_detail_design.dart';

/// Verifiable simulated drop outcome with mathematical odds calculation.
class SimulatedDropResult {
  const SimulatedDropResult({
    required this.rarity,
    required this.itemName,
    required this.probabilityPct,
    required this.timestamp,
    required this.rollValue,
    required this.level,
  });

  final String rarity;
  final String itemName;
  final double probabilityPct;
  final DateTime timestamp;
  final double rollValue;
  final int level;
}

class _CelestialParticle {
  _CelestialParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.isStar,
    required this.spinSpeed,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final bool isStar;
  final double spinSpeed;
}

class _CelestialParticlePainter extends CustomPainter {
  _CelestialParticlePainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_CelestialParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double fade = (1.0 - progress).clamp(0.0, 1.0);

    for (final _CelestialParticle p in particles) {
      final double dist = p.speed * progress * (size.width * 0.45);
      final double x = center.dx + math.cos(p.angle) * dist;
      final double y = center.dy + math.sin(p.angle) * dist;
      final double currentSize = p.size * (0.4 + 0.6 * fade);
      final Paint paint = Paint()
        ..color = p.color.withValues(alpha: (p.color.a * fade).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      if (p.isStar) {
        final Path star = Path();
        final double rotation = p.angle + progress * p.spinSpeed;
        const int points = 4;
        for (int i = 0; i < points * 2; i++) {
          final double r = i.isEven ? currentSize : currentSize * 0.35;
          final double a = rotation + (i * math.pi / points);
          final double px = x + math.cos(a) * r;
          final double py = y + math.sin(a) * r;
          if (i == 0) {
            star.moveTo(px, py);
          } else {
            star.lineTo(px, py);
          }
        }
        star.close();
        canvas.drawPath(star, paint);
      } else {
        canvas.drawCircle(Offset(x, y), currentSize * 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CelestialHaloRipplePainter extends CustomPainter {
  _CelestialHaloRipplePainter({
    required this.progress,
    required this.accentColor,
  });

  final double progress;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = math.min(size.width, size.height) * 0.55;

    for (int i = 0; i < 3; i++) {
      final double ringProgress = (progress - (i * 0.18)).clamp(0.0, 1.0);
      if (ringProgress <= 0 || ringProgress >= 1.0) continue;

      final double radius = maxRadius * Curves.easeOutQuad.transform(ringProgress);
      final double alpha = (1.0 - ringProgress).clamp(0.0, 1.0);

      final Paint strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * (1.0 - ringProgress * 0.5)
        ..color = accentColor.withValues(alpha: alpha * 0.7);

      canvas.drawCircle(center, radius, strokePaint);

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0 * (1.0 - ringProgress * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..color = accentColor.withValues(alpha: alpha * 0.35);

      canvas.drawCircle(center, radius, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialHaloRipplePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
}

class CelestialProbabilityCurvePainter extends CustomPainter {
  CelestialProbabilityCurvePainter({
    required this.currentLevel,
    required this.selectedLevel,
    required this.highlightedRarity,
    required this.pulseValue,
  });

  final int currentLevel;
  final int selectedLevel;
  final String? highlightedRarity;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    const double padL = 34.0;
    const double padR = 14.0;
    const double padT = 16.0;
    const double padB = 24.0;

    final double chartW = size.width - padL - padR;
    final double chartH = size.height - padT - padB;
    if (chartW <= 0 || chartH <= 0) return;

    final Paint gridPaint = Paint()
      ..color = AppColors.mutedTitanium.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const List<int> yTicks = <int>[0, 25, 50, 75, 100];
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final int tick in yTicks) {
      final double y = padT + chartH * (1.0 - tick / 100.0);
      canvas.drawLine(Offset(padL, y), Offset(padL + chartW, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$tick%',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedTitanium.withValues(alpha: 0.65),
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(padL - textPainter.width - 4, y - textPainter.height / 2));
    }

    for (int lvl = 1; lvl <= 10; lvl++) {
      final double x = padL + (lvl - 1) / 9.0 * chartW;
      textPainter.text = TextSpan(
        text: '$lvl',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: lvl == currentLevel ? FontWeight.w900 : FontWeight.w600,
          color: lvl == currentLevel
              ? AppColors.liquidGold
              : AppColors.mutedTitanium.withValues(alpha: 0.5),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - padB + 6),
      );
    }

    for (final String rarity in kFacilityResourceRarities) {
      final bool isFocused = highlightedRarity == null || highlightedRarity == rarity;
      final Color color = facRarityAccent(rarity);
      final double alpha = isFocused ? 1.0 : 0.22;
      final double strokeWidth = (highlightedRarity == rarity) ? 2.8 : (isFocused ? 1.6 : 0.9);

      final List<Offset> points = <Offset>[];
      for (int lvl = 1; lvl <= 10; lvl++) {
        final Map<String, int> weights = facilityRarityWeightsAtLevel(lvl);
        final int total = weights.values.fold<int>(0, (int s, int v) => s + v);
        final double pct = total > 0 ? (weights[rarity] ?? 0) / total * 100.0 : 0.0;
        final double x = padL + (lvl - 1) / 9.0 * chartW;
        final double y = padT + chartH * (1.0 - (pct / 100.0).clamp(0.0, 1.0));
        points.add(Offset(x, y));
      }

      if (points.isEmpty) continue;

      final Path curvePath = Path();
      curvePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 0; i < points.length - 1; i++) {
        final Offset p0 = points[i];
        final Offset p1 = points[i + 1];
        final double cx = (p0.dx + p1.dx) / 2;
        curvePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      }

      if (isFocused) {
        final Path fillPath = Path.from(curvePath);
        fillPath.lineTo(points.last.dx, padT + chartH);
        fillPath.lineTo(points.first.dx, padT + chartH);
        fillPath.close();

        final Paint fillPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              color.withValues(alpha: (highlightedRarity == rarity ? 0.22 : 0.08) * alpha),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(padL, padT, chartW, chartH))
          ..style = PaintingStyle.fill;

        canvas.drawPath(fillPath, fillPaint);
      }

      final Paint strokePaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (highlightedRarity == rarity) {
        final Paint glowPaint = Paint()
          ..color = color.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawPath(curvePath, glowPaint);
      }

      canvas.drawPath(curvePath, strokePaint);

      if (isFocused) {
        final Paint dotPaint = Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        for (final Offset pt in points) {
          canvas.drawCircle(pt, (highlightedRarity == rarity) ? 2.8 : 1.8, dotPaint);
        }
      }
    }

    if (selectedLevel != currentLevel) {
      final double selX = padL + (selectedLevel - 1) / 9.0 * chartW;
      final Paint selLinePaint = Paint()
        ..color = AppColors.accentCyan.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(selX, padT), Offset(selX, padT + chartH), selLinePaint);

      final Paint selHeadPaint = Paint()
        ..color = AppColors.accentCyan
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selX, padT - 2), 3.0, selHeadPaint);
    }

    final double curX = padL + (currentLevel - 1) / 9.0 * chartW;
    final Paint beaconLinePaint = Paint()
      ..color = AppColors.liquidGold.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(curX, padT), Offset(curX, padT + chartH), beaconLinePaint);

    final double pulseRadius = 5.0 + 3.0 * pulseValue;
    final Paint beaconHaloPaint = Paint()
      ..color = AppColors.liquidGold.withValues(alpha: (0.45 * (1.0 - pulseValue * 0.4)).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(curX, padT - 4), pulseRadius, beaconHaloPaint);

    final Paint beaconDiamondPaint = Paint()
      ..color = AppColors.liquidGold
      ..style = PaintingStyle.fill;
    final Path diamond = Path()
      ..moveTo(curX, padT - 8)
      ..lineTo(curX + 3.5, padT - 4)
      ..lineTo(curX, padT)
      ..lineTo(curX - 3.5, padT - 4)
      ..close();
    canvas.drawPath(diamond, beaconDiamondPaint);
  }

  @override
  bool shouldRepaint(covariant CelestialProbabilityCurvePainter oldDelegate) {
    return oldDelegate.currentLevel != currentLevel ||
        oldDelegate.selectedLevel != selectedLevel ||
        oldDelegate.highlightedRarity != highlightedRarity ||
        oldDelegate.pulseValue != pulseValue;
  }
}

class CelestialProbabilityCurveCard extends StatefulWidget {
  const CelestialProbabilityCurveCard({
    super.key,
    required this.currentLevel,
    required this.selectedLevel,
    required this.highlightedRarity,
    required this.pulseValue,
  });

  final int currentLevel;
  final int selectedLevel;
  final String? highlightedRarity;
  final double pulseValue;

  @override
  State<CelestialProbabilityCurveCard> createState() =>
      _CelestialProbabilityCurveCardState();
}

class _CelestialProbabilityCurveCardState
    extends State<CelestialProbabilityCurveCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cyberFuchsia.withValues(alpha: 0.3),
          width: 1.0,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.bgCardElevated.withValues(alpha: 0.75),
            AppColors.bgDeep.withValues(alpha: 0.90),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.cyberFuchsia.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _expanded = !_expanded);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cyberFuchsia.withValues(alpha: 0.16),
                          border: Border.all(
                            color: AppColors.cyberFuchsia.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          size: 14,
                          color: AppColors.cyberFuchsia,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Semavi İhtimal Eğrisi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.liquidGold.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.liquidGold.withValues(alpha: 0.35),
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          'Mevcut Lv.${widget.currentLevel}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.liquidGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.mutedTitanium,
                      ),
                    ],
                  ),
                ),
                if (_expanded) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 140,
                    child: CustomPaint(
                      size: const Size(double.infinity, 140),
                      painter: CelestialProbabilityCurvePainter(
                        currentLevel: widget.currentLevel,
                        selectedLevel: widget.selectedLevel,
                        highlightedRarity: widget.highlightedRarity,
                        pulseValue: widget.pulseValue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: kFacilityResourceRarities.map((String rarity) {
                      final Color clr = facRarityAccent(rarity);
                      final bool isSelected = widget.highlightedRarity == rarity;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: clr,
                              boxShadow: isSelected
                                  ? <BoxShadow>[
                                      BoxShadow(color: clr, blurRadius: 4),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            facilityRarityTitle(rarity),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.mutedTitanium,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RarityTierChip extends StatelessWidget {
  const RarityTierChip({
    super.key,
    required this.rarity,
    required this.percent,
    required this.isSelected,
    required this.onTap,
  });

  final String rarity;
  final double percent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = facRarityAccent(rarity);
    final int unlockLvl = kFacilityRarityUnlockLevels[rarity] ?? 1;
    final int decimals = (rarity == 'common' || rarity == 'uncommon' || rarity == 'rare') ? 0 : 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? accent.withValues(alpha: 0.18)
                : AppColors.bgDeep.withValues(alpha: 0.65),
            border: Border.all(
              color: isSelected ? accent : accent.withValues(alpha: 0.3),
              width: isSelected ? 1.4 : 0.8,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                facilityRarityEmoji(rarity),
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        facilityRarityTitle(rarity),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lv.$unlockLvl+',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedTitanium.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '%${percent.toStringAsFixed(decimals)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? accent : AppColors.textPrimary,
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
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

class _CelestialChestChamber extends StatelessWidget {
  const _CelestialChestChamber({
    required this.levitatePhase,
    required this.simulateProgress,
    required this.particles,
    required this.activeRarity,
    required this.useAmazonChest,
    required this.onToggleChestArt,
  });

  final double levitatePhase;
  final double simulateProgress;
  final List<_CelestialParticle> particles;
  final String activeRarity;
  final bool useAmazonChest;
  final VoidCallback onToggleChestArt;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = facRarityAccent(activeRarity);
    final double bobOffset = math.sin(levitatePhase * 2 * math.pi) * 5.0;
    final double shakeOffset = simulateProgress > 0 && simulateProgress < 1.0
        ? math.sin(simulateProgress * 10 * math.pi) * (1.0 - simulateProgress) * 7.0
        : 0.0;

    final String assetPath = useAmazonChest
        ? 'assets/chest/kasaamazon.png'
        : 'assets/chest/kasacevher.png';

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.35),
          width: 1.1,
        ),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: <Color>[
            rarityColor.withValues(alpha: 0.16),
            AppColors.spaceNavy.withValues(alpha: 0.75),
            AppColors.carbonVoid.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (simulateProgress > 0 && simulateProgress < 1.0)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.1),
                      radius: 0.6,
                      colors: <Color>[
                        rarityColor.withValues(alpha: (1.0 - simulateProgress) * 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _CelestialHaloRipplePainter(
                  progress: simulateProgress,
                  accentColor: rarityColor,
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              child: Container(
                width: 110,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: rarityColor.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(shakeOffset, bobOffset),
              child: SizedBox(
                width: 110,
                height: 110,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext ctx, Object err, StackTrace? st) {
                    return Center(
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: 72,
                        color: rarityColor,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _CelestialParticlePainter(
                  progress: simulateProgress,
                  particles: particles,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: onToggleChestArt,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.bgDeep.withValues(alpha: 0.75),
                    border: Border.all(
                      color: AppColors.mutedTitanium.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.style_rounded, size: 10, color: AppColors.liquidGold),
                      const SizedBox(width: 4),
                      Text(
                        useAmazonChest ? 'Amazon Sandığı' : 'Cevher Sandığı',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: rarityColor.withValues(alpha: 0.16),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.5),
                    width: 0.9,
                  ),
                ),
                child: Text(
                  '${facilityRarityEmoji(activeRarity)} ${facilityRarityTitle(activeRarity).toUpperCase()} SANDIK',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: rarityColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aion-2 Drop Simülasyonu Akordiyonu — Frosted Glass + Level Drop Gauges.
class FacRaritySimulatorAccordion extends StatefulWidget {
  const FacRaritySimulatorAccordion({
    super.key,
    required this.currentLevel,
    this.facilityType = 'mining',
  });

  final int currentLevel;
  final String facilityType;

  @override
  State<FacRaritySimulatorAccordion> createState() =>
      _FacRaritySimulatorAccordionState();
}

class _FacRaritySimulatorAccordionState
    extends State<FacRaritySimulatorAccordion>
    with TickerProviderStateMixin {
  late final Set<int> _expandedLevels;
  late final AnimationController _levitateController;
  late final AnimationController _pulseController;
  late final AnimationController _simulateController;
  late final List<_CelestialParticle> _particles;

  int _selectedSimLevel = 1;
  String? _highlightedRarity;
  SimulatedDropResult? _lastResult;
  final List<SimulatedDropResult> _recentHistory = <SimulatedDropResult>[];
  bool _useAmazonChest = false;

  @override
  void initState() {
    super.initState();
    _selectedSimLevel = widget.currentLevel.clamp(1, 10);
    _expandedLevels = <int>{widget.currentLevel};

    _levitateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _simulateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    final math.Random rng = math.Random(42);
    _particles = List<_CelestialParticle>.generate(28, (int idx) {
      final double angle = rng.nextDouble() * 2 * math.pi;
      final double speed = 0.5 + rng.nextDouble() * 1.0;
      final double size = 3.0 + rng.nextDouble() * 5.0;
      final bool isStar = rng.nextBool();
      final Color color = switch (idx % 5) {
        0 => AppColors.liquidGold,
        1 => AppColors.accentCyan,
        2 => AppColors.cyberFuchsia,
        3 => AppColors.warningSolar,
        _ => Colors.white,
      };
      return _CelestialParticle(
        angle: angle,
        speed: speed,
        size: size,
        color: color,
        isStar: isStar,
        spinSpeed: (rng.nextDouble() - 0.5) * 8.0,
      );
    });

    // Headless test guard prevents pumpAndSettle infinite waiting loop in unit tests
    final bool isTest = WidgetsBinding.instance.runtimeType
        .toString()
        .toLowerCase()
        .contains('test');
    if (!isTest) {
      _levitateController.repeat(reverse: true);
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _levitateController.dispose();
    _pulseController.dispose();
    _simulateController.dispose();
    super.dispose();
  }

  void _triggerSimulation([int? targetLevel]) {
    final int simLvl = (targetLevel ?? _selectedSimLevel).clamp(1, 10);
    setState(() {
      _selectedSimLevel = simLvl;
    });

    HapticFeedback.heavyImpact();
    _simulateController.forward(from: 0.0);

    final Map<String, int> weights = facilityRarityWeightsAtLevel(simLvl);
    final int totalWeight =
        weights.values.fold<int>(0, (int sum, int v) => sum + v);
    if (totalWeight <= 0) return;

    final math.Random rng = math.Random();
    final int roll = rng.nextInt(totalWeight);
    int cumulative = 0;
    String wonRarity = 'common';
    for (final MapEntry<String, int> entry in weights.entries) {
      cumulative += entry.value;
      if (roll < cumulative) {
        wonRarity = entry.key;
        break;
      }
    }

    final double pct = (weights[wonRarity]! / totalWeight) * 100.0;
    final String resName =
        facilityResourceNameByRarity(widget.facilityType, wonRarity);

    final SimulatedDropResult result = SimulatedDropResult(
      rarity: wonRarity,
      itemName: resName,
      probabilityPct: pct,
      timestamp: DateTime.now(),
      rollValue: roll.toDouble(),
      level: simLvl,
    );

    setState(() {
      _lastResult = result;
      _recentHistory.insert(0, result);
      if (_recentHistory.length > 5) {
        _recentHistory.removeLast();
      }
    });
  }

  void _toggleLevel(int level) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedLevels.contains(level)) {
        _expandedLevels.remove(level);
      } else {
        _expandedLevels.add(level);
      }
    });
  }

  void _toggleHighlightRarity(String rarity) {
    setState(() {
      if (_highlightedRarity == rarity) {
        _highlightedRarity = null;
      } else {
        _highlightedRarity = rarity;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, int> simWeights =
        facilityRarityWeightsAtLevel(_selectedSimLevel);
    final int simTotal =
        simWeights.values.fold<int>(0, (int s, int v) => s + v);
    final String activeRarity = _lastResult?.rarity ?? _highlightedRarity ?? 'common';

    return FacGlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: FacilitiesUi.radiusMd,
      borderColor: AppColors.cyberFuchsia.withValues(alpha: 0.28),
      glowColor: AppColors.cyberFuchsia.withValues(alpha: 0.12),
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _levitateController,
          _pulseController,
          _simulateController,
        ]),
        builder: (BuildContext context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              facilitiesSectionTitle(
                'Nadir Seviye İhtimal Simülasyonu',
                trailing: 'Lv.1–10',
              ),
              const SizedBox(height: FacilitiesUi.gapSm),

              // Interactive Celestial Chest Chamber
              _CelestialChestChamber(
                levitatePhase: _levitateController.value,
                simulateProgress: _simulateController.value,
                particles: _particles,
                activeRarity: activeRarity,
                useAmazonChest: _useAmazonChest,
                onToggleChestArt: () {
                  HapticFeedback.selectionClick();
                  setState(() => _useAmazonChest = !_useAmazonChest);
                },
              ),
              const SizedBox(height: 10),

              // Last Simulation Outcome Card
              if (_lastResult != null) ...<Widget>[
                _buildSimulationOutcomeCard(_lastResult!),
                const SizedBox(height: 10),
              ],

              // Interactive Simulation Trigger Deck
              _buildSimulateActionDeck(simWeights, simTotal),
              const SizedBox(height: 10),

              // Glowing Rarity Tier Chips
              _buildRarityTierChips(simWeights, simTotal),
              const SizedBox(height: 10),

              // Celestial Probability Curves Card
              CelestialProbabilityCurveCard(
                currentLevel: widget.currentLevel,
                selectedLevel: _selectedSimLevel,
                highlightedRarity: _highlightedRarity,
                pulseValue: _pulseController.value,
              ),
              const SizedBox(height: 12),

              // Accordion List of 10 Levels
              ...List<Widget>.generate(10, (int idx) {
                final int rarityLevel = idx + 1;
                final bool isCurrent = rarityLevel == widget.currentLevel;
                final bool isExpanded = _expandedLevels.contains(rarityLevel);
                final bool isSimSelected = rarityLevel == _selectedSimLevel;
                final Map<String, int> weights =
                    facilityRarityWeightsAtLevel(rarityLevel);
                final int total =
                    weights.values.fold<int>(0, (int sum, int v) => sum + v);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.liquidGold.withValues(alpha: 0.6)
                            : (isSimSelected
                                ? AppColors.accentCyan.withValues(alpha: 0.45)
                                : AppColors.mutedTitanium.withValues(alpha: 0.18)),
                        width: isCurrent ? 1.3 : (isSimSelected ? 1.1 : 0.9),
                      ),
                      gradient: isCurrent
                          ? LinearGradient(
                              colors: <Color>[
                                AppColors.liquidGold.withValues(alpha: 0.12),
                                AppColors.bgDeep.withValues(alpha: 0.6),
                              ],
                            )
                          : (isSimSelected
                              ? LinearGradient(
                                  colors: <Color>[
                                    AppColors.accentCyan.withValues(alpha: 0.10),
                                    AppColors.bgDeep.withValues(alpha: 0.6),
                                  ],
                                )
                              : null),
                      color: (isCurrent || isSimSelected)
                          ? null
                          : AppColors.bgDeep.withValues(alpha: 0.45),
                    ),
                    child: Column(
                      children: <Widget>[
                        InkWell(
                          onTap: () => _toggleLevel(rarityLevel),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: isCurrent
                                        ? AppColors.liquidGold.withValues(alpha: 0.18)
                                        : AppColors.darkObsidian.withValues(alpha: 0.4),
                                    border: Border.all(
                                      color: isCurrent
                                          ? AppColors.liquidGold.withValues(alpha: 0.4)
                                          : AppColors.mutedTitanium.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    'Lv.$rarityLevel',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: isCurrent
                                          ? AppColors.liquidGold
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isCurrent) ...<Widget>[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: AppColors.toxicNeon.withValues(alpha: 0.12),
                                      border: Border.all(
                                        color: AppColors.toxicNeon.withValues(alpha: 0.4),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Text(
                                      'Mevcut Seviye',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.toxicNeon,
                                      ),
                                    ),
                                  ),
                                ],
                                if (isSimSelected && !isCurrent) ...<Widget>[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: AppColors.accentCyan.withValues(alpha: 0.12),
                                      border: Border.all(
                                        color: AppColors.accentCyan.withValues(alpha: 0.35),
                                        width: 0.7,
                                      ),
                                    ),
                                    child: const Text(
                                      'Seçili Hedef',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accentCyan,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: isCurrent
                                      ? AppColors.liquidGold
                                      : AppColors.mutedTitanium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children:
                                      kFacilityResourceRarities.map((String rarity) {
                                    final double pct = total > 0
                                        ? ((weights[rarity] ?? 0) / total) * 100
                                        : 0;
                                    final int decimals = (rarity == 'common' ||
                                            rarity == 'uncommon' ||
                                            rarity == 'rare')
                                        ? 0
                                        : 1;
                                    final Color accent = facRarityAccent(rarity);
                                    final String resName =
                                        facilityResourceNameByRarity(
                                            widget.facilityType, rarity);

                                    return LayoutBuilder(
                                      builder: (BuildContext context,
                                          BoxConstraints constraints) {
                                        final double itemWidth =
                                            (MediaQuery.of(context).size.width - 76) / 2;
                                        return Container(
                                          width: itemWidth.clamp(130, 200),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: accent.withValues(alpha: 0.3),
                                              width: 0.8,
                                            ),
                                            color: AppColors.bgDeep.withValues(alpha: 0.7),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: <Widget>[
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: <Widget>[
                                                      Text(
                                                        facilityRarityEmoji(rarity),
                                                        style: const TextStyle(fontSize: 9),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        facilityRarityTitle(rarity),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: accent,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '%${pct.toStringAsFixed(decimals)}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                resName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.mutedTitanium
                                                      .withValues(alpha: 0.8),
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(999),
                                                child: LinearProgressIndicator(
                                                  value: (pct.clamp(0, 100)) / 100,
                                                  minHeight: 4.5,
                                                  backgroundColor:
                                                      AppColors.darkObsidian,
                                                  color: accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: InkWell(
                                    onTap: () => _triggerSimulation(rarityLevel),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: AppColors.accentCyan.withValues(alpha: 0.12),
                                        border: Border.all(
                                          color: AppColors.accentCyan.withValues(alpha: 0.35),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          const Icon(
                                            Icons.casino_rounded,
                                            size: 11,
                                            color: AppColors.accentCyan,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Bu Seviyede Test Et (Seviye $rarityLevel)',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.accentCyan,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSimulationOutcomeCard(SimulatedDropResult res) {
    final Color clr = facRarityAccent(res.rarity);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.bgDeep.withValues(alpha: 0.85),
        border: Border.all(
          color: clr.withValues(alpha: 0.6),
          width: 1.1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: clr.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: clr.withValues(alpha: 0.16),
              border: Border.all(color: clr.withValues(alpha: 0.45)),
            ),
            child: Text(
              facilityRarityEmoji(res.rarity),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      '${facilityRarityTitle(res.rarity).toUpperCase()} DÜŞÜŞ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: clr,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'İhtimal: %${res.probabilityPct.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  res.itemName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Simüle Edilen Kademe: Seviye ${res.level}',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedTitanium.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulateActionDeck(Map<String, int> weights, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Level selector quick pills
        SizedBox(
          height: 26,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (BuildContext ctx, int idx) {
              final int lvl = idx + 1;
              final bool isSel = lvl == _selectedSimLevel;
              final bool isCur = lvl == widget.currentLevel;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSimLevel = lvl);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: isSel
                        ? AppColors.liquidGold.withValues(alpha: 0.22)
                        : AppColors.bgDeep.withValues(alpha: 0.6),
                    border: Border.all(
                      color: isSel
                          ? AppColors.liquidGold
                          : (isCur
                              ? AppColors.toxicNeon.withValues(alpha: 0.5)
                              : AppColors.mutedTitanium.withValues(alpha: 0.25)),
                      width: isSel ? 1.2 : 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Seviye $lvl',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        color: isSel
                            ? AppColors.liquidGold
                            : (isCur ? AppColors.toxicNeon : AppColors.mutedTitanium),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Simulate Action Button with Ripple & Glow
        FacGoldButton(
          label: '✨ Şansı Simüle Et (Seviye $_selectedSimLevel)',
          height: 40,
          onPressed: () => _triggerSimulation(),
        ),

        // Recent History Pills
        if (_recentHistory.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: _recentHistory.map((SimulatedDropResult item) {
              final Color clr = facRarityAccent(item.rarity);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: clr.withValues(alpha: 0.12),
                  border: Border.all(color: clr.withValues(alpha: 0.35), width: 0.7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(facilityRarityEmoji(item.rarity), style: const TextStyle(fontSize: 8)),
                    const SizedBox(width: 3),
                    Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: clr,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRarityTierChips(Map<String, int> weights, int total) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: kFacilityResourceRarities.map((String rarity) {
          final double pct =
              total > 0 ? ((weights[rarity] ?? 0) / total) * 100 : 0;
          final bool isSelected = _highlightedRarity == rarity;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: RarityTierChip(
              rarity: rarity,
              percent: pct,
              isSelected: isSelected,
              onTap: () => _toggleHighlightRarity(rarity),
            ),
          );
        }).toList(),
      ),
    );
  }
}

