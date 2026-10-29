import 'package:flutter/material.dart';

import 'chat_design_system.dart';

enum ChatChannel { global, guild, party, dm, system, trade }

extension ChatChannelX on ChatChannel {
  String get key {
    switch (this) {
      case ChatChannel.global:
        return 'global';
      case ChatChannel.guild:
        return 'guild';
      case ChatChannel.party:
        return 'party';
      case ChatChannel.dm:
        return 'dm';
      case ChatChannel.system:
        return 'system';
      case ChatChannel.trade:
        return 'trade';
    }
  }

  String get label {
    switch (this) {
      case ChatChannel.global:
        return 'Dünya';
      case ChatChannel.guild:
        return 'Lonca';
      case ChatChannel.party:
        return 'Grup';
      case ChatChannel.dm:
        return 'Fısıltı';
      case ChatChannel.system:
        return 'Sistem';
      case ChatChannel.trade:
        return 'Pazar';
    }
  }

  String get tag {
    switch (this) {
      case ChatChannel.global:
        return '[DÜNYA]';
      case ChatChannel.guild:
        return '[LONCA]';
      case ChatChannel.party:
        return '[GRUP]';
      case ChatChannel.dm:
        return '[FISILTI]';
      case ChatChannel.system:
        return '[SİSTEM]';
      case ChatChannel.trade:
        return '[PAZAR]';
    }
  }

  IconData get icon {
    switch (this) {
      case ChatChannel.global:
        return Icons.public_rounded;
      case ChatChannel.guild:
        return Icons.shield_rounded;
      case ChatChannel.party:
        return Icons.group_rounded;
      case ChatChannel.dm:
        return Icons.forum_rounded;
      case ChatChannel.system:
        return Icons.campaign_rounded;
      case ChatChannel.trade:
        return Icons.currency_exchange_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case ChatChannel.global:
        return ChatDesignSystem.colorGlobalAccent;
      case ChatChannel.guild:
        return ChatDesignSystem.colorGuildAccent;
      case ChatChannel.party:
        return ChatDesignSystem.colorPartyAccent;
      case ChatChannel.dm:
        return ChatDesignSystem.colorDmAccent;
      case ChatChannel.system:
        return ChatDesignSystem.colorSystemAccent;
      case ChatChannel.trade:
        return ChatDesignSystem.colorTradeAccent;
    }
  }

  LinearGradient get gradient {
    switch (this) {
      case ChatChannel.global:
        return ChatDesignSystem.gradientGlobal;
      case ChatChannel.guild:
        return ChatDesignSystem.gradientGuild;
      case ChatChannel.party:
        return ChatDesignSystem.gradientParty;
      case ChatChannel.dm:
        return ChatDesignSystem.gradientDm;
      case ChatChannel.system:
        return ChatDesignSystem.gradientSystem;
      case ChatChannel.trade:
        return ChatDesignSystem.gradientTrade;
    }
  }

  static ChatChannel fromKey(String value) {
    switch (value.toLowerCase().trim()) {
      case 'guild':
        return ChatChannel.guild;
      case 'party':
      case 'grup':
        return ChatChannel.party;
      case 'whisper':
      case 'dm':
      case 'pm':
        return ChatChannel.dm;
      case 'system':
      case 'sistem':
        return ChatChannel.system;
      case 'trade':
      case 'pazar':
        return ChatChannel.trade;
      case 'world':
      case 'global':
      default:
        return ChatChannel.global;
    }
  }
}

enum ChatFaction { elyos, asmodian, neutral }

extension ChatFactionX on ChatFaction {
  String get key {
    switch (this) {
      case ChatFaction.elyos:
        return 'elyos';
      case ChatFaction.asmodian:
        return 'asmodian';
      case ChatFaction.neutral:
        return 'neutral';
    }
  }

  String get factionName {
    switch (this) {
      case ChatFaction.elyos:
        return 'Elyos';
      case ChatFaction.asmodian:
        return 'Asmodian';
      case ChatFaction.neutral:
        return 'Tarafsız';
    }
  }

  String get title {
    switch (this) {
      case ChatFaction.elyos:
        return 'Gökkanat Muhafızı';
      case ChatFaction.asmodian:
        return 'Gölgepençe Akıncısı';
      case ChatFaction.neutral:
        return 'Bağımsız Savaşçı';
    }
  }

