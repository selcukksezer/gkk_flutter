import 'dart:math' as math;

/// 3D Vector tailored for game physics, knockback impulses, and ragdoll kinematics.
///
/// Designed to be immutable, performant, and self-contained without external
/// engine dependencies. Coordinate convention:
/// - X: Horizontal lateral axis (Left/Right)
/// - Y: Vertical elevation axis (Up/Down, where Y = 0 is ground plane)
/// - Z: Horizontal longitudinal axis (Forward/Backward)
class KnockbackVector3 {
  const KnockbackVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const KnockbackVector3 zero = KnockbackVector3(0.0, 0.0, 0.0);
  static const KnockbackVector3 unitX = KnockbackVector3(1.0, 0.0, 0.0);
  static const KnockbackVector3 unitY = KnockbackVector3(0.0, 1.0, 0.0);
  static const KnockbackVector3 unitZ = KnockbackVector3(0.0, 0.0, 1.0);

  KnockbackVector3 operator +(KnockbackVector3 other) =>
      KnockbackVector3(x + other.x, y + other.y, z + other.z);

  KnockbackVector3 operator -(KnockbackVector3 other) =>
      KnockbackVector3(x - other.x, y - other.y, z - other.z);

  KnockbackVector3 operator *(double scalar) =>
      KnockbackVector3(x * scalar, y * scalar, z * scalar);

  KnockbackVector3 operator /(double scalar) {
    if (scalar.abs() < 1e-9) {
      return KnockbackVector3.zero;
    }
    return KnockbackVector3(x / scalar, y / scalar, z / scalar);
  }

  KnockbackVector3 operator -() => KnockbackVector3(-x, -y, -z);

  double dot(KnockbackVector3 other) =>
      (x * other.x) + (y * other.y) + (z * other.z);

  KnockbackVector3 cross(KnockbackVector3 other) => KnockbackVector3(
        (y * other.z) - (z * other.y),
        (z * other.x) - (x * other.z),
        (x * other.y) - (y * other.x),
      );

  double get lengthSquared => (x * x) + (y * y) + (z * z);

  double get length => math.sqrt(lengthSquared);

  /// Horizontal ground-plane length (ignoring Y).
  double get horizontalLength => math.sqrt((x * x) + (z * z));

  KnockbackVector3 get normalized {
    final len = length;
    if (len < 1e-9) return KnockbackVector3.zero;
    return this / len;
  }

  /// Normalized horizontal vector on XZ plane.
  KnockbackVector3 get normalizedHorizontal {
    final hLen = horizontalLength;
    if (hLen < 1e-9) return KnockbackVector3.zero;
    return KnockbackVector3(x / hLen, 0.0, z / hLen);
  }

  double distanceTo(KnockbackVector3 other) => (this - other).length;

  /// Reflects this velocity vector across a collision surface normal:
  /// v_refl = v - (1 + e) * (v . n) * n
  KnockbackVector3 reflect(KnockbackVector3 normal, [double restitution = 1.0]) {
    final norm = normal.normalized;
    final dotProduct = dot(norm);
    if (dotProduct >= 0.0) {
      // Vector is moving away from the normal, no reflection necessary
      return this;
    }
    return this - norm * ((1.0 + restitution) * dotProduct);
  }

  KnockbackVector3 lerp(KnockbackVector3 other, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return KnockbackVector3(
      x + ((other.x - x) * clampedT),
      y + ((other.y - y) * clampedT),
      z + ((other.z - z) * clampedT),
    );
  }

  KnockbackVector3 clampMagnitude(double maxMagnitude) {
    final lenSq = lengthSquared;
    if (lenSq > maxMagnitude * maxMagnitude && maxMagnitude > 0) {
      return normalized * maxMagnitude;
    }
    return this;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KnockbackVector3 &&
        (x - other.x).abs() < 1e-7 &&
        (y - other.y).abs() < 1e-7 &&
        (z - other.z).abs() < 1e-7;
  }

  @override
  int get hashCode => Object.hash(
        (x * 1000).round(),
        (y * 1000).round(),
        (z * 1000).round(),
      );

  @override
  String toString() =>
      'KnockbackVector3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Result of collision detection against an arena boundary.
class BoundaryCollisionResult {
  const BoundaryCollisionResult({
    required this.collided,
    required this.normal,
    required this.penetrationDepth,
    required this.correctedPosition,
    this.wallImpactSpeed = 0.0,
  });

  final bool collided;
  final KnockbackVector3 normal;
  final double penetrationDepth;
  final KnockbackVector3 correctedPosition;
  final double wallImpactSpeed;
}

/// Abstract contract for arena / dungeon boundary collision detection.
abstract class CollisionBoundary {
  BoundaryCollisionResult checkAndResolve({
    required KnockbackVector3 currentPosition,
    required KnockbackVector3 velocity,
    required double characterRadius,
  });
}

/// Axis-Aligned Bounding Box (AABB) boundary representing dungeon rooms or arena fences.
class AABBCollisionBoundary implements CollisionBoundary {
  const AABBCollisionBoundary({
    required this.minX,
    required this.maxX,
    required this.minZ,
    required this.maxZ,
    this.minY,
    this.maxY,
  });

