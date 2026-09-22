/// Rule policy: pick next FeatureGoal without LLM (primary for 300 swarm).
library;

import 'feature_goal_registry.dart';

class RulePolicy {
  const RulePolicy();

  /// Prefer unfinished goals in registry order; skip already done.
  FeatureGoal? nextGoal({
    required Set<String> completedIds,
    required Set<String> skippedIds,
    bool allowPeerGoals = true,
  }) {
    for (final FeatureGoal g in FeatureGoalRegistry.all) {
      if (completedIds.contains(g.id) || skippedIds.contains(g.id)) continue;
      if (g.needsPeer && !allowPeerGoals) continue;
      return g;
    }
    return null;
  }

  bool get allowAll => true;
}
