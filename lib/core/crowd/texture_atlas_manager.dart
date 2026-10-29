import 'dart:convert';
import 'dart:typed_data';

/// Represents a 2D integer pixel bounding box within a texture atlas.
class AtlasPixelRect {
  final int x;
  final int y;
  final int width;
  final int height;

  const AtlasPixelRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  int get right => x + width;
  int get bottom => y + height;
  int get area => width * height;

  /// Returns true if this rectangle intersects with another rectangle.
  bool intersects(AtlasPixelRect other) {
    return !(right <= other.x ||
        other.right <= x ||
        bottom <= other.y ||
        other.bottom <= y);
  }

  /// Returns true if this rectangle completely contains another rectangle.
  bool contains(AtlasPixelRect other) {
    return x <= other.x &&
        y <= other.y &&
        right >= other.right &&
        bottom >= other.bottom;
  }

  factory AtlasPixelRect.fromJson(Map<String, dynamic> json) {
    return AtlasPixelRect(
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  @override
  String toString() => 'AtlasPixelRect(x: $x, y: $y, w: $width, h: $height)';
}

/// Represents normalized UV coordinates [0.0 .. 1.0] and scale/offset factors.
class AtlasUVRect {
  final double uMin;
  final double vMin;
  final double uMax;
  final double vMax;
  final double uScale;
  final double vScale;
  final double uOffset;
  final double vOffset;

  const AtlasUVRect({
    required this.uMin,
    required this.vMin,
    required this.uMax,
    required this.vMax,
    required this.uScale,
    required this.vScale,
    required this.uOffset,
    required this.vOffset,
  });

  /// Factory creating an [AtlasUVRect] from raw min/max bounds.
  factory AtlasUVRect.fromBounds({
    required double uMin,
    required double vMin,
    required double uMax,
    required double vMax,
  }) {
    return AtlasUVRect(
      uMin: uMin,
      vMin: vMin,
      uMax: uMax,
      vMax: vMax,
      uScale: uMax - uMin,
      vScale: vMax - vMin,
      uOffset: uMin,
      vOffset: vMin,
    );
  }

  factory AtlasUVRect.fromJson(Map<String, dynamic> json) {
    final uMin = (json['uMin'] as num).toDouble();
    final vMin = (json['vMin'] as num).toDouble();
    final uMax = (json['uMax'] as num).toDouble();
    final vMax = (json['vMax'] as num).toDouble();
    final uScale = (json['uScale'] as num?)?.toDouble() ?? (uMax - uMin);
    final vScale = (json['vScale'] as num?)?.toDouble() ?? (vMax - vMin);
    final uOffset = (json['uOffset'] as num?)?.toDouble() ?? uMin;
    final vOffset = (json['vOffset'] as num?)?.toDouble() ?? vMin;

    return AtlasUVRect(
      uMin: uMin,
      vMin: vMin,
      uMax: uMax,
      vMax: vMax,
      uScale: uScale,
      vScale: vScale,
      uOffset: uOffset,
      vOffset: vOffset,
    );
  }

  Map<String, dynamic> toJson() => {
        'uMin': uMin,
        'vMin': vMin,
        'uMax': uMax,
        'vMax': vMax,
        'uScale': uScale,
        'vScale': vScale,
        'uOffset': uOffset,
        'vOffset': vOffset,
      };

  /// Validates that UV bounds are within standard normalized bounds.
  bool isValid({double tolerance = 1e-5}) {
    return uMin >= -tolerance &&
        vMin >= -tolerance &&
        uMax <= 1.0 + tolerance &&
        vMax <= 1.0 + tolerance &&
        uMin < uMax &&
        vMin < vMax;
  }

  /// Remaps a normalized (0..1) UV point into atlas UV space.
  (double, double) remap(double u, double v, {bool flipY = false}) {
    final remappedU = uOffset + u * uScale;
    final remappedV = flipY ? (vMax - v * vScale) : (vOffset + v * vScale);
    return (remappedU, remappedV);
  }

  @override
  String toString() =>
      'AtlasUVRect(u: [$uMin, $uMax], v: [$vMin, $vMax], scale: [$uScale, $vScale])';
}

/// Information about a single packed subtexture in the atlas.
class AtlasRegion {
  final String id;
  final String name;
  final int pageIndex;
  final AtlasPixelRect pixel;
  final AtlasPixelRect outerPixel;
  final AtlasUVRect uv;
  final Map<String, String?> channels;

  const AtlasRegion({
    required this.id,
    required this.name,
    required this.pageIndex,
    required this.pixel,
    required this.outerPixel,
    required this.uv,
    this.channels = const {},
  });

  double get uMin => uv.uMin;
  double get vMin => uv.vMin;
  double get uMax => uv.uMax;
  double get vMax => uv.vMax;
  double get uScale => uv.uScale;
  double get vScale => uv.vScale;
  double get uOffset => uv.uOffset;
  double get vOffset => uv.vOffset;

  /// Remaps single UV coordinates.
  (double, double) remapUV(double u, double v, {bool flipY = false}) {
    return uv.remap(u, v, flipY: flipY);
  }

  /// Returns [uOffset, vOffset, uScale, vScale] as a Float32List for shader uniforms.
  Float32List toShaderUniformVec4() {
    return Float32List.fromList([uOffset, vOffset, uScale, vScale]);
  }

  factory AtlasRegion.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = (json['name'] as String?) ?? id;
    final pageIndex = (json['pageIndex'] as num?)?.toInt() ?? 0;
    final pixel = AtlasPixelRect.fromJson(json['pixel'] as Map<String, dynamic>);
    final outerPixel = json['outerPixel'] != null
        ? AtlasPixelRect.fromJson(json['outerPixel'] as Map<String, dynamic>)
        : pixel;
    final uv = AtlasUVRect.fromJson(json['uv'] as Map<String, dynamic>);

    final rawChannels = json['channels'] as Map<String, dynamic>?;
    final Map<String, String?> channels = {};
    if (rawChannels != null) {
      for (final entry in rawChannels.entries) {
        channels[entry.key] = entry.value as String?;
      }
    }

    return AtlasRegion(
      id: id,
      name: name,
      pageIndex: pageIndex,
      pixel: pixel,
      outerPixel: outerPixel,
      uv: uv,
      channels: channels,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pageIndex': pageIndex,
        'pixel': pixel.toJson(),
        'outerPixel': outerPixel.toJson(),
        'uv': uv.toJson(),
        'channels': channels,
      };

  @override
  String toString() => 'AtlasRegion(id: $id, page: $pageIndex, uv: $uv)';
}

/// Metadata representation of a generated texture atlas sheet.
class TextureAtlasMetadata {
  final String version;
  final String generator;
  final int timestamp;
  final int atlasWidth;
  final int atlasHeight;
  final int padding;
  final int pageIndex;
  final int totalPages;
  final int totalRegions;
  final double efficiency;
  final double allocatedEfficiency;
  final Map<String, String> channels;
  final Map<String, AtlasRegion> regions;

  const TextureAtlasMetadata({
    required this.version,
    required this.generator,
    required this.timestamp,
    required this.atlasWidth,
    required this.atlasHeight,
    required this.padding,
    required this.pageIndex,
    required this.totalPages,
    required this.totalRegions,
    required this.efficiency,
    required this.allocatedEfficiency,
    required this.channels,
    required this.regions,
  });

  /// Genuine recalculation of content packing efficiency:
  /// sum(subtexture inner content areas) / (atlasWidth * atlasHeight)
  double calculateActualContentEfficiency() {
    if (atlasWidth <= 0 || atlasHeight <= 0) return 0.0;
    int contentArea = 0;
    for (final region in regions.values) {
      contentArea += region.pixel.area;
    }
    return contentArea / (atlasWidth * atlasHeight);
  }

  /// Validates integrity of regions: checks UV boundary math, valid coordinates,
  /// and confirms zero overlapping content pixels.
  List<String> validateIntegrity() {
    final errors = <String>[];

    // Check bounds
    for (final region in regions.values) {
      if (!region.uv.isValid()) {
        errors.add('Region ${region.id} has invalid UV bounds: ${region.uv}');
      }
      if (region.pixel.x < 0 ||
          region.pixel.y < 0 ||
          region.pixel.right > atlasWidth ||
          region.pixel.bottom > atlasHeight) {
        errors.add(
            'Region ${region.id} exceeds atlas bounds (${atlasWidth}x$atlasHeight): ${region.pixel}');
      }
    }

    // Check overlaps
    final regionList = regions.values.toList();
    for (int i = 0; i < regionList.length; i++) {
      for (int j = i + 1; j < regionList.length; j++) {
        final r1 = regionList[i];
        final r2 = regionList[j];
        if (r1.pageIndex == r2.pageIndex && r1.pixel.intersects(r2.pixel)) {
          errors.add('Regions ${r1.id} and ${r2.id} overlap in pixel content space');
        }
      }
    }

    return errors;
  }

  factory TextureAtlasMetadata.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as String?) ?? '1.0.0';
    final generator = (json['generator'] as String?) ?? 'texture_atlas_packer.py';
    final timestamp = (json['timestamp'] as num?)?.toInt() ?? 0;
    final atlasWidth = (json['atlasWidth'] as num).toInt();
    final atlasHeight = (json['atlasHeight'] as num).toInt();
    final padding = (json['padding'] as num?)?.toInt() ?? 0;
    final pageIndex = (json['pageIndex'] as num?)?.toInt() ?? 0;
    final totalPages = (json['totalPages'] as num?)?.toInt() ?? 1;
    final totalRegions = (json['totalRegions'] as num?)?.toInt() ?? 0;
    final efficiency = (json['efficiency'] as num?)?.toDouble() ?? 0.0;
    final allocatedEfficiency =
        (json['allocatedEfficiency'] as num?)?.toDouble() ?? efficiency;

    final rawChannels = json['channels'] as Map<String, dynamic>? ?? {};
    final channels = rawChannels.map((k, v) => MapEntry(k, v.toString()));

    final rawRegions = json['regions'] as Map<String, dynamic>? ?? {};
    final regions = <String, AtlasRegion>{};
    for (final entry in rawRegions.entries) {
      regions[entry.key] =
          AtlasRegion.fromJson(entry.value as Map<String, dynamic>);
    }

    return TextureAtlasMetadata(
      version: version,
      generator: generator,
      timestamp: timestamp,
      atlasWidth: atlasWidth,
      atlasHeight: atlasHeight,
      padding: padding,
      pageIndex: pageIndex,
      totalPages: totalPages,
      totalRegions: totalRegions,
      efficiency: efficiency,
      allocatedEfficiency: allocatedEfficiency,
      channels: channels,
      regions: regions,
    );
  }

