import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';
import 'package:gkk_flutter/qa/smoke_route_resolver.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';
import 'smoke_harness.dart';

/// Visits every registered route and counts interactive widgets.
/// Does not tap actions (safe audit scaffold for 350-action gate).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('UI action tap audit scaffold', () {
    testWidgets('route matrix + interactive widget inventory', (
      WidgetTester tester,
    ) async {
      if (!SmokeEnv.hasCredentials) {
        expect(SmokeRouteRegistry.uniquePaths.length, greaterThanOrEqualTo(35));
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);

      final GoRouter router = SmokeHarness.routerFromTester(tester);

      final SmokeRunReport report = SmokeRunReport(
        runId: DateTime.now().toUtc().toIso8601String(),
        testName: 'action_tap_audit',
      );

      final List<String> paths = await SmokeRouteResolver.integrationPaths();

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
            report.addFailure('$path → $err');
            report.addScreen(
              SmokeScreenAudit(
                route: path,
                interactiveCount: 0,
                hasScaffold: false,
                error: err.toString(),
              ),
            );
            continue;
          }

          report.addScreen(
            SmokeScreenAudit(
              route: path,
              interactiveCount: SmokeHarness.countInteractiveWidgets(tester),
              hasScaffold: find.byType(Scaffold).evaluate().isNotEmpty,
            ),
          );
        } catch (e) {
          report.addFailure('$path → $e');
          report.addScreen(
            SmokeScreenAudit(
              route: path,
              interactiveCount: 0,
              hasScaffold: false,
              error: e.toString(),
            ),
          );
        }
      }

      final int totalInteractive = report.screens.fold<int>(
        0,
        (int sum, SmokeScreenAudit s) => sum + s.interactiveCount,
      );

      // ignore: avoid_print
      print('SMOKE_REPORT_JSON:${jsonEncode(report.toJson())}');
      // ignore: avoid_print
      print('SMOKE_INTERACTIVE_TOTAL:$totalInteractive');

      expect(report.failures, isEmpty, reason: report.failures.join('\n'));
    });
  });
}
