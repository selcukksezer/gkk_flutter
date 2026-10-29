import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

/// Level of Detail (LOD) tier classifications for crowd entities.
///
/// Complies with R4 specification:
/// - [lod0Close]: 30-50 closest entities rendered as full fidelity models (< 25m).
/// - [lod2Instanced]: Medium distance entities (25m - 80m) rendered via GPU instancing.
/// - [vatDistant]: Distant entities (80m - 250m) rendered via single draw-call VAT / Impostors.
/// - [culled]: Entities beyond max distance or outside camera frustum/AOI.
enum CrowdLodTier {
  lod0Close(0),
  lod2Instanced(1),
  vatDistant(2),
  culled(3);

  final int id;
  const CrowdLodTier(this.id);

  static CrowdLodTier fromId(int id) {
    switch (id) {
      case 0:
        return CrowdLodTier.lod0Close;
      case 1:
        return CrowdLodTier.lod2Instanced;
      case 2:
        return CrowdLodTier.vatDistant;
      default:
        return CrowdLodTier.culled;
    }
  }
}

/// Camera data used for distance calculations, Area of Interest (AOI),
/// and Frustum Culling during the crowd simulation tick.
class CrowdCamera {
  double x;
  double y;
  double z;
  double yaw; // radians
  double pitch; // radians
  double fovRadians;
  double aspect;
  double nearPlane;
  double farPlane;

  // Precomputed forward and right unit vectors to avoid trig inside 10K loops
  double _forwardX = 0.0;
  double _forwardY = 0.0;
  double _forwardZ = 1.0;
  double _halfFovCos = 0.0;

  CrowdCamera({
    this.x = 0.0,
    this.y = 10.0,
    this.z = -20.0,
    this.yaw = 0.0,
    this.pitch = 0.0,
    double fovDegrees = 60.0,
    this.aspect = 16.0 / 9.0,
    this.nearPlane = 0.1,
    this.farPlane = 250.0,
  }) : fovRadians = fovDegrees * (math.pi / 180.0) {
    updateVectors();
  }

  void updateVectors() {
    final cosPitch = math.cos(pitch);
    _forwardX = math.sin(yaw) * cosPitch;
    _forwardY = math.sin(pitch);
    _forwardZ = math.cos(yaw) * cosPitch;
    // Frustum cone half-angle cosine for fast cone culling
    _halfFovCos = math.cos((fovRadians * 0.5) * 1.3); // 1.3 margin for aspect
  }

  void setPosition(double px, double py, double pz) {
    x = px;
    y = py;
    z = pz;
  }

  void setRotation(double pyaw, double ppitch) {
    yaw = pyaw;
    pitch = ppitch;
    updateVectors();
  }

  /// High-performance cone/frustum check in O(1) time without matrix inversion.
  bool isInView(double px, double py, double pz, double margin) {
    final dx = px - x;
    final dy = py - y;
    final dz = pz - z;
    final distSq = dx * dx + dy * dy + dz * dz;

    if (distSq > (farPlane + margin) * (farPlane + margin)) return false;
    if (distSq < (nearPlane + margin) * (nearPlane + margin)) return true;

    final invDist = 1.0 / math.sqrt(distSq);
    final dot = (dx * _forwardX + dy * _forwardY + dz * _forwardZ) * invDist;
    return dot >= _halfFovCos;
  }
}

/// Read-only snapshot / accessor for GPU transformation and instance buffers.
class CrowdGpuBuffers {
  /// 4x4 matrix buffer for LOD2 GPU instancing (16 floats per instance).
  final Float32List lod2TransformBuffer;
  final int lod2InstanceCount;

  /// Packed instance buffer for VAT / Impostors (8 floats per instance).
  /// [x, y, z, yaw, scale, animTime, archetypeId, tintPacked]
  final Float32List vatInstanceBuffer;
  final int vatInstanceCount;

  /// Indices of entities assigned to LOD0/1 full-fidelity mesh rendering.
  final Int32List lod0Indices;
  final int lod0Count;

  /// Total active crowd entities.
  final int totalActive;

  /// Count of culled entities in last tick.
  final int culledCount;

  const CrowdGpuBuffers({
    required this.lod2TransformBuffer,
    required this.lod2InstanceCount,
    required this.vatInstanceBuffer,
    required this.vatInstanceCount,
    required this.lod0Indices,
    required this.lod0Count,
    required this.totalActive,
    required this.culledCount,
  });
}

