import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/models/dungeon_siege_model.dart';

void main() {
  test('DungeonSiegeConfig parses siege dungeon ids from list', () {
    final DungeonSiegeConfig config = DungeonSiegeConfig.fromJson(<String, dynamic>{
      'is_enabled': true,
      'slot_count': 6,
      'siege_dungeon_ids': <String>['dng_010', 'dng_020'],
      'rep_bonus_pct': 0.15,
    });

    expect(config.slotCount, 6);
    expect(config.siegeDungeonIds, contains('dng_010'));
    expect(config.repBonusPct, 0.15);
  });

  test('isSiegeDungeon prefers config ids when status provided', () {
    final DungeonSiegeStatus status = DungeonSiegeStatus.fromJson(<String, dynamic>{
      'enabled': true,
      'in_prime_window': true,
      'siege_active': true,
      'is_banned': false,
      'sessions': <dynamic>[],
      'config': <String, dynamic>{
        'is_enabled': true,
        'siege_dungeon_ids': <String>['dng_010'],
      },
    });

    expect(isSiegeDungeon('dng_010', status: status), isTrue);
    expect(isSiegeDungeon('dng_020', status: status), isFalse);
  });
}
