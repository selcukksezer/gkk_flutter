import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/gpu_shader_service.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../models/moradon_models.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/moradon_hub_provider.dart';

/// Resolves the live Capital Square atmosphere from user choice or automatic GKK schedule.
MoradonAtmospherePhase resolveLiveAtmospherePhase({
  required MoradonAtmosphereChoice choice,
  required bool nightMarketActive,
  required bool siegeLive,
}) {
  switch (choice) {
    case MoradonAtmosphereChoice.twilight:
      return MoradonAtmospherePhase.twilight;
    case MoradonAtmosphereChoice.nightMarket:
      return MoradonAtmospherePhase.nightMarket;
    case MoradonAtmosphereChoice.siegeStorm:
      return MoradonAtmospherePhase.siegeStorm;
    case MoradonAtmosphereChoice.bloodMoon:
      return MoradonAtmospherePhase.bloodMoon;
    case MoradonAtmosphereChoice.auto:
      if (nightMarketActive) return MoradonAtmospherePhase.nightMarket;
      if (siegeLive) return MoradonAtmospherePhase.siegeStorm;
      final DateTime trNow =
          DateTime.now().toUtc().add(const Duration(hours: 3));
      final int h = trNow.hour;
      if (h == 0) {
        return MoradonAtmospherePhase.bloodMoon;
      }
      if (h >= 20 && h < 22) {
        return MoradonAtmospherePhase.nightMarket;
      }
      if (h == 19 || h >= 22) {
        return MoradonAtmospherePhase.siegeStorm;
      }
      return MoradonAtmospherePhase.twilight;
  }
}

String atmosphereChoiceBadgeLabel(
  MoradonAtmosphereChoice choice,
  MoradonAtmospherePhase resolved,
) {
  final String phaseShort = switch (resolved) {
    MoradonAtmospherePhase.twilight => 'Alacakaranlık',
    MoradonAtmospherePhase.nightMarket => 'Gece Pazarı',
    MoradonAtmospherePhase.siegeStorm => 'Kuşatma Göğü',
    MoradonAtmospherePhase.bloodMoon => 'Kanlı Ay',
  };
  return choice == MoradonAtmosphereChoice.auto
      ? '$phaseShort (Oto)'
      : phaseShort;
}

IconData atmospherePhaseIcon(MoradonAtmospherePhase phase) {
  return switch (phase) {
    MoradonAtmospherePhase.twilight => Icons.wb_twilight_rounded,
    MoradonAtmospherePhase.nightMarket => Icons.nights_stay_rounded,
    MoradonAtmospherePhase.siegeStorm => Icons.thunderstorm_rounded,
    MoradonAtmospherePhase.bloodMoon => Icons.brightness_3_rounded,
  };
}

Color atmospherePhaseAccent(MoradonAtmospherePhase phase) {
  return switch (phase) {
    MoradonAtmospherePhase.twilight => const Color(0xFFFBBF24),
    MoradonAtmospherePhase.nightMarket => const Color(0xFFC084FC),
    MoradonAtmospherePhase.siegeStorm => const Color(0xFFF87171),
    MoradonAtmospherePhase.bloodMoon => const Color(0xFFFB7185),
  };
}