/// Production-ready Spatial Hash Grid integrated directly into crowd memory.
///
/// Operates with ZERO heap allocations during insertion, queries, and clearing
/// via flat typed array linked-lists.
class FastSpatialHashGrid {
  final double cellSize;
  final double invCellSize;
  final int gridResolution; // Number of cells along axis (e.g. 64)
  final int cellCount;
  final int maxEntities;

  /// Head entity index for each cell (-1 if cell is empty).
  final Int32List cellHeads;

  /// Pointer to the next entity in the same spatial cell linked-list.
  final Int32List entityNext;

  /// Cell index occupied by each entity (-1 if unassigned).
  final Int32List entityCell;

  FastSpatialHashGrid({
    this.cellSize = 10.0,
    this.gridResolution = 128,
    required this.maxEntities,
  })  : invCellSize = 1.0 / cellSize,
        cellCount = gridResolution * gridResolution,
        cellHeads = Int32List(gridResolution * gridResolution),
        entityNext = Int32List(maxEntities),
        entityCell = Int32List(maxEntities) {
    clear();
  }

  void clear() {
    cellHeads.fillRange(0, cellCount, -1);
    entityNext.fillRange(0, maxEntities, -1);
    entityCell.fillRange(0, maxEntities, -1);
  }

  /// Fast 2D spatial coordinate hash into cell index [0 .. cellCount - 1].
  @pragma('vm:prefer-inline')
  int _hashCoords(int cx, int cz) {
    final x = (cx % gridResolution + gridResolution) % gridResolution;
    final z = (cz % gridResolution + gridResolution) % gridResolution;
    return z * gridResolution + x;
  }

  /// Insert an entity into the spatial grid in O(1) time.
  @pragma('vm:prefer-inline')
  void insert(int entityIndex, double worldX, double worldZ) {
    final cx = (worldX * invCellSize).floor();
    final cz = (worldZ * invCellSize).floor();
    final cellIdx = _hashCoords(cx, cz);

    entityNext[entityIndex] = cellHeads[cellIdx];
    cellHeads[cellIdx] = entityIndex;
    entityCell[entityIndex] = cellIdx;
  }

  /// Reset all cell heads in O(N_cells) without recreating arrays.
  @pragma('vm:prefer-inline')
  void beginFrame() {
    cellHeads.fillRange(0, cellCount, -1);
  }

  /// Radial proximity query writing directly into [outBuffer] with ZERO allocations.
  /// Returns count of entities found within [radius].
  int queryRadius({
    required double centerX,
    required double centerZ,
    required double radius,
    required Float32List positions,
    required Int32List outBuffer,
    int maxResults = 1024,
  }) {
    final minCx = ((centerX - radius) * invCellSize).floor();
    final maxCx = ((centerX + radius) * invCellSize).floor();
    final minCz = ((centerZ - radius) * invCellSize).floor();
    final maxCz = ((centerZ + radius) * invCellSize).floor();
    final rSq = radius * radius;

    final span = gridResolution - 1;
    final clampedMaxCx = math.min(maxCx, minCx + span);
    final clampedMaxCz = math.min(maxCz, minCz + span);

    int foundCount = 0;

    for (int cz = minCz; cz <= clampedMaxCz; cz++) {
      for (int cx = minCx; cx <= clampedMaxCx; cx++) {
        final cellIdx = _hashCoords(cx, cz);
        int curr = cellHeads[cellIdx];

        while (curr != -1 && foundCount < maxResults && foundCount < outBuffer.length) {
          final px = positions[curr * 3];
          final pz = positions[curr * 3 + 2];
          final dx = px - centerX;
          final dz = pz - centerZ;

          if (dx * dx + dz * dz <= rSq) {
            outBuffer[foundCount++] = curr;
          }
          curr = entityNext[curr];
        }
      }
    }

    return foundCount;
  }
}

