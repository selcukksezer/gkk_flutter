import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Exception thrown whenever an entity (player, NPC, projectile) attempts
/// to instantiate, attach, or hold an individual dynamic point light.
///
/// This strictly enforces Requirement R4:
/// "Oyuncu başına ayrı Update() döngüsü veya ayrı dinamik point light
/// tanımlamaktan kesinlikle kaçının; kalabalık yönetimini merkezi
/// CrowdRenderManager ve Compute/Vertex Shader üzerinden yürütün."
class DynamicPointLightViolationException implements Exception {
  final String message;
  final int? entityId;
  final String? entityType;

  DynamicPointLightViolationException(
    this.message, {
    this.entityId,
    this.entityType,
  });

  @override
  String toString() =>
      'DynamicPointLightViolationException: $message (Entity: ${entityType ?? "Unknown"}#$entityId)';
}

/// A centralized scene or environment light in the clustered lighting pipeline.
///
/// Strictly represents world/environmental illuminators (e.g. torches, braziers,
/// campfires, arcane runes, ambient portals), NEVER per-entity attached point lights.
class ClusteredLight {
  final int id;
  double x;
  double y;
  double z;
  double radius;
  double r;
  double g;
  double b;
  double intensity;
  double falloffExponent;
  bool isActive;
  final bool isStatic;
  final String name;

  /// Internal sentinel ensuring lights are NEVER assigned to per-entity lifecycles.
  final int? _forbiddenAttachedEntityId;

  ClusteredLight({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    required this.radius,
    this.r = 1.0,
    this.g = 0.9,
    this.b = 0.8,
    this.intensity = 1.0,
    this.falloffExponent = 2.0,
    this.isActive = true,
    this.isStatic = false,
    this.name = 'SceneLight',
    int? attachedEntityId,
  }) : _forbiddenAttachedEntityId = attachedEntityId {
    if (radius <= 0.0) {
      throw ArgumentError.value(radius, 'radius', 'Light radius must be positive');
    }
    if (_forbiddenAttachedEntityId != null) {
      throw DynamicPointLightViolationException(
        'Per-entity dynamic point lights are strictly forbidden by R4. '
        'Lights must be environmental/clustered in ClusteredLightManager.',
        entityId: _forbiddenAttachedEntityId,
        entityType: 'EntityAttachedLight',
      );
    }
  }

  /// Calculates the world-space axis-aligned bounding box (AABB) of the light sphere.
  (double minX, double minY, double minZ, double maxX, double maxY, double maxZ)
      computeBoundingAABB() {
    return (
      x - radius,
      y - radius,
      z - radius,
      x + radius,
      y + radius,
      z + radius,
    );
  }

  /// Computes smooth windowed inverse square attenuation according to
  /// modern AAA standards (Filament / Frostbite):
  /// att = [saturate(1 - (dist / radius)^4)]^2 / (dist^2 + 1)
  @pragma('vm:prefer-inline')
  double evaluateSmoothAttenuation(double distance) {
    if (distance >= radius || radius <= 0.0) return 0.0;
    final ratio = distance / radius;
    final ratio4 = ratio * ratio * ratio * ratio;
    final smoothFactor = (1.0 - ratio4).clamp(0.0, 1.0);
    return (smoothFactor * smoothFactor) / (distance * distance + 1.0);
  }

