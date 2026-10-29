import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Available fantasy kingdom crest types.
enum KingdomCrestType {
  territory,
  treasury,
  army,
  diplomacy,
  crown,
  blessing,
}

/// High-res vector-drawn fantasy kingdom crest with glowing aura and runic detail.
///
/// Designed to scale crisply across all mobile resolutions (Retina / high-DPI)
/// without pixelation.
class KingdomCrestIcon extends StatefulWidget {
  const KingdomCrestIcon({
    super.key,
    required this.type,
    this.size = 48.0,
    this.primaryColor,
    this.secondaryColor,
    this.showGlow = true,
    this.animatedPulse = false,
    this.badgeText,
  });

  final KingdomCrestType type;
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool showGlow;
  final bool animatedPulse;
  final String? badgeText;

  @override
  State<KingdomCrestIcon> createState() => _KingdomCrestIconState();
}

class _KingdomCrestIconState extends State<KingdomCrestIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.animatedPulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant KingdomCrestIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animatedPulse != oldWidget.animatedPulse) {
      if (widget.animatedPulse) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getPalette(widget.type, widget.primaryColor, widget.secondaryColor);

    Widget crest = CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _KingdomCrestPainter(
        type: widget.type,
        primaryColor: colors.$1,
        secondaryColor: colors.$2,
        accentColor: colors.$3,
        showGlow: widget.showGlow,
      ),
    );

    if (widget.animatedPulse) {
      crest = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 + (_controller.value * 0.06);
          final glowAlpha = 0.4 + (_controller.value * 0.4);
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.$1.withValues(alpha: glowAlpha * 0.35),
                    blurRadius: widget.size * 0.5,
                    spreadRadius: widget.size * 0.08,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: crest,
      );
    }

    if (widget.badgeText != null && widget.badgeText!.isNotEmpty) {
      crest = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          crest,
          Positioned(
            right: -4,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.$1.withValues(alpha: 0.8),
                  width: 1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.$1.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                widget.badgeText!,
                style: TextStyle(
                  color: colors.$1,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(child: crest),
    );
  }

  (Color, Color, Color) _getPalette(
    KingdomCrestType type,
    Color? primary,
    Color? secondary,
  ) {
    switch (type) {
      case KingdomCrestType.territory:
        return (
          primary ?? const Color(0xFF38BDF8), // Cyan / Azure
          secondary ?? const Color(0xFF1E3A8A), // Deep Cobalt
          const Color(0xFF7DD3FC), // Highlights
        );
      case KingdomCrestType.treasury:
        return (
          primary ?? const Color(0xFFFBBF24), // Imperial Gold
          secondary ?? const Color(0xFF92400E), // Burnished Amber
          const Color(0xFFFEF08A), // Shimmering Gold
        );
      case KingdomCrestType.army:
        return (
          primary ?? const Color(0xFFF87171), // Crimson Flame
          secondary ?? const Color(0xFF991B1B), // Dark Iron
          const Color(0xFFFCA5A5), // Blade Sheen
        );
      case KingdomCrestType.diplomacy:
        return (
          primary ?? const Color(0xFFA78BFA), // Royal Amethyst
          secondary ?? const Color(0xFF5B21B6), // Deep Violet
          const Color(0xFFDDD6FE), // Ethereal Rune
        );
      case KingdomCrestType.crown:
      case KingdomCrestType.blessing:
        return (
          primary ?? AppColors.liquidGold, // Radiant Sun Gold
          secondary ?? const Color(0xFFB45309), // Ancient Bronze
          const Color(0xFF67E8F9), // Celestial Diamond Sparkle
        );
    }
  }
}

/// Custom painter for all high-res kingdom crest vectors.
class _KingdomCrestPainter extends CustomPainter {
  const _KingdomCrestPainter({
    required this.type,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.showGlow,
  });

