import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../screens/loot/loot_chest_theme.dart';
import '../../theme/app_colors.dart';

// =============================================================================
// 1. AION 2 CURRENCY ILLUSTRATIONS (GOLD COIN, ASTRAL GEM, SHARD, TOKEN)
// =============================================================================

enum AionCurrencyType {
  gold,
  gem,
  shard,
  token,
}

/// Ultra-high fidelity vector illustration for Aion 2 Mobile currencies.
/// Includes multi-layer radial gradients, specular highlights, and ambient glow.
class AionCurrencyIllustration extends StatelessWidget {
  const AionCurrencyIllustration({
    super.key,
    required this.type,
    this.size = 24,
    this.showGlow = true,
  });

  const AionCurrencyIllustration.gold({
    super.key,
    this.size = 24,
    this.showGlow = true,
  }) : type = AionCurrencyType.gold;

  const AionCurrencyIllustration.gem({
    super.key,
    this.size = 24,
    this.showGlow = true,
  }) : type = AionCurrencyType.gem;

  const AionCurrencyIllustration.shard({
    super.key,
    this.size = 24,
    this.showGlow = true,
  }) : type = AionCurrencyType.shard;

  const AionCurrencyIllustration.token({
    super.key,
    this.size = 24,
    this.showGlow = true,
  }) : type = AionCurrencyType.token;

  final AionCurrencyType type;
  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AionCurrencyPainter(type: type, showGlow: showGlow),
      ),
    );
  }
}

class _AionCurrencyPainter extends CustomPainter {
  const _AionCurrencyPainter({required this.type, required this.showGlow});

