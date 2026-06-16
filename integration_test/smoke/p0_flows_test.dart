import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_drawer_labels.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';
import 'smoke_harness.dart';

@Skip('Merged into smoke_gate_test — avoids duplicate 24-route nav')
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('P0 smoke flows', () {
    testWidgets('10 critical flows without crash', (WidgetTester tester) async {
      if (!SmokeEnv.hasCredentials) {
        expect(SmokeP0Flows.all.length, 10);
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);

      final GoRouter router = SmokeHarness.routerFromTester(tester);

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.home);
      SmokeHarness.assertNoFlutterError(tester, 'home');

      // 2 — all drawer routes via router (same screens as drawer nav)
      for (final SmokeRouteEntry entry in SmokeRouteRegistry.drawerRoutes) {
        await SmokeHarness.navigateRoute(tester, router, entry.path);
        SmokeHarness.assertNoFlutterError(tester, entry.path);
      }

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.dungeon);
      SmokeHarness.assertNoFlutterError(tester, 'dungeon');

      for (final String path in <String>[
        AppRoutes.pvp,
        '/pvp/history',
        '/pvp/tournament',
      ]) {
        await SmokeHarness.navigateRoute(tester, router, path);
        SmokeHarness.assertNoFlutterError(tester, path);
      }

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.market);
      for (final String tab in <String>['Gozat', 'Sat', 'Pazarim']) {
        final Finder tabFinder = find.text(tab);
        if (tabFinder.evaluate().isNotEmpty) {
          await tester.tap(tabFinder.first);
          await smokePump(tester);
        }
      }
      SmokeHarness.assertNoFlutterError(tester, 'market tabs');

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.hospital);
      SmokeHarness.assertNoFlutterError(tester, 'hospital');

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.prison);
      SmokeHarness.assertNoFlutterError(tester, 'prison');

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.mekans);
      await SmokeHarness.navigateRoute(tester, router, '/mekans/create');
      SmokeHarness.assertNoFlutterError(tester, 'mekans');

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.guild);
      await SmokeHarness.navigateRoute(tester, router, '/guild/monument');
      SmokeHarness.assertNoFlutterError(tester, 'guild');

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.quests);
      SmokeHarness.assertNoFlutterError(tester, 'quests');
    });
  });
}
