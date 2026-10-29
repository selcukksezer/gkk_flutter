import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// ----------------------------------------------------------------------------
/// Guild War Battlefield Lighting, Siege Fires, & Dynamic Shadows System
/// 2027 Cinematic AAA Graphics Pipeline (Aion 2 Abyssal Siege Standard)
/// ----------------------------------------------------------------------------

/// Type of light source in the Guild War siege theatre.
enum SiegeLightType {
  /// Open brazier or fortress wall torch with multi-harmonic flicker.
  warFireBrazier,

  /// Flaming catapult projectile hurled along a parabolic trajectory.
  catapultOrb,

  /// Abyssal fortress arcane ward crystal or glowing gate beacon.
  fortressBeacon,

  /// Ambient twilight sky global illumination bounce.
  twilightGI,

  /// Explosive breach detonation with radiant shockwave.
  breachExplosion,
}

/// Lightweight immutable 2D vector for siege field coordinates and shadow projection.
class SiegeVector2 {
  const SiegeVector2(this.x, this.y);

  final double x;
  final double y;

  static const SiegeVector2 zero = SiegeVector2(0.0, 0.0);

  double get lengthSquared => x * x + y * y;
  double get length => math.sqrt(lengthSquared);

  SiegeVector2 normalized() {
    final double l = length;
    if (l < 1e-7) return zero;
    return SiegeVector2(x / l, y / l);
  }

  SiegeVector2 operator +(SiegeVector2 o) => SiegeVector2(x + o.x, y + o.y);
  SiegeVector2 operator -(SiegeVector2 o) => SiegeVector2(x - o.x, y - o.y);
  SiegeVector2 operator *(double s) => SiegeVector2(x * s, y * s);
  SiegeVector2 operator /(double s) => SiegeVector2(x / s, y / s);
  SiegeVector2 operator -() => SiegeVector2(-x, -y);

  double dot(SiegeVector2 o) => x * o.x + y * o.y;
  double distanceTo(SiegeVector2 o) => (this - o).length;
  double distanceSquaredTo(SiegeVector2 o) => (this - o).lengthSquared;

  SiegeVector2 lerp(SiegeVector2 target, double t) =>
      SiegeVector2(x + (target.x - x) * t, y + (target.y - y) * t);

  Offset toOffset() => Offset(x, y);

  @override
  String toString() => 'SiegeVector2(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiegeVector2 &&
          (x - other.x).abs() < 1e-6 &&
          (y - other.y).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(x.round(), y.round());
}

/// Dynamic light source for battlefield siege illumination.
class SiegeLightSource {
  SiegeLightSource({
    required this.id,
    required this.position,
    this.z = 10.0,
    required this.radius,
    this.color = const Color(0xFFFF8A00),
    this.intensity = 1.0,
    this.type = SiegeLightType.warFireBrazier,
    this.flickerRate = 4.5,
    this.flickerPhase = 0.0,
    this.flickerAmount = 0.25,
    this.shadowHardness = 0.85,
    this.isActive = true,
  }) : assert(radius > 0.0, 'Radius must be positive');

  final String id;
  SiegeVector2 position;
  double z;
  double radius;
  Color color;
  double intensity;
  final SiegeLightType type;
  final double flickerRate;
  final double flickerPhase;
  final double flickerAmount;
  final double shadowHardness;
  bool isActive;

  /// Evaluates time-varying multi-harmonic flicker intensity.
  double evaluateFlicker(double timeSeconds) {
    if (flickerAmount <= 0.0) return intensity;
    final double t = timeSeconds * flickerRate + flickerPhase;
    final double h1 = math.sin(t);
    final double h2 = math.sin(t * 2.37 + 1.1) * 0.45;
    final double h3 = math.sin(t * 5.71 + 2.8) * 0.25;
    final double norm = (h1 + h2 + h3) / 1.7; // ~ [-1.0, 1.0]
    final double factor = 1.0 + (norm * flickerAmount);
    return (intensity * factor).clamp(0.0, intensity * 2.5);
  }

  /// AAA windowed inverse-square attenuation falloff:
  /// att = [clamp(1 - (dist / radius)^4, 0, 1)]^2 / (1 + (dist / 25)^2)
  double evaluateAttenuation(SiegeVector2 samplePoint) {
    final double dist = position.distanceTo(samplePoint);
    if (dist >= radius || radius <= 0.0) return 0.0;
    final double rNorm = dist / radius;
    final double r4 = rNorm * rNorm * rNorm * rNorm;
    final double window = (1.0 - r4).clamp(0.0, 1.0);
    final double dScaled = dist / 25.0;
    final double denom = 1.0 + dScaled * dScaled;
    return (window * window) / denom;
  }
}

/// Fortress wall segment, gatehouse, or battlement casting dynamic shadows.
class FortressShadowCaster {
  FortressShadowCaster({
    required this.id,
    required this.start,
    required this.end,
    this.height = 35.0,
    this.penumbraSoftness = 1.2,
  });

  final String id;
  final SiegeVector2 start;
  final SiegeVector2 end;
  final double height;
  final double penumbraSoftness;

  /// Evaluates normal vector perpendicular to wall segment.
  SiegeVector2 get normal {
    final SiegeVector2 dir = end - start;
    final double l = dir.length;
    if (l < 1e-6) return const SiegeVector2(0, 1);
    return SiegeVector2(-dir.y / l, dir.x / l);
  }

