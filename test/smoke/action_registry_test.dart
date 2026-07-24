import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/qa/smoke_action_registry.dart';

void main() {
  group('SmokeActionRegistry', () {
    test('P0 navigation targets cover drawer + tabs', () {
      expect(SmokeActionRegistry.p0Count, greaterThanOrEqualTo(30));
      expect(SmokeActionRegistry.fullInventoryActionCount, 350);
    });

    test('every P0 target has route and label', () {
      for (final SmokeActionTarget t in SmokeActionRegistry.p0Navigation) {
        expect(t.route, startsWith('/'));
        expect(t.label, isNotEmpty);
      }
    });

    test('full registry has 350 unique action ids', () {
      final Set<String> ids =
          SmokeActionRegistry.allActions.map((SmokeActionEntry a) => a.id).toSet();
      expect(ids.length, 350);
    });

    test('shardActions partitions full registry', () {
      const int shards = 5;
      final Set<String> seen = <String>{};
      for (int i = 0; i < shards; i++) {
        for (final SmokeActionEntry a in SmokeActionRegistry.shardActions(
          shardIndex: i,
          shardTotal: shards,
        )) {
          expect(seen.add(a.id), true, reason: 'duplicate shard id ${a.id}');
        }
      }
      expect(seen.length, 350);
    });
  });
}
