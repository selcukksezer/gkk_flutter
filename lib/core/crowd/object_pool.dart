import 'dart:math' as math;
import 'dart:typed_data';

// =============================================================================
// Core Object Pooling Contracts & Exceptions (R4 Zero-GC Architecture)
// =============================================================================

/// Contract for any object that can be stored and recycled inside an [ObjectPool].
///
/// Implements deterministic lifecycle hooks ([onLease], [onRecycle]) and
/// zero-overhead pool tracking via [poolIndex], [leaseSequence], and [isLeased].
abstract class Poolable {
  /// Zero-based slot index inside the owning [ObjectPool].
  ///
  /// Used for O(1) identity validation and bounds verification.
  int get poolIndex;
  set poolIndex(int value);

  /// Incremental sequence ticket assigned upon each lease for FIFO eviction.
  int get leaseSequence;
  set leaseSequence(int value);

  /// Whether this instance is currently leased out of its pool.
  ///
  /// Used for double-release protection and leak detection.
  bool get isLeased;
  set isLeased(bool value);

  /// Invoked immediately after this instance is leased from the pool.
  /// Used to initialize active state before returning to the caller.
  void onLease();

  /// Invoked immediately when this instance is recycled back into the pool.
  /// Must restore all instance properties to clean baseline defaults.
  void onRecycle();
}

/// Abstract base class providing default implementations for [Poolable].
abstract class PoolableBase implements Poolable {
  @override
  int poolIndex = -1;

  @override
  int leaseSequence = 0;

  @override
  bool isLeased = false;

  @override
  void onLease() {}

  @override
  void onRecycle() {}
}

/// Base class for all object pool exceptions.
abstract class ObjectPoolException implements Exception {
  final String message;
  const ObjectPoolException(this.message);

  @override
  String toString() => 'ObjectPoolException: $message';
}

/// Thrown when an object is recycled more than once or recycled while not leased.
class DoubleReleaseException extends ObjectPoolException {
  const DoubleReleaseException(super.message);

  @override
  String toString() => 'DoubleReleaseException: $message';
}

/// Thrown when a fixed-capacity pool runs out of available pre-allocated objects.
class PoolExhaustedException extends ObjectPoolException {
  final int capacity;
  const PoolExhaustedException(super.message, {required this.capacity});

  @override
  String toString() => 'PoolExhaustedException (capacity: $capacity): $message';
}

/// Thrown when an object is returned to a pool that did not create it.
class ForeignObjectException extends ObjectPoolException {
  const ForeignObjectException(super.message);

  @override
  String toString() => 'ForeignObjectException: $message';
}

/// Policy dictating behavior when an [ObjectPool] has zero available items.
enum PoolExhaustionPolicy {
  /// Throws [PoolExhaustedException]. Preferred for deterministic 10K crowd budgeting.
  throwException,

  /// Recycles and reassigns the oldest leased object (FIFO eviction).
  recycleOldest,

  /// Dynamically expands pool capacity by a growth factor (reallocates storage).
  grow,
}

/// Real-time metrics tracked by an [ObjectPool].
class ObjectPoolMetrics {
  final int totalLeases;
  final int totalRecycles;
  final int peakLeased;
  final int currentLeased;
  final int currentAvailable;
  final int capacity;
  final int growCount;

  const ObjectPoolMetrics({
    required this.totalLeases,
    required this.totalRecycles,
    required this.peakLeased,
    required this.currentLeased,
    required this.currentAvailable,
    required this.capacity,
    required this.growCount,
  });

  @override
  String toString() =>
      'ObjectPoolMetrics(leased: $currentLeased/$capacity, peak: $peakLeased, '
      'leases: $totalLeases, recycles: $totalRecycles, grows: $growCount)';
}

// =============================================================================
// Generic Typed ObjectPool<T extends Poolable>
// =============================================================================

/// Generic high-performance, 100% GC-free object pool.
///
/// Complies with R4 specification:
/// 1. Fixed capacity pre-allocation: All [capacity] instances are constructed once up front.
/// 2. Zero per-frame heap allocations during continuous lease / recycle churn loops.
/// 3. Strict double-release protection preventing corrupted pool state.
/// 4. Deterministic reset hooks restoring objects to pristine state upon recycling.
/// 5. O(1) lease and recycle via pointer-indexed contiguous array stack.
class ObjectPool<T extends Poolable> {
  /// Maximum capacity of preallocated objects.
  int _capacity;

  /// Exhaustion policy when all objects are leased.
  final PoolExhaustionPolicy exhaustionPolicy;

  /// Factory function used to instantiate objects during preallocation.
  final T Function(int index) factory;

