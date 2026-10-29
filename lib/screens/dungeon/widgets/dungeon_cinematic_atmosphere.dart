import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gkk_flutter/core/lighting/dungeon_light_system.dart' as dls;
import 'package:gkk_flutter/core/vfx/ground_decal_system.dart' as gds;

import 'dungeon_battle_effects.dart';
import 'dungeon_cave_theme.dart';

/// ----------------------------------------------------------------------------
/// Production 2027 AAA Cinematic Dungeon Atmosphere & 3D Combat Arena
/// Standard: Requirement R3 (Dungeon Lighting, Decals & Game Feel) & R5 (Integration)
/// ----------------------------------------------------------------------------

/// Configuration for arena torches.
class ArenaTorchConfig {
  const ArenaTorchConfig({
    required this.id,
    required this.worldPosition,
    required this.color,
    this.baseIntensity = 2.4,
    this.minIntensity = 1.6,
    this.maxIntensity = 3.2,
    this.radius = 8.5,
    this.flickerSpeed = 1.0,
    this.flickerPhase = 0.0,
    this.wobbleRadius = 0.22,
    this.shadowHardness = 0.55,
  });

  final String id;
  final dls.Vector3D worldPosition;
  final Color color;
  final double baseIntensity;
  final double minIntensity;
  final double maxIntensity;
  final double radius;
  final double flickerSpeed;
  final double flickerPhase;
  final double wobbleRadius;
  final double shadowHardness;
}

/// Perspective projection camera parameters for the 3D dungeon arena.
class Arena3DCamera {
  const Arena3DCamera({
    this.pitch = 0.52, // ~30 degrees down-angle
    this.height = 4.2,
    this.distance = 7.0,
    this.fov = 1.15,
    this.horizonYRatio = 0.42,
  });

  final double pitch;
  final double height;
  final double distance;
  final double fov;
  final double horizonYRatio;

  /// Project a 3D world position (X: left-right, Y: up, Z: depth) to 2D screen coordinates.
  Offset project(dls.Vector3D world, Size viewport) {
    final double cx = viewport.width * 0.5;
    final double cy = viewport.height * horizonYRatio;

    // Camera view transform:
    final double cosP = math.cos(pitch);
    final double sinP = math.sin(pitch);

    // Relative to camera position (0, height, -distance)
    final double rx = world.x;
    final double ry = world.y - height;
    final double rz = world.z + distance;

    // Pitch rotation around X axis
    final double viewY = ry * cosP - rz * sinP;
    final double viewZ = ry * sinP + rz * cosP;

    if (viewZ <= 0.2) {
      return Offset(cx + rx * 50, cy);
    }

    final double factor = (viewport.height * fov) / viewZ;
    final double screenX = cx + rx * factor;
    final double screenY = cy - viewY * factor;

    return Offset(screenX, screenY);
  }

  /// Scale factor for objects at given world depth Z.
  double depthScale(double worldZ, Size viewport) {
    final double rz = worldZ + distance;
    final double cosP = math.cos(pitch);
    final double viewZ = rz * cosP;
    if (viewZ <= 0.2) return 0.2;
    return (viewport.height * fov * 0.0018) / viewZ;
  }
}

/// Structure representing a soft shadow occluder (pillar, statue, battle monolith).
class ArenaShadowOccluder {
  const ArenaShadowOccluder({
    required this.center,
    required this.radius,
    required this.height,
  });

  final dls.Vector3D center;
  final double radius;
  final double height;
}

/// Controller to trigger dynamic combat decals, spell light flares, and monitor atmosphere state.
class DungeonAtmosphereController extends ChangeNotifier {
  DungeonAtmosphereController({
    this.maxDecals = 48,
    int noiseSeed = 1337,
  })  : decalSystem = gds.GroundDecalSystem(maxDecals: maxDecals),
        lightSystem = dls.DungeonLightSystem(maxLights: 8),
        noise = dls.PerlinNoiseGenerator(seed: noiseSeed) {
    _initDefaultTorches();
    _seedAtmosphericDecals();
  }

  final int maxDecals;
  final gds.GroundDecalSystem decalSystem;
  final dls.DungeonLightSystem lightSystem;
  final dls.PerlinNoiseGenerator noise;

  double _timeSeconds = 0.0;
  double get timeSeconds => _timeSeconds;

  final List<ArenaTorchConfig> _torches = <ArenaTorchConfig>[];
  List<ArenaTorchConfig> get torches => List.unmodifiable(_torches);

  final List<ArenaShadowOccluder> occluders = <ArenaShadowOccluder>[
    // Left arch pillar
    const ArenaShadowOccluder(
      center: dls.Vector3D(-3.6, 1.8, 4.0),
      radius: 0.55,
      height: 3.6,
    ),
    // Right arch pillar
    const ArenaShadowOccluder(
      center: dls.Vector3D(3.6, 1.8, 4.0),
      radius: 0.55,
      height: 3.6,
    ),
    // Central combat arena monoliths
    const ArenaShadowOccluder(
      center: dls.Vector3D(-2.0, 0.9, 1.5),
      radius: 0.35,
      height: 1.8,
    ),
    const ArenaShadowOccluder(
      center: dls.Vector3D(2.0, 0.9, 1.5),
      radius: 0.35,
      height: 1.8,
    ),
    // Central ancient altar monolith
    const ArenaShadowOccluder(
      center: dls.Vector3D(0.0, 1.1, 5.0),
      radius: 0.6,
      height: 2.2,
    ),
  ];

  void _initDefaultTorches() {
    _torches.clear();
    // Warm flame left torch
    _torches.add(
      const ArenaTorchConfig(
        id: 'torch_left',
        worldPosition: dls.Vector3D(-3.5, 2.5, 3.8),
        color: Color(0xFFFF851B), // Amber flame
        baseIntensity: 2.6,
        radius: 9.5,
        flickerSpeed: 1.1,
        flickerPhase: 0.0,
      ),
    );

    // Golden flame right torch
    _torches.add(
      const ArenaTorchConfig(
        id: 'torch_right',
        worldPosition: dls.Vector3D(3.5, 2.5, 3.8),
        color: Color(0xFFFFB300), // Golden fire
        baseIntensity: 2.6,
        radius: 9.5,
        flickerSpeed: 0.95,
        flickerPhase: 2.14,
      ),
    );

    // High arch central brazer / ancient rune light
    _torches.add(
      const ArenaTorchConfig(
        id: 'brazer_center',
        worldPosition: dls.Vector3D(0.0, 3.8, 6.0),
        color: Color(0xFFFF5722), // Fiery deep orange
        baseIntensity: 2.0,
        radius: 11.0,
        flickerSpeed: 0.8,
        flickerPhase: 4.28,
        wobbleRadius: 0.15,
      ),
    );

    for (final ArenaTorchConfig t in _torches) {
      lightSystem.addLight(
        dls.DungeonLight(
          id: t.id,
          position: t.worldPosition,
          color: t.color,
          intensity: t.baseIntensity,
          radius: t.radius,
          type: dls.LightType.torch,
          minIntensity: t.minIntensity,
          maxIntensity: t.maxIntensity,
          flickerSpeed: t.flickerSpeed,
          flickerPhase: t.flickerPhase,
          maxWobbleRadius: t.wobbleRadius,
          shadowHardness: t.shadowHardness,
        ),
      );
    }
  }

  void _seedAtmosphericDecals() {
    // Ancient cracked flagstones from prior siege battles
    decalSystem.spawnCrackedEarth(
      position: const gds.Vector3D(-1.2, 0.0, 2.0),
      radius: 1.2,
      lifetime: double.infinity,
      color: const Color(0xFF1E242B),
    );

    decalSystem.spawnCrackedEarth(
      position: const gds.Vector3D(1.8, 0.0, 3.2),
      radius: 1.0,
      lifetime: double.infinity,
      color: const Color(0xFF1A1F26),
    );

    // Old dried battle scorch mark
    decalSystem.spawnScorchMark(
      position: const gds.Vector3D(0.5, 0.0, 1.8),
      radius: 1.0,
      lifetime: double.infinity,
      color: const Color(0xFF140E0C),
    );

    // Ancient dried blood pool
    decalSystem.spawnBloodSplatter(
      position: const gds.Vector3D(-2.2, 0.0, 3.5),
      radius: 0.8,
      lifetime: double.infinity,
      color: const Color(0xFF4A0A10),
    );
  }

  /// Advance time, update flicker physics, and fade active ground decals.
  void update(double dt) {
    _timeSeconds += dt;
    lightSystem.update(dt);
    decalSystem.update(dt);
    notifyListeners();
  }

  /// Spawn visceral crimson blood splatter at arena position on combat hit.
  void triggerBloodSplatter({
    gds.Vector3D? position,
    double radius = 1.4,
    double lifetime = 14.0,
  }) {
    final double px = (math.Random().nextDouble() - 0.5) * 3.0;
    final double pz = 1.2 + math.Random().nextDouble() * 2.5;
    decalSystem.spawnBloodSplatter(
      position: position ?? gds.Vector3D(px, 0.0, pz),
      radius: radius,
      lifetime: lifetime,
      color: const Color(0xFF880815),
    );
    notifyListeners();
  }