  final double minX;
  final double maxX;
  final double minZ;
  final double maxZ;
  final double? minY;
  final double? maxY;

  @override
  BoundaryCollisionResult checkAndResolve({
    required KnockbackVector3 currentPosition,
    required KnockbackVector3 velocity,
    required double characterRadius,
  }) {
    double correctedX = currentPosition.x;
    double correctedY = currentPosition.y;
    double correctedZ = currentPosition.z;

    KnockbackVector3 normal = KnockbackVector3.zero;
    double maxPenetration = 0.0;
    bool collided = false;

    // Check X boundaries
    if (currentPosition.x - characterRadius < minX) {
      final pen = minX - (currentPosition.x - characterRadius);
      if (pen > maxPenetration) {
        maxPenetration = pen;
        normal = KnockbackVector3.unitX;
      }
      correctedX = minX + characterRadius;
      collided = true;
    } else if (currentPosition.x + characterRadius > maxX) {
      final pen = (currentPosition.x + characterRadius) - maxX;
      if (pen > maxPenetration) {
        maxPenetration = pen;
        normal = -KnockbackVector3.unitX;
      }
      correctedX = maxX - characterRadius;
      collided = true;
    }

    // Check Z boundaries
    if (currentPosition.z - characterRadius < minZ) {
      final pen = minZ - (currentPosition.z - characterRadius);
      if (pen > maxPenetration) {
        maxPenetration = pen;
        normal = KnockbackVector3.unitZ;
      }
      correctedZ = minZ + characterRadius;
      collided = true;
    } else if (currentPosition.z + characterRadius > maxZ) {
      final pen = (currentPosition.z + characterRadius) - maxZ;
      if (pen > maxPenetration) {
        maxPenetration = pen;
        normal = -KnockbackVector3.unitZ;
      }
      correctedZ = maxZ - characterRadius;
      collided = true;
    }

    // Optional Y boundaries (e.g. ceiling)
    if (maxY != null && currentPosition.y + characterRadius > maxY!) {
      final pen = (currentPosition.y + characterRadius) - maxY!;
      if (pen > maxPenetration) {
        maxPenetration = pen;
        normal = -KnockbackVector3.unitY;
      }
      correctedY = maxY! - characterRadius;
      collided = true;
    }

    final impactSpeed = normal != KnockbackVector3.zero
        ? (-velocity.dot(normal)).clamp(0.0, double.infinity)
        : 0.0;

    return BoundaryCollisionResult(
      collided: collided,
      normal: normal,
      penetrationDepth: maxPenetration,
      correctedPosition: KnockbackVector3(correctedX, correctedY, correctedZ),
      wallImpactSpeed: impactSpeed,
    );
  }
}

/// Cylindrical / Circular arena boundary (e.g. gladiator pit or circular boss room).
class CircularCollisionBoundary implements CollisionBoundary {
  const CircularCollisionBoundary({
    this.center = KnockbackVector3.zero,
    required this.radius,
  });

  final KnockbackVector3 center;
  final double radius;

  @override
  BoundaryCollisionResult checkAndResolve({
    required KnockbackVector3 currentPosition,
    required KnockbackVector3 velocity,
    required double characterRadius,
  }) {
    final dx = currentPosition.x - center.x;
    final dz = currentPosition.z - center.z;
    final horizontalDist = math.sqrt((dx * dx) + (dz * dz));
    final maxAllowedDist = radius - characterRadius;

    if (horizontalDist > maxAllowedDist && horizontalDist > 1e-9) {
      final nx = -dx / horizontalDist;
      final nz = -dz / horizontalDist;
      final normal = KnockbackVector3(nx, 0.0, nz);
      final penetration = horizontalDist - maxAllowedDist;
      final correctedX = center.x + (dx / horizontalDist) * maxAllowedDist;
      final correctedZ = center.z + (dz / horizontalDist) * maxAllowedDist;

      final impactSpeed = (-velocity.dot(normal)).clamp(0.0, double.infinity);

      return BoundaryCollisionResult(
        collided: true,
        normal: normal,
        penetrationDepth: penetration,
        correctedPosition: KnockbackVector3(correctedX, currentPosition.y, correctedZ),
        wallImpactSpeed: impactSpeed,
      );
    }

    return BoundaryCollisionResult(
      collided: false,
      normal: KnockbackVector3.zero,
      penetrationDepth: 0.0,
      correctedPosition: currentPosition,
      wallImpactSpeed: 0.0,
    );
  }
}

/// Planar wall boundary defined by a plane normal and distance from origin.
class PlaneCollisionBoundary implements CollisionBoundary {
  const PlaneCollisionBoundary({
    required this.normal,
    required this.distance,
  });

