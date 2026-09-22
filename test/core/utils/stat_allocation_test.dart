import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/stat_allocation.dart';

void main() {
  test('stat point health gain uses multiplier', () {
    expect(statPointHealthGain(0), 0);
    expect(statPointHealthGain(1), 10);
    expect(statPointHealthGain(3), 30);
  });

  test('health preview label', () {
    expect(statPointHealthPreviewLabel(2), '+2 → +20 can');
  });
}
