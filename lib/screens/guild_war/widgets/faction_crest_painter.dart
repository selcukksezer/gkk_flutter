import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Faction alliance in the Dark Fantasy realm (inspired by Elyos vs Asmodian / Light vs Dark).
enum FactionType {
  elyos,
  asmodian,
  neutral;

  String get displayName {
    switch (this) {
      case FactionType.elyos:
        return 'Elyos (Işık Hanedanı)';
      case FactionType.asmodian:
        return 'Asmodian (Gölge Lejyonu)';
      case FactionType.neutral:
        return 'Bağımsız Muhafızlar';
    }
  }

  String get shortName {
    switch (this) {
      case FactionType.elyos:
        return 'Elyos';
      case FactionType.asmodian:
        return 'Asmodian';
      case FactionType.neutral:
        return 'Muhafız';
    }
  }

  Color get primaryColor {
    switch (this) {
      case FactionType.elyos:
        return AppColors.liquidGold;
      case FactionType.asmodian:
        return AppColors.mysticRuby;
      case FactionType.neutral:
        return AppColors.mutedTitanium;
    }
  }

  Color get secondaryColor {
    switch (this) {
      case FactionType.elyos:
        return const Color(0xFF00E5FF); // Celestial cyan
      case FactionType.asmodian:
        return const Color(0xFF9D00FF); // Abyssal violet
      case FactionType.neutral:
        return const Color(0xFF607D8B); // Slate grey
    }
  }

  Color get glowColor {
    switch (this) {
      case FactionType.elyos:
        return const Color(0xFFFFD54F);
      case FactionType.asmodian:
        return const Color(0xFFFF1744);
      case FactionType.neutral:
        return const Color(0xFF90A4AE);
    }
  }
}

/// High-fidelity vector painter rendering authentic Elyos and Asmodian faction crests.
class FactionCrestPainter extends CustomPainter {
  FactionCrestPainter({
    required this.faction,
    this.animationValue = 0.0,
    this.glowOpacity = 0.6,
  });

  final FactionType faction;
  final double animationValue; // 0.0 to 1.0 (for pulsating glow & particle motion)
  final double glowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = math.min(cx, cy);

    final double pulse = 0.85 + 0.15 * math.sin(animationValue * 2 * math.pi);