  /// Optional pool-level reset hook called on recycle after [Poolable.onRecycle].
  final void Function(T object)? onResetHook;

  /// Optional pool-level initialization hook called on lease after [Poolable.onLease].
  final void Function(T object)? onLeaseHook;

  /// Contiguous array stack of available objects ready for leasing.
  late List<T> _availableStack;

  /// Master array of all objects belonging to this pool, indexed by [Poolable.poolIndex].
  late List<T> _allObjects;

  /// Stack pointer representing the number of currently available objects.
  int _availableCount;

  /// Monotonically increasing sequence counter for FIFO oldest-eviction.
  int _leaseSequenceCounter = 0;

  // --- Metrics ---
  int _totalLeases = 0;
  int _totalRecycles = 0;
  int _peakLeased = 0;
  int _growCount = 0;

  ObjectPool({
    required int capacity,
    required this.factory,
    this.exhaustionPolicy = PoolExhaustionPolicy.throwException,
    this.onResetHook,
    this.onLeaseHook,
    bool preallocate = true,
  })  : assert(capacity > 0, 'Pool capacity must be greater than zero'),
        _capacity = capacity,
        _availableCount = preallocate ? capacity : 0 {
    _initializePool(preallocate);
  }

  void _initializePool(bool preallocate) {
    _availableStack = List<T>.generate(_capacity, (i) {
      final obj = factory(i);
      obj.poolIndex = i;
      obj.leaseSequence = 0;
      obj.isLeased = false;
      return obj;
    }, growable: false);

    _allObjects = List<T>.from(_availableStack, growable: false);
    _availableCount = preallocate ? _capacity : 0;
  }

  /// Total capacity of this pool.
  int get capacity => _capacity;

  /// Number of objects currently available to be leased immediately.
  int get availableCount => _availableCount;

  /// Number of objects currently leased out and active.
  int get leasedCount => _capacity - _availableCount;

  /// Whether the pool has zero available objects.
  bool get isExhausted => _availableCount == 0;

  /// Whether all objects are currently in the pool (zero leased).
  bool get isFull => _availableCount == _capacity;

  /// Current metrics snapshot.
  ObjectPoolMetrics get metrics => ObjectPoolMetrics(
        totalLeases: _totalLeases,
        totalRecycles: _totalRecycles,
        peakLeased: _peakLeased,
        currentLeased: leasedCount,
        currentAvailable: _availableCount,
        capacity: _capacity,
        growCount: _growCount,
      );

  /// Leases an object from the pool in O(1) time with ZERO memory allocation.
  ///
  /// Throws [PoolExhaustedException] if pool is empty and policy is [PoolExhaustionPolicy.throwException].
  @pragma('vm:prefer-inline')
  T lease() {
    if (_availableCount == 0) {
      return _handleExhaustion();
    }

    _availableCount--;
    final T obj = _availableStack[_availableCount];

    obj.isLeased = true;
    obj.leaseSequence = ++_leaseSequenceCounter;
    obj.onLease();
    onLeaseHook?.call(obj);

    _totalLeases++;
    final currentLeased = _capacity - _availableCount;
    if (currentLeased > _peakLeased) {
      _peakLeased = currentLeased;
    }

    return obj;
  }

  /// Recycles an active object back into the pool in O(1) time with ZERO memory allocation.
  ///
  /// Strictly enforces double-release and foreign-pool protection:
  /// - Throws [DoubleReleaseException] if [object] was already recycled or not leased.
  /// - Throws [ForeignObjectException] if [object] does not belong to this pool.
  @pragma('vm:prefer-inline')
  void recycle(T object) {
    if (!object.isLeased) {
      throw DoubleReleaseException(
        'Double release detected: object ${object.runtimeType} (poolIndex: ${object.poolIndex}) '
        'is already recycled or was never leased.',
      );
    }

    final int idx = object.poolIndex;
    if (idx < 0 || idx >= _allObjects.length || !identical(_allObjects[idx], object)) {
      throw ForeignObjectException(
        'Attempted to recycle foreign object ${object.runtimeType} into an alien pool.',
      );
    }

    // Execute reset hooks
    object.onRecycle();
    onResetHook?.call(object);

    object.isLeased = false;
    object.leaseSequence = 0;
    _availableStack[_availableCount] = object;
    _availableCount++;
    _totalRecycles++;
  }

  /// Batch leases up to [count] objects into a preallocated [destination] list.
  ///
  /// Does NOT allocate any new lists or wrappers, preserving 0 GC pressure.
  /// Returns the actual number of objects leased.
  int leaseBatch(int count, List<T> destination) {
    final int toLease = math.min(count, _availableCount);
    for (int i = 0; i < toLease; i++) {
      destination.add(lease());
    }
    return toLease;
  }