  final AionCurrencyType type;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case AionCurrencyType.gold:
        _drawGoldCoin(canvas, size);
        break;
      case AionCurrencyType.gem:
        _drawAstralGem(canvas, size);
        break;
      case AionCurrencyType.shard:
        _drawCosmicShard(canvas, size);
        break;
      case AionCurrencyType.token:
        _drawAbyssToken(canvas, size);
        break;
    }
  }

  void _drawGoldCoin(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center, radius + 2, glowPaint);
    }

    // Outer Coin Rim (Dark bronze to brilliant gold)
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFEF08A), Color(0xFFF59E0B), Color(0xFF78350F)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, rimPaint);

    // Beveled Inner Rim Ring
    final beveledPaint = Paint()
      ..color = const Color(0xFF451A03).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04;
    canvas.drawCircle(center, radius * 0.88, beveledPaint);

    // Inner Coin Face
    final innerRadius = radius * 0.80;
    final innerPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFCD34D), Color(0xFFD97706), Color(0xFF92400E)],
        stops: [0.3, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.drawCircle(center, innerRadius, innerPaint);

    // Stamped Celestial Sunburst / Star Emblem
    final starPath = Path();
    const spikes = 8;
    final outerR = innerRadius * 0.70;
    final innerR = innerRadius * 0.35;
    for (int i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / spikes) - (math.pi / 2);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();

    final starPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFBEB), Color(0xFFFDE68A)],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));
    canvas.drawPath(starPath, starPaint);

    // Center Core Gem/Rune Dot
    final corePaint = Paint()..color = const Color(0xFF78350F);
    canvas.drawCircle(center, innerRadius * 0.16, corePaint);

    // Specular Highlight Arc
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius * 0.94),
      math.pi * 1.15,
      math.pi * 0.55,
      false,
      highlightPaint,
    );
  }

  void _drawAstralGem(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF06B6D4).withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.45, glowPaint);
    }

    // Classic Brilliant Cut Faceted Astral Diamond
    final topY = h * 0.14;
    final shoulderY = h * 0.42;
    final bottomY = h * 0.88;
    final tableL = w * 0.28;
    final tableR = w * 0.72;
    final leftX = w * 0.10;
    final rightX = w * 0.90;
    final centerX = w * 0.50;

    // 1. Table Facet (Top Flat Crown)
    final crownPath = Path()
      ..moveTo(tableL, topY)
      ..lineTo(tableR, topY)
      ..lineTo(rightX, shoulderY)
      ..lineTo(leftX, shoulderY)
      ..close();
    final crownPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0284C7)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(crownPath, crownPaint);

    // 2. Pavilion (Lower Triangle Cone)
    final pavPath = Path()
      ..moveTo(leftX, shoulderY)
      ..lineTo(rightX, shoulderY)
      ..lineTo(centerX, bottomY)
      ..close();
    final pavPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF082F49)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(pavPath, pavPaint);

    // 3. Facet Bevel Lines & Refractions
    final facetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035;

    canvas.drawLine(Offset(tableL, topY), Offset(w * 0.36, shoulderY), facetPaint);
    canvas.drawLine(Offset(tableR, topY), Offset(w * 0.64, shoulderY), facetPaint);
    canvas.drawLine(Offset(w * 0.36, shoulderY), Offset(centerX, bottomY), facetPaint);
    canvas.drawLine(Offset(w * 0.64, shoulderY), Offset(centerX, bottomY), facetPaint);

    // 4. Starlight Glint Flares
    final glintPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(tableL + 2, topY + 2), size.width * 0.05, glintPaint);
    canvas.drawCircle(Offset(centerX, shoulderY * 0.7), size.width * 0.04, glintPaint);
  }

  void _drawCosmicShard(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFA855F7).withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, glowPaint);
    }

    // Jagged Arcane Crystal Fragment
    final shardPath = Path()
      ..moveTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.82, h * 0.35)
      ..lineTo(w * 0.74, h * 0.78)
      ..lineTo(w * 0.45, h * 0.90)
      ..lineTo(w * 0.18, h * 0.62)
      ..lineTo(w * 0.28, h * 0.30)
      ..close();

    final shardPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFAF5FF), Color(0xFFA855F7), Color(0xFF581C87)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shardPath, shardPaint);

    // Glowing Inner Fracture Lines
    final fracturePaint = Paint()
      ..color = const Color(0xFFF3E8FF).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04;

    final fracturePath = Path()
      ..moveTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.48, h * 0.54)
      ..lineTo(w * 0.74, h * 0.78)
      ..moveTo(w * 0.48, h * 0.54)
      ..lineTo(w * 0.18, h * 0.62);
    canvas.drawPath(fracturePath, fracturePaint);
  }

  void _drawAbyssToken(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.44;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFDC2626).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center, r + 2, glowPaint);
    }

    // Heavy Obsidian Coin Base
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF374151), Color(0xFF111827), Color(0xFF030712)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, basePaint);

    // Crimson Runic Circle Rim
    final rimPaint = Paint()
      ..color = const Color(0xFFDC2626).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, r * 0.82, rimPaint);

    // Center Demon Horns / Crest Sigil
    final crestPath = Path()
      ..moveTo(center.dx - r * 0.4, center.dy - r * 0.25)
      ..quadraticBezierTo(center.dx, center.dy - r * 0.45, center.dx + r * 0.4, center.dy - r * 0.25)
      ..lineTo(center.dx + r * 0.2, center.dy + r * 0.4)
      ..lineTo(center.dx, center.dy + r * 0.2)
      ..lineTo(center.dx - r * 0.2, center.dy + r * 0.4)
      ..close();

    final crestPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFCA5A5), Color(0xFFDC2626)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.5));
    canvas.drawPath(crestPath, crestPaint);
  }

  @override
  bool shouldRepaint(covariant _AionCurrencyPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.showGlow != showGlow;
  }
}

/// Compact pill badge displaying an Aion 2 currency icon with formatted quantity.
class AionCurrencyBadge extends StatelessWidget {
  const AionCurrencyBadge({
    super.key,
    required this.type,
    required this.amount,
    this.iconSize = 16,
    this.fontSize = 12,
    this.customColor,
  });

  const AionCurrencyBadge.gold({
    super.key,
    required this.amount,
    this.iconSize = 16,
    this.fontSize = 12,
    this.customColor,
  }) : type = AionCurrencyType.gold;

  const AionCurrencyBadge.gem({
    super.key,
    required this.amount,
    this.iconSize = 16,
    this.fontSize = 12,
    this.customColor,
  }) : type = AionCurrencyType.gem;

  final AionCurrencyType type;
  final String amount;
  final double iconSize;
  final double fontSize;
  final Color? customColor;