  /// Projects a dynamic shadow polygon from the wall segment away from [light].
  /// Returns a 4-point polygon `[start, pStart, pEnd, end]`.
  List<SiegeVector2> projectShadowPolygon(
    SiegeLightSource light, {
    double maxProjection = 160.0,
  }) {
    final SiegeVector2 rayStart = (start - light.position).normalized();
    final SiegeVector2 rayEnd = (end - light.position).normalized();

    // Shadow length scales with wall height and light proximity
    final double distStart = (start - light.position).length;
    final double distEnd = (end - light.position).length;

    final double lengthStart =
        (height * 2.2 * (1.0 + (distStart / (light.radius * 0.75)))).clamp(20.0, maxProjection);
    final double lengthEnd =
        (height * 2.2 * (1.0 + (distEnd / (light.radius * 0.75)))).clamp(20.0, maxProjection);

    final SiegeVector2 projStart = start + (rayStart * lengthStart);
    final SiegeVector2 projEnd = end + (rayEnd * lengthEnd);

    return <SiegeVector2>[start, projStart, projEnd, end];
  }
}

/// Burning catapult trail packet representing a blazing projectile launched across the siege grounds.
class BurningCatapultTrail {
  BurningCatapultTrail({
    required this.id,
    required this.origin,
    required this.target,
    this.arcHeight = 120.0,
    this.totalDuration = 2.4,
    this.coreColor = const Color(0xFFFFE082),
    this.tailColor = const Color(0xFFFF3D00),
  }) : lightSource = SiegeLightSource(
          id: 'catapult_light_$id',
          position: origin,
          z: 20.0,
          radius: 95.0,
          color: const Color(0xFFFF6D00),
          intensity: 1.4,
          type: SiegeLightType.catapultOrb,
          flickerAmount: 0.15,
        );

  final String id;
  final SiegeVector2 origin;
  final SiegeVector2 target;
  final double arcHeight;
  final double totalDuration;
  final Color coreColor;
  final Color tailColor;

  final SiegeLightSource lightSource;
  final List<SiegeVector2> trajectoryRibbon = <SiegeVector2>[];
  final List<double> ribbonTimestamps = <double>[];

  double _elapsed = 0.0;
  bool _detonated = false;
  double _detonationTimer = 0.0;

  double get progress => (_elapsed / totalDuration).clamp(0.0, 1.0);
  bool get isDetonated => _detonated;
  bool get isFinished => _detonated && _detonationTimer >= 0.6;
  double get detonationProgress => (_detonationTimer / 0.6).clamp(0.0, 1.0);

  /// Current 2D ground projection + parabolic elevation.
  SiegeVector2 get currentPos {
    final double t = progress;
    final double x = origin.x + (target.x - origin.x) * t;
    // Parabolic arc formula: 4 * h * t * (1 - t)
    final double arc = 4.0 * arcHeight * t * (1.0 - t);
    final double y = origin.y + (target.y - origin.y) * t - arc * 0.45;
    return SiegeVector2(x, y);
  }

  void update(double dt) {
    if (_detonated) {
      _detonationTimer += dt;
      lightSource.intensity = math.max(0.0, 2.5 * (1.0 - detonationProgress));
      lightSource.radius = 95.0 + 80.0 * detonationProgress;
      return;
    }

    _elapsed += dt;
    final SiegeVector2 pos = currentPos;
    lightSource.position = pos;

    // Record trail history
    trajectoryRibbon.add(pos);
    ribbonTimestamps.add(_elapsed);

    // Prune ribbon older than 0.45 seconds
    while (ribbonTimestamps.isNotEmpty && (_elapsed - ribbonTimestamps.first) > 0.45) {
      ribbonTimestamps.removeAt(0);
      trajectoryRibbon.removeAt(0);
    }

    if (_elapsed >= totalDuration) {
      _detonated = true;
      _detonationTimer = 0.0;
      lightSource.position = target;
      lightSource.color = const Color(0xFFFFAB40);
    }
  }
}

/// Particle representing war embers, smoke plumes, and flame tongues.
class SiegeWarFireParticle {
  SiegeWarFireParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.maxAge,
    required this.color,
    this.isSmoke = false,
  });

  SiegeVector2 position;
  SiegeVector2 velocity;
  double size;
  double maxAge;
  Color color;
  final bool isSmoke;
  double age = 0.0;

  double get lifeRemaining => (1.0 - (age / maxAge)).clamp(0.0, 1.0);
  bool get isDead => age >= maxAge;

  void update(double dt) {
    age += dt;
    // Buoyancy lift + turbulent lateral drift
    position = position + (velocity * dt);
    // Slow down horizontal velocity due to atmospheric drag
    velocity = SiegeVector2(velocity.x * 0.98, velocity.y - 4.0 * dt);
    if (isSmoke) {
      size += 8.0 * dt; // Smoke expands as it rises
    }
  }
}