  Color get color {
    switch (this) {
      case ChatFaction.elyos:
        return const Color(0xFFFBBF24);
      case ChatFaction.asmodian:
        return const Color(0xFFA855F7);
      case ChatFaction.neutral:
        return const Color(0xFF06B6D4);
    }
  }

  IconData get icon {
    switch (this) {
      case ChatFaction.elyos:
        return Icons.wb_sunny_rounded;
      case ChatFaction.asmodian:
        return Icons.nights_stay_rounded;
      case ChatFaction.neutral:
        return Icons.shield_rounded;
    }
  }

  String get rune {
    switch (this) {
      case ChatFaction.elyos:
        return 'ᛟ';
      case ChatFaction.asmodian:
        return 'ᛉ';
      case ChatFaction.neutral:
        return 'ᚱ';
    }
  }

  static ChatFaction? fromKey(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'elyos':
      case 'celestial':
      case 'light':
        return ChatFaction.elyos;
      case 'asmodian':
      case 'shadow':
      case 'dark':
        return ChatFaction.asmodian;
      case 'neutral':
      case 'guardian':
        return ChatFaction.neutral;
      default:
        return null;
    }
  }
}

enum ChatCharacterClass {
  gladiator,
  templar,
  assassin,
  ranger,
  sorcerer,
  spiritmaster,
  cleric,
  chanter,
}

extension ChatCharacterClassX on ChatCharacterClass {
  String get key => name;

  String get label {
    switch (this) {
      case ChatCharacterClass.gladiator:
        return 'Gladyatör';
      case ChatCharacterClass.templar:
        return 'Muhafız';
      case ChatCharacterClass.assassin:
        return 'Suikastçı';
      case ChatCharacterClass.ranger:
        return 'Korucu';
      case ChatCharacterClass.sorcerer:
        return 'Büyücü';
      case ChatCharacterClass.spiritmaster:
        return 'Ruh Çağırıcı';
      case ChatCharacterClass.cleric:
        return 'Rahip';
      case ChatCharacterClass.chanter:
        return 'Şaman';
    }
  }

  String get role {
    switch (this) {
      case ChatCharacterClass.gladiator:
        return 'Fiziksel Ağır DPS';
      case ChatCharacterClass.templar:
        return 'Savunma Tankı';
      case ChatCharacterClass.assassin:
        return 'Gölge Suikastçısı';
      case ChatCharacterClass.ranger:
        return 'Menzilli Avcı';
      case ChatCharacterClass.sorcerer:
        return 'Elementel Yıkım';
      case ChatCharacterClass.spiritmaster:
        return 'Aether Kontrolcüsü';
      case ChatCharacterClass.cleric:
        return 'İlahi İyileştirici';
      case ChatCharacterClass.chanter:
        return 'Mantra Destekçisi';
    }
  }

  Color get accentColor {
    switch (this) {
      case ChatCharacterClass.gladiator:
        return const Color(0xFFEF4444);
      case ChatCharacterClass.templar:
        return const Color(0xFF3B82F6);
      case ChatCharacterClass.assassin:
        return const Color(0xFF8B5CF6);
      case ChatCharacterClass.ranger:
        return const Color(0xFF10B981);
      case ChatCharacterClass.sorcerer:
        return const Color(0xFFEC4899);
      case ChatCharacterClass.spiritmaster:
        return const Color(0xFF06B6D4);
      case ChatCharacterClass.cleric:
        return const Color(0xFFF59E0B);
      case ChatCharacterClass.chanter:
        return const Color(0xFF14B8A6);
    }
  }

  IconData get icon {
    switch (this) {
      case ChatCharacterClass.gladiator:
        return Icons.colorize_rounded;
      case ChatCharacterClass.templar:
        return Icons.security_rounded;
      case ChatCharacterClass.assassin:
        return Icons.flash_on_rounded;
      case ChatCharacterClass.ranger:
        return Icons.explore_rounded;
      case ChatCharacterClass.sorcerer:
        return Icons.auto_awesome_rounded;
      case ChatCharacterClass.spiritmaster:
        return Icons.psychology_rounded;
      case ChatCharacterClass.cleric:
        return Icons.health_and_safety_rounded;
      case ChatCharacterClass.chanter:
        return Icons.record_voice_over_rounded;
    }
  }

