import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'faction_crest_painter.dart';
import 'siege_combat_vfx_coordinator.dart';

// =============================================================================
// 1. Data Models for Trajectories, Burning Oil Decals, and Ambient Atmosphere
// =============================================================================

/// Dynamic burning oil / boiling pitch ground decal.
class BurningOilDecal {
  BurningOilDecal({
    required this.id,
    required this.position,
    required this.radiusX,
    required this.radiusY,
    required this.rotation,
    this.lifetime = const Duration(seconds: 12),
  })  : createdAt = DateTime.now(),
        bubbleOffsets = List<Offset>.generate(
          7,
          (int i) => Offset(
            (math.Random(i * 23 + 7).nextDouble() * 2.0 - 1.0) * 0.72,
            (math.Random(i * 41 + 13).nextDouble() * 2.0 - 1.0) * 0.65,
          ),
        );

  final String id;
  final Offset position;
  final double radiusX;
  final double radiusY;
  final double rotation;
  final Duration lifetime;
  final DateTime createdAt;
  final List<Offset> bubbleOffsets;

  double get ageRatio {
    final int elapsed = DateTime.now().difference(createdAt).inMilliseconds;
    return (elapsed / lifetime.inMilliseconds).clamp(0.0, 1.0);
  }

  double get opacity => (1.0 - ageRatio).clamp(0.0, 1.0);
  bool get isExpired => ageRatio >= 1.0;
}

/// Dynamic catapult projectile following a realistic parabolic ballistic arc.
class CatapultProjectile {
  CatapultProjectile({
    required this.id,
    required this.start,
    required this.target,
    required this.arcHeight,
    required this.duration,
    required this.damage,
    this.isCritical = false,
  });

  final String id;
  final Offset start;
  final Offset target;
  final double arcHeight;
  final double duration;
  final int damage;
  final bool isCritical;

  double elapsed = 0.0;
  double rotation = 0.0;
  final List<Offset> trailHistory = <Offset>[];

  double get progress => (elapsed / duration).clamp(0.0, 1.0);
  bool get isFinished => elapsed >= duration;

  Offset get currentPosition {
    final double t = progress;
    final double x = start.dx + (target.dx - start.dx) * t;
    // Ballistic parabolic arc: 4 * h * t * (1 - t)
    final double y = start.dy + (target.dy - start.dy) * t - 4.0 * arcHeight * t * (1.0 - t);
    return Offset(x, y);
  }

  void update(double dt) {
    elapsed += dt;
    rotation += dt * 8.5;
    final Offset pos = currentPosition;
    trailHistory.insert(0, pos);
    if (trailHistory.length > 22) {
      trailHistory.removeLast();
    }
  }
}

/// Atmospheric ambient ember/ash particle floating across the battlefield.
class BattlefieldAmbientEmber {
  BattlefieldAmbientEmber({
    required this.xRatio,
    required this.yRatio,
    required this.speedY,
    required this.driftSpeedX,
    required this.driftAmplitude,
    required this.size,
    required this.baseAlpha,
    required this.color,
    required this.phase,
  });

  double xRatio;
  double yRatio;
  final double speedY;
  final double driftSpeedX;
  final double driftAmplitude;
  final double size;
  final double baseAlpha;
  final Color color;
  double phase;

  void update(double dt) {
    yRatio -= speedY * dt;
    phase += dt * driftSpeedX;
    if (yRatio < -0.05) {
      yRatio = 1.05;
      xRatio = math.Random().nextDouble();
    }
  }
}

// =============================================================================
// 2. High-Performance Custom Painters (Atmosphere, Ramparts, Trajectories, Decals)
// =============================================================================

/// Multi-layered battlefield atmosphere with rolling volumetric smoke plumes
/// and distant burning horizon glow.
class BattlefieldAtmospherePainter extends CustomPainter {
  BattlefieldAtmospherePainter({
    required this.animTime,
  });

  final double animTime;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect fullRect = Offset.zero & size;

    // 1. Stormy Dark-Fantasy Skybox Gradient
    final Paint skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF160A13), // Deep blood-smoke twilight
          Color(0xFF0F121E), // Soot-black stone atmosphere
          Color(0xFF0B0D15), // Abyssal ground shadow
        ],
        stops: <double>[0.0, 0.55, 1.0],
      ).createShader(fullRect);
    canvas.drawRect(fullRect, skyPaint);

    // 2. Distant Jagged Mountain Peaks Silhouette
    final Path mountainPath = Path();
    mountainPath.moveTo(0, size.height * 0.38);
    mountainPath.lineTo(size.width * 0.15, size.height * 0.26);
    mountainPath.lineTo(size.width * 0.32, size.height * 0.34);
    mountainPath.lineTo(size.width * 0.48, size.height * 0.22);
    mountainPath.lineTo(size.width * 0.65, size.height * 0.32);
    mountainPath.lineTo(size.width * 0.82, size.height * 0.24);
    mountainPath.lineTo(size.width, size.height * 0.36);
    mountainPath.lineTo(size.width, size.height);
    mountainPath.lineTo(0, size.height);
    mountainPath.close();

    final Paint mountainPaint = Paint()
      ..color = const Color(0xFF131622).withValues(alpha: 0.95);
    canvas.drawPath(mountainPath, mountainPaint);

    // 3. Distant Siege Horizon Fires Glow
    final double horizonPulse = 0.5 + 0.3 * math.sin(animTime * 2.2);
    final Paint fireGlowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.3),
        radius: 0.85,
        colors: <Color>[
          const Color(0xFFFF5722).withValues(alpha: 0.22 * horizonPulse),
          const Color(0xFFFF1744).withValues(alpha: 0.08 * horizonPulse),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(fullRect);
    canvas.drawRect(fullRect, fireGlowPaint);

    // 4. Volumetric Drifting Smoke Plumes (2 Procedural Wave Layers)
    _drawVolumetricSmokeBand(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.25,
      amplitude: 14.0,
      frequency: 0.015,
      speed: 16.0,
      color: const Color(0xFF231C24).withValues(alpha: 0.35),
    );
    _drawVolumetricSmokeBand(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.15,
      amplitude: 18.0,
      frequency: 0.012,
      speed: 10.0,
      color: const Color(0xFF1A1722).withValues(alpha: 0.25),
    );

    // 5. Muddy Charred Battlefield Ground Gradient
    final Rect groundRect = Rect.fromLTRB(0, size.height * 0.52, size.width, size.height);
    final Paint groundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF151822),
          Color(0xFF0F1118),
          Color(0xFF090A0F),
        ],
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);
  }

  void _drawVolumetricSmokeBand({
    required Canvas canvas,
    required Size size,
    required double baseY,
    required double amplitude,
    required double frequency,
    required double speed,
    required Color color,
  }) {
    final Path path = Path();
    path.moveTo(0, baseY);

    final double phase = (animTime * speed) * frequency;
    for (double x = 0; x <= size.width; x += 18.0) {
      final double y = baseY +
          math.sin(x * frequency + phase) * amplitude +
          math.cos(x * frequency * 1.8 - phase * 0.6) * (amplitude * 0.4);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    final Paint smokePaint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawPath(path, smokePaint);
  }

  @override
  bool shouldRepaint(covariant BattlefieldAtmospherePainter oldDelegate) => true;
}