/// Centralized CrowdRenderManager.
///
/// Implements R4 from game specification:
/// 1. Coordinates up to 10,000+ entities without separate per-entity Update() loops.
/// 2. Executes a single unified simulation & preparation pass per tick.
/// 3. Struct-of-Arrays (SoA) contiguous typed memory layout for zero GC pauses.
/// 4. Categorizes entities into 3 distance tiers (LOD0/1 Close, LOD2 GPU Instanced, Distant VAT/Impostor).
/// 5. Automatically generates GPU transform buffers for Impeller / Metal / Vulkan pipelines.
/// 6. Integrates with Flutter's rendering pipeline via [CrowdCustomPainter] and [CrowdRenderBridge].
class CrowdRenderManager {
  final int maxEntities;
  final double closeDistanceThreshold;
  final double mediumDistanceThreshold;
  final double maxCullDistance;
  final int maxLod0Entities;

  // --- Struct of Arrays (SoA) Entity State (Contiguous preallocated memory) ---
  /// World coordinates [x, y, z] per entity (length = maxEntities * 3)
  final Float32List positions;

  /// Velocity vector [vx, vy, vz] per entity (length = maxEntities * 3)
  final Float32List velocities;

  /// Yaw orientation in radians (length = maxEntities)
  final Float32List rotations;

  /// Uniform scale (length = maxEntities)
  final Float32List scales;

  /// Animation clip ID (length = maxEntities)
  final Int32List animationIds;

  /// Current animation timestamp / phase in seconds (length = maxEntities)
  final Float32List animationTimes;

  /// Playback speed multiplier (length = maxEntities)
  final Float32List animationSpeeds;

  /// Character archetype / mesh category (length = maxEntities)
  final Int32List archetypeIds;

  /// Packed 32-bit ARGB tint color (length = maxEntities)
  final Int32List tintColors;

  /// Entity status flags (bit 0: active, bit 1: visible, bit 2: static)
  final Uint8List flags;

  /// Distance to camera computed on each tick (length = maxEntities)
  final Float32List distancesToCamera;

  /// Current LOD tier assigned to each entity (length = maxEntities)
  final Uint8List lodTiers;

  // --- Entity Slot Pool (Zero allocation lifecycle) ---
  int _activeCount = 0;
  final Int32List _freeList;
  int _freeTop = 0;

  // --- LOD Output Buffers (Preallocated for GPU pipeline) ---
  /// LOD0 full fidelity entity indices (maxLod0Entities capacity)
  final Int32List lod0Indices;
  int _lod0Count = 0;

  /// LOD2 GPU Instancing Transform Matrix buffer: 16 floats (4x4 matrix) per entity.
  /// Preallocated to full maxEntities capacity (maxEntities * 16 floats = 640 KB for 10K).
  final Float32List lod2TransformBuffer;
  int _lod2InstanceCount = 0;

  /// VAT / Impostor single draw-call buffer: 8 floats per entity.
  /// [posX, posY, posZ, yaw, scale, animTime, archetypeId, tintPacked]
  final Float32List vatInstanceBuffer;
  int _vatInstanceCount = 0;

  int _culledCount = 0;

  // --- 2D / 2.5D Canvas Raw Atlas Buffers (for Flutter CustomPainter / Impeller) ---
  /// RSTransform values for Canvas.drawRawAtlas: [scos, ssin, tx, ty]
  final Float32List rstTransforms;

  /// Source rectangles in sprite/VAT texture atlas: [l, t, r, b]
  final Float32List atlasRects;

  /// Per-instance color blend
  final Int32List atlasColors;

  // --- Spatial Hash Partition ---
  final FastSpatialHashGrid spatialGrid;

  // --- Performance Metrics ---
  double _lastTickDurationMs = 0.0;
  int _tickCounter = 0;

