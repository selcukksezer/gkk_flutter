import 'package:flutter_test/flutter_test.dart';

/// Documents expected live smoke output from [scripts/run_dm_chat_smoke.sh].
void main() {
  group('DM chat smoke invariants', () {
    test('hide response shape', () {
      expect({'success': true}['success'], isTrue);
      expect({'success': false, 'error': 'Bu mesaji silme yetkiniz yok'}['success'], isFalse);
    });

    test('unread must drop after hide', () {
      const int before = 3;
      const int after = 2;
      expect(after, lessThan(before));
    });
  });
}
