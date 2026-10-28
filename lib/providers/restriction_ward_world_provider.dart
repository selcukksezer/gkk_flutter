import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';
import '../models/moradon_models.dart';
import '../models/player_model.dart';

/// Active restriction world mode displayed directly on HomeScreen.
enum WardWorldMode {
  hospital,
  prison;

  String get wardTypeKey => this == WardWorldMode.hospital ? 'hospital' : 'prison';

  String get chatChannelKey =>
      this == WardWorldMode.hospital ? 'ward_hospital' : 'ward_prison';

  String get realtimeRoomKey =>
      this == WardWorldMode.hospital
          ? 'ward_world_hospital_v1'
          : 'ward_world_prison_v1';

  String get backgroundAsset =>
      this == WardWorldMode.hospital
          ? 'assets/moradon/ward_hospital_sanctum.jpg'
          : 'assets/moradon/ward_prison_dungeon.jpg';
}

/// Interactive non-player staff inside the Hospital Sanctum or Prison Cellblock
/// ("ordaki insanlar": doctors/healers in hospital, warden/guards in prison).
/// Explicitly marked as NPCs — never mixed into the online fellow-player list.
class WardWorldNpc {
  final String id;
  final String name;
  final String title;
  final String badgeEmoji;
  final String quote;
  final String assetPath;
  final double x;
  final double y;
  final double spriteWidth;
  final double spriteHeight;
  final bool facingRight;
  final Color accentColor;

  const WardWorldNpc({
    required this.id,
    required this.name,
    required this.title,
    required this.badgeEmoji,
    required this.quote,
    required this.assetPath,
    required this.x,
    required this.y,
    this.spriteWidth = 82.0,
    this.spriteHeight = 118.0,
    this.facingRight = true,
    required this.accentColor,
  });
}

const List<WardWorldNpc> kHospitalWardNpcs = <WardWorldNpc>[
  WardWorldNpc(
    id: 'hospital_chief_healer',
    name: 'Baş Şifacı Lyra',
    title: 'Kraliyet Şifahanesi',
    badgeEmoji: '⚕️',
    quote:
        'Yaraların ağır savaşçı... İksir masamda acil müdahale yapabilir ya da seni hemen taburcu edebilirim.',
    assetPath: 'assets/moradon/npc_master_mira.png',
    x: 560.0,
    y: 590.0,
    facingRight: true,
    accentColor: Color(0xFF34D399),
  ),
  WardWorldNpc(
    id: 'hospital_guild_surgeon',
    name: 'Klinik Hekimi Veyron',
    title: 'Lonca & Doktor Müdahalesi',
    badgeEmoji: '🧪',
    quote:
        'Lonca kliniğin açıksa süreni kısaltabilir veya nöbetçi doktor muayenesi talep edebilirsin.',
    assetPath: 'assets/moradon/npc_master_veyron.png',
    x: 830.0,
    y: 495.0,
    facingRight: false,
    accentColor: Color(0xFF38BDF8),
  ),
];

const List<WardWorldNpc> kPrisonWardNpcs = <WardWorldNpc>[
  WardWorldNpc(
    id: 'prison_chief_warden',
    name: 'Baş Gardiyan Alaric',
    title: 'Zindan Amirliği & Kefalet',
    badgeEmoji: '⛓️',
    quote:
        'Kraliyet zindanına düştün! Kefalet elmasını masaya koy, lonca avukatını çağır ya da cezanı bekle.',
    assetPath: 'assets/moradon/npc_master_alaric.png',
    x: 585.0,
    y: 585.0,
    facingRight: true,
    accentColor: Color(0xFFF59E0B),
  ),
  WardWorldNpc(
    id: 'prison_gate_guard',
    name: 'Demir Kapı Nöbetçisi',
    title: 'Kraliyet Muhafızı',
    badgeEmoji: '🛡️',
    quote:
        'Demir parmaklıkların ardında sadece şu an çevrimiçi mahkumları görürsün. Firar denemesi risklidir!',
    assetPath: 'assets/moradon/npc_master_draven.png',
    x: 1155.0,
    y: 515.0,
    facingRight: false,
    accentColor: Color(0xFFF87171),
  ),
];

/// Represents a REAL, currently ONLINE fellow player who is in the exact same
/// active restriction (Hospital or Prison). Offline users and bots are never created.
class OnlineWardPeer {
  final String userId;
  final String username;
  final String displayName;
  final String characterClass;
  final int level;
  final int power;
  final String? guildName;
  final String? cosmeticTitle;
  final String? avatarUrl;
  final DateTime untilTs;
  final String? reason;
  final double x;
  final double y;
  final double targetX;
  final double targetY;
  final bool facingRight;
  final bool facingBack;
  final double walkPhase;
  final bool sameGuild;
  final DateTime? lastRealtimeSeen;
  final DateTime? lastDbOnlineSeen;

  const OnlineWardPeer({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.characterClass,
    required this.level,
    this.power = 100,
    this.guildName,
    this.cosmeticTitle,
    this.avatarUrl,
    required this.untilTs,
    this.reason,
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
    this.facingRight = true,
    this.facingBack = false,
    this.walkPhase = 0.0,
    this.sameGuild = false,
    this.lastRealtimeSeen,
    this.lastDbOnlineSeen,
  });

