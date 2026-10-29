import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/texture_atlas_manager.dart';

const sampleAtlasJson = '''
{
  "version": "1.0.0",
  "generator": "texture_atlas_packer.py",
  "timestamp": 1793221340,
  "atlasWidth": 2048,
  "atlasHeight": 2048,
  "padding": 4,
  "pageIndex": 0,
  "totalPages": 1,
  "totalRegions": 7,
  "efficiency": 0.95367,
  "allocatedEfficiency": 0.97285,
  "channels": {
    "albedo": "crowd_atlas_albedo.png",
    "normal": "crowd_atlas_normal.png",
    "roughness": "crowd_atlas_roughness.png",
    "metallic": "crowd_atlas_metallic.png",
    "orm": "crowd_atlas_orm.png"
  },
  "regions": {
    "soldier_body": {
      "id": "soldier_body",
      "name": "soldier_body",
      "pageIndex": 0,
      "pixel": {"x": 4, "y": 4, "width": 1000, "height": 1000},
      "outerPixel": {"x": 0, "y": 0, "width": 1008, "height": 1008},
      "uv": {
        "uMin": 0.001953125,
        "vMin": 0.001953125,
        "uMax": 0.490234375,
        "vMax": 0.490234375,
        "uScale": 0.48828125,
        "vScale": 0.48828125,
        "uOffset": 0.001953125,
        "vOffset": 0.001953125
      },
      "channels": {
        "albedo": "textures/soldier_body_albedo.png",
        "normal": "textures/soldier_body_normal.png",
        "roughness": "textures/soldier_body_roughness.png",
        "metallic": "textures/soldier_body_metallic.png"
      }
    },
    "soldier_armor": {
      "id": "soldier_armor",
      "name": "soldier_armor",
      "pageIndex": 0,
      "pixel": {"x": 1012, "y": 4, "width": 1000, "height": 1000},
      "outerPixel": {"x": 1008, "y": 0, "width": 1008, "height": 1008},
      "uv": {
        "uMin": 0.494140625,
        "vMin": 0.001953125,
        "uMax": 0.982421875,
        "vMax": 0.490234375,
        "uScale": 0.48828125,
        "vScale": 0.48828125,
        "uOffset": 0.494140625,
        "vOffset": 0.001953125
      },
      "channels": {
        "albedo": "textures/soldier_armor_albedo.png",
        "normal": "textures/soldier_armor_normal.png"
      }
    },
    "orc_boss": {
      "id": "orc_boss",
      "name": "orc_boss",
      "pageIndex": 0,
      "pixel": {"x": 4, "y": 1012, "width": 1000, "height": 1000},
      "outerPixel": {"x": 0, "y": 1008, "width": 1008, "height": 1008},
      "uv": {
        "uMin": 0.001953125,
        "vMin": 0.494140625,
        "uMax": 0.490234375,
        "vMax": 0.982421875,
        "uScale": 0.48828125,
        "vScale": 0.48828125,
        "uOffset": 0.001953125,
        "vOffset": 0.494140625
      },
      "channels": {
        "albedo": "C:\\\\game\\\\assets\\\\textures\\\\orc_boss_albedo.png"
      }
    },
    "soldier_head": {
      "id": "soldier_head",
      "name": "soldier_head",
      "pageIndex": 0,
      "pixel": {"x": 1012, "y": 1012, "width": 500, "height": 500},
      "outerPixel": {"x": 1008, "y": 1008, "width": 508, "height": 508},
      "uv": {
        "uMin": 0.494140625,
        "vMin": 0.494140625,
        "uMax": 0.73828125,
        "vMax": 0.73828125,
        "uScale": 0.244140625,
        "vScale": 0.244140625,
        "uOffset": 0.494140625,
        "vOffset": 0.494140625
      },
      "channels": {}
    },
    "soldier_shield": {
      "id": "soldier_shield",
      "name": "soldier_shield",
      "pageIndex": 0,
      "pixel": {"x": 1520, "y": 1012, "width": 500, "height": 500},
      "outerPixel": {"x": 1516, "y": 1008, "width": 508, "height": 508},
      "uv": {
        "uMin": 0.7421875,
        "vMin": 0.494140625,
        "uMax": 0.986328125,
        "vMax": 0.73828125,
        "uScale": 0.244140625,
        "vScale": 0.244140625,
        "uOffset": 0.7421875,
        "vOffset": 0.494140625
      },
      "channels": {}
    },
    "soldier_sword": {
      "id": "soldier_sword",
      "name": "soldier_sword",
      "pageIndex": 0,
      "pixel": {"x": 1012, "y": 1520, "width": 500, "height": 500},
      "outerPixel": {"x": 1008, "y": 1516, "width": 508, "height": 508},
      "uv": {
        "uMin": 0.494140625,
        "vMin": 0.7421875,
        "uMax": 0.73828125,
        "vMax": 0.986328125,
        "uScale": 0.244140625,
        "vScale": 0.244140625,
        "uOffset": 0.494140625,
        "vOffset": 0.7421875
      },
      "channels": {}
    },
    "soldier_helmet": {
      "id": "soldier_helmet",
      "name": "soldier_helmet",
      "pageIndex": 0,
      "pixel": {"x": 1520, "y": 1520, "width": 500, "height": 500},
      "outerPixel": {"x": 1516, "y": 1516, "width": 508, "height": 508},
      "uv": {
        "uMin": 0.7421875,
        "vMin": 0.7421875,
        "uMax": 0.986328125,
        "vMax": 0.986328125,
        "uScale": 0.244140625,
        "vScale": 0.244140625,
        "uOffset": 0.7421875,
        "vOffset": 0.7421875
      },
      "channels": {}
    }
  }
}
''';