  /// Spawn fiery charred scorch mark on spell cast / explosive hit.
  void triggerScorchMark({
    gds.Vector3D? position,
    double radius = 2.2,
    double lifetime = 16.0,
  }) {
    final double px = (math.Random().nextDouble() - 0.5) * 3.5;
    final double pz = 1.0 + math.Random().nextDouble() * 3.0;
    decalSystem.spawnScorchMark(
      position: position ?? gds.Vector3D(px, 0.0, pz),
      radius: radius,
      lifetime: lifetime,
      color: const Color(0xFF19110E),
    );

    // Cast a dynamic explosive spell light flash that expands and cools
    lightSystem.castFieryExplosion(
      id: 'spell_flare_${DateTime.now().microsecondsSinceEpoch}',
      position: dls.Vector3D(px, 1.2, pz),
      peakIntensity: 4.5,
      maxRadius: 180.0,
      duration: 1.2,
      coreColor: const Color(0xFFFFD54F),
    );
    notifyListeners();
  }

  /// Spawn cracked flagstone fissure on heavy physical hammer / strike impact.
  void triggerCrackedFlagstones({
    gds.Vector3D? position,
    double radius = 2.0,
    double lifetime = 18.0,
  }) {
    final double px = (math.Random().nextDouble() - 0.5) * 2.8;
    final double pz = 1.2 + math.Random().nextDouble() * 2.6;
    decalSystem.spawnCrackedEarth(
      position: position ?? gds.Vector3D(px, 0.0, pz),
      radius: radius,
      lifetime: lifetime,
      color: const Color(0xFF161B22),
    );
    notifyListeners();
  }

  /// Spawn weapon slash gouge with friction heat.
  void triggerSlashGouge({
    gds.Vector3D? position,
    gds.Vector3D? strikeDir,
    double length = 2.4,
    double lifetime = 15.0,
  }) {
    final double px = (math.Random().nextDouble() - 0.5) * 2.5;
    final double pz = 1.0 + math.Random().nextDouble() * 2.5;
    final double angle = math.Random().nextDouble() * math.pi;
    final gds.Vector3D dir = strikeDir ??
        gds.Vector3D(math.cos(angle), 0.0, math.sin(angle)).normalized;

    decalSystem.spawnSlashGouge(
      position: position ?? gds.Vector3D(px, 0.0, pz),
      strikeDirection: dir,
      length: length,
      width: 0.45,
      lifetime: lifetime,
      color: const Color(0xFF221A15),
    );
    notifyListeners();
  }

  /// Cast a dynamic magical spell flare or explosion that illuminates walls, floor, and occluders.
  void triggerMagicSpellFlare({
    dls.Vector3D? position,
    Color color = const Color(0xFF9C27B0),
    double peakIntensity = 4.2,
    double maxRadius = 160.0,
    double duration = 1.4,
  }) {
    final double px = (math.Random().nextDouble() - 0.5) * 3.0;
    final double pz = 1.2 + math.Random().nextDouble() * 3.0;
    lightSystem.castFieryExplosion(
      id: 'magic_flare_${DateTime.now().microsecondsSinceEpoch}',
      position: position ?? dls.Vector3D(px, 1.4, pz),
      peakIntensity: peakIntensity,
      maxRadius: maxRadius,
      duration: duration,
      coreColor: color,
    );
    notifyListeners();
  }

  /// Spawn or pulse an ancient arcane rune with rhythmic breathing and chromatic aura.
  dls.DungeonLight triggerArcaneRunePulse({
    String? id,
    dls.Vector3D? position,
    Color color = const Color(0xFF00E5FF),
    double intensity = 2.4,
    double radius = 130.0,
    double pulseSpeed = 1.5,
  }) {
    final String runeId = id ?? 'arcane_rune_${DateTime.now().microsecondsSinceEpoch}';
    final dls.DungeonLight rune = lightSystem.castPulsingRune(
      id: runeId,
      position: position ?? const dls.Vector3D(0.0, 1.2, 3.8),
      runeColor: color,
      baseIntensity: intensity,
      radius: radius,
      pulseFreq: pulseSpeed,
      shadowHardness: 0.75,
    );
    notifyListeners();
    return rune;
  }

  /// Spawn a floating ethereal soul orb that orbits the arena in 3D with harmonic shimmer.
  dls.DungeonLight triggerEtherealSoulOrb({
    String? id,
    dls.Vector3D? orbitCenter,
    Color color = const Color(0xFF7C4DFF),
    double intensity = 2.0,
    double radius = 110.0,
    double orbitSpeed = 1.2,
  }) {
    final String soulId = id ?? 'soul_orb_${DateTime.now().microsecondsSinceEpoch}';
    final dls.DungeonLight soul = lightSystem.castEtherealSoul(
      id: soulId,
      origin: orbitCenter ?? const dls.Vector3D(0.0, 1.8, 3.5),
      spectralColor: color,
      intensity: intensity,
      radius: radius,
      orbitSpeed: orbitSpeed,
      shadowHardness: 0.6,
    );
    notifyListeners();
    return soul;
  }

  /// Cast an instant radiant divine celestial flash with rapid falloff.
  void triggerCelestialFlash({
    dls.Vector3D? position,
    Color color = const Color(0xFFFFF9C4),
    double peakIntensity = 5.2,
    double duration = 0.8,
  }) {
    final double px = (math.Random().nextDouble() - 0.5) * 2.5;
    final double pz = 1.0 + math.Random().nextDouble() * 2.5;
    lightSystem.castFieryExplosion(
      id: 'celestial_flash_${DateTime.now().microsecondsSinceEpoch}',
      position: position ?? dls.Vector3D(px, 2.2, pz),
      peakIntensity: peakIntensity,
      maxRadius: 220.0,
      duration: duration,
      coreColor: color,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    lightSystem.clear();
    super.dispose();
  }
}

/// Atmospheric Mist Particle Model for volumetric multi-tier fog.
class MistWisp {
  const MistWisp({
    required this.baseX,
    required this.baseZ,
    required this.speed,
    required this.scaleX,
    required this.scaleY,
    required this.alpha,
    required this.tier,
    required this.phase,
  });

  final double baseX;
  final double baseZ;
  final double speed;
  final double scaleX;
  final double scaleY;
  final double alpha;
  final int tier; // 0: ground-hugging floor mist, 1: mid-level vapor, 2: cavern vault haze
  final double phase;
}

/// Model for 3D atmospheric embers and sparks drifting through the dungeon arena.
class ArenaEmberParticle {
  const ArenaEmberParticle({
    required this.seedX,
    required this.seedZ,
    required this.speedY,
    required this.swaySpeed,
    required this.swayRadius,
    required this.size,
    required this.phase,
    required this.isMysticSpore,
  });

  final double seedX;
  final double seedZ;
  final double speedY;
  final double swaySpeed;
  final double swayRadius;
  final double size;
  final double phase;
  final bool isMysticSpore;
}

/// Model for volumetric mystical light shafts / crepuscular god rays.
class MysticalLightShaft {
  const MysticalLightShaft({
    required this.originXRatio,
    required this.angleRadians,
    required this.topWidth,
    required this.bottomWidth,
    required this.lengthRatio,
    required this.baseAlpha,
    required this.pulseSpeed,
    required this.pulsePhase,
  });

  final double originXRatio;
  final double angleRadians;
  final double topWidth;
  final double bottomWidth;
  final double lengthRatio;
  final double baseAlpha;
  final double pulseSpeed;
  final double pulsePhase;
}

/// The master 3D Dungeon Arena Custom Painter.
/// Renders:
/// 1. 3D perspective flagstone floor with foreshortening & normal relief
/// 2. Dynamic torch light irradiance fields with Perlin flicker
/// 3. Soft shadow projection lobes from pillars & occluders
/// 4. Projected ground decals (blood splatters, scorch marks, cracked flagstones, slash gouges)
/// 5. Mystical crepuscular light shafts cutting through high ceiling vaults
/// 6. Multi-tier atmospheric volumetric mist with torch light in-scattering
/// 7. 3D drifting ember sparks & arcane cavern spores
/// 8. Multi-stage cinematic vignette and atmospheric depth grading
class DungeonArena3DPainter extends CustomPainter {
  DungeonArena3DPainter({
    required this.controller,
    required this.camera,
    required this.theme,
    this.showTorches = true,
    this.showArena3D = true,
    this.showMist = true,
    this.showDecals = true,
    this.showDynamicShadows = true,
    this.showWallShadows = true,
    this.showEmbers = true,
    this.showLightShafts = true,
    this.intensityMultiplier = 1.0,
  }) : super(repaint: controller);

