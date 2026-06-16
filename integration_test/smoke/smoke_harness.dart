import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/services/supabase_service.dart';
import 'package:gkk_flutter/main.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

class SmokeHarness {
  SmokeHarness._();

  static Future<void> ensureInitialized() async {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    await SupabaseService.initialize();
  }

  /// Login via API before UI pump — faster and avoids redirect loops.
  static Future<void> loginBeforePump() async {
    if (!SmokeEnv.hasCredentials) return;
    if (SupabaseService.client.auth.currentSession != null) return;

    await SupabaseService.client.auth.signInWithPassword(
      email: SmokeEnv.email!,
      password: SmokeEnv.password!,
    );
  }

  static GoRouter routerFromTester(WidgetTester tester) {
    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final Object? config = app.routerConfig;
    if (config is GoRouter) {
      return config;
    }
    fail('GoRouter not found on MaterialApp.routerConfig');
  }

  static Future<void> pumpApp(WidgetTester tester) async {
    await loginBeforePump();
    await tester.pumpWidget(const ProviderScope(child: GkkMobileApp()));
    await smokePump(tester, duration: const Duration(seconds: 2));
  }

  static Future<void> loginViaUi(WidgetTester tester) async {
    SmokeEnv.requireCredentials();

    final GoRouter router = SmokeHarness.routerFromTester(tester);
    router.go(AppRoutes.login);
    await smokePump(tester);

    final Finder fields = find.byType(TextFormField);
    expect(fields, findsAtLeast(2));
    await tester.enterText(fields.at(0), SmokeEnv.email!);
    await tester.enterText(fields.at(1), SmokeEnv.password!);
    await tester.tap(find.text('Giris Yap'));
    await smokePump(tester, duration: const Duration(seconds: 4));

    final Object? err = tester.takeException();
    if (err != null) {
      fail('Login failed: $err');
    }
  }

  static Future<void> loginOrSkip(WidgetTester tester) async {
    if (!SmokeEnv.hasCredentials) return;
    await loginBeforePump();
    await smokePump(tester);
  }

  static Future<void> openQuickMenu(WidgetTester tester) async {
    final Finder menuTab = find.text('Menü');
    if (menuTab.evaluate().isEmpty) {
      throw TestFailure('Menü tab not found');
    }
    await tester.tap(menuTab);
    await smokePump(tester, duration: const Duration(milliseconds: 400));
  }

  /// Opens bottom-bar quick menu (replaces legacy drawer).
  static Future<void> openDrawer(WidgetTester tester) => openQuickMenu(tester);

  static Future<void> tapQuickMenuItem(WidgetTester tester, String label) async {
    await openQuickMenu(tester);

    Finder labelFinder = find.text(label);
    if (labelFinder.evaluate().isEmpty) {
      throw TestFailure('Quick menu item not found: $label');
    }

    final Finder scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        labelFinder.first,
        80,
        scrollable: scrollable.first,
      );
      labelFinder = find.text(label);
    }

    await smokePump(tester, duration: const Duration(milliseconds: 300));
    await tester.tap(labelFinder.first, warnIfMissed: false);
    await smokePump(tester, duration: const Duration(seconds: 2));
  }

  static Future<void> tapDrawerItem(WidgetTester tester, String label) =>
      tapQuickMenuItem(tester, label);

  static Future<void> navigateRoute(
    WidgetTester tester,
    GoRouter router,
    String path,
  ) async {
    router.go(path);
    await smokePump(tester, duration: const Duration(milliseconds: 700));
  }

  static void assertNoFlutterError(WidgetTester tester, String context) {
    final Object? err = tester.takeException();
    expect(err, isNull, reason: 'Flutter error on $context: $err');
  }

  static int countInteractiveWidgets(WidgetTester tester) {
    return find.byType(InkWell).evaluate().length +
        find.byType(GestureDetector).evaluate().length +
        find.byType(ElevatedButton).evaluate().length +
        find.byType(FilledButton).evaluate().length +
        find.byType(TextButton).evaluate().length +
        find.byType(IconButton).evaluate().length;
  }
}