  final KnockbackVector3 normal;
  final double distance;

  @override
  BoundaryCollisionResult checkAndResolve({
    required KnockbackVector3 currentPosition,
    required KnockbackVector3 velocity,
    required double characterRadius,
  }) {
    final n = normal.normalized;
    final signedDist = currentPosition.dot(n) - distance;

    if (signedDist < characterRadius) {
      final penetration = characterRadius - signedDist;
      final corrected = currentPosition + n * penetration;
      final impactSpeed = (-velocity.dot(n)).clamp(0.0, double.infinity);

      return BoundaryCollisionResult(
        collided: true,
        normal: n,
        penetrationDepth: penetration,
        correctedPosition: corrected,
        wallImpactSpeed: impactSpeed,
      );
    }

    return BoundaryCollisionResult(
      collided: false,
      normal: KnockbackVector3.zero,
      penetrationDepth: 0.0,
      correctedPosition: currentPosition,
      wallImpactSpeed: 0.0,
    );
  }
}

/// Phase states of the physical stagger / ragdoll blend lifecycle.
enum RagdollPhase {
  /// No physical impulse active; character under 100% animator control.
  idle,

  /// Rapidly blending from animation pose into physical ragdoll displacement.
  blendingIn,

  /// Full physical momentum simulation (sliding, airborne arc, wall bounce).
  ragdollActive,

  /// Velocity has settled; smoothly recovering back to standard animator control.
  recovering,
}

/// Mode defining how animator root motion and physics impulse are blended.
enum RootMotionCombineMode {
  /// Physics displacement is added on top of animator motion, with animator
  /// contribution scaled down during high ragdoll weight.
  additive,

  /// Linear interpolation between pure animator displacement (weight = 0)
  /// and pure physics displacement (weight = 1).
  blended,
}

/// Procedural spine tilt state driven by a damped harmonic spring.
/// Produces realistic reactive wobbles and leans on impact.
class SpineTilt {
  const SpineTilt({
    this.pitch = 0.0,
    this.roll = 0.0,
    this.yaw = 0.0,
    this.pitchVelocity = 0.0,
    this.rollVelocity = 0.0,
    this.yawVelocity = 0.0,
  });

  /// Forward / backward tilt angle in radians.
  final double pitch;

  /// Sideways lean angle in radians.
  final double roll;

  /// Rotational twist angle in radians.
  final double yaw;

  final double pitchVelocity;
  final double rollVelocity;
  final double yawVelocity;

  static const SpineTilt zero = SpineTilt();

  SpineTilt update({
    required double dt,
    required double springStiffness,
    required double damping,
  }) {
    // Damped harmonic oscillator: a = -k * theta - c * omega
    final pitchAcc = (-springStiffness * pitch) - (damping * pitchVelocity);
    final rollAcc = (-springStiffness * roll) - (damping * rollVelocity);
    final yawAcc = (-springStiffness * yaw) - (damping * yawVelocity);

    final newPitchVel = pitchVelocity + (pitchAcc * dt);
    final newRollVel = rollVelocity + (rollAcc * dt);
    final newYawVel = yawVelocity + (yawAcc * dt);

    final newPitch = pitch + (newPitchVel * dt);
    final newRoll = roll + (newRollVel * dt);
    final newYaw = yaw + (newYawVel * dt);

    // Snap to zero if settled
    final totalEnergy = (newPitch * newPitch) +
        (newRoll * newRoll) +
        (newYaw * newYaw) +
        (newPitchVel * newPitchVel) +
        (newRollVel * newRollVel) +
        (newYawVel * newYawVel);

    if (totalEnergy < 2e-4) {
      return SpineTilt.zero;
    }

    return SpineTilt(
      pitch: newPitch,
      roll: newRoll,
      yaw: newYaw,
      pitchVelocity: newPitchVel,
      rollVelocity: newRollVel,
      yawVelocity: newYawVel,
    );
  }

  SpineTilt applyAngularImpulse({
    required double deltaPitch,
    required double deltaRoll,
    required double deltaYaw,
  }) {
    return SpineTilt(
      pitch: pitch,
      roll: roll,
      yaw: yaw,
      pitchVelocity: pitchVelocity + deltaPitch,
      rollVelocity: rollVelocity + deltaRoll,
      yawVelocity: yawVelocity + deltaYaw,
    );
  }
}

/// Description of an incoming combat hit impulse.
class KnockbackImpulse {
  const KnockbackImpulse({
    required this.impulse,
    this.verticalLaunchImpulse = 0.0,
    this.isCriticalHit = false,
    this.customRagdollPeakWeight,
    this.customFrictionFactor,
    this.sourceAttackerId,
  });

  /// Linear impulse momentum vector in kg * m/s.
  final KnockbackVector3 impulse;

  /// Additional upward vertical launch impulse.
  final double verticalLaunchImpulse;

