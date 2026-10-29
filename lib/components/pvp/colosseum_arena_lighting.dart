import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/engine/adaptive_quality_scaler.dart';
import '../../core/engine/zero_jank_preloader.dart';

/// Predefined lighting presets for PvP Colosseum arenas, featuring 2027 Aion 2 Obsidian-Glass
/// and high-octane battle atmosphere dynamics.
enum ColosseumAtmosphere {
  sanctumCelestial,
  abyssalEclipse,
  obsidianChasm,
  dawnGladiator,
  crimsonBattle,
}

/// Physical and visual parameters governing arena illumination, volumetric godrays,
/// dramatic spotlight falloff, chromatic lens flares, and directional shadow casting.
class ArenaLightingTheme {
  const ArenaLightingTheme({
    required this.name,
    required this.sunAzimuth,
    required this.sunElevation,
    required this.sunIntensity,
    required this.sunColor,
    required this.ambientColor,
    required this.crystalColor,
    required this.shadowColor,
    this.secondaryCrystalColor = const Color(0xFF00E5FF),
    this.beamCount = 6,
    this.dustMoteCount = 28,
    this.spotlightFalloff = 0.85,
    this.battleCrimsonFlare = const Color(0xFFFF3366),
    this.goldenSunburstFlare = const Color(0xFFFFA000),
    this.volumetricHazeDensity = 0.45,
    this.obsidianVignetteStrength = 0.65,
    this.flareIntensity = 0.70,
  });

  /// User-facing localized title of the colosseum atmosphere.
  final String name;

  /// Horizontal angle of the sun in radians (-pi to pi).
  final double sunAzimuth;

  /// Elevation of the sun above horizon in radians (0.2 to 1.4).
  /// Lower elevation produces longer dramatic shadows; higher elevation produces shorter crisp shadows.
  final double sunElevation;

  /// Directional sun intensity (0.0 to 1.0).
  final double sunIntensity;

  /// Color of the primary sunlight shafts and specular highlights.
  final Color sunColor;

  /// Diffuse ambient lighting color filling shadows and background sky.
  final Color ambientColor;

  /// Primary color emitted by perimeter aether crystals.
  final Color crystalColor;

  /// Secondary resonance color of aether crystal facets and caustics.
  final Color secondaryCrystalColor;

  /// Directional shadow tint cast on the stone/sand floor.
  final Color shadowColor;

  /// Number of volumetric sun shaft godrays.
  final int beamCount;

  /// Number of floating atmospheric dust motes.
  final int dustMoteCount;

  /// Dramatic spotlight falloff steepness (0.3 to 1.2) focusing light onto central duel arena.
  final double spotlightFalloff;

  /// Battle Crimson chromatic flare color (#FFFF3366) for intense duel tension.
  final Color battleCrimsonFlare;

  /// Golden Sunburst optical lens flare color (#FFA000) for celestial radiance.
  final Color goldenSunburstFlare;

  /// Volumetric atmosphere density (0.0 to 1.0) governing Mie scattering haze and radial gradient masks.
  final double volumetricHazeDensity;

  /// Obsidian perimeter vignette strength (0.0 to 1.0) darkening outer colonnades.
  final double obsidianVignetteStrength;

  /// Optical anamorphic flare and starburst intensity (0.0 to 1.0).
  final double flareIntensity;

  /// Sanctum Celestial preset: high golden sunbeams, ethereal cyan crystal caustics.
  factory ArenaLightingTheme.sanctumCelestial() {
    return const ArenaLightingTheme(
      name: 'Sanctum Göksel Meydanı',
      sunAzimuth: -0.65,
      sunElevation: 1.15,
      sunIntensity: 0.95,
      sunColor: Color(0xFFFFE082),
      ambientColor: Color(0xFF14192E),
      crystalColor: Color(0xFF00E5FF),
      secondaryCrystalColor: Color(0xFF80D8FF),
      shadowColor: Color(0xFF080B14),
      beamCount: 6,
      dustMoteCount: 30,
      spotlightFalloff: 0.82,
      battleCrimsonFlare: Color(0xFFFF3366),
      goldenSunburstFlare: Color(0xFFFFA000),
      volumetricHazeDensity: 0.42,
      obsidianVignetteStrength: 0.60,
      flareIntensity: 0.75,
    );
  }

  /// Abyssal Eclipse preset: low dramatic crimson godrays with violet shadows.
  factory ArenaLightingTheme.abyssalEclipse() {
    return const ArenaLightingTheme(
      name: 'Uçurum Gladyatör Arenası',
      sunAzimuth: 0.85,
      sunElevation: 0.55,
      sunIntensity: 0.90,
      sunColor: Color(0xFFFF3D00),
      ambientColor: Color(0xFF150A18),
      crystalColor: Color(0xFFFF1744),
      secondaryCrystalColor: Color(0xFFD500F9),
      shadowColor: Color(0xFF09040C),
      beamCount: 7,
      dustMoteCount: 35,
      spotlightFalloff: 0.90,
      battleCrimsonFlare: Color(0xFFFF3366),
      goldenSunburstFlare: Color(0xFFFF6D00),
      volumetricHazeDensity: 0.55,
      obsidianVignetteStrength: 0.72,
      flareIntensity: 0.85,
    );
  }

  /// Obsidian Chasm preset: mysterious subterranean cyan-teal lighting with deep dark shadows.
  factory ArenaLightingTheme.obsidianChasm() {
    return const ArenaLightingTheme(
      name: 'Obsidiyen Çukur Koloseumu',
      sunAzimuth: -0.35,
      sunElevation: 0.80,
      sunIntensity: 0.85,
      sunColor: Color(0xFF64FFDA),
      ambientColor: Color(0xFF0B121A),
      crystalColor: Color(0xFF00B0FF),
      secondaryCrystalColor: Color(0xFF1DE9B6),
      shadowColor: Color(0xFF05090F),
      beamCount: 5,
      dustMoteCount: 26,
      spotlightFalloff: 0.88,
      battleCrimsonFlare: Color(0xFFFF3366),
      goldenSunburstFlare: Color(0xFF00E5FF),
      volumetricHazeDensity: 0.48,
      obsidianVignetteStrength: 0.78,
      flareIntensity: 0.68,
    );
  }

  /// Dawn Gladiator preset: low morning amber sun cutting through morning colosseum mist.
  factory ArenaLightingTheme.dawnGladiator() {
    return const ArenaLightingTheme(
      name: 'Şafak Gladyatör Koloseumu',
      sunAzimuth: -1.05,
      sunElevation: 0.45,
      sunIntensity: 0.92,
      sunColor: Color(0xFFFFB300),
      ambientColor: Color(0xFF1A1320),
      crystalColor: Color(0xFFFFAB00),
      secondaryCrystalColor: Color(0xFFFF6D00),
      shadowColor: Color(0xFF0A0710),
      beamCount: 6,
      dustMoteCount: 32,
      spotlightFalloff: 0.80,
      battleCrimsonFlare: Color(0xFFFF3366),
      goldenSunburstFlare: Color(0xFFFFA000),
      volumetricHazeDensity: 0.50,
      obsidianVignetteStrength: 0.62,
      flareIntensity: 0.80,
    );
  }

  /// 2027 Aion 2 Signature Battle Crimson & Golden Sunburst Preset.
  factory ArenaLightingTheme.crimsonBattle() {
    return const ArenaLightingTheme(
      name: 'Aion Obsidiyen Kan Arenası',
      sunAzimuth: -0.80,
      sunElevation: 0.70,
      sunIntensity: 0.98,
      sunColor: Color(0xFFFFA000),
      ambientColor: Color(0xFF160912),
      crystalColor: Color(0xFFFF3366),
      secondaryCrystalColor: Color(0xFFFF80AB),
      shadowColor: Color(0xFF080306),
      beamCount: 8,
      dustMoteCount: 36,
      spotlightFalloff: 0.94,
      battleCrimsonFlare: Color(0xFFFF3366),
      goldenSunburstFlare: Color(0xFFFFA000),
      volumetricHazeDensity: 0.58,
      obsidianVignetteStrength: 0.75,
      flareIntensity: 0.92,
    );
  }