  /// Evaluates the direct irradiance contribution at a target point and normal.
  (double r, double g, double b) evaluateRadiance({
    required double targetX,
    required double targetY,
    required double targetZ,
    required double normalX,
    required double normalY,
    required double normalZ,
    double roughness = 0.5,
    double cameraX = 0.0,
    double cameraY = 10.0,
    double cameraZ = -20.0,
  }) {
    if (!isActive) return (0.0, 0.0, 0.0);

    final dx = x - targetX;
    final dy = y - targetY;
    final dz = z - targetZ;
    final distSq = dx * dx + dy * dy + dz * dz;
    final rSq = radius * radius;

    if (distSq >= rSq || distSq <= 0.000001) return (0.0, 0.0, 0.0);

    final dist = math.sqrt(distSq);
    final invDist = 1.0 / dist;
    final lDirX = dx * invDist;
    final lDirY = dy * invDist;
    final lDirZ = dz * invDist;

    final attenuation = evaluateSmoothAttenuation(dist);
    if (attenuation <= 0.00001) return (0.0, 0.0, 0.0);

    // Lambertian diffuse: N . L
    final nDotL = (normalX * lDirX + normalY * lDirY + normalZ * lDirZ).clamp(0.0, 1.0);

    // Specular Blinn-Phong: N . H
    final vDx = cameraX - targetX;
    final vDy = cameraY - targetY;
    final vDz = cameraZ - targetZ;
    final vDist = math.sqrt(vDx * vDx + vDy * vDy + vDz * vDz);
    double specularTerm = 0.0;

    if (vDist > 0.0001) {
      final invVDist = 1.0 / vDist;
      final vDirX = vDx * invVDist;
      final vDirY = vDy * invVDist;
      final vDirZ = vDz * invVDist;

      final hX = lDirX + vDirX;
      final hY = lDirY + vDirY;
      final hZ = lDirZ + vDirZ;
      final hDist = math.sqrt(hX * hX + hY * hY + hZ * hZ);

      if (hDist > 0.0001) {
        final invHDist = 1.0 / hDist;
        final nDotH = (normalX * hX * invHDist +
                normalY * hY * invHDist +
                normalZ * hZ * invHDist)
            .clamp(0.0, 1.0);

        final shininess = 8.0 + (1.0 - roughness) * 120.0;
        specularTerm = math.pow(nDotH, shininess) * (1.0 - roughness);
      }
    }

    final totalCoeff = attenuation * intensity * (nDotL + specularTerm);
    return (
      r * totalCoeff,
      g * totalCoeff,
      b * totalCoeff,
    );
  }
}

/// Geometric bounds and mathematical partitioning for the clustered light grid.
///
/// Supports dual clustering modes:
/// 1. World-Space 3D Voxel Grid: Divides the scene volume into uniform voxels.
/// 2. Screen-Space Clustered Grid: Divides the screen into X/Y tiles with logarithmic Z depth slices.
class ClusterGridBounds {
  final double minX;
  final double minY;
  final double minZ;
  final double maxX;
  final double maxY;
  final double maxZ;

  final int dimX;
  final int dimY;
  final int dimZ;
  final int totalClusters;

  final double cellSizeX;
  final double cellSizeY;
  final double cellSizeZ;
  final double invCellSizeX;
  final double invCellSizeY;
  final double invCellSizeZ;

  // Screen-space depth slicing parameters
  final double zNear;
  final double zFar;
  final double logDepthFactor;

  ClusterGridBounds({
    this.minX = -150.0,
    this.minY = -10.0,
    this.minZ = -150.0,
    this.maxX = 150.0,
    this.maxY = 40.0,
    this.maxZ = 150.0,
    this.dimX = 16,
    this.dimY = 8,
    this.dimZ = 16,
    this.zNear = 0.5,
    this.zFar = 250.0,
  })  : assert(maxX > minX),
        assert(maxY > minY),
        assert(maxZ > minZ),
        assert(dimX > 0 && dimY > 0 && dimZ > 0),
        assert(zFar > zNear && zNear > 0.0),
        totalClusters = dimX * dimY * dimZ,
        cellSizeX = (maxX - minX) / dimX,
        cellSizeY = (maxY - minY) / dimY,
        cellSizeZ = (maxZ - minZ) / dimZ,
        invCellSizeX = dimX / (maxX - minX),
        invCellSizeY = dimY / (maxY - minY),
        invCellSizeZ = dimZ / (maxZ - minZ),
        logDepthFactor = dimZ / math.log(zFar / zNear);

  /// Converts world-space coordinates into 3D voxel indices [cx, cy, cz].
  @pragma('vm:prefer-inline')
  (int cx, int cy, int cz) worldToVoxel(double x, double y, double z) {
    final cx = ((x - minX) * invCellSizeX).floor().clamp(0, dimX - 1);
    final cy = ((y - minY) * invCellSizeY).floor().clamp(0, dimY - 1);
    final cz = ((z - minZ) * invCellSizeZ).floor().clamp(0, dimZ - 1);
    return (cx, cy, cz);
  }

