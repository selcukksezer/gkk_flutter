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

/// Single integration gate — one Xcode build, ~2 min, real Supabase session.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke gate (real QA session)', () {
    testWidgets('all routes + interactive inventory', (WidgetTester tester) async {
      if (!SmokeEnv.hasCredentials) {
        expect(SmokeRouteRegistry.uniquePaths.length, greaterThanOrEqualTo(35));
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);

      final GoRouter router = SmokeHarness.routerFromTester(tester);
      final List<String> paths = await SmokeRouteResolver.integrationPaths();

      final SmokeRunReport report = SmokeRunReport(
        runId: DateTime.now().toUtc().toIso8601String(),
        testName: 'smoke_gate',
      );

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
          tester.takeException();
        }
      }

      // P0 extras: market tabs
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.market);
      for (final String tab in <String>['Gozat', 'Sat', 'Pazarim']) {
        final Finder tabFinder = find.text(tab);
        if (tabFinder.evaluate().isNotEmpty) {
          await tester.tap(tabFinder.first, warnIfMissed: false);
          await smokePump(tester, duration: const Duration(milliseconds: 500));
        }
      }

      final int totalInteractive = report.screens.fold<int>(
        0,
        (int sum, SmokeScreenAudit s) => sum + s.interactiveCount,
      );

      // ignore: avoid_print
      print('SMOKE_GATE_JSON:${jsonEncode(report.toJson())}');
      // ignore: avoid_print
      print('SMOKE_INTERACTIVE_TOTAL:$totalInteractive');
      // ignore: avoid_print
      print('SMOKE_GATE_PASS:${report.passCount}/${report.screens.length}');

      expect(
        report.failures,
        isEmpty,
        reason: report.failures.join('\n'),
      );
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
