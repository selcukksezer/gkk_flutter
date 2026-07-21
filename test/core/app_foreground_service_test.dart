import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/services/app_foreground_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppForegroundService starts in foreground', () {
    AppForegroundService.instance.start();
    expect(AppForegroundService.instance.isForeground, isTrue);
  });
}
