import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bounded pump — avoids pumpAndSettle hang on infinite animations.
Future<void> smokePump(
  WidgetTester tester, {
  Duration duration = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(duration);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Waits until [finder] appears or [timeout] elapses.
Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

/// Reads dart-define env at test runtime.
class SmokeEnv {
  const SmokeEnv._();

  static String? get email {
    const String fromDefine = String.fromEnvironment('QA_TEST_EMAIL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return null;
  }

  static String? get password {
    const String fromDefine = String.fromEnvironment('QA_TEST_PASSWORD');
    if (fromDefine.isNotEmpty) return fromDefine;
    return null;
  }

  static bool get hasCredentials =>
      (email ?? '').isNotEmpty && (password ?? '').isNotEmpty;

  static void requireCredentials() {
    if (!hasCredentials) {
      fail(
        'QA_TEST_EMAIL and QA_TEST_PASSWORD required. '
        'Run: flutter test integration_test/smoke/... '
        '--dart-define=QA_TEST_EMAIL=... --dart-define=QA_TEST_PASSWORD=...',
      );
    }
  }
}

class SmokeScreenAudit {
  SmokeScreenAudit({
    required this.route,
    required this.interactiveCount,
    required this.hasScaffold,
    this.error,
  });

  final String route;
  final int interactiveCount;
  final bool hasScaffold;
  final String? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'route': route,
        'interactive_count': interactiveCount,
        'has_scaffold': hasScaffold,
        'error': error,
        'status': error == null ? 'pass' : 'fail',
      };
}

class SmokeRunReport {
  SmokeRunReport({required this.runId, required this.testName});

  final String runId;
  final String testName;
  final List<SmokeScreenAudit> screens = <SmokeScreenAudit>[];
  final List<String> failures = <String>[];

  void addScreen(SmokeScreenAudit audit) => screens.add(audit);

  void addFailure(String message) => failures.add(message);

  int get passCount => screens.where((SmokeScreenAudit s) => s.error == null).length;

  int get failCount => screens.where((SmokeScreenAudit s) => s.error != null).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'run_id': runId,
        'test_name': testName,
        'pass': passCount,
        'fail': failCount,
        'failures': failures,
        'screens': screens.map((SmokeScreenAudit s) => s.toJson()).toList(),
      };
}