/// Full Fortress Ramparts & Gate Architecture with 4 Rich Damage States:
/// - State 1: Pristine Granite Masonry & Warding Runes (Integrity >= 0.8)
/// - State 2: Structural Fractures & Mortar Dust (0.5 <= Integrity < 0.8)
/// - State 3: Severe Crenel Breaches & Buckling Timbers (0.2 <= Integrity < 0.5)
/// - State 4: Blown Gateway & Flaming Interior Inferno (Integrity < 0.2)
class FortressRampartPainter extends CustomPainter {
  FortressRampartPainter({
    required this.gateIntegrity,
    required this.animTime,
    required this.isElyosAttacker,
    required this.isVictory,
  });

  final double gateIntegrity;
  final double animTime;
  final bool isElyosAttacker;
  final bool isVictory;

  @override
  void paint(Canvas canvas, Size size) {
    final double wallTop = size.height * 0.16;
    final double wallHeight = size.height * 0.36;
    final double wallBottom = wallTop + wallHeight;
    final double centerX = size.width * 0.5;

    // 1. Bastion Towers on Flanks
    _drawBastionTower(canvas, size, Offset(size.width * 0.08, wallTop - 18), true);
    _drawBastionTower(canvas, size, Offset(size.width * 0.82, wallTop - 18), false);

    // 2. Main Stone Curtain Wall Masonry
    final Rect wallRect = Rect.fromLTRB(size.width * 0.16, wallTop, size.width * 0.84, wallBottom);
    final Paint stonePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF2B2E3D),
          const Color(0xFF1E212D),
          const Color(0xFF151722),
        ],
      ).createShader(wallRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(wallRect, const Radius.circular(4)),
      stonePaint,
    );

    // Stone ashlar course lines
    final Paint mortarPaint = Paint()
      ..color = const Color(0xFF10121A).withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (double y = wallTop + 14; y < wallBottom; y += 14.0) {
      canvas.drawLine(Offset(size.width * 0.16, y), Offset(size.width * 0.84, y), mortarPaint);
    }

    // 3. Parapet Battlements (Crenels & Merlons)
    _drawBattlements(canvas, size.width * 0.16, size.width * 0.84, wallTop);

    // 4. Central Fortress Gateway Archway & Doors
    _drawFortressGateAndDamage(canvas, centerX, wallBottom, wallHeight);

    // 5. Dynamic Damage Overlays (Cracks, Fissures, and Rubble based on Integrity)
    _drawStructuralDamageFissures(canvas, wallRect, centerX, wallBottom);

    // 6. Defensive Braziers on the Ramparts
    _drawRampartBrazier(canvas, Offset(size.width * 0.22, wallTop - 4));
    _drawRampartBrazier(canvas, Offset(size.width * 0.78, wallTop - 4));
  }

  void _drawBastionTower(Canvas canvas, Size size, Offset origin, bool isLeft) {
    const double towerWidth = 38.0;
    const double towerHeight = 72.0;
    final Rect towerRect = Rect.fromLTWH(origin.dx, origin.dy, towerWidth, towerHeight);

    // Tower Body
    final Paint towerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF383C4D),
          const Color(0xFF222533),
          const Color(0xFF171924),
        ],
      ).createShader(towerRect);
    canvas.drawRRect(RRect.fromRectAndRadius(towerRect, const Radius.circular(3)), towerPaint);

    // Tower Crenellations
    final Paint crenelPaint = Paint()..color = const Color(0xFF2B2E3D);
    canvas.drawRect(Rect.fromLTWH(origin.dx + 2, origin.dy - 8, 10, 8), crenelPaint);
    canvas.drawRect(Rect.fromLTWH(origin.dx + towerWidth - 12, origin.dy - 8, 10, 8), crenelPaint);

    // Arrow Loop Slit with inner torchlight
    final Rect slitRect = Rect.fromLTWH(origin.dx + towerWidth * 0.5 - 2, origin.dy + 24, 4, 18);
    final Paint slitPaint = Paint()..color = const Color(0xFF0B0D14);
    canvas.drawRRect(RRect.fromRectAndRadius(slitRect, const Radius.circular(2)), slitPaint);

    final Paint innerLight = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(slitRect.center.dx, slitRect.center.dy), 2.5, innerLight);

    // Faction Hanging Banner
    final Path banner = Path();
    final double bannerLeft = origin.dx + 8;
    final double bannerTop = origin.dy + 45;
    banner.moveTo(bannerLeft, bannerTop);
    banner.lineTo(bannerLeft + 22, bannerTop);
    banner.lineTo(bannerLeft + 22, bannerTop + 34);
    banner.lineTo(bannerLeft + 11, bannerTop + 24);
    banner.lineTo(bannerLeft, bannerTop + 34);
    banner.close();

    final Color bannerColor = isElyosAttacker
        ? const Color(0xFFD50000) // Defender is Asmodian red
        : const Color(0xFF00B0FF); // Defender is Elyos cyan

    final Paint bannerPaint = Paint()
      ..color = gateIntegrity > 0.4
          ? bannerColor.withValues(alpha: 0.85)
          : const Color(0xFF3E2723).withValues(alpha: 0.7);
    canvas.drawPath(banner, bannerPaint);
  }

  void _drawBattlements(Canvas canvas, double left, double right, double top) {
    final Paint merlonPaint = Paint()..color = const Color(0xFF323646);
    const double merlonWidth = 14.0;
    const double merlonHeight = 10.0;
    const double crenelGap = 10.0;

    int index = 0;
    for (double x = left + 4; x < right - merlonWidth; x += (merlonWidth + crenelGap)) {
      // In heavy damage state, some merlons have crumbled away
      if (gateIntegrity < 0.4 && (index % 3 == 1)) {
        index++;
        continue;
      }
      canvas.drawRect(Rect.fromLTWH(x, top - merlonHeight, merlonWidth, merlonHeight), merlonPaint);
      index++;
    }
  }

  void _drawFortressGateAndDamage(Canvas canvas, double centerX, double wallBottom, double wallHeight) {
    const double gateWidth = 92.0;
    const double gateHeight = 68.0;
    final Rect gateRect = Rect.fromLTWH(centerX - gateWidth * 0.5, wallBottom - gateHeight, gateWidth, gateHeight);

    // Massive Stone Gateway Arch
    final Rect archRect = Rect.fromLTWH(gateRect.left - 8, gateRect.top - 12, gateWidth + 16, gateHeight + 12);
    final Paint archPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF454B60),
          const Color(0xFF262936),
        ],
      ).createShader(archRect);
    canvas.drawRRect(
      RRect.fromRectAndCorners(archRect, topLeft: const Radius.circular(24), topRight: const Radius.circular(24)),
      archPaint,
    );

    if (gateIntegrity <= 0.05) {
      // State 4: Blown Gateway & Flaming Interior Inferno
      final Paint infernoPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFF176),
            const Color(0xFFFF5722),
            const Color(0xFFB71C1C),
            const Color(0xFF210005),
          ],
          stops: const <double>[0.0, 0.35, 0.75, 1.0],
        ).createShader(gateRect);
      canvas.drawRRect(
        RRect.fromRectAndCorners(gateRect, topLeft: const Radius.circular(20), topRight: const Radius.circular(20)),
        infernoPaint,
      );

      // Broken Charred Timber Silhouette Spikes
      final Paint timberPaint = Paint()..color = const Color(0xFF1B0B0E);
      final Path brokenDoors = Path();
      brokenDoors.moveTo(gateRect.left, gateRect.bottom);
      brokenDoors.lineTo(gateRect.left + 16, gateRect.top + 28);
      brokenDoors.lineTo(gateRect.left + 24, gateRect.bottom);
      brokenDoors.moveTo(gateRect.right, gateRect.bottom);
      brokenDoors.lineTo(gateRect.right - 18, gateRect.top + 22);
      brokenDoors.lineTo(gateRect.right - 28, gateRect.bottom);
      canvas.drawPath(brokenDoors, timberPaint);
      return;
    }

    // Heavy Ironclad Oak Fortress Gate Doors
    final Paint doorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          const Color(0xFF2A2421),
          const Color(0xFF3E3531),
          const Color(0xFF2A2421),
        ],
      ).createShader(gateRect);
    canvas.drawRRect(
      RRect.fromRectAndCorners(gateRect, topLeft: const Radius.circular(20), topRight: const Radius.circular(20)),
      doorPaint,
    );

    // Iron reinforcement cross-bands
    final Paint ironBandPaint = Paint()
      ..color = const Color(0xFF1E212B)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(gateRect.left + 4, gateRect.top + 20), Offset(gateRect.right - 4, gateRect.top + 20), ironBandPaint);
    canvas.drawLine(Offset(gateRect.left + 4, gateRect.bottom - 16), Offset(gateRect.right - 4, gateRect.bottom - 16), ironBandPaint);

    // Central door seam
    final Paint seamPaint = Paint()
      ..color = const Color(0xFF12131A)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(centerX, gateRect.top + 4), Offset(centerX, gateRect.bottom), seamPaint);

    // Warding Runes on Archway (Pristine state = bright cyan/gold glow)
    if (gateIntegrity >= 0.8) {
      final double runeGlow = 0.5 + 0.5 * math.sin(animTime * 3.0);
      final Paint runePaint = Paint()
        ..color = (isElyosAttacker ? const Color(0xFF00E5FF) : const Color(0xFFFFB300))
            .withValues(alpha: 0.65 * runeGlow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      final Path runeArch = Path();
      runeArch.addArc(
        Rect.fromCircle(center: Offset(centerX, gateRect.top + 16), radius: gateWidth * 0.44),
        math.pi,
        math.pi,
      );
      canvas.drawPath(runeArch, runePaint);
    }
  }

  void _drawStructuralDamageFissures(Canvas canvas, Rect wallRect, double centerX, double wallBottom) {
    if (gateIntegrity >= 0.8) return;

    final Paint crackPaint = Paint()
      ..strokeWidth = gateIntegrity < 0.4 ? 2.8 : 1.6
      ..style = PaintingStyle.stroke
      ..color = gateIntegrity < 0.3 ? const Color(0xFFFF3D00) : const Color(0xFF151218);

    // Structural fracture 1: Left rampart to gate arch
    final Path crack1 = Path();
    crack1.moveTo(wallRect.left + 35, wallRect.top + 8);
    crack1.lineTo(wallRect.left + 50, wallRect.top + 22);
    crack1.lineTo(wallRect.left + 42, wallRect.top + 38);
    crack1.lineTo(centerX - 35, wallRect.top + 46);
    canvas.drawPath(crack1, crackPaint);

    // Structural fracture 2: Right rampart downward crack
    final Path crack2 = Path();
    crack2.moveTo(wallRect.right - 40, wallRect.top + 6);
    crack2.lineTo(wallRect.right - 52, wallRect.top + 26);
    crack2.lineTo(wallRect.right - 46, wallRect.top + 48);
    crack2.lineTo(centerX + 38, wallBottom - 18);
    canvas.drawPath(crack2, crackPaint);

    if (gateIntegrity < 0.5) {
      // Internal heat glow radiating through severe fissures
      final Paint fissureGlow = Paint()
        ..color = const Color(0xFFFF5722).withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(crack1, fissureGlow);
      canvas.drawPath(crack2, fissureGlow);

      // Crumbling stone rubble at the wall base
      final Paint rubblePaint = Paint()..color = const Color(0xFF2B2E3D);
      canvas.drawCircle(Offset(centerX - 55, wallBottom - 4), 4.5, rubblePaint);
      canvas.drawCircle(Offset(centerX - 62, wallBottom - 2), 3.0, rubblePaint);
      canvas.drawCircle(Offset(centerX + 58, wallBottom - 5), 5.0, rubblePaint);
      canvas.drawCircle(Offset(centerX + 66, wallBottom - 3), 3.5, rubblePaint);
    }
  }

  void _drawRampartBrazier(Canvas canvas, Offset pos) {
    // Iron Tripod Stand
    final Paint standPaint = Paint()
      ..color = const Color(0xFF1A1C24)
      ..strokeWidth = 2.0;
    canvas.drawLine(pos, Offset(pos.dx - 6, pos.dy + 12), standPaint);
    canvas.drawLine(pos, Offset(pos.dx + 6, pos.dy + 12), standPaint);
    canvas.drawCircle(pos, 5.0, Paint()..color = const Color(0xFF2A2D3D));

    // Animated Multi-Tongue Brazier Flame
    final double flameFlicker = 0.8 + 0.35 * math.sin(animTime * 6.0 + pos.dx);
    final Paint flamePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFFFFF9C4),
          const Color(0xFFFF9800),
          const Color(0xFFFF3D00).withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: pos + const Offset(0, -6), radius: 10 * flameFlicker));

    canvas.drawCircle(pos + const Offset(0, -6), 9.0 * flameFlicker, flamePaint);
  }

  @override
  bool shouldRepaint(covariant FortressRampartPainter oldDelegate) => true;
}