  final DungeonAtmosphereController controller;
  final Arena3DCamera camera;
  final CaveCardTheme theme;
  final bool showTorches;
  final bool showArena3D;
  final bool showMist;
  final bool showDecals;
  final bool showDynamicShadows;
  final bool showWallShadows;
  final bool showEmbers;
  final bool showLightShafts;
  final double intensityMultiplier;

  static final List<MistWisp> wisps = _generateMistWisps();
  static final List<ArenaEmberParticle> embers = _generateArenaEmbers();
  static final List<MysticalLightShaft> lightShafts = _generateLightShafts();

  static List<MistWisp> _generateMistWisps() {
    final List<MistWisp> list = <MistWisp>[];
    // 32 deterministic procedural mist wisps across 3 atmospheric tiers
    for (int i = 0; i < 32; ++i) {
      final double seed = ((i * 73.19) % 100.0) / 100.0;
      final double x = (seed * 18.0) - 9.0;
      final double z = 1.2 + (((i * 37.4) % 100.0) / 100.0) * 8.0;
      final int tier = i % 3;
      final double speed = tier == 0
          ? 0.18 + (i % 4) * 0.04
          : (tier == 1 ? 0.28 + (i % 5) * 0.06 : 0.20 + (i % 3) * 0.05);
      final double scaleX = tier == 0
          ? 240.0 + (i % 6) * 35.0
          : (tier == 1 ? 180.0 + (i % 7) * 25.0 : 320.0 + (i % 5) * 40.0);
      final double scaleY = tier == 0
          ? 32.0 + (i % 4) * 8.0
          : (tier == 1 ? 42.0 + (i % 5) * 12.0 : 64.0 + (i % 4) * 16.0);
      final double alpha = tier == 0
          ? 0.14 + (i % 5) * 0.02
          : (tier == 1 ? 0.10 + (i % 6) * 0.02 : 0.08 + (i % 4) * 0.02);
      final double phase = (i * 1.618) % (math.pi * 2);
      list.add(
        MistWisp(
          baseX: x,
          baseZ: z,
          speed: speed,
          scaleX: scaleX,
          scaleY: scaleY,
          alpha: alpha,
          tier: tier,
          phase: phase,
        ),
      );
    }
    return list;
  }

  static List<ArenaEmberParticle> _generateArenaEmbers() {
    final List<ArenaEmberParticle> list = <ArenaEmberParticle>[];
    // 32 deterministic procedural embers and arcane spores
    for (int i = 0; i < 32; ++i) {
      final double seed = ((i * 59.71) % 100.0) / 100.0;
      final double x = (seed * 13.0) - 6.5;
      final double z = 0.9 + (((i * 43.17) % 100.0) / 100.0) * 7.5;
      final double speedY = 0.16 + (i % 7) * 0.035;
      final double swaySpeed = 1.2 + (i % 5) * 0.35;
      final double swayRadius = 0.25 + (i % 4) * 0.12;
      final double size = 0.9 + (i % 5) * 0.45;
      final double phase = (i * 2.399) % (math.pi * 2);
      final bool isMysticSpore = (i % 6) == 0;
      list.add(
        ArenaEmberParticle(
          seedX: x,
          seedZ: z,
          speedY: speedY,
          swaySpeed: swaySpeed,
          swayRadius: swayRadius,
          size: size,
          phase: phase,
          isMysticSpore: isMysticSpore,
        ),
      );
    }
    return list;
  }

