import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// -----------------------------------------------------------------------------
// AAA Multi-Layer GPU Particle System (2027 Cinematic Pipeline)
// -----------------------------------------------------------------------------

/// Particle rendering and simulation procedural types.
enum GpuParticleType {
  /// Arcane spell / glowing energy orb with plasma turbulence and chromatic halo.
  spellOrb,

  /// Directional incandescent spark streak with velocity-aligned stretch and flicker.
  sparkStreak,

  /// Viscous blood droplet SDF with teardrop stretching and wet specular highlight.
  bloodDroplet,

  /// Mystical geometric rune glyph with concentric rings and pulsating aura.
  magicRune,

  /// Expanding shockwave / energy blast ring with turbulent wavefront.
  shockwave,
}

/// Blending mode for particle layers.
enum GpuBlendMode {
  /// Standard alpha compositing (for blood, smoke, physical debris).
  normal,

  /// Additive HDR blending (for spells, weapon sparks, laser flashes, runes).
  additive,

  /// Screen blending for soft magical glows.
  screen,
}

// -----------------------------------------------------------------------------
// High-Precision Procedural Noise & Divergence-Free Curl Field
// -----------------------------------------------------------------------------

/// Analytical 2D Simplex Noise and Curl Turbulence generator.
/// Pure Dart implementation matching GLSL shader calculations.
class GpuNoise {
  GpuNoise._();

  static final Uint8List _p = () {
    const List<int> permutation = <int>[
      151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
      140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
      247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
      57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
      74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
      60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
      65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
      200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3,
      64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85,
      212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170,
      213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172,
      9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112,
      104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179,
      162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199,
      106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236,
      205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61,
      156, 180,
    ];
    final Uint8List table = Uint8List(512);
    for (int i = 0; i < 256; ++i) {
      table[i] = permutation[i];
      table[i + 256] = permutation[i];
    }
    return table;
  }();

  static const List<List<double>> _grad2 = <List<double>>[
    <double>[1, 1], <double>[-1, 1], <double>[1, -1], <double>[-1, -1],
    <double>[1, 0], <double>[-1, 0], <double>[0, 1], <double>[0, -1],
  ];

  /// Evaluates 2D Simplex Noise in range [-1.0, 1.0].
  static double simplex2D(double xin, double yin) {
    const double f2 = 0.3660254037844386; // 0.5 * (sqrt(3.0) - 1.0)
    const double g2 = 0.2113248654051871; // (3.0 - sqrt(3.0)) / 6.0

    double n0 = 0.0;
    double n1 = 0.0;
    double n2 = 0.0;

    final double s = (xin + yin) * f2;
    final int i = (xin + s).floor();
    final int j = (yin + s).floor();
    final double t = (i + j) * g2;
    final double x0 = xin - (i - t);
    final double y0 = yin - (j - t);

    int i1 = 0;
    int j1 = 0;
    if (x0 > y0) {
      i1 = 1;
      j1 = 0;
    } else {
      i1 = 0;
      j1 = 1;
    }

    final double x1 = x0 - i1 + g2;
    final double y1 = y0 - j1 + g2;
    final double x2 = x0 - 1.0 + 2.0 * g2;
    final double y2 = y0 - 1.0 + 2.0 * g2;

    final int ii = i & 255;
    final int jj = j & 255;
    final int gi0 = _p[ii + _p[jj]] % 8;
    final int gi1 = _p[ii + i1 + _p[jj + j1]] % 8;
    final int gi2 = _p[ii + 1 + _p[jj + 1]] % 8;

    double t0 = 0.5 - x0 * x0 - y0 * y0;
    if (t0 >= 0) {
      t0 *= t0;
      n0 = t0 * t0 * (_grad2[gi0][0] * x0 + _grad2[gi0][1] * y0);
    }

    double t1 = 0.5 - x1 * x1 - y1 * y1;
    if (t1 >= 0) {
      t1 *= t1;
      n1 = t1 * t1 * (_grad2[gi1][0] * x1 + _grad2[gi1][1] * y1);
    }

    double t2 = 0.5 - x2 * x2 - y2 * y2;
    if (t2 >= 0) {
      t2 *= t2;
      n2 = t2 * t2 * (_grad2[gi2][0] * x2 + _grad2[gi2][1] * y2);
    }

    return 70.0 * (n0 + n1 + n2);
  }

  /// Calculates a 2D curl noise vector `(curlX, curlY) = (dPhi/dy, -dPhi/dx)`.
  /// Guaranteed divergence-free (div(V) = 0), creating natural fluid swirls
  /// without artificial clumping or mass concentration.
  static (double, double) curlNoise2D(double x, double y) {
    const double eps = 0.005;
    final double nYPlus = simplex2D(x, y + eps);
    final double nYMinus = simplex2D(x, y - eps);
    final double dPhiDy = (nYPlus - nYMinus) / (2.0 * eps);

    final double nXPlus = simplex2D(x + eps, y);
    final double nXMinus = simplex2D(x - eps, y);
    final double dPhiDx = (nXPlus - nXMinus) / (2.0 * eps);

    return (dPhiDy, -dPhiDx);
  }
}

// -----------------------------------------------------------------------------
// Particle Layer Specification
// -----------------------------------------------------------------------------

/// Configuration for a distinct layer inside the multi-layer particle system.
class GpuParticleLayerConfig {
  const GpuParticleLayerConfig({
    required this.name,
    required this.type,
    this.emissionRate = 0.0,
    this.maxParticles = 500,
    this.minLifetime = 0.5,
    this.maxLifetime = 1.5,
    this.minSpeed = 50.0,
    this.maxSpeed = 150.0,
    this.spreadAngle = math.pi * 2.0,
    this.emissionAngle = 0.0,
    this.gravity = Offset.zero,
    this.drag = 0.0,
    this.turbulenceStrength = 0.0,
    this.turbulenceFrequency = 0.005,
    this.startSize = 10.0,
    this.endSize = 2.0,
    this.startColor = const Color(0xFFFFFFFF),
    this.midColor,
    this.endColor = const Color(0x00FFFFFF),
    this.emissiveIntensity = 1.0,
    this.minRotationSpeed = 0.0,
    this.maxRotationSpeed = 0.0,
    this.bounce = 0.0,
    this.floorY,
    this.blendMode = GpuBlendMode.additive,
    this.layerParam = 0.0,
  });

