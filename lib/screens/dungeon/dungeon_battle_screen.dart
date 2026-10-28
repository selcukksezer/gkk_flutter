import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/adaptive_glass_blur.dart';
import '../../components/common/rarity_loot_beam.dart';
import '../../models/item_model.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/graphics_quality_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/bank_tutorial.dart';
import '../../core/utils/captcha_guard.dart';
import '../../core/utils/power_formula.dart';
import '../../models/dungeon_model.dart';
import '../../models/dungeon_siege_model.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dungeon_provider.dart';
import '../../providers/dungeon_siege_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../reputation/widgets/reputation_gain_banner.dart';
import 'dungeon_battle_profiles.dart';
import 'dungeon_item_utils.dart';
import 'dungeon_result_widgets.dart';
import 'dungeon_zone_data.dart';
import 'widgets/codex_discovery_chip.dart';
import 'widgets/dungeon_arena_vfx.dart';
import 'widgets/dungeon_battle_effects.dart';
import 'widgets/dungeon_cave_theme.dart';
import 'widgets/dungeon_mob_pack_rig.dart';
import 'widgets/dungeon_stage_combat_view.dart';

class DungeonBattleScreen extends ConsumerStatefulWidget {
  const DungeonBattleScreen({super.key});

  @override
  ConsumerState<DungeonBattleScreen> createState() =>
      _DungeonBattleScreenState();
}