  /// Critical hit flag — triggers dramatic airborne arc and full ragdoll blend.
  final bool isCriticalHit;

  /// Optional peak blend weight override (0.0 to 1.0).
  final double? customRagdollPeakWeight;

  /// Optional multiplier on ground friction for specific attacks (e.g. ice vs mud).
  final double? customFrictionFactor;

  /// Identifier of the entity originating the hit.
  final String? sourceAttackerId;
}

/// Configuration settings for mass, resistance, friction, gravity, and blend times.
class KnockbackConfig {
  const KnockbackConfig({
    this.mass = 70.0,
    this.poiseArmor = 0.0,
    this.groundFriction = 7.5,
    this.gravity = 18.0,
    this.groundRestitution = 0.22,
    this.wallRestitution = 0.45,
    this.airDrag = 0.12,
    this.blendInDuration = 0.05,
    this.blendOutDuration = 0.25,
    this.defaultMaxRagdollWeight = 1.0,
    this.wallSplatSpeedThreshold = 7.0,
    this.restVelocityThreshold = 0.08,
    this.angularSpringStiffness = 45.0,
    this.angularSpringDamping = 9.0,
    this.rootMotionCombineMode = RootMotionCombineMode.additive,
  });

  /// Target character mass in kilograms (minimum 1.0 kg).
  final double mass;

  /// Poise / hyper-armor factor. Reduces impulse by 1 / (1 + poiseArmor).
  final double poiseArmor;

  /// Dynamic ground friction coefficient (mu * g deceleration).
  final double groundFriction;

  /// Gravitational acceleration in m/s^2 (downward Y).
  final double gravity;

  /// Elasticity of ground bounce on landing (0.0 = inelastic, 1.0 = elastic).
  final double groundRestitution;

  /// Elasticity of arena wall reflection (0.0 = stops at wall, 1.0 = full reflection).
  final double wallRestitution;

  /// Aerodynamic drag coefficient acting during airborne arcs.
  final double airDrag;

  /// Duration in seconds to blend into peak ragdoll weight.
  final double blendInDuration;

  /// Duration in seconds to smoothly recover back to animator control.
  final double blendOutDuration;

  /// Peak ragdoll blend weight (0.0 to 1.0).
  final double defaultMaxRagdollWeight;

  /// Threshold velocity (m/s) triggering a wall-splat stagger / event.
  final double wallSplatSpeedThreshold;

  /// Velocity threshold below which physical motion is considered settled.
  final double restVelocityThreshold;

  /// Spring stiffness for procedural spine hit-reaction tilt.
  final double angularSpringStiffness;

  /// Damping factor for procedural spine hit-reaction tilt.
  final double angularSpringDamping;

  /// How root motion and physics displacements are merged.
  final RootMotionCombineMode rootMotionCombineMode;

  /// Combat Presets tailored for varying attack weights.
  static const KnockbackConfig lightStagger = KnockbackConfig(
    mass: 70.0,
    poiseArmor: 0.0,
    groundFriction: 12.0,
    gravity: 18.0,
    blendInDuration: 0.03,
    blendOutDuration: 0.15,
    defaultMaxRagdollWeight: 0.35,
    wallRestitution: 0.2,
  );

  static const KnockbackConfig mediumHit = KnockbackConfig(
    mass: 70.0,
    poiseArmor: 0.0,
    groundFriction: 8.0,
    gravity: 18.0,
    blendInDuration: 0.05,
    blendOutDuration: 0.25,
    defaultMaxRagdollWeight: 0.65,
    wallRestitution: 0.35,
  );

  static const KnockbackConfig heavySmash = KnockbackConfig(
    mass: 70.0,
    poiseArmor: 0.0,
    groundFriction: 5.5,
    gravity: 19.0,
    blendInDuration: 0.06,
    blendOutDuration: 0.35,
    defaultMaxRagdollWeight: 0.90,
    wallRestitution: 0.50,
  );

  static const KnockbackConfig criticalLaunch = KnockbackConfig(
    mass: 70.0,
    poiseArmor: 0.0,
    groundFriction: 5.0,
    gravity: 16.5,
    groundRestitution: 0.30,
    blendInDuration: 0.08,
    blendOutDuration: 0.45,
    defaultMaxRagdollWeight: 1.0,
    wallRestitution: 0.60,
  );

  static const KnockbackConfig bossPoise = KnockbackConfig(
    mass: 350.0,
    poiseArmor: 4.0,
    groundFriction: 14.0,
    gravity: 25.0,
    blendInDuration: 0.02,
    blendOutDuration: 0.10,
    defaultMaxRagdollWeight: 0.15,
    wallRestitution: 0.10,
  );

