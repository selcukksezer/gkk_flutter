import 'dart:convert';
import 'dart:io';

/// NDJSON debug log for bugfix UI integration tests (session 02eb2a).
void bugfixUiLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'bugfix-ui',
}) {
  final Map<String, dynamic> entry = <String, dynamic>{
    'sessionId': '02eb2a',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'hypothesisId': hypothesisId,
    'runId': runId,
    if (data != null) 'data': data,
  };
  try {
    File('/Users/selcuk/Documents/gkk-web/gkk_flutter/.cursor/debug-02eb2a.log')
        .writeAsStringSync('${jsonEncode(entry)}\n', mode: FileMode.append);
  } catch (_) {}
}
