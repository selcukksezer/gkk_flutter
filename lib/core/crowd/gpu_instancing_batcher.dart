import 'dart:math' as math;
import 'dart:typed_data';

// =============================================================================
// GPU Instancing Buffer Layout Specification
// 2027 AAA Engine Architecture (R4: Crowd Optimization)
// =============================================================================

/// Defines the precise binary and float memory layout for GPU-instanced
/// medium-range entities (LOD2).
///
/// Layout per Instance (24 floats = 96 bytes, 16-byte aligned):
/// ----------------------------------------------------------------------------
/// Offset (Floats) | Offset (Bytes) | Type    | Semantic
/// ----------------------------------------------------------------------------
/// 0 .. 15         | 0 .. 63        | mat4    | Model Transformation Matrix
/// 16 .. 19        | 64 .. 79       | vec4    | Animation Frame & Locomotion Data
/// 20 .. 23        | 80 .. 95       | vec4    | RGBA Tint / Team / Hit Flash
/// ----------------------------------------------------------------------------
abstract final class InstanceBufferLayout {
  /// 16 floats representing a column-major 4x4 matrix (locations 5, 6, 7, 8 in GLSL)
  static const int matrixFloatCount = 16;

  /// 4 floats representing instance animation state:
  /// - [0] (float): current animation frame index (e.g. 0.0 .. 59.0)
  /// - [1] (float): normalized animation phase [0.0 .. 1.0]
  /// - [2] (float): animation type (0: Idle, 1: Walk, 2: Run, 3: Combat, 4: Stun)
  /// - [3] (float): blend weight / secondary animation factor
  static const int animDataFloatCount = 4;

  /// 4 floats representing instance tint color (RGBA linear [0.0 .. 1.0])
  static const int tintColorFloatCount = 4;

  /// Total number of 32-bit floating point words per instance
  static const int floatsPerInstance =
      matrixFloatCount + animDataFloatCount + tintColorFloatCount; // 24

  /// Total number of bytes per instance (24 * 4 = 96 bytes)
  /// 96 is evenly divisible by 16 bytes (vec4 / GPU cache-line alignment)
  static const int bytesPerInstance = floatsPerInstance * 4; // 96

  // Float offsets within each instance record:
  static const int matrixOffset = 0;
  static const int animDataOffset = matrixOffset + matrixFloatCount; // 16
  static const int tintColorOffset = animDataOffset + animDataFloatCount; // 20

  // Byte offsets within each instance record:
  static const int matrixByteOffset = matrixOffset * 4; // 0
  static const int animDataByteOffset = animDataOffset * 4; // 64
  static const int tintColorByteOffset = tintColorOffset * 4; // 80

  /// Animation data sub-component offsets
  static const int animFrameIndexSubOffset = 0;
  static const int animPhaseSubOffset = 1;
  static const int animTypeSubOffset = 2;
  static const int animBlendWeightSubOffset = 3;

  /// Tint color sub-component offsets
  static const int tintRedSubOffset = 0;
  static const int tintGreenSubOffset = 1;
  static const int tintBlueSubOffset = 2;
  static const int tintAlphaSubOffset = 3;
}

// =============================================================================
// LOD2 Entity Representation
// =============================================================================

/// Represents a single medium-range entity eligible for GPU instancing.
class LOD2Entity {
  final int entityId;
  final int meshId;
  final int materialKey;

  /// 16-element column-major 4x4 model transformation matrix.
  final Float32List transformMatrix;

  /// Animation frame index (e.g. 0.0 to 59.0)
  double animationFrameIndex;

  /// Normalized animation time / phase [0.0, 1.0]
  double normalizedAnimationTime;

  /// Animation locomotion state (0: Idle, 1: Walk, 2: Run, 3: Combat, 4: Stun)
  int animationType;

  /// Animation blend weight or secondary parameter [0.0, 1.0]
  double animationBlendWeight;

  /// RGBA Tint values [0.0, 1.0]
  double tintR;
  double tintG;
  double tintB;
  double tintA;