  factory TextureAtlasMetadata.parseJsonString(String jsonStr) {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object for TextureAtlasMetadata');
    }
    return TextureAtlasMetadata.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'generator': generator,
        'timestamp': timestamp,
        'atlasWidth': atlasWidth,
        'atlasHeight': atlasHeight,
        'padding': padding,
        'pageIndex': pageIndex,
        'totalPages': totalPages,
        'totalRegions': totalRegions,
        'efficiency': efficiency,
        'allocatedEfficiency': allocatedEfficiency,
        'channels': channels,
        'regions': regions.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// Production-ready runtime UV remap engine and crowd material atlas manager.
/// Resolves atlas coordinates for 10,000 crowd instances, batch transforms mesh UVs,
/// and builds GPU instanced uniform buffers.
class TextureAtlasManager {
  static TextureAtlasManager? _instance;
  static TextureAtlasManager get instance => _instance ??= TextureAtlasManager();

  /// Registered atlas pages grouped by category (e.g. 'characters', 'weapons', 'props').
  final Map<String, List<TextureAtlasMetadata>> _atlasesByCategory = {};

  /// Fast index: key -> (category, AtlasRegion)
  final Map<String, AtlasRegion> _regionsByKey = {};

  /// Fast index: original texture file path (normalized) -> AtlasRegion
  final Map<String, AtlasRegion> _regionsByPath = {};

