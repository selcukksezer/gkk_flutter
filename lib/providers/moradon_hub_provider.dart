import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/app_foreground_service.dart';
import '../core/services/app_haptics.dart';
import '../core/services/game_sfx_service.dart';
import '../core/services/graphics_quality_service.dart';
import '../core/services/supabase_service.dart';
import '../models/moradon_models.dart';
import '../models/player_model.dart';

const List<MoradonChannelInfo> _kDefaultChannels = <MoradonChannelInfo>[
  MoradonChannelInfo(channelId: 1, onlineCount: 1, capacity: 200),
  MoradonChannelInfo(channelId: 2, onlineCount: 0, capacity: 200),
  MoradonChannelInfo(channelId: 3, onlineCount: 0, capacity: 200),
  MoradonChannelInfo(channelId: 4, onlineCount: 0, capacity: 200),
  MoradonChannelInfo(channelId: 5, onlineCount: 0, capacity: 200),
];

class MoradonHubState {
  static const double worldWidth = 6400.0;
  static const double worldHeight = 3600.0;
  static const double spawnX = 3200.0;
  static const double spawnY = 2625.0;
  static const double minWorldZoom = 0.24;
  static const double maxWorldZoom = 1.55;
  static const int mobileAvatarRenderCap = 48;
  static const int desktopAvatarRenderCap = 72;

  final double playerX;
  final double playerY;
  final double targetX;
  final double targetY;
  final double zoom;
  final bool facingRight;
  final bool facingBack;
  final double walkPhase;
  final bool isMoving;
  final bool isMerchant;
  final String? merchantTitle;
  final bool classicViewMode;
  final String? pendingNpcId;
  final String? pendingDummyId;
  final bool pendingWorldBossAttack;
  final MoradonNpcDefinition? activeNpcDialog;
  final String? selectedRemoteUserId;
  final Offset? moveRingPosition;
  final Map<String, MoradonPlayerPresence> remotePlayers;
  final Map<String, MoradonChatBubble> chatBubbles;
  final bool realtimeConnected;
  final MoradonAtmosphereChoice atmosphereChoice;
  final MoradonCelebrationEvent? activeCelebration;
  final List<MoradonPatrolGuard> patrolGuards;
  final double attackProgress;
  final int comboStage;
  final bool responsiveZoomApplied;
  final int currentChannel;
  final int totalRealmOnline;
  final int channelOnlineCount;
  final List<MoradonChannelInfo> channels;
  final bool is3dPerspective;
  final int comboStreak;
  final MoradonStrikeFeedback? activeStrike;
  final MoradonMountVisual mountedSteed;
  final MoradonEmoteBubble? activeEmote;
  final MoradonWorldBossState worldBoss;

  const MoradonHubState({
    this.playerX = spawnX,
    this.playerY = spawnY,
    this.targetX = spawnX,
    this.targetY = spawnY,
    this.zoom = 1.00,
    this.facingRight = true,
    this.facingBack = false,
    this.walkPhase = 0.0,
    this.isMoving = false,
    this.isMerchant = false,
    this.merchantTitle,
    this.classicViewMode = false,
    this.pendingNpcId,
    this.pendingDummyId,
    this.pendingWorldBossAttack = false,
    this.activeNpcDialog,
    this.selectedRemoteUserId,
    this.moveRingPosition,
    this.remotePlayers = const <String, MoradonPlayerPresence>{},
    this.chatBubbles = const <String, MoradonChatBubble>{},
    this.realtimeConnected = false,
    this.atmosphereChoice = MoradonAtmosphereChoice.auto,
    this.activeCelebration,
    this.patrolGuards = const <MoradonPatrolGuard>[],
    this.attackProgress = 0.0,
    this.comboStage = 0,
    this.responsiveZoomApplied = false,
    this.currentChannel = 1,
    this.totalRealmOnline = 1,
    this.channelOnlineCount = 1,
    this.channels = _kDefaultChannels,
    this.is3dPerspective = true,
    this.comboStreak = 0,
    this.activeStrike,
    this.mountedSteed = MoradonMountVisual.none,
    this.activeEmote,
    this.worldBoss = const MoradonWorldBossState(),
  });

  MoradonPlayerPresence? get selectedRemotePlayer =>
      selectedRemoteUserId == null ? null : remotePlayers[selectedRemoteUserId];

  MoradonDistrictZone get currentDistrict =>
      resolveMoradonDistrict(playerX, playerY);

  MoradonHubState copyWith({
    double? playerX,
    double? playerY,
    double? targetX,
    double? targetY,
    double? zoom,
    bool? facingRight,
    bool? facingBack,
    double? walkPhase,
    bool? isMoving,
    bool? isMerchant,
    String? merchantTitle,
    bool clearMerchantTitle = false,
    bool? classicViewMode,
    String? pendingNpcId,
    bool clearPendingNpc = false,
    String? pendingDummyId,
    bool clearPendingDummy = false,
    bool? pendingWorldBossAttack,
    MoradonNpcDefinition? activeNpcDialog,
    bool clearActiveNpcDialog = false,
    String? selectedRemoteUserId,
    bool clearSelectedRemoteUser = false,
    Offset? moveRingPosition,
    bool clearMoveRing = false,
    Map<String, MoradonPlayerPresence>? remotePlayers,
    Map<String, MoradonChatBubble>? chatBubbles,
    bool? realtimeConnected,
    MoradonAtmosphereChoice? atmosphereChoice,
    MoradonCelebrationEvent? activeCelebration,
    bool clearCelebration = false,
    List<MoradonPatrolGuard>? patrolGuards,
    double? attackProgress,
    int? comboStage,
    bool? responsiveZoomApplied,
    int? currentChannel,
    int? totalRealmOnline,
    int? channelOnlineCount,
    List<MoradonChannelInfo>? channels,
    bool? is3dPerspective,
    int? comboStreak,
    MoradonStrikeFeedback? activeStrike,
    bool clearActiveStrike = false,
    MoradonMountVisual? mountedSteed,
    MoradonEmoteBubble? activeEmote,
    bool clearActiveEmote = false,
    MoradonWorldBossState? worldBoss,
  }) {
    return MoradonHubState(
      playerX: playerX ?? this.playerX,
      playerY: playerY ?? this.playerY,
      targetX: targetX ?? this.targetX,
      targetY: targetY ?? this.targetY,
      zoom: zoom ?? this.zoom,
      facingRight: facingRight ?? this.facingRight,
      facingBack: facingBack ?? this.facingBack,
      walkPhase: walkPhase ?? this.walkPhase,
      isMoving: isMoving ?? this.isMoving,
      isMerchant: isMerchant ?? this.isMerchant,
      merchantTitle: clearMerchantTitle
          ? null
          : (merchantTitle ?? this.merchantTitle),
      classicViewMode: classicViewMode ?? this.classicViewMode,
      pendingNpcId: clearPendingNpc ? null : (pendingNpcId ?? this.pendingNpcId),
      pendingDummyId:
          clearPendingDummy ? null : (pendingDummyId ?? this.pendingDummyId),
      pendingWorldBossAttack:
          pendingWorldBossAttack ?? this.pendingWorldBossAttack,
      activeNpcDialog: clearActiveNpcDialog
          ? null
          : (activeNpcDialog ?? this.activeNpcDialog),
      selectedRemoteUserId: clearSelectedRemoteUser
          ? null
          : (selectedRemoteUserId ?? this.selectedRemoteUserId),
      moveRingPosition: clearMoveRing
          ? null
          : (moveRingPosition ?? this.moveRingPosition),
      remotePlayers: remotePlayers ?? this.remotePlayers,
      chatBubbles: chatBubbles ?? this.chatBubbles,
      realtimeConnected: realtimeConnected ?? this.realtimeConnected,
      atmosphereChoice: atmosphereChoice ?? this.atmosphereChoice,
      activeCelebration: clearCelebration
          ? null
          : (activeCelebration ?? this.activeCelebration),
      patrolGuards: patrolGuards ?? this.patrolGuards,
      attackProgress: attackProgress ?? this.attackProgress,
      comboStage: comboStage ?? this.comboStage,
      responsiveZoomApplied:
          responsiveZoomApplied ?? this.responsiveZoomApplied,
      currentChannel: currentChannel ?? this.currentChannel,
      totalRealmOnline: totalRealmOnline ?? this.totalRealmOnline,
      channelOnlineCount: channelOnlineCount ?? this.channelOnlineCount,
      channels: channels ?? this.channels,
      is3dPerspective: is3dPerspective ?? this.is3dPerspective,
      comboStreak: comboStreak ?? this.comboStreak,
      activeStrike:
          clearActiveStrike ? null : (activeStrike ?? this.activeStrike),
      mountedSteed: mountedSteed ?? this.mountedSteed,
      activeEmote:
          clearActiveEmote ? null : (activeEmote ?? this.activeEmote),
      worldBoss: worldBoss ?? this.worldBoss,
    );
  }
}

class MoradonHubNotifier extends Notifier<MoradonHubState> {
  Timer? _tickTimer;
  Timer? _ambientRoamTimer;
  final Stopwatch _tickWatch = Stopwatch();
  int _lastTickMicros = 0;
  double _idleAccumulatedDt = 0.0;
  RealtimeChannel? _channel;
  DateTime _lastMoveBroadcast = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAttackAt = DateTime.fromMillisecondsSinceEpoch(0);
  Offset _joystickVector = Offset.zero;
  PlayerProfile? _localProfile;
  int _localTotalPower = 100;
  String _lastSyncedPresenceSignature = '';
  final math.Random _rng = math.Random();
  int _ambientCycleTick = 0;
  int _strikeSeqCounter = 0;
  bool _worldViewMounted = true;
  int _activeTickIntervalMs = 16;

  @override
  MoradonHubState build() {
    GraphicsQualityService.instance.addListener(_onGraphicsProfileChanged);
    ref.onDispose(() {
      GraphicsQualityService.instance.removeListener(_onGraphicsProfileChanged);
      _disposeResources();
    });
    return const MoradonHubState();
  }

  void _onGraphicsProfileChanged() {
    if (!_worldViewMounted || _tickTimer == null) return;
    final int desiredMs =
        GraphicsQualityService.instance.profile.moradonTickIntervalMs;
    if (desiredMs != _activeTickIntervalMs) {
      _activeTickIntervalMs = desiredMs;
      _tickTimer?.cancel();
      _lastTickMicros = _tickWatch.elapsedMicroseconds;
      _tickTimer = Timer.periodic(Duration(milliseconds: desiredMs), (_) {
        _onTick();
      });
    }
  }

  /// Pauses Moradon simulation timers when [MoradonWorldView] is off-screen
  /// (e.g. while inside Dungeon Battle, Inventory, Market, or Settings) so
  /// background tabs burn 0% CPU and trigger 0 provider rebuilds.
  void setWorldViewActive(bool active) {
    if (_worldViewMounted == active) return;
    _worldViewMounted = active;
    if (!active) {
      _joystickVector = Offset.zero;
      _tickTimer?.cancel();
      _tickTimer = null;
      _ambientRoamTimer?.cancel();
      _ambientRoamTimer = null;
    } else if (_localProfile != null) {
      _startLoops();
    }
  }

