/// Thin live-play agent loop (rule_policy primary; LLM optional sample).
library;

import 'feature_goal_registry.dart';
import 'headless_play_driver.dart';
import 'llm_client.dart';
import 'rule_policy.dart';

class LivePlayAgent {
  LivePlayAgent({
    required this.driver,
    this.llm,
    this.llmSampleRate = 0.0,
    RulePolicy? policy,
  }) : policy = policy ?? const RulePolicy();

  final HeadlessPlayDriver driver;
  final LlmClient? llm;
  final double llmSampleRate;
  final RulePolicy policy;

  Future<Map<String, dynamic>> runMarathonBot(int botIndex) =>
      driver.runBot(botIndex);

  Future<Map<String, dynamic>> runSwarm({int from = 1, int to = 300}) async {
    final Map<String, dynamic> raw = await driver.runSwarm(from: from, to: to);
    return driver.enrichCoverage(raw);
  }

  Future<String?> maybeLlmPick({
    required Map<String, dynamic> obs,
    required List<String> available,
    required int botIndex,
  }) async {
    if (llm == null || llmSampleRate <= 0) return null;
    if ((botIndex % 100) / 100.0 > llmSampleRate) return null;
    return llm!.decideGoal(observation: obs, availableGoalIds: available);
  }

  FeatureGoal? nextRuleGoal(Set<String> done, Set<String> skipped) =>
      policy.nextGoal(completedIds: done, skippedIds: skipped);
}
