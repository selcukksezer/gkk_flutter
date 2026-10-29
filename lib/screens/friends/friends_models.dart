import 'package:flutter/foundation.dart';

@immutable
class FriendEntry {
  const FriendEntry({
    required this.friendshipId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.level = 1,
    this.power = 0,
    this.isOnline = false,
    this.characterClass,
    this.location,
    this.guildName,
    this.activityStatus,
    this.createdAt,
  });

  final String friendshipId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final int power;
  final bool isOnline;
  final String? characterClass;
  final String? location;
  final String? guildName;
  final String? activityStatus;
  final DateTime? createdAt;

  String get name =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : username;

  factory FriendEntry.fromJson(Map<String, dynamic> json) {
    final bool online = json['is_online'] == true;
    final String? rawLoc = json['location']?.toString();
    return FriendEntry(
      friendshipId: (json['friendship_id'] ?? json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      power: (json['power'] as num?)?.toInt() ?? 0,
      isOnline: online,
      characterClass: json['character_class']?.toString(),
      location: rawLoc ?? (online ? 'Sanctum Tapınağı' : 'Çevrimdışı'),
      guildName: json['guild_name']?.toString(),
      activityStatus: json['activity_status']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'friendship_id': friendshipId,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'level': level,
        'power': power,
        'is_online': isOnline,
        'character_class': characterClass,
        'location': location,
        'guild_name': guildName,
        'activity_status': activityStatus,
        'created_at': createdAt?.toIso8601String(),
      };
}

@immutable
class PlayerSearchResult {
  const PlayerSearchResult({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.level = 1,
    this.power = 0,
    this.isOnline = false,
    this.characterClass,
    this.isFriend = false,
    this.hasPendingOutgoing = false,
    this.hasPendingIncoming = false,
    this.isBlocked = false,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final int power;
  final bool isOnline;
  final String? characterClass;
  final bool isFriend;
  final bool hasPendingOutgoing;
  final bool hasPendingIncoming;
  final bool isBlocked;

  String get name =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : username;

  factory PlayerSearchResult.fromJson(Map<String, dynamic> json) {
    return PlayerSearchResult(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      power: (json['power'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] == true,
      characterClass: json['character_class']?.toString(),
      isFriend: json['is_friend'] == true,
      hasPendingOutgoing: json['has_pending_outgoing'] == true,
      hasPendingIncoming: json['has_pending_incoming'] == true,
      isBlocked: json['is_blocked'] == true,
    );
  }

  PlayerSearchResult copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    int? level,
    int? power,
    bool? isOnline,
    String? characterClass,
    bool? isFriend,
    bool? hasPendingOutgoing,
    bool? hasPendingIncoming,
    bool? isBlocked,
  }) {
    return PlayerSearchResult(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      level: level ?? this.level,
      power: power ?? this.power,
      isOnline: isOnline ?? this.isOnline,
      characterClass: characterClass ?? this.characterClass,
      isFriend: isFriend ?? this.isFriend,
      hasPendingOutgoing: hasPendingOutgoing ?? this.hasPendingOutgoing,
      hasPendingIncoming: hasPendingIncoming ?? this.hasPendingIncoming,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}

@immutable
class BlockedPlayerEntry {
  const BlockedPlayerEntry({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.blockedAt,
    this.reason,
    this.level = 1,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? blockedAt;
  final String? reason;
  final int level;

  String get name =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : username;

  factory BlockedPlayerEntry.fromJson(Map<String, dynamic> json) {
    return BlockedPlayerEntry(
      id: (json['blocked_user_id'] ?? json['id'] ?? json['user_id'] ?? '').toString(),
      username: (json['username'] ?? 'oyuncu').toString(),
      displayName: json['display_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      blockedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      reason: json['reason']?.toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'created_at': blockedAt?.toIso8601String(),
        'reason': reason,
        'level': level,
      };
}
