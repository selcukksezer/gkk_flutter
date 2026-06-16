import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_drawer_labels.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';
import 'smoke_harness.dart';

@Skip('Flaky quick menu on simulator — use smoke_gate_test (router nav)')
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Quick menu navigation smoke', () {
    testWidgets('all quick menu items reachable', (WidgetTester tester) async {
      if (!SmokeEnv.hasCredentials) {
        expect(SmokeMenuLabels.all.length, 25);
        expect(SmokeRouteRegistry.quickMenuRouteCount, 24);
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);

      final SmokeRunReport report = SmokeRunReport(
        runId: DateTime.now().toUtc().toIso8601String(),
        testName: 'quick_menu_navigation',
      );

      for (final SmokeRouteEntry entry in SmokeRouteRegistry.quickMenuRoutes) {
        try {
          await SmokeHarness.tapQuickMenuItem(tester, entry.label);
          SmokeHarness.assertNoFlutterError(tester, entry.path);

          final bool hasScaffold =
              find.byType(Scaffold).evaluate().isNotEmpty;
          report.addScreen(
            SmokeScreenAudit(
              route: entry.path,
              interactiveCount: SmokeHarness.countInteractiveWidgets(tester),
              hasScaffold: hasScaffold,
            ),
          );
        } catch (e) {
          report.addFailure('${entry.label} (${entry.path}): $e');
          report.addScreen(
            SmokeScreenAudit(
              route: entry.path,
              interactiveCount: 0,
              hasScaffold: false,
              error: e.toString(),
            ),
          );
        }
      }

      // ignore: avoid_print
      print('SMOKE_REPORT_JSON:${jsonEncode(report.toJson())}');

      expect(report.failures, isEmpty, reason: report.failures.join('\n'));
    });
  });
}