  KnockbackConfig copyWith({
    double? mass,
    double? poiseArmor,
    double? groundFriction,
    double? gravity,
    double? groundRestitution,
    double? wallRestitution,
    double? airDrag,
    double? blendInDuration,
    double? blendOutDuration,
    double? defaultMaxRagdollWeight,
    double? wallSplatSpeedThreshold,
    double? restVelocityThreshold,
    double? angularSpringStiffness,
    double? angularSpringDamping,
    RootMotionCombineMode? rootMotionCombineMode,
  }) {
    return KnockbackConfig(
      mass: mass ?? this.mass,
      poiseArmor: poiseArmor ?? this.poiseArmor,
      groundFriction: groundFriction ?? this.groundFriction,
      gravity: gravity ?? this.gravity,
      groundRestitution: groundRestitution ?? this.groundRestitution,
      wallRestitution: wallRestitution ?? this.wallRestitution,
      airDrag: airDrag ?? this.airDrag,
      blendInDuration: blendInDuration ?? this.blendInDuration,
      blendOutDuration: blendOutDuration ?? this.blendOutDuration,
      defaultMaxRagdollWeight:
          defaultMaxRagdollWeight ?? this.defaultMaxRagdollWeight,
      wallSplatSpeedThreshold:
          wallSplatSpeedThreshold ?? this.wallSplatSpeedThreshold,
      restVelocityThreshold:
          restVelocityThreshold ?? this.restVelocityThreshold,
      angularSpringStiffness:
          angularSpringStiffness ?? this.angularSpringStiffness,
      angularSpringDamping:
          angularSpringDamping ?? this.angularSpringDamping,
      rootMotionCombineMode:
          rootMotionCombineMode ?? this.rootMotionCombineMode,
    );
  }
}

/// Event data payload for boundary collisions.
class WallCollisionEvent {
  const WallCollisionEvent({
    required this.contactPosition,
    required this.normal,
    required this.impactSpeed,
    required this.isWallSplat,
  });

  final KnockbackVector3 contactPosition;
  final KnockbackVector3 normal;
  final double impactSpeed;
  final bool isWallSplat;
}

/// State snapshot for debugging, HUD display, or unit test inspection.
class KnockbackState {
  const KnockbackState({
    required this.position,
    required this.velocity,
    required this.ragdollWeight,
    required this.phase,
    required this.isAirborne,
    required this.isActive,
    required this.spineTilt,
    required this.totalElapsedTime,
    required this.peakApexHeight,
  });

  final KnockbackVector3 position;
  final KnockbackVector3 velocity;
  final double ragdollWeight;
  final RagdollPhase phase;
  final bool isAirborne;
  final bool isActive;
  final SpineTilt spineTilt;
  final double totalElapsedTime;
  final double peakApexHeight;
}

/// Production-ready Knockback Impulse & Physical Stagger / Ragdoll Blend Controller.
///
/// Features:
/// 1. Real velocity impulse vector calculation with mass resistance, hyper-armor,
///    Coulomb & aerodynamic friction decay, and boundary collision reflection.
/// 2. Procedural hit-reaction blend transitioning between animator root motion
///    and dynamic physical impulse via configurable blend curves.
/// 3. Procedural spine tilt driven by a damped harmonic spring for AAA game feel.
/// 4. Critical hit airborne arc trajectory calculation with gravitational
///    acceleration, apex detection, and ground landing restitution.
/// 5. Boundary collision reflection against AABB, circular pits, and arbitrary planes
///    with positional depenetration and wall-splat triggering.
class KnockbackRagdollController {
  KnockbackRagdollController({
    KnockbackConfig? config,
    this.boundary,
    this.characterRadius = 0.4,
    KnockbackVector3? initialPosition,
    this.onKnockbackStarted,
    this.onAirborneApex,
    this.onGroundImpact,
    this.onWallCollision,
    this.onRagdollBlendChanged,
    this.onKnockbackFinished,
  })  : config = config ?? const KnockbackConfig(),
        _position = initialPosition ?? KnockbackVector3.zero;

  KnockbackConfig config;
  CollisionBoundary? boundary;
  final double characterRadius;

  // Callbacks
  void Function(KnockbackImpulse impulse)? onKnockbackStarted;
  void Function(KnockbackVector3 position, double apexHeight)? onAirborneApex;
  void Function(KnockbackVector3 position, double impactVelocity)?
      onGroundImpact;
  void Function(WallCollisionEvent event)? onWallCollision;
  void Function(double blendWeight)? onRagdollBlendChanged;
  void Function()? onKnockbackFinished;

  // State variables
  KnockbackVector3 _position;
  KnockbackVector3 _velocity = KnockbackVector3.zero;
  SpineTilt _spineTilt = SpineTilt.zero;
  RagdollPhase _phase = RagdollPhase.idle;
  double _ragdollWeight = 0.0;
  bool _isAirborne = false;
  bool _apexReached = false;
  double _peakApexHeight = 0.0;

  double _phaseTime = 0.0;
  double _totalElapsedTime = 0.0;
  double _currentMaxRagdollWeight = 1.0;
  double _startBlendWeight = 0.0;