  /// Batch recycles a collection of active objects back into the pool.
  void recycleBatch(Iterable<T> objects) {
    for (final obj in objects) {
      recycle(obj);
    }
  }

  /// Immediately recycles all currently leased objects and restores the pool
  /// to 100% capacity with ZERO heap allocations.
  void recycleAll() {
    _availableCount = 0;
    for (int i = 0; i < _capacity; i++) {
      final T obj = _allObjects[i];
      if (obj.isLeased) {
        obj.onRecycle();
        onResetHook?.call(obj);
        obj.isLeased = false;
        obj.leaseSequence = 0;
        _totalRecycles++;
      }
      _availableStack[_availableCount++] = obj;
    }
  }

  /// Internal handler when pool is exhausted during a [lease] request.
  T _handleExhaustion() {
    switch (exhaustionPolicy) {
      case PoolExhaustionPolicy.throwException:
        throw PoolExhaustedException(
          'ObjectPool of type $T has no available objects remaining.',
          capacity: _capacity,
        );

      case PoolExhaustionPolicy.recycleOldest:
        // Find the oldest leased object by leaseSequence (FIFO eviction)
        T? oldest;
        int minSeq = 0x7FFFFFFFFFFFFFFF;
        for (int i = 0; i < _capacity; i++) {
          final T candidate = _allObjects[i];
          if (candidate.isLeased && candidate.leaseSequence < minSeq) {
            minSeq = candidate.leaseSequence;
            oldest = candidate;
          }
        }

        if (oldest != null) {
          recycle(oldest);
          return lease();
        }

        throw PoolExhaustedException(
          'Failed to evict candidate from exhausted pool.',
          capacity: _capacity,
        );

      case PoolExhaustionPolicy.grow:
        _growPool();
        return lease();
    }
  }

  /// Expands capacity by doubling it when exhaustion policy is [PoolExhaustionPolicy.grow].
  void _growPool() {
    final int oldCapacity = _capacity;
    final int newCapacity = oldCapacity * 2;

    final List<T> newAvailable = List<T>.generate(newCapacity, (i) {
      if (i < _availableCount) {
        return _availableStack[i];
      } else if (i < oldCapacity) {
        // Leased objects remain in master table
        return factory(i);
      } else {
        final newObj = factory(i);
        newObj.poolIndex = i;
        newObj.leaseSequence = 0;
        newObj.isLeased = false;
        return newObj;
      }
    }, growable: false);

    final List<T> newAll = List<T>.generate(newCapacity, (i) {
      if (i < oldCapacity) {
        return _allObjects[i];
      } else {
        return newAvailable[i];
      }
    }, growable: false);

    // Add newly created slots to available stack
    for (int i = oldCapacity; i < newCapacity; i++) {
      newAvailable[_availableCount++] = newAll[i];
    }

    _availableStack = newAvailable;
    _allObjects = newAll;
    _capacity = newCapacity;
    _growCount++;
  }

  /// Resets all metrics counters to zero.
  void resetMetrics() {
    _totalLeases = 0;
    _totalRecycles = 0;
    _peakLeased = leasedCount;
    _growCount = 0;
  }
}

// =============================================================================
// Specialized Pool 1: CrowdEntity & CrowdEntityPool
// =============================================================================

/// Full-featured 3D Crowd Entity designed for 10,000 concurrent entities.
///
/// Implements [Poolable] with zero-allocation in-place transforms and
/// integration with GPU instancing / VAT Impostor pipelines.
class CrowdEntity implements Poolable {
  @override
  int poolIndex = -1;

  @override
  int leaseSequence = 0;

  @override
  bool isLeased = false;

  /// Unique crowd instance identifier.
  int id = 0;

  /// Character archetype / mesh category (0: soldier, 1: archer, 2: beast, etc.).
  int typeId = 0;

  // --- World Coordinates ---
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;

  // --- Velocity Vector ---
  double vx = 0.0;
  double vy = 0.0;
  double vz = 0.0;

  // --- Orientation (Euler Angles in Radians) ---
  double yaw = 0.0;
  double pitch = 0.0;
  double roll = 0.0;

  // --- 3D Scale ---
  double scaleX = 1.0;
  double scaleY = 1.0;
  double scaleZ = 1.0;

  // --- LOD & Shading State ---
  /// 0: LOD0 Close (<25m), 1: LOD2 Instanced (25-80m), 2: VAT Distant (>80m), 3: Culled.
  int lodTier = 0;