  CrowdRenderManager({
    this.maxEntities = 10000,
    this.closeDistanceThreshold = 25.0,
    this.mediumDistanceThreshold = 80.0,
    this.maxCullDistance = 250.0,
    this.maxLod0Entities = 50,
    double spatialCellSize = 12.0,
  })  : positions = Float32List(maxEntities * 3),
        velocities = Float32List(maxEntities * 3),
        rotations = Float32List(maxEntities),
        scales = Float32List(maxEntities),
        animationIds = Int32List(maxEntities),
        animationTimes = Float32List(maxEntities),
        animationSpeeds = Float32List(maxEntities),
        archetypeIds = Int32List(maxEntities),
        tintColors = Int32List(maxEntities),
        flags = Uint8List(maxEntities),
        distancesToCamera = Float32List(maxEntities),
        lodTiers = Uint8List(maxEntities),
        _freeList = Int32List(maxEntities),
        lod0Indices = Int32List(maxLod0Entities),
        lod2TransformBuffer = Float32List(maxEntities * 16),
        vatInstanceBuffer = Float32List(maxEntities * 8),
        rstTransforms = Float32List(maxEntities * 4),
        atlasRects = Float32List(maxEntities * 4),
        atlasColors = Int32List(maxEntities),
        spatialGrid = FastSpatialHashGrid(
          cellSize: spatialCellSize,
          maxEntities: maxEntities,
        ) {
    // Populate free pool
    for (int i = 0; i < maxEntities; i++) {
      _freeList[i] = i;
      scales[i] = 1.0;
      animationSpeeds[i] = 1.0;
      tintColors[i] = 0xFFFFFFFF;
      lodTiers[i] = CrowdLodTier.culled.id;
    }
    _freeTop = maxEntities;
  }

  // --- Public Getters ---
  int get activeCount => _activeCount;
  int get lod0Count => _lod0Count;
  int get lod2InstanceCount => _lod2InstanceCount;
  int get vatInstanceCount => _vatInstanceCount;
  int get culledCount => _culledCount;
  double get lastTickDurationMs => _lastTickDurationMs;
  int get tickCounter => _tickCounter;

  /// Snapshot of current GPU buffers for downstream renderers.
  CrowdGpuBuffers get gpuBuffers => CrowdGpuBuffers(
        lod2TransformBuffer: lod2TransformBuffer,
        lod2InstanceCount: _lod2InstanceCount,
        vatInstanceBuffer: vatInstanceBuffer,
        vatInstanceCount: _vatInstanceCount,
        lod0Indices: lod0Indices,
        lod0Count: _lod0Count,
        totalActive: _activeCount,
        culledCount: _culledCount,
      );

  // --- Entity Management (O(1) with Zero Allocations) ---

  /// Spawns a new entity from the preallocated pool.
  /// Returns entity index or -1 if pool is full.
  int spawnEntity({
    double x = 0.0,
    double y = 0.0,
    double z = 0.0,
    double vx = 0.0,
    double vy = 0.0,
    double vz = 0.0,
    double yaw = 0.0,
    double scale = 1.0,
    int archetypeId = 0,
    int tintColor = 0xFFFFFFFF,
    double animationPhase = 0.0,
    double animationSpeed = 1.0,
  }) {
    if (_freeTop <= 0) return -1;

    final index = _freeList[--_freeTop];
    final pIdx = index * 3;

    positions[pIdx] = x;
    positions[pIdx + 1] = y;
    positions[pIdx + 2] = z;

    velocities[pIdx] = vx;
    velocities[pIdx + 1] = vy;
    velocities[pIdx + 2] = vz;

    rotations[index] = yaw;
    scales[index] = scale;
    archetypeIds[index] = archetypeId;
    tintColors[index] = tintColor;
    animationTimes[index] = animationPhase;
    animationSpeeds[index] = animationSpeed;
    flags[index] = 1; // Active bit

    _activeCount++;
    spatialGrid.insert(index, x, z);
    return index;
  }

  /// Despawns an entity in O(1) and returns slot to the pool.
  bool despawnEntity(int entityIndex) {
    if (entityIndex < 0 || entityIndex >= maxEntities) return false;
    if ((flags[entityIndex] & 1) == 0) return false; // Already inactive

    flags[entityIndex] = 0;
    lodTiers[entityIndex] = CrowdLodTier.culled.id;
    _freeList[_freeTop++] = entityIndex;
    _activeCount--;
    return true;
  }

  /// Bulk spawns [count] entities arranged in an area.
  void spawnBatch({
    required int count,
    required double areaRadius,
    double originX = 0.0,
    double originZ = 0.0,
    int defaultArchetype = 0,
    math.Random? rng,
  }) {
    final rand = rng ?? math.Random(42);
    for (int i = 0; i < count; i++) {
      if (_freeTop <= 0) break;
      final angle = rand.nextDouble() * 2.0 * math.pi;
      final r = math.sqrt(rand.nextDouble()) * areaRadius;
      final x = originX + math.cos(angle) * r;
      final z = originZ + math.sin(angle) * r;
      final yaw = rand.nextDouble() * 2.0 * math.pi;

      spawnEntity(
        x: x,
        y: 0.0,
        z: z,
        vx: (rand.nextDouble() - 0.5) * 1.5,
        vy: 0.0,
        vz: (rand.nextDouble() - 0.5) * 1.5,
        yaw: yaw,
        scale: 0.9 + rand.nextDouble() * 0.2,
        archetypeId: defaultArchetype,
        animationPhase: rand.nextDouble() * 3.0,
        animationSpeed: 0.8 + rand.nextDouble() * 0.4,
      );
    }
  }