  static ArenaLightingTheme fromAtmosphere(ColosseumAtmosphere atmosphere) {
    switch (atmosphere) {
      case ColosseumAtmosphere.sanctumCelestial:
        return ArenaLightingTheme.sanctumCelestial();
      case ColosseumAtmosphere.abyssalEclipse:
        return ArenaLightingTheme.abyssalEclipse();
      case ColosseumAtmosphere.obsidianChasm:
        return ArenaLightingTheme.obsidianChasm();
      case ColosseumAtmosphere.dawnGladiator:
        return ArenaLightingTheme.dawnGladiator();
      case ColosseumAtmosphere.crimsonBattle:
        return ArenaLightingTheme.crimsonBattle();
    }
  }

  /// Returns a copy of this theme with modified properties.
  ArenaLightingTheme copyWith({
    String? name,
    double? sunAzimuth,
    double? sunElevation,
    double? sunIntensity,
    Color? sunColor,
    Color? ambientColor,
    Color? crystalColor,
    Color? secondaryCrystalColor,
    Color? shadowColor,
    int? beamCount,
    int? dustMoteCount,
    double? spotlightFalloff,
    Color? battleCrimsonFlare,
    Color? goldenSunburstFlare,
    double? volumetricHazeDensity,
    double? obsidianVignetteStrength,
    double? flareIntensity,
  }) {
    return ArenaLightingTheme(
      name: name ?? this.name,
      sunAzimuth: sunAzimuth ?? this.sunAzimuth,
      sunElevation: sunElevation ?? this.sunElevation,
      sunIntensity: sunIntensity ?? this.sunIntensity,
      sunColor: sunColor ?? this.sunColor,
      ambientColor: ambientColor ?? this.ambientColor,
      crystalColor: crystalColor ?? this.crystalColor,
      secondaryCrystalColor: secondaryCrystalColor ?? this.secondaryCrystalColor,
      shadowColor: shadowColor ?? this.shadowColor,
      beamCount: beamCount ?? this.beamCount,
      dustMoteCount: dustMoteCount ?? this.dustMoteCount,
      spotlightFalloff: spotlightFalloff ?? this.spotlightFalloff,
      battleCrimsonFlare: battleCrimsonFlare ?? this.battleCrimsonFlare,
      goldenSunburstFlare: goldenSunburstFlare ?? this.goldenSunburstFlare,
      volumetricHazeDensity: volumetricHazeDensity ?? this.volumetricHazeDensity,
      obsidianVignetteStrength: obsidianVignetteStrength ?? this.obsidianVignetteStrength,
      flareIntensity: flareIntensity ?? this.flareIntensity,
    );
  }

  /// Linearly interpolates between two [ArenaLightingTheme] states for smooth dynamic transitions.
  static ArenaLightingTheme lerp(ArenaLightingTheme a, ArenaLightingTheme b, double t) {
    final double clampedT = t.clamp(0.0, 1.0);
    return ArenaLightingTheme(
      name: clampedT < 0.5 ? a.name : b.name,
      sunAzimuth: ui.lerpDouble(a.sunAzimuth, b.sunAzimuth, clampedT) ?? a.sunAzimuth,
      sunElevation: ui.lerpDouble(a.sunElevation, b.sunElevation, clampedT) ?? a.sunElevation,
      sunIntensity: ui.lerpDouble(a.sunIntensity, b.sunIntensity, clampedT) ?? a.sunIntensity,
      sunColor: Color.lerp(a.sunColor, b.sunColor, clampedT) ?? a.sunColor,
      ambientColor: Color.lerp(a.ambientColor, b.ambientColor, clampedT) ?? a.ambientColor,
      crystalColor: Color.lerp(a.crystalColor, b.crystalColor, clampedT) ?? a.crystalColor,
      secondaryCrystalColor:
          Color.lerp(a.secondaryCrystalColor, b.secondaryCrystalColor, clampedT) ??
              a.secondaryCrystalColor,
      shadowColor: Color.lerp(a.shadowColor, b.shadowColor, clampedT) ?? a.shadowColor,
      beamCount: (ui.lerpDouble(a.beamCount.toDouble(), b.beamCount.toDouble(), clampedT) ??
              a.beamCount.toDouble())
          .round(),
      dustMoteCount: (ui.lerpDouble(
                  a.dustMoteCount.toDouble(), b.dustMoteCount.toDouble(), clampedT) ??
              a.dustMoteCount.toDouble())
          .round(),
      spotlightFalloff:
          ui.lerpDouble(a.spotlightFalloff, b.spotlightFalloff, clampedT) ?? a.spotlightFalloff,
      battleCrimsonFlare:
          Color.lerp(a.battleCrimsonFlare, b.battleCrimsonFlare, clampedT) ?? a.battleCrimsonFlare,
      goldenSunburstFlare:
          Color.lerp(a.goldenSunburstFlare, b.goldenSunburstFlare, clampedT) ?? a.goldenSunburstFlare,
      volumetricHazeDensity:
          ui.lerpDouble(a.volumetricHazeDensity, b.volumetricHazeDensity, clampedT) ??
              a.volumetricHazeDensity,
      obsidianVignetteStrength:
          ui.lerpDouble(a.obsidianVignetteStrength, b.obsidianVignetteStrength, clampedT) ??
              a.obsidianVignetteStrength,
      flareIntensity:
          ui.lerpDouble(a.flareIntensity, b.flareIntensity, clampedT) ?? a.flareIntensity,
    );
  }
}

/// Represents a gladiator shadow casting source in normalized viewport coordinates (0.0 to 1.0).
class GladiatorShadowSlot {
  const GladiatorShadowSlot({
    required this.position,
    this.height = 70.0,
    this.width = 32.0,
    this.lungeOffset = Offset.zero,
    this.hitShake = 0.0,
    this.auraIntensity = 0.0,
    this.auraColor,
  });

  /// Base position (feet contact point) on arena floor in normalized (x, y) coordinates.
  final Offset position;

  /// Approximate gladiator height in logical pixels.
  final double height;

  /// Approximate gladiator body width in logical pixels.
  final double width;

  /// Dynamic combat lunge / attack translation offset.
  final Offset lungeOffset;

  /// Intensity of impact recoil / hit-shake (0.0 to 1.0).
  final double hitShake;

  /// Ethereal aether aura intensity cast around fighter feet (0.0 to 1.0).
  final double auraIntensity;

  /// Color of fighter personal combat aura.
  final Color? auraColor;
}

/// Dynamic programmatic controller for Colosseum lighting, atmospheric surges, and battle flashes.
class ColosseumLightingController extends ChangeNotifier {
  ColosseumLightingController({
    ArenaLightingTheme? initialTheme,
  }) : _theme = initialTheme ?? ArenaLightingTheme.sanctumCelestial();

  ArenaLightingTheme _theme;
  double _combatFlash = 0.0;
  double _spotlightPulse = 0.0;

  ArenaLightingTheme get theme => _theme;
  double get combatFlash => _combatFlash;
  double get spotlightPulse => _spotlightPulse;

  void setTheme(ArenaLightingTheme newTheme) {
    if (_theme == newTheme) return;
    _theme = newTheme;
    notifyListeners();
  }

  void setAtmosphere(ColosseumAtmosphere atmosphere) {
    setTheme(ArenaLightingTheme.fromAtmosphere(atmosphere));
  }

  void triggerCombatSurge({double intensity = 1.0}) {
    _combatFlash = intensity.clamp(0.0, 1.0);
    _spotlightPulse = 1.0;
    notifyListeners();
  }

  void flashHit({double intensity = 0.75}) {
    _combatFlash = math.max(_combatFlash, intensity.clamp(0.0, 1.0));
    notifyListeners();
  }

  void setSunPosition({required double azimuth, required double elevation}) {
    _theme = _theme.copyWith(
      sunAzimuth: azimuth,
      sunElevation: elevation,
    );
    notifyListeners();
  }