    switch (faction) {
      case FactionType.elyos:
        _drawElyosCrest(canvas, size, cx, cy, radius, pulse);
        break;
      case FactionType.asmodian:
        _drawAsmodianCrest(canvas, size, cx, cy, radius, pulse);
        break;
      case FactionType.neutral:
        _drawNeutralCrest(canvas, size, cx, cy, radius, pulse);
        break;
    }
  }

  void _drawElyosCrest(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double r,
    double pulse,
  ) {
    // 1. Radiant Sunburst Background Glow
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFFFD54F).withValues(alpha: 0.45 * glowOpacity * pulse),
          const Color(0xFF00E5FF).withValues(alpha: 0.20 * glowOpacity * pulse),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.3));

    canvas.drawCircle(Offset(cx, cy), r * 1.25, glowPaint);

    // 2. Eight-pointed Sunburst Rays
    final Paint rayPaint = Paint()
      ..color = const Color(0xFFFFECB3).withValues(alpha: 0.35 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final int rays = 8;
    for (int i = 0; i < rays; i++) {
      final double angle = (i * 2 * math.pi / rays) + (animationValue * 0.1);
      final double rayLen = (i % 2 == 0) ? r * 0.95 : r * 0.75;
      final double x1 = cx + math.cos(angle) * (r * 0.4);
      final double y1 = cy + math.sin(angle) * (r * 0.4);
      final double x2 = cx + math.cos(angle) * rayLen;
      final double y2 = cy + math.sin(angle) * rayLen;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), rayPaint);
    }

    // 3. Celestial Halo Rings
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const SweepGradient(
        colors: <Color>[
          Color(0xFFFFD700),
          Color(0xFF00E5FF),
          Color(0xFFFFF9C4),
          Color(0xFFFFD700),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.8));

    canvas.drawCircle(Offset(cx, cy), r * 0.8, ringPaint);

    // 4. Elyos Angelic Wings (Left and Right)
    final Paint wingFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFFFFFF),
          Color(0xFFFFD54F),
          Color(0xFFFF8F00),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint wingOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFFFF8E1);

    // Left Wing
    final Path leftWing = Path();
    leftWing.moveTo(cx - r * 0.08, cy + r * 0.35);
    leftWing.cubicTo(
      cx - r * 0.4,
      cy + r * 0.2,
      cx - r * 0.85,
      cy - r * 0.1,
      cx - r * 0.9,
      cy - r * 0.55,
    );
    leftWing.cubicTo(
      cx - r * 0.65,
      cy - r * 0.35,
      cx - r * 0.45,
      cy - r * 0.25,
      cx - r * 0.15,
      cy - r * 0.3,
    );
    // Inner feather feathers
    leftWing.cubicTo(
      cx - r * 0.5,
      cy - r * 0.05,
      cx - r * 0.35,
      cy + r * 0.15,
      cx - r * 0.08,
      cy + r * 0.35,
    );
    leftWing.close();

    canvas.drawPath(leftWing, wingFill);
    canvas.drawPath(leftWing, wingOutline);

    // Right Wing (Mirrored)
    final Path rightWing = Path();
    rightWing.moveTo(cx + r * 0.08, cy + r * 0.35);
    rightWing.cubicTo(
      cx + r * 0.4,
      cy + r * 0.2,
      cx + r * 0.85,
      cy - r * 0.1,
      cx + r * 0.9,
      cy - r * 0.55,
    );
    rightWing.cubicTo(
      cx + r * 0.65,
      cy - r * 0.35,
      cx + r * 0.45,
      cy - r * 0.25,
      cx + r * 0.15,
      cy - r * 0.3,
    );
    rightWing.cubicTo(
      cx + r * 0.5,
      cy - r * 0.05,
      cx + r * 0.35,
      cy + r * 0.15,
      cx + r * 0.08,
      cy + r * 0.35,
    );
    rightWing.close();

    canvas.drawPath(rightWing, wingFill);
    canvas.drawPath(rightWing, wingOutline);

    // 5. Central Divine Dawn Crystal Spire
    final Path crystal = Path();
    crystal.moveTo(cx, cy - r * 0.7); // Top apex
    crystal.lineTo(cx + r * 0.16, cy - r * 0.1);
    crystal.lineTo(cx, cy + r * 0.55); // Bottom tip
    crystal.lineTo(cx - r * 0.16, cy - r * 0.1);
    crystal.close();

    final Paint crystalPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFE0F7FA),
          Color(0xFF00E5FF),
          Color(0xFFFFD54F),
        ],
      ).createShader(Rect.fromLTWH(cx - r * 0.2, cy - r * 0.7, r * 0.4, r * 1.3));

    canvas.drawPath(crystal, crystalPaint);

    final Paint crystalBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFFFFFFF);
    canvas.drawPath(crystal, crystalBorder);

    // Center Core Gem
    canvas.drawCircle(
      Offset(cx, cy - r * 0.1),
      r * 0.09 * pulse,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }

  void _drawAsmodianCrest(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double r,
    double pulse,
  ) {
    // 1. Dark Abyssal Void Glow
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFFF1744).withValues(alpha: 0.45 * glowOpacity * pulse),
          const Color(0xFF7C4DFF).withValues(alpha: 0.25 * glowOpacity * pulse),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.3));

    canvas.drawCircle(Offset(cx, cy), r * 1.25, glowPaint);

    // 2. Abyssal Rune Ring
    final Paint runeRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = const SweepGradient(
        colors: <Color>[
          Color(0xFFFF1744),
          Color(0xFF7C4DFF),
          Color(0xFF311B92),
          Color(0xFFFF1744),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.8));

    canvas.drawCircle(Offset(cx, cy), r * 0.8, runeRingPaint);

    // 3. Asmodian Dread Horns (Curving outward and upward)
    final Paint hornPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFF5252),
          Color(0xFFB71C1C),
          Color(0xFF212121),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint hornOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFFFF8A80);

    // Left Horn
    final Path leftHorn = Path();
    leftHorn.moveTo(cx - r * 0.12, cy - r * 0.1);
    leftHorn.cubicTo(
      cx - r * 0.35,
      cy - r * 0.4,
      cx - r * 0.7,
      cy - r * 0.75,
      cx - r * 0.88,
      cy - r * 0.8,
    );
    leftHorn.cubicTo(
      cx - r * 0.65,
      cy - r * 0.55,
      cx - r * 0.4,
      cy - r * 0.2,
      cx - r * 0.1,
      cy + r * 0.05,
    );
    leftHorn.close();

    canvas.drawPath(leftHorn, hornPaint);
    canvas.drawPath(leftHorn, hornOutline);

    // Right Horn (Mirrored)
    final Path rightHorn = Path();
    rightHorn.moveTo(cx + r * 0.12, cy - r * 0.1);
    rightHorn.cubicTo(
      cx + r * 0.35,
      cy - r * 0.4,
      cx + r * 0.7,
      cy - r * 0.75,
      cx + r * 0.88,
      cy - r * 0.8,
    );
    rightHorn.cubicTo(
      cx + r * 0.65,
      cy - r * 0.55,
      cx + r * 0.4,
      cy - r * 0.2,
      cx + r * 0.1,
      cy + r * 0.05,
    );
    rightHorn.close();

    canvas.drawPath(rightHorn, hornPaint);
    canvas.drawPath(rightHorn, hornOutline);

    // 4. Shadow Talon Wings (Bottom-swept)
    final Path leftWing = Path();
    leftWing.moveTo(cx - r * 0.05, cy + r * 0.15);
    leftWing.cubicTo(
      cx - r * 0.5,
      cy + r * 0.1,
      cx - r * 0.85,
      cy + r * 0.45,
      cx - r * 0.75,
      cy + r * 0.75,
    );
    leftWing.cubicTo(
      cx - r * 0.55,
      cy + r * 0.5,
      cx - r * 0.35,
      cy + r * 0.4,
      cx - r * 0.05,
      cy + r * 0.25,
    );
    leftWing.close();

    final Path rightWing = Path();
    rightWing.moveTo(cx + r * 0.05, cy + r * 0.15);
    rightWing.cubicTo(
      cx + r * 0.5,
      cy + r * 0.1,
      cx + r * 0.85,
      cy + r * 0.45,
      cx + r * 0.75,
      cy + r * 0.75,
    );
    rightWing.cubicTo(
      cx + r * 0.55,
      cy + r * 0.5,
      cx + r * 0.35,
      cy + r * 0.4,
      cx + r * 0.05,
      cy + r * 0.25,
    );
    rightWing.close();

    final Paint talonPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF7C4DFF),
          Color(0xFF311B92),
          Color(0xFF000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(leftWing, talonPaint);
    canvas.drawPath(leftWing, hornOutline);
    canvas.drawPath(rightWing, talonPaint);
    canvas.drawPath(rightWing, hornOutline);

    // 5. Central Eclipsed Dark Core & Dragon Eye
    final Path darkCore = Path();
    darkCore.moveTo(cx, cy - r * 0.3);
    darkCore.lineTo(cx + r * 0.22, cy);
    darkCore.lineTo(cx, cy + r * 0.35);
    darkCore.lineTo(cx - r * 0.22, cy);
    darkCore.close();

    final Paint corePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const RadialGradient(
        colors: <Color>[
          Color(0xFFFF1744),
          Color(0xFF880E4F),
          Color(0xFF1A000A),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.25));

    canvas.drawPath(darkCore, corePaint);

    final Paint coreBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFFF5252);
    canvas.drawPath(darkCore, coreBorder);

    // Slit pupil / glowing ember
    final Paint pupilPaint = Paint()..color = const Color(0xFFFFEA00);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 0.07 * pulse, height: r * 0.22),
      pupilPaint,
    );
  }

  void _drawNeutralCrest(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double r,
    double pulse,
  ) {
    final Paint shieldPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF37474F);

    final Path shield = Path();
    shield.moveTo(cx, cy - r * 0.6);
    shield.lineTo(cx + r * 0.5, cy - r * 0.3);
    shield.lineTo(cx + r * 0.4, cy + r * 0.4);
    shield.lineTo(cx, cy + r * 0.7);
    shield.lineTo(cx - r * 0.4, cy + r * 0.4);
    shield.lineTo(cx - r * 0.5, cy - r * 0.3);
    shield.close();

    canvas.drawPath(shield, shieldPaint);

    final Paint shieldBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF90A4AE);
    canvas.drawPath(shield, shieldBorder);

    final Paint swordPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFCFD8DC);
    canvas.drawLine(Offset(cx, cy - r * 0.5), Offset(cx, cy + r * 0.5), swordPaint);
    canvas.drawLine(Offset(cx - r * 0.2, cy - r * 0.2), Offset(cx + r * 0.2, cy - r * 0.2), swordPaint);
  }

  @override
  bool shouldRepaint(covariant FactionCrestPainter oldDelegate) {
    return oldDelegate.faction != faction ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.glowOpacity != glowOpacity;
  }
}