  static ChatCharacterClass? fromKey(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'gladiator':
      case 'warrior':
      case 'savasci':
        return ChatCharacterClass.gladiator;
      case 'templar':
      case 'knight':
      case 'muhafiz':
        return ChatCharacterClass.templar;
      case 'assassin':
      case 'rogue':
      case 'suikastci':
        return ChatCharacterClass.assassin;
      case 'ranger':
      case 'archer':
      case 'korucu':
        return ChatCharacterClass.ranger;
      case 'sorcerer':
      case 'mage':
      case 'wizard':
      case 'buyucu':
        return ChatCharacterClass.sorcerer;
      case 'spiritmaster':
      case 'summoner':
      case 'ruh':
        return ChatCharacterClass.spiritmaster;
      case 'cleric':
      case 'priest':
      case 'healer':
      case 'rahip':
        return ChatCharacterClass.cleric;
      case 'chanter':
      case 'bard':
      case 'saman':
        return ChatCharacterClass.chanter;
      default:
        return null;
    }
  }
}

enum ChatItemRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  mythic,
}

extension ChatItemRarityX on ChatItemRarity {
  String get label {
    switch (this) {
      case ChatItemRarity.common:
        return 'Yaygın';
      case ChatItemRarity.uncommon:
        return 'Sıradışı';
      case ChatItemRarity.rare:
        return 'Nadir';
      case ChatItemRarity.epic:
        return 'Epik';
      case ChatItemRarity.legendary:
        return 'Efsanevi';
      case ChatItemRarity.mythic:
        return 'Mitik';
    }
  }

  Color get color {
    switch (this) {
      case ChatItemRarity.common:
        return const Color(0xFF94A3B8);
      case ChatItemRarity.uncommon:
        return const Color(0xFF10B981);
      case ChatItemRarity.rare:
        return const Color(0xFF38BDF8);
      case ChatItemRarity.epic:
        return const Color(0xFFA855F7);
      case ChatItemRarity.legendary:
        return const Color(0xFFF59E0B);
      case ChatItemRarity.mythic:
        return const Color(0xFFF43F5E);
    }
  }

