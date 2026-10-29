import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/hit_stop_manager.dart';

void main() {
  group('HitStopManager — Preset Timing & Duration Tests', () {
    late HitStopManager manager;

    setUp(() {
      manager = HitStopManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('Light attack preset executes exact 25ms freeze + 10ms smooth ease-out (~35ms)', () {
      bool started = false;
      bool completed = false;

      final ActiveHitStopInstance instance = manager.triggerPreset(
        HitStopPreset.light,
        onStart: () => started = true,
        onComplete: () => completed = true,
      );

      expect(started, isTrue);
      expect(completed, isFalse);
      expect(manager.activeCount, equals(1));

      // At t = 0ms: Target and attacker are frozen at 0.0
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));
      expect(manager.getTimeScale(TimeDilationChannel.target), equals(0.0));
      expect(manager.isChannelFrozen(TimeDilationChannel.attacker), isTrue);

      // Advance by 15ms (within freeze phase: 15ms < 25ms)
      manager.update(0.015);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));
      expect(instance.isInFreezePhase, isTrue);
      expect(completed, isFalse);

      // Advance by 10ms (total 25ms: exact end of freeze phase)
      manager.update(0.010);
      expect(instance.isInFreezePhase, isFalse);
      expect(instance.isInEaseOutPhase, isTrue);

      // Advance by 5ms (total 30ms: midway through 10ms ease-out)
      manager.update(0.005);
      final double midScale = manager.getTimeScale(TimeDilationChannel.attacker);
      expect(midScale, greaterThan(0.0));
      expect(midScale, lessThan(1.0));
      // smoothStep at t=0.5 -> 0.5 * 0.5 * (3 - 2 * 0.5) = 0.25 * 2 = 0.5
      expect(midScale, closeTo(0.5, 0.05));

      // Advance by 5ms (total 35ms: completion)
      manager.update(0.005);
      expect(completed, isTrue);
      expect(manager.activeCount, equals(0));
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
      expect(manager.getTimeScale(TimeDilationChannel.target), equals(1.0));
      expect(manager.isChannelFrozen(TimeDilationChannel.attacker), isFalse);
    });

    test('Medium attack preset executes exact 35ms freeze + 15ms ease-out (~50ms total)', () {
      bool completed = false;
      manager.triggerMedium(onComplete: () => completed = true);

      // At 20ms: fully frozen
      manager.update(0.020);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      // At 35ms: freeze ends, ease-out starts
      manager.update(0.015);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.0, 0.001));

      // At 42.5ms (t=0.5 into ease-out)
      manager.update(0.0075);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.5, 0.05));

      // At 50ms: fully restored
      manager.update(0.0075);
      expect(completed, isTrue);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('Heavy finisher preset executes 45ms freeze + 18ms ease-out (~63ms total)', () {
      bool completed = false;
      manager.triggerHeavy(onComplete: () => completed = true);

      // Freeze phase at 40ms
      manager.update(0.040);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      // 45ms freeze ends
      manager.update(0.005);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.0, 0.001));

      // Ease-out completes at 63ms
      manager.update(0.018);
      expect(completed, isTrue);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('Critical shockwave preset executes 60ms freeze + 20ms ease-out (80ms total)', () {
      bool completed = false;
      manager.triggerCritical(onComplete: () => completed = true);

      // 50ms: fully frozen
      manager.update(0.050);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      // 80ms: fully complete
      manager.update(0.030);
      expect(completed, isTrue);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('Glance deflection preset applies partial 0.2 slow-motion for 15ms', () {
      manager.triggerPreset(HitStopPreset.glance);

      // During 10ms freeze, time scale is 0.2 (not 0.0)
      manager.update(0.005);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.2, 0.001));

      // Total 15ms restores to 1.0
      manager.update(0.010);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });
  });

  group('HitStopManager — Independent Time Dilation Channels', () {
    late HitStopManager manager;

    setUp(() {
      manager = HitStopManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('Combat pair freeze leaves Camera and VFX particle channels fully fluid at 1.0', () {
      manager.triggerLight(
        channels: <TimeDilationChannel>{
          TimeDilationChannel.attacker,
          TimeDilationChannel.target,
        },
      );

      // Attacker and target are frozen
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));
      expect(manager.getTimeScale(TimeDilationChannel.target), equals(0.0));

      // Camera shake and VFX ribbon/particles remain completely fluid at 1.0
      expect(manager.getTimeScale(TimeDilationChannel.camera), equals(1.0));
      expect(manager.getTimeScale(TimeDilationChannel.vfx), equals(1.0));
      expect(manager.getTimeScale(TimeDilationChannel.environment), equals(1.0));
      expect(manager.getTimeScale(TimeDilationChannel.ui), equals(1.0));

      // Effective delta time checks
      const double rawDt = 0.016667; // 60 FPS
      expect(manager.getEffectiveDeltaTime(rawDt, TimeDilationChannel.attacker), equals(0.0));
      expect(manager.getEffectiveDeltaTime(rawDt, TimeDilationChannel.camera), closeTo(rawDt, 0.000001));
      expect(manager.getEffectiveDeltaTime(rawDt, TimeDilationChannel.vfx), closeTo(rawDt, 0.000001));
    });

    test('Global channel freeze pauses all subsystems simultaneously', () {
      manager.trigger(
        const HitStopRequest(
          id: 'global_freeze',
          freezeDuration: Duration(milliseconds: 40),
          easeOutDuration: Duration.zero,
          channels: <TimeDilationChannel>{TimeDilationChannel.global},
        ),
      );

      expect(manager.getTimeScale(TimeDilationChannel.global), equals(0.0));
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));
      expect(manager.getTimeScale(TimeDilationChannel.target), equals(0.0));
      expect(manager.getTimeScale(TimeDilationChannel.camera), equals(0.0));
      expect(manager.getTimeScale(TimeDilationChannel.vfx), equals(0.0));
      expect(manager.getTimeScale(TimeDilationChannel.environment), equals(0.0));
    });

    test('Base time scale scales multiplicatively with hit-stop time scale', () {
      // Set environmental bullet-time: base speed is 0.5x
      manager.setBaseTimeScale(TimeDilationChannel.attacker, 0.5);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.5));

      // Trigger hit-stop with 0.0 scale
      manager.triggerLight(channels: <TimeDilationChannel>{TimeDilationChannel.attacker});
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      // Advance through hit stop to completion: returns to 0.5 (not 1.0)
      manager.update(0.050);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.5));
    });

    test('Custom auxiliary channels are supported seamlessly', () {
      const TimeDilationChannel bossArm = TimeDilationChannel.custom1;
      manager.trigger(
        const HitStopRequest(
          id: 'boss_arm_hit',
          freezeDuration: Duration(milliseconds: 30),
          easeOutDuration: Duration(milliseconds: 10),
          channels: <TimeDilationChannel>{bossArm},
        ),
      );

      expect(manager.getTimeScale(bossArm), equals(0.0));
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });
  });

  group('HitStopManager — Smooth Resumption Curves', () {
    late HitStopManager manager;

    setUp(() {
      manager = HitStopManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('Instant curve snaps from target time scale directly to 1.0', () {
      manager.trigger(
        const HitStopRequest(
          id: 'instant_test',
          freezeDuration: Duration(milliseconds: 30),
          easeOutDuration: Duration(milliseconds: 20),
          resumptionCurve: HitStopResumptionCurve.instant,
          channels: <TimeDilationChannel>{TimeDilationChannel.attacker},
        ),
      );

      manager.update(0.030); // Freeze ends
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      manager.update(0.010); // Midway through ease-out: still 0.0 because it is instant-at-end
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      manager.update(0.010); // At 50ms: reaches 1.0
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('Linear curve ramps smoothly from 0.0 to 1.0', () {
      manager.trigger(
        const HitStopRequest(
          id: 'linear_test',
          freezeDuration: Duration(milliseconds: 20),
          easeOutDuration: Duration(milliseconds: 20),
          resumptionCurve: HitStopResumptionCurve.linear,
          channels: <TimeDilationChannel>{TimeDilationChannel.attacker},
        ),
      );

      manager.update(0.020); // End of freeze
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.0, 0.001));

      manager.update(0.005); // 25% into ramp
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.25, 0.01));

      manager.update(0.005); // 50% into ramp
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.50, 0.01));

      manager.update(0.005); // 75% into ramp
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.75, 0.01));

      manager.update(0.005); // 100% completed
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(1.0, 0.01));
    });

    test('EaseOutQuad accelerates recovery fast initially and cushions near 1.0', () {
      manager.trigger(
        const HitStopRequest(
          id: 'ease_out_test',
          freezeDuration: Duration(milliseconds: 20),
          easeOutDuration: Duration(milliseconds: 20),
          resumptionCurve: HitStopResumptionCurve.easeOutQuad,
          channels: <TimeDilationChannel>{TimeDilationChannel.attacker},
        ),
      );

      manager.update(0.020); // Freeze ends
      // Halfway: t = 0.5 -> 0.5 * (2 - 0.5) = 0.75
      manager.update(0.010);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.75, 0.02));
    });

    test('SmoothStep curve produces continuous S-curve acceleration', () {
      manager.trigger(
        const HitStopRequest(
          id: 'smoothstep_test',
          freezeDuration: Duration(milliseconds: 20),
          easeOutDuration: Duration(milliseconds: 20),
          resumptionCurve: HitStopResumptionCurve.smoothStep,
          channels: <TimeDilationChannel>{TimeDilationChannel.attacker},
        ),
      );

      manager.update(0.020); // Freeze ends
      // t = 0.25 -> 0.25^2 * (3 - 0.5) = 0.0625 * 2.5 = 0.15625
      manager.update(0.005);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.156, 0.02));

      // t = 0.50 -> 0.5
      manager.update(0.005);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.50, 0.02));

      // t = 0.75 -> 0.75^2 * (3 - 1.5) = 0.5625 * 1.5 = 0.84375
      manager.update(0.005);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.844, 0.02));
    });

    test('Custom lambda curve is properly evaluated and clamped', () {
      manager.trigger(
        HitStopRequest(
          id: 'custom_curve_test',
          freezeDuration: const Duration(milliseconds: 10),
          easeOutDuration: const Duration(milliseconds: 10),
          customCurve: (double t) => t * t * t, // Cubic ease-in
          channels: const <TimeDilationChannel>{TimeDilationChannel.attacker},
        ),
      );

      manager.update(0.010); // End of freeze
      // t = 0.5 -> 0.125
      manager.update(0.005);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), closeTo(0.125, 0.02));
    });
  });

  group('HitStopManager — Queueing & Concurrency Conflict Policies', () {
    late HitStopManager manager;

    setUp(() {
      manager = HitStopManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('Queue policy sequences rapid combo hits back-to-back without overlap', () {
      int firstCompleted = 0;
      int secondCompleted = 0;

      // First hit: 30ms total
      manager.trigger(
        HitStopRequest(
          id: 'hit_1',
          freezeDuration: const Duration(milliseconds: 20),
          easeOutDuration: const Duration(milliseconds: 10),
          conflictPolicy: HitStopConflictPolicy.queue,
          onComplete: () => firstCompleted++,
        ),
      );

      // Second rapid hit 5ms later: queued!
      manager.update(0.005);
      manager.trigger(
        HitStopRequest(
          id: 'hit_2',
          freezeDuration: const Duration(milliseconds: 20),
          easeOutDuration: const Duration(milliseconds: 10),
          conflictPolicy: HitStopConflictPolicy.queue,
          onComplete: () => secondCompleted++,
        ),
      );

      expect(manager.activeCount, equals(1));
      expect(manager.queuedCount, equals(1));
      expect(firstCompleted, equals(0));
      expect(secondCompleted, equals(0));

      // Advance by 25ms (first hit finishes at 30ms total)
      manager.update(0.025);
      expect(firstCompleted, equals(1));
      // Second hit immediately promoted to active!
      expect(manager.activeCount, equals(1));
      expect(manager.queuedCount, equals(0));
      expect(secondCompleted, equals(0));
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      // Advance by 30ms: second hit finishes
      manager.update(0.030);
      expect(secondCompleted, equals(1));
      expect(manager.activeCount, equals(0));
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('Extend policy extends remaining freeze when a subsequent strike lands', () {
      // First hit: 30ms freeze
      manager.trigger(
        const HitStopRequest(
          id: 'extend_1',
          freezeDuration: Duration(milliseconds: 30),
          easeOutDuration: Duration(milliseconds: 10),
          conflictPolicy: HitStopConflictPolicy.extend,
        ),
      );

      // Advance 20ms: 10ms remaining freeze
      manager.update(0.020);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      // Second strike hits: requests 30ms freeze extension
      manager.trigger(
        const HitStopRequest(
          id: 'extend_2',
          freezeDuration: Duration(milliseconds: 30),
          easeOutDuration: Duration(milliseconds: 10),
          conflictPolicy: HitStopConflictPolicy.extend,
        ),
      );

      // Another 20ms later (total 40ms from start): still frozen because it was extended!
      manager.update(0.020);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      // Another 15ms later: ease-out completes
      manager.update(0.020);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('Override policy immediately replaces current hit stop with the new one', () {
      bool hit1Completed = false;
      bool hit2Completed = false;

      manager.trigger(
        HitStopRequest(
          id: 'override_1',
          freezeDuration: const Duration(milliseconds: 60),
          easeOutDuration: const Duration(milliseconds: 20),
          conflictPolicy: HitStopConflictPolicy.override,
          onComplete: () => hit1Completed = true,
        ),
      );

      manager.update(0.020);
      expect(hit1Completed, isFalse);

      // Trigger override
      manager.trigger(
        HitStopRequest(
          id: 'override_2',
          freezeDuration: const Duration(milliseconds: 20),
          easeOutDuration: const Duration(milliseconds: 10),
          conflictPolicy: HitStopConflictPolicy.override,
          onComplete: () => hit2Completed = true,
        ),
      );

      expect(hit1Completed, isTrue); // Interrupted and completed
      expect(manager.activeCount, equals(1));
      expect(manager.activeHitStops.first.id, equals('override_2'));

      manager.update(0.030);
      expect(hit2Completed, isTrue);
      expect(manager.activeCount, equals(0));
    });

    test('IgnoreIfActive policy discards new requests while channel is frozen', () {
      manager.trigger(
        const HitStopRequest(
          id: 'ignore_1',
          freezeDuration: Duration(milliseconds: 40),
          easeOutDuration: Duration(milliseconds: 10),
          conflictPolicy: HitStopConflictPolicy.ignoreIfActive,
        ),
      );

      manager.update(0.010);
      expect(manager.activeCount, equals(1));

      // Spam hit
      manager.trigger(
        const HitStopRequest(
          id: 'ignore_2',
          freezeDuration: Duration(milliseconds: 40),
          easeOutDuration: Duration(milliseconds: 10),
          conflictPolicy: HitStopConflictPolicy.ignoreIfActive,
        ),
      );

      expect(manager.activeCount, equals(1));
      expect(manager.queuedCount, equals(0));
      expect(manager.activeHitStops.first.id, equals('ignore_1'));
    });

    test('High priority strike preempts active lower priority hit-stops', () {
      bool lightFinished = false;

      // Light hit (priority 1)
      manager.trigger(
        HitStopRequest(
          id: 'light_priority',
          freezeDuration: const Duration(milliseconds: 50),
          easeOutDuration: const Duration(milliseconds: 20),
          priority: 1,
          conflictPolicy: HitStopConflictPolicy.extend,
          onComplete: () => lightFinished = true,
        ),
      );

      manager.update(0.010);

      // Heavy finisher strike (priority 5) lands -> preempts regardless of conflictPolicy!
      manager.trigger(
        const HitStopRequest(
          id: 'heavy_finisher_priority',
          freezeDuration: Duration(milliseconds: 30),
          easeOutDuration: Duration(milliseconds: 15),
          priority: 5,
        ),
      );

      expect(lightFinished, isTrue);
      expect(manager.activeCount, equals(1));
      expect(manager.activeHitStops.first.id, equals('heavy_finisher_priority'));
    });
  });

  group('HitStopManager — Edge Cases, Cancellation, and Delta Time', () {
    late HitStopManager manager;

    setUp(() {
      manager = HitStopManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('Zero dt update does not mutate state or cause division by zero', () {
      manager.triggerLight();
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      manager.update(0.0);
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));
      expect(manager.activeCount, equals(1));
    });

    test('Massive dt spike (e.g. 500ms lag spike) cleanly finishes without residual freeze', () {
      bool completed = false;
      manager.triggerMedium(onComplete: () => completed = true);

      manager.update(0.500); // 500ms
      expect(completed, isTrue);
      expect(manager.activeCount, equals(0));
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('cancelAll immediately flushes active and queued requests and restores 1.0', () {
      bool c1 = false;
      bool c2 = false;

      manager.trigger(
        HitStopRequest(
          id: 'c1',
          freezeDuration: const Duration(milliseconds: 50),
          onComplete: () => c1 = true,
        ),
      );
      manager.trigger(
        HitStopRequest(
          id: 'c2',
          freezeDuration: const Duration(milliseconds: 50),
          conflictPolicy: HitStopConflictPolicy.queue,
          onComplete: () => c2 = true,
        ),
      );

      expect(manager.activeCount, equals(1));
      expect(manager.queuedCount, equals(1));

      manager.cancelAll();
      expect(manager.activeCount, equals(0));
      expect(manager.queuedCount, equals(0));
      expect(c1, isTrue);
      expect(c2, isFalse); // Queued request was flushed before starting
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('cancelChannel selectively cancels only affected channel', () {
      const TimeDilationChannel chA = TimeDilationChannel.custom1;
      const TimeDilationChannel chB = TimeDilationChannel.custom2;

      manager.trigger(
        const HitStopRequest(
          id: 'hit_a',
          freezeDuration: Duration(milliseconds: 50),
          channels: <TimeDilationChannel>{chA},
        ),
      );
      manager.trigger(
        const HitStopRequest(
          id: 'hit_b',
          freezeDuration: Duration(milliseconds: 50),
          channels: <TimeDilationChannel>{chB},
        ),
      );

      expect(manager.getTimeScale(chA), equals(0.0));
      expect(manager.getTimeScale(chB), equals(0.0));

      manager.cancelChannel(chA);
      expect(manager.getTimeScale(chA), equals(1.0));
      expect(manager.getTimeScale(chB), equals(0.0));
    });

    test('cancelById successfully cancels target hit stop', () {
      manager.trigger(
        const HitStopRequest(
          id: 'unique_tag_123',
          freezeDuration: Duration(milliseconds: 50),
        ),
      );

      expect(manager.activeCount, equals(1));
      final bool removed = manager.cancelById('unique_tag_123');
      expect(removed, isTrue);
      expect(manager.activeCount, equals(0));
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });

    test('ChangeNotifier notifies listeners when hit stop starts and time scales update', () {
      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      manager.triggerLight();
      expect(notifyCount, greaterThan(0));

      final int beforeUpdate = notifyCount;
      manager.update(0.010);
      expect(notifyCount, greaterThan(beforeUpdate));
    });

    test('tick(Duration) handles Duration directly with sub-millisecond precision', () {
      manager.triggerLight();
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(0.0));

      manager.tick(const Duration(milliseconds: 35));
      expect(manager.getTimeScale(TimeDilationChannel.attacker), equals(1.0));
    });
  });
}