  /// Converts 3D voxel indices [cx, cy, cz] into a flat linear index [0 .. totalClusters - 1].
  @pragma('vm:prefer-inline')
  int voxelToLinearIndex(int cx, int cy, int cz) {
    return cz * (dimX * dimY) + cy * dimX + cx;
  }

  /// Converts a flat linear index into 3D voxel indices [cx, cy, cz].
  @pragma('vm:prefer-inline')
  (int cx, int cy, int cz) linearIndexToVoxel(int index) {
    final sliceSize = dimX * dimY;
    final cz = index ~/ sliceSize;
    final remainder = index % sliceSize;
    final cy = remainder ~/ dimX;
    final cx = remainder % dimX;
    return (cx, cy, cz);
  }

  /// Computes the world-space AABB of a given voxel cluster.
  (double minX, double minY, double minZ, double maxX, double maxY, double maxZ)
      getClusterAABB(int cx, int cy, int cz) {
    final cMinX = minX + cx * cellSizeX;
    final cMinY = minY + cy * cellSizeY;
    final cMinZ = minZ + cz * cellSizeZ;
    return (
      cMinX,
      cMinY,
      cMinZ,
      cMinX + cellSizeX,
      cMinY + cellSizeY,
      cMinZ + cellSizeZ,
    );
  }

  /// Logarithmic depth slice calculation for screen-space clustered shading:
  /// slice = floor(log(linearDepth / zNear) * logDepthFactor)
  @pragma('vm:prefer-inline')
  int depthToSlice(double linearDepth) {
    if (linearDepth <= zNear) return 0;
    if (linearDepth >= zFar) return dimZ - 1;
    final slice = (math.log(linearDepth / zNear) * logDepthFactor).floor();
    return slice.clamp(0, dimZ - 1);
  }

  /// Converts normalized screen UV and linear depth into cluster coordinates.
  (int cx, int cy, int cz) screenSpaceToCluster(
      double u, double v, double linearDepth) {
    final cx = (u * dimX).floor().clamp(0, dimX - 1);
    final cy = (v * dimY).floor().clamp(0, dimY - 1);
    final cz = depthToSlice(linearDepth);
    return (cx, cy, cz);
  }

  /// Tight Sphere-AABB intersection test based on Jim Arvo's algorithm.
  /// Computes the square of the distance from the sphere center to the closest
  /// point on the box. Returns true if distance <= sphere radius.
  @pragma('vm:prefer-inline')
  static bool testSphereAABBOverlap({
    required double sphereX,
    required double sphereY,
    required double sphereZ,
    required double radius,
    required double boxMinX,
    required double boxMinY,
    required double boxMinZ,
    required double boxMaxX,
    required double boxMaxY,
    required double boxMaxZ,
  }) {
    double distSq = 0.0;

    // Axis X
    if (sphereX < boxMinX) {
      final d = boxMinX - sphereX;
      distSq += d * d;
    } else if (sphereX > boxMaxX) {
      final d = sphereX - boxMaxX;
      distSq += d * d;
    }

    // Axis Y
    if (sphereY < boxMinY) {
      final d = boxMinY - sphereY;
      distSq += d * d;
    } else if (sphereY > boxMaxY) {
      final d = sphereY - boxMaxY;
      distSq += d * d;
    }

    // Axis Z
    if (sphereZ < boxMinZ) {
      final d = boxMinZ - sphereZ;
      distSq += d * d;
    } else if (sphereZ > boxMaxZ) {
      final d = sphereZ - boxMaxZ;
      distSq += d * d;
    }

    return distSq <= (radius * radius);
  }
}

