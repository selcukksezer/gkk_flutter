import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../smoke/helpers.dart';
import '../smoke/smoke_harness.dart';

/// Programmatic F2P journey — login → home → character (rep) → dungeon → reputation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auto player smoke journey', () {
    testWidgets('login home character dungeon reputation flow', (
      WidgetTester tester,
    ) async {
      if (!SmokeEnv.hasCredentials) {
        expect(true, true, reason: 'Skipped — no QA_TEST_EMAIL/PASSWORD');
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);

      final GoRouter router = SmokeHarness.routerFromTester(tester);

      // Home
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.home);
      SmokeHarness.assertNoFlutterError(tester, 'home');
      expect(find.byType(Scaffold), findsWidgets);

      // Character — reputation tier chip (military_tech icon)
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.character);
      await waitForFinder(
        tester,
        find.byIcon(Icons.military_tech_rounded),
        timeout: const Duration(seconds: 15),
      );
      SmokeHarness.assertNoFlutterError(tester, 'character reputation chip');

      // Dungeon list
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.dungeon);
      await smokePump(tester, duration: const Duration(seconds: 2));
      SmokeHarness.assertNoFlutterError(tester, 'dungeon list');
      expect(find.byType(Scaffold), findsWidgets);

      // Reputation screen
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.reputation);
      await waitForFinder(
        tester,
        find.text('İtibar'),
        timeout: const Duration(seconds: 15),
      );
      SmokeHarness.assertNoFlutterError(tester, 'reputation screen');

      // Back to home via bottom nav
      final Finder homeTab = find.text('Home');
      if (homeTab.evaluate().isNotEmpty) {
        await tester.tap(homeTab.first, warnIfMissed: false);
        await smokePump(tester, duration: const Duration(seconds: 2));
      } else {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.home);
      }
      SmokeHarness.assertNoFlutterError(tester, 'home return');

      // ignore: avoid_print
      print('AUTO_PLAYER_SMOKE:PASS');
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