  void decay(double dt) {
    bool changed = false;
    if (_combatFlash > 0.0) {
      _combatFlash = math.max(0.0, _combatFlash - dt * 2.8);
      changed = true;
    }
    if (_spotlightPulse > 0.0) {
      _spotlightPulse = math.max(0.0, _spotlightPulse - dt * 1.5);
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }
}

/// High-performance CustomPainter delivering 2027 Aion 2 Obsidian-Glass Colosseum lighting,
/// volumetric godrays, dramatic spotlight falloff, Battle Crimson (#FFFF3366) and Golden Sunburst (#FFA000)
/// lens flares, and directional gladiator shadows with zero CPU jank.
class ColosseumArenaPainter extends CustomPainter {
  ColosseumArenaPainter({
    required this.animationProgress,
    required this.theme,
    this.gladiatorSlots = const <GladiatorShadowSlot>[],
    this.showColosseumWalls = true,
    this.showCrystals = true,
    this.showGodrays = true,
    this.showShadows = true,
    this.combatFlashIntensity = 0.0,
    this.showLensFlares = true,
    this.showVolumetricAtmosphere = true,
    this.scaler,
    this.qualitySettings,
    this.shadowResolution,
    this.shadowCascadeCount,
  });

  final double animationProgress;
  final ArenaLightingTheme theme;
  final List<GladiatorShadowSlot> gladiatorSlots;
  final bool showColosseumWalls;
  final bool showCrystals;
  final bool showGodrays;
  final bool showShadows;
  final double combatFlashIntensity;
  final bool showLensFlares;
  final bool showVolumetricAtmosphere;

  /// Optional AdaptiveQualityScaler hook for dynamic runtime quality scaling.
  final AdaptiveQualityScaler? scaler;

  /// Optional QualitySettings snapshot override.
  final QualitySettings? qualitySettings;

  /// Optional explicit shadow map resolution (e.g. 0, 512, 1024, 2048).
  final int? shadowResolution;

  /// Optional explicit shadow cascade count (0 to 4).
  final int? shadowCascadeCount;

  /// Resolved active QualitySettings snapshot from scaler or custom settings.
  QualitySettings get activeQualitySettings =>
      qualitySettings ?? scaler?.currentSettings ?? QualitySettings.forTier(HardwareTier.high);

  /// Resolved shadow map resolution (0 for off, 512, 1024, 2048).
  int get effectiveShadowResolution =>
      shadowResolution ?? scaler?.currentSettings.shadowResolution ?? qualitySettings?.shadowResolution ?? 1024;

  /// Resolved shadow cascade count (0 to 4).
  int get effectiveShadowCascadeCount =>
      shadowCascadeCount ?? scaler?.currentSettings.shadowCascadeCount ?? qualitySettings?.shadowCascadeCount ?? 3;

  /// Whether active tier is Eco or Low (<= 2GB RAM or 0 shadows).
  bool get isEcoOrLowTier {
    final HardwareTier tier = scaler?.currentTier ?? qualitySettings?.tier ?? HardwareTier.high;
    return tier == HardwareTier.eco ||
        tier == HardwareTier.low ||
        effectiveShadowResolution <= 0 ||
        effectiveShadowCascadeCount <= 0;
  }

  /// Whether active tier is Mid tier (4GB - 6GB RAM, 512px map, 2 cascades).
  bool get isMidTier {
    final HardwareTier tier = scaler?.currentTier ?? qualitySettings?.tier ?? HardwareTier.high;
    return !isEcoOrLowTier &&
        (tier == HardwareTier.mid || effectiveShadowCascadeCount == 2 || effectiveShadowResolution <= 512);
  }

  /// Whether active tier is High or Ultra (8GB - 16GB+ RAM, 1024-2048px map, 3-4 cascades).
  bool get isHighOrUltraTier => !isEcoOrLowTier && !isMidTier;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    final double cx = w * 0.5;
    final double cy = h * 0.58;

    // 1. Far Arena Colosseum Colonnade & Amphitheater Sky with Aether Braziers
    _paintAtmosphericSkyAndColonnade(canvas, size, cx, cy);

    // 2. Volumetric Atmosphere Simulation with Radial Gradient Masks
    if (showVolumetricAtmosphere) {
      _paintVolumetricAtmosphere(canvas, size, cx, cy);
    }

    // 3. Colosseum Obsidian-Glass & Sand Floor with Dramatic Spotlight Falloff & Runic Compass
    final Rect arenaRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: w * 0.88,
      height: h * 0.54,
    );
    _paintColosseumFloor(canvas, arenaRect, cx, cy);

    // 4. Aether Crystal Illumination & Floor Caustics
    if (showCrystals) {
      _paintAetherCrystals(canvas, size, arenaRect);
    }

    // 5. Directional Dynamic Gladiator Floor Shadows
    if (showShadows && gladiatorSlots.isNotEmpty) {
      _paintGladiatorShadows(canvas, size, arenaRect);
    }

    // 6. Volumetric Sun Shaft Godrays with Mie Scattering
    if (showGodrays) {
      _paintSunShaftGodrays(canvas, size, cx);
    }

    // 7. Battle Crimson (#FFFF3366) and Golden Sunburst (#FFA000) Lens Flares & Starburst
    if (showLensFlares) {
      _paintBattleFlaresAndSunburst(canvas, size, cx, cy);
    }

    // 8. Sunlight Scattering Dust Motes & Incandescent Obsidian Embers (Zero CPU Allocation)
    _paintAtmosphericParticulates(canvas, size);

