/// Observation snapshot for live-play agent (Riverpod / SQL marathon).
library;

class GameStateProbeSnapshot {
  const GameStateProbeSnapshot({
    required this.botIndex,
    required this.username,
    this.route,
    this.level,
    this.gold,
    this.gems,
    this.energy,
    this.hp,
    this.maxHp,
    this.guildId,
    this.peerUsername,
    this.availableGoalIds = const <String>[],
    this.raw = const <String, dynamic>{},
  });

  final int botIndex;
  final String username;
  final String? route;
  final int? level;
  final int? gold;
  final int? gems;
  final int? energy;
  final int? hp;
  final int? maxHp;
  final String? guildId;
  final String? peerUsername;
  final List<String> availableGoalIds;
  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'botIndex': botIndex,
        'username': username,
        'route': route,
        'player': <String, dynamic>{
          'level': level,
          'gold': gold,
          'gems': gems,
          'energy': energy,
          'hp': hp,
          'maxHp': maxHp,
        },
        'guildId': guildId,
        'peerUsername': peerUsername,
        'availableGoalIds': availableGoalIds,
        'raw': raw,
      };

  factory GameStateProbeSnapshot.fromMarathonBot(Map<String, dynamic> bot) {
    return GameStateProbeSnapshot(
      botIndex: (bot['bot_index'] as num?)?.toInt() ?? 0,
      username: bot['bot_username']?.toString() ?? '',
      peerUsername: bot['peer_index']?.toString(),
      availableGoalIds: ((bot['steps'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => (e as Map)['id']?.toString() ?? '')
          .where((String s) => s.isNotEmpty)
          .toList(),
      raw: bot,
    );
  }
}

/// Thin probe API — SQL marathon is source of truth for swarm;
/// UI tests can fill [route] + player fields from Riverpod later.
class GameStateProbe {
  const GameStateProbe();

  GameStateProbeSnapshot fromRpcBotResult(Map<String, dynamic> bot) =>
      GameStateProbeSnapshot.fromMarathonBot(bot);
}