/// Resolves local player's equipped GKK weapon visual & HUD label from real inventory.
(MoradonWeaponVisual, String) resolveEquippedWeaponSpec({
  required InventoryState inventoryState,
  required String classKey,
  required int glowLevel,
}) {
  InventoryItem? equippedWeapon = inventoryState.equippedItems['weapon'];
  if (equippedWeapon == null) {
    for (final InventoryItem? candidate
        in inventoryState.equippedItems.values) {
      if (candidate != null && candidate.itemType == ItemType.weapon) {
        equippedWeapon = candidate;
        break;
      }
    }
  }

  if (equippedWeapon != null) {
    final String lower =
        '${equippedWeapon.itemId} ${equippedWeapon.name}'.toLowerCase();
    final int enh = equippedWeapon.enhancementLevel;
    final String prefix = enh > 0 ? '+$enh ' : '';
    final String label = '$prefix${equippedWeapon.name}';

    if (lower.contains('fang') ||
        lower.contains('dagger') ||
        lower.contains('hançer') ||
        lower.contains('bicak') ||
        lower.contains('shiv')) {
      return (MoradonWeaponVisual.twilightFang, label);
    }
    if (lower.contains('halberd') ||
        lower.contains('teber') ||
        lower.contains('mızrak') ||
        lower.contains('bardiche') ||
        lower.contains('spear')) {
      return (MoradonWeaponVisual.imperialHalberd, label);
    }
    if (lower.contains('axe') ||
        lower.contains('balta') ||
        lower.contains('scar') ||
        lower.contains('maul') ||
        lower.contains('chopper')) {
      return (MoradonWeaponVisual.crimsonAxe, label);
    }
    if (lower.contains('staff') ||
        lower.contains('asa') ||
        lower.contains('wand') ||
        lower.contains('rod') ||
        lower.contains('aether')) {
      return (MoradonWeaponVisual.aetherStaff, label);
    }
    return (MoradonWeaponVisual.illusionSabre, label);
  }

  return switch (classKey) {
    'golge' => (
        MoradonWeaponVisual.twilightFang,
        '+$glowLevel Twilight Fang',
      ),
    'simyaci' => (
        MoradonWeaponVisual.aetherStaff,
        '+$glowLevel Aether İksiri',
      ),
    _ => (
        MoradonWeaponVisual.illusionSabre,
        '+$glowLevel Illusion Sabre',
      ),
  };
}

MoradonPetVisual resolveHeroPetVisual({
  required String classKey,
  required int level,
  required int totalPower,
}) {
  // Keep hero silhouette clean; do not force an unequipped shoulder sticker pet.
  return MoradonPetVisual.none;
}

/// Pure soft radial-gradient additive weapon enchantment sheen & micro-embers aligned to each
/// character sprite's hand-painted weapon (zero harsh lines, zero MaskFilter platform artifacts).
void drawIsometricWeapon({
  required Canvas canvas,
  required Size size,
  required MoradonWeaponVisual weapon,
  required Color glowColor,
  required int glowLevel,
  required bool isMoving,
  required bool facingBack,
  required double walkPhase,
  required double idlePhase,
}) {
  if (weapon == MoradonWeaponVisual.none || glowLevel < 7) {
    return;
  }
  if (isMoving) {
    final Offset strideGlow = Offset(size.width * 0.52, size.height * 0.56);
    final Rect r = Rect.fromCenter(center: strideGlow, width: 28, height: 28);
    canvas.drawOval(
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[
            glowColor.withValues(alpha: glowLevel >= 9 ? 0.22 : 0.12),
            Colors.transparent,
          ],
        ).createShader(r),
    );
    return;
  }

  final double w = size.width;
  final double h = size.height;
  final double pulse = 0.5 + 0.5 * math.sin(idlePhase * math.pi * 4);
  final double intensity = (glowLevel >= 10
          ? 0.34
          : (glowLevel == 9 ? 0.26 : (glowLevel == 8 ? 0.20 : 0.14))) +
      pulse * 0.06;

  void drawBladeBloom(Offset start, Offset end, double radius) {
    // Smooth overlapping radial light pools along the painted weapon blade
    const int samples = 5;
    for (int s = 0; s < samples; s++) {
      final double f = s / (samples - 1);
      final Offset pt = Offset.lerp(start, end, f)!;
      final double taper = 1.0 - (f - 0.45).abs() * 0.55;
      final double r = radius * taper;
      final Rect glowRect = Rect.fromCenter(
        center: pt,
        width: r * 2.4,
        height: r * 2.4,
      );
      canvas.drawOval(
        glowRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFFEF3C7).withValues(alpha: intensity * 0.42),
              glowColor.withValues(alpha: intensity * 0.55),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.42, 1.0],
          ).createShader(glowRect),
      );
    }

    // Subtle rising forge micro-embers off the blade
    final Paint sparkPaint = Paint()..blendMode = BlendMode.plus;
    for (int i = 0; i < 3; i++) {
      final double t = (idlePhase * 1.8 + i * 0.33) % 1.0;
      final Offset base =
          Offset.lerp(start, end, (0.22 + i * 0.32).clamp(0.0, 1.0))!;
      final Offset pos = Offset(
        base.dx + math.sin((t + i) * math.pi * 2) * 2.2,
        base.dy - t * 9.0,
      );
      sparkPaint.color = const Color(0xFFFDE68A)
          .withValues(alpha: (1.0 - t) * intensity * 0.90);
      canvas.drawCircle(pos, 1.15 * (1.0 - t * 0.35), sparkPaint);
    }
  }

  switch (weapon) {
    case MoradonWeaponVisual.illusionSabre:
    case MoradonWeaponVisual.imperialHalberd:
    case MoradonWeaponVisual.crimsonAxe:
      // Aligns strictly with Warrior's painted broadsword from grip (0.39w, 0.53h) to tip (0.67w, 0.74h)
      drawBladeBloom(
        Offset(w * 0.40, h * 0.54),
        Offset(w * 0.67, h * 0.74),
        4.2,
      );

    case MoradonWeaponVisual.twilightFang:
      // Aligns strictly with Gölge assassin's twin painted curved daggers
      drawBladeBloom(
        Offset(w * 0.33, h * 0.50),
        Offset(w * 0.26, h * 0.37),
        3.4,
      );
      drawBladeBloom(
        Offset(w * 0.65, h * 0.43),
        Offset(w * 0.57, h * 0.34),
        3.4,
      );

    case MoradonWeaponVisual.aetherStaff:
      // Aligns strictly with Simyacı's painted glowing alchemical flask (0.70w, 0.35h) & arcane palm
      final Offset vial = Offset(w * 0.70, h * 0.35);
      final Rect vialGlow = Rect.fromCenter(center: vial, width: 28, height: 28);
      canvas.drawOval(
        vialGlow,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: intensity * 0.65),
              glowColor.withValues(alpha: intensity * 0.75),
              Colors.transparent,
            ],
          ).createShader(vialGlow),
      );
      final Offset rightHand = Offset(w * 0.37, h * 0.54);
      final Rect handGlow =
          Rect.fromCenter(center: rightHand, width: 20, height: 20);
      canvas.drawOval(
        handGlow,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              glowColor.withValues(alpha: intensity * 0.55),
              Colors.transparent,
            ],
          ).createShader(handGlow),
      );

    case MoradonWeaponVisual.none:
      break;
  }
}