  Color get _color =>
      customColor ??
      switch (type) {
        AionCurrencyType.gold => const Color(0xFFFBBF24),
        AionCurrencyType.gem => const Color(0xFF38BDF8),
        AionCurrencyType.shard => const Color(0xFFA855F7),
        AionCurrencyType.token => const Color(0xFFEF4444),
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AionCurrencyIllustration(type: type, size: iconSize, showGlow: false),
          const SizedBox(width: 5),
          Text(
            amount,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. GLOWING POTIONS (HEALTH, MANA, ENERGY, BUFF, DETOX, SHADOW)
// =============================================================================

enum AionPotionTheme {
  health, // Crimson Vitality
  mana,   // Astral Sapphire Arcane
  energy, // Sunburst Amber Stamina
  buff,   // Royal Violet Mastery
  detox,  // Emerald Cleansing
  shadow, // Abyssal Void Twilight
}

/// Authentic 2027 Aion 2 Glowing Potion Illustration.
/// Features glass bottle curvatures, floating luminous bubbles, cork wire seal,
/// and intense multi-stop internal luminescence.
class AionPotionIllustration extends StatelessWidget {
  const AionPotionIllustration({
    super.key,
    this.theme = AionPotionTheme.health,
    this.size = 32,
    this.showGlow = true,
  });

  final AionPotionTheme theme;
  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AionPotionPainter(theme: theme, showGlow: showGlow),
      ),
    );
  }
}

class _AionPotionPainter extends CustomPainter {
  const _AionPotionPainter({required this.theme, required this.showGlow});

  final AionPotionTheme theme;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Theme Color Setup
    final (liquidTop, liquidMid, liquidBottom, glowColor) = switch (theme) {
      AionPotionTheme.health => (
        const Color(0xFFFCA5A5),
        const Color(0xFFEF4444),
        const Color(0xFF7F1D1D),
        const Color(0xFFDC2626),
      ),
      AionPotionTheme.mana => (
        const Color(0xFFBAE6FD),
        const Color(0xFF0284C7),
        const Color(0xFF0C4A6E),
        const Color(0xFF06B6D4),
      ),
      AionPotionTheme.energy => (
        const Color(0xFFFEF08A),
        const Color(0xFFF59E0B),
        const Color(0xFF78350F),
        const Color(0xFFEAB308),
      ),
      AionPotionTheme.buff => (
        const Color(0xFFF5D0FE),
        const Color(0xFFA855F7),
        const Color(0xFF581C87),
        const Color(0xFFC084FC),
      ),
      AionPotionTheme.detox => (
        const Color(0xFFA7F3D0),
        const Color(0xFF10B981),
        const Color(0xFF064E3B),
        const Color(0xFF059669),
      ),
      AionPotionTheme.shadow => (
        const Color(0xFFDDD6FE),
        const Color(0xFF6366F1),
        const Color(0xFF1E1B4B),
        const Color(0xFF818CF8),
      ),
    };

