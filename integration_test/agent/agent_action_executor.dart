/// UI action executor bridge (spot-check / future UI agent).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../smoke/smoke_harness.dart';
import 'agent_action_schema.dart';

class AgentActionExecutor {
  const AgentActionExecutor();

  Future<AgentActionResult> run(
    WidgetTester tester,
    GoRouter router,
    AgentAction action,
  ) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      switch (action.kind) {
        case 'navigate':
          if (action.route == null) {
            return AgentActionResult(
              actionId: action.id,
              ok: false,
              error: 'missing route',
              dtMs: sw.elapsedMilliseconds,
            );
          }
          await SmokeHarness.navigateRoute(tester, router, action.route!);
          break;
        case 'tap':
          final Finder f = find.text(action.label ?? '');
          if (f.evaluate().isEmpty) {
            return AgentActionResult(
              actionId: action.id,
              ok: false,
              error: 'label not found',
              dtMs: sw.elapsedMilliseconds,
            );
          }
          await tester.tap(f.first, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 400));
          break;
        case 'wait':
          await tester.pump(const Duration(milliseconds: 500));
          break;
        case 'abort':
          return AgentActionResult(
            actionId: action.id,
            ok: true,
            dtMs: sw.elapsedMilliseconds,
          );
        default:
          return AgentActionResult(
            actionId: action.id,
            ok: false,
            error: 'unsupported kind ${action.kind}',
            dtMs: sw.elapsedMilliseconds,
          );
      }
      SmokeHarness.assertNoFlutterError(tester, action.id);
      return AgentActionResult(
        actionId: action.id,
        ok: true,
        dtMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      return AgentActionResult(
        actionId: action.id,
        ok: false,
        error: e.toString(),
        dtMs: sw.elapsedMilliseconds,
      );
    }
  }
}
