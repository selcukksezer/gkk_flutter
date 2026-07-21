import 'package:flutter/material.dart';

import 'chat_design_system.dart';

enum ChatChannel { global, guild, trade, dm }

extension ChatChannelX on ChatChannel {
  String get key {
    switch (this) {
      case ChatChannel.global:
        return 'global';
      case ChatChannel.guild:
        return 'guild';
      case ChatChannel.trade:
        return 'trade';
      case ChatChannel.dm:
        return 'dm';
    }
  }

  String get label {
    switch (this) {
      case ChatChannel.global:
        return 'Genel';
      case ChatChannel.guild:
        return 'Lonca';
      case ChatChannel.trade:
        return 'Pazar';
      case ChatChannel.dm:
        return 'Özel';
    }
  }

  Color get accentColor {
    switch (this) {
      case ChatChannel.global:
        return ChatDesignSystem.colorGlobalAccent;
      case ChatChannel.guild:
        return ChatDesignSystem.colorGuildAccent;
      case ChatChannel.trade:
        return ChatDesignSystem.colorTradeAccent;
      case ChatChannel.dm:
        return ChatDesignSystem.colorDmAccent;
    }
  }

  LinearGradient get gradient {
    switch (this) {
      case ChatChannel.global:
        return ChatDesignSystem.gradientGlobal;
      case ChatChannel.guild:
        return ChatDesignSystem.gradientGuild;
      case ChatChannel.trade:
        return ChatDesignSystem.gradientTrade;
      case ChatChannel.dm:
        return ChatDesignSystem.gradientDm;
    }
  }

  static ChatChannel fromKey(String value) {
    switch (value) {
      case 'guild':
        return ChatChannel.guild;
      case 'trade':
        return ChatChannel.trade;
      case 'dm':
        return ChatChannel.dm;
      case 'global':
      default:
        return ChatChannel.global;
    }
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channel,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isSystem,
    this.recipientUserId,
    this.guildId,
    this.deletedAt,
    this.senderIsOnline,
  });

  final String id;
  final ChatChannel channel;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isSystem;
  final String? recipientUserId;
  final String? guildId;
  final String? deletedAt;
  final bool? senderIsOnline;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final String rawChannel = (json['channel']?.toString() ?? 'global').toLowerCase();
    final String ts = json['created_at']?.toString() ?? json['timestamp']?.toString() ?? DateTime.now().toIso8601String();

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      channel: ChatChannelX.fromKey(rawChannel),
      senderId: (json['sender_user_id'] ?? json['sender_id'] ?? json['user_id'] ?? json['author_id'])?.toString() ?? '',
      senderName: (json['sender_name'] ?? json['sender_username'] ?? json['username'] ?? json['user_name'])?.toString() ?? 'Oyuncu',
      content: (json['content'] ?? json['message'])?.toString() ?? '',
      timestamp: DateTime.tryParse(ts)?.toLocal() ?? DateTime.now(),
      isSystem: (json['is_system'] as bool?) ?? false,
      recipientUserId: json['recipient_user_id']?.toString(),
      guildId: json['guild_id']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
      senderIsOnline: json['sender_is_online'] as bool?,
    );
  }
}

class ChatUserSummary {
  const ChatUserSummary({
    required this.id,
    required this.username,
    this.displayName,
    this.isOnline,
  });

  final String id;
  final String username;
  final String? displayName;
  final bool? isOnline;

  factory ChatUserSummary.fromJson(Map<String, dynamic> json) => ChatUserSummary(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? 'oyuncu',
        displayName: json['display_name']?.toString(),
        isOnline: json['is_online'] as bool?,
      );
}

class ChatDmConversation {
  const ChatDmConversation({
    required this.peerUserId,
    required this.peerUsername,
    required this.lastMessageContent,
    required this.lastMessageAt,
    required this.unreadCount,
    this.peerDisplayName,
    this.peerIsOnline,
  });

  final String peerUserId;
  final String peerUsername;
  final String? peerDisplayName;
  final String lastMessageContent;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool? peerIsOnline;