/// Dynamic Viscous Burning Oil & Boiling Pitch Ground Decals
/// with animated boiling bubbles, charred perimeter scorch, and dancing flame tongues.
class BurningOilDecalsPainter extends CustomPainter {
  BurningOilDecalsPainter({
    required this.decals,
    required this.animTime,
  });

  final List<BurningOilDecal> decals;
  final double animTime;

  @override
  void paint(Canvas canvas, Size size) {
    for (final BurningOilDecal decal in decals) {
      final double alpha = decal.opacity;
      if (alpha <= 0.0) continue;

      canvas.save();
      canvas.translate(decal.position.dx, decal.position.dy);
      canvas.rotate(decal.rotation);

      final Rect poolRect = Rect.fromCenter(
        center: Offset.zero,
        width: decal.radiusX * 2.0,
        height: decal.radiusY * 2.0,
      );

      // 1. Outer Scorched Earth Rim (Soft charred soot)
      final Paint scorchPaint = Paint()
        ..color = const Color(0xFF0D0709).withValues(alpha: alpha * 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawOval(poolRect.inflate(8.0), scorchPaint);

      // 2. Viscous Black Pitch Organic Body
      final Path pitchPath = Path();
      const int steps = 14;
      for (int i = 0; i <= steps; i++) {
        final double theta = (i / steps) * 2 * math.pi;
        final double perturbation = 1.0 +
            0.14 * math.sin(theta * 3.0 + decal.id.hashCode) +
            0.08 * math.cos(theta * 5.0);
        final double x = math.cos(theta) * decal.radiusX * perturbation;
        final double y = math.sin(theta) * decal.radiusY * perturbation;
        if (i == 0) {
          pitchPath.moveTo(x, y);
        } else {
          pitchPath.lineTo(x, y);
        }
      }
      pitchPath.close();

      final Paint pitchPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFF9100).withValues(alpha: alpha * 0.95), // Core molten fire
            const Color(0xFFD50000).withValues(alpha: alpha * 0.85), // Blazing pitch red
            const Color(0xFF1F0B10).withValues(alpha: alpha * 0.95), // Obsidian tar edge
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(poolRect);
      canvas.drawPath(pitchPath, pitchPaint);

      // 3. Animated Boiling Tar Bubbles
      final Paint bubblePaint = Paint();
      for (int i = 0; i < decal.bubbleOffsets.length; i++) {
        final Offset bOffset = Offset(
          decal.bubbleOffsets[i].dx * decal.radiusX,
          decal.bubbleOffsets[i].dy * decal.radiusY,
        );
        final double bPhase = (animTime * 3.5 + i * 1.3) % 1.0;
        final double bRadius = (1.5 + bPhase * 3.5);
        final double bAlpha = (1.0 - bPhase) * alpha;

        bubblePaint
          ..color = const Color(0xFFFFE082).withValues(alpha: bAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        canvas.drawCircle(bOffset, bRadius, bubblePaint);
      }

      // 4. Procedural Creeping Flame Tongues atop the Oil
      final Paint flamePaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFF59D).withValues(alpha: alpha * 0.9),
            const Color(0xFFFF6D00).withValues(alpha: alpha * 0.7),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: decal.radiusY * 0.7));