/// Animated Crest Widget providing breathing glow and subtle scaling.
class FactionCrestWidget extends StatefulWidget {
  const FactionCrestWidget({
    super.key,
    required this.faction,
    this.size = 54.0,
    this.showGlow = true,
  });

  final FactionType faction;
  final double size;
  final bool showGlow;

  @override
  State<FactionCrestWidget> createState() => _FactionCrestWidgetState();
}

class _FactionCrestWidgetState extends State<FactionCrestWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: FactionCrestPainter(
            faction: widget.faction,
            animationValue: _controller.value,
            glowOpacity: widget.showGlow ? 0.75 : 0.0,
          ),
        );
      },
    );
  }
}

/// Heraldic symbol types for custom guild crests.
enum GuildCrestSymbol {
  dragon,
  lion,
  raven,
  blade,
  crown,
  hydra,
  wolf,
  sun;

  static GuildCrestSymbol fromString(String? val) {
    if (val == null) return GuildCrestSymbol.dragon;
    for (final s in GuildCrestSymbol.values) {
      if (s.name.toLowerCase() == val.toLowerCase()) return s;
    }
    return GuildCrestSymbol.dragon;
  }
}

/// Ornamental filigree border frame for guild crest banners.
enum GuildHeraldicFrame {
  goldFiligree,
  obsidianRune,
  celestialSilver,
  bloodIron;