  static List<MysticalLightShaft> _generateLightShafts() {
    return const <MysticalLightShaft>[
      MysticalLightShaft(
        originXRatio: 0.22,
        angleRadians: 0.54,
        topWidth: 48.0,
        bottomWidth: 195.0,
        lengthRatio: 0.92,
        baseAlpha: 0.16,
        pulseSpeed: 0.95,
        pulsePhase: 0.0,
      ),
      MysticalLightShaft(
        originXRatio: 0.42,
        angleRadians: 0.46,
        topWidth: 62.0,
        bottomWidth: 240.0,
        lengthRatio: 0.88,
        baseAlpha: 0.18,
        pulseSpeed: 0.80,
        pulsePhase: 1.84,
      ),
      MysticalLightShaft(
        originXRatio: 0.64,
        angleRadians: -0.42,
        topWidth: 42.0,
        bottomWidth: 175.0,
        lengthRatio: 0.82,
        baseAlpha: 0.15,
        pulseSpeed: 1.10,
        pulsePhase: 3.52,
      ),
      MysticalLightShaft(
        originXRatio: 0.82,
        angleRadians: -0.52,
        topWidth: 70.0,
        bottomWidth: 265.0,
        lengthRatio: 0.95,
        baseAlpha: 0.13,
        pulseSpeed: 0.72,
        pulsePhase: 4.98,
      ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double t = controller.timeSeconds;

    // 1. Dark cavern background fill
    final Rect fullRect = Offset.zero & size;
    final Paint bgPaint = Paint()..color = BattlePalette.carbonVoid;
    canvas.drawRect(fullRect, bgPaint);

    if (showArena3D) {
      _paint3DStoneWalls(canvas, size, t);
      _paint3DGroundPlane(canvas, size, t);
    }

    if (showDynamicShadows) {
      _paintSoftShadows(canvas, size, t);
    }

    if (showDecals) {
      _paintGroundDecals(canvas, size);
    }

    if (showTorches) {
      _paintTorchIrradianceAndBeams(canvas, size, t);
    }

    if (showLightShafts) {
      _paintMysticalLightShafts(canvas, size, t);
    }

    if (showMist) {
      _paintAtmosphericMist(canvas, size, t);
    }

    if (showEmbers) {
      _paintEmberDrifts(canvas, size, t);
    }

    _paintCinematicVignette(canvas, size);
  }

  // ---------------------------------------------------------------------------
  // 1a. 3D Rear Stone Wall Masonry & Arch Vaulting with Dynamic Light Irradiance
  // ---------------------------------------------------------------------------
  void _paint3DStoneWalls(Canvas canvas, Size size, double time) {
    final double horizonY = size.height * camera.horizonYRatio;
    if (horizonY <= 0) return;

    // Rear wall rectangle: from top of viewport down to horizon line
    final Rect wallRect = Rect.fromLTRB(0, 0, size.width, horizonY + 2.0);

    // Deep abyssal stone masonry gradient
    final Paint wallBasePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, horizonY),
        <Color>[
          const Color(0xFF030407),
          const Color(0xFF080C13),
          const Color(0xFF0E131E),
        ],
        <double>[0.0, 0.5, 1.0],
      );
    canvas.drawRect(wallRect, wallBasePaint);

    // Dynamic Light Irradiance on Stone Wall (Torches & Magic Lights)
    final List<dls.DungeonLight> activeLights =
        controller.lightSystem.lights.toList();

    for (final dls.DungeonLight light in activeLights) {
      if (light.currentIntensity <= 0.05) continue;
      final dls.Vector3D lpos = light.currentPosition;
      // Project light center on rear wall plane Z = 6.8
      final Offset wallLightCenter = camera.project(
        dls.Vector3D(lpos.x, math.max(0.2, lpos.y), 6.8),
        size,
      );

      final double flicker = light.currentIntensity * intensityMultiplier;
      final double distToWall = (6.8 - lpos.z).abs();
      final double wallGlowRadius = ((light.currentRadius * 16.0 * flicker) /
              (1.0 + distToWall * 0.35))
          .clamp(35.0, 360.0);

      // Lambertian cosine attenuation against wall surface normal (0, 0, -1)
      final double nDotL = (distToWall / math.max(1.0, light.currentRadius * 0.5)).clamp(0.2, 1.0);

      final Paint wallLightPaint = Paint()
        ..shader = ui.Gradient.radial(
          wallLightCenter,
          wallGlowRadius,
          <Color>[
            light.currentColor.withValues(alpha: 0.28 * flicker * nDotL),
            light.currentColor.withValues(alpha: 0.08 * flicker * nDotL),
            light.currentColor.withValues(alpha: 0.0),
          ],
          <double>[0.0, 0.45, 1.0],
        );

      canvas.drawOval(
        Rect.fromCenter(
          center: wallLightCenter,
          width: wallGlowRadius * 2.2,
          height: wallGlowRadius * 1.8,
        ),
        wallLightPaint,
      );
    }

    // Coursed ashlar masonry horizontal seams
    final Paint mortarPaint = Paint()
      ..color = const Color(0xFF06080E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final Paint stoneHighlightPaint = Paint()
      ..color = const Color(0x1E94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    const double wallZ = 6.8;
    // Courses of stone blocks from ground Y=0 up to vault Y=5.5
    final List<double> courseHeights = <double>[0.4, 0.9, 1.5, 2.2, 3.0, 3.8, 4.7, 5.6];
    for (int c = 0; c < courseHeights.length; ++c) {
      final double wy = courseHeights[c];
      final Offset left = camera.project(dls.Vector3D(-7.0, wy, wallZ), size);
      final Offset right = camera.project(dls.Vector3D(7.0, wy, wallZ), size);

      if (left.dy <= horizonY + 2 && left.dy >= -20) {
        canvas.drawLine(left, right, mortarPaint);
        // Bevel highlight on stone upper lip
        canvas.drawLine(
          Offset(left.dx, left.dy + 1.0),
          Offset(right.dx, right.dy + 1.0),
          stoneHighlightPaint,
        );

        // Staggered vertical joints between blocks
        final double xOffset = (c % 2 == 0) ? 0.0 : 0.6;
        for (double wx = -6.0 + xOffset; wx <= 6.0; wx += 1.3) {
          final double prevY = c == 0 ? 0.0 : courseHeights[c - 1];
          final Offset bBottom = camera.project(dls.Vector3D(wx, prevY, wallZ), size);
          final Offset bTop = camera.project(dls.Vector3D(wx, wy, wallZ), size);
          if (bBottom.dy <= horizonY + 2) {
            canvas.drawLine(bBottom, bTop, mortarPaint);
          }
        }
      }
    }

    // Vaulted arch pilasters on left (X = -3.8) and right (X = 3.8)
    _paintVaultArchRibs(canvas, size, horizonY);
  }

  void _paintVaultArchRibs(Canvas canvas, Size size, double horizonY) {
    final Paint archPaint = Paint()
      ..color = const Color(0xFF090D15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final Paint archHighlight = Paint()
      ..color = const Color(0x22CBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double wallZ = 6.5;
    // Left arch column curve
    final Path leftArch = Path();
    final Offset lBase = camera.project(const dls.Vector3D(-3.8, 0.0, wallZ), size);
    final Offset lMid = camera.project(const dls.Vector3D(-3.8, 3.2, wallZ), size);
    final Offset lApex = camera.project(const dls.Vector3D(-0.5, 5.2, wallZ), size);

    leftArch.moveTo(lBase.dx, lBase.dy);
    leftArch.lineTo(lMid.dx, lMid.dy);
    leftArch.quadraticBezierTo(lMid.dx, lApex.dy, lApex.dx, lApex.dy);
    canvas.drawPath(leftArch, archPaint);
    canvas.drawPath(leftArch, archHighlight);

    // Right arch column curve
    final Path rightArch = Path();
    final Offset rBase = camera.project(const dls.Vector3D(3.8, 0.0, wallZ), size);
    final Offset rMid = camera.project(const dls.Vector3D(3.8, 3.2, wallZ), size);
    final Offset rApex = camera.project(const dls.Vector3D(0.5, 5.2, wallZ), size);

    rightArch.moveTo(rBase.dx, rBase.dy);
    rightArch.lineTo(rMid.dx, rMid.dy);
    rightArch.quadraticBezierTo(rMid.dx, rApex.dy, rApex.dx, rApex.dy);
    canvas.drawPath(rightArch, archPaint);
    canvas.drawPath(rightArch, archHighlight);
  }

  // ---------------------------------------------------------------------------
  // 1. 3D Flagstone Floor with Perspective Depth & Normal-like Relief
  // ---------------------------------------------------------------------------
  void _paint3DGroundPlane(Canvas canvas, Size size, double time) {
    final double horizonY = size.height * camera.horizonYRatio;
    final Rect groundRect = Rect.fromLTRB(0, horizonY, size.width, size.height);

    // Deep stone cavern gradient (dark horizon fading into arena floor)
    final Paint groundBasePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, horizonY),
        Offset(0, size.height),
        <Color>[
          const Color(0xFF04060A),
          const Color(0xFF0D121B),
          const Color(0xFF141A25),
        ],
        <double>[0.0, 0.45, 1.0],
      );
    canvas.drawRect(groundRect, groundBasePaint);

    // Flagstone grid in 3D perspective
    final Paint mortarPaint = Paint()
      ..color = const Color(0xFF06090F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final Paint stoneEdgeHighlight = Paint()
      ..color = const Color(0x2894A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Longitudinal mortar lines converging to vanishing point
    const int longitudinalCount = 14;
    for (int i = -longitudinalCount ~/ 2; i <= longitudinalCount ~/ 2; ++i) {
      final double wx = i * 0.85;
      final Offset nearPoint = camera.project(dls.Vector3D(wx, 0.0, 0.5), size);
      final Offset farPoint = camera.project(dls.Vector3D(wx, 0.0, 10.0), size);

      if (nearPoint.dy > horizonY && farPoint.dy >= horizonY) {
        canvas.drawLine(farPoint, nearPoint, mortarPaint);
      }
    }

    // Transverse mortar lines with foreshortened distance spacing
    for (double wz = 0.8; wz <= 9.5; wz += (0.45 + wz * 0.18)) {
      final Offset left = camera.project(dls.Vector3D(-7.0, 0.0, wz), size);
      final Offset right = camera.project(dls.Vector3D(7.0, 0.0, wz), size);

      if (left.dy >= horizonY && right.dy >= horizonY) {
        // Deep mortar groove
        canvas.drawLine(left, right, mortarPaint);
        // Bevel highlight catching overhead torch glow
        canvas.drawLine(
          Offset(left.dx, left.dy - 1.0),
          Offset(right.dx, right.dy - 1.0),
          stoneEdgeHighlight,
        );
      }
    }

    // Arena Combat Circle (ancient carved ritual perimeter)
    _paintArenaRitualCircle(canvas, size, time);
  }

  void _paintArenaRitualCircle(Canvas canvas, Size size, double time) {
    const double radius = 3.2;
    const int segments = 48;
    final Path circlePath = Path();
    final Path innerRingPath = Path();

    for (int i = 0; i <= segments; ++i) {
      final double theta = (i / segments) * math.pi * 2;
      final double wx = math.cos(theta) * radius;
      final double wz = 3.6 + math.sin(theta) * radius * 0.85;
      final Offset p = camera.project(dls.Vector3D(wx, 0.0, wz), size);

      if (i == 0) {
        circlePath.moveTo(p.dx, p.dy);
      } else {
        circlePath.lineTo(p.dx, p.dy);
      }

      // Inner rune ring
      final double inX = math.cos(theta) * (radius * 0.72);
      final double inZ = 3.6 + math.sin(theta) * (radius * 0.72 * 0.85);
      final Offset ip = camera.project(dls.Vector3D(inX, 0.0, inZ), size);
      if (i == 0) {
        innerRingPath.moveTo(ip.dx, ip.dy);
      } else {
        innerRingPath.lineTo(ip.dx, ip.dy);
      }
    }

    // Outer ring with theme glow
    final Paint ringPaint = Paint()
      ..color = theme.accentGlow.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(circlePath, ringPaint);

    final Paint innerPaint = Paint()
      ..color = theme.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(innerRingPath, innerPaint);
  }

  // ---------------------------------------------------------------------------
  // 2. Dynamic Soft Shadow Projection (Floor & Stone Walls)
  // ---------------------------------------------------------------------------
  void _paintSoftShadows(Canvas canvas, Size size, double time) {
    _paintSoftFloorShadows(canvas, size, time);
    if (showWallShadows) {
      _paintSoftWallShadows(canvas, size, time);
    }
  }

  void _paintSoftFloorShadows(Canvas canvas, Size size, double time) {
    final List<dls.DungeonLight> activeLights =
        controller.lightSystem.lights.toList();
    if (activeLights.isEmpty) return;

    for (final ArenaShadowOccluder occ in controller.occluders) {
      for (final dls.DungeonLight light in activeLights) {
        if (light.currentIntensity <= 0.05) continue;

        final dls.Vector3D lpos = light.currentPosition;
        if (lpos.y <= occ.center.y) continue;

        // Optical ray projection from light through occluder center to ground Y = 0
        final double dy = lpos.y - occ.center.y;
        final double t = lpos.y / math.max(dy, 0.05);

        final double shadowX = lpos.x + (occ.center.x - lpos.x) * t;
        final double shadowZ = lpos.z + (occ.center.z - lpos.z) * t;

        final Offset groundCenter =
            camera.project(dls.Vector3D(occ.center.x, 0.0, occ.center.z), size);
        final Offset shadowTip =
            camera.project(dls.Vector3D(shadowX, 0.0, shadowZ), size);

        // Penumbra softness width scaling with distance
        final double distToReceiver =
            dls.Vector3D(shadowX, 0.0, shadowZ).distanceTo(occ.center);
        final double penumbraWidth =
            (occ.radius * 24.0) * (1.0 + distToReceiver * 0.35);

        final double shadowLength = (shadowTip - groundCenter).distance;
        if (shadowLength <= 1.0) continue;

        final double angle =
            math.atan2(shadowTip.dy - groundCenter.dy, shadowTip.dx - groundCenter.dx);

        // Calculate dynamic shadow opacity based on light intensity & falloff
        final double distSq = lpos.distanceSquaredTo(occ.center);
        final double falloff = 1.0 / (1.0 + distSq * 0.15);
        final double shadowAlpha = (0.45 * light.currentIntensity * falloff * light.shadowHardness)
            .clamp(0.05, 0.75);

        canvas.save();
        canvas.translate(groundCenter.dx, groundCenter.dy);
        canvas.rotate(angle);

        final Rect shadowBounds =
            Rect.fromLTWH(0, -penumbraWidth * 0.5, shadowLength, penumbraWidth);

        // Soft blurred gradient shadow lobe
        final Paint shadowPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(shadowLength, 0),
            <Color>[
              Colors.black.withValues(alpha: shadowAlpha),
              Colors.black.withValues(alpha: shadowAlpha * 0.55),
              Colors.black.withValues(alpha: 0.0),
            ],
            <double>[0.0, 0.65, 1.0],
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            math.max(1.8, penumbraWidth * 0.22),
          );

        final RRect roundedLobe = RRect.fromRectAndRadius(
          shadowBounds,
          Radius.circular(penumbraWidth * 0.5),
        );
        canvas.drawRRect(roundedLobe, shadowPaint);

        canvas.restore();
      }
    }
  }

  void _paintSoftWallShadows(Canvas canvas, Size size, double time) {
    final List<dls.DungeonLight> activeLights =
        controller.lightSystem.lights.toList();
    if (activeLights.isEmpty) return;

    const double wallZ = 6.8;

    for (final ArenaShadowOccluder occ in controller.occluders) {
      if (occ.center.z >= wallZ) continue;

      for (final dls.DungeonLight light in activeLights) {
        if (light.currentIntensity <= 0.05) continue;
        final dls.Vector3D lpos = light.currentPosition;

        final double dZ = occ.center.z - lpos.z;
        if (dZ <= 0.1) continue;

        // Optical ray projection from light through occluder center to wallZ
        final double tz = (wallZ - lpos.z) / dZ;
        if (tz <= 1.0) continue;

        final double wallShadowX = lpos.x + (occ.center.x - lpos.x) * tz;
        final double wallShadowY = lpos.y + (occ.center.y - lpos.y) * tz;

        if (wallShadowY < -0.5 || wallShadowY > 8.0) continue;
        if (wallShadowX.abs() > 8.0) continue;

        final Offset shadowCenter = camera.project(
          dls.Vector3D(wallShadowX, wallShadowY, wallZ),
          size,
        );

        final double distToWall = wallZ - occ.center.z;
        final double distLightToWall = lpos.distanceTo(dls.Vector3D(wallShadowX, wallShadowY, wallZ));
        if (distLightToWall >= light.currentRadius) continue;

        final double penumbraWidth =
            (occ.radius * 26.0 * tz) * (1.0 + distToWall * 0.28);
        final double shadowHeight =
            (occ.height * 22.0 * tz).clamp(15.0, 240.0);

        final double falloff = 1.0 / (1.0 + distLightToWall * 0.2);
        final double shadowAlpha = (0.52 * light.currentIntensity * falloff * light.shadowHardness)
            .clamp(0.06, 0.82);

        final Rect shadowBounds = Rect.fromCenter(
          center: shadowCenter,
          width: penumbraWidth.clamp(12.0, 180.0),
          height: shadowHeight,
        );

        // Chromatic dispersion rim for arcane rune light shadows
        if (light.type == dls.LightType.pulsingRune) {
          final Paint chromaticPaint = Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: shadowAlpha * 0.25)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, penumbraWidth * 0.35));
          canvas.drawOval(shadowBounds.inflate(3.0), chromaticPaint);
        }

        // Primary wall shadow lobe
        final Paint wallShadowPaint = Paint()
          ..shader = ui.Gradient.radial(
            shadowCenter,
            math.max(penumbraWidth, shadowHeight) * 0.6,
            <Color>[
              Colors.black.withValues(alpha: shadowAlpha),
              Colors.black.withValues(alpha: shadowAlpha * 0.6),
              Colors.black.withValues(alpha: 0.0),
            ],
            <double>[0.0, 0.65, 1.0],
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            math.min(16.0, math.max(2.0, penumbraWidth * 0.25)),
          );

        final RRect roundedLobe = RRect.fromRectAndRadius(
          shadowBounds,
          Radius.circular(penumbraWidth * 0.4),
        );
        canvas.drawRRect(roundedLobe, wallShadowPaint);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Projected Ground Decals (Blood, Scorch, Cracked Stone, Slash Gouge)
  // ---------------------------------------------------------------------------
  void _paintGroundDecals(Canvas canvas, Size size) {
    for (final gds.DecalInstance decal in controller.decalSystem.activeDecals) {
      if (decal.currentOpacity <= 0.001) continue;

      // Project world decal position onto 3D camera screen coordinates
      final Offset screenPos = camera.project(
        dls.Vector3D(decal.position.x, decal.position.y, decal.position.z),
        size,
      );

      final double scale = camera.depthScale(decal.position.z, size);
      final double rx = decal.halfExtents.x * scale * 34.0;
      final double ry = decal.halfExtents.y * scale * 34.0 * math.sin(camera.pitch);

      if (rx <= 0.5 || ry <= 0.5) continue;

      canvas.save();
      canvas.translate(screenPos.dx, screenPos.dy);

      // Decal yaw rotation in perspective space
      final double yaw = math.atan2(decal.obb.axisY.x, decal.obb.axisY.z);
      canvas.rotate(yaw);

      final double alpha = (decal.color.a * decal.currentOpacity).clamp(0.0, 1.0);

      switch (decal.type) {
        case gds.DecalType.scorchMark:
          // Deep charred center
          final Paint sootPaint = Paint()
            ..color = decal.color.withValues(alpha: alpha * 0.88)
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: rx * 2.2, height: ry * 2.2),
            sootPaint,
          );

          // Glowing smoldering ember core
          final Paint emberPaint = Paint()
            ..color = const Color(0xFFFF4500).withValues(alpha: alpha * 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, rx * 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: rx * 1.5, height: ry * 1.5),
            emberPaint,
          );
          break;

        case gds.DecalType.bloodSplatter:
          // Visceral blood puddle
          final Paint bloodPaint = Paint()
            ..color = decal.color.withValues(alpha: alpha * 0.92)
            ..style = PaintingStyle.fill;
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: rx * 2.0, height: ry * 2.0),
            bloodPaint,
          );

          // Outer splatter micro-droplets
          final Paint dropletPaint = Paint()
            ..color = decal.color.withValues(alpha: alpha * 0.78)
            ..style = PaintingStyle.fill;

          for (int i = 0; i < 7; ++i) {
            final double angle = (i * math.pi * 2.0) / 7.0 + decal.proceduralSeed;
            final double dist = rx * (1.15 + 0.35 * math.sin(i * 2.1));
            final Offset dropPos = Offset(
              math.cos(angle) * dist,
              math.sin(angle) * dist * 0.6,
            );
            canvas.drawCircle(dropPos, math.max(1.0, rx * 0.16), dropletPaint);
          }
          break;

        case gds.DecalType.crackedEarth:
          // Fissures radiating outward
          final Paint fissurePaint = Paint()
            ..color = decal.color.withValues(alpha: alpha * 0.96)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, rx * 0.08);

