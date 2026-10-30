import 'dart:collection';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

// ============================================================================
// ENUMS & TYPES
// ============================================================================

/// Broad category classification for 3D fantasy assets.
enum ModelCategory {
  weapon,
  character,
  building,
  natureProp,
  dungeonProp,
}

/// Level of Detail (LOD) tier for geometry and rendering complexity.
enum LodLevel {
  /// Hero / close-up (0–15m), full geometry and complete PBR maps.
  lod0,

  /// Mid-range (15–40m), 60–75% polygon decimation.
  lod1,

  /// Far range (40–90m), low-poly convex geometry suited for GPU instancing.
  lod2,

  /// Ultra-far (>90m), octahedral billboard or VAT single-draw-call representation.
  impostor,
}

/// Device performance capability tier for dynamic LOD selection.
enum DevicePerformanceTier {
  low,
  medium,
  high,
  ultra,
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

/// Exception thrown when glTF / GLB binary container parsing fails.
class GlbFormatException implements Exception {
  final String message;
  final int? byteOffset;

  const GlbFormatException(this.message, [this.byteOffset]);

  @override
  String toString() => byteOffset != null
      ? 'GlbFormatException: $message (at byte offset $byteOffset)'
      : 'GlbFormatException: $message';
}

/// Exception thrown when Draco compressed payload parsing fails.
class DracoFormatException implements Exception {
  final String message;
  final int? byteOffset;

  const DracoFormatException(this.message, [this.byteOffset]);

  @override
  String toString() => byteOffset != null
      ? 'DracoFormatException: $message (at byte offset $byteOffset)'
      : 'DracoFormatException: $message';
}

// ============================================================================
// 3D MATH & BOUNDS
// ============================================================================

/// Axis-aligned 3D bounding box for spatial queries, culling, and LOD scaling.
class BoundingBox3D {
  final double minX;
  final double minY;
  final double minZ;
  final double maxX;
  final double maxY;
  final double maxZ;

  const BoundingBox3D({
    required this.minX,
    required this.minY,
    required this.minZ,
    required this.maxX,
    required this.maxY,
    required this.maxZ,
  });

  /// Factory creating an empty / zero-size bounding box at origin.
  factory BoundingBox3D.zero() => const BoundingBox3D(
        minX: 0,
        minY: 0,
        minZ: 0,
        maxX: 0,
        maxY: 0,
        maxZ: 0,
      );

  /// Factory creating bounding box from center and extents (half-sizes).
  factory BoundingBox3D.fromCenterAndExtents({
    required double centerX,
    required double centerY,
    required double centerZ,
    required double extentX,
    required double extentY,
    required double extentZ,
  }) {
    return BoundingBox3D(
      minX: centerX - extentX,
      minY: centerY - extentY,
      minZ: centerZ - extentZ,
      maxX: centerX + extentX,
      maxY: centerY + extentY,
      maxZ: centerZ + extentZ,
    );
  }

  /// Factory creating bounding box by encapsulating a list of 3D vertices [x, y, z].
  factory BoundingBox3D.fromPoints(Float32List positions) {
    if (positions.isEmpty) return BoundingBox3D.zero();

    double minX = positions[0];
    double minY = positions[1];
    double minZ = positions[2];
    double maxX = positions[0];
    double maxY = positions[1];
    double maxZ = positions[2];

    for (int i = 0; i < positions.length; i += 3) {
      final double x = positions[i];
      final double y = positions[i + 1];
      final double z = positions[i + 2];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (z < minZ) minZ = z;
      if (z > maxZ) maxZ = z;
    }

    return BoundingBox3D(
      minX: minX,
      minY: minY,
      minZ: minZ,
      maxX: maxX,
      maxY: maxY,
      maxZ: maxZ,
    );
  }

  double get centerX => (minX + maxX) * 0.5;
  double get centerY => (minY + maxY) * 0.5;
  double get centerZ => (minZ + maxZ) * 0.5;

  double get sizeX => maxX - minX;
  double get sizeY => maxY - minY;
  double get sizeZ => maxZ - minZ;

  /// Maximum span across any single coordinate axis.
  double get maxDimension => math.max(sizeX, math.max(sizeY, sizeZ));

  /// Radius of bounding sphere enclosing this box from center.
  double get boundingRadius {
    final double hx = sizeX * 0.5;
    final double hy = sizeY * 0.5;
    final double hz = sizeZ * 0.5;
    return math.sqrt(hx * hx + hy * hy + hz * hz);
  }

  /// Tests if a 3D point lies within this bounding box.
  bool containsPoint(double x, double y, double z) {
    return x >= minX &&
        x <= maxX &&
        y >= minY &&
        y <= maxY &&
        z >= minZ &&
        z <= maxZ;
  }

  /// Tests intersection with another 3D bounding box.
  bool intersects(BoundingBox3D other) {
    return minX <= other.maxX &&
        maxX >= other.minX &&
        minY <= other.maxY &&
        maxY >= other.minY &&
        minZ <= other.maxZ &&
        maxZ >= other.minZ;
  }

  @override
  String toString() =>
      'BoundingBox3D(min: [$minX, $minY, $minZ], max: [$maxX, $maxY, $maxZ], radius: ${boundingRadius.toStringAsFixed(2)})';
}

// ============================================================================
// PBR MATERIAL DESCRIPTOR
// ============================================================================

/// Metadata descriptor for a Physically Based Rendering (PBR) metallic-roughness material.
class PbrMaterialDescriptor {
  final String materialId;
  final String name;
  final String? albedoTexturePath;
  final List<double> baseColorRgba;
  final String? normalTexturePath;
  final String? metallicRoughnessTexturePath;
  final double roughnessFactor;
  final double metallicFactor;
  final String? occlusionTexturePath;
  final double occlusionStrength;
  final String? emissiveTexturePath;
  final List<double> emissiveColorRgb;
  final double emissiveStrength;
  final String alphaMode;
  final bool doubleSided;

  const PbrMaterialDescriptor({
    required this.materialId,
    required this.name,
    this.albedoTexturePath,
    this.baseColorRgba = const <double>[1.0, 1.0, 1.0, 1.0],
    this.normalTexturePath,
    this.metallicRoughnessTexturePath,
    this.roughnessFactor = 0.5,
    this.metallicFactor = 0.0,
    this.occlusionTexturePath,
    this.occlusionStrength = 1.0,
    this.emissiveTexturePath,
    this.emissiveColorRgb = const <double>[0.0, 0.0, 0.0],
    this.emissiveStrength = 1.0,
    this.alphaMode = 'OPAQUE',
    this.doubleSided = false,
  });

  factory PbrMaterialDescriptor.fromJson(Map<String, dynamic> json, String id) {
    final String name = json['name'] as String? ?? id;
    final Map<String, dynamic>? pbr =
        json['pbrMetallicRoughness'] as Map<String, dynamic>?;

    List<double> baseColor = const <double>[1.0, 1.0, 1.0, 1.0];
    if (pbr != null && pbr['baseColorFactor'] is List) {
      baseColor = (pbr['baseColorFactor'] as List<dynamic>)
          .map((dynamic e) => (e as num).toDouble())
          .toList();
    }

    final double roughness =
        pbr != null ? ((pbr['roughnessFactor'] as num?)?.toDouble() ?? 1.0) : 0.5;
    final double metallic =
        pbr != null ? ((pbr['metallicFactor'] as num?)?.toDouble() ?? 1.0) : 0.0;

    List<double> emissive = const <double>[0.0, 0.0, 0.0];
    if (json['emissiveFactor'] is List) {
      emissive = (json['emissiveFactor'] as List<dynamic>)
          .map((dynamic e) => (e as num).toDouble())
          .toList();
    }

    double emissiveStr = 1.0;
    final Map<String, dynamic>? extensions =
        json['extensions'] as Map<String, dynamic>?;
    if (extensions != null &&
        extensions['KHR_materials_emissive_strength'] is Map) {
      final Map<String, dynamic> emExt =
          extensions['KHR_materials_emissive_strength'] as Map<String, dynamic>;
      emissiveStr = (emExt['emissiveStrength'] as num?)?.toDouble() ?? 1.0;
    }

    return PbrMaterialDescriptor(
      materialId: id,
      name: name,
      baseColorRgba: baseColor,
      roughnessFactor: roughness,
      metallicFactor: metallic,
      emissiveColorRgb: emissive,
      emissiveStrength: emissiveStr,
      alphaMode: json['alphaMode'] as String? ?? 'OPAQUE',
      doubleSided: json['doubleSided'] as bool? ?? false,
    );
  }

  bool get hasEmission =>
      emissiveColorRgb.any((double c) => c > 0.001) && emissiveStrength > 0.001;

  @override
  String toString() =>
      'PbrMaterialDescriptor($name, roughness: $roughnessFactor, metallic: $metallicFactor, emissive: $emissiveStrength)';
}

// ============================================================================
// MODEL LOD INFO & METADATA
// ============================================================================

/// Metadata describing a specific LOD variant for a 3D model.
class ModelLodInfo {
  final LodLevel lodLevel;
  final String filePath;
  final int triangleCount;
  final int vertexCount;
  final int fileSizeBytes;
  final bool isDracoCompressed;

  const ModelLodInfo({
    required this.lodLevel,
    required this.filePath,
    required this.triangleCount,
    required this.vertexCount,
    required this.fileSizeBytes,
    this.isDracoCompressed = true,
  });

  @override
  String toString() =>
      'ModelLodInfo($lodLevel: $filePath, tris: $triangleCount, draco: $isDracoCompressed)';
}

/// Complete catalog metadata for a registered 3D asset.
class MeshAssetMetadata {
  final String id;
  final String name;
  final ModelCategory category;
  final String license;
  final String licenseSource;
  final Map<LodLevel, ModelLodInfo> lods;
  final LodLevel defaultLod;
  final Set<String> tags;
  final BoundingBox3D bounds;
  final List<PbrMaterialDescriptor> materials;
  final Map<String, List<double>> sockets;
  final Map<String, dynamic> properties;

  const MeshAssetMetadata({
    required this.id,
    required this.name,
    required this.category,
    required this.license,
    required this.licenseSource,
    required this.lods,
    this.defaultLod = LodLevel.lod0,
    this.tags = const <String>{},
    required this.bounds,
    this.materials = const <PbrMaterialDescriptor>[],
    this.sockets = const <String, List<double>>{},
    this.properties = const <String, dynamic>{},
  });

  bool get isCc0 =>
      license.toUpperCase().contains('CC0') ||
      license.toUpperCase().contains('PUBLIC DOMAIN');

  bool hasLod(LodLevel level) => lods.containsKey(level);

  ModelLodInfo? getLod(LodLevel level) => lods[level];

  int triangleCountFor(LodLevel level) => lods[level]?.triangleCount ?? 0;

  bool isDracoFor(LodLevel level) => lods[level]?.isDracoCompressed ?? false;

  @override
  String toString() =>
      'MeshAssetMetadata($id [$category], lods: ${lods.keys.join(",")}, license: $license)';
}

// ============================================================================
// LOD RESOLUTION ENGINE
// ============================================================================

/// Configuration for distance-based LOD resolution adapted by device performance tier.
class LodResolutionConfig {
  /// Distance thresholds (in meters) for each LOD level per performance tier.
  /// Any distance beyond lod2 falls back to impostor.
  final Map<DevicePerformanceTier, Map<LodLevel, double>> thresholds;

  /// Global multiplier to scale distance thresholds (< 1.0 forces earlier LOD downgrade, > 1.0 extends LOD0 range).
  final double globalDistanceMultiplier;

  const LodResolutionConfig({
    this.thresholds = defaultThresholds,
    this.globalDistanceMultiplier = 1.0,
  });

  static const Map<DevicePerformanceTier, Map<LodLevel, double>>
      defaultThresholds = <DevicePerformanceTier, Map<LodLevel, double>>{
    DevicePerformanceTier.ultra: <LodLevel, double>{
      LodLevel.lod0: 25.0,
      LodLevel.lod1: 60.0,
      LodLevel.lod2: 120.0,
    },
    DevicePerformanceTier.high: <LodLevel, double>{
      LodLevel.lod0: 15.0,
      LodLevel.lod1: 40.0,
      LodLevel.lod2: 90.0,
    },
    DevicePerformanceTier.medium: <LodLevel, double>{
      LodLevel.lod0: 8.0,
      LodLevel.lod1: 25.0,
      LodLevel.lod2: 60.0,
    },
    DevicePerformanceTier.low: <LodLevel, double>{
      LodLevel.lod0: 4.0,
      LodLevel.lod1: 15.0,
      LodLevel.lod2: 35.0,
    },
  };

  /// Resolves the optimal [LodLevel] for given [distance] and [tier].
  ///
  /// [lodBias] can boost or demote distance for individual high-importance entities (e.g. boss hero = 1.5).
  /// [isHero] prioritizes retaining LOD0 closer to the camera.
  LodLevel resolveLevel({
    required double distance,
    required DevicePerformanceTier tier,
    double lodBias = 1.0,
    bool isHero = false,
  }) {
    final Map<LodLevel, double> tierMap =
        thresholds[tier] ?? defaultThresholds[DevicePerformanceTier.medium]!;

    final double effectiveMultiplier =
        globalDistanceMultiplier * (isHero ? 1.5 : 1.0) * lodBias;

    final double lod0Max = (tierMap[LodLevel.lod0] ?? 15.0) * effectiveMultiplier;
    final double lod1Max = (tierMap[LodLevel.lod1] ?? 40.0) * effectiveMultiplier;
    final double lod2Max = (tierMap[LodLevel.lod2] ?? 90.0) * effectiveMultiplier;

    if (distance <= lod0Max) {
      return LodLevel.lod0;
    } else if (distance <= lod1Max) {
      return LodLevel.lod1;
    } else if (distance <= lod2Max) {
      return LodLevel.lod2;
    } else {
      return LodLevel.impostor;
    }
  }
}

/// The concrete result of resolving an asset's LOD.
class LodResolutionResult {
  final MeshAssetMetadata metadata;
  final double requestedDistance;
  final DevicePerformanceTier tier;
  final LodLevel targetLod;
  final LodLevel resolvedLod;
  final ModelLodInfo lodInfo;
  final bool wasFallback;

  const LodResolutionResult({
    required this.metadata,
    required this.requestedDistance,
    required this.tier,
    required this.targetLod,
    required this.resolvedLod,
    required this.lodInfo,
    required this.wasFallback,
  });

  @override
  String toString() =>
      'LodResolutionResult(${metadata.id} @ ${requestedDistance.toStringAsFixed(1)}m: target=$targetLod -> resolved=$resolvedLod, path=${lodInfo.filePath}, fallback=$wasFallback)';
}

// ============================================================================
// DRACO & GLB BINARY PARSER
// ============================================================================

/// Header metadata extracted from Draco bitstream chunk.
class DracoHeaderInfo {
  final String magic;
  final int majorVersion;
  final int minorVersion;
  final int encoderType;
  final int connectivityMethod;
  final int bufferViewOffset;
  final int bufferViewLength;

  const DracoHeaderInfo({
    required this.magic,
    required this.majorVersion,
    required this.minorVersion,
    required this.encoderType,
    required this.connectivityMethod,
    required this.bufferViewOffset,
    required this.bufferViewLength,
  });

  bool get isMesh => encoderType == 1;
  bool get isPointCloud => encoderType == 0;

