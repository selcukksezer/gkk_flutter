import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'faction_crest_painter.dart';
import 'guild_war_design.dart';

/// Style archetype for dark fantasy fortress siege illustrations.
enum FortressTheme {
  abyssalCitadel,
  celestialSanctuary,
  dragonShrine,
  obsidianBastion,
  sunkenGate;

  static FortressTheme fromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('uçurum') || lower.contains('abyss') || lower.contains('karanlık')) {
      return FortressTheme.abyssalCitadel;
    }
    if (lower.contains('mabet') || lower.contains('sanctuary') || lower.contains('ışık') || lower.contains('merkez')) {
      return FortressTheme.celestialSanctuary;
    }
    if (lower.contains('ejder') || lower.contains('dragon') || lower.contains('ateş') || lower.contains('lav')) {
      return FortressTheme.dragonShrine;
    }
    if (lower.contains('batık') || lower.contains('geçit') || lower.contains('su') || lower.contains('liman')) {
      return FortressTheme.sunkenGate;
    }
    return FortressTheme.obsidianBastion;
  }

  Color get skyTop {
    switch (this) {
      case FortressTheme.abyssalCitadel:
        return const Color(0xFF0D081E);
      case FortressTheme.celestialSanctuary:
        return const Color(0xFF0F1E36);
      case FortressTheme.dragonShrine:
        return const Color(0xFF240A07);
      case FortressTheme.sunkenGate:
        return const Color(0xFF081C1D);
      case FortressTheme.obsidianBastion:
        return const Color(0xFF14101A);
    }
  }

  Color get skyBottom {
    switch (this) {
      case FortressTheme.abyssalCitadel:
        return const Color(0xFF2E123D);
      case FortressTheme.celestialSanctuary:
        return const Color(0xFF1B3D5E);
      case FortressTheme.dragonShrine:
        return const Color(0xFF4A180E);
      case FortressTheme.sunkenGate:
        return const Color(0xFF103A3C);
      case FortressTheme.obsidianBastion:
        return const Color(0xFF2D2336);
    }
  }

  Color get stoneColorPrimary {
    switch (this) {
      case FortressTheme.abyssalCitadel:
        return const Color(0xFF1B1B2A);
      case FortressTheme.celestialSanctuary:
        return const Color(0xFF2A3644);
      case FortressTheme.dragonShrine:
        return const Color(0xFF2A1C1C);
      case FortressTheme.sunkenGate:
        return const Color(0xFF1C2A28);
      case FortressTheme.obsidianBastion:
        return const Color(0xFF1E1E24);
    }
  }

  Color get stoneColorHighlight {
    switch (this) {
      case FortressTheme.abyssalCitadel:
        return const Color(0xFF453966);
      case FortressTheme.celestialSanctuary:
        return const Color(0xFF6B8BA4);
      case FortressTheme.dragonShrine:
        return const Color(0xFF5E3430);
      case FortressTheme.sunkenGate:
        return const Color(0xFF385E5A);
      case FortressTheme.obsidianBastion:
        return const Color(0xFF484856);
    }
  }

  Color get energyGlow {
    switch (this) {
      case FortressTheme.abyssalCitadel:
        return const Color(0xFFB347FF);
      case FortressTheme.celestialSanctuary:
        return const Color(0xFF00E5FF);
      case FortressTheme.dragonShrine:
        return const Color(0xFFFF5722);
      case FortressTheme.sunkenGate:
        return const Color(0xFF00BFA5);
      case FortressTheme.obsidianBastion:
        return const Color(0xFFFF9100);
    }
  }
}

/// Dynamic ember / dust particle model for cinematic fortress atmosphere.
class FortressAtmosphereParticle {
  FortressAtmosphereParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.drift,
  });

  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double drift;
}

/// High-detail procedural vector painter rendering an authentic Aion-2 style fortress siege.
class FortressPainter extends CustomPainter {
  FortressPainter({
    required this.theme,
    required this.faction,
    required this.shieldIntegrity,
    required this.isUnderSiege,
    required this.animProgress,
    required this.particles,
  });

  final FortressTheme theme;
  final FactionType faction;
  final double shieldIntegrity; // 0.0 to 1.0
  final bool isUnderSiege;
  final double animProgress; // 0.0 to 1.0
  final List<FortressAtmosphereParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Sky & Atmospheric Gradient
    _drawSkyAndHorizon(canvas, size, w, h);

