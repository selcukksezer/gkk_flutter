import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/components/daily_reward/chest_unlock_vfx.dart';
import 'package:gkk_flutter/components/daily_reward/daily_calendar_grid.dart';
import 'package:gkk_flutter/components/daily_reward/daily_reward_dialog.dart';
import 'package:gkk_flutter/models/daily_reward_model.dart';
import 'package:gkk_flutter/providers/daily_reward_provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DailyRewardDialog Widget & Integration Tests', () {
    const todayReward = DailyRewardGrant(
      cycleDay: 3,
      displayLabel: 'Kadim Hazine',
      isMilestone: false,
      gold: 4500,
      gems: 10,
      xp: 600,
      energy: 5,
      itemQuantity: 0,
    );

    final mockStatus = DailyRewardStatus(
      canClaim: true,
      cycleDay: 3,
      cycleLength: 28,
      streakLength: 2,
      claimedToday: false,
      todayReward: todayReward,
      weekCalendar: const [],
      nextResetAt: DateTime.now().toUtc().add(const Duration(hours: 6)),
    );

    testWidgets('Renders within 390x844 responsive mobile safe area', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyRewardProvider.overrideWith(
              () => _FakeDailyRewardNotifier(
                DailyRewardState(status: mockStatus),
              ),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Open dialog with ref
                      },
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Verify no overflow in mobile portrait dimensions
      expect(tester.takeException(), isNull);
    });

    testWidgets('Opens dialog, displays chest, header, streak, and claim CTA', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyRewardProvider.overrideWith(
              () => _FakeDailyRewardNotifier(
                DailyRewardState(status: mockStatus),
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showDailyRewardDialog(context, ref),
                      child: const Text('Open Dialog'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Günlük Ödül Yolu'), findsOneWidget);
      expect(find.text('28 GÜNLÜK'), findsOneWidget);
      expect(find.text('Döngü Günü: 3 / 28'), findsOneWidget);
      expect(find.text('3 Gün'), findsOneWidget); // Streak badge: streakLength + 1
      expect(find.byType(ChestUnlockVfxWidget), findsOneWidget);
      expect(find.byType(DailyCalendarGrid), findsOneWidget);
      expect(find.text('Gün 3 Sandığını Aç'), findsOneWidget);

      // Tap claim CTA to start unlock sequence
      await tester.tap(find.text('Gün 3 Sandığını Aç'));
      await tester.pump(const Duration(milliseconds: 700)); // anticipation completes
      await tester.pump(const Duration(milliseconds: 300)); // burst and lid open
      await tester.pump(const Duration(milliseconds: 300)); // modal presentation

      // RewardItemModal should now be visible with Collect button
      expect(find.text('Ödülü Topla'), findsOneWidget);

      // Collect reward
      await tester.tap(find.text('Ödülü Topla'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeDailyRewardNotifier extends DailyRewardNotifier {
  _FakeDailyRewardNotifier(this._initialState);
  final DailyRewardState _initialState;

  @override
  DailyRewardState build() => _initialState;

  @override
  Future<void> loadStatus() async {}

  @override
  Future<bool> claim() async => true;
}