          for (int i = 0; i < 6; ++i) {
            final double angle = (i * math.pi * 2.0) / 6.0 + (decal.proceduralSeed % 1.0);
            final Path path = Path()..moveTo(0, 0);
            final double midD = rx * 0.55;
            final double endD = rx * 1.05;
            final double midA = angle + 0.22 * math.sin(i * 1.8);

            path.lineTo(
              math.cos(midA) * midD,
              math.sin(midA) * midD * 0.65,
            );
            path.lineTo(
              math.cos(angle) * endD,
              math.sin(angle) * endD * 0.65,
            );
            canvas.drawPath(path, fissurePaint);
          }
          break;

        case gds.DecalType.slashGouge:
          // Directional weapon impact furrow
          final Paint gougePaint = Paint()
            ..color = decal.color.withValues(alpha: alpha * 0.9)
            ..style = PaintingStyle.fill;
          final Rect gRect = Rect.fromCenter(
            center: Offset.zero,
            width: rx * 2.6,
            height: ry * 1.2,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(gRect, Radius.circular(ry * 0.6)),
            gougePaint,
          );

          // Friction spark core line
          final Paint sparkPaint = Paint()
            ..color = const Color(0xFFFFB300).withValues(alpha: alpha * 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, ry * 0.25);
          canvas.drawLine(
            Offset(-rx * 0.85, 0),
            Offset(rx * 0.85, 0),
            sparkPaint,
          );
          break;