  void _disposeResources() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _ambientRoamTimer?.cancel();
    _ambientRoamTimer = null;
    _leaveActiveRealtimeChannel();
  }

  void _leaveActiveRealtimeChannel({String? overrideLeavingId}) {
    final RealtimeChannel? ch = _channel;
    final String? leavingId = overrideLeavingId ?? _localProfile?.id;
    _channel = null;
    if (ch != null) {
      if (leavingId != null && leavingId.isNotEmpty) {
        unawaited(
          ch
              .sendBroadcastMessage(
                event: 'player_leave',
                payload: <String, dynamic>{'user_id': leavingId},
              )
              .catchError((Object _) => ChannelResponse.ok),
        );
      }
      unawaited(ch.unsubscribe());
    }
  }

  void bindLocalProfile(PlayerProfile profile, {required int totalPower}) {
    final bool firstBind = _localProfile?.id != profile.id;
    final String? previousId = _localProfile?.id;
    final String nextSig =
        '${profile.id}|${profile.username}|${profile.level}|'
        '${profile.characterClass?.name}|${profile.guildName}|'
        '${profile.cosmeticTitle}|$totalPower|${state.isMerchant}|'
        '${state.merchantTitle}';
    _localProfile = profile;
    _localTotalPower = totalPower;

    if (firstBind) {
      _lastSyncedPresenceSignature = nextSig;
      _leaveActiveRealtimeChannel(overrideLeavingId: previousId);
      state = state.copyWith(
        remotePlayers: const <String, MoradonPlayerPresence>{},
      );
      _seedAmbientPopulation();
      if (_worldViewMounted) {
        _startLoops();
      }
      unawaited(_bootstrapChannelAndPresence());
    } else if (nextSig != _lastSyncedPresenceSignature) {
      _lastSyncedPresenceSignature = nextSig;
      unawaited(_trackMyPresence());
    }
  }

  Future<void> _bootstrapChannelAndPresence() async {
    await _syncMyServerPresence(autoBalance: true);
    await _connectRealtime();
    await Future.wait(<Future<void>>[
      _refreshChannelPopulations(),
      _loadRealPlayersSnapshot(),
    ]);
  }

  /// Switches player to another Moradon shard (`Moradon-1 .. Moradon-N`) for 10,000+ CCU load distribution.
  Future<void> switchChannel(int nextChannelId) async {
    final int clamped = nextChannelId.clamp(1, 80);
    if (clamped == state.currentChannel && state.realtimeConnected) {
      await _refreshChannelPopulations();
      return;
    }

    _leaveActiveRealtimeChannel();

    // Retain ambient town NPCs/merchants while clearing previous shard's remote players
    final Map<String, MoradonPlayerPresence> keptAmbient =
        <String, MoradonPlayerPresence>{
      for (final MapEntry<String, MoradonPlayerPresence> e
          in state.remotePlayers.entries)
        if (e.value.isAmbientBot) e.key: e.value,
    };

    state = state.copyWith(
      currentChannel: clamped,
      realtimeConnected: false,
      remotePlayers: keptAmbient,
      clearSelectedRemoteUser: true,
    );

    await _syncMyServerPresence(autoBalance: false);
    await _connectRealtime();
    await Future.wait(<Future<void>>[
      _refreshChannelPopulations(),
      _loadRealPlayersSnapshot(),
    ]);
  }

  Future<void> refreshShardDirectory() async {
    await _refreshChannelPopulations();
  }

  Future<void> _syncMyServerPresence({required bool autoBalance}) async {
    if (!SupabaseService.isInitialized || _localProfile == null) return;
    try {
      final dynamic res = await SupabaseService.client
          .rpc(
            'sync_moradon_presence',
            params: <String, dynamic>{
              'p_channel': state.currentChannel,
              'p_x': state.playerX.round(),
              'p_y': state.playerY.round(),
              'p_auto_balance': autoBalance,
            },
          )
          .timeout(const Duration(seconds: 5));
      if (res is Map && res['success'] == true) {
        final int assigned =
            ((res['assigned_channel'] as num?)?.toInt() ?? state.currentChannel)
                .clamp(1, 80);
        if (assigned != state.currentChannel) {
          state = state.copyWith(currentChannel: assigned);
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshChannelPopulations() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final dynamic res = await SupabaseService.client
          .rpc('get_moradon_channel_populations')
          .timeout(const Duration(seconds: 5));
      if (res is Map && res['success'] == true && res['channels'] is List) {
        final int totalRealm =
            math.max(1, (res['total_realm_online'] as num?)?.toInt() ?? 1);
        final List<MoradonChannelInfo> parsed = <MoradonChannelInfo>[];
        int myShardOnline = 1;
        for (final dynamic item in res['channels'] as List<dynamic>) {
          if (item is Map) {
            final MoradonChannelInfo info = MoradonChannelInfo.fromJson(
              Map<String, dynamic>.from(item),
            );
            parsed.add(info);
            if (info.channelId == state.currentChannel) {
              myShardOnline = math.max(1, info.onlineCount);
            }
          }
        }
        if (parsed.isNotEmpty) {
          state = state.copyWith(
            totalRealmOnline: totalRealm,
            channelOnlineCount: myShardOnline,
            channels: parsed,
          );
        }
      }
    } catch (_) {}
  }

  void setZoom(double nextZoom) {
    state = state.copyWith(
      zoom: nextZoom.clamp(
        MoradonHubState.minWorldZoom,
        MoradonHubState.maxWorldZoom,
      ),
      responsiveZoomApplied: true,
    );
  }

  void ensureResponsiveZoom(double viewportWidth) {
    if (state.responsiveZoomApplied) return;
    // Panoramic native-4K framing: shows Obsidian Fountain, Gothic Pillars, Braziers & Dummies crisply
    final double idealZoom = viewportWidth < 680 ? 0.34 : 0.62;
    state = state.copyWith(
      zoom: idealZoom,
      responsiveZoomApplied: true,
    );
  }

  void adjustZoom(double delta) {
    setZoom(state.zoom + delta);
  }

  void toggle3dPerspective() {
    state = state.copyWith(is3dPerspective: !state.is3dPerspective);
  }

  /// Cycles player mount (`Yaya -> Kızıl Yıldırım -> Gölge Yele -> Yaya`) with `+34%` speed boost & gallop SFX.
  void toggleMount({MoradonMountVisual? explicitMount}) {
    const List<MoradonMountVisual> order = MoradonMountVisual.values;
    final MoradonMountVisual next = explicitMount ??
        order[(order.indexOf(state.mountedSteed) + 1) % order.length];
    state = state.copyWith(
      mountedSteed: next,
      isMerchant: next.isMounted ? false : state.isMerchant,
      clearMerchantTitle: next.isMounted,
    );
    if (next.isMounted) {
      unawaited(GameSfxService.instance.play(GameSfx.gallopBoost));
      unawaited(AppHaptics.medium());
    } else {
      unawaited(AppHaptics.selection());
    }
  }

  /// Displays a floating MMO emote crest above the player and triggers a victory flourish.
  void triggerEmote(String emoteId) {
    final ({String id, String emoji, String labelTr, Color accent}) spec =
        kMoradonQuickEmotes.firstWhere(
      (({String id, String emoji, String labelTr, Color accent}) e) =>
          e.id == emoteId,
      orElse: () => kMoradonQuickEmotes.first,
    );
    final DateTime now = DateTime.now();
    final MoradonEmoteBubble bubble = MoradonEmoteBubble(
      id: spec.id,
      emoji: spec.emoji,
      labelTr: spec.labelTr,
      accentColor: spec.accent,
      createdAt: now,
      expiresAt: now.add(const Duration(milliseconds: 4500)),
    );
    state = state.copyWith(
      activeEmote: bubble,
      attackProgress: 0.02,
      comboStage: 2,
    );
    unawaited(
      GameSfxService.instance.play(
        spec.id == 'prestige' ? GameSfx.legendaryDrop : GameSfx.siegeHorn,
      ),
    );
    unawaited(AppHaptics.medium());
  }

  /// Cycles through quick emotes with 1-tap from the mobile HUD.
  void cycleQuickEmote() {
    final String? curId = state.activeEmote?.id;
    final int curIdx = kMoradonQuickEmotes.indexWhere(
      (({String id, String emoji, String labelTr, Color accent}) e) =>
          e.id == curId,
    );
    final int nextIdx = (curIdx + 1) % kMoradonQuickEmotes.length;
    triggerEmote(kMoradonQuickEmotes[nextIdx].id);
  }

  /// Summons or dismisses the Moradon Plaza World Boss Raid (`Kadim Yıkım Tiranı`).
  void toggleWorldBossRaid({bool? forceActive}) {
    final bool shouldSpawn =
        forceActive ?? (!state.worldBoss.isActive || state.worldBoss.isDefeated);
    if (!shouldSpawn) {
      state = state.copyWith(
        worldBoss: state.worldBoss.copyWith(isActive: false),
      );
      unawaited(AppHaptics.selection());
      return;
    }
    final int scaledMaxHp = math.max(18000, _localTotalPower * 6);
    state = state.copyWith(
      worldBoss: MoradonWorldBossState(
        isActive: true,
        currentHp: scaledMaxHp,
        maxHp: scaledMaxHp,
        myContribution: 0,
        mvpUsername: _localProfile?.username ?? 'Gölge Sancak',
      ),
    );
    unawaited(GameSfxService.instance.play(GameSfx.siegeHorn));
    unawaited(AppHaptics.criticalImpact());
  }

  bool get _isLocalRangedClass =>
      _localProfile?.characterClass == CharacterClass.alchemist;

  double get _dummyMeleeReach => _isLocalRangedClass ? 235.0 : 175.0;

  double get _bossMeleeReach => _isLocalRangedClass ? 290.0 : 240.0;

  MoradonTrainingDummy? _findDummy(String id) {
    for (final MoradonTrainingDummy d in kMoradonTrainingDummies) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _approachCombatTarget({
    required double destX,
    required double destY,
    required double lookAtX,
    String? dummyId,
    bool worldBoss = false,
    bool playPrepSlash = false,
    int prepComboStage = 0,
  }) {
    _joystickVector = Offset.zero;
    final Offset standPt = _clampToWalkablePlaza(destX, destY);
    final double sdx = standPt.dx - state.playerX;
    final double sdy = standPt.dy - state.playerY;
    state = state.copyWith(
      targetX: standPt.dx,
      targetY: standPt.dy,
      facingRight: lookAtX >= state.playerX,
      facingBack: sdy < -8.0 && sdy.abs() > sdx.abs() * 0.25,
      isMoving: true,
      pendingDummyId: dummyId,
      clearPendingDummy: dummyId == null,
      pendingWorldBossAttack: worldBoss,
      clearPendingNpc: true,
      clearActiveNpcDialog: true,
      clearSelectedRemoteUser: true,
      moveRingPosition: standPt,
      attackProgress: playPrepSlash ? 0.02 : state.attackProgress,
      comboStage: playPrepSlash ? prepComboStage : state.comboStage,
    );
    if (playPrepSlash) {
      unawaited(GameSfxService.instance.play(GameSfx.swordSlash));
    }
    _throttledBroadcastMove(standPt.dx, standPt.dy);
  }

  /// Walks within melee reach of the Moradon World Boss or strikes immediately if close.
  void interactWithWorldBoss() {
    if (state.isMerchant ||
        !state.worldBoss.isActive ||
        state.worldBoss.isDefeated) {
      return;
    }
    final double dx = state.worldBoss.x - state.playerX;
    final double dy = state.worldBoss.y - state.playerY;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= _bossMeleeReach) {
      triggerHeroAttack(targetWorldBoss: true);
      return;
    }
    _approachCombatTarget(
      destX: state.worldBoss.x +
          (state.playerX <= state.worldBoss.x ? -135.0 : 135.0),
      destY: state.worldBoss.y + 14.0,
      lookAtX: state.worldBoss.x,
      worldBoss: true,
    );
  }

  /// Walks within melee reach of a Royal Training Dummy or immediately strikes it if close.
  void interactWithTrainingDummy(MoradonTrainingDummy dummy) {
    if (state.isMerchant) return;
    final double dx = dummy.x - state.playerX;
    final double dy = dummy.y - state.playerY;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= _dummyMeleeReach) {
      triggerHeroAttack(targetDummy: dummy);
      return;
    }
    _approachCombatTarget(
      destX: dummy.x + (state.playerX <= dummy.x ? -96.0 : 96.0),
      destY: dummy.y + 12.0,
      lookAtX: dummy.x,
      dummyId: dummy.id,
    );
  }

  /// Triggers a 60 FPS 3-hit class weapon/spell combo animation (Slash 1 -> Cross 2 -> Finisher 3).
  /// Deals damage & stacks combo ONLY when striking a valid combat target in melee reach
  /// (Royal Training Dummy or active World Boss) — never across empty air or on Safe Zone citizens.
  void triggerHeroAttack({
    MoradonTrainingDummy? targetDummy,
    bool targetWorldBoss = false,
  }) {
    if (state.isMerchant) return;
    final DateTime now = DateTime.now();
    final int gapMs = now.difference(_lastAttackAt).inMilliseconds;
    final bool continueCombo = gapMs <= 1450;
    final bool keepStreak = gapMs <= 3400;
    final int nextCombo = continueCombo ? ((state.comboStage + 1) % 3) : 0;

    final double bossReach = _bossMeleeReach;
    final double dummyReach = _dummyMeleeReach;

    // 1. Check Moradon Plaza World Boss Raid in melee reach (or explicit boss strike)
    bool hitWorldBoss = false;
    double bossDist = double.infinity;
    if (state.worldBoss.isActive && !state.worldBoss.isDefeated) {
      final double bdx = state.worldBoss.x - state.playerX;
      final double bdy = state.worldBoss.y - state.playerY;
      bossDist = math.sqrt(bdx * bdx + bdy * bdy);
      if (targetWorldBoss || (targetDummy == null && bossDist <= bossReach)) {
        hitWorldBoss = true;
      }
    }

    // 2. Check Royal Training Dummy strictly within melee reach
    MoradonTrainingDummy? hitDummy;
    if (!hitWorldBoss) {
      if (targetDummy != null) {
        final double tdx = targetDummy.x - state.playerX;
        final double tdy = targetDummy.y - state.playerY;
        if (math.sqrt(tdx * tdx + tdy * tdy) <= dummyReach + 24.0) {
          hitDummy = targetDummy;
        }
      }
      if (hitDummy == null) {
        double bestDummyDist = dummyReach;
        for (final MoradonTrainingDummy d in kMoradonTrainingDummies) {
          final double dx = d.x - state.playerX;
          final double dy = d.y - state.playerY;
          final double dist = math.sqrt(dx * dx + dy * dy);
          if (dist <= bestDummyDist) {
            bestDummyDist = dist;
            hitDummy = d;
          }
        }
      }
    }

    // 3. Auto-approach if player tapped Attack near a Boss (<= 680px) or Dummy (<= 620px)
    if (!hitWorldBoss &&
        hitDummy == null &&
        !targetWorldBoss &&
        targetDummy == null) {
      if (state.worldBoss.isActive &&
          !state.worldBoss.isDefeated &&
          bossDist <= 680.0) {
        _approachCombatTarget(
          destX: state.worldBoss.x +
              (state.playerX <= state.worldBoss.x ? -135.0 : 135.0),
          destY: state.worldBoss.y + 14.0,
          lookAtX: state.worldBoss.x,
          worldBoss: true,
          playPrepSlash: true,
          prepComboStage: nextCombo,
        );
        return;
      }

      MoradonTrainingDummy? approachDummy;
      double nearestDist = 620.0;
      for (final MoradonTrainingDummy d in kMoradonTrainingDummies) {
        final double dx = d.x - state.playerX;
        final double dy = d.y - state.playerY;
        final double dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= nearestDist) {
          nearestDist = dist;
          approachDummy = d;
        }
      }
      if (approachDummy != null) {
        _approachCombatTarget(
          destX: approachDummy.x +
              (state.playerX <= approachDummy.x ? -96.0 : 96.0),
          destY: approachDummy.y + 12.0,
          lookAtX: approachDummy.x,
          dummyId: approachDummy.id,
          playPrepSlash: true,
          prepComboStage: nextCombo,
        );
        return;
      }

      // 4. Open-space flourish in Safe Zone: play slash animation & whoosh ONLY (no fake damage/combo)
      _lastAttackAt = now;
      unawaited(GameSfxService.instance.play(GameSfx.swordSlash));
      state = state.copyWith(
        attackProgress: 0.02,
        comboStage: nextCombo,
        comboStreak: 0,
        clearActiveStrike: true,
      );
      final RealtimeChannel? openCh = _channel;
      final String? openMyId = _localProfile?.id;
      if (openCh != null && state.realtimeConnected && openMyId != null) {
        unawaited(
          openCh.sendBroadcastMessage(
            event: 'player_attack',
            payload: <String, dynamic>{
              'user_id': openMyId,
              'combo_stage': nextCombo,
              'facing_right': state.facingRight,
            },
          ),
        );
      }
      return;
    }

    // 5. Confirmed melee hit on World Boss or Training Dummy!
    _lastAttackAt = now;
    final int nextStreak = keepStreak ? (state.comboStreak + 1) : 1;
    final bool faceRight = hitWorldBoss
        ? state.worldBoss.x >= state.playerX
        : (hitDummy != null
            ? hitDummy.x >= state.playerX
            : state.facingRight);

    final bool isCrit = nextCombo == 2 || _rng.nextDouble() < 0.28;
    final double comboMult =
        1.0 + math.min(nextStreak, 15) * 0.06 + (isCrit ? 0.58 : 0.0);
    final int basePwr = math.max(120, _localTotalPower);
    final int rawDamage = ((basePwr *
                (0.32 + _rng.nextDouble() * 0.09) *
                comboMult) *
            (hitWorldBoss ? 2.1 : 1.0))
        .round();
    final double popupX = hitWorldBoss ? state.worldBoss.x : hitDummy!.x;
    final double popupY = hitWorldBoss
        ? state.worldBoss.y - 195.0
        : hitDummy!.y - 125.0;

    final MoradonStrikeFeedback feedback = MoradonStrikeFeedback(
      seq: ++_strikeSeqCounter,
      damage: rawDamage,
      isCritical: isCrit,
      comboStreak: nextStreak,
      worldX: popupX,
      worldY: popupY,
      hitDummyId: hitWorldBoss ? 'world_boss_tyrant' : hitDummy?.id,
      createdAt: now,
    );

    unawaited(
      GameSfxService.instance.play(
        isCrit ? GameSfx.criticalSlash : GameSfx.swordSlash,
      ),
    );

    MoradonWorldBossState nextBoss = state.worldBoss;
    bool defeatedBossJustNow = false;
    if (hitWorldBoss) {
      final int nextHp = math.max(0, state.worldBoss.currentHp - rawDamage);
      final int nextContrib = state.worldBoss.myContribution + rawDamage;
      defeatedBossJustNow = state.worldBoss.currentHp > 0 && nextHp == 0;
      nextBoss = state.worldBoss.copyWith(
        currentHp: nextHp,
        myContribution: nextContrib,
        mvpUsername: _localProfile?.username ?? state.worldBoss.mvpUsername,
        lastHitAt: now,
        defeatedAt: defeatedBossJustNow ? now : state.worldBoss.defeatedAt,
      );
    }

    state = state.copyWith(
      isMoving: false,
      targetX: state.playerX,
      targetY: state.playerY,
      clearMoveRing: true,
      clearPendingDummy: true,
      pendingWorldBossAttack: false,
      attackProgress: 0.02,
      comboStage: nextCombo,
      comboStreak: nextStreak,
      activeStrike: feedback,
      facingRight: faceRight,
      worldBoss: nextBoss,
    );

    if (defeatedBossJustNow) {
      unawaited(GameSfxService.instance.play(GameSfx.legendaryDrop));
      unawaited(AppHaptics.legendaryDropPulse());
      triggerTownCelebration(
        username: _localProfile?.username ?? 'Savaşçı',
        itemName: 'Kadim Yıkım Tiranı Hazine Sandığı',
        enhancementLevel: 10,
        originNpcId: 'monument_center',
        broadcast: false,
      );
    }

    final RealtimeChannel? ch = _channel;
    final String? myId = _localProfile?.id;
    if (ch != null && state.realtimeConnected && myId != null) {
      unawaited(
        ch.sendBroadcastMessage(
          event: 'player_attack',
          payload: <String, dynamic>{
            'user_id': myId,
            'combo_stage': nextCombo,
            'facing_right': faceRight,
          },
        ),
      );
    }
  }

  void interactNearestNpc() {
    MoradonNpcDefinition? best;
    double bestDist = double.infinity;
    for (final MoradonNpcDefinition npc in kMoradonNpcs) {
      final double dx = npc.x - state.playerX;
      final double dy = (npc.y + 45.0) - state.playerY;
      final double d = math.sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        best = npc;
      }
    }
    if (best != null) {
      interactWithNpc(best);
    }
  }

  void cycleAtmosphereChoice() {
    const List<MoradonAtmosphereChoice> order = MoradonAtmosphereChoice.values;
    final int nextIdx =
        (order.indexOf(state.atmosphereChoice) + 1) % order.length;
    state = state.copyWith(atmosphereChoice: order[nextIdx]);
  }

  void triggerTownCelebration({
    required String username,
    required String itemName,
    required int enhancementLevel,
    String originNpcId = 'magic_anvil',
    bool broadcast = true,
  }) {
    final DateTime now = DateTime.now();
    final MoradonCelebrationEvent event = MoradonCelebrationEvent(
      id: '${now.millisecondsSinceEpoch}_$username',
      username: username,
      itemName: itemName,
      enhancementLevel: enhancementLevel,
      originNpcId: originNpcId,
      startedAt: now,
      expiresAt: now.add(const Duration(milliseconds: 7200)),
    );
    state = state.copyWith(activeCelebration: event);

    final RealtimeChannel? ch = _channel;
    if (broadcast && ch != null && state.realtimeConnected) {
      unawaited(
        ch.sendBroadcastMessage(
          event: 'town_celebration',
          payload: <String, dynamic>{
            'username': username,
            'item_name': itemName,
            'enhancement_level': enhancementLevel,
            'origin_npc_id': originNpcId,
          },
        ),
      );
    }
  }

  void _seedAmbientPopulation() {
    final Map<String, MoradonPlayerPresence> seeded =
        Map<String, MoradonPlayerPresence>.from(state.remotePlayers);

    final List<MoradonPlayerPresence> defaults = <MoradonPlayerPresence>[
      const MoradonPlayerPresence(
        userId: 'ambient_merchant_1',
        username: 'xKralPazarci',
        characterClass: 'savasci',
        guildName: 'GÖLGE SANCAK',
        cosmeticTitle: 'Başkent Baronu',
        level: 62,
        totalPower: 14850,
        x: 4760,
        y: 1740,
        targetX: 4760,
        targetY: 1740,
        facingRight: false,
        isMerchant: true,
        merchantTitle: '+8 Illusion Sabre & Kutsal Rune Pazarı',
        weaponGlowLevel: 9,
        weaponVisual: MoradonWeaponVisual.illusionSabre,
        weaponLabel: '+8 Illusion Sabre',
        petVisual: MoradonPetVisual.solarPhoenix,
        isAmbientBot: true,
      ),
      const MoradonPlayerPresence(
        userId: 'ambient_merchant_2',
        username: 'SimyaciMiriam',
        characterClass: 'simyaci',
        guildName: 'ARKANA',
        cosmeticTitle: 'İksir Ustası',
        level: 54,
        totalPower: 11120,
        x: 4880,
        y: 2180,
        targetX: 4880,
        targetY: 2180,
        facingRight: false,
        isMerchant: true,
        merchantTitle: 'Yüksek Sınıf Parşömen & Detox İksiri',
        weaponGlowLevel: 8,
        weaponVisual: MoradonWeaponVisual.aetherStaff,
        weaponLabel: '+8 Aether Asası',
        petVisual: MoradonPetVisual.arcaneWisp,
        isAmbientBot: true,
      ),
      const MoradonPlayerPresence(
        userId: 'ambient_merchant_3',
        username: 'ZirhciBorin',
        characterClass: 'savasci',
        guildName: 'KERVANSARAY',
        cosmeticTitle: 'Usta Tüccar',
        level: 58,
        totalPower: 12940,
        x: 4580,
        y: 1960,
        targetX: 4580,
        targetY: 1960,
        facingRight: false,
        isMerchant: true,
        merchantTitle: '+9 Aether Bulwark & Saf Celestium',
        weaponGlowLevel: 9,
        weaponVisual: MoradonWeaponVisual.imperialHalberd,
        weaponLabel: '+9 Imperial Halberd',
        petVisual: MoradonPetVisual.royalGriffin,
        isAmbientBot: true,
      ),
      const MoradonPlayerPresence(
        userId: 'ambient_roamer_1',
        username: 'GeceAvcisi',
        characterClass: 'golge',
        guildName: 'NEMESIS',
        cosmeticTitle: 'Gece Avcısı',
        level: 68,
        totalPower: 18200,
        x: 2360,
        y: 1960,
        targetX: 1620,
        targetY: 1960,
        weaponGlowLevel: 10,
        weaponVisual: MoradonWeaponVisual.twilightFang,
        weaponLabel: '+10 Twilight Fang',
        petVisual: MoradonPetVisual.shadowRaven,
        isAmbientBot: true,
      ),
      const MoradonPlayerPresence(
        userId: 'ambient_roamer_2',
        username: 'DemirKalkan',
        characterClass: 'savasci',
        guildName: 'DEMİR MUHAFIZ',
        cosmeticTitle: 'Kuşatma Komutanı',
        level: 59,
        totalPower: 13340,
        x: 3360,
        y: 1520,
        targetX: 3240,
        targetY: 1140,
        facingRight: false,
        weaponGlowLevel: 9,
        weaponVisual: MoradonWeaponVisual.imperialHalberd,
        weaponLabel: '+9 Imperial Halberd',
        petVisual: MoradonPetVisual.royalGriffin,
        isAmbientBot: true,
      ),
      const MoradonPlayerPresence(
        userId: 'ambient_roamer_3',
        username: 'AetherSimyaci',
        characterClass: 'simyaci',
        guildName: 'KODEX',
        cosmeticTitle: 'Mistik Üstat',
        level: 47,
        totalPower: 8890,
        x: 2380,
        y: 2340,
        targetX: 3980,
        targetY: 2340,
        weaponGlowLevel: 8,
        weaponVisual: MoradonWeaponVisual.aetherStaff,
        weaponLabel: '+8 Aether Asası',
        petVisual: MoradonPetVisual.arcaneWisp,
        isAmbientBot: true,
      ),
    ];

    for (final MoradonPlayerPresence p in defaults) {
      seeded[p.userId] = p;
    }

    const List<MoradonPatrolGuard> guards = <MoradonPatrolGuard>[
      MoradonPatrolGuard(
        id: 'guard_west_patrol',
        name: 'Kraliyet Muhafızı',
        title: 'Batı Ocak Bulvarı Devriyesi',
        totalPower: 45800,
        waypoints: <Offset>[
          Offset(2520, 1820),
          Offset(1680, 1860),
          Offset(1720, 2240),
          Offset(2540, 2280),
        ],
        targetWaypointIndex: 1,
        x: 2520,
        y: 1820,
        facingRight: false,
        facingBack: false,
      ),
      MoradonPatrolGuard(
        id: 'guard_east_patrol',
        name: 'Kraliyet Muhafızı',
        title: 'Doğu Kemer Bulvarı Devriyesi',
        totalPower: 47200,
        waypoints: <Offset>[
          Offset(3880, 1820),
          Offset(4660, 1840),
          Offset(4640, 2260),
          Offset(3880, 2280),
        ],
        targetWaypointIndex: 1,
        x: 3880,
        y: 1820,
        facingRight: true,
        facingBack: false,
      ),
      MoradonPatrolGuard(
        id: 'guard_north_patrol',
        name: 'Kraliyet Muhafızı',
        title: 'Kuzey Zindan Geçidi Muhafızı',
        totalPower: 51400,
        waypoints: <Offset>[
          Offset(2980, 1620),
          Offset(2980, 1140),
          Offset(3420, 1140),
          Offset(3420, 1620),
        ],
        targetWaypointIndex: 1,
        x: 2980,
        y: 1620,
        facingRight: true,
        facingBack: true,
      ),
    ];

    final Map<String, MoradonChatBubble> bubbles =
        Map<String, MoradonChatBubble>.from(state.chatBubbles);
    bubbles['ambient_merchant_1'] = MoradonChatBubble(
      userId: 'ambient_merchant_1',
      username: 'xKralPazarci',
      message: '🔥 Doğu Kervansarayda +8 Illusion Sabre & Kutsal Rune!',
      expiresAt: DateTime.now().add(const Duration(seconds: 16)),
    );

    state = state.copyWith(
      remotePlayers: seeded,
      chatBubbles: bubbles,
      patrolGuards: state.patrolGuards.isEmpty ? guards : state.patrolGuards,
    );
  }

  MoradonWeaponVisual _defaultWeaponForClass(String rawClass, int idx) {
    final String lower = rawClass.toLowerCase();
    if (lower.contains('golge') || lower.contains('shadow')) {
      return MoradonWeaponVisual.twilightFang;
    }
    if (lower.contains('simyaci') || lower.contains('alchemist')) {
      return MoradonWeaponVisual.aetherStaff;
    }
    if (idx % 3 == 1) return MoradonWeaponVisual.imperialHalberd;
    if (idx % 3 == 2) return MoradonWeaponVisual.crimsonAxe;
    return MoradonWeaponVisual.illusionSabre;
  }

  String _defaultWeaponLabel(MoradonWeaponVisual vis, int glow) {
    final String name = switch (vis) {
      MoradonWeaponVisual.twilightFang => 'Twilight Fang',
      MoradonWeaponVisual.imperialHalberd => 'Imperial Halberd',
      MoradonWeaponVisual.crimsonAxe => 'Crimson Scar',
      MoradonWeaponVisual.aetherStaff => 'Aether Asası',
      MoradonWeaponVisual.illusionSabre || MoradonWeaponVisual.none =>
        'Illusion Sabre',
    };
    return '+$glow $name';
  }

  MoradonPetVisual _defaultPetForLevel(String rawClass, int level) {
    if (level < 40) return MoradonPetVisual.none;
    final String lower = rawClass.toLowerCase();
    if (lower.contains('golge') || lower.contains('shadow')) {
      return MoradonPetVisual.shadowRaven;
    }
    if (lower.contains('simyaci') || lower.contains('alchemist')) {
      return MoradonPetVisual.arcaneWisp;
    }
    return MoradonPetVisual.solarPhoenix;
  }

  Future<void> _loadRealPlayersSnapshot() async {
    if (!SupabaseService.isInitialized) return;
    try {
      final DateTime nowUtc = DateTime.now().toUtc();
      List<dynamic>? rows;
      int? shardOnlineFromRpc;

      // 1. Primary 10K-CCU Spatial AOI RPC (filtered by shard + camera/player bounding box!)
      try {
        final dynamic rpcRes = await SupabaseService.client
            .rpc(
              'get_online_moradon_players_aoi',
              params: <String, dynamic>{
                'p_channel': state.currentChannel,
                'p_center_x': state.playerX.round(),
                'p_center_y': state.playerY.round(),
                'p_radius': 2600,
                'p_limit': 64,
              },
            )
            .timeout(const Duration(seconds: 6));
        if (rpcRes is Map &&
            rpcRes['success'] == true &&
            rpcRes['entries'] is List) {
          rows = rpcRes['entries'] as List<dynamic>;
          shardOnlineFromRpc = (rpcRes['channel_online'] as num?)?.toInt();
        }
      } catch (_) {}

      // 2. Secondary fallback: non-sharded RPC
      if (rows == null) {
        try {
          final dynamic rpcRes = await SupabaseService.client
              .rpc('get_online_moradon_players')
              .timeout(const Duration(seconds: 6));
          if (rpcRes is Map &&
              rpcRes['success'] == true &&
              rpcRes['entries'] is List) {
            rows = rpcRes['entries'] as List<dynamic>;
          }
        } catch (_) {}
      }

      if (rows == null) return;
      final String? myId = _localProfile?.id;
      final Map<String, MoradonPlayerPresence> updated =
          <String, MoradonPlayerPresence>{
        for (final MapEntry<String, MoradonPlayerPresence> e
            in state.remotePlayers.entries)
          if (e.value.isAmbientBot) e.key: e.value,
      };

      int idx = 0;
      for (final dynamic item in rows) {
        if (item is! Map) continue;
        final String uid = (item['id'] ?? '').toString();
        if (uid.isEmpty || uid == myId) continue;
        if (item['is_online'] == false) continue;

        final DateTime? hospUntil =
            DateTime.tryParse((item['hospital_until'] ?? '').toString());
        final DateTime? prisUntil =
            DateTime.tryParse((item['prison_until'] ?? '').toString());
        if ((hospUntil != null && hospUntil.toUtc().isAfter(nowUtc)) ||
            (prisUntil != null && prisUntil.toUtc().isAfter(nowUtc))) {
          continue;
        }

        final String uname =
            (item['display_name'] ?? item['username'] ?? 'Savaşçı').toString();
        final String cclass = (item['character_class'] ?? 'savasci').toString();
        final int lvl = (item['level'] as num?)?.toInt() ?? 10;
        final int dbPower = (item['power'] as num?)?.toInt() ?? 0;
        final int resolvedPower = dbPower > 0 ? dbPower : (lvl * 500);
        final String? guildName = item['guild_name'] as String?;
        final String? cosmeticTitle = item['cosmetic_title'] as String?;
        final int wpnEnh = (item['weapon_enh'] as num?)?.toInt() ?? 0;
        final String? wpnName = item['weapon_name'] as String?;
        final int glow = wpnEnh > 0
            ? wpnEnh.clamp(1, 10)
            : (lvl >= 75 ? 10 : (lvl >= 50 ? 9 : 7));

        final MoradonPlayerPresence? prev = state.remotePlayers[uid];
        if (prev != null && !prev.isAmbientBot) {
          final Offset clampedPrev = _clampToWalkablePlaza(prev.x, prev.y);
          final Offset clampedTarget =
              _clampToWalkablePlaza(prev.targetX, prev.targetY);
          updated[uid] = prev.copyWith(
            username: uname,
            characterClass: cclass,
            level: lvl,
            totalPower: resolvedPower,
            x: clampedPrev.dx,
            y: clampedPrev.dy,
            targetX: clampedTarget.dx,
            targetY: clampedTarget.dy,
            guildName: guildName ?? prev.guildName,
            cosmeticTitle: cosmeticTitle ?? prev.cosmeticTitle,
            weaponGlowLevel: wpnEnh > 0 ? glow : prev.weaponGlowLevel,
            weaponLabel: (wpnName != null && wpnName.isNotEmpty)
                ? (wpnEnh > 0 ? '+$wpnEnh $wpnName' : wpnName)
                : prev.weaponLabel,
          );
          idx++;
          continue;
        }

        final MoradonWeaponVisual wVis = _resolveWeaponVisualFromDb(
          weaponType: (item['weapon_type'] ?? '').toString(),
          weaponIcon: (item['weapon_icon'] ?? '').toString(),
          classRaw: cclass,
          idx: idx,
        );
        final double? dbX = (item['world_x'] as num?)?.toDouble();
        final double? dbY = (item['world_y'] as num?)?.toDouble();
        final double angle = (idx * 1.15) + 0.5;
        double candX = dbX ?? (3200.0 + math.cos(angle) * 620.0);
        double candY = dbY ?? (2160.0 + math.sin(angle) * 370.0);
        // Prevent legacy DB center spawns from stacking directly behind local hero nameplate
        if ((candX - MoradonHubState.spawnX).abs() < 210.0 &&
            (candY - MoradonHubState.spawnY).abs() < 260.0) {
          candX = MoradonHubState.spawnX +
              (idx.isEven ? -310.0 : 310.0) +
              (idx % 3) * 42.0;
          candY = 2360.0 + (idx % 2) * 85.0;
        }
        final Offset safePt = _clampToWalkablePlaza(candX, candY);
        updated[uid] = MoradonPlayerPresence(
          userId: uid,
          username: uname,
          characterClass: cclass,
          guildName: guildName,
          cosmeticTitle: cosmeticTitle,
          level: lvl,
          totalPower: resolvedPower,
          x: safePt.dx,
          y: safePt.dy,
          targetX: safePt.dx,
          targetY: safePt.dy,
          facingRight: idx.isEven,
          weaponGlowLevel: glow,
          weaponVisual: wVis,
          weaponLabel: (wpnName != null && wpnName.isNotEmpty)
              ? (wpnEnh > 0 ? '+$wpnEnh $wpnName' : wpnName)
              : _defaultWeaponLabel(wVis, glow),
          petVisual: _defaultPetForLevel(cclass, lvl),
          isAmbientBot: false,
        );
        idx++;
      }

      final String? selId = state.selectedRemotePlayer?.userId;
      final bool clearSel = selId != null && !updated.containsKey(selId);
      state = state.copyWith(
        remotePlayers: updated,
        channelOnlineCount: shardOnlineFromRpc != null
            ? math.max(1, shardOnlineFromRpc)
            : state.channelOnlineCount,
        clearSelectedRemoteUser: clearSel,
      );
    } catch (_) {}
  }

  MoradonWeaponVisual _resolveWeaponVisualFromDb({
    required String weaponType,
    required String weaponIcon,
    required String classRaw,
    required int idx,
  }) {
    final String wt = '${weaponType.toLowerCase()} ${weaponIcon.toLowerCase()}';
    if (wt.contains('dagger')) return MoradonWeaponVisual.twilightFang;
    if (wt.contains('staff') || wt.contains('bow')) {
      return MoradonWeaponVisual.aetherStaff;
    }
    if (wt.contains('axe') || wt.contains('mace')) {
      return MoradonWeaponVisual.crimsonAxe;
    }
    if (wt.contains('sword')) return MoradonWeaponVisual.imperialHalberd;
    return _defaultWeaponForClass(classRaw, idx);
  }

  Future<void> _connectRealtime() async {
    if (!SupabaseService.isInitialized || _localProfile == null) return;
    final int shardId = state.currentChannel;
    try {
      final RealtimeChannel channel = SupabaseService.client.channel(
        'moradon_town_ch_$shardId',
        opts: const RealtimeChannelConfig(self: false),
      );
      _channel = channel;

      channel
          .onBroadcast(
            event: 'player_move',
            callback: (Map<String, dynamic> payload) {
              _handleMoveBroadcast(payload);
            },
          )
          .onBroadcast(
            event: 'chat_bubble',
            callback: (Map<String, dynamic> payload) {
              _handleChatBroadcast(payload);
            },
          )
          .onBroadcast(
            event: 'player_sync',
            callback: (Map<String, dynamic> payload) {
              _handlePlayerSyncBroadcast(payload);
            },
          )
          .onBroadcast(
            event: 'player_leave',
            callback: (Map<String, dynamic> payload) {
              final String uid = (payload['user_id'] ?? '').toString();
              if (uid.isEmpty || uid == _localProfile?.id) return;
              final MoradonPlayerPresence? existing = state.remotePlayers[uid];
              if (existing == null || existing.isAmbientBot) return;
              final Map<String, MoradonPlayerPresence> next =
                  Map<String, MoradonPlayerPresence>.from(state.remotePlayers)
                    ..remove(uid);
              final bool clearSel =
                  state.selectedRemotePlayer?.userId == uid;
              state = state.copyWith(
                remotePlayers: next,
                clearSelectedRemoteUser: clearSel,
              );
            },
          )
          .onBroadcast(
            event: 'player_attack',
            callback: (Map<String, dynamic> payload) {
              final String uid = (payload['user_id'] ?? '').toString();
              if (uid.isEmpty || uid == _localProfile?.id) return;
              final MoradonPlayerPresence? existing = state.remotePlayers[uid];
              if (existing == null) return;
              final int stage =
                  ((payload['combo_stage'] as num?)?.toInt() ?? 0).clamp(0, 2);
              final bool faceR =
                  payload['facing_right'] as bool? ?? existing.facingRight;
              final Map<String, MoradonPlayerPresence> next =
                  Map<String, MoradonPlayerPresence>.from(state.remotePlayers);
              next[uid] = existing.copyWith(
                attackProgress: 0.02,
                comboStage: stage,
                facingRight: faceR,
              );
              state = state.copyWith(remotePlayers: next);
            },
          )
          .onBroadcast(
            event: 'town_celebration',
            callback: (Map<String, dynamic> payload) {
              final String uname =
                  (payload['username'] ?? 'Savaşçı').toString();
              final String itemName =
                  (payload['item_name'] ?? 'Imperial Halberd').toString();
              final int enh =
                  (payload['enhancement_level'] as num?)?.toInt() ?? 9;
              final String npcId =
                  (payload['origin_npc_id'] ?? 'magic_anvil').toString();
              triggerTownCelebration(
                username: uname,
                itemName: itemName,
                enhancementLevel: enh,
                originNpcId: npcId,
                broadcast: false,
              );
            },
          )
          .subscribe((RealtimeSubscribeStatus status, Object? error) {
            if (_channel != channel) return;
            if (status == RealtimeSubscribeStatus.subscribed) {
              state = state.copyWith(realtimeConnected: true);
              unawaited(_trackMyPresence());
            } else if (status == RealtimeSubscribeStatus.closed ||
                status == RealtimeSubscribeStatus.channelError) {
              state = state.copyWith(realtimeConnected: false);
            }
          });
    } catch (_) {
      state = state.copyWith(realtimeConnected: false);
    }
  }

  Future<void> _trackMyPresence() async {
    final PlayerProfile? profile = _localProfile;
    final RealtimeChannel? ch = _channel;
    if (profile == null || ch == null || !state.realtimeConnected) return;
    final String cclass = profile.characterClass?.name ?? 'savasci';
    final int glow = _localTotalPower >= 8000
        ? 10
        : (_localTotalPower >= 4000 ? 9 : 7);
    final MoradonWeaponVisual wVis = _defaultWeaponForClass(cclass, 0);
    final MoradonPlayerPresence me = MoradonPlayerPresence(
      userId: profile.id,
      username: profile.username,
      characterClass: cclass,
      guildName: profile.guildName,
      cosmeticTitle: profile.cosmeticTitle,
      level: profile.level,
      totalPower: _localTotalPower,
      x: state.playerX,
      y: state.playerY,
      targetX: state.targetX,
      targetY: state.targetY,
      facingRight: state.facingRight,
      isMerchant: state.isMerchant,
      merchantTitle: state.merchantTitle,
      weaponGlowLevel: glow,
      weaponVisual: wVis,
      weaponLabel: _defaultWeaponLabel(wVis, glow),
      petVisual: _defaultPetForLevel(cclass, profile.level),
    );
    try {
      await ch.sendBroadcastMessage(
        event: 'player_sync',
        payload: me.toJson(),
      );
    } catch (_) {}
  }

  void _handlePlayerSyncBroadcast(Map<String, dynamic> payload) {
    final String uid = (payload['user_id'] ?? '').toString();
    if (uid.isEmpty || uid == _localProfile?.id) return;
    final MoradonPlayerPresence rawIncoming =
        MoradonPlayerPresence.fromJson(payload);
    final Offset safePt = _clampToWalkablePlaza(rawIncoming.x, rawIncoming.y);
    final MoradonPlayerPresence incoming = rawIncoming.copyWith(
      x: safePt.dx,
      y: safePt.dy,
      targetX: safePt.dx,
      targetY: safePt.dy,
    );
    final Map<String, MoradonPlayerPresence> next =
        Map<String, MoradonPlayerPresence>.from(state.remotePlayers);
    final MoradonPlayerPresence? existing = next[uid];
    next[uid] = existing == null
        ? incoming
        : incoming.copyWith(
            x: existing.x,
            y: existing.y,
            targetX: incoming.x,
            targetY: incoming.y,
          );
    state = state.copyWith(remotePlayers: next);
  }

  void _handleMoveBroadcast(Map<String, dynamic> payload) {
    final String uid = (payload['user_id'] ?? '').toString();
    if (uid.isEmpty || uid == _localProfile?.id) return;
    final Offset safeTarget = _clampToWalkablePlaza(
      (payload['x'] as num?)?.toDouble() ?? 3200.0,
      (payload['y'] as num?)?.toDouble() ?? 2360.0,
    );
    final double tx = safeTarget.dx;
    final double ty = safeTarget.dy;

    // 10K-CCU AOI Memory Guard: if we already hold >90 remote players in shard state
    // and this newcomer is >3200px away from us, ignore until within AOI!
    final MoradonPlayerPresence? existing = state.remotePlayers[uid];
    if (existing == null && state.remotePlayers.length > 90) {
      final double dx = tx - state.playerX;
      final double dy = ty - state.playerY;
      if (dx * dx + dy * dy > 3200.0 * 3200.0) {
        return;
      }
    }

    final Map<String, MoradonPlayerPresence> next =
        Map<String, MoradonPlayerPresence>.from(state.remotePlayers);
    if (existing != null) {
      next[uid] = existing.copyWith(
        targetX: tx,
        targetY: ty,
        facingRight: tx >= existing.x,
        isMerchant: payload['is_merchant'] as bool? ?? existing.isMerchant,
        merchantTitle:
            payload['merchant_title'] as String? ?? existing.merchantTitle,
      );
    } else {
      final MoradonPlayerPresence raw = MoradonPlayerPresence.fromJson(payload);
      next[uid] = raw.copyWith(
        x: tx,
        y: ty,
        targetX: tx,
        targetY: ty,
      );
    }
    state = state.copyWith(remotePlayers: next);
  }

  void _handleChatBroadcast(Map<String, dynamic> payload) {
    final String uid = (payload['user_id'] ?? '').toString();
    final String uname = (payload['username'] ?? 'Gezgin').toString();
    final String msg = (payload['message'] ?? '').toString().trim();
    if (uid.isEmpty || msg.isEmpty) return;

    final Map<String, MoradonChatBubble> next =
        Map<String, MoradonChatBubble>.from(state.chatBubbles);
    next[uid] = MoradonChatBubble(
      userId: uid,
      username: uname,
      message: msg,
      expiresAt: DateTime.now().add(const Duration(seconds: 6)),
    );
    state = state.copyWith(chatBubbles: next);
  }

  void _startLoops() {
    if (!_worldViewMounted) return;
    _tickTimer?.cancel();
    _tickWatch
      ..reset()
      ..start();
    _lastTickMicros = 0;
    final int tickMs =
        GraphicsQualityService.instance.profile.moradonTickIntervalMs;
    _activeTickIntervalMs = tickMs;
    _tickTimer = Timer.periodic(Duration(milliseconds: tickMs), (_) {
      _onTick();
    });

    _ambientRoamTimer?.cancel();
    _ambientRoamTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _onAmbientRoam();
    });
  }

  void _onAmbientRoam() {
    if (!AppForegroundService.instance.isForeground) return;
    _ambientCycleTick++;
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final Map<String, MoradonPlayerPresence> updated =
        Map<String, MoradonPlayerPresence>.from(state.remotePlayers);
    bool changed = false;

    if (!gfx.isLow) {
      for (final MapEntry<String, MoradonPlayerPresence> entry
          in updated.entries.toList()) {
        final MoradonPlayerPresence p = entry.value;
        if (!p.isAmbientBot || p.isMerchant) continue;
        if (_rng.nextDouble() > 0.55) continue;

        final MoradonNpcDefinition targetNpc =
            kMoradonNpcs[_rng.nextInt(kMoradonNpcs.length)];
        final Offset safeTarget = _clampToWalkablePlaza(
          targetNpc.x + (_rng.nextDouble() - 0.5) * 340.0,
          targetNpc.y + 95.0 + (_rng.nextDouble() - 0.5) * 190.0,
        );
        final double nx = safeTarget.dx;
        final double ny = safeTarget.dy;
        final double rdx = nx - p.x;
        final double rdy = ny - p.y;

        updated[entry.key] = p.copyWith(
          targetX: nx,
          targetY: ny,
          facingRight: rdx.abs() > 2.5 ? rdx >= 0 : p.facingRight,
          facingBack: rdy < -12.0 && rdy.abs() > rdx.abs() * 0.26,
        );
        changed = true;
      }
    }

    final int prevBubbleCount = state.chatBubbles.length;
    final Map<String, MoradonChatBubble> bubbles =
        Map<String, MoradonChatBubble>.from(state.chatBubbles)
          ..removeWhere((_, MoradonChatBubble b) => b.isExpired);
    if (bubbles.length != prevBubbleCount) {
      changed = true;
    }

    if (!gfx.isLow &&
        _ambientCycleTick % 5 == 0 &&
        _rng.nextDouble() < 0.55) {
      const List<(String, String, String)> shouts = <(String, String, String)>[
        ('guard_west_patrol', 'Kraliyet Muhafızı', '🛡️ 8 Başkent mahallesi ve Kervansaray bulvarları güvenli!'),
        ('ambient_merchant_1', 'xKralPazarci', '🏪 Doğu Kervansaray tezgahları tüm savaşçılara açıktır!'),
        ('ambient_merchant_2', 'SimyaciMiriam', '⚗️ Zindan seferi öncesi iksir ve detoks stoklarınızı kontrol edin!'),
        ('ambient_roamer_1', 'GeceAvcisi', '⚔️ Kuzey Zindan Geçidi\'nde grup seferi hazırlığı var!'),
        ('ambient_roamer_2', 'DemirKalkan', '🏛️ Pantheon anıtında haftalık güç sıralaması güncelleniyor!'),
      ];
      final (String id, String name, String text) pick =
          shouts[_rng.nextInt(shouts.length)];
      bubbles[pick.$1] = MoradonChatBubble(
        userId: pick.$1,
        username: pick.$2,
        message: pick.$3,
        expiresAt: DateTime.now().add(const Duration(seconds: 6)),
      );
      changed = true;
    }

    if (changed) {
      state = state.copyWith(remotePlayers: updated, chatBubbles: bubbles);
    }

    // Every ~16s: sync O(1) server AOI position + refresh nearby AOI players & shard counts!
    if (_ambientCycleTick % 4 == 0) {
      unawaited(_syncMyServerPresence(autoBalance: false));
      unawaited(_loadRealPlayersSnapshot());
      unawaited(_refreshChannelPopulations());
    }
  }

  void _onTick() {
    final int nowMicros = _tickWatch.elapsedMicroseconds;
    if (!AppForegroundService.instance.isForeground) {
      _lastTickMicros = nowMicros;
      _idleAccumulatedDt = 0.0;
      return;
    }
    final double rawDt = _lastTickMicros == 0
        ? 0.016
        : ((nowMicros - _lastTickMicros) / 1000000.0).clamp(0.004, 0.065);
    _lastTickMicros = nowMicros;

    // Adaptive tick throttling: full 60Hz when local hero is moving/attacking/striking;
    // coalesced ~25Hz (40ms) when hero is idle so background roamers don't thrash the UI!
    final bool localActive = state.isMoving ||
        _joystickVector.distance >= 0.08 ||
        state.attackProgress > 0.0 ||
        (state.activeStrike != null && !state.activeStrike!.isExpired);
    double dt;
    if (localActive) {
      dt = rawDt + _idleAccumulatedDt;
      _idleAccumulatedDt = 0.0;
    } else {
      _idleAccumulatedDt += rawDt;
      if (_idleAccumulatedDt < 0.040) {
        return;
      }
      dt = _idleAccumulatedDt.clamp(0.016, 0.085);
      _idleAccumulatedDt = 0.0;
    }

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;

    final double baseSpeed =
        365.0 * state.mountedSteed.speedMultiplier; // +34% speed when mounted!
    double px = state.playerX;
    double py = state.playerY;
    double tx = state.targetX;
    double ty = state.targetY;
    bool faceRight = state.facingRight;
    bool faceBack = state.facingBack;
    double phase = state.walkPhase;
    double nextAtk = state.attackProgress;
    bool atkChanged = false;

    if (nextAtk > 0.0) {
      nextAtk += dt / 0.52;
      if (nextAtk >= 1.0) {
        nextAtk = 0.0;
      }
      atkChanged = true;
    }

    bool movedLocal = false;
    bool nowMoving = false;
    String? pendingNpc = state.pendingNpcId;
    String? pendingDummy = state.pendingDummyId;
    bool pendingBoss = state.pendingWorldBossAttack;
    MoradonTrainingDummy? arrivedDummy;
    bool arrivedBoss = false;
    MoradonNpcDefinition? openDialog = state.activeNpcDialog;
    bool clearRing = false;

    // 1. Continuous 60 FPS Analog Joystick Locomotion
    if (!state.isMerchant && _joystickVector.distance >= 0.08) {
      final double mag = _joystickVector.distance.clamp(0.15, 1.0);
      final Offset dir = _joystickVector / _joystickVector.distance;
      final double step = baseSpeed * mag * dt;
      final Offset nextPt = _clampToWalkablePlaza(
        px + dir.dx * step,
        py + dir.dy * (step / 1.16),
      );
      final Offset slid = _slideAroundFountain(
        nextPt.dx,
        nextPt.dy,
        px + dir.dx * 120.0,
        step,
      );
      px = slid.dx;
      py = slid.dy;
      tx = px;
      ty = py;
      if (_joystickVector.dx.abs() > 0.08) {
        faceRight = _joystickVector.dx >= 0;
      }
      faceBack = _joystickVector.dy < -0.18 &&
          _joystickVector.dy.abs() > _joystickVector.dx.abs() * 0.25;
      phase = (phase + step * 0.030) % (math.pi * 2);
      movedLocal = true;
      nowMoving = true;
      pendingNpc = null;
      pendingDummy = null;
      pendingBoss = false;
      clearRing = true;
      _throttledBroadcastMove(px, py);
    } else {
      // 2. Tap-to-Move / NPC / Combat Target Approach Locomotion
      final double dx = tx - px;
      final double dy = ty - py;
      final double isoDist = math.sqrt(dx * dx + (dy * 1.24) * (dy * 1.24));

      if (!state.isMerchant && isoDist > 2.5) {
        nowMoving = true;
        movedLocal = true;
        final double easeFactor = (isoDist / 32.0).clamp(0.48, 1.0);
        final double step = baseSpeed * easeFactor * dt;

        if (dx.abs() > 2.5) {
          faceRight = dx >= 0;
        }
        if (dy.abs() > 4.0 && dy.abs() > dx.abs() * 0.25) {
          faceBack = dy < 0;
        } else if (dx.abs() > dy.abs() * 1.65) {
          faceBack = false;
        }

        if (isoDist <= step) {
          px = tx;
          py = ty;
          nowMoving = false;
          clearRing = true;
        } else {
          final Offset slid = _slideAroundFountain(
            px + (dx / isoDist) * step,
            py + (dy / isoDist) * step,
            tx,
            step,
          );
          px = slid.dx;
          py = slid.dy;
        }

        phase = (phase + math.min(isoDist, step) * 0.030) % (math.pi * 2);

        if (pendingNpc != null) {
          final MoradonNpcDefinition? npc = _findNpc(pendingNpc);
          if (npc != null) {
            final double ndx = npc.x - px;
            final double ndy = (npc.y + 45.0) - py;
            if (math.sqrt(ndx * ndx + ndy * ndy) <= npc.interactionRadius) {
              openDialog = npc;
              pendingNpc = null;
              nowMoving = false;
              clearRing = true;
              faceRight = npc.x >= px;
              faceBack = npc.y < py - 24.0;
            }
          }
        }

        if (pendingDummy != null) {
          final MoradonTrainingDummy? d = _findDummy(pendingDummy);
          if (d == null) {
            pendingDummy = null;
          } else {
            final double ddx = d.x - px;
            final double ddy = d.y - py;
            if (math.sqrt(ddx * ddx + ddy * ddy) <= _dummyMeleeReach ||
                !nowMoving) {
              arrivedDummy = d;
              pendingDummy = null;
              nowMoving = false;
              clearRing = true;
              tx = px;
              ty = py;
              faceRight = d.x >= px;
            }
          }
        }

        if (pendingBoss) {
          if (!state.worldBoss.isActive || state.worldBoss.isDefeated) {
            pendingBoss = false;
          } else {
            final double bdx = state.worldBoss.x - px;
            final double bdy = state.worldBoss.y - py;
            if (math.sqrt(bdx * bdx + bdy * bdy) <= _bossMeleeReach ||
                !nowMoving) {
              arrivedBoss = true;
              pendingBoss = false;
              nowMoving = false;
              clearRing = true;
              tx = px;
              ty = py;
              faceRight = state.worldBoss.x >= px;
            }
          }
        }
      } else if (state.isMoving ||
          pendingDummy != null ||
          pendingBoss) {
        if (pendingDummy != null) {
          arrivedDummy = _findDummy(pendingDummy);
          pendingDummy = null;
        }
        if (pendingBoss &&
            state.worldBoss.isActive &&
            !state.worldBoss.isDefeated) {
          arrivedBoss = true;
        }
        pendingBoss = false;
        movedLocal = true;
        nowMoving = false;
        clearRing = true;
      }
    }

    // 3. 10K-CCU Fast Remote Tick: Stationary players skip sqrt, collision & Map allocation!
    bool remoteMoved = false;
    Map<String, MoradonPlayerPresence>? nextRemote;
    const double remoteSpeed = 235.0;
    for (final MapEntry<String, MoradonPlayerPresence> e
        in state.remotePlayers.entries) {
      final MoradonPlayerPresence rp = e.value;
      double rAtk = rp.attackProgress;
      bool rAtkChanged = false;
      if (rAtk > 0.0) {
        rAtk += dt / 0.52;
        if (rAtk >= 1.0) rAtk = 0.0;
        rAtkChanged = true;
        remoteMoved = true;
      }

      final double rdx = rp.targetX - rp.x;
      final double rdy = rp.targetY - rp.y;
      if (rp.isMerchant || (rdx.abs() <= 1.5 && rdy.abs() <= 1.5)) {
        if (rAtkChanged) {
          nextRemote ??=
              Map<String, MoradonPlayerPresence>.from(state.remotePlayers);
          nextRemote[e.key] = rp.copyWith(attackProgress: rAtk);
        }
        continue;
      }

      // Off-camera AOI snap: skip per-tick sqrt & fountain slide for distant district players!
      if ((rp.x - px).abs() > 1950.0 || (rp.y - py).abs() > 1450.0) {
        remoteMoved = true;
        nextRemote ??=
            Map<String, MoradonPlayerPresence>.from(state.remotePlayers);
        nextRemote[e.key] = rp.copyWith(
          x: rp.targetX,
          y: rp.targetY,
          facingRight: rdx >= 0,
          attackProgress: rAtk,
        );
        continue;
      }

      final double rIsoDist =
          math.sqrt(rdx * rdx + (rdy * 1.24) * (rdy * 1.24));
      if (rIsoDist > 2.0) {
        remoteMoved = true;
        final double rStep = math.min(rIsoDist, remoteSpeed * dt);
        final bool rRight = rdx.abs() > 2.0 ? rdx >= 0 : rp.facingRight;
        final bool rBack = (rdy.abs() > 4.0 && rdy.abs() > rdx.abs() * 0.25)
            ? (rdy < 0)
            : (rdx.abs() > rdy.abs() * 1.65 ? false : rp.facingBack);
        final Offset rSlid = _slideAroundFountain(
          rp.x + (rdx / rIsoDist) * rStep,
          rp.y + (rdy / rIsoDist) * rStep,
          rp.targetX,
          rStep,
        );
        nextRemote ??=
            Map<String, MoradonPlayerPresence>.from(state.remotePlayers);
        nextRemote[e.key] = rp.copyWith(
          x: rSlid.dx,
          y: rSlid.dy,
          facingRight: rRight,
          facingBack: rBack,
          walkPhase: (rp.walkPhase + rStep * 0.034) % (math.pi * 2),
          attackProgress: rAtk,
        );
      } else if (rAtkChanged) {
        nextRemote ??=
            Map<String, MoradonPlayerPresence>.from(state.remotePlayers);
        nextRemote[e.key] = rp.copyWith(attackProgress: rAtk);
      }
    }

    // 4. Advance Royal Citadel Patrol Guards along closed boulevard loops (skipped on Low tier!)
    bool guardsMoved = false;
    List<MoradonPatrolGuard>? nextGuards;
    if (gfx.moradonEnablePatrolGuards && state.patrolGuards.isNotEmpty) {
      nextGuards = <MoradonPatrolGuard>[];
      const double guardSpeed = 138.0;
      for (final MoradonPatrolGuard g in state.patrolGuards) {
        if (g.waypoints.isEmpty) {
          nextGuards.add(g);
          continue;
        }
        final Offset wp =
            g.waypoints[g.targetWaypointIndex % g.waypoints.length];
        final double gdx = wp.dx - g.x;
        final double gdy = wp.dy - g.y;
        final double gIsoDist =
            math.sqrt(gdx * gdx + (gdy * 1.24) * (gdy * 1.24));
        if (gIsoDist <= 6.0) {
          final int nextWpIdx =
              (g.targetWaypointIndex + 1) % g.waypoints.length;
          nextGuards.add(g.copyWith(targetWaypointIndex: nextWpIdx));
          guardsMoved = true;
        } else {
          final double gStep = math.min(gIsoDist, guardSpeed * dt);
          final bool gRight = gdx.abs() > 1.5 ? gdx >= 0 : g.facingRight;
          final bool gBack = (gdy.abs() > 3.5 && gdy.abs() > gdx.abs() * 0.25)
              ? (gdy < 0)
              : (gdx.abs() > gdy.abs() * 1.65 ? false : g.facingBack);
          nextGuards.add(
            g.copyWith(
              x: g.x + (gdx / gIsoDist) * gStep,
              y: g.y + (gdy / gIsoDist) * gStep,
              facingRight: gRight,
              facingBack: gBack,
              walkPhase: (g.walkPhase + gStep * 0.038) % (math.pi * 2),
            ),
          );
          guardsMoved = true;
        }
      }
    }

    final bool expireCelebration =
        state.activeCelebration != null && state.activeCelebration!.isExpired;
    final bool expireStrike =
        state.activeStrike != null && state.activeStrike!.isExpired;
    final bool expireEmote =
        state.activeEmote != null && state.activeEmote!.isExpired;
    final bool resetStreak = state.comboStreak > 0 &&
        DateTime.now().difference(_lastAttackAt).inMilliseconds > 3600;

    if (movedLocal ||
        atkChanged ||
        remoteMoved ||
        guardsMoved ||
        expireCelebration ||
        expireStrike ||
        expireEmote ||
        resetStreak ||
        pendingDummy != state.pendingDummyId ||
        pendingBoss != state.pendingWorldBossAttack ||
        openDialog != state.activeNpcDialog) {
      state = state.copyWith(
        playerX: px,
        playerY: py,
        targetX: nowMoving ? tx : px,
        targetY: nowMoving ? ty : py,
        facingRight: faceRight,
        facingBack: faceBack,
        walkPhase: phase,
        isMoving: nowMoving,
        attackProgress: nextAtk,
        pendingNpcId: pendingNpc,
        clearPendingNpc: pendingNpc == null,
        pendingDummyId: pendingDummy,
        clearPendingDummy: pendingDummy == null,
        pendingWorldBossAttack: pendingBoss,
        activeNpcDialog: openDialog,
        clearMoveRing: clearRing,
        remotePlayers:
            (remoteMoved && nextRemote != null) ? nextRemote : state.remotePlayers,
        patrolGuards:
            (guardsMoved && nextGuards != null) ? nextGuards : state.patrolGuards,
        clearCelebration: expireCelebration,
        clearActiveStrike: expireStrike,
        clearActiveEmote: expireEmote,
        comboStreak: resetStreak ? 0 : state.comboStreak,
      );
    }

    if (arrivedBoss) {
      triggerHeroAttack(targetWorldBoss: true);
    } else if (arrivedDummy != null) {
      triggerHeroAttack(targetDummy: arrivedDummy);
    }
  }

  MoradonNpcDefinition? _findNpc(String id) {
    for (final MoradonNpcDefinition n in kMoradonNpcs) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Keeps players strictly on the flat dark-cobblestone courtyard of `citadel_dungeon_v9.jpg`,
  /// preventing walking onto perimeter stronghold roofs/walls or into the Central Obsidian Fountain.
  Offset _clampToWalkablePlaza(double rawX, double rawY) {
    double cx = rawX.clamp(1180.0, 5220.0);
    final double minNorthY = (cx >= 2780.0 && cx <= 3620.0) ? 940.0 : 1020.0;
    double cy = rawY.clamp(minNorthY, 3180.0);

    // 1. Isometric perimeter stronghold wall planes (NW Vault, NE War Gate, SW Bastion, SE Tavern)
    final double minNwX = 3380.0 - 1.48 * cy;
    if (cx < minNwX) cx = minNwX;

    final double maxNeX = 6400.0 - (3180.0 - 1.48 * cy);
    if (cx > maxNeX) cx = maxNeX;

    final double minSwX = 2660.0 - 1.35 * (3600.0 - cy);
    if (cx < minSwX) cx = minSwX;

    final double maxSeX = 6400.0 - (2260.0 - 1.42 * (3600.0 - cy));
    if (cx > maxSeX) cx = maxSeX;

    cx = cx.clamp(1180.0, 5220.0);

    // 2. Central Obsidian Arcane Fountain & Octagonal Runic Steps (center: 3200, 2145)
    const double fx = 3200.0;
    const double fy = 2145.0;
    const double rx = 590.0;
    const double ry = 362.0;
    final double nx = (cx - fx) / rx;
    final double ny = (cy - fy) / ry;
    final double normSq = nx * nx + ny * ny;
    if (normSq < 1.0) {
      if (normSq < 0.0001) {
        cy = fy + ry + 14.0;
      } else {
        final double inv = 1.02 / math.sqrt(normSq);
        cx = fx + (cx - fx) * inv;
        cy = fy + (cy - fy) * inv;
      }
    }
    return Offset(cx, cy);
  }

  /// Smoothly steers walking characters around the central octagonal fountain rim.
  Offset _slideAroundFountain(
    double nextX,
    double nextY,
    double targetX,
    double step,
  ) {
    const double fx = 3200.0;
    const double fy = 2145.0;
    const double rx = 590.0;
    const double ry = 362.0;
    final double nx = (nextX - fx) / rx;
    final double ny = (nextY - fy) / ry;
    final double normSq = nx * nx + ny * ny;
    if (normSq >= 1.0) return Offset(nextX, nextY);
    final double side = targetX >= fx ? 1.0 : -1.0;
    final double nudgedX = nextX + side * step * 0.88;
    final double nnx = (nudgedX - fx) / rx;
    final double nny = (nextY - fy) / ry;
    final double nNorm = math.sqrt(math.max(0.0001, nnx * nnx + nny * nny));
    return Offset(
      fx + (nudgedX - fx) / nNorm * 1.005,
      fy + (nextY - fy) / nNorm * 1.005,
    );
  }

  void moveToWorldPoint(double worldX, double worldY) {
    if (state.isMerchant) return;
    _joystickVector = Offset.zero;
    final Offset clamped = _clampToWalkablePlaza(worldX, worldY);
    final double clampedX = clamped.dx;
    final double clampedY = clamped.dy;
    final double dx = clampedX - state.playerX;
    final double dy = clampedY - state.playerY;
    final bool faceRight = dx.abs() > 2.5 ? dx >= 0 : state.facingRight;
    final bool faceBack = (dy.abs() > 4.0 && dy.abs() > dx.abs() * 0.25)
        ? (dy < 0)
        : (dx.abs() > dy.abs() * 1.65 ? false : state.facingBack);

    state = state.copyWith(
      targetX: clampedX,
      targetY: clampedY,
      facingRight: faceRight,
      facingBack: faceBack,
      isMoving: true,
      clearPendingNpc: true,
      clearPendingDummy: true,
      pendingWorldBossAttack: false,
      clearActiveNpcDialog: true,
      clearSelectedRemoteUser: true,
      moveRingPosition: Offset(clampedX, clampedY),
    );
    _throttledBroadcastMove(clampedX, clampedY);
  }

  void nudgeByJoystick(Offset delta) {
    if (state.isMerchant) {
      _joystickVector = Offset.zero;
      return;
    }
    if (delta.distance < 0.08) {
      _joystickVector = Offset.zero;
      state = state.copyWith(
        targetX: state.playerX,
        targetY: state.playerY,
        isMoving: false,
        clearMoveRing: true,
      );
      return;
    }
    _joystickVector = delta;
    final bool faceRight =
        delta.dx.abs() > 0.08 ? delta.dx >= 0 : state.facingRight;
    final bool faceBack =
        delta.dy < -0.18 && delta.dy.abs() > delta.dx.abs() * 0.25;
    state = state.copyWith(
      facingRight: faceRight,
      facingBack: faceBack,
      isMoving: true,
      clearPendingNpc: true,
      clearPendingDummy: true,
      pendingWorldBossAttack: false,
      clearActiveNpcDialog: true,
      clearMoveRing: true,
    );
  }

  void interactWithNpc(MoradonNpcDefinition npc) {
    _joystickVector = Offset.zero;
    if (state.isMerchant) {
      state = state.copyWith(
        activeNpcDialog: npc,
        clearSelectedRemoteUser: true,
      );
      return;
    }
    final double dx = npc.x - state.playerX;
    final double dy = (npc.y + 45.0) - state.playerY;
    final double dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= npc.interactionRadius + 25.0) {
      state = state.copyWith(
        activeNpcDialog: npc,
        facingRight: npc.x >= state.playerX,
        facingBack: npc.y < state.playerY - 24.0,
        isMoving: false,
        targetX: state.playerX,
        targetY: state.playerY,
        clearPendingNpc: true,
        clearPendingDummy: true,
        pendingWorldBossAttack: false,
        clearSelectedRemoteUser: true,
      );
      return;
    }
    final Offset standPt = _clampToWalkablePlaza(
      npc.isArchitecturalZone
          ? npc.x
          : npc.x + (state.playerX < npc.x ? -95.0 : 95.0),
      npc.id == 'monument_center'
          ? 2535.0
          : (npc.id == 'teleport_gate' ? 1140.0 : npc.y + 92.0),
    );
    final double standX = standPt.dx;
    final double standY = standPt.dy;
    final double sdx = standX - state.playerX;
    final double sdy = standY - state.playerY;
    state = state.copyWith(
      targetX: standX,
      targetY: standY,
      facingRight: sdx.abs() > 2.5 ? sdx >= 0 : state.facingRight,
      facingBack: sdy < -8.0 && sdy.abs() > sdx.abs() * 0.25,
      isMoving: true,
      pendingNpcId: npc.id,
      clearPendingDummy: true,
      pendingWorldBossAttack: false,
      clearActiveNpcDialog: true,
      clearSelectedRemoteUser: true,
      moveRingPosition: Offset(standX, standY),
    );
    _throttledBroadcastMove(standX, standY);
  }

  void selectRemotePlayer(MoradonPlayerPresence player) {
    state = state.copyWith(
      selectedRemoteUserId: player.userId,
      clearActiveNpcDialog: true,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearActiveNpcDialog: true,
      clearSelectedRemoteUser: true,
    );
  }

  void teleportToDistrict(MoradonDistrictZone district) {
    _joystickVector = Offset.zero;
    final Offset safe = _clampToWalkablePlaza(
      district.fastTravelX,
      district.fastTravelY,
    );
    state = state.copyWith(
      playerX: safe.dx,
      playerY: safe.dy,
      targetX: safe.dx,
      targetY: safe.dy,
      isMoving: false,
      isMerchant: false,
      clearMerchantTitle: true,
      clearPendingNpc: true,
      clearPendingDummy: true,
      pendingWorldBossAttack: false,
      clearActiveNpcDialog: true,
      clearSelectedRemoteUser: true,
      clearMoveRing: true,
    );
    _throttledBroadcastMove(safe.dx, safe.dy);
    unawaited(_syncMyServerPresence(autoBalance: false));
    unawaited(_loadRealPlayersSnapshot());
  }

  void teleportToTownCenter() {
    teleportToDistrict(kMoradonDistricts.first);
  }

  void toggleMerchantMode({String? title}) {
    final bool nextMerchant = !state.isMerchant;
    final String resolvedTitle =
        (title != null && title.trim().isNotEmpty)
            ? title.trim()
            : '${_localProfile?.username ?? "Oyuncu"} Pazar Tezgahı';
    state = state.copyWith(
      isMerchant: nextMerchant,
      merchantTitle: nextMerchant ? resolvedTitle : null,
      clearMerchantTitle: !nextMerchant,
      isMoving: false,
      targetX: state.playerX,
      targetY: state.playerY,
      clearPendingNpc: true,
      clearPendingDummy: true,
      pendingWorldBossAttack: false,
      clearMoveRing: true,
    );
    unawaited(_trackMyPresence());
  }

  void toggleClassicViewMode() {
    state = state.copyWith(classicViewMode: !state.classicViewMode);
  }

  Future<void> sendChatBubble(String rawMessage) async {
    final String msg = rawMessage.trim();
    if (msg.isEmpty) return;
    final String myId = _localProfile?.id ?? 'local_player';
    final String myName = _localProfile?.username ?? 'Savaşçı';

    final Map<String, MoradonChatBubble> nextBubbles =
        Map<String, MoradonChatBubble>.from(state.chatBubbles);
    nextBubbles[myId] = MoradonChatBubble(
      userId: myId,
      username: myName,
      message: msg,
      expiresAt: DateTime.now().add(const Duration(seconds: 6)),
    );
    state = state.copyWith(chatBubbles: nextBubbles);

    final RealtimeChannel? ch = _channel;
    if (ch != null && state.realtimeConnected) {
      try {
        await ch.sendBroadcastMessage(
          event: 'chat_bubble',
          payload: <String, dynamic>{
            'user_id': myId,
            'username': myName,
            'message': msg,
          },
        );
      } catch (_) {}
    }
  }

  void _throttledBroadcastMove(double tx, double ty) {
    final DateTime now = DateTime.now();
    if (now.difference(_lastMoveBroadcast).inMilliseconds < 280) return;
    _lastMoveBroadcast = now;

    final RealtimeChannel? ch = _channel;
    final PlayerProfile? profile = _localProfile;
    if (ch == null || profile == null || !state.realtimeConnected) return;
    unawaited(
      ch.sendBroadcastMessage(
        event: 'player_move',
        payload: <String, dynamic>{
          'user_id': profile.id,
          'username': profile.username,
          'character_class': profile.characterClass?.name ?? 'savasci',
          'guild_name': profile.guildName,
          'cosmetic_title': profile.cosmeticTitle,
          'level': profile.level,
          'total_power': _localTotalPower,
          'x': tx.round(),
          'y': ty.round(),
          'is_merchant': state.isMerchant,
          'merchant_title': state.merchantTitle,
        },
      ),
    );
  }
}

final NotifierProvider<MoradonHubNotifier, MoradonHubState>
    moradonHubProvider =
    NotifierProvider<MoradonHubNotifier, MoradonHubState>(
      MoradonHubNotifier.new,
    );