  final String name;
  final GpuParticleType type;

  /// Continuous emission rate in particles per second.
  final double emissionRate;

  /// Maximum concurrent particles allowed for this layer.
  final int maxParticles;

  final double minLifetime;
  final double maxLifetime;

  final double minSpeed;
  final double maxSpeed;

  /// Cone spread angle in radians (e.g. 2*pi for omni, pi/4 for tight spray).
  final double spreadAngle;

  /// Central emission trajectory angle in radians.
  final double emissionAngle;

  /// Acceleration vector in pixels/s^2 (e.g. (0, 980) for gravity).
  final Offset gravity;

  /// Air resistance / fluid drag damping coefficient [0.0, 1.0].
  final double drag;

  /// Magnitude of divergence-free curl turbulence velocity perturbation.
  final double turbulenceStrength;

  /// Spatial frequency of curl turbulence noise.
  final double turbulenceFrequency;

  final double startSize;
  final double endSize;

  final Color startColor;
  final Color? midColor;
  final Color endColor;

  /// HDR bloom boost multiplier (values > 1.0 trigger bloom threshold passes).
  final double emissiveIntensity;

  final double minRotationSpeed;
  final double maxRotationSpeed;

  /// Floor bounce restitution factor [0.0, 1.0]. 0.0 = stops, 0.7 = elastic bounce.
  final double bounce;

  /// Optional ground collision plane Y coordinate.
  final double? floorY;

  final GpuBlendMode blendMode;

  /// Custom shader parameter (e.g. rune variant index or blood viscosity).
  final double layerParam;

  GpuParticleLayerConfig copyWith({
    String? name,
    GpuParticleType? type,
    double? emissionRate,
    int? maxParticles,
    double? minLifetime,
    double? maxLifetime,
    double? minSpeed,
    double? maxSpeed,
    double? spreadAngle,
    double? emissionAngle,
    Offset? gravity,
    double? drag,
    double? turbulenceStrength,
    double? turbulenceFrequency,
    double? startSize,
    double? endSize,
    Color? startColor,
    Color? midColor,
    Color? endColor,
    double? emissiveIntensity,
    double? minRotationSpeed,
    double? maxRotationSpeed,
    double? bounce,
    double? floorY,
    GpuBlendMode? blendMode,
    double? layerParam,
  }) {
    return GpuParticleLayerConfig(
      name: name ?? this.name,
      type: type ?? this.type,
      emissionRate: emissionRate ?? this.emissionRate,
      maxParticles: maxParticles ?? this.maxParticles,
      minLifetime: minLifetime ?? this.minLifetime,
      maxLifetime: maxLifetime ?? this.maxLifetime,
      minSpeed: minSpeed ?? this.minSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      spreadAngle: spreadAngle ?? this.spreadAngle,
      emissionAngle: emissionAngle ?? this.emissionAngle,
      gravity: gravity ?? this.gravity,
      drag: drag ?? this.drag,
      turbulenceStrength: turbulenceStrength ?? this.turbulenceStrength,
      turbulenceFrequency: turbulenceFrequency ?? this.turbulenceFrequency,
      startSize: startSize ?? this.startSize,
      endSize: endSize ?? this.endSize,
      startColor: startColor ?? this.startColor,
      midColor: midColor ?? this.midColor,
      endColor: endColor ?? this.endColor,
      emissiveIntensity: emissiveIntensity ?? this.emissiveIntensity,
      minRotationSpeed: minRotationSpeed ?? this.minRotationSpeed,
      maxRotationSpeed: maxRotationSpeed ?? this.maxRotationSpeed,
      bounce: bounce ?? this.bounce,
      floorY: floorY ?? this.floorY,
      blendMode: blendMode ?? this.blendMode,
      layerParam: layerParam ?? this.layerParam,
    );
  }
}

// -----------------------------------------------------------------------------
// Contiguous Float32List Particle Buffer (Zero Heap Allocation)
// -----------------------------------------------------------------------------

/// Ultra-high performance contiguous memory buffer storing all particle state.
/// Eliminates GC thrashing by recycling particle memory in-place via an internal free-list.
class GpuParticleBuffer {
  GpuParticleBuffer(this.capacity)
      : data = Float32List(capacity * stride),
        _freeList = Uint32List(capacity),
        _activeIndices = Uint32List(capacity),
        _activeLookup = Int32List(capacity) {
    _freeCount = capacity;
    for (int i = 0; i < capacity; ++i) {
      _freeList[i] = i;
      _activeLookup[i] = -1;
    }
  }

  /// Stride in floats per particle:
  /// 0: X
  /// 1: Y
  /// 2: VX
  /// 3: VY
  /// 4: LIFE (elapsed seconds)
  /// 5: MAX_LIFE (total lifetime seconds)
  /// 6: START_SIZE
  /// 7: END_SIZE
  /// 8: ROTATION (radians)
  /// 9: ROT_SPEED (radians/sec)
  /// 10: COLOR_R0
  /// 11: COLOR_G0
  /// 12: COLOR_B0
  /// 13: COLOR_A0
  /// 14: COLOR_R1
  /// 15: COLOR_G1
  /// 16: COLOR_B1
  /// 17: COLOR_A1
  /// 18: LAYER_ID
  /// 19: SEED
  static const int stride = 20;

