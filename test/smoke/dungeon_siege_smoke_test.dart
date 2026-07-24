import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Invariants for [scripts/run_dungeon_siege_smoke.sh] output.
/// Run: ./scripts/run_dungeon_siege_smoke.sh
void main() {
  group('dungeon siege smoke report', () {
    final File report = File('reports/dungeon_siege_smoke.json');

    test('report exists after smoke run', () {
      expect(
        report.existsSync(),
        true,
        reason: 'Run: ./scripts/run_dungeon_siege_smoke.sh',
      );
    }, skip: !report.existsSync());

    test('all siege gates pass', () {
      final Map<String, dynamic> data =
          jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;

      expect(data['verdict'], 'PASS');

      final List<dynamic> tests = data['tests'] as List<dynamic>? ?? [];
      expect(tests, isNotEmpty);

      const Set<String> required = {
        'siege_config_table_exists',
        'siege_rpc_functions_exist',
        'siege_config_rpc_shape',
        'siege_status_rpc_shape',
        'siege_hub_rpc_shape',
        'siege_leaderboard_rpc_shape',
        'siege_claim_slot',
        'siege_challenge_no_bonus_for_non_owner_guild',
        'siege_notifications_rpc',
        'siege_release_slot',
        'siege_config_restored',
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