      for (int i = 0; i < 5; i++) {
        final double angle = (i / 5) * 2 * math.pi;
        final double flameH = 6.0 + 4.0 * math.sin(animTime * 7.0 + i * 2.0);
        final Offset flamePos = Offset(
          math.cos(angle) * (decal.radiusX * 0.5),
          math.sin(angle) * (decal.radiusY * 0.5) - flameH * 0.5,
        );
        canvas.drawCircle(flamePos, flameH, flamePaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant BurningOilDecalsPainter oldDelegate) => true;
}

/// Dynamic Catapult Projectile In-Flight Trajectory Renderer
/// Draws ballistic prediction arc, molten magma comet tail ribbon, and tumbling rock core.
class CatapultTrajectoryPainter extends CustomPainter {
  CatapultTrajectoryPainter({
    required this.projectiles,
    required this.animTime,
  });

  final List<CatapultProjectile> projectiles;
  final double animTime;

  @override
  void paint(Canvas canvas, Size size) {
    for (final CatapultProjectile proj in projectiles) {
      if (proj.isFinished) continue;

      // 1. Ghost Ballistic Trajectory Curve Guide
      final Path guidePath = Path();
      guidePath.moveTo(proj.start.dx, proj.start.dy);
      const int steps = 18;
      for (int i = 1; i <= steps; i++) {
        final double t = i / steps;
        final double x = proj.start.dx + (proj.target.dx - proj.start.dx) * t;
        final double y = proj.start.dy + (proj.target.dy - proj.start.dy) * t - 4.0 * proj.arcHeight * t * (1.0 - t);
        guidePath.lineTo(x, y);
      }

      final Paint guidePaint = Paint()
        ..color = const Color(0xFFFF9800).withValues(alpha: 0.22)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(guidePath, guidePaint);

      // 2. Fiery Magma Comet Tail (Trailing Historical Ribbon)
      if (proj.trailHistory.length >= 2) {
        final Paint glowTailPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

        final Paint coreTailPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        for (int i = 0; i < proj.trailHistory.length - 1; i++) {
          final double ratio = 1.0 - (i / proj.trailHistory.length);
          final Offset p0 = proj.trailHistory[i];
          final Offset p1 = proj.trailHistory[i + 1];

          glowTailPaint
            ..color = const Color(0xFFFF3D00).withValues(alpha: ratio * 0.75)
            ..strokeWidth = 12.0 * ratio;
          canvas.drawLine(p0, p1, glowTailPaint);

          coreTailPaint
            ..color = const Color(0xFFFFF176).withValues(alpha: ratio * 0.95)
            ..strokeWidth = 5.0 * ratio;
          canvas.drawLine(p0, p1, coreTailPaint);
        }
      }

      // 3. In-Flight Flaming Boulder
      final Offset curPos = proj.currentPosition;
      canvas.save();
      canvas.translate(curPos.dx, curPos.dy);
      canvas.rotate(proj.rotation);

      // Incandescent Outer Heat Coronal Aura
      final Paint auraPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFFF59D).withValues(alpha: 0.95),
            const Color(0xFFFF6D00).withValues(alpha: 0.75),
            const Color(0xFFDD2C00).withValues(alpha: 0.35),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.35, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 24.0));
      canvas.drawCircle(Offset.zero, 24.0, auraPaint);

