import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Pulls screenshot bytes from device/emulator to host disk during `flutter drive`.
Future<void> main() async {
  final String outputDir = Platform.environment['AUDIT_SCREENSHOT_DIR'] ??
      'reports/screenshots/audit_${DateTime.now().toIso8601String().substring(0, 10)}';

  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      if (bytes.isEmpty) return false;
      final File file = File('$outputDir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