  @override
  String toString() =>
      'DracoHeaderInfo(v$majorVersion.$minorVersion, encoder: $encoderType, len: $bufferViewLength bytes)';
}

/// In-memory representation of a single submesh primitive.
class ParsedSubmesh {
  final String name;
  final int vertexCount;
  final int indexCount;
  final BoundingBox3D bounds;
  final int materialIndex;
  final bool isDracoCompressed;
  final Float32List? positions;
  final Float32List? normals;
  final Float32List? uvs;
  final Uint32List? indices;

  const ParsedSubmesh({
    required this.name,
    required this.vertexCount,
    required this.indexCount,
    required this.bounds,
    this.materialIndex = 0,
    this.isDracoCompressed = false,
    this.positions,
    this.normals,
    this.uvs,
    this.indices,
  });

  int get triangleCount => indexCount ~/ 3;

  int get approximateMemoryBytes {
    int bytes = 64; // base object
    if (positions != null) bytes += positions!.lengthInBytes;
    if (normals != null) bytes += normals!.lengthInBytes;
    if (uvs != null) bytes += uvs!.lengthInBytes;
    if (indices != null) bytes += indices!.lengthInBytes;
    return bytes;
  }
}

/// Fully parsed, memory-resident 3D model container.
class ParsedModelMesh {
  final String modelId;
  final String sourcePath;
  final bool isDracoCompressed;
  final DracoHeaderInfo? dracoHeader;
  final List<ParsedSubmesh> submeshes;
  final List<PbrMaterialDescriptor> materials;
  final BoundingBox3D bounds;
  final Map<String, dynamic> rawJson;
  final int approximateMemoryBytes;

  const ParsedModelMesh({
    required this.modelId,
    required this.sourcePath,
    required this.isDracoCompressed,
    this.dracoHeader,
    required this.submeshes,
    required this.materials,
    required this.bounds,
    this.rawJson = const <String, dynamic>{},
    required this.approximateMemoryBytes,
  });

  int get totalVertices => submeshes.fold<int>(
      0, (int sum, ParsedSubmesh sub) => sum + sub.vertexCount);

  int get totalIndices => submeshes.fold<int>(
      0, (int sum, ParsedSubmesh sub) => sum + sub.indexCount);

  int get totalTriangles => submeshes.fold<int>(
      0, (int sum, ParsedSubmesh sub) => sum + sub.triangleCount);

  @override
  String toString() =>
      'ParsedModelMesh($modelId, submeshes: ${submeshes.length}, tris: $totalTriangles, draco: $isDracoCompressed, mem: ${(approximateMemoryBytes / 1024).toStringAsFixed(1)} KB)';
}

/// Binary parser for Khronos glTF 2.0 Binary (.glb) files and Draco compressed chunks.
class DracoGlbParser {
  static const int glbMagic = 0x46546C67; // "glTF"
  static const int jsonChunkType = 0x4E4F534A; // "JSON"
  static const int binChunkType = 0x004E4942; // "BIN\0"
  static const String dracoExtension = 'KHR_draco_mesh_compression';