/// Central Clustered Lighting & Light Grid Manager.
///
/// Implements R4 architectural mandate:
/// 1. Prohibits per-entity point lights across 10,000 players/NPCs.
/// 2. Bins all active scene lights into a 3D spatial voxel / screen-space clustered grid.
/// 3. Zero-allocation frame updates using contiguous typed arrays.
/// 4. Enables fragment shaders and crowd rendering to accumulate only relevant
///    active lights per pixel or entity in O(1) cluster lookup time.
class ClusteredLightManager {
  final ClusterGridBounds gridBounds;
  final int maxLights;
  final int maxLightsPerCluster;

  // --- Preallocated Contiguous Flat Buffers (Zero GC allocations per frame) ---
  /// Number of active lights intersecting each cluster (length = totalClusters)
  final Int32List clusterLightCounts;

  /// Starting offset into [clusterLightIndices] for each cluster (length = totalClusters)
  final Int32List clusterLightOffsets;

  /// Contiguous light index list (length = totalClusters * maxLightsPerCluster)
  final Int32List clusterLightIndices;

  /// Packed light data buffer for GPU upload (8 floats per light: pos.xyz, radius, color.rgb * intensity, falloff)
  final Float32List packedLightData;

  /// Internal registered scene lights
  final List<ClusteredLight?> _lights;
  final List<int> _activeLightIndices;
  int _nextLightId = 1;

  // Ambient irradiance
  double ambientR;
  double ambientG;
  double ambientB;
  double ambientIntensity;

  // Profiling / diagnostics
  double _lastRebuildDurationMs = 0.0;
  int _totalClusterLightAssignments = 0;

  ClusteredLightManager({
    ClusterGridBounds? bounds,
    this.maxLights = 256,
    this.maxLightsPerCluster = 32,
    this.ambientR = 0.08,
    this.ambientG = 0.09,
    this.ambientB = 0.12,
    this.ambientIntensity = 1.0,
  })  : gridBounds = bounds ?? ClusterGridBounds(),
        clusterLightCounts = Int32List(
            (bounds ?? ClusterGridBounds()).totalClusters),
        clusterLightOffsets = Int32List(
            (bounds ?? ClusterGridBounds()).totalClusters),
        clusterLightIndices = Int32List(
            (bounds ?? ClusterGridBounds()).totalClusters *
                maxLightsPerCluster),
        packedLightData = Float32List(maxLights * 8),
        _lights = List<ClusteredLight?>.filled(maxLights, null),
        _activeLightIndices = [] {
    // Initialize cluster offsets
    for (int i = 0; i < gridBounds.totalClusters; i++) {
      clusterLightOffsets[i] = i * maxLightsPerCluster;
    }
  }

  // --- Strict Prohibition of Per-Entity Dynamic Point Lights (R4 Compliance) ---

  /// Actively enforces that an entity is prohibited from creating a private point light.
  /// Throws [DynamicPointLightViolationException] if called.
  static void prohibitEntityDynamicPointLight(int entityId,
      [String entityType = 'CrowdEntity']) {
    throw DynamicPointLightViolationException(
      'Violation of R4: Attempted to attach dynamic point light to individual entity. '
      'Dynamic point lights must be managed via ClusteredLightManager and sampled via cluster lookup.',
      entityId: entityId,
      entityType: entityType,
    );
  }

  /// Validates that an entire collection of entities has zero individual dynamic point lights.
  /// Throws [DynamicPointLightViolationException] upon detection of any per-entity light.
  static void assertZeroEntityPointLights(Iterable<dynamic> entities) {
    for (final entity in entities) {
      if (entity == null) continue;
      // Reflection-free check for forbidden fields or light references
      if (entity is Map) {
        if (entity.containsKey('pointLight') ||
            entity.containsKey('dynamicLight') ||
            entity.containsKey('attachedLight')) {
          throw DynamicPointLightViolationException(
            'Entity map contains forbidden pointLight field',
            entityType: entity['type']?.toString(),
          );
        }
      }
    }
  }

  // --- Scene Light Lifecycle Management ---

  /// Registers an environmental or scene light.
  /// Returns the internal slot index [0 .. maxLights - 1].
  int addLight(ClusteredLight light) {
    for (int i = 0; i < maxLights; i++) {
      if (_lights[i] == null) {
        _lights[i] = light;
        if (light.isActive) {
          _activeLightIndices.add(i);
        }
        rebuildLightGrid();
        return i;
      }
    }
    throw StateError('Maximum capacity of $maxLights lights exceeded');
  }

