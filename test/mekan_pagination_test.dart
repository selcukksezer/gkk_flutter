import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/providers/mekan_provider.dart';

void main() {
  test('mekan list default page size is 20', () {
    expect(MekanRepository.defaultPageSize, 20);
  });

  test('pagination offset increments by page size', () {
    const int pageSize = MekanRepository.defaultPageSize;
    int offset = 0;
    final List<int> pageLengths = <int>[20, 20, 7];
    for (final int len in pageLengths) {
      expect(len <= pageSize, isTrue);
      offset += len;
    }
    expect(offset, 47);
    expect(pageLengths.last < pageSize, isTrue);
  });
}
