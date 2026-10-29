import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Non-linear decay curves for trauma decay over time.
enum CameraShakeDecayMode {
  /// Quadratic decay: decay rate accelerates at higher trauma, ensuring a sharp initial drop
  /// followed by a controlled settle.
  quadratic,

  /// Exponential decay: trauma decays proportionally to current trauma level.
  exponential,

  /// Smooth-step decay: smooth Hermite interpolation between 1.0 and 0.0.
  smoothStep,

  /// Linear decay: constant trauma decrease per second.
  linear,
}

/// Configuration settings for directional micro-camera shake dynamics.
class CameraShakeConfig {
  /// Exponent applied to trauma to compute shake intensity (shake = trauma^exponent).
  /// Typically 2.0 or 3.0. Higher values make small hits subtle and heavy hits visceral.
  final double traumaExponent;

  /// Speed at which trauma decays per second.
  final double decayRate;

  /// Non-linear decay mode used to step trauma down.
  final CameraShakeDecayMode decayMode;

  /// Maximum translational displacement in screen pixels (x, y).
  final Offset maxTranslation;

  /// Maximum rotational roll angle in radians (around camera Z axis).
  final double maxRoll;

  /// Maximum rotational pitch angle in radians (around camera X axis).
  final double maxPitch;

  /// Maximum rotational yaw angle in radians (around camera Y axis).
  final double maxYaw;

  /// Base noise frequency in Hertz (cycles per second).
  final double baseFrequency;

  /// Frequency modulation factor: increases noise frequency with trauma (Hz / trauma).
  final double frequencyModulation;

  /// Number of octaves for fractal multi-octave noise.
  final int noiseOctaves;

  /// Lacunarity for multi-octave noise (frequency multiplier per octave).
  final double noiseLacunarity;

  /// Persistence for multi-octave noise (amplitude multiplier per octave).
  final double noisePersistence;

  /// Influence weight of hit direction on initial displacement (0.0 = pure isotropic, 1.0 = strictly directional).
  final double directionalBiasWeight;

  /// Damping factor for harmonic directional recoil impulse.
  final double harmonicDamping;

  /// Natural frequency of directional recoil oscillation in radians/sec.
  final double harmonicFrequency;

  /// Epsilon below which trauma snaps to 0.0.
  final double traumaCutoff;

  const CameraShakeConfig({
    this.traumaExponent = 2.0,
    this.decayRate = 1.8,
    this.decayMode = CameraShakeDecayMode.quadratic,
    this.maxTranslation = const Offset(20.0, 14.0),
    this.maxRoll = 0.065,
    this.maxPitch = 0.025,
    this.maxYaw = 0.025,
    this.baseFrequency = 24.0,
    this.frequencyModulation = 12.0,
    this.noiseOctaves = 3,
    this.noiseLacunarity = 2.0,
    this.noisePersistence = 0.5,
    this.directionalBiasWeight = 0.8,
    this.harmonicDamping = 8.0,
    this.harmonicFrequency = 22.0,
    this.traumaCutoff = 1e-4,
  }) : assert(traumaExponent >= 1.0, 'traumaExponent must be >= 1.0'),
       assert(decayRate > 0.0, 'decayRate must be > 0.0'),
       assert(noiseOctaves >= 1, 'noiseOctaves must be >= 1');

  /// Creates a copy of this config with modified fields.
  CameraShakeConfig copyWith({
    double? traumaExponent,
    double? decayRate,
    CameraShakeDecayMode? decayMode,
    Offset? maxTranslation,
    double? maxRoll,
    double? maxPitch,
    double? maxYaw,
    double? baseFrequency,
    double? frequencyModulation,
    int? noiseOctaves,
    double? noiseLacunarity,
    double? noisePersistence,
    double? directionalBiasWeight,
    double? harmonicDamping,
    double? harmonicFrequency,
    double? traumaCutoff,
  }) {
    return CameraShakeConfig(
      traumaExponent: traumaExponent ?? this.traumaExponent,
      decayRate: decayRate ?? this.decayRate,
      decayMode: decayMode ?? this.decayMode,
      maxTranslation: maxTranslation ?? this.maxTranslation,
      maxRoll: maxRoll ?? this.maxRoll,
      maxPitch: maxPitch ?? this.maxPitch,
      maxYaw: maxYaw ?? this.maxYaw,
      baseFrequency: baseFrequency ?? this.baseFrequency,
      frequencyModulation: frequencyModulation ?? this.frequencyModulation,
      noiseOctaves: noiseOctaves ?? this.noiseOctaves,
      noiseLacunarity: noiseLacunarity ?? this.noiseLacunarity,
      noisePersistence: noisePersistence ?? this.noisePersistence,
      directionalBiasWeight: directionalBiasWeight ?? this.directionalBiasWeight,
      harmonicDamping: harmonicDamping ?? this.harmonicDamping,
      harmonicFrequency: harmonicFrequency ?? this.harmonicFrequency,
      traumaCutoff: traumaCutoff ?? this.traumaCutoff,
    );
  }
}

