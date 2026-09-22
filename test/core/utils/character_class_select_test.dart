import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/utils/character_class_select.dart';

void main() {
  test('success == true → success', () {
    expect(
      CharacterClassSelect.interpretResponse(<String, dynamic>{
        'success': true,
        'character_class': 'warrior',
      }),
      CharacterClassSelectOutcome.success,
    );
  });

  test('already selected error → alreadySelected', () {
    expect(
      CharacterClassSelect.interpretResponse(<String, dynamic>{
        'success': false,
        'error': 'Sınıf zaten seçilmiş',
        'selected_class': 'shadow',
      }),
      CharacterClassSelectOutcome.alreadySelected,
    );
  });

  test('non-Map / loose truthy → failed (no silent success)', () {
    expect(
      CharacterClassSelect.interpretResponse('ok'),
      CharacterClassSelectOutcome.failed,
    );
    expect(
      CharacterClassSelect.interpretResponse(<String, dynamic>{
        'success': false,
        'error': 'Geçersiz sınıf',
      }),
      CharacterClassSelectOutcome.failed,
    );
  });

  test('success missing → failed', () {
    expect(
      CharacterClassSelect.interpretResponse(<String, dynamic>{
        'character_class': 'warrior',
      }),
      CharacterClassSelectOutcome.failed,
    );
  });
}