      // Jagged Basalt / Magma Core
      final Path rockPath = Path();
      const int rockVertices = 7;
      for (int i = 0; i <= rockVertices; i++) {
        final double theta = (i / rockVertices) * 2 * math.pi;
        final double r = 8.5 + 2.5 * math.sin(theta * 3.0 + 1.2);
        final double rx = math.cos(theta) * r;
        final double ry = math.sin(theta) * r;
        if (i == 0) {
          rockPath.moveTo(rx, ry);
        } else {
          rockPath.lineTo(rx, ry);
        }
      }
      rockPath.close();

      final Paint rockPaint = Paint()..color = const Color(0xFF261914);
      canvas.drawPath(rockPath, rockPaint);

      // Molten magma fissure lines across the stone
      final Paint magmaFissure = Paint()
        ..color = const Color(0xFFFFD54F)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(-5, -3), const Offset(4, 5), magmaFissure);
      canvas.drawLine(const Offset(-2, 4), const Offset(5, -2), magmaFissure);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CatapultTrajectoryPainter oldDelegate) => true;
}

/// Atmospheric Ambient Embers & Ash Specks Painter
class BattlefieldAmbientEmbersPainter extends CustomPainter {
  BattlefieldAmbientEmbersPainter({
    required this.embers,
    required this.animTime,
  });

  final List<BattlefieldAmbientEmber> embers;
  final double animTime;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint emberPaint = Paint();

    for (final BattlefieldAmbientEmber e in embers) {
      final double sway = math.sin(e.phase) * (e.driftAmplitude / size.width);
      final double x = (e.xRatio + sway).clamp(0.0, 1.0) * size.width;
      final double y = e.yRatio * size.height;

      final double pulse = 0.7 + 0.3 * math.sin(animTime * 4.0 + e.phase);
      final double alpha = (e.baseAlpha * pulse).clamp(0.0, 1.0);

      emberPaint
        ..color = e.color.withValues(alpha: alpha)
        ..maskFilter = e.size > 2.0 ? const MaskFilter.blur(BlurStyle.normal, 2.0) : null;

      canvas.drawCircle(Offset(x, y), e.size, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BattlefieldAmbientEmbersPainter oldDelegate) => true;
}

/// Ground and Wall Scorches, Craters, Fissures, and Weapon Gouges
class SiegeDecalsPainter extends CustomPainter {
  SiegeDecalsPainter({required this.decals});

  final List<SiegeDecal> decals;

  @override
  void paint(Canvas canvas, Size size) {
    for (final SiegeDecal decal in decals) {
      final double alpha = decal.opacity;
      if (alpha <= 0.0) continue;

      canvas.save();
      canvas.translate(decal.position.dx, decal.position.dy);
      canvas.rotate(decal.rotation);

      final Rect rect = Rect.fromCircle(center: Offset.zero, radius: decal.radius);

      if (decal.type == SiegeDecalType.burningCrater) {
        // Outer dark scorched ring
        final Paint scorchPaint = Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFF1B0505).withValues(alpha: alpha * 0.88),
              const Color(0xFF3E120A).withValues(alpha: alpha * 0.65),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.7, 1.0],
          ).createShader(rect);
        canvas.drawOval(rect, scorchPaint);

        // Inner burning molten core
        final double innerR = decal.radius * 0.45;
        final Paint corePaint = Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              decal.secondaryColor.withValues(alpha: alpha * 0.95),
              decal.primaryColor.withValues(alpha: alpha * 0.75),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: innerR));
        canvas.drawCircle(Offset.zero, innerR, corePaint);
      } else if (decal.type == SiegeDecalType.wallScorch) {
        final Paint wallPaint = Paint()
          ..color = const Color(0xFF101015).withValues(alpha: alpha * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawOval(rect, wallPaint);
      } else if (decal.type == SiegeDecalType.crackedEarthFissure) {
        final Paint crackPaint = Paint()
          ..color = const Color(0xFF4E342E).withValues(alpha: alpha * 0.8)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
        final Path path = Path();
        path.moveTo(-decal.radius, 0);
        path.lineTo(-decal.radius * 0.4, 4);
        path.lineTo(0, -6);
        path.lineTo(decal.radius * 0.5, 3);
        path.lineTo(decal.radius, 0);
        canvas.drawPath(path, crackPaint);
      } else {
        // Blade gouge
        final Paint gougePaint = Paint()
          ..color = const Color(0xFF263238).withValues(alpha: alpha * 0.7)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(-decal.radius * 0.8, -4),
          Offset(decal.radius * 0.8, 4),
          gougePaint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SiegeDecalsPainter oldDelegate) => true;
}

/// Weapon Ribbon Trails
class SiegeWeaponTrailsPainter extends CustomPainter {
  SiegeWeaponTrailsPainter({required this.trails});

  final List<SiegeWeaponTrail> trails;