  LinearGradient get gradient {
    return LinearGradient(
      colors: <Color>[
        color.withValues(alpha: 0.28),
        color.withValues(alpha: 0.08),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static ChatItemRarity fromString(String? val) {
    if (val == null) return ChatItemRarity.common;
    switch (val.toLowerCase().trim()) {
      case 'mythic':
      case 'mitik':
        return ChatItemRarity.mythic;
      case 'legendary':
      case 'efsanevi':
        return ChatItemRarity.legendary;
      case 'epic':
      case 'epik':
        return ChatItemRarity.epic;
      case 'rare':
      case 'nadir':
        return ChatItemRarity.rare;
      case 'uncommon':
      case 'siradisi':
      case 'sıradışı':
        return ChatItemRarity.uncommon;
      case 'common':
      case 'yaygin':
      case 'yaygın':
      default:
        return ChatItemRarity.common;
    }
  }
}

class ChatItemLink {
  const ChatItemLink({
    required this.id,
    required this.name,
    this.rarity = ChatItemRarity.rare,
    this.enhancementLevel = 0,
    this.requiredLevel = 50,
    this.itemType = 'Silah',
    this.attack = 0,
    this.defense = 0,
    this.magicPower = 0,
    this.criticalRate = 0,
    this.description = '',
    this.isTradeable = true,
    this.sockets = const <String>[],
  });

  final String id;
  final String name;
  final ChatItemRarity rarity;
  final int enhancementLevel;
  final int requiredLevel;
  final String itemType;
  final int attack;
  final int defense;
  final int magicPower;
  final int criticalRate;
  final String description;
  final bool isTradeable;
  final List<String> sockets;

  String get displayName =>
      enhancementLevel > 0 ? '+$enhancementLevel $name' : name;

  String get tag => '[$displayName]';

  factory ChatItemLink.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSockets = (json['sockets'] as List<dynamic>?) ?? <dynamic>[];
    return ChatItemLink(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Bilinmeyen Eşya',
      rarity: ChatItemRarityX.fromString(json['rarity']?.toString()),
      enhancementLevel: ((json['enhancement_level'] ?? json['enhancement']) as num?)?.toInt() ?? 0,
      requiredLevel: ((json['required_level'] ?? json['level']) as num?)?.toInt() ?? 1,
      itemType: json['item_type']?.toString() ?? json['type']?.toString() ?? 'Ekipman',
      attack: ((json['attack'] ?? json['atk']) as num?)?.toInt() ?? 0,
      defense: ((json['defense'] ?? json['def']) as num?)?.toInt() ?? 0,
      magicPower: ((json['magic_power'] ?? json['matk']) as num?)?.toInt() ?? 0,
      criticalRate: ((json['critical_rate'] ?? json['crit']) as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
      isTradeable: (json['is_tradeable'] as bool?) ?? true,
      sockets: rawSockets.map((s) => s.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'rarity': rarity.name,
        'enhancement_level': enhancementLevel,
        'required_level': requiredLevel,
        'item_type': itemType,
        'attack': attack,
        'defense': defense,
        'magic_power': magicPower,
        'critical_rate': criticalRate,
        'description': description,
        'is_tradeable': isTradeable,
        'sockets': sockets,
      };

  /// Parses `[item:id:name:rarity:enhancement:level:type]` or returns null.
  static ChatItemLink? tryParseTag(String rawTag) {
    final RegExp reg = RegExp(r'^\[item:([^:]+):([^:]+)(?::([^:]+))?(?::([^:]+))?(?::([^:]+))?(?::([^:]+))?\]$');
    final RegExpMatch? m = reg.firstMatch(rawTag);
    if (m == null) return null;
    final String id = m.group(1)!;
    final String name = m.group(2)!;
    final String rarityStr = m.group(3) ?? 'rare';
    final int enhancement = int.tryParse(m.group(4) ?? '0') ?? 0;
    final int level = int.tryParse(m.group(5) ?? '50') ?? 50;
    final String type = m.group(6) ?? 'Silah';

    return ChatItemLink(
      id: id,
      name: name,
      rarity: ChatItemRarityX.fromString(rarityStr),
      enhancementLevel: enhancement,
      requiredLevel: level,
      itemType: type,
    );
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
    this.senderStaffBadge,
    this.senderKingBadge,
    this.senderGuildName,
    this.senderAuthId,
    this.systemTone,
    this.senderClass,
    this.senderFaction,
    this.senderLevel,
    this.senderAvatarUrl,
    this.itemLinks,
    this.metadata,
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
  final String? senderStaffBadge;
  final String? senderKingBadge;
  final String? senderGuildName;
  final String? senderAuthId;
  /// System announcement styling: `success` | `danger` | `warning` | null (info).
  final String? systemTone;
  final ChatCharacterClass? senderClass;
  final ChatFaction? senderFaction;
  final int? senderLevel;
  final String? senderAvatarUrl;
  final List<ChatItemLink>? itemLinks;
  final Map<String, dynamic>? metadata;

  bool get isDeleted => deletedAt != null && deletedAt!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final String rawChannel = (json['channel']?.toString() ?? 'global').toLowerCase();
    final String ts = json['created_at']?.toString() ?? json['timestamp']?.toString() ?? DateTime.now().toIso8601String();
    final dynamic metaRaw = json['metadata'];
    final Map<String, dynamic>? meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : null;

    final String contentStr = (json['content'] ?? json['message'])?.toString() ?? '';
    final List<ChatItemLink> parsedLinks = _parseItemLinks(json, meta, contentStr);

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      channel: ChatChannelX.fromKey(rawChannel),
      senderId: (json['sender_user_id'] ?? json['sender_id'] ?? json['user_id'] ?? json['author_id'])?.toString() ?? '',
      senderName: (json['sender_name'] ?? json['sender_username'] ?? json['username'] ?? json['user_name'])?.toString() ?? 'Oyuncu',
      content: contentStr,
      timestamp: DateTime.tryParse(ts)?.toLocal() ?? DateTime.now(),
      isSystem: (json['is_system'] as bool?) ?? false,
      recipientUserId: json['recipient_user_id']?.toString(),
      guildId: json['guild_id']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
      senderIsOnline: json['sender_is_online'] as bool?,
      senderStaffBadge: json['sender_staff_badge']?.toString(),
      senderKingBadge: json['sender_king_badge']?.toString(),
      senderGuildName: _parseSenderGuildName(json),
      senderAuthId: json['sender_auth_id']?.toString(),
      systemTone: _parseSystemTone(json),
      senderClass: _parseSenderClass(json, meta),
      senderFaction: _parseSenderFaction(json, meta),
      senderLevel: _parseSenderLevel(json, meta),
      senderAvatarUrl: json['sender_avatar_url']?.toString() ?? meta?['avatar_url']?.toString(),
      itemLinks: parsedLinks.isEmpty ? null : parsedLinks,
      metadata: meta,
    );
  }

  ChatMessage copyWith({
    String? id,
    ChatChannel? channel,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    bool? isSystem,
    String? recipientUserId,
    String? guildId,
    String? deletedAt,
    bool? senderIsOnline,
    String? senderStaffBadge,
    String? senderKingBadge,
    String? senderGuildName,
    String? senderAuthId,
    String? systemTone,
    ChatCharacterClass? senderClass,
    ChatFaction? senderFaction,
    int? senderLevel,
    String? senderAvatarUrl,
    List<ChatItemLink>? itemLinks,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      channel: channel ?? this.channel,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isSystem: isSystem ?? this.isSystem,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      guildId: guildId ?? this.guildId,
      deletedAt: deletedAt ?? this.deletedAt,
      senderIsOnline: senderIsOnline ?? this.senderIsOnline,
      senderStaffBadge: senderStaffBadge ?? this.senderStaffBadge,
      senderKingBadge: senderKingBadge ?? this.senderKingBadge,
      senderGuildName: senderGuildName ?? this.senderGuildName,
      senderAuthId: senderAuthId ?? this.senderAuthId,
      systemTone: systemTone ?? this.systemTone,
      senderClass: senderClass ?? this.senderClass,
      senderFaction: senderFaction ?? this.senderFaction,
      senderLevel: senderLevel ?? this.senderLevel,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      itemLinks: itemLinks ?? this.itemLinks,
      metadata: metadata ?? this.metadata,
    );
  }

  static ChatCharacterClass? _parseSenderClass(Map<String, dynamic> json, Map<String, dynamic>? meta) {
    final String? val = json['sender_class']?.toString() ??
        json['class']?.toString() ??
        meta?['class']?.toString() ??
        meta?['sender_class']?.toString();
    return ChatCharacterClassX.fromKey(val);
  }

  static ChatFaction? _parseSenderFaction(Map<String, dynamic> json, Map<String, dynamic>? meta) {
    final String? val = json['sender_faction']?.toString() ??
        json['faction']?.toString() ??
        meta?['faction']?.toString() ??
        meta?['sender_faction']?.toString();
    return ChatFactionX.fromKey(val);
  }

  static int? _parseSenderLevel(Map<String, dynamic> json, Map<String, dynamic>? meta) {
    final dynamic lvl = json['sender_level'] ?? json['level'] ?? meta?['level'] ?? meta?['sender_level'];
    if (lvl is num) return lvl.toInt();
    if (lvl is String) return int.tryParse(lvl);
    return null;
  }

  static List<ChatItemLink> _parseItemLinks(
    Map<String, dynamic> json,
    Map<String, dynamic>? meta,
    String content,
  ) {
    final List<ChatItemLink> result = <ChatItemLink>[];

    // Explicit item links list in json or metadata
    final dynamic linksRaw = json['item_links'] ?? meta?['item_links'];
    if (linksRaw is List) {
      for (final dynamic item in linksRaw) {
        if (item is Map) {
          result.add(ChatItemLink.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Parse [item:...] tags from message content
    final RegExp tagRegExp = RegExp(r'\[item:[^\]]+\]');
    final Iterable<RegExpMatch> matches = tagRegExp.allMatches(content);
    for (final RegExpMatch m in matches) {
      final String tag = m.group(0)!;
      final ChatItemLink? parsed = ChatItemLink.tryParseTag(tag);
      if (parsed != null && !result.any((l) => l.id == parsed.id)) {
        result.add(parsed);
      }
    }

    return result;
  }

  static String? _parseSystemTone(Map<String, dynamic> json) {
    final dynamic metadata = json['metadata'];
    if (metadata is Map) {
      final String? tone = metadata['tone']?.toString();
      if (tone == 'success' || tone == 'danger' || tone == 'warning') return tone;
    }
    return null;
  }

  static String? _parseSenderGuildName(Map<String, dynamic> json) {
    final String? direct = json['sender_guild_name']?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final dynamic metadata = json['metadata'];
    if (metadata is Map) {
      final String? fromMeta = metadata['sender_guild_name']?.toString();
      if (fromMeta != null && fromMeta.trim().isNotEmpty) return fromMeta.trim();
    }
    return null;
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