/// Combat camera shake presets fine-tuned for game feel (R3).
class CameraShakePreset {
  final String name;
  final double trauma;
  final CameraShakeConfig config;

  const CameraShakePreset({
    required this.name,
    required this.trauma,
    required this.config,
  });

  /// Light jab: Quick, crisp micro-shake for light attacks and quick daggers.
  static const CameraShakePreset lightJab = CameraShakePreset(
    name: 'lightJab',
    trauma: 0.30,
    config: CameraShakeConfig(
      traumaExponent: 2.0,
      decayRate: 4.0,
      decayMode: CameraShakeDecayMode.quadratic,
      maxTranslation: Offset(6.0, 4.0),
      maxRoll: 0.018,
      maxPitch: 0.008,
      maxYaw: 0.008,
      baseFrequency: 32.0,
      frequencyModulation: 8.0,
      noiseOctaves: 2,
      directionalBiasWeight: 0.55,
      harmonicDamping: 12.0,
      harmonicFrequency: 30.0,
    ),
  );

  /// Heavy crit: Visceral, bone-crunching impact with deep directional kick and rumble.
  static const CameraShakePreset heavyCrit = CameraShakePreset(
    name: 'heavyCrit',
    trauma: 0.78,
    config: CameraShakeConfig(
      traumaExponent: 2.0,
      decayRate: 1.8,
      decayMode: CameraShakeDecayMode.quadratic,
      maxTranslation: Offset(26.0, 18.0),
      maxRoll: 0.075,
      maxPitch: 0.035,
      maxYaw: 0.030,
      baseFrequency: 22.0,
      frequencyModulation: 14.0,
      noiseOctaves: 3,
      directionalBiasWeight: 0.85,
      harmonicDamping: 7.0,
      harmonicFrequency: 20.0,
    ),
  );

  /// Explosive shock: Cataclysmic detonation, omnidirectional shockwave followed by heavy rumble.
  static const CameraShakePreset explosiveShock = CameraShakePreset(
    name: 'explosiveShock',
    trauma: 1.0,
    config: CameraShakeConfig(
      traumaExponent: 2.0,
      decayRate: 1.2,
      decayMode: CameraShakeDecayMode.quadratic,
      maxTranslation: Offset(44.0, 32.0),
      maxRoll: 0.125,
      maxPitch: 0.055,
      maxYaw: 0.050,
      baseFrequency: 16.0,
      frequencyModulation: 18.0,
      noiseOctaves: 4,
      directionalBiasWeight: 0.92,
      harmonicDamping: 5.0,
      harmonicFrequency: 15.0,
    ),
  );

  /// Micro vibration: High-frequency sword clash, parry, or shield deflection.
  static const CameraShakePreset microVibration = CameraShakePreset(
    name: 'microVibration',
    trauma: 0.42,
    config: CameraShakeConfig(
      traumaExponent: 2.5,
      decayRate: 5.0,
      decayMode: CameraShakeDecayMode.exponential,
      maxTranslation: Offset(4.5, 3.5),
      maxRoll: 0.012,
      maxPitch: 0.006,
      maxYaw: 0.006,
      baseFrequency: 48.0,
      frequencyModulation: 10.0,
      noiseOctaves: 3,
      directionalBiasWeight: 0.40,
      harmonicDamping: 16.0,
      harmonicFrequency: 45.0,
    ),
  );
}

/// Instantaneous snapshot of the camera shake transformation.
class CameraShakeState {
  /// Translational displacement in screen coordinates (dx, dy).
  final Offset translation;

  /// Rotational roll around the camera Z axis in radians.
  final double roll;

  /// Rotational pitch around the camera X axis in radians.
  final double pitch;

