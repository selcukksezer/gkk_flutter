import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Invariants for [scripts/run_comprehensive_smoke_10k.sh] output.
/// Run smoke on staging, then: dart test test/smoke/comprehensive_smoke_10k_test.dart
void main() {
  group('comprehensive smoke 10k report invariants', () {
    final File report = File('reports/comprehensive_smoke_10000_30d.json');

    test('report exists after smoke run', () {
      expect(
        report.existsSync(),
        true,
        reason: 'Run: ./scripts/run_comprehensive_smoke_10k.sh 10000 30',
      );
    }, skip: !report.existsSync());

    test('PLAN_11 + PLAN_13 gates', () {
      final Map<String, dynamic> data =
          jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;

      expect(data['verdict'], 'PASS');
      expect(data['bots'], greaterThanOrEqualTo(9500));

      final Map<String, dynamic> gates =
          data['gates'] as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> plan13 =
          gates['plan13'] as Map<String, dynamic>? ?? {};
      final Map<String, dynamic> plan11 =
          gates['plan11'] as Map<String, dynamic>? ?? {};

      expect(plan11['all_pass'], true);
      expect(plan13['gold_inflation_pass'], true);
      expect(plan13['exploit_pass'], true);
      expect(plan13['casual_d30_pass'], true);
      expect(plan13['newbie_d30_pass'], true);

      final List<dynamic> tests = plan11['tests'] as List<dynamic>? ?? [];
      final Set<String> required = {
        'shadow_effective_suspicion_cap_80',
        'shadow_facility_suspicion_reduction_30pct',
        'shadow_bribe_gem_cost_minus_25pct',
        'alchemist_detox_effectiveness_plus_25pct',
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