  /// Clears all active entities.
  void clear() {
    _activeCount = 0;
    _freeTop = maxEntities;
    for (int i = 0; i < maxEntities; i++) {
      _freeList[i] = i;
      flags[i] = 0;
      lodTiers[i] = CrowdLodTier.culled.id;
    }
    spatialGrid.clear();
    _lod0Count = 0;
    _lod2InstanceCount = 0;
    _vatInstanceCount = 0;
    _culledCount = 0;
  }

  // --- Unified Single-Pass Tick (Zero GC Allocations) ---

  /// Executes one simulation and render-preparation step for all entities.
  ///
  /// Steps performed in a single cache-friendly pass:
  /// 1. Updates spatial hash grid buckets.
  /// 2. Integrates position velocities & updates animation timing.
  /// 3. Computes distance to camera and checks view frustum.
  /// 4. Categorizes into LOD tiers:
  ///    - Close (< 25m, up to maxLod0Entities) -> LOD0 list
  ///    - Medium (25m - 80m) -> packs 4x4 matrix into lod2TransformBuffer
  ///    - Distant (80m - 250m) -> packs into vatInstanceBuffer
  ///    - Beyond 250m or off-screen -> Culled
  /// 5. Packs 2D Atlas RSTransforms for Flutter CustomPainter / Impeller.
  void update(double dt, CrowdCamera camera) {
    final stopwatch = Stopwatch()..start();
    _tickCounter++;

    final camX = camera.x;
    final camY = camera.y;
    final camZ = camera.z;

    final closeDistSq = closeDistanceThreshold * closeDistanceThreshold;
    final medDistSq = mediumDistanceThreshold * mediumDistanceThreshold;
    final cullDistSq = maxCullDistance * maxCullDistance;

    // Reset frame counters
    _lod0Count = 0;
    _lod2InstanceCount = 0;
    _vatInstanceCount = 0;
    _culledCount = 0;

    // Begin spatial partition frame
    spatialGrid.beginFrame();

    int lod2Offset = 0;
    int vatOffset = 0;
    int rstOffset = 0;

    // Main single-pass iteration across all entity slots
    for (int i = 0; i < maxEntities; i++) {
      if ((flags[i] & 1) == 0) {
        continue; // Inactive slot
      }

      final pIdx = i * 3;

      // 1. Position & Animation Update
      final vx = velocities[pIdx];
      final vy = velocities[pIdx + 1];
      final vz = velocities[pIdx + 2];

      double posX = positions[pIdx] + vx * dt;
      double posY = positions[pIdx + 1] + vy * dt;
      double posZ = positions[pIdx + 2] + vz * dt;

      positions[pIdx] = posX;
      positions[pIdx + 1] = posY;
      positions[pIdx + 2] = posZ;

      animationTimes[i] += dt * animationSpeeds[i];

      // 2. Spatial Hash Grid Registration
      spatialGrid.insert(i, posX, posZ);

      // 3. Distance to Camera Calculation
      final dx = posX - camX;
      final dy = posY - camY;
      final dz = posZ - camZ;
      final distSq = dx * dx + dy * dy + dz * dz;
      final dist = math.sqrt(distSq);
      distancesToCamera[i] = dist;

      // 4. Frustum & Distance Culling Check
      if (distSq > cullDistSq || !camera.isInView(posX, posY, posZ, 5.0)) {
        lodTiers[i] = CrowdLodTier.culled.id;
        _culledCount++;
        continue;
      }

      final yaw = rotations[i];
      final scale = scales[i];

      // 5. LOD Tier Categorization & GPU Buffer Packing
      if (distSq < closeDistSq && _lod0Count < maxLod0Entities) {
        // --- LOD0/1: Full Fidelity Models ---
        lodTiers[i] = CrowdLodTier.lod0Close.id;
        lod0Indices[_lod0Count++] = i;
      } else if (distSq < medDistSq) {
        // --- LOD2: GPU Instanced Transforms ---
        lodTiers[i] = CrowdLodTier.lod2Instanced.id;
        _lod2InstanceCount++;

        // Pack 4x4 column-major affine transformation matrix (16 floats)
        final cosY = math.cos(yaw) * scale;
        final sinY = math.sin(yaw) * scale;

        // Column 0
        lod2TransformBuffer[lod2Offset] = cosY;
        lod2TransformBuffer[lod2Offset + 1] = 0.0;
        lod2TransformBuffer[lod2Offset + 2] = sinY;
        lod2TransformBuffer[lod2Offset + 3] = 0.0;

        // Column 1
        lod2TransformBuffer[lod2Offset + 4] = 0.0;
        lod2TransformBuffer[lod2Offset + 5] = scale;
        lod2TransformBuffer[lod2Offset + 6] = 0.0;
        lod2TransformBuffer[lod2Offset + 7] = 0.0;

        // Column 2
        lod2TransformBuffer[lod2Offset + 8] = -sinY;
        lod2TransformBuffer[lod2Offset + 9] = 0.0;
        lod2TransformBuffer[lod2Offset + 10] = cosY;
        lod2TransformBuffer[lod2Offset + 11] = 0.0;

        // Column 3 (Translation)
        lod2TransformBuffer[lod2Offset + 12] = posX;
        lod2TransformBuffer[lod2Offset + 13] = posY;
        lod2TransformBuffer[lod2Offset + 14] = posZ;
        lod2TransformBuffer[lod2Offset + 15] = 1.0;

        lod2Offset += 16;
      } else {
        // --- LOD3 / VAT: Distant Impostor Single Draw-Call ---
        lodTiers[i] = CrowdLodTier.vatDistant.id;
        _vatInstanceCount++;

        // Pack 8-float VAT/Impostor instance packet
        vatInstanceBuffer[vatOffset] = posX;
        vatInstanceBuffer[vatOffset + 1] = posY;
        vatInstanceBuffer[vatOffset + 2] = posZ;
        vatInstanceBuffer[vatOffset + 3] = yaw;
        vatInstanceBuffer[vatOffset + 4] = scale;
        vatInstanceBuffer[vatOffset + 5] = animationTimes[i];
        vatInstanceBuffer[vatOffset + 6] = archetypeIds[i].toDouble();
        vatInstanceBuffer[vatOffset + 7] = tintColors[i].toDouble();

        vatOffset += 8;
      }

      // 6. Flutter Canvas 2D/2.5D Atlas Transform Buffer (RSTransform: scos, ssin, tx, ty)
      rstTransforms[rstOffset] = math.cos(yaw) * scale;
      rstTransforms[rstOffset + 1] = math.sin(yaw) * scale;
      rstTransforms[rstOffset + 2] = posX;
      rstTransforms[rstOffset + 3] = posZ; // 2D projection on XZ plane

      atlasColors[i] = tintColors[i];
      rstOffset += 4;
    }

    stopwatch.stop();
    _lastTickDurationMs = stopwatch.elapsedMicroseconds / 1000.0;
  }