  static const int kOffsetX = 0;
  static const int kOffsetY = 1;
  static const int kOffsetVx = 2;
  static const int kOffsetVy = 3;
  static const int kOffsetLife = 4;
  static const int kOffsetMaxLife = 5;
  static const int kOffsetStartSize = 6;
  static const int kOffsetEndSize = 7;
  static const int kOffsetRotation = 8;
  static const int kOffsetRotSpeed = 9;
  static const int kOffsetColorR0 = 10;
  static const int kOffsetColorG0 = 11;
  static const int kOffsetColorB0 = 12;
  static const int kOffsetColorA0 = 13;
  static const int kOffsetColorR1 = 14;
  static const int kOffsetColorG1 = 15;
  static const int kOffsetColorB1 = 16;
  static const int kOffsetColorA1 = 17;
  static const int kOffsetLayerId = 18;
  static const int kOffsetSeed = 19;

  final int capacity;
  final Float32List data;

  final Uint32List _freeList;
  int _freeCount = 0;

  final Uint32List _activeIndices;
  final Int32List _activeLookup;
  int _activeCount = 0;

  int get activeCount => _activeCount;
  int get freeCount => _freeCount;

  /// Allocates an available particle index in O(1) time without heap allocations.
  int? allocate() {
    if (_freeCount <= 0) {
      return null;
    }
    _freeCount--;
    final int particleIndex = _freeList[_freeCount];

    _activeLookup[particleIndex] = _activeCount;
    _activeIndices[_activeCount] = particleIndex;
    _activeCount++;

    return particleIndex;
  }

  /// Recycles an expired particle back into the free-list in O(1) time.
  void free(int particleIndex) {
    final int densePos = _activeLookup[particleIndex];
    if (densePos < 0) {
      return;
    }

    // Swap with last active particle to maintain contiguous active list
    final int lastIndex = _activeIndices[_activeCount - 1];
    _activeIndices[densePos] = lastIndex;
    _activeLookup[lastIndex] = densePos;

    _activeLookup[particleIndex] = -1;
    _activeCount--;

    _freeList[_freeCount] = particleIndex;
    _freeCount++;
  }

  /// Direct read and write accessors for particle attributes:
  double getX(int i) => data[i * stride + kOffsetX];
  double getY(int i) => data[i * stride + kOffsetY];
  void setPosition(int i, double x, double y) {
    final int base = i * stride;
    data[base + kOffsetX] = x;
    data[base + kOffsetY] = y;
  }

  double getVx(int i) => data[i * stride + kOffsetVx];
  double getVy(int i) => data[i * stride + kOffsetVy];
  void setVelocity(int i, double vx, double vy) {
    final int base = i * stride;
    data[base + kOffsetVx] = vx;
    data[base + kOffsetVy] = vy;
  }

  double getLife(int i) => data[i * stride + kOffsetLife];
  double getMaxLife(int i) => data[i * stride + kOffsetMaxLife];
  void setLife(int i, double life, double maxLife) {
    final int base = i * stride;
    data[base + kOffsetLife] = life;
    data[base + kOffsetMaxLife] = maxLife;
  }

  double getNormalizedAge(int i) {
    final int base = i * stride;
    final double maxLife = data[base + kOffsetMaxLife];
    if (maxLife <= 0.0) return 1.0;
    return (data[base + kOffsetLife] / maxLife).clamp(0.0, 1.0);
  }

  double getCurrentSize(int i) {
    final int base = i * stride;
    final double age = getNormalizedAge(i);
    final double s0 = data[base + kOffsetStartSize];
    final double s1 = data[base + kOffsetEndSize];
    return s0 + (s1 - s0) * age;
  }

  double getRotation(int i) => data[i * stride + kOffsetRotation];
  double getRotSpeed(int i) => data[i * stride + kOffsetRotSpeed];
  void setRotation(int i, double rot, double speed) {
    final int base = i * stride;
    data[base + kOffsetRotation] = rot;
    data[base + kOffsetRotSpeed] = speed;
  }

  int getLayerId(int i) => data[i * stride + kOffsetLayerId].toInt();
  double getSeed(int i) => data[i * stride + kOffsetSeed];

  Color getCurrentColor(int i) {
    final int base = i * stride;
    final double age = getNormalizedAge(i);

    final double r0 = data[base + kOffsetColorR0];
    final double g0 = data[base + kOffsetColorG0];
    final double b0 = data[base + kOffsetColorB0];
    final double a0 = data[base + kOffsetColorA0];

    final double r1 = data[base + kOffsetColorR1];
    final double g1 = data[base + kOffsetColorG1];
    final double b1 = data[base + kOffsetColorB1];
    final double a1 = data[base + kOffsetColorA1];

    final double r = r0 + (r1 - r0) * age;
    final double g = g0 + (g1 - g0) * age;
    final double b = b0 + (b1 - b0) * age;
    final double a = a0 + (a1 - a0) * age;

    return Color.fromARGB(
      (a.clamp(0.0, 1.0) * 255.0).round(),
      (r.clamp(0.0, 1.0) * 255.0).round(),
      (g.clamp(0.0, 1.0) * 255.0).round(),
      (b.clamp(0.0, 1.0) * 255.0).round(),
    );
  }

  /// Returns the array of active particle indices.
  Uint32List get activeIndices => _activeIndices;

  /// Resets all particles to free state.
  void clear() {
    _activeCount = 0;
    _freeCount = capacity;
    for (int i = 0; i < capacity; ++i) {
      _freeList[i] = i;
      _activeLookup[i] = -1;
    }
  }
}

// -----------------------------------------------------------------------------
// Multi-Layer GPU Particle System Engine
// -----------------------------------------------------------------------------

/// Central particle emitter and physics simulation manager.
class GpuParticleSystem {
  GpuParticleSystem({
    required this.layers,
    int? maxCapacity,
    int? randomSeed,
  })  : _random = randomSeed != null ? math.Random(randomSeed) : math.Random(),
        _emissionCounters = Float64List(layers.length),
        buffer = GpuParticleBuffer(
          maxCapacity ??
              layers.fold<int>(0, (int sum, GpuParticleLayerConfig layer) => sum + layer.maxParticles),
        );

  final List<GpuParticleLayerConfig> layers;
  final GpuParticleBuffer buffer;
  final math.Random _random;
  final Float64List _emissionCounters;

