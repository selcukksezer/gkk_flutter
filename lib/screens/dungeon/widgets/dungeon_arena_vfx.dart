import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dungeon_battle_profiles.dart';

// =============================================================================
// 1. 16-Mode Bespoke Environmental & Combat Weather VFX Painter
// =============================================================================
class DungeonWeatherPainter extends CustomPainter {
  const DungeonWeatherPainter({
    required this.type,
    required this.progress,
    required this.primary,
    required this.secondary,
    this.intensity = 1.0,
  });

  final DungeonWeatherVfxType type;
  final double progress;
  final Color primary;
  final Color secondary;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (type) {
      case DungeonWeatherVfxType.mistClaws:
        _paintMistClaws(canvas, size);
      case DungeonWeatherVfxType.venomWebs:
        _paintVenomWebs(canvas, size);
      case DungeonWeatherVfxType.campEmbers:
        _paintRisingSparks(canvas, size, count: 28, drift: 18, smoke: true);
      case DungeonWeatherVfxType.sporeFloat:
        _paintSpores(canvas, size);
      case DungeonWeatherVfxType.fallingLeaves:
        _paintFallingLeaves(canvas, size);
      case DungeonWeatherVfxType.cursedHexes:
        _paintCursedHexes(canvas, size);
      case DungeonWeatherVfxType.crystalGlint:
        _paintCrystalGlints(canvas, size);
      case DungeonWeatherVfxType.abyssRipples:
        _paintAbyssRipples(canvas, size);
      case DungeonWeatherVfxType.batSwarm:
        _paintBatSwarm(canvas, size);
      case DungeonWeatherVfxType.sandstorm:
        _paintSandstorm(canvas, size);
      case DungeonWeatherVfxType.solarHieroglyphs:
        _paintSolarHieroglyphs(canvas, size);
      case DungeonWeatherVfxType.blizzard:
        _paintBlizzard(canvas, size);
      case DungeonWeatherVfxType.lightningStorm:
        _paintLightningStorm(canvas, size);
      case DungeonWeatherVfxType.magmaAsh:
        _paintRisingSparks(canvas, size, count: 38, drift: 26, smoke: false);
      case DungeonWeatherVfxType.necroticBlood:
        _paintNecroticBlood(canvas, size);
      case DungeonWeatherVfxType.cosmicFracture:
        _paintCosmicFracture(canvas, size);
    }
  }

  void _paintMistClaws(Canvas canvas, Size size) {
    // Low drifting ground fog banks
    for (int i = 0; i < 6; i++) {
      final double phase = (progress * (0.25 + i * 0.05) + i * 0.19) % 1.0;
      final double cx = (phase * 1.4 - 0.2) * size.width;
      final double cy = size.height * (0.64 + (i % 3) * 0.10);
      final Rect rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.55,
        height: 54 + i * 8,
      );
      final Paint mist = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            primary.withValues(alpha: 0.14 * intensity),
            secondary.withValues(alpha: 0.05 * intensity),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawOval(rect, mist);
    }
    // Soft drifting bioluminescent forest motes in the dark canopy
    for (int i = 0; i < 14; i++) {
      final double seed = ((i * 173) % 1000) / 1000;
      final double p = (progress * (0.45 + (i % 3) * 0.12) + seed) % 1.0;
      final double alpha =
          math.sin(p * math.pi).clamp(0.0, 1.0) * 0.34 * intensity;
      final double x = size.width * (0.08 + ((seed * 7.3) % 0.84)) +
          math.sin((p * 2 + i) * math.pi) * 12;
      final double y = size.height * (0.82 - p * 0.62);
      final Color c = i.isEven ? primary : secondary;
      canvas.drawCircle(
        Offset(x, y),
        2.2 + (i % 3) * 1.1,
        Paint()
          ..color = c.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
      );
    }
  }

  void _paintVenomWebs(Canvas canvas, Size size) {
    // Low toxic bog miasma pools + dripping glowing venom droplets (no corner arcs)
    for (int i = 0; i < 4; i++) {
      final double phase = (progress * (0.20 + i * 0.05) + i * 0.25) % 1.0;
      final double cx = (phase * 1.3 - 0.15) * size.width;
      final double cy = size.height * (0.70 + (i % 2) * 0.10);
      final Rect mistRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.50,
        height: 48,
      );
      canvas.drawOval(
        mistRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              primary.withValues(alpha: 0.11 * intensity),
              Colors.transparent,
            ],
          ).createShader(mistRect),
      );
    }
    // Dripping glowing venom droplets
    for (int i = 0; i < 20; i++) {
      final double seed = ((i * 137) % 100) / 100;
      final double phase = (progress * (0.55 + (i % 5) * 0.12) + seed) % 1.0;
      final double x = size.width * (0.06 + seed * 0.88);
      final double y = size.height * (phase * 0.95);
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Paint drop = Paint()
        ..color = primary.withValues(alpha: 0.65 * fade * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 3.4, height: 8.5),
        drop,
      );
    }
  }

  void _paintRisingSparks(
    Canvas canvas,
    Size size, {
    required int count,
    required double drift,
    required bool smoke,
  }) {
    for (int i = 0; i < count; i++) {
      final double seed = ((i * 173) % 1000) / 1000;
      final double speed = 0.45 + ((i * 47) % 100) / 100 * 0.75;
      final double phase = (progress * speed + seed) % 1.0;
      final double x = size.width * ((seed * 9.3) % 1.0) +
          math.sin((phase * 3 + i) * math.pi) * drift;
      final double y = size.height * (1.04 - phase * 1.08);
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Color c = i % 3 == 0 ? secondary : primary;
      if (smoke && i % 5 == 0) {
        final Paint sm = Paint()
          ..color = Colors.white.withValues(alpha: 0.05 * fade * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(Offset(x, y), 14, sm);
      }
      final Paint spark = Paint()
        ..color = c.withValues(alpha: 0.78 * fade * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
      canvas.drawCircle(Offset(x, y), 1.3 + (i % 3) * 0.9, spark);
    }
  }

  void _paintSpores(Canvas canvas, Size size) {
    for (int i = 0; i < 26; i++) {
      final double seed = ((i * 197) % 1000) / 1000;
      final double phase = (progress * (0.3 + (i % 4) * 0.1) + seed) % 1.0;
      final double x = size.width * ((seed * 5.7) % 1.0) +
          math.sin((phase * 2 + i) * math.pi * 2) * 18;
      final double y = size.height * (0.98 - phase * 0.92);
      final double pulse = 0.45 + 0.55 * math.sin((progress * 3 + i) * math.pi * 2).abs();
      final Color c = i.isEven ? primary : secondary;
      final Paint glow = Paint()
        ..color = c.withValues(alpha: 0.30 * pulse * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, y), 5.5 + (i % 3) * 2.0, glow);
      canvas.drawCircle(
        Offset(x, y),
        1.8,
        Paint()..color = Colors.white.withValues(alpha: 0.8 * pulse * intensity),
      );
    }
  }

  void _paintFallingLeaves(Canvas canvas, Size size) {
    for (int i = 0; i < 20; i++) {
      final double seed = ((i * 223) % 1000) / 1000;
      final double phase = (progress * (0.35 + (i % 4) * 0.12) + seed) % 1.0;
      final double x = size.width * ((seed * 6.1 + phase * 0.28) % 1.05);
      final double y = size.height * (phase * 1.05 - 0.04);
      final double rot = (phase * 4 + i) * math.pi;
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Color c = i % 3 == 0 ? secondary : primary;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 8.5, height: 4.0),
        Paint()..color = c.withValues(alpha: 0.72 * fade * intensity),
      );
      canvas.restore();
    }
  }

  void _paintCursedHexes(Canvas canvas, Size size) {
    // Eerie rising spectral soul-flame wisps (no geometric boxes)
    for (int i = 0; i < 20; i++) {
      final double seed = ((i * 157) % 1000) / 1000;
      final double phase = (progress * (0.38 + (i % 3) * 0.11) + seed) % 1.0;
      final double x = size.width * (0.06 + ((seed * 8.3) % 0.88)) +
          math.sin((phase * 3 + i) * math.pi) * 14;
      final double y = size.height * (0.94 - phase * 0.80);
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Color c = i.isEven ? primary : secondary;
      final Rect glowRect = Rect.fromCenter(
        center: Offset(x, y),
        width: 12,
        height: 28,
      );
      canvas.drawOval(
        glowRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              c.withValues(alpha: 0.42 * fade * intensity),
              Colors.transparent,
            ],
          ).createShader(glowRect),
      );
      canvas.drawCircle(
        Offset(x, y - 2),
        1.7,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.68 * fade * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }
  }

  void _paintCrystalGlints(Canvas canvas, Size size) {
    for (int i = 0; i < 20; i++) {
      final double seed = ((i * 251) % 1000) / 1000;
      final double twinkle = math
          .pow(
            math.sin(((progress * 2 + seed) % 1.0) * math.pi).clamp(0.0, 1.0),
            2,
          )
          .toDouble();
      final double x = size.width * ((seed * 11.3) % 1.0);
      final double y = size.height * (0.08 + ((seed * 7.9) % 0.82));
      final Color c = i.isEven ? primary : secondary;
      final double rad = (6.0 + (i % 4) * 3.5) * (0.5 + 0.5 * twinkle);
      final Rect halo = Rect.fromCircle(center: Offset(x, y), radius: rad);
      canvas.drawOval(
        halo,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              c.withValues(alpha: 0.42 * twinkle * intensity),
              Colors.transparent,
            ],
          ).createShader(halo),
      );
      canvas.drawCircle(
        Offset(x, y),
        1.4 + twinkle * 1.1,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.78 * twinkle * intensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );
    }
  }

  void _paintAbyssRipples(Canvas canvas, Size size) {
    for (int i = 0; i < 6; i++) {
      final double phase = (progress * 0.45 + i * 0.17) % 1.0;
      final double cx = size.width * (0.20 + ((i * 37) % 60) / 100);
      final double cy = size.height * (0.72 + (i % 3) * 0.06);
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0) * 0.22 * intensity;
      final Rect pool = Rect.fromCenter(
        center: Offset(cx, cy),
        width: 30 + phase * 96,
        height: 8 + phase * 20,
      );
      canvas.drawOval(
        pool,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              primary.withValues(alpha: fade),
              Colors.transparent,
            ],
          ).createShader(pool),
      );
    }
    _paintSpores(canvas, size);
  }

  void _paintBatSwarm(Canvas canvas, Size size) {
    // Drifting cavern shadow-ash & crimson dust motes (zero cartoon line bats)
    _paintRisingSparks(canvas, size, count: 24, drift: 22, smoke: true);
  }

  void _paintSandstorm(Canvas canvas, Size size) {
    for (int i = 0; i < 34; i++) {
      final double seed = ((i * 167) % 1000) / 1000;
      final double phase = (progress * (1.2 + (i % 4) * 0.25) + seed) % 1.0;
      final double x = size.width * (1.1 - phase * 1.25);
      final double y = size.height * ((seed * 9.7) % 1.0) + phase * 28;
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Paint streak = Paint()
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..color = (i % 3 == 0 ? secondary : primary)
            .withValues(alpha: 0.42 * fade * intensity);
      canvas.drawLine(Offset(x, y), Offset(x + 28, y - 6), streak);
    }
  }

  void _paintSolarHieroglyphs(Canvas canvas, Size size) {
    // Shimmering golden tomb dust motes & warm torch embers
    _paintRisingSparks(canvas, size, count: 28, drift: 16, smoke: false);
    for (int i = 0; i < 12; i++) {
      final double seed = ((i * 211) % 1000) / 1000;
      final double phase = (progress * 0.32 + seed) % 1.0;
      final double x = size.width * (0.08 + ((seed * 7.3) % 0.84));
      final double y = size.height * (0.86 - phase * 0.68);
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Rect mote = Rect.fromCenter(
        center: Offset(x, y),
        width: 18,
        height: 18,
      );
      canvas.drawOval(
        mote,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              primary.withValues(alpha: 0.28 * fade * intensity),
              Colors.transparent,
            ],
          ).createShader(mote),
      );
    }
  }

  void _paintBlizzard(Canvas canvas, Size size) {
    for (int i = 0; i < 36; i++) {
      final double seed = ((i * 149) % 1000) / 1000;
      final double phase = (progress * (0.9 + (i % 4) * 0.2) + seed) % 1.0;
      final double x = (size.width * ((seed * 8.1) % 1.2) - phase * size.width * 0.35) %
          size.width;
      final double y = size.height * phase;
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Paint flake = Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.62 * fade * intensity);
      canvas.drawLine(Offset(x, y), Offset(x + 7, y - 9), flake);
    }
  }

  void _paintLightningStorm(Canvas canvas, Size size) {
    // Fine atmospheric storm mist streaks
    for (int i = 0; i < 20; i++) {
      final double seed = ((i * 131) % 1000) / 1000;
      final double phase = (progress * 1.6 + seed) % 1.0;
      final double x = size.width * ((seed * 7.7) % 1.0);
      final double y = size.height * phase;
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 4, y - 14),
        Paint()
          ..strokeWidth = 0.9
          ..color = Colors.white.withValues(alpha: 0.13 * fade * intensity),
      );
    }
    // Volumetric upper-vault storm illumination flash (zero jagged wireframe bolts)
    final double boltWindow = (progress * 3.0) % 1.0;
    if (boltWindow < 0.14) {
      final double flash = (1 - boltWindow / 0.14) * intensity;
      final int boltIdx = (progress * 3.0).floor();
      final double bx = size.width * (0.25 + ((boltIdx * 37) % 50) / 100);
      final Rect stormGlow = Rect.fromCenter(
        center: Offset(bx, size.height * 0.14),
        width: size.width * 0.65,
        height: size.height * 0.42,
      );
      canvas.drawOval(
        stormGlow,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.22 * flash),
              primary.withValues(alpha: 0.16 * flash),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.45, 1.0],
          ).createShader(stormGlow),
      );
    }
  }

  void _paintNecroticBlood(Canvas canvas, Size size) {
    for (int i = 0; i < 24; i++) {
      final double seed = ((i * 179) % 1000) / 1000;
      final double phase = (progress * (0.42 + (i % 3) * 0.14) + seed) % 1.0;
      final double x = size.width * ((seed * 8.9) % 1.0) +
          math.sin((phase * 3 + i) * math.pi) * 14;
      final double y = size.height * (0.98 - phase * 0.85);
      final double fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final Color c = i % 3 == 0 ? secondary : primary;
      final Paint wisp = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            c.withValues(alpha: 0.72 * fade * intensity),
            c.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x - 3, y, 6, 18));
      canvas.drawOval(Rect.fromLTWH(x - 3, y, 6, 18), wisp);
    }
  }

  void _paintCosmicFracture(Canvas canvas, Size size) {
    // Soft drifting nebula/singularity aura motes (zero wireframe rings)
    final Offset center = Offset(size.width * 0.5, size.height * 0.36);
    final double pulse = 0.75 + 0.25 * math.sin(progress * math.pi * 2);
    final Rect corona =
        Rect.fromCircle(center: center, radius: size.width * 0.26);
    canvas.drawOval(
      corona,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            primary.withValues(alpha: 0.14 * pulse * intensity),
            secondary.withValues(alpha: 0.06 * pulse * intensity),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(corona),
    );
    _paintCrystalGlints(canvas, size);
  }

  @override
  bool shouldRepaint(DungeonWeatherPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.type != type ||
      oldDelegate.primary != primary;
}