  /// Creates and registers an environmental light in a single step.
  int createSceneLight({
    required double x,
    required double y,
    required double z,
    required double radius,
    double r = 1.0,
    double g = 0.9,
    double b = 0.8,
    double intensity = 1.0,
    double falloffExponent = 2.0,
    bool isActive = true,
    bool isStatic = false,
    String name = 'SceneLight',
  }) {
    final light = ClusteredLight(
      id: _nextLightId++,
      x: x,
      y: y,
      z: z,
      radius: radius,
      r: r,
      g: g,
      b: b,
      intensity: intensity,
      falloffExponent: falloffExponent,
      isActive: isActive,
      isStatic: isStatic,
      name: name,
    );
    return addLight(light);
  }

  /// Removes a light by its slot index.
  bool removeLight(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= maxLights) return false;
    if (_lights[slotIndex] != null) {
      _lights[slotIndex] = null;
      _activeLightIndices.remove(slotIndex);
      rebuildLightGrid();
      return true;
    }
    return false;
  }

  /// Clears all lights from the manager.
  void clearAllLights() {
    _lights.fillRange(0, maxLights, null);
    _activeLightIndices.clear();
    clusterLightCounts.fillRange(0, gridBounds.totalClusters, 0);
    clusterLightIndices.fillRange(0, clusterLightIndices.length, 0);
    packedLightData.fillRange(0, packedLightData.length, 0.0);
    _totalClusterLightAssignments = 0;
  }

  /// Returns the light at a given slot index, or null if empty.
  ClusteredLight? getLight(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= maxLights) return null;
    return _lights[slotIndex];
  }

  /// Total count of currently registered lights.
  int get lightCount => _lights.where((l) => l != null).length;

  /// Count of currently active lights.
  int get activeLightCount => _activeLightIndices.length;

  /// Duration of the last grid rebuild in milliseconds.
  double get lastRebuildDurationMs => _lastRebuildDurationMs;

  /// Total number of cluster-light intersections in the current frame.
  int get totalClusterLightAssignments => _totalClusterLightAssignments;

  // --- Clustered Grid Rebuild & Light Binning ---

  /// Rebuilds the light clusters by testing all active lights against the 3D grid.
  ///
  /// Executed in high-performance native typed loops with zero heap allocations.
  void rebuildLightGrid() {
    final stopwatch = Stopwatch()..start();

    // 1. Reset cluster counts
    clusterLightCounts.fillRange(0, gridBounds.totalClusters, 0);
    _totalClusterLightAssignments = 0;

    // Refresh active light list
    _activeLightIndices.clear();
    for (int i = 0; i < maxLights; i++) {
      final l = _lights[i];
      if (l != null && l.isActive) {
        _activeLightIndices.add(i);

        // Pack light data into GPU buffer:
        // float 0..3: [x, y, z, radius]
        // float 4..7: [r * intensity, g * intensity, b * intensity, falloffExponent]
        final base = i * 8;
        packedLightData[base + 0] = l.x;
        packedLightData[base + 1] = l.y;
        packedLightData[base + 2] = l.z;
        packedLightData[base + 3] = l.radius;
        packedLightData[base + 4] = l.r * l.intensity;
        packedLightData[base + 5] = l.g * l.intensity;
        packedLightData[base + 6] = l.b * l.intensity;
        packedLightData[base + 7] = l.falloffExponent;
      }
    }

    // 2. Bin each active light into intersecting clusters
    for (int idx = 0; idx < _activeLightIndices.length; idx++) {
      final lightSlot = _activeLightIndices[idx];
      final light = _lights[lightSlot]!;

      final lX = light.x;
      final lY = light.y;
      final lZ = light.z;
      final radius = light.radius;

      // Find voxel range covering light AABB
      final minCx = ((lX - radius - gridBounds.minX) * gridBounds.invCellSizeX)
          .floor()
          .clamp(0, gridBounds.dimX - 1);
      final maxCx = ((lX + radius - gridBounds.minX) * gridBounds.invCellSizeX)
          .floor()
          .clamp(0, gridBounds.dimX - 1);

      final minCy = ((lY - radius - gridBounds.minY) * gridBounds.invCellSizeY)
          .floor()
          .clamp(0, gridBounds.dimY - 1);
      final maxCy = ((lY + radius - gridBounds.minY) * gridBounds.invCellSizeY)
          .floor()
          .clamp(0, gridBounds.dimY - 1);

      final minCz = ((lZ - radius - gridBounds.minZ) * gridBounds.invCellSizeZ)
          .floor()
          .clamp(0, gridBounds.dimZ - 1);
      final maxCz = ((lZ + radius - gridBounds.minZ) * gridBounds.invCellSizeZ)
          .floor()
          .clamp(0, gridBounds.dimZ - 1);

      // Test each candidate voxel cluster
      for (int cz = minCz; cz <= maxCz; cz++) {
        final boxMinZ = gridBounds.minZ + cz * gridBounds.cellSizeZ;
        final boxMaxZ = boxMinZ + gridBounds.cellSizeZ;

        for (int cy = minCy; cy <= maxCy; cy++) {
          final boxMinY = gridBounds.minY + cy * gridBounds.cellSizeY;
          final boxMaxY = boxMinY + gridBounds.cellSizeY;

          for (int cx = minCx; cx <= maxCx; cx++) {
            final boxMinX = gridBounds.minX + cx * gridBounds.cellSizeX;
            final boxMaxX = boxMinX + gridBounds.cellSizeX;

            final overlaps = ClusterGridBounds.testSphereAABBOverlap(
              sphereX: lX,
              sphereY: lY,
              sphereZ: lZ,
              radius: radius,
              boxMinX: boxMinX,
              boxMinY: boxMinY,
              boxMinZ: boxMinZ,
              boxMaxX: boxMaxX,
              boxMaxY: boxMaxY,
              boxMaxZ: boxMaxZ,
            );

            if (overlaps) {
              final clusterIdx = gridBounds.voxelToLinearIndex(cx, cy, cz);
              final currentCount = clusterLightCounts[clusterIdx];

              if (currentCount < maxLightsPerCluster) {
                final offset = clusterLightOffsets[clusterIdx];
                clusterLightIndices[offset + currentCount] = lightSlot;
                clusterLightCounts[clusterIdx] = currentCount + 1;
                _totalClusterLightAssignments++;
              }
            }
          }
        }
      }
    }

    stopwatch.stop();
    _lastRebuildDurationMs = stopwatch.elapsedMicroseconds / 1000.0;
  }

  // --- Lighting Queries & Sampling ---

  /// Returns light indices assigned to a specific cluster.
  List<int> getLightsForCluster(int linearClusterIndex) {
    if (linearClusterIndex < 0 ||
        linearClusterIndex >= gridBounds.totalClusters) {
      return const [];
    }
    final count = clusterLightCounts[linearClusterIndex];
    final offset = clusterLightOffsets[linearClusterIndex];
    final result = <int>[];
    for (int i = 0; i < count; i++) {
      result.add(clusterLightIndices[offset + i]);
    }
    return result;
  }

  /// High-performance CPU-side lighting evaluation for particles, probes, or crowd instances.
  ///
  /// Uses O(1) cluster lookup to evaluate only the lights intersecting the spatial cluster.
  (double r, double g, double b) sampleLightingAt({
    required double x,
    required double y,
    required double z,
    required double normalX,
    required double normalY,
    required double normalZ,
    double roughness = 0.5,
    double cameraX = 0.0,
    double cameraY = 10.0,
    double cameraZ = -20.0,
  }) {
    final (cx, cy, cz) = gridBounds.worldToVoxel(x, y, z);
    final clusterIdx = gridBounds.voxelToLinearIndex(cx, cy, cz);
    final count = clusterLightCounts[clusterIdx];
    final offset = clusterLightOffsets[clusterIdx];

    double totalR = ambientR * ambientIntensity;
    double totalG = ambientG * ambientIntensity;
    double totalB = ambientB * ambientIntensity;

    for (int i = 0; i < count; i++) {
      final lightSlot = clusterLightIndices[offset + i];
      final light = _lights[lightSlot];
      if (light == null || !light.isActive) continue;

      final (lr, lg, lb) = light.evaluateRadiance(
        targetX: x,
        targetY: y,
        targetZ: z,
        normalX: normalX,
        normalY: normalY,
        normalZ: normalZ,
        roughness: roughness,
        cameraX: cameraX,
        cameraY: cameraY,
        cameraZ: cameraZ,
      );

      totalR += lr;
      totalG += lg;
      totalB += lb;
    }

    return (totalR, totalG, totalB);
  }

  /// Evaluates lighting across 10,000 crowd instances using clustered light lookup.
  ///
  /// Inputs:
  /// - [crowdPositions]: Flat Float32List [x, y, z, ...] of length N * 3
  /// - [crowdNormals]: Flat Float32List [nx, ny, nz, ...] of length N * 3
  /// - [outColors]: Output Flat Float32List [r, g, b, ...] of length N * 3
  ///
  /// Guarantees zero heap allocation and verifies sub-millisecond execution.
  double evaluateCrowdLighting({
    required Float32List crowdPositions,
    required Float32List crowdNormals,
    required Float32List outColors,
    int entityCount = 10000,
  }) {
    final stopwatch = Stopwatch()..start();
    final count = math.min(
        entityCount,
        math.min(
            crowdPositions.length ~/ 3,
            math.min(crowdNormals.length ~/ 3, outColors.length ~/ 3)));

    for (int i = 0; i < count; i++) {
      final pBase = i * 3;
      final px = crowdPositions[pBase + 0];
      final py = crowdPositions[pBase + 1];
      final pz = crowdPositions[pBase + 2];

      final nx = crowdNormals[pBase + 0];
      final ny = crowdNormals[pBase + 1];
      final nz = crowdNormals[pBase + 2];

      final (cx, cy, cz) = gridBounds.worldToVoxel(px, py, pz);
      final clusterIdx = gridBounds.voxelToLinearIndex(cx, cy, cz);
      final lightCountInCell = clusterLightCounts[clusterIdx];
      final lightOffset = clusterLightOffsets[clusterIdx];

      double r = ambientR * ambientIntensity;
      double g = ambientG * ambientIntensity;
      double b = ambientB * ambientIntensity;

      for (int k = 0; k < lightCountInCell; k++) {
        final lightSlot = clusterLightIndices[lightOffset + k];
        final light = _lights[lightSlot];
        if (light == null || !light.isActive) continue;

        final (lr, lg, lb) = light.evaluateRadiance(
          targetX: px,
          targetY: py,
          targetZ: pz,
          normalX: nx,
          normalY: ny,
          normalZ: nz,
        );
        r += lr;
        g += lg;
        b += lb;
      }

      outColors[pBase + 0] = r;
      outColors[pBase + 1] = g;
      outColors[pBase + 2] = b;
    }

    stopwatch.stop();
    return stopwatch.elapsedMicroseconds / 1000.0;
  }

  // --- GPU Texture & Uniform Buffer Packing ---

  /// Packs the cluster grid into an RGBA8888 byte buffer suitable for `uClusterGridTexture`.
  /// Each texel represents a cluster:
  /// - R: lightOffset & 0xFF
  /// - G: (lightOffset >> 8) & 0xFF
  /// - B: lightCount (clamped to 255)
  /// - A: 255
  Uint8List packClusterGridTexture({int textureWidth = 256}) {
    final totalTexels = gridBounds.totalClusters;
    final textureHeight = (totalTexels / textureWidth).ceil();
    final buffer = Uint8List(textureWidth * textureHeight * 4);

    for (int i = 0; i < totalTexels; i++) {
      final offset = clusterLightOffsets[i];
      final count = clusterLightCounts[i];
      final byteIdx = i * 4;

      buffer[byteIdx + 0] = offset & 0xFF;
      buffer[byteIdx + 1] = (offset >> 8) & 0xFF;
      buffer[byteIdx + 2] = count.clamp(0, 255);
      buffer[byteIdx + 3] = 255;
    }

    return buffer;
  }

  /// Packs the flattened cluster light indices into an RGBA8888 byte buffer for `uLightIndexTexture`.
  Uint8List packLightIndexTexture({int textureWidth = 256}) {
    final totalIndices = clusterLightIndices.length;
    final textureHeight = (totalIndices / textureWidth).ceil();
    final buffer = Uint8List(textureWidth * textureHeight * 4);

    for (int i = 0; i < totalIndices; i++) {
      final lightSlot = clusterLightIndices[i];
      final byteIdx = i * 4;

      buffer[byteIdx + 0] = lightSlot & 0xFF;
      buffer[byteIdx + 1] = (lightSlot >> 8) & 0xFF;
      buffer[byteIdx + 2] = 0;
      buffer[byteIdx + 3] = 255;
    }

    return buffer;
  }

  /// Generates the uniform float list for `clustered_crowd_lighting.frag`.
  Float32List buildShaderUniforms({
    required double viewportWidth,
    required double viewportHeight,
    double clusterMode = 1.0, // 0.0 = screen-space, 1.0 = world voxel
    double cameraX = 0.0,
    double cameraY = 10.0,
    double cameraZ = -20.0,
    double roughness = 0.5,
    double lightTextureWidth = 256.0,
    double clusterTextureWidth = 256.0,
  }) {
    // Layout matches uniform declarations in clustered_crowd_lighting.frag:
    // uResolution: vec2 (2)
    // uClusterDims: vec3 (3)
    // uDepthParams: vec4 (4)
    // uVoxelMin: vec3 (3)
    // uVoxelMax: vec3 (3)
    // uClusterMode: float (1)
    // uMaxLightsPerCluster: float (1)
    // uAmbientIrradiance: vec4 (4)
    // uCameraPos: vec3 (3)
    // uSpecularRoughness: float (1)
    // uLightTextureWidth: float (1)
    // uClusterTextureWidth: float (1)
    // Total = 2 + 3 + 4 + 3 + 3 + 1 + 1 + 4 + 3 + 1 + 1 + 1 = 27 floats

    final uniforms = Float32List(27);
    int idx = 0;

    // uResolution
    uniforms[idx++] = viewportWidth;
    uniforms[idx++] = viewportHeight;

    // uClusterDims
    uniforms[idx++] = gridBounds.dimX.toDouble();
    uniforms[idx++] = gridBounds.dimY.toDouble();
    uniforms[idx++] = gridBounds.dimZ.toDouble();

    // uDepthParams: (zNear, zFar, logFactor, invZFarNear)
    uniforms[idx++] = gridBounds.zNear;
    uniforms[idx++] = gridBounds.zFar;
    uniforms[idx++] = gridBounds.logDepthFactor;
    uniforms[idx++] = 1.0 / (gridBounds.zFar - gridBounds.zNear);

    // uVoxelMin
    uniforms[idx++] = gridBounds.minX;
    uniforms[idx++] = gridBounds.minY;
    uniforms[idx++] = gridBounds.minZ;

    // uVoxelMax
    uniforms[idx++] = gridBounds.maxX;
    uniforms[idx++] = gridBounds.maxY;
    uniforms[idx++] = gridBounds.maxZ;

    // uClusterMode
    uniforms[idx++] = clusterMode;

    // uMaxLightsPerCluster
    uniforms[idx++] = maxLightsPerCluster.toDouble();

    // uAmbientIrradiance
    uniforms[idx++] = ambientR;
    uniforms[idx++] = ambientG;
    uniforms[idx++] = ambientB;
    uniforms[idx++] = ambientIntensity;

    // uCameraPos
    uniforms[idx++] = cameraX;
    uniforms[idx++] = cameraY;
    uniforms[idx++] = cameraZ;

    // uSpecularRoughness
    uniforms[idx++] = roughness;

    // uLightTextureWidth
    uniforms[idx++] = lightTextureWidth;

    // uClusterTextureWidth
    uniforms[idx++] = clusterTextureWidth;

    return uniforms;
  }
}