  double _globalTime = 0.0;
  double get globalTime => _globalTime;

  int get activeParticleCount => buffer.activeCount;
  int get capacity => buffer.capacity;

  /// Advances physics simulation and continuous emission by [dt] seconds.
  void update(double dt) {
    if (dt <= 0.0) return;
    _globalTime += dt;

    // 1. Update existing active particles
    int i = 0;
    while (i < buffer.activeCount) {
      final int p = buffer.activeIndices[i];
      final int base = p * GpuParticleBuffer.stride;

      // Age particle
      double life = buffer.data[base + GpuParticleBuffer.kOffsetLife] + dt;
      final double maxLife = buffer.data[base + GpuParticleBuffer.kOffsetMaxLife];

      if (life >= maxLife) {
        // Expired -> Recycle back to pool
        buffer.free(p);
        // Do not increment i, as buffer.free swaps the last element into i
        continue;
      }

      buffer.data[base + GpuParticleBuffer.kOffsetLife] = life;

      // Retrieve layer configuration
      final int layerId = buffer.data[base + GpuParticleBuffer.kOffsetLayerId].toInt();
      final GpuParticleLayerConfig layer =
          (layerId >= 0 && layerId < layers.length) ? layers[layerId] : layers[0];

      double x = buffer.data[base + GpuParticleBuffer.kOffsetX];
      double y = buffer.data[base + GpuParticleBuffer.kOffsetY];
      double vx = buffer.data[base + GpuParticleBuffer.kOffsetVx];
      double vy = buffer.data[base + GpuParticleBuffer.kOffsetVy];

      // Gravity acceleration
      vx += layer.gravity.dx * dt;
      vy += layer.gravity.dy * dt;

      // Divergence-free curl turbulence perturbation
      if (layer.turbulenceStrength > 0.0) {
        final (double curlX, double curlY) = GpuNoise.curlNoise2D(
          x * layer.turbulenceFrequency,
          y * layer.turbulenceFrequency + _globalTime * 0.5,
        );
        vx += curlX * layer.turbulenceStrength * dt;
        vy += curlY * layer.turbulenceStrength * dt;
      }

      // Air resistance / viscous fluid drag
      if (layer.drag > 0.0) {
        final double dragFactor = math.max(0.0, 1.0 - layer.drag * dt);
        vx *= dragFactor;
        vy *= dragFactor;
      }

      // Position integration
      x += vx * dt;
      y += vy * dt;

      // Floor collision plane with restitution bounce and ground friction
      if (layer.floorY != null && y >= layer.floorY! && vy > 0.0) {
        y = layer.floorY!;
        vy = -vy * layer.bounce;
        vx *= 0.8; // ground friction damping
        if (vy.abs() < 10.0) {
          vy = 0.0;
        }
      }

      buffer.data[base + GpuParticleBuffer.kOffsetX] = x;
      buffer.data[base + GpuParticleBuffer.kOffsetY] = y;
      buffer.data[base + GpuParticleBuffer.kOffsetVx] = vx;
      buffer.data[base + GpuParticleBuffer.kOffsetVy] = vy;

      // Angular rotation
      final double rotSpeed = buffer.data[base + GpuParticleBuffer.kOffsetRotSpeed];
      buffer.data[base + GpuParticleBuffer.kOffsetRotation] += rotSpeed * dt;

      i++;
    }

    // 2. Process continuous layer emission rates
    for (int layerIdx = 0; layerIdx < layers.length; ++layerIdx) {
      final GpuParticleLayerConfig layer = layers[layerIdx];
      if (layer.emissionRate <= 0.0) continue;

      _emissionCounters[layerIdx] += layer.emissionRate * dt;
      final int particlesToSpawn = _emissionCounters[layerIdx].floor();
      if (particlesToSpawn > 0) {
        _emissionCounters[layerIdx] -= particlesToSpawn;
        emitBurst(
          layerIndex: layerIdx,
          count: particlesToSpawn,
          origin: Offset.zero,
        );
      }
    }
  }

  /// Instantly emits a burst of particles for the specified [layerIndex] at [origin].
  int emitBurst({
    required int layerIndex,
    required int count,
    required Offset origin,
    double? directionAngle,
    double speedMultiplier = 1.0,
  }) {
    if (layerIndex < 0 || layerIndex >= layers.length || count <= 0) {
      return 0;
    }

    final GpuParticleLayerConfig layer = layers[layerIndex];
    int spawned = 0;

    for (int i = 0; i < count; ++i) {
      final int? p = buffer.allocate();
      if (p == null) {
        // Buffer capacity reached
        break;
      }

      final int base = p * GpuParticleBuffer.stride;

      // Lifetime
      final double lifeRange = layer.maxLifetime - layer.minLifetime;
      final double maxLife = layer.minLifetime + (lifeRange > 0 ? _random.nextDouble() * lifeRange : 0.0);

      // Trajectory angle
      final double baseAngle = directionAngle ?? layer.emissionAngle;
      final double angle = baseAngle + (_random.nextDouble() - 0.5) * layer.spreadAngle;

      // Speed
      final double speedRange = layer.maxSpeed - layer.minSpeed;
      final double speed =
          (layer.minSpeed + (speedRange > 0 ? _random.nextDouble() * speedRange : 0.0)) *
          speedMultiplier;

      final double vx = math.cos(angle) * speed;
      final double vy = math.sin(angle) * speed;

      // Rotation
      final double rot = _random.nextDouble() * math.pi * 2.0;
      final double rotSpeedRange = layer.maxRotationSpeed - layer.minRotationSpeed;
      final double rotSpeed =
          layer.minRotationSpeed + (rotSpeedRange > 0 ? _random.nextDouble() * rotSpeedRange : 0.0);

      // Colors
      final Color c0 = layer.startColor;
      final Color c1 = layer.endColor;

      // Seed
      final double seed = _random.nextDouble();

      // Write into contiguous buffer
      buffer.data[base + GpuParticleBuffer.kOffsetX] = origin.dx;
      buffer.data[base + GpuParticleBuffer.kOffsetY] = origin.dy;
      buffer.data[base + GpuParticleBuffer.kOffsetVx] = vx;
      buffer.data[base + GpuParticleBuffer.kOffsetVy] = vy;
      buffer.data[base + GpuParticleBuffer.kOffsetLife] = 0.0;
      buffer.data[base + GpuParticleBuffer.kOffsetMaxLife] = maxLife;
      buffer.data[base + GpuParticleBuffer.kOffsetStartSize] = layer.startSize;
      buffer.data[base + GpuParticleBuffer.kOffsetEndSize] = layer.endSize;
      buffer.data[base + GpuParticleBuffer.kOffsetRotation] = rot;
      buffer.data[base + GpuParticleBuffer.kOffsetRotSpeed] = rotSpeed;
      buffer.data[base + GpuParticleBuffer.kOffsetColorR0] = c0.r;
      buffer.data[base + GpuParticleBuffer.kOffsetColorG0] = c0.g;
      buffer.data[base + GpuParticleBuffer.kOffsetColorB0] = c0.b;
      buffer.data[base + GpuParticleBuffer.kOffsetColorA0] = c0.a;
      buffer.data[base + GpuParticleBuffer.kOffsetColorR1] = c1.r;
      buffer.data[base + GpuParticleBuffer.kOffsetColorG1] = c1.g;
      buffer.data[base + GpuParticleBuffer.kOffsetColorB1] = c1.b;
      buffer.data[base + GpuParticleBuffer.kOffsetColorA1] = c1.a;
      buffer.data[base + GpuParticleBuffer.kOffsetLayerId] = layerIndex.toDouble();
      buffer.data[base + GpuParticleBuffer.kOffsetSeed] = seed;

      spawned++;
    }

    return spawned;
  }

