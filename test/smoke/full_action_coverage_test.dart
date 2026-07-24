import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_action_registry.dart';

/// Invariants for [scripts/run_full_action_audit.sh] merged report.
void main() {
  group('full 350-action coverage', () {
    test('registry declares exactly 350 actions', () {
      expect(SmokeActionRegistry.fullInventoryActionCount, 350);
      expect(SmokeActionRegistry.allActions.length, 350);
      expect(SmokeActionRegistryFull.autoTapCount, 317);
      expect(SmokeActionRegistryFull.rpcCount, 25);
      expect(SmokeActionRegistryFull.skipCount, 8);
    });

    final File report = File('reports/full_action_audit.json');

    test('merged audit report exists after full run', () {
      expect(
        report.existsSync(),
        true,
        reason: 'Run: ./scripts/run_full_action_audit.sh',
      );
    }, skip: !report.existsSync());

    test('350/350 covered or explicit skip', () {
      final Map<String, dynamic> data =
          jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;

      expect(data['total'], 350);
      expect(data['covered'], 350);
      expect(data['missing'], 0);

      final List<dynamic> actions = data['actions'] as List<dynamic>? ?? [];
      expect(actions.length, 350);

      final List<Map<String, dynamic>> failures = actions
          .cast<Map<String, dynamic>>()
          .where((Map<String, dynamic> a) => a['status'] == 'fail')
          .toList();

      if (failures.isNotEmpty) {
        fail(
          '${failures.length} failed actions:\n'
          '${failures.take(20).map((Map<String, dynamic> f) => f['action_id']).join('\n')}',
        );
      }

      expect(data['verdict'], 'PASS');
    }, skip: !report.existsSync());
  });
}
