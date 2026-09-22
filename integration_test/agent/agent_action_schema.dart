/// Action schema for optional UI executor / LLM.
library;

class AgentAction {
  const AgentAction({
    required this.id,
    required this.kind,
    this.route,
    this.label,
    this.text,
    this.safe = true,
  });

  final String id;
  final String kind; // navigate | tap | type_text | provider_call | wait | abort
  final String? route;
  final String? label;
  final String? text;
  final bool safe;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind,
        'route': route,
        'label': label,
        'text': text,
        'safe': safe,
      };
}

class AgentActionResult {
  const AgentActionResult({
    required this.actionId,
    required this.ok,
    this.error,
    this.dtMs,
  });

  final String actionId;
  final bool ok;
  final String? error;
  final int? dtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'actionId': actionId,
        'ok': ok,
        'error': error,
        'dtMs': dtMs,
      };
}