  Color get frameColor {
    switch (this) {
      case GuildHeraldicFrame.goldFiligree:
        return AppColors.liquidGold;
      case GuildHeraldicFrame.obsidianRune:
        return const Color(0xFF9D00FF);
      case GuildHeraldicFrame.celestialSilver:
        return const Color(0xFF00E5FF);
      case GuildHeraldicFrame.bloodIron:
        return AppColors.mysticRuby;
    }
  }
}

/// High-detail procedural painter for customizable guild crest heraldry.
class GuildCustomCrestPainter extends CustomPainter {
  GuildCustomCrestPainter({
    required this.symbol,
    required this.primaryColor,
    required this.secondaryColor,
    this.frame = GuildHeraldicFrame.goldFiligree,
    this.faction = FactionType.neutral,
    this.pulse = 1.0,
  });

  final GuildCrestSymbol symbol;
  final Color primaryColor;
  final Color secondaryColor;
  final GuildHeraldicFrame frame;
  final FactionType faction;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = math.min(cx, cy);

    // 1. Escutcheon Shield Silhouette
    final Path shield = Path();
    shield.moveTo(cx - r * 0.75, cy - r * 0.85);
    shield.lineTo(cx + r * 0.75, cy - r * 0.85);
    shield.cubicTo(
      cx + r * 0.75,
      cy + r * 0.20,
      cx + r * 0.45,
      cy + r * 0.75,
      cx,
      cy + r * 0.95,
    );
    shield.cubicTo(
      cx - r * 0.45,
      cy + r * 0.75,
      cx - r * 0.75,
      cy + r * 0.20,
      cx - r * 0.75,
      cy - r * 0.85,
    );
    shield.close();