    // 2. Distant Abyssal Jagged Mountain Ridges
    _drawDistantMountains(canvas, size, w, h);

    // 3. Middleground Ramparts & Terrain Plateaus
    _drawTerrainAndFooting(canvas, size, w, h);

    // 4. Colossal Central Fortress & Flanking Bastions
    _drawFortressStructure(canvas, size, w, h);

    // 5. Architectural Embellishments: Crenellations, Arched Portcullis & Windows
    _drawArchitecturalDetails(canvas, size, w, h);

    // 6. Siege Fire Braziers & Flaming Torches
    _drawSiegeBraziers(canvas, size, w, h);

    // 7. Faction Crest & Battle Standard Atop Central Tower
    _drawTopBanner(canvas, size, w, h);

    // 8. Runic Energy Defensive Shield Barrier
    if (shieldIntegrity > 0.05) {
      _drawRunicDefenseShield(canvas, size, w, h);
    }

    // 9. Floating Embers, Sparks & Atmospheric Shimmer Particles
    _drawAtmosphereParticles(canvas, size, w, h);

    // 10. Vignette & Edge Glaze
    _drawCinematicVignette(canvas, size, w, h);
  }

  void _drawSkyAndHorizon(Canvas canvas, Size size, double w, double h) {
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          theme.skyTop,
          Color.lerp(theme.skyTop, theme.skyBottom, 0.5)!,
          theme.skyBottom,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // Celestial rift / nebula glow
    final double riftX = w * 0.65;
    final double riftY = h * 0.22;
    final Paint nebulaPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, -0.5),
        radius: 0.6,
        colors: <Color>[
          theme.energyGlow.withValues(alpha: 0.28),
          theme.energyGlow.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), nebulaPaint);

    // Subtle sunburst / abyssal rays radiating from horizon
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24.0
      ..color = theme.energyGlow.withValues(alpha: 0.04);

    for (int i = -3; i <= 3; i++) {
      final double angle = math.pi * 0.5 + (i * 0.15) + (math.sin(animProgress * math.pi * 2) * 0.02);
      final double endX = riftX + math.cos(angle) * w * 0.8;
      final double endY = riftY - math.sin(angle) * h * 0.8;
      canvas.drawLine(Offset(riftX, riftY), Offset(endX, endY), rayPaint);
    }
  }

  void _drawDistantMountains(Canvas canvas, Size size, double w, double h) {
    final Paint farMountainPaint = Paint()
      ..color = Color.lerp(theme.skyBottom, Colors.black, 0.55)!
      ..style = PaintingStyle.fill;

    final Path farPath = Path();
    farPath.moveTo(0, h * 0.55);
    farPath.lineTo(w * 0.12, h * 0.42);
    farPath.lineTo(w * 0.28, h * 0.52);
    farPath.lineTo(w * 0.42, h * 0.38);
    farPath.lineTo(w * 0.58, h * 0.48);
    farPath.lineTo(w * 0.76, h * 0.36);
    farPath.lineTo(w * 0.88, h * 0.46);
    farPath.lineTo(w, h * 0.40);
    farPath.lineTo(w, h);
    farPath.lineTo(0, h);
    farPath.close();
    canvas.drawPath(farPath, farMountainPaint);

    // Near mountain layer with sharper ridges
    final Paint nearMountainPaint = Paint()
      ..color = Color.lerp(theme.skyBottom, Colors.black, 0.75)!
      ..style = PaintingStyle.fill;

    final Path nearPath = Path();
    nearPath.moveTo(0, h * 0.62);
    nearPath.lineTo(w * 0.18, h * 0.50);
    nearPath.lineTo(w * 0.34, h * 0.60);
    nearPath.lineTo(w * 0.52, h * 0.48);
    nearPath.lineTo(w * 0.68, h * 0.56);
    nearPath.lineTo(w * 0.84, h * 0.46);
    nearPath.lineTo(w, h * 0.58);
    nearPath.lineTo(w, h);
    nearPath.lineTo(0, h);
    nearPath.close();
    canvas.drawPath(nearPath, nearMountainPaint);
  }

  void _drawTerrainAndFooting(Canvas canvas, Size size, double w, double h) {
    final Paint groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF141720),
          const Color(0xFF090B0E),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.70, w, h * 0.30));

    final Path groundPath = Path();
    groundPath.moveTo(0, h * 0.74);
    groundPath.cubicTo(w * 0.25, h * 0.72, w * 0.50, h * 0.76, w * 0.75, h * 0.71);
    groundPath.lineTo(w, h * 0.75);
    groundPath.lineTo(w, h);
    groundPath.lineTo(0, h);
    groundPath.close();
    canvas.drawPath(groundPath, groundPaint);

    // Fortress stone terrace foundation
    final Paint baseTerracePaint = Paint()
      ..color = const Color(0xFF181B26)
      ..style = PaintingStyle.fill;
    final Rect terraceRect = Rect.fromLTRB(w * 0.08, h * 0.70, w * 0.92, h * 0.88);
    canvas.drawRRect(RRect.fromRectAndRadius(terraceRect, const Radius.circular(8)), baseTerracePaint);

    // Edge bevel on terrace
    final Paint terraceBevel = Paint()
      ..color = theme.stoneColorHighlight.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(w * 0.08, h * 0.70), Offset(w * 0.92, h * 0.70), terraceBevel);
  }

  void _drawFortressStructure(Canvas canvas, Size size, double w, double h) {
    final double cx = w * 0.50;

    // Outer curtain wall connecting bastions
    final Paint wallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          theme.stoneColorHighlight,
          theme.stoneColorPrimary,
          const Color(0xFF0C0E14),
        ],
      ).createShader(Rect.fromLTWH(w * 0.15, h * 0.44, w * 0.70, h * 0.35));

    final Rect wallRect = Rect.fromLTRB(w * 0.16, h * 0.48, w * 0.84, h * 0.74);
    canvas.drawRect(wallRect, wallPaint);

    // Left Bastion Tower
    _drawTower(
      canvas: canvas,
      left: w * 0.12,
      top: h * 0.34,
      width: w * 0.18,
      height: h * 0.40,
      roofStyle: 'spire',
    );

    // Right Bastion Tower
    _drawTower(
      canvas: canvas,
      left: w * 0.70,
      top: h * 0.34,
      width: w * 0.18,
      height: h * 0.40,
      roofStyle: 'spire',
    );

    // Central Citadel Keep (Grand Tower)
    _drawTower(
      canvas: canvas,
      left: cx - (w * 0.20),
      top: h * 0.20,
      width: w * 0.40,
      height: h * 0.54,
      roofStyle: 'crenellated',
      isKeep: true,
    );
  }

  void _drawTower({
    required Canvas canvas,
    required double left,
    required double top,
    required double width,
    required double height,
    required String roofStyle,
    bool isKeep = false,
  }) {
    final double right = left + width;
    final double bottom = top + height;

    // Tower Body Gradient (lit from upper right)
    final Paint towerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          theme.stoneColorPrimary,
          theme.stoneColorHighlight,
          theme.stoneColorPrimary,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTRB(left, top, right, bottom));

    // Tower Silhouette Path (slightly tapered towards top)
    final double taper = width * 0.08;
    final Path towerPath = Path();
    towerPath.moveTo(left + taper, top);
    towerPath.lineTo(right - taper, top);
    towerPath.lineTo(right, bottom);
    towerPath.lineTo(left, bottom);
    towerPath.close();
    canvas.drawPath(towerPath, towerPaint);

    // Tower Stone Bevel Lines
    final Paint bevelPaint = Paint()
      ..color = theme.stoneColorHighlight.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(left + taper, top), Offset(left, bottom), bevelPaint);
    canvas.drawLine(Offset(right - taper, top), Offset(right, bottom), bevelPaint);

    // Tower Parapet / Machicolations
    final double parapetTop = top - (height * 0.07);
    final Rect parapetRect = Rect.fromLTRB(left + (taper * 0.3), parapetTop, right - (taper * 0.3), top);
    canvas.drawRect(parapetRect, Paint()..color = theme.stoneColorHighlight);

    // Crenellations along top of parapet
    final int notches = isKeep ? 5 : 3;
    final double notchWidth = (parapetRect.width / (notches * 2));
    final Paint crenelPaint = Paint()..color = theme.stoneColorPrimary;
    for (int i = 0; i < notches; i++) {
      final double cLeft = parapetRect.left + (i * 2 * notchWidth);
      final Rect crenel = Rect.fromLTWH(cLeft, parapetTop - 6, notchWidth, 6);
      canvas.drawRect(crenel, crenelPaint);
    }

    if (roofStyle == 'spire') {
      // Steep gothic spire
      final Path spirePath = Path();
      spirePath.moveTo(left + (width * 0.5), parapetTop - (height * 0.22));
      spirePath.lineTo(right - (taper * 0.5), parapetTop);
      spirePath.lineTo(left + (taper * 0.5), parapetTop);
      spirePath.close();

      final Paint spirePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            theme.energyGlow.withValues(alpha: 0.8),
            theme.stoneColorPrimary,
          ],
        ).createShader(Rect.fromLTRB(left, parapetTop - (height * 0.22), right, parapetTop));
      canvas.drawPath(spirePath, spirePaint);
    }
  }

  void _drawArchitecturalDetails(Canvas canvas, Size size, double w, double h) {
    final double cx = w * 0.50;

    // Arched Gate Portal in Central Keep
    final double gateWidth = w * 0.14;
    final double gateHeight = h * 0.15;
    final double gateLeft = cx - (gateWidth * 0.5);
    final double gateBottom = h * 0.74;
    final double gateTop = gateBottom - gateHeight;

    final Path archPath = Path();
    archPath.moveTo(gateLeft, gateBottom);
    archPath.lineTo(gateLeft, gateTop + (gateHeight * 0.4));
    archPath.quadraticBezierTo(
      cx,
      gateTop,
      gateLeft + gateWidth,
      gateTop + (gateHeight * 0.4),
    );
    archPath.lineTo(gateLeft + gateWidth, gateBottom);
    archPath.close();

    // Dark interior portal
    canvas.drawPath(archPath, Paint()..color = const Color(0xFF05060A));

    // Glowing gate energy barrier or portcullis
    final Paint portcullis = Paint()
      ..color = theme.energyGlow.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Vertical bars
    for (int i = 1; i <= 4; i++) {
      final double bx = gateLeft + (gateWidth * (i / 5));
      canvas.drawLine(Offset(bx, gateTop + 8), Offset(bx, gateBottom), portcullis);
    }
    // Horizontal cross-bars
    for (int i = 1; i <= 3; i++) {
      final double by = gateTop + (gateHeight * (i / 4));
      canvas.drawLine(Offset(gateLeft + 2, by), Offset(gateLeft + gateWidth - 2, by), portcullis);
    }

    // Glowing Runic Windows on Keep
    final Paint windowGlow = Paint()
      ..color = theme.energyGlow.withValues(alpha: 0.75 + 0.20 * math.sin(animProgress * math.pi * 2))
      ..style = PaintingStyle.fill;

    // Upper grand lancet window
    final Rect grandWindow = Rect.fromLTWH(cx - 8, h * 0.27, 16, 28);
    canvas.drawRRect(RRect.fromRectAndRadius(grandWindow, const Radius.circular(8)), windowGlow);

    // Flanking lancet windows
    final Rect leftWindow = Rect.fromLTWH(cx - (w * 0.12), h * 0.35, 8, 16);
    final Rect rightWindow = Rect.fromLTWH(cx + (w * 0.12) - 8, h * 0.35, 8, 16);
    canvas.drawRRect(RRect.fromRectAndRadius(leftWindow, const Radius.circular(4)), windowGlow);
    canvas.drawRRect(RRect.fromRectAndRadius(rightWindow, const Radius.circular(4)), windowGlow);
  }

  void _drawSiegeBraziers(Canvas canvas, Size size, double w, double h) {
    final List<Offset> brazierPositions = <Offset>[
      Offset(w * 0.19, h * 0.32),
      Offset(w * 0.77, h * 0.32),
      Offset(w * 0.34, h * 0.18),
      Offset(w * 0.66, h * 0.18),
    ];

    final double flamePulse = math.sin(animProgress * math.pi * 4).abs();

    for (final Offset pos in brazierPositions) {
      // Iron bowl
      final Rect bowl = Rect.fromLTWH(pos.dx - 6, pos.dy, 12, 5);
      canvas.drawRect(bowl, Paint()..color = const Color(0xFF1E1E24));

      // Flame glow gradient
      final Color flameColor = isUnderSiege ? const Color(0xFFFF3D00) : theme.energyGlow;
      final Paint flamePaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFF176),
            flameColor,
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(pos.dx, pos.dy - 6), radius: 12 + 4 * flamePulse));

      canvas.drawCircle(Offset(pos.dx, pos.dy - 6), 10 + 4 * flamePulse, flamePaint);
    }
  }

  void _drawTopBanner(Canvas canvas, Size size, double w, double h) {
    final double cx = w * 0.50;
    final double flagPoleTop = h * 0.11;
    final double flagPoleBottom = h * 0.19;

    // Pole
    final Paint polePaint = Paint()
      ..color = AppColors.liquidGold
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(cx, flagPoleTop), Offset(cx, flagPoleBottom), polePaint);

    // Banner cloth waving
    final double wave = math.sin(animProgress * math.pi * 2) * 5;
    final Path flagPath = Path();
    flagPath.moveTo(cx, flagPoleTop);
    flagPath.lineTo(cx + 28 + wave, flagPoleTop + 6);
    flagPath.lineTo(cx + 22 + (wave * 0.5), flagPoleTop + 16);
    flagPath.lineTo(cx, flagPoleTop + 20);
    flagPath.close();

    final Color bannerColor = faction == FactionType.elyos
        ? AppColors.liquidGold
        : faction == FactionType.asmodian
            ? AppColors.mysticRuby
            : AppColors.mutedTitanium;

    final Paint flagPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[bannerColor, bannerColor.withValues(alpha: 0.6)],
      ).createShader(flagPath.getBounds());
    canvas.drawPath(flagPath, flagPaint);
  }

  void _drawRunicDefenseShield(Canvas canvas, Size size, double w, double h) {
    final double cx = w * 0.50;
    final double cy = h * 0.50;
    final double rx = w * 0.46;
    final double ry = h * 0.42;

    final double pulse = 0.85 + 0.15 * math.sin(animProgress * math.pi * 2);
    final double alpha = (shieldIntegrity * pulse).clamp(0.0, 1.0);

    final Rect shieldRect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

    // Shield Dome Outer Glow
    final Paint shieldGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..shader = RadialGradient(
        colors: <Color>[
          theme.energyGlow.withValues(alpha: 0.7 * alpha),
          theme.energyGlow.withValues(alpha: 0.15 * alpha),
        ],
      ).createShader(shieldRect);
    canvas.drawOval(shieldRect, shieldGlow);

    // Shield Runic Grid / Hexagonal Lattice
    final Paint gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = theme.energyGlow.withValues(alpha: 0.35 * alpha);

    final double step = w * 0.10;
    for (double x = cx - rx + step; x < cx + rx; x += step) {
      final double normalized = ((x - cx) / rx).clamp(-1.0, 1.0);
      final double halfH = ry * math.sqrt((1 - normalized * normalized).clamp(0.0, 1.0));
      canvas.drawLine(Offset(x, cy - halfH), Offset(x, cy + halfH), gridPaint);
    }
  }

  void _drawAtmosphereParticles(Canvas canvas, Size size, double w, double h) {
    final Paint emberPaint = Paint()..style = PaintingStyle.fill;

    for (final FortressAtmosphereParticle p in particles) {
      final double px = (p.x * w) % w;
      final double py = (p.y * h) % h;

      final Color pColor = isUnderSiege
          ? (p.size > 2.0 ? const Color(0xFFFF5722) : const Color(0xFFFFD54F))
          : theme.energyGlow;

      emberPaint.color = pColor.withValues(alpha: p.opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), p.size, emberPaint);
    }
  }

  void _drawCinematicVignette(Canvas canvas, Size size, double w, double h) {
    final Paint vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: <Color>[
          Colors.transparent,
          Colors.black.withValues(alpha: 0.3),
          Colors.black.withValues(alpha: 0.85),
        ],
        stops: const <double>[0.6, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant FortressPainter oldDelegate) {
    return oldDelegate.animProgress != animProgress ||
        oldDelegate.shieldIntegrity != shieldIntegrity ||
        oldDelegate.isUnderSiege != isUnderSiege ||
        oldDelegate.theme != theme ||
        oldDelegate.faction != faction;
  }
}

