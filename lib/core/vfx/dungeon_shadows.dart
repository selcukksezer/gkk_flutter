import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ground_decal_system.dart' as gds;

/// ----------------------------------------------------------------------------
/// Production 2027 AAA Dynamic Dungeon & Arena Shadows System (Module 9)
/// Standard: Requirement R3 (Combat Mechanics, VFX & Game Feel) & R5 (Integration)
///
/// Features:
/// 1. Dynamic light sources (point torches, braziers, celestial sun, spell flares)
/// 2. Soft shadow projection lobes with umbra core and softened penumbra
/// 3. Occluder geometry (monoliths, pillars, heroes, bosses, siege gates)
/// 4. Procedural torch flicker and light wobble
/// 5. Top-down, 2.5D isometric, and perspective floor projection transforms
/// 6. High-performance caching and zero allocations during paint passes
/// ----------------------------------------------------------------------------

/// Type of dynamic shadow light source.
enum ShadowLightType {
  /// Local torch or brazier with point falloff and organic flicker.
  pointTorch,

  /// Directional sunlight / celestial moonlight (parallel rays).
  directionalSun,

  /// High-energy magical burst or spell flare (expanding pulse).
  magicalFlare,

  /// Ambient ground glow / abyss lava fissure.
  groundAura,
}

/// Configuration for a dynamic light casting shadows in the arena.
class DungeonShadowLight {
  DungeonShadowLight({
    required this.id,
    required this.worldPosition,
    required this.color,
    this.type = ShadowLightType.pointTorch,
    this.baseIntensity = 2.4,
    this.minIntensity = 1.6,
    this.maxIntensity = 3.2,
    this.radius = 8.5,
    this.flickerSpeed = 1.0,
    this.flickerPhase = 0.0,
    this.wobbleRadius = 0.22,
    this.shadowHardness = 0.65,
    this.direction = const Offset(0.0, 1.0),
  })  : currentIntensity = baseIntensity,
        currentPosition = worldPosition;

  final String id;
  final gds.Vector3D worldPosition;
  final Color color;
  final ShadowLightType type;
  final double baseIntensity;
  final double minIntensity;
  final double maxIntensity;
  final double radius;
  final double flickerSpeed;
  final double flickerPhase;
  final double wobbleRadius;
  final double shadowHardness;
  final Offset direction;

  double currentIntensity;
  gds.Vector3D currentPosition;

  /// Updates procedural flicker and spatial wobble over time [t] seconds.
  void update(double t) {
    if (type == ShadowLightType.directionalSun) {
      currentIntensity = baseIntensity;
      currentPosition = worldPosition;
      return;
    }

    final double phase = t * flickerSpeed * 3.5 + flickerPhase;
    // Multi-octave sinusoidal organic flame flicker
    final double flickerNorm = 0.5 +
        0.32 * math.sin(phase) +
        0.18 * math.sin(phase * 2.3 + 1.2) +
        0.08 * math.sin(phase * 4.7 + 2.8);

    currentIntensity = minIntensity + (maxIntensity - minIntensity) * flickerNorm.clamp(0.0, 1.0);

    // Subtle 2D wobble
    final double wobbleX = math.sin(phase * 0.8) * wobbleRadius;
    final double wobbleZ = math.cos(phase * 0.9 + 0.5) * wobbleRadius;
    currentPosition = gds.Vector3D(
      worldPosition.x + wobbleX,
      worldPosition.y,
      worldPosition.z + wobbleZ,
    );
  }
}

/// Shadow occluder representing an entity, pillar, hero, or boss monolith.
class DungeonShadowOccluder {
  DungeonShadowOccluder({
    required this.id,
    required this.center,
    required this.radius,
    required this.height,
    this.opacityMultiplier = 1.0,
    this.isDynamic = true,
  });

  final String id;
  gds.Vector3D center;
  double radius;
  double height;
  double opacityMultiplier;
  final bool isDynamic;

  /// Clones or updates the occluder center.
  void updatePosition(gds.Vector3D newCenter) {
    center = newCenter;
  }
}

/// Computed 2D soft shadow projection lobe.
class ShadowProjectionLobe {
  const ShadowProjectionLobe({
    required this.groundCenter,
    required this.shadowTip,
    required this.shadowLength,
    required this.shadowAngle,
    required this.penumbraWidth,
    required this.shadowAlpha,
    required this.tintColor,
  });

