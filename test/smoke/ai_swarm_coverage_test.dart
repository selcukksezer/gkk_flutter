import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/agent/feature_goal_registry.dart';
import '../../integration_test/agent/peer_mesh.dart';
import '../../integration_test/agent/rule_policy.dart';

void main() {
  group('FeatureGoalRegistry', () {
    test('has unique ids and core live-play goals', () {
      final List<String> ids = FeatureGoalRegistry.allIds;
      expect(ids.toSet().length, ids.length);
      expect(ids, contains('guild_create_or_join'));
      expect(ids, contains('dungeon_attack_win'));
      expect(ids, contains('market_list_item'));
      expect(ids, contains('market_buy_listing'));
      expect(ids, contains('chat_dm_send'));
      expect(ids, contains('enhancement_equip_upgraded'));
      expect(ids, contains('guild_monument_donate'));
      expect(ids, contains('guild_war_hub'));
      expect(FeatureGoalRegistry.all.length, greaterThanOrEqualTo(40));
    });
  });

  group('PeerMesh', () {
    test('pairs wrap and guild size 10', () {
      final PeerMesh mesh = PeerMesh(botCount: 300);
      expect(mesh.peerIndex(1), 2);
      expect(mesh.peerIndex(300), 1);
      expect(mesh.guildNumber(1), 1);
      expect(mesh.guildNumber(10), 1);
      expect(mesh.guildNumber(11), 2);
      expect(mesh.isGuildLeader(1), isTrue);
      expect(mesh.isGuildLeader(2), isFalse);
      expect(mesh.usernameFor(7), 'qa_bot_007');
    });
  });

  group('RulePolicy', () {
    test('walks unfinished goals', () {
      const RulePolicy policy = RulePolicy();
      final FeatureGoal? first = policy.nextGoal(
        completedIds: <String>{},
        skippedIds: <String>{},
      );
      expect(first, isNotNull);
      final FeatureGoal? second = policy.nextGoal(
        completedIds: <String>{first!.id},
        skippedIds: <String>{},
      );
      expect(second?.id, isNot(first.id));
    });
  });
}
