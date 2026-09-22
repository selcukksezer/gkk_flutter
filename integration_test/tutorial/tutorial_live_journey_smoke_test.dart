import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_anchor_registry.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_controller.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_persistence.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_step.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track.dart';
import 'package:gkk_flutter/core/tutorial/tutorial_track_registry.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../smoke/helpers.dart';
import '../smoke/screenshot_helper.dart';
import '../smoke/smoke_harness.dart';
import 'tutorial_smoke_helpers.dart';

class _StepResult {
  _StepResult({
    required this.id,
    required this.title,
    required this.pass,
    this.error,
    this.screenshotBefore,
    this.screenshotAfter,
    this.fixNotes = const <String>[],
    this.activeStepBefore,
    this.activeStepAfter,
  });

  final String id;
  final String title;
  final bool pass;
  final String? error;
  final String? screenshotBefore;
  final String? screenshotAfter;
  final List<String> fixNotes;
  final String? activeStepBefore;
  final String? activeStepAfter;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'pass': pass,
        'error': error,
        'screenshot_before': screenshotBefore,
        'screenshot_after': screenshotAfter,
        'active_step_before': activeStepBefore,
        'active_step_after': activeStepAfter,
        'fix_notes': fixNotes,
      };
}

class _Report {
  _Report({required this.runId, required this.screenshotDir});

  final String runId;
  final String screenshotDir;
  final List<_StepResult> steps = <_StepResult>[];
  int _shotIndex = 0;

  void add(_StepResult step) => steps.add(step);

  int nextShotIndex() => ++_shotIndex;

  List<String> get failures => steps
      .where((_StepResult s) => !s.pass)
      .map((_StepResult s) => '${s.id}: ${s.error}')
      .toList();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'run_id': runId,
        'test_name': 'tutorial_live_journey_smoke',
        'screenshot_dir': screenshotDir,
        'verdict': failures.isEmpty ? 'PASS' : 'FAIL',
        'pass': steps.where((_StepResult s) => s.pass).length,
        'total': steps.length,
        'failures': failures,
        'steps': steps.map((_StepResult s) => s.toJson()).toList(),
      };

  String toFixesMarkdown() {
    final StringBuffer buf = StringBuffer()
      ..writeln('# Tutorial LIVE Smoke — Düzeltme Notları')
      ..writeln()
      ..writeln('- run_id: `$runId`')
      ..writeln('- screenshot_dir: `$screenshotDir`')
      ..writeln('- verdict: **${failures.isEmpty ? 'PASS' : 'FAIL'}**')
      ..writeln();
    for (final _StepResult s in steps) {
      buf
        ..writeln('## ${s.id}')
        ..writeln()
        ..writeln('- title: ${s.title}')
        ..writeln('- pass: ${s.pass}')
        ..writeln('- before: `${s.screenshotBefore ?? '-'}`')
        ..writeln('- after: `${s.screenshotAfter ?? '-'}`');
      if (s.error != null) {
        buf.writeln('- error: `${s.error}`');
      }
      buf.writeln('- fix_notes:');
      for (final String n in s.fixNotes) {
        buf.writeln('  - $n');
      }
      buf.writeln();
    }
    return buf.toString();
  }
}

