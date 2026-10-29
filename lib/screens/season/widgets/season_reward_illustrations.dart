import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Authentic 2027 Aion 2 Mobile Season Reward Illustrations.
/// Provides high-fidelity procedural vector illustrations for celestial wings,
/// epic weapon skins, diamond chests, and dye ampoules.

enum SeasonRewardIllustrationType {
  celestialWings,
  epicWeaponSkin,
  diamondChest,
  dyeAmpoule,
  goldCache,
  genericItem,
}

/// Unified widget to render any season reward illustration with a celestial aura.
class SeasonRewardIllustrationView extends StatelessWidget {
  const SeasonRewardIllustrationView({
    super.key,
    required this.type,
    this.size = 48.0,
    this.rarity = 'legendary',
    this.badgeText,
    this.showGlow = true,
  });

  final SeasonRewardIllustrationType type;
  final double size;
  final String rarity;
  final String? badgeText;
  final bool showGlow;

  /// Helper factory to automatically detect type from level or item keywords.
  factory SeasonRewardIllustrationView.fromReward({
    Key? key,
    required int level,
    required bool isVip,
    String? itemId,
    Map<String, dynamic>? item,
    int gold = 0,
    double size = 48.0,
  }) {
    final String? itemName = (item?['name'] as String?)?.toLowerCase();
    final String? itemDesc = (item?['description'] as String?)?.toLowerCase();
    final String rarity = (item?['rarity'] as String?) ?? 'epic';

    SeasonRewardIllustrationType type;

    if (level == 20 ||
        (itemName?.contains('kanat') ?? false) ||
        (itemName?.contains('wing') ?? false) ||
        (itemDesc?.contains('kanat') ?? false)) {
      type = SeasonRewardIllustrationType.celestialWings;
    } else if (level == 15 ||
        (itemName?.contains('silah') ?? false) ||
        (itemName?.contains('kılıç') ?? false) ||
        (itemName?.contains('weapon') ?? false) ||
        (itemName?.contains('skin') ?? false) ||
        (itemDesc?.contains('silah') ?? false)) {
      type = SeasonRewardIllustrationType.epicWeaponSkin;
    } else if (level == 5 ||
        (itemName?.contains('sandık') ?? false) ||
        (itemName?.contains('kasa') ?? false) ||
        (itemName?.contains('chest') ?? false) ||
        (itemDesc?.contains('sandık') ?? false)) {
      type = SeasonRewardIllustrationType.diamondChest;
    } else if (level == 10 ||
        (itemName?.contains('boya') ?? false) ||
        (itemName?.contains('ampul') ?? false) ||
        (itemName?.contains('dye') ?? false) ||
        (itemName?.contains('iksir') ?? false) ||
        (itemDesc?.contains('boya') ?? false)) {
      type = SeasonRewardIllustrationType.dyeAmpoule;
    } else if (gold > 0) {
      type = SeasonRewardIllustrationType.goldCache;
    } else {
      type = SeasonRewardIllustrationType.genericItem;
    }

    return SeasonRewardIllustrationView(
      key: key,
      type: type,
      size: size,
      rarity: rarity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = AppColors.forRarity(rarity);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Ambient Glow Aura
          if (showGlow)
            Container(
              width: size * 0.9,
              height: size * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (type == SeasonRewardIllustrationType.celestialWings ||
                            type == SeasonRewardIllustrationType.epicWeaponSkin)
                        ? AppColors.liquidGold.withValues(alpha: 0.35)
                        : rarityColor.withValues(alpha: 0.28),
                    blurRadius: size * 0.35,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

          // Custom Illustration Painter
          CustomPaint(
            size: Size(size, size),
            painter: _SeasonRewardPainter(
              type: type,
              rarityColor: rarityColor,
            ),
          ),

          // Optional badge
          if (badgeText != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: rarityColor.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    color: rarityColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SeasonRewardPainter extends CustomPainter {
  _SeasonRewardPainter({
    required this.type,
    required this.rarityColor,
  });

  final SeasonRewardIllustrationType type;
  final Color rarityColor;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case SeasonRewardIllustrationType.celestialWings:
        _drawCelestialWings(canvas, size);
        break;
      case SeasonRewardIllustrationType.epicWeaponSkin:
        _drawEpicWeaponSkin(canvas, size);
        break;
      case SeasonRewardIllustrationType.diamondChest:
        _drawDiamondChest(canvas, size);
        break;
      case SeasonRewardIllustrationType.dyeAmpoule:
        _drawDyeAmpoule(canvas, size);
        break;
      case SeasonRewardIllustrationType.goldCache:
        _drawGoldCache(canvas, size);
        break;
      case SeasonRewardIllustrationType.genericItem:
        _drawGenericAionItem(canvas, size);
        break;
    }
  }

  // 1. CELESTIAL WINGS ILLUSTRATION
  void _drawCelestialWings(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w * 0.5, h * 0.52);

    // Halo ring behind wings
    final Paint haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = SweepGradient(
        colors: <Color>[
          AppColors.liquidGold.withValues(alpha: 0.8),
          const Color(0xFF38BDF8).withValues(alpha: 0.8),
          AppColors.liquidGold.withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.38));
    canvas.drawCircle(center, w * 0.35, haloPaint);

    // Right Wing
    _drawWingFeathers(canvas, center, w * 0.42, isRight: true);
    // Left Wing
    _drawWingFeathers(canvas, center, w * 0.42, isRight: false);

    // Central Daeva Crest Core
    final Paint corePaint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[
          Color(0xFFFFFBEB),
          AppColors.liquidGold,
          Color(0xFF92400E),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.12));

    final Path crestPath = Path()
      ..moveTo(center.dx, center.dy - h * 0.14)
      ..lineTo(center.dx + w * 0.08, center.dy)
      ..lineTo(center.dx, center.dy + h * 0.14)
      ..lineTo(center.dx - w * 0.08, center.dy)
      ..close();
    canvas.drawPath(crestPath, corePaint);

    // Core gemstone sparkle
    final Paint gemPaint = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawCircle(center, w * 0.04, gemPaint);
  }

  void _drawWingFeathers(Canvas canvas, Offset origin, double wingSpan, {required bool isRight}) {
    final double sign = isRight ? 1.0 : -1.0;

    final List<List<double>> feathers = <List<double>>[
      <double>[0.35 * sign, -0.7, 0.9 * sign, -0.65, 2.5],
      <double>[0.45 * sign, -0.4, 0.98 * sign, -0.3, 2.2],
      <double>[0.45 * sign, -0.1, 0.92 * sign, 0.05, 2.0],
      <double>[0.35 * sign, 0.15, 0.75 * sign, 0.35, 1.8],
    ];

    final Paint featherPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < feathers.length; i++) {
      final item = feathers[i];
      final Path path = Path();
      path.moveTo(origin.dx + 4 * sign, origin.dy - 2);
      path.quadraticBezierTo(
        origin.dx + item[0] * wingSpan,
        origin.dy + item[1] * wingSpan,
        origin.dx + item[2] * wingSpan,
        origin.dy + item[3] * wingSpan,
      );

      featherPaint
        ..strokeWidth = item[4]
        ..shader = LinearGradient(
          begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
          end: isRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: <Color>[
            AppColors.liquidGold,
            const Color(0xFFBAE6FD),
            Colors.white.withValues(alpha: 0.9),
          ],
        ).createShader(Rect.fromLTWH(origin.dx - wingSpan, origin.dy - wingSpan, wingSpan * 2, wingSpan * 2));

      canvas.drawPath(path, featherPaint);
    }
  }

