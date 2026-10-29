import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/components/daily_reward/daily_reward_vfx_models.dart';
import 'package:gkk_flutter/components/daily_reward/chest_unlock_vfx.dart';
import 'package:gkk_flutter/components/daily_reward/reward_item_modal.dart';
import 'package:gkk_flutter/components/daily_reward/daily_calendar_grid.dart';
import 'package:gkk_flutter/models/daily_reward_model.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DailyRewardRarity Tests', () {
    test('Calculates rarity correctly from grants', () {
      const grantLegendary = DailyRewardGrant(
        cycleDay: 28,
        displayLabel: 'Büyük Taç',
        isMilestone: true,
        gold: 50000,
        gems: 100,
        xp: 5000,
        energy: 50,
        itemQuantity: 1,
      );
      expect(DailyRewardRarity.fromGrant(grantLegendary), DailyRewardRarity.legendary);

      const grantEpic = DailyRewardGrant(
        cycleDay: 14,
        displayLabel: 'Haftalık Sandık',
        isMilestone: true,
        gold: 20000,
        gems: 25,
        xp: 2000,
        energy: 20,
        itemQuantity: 0,
      );
      expect(DailyRewardRarity.fromGrant(grantEpic), DailyRewardRarity.epic);

      const grantRare = DailyRewardGrant(
        cycleDay: 3,
        displayLabel: 'Nadir Eşya',
        isMilestone: false,
        gold: 12000,
        gems: 5,
        xp: 600,
        energy: 0,
        itemId: 'steel_sword',
        itemName: 'Çelik Kılıç',
        itemQuantity: 1,
      );
      expect(DailyRewardRarity.fromGrant(grantRare), DailyRewardRarity.rare);

      const grantUncommon = DailyRewardGrant(
        cycleDay: 2,
        displayLabel: 'Altın Kesesi',
        isMilestone: false,
        gold: 6000,
        gems: 0,
        xp: 400,
        energy: 0,
        itemQuantity: 0,
      );
      expect(DailyRewardRarity.fromGrant(grantUncommon), DailyRewardRarity.uncommon);

      const grantCommon = DailyRewardGrant(
        cycleDay: 1,
        displayLabel: 'Başlangıç Payı',
        isMilestone: false,
        gold: 1500,
        gems: 0,
        xp: 200,
        energy: 0,
        itemQuantity: 0,
      );
      expect(DailyRewardRarity.fromGrant(grantCommon), DailyRewardRarity.common);
    });

    test('Rarity properties return valid colors and shadows', () {
      for (final rarity in DailyRewardRarity.values) {
        expect(rarity.label.isNotEmpty, isTrue);
        expect(rarity.primaryColor.value, isNonZero);
        expect(rarity.auraShadow.isNotEmpty, isTrue);
      }
    });
  });

  group('DailyParticle Physics Tests', () {
    test('Particle spawns and updates correctly', () {
      final random = math.Random(42);
      final particle = DailyParticle.spawnBurst(
        originX: 100,
        originY: 100,
        random: random,
      );

      expect(particle.x, 100);
      expect(particle.y, 100);
      expect(particle.isDead, isFalse);
      expect(particle.alpha, inInclusiveRange(0.0, 1.0));

      final initialVx = particle.vx;
      final initialVy = particle.vy;

      particle.update(0.05);

      expect(particle.life, closeTo(0.05, 0.001));
      expect(particle.x, isNot(100));
      expect(particle.vx.abs(), lessThanOrEqualTo(initialVx.abs()));
    });
  });

  group('Chest CustomPainter Tests', () {
    test('ChestLightRaysPainter paints without error', () {
      const painter = ChestLightRaysPainter(
        progress: 0.8,
        rotation: 0.5,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 200));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('ChestParticlePainter paints particles without error', () {
      final particles = [
        DailyParticle.spawnBurst(originX: 50, originY: 50, random: math.Random(1)),
      ];
      final painter = ChestParticlePainter(particles: particles);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 200));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('ChestIllustrationPainter paints closed and open lid without error', () {
      const closedPainter = ChestIllustrationPainter(
        lidOpenFactor: 0.0,
        glowIntensity: 0.5,
      );
      const openPainter = ChestIllustrationPainter(
        lidOpenFactor: 1.0,
        glowIntensity: 1.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      closedPainter.paint(canvas, const Size(150, 150));
      openPainter.paint(canvas, const Size(150, 150));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('ChestUnlockVfxWidget Widget Tests', () {
    testWidgets('Renders idle chest and triggers unlock callback on tap', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChestUnlockVfxWidget(
              phase: ChestUnlockPhase.idle,
              canClaim: true,
              onTapUnlock: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(ChestUnlockVfxWidget), findsOneWidget);
      expect(find.text('Açmak için dokun!'), findsOneWidget);

      await tester.tap(find.byType(ChestUnlockVfxWidget));
      expect(tapped, isTrue);
    });

    testWidgets('Transitions into anticipating and bursting phases', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChestUnlockVfxWidget(
              phase: ChestUnlockPhase.anticipating,
              canClaim: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ChestUnlockVfxWidget), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChestUnlockVfxWidget(
              phase: ChestUnlockPhase.bursting,
              canClaim: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ChestUnlockVfxWidget), findsOneWidget);
    });
  });

  group('RewardItemModal Widget Tests', () {
    testWidgets('Renders reward item details and invokes onCollect', (WidgetTester tester) async {
      bool collected = false;
      const testGrant = DailyRewardGrant(
        cycleDay: 7,
        displayLabel: 'Haftalık Zafer',
        isMilestone: true,
        gold: 10500,
        gems: 30,
        xp: 1400,
        energy: 15,
        itemId: 'ruby_ring',
        itemName: 'Yakut Yüzük',
        itemQuantity: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardItemModal(
              grant: testGrant,
              onCollect: () => collected = true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Yakut Yüzük'), findsOneWidget);
      expect(find.text('DESTANSI ÖDÜL'), findsOneWidget);
      expect(find.text('+10.5K Altın'), findsOneWidget);
      expect(find.text('+30 Elmas'), findsOneWidget);
      expect(find.text('+1.4K XP'), findsOneWidget);
      expect(find.text('+15 Enerji'), findsOneWidget);
      expect(find.text('Ödülü Topla'), findsOneWidget);

      await tester.tap(find.text('Ödülü Topla'));
      expect(collected, isTrue);
    });
  });

  group('DailyCalendarGrid Widget Tests', () {
    testWidgets('Renders 7-day and 28-day views correctly', (WidgetTester tester) async {
      const todayReward = DailyRewardGrant(
        cycleDay: 5,
        displayLabel: 'Gün 5 Sandığı',
        isMilestone: false,
        gold: 7500,
        gems: 5,
        xp: 1000,
        energy: 10,
        itemQuantity: 0,
      );

      final status = DailyRewardStatus(
        canClaim: true,
        cycleDay: 5,
        cycleLength: 28,
        streakLength: 4,
        claimedToday: false,
        todayReward: todayReward,
        weekCalendar: const [],
        nextResetAt: DateTime.now().toUtc().add(const Duration(hours: 4)),
      );

      DailyRewardCalendarDay? selectedDay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyCalendarGrid(
                status: status,
                onDaySelected: (day) => selectedDay = day,
              ),
            ),
          ),
        ),
      );

      expect(find.text('7 Günlük'), findsOneWidget);
      expect(find.text('28 Günlük'), findsOneWidget);

      // In 7-day mode, shows 7 items
      expect(find.text('5'), findsOneWidget);

      // Switch to 28-day mode
      await tester.tap(find.text('28 Günlük'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('28'), findsOneWidget);

      // Tap day 28 cell
      await tester.tap(find.text('28'));
      expect(selectedDay?.cycleDay, 28);
    });
  });
}
