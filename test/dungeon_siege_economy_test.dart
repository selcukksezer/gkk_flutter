import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/gold_format.dart';
import 'package:gkk_flutter/models/dungeon_siege_economy.dart';

void main() {
  test('formatCompactGold uses K/M scale', () {
    expect(formatCompactGold(500), '500');
    expect(formatCompactGold(18000), '18.0K');
    expect(formatCompactGold(4400000), '4.4M');
  });

  test('challengeGoldForRange matches PLAN_06 boss averages', () {
    expect(
      DungeonSiegeEconomy.challengeGoldForRange(goldMin: 18000, goldMax: 40000),
      50000,
    );
    expect(
      DungeonSiegeEconomy.challengeGoldForRange(goldMin: 145000, goldMax: 310000),
      79625,
    );
    expect(
      DungeonSiegeEconomy.challengeGoldForRange(goldMin: 4400000, goldMax: 8860000),
      2320500,
    );
  });
}
