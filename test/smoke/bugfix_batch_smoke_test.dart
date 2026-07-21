import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Invariants for [scripts/run_bugfix_batch_smoke.sh] output.
/// Run: ./scripts/run_bugfix_batch_smoke.sh
void main() {
  group('bugfix batch smoke report', () {
    final File report = File('reports/bugfix_batch_smoke.json');

    test('report exists after smoke run', () {
      expect(
        report.existsSync(),
        true,
        reason: 'Run: ./scripts/run_bugfix_batch_smoke.sh',
      );
    }, skip: !report.existsSync());

    test('all bank/equip/box/leaderboard gates pass', () {
      final Map<String, dynamic> data =
          jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;

      expect(data['verdict'], 'PASS');

      final List<dynamic> tests = data['tests'] as List<dynamic>? ?? [];
      expect(tests, isNotEmpty);

      const Set<String> required = {
        'bank_expand_5_gems_one_slot',
        'bank_full_no_deposit_to_locked_slots',
        'bank_unlock_then_deposit_new_slot',
        'bank_no_duplicate_slot_positions',
        'bank_expand_blocked_insufficient_gems',
        'bank_expand_blocked_at_max_200',
        'bank_withdraw_partial_qty',
        'equip_replace_same_slot_no_collision',
        'box_one_active_opening_per_user',
        'leaderboard_weekly_gold_from_dungeon_runs',
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