  Duration remainingAt(DateTime now) {
    final Duration diff = untilTs.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Strict online + active restriction truth check:
  /// 1) Restriction MUST still be in the future (`untilTs > now`).
  /// 2) Peer MUST have an active Realtime heartbeat (<= 20s) OR a fresh DB
  ///    online heartbeat (`is_online = true` verified within <= 5m).
  bool isStrictOnlineAndActive(DateTime now) {
    if (!untilTs.isAfter(now)) return false;
    final bool liveWs =
        lastRealtimeSeen != null &&
        now.difference(lastRealtimeSeen!).abs() <= const Duration(seconds: 20);
    final bool liveDb =
        lastDbOnlineSeen != null &&
        now.difference(lastDbOnlineSeen!).abs() <= const Duration(minutes: 5);
    return liveWs || liveDb;
  }

  OnlineWardPeer copyWith({
    String? username,
    String? displayName,
    String? characterClass,
    int? level,
    int? power,
    String? guildName,
    String? cosmeticTitle,
    String? avatarUrl,
    DateTime? untilTs,
    String? reason,
    double? x,
    double? y,
    double? targetX,
    double? targetY,
    bool? facingRight,
    bool? facingBack,
    double? walkPhase,
    bool? sameGuild,
    DateTime? lastRealtimeSeen,
    DateTime? lastDbOnlineSeen,
  }) {
    return OnlineWardPeer(
      userId: userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      characterClass: characterClass ?? this.characterClass,
      level: level ?? this.level,
      power: power ?? this.power,
      guildName: guildName ?? this.guildName,
      cosmeticTitle: cosmeticTitle ?? this.cosmeticTitle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      untilTs: untilTs ?? this.untilTs,
      reason: reason ?? this.reason,
      x: x ?? this.x,
      y: y ?? this.y,
      targetX: targetX ?? this.targetX,
      targetY: targetY ?? this.targetY,
      facingRight: facingRight ?? this.facingRight,
      facingBack: facingBack ?? this.facingBack,
      walkPhase: walkPhase ?? this.walkPhase,
      sameGuild: sameGuild ?? this.sameGuild,
      lastRealtimeSeen: lastRealtimeSeen ?? this.lastRealtimeSeen,
      lastDbOnlineSeen: lastDbOnlineSeen ?? this.lastDbOnlineSeen,
    );
  }
}

class WardChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;

  const WardChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });
}

/// Clamp any coordinate to the walkable stone floor of the 1920x1080 2.5D room.
Offset clampToWardWalkableFloor(WardWorldMode mode, double rawX, double rawY) {
  if (mode == WardWorldMode.hospital) {
    // Central stone flagstone hall in ward_hospital_sanctum.jpg
    final double y = rawY.clamp(535.0, 935.0);
    final double t = (y - 535.0) / 400.0;
    final double minX = 430.0 - t * 90.0;
    final double maxX = 1230.0 + t * 230.0;
    return Offset(rawX.clamp(minX, maxX), y);
  } else {
    // Central stone dungeon courtyard in ward_prison_dungeon.jpg
    final double y = rawY.clamp(525.0, 940.0);
    final double t = (y - 525.0) / 415.0;
    final double minX = 450.0 - t * 95.0;
    final double maxX = 1320.0 + t * 165.0;
    return Offset(rawX.clamp(minX, maxX), y);
  }
}

/// Deterministic, non-overlapping floor slot for an online peer when they have
/// not yet broadcast custom walk coordinates.
Offset deterministicWardSlot(WardWorldMode mode, String userId, int index) {
  final int hash = userId.codeUnits.fold<int>(
    17,
    (int acc, int c) => (acc * 31 + c) & 0x7fffffff,
  );
  if (mode == WardWorldMode.hospital) {
    // Recovery bed alcoves & central sunburst mosaic positions
    const List<Offset> slots = <Offset>[
      Offset(980, 625),
      Offset(1115, 685),
      Offset(1245, 745),
      Offset(745, 735),
      Offset(935, 815),
      Offset(620, 790),
      Offset(1120, 845),
      Offset(815, 645),
    ];
    final Offset base = slots[(index + hash) % slots.length];
    final double jitterX = ((hash % 36) - 18).toDouble();
    final double jitterY = (((hash ~/ 7) % 26) - 13).toDouble();
    return clampToWardWalkableFloor(
      mode,
      base.dx + jitterX,
      base.dy + jitterY,
    );
  } else {
    // Dungeon cellblock courtyard around the iron floor grate
    const List<Offset> slots = <Offset>[
      Offset(950, 650),
      Offset(1145, 695),
      Offset(760, 715),
      Offset(1055, 810),
      Offset(825, 835),
      Offset(1255, 785),
      Offset(645, 775),
      Offset(945, 745),
    ];
    final Offset base = slots[(index + hash) % slots.length];
    final double jitterX = ((hash % 38) - 19).toDouble();
    final double jitterY = (((hash ~/ 11) % 28) - 14).toDouble();
    return clampToWardWalkableFloor(
      mode,
      base.dx + jitterX,
      base.dy + jitterY,
    );
  }
}