/// Abyssal Twilight Sky Global Illumination (GI) Model.
class TwilightSkyGISystem {
  TwilightSkyGISystem({
    this.zenithColor = const Color(0xFF070B18), // Abyssal deep navy void
    this.midAtmosphereColor = const Color(0xFF1B142E), // Mystic twilight violet
    this.horizonColor = const Color(0xFF38150D), // Burning war horizon amber-red
    this.hazeColor = const Color(0xFF261829),
    this.ambientFlux = 0.35,
  });

  final Color zenithColor;
  final Color midAtmosphereColor;
  final Color horizonColor;
  final Color hazeColor;
  final double ambientFlux;

  /// Creates full-screen atmospheric twilight sky GI shader/gradient.
  LinearGradient createSkyGradient() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        zenithColor,
        midAtmosphereColor,
        horizonColor,
        const Color(0xFF0F111A), // Battlefield ground baseline
      ],
      stops: const <double>[0.0, 0.45, 0.85, 1.0],
    );
  }

  /// Calculates hemispherical GI irradiance ambient tone at elevation [yRatio] (0.0=top, 1.0=ground).
  Color evaluateAmbientTone(double yRatio) {
    if (yRatio < 0.5) {
      return Color.lerp(zenithColor, midAtmosphereColor, yRatio * 2.0)!;
    } else {
      return Color.lerp(midAtmosphereColor, horizonColor, (yRatio - 0.5) * 2.0)!;
    }
  }
}

/// Central coordinator managing battlefield siege lights, shadow casters, catapults, and fires.
class GuildWarSiegeLightingSystem {
  GuildWarSiegeLightingSystem({
    TwilightSkyGISystem? skyGI,
  }) : skyGI = skyGI ?? TwilightSkyGISystem() {
    _initDefaultFortressGeometry();
  }

  final TwilightSkyGISystem skyGI;
  final List<SiegeLightSource> _lights = <SiegeLightSource>[];
  final List<FortressShadowCaster> _casters = <FortressShadowCaster>[];
  final List<BurningCatapultTrail> _catapults = <BurningCatapultTrail>[];
  final List<SiegeWarFireParticle> _particles = <SiegeWarFireParticle>[];

  final math.Random _rng = math.Random(1337);
  double _simulationTime = 0.0;
  int _catapultCounter = 0;

  List<SiegeLightSource> get lights => List<SiegeLightSource>.unmodifiable(_lights);
  List<FortressShadowCaster> get casters => List<FortressShadowCaster>.unmodifiable(_casters);
  List<BurningCatapultTrail> get catapults => List<BurningCatapultTrail>.unmodifiable(_catapults);
  List<SiegeWarFireParticle> get particles => List<SiegeWarFireParticle>.unmodifiable(_particles);
  double get simulationTime => _simulationTime;

  void addLight(SiegeLightSource light) {
    _lights.add(light);
  }

  void addShadowCaster(FortressShadowCaster caster) {
    _casters.add(caster);
  }

  /// Launches a new flaming catapult projectile across the battlefield.
  BurningCatapultTrail launchCatapult({
    required SiegeVector2 origin,
    required SiegeVector2 target,
    double arcHeight = 110.0,
    double duration = 2.2,
  }) {
    _catapultCounter++;
    final BurningCatapultTrail trail = BurningCatapultTrail(
      id: 'cat_$_catapultCounter',
      origin: origin,
      target: target,
      arcHeight: arcHeight,
      totalDuration: duration,
    );
    _catapults.add(trail);
    _lights.add(trail.lightSource);
    return trail;
  }

  /// Spawns a cluster of fire and ember particles at [emitterPos].
  void emitWarFireBurst(SiegeVector2 emitterPos, {int count = 6, bool withSmoke = true}) {
    for (int i = 0; i < count; i++) {
      final double angle = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 0.9;
      final double speed = 25.0 + _rng.nextDouble() * 45.0;
      final SiegeVector2 vel = SiegeVector2(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );
      final double life = 0.5 + _rng.nextDouble() * 0.9;
      final double size = 2.0 + _rng.nextDouble() * 3.5;

      final Color flameColor = _rng.nextBool()
          ? const Color(0xFFFFD54F) // Core hot yellow
          : const Color(0xFFFF5722); // Outer burning orange

      _particles.add(SiegeWarFireParticle(
        position: emitterPos + SiegeVector2((_rng.nextDouble() - 0.5) * 8.0, 0),
        velocity: vel,
        size: size,
        maxAge: life,
        color: flameColor,
      ));
    }

    if (withSmoke && _rng.nextDouble() < 0.35) {
      _particles.add(SiegeWarFireParticle(
        position: emitterPos + const SiegeVector2(0, -6),
        velocity: SiegeVector2((_rng.nextDouble() - 0.5) * 12.0, -18.0 - _rng.nextDouble() * 15.0),
        size: 5.0,
        maxAge: 1.4 + _rng.nextDouble() * 0.8,
        color: const Color(0x55302636),
        isSmoke: true,
      ));
    }
  }