  /// Rotational yaw around the camera Y axis in radians.
  final double yaw;

  /// Normalized camera trauma level in [0.0, 1.0].
  final double trauma;

  /// Effective shake intensity after applying non-linear trauma exponent (trauma^exponent).
  final double shakeIntensity;

  /// Accumulated time in seconds since shake started.
  final double elapsedTime;

  const CameraShakeState({
    required this.translation,
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.trauma,
    required this.shakeIntensity,
    required this.elapsedTime,
  });

  /// Neutral, zero-displacement state.
  static const CameraShakeState neutral = CameraShakeState(
    translation: Offset.zero,
    roll: 0.0,
    pitch: 0.0,
    yaw: 0.0,
    trauma: 0.0,
    shakeIntensity: 0.0,
    elapsedTime: 0.0,
  );

  /// Converts this state into a 4x4 Transformation Matrix suitable for Flutter Transforms or Canvas.
  Matrix4 toMatrix4() {
    if (shakeIntensity <= 0.0 && translation == Offset.zero && roll == 0.0 && pitch == 0.0 && yaw == 0.0) {
      return Matrix4.identity();
    }
    final matrix = Matrix4.identity();
    if (translation.dx != 0.0 || translation.dy != 0.0) {
      matrix.translate(translation.dx, translation.dy, 0.0);
    }
    if (roll != 0.0) {
      matrix.rotateZ(roll);
    }
    if (pitch != 0.0) {
      matrix.rotateX(pitch);
    }
    if (yaw != 0.0) {
      matrix.rotateY(yaw);
    }
    return matrix;
  }

  /// Converts this state into a 4x4 Transformation Matrix rotated and scaled around a given screen pivot point.
  Matrix4 toMatrix4WithPivot(Offset pivot) {
    if (shakeIntensity <= 0.0 && translation == Offset.zero && roll == 0.0 && pitch == 0.0 && yaw == 0.0) {
      return Matrix4.identity();
    }
    final matrix = Matrix4.identity();
    matrix.translate(pivot.dx + translation.dx, pivot.dy + translation.dy, 0.0);
    if (roll != 0.0) matrix.rotateZ(roll);
    if (pitch != 0.0) matrix.rotateX(pitch);
    if (yaw != 0.0) matrix.rotateY(yaw);
    matrix.translate(-pivot.dx, -pivot.dy, 0.0);
    return matrix;
  }

  @override
  String toString() =>
      'CameraShakeState(translation: $translation, roll: ${roll.toStringAsFixed(4)}, trauma: ${trauma.toStringAsFixed(3)}, intensity: ${shakeIntensity.toStringAsFixed(3)})';
}

/// Production-ready 1D Perlin Gradient Noise generator.
/// Continuous, smooth, and seedable without external dependencies.
class PerlinNoise1D {
  final List<int> _perm = List<int>.filled(512, 0);

  PerlinNoise1D([int seed = 1337]) {
    _initPermutation(seed);
  }

  void _initPermutation(int seed) {
    final rand = math.Random(seed);
    final p = List<int>.generate(256, (i) => i);
    // Fisher-Yates shuffle
    for (int i = 255; i > 0; i--) {
      final swapIdx = rand.nextInt(i + 1);
      final temp = p[i];
      p[i] = p[swapIdx];
      p[swapIdx] = temp;
    }
    for (int i = 0; i < 256; i++) {
      _perm[i] = p[i];
      _perm[256 + i] = p[i];
    }
  }

  /// Ken Perlin's quintic fade curve: 6t^5 - 15t^4 + 10t^3.
  /// Eliminates 1st and 2nd derivative discontinuities.
  static double _fade(double t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  }

  /// 1D gradient hash function.
  static double _grad(int hash, double x) {
    // Uses lowest bit to pick gradient direction (+1 or -1)
    return (hash & 1) == 0 ? x : -x;
  }

  /// Evaluates 1D Perlin noise at time coordinate [t].
  /// Output is continuously bounded in [-1.0, 1.0].
  double sample(double t) {
    final floorVal = t.floor();
    final x0 = floorVal & 255;
    final x1 = (x0 + 1) & 255;

    final dx = t - floorVal;
    final u = _fade(dx);

    final g0 = _grad(_perm[x0], dx);
    final g1 = _grad(_perm[x1], dx - 1.0);

    // Linear interpolation of gradient contributions
    return g0 + u * (g1 - g0);
  }
}