    // 9. Dynamic Combat Flash / Impact Illumination Overlay
    if (combatFlashIntensity > 0.0) {
      _paintCombatLightingFlash(canvas, size, arenaRect);
    }
  }

  // ── 1. SKY & COLONNADE ──────────────────────────────────────────────────────
  void _paintAtmosphericSkyAndColonnade(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
  ) {
    final double w = size.width;
    final double h = size.height;

    // Deep Obsidian Sky Gradient with Atmospheric Horizon Haze
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          theme.ambientColor.withValues(alpha: 0.98),
          const Color(0xFF03050A),
          theme.shadowColor,
        ],
        stops: const <double>[0.0, 0.42, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    if (!showColosseumWalls) return;

    // 1.1 Far Tier Amphitheater Wall Silhouette (2027 Aion 2 Obsidian Colonnade)
    final Paint wallPaint = Paint()
      ..color = const Color(0xFF0C101A).withValues(alpha: 0.94)
      ..style = PaintingStyle.fill;

    final Path wallPath = Path();
    wallPath.moveTo(0, h * 0.48);
    const int archCount = 9;
    final double archWidth = w / archCount;
    for (int i = 0; i < archCount; i++) {
      final double x0 = i * archWidth;
      final double x1 = x0 + archWidth;
      final double archHeight = 20.0 + 8.0 * math.sin(i * 0.7);
      wallPath.lineTo(x0 + archWidth * 0.15, h * 0.48 - archHeight);
      wallPath.quadraticBezierTo(
        x0 + archWidth * 0.5,
        h * 0.48 - archHeight - 7,
        x1 - archWidth * 0.15,
        h * 0.48 - archHeight,
      );
      wallPath.lineTo(x1, h * 0.48);
    }
    wallPath.lineTo(w, h * 0.56);
    wallPath.lineTo(0, h * 0.56);
    wallPath.close();
    canvas.drawPath(wallPath, wallPaint);

    // 1.2 Distant Colonnade Aether Braziers (faint warm incandescent embers in amphitheater)
    final Paint brazierPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < archCount; i++) {
      final double bx = (i + 0.5) * archWidth;
      final double by = h * 0.48 - (20.0 + 8.0 * math.sin(i * 0.7)) * 0.35;
      final double flicker = 0.8 + 0.2 * math.sin(animationProgress * 12.0 + i * 1.7);

      brazierPaint.shader = RadialGradient(
        colors: <Color>[
          theme.goldenSunburstFlare.withValues(alpha: 0.45 * flicker),
          theme.battleCrimsonFlare.withValues(alpha: 0.18 * flicker),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(bx, by), radius: 8.0 * flicker));

      canvas.drawCircle(Offset(bx, by), 8.0 * flicker, brazierPaint);
    }

    // 1.3 Wall Arch Rim Highlights reacting to directional celestial sun
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: <Color>[
          theme.sunColor.withValues(alpha: 0.38 * theme.sunIntensity),
          theme.goldenSunburstFlare.withValues(alpha: 0.22 * theme.sunIntensity),
          theme.battleCrimsonFlare.withValues(alpha: 0.16 * theme.sunIntensity),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.42, w, h * 0.14));
    canvas.drawPath(wallPath, rimPaint);
  }

  // ── 2. VOLUMETRIC ATMOSPHERE SIMULATION ─────────────────────────────────────
  void _paintVolumetricAtmosphere(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
  ) {
    final double w = size.width;
    final double h = size.height;
    final double density = theme.volumetricHazeDensity.clamp(0.0, 1.0);

    // 2.1 Horizon Atmospheric Mist Layer hugging amphitheater base
    final Rect horizonRect = Rect.fromLTWH(0, h * 0.40, w, h * 0.26);
    final Paint horizonHazePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          theme.ambientColor.withValues(alpha: 0.40 * density),
          theme.shadowColor.withValues(alpha: 0.22 * density),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.40, 0.75, 1.0],
      ).createShader(horizonRect);
    canvas.drawRect(horizonRect, horizonHazePaint);

    // 2.2 Volumetric Radial Gradient Mask around Arena Upper Light Aperture
    final double sunX = cx + math.cos(theme.sunAzimuth) * (w * 0.52);
    final double sunY = -h * 0.12;
    final Rect apertureRect = Rect.fromCircle(
      center: Offset(sunX, sunY),
      radius: w * 0.95,
    );

    final Paint apertureMaskPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: <Color>[
          theme.sunColor.withValues(alpha: 0.24 * density * theme.sunIntensity),
          theme.goldenSunburstFlare.withValues(alpha: 0.13 * density * theme.sunIntensity),
          theme.battleCrimsonFlare.withValues(alpha: 0.06 * density),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.30, 0.65, 1.0],
      ).createShader(apertureRect);
    canvas.drawOval(apertureRect, apertureMaskPaint);
  }

  // ── 3. COLOSSEUM ARENA FLOOR WITH SPOTLIGHT FALLOFF ─────────────────────────
  void _paintColosseumFloor(Canvas canvas, Rect arenaRect, double cx, double cy) {
    // 3.1 Polished 2027 Aion 2 Obsidian Stone Floor Base
    final Paint floorPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          math.cos(theme.sunAzimuth) * 0.22,
          math.sin(theme.sunAzimuth) * 0.22,
        ),
        radius: 0.95,
        colors: <Color>[
          const Color(0xFF1C2334),
          const Color(0xFF101420),
          const Color(0xFF080B12),
        ],
        stops: const <double>[0.0, 0.62, 1.0],
      ).createShader(arenaRect);
    canvas.drawOval(arenaRect, floorPaint);

    // 3.2 Sand & Crushed Quartz Duel Pit Center
    final Rect sandPitRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: arenaRect.width * 0.68,
      height: arenaRect.height * 0.64,
    );
    final Paint sandPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF2B2218).withValues(alpha: 0.80),
          const Color(0xFF1A140F).withValues(alpha: 0.52),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.72, 1.0],
      ).createShader(sandPitRect);
    canvas.drawOval(sandPitRect, sandPaint);

    // 3.3 Concentric Obsidian-Glass Runic Joint Channels
    final Paint jointPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.18),
          theme.secondaryCrystalColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.85, 1.0],
      ).createShader(arenaRect);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: arenaRect.width * 0.85,
        height: arenaRect.height * 0.85,
      ),
      jointPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: arenaRect.width * 0.52,
        height: arenaRect.height * 0.52,
      ),
      jointPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: arenaRect.width * 0.26,
        height: arenaRect.height * 0.26,
      ),
      jointPaint,
    );

    // 3.4 Etched Runic Compass Star in Central Obsidian Duel Zone
    _paintRunicCompassRosette(canvas, Offset(cx, cy), arenaRect.width * 0.16);

    // 3.5 Dramatic Central Duel Spotlight Falloff
    final double falloffRadius = (arenaRect.width * 0.62) / theme.spotlightFalloff.clamp(0.4, 1.3);
    final Rect spotlightRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: falloffRadius * 2.0,
      height: falloffRadius * 1.18,
    );

    final Paint spotlightPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          theme.sunColor.withValues(alpha: 0.30 * theme.sunIntensity),
          theme.goldenSunburstFlare.withValues(alpha: 0.16 * theme.sunIntensity),
          theme.battleCrimsonFlare.withValues(alpha: 0.07 * theme.sunIntensity),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.35, 0.70, 1.0],
      ).createShader(spotlightRect);
    canvas.drawOval(spotlightRect, spotlightPaint);

    // 3.6 Peripheral Obsidian Vignette Mask
    final double vignette = theme.obsidianVignetteStrength.clamp(0.0, 1.0);
    final Paint vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.98,
        colors: <Color>[
          Colors.transparent,
          const Color(0xFF030508).withValues(alpha: 0.38 * vignette),
          const Color(0xFF010204).withValues(alpha: 0.78 * vignette),
        ],
        stops: const <double>[0.45, 0.80, 1.0],
      ).createShader(arenaRect);
    canvas.drawOval(arenaRect, vignettePaint);

    // 3.7 Outer Glowing Perimeter Balustrade Rim with Obsidian Glass Reflection
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: <Color>[
          theme.crystalColor,
          theme.battleCrimsonFlare,
          theme.goldenSunburstFlare,
          theme.secondaryCrystalColor,
          theme.crystalColor,
        ],
        stops: const <double>[0.0, 0.25, 0.50, 0.75, 1.0],
      ).createShader(arenaRect);
    canvas.drawOval(arenaRect, rimPaint);
  }

  // ── 3.4 RUNIC COMPASS ROSETTE ───────────────────────────────────────────────
  void _paintRunicCompassRosette(Canvas canvas, Offset center, double radius) {
    final Paint runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = theme.secondaryCrystalColor.withValues(alpha: 0.26);

    const int points = 8;
    final Path starPath = Path();
    for (int i = 0; i < points * 2; i++) {
      final double r = i.isEven ? radius : radius * 0.42;
      final double angle = (i * math.pi / points) - math.pi * 0.5;
      final double px = center.dx + math.cos(angle) * r;
      final double py = center.dy + math.sin(angle) * (r * 0.48); // 2.5D perspective compression
      if (i == 0) {
        starPath.moveTo(px, py);
      } else {
        starPath.lineTo(px, py);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, runePaint);

    // Center focal specular pip
    final Paint corePip = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, corePip);
  }

  // ── 4. AETHER CRYSTALS & FLOOR CAUSTICS ─────────────────────────────────────
  void _paintAetherCrystals(Canvas canvas, Size size, Rect arenaRect) {
    final List<double> crystalAngles = <double>[
      -math.pi * 0.85,
      -math.pi * 0.15,
      math.pi * 0.20,
      math.pi * 0.80,
    ];

    final double pulse = 0.85 + 0.15 * math.sin(animationProgress * 2 * math.pi * 1.5);

    for (int i = 0; i < crystalAngles.length; i++) {
      final double ang = crystalAngles[i];
      final double px = arenaRect.center.dx + math.cos(ang) * (arenaRect.width * 0.48);
      final double py = arenaRect.center.dy + math.sin(ang) * (arenaRect.height * 0.48);

      final Color activeColor = i.isEven ? theme.crystalColor : theme.secondaryCrystalColor;

      // 4.1 Floor Caustic Light Pool
      final Rect causticRect = Rect.fromCenter(
        center: Offset(px, py + 4),
        width: 48.0 * pulse,
        height: 24.0 * pulse,
      );
      final Paint causticPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            activeColor.withValues(alpha: 0.42 * pulse),
            activeColor.withValues(alpha: 0.15 * pulse),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(causticRect);
      canvas.drawOval(causticRect, causticPaint);

      // 4.2 Beveled Obsidian Pedestal Footing
      final Path pedestalPath = Path()
        ..moveTo(px - 10, py + 3)
        ..lineTo(px + 10, py + 3)
        ..lineTo(px + 14, py + 7)
        ..lineTo(px - 14, py + 7)
        ..close();
      final Paint pedestalPaint = Paint()..color = const Color(0xFF090D15);
      canvas.drawPath(pedestalPath, pedestalPaint);

      // 4.3 Crystal Obelisk Spire (Faceted Obsidian-Glass Prism)
      final Path crystalPath = Path();
      const double ch = 24.0;
      const double cw = 8.5;
      crystalPath.moveTo(px, py - ch);
      crystalPath.lineTo(px + cw, py - ch * 0.42);
      crystalPath.lineTo(px + cw * 0.7, py + 2);
      crystalPath.lineTo(px - cw * 0.7, py + 2);
      crystalPath.lineTo(px - cw, py - ch * 0.42);
      crystalPath.close();

      final Paint crystalBodyPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white,
            activeColor,
            activeColor.withValues(alpha: 0.65),
          ],
          stops: const <double>[0.0, 0.38, 1.0],
        ).createShader(Rect.fromLTWH(px - cw, py - ch, cw * 2, ch + 2));
      canvas.drawPath(crystalPath, crystalBodyPaint);

      // Specular Facet Ridge
      final Paint facetStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: 0.82);
      canvas.drawLine(Offset(px, py - ch), Offset(px, py + 2), facetStroke);

      // 4.4 Orbiting Aether Resonance Shards
      final double orbitAngle = animationProgress * 2 * math.pi * (i.isEven ? 1.0 : -1.0) + i;
      final double shardX = px + math.cos(orbitAngle) * 15.0;
      final double shardY = (py - ch * 0.5) + math.sin(orbitAngle) * 6.5;

      final Path shardPath = Path();
      shardPath.moveTo(shardX, shardY - 4.0);
      shardPath.lineTo(shardX + 2.8, shardY);
      shardPath.lineTo(shardX, shardY + 4.0);
      shardPath.lineTo(shardX - 2.8, shardY);
      shardPath.close();

      final Paint shardPaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
      canvas.drawPath(shardPath, shardPaint);
    }
  }

  // ── 5. DIRECTIONAL DYNAMIC GLADIATOR FLOOR SHADOWS ─────────────────────────
  void _paintGladiatorShadows(Canvas canvas, Size size, Rect arenaRect) {
    final double w = size.width;
    final double h = size.height;

    // Hook 1: Eco / Low Tiers (<= 2GB RAM or shadowResolution == 0 / shadowCascadeCount == 0)
    // Dynamic directional shadows disabled; fall back to simple baked ambient ground circle.
    if (isEcoOrLowTier) {
      final Paint bakedAmbientPaint = Paint()
        ..color = theme.shadowColor.withValues(alpha: 0.60)
        ..style = PaintingStyle.fill;

      for (final GladiatorShadowSlot slot in gladiatorSlots) {
        final double baseX = slot.position.dx * w + slot.lungeOffset.dx;
        final double baseY = slot.position.dy * h + slot.lungeOffset.dy;
        final Offset footContact = Offset(baseX, baseY);

        // Simple baked ambient ground circle/oval under gladiator contact point (0 blurs, 0 drawPath)
        final Rect bakedRect = Rect.fromCenter(
          center: footContact,
          width: slot.width * 0.95,
          height: slot.width * 0.40,
        );
        canvas.drawOval(bakedRect, bakedAmbientPaint);

        // Personal combat aura if active
        if (slot.auraIntensity > 0.0 && slot.auraColor != null) {
          final Rect auraRect = Rect.fromCenter(
            center: footContact,
            width: slot.width * 1.3 * slot.auraIntensity,
            height: slot.width * 0.6 * slot.auraIntensity,
          );
          final Paint auraPaint = Paint()
            ..color = slot.auraColor!.withValues(alpha: 0.25 * slot.auraIntensity);
          canvas.drawOval(auraRect, auraPaint);
        }
      }
      return;
    }

    final double shadowAngle = theme.sunAzimuth + math.pi;
    final double cotElevation = 1.0 / math.tan(theme.sunElevation.clamp(0.25, 1.45));

    final int cascades = effectiveShadowCascadeCount;
    final int resolution = effectiveShadowResolution;
    final bool pcfEnabled = isHighOrUltraTier; // 3-4 cascades with soft PCF filtering

    for (final GladiatorShadowSlot slot in gladiatorSlots) {
      final double baseX = slot.position.dx * w + slot.lungeOffset.dx;
      final double baseY = slot.position.dy * h + slot.lungeOffset.dy;

      // Hit-shake jitter applied to shadow during combat impacts
      final double jitter = slot.hitShake > 0.0
          ? math.sin(animationProgress * 30.0) * slot.hitShake * 4.0
          : 0.0;

      final double shadowLength = slot.height * cotElevation * 0.85;
      final double shadowSpreadX = math.cos(shadowAngle) * shadowLength + jitter;
      final double shadowSpreadY = math.sin(shadowAngle) * shadowLength * 0.45;

      final Offset footContact = Offset(baseX, baseY);
      final Offset shadowTip = Offset(baseX + shadowSpreadX, baseY + shadowSpreadY);

      // CASCADE 1: Dense Contact Umbra Shadow (tighter contact hardening on High/Ultra)
      final double contactBlur = pcfEnabled ? 1.5 : 2.0;
      final Rect contactRect = Rect.fromCenter(
        center: footContact,
        width: slot.width * (pcfEnabled ? 1.15 : 1.05),
        height: slot.width * (pcfEnabled ? 0.40 : 0.35),
      );
      final Paint contactPaint = Paint()
        ..color = theme.shadowColor.withValues(alpha: pcfEnabled ? 0.94 : 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, contactBlur);
      canvas.drawOval(contactRect, contactPaint);

      // CASCADE 2: Elongated Directional Penumbra Shadow (512px map on Mid; 1024-2048px on High/Ultra)
      final double perpAngle = shadowAngle + math.pi * 0.5;
      final double halfFootW = slot.width * 0.42;
      final double halfHeadW = slot.width * 0.58;

      final Offset p1 = Offset(
        baseX + math.cos(perpAngle) * halfFootW,
        baseY + math.sin(perpAngle) * halfFootW * 0.4,
      );
      final Offset p2 = Offset(
        baseX - math.cos(perpAngle) * halfFootW,
        baseY - math.sin(perpAngle) * halfFootW * 0.4,
      );
      final Offset p3 = Offset(
        shadowTip.dx - math.cos(perpAngle) * halfHeadW,
        shadowTip.dy - math.sin(perpAngle) * halfHeadW * 0.4,
      );
      final Offset p4 = Offset(
        shadowTip.dx + math.cos(perpAngle) * halfHeadW,
        shadowTip.dy + math.sin(perpAngle) * halfHeadW * 0.4,
      );

      final Path shadowBody = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..arcToPoint(
          p4,
          radius: Radius.circular(halfHeadW),
          clockwise: true,
        )
        ..close();

      final double penumbraBlur = isMidTier ? 4.0 : (resolution >= 2048 ? 6.5 : 5.0);
      final Paint penumbraPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(
            (footContact.dx - w * 0.5) / (w * 0.5),
            (footContact.dy - h * 0.5) / (h * 0.5),
          ),
          end: Alignment(
            (shadowTip.dx - w * 0.5) / (w * 0.5),
            (shadowTip.dy - h * 0.5) / (h * 0.5),
          ),
          colors: <Color>[
            theme.shadowColor.withValues(alpha: 0.82),
            theme.shadowColor.withValues(alpha: 0.45),
            theme.shadowColor.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.65, 1.0],
        ).createShader(Rect.fromPoints(footContact, shadowTip))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, penumbraBlur);

      canvas.drawPath(shadowBody, penumbraPaint);

      // CASCADE 3: Soft PCF Filtering Multi-Tap Expansion Pass (On High / Ultra with cascades >= 3)
      if (cascades >= 3 && pcfEnabled) {
        final double pcfBlur = resolution >= 2048 ? 8.5 : 7.0;
        final Paint pcfFilterPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment(
              (footContact.dx - w * 0.5) / (w * 0.5),
              (footContact.dy - h * 0.5) / (h * 0.5),
            ),
            end: Alignment(
              (shadowTip.dx - w * 0.5) / (w * 0.5),
              (shadowTip.dy - h * 0.5) / (h * 0.5),
            ),
            colors: <Color>[
              theme.shadowColor.withValues(alpha: 0.28),
              theme.shadowColor.withValues(alpha: 0.14),
              theme.shadowColor.withValues(alpha: 0.0),
            ],
            stops: const <double>[0.0, 0.50, 1.0],
          ).createShader(Rect.fromPoints(footContact, shadowTip))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pcfBlur);

        canvas.drawPath(shadowBody, pcfFilterPaint);
      }

      // CASCADE 4: Secondary Opposing Ambient Crystal Fill Shadow (Active on Ultra / cascades >= 4)
      if (cascades >= 4) {
        final double crystalFillLength = slot.height * 0.22;
        final Offset crystalShadowCenter = Offset(
          baseX - math.cos(shadowAngle) * crystalFillLength,
          baseY - math.sin(shadowAngle) * crystalFillLength * 0.35,
        );
        final Paint crystalShadowPaint = Paint()
          ..color = theme.crystalColor.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
        canvas.drawOval(
          Rect.fromCenter(
            center: crystalShadowCenter,
            width: slot.width * 0.9,
            height: slot.width * 0.45,
          ),
          crystalShadowPaint,
        );
      }

      // 5.5 Personal Combat Aether Aura Ground Glow (if configured)
      if (slot.auraIntensity > 0.0 && slot.auraColor != null) {
        final Rect auraRect = Rect.fromCenter(
          center: footContact,
          width: slot.width * 1.8 * slot.auraIntensity,
          height: slot.width * 0.8 * slot.auraIntensity,
        );
        final Paint auraPaint = Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              slot.auraColor!.withValues(alpha: 0.45 * slot.auraIntensity),
              slot.auraColor!.withValues(alpha: 0.15 * slot.auraIntensity),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.5, 1.0],
          ).createShader(auraRect);
        canvas.drawOval(auraRect, auraPaint);
      }
    }
  }

  // ── 6. VOLUMETRIC SUN SHAFT GODRAYS ────────────────────────────────────────
  void _paintSunShaftGodrays(Canvas canvas, Size size, double cx) {
    final double w = size.width;
    final double h = size.height;

    final double sunX = cx + math.cos(theme.sunAzimuth) * (w * 0.6);
    final double sunY = -h * 0.15;

    final Paint beamPaint = Paint()..style = PaintingStyle.fill;

    final int effectiveBeamCount = isEcoOrLowTier
        ? math.min(theme.beamCount, 3)
        : isMidTier
            ? math.min(theme.beamCount, 5)
            : theme.beamCount;

    for (int i = 0; i < effectiveBeamCount; i++) {
      final double sway = math.sin((animationProgress + i * 0.18) * 2 * math.pi) * 16.0;
      final double beamAlpha =
          (0.18 + 0.08 * math.sin((animationProgress * 3.0) + i)) * theme.sunIntensity;

      final double topSpan = 20.0 + (i % 3) * 8.0;
      final double startX = sunX - (effectiveBeamCount * 25.0) + (i * 50.0);

      final double floorSpan = 70.0 + (i % 2) * 35.0;
      final double endX = cx - (effectiveBeamCount * 35.0) + (i * 70.0) + sway;
      final double endY = h * 0.88;

      final Path beamPath = Path();
      beamPath.moveTo(startX, sunY);
      beamPath.lineTo(startX + topSpan, sunY);
      beamPath.lineTo(endX + floorSpan, endY);
      beamPath.lineTo(endX, endY);
      beamPath.close();

      beamPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          theme.sunColor.withValues(alpha: beamAlpha * 1.3),
          theme.goldenSunburstFlare.withValues(alpha: beamAlpha * 0.8),
          theme.battleCrimsonFlare.withValues(alpha: beamAlpha * 0.25),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.35, 0.75, 1.0],
      ).createShader(Rect.fromPoints(Offset(startX, sunY), Offset(endX, endY)));

      canvas.drawPath(beamPath, beamPaint);
    }
  }

  // ── 7. BATTLE CRIMSON & GOLDEN SUNBURST FLARE SYSTEM ───────────────────────
  void _paintBattleFlaresAndSunburst(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
  ) {
    final double w = size.width;
    final double h = size.height;
    final double flareIntensity = theme.flareIntensity.clamp(0.0, 1.0);
    if (flareIntensity <= 0.0) return;

    // Optical Sun Position
    final double sunX = cx + math.cos(theme.sunAzimuth) * (w * 0.52);
    final double sunY = cy - math.sin(theme.sunElevation) * (h * 0.65);
    final Offset sunPos = Offset(sunX, sunY);
    final Offset arenaCenter = Offset(cx, cy);

    final double flareScale = (1.0 + combatFlashIntensity * 1.35) * flareIntensity;

    // 7.1 Golden Sunburst Corona Core
    final Rect coronaRect = Rect.fromCircle(center: sunPos, radius: 46.0 * flareScale);
    final Paint coronaPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          theme.goldenSunburstFlare.withValues(alpha: 0.78 * flareScale),
          theme.goldenSunburstFlare.withValues(alpha: 0.25 * flareScale),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.28, 0.65, 1.0],
      ).createShader(coronaRect);
    canvas.drawOval(coronaRect, coronaPaint);

    // 7.2 Battle Crimson (#FFFF3366) Anamorphic Laser Flare Streak with Chromatic Fringe
    final double streakHalfWidth = w * 0.48 * flareScale;
    final double streakHalfHeight = 3.2 * flareScale;
    final Rect streakRect = Rect.fromCenter(
      center: sunPos,
      width: streakHalfWidth * 2.0,
      height: streakHalfHeight * 2.0,
    );

    final Paint streakPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.transparent,
          theme.battleCrimsonFlare.withValues(alpha: 0.15 * flareScale),
          theme.battleCrimsonFlare.withValues(alpha: 0.88 * flareScale),
          Colors.white,
          theme.battleCrimsonFlare.withValues(alpha: 0.88 * flareScale),
          theme.battleCrimsonFlare.withValues(alpha: 0.15 * flareScale),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.25, 0.46, 0.50, 0.54, 0.75, 1.0],
      ).createShader(streakRect);
    canvas.drawRect(streakRect, streakPaint);

    // Secondary subtle cross-vertical flare streak
    final Rect crossStreakRect = Rect.fromCenter(
      center: sunPos,
      width: 2.2 * flareScale,
      height: 48.0 * flareScale,
    );
    final Paint crossStreakPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          theme.goldenSunburstFlare.withValues(alpha: 0.65 * flareScale),
          Colors.white,
          theme.goldenSunburstFlare.withValues(alpha: 0.65 * flareScale),
          Colors.transparent,
        ],
      ).createShader(crossStreakRect);
    canvas.drawRect(crossStreakRect, crossStreakPaint);

    // 7.3 Eight-Point Celestial Starburst Spikes
    final Paint spikePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          theme.goldenSunburstFlare.withValues(alpha: 0.65 * flareScale),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: sunPos, radius: 55.0 * flareScale));

    const int spikeCount = 8;
    for (int i = 0; i < spikeCount; i++) {
      final double rot = (i * math.pi / 4.0) + (animationProgress * 0.25);
      final double spikeLen = (i % 2 == 0 ? 55.0 : 32.0) * flareScale;
      final Offset end = sunPos + Offset(math.cos(rot) * spikeLen, math.sin(rot) * spikeLen);
      canvas.drawLine(sunPos, end, spikePaint);
    }

    // 7.4 Chromatic Dispersion Halo Ring
    final Offset axis = arenaCenter - sunPos;
    final Offset haloCenter = sunPos + axis * 0.45;
    final double haloRadius = 38.0 * flareScale;
    final Rect haloRect = Rect.fromCircle(center: haloCenter, radius: haloRadius);

    final Paint haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * flareScale
      ..shader = SweepGradient(
        colors: <Color>[
          theme.battleCrimsonFlare.withValues(alpha: 0.40 * flareScale),
          theme.goldenSunburstFlare.withValues(alpha: 0.35 * flareScale),
          theme.secondaryCrystalColor.withValues(alpha: 0.30 * flareScale),
          theme.battleCrimsonFlare.withValues(alpha: 0.40 * flareScale),
        ],
      ).createShader(haloRect);
    canvas.drawCircle(haloCenter, haloRadius, haloPaint);

    // 7.5 Optical Axis Lens Flare Ghost Nodes
    final List<double> ghostOffsets = <double>[0.28, 0.72, 1.15];
    for (int i = 0; i < ghostOffsets.length; i++) {
      final double t = ghostOffsets[i];
      final Offset ghostPos = sunPos + axis * t;
      final double radius = (12.0 + i * 9.0) * flareScale;
      final Color ghostColor =
          i.isEven ? theme.battleCrimsonFlare : theme.goldenSunburstFlare;

      final Rect ghostRect = Rect.fromCircle(center: ghostPos, radius: radius);
      final Paint ghostPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            ghostColor.withValues(alpha: 0.28 * flareScale),
            ghostColor.withValues(alpha: 0.08 * flareScale),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.60, 1.0],
        ).createShader(ghostRect);
      canvas.drawCircle(ghostPos, radius, ghostPaint);
    }
  }

  // ── 8. ATMOSPHERIC PARTICULATES & INCANDESCENT EMBERS (ZERO CPU ALLOCATION) ─
  void _paintAtmosphericParticulates(Canvas canvas, Size size) {
    if (isEcoOrLowTier) return; // 0 particles on Eco/Low to eliminate draw calls

    final double w = size.width;
    final double h = size.height;
    final int baseCount = theme.dustMoteCount.clamp(12, 64);
    final int count = isMidTier ? (baseCount * 0.5).round() : baseCount;
    final Paint dustPaint = Paint()..style = PaintingStyle.fill;

    // Zero-allocation deterministic hash generator replacing Random(42) heap allocation
    for (int i = 0; i < count; i++) {
      final double seedX = ((i * 137.3) % 100.0) / 100.0;
      final double seedY = ((i * 269.7) % 100.0) / 100.0;
      final double speed = 0.30 + (((i * 71.9) % 100.0) / 200.0);
      final double sizeMultiplier = 0.80 + (((i * 43.1) % 100.0) / 100.0);

      final double progress = (animationProgress * speed + seedY) % 1.0;
      final double px = (seedX * w + math.sin((animationProgress + i) * math.pi) * 14.0) % w;
      final double py = h * (0.95 - progress * 0.90);

      // Tyndall forward scattering: brighter near the sun shaft corridor
      final double distFromCenter = ((px - w * 0.5).abs() / (w * 0.5)).clamp(0.0, 1.0);
      final double forwardScatter = 1.0 - distFromCenter * 0.65;
      final double alpha = math.sin(progress * math.pi) * 0.60 * forwardScatter;

      final Color moteColor = (i % 3 == 0)
          ? theme.crystalColor
          : (i % 2 == 0 ? theme.goldenSunburstFlare : theme.battleCrimsonFlare);

      dustPaint.color = moteColor.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), sizeMultiplier * 1.35, dustPaint);

      // Floating incandescent combat ember sparks (1 in 4 particles)
      if (i % 4 == 0) {
        final double sparkY = py - 3.5;
        final Paint sparkCore = Paint()
          ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0));
        canvas.drawCircle(Offset(px, sparkY), 0.75, sparkCore);
      }
    }
  }

  // ── 9. DYNAMIC COMBAT LIGHTING FLASH & SHOCKWAVE ───────────────────────────
  void _paintCombatLightingFlash(Canvas canvas, Size size, Rect arenaRect) {
    final double intensity = combatFlashIntensity.clamp(0.0, 1.0);

    // Radial Flash Bloom
    final Paint flashPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: intensity * 0.58),
          theme.goldenSunburstFlare.withValues(alpha: intensity * 0.36),
          theme.battleCrimsonFlare.withValues(alpha: intensity * 0.20),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.35, 0.70, 1.0],
      ).createShader(arenaRect);
    canvas.drawOval(arenaRect, flashPaint);

    // High-impact Battle Shockwave Ring
    final double ringRadius = arenaRect.width * (0.35 + (1.0 - intensity) * 0.25);
    final Rect ringRect = Rect.fromCenter(
      center: arenaRect.center,
      width: ringRadius * 2.0,
      height: ringRadius * 1.15,
    );
    final Paint shockwavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * intensity
      ..shader = SweepGradient(
        colors: <Color>[
          theme.battleCrimsonFlare.withValues(alpha: intensity * 0.80),
          theme.goldenSunburstFlare.withValues(alpha: intensity * 0.80),
          theme.battleCrimsonFlare.withValues(alpha: intensity * 0.80),
        ],
      ).createShader(ringRect);
    canvas.drawOval(ringRect, shockwavePaint);
  }

  @override
  bool shouldRepaint(covariant ColosseumArenaPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.theme.name != theme.name ||
        oldDelegate.theme.sunIntensity != theme.sunIntensity ||
        oldDelegate.theme.flareIntensity != theme.flareIntensity ||
        oldDelegate.combatFlashIntensity != combatFlashIntensity ||
        oldDelegate.showColosseumWalls != showColosseumWalls ||
        oldDelegate.showCrystals != showCrystals ||
        oldDelegate.showGodrays != showGodrays ||
        oldDelegate.showShadows != showShadows ||
        oldDelegate.showLensFlares != showLensFlares ||
        oldDelegate.showVolumetricAtmosphere != showVolumetricAtmosphere ||
        oldDelegate.effectiveShadowResolution != effectiveShadowResolution ||
        oldDelegate.effectiveShadowCascadeCount != effectiveShadowCascadeCount ||
        oldDelegate.isEcoOrLowTier != isEcoOrLowTier ||
        oldDelegate.isMidTier != isMidTier ||
        oldDelegate.gladiatorSlots.length != gladiatorSlots.length;
  }
}