/// Draws hand-painted 1024px-sourced floating magical companion sprite beside character shoulder.
void drawIsometricCompanionPet({
  required Canvas canvas,
  required Size size,
  required MoradonPetVisual pet,
  required Map<MoradonPetVisual, ui.Image> petImages,
  required bool facingRight,
  required double idlePhase,
  required double orbitPhase,
}) {
  if (pet == MoradonPetVisual.none) return;
  final ui.Image? img = petImages[pet];
  if (img == null) return;

  final double trailSide = facingRight ? -1.0 : 1.0;
  final double bobY = math.sin(idlePhase * math.pi * 2) * 4.5;
  final double swayX = math.cos(orbitPhase * math.pi * 2) * 3.0;
  final Offset petCenter = Offset(
    size.width * 0.5 + trailSide * 38.0 + swayX,
    size.height * 0.38 + bobY,
  );
  final double groundY = size.height - 7.0;

  // Cobblestone contact shadow under hovering companion
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(petCenter.dx, groundY),
      width: 19.0,
      height: 6.5,
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.38),
  );

  final Color auraColor = switch (pet) {
    MoradonPetVisual.solarPhoenix => const Color(0xFFF97316),
    MoradonPetVisual.shadowRaven => const Color(0xFFA855F7),
    MoradonPetVisual.arcaneWisp => const Color(0xFF38BDF8),
    MoradonPetVisual.royalGriffin => const Color(0xFFFBBF24),
    MoradonPetVisual.none => Colors.transparent,
  };

  // Soft additive magical aura behind painted companion sprite
  final Rect auraRect =
      Rect.fromCenter(center: petCenter, width: 38, height: 38);
  canvas.drawOval(
    auraRect,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: <Color>[
          auraColor.withValues(alpha: 0.36),
          Colors.transparent,
        ],
      ).createShader(auraRect),
  );

  // Render crisp painted companion sprite with gentle wing-breath scale
  const double dstW = 34.0;
  const double dstH = 38.0;
  final double wingPulse = 1.0 + 0.045 * math.sin(idlePhase * math.pi * 6);

  canvas.save();
  canvas.translate(petCenter.dx, petCenter.dy);
  if (!facingRight) {
    canvas.scale(-1.0, 1.0);
  }
  canvas.scale(wingPulse, 2.0 - wingPulse * 0.98);
  canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromCenter(center: Offset.zero, width: dstW, height: dstH),
    Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true,
  );
  canvas.restore();
}