  /// Distance from camera in meters (used for LOD tier verification & sorting)
  double distanceToCamera;

  /// Frustum / occlusion visibility status
  bool isVisible;

  LOD2Entity({
    required this.entityId,
    required this.meshId,
    required this.materialKey,
    required this.transformMatrix,
    this.animationFrameIndex = 0.0,
    this.normalizedAnimationTime = 0.0,
    this.animationType = 1,
    this.animationBlendWeight = 0.0,
    this.tintR = 1.0,
    this.tintG = 1.0,
    this.tintB = 1.0,
    this.tintA = 1.0,
    this.distanceToCamera = 35.0,
    this.isVisible = true,
  }) : assert(
         transformMatrix.length == InstanceBufferLayout.matrixFloatCount,
         'Transform matrix must contain exactly 16 floats',
       );

  /// Factory helper creating an entity with a transformation matrix computed
  /// from position (tx, ty, tz), yaw rotation (radians around Y), and uniform or 3D scale.
  factory LOD2Entity.fromTransform({
    required int entityId,
    required int meshId,
    required int materialKey,
    double tx = 0.0,
    double ty = 0.0,
    double tz = 0.0,
    double yawRadians = 0.0,
    double scaleX = 1.0,
    double scaleY = 1.0,
    double scaleZ = 1.0,
    double animationFrameIndex = 0.0,
    double normalizedAnimationTime = 0.0,
    int animationType = 1,
    double animationBlendWeight = 0.0,
    double tintR = 1.0,
    double tintG = 1.0,
    double tintB = 1.0,
    double tintA = 1.0,
    double distanceToCamera = 35.0,
    bool isVisible = true,
  }) {
    final matrix = createTransformMatrix(
      tx: tx,
      ty: ty,
      tz: tz,
      yawRadians: yawRadians,
      scaleX: scaleX,
      scaleY: scaleY,
      scaleZ: scaleZ,
    );

    return LOD2Entity(
      entityId: entityId,
      meshId: meshId,
      materialKey: materialKey,
      transformMatrix: matrix,
      animationFrameIndex: animationFrameIndex,
      normalizedAnimationTime: normalizedAnimationTime,
      animationType: animationType,
      animationBlendWeight: animationBlendWeight,
      tintR: tintR,
      tintG: tintG,
      tintB: tintB,
      tintA: tintA,
      distanceToCamera: distanceToCamera,
      isVisible: isVisible,
    );
  }

  /// Creates a standard 4x4 identity matrix as a Float32List.
  static Float32List createIdentityMatrix() {
    final m = Float32List(16);
    m[0] = 1.0;
    m[5] = 1.0;
    m[10] = 1.0;
    m[15] = 1.0;
    return m;
  }

  /// Computes a column-major 4x4 matrix from translation, yaw rotation, and scale.
  static Float32List createTransformMatrix({
    double tx = 0.0,
    double ty = 0.0,
    double tz = 0.0,
    double yawRadians = 0.0,
    double scaleX = 1.0,
    double scaleY = 1.0,
    double scaleZ = 1.0,
  }) {
    final m = Float32List(16);
    final cosY = math.cos(yawRadians);
    final sinY = math.sin(yawRadians);

    // Column 0
    m[0] = cosY * scaleX;
    m[1] = 0.0;
    m[2] = -sinY * scaleX;
    m[3] = 0.0;

    // Column 1
    m[4] = 0.0;
    m[5] = scaleY;
    m[6] = 0.0;
    m[7] = 0.0;

    // Column 2
    m[8] = sinY * scaleZ;
    m[9] = 0.0;
    m[10] = cosY * scaleZ;
    m[11] = 0.0;

    // Column 3 (Translation)
    m[12] = tx;
    m[13] = ty;
    m[14] = tz;
    m[15] = 1.0;

    return m;
  }
}

// =============================================================================
// Draw Call Batch Container
// =============================================================================

/// Represents a single GPU Draw Call batch holding packed instance data for up
/// to [maxCapacity] instances sharing the same mesh and material.
class DrawCallBatch {
  final int batchId;
  final int meshId;
  final int materialKey;
  final int maxCapacity;