  /// Active animation clip index.
  int animationId = 0;

  /// Current animation timestamp in seconds.
  double animationTime = 0.0;

  /// Playback speed multiplier.
  double animationSpeed = 1.0;

  /// Packed bitfield status (bit 0: active, bit 1: visible, bit 2: inCombat, bit 3: hitReaction).
  int flags = 0;

  /// Vitality points.
  double health = 100.0;
  double maxHealth = 100.0;

  /// Distance to active camera calculated during crowd tick.
  double distanceToCamera = 0.0;

  /// Current spatial hash grid cell occupancy reference.
  int spatialCellIndex = -1;

  /// Contiguous 16-float column-major 4x4 transform matrix preallocated per entity.
  /// Eliminates all matrix allocations when uploading transforms to GPU instances.
  final Float32List transformBuffer = Float32List(16);

  CrowdEntity([this.poolIndex = -1]) {
    _setIdentityMatrix();
  }

  bool get isAlive => (flags & 1) != 0 && health > 0.0;
  bool get isVisible => (flags & 2) != 0;

  void setAlive(bool alive) {
    if (alive) {
      flags |= 1;
    } else {
      flags &= ~1;
    }
  }

  void setVisible(bool visible) {
    if (visible) {
      flags |= 2;
    } else {
      flags &= ~2;
    }
  }

  /// Recomputes 4x4 column-major transformation matrix directly into [transformBuffer].
  ///
  /// Completely GC-free in-place trigonometric evaluation.
  void updateTransformBuffer() {
    final double cosY = math.cos(yaw);
    final double sinY = math.sin(yaw);

    // Column 0: X-axis transformed and scaled
    transformBuffer[0] = cosY * scaleX;
    transformBuffer[1] = 0.0;
    transformBuffer[2] = -sinY * scaleX;
    transformBuffer[3] = 0.0;

    // Column 1: Y-axis transformed and scaled
    transformBuffer[4] = 0.0;
    transformBuffer[5] = scaleY;
    transformBuffer[6] = 0.0;
    transformBuffer[7] = 0.0;

    // Column 2: Z-axis transformed and scaled
    transformBuffer[8] = sinY * scaleZ;
    transformBuffer[9] = 0.0;
    transformBuffer[10] = cosY * scaleZ;
    transformBuffer[11] = 0.0;

    // Column 3: Translation (world position)
    transformBuffer[12] = x;
    transformBuffer[13] = y;
    transformBuffer[14] = z;
    transformBuffer[15] = 1.0;
  }

  /// Copies 16 matrix floats into an external GPU buffer at [offset] with ZERO allocation.
  void copyTransformTo(Float32List target, int offset) {
    target.setRange(offset, offset + 16, transformBuffer);
  }

  /// Copies 8 packed floats into an external VAT / Impostor buffer at [offset].
  /// [x, y, z, yaw, scaleX, animationTime, typeId, flags]
  void copyVatPacketTo(Float32List target, int offset) {
    target[offset] = x;
    target[offset + 1] = y;
    target[offset + 2] = z;
    target[offset + 3] = yaw;
    target[offset + 4] = scaleX;
    target[offset + 5] = animationTime;
    target[offset + 6] = typeId.toDouble();
    target[offset + 7] = flags.toDouble();
  }

  void _setIdentityMatrix() {
    transformBuffer.fillRange(0, 16, 0.0);
    transformBuffer[0] = 1.0;
    transformBuffer[5] = 1.0;
    transformBuffer[10] = 1.0;
    transformBuffer[15] = 1.0;
  }

  @override
  void onLease() {
    flags = 3; // active | visible
    health = 100.0;
    maxHealth = 100.0;
    scaleX = 1.0;
    scaleY = 1.0;
    scaleZ = 1.0;
    animationSpeed = 1.0;
    animationTime = 0.0;
    lodTier = 0;
    distanceToCamera = 0.0;
    spatialCellIndex = -1;
  }

  @override
  void onRecycle() {
    id = 0;
    typeId = 0;
    x = 0.0;
    y = 0.0;
    z = 0.0;
    vx = 0.0;
    vy = 0.0;
    vz = 0.0;
    yaw = 0.0;
    pitch = 0.0;
    roll = 0.0;
    scaleX = 1.0;
    scaleY = 1.0;
    scaleZ = 1.0;
    lodTier = 0;
    animationId = 0;
    animationTime = 0.0;
    animationSpeed = 1.0;
    flags = 0;
    health = 100.0;
    maxHealth = 100.0;
    distanceToCamera = 0.0;
    spatialCellIndex = -1;
    _setIdentityMatrix();
  }
}