  // --- Spatial Proximity API ---

  /// Zero-allocation query finding all entities within [radius] of [cx, cz].
  /// Writes entity indices into [outBuffer] and returns count found.
  int queryRadius({
    required double cx,
    required double cz,
    required double radius,
    required Int32List outBuffer,
    int maxResults = 1024,
  }) {
    return spatialGrid.queryRadius(
      centerX: cx,
      centerZ: cz,
      radius: radius,
      positions: positions,
      outBuffer: outBuffer,
      maxResults: maxResults,
    );
  }

  /// Finds nearest entity to [cx, cz] within [maxRadius]. Returns -1 if none found.
  int findNearest(double cx, double cz, double maxRadius) {
    final queryBuf = Int32List(64);
    final count = queryRadius(
      cx: cx,
      cz: cz,
      radius: maxRadius,
      outBuffer: queryBuf,
      maxResults: 64,
    );
    if (count == 0) return -1;

    int nearestIdx = -1;
    double minDSq = double.infinity;

    for (int i = 0; i < count; i++) {
      final eIdx = queryBuf[i];
      final pIdx = eIdx * 3;
      final dx = positions[pIdx] - cx;
      final dz = positions[pIdx + 2] - cz;
      final dSq = dx * dx + dz * dz;
      if (dSq < minDSq) {
        minDSq = dSq;
        nearestIdx = eIdx;
      }
    }
    return nearestIdx;
  }
}