/// Standalone mobile-optimized Colosseum Arena Lighting widget featuring 2027 Aion 2 Obsidian-Glass,
/// dynamic lighting controller support, optional glassmorphic HUD, haptic feedback,
/// and adaptive quality scaling / zero-jank shader preloading hooks.
class ColosseumArenaLighting extends StatefulWidget {
  const ColosseumArenaLighting({
    super.key,
    required this.theme,
    this.height = 220.0,
    this.gladiatorSlots = const <GladiatorShadowSlot>[],
    this.child,
    this.combatFlash = 0.0,
    this.controller,
    this.showAtmosphereHud = false,
    this.enableHaptics = true,
    this.onAtmosphereChanged,
    this.scaler,
    this.preloader,
    this.qualitySettings,
    this.enablePreload = true,
  });

  final ArenaLightingTheme theme;
  final double height;
  final List<GladiatorShadowSlot> gladiatorSlots;
  final Widget? child;
  final double combatFlash;
  final ColosseumLightingController? controller;
  final bool showAtmosphereHud;
  final bool enableHaptics;
  final ValueChanged<ColosseumAtmosphere>? onAtmosphereChanged;

  /// Optional AdaptiveQualityScaler hook for dynamic runtime quality scaling.
  final AdaptiveQualityScaler? scaler;