/// Specialized pool for [CrowdEntity] instances supporting 10,000+ entities.
class CrowdEntityPool extends ObjectPool<CrowdEntity> {
  CrowdEntityPool({
    super.capacity = 10000,
    super.exhaustionPolicy = PoolExhaustionPolicy.throwException,
    super.onResetHook,
    super.onLeaseHook,
  }) : super(
          factory: (index) => CrowdEntity(index),
        );
}

// =============================================================================
// Specialized Pool 2: ParticleNode & ParticleNodePool
// =============================================================================

/// Lightweight GPU / CPU particle instance for particle systems and combat effects.
class ParticleNode implements Poolable {
  @override
  int poolIndex = -1;

  @override
  int leaseSequence = 0;

  @override
  bool isLeased = false;

  int id = 0;

  /// Particle type (0: spark, 1: smoke, 2: fire, 3: magic, 4: shockwave, 5: blood).
  int particleType = 0;

  // --- World Position ---
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;

  // --- Velocity ---
  double vx = 0.0;
  double vy = 0.0;
  double vz = 0.0;

  // --- Acceleration / Gravity ---
  double ax = 0.0;
  double ay = -9.8;
  double az = 0.0;

  // --- Color & Alpha (RGBA normalized 0.0 to 1.0) ---
  double r = 1.0;
  double g = 1.0;
  double b = 1.0;
  double a = 1.0;

  // --- Life Cycle ---
  double life = 0.0;
  double maxLife = 1.0;

  // --- Scale & Size ---
  double size = 1.0;
  double startSize = 1.0;
  double endSize = 0.0;

  // --- Rotation ---
  double rotation = 0.0;
  double angularVelocity = 0.0;

  // --- Blend Mode (0: alpha, 1: additive, 2: multiply) ---
  int blendMode = 0;

  ParticleNode([this.poolIndex = -1]);

  bool get isAlive => life < maxLife;

  double get normalizedLife =>
      maxLife > 0.0 ? (life / maxLife).clamp(0.0, 1.0) : 1.0;

  /// In-place Euler integration simulation step.
  void step(double dt) {
    vx += ax * dt;
    vy += ay * dt;
    vz += az * dt;

    x += vx * dt;
    y += vy * dt;
    z += vz * dt;

    rotation += angularVelocity * dt;
    life += dt;

    final double t = normalizedLife;
    size = startSize + (endSize - startSize) * t;
    a = (1.0 - t).clamp(0.0, 1.0);
  }

  /// Copies 8 floats into target GPU particle buffer:
  /// [x, y, z, size, r, g, b, a]
  void copyIntoBuffer(Float32List target, int offset) {
    target[offset] = x;
    target[offset + 1] = y;
    target[offset + 2] = z;
    target[offset + 3] = size;
    target[offset + 4] = r;
    target[offset + 5] = g;
    target[offset + 6] = b;
    target[offset + 7] = a;
  }

  @override
  void onLease() {
    life = 0.0;
    maxLife = 1.0;
    size = 1.0;
    startSize = 1.0;
    endSize = 0.0;
    r = 1.0;
    g = 1.0;
    b = 1.0;
    a = 1.0;
    rotation = 0.0;
    angularVelocity = 0.0;
    blendMode = 0;
  }

  @override
  void onRecycle() {
    id = 0;
    particleType = 0;
    x = 0.0;
    y = 0.0;
    z = 0.0;
    vx = 0.0;
    vy = 0.0;
    vz = 0.0;
    ax = 0.0;
    ay = -9.8;
    az = 0.0;
    r = 1.0;
    g = 1.0;
    b = 1.0;
    a = 1.0;
    life = 0.0;
    maxLife = 1.0;
    size = 1.0;
    startSize = 1.0;
    endSize = 0.0;
    rotation = 0.0;
    angularVelocity = 0.0;
    blendMode = 0;
  }
}

/// Specialized pool for [ParticleNode] instances.
class ParticleNodePool extends ObjectPool<ParticleNode> {
  ParticleNodePool({
    super.capacity = 5000,
    super.exhaustionPolicy = PoolExhaustionPolicy.recycleOldest,
    super.onResetHook,
    super.onLeaseHook,
  }) : super(
          factory: (index) => ParticleNode(index),
        );
}

// =============================================================================
// Specialized Pool 3: DecalInstance & DecalInstancePool
// =============================================================================

/// Dynamic ground decal projection instance (scorch marks, blood, fissures, slashes).
class DecalInstance implements Poolable {
  @override
  int poolIndex = -1;

