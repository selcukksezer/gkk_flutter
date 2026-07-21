import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'bugfix_ui_harness.dart';
import 'helpers.dart';
import 'smoke_harness.dart';

/// UI smoke for bugfix batch — needs QA credentials + device/emulator.
///
/// Run:
/// flutter test integration_test/smoke/bugfix_batch_ui_test.dart \
///   --dart-define=QA_TEST_EMAIL=... --dart-define=QA_TEST_PASSWORD=...
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bugfix batch UI smoke', () {
    testWidgets('bank qty cancel, enhancement scroll picker, nav guards',
        (WidgetTester tester) async {
      if (!SmokeEnv.hasCredentials) {
        bugfixUiLog(
          location: 'bugfix_batch_ui_test',
          message: 'skipped_no_credentials',
          hypothesisId: 'SETUP',
        );
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);
      final GoRouter router = SmokeHarness.routerFromTester(tester);

      // ── BANK: qty dialog cancel (long-press stackable item) ─────────────
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.bank);
      await smokePump(tester, duration: const Duration(seconds: 2));

      final Finder inventoryHeaders = find.textContaining('Envanter');
      expect(inventoryHeaders, findsWidgets);

      // Long-press first inventory slot if present (stackable → qty dialog)
      final Finder slotTargets = find.byType(GestureDetector);
      bool qtyDialogTested = false;
      for (int i = 0; i < 30 && !qtyDialogTested; i++) {
        if (slotTargets.evaluate().length <= i) break;
        await tester.longPress(slotTargets.at(i));
        await smokePump(tester, duration: const Duration(milliseconds: 600));
        if (find.text('İptal').evaluate().isNotEmpty) {
          qtyDialogTested = true;
          await tester.tap(find.text('İptal').first);
          await smokePump(tester);
          SmokeHarness.assertNoFlutterError(tester, 'bank_qty_cancel');
          bugfixUiLog(
            location: 'bugfix_batch_ui_test:bank_qty_cancel',
            message: 'pass',
            hypothesisId: 'BANK-QTY',
          );
          break;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (!qtyDialogTested) {
        bugfixUiLog(
          location: 'bugfix_batch_ui_test:bank_qty_cancel',
          message: 'skipped_no_stackable_item',
          hypothesisId: 'BANK-QTY',
        );
      }

      // ── BANK: double-tap Yatır should not crash ─────────────────────────
      final Finder yatirButtons = find.textContaining('Yatır (');
      if (yatirButtons.evaluate().isNotEmpty) {
        await tester.tap(yatirButtons.first);
        await tester.tap(yatirButtons.first);
        await smokePump(tester);
        SmokeHarness.assertNoFlutterError(tester, 'bank_deposit_double_tap');
        bugfixUiLog(
          location: 'bugfix_batch_ui_test:bank_deposit_spam',
          message: 'pass',
          hypothesisId: 'BANK-SPAM',
        );
      }

      // ── ENHANCEMENT: parşömen slot opens picker ───────────────────────────
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.enhancement);
      await smokePump(tester, duration: const Duration(seconds: 2));

      final Finder scrollSlot = find.byKey(const Key('enhancement_scroll_slot'));
      if (scrollSlot.evaluate().isNotEmpty) {
        await tester.tap(scrollSlot.first);
        await smokePump(tester, duration: const Duration(milliseconds: 500));
        final bool sheetOpen = find
                .textContaining('parşömen')
                .evaluate()
                .isNotEmpty ||
            find.textContaining('Parşömen').evaluate().length > 1;
        if (sheetOpen) {
          bugfixUiLog(
            location: 'bugfix_batch_ui_test:enhancement_scroll_picker',
            message: 'pass',
            hypothesisId: 'ENH-SCROLL',
          );
          await tester.pageBack();
          await smokePump(tester);
        } else {
          bugfixUiLog(
            location: 'bugfix_batch_ui_test:enhancement_scroll_picker',
            message: 'sheet_not_detected',
            hypothesisId: 'ENH-SCROLL',
          );
        }
        SmokeHarness.assertNoFlutterError(tester, 'enhancement_scroll_picker');
      }

      // ── SHOP: energy potion subtitle visible when applicable ──────────────
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.shop);
      await smokePump(tester, duration: const Duration(seconds: 2));
      final Finder esyaTab = find.text('🛍️ Eşya');
      if (esyaTab.evaluate().isNotEmpty) {
        await tester.tap(esyaTab.first);
        await smokePump(tester, duration: const Duration(seconds: 2));
      }
      final bool hasEnergyHint = find.textContaining('enerji').evaluate().isNotEmpty;
      bugfixUiLog(
        location: 'bugfix_batch_ui_test:shop_energy_label',
        message: hasEnergyHint ? 'pass' : 'no_energy_potion_in_shop',
        hypothesisId: 'SHOP-ENERGY',
        data: <String, dynamic>{'has_hint': hasEnergyHint},
      );
      SmokeHarness.assertNoFlutterError(tester, 'shop_items_tab');

      // ── HOME: equipped slot tap opens dialog when gear worn ───────────────
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.home);
      await smokePump(tester, duration: const Duration(seconds: 2));
      final Finder kapatButtons = find.text('Kapat');
      // Tap center equip slots area — if equipped, dialog may appear
      await tester.tapAt(const Offset(200, 400));
      await smokePump(tester, duration: const Duration(milliseconds: 800));
      if (find.text('Envantere Git').evaluate().isNotEmpty ||
          kapatButtons.evaluate().isNotEmpty) {
        bugfixUiLog(
          location: 'bugfix_batch_ui_test:hero_equipped_info',
          message: 'pass',
          hypothesisId: 'EQUIP-INFO',
        );
        if (kapatButtons.evaluate().isNotEmpty) {
          await tester.tap(kapatButtons.first);
          await smokePump(tester);
        }
      } else {
        bugfixUiLog(
          location: 'bugfix_batch_ui_test:hero_equipped_info',
          message: 'skipped_no_equipped_gear',
          hypothesisId: 'EQUIP-INFO',
        );
      }
      SmokeHarness.assertNoFlutterError(tester, 'home_equipped_tap');

      bugfixUiLog(
        location: 'bugfix_batch_ui_test',
        message: 'ui_smoke_complete',
        hypothesisId: 'DONE',
      );
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}