// =============================================================================
// 2. Perspective-Grounded 2.5D Stage Floor Rune & Shadow Painter
// =============================================================================
class DungeonStageFloorPainter extends CustomPainter {
  const DungeonStageFloorPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.isBoss,
    required this.heroX,
    required this.enemyX,
    required this.groundY,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final bool isBoss;
  final double heroX;
  final double enemyX;
  final double groundY;

  @override
  void paint(Canvas canvas, Size size) {
    final double pulse = 0.72 + 0.28 * math.sin(progress * math.pi * 2);

    // Subtle atmospheric torch/elemental floor bounce-light pool (zero wireframe lines)
    final Rect arenaPool = Rect.fromCenter(
      center: Offset((heroX + enemyX) * 0.5, groundY + 4),
      width: (enemyX - heroX).abs() * 1.45,
      height: 68,
    );
    canvas.drawOval(
      arenaPool,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            primary.withValues(alpha: (isBoss ? 0.18 : 0.10) * pulse),
            secondary.withValues(alpha: 0.04 * pulse),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(arenaPool),
    );

    // Hero grounded ambient + core contact shadow on dungeon flagstones
    _drawGroundedShadow(
      canvas,
      center: Offset(heroX, groundY),
      width: 146,
      height: 30,
      rimColor: const Color(0xFF34D399),
      rimAlpha: 0.14 * pulse,
    );

    // Boss / Guardian heavy grounded contact shadow + subtle elemental floor reflection
    _drawGroundedShadow(
      canvas,
      center: Offset(enemyX, groundY),
      width: isBoss ? 196 : 164,
      height: isBoss ? 40 : 34,
      rimColor: primary,
      rimAlpha: (isBoss ? 0.28 : 0.18) * pulse,
    );
  }

