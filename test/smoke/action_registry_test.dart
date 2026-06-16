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
  });
}