  /// Parses raw byte data of a GLB file into a structured [ParsedModelMesh].
  ParsedModelMesh parse({
    required Uint8List bytes,
    required String modelId,
    String sourcePath = '',
  }) {
    if (bytes.length < 12) {
      throw const GlbFormatException('File too short to contain GLB header', 0);
    }

    final ByteData byteData = ByteData.sublistView(bytes);

    // 1. Verify GLB Header (12 bytes)
    final int magic = byteData.getUint32(0, Endian.little);
    if (magic != glbMagic) {
      throw GlbFormatException(
          'Invalid GLB magic header: 0x${magic.toRadixString(16)}. Expected 0x${glbMagic.toRadixString(16)} ("glTF")',
          0);
    }

    final int version = byteData.getUint32(4, Endian.little);
    if (version != 2) {
      throw GlbFormatException('Unsupported glTF version: $version. Expected 2', 4);
    }

    final int totalLength = byteData.getUint32(8, Endian.little);
    if (bytes.length < totalLength) {
      throw GlbFormatException(
          'Truncated GLB container: byte length is ${bytes.length}, expected $totalLength',
          8);
    }

    // 2. Parse Chunks
    int offset = 12;
    Map<String, dynamic>? gltfJson;
    Uint8List? binBuffer;

    while (offset + 8 <= totalLength) {
      final int chunkLength = byteData.getUint32(offset, Endian.little);
      final int chunkType = byteData.getUint32(offset + 4, Endian.little);
      offset += 8;

      if (offset + chunkLength > bytes.length) {
        throw GlbFormatException(
            'Chunk length exceeds container: chunkLength=$chunkLength, remaining=${bytes.length - offset}',
            offset);
      }

      if (chunkType == jsonChunkType) {
        final String jsonString =
            utf8.decode(bytes.sublist(offset, offset + chunkLength));
        gltfJson = json.decode(jsonString) as Map<String, dynamic>;
      } else if (chunkType == binChunkType) {
        binBuffer = bytes.sublist(offset, offset + chunkLength);
      }

      offset += chunkLength;
      // Chunks are 4-byte aligned
      while (offset % 4 != 0 && offset < totalLength) {
        offset++;
      }
    }

    if (gltfJson == null) {
      throw const GlbFormatException('GLB missing mandatory JSON chunk', 12);
    }

    // 3. Inspect Extensions & Draco Compression
    final List<dynamic> extensionsUsed =
        (gltfJson['extensionsUsed'] as List<dynamic>?) ?? <dynamic>[];
    final bool hasDracoExtension = extensionsUsed.contains(dracoExtension);

    DracoHeaderInfo? dracoHeader;
    bool modelIsDracoCompressed = false;

    final List<dynamic> bufferViews =
        (gltfJson['bufferViews'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> meshes =
        (gltfJson['meshes'] as List<dynamic>?) ?? <dynamic>[];

    // Check primitives for Draco extension
    for (final dynamic mesh in meshes) {
      if (mesh is! Map<String, dynamic>) continue;
      final List<dynamic> primitives =
          (mesh['primitives'] as List<dynamic>?) ?? <dynamic>[];
      for (final dynamic prim in primitives) {
        if (prim is! Map<String, dynamic>) continue;
        final Map<String, dynamic>? exts =
            prim['extensions'] as Map<String, dynamic>?;
        if (exts != null && exts.containsKey(dracoExtension)) {
          modelIsDracoCompressed = true;
          final Map<String, dynamic> dracoExt =
              exts[dracoExtension] as Map<String, dynamic>;
          final int bvIndex = dracoExt['bufferView'] as int? ?? 0;

          if (bvIndex >= 0 && bvIndex < bufferViews.length && binBuffer != null) {
            final Map<String, dynamic> bv =
                bufferViews[bvIndex] as Map<String, dynamic>;
            final int bvOffset = bv['byteOffset'] as int? ?? 0;
            final int bvLength = bv['byteLength'] as int? ?? 0;

            if (bvOffset + bvLength <= binBuffer.length) {
              dracoHeader = _parseDracoHeader(
                binBytes: binBuffer,
                offset: bvOffset,
                length: bvLength,
              );
            }
          }
          break;
        }
      }
      if (modelIsDracoCompressed) break;
    }

    if (hasDracoExtension && !modelIsDracoCompressed) {
      modelIsDracoCompressed = true;
    }

    // 4. Parse Materials
    final List<PbrMaterialDescriptor> materials = <PbrMaterialDescriptor>[];
    final List<dynamic> rawMaterials =
        (gltfJson['materials'] as List<dynamic>?) ?? <dynamic>[];
    for (int i = 0; i < rawMaterials.length; i++) {
      final dynamic mat = rawMaterials[i];
      if (mat is Map<String, dynamic>) {
        materials.add(PbrMaterialDescriptor.fromJson(mat, '${modelId}_mat_$i'));
      }
    }

    // 5. Parse Submeshes & Primitives
    final List<ParsedSubmesh> submeshes = <ParsedSubmesh>[];
    final List<dynamic> accessors =
        (gltfJson['accessors'] as List<dynamic>?) ?? <dynamic>[];

    double globalMinX = double.infinity;
    double globalMinY = double.infinity;
    double globalMinZ = double.infinity;
    double globalMaxX = -double.infinity;
    double globalMaxY = -double.infinity;
    double globalMaxZ = -double.infinity;

    for (int m = 0; m < meshes.length; m++) {
      final dynamic mesh = meshes[m];
      if (mesh is! Map<String, dynamic>) continue;
      final String meshName =
          mesh['name'] as String? ?? '${modelId}_mesh_$m';
      final List<dynamic> primitives =
          (mesh['primitives'] as List<dynamic>?) ?? <dynamic>[];

      for (int p = 0; p < primitives.length; p++) {
        final dynamic prim = primitives[p];
        if (prim is! Map<String, dynamic>) continue;

        final Map<String, dynamic>? primExts =
            prim['extensions'] as Map<String, dynamic>?;
        final bool primIsDraco =
            primExts != null && primExts.containsKey(dracoExtension);

        int vertCount = 0;
        int indCount = 0;
        BoundingBox3D subBounds = BoundingBox3D.zero();

        final Map<String, dynamic>? attributes =
            prim['attributes'] as Map<String, dynamic>?;

        if (attributes != null && attributes.containsKey('POSITION')) {
          final int posAccessorIdx = attributes['POSITION'] as int;
          if (posAccessorIdx >= 0 && posAccessorIdx < accessors.length) {
            final Map<String, dynamic> acc =
                accessors[posAccessorIdx] as Map<String, dynamic>;
            vertCount = acc['count'] as int? ?? 0;

            if (acc['min'] is List && acc['max'] is List) {
              final List<dynamic> minList = acc['min'] as List<dynamic>;
              final List<dynamic> maxList = acc['max'] as List<dynamic>;
              if (minList.length >= 3 && maxList.length >= 3) {
                final double x0 = (minList[0] as num).toDouble();
                final double y0 = (minList[1] as num).toDouble();
                final double z0 = (minList[2] as num).toDouble();
                final double x1 = (maxList[0] as num).toDouble();
                final double y1 = (maxList[1] as num).toDouble();
                final double z1 = (maxList[2] as num).toDouble();

                subBounds = BoundingBox3D(
                  minX: x0,
                  minY: y0,
                  minZ: z0,
                  maxX: x1,
                  maxY: y1,
                  maxZ: z1,
                );

                if (x0 < globalMinX) globalMinX = x0;
                if (y0 < globalMinY) globalMinY = y0;
                if (z0 < globalMinZ) globalMinZ = z0;
                if (x1 > globalMaxX) globalMaxX = x1;
                if (y1 > globalMaxY) globalMaxY = y1;
                if (z1 > globalMaxZ) globalMaxZ = z1;
              }
            }
          }
        }

        if (prim.containsKey('indices')) {
          final int indAccessorIdx = prim['indices'] as int;
          if (indAccessorIdx >= 0 && indAccessorIdx < accessors.length) {
            final Map<String, dynamic> acc =
                accessors[indAccessorIdx] as Map<String, dynamic>;
            indCount = acc['count'] as int? ?? 0;
          }
        }

        // When uncompressed, extract actual positions/indices if available
        Float32List? positions;
        Uint32List? indices;

        if (!primIsDraco && binBuffer != null && attributes != null) {
          positions = _extractPositions(
            attributes: attributes,
            accessors: accessors,
            bufferViews: bufferViews,
            binBuffer: binBuffer,
          );
          indices = _extractIndices(
            prim: prim,
            accessors: accessors,
            bufferViews: bufferViews,
            binBuffer: binBuffer,
          );
        }

        final int matIdx = prim['material'] as int? ?? 0;

        submeshes.add(ParsedSubmesh(
          name: '${meshName}_prim_$p',
          vertexCount: vertCount,
          indexCount: indCount,
          bounds: subBounds,
          materialIndex: matIdx,
          isDracoCompressed: primIsDraco,
          positions: positions,
          indices: indices,
        ));
      }
    }

    final BoundingBox3D modelBounds = (globalMinX != double.infinity)
        ? BoundingBox3D(
            minX: globalMinX,
            minY: globalMinY,
            minZ: globalMinZ,
            maxX: globalMaxX,
            maxY: globalMaxY,
            maxZ: globalMaxZ,
          )
        : BoundingBox3D.zero();

    // Memory estimation: binary chunk + JSON structures
    int memoryEstimate = bytes.length;
    for (final ParsedSubmesh sub in submeshes) {
      memoryEstimate += sub.approximateMemoryBytes;
    }

    return ParsedModelMesh(
      modelId: modelId,
      sourcePath: sourcePath,
      isDracoCompressed: modelIsDracoCompressed,
      dracoHeader: dracoHeader,
      submeshes: submeshes,
      materials: materials,
      bounds: modelBounds,
      rawJson: gltfJson,
      approximateMemoryBytes: memoryEstimate,
    );
  }

  /// Parses Draco bitstream header starting at [offset] within [binBytes].
  static DracoHeaderInfo _parseDracoHeader({
    required Uint8List binBytes,
    required int offset,
    required int length,
  }) {
    if (length < 8 || offset + 8 > binBytes.length) {
      throw DracoFormatException(
          'Draco buffer view too short: length=$length', offset);
    }

    final String magic = utf8.decode(binBytes.sublist(offset, offset + 5),
        allowMalformed: true);

    if (magic != 'DRACO') {
      throw DracoFormatException(
          'Invalid Draco magic: "$magic". Expected "DRACO"', offset);
    }

    final int majorVersion = binBytes[offset + 5];
    final int minorVersion = binBytes[offset + 6];
    final int encoderType = binBytes[offset + 7];
    final int connectivityMethod =
        (length > 8 && offset + 8 < binBytes.length) ? binBytes[offset + 8] : 0;

    return DracoHeaderInfo(
      magic: magic,
      majorVersion: majorVersion,
      minorVersion: minorVersion,
      encoderType: encoderType,
      connectivityMethod: connectivityMethod,
      bufferViewOffset: offset,
      bufferViewLength: length,
    );
  }

  static Float32List? _extractPositions({
    required Map<String, dynamic> attributes,
    required List<dynamic> accessors,
    required List<dynamic> bufferViews,
    required Uint8List binBuffer,
  }) {
    if (!attributes.containsKey('POSITION')) return null;
    final int accIdx = attributes['POSITION'] as int;
    if (accIdx < 0 || accIdx >= accessors.length) return null;

    final Map<String, dynamic> acc = accessors[accIdx] as Map<String, dynamic>;
    final int? bvIdx = acc['bufferView'] as int?;
    if (bvIdx == null || bvIdx < 0 || bvIdx >= bufferViews.length) return null;

    final Map<String, dynamic> bv = bufferViews[bvIdx] as Map<String, dynamic>;
    final int count = acc['count'] as int? ?? 0;
    final int accOffset = acc['byteOffset'] as int? ?? 0;
    final int bvOffset = bv['byteOffset'] as int? ?? 0;
    final int start = bvOffset + accOffset;
    final int byteLength = count * 3 * 4;

    if (start + byteLength > binBuffer.length) return null;

    final Float32List list = Float32List(count * 3);
    final ByteData bd = ByteData.sublistView(binBuffer, start, start + byteLength);
    for (int i = 0; i < count * 3; i++) {
      list[i] = bd.getFloat32(i * 4, Endian.little);
    }
    return list;
  }

  static Uint32List? _extractIndices({
    required Map<String, dynamic> prim,
    required List<dynamic> accessors,
    required List<dynamic> bufferViews,
    required Uint8List binBuffer,
  }) {
    if (!prim.containsKey('indices')) return null;
    final int indIdx = prim['indices'] as int;
    if (indIdx < 0 || indIdx >= accessors.length) return null;

    final Map<String, dynamic> acc = accessors[indIdx] as Map<String, dynamic>;
    final int? bvIdx = acc['bufferView'] as int?;
    if (bvIdx == null || bvIdx < 0 || bvIdx >= bufferViews.length) return null;

    final Map<String, dynamic> bv = bufferViews[bvIdx] as Map<String, dynamic>;
    final int count = acc['count'] as int? ?? 0;
    final int compType = acc['componentType'] as int? ?? 5123; // 5123 = UNSIGNED_SHORT
    final int accOffset = acc['byteOffset'] as int? ?? 0;
    final int bvOffset = bv['byteOffset'] as int? ?? 0;
    final int start = bvOffset + accOffset;

    final Uint32List outIndices = Uint32List(count);

    if (compType == 5123) {
      // 16-bit uint
      final int byteLen = count * 2;
      if (start + byteLen > binBuffer.length) return null;
      final ByteData bd = ByteData.sublistView(binBuffer, start, start + byteLen);
      for (int i = 0; i < count; i++) {
        outIndices[i] = bd.getUint16(i * 2, Endian.little);
      }
    } else if (compType == 5125) {
      // 32-bit uint
      final int byteLen = count * 4;
      if (start + byteLen > binBuffer.length) return null;
      final ByteData bd = ByteData.sublistView(binBuffer, start, start + byteLen);
      for (int i = 0; i < count; i++) {
        outIndices[i] = bd.getUint32(i * 4, Endian.little);
      }
    } else {
      return null;
    }

    return outIndices;
  }
}

// ============================================================================
// HIGH-PERFORMANCE LRU MESH CACHE
// ============================================================================

/// Callback invoked when a mesh is evicted from [ModelMeshCache].
typedef MeshEvictionListener = void Function(String key, ParsedModelMesh mesh);

/// High-throughput Least-Recently-Used (LRU) cache with byte-budget and item limits.
class ModelMeshCache {
  final int maxMemoryBytes;
  final int maxItemCount;
  final MeshEvictionListener? onEvicted;

  final LinkedHashMap<String, ParsedModelMesh> _cache =
      LinkedHashMap<String, ParsedModelMesh>();

  int _currentMemoryBytes = 0;
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _peakMemoryBytes = 0;

  ModelMeshCache({
    this.maxMemoryBytes = 128 * 1024 * 1024, // 128 MB default
    this.maxItemCount = 64,
    this.onEvicted,
  });

  int get currentMemoryBytes => _currentMemoryBytes;
  int get itemCount => _cache.length;
  int get hits => _hits;
  int get misses => _misses;
  int get evictions => _evictions;
  int get peakMemoryBytes => _peakMemoryBytes;

  double get hitRatio =>
      (_hits + _misses) == 0 ? 0.0 : _hits / (_hits + _misses);

  /// Checks if key exists without altering LRU order.
  bool contains(String key) => _cache.containsKey(key);

  /// Retrieves cached mesh and marks as Most Recently Used (MRU).
  ParsedModelMesh? get(String key) {
    final ParsedModelMesh? existing = _cache.remove(key);
    if (existing != null) {
      _cache[key] = existing; // Re-insert at tail (MRU)
      _hits++;
      return existing;
    }
    _misses++;
    return null;
  }

  /// Inserts or updates mesh in cache, enforcing memory and item-count budgets.
  void put(String key, ParsedModelMesh mesh) {
    if (_cache.containsKey(key)) {
      final ParsedModelMesh old = _cache.remove(key)!;
      _currentMemoryBytes -= old.approximateMemoryBytes;
    }

    _cache[key] = mesh;
    _currentMemoryBytes += mesh.approximateMemoryBytes;
    if (_currentMemoryBytes > _peakMemoryBytes) {
      _peakMemoryBytes = _currentMemoryBytes;
    }

    _enforceBudgets();
  }

  /// Removes a specific cached mesh.
  ParsedModelMesh? remove(String key) {
    final ParsedModelMesh? removed = _cache.remove(key);
    if (removed != null) {
      _currentMemoryBytes -= removed.approximateMemoryBytes;
      onEvicted?.call(key, removed);
    }
    return removed;
  }

  /// Purges all entries and notifies eviction listener.
  void clear() {
    if (onEvicted != null) {
      for (final MapEntry<String, ParsedModelMesh> entry in _cache.entries) {
        onEvicted!(entry.key, entry.value);
      }
    }
    _cache.clear();
    _currentMemoryBytes = 0;
  }

  void _enforceBudgets() {
    while (_cache.isNotEmpty &&
        (_currentMemoryBytes > maxMemoryBytes ||
            _cache.length > maxItemCount)) {
      final String oldestKey = _cache.keys.first;
      final ParsedModelMesh evicted = _cache.remove(oldestKey)!;
      _currentMemoryBytes -= evicted.approximateMemoryBytes;
      _evictions++;
      onEvicted?.call(oldestKey, evicted);
    }
  }

  /// Returns unmodifiable view of cached keys in LRU-to-MRU order.
  List<String> get keys => List<String>.unmodifiable(_cache.keys);
}

// ============================================================================
// AGGREGATE STATS
// ============================================================================

/// Aggregated metrics across registry entries and memory cache.
class RegistryStatistics {
  final int totalModels;
  final Map<ModelCategory, int> modelsByCategory;
  final int totalCc0Models;
  final int cachedModelsCount;
  final int cachedMemoryBytes;
  final int maxCacheMemoryBytes;
  final int cacheHits;
  final int cacheMisses;
  final int cacheEvictions;
  final double cacheHitRatio;

  const RegistryStatistics({
    required this.totalModels,
    required this.modelsByCategory,
    required this.totalCc0Models,
    required this.cachedModelsCount,
    required this.cachedMemoryBytes,
    required this.maxCacheMemoryBytes,
    required this.cacheHits,
    required this.cacheMisses,
    required this.cacheEvictions,
    required this.cacheHitRatio,
  });

  @override
  String toString() =>
      'RegistryStats(models: $totalModels [CC0: $totalCc0Models], cached: $cachedModelsCount [${(cachedMemoryBytes / (1024 * 1024)).toStringAsFixed(1)} MB], hitRatio: ${(cacheHitRatio * 100).toStringAsFixed(1)}%)';
}

// ============================================================================
// CENTRAL MESH ASSET REGISTRY
// ============================================================================

/// Central authority indexing all 3D fantasy models, managing LOD resolutions,
/// loading Draco/glTF models, and providing LRU cache management.
class MeshAssetRegistry {
  static final MeshAssetRegistry _singleton = MeshAssetRegistry();
  static MeshAssetRegistry get instance => _singleton;

  // ==========================================================================
  // MODEL ID CONSTANTS
  // ==========================================================================
  static const String idBroadsword = 'wpn_mercenary_broadsword';
  static const String idBattleaxe = 'wpn_executioner_axe';
  static const String idStaff = 'wpn_alchemists_rod';
  static const String idDagger = 'wpn_shadow_shiv';
  static const String idAion2Sword = 'wpn_aion2_dark_fantasy_sword';

  static const String idWarriorKnight = 'char_warrior_knight';
  static const String idSorcerer = 'char_sorcerer_alchemist';
  static const String idBossDemon = 'char_boss_demon';

  static const String idGothicArch = 'bld_gothic_arch';
  static const String idPortcullis = 'bld_portcullis_iron';
  static const String idAion2Pillar = 'bld_aion2_gothic_pillar';

  static const String idTwistedOak = 'nat_twisted_oak';
  static const String idGraniteBoulder = 'nat_granite_boulder';

  static const String idBrazier = 'prop_brazier_iron_embers';
  static const String idFlagstones = 'prop_flagstones_cracked';
  static const String idGargoyle = 'prop_gargoyle_dark_stone';
  static const String idStoneAltar = 'prop_stone_altar';
  static const String idAion2Wings = 'prop_aion2_ethereal_wings';

  // ==========================================================================
  // MODEL ASSET PATH CONSTANTS (Verified Real Files On Disk)
  // ==========================================================================
  // Weapons
  static const String pathSwordLod0 = 'assets/models/weapons/Sword_LOD0.glb';
  static const String pathSwordLod1 = 'assets/models/weapons/Sword_LOD1.glb';
  static const String pathSwordLod2 = 'assets/models/weapons/Sword_LOD2.glb';
  static const String pathSwordImpostor = 'assets/models/weapons/Sword_Impostor.glb';
  static const String pathBroadsword = 'assets/models/weapons/broadsword.glb';
  static const String pathClaymore = 'assets/models/weapons/Claymore.glb';
  static const String pathBattleaxe = 'assets/models/weapons/battleaxe.glb';
  static const String pathMagicStaff = 'assets/models/weapons/magic_staff.glb';
  static const String pathDagger = 'assets/models/weapons/Dagger.glb';
  static const String pathKatanaAntique = 'assets/models/weapons/katana_antique.glb';

  // Characters
  static const String pathWarriorLod0 = 'assets/models/characters/warrior_LOD0.glb';
  static const String pathWarriorLod1 = 'assets/models/characters/warrior_LOD1.glb';
  static const String pathWarriorLod2 = 'assets/models/characters/warrior_LOD2.glb';
  static const String pathWarriorImpostor = 'assets/models/characters/warrior_Impostor.glb';
  static const String pathKnightLod0 = 'assets/models/characters/Knight_LOD0.glb';
  static const String pathKnightLod1 = 'assets/models/characters/Knight_LOD1.glb';
  static const String pathKnightLod2 = 'assets/models/characters/Knight_LOD2.glb';
  static const String pathKnightImpostor = 'assets/models/characters/Knight_Impostor.glb';
  static const String pathMageLod0 = 'assets/models/characters/Mage_LOD0.glb';
  static const String pathMageLod1 = 'assets/models/characters/Mage_LOD1.glb';
  static const String pathMageLod2 = 'assets/models/characters/Mage_LOD2.glb';
  static const String pathMageImpostor = 'assets/models/characters/Mage_Impostor.glb';

  // Monsters / Bosses
  static const String pathDragon = 'assets/models/monsters/dragon.glb';
  static const String pathDragonAttenuation = 'assets/models/monsters/DragonAttenuation.glb';
  static const String pathGolem = 'assets/models/monsters/golem.glb';

  // Architecture & Props
  static const String pathGothicArch = 'assets/models/props/GothicArch_Lancet.glb';
  static const String pathGothicArchLod0 = 'assets/models/props/GothicArch_Lancet_LOD0.glb';
  static const String pathGothicArchLod1 = 'assets/models/props/GothicArch_Lancet_LOD1.glb';
  static const String pathGothicArchLod2 = 'assets/models/props/GothicArch_Lancet_LOD2.glb';
  static const String pathGothicArchImpostor = 'assets/models/props/GothicArch_Lancet_Impostor.glb';

  static const String pathPortcullis = 'assets/models/props/Portcullis_HeavyIron.glb';
  static const String pathPortcullisLod0 = 'assets/models/props/Portcullis_HeavyIron_LOD0.glb';
  static const String pathPortcullisLod1 = 'assets/models/props/Portcullis_HeavyIron_LOD1.glb';
  static const String pathPortcullisLod2 = 'assets/models/props/Portcullis_HeavyIron_LOD2.glb';
  static const String pathPortcullisImpostor = 'assets/models/props/Portcullis_HeavyIron_Impostor.glb';

  static const String pathBrazier = 'assets/models/props/Brazier_IronEmbers.glb';
  static const String pathFlagstones = 'assets/models/props/Flagstones_CrackedTile.glb';
  static const String pathGargoyle = 'assets/models/props/Gargoyle_DarkStone.glb';
  static const String pathStoneAltar = 'assets/models/props/StoneAltar_Ritual.glb';

  // Environment & Nature
  static const String pathOakTree = 'assets/models/environment/oak_tree.glb';
  static const String pathPineTree = 'assets/models/environment/pine_tree.glb';
  static const String pathRockBoulder = 'assets/models/environment/rock_boulder.glb';
  static const String pathCliff = 'assets/models/environment/cliff.glb';

  // Aion 2 High-Fidelity Assets
  static const String pathAion2Sword = 'assets/models/aion2/aion2_dark_fantasy_sword.glb';
  static const String pathAion2SwordLod0 = 'assets/models/aion2/aion2_dark_fantasy_sword_LOD0.glb';
  static const String pathAion2SwordLod1 = 'assets/models/aion2/aion2_dark_fantasy_sword_LOD1.glb';
  static const String pathAion2SwordLod2 = 'assets/models/aion2/aion2_dark_fantasy_sword_LOD2.glb';
  static const String pathAion2SwordImpostor = 'assets/models/aion2/aion2_dark_fantasy_sword_Impostor.glb';

  static const String pathAion2Wings = 'assets/models/aion2/aion2_ethereal_wings.glb';
  static const String pathAion2WingsLod0 = 'assets/models/aion2/aion2_ethereal_wings_LOD0.glb';
  static const String pathAion2WingsLod1 = 'assets/models/aion2/aion2_ethereal_wings_LOD1.glb';
  static const String pathAion2WingsLod2 = 'assets/models/aion2/aion2_ethereal_wings_LOD2.glb';
  static const String pathAion2WingsImpostor = 'assets/models/aion2/aion2_ethereal_wings_Impostor.glb';

  static const String pathAion2Pillar = 'assets/models/aion2/aion2_gothic_dungeon_pillar.glb';
  static const String pathAion2PillarLod0 = 'assets/models/aion2/aion2_gothic_dungeon_pillar_LOD0.glb';
  static const String pathAion2PillarLod1 = 'assets/models/aion2/aion2_gothic_dungeon_pillar_LOD1.glb';
  static const String pathAion2PillarLod2 = 'assets/models/aion2/aion2_gothic_dungeon_pillar_LOD2.glb';
  static const String pathAion2PillarImpostor = 'assets/models/aion2/aion2_gothic_dungeon_pillar_Impostor.glb';

  final Map<String, MeshAssetMetadata> _registry =
      <String, MeshAssetMetadata>{};
  final Map<ModelCategory, Set<String>> _byCategory =
      <ModelCategory, Set<String>>{};
  final Map<String, Set<String>> _byTag = <String, Set<String>>{};

  final ModelMeshCache cache;
  final DracoGlbParser parser;
  final LodResolutionConfig lodConfig;

  MeshAssetRegistry({
    ModelMeshCache? cache,
    DracoGlbParser? parser,
    LodResolutionConfig? lodConfig,
  })  : cache = cache ?? ModelMeshCache(),
        parser = parser ?? DracoGlbParser(),
        lodConfig = lodConfig ?? const LodResolutionConfig() {
    _registerDefaultCc0Catalog();
  }

  // --------------------------------------------------------------------------
  // REGISTRATION & QUERY API
  // --------------------------------------------------------------------------

  /// Registers a model's metadata into the central registry.
  void register(MeshAssetMetadata metadata) {
    _registry[metadata.id] = metadata;

    _byCategory
        .putIfAbsent(metadata.category, () => <String>{})
        .add(metadata.id);

    for (final String tag in metadata.tags) {
      _byTag.putIfAbsent(tag.toLowerCase(), () => <String>{}).add(metadata.id);
    }
  }

  /// Removes a model from registry.
  bool unregister(String id) {
    final MeshAssetMetadata? existing = _registry.remove(id);
    if (existing == null) return false;

    _byCategory[existing.category]?.remove(id);
    for (final String tag in existing.tags) {
      _byTag[tag.toLowerCase()]?.remove(id);
    }
    return true;
  }

  /// Retrieves metadata for a model ID.
  MeshAssetMetadata? get(String id) => _registry[id];

  /// Checks if a model ID is registered.
  bool contains(String id) => _registry.containsKey(id);

  /// Returns all registered assets.
  List<MeshAssetMetadata> getAll() =>
      List<MeshAssetMetadata>.unmodifiable(_registry.values);

  /// Queries all assets belonging to a specific category.
  List<MeshAssetMetadata> getByCategory(ModelCategory category) {
    final Set<String>? ids = _byCategory[category];
    if (ids == null) return const <MeshAssetMetadata>[];
    return ids.map((String id) => _registry[id]!).toList();
  }

  /// Queries all assets annotated with a specific keyword tag.
  List<MeshAssetMetadata> getByTag(String tag) {
    final Set<String>? ids = _byTag[tag.toLowerCase()];
    if (ids == null) return const <MeshAssetMetadata>[];
    return ids.map((String id) => _registry[id]!).toList();
  }

  /// Comprehensive search filtering by query text, category, tag, and CC0 license flag.
  List<MeshAssetMetadata> search({
    String? query,
    ModelCategory? category,
    String? tag,
    bool? cc0Only,
  }) {
    return _registry.values.where((MeshAssetMetadata item) {
      if (category != null && item.category != category) return false;
      if (cc0Only == true && !item.isCc0) return false;
      if (tag != null && !item.tags.contains(tag.toLowerCase())) return false;
      if (query != null && query.isNotEmpty) {
        final String q = query.toLowerCase();
        final bool matchesId = item.id.toLowerCase().contains(q);
        final bool matchesName = item.name.toLowerCase().contains(q);
        final bool matchesTag = item.tags.any((String t) => t.contains(q));
        if (!matchesId && !matchesName && !matchesTag) return false;
      }
      return true;
    }).toList();
  }

  /// Finds model metadata that contains the specified asset [filePath].
  MeshAssetMetadata? getByPath(String filePath) {
    for (final MeshAssetMetadata meta in _registry.values) {
      for (final ModelLodInfo lod in meta.lods.values) {
        if (lod.filePath == filePath) return meta;
      }
    }
    return null;
  }

  /// Returns a set of all registered asset file paths across all models and LODs.
  Set<String> getAllAssetPaths() {
    final Set<String> paths = <String>{};
    for (final MeshAssetMetadata meta in _registry.values) {
      for (final ModelLodInfo lod in meta.lods.values) {
        paths.add(lod.filePath);
      }
    }
    return paths;
  }


  // --------------------------------------------------------------------------
  // LOD RESOLVER API
  // --------------------------------------------------------------------------

  /// Resolves the optimal LOD level and asset path for a model given [distance] and [tier].
  LodResolutionResult resolveLod(
    String modelId, {
    required double distance,
    required DevicePerformanceTier tier,
    double lodBias = 1.0,
    bool isHero = false,
  }) {
    final MeshAssetMetadata? metadata = _registry[modelId];
    if (metadata == null) {
      throw ArgumentError('Model "$modelId" is not registered in MeshAssetRegistry');
    }

    final LodLevel targetLod = lodConfig.resolveLevel(
      distance: distance,
      tier: tier,
      lodBias: lodBias,
      isHero: isHero,
    );

    // If exact target LOD is available, return it
    if (metadata.hasLod(targetLod)) {
      return LodResolutionResult(
        metadata: metadata,
        requestedDistance: distance,
        tier: tier,
        targetLod: targetLod,
        resolvedLod: targetLod,
        lodInfo: metadata.getLod(targetLod)!,
        wasFallback: false,
      );
    }

    // Fallback ladder: search nearest available LOD
    LodLevel fallbackLod = metadata.defaultLod;
    final List<LodLevel> searchOrder = _getFallbackLodLadder(targetLod);

    for (final LodLevel candidate in searchOrder) {
      if (metadata.hasLod(candidate)) {
        fallbackLod = candidate;
        break;
      }
    }

    return LodResolutionResult(
      metadata: metadata,
      requestedDistance: distance,
      tier: tier,
      targetLod: targetLod,
      resolvedLod: fallbackLod,
      lodInfo: metadata.getLod(fallbackLod)!,
      wasFallback: fallbackLod != targetLod,
    );
  }

  static List<LodLevel> _getFallbackLodLadder(LodLevel target) {
    switch (target) {
      case LodLevel.lod0:
        return const <LodLevel>[LodLevel.lod0, LodLevel.lod1, LodLevel.lod2, LodLevel.impostor];
      case LodLevel.lod1:
        return const <LodLevel>[LodLevel.lod1, LodLevel.lod0, LodLevel.lod2, LodLevel.impostor];
      case LodLevel.lod2:
        return const <LodLevel>[LodLevel.lod2, LodLevel.lod1, LodLevel.lod0, LodLevel.impostor];
      case LodLevel.impostor:
        return const <LodLevel>[LodLevel.impostor, LodLevel.lod2, LodLevel.lod1, LodLevel.lod0];
    }
  }

  // --------------------------------------------------------------------------
  // MODEL LOADING & CACHING PIPELINE
  // --------------------------------------------------------------------------

  /// Loads, parses, and caches a model mesh.
  ///
  /// Can resolve LOD automatically if [distance] and [tier] are provided.
  Future<ParsedModelMesh> loadMesh(
    String modelId, {
    LodLevel? lod,
    double? distance,
    DevicePerformanceTier? tier,
    double lodBias = 1.0,
    bool isHero = false,
  }) async {
    final MeshAssetMetadata? metadata = _registry[modelId];
    if (metadata == null) {
      throw ArgumentError('Model "$modelId" is not registered in MeshAssetRegistry');
    }

    LodLevel activeLod = lod ?? metadata.defaultLod;
    if (distance != null && tier != null) {
      final LodResolutionResult resolution = resolveLod(
        modelId,
        distance: distance,
        tier: tier,
        lodBias: lodBias,
        isHero: isHero,
      );
      activeLod = resolution.resolvedLod;
    }

    final ModelLodInfo? lodInfo = metadata.getLod(activeLod) ??
        metadata.getLod(metadata.defaultLod);

    if (lodInfo == null) {
      throw StateError('No valid LOD variant found for model "$modelId"');
    }

    final String cacheKey = '${modelId}_${activeLod.name}';
    final ParsedModelMesh? cached = cache.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    // Load file bytes
    final Uint8List fileBytes = await _loadBytesForPath(lodInfo.filePath);

    final ParsedModelMesh parsed = parser.parse(
      bytes: fileBytes,
      modelId: modelId,
      sourcePath: lodInfo.filePath,
    );

    cache.put(cacheKey, parsed);
    return parsed;
  }

  /// Parses and caches mesh directly from raw binary data.
  ParsedModelMesh loadMeshFromBytes(
    Uint8List bytes, {
    required String modelId,
    String? cacheKey,
    String sourcePath = '',
  }) {
    final String key = cacheKey ?? modelId;
    final ParsedModelMesh? cached = cache.get(key);
    if (cached != null) {
      return cached;
    }

    final ParsedModelMesh parsed = parser.parse(
      bytes: bytes,
      modelId: modelId,
      sourcePath: sourcePath,
    );

    cache.put(key, parsed);
    return parsed;
  }

  /// Direct file loader for standalone or toolchain execution.
  Future<ParsedModelMesh> loadMeshFromFile(
    io.File file, {
    required String modelId,
    String? cacheKey,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    return loadMeshFromBytes(
      bytes,
      modelId: modelId,
      cacheKey: cacheKey ?? modelId,
      sourcePath: file.path,
    );
  }

  Future<Uint8List> _loadBytesForPath(String path) async {
    // 1. Try direct local filesystem read (works in test / desktop CLI runs)
    try {
      final io.File file = io.File(path);
      if (file.existsSync()) {
        return await file.readAsBytes();
      }
    } catch (_) {
      // Fall through to asset bundle
    }

    // 2. Try Flutter rootBundle asset loader
    try {
      final ByteData bd = await rootBundle.load(path);
      return bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    } catch (e) {
      throw io.FileSystemException('Failed to load asset binary for path: $path', path);
    }
  }

  /// Returns runtime registry and cache statistics.
  RegistryStatistics getStats() {
    final Map<ModelCategory, int> byCat = <ModelCategory, int>{};
    int cc0Count = 0;

    for (final MeshAssetMetadata meta in _registry.values) {
      byCat[meta.category] = (byCat[meta.category] ?? 0) + 1;
      if (meta.isCc0) cc0Count++;
    }

    return RegistryStatistics(
      totalModels: _registry.length,
      modelsByCategory: byCat,
      totalCc0Models: cc0Count,
      cachedModelsCount: cache.itemCount,
      cachedMemoryBytes: cache.currentMemoryBytes,
      maxCacheMemoryBytes: cache.maxMemoryBytes,
      cacheHits: cache.hits,
      cacheMisses: cache.misses,
      cacheEvictions: cache.evictions,
      cacheHitRatio: cache.hitRatio,
    );
  }

  /// Clears in-memory mesh cache.
  void clearCache() => cache.clear();

  // --------------------------------------------------------------------------
  // PRE-SEEDED CC0 FANTASY CATALOG
  // --------------------------------------------------------------------------

  void _registerDefaultCc0Catalog() {
    // ------------------------------------------------------------------------
    // 1. WEAPONS (CC0)
    // ------------------------------------------------------------------------
    register(const MeshAssetMetadata(
      id: idBroadsword,
      name: 'Mercenary Broadsword (Claymore)',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Fantasy Pack',
      bounds: BoundingBox3D(
        minX: -0.15,
        minY: -0.05,
        minZ: -0.10,
        maxX: 0.15,
        maxY: 1.45,
        maxZ: 0.10,
      ),
      tags: <String>{'weapon', 'sword', 'claymore', 'melee', 'steel', 'two_handed'},
      sockets: <String, List<double>>{
        'socket_grip': <double>[0.0, 0.20, 0.0],
        'socket_tip': <double>[0.0, 1.40, 0.0],
        'socket_trail_base': <double>[0.0, 0.35, 0.0],
        'socket_trail_tip': <double>[0.0, 1.45, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathSwordLod0,
          triangleCount: 4280,
          vertexCount: 2210,
          fileSizeBytes: 14120,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: pathSwordLod1,
          triangleCount: 1350,
          vertexCount: 710,
          fileSizeBytes: 9580,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: pathSwordLod2,
          triangleCount: 320,
          vertexCount: 180,
          fileSizeBytes: 6404,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: pathSwordImpostor,
          triangleCount: 12,
          vertexCount: 8,
          fileSizeBytes: 7272,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idBattleaxe,
      name: 'Executioner Battleaxe',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons',
      bounds: BoundingBox3D(
        minX: -0.35,
        minY: -0.08,
        minZ: -0.08,
        maxX: 0.35,
        maxY: 1.55,
        maxZ: 0.08,
      ),
      tags: <String>{'weapon', 'axe', 'battleaxe', 'two_handed', 'iron', 'heavy'},
      sockets: <String, List<double>>{
        'socket_grip': <double>[0.0, 0.30, 0.0],
        'socket_blade_edge': <double>[0.30, 1.35, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathBattleaxe,
          triangleCount: 1892,
          vertexCount: 3558,
          fileSizeBytes: 101596,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idStaff,
      name: 'Alchemists Runic Staff',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius CC0 Mage Armory',
      bounds: BoundingBox3D(
        minX: -0.18,
        minY: -0.06,
        minZ: -0.06,
        maxX: 0.18,
        maxY: 1.85,
        maxZ: 0.06,
      ),
      tags: <String>{'weapon', 'staff', 'wand', 'magic', 'runic', 'crystal'},
      sockets: <String, List<double>>{
        'socket_grip': <double>[0.0, 0.85, 0.0],
        'socket_spell_crystal': <double>[0.0, 1.78, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathMagicStaff,
          triangleCount: 1640,
          vertexCount: 980,
          fileSizeBytes: 41960,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idDagger,
      name: 'Shadow Curved Dagger',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Kenney CC0 Rogue Armory',
      bounds: BoundingBox3D(
        minX: -0.08,
        minY: -0.03,
        minZ: -0.03,
        maxX: 0.08,
        maxY: 0.55,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'dagger', 'shiv', 'rogue', 'assassin', 'curved'},
      sockets: <String, List<double>>{
        'socket_grip': <double>[0.0, 0.12, 0.0],
        'socket_tip': <double>[0.03, 0.52, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathDagger,
          triangleCount: 726,
          vertexCount: 1395,
          fileSizeBytes: 43740,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idAion2Sword,
      name: 'Aion 2 Dark Fantasy Runic Greatsword',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Aion 2 Dark Fantasy 3D Asset Studio',
      bounds: BoundingBox3D(
        minX: -0.20,
        minY: -0.05,
        minZ: -0.12,
        maxX: 0.20,
        maxY: 1.60,
        maxZ: 0.12,
      ),
      tags: <String>{'weapon', 'sword', 'greatsword', 'aion2', 'runic', 'dark_fantasy'},
      sockets: <String, List<double>>{
        'socket_grip': <double>[0.0, 0.25, 0.0],
        'socket_tip': <double>[0.0, 1.55, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathAion2SwordLod0,
          triangleCount: 8400,
          vertexCount: 4400,
          fileSizeBytes: 1849724,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: pathAion2SwordLod1,
          triangleCount: 2800,
          vertexCount: 1500,
          fileSizeBytes: 1848592,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: pathAion2SwordLod2,
          triangleCount: 750,
          vertexCount: 410,
          fileSizeBytes: 1847272,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: pathAion2SwordImpostor,
          triangleCount: 16,
          vertexCount: 10,
          fileSizeBytes: 1845928,
        ),
      },
    ));

    // ------------------------------------------------------------------------
    // 2. CHARACTERS (CC0)
    // ------------------------------------------------------------------------
    register(const MeshAssetMetadata(
      id: idWarriorKnight,
      name: 'Warrior Knight (Heavy Plate)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.45,
        minY: 0.0,
        minZ: -0.30,
        maxX: 0.45,
        maxY: 1.95,
        maxZ: 0.35,
      ),
      tags: <String>{'character', 'warrior', 'knight', 'hero', 'humanoid', 'armor'},
      sockets: <String, List<double>>{
        'socket_hand_r': <double>[0.38, 0.95, 0.15],
        'socket_hand_l': <double>[-0.38, 0.95, 0.15],
        'socket_head': <double>[0.0, 1.75, 0.05],
        'socket_chest': <double>[0.0, 1.25, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathWarriorLod0,
          triangleCount: 14200,
          vertexCount: 7450,
          fileSizeBytes: 2883928,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: pathWarriorLod1,
          triangleCount: 4200,
          vertexCount: 2210,
          fileSizeBytes: 2862012,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: pathWarriorLod2,
          triangleCount: 980,
          vertexCount: 520,
          fileSizeBytes: 2839344,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: pathWarriorImpostor,
          triangleCount: 16,
          vertexCount: 10,
          fileSizeBytes: 50344,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idSorcerer,
      name: 'Sorcerer Alchemist (Robe & Mantle)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius CC0 Fantasy Cast',
      bounds: BoundingBox3D(
        minX: -0.40,
        minY: 0.0,
        minZ: -0.30,
        maxX: 0.40,
        maxY: 1.88,
        maxZ: 0.35,
      ),
      tags: <String>{'character', 'sorcerer', 'alchemist', 'mage', 'robe', 'humanoid'},
      sockets: <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.12],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathMageLod0,
          triangleCount: 12600,
          vertexCount: 6600,
          fileSizeBytes: 2875996,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: pathMageLod1,
          triangleCount: 3700,
          vertexCount: 1950,
          fileSizeBytes: 2855276,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: pathMageLod2,
          triangleCount: 860,
          vertexCount: 460,
          fileSizeBytes: 2835624,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: pathMageImpostor,
          triangleCount: 16,
          vertexCount: 10,
          fileSizeBytes: 39644,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idBossDemon,
      name: 'Dungeon Dragon Titan (Winged Colossus)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -1.80,
        minY: 0.0,
        minZ: -1.20,
        maxX: 1.80,
        maxY: 4.50,
        maxZ: 1.40,
      ),
      tags: <String>{'character', 'boss', 'demon', 'dragon', 'titan', 'wings', 'horns', 'colossus'},
      sockets: <String, List<double>>{
        'socket_mouth_breath': <double>[0.0, 3.80, 0.65],
        'socket_hand_r_smash': <double>[1.45, 1.80, 0.40],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathDragon,
          triangleCount: 7800,
          vertexCount: 4200,
          fileSizeBytes: 324860,
        ),
      },
    ));

    // ------------------------------------------------------------------------
    // 3. BUILDINGS & ARCHITECTURE (CC0)
    // ------------------------------------------------------------------------
    register(const MeshAssetMetadata(
      id: idGothicArch,
      name: 'Gothic Lancet Arch (Stone Colonnade)',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.60,
        minY: 0.0,
        minZ: -0.45,
        maxX: 1.60,
        maxY: 4.80,
        maxZ: 0.45,
      ),
      tags: <String>{'building', 'arch', 'gothic', 'cathedral', 'portal', 'stone'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathGothicArch,
          triangleCount: 3120,
          vertexCount: 1680,
          fileSizeBytes: 74336,
          isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: pathGothicArchLod1,
          triangleCount: 1560,
          vertexCount: 840,
          fileSizeBytes: 66524,
          isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: pathGothicArchLod2,
          triangleCount: 420,
          vertexCount: 240,
          fileSizeBytes: 50696,
          isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: pathGothicArchImpostor,
          triangleCount: 12,
          vertexCount: 8,
          fileSizeBytes: 24776,
          isDracoCompressed: true,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idPortcullis,
      name: 'Iron Dungeon Portcullis (Spiked Grate)',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.70,
        minY: 0.0,
        minZ: -0.20,
        maxX: 1.70,
        maxY: 3.60,
        maxZ: 0.20,
      ),
      tags: <String>{'building', 'portcullis', 'gate', 'iron', 'spikes', 'dungeon'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathPortcullis,
          triangleCount: 2240,
          vertexCount: 1190,
          fileSizeBytes: 50796,
          isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: pathPortcullisLod1,
          triangleCount: 1120,
          vertexCount: 600,
          fileSizeBytes: 48928,
          isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: pathPortcullisLod2,
          triangleCount: 310,
          vertexCount: 180,
          fileSizeBytes: 42188,
          isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: pathPortcullisImpostor,
          triangleCount: 12,
          vertexCount: 8,
          fileSizeBytes: 24688,
          isDracoCompressed: true,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idAion2Pillar,
      name: 'Aion 2 Gothic Dungeon Pillar',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Aion 2 Dark Fantasy 3D Asset Studio',
      bounds: BoundingBox3D(
        minX: -0.80,
        minY: 0.0,
        minZ: -0.80,
        maxX: 0.80,
        maxY: 5.20,
        maxZ: 0.80,
      ),
      tags: <String>{'building', 'pillar', 'gothic', 'dungeon', 'aion2', 'stone'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathAion2PillarLod0,
          triangleCount: 6200,
          vertexCount: 3300,
          fileSizeBytes: 928860,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: pathAion2PillarLod1,
          triangleCount: 2100,
          vertexCount: 1100,
          fileSizeBytes: 927216,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: pathAion2PillarLod2,
          triangleCount: 580,
          vertexCount: 320,
          fileSizeBytes: 924556,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: pathAion2PillarImpostor,
          triangleCount: 16,
          vertexCount: 10,
          fileSizeBytes: 921608,
        ),
      },
    ));

    // ------------------------------------------------------------------------
    // 4. NATURE PROPS (CC0)
    // ------------------------------------------------------------------------
    register(const MeshAssetMetadata(
      id: idTwistedOak,
      name: 'Twisted Dark Fantasy Oak',
      category: ModelCategory.natureProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven CC0 Nature Pack',
      bounds: BoundingBox3D(
        minX: -2.80,
        minY: 0.0,
        minZ: -2.80,
        maxX: 2.80,
        maxY: 6.20,
        maxZ: 2.80,
      ),
      tags: <String>{'nature', 'tree', 'oak', 'twisted', 'dark_fantasy', 'vegetation'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathOakTree,
          triangleCount: 5800,
          vertexCount: 3100,
          fileSizeBytes: 158708,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idGraniteBoulder,
      name: 'Mossy Cracked Granite Boulder',
      category: ModelCategory.natureProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'AmbientCG CC0 Rock Scans',
      bounds: BoundingBox3D(
        minX: -1.20,
        minY: 0.0,
        minZ: -1.10,
        maxX: 1.20,
        maxY: 1.65,
        maxZ: 1.10,
      ),
      tags: <String>{'nature', 'rock', 'boulder', 'granite', 'moss', 'stone'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathRockBoulder,
          triangleCount: 2400,
          vertexCount: 1250,
          fileSizeBytes: 22888,
        ),
      },
    ));

    // ------------------------------------------------------------------------
    // 5. DUNGEON PROPS (CC0)
    // ------------------------------------------------------------------------
    register(const MeshAssetMetadata(
      id: idBrazier,
      name: 'Iron Brazier with Embers',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -0.65,
        minY: 0.0,
        minZ: -0.65,
        maxX: 0.65,
        maxY: 1.25,
        maxZ: 0.65,
      ),
      tags: <String>{'dungeon', 'brazier', 'fire', 'light', 'iron', 'embers', 'torch'},
      sockets: <String, List<double>>{
        'socket_flame_center': <double>[0.0, 1.05, 0.0],
        'socket_smoke_emitter': <double>[0.0, 1.20, 0.0],
      },
      materials: <PbrMaterialDescriptor>[
        PbrMaterialDescriptor(
          materialId: 'mat_iron_scratched',
          name: 'PBR_CastIron_Corroded',
          roughnessFactor: 0.75,
          metallicFactor: 0.90,
        ),
        PbrMaterialDescriptor(
          materialId: 'mat_embers_glow',
          name: 'PBR_GlowingEmbers',
          roughnessFactor: 0.95,
          metallicFactor: 0.05,
          emissiveColorRgb: <double>[1.0, 0.42, 0.05],
          emissiveStrength: 5.5,
        ),
      ],
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathBrazier,
          triangleCount: 1840,
          vertexCount: 960,
          fileSizeBytes: 45624,
          isDracoCompressed: true,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idFlagstones,
      name: 'Cracked Dungeon Flagstones (Modular Floor Tile)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.0,
        minY: -0.05,
        minZ: -1.0,
        maxX: 1.0,
        maxY: 0.05,
        maxZ: 1.0,
      ),
      tags: <String>{'dungeon', 'floor', 'tile', 'stone', 'cracked', 'flagstone', 'modular'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathFlagstones,
          triangleCount: 2680,
          vertexCount: 1420,
          fileSizeBytes: 43964,
          isDracoCompressed: true,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idGargoyle,
      name: 'Demon Gargoyle on Pedestal',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -0.55,
        minY: 0.0,
        minZ: -0.60,
        maxX: 0.55,
        maxY: 1.45,
        maxZ: 0.60,
      ),
      tags: <String>{'dungeon', 'gargoyle', 'stone', 'statue', 'pedestal', 'demon'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathGargoyle,
          triangleCount: 1960,
          vertexCount: 1040,
          fileSizeBytes: 33936,
          isDracoCompressed: true,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idStoneAltar,
      name: 'Sacrificial Stone Altar',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.10,
        minY: 0.0,
        minZ: -0.65,
        maxX: 1.10,
        maxY: 0.95,
        maxZ: 0.65,
      ),
      tags: <String>{'dungeon', 'altar', 'stone', 'ritual', 'sacrificial', 'runes'},
      sockets: <String, List<double>>{
        'socket_offering_center': <double>[0.0, 0.95, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathStoneAltar,
          triangleCount: 1720,
          vertexCount: 910,
          fileSizeBytes: 51332,
          isDracoCompressed: true,
        ),
      },
    ));

    register(const MeshAssetMetadata(
      id: idAion2Wings,
      name: 'Aion 2 Ethereal Daeva Wings',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Aion 2 Dark Fantasy 3D Asset Studio',
      bounds: BoundingBox3D(
        minX: -1.60,
        minY: -0.20,
        minZ: -0.50,
        maxX: 1.60,
        maxY: 2.20,
        maxZ: 0.50,
      ),
      tags: <String>{'dungeon', 'wings', 'ethereal', 'daeva', 'aion2', 'feathers'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: pathAion2WingsLod0,
          triangleCount: 7500,
          vertexCount: 3900,
          fileSizeBytes: 1211076,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: pathAion2WingsLod1,
          triangleCount: 2400,
          vertexCount: 1300,
          fileSizeBytes: 1206352,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: pathAion2WingsLod2,
          triangleCount: 650,
          vertexCount: 360,
          fileSizeBytes: 1200644,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: pathAion2WingsImpostor,
          triangleCount: 16,
          vertexCount: 10,
          fileSizeBytes: 1194260,
        ),
      },
    ));


    register(MeshAssetMetadata(
      id: 'char_barbarian',
      name: 'Barbarian Berserker',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.53,
        maxX: 0.97,
        maxY: 2.19,
        maxZ: 0.74,
      ),
      tags: <String>{'character', 'barbarian', 'berserker', 'warrior', 'melee'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Barbarian_LOD0.glb',
          triangleCount: 6543,
          vertexCount: 5987,
          fileSizeBytes: 2883928, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/Barbarian_LOD1.glb',
          triangleCount: 3268,
          vertexCount: 3735,
          fileSizeBytes: 2862012, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/Barbarian_LOD2.glb',
          triangleCount: 1298,
          vertexCount: 1762,
          fileSizeBytes: 2839344, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/Barbarian_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 50352, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_barbarian_master',
      name: 'Barbarian Berserker (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.53,
        maxX: 0.97,
        maxY: 2.19,
        maxZ: 0.74,
      ),
      tags: <String>{'character', 'barbarian', 'berserker', 'warrior', 'melee', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Barbarian.glb',
          triangleCount: 6543,
          vertexCount: 5922,
          fileSizeBytes: 3613268,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_knight',
      name: 'Heavy Plate Knight',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.54,
        maxX: 0.97,
        maxY: 2.31,
        maxZ: 0.71,
      ),
      tags: <String>{'character', 'knight', 'paladin', 'plate', 'armor'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Knight_LOD0.glb',
          triangleCount: 6952,
          vertexCount: 7153,
          fileSizeBytes: 2896532, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/Knight_LOD1.glb',
          triangleCount: 3473,
          vertexCount: 4438,
          fileSizeBytes: 2870680, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/Knight_LOD2.glb',
          triangleCount: 1381,
          vertexCount: 2079,
          fileSizeBytes: 2844248, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/Knight_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 45044, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_knight_master',
      name: 'Heavy Plate Knight (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.54,
        maxX: 0.97,
        maxY: 2.31,
        maxZ: 0.71,
      ),
      tags: <String>{'character', 'knight', 'paladin', 'plate', 'armor', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Knight.glb',
          triangleCount: 6952,
          vertexCount: 7024,
          fileSizeBytes: 3659532,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_knight_crusader',
      name: 'Crusader Knight',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -3.4,
        minY: -0.0,
        minZ: -0.79,
        maxX: 3.4,
        maxY: 5.6,
        maxZ: 0.59,
      ),
      tags: <String>{'character', 'knight', 'crusader', 'holy'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/KnightCharacter_LOD0.glb',
          triangleCount: 956,
          vertexCount: 2060,
          fileSizeBytes: 306084, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/KnightCharacter_LOD1.glb',
          triangleCount: 478,
          vertexCount: 1102,
          fileSizeBytes: 294380, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/KnightCharacter_LOD2.glb',
          triangleCount: 191,
          vertexCount: 465,
          fileSizeBytes: 286064, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/KnightCharacter_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 37976, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_knight_crusader_master',
      name: 'Crusader Knight (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.03,
        minY: -0.01,
        minZ: -0.0,
        maxX: 0.03,
        maxY: 0.01,
        maxZ: 0.06,
      ),
      tags: <String>{'character', 'knight', 'crusader', 'holy', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/KnightCharacter.glb',
          triangleCount: 956,
          vertexCount: 2058,
          fileSizeBytes: 393060,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_skeleton_mage',
      name: 'Crypt Skeleton Mage',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.42,
        minZ: -0.85,
        maxX: 0.97,
        maxY: 2.17,
        maxZ: 0.89,
      ),
      tags: <String>{'character', 'skeleton', 'undead', 'mage', 'crypt'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Skeleton_Mage_LOD0.glb',
          triangleCount: 4588,
          vertexCount: 4116,
          fileSizeBytes: 3917400, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/Skeleton_Mage_LOD1.glb',
          triangleCount: 2292,
          vertexCount: 2519,
          fileSizeBytes: 3900784, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/Skeleton_Mage_LOD2.glb',
          triangleCount: 913,
          vertexCount: 1167,
          fileSizeBytes: 3884420, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/Skeleton_Mage_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 40632, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_skeleton_mage_master',
      name: 'Crypt Skeleton Mage (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.42,
        minZ: -0.85,
        maxX: 0.97,
        maxY: 2.17,
        maxZ: 0.89,
      ),
      tags: <String>{'character', 'skeleton', 'undead', 'mage', 'crypt', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Skeleton_Mage.glb',
          triangleCount: 4588,
          vertexCount: 4056,
          fileSizeBytes: 4761048,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_skeleton_warrior',
      name: 'Crypt Skeleton Warrior',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.76,
        maxX: 0.97,
        maxY: 2.17,
        maxZ: 0.7,
      ),
      tags: <String>{'character', 'skeleton', 'undead', 'warrior', 'crypt'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Skeleton_Warrior_LOD0.glb',
          triangleCount: 5934,
          vertexCount: 6364,
          fileSizeBytes: 3947300, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/Skeleton_Warrior_LOD1.glb',
          triangleCount: 2967,
          vertexCount: 4185,
          fileSizeBytes: 3924520, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/Skeleton_Warrior_LOD2.glb',
          triangleCount: 1183,
          vertexCount: 1902,
          fileSizeBytes: 3896924, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/Skeleton_Warrior_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 45256, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_skeleton_warrior_master',
      name: 'Crypt Skeleton Warrior (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.76,
        maxX: 0.97,
        maxY: 2.17,
        maxZ: 0.7,
      ),
      tags: <String>{'character', 'skeleton', 'undead', 'warrior', 'crypt', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Skeleton_Warrior.glb',
          triangleCount: 5934,
          vertexCount: 6117,
          fileSizeBytes: 4863620,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_soldier',
      name: 'Infantry Soldier',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.92,
        minY: -0.0,
        minZ: -0.22,
        maxX: 0.92,
        maxY: 1.83,
        maxZ: 0.22,
      ),
      tags: <String>{'character', 'soldier', 'infantry', 'guard', 'armor'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Soldier_LOD0.glb',
          triangleCount: 11376,
          vertexCount: 7434,
          fileSizeBytes: 1067624, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/Soldier_LOD1.glb',
          triangleCount: 5687,
          vertexCount: 4257,
          fileSizeBytes: 1006028, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/Soldier_LOD2.glb',
          triangleCount: 2275,
          vertexCount: 2082,
          fileSizeBytes: 952864, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/Soldier_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 35972, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_soldier_master',
      name: 'Infantry Soldier (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -92.39,
        minY: -22.48,
        minZ: -0.04,
        maxX: 92.41,
        maxY: 21.9,
        maxZ: 183.18,
      ),
      tags: <String>{'character', 'soldier', 'infantry', 'guard', 'armor', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Soldier.glb',
          triangleCount: 11376,
          vertexCount: 7434,
          fileSizeBytes: 2160468,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_archer',
      name: 'Elven Marksman Archer',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.51,
        maxX: 0.97,
        maxY: 2.27,
        maxZ: 0.54,
      ),
      tags: <String>{'character', 'archer', 'ranger', 'bow', 'elf'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/archer_LOD0.glb',
          triangleCount: 8900,
          vertexCount: 7901,
          fileSizeBytes: 117664, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/archer_LOD1.glb',
          triangleCount: 4448,
          vertexCount: 4919,
          fileSizeBytes: 91456, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/archer_LOD2.glb',
          triangleCount: 1777,
          vertexCount: 2359,
          fileSizeBytes: 61700, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/archer_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 46128, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_archer_master',
      name: 'Elven Marksman Archer (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.51,
        maxX: 0.97,
        maxY: 2.27,
        maxZ: 0.54,
      ),
      tags: <String>{'character', 'archer', 'ranger', 'bow', 'elf', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/archer.glb',
          triangleCount: 8900,
          vertexCount: 7734,
          fileSizeBytes: 484712,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_druid',
      name: 'Sylvan Forest Druid',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -1.04,
        minY: -0.0,
        minZ: -0.61,
        maxX: 1.02,
        maxY: 2.75,
        maxZ: 0.61,
      ),
      tags: <String>{'character', 'druid', 'nature', 'magic', 'staff'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/druid_LOD0.glb',
          triangleCount: 7784,
          vertexCount: 7790,
          fileSizeBytes: 120296, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/druid_LOD1.glb',
          triangleCount: 3891,
          vertexCount: 5020,
          fileSizeBytes: 93864, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/druid_LOD2.glb',
          triangleCount: 1554,
          vertexCount: 2391,
          fileSizeBytes: 62888, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/druid_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 47436, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_druid_master',
      name: 'Sylvan Forest Druid (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -1.04,
        minY: 0,
        minZ: -0.61,
        maxX: 1.02,
        maxY: 2.75,
        maxZ: 0.61,
      ),
      tags: <String>{'character', 'druid', 'nature', 'magic', 'staff', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/druid.glb',
          triangleCount: 7784,
          vertexCount: 7481,
          fileSizeBytes: 465800,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_hero',
      name: 'Chosen Realm Hero',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.92,
        minY: -0.0,
        minZ: -0.22,
        maxX: 0.92,
        maxY: 1.83,
        maxZ: 0.22,
      ),
      tags: <String>{'character', 'hero', 'champion', 'adventurer'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/hero_LOD0.glb',
          triangleCount: 11376,
          vertexCount: 7434,
          fileSizeBytes: 1067624, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/hero_LOD1.glb',
          triangleCount: 5687,
          vertexCount: 4257,
          fileSizeBytes: 1006028, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/hero_LOD2.glb',
          triangleCount: 2275,
          vertexCount: 2082,
          fileSizeBytes: 952864, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/hero_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 35960, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_hero_master',
      name: 'Chosen Realm Hero (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -92.39,
        minY: -22.48,
        minZ: -0.04,
        maxX: 92.41,
        maxY: 21.9,
        maxZ: 183.18,
      ),
      tags: <String>{'character', 'hero', 'champion', 'adventurer', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/hero.glb',
          triangleCount: 11376,
          vertexCount: 7434,
          fileSizeBytes: 2160468,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_marksman',
      name: 'Master Crossbow Marksman',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.62,
        maxX: 0.97,
        maxY: 2.22,
        maxZ: 0.77,
      ),
      tags: <String>{'character', 'marksman', 'crossbow', 'sniper'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/marksman_LOD0.glb',
          triangleCount: 7655,
          vertexCount: 8350,
          fileSizeBytes: 303952, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/marksman_LOD1.glb',
          triangleCount: 3826,
          vertexCount: 5636,
          fileSizeBytes: 275936, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/marksman_LOD2.glb',
          triangleCount: 1529,
          vertexCount: 2673,
          fileSizeBytes: 237536, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/marksman_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 48276, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_marksman_master',
      name: 'Master Crossbow Marksman (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: 0,
        minZ: -0.62,
        maxX: 0.97,
        maxY: 2.22,
        maxZ: 0.77,
      ),
      tags: <String>{'character', 'marksman', 'crossbow', 'sniper', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/marksman.glb',
          triangleCount: 7655,
          vertexCount: 8070,
          fileSizeBytes: 664844,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_paladin',
      name: 'Order of the Sun Paladin',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -3.4,
        minY: -0.0,
        minZ: -0.79,
        maxX: 3.4,
        maxY: 5.6,
        maxZ: 0.59,
      ),
      tags: <String>{'character', 'paladin', 'holy', 'templar', 'plate'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/paladin_LOD0.glb',
          triangleCount: 956,
          vertexCount: 2060,
          fileSizeBytes: 306084, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/paladin_LOD1.glb',
          triangleCount: 478,
          vertexCount: 1102,
          fileSizeBytes: 294380, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/paladin_LOD2.glb',
          triangleCount: 191,
          vertexCount: 465,
          fileSizeBytes: 286064, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/paladin_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 37944, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_paladin_master',
      name: 'Order of the Sun Paladin (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.03,
        minY: -0.01,
        minZ: -0.0,
        maxX: 0.03,
        maxY: 0.01,
        maxZ: 0.06,
      ),
      tags: <String>{'character', 'paladin', 'holy', 'templar', 'plate', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/paladin.glb',
          triangleCount: 956,
          vertexCount: 2058,
          fileSizeBytes: 393060,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_ranger',
      name: 'Highland Forest Ranger',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.51,
        maxX: 0.97,
        maxY: 2.27,
        maxZ: 0.54,
      ),
      tags: <String>{'character', 'ranger', 'scout', 'forest', 'bow'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/ranger_LOD0.glb',
          triangleCount: 8900,
          vertexCount: 7901,
          fileSizeBytes: 117664, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/ranger_LOD1.glb',
          triangleCount: 4448,
          vertexCount: 4919,
          fileSizeBytes: 91456, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/ranger_LOD2.glb',
          triangleCount: 1777,
          vertexCount: 2359,
          fileSizeBytes: 61700, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/ranger_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 46128, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_ranger_master',
      name: 'Highland Forest Ranger (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.51,
        maxX: 0.97,
        maxY: 2.27,
        maxZ: 0.54,
      ),
      tags: <String>{'character', 'ranger', 'scout', 'forest', 'bow', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/ranger.glb',
          triangleCount: 8900,
          vertexCount: 7734,
          fileSizeBytes: 484712,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_rogue',
      name: 'Shadow Infiltrator Rogue',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.5,
        maxX: 0.97,
        maxY: 2.19,
        maxZ: 1.16,
      ),
      tags: <String>{'character', 'rogue', 'shadow', 'assassin', 'stealth'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/rogue_LOD0.glb',
          triangleCount: 6377,
          vertexCount: 5979,
          fileSizeBytes: 2881140, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/rogue_LOD1.glb',
          triangleCount: 3186,
          vertexCount: 3641,
          fileSizeBytes: 2859388, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/rogue_LOD2.glb',
          triangleCount: 1269,
          vertexCount: 1729,
          fileSizeBytes: 2838504, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/rogue_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 50632, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_rogue_master',
      name: 'Shadow Infiltrator Rogue (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.5,
        maxX: 0.97,
        maxY: 2.19,
        maxZ: 1.16,
      ),
      tags: <String>{'character', 'rogue', 'shadow', 'assassin', 'stealth', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/rogue.glb',
          triangleCount: 6377,
          vertexCount: 5901,
          fileSizeBytes: 3616284,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_rogue_hooded',
      name: 'Hooded Night Assassin',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.57,
        maxX: 0.97,
        maxY: 2.25,
        maxZ: 1.16,
      ),
      tags: <String>{'character', 'rogue', 'assassin', 'hooded', 'daggers'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/rogue_hooded_LOD0.glb',
          triangleCount: 6035,
          vertexCount: 5662,
          fileSizeBytes: 2878492, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/rogue_hooded_LOD1.glb',
          triangleCount: 3014,
          vertexCount: 3424,
          fileSizeBytes: 2857440, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/rogue_hooded_LOD2.glb',
          triangleCount: 1200,
          vertexCount: 1589,
          fileSizeBytes: 2837244, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/rogue_hooded_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 49208, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_rogue_hooded_master',
      name: 'Hooded Night Assassin (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.57,
        maxX: 0.97,
        maxY: 2.25,
        maxZ: 1.16,
      ),
      tags: <String>{'character', 'rogue', 'assassin', 'hooded', 'daggers', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/rogue_hooded.glb',
          triangleCount: 6035,
          vertexCount: 5586,
          fileSizeBytes: 3597652,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_witch',
      name: 'Occult Coven Witch',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.84,
        maxX: 0.97,
        maxY: 2.62,
        maxZ: 0.76,
      ),
      tags: <String>{'character', 'witch', 'occult', 'magic', 'curse'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/witch_LOD0.glb',
          triangleCount: 6210,
          vertexCount: 4913,
          fileSizeBytes: 84504, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/witch_LOD1.glb',
          triangleCount: 3103,
          vertexCount: 2971,
          fileSizeBytes: 66420, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/witch_LOD2.glb',
          triangleCount: 1238,
          vertexCount: 1485,
          fileSizeBytes: 49988, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/witch_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 42880, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_witch_master',
      name: 'Occult Coven Witch (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.84,
        maxX: 0.97,
        maxY: 2.62,
        maxZ: 0.76,
      ),
      tags: <String>{'character', 'witch', 'occult', 'magic', 'curse', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/witch.glb',
          triangleCount: 6210,
          vertexCount: 4866,
          fileSizeBytes: 320316,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_wizard',
      name: 'Grand Arcane Wizard',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -1.04,
        minY: -0.0,
        minZ: -0.61,
        maxX: 1.02,
        maxY: 2.75,
        maxZ: 0.61,
      ),
      tags: <String>{'character', 'wizard', 'arcane', 'mage', 'sorcerer'},
      sockets: const <String, List<double>>{
        'socket_hand_r': <double>[0.35, 0.90, 0.15],
        'socket_hand_l': <double>[-0.35, 0.90, 0.15],
        'socket_head': <double>[0.0, 1.70, 0.05],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/wizard_LOD0.glb',
          triangleCount: 7784,
          vertexCount: 7790,
          fileSizeBytes: 120296, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/characters/wizard_LOD1.glb',
          triangleCount: 3891,
          vertexCount: 5020,
          fileSizeBytes: 93864, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/characters/wizard_LOD2.glb',
          triangleCount: 1554,
          vertexCount: 2391,
          fileSizeBytes: 62888, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/characters/wizard_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 47440, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_wizard_master',
      name: 'Grand Arcane Wizard (Master High-Poly)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -1.04,
        minY: 0,
        minZ: -0.61,
        maxX: 1.02,
        maxY: 2.75,
        maxZ: 0.61,
      ),
      tags: <String>{'character', 'wizard', 'arcane', 'mage', 'sorcerer', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/wizard.glb',
          triangleCount: 7784,
          vertexCount: 7481,
          fileSizeBytes: 465800,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_warrior_master',
      name: 'Vanguard Warrior (Master)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.53,
        maxX: 0.97,
        maxY: 2.19,
        maxZ: 0.74,
      ),
      tags: const <String>{'character', 'master', 'humanoid'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/warrior.glb',
          triangleCount: 6543,
          vertexCount: 5922,
          fileSizeBytes: 3613268,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'char_mage_master',
      name: 'Sorcerer Mage (Master)',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Quaternius / KayKit CC0 Animated Characters',
      bounds: BoundingBox3D(
        minX: -1.05,
        minY: -1.16,
        minZ: -1.07,
        maxX: 1.05,
        maxY: 2.2,
        maxZ: 1.02,
      ),
      tags: const <String>{'character', 'master', 'humanoid'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/characters/Mage.glb',
          triangleCount: 5683,
          vertexCount: 5279,
          fileSizeBytes: 3589240,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_dragon_attenuation',
      name: 'Volumetric Attenuation Dragon Boss',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -7.05,
        minY: -3.15,
        minZ: -9.94,
        maxX: 7.05,
        maxY: 3.15,
        maxZ: 1.43,
      ),
      tags: <String>{'character', 'boss', 'dragon', 'titan', 'attenuation'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/DragonAttenuation.glb',
          triangleCount: 134995,
          vertexCount: 139379,
          fileSizeBytes: 6401616,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_golem',
      name: 'Iron Stone Golem',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -32767,
        minY: -32767,
        minZ: -27011,
        maxX: 32767,
        maxY: 32767,
        maxZ: 27011,
      ),
      tags: <String>{'character', 'monster', 'golem', 'stone', 'boss'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/golem.glb',
          triangleCount: 7156,
          vertexCount: 8185,
          fileSizeBytes: 292776,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_spider',
      name: 'Dungeon Cave Spider',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.03,
        minY: -0.03,
        minZ: -0.0,
        maxX: 0.03,
        maxY: 0.03,
        maxZ: 0.02,
      ),
      tags: <String>{'character', 'monster', 'spider', 'beast'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/Spider.glb',
          triangleCount: 2712,
          vertexCount: 5461,
          fileSizeBytes: 449008,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_wasp',
      name: 'Giant Stinger Wasp',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.01,
        minZ: 0.0,
        maxX: 0.02,
        maxY: 0.01,
        maxZ: 0.04,
      ),
      tags: <String>{'character', 'monster', 'wasp', 'insect', 'flying'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/Wasp.glb',
          triangleCount: 3734,
          vertexCount: 7472,
          fileSizeBytes: 441256,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_character_zombie',
      name: 'Rotting Crypt Zombie',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.28,
        minY: -0.2,
        minZ: -0.16,
        maxX: 0.28,
        maxY: 0.4,
        maxZ: 0.18,
      ),
      tags: <String>{'character', 'monster', 'zombie', 'undead'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/character-zombie.glb',
          triangleCount: 1078,
          vertexCount: 1992,
          fileSizeBytes: 245500,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_elemental',
      name: 'Fire Elemental Spirit',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.68,
        minY: -0.75,
        minZ: -0.66,
        maxX: 0.68,
        maxY: 0.92,
        maxZ: 0.66,
      ),
      tags: <String>{'character', 'monster', 'elemental', 'fire', 'spirit'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/elemental.glb',
          triangleCount: 10432,
          vertexCount: 6312,
          fileSizeBytes: 255292,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_ghost',
      name: 'Specter Wraith',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.27,
        minY: -0.11,
        minZ: -0.24,
        maxX: 0.27,
        maxY: 0.55,
        maxZ: 0.24,
      ),
      tags: <String>{'character', 'monster', 'ghost', 'wraith', 'specter'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/ghost.glb',
          triangleCount: 413,
          vertexCount: 593,
          fileSizeBytes: 114016,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_goblin',
      name: 'Goblin Scout Skirmisher',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -32767,
        minY: -11937,
        minZ: -29983,
        maxX: 32767,
        maxY: 11937,
        maxZ: 29983,
      ),
      tags: <String>{'character', 'monster', 'goblin', 'humanoid'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/goblin.glb',
          triangleCount: 2912,
          vertexCount: 2738,
          fileSizeBytes: 48360,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_orc',
      name: 'Orc Vanguard Berserker',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -32767,
        minY: -32767,
        minZ: -22442,
        maxX: 32767,
        maxY: 32767,
        maxZ: 22442,
      ),
      tags: <String>{'character', 'monster', 'orc', 'brute', 'humanoid'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/orc.glb',
          triangleCount: 7344,
          vertexCount: 4382,
          fileSizeBytes: 176892,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_skeleton_archer',
      name: 'Skeleton Bone Archer',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -1.12,
        minZ: -0.58,
        maxX: 0.97,
        maxY: 2.17,
        maxZ: 0.57,
      ),
      tags: <String>{'character', 'monster', 'skeleton', 'archer', 'undead'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/skeleton_archer.glb',
          triangleCount: 5278,
          vertexCount: 5259,
          fileSizeBytes: 4827024,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_skeleton_mage',
      name: 'Tomb Skeleton Sorcerer',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.42,
        minZ: -0.85,
        maxX: 0.97,
        maxY: 2.17,
        maxZ: 0.89,
      ),
      tags: <String>{'character', 'monster', 'skeleton', 'mage', 'undead'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/skeleton_mage.glb',
          triangleCount: 4588,
          vertexCount: 4056,
          fileSizeBytes: 4761048,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_skeleton_warrior',
      name: 'Tomb Skeleton Raider',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.97,
        minY: -0.0,
        minZ: -0.76,
        maxX: 0.97,
        maxY: 2.17,
        maxZ: 0.7,
      ),
      tags: <String>{'character', 'monster', 'skeleton', 'warrior', 'undead'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/skeleton_warrior.glb',
          triangleCount: 5934,
          vertexCount: 6117,
          fileSizeBytes: 4863620,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_slime',
      name: 'Toxic Cavern Slime',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -1.27,
        minY: -0.01,
        minZ: -1.53,
        maxX: 1.27,
        maxY: 1.93,
        maxZ: 1.53,
      ),
      tags: <String>{'character', 'monster', 'slime', 'ooze'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/slime.glb',
          triangleCount: 1440,
          vertexCount: 2908,
          fileSizeBytes: 192132,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_wolf',
      name: 'Shadow Dire Wolf',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.03,
        minZ: -0.0,
        maxX: 0.01,
        maxY: 0.03,
        maxZ: 0.03,
      ),
      tags: <String>{'character', 'monster', 'wolf', 'beast', 'predator'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/wolf.glb',
          triangleCount: 1962,
          vertexCount: 3994,
          fileSizeBytes: 608660,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'mon_zombie',
      name: 'Plague Walker Zombie',
      category: ModelCategory.character,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Quaternius Dark Fantasy Models',
      bounds: BoundingBox3D(
        minX: -0.28,
        minY: -0.2,
        minZ: -0.16,
        maxX: 0.28,
        maxY: 0.4,
        maxZ: 0.18,
      ),
      tags: <String>{'character', 'monster', 'zombie', 'plague', 'undead'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/monsters/zombie.glb',
          triangleCount: 1078,
          vertexCount: 1992,
          fileSizeBytes: 245500,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_brazier_lods',
      name: 'Iron Brazier with Embers (LOD Suite)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -0.59,
        minY: -0.02,
        minZ: -0.55,
        maxX: 0.6,
        maxY: 1.04,
        maxZ: 0.55,
      ),
      tags: <String>{'dungeon', 'brazier', 'fire'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/Brazier_IronEmbers_LOD0.glb',
          triangleCount: 952,
          vertexCount: 1207,
          fileSizeBytes: 45624, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/props/Brazier_IronEmbers_LOD1.glb',
          triangleCount: 476,
          vertexCount: 819,
          fileSizeBytes: 42408, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/props/Brazier_IronEmbers_LOD2.glb',
          triangleCount: 238,
          vertexCount: 403,
          fileSizeBytes: 38560, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/props/Brazier_IronEmbers_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 34636, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_brazier_lods_multilod',
      name: 'Iron Brazier with Embers (LOD Suite) (MultiLOD Container)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -0.59,
        minY: -0.02,
        minZ: -0.57,
        maxX: 0.6,
        maxY: 1.04,
        maxZ: 0.58,
      ),
      tags: <String>{'dungeon', 'brazier', 'fire', 'multilod'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/Brazier_IronEmbers_MultiLOD.glb',
          triangleCount: 1668,
          vertexCount: 2433,
          fileSizeBytes: 59928, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_flagstones_lods',
      name: 'Cracked Flagstones Floor (LOD Suite)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.25,
        minY: -0.1,
        minZ: -1.25,
        maxX: 1.39,
        maxY: 0.15,
        maxZ: 1.25,
      ),
      tags: <String>{'dungeon', 'flagstones', 'tile'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/Flagstones_CrackedTile_LOD0.glb',
          triangleCount: 3132,
          vertexCount: 2784,
          fileSizeBytes: 43964, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/props/Flagstones_CrackedTile_LOD1.glb',
          triangleCount: 1566,
          vertexCount: 1866,
          fileSizeBytes: 41660, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/props/Flagstones_CrackedTile_LOD2.glb',
          triangleCount: 783,
          vertexCount: 1107,
          fileSizeBytes: 35116, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/props/Flagstones_CrackedTile_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 24948, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_flagstones_lods_multilod',
      name: 'Cracked Flagstones Floor (LOD Suite) (MultiLOD Container)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.25,
        minY: -0.1,
        minZ: -1.25,
        maxX: 1.39,
        maxY: 0.4,
        maxZ: 1.25,
      ),
      tags: <String>{'dungeon', 'flagstones', 'tile', 'multilod'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/Flagstones_CrackedTile_MultiLOD.glb',
          triangleCount: 5483,
          vertexCount: 5761,
          fileSizeBytes: 73432, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_gargoyle_lods',
      name: 'Demon Gargoyle Statue (LOD Suite)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -0.63,
        minY: 0,
        minZ: -0.45,
        maxX: 0.63,
        maxY: 1.62,
        maxZ: 0.45,
      ),
      tags: <String>{'dungeon', 'gargoyle', 'statue'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/Gargoyle_DarkStone_LOD0.glb',
          triangleCount: 1064,
          vertexCount: 1044,
          fileSizeBytes: 33936, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/props/Gargoyle_DarkStone_LOD1.glb',
          triangleCount: 532,
          vertexCount: 706,
          fileSizeBytes: 31436, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/props/Gargoyle_DarkStone_LOD2.glb',
          triangleCount: 266,
          vertexCount: 436,
          fileSizeBytes: 28964, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/props/Gargoyle_DarkStone_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 24788, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_gargoyle_lods_multilod',
      name: 'Demon Gargoyle Statue (LOD Suite) (MultiLOD Container)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -0.63,
        minY: 0,
        minZ: -0.45,
        maxX: 0.63,
        maxY: 1.62,
        maxZ: 0.45,
      ),
      tags: <String>{'dungeon', 'gargoyle', 'statue', 'multilod'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/Gargoyle_DarkStone_MultiLOD.glb',
          triangleCount: 1864,
          vertexCount: 2190,
          fileSizeBytes: 47316, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_stone_altar_lods',
      name: 'Sacrificial Stone Altar (LOD Suite)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.63,
        minY: 0,
        minZ: -0.88,
        maxX: 1.63,
        maxY: 1.17,
        maxZ: 0.88,
      ),
      tags: <String>{'dungeon', 'altar', 'ritual'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/StoneAltar_Ritual_LOD0.glb',
          triangleCount: 2932,
          vertexCount: 2493,
          fileSizeBytes: 51332, isDracoCompressed: true,
        ),
        LodLevel.lod1: ModelLodInfo(
          lodLevel: LodLevel.lod1,
          filePath: 'assets/models/props/StoneAltar_Ritual_LOD1.glb',
          triangleCount: 1466,
          vertexCount: 1635,
          fileSizeBytes: 48884, isDracoCompressed: true,
        ),
        LodLevel.lod2: ModelLodInfo(
          lodLevel: LodLevel.lod2,
          filePath: 'assets/models/props/StoneAltar_Ritual_LOD2.glb',
          triangleCount: 733,
          vertexCount: 960,
          fileSizeBytes: 43240, isDracoCompressed: true,
        ),
        LodLevel.impostor: ModelLodInfo(
          lodLevel: LodLevel.impostor,
          filePath: 'assets/models/props/StoneAltar_Ritual_Impostor.glb',
          triangleCount: 2,
          vertexCount: 4,
          fileSizeBytes: 35024, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_stone_altar_lods_multilod',
      name: 'Sacrificial Stone Altar (LOD Suite) (MultiLOD Container)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.63,
        minY: 0,
        minZ: -0.88,
        maxX: 1.63,
        maxY: 1.17,
        maxZ: 0.88,
      ),
      tags: <String>{'dungeon', 'altar', 'ritual', 'multilod'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/StoneAltar_Ritual_MultiLOD.glb',
          triangleCount: 5133,
          vertexCount: 5092,
          fileSizeBytes: 75960, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_gothic_arch_hero_lod0',
      name: 'Gothic Lancet Arch (Hero LOD0)',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -2.8,
        minY: 0,
        minZ: -0.34,
        maxX: 2.8,
        maxY: 4.71,
        maxZ: 0.34,
      ),
      tags: <String>{'building', 'arch', 'gothic', 'lod0'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/GothicArch_Lancet_LOD0.glb',
          triangleCount: 8412,
          vertexCount: 7360,
          fileSizeBytes: 74336, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_gothic_arch_multilod',
      name: 'Gothic Lancet Arch (MultiLOD Container)',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -2.8,
        minY: 0,
        minZ: -0.34,
        maxX: 2.8,
        maxY: 4.71,
        maxZ: 0.34,
      ),
      tags: <String>{'building', 'arch', 'gothic', 'multilod'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/GothicArch_Lancet_MultiLOD.glb',
          triangleCount: 14723,
          vertexCount: 15376,
          fileSizeBytes: 144532, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_portcullis_hero_lod0',
      name: 'Iron Dungeon Portcullis (Hero LOD0)',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.3,
        minY: 0,
        minZ: -0.1,
        maxX: 1.3,
        maxY: 3.44,
        maxZ: 0.1,
      ),
      tags: <String>{'building', 'portcullis', 'iron', 'lod0'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/Portcullis_HeavyIron_LOD0.glb',
          triangleCount: 4868,
          vertexCount: 4856,
          fileSizeBytes: 50796, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_portcullis_multilod',
      name: 'Iron Dungeon Portcullis (MultiLOD Container)',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Procedural Dark Fantasy Props Architect (Blender MCP)',
      bounds: BoundingBox3D(
        minX: -1.3,
        minY: 0,
        minZ: -0.1,
        maxX: 1.3,
        maxY: 3.44,
        maxZ: 0.1,
      ),
      tags: <String>{'building', 'portcullis', 'iron', 'multilod'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/props/Portcullis_HeavyIron_MultiLOD.glb',
          triangleCount: 8521,
          vertexCount: 10370,
          fileSizeBytes: 95096, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_chest_gold',
      name: 'Gilded Royal Treasure Chest',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.01,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.01,
        maxZ: 0.0,
      ),
      tags: <String>{'dungeon', 'chest', 'gold', 'loot', 'treasure'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/Chest_gold.glb',
          triangleCount: 436,
          vertexCount: 860,
          fileSizeBytes: 29924,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_chest_wood',
      name: 'Reinforced Wooden Chest',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.85,
        minY: -0.17,
        minZ: -0.6,
        maxX: 0.85,
        maxY: 0.8,
        maxZ: 1.31,
      ),
      tags: <String>{'dungeon', 'chest', 'wood', 'loot'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/chest.glb',
          triangleCount: 728,
          vertexCount: 1204,
          fileSizeBytes: 81412,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_crate_wood',
      name: 'Supply Wooden Crate',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -1.09,
        minY: -0.0,
        minZ: -1.16,
        maxX: 1.0,
        maxY: 2.14,
        maxZ: 1.09,
      ),
      tags: <String>{'dungeon', 'crate', 'storage', 'wood'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/crate.glb',
          triangleCount: 1331,
          vertexCount: 2457,
          fileSizeBytes: 103704,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_barrel_wood',
      name: 'Ale Storage Barrel',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.9,
        minY: 0.0,
        minZ: -0.9,
        maxX: 0.9,
        maxY: 2.0,
        maxZ: 0.9,
      ),
      tags: <String>{'dungeon', 'barrel', 'ale', 'wood', 'prop'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/barrel.glb',
          triangleCount: 561,
          vertexCount: 745,
          fileSizeBytes: 44292,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_altar_stone',
      name: 'Ancient Stone Offering Altar',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.52,
        minY: 0.0,
        minZ: -0.33,
        maxX: 0.52,
        maxY: 0.49,
        maxZ: 0.33,
      ),
      tags: <String>{'dungeon', 'altar', 'stone', 'ancient'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/altar-stone.glb',
          triangleCount: 166,
          vertexCount: 300,
          fileSizeBytes: 17164,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_fire_basket',
      name: 'Hanging Iron Fire Basket',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.21,
        minY: 0.0,
        minZ: -0.21,
        maxX: 0.21,
        maxY: 0.17,
        maxZ: 0.21,
      ),
      tags: <String>{'dungeon', 'fire', 'basket', 'light'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/fire-basket.glb',
          triangleCount: 196,
          vertexCount: 328,
          fileSizeBytes: 18740,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_wall_torch',
      name: 'Wall Mounted Dungeon Torch',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.28,
        minY: -0.38,
        minZ: -0.0,
        maxX: 0.28,
        maxY: 0.68,
        maxZ: 0.62,
      ),
      tags: <String>{'dungeon', 'torch', 'fire', 'wall'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/torch.glb',
          triangleCount: 278,
          vertexCount: 452,
          fileSizeBytes: 33220,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_column_broken',
      name: 'Broken Marble Column',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.01,
        minZ: -0.0,
        maxX: 0.01,
        maxY: 0.02,
        maxZ: 0.01,
      ),
      tags: <String>{'building', 'column', 'ruins', 'marble', 'pillar'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/Column_Broken.glb',
          triangleCount: 140,
          vertexCount: 272,
          fileSizeBytes: 9064,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_column_large',
      name: 'Grand Dungeon Column',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.2,
        minY: 0.0,
        minZ: -0.2,
        maxX: 0.2,
        maxY: 1.13,
        maxZ: 0.2,
      ),
      tags: <String>{'building', 'column', 'pillar', 'stone'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/column-large.glb',
          triangleCount: 394,
          vertexCount: 696,
          fileSizeBytes: 37540,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_stone_pillar',
      name: 'Monolithic Stone Pillar',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.75,
        minY: 0,
        minZ: -0.75,
        maxX: 0.75,
        maxY: 4,
        maxZ: 0.75,
      ),
      tags: <String>{'building', 'pillar', 'stone', 'monolith'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/pillar.glb',
          triangleCount: 136,
          vertexCount: 241,
          fileSizeBytes: 25552,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_pillar_obelisk',
      name: 'Runic Stone Obelisk',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.17,
        minY: 0.0,
        minZ: -0.17,
        maxX: 0.17,
        maxY: 1.01,
        maxZ: 0.17,
      ),
      tags: <String>{'building', 'obelisk', 'pillar', 'runes'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/pillar-obelisk.glb',
          triangleCount: 76,
          vertexCount: 136,
          fileSizeBytes: 8552,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_crypt_large',
      name: 'Catacomb Crypt Portal',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.93,
        minY: 0.0,
        minZ: -1.2,
        maxX: 0.93,
        maxY: 1.0,
        maxZ: 1.2,
      ),
      tags: <String>{'building', 'crypt', 'catacomb', 'tomb', 'entrance'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/crypt-large.glb',
          triangleCount: 626,
          vertexCount: 1028,
          fileSizeBytes: 54852,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_dungeon_gate',
      name: 'Heavy Dungeon Gate',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -2,
        minY: 0,
        minZ: -0.5,
        maxX: 2,
        maxY: 4,
        maxZ: 0.5,
      ),
      tags: <String>{'building', 'gate', 'dungeon', 'portal', 'iron'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/dungeon_gate.glb',
          triangleCount: 449,
          vertexCount: 833,
          fileSizeBytes: 46364,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_dungeon_warkarma',
      name: 'Warkarma Fortress Dungeon',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -41.3,
        minY: -40.76,
        minZ: -33.39,
        maxX: 37.94,
        maxY: 41.28,
        maxZ: 34.81,
      ),
      tags: <String>{'building', 'fortress', 'dungeon', 'castle', 'architecture'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/dungeon_warkarma.glb',
          triangleCount: 72137,
          vertexCount: 145805,
          fileSizeBytes: 7990584,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'nat_cliff_rock',
      name: 'Craggy Cliff Face',
      category: ModelCategory.natureProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.51,
        minY: -0.0,
        minZ: -0.56,
        maxX: 0.52,
        maxY: 0.59,
        maxZ: 0.46,
      ),
      tags: <String>{'nature', 'cliff', 'rock', 'crag', 'mountain'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/cliff.glb',
          triangleCount: 364,
          vertexCount: 684,
          fileSizeBytes: 36924,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'nat_grass_clump',
      name: 'Wild Grass Clump',
      category: ModelCategory.natureProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.0,
        maxX: 0.0,
        maxY: 0.0,
        maxZ: 0.01,
      ),
      tags: <String>{'nature', 'grass', 'foliage', 'vegetation'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/grass_clump.glb',
          triangleCount: 192,
          vertexCount: 408,
          fileSizeBytes: 12632,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'nat_pine_tree',
      name: 'Alpine Evergreen Pine Tree',
      category: ModelCategory.natureProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Poly Haven / Kenney CC0 Nature & Dungeon Scans',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.01,
        minZ: -0.0,
        maxX: 0.01,
        maxY: 0.01,
        maxZ: 0.03,
      ),
      tags: <String>{'nature', 'tree', 'pine', 'evergreen', 'forest'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/environment/pine_tree.glb',
          triangleCount: 1911,
          vertexCount: 3827,
          fileSizeBytes: 106060,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_arrow_steel',
      name: 'Bodkin Steel Arrow',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.03,
        minZ: -0.0,
        maxX: 0.0,
        maxY: 0.0,
        maxZ: 0.0,
      ),
      tags: <String>{'weapon', 'arrow', 'ammo', 'steel', 'archery'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Arrow.glb',
          triangleCount: 224,
          vertexCount: 444,
          fileSizeBytes: 16828,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_axe_iron',
      name: 'Iron Woodcutters Axe',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.02,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.04,
      ),
      tags: <String>{'weapon', 'axe', 'one_handed', 'iron'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Axe.glb',
          triangleCount: 1130,
          vertexCount: 2173,
          fileSizeBytes: 63764,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_axe_double',
      name: 'Double-Headed Waraxe',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.03,
        maxX: 0.02,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'axe', 'two_handed', 'heavy'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Axe_Double.glb',
          triangleCount: 1892,
          vertexCount: 3558,
          fileSizeBytes: 101596,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_axe_small',
      name: 'Small Handaxe',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.02,
      ),
      tags: <String>{'weapon', 'axe', 'hatchet', 'one_handed'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Axe_Small.glb',
          triangleCount: 964,
          vertexCount: 1838,
          fileSizeBytes: 54740,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_bow_evil',
      name: 'Shadow Horn Recurve Bow',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.03,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'bow', 'recurve', 'dark', 'evil'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Bow_Evil.glb',
          triangleCount: 772,
          vertexCount: 1506,
          fileSizeBytes: 44556,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_bow_golden',
      name: 'Golden Elven Longbow',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.03,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'bow', 'golden', 'elven', 'ranged'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Bow_Golden.glb',
          triangleCount: 776,
          vertexCount: 1542,
          fileSizeBytes: 45448,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_bow_wooden',
      name: 'Yew Wooden Longbow',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.03,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'bow', 'wood', 'longbow'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Bow_Wooden.glb',
          triangleCount: 728,
          vertexCount: 1438,
          fileSizeBytes: 42668,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_bow_short',
      name: 'Compact Wooden Shortbow',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.03,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'bow', 'shortbow', 'wood'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Bow_Wooden2.glb',
          triangleCount: 664,
          vertexCount: 1314,
          fileSizeBytes: 39308,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_bow_hunting',
      name: 'Hunters Composite Bow',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.03,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'bow', 'hunting', 'ranged'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/bow.glb',
          triangleCount: 728,
          vertexCount: 1438,
          fileSizeBytes: 42668,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_broadsword_master',
      name: 'Mercenary Broadsword (Master)',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.0,
        maxX: 0.0,
        maxY: 0.0,
        maxZ: 0.06,
      ),
      tags: <String>{'weapon', 'sword', 'broadsword', 'steel'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/broadsword.glb',
          triangleCount: 1031,
          vertexCount: 1787,
          fileSizeBytes: 54980,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_claymore_highland',
      name: 'Highland Great Claymore',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.0,
        maxX: 0.0,
        maxY: 0.0,
        maxZ: 0.06,
      ),
      tags: <String>{'weapon', 'sword', 'claymore', 'two_handed'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Claymore.glb',
          triangleCount: 1031,
          vertexCount: 1787,
          fileSizeBytes: 54980,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_crossbow_heavy',
      name: 'Heavy Siege Crossbow',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.61,
        minY: -0.17,
        minZ: -0.28,
        maxX: 0.61,
        maxY: 0.31,
        maxZ: 1.16,
      ),
      tags: <String>{'weapon', 'crossbow', 'ranged', 'bolt'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/crossbow.glb',
          triangleCount: 792,
          vertexCount: 942,
          fileSizeBytes: 58772,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_dagger_stiletto',
      name: 'Assassins Stiletto Dagger',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.0,
        maxY: 0.0,
        maxZ: 0.02,
      ),
      tags: <String>{'weapon', 'dagger', 'stiletto', 'rogue'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Dagger_2.glb',
          triangleCount: 736,
          vertexCount: 1252,
          fileSizeBytes: 40368,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_helmet_damaged',
      name: 'Battle Damaged Visor Helmet (Source)',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.95,
        minY: -1.19,
        minZ: -0.9,
        maxX: 0.94,
        maxY: 0.81,
        maxZ: 0.9,
      ),
      tags: <String>{'weapon', 'helmet', 'armor', 'visor', 'damaged'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/DamagedHelmet.glb',
          triangleCount: 15452,
          vertexCount: 14556,
          fileSizeBytes: 3773916,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_helmet_damaged_baked',
      name: 'Battle Damaged Visor Helmet (PBR Baked)',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.95,
        minY: -1.19,
        minZ: -0.9,
        maxX: 0.94,
        maxY: 0.81,
        maxZ: 0.9,
      ),
      tags: <String>{'weapon', 'helmet', 'armor', 'pbr', 'baked'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/DamagedHelmet_baked.glb',
          triangleCount: 15452,
          vertexCount: 16789,
          fileSizeBytes: 1142428,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_hammer_double',
      name: 'Dwarven Double Warhammer',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.02,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'hammer', 'blunt', 'two_handed'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Hammer_Double.glb',
          triangleCount: 1918,
          vertexCount: 3724,
          fileSizeBytes: 105748,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_hammer_small',
      name: 'Blacksmith Hand Hammer',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'hammer', 'forge', 'one_handed'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Hammer_Small.glb',
          triangleCount: 1474,
          vertexCount: 2868,
          fileSizeBytes: 82540,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_katana_antique',
      name: 'Antique Samurai Katana',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.05,
        minY: -0.31,
        minZ: -0.05,
        maxX: 0.05,
        maxY: 0.7,
        maxZ: 0.05,
      ),
      tags: <String>{'weapon', 'sword', 'katana', 'blade', 'steel'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/katana_antique.glb',
          triangleCount: 6670,
          vertexCount: 5685,
          fileSizeBytes: 4368244,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_reaper_scythe',
      name: 'Death Reapers War Scythe',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.02,
        maxX: 0.02,
        maxY: 0.0,
        maxZ: 0.03,
      ),
      tags: <String>{'weapon', 'scythe', 'polearm', 'reaper', 'death'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Scythe.glb',
          triangleCount: 1310,
          vertexCount: 2606,
          fileSizeBytes: 75252,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_shield_kite',
      name: 'Ironbound Kite Shield',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.01,
        minZ: -0.02,
        maxX: 0.01,
        maxY: 0.01,
        maxZ: 0.02,
      ),
      tags: <String>{'weapon', 'shield', 'defense', 'kite', 'iron'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/shield.glb',
          triangleCount: 832,
          vertexCount: 1572,
          fileSizeBytes: 47584,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_shield_celtic_golden',
      name: 'Celtic Golden Boss Shield',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.01,
        minZ: -0.02,
        maxX: 0.01,
        maxY: 0.01,
        maxZ: 0.02,
      ),
      tags: <String>{'weapon', 'shield', 'golden', 'celtic', 'defense'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Shield_Celtic_Golden.glb',
          triangleCount: 832,
          vertexCount: 1572,
          fileSizeBytes: 47584,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_shield_heater',
      name: 'Knights Heater Shield',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.01,
      ),
      tags: <String>{'weapon', 'shield', 'heater', 'knight', 'defense'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Shield_Heater.glb',
          triangleCount: 1948,
          vertexCount: 3386,
          fileSizeBytes: 97820,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_shield_heater_2',
      name: 'Reinforced Spiked Heater Shield',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.01,
      ),
      tags: <String>{'weapon', 'shield', 'heater', 'reinforced'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Shield_Heater_2.glb',
          triangleCount: 1272,
          vertexCount: 2122,
          fileSizeBytes: 63424,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_shield_round',
      name: 'Viking Oak Round Shield',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.01,
      ),
      tags: <String>{'weapon', 'shield', 'round', 'viking', 'wood'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Shield_Round.glb',
          triangleCount: 1056,
          vertexCount: 2052,
          fileSizeBytes: 60448,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_shield_round_2',
      name: 'Studded Iron Round Shield',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.01,
      ),
      tags: <String>{'weapon', 'shield', 'round', 'iron', 'studded'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Shield_Round_2.glb',
          triangleCount: 1204,
          vertexCount: 2348,
          fileSizeBytes: 69492,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_spear_halberd',
      name: 'Guardsman Steel Spear',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.0,
        minY: -0.0,
        minZ: -0.02,
        maxX: 0.0,
        maxY: 0.0,
        maxZ: 0.08,
      ),
      tags: <String>{'weapon', 'spear', 'polearm', 'thrust', 'steel'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Spear.glb',
          triangleCount: 1202,
          vertexCount: 2410,
          fileSizeBytes: 69892,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_sword_long',
      name: 'Knights Longsword (Source)',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.05,
      ),
      tags: <String>{'weapon', 'sword', 'longsword', 'steel'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/sword.glb',
          triangleCount: 1006,
          vertexCount: 1928,
          fileSizeBytes: 58220,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_sword_baked',
      name: 'Knights Longsword (PBR Baked)',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.05,
      ),
      tags: <String>{'weapon', 'sword', 'longsword', 'pbr', 'baked'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/sword_baked.glb',
          triangleCount: 1006,
          vertexCount: 1984,
          fileSizeBytes: 338640,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_sword_arming',
      name: 'Crusader Arming Sword',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.05,
      ),
      tags: <String>{'weapon', 'sword', 'arming', 'one_handed'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Sword_2.glb',
          triangleCount: 942,
          vertexCount: 1775,
          fileSizeBytes: 54156,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_sword_big',
      name: 'Executioners Zweihander',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.0,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.06,
      ),
      tags: <String>{'weapon', 'sword', 'zweihander', 'greatsword', 'heavy'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Sword_Big.glb',
          triangleCount: 830,
          vertexCount: 1644,
          fileSizeBytes: 50336,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_sword_golden',
      name: 'Imperial Golden Gladius',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.01,
        minY: -0.0,
        minZ: -0.01,
        maxX: 0.01,
        maxY: 0.0,
        maxZ: 0.05,
      ),
      tags: <String>{'weapon', 'sword', 'gladius', 'golden', 'royal'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/Sword_Golden.glb',
          triangleCount: 1006,
          vertexCount: 1928,
          fileSizeBytes: 58220,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_wand_sorcerer',
      name: 'Apprentice Spell Wand',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'KayKit / Kenney CC0 Fantasy Weapons & Armory',
      bounds: BoundingBox3D(
        minX: -0.08,
        minY: -0.27,
        minZ: -0.08,
        maxX: 0.08,
        maxY: 0.7,
        maxZ: 0.08,
      ),
      tags: <String>{'weapon', 'wand', 'magic', 'arcane', 'wood'},
      sockets: const <String, List<double>>{
        'socket_grip': <double>[0.0, 0.15, 0.0],
      },
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/weapons/wand.glb',
          triangleCount: 150,
          vertexCount: 158,
          fileSizeBytes: 29340,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'wpn_aion2_sword_master',
      name: 'Aion 2 Dark Fantasy Runic Greatsword (Master)',
      category: ModelCategory.weapon,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Aion 2 Dark Fantasy 3D Asset Studio',
      bounds: BoundingBox3D(
        minX: -0.21,
        minY: -0.41,
        minZ: -0.2,
        maxX: 0.21,
        maxY: 1.3,
        maxZ: 0.2,
      ),
      tags: <String>{'weapon', 'sword', 'aion2', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/aion2/aion2_dark_fantasy_sword.glb',
          triangleCount: 803,
          vertexCount: 955,
          fileSizeBytes: 1856544, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'prop_aion2_wings_master',
      name: 'Aion 2 Ethereal Daeva Wings (Master)',
      category: ModelCategory.dungeonProp,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Aion 2 Dark Fantasy 3D Asset Studio',
      bounds: BoundingBox3D(
        minX: -3.42,
        minY: 0.67,
        minZ: -0.1,
        maxX: 3.42,
        maxY: 2.2,
        maxZ: 1.17,
      ),
      tags: <String>{'dungeon', 'wings', 'aion2', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/aion2/aion2_ethereal_wings.glb',
          triangleCount: 3703,
          vertexCount: 4366,
          fileSizeBytes: 1232332, isDracoCompressed: true,
        ),
      },
    ));

    register(MeshAssetMetadata(
      id: 'bld_aion2_pillar_master',
      name: 'Aion 2 Gothic Dungeon Pillar (Master)',
      category: ModelCategory.building,
      license: 'CC0 1.0 Universal (Public Domain)',
      licenseSource: 'Aion 2 Dark Fantasy 3D Asset Studio',
      bounds: BoundingBox3D(
        minX: -1.35,
        minY: -0.06,
        minZ: -1.35,
        maxX: 1.35,
        maxY: 6.39,
        maxZ: 1.35,
      ),
      tags: <String>{'building', 'pillar', 'aion2', 'master'},
      lods: <LodLevel, ModelLodInfo>{
        LodLevel.lod0: ModelLodInfo(
          lodLevel: LodLevel.lod0,
          filePath: 'assets/models/aion2/aion2_gothic_dungeon_pillar.glb',
          triangleCount: 1173,
          vertexCount: 1937,
          fileSizeBytes: 940244, isDracoCompressed: true,
        ),
      },
    ));
  }
}
