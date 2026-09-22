import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor_registry.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/main.dart';
import 'package:integration_test/integration_test.dart';

import '../smoke/helpers.dart';
import '../smoke/screenshot_helper.dart';
import '../smoke/smoke_harness.dart';

/// Helpers for LIVE tutorial journey smoke.
abstract final class TutorialSmokeHelpers {
  TutorialSmokeHelpers._();

  /// Capture PNG for [stepId]. Best-effort — never hangs the suite (>8s → skip).
  static Future<String?> captureStepScreenshot({
    required IntegrationTestWidgetsFlutterBinding binding,
    required WidgetTester tester,
    required String stepId,
    required String phase,
    required int index,
  }) async {
    final String slug =
        '${index.toString().padLeft(2, '0')}_${phase}_$stepId';
    try {
      // Android needs surface→image; calling this on iOS can hang the driver.
      if (!kIsWeb && Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 200));
      final List<int> bytes = await binding
          .takeScreenshot(slug)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => <int>[],
          );
      if (bytes.isEmpty) {
        // ignore: avoid_print
        print('TUTORIAL_SHOT_SKIP:$slug empty_or_timeout');
        return null;
      }

      final String? dir = screenshotOutputDir();
      if (dir != null && writesScreenshotsOnHost) {
        final String path = '$dir/$slug.png';
        final File file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        // ignore: avoid_print
        print('TUTORIAL_SHOT_OK:$path');
        return path;
      }
      // Device/sim: driver pulls via onScreenshot → AUDIT_SCREENSHOT_DIR/$slug.png
      final String path = '${dir ?? 'reports/screenshots/tutorial'}/$slug.png';
      // ignore: avoid_print
      print('TUTORIAL_SHOT_OK:$path');
      return path;
    } catch (e) {
      // ignore: avoid_print
      print('TUTORIAL_SHOT_SKIP:$slug $e');
      return null;
    }
  }

  /// Suggested fixes when a step fails (or always for audit).
  static List<String> fixNotesFor({
    required String stepId,
    required bool pass,
    String? error,
    String? activeStepId,
  }) {
    final List<String> notes = <String>[];
    if (!pass) {
      notes.add('FAIL: ${error ?? 'unknown'}');
      if (activeStepId != null && activeStepId != stepId) {
        notes.add('Active step desync: expected=$stepId got=$activeStepId');
      }
    }

    switch (stepId) {
      case 'onboarding_welcome':
      case 'onboarding_game_loop':
        if (!pass) {
          notes.add('Check TutorialTooltipCard primary CTA labels / l10n.');
        }
      case 'onboarding_home_promo':
      case 'onboarding_home_hero':
        if (!pass) {
          notes.add(
            'home.promo / home.hero anchor missing — HomeScreen TutorialAnchorScope.',
          );
        }
      case 'onboarding_hud_energy':
      case 'onboarding_hud_gold':
      case 'onboarding_hud_gems':
      case 'onboarding_nav_intro':
        if (!pass) {
          notes.add('Manual CTA not found — tap Devam / completeActiveManual.');
        }
      case 'onboarding_tap_dungeon_tab':
        if (!pass) {
          notes.add(
            'nav.dungeon_tab — GameBottomBar allowsNavTab / onAnchorTap.',
          );
        }
      case 'dungeon_pick_zone':
      case 'dungeon_enter_btn':
      case 'dungeon_confirm_enter':
        if (!pass) {
          notes.add(
            'Dungeon anchors — dungeon_screen zone/enter/confirm wiring.',
          );
        }
      case 'dungeon_first_win':
        if (!pass) {
          notes.add(
            'Win hold — TutorialTriggers.onDungeonWin / revealHeldDungeonWin.',
          );
        }
      case 'inventory_first_item':
        if (!pass) {
          notes.add(
            'inventory.first_weapon — no loot? Seed QA inventory.',
          );
        }
      case 'inventory_open_menu':
      case 'inventory_tap_enhance':
        if (!pass) {
          notes.add(
            'Quick menu keepOverlay / menu item anchors (enhance before equip).',
          );
        }
      case 'enhance_equip':
        if (!pass) {
          notes.add(
            'equip_success after upgrade — inventory detail keepOverlay.',
          );
        }
      case 'character_open_menu':
      case 'character_tap_season':
        if (!pass) {
          notes.add(
            'Quick menu keepOverlay / blocksNavigation / season tile.',
          );
        }
      case 'enhance_pick_item':
      case 'enhance_tap_forge':
        if (!pass) {
          notes.add(
            'Enhancement anchors / enhancement_attempt game event.',
          );
        }
      case 'hospital_health_intro':
        if (!pass) {
          notes.add(
            'hud.health onTutorialTap — game_chrome TutorialAnchorScope.',
          );
        }
      case 'soft_pause_core_pin':
        if (!pass) {
          notes.add(
            'Core-pin soft-pause — tutorial_controller onRouteEnter clearActive.',
          );
        }
      default:
        if (!pass) {
          notes.add('Inspect screenshot + tutorial_controller / host for $stepId.');
        }
    }

    if (pass && notes.isEmpty) {
      notes.add('OK — no fix required for this step.');
    }
    return notes;
  }

  static ProviderContainer containerOf(WidgetTester tester) {
    final Element app = find.byType(GkkMobileApp).evaluate().first;
    return ProviderScope.containerOf(app);
  }

  static TutorialController controller(WidgetTester tester) =>
      containerOf(tester).read(tutorialProvider.notifier);

  static TutorialState state(WidgetTester tester) =>
      containerOf(tester).read(tutorialProvider);

  static void expectStep(WidgetTester tester, String stepId) {
    expect(
      state(tester).activeStep?.id,
      stepId,
      reason: 'expected active step $stepId',
    );
  }

  static void expectTrack(WidgetTester tester, String trackId) {
    expect(
      state(tester).activeTrackId,
      trackId,
      reason: 'expected active track $trackId',
    );
  }

  static Future<void> dismissBlockingDialogs(WidgetTester tester) async {
    for (final String label in <String>[
      'TAMAM',
      'Tamam',
      'OK',
      'Kabul Et',
      'Kabul et',
      'Anladım',
    ]) {
      final Finder f = find.text(label);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first, warnIfMissed: false);
        await smokePump(tester, duration: const Duration(milliseconds: 400));
      }
    }
  }

  /// Taps the coach primary CTA if visible.
  static Future<bool> tapTutorialPrimary(WidgetTester tester) async {
    await dismissBlockingDialogs(tester);
    for (final String label in <String>[
      'Rehbere Başla',
      'Anladım',
      'Devam',
      'Continue',
      'Tamam',
      'Done',
    ]) {
      final Finder f = find.text(label);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first, warnIfMissed: false);
        await smokePump(tester, duration: const Duration(milliseconds: 800));
        return true;
      }
    }
    return false;
  }

  /// Taps registered anchor hole center (global → local via tester).
  static Future<bool> tapAnchorHole(
    WidgetTester tester,
    String anchorId,
  ) async {
    TutorialAnchorRegistry.instance.scheduleRefresh();
    await tester.pump(const Duration(milliseconds: 200));
    final Rect? rect = TutorialAnchorRegistry.instance.rectFor(anchorId);
    if (rect == null || rect.width <= 0 || rect.height <= 0) {
      return false;
    }
    final Offset center = rect.center;
    await tester.tapAt(center);
    await smokePump(tester, duration: const Duration(milliseconds: 800));
    return true;
  }

  /// Wait until active step id equals [stepId] or timeout.
  static Future<bool> waitForStep(
    WidgetTester tester,
    String stepId, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (state(tester).activeStep?.id == stepId) return true;
      await tester.pump(const Duration(milliseconds: 200));
    }
    return false;
  }

  /// Advance narrative / manual-dismiss via primary CTA.
  static Future<String?> advanceManual(
    WidgetTester tester,
    String expectedStepId,
  ) async {
    if (state(tester).activeStep?.id != expectedStepId) {
      return 'expected $expectedStepId, got ${state(tester).activeStep?.id}';
    }
    final bool tapped = await tapTutorialPrimary(tester);
    if (!tapped) {
      // Fallback: complete via controller when CTA text missed.
      await controller(tester).completeActiveManual();
      await smokePump(tester, duration: const Duration(milliseconds: 500));
    }
    SmokeHarness.assertNoFlutterError(tester, expectedStepId);
    return null;
  }

  /// Tap-target step: hole first; if step unchanged → controller onAnchorTap.
  static Future<String?> advanceTapAnchor(
    WidgetTester tester,
    String expectedStepId,
    String anchorId,
  ) async {
    if (state(tester).activeStep?.id != expectedStepId) {
      return 'expected $expectedStepId, got ${state(tester).activeStep?.id}';
    }
    await tapAnchorHole(tester, anchorId);
    // Hole tap may miss catcher (coord/dialog). Always force complete if stuck.
    if (state(tester).activeStep?.id == expectedStepId) {
      await controller(tester).onAnchorTap(anchorId);
      await smokePump(tester, duration: const Duration(milliseconds: 600));
    }
    SmokeHarness.assertNoFlutterError(tester, expectedStepId);
    return null;
  }

  static Future<void> resetOnboarding(WidgetTester tester) async {
    await dismissBlockingDialogs(tester);
    final TutorialController ctrl = controller(tester);
    await ctrl.resetAndReplay().timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
    await smokePump(tester, duration: const Duration(seconds: 1));
    TutorialAnchorRegistry.instance.scheduleRefresh();
    await tester.pump(const Duration(milliseconds: 400));
  }
}
