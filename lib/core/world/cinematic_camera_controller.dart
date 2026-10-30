import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// High-precision 3D Cartesian vector with value equality and math operators.
class WorldVector3 {
  final double x;
  final double y;
  final double z;

  const WorldVector3(this.x, this.y, this.z);

  static const WorldVector3 zero = WorldVector3(0.0, 0.0, 0.0);
  static const WorldVector3 up = WorldVector3(0.0, 1.0, 0.0);
  static const WorldVector3 forward = WorldVector3(0.0, 0.0, 1.0);
  static const WorldVector3 right = WorldVector3(1.0, 0.0, 0.0);

  WorldVector3 operator +(WorldVector3 other) =>
      WorldVector3(x + other.x, y + other.y, z + other.z);

  WorldVector3 operator -(WorldVector3 other) =>
      WorldVector3(x - other.x, y - other.y, z - other.z);

  WorldVector3 operator *(double scalar) =>
      WorldVector3(x * scalar, y * scalar, z * scalar);

  WorldVector3 operator /(double scalar) =>
      scalar == 0.0 ? WorldVector3.zero : WorldVector3(x / scalar, y / scalar, z / scalar);

  WorldVector3 operator -() => WorldVector3(-x, -y, -z);

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  WorldVector3 normalized() {
    final len = length;
    if (len < 1e-9) return WorldVector3.zero;
    return WorldVector3(x / len, y / len, z / len);
  }

  double dot(WorldVector3 other) => x * other.x + y * other.y + z * other.z;