  // 2. EPIC WEAPON SKIN ILLUSTRATION
  void _drawEpicWeaponSkin(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.rotate(-math.pi / 4);

    final Path blade = Path()
      ..moveTo(0, -h * 0.44)
      ..lineTo(w * 0.08, -h * 0.35)
      ..lineTo(w * 0.07, h * 0.10)
      ..lineTo(0, h * 0.14)
      ..lineTo(-w * 0.07, h * 0.10)
      ..lineTo(-w * 0.08, -h * 0.35)
      ..close();

    final Paint bladePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFE0F2FE),
          Color(0xFF38BDF8),
          Color(0xFF1E3A8A),
        ],
      ).createShader(Rect.fromLTWH(-w * 0.1, -h * 0.45, w * 0.2, h * 0.6));
    canvas.drawPath(blade, bladePaint);

    final Paint fullerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white,
          AppColors.liquidGold,
          Color(0xFFF59E0B),
        ],
      ).createShader(Rect.fromLTWH(-2, -h * 0.4, 4, h * 0.5));
    canvas.drawLine(Offset(0, -h * 0.40), Offset(0, h * 0.10), fullerPaint);

    final Path guard = Path()
      ..moveTo(-w * 0.22, h * 0.14)
      ..quadraticBezierTo(0, h * 0.10, w * 0.22, h * 0.14)
      ..lineTo(w * 0.18, h * 0.20)
      ..quadraticBezierTo(0, h * 0.16, -w * 0.18, h * 0.20)
      ..close();

    final Paint guardPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFFF59E0B),
          AppColors.liquidGold,
          Color(0xFF78350F),
        ],
      ).createShader(Rect.fromLTWH(-w * 0.25, h * 0.10, w * 0.5, h * 0.12));
    canvas.drawPath(guard, guardPaint);

    canvas.drawCircle(Offset(0, h * 0.15), 2.5, Paint()..color = const Color(0xFFEF4444));

    final Paint gripPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(0, h * 0.18), Offset(0, h * 0.34), gripPaint);

    final Paint pommelPaint = Paint()..color = AppColors.liquidGold;
    canvas.drawCircle(Offset(0, h * 0.36), 3.5, pommelPaint);

    canvas.restore();
  }

  // 3. DIAMOND CHEST ILLUSTRATION
  void _drawDiamondChest(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Rect baseRect = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.62),
      width: w * 0.65,
      height: h * 0.40,
    );
    final RRect baseRRect = RRect.fromRectAndRadius(baseRect, const Radius.circular(5));

    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF1E293B),
          Color(0xFF0F172A),
          Color(0xFF020617),
        ],
      ).createShader(baseRect);
    canvas.drawRRect(baseRRect, bodyPaint);

    final Paint trimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFFFFFBEB),
          AppColors.liquidGold,
          Color(0xFFB45309),
        ],
      ).createShader(baseRect);
    canvas.drawRRect(baseRRect, trimPaint);

    final Path lid = Path()
      ..moveTo(w * 0.14, h * 0.44)
      ..lineTo(w * 0.28, h * 0.22)
      ..lineTo(w * 0.72, h * 0.22)
      ..lineTo(w * 0.86, h * 0.44)
      ..close();

    final Paint lidPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFE0F2FE),
          Color(0xFF38BDF8),
          Color(0xFF0369A1),
        ],
      ).createShader(Rect.fromLTWH(w * 0.14, h * 0.22, w * 0.72, h * 0.24));
    canvas.drawPath(lid, lidPaint);

    final Paint facetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawLine(Offset(w * 0.28, h * 0.22), Offset(w * 0.38, h * 0.44), facetPaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.22), Offset(w * 0.62, h * 0.44), facetPaint);

    final Offset lockCenter = Offset(w * 0.5, h * 0.50);
    final Paint lockPaint = Paint()..color = AppColors.liquidGold;
    canvas.drawCircle(lockCenter, w * 0.09, lockPaint);

    final Paint gemPaint = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawCircle(lockCenter, w * 0.045, gemPaint);

    final Paint rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(lockCenter.dx - 6, lockCenter.dy), Offset(lockCenter.dx + 6, lockCenter.dy), rayPaint);
    canvas.drawLine(Offset(lockCenter.dx, lockCenter.dy - 6), Offset(lockCenter.dx, lockCenter.dy + 6), rayPaint);
  }

  // 4. DYE AMPOULE ILLUSTRATION
  void _drawDyeAmpoule(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w * 0.5, h * 0.55);

    final double bulbRadius = w * 0.26;
    final Rect bulbRect = Rect.fromCircle(center: center, radius: bulbRadius);

    final Paint liquidPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.2, 0.2),
        colors: <Color>[
          Color(0xFFF472B6),
          Color(0xFFC026D3),
          Color(0xFF581C87),
        ],
      ).createShader(bulbRect);
    canvas.drawCircle(center, bulbRadius, liquidPaint);

    final Rect neckRect = Rect.fromLTWH(w * 0.40, h * 0.18, w * 0.20, h * 0.18);
    canvas.drawRect(neckRect, Paint()..color = const Color(0xFFC026D3));

    final Paint glassOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white,
          Color(0x88FFFFFF),
          Color(0x33A855F7),
        ],
      ).createShader(bulbRect);
    canvas.drawCircle(center, bulbRadius, glassOutline);
    canvas.drawRect(neckRect, glassOutline);

    final Path cap = Path()
      ..moveTo(w * 0.35, h * 0.18)
      ..lineTo(w * 0.65, h * 0.18)
      ..lineTo(w * 0.58, h * 0.08)
      ..lineTo(w * 0.42, h * 0.08)
      ..close();

    final Paint capPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          AppColors.liquidGold,
          Color(0xFFFFFBEB),
          Color(0xFFB45309),
        ],
      ).createShader(Rect.fromLTWH(w * 0.35, h * 0.08, w * 0.30, h * 0.10));
    canvas.drawPath(cap, capPaint);

    canvas.drawCircle(Offset(w * 0.5, h * 0.07), 2.5, Paint()..color = const Color(0xFF38BDF8));

    final Path specular = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: bulbRadius * 0.75),
        -math.pi * 0.75,
        math.pi * 0.5,
      );
    final Paint specPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawPath(specular, specPaint);
  }

  // 5. GOLD CACHE ILLUSTRATION
  void _drawGoldCache(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    _drawCoin(canvas, Offset(w * 0.38, h * 0.66), w * 0.18);
    _drawCoin(canvas, Offset(w * 0.62, h * 0.68), w * 0.18);
    _drawCoin(canvas, Offset(w * 0.48, h * 0.52), w * 0.20);
    _drawCoin(canvas, Offset(w * 0.35, h * 0.42), w * 0.17);
    _drawCoin(canvas, Offset(w * 0.58, h * 0.38), w * 0.19);

    final Paint sparkPaint = Paint()..color = const Color(0xFFFFFBEB);
    canvas.drawCircle(Offset(w * 0.75, h * 0.30), 1.5, sparkPaint);
    canvas.drawCircle(Offset(w * 0.25, h * 0.50), 1.2, sparkPaint);
  }

  void _drawCoin(Canvas canvas, Offset center, double radius) {
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint coinPaint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[
          Color(0xFFFFFBEB),
          AppColors.liquidGold,
          Color(0xFF92400E),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, coinPaint);

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFFFFBEB);
    canvas.drawCircle(center, radius * 0.75, borderPaint);

    final Paint runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF78350F);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.45),
      Offset(center.dx, center.dy + radius * 0.45),
      runePaint,
    );
  }

  // 6. GENERIC AION ITEM (Celestial Crest / Sigil)
  void _drawGenericAionItem(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w * 0.5, h * 0.5);

    final Path diamond = Path()
      ..moveTo(center.dx, center.dy - h * 0.35)
      ..lineTo(center.dx + w * 0.35, center.dy)
      ..lineTo(center.dx + w * 0.35, center.dy)
      ..lineTo(center.dx, center.dy + h * 0.35)
      ..lineTo(center.dx - w * 0.35, center.dy)
      ..close();

    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          rarityColor.withValues(alpha: 0.8),
          rarityColor.withValues(alpha: 0.2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.35));
    canvas.drawPath(diamond, fill);

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = rarityColor;
    canvas.drawPath(diamond, border);

    canvas.drawCircle(center, w * 0.10, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SeasonRewardPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.rarityColor != rarityColor;
  }
}
