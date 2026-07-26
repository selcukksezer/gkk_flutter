import 'dart:convert';
import 'dart:io';

/// Debug-mode NDJSON logger for staff hub audit (session a3bc69).
abstract final class StaffHubDebugLog {
  static const String _logPath =
      '/Users/selcuk/Documents/gkk-web/gkk_flutter/.cursor/debug-a3bc69.log';
  static const String _sessionId = 'a3bc69';

  static void log(
    String hypothesisId,
    String location,
    String message, {
    Map<String, Object?> data = const <String, Object?>{},
    String runId = 'staff-audit',
  }) {
    // #region agent log
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'sessionId': _sessionId,
        'runId': runId,
        'hypothesisId': hypothesisId,
        'location': location,
        'message': message,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      File(_logPath).writeAsStringSync(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    // ignore: avoid_print
    print('[DEBUG-a3bc69][$hypothesisId] $message ${jsonEncode(data)}');
    // #endregion
  }
}
