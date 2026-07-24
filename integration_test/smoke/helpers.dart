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

  static bool get skipDailyReward {
    const String fromDefine = String.fromEnvironment('QA_SKIP_DAILY_REWARD');
    if (fromDefine == '1' || fromDefine.toLowerCase() == 'true') return true;
    return false;
  }

  /// Optional comma-separated route filter, e.g. `/home,/dungeon`.
  static List<String>? get auditRoutesOnly {
    const String fromDefine = String.fromEnvironment('AUDIT_ROUTES');
    if (fromDefine.isEmpty) return null;
    return fromDefine
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  /// Matrix shard index (0-based) for 350-action audit.
  static int get auditShardIndex {
    const String fromDefine = String.fromEnvironment('AUDIT_SHARD_INDEX');
    if (fromDefine.isEmpty) return 0;
    return int.tryParse(fromDefine) ?? 0;
  }

  /// Total shards — default 1 (no sharding).
  static int get auditShardTotal {
    const String fromDefine = String.fromEnvironment('AUDIT_SHARD_TOTAL');
    if (fromDefine.isEmpty) return 1;
    return int.tryParse(fromDefine) ?? 1;
  }

  /// Round-robin QA account index from comma-separated QA_ACCOUNTS env.
  static int get qaAccountIndex {
    const String fromDefine = String.fromEnvironment('QA_ACCOUNT_INDEX');
    if (fromDefine.isEmpty) return 0;
    return int.tryParse(fromDefine) ?? 0;
  }

  /// Comma-separated email:password pairs (bootstrap script).
  static List<MapEntry<String, String>> get qaAccountPairs {
    const String fromDefine = String.fromEnvironment('QA_ACCOUNTS');
    if (fromDefine.isEmpty) return <MapEntry<String, String>>[];
    final List<MapEntry<String, String>> pairs = <MapEntry<String, String>>[];
    for (final String part in fromDefine.split(',')) {
      final List<String> bits = part.trim().split(':');
      if (bits.length >= 2) {
        pairs.add(MapEntry<String, String>(bits[0].trim(), bits[1].trim()));
      }
    }
    return pairs;
  }

  /// Resolved credentials — QA_ACCOUNTS round-robin or single QA_TEST_*.
  static String? get resolvedEmail {
    final List<MapEntry<String, String>> pairs = qaAccountPairs;
    if (pairs.isNotEmpty) {
      return pairs[qaAccountIndex % pairs.length].key;
    }
    return email;
  }

  static String? get resolvedPassword {
    final List<MapEntry<String, String>> pairs = qaAccountPairs;
    if (pairs.isNotEmpty) {
      return pairs[qaAccountIndex % pairs.length].value;
    }
    return password;
  }

  static bool get hasResolvedCredentials =>
      (resolvedEmail ?? '').isNotEmpty && (resolvedPassword ?? '').isNotEmpty;

  static void requireCredentials() {
    if (!hasResolvedCredentials) {
      fail(
        'QA credentials required (QA_TEST_EMAIL/PASSWORD or QA_ACCOUNTS). '
        'Run: ./scripts/run_full_action_audit.sh',
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

class ActionAuditResult {
  ActionAuditResult({
    required this.actionId,
    required this.coverage,
    required this.status,
    this.route,
    this.error,
    this.skipReason,
  });

  final String actionId;
  final String coverage;
  final String status;
  final String? route;
  final String? error;
  final String? skipReason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'action_id': actionId,
        'coverage': coverage,
        'status': status,
        'route': route,
        'error': error,
        'skip_reason': skipReason,
      };
}

class FullActionAuditReport {
  FullActionAuditReport({
    required this.runId,
    required this.shardIndex,
    required this.shardTotal,
    this.accountEmail,
  });

  final String runId;
  final int shardIndex;
  final int shardTotal;
  final String? accountEmail;
  final List<ActionAuditResult> actions = <ActionAuditResult>[];

  void add(ActionAuditResult result) => actions.add(result);

  int get passCount =>
      actions.where((ActionAuditResult a) => a.status == 'pass').length;

  int get failCount =>
      actions.where((ActionAuditResult a) => a.status == 'fail').length;

  int get skipCount =>
      actions.where((ActionAuditResult a) => a.status == 'skip').length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'run_id': runId,
        'test_name': 'full_action_audit',
        'shard_index': shardIndex,
        'shard_total': shardTotal,
        'account_email': accountEmail,
        'total': actions.length,
        'pass': passCount,
        'fail': failCount,
        'skip': skipCount,
        'auto_tap': actions.where((ActionAuditResult a) => a.coverage == 'auto_tap').length,
        'rpc': actions.where((ActionAuditResult a) => a.coverage == 'rpc').length,
        'actions': actions.map((ActionAuditResult a) => a.toJson()).toList(),
      };
}