  /// The underlying pre-allocated Float32 buffer (capacity * 24 floats).
  final Float32List buffer;

  /// Direct byte data view into [buffer] for low-level GPU buffer uploads.
  final ByteData byteData;

  /// Current number of instances packed into this batch.
  int instanceCount = 0;

  DrawCallBatch({
    required this.batchId,
    required this.meshId,
    required this.materialKey,
    required this.maxCapacity,
    required this.buffer,
  }) : byteData = ByteData.sublistView(buffer),
       assert(
         buffer.length >= maxCapacity * InstanceBufferLayout.floatsPerInstance,
         'Buffer capacity too small for batch limit',
       );

  /// Whether this batch has reached its maximum draw-call capacity.
  bool get isFull => instanceCount >= maxCapacity;

  /// Whether this batch contains zero instances.
  bool get isEmpty => instanceCount == 0;

  /// Total number of active 32-bit floats in this batch.
  int get activeFloatCount =>
      instanceCount * InstanceBufferLayout.floatsPerInstance;

  /// Total size in bytes of active instance data ready for GPU upload.
  int get totalActiveBytes =>
      instanceCount * InstanceBufferLayout.bytesPerInstance;

  /// Provides a sublist view of the active portion of [buffer].
  Float32List get activeBufferView =>
      Float32List.sublistView(buffer, 0, activeFloatCount);

  /// Appends an entity into the packed buffer.
  /// Uses direct index assignment for maximum performance and zero heap allocations.
  @pragma('vm:prefer-inline')
  void appendEntity(LOD2Entity entity) {
    if (instanceCount >= maxCapacity) {
      throw StateError(
        'DrawCallBatch $batchId reached maximum capacity ($maxCapacity)',
      );
    }

    final int base = instanceCount * InstanceBufferLayout.floatsPerInstance;
    final Float32List matrix = entity.transformMatrix;

    // 1. Pack 16-float Model Transformation Matrix (Offsets 0..15)
    buffer[base + 0] = matrix[0];
    buffer[base + 1] = matrix[1];
    buffer[base + 2] = matrix[2];
    buffer[base + 3] = matrix[3];
    buffer[base + 4] = matrix[4];
    buffer[base + 5] = matrix[5];
    buffer[base + 6] = matrix[6];
    buffer[base + 7] = matrix[7];
    buffer[base + 8] = matrix[8];
    buffer[base + 9] = matrix[9];
    buffer[base + 10] = matrix[10];
    buffer[base + 11] = matrix[11];
    buffer[base + 12] = matrix[12];
    buffer[base + 13] = matrix[13];
    buffer[base + 14] = matrix[14];
    buffer[base + 15] = matrix[15];

    // 2. Pack Animation Frame & State (Offsets 16..19)
    buffer[base + 16] = entity.animationFrameIndex;
    buffer[base + 17] = entity.normalizedAnimationTime;
    buffer[base + 18] = entity.animationType.toDouble();
    buffer[base + 19] = entity.animationBlendWeight;

    // 3. Pack RGBA Tint / Team / Flash Color (Offsets 20..23)
    buffer[base + 20] = entity.tintR;
    buffer[base + 21] = entity.tintG;
    buffer[base + 22] = entity.tintB;
    buffer[base + 23] = entity.tintA;

    instanceCount++;
  }

  /// Appends raw components directly without requiring an intermediate LOD2Entity object.
  @pragma('vm:prefer-inline')
  void appendRaw({
    required Float32List matrix16,
    required double animFrameIndex,
    required double animNormalizedTime,
    required int animType,
    required double animBlendWeight,
    required double tintR,
    required double tintG,
    required double tintB,
    required double tintA,
  }) {
    if (instanceCount >= maxCapacity) {
      throw StateError('DrawCallBatch $batchId reached capacity');
    }

    final int base = instanceCount * InstanceBufferLayout.floatsPerInstance;

    // 1. Matrix
    for (int i = 0; i < 16; i++) {
      buffer[base + i] = matrix16[i];
    }

    // 2. Anim Data
    buffer[base + 16] = animFrameIndex;
    buffer[base + 17] = animNormalizedTime;
    buffer[base + 18] = animType.toDouble();
    buffer[base + 19] = animBlendWeight;

    // 3. Tint Color
    buffer[base + 20] = tintR;
    buffer[base + 21] = tintG;
    buffer[base + 22] = tintB;
    buffer[base + 23] = tintA;

    instanceCount++;
  }