  /// Advances physics simulation and dynamic lighting flicker by [dt] seconds.
  void step(double dt) {
    _simulationTime += dt;

    // 1. Update catapult projectiles
    for (int i = _catapults.length - 1; i >= 0; i--) {
      final BurningCatapultTrail cat = _catapults[i];
      cat.update(dt);

      // Emit sparks from flying boulder
      if (!cat.isDetonated && _rng.nextDouble() < 0.6) {
        emitWarFireBurst(cat.currentPos, count: 2, withSmoke: false);
      }

      // If finished, remove light source and trail
      if (cat.isFinished) {
        _lights.remove(cat.lightSource);
        _catapults.removeAt(i);
      }
    }

    // 2. Emit ongoing fire particles from stationary war fire braziers
    for (final SiegeLightSource light in _lights) {
      if (light.type == SiegeLightType.warFireBrazier && light.isActive) {
        if (_rng.nextDouble() < 0.45) {
          emitWarFireBurst(light.position, count: 2, withSmoke: true);
        }
      }
    }

    // 3. Update active particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final SiegeWarFireParticle p = _particles[i];
      p.update(dt);
      if (p.isDead) {
        _particles.removeAt(i);
      }
    }

    // 4. Autonomous catapult volley to sustain atmospheric siege warfare
    if (_catapults.isEmpty && _simulationTime > 1.0) {
      final double startX = 20.0 + _rng.nextDouble() * 60.0;
      final double targetX = 220.0 + _rng.nextDouble() * 120.0;
      launchCatapult(
        origin: SiegeVector2(startX, 160.0),
        target: SiegeVector2(targetX, 120.0),
        arcHeight: 90.0 + _rng.nextDouble() * 50.0,
        duration: 2.0 + _rng.nextDouble() * 0.8,
      );
    }
  }

  void _initDefaultFortressGeometry() {
    // Fortress Left Bastion Wall
    addShadowCaster(FortressShadowCaster(
      id: 'bastion_left',
      start: const SiegeVector2(90.0, 110.0),
      end: const SiegeVector2(140.0, 105.0),
      height: 38.0,
    ));

    // Fortress Central Gate Tower
    addShadowCaster(FortressShadowCaster(
      id: 'gatehouse_tower',
      start: const SiegeVector2(150.0, 95.0),
      end: const SiegeVector2(210.0, 95.0),
      height: 48.0,
    ));

    // Fortress Right Curtain Wall
    addShadowCaster(FortressShadowCaster(
      id: 'curtain_right',
      start: const SiegeVector2(220.0, 105.0),
      end: const SiegeVector2(280.0, 115.0),
      height: 36.0,
    ));

    // Standing War Fire Braziers on the ramparts and siege lines
    addLight(SiegeLightSource(
      id: 'brazier_left_wall',
      position: const SiegeVector2(115.0, 98.0),
      z: 35.0,
      radius: 90.0,
      color: const Color(0xFFFF9100),
      intensity: 1.25,
      flickerRate: 5.2,
      flickerPhase: 0.2,
    ));

    addLight(SiegeLightSource(
      id: 'brazier_gate_left',
      position: const SiegeVector2(155.0, 88.0),
      z: 45.0,
      radius: 110.0,
      color: const Color(0xFFFF5722),
      intensity: 1.4,
      flickerRate: 4.8,
      flickerPhase: 1.4,
    ));

    addLight(SiegeLightSource(
      id: 'brazier_gate_right',
      position: const SiegeVector2(205.0, 88.0),
      z: 45.0,
      radius: 110.0,
      color: const Color(0xFFFF5722),
      intensity: 1.4,
      flickerRate: 5.6,
      flickerPhase: 3.1,
    ));

    addLight(SiegeLightSource(
      id: 'trench_siege_fire',
      position: const SiegeVector2(80.0, 175.0),
      z: 5.0,
      radius: 120.0,
      color: const Color(0xFFFFAB00),
      intensity: 1.1,
      flickerRate: 4.2,
      flickerPhase: 2.7,
    ));

    // Arcane Ward Crystal illumination on Central Keep
    addLight(SiegeLightSource(
      id: 'arcane_beacon',
      position: const SiegeVector2(180.0, 65.0),
      z: 60.0,
      radius: 130.0,
      color: const Color(0xFF00E5FF),
      intensity: 1.2,
      type: SiegeLightType.fortressBeacon,
      flickerRate: 2.1,
      flickerPhase: 0.5,
      flickerAmount: 0.18,
    ));
  }
}

/// Custom painter rendering dynamic war fires, siege lighting, and fortress perimeter dynamic shadows.
class GuildWarSiegeLightingPainter extends CustomPainter {
  GuildWarSiegeLightingPainter({
    required this.system,
    required this.pulseValue,
  });

  final GuildWarSiegeLightingSystem system;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Coordinate normalization factor (canvas size vs reference 360x220)
    final double scaleX = w / 360.0;
    final double scaleY = h / 220.0;

    // 1. Twilight Sky Global Illumination (GI)
    final Paint skyPaint = Paint()..shader = system.skyGI.createSkyGradient().createShader(
        Rect.fromLTWH(0, 0, w, h),
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Abyssal Distant Mountains & Fortress Silhouette
    _drawFortressSilhouette(canvas, size, scaleX, scaleY);

    // 3. Dynamic Fortress Perimeter Shadows
    _drawFortressPerimeterShadows(canvas, scaleX, scaleY);

    // 4. Clustered Light Accumulation Passes (Direct Light + Warm Radiance)
    _drawSiegeLightAccumulation(canvas, scaleX, scaleY);

    // 5. Burning Catapult Projectiles & Arcing Fiery Trails
    _drawCatapultTrails(canvas, scaleX, scaleY);

    // 6. War Fires, Rising Embers, & Smoke Plumes
    _drawWarFireParticles(canvas, scaleX, scaleY);

    // 7. Cinematic Horizon Edge Glow / Atmospheric Volumetric Dust
    _drawAtmosphericHaze(canvas, size);
  }