/// Brings the 4K Dark-Gothic `citadel_dungeon_v9.jpg` (6400 x 3600) architecture alive:
/// Forge furnace fire & chimney smoke, Northern Chained Rift vortex, Central Obsidian Fountain ripples,
/// and flickering perimeter wall torches & war-gate braziers — strictly frustum-culled to camera viewport!
class CitadelArchitecturalVfxPainter extends CustomPainter {
  final double phase;
  final double skyPhase;
  final Rect? frustum;

  const CitadelArchitecturalVfxPainter({
    required this.phase,
    required this.skyPhase,
    this.frustum,
  });

  bool _isVisible(Offset pt, [double pad = 260.0]) {
    final Rect? f = frustum;
    if (f == null) return true;
    return pt.dx >= f.left - pad &&
        pt.dx <= f.right + pad &&
        pt.dy >= f.top - pad &&
        pt.dy <= f.bottom + pad;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double flicker =
        0.5 + 0.5 * math.sin(phase * math.pi * 6 + math.cos(phase * math.pi * 4));
    final Paint plusPaint = Paint()..blendMode = BlendMode.plus;

    // 1. WEST HELLFIRE FORGE (Furnace Mouth: 475,1690 | Molten Crucible: 970,1595 | Runic Anvil: 1140,1875)
    if (_isVisible(const Offset(820, 1720), 460.0)) {
      for (final (Offset pos, double r, Color c)
          in const <(Offset, double, Color)>[
        (Offset(475, 1690), 215.0, Color(0xFFFF6B00)),
        (Offset(970, 1595), 145.0, Color(0xFFF97316)),
        (Offset(1140, 1875), 115.0, Color(0xFFFB923C)),
      ]) {
        if (!_isVisible(pos, r + 40.0)) continue;
        final Rect rect =
            Rect.fromCenter(center: pos, width: r * 2.1, height: r * 1.55);
        canvas.drawOval(
          rect,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: <Color>[
                c.withValues(alpha: 0.22 + flicker * 0.08),
                c.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ).createShader(rect),
        );
      }

      // Rising forge embers over roaring furnace mouth & molten crucible
      for (int i = 0; i < 12; i++) {
        final double t = (phase * 1.8 + i / 12.0) % 1.0;
        final Offset base = i.isEven
            ? const Offset(475, 1685)
            : const Offset(970, 1590);
        final double ex = base.dx + math.sin((t * 2 + i) * math.pi * 2) * 24.0;
        final double ey = base.dy - t * 115.0;
        plusPaint.color = const Color(0xFFFDE047)
            .withValues(alpha: (1.0 - t) * 0.78);
        canvas.drawCircle(Offset(ex, ey), 2.3 * (1.0 - t * 0.4), plusPaint);
      }
    }

    // Zero-blur radial smoke puffs rising out of West Forge Stone Chimney (280, 770)
    if (_isVisible(const Offset(280, 650), 260.0)) {
      for (int s = 0; s < 5; s++) {
        final double st = (skyPhase * 4.0 + s / 5.0) % 1.0;
        final double sx =
            280.0 - st * 36.0 + math.sin((st + s) * math.pi * 2) * 18.0;
        final double sy = 770.0 - st * 245.0;
        final double sr = 26.0 + st * 46.0;
        final Rect smokeRect =
            Rect.fromCircle(center: Offset(sx, sy), radius: sr);
        canvas.drawOval(
          smokeRect,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                const Color(0xFFCBD5E1)
                    .withValues(alpha: math.sin(st * math.pi) * 0.14),
                Colors.transparent,
              ],
            ).createShader(smokeRect),
        );
      }
    }

    // 2. NORTHERN CHAINED DUNGEON RIFT PORTAL (Vortex Center: 3205, 515)
    const Offset portalCenter = Offset(3205, 515);
    if (_isVisible(portalCenter, 260.0)) {
      final Rect portalHalo =
          Rect.fromCenter(center: portalCenter, width: 410, height: 390);
      canvas.drawOval(
        portalHalo,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFF67E8F9).withValues(alpha: 0.20 + flicker * 0.06),
              const Color(0xFF0284C7).withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ).createShader(portalHalo),
      );
      canvas.save();
      canvas.translate(portalCenter.dx, portalCenter.dy);
      canvas.rotate(phase * math.pi * 2);
      final Paint arcPaint = Paint()
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFA5F3FC).withValues(alpha: 0.36)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.6;
      for (int a = 0; a < 3; a++) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset.zero, width: 165, height: 185),
          a * (math.pi * 2 / 3),
          math.pi * 0.45,
          false,
          arcPaint,
        );
      }
      canvas.restore();
    }

    // 3. CENTRAL OBSIDIAN ARCANE FOUNTAIN WATER SHIMMER & GLSL CAUSTICS (Pool Center: 3200, 2055)
    const Offset poolCenter = Offset(3200, 2055);
    if (_isVisible(poolCenter, 280.0)) {
      final Rect waterGlow =
          Rect.fromCenter(center: poolCenter, width: 440, height: 270);
      final ui.FragmentShader? waterShader =
          GpuShaderService.instance.createWaterCausticsShader(
        size: waterGlow.size,
        timeSec: (skyPhase * 24.0) + (phase * 4.0),
        intensity: 1.05,
      );
      if (waterShader != null) {
        canvas.save();
        canvas.translate(waterGlow.left, waterGlow.top);
        canvas.drawOval(
          Offset.zero & waterGlow.size,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = waterShader,
        );
        canvas.restore();
      }
      canvas.drawOval(
        waterGlow,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFF22D3EE).withValues(alpha: 0.16 + flicker * 0.05),
              Colors.transparent,
            ],
          ).createShader(waterGlow),
      );
      for (int r = 0; r < 3; r++) {
        final double rt = (phase * 1.5 + r / 3.0) % 1.0;
        canvas.drawOval(
          Rect.fromCenter(
            center: poolCenter,
            width: 145.0 + rt * 255.0,
            height: 86.0 + rt * 148.0,
          ),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = const Color(0xFFA5F3FC)
                .withValues(alpha: (1.0 - rt) * 0.24)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      for (int d = 0; d < 10; d++) {
        final double dt = (phase * 2.6 + d / 10.0) % 1.0;
        final double ang = (d / 10.0) * math.pi * 2;
        final double dx = poolCenter.dx + math.cos(ang) * (58.0 + dt * 58.0);
        final double dy =
            (poolCenter.dy - 54.0) + math.sin(ang) * 28.0 + dt * 62.0;
        plusPaint.color =
            const Color(0xFFE0F2FE).withValues(alpha: (1.0 - dt) * 0.55);
        canvas.drawCircle(Offset(dx, dy), 1.8, plusPaint);
      }
    }

    // 4. PAINTED PERIMETER WALL TORCHES & STANDING FIRE BRAZIERS
    const List<Offset> braziers = <Offset>[
      Offset(2240, 675),  // North-West Portal Approach Brazier
      Offset(4595, 700),  // North-East Portal Approach Brazier
      Offset(5285, 1000), // NE War Gate Right Giant Brazier
      Offset(1395, 1085), // NW Cathedral Steps Brazier
      Offset(1190, 905),  // NW Cathedral Left Torch
      Offset(1725, 625),  // NW Cathedral Right Torch
      Offset(1358, 2400), // SW Guard Bastion Tower Brazier
      Offset(2190, 2909), // SW Courtyard Brazier
    ];
    for (int b = 0; b < braziers.length; b++) {
      final Offset bp = braziers[b];
      if (!_isVisible(bp, 180.0)) continue;
      final double localFlicker =
          0.5 + 0.5 * math.sin((phase * 3.0 + b * 0.41) * math.pi * 2);
      final Rect groundBounce = Rect.fromCenter(
        center: Offset(bp.dx, bp.dy + 65.0),
        width: 240,
        height: 140,
      );
      canvas.drawOval(
        groundBounce,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFF59E0B)
                  .withValues(alpha: 0.12 + localFlicker * 0.05),
              Colors.transparent,
            ],
          ).createShader(groundBounce),
      );
      final Rect bowlHalo =
          Rect.fromCenter(center: bp, width: 72, height: 72);
      canvas.drawOval(
        bowlHalo,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFFEF08A)
                  .withValues(alpha: 0.34 + localFlicker * 0.14),
              const Color(0xFFF97316).withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(bowlHalo),
      );
      for (int sp = 0; sp < 2; sp++) {
        final double spt = (phase * 2.2 + b * 0.27 + sp * 0.5) % 1.0;
        final double spx = bp.dx + math.sin((spt + b) * math.pi * 3) * 8.0;
        final double spy = bp.dy - 12.0 - spt * 52.0;
        plusPaint.color = const Color(0xFFFDE047)
            .withValues(alpha: (1.0 - spt) * 0.72);
        canvas.drawCircle(Offset(spx, spy), 1.6, plusPaint);
      }
    }

    // Warm golden gothic tavern stained-glass window spill onto SE cobblestones
    const Offset tavernPos = Offset(5460, 3040);
    if (_isVisible(tavernPos, 280.0)) {
      final Rect tavernSpill = Rect.fromCenter(
        center: tavernPos,
        width: 520,
        height: 250,
      );
      canvas.drawOval(
        tavernSpill,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFFBBF24).withValues(alpha: 0.16 + flicker * 0.04),
              Colors.transparent,
            ],
          ).createShader(tavernSpill),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CitadelArchitecturalVfxPainter oldDelegate) =>
      oldDelegate.frustum != frustum ||
      (oldDelegate.phase - phase).abs() > 0.014 ||
      (oldDelegate.skyPhase - skyPhase).abs() > 0.004;
}