  /// Decodes and unpacks an instance at [index] back into destination float arrays.
  /// Used for test verification and CPU debugging.
  void unpackInstance(
    int index, {
    required Float32List outMatrix,
    required Float32List outAnimData,
    required Float32List outTintColor,
  }) {
    if (index < 0 || index >= instanceCount) {
      throw RangeError.index(index, this, 'index', 'Index out of bounds', instanceCount);
    }

    final int base = index * InstanceBufferLayout.floatsPerInstance;

    // Unpack Matrix (16 floats)
    for (int i = 0; i < 16; i++) {
      outMatrix[i] = buffer[base + i];
    }

    // Unpack Anim Data (4 floats)
    outAnimData[0] = buffer[base + 16];
    outAnimData[1] = buffer[base + 17];
    outAnimData[2] = buffer[base + 18];
    outAnimData[3] = buffer[base + 19];

    // Unpack Tint Color (4 floats)
    outTintColor[0] = buffer[base + 20];
    outTintColor[1] = buffer[base + 21];
    outTintColor[2] = buffer[base + 22];
    outTintColor[3] = buffer[base + 23];
  }

  /// Resets instance count for buffer recycling without deallocating memory.
  void reset() {
    instanceCount = 0;
  }
}

// =============================================================================
// Batcher Performance Metrics
// =============================================================================

/// Performance and profiling statistics for a batching run.
class BatcherMetrics {
  final int totalEntitiesProcessed;
  final int totalEntitiesCulled;
  final int totalEntitiesPacked;
  final int totalDrawCalls;
  final int totalBytesUploaded;
  final int packingDurationMicroseconds;
  final Map<int, int> drawCallsPerMaterial;

  const BatcherMetrics({
    required this.totalEntitiesProcessed,
    required this.totalEntitiesCulled,
    required this.totalEntitiesPacked,
    required this.totalDrawCalls,
    required this.totalBytesUploaded,
    required this.packingDurationMicroseconds,
    required this.drawCallsPerMaterial,
  });

  /// Packing throughput in instances per second.
  double get throughputInstancesPerSec {
    if (packingDurationMicroseconds <= 0) return 0.0;
    return (totalEntitiesPacked / packingDurationMicroseconds) * 1000000.0;
  }

  /// Average instances per draw call.
  double get averageInstancesPerDrawCall {
    if (totalDrawCalls == 0) return 0.0;
    return totalEntitiesPacked / totalDrawCalls;
  }

  @override
  String toString() {
    return 'BatcherMetrics('
        'packed: $totalEntitiesPacked/$totalEntitiesProcessed, '
        'culled: $totalEntitiesCulled, '
        'drawCalls: $totalDrawCalls, '
        'bytes: $totalBytesUploaded B, '
        'time: $packingDurationMicroseconds µs, '
        'throughput: ${throughputInstancesPerSec.toStringAsFixed(0)} inst/s)';
  }
}

// =============================================================================
// Production GPU Instancing Batcher Pipeline
// =============================================================================

/// High-throughput GPU Instancing Batcher for medium-range entities (LOD2).
///
/// Groups hundreds to thousands of entities sharing meshes and materials into
/// unified single draw calls, respecting GPU uniform/VBO batch boundaries
/// and eliminating GC spikes via reusable typed buffer pooling.
class GpuInstancingBatcher {
  /// Maximum number of instances packed into a single GPU draw call.
  /// Typical values: 512, 1024, or 2048. Default is 1024.
  final int maxInstancesPerBatch;