  // Getters
  KnockbackVector3 get position => _position;
  KnockbackVector3 get velocity => _velocity;
  SpineTilt get spineTilt => _spineTilt;
  RagdollPhase get phase => _phase;
  double get ragdollWeight => _ragdollWeight;
  bool get isAirborne => _isAirborne;
  bool get isActive => _phase != RagdollPhase.idle;
  double get peakApexHeight => _peakApexHeight;
  double get totalElapsedTime => _totalElapsedTime;

  /// Applies a physical knockback impulse vector to the target.
  ///
  /// Initial velocity change follows Newton's second law:
  /// Delta v = Impulse / (Effective Mass)
  /// where Effective Mass = mass * (1.0 + poiseArmor).
  void applyImpulse(KnockbackImpulse impulse) {
    final effectiveMass =
        math.max(1.0, config.mass) * (1.0 + math.max(0.0, config.poiseArmor));

    // Linear impulse velocity change
    final deltaV = impulse.impulse / effectiveMass;

    // Upward launch component
    var verticalV = 0.0;
    if (impulse.isCriticalHit) {
      // Critical hit gives automatic launch boost
      verticalV = math.max(6.0, impulse.verticalLaunchImpulse / effectiveMass);
    } else if (impulse.verticalLaunchImpulse > 0.0) {
      verticalV = impulse.verticalLaunchImpulse / effectiveMass;
    }

    // New combined velocity
    _velocity = KnockbackVector3(
      _velocity.x + deltaV.x,
      _velocity.y + deltaV.y + verticalV,
      _velocity.z + deltaV.z,
    );

    // Airborne state transition
    if (_position.y > 0.01 || _velocity.y > 0.1) {
      _isAirborne = true;
      _apexReached = false;
      _peakApexHeight = math.max(_peakApexHeight, _position.y);
    }

    // Configure ragdoll blending
    _currentMaxRagdollWeight = (impulse.customRagdollPeakWeight ??
            (impulse.isCriticalHit
                ? 1.0
                : config.defaultMaxRagdollWeight))
        .clamp(0.0, 1.0);

    _startBlendWeight = _ragdollWeight;
    _phase = RagdollPhase.blendingIn;
    _phaseTime = 0.0;

    // Apply procedural spine tilt impulse based on horizontal impact direction
    _applySpineTiltImpulse(deltaV);

    onKnockbackStarted?.call(impulse);
    _notifyBlendChanged();
  }

  /// Convenience method for applying a directional hit from an attacker position.
  void applyDirectionalHit({
    required KnockbackVector3 hitDirection,
    required double impulseMagnitude,
    double verticalRatio = 0.25,
    bool isCritical = false,
    double? peakWeight,
    String? attackerId,
  }) {
    final dir = hitDirection.normalized;
    final horizontalDir =
        KnockbackVector3(dir.x, 0.0, dir.z).normalizedHorizontal;

    final horizontalImpulse =
        horizontalDir * (impulseMagnitude * (1.0 - verticalRatio));
    final verticalImpulse = impulseMagnitude * verticalRatio;

    applyImpulse(KnockbackImpulse(
      impulse: horizontalImpulse,
      verticalLaunchImpulse: verticalImpulse,
      isCriticalHit: isCritical,
      customRagdollPeakWeight: peakWeight,
      sourceAttackerId: attackerId,
    ));
  }

  /// Calculates procedural angular tilt kick to simulate torso reaction.
  void _applySpineTiltImpulse(KnockbackVector3 deltaV) {
    final hSpeed = deltaV.horizontalLength;
    if (hSpeed < 1e-4) return;

    // Lean backwards along direction of impulse, tilt sideways
    // Pitch: positive is forward lean, negative is backward lean
    final pitchKick = -deltaV.z * 0.05;
    final rollKick = deltaV.x * 0.05;
    final yawKick = (deltaV.x * deltaV.z) * 0.02;

    _spineTilt = _spineTilt.applyAngularImpulse(
      deltaPitch: pitchKick.clamp(-1.2, 1.2),
      deltaRoll: rollKick.clamp(-1.2, 1.2),
      deltaYaw: yawKick.clamp(-0.8, 0.8),
    );
  }