/// Multi-octave Fractal Brownian Motion (fBM) noise generator.
class MultiOctaveNoise1D {
  final List<PerlinNoise1D> _octaves;
  final double lacunarity;
  final double persistence;

  MultiOctaveNoise1D({
    int octaveCount = 3,
    this.lacunarity = 2.0,
    this.persistence = 0.5,
    int baseSeed = 42,
  }) : _octaves = List<PerlinNoise1D>.generate(
          math.max(1, octaveCount),
          (i) => PerlinNoise1D(baseSeed + i * 1013),
        );

  /// Samples multi-octave noise at coordinate [t].
  /// Normalized to [-1.0, 1.0].
  double sample(double t) {
    double total = 0.0;
    double frequency = 1.0;
    double amplitude = 1.0;
    double maxAmplitude = 0.0;

    for (int i = 0; i < _octaves.length; i++) {
      total += _octaves[i].sample(t * frequency) * amplitude;
      maxAmplitude += amplitude;
      frequency *= lacunarity;
      amplitude *= persistence;
    }

    if (maxAmplitude == 0.0) return 0.0;
    return total / maxAmplitude;
  }
}

/// Directional Micro-Camera Shake controller for high-impact combat feedback.
///
/// Implements:
/// - Trauma-based shake algorithm: `Shake = Trauma^traumaExponent` (default 2.0 or 3.0)
/// - Non-linear decay curves converging cleanly to zero
/// - Directional hit bias with damped harmonic oscillation
/// - Multi-octave continuous Perlin rumble
/// - Presets for light jabs, heavy crits, and explosive shocks
/// - 4x4 Matrix output for 2D/3D camera transformations
class DirectionalCameraShake extends ChangeNotifier {
  CameraShakeConfig _config;

  double _trauma = 0.0;
  double _elapsedTime = 0.0;

  // Directional impulse state
  Offset _normalizedHitDirection = Offset.zero;
  double _directionalImpulse = 0.0;
  double _directionalOscillationTime = 0.0;

  // Independent multi-octave noise generators for 5 degrees of freedom
  late MultiOctaveNoise1D _noiseX;
  late MultiOctaveNoise1D _noiseY;
  late MultiOctaveNoise1D _noiseRoll;
  late MultiOctaveNoise1D _noisePitch;
  late MultiOctaveNoise1D _noiseYaw;

  CameraShakeState _currentState = CameraShakeState.neutral;

  DirectionalCameraShake({
    CameraShakeConfig config = const CameraShakeConfig(),
    int baseSeed = 2027,
  }) : _config = config {
    _initNoise(baseSeed);
  }

  void _initNoise(int baseSeed) {
    _noiseX = MultiOctaveNoise1D(
      octaveCount: _config.noiseOctaves,
      lacunarity: _config.noiseLacunarity,
      persistence: _config.noisePersistence,
      baseSeed: baseSeed,
    );
    _noiseY = MultiOctaveNoise1D(
      octaveCount: _config.noiseOctaves,
      lacunarity: _config.noiseLacunarity,
      persistence: _config.noisePersistence,
      baseSeed: baseSeed + 347,
    );
    _noiseRoll = MultiOctaveNoise1D(
      octaveCount: _config.noiseOctaves,
      lacunarity: _config.noiseLacunarity,
      persistence: _config.noisePersistence,
      baseSeed: baseSeed + 719,
    );
    _noisePitch = MultiOctaveNoise1D(
      octaveCount: _config.noiseOctaves,
      lacunarity: _config.noiseLacunarity,
      persistence: _config.noisePersistence,
      baseSeed: baseSeed + 1223,
    );
    _noiseYaw = MultiOctaveNoise1D(
      octaveCount: _config.noiseOctaves,
      lacunarity: _config.noiseLacunarity,
      persistence: _config.noisePersistence,
      baseSeed: baseSeed + 1877,
    );
  }

  /// Current active configuration.
  CameraShakeConfig get config => _config;

  /// Updates the active configuration.
  set config(CameraShakeConfig newConfig) {
    _config = newConfig;
    _initNoise(2027);
    notifyListeners();
  }

  /// Current normalized trauma level in [0.0, 1.0].
  double get trauma => _trauma;

  /// Effective shake intensity (trauma^exponent).
  double get shakeIntensity => math.pow(_trauma, _config.traumaExponent).toDouble();

