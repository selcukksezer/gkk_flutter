import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../smoke/helpers.dart';
import '../smoke/smoke_harness.dart';

/// Thin UI spot-check after headless swarm — chrome + core routes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI UI spot-check', () {
    testWidgets('login + home dungeon inventory guild market', (
      WidgetTester tester,
    ) async {
      if (!SmokeEnv.hasResolvedCredentials && !SmokeEnv.hasCredentials) {
        expect(true, true, reason: 'Skipped — no QA credentials');
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);

      final GoRouter router = SmokeHarness.routerFromTester(tester);

      for (final String route in <String>[
        AppRoutes.home,
        AppRoutes.dungeon,
        AppRoutes.inventory,
        AppRoutes.character,
        AppRoutes.guild,
        AppRoutes.market,
        AppRoutes.chat,
      ]) {
        await SmokeHarness.navigateRoute(tester, router, route);
        SmokeHarness.assertNoFlutterError(tester, route);
        expect(find.byType(Scaffold), findsWidgets);
      }

      // ignore: avoid_print
      print('AI_UI_SPOTCHECK:PASS');
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}
