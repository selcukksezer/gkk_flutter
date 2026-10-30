import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/assets/mesh_asset_registry.dart';
import 'package:gkk_flutter/rendering/mesh_asset_registry.dart' as rendering_barrel;

void main() {
  group('MeshAssetRegistry — Default Catalog & Registration', () {
    late MeshAssetRegistry registry;

    setUp(() {
      registry = MeshAssetRegistry();
    });

    test('pre-seeds CC0 catalog across all 5 fantasy categories', () {
      final List<MeshAssetMetadata> all = registry.getAll();
      expect(all.length, greaterThanOrEqualTo(12));

      final List<MeshAssetMetadata> weapons =
          registry.getByCategory(ModelCategory.weapon);
      final List<MeshAssetMetadata> characters =
          registry.getByCategory(ModelCategory.character);
      final List<MeshAssetMetadata> buildings =
          registry.getByCategory(ModelCategory.building);
      final List<MeshAssetMetadata> nature =
          registry.getByCategory(ModelCategory.natureProp);
      final List<MeshAssetMetadata> dungeons =
          registry.getByCategory(ModelCategory.dungeonProp);

      expect(weapons, isNotEmpty);
      expect(characters, isNotEmpty);
      expect(buildings, isNotEmpty);
      expect(nature, isNotEmpty);
      expect(dungeons, isNotEmpty);

      // Verify all pre-seeded models are CC0
      for (final MeshAssetMetadata meta in all) {
        expect(meta.isCc0, isTrue,
            reason: '${meta.id} must be licensed as CC0 / Public Domain');
        expect(meta.licenseSource, isNotEmpty);
        expect(meta.bounds.boundingRadius, greaterThan(0.0));
      }
    });

    test('supports dynamic registration and unregistration', () {
      const MeshAssetMetadata customProp = MeshAssetMetadata(
        id: 'prop_custom_crystal_obelisk',
        name: 'Dark Runic Crystal Obelisk',
        category: ModelCategory.dungeonProp,
        license: 'CC0 1.0 Universal',
        licenseSource: 'Community Forge',
        bounds: BoundingBox3D(
          minX: -0.5,
          minY: 0.0,
          minZ: -0.5,
          maxX: 0.5,
          maxY: 3.0,
          maxZ: 0.5,
        ),
        tags: <String>{'crystal', 'obelisk', 'magic', 'dungeon'},
        lods: <LodLevel, ModelLodInfo>{
          LodLevel.lod0: ModelLodInfo(
            lodLevel: LodLevel.lod0,
            filePath: 'assets/models/props/Obelisk_LOD0.glb',
            triangleCount: 1200,
            vertexCount: 650,
            fileSizeBytes: 8400,
          ),
        },
      );

      expect(registry.contains('prop_custom_crystal_obelisk'), isFalse);
      registry.register(customProp);
      expect(registry.contains('prop_custom_crystal_obelisk'), isTrue);

      final MeshAssetMetadata? retrieved =
          registry.get('prop_custom_crystal_obelisk');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Dark Runic Crystal Obelisk');
      expect(retrieved.tags.contains('crystal'), isTrue);

      final List<MeshAssetMetadata> obeliskMatches =
          registry.getByTag('obelisk');
      expect(obeliskMatches.any((MeshAssetMetadata m) => m.id == customProp.id),
          isTrue);

      final bool unregistered = registry.unregister('prop_custom_crystal_obelisk');
      expect(unregistered, isTrue);
      expect(registry.contains('prop_custom_crystal_obelisk'), isFalse);
      expect(registry.getByTag('obelisk'), isEmpty);
    });

    test('multi-parameter search filters accurately', () {
      final List<MeshAssetMetadata> swords = registry.search(query: 'sword');
      expect(swords, isNotEmpty);
      expect(swords.every((MeshAssetMetadata m) => m.category == ModelCategory.weapon), isTrue);

      final List<MeshAssetMetadata> dungeonLight = registry.search(
        category: ModelCategory.dungeonProp,
        tag: 'fire',
      );
      expect(dungeonLight.length, 1);
      expect(dungeonLight.first.id, 'prop_brazier_iron_embers');

      final List<MeshAssetMetadata> cc0Chars = registry.search(
        category: ModelCategory.character,
        cc0Only: true,
      );
      expect(cc0Chars.length, greaterThanOrEqualTo(3));
    });

    test('verifies attachment sockets and 3D bounding geometry', () {
      final MeshAssetMetadata? broadsword =
          registry.get('wpn_mercenary_broadsword');
      expect(broadsword, isNotNull);
      expect(broadsword!.sockets.containsKey('socket_grip'), isTrue);
      expect(broadsword.sockets.containsKey('socket_tip'), isTrue);
      expect(broadsword.bounds.sizeY, closeTo(1.50, 0.05));

      final MeshAssetMetadata? brazier =
          registry.get('prop_brazier_iron_embers');
      expect(brazier, isNotNull);
      expect(brazier!.sockets.containsKey('socket_flame_center'), isTrue);
      expect(brazier.materials.length, 2);
      expect(brazier.materials.any((PbrMaterialDescriptor m) => m.hasEmission),
          isTrue);
    });

    test('registry stats aggregates counts and categories accurately', () {
      final RegistryStatistics stats = registry.getStats();
      expect(stats.totalModels, greaterThanOrEqualTo(12));
      expect(stats.totalCc0Models, stats.totalModels);
      expect(stats.modelsByCategory[ModelCategory.weapon], greaterThanOrEqualTo(4));
      expect(stats.modelsByCategory[ModelCategory.character], greaterThanOrEqualTo(3));
      expect(stats.modelsByCategory[ModelCategory.dungeonProp], greaterThanOrEqualTo(4));
    });
  });

  group('LodResolutionConfig & Resolver', () {
    late MeshAssetRegistry registry;
    const LodResolutionConfig config = LodResolutionConfig();

    setUp(() {
      registry = MeshAssetRegistry();
    });

    test('resolves optimal LOD based on distance across device tiers', () {
      // ULTRA Tier: LOD0 <= 25m, LOD1 <= 60m, LOD2 <= 120m, Impostor > 120m
      expect(
          config.resolveLevel(distance: 10.0, tier: DevicePerformanceTier.ultra),
          LodLevel.lod0);
      expect(
          config.resolveLevel(distance: 35.0, tier: DevicePerformanceTier.ultra),
          LodLevel.lod1);
      expect(
          config.resolveLevel(distance: 80.0, tier: DevicePerformanceTier.ultra),
          LodLevel.lod2);
      expect(
          config.resolveLevel(distance: 150.0, tier: DevicePerformanceTier.ultra),
          LodLevel.impostor);

      // LOW Tier: LOD0 <= 4m, LOD1 <= 15m, LOD2 <= 35m, Impostor > 35m
      expect(
          config.resolveLevel(distance: 3.0, tier: DevicePerformanceTier.low),
          LodLevel.lod0);
      expect(
          config.resolveLevel(distance: 10.0, tier: DevicePerformanceTier.low),
          LodLevel.lod1);
      expect(
          config.resolveLevel(distance: 25.0, tier: DevicePerformanceTier.low),
          LodLevel.lod2);
      expect(
          config.resolveLevel(distance: 50.0, tier: DevicePerformanceTier.low),
          LodLevel.impostor);
    });

    test('applies hero multiplier and custom lod bias', () {
      // Normal mid tier at 10m is LOD1 (> 8m)
      expect(
          config.resolveLevel(distance: 10.0, tier: DevicePerformanceTier.medium),
          LodLevel.lod1);

      // Hero entity gets 1.5x multiplier -> LOD0 range expands from 8m to 12m
      expect(
          config.resolveLevel(
              distance: 10.0, tier: DevicePerformanceTier.medium, isHero: true),
          LodLevel.lod0);

      // Custom lodBias of 2.0 expands LOD0 range to 16m
      expect(
          config.resolveLevel(
              distance: 14.0, tier: DevicePerformanceTier.medium, lodBias: 2.0),
          LodLevel.lod0);
    });

    test('resolves asset LOD with graceful fallback ladder', () {
      // Model 'char_warrior_knight' has LOD0, LOD1, LOD2, Impostor
      final LodResolutionResult fullRes = registry.resolveLod(
        'char_warrior_knight',
        distance: 150.0,
        tier: DevicePerformanceTier.high,
      );
      expect(fullRes.targetLod, LodLevel.impostor);
      expect(fullRes.resolvedLod, LodLevel.impostor);
      expect(fullRes.wasFallback, isFalse);

      // Model 'prop_brazier_iron_embers' only defines LOD0
      final LodResolutionResult fallbackRes = registry.resolveLod(
        'prop_brazier_iron_embers',
        distance: 80.0,
        tier: DevicePerformanceTier.low,
      );
      // Low tier at 80m targets impostor, but model only has lod0 -> fallbacks to lod0
      expect(fallbackRes.targetLod, LodLevel.impostor);
      expect(fallbackRes.resolvedLod, LodLevel.lod0);
      expect(fallbackRes.wasFallback, isTrue);
      expect(fallbackRes.lodInfo.filePath,
          'assets/models/props/Brazier_IronEmbers.glb');
    });

    test('throws ArgumentError when resolving unregistered model', () {
      expect(
        () => registry.resolveLod('non_existent_asset',
            distance: 10.0, tier: DevicePerformanceTier.high),
        throwsArgumentError,
      );
    });
  });

  group('ModelMeshCache — LRU Eviction & Telemetry', () {
    late ModelMeshCache cache;
    final List<String> evictedKeys = <String>[];

    setUp(() {
      evictedKeys.clear();
      cache = ModelMeshCache(
        maxMemoryBytes: 1000,
        maxItemCount: 3,
        onEvicted: (String key, ParsedModelMesh mesh) {
          evictedKeys.add(key);
        },
      );
    });

    ParsedModelMesh createFakeMesh(String id, int memoryBytes) {
      return ParsedModelMesh(
        modelId: id,
        sourcePath: 'fake/$id.glb',
        isDracoCompressed: false,
        submeshes: const <ParsedSubmesh>[],
        materials: const <PbrMaterialDescriptor>[],
        bounds: BoundingBox3D.zero(),
        approximateMemoryBytes: memoryBytes,
      );
    }

    test('stores and retrieves mesh updating LRU ordering', () {
      final ParsedModelMesh m1 = createFakeMesh('m1', 100);
      final ParsedModelMesh m2 = createFakeMesh('m2', 150);

      cache.put('m1', m1);
      cache.put('m2', m2);

      expect(cache.itemCount, 2);
      expect(cache.currentMemoryBytes, 250);

      // Cache hit
      final ParsedModelMesh? retrieved = cache.get('m1');
      expect(retrieved, isNotNull);
      expect(retrieved!.modelId, 'm1');
      expect(cache.hits, 1);
      expect(cache.misses, 0);
      expect(cache.hitRatio, 1.0);

      // Accessing m1 makes it MRU. Order is now [m2, m1]
      expect(cache.keys, <String>['m2', 'm1']);

      // Cache miss
      final ParsedModelMesh? missed = cache.get('unknown');
      expect(missed, isNull);
      expect(cache.misses, 1);
      expect(cache.hitRatio, 0.5);
    });

    test('evicts least recently used item when maxItemCount is exceeded', () {
      cache.put('m1', createFakeMesh('m1', 100));
      cache.put('m2', createFakeMesh('m2', 100));
      cache.put('m3', createFakeMesh('m3', 100));

      expect(cache.itemCount, 3);
      expect(evictedKeys, isEmpty);

      // Access m1 to make it MRU -> Order: [m2, m3, m1]
      cache.get('m1');

      // Adding m4 must evict m2 (the LRU entry)
      cache.put('m4', createFakeMesh('m4', 100));

      expect(cache.itemCount, 3);
      expect(cache.contains('m2'), isFalse);
      expect(cache.contains('m1'), isTrue);
      expect(cache.contains('m3'), isTrue);
      expect(cache.contains('m4'), isTrue);
      expect(evictedKeys, <String>['m2']);
      expect(cache.evictions, 1);
    });

    test('evicts items when maxMemoryBytes budget is exceeded', () {
      // Memory limit is 1000 bytes
      cache.put('m1', createFakeMesh('m1', 400));
      cache.put('m2', createFakeMesh('m2', 400));
      expect(cache.currentMemoryBytes, 800);

      // Inserting m3 (400 bytes) -> 1200 > 1000 -> m1 evicted -> remaining 800 <= 1000
      cache.put('m3', createFakeMesh('m3', 400));

      expect(cache.currentMemoryBytes, 800);
      expect(cache.contains('m1'), isFalse);
      expect(cache.contains('m2'), isTrue);
      expect(cache.contains('m3'), isTrue);
      expect(evictedKeys, <String>['m1']);
    });

    test('manual remove and clear functions trigger notifications correctly', () {
      cache.put('m1', createFakeMesh('m1', 200));
      cache.put('m2', createFakeMesh('m2', 300));

      final ParsedModelMesh? removed = cache.remove('m1');
      expect(removed, isNotNull);
      expect(cache.currentMemoryBytes, 300);
      expect(evictedKeys, <String>['m1']);

      cache.clear();
      expect(cache.itemCount, 0);
      expect(cache.currentMemoryBytes, 0);
      expect(evictedKeys, <String>['m1', 'm2']);
    });
  });

  group('DracoGlbParser — Binary Format & Draco Header Inspection', () {
    late DracoGlbParser parser;

    setUp(() {
      parser = DracoGlbParser();
    });

    test('throws GlbFormatException on truncated or invalid headers', () {
      expect(
        () => parser.parse(bytes: Uint8List(8), modelId: 'test'),
        throwsA(isA<GlbFormatException>()),
      );

      final Uint8List badMagic = Uint8List(24);
      badMagic[0] = 0xAA;
      expect(
        () => parser.parse(bytes: badMagic, modelId: 'test'),
        throwsA(isA<GlbFormatException>()),
      );
    });

    test('parses real procedural Draco-compressed GLB asset: Brazier_IronEmbers.glb', () {
      final io.File file =
          io.File('assets/models/props/Brazier_IronEmbers.glb');
      expect(file.existsSync(), isTrue,
          reason: 'Brazier_IronEmbers.glb must exist in assets/models/props/');

      final Uint8List bytes = file.readAsBytesSync();
      final ParsedModelMesh parsed = parser.parse(
        bytes: bytes,
        modelId: 'prop_brazier_iron_embers',
        sourcePath: file.path,
      );

      expect(parsed.modelId, 'prop_brazier_iron_embers');
      expect(parsed.isDracoCompressed, isTrue);
      expect(parsed.dracoHeader, isNotNull);

      // Verify Draco header fields
      final DracoHeaderInfo draco = parsed.dracoHeader!;
      expect(draco.magic, 'DRACO');
      expect(draco.majorVersion, 2);
      expect(draco.minorVersion, 2);
      expect(draco.isMesh, isTrue);
      expect(draco.bufferViewLength, greaterThan(1000));

      // Verify submeshes and primitives
      expect(parsed.submeshes, isNotEmpty);
      final ParsedSubmesh prim0 = parsed.submeshes.first;
      expect(prim0.isDracoCompressed, isTrue);
      expect(prim0.vertexCount, greaterThan(0));

      // Verify materials
      expect(parsed.materials, isNotEmpty);
      final PbrMaterialDescriptor mat = parsed.materials.first;
      expect(mat.name, contains('Brazier_IronEmbers'));
      expect(mat.hasEmission, isTrue);
      expect(mat.emissiveStrength, greaterThan(1.0));

      // Verify bounds
      expect(parsed.bounds.maxDimension, greaterThan(0.5));
      expect(parsed.approximateMemoryBytes, greaterThan(bytes.length));
    });

    test('parses multiple real procedural GLB props', () {
      final List<String> props = <String>[
        'Flagstones_CrackedTile.glb',
        'Gargoyle_DarkStone.glb',
        'GothicArch_Lancet.glb',
        'Portcullis_HeavyIron.glb',
        'StoneAltar_Ritual.glb',
      ];

      for (final String propName in props) {
        final io.File file = io.File('assets/models/props/$propName');
        expect(file.existsSync(), isTrue, reason: '$propName must exist');

        final Uint8List bytes = file.readAsBytesSync();
        final ParsedModelMesh parsed = parser.parse(
          bytes: bytes,
          modelId: propName,
          sourcePath: file.path,
        );

        expect(parsed.isDracoCompressed, isTrue);
        expect(parsed.dracoHeader?.magic, 'DRACO');
        expect(parsed.submeshes, isNotEmpty);
        expect(parsed.bounds.boundingRadius, greaterThan(0.0));
      }
    });

    test('parses uncompressed standard glTF container with geometry accessors', () {
      // Build a synthetic valid glTF 2.0 GLB in memory
      final Map<String, dynamic> jsonMap = <String, dynamic>{
        'asset': <String, dynamic>{'version': '2.0'},
        'accessors': <Map<String, dynamic>>[
          <String, dynamic>{
            'bufferView': 0,
            'byteOffset': 0,
            'componentType': 5126, // FLOAT
            'count': 3,
            'type': 'VEC3',
            'min': <double>[0.0, 0.0, 0.0],
            'max': <double>[1.0, 2.0, 0.0],
          },
          <String, dynamic>{
            'bufferView': 1,
            'byteOffset': 0,
            'componentType': 5123, // UNSIGNED_SHORT
            'count': 3,
            'type': 'SCALAR',
          },
        ],
        'bufferViews': <Map<String, dynamic>>[
          <String, dynamic>{
            'buffer': 0,
            'byteOffset': 0,
            'byteLength': 36, // 3 vertices * 3 floats * 4 bytes
          },
          <String, dynamic>{
            'buffer': 0,
            'byteOffset': 36,
            'byteLength': 6, // 3 indices * 2 bytes
          },
        ],
        'buffers': <Map<String, dynamic>>[
          <String, dynamic>{'byteLength': 44},
        ],
        'meshes': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'SyntheticTriangle',
            'primitives': <Map<String, dynamic>>[
              <String, dynamic>{
                'attributes': <String, dynamic>{'POSITION': 0},
                'indices': 1,
                'mode': 4,
              },
            ],
          },
        ],
      };

      final String jsonStr = json.encode(jsonMap);
      final List<int> jsonBytes = utf8.encode(jsonStr);
      // Pad JSON to 4-byte alignment
      final int jsonPadding = (4 - (jsonBytes.length % 4)) % 4;
      final int jsonChunkLength = jsonBytes.length + jsonPadding;

      // Binary payload: 3 vertices [0,0,0], [1,0,0], [0,2,0] + indices [0, 1, 2]
      final ByteData binData = ByteData(44);
      // Vert 0: (0, 0, 0)
      binData.setFloat32(0, 0.0, Endian.little);
      binData.setFloat32(4, 0.0, Endian.little);
      binData.setFloat32(8, 0.0, Endian.little);
      // Vert 1: (1, 0, 0)
      binData.setFloat32(12, 1.0, Endian.little);
      binData.setFloat32(16, 0.0, Endian.little);
      binData.setFloat32(20, 0.0, Endian.little);
      // Vert 2: (0, 2, 0)
      binData.setFloat32(24, 0.0, Endian.little);
      binData.setFloat32(28, 2.0, Endian.little);
      binData.setFloat32(32, 0.0, Endian.little);
      // Indices: 0, 1, 2
      binData.setUint16(36, 0, Endian.little);
      binData.setUint16(38, 1, Endian.little);
      binData.setUint16(40, 2, Endian.little);

      final int totalLength = 12 + 8 + jsonChunkLength + 8 + 44;
      final ByteData glbBytes = ByteData(totalLength);

      // GLB Header
      glbBytes.setUint32(0, DracoGlbParser.glbMagic, Endian.little);
      glbBytes.setUint32(4, 2, Endian.little);
      glbBytes.setUint32(8, totalLength, Endian.little);

      // JSON Chunk Header
      glbBytes.setUint32(12, jsonChunkLength, Endian.little);
      glbBytes.setUint32(16, DracoGlbParser.jsonChunkType, Endian.little);
      for (int i = 0; i < jsonBytes.length; i++) {
        glbBytes.setUint8(20 + i, jsonBytes[i]);
      }
      for (int i = 0; i < jsonPadding; i++) {
        glbBytes.setUint8(20 + jsonBytes.length + i, 0x20); // space padding
      }

      // BIN Chunk Header
      final int binHeaderOffset = 20 + jsonChunkLength;
      glbBytes.setUint32(binHeaderOffset, 44, Endian.little);
      glbBytes.setUint32(binHeaderOffset + 4, DracoGlbParser.binChunkType, Endian.little);
      final int binPayloadOffset = binHeaderOffset + 8;
      for (int i = 0; i < 44; i++) {
        glbBytes.setUint8(binPayloadOffset + i, binData.getUint8(i));
      }

      final ParsedModelMesh parsed = parser.parse(
        bytes: glbBytes.buffer.asUint8List(),
        modelId: 'synthetic_triangle',
      );

      expect(parsed.isDracoCompressed, isFalse);
      expect(parsed.submeshes.length, 1);
      final ParsedSubmesh submesh = parsed.submeshes.first;
      expect(submesh.vertexCount, 3);
      expect(submesh.indexCount, 3);
      expect(submesh.triangleCount, 1);
      expect(submesh.positions, isNotNull);
      expect(submesh.positions!.length, 9);
      expect(submesh.indices, isNotNull);
      expect(submesh.indices!, <int>[0, 1, 2]);
      expect(parsed.bounds.sizeX, closeTo(1.0, 0.001));
      expect(parsed.bounds.sizeY, closeTo(2.0, 0.001));
    });
  });

  group('MeshAssetRegistry — End-to-End Loading Integration', () {
    late MeshAssetRegistry registry;

    setUp(() {
      registry = MeshAssetRegistry();
    });

    test('loads, parses and caches real GLB model from disk', () async {
      final ParsedModelMesh loaded = await registry.loadMesh('prop_brazier_iron_embers');
      expect(loaded.modelId, 'prop_brazier_iron_embers');
      expect(loaded.isDracoCompressed, isTrue);

      // Verify cached
      final RegistryStatistics stats = registry.getStats();
      expect(stats.cachedModelsCount, 1);
      expect(stats.cachedMemoryBytes, greaterThan(10000));

      // Subsequent call hits cache directly
      final ParsedModelMesh cached = await registry.loadMesh('prop_brazier_iron_embers');
      expect(identical(loaded, cached), isTrue);

      final RegistryStatistics statsAfter = registry.getStats();
      expect(statsAfter.cacheHits, 1);
      expect(statsAfter.cacheMisses, 1);
      expect(statsAfter.cacheHitRatio, closeTo(0.5, 0.01));
    });

    test('loads mesh directly from byte buffer and registers in cache', () {
      final io.File file = io.File('assets/models/props/StoneAltar_Ritual.glb');
      final Uint8List bytes = file.readAsBytesSync();

      final ParsedModelMesh parsed = registry.loadMeshFromBytes(
        bytes,
        modelId: 'prop_stone_altar',
        cacheKey: 'prop_stone_altar_direct',
      );

      expect(parsed.modelId, 'prop_stone_altar');
      expect(parsed.isDracoCompressed, isTrue);
      expect(registry.cache.contains('prop_stone_altar_direct'), isTrue);
    });
  });

  group('MeshAssetRegistry — Forensic 215 Model Coverage & Barrel Parity', () {
    late MeshAssetRegistry registry;

    setUp(() {
      registry = MeshAssetRegistry();
    });

    test('registers 100% of all 215 models on disk without omission', () {
      final Set<String> registeredPaths = registry.getAllAssetPaths();
      expect(registeredPaths.length, 215);

      // Verify every registered path exists on disk
      for (final String path in registeredPaths) {
        final io.File file = io.File(path);
        expect(file.existsSync(), isTrue,
            reason: 'Registered asset must exist on disk: $path');
        expect(file.lengthSync(), greaterThan(0),
            reason: 'Registered asset must not be empty: $path');
      }
    });

    test('retrieves metadata by asset file path', () {
      final MeshAssetMetadata? barbMeta =
          registry.getByPath('assets/models/characters/Barbarian_LOD0.glb');
      expect(barbMeta, isNotNull);
      expect(barbMeta!.id, 'char_barbarian');
      expect(barbMeta.category, ModelCategory.character);

      final MeshAssetMetadata? golemMeta =
          registry.getByPath('assets/models/monsters/golem.glb');
      expect(golemMeta, isNotNull);
      expect(golemMeta!.id, 'mon_golem');

      final MeshAssetMetadata? archMeta =
          registry.getByPath('assets/models/props/GothicArch_Lancet_MultiLOD.glb');
      expect(archMeta, isNotNull);
      expect(archMeta!.id, 'bld_gothic_arch_multilod');
    });

    test('rendering/mesh_asset_registry barrel export provides identical types and instance', () {
      final rendering_barrel.MeshAssetRegistry barrelRegistry =
          rendering_barrel.MeshAssetRegistry.instance;
      expect(identical(barrelRegistry, MeshAssetRegistry.instance), isTrue);
      expect(barrelRegistry.getAllAssetPaths().length, 215);
    });

    test('all registered models are CC0 and possess valid 3D bounds', () {
      final List<MeshAssetMetadata> allModels = registry.getAll();
      expect(allModels.length, greaterThanOrEqualTo(80));

      for (final MeshAssetMetadata meta in allModels) {
        expect(meta.isCc0, isTrue);
        expect(meta.bounds.boundingRadius, greaterThan(0.0));
        expect(meta.lods, isNotEmpty);
      }
    });
  });
}