/// Pure, unit-testable online-only peer parser & filter.
/// Rejects:
/// - local player (`myUserId`)
/// - offline players (`is_online != true`)
/// - stale heartbeats (`last_active_at` older than 5 minutes when present)
/// - expired or missing restriction timestamps (`untilTs <= now`)
List<OnlineWardPeer> filterOnlineWardPeersFromRows({
  required WardWorldMode mode,
  required Iterable<Map<String, dynamic>> rows,
  required String myUserId,
  required DateTime now,
  String? myGuildId,
  Map<String, OnlineWardPeer> existingPeers = const <String, OnlineWardPeer>{},
}) {
  final List<OnlineWardPeer> accepted = <OnlineWardPeer>[];
  int idx = 0;

  for (final Map<String, dynamic> row in rows) {
    final String uid = (row['user_id'] ?? row['id'] ?? '').toString().trim();
    if (uid.isEmpty || uid == myUserId) continue;

    // 1. Strict online flag check
    final dynamic rawOnline = row['is_online'];
    final bool isOnline = rawOnline == true;
    if (!isOnline) continue;

    // 2. Strict fresh heartbeat check (<= 5 minutes) when last_active_at is provided
    final String? lastActiveRaw = row['last_active_at']?.toString();
    DateTime dbSeenAt = now;
    if (lastActiveRaw != null && lastActiveRaw.isNotEmpty) {
      final DateTime? parsedActive = DateTime.tryParse(lastActiveRaw);
      if (parsedActive == null) continue;
      if (now.toUtc().difference(parsedActive.toUtc()) >
          const Duration(minutes: 5)) {
        continue;
      }
      dbSeenAt = parsedActive.toLocal();
    }

    // 3. Strict active restriction check for the SAME ward (hospital vs prison)
    final String? untilRaw = (row['until_ts'] ??
            (mode == WardWorldMode.hospital
                ? row['hospital_until']
                : row['prison_until']))
        ?.toString();
    if (untilRaw == null || untilRaw.isEmpty) continue;
    final DateTime? parsedUntil = DateTime.tryParse(untilRaw);
    if (parsedUntil == null || !parsedUntil.toUtc().isAfter(now.toUtc())) {
      continue;
    }

    final String uname =
        (row['username'] ?? row['display_name'] ?? 'Oyuncu').toString().trim();
    final String dname =
        (row['display_name'] ?? row['username'] ?? uname).toString().trim();
    final String cclass =
        (row['character_class'] ?? 'savasci').toString().trim();
    final int lvl = (row['level'] as num?)?.toInt() ?? 1;
    final int pwr = (row['power'] as num?)?.toInt() ?? (lvl * 180 + 250);
    final String? gName = row['guild_name']?.toString();
    final String? rowGuildId = row['guild_id']?.toString();
    final bool sameGuild =
        row['same_guild'] == true ||
        (myGuildId != null &&
            myGuildId.isNotEmpty &&
            rowGuildId != null &&
            rowGuildId == myGuildId);
    final String? reason = (row['reason'] ??
            (mode == WardWorldMode.hospital
                ? row['hospital_reason']
                : row['prison_reason']))
        ?.toString();

    final OnlineWardPeer? prev = existingPeers[uid];
    final Offset slot = prev != null
        ? Offset(prev.x, prev.y)
        : deterministicWardSlot(mode, uid, idx);

    accepted.add(
      OnlineWardPeer(
        userId: uid,
        username: uname.isEmpty ? 'Oyuncu' : uname,
        displayName: dname.isEmpty ? uname : dname,
        characterClass: cclass.isEmpty ? 'savasci' : cclass,
        level: lvl,
        power: pwr,
        guildName: (gName != null && gName.isNotEmpty)
            ? gName
            : prev?.guildName,
        cosmeticTitle:
            row['cosmetic_title']?.toString() ?? prev?.cosmeticTitle,
        avatarUrl: row['avatar_url']?.toString() ?? prev?.avatarUrl,
        untilTs: parsedUntil.toLocal(),
        reason: reason ?? prev?.reason,
        x: slot.dx,
        y: slot.dy,
        targetX: prev?.targetX ?? slot.dx,
        targetY: prev?.targetY ?? slot.dy,
        facingRight: prev?.facingRight ?? idx.isEven,
        facingBack: prev?.facingBack ?? false,
        walkPhase: prev?.walkPhase ?? 0.0,
        sameGuild: sameGuild,
        lastRealtimeSeen: prev?.lastRealtimeSeen,
        lastDbOnlineSeen: dbSeenAt,
      ),
    );
    idx++;
  }

  return accepted;
}

class RestrictionWardWorldState {
  static const double worldWidth = 1920.0;
  static const double worldHeight = 1080.0;

  final WardWorldMode mode;
  final double playerX;
  final double playerY;
  final double targetX;
  final double targetY;
  final bool facingRight;
  final bool facingBack;
  final bool isMoving;
  final double walkPhase;
  final Offset? moveRingPosition;
  final Map<String, OnlineWardPeer> onlinePeers;
  final Map<String, MoradonChatBubble> chatBubbles;
  final List<WardChatMessage> chatMessages;
  final String? selectedPeerId;
  final String? selectedNpcId;
  final bool realtimeConnected;
  final bool loadingPeers;

  const RestrictionWardWorldState({
    this.mode = WardWorldMode.hospital,
    this.playerX = 890.0,
    this.playerY = 745.0,
    this.targetX = 890.0,
    this.targetY = 745.0,
    this.facingRight = true,
    this.facingBack = false,
    this.isMoving = false,
    this.walkPhase = 0.0,
    this.moveRingPosition,
    this.onlinePeers = const <String, OnlineWardPeer>{},
    this.chatBubbles = const <String, MoradonChatBubble>{},
    this.chatMessages = const <WardChatMessage>[],
    this.selectedPeerId,
    this.selectedNpcId,
    this.realtimeConnected = false,
    this.loadingPeers = false,
  });