  @override
  int leaseSequence = 0;

  @override
  bool isLeased = false;

  int id = 0;

  /// Decal type (0: scorchMark, 1: bloodSplatter, 2: crackedEarth, 3: slashGouge, 4: custom).
  int decalType = 0;

  // --- World Position & Normal ---
  double x = 0.0;
  double y = 0.0;
  double z = 0.0;

  double nx = 0.0;
  double ny = 1.0;
  double nz = 0.0;

  // --- Orientation Quaternion (qx, qy, qz, qw) ---
  double qx = 0.0;
  double qy = 0.0;
  double qz = 0.0;
  double qw = 1.0;

  // --- Bounding Box Dimensions ---
  double sizeX = 2.0;
  double sizeY = 2.0;
  double sizeZ = 1.0;

  // --- Tint Color ---
  double r = 1.0;
  double g = 1.0;
  double b = 1.0;

  // --- Opacity & Fade ---
  double baseOpacity = 1.0;
  double currentOpacity = 1.0;

  // --- PBR Material Properties ---
  double roughness = 0.5;
  double normalStrength = 1.0;
  double metallic = 0.0;

  // --- Timing ---
  double totalLifetime = 10.0;
  double elapsedTime = 0.0;
  double fadeDuration = 3.0;

  // --- Shading Controls ---
  int fadeCurve = 1; // 0: linear, 1: smoothStep, 2: quadratic
  int blendMode = 0; // 0: alphaBlend, 1: modulate, 2: additive
  double angleCutoff = 0.35;
  double edgeSoftness = 0.15;

  /// Preallocated 4x4 matrix for projection calculations.
  final Float32List worldToLocalMatrix = Float32List(16);

  DecalInstance([this.poolIndex = -1]) {
    _setIdentityMatrix();
  }

  bool get isExpired => elapsedTime >= totalLifetime;

  void _setIdentityMatrix() {
    worldToLocalMatrix.fillRange(0, 16, 0.0);
    worldToLocalMatrix[0] = 1.0;
    worldToLocalMatrix[5] = 1.0;
    worldToLocalMatrix[10] = 1.0;
    worldToLocalMatrix[15] = 1.0;
  }

  /// Updates simulation timer and computes fade curve opacity.
  void update(double dt) {
    if (!isLeased || isExpired) return;

    elapsedTime += dt;
    if (elapsedTime >= totalLifetime) {
      currentOpacity = 0.0;
      return;
    }

    final double remaining = totalLifetime - elapsedTime;
    if (remaining < fadeDuration && fadeDuration > 0.0) {
      final double progress = (remaining / fadeDuration).clamp(0.0, 1.0);
      switch (fadeCurve) {
        case 0: // linear
          currentOpacity = baseOpacity * progress;
          break;
        case 1: // smoothStep
          final double t = progress;
          final double smooth = t * t * (3.0 - 2.0 * t);
          currentOpacity = baseOpacity * smooth;
          break;
        case 2: // quadratic
          currentOpacity = baseOpacity * (progress * progress);
          break;
        default:
          currentOpacity = baseOpacity * progress;
          break;
      }
    } else {
      currentOpacity = baseOpacity;
    }
  }

  @override
  void onLease() {
    elapsedTime = 0.0;
    totalLifetime = 10.0;
    fadeDuration = 3.0;
    baseOpacity = 1.0;
    currentOpacity = 1.0;
    roughness = 0.5;
    normalStrength = 1.0;
    metallic = 0.0;
    fadeCurve = 1;
    blendMode = 0;
    angleCutoff = 0.35;
    edgeSoftness = 0.15;
  }

  @override
  void onRecycle() {
    id = 0;
    decalType = 0;
    x = 0.0;
    y = 0.0;
    z = 0.0;
    nx = 0.0;
    ny = 1.0;
    nz = 0.0;
    qx = 0.0;
    qy = 0.0;
    qz = 0.0;
    qw = 1.0;
    sizeX = 2.0;
    sizeY = 2.0;
    sizeZ = 1.0;
    r = 1.0;
    g = 1.0;
    b = 1.0;
    baseOpacity = 1.0;
    currentOpacity = 1.0;
    roughness = 0.5;
    normalStrength = 1.0;
    metallic = 0.0;
    totalLifetime = 10.0;
    elapsedTime = 0.0;
    fadeDuration = 3.0;
    fadeCurve = 1;
    blendMode = 0;
    angleCutoff = 0.35;
    edgeSoftness = 0.15;
    _setIdentityMatrix();
  }
}

