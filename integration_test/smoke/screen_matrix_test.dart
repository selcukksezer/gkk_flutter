import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';
import 'package:gkk_flutter/qa/smoke_route_resolver.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';
import 'smoke_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screen matrix smoke', () {
    testWidgets('navigates unique routes without crash when authenticated', (
      WidgetTester tester,
    ) async {
      if (!SmokeEnv.hasCredentials) {
        expect(SmokeRouteRegistry.uniquePaths.length, greaterThanOrEqualTo(35));
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);

      final GoRouter router = SmokeHarness.routerFromTester(tester);

      final List<String> paths = await SmokeRouteResolver.integrationPaths();
      final List<String> failures = <String>[];

      for (final String path in paths) {
        if (path == AppRoutes.splash ||
            path == AppRoutes.login ||
            path == AppRoutes.register) {
          continue;
        }

        try {
          await SmokeHarness.navigateRoute(tester, router, path);
          final Object? err = tester.takeException();
          if (err != null) {
            failures.add('$path → $err');
          }
        } catch (e) {
          failures.add('$path → $e');
          tester.takeException();
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });
}
