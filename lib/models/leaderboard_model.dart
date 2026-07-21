class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.value,
    required this.level,
    this.guild,
  });

  final int rank;
  final String username;
  final int value;
  final int level;
  final String? guild;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      username: (json['username'] as String?) ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      guild: json['guild'] as String?,
    );
  }
}

class LeaderboardCategory {
  const LeaderboardCategory({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final String icon;
}

const List<LeaderboardCategory> leaderboardCategories = <LeaderboardCategory>[
  LeaderboardCategory(key: 'gold', label: 'Servet', icon: '💰'),
  LeaderboardCategory(key: 'pvp_rating', label: 'PvP', icon: '⚔️'),
  LeaderboardCategory(key: 'level', label: 'Seviye', icon: '📜'),
  LeaderboardCategory(key: 'power', label: 'Güç', icon: '💪'),
  LeaderboardCategory(key: 'guild_power', label: 'Lonca', icon: '🏰'),
];

abstract final class LeaderboardValueFormatter {
  static String unknown = 'Bilinmiyor';

  static String compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  static String format(int value, String category) {
    switch (category) {
      case 'gold':
        return '🪙 ${compact(value)}';
      case 'level':
        return 'Sv.$value';
      case 'pvp_rating':
        return '${compact(value)} puan';
      case 'guild_power':
        return '${compact(value)} güç';
      default:
        return '${compact(value)} güç';
    }
  }
}