    // Shield Field Fill Gradient
    final Paint fieldPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[primaryColor, secondaryColor, const Color(0xFF0C0E14)],
        stops: const <double>[0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(shield, fieldPaint);

    // Subtle Quartering Cross or Chevron
    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx, cy - r * 0.85), Offset(cx, cy + r * 0.95), linePaint);
    canvas.drawLine(Offset(cx - r * 0.70, cy), Offset(cx + r * 0.70, cy), linePaint);

    // 2. Filigree Frame Border
    final Paint frameBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          frame.frameColor,
          frame.frameColor.withValues(alpha: 0.5),
          const Color(0xFF14141E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(shield, frameBorder);

    // Inner filigree rim
    final Paint innerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawPath(shield, innerBorder);

    // 3. Central Heraldic Charge Symbol
    _drawSymbolCharge(canvas, cx, cy, r * 0.45);

    // 4. Corner rivets
    final Paint rivetPaint = Paint()..color = frame.frameColor;
    canvas.drawCircle(Offset(cx - r * 0.65, cy - r * 0.75), 1.8, rivetPaint);
    canvas.drawCircle(Offset(cx + r * 0.65, cy - r * 0.75), 1.8, rivetPaint);
  }

  void _drawSymbolCharge(Canvas canvas, double cx, double cy, double cr) {
    final Paint chargePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = frame.frameColor;

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = frame.frameColor.withValues(alpha: 0.85);

    switch (symbol) {
      case GuildCrestSymbol.dragon:
        // Dragon head silhouette
        final Path dragon = Path();
        dragon.moveTo(cx - cr * 0.6, cy + cr * 0.4);
        dragon.lineTo(cx - cr * 0.2, cy - cr * 0.5);
        dragon.lineTo(cx + cr * 0.4, cy - cr * 0.6); // horn
        dragon.lineTo(cx + cr * 0.1, cy - cr * 0.2);
        dragon.lineTo(cx + cr * 0.7, cy + cr * 0.1); // snout
        dragon.lineTo(cx + cr * 0.2, cy + cr * 0.2); // jaw
        dragon.lineTo(cx + cr * 0.5, cy + cr * 0.6);
        dragon.lineTo(cx, cy + cr * 0.5);
        dragon.close();
        canvas.drawPath(dragon, fillPaint);
        canvas.drawPath(dragon, chargePaint);
        break;

      case GuildCrestSymbol.blade:
        // Crossed broadswords
        canvas.drawLine(Offset(cx - cr, cy - cr), Offset(cx + cr, cy + cr), chargePaint);
        canvas.drawLine(Offset(cx + cr, cy - cr), Offset(cx - cr, cy + cr), chargePaint);
        // Crossguards
        canvas.drawLine(Offset(cx - cr * 0.5, cy - cr * 0.1), Offset(cx - cr * 0.1, cy - cr * 0.5), chargePaint);
        canvas.drawLine(Offset(cx + cr * 0.5, cy - cr * 0.1), Offset(cx + cr * 0.1, cy - cr * 0.5), chargePaint);
        break;

      case GuildCrestSymbol.crown:
        // Royal coronet with 3 peaks
        final Path crown = Path();
        crown.moveTo(cx - cr * 0.8, cy + cr * 0.3);
        crown.lineTo(cx - cr * 0.8, cy - cr * 0.2);
        crown.lineTo(cx - cr * 0.4, cy + cr * 0.05);
        crown.lineTo(cx, cy - cr * 0.5);
        crown.lineTo(cx + cr * 0.4, cy + cr * 0.05);
        crown.lineTo(cx + cr * 0.8, cy - cr * 0.2);
        crown.lineTo(cx + cr * 0.8, cy + cr * 0.3);
        crown.close();
        canvas.drawPath(crown, fillPaint);
        canvas.drawPath(crown, chargePaint);
        break;

      default:
        // Heraldic Lion / Beast Rampant silhouette
        final Path beast = Path();
        beast.moveTo(cx - cr * 0.3, cy + cr * 0.6);
        beast.lineTo(cx, cy - cr * 0.4);
        beast.lineTo(cx + cr * 0.4, cy - cr * 0.2);
        beast.lineTo(cx + cr * 0.2, cy + cr * 0.5);
        beast.close();
        canvas.drawPath(beast, fillPaint);
        canvas.drawCircle(Offset(cx, cy), cr * 0.6, chargePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant GuildCustomCrestPainter oldDelegate) {
    return oldDelegate.symbol != symbol ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.frame != frame ||
        oldDelegate.faction != faction ||
        oldDelegate.pulse != pulse;
  }
}

/// Custom Guild War Crest Widget for displaying personalized guild heraldry.
class GuildCustomCrestWidget extends StatelessWidget {
  const GuildCustomCrestWidget({
    super.key,
    required this.symbol,
    required this.primaryColor,
    required this.secondaryColor,
    this.frame = GuildHeraldicFrame.goldFiligree,
    this.faction = FactionType.neutral,
    this.size = 48.0,
  });

  final GuildCrestSymbol symbol;
  final Color primaryColor;
  final Color secondaryColor;
  final GuildHeraldicFrame frame;
  final FactionType faction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: GuildCustomCrestPainter(
        symbol: symbol,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        frame: frame,
        faction: faction,
      ),
    );
  }
}