void main() {
  group('AtlasPixelRect Geometry & Serialization', () {
    test('calculates correct area and boundary values', () {
      const rect = AtlasPixelRect(x: 10, y: 20, width: 200, height: 100);
      expect(rect.right, 210);
      expect(rect.bottom, 120);
      expect(rect.area, 20000);
    });

    test('intersection detection is accurate', () {
      const r1 = AtlasPixelRect(x: 0, y: 0, width: 100, height: 100);
      const r2 = AtlasPixelRect(x: 50, y: 50, width: 100, height: 100);
      const r3 = AtlasPixelRect(x: 100, y: 100, width: 50, height: 50); // Edge-adjacent, no overlap
      const r4 = AtlasPixelRect(x: 200, y: 200, width: 50, height: 50); // Disjoint

      expect(r1.intersects(r2), isTrue);
      expect(r2.intersects(r1), isTrue);
      expect(r1.intersects(r3), isFalse);
      expect(r1.intersects(r4), isFalse);
    });

    test('containment checks are accurate', () {
      const outer = AtlasPixelRect(x: 0, y: 0, width: 500, height: 500);
      const inner = AtlasPixelRect(x: 10, y: 10, width: 100, height: 100);
      const outside = AtlasPixelRect(x: 400, y: 400, width: 200, height: 200);

      expect(outer.contains(inner), isTrue);
      expect(inner.contains(outer), isFalse);
      expect(outer.contains(outside), isFalse);
    });

    test('toJson and fromJson round-trip perfectly', () {
      const original = AtlasPixelRect(x: 16, y: 32, width: 512, height: 256);
      final json = original.toJson();
      final restored = AtlasPixelRect.fromJson(json);

      expect(restored.x, original.x);
      expect(restored.y, original.y);
      expect(restored.width, original.width);
      expect(restored.height, original.height);
      expect(restored.area, original.area);
    });
  });

  group('AtlasUVRect Boundaries and Remap Math', () {
    test('validates normalized coordinate boundaries', () {
      const validRect = AtlasUVRect(
        uMin: 0.1,
        vMin: 0.2,
        uMax: 0.5,
        vMax: 0.6,
        uScale: 0.4,
        vScale: 0.4,
        uOffset: 0.1,
        vOffset: 0.2,
      );
      expect(validRect.isValid(), isTrue);

      const invalidRect = AtlasUVRect(
        uMin: 0.6,
        vMin: 0.2,
        uMax: 0.4, // uMin > uMax (inverted)
        vMax: 0.6,
        uScale: -0.2,
        vScale: 0.4,
        uOffset: 0.6,
        vOffset: 0.2,
      );
      expect(invalidRect.isValid(), isFalse);
    });

    test('remaps normalized coordinates accurately', () {
      final rect = AtlasUVRect.fromBounds(
        uMin: 0.25,
        vMin: 0.50,
        uMax: 0.75,
        vMax: 1.00,
      );

      // (0, 0) -> bottom-left / origin of subtexture
      final (u0, v0) = rect.remap(0.0, 0.0);
      expect(u0, closeTo(0.25, 1e-6));
      expect(v0, closeTo(0.50, 1e-6));

      // (1, 1) -> top-right of subtexture
      final (u1, v1) = rect.remap(1.0, 1.0);
      expect(u1, closeTo(0.75, 1e-6));
      expect(v1, closeTo(1.00, 1e-6));

      // (0.5, 0.5) -> center of subtexture
      final (uMid, vMid) = rect.remap(0.5, 0.5);
      expect(uMid, closeTo(0.50, 1e-6));
      expect(vMid, closeTo(0.75, 1e-6));
    });

    test('supports flipY coordinate convention', () {
      final rect = AtlasUVRect.fromBounds(
        uMin: 0.1,
        vMin: 0.2,
        uMax: 0.6,
        vMax: 0.8,
      );

      // In flipY: v=0 maps to vMax (0.8), v=1 maps to vMin (0.2)
      final (u0, v0) = rect.remap(0.0, 0.0, flipY: true);
      expect(u0, closeTo(0.1, 1e-6));
      expect(v0, closeTo(0.8, 1e-6));

      final (u1, v1) = rect.remap(1.0, 1.0, flipY: true);
      expect(u1, closeTo(0.6, 1e-6));
      expect(v1, closeTo(0.2, 1e-6));
    });
  });

  group('TextureAtlasMetadata & Packing Efficiency Verification', () {
    test('parses metadata and verifies packing efficiency exceeds 85%', () {
      final meta = TextureAtlasMetadata.parseJsonString(sampleAtlasJson);

      expect(meta.atlasWidth, 2048);
      expect(meta.atlasHeight, 2048);
      expect(meta.totalRegions, 7);
      expect(meta.padding, 4);

      // Verify actual content packing efficiency:
      // (3 * 1,000,000 + 4 * 250,000) / 4,194,304 = 4,000,000 / 4,194,304 = 95.367%
      final actualEfficiency = meta.calculateActualContentEfficiency();
      expect(
        actualEfficiency,
        greaterThan(0.85),
        reason: 'Packing efficiency must exceed 85% requirement',
      );
      expect(actualEfficiency, closeTo(0.95367, 1e-4));
      expect(meta.efficiency, closeTo(0.95367, 1e-4));
    });

    test('verifies integrity validation detects zero errors on clean atlas', () {
      final meta = TextureAtlasMetadata.parseJsonString(sampleAtlasJson);
      final errors = meta.validateIntegrity();
      expect(errors, isEmpty, reason: 'Valid atlas should have no errors');
    });

    test('detects out-of-bounds UVs or overlapping regions when corrupt', () {
      final decoded = jsonDecode(sampleAtlasJson) as Map<String, dynamic>;
      final regions = decoded['regions'] as Map<String, dynamic>;

      // Force soldier_body and soldier_armor to overlap
      (regions['soldier_armor']['pixel'] as Map<String, dynamic>)['x'] = 100;
      (regions['soldier_armor']['pixel'] as Map<String, dynamic>)['y'] = 100;

      final corruptedMeta = TextureAtlasMetadata.fromJson(decoded);
      final errors = corruptedMeta.validateIntegrity();

      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('overlap')), isTrue);
    });
  });

  group('TextureAtlasManager Runtime Resolution & Transforms', () {
    late TextureAtlasManager manager;

    setUp(() {
      manager = TextureAtlasManager();
      manager.loadFromJsonString(sampleAtlasJson);
    });

    test('resolves region by ID, name, and normalized file path', () {
      expect(manager.hasRegion('soldier_body'), isTrue);
      expect(manager.hasRegion('orc_boss'), isTrue);

      final r1 = manager.getRegion('soldier_body');
      expect(r1, isNotNull);
      expect(r1!.id, 'soldier_body');

      // Resolve by path with forward and backward slashes
      final r2 = manager.getRegionByPath('textures/soldier_body_albedo.png');
      expect(r2, isNotNull);
      expect(r2!.id, 'soldier_body');

      final r3 = manager.getRegionByPath('c:/game/assets/textures/orc_boss_albedo.png');
      expect(r3, isNotNull);
      expect(r3!.id, 'orc_boss');
    });

    test('fallback returns identity UV when not in strict mode', () {
      manager.strict = false;
      final fallback = manager.getRegion('unknown_texture_key');
      expect(fallback, isNotNull);
      expect(fallback!.uMin, 0.0);
      expect(fallback.uMax, 1.0);
      expect(fallback.uScale, 1.0);

      // In strict mode, throws ArgumentError
      manager.strict = true;
      expect(() => manager.getRegion('unknown_texture_key'), throwsArgumentError);
    });

    test('remaps single UV coordinates correctly', () {
      final (u0, v0) = manager.remapUV('soldier_body', 0.0, 0.0);
      expect(u0, closeTo(0.001953125, 1e-6));
      expect(v0, closeTo(0.001953125, 1e-6));

      final (u1, v1) = manager.remapUV('soldier_body', 1.0, 1.0);
      expect(u1, closeTo(0.490234375, 1e-6));
      expect(v1, closeTo(0.490234375, 1e-6));

      final (uMid, vMid) = manager.remapUV('soldier_body', 0.5, 0.5);
      expect(uMid, closeTo(0.24609375, 1e-6));
      expect(vMid, closeTo(0.24609375, 1e-6));
    });

    test('batch transforms mesh Float32List UV buffer for 10,000 vertices', () {
      // 10,000 vertices -> 20,000 floats (u, v pairs)
      const vertexCount = 10000;
      final originalUVs = Float32List(vertexCount * 2);

      for (int i = 0; i < vertexCount; i++) {
        final double u = (i % 100) / 100.0;
        final double v = (i / 100) / 100.0;
        originalUVs[i * 2] = u;
        originalUVs[i * 2 + 1] = v;
      }

      final stopwatch = Stopwatch()..start();
      final remapped = manager.remapMeshUVBuffer(
        originalUVs,
        'soldier_body',
        inPlace: false,
      );
      stopwatch.stop();

      expect(remapped.length, 20000);
      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: '10,000 vertices must transform in under 50ms');

      // Check vertex 0 (u=0, v=0)
      expect(remapped[0], closeTo(0.001953125, 1e-6));
      expect(remapped[1], closeTo(0.001953125, 1e-6));

      // In-place transform verification
      manager.remapMeshUVBuffer(originalUVs, 'soldier_body', inPlace: true);
      expect(originalUVs[0], closeTo(0.001953125, 1e-6));
      expect(originalUVs[1], closeTo(0.001953125, 1e-6));
    });

    test('generates material shader uniform vector4 [uOffset, vOffset, uScale, vScale]', () {
      final vec4 = manager.getMaterialUniforms('soldier_body');
      expect(vec4.length, 4);
      expect(vec4[0], closeTo(0.001953125, 1e-6)); // uOffset
      expect(vec4[1], closeTo(0.001953125, 1e-6)); // vOffset
      expect(vec4[2], closeTo(0.48828125, 1e-6));  // uScale
      expect(vec4[3], closeTo(0.48828125, 1e-6));  // vScale
    });

    test('generates GPU crowd instance buffer for 10,000 crowd instances', () {
      const crowdCount = 10000;
      final instanceKeys = List<String>.generate(
        crowdCount,
        (i) => (i % 2 == 0) ? 'soldier_body' : 'orc_boss',
      );

      final stopwatch = Stopwatch()..start();
      final instanceBuffer = manager.generateCrowdInstanceBuffer(instanceKeys);
      stopwatch.stop();

      expect(instanceBuffer.length, crowdCount * 4); // 40,000 floats
      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: '10,000 instance uniforms must build under 50ms');

      // Instance 0 (soldier_body)
      expect(instanceBuffer[0], closeTo(0.001953125, 1e-6));
      expect(instanceBuffer[1], closeTo(0.001953125, 1e-6));
      expect(instanceBuffer[2], closeTo(0.48828125, 1e-6));
      expect(instanceBuffer[3], closeTo(0.48828125, 1e-6));

      // Instance 1 (orc_boss)
      expect(instanceBuffer[4], closeTo(0.001953125, 1e-6));
      expect(instanceBuffer[5], closeTo(0.494140625, 1e-6));
      expect(instanceBuffer[6], closeTo(0.48828125, 1e-6));
      expect(instanceBuffer[7], closeTo(0.48828125, 1e-6));
    });

    test('audit report computes accurate statistics and draw call reductions', () {
      final report = manager.generateAuditReport();
      expect(report['totalAtlasSheets'], 1);
      expect(report['totalSubtextures'], 7);
      expect(report['exceeds85Target'], isTrue);
      expect(report['estimatedDrawCallReduction'], 6);
      expect(report['gpuCrowdInstancingReady'], isTrue);
    });
  });
}
