/// Optional OpenAI-compatible LLM client (Ollama default). Sample use only.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

class LlmClient {
  LlmClient({
    Dio? dio,
    this.baseUrl = 'http://127.0.0.1:11434/v1',
    this.model = 'llama3.2',
    this.apiKey,
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final String baseUrl;
  final String model;
  final String? apiKey;

  /// Returns actionId from availableGoalIds, or null on failure.
  Future<String?> decideGoal({
    required Map<String, dynamic> observation,
    required List<String> availableGoalIds,
  }) async {
    if (availableGoalIds.isEmpty) return null;
    try {
      final Response<dynamic> res = await _dio.post<dynamic>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: <String, dynamic>{
            if (apiKey != null && apiKey!.isNotEmpty)
              'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: <String, dynamic>{
          'model': model,
          'temperature': 0,
          'messages': <Map<String, String>>[
            <String, String>{
              'role': 'system',
              'content':
                  'Pick exactly one goal id from availableGoalIds. Reply JSON: {"actionId":"..."}',
            },
            <String, String>{
              'role': 'user',
              'content': jsonEncode(<String, dynamic>{
                'observation': observation,
                'availableGoalIds': availableGoalIds,
              }),
            },
          ],
        },
      );
      final dynamic content =
          res.data?['choices']?[0]?['message']?['content'];
      if (content is! String) return availableGoalIds.first;
      final Map<String, dynamic> parsed =
          jsonDecode(content) as Map<String, dynamic>;
      final String? id = parsed['actionId']?.toString();
      if (id != null && availableGoalIds.contains(id)) return id;
      return availableGoalIds.first;
    } catch (_) {
      return availableGoalIds.first;
    }
  }
}