  /// Optional ZeroJankPreloader instance for asynchronous time-sliced shader warming.
  final ZeroJankPreloader? preloader;

  /// Optional static QualitySettings snapshot.
  final QualitySettings? qualitySettings;

  /// Whether to asynchronously pre-warm lighting shaders on initialization.
  final bool enablePreload;

  /// Pre-warms arena lighting shaders (floor gradients, godrays, crystal caustics, and shadow blurs)
  /// using [ZeroJankPreloader.instance.preloadShader] within time-sliced (<2ms per frame) budgets.
  static Future<bool> preloadArenaShaders({
    ZeroJankPreloader? preloader,
    ArenaLightingTheme? theme,
  }) async {
    final ZeroJankPreloader loader = preloader ?? ZeroJankPreloader.instance;
    final ArenaLightingTheme activeTheme = theme ?? ArenaLightingTheme.sanctumCelestial();

    return loader.preloadShader<bool>(
      id: 'shader_colosseum_arena_lighting_${activeTheme.name.hashCode}',
      priority: PreloadPriority.criticalHud,
      tags: const <String>{'pvp', 'arena', 'lighting', 'shaders'},
      shaderWarmupLoader: (PreloadExecutionContext ctx) async {
        final Rect bounds = const Rect.fromLTWH(0, 0, 512, 512);

        // Slice 1: Sky and arena floor radial/linear shaders (<2ms slice)
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            activeTheme.ambientColor.withValues(alpha: 0.95),
            const Color(0xFF060810),
            activeTheme.shadowColor,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(bounds);

        RadialGradient(
          center: const Alignment(0.2, 0.2),
          radius: 0.95,
          colors: const <Color>[
            Color(0xFF232B3E),
            Color(0xFF151A27),
            Color(0xFF0D101A),
          ],
          stops: const <double>[0.0, 0.65, 1.0],
        ).createShader(bounds);

        if (ctx.shouldYield()) {
          await ctx.yieldControl();
        }

        // Slice 2: Crystal rim sweep gradient & floor caustic pools (<2ms slice)
        SweepGradient(
          center: Alignment.center,
          colors: <Color>[
            activeTheme.crystalColor,
            activeTheme.secondaryCrystalColor,
            activeTheme.sunColor.withValues(alpha: 0.85),
            activeTheme.crystalColor,
          ],
        ).createShader(bounds);

        RadialGradient(
          colors: <Color>[
            activeTheme.crystalColor.withValues(alpha: 0.38),
            activeTheme.crystalColor.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(bounds);

        if (ctx.shouldYield()) {
          await ctx.yieldControl();
        }

        // Slice 3: Volumetric sun shaft beam shaders (<2ms slice)
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            activeTheme.sunColor.withValues(alpha: 0.2),
            activeTheme.sunColor.withValues(alpha: 0.1),
            activeTheme.secondaryCrystalColor.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.35, 0.75, 1.0],
        ).createShader(bounds);

        // Slice 4: Dynamic directional shadow penumbra & combat flash shaders (<2ms slice)
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            activeTheme.shadowColor.withValues(alpha: 0.75),
            activeTheme.shadowColor.withValues(alpha: 0.45),
            activeTheme.shadowColor.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.65, 1.0],
        ).createShader(bounds);

        RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.45),
            activeTheme.sunColor.withValues(alpha: 0.25),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.4, 1.0],
        ).createShader(bounds);

        return true;
      },
    );
  }

  @override
  State<ColosseumArenaLighting> createState() => _ColosseumArenaLightingState();
}