/// Specialized pool for [DecalInstance] projections.
class DecalInstancePool extends ObjectPool<DecalInstance> {
  DecalInstancePool({
    super.capacity = 1000,
    super.exhaustionPolicy = PoolExhaustionPolicy.recycleOldest,
    super.onResetHook,
    super.onLeaseHook,
  }) : super(
          factory: (index) => DecalInstance(index),
        );
}

// =============================================================================
// Specialized Pool 4: Matrix4Buffer & Matrix4BufferPool
// =============================================================================

/// Pooled 4x4 Transformation Matrix with contiguous [Float32List] storage.
///
/// Avoids the severe GC penalties of instantiating thousands of temporary
/// Matrix4 objects per frame during 10,000 crowd coordinate calculations.
class Matrix4Buffer implements Poolable {
  @override
  int poolIndex = -1;

  @override
  int leaseSequence = 0;

  @override
  bool isLeased = false;

  /// Internal 16-element column-major float array.
  final Float32List storage = Float32List(16);

  Matrix4Buffer([this.poolIndex = -1]) {
    setIdentity();
  }

  /// Sets this matrix to the 4x4 identity matrix.
  @pragma('vm:prefer-inline')
  void setIdentity() {
    storage[0] = 1.0;
    storage[1] = 0.0;
    storage[2] = 0.0;
    storage[3] = 0.0;

    storage[4] = 0.0;
    storage[5] = 1.0;
    storage[6] = 0.0;
    storage[7] = 0.0;

    storage[8] = 0.0;
    storage[9] = 0.0;
    storage[10] = 1.0;
    storage[11] = 0.0;

    storage[12] = 0.0;
    storage[13] = 0.0;
    storage[14] = 0.0;
    storage[15] = 1.0;
  }

  /// Zeroes all 16 matrix elements.
  @pragma('vm:prefer-inline')
  void setZero() {
    storage.fillRange(0, 16, 0.0);
  }

  /// Sets pure translation matrix.
  void setTranslation(double tx, double ty, double tz) {
    setIdentity();
    storage[12] = tx;
    storage[13] = ty;
    storage[14] = tz;
  }

  /// Sets pure scaling matrix.
  void setScale(double sx, double sy, double sz) {
    setZero();
    storage[0] = sx;
    storage[5] = sy;
    storage[10] = sz;
    storage[15] = 1.0;
  }

  /// Sets rotation around Y axis (yaw).
  void setRotationY(double radians) {
    setIdentity();
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    storage[0] = c;
    storage[2] = -s;
    storage[8] = s;
    storage[10] = c;
  }

  /// In-place composition of translation, yaw rotation, and scale with ZERO allocations.
  void compose({
    double tx = 0.0,
    double ty = 0.0,
    double tz = 0.0,
    double yaw = 0.0,
    double sx = 1.0,
    double sy = 1.0,
    double sz = 1.0,
  }) {
    final double c = math.cos(yaw);
    final double s = math.sin(yaw);

    storage[0] = c * sx;
    storage[1] = 0.0;
    storage[2] = -s * sx;
    storage[3] = 0.0;

    storage[4] = 0.0;
    storage[5] = sy;
    storage[6] = 0.0;
    storage[7] = 0.0;

    storage[8] = s * sz;
    storage[9] = 0.0;
    storage[10] = c * sz;
    storage[11] = 0.0;

    storage[12] = tx;
    storage[13] = ty;
    storage[14] = tz;
    storage[15] = 1.0;
  }

  /// Multiplies matrix [a] by matrix [b] and writes result into this matrix.
  ///
  /// Completely GC-free in-place GEMM implementation.
  void multiply(Matrix4Buffer a, Matrix4Buffer b) {
    final Float32List as = a.storage;
    final Float32List bs = b.storage;

    for (int col = 0; col < 4; col++) {
      final int bCol = col * 4;
      final double b0 = bs[bCol];
      final double b1 = bs[bCol + 1];
      final double b2 = bs[bCol + 2];
      final double b3 = bs[bCol + 3];

      storage[bCol] = as[0] * b0 + as[4] * b1 + as[8] * b2 + as[12] * b3;
      storage[bCol + 1] = as[1] * b0 + as[5] * b1 + as[9] * b2 + as[13] * b3;
      storage[bCol + 2] = as[2] * b0 + as[6] * b1 + as[10] * b2 + as[14] * b3;
      storage[bCol + 3] = as[3] * b0 + as[7] * b1 + as[11] * b2 + as[15] * b3;
    }
  }

  /// Copies 16 floats from [source] starting at [offset].
  void copyFrom(Float32List source, [int offset = 0]) {
    storage.setRange(0, 16, source, offset);
  }