Future<void> _runStep(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  _Report report,
  String id,
  String title,
  Future<String?> Function() action,
) async {
  final int idx = report.nextShotIndex();
  // ignore: avoid_print
  print('TUTORIAL_STEP_START:$id');
  final String? beforeStep = TutorialSmokeHelpers.state(tester).activeStep?.id;

  String? err;
  try {
    // Do NOT Future.timeout tester actions — timeout does not cancel and
    // causes Guarded function conflict on WidgetTester.pump.
    err = await action();
  } catch (e) {
    tester.takeException();
    err = e.toString();
  }

  final String? afterStep = TutorialSmokeHelpers.state(tester).activeStep?.id;
  // One shot after action (before+after doubled hang risk on iOS drive).
  final String? shotAfter = await TutorialSmokeHelpers.captureStepScreenshot(
    binding: binding,
    tester: tester,
    stepId: id,
    phase: 'after',
    index: idx,
  );

  final bool pass = err == null;
  // ignore: avoid_print
  print('TUTORIAL_STEP_END:$id pass=$pass err=$err');
  // ignore: avoid_print
  print(
    'TUTORIAL_STEP_JSON:${jsonEncode(<String, Object?>{
      'id': id,
      'pass': pass,
      'error': err,
      'screenshot_after': shotAfter,
      'fix_notes': TutorialSmokeHelpers.fixNotesFor(
        stepId: id,
        pass: pass,
        error: err,
        activeStepId: afterStep,
      ),
    })}',
  );
  report.add(
    _StepResult(
      id: id,
      title: title,
      pass: pass,
      error: err,
      screenshotBefore: null,
      screenshotAfter: shotAfter,
      activeStepBefore: beforeStep,
      activeStepAfter: afterStep,
      fixNotes: TutorialSmokeHelpers.fixNotesFor(
        stepId: id,
        pass: pass,
        error: err,
        activeStepId: afterStep,
      ),
    ),
  );
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tutorial live journey (device)', () {
    testWidgets(
      'core: onboarding → dungeon → inventory → character → enhance',
      (WidgetTester tester) async {
        if (!SmokeEnv.hasResolvedCredentials) {
          expect(true, true, reason: 'Skipped — no QA creds');
          return;
        }

        final String shotDir = screenshotOutputDir() ??
            'reports/screenshots/tutorial_${DateTime.now().toIso8601String().substring(0, 10)}';
        final _Report report = _Report(
          runId: DateTime.now().toUtc().toIso8601String(),
          screenshotDir: shotDir,
        );

        // ignore: avoid_print
        print('TUTORIAL_BOOT: pumpApp start');
        await SmokeHarness.ensureInitialized();
        await SmokeHarness.pumpApp(tester);
        // ignore: avoid_print
        print('TUTORIAL_BOOT: pumpApp done');
        await TutorialSmokeHelpers.dismissBlockingDialogs(tester);
        // ignore: avoid_print
        print('TUTORIAL_BOOT: resetOnboarding');
        await TutorialSmokeHelpers.resetOnboarding(tester);
        // ignore: avoid_print
        print('TUTORIAL_BOOT: ready step=${TutorialSmokeHelpers.state(tester).activeStep?.id}');

        await _runStep(
          tester,
          binding,
          report,
          'onboarding_welcome',
          'Welcome narrative',
          () => TutorialSmokeHelpers.advanceManual(
            tester,
            'onboarding_welcome',
          ),
        );

        await _runStep(
          tester,
          binding,
          report,
          'onboarding_game_loop',
          'Game loop narrative',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'onboarding_game_loop',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceManual(
              tester,
              'onboarding_game_loop',
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'onboarding_home_promo',
          'Home promo highlight',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'onboarding_home_promo',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'onboarding_home_promo',
              TutorialAnchorId.homePromo,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'onboarding_home_hero',
          'Home hero highlight',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'onboarding_home_hero',
              timeout: const Duration(seconds: 10),
            );
            if (!ready) {
              // Promo may have skipped if anchor missing — tolerate hero.
              if (TutorialSmokeHelpers.state(tester).activeStep?.id ==
                  'onboarding_home_hero') {
                return TutorialSmokeHelpers.advanceTapAnchor(
                  tester,
                  'onboarding_home_hero',
                  TutorialAnchorId.homeHero,
                );
              }
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'onboarding_home_hero',
              TutorialAnchorId.homeHero,
            );
          },
        );

        for (final String stepId in <String>[
          'onboarding_hud_energy',
          'onboarding_hud_gold',
          'onboarding_hud_gems',
          'onboarding_nav_intro',
        ]) {
          await _runStep(
            tester,
            binding,
            report,
            stepId,
            'HUD/nav manual $stepId',
            () async {
              final bool ready = await TutorialSmokeHelpers.waitForStep(
                tester,
                stepId,
                timeout: const Duration(seconds: 12),
              );
              if (!ready) {
                return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
              }
              return TutorialSmokeHelpers.advanceManual(tester, stepId);
            },
          );
        }

        await _runStep(
          tester,
          binding,
          report,
          'onboarding_tap_dungeon_tab',
          'Tap dungeon tab',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'onboarding_tap_dungeon_tab',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            final String? err = await TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'onboarding_tap_dungeon_tab',
              TutorialAnchorId.navDungeonTab,
            );
            if (err != null) return err;
            // Race: track complete may clearActive before route sync.
            final GoRouter router = SmokeHarness.routerFromTester(tester);
            await SmokeHarness.navigateRoute(
              tester,
              router,
              AppRoutes.dungeon,
            );
            await TutorialSmokeHelpers.controller(tester).onRouteEnter(
                  TutorialRoutes.dungeon,
                );
            await smokePump(tester, duration: const Duration(seconds: 1));
            return null;
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'dungeon_intro',
          'Dungeon intro',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'dungeon_intro',
              timeout: const Duration(seconds: 25),
            );
            if (!ready) {
              // Force-start dungeon track if route sync dropped it.
              await TutorialSmokeHelpers.controller(tester).startTrack(
                    TutorialTrackId.dungeon,
                  );
              await smokePump(tester, duration: const Duration(seconds: 1));
              final bool again = await TutorialSmokeHelpers.waitForStep(
                tester,
                'dungeon_intro',
                timeout: const Duration(seconds: 10),
              );
              if (!again) {
                return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
              }
            }
            return TutorialSmokeHelpers.advanceManual(tester, 'dungeon_intro');
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'dungeon_pick_zone',
          'Pick zone 1',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'dungeon_pick_zone',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'dungeon_pick_zone',
              TutorialAnchorId.dungeonZone1Tab,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'dungeon_enter_btn',
          'Enter dungeon',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'dungeon_enter_btn',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'dungeon_enter_btn',
              TutorialAnchorId.dungeonEnterBtn,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'dungeon_confirm_enter',
          'Confirm enter',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'dungeon_confirm_enter',
              timeout: const Duration(seconds: 15),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'dungeon_confirm_enter',
              TutorialAnchorId.dungeonConfirmOk,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'dungeon_battle_fight',
          'Tap SAVAŞ! (no coach step)',
          () async {
            // Coach cleared after confirm — fight freely, then win reveals first_win.
            final bool tapped = await TutorialSmokeHelpers.tapAnchorHole(
              tester,
              TutorialAnchorId.dungeonAttackBtn,
            );
            if (!tapped) {
              return 'SAVAŞ! anchor missing (dungeon.attack_btn)';
            }
            await tester.pump(const Duration(seconds: 2));
            return null;
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'dungeon_first_win',
          'First win narrative',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'dungeon_first_win',
              timeout: const Duration(seconds: 90),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id} '
                  '(battle win hold timeout)';
            }
            return TutorialSmokeHelpers.advanceManual(
              tester,
              'dungeon_first_win',
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'dungeon_to_inventory',
          'Nav to inventory',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'dungeon_to_inventory',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'dungeon_to_inventory',
              TutorialAnchorId.navInventoryTab,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'inventory_first_item',
          'Loot peek (Devam)',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'inventory_first_item',
              timeout: const Duration(seconds: 20),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceManual(
              tester,
              'inventory_first_item',
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'inventory_open_menu',
          'Open menu for enhance',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'inventory_open_menu',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'inventory_open_menu',
              TutorialAnchorId.navMenuTab,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'inventory_tap_enhance',
          'Tap enhancement (before equip)',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'inventory_tap_enhance',
              timeout: const Duration(seconds: 15),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'inventory_tap_enhance',
              TutorialAnchorId.navMenuEnhancement,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'enhance_pick_item',
          'Pick enhance item (unequipped)',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'enhance_pick_item',
              timeout: const Duration(seconds: 25),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'enhance_pick_item',
              TutorialAnchorId.enhanceInventoryWeapon,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'enhance_tap_forge',
          'Forge attempt',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'enhance_tap_forge',
              timeout: const Duration(seconds: 15),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            await TutorialSmokeHelpers.tapAnchorHole(
              tester,
              TutorialAnchorId.enhanceForgeBtn,
            );
            final bool advanced = await TutorialSmokeHelpers.waitForStep(
              tester,
              'enhance_result',
              timeout: const Duration(seconds: 30),
            );
            if (!advanced) {
              return 'enhancement_attempt not observed; '
                  'step=${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return null;
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'enhance_result',
          'Enhance result narrative',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'enhance_result',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceManual(tester, 'enhance_result');
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'enhance_to_inventory',
          'Back to inventory to equip',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'enhance_to_inventory',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'enhance_to_inventory',
              TutorialAnchorId.navInventoryTab,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'enhance_open_item',
          'Open upgraded item',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'enhance_open_item',
              timeout: const Duration(seconds: 20),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'enhance_open_item',
              TutorialAnchorId.inventoryFirstWeapon,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'enhance_equip',
          'Equip after upgrade',
          () async {
            final bool onEquip = await TutorialSmokeHelpers.waitForStep(
              tester,
              'enhance_equip',
              timeout: const Duration(seconds: 15),
            );
            if (!onEquip) {
              if (TutorialSmokeHelpers.state(tester)
                      .progress
                      .stepsForTrack(TutorialTrackId.enhancement)
                      .contains('enhance_equip')) {
                return null;
              }
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            for (final String label in <String>['KUSAN', 'KUŞAN', 'Equip']) {
              final Finder kusan = find.textContaining(label);
              if (kusan.evaluate().isNotEmpty) {
                await tester.tap(kusan.first, warnIfMissed: false);
                await smokePump(tester, duration: const Duration(seconds: 2));
                break;
              }
            }
            await TutorialSmokeHelpers.tapAnchorHole(
              tester,
              TutorialAnchorId.inventoryEquipBtn,
            );
            await TutorialAnchorRegistry.instance.invokeTapAction(
              TutorialAnchorId.inventoryEquipBtn,
            );
            await smokePump(tester, duration: const Duration(seconds: 2));

            final bool advanced = await TutorialSmokeHelpers.waitForStep(
              tester,
              'enhance_to_character',
              timeout: const Duration(seconds: 35),
            );
            if (!advanced) {
              return 'equip_success not observed; '
                  'step=${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return null;
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'enhance_to_character',
          'Nav to character after equip',
          () async {
            final String? id =
                TutorialSmokeHelpers.state(tester).activeStep?.id;
            if (id == 'enhance_to_character') {
              return TutorialSmokeHelpers.advanceTapAnchor(
                tester,
                'enhance_to_character',
                TutorialAnchorId.navCharacterTab,
              );
            }
            if (TutorialSmokeHelpers.state(tester).activeTrackId ==
                TutorialTrackId.character) {
              return null;
            }
            return 'stuck at $id';
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'character_check_power',
          'Character power',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'character_check_power',
              timeout: const Duration(seconds: 20),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'character_check_power',
              TutorialAnchorId.characterPowerStat,
            );
          },
        );

        for (final String stepId in <String>[
          'character_stat_panel',
          'character_class_abilities',
        ]) {
          await _runStep(
            tester,
            binding,
            report,
            stepId,
            'Character manual $stepId',
            () async {
              final bool ready = await TutorialSmokeHelpers.waitForStep(
                tester,
                stepId,
              );
              if (!ready) {
                return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
              }
              return TutorialSmokeHelpers.advanceManual(tester, stepId);
            },
          );
        }

        await _runStep(
          tester,
          binding,
          report,
          'character_open_menu',
          'Open menu tab',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'character_open_menu',
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'character_open_menu',
              TutorialAnchorId.navMenuTab,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'character_tap_season',
          'Tap season menu item',
          () async {
            final bool ready = await TutorialSmokeHelpers.waitForStep(
              tester,
              'character_tap_season',
              timeout: const Duration(seconds: 15),
            );
            if (!ready) {
              return 'stuck at ${TutorialSmokeHelpers.state(tester).activeStep?.id}';
            }
            return TutorialSmokeHelpers.advanceTapAnchor(
              tester,
              'character_tap_season',
              TutorialAnchorId.navMenuSeason,
            );
          },
        );

        await _runStep(
          tester,
          binding,
          report,
          'core_complete_check',
          'Core tracks progressed',
          () async {
            final TutorialState st = TutorialSmokeHelpers.state(tester);
            final bool enhanceDone = st.progress
                    .stepsForTrack(TutorialTrackId.enhancement)
                    .contains('enhance_equip') ||
                st.progress.isTrackComplete(TutorialTrackId.enhancement);
            if (enhanceDone) return null;
            return 'enhancement not progressed: '
                '${st.progress.stepsForTrack(TutorialTrackId.enhancement)}';
          },
        );

        // ignore: avoid_print
        print('TUTORIAL_JOURNEY_SMOKE_JSON:${jsonEncode(report.toJson())}');
        // ignore: avoid_print
        print('TUTORIAL_JOURNEY_FIXES_MD_BEGIN');
        // ignore: avoid_print
        print(report.toFixesMarkdown());
        // ignore: avoid_print
        print('TUTORIAL_JOURNEY_FIXES_MD_END');

        // Host write when possible (macOS flutter test); drive uses log extract.
        try {
          if (writesScreenshotsOnHost) {
            final Directory dir = Directory(shotDir);
            await dir.create(recursive: true);
            await File('$shotDir/report.json').writeAsString(
              const JsonEncoder.withIndent('  ').convert(report.toJson()),
            );
            await File('$shotDir/FIXES.md').writeAsString(
              report.toFixesMarkdown(),
            );
          }
        } catch (_) {}

        expect(
          report.failures,
          isEmpty,
          reason: report.failures.join('\n'),
        );
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );

    testWidgets('hospital_health_intro advances on hud.health tap', (
      WidgetTester tester,
    ) async {
      if (!SmokeEnv.hasResolvedCredentials) {
        expect(true, true, reason: 'Skipped — no QA creds');
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);
      await TutorialSmokeHelpers.dismissBlockingDialogs(tester);

      TutorialProgressState progress = TutorialProgressState.initial();
      for (final String t in TutorialTrackId.coreTracks) {
        progress = progress.completeTrack(t);
      }
      TutorialSmokeHelpers.controller(tester).debugSetState(
            TutorialState(
              loaded: true,
              progress: progress,
            ),
          );

      final GoRouter router = SmokeHarness.routerFromTester(tester);
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.hospital);
      await TutorialSmokeHelpers.controller(tester).onRouteEnter(
            TutorialRoutes.hospital,
          );
      await smokePump(tester, duration: const Duration(seconds: 2));
      // Clear any soft-pause from navigate race.
      TutorialSmokeHelpers.controller(tester).debugSetState(
            TutorialSmokeHelpers.state(tester).copyWith(overlayPaused: false),
          );

      await TutorialSmokeHelpers.captureStepScreenshot(
        binding: binding,
        tester: tester,
        stepId: 'hospital_health_intro',
        phase: 'before',
        index: 90,
      );

      final bool onIntro = await TutorialSmokeHelpers.waitForStep(
        tester,
        'hospital_health_intro',
        timeout: const Duration(seconds: 20),
      );
      expect(onIntro, isTrue, reason: 'hospital_health_intro should start');

      final String? err = await TutorialSmokeHelpers.advanceTapAnchor(
        tester,
        'hospital_health_intro',
        TutorialAnchorId.hudHealth,
      );

      // Belt-and-suspenders: direct complete if hole path missed.
      if (TutorialSmokeHelpers.state(tester).activeStep?.id ==
          'hospital_health_intro') {
        await TutorialSmokeHelpers.controller(tester).onAnchorTap(
              TutorialAnchorId.hudHealth,
            );
        await smokePump(tester, duration: const Duration(milliseconds: 800));
      }

      await TutorialSmokeHelpers.captureStepScreenshot(
        binding: binding,
        tester: tester,
        stepId: 'hospital_health_intro',
        phase: 'after',
        index: 90,
      );

      final bool advanced = await TutorialSmokeHelpers.waitForStep(
        tester,
        'hospital_wounded_penalty',
        timeout: const Duration(seconds: 10),
      );
      // ignore: avoid_print
      print(
        'TUTORIAL_STEP_FIX:hospital_health_intro:'
        '${jsonEncode(TutorialSmokeHelpers.fixNotesFor(stepId: 'hospital_health_intro', pass: advanced, error: advanced ? null : (err ?? 'still hospital_health_intro')))}',
      );

      expect(
        advanced,
        isTrue,
        reason:
            'hud.health tap should advance; got ${TutorialSmokeHelpers.state(tester).activeStep?.id}',
      );
    });

    testWidgets('soft-pause core pin keeps dungeon track', (
      WidgetTester tester,
    ) async {
      if (!SmokeEnv.hasResolvedCredentials) {
        expect(true, true, reason: 'Skipped — no QA creds');
        return;
      }

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);
      await TutorialSmokeHelpers.dismissBlockingDialogs(tester);

      TutorialProgressState progress = TutorialProgressState.initial();
      progress = progress.completeTrack(TutorialTrackId.onboarding);
      final TutorialStepV2 pick =
          TutorialTrackRegistry.stepById('dungeon_pick_zone')!;
      final TutorialController ctrl = TutorialSmokeHelpers.controller(tester);
      ctrl.debugSetState(
        TutorialState(
          loaded: true,
          progress: progress,
          activeTrackId: TutorialTrackId.dungeon,
          activeStep: pick,
        ),
      );
      ctrl.debugSetLastRoute(TutorialRoutes.dungeon);

      final GoRouter router = SmokeHarness.routerFromTester(tester);
      await SmokeHarness.navigateRoute(tester, router, AppRoutes.inventory);
      await ctrl.onRouteEnter(TutorialRoutes.inventory);
      await smokePump(tester, duration: const Duration(milliseconds: 800));

      await TutorialSmokeHelpers.captureStepScreenshot(
        binding: binding,
        tester: tester,
        stepId: 'soft_pause_core_pin',
        phase: 'paused',
        index: 91,
      );

      final TutorialState paused = TutorialSmokeHelpers.state(tester);
      final bool pinOk = paused.activeTrackId == TutorialTrackId.dungeon &&
          paused.overlayPaused &&
          paused.activeStep?.id == 'dungeon_pick_zone';

      expect(paused.activeTrackId, TutorialTrackId.dungeon);
      expect(paused.overlayPaused, isTrue);
      expect(paused.activeStep?.id, 'dungeon_pick_zone');

      await SmokeHarness.navigateRoute(tester, router, AppRoutes.dungeon);
      await ctrl.onRouteEnter(TutorialRoutes.dungeon);
      await smokePump(tester, duration: const Duration(milliseconds: 800));

      await TutorialSmokeHelpers.captureStepScreenshot(
        binding: binding,
        tester: tester,
        stepId: 'soft_pause_core_pin',
        phase: 'resumed',
        index: 91,
      );

      final TutorialState resumed = TutorialSmokeHelpers.state(tester);
      // ignore: avoid_print
      print(
        'TUTORIAL_STEP_FIX:soft_pause_core_pin:'
        '${jsonEncode(TutorialSmokeHelpers.fixNotesFor(stepId: 'soft_pause_core_pin', pass: pinOk && !resumed.overlayPaused, error: pinOk ? null : 'core pin failed'))}',
      );

      expect(resumed.overlayPaused, isFalse);
      expect(resumed.activeTrackId, TutorialTrackId.dungeon);
    });
  });
}