/// Viewport Screen-Space Dynamic Sky Grading, Night Market Lanterns, Siege Rain & Blood Moon.
/// Runs in `viewW x viewH` screen space (~1 MP) instead of `6400 x 3600` world space (23 MP)!
class MoradonDynamicWeatherPainter extends CustomPainter {
  final MoradonAtmospherePhase atmosphere;
  final double phase;
  final double skyPhase;

  const MoradonDynamicWeatherPainter({
    required this.atmosphere,
    required this.phase,
    required this.skyPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 1 || size.height <= 1) return;
    final Rect fullRect = Offset.zero & size;

    switch (atmosphere) {
      case MoradonAtmospherePhase.twilight:
        return;

      case MoradonAtmospherePhase.nightMarket:
        canvas.drawRect(
          fullRect,
          Paint()..color = const Color(0x38060418),
        );

        final Paint glowPaint = Paint()..blendMode = BlendMode.plus;
        final Paint corePaint = Paint();
        for (int i = 0; i < 14; i++) {
          final double t = (skyPhase * 2.0 + i / 14.0) % 1.0;
          final double baseX = ((i * 197) % 1000) / 1000.0 * size.width;
          final double sway = math.sin((t * 2.0 + i) * math.pi * 2) * 26.0;
          final double lx = baseX + sway;
          final double ly = size.height * (1.05 - t * 1.10);
          final double alpha =
              (math.sin(t * math.pi)).clamp(0.0, 1.0) * 0.82;
          glowPaint.color =
              const Color(0xFFF59E0B).withValues(alpha: alpha * 0.42);
          canvas.drawCircle(Offset(lx, ly), 9.0, glowPaint);
          corePaint.color = const Color(0xFFFEF08A).withValues(alpha: alpha);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(lx, ly), width: 5.5, height: 7.5),
              const Radius.circular(1.8),
            ),
            corePaint,
          );
        }

      case MoradonAtmospherePhase.siegeStorm:
        canvas.drawRect(
          fullRect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x52450A0A),
                Color(0x241E1B4B),
                Color(0x14090D16),
              ],
              stops: <double>[0.0, 0.48, 1.0],
            ).createShader(fullRect),
        );

        final Paint rainPaint = Paint()
          ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.22)
          ..strokeWidth = 1.15
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < 48; i++) {
          final double progress = (phase * 3.0 + (i * 0.137)) % 1.0;
          final double startX = ((i * 577) % 1000) / 1000.0 * (size.width + 80);
          final double startY = ((i * 383) % 1000) / 1000.0 * size.height;
          final double rx = (startX + progress * 160.0) % (size.width + 80.0);
          final double ry = (startY + progress * size.height) % size.height;
          canvas.drawLine(
            Offset(rx, ry),
            Offset(rx - 10.0, ry - 28.0),
            rainPaint,
          );
        }

        final double boltCycle = (skyPhase * 4.0) % 1.0;
        if (boltCycle < 0.085) {
          final double flash = 1.0 - (boltCycle / 0.085);
          canvas.drawRect(
            fullRect,
            Paint()
              ..blendMode = BlendMode.plus
              ..color = const Color(0xFFFECACA).withValues(alpha: flash * 0.10),
          );
          final double bx = size.width * (boltCycle < 0.042 ? 0.36 : 0.68);
          final Path bolt = Path()
            ..moveTo(bx, 0)
            ..lineTo(bx - 18, size.height * 0.14)
            ..lineTo(bx + 14, size.height * 0.26)
            ..lineTo(bx - 22, size.height * 0.40);
          canvas.drawPath(
            bolt,
            Paint()
              ..blendMode = BlendMode.plus
              ..color = Colors.white.withValues(alpha: flash * 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
        }

      case MoradonAtmospherePhase.bloodMoon:
        canvas.drawRect(
          fullRect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x5E4C0519),
                Color(0x30280718),
                Color(0x1C0B0614),
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ).createShader(fullRect),
        );

        final double moonPulse = 0.90 + 0.10 * math.sin(phase * math.pi * 2);
        final Paint ashPaint = Paint();
        final Paint emberPaint = Paint()..blendMode = BlendMode.plus;
        for (int i = 0; i < 28; i++) {
          final double t = (skyPhase * 2.4 + (i * 0.089)) % 1.0;
          final double baseX = ((i * 463) % 1000) / 1000.0 * size.width;
          final double baseY = ((i * 317) % 1000) / 1000.0 * size.height;
          final double sway = math.sin((t * 2.0 + i) * math.pi * 2) * 28.0;
          final double px = (baseX + sway + t * 80.0) % size.width;
          if (i.isEven) {
            final double py = (baseY + t * size.height * 0.65) % size.height;
            ashPaint.color =
                const Color(0xFFFDA4AF).withValues(alpha: 0.30 * moonPulse);
            canvas.drawCircle(Offset(px, py), 1.8, ashPaint);
          } else {
            final double py =
                (baseY - t * size.height * 0.70 + size.height) % size.height;
            emberPaint.color = const Color(0xFFFB7185)
                .withValues(alpha: 0.24 + 0.42 * math.sin(t * math.pi));
            canvas.drawCircle(Offset(px, py), 2.3, emberPaint);
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant MoradonDynamicWeatherPainter oldDelegate) {
    if (atmosphere == MoradonAtmospherePhase.twilight &&
        oldDelegate.atmosphere == MoradonAtmospherePhase.twilight) {
      return false;
    }
    return oldDelegate.atmosphere != atmosphere ||
        (oldDelegate.phase - phase).abs() > 0.016 ||
        (oldDelegate.skyPhase - skyPhase).abs() > 0.004;
  }
}