    // 1. Exterior Ambient Glow
    if (showGlow) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(w / 2, h * 0.58), w * 0.40, glowPaint);
    }

    // 2. Glass Flask Geometry
    // Neck
    final neckLeft = w * 0.40;
    final neckRight = w * 0.60;
    final neckTop = h * 0.16;
    final neckBottom = h * 0.34;

    // Belly (Spherical / Flask Bulb)
    final flaskPath = Path()
      ..moveTo(neckLeft, neckBottom)
      ..lineTo(neckLeft, neckTop)
      ..lineTo(neckRight, neckTop)
      ..lineTo(neckRight, neckBottom)
      ..cubicTo(w * 0.88, h * 0.42, w * 0.92, h * 0.84, w * 0.50, h * 0.92)
      ..cubicTo(w * 0.08, h * 0.84, w * 0.12, h * 0.42, neckLeft, neckBottom)
      ..close();

    // Dark Glass Backdrop
    final bgGlassPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.85);
    canvas.drawPath(flaskPath, bgGlassPaint);

    // 3. Liquid Interior Fill
    final liquidPath = Path()
      ..moveTo(w * 0.20, h * 0.50)
      ..cubicTo(w * 0.35, h * 0.48, w * 0.65, h * 0.52, w * 0.80, h * 0.50)
      ..cubicTo(w * 0.90, h * 0.78, w * 0.75, h * 0.90, w * 0.50, h * 0.90)
      ..cubicTo(w * 0.25, h * 0.90, w * 0.10, h * 0.78, w * 0.20, h * 0.50)
      ..close();

    final liquidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [liquidTop, liquidMid, liquidBottom],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(liquidPath, liquidPaint);

    // 4. Luminous Micro-Bubbles
    final bubblePaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(w * 0.42, h * 0.65), size.width * 0.045, bubblePaint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.72), size.width * 0.035, bubblePaint);
    canvas.drawCircle(Offset(w * 0.52, h * 0.80), size.width * 0.025, bubblePaint);

    // 5. Wooden / Golden Cork Stopper & Lip
    final corkPath = Path()
      ..moveTo(neckLeft - w * 0.04, neckTop)
      ..lineTo(neckLeft - w * 0.02, h * 0.07)
      ..lineTo(neckRight + w * 0.02, h * 0.07)
      ..lineTo(neckRight + w * 0.04, neckTop)
      ..close();

    final corkPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFF78350F)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(corkPath, corkPaint);

    // Metallic Neck Ring / Seal
    final ringPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04;
    canvas.drawLine(Offset(neckLeft - 1, neckTop + 1), Offset(neckRight + 1, neckTop + 1), ringPaint);

    // 6. Glass Highlights & Specular Flank Curves
    final glassOutline = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035;
    canvas.drawPath(flaskPath, glassOutline);

    final highlightArc = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.63), radius: w * 0.32),
      math.pi * 0.90,
      math.pi * 0.50,
      false,
      highlightArc,
    );
  }

  @override
  bool shouldRepaint(covariant _AionPotionPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.showGlow != showGlow;
  }
}

// =============================================================================
// 3. CRAFTING MATERIALS (RUNE CRYSTAL, ORE INGOT, HERB, LUMBER, SILK, CATALYST)
// =============================================================================

enum AionCraftingMaterialType {
  runeCrystal,
  oreIngot,
  herbFlora,
  lumberWood,
  silkLeather,
  alchemicalCatalyst,
}

/// Authentic 2027 Aion 2 Dark-Fantasy Crafting Material Illustration.
class AionCraftingMaterialIllustration extends StatelessWidget {
  const AionCraftingMaterialIllustration({
    super.key,
    required this.materialType,
    this.size = 32,
    this.showGlow = true,
  });

  final AionCraftingMaterialType materialType;
  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AionCraftingMaterialPainter(
          materialType: materialType,
          showGlow: showGlow,
        ),
      ),
    );
  }
}

class _AionCraftingMaterialPainter extends CustomPainter {
  const _AionCraftingMaterialPainter({
    required this.materialType,
    required this.showGlow,
  });