  @override
  void paint(Canvas canvas, Size size) {
    for (final SiegeWeaponTrail trail in trails) {
      if (trail.points.length < 2) continue;

      final Paint glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final Paint corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < trail.points.length - 1; i++) {
        final p0 = trail.points[i];
        final p1 = trail.points[i + 1];
        final double width = (p0.width + p1.width) * 0.5;

        glowPaint
          ..color = trail.glowColor.withValues(alpha: 0.6)
          ..strokeWidth = width * 1.8;
        canvas.drawLine(p0.tip, p1.tip, glowPaint);

        corePaint
          ..color = trail.primaryColor
          ..strokeWidth = width;
        canvas.drawLine(p0.tip, p1.tip, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SiegeWeaponTrailsPainter oldDelegate) => true;
}

/// Particle System Painter
class SiegeParticlesPainter extends CustomPainter {
  SiegeParticlesPainter({required this.particles});

  final List<SiegeParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pPaint = Paint();

    for (final SiegeParticle p in particles) {
      final double alpha = p.alpha;
      if (alpha <= 0.0) continue;

      pPaint.color = p.color.withValues(alpha: alpha);

      switch (p.type) {
        case SiegeParticleType.fieryEmber:
          pPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(p.position, p.scale, pPaint);
          break;
        case SiegeParticleType.smokePlume:
          pPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawCircle(p.position, p.scale, pPaint);
          break;
        case SiegeParticleType.stoneDebris:
          pPaint.maskFilter = null;
          canvas.save();
          canvas.translate(p.position.dx, p.position.dy);
          canvas.rotate(p.rotation);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.scale, height: p.scale * 1.4),
            pPaint,
          );
          canvas.restore();
          break;
        case SiegeParticleType.metalSpark:
          pPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
          canvas.drawCircle(p.position, p.scale, pPaint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SiegeParticlesPainter oldDelegate) => true;
}

// =============================================================================
// 3. Master Siege Combat Viewport Widget
// =============================================================================

class SiegeCombatViewport extends StatefulWidget {
  const SiegeCombatViewport({
    super.key,
    required this.territoryName,
    required this.attackPower,
    required this.defensePower,
    this.pointsGained = 0,
    this.isVictory = true,
    this.attackerGuildName = 'Saldıran Lonca',
    this.defenderGuildName = 'Savunan Lonca',
    this.isElyosAttacker = true,
    this.onSequenceCompleted,
    this.autoPlay = true,
    this.height = 360,
  });

  final String territoryName;
  final int attackPower;
  final int defensePower;
  final int pointsGained;
  final bool isVictory;
  final String attackerGuildName;
  final String defenderGuildName;
  final bool isElyosAttacker;
  final VoidCallback? onSequenceCompleted;
  final bool autoPlay;
  final double height;

  @override
  State<SiegeCombatViewport> createState() => _SiegeCombatViewportState();
}

class _SiegeCombatViewportState extends State<SiegeCombatViewport>
    with SingleTickerProviderStateMixin {
  late final GuildWarCombatVfxCoordinator coordinator;
  late final AnimationController _ticker;
  double _lastTick = 0.0;
  double _animTime = 0.0;

  // Siege progression states
  double gateIntegrity = 1.0;
  double attackerMorale = 1.0;
  String currentPhaseText = 'Kuşatma Mevzileniyor';
  int totalDamageDealt = 0;
  bool isSiegeResolved = false;

  // Dynamic projectile, decal, and atmosphere pools
  final List<CatapultProjectile> _projectiles = <CatapultProjectile>[];
  final List<BurningOilDecal> _burningOilDecals = <BurningOilDecal>[];
  late final List<BattlefieldAmbientEmber> _ambientEmbers;

  @override
  void initState() {
    super.initState();
    coordinator = GuildWarCombatVfxCoordinator();

    // Initialize multi-layered battlefield ambient embers
    _ambientEmbers = List<BattlefieldAmbientEmber>.generate(38, (int i) {
      final math.Random rng = math.Random(i * 19 + 5);
      final bool isBright = i % 3 == 0;
      final Color eColor = isBright
          ? const Color(0xFFFFD54F)
          : (i % 2 == 0 ? const Color(0xFFFF7043) : const Color(0xFF78909C));

      return BattlefieldAmbientEmber(
        xRatio: rng.nextDouble(),
        yRatio: rng.nextDouble(),
        speedY: 0.06 + rng.nextDouble() * 0.14,
        driftSpeedX: 1.2 + rng.nextDouble() * 2.0,
        driftAmplitude: 14.0 + rng.nextDouble() * 22.0,
        size: isBright ? 2.6 : 1.4 + rng.nextDouble() * 1.4,
        baseAlpha: isBright ? 0.85 : 0.45 + rng.nextDouble() * 0.35,
        color: eColor,
        phase: rng.nextDouble() * 2 * math.pi,
      );
    });

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _ticker.addListener(_onFrame);

    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runFullSiegeChoreography();
      });
    }
  }

  void _onFrame() {
    final double now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (_lastTick == 0.0) _lastTick = now;
    final double dt = (now - _lastTick).clamp(0.001, 0.05);
    _lastTick = now;
    _animTime += dt;

    // 1. Update VFX coordinator
    coordinator.update(dt);

    // 2. Update Catapult Projectiles
    for (int i = _projectiles.length - 1; i >= 0; i--) {
      final CatapultProjectile p = _projectiles[i];
      p.update(dt);
      if (p.isFinished) {
        _onCatapultImpact(p);
        _projectiles.removeAt(i);
      }
    }

    // 3. Update Ambient Battlefield Embers
    for (final BattlefieldAmbientEmber ember in _ambientEmbers) {
      ember.update(dt);
    }

    // 4. Prune Expired Burning Oil Decals
    _burningOilDecals.removeWhere((BurningOilDecal d) => d.isExpired);
  }

  void _onCatapultImpact(CatapultProjectile p) {
    if (!mounted) return;

    setState(() {
      totalDamageDealt += p.damage;
      gateIntegrity = math.max(0.0, gateIntegrity - 0.28);
    });

    // Execute impact explosion on coordinator
    coordinator.executeCatapultBoulderStrike(
      impactPoint: p.target,
      damage: p.damage,
      isCritical: p.isCritical,
    );

    // Spawn viscous burning oil decal at boulder strike point
    _spawnBurningOilPool(p.target);
  }

  void _spawnBurningOilPool(Offset groundPoint) {
    final BurningOilDecal oilDecal = BurningOilDecal(
      id: 'oil_${DateTime.now().microsecondsSinceEpoch}',
      position: groundPoint + Offset(math.Random().nextDouble() * 24 - 12, 12),
      radiusX: 36.0 + math.Random().nextDouble() * 16.0,
      radiusY: 18.0 + math.Random().nextDouble() * 10.0,
      rotation: math.Random().nextDouble() * math.pi,
    );
    _burningOilDecals.add(oilDecal);
    if (_burningOilDecals.length > 7) {
      _burningOilDecals.removeAt(0);
    }
  }

  @override
  void dispose() {
    _ticker.removeListener(_onFrame);
    _ticker.dispose();
    coordinator.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Automated 3-Phase Siege Assault Choreography
  // ---------------------------------------------------------------------------
  Future<void> _runFullSiegeChoreography() async {
    if (!mounted) return;

    // Phase 1: Heavy Catapult Ballistic Artillery Barrage (0-2s)
    setState(() {
      currentPhaseText = '1. AŞAMA: Ağır Mancınık Ateşi!';
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _launchCatapultAssault();

    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    _launchCatapultAssault();

    // Phase 2: Battering Ram & Boiling Oil Rampart Defense (2-4s)
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      currentPhaseText = '2. AŞAMA: Koçbaşı ile Kapı Yarma & Yanar Yağ!';
    });
    _smashGate();
    _pourBoilingOilDefense();

    // Phase 3: Commander Duel Clash & Fortress Breach (4-6s)
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      currentPhaseText = '3. AŞAMA: Baş Komutan Düellosu!';
    });
    _clashCommanders();

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      isSiegeResolved = true;
      currentPhaseText = widget.isVictory
          ? 'KALE KAPISI KIRILDI — ZAFER!'
          : 'SALDIRI PÜSKÜRTÜLDÜ — SAVUNMA DAYANDI!';
    });

    widget.onSequenceCompleted?.call();
  }

  // ---------------------------------------------------------------------------
  // Tactical Action Handlers
  // ---------------------------------------------------------------------------
  void _launchCatapultAssault() {
    final Size size = Size(MediaQuery.of(context).size.width, widget.height);
    final Offset launchOrigin = Offset(size.width * 0.18, widget.height * 0.82);
    final Offset gateTarget = Offset(
      size.width * 0.5 + (math.Random().nextDouble() * 36 - 18),
      widget.height * 0.38,
    );

    final int dmg = (widget.attackPower * 0.35 + (widget.pointsGained * 2)).round();

    final CatapultProjectile projectile = CatapultProjectile(
      id: 'proj_${DateTime.now().microsecondsSinceEpoch}',
      start: launchOrigin,
      target: gateTarget,
      arcHeight: 125.0 + math.Random().nextDouble() * 25.0,
      duration: 0.72,
      damage: dmg,
      isCritical: true,
    );

    setState(() {
      _projectiles.add(projectile);
    });
  }

  void _smashGate() {
    final Size size = Size(MediaQuery.of(context).size.width, widget.height);
    final Offset gatePoint = Offset(size.width * 0.5, size.height * 0.44);

    final int dmg = (widget.attackPower * 0.45).round();
    setState(() {
      totalDamageDealt += dmg;
      gateIntegrity = math.max(0.0, gateIntegrity - 0.40);
    });

    coordinator.executeGateSmashStrike(
      gateCenter: gatePoint,
      damage: dmg,
    );
  }

  void _pourBoilingOilDefense() {
    final Size size = Size(MediaQuery.of(context).size.width, widget.height);
    final Offset rampartOilDrop = Offset(size.width * 0.5, size.height * 0.48);

    // Spawn 2 overlapping spreading pools of boiling pitch
    _spawnBurningOilPool(rampartOilDrop + const Offset(-28, 8));
    _spawnBurningOilPool(rampartOilDrop + const Offset(28, 12));

    coordinator.triggerCatapultShake();
    coordinator.triggerRimFlash(
      tint: const Color(0xFFFF6D00),
      intensity: 0.8,
    );
  }

  void _clashCommanders() {
    final Size size = Size(MediaQuery.of(context).size.width, widget.height);
    final Offset clashPoint = Offset(size.width * 0.5, size.height * 0.62);

    final int atkDmg = (widget.attackPower * 0.6).round();
    final int defDmg = (widget.defensePower * 0.5).round();

    setState(() {
      totalDamageDealt += atkDmg;
      if (widget.isVictory) {
        gateIntegrity = 0.0;
      } else {
        attackerMorale = math.max(0.1, attackerMorale - 0.5);
      }
    });

    coordinator.executeCommanderDuelClash(
      clashPoint: clashPoint,
      attackerDamage: atkDmg,
      defenderDamage: defDmg,
      isElyosAttacker: widget.isElyosAttacker,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: coordinator,
      builder: (BuildContext context, Widget? child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0D15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: coordinator.rimFlashIntensity > 0.0
                    ? coordinator.rimFlashColor.withValues(alpha: coordinator.rimFlashIntensity)
                    : const Color(0xFF232838),
                width: 1.5 + coordinator.rimFlashIntensity * 2.0,
              ),
              boxShadow: <BoxShadow>[
                if (coordinator.rimFlashIntensity > 0.0)
                  BoxShadow(
                    color: coordinator.rimFlashColor.withValues(alpha: coordinator.rimFlashIntensity * 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                // 1. Camera Shake Transform on the Battleground
                Transform.translate(
                  offset: coordinator.shakeOffset,
                  child: Transform.rotate(
                    angle: coordinator.shakeRotation,
                    child: Stack(
                      children: <Widget>[
                        // Layer 1.1: Volumetric Atmospheric Smoke & Distant Mountains
                        Positioned.fill(
                          child: CustomPaint(
                            painter: BattlefieldAtmospherePainter(animTime: _animTime),
                          ),
                        ),

                        // Layer 1.2: Viscous Burning Oil & Boiling Pitch Decals
                        Positioned.fill(
                          child: CustomPaint(
                            painter: BurningOilDecalsPainter(
                              decals: _burningOilDecals,
                              animTime: _animTime,
                            ),
                          ),
                        ),

                        // Layer 1.3: Ground & Wall Decals (Craters, Scorches, Fissures)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: SiegeDecalsPainter(decals: coordinator.decals),
                          ),
                        ),

                        // Layer 1.4: Complete Fortress Ramparts & Gate Architecture
                        Positioned.fill(
                          child: CustomPaint(
                            painter: FortressRampartPainter(
                              gateIntegrity: gateIntegrity,
                              animTime: _animTime,
                              isElyosAttacker: widget.isElyosAttacker,
                              isVictory: widget.isVictory,
                            ),
                          ),
                        ),

                        // Layer 1.5: Defender Battlement Troops
                        Positioned(
                          top: widget.height * 0.15,
                          left: 0,
                          right: 0,
                          child: _buildDefenderBattlementRow(),
                        ),

                        // Layer 1.6: Attacking Engines & Troops
                        Positioned(
                          bottom: 44,
                          left: 0,
                          right: 0,
                          child: _buildAttackerVanguardAndCatapult(),
                        ),

                        // Layer 1.7: Weapon Ribbon Trails
                        Positioned.fill(
                          child: CustomPaint(
                            painter: SiegeWeaponTrailsPainter(trails: coordinator.weaponTrails),
                          ),
                        ),

                        // Layer 1.8: In-Flight Ballistic Catapult Projectiles & Comets
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CatapultTrajectoryPainter(
                              projectiles: _projectiles,
                              animTime: _animTime,
                            ),
                          ),
                        ),

                        // Layer 1.9: Siege Particles (Debris, Sparks, Plumes)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: SiegeParticlesPainter(particles: coordinator.particles),
                          ),
                        ),

                        // Layer 1.10: Atmospheric Drifting Embers & Ash Specks
                        Positioned.fill(
                          child: CustomPaint(
                            painter: BattlefieldAmbientEmbersPainter(
                              embers: _ambientEmbers,
                              animTime: _animTime,
                            ),
                          ),
                        ),

                        // Layer 1.11: Floating Damage Numbers
                        Positioned.fill(
                          child: _buildFloatingDamageNumbersLayer(),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. HUD: Phase Header, Gate Health, & Duel Control Deck
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: _buildSiegeHudHeader(),
                ),

                // 3. Thumb-Friendly Interactive Tactical Action Bar
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: _buildTacticalActionBar(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefenderBattlementRow() {
    return Transform.translate(
      offset: coordinator.defenderTroopFlinch.offset,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _buildUnitAvatar(
            label: 'Okçular',
            isDefender: true,
            icon: Icons.architecture,
            color: const Color(0xFFFF5252),
          ),
          const SizedBox(width: 16),
          _buildUnitAvatar(
            label: widget.defenderGuildName,
            isDefender: true,
            icon: Icons.shield,
            color: const Color(0xFFFF1744),
            isCommander: true,
          ),
          const SizedBox(width: 16),
          _buildUnitAvatar(
            label: 'Muhafızlar',
            isDefender: true,
            icon: Icons.group,
            color: const Color(0xFFFF5252),
          ),
        ],
      ),
    );
  }

  Widget _buildAttackerVanguardAndCatapult() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        // Catapult Siege Engine
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF9800), width: 1.2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x40FF9800), blurRadius: 6),
                ],
              ),
              child: const Icon(Icons.rocket_launch, size: 18, color: Color(0xFFFF9800)),
            ),
            const SizedBox(height: 2),
            const Text(
              'Mancınık',
              style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ],
        ),

        // Attacking Vanguard Commander
        Transform.translate(
          offset: coordinator.attackerCommanderFlinch.offset,
          child: _buildUnitAvatar(
            label: widget.attackerGuildName,
            isDefender: false,
            icon: Icons.military_tech,
            color: widget.isElyosAttacker ? const Color(0xFF00E5FF) : const Color(0xFFFF2A4D),
            isCommander: true,
          ),
        ),

        // Battering Ram Engine
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF5722), width: 1.2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x40FF5722), blurRadius: 6),
                ],
              ),
              child: const Icon(Icons.hardware, size: 18, color: Color(0xFFFF5722)),
            ),
            const SizedBox(height: 2),
            const Text(
              'Koçbaşı',
              style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnitAvatar({
    required String label,
    required bool isDefender,
    required IconData icon,
    required Color color,
    bool isCommander = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: isCommander ? 34 : 26,
          height: isCommander ? 34 : 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.25),
            border: Border.all(
              color: color,
              width: isCommander ? 2.0 : 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, size: isCommander ? 18 : 13, color: color),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingDamageNumbersLayer() {
    return Stack(
      children: coordinator.damageNumbers.map((SiegeDamageNumber dmg) {
        return Positioned(
          left: dmg.position.dx,
          top: dmg.position.dy,
          child: Opacity(
            opacity: dmg.opacity,
            child: Transform.scale(
              scale: dmg.scale,
              child: Text(
                dmg.text,
                style: GoogleFonts.cinzel(
                  fontSize: dmg.isCritical ? 17 : 13,
                  fontWeight: FontWeight.w900,
                  color: dmg.color,
                  shadows: <Shadow>[
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.9),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                    Shadow(
                      color: dmg.color.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSiegeHudHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black54, blurRadius: 8),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              FactionCrestWidget(
                faction: widget.isElyosAttacker ? FactionType.elyos : FactionType.asmodian,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentPhaseText,
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFFFFD54F),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'Top. Hasar: $totalDamageDealt',
                style: const TextStyle(
                  color: Color(0xFFFF5252),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Fortress Gate Durability Progress Bar with glowing indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: gateIntegrity,
              minHeight: 5,
              backgroundColor: const Color(0xFF212533),
              valueColor: AlwaysStoppedAnimation<Color>(
                gateIntegrity > 0.4
                    ? const Color(0xFF00E5FF)
                    : (gateIntegrity > 0.15 ? const Color(0xFFFF9800) : const Color(0xFFFF1744)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalActionBar() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _TacticalButton(
            label: 'Mancınık',
            icon: Icons.rocket_launch,
            color: const Color(0xFFFF9800),
            onPressed: _launchCatapultAssault,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _TacticalButton(
            label: 'Koçbaşı',
            icon: Icons.hardware,
            color: const Color(0xFFFF5722),
            onPressed: _smashGate,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _TacticalButton(
            label: 'Yanar Yağ',
            icon: Icons.local_fire_department,
            color: const Color(0xFFFF1744),
            onPressed: _pourBoilingOilDefense,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _TacticalButton(
            label: 'Düello',
            icon: Icons.sports_kabaddi,
            color: const Color(0xFF00E5FF),
            onPressed: _clashCommanders,
          ),
        ),
      ],
    );
  }
}

class _TacticalButton extends StatelessWidget {
  const _TacticalButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF141724),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          side: BorderSide(color: color.withValues(alpha: 0.55), width: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