  void _drawFortressSilhouette(Canvas canvas, Size size, double sx, double sy) {
    final double groundY = 165.0 * sy;

    // Abyssal rugged terrain ground
    final Path terrain = Path();
    terrain.moveTo(0, groundY);
    terrain.lineTo(size.width * 0.25, groundY - 8 * sy);
    terrain.lineTo(size.width * 0.50, groundY - 4 * sy);
    terrain.lineTo(size.width * 0.85, groundY - 12 * sy);
    terrain.lineTo(size.width, groundY);
    terrain.lineTo(size.width, size.height);
    terrain.lineTo(0, size.height);
    terrain.close();

    final Paint groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF141724),
          const Color(0xFF0C0E17),
          const Color(0xFF080910),
        ],
      ).createShader(Rect.fromLTWH(0, groundY - 20, size.width, size.height - groundY + 20));
    canvas.drawPath(terrain, groundPaint);

    // Fortress Architecture Silhouette (Bastions, crenellations, towers)
    final Path fortPath = Path();
    // Left tower
    fortPath.moveTo(90 * sx, groundY);
    fortPath.lineTo(90 * sx, 105 * sy);
    fortPath.lineTo(96 * sx, 105 * sy);
    fortPath.lineTo(96 * sx, 112 * sy);
    fortPath.lineTo(104 * sx, 112 * sy);
    fortPath.lineTo(104 * sx, 105 * sy);
    fortPath.lineTo(112 * sx, 105 * sy);
    fortPath.lineTo(112 * sx, 112 * sy);
    fortPath.lineTo(120 * sx, 112 * sy);
    fortPath.lineTo(120 * sx, 105 * sy);
    fortPath.lineTo(138 * sx, 105 * sy);

    // Central Grand Keep Tower
    fortPath.lineTo(145 * sx, 85 * sy);
    fortPath.lineTo(152 * sx, 85 * sy);
    fortPath.lineTo(152 * sx, 92 * sy);
    fortPath.lineTo(162 * sx, 92 * sy);
    fortPath.lineTo(162 * sx, 85 * sy);
    // Spire
    fortPath.lineTo(175 * sx, 62 * sy);
    fortPath.lineTo(185 * sx, 62 * sy);
    fortPath.lineTo(198 * sx, 85 * sy);
    fortPath.lineTo(208 * sx, 85 * sy);
    fortPath.lineTo(208 * sx, 92 * sy);
    fortPath.lineTo(218 * sx, 92 * sy);
    fortPath.lineTo(218 * sx, 85 * sy);
    fortPath.lineTo(225 * sx, 105 * sy);

    // Right curtain wall
    fortPath.lineTo(240 * sx, 105 * sy);
    fortPath.lineTo(240 * sx, 112 * sy);
    fortPath.lineTo(248 * sx, 112 * sy);
    fortPath.lineTo(248 * sx, 105 * sy);
    fortPath.lineTo(256 * sx, 105 * sy);
    fortPath.lineTo(256 * sx, 112 * sy);
    fortPath.lineTo(264 * sx, 112 * sy);
    fortPath.lineTo(264 * sx, 105 * sy);
    fortPath.lineTo(280 * sx, 110 * sy);
    fortPath.lineTo(280 * sx, groundY);
    fortPath.close();

    final Paint fortPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF1E2235), // Top masonry catch twilight light
          const Color(0xFF121522),
          const Color(0xFF0C0E17),
        ],
      ).createShader(Rect.fromLTWH(80 * sx, 55 * sy, 210 * sx, groundY - 55 * sy));
    canvas.drawPath(fortPath, fortPaint);

    // Glowing runic ward slit on central gatehouse
    final Paint runeGlow = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.65 + 0.25 * math.sin(system.simulationTime * 3.0))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(178 * sx, 115 * sy, 6 * sx, 18 * sy),
        const Radius.circular(3),
      ),
      runeGlow,
    );
  }

  void _drawFortressPerimeterShadows(Canvas canvas, double sx, double sy) {
    for (final SiegeLightSource light in system.lights) {
      if (!light.isActive || light.radius <= 0.0) continue;

      final double lightIntensity = light.evaluateFlicker(system.simulationTime);
      if (lightIntensity <= 0.05) continue;

      for (final FortressShadowCaster caster in system.casters) {
        final List<SiegeVector2> shadowPoly = caster.projectShadowPolygon(light);
        if (shadowPoly.length != 4) continue;

        final Path polyPath = Path();
        polyPath.moveTo(shadowPoly[0].x * sx, shadowPoly[0].y * sy);
        polyPath.lineTo(shadowPoly[1].x * sx, shadowPoly[1].y * sy);
        polyPath.lineTo(shadowPoly[2].x * sx, shadowPoly[2].y * sy);
        polyPath.lineTo(shadowPoly[3].x * sx, shadowPoly[3].y * sy);
        polyPath.close();

        final double shadowAlpha = (0.55 * light.shadowHardness * (lightIntensity / light.intensity))
            .clamp(0.0, 0.75);

        final Paint shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: shadowAlpha)
          ..style = PaintingStyle.fill;

        canvas.drawPath(polyPath, shadowPaint);
      }
    }
  }

  void _drawSiegeLightAccumulation(Canvas canvas, double sx, double sy) {
    for (final SiegeLightSource light in system.lights) {
      if (!light.isActive) continue;

      final double intensity = light.evaluateFlicker(system.simulationTime);
      final double cx = light.position.x * sx;
      final double cy = light.position.y * sy;
      final double r = light.radius * math.max(sx, sy) * 0.65;

      if (r <= 0.0) continue;

      // Radial light flare & ambient wash
      final Paint lightWash = Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: <Color>[
            light.color.withValues(alpha: (0.45 * intensity).clamp(0.0, 0.9)),
            light.color.withValues(alpha: (0.15 * intensity).clamp(0.0, 0.5)),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

      canvas.drawCircle(Offset(cx, cy), r, lightWash);

      // Core hot spot
      final Paint coreFlare = Paint()
        ..blendMode = BlendMode.plus
        ..color = Colors.white.withValues(alpha: (0.35 * intensity).clamp(0.0, 0.8))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), 3.5 * sx, coreFlare);
    }
  }

  void _drawCatapultTrails(Canvas canvas, double sx, double sy) {
    for (final BurningCatapultTrail cat in system.catapults) {
      if (cat.trajectoryRibbon.length >= 2) {
        // Multi-segment flaming ribbon trail
        for (int i = 0; i < cat.trajectoryRibbon.length - 1; i++) {
          final double tNorm = i / cat.trajectoryRibbon.length;
          final Offset p1 = Offset(cat.trajectoryRibbon[i].x * sx, cat.trajectoryRibbon[i].y * sy);
          final Offset p2 = Offset(cat.trajectoryRibbon[i + 1].x * sx, cat.trajectoryRibbon[i + 1].y * sy);

          final Color segColor = Color.lerp(cat.tailColor, cat.coreColor, tNorm)!;
          final double strokeW = (1.5 + 4.0 * tNorm) * sx;

          final Paint trailPaint = Paint()
            ..color = segColor.withValues(alpha: (0.2 + 0.7 * tNorm))
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;

          canvas.drawLine(p1, p2, trailPaint);
        }
      }

      // Projectile Core Head
      final Offset head = Offset(cat.currentPos.x * sx, cat.currentPos.y * sy);
      final Paint headGlow = Paint()
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(head, 4.5 * sx, headGlow);

      final Paint hotWhite = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(head, 2.2 * sx, hotWhite);

      // Detonation shockwave flash upon impact
      if (cat.isDetonated) {
        final double dp = cat.detonationProgress;
        final Offset impact = Offset(cat.target.x * sx, cat.target.y * sy);
        final Paint shockwave = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.5 * (1.0 - dp)) * sx
          ..color = const Color(0xFFFF6D00).withValues(alpha: (1.0 - dp) * 0.85);
        canvas.drawCircle(impact, (15.0 + 45.0 * dp) * sx, shockwave);
      }
    }
  }

  void _drawWarFireParticles(Canvas canvas, double sx, double sy) {
    for (final SiegeWarFireParticle p in system.particles) {
      final Offset pos = Offset(p.position.x * sx, p.position.y * sy);
      final double life = p.lifeRemaining;
      final double r = p.size * (p.isSmoke ? (1.5 - 0.5 * life) : life) * sx;

      if (r <= 0.0) continue;

      final Paint pPaint = Paint()
        ..color = p.color.withValues(alpha: (p.color.a * life).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      if (!p.isSmoke) {
        pPaint.blendMode = BlendMode.screen;
      }

      canvas.drawCircle(pos, r, pPaint);
    }
  }

  void _drawAtmosphericHaze(Canvas canvas, Size size) {
    // Volumetric twilight dust / smoke gradient across lower horizon
    final Paint hazePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          system.skyGI.horizonColor.withValues(alpha: 0.12),
          const Color(0xFF1B0F1C).withValues(alpha: 0.22),
        ],
        stops: const <double>[0.35, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), hazePaint);
  }

  @override
  bool shouldRepaint(covariant GuildWarSiegeLightingPainter oldDelegate) => true;
}