        case gds.DecalType.custom:
          final Paint customPaint = Paint()
            ..color = decal.color.withValues(alpha: alpha)
            ..style = PaintingStyle.fill;
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
            customPaint,
          );
          break;
      }

      canvas.restore();
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Torch Irradiance Glow, Light Shafts & Flame Tongues
  // ---------------------------------------------------------------------------
  void _paintTorchIrradianceAndBeams(Canvas canvas, Size size, double time) {
    final List<dls.DungeonLight> activeLights =
        controller.lightSystem.lights.toList();

    for (final dls.DungeonLight light in activeLights) {
      if (light.currentIntensity <= 0.05) continue;

      final Offset screenPos = camera.project(light.currentPosition, size);
      final double flicker = light.currentIntensity * intensityMultiplier;

      // Radial warm irradiance falloff field on surrounding wall/air
      final double glowRadius = (light.currentRadius * 18.0 * flicker).clamp(40.0, 320.0);
      final Paint glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          screenPos,
          glowRadius,
          <Color>[
            light.currentColor.withValues(alpha: 0.35 * flicker),
            light.currentColor.withValues(alpha: 0.12 * flicker),
            light.currentColor.withValues(alpha: 0.0),
          ],
          <double>[0.0, 0.45, 1.0],
        );
      canvas.drawCircle(screenPos, glowRadius, glowPaint);

      // Downward ground illumination pool
      final Offset groundProjection = camera.project(
        dls.Vector3D(light.currentPosition.x, 0.0, light.currentPosition.z),
        size,
      );
      final double poolRadius = (glowRadius * 0.65).clamp(30.0, 180.0);
      final Paint groundPoolPaint = Paint()
        ..shader = ui.Gradient.radial(
          groundProjection,
          poolRadius,
          <Color>[
            light.currentColor.withValues(alpha: 0.22 * flicker),
            light.currentColor.withValues(alpha: 0.06 * flicker),
            light.currentColor.withValues(alpha: 0.0),
          ],
          <double>[0.0, 0.5, 1.0],
        );
      canvas.drawOval(
        Rect.fromCenter(
          center: groundProjection,
          width: poolRadius * 2.2,
          height: poolRadius * 0.9,
        ),
        groundPoolPaint,
      );

      // Visual Light Source Entity (Torch, Arcane Rune, Explosion Flash, or Soul Orb)
      if (screenPos.dy < size.height * 0.95 && screenPos.dy > -50) {
        switch (light.type) {
          case dls.LightType.torch:
          case dls.LightType.point:
            _paintTorchBracketAndFlame(canvas, screenPos, light, flicker, time);
            break;
          case dls.LightType.pulsingRune:
            _paintArcaneRuneVisual(canvas, screenPos, light, flicker, time);
            break;
          case dls.LightType.fieryExplosion:
            _paintExplosionFlashVisual(canvas, screenPos, light, flicker, time);
            break;
          case dls.LightType.etherealSoul:
            _paintSoulWispVisual(canvas, screenPos, light, flicker, time);
            break;
        }
      }
    }
  }

  void _paintTorchBracketAndFlame(
    Canvas canvas,
    Offset pos,
    dls.DungeonLight light,
    double flicker,
    double time,
  ) {
    // 1. Ornate Forged Gothic Wall Mount & Iron Sconce Bracket
    final Paint ironPaint = Paint()
      ..color = const Color(0xFF141822)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    final Paint rivetPaint = Paint()
      ..color = const Color(0xFF2D3748)
      ..style = PaintingStyle.fill;

    // Wall backplate flange
    final Rect backplate = Rect.fromCenter(
      center: Offset(pos.dx, pos.dy + 12),
      width: 7.0,
      height: 18.0,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(backplate, const Radius.circular(2.0)), rivetPaint);
    canvas.drawCircle(Offset(pos.dx, pos.dy + 5), 1.2, ironPaint);
    canvas.drawCircle(Offset(pos.dx, pos.dy + 19), 1.2, ironPaint);

    // Curving forged iron bracket arm
    final Path bracketArm = Path()
      ..moveTo(pos.dx, pos.dy + 18)
      ..quadraticBezierTo(pos.dx - 3, pos.dy + 8, pos.dx, pos.dy + 3);
    canvas.drawPath(bracketArm, ironPaint);

    // Torch brazier bowl
    final Paint bowlPaint = Paint()
      ..color = const Color(0xFF0F131A)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy + 4), width: 15, height: 11),
      0,
      math.pi,
      true,
      bowlPaint,
    );

    // Glowing molten coal embers bed in torch bowl
    final Paint coalBedPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(pos.dx, pos.dy + 2),
        7.0,
        <Color>[
          const Color(0xFFFF9100).withValues(alpha: 0.9 * flicker),
          const Color(0xFFFF3D00).withValues(alpha: 0.7 * flicker),
          const Color(0xFF210802),
        ],
        <double>[0.0, 0.55, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy + 2), width: 13, height: 5.5),
      coalBedPaint,
    );

    // 2. Multi-octave flame turbulence via Perlin noise & high-frequency harmonics
    final double noiseWobble = controller.noise.noise2D(
      light.position.x * 0.5 + pos.dx * 0.01,
      time * 4.6 + light.flickerPhase,
    ) * 3.8;
    final double flameWobble = math.sin(time * 19.0 + light.flickerPhase) * 1.6 +
        math.sin(time * 31.0 + light.flickerPhase * 2.0) * 0.8 +
        noiseWobble;
    final double flameHeight = (19.0 * flicker).clamp(11.0, 34.0);

    // 3. Expanding thermal heat shimmer rings rising above torch
    for (int r = 0; r < 2; ++r) {
      final double shimmerCycle = (time * 1.6 + r * 0.5 + light.flickerPhase * 0.15) % 1.0;
      final double ringY = pos.dy - flameHeight * 1.1 - shimmerCycle * 22.0;
      final double ringRadius = 5.0 + shimmerCycle * 14.0;
      final double ringAlpha = ((1.0 - shimmerCycle) * 0.12 * flicker).clamp(0.0, 1.0);
      if (ringAlpha > 0.01) {
        final Paint shimmerPaint = Paint()
          ..color = const Color(0xFFFFCC80).withValues(alpha: ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(pos.dx + flameWobble * 0.6, ringY), width: ringRadius * 2.0, height: ringRadius * 0.8),
          shimmerPaint,
        );
      }
    }

    // 4. Outer thermal combustion mantle (broad warm glow)
    final Path outerMantle = Path()
      ..moveTo(pos.dx - 6.5, pos.dy + 1)
      ..quadraticBezierTo(
        pos.dx - 5.5 + flameWobble * 0.7,
        pos.dy - flameHeight * 0.55,
        pos.dx + flameWobble * 1.2,
        pos.dy - flameHeight * 1.15,
      )
      ..quadraticBezierTo(
        pos.dx + 5.5 + flameWobble * 0.7,
        pos.dy - flameHeight * 0.55,
        pos.dx + 6.5,
        pos.dy + 1,
      )
      ..close();

    final Paint mantlePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(pos.dx, pos.dy),
        Offset(pos.dx, pos.dy - flameHeight * 1.15),
        <Color>[
          light.currentColor.withValues(alpha: 0.85),
          const Color(0xFFFF5722).withValues(alpha: 0.65),
          const Color(0xFFFF9800).withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.6, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(outerMantle, mantlePaint);

    // 5. Secondary dancing flame tongue (licking dynamic plume)
    final double tongueLean = flameWobble * 1.4 + math.sin(time * 24.0 + light.flickerPhase) * 2.0;
    final Path flameTongue = Path()
      ..moveTo(pos.dx - 2.0, pos.dy)
      ..quadraticBezierTo(
        pos.dx + tongueLean * 0.8,
        pos.dy - flameHeight * 0.65,
        pos.dx + tongueLean * 1.4,
        pos.dy - flameHeight * 1.05,
      )
      ..quadraticBezierTo(
        pos.dx + tongueLean * 0.3,
        pos.dy - flameHeight * 0.5,
        pos.dx + 2.0,
        pos.dy,
      )
      ..close();

    final Paint tonguePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(pos.dx, pos.dy),
        Offset(pos.dx, pos.dy - flameHeight * 1.05),
        <Color>[
          const Color(0xFFFFB300).withValues(alpha: 0.8),
          const Color(0xFFFF7043).withValues(alpha: 0.4),
          Colors.transparent,
        ],
        <double>[0.0, 0.6, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawPath(flameTongue, tonguePaint);

    // 6. Primary core flame teardrop (intense yellow/white heat)
    final Path flamePath = Path()
      ..moveTo(pos.dx - 4.5, pos.dy)
      ..quadraticBezierTo(
        pos.dx - 3.5 + flameWobble,
        pos.dy - flameHeight * 0.6,
        pos.dx + flameWobble * 1.5,
        pos.dy - flameHeight,
      )
      ..quadraticBezierTo(
        pos.dx + 3.5 + flameWobble,
        pos.dy - flameHeight * 0.6,
        pos.dx + 4.5,
        pos.dy,
      )
      ..close();

    final Paint flamePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(pos.dx, pos.dy),
        Offset(pos.dx, pos.dy - flameHeight),
        <Color>[
          light.currentColor,
          const Color(0xFFFFD54F),
          const Color(0xFFFFFFFF),
        ],
        <double>[0.0, 0.65, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    canvas.drawPath(flamePath, flamePaint);

    // 7. Core white-hot spark ignition zone
    final Paint coreSpark = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(pos.dx + flameWobble * 0.4, pos.dy - 3), 2.2, coreSpark);

    // 8. Procedural rising thermal ember sparks (drifting upward with convection)
    final Paint sparkPaint = Paint()..style = PaintingStyle.fill;
    for (int s = 0; s < 4; ++s) {
      final double sOffset = (time * 1.8 + s * 0.25 + light.flickerPhase * 0.1) % 1.0;
      final double sparkY = pos.dy - flameHeight * (0.8 + sOffset * 1.4);
      final double sparkX = pos.dx + flameWobble * (1.0 + sOffset) +
          math.sin(time * 6.0 + s * 2.0) * (3.0 + sOffset * 4.0);
      final double sparkAlpha = ((1.0 - sOffset) * flicker * 0.85).clamp(0.0, 1.0);
      if (sparkAlpha > 0.05) {
        sparkPaint.color = const Color(0xFFFFE082).withValues(alpha: sparkAlpha);
        final double sparkRadius = (1.5 * (1.0 - sOffset * 0.5)).clamp(0.6, 1.8);
        canvas.drawCircle(Offset(sparkX, sparkY), sparkRadius, sparkPaint);
      }
    }
  }

  void _paintArcaneRuneVisual(
    Canvas canvas,
    Offset pos,
    dls.DungeonLight light,
    double flicker,
    double time,
  ) {
    final double pulse = (math.sin(time * 3.5 + light.flickerPhase) * 0.5 + 0.5);
    final double ringRadius = (16.0 + pulse * 6.0) * (flicker * 0.8).clamp(0.5, 1.5);

    // Glowing arcane rune perimeter
    final Paint runePaint = Paint()
      ..color = light.currentColor.withValues(alpha: (0.75 * flicker).clamp(0.1, 0.95))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(pos, ringRadius, runePaint);

    // Cardinal power nodes
    final Paint nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.9 * flicker).clamp(0.2, 1.0))
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 4; ++i) {
      final double angle = (i * math.pi * 0.5) + (time * 0.8);
      final Offset nodePos = Offset(
        pos.dx + math.cos(angle) * ringRadius,
        pos.dy + math.sin(angle) * ringRadius * 0.65,
      );
      canvas.drawCircle(nodePos, 2.0, nodePaint);
    }

    // Inner glowing arcane glyph
    final Paint innerGlyph = Paint()
      ..color = light.currentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(pos, 3.5, innerGlyph);
  }

  void _paintExplosionFlashVisual(
    Canvas canvas,
    Offset pos,
    dls.DungeonLight light,
    double flicker,
    double time,
  ) {
    final double flashRadius = (32.0 * flicker).clamp(12.0, 90.0);

    // Blinding central burst
    final Paint burstPaint = Paint()
      ..shader = ui.Gradient.radial(
        pos,
        flashRadius,
        <Color>[
          Colors.white.withValues(alpha: (0.9 * flicker).clamp(0.0, 1.0)),
          light.currentColor.withValues(alpha: (0.65 * flicker).clamp(0.0, 0.9)),
          const Color(0xFFFF5722).withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.45, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(pos, flashRadius, burstPaint);

    // Radiating energy light spikes
    final Paint spikePaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.8 * flicker).clamp(0.0, 1.0))
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 6; ++i) {
      final double angle = (i * math.pi / 3.0) + (light.flickerPhase * 0.1);
      final double spikeLen = flashRadius * (1.1 + 0.3 * math.sin(i * 1.5));
      final Offset end = Offset(
        pos.dx + math.cos(angle) * spikeLen,
        pos.dy + math.sin(angle) * spikeLen,
      );
      canvas.drawLine(pos, end, spikePaint);
    }
  }

  void _paintSoulWispVisual(
    Canvas canvas,
    Offset pos,
    dls.DungeonLight light,
    double flicker,
    double time,
  ) {
    final double wispBobble = math.sin(time * 4.5 + light.flickerPhase) * 2.5;
    final Offset wispPos = Offset(pos.dx, pos.dy + wispBobble);

    // Ghostly spectral aura
    final Paint auraPaint = Paint()
      ..shader = ui.Gradient.radial(
        wispPos,
        18.0 * flicker,
        <Color>[
          light.currentColor.withValues(alpha: 0.8 * flicker),
          const Color(0xFF00E5FF).withValues(alpha: 0.35 * flicker),
          Colors.transparent,
        ],
        <double>[0.0, 0.55, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(wispPos, 18.0 * flicker, auraPaint);

    // Ethereal teardrop body
    final Path wispPath = Path()
      ..moveTo(wispPos.dx, wispPos.dy - 6)
      ..quadraticBezierTo(
        wispPos.dx + 4,
        wispPos.dy,
        wispPos.dx,
        wispPos.dy + 8,
      )
      ..quadraticBezierTo(
        wispPos.dx - 4,
        wispPos.dy,
        wispPos.dx,
        wispPos.dy - 6,
      )
      ..close();

    final Paint corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * flicker)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wispPath, corePaint);
  }

  // ---------------------------------------------------------------------------
  // 5. Mystical Crepuscular Light Shafts (God Rays & Cavern Ceiling Fissures)
  // ---------------------------------------------------------------------------
  void _paintMysticalLightShafts(Canvas canvas, Size size, double time) {
    for (final MysticalLightShaft shaft in lightShafts) {
      final double pulse = 0.82 + 0.18 * math.sin(time * shaft.pulseSpeed + shaft.pulsePhase);
      final double alpha = (shaft.baseAlpha * pulse * intensityMultiplier).clamp(0.0, 0.40);
      if (alpha <= 0.005) continue;

      final double originX = size.width * shaft.originXRatio;
      final double beamLength = size.height * shaft.lengthRatio;
      final double dx = math.tan(shaft.angleRadians) * beamLength;
      final Offset endCenter = Offset(originX + dx, beamLength);

      final Path beamPath = Path()
        ..moveTo(originX - shaft.topWidth * 0.5, 0.0)
        ..lineTo(originX + shaft.topWidth * 0.5, 0.0)
        ..lineTo(endCenter.dx + shaft.bottomWidth * 0.5, beamLength)
        ..lineTo(endCenter.dx - shaft.bottomWidth * 0.5, beamLength)
        ..close();

      // Atmospheric color: harmonious blend of celestial amber and theme accent glow
      final Color rayColor = Color.lerp(
        const Color(0xFFFFE082),
        theme.accentGlow,
        0.55,
      )!;

      final Paint beamPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(originX, 0.0),
          endCenter,
          <Color>[
            rayColor.withValues(alpha: alpha * 1.0),
            rayColor.withValues(alpha: alpha * 0.70),
            rayColor.withValues(alpha: alpha * 0.22),
            Colors.transparent,
          ],
          <double>[0.0, 0.35, 0.75, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      canvas.drawPath(beamPath, beamPaint);

      // Airborne dust motes floating inside the beam of light
      final Paint motePaint = Paint()..style = PaintingStyle.fill;
      for (int m = 0; m < 4; ++m) {
        final double mProgress = (time * 0.08 + m * 0.25 + shaft.pulsePhase * 0.1) % 1.0;
        final double my = mProgress * beamLength;
        final double mx = originX + (dx * mProgress) + math.sin(time * 1.5 + m * 2.1) * (shaft.topWidth * 0.5 + mProgress * (shaft.bottomWidth * 0.35));
        final double moteAlpha = (math.sin(mProgress * math.pi) * alpha * 2.2).clamp(0.0, 0.85);

        if (moteAlpha > 0.02) {
          motePaint.color = Colors.white.withValues(alpha: moteAlpha);
          canvas.drawCircle(Offset(mx, my), 1.2, motePaint);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 6. Multi-Tier Atmospheric Volumetric Mist with Torch In-Scattering
  // ---------------------------------------------------------------------------
  void _paintAtmosphericMist(Canvas canvas, Size size, double time) {
    final List<dls.DungeonLight> activeLights = controller.lightSystem.lights.toList();

    for (final MistWisp wisp in wisps) {
      // Continuous drifting motion across X with looping bounds
      final double driftX = ((wisp.baseX + time * wisp.speed * 0.35) % 20.0) - 10.0;
      final double waveY = math.sin(time * 1.2 + wisp.phase) * 0.25;

      final double worldY = wisp.tier == 0
          ? 0.18 + waveY * 0.5
          : (wisp.tier == 1 ? 1.35 + waveY : 3.8 + waveY * 0.8);

      final Offset screenPos = camera.project(
        dls.Vector3D(driftX, worldY, wisp.baseZ),
        size,
      );

      final double scale = camera.depthScale(wisp.baseZ, size);
      final double w = wisp.scaleX * scale * 1.8;
      final double h = wisp.scaleY * scale * 1.8;

      if (w <= 1.0 || h <= 1.0) continue;

      // Volumetric In-Scattering: sample proximity to nearest active light source
      double nearestLightScatter = 0.0;
      Color scatterColor = const Color(0xFFFF9800);

      for (final dls.DungeonLight light in activeLights) {
        if (light.currentIntensity <= 0.05) continue;
        final double dX = driftX - light.currentPosition.x;
        final double dY = worldY - light.currentPosition.y;
        final double dZ = wisp.baseZ - light.currentPosition.z;
        final double dist = math.sqrt(dX * dX + dY * dY + dZ * dZ);
        final double maxScatterDist = light.currentRadius * 0.65;
        if (dist < maxScatterDist) {
          final double factor = (1.0 - (dist / maxScatterDist)) * light.currentIntensity * 0.45;
          if (factor > nearestLightScatter) {
            nearestLightScatter = factor;
            scatterColor = light.currentColor;
          }
        }
      }

      // Base cold cavern fog color blended with warm in-scatter
      final Color baseFogColor = theme.surfaceDeep.withValues(alpha: wisp.alpha * intensityMultiplier);
      final Color finalMistColor = Color.lerp(
        baseFogColor,
        scatterColor.withValues(alpha: (wisp.alpha * 1.4 * intensityMultiplier).clamp(0.0, 1.0)),
        nearestLightScatter.clamp(0.0, 0.85),
      )!;

      final Paint mistPaint = Paint()
        ..shader = ui.Gradient.radial(
          screenPos,
          w * 0.5,
          <Color>[
            finalMistColor,
            finalMistColor.withValues(alpha: (finalMistColor.a * 0.38).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          <double>[0.0, 0.55, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.5, h * 0.42));

      canvas.drawOval(
        Rect.fromCenter(center: screenPos, width: w, height: h),
        mistPaint,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 7. Global 3D Ember Drifts & Arcane Spore Currents
  // ---------------------------------------------------------------------------
  void _paintEmberDrifts(Canvas canvas, Size size, double time) {
    final Paint auraPaint = Paint()..style = PaintingStyle.fill;
    final Paint corePaint = Paint()..style = PaintingStyle.fill;
    final Paint wakePaint = Paint()..style = PaintingStyle.stroke;

    for (final ArenaEmberParticle ember in embers) {
      final double cycle = (time * ember.speedY + ember.phase) % 1.0;
      final double worldY = 0.15 + cycle * 4.6;
      final double worldX = ember.seedX + math.sin(time * ember.swaySpeed + ember.phase) * ember.swayRadius;
      final double worldZ = ember.seedZ + math.cos(time * (ember.swaySpeed * 0.65) + ember.phase) * (ember.swayRadius * 0.45);

      final Offset screenPos = camera.project(dls.Vector3D(worldX, worldY, worldZ), size);
      if (screenPos.dx < -20 || screenPos.dx > size.width + 20 || screenPos.dy < -20 || screenPos.dy > size.height + 20) {
        continue;
      }

      final double depthScale = camera.depthScale(worldZ, size);
      final double lifeFade = math.sin(cycle * math.pi);
      final double shimmer = 0.78 + 0.22 * math.sin(time * 7.5 + ember.phase * 4.0);
      final double alpha = (lifeFade * shimmer * 0.88 * intensityMultiplier).clamp(0.0, 1.0);
      if (alpha <= 0.03) continue;

      final double radius = (ember.size * depthScale * 25.0).clamp(1.1, 4.8);

      if (ember.isMysticSpore) {
        // Glowing arcane cavern spore
        auraPaint
          ..color = theme.accentGlow.withValues(alpha: alpha * 0.65)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, radius * 1.8));
        canvas.drawCircle(screenPos, radius * 2.2, auraPaint);

        corePaint.color = Colors.white.withValues(alpha: alpha * 0.95);
        canvas.drawCircle(screenPos, radius * 0.75, corePaint);
      } else {
        // Fiery thermal convection ember
        auraPaint
          ..color = const Color(0xFFFF5722).withValues(alpha: alpha * 0.60)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.2, radius * 1.4));
        canvas.drawCircle(screenPos, radius * 2.0, auraPaint);

        corePaint.color = const Color(0xFFFFF9C4).withValues(alpha: alpha * 0.95);
        canvas.drawCircle(screenPos, radius * 0.7, corePaint);

        // Rising thermal motion wake
        wakePaint
          ..color = const Color(0xFFFF8F00).withValues(alpha: alpha * 0.45)
          ..strokeWidth = math.max(0.8, radius * 0.35);
        canvas.drawLine(
          screenPos,
          Offset(screenPos.dx, screenPos.dy + radius * 1.6),
          wakePaint,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 8. Multi-Stage Cinematic Vignette & Atmospheric Depth Grading
  // ---------------------------------------------------------------------------
  void _paintCinematicVignette(Canvas canvas, Size size) {
    final Rect fullRect = Offset.zero & size;
    final double horizonY = size.height * camera.horizonYRatio;

    // Stage A: High cavern vault ceiling abyssal shadow (top 15% linear dropoff)
    final Paint ceilingShadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height * 0.15),
        <Color>[
          BattlePalette.carbonVoid.withValues(alpha: 0.90),
          BattlePalette.carbonVoid.withValues(alpha: 0.40),
          Colors.transparent,
        ],
        <double>[0.0, 0.55, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.15), ceilingShadowPaint);

    // Stage B: Horizon ambient occlusion contact crevice (ground plane grounding)
    if (horizonY > 10 && horizonY < size.height) {
      final Paint horizonAoPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonY - 14),
          Offset(0, horizonY + 14),
          <Color>[
            Colors.transparent,
            BattlePalette.carbonVoid.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          <double>[0.0, 0.5, 1.0],
        );
      canvas.drawRect(Rect.fromLTRB(0, horizonY - 14, size.width, horizonY + 14), horizonAoPaint);
    }

    // Stage C: Deep anamorphic elliptical vignette with dark obsidian corners
    final Paint vignettePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.52),
        size.longestSide * 0.72,
        <Color>[
          Colors.transparent,
          BattlePalette.carbonVoid.withValues(alpha: 0.28),
          BattlePalette.carbonVoid.withValues(alpha: 0.76),
          BattlePalette.carbonVoid.withValues(alpha: 0.94),
        ],
        <double>[0.32, 0.65, 0.86, 1.0],
      );
    canvas.drawRect(fullRect, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant DungeonArena3DPainter oldDelegate) => true;
}

/// The composable Flutter Widget for the Dark Cinematic Dungeon Atmosphere.
class DungeonCinematicAtmosphere extends StatefulWidget {
  const DungeonCinematicAtmosphere({
    super.key,
    this.controller,
    required this.theme,
    this.showTorches = true,
    this.showArena3D = true,
    this.showMist = true,
    this.showDecals = true,
    this.showDynamicShadows = true,
    this.showWallShadows = true,
    this.showEmbers = true,
    this.showLightShafts = true,
    this.intensityMultiplier = 1.0,
    this.child,
  });

  final DungeonAtmosphereController? controller;
  final CaveCardTheme theme;
  final bool showTorches;
  final bool showArena3D;
  final bool showMist;
  final bool showDecals;
  final bool showDynamicShadows;
  final bool showWallShadows;
  final bool showEmbers;
  final bool showLightShafts;
  final double intensityMultiplier;
  final Widget? child;

  @override
  State<DungeonCinematicAtmosphere> createState() =>
      _DungeonCinematicAtmosphereState();
}

class _DungeonCinematicAtmosphereState extends State<DungeonCinematicAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late DungeonAtmosphereController _controller;
  bool _ownsController = false;
  late final Stopwatch _stopwatch;
  double _lastElapsedSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = DungeonAtmosphereController();
      _ownsController = true;
    }

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _ticker.addListener(_onTick);
  }

  void _onTick() {
    final double elapsed = _stopwatch.elapsedMicroseconds / 1000000.0;
    if (_lastElapsedSeconds > 0) {
      final double dt = (elapsed - _lastElapsedSeconds).clamp(0.001, 0.05);
      _controller.update(dt);
    }
    _lastElapsedSeconds = elapsed;
  }

  @override
  void didUpdateWidget(covariant DungeonCinematicAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      if (widget.controller != null) {
        _controller = widget.controller!;
        _ownsController = false;
      } else {
        _controller = DungeonAtmosphereController();
        _ownsController = true;
      }
    }
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    _stopwatch.stop();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CustomPaint(
          painter: DungeonArena3DPainter(
            controller: _controller,
            camera: const Arena3DCamera(),
            theme: widget.theme,
            showTorches: widget.showTorches,
            showArena3D: widget.showArena3D,
            showMist: widget.showMist,
            showDecals: widget.showDecals,
            showDynamicShadows: widget.showDynamicShadows,
            showWallShadows: widget.showWallShadows,
            showEmbers: widget.showEmbers,
            showLightShafts: widget.showLightShafts,
            intensityMultiplier: widget.intensityMultiplier,
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