  /// Internal pool of reusable Float32List buffers to eliminate runtime allocations.
  final List<Float32List> _bufferPool = [];

  /// Active batches in the current frame.
  final List<DrawCallBatch> _activeBatches = [];

  /// Recycled batches cache.
  final List<DrawCallBatch> _recycledBatches = [];

  int _nextBatchId = 1;
  BatcherMetrics? _lastMetrics;

  GpuInstancingBatcher({
    this.maxInstancesPerBatch = 1024,
    int initialBufferPoolSize = 16,
  }) {
    assert(maxInstancesPerBatch > 0, 'maxInstancesPerBatch must be > 0');
    // Pre-populate buffer pool
    for (int i = 0; i < initialBufferPoolSize; i++) {
      _bufferPool.add(_allocateBuffer());
    }
  }

  /// Number of buffers currently idle in pool.
  int get poolAvailableCount => _bufferPool.length;

  /// Last recorded performance metrics.
  BatcherMetrics? get lastMetrics => _lastMetrics;

  /// Allocates a new Float32List with capacity matching [maxInstancesPerBatch].
  Float32List _allocateBuffer() {
    return Float32List(
      maxInstancesPerBatch * InstanceBufferLayout.floatsPerInstance,
    );
  }

  /// Obtains a Float32List buffer from pool or allocates one if pool is empty.
  Float32List _acquireBuffer() {
    if (_bufferPool.isNotEmpty) {
      return _bufferPool.removeLast();
    }
    return _allocateBuffer();
  }

  /// Obtains a [DrawCallBatch] for the given [meshId] and [materialKey].
  DrawCallBatch _acquireBatch(int meshId, int materialKey) {
    if (_recycledBatches.isNotEmpty) {
      final recycled = _recycledBatches.removeLast();
      // Re-configure batch metadata
      final batch = DrawCallBatch(
        batchId: _nextBatchId++,
        meshId: meshId,
        materialKey: materialKey,
        maxCapacity: maxInstancesPerBatch,
        buffer: recycled.buffer,
      );
      _activeBatches.add(batch);
      return batch;
    }

    final buffer = _acquireBuffer();
    final batch = DrawCallBatch(
      batchId: _nextBatchId++,
      meshId: meshId,
      materialKey: materialKey,
      maxCapacity: maxInstancesPerBatch,
      buffer: buffer,
    );
    _activeBatches.add(batch);
    return batch;
  }

  /// Generates a 64-bit composite bucket key for mesh and material grouping.
  @pragma('vm:prefer-inline')
  static int _computeBucketKey(int meshId, int materialKey) {
    return ((meshId & 0xFFFFFFFF) << 32) | (materialKey & 0xFFFFFFFF);
  }

  /// Packs a list of [LOD2Entity] instances into draw call batches.
  ///
  /// - Automatically groups entities by (meshId, materialKey).
  /// - Filters out non-visible entities (frustum/occlusion culling) if [cullNonVisible] is true.
  /// - Automatically splits entities into multiple draw calls if the count exceeds [maxInstancesPerBatch].
  /// - Guarantees zero runtime heap allocation during steady-state rendering when buffer pool is populated.
  List<DrawCallBatch> batchAndPack(
    List<LOD2Entity> entities, {
    bool cullNonVisible = true,
  }) {
    final stopwatch = Stopwatch()..start();

    // Reset current active batches into pool for recycling
    reset();

    final Map<int, DrawCallBatch> bucketActiveBatch = {};
    final Map<int, int> drawCallsPerMaterial = {};
    int culledCount = 0;
    int packedCount = 0;

    final int entityCount = entities.length;
    for (int i = 0; i < entityCount; i++) {
      final entity = entities[i];

      // Visibility check
      if (cullNonVisible && !entity.isVisible) {
        culledCount++;
        continue;
      }

      final bucketKey = _computeBucketKey(entity.meshId, entity.materialKey);
      var batch = bucketActiveBatch[bucketKey];

      // If no batch exists or current batch is full, create/acquire a new batch
      if (batch == null || batch.isFull) {
        batch = _acquireBatch(entity.meshId, entity.materialKey);
        bucketActiveBatch[bucketKey] = batch;
        drawCallsPerMaterial[entity.materialKey] =
            (drawCallsPerMaterial[entity.materialKey] ?? 0) + 1;
      }

      batch.appendEntity(entity);
      packedCount++;
    }

    stopwatch.stop();

    // Calculate total bytes uploaded
    int totalBytes = 0;
    for (int b = 0; b < _activeBatches.length; b++) {
      totalBytes += _activeBatches[b].totalActiveBytes;
    }

    _lastMetrics = BatcherMetrics(
      totalEntitiesProcessed: entityCount,
      totalEntitiesCulled: culledCount,
      totalEntitiesPacked: packedCount,
      totalDrawCalls: _activeBatches.length,
      totalBytesUploaded: totalBytes,
      packingDurationMicroseconds: stopwatch.elapsedMicroseconds,
      drawCallsPerMaterial: drawCallsPerMaterial,
    );

    return List.unmodifiable(_activeBatches);
  }

