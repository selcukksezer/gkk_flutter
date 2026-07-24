import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_action_registry.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';
import 'package:gkk_flutter/qa/smoke_route_resolver.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';
import 'smoke_harness.dart';

/// Route inventory scaffold — full tap audit lives in full_action_audit_test.dart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('UI action tap audit scaffold', () {
    testWidgets('350 registry + route matrix inventory', (
      WidgetTester tester,
    ) async {
      expect(SmokeActionRegistry.fullInventoryActionCount, 350);
      expect(SmokeRouteRegistry.uniquePaths.length, greaterThanOrEqualTo(35));

      if (!SmokeEnv.hasResolvedCredentials) {
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
      // ignore: avoid_print
      print('SMOKE_ACTION_REGISTRY_TOTAL:${SmokeActionRegistry.allActions.length}');

      expect(report.failures, isEmpty, reason: report.failures.join('\n'));
    });
  });
}