  /// Copies 16 floats into [target] starting at [offset].
  void copyInto(Float32List target, [int offset = 0]) {
    target.setRange(offset, offset + 16, storage);
  }

  /// Gets element at 0-based [row] and [col].
  double get(int row, int col) => storage[col * 4 + row];

  /// Sets element at 0-based [row] and [col].
  void set(int row, int col, double val) {
    storage[col * 4 + row] = val;
  }

  @override
  void onLease() {
    setIdentity();
  }

  @override
  void onRecycle() {
    setIdentity();
  }
}

/// Specialized pool for [Matrix4Buffer] objects.
class Matrix4BufferPool extends ObjectPool<Matrix4Buffer> {
  Matrix4BufferPool({
    super.capacity = 10000,
    super.exhaustionPolicy = PoolExhaustionPolicy.throwException,
    super.onResetHook,
    super.onLeaseHook,
  }) : super(
          factory: (index) => Matrix4Buffer(index),
        );
}

// =============================================================================
// Specialized Pool 5: Float32BufferPool (GPU Stride Buffers)
// =============================================================================

/// Pooled contiguous [Float32List] buffer wrapper implementing [Poolable].
class PooledFloat32Buffer implements Poolable {
  @override
  int poolIndex = -1;

  @override
  int leaseSequence = 0;

  @override
  bool isLeased = false;

  /// Internal float array.
  final Float32List buffer;

  PooledFloat32Buffer(int size, [this.poolIndex = -1])
      : buffer = Float32List(size);

  int get length => buffer.length;

  void zero() {
    buffer.fillRange(0, buffer.length, 0.0);
  }

  @override
  void onLease() {
    zero();
  }

  @override
  void onRecycle() {
    zero();
  }
}

/// Pool of reusable [Float32List] scratch arrays with fixed size.
class Float32BufferPool extends ObjectPool<PooledFloat32Buffer> {
  final int bufferSize;

  Float32BufferPool({
    required super.capacity,
    required this.bufferSize,
    super.exhaustionPolicy = PoolExhaustionPolicy.throwException,
    super.onResetHook,
    super.onLeaseHook,
  }) : super(
          factory: (index) => PooledFloat32Buffer(bufferSize, index),
        );
}

// =============================================================================
// Central Object Pool Registry (Singleton Manager)
// =============================================================================

/// Centralized manager coordinating all crowd, VFX, and math object pools.
///
/// Provides single-point access, lifecycle coordination, and metrics profiling.
class ObjectPoolRegistry {
  static ObjectPoolRegistry? _instance;

  /// Global singleton instance.
  static ObjectPoolRegistry get instance =>
      _instance ??= ObjectPoolRegistry._internal();

  /// Resets or replaces the singleton instance (useful for test isolation).
  static void resetInstance() {
    _instance?.recycleAll();
    _instance = null;
  }

  final CrowdEntityPool crowdEntityPool;
  final ParticleNodePool particlePool;
  final DecalInstancePool decalPool;
  final Matrix4BufferPool matrixPool;

  ObjectPoolRegistry._internal({
    int crowdCapacity = 10000,
    int particleCapacity = 5000,
    int decalCapacity = 1000,
    int matrixCapacity = 10000,
  })  : crowdEntityPool = CrowdEntityPool(capacity: crowdCapacity),
        particlePool = ParticleNodePool(capacity: particleCapacity),
        decalPool = DecalInstancePool(capacity: decalCapacity),
        matrixPool = Matrix4BufferPool(capacity: matrixCapacity);

  /// Factory constructor allowing custom initial capacities.
  factory ObjectPoolRegistry({
    int crowdCapacity = 10000,
    int particleCapacity = 5000,
    int decalCapacity = 1000,
    int matrixCapacity = 10000,
  }) {
    final reg = ObjectPoolRegistry._internal(
      crowdCapacity: crowdCapacity,
      particleCapacity: particleCapacity,
      decalCapacity: decalCapacity,
      matrixCapacity: matrixCapacity,
    );
    _instance = reg;
    return reg;
  }

  /// Recycles all active objects across all registered pools.
  void recycleAll() {
    crowdEntityPool.recycleAll();
    particlePool.recycleAll();
    decalPool.recycleAll();
    matrixPool.recycleAll();
  }

  /// Collects metrics from all pools for performance auditing.
  Map<String, ObjectPoolMetrics> getMetricsSummary() => {
        'CrowdEntities': crowdEntityPool.metrics,
        'Particles': particlePool.metrics,
        'Decals': decalPool.metrics,
        'Matrices': matrixPool.metrics,
      };
}