class _DungeonBattleScreenState extends ConsumerState<DungeonBattleScreen>
    with TickerProviderStateMixin {
  String _phase = 'idle';
  String _dungeonId = '';
  String _dungeonName = 'Zindan';
  int _zone = 1;
  int _energyCost = 0;
  bool _autoStart = false;
  DungeonResult? _result;
  Timer? _logTimer;
  bool _paramsLoaded = false;
  int _logIndex = 0;
  final List<String> _battleLog = <String>[];
  int _battleGeneration = 0;
  bool _battleInFlight = false;
  bool _captchaRetryUsed = false;
  bool _rpcAttempted = false;

  /// Interactive Tactical Combat state (pure visual/feel mastery; server RPC 100% preserved).
  DungeonTacticalCommand? _tacticalCommand;
  int _tacticalSeq = 0;
  int _tacticalComboStreak = 0;
  DateTime _lastArenaTapAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<DateTime> _skillReadyAt = List<DateTime>.filled(
    3,
    DateTime.fromMillisecondsSinceEpoch(0),
  );
  final List<int> _skillCooldownMs = <int>[1500, 2200, 3000];

  /// Ambient loop driving weather VFX, floor shadows, breathing, and rays.
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    GraphicsQualityService.instance.addListener(_onGraphicsTierChanged);
    _syncAmbientLoop();
  }

  void _onGraphicsTierChanged() {
    if (!mounted) return;
    _syncAmbientLoop();
    setState(() {});
  }

  void _syncAmbientLoop() {
    final bool isLow = GraphicsQualityService.instance.profile.isLow;
    final bool activePhase = _phase == 'counting' || _phase == 'fighting';
    if (isLow && !activePhase) {
      _ambient.stop();
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_onGraphicsTierChanged);
    _logTimer?.cancel();
    _ambient.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paramsLoaded) return;
    _paramsLoaded = true;
    final Map<String, String> params =
        GoRouterState.of(context).uri.queryParameters;
    _dungeonId = params['dungeon_id'] ?? '';
    _dungeonName = params['dungeon_name'] ?? 'Zindan';
    _zone = int.tryParse(params['zone'] ?? '') ?? 1;
    _energyCost = int.tryParse(params['energy_cost'] ?? '') ?? 0;
    _autoStart = params['auto'] == '1';
    if (_dungeonId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return;
    }
    if (_autoStart && _dungeonId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
    }
  }

  // ===========================================================================
  // Battle flow (100% preserved server, anti-cheat & tutorial mechanics)
  // ===========================================================================

  void _resetForRetry() {
    if (_battleInFlight) return;
    _logTimer?.cancel();
    _captchaRetryUsed = false;
    _rpcAttempted = false;
    setState(() {
      _result = null;
      _battleLog.clear();
      _logIndex = 0;
    });
    _startCountdown();
  }

  String? _preflightBlockReason(PlayerProfile player) {
    final DungeonZone? entryZone = zoneDataFor(_zone);
    if (entryZone != null && !isZoneUnlockedForLevel(entryZone, player.level)) {
      return zoneLevelGateMessage(entryZone.requiredLevel);
    }
    if (_isRestricted(player.hospitalUntil)) {
      return 'Hastanedeyken zindana giriş yapılamaz.';
    }
    if (_isRestricted(player.prisonUntil)) {
      return 'Hapisteyken zindana giriş yapılamaz.';
    }
    if (_energyCost > 0 && player.energy < _energyCost) {
      return 'Enerji yetersiz.';
    }
    final siegeStatus = ref.read(dungeonSiegeProvider).status;
    if (isSiegeDungeon(_dungeonId, status: siegeStatus) &&
        siegeStatus.isBannedForDungeon(_dungeonId)) {
      return 'Kuşatma kaybı banı — bu zindana giremezsin.';
    }
    return null;
  }

  bool _isRestricted(String? untilRaw) {
    if (untilRaw == null || untilRaw.isEmpty) return false;
    final DateTime? until = DateTime.tryParse(untilRaw);
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  void _startCountdown() {
    final PlayerProfile? player = ref.read(playerProvider).profile;
    if (player == null) {
      AppMessenger.showError(context, 'Oyuncu bilgisi yüklenemedi.');
      context.pop();
      return;
    }
    final String? blocked = _preflightBlockReason(player);
    if (blocked != null) {
      AppMessenger.show(context, blocked);
      context.pop();
      return;
    }

    setState(() {
      _phase = 'counting';
      _result = null;
      _battleLog.clear();
      _logIndex = 0;
    });
    _syncAmbientLoop();
  }

  List<String> _buildBespokeCombatLines(DungeonBattleProfile profile) {
    final List<DungeonMobPackMember> pack = resolveDungeonMobPack(
      profile,
      maxMembers: GraphicsQualityService.instance.profile.dungeonMaxPackMobs,
    );
    final String vanguardName =
        pack.isNotEmpty ? pack.first.name : profile.enemyName;
    final String flankerName =
        pack.length > 1 ? pack[1].name : profile.enemyName;
    final List<String> lines = <String>[
      profile.introQuote,
      '${pack.length} kişilik düşman sürüsü karanlıktan çıktı — Öncü $vanguardName atıldı!',
      if (profile.clashLines.isNotEmpty) profile.clashLines[0],
      'Kritik darbeyle $vanguardName kor parçalarına ayrıldı; $flankerName yandan saldırdı!',
      if (profile.clashLines.length > 1) profile.clashLines[1],
      'Sürü çemberini yarıp muhafızları biçtin — ${profile.enemyName} öfkeyle kükredi!',
      if (profile.clashLines.length > 2) profile.clashLines[2],
      ...zoneFlavorLines(_zone).take(1),
      '${profile.enemyName} ile rün çemberinin ortasında son çarpışma!',
    ];
    return lines;
  }

  static const int _kMinFightMs = 7000;

  bool get _battleLocked => _phase == 'counting' || _phase == 'fighting';

  DungeonStagePhase get _stagePhase => switch (_phase) {
        'counting' => DungeonStagePhase.counting,
        'fighting' => DungeonStagePhase.fighting,
        'success' => DungeonStagePhase.victory,
        'failure' => DungeonStagePhase.defeat,
        _ => DungeonStagePhase.idle,
      };

  Future<void> _startBattle() async {
    if (_battleInFlight) return;
    _battleInFlight = true;

    unawaited(
      TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.dungeonAttackBtn),
    );
    final int generation = ++_battleGeneration;
    final DateTime battleStart = DateTime.now();
    final DungeonBattleProfile profile = _battleProfile;

    setState(() {
      _phase = 'fighting';
      _tacticalCommand = null;
      _tacticalComboStreak = 0;
      for (int i = 0; i < _skillReadyAt.length; i++) {
        _skillReadyAt[i] = DateTime.fromMillisecondsSinceEpoch(0);
      }
      _battleLog
        ..clear()
        ..addAll(_buildBespokeCombatLines(profile));
      _logIndex = 0;
    });
    _syncAmbientLoop();

    _logTimer = Timer.periodic(
      const Duration(milliseconds: 780),
      (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_logIndex < _battleLog.length - 1) {
          setState(() => _logIndex++);
        }
      },
    );

    try {
      final PlayerProfile? preflightPlayer = ref.read(playerProvider).profile;
      if (preflightPlayer == null) {
        _logTimer?.cancel();
        AppMessenger.showError(context, 'Oyuncu bilgisi yüklenemedi.');
        context.pop();
        return;
      }
      final String? blocked = _preflightBlockReason(preflightPlayer);
      if (blocked != null) {
        _logTimer?.cancel();
        AppMessenger.show(context, blocked);
        context.pop();
        return;
      }

      final int elapsedBeforeRpc =
          DateTime.now().difference(battleStart).inMilliseconds;
      if (elapsedBeforeRpc < _kMinFightMs) {
        await Future<void>.delayed(
          Duration(milliseconds: _kMinFightMs - elapsedBeforeRpc),
        );
      }

      if (!mounted || generation != _battleGeneration || !_battleLocked) {
        _logTimer?.cancel();
        return;
      }

      _rpcAttempted = true;
      final dynamic raw = await SupabaseService.client.rpc(
        'attack_dungeon',
        params: <String, dynamic>{'p_dungeon_id': _dungeonId},
      );

      if (!mounted || generation != _battleGeneration) {
        _logTimer?.cancel();
        return;
      }

      if (raw is Map) {
        if (CaptchaGuard.isCaptchaRequired(raw)) {
          _logTimer?.cancel();
          final bool solved = await CaptchaGuard.solve(context, 'dungeon');
          if (!mounted) return;
          if (solved) {
            if (_captchaRetryUsed) {
              AppMessenger.showError(
                context,
                'Doğrulama sonrası tekrar deneme limiti. Enerjini kontrol edip tekrar dene.',
              );
              context.pop();
              return;
            }
            _captchaRetryUsed = true;
            _rpcAttempted = false;
            _battleInFlight = false;
            await _startBattle();
          } else {
            context.pop();
          }
          return;
        }
        final DungeonResult parsed =
            DungeonResult.fromJson(Map<String, dynamic>.from(raw));
        if ((parsed.error ?? '').isNotEmpty) {
          _logTimer?.cancel();
          AppMessenger.showError(context, _mapError(parsed.error!));
          context.pop();
          return;
        }

        await ref.read(playerProvider.notifier).loadProfile();
        await ref.read(inventoryProvider.notifier).loadInventory(silent: true);

        if (!mounted || generation != _battleGeneration) {
          _logTimer?.cancel();
          return;
        }

        _logTimer?.cancel();

        if (parsed.success) {
          if (parsed.isCritical) {
            _battleLog.add('EZİCİ KRİTİK VURUŞ! ${profile.enemyName} yıkıldı!');
          } else {
            _battleLog.add('${profile.enemyName} alt edildi!');
          }
        } else if (parsed.hospitalized) {
          _battleLog.add('${profile.enemyName} ağır darbe indirdi...');
          _battleLog.add('Hastaneye kaldırılıyorsun.');
        } else {
          _battleLog.add('Son çarpışmada geri çekilmek zorunda kaldın...');
        }

        setState(() {
          _result = parsed;
          _logIndex = _battleLog.length - 1;
          _phase = parsed.success ? 'success' : 'failure';
        });
        _syncAmbientLoop();

        if (parsed.success) {
          unawaited(TutorialTriggers.onDungeonWin(ref));
        } else {
          TutorialTriggers.onDungeonLoss(ref);
        }

        if (parsed.inventoryFull) {
          unawaited(BankTutorial.maybeShowInventoryFullDialog(context, ref));
        }
      } else {
        setState(() {
          _result = null;
          _phase = 'failure';
        });
        _syncAmbientLoop();
      }
    } catch (e) {
      _logTimer?.cancel();
      if (!mounted) return;
      final String msg = _rpcAttempted
          ? 'Bağlantı koptu — savaş sunucuda işlenmiş olabilir. Enerji/ödülü kontrol et, otomatik tekrar yok.'
          : userFacingErrorMessage(e, fallback: 'Savaş başlatılamadı.');
      AppMessenger.showError(context, msg);
      context.pop();
    } finally {
      _battleInFlight = false;
    }
  }

  String _mapError(String raw) {
    return userFacingErrorMessage(raw, fallback: 'Operasyon tamamlanamadı.');
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 dk';
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m dk';
    return '$h sa $m dk';
  }

  bool _canRetry() {
    if (_battleInFlight) return false;
    final PlayerProfile? player = ref.read(playerProvider).profile;
    if (player == null) return false;
    return _preflightBlockReason(player) == null;
  }

  List<
      ({
        IconData icon,
        String title,
        double mult,
        bool aoe,
        int cdMs,
        Color accent,
      })> _resolveClassSkills(CharacterClass? cls) {
    return switch (cls) {
      CharacterClass.shadow => <({
          IconData icon,
          String title,
          double mult,
          bool aoe,
          int cdMs,
          Color accent,
        })>[
          (
            icon: Icons.bolt_rounded,
            title: 'İkiz Gölge',
            mult: 1.48,
            aoe: false,
            cdMs: 1450,
            accent: const Color(0xFFC084FC),
          ),
          (
            icon: Icons.blur_on_rounded,
            title: 'Zehirli Sis',
            mult: 1.82,
            aoe: true,
            cdMs: 2200,
            accent: const Color(0xFF34D399),
          ),
          (
            icon: Icons.crisis_alert_rounded,
            title: 'Gece İnfazı',
            mult: 2.52,
            aoe: true,
            cdMs: 2950,
            accent: const Color(0xFFF43F5E),
          ),
        ],
      CharacterClass.alchemist => <({
          IconData icon,
          String title,
          double mult,
          bool aoe,
          int cdMs,
          Color accent,
        })>[
          (
            icon: Icons.science_rounded,
            title: 'Kor İksiri',
            mult: 1.48,
            aoe: false,
            cdMs: 1450,
            accent: const Color(0xFF34D399),
          ),
          (
            icon: Icons.ac_unit_rounded,
            title: 'Rün Kristali',
            mult: 1.84,
            aoe: true,
            cdMs: 2200,
            accent: const Color(0xFF38BDF8),
          ),
          (
            icon: Icons.flare_rounded,
            title: 'Kadim Nova',
            mult: 2.55,
            aoe: true,
            cdMs: 2950,
            accent: const Color(0xFFFBBF24),
          ),
        ],
      _ => <({
          IconData icon,
          String title,
          double mult,
          bool aoe,
          int cdMs,
          Color accent,
        })>[
          (
            icon: Icons.local_fire_department_rounded,
            title: 'Ateş Yaran',
            mult: 1.50,
            aoe: false,
            cdMs: 1450,
            accent: const Color(0xFFFB923C),
          ),
          (
            icon: Icons.shield_rounded,
            title: 'Kalkan Kıran',
            mult: 1.85,
            aoe: true,
            cdMs: 2200,
            accent: const Color(0xFF38BDF8),
          ),
          (
            icon: Icons.auto_awesome_rounded,
            title: 'Hükümdar İnfazı',
            mult: 2.58,
            aoe: true,
            cdMs: 2950,
            accent: const Color(0xFFFBBF24),
          ),
        ],
    };
  }

  void _handleArenaStrikeTap(bool isSweetSpot) {
    if (_phase != 'fighting') return;
    final DateTime now = DateTime.now();
    if (now.difference(_lastArenaTapAt).inMilliseconds < 210) return;
    _lastArenaTapAt = now;

    if (isSweetSpot) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _tacticalComboStreak += isSweetSpot ? 2 : 1;
      _tacticalCommand = DungeonTacticalCommand(
        seq: ++_tacticalSeq,
        type: isSweetSpot
            ? DungeonTacticalActionType.perfectCrit
            : DungeonTacticalActionType.quickSlash,
        skillTitle: isSweetSpot ? 'MÜKEMMEL KRİTİK' : 'HIZLI KESİŞ',
        damageMultiplier: isSweetSpot ? 1.92 : 1.18,
        isCritical: isSweetSpot,
        aoeAllMobs: isSweetSpot,
        comboStreak: _tacticalComboStreak,
      );
      if (isSweetSpot) {
        _battleLog.insert(
          math.min(_logIndex + 1, _battleLog.length),
          'MÜKEMMEL KRİTİK! Altın halkada vurdun (Kombo x$_tacticalComboStreak)!',
        );
        _logIndex = math.min(_logIndex + 1, _battleLog.length - 1);
      }
    });
  }

  void _triggerTacticalSkill(int slot, CharacterClass? cls) {
    if (_phase != 'fighting' || slot < 0 || slot >= 3) return;
    final DateTime now = DateTime.now();
    if (now.isBefore(_skillReadyAt[slot])) return;

    final skills = _resolveClassSkills(cls);
    final sk = skills[slot];
    if (slot == 2) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _skillCooldownMs[slot] = sk.cdMs;
      _skillReadyAt[slot] = now.add(Duration(milliseconds: sk.cdMs));
      _tacticalComboStreak += slot == 2 ? 3 : 2;
      _tacticalCommand = DungeonTacticalCommand(
        seq: ++_tacticalSeq,
        type: switch (slot) {
          0 => DungeonTacticalActionType.skill1,
          1 => DungeonTacticalActionType.skill2,
          _ => DungeonTacticalActionType.ultimate,
        },
        skillTitle: sk.title.toUpperCase(),
        damageMultiplier: sk.mult,
        isCritical: slot >= 1,
        aoeAllMobs: sk.aoe,
        comboStreak: _tacticalComboStreak,
      );
      _battleLog.insert(
        math.min(_logIndex + 1, _battleLog.length),
        '${sk.title} patladı — sürü sarsıldı (Kombo x$_tacticalComboStreak)!',
      );
      _logIndex = math.min(_logIndex + 1, _battleLog.length - 1);
    });
  }

  // ===========================================================================
  // Bespoke 65-Dungeon Profile & Player Combat Stats Helpers
  // ===========================================================================

  DungeonBattleProfile get _battleProfile =>
      DungeonBattleProfile.forDungeonId(_dungeonId, fallbackZone: _zone);

  CaveCardTheme get _caveTheme =>
      CaveCardTheme.forDungeonNumber(parseDungeonNumber(_dungeonId)) ??
      CaveCardTheme.cyberCave;

  String get _displayDungeonTitle {
    final String raw = _dungeonName.trim();
    if (raw.isEmpty || raw == 'Zindan') {
      return _battleProfile.turkishTitle;
    }
    return raw;
  }

  String get _characterAsset {
    final CharacterClass? cls =
        ref.read(playerProvider).profile?.characterClass;
    return switch (cls) {
      CharacterClass.shadow => 'assets/dungeon/hero_battle_shadow.png',
      CharacterClass.alchemist => 'assets/dungeon/hero_battle_alchemist.png',
      _ => 'assets/dungeon/hero_battle_warrior.png',
    };
  }

  ({int? powerReq, int? successPct, int combatPower}) _resolvePowerMetrics(
    PlayerProfile? profile,
  ) {
    int? powerRequirement;
    for (final DungeonData d in ref.read(dungeonProvider).dungeons) {
      if (d.dungeonId == _dungeonId) {
        powerRequirement = d.powerRequirement;
        break;
      }
    }
    int? successPct;
    int combatPower = profile?.power ?? 0;
    if (profile != null) {
      final equipped = ref.read(inventoryProvider).equippedItems.values;
      combatPower = resolveDungeonCombatPower(
        profile: profile,
        equippedItems: equipped,
      );
      if (powerRequirement != null) {
        successPct = computeDungeonSuccessPercent(
          profile: profile,
          dungeonPowerRequirement: powerRequirement,
          equippedItems: equipped,
        );
      }
    }
    return (
      powerReq: powerRequirement,
      successPct: successPct,
      combatPower: combatPower,
    );
  }

  // ===========================================================================
  // Build — 100% FULL-SCREEN EDGE-TO-EDGE LIVING 2.5D DUNGEON
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    Future<void> logoutHandler() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    final DungeonBattleProfile profile = _battleProfile;
    final CaveCardTheme theme = _caveTheme;
    final PlayerProfile? player = ref.watch(playerProvider).profile;
    final String rawName =
        ((player?.displayName ?? player?.username) ?? 'KAHRAMAN').trim();
    final String playerName = rawName.isEmpty ? 'KAHRAMAN' : rawName;
    final ({int combatPower, int? powerReq, int? successPct}) metrics =
        _resolvePowerMetrics(player);

    final MediaQueryData mq = MediaQuery.of(context);
    final double topSafe = mq.padding.top;
    // Clearance above GameBottomBar
    final double bottomNavClearance = math.max(92.0, mq.padding.bottom + 82.0);
    final bool isResultPhase = _phase == 'success' || _phase == 'failure';
    final bool isCompactMobile = mq.size.width < 600;

    return PopScope(
      canPop: !_battleLocked,
      child: Scaffold(
        backgroundColor: profile.deepSurface,
        extendBody: true,
        bottomNavigationBar: GameBottomBar(
          currentRoute: AppRoutes.dungeon,
          onLogout: logoutHandler,
          navigationLocked: _battleLocked,
          showChatFab: false,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. PERSISTENT 100% FULL-SCREEN LIVING 3D DUNGEON WORLD
            Positioned.fill(
              child: DungeonStageCombatView(
                profile: profile,
                stagePhase: _stagePhase,
                ambient: _ambient,
                characterAsset: _characterAsset,
                characterClass: player?.characterClass,
                playerName: playerName,
                playerLevel: player?.level ?? 1,
                playerPower: metrics.combatPower,
                powerRequirement: metrics.powerReq,
                fullscreen: true,
                hudTopInset: topSafe + 58,
                groundYFactor: isCompactMobile
                    ? (isResultPhase ? 0.50 : 0.565)
                    : (isResultPhase ? 0.58 : 0.70),
                tacticalCommand: _tacticalCommand,
                onArenaStrikeTap:
                    _phase == 'fighting' ? _handleArenaStrikeTap : null,
              ),
            ),

            // 2. FLOATING TOP DUNGEON HEADER BAR
            Positioned(
              top: topSafe + 6,
              left: 12,
              right: 12,
              child: _buildHeader(profile, player),
            ),

            // 3. FLOATING PHASE HUD OVERLAYS OVER THE FULL-SCREEN DUNGEON
            Positioned.fill(
              top: topSafe + 118,
              bottom: bottomNavClearance,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey<String>('${profile.dungeonId}_$_phase'),
                  child: _buildFloatingPhaseHud(
                    profile: profile,
                    theme: theme,
                    player: player,
                    playerName: playerName,
                    metrics: metrics,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DungeonBattleProfile profile, PlayerProfile? player) {
    final int energy = player?.energy ?? 0;
    final int maxEnergy = player?.maxEnergy ?? 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xBF070A12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: profile.primaryColor.withValues(alpha: 0.42),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              PressableScale(
                onTap: _battleLocked
                    ? () => AppMessenger.show(
                          context,
                          'Savaş bitene kadar çıkamazsın.',
                        )
                    : () => context.pop(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: profile.deepSurface.withValues(alpha: 0.90),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: profile.primaryColor.withValues(alpha: 0.52),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (profile.isBoss) ...<Widget>[
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFFFFD700),
                                  Color(0xFFEA580C),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'BOSS',
                              style: TextStyle(
                                color: Color(0xFF090D16),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                        Flexible(
                          child: DungeonInsetText(
                            _displayDungeonTitle,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'BÖLGE $_zone • ${profile.latinTitle.toUpperCase()} • #${profile.dungeonNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: profile.primaryColor.withValues(alpha: 0.92),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const GraphicsQuickPill(),
              const SizedBox(width: 6),
              BattleChip(
                icon: Icons.bolt_rounded,
                label: 'ENERJİ',
                value: maxEnergy > 0 ? '$energy/$maxEnergy' : '$energy',
                color: BattlePalette.warningSolar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPhaseHud({
    required DungeonBattleProfile profile,
    required CaveCardTheme theme,
    required PlayerProfile? player,
    required String playerName,
    required ({int combatPower, int? powerReq, int? successPct}) metrics,
  }) {
    switch (_phase) {
      case 'counting':
        return _FullscreenVsCountdownHud(
          profile: profile,
          theme: theme,
          playerName: playerName,
          playerLevel: player?.level ?? 1,
          playerPower: metrics.combatPower,
          playerAttack: player?.attack ?? 0,
          playerDefense: player?.defense ?? 0,
          powerRequirement: metrics.powerReq,
          successPct: metrics.successPct,
          onComplete: _startBattle,
        );

      case 'fighting':
        return _FullscreenFightingTickerHud(
          profile: profile,
          ambient: _ambient,
          logLines: _battleLog.take(_logIndex + 1).toList(),
          skills: _resolveClassSkills(player?.characterClass),
          skillReadyAt: _skillReadyAt,
          skillCooldownMs: _skillCooldownMs,
          comboStreak: _tacticalComboStreak,
          onTriggerSkill: (int slot) =>
              _triggerTacticalSkill(slot, player?.characterClass),
        );

      case 'success':
        return _buildFullscreenSuccessHud(profile);

      case 'failure':
        return _buildFullscreenFailureHud(profile);

      case 'idle':
      default:
        return _FullscreenIdleDock(
          profile: profile,
          theme: theme,
          energyCost: _energyCost,
          playerPower: metrics.combatPower,
          powerRequirement: metrics.powerReq,
          successPct: metrics.successPct,
          onAttack: () async {
            await TutorialTriggers.onAnchorTap(
              ref,
              TutorialAnchorId.dungeonAttackBtn,
            );
            _startCountdown();
          },
        );
    }
  }

  Widget _buildFullscreenSuccessHud(DungeonBattleProfile profile) {
    final DungeonResult? result = _result;
    if (result == null) return const SizedBox.shrink();

    return _FullscreenVictoryOverlay(
      profile: profile,
      ambient: _ambient,
      result: result,
      comboStreak: _tacticalComboStreak,
      canRetry: _canRetry(),
      onRetry: _resetForRetry,
      onBack: () => context.pop(),
      onOpenCodex: () => context.push(AppRoutes.codex),
    );
  }

  Widget _buildFullscreenFailureHud(DungeonBattleProfile profile) {
    final DungeonResult? result = _result;
    final bool hospitalized = result?.hospitalized == true;
    final String duration =
        _formatDuration(result?.hospitalDurationSeconds ?? 0);
    final int dungeonNum = profile.dungeonNumber;
    final List<String> notices = hospitalized
        ? <String>[
            '${profile.enemyName} karşısında ağır yaralandın!',
            'Hastane tedavi süresi: $duration',
          ]
        : dungeonNum <= 3
            ? <String>[
                '${profile.enemyName} saldırıyı püskürttü.',
                'Gücünü toplayıp tekrar dene.',
              ]
            : <String>[
                '${profile.enemyName} bu karşılaşmada üstün geldi.',
                'Ekipmanını güçlendir veya tekrar dene.',
              ];

    final int hospitalCount =
        ref.read(playerProvider).profile?.hospitalLifetimeCount ?? 0;
    final bool canFree = canFreeHospitalDischarge(hospitalCount);

    return _FullscreenDefeatOverlay(
      profile: profile,
      ambient: _ambient,
      hospitalized: hospitalized,
      canFreeDischarge: canFree,
      notices: notices,
      canRetry: _canRetry(),
      onRetry: _resetForRetry,
      onGoHospital: () => context.go(AppRoutes.hospital),
      onBack: () => context.pop(),
    );
  }
}

// =============================================================================
// 1. IDLE DOCK — Sleek Compact Frosted Glass Dock at Bottom of Full-Screen Dungeon
// =============================================================================
class _FullscreenIdleDock extends StatelessWidget {
  const _FullscreenIdleDock({
    required this.profile,
    required this.theme,
    required this.energyCost,
    required this.playerPower,
    required this.powerRequirement,
    required this.successPct,
    required this.onAttack,
  });

  final DungeonBattleProfile profile;
  final CaveCardTheme theme;
  final int energyCost;
  final int playerPower;
  final int? powerRequirement;
  final int? successPct;
  final VoidCallback onAttack;

  @override
  Widget build(BuildContext context) {
    final Color chanceColor = successPct != null
        ? theme.threatForSuccess(successPct!)
        : profile.primaryColor;
    final int packSize = resolveDungeonMobPack(
      profile,
      maxMembers: GraphicsQualityService.instance.profile.dungeonMaxPackMobs,
    ).length;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AdaptiveGlassBlur(
              sigma: 10,
              child: DungeonOrnamentalPanel(
                style: profile.hudFrameStyle,
                primary: profile.primaryColor,
                secondary: profile.secondaryColor,
                fillAlpha: 0.72,
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          profile.isBoss
                              ? Icons.workspace_premium_rounded
                              : Icons.shield_moon_rounded,
                          size: 13,
                          color: profile.isBoss
                              ? const Color(0xFFFFD700)
                              : profile.primaryColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '${profile.enemyName.toUpperCase()} — ${profile.enemyTitle.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: profile.isBoss
                                  ? const Color(0xFFFFD700)
                                  : profile.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '“${profile.introQuote}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        height: 1.32,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        BattleChip(
                          icon: Icons.flash_on_rounded,
                          label: 'GÜCÜN',
                          value: '$playerPower',
                          color: const Color(0xFF34D399),
                        ),
                        if (powerRequirement != null)
                          BattleChip(
                            icon: Icons.security_rounded,
                            label: 'HEDEF',
                            value: '$powerRequirement',
                            color: profile.primaryColor,
                          ),
                        if (successPct != null)
                          BattleChip(
                            icon: Icons.percent_rounded,
                            label: 'ŞANS',
                            value: '%$successPct',
                            color: chanceColor,
                          ),
                        BattleChip(
                          icon: Icons.groups_rounded,
                          label: 'SÜRÜ',
                          value: '$packSize',
                          color: profile.secondaryColor,
                        ),
                        if (energyCost > 0)
                          BattleChip(
                            icon: Icons.bolt_rounded,
                            label: 'ENERJİ',
                            value: '$energyCost',
                            color: BattlePalette.warningSolar,
                          ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    TutorialAnchorScope(
                      id: TutorialAnchorId.dungeonAttackBtn,
                      child: BattleCtaButton(
                        label: profile.isBoss ? 'BOSSA SALDIR' : 'SALDIR',
                        icon: Icons.sports_martial_arts_rounded,
                        colors: <Color>[
                          profile.primaryColor,
                          profile.secondaryColor,
                        ],
                        glowColor: profile.primaryColor,
                        foreground: const Color(0xFF070A12),
                        onTap: onAttack,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. COUNTDOWN HUD — Center Rune Sigil + Compact Bottom VS Stat Strip
// =============================================================================
class _FullscreenVsCountdownHud extends StatefulWidget {
  const _FullscreenVsCountdownHud({
    required this.profile,
    required this.theme,
    required this.playerName,
    required this.playerLevel,
    required this.playerPower,
    required this.playerAttack,
    required this.playerDefense,
    required this.powerRequirement,
    required this.successPct,
    required this.onComplete,
  });

  final DungeonBattleProfile profile;
  final CaveCardTheme theme;
  final String playerName;
  final int playerLevel;
  final int playerPower;
  final int playerAttack;
  final int playerDefense;
  final int? powerRequirement;
  final int? successPct;
  final VoidCallback onComplete;

  @override
  State<_FullscreenVsCountdownHud> createState() =>
      _FullscreenVsCountdownHudState();
}

class _FullscreenVsCountdownHudState extends State<_FullscreenVsCountdownHud>
    with SingleTickerProviderStateMixin {
  static const int _kTotalMs = 4200;
  static const int _kCountStartMs = 650;
  static const int _kCountStepMs = 900;
  static const int _kBurstStartMs = 3350;

  late final AnimationController _seq;
  int _lastNumber = 0;
  bool _burstHapticDone = false;

  double _f(int ms) => ms / _kTotalMs;

  @override
  void initState() {
    super.initState();
    _seq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTotalMs),
    )
      ..addListener(_handleHaptics)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) widget.onComplete();
      })
      ..forward();
  }

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  int? _numberAt(double v) {
    final double start = _f(_kCountStartMs);
    final double end = _f(_kBurstStartMs);
    if (v < start || v >= end) return null;
    final int idx = ((v - start) / _f(_kCountStepMs)).floor();
    return (3 - idx).clamp(1, 3);
  }

  void _handleHaptics() {
    final double v = _seq.value;
    final int? n = _numberAt(v);
    if (n != null && n != _lastNumber) {
      _lastNumber = n;
      HapticFeedback.mediumImpact();
    }
    if (!_burstHapticDone && v >= _f(_kBurstStartMs)) {
      _burstHapticDone = true;
      HapticFeedback.heavyImpact();
    }
  }

  void _skip() {
    if (_seq.value >= _f(_kBurstStartMs)) return;
    _seq.animateTo(
      1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final DungeonBattleProfile profile = widget.profile;

    return AnimatedBuilder(
      animation: _seq,
      builder: (BuildContext context, _) {
        final double v = _seq.value;
        final int? number = _numberAt(v);
        final bool inBurst = v >= _f(_kBurstStartMs);
        final double statsT =
            Curves.easeOutCubic.transform((v / 0.28).clamp(0.0, 1.0));

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Centered Runic Countdown between Hero and Boss
            Align(
              alignment: const Alignment(0, -0.22),
              child: IgnorePointer(
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (number != null) ...<Widget>[
                      CustomPaint(
                        size: const Size(156, 156),
                        painter: CountdownRingPainter(
                          rotation: v * 2 * math.pi * 6,
                          color: profile.primaryColor,
                          secondary: profile.secondaryColor,
                        ),
                      ),
                      Text(
                        '$number',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 82,
                          fontWeight: FontWeight.w900,
                          shadows: <Shadow>[
                            Shadow(
                              color:
                                  profile.primaryColor.withValues(alpha: 0.92),
                              blurRadius: 30,
                            ),
                            const Shadow(color: Colors.black, blurRadius: 14),
                          ],
                        ),
                      ),
                    ],
                    if (inBurst)
                      Transform.scale(
                        scale: Curves.elasticOut.transform(
                          (((v - _f(_kBurstStartMs)) /
                                      (1 - _f(_kBurstStartMs))) *
                                  2.0)
                              .clamp(0.0, 1.0),
                        ),
                        child: Text(
                          'SAVAŞ!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 3.5,
                            shadows: <Shadow>[
                              Shadow(
                                color: profile.primaryColor
                                    .withValues(alpha: 0.95),
                                blurRadius: 34,
                              ),
                              const Shadow(color: Colors.black, blurRadius: 16),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Compact Stat Duel Ribbon + Skip Button
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Opacity(
                    opacity: statsT,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (!inBurst)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PressableScale(
                              onTap: _skip,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xCC070A12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: profile.primaryColor
                                        .withValues(alpha: 0.48),
                                  ),
                                ),
                                child: Text(
                                  'İNTROYU GEÇ ▸',
                                  style: TextStyle(
                                    color: profile.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AdaptiveGlassBlur(
                            sigma: 10,
                            child: _CompactDuelRibbon(
                              profile: profile,
                              theme: widget.theme,
                              playerPower: widget.playerPower,
                              playerAttack: widget.playerAttack,
                              playerDefense: widget.playerDefense,
                              powerRequirement: widget.powerRequirement,
                              successPct: widget.successPct,
                              fillT: statsT,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompactDuelRibbon extends StatelessWidget {
  const _CompactDuelRibbon({
    required this.profile,
    required this.theme,
    required this.playerPower,
    required this.playerAttack,
    required this.playerDefense,
    required this.powerRequirement,
    required this.successPct,
    required this.fillT,
  });

  final DungeonBattleProfile profile;
  final CaveCardTheme theme;
  final int playerPower;
  final int playerAttack;
  final int playerDefense;
  final int? powerRequirement;
  final int? successPct;
  final double fillT;

  @override
  Widget build(BuildContext context) {
    final Color chanceColor = successPct != null
        ? theme.threatForSuccess(successPct!)
        : profile.primaryColor;
    final int packSize = resolveDungeonMobPack(
      profile,
      maxMembers: GraphicsQualityService.instance.profile.dungeonMaxPackMobs,
    ).length;

    return DungeonOrnamentalPanel(
      style: profile.hudFrameStyle,
      primary: profile.primaryColor,
      secondary: profile.secondaryColor,
      fillAlpha: 0.72,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SENİN GÜCÜN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$playerPower  •  ATK $playerAttack  •  DEF $playerDefense',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'HEDEF GÜÇ • $packSize SÜRÜ',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${powerRequirement ?? 0}',
                    style: TextStyle(
                      color: profile.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (successPct != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'ZAFER İHTİMALİ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  '%$successPct',
                  style: TextStyle(
                    color: chanceColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: <Widget>[
                    Container(color: Colors.white.withValues(alpha: 0.10)),
                    FractionallySizedBox(
                      widthFactor:
                          ((successPct! / 100) * fillT).clamp(0.0, 1.0),
                      heightFactor: 1.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              chanceColor.withValues(alpha: 0.72),
                              chanceColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 3. FIGHTING TICKER HUD — Tactical Class Skill Bar + 2-Line Glass Action Strip
// =============================================================================
class _FullscreenFightingTickerHud extends StatelessWidget {
  const _FullscreenFightingTickerHud({
    required this.profile,
    required this.ambient,
    required this.logLines,
    required this.skills,
    required this.skillReadyAt,
    required this.skillCooldownMs,
    required this.comboStreak,
    required this.onTriggerSkill,
  });

  final DungeonBattleProfile profile;
  final AnimationController ambient;
  final List<String> logLines;
  final List<
      ({
        IconData icon,
        String title,
        double mult,
        bool aoe,
        int cdMs,
        Color accent,
      })> skills;
  final List<DateTime> skillReadyAt;
  final List<int> skillCooldownMs;
  final int comboStreak;
  final ValueChanged<int> onTriggerSkill;

  @override
  Widget build(BuildContext context) {
    final List<String> recentLines = logLines.length <= 2
        ? logLines
        : logLines.sublist(logLines.length - 2);
    final ({String grade, Color color}) rank =
        resolveDungeonStyleRank(comboStreak);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. Timing Hint + Live Style Rank Strip
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC090D16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.gps_fixed_rounded,
                              size: 12,
                              color: Color(0xFFFBBF24),
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'HALKADA ARENAYA DOKUN = KRİTİK DARBE',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (comboStreak >= 1) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              const Color(0xEE0B101D),
                              rank.color.withValues(alpha: 0.30),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: rank.color.withValues(alpha: 0.85),
                            width: 1.2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: rank.color.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.whatshot_rounded,
                              size: 12,
                              color: rank.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'STİL ${rank.grade} • x$comboStreak',
                              style: TextStyle(
                                color: rank.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 2. Interactive 3-Slot Class Tactical Skill Bar
              AnimatedBuilder(
                animation: ambient,
                builder: (BuildContext context, _) {
                  final DateTime now = DateTime.now();
                  return Row(
                    children: <Widget>[
                      for (int i = 0; i < skills.length && i < 3; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _TacticalSkillButton(
                            icon: skills[i].icon,
                            title: skills[i].title,
                            mult: skills[i].mult,
                            aoe: skills[i].aoe,
                            accent: skills[i].accent,
                            remainingMs: math.max(
                              0,
                              skillReadyAt[i].difference(now).inMilliseconds,
                            ),
                            totalCdMs: math.max(1, skillCooldownMs[i]),
                            isUltimate: i == 2,
                            onTap: () => onTriggerSkill(i),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),

              // 3. Glass Combat Ticker Panel
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AdaptiveGlassBlur(
                  sigma: 10,
                  child: DungeonOrnamentalPanel(
                    style: profile.hudFrameStyle,
                    primary: profile.primaryColor,
                    secondary: profile.secondaryColor,
                    fillAlpha: 0.68,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        AnimatedBuilder(
                          animation: ambient,
                          builder: (BuildContext context, _) {
                            return EnergySweepBar(
                              progress: (ambient.value * 3) % 1.0,
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        for (int i = 0; i < recentLines.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '▸ ',
                                  style: TextStyle(
                                    color: i == recentLines.length - 1
                                        ? profile.primaryColor
                                        : profile.secondaryColor
                                            .withValues(alpha: 0.55),
                                    fontSize: 11.5,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    recentLines[i],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: i == recentLines.length - 1
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.54),
                                      fontSize: 11.5,
                                      fontWeight: i == recentLines.length - 1
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TacticalSkillButton extends StatelessWidget {
  const _TacticalSkillButton({
    required this.icon,
    required this.title,
    required this.mult,
    required this.aoe,
    required this.accent,
    required this.remainingMs,
    required this.totalCdMs,
    required this.isUltimate,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final double mult;
  final bool aoe;
  final Color accent;
  final int remainingMs;
  final int totalCdMs;
  final bool isUltimate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool ready = remainingMs <= 0;
    final double cdProgress = ready
        ? 1.0
        : (1.0 - (remainingMs / totalCdMs)).clamp(0.0, 1.0);
    final String subText = ready
        ? '${aoe ? "AOE" : "TEK"} • x${mult.toStringAsFixed(1)}'
        : '${(remainingMs / 1000).toStringAsFixed(1)}sn';

    return GestureDetector(
      onTap: ready ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ready
                ? <Color>[
                    const Color(0xE00A101E),
                    accent.withValues(alpha: isUltimate ? 0.34 : 0.22),
                  ]
                : <Color>[
                    const Color(0xCC070A12),
                    const Color(0xCC0F172A),
                  ],
          ),
          border: Border.all(
            color: ready
                ? accent.withValues(alpha: isUltimate ? 0.92 : 0.72)
                : Colors.white.withValues(alpha: 0.14),
            width: isUltimate && ready ? 1.5 : 1.1,
          ),
          boxShadow: ready
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: isUltimate ? 0.34 : 0.20),
                    blurRadius: isUltimate ? 12 : 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (!ready)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: cdProgress,
                  child: Container(
                    color: accent.withValues(alpha: 0.18),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ready
                            ? accent.withValues(alpha: 0.20)
                            : Colors.white.withValues(alpha: 0.06),
                        border: Border.all(
                          color: ready
                              ? accent.withValues(alpha: 0.78)
                              : Colors.white.withValues(alpha: 0.16),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 15,
                        color: ready
                            ? accent
                            : Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              maxLines: 1,
                              style: TextStyle(
                                color: ready
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ready
                                  ? accent
                                  : const Color(0xFF94A3B8),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 4. VICTORY & DEFEAT FULL-SCREEN OVERLAYS — Upper Crest + Bottom Loot Sheet
// =============================================================================
class _FullscreenVictoryOverlay extends StatelessWidget {
  const _FullscreenVictoryOverlay({
    required this.profile,
    required this.ambient,
    required this.result,
    required this.comboStreak,
    required this.canRetry,
    required this.onRetry,
    required this.onBack,
    required this.onOpenCodex,
  });

  final DungeonBattleProfile profile;
  final AnimationController ambient;
  final DungeonResult result;
  final int comboStreak;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final VoidCallback onOpenCodex;

  @override
  Widget build(BuildContext context) {
    final double availH = MediaQuery.sizeOf(context).height;
    final ({String grade, Color color}) rank =
        resolveDungeonStyleRank(comboStreak);

    final bool isLow = GraphicsQualityService.instance.profile.isLow;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Golden victory rays & confetti inside the full-screen dungeon (Medium+)
        if (!isLow) ...<Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: ambient,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: RadiantRaysPainter(
                      progress: ambient.value,
                      color: BattlePalette.liquidGold,
                      maxOpacity:
                          result.isCritical || result.isFirstClear ? 0.24 : 0.15,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: ambient,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: ConfettiFieldPainter(progress: ambient.value),
                  );
                },
              ),
            ),
          ),
        ],

        // Upper-center ZAFER crest over the triumphant Hero
        Align(
          alignment: const Alignment(0, -0.78),
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _ResultEmblem(
                      icon: Icons.emoji_events_rounded,
                      colors: const <Color>[
                        Color(0xFFFFD700),
                        Color(0xFFB8860B),
                      ],
                      glowColor: BattlePalette.liquidGold,
                      ambient: ambient,
                      size: 62,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ZAFER!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 3.2,
                        shadows: <Shadow>[
                          Shadow(
                            color:
                                BattlePalette.liquidGold.withValues(alpha: 0.92),
                            blurRadius: 26,
                          ),
                          const Shadow(color: Colors.black, blurRadius: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                if (comboStreak >= 2) ...<Widget>[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD9090D16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: rank.color.withValues(alpha: 0.85),
                        width: 1.2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: rank.color.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 13,
                          color: rank.color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'SAVAŞ STİLİ: ${rank.grade} • x$comboStreak KOMBO',
                          style: TextStyle(
                            color: rank.color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Pack 4: Skyward Diablo-style Rarity Loot Beam rising behind rare+ drops!
        if (result.itemDetails.isNotEmpty)
          Builder(
            builder: (BuildContext context) {
              Rarity bestRarity = Rarity.common;
              for (final DungeonItemDrop d in result.itemDetails) {
                final Rarity r = RarityParsing.fromValue(d.rarity);
                if (r.index > bestRarity.index) bestRarity = r;
              }
              if (!RarityLootBeamOverlay.shouldShowBeam(bestRarity)) {
                return const SizedBox.shrink();
              }
              return Align(
                alignment: const Alignment(0, -0.10),
                child: RarityLootBeamOverlay(
                  rarity: bestRarity,
                  height: 260,
                  width: 260,
                ),
              );
            },
          ),

        // Scrollable Constrained Bottom Loot Drawer
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: (availH * 0.50).clamp(290.0, 460.0),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DungeonResultBanner(
                    isCritical: result.isCritical,
                    isFirstClear: result.isFirstClear,
                  ),
                  if (result.siegeBonus != null)
                    DungeonSiegeResultBanner(bonus: result.siegeBonus!),
                  if (result.reputationBuffs.isNotEmpty)
                    ReputationBuffResultBanner(buffs: result.reputationBuffs),
                  if ((result.siegeBonus?.repGained ?? 0) > 0)
                    ReputationGainBanner(amount: result.siegeBonus!.repGained),
                  DungeonMilestoneBanner(rewards: result.milestoneRewards),
                  CodexDiscoveryChip(
                    discoveries: result.codexNew,
                    onTap: onOpenCodex,
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AdaptiveGlassBlur(
                      sigma: 10,
                      child: DungeonOrnamentalPanel(
                        style: profile.hudFrameStyle,
                        primary: BattlePalette.liquidGold,
                        secondary: profile.primaryColor,
                        fillAlpha: 0.78,
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              '${profile.enemyName.toUpperCase()} GANİMETİ',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: BattlePalette.liquidGold,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                _RewardTile(
                                  icon: Icons.monetization_on_rounded,
                                  label: 'ALTIN',
                                  value: result.goldEarned,
                                  color: BattlePalette.liquidGold,
                                ),
                                const SizedBox(width: 8),
                                _RewardTile(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'TECRÜBE',
                                  value: result.xpEarned,
                                  color: BattlePalette.toxicNeon,
                                  prefix: '+',
                                ),
                                if (result.itemDetails.isNotEmpty) ...<Widget>[
                                  const SizedBox(width: 8),
                                  _RewardTile(
                                    icon: Icons.backpack_rounded,
                                    label: 'EŞYA',
                                    value: result.itemDetails.length,
                                    color: profile.primaryColor,
                                  ),
                                ],
                              ],
                            ),
                            DungeonResultBalanceNotes(
                              rewardMultiplier: result.rewardMultiplier,
                              tutorialWrapperLootCount:
                                  result.tutorialWrapperLootCount,
                              siegeBonusApplied:
                                  result.siegeBonus?.shouldShowOnResult ??
                                      false,
                              xpBreakdown: result.xpBreakdown,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (result.itemDetails.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    DungeonItemRevealList(items: result.itemDetails),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 4,
                        child: _GhostButton(
                          label: 'Zindanlar',
                          icon: Icons.map_rounded,
                          accent: profile.primaryColor,
                          onTap: onBack,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: BattleCtaButton(
                          label: 'TEKRAR SALDIR',
                          icon: Icons.replay_rounded,
                          colors: <Color>[
                            profile.primaryColor,
                            profile.secondaryColor,
                          ],
                          glowColor: profile.primaryColor,
                          foreground: const Color(0xFF070A12),
                          onTap: canRetry ? onRetry : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullscreenDefeatOverlay extends StatelessWidget {
  const _FullscreenDefeatOverlay({
    required this.profile,
    required this.ambient,
    required this.hospitalized,
    required this.canFreeDischarge,
    required this.notices,
    required this.canRetry,
    required this.onRetry,
    required this.onGoHospital,
    required this.onBack,
  });

  final DungeonBattleProfile profile;
  final AnimationController ambient;
  final bool hospitalized;
  final bool canFreeDischarge;
  final List<String> notices;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onGoHospital;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Align(
          alignment: const Alignment(0, -0.74),
          child: IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ResultEmblem(
                  icon: hospitalized
                      ? Icons.local_hospital_rounded
                      : Icons.heart_broken_rounded,
                  colors: const <Color>[
                    Color(0xFFE52E2E),
                    Color(0xFF7F1D1D),
                  ],
                  glowColor: BattlePalette.mysticRuby,
                  ambient: ambient,
                  size: 62,
                ),
                const SizedBox(width: 10),
                Text(
                  hospitalized ? 'DÜŞTÜN!' : 'YENİLDİN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 3.2,
                    shadows: <Shadow>[
                      Shadow(
                        color: BattlePalette.mysticRuby.withValues(alpha: 0.92),
                        blurRadius: 28,
                      ),
                      const Shadow(color: Colors.black, blurRadius: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AdaptiveGlassBlur(
                      sigma: 10,
                      child: DungeonOrnamentalPanel(
                        style: profile.hudFrameStyle,
                        primary: BattlePalette.mysticRuby,
                        secondary: profile.primaryColor,
                        fillAlpha: 0.78,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < notices.length; i++)
                              Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 5),
                                child: Text(
                                  notices[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: i == 0
                                        ? const Color(0xFFFCA5A5)
                                        : Colors.white.withValues(alpha: 0.76),
                                    fontSize: i == 0 ? 13.5 : 12,
                                    fontWeight: i == 0
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    height: 1.32,
                                  ),
                                ),
                              ),
                            if (hospitalized && canFreeDischarge) ...<Widget>[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: BattlePalette.toxicNeon
                                      .withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: BattlePalette.toxicNeon
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Text(
                                  'İlk 2 düşüşte ücretsiz taburcu hakkın var.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF86EFAC),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 4,
                        child: _GhostButton(
                          label: 'Zindanlar',
                          icon: Icons.map_rounded,
                          accent: profile.primaryColor,
                          onTap: onBack,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: hospitalized
                            ? BattleCtaButton(
                                label: 'HASTANEYE GİT',
                                icon: Icons.local_hospital_rounded,
                                colors: const <Color>[
                                  Color(0xFFE52E2E),
                                  Color(0xFF991B1B),
                                ],
                                glowColor: BattlePalette.mysticRuby,
                                foreground: Colors.white,
                                onTap: onGoHospital,
                              )
                            : BattleCtaButton(
                                label: 'TEKRAR SALDIR',
                                icon: Icons.replay_rounded,
                                colors: <Color>[
                                  profile.primaryColor,
                                  profile.secondaryColor,
                                ],
                                glowColor: profile.primaryColor,
                                foreground: const Color(0xFF070A12),
                                onTap: canRetry ? onRetry : null,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xBF090D16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 17, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultEmblem extends StatelessWidget {
  const _ResultEmblem({
    required this.icon,
    required this.colors,
    required this.glowColor,
    required this.ambient,
    this.size = 76,
  });

  final IconData icon;
  final List<Color> colors;
  final Color glowColor;
  final AnimationController ambient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double inner = size * 0.72;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 950),
            curve: Curves.easeOut,
            builder: (BuildContext context, double t, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: ShockwavePainter(progress: t, color: glowColor),
              );
            },
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 780),
            curve: Curves.elasticOut,
            builder: (BuildContext context, double t, Widget? child) {
              return Transform.scale(scale: t, child: child);
            },
            child: Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.38),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.55),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: inner * 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.42)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, _) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$prefix${v.round()}',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