  /// Updates physics simulation, ragdoll blend weights, and collisions for time step [dt].
  ///
  /// [animatorRootMotionDelta] is the displacement vector that the animation clip
  /// attempted to travel during this frame.
  ///
  /// Returns the net combined displacement vector to apply to the character transform.
  KnockbackVector3 update(
    double dt, {
    KnockbackVector3 animatorRootMotionDelta = KnockbackVector3.zero,
  }) {
    if (dt <= 0.0) return KnockbackVector3.zero;

    // If completely idle, pass through animator root motion
    if (_phase == RagdollPhase.idle && _velocity.lengthSquared < 1e-8) {
      _position = _position + animatorRootMotionDelta;
      return animatorRootMotionDelta;
    }

    // Sub-step large delta times for numerical integration stability (<= 16.6ms per step)
    const maxSubStep = 1.0 / 60.0;
    var remainingTime = dt;
    var totalPhysicsDisplacement = KnockbackVector3.zero;

    while (remainingTime > 1e-7) {
      final step = math.min(remainingTime, maxSubStep);
      final stepDisplacement = _integratePhysicsStep(step);
      totalPhysicsDisplacement = totalPhysicsDisplacement + stepDisplacement;
      remainingTime -= step;
    }

    _totalElapsedTime += dt;

    // Update spine tilt harmonic spring
    _spineTilt = _spineTilt.update(
      dt: dt,
      springStiffness: config.angularSpringStiffness,
      damping: config.angularSpringDamping,
    );

    // Update Ragdoll Blend weight lifecycle
    _updateBlendState(dt);

    // Combine animator root motion with physics impulse
    final combinedDisplacement = _combineDisplacements(
      physicsDelta: totalPhysicsDisplacement,
      animatorDelta: animatorRootMotionDelta,
    );

    return combinedDisplacement;
  }

  /// Numerical physics integration step (Verlet / Semi-implicit Euler).
  KnockbackVector3 _integratePhysicsStep(double dt) {
    final startPos = _position;

    // 1. Airborne & Gravity Integration
    if (_isAirborne) {
      // Aerodynamic drag opposing velocity vector
      final speed = _velocity.length;
      final dragForce = speed > 1e-4 ? _velocity * (config.airDrag * speed) : KnockbackVector3.zero;

      // Downward gravity: acceleration on Y
      final gravityAcc = -config.gravity;

      final newVx = _velocity.x - (dragForce.x * dt);
      final newVy = _velocity.y + (gravityAcc * dt) - (dragForce.y * dt);
      final newVz = _velocity.z - (dragForce.z * dt);

      // Midpoint velocity integration: (v_start + v_end) / 2
      final midVx = (_velocity.x + newVx) * 0.5;
      final midVy = (_velocity.y + newVy) * 0.5;
      final midVz = (_velocity.z + newVz) * 0.5;

      final previousVy = _velocity.y;
      _velocity = KnockbackVector3(newVx, newVy, newVz);

      // Integrate position
      var proposedY = _position.y + (midVy * dt);
      var proposedX = _position.x + (midVx * dt);
      var proposedZ = _position.z + (midVz * dt);

      // Track maximum apex elevation
      if (proposedY > _peakApexHeight) {
        _peakApexHeight = proposedY;
      }

      // Check apex detection
      if (!_apexReached && previousVy > 0.0 && newVy <= 0.0) {
        _apexReached = true;
        onAirborneApex?.call(
          KnockbackVector3(proposedX, proposedY, proposedZ),
          _peakApexHeight,
        );
      }

      // Check Ground Contact (Y <= 0)
      if (proposedY <= 0.0) {
        proposedY = 0.0;
        final impactSpeed = -_velocity.y;

        // Ground restitution bounce
        final bounceVy = impactSpeed * config.groundRestitution;

        // Landing shock friction damps horizontal velocity
        final landingFriction = math.max(0.4, 1.0 - (config.groundRestitution * 0.5));
        final horizontalVx = _velocity.x * (1.0 - landingFriction);
        final horizontalVz = _velocity.z * (1.0 - landingFriction);

        if (bounceVy < 1.2) {
          // Settled on ground
          _velocity = KnockbackVector3(horizontalVx, 0.0, horizontalVz);
          _isAirborne = false;
        } else {
          // Bouncing off ground
          _velocity = KnockbackVector3(horizontalVx, bounceVy, horizontalVz);
          _apexReached = false;
        }

        onGroundImpact?.call(
          KnockbackVector3(proposedX, 0.0, proposedZ),
          impactSpeed,
        );
      }

      _position = KnockbackVector3(proposedX, proposedY, proposedZ);
    } else {
      // 2. Ground Sliding Friction Decay
      final hSpeed = _velocity.horizontalLength;

      if (hSpeed > 1e-4) {
        // Dynamic kinetic friction deceleration: a_fric = mu * g
        final frictionDecel = config.groundFriction * config.gravity;
        final speedDrop = frictionDecel * dt;

        if (speedDrop >= hSpeed || hSpeed < config.restVelocityThreshold) {
          // Velocity settled to zero
          _velocity = KnockbackVector3(0.0, 0.0, 0.0);
        } else {
          final scale = (hSpeed - speedDrop) / hSpeed;
          _velocity = KnockbackVector3(
            _velocity.x * scale,
            0.0,
            _velocity.z * scale,
          );
        }

        _position = _position + (_velocity * dt);
      } else {
        _velocity = KnockbackVector3.zero;
      }
    }

    // 3. Boundary Collision & Reflection
    if (boundary != null) {
      final col = boundary!.checkAndResolve(
        currentPosition: _position,
        velocity: _velocity,
        characterRadius: characterRadius,
      );

      if (col.collided) {
        _position = col.correctedPosition;

        // Reflect velocity across collision normal with wall restitution
        final reflected = _velocity.reflect(col.normal, config.wallRestitution);

        final isWallSplat = col.wallImpactSpeed >= config.wallSplatSpeedThreshold;

        // On wall-splat, apply additional spine tilt and ragdoll shock
        if (isWallSplat) {
          _spineTilt = _spineTilt.applyAngularImpulse(
            deltaPitch: -col.normal.z * 0.6,
            deltaRoll: col.normal.x * 0.6,
            deltaYaw: 0.3,
          );
        }

        _velocity = reflected;

        onWallCollision?.call(WallCollisionEvent(
          contactPosition: col.correctedPosition,
          normal: col.normal,
          impactSpeed: col.wallImpactSpeed,
          isWallSplat: isWallSplat,
        ));
      }
    }

    return _position - startPos;
  }