  WorldVector3 cross(WorldVector3 other) {
    return WorldVector3(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  double distanceTo(WorldVector3 other) => (this - other).length;

  static WorldVector3 lerp(WorldVector3 a, WorldVector3 b, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return WorldVector3(
      a.x + (b.x - a.x) * clampedT,
      a.y + (b.y - a.y) * clampedT,
      a.z + (b.z - a.z) * clampedT,
    );
  }

  /// Converts (x, y) to standard 2D Flutter Offset.
  Offset toOffset() => Offset(x, y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldVector3 &&
          runtimeType == other.runtimeType &&
          (x - other.x).abs() < 1e-7 &&
          (y - other.y).abs() < 1e-7 &&
          (z - other.z).abs() < 1e-7;

  @override
  int get hashCode => Object.hash(
        (x * 1000).round(),
        (y * 1000).round(),
        (z * 1000).round(),
      );

  @override
  String toString() =>
      'WorldVector3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// Spherical coordinates for 3D orbital camera placement around a focal point.
class OrbitalCoordinates {
  /// Azimuth angle in radians (horizontal yaw around vertical axis).
  final double azimuth;

  /// Elevation angle in radians (vertical pitch above horizon).
  final double elevation;

  /// Radius distance in world units from focal pivot.
  final double distance;

  const OrbitalCoordinates({
    required this.azimuth,
    required this.elevation,
    required this.distance,
  });

  /// Converts spherical angles to a 3D Cartesian offset vector relative to target.
  /// Coordinate system: Y = Up, Z = Forward, X = Right.
  WorldVector3 toCartesianOffset() {
    final cosElev = math.cos(elevation);
    final sinElev = math.sin(elevation);
    final sinAzim = math.sin(azimuth);
    final cosAzim = math.cos(azimuth);

    return WorldVector3(
      distance * cosElev * sinAzim,
      distance * sinElev,
      distance * cosElev * cosAzim,
    );
  }

  /// Reconstructs orbital coordinates from a 3D relative offset vector.
  static OrbitalCoordinates fromCartesianOffset(WorldVector3 offset) {
    final dist = offset.length;
    if (dist < 1e-6) {
      return const OrbitalCoordinates(azimuth: 0.0, elevation: 0.0, distance: 0.0);
    }
    final elev = math.asin((offset.y / dist).clamp(-1.0, 1.0));
    final azim = math.atan2(offset.x, offset.z);
    return OrbitalCoordinates(
      azimuth: azim,
      elevation: elev,
      distance: dist,
    );
  }

  OrbitalCoordinates copyWith({
    double? azimuth,
    double? elevation,
    double? distance,
  }) {
    return OrbitalCoordinates(
      azimuth: azimuth ?? this.azimuth,
      elevation: elevation ?? this.elevation,
      distance: distance ?? this.distance,
    );
  }

  @override
  String toString() =>
      'OrbitalCoordinates(azim: ${(azimuth * 180 / math.pi).toStringAsFixed(1)}°, elev: ${(elevation * 180 / math.pi).toStringAsFixed(1)}°, dist: ${distance.toStringAsFixed(2)}m)';
}

/// Result of smooth damping integration containing both updated value and new velocity.
class SmoothDampResult {
  final double value;
  final double velocity;

  const SmoothDampResult(this.value, this.velocity);
}

/// Result of vector smooth damping integration.
class SmoothDampVectorResult {
  final WorldVector3 value;
  final WorldVector3 velocity;

  const SmoothDampVectorResult(this.value, this.velocity);
}

/// Mathematical damping utilities implementing critically damped harmonic springs
/// (`SmoothDamp`) with zero overshoot and smooth acceleration/deceleration.
class CameraDampingMath {
  CameraDampingMath._();

  /// Critically damped harmonic oscillator for scalar values.
  ///
  /// Solves: `x''(t) + 2*omega*x'(t) + omega^2*x(t) = 0`
  /// using a rational polynomial approximation to `exp(-omega * dt)`.
  static SmoothDampResult smoothDamp({
    required double current,
    required double target,
    required double currentVelocity,
    required double smoothTime,
    required double deltaTime,
    double maxSpeed = double.infinity,
  }) {
    if (deltaTime <= 0.0) {
      return SmoothDampResult(current, currentVelocity);
    }

    final safeSmoothTime = math.max(0.0001, smoothTime);
    final omega = 2.0 / safeSmoothTime;
    final x = omega * deltaTime;
    final exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);

    double change = current - target;
    final originalTarget = target;

    // Clamp maximum speed
    final maxChange = maxSpeed * safeSmoothTime;
    change = change.clamp(-maxChange, maxChange);
    final adjustedTarget = current - change;

    final temp = (currentVelocity + omega * change) * deltaTime;
    double newVelocity = (currentVelocity - omega * temp) * exp;
    double output = adjustedTarget + (change + temp) * exp;

    // Prevent overshooting the target
    if ((originalTarget - current > 0.0) == (output > originalTarget)) {
      output = originalTarget;
      newVelocity = (output - originalTarget) / deltaTime;
    }

    return SmoothDampResult(output, newVelocity);
  }

  /// Critically damped harmonic oscillator for angles (in radians),
  /// correctly wrapping the delta to take the shortest angular path across `[-pi, pi]`.
  static SmoothDampResult smoothDampAngle({
    required double current,
    required double target,
    required double currentVelocity,
    required double smoothTime,
    required double deltaTime,
    double maxSpeed = double.infinity,
  }) {
    final wrappedTarget = current + deltaAngle(current, target);
    return smoothDamp(
      current: current,
      target: wrappedTarget,
      currentVelocity: currentVelocity,
      smoothTime: smoothTime,
      deltaTime: deltaTime,
      maxSpeed: maxSpeed,
    );
  }

  /// Computes shortest angular distance between two radian angles in `[-pi, pi]`.
  static double deltaAngle(double current, double target) {
    var delta = (target - current) % (2.0 * math.pi);
    if (delta > math.pi) {
      delta -= 2.0 * math.pi;
    } else if (delta < -math.pi) {
      delta += 2.0 * math.pi;
    }
    return delta;
  }

  /// Critically damped harmonic oscillator for 3D vectors.
  static SmoothDampVectorResult smoothDampVector({
    required WorldVector3 current,
    required WorldVector3 target,
    required WorldVector3 currentVelocity,
    required double smoothTime,
    required double deltaTime,
    double maxSpeed = double.infinity,
  }) {
    final rx = smoothDamp(
      current: current.x,
      target: target.x,
      currentVelocity: currentVelocity.x,
      smoothTime: smoothTime,
      deltaTime: deltaTime,
      maxSpeed: maxSpeed,
    );

    final ry = smoothDamp(
      current: current.y,
      target: target.y,
      currentVelocity: currentVelocity.y,
      smoothTime: smoothTime,
      deltaTime: deltaTime,
      maxSpeed: maxSpeed,
    );

    final rz = smoothDamp(
      current: current.z,
      target: target.z,
      currentVelocity: currentVelocity.z,
      smoothTime: smoothTime,
      deltaTime: deltaTime,
      maxSpeed: maxSpeed,
    );

    return SmoothDampVectorResult(
      WorldVector3(rx.value, ry.value, rz.value),
      WorldVector3(rx.velocity, ry.velocity, rz.velocity),
    );
  }
}

/// Depth of field (DoF) and physical camera optical parameters.
class DepthOfFieldParameters {
  /// Lens aperture f-number (e.g. 1.4, 2.8, 5.6).
  final double aperture;

  /// Focal length of the lens in millimeters (e.g. 35.0, 50.0, 85.0).
  final double focalLengthMm;

  /// Permissible circle of confusion diameter in millimeters on sensor (standard 35mm full-frame = 0.029mm).
  final double permissibleCocMm;

  /// Sensor height in millimeters (standard full-frame = 24.0mm).
  final double sensorHeightMm;

  /// Maximum bokeh blur disc radius in screen pixels (for fragment shader kernels).
  final double maxBokehRadiusPixels;

  const DepthOfFieldParameters({
    this.aperture = 2.8,
    this.focalLengthMm = 50.0,
    this.permissibleCocMm = 0.029,
    this.sensorHeightMm = 24.0,
    this.maxBokehRadiusPixels = 16.0,
  })  : assert(aperture > 0.0, 'Aperture must be positive'),
        assert(focalLengthMm > 0.0, 'Focal length must be positive');

  DepthOfFieldParameters copyWith({
    double? aperture,
    double? focalLengthMm,
    double? permissibleCocMm,
    double? sensorHeightMm,
    double? maxBokehRadiusPixels,
  }) {
    return DepthOfFieldParameters(
      aperture: aperture ?? this.aperture,
      focalLengthMm: focalLengthMm ?? this.focalLengthMm,
      permissibleCocMm: permissibleCocMm ?? this.permissibleCocMm,
      sensorHeightMm: sensorHeightMm ?? this.sensorHeightMm,
      maxBokehRadiusPixels: maxBokehRadiusPixels ?? this.maxBokehRadiusPixels,
    );
  }
}

/// Optical calculations representing the current depth of field state.
class DepthOfFieldState {
  /// Exact distance in world units from camera lens to the focal plane.
  final double focusDistance;

  /// Hyperfocal distance in world meters: beyond this, everything to infinity is acceptably sharp.
  final double hyperfocalDistance;

  /// Near limit of acceptable focus in world units.
  final double nearFocusPlane;

  /// Far limit of acceptable focus in world units (or infinity).
  final double farFocusPlane;

  /// Total depth of field depth range (`farFocusPlane - nearFocusPlane`).
  final double depthOfFieldRange;

  /// Effective normalized blur radius for fragment shader uniforms in [0.0, 1.0].
  final double normalizedBokehIntensity;

  /// Physical circle of confusion diameter at target focus point (nominally 0.0).
  final double focalCocMm;

  const DepthOfFieldState({
    required this.focusDistance,
    required this.hyperfocalDistance,
    required this.nearFocusPlane,
    required this.farFocusPlane,
    required this.depthOfFieldRange,
    required this.normalizedBokehIntensity,
    required this.focalCocMm,
  });

  /// Evaluates circle of confusion (CoC) in millimeters at an arbitrary scene depth [zMeters].
  ///
  /// Physical thin-lens optical formula:
  /// `c = | (f^2 / (N * (s - f))) * ((z - s) / z) |`
  /// where `f` is focal length, `N` is aperture f-number, `s` is focal distance, and `z` is object depth.
  static double computeCircleOfConfusion({
    required double depthMeters,
    required double focusDistanceMeters,
    required double focalLengthMm,
    required double aperture,
  }) {
    if (depthMeters <= 0.0 || focusDistanceMeters <= 0.0) return 0.0;

    final fMeters = focalLengthMm / 1000.0;
    if (focusDistanceMeters <= fMeters) return 0.0;

    final lensApertureDiameter = fMeters / aperture;
    final objectFactor = (depthMeters - focusDistanceMeters).abs() / depthMeters;
    final focalFactor = fMeters / (focusDistanceMeters - fMeters);

    final cocMeters = lensApertureDiameter * focalFactor * objectFactor;
    return cocMeters * 1000.0; // Return in mm
  }

  /// Calculates a normalized blur factor in [0.0, 1.0] for fragment shaders at depth [depthMeters].
  double normalizedBlurAt(
    double depthMeters, {
    required DepthOfFieldParameters params,
  }) {
    final coc = computeCircleOfConfusion(
      depthMeters: depthMeters,
      focusDistanceMeters: focusDistance,
      focalLengthMm: params.focalLengthMm,
      aperture: params.aperture,
    );

    // Normalize against permissible CoC and maximum blur threshold
    final maxExpectedCoc = params.permissibleCocMm * 8.0;
    return (coc / maxExpectedCoc).clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'DepthOfFieldState(focus: ${focusDistance.toStringAsFixed(2)}m, near: ${nearFocusPlane.toStringAsFixed(2)}m, far: ${farFocusPlane.isInfinite ? "inf" : "${farFocusPlane.toStringAsFixed(2)}m"}, range: ${depthOfFieldRange.isInfinite ? "inf" : "${depthOfFieldRange.toStringAsFixed(2)}m"})';
}

/// Camera behavioral presets defining framing, dynamic FOV, and damping times.
enum CinematicCameraMode {
  /// Default world exploration mode: balanced 60° FOV, medium orbital distance.
  idle,

  /// Active locomotion: slightly widened 66° FOV, moderate forward look-ahead.
  running,

  /// High-speed sprinting: dynamic 74° FOV shift, extended look-ahead, speed-feeling pull-back.
  sprinting,

  /// Tactical combat mode: elevated 68° FOV, higher elevation angle, wide battlefield overview.
  combat,

  /// Precision aiming: tight 45° FOV, over-the-right-shoulder camera offset.
  aiming,

  /// Cinematic dialogue / cutscene: shallow 38° FOV, intimate framing with rich bokeh.
  cinematicDialogue,

  /// Expansive landscape vista: wide 82° FOV, pulled back distance, panoramic horizon framing.
  panoramicVista,

  /// User custom mode.
  custom,
}

/// Profile configuration associated with a camera mode.
class CinematicCameraProfile {
  final double fieldOfViewDegrees;
  final double targetDistance;
  final double targetHeightOffset;
  final WorldVector3 lateralShoulderOffset;
  final double defaultElevation;
  final double lookAheadFactor;
  final double positionSmoothTime;
  final double rotationSmoothTime;
  final double fovSmoothTime;
  final DepthOfFieldParameters dofParameters;

  const CinematicCameraProfile({
    required this.fieldOfViewDegrees,
    required this.targetDistance,
    required this.targetHeightOffset,
    required this.lateralShoulderOffset,
    required this.defaultElevation,
    required this.lookAheadFactor,
    required this.positionSmoothTime,
    required this.rotationSmoothTime,
    required this.fovSmoothTime,
    required this.dofParameters,
  });

  static const CinematicCameraProfile idle = CinematicCameraProfile(
    fieldOfViewDegrees: 60.0,
    targetDistance: 5.5,
    targetHeightOffset: 1.6,
    lateralShoulderOffset: WorldVector3.zero,
    defaultElevation: 0.18, // ~10.3°
    lookAheadFactor: 0.25,
    positionSmoothTime: 0.22,
    rotationSmoothTime: 0.18,
    fovSmoothTime: 0.35,
    dofParameters: DepthOfFieldParameters(aperture: 3.5, focalLengthMm: 45.0),
  );

  static const CinematicCameraProfile running = CinematicCameraProfile(
    fieldOfViewDegrees: 66.0,
    targetDistance: 6.2,
    targetHeightOffset: 1.65,
    lateralShoulderOffset: WorldVector3.zero,
    defaultElevation: 0.22, // ~12.6°
    lookAheadFactor: 0.65,
    positionSmoothTime: 0.18,
    rotationSmoothTime: 0.15,
    fovSmoothTime: 0.30,
    dofParameters: DepthOfFieldParameters(aperture: 4.0, focalLengthMm: 40.0),
  );

  static const CinematicCameraProfile sprinting = CinematicCameraProfile(
    fieldOfViewDegrees: 74.0,
    targetDistance: 7.2,
    targetHeightOffset: 1.55,
    lateralShoulderOffset: WorldVector3.zero,
    defaultElevation: 0.20, // ~11.5°
    lookAheadFactor: 1.10,
    positionSmoothTime: 0.15,
    rotationSmoothTime: 0.12,
    fovSmoothTime: 0.25,
    dofParameters: DepthOfFieldParameters(aperture: 4.5, focalLengthMm: 35.0),
  );

  static const CinematicCameraProfile combat = CinematicCameraProfile(
    fieldOfViewDegrees: 68.0,
    targetDistance: 7.8,
    targetHeightOffset: 2.1,
    lateralShoulderOffset: WorldVector3(0.3, 0.0, 0.0),
    defaultElevation: 0.32, // ~18.3°
    lookAheadFactor: 0.40,
    positionSmoothTime: 0.16,
    rotationSmoothTime: 0.14,
    fovSmoothTime: 0.22,
    dofParameters: DepthOfFieldParameters(aperture: 2.8, focalLengthMm: 50.0),
  );

  static const CinematicCameraProfile aiming = CinematicCameraProfile(
    fieldOfViewDegrees: 45.0,
    targetDistance: 2.8,
    targetHeightOffset: 1.5,
    lateralShoulderOffset: WorldVector3(0.75, 0.0, 0.0),
    defaultElevation: 0.12, // ~6.9°
    lookAheadFactor: 0.10,
    positionSmoothTime: 0.12,
    rotationSmoothTime: 0.10,
    fovSmoothTime: 0.18,
    dofParameters: DepthOfFieldParameters(aperture: 2.0, focalLengthMm: 70.0),
  );

  static const CinematicCameraProfile cinematicDialogue = CinematicCameraProfile(
    fieldOfViewDegrees: 38.0,
    targetDistance: 2.2,
    targetHeightOffset: 1.5,
    lateralShoulderOffset: WorldVector3(0.4, 0.0, 0.0),
    defaultElevation: 0.08, // ~4.6°
    lookAheadFactor: 0.0,
    positionSmoothTime: 0.35,
    rotationSmoothTime: 0.30,
    fovSmoothTime: 0.40,
    dofParameters: DepthOfFieldParameters(aperture: 1.4, focalLengthMm: 85.0),
  );

  static const CinematicCameraProfile panoramicVista = CinematicCameraProfile(
    fieldOfViewDegrees: 82.0,
    targetDistance: 14.0,
    targetHeightOffset: 3.5,
    lateralShoulderOffset: WorldVector3.zero,
    defaultElevation: 0.45, // ~25.8°
    lookAheadFactor: 0.20,
    positionSmoothTime: 0.40,
    rotationSmoothTime: 0.35,
    fovSmoothTime: 0.50,
    dofParameters: DepthOfFieldParameters(aperture: 8.0, focalLengthMm: 24.0),
  );

  static CinematicCameraProfile getProfile(CinematicCameraMode mode) {
    switch (mode) {
      case CinematicCameraMode.idle:
        return idle;
      case CinematicCameraMode.running:
        return running;
      case CinematicCameraMode.sprinting:
        return sprinting;
      case CinematicCameraMode.combat:
        return combat;
      case CinematicCameraMode.aiming:
        return aiming;
      case CinematicCameraMode.cinematicDialogue:
        return cinematicDialogue;
      case CinematicCameraMode.panoramicVista:
        return panoramicVista;
      case CinematicCameraMode.custom:
        return idle;
    }
  }
}

/// Instantaneous snapshot of the camera controller's state.
class CinematicCameraState {
  /// Current camera eye position in world space.
  final WorldVector3 eyePosition;

  /// Smoothed look-at pivot point in world space.
  final WorldVector3 lookAtTarget;

  /// Current orbital spherical coordinates.
  final OrbitalCoordinates orbital;

  /// Current field of view in degrees.
  final double fovDegrees;

  /// Current field of view in radians.
  final double fovRadians;

  /// Depth of field optical state.
  final DepthOfFieldState dof;

  /// Active camera behavioral mode.
  final CinematicCameraMode mode;

  /// 4x4 View Transformation Matrix (`lookAt`).
  final Matrix4 viewMatrix;

  /// Forward unit vector pointing where camera is facing.
  final WorldVector3 forward;

  /// Up unit vector.
  final WorldVector3 up;

  /// Right unit vector.
  final WorldVector3 right;

  const CinematicCameraState({
    required this.eyePosition,
    required this.lookAtTarget,
    required this.orbital,
    required this.fovDegrees,
    required this.fovRadians,
    required this.dof,
    required this.mode,
    required this.viewMatrix,
    required this.forward,
    required this.up,
    required this.right,
  });

  /// Computes a standard 4x4 perspective projection matrix.
  Matrix4 computeProjectionMatrix({
    required double aspectRatio,
    double near = 0.1,
    double far = 1000.0,
  }) {
    final tanHalfFov = math.tan(fovRadians / 2.0);
    final proj = Matrix4.zero();
    proj.setEntry(0, 0, 1.0 / (aspectRatio * tanHalfFov));
    proj.setEntry(1, 1, 1.0 / tanHalfFov);
    proj.setEntry(2, 2, -(far + near) / (far - near));
    proj.setEntry(2, 3, -(2.0 * far * near) / (far - near));
    proj.setEntry(3, 2, -1.0);
    proj.setEntry(3, 3, 0.0);
    return proj;
  }

  /// Computes combined View-Projection matrix for rendering shaders.
  Matrix4 computeViewProjectionMatrix({
    required double aspectRatio,
    double near = 0.1,
    double far = 1000.0,
  }) {
    final proj = computeProjectionMatrix(aspectRatio: aspectRatio, near: near, far: far);
    return proj * viewMatrix;
  }
}

/// Production-ready 3D Cinematic Camera Controller.
///
/// Features:
/// - Smooth orbital panning (azimuth, elevation, distance) with pitch limits and wrapping.
/// - Target tracking with critically damped harmonic spring smoothing (`SmoothDamp`).
/// - Dynamic FOV transitions across gameplay modes (sprinting, combat, aiming, dialogue, vistas).
/// - Velocity-based look-ahead anticipating player movement for open world vistas.
/// - Physically accurate Depth of Field (DoF) focus distance and bokeh calculator.
/// - 4x4 View and Projection Matrix generation for Flutter shaders and Canvas 3D.
/// - Obstacle collision distance clamping.
class CinematicCameraController extends ChangeNotifier {
  // Current mode and profile
  CinematicCameraMode _mode = CinematicCameraMode.idle;
  CinematicCameraProfile _profile = CinematicCameraProfile.idle;

  // Tracked player / target state
  WorldVector3 _targetPosition = WorldVector3.zero;
  WorldVector3 _targetVelocity = WorldVector3.zero;
  WorldVector3 _targetOffset = const WorldVector3(0.0, 1.6, 0.0);

  // Look-ahead tracking state
  WorldVector3 _currentLookAhead = WorldVector3.zero;
  WorldVector3 _lookAheadVelocity = WorldVector3.zero;

  // Smoothed camera target pivot state
  WorldVector3 _currentLookAtTarget = const WorldVector3(0.0, 1.6, 0.0);
  WorldVector3 _lookAtVelocity = WorldVector3.zero;

  // Orbital angles & distance
  double _currentAzimuth = 0.0;
  double _targetAzimuth = 0.0;
  double _azimuthVelocity = 0.0;

  double _currentElevation = 0.18;
  double _targetElevation = 0.18;
  double _elevationVelocity = 0.0;

  double _currentDistance = 5.5;
  double _targetDistance = 5.5;
  double _distanceVelocity = 0.0;

  // Lateral shoulder offset state
  WorldVector3 _currentShoulderOffset = WorldVector3.zero;
  WorldVector3 _shoulderOffsetVelocity = WorldVector3.zero;

  // Dynamic FOV state
  double _currentFov = 60.0;
  double _targetFov = 60.0;
  double _fovVelocity = 0.0;

  // Bounds and sensitivities
  double minElevation = -1.35; // ~-77°
  double maxElevation = 1.45; // ~+83°
  double minDistance = 1.0;
  double maxDistance = 30.0;
  double orbitSensitivity = 0.005;
  double zoomSensitivity = 0.01;

  // Angular and zoom momentum state (AAA touch fling inertia & friction)
  double _momentumAzimuth = 0.0;
  double _momentumElevation = 0.0;
  double _momentumDistance = 0.0;
  double momentumDecayRate = 4.2; // 1/s exponential friction decay
  double maxAngularMomentum = 12.0; // rad/s clamp

  // Collision clamping override
  double? _collisionMaxDistance;

  // Depth of field parameters
  DepthOfFieldParameters _dofParams = const DepthOfFieldParameters();

  // Cached state
  late CinematicCameraState _currentState;

  CinematicCameraController({
    CinematicCameraMode initialMode = CinematicCameraMode.idle,
    WorldVector3 initialTarget = WorldVector3.zero,
    double initialAzimuth = 0.0,
    double initialElevation = 0.18,
    double initialDistance = 5.5,
  }) {
    _mode = initialMode;
    _profile = CinematicCameraProfile.getProfile(initialMode);
    _targetPosition = initialTarget;
    _currentAzimuth = initialAzimuth;
    _targetAzimuth = initialAzimuth;
    _currentElevation = initialElevation;
    _targetElevation = initialElevation;
    _currentDistance = initialDistance;
    _targetDistance = initialDistance;
    _currentFov = _profile.fieldOfViewDegrees;
    _targetFov = _profile.fieldOfViewDegrees;
    _dofParams = _profile.dofParameters;
    _targetOffset = WorldVector3(0.0, _profile.targetHeightOffset, 0.0);
    _currentLookAtTarget = _targetPosition + _targetOffset;

    _recomputeState();
  }

  CinematicCameraState get state => _currentState;
  CinematicCameraMode get mode => _mode;
  CinematicCameraProfile get profile => _profile;
  WorldVector3 get targetPosition => _targetPosition;
  WorldVector3 get targetVelocity => _targetVelocity;
  DepthOfFieldParameters get dofParameters => _dofParams;

  /// Sets the camera behavioral mode with smooth animated transitions.
  void setMode(CinematicCameraMode newMode, {bool snap = false}) {
    _mode = newMode;
    _profile = CinematicCameraProfile.getProfile(newMode);
    _targetFov = _profile.fieldOfViewDegrees;
    _targetDistance = _profile.targetDistance;
    _targetElevation = _profile.defaultElevation;
    _targetOffset = WorldVector3(0.0, _profile.targetHeightOffset, 0.0);
    _dofParams = _profile.dofParameters;

    if (snap) {
      _currentFov = _targetFov;
      _currentDistance = _targetDistance;
      _currentElevation = _targetElevation;
      _currentShoulderOffset = _profile.lateralShoulderOffset;
    }

    notifyListeners();
  }

  /// Sets tracked target position and optional velocity.
  void setTarget({
    required WorldVector3 position,
    WorldVector3? velocity,
  }) {
    _targetPosition = position;
    if (velocity != null) {
      _targetVelocity = velocity;
    }
  }

  /// Rotates the camera orbitally by delta azimuth (yaw) and delta elevation (pitch).
  void orbit(double deltaAzimuth, double deltaElevation) {
    _targetAzimuth += deltaAzimuth;
    _targetElevation = (_targetElevation + deltaElevation).clamp(minElevation, maxElevation);
  }

  /// Imparts physical angular fling momentum (rad/s) from touch gestures.
  /// Decelerates smoothly via exponential friction decay in [update].
  void fling(double velocityAzimuth, double velocityElevation) {
    _momentumAzimuth = velocityAzimuth.clamp(-maxAngularMomentum, maxAngularMomentum);
    _momentumElevation = velocityElevation.clamp(-maxAngularMomentum, maxAngularMomentum);
  }

  /// Imparts physical zoom fling momentum (distance units/s) from pinch release.
  void flingZoom(double velocityDistance) {
    _momentumDistance = velocityDistance.clamp(-20.0, 20.0);
  }

  /// Adjusts camera zoom distance with optional dynamic FOV interpolation.
  /// Modulates FOV: tighter focal perspective on hero close-ups,
  /// wider panoramic FOV on distant vistas.
  void zoom(double deltaDistance, {bool dynamicFov = true}) {
    _targetDistance = (_targetDistance + deltaDistance).clamp(minDistance, maxDistance);
    if (dynamicFov) {
      _updateDynamicFovForDistance(_targetDistance);
    }
  }

  /// Calculates dynamic FOV target from camera distance using an S-curve blend.
  void _updateDynamicFovForDistance(double dist) {
    final t = ((dist - minDistance) / (maxDistance - minDistance)).clamp(0.0, 1.0);
    final smoothT = 0.5 - 0.5 * math.cos(t * math.pi);
    final baseFov = _profile.fieldOfViewDegrees;
    _targetFov = (baseFov * 0.85) + smoothT * (baseFov * 0.30);
  }

  /// Smoothly re-centers the camera on the target/character or specific landmark.
  /// Uses critically damped harmonic motion (zero overshoot) to return to default framing.
  void recenter({
    WorldVector3? focalPoint,
    double? azimuth,
    double? elevation,
    double? distance,
    double? fov,
    bool snap = false,
  }) {
    _targetAzimuth = azimuth ?? 0.0;
    _targetElevation = elevation ?? _profile.defaultElevation;
    _targetDistance = distance ?? _profile.targetDistance;
    _targetFov = fov ?? _profile.fieldOfViewDegrees;
    if (focalPoint != null) {
      _targetPosition = focalPoint;
    }

    _momentumAzimuth = 0.0;
    _momentumElevation = 0.0;
    _momentumDistance = 0.0;

    if (snap) {
      snapToTarget();
    } else {
      notifyListeners();
    }
  }

  /// Convenience method to smoothly re-center on the Sanctum Citadel courtyard.
  void recenterOnCitadel({
    WorldVector3 citadelPosition = const WorldVector3(0.0, 0.05, 7.4),
    bool snap = false,
  }) {
    recenter(focalPoint: citadelPosition, snap: snap);
  }

  /// Applies collision detection constraint from physics raycast.
  void setCollisionDistanceConstraint(double? maxAllowedDistance) {
    _collisionMaxDistance = maxAllowedDistance;
  }

  /// Overrides optical Depth of Field parameters (e.g. for photo mode or dialogue).
  void setDepthOfFieldParameters(DepthOfFieldParameters params) {
    _dofParams = params;
    _recomputeState();
    notifyListeners();
  }

  /// Instantly snaps the camera to target without damping.
  void snapToTarget() {
    _momentumAzimuth = 0.0;
    _momentumElevation = 0.0;
    _momentumDistance = 0.0;
    _currentAzimuth = _targetAzimuth;
    _azimuthVelocity = 0.0;
    _currentElevation = _targetElevation;
    _elevationVelocity = 0.0;
    _currentDistance = _targetDistance;
    _distanceVelocity = 0.0;
    _currentFov = _targetFov;
    _fovVelocity = 0.0;
    _currentLookAhead = _targetVelocity * _profile.lookAheadFactor;
    _lookAheadVelocity = WorldVector3.zero;
    _currentShoulderOffset = _profile.lateralShoulderOffset;
    _shoulderOffsetVelocity = WorldVector3.zero;
    _currentLookAtTarget = _targetPosition + _targetOffset + _currentLookAhead;
    _lookAtVelocity = WorldVector3.zero;

    _recomputeState();
    notifyListeners();
  }

  /// Advances the cinematic camera simulation forward by [dt] seconds.
  void update(double dt) {
    if (dt <= 0.0) return;

    // 0. Process momentum friction & damping inertia
    if (_momentumAzimuth.abs() > 1e-5 || _momentumElevation.abs() > 1e-5) {
      final decay = math.exp(-momentumDecayRate * dt);
      _targetAzimuth += _momentumAzimuth * dt;
      _targetElevation += _momentumElevation * dt;
      _momentumAzimuth *= decay;
      _momentumElevation *= decay;

      // Elastic boundary resistance (yaylanma)
      if (_targetElevation < minElevation) {
        final diff = minElevation - _targetElevation;
        _targetElevation = minElevation - diff * 0.15;
        _momentumElevation = 0.0;
      } else if (_targetElevation > maxElevation) {
        final diff = _targetElevation - maxElevation;
        _targetElevation = maxElevation + diff * 0.15;
        _momentumElevation = 0.0;
      }
    }

    if (_momentumDistance.abs() > 1e-5) {
      final decay = math.exp(-momentumDecayRate * dt);
      _targetDistance = (_targetDistance + _momentumDistance * dt).clamp(minDistance, maxDistance);
      _momentumDistance *= decay;
      _updateDynamicFovForDistance(_targetDistance);
    }

    // 1. Smooth look-ahead vector based on velocity
    final desiredLookAhead = _targetVelocity * _profile.lookAheadFactor;
    final lookAheadResult = CameraDampingMath.smoothDampVector(
      current: _currentLookAhead,
      target: desiredLookAhead,
      currentVelocity: _lookAheadVelocity,
      smoothTime: _profile.positionSmoothTime * 1.5,
      deltaTime: dt,
    );
    _currentLookAhead = lookAheadResult.value;
    _lookAheadVelocity = lookAheadResult.velocity;

    // 2. Smooth focal target position
    final desiredPivot = _targetPosition + _targetOffset + _currentLookAhead;
    final pivotResult = CameraDampingMath.smoothDampVector(
      current: _currentLookAtTarget,
      target: desiredPivot,
      currentVelocity: _lookAtVelocity,
      smoothTime: _profile.positionSmoothTime,
      deltaTime: dt,
    );
    _currentLookAtTarget = pivotResult.value;
    _lookAtVelocity = pivotResult.velocity;

    // 3. Smooth orbital angles with shortest path wrapping
    final azimResult = CameraDampingMath.smoothDampAngle(
      current: _currentAzimuth,
      target: _targetAzimuth,
      currentVelocity: _azimuthVelocity,
      smoothTime: _profile.rotationSmoothTime,
      deltaTime: dt,
    );
    _currentAzimuth = azimResult.value;
    _azimuthVelocity = azimResult.velocity;

    final elevResult = CameraDampingMath.smoothDamp(
      current: _currentElevation,
      target: _targetElevation,
      currentVelocity: _elevationVelocity,
      smoothTime: _profile.rotationSmoothTime,
      deltaTime: dt,
    );
    _currentElevation = elevResult.value.clamp(minElevation, maxElevation);
    _elevationVelocity = elevResult.velocity;

    // 4. Smooth distance with optional collision constraint
    double effectiveTargetDistance = _targetDistance;
    if (_collisionMaxDistance != null) {
      effectiveTargetDistance = math.min(effectiveTargetDistance, _collisionMaxDistance!);
    }
    effectiveTargetDistance = effectiveTargetDistance.clamp(minDistance, maxDistance);

    final distResult = CameraDampingMath.smoothDamp(
      current: _currentDistance,
      target: effectiveTargetDistance,
      currentVelocity: _distanceVelocity,
      smoothTime: _profile.positionSmoothTime,
      deltaTime: dt,
    );
    _currentDistance = distResult.value.clamp(minDistance, maxDistance);
    _distanceVelocity = distResult.velocity;

    // 5. Smooth shoulder offset
    final shoulderResult = CameraDampingMath.smoothDampVector(
      current: _currentShoulderOffset,
      target: _profile.lateralShoulderOffset,
      currentVelocity: _shoulderOffsetVelocity,
      smoothTime: _profile.positionSmoothTime,
      deltaTime: dt,
    );
    _currentShoulderOffset = shoulderResult.value;
    _shoulderOffsetVelocity = shoulderResult.velocity;

    // 6. Smooth dynamic FOV shift
    final fovResult = CameraDampingMath.smoothDamp(
      current: _currentFov,
      target: _targetFov,
      currentVelocity: _fovVelocity,
      smoothTime: _profile.fovSmoothTime,
      deltaTime: dt,
    );
    _currentFov = fovResult.value;
    _fovVelocity = fovResult.velocity;

    // 7. Update state and notify
    _recomputeState();
    notifyListeners();
  }

  /// Calculates depth of field, vectors, view matrix and updates `_currentState`.
  void _recomputeState() {
    final orbital = OrbitalCoordinates(
      azimuth: _currentAzimuth,
      elevation: _currentElevation,
      distance: _currentDistance,
    );

    // Calculate base eye position from spherical coordinates
    final baseOffset = orbital.toCartesianOffset();

    // Compute camera coordinate frame
    final lookAt = _currentLookAtTarget;
    var eye = lookAt + baseOffset;

    // Compute forward vector
    var forward = (lookAt - eye).normalized();
    if (forward.lengthSquared < 1e-6) {
      forward = WorldVector3.forward;
    }

    // Right vector: forward x worldUp
    var right = forward.cross(WorldVector3.up).normalized();
    if (right.lengthSquared < 1e-6) {
      right = WorldVector3.right;
    }

    // Up vector: right x forward
    final up = right.cross(forward).normalized();

    // Apply lateral shoulder offset in camera local coordinate space
    if (_currentShoulderOffset.lengthSquared > 1e-6) {
      final lateral = right * _currentShoulderOffset.x +
          up * _currentShoulderOffset.y +
          forward * _currentShoulderOffset.z;
      eye = eye + lateral;
    }

    // Compute 4x4 View Matrix (lookAt)
    final viewMatrix = Matrix4.zero();
    viewMatrix.setEntry(0, 0, right.x);
    viewMatrix.setEntry(0, 1, right.y);
    viewMatrix.setEntry(0, 2, right.z);
    viewMatrix.setEntry(0, 3, -right.dot(eye));

    viewMatrix.setEntry(1, 0, up.x);
    viewMatrix.setEntry(1, 1, up.y);
    viewMatrix.setEntry(1, 2, up.z);
    viewMatrix.setEntry(1, 3, -up.dot(eye));

    viewMatrix.setEntry(2, 0, -forward.x);
    viewMatrix.setEntry(2, 1, -forward.y);
    viewMatrix.setEntry(2, 2, -forward.z);
    viewMatrix.setEntry(2, 3, forward.dot(eye));

    viewMatrix.setEntry(3, 0, 0.0);
    viewMatrix.setEntry(3, 1, 0.0);
    viewMatrix.setEntry(3, 2, 0.0);
    viewMatrix.setEntry(3, 3, 1.0);

    // Compute Depth of Field metrics
    final focusDist = eye.distanceTo(_targetPosition + _targetOffset);
    final fMeters = _dofParams.focalLengthMm / 1000.0;
    final cMeters = _dofParams.permissibleCocMm / 1000.0;
    final hyperfocal = (fMeters * fMeters) / (_dofParams.aperture * cMeters) + fMeters;

    double nearPlane = 0.0;
    double farPlane = double.infinity;
    if (focusDist > 0.0) {
      final denomNear = hyperfocal + (focusDist - fMeters);
      nearPlane = denomNear > 0.0 ? (hyperfocal * focusDist) / denomNear : 0.0;

      final denomFar = hyperfocal - (focusDist - fMeters);
      if (denomFar > 0.0) {
        farPlane = (hyperfocal * focusDist) / denomFar;
      } else {
        farPlane = double.infinity;
      }
    }
    final dofRange = farPlane.isInfinite ? double.infinity : (farPlane - nearPlane);

    final dofState = DepthOfFieldState(
      focusDistance: focusDist,
      hyperfocalDistance: hyperfocal,
      nearFocusPlane: nearPlane,
      farFocusPlane: farPlane,
      depthOfFieldRange: dofRange,
      normalizedBokehIntensity: (1.4 / _dofParams.aperture).clamp(0.0, 1.0),
      focalCocMm: 0.0,
    );

    final fovRads = _currentFov * math.pi / 180.0;

    _currentState = CinematicCameraState(
      eyePosition: eye,
      lookAtTarget: lookAt,
      orbital: orbital,
      fovDegrees: _currentFov,
      fovRadians: fovRads,
      dof: dofState,
      mode: _mode,
      viewMatrix: viewMatrix,
      forward: forward,
      up: up,
      right: right,
    );
  }
}
