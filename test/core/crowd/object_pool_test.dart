import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/object_pool.dart';

class TestPoolable extends PoolableBase {
  int customValue = 0;
  String tag = '';

  TestPoolable([int index = -1]) {
    poolIndex = index;
  }

  @override
  void onLease() {
    customValue = 42;
    tag = 'leased';
  }

  @override
  void onRecycle() {
    customValue = 0;
    tag = '';
  }
}

void main() {
  setUp(() {
    ObjectPoolRegistry.resetInstance();
  });

  tearDown(() {
    ObjectPoolRegistry.resetInstance();
  });

  group('ObjectPool<T> — Pre-allocation & Capacity', () {
    test('pre-allocates all instances on construction and starts 100% available', () {
      const capacity = 100;
      int factoryInvocations = 0;

      final pool = ObjectPool<TestPoolable>(
        capacity: capacity,
        factory: (index) {
          factoryInvocations++;
          return TestPoolable(index);
        },
      );

      expect(factoryInvocations, equals(capacity));
      expect(pool.capacity, equals(capacity));
      expect(pool.availableCount, equals(capacity));
      expect(pool.leasedCount, equals(0));
      expect(pool.isFull, isTrue);
      expect(pool.isExhausted, isFalse);
    });

    test('all pre-allocated instances have unique poolIndex and isLeased is false', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 50,
        factory: (index) => TestPoolable(index),
      );

      final leasedList = <TestPoolable>[];
      for (int i = 0; i < 50; i++) {
        final item = pool.lease();
        expect(item.isLeased, isTrue);
        expect(item.poolIndex, inInclusiveRange(0, 49));
        leasedList.add(item);
      }

      // Check all 50 indices are unique
      final indices = leasedList.map((e) => e.poolIndex).toSet();
      expect(indices.length, equals(50));

      pool.recycleBatch(leasedList);
      expect(pool.isFull, isTrue);
    });
  });

  group('ObjectPool<T> — Double-Release Protection & Safety', () {
    test('recycling an already recycled object throws DoubleReleaseException', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 10,
        factory: (i) => TestPoolable(i),
      );

      final item = pool.lease();
      expect(item.isLeased, isTrue);

      pool.recycle(item);
      expect(item.isLeased, isFalse);

      // Attempt second recycle
      expect(
        () => pool.recycle(item),
        throwsA(isA<DoubleReleaseException>()),
      );
    });

    test('recycling an unleased newly constructed object throws DoubleReleaseException', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 10,
        factory: (i) => TestPoolable(i),
      );

      final foreign = TestPoolable(99);
      expect(
        () => pool.recycle(foreign),
        throwsA(isA<DoubleReleaseException>()),
      );
    });

    test('recycling an object from Pool A into Pool B throws ForeignObjectException', () {
      final poolA = ObjectPool<TestPoolable>(
        capacity: 5,
        factory: (i) => TestPoolable(i),
      );
      final poolB = ObjectPool<TestPoolable>(
        capacity: 5,
        factory: (i) => TestPoolable(i),
      );

      final itemA = poolA.lease();
      expect(itemA.isLeased, isTrue);

      expect(
        () => poolB.recycle(itemA),
        throwsA(isA<ForeignObjectException>()),
      );
    });
  });

  group('ObjectPool<T> — Reset Hooks & Re-lease Cleanliness', () {
    test('dirty modifications are cleanly wiped by onRecycle upon re-lease', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 5,
        factory: (i) => TestPoolable(i),
      );

      // 1. Lease item
      final item = pool.lease();
      expect(item.customValue, equals(42));
      expect(item.tag, equals('leased'));

      // 2. Pollute state
      item.customValue = 999999;
      item.tag = 'corrupted_state';

      // 3. Recycle item
      pool.recycle(item);
      expect(item.customValue, equals(0));
      expect(item.tag, equals(''));

      // 4. Re-lease same slot
      final reLeased = pool.lease();
      expect(identical(reLeased, item), isTrue);
      expect(reLeased.customValue, equals(42)); // onLease reset to 42
      expect(reLeased.tag, equals('leased'));
    });

    test('pool-level onResetHook and onLeaseHook execute during lifecycle', () {
      int poolResetCalls = 0;
      int poolLeaseCalls = 0;

      final pool = ObjectPool<TestPoolable>(
        capacity: 5,
        factory: (i) => TestPoolable(i),
        onLeaseHook: (obj) => poolLeaseCalls++,
        onResetHook: (obj) => poolResetCalls++,
      );

      final obj = pool.lease();
      expect(poolLeaseCalls, equals(1));
      expect(poolResetCalls, equals(0));

      pool.recycle(obj);
      expect(poolLeaseCalls, equals(1));
      expect(poolResetCalls, equals(1));
    });
  });

  group('ObjectPool<T> — Exhaustion Policies & Batch Operations', () {
    test('throwException policy throws PoolExhaustedException when empty', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 2,
        factory: (i) => TestPoolable(i),
        exhaustionPolicy: PoolExhaustionPolicy.throwException,
      );

      final a = pool.lease();
      final b = pool.lease();
      expect(pool.isExhausted, isTrue);

      expect(
        () => pool.lease(),
        throwsA(isA<PoolExhaustedException>()),
      );

      pool.recycle(a);
      expect(pool.isExhausted, isFalse);
      expect(pool.availableCount, equals(1));

      pool.recycle(b);
      expect(pool.isFull, isTrue);
    });

    test('recycleOldest policy evicts oldest leased object on overflow', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 2,
        factory: (i) => TestPoolable(i),
        exhaustionPolicy: PoolExhaustionPolicy.recycleOldest,
      );

      final first = pool.lease();
      first.tag = 'first_leased';

      final second = pool.lease();
      second.tag = 'second_leased';

      expect(pool.isExhausted, isTrue);

      // Third lease should evict the oldest leased object (first)
      final third = pool.lease();
      expect(identical(third, first), isTrue);
      expect(third.tag, equals('leased')); // reset by onLease
    });

    test('grow policy dynamically expands capacity when exhausted', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 2,
        factory: (i) => TestPoolable(i),
        exhaustionPolicy: PoolExhaustionPolicy.grow,
      );

      pool.lease();
      pool.lease();
      expect(pool.capacity, equals(2));

      // Overflows -> grows to 4
      pool.lease();
      expect(pool.capacity, equals(4));
      expect(pool.metrics.growCount, equals(1));

      pool.recycleAll();
      expect(pool.availableCount, equals(4));
      expect(pool.isFull, isTrue);
    });

    test('leaseBatch and recycleBatch operate without list allocations', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 10,
        factory: (i) => TestPoolable(i),
      );

      final preallocatedDest = <TestPoolable>[];
      final leased = pool.leaseBatch(6, preallocatedDest);

      expect(leased, equals(6));
      expect(preallocatedDest.length, equals(6));
      expect(pool.availableCount, equals(4));
      expect(pool.leasedCount, equals(6));

      pool.recycleBatch(preallocatedDest);
      expect(pool.isFull, isTrue);
      expect(pool.availableCount, equals(10));
    });

    test('recycleAll restores entire pool from partial lease state', () {
      final pool = ObjectPool<TestPoolable>(
        capacity: 20,
        factory: (i) => TestPoolable(i),
      );

      for (int i = 0; i < 15; i++) {
        pool.lease();
      }
      expect(pool.leasedCount, equals(15));
      expect(pool.availableCount, equals(5));

      pool.recycleAll();
      expect(pool.leasedCount, equals(0));
      expect(pool.availableCount, equals(20));
      expect(pool.isFull, isTrue);
    });
  });

  group('Specialized Pool: CrowdEntity & CrowdEntityPool (10K Churn)', () {
    test('CrowdEntityPool pre-allocates 10,000 entities without allocation spikes', () {
      final pool = CrowdEntityPool(capacity: 10000);

      expect(pool.capacity, equals(10000));
      expect(pool.availableCount, equals(10000));
      expect(pool.isFull, isTrue);
    });

    test('CrowdEntity computes 4x4 matrix into transformBuffer in-place with 0 GC', () {
      final pool = CrowdEntityPool(capacity: 10);
      final entity = pool.lease();

      entity.x = 100.0;
      entity.y = 15.0;
      entity.z = -50.0;
      entity.yaw = 1.57079632679; // pi / 2 (90 deg)
      entity.scaleX = 2.0;
      entity.scaleY = 2.0;
      entity.scaleZ = 2.0;

      entity.updateTransformBuffer();

      // Check translation in column 3
      expect(entity.transformBuffer[12], closeTo(100.0, 0.001));
      expect(entity.transformBuffer[13], closeTo(15.0, 0.001));
      expect(entity.transformBuffer[14], closeTo(-50.0, 0.001));
      expect(entity.transformBuffer[15], equals(1.0));

      // Check Y-scale in column 1
      expect(entity.transformBuffer[5], closeTo(2.0, 0.001));

      // Copy into target GPU buffer without allocating
      final gpuBuffer = Float32List(160);
      entity.copyTransformTo(gpuBuffer, 0);
      expect(gpuBuffer[12], closeTo(100.0, 0.001));

      pool.recycle(entity);
      expect(pool.isFull, isTrue);
    });

    test('CrowdEntity pack VAT packet copies 8 floats accurately', () {
      final pool = CrowdEntityPool(capacity: 5);
      final entity = pool.lease();

      entity.x = 25.0;
      entity.y = 2.0;
      entity.z = 75.0;
      entity.yaw = 3.14159;
      entity.scaleX = 1.5;
      entity.animationTime = 0.45;
      entity.typeId = 2;
      entity.flags = 3;

      final vatBuffer = Float32List(8);
      entity.copyVatPacketTo(vatBuffer, 0);

      expect(vatBuffer[0], equals(25.0));
      expect(vatBuffer[1], equals(2.0));
      expect(vatBuffer[2], equals(75.0));
      expect(vatBuffer[3], closeTo(3.14159, 0.001));
      expect(vatBuffer[4], equals(1.5));
      expect(vatBuffer[5], closeTo(0.45, 0.001));
      expect(vatBuffer[6], equals(2.0));
      expect(vatBuffer[7], equals(3.0));

      pool.recycle(entity);
    });

    test('simulates 10,000 crowd spawn/despawn churn cycle with zero failures', () {
      const churnCount = 10000;
      final pool = CrowdEntityPool(capacity: churnCount);

      // Pre-allocated active array to simulate zero-allocation crowd manager loop
      final activeEntities = List<CrowdEntity?>.filled(churnCount, null);

      final stopwatch = Stopwatch()..start();

      // 5 consecutive heavy churn cycles (50,000 total leases and 50,000 recycles)
      for (int cycle = 0; cycle < 5; cycle++) {
        // Spawn 10,000
        for (int i = 0; i < churnCount; i++) {
          final entity = pool.lease();
          entity.id = i;
          entity.x = i * 0.5;
          entity.z = i * 0.25;
          entity.health = 80.0;
          activeEntities[i] = entity;
        }

        expect(pool.availableCount, equals(0));
        expect(pool.leasedCount, equals(churnCount));

        // Despawn 10,000
        for (int i = 0; i < churnCount; i++) {
          final entity = activeEntities[i]!;
          pool.recycle(entity);
          activeEntities[i] = null;
        }

        expect(pool.availableCount, equals(churnCount));
        expect(pool.leasedCount, equals(0));
      }

      stopwatch.stop();

      // 50,000 operations should complete in well under 250ms
      expect(stopwatch.elapsedMilliseconds, lessThan(250));
      expect(pool.metrics.totalLeases, equals(50000));
      expect(pool.metrics.totalRecycles, equals(50000));
      expect(pool.metrics.peakLeased, equals(10000));
    });
  });

  group('Specialized Pool: ParticleNode & ParticleNodePool', () {
    test('ParticleNode Euler integration steps physics and fades alpha', () {
      final pool = ParticleNodePool(capacity: 100);
      final p = pool.lease();

      p.x = 0.0;
      p.y = 10.0;
      p.z = 0.0;
      p.vx = 2.0;
      p.vy = 5.0;
      p.vz = 0.0;
      p.ax = 0.0;
      p.ay = -10.0; // gravity
      p.az = 0.0;
      p.life = 0.0;
      p.maxLife = 1.0;
      p.startSize = 2.0;
      p.endSize = 0.5;

      p.step(0.5); // half life

      expect(p.life, equals(0.5));
      expect(p.isAlive, isTrue);
      expect(p.normalizedLife, equals(0.5));
      expect(p.size, closeTo(1.25, 0.001));
      expect(p.a, closeTo(0.5, 0.001));

      p.step(0.6); // expires life
      expect(p.isAlive, isFalse);

      pool.recycle(p);
      expect(pool.isFull, isTrue);
    });

    test('ParticleNode copies 8 packed floats to GPU buffer', () {
      final pool = ParticleNodePool(capacity: 10);
      final p = pool.lease();

      p.x = 1.0;
      p.y = 2.0;
      p.z = 3.0;
      p.size = 1.5;
      p.r = 0.9;
      p.g = 0.4;
      p.b = 0.1;
      p.a = 0.8;

      final gpuBuffer = Float32List(8);
      p.copyIntoBuffer(gpuBuffer, 0);

      expect(gpuBuffer[0], equals(1.0));
      expect(gpuBuffer[1], equals(2.0));
      expect(gpuBuffer[2], equals(3.0));
      expect(gpuBuffer[3], equals(1.5));
      expect(gpuBuffer[4], closeTo(0.9, 0.001));
      expect(gpuBuffer[5], closeTo(0.4, 0.001));
      expect(gpuBuffer[6], closeTo(0.1, 0.001));
      expect(gpuBuffer[7], closeTo(0.8, 0.001));

      pool.recycle(p);
    });
  });

  group('Specialized Pool: DecalInstance & DecalInstancePool', () {
    test('DecalInstance updates simulation and fades opacity using smoothstep', () {
      final pool = DecalInstancePool(capacity: 50);
      final decal = pool.lease();

      decal.baseOpacity = 1.0;
      decal.totalLifetime = 10.0;
      decal.fadeDuration = 4.0;
      decal.fadeCurve = 1; // smoothStep

      decal.update(4.0); // 6.0s remaining -> not in fade window yet
      expect(decal.currentOpacity, equals(1.0));

      decal.update(4.0); // 2.0s remaining (halfway into 4.0s fade duration)
      expect(decal.elapsedTime, equals(8.0));
      expect(decal.currentOpacity, closeTo(0.5, 0.05));

      decal.update(2.0); // 10.0s reached -> expired
      expect(decal.isExpired, isTrue);
      expect(decal.currentOpacity, equals(0.0));

      pool.recycle(decal);
      expect(pool.isFull, isTrue);
    });
  });

  group('Specialized Pool: Matrix4Buffer & Matrix4BufferPool', () {
    test('Matrix4Buffer initializes as 4x4 identity and compose performs in-place transforms', () {
      final pool = Matrix4BufferPool(capacity: 100);
      final mat = pool.lease();

      // Check identity diagonal
      expect(mat.get(0, 0), equals(1.0));
      expect(mat.get(1, 1), equals(1.0));
      expect(mat.get(2, 2), equals(1.0));
      expect(mat.get(3, 3), equals(1.0));
      expect(mat.get(0, 3), equals(0.0));

      // Compose in-place
      mat.compose(tx: 50.0, ty: 10.0, tz: -25.0, yaw: 0.0, sx: 2.0, sy: 3.0, sz: 4.0);

      expect(mat.get(0, 3), equals(50.0));
      expect(mat.get(1, 3), equals(10.0));
      expect(mat.get(2, 3), equals(-25.0));
      expect(mat.get(0, 0), equals(2.0));
      expect(mat.get(1, 1), equals(3.0));
      expect(mat.get(2, 2), equals(4.0));

      pool.recycle(mat);
      expect(pool.isFull, isTrue);
    });

    test('Matrix4Buffer in-place multiply computes accurate transformation product', () {
      final pool = Matrix4BufferPool(capacity: 10);
      final matA = pool.lease();
      final matB = pool.lease();
      final result = pool.lease();

      matA.setTranslation(10.0, 20.0, 30.0);
      matB.setScale(2.0, 2.0, 2.0);

      result.multiply(matA, matB);

      // Result should have scale 2 and translation (10, 20, 30)
      expect(result.get(0, 0), equals(2.0));
      expect(result.get(1, 1), equals(2.0));
      expect(result.get(2, 2), equals(2.0));
      expect(result.get(0, 3), equals(10.0));
      expect(result.get(1, 3), equals(20.0));
      expect(result.get(2, 3), equals(30.0));

      pool.recycle(matA);
      pool.recycle(matB);
      pool.recycle(result);
      expect(pool.isFull, isTrue);
    });
  });

  group('Specialized Pool: Float32BufferPool', () {
    test('Float32BufferPool leases and recycles zeroed float scratch buffers', () {
      final pool = Float32BufferPool(capacity: 20, bufferSize: 1024);

      final scratch = pool.lease();
      expect(scratch.length, equals(1024));
      expect(scratch.buffer[0], equals(0.0));

      // Write values
      scratch.buffer[0] = 123.45;
      scratch.buffer[1023] = 678.90;

      pool.recycle(scratch);

      // Re-lease verifies buffer is zeroed
      final reLeased = pool.lease();
      expect(reLeased.buffer[0], equals(0.0));
      expect(reLeased.buffer[1023], equals(0.0));

      pool.recycle(reLeased);
      expect(pool.isFull, isTrue);
    });
  });

  group('ObjectPoolRegistry — Singleton Coordination & Metrics', () {
    test('manages centralized pools and collects comprehensive metrics summary', () {
      final registry = ObjectPoolRegistry(
        crowdCapacity: 200,
        particleCapacity: 100,
        decalCapacity: 50,
        matrixCapacity: 200,
      );

      registry.crowdEntityPool.lease();
      registry.particlePool.lease();
      registry.decalPool.lease();
      registry.matrixPool.lease();

      final summary = registry.getMetricsSummary();
      expect(summary.containsKey('CrowdEntities'), isTrue);
      expect(summary.containsKey('Particles'), isTrue);
      expect(summary.containsKey('Decals'), isTrue);
      expect(summary.containsKey('Matrices'), isTrue);

      expect(summary['CrowdEntities']!.currentLeased, equals(1));
      expect(summary['CrowdEntities']!.capacity, equals(200));

      // Recycle all globally
      registry.recycleAll();

      final updatedSummary = registry.getMetricsSummary();
      expect(updatedSummary['CrowdEntities']!.currentLeased, equals(0));
      expect(updatedSummary['CrowdEntities']!.currentAvailable, equals(200));
      expect(updatedSummary['Particles']!.currentLeased, equals(0));
      expect(updatedSummary['Decals']!.currentLeased, equals(0));
      expect(updatedSummary['Matrices']!.currentLeased, equals(0));
    });
  });
}