  void _drawGroundedShadow(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color rimColor,
    required double rimAlpha,
  }) {
    // 1. Soft floor bounce light around feet
    final Rect glowRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 2),
      width: width * 1.32,
      height: height * 1.55,
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            rimColor.withValues(alpha: rimAlpha),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );

    // 2. Wide soft ambient occlusion shadow
    final Rect wideShadow =
        Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawOval(
      wideShadow,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 3. Tight dark core contact shadow directly beneath boots/claws
    final Rect coreShadow = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 1),
      width: width * 0.64,
      height: height * 0.48,
    );
    canvas.drawOval(
      coreShadow,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.86)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(DungeonStageFloorPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.heroX != heroX ||
      oldDelegate.enemyX != enemyX ||
      oldDelegate.primary != primary;
}

// =============================================================================
// 3. 8-Archetype Bespoke Ornamental HUD Frame Container
// =============================================================================
class DungeonOrnamentalPanel extends StatelessWidget {
  const DungeonOrnamentalPanel({
    super.key,
    required this.style,
    required this.primary,
    required this.secondary,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.fillAlpha = 0.86,
  });

  final DungeonHudFrameStyle style;
  final Color primary;
  final Color secondary;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double fillAlpha;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OrnamentalFramePainter(
        style: style,
        primary: primary,
        secondary: secondary,
        fillAlpha: fillAlpha,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _OrnamentalFramePainter extends CustomPainter {
  const _OrnamentalFramePainter({
    required this.style,
    required this.primary,
    required this.secondary,
    required this.fillAlpha,
  });

  final DungeonHudFrameStyle style;
  final Color primary;
  final Color secondary;
  final double fillAlpha;

  Path _buildOuterPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    switch (style) {
      case DungeonHudFrameStyle.crystallineRunic:
      case DungeonHudFrameStyle.dwarvenForge:
        // Chamfered octagonal bevel frame
        const double c = 14.0;
        return Path()
          ..moveTo(c, 0)
          ..lineTo(w - c, 0)
          ..lineTo(w, c)
          ..lineTo(w, h - c)
          ..lineTo(w - c, h)
          ..lineTo(c, h)
          ..lineTo(0, h - c)
          ..lineTo(0, c)
          ..close();

      case DungeonHudFrameStyle.solarHieroglyph:
        // Stepped Pharaonic temple corner frame
        const double s = 8.0;
        return Path()
          ..moveTo(s * 2, 0)
          ..lineTo(w - s * 2, 0)
          ..lineTo(w - s * 2, s)
          ..lineTo(w - s, s)
          ..lineTo(w - s, s * 2)
          ..lineTo(w, s * 2)
          ..lineTo(w, h - s * 2)
          ..lineTo(w - s, h - s * 2)
          ..lineTo(w - s, h - s)
          ..lineTo(w - s * 2, h - s)
          ..lineTo(w - s * 2, h)
          ..lineTo(s * 2, h)
          ..lineTo(s * 2, h - s)
          ..lineTo(s, h - s)
          ..lineTo(s, h - s * 2)
          ..lineTo(0, h - s * 2)
          ..lineTo(0, s * 2)
          ..lineTo(s, s * 2)
          ..lineTo(s, s)
          ..lineTo(s * 2, s)
          ..close();

      case DungeonHudFrameStyle.infernalSpike:
      case DungeonHudFrameStyle.tempestGlacier:
        // Sharp notched aggressive war-frame
        const double n = 12.0;
        return Path()
          ..moveTo(n, 0)
          ..lineTo(w * 0.5 - 18, 0)
          ..lineTo(w * 0.5, 4)
          ..lineTo(w * 0.5 + 18, 0)
          ..lineTo(w - n, 0)
          ..lineTo(w, n)
          ..lineTo(w, h - n)
          ..lineTo(w - n, h)
          ..lineTo(n, h)
          ..lineTo(0, h - n)
          ..lineTo(0, n)
          ..close();

      case DungeonHudFrameStyle.feralFang:
      case DungeonHudFrameStyle.organicSpore:
      case DungeonHudFrameStyle.celestialMythic:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Offset.zero & size,
              Radius.circular(
                style == DungeonHudFrameStyle.celestialMythic ? 20 : 16,
              ),
            ),
          );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Path path = _buildOuterPath(size);

    // Shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.72), 14, false);

    // Translucent dark-fantasy glass fill tinted subtly by dungeon primary
    final Rect bounds = Offset.zero & size;
    final Paint fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.lerp(const Color(0xFF0E1422), primary, 0.14)!
              .withValues(alpha: fillAlpha),
          Color.lerp(const Color(0xFF070A12), secondary, 0.08)!
              .withValues(alpha: (fillAlpha + 0.06).clamp(0.0, 0.97)),
        ],
      ).createShader(bounds);
    canvas.drawPath(path, fill);

    // Luminous border stroke
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          primary.withValues(alpha: 0.78),
          secondary.withValues(alpha: 0.42),
          primary.withValues(alpha: 0.65),
        ],
      ).createShader(bounds);
    canvas.drawPath(path, border);

    // Archetype-specific corner filigree / rivets / diamonds
    _paintCornerOrnaments(canvas, size);
  }

  void _paintCornerOrnaments(Canvas canvas, Size size) {
    final double w = size.width;
    final Paint accent = Paint()
      ..color = primary.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Sleek glowing top-center dark-fantasy crest bar along the rounded rim
    final Rect crestRect = Rect.fromLTWH(w * 0.24, 0, w * 0.52, 2.2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(crestRect, const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            Colors.transparent,
            primary.withValues(alpha: 0.88),
            secondary.withValues(alpha: 0.92),
            primary.withValues(alpha: 0.88),
            Colors.transparent,
          ],
        ).createShader(crestRect),
    );
    if (style == DungeonHudFrameStyle.crystallineRunic ||
        style == DungeonHudFrameStyle.celestialMythic) {
      final Path diamond = Path()
        ..moveTo(w * 0.5, -3.5)
        ..lineTo(w * 0.5 + 5, 1)
        ..lineTo(w * 0.5, 5.5)
        ..lineTo(w * 0.5 - 5, 1)
        ..close();
      canvas.drawPath(diamond, accent);
    }
  }

  @override
  bool shouldRepaint(_OrnamentalFramePainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.fillAlpha != fillAlpha;
}
