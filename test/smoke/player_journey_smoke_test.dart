import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Invariants for [scripts/run_player_journey_smoke.sh] output.
/// Run: ./scripts/run_player_journey_smoke.sh
void main() {
  group('player journey smoke report', () {
    final File report = File('reports/player_journey_smoke.json');

    test('report exists after smoke run', () {
      expect(
        report.existsSync(),
        true,
        reason: 'Run: ./scripts/run_player_journey_smoke.sh',
      );
    }, skip: !report.existsSync());

    test('all F2P journey steps pass', () {
      final Map<String, dynamic> data =
          jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;

      expect(data['verdict'], 'PASS');

      final List<dynamic> steps = data['steps'] as List<dynamic>? ?? [];
      expect(steps, isNotEmpty);

      const Set<String> required = {
        'energy_check',
        'dungeon_list_shape',
        'dungeon_entry_validation',
        'quest_list_shape',
        'quest_claim_shape',
        'reputation_overview',
      };

      final Set<String> passed = steps
          .where((dynamic s) => (s as Map)['pass'] == true)
          .map((dynamic s) => (s as Map)['step'] as String)
          .toSet();

      for (final String name in required) {
        expect(passed.contains(name), true, reason: 'missing pass: $name');
      }
    }, skip: !report.existsSync());
  });
}