  /// Triggers a simultaneous multi-layer burst at [origin].
  int emitAllLayersBurst({
    required int countPerLayer,
    required Offset origin,
    double? directionAngle,
  }) {
    int total = 0;
    for (int i = 0; i < layers.length; ++i) {
      total += emitBurst(
        layerIndex: i,
        count: countPerLayer,
        origin: origin,
        directionAngle: directionAngle,
      );
    }
    return total;
  }

  /// Clears all active particles and resets emission counters.
  void reset() {
    buffer.clear();
    for (int i = 0; i < _emissionCounters.length; ++i) {
      _emissionCounters[i] = 0.0;
    }
    _globalTime = 0.0;
  }
}

// -----------------------------------------------------------------------------
// Production AAA Particle Presets (R3)
// -----------------------------------------------------------------------------

/// Ready-to-use cinematic presets for spells, weapon impacts, sparks, blood, and magic runes.
class GpuParticlePresets {
  GpuParticlePresets._();

  /// High-tier magical fireball / spell projectile with blazing core and swirling embers.
  static GpuParticleSystem spellFireball({
    Offset origin = Offset.zero,
    Offset direction = const Offset(1, 0),
  }) {
    final double angle = math.atan2(direction.dy, direction.dx);

    return GpuParticleSystem(
      layers: <GpuParticleLayerConfig>[
        // Layer 0: Core blazing orb
        GpuParticleLayerConfig(
          name: 'CoreBlaze',
          type: GpuParticleType.spellOrb,
          emissionRate: 60.0,
          maxParticles: 300,
          minLifetime: 0.25,
          maxLifetime: 0.5,
          minSpeed: 200.0,
          maxSpeed: 260.0,
          spreadAngle: 0.15,
          emissionAngle: angle,
          startSize: 28.0,
          endSize: 6.0,
          startColor: const Color(0xFFFFFAEE),
          endColor: const Color(0xFFFF4500),
          emissiveIntensity: 3.5,
          turbulenceStrength: 25.0,
          blendMode: GpuBlendMode.additive,
        ),
        // Layer 1: Swirling arcane embers
        GpuParticleLayerConfig(
          name: 'SwirlingEmbers',
          type: GpuParticleType.sparkStreak,
          emissionRate: 120.0,
          maxParticles: 500,
          minLifetime: 0.4,
          maxLifetime: 0.8,
          minSpeed: 80.0,
          maxSpeed: 220.0,
          spreadAngle: math.pi * 0.7,
          emissionAngle: angle + math.pi, // trailing back
          startSize: 8.0,
          endSize: 2.0,
          startColor: const Color(0xFFFFD700),
          endColor: const Color(0xFF8B0000),
          emissiveIntensity: 2.0,
          turbulenceStrength: 120.0,
          turbulenceFrequency: 0.015,
          blendMode: GpuBlendMode.additive,
        ),
      ],
    );
  }

  /// Arcane explosion: radial shockwave ring + high-velocity magic shards + floating runes.
  static GpuParticleSystem spellArcaneBlast({
    Offset origin = Offset.zero,
  }) {
    return GpuParticleSystem(
      layers: <GpuParticleLayerConfig>[
        // Layer 0: Expanding Shockwave
        const GpuParticleLayerConfig(
          name: 'ArcaneShockwave',
          type: GpuParticleType.shockwave,
          maxParticles: 20,
          minLifetime: 0.35,
          maxLifetime: 0.5,
          minSpeed: 0.0,
          maxSpeed: 0.0,
          startSize: 10.0,
          endSize: 180.0,
          startColor: Color(0xFF00FFFF),
          endColor: Color(0x009400D3),
          emissiveIntensity: 4.0,
          turbulenceStrength: 10.0,
          blendMode: GpuBlendMode.additive,
        ),
        // Layer 1: Radial Arcane Shards
        const GpuParticleLayerConfig(
          name: 'ArcaneShards',
          type: GpuParticleType.sparkStreak,
          maxParticles: 400,
          minLifetime: 0.3,
          maxLifetime: 0.7,
          minSpeed: 250.0,
          maxSpeed: 600.0,
          spreadAngle: math.pi * 2.0,
          startSize: 12.0,
          endSize: 2.0,
          startColor: Color(0xFFFFFFFF),
          endColor: Color(0xFFBA55D3),
          emissiveIntensity: 3.0,
          drag: 1.5,
          blendMode: GpuBlendMode.additive,
        ),
        // Layer 2: Mystic Runes
        const GpuParticleLayerConfig(
          name: 'MysticRunes',
          type: GpuParticleType.magicRune,
          maxParticles: 50,
          minLifetime: 0.8,
          maxLifetime: 1.6,
          minSpeed: 30.0,
          maxSpeed: 90.0,
          spreadAngle: math.pi * 2.0,
          startSize: 24.0,
          endSize: 32.0,
          startColor: Color(0xFF00FFFF),
          endColor: Color(0x004169E1),
          emissiveIntensity: 2.5,
          minRotationSpeed: -1.5,
          maxRotationSpeed: 1.5,
          blendMode: GpuBlendMode.additive,
        ),
      ],
    );
  }

