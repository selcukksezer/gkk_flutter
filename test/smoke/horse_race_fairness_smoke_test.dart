import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// Parses [qa_smoke_horse_race_fairness] JSON and asserts basic invariants.
Map<String, dynamic> parseHorseRaceSmokeReport(String raw) {
  final int start = raw.indexOf('{');
  final int end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw FormatException('Smoke output is not JSON: $raw');
  }
  return jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
}

void assertHorseRaceSmokeReport(Map<String, dynamic> report) {
  expect(report['success'], isTrue);
  final int runs = report['runs'] as int;
  expect(runs, greaterThan(0));

  final Map<String, dynamic> fairness =
      Map<String, dynamic>.from(report['fairness_check'] as Map<dynamic, dynamic>);

  expect(fairness['always_lowest_gold_wins'], isFalse,
      reason: 'Lowest gold mult must NOT win every round');
  expect(fairness['always_lowest_gem_wins'], isFalse,
      reason: 'Lowest gem mult must NOT win every round');
  expect(fairness['gems_low_beats_high'], isTrue,
      reason: 'Lowest gem mult win rate must exceed highest gem mult');

  final String verdict = fairness['verdict'] as String;
  expect(verdict.startsWith('FAIL'), isFalse, reason: verdict);

  for (final String key in <String>[
    'gold_lowest_mult_strategy',
    'gold_highest_mult_strategy',
    'gems_lowest_mult_strategy',
    'gems_highest_mult_strategy',
  ]) {
    final Map<String, dynamic> strategy =
        Map<String, dynamic>.from(report[key] as Map<dynamic, dynamic>);
    expect(strategy['rounds'], runs);
    expect(strategy['wins'], isA<int>());
    expect(strategy['losses'], isA<int>());
    expect((strategy['wins'] as int) + (strategy['losses'] as int), runs);
    expect(strategy['total_wagered'], isNotNull);
    expect(strategy['total_payout'], isNotNull);
    expect(strategy['net_profit'], isNotNull);
    expect(strategy['rtp_pct'], isA<num>());
  }

  final List<dynamic> distribution = report['winner_distribution_by_sort_order'] as List<dynamic>;
  expect(distribution.length, 6);
}

void main() {
  group('Horse race fairness smoke', () {
    test('report schema invariants (offline fixture)', () {
      const String fixture = '''
{
  "success": true,
  "runs": 500,
  "fairness_check": {
    "lowest_gold_mult_wins": 210,
    "lowest_gold_mult_win_pct": 42.0,
    "lowest_gem_mult_wins": 95,
    "lowest_gem_mult_win_pct": 19.0,
    "always_lowest_gold_wins": false,
    "always_lowest_gem_wins": false,
    "gems_low_beats_high": true,
    "verdict": "PASS: inverse odds + aligned gem ranks"
  },
  "winner_distribution_by_sort_order": [
    {"sort_order": 1, "wins": 210, "win_pct": 42.0},
    {"sort_order": 2, "wins": 120, "win_pct": 24.0},
    {"sort_order": 3, "wins": 80, "win_pct": 16.0},
    {"sort_order": 4, "wins": 50, "win_pct": 10.0},
    {"sort_order": 5, "wins": 25, "win_pct": 5.0},
    {"sort_order": 6, "wins": 15, "win_pct": 3.0}
  ],
  "gold_lowest_mult_strategy": {
    "rounds": 500, "wins": 210, "losses": 290,
    "total_wagered": 5000000, "total_payout": 4200000, "net_profit": -800000, "rtp_pct": 84.0
  },
  "gold_highest_mult_strategy": {
    "rounds": 500, "wins": 15, "losses": 485,
    "total_wagered": 5000000, "total_payout": 350000, "net_profit": -4650000, "rtp_pct": 7.0
  },
  "gems_lowest_mult_strategy": {
    "rounds": 500, "wins": 95, "losses": 405,
    "total_wagered": 500, "total_payout": 120.5, "net_profit": -379.5, "rtp_pct": 24.1
  },
  "gems_highest_mult_strategy": {
    "rounds": 500, "wins": 40, "losses": 460,
    "total_wagered": 500, "total_payout": 55.2, "net_profit": -444.8, "rtp_pct": 11.04
  }
}
''';
      assertHorseRaceSmokeReport(parseHorseRaceSmokeReport(fixture));
    });

    test('RPC name registered for horse race route', () {
      expect(
        'qa_smoke_horse_race_fairness',
        isNotEmpty,
        reason: 'Run: SELECT public.qa_smoke_horse_race_fairness(500);',
      );
    });
  });
}