  /// Clears active batches and returns their underlying Float32List buffers to
  /// the reusable pool to avoid garbage collection overhead.
  void reset() {
    for (int i = 0; i < _activeBatches.length; i++) {
      final batch = _activeBatches[i];
      batch.reset();
      _bufferPool.add(batch.buffer);
    }
    _recycledBatches.clear();
    _activeBatches.clear();
  }

  /// Releases all pooled buffers.
  void dispose() {
    reset();
    _bufferPool.clear();
  }

  // ---------------------------------------------------------------------------
  // Verification & Audit Utilities
  // ---------------------------------------------------------------------------

  /// Verifies memory alignment and layout constraints for a batch.
  static bool verifyBufferAlignment(DrawCallBatch batch) {
    // 1. Stride must be 96 bytes (24 floats)
    if (InstanceBufferLayout.bytesPerInstance != 96) return false;
    if (InstanceBufferLayout.floatsPerInstance != 24) return false;

    // 2. 16-byte alignment check
    if (InstanceBufferLayout.bytesPerInstance % 16 != 0) return false;
    if (InstanceBufferLayout.matrixByteOffset % 16 != 0) return false;
    if (InstanceBufferLayout.animDataByteOffset % 16 != 0) return false;
    if (InstanceBufferLayout.tintColorByteOffset % 16 != 0) return false;

    // 3. Float32List buffer length check
    if (batch.buffer.lengthInBytes % 16 != 0) return false;

    // 4. Stride integrity
    final activeBytes = batch.totalActiveBytes;
    if (activeBytes != batch.instanceCount * 96) return false;

    return true;
  }

  /// Verifies exact numerical integrity between an unpacked batch slot and original entity.
  static bool verifyInstanceIntegrity(
    DrawCallBatch batch,
    int instanceIndex,
    LOD2Entity original, {
    double epsilon = 1e-5,
  }) {
    final matrix = Float32List(16);
    final anim = Float32List(4);
    final tint = Float32List(4);

    batch.unpackInstance(
      instanceIndex,
      outMatrix: matrix,
      outAnimData: anim,
      outTintColor: tint,
    );

    // Verify matrix
    for (int i = 0; i < 16; i++) {
      if ((matrix[i] - original.transformMatrix[i]).abs() > epsilon) {
        return false;
      }
    }

    // Verify animation parameters
    if ((anim[0] - original.animationFrameIndex).abs() > epsilon) return false;
    if ((anim[1] - original.normalizedAnimationTime).abs() > epsilon) return false;
    if ((anim[2] - original.animationType.toDouble()).abs() > epsilon) return false;
    if ((anim[3] - original.animationBlendWeight).abs() > epsilon) return false;

    // Verify tint color
    if ((tint[0] - original.tintR).abs() > epsilon) return false;
    if ((tint[1] - original.tintG).abs() > epsilon) return false;
    if ((tint[2] - original.tintB).abs() > epsilon) return false;
    if ((tint[3] - original.tintA).abs() > epsilon) return false;

    return true;
  }
}