// ============================================================================
// Flutter Rendering Pipeline Integration
// ============================================================================

/// CustomPainter providing Flutter canvas and Impeller integration for crowd rendering.
///
/// Can render either:
/// 1. High performance GPU accelerated 2D/2.5D sprite atlas via [Canvas.drawRawAtlas].
/// 2. Debug visualizer displaying entity positions and LOD tier color coding.
class CrowdCustomPainter extends CustomPainter {
  final CrowdRenderManager manager;
  final ui.Image? textureAtlas;
  final bool debugVisualizer;
  final double worldToScreenScale;
  final ui.Offset screenOrigin;
  final int tickCounter;

  static final Paint _lod0Paint = Paint()..color = const Color(0xFF00FF66); // Neon Green
  static final Paint _lod2Paint = Paint()..color = const Color(0xFFFFCC00); // Amber Yellow
  static final Paint _vatPaint = Paint()..color = const Color(0xFF00CCFF); // Cyan
  static final Paint _culledPaint = Paint()..color = const Color(0x33888888); // Dim Gray

  CrowdCustomPainter({
    required this.manager,
    this.textureAtlas,
    this.debugVisualizer = false,
    this.worldToScreenScale = 2.0,
    this.screenOrigin = const ui.Offset(400, 400),
    int? tickCounter,
  }) : tickCounter = tickCounter ?? manager.tickCounter;

  @override
  void paint(Canvas canvas, Size size) {
    if (debugVisualizer || textureAtlas == null) {
      _paintDebugVisualizer(canvas, size);
    } else {
      _paintAtlas(canvas);
    }
  }

  void _paintAtlas(Canvas canvas) {
    if (textureAtlas == null) return;
    final active = manager.activeCount;
    if (active == 0) return;

    // Use Flutter's Impeller-accelerated drawRawAtlas
    canvas.drawRawAtlas(
      textureAtlas!,
      manager.rstTransforms,
      manager.atlasRects,
      manager.atlasColors,
      BlendMode.srcOver,
      null, // No clip rect
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  void _paintDebugVisualizer(Canvas canvas, Size size) {
    final positions = manager.positions;
    final tiers = manager.lodTiers;
    final flags = manager.flags;
    final maxEntities = manager.maxEntities;

    for (int i = 0; i < maxEntities; i++) {
      if ((flags[i] & 1) == 0) continue;

      final pIdx = i * 3;
      final sx = screenOrigin.dx + positions[pIdx] * worldToScreenScale;
      final sy = screenOrigin.dy + positions[pIdx + 2] * worldToScreenScale;

      if (sx < 0 || sx > size.width || sy < 0 || sy > size.height) {
        continue;
      }

      final tier = tiers[i];
      Paint paint;
      double radius;

      if (tier == CrowdLodTier.lod0Close.id) {
        paint = _lod0Paint;
        radius = 3.5;
      } else if (tier == CrowdLodTier.lod2Instanced.id) {
        paint = _lod2Paint;
        radius = 2.2;
      } else if (tier == CrowdLodTier.vatDistant.id) {
        paint = _vatPaint;
        radius = 1.4;
      } else {
        paint = _culledPaint;
        radius = 0.8;
      }

      canvas.drawCircle(ui.Offset(sx, sy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CrowdCustomPainter oldDelegate) {
    return oldDelegate.tickCounter != tickCounter;
  }
}

/// Bridge coordinating the Flutter Ticker/Engine loop with CrowdRenderManager.
class CrowdRenderBridge {
  final CrowdRenderManager manager;
  final CrowdCamera camera;
  bool isRunning = false;

  CrowdRenderBridge({
    required this.manager,
    required this.camera,
  });

  /// Frame tick callback invoked by Flutter Ticker or Game loop.
  void onTick(double dt) {
    if (!isRunning) return;
    manager.update(dt, camera);
  }

  void start() {
    isRunning = true;
  }

  void stop() {
    isRunning = false;
  }
}