  OnlineWardPeer? get selectedPeer =>
      selectedPeerId == null ? null : onlinePeers[selectedPeerId];

  List<WardWorldNpc> get npcs =>
      mode == WardWorldMode.hospital ? kHospitalWardNpcs : kPrisonWardNpcs;

  WardWorldNpc? get selectedNpc {
    if (selectedNpcId == null) return null;
    for (final WardWorldNpc npc in npcs) {
      if (npc.id == selectedNpcId) return npc;
    }
    return null;
  }

  RestrictionWardWorldState copyWith({
    WardWorldMode? mode,
    double? playerX,
    double? playerY,
    double? targetX,
    double? targetY,
    bool? facingRight,
    bool? facingBack,
    bool? isMoving,
    double? walkPhase,
    Offset? moveRingPosition,
    bool clearMoveRing = false,
    Map<String, OnlineWardPeer>? onlinePeers,
    Map<String, MoradonChatBubble>? chatBubbles,
    List<WardChatMessage>? chatMessages,
    String? selectedPeerId,
    bool clearSelectedPeer = false,
    String? selectedNpcId,
    bool clearSelectedNpc = false,
    bool? realtimeConnected,
    bool? loadingPeers,
  }) {
    return RestrictionWardWorldState(
      mode: mode ?? this.mode,
      playerX: playerX ?? this.playerX,
      playerY: playerY ?? this.playerY,
      targetX: targetX ?? this.targetX,
      targetY: targetY ?? this.targetY,
      facingRight: facingRight ?? this.facingRight,
      facingBack: facingBack ?? this.facingBack,
      isMoving: isMoving ?? this.isMoving,
      walkPhase: walkPhase ?? this.walkPhase,
      moveRingPosition: clearMoveRing
          ? null
          : (moveRingPosition ?? this.moveRingPosition),
      onlinePeers: onlinePeers ?? this.onlinePeers,
      chatBubbles: chatBubbles ?? this.chatBubbles,
      chatMessages: chatMessages ?? this.chatMessages,
      selectedPeerId: clearSelectedPeer
          ? null
          : (selectedPeerId ?? this.selectedPeerId),
      selectedNpcId: clearSelectedNpc
          ? null
          : (selectedNpcId ?? this.selectedNpcId),
      realtimeConnected: realtimeConnected ?? this.realtimeConnected,
      loadingPeers: loadingPeers ?? this.loadingPeers,
    );
  }
}

class RestrictionWardWorldNotifier extends Notifier<RestrictionWardWorldState> {
  Timer? _frameTimer;
  Timer? _heartbeatTimer;
  Timer? _dbPollTimer;
  final Stopwatch _watch = Stopwatch();
  int _lastMicros = 0;

  RealtimeChannel? _worldChannel;
  RealtimeChannel? _chatDbChannel;
  PlayerProfile? _localProfile;
  int _localPower = 100;
  DateTime _lastMoveSent = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  RestrictionWardWorldState build() {
    ref.onDispose(_disposeAll);
    return const RestrictionWardWorldState();
  }

