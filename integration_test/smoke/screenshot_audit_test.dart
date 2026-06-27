import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/services/supabase_service.dart';
import 'package:gkk_flutter/main.dart';
import 'package:gkk_flutter/qa/smoke_route_registry.dart';
import 'package:gkk_flutter/qa/smoke_route_resolver.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';
import 'screenshot_helper.dart';
import 'smoke_harness.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot audit', () {
    testWidgets('captures every navigable route', (WidgetTester tester) async {
      SmokeEnv.requireCredentials();

      final String outputDir = screenshotOutputDir() ??
          'reports/screenshots/audit_${DateTime.now().toIso8601String().substring(0, 10)}';
      final String runId = DateTime.now().toUtc().toIso8601String();
      final String device = Platform.environment['FLUTTER_DEVICE'] ?? 'unknown';

      final ScreenshotAuditManifest manifest = ScreenshotAuditManifest(
        runId: runId,
        outputDir: outputDir,
        device: device,
      );

      await SmokeHarness.ensureInitialized();

      // --- Unauthenticated auth screens ---
      if (SupabaseService.client.auth.currentSession != null) {
        await SupabaseService.client.auth.signOut();
      }

      await tester.pumpWidget(
        const ProviderScope(child: GkkMobileApp()),
      );
      await smokePump(tester, duration: const Duration(seconds: 2));

      final GoRouter router = SmokeHarness.routerFromTester(tester);

      for (final String authPath in <String>[
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.register,
      ]) {
        await SmokeHarness.navigateRoute(tester, router, authPath);
        await captureRouteScreenshot(
          binding: binding,
          tester: tester,
          routePath: authPath,
          manifest: manifest,
        );
      }

      // --- Authenticated routes ---
      await SmokeHarness.loginBeforePump();
      await tester.pumpWidget(
        const ProviderScope(child: GkkMobileApp()),
      );
      await smokePump(tester, duration: const Duration(seconds: 2));

      final GoRouter authedRouter = SmokeHarness.routerFromTester(tester);
      final List<String> paths = await SmokeRouteResolver.integrationPaths();
      final List<String>? routesOnly = SmokeEnv.auditRoutesOnly;

      for (final String path in paths) {
        if (routesOnly != null && !routesOnly.contains(path)) {
          continue;
        }
        if (path == AppRoutes.splash ||
            path == AppRoutes.login ||
            path == AppRoutes.register) {
          continue;
        }

        try {
          await SmokeHarness.navigateRoute(tester, authedRouter, path);
          final Object? err = tester.takeException();
          if (err != null) {
            manifest.addFailure('$path → $err');
          }
          await captureRouteScreenshot(
            binding: binding,
            tester: tester,
            routePath: path,
            manifest: manifest,
          );
        } catch (e) {
          manifest.addFailure('$path → $e');
          tester.takeException();
          manifest.addEntry(
            ScreenshotEntry(
              route: path,
              slug: screenshotSlug(path),
              error: e.toString(),
              screenFile: screenFileForRoute(path),
            ),
          );
        }
      }

      await manifest.writeToDisk();

      // ignore: avoid_print
      print('SCREENSHOT_MANIFEST_JSON:${jsonEncode(manifest.toJson())}');
      // ignore: avoid_print
      print(
        'SCREENSHOT_AUDIT_SUMMARY:captured=${manifest.capturedCount}/'
        '${SmokeRouteRegistry.uniquePaths.length} dir=$outputDir',
      );

      final int expectedMin =
          routesOnly != null ? 3 + routesOnly.length : 30;
      expect(
        manifest.capturedCount,
        greaterThanOrEqualTo(expectedMin),
        reason: 'Too few screenshots captured — check device/driver support',
      );
    });
  });
}
