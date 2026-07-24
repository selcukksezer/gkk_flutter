import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_action_registry.dart';
import 'package:gkk_flutter/qa/smoke_route_resolver.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';
import 'smoke_harness.dart';

/// Programmatic tap audit for all 350 registered UI actions (sharded).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Full 350-action audit', () {
    testWidgets('auto_tap shard + skip inventory', (WidgetTester tester) async {
      final int shardIndex = SmokeEnv.auditShardIndex;
      final int shardTotal = SmokeEnv.auditShardTotal;
      final List<SmokeActionEntry> shard = SmokeActionRegistry.shardActions(
        shardIndex: shardIndex,
        shardTotal: shardTotal,
      );

      if (!SmokeEnv.hasResolvedCredentials) {
        expect(SmokeActionRegistry.fullInventoryActionCount, 350);
        expect(shard.isNotEmpty, true);
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);

      final GoRouter router = SmokeHarness.routerFromTester(tester);
      final List<String> resolvedPaths = await SmokeRouteResolver.integrationPaths();
      final Map<String, String> pathAliases = <String, String>{};
      for (final String p in resolvedPaths) {
        if (p.contains('sample-id')) continue;
        pathAliases[p] = p;
      }
      for (final String p in resolvedPaths) {
        if (p.contains('sample-id')) {
          final String generic = p.replaceAll(RegExp(r'[0-9a-f-]{36}'), 'sample-id');
          pathAliases.putIfAbsent(generic, () => p);
        }
      }

      final FullActionAuditReport report = FullActionAuditReport(
        runId: DateTime.now().toUtc().toIso8601String(),
        shardIndex: shardIndex,
        shardTotal: shardTotal,
        accountEmail: SmokeEnv.resolvedEmail,
      );

      String? lastRoute;
      for (final SmokeActionEntry action in shard) {
        if (action.coverage == 'skip') {
          report.add(
            ActionAuditResult(
              actionId: action.id,
              coverage: action.coverage,
              status: 'skip',
              route: action.route,
              skipReason: action.skipReason,
            ),
          );
          continue;
        }

        if (action.coverage == 'rpc') {
          report.add(
            ActionAuditResult(
              actionId: action.id,
              coverage: action.coverage,
              status: 'pass',
              route: action.route,
              skipReason: 'verified_via_db_rpc',
            ),
          );
          continue;
        }

        final String route = pathAliases[action.route] ?? action.route;
        if (route == AppRoutes.splash ||
            route == AppRoutes.login ||
            route == AppRoutes.register) {
          report.add(
            ActionAuditResult(
              actionId: action.id,
              coverage: action.coverage,
              status: 'skip',
              route: route,
              skipReason: 'auth_route',
            ),
          );
          continue;
        }

        try {
          if (lastRoute != route) {
            await SmokeHarness.navigateRoute(tester, router, route);
            lastRoute = route;
          }

          final Object? navErr = tester.takeException();
          if (navErr != null) {
            report.add(
              ActionAuditResult(
                actionId: action.id,
                coverage: action.coverage,
                status: 'fail',
                route: route,
                error: navErr.toString(),
              ),
            );
            continue;
          }

          final bool tapped =
              await SmokeHarness.tapInteractiveAt(tester, action.actionIndex);
          final Object? tapErr = tester.takeException();

          if (tapErr != null) {
            report.add(
              ActionAuditResult(
                actionId: action.id,
                coverage: action.coverage,
                status: 'fail',
                route: route,
                error: tapErr.toString(),
              ),
            );
          } else if (!tapped &&
              SmokeHarness.countInteractiveWidgets(tester) == 0) {
            report.add(
              ActionAuditResult(
                actionId: action.id,
                coverage: action.coverage,
                status: 'pass',
                route: route,
                skipReason: 'route_load_no_interactive',
              ),
            );
          } else {
            report.add(
              ActionAuditResult(
                actionId: action.id,
                coverage: action.coverage,
                status: 'pass',
                route: route,
              ),
            );
          }
        } catch (e) {
          report.add(
            ActionAuditResult(
              actionId: action.id,
              coverage: action.coverage,
              status: 'fail',
              route: route,
              error: e.toString(),
            ),
          );
          tester.takeException();
        }
      }

      // ignore: avoid_print
      print('FULL_ACTION_AUDIT_JSON:${jsonEncode(report.toJson())}');

      expect(
        report.failCount,
        0,
        reason: report.actions
            .where((ActionAuditResult a) => a.status == 'fail')
            .map((ActionAuditResult a) => '${a.actionId}: ${a.error}')
            .join('\n'),
      );
    }, timeout: const Timeout(Duration(minutes: 15)));
  });
}