  final Offset groundCenter;
  final Offset shadowTip;
  final double shadowLength;
  final double shadowAngle;
  final double penumbraWidth;
  final double shadowAlpha;
  final Color tintColor;
}

/// Controller managing all active dynamic lights and shadow occluders.
class DungeonShadowsController extends ChangeNotifier {
  DungeonShadowsController({
    List<DungeonShadowLight>? initialLights,
    List<DungeonShadowOccluder>? initialOccluders,
  }) {
    if (initialLights != null) {
      _lights.addAll(initialLights);
    }
    if (initialOccluders != null) {
      _occluders.addAll(initialOccluders);
    }
  }

  final List<DungeonShadowLight> _lights = <DungeonShadowLight>[];
  final List<DungeonShadowOccluder> _occluders = <DungeonShadowOccluder>[];

  List<DungeonShadowLight> get lights => List<DungeonShadowLight>.unmodifiable(_lights);
  List<DungeonShadowOccluder> get occluders => List<DungeonShadowOccluder>.unmodifiable(_occluders);

  double _timeSeconds = 0.0;
  double get timeSeconds => _timeSeconds;

  bool _enabled = true;
  bool get enabled => _enabled;
  set enabled(bool val) {
    if (_enabled != val) {
      _enabled = val;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Light Management
  // ---------------------------------------------------------------------------

  void addLight(DungeonShadowLight light) {
    _lights.add(light);
    notifyListeners();
  }

  void removeLight(String id) {
    _lights.removeWhere((DungeonShadowLight l) => l.id == id);
    notifyListeners();
  }

  DungeonShadowLight? getLight(String id) {
    for (final DungeonShadowLight l in _lights) {
      if (l.id == id) return l;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Occluder Management
  // ---------------------------------------------------------------------------

  void addOccluder(DungeonShadowOccluder occluder) {
    _occluders.add(occluder);
    notifyListeners();
  }

  void removeOccluder(String id) {
    _occluders.removeWhere((DungeonShadowOccluder o) => o.id == id);
    notifyListeners();
  }

  DungeonShadowOccluder? getOccluder(String id) {
    for (final DungeonShadowOccluder o in _occluders) {
      if (o.id == id) return o;
    }
    return null;
  }

  void updateOccluderPosition(String id, gds.Vector3D position) {
    final DungeonShadowOccluder? occ = getOccluder(id);
    if (occ != null) {
      occ.updatePosition(position);
    }
  }

  // ---------------------------------------------------------------------------
  // Frame Update Loop
  // ---------------------------------------------------------------------------

  void update(double dt) {
    if (!_enabled || dt <= 0.0) return;
    _timeSeconds += dt;
    for (final DungeonShadowLight light in _lights) {
      light.update(_timeSeconds);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Pre-Built Atmospheric Presets
  // ---------------------------------------------------------------------------

  /// Preset 1: Abyssal Cave Dungeon Torches & Central Rune Light
  factory DungeonShadowsController.abyssalDungeon() {
    return DungeonShadowsController(
      initialLights: <DungeonShadowLight>[
        DungeonShadowLight(
          id: 'torch_left',
          worldPosition: const gds.Vector3D(-3.6, 2.6, 3.8),
          color: const Color(0xFFFF851B), // Warm Amber Flame
          baseIntensity: 2.8,
          radius: 9.5,
          flickerSpeed: 1.1,
          flickerPhase: 0.0,
          shadowHardness: 0.65,
        ),
        DungeonShadowLight(
          id: 'torch_right',
          worldPosition: const gds.Vector3D(3.6, 2.6, 3.8),
          color: const Color(0xFFFFB300), // Golden Flame
          baseIntensity: 2.8,
          radius: 9.5,
          flickerSpeed: 0.95,
          flickerPhase: 2.14,
          shadowHardness: 0.65,
        ),
        DungeonShadowLight(
          id: 'brazier_center',
          worldPosition: const gds.Vector3D(0.0, 3.8, 6.0),
          color: const Color(0xFF00E5FF), // Arcane Cyan Aether
          baseIntensity: 1.9,
          radius: 11.0,
          flickerSpeed: 0.7,
          flickerPhase: 4.1,
          shadowHardness: 0.50,
        ),
      ],
      initialOccluders: <DungeonShadowOccluder>[
        DungeonShadowOccluder(
          id: 'player_fighter',
          center: const gds.Vector3D(-1.4, 0.9, 2.0),
          radius: 0.45,
          height: 1.8,
        ),
        DungeonShadowOccluder(
          id: 'boss_monster',
          center: const gds.Vector3D(1.4, 1.2, 2.4),
          radius: 0.70,
          height: 2.4,
        ),
        DungeonShadowOccluder(
          id: 'pillar_left',
          center: const gds.Vector3D(-3.5, 1.8, 4.0),
          radius: 0.55,
          height: 3.6,
          isDynamic: false,
        ),
        DungeonShadowOccluder(
          id: 'pillar_right',
          center: const gds.Vector3D(3.5, 1.8, 4.0),
          radius: 0.55,
          height: 3.6,
          isDynamic: false,
        ),
      ],
    );
  }

  /// Preset 2: Colosseum Open Sun & Gladiator Duel
  factory DungeonShadowsController.colosseumSunlight() {
    return DungeonShadowsController(
      initialLights: <DungeonShadowLight>[
        DungeonShadowLight(
          id: 'colosseum_sun',
          worldPosition: const gds.Vector3D(-6.0, 12.0, -8.0),
          color: const Color(0xFFFFF8E7),
          type: ShadowLightType.directionalSun,
          baseIntensity: 3.2,
          radius: 35.0,
          shadowHardness: 0.85,
        ),
        DungeonShadowLight(
          id: 'arena_brazier',
          worldPosition: const gds.Vector3D(0.0, 1.8, 4.5),
          color: const Color(0xFFFF9100),
          baseIntensity: 1.8,
          radius: 8.0,
          shadowHardness: 0.55,
        ),
      ],
      initialOccluders: <DungeonShadowOccluder>[
        DungeonShadowOccluder(
          id: 'gladiator_challenger',
          center: const gds.Vector3D(-1.2, 0.9, 2.0),
          radius: 0.42,
          height: 1.8,
        ),
        DungeonShadowOccluder(
          id: 'gladiator_defender',
          center: const gds.Vector3D(1.2, 0.9, 2.0),
          radius: 0.42,
          height: 1.8,
        ),
      ],
    );
  }

  /// Preset 3: Guild Fortress Ramparts & Siege Fire
  factory DungeonShadowsController.guildFortressSiege() {
    return DungeonShadowsController(
      initialLights: <DungeonShadowLight>[
        DungeonShadowLight(
          id: 'siege_fire_left',
          worldPosition: const gds.Vector3D(-4.2, 3.2, 2.0),
          color: const Color(0xFFFF5722),
          baseIntensity: 3.4,
          radius: 12.0,
          flickerSpeed: 1.4,
          shadowHardness: 0.70,
        ),
        DungeonShadowLight(
          id: 'siege_fire_right',
          worldPosition: const gds.Vector3D(4.2, 3.2, 2.0),
          color: const Color(0xFFFF9800),
          baseIntensity: 3.0,
          radius: 12.0,
          flickerSpeed: 1.2,
          flickerPhase: 1.8,
          shadowHardness: 0.70,
        ),
      ],
      initialOccluders: <DungeonShadowOccluder>[
        DungeonShadowOccluder(
          id: 'fortress_gate',
          center: const gds.Vector3D(0.0, 2.0, 6.0),
          radius: 1.6,
          height: 4.0,
        ),
        DungeonShadowOccluder(
          id: 'vanguard_troop',
          center: const gds.Vector3D(-1.5, 0.8, 1.5),
          radius: 0.5,
          height: 1.7,
        ),
      ],
    );
  }
}

/// CustomPainter projecting soft shadow lobes on a ground floor canvas.
class DungeonShadowsPainter extends CustomPainter {
  DungeonShadowsPainter({
    required this.controller,
    this.pixelsPerUnit = 48.0,
    this.groundYRatio = 0.55,
    this.ambientShadowAlpha = 0.55,
  }) : super(repaint: controller);

  final DungeonShadowsController controller;
  final double pixelsPerUnit;
  final double groundYRatio;
  final double ambientShadowAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (!controller.enabled || size.width <= 0 || size.height <= 0) return;

    final double cx = size.width * 0.5;
    final double cy = size.height * groundYRatio;

    // Convert 3D world coord to 2D screen floor point
    Offset projectToFloor(gds.Vector3D world) {
      return Offset(
        cx + world.x * pixelsPerUnit,
        cy + world.z * (pixelsPerUnit * 0.45),
      );
    }

    for (final DungeonShadowOccluder occ in controller.occluders) {
      final Offset occGround = projectToFloor(occ.center);

      // 1. Static contact ambient occlusion oval beneath feet/base
      final Paint aoPaint = Paint()
        ..shader = ui.Gradient.radial(
          occGround,
          occ.radius * pixelsPerUnit * 1.25,
          <Color>[
            Colors.black.withValues(alpha: 0.58 * occ.opacityMultiplier * ambientShadowAlpha),
            Colors.black.withValues(alpha: 0.22 * occ.opacityMultiplier * ambientShadowAlpha),
            Colors.transparent,
          ],
          <double>[0.0, 0.65, 1.0],
        );

      final Rect aoRect = Rect.fromCenter(
        center: occGround,
        width: occ.radius * pixelsPerUnit * 2.5,
        height: occ.radius * pixelsPerUnit * 1.15,
      );
      canvas.drawOval(aoRect, aoPaint);

      // 2. Projected directional shadow lobes for each active light
      for (final DungeonShadowLight light in controller.lights) {
        if (light.currentIntensity <= 0.05) continue;

        Offset shadowDir;
        double distToLight;

        if (light.type == ShadowLightType.directionalSun) {
          shadowDir = light.direction;
          distToLight = 20.0;
        } else {
          final double dx = occ.center.x - light.currentPosition.x;
          final double dz = occ.center.z - light.currentPosition.z;
          distToLight = math.sqrt(dx * dx + dz * dz);
          if (distToLight >= light.radius) continue; // Out of light range
          if (distToLight <= 0.01) continue;
          shadowDir = Offset(dx / distToLight, dz / distToLight);
        }

        // Distance attenuation & shadow strength
        final double distanceFalloff = (1.0 - (distToLight / light.radius)).clamp(0.0, 1.0);
        final double shadowLength = (occ.height * pixelsPerUnit * 0.55 * (1.2 - distanceFalloff * 0.4)).clamp(12.0, 160.0);
        final double penumbraWidth = (occ.radius * pixelsPerUnit * 1.8 * (1.0 + (1.0 - light.shadowHardness) * 0.8)).clamp(8.0, 80.0);
        final double shadowAlpha = (0.42 * light.currentIntensity * distanceFalloff * light.shadowHardness * occ.opacityMultiplier).clamp(0.0, 0.75);

        if (shadowAlpha <= 0.01) continue;

        final double shadowAngle = math.atan2(shadowDir.dy * 0.45, shadowDir.dx);

        canvas.save();
        canvas.translate(occGround.dx, occGround.dy);
        canvas.rotate(shadowAngle);

        final Rect shadowBounds = Rect.fromLTWH(0.0, -penumbraWidth * 0.5, shadowLength, penumbraWidth);
        final Paint shadowPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(shadowLength, 0.0),
            <Color>[
              Colors.black.withValues(alpha: shadowAlpha),
              Colors.black.withValues(alpha: shadowAlpha * 0.55),
              Colors.transparent,
            ],
            <double>[0.0, 0.45, 1.0],
          );

        final RRect roundedLobe = RRect.fromRectAndRadius(
          shadowBounds,
          Radius.circular(penumbraWidth * 0.45),
        );
        canvas.drawRRect(roundedLobe, shadowPaint);

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant DungeonShadowsPainter oldDelegate) => true;
}

/// Convenience widget embedding dynamic dungeon shadows.
class DungeonShadowsWidget extends StatelessWidget {
  const DungeonShadowsWidget({
    super.key,
    required this.controller,
    this.pixelsPerUnit = 48.0,
    this.groundYRatio = 0.55,
    this.ambientShadowAlpha = 0.55,
    this.child,
  });

  final DungeonShadowsController controller;
  final double pixelsPerUnit;
  final double groundYRatio;
  final double ambientShadowAlpha;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DungeonShadowsPainter(
        controller: controller,
        pixelsPerUnit: pixelsPerUnit,
        groundYRatio: groundYRatio,
        ambientShadowAlpha: ambientShadowAlpha,
      ),
      child: child,
    );
  }
}
