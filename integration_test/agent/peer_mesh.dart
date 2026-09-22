/// Peer pairing for 300-bot social mesh.
library;

class PeerMesh {
  const PeerMesh({required this.botCount, this.guildSize = 10});

  final int botCount;
  final int guildSize;

  /// Bot i ↔ bot i+1 (wrap).
  int peerIndex(int botIndex) {
    if (botIndex < 1 || botIndex > botCount) {
      throw ArgumentError('botIndex out of range: $botIndex');
    }
    return botIndex >= botCount ? 1 : botIndex + 1;
  }

  /// 1-based guild number (10 bots each).
  int guildNumber(int botIndex) => 1 + ((botIndex - 1) ~/ guildSize);

  bool isGuildLeader(int botIndex) => ((botIndex - 1) % guildSize) == 0;

  List<int> guildMembers(int guildNumber) {
    final int start = (guildNumber - 1) * guildSize + 1;
    final List<int> out = <int>[];
    for (int i = 0; i < guildSize; i++) {
      final int idx = start + i;
      if (idx > botCount) break;
      out.add(idx);
    }
    return out;
  }

  String emailFor(int botIndex) =>
      'qa_bot_${botIndex.toString().padLeft(3, '0')}@sim.local';

  String usernameFor(int botIndex) =>
      'qa_bot_${botIndex.toString().padLeft(3, '0')}';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'botCount': botCount,
        'guildSize': guildSize,
        'guildCount': (botCount + guildSize - 1) ~/ guildSize,
      };
}