  /// Whether camera shake is currently active.
  bool get isActive => _trauma > _config.traumaCutoff;

  /// Latest calculated camera shake state.
  CameraShakeState get state => _currentState;

  /// Adds trauma to the camera, clamped in [0.0, 1.0].
  ///
  /// [hitDirection]: The 2D world/screen vector along which the impact force acts.
  /// Biases initial displacement along this vector, and tilts camera roll accordingly.
  ///
  /// [directionalWeight]: Optional override for the directional bias weight in [0.0, 1.0].
  void addTrauma(
    double amount, {
    Offset? hitDirection,
    double? directionalWeight,
  }) {
    if (amount <= 0.0) return;

    _trauma = (_trauma + amount).clamp(0.0, 1.0);

    if (hitDirection != null && (hitDirection.dx != 0.0 || hitDirection.dy != 0.0)) {
      final double len = hitDirection.distance;
      if (len > 0.0) {
        _normalizedHitDirection = Offset(hitDirection.dx / len, hitDirection.dy / len);
        _directionalImpulse = math.min(1.0, _directionalImpulse + amount);
        _directionalOscillationTime = 0.0;
      }
    }

    _computeCurrentState();
    notifyListeners();
  }

  /// Triggers a pre-tuned combat camera shake preset.
  void triggerPreset(
    CameraShakePreset preset, {
    Offset? hitDirection,
    double? directionalWeight,
  }) {
    _config = preset.config;
    _initNoise(2027);
    addTrauma(
      preset.trauma,
      hitDirection: hitDirection,
      directionalWeight: directionalWeight,
    );
  }

  /// Steps the camera shake simulation forward by [dt] seconds.
  void update(double dt) {
    if (dt <= 0.0) return;

    if (_trauma <= _config.traumaCutoff) {
      if (_trauma > 0.0 || _currentState != CameraShakeState.neutral) {
        _trauma = 0.0;
        _directionalImpulse = 0.0;
        _directionalOscillationTime = 0.0;
        _currentState = CameraShakeState.neutral;
        notifyListeners();
      }
      return;
    }

    _elapsedTime += dt;
    _directionalOscillationTime += dt;

    // Apply non-linear decay
    _trauma = _applyTraumaDecay(_trauma, dt);

    if (_trauma <= _config.traumaCutoff) {
      _trauma = 0.0;
      _directionalImpulse = 0.0;
      _directionalOscillationTime = 0.0;
      _currentState = CameraShakeState.neutral;
      notifyListeners();
      return;
    }

    _computeCurrentState();
    notifyListeners();
  }

  /// Evaluates the non-linear decay of trauma over time step [dt].
  double _applyTraumaDecay(double currentTrauma, double dt) {
    switch (_config.decayMode) {
      case CameraShakeDecayMode.quadratic:
        // Quadratic decay: decays faster at higher trauma, slows down smoothly as it approaches zero
        final rate = _config.decayRate * (0.4 + 0.6 * currentTrauma);
        final decayed = currentTrauma - rate * dt;
        return decayed > 0.0 ? decayed : 0.0;

      case CameraShakeDecayMode.exponential:
        // Exponential decay: trauma(t) = trauma(0) * exp(-rate * t)
        final decayed = currentTrauma * math.exp(-_config.decayRate * dt);
        return decayed > _config.traumaCutoff ? decayed : 0.0;

      case CameraShakeDecayMode.smoothStep:
        // Smoothstep decay
        final step = (_config.decayRate * dt);
        final normalized = (currentTrauma - step).clamp(0.0, 1.0);
        final decayed = normalized * normalized * (3.0 - 2.0 * normalized);
        return decayed > 0.0 ? decayed : 0.0;

      case CameraShakeDecayMode.linear:
        final decayed = currentTrauma - (_config.decayRate * dt);
        return decayed > 0.0 ? decayed : 0.0;
    }
  }