  final KingdomCrestType type;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    if (showGlow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: <Color>[
            primaryColor.withValues(alpha: 0.35),
            primaryColor.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: w * 0.65));
      canvas.drawCircle(center, w * 0.65, glowPaint);
    }

    switch (type) {
      case KingdomCrestType.territory:
        _paintTerritoryCitadel(canvas, size);
        break;
      case KingdomCrestType.treasury:
        _paintTreasuryVault(canvas, size);
        break;
      case KingdomCrestType.army:
        _paintArmyLegion(canvas, size);
        break;
      case KingdomCrestType.diplomacy:
        _paintDiplomacyScroll(canvas, size);
        break;
      case KingdomCrestType.crown:
        _paintCelestialCrown(canvas, size);
        break;
      case KingdomCrestType.blessing:
        _paintRoyalBlessing(canvas, size);
        break;
    }
  }

  /// Territory: Fortified Citadel Bastion with runic towers & compass star
  void _paintTerritoryCitadel(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer runic shield frame
    final shieldPath = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.88, h * 0.22)
      ..cubicTo(w * 0.92, h * 0.58, w * 0.72, h * 0.86, w * 0.5, h * 0.95)
      ..cubicTo(w * 0.28, h * 0.86, w * 0.08, h * 0.58, w * 0.12, h * 0.22)
      ..close();

    final shieldBgPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          secondaryColor.withValues(alpha: 0.85),
          const Color(0xFF090D1A).withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shieldPath, shieldBgPaint);

    final shieldBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[accentColor, primaryColor, secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shieldPath, shieldBorderPaint);

    // Castle Citadel Towers
    final castlePath = Path();
    // Central keep & towers
    castlePath.moveTo(w * 0.32, h * 0.72);
    castlePath.lineTo(w * 0.32, h * 0.42);
    castlePath.lineTo(w * 0.38, h * 0.42);
    castlePath.lineTo(w * 0.38, h * 0.48);
    castlePath.lineTo(w * 0.44, h * 0.48);
    castlePath.lineTo(w * 0.44, h * 0.34);
    castlePath.lineTo(w * 0.50, h * 0.26); // Center spire tip
    castlePath.lineTo(w * 0.56, h * 0.34);
    castlePath.lineTo(w * 0.56, h * 0.48);
    castlePath.lineTo(w * 0.62, h * 0.48);
    castlePath.lineTo(w * 0.62, h * 0.42);
    castlePath.lineTo(w * 0.68, h * 0.42);
    castlePath.lineTo(w * 0.68, h * 0.72);
    castlePath.close();

    final castlePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[accentColor, primaryColor],
      ).createShader(Rect.fromLTWH(w * 0.3, h * 0.25, w * 0.4, h * 0.5));
    canvas.drawPath(castlePath, castlePaint);

    // Fortress Gate Archway
    final gatePath = Path()
      ..moveTo(w * 0.44, h * 0.72)
      ..lineTo(w * 0.44, h * 0.56)
      ..arcToPoint(Offset(w * 0.56, h * 0.56), radius: Radius.circular(w * 0.06))
      ..lineTo(w * 0.56, h * 0.72)
      ..close();

    final gatePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF0A0F1D);
    canvas.drawPath(gatePath, gatePaint);

    // Glowing gate gem
    final gemPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor;
    canvas.drawCircle(Offset(w * 0.5, h * 0.40), w * 0.035, gemPaint);
  }

  /// Treasury: Imperial Vault Chest with Gold Ingants & Star Gems
  void _paintTreasuryVault(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Glowing radiance disc
    final discPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..shader = SweepGradient(
        colors: <Color>[
          accentColor,
          primaryColor,
          secondaryColor,
          accentColor,
        ],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * 0.42));
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.42, discPaint);

    // Vault Base / Chest
    final chestBase = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.62), width: w * 0.58, height: h * 0.32),
      Radius.circular(w * 0.07),
    );
    final chestPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[accentColor, primaryColor, secondaryColor],
      ).createShader(chestBase.outerRect);
    canvas.drawRRect(chestBase, chestPaint);

    // Chest Lid Arch
    final lidPath = Path()
      ..moveTo(w * 0.20, h * 0.48)
      ..cubicTo(w * 0.20, h * 0.28, w * 0.80, h * 0.28, w * 0.80, h * 0.48)
      ..close();
    final lidPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Colors.white, accentColor, primaryColor],
      ).createShader(Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.6, h * 0.25));
    canvas.drawPath(lidPath, lidPaint);

    // Iron Banding / Filigree
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = const Color(0xFF1F1608);
    canvas.drawLine(Offset(w * 0.35, h * 0.33), Offset(w * 0.35, h * 0.77), bandPaint);
    canvas.drawLine(Offset(w * 0.65, h * 0.33), Offset(w * 0.65, h * 0.77), bandPaint);

    // Center Vault Runic Keyhole Diamond
    final keyholePath = Path()
      ..moveTo(w * 0.5, h * 0.44)
      ..lineTo(w * 0.56, h * 0.51)
      ..lineTo(w * 0.5, h * 0.58)
      ..lineTo(w * 0.44, h * 0.51)
      ..close();
    final keyholePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF38BDF8); // Sapphire core
    canvas.drawPath(keyholePath, keyholePaint);

    // Radiant Gold Coin in background
    final coinPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(w * 0.5, h * 0.24), w * 0.08, coinPaint);
  }

  /// Army: Crossed Celestial Winged Runeblades & Vanguard Aegis
  void _paintArmyLegion(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Crossed Blade 1 (Top-Left to Bottom-Right)
    final blade1 = Path()
      ..moveTo(w * 0.16, h * 0.18)
      ..lineTo(w * 0.26, h * 0.16)
      ..lineTo(w * 0.82, h * 0.82)
      ..lineTo(w * 0.84, h * 0.86)
      ..lineTo(w * 0.78, h * 0.84)
      ..close();

    // Crossed Blade 2 (Top-Right to Bottom-Left)
    final blade2 = Path()
      ..moveTo(w * 0.84, h * 0.18)
      ..lineTo(w * 0.74, h * 0.16)
      ..lineTo(w * 0.18, h * 0.82)
      ..lineTo(w * 0.16, h * 0.86)
      ..lineTo(w * 0.22, h * 0.84)
      ..close();

    final bladePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Colors.white, accentColor, primaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(blade1, bladePaint);
    canvas.drawPath(blade2, bladePaint);

    // Central Vanguard Shield
    final shield = Path()
      ..moveTo(w * 0.5, h * 0.24)
      ..lineTo(w * 0.74, h * 0.36)
      ..cubicTo(w * 0.74, h * 0.62, w * 0.62, h * 0.82, w * 0.5, h * 0.90)
      ..cubicTo(w * 0.38, h * 0.82, w * 0.26, h * 0.62, w * 0.26, h * 0.36)
      ..close();

    final shieldPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[primaryColor, secondaryColor, const Color(0xFF1E0A0A)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shield, shieldPaint);

    final shieldBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..color = accentColor;
    canvas.drawPath(shield, shieldBorder);

    // Center Lion/Vanguard Emblem
    final lionPath = Path()
      ..moveTo(w * 0.5, h * 0.40)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.54, h * 0.68)
      ..lineTo(w * 0.46, h * 0.68)
      ..lineTo(w * 0.42, h * 0.52)
      ..close();
    final lionPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawPath(lionPath, lionPaint);
  }

  /// Diplomacy: Imperial Scroll with Golden Seal & Laurel Leaves
  void _paintDiplomacyScroll(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Laurel Wreath branches (Left and Right)
    final wreathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..shader = LinearGradient(
        colors: <Color>[accentColor, primaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final leftBranch = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..cubicTo(w * 0.16, h * 0.82, w * 0.12, h * 0.38, w * 0.36, h * 0.16);
    final rightBranch = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..cubicTo(w * 0.84, h * 0.82, w * 0.88, h * 0.38, w * 0.64, h * 0.16);

    canvas.drawPath(leftBranch, wreathPaint);
    canvas.drawPath(rightBranch, wreathPaint);

    // Rolled Imperial Parchment
    final scrollRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.44, height: h * 0.54),
      Radius.circular(w * 0.06),
    );
    final scrollPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFFFBF7EE),
          const Color(0xFFE2D6C1),
          const Color(0xFFC7B696),
        ],
      ).createShader(scrollRect.outerRect);
    canvas.drawRRect(scrollRect, scrollPaint);

    // Scroll lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..color = const Color(0xFF6B583E).withValues(alpha: 0.6);
    canvas.drawLine(Offset(w * 0.36, h * 0.36), Offset(w * 0.64, h * 0.36), linePaint);
    canvas.drawLine(Offset(w * 0.36, h * 0.44), Offset(w * 0.64, h * 0.44), linePaint);
    canvas.drawLine(Offset(w * 0.36, h * 0.52), Offset(w * 0.58, h * 0.52), linePaint);

    // Golden Wax Council Seal with Ribbon
    final ribbonPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = primaryColor;
    final ribbon = Path()
      ..moveTo(w * 0.46, h * 0.64)
      ..lineTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.50, h * 0.74)
      ..lineTo(w * 0.58, h * 0.78)
      ..lineTo(w * 0.54, h * 0.64)
      ..close();
    canvas.drawPath(ribbon, ribbonPaint);

    final sealPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: <Color>[accentColor, primaryColor, secondaryColor],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.64), radius: w * 0.12));
    canvas.drawCircle(Offset(w * 0.5, h * 0.64), w * 0.10, sealPaint);
  }

  /// Crown: Imperial Aion-2 Celestial Archon Crown
  void _paintCelestialCrown(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Winged Radiant Crown Path
    final crownPath = Path();
    crownPath.moveTo(w * 0.12, h * 0.68); // Left base
    crownPath.cubicTo(w * 0.10, h * 0.44, w * 0.14, h * 0.28, w * 0.22, h * 0.22); // Left wing tip
    crownPath.lineTo(w * 0.34, h * 0.44); // Inner left valley
    crownPath.lineTo(w * 0.50, h * 0.12); // Majestic center spire
    crownPath.lineTo(w * 0.66, h * 0.44); // Inner right valley
    crownPath.lineTo(w * 0.78, h * 0.22); // Right wing tip
    crownPath.cubicTo(w * 0.86, h * 0.28, w * 0.90, h * 0.44, w * 0.88, h * 0.68); // Right base
    crownPath.cubicTo(w * 0.65, h * 0.78, w * 0.35, h * 0.78, w * 0.12, h * 0.68); // Bottom arch
    crownPath.close();

    final crownPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white,
          accentColor,
          primaryColor,
          secondaryColor,
        ],
        stops: const <double>[0.0, 0.25, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(crownPath, crownPaint);

    // Crown Band Filigree
    final bandPath = Path()
      ..moveTo(w * 0.16, h * 0.64)
      ..cubicTo(w * 0.38, h * 0.72, w * 0.62, h * 0.72, w * 0.84, h * 0.64);
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..color = const Color(0xFF38BDF8); // Sapphire inlay band
    canvas.drawPath(bandPath, bandPaint);

    // Sparkling Gems
    final gemPaint = Paint()..style = PaintingStyle.fill;

    // Center Majestic Sapphire Diamond
    final diamond = Path()
      ..moveTo(w * 0.50, h * 0.32)
      ..lineTo(w * 0.56, h * 0.40)
      ..lineTo(w * 0.50, h * 0.48)
      ..lineTo(w * 0.44, h * 0.40)
      ..close();
    gemPaint.color = const Color(0xFF38BDF8);
    canvas.drawPath(diamond, gemPaint);

    // Side rubies
    gemPaint.color = const Color(0xFFEF4444);
    canvas.drawCircle(Offset(w * 0.34, h * 0.50), w * 0.035, gemPaint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.50), w * 0.035, gemPaint);
  }

  /// Royal Blessing: Sunburst aura with descending divine blessing & tiara
  void _paintRoyalBlessing(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // Radiant Sunburst Rays
    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..shader = RadialGradient(
        colors: <Color>[accentColor, primaryColor.withValues(alpha: 0.1)],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.48));

    for (int i = 0; i < 12; i++) {
      final angle = (i * math.pi) / 6;
      final start = Offset(center.dx + math.cos(angle) * (w * 0.28), center.dy + math.sin(angle) * (h * 0.28));
      final end = Offset(center.dx + math.cos(angle) * (w * 0.46), center.dy + math.sin(angle) * (h * 0.46));
      canvas.drawLine(start, end, rayPaint);
    }

    // Mini Celestial Crown in center
    _paintCelestialCrown(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _KingdomCrestPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.showGlow != showGlow;
  }
}
