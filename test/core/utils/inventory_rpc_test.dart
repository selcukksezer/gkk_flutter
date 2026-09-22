import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/errors/app_exception.dart';
import 'package:gkk_flutter/core/utils/inventory_rpc.dart';

void main() {
  test('success == true → ok', () {
    expect(
      inventoryRpcSucceeded(
        <String, dynamic>{'success': true},
        fallbackError: 'fail',
      ),
      isTrue,
    );
  });

  test('success == false → throws AppException', () {
    expect(
      () => inventoryRpcSucceeded(
        <String, dynamic>{'success': false, 'error': 'dolu'},
        fallbackError: 'fail',
      ),
      throwsA(
        isA<AppException>().having((AppException e) => e.message, 'message', 'dolu'),
      ),
    );
  });

  test('missing success / non-Map → fail (no silent true)', () {
    expect(
      () => inventoryRpcSucceeded(
        <String, dynamic>{'updated': 1},
        fallbackError: 'fail',
      ),
      throwsA(isA<AppException>()),
    );
    expect(inventoryRpcSuccessFlag('ok'), isFalse);
    expect(inventoryRpcSuccessFlag(<String, dynamic>{'success': true}), isTrue);
    expect(
      inventoryRpcSuccessFlag(<String, dynamic>{'success': false}),
      isFalse,
    );
  });
}