  void _disposeAll() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _dbPollTimer?.cancel();
    _dbPollTimer = null;
    _sendLeaveAndCloseChannels();
  }

  void _sendLeaveAndCloseChannels() {
    final RealtimeChannel? worldCh = _worldChannel;
    final String? uid = _localProfile?.id;
    _worldChannel = null;
    if (worldCh != null) {
      if (uid != null && uid.isNotEmpty) {
        unawaited(
          worldCh
              .sendBroadcastMessage(
                event: 'ward_leave',
                payload: <String, dynamic>{'user_id': uid},
              )
              .catchError((_) => ChannelResponse.ok),
        );
      }
      unawaited(worldCh.unsubscribe());
    }
    final RealtimeChannel? chatCh = _chatDbChannel;
    _chatDbChannel = null;
    if (chatCh != null) {
      unawaited(chatCh.unsubscribe());
    }
  }

  /// Binds the active restriction mode (`hospital` or `prison`) and local player.
  /// Automatically switches rooms & refreshes online-only peers if mode changes.
  void bindSession({
    required WardWorldMode mode,
    required PlayerProfile profile,
    required int totalPower,
  }) {
    final bool modeChanged = state.mode != mode;
    final bool userChanged = _localProfile?.id != profile.id;
    final bool uninitialized = _frameTimer == null;

    _localProfile = profile;
    _localPower = totalPower;

    if (modeChanged || userChanged || uninitialized) {
      _sendLeaveAndCloseChannels();
      final Offset spawn = mode == WardWorldMode.hospital
          ? const Offset(885.0, 745.0)
          : const Offset(905.0, 755.0);
      state = RestrictionWardWorldState(
        mode: mode,
        playerX: spawn.dx,
        playerY: spawn.dy,
        targetX: spawn.dx,
        targetY: spawn.dy,
        facingRight: true,
        loadingPeers: true,
      );
      _startLoops();
      unawaited(_connectRealtime(mode));
      unawaited(refreshOnlinePeers());
      unawaited(loadWardChatHistory());
    }
  }

  void _startLoops() {
    _frameTimer?.cancel();
    _watch
      ..reset()
      ..start();
    _lastMicros = _watch.elapsedMicroseconds;
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _onTick(),
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      unawaited(_broadcastHeartbeat());
      _pruneOfflineAndExpiredPeers();
    });

    _dbPollTimer?.cancel();
    _dbPollTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      unawaited(refreshOnlinePeers(silent: true));
    });
  }

  DateTime? _myActiveUntil() {
    final PlayerProfile? me = _localProfile;
    if (me == null) return null;
    final String? raw = state.mode == WardWorldMode.hospital
        ? me.hospitalUntil
        : me.prisonUntil;
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> _connectRealtime(WardWorldMode mode) async {
    if (!SupabaseService.isInitialized || _localProfile == null) return;

    try {
      final RealtimeChannel worldCh = SupabaseService.client.channel(
        mode.realtimeRoomKey,
        opts: const RealtimeChannelConfig(self: false),
      );
      _worldChannel = worldCh;

      worldCh
          .onBroadcast(
            event: 'ward_heartbeat',
            callback: _handlePeerHeartbeat,
          )
          .onBroadcast(
            event: 'player_move',
            callback: _handlePeerMove,
          )
          .onBroadcast(
            event: 'ward_chat_bubble',
            callback: _handleChatBubbleBroadcast,
          )
          .onBroadcast(
            event: 'ward_leave',
            callback: (Map<String, dynamic> payload) {
              final String uid = (payload['user_id'] ?? '').toString();
              if (uid.isEmpty) return;
              final Map<String, OnlineWardPeer> next =
                  Map<String, OnlineWardPeer>.from(state.onlinePeers)
                    ..remove(uid);
              state = state.copyWith(
                onlinePeers: next,
                clearSelectedPeer: state.selectedPeerId == uid,
              );
            },
          )
          .subscribe((RealtimeSubscribeStatus status, Object? _) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              state = state.copyWith(realtimeConnected: true);
              unawaited(_broadcastHeartbeat());
            } else if (status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.channelError) {
              state = state.copyWith(realtimeConnected: false);
            }
          });

      // Subscribe to live Postgres INSERTs on ward_hospital / ward_prison chat
      final RealtimeChannel chatCh = SupabaseService.client
          .channel('home_${mode.chatChannelKey}_stream')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'channel',
              value: mode.chatChannelKey,
            ),
            callback: (PostgresChangePayload payload) {
              final Map<String, dynamic> row =
                  Map<String, dynamic>.from(payload.newRecord);
              if (row.isEmpty || row['deleted_at'] != null) return;
              _ingestChatRow(row, showBubble: true);
            },
          )
          .subscribe();
      _chatDbChannel = chatCh;
    } catch (_) {
      state = state.copyWith(realtimeConnected: false);
    }
  }

  Future<void> _broadcastHeartbeat() async {
    final PlayerProfile? me = _localProfile;
    final RealtimeChannel? ch = _worldChannel;
    final DateTime? until = _myActiveUntil();
    if (me == null || ch == null || !state.realtimeConnected || until == null) {
      return;
    }
    if (!until.isAfter(DateTime.now())) return;

    try {
      await ch.sendBroadcastMessage(
        event: 'ward_heartbeat',
        payload: <String, dynamic>{
          'user_id': me.id,
          'username': me.username,
          'display_name': me.displayName ?? me.username,
          'character_class': me.characterClass?.name ?? 'savasci',
          'level': me.level,
          'power': _localPower,
          'guild_id': me.guildId,
          'guild_name': me.guildName,
          'cosmetic_title': me.cosmeticTitle,
          'avatar_url': me.avatarUrl,
          'until_ts': until.toUtc().toIso8601String(),
          'reason': state.mode == WardWorldMode.hospital
              ? me.hospitalReason
              : me.prisonReason,
          'x': state.playerX.round(),
          'y': state.playerY.round(),
          'facing_right': state.facingRight,
        },
      );
    } catch (_) {}
  }

  void _handlePeerHeartbeat(Map<String, dynamic> payload) {
    final PlayerProfile? me = _localProfile;
    if (me == null) return;
    final String uid = (payload['user_id'] ?? '').toString().trim();
    if (uid.isEmpty || uid == me.id) return;

    final String? untilRaw = payload['until_ts']?.toString();
    final DateTime? until = untilRaw == null ? null : DateTime.tryParse(untilRaw);
    final DateTime now = DateTime.now();
    if (until == null || !until.toUtc().isAfter(now.toUtc())) {
      final Map<String, OnlineWardPeer> next =
          Map<String, OnlineWardPeer>.from(state.onlinePeers)..remove(uid);
      state = state.copyWith(onlinePeers: next);
      return;
    }

    final Offset clamped = clampToWardWalkableFloor(
      state.mode,
      (payload['x'] as num?)?.toDouble() ?? 950.0,
      (payload['y'] as num?)?.toDouble() ?? 720.0,
    );
    final Map<String, OnlineWardPeer> next =
        Map<String, OnlineWardPeer>.from(state.onlinePeers);
    final OnlineWardPeer? existing = next[uid];
    final String uname = (payload['username'] ?? 'Oyuncu').toString();
    final String dname = (payload['display_name'] ?? uname).toString();
    final String? peerGuildId = payload['guild_id']?.toString();
    final bool sameGuild =
        me.guildId != null &&
        me.guildId!.isNotEmpty &&
        peerGuildId == me.guildId;

    next[uid] = OnlineWardPeer(
      userId: uid,
      username: uname,
      displayName: dname,
      characterClass: (payload['character_class'] ?? 'savasci').toString(),
      level: (payload['level'] as num?)?.toInt() ?? 1,
      power: (payload['power'] as num?)?.toInt() ?? 200,
      guildName: payload['guild_name']?.toString(),
      cosmeticTitle: payload['cosmetic_title']?.toString(),
      avatarUrl: payload['avatar_url']?.toString(),
      untilTs: until.toLocal(),
      reason: payload['reason']?.toString(),
      x: existing?.x ?? clamped.dx,
      y: existing?.y ?? clamped.dy,
      targetX: clamped.dx,
      targetY: clamped.dy,
      facingRight: payload['facing_right'] as bool? ?? true,
      facingBack: existing?.facingBack ?? false,
      walkPhase: existing?.walkPhase ?? 0.0,
      sameGuild: sameGuild,
      lastRealtimeSeen: now,
      lastDbOnlineSeen: existing?.lastDbOnlineSeen ?? now,
    );
    state = state.copyWith(onlinePeers: next);
  }

  void _handlePeerMove(Map<String, dynamic> payload) {
    final String uid = (payload['user_id'] ?? '').toString().trim();
    if (uid.isEmpty || uid == _localProfile?.id) return;
    final OnlineWardPeer? existing = state.onlinePeers[uid];
    if (existing == null) {
      _handlePeerHeartbeat(payload);
      return;
    }
    final Offset target = clampToWardWalkableFloor(
      state.mode,
      (payload['x'] as num?)?.toDouble() ?? existing.targetX,
      (payload['y'] as num?)?.toDouble() ?? existing.targetY,
    );
    final Map<String, OnlineWardPeer> next =
        Map<String, OnlineWardPeer>.from(state.onlinePeers);
    next[uid] = existing.copyWith(
      targetX: target.dx,
      targetY: target.dy,
      facingRight: target.dx >= existing.x,
      facingBack: target.dy < existing.y - 8.0,
      lastRealtimeSeen: DateTime.now(),
    );
    state = state.copyWith(onlinePeers: next);
  }

  void _handleChatBubbleBroadcast(Map<String, dynamic> payload) {
    final String uid = (payload['user_id'] ?? '').toString().trim();
    final String sender = (payload['sender_name'] ?? 'Oyuncu').toString();
    final String msg = (payload['message'] ?? '').toString().trim();
    if (uid.isEmpty || msg.isEmpty) return;
    _putSpeechBubble(userId: uid, username: sender, message: msg);
  }

  void _putSpeechBubble({
    required String userId,
    required String username,
    required String message,
  }) {
    final Map<String, MoradonChatBubble> bubbles =
        Map<String, MoradonChatBubble>.from(state.chatBubbles);
    bubbles[userId] = MoradonChatBubble(
      userId: userId,
      username: username,
      message: message,
      expiresAt: DateTime.now().add(const Duration(seconds: 7)),
    );
    state = state.copyWith(chatBubbles: bubbles);
  }

  /// Queries ONLY currently ONLINE players (`is_online = true` & fresh heartbeat)
  /// who are in the exact same restriction (`hospital` or `prison`).
  Future<void> refreshOnlinePeers({bool silent = false}) async {
    final PlayerProfile? me = _localProfile;
    if (me == null || !SupabaseService.isInitialized) {
      if (state.loadingPeers) state = state.copyWith(loadingPeers: false);
      return;
    }
    if (!silent) {
      state = state.copyWith(loadingPeers: true);
    }

    final WardWorldMode mode = state.mode;
    final DateTime now = DateTime.now();
    List<Map<String, dynamic>> rawRows = <Map<String, dynamic>>[];
    bool fetched = false;

    // 1. Primary: SECURITY DEFINER RPC get_online_ward_players
    try {
      final dynamic rpcRes = await SupabaseService.client
          .rpc(
            'get_online_ward_players',
            params: <String, dynamic>{'p_ward_type': mode.wardTypeKey},
          )
          .timeout(const Duration(seconds: 6));
      if (rpcRes is Map && rpcRes['success'] == true && rpcRes['entries'] is List) {
        rawRows = (rpcRes['entries'] as List<dynamic>)
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
            .toList();
        fetched = true;
      }
    } catch (_) {
      // Fallback to direct users query below if migration is not yet applied
    }

    // 2. Fallback: Direct query on public.users strictly filtering online + active restriction
    if (!fetched) {
      try {
        final String untilCol =
            mode == WardWorldMode.hospital ? 'hospital_until' : 'prison_until';
        final String nowIso = now.toUtc().toIso8601String();
        final String freshIso =
            now.toUtc().subtract(const Duration(minutes: 5)).toIso8601String();

        final dynamic rows = await SupabaseService.client
            .from('users')
            .select(
              'id, username, display_name, character_class, level, power, guild_id, cosmetic_title, avatar_url, is_online, last_active_at, hospital_until, hospital_reason, prison_until, prison_reason',
            )
            .eq('is_online', true)
            .gt(untilCol, nowIso)
            .gt('last_active_at', freshIso)
            .limit(40)
            .timeout(const Duration(seconds: 6));

        if (rows is List) {
          rawRows = rows
              .whereType<Map<dynamic, dynamic>>()
              .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
              .toList();
          fetched = true;
        }
      } catch (_) {}
    }

    if (_localProfile?.id != me.id || state.mode != mode) return;

    final List<OnlineWardPeer> dbOnlinePeers = filterOnlineWardPeersFromRows(
      mode: mode,
      rows: rawRows,
      myUserId: me.id,
      myGuildId: me.guildId,
      now: now,
      existingPeers: state.onlinePeers,
    );

    final Map<String, OnlineWardPeer> merged = <String, OnlineWardPeer>{};
    for (final OnlineWardPeer p in dbOnlinePeers) {
      merged[p.userId] = p;
    }

    // Preserve peers who have a live WebSocket heartbeat (< 20s) and unexpired timer
    for (final MapEntry<String, OnlineWardPeer> entry
        in state.onlinePeers.entries) {
      if (merged.containsKey(entry.key)) continue;
      final OnlineWardPeer p = entry.value;
      final bool liveWs =
          p.lastRealtimeSeen != null &&
          now.difference(p.lastRealtimeSeen!) <= const Duration(seconds: 20);
      if (liveWs && p.untilTs.isAfter(now)) {
        merged[entry.key] = p;
      }
    }

    state = state.copyWith(
      onlinePeers: merged,
      loadingPeers: false,
      clearSelectedPeer:
          state.selectedPeerId != null && !merged.containsKey(state.selectedPeerId),
    );
  }

  void _pruneOfflineAndExpiredPeers() {
    final DateTime now = DateTime.now();
    bool changed = false;
    final Map<String, OnlineWardPeer> next = <String, OnlineWardPeer>{};
    for (final MapEntry<String, OnlineWardPeer> e
        in state.onlinePeers.entries) {
      if (e.value.isStrictOnlineAndActive(now)) {
        next[e.key] = e.value;
      } else {
        changed = true;
      }
    }
    if (changed) {
      state = state.copyWith(
        onlinePeers: next,
        clearSelectedPeer:
            state.selectedPeerId != null && !next.containsKey(state.selectedPeerId),
      );
    }
  }

  /// Move local player across the Hospital Ward / Prison Cellblock stone floor.
  void moveToWorldPoint(Offset rawTarget) {
    final Offset target = clampToWardWalkableFloor(
      state.mode,
      rawTarget.dx,
      rawTarget.dy,
    );
    final double dx = target.dx - state.playerX;
    final double dy = target.dy - state.playerY;
    state = state.copyWith(
      targetX: target.dx,
      targetY: target.dy,
      facingRight: dx.abs() < 2.0 ? state.facingRight : dx >= 0,
      facingBack: dy < -10.0,
      isMoving: true,
      moveRingPosition: target,
      clearSelectedPeer: true,
      clearSelectedNpc: true,
    );

    final DateTime now = DateTime.now();
    final RealtimeChannel? ch = _worldChannel;
    if (ch != null &&
        state.realtimeConnected &&
        now.difference(_lastMoveSent) > const Duration(milliseconds: 140)) {
      _lastMoveSent = now;
      unawaited(
        ch
            .sendBroadcastMessage(
              event: 'player_move',
              payload: <String, dynamic>{
                'user_id': _localProfile?.id ?? '',
                'username': _localProfile?.username ?? 'Oyuncu',
                'display_name':
                    _localProfile?.displayName ?? _localProfile?.username ?? 'Oyuncu',
                'character_class': _localProfile?.characterClass?.name ?? 'savasci',
                'level': _localProfile?.level ?? 1,
                'power': _localPower,
                'guild_id': _localProfile?.guildId,
                'guild_name': _localProfile?.guildName,
                'until_ts': _myActiveUntil()?.toUtc().toIso8601String(),
                'x': target.dx.round(),
                'y': target.dy.round(),
                'facing_right': dx >= 0,
              },
            )
            .catchError((_) => ChannelResponse.ok),
      );
    }
  }

  void selectPeer(OnlineWardPeer? peer) {
    if (peer == null) {
      state = state.copyWith(clearSelectedPeer: true);
      return;
    }
    state = state.copyWith(
      selectedPeerId: peer.userId,
      clearSelectedNpc: true,
    );
  }

  void interactWithNpc(WardWorldNpc npc) {
    final Offset standSpot = clampToWardWalkableFloor(
      state.mode,
      npc.x + (npc.facingRight ? 95.0 : -95.0),
      npc.y + 55.0,
    );
    moveToWorldPoint(standSpot);
    state = state.copyWith(
      selectedNpcId: npc.id,
      clearSelectedPeer: true,
    );
  }

  void clearSelections() {
    state = state.copyWith(clearSelectedPeer: true, clearSelectedNpc: true);
  }

  Future<void> loadWardChatHistory() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'get_ward_chat_history',
        params: <String, dynamic>{
          'p_ward_type': state.mode.wardTypeKey,
          'p_limit': 35,
        },
      );
      if (res is Map && res['success'] == true && res['messages'] is List) {
        final List<WardChatMessage> parsed = <WardChatMessage>[];
        for (final dynamic item in res['messages'] as List<dynamic>) {
          if (item is! Map) continue;
          final Map<String, dynamic> m = Map<String, dynamic>.from(item);
          final String id = (m['id'] ?? '').toString();
          final String content = (m['content'] ?? '').toString().trim();
          if (id.isEmpty || content.isEmpty) continue;
          parsed.add(
            WardChatMessage(
              id: id,
              senderId: (m['sender_id'] ?? m['sender_user_id'] ?? '').toString(),
              senderName: (m['sender_name'] ?? 'Oyuncu').toString(),
              content: content,
              createdAt:
                  DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ??
                  DateTime.now(),
            ),
          );
        }
        state = state.copyWith(chatMessages: parsed);
      }
    } catch (_) {}
  }

  void _ingestChatRow(Map<String, dynamic> row, {required bool showBubble}) {
    final String id = (row['id'] ?? '').toString();
    final String content = (row['content'] ?? '').toString().trim();
    if (id.isEmpty || content.isEmpty) return;
    if (state.chatMessages.any((WardChatMessage m) => m.id == id)) return;

    final String senderId =
        (row['sender_user_id'] ?? row['sender_id'] ?? '').toString();
    final String senderName = (row['sender_name'] ?? 'Oyuncu').toString();

    final List<WardChatMessage> next = <WardChatMessage>[
      ...state.chatMessages,
      WardChatMessage(
        id: id,
        senderId: senderId,
        senderName: senderName,
        content: content,
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
      ),
    ];
    state = state.copyWith(
      chatMessages: next.length > 50 ? next.sublist(next.length - 50) : next,
    );

    if (showBubble && senderId.isNotEmpty) {
      _putSpeechBubble(
        userId: senderId,
        username: senderName,
        message: content,
      );
    }
  }

  Future<String?> sendWardChatMessage(String rawText) async {
    final String text = rawText.trim();
    final PlayerProfile? me = _localProfile;
    if (text.isEmpty || me == null) return null;

    // Show instant overhead bubble above local hero + broadcast to room peers
    _putSpeechBubble(userId: me.id, username: me.username, message: text);
    final RealtimeChannel? ch = _worldChannel;
    if (ch != null && state.realtimeConnected) {
      unawaited(
        ch
            .sendBroadcastMessage(
              event: 'ward_chat_bubble',
              payload: <String, dynamic>{
                'user_id': me.id,
                'sender_name': me.displayName ?? me.username,
                'message': text,
              },
            )
            .catchError((_) => ChannelResponse.ok),
      );
    }

    if (!SupabaseService.isInitialized) return null;
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'send_ward_message',
        params: <String, dynamic>{
          'p_ward_type': state.mode.wardTypeKey,
          'p_content': text,
        },
      );
      if (res is Map && res['success'] != true) {
        return (res['message'] ?? res['error'] ?? 'Mesaj gönderilemedi')
            .toString();
      }
      unawaited(loadWardChatHistory());
      return null;
    } catch (_) {
      return 'Mesaj gönderilemedi.';
    }
  }

  void _onTick() {
    final int nowMicros = _watch.elapsedMicroseconds;
    final double dt = ((nowMicros - _lastMicros) / 1000000.0).clamp(0.0, 0.08);
    _lastMicros = nowMicros;
    if (dt <= 0) return;

    const double walkSpeed = 240.0;
    double px = state.playerX;
    double py = state.playerY;
    double wPhase = state.walkPhase;
    bool moving = state.isMoving;
    bool clearRing = false;

    final double dx = state.targetX - px;
    final double dy = state.targetY - py;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist > 3.0) {
      final double step = math.min(dist, walkSpeed * dt);
      px += (dx / dist) * step;
      py += (dy / dist) * step;
      wPhase = (wPhase + step * 0.032) % (math.pi * 2);
      moving = true;
    } else if (moving) {
      px = state.targetX;
      py = state.targetY;
      moving = false;
      clearRing = true;
    }

    // Interpolate remote online peers smoothly at 60 FPS
    bool peersChanged = false;
    Map<String, OnlineWardPeer>? nextPeers;
    for (final MapEntry<String, OnlineWardPeer> e
        in state.onlinePeers.entries) {
      final OnlineWardPeer p = e.value;
      final double pdx = p.targetX - p.x;
      final double pdy = p.targetY - p.y;
      final double pdist = math.sqrt(pdx * pdx + pdy * pdy);
      if (pdist > 2.5) {
        nextPeers ??= Map<String, OnlineWardPeer>.from(state.onlinePeers);
        final double step = math.min(pdist, walkSpeed * 0.92 * dt);
        nextPeers[e.key] = p.copyWith(
          x: p.x + (pdx / pdist) * step,
          y: p.y + (pdy / pdist) * step,
          walkPhase: (p.walkPhase + step * 0.032) % (math.pi * 2),
        );
        peersChanged = true;
      }
    }

    // Prune expired speech bubbles
    Map<String, MoradonChatBubble>? nextBubbles;
    for (final MapEntry<String, MoradonChatBubble> b
        in state.chatBubbles.entries) {
      if (b.value.isExpired) {
        nextBubbles ??= Map<String, MoradonChatBubble>.from(state.chatBubbles);
        nextBubbles.remove(b.key);
      }
    }

    if (moving || clearRing || peersChanged || nextBubbles != null) {
      state = state.copyWith(
        playerX: px,
        playerY: py,
        walkPhase: wPhase,
        isMoving: moving,
        clearMoveRing: clearRing,
        onlinePeers: nextPeers,
        chatBubbles: nextBubbles,
      );
    }
  }
}

final NotifierProvider<RestrictionWardWorldNotifier, RestrictionWardWorldState>
restrictionWardWorldProvider =
    NotifierProvider<RestrictionWardWorldNotifier, RestrictionWardWorldState>(
      RestrictionWardWorldNotifier.new,
    );
