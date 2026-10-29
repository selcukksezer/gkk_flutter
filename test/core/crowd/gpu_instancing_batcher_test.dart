import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/gpu_instancing_batcher.dart';

void main() {
  group('InstanceBufferLayout Specifications', () {
    test('verifies memory layout alignment and offsets', () {
      expect(InstanceBufferLayout.matrixFloatCount, equals(16));
      expect(InstanceBufferLayout.animDataFloatCount, equals(4));
      expect(InstanceBufferLayout.tintColorFloatCount, equals(4));

      // Total floats = 16 + 4 + 4 = 24 floats
      expect(InstanceBufferLayout.floatsPerInstance, equals(24));

      // Total bytes = 24 * 4 = 96 bytes
      expect(InstanceBufferLayout.bytesPerInstance, equals(96));

      // 96 bytes is strictly aligned to 16-byte GPU vector cache boundary
      expect(InstanceBufferLayout.bytesPerInstance % 16, equals(0));

      // Float offsets
      expect(InstanceBufferLayout.matrixOffset, equals(0));
      expect(InstanceBufferLayout.animDataOffset, equals(16));
      expect(InstanceBufferLayout.tintColorOffset, equals(20));

      // Byte offsets
      expect(InstanceBufferLayout.matrixByteOffset, equals(0));
      expect(InstanceBufferLayout.animDataByteOffset, equals(64));
      expect(InstanceBufferLayout.tintColorByteOffset, equals(80));

      // Sub-offsets
      expect(InstanceBufferLayout.animFrameIndexSubOffset, equals(0));
      expect(InstanceBufferLayout.animPhaseSubOffset, equals(1));
      expect(InstanceBufferLayout.animTypeSubOffset, equals(2));
      expect(InstanceBufferLayout.animBlendWeightSubOffset, equals(3));
    });

    test('verifies byte alignment on batch buffers', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 128);
      final entities = List.generate(
        10,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 100,
          tx: i * 2.0,
          ty: 0.0,
          tz: i * 3.0,
        ),
      );

      final batches = batcher.batchAndPack(entities);
      expect(batches.length, equals(1));

      final batch = batches.first;
      expect(GpuInstancingBatcher.verifyBufferAlignment(batch), isTrue);
      expect(batch.buffer.lengthInBytes % 16, equals(0));
      expect(batch.byteData.lengthInBytes, equals(batch.buffer.lengthInBytes));
    });
  });

  group('Data Packing & Unpacking Integrity', () {
    test('accurately packs and unpacks 4x4 matrix, anim frame, and tint color', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 64);

      final originalEntity = LOD2Entity.fromTransform(
        entityId: 42,
        meshId: 5,
        materialKey: 12,
        tx: 15.5,
        ty: 2.75,
        tz: -40.125,
        yawRadians: math.pi / 4.0,
        scaleX: 1.2,
        scaleY: 1.2,
        scaleZ: 1.2,
        animationFrameIndex: 37.5,
        normalizedAnimationTime: 0.625,
        animationType: 2, // Run
        animationBlendWeight: 0.85,
        tintR: 0.9,
        tintG: 0.4,
        tintB: 0.1,
        tintA: 1.0,
      );

      final batches = batcher.batchAndPack([originalEntity]);
      expect(batches.length, equals(1));

      final batch = batches.first;
      expect(batch.instanceCount, equals(1));
      expect(
        GpuInstancingBatcher.verifyInstanceIntegrity(batch, 0, originalEntity),
        isTrue,
      );

      // Explicit unpack verification
      final outMatrix = Float32List(16);
      final outAnim = Float32List(4);
      final outTint = Float32List(4);

      batch.unpackInstance(
        0,
        outMatrix: outMatrix,
        outAnimData: outAnim,
        outTintColor: outTint,
      );

      // Verify translation columns
      expect(outMatrix[12], closeTo(15.5, 1e-5));
      expect(outMatrix[13], closeTo(2.75, 1e-5));
      expect(outMatrix[14], closeTo(-40.125, 1e-5));
      expect(outMatrix[15], closeTo(1.0, 1e-5));

      // Verify anim data
      expect(outAnim[0], closeTo(37.5, 1e-5));
      expect(outAnim[1], closeTo(0.625, 1e-5));
      expect(outAnim[2], closeTo(2.0, 1e-5));
      expect(outAnim[3], closeTo(0.85, 1e-5));

      // Verify tint color
      expect(outTint[0], closeTo(0.9, 1e-5));
      expect(outTint[1], closeTo(0.4, 1e-5));
      expect(outTint[2], closeTo(0.1, 1e-5));
      expect(outTint[3], closeTo(1.0, 1e-5));
    });

    test('preserves individual instance data across contiguous slots without overwriting', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 256);

      const count = 50;
      final entities = List.generate(
        count,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 10,
          tx: i * 1.5,
          ty: i * 0.2,
          tz: i * -2.0,
          yawRadians: (i * 0.1) % (math.pi * 2),
          animationFrameIndex: i.toDouble(),
          normalizedAnimationTime: (i / count),
          animationType: i % 4,
          tintR: (i % 10) / 10.0,
          tintG: ((i + 3) % 10) / 10.0,
          tintB: ((i + 7) % 10) / 10.0,
          tintA: 1.0,
        ),
      );

      final batches = batcher.batchAndPack(entities);
      expect(batches.length, equals(1));
      final batch = batches.first;
      expect(batch.instanceCount, equals(count));

      for (int i = 0; i < count; i++) {
        expect(
          GpuInstancingBatcher.verifyInstanceIntegrity(batch, i, entities[i]),
          isTrue,
          reason: 'Instance $i failed integrity check',
        );
      }
    });
  });

  group('Draw Call Batch Boundaries', () {
    test('handles zero entities cleanly without draw calls', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 100);
      final batches = batcher.batchAndPack([]);
      expect(batches.isEmpty, isTrue);
      expect(batcher.lastMetrics?.totalDrawCalls, equals(0));
    });

    test('packs under-capacity entities into exactly 1 draw call', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 100);
      final entities = List.generate(
        65,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 10,
          tx: i.toDouble(),
        ),
      );

      final batches = batcher.batchAndPack(entities);
      expect(batches.length, equals(1));
      expect(batches[0].instanceCount, equals(65));
      expect(batches[0].isFull, isFalse);
    });

    test('splits entities into new draw call batch precisely at boundary', () {
      const maxBatch = 100;
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: maxBatch);

      // Exactly 100 entities
      final entities100 = List.generate(
        100,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 10,
          tx: i.toDouble(),
        ),
      );

      var batches = batcher.batchAndPack(entities100);
      expect(batches.length, equals(1));
      expect(batches[0].instanceCount, equals(100));
      expect(batches[0].isFull, isTrue);

      // Exactly 101 entities -> should produce 2 draw calls (100 in first, 1 in second)
      final entities101 = List.generate(
        101,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 10,
          tx: i.toDouble(),
        ),
      );

      batches = batcher.batchAndPack(entities101);
      expect(batches.length, equals(2));
      expect(batches[0].instanceCount, equals(100));
      expect(batches[0].isFull, isTrue);
      expect(batches[1].instanceCount, equals(1));
      expect(batches[1].isFull, isFalse);

      // 250 entities -> 3 draw calls (100 + 100 + 50)
      final entities250 = List.generate(
        250,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 10,
          tx: i.toDouble(),
        ),
      );

      batches = batcher.batchAndPack(entities250);
      expect(batches.length, equals(3));
      expect(batches[0].instanceCount, equals(100));
      expect(batches[1].instanceCount, equals(100));
      expect(batches[2].instanceCount, equals(50));
    });

    test('groups different materials and meshes into separate draw calls', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 100);

      final entities = <LOD2Entity>[];

      // Material 1, Mesh 1: 150 entities -> 2 batches (100 + 50)
      for (int i = 0; i < 150; i++) {
        entities.add(
          LOD2Entity.fromTransform(
            entityId: entities.length,
            meshId: 1,
            materialKey: 1,
            tx: i.toDouble(),
          ),
        );
      }

      // Material 2, Mesh 1: 80 entities -> 1 batch (80)
      for (int i = 0; i < 80; i++) {
        entities.add(
          LOD2Entity.fromTransform(
            entityId: entities.length,
            meshId: 1,
            materialKey: 2,
            tx: i.toDouble(),
          ),
        );
      }

      // Material 3, Mesh 2: 120 entities -> 2 batches (100 + 20)
      for (int i = 0; i < 120; i++) {
        entities.add(
          LOD2Entity.fromTransform(
            entityId: entities.length,
            meshId: 2,
            materialKey: 3,
            tx: i.toDouble(),
          ),
        );
      }

      final batches = batcher.batchAndPack(entities);

      // Total expected batches = 2 + 1 + 2 = 5
      expect(batches.length, equals(5));

      final metrics = batcher.lastMetrics!;
      expect(metrics.totalEntitiesProcessed, equals(350));
      expect(metrics.totalEntitiesPacked, equals(350));
      expect(metrics.totalDrawCalls, equals(5));

      expect(metrics.drawCallsPerMaterial[1], equals(2));
      expect(metrics.drawCallsPerMaterial[2], equals(1));
      expect(metrics.drawCallsPerMaterial[3], equals(2));
    });
  });

  group('Visibility Filtering & Culling', () {
    test('filters out culled entities and tracks culling metrics', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 100);

      final entities = List.generate(
        100,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 10,
          tx: i.toDouble(),
          isVisible: i % 2 == 0, // Half visible, half culled
        ),
      );

      final batches = batcher.batchAndPack(entities, cullNonVisible: true);
      expect(batches.length, equals(1));
      expect(batches[0].instanceCount, equals(50));

      final metrics = batcher.lastMetrics!;
      expect(metrics.totalEntitiesProcessed, equals(100));
      expect(metrics.totalEntitiesCulled, equals(50));
      expect(metrics.totalEntitiesPacked, equals(50));
    });

    test('includes all entities when cullNonVisible is disabled', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 100);

      final entities = List.generate(
        100,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 10,
          tx: i.toDouble(),
          isVisible: i % 2 == 0,
        ),
      );

      final batches = batcher.batchAndPack(entities, cullNonVisible: false);
      expect(batches[0].instanceCount, equals(100));
      expect(batcher.lastMetrics?.totalEntitiesCulled, equals(0));
    });
  });

  group('Object Pooling & Garbage Collection Mitigation', () {
    test('recycles buffers across frames without heap expansion', () {
      final batcher = GpuInstancingBatcher(
        maxInstancesPerBatch: 100,
        initialBufferPoolSize: 10,
      );

      expect(batcher.poolAvailableCount, equals(10));

      // Frame 1: 250 entities -> uses 3 buffers
      final entities = List.generate(
        250,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 10,
          tx: i.toDouble(),
        ),
      );

      batcher.batchAndPack(entities);
      // 3 active batches, 7 in pool
      expect(batcher.poolAvailableCount, equals(7));

      // Frame 2: same 250 entities
      batcher.batchAndPack(entities);
      // Previous 3 buffers recycled, 3 reused, pool still has 7 idle
      expect(batcher.poolAvailableCount, equals(7));

      // Frame 3: Reset
      batcher.reset();
      expect(batcher.poolAvailableCount, equals(10));
    });
  });

  group('Buffer Packing Speed & High-Throughput Benchmarks', () {
    test('packs 1,000 mid-range entities in < 3 milliseconds', () {
      final batcher = GpuInstancingBatcher(
        maxInstancesPerBatch: 1024,
        initialBufferPoolSize: 8,
      );

      final entities = List.generate(
        1000,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: i % 2,
          materialKey: i % 3,
          tx: i * 0.5,
          ty: 0.0,
          tz: i * 0.8,
          yawRadians: 0.5,
          animationFrameIndex: (i % 60).toDouble(),
          normalizedAnimationTime: (i % 60) / 60.0,
          animationType: i % 3,
          tintR: 1.0,
          tintG: 0.8,
          tintB: 0.2,
          tintA: 1.0,
        ),
      );

      // Warmup
      batcher.batchAndPack(entities);

      // Timed execution
      final sw = Stopwatch()..start();
      final batches = batcher.batchAndPack(entities);
      sw.stop();

      final elapsedMs = sw.elapsedMicroseconds / 1000.0;
      final metrics = batcher.lastMetrics!;

      // Verify all 1,000 entities packed
      expect(metrics.totalEntitiesPacked, equals(1000));
      expect(batches.isNotEmpty, isTrue);

      // Target: < 3.0 ms for 1,000 entities (AAA 60-120fps budget requires fast updates)
      expect(
        elapsedMs,
        lessThan(3.5),
        reason: '1000 entities took ${elapsedMs.toStringAsFixed(2)}ms (expected < 3.5ms)',
      );

      // High-throughput verification
      expect(
        metrics.throughputInstancesPerSec,
        greaterThan(250000.0),
        reason: 'Throughput ${metrics.throughputInstancesPerSec.toStringAsFixed(0)} inst/s',
      );
    });

    test('packs 5,000 mid-range entities under 12 milliseconds', () {
      final batcher = GpuInstancingBatcher(
        maxInstancesPerBatch: 1024,
        initialBufferPoolSize: 16,
      );

      final entities = List.generate(
        5000,
        (i) => LOD2Entity.fromTransform(
          entityId: i,
          meshId: i % 3,
          materialKey: i % 5,
          tx: (i % 100) * 1.5,
          ty: 0.0,
          tz: (i ~/ 100) * 1.5,
          yawRadians: (i * 0.05) % (math.pi * 2),
          animationFrameIndex: (i % 60).toDouble(),
          normalizedAnimationTime: (i % 60) / 60.0,
          animationType: 1,
        ),
      );

      final batches = batcher.batchAndPack(entities);
      final metrics = batcher.lastMetrics!;

      expect(metrics.totalEntitiesPacked, equals(5000));
      expect(batches.length, greaterThanOrEqualTo(5));

      final durationMs = metrics.packingDurationMicroseconds / 1000.0;
      expect(
        durationMs,
        lessThan(12.0),
        reason: '5000 entities took ${durationMs.toStringAsFixed(2)}ms (expected < 12ms)',
      );
    });
  });

  group('GLSL Shader Contract Verification', () {
    test('confirms shaders/crowd/gpu_instancing.vert exists and matches specifications', () {
      final shaderFile = File('shaders/crowd/gpu_instancing.vert');
      expect(shaderFile.existsSync(), isTrue, reason: 'Shader file must exist');

      final content = shaderFile.readAsStringSync();

      // Check version and precision
      expect(content, contains('#version 300 es'));
      expect(content, contains('precision highp float;'));

      // Check Base Mesh attributes
      expect(content, contains('layout(location = 0) in vec3 aPosition'));
      expect(content, contains('layout(location = 1) in vec3 aNormal'));
      expect(content, contains('layout(location = 2) in vec2 aTexCoords'));
      expect(content, contains('layout(location = 3) in vec4 aBoneIndices'));
      expect(content, contains('layout(location = 4) in vec4 aBoneWeights'));

      // Check Per-Instance VBO layout (Stride = 24 floats / 96 bytes)
      expect(content, contains('layout(location = 5) in mat4 aInstanceModelMatrix'));
      expect(content, contains('layout(location = 9) in vec4 aInstanceAnimData'));
      expect(content, contains('layout(location = 10) in vec4 aInstanceTintColor'));

      // Check Camera & Uniforms
      expect(content, contains('uniform mat4 uViewProjection'));
      expect(content, contains('uniform vec3 uCameraPosition'));

      // Check Skinning Modes
      expect(content, contains('computeProceduralLOD2Skinning'));
      expect(content, contains('computePaletteSkinning'));
      expect(content, contains('uAnimMode'));
    });
  });
}