  /// If strict is false, unknown textures fall back to default identity UVs [0..1]
  bool strict = false;

  /// Default fallback region for unatlased or missing textures
  static const AtlasRegion fallbackIdentityRegion = AtlasRegion(
    id: '__fallback__',
    name: '__fallback__',
    pageIndex: 0,
    pixel: AtlasPixelRect(x: 0, y: 0, width: 1, height: 1),
    outerPixel: AtlasPixelRect(x: 0, y: 0, width: 1, height: 1),
    uv: AtlasUVRect(
      uMin: 0.0,
      vMin: 0.0,
      uMax: 1.0,
      vMax: 1.0,
      uScale: 1.0,
      vScale: 1.0,
      uOffset: 0.0,
      vOffset: 0.0,
    ),
  );

  /// Clears all loaded atlases and indices.
  void clear() {
    _atlasesByCategory.clear;
    _regionsByKey.clear();
    _regionsByPath.clear();
  }

  /// Registers a parsed [TextureAtlasMetadata] sheet into the manager.
  void registerAtlas(TextureAtlasMetadata atlas, {String category = 'default'}) {
    _atlasesByCategory.putIfAbsent(category, () => []).add(atlas);

    for (final region in atlas.regions.values) {
      _regionsByKey[region.id] = region;
      _regionsByKey[region.name] = region;

      // Index original channel paths if available
      for (final path in region.channels.values) {
        if (path != null && path.isNotEmpty) {
          final normalized = _normalizePath(path);
          _regionsByPath[normalized] = region;
        }
      }
    }
  }