/// Production-ready Animated Flutter Viewport displaying the 2027 Aion 2 Abyssal Siege Theatre.
class GuildWarSiegeBattlefieldViewport extends StatefulWidget {
  const GuildWarSiegeBattlefieldViewport({
    super.key,
    this.height = 200.0,
    this.interactive = true,
    this.title = '⚔ ABYSSAL KUŞATMA ALANI',
    this.subtitle = 'Dinamik kuşatma ateşi & gölge haritası',
  });

  final double height;
  final bool interactive;
  final String title;
  final String subtitle;

  @override
  State<GuildWarSiegeBattlefieldViewport> createState() =>
      _GuildWarSiegeBattlefieldViewportState();
}

class _GuildWarSiegeBattlefieldViewportState
    extends State<GuildWarSiegeBattlefieldViewport>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  late final GuildWarSiegeLightingSystem _system;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _system = GuildWarSiegeLightingSystem();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _lastTick = DateTime.now();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onViewportTap(TapDownDetails details, BoxConstraints constraints) {
    if (!widget.interactive) return;

    final double w = constraints.maxWidth;
    final double h = constraints.maxHeight;
    final double clickNormX = (details.localPosition.dx / w) * 360.0;
    final double clickNormY = (details.localPosition.dy / h) * 220.0;

    // Launch a direct catapult bombardment at tapped coordinates
    _system.launchCatapult(
      origin: const SiegeVector2(30.0, 180.0),
      target: SiegeVector2(clickNormX, clickNormY),
      arcHeight: 100.0,
      duration: 1.6,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFFF5722).withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return GestureDetector(
            onTapDown: (details) => _onViewportTap(details, constraints),
            child: Stack(
              children: <Widget>[
                // Real-time Canvas Rendering
                AnimatedBuilder(
                  animation: _ticker,
                  builder: (BuildContext context, Widget? child) {
                    final DateTime now = DateTime.now();
                    final double dt =
                        (now.difference(_lastTick).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
                    _lastTick = now;
                    _system.step(dt);

                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: GuildWarSiegeLightingPainter(
                        system: _system,
                        pulseValue: _ticker.value,
                      ),
                    );
                  },
                ),

                // Cinematic Top Banner & Threat Status
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: AppColors.coralFlare,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141926).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFF6D00).withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const <Widget>[
                            Text('🔥', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 4),
                            Text(
                              'KUŞATMA AKTİF',
                              style: TextStyle(
                                color: Color(0xFFFFAB40),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dynamic atmospheric backdrop widget wrapping Guild War screens with 2027 Aion 2
/// twilight sky GI, distant fortress silhouette, dynamic perimeter shadows, and rising war embers.
class GuildWarSiegeBackdrop extends StatefulWidget {
  const GuildWarSiegeBackdrop({
    super.key,
    required this.child,
    this.showFortress = true,
    this.ambientFireIntensity = 1.0,
  });

  final Widget child;
  final bool showFortress;
  final double ambientFireIntensity;

  @override
  State<GuildWarSiegeBackdrop> createState() => _GuildWarSiegeBackdropState();
}

class _GuildWarSiegeBackdropState extends State<GuildWarSiegeBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final GuildWarSiegeLightingSystem _system;
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _system = GuildWarSiegeLightingSystem();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _lastTick = DateTime.now();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Animated Canvas Background with Twilight GI & Siege Lighting
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (BuildContext context, Widget? child) {
              final DateTime now = DateTime.now();
              final double dt =
                  (now.difference(_lastTick).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
              _lastTick = now;
              _system.step(dt);

              return CustomPaint(
                painter: GuildWarSiegeLightingPainter(
                  system: _system,
                  pulseValue: _anim.value,
                ),
              );
            },
          ),
        ),

        // Semi-transparent deep abyssal wash for screen legibility
        Container(
          color: const Color(0xFF070B18).withValues(alpha: 0.55),
        ),

        // Foreground Screen Content
        widget.child,
      ],
    );
  }
}

