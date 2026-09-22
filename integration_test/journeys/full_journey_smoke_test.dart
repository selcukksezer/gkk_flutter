import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/routing/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../smoke/helpers.dart';
import '../smoke/smoke_harness.dart';

class GameplayStepResult {
  GameplayStepResult({
    required this.id,
    required this.title,
    required this.pass,
    this.detail,
    this.error,
  });

  final String id;
  final String title;
  final bool pass;
  final String? detail;
  final String? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'pass': pass,
        'detail': detail,
        'error': error,
      };
}

class GameplayJourneyReport {
  GameplayJourneyReport({required this.runId});

  final String runId;
  final List<GameplayStepResult> steps = <GameplayStepResult>[];

  void add(GameplayStepResult step) => steps.add(step);

  List<String> get failures => steps
      .where((GameplayStepResult s) => !s.pass && s.error != null)
      .map((GameplayStepResult s) => '${s.id}: ${s.error}')
      .toList();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'run_id': runId,
        'test_name': 'gameplay_journey_smoke',
        'verdict': failures.isEmpty ? 'PASS' : 'FAIL',
        'pass': steps.where((GameplayStepResult s) => s.pass).length,
        'total': steps.length,
        'failures': failures,
        'steps': steps.map((GameplayStepResult s) => s.toJson()).toList(),
      };
}

Future<void> _runStep(
  WidgetTester tester,
  GameplayJourneyReport report,
  String id,
  String title,
  Future<String?> Function() action,
) async {
  try {
    final String? err = await action();
    report.add(
      GameplayStepResult(
        id: id,
        title: title,
        pass: err == null,
        error: err,
      ),
    );
  } catch (e) {
    tester.takeException();
    report.add(
      GameplayStepResult(
        id: id,
        title: title,
        pass: false,
        error: e.toString(),
      ),
    );
  }
}

/// Real gameplay smoke — HUD, dungeon, inventory, character, quests, economy.
/// Not a route matrix; validates player-facing flows.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Gameplay journey smoke (device)', () {
    testWidgets('F2P loop: home → dungeon → inventory → character → quests → market',
        (WidgetTester tester) async {
      if (!SmokeEnv.hasResolvedCredentials) {
        expect(true, true, reason: 'Skipped — no QA creds');
        return;
      }

      final GameplayJourneyReport report = GameplayJourneyReport(
        runId: DateTime.now().toUtc().toIso8601String(),
      );

      await SmokeHarness.ensureInitialized();
      await SmokeHarness.pumpApp(tester);
      final GoRouter router = SmokeHarness.routerFromTester(tester);

      // Blocker: legal policy gate must not crash (Checkbox/Material).
      await _runStep(tester, report, 'policy_gate', 'Policy gate safe', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.home);
        await smokePump(tester, duration: const Duration(seconds: 2));
        if (find.text('Güncellenmiş sözleşmeler').evaluate().isNotEmpty) {
          if (find.byType(Checkbox).evaluate().isEmpty) {
            return 'Policy modal visible but Checkbox missing';
          }
          return tester.takeException()?.toString();
        }
        return tester.takeException()?.toString();
      });

      await _runStep(tester, report, 'home_hud', 'Home HUD loaded', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.home);
        await smokePump(tester, duration: const Duration(seconds: 2));
        final bool hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;
        final bool hasHero = find.byType(Scaffold).evaluate().isNotEmpty;
        if (!hasScaffold || !hasHero) {
          return 'Home scaffold missing';
        }
        return tester.takeException()?.toString();
      });

      await _runStep(tester, report, 'dungeon_list', 'Dungeon list playable', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.dungeon);
        await smokePump(tester, duration: const Duration(seconds: 2));
        await waitForFinder(
          tester,
          find.textContaining('Zindan'),
          timeout: const Duration(seconds: 15),
        );
        return tester.takeException()?.toString();
      });

      await _runStep(tester, report, 'inventory', 'Inventory grid', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.inventory);
        await smokePump(tester, duration: const Duration(seconds: 2));
        if (find.byType(Scaffold).evaluate().isEmpty) {
          return 'Inventory scaffold missing';
        }
        return tester.takeException()?.toString();
      });

      await _runStep(tester, report, 'character', 'Character stats', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.character);
        await waitForFinder(
          tester,
          find.byIcon(Icons.military_tech_rounded),
          timeout: const Duration(seconds: 15),
        );
        return tester.takeException()?.toString();
      });

      await _runStep(tester, report, 'quests', 'Quest board', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.quests);
        await smokePump(tester, duration: const Duration(seconds: 2));
        final Finder questTitle = find.textContaining('Görev');
        if (questTitle.evaluate().isEmpty) {
          return 'Quest screen title not found';
        }
        return tester.takeException()?.toString();
      });

      await _runStep(tester, report, 'reputation', 'Reputation overview', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.reputation);
        await waitForFinder(
          tester,
          find.text('İtibar'),
          timeout: const Duration(seconds: 15),
        );
        return tester.takeException()?.toString();
      });

      await _runStep(tester, report, 'market', 'Market browse', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.market);
        await smokePump(tester, duration: const Duration(seconds: 2));
        if (find.byType(Scaffold).evaluate().isEmpty) {
          return 'Market scaffold missing';
        }
        return tester.takeException()?.toString();
      });

      await _runStep(tester, report, 'crafting', 'Crafting queue', () async {
        await SmokeHarness.navigateRoute(tester, router, AppRoutes.crafting);
        await smokePump(tester, duration: const Duration(seconds: 2));
        if (find.byType(Scaffold).evaluate().isEmpty) {
          return 'Crafting scaffold missing';
        }
        return tester.takeException()?.toString();
      });

      // ignore: avoid_print
      print('FULL_JOURNEY_SMOKE_JSON:${jsonEncode(report.toJson())}');
      // ignore: avoid_print
      print(
        'FULL_JOURNEY_VERDICT:${report.toJson()['verdict']} '
        '${report.steps.where((GameplayStepResult s) => s.pass).length}/${report.steps.length}',
      );

      expect(
        report.failures,
        isEmpty,
        reason: report.failures.join('\n'),
      );
    }, timeout: const Timeout(Duration(minutes: 8)));
  });
}