  factory ChatDmConversation.fromJson(Map<String, dynamic> json) {
    final DateTime ts = DateTime.tryParse(json['last_message_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    return ChatDmConversation(
      peerUserId: json['peer_user_id']?.toString() ?? '',
      peerUsername: json['peer_username']?.toString() ?? 'oyuncu',
      peerDisplayName: json['peer_display_name']?.toString(),
      lastMessageContent: json['last_message_content']?.toString() ?? '',
      lastMessageAt: ts,
      unreadCount: ((json['unread_count'] as num?) ?? 0).toInt().clamp(0, 99),
      peerIsOnline: json['peer_is_online'] as bool?,
    );
  }
}

class BlockedChatUser {
  const BlockedChatUser({
    required this.id,
    required this.username,
    this.displayName,
  });

  final String id;
  final String username;
  final String? displayName;

  factory BlockedChatUser.fromJson(Map<String, dynamic> json) => BlockedChatUser(
        id: (json['blocked_user_id'] ?? json['id'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        displayName: json['display_name']?.toString(),
      );
}

class ChatFilter {
  const ChatFilter({
    required this.id,
    required this.term,
    required this.replacement,
    required this.scope,
  });

  final String id;
  final String term;
  final String replacement;
  final String scope;

  factory ChatFilter.fromJson(Map<String, dynamic> json) => ChatFilter(
        id: json['id']?.toString() ?? '',
        term: json['term']?.toString() ?? '',
        replacement: json['replacement']?.toString() ?? '***',
        scope: json['scope']?.toString() ?? 'channel',
      );
}

class ChatBan {
  const ChatBan({
    required this.reason,
    required this.expiresAt,
    required this.scope,
    this.channel,
  });

  final String reason;
  final DateTime expiresAt;
  final String scope;
  final String? channel;

  factory ChatBan.fromJson(Map<String, dynamic> json) => ChatBan(
        reason: json['reason']?.toString() ?? 'Sohbet erişimi kısıtlandı.',
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        scope: json['scope']?.toString() ?? 'channel',
        channel: json['channel']?.toString(),
      );
}

class ChatPermissions {
  const ChatPermissions({
    required this.canDelete,
    required this.canBan,
    required this.canManageFilters,
    required this.canManageModerators,
  });

  final bool canDelete;
  final bool canBan;
  final bool canManageFilters;
  final bool canManageModerators;

  factory ChatPermissions.fromJson(Map<String, dynamic>? json) => ChatPermissions(
        canDelete: (json?['can_delete'] as bool?) ?? false,
        canBan: (json?['can_ban'] as bool?) ?? false,
        canManageFilters: (json?['can_manage_filters'] as bool?) ?? false,
        canManageModerators: (json?['can_manage_moderators'] as bool?) ?? false,
      );
}

class ChatModerationState {
  const ChatModerationState({
    required this.channel,
    required this.filters,
    required this.activeBans,
    required this.permissions,
  });

  final ChatChannel channel;
  final List<ChatFilter> filters;
  final List<ChatBan> activeBans;
  final ChatPermissions permissions;

  factory ChatModerationState.empty(ChatChannel channel) => ChatModerationState(
        channel: channel,
        filters: const <ChatFilter>[],
        activeBans: const <ChatBan>[],
        permissions: ChatPermissions.fromJson(null),
      );

  factory ChatModerationState.fromJson(ChatChannel channel, Map<String, dynamic>? json) {
    final List<dynamic> rawFilters = (json?['filters'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> rawBans = (json?['active_bans'] as List<dynamic>?) ?? <dynamic>[];

    return ChatModerationState(
      channel: channel,
      filters: rawFilters.whereType<Map>().map((Map f) => ChatFilter.fromJson(Map<String, dynamic>.from(f))).toList(growable: false),
      activeBans: rawBans.whereType<Map>().map((Map b) => ChatBan.fromJson(Map<String, dynamic>.from(b))).toList(growable: false),
      permissions: ChatPermissions.fromJson((json?['permissions'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

String formatChatTime(DateTime dt) {
  final String hh = dt.hour.toString().padLeft(2, '0');
  final String mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