/// Sky-Piercing +9/+10 Forge & Legendary Crate Celebration Light Pillar across 6400 x 3600.
class MoradonCelebrationPillarPainter extends CustomPainter {
  final MoradonCelebrationEvent event;
  final double phase;
  final Rect? frustum;

  const MoradonCelebrationPillarPainter({
    required this.event,
    required this.phase,
    this.frustum,
  });

  Offset _resolveOrigin() {
    if (event.originNpcId == 'magic_anvil') {
      return const Offset(1140, 1875); // Exact Painted Forge Runic Anvil!
    }
    if (event.originNpcId == 'entertainment_gate') {
      return const Offset(4880, 2860); // Gothic Tavern Courtyard!
    }
    for (final MoradonNpcDefinition npc in kMoradonNpcs) {
      if (npc.id == event.originNpcId) {
        return Offset(npc.x, npc.y - 48.0);
      }
    }
    return const Offset(1190, 1895);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset origin = _resolveOrigin();
    final Rect? f = frustum;
    if (f != null && (origin.dx < f.left - 240 || origin.dx > f.right + 240)) {
      return;
    }
    final int totalMs =
        event.expiresAt.difference(event.startedAt).inMilliseconds;
    final int elapsedMs =
        DateTime.now().difference(event.startedAt).inMilliseconds;
    if (totalMs <= 0 || elapsedMs < 0 || elapsedMs > totalMs) return;

    final double progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
    final double envelope = progress < 0.09
        ? (progress / 0.09)
        : (progress > 0.82 ? ((1.0 - progress) / 0.18) : 1.0);
    if (envelope <= 0.01) return;

    final Color primary = event.isCrateDrop
        ? const Color(0xFF34D399)
        : (event.enhancementLevel >= 10
            ? const Color(0xFFF43F5E)
            : const Color(0xFFFBBF24));
    final Color core = event.isCrateDrop
        ? const Color(0xFFBAE6FD)
        : const Color(0xFFFEF9C3);

    for (int r = 0; r < 3; r++) {
      final double rt = (progress * 3.2 + r / 3.0) % 1.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(origin.dx, origin.dy + 26.0),
          width: 90.0 + rt * 320.0,
          height: 44.0 + rt * 155.0,
        ),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = primary.withValues(alpha: (1.0 - rt) * 0.55 * envelope)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 - rt * 1.4,
      );
    }

    final double pulseW = 1.0 + 0.12 * math.sin(phase * math.pi * 6);
    final double outerW = 142.0 * pulseW * envelope;
    final Rect beamRect = Rect.fromLTWH(
      origin.dx - outerW / 2,
      0,
      outerW,
      origin.dy + 24.0,
    );
    canvas.drawRect(
      beamRect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Colors.transparent,
            primary.withValues(alpha: 0.34 * envelope),
            core.withValues(alpha: 0.78 * envelope),
            primary.withValues(alpha: 0.34 * envelope),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.28, 0.50, 0.72, 1.0],
        ).createShader(beamRect),
    );

    final Paint orbPaint = Paint()..blendMode = BlendMode.plus;
    for (int i = 0; i < 14; i++) {
      final double ht = (progress * 2.4 + i / 14.0) % 1.0;
      final double angle = ht * math.pi * 8 + (i.isEven ? 0.0 : math.pi);
      final double hx = origin.dx + math.cos(angle) * 46.0 * envelope;
      final double hy = origin.dy - ht * (origin.dy - 30.0);
      orbPaint.color = (i.isEven ? core : primary)
          .withValues(alpha: (1.0 - ht * 0.55) * 0.85 * envelope);
      canvas.drawCircle(Offset(hx, hy), 3.4, orbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MoradonCelebrationPillarPainter oldDelegate) =>
      oldDelegate.event.id != event.id ||
      oldDelegate.frustum != frustum ||
      (oldDelegate.phase - phase).abs() > 0.012;
}

