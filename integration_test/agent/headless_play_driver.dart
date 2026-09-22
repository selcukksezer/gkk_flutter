/// Headless live-play driver — invokes SQL marathon RPCs (no Flutter UI).
library;

import 'feature_goal_registry.dart';
import 'game_state_probe.dart';
import 'peer_mesh.dart';
import 'rule_policy.dart';

typedef RpcCaller = Future<Map<String, dynamic>> Function(
  String fn,
  Map<String, dynamic> params,
);

class HeadlessPlayDriver {
  HeadlessPlayDriver({
    required this.callRpc,
    this.botCount = 300,
    this.password = 'QaLivePlay300!',
    RulePolicy? policy,
    GameStateProbe? probe,
  })  : policy = policy ?? const RulePolicy(),
        probe = probe ?? const GameStateProbe(),
        mesh = PeerMesh(botCount: botCount);

  final RpcCaller callRpc;
  final int botCount;
  final String password;
  final RulePolicy policy;
  final GameStateProbe probe;
  final PeerMesh mesh;

  Future<Map<String, dynamic>> seed({int count = 300}) async {
    return callRpc('qa_seed_live_play_bots', <String, dynamic>{
      'p_bot_count': count,
    });
  }

  Future<Map<String, dynamic>> wipe() async {
    return callRpc('qa_wipe_live_play_bots', <String, dynamic>{});
  }

  Future<Map<String, dynamic>> runBot(int botIndex) async {
    return callRpc('qa_live_play_run_bot', <String, dynamic>{
      'p_bot_index': botIndex,
    });
  }

  Future<Map<String, dynamic>> runSwarm({
    int from = 1,
    int to = 300,
  }) async {
    return callRpc('qa_live_play_swarm', <String, dynamic>{
      'p_from': from,
      'p_to': to,
    });
  }

  /// Merge SQL marathon steps with registry completeness gaps.
  Map<String, dynamic> enrichCoverage(Map<String, dynamic> swarmResult) {
    final Map<String, dynamic> byGoal = Map<String, dynamic>.from(
      (swarmResult['coverage_by_goal'] as Map<String, dynamic>?) ??
          <String, dynamic>{},
    );
    final List<String> missing = <String>[];
    for (final String id in FeatureGoalRegistry.allIds) {
      if (!byGoal.containsKey(id)) {
        missing.add(id);
        byGoal[id] = <String, dynamic>{'SKIP': swarmResult['bots_total'] ?? 0};
      }
    }
    return <String, dynamic>{
      ...swarmResult,
      'coverage_by_goal': byGoal,
      'registry_goal_count': FeatureGoalRegistry.all.length,
      'goals_not_in_sql_marathon': missing,
      'mesh': mesh.toJson(),
      'allow_all': policy.allowAll,
    };
  }

  GameStateProbeSnapshot probeBot(Map<String, dynamic> botResult) =>
      probe.fromRpcBotResult(botResult);
}