  /// Loads and registers an atlas from raw JSON string.
  TextureAtlasMetadata loadFromJsonString(String jsonString,
      {String category = 'default'}) {
    final atlas = TextureAtlasMetadata.parseJsonString(jsonString);
    registerAtlas(atlas, category: category);
    return atlas;
  }

  /// Checks if a region exists for [key].
  bool hasRegion(String key) {
    return _regionsByKey.containsKey(key) ||
        _regionsByPath.containsKey(_normalizePath(key));
  }

  /// Resolves the [AtlasRegion] for a given texture identifier or name.
  AtlasRegion? getRegion(String key) {
    final region = _regionsByKey[key] ?? _regionsByPath[_normalizePath(key)];
    if (region == null && strict) {
      throw ArgumentError('TextureAtlasManager: Unknown texture key "$key"');
    }
    return region ?? (strict ? null : fallbackIdentityRegion);
  }

  /// Resolves the [AtlasRegion] directly by matching original texture file path.
  AtlasRegion? getRegionByPath(String path) {
    final region = _regionsByPath[_normalizePath(path)];
    if (region == null && strict) {
      throw ArgumentError('TextureAtlasManager: Unknown texture path "$path"');
    }
    return region ?? (strict ? null : fallbackIdentityRegion);
  }

  /// Remaps a single normalized UV coordinate (u, v) [0..1] into atlas UV space.
  (double, double) remapUV(
    String textureKey,
    double u,
    double v, {
    bool flipY = false,
  }) {
    final region = getRegion(textureKey) ?? fallbackIdentityRegion;
    return region.remapUV(u, v, flipY: flipY);
  }

  /// High-performance batch UV remapping for mesh vertex buffers.
  /// [originalUVs] contains contiguous vertex UV pairs: [u0, v0, u1, v1, ...].
  /// If [inPlace] is true, modifies [originalUVs] directly to eliminate allocations.
  Float32List remapMeshUVBuffer(
    Float32List originalUVs,
    String textureKey, {
    bool inPlace = false,
    bool flipY = false,
  }) {
    final region = getRegion(textureKey) ?? fallbackIdentityRegion;
    final int count = originalUVs.length;
    if (count % 2 != 0) {
      throw ArgumentError('originalUVs length must be even (pairs of u, v)');
    }

    final Float32List target = inPlace ? originalUVs : Float32List(count);

    final double uMin = region.uMin;
    final double vMin = region.vMin;
    final double vMax = region.vMax;
    final double uScale = region.uScale;
    final double vScale = region.vScale;

    if (flipY) {
      for (int i = 0; i < count; i += 2) {
        final double u = originalUVs[i];
        final double v = originalUVs[i + 1];
        target[i] = uMin + u * uScale;
        target[i + 1] = vMax - v * vScale;
      }
    } else {
      for (int i = 0; i < count; i += 2) {
        final double u = originalUVs[i];
        final double v = originalUVs[i + 1];
        target[i] = uMin + u * uScale;
        target[i + 1] = vMin + v * vScale;
      }
    }

    return target;
  }

