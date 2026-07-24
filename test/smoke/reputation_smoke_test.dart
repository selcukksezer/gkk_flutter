import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Invariants for [scripts/run_reputation_smoke.sh] output.
/// Run: ./scripts/run_reputation_smoke.sh
void main() {
  group('reputation smoke report', () {
    final File report = File('reports/reputation_smoke.json');

    test('report exists after smoke run', () {
      expect(
        report.existsSync(),
        true,
        reason: 'Run: ./scripts/run_reputation_smoke.sh',
      );
    }, skip: !report.existsSync());

    test('all reputation gates pass', () {
      final Map<String, dynamic> data =
          jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;

      expect(data['verdict'], 'PASS');

      final List<dynamic> tests = data['tests'] as List<dynamic>? ?? [];
      expect(tests, isNotEmpty);

      const Set<String> required = {
        'rep_rpc_functions_exist',
        'rep_overview_rpc_shape',
        'rep_shop_rpc_shape',
        'rep_shop_has_global_items',
        'rep_purchase_insufficient_funds',
        'rep_purchase_success_shape',
        'rep_activity_logged_after_purchase',
      };

      final Set<String> passed = tests
          .where((dynamic t) => (t as Map)['pass'] == true)
          .map((dynamic t) => (t as Map)['test'] as String)
          .toSet();

      for (final String name in required) {
        expect(passed.contains(name), true, reason: 'missing pass: $name');
      }
    }, skip: !report.existsSync());
  });
}