  /// Weapon impact: directional sparks bouncing off surface + incandescent flash + debris.
  static GpuParticleSystem weaponImpact({
    Offset origin = Offset.zero,
    Offset normal = const Offset(0, -1),
    double? floorY,
  }) {
    final double normalAngle = math.atan2(normal.dy, normal.dx);

    return GpuParticleSystem(
      layers: <GpuParticleLayerConfig>[
        // Layer 0: Directional Sparks with Gravity and Bounce
        GpuParticleLayerConfig(
          name: 'RicochetSparks',
          type: GpuParticleType.sparkStreak,
          maxParticles: 250,
          minLifetime: 0.3,
          maxLifetime: 0.9,
          minSpeed: 250.0,
          maxSpeed: 650.0,
          spreadAngle: math.pi * 0.5,
          emissionAngle: normalAngle,
          gravity: const Offset(0, 850),
          drag: 0.2,
          bounce: 0.65,
          floorY: floorY,
          startSize: 6.0,
          endSize: 1.5,
          startColor: const Color(0xFFFFFFA0),
          endColor: const Color(0xFFFF3300),
          emissiveIntensity: 4.0,
          blendMode: GpuBlendMode.additive,
        ),
        // Layer 1: Incandescent Impact Flash
        const GpuParticleLayerConfig(
          name: 'ImpactFlash',
          type: GpuParticleType.spellOrb,
          maxParticles: 10,
          minLifetime: 0.06,
          maxLifetime: 0.10,
          minSpeed: 0.0,
          maxSpeed: 0.0,
          startSize: 45.0,
          endSize: 10.0,
          startColor: Color(0xFFFFFFFF),
          endColor: Color(0xFFFFCC00),
          emissiveIntensity: 5.0,
          blendMode: GpuBlendMode.additive,
        ),
      ],
    );
  }

  /// Viscous blood splatter: high-velocity directional spray + aerosol mist + ground pools.
  static GpuParticleSystem bloodSplatter({
    Offset origin = Offset.zero,
    Offset direction = const Offset(1, 0),
    double? floorY,
  }) {
    final double sprayAngle = math.atan2(direction.dy, direction.dx);

    return GpuParticleSystem(
      layers: <GpuParticleLayerConfig>[
        // Layer 0: Directional Blood Droplets
        GpuParticleLayerConfig(
          name: 'BloodDroplets',
          type: GpuParticleType.bloodDroplet,
          maxParticles: 300,
          minLifetime: 0.4,
          maxLifetime: 1.2,
          minSpeed: 180.0,
          maxSpeed: 450.0,
          spreadAngle: math.pi * 0.4,
          emissionAngle: sprayAngle,
          gravity: const Offset(0, 900),
          drag: 0.4,
          bounce: 0.1,
          floorY: floorY,
          startSize: 14.0,
          endSize: 6.0,
          startColor: const Color(0xFF8B0000),
          endColor: const Color(0xFF3B0000),
          blendMode: GpuBlendMode.normal,
        ),
        // Layer 1: Fine Aerosol Blood Mist
        GpuParticleLayerConfig(
          name: 'BloodMist',
          type: GpuParticleType.bloodDroplet,
          maxParticles: 200,
          minLifetime: 0.25,
          maxLifetime: 0.6,
          minSpeed: 60.0,
          maxSpeed: 180.0,
          spreadAngle: math.pi * 0.65,
          emissionAngle: sprayAngle,
          gravity: const Offset(0, 400),
          drag: 0.8,
          startSize: 8.0,
          endSize: 1.5,
          startColor: const Color(0xCCB22222),
          endColor: const Color(0x004A0000),
          blendMode: GpuBlendMode.normal,
        ),
      ],
    );
  }

  /// Orbiting mystical runes: rotating enchanted glyphs + pulsating aura.
  static GpuParticleSystem magicRunes({
    Offset center = Offset.zero,
  }) {
    return GpuParticleSystem(
      layers: <GpuParticleLayerConfig>[
        // Layer 0: Orbiting Runic Sigils
        const GpuParticleLayerConfig(
          name: 'OrbitingGlyphs',
          type: GpuParticleType.magicRune,
          emissionRate: 15.0,
          maxParticles: 60,
          minLifetime: 2.0,
          maxLifetime: 3.5,
          minSpeed: 40.0,
          maxSpeed: 80.0,
          spreadAngle: math.pi * 2.0,
          startSize: 28.0,
          endSize: 34.0,
          startColor: Color(0xFF00FFCC),
          endColor: Color(0x000066FF),
          emissiveIntensity: 3.0,
          minRotationSpeed: 0.5,
          maxRotationSpeed: 1.5,
          blendMode: GpuBlendMode.additive,
        ),
        // Layer 1: Ascending Starlight Sparkles
        const GpuParticleLayerConfig(
          name: 'AscendingSparkles',
          type: GpuParticleType.sparkStreak,
          emissionRate: 40.0,
          maxParticles: 150,
          minLifetime: 1.0,
          maxLifetime: 2.0,
          minSpeed: 20.0,
          maxSpeed: 50.0,
          spreadAngle: math.pi * 0.5,
          emissionAngle: -math.pi * 0.5, // upwards
          gravity: Offset(0, -60), // buoyant float upwards
          turbulenceStrength: 45.0,
          startSize: 5.0,
          endSize: 1.0,
          startColor: Color(0xFFFFFFFF),
          endColor: Color(0x0000FFFF),
          emissiveIntensity: 2.5,
          blendMode: GpuBlendMode.additive,
        ),
      ],
    );
  }