  /// Returns [uOffset, vOffset, uScale, vScale] for crowd GPU vertex/fragment shaders.
  Float32List getMaterialUniforms(String textureKey) {
    final region = getRegion(textureKey) ?? fallbackIdentityRegion;
    return region.toShaderUniformVec4();
  }

  /// Generates a contiguous GPU Instance Buffer array for 10,000 crowd instances.
  /// Each instance receives 4 consecutive floats [uOffset, vOffset, uScale, vScale].
  /// Shaders remap UVs on the GPU per-instance:
  /// `remappedUV = vUV * uScaleOffset.zw + uScaleOffset.xy;`
  Float32List generateCrowdInstanceBuffer(List<String> instanceTextureKeys) {
    final int instanceCount = instanceTextureKeys.length;
    final buffer = Float32List(instanceCount * 4);

    for (int i = 0; i < instanceCount; i++) {
      final key = instanceTextureKeys[i];
      final region = getRegion(key) ?? fallbackIdentityRegion;
      final offset = i * 4;

      buffer[offset] = region.uOffset;
      buffer[offset + 1] = region.vOffset;
      buffer[offset + 2] = region.uScale;
      buffer[offset + 3] = region.vScale;
    }

    return buffer;
  }

  /// Returns the total number of unique registered regions.
  int get totalRegionsCount => _regionsByKey.length;

  /// Returns total number of registered atlas sheets across all categories.
  int get totalRegisteredAtlases {
    int count = 0;
    for (final list in _atlasesByCategory.values) {
      count += list.length;
    }
    return count;
  }

  /// Computes average packing efficiency across all registered atlases.
  double get averagePackingEfficiency {
    int totalAtlases = 0;
    double sumEff = 0.0;
    for (final list in _atlasesByCategory.values) {
      for (final a in list) {
        sumEff += a.calculateActualContentEfficiency();
        totalAtlases++;
      }
    }
    return totalAtlases > 0 ? (sumEff / totalAtlases) : 0.0;
  }

  /// Produces a comprehensive audit and performance report for the crowd render pipeline.
  Map<String, dynamic> generateAuditReport() {
    int totalSubtextures = 0;
    int totalAtlasSheets = 0;
    int totalPixelAreaPacked = 0;
    int totalAtlasPixelCapacity = 0;

    for (final list in _atlasesByCategory.values) {
      for (final a in list) {
        totalAtlasSheets++;
        totalAtlasPixelCapacity += a.atlasWidth * a.atlasHeight;
        for (final r in a.regions.values) {
          totalSubtextures++;
          totalPixelAreaPacked += r.pixel.area;
        }
      }
    }

    final double avgEff = totalAtlasPixelCapacity > 0
        ? (totalPixelAreaPacked / totalAtlasPixelCapacity)
        : 0.0;

    // In a scene with N individual subtextures, without atlas packing every material
    // would require its own texture binding and draw call.
    // Atlas packing collapses all subtextures sharing an atlas into 1 draw call!
    final int estimatedDrawCallReduction =
        totalSubtextures > 0 ? (totalSubtextures - totalAtlasSheets) : 0;

    return {
      'totalAtlasSheets': totalAtlasSheets,
      'totalSubtextures': totalSubtextures,
      'totalPixelAreaPacked': totalPixelAreaPacked,
      'totalAtlasPixelCapacity': totalAtlasPixelCapacity,
      'actualEfficiency': avgEff,
      'efficiencyPercentage': (avgEff * 100).toStringAsFixed(2),
      'exceeds85Target': avgEff > 0.85,
      'estimatedDrawCallReduction': estimatedDrawCallReduction,
      'gpuCrowdInstancingReady': true,
    };
  }

  static String _normalizePath(String path) {
    return path.replaceAll('\\', '/').toLowerCase();
  }
}