  final AionCraftingMaterialType materialType;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    switch (materialType) {
      case AionCraftingMaterialType.runeCrystal:
        _drawRuneCrystal(canvas, size);
        break;
      case AionCraftingMaterialType.oreIngot:
        _drawOreIngot(canvas, size);
        break;
      case AionCraftingMaterialType.herbFlora:
        _drawHerbFlora(canvas, size);
        break;
      case AionCraftingMaterialType.lumberWood:
        _drawLumberWood(canvas, size);
        break;
      case AionCraftingMaterialType.silkLeather:
        _drawSilkLeather(canvas, size);
        break;
      case AionCraftingMaterialType.alchemicalCatalyst:
        _drawCatalyst(canvas, size);
        break;
    }
  }

  void _drawRuneCrystal(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.44;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF818CF8).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, r + 2, glowPaint);
    }

    // Hexagonal Runic Crystal Shard
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) - (math.pi / 6);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();

    final hexPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0E7FF), Color(0xFF6366F1), Color(0xFF312E81)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(hexPath, hexPaint);

    // Inner Glowing Rune Node
    final runePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, r * 0.45, runePaint);

    final corePaint = Paint()..color = const Color(0xFFC7D2FE);
    canvas.drawCircle(center, r * 0.20, corePaint);
  }

  void _drawOreIngot(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFF97316).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, glowPaint);
    }

    // Dragon-Forged Beveled Metal Bar
    final ingotPath = Path()
      ..moveTo(w * 0.22, h * 0.30)
      ..lineTo(w * 0.78, h * 0.30)
      ..lineTo(w * 0.90, h * 0.70)
      ..lineTo(w * 0.10, h * 0.70)
      ..close();

    final ingotPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFED7AA), Color(0xFFEA580C), Color(0xFF7C2D12)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(ingotPath, ingotPaint);

    // Glowing Molten Vein
    final veinPaint = Paint()
      ..color = const Color(0xFFFEF08A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.30, h * 0.50), Offset(w * 0.70, h * 0.50), veinPaint);
  }

  void _drawHerbFlora(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, glowPaint);
    }

    // Celestial Starlight Lotus Petals
    final center = Offset(w * 0.5, h * 0.55);
    const petalCount = 5;
    for (int i = 0; i < petalCount; i++) {
      final angle = (i * 2 * math.pi / petalCount) - (math.pi / 2);
      final petalPath = Path();
      petalPath.moveTo(center.dx, center.dy);
      final tipX = center.dx + w * 0.38 * math.cos(angle);
      final tipY = center.dy + w * 0.38 * math.sin(angle);
      final c1X = center.dx + w * 0.24 * math.cos(angle - 0.4);
      final c1Y = center.dy + w * 0.24 * math.sin(angle - 0.4);
      final c2X = center.dx + w * 0.24 * math.cos(angle + 0.4);
      final c2Y = center.dy + w * 0.24 * math.sin(angle + 0.4);

      petalPath.cubicTo(c1X, c1Y, tipX, tipY, tipX, tipY);
      petalPath.cubicTo(tipX, tipY, c2X, c2Y, center.dx, center.dy);
      petalPath.close();

      final petalPaint = Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFFA7F3D0), Color(0xFF10B981), Color(0xFF065F46)],
        ).createShader(Rect.fromCircle(center: center, radius: w * 0.4));
      canvas.drawPath(petalPath, petalPaint);
    }

    // Glowing Pollen Stamen Core
    final corePaint = Paint()..color = const Color(0xFFFEF08A);
    canvas.drawCircle(center, w * 0.12, corePaint);
  }

  void _drawLumberWood(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFD97706).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, glowPaint);
    }

    // Ancient Elderwood Log Section
    final woodPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.72, height: h * 0.54),
        Radius.circular(w * 0.12),
      ));

    final woodPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD97706), Color(0xFF92400E), Color(0xFF451A03)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(woodPath, woodPaint);

    // Glowing Amber Sap Vein
    final sapPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;
    canvas.drawLine(Offset(w * 0.26, h * 0.5), Offset(w * 0.74, h * 0.5), sapPaint);
  }

  void _drawSilkLeather(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFEC4899).withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, glowPaint);
    }

    // Rolled Celestial Silk Swatch
    final silkPath = Path()
      ..moveTo(w * 0.18, h * 0.24)
      ..lineTo(w * 0.82, h * 0.18)
      ..quadraticBezierTo(w * 0.90, h * 0.50, w * 0.80, h * 0.82)
      ..lineTo(w * 0.16, h * 0.86)
      ..quadraticBezierTo(w * 0.10, h * 0.50, w * 0.18, h * 0.24)
      ..close();

    final silkPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFCE7F3), Color(0xFFEC4899), Color(0xFF831843)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(silkPath, silkPaint);

    // Golden Stitch Trim
    final trimPaint = Paint()
      ..color = const Color(0xFFFDE047)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04;
    canvas.drawPath(silkPath, trimPaint);
  }

  void _drawCatalyst(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF06B6D4).withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, r + 2, glowPaint);
    }

    // Outer Gyroscope Brass Ring
    final ringPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06;
    canvas.drawCircle(center, r, ringPaint);

    // Diagonal Crossed Ring
    final innerRingPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 1.8, height: r * 0.8),
      innerRingPaint,
    );

    // Pulsing Arcane Sphere Core
    final spherePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFE0F2FE), Color(0xFF06B6D4), Color(0xFF083344)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.5));
    canvas.drawCircle(center, r * 0.5, spherePaint);
  }

  @override
  bool shouldRepaint(covariant _AionCraftingMaterialPainter oldDelegate) {
    return oldDelegate.materialType != materialType || oldDelegate.showGlow != showGlow;
  }
}

// =============================================================================
// 4. TREASURE CHEST ILLUSTRATIONS (5 TIERS WITH GENUINE VECTOR FALLBACK)
// =============================================================================

