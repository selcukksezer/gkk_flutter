import '../../models/guild_model.dart';

String guildRoleLabel(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return 'Lider';
    case GuildRole.officer:
      return 'Subay';
    case GuildRole.member:
      return 'Üye';
  }
}

String guildRoleEmoji(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return '👑';
    case GuildRole.officer:
      return '⭐';
    case GuildRole.member:
      return '🛡️';
  }
}

int guildRoleSortOrder(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return 0;
    case GuildRole.officer:
      return 1;
    case GuildRole.member:
      return 2;
  }
}

String formatGuildCompact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String formatGuildGold(int gold) {
  if (gold >= 1000000) {
    return '${(gold / 1000000).toStringAsFixed(gold % 1000000 == 0 ? 0 : 1)}M';
  }
  if (gold >= 1000) {
    return '${(gold / 1000).toStringAsFixed(gold % 1000 == 0 ? 0 : 1)}K';
  }
  return gold.toString();
}
