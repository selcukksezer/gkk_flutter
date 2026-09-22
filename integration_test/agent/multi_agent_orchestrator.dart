/// Multi-agent social orchestrator notes + pairing helpers.
library;

import 'peer_mesh.dart';

class MultiAgentOrchestrator {
  MultiAgentOrchestrator({required this.mesh});

  final PeerMesh mesh;

  /// Ordered social goals for pair (A,B).
  List<String> pairSocialGoals() => const <String>[
        'friends_send_request',
        'friends_accept',
        'chat_dm_send',
        'chat_dm_reply',
        'market_list_item',
        'market_buy_listing',
        'trade_initiate',
        'trade_confirm',
      ];

  Map<String, dynamic> planForBot(int botIndex) {
    final int peer = mesh.peerIndex(botIndex);
    return <String, dynamic>{
      'bot': mesh.usernameFor(botIndex),
      'peer': mesh.usernameFor(peer),
      'guild': mesh.guildNumber(botIndex),
      'isLeader': mesh.isGuildLeader(botIndex),
      'goals': pairSocialGoals(),
    };
  }
}