  /// Computes the exact screen displacement and rotation for the current trauma and time.
  void _computeCurrentState() {
    final intensity = math.pow(_trauma, _config.traumaExponent).toDouble();
    if (intensity <= 0.0) {
      _currentState = CameraShakeState.neutral;
      return;
    }

    // Dynamic frequency modulation: higher trauma causes higher frequency vibration
    final effectiveFreq = _config.baseFrequency + (_trauma * _config.frequencyModulation);
    final noiseTime = _elapsedTime * effectiveFreq;

    // Multi-octave continuous noise components in [-1.0, 1.0]
    final noiseXVal = _noiseX.sample(noiseTime);
    final noiseYVal = _noiseY.sample(noiseTime);
    final noiseRollVal = _noiseRoll.sample(noiseTime);
    final noisePitchVal = _noisePitch.sample(noiseTime);
    final noiseYawVal = _noiseYaw.sample(noiseTime);

    // Damped harmonic oscillator along hit direction vector
    // x(t) = e^(-zeta * omega * t) * cos(omega * t)
    double harmonicDisplacement = 0.0;
    if (_directionalImpulse > 0.0) {
      final damping = math.exp(-_config.harmonicDamping * _directionalOscillationTime);
      final oscillation = math.cos(_config.harmonicFrequency * _directionalOscillationTime);
      harmonicDisplacement = _directionalImpulse * damping * oscillation;

      // Damp impulse over time
      _directionalImpulse = math.max(0.0, _directionalImpulse - _config.decayRate * 0.5 * _directionalOscillationTime);
    }

    final dirWeight = _config.directionalBiasWeight.clamp(0.0, 1.0);
    final isotropicWeight = 1.0 - dirWeight;

    // 1. Directional translation
    final dirOffsetX = _normalizedHitDirection.dx * harmonicDisplacement * _config.maxTranslation.dx * dirWeight;
    final dirOffsetY = _normalizedHitDirection.dy * harmonicDisplacement * _config.maxTranslation.dy * dirWeight;

    // 2. Multi-octave noise translation
    final noiseOffsetX = noiseXVal * _config.maxTranslation.dx * (isotropicWeight + 0.3 * dirWeight);
    final noiseOffsetY = noiseYVal * _config.maxTranslation.dy * (isotropicWeight + 0.3 * dirWeight);

    final finalDx = (dirOffsetX + noiseOffsetX) * intensity;
    final finalDy = (dirOffsetY + noiseOffsetY) * intensity;

    // 3. Directional Roll Torque:
    // A hit from the left (+X velocity) rolls the camera clockwise (negative roll), and vice-versa
    final dirRollBias = -_normalizedHitDirection.dx * harmonicDisplacement * _config.maxRoll * dirWeight;
    final noiseRoll = noiseRollVal * _config.maxRoll * isotropicWeight;
    final finalRoll = (dirRollBias + noiseRoll) * intensity;

    // 4. Pitch and Yaw:
    // Vertical hits pitch the camera up/down
    final dirPitchBias = _normalizedHitDirection.dy * harmonicDisplacement * _config.maxPitch * dirWeight;
    final noisePitch = noisePitchVal * _config.maxPitch * isotropicWeight;
    final finalPitch = (dirPitchBias + noisePitch) * intensity;

    final finalYaw = noiseYawVal * _config.maxYaw * intensity;

    _currentState = CameraShakeState(
      translation: Offset(finalDx, finalDy),
      roll: finalRoll,
      pitch: finalPitch,
      yaw: finalYaw,
      trauma: _trauma,
      shakeIntensity: intensity,
      elapsedTime: _elapsedTime,
    );
  }

  /// Instantly resets trauma and zero out all camera shake displacements.
  void reset() {
    _trauma = 0.0;
    _elapsedTime = 0.0;
    _directionalImpulse = 0.0;
    _directionalOscillationTime = 0.0;
    _normalizedHitDirection = Offset.zero;
    _currentState = CameraShakeState.neutral;
    notifyListeners();
  }
}

/// A Flutter widget that hosts and transforms its child with [DirectionalCameraShake].
class DirectionalCameraShakeHost extends StatelessWidget {
  final DirectionalCameraShake controller;
  final Widget child;
  final Offset? pivot;

  const DirectionalCameraShakeHost({
    super.key,
    required this.controller,
    required this.child,
    this.pivot,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, staticChild) {
        final state = controller.state;
        if (!controller.isActive && state.translation == Offset.zero && state.roll == 0.0) {
          return staticChild!;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final effectivePivot = pivot ?? Offset(constraints.maxWidth / 2.0, constraints.maxHeight / 2.0);
            return Transform(
              alignment: FractionalOffset.center,
              transform: state.toMatrix4WithPivot(effectivePivot),
              child: staticChild,
            );
          },
        );
      },
      child: child,
    );
  }
}