  /// Advances the ragdoll blend weight state machine.
  void _updateBlendState(double dt) {
    _phaseTime += dt;

    switch (_phase) {
      case RagdollPhase.idle:
        _ragdollWeight = 0.0;
        break;

      case RagdollPhase.blendingIn:
        final blendInDuration = math.max(0.001, config.blendInDuration);
        final progress = (_phaseTime / blendInDuration).clamp(0.0, 1.0);

        // Smooth cubic ease-in-out: 3t^2 - 2t^3
        final ease = (progress * progress) * (3.0 - (2.0 * progress));
        _ragdollWeight = _startBlendWeight +
            ((_currentMaxRagdollWeight - _startBlendWeight) * ease);

        if (progress >= 1.0) {
          _ragdollWeight = _currentMaxRagdollWeight;
          _phase = RagdollPhase.ragdollActive;
          _phaseTime = 0.0;
        }
        _notifyBlendChanged();
        break;

      case RagdollPhase.ragdollActive:
        _ragdollWeight = _currentMaxRagdollWeight;

        // Transition to recovery when physics motion has settled
        final isMoving = _isAirborne ||
            _velocity.horizontalLength > config.restVelocityThreshold;

        if (!isMoving) {
          _phase = RagdollPhase.recovering;
          _phaseTime = 0.0;
          _startBlendWeight = _ragdollWeight;
        }
        break;

      case RagdollPhase.recovering:
        final blendOutDuration = math.max(0.001, config.blendOutDuration);
        final progress = (_phaseTime / blendOutDuration).clamp(0.0, 1.0);

        // Smooth cubic ease-out
        final ease = 1.0 - (progress * progress * (3.0 - (2.0 * progress)));
        _ragdollWeight = (_startBlendWeight * ease).clamp(0.0, 1.0);

        if (progress >= 1.0) {
          _ragdollWeight = 0.0;
          _phase = RagdollPhase.idle;
          _phaseTime = 0.0;
          _peakApexHeight = 0.0;
          onKnockbackFinished?.call();
        }
        _notifyBlendChanged();
        break;
    }
  }

  /// Combines animator root motion displacement with physics impulse displacement.
  KnockbackVector3 _combineDisplacements({
    required KnockbackVector3 physicsDelta,
    required KnockbackVector3 animatorDelta,
  }) {
    switch (config.rootMotionCombineMode) {
      case RootMotionCombineMode.additive:
        // Animator displacement is scaled down as ragdoll weight approaches 1.0
        // (so violent physics impulse suppresses animator root motion).
        final animatorWeight = (1.0 - (_ragdollWeight * 0.85)).clamp(0.0, 1.0);
        return physicsDelta + (animatorDelta * animatorWeight);

      case RootMotionCombineMode.blended:
        // Pure lerp between animator delta and physics delta based on ragdoll weight.
        return animatorDelta.lerp(physicsDelta, _ragdollWeight);
    }
  }

  void _notifyBlendChanged() {
    onRagdollBlendChanged?.call(_ragdollWeight);
  }

  /// Resets controller state to rest position.
  void reset({KnockbackVector3? newPosition}) {
    _position = newPosition ?? KnockbackVector3.zero;
    _velocity = KnockbackVector3.zero;
    _spineTilt = SpineTilt.zero;
    _phase = RagdollPhase.idle;
    _ragdollWeight = 0.0;
    _isAirborne = false;
    _apexReached = false;
    _peakApexHeight = 0.0;
    _phaseTime = 0.0;
    _totalElapsedTime = 0.0;
    _startBlendWeight = 0.0;
    _notifyBlendChanged();
  }

  /// Captures an immutable state snapshot for telemetry, debug overlays, or inspection.
  KnockbackState getStateSnapshot() {
    return KnockbackState(
      position: _position,
      velocity: _velocity,
      ragdollWeight: _ragdollWeight,
      phase: _phase,
      isAirborne: _isAirborne,
      isActive: isActive,
      spineTilt: _spineTilt,
      totalElapsedTime: _totalElapsedTime,
      peakApexHeight: _peakApexHeight,
    );
  }
}