  /// Ambient glowing embers and flames floating upwards with curl turbulence.
  static GpuParticleSystem emberFlames({
    Offset origin = Offset.zero,
  }) {
    return GpuParticleSystem(
      layers: <GpuParticleLayerConfig>[
        const GpuParticleLayerConfig(
          name: 'RisingEmbers',
          type: GpuParticleType.sparkStreak,
          emissionRate: 50.0,
          maxParticles: 200,
          minLifetime: 1.2,
          maxLifetime: 2.5,
          minSpeed: 30.0,
          maxSpeed: 80.0,
          spreadAngle: math.pi * 0.4,
          emissionAngle: -math.pi * 0.5, // upwards
          gravity: Offset(0, -90), // negative gravity / heat buoyancy
          turbulenceStrength: 60.0,
          turbulenceFrequency: 0.02,
          startSize: 6.0,
          endSize: 1.0,
          startColor: Color(0xFFFFCC00),
          endColor: Color(0x00FF2200),
          emissiveIntensity: 2.5,
          blendMode: GpuBlendMode.additive,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Uniform Packing & Shader Pipeline Controller
// -----------------------------------------------------------------------------

/// Packs uniforms matching `shaders/vfx/gpu_particles.frag` layout.
class GpuParticleShaderUniforms {
  GpuParticleShaderUniforms._();

  /// Total float uniforms declared in `gpu_particles.frag`: 24 floats.
  static const int uniformFloatCount = 24;

  static Float32List pack({
    required Size resolution,
    required double time,
    required Rect bounds,
    required GpuParticleType type,
    required double lifetimeProgress,
    required Color startColor,
    required Color endColor,
    required Offset velocity,
    required double turbulence,
    required double emissiveIntensity,
    required double size,
    required double rotation,
    required double layerParam,
  }) {
    final Float32List uniforms = Float32List(uniformFloatCount);

    // 0..1: uResolution
    uniforms[0] = resolution.width;
    uniforms[1] = resolution.height;

    // 2: uTime
    uniforms[2] = time;

    // 3..6: uBounds (minX, minY, width, height)
    uniforms[3] = bounds.left;
    uniforms[4] = bounds.top;
    uniforms[5] = bounds.width;
    uniforms[6] = bounds.height;

    // 7: uParticleType
    uniforms[7] = type.index.toDouble();

    // 8: uLifetimeProgress
    uniforms[8] = lifetimeProgress.clamp(0.0, 1.0);

    // 9..12: uColorStart (RGBA)
    uniforms[9] = startColor.r;
    uniforms[10] = startColor.g;
    uniforms[11] = startColor.b;
    uniforms[12] = startColor.a;

    // 13..16: uColorEnd (RGBA)
    uniforms[13] = endColor.r;
    uniforms[14] = endColor.g;
    uniforms[15] = endColor.b;
    uniforms[16] = endColor.a;

    // 17..18: uVelocity
    uniforms[17] = velocity.dx;
    uniforms[18] = velocity.dy;

    // 19: uTurbulence
    uniforms[19] = turbulence;

    // 20: uEmissiveIntensity
    uniforms[20] = emissiveIntensity;

    // 21: uSize
    uniforms[21] = size;

    // 22: uRotation
    uniforms[22] = rotation;

    // 23: uLayerParam
    uniforms[23] = layerParam;

    return uniforms;
  }

  /// Applies packed uniforms to an initialized Flutter FragmentShader.
  static void apply(ui.FragmentShader shader, Float32List uniforms) {
    for (int i = 0; i < uniforms.length; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
  }
}

// -----------------------------------------------------------------------------
// High-Performance GPU Particle Painter (Zero Per-Particle Widget Allocation)
// -----------------------------------------------------------------------------

/// CustomPainter rendering all particles via GPU fragment shader or hardware-accelerated canvas batching.
class GpuParticlePainter extends CustomPainter {
  GpuParticlePainter({
    required this.system,
    this.fragmentShader,
  });

  final GpuParticleSystem system;
  final ui.FragmentShader? fragmentShader;

  @override
  void paint(Canvas canvas, Size size) {
    if (system.activeParticleCount == 0) return;

    final GpuParticleBuffer buffer = system.buffer;
    final int count = buffer.activeCount;

    // Batch paint objects
    final Paint additivePaint = Paint()..blendMode = BlendMode.plus;
    final Paint normalPaint = Paint()..blendMode = BlendMode.srcOver;

    for (int i = 0; i < count; ++i) {
      final int p = buffer.activeIndices[i];
      final int base = p * GpuParticleBuffer.stride;

      final double px = buffer.data[base + GpuParticleBuffer.kOffsetX];
      final double py = buffer.data[base + GpuParticleBuffer.kOffsetY];
      final double age = buffer.getNormalizedAge(p);
      final double pSize = buffer.getCurrentSize(p);

      if (pSize <= 0.0) continue;

      final int layerId = buffer.data[base + GpuParticleBuffer.kOffsetLayerId].toInt();
      final GpuParticleLayerConfig layer = (layerId >= 0 && layerId < system.layers.length)
          ? system.layers[layerId]
          : system.layers[0];

      final double halfSize = pSize * 0.5;
      final Rect bounds = Rect.fromLTWH(px - halfSize, py - halfSize, pSize, pSize);

      // 1. GPU Runtime FragmentShader path
      if (fragmentShader != null) {
        final double vx = buffer.data[base + GpuParticleBuffer.kOffsetVx];
        final double vy = buffer.data[base + GpuParticleBuffer.kOffsetVy];
        final double rot = buffer.data[base + GpuParticleBuffer.kOffsetRotation];

        final Float32List uniforms = GpuParticleShaderUniforms.pack(
          resolution: size,
          time: system.globalTime,
          bounds: bounds,
          type: layer.type,
          lifetimeProgress: age,
          startColor: layer.startColor,
          endColor: layer.endColor,
          velocity: Offset(vx, vy),
          turbulence: layer.turbulenceStrength,
          emissiveIntensity: layer.emissiveIntensity,
          size: pSize,
          rotation: rot,
          layerParam: layer.layerParam,
        );

        GpuParticleShaderUniforms.apply(fragmentShader!, uniforms);

        final Paint shaderPaint = Paint()
          ..shader = fragmentShader
          ..blendMode =
              layer.blendMode == GpuBlendMode.additive ? BlendMode.plus : BlendMode.srcOver;

        canvas.drawRect(bounds, shaderPaint);
        continue;
      }

      // 2. High-Performance Canvas Hardware Fallback (Headless tests & non-shader devices)
      final Color col = buffer.getCurrentColor(p);
      final Paint activePaint =
          layer.blendMode == GpuBlendMode.additive ? additivePaint : normalPaint;
      activePaint.color = col;

      switch (layer.type) {
        case GpuParticleType.spellOrb:
          // Glowing radial circle with core highlight
          canvas.drawCircle(Offset(px, py), halfSize, activePaint);
          if (layer.emissiveIntensity > 1.5) {
            final Paint coreHighlight = Paint()
              ..color = const Color(0xCCFFFFFF)
              ..blendMode = BlendMode.plus;
            canvas.drawCircle(Offset(px, py), halfSize * 0.35, coreHighlight);
          }
          break;

        case GpuParticleType.sparkStreak:
          // Elongated spark capsule aligned with velocity
          final double vx = buffer.data[base + GpuParticleBuffer.kOffsetVx];
          final double vy = buffer.data[base + GpuParticleBuffer.kOffsetVy];
          final double speed = math.sqrt(vx * vx + vy * vy);
          if (speed > 10.0) {
            final double streakLength = (speed * 0.04).clamp(halfSize, halfSize * 4.0);
            final double dirX = vx / speed;
            final double dirY = vy / speed;
            final Offset pStart = Offset(px - dirX * streakLength, py - dirY * streakLength);
            final Offset pEnd = Offset(px, py);

            final Paint streakPaint = Paint()
              ..color = col
              ..strokeWidth = math.max(1.0, halfSize * 0.4)
              ..strokeCap = StrokeCap.round
              ..blendMode = BlendMode.plus;
            canvas.drawLine(pStart, pEnd, streakPaint);
          } else {
            canvas.drawCircle(Offset(px, py), halfSize * 0.5, activePaint);
          }
          break;

        case GpuParticleType.bloodDroplet:
          // Teardrop / ellipse droplet
          final double vx = buffer.data[base + GpuParticleBuffer.kOffsetVx];
          final double vy = buffer.data[base + GpuParticleBuffer.kOffsetVy];
          final double speed = math.sqrt(vx * vx + vy * vy);
          if (speed > 30.0) {
            final double dirX = vx / speed;
            final double dirY = vy / speed;
            final Offset pTail = Offset(px - dirX * halfSize * 1.5, py - dirY * halfSize * 1.5);
            final Offset pHead = Offset(px, py);
            final Paint dropPaint = Paint()
              ..color = col
              ..strokeWidth = halfSize
              ..strokeCap = StrokeCap.round
              ..blendMode = BlendMode.srcOver;
            canvas.drawLine(pTail, pHead, dropPaint);
          } else {
            canvas.drawCircle(Offset(px, py), halfSize, activePaint);
          }
          break;

        case GpuParticleType.magicRune:
          // Concentric geometric rune glyph
          final double rot = buffer.data[base + GpuParticleBuffer.kOffsetRotation];
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(rot);

          final Paint runeRing = Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..blendMode = BlendMode.plus;

          canvas.drawCircle(Offset.zero, halfSize, runeRing);
          canvas.drawCircle(Offset.zero, halfSize * 0.65, runeRing);

          // Central cross/star
          canvas.drawLine(
            Offset(-halfSize * 0.5, 0),
            Offset(halfSize * 0.5, 0),
            runeRing,
          );
          canvas.drawLine(
            Offset(0, -halfSize * 0.5),
            Offset(0, halfSize * 0.5),
            runeRing,
          );

          canvas.restore();
          break;

        case GpuParticleType.shockwave:
          // Expanding blast ring
          final Paint waveRing = Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, pSize * 0.08)
            ..blendMode = BlendMode.plus;
          canvas.drawCircle(Offset(px, py), halfSize, waveRing);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GpuParticlePainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// Production Zero-Allocation Particle Widget
// -----------------------------------------------------------------------------

/// Flutter widget embedding the GPU particle system with continuous ticker updates.
/// Guarantees zero widget allocations per particle.
class GpuParticleWidget extends StatefulWidget {
  const GpuParticleWidget({
    super.key,
    required this.system,
    this.fragmentShader,
    this.autoTick = true,
  });

  final GpuParticleSystem system;
  final ui.FragmentShader? fragmentShader;
  final bool autoTick;

  @override
  State<GpuParticleWidget> createState() => _GpuParticleWidgetState();
}

class _GpuParticleWidgetState extends State<GpuParticleWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.autoTick) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed != Duration.zero) {
      final double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      if (dt > 0.0) {
        // Cap max elapsed frame to 2.0s to handle system suspension gracefully
        double remaining = math.min(dt, 2.0);
        // Sub-step in increments of <= 0.05s for high-fidelity physics stability
        while (remaining > 0.0001) {
          final double step = math.min(remaining, 0.05);
          widget.system.update(step);
          remaining -= step;
        }
      }
    }
    _lastElapsed = elapsed;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: GpuParticlePainter(
          system: widget.system,
          fragmentShader: widget.fragmentShader,
        ),
        size: Size.infinite,
      ),
    );
  }
}