/// Interactive Hand-Painted Isometric Thoroughbred Racehorse inside SE Royal Hippodrome Track.
class MoradonRacehorseEntity extends StatelessWidget {
  final MoradonRacehorseProp steed;
  final double phase;
  final VoidCallback onTap;

  const MoradonRacehorseEntity({
    super.key,
    required this.steed,
    required this.phase,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget spriteImg = Image.asset(
      steed.assetPath,
      width: 98,
      height: 94,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return Image.network(
          'assets/${steed.assetPath}',
          width: 98,
          height: 94,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const SizedBox(width: 98, height: 94),
        );
      },
    );

    return Positioned(
      left: steed.x - 84,
      bottom: MoradonHubState.worldHeight - steed.y,
      width: 168,
      child: RepaintBoundary(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '<${steed.pedigree}>',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: steed.accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.black, offset: Offset(0, 1.3)),
                    ],
                  ),
                ),
                Text(
                  '[🐎 ${steed.name}]',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFEF9C3),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                    shadows: <Shadow>[
                      Shadow(color: Colors.black, offset: Offset(0, 1.3)),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                SizedBox(
                  width: 106,
                  height: 98,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      Positioned(
                        bottom: 2,
                        child: Container(
                          width: 82,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: RadialGradient(
                              colors: <Color>[
                                Colors.black.withValues(alpha: 0.78),
                                steed.accentColor.withValues(alpha: 0.18),
                                Colors.transparent,
                              ],
                              stops: const <double>[0.0, 0.62, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Transform.flip(
                        flipX: !steed.facingRight,
                        child: spriteImg,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