/// AAA Mobile War Room Fortress Siege Illustration Widget with interactive state and animated FX.
class FortressSiegeIllustration extends StatefulWidget {
  const FortressSiegeIllustration({
    super.key,
    required this.fortressName,
    this.faction = FactionType.neutral,
    this.shieldIntegrity = 1.0,
    this.isUnderSiege = false,
    this.height = 230.0,
    this.showTitle = true,
    this.subtitle,
    this.onTap,
    this.garrisonCount,
    this.defensePower,
    this.maxDefensePower,
  });

  final String fortressName;
  final FactionType faction;
  final double shieldIntegrity;
  final bool isUnderSiege;
  final double height;
  final bool showTitle;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? garrisonCount;
  final int? defensePower;
  final int? maxDefensePower;

  @override
  State<FortressSiegeIllustration> createState() => _FortressSiegeIllustrationState();
}

class _FortressSiegeIllustrationState extends State<FortressSiegeIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  final List<FortressAtmosphereParticle> _particles = <FortressAtmosphereParticle>[];
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // Initialize 24 ambient floating particles
    for (int i = 0; i < 24; i++) {
      _particles.add(
        FortressAtmosphereParticle(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          size: 1.0 + _rng.nextDouble() * 2.2,
          speed: 0.001 + _rng.nextDouble() * 0.002,
          opacity: 0.3 + _rng.nextDouble() * 0.7,
          drift: (_rng.nextDouble() - 0.5) * 0.001,
        ),
      );
    }

    _anim.addListener(_updateParticles);
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.y -= p.speed;
      p.x += p.drift;
      if (p.y < 0) {
        p.y = 1.0;
        p.x = _rng.nextDouble();
      }
    }
  }

  @override
  void dispose() {
    _anim.removeListener(_updateParticles);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FortressTheme theme = FortressTheme.fromName(widget.fortressName);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: widget.isUnderSiege
                ? const Color(0xFFFF3D00).withValues(alpha: 0.8)
                : theme.energyGlow.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            if (widget.isUnderSiege)
              BoxShadow(
                color: const Color(0xFFFF3D00).withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 2,
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: <Widget>[
            // Procedural Canvas Painter
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (BuildContext context, Widget? child) {
                  return CustomPaint(
                    painter: FortressPainter(
                      theme: theme,
                      faction: widget.faction,
                      shieldIntegrity: widget.shieldIntegrity,
                      isUnderSiege: widget.isUnderSiege,
                      animProgress: _anim.value,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),

            // Top Badges & Faction Alignment
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Faction Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.faction.primaryColor.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FactionCrestWidget(
                          faction: widget.faction,
                          size: 16,
                          showGlow: false,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.faction.displayName,
                          style: TextStyle(
                            color: widget.faction.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Siege State Indicator Pill
                  if (widget.isUnderSiege)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFFFF1744), Color(0xFFFF5252)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Color(0xFFFF1744), blurRadius: 8),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'KUŞATMA ALTINDA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.shield_outlined,
                            color: theme.energyGlow,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Kalkan: %${(widget.shieldIntegrity * 100).toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Hero Title & Fortress Stats Overlay
            if (widget.showTitle)
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C101A).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: AppColors.liquidGold.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              widget.fortressName,
                              style: const TextStyle(
                                fontFamily: 'Cinzel',
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: const TextStyle(
                                  color: WarPalette.titanium,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (widget.garrisonCount != null || widget.defensePower != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (widget.garrisonCount != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    const Text('Garnizon', style: TextStyle(color: WarPalette.titanium, fontSize: 8)),
                                    Text(
                                      '${widget.garrisonCount} Savaşçı',
                                      style: const TextStyle(
                                        color: WarPalette.gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.defensePower != null)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  const Text('Savunma', style: TextStyle(color: WarPalette.titanium, fontSize: 8)),
                                  Text(
                                    '${widget.defensePower}',
                                    style: TextStyle(
                                      color: widget.isUnderSiege ? WarPalette.ruby : WarPalette.neon,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