class _ColosseumArenaLightingState extends State<ColosseumArenaLighting>
    with TickerProviderStateMixin {
  late AnimationController _ambientController;
  late AnimationController _themeTransitionController;
  late ArenaLightingTheme _currentTheme;
  late ArenaLightingTheme _targetTheme;
  AdaptiveQualityScaler? _scaler;

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.controller?.theme ?? widget.theme;
    _targetTheme = _currentTheme;

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    _themeTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    widget.controller?.addListener(_onControllerChanged);

    _scaler = widget.scaler;
    _scaler?.addListener(_onScalerChanged);

    if (widget.enablePreload) {
      ColosseumArenaLighting.preloadArenaShaders(
        preloader: widget.preloader ?? ZeroJankPreloader.instance,
        theme: _currentTheme,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ColosseumArenaLighting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
    if (widget.theme != oldWidget.theme && widget.controller == null) {
      _animateToTheme(widget.theme);
    }
    if (widget.scaler != oldWidget.scaler) {
      oldWidget.scaler?.removeListener(_onScalerChanged);
      _scaler = widget.scaler;
      _scaler?.addListener(_onScalerChanged);
    }
    if (widget.enablePreload && (widget.theme.name != oldWidget.theme.name)) {
      ColosseumArenaLighting.preloadArenaShaders(
        preloader: widget.preloader ?? ZeroJankPreloader.instance,
        theme: widget.theme,
      );
    }
  }

  void _onControllerChanged() {
    if (widget.controller != null && widget.controller!.theme != _targetTheme) {
      _animateToTheme(widget.controller!.theme);
    } else {
      setState(() {});
    }
  }

  void _onScalerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _animateToTheme(ArenaLightingTheme nextTheme) {
    _currentTheme = _interpolatedTheme();
    _targetTheme = nextTheme;
    _themeTransitionController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _currentTheme = _targetTheme;
        });
      }
    });
  }

  ArenaLightingTheme _interpolatedTheme() {
    if (!_themeTransitionController.isAnimating) {
      return _targetTheme;
    }
    return ArenaLightingTheme.lerp(
      _currentTheme,
      _targetTheme,
      Curves.easeInOutCubic.transform(_themeTransitionController.value),
    );
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _scaler?.removeListener(_onScalerChanged);
    _ambientController.dispose();
    _themeTransitionController.dispose();
    super.dispose();
  }

  void _handleAtmosphereSelect(ColosseumAtmosphere atmosphere) {
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    final ArenaLightingTheme newTheme = ArenaLightingTheme.fromAtmosphere(atmosphere);
    if (widget.controller != null) {
      widget.controller!.setTheme(newTheme);
    } else {
      _animateToTheme(newTheme);
    }
    widget.onAtmosphereChanged?.call(atmosphere);
  }

  @override
  Widget build(BuildContext context) {
    final double effectiveCombatFlash =
        widget.controller != null ? widget.controller!.combatFlash : widget.combatFlash;

    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _ambientController,
              _themeTransitionController,
              if (widget.controller != null) widget.controller!,
              if (_scaler != null) _scaler!,
            ]),
            builder: (BuildContext context, Widget? child) {
              final QualitySettings? effectiveSettings =
                  widget.qualitySettings ?? _scaler?.currentSettings;
              return CustomPaint(
                painter: ColosseumArenaPainter(
                  animationProgress: _ambientController.value,
                  theme: _interpolatedTheme(),
                  gladiatorSlots: widget.gladiatorSlots,
                  combatFlashIntensity: effectiveCombatFlash,
                  scaler: _scaler,
                  qualitySettings: effectiveSettings,
                  shadowResolution: _scaler?.currentSettings.shadowResolution,
                  shadowCascadeCount: _scaler?.currentSettings.shadowCascadeCount,
                ),
              );
            },
          ),
          if (widget.child != null) widget.child!,
          if (widget.showAtmosphereHud) _buildGlassmorphicAtmosphereHud(),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicAtmosphereHud() {
    return Positioned(
      top: 10.0,
      left: 12.0,
      right: 12.0,
      child: SafeArea(
        top: true,
        bottom: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: const Color(0xFF090D18).withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildAtmosphereButton(
                    atmosphere: ColosseumAtmosphere.sanctumCelestial,
                    label: 'Sanctum',
                    accentColor: const Color(0xFFFFE082),
                  ),
                  _buildAtmosphereButton(
                    atmosphere: ColosseumAtmosphere.abyssalEclipse,
                    label: 'Abyss',
                    accentColor: const Color(0xFFFF3D00),
                  ),
                  _buildAtmosphereButton(
                    atmosphere: ColosseumAtmosphere.obsidianChasm,
                    label: 'Obsidian',
                    accentColor: const Color(0xFF64FFDA),
                  ),
                  _buildAtmosphereButton(
                    atmosphere: ColosseumAtmosphere.dawnGladiator,
                    label: 'Dawn',
                    accentColor: const Color(0xFFFFB300),
                  ),
                  _buildAtmosphereButton(
                    atmosphere: ColosseumAtmosphere.crimsonBattle,
                    label: 'Crimson',
                    accentColor: const Color(0xFFFF3366),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAtmosphereButton({
    required ColosseumAtmosphere atmosphere,
    required String label,
    required Color accentColor,
  }) {
    final bool isSelected = _targetTheme.name ==
        ArenaLightingTheme.fromAtmosphere(atmosphere).name;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Select $label Arena Lighting Atmosphere',
      child: Tooltip(
        message: '$label Colosseum Atmosphere',
        child: InkWell(
          onTap: () => _handleAtmosphereSelect(atmosphere),
          borderRadius: BorderRadius.circular(10.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.24)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.70)
                    : Colors.transparent,
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.70),
                fontSize: 11.0,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