/// Authentic 2027 Aion 2 Treasure Chest Illustration.
/// Used directly or as robust fallback rendering when chest image assets fail.
class AionChestIllustration extends StatelessWidget {
  const AionChestIllustration({
    super.key,
    this.tier = LootChestTier.common,
    this.size = 48,
    this.showGlow = true,
  });

  final LootChestTier tier;
  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AionChestPainter(tier: tier, showGlow: showGlow),
      ),
    );
  }
}

class _AionChestPainter extends CustomPainter {
  const _AionChestPainter({required this.tier, required this.showGlow});

  final LootChestTier tier;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final (primaryColor, trimColor, accentColor, glowColor) = switch (tier) {
      LootChestTier.common => (
        const Color(0xFF4B5563), // Weathered Iron
        const Color(0xFF78350F), // Oak
        const Color(0xFFD1D5DB),
        const Color(0xFF9CA3AF),
      ),
      LootChestTier.rare => (
        const Color(0xFF1E3A8A), // Polished Cobalt
        const Color(0xFF94A3B8), // Silver Filigree
        const Color(0xFF38BDF8),
        const Color(0xFF2563EB),
      ),
      LootChestTier.heroic => (
        const Color(0xFF881337), // Crimson Velvet
        const Color(0xFFF59E0B), // Gilded Gold
        const Color(0xFFFDE047),
        const Color(0xFFE11D48),
      ),
      LootChestTier.fabled => (
        const Color(0xFF083344), // Deep Astral Cyan
        const Color(0xFFE2E8F0), // Shimmering Platinum
        const Color(0xFF22D3EE),
        const Color(0xFF06B6D4),
      ),
      LootChestTier.eternal => (
        const Color(0xFF09090B), // Abyssal Obsidian
        const Color(0xFF9333EA), // Burning Purple Rune Trim
        const Color(0xFFC084FC),
        const Color(0xFFA855F7),
      ),
    };

    // 1. Radiating Ambient Glow
    if (showGlow) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(w * 0.5, h * 0.55), w * 0.44, glowPaint);
    }

    // 2. Chest Lower Body Box
    final bodyRect = Rect.fromLTWH(w * 0.14, h * 0.44, w * 0.72, h * 0.46);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.08));

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primaryColor, primaryColor.withValues(alpha: 0.85), Colors.black],
      ).createShader(bodyRect);
    canvas.drawRRect(bodyRRect, bodyPaint);

    // 3. Radiant Treasure Seam Fissure (Glow between lid and body)
    final fissurePaint = Paint()
      ..color = accentColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(Offset(w * 0.16, h * 0.45), Offset(w * 0.84, h * 0.45), fissurePaint);

    // 4. Chest Curved Lid
    final lidPath = Path()
      ..moveTo(w * 0.12, h * 0.45)
      ..cubicTo(w * 0.16, h * 0.15, w * 0.84, h * 0.15, w * 0.88, h * 0.45)
      ..close();

    final lidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [trimColor, primaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(lidPath, lidPaint);

    // 5. Metallic Trim Bands & Corner Brackets
    final trimPaint = Paint()
      ..color = trimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;
    canvas.drawRRect(bodyRRect, trimPaint);
    canvas.drawPath(lidPath, trimPaint);

    // Vertical Straps
    canvas.drawLine(Offset(w * 0.32, h * 0.22), Offset(w * 0.32, h * 0.90), trimPaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.22), Offset(w * 0.68, h * 0.90), trimPaint);

    // 6. Central Ornate Lock Plate & Keyhole
    final lockCenter = Offset(w * 0.50, h * 0.47);
    final lockRect = Rect.fromCenter(center: lockCenter, width: w * 0.20, height: h * 0.20);
    final lockPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFFEF3C7), trimColor],
      ).createShader(lockRect);
    canvas.drawRRect(RRect.fromRectAndRadius(lockRect, Radius.circular(w * 0.04)), lockPaint);

    // Glowing Keyhole
    final keyholePaint = Paint()..color = accentColor;
    canvas.drawCircle(Offset(lockCenter.dx, lockCenter.dy - 1), size.width * 0.035, keyholePaint);
  }

  @override
  bool shouldRepaint(covariant _AionChestPainter oldDelegate) {
    return oldDelegate.tier != tier || oldDelegate.showGlow != showGlow;
  }
}
