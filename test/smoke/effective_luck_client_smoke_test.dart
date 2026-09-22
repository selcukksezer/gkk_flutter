import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/effective_luck.dart';

void main() {
  group('effective_luck Faz 0', () {
    test('zero equip → zero softcap add', () {
      expect(equipLuckEffective(0), 0);
      expect(effectivePlayerLuck(baseLuck: 84, equipLuckRaw: 0), 84);
    });

    test('whale equip softcaps near +500', () {
      final double eq = equipLuckEffective(45221);
      expect(eq, closeTo(500.0, 0.5));
      expect(
        effectivePlayerLuck(baseLuck: 84, equipLuckRaw: 45221),
        584,
      );
    });

    test('hard ceiling 1500', () {
      expect(
        effectivePlayerLuck(baseLuck: 1200, equipLuckRaw: 100000),
        1500,
      );
    });
  });
}