/// Custom painter for dark fantasy continent terrain with 2027 Aion 2 abyssal siege lighting,
/// dynamic fortress perimeter shadows, flickering war fires, and burning catapult trails.
class ContinentTacticalMapPainter extends CustomPainter {
  ContinentTacticalMapPainter({
    required this.nodePositions,
    required this.selectedNodeIndex,
    required this.pulseValue,
  });

  final List<Offset> nodePositions;
  final int? selectedNodeIndex;
  final double pulseValue; // 0.0 to 1.0

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Dark Fantasy Continent Topography & Twilight Sky GI Mist
    final Paint bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.0, -0.2),
        radius: 1.25,
        colors: <Color>[
          Color(0xFF1E152B), // Deep mystic abyss twilight violet
          Color(0xFF121624), // Space navy
          Color(0xFF070912), // Deep abyss black
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Twilight Sky GI Horizon Ember Wash
    final Paint giWash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          const Color(0xFF38150D).withValues(alpha: 0.22),
          const Color(0xFF1B0F1C).withValues(alpha: 0.35),
        ],
        stops: const <double>[0.35, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), giWash);

    // 2. Abyssal Chasms & Continental Ridge Lines
    final Paint ridgePaint = Paint()
      ..color = const Color(0xFF28324E).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Path ridges = Path();
    ridges.moveTo(0, h * 0.35);
    ridges.cubicTo(w * 0.25, h * 0.28, w * 0.4, h * 0.48, w * 0.7, h * 0.38);
    ridges.cubicTo(w * 0.85, h * 0.32, w * 0.95, h * 0.45, w, h * 0.42);

    ridges.moveTo(w * 0.1, h * 0.75);
    ridges.cubicTo(w * 0.35, h * 0.68, w * 0.55, h * 0.85, w * 0.9, h * 0.72);
    canvas.drawPath(ridges, ridgePaint);

    // 3. Dynamic Fortress Perimeter Shadows cast onto terrain
    for (int i = 0; i < nodePositions.length; i++) {
      final Offset node = nodePositions[i];
      final double shadowLength = 20.0 + 5.0 * math.sin(pulseValue * 2 * math.pi + i);
      final double angle = (i * 1.05 + pulseValue * 0.15) % (2 * math.pi);
      final Offset shadowOffset = Offset(
        math.cos(angle) * shadowLength,
        math.sin(angle) * shadowLength * 0.45 + 5.0,
      );

      final Path shadowPoly = Path()
        ..moveTo(node.dx - 16, node.dy)
        ..lineTo(node.dx + shadowOffset.dx - 22, node.dy + shadowOffset.dy)
        ..lineTo(node.dx + shadowOffset.dx + 22, node.dy + shadowOffset.dy)
        ..lineTo(node.dx + 16, node.dy)
        ..close();

      final Paint shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..style = PaintingStyle.fill;
      canvas.drawPath(shadowPoly, shadowPaint);
    }

    // 4. Dynamic War Fires & Flickering Siege Braziers at Fortress Nodes
    for (int i = 0; i < nodePositions.length; i++) {
      final Offset node = nodePositions[i];
      final double flicker = 0.85 +
          0.15 * math.sin(pulseValue * 14.0 + i * 2.1) +
          0.08 * math.cos(pulseValue * 27.0 + i * 1.3);

      final double fireRadius = (28.0 + 8.0 * flicker);
      final Paint fireGlow = Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFF9100).withValues(alpha: (0.40 * flicker).clamp(0.0, 0.75)),
            const Color(0xFFFF3D00).withValues(alpha: (0.15 * flicker).clamp(0.0, 0.40)),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: node, radius: fireRadius));
      canvas.drawCircle(node, fireRadius, fireGlow);

      // Rising war embers from node braziers
      final double emberY = node.dy - (10.0 + (pulseValue * 30.0 + i * 14.0) % 22.0);
      final double emberX = node.dx + math.sin(pulseValue * 10.0 + i) * 6.0;
      final Paint emberPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(emberX, emberY), 1.2, emberPaint);
    }

    // 5. Ley-Line Energy Conduits Connecting Nodes
    if (nodePositions.length >= 2) {
      final Paint leyLineGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15 + 0.10 * pulseValue);

      final Paint leyLineCore = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF80DEEA).withValues(alpha: 0.45 + 0.20 * pulseValue);

      for (int i = 0; i < nodePositions.length - 1; i++) {
        final Offset p1 = nodePositions[i];
        final Offset p2 = nodePositions[i + 1];

        // Draw glowing conduits
        canvas.drawLine(p1, p2, leyLineGlow);
        canvas.drawLine(p1, p2, leyLineCore);

        // Animated ley-line pulse packet traveling between nodes
        final double t = (pulseValue + (i * 0.25)) % 1.0;
        final Offset packetPos = Offset.lerp(p1, p2, t)!;
        final Paint packetPaint = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(packetPos, 2.5, packetPaint);
      }

      // Connect last to first to close strategic perimeter
      if (nodePositions.length > 2) {
        final Offset pFirst = nodePositions.first;
        final Offset pLast = nodePositions.last;
        canvas.drawLine(pFirst, pLast, leyLineGlow);
        canvas.drawLine(pFirst, pLast, leyLineCore);
      }
    }

    // 6. Burning Catapult Ballistic Projectile Trails Arcing Across Continents
    if (nodePositions.length >= 2) {
      final int srcIdx = (pulseValue * 2.0).floor() % nodePositions.length;
      final int dstIdx = (srcIdx + 1) % nodePositions.length;
      final Offset src = nodePositions[srcIdx];
      final Offset dst = nodePositions[dstIdx];

      final double catT = (pulseValue * 2.0) % 1.0;
      // Parabolic flight
      final double projX = src.dx + (dst.dx - src.dx) * catT;
      final double arcLift = 38.0 * math.sin(catT * math.pi);
      final double projY = src.dy + (dst.dy - src.dy) * catT - arcLift;
      final Offset projPos = Offset(projX, projY);

      // Fiery trail ribbon behind catapult projectile
      for (int step = 1; step <= 5; step++) {
        final double tailT = (catT - step * 0.03).clamp(0.0, 1.0);
        final double tailX = src.dx + (dst.dx - src.dx) * tailT;
        final double tailY = src.dy + (dst.dy - src.dy) * tailT - (38.0 * math.sin(tailT * math.pi));
        final double alpha = (1.0 - step / 6.0) * 0.6;
        final Paint tailPaint = Paint()
          ..color = const Color(0xFFFF5722).withValues(alpha: alpha)
          ..strokeWidth = (5.0 - step * 0.8)
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(tailX, tailY), 1.8, tailPaint);
      }

      // Projectile core
      final Paint catCore = Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(projPos, 3.5, catCore);
      final Paint catFlare = Paint()
        ..color = const Color(0xFFFF9100).withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(projPos, 7.0, catFlare);
    }

    // 7. Highlight Ring for Selected Node
    if (selectedNodeIndex != null && selectedNodeIndex! < nodePositions.length) {
      final Offset selPos = nodePositions[selectedNodeIndex!];
      final Paint selGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = AppColors.liquidGold.withValues(alpha: 0.8 * pulseValue);
      canvas.drawCircle(selPos, 28 + 4 * pulseValue, selGlow);
    }
  }

  @override
  bool shouldRepaint(covariant ContinentTacticalMapPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.selectedNodeIndex != selectedNodeIndex ||
        oldDelegate.nodePositions != nodePositions;
  }
}


