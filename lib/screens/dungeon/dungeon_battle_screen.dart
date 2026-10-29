import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/bank_tutorial.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../core/utils/captcha_guard.dart';
import '../../core/utils/power_formula.dart';
import '../../models/dungeon_model.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dungeon_provider.dart';
import '../../models/dungeon_siege_model.dart';
import '../../providers/dungeon_siege_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'dungeon_item_utils.dart';
import 'dungeon_zone_data.dart';
import 'widgets/codex_discovery_chip.dart';
import 'dungeon_result_widgets.dart';
import '../reputation/widgets/reputation_gain_banner.dart';
import 'widgets/dungeon_battle_effects.dart';
import 'widgets/dungeon_cave_theme.dart';
import '../../core/vfx/directional_camera_shake.dart';
import 'widgets/dungeon_cinematic_atmosphere.dart';
import 'widgets/dungeon_combat_vfx.dart';
import 'widgets/dungeon_monster_glb_viewport.dart';
import 'widgets/aion2_boss_illustration_catalog.dart';
import 'widgets/aion2_presentation_frame.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

class DungeonBattleScreen extends ConsumerStatefulWidget {
  const DungeonBattleScreen({super.key});

  @override
  ConsumerState<DungeonBattleScreen> createState() => _DungeonBattleScreenState();
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

  /// Dynamic Combat Health & Boss Rage states
  int _playerMaxHp = 1000;
  int _playerCurrentHp = 1000;
  int _bossMaxHp = 1000;
  int _bossCurrentHp = 1000;
  bool _bossEnraged = false;
  bool _rageBannerActive = false;
  Timer? _rageBannerTimer;

  /// Ambient loop: embers, sweep bar, ring rotation, breathing.
  late final AnimationController _ambient;

  /// 2027 Cinematic AAA Dungeon Lighting, 3D Arena & Ground Decal Controller.
  late final DungeonAtmosphereController _atmosphereController;

  /// 2027 AAA Combat Feel & 9-Module VFX Controller.
  late final DungeonCombatVfxController _combatVfxController;
  DateTime _lastVfxTick = DateTime.now();

  /// 2027 Authentic Aion 2 Abyssal Monster & Boss 3D GLB Controller.
  late final DungeonMonsterGlbController _monsterController;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _atmosphereController = DungeonAtmosphereController();
    _combatVfxController = DungeonCombatVfxController(
      atmosphereController: _atmosphereController,
    );
    _monsterController = DungeonMonsterGlbController();
    _ambient.addListener(_onVfxTick);
  }

  void _onVfxTick() {
    final DateTime now = DateTime.now();
    final double dt = (now.difference(_lastVfxTick).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
    _lastVfxTick = now;
    _combatVfxController.update(dt);
    _monsterController.update(dt);
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _rageBannerTimer?.cancel();
    _ambient.removeListener(_onVfxTick);
    _ambient.dispose();
    _atmosphereController.dispose();
    _combatVfxController.dispose();
    _monsterController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_paramsLoaded) return;
    _paramsLoaded = true;
    final Map<String, String> params = GoRouterState.of(context).uri.queryParameters;
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
  // Battle flow (unchanged mechanics)
  // ===========================================================================

  void _resetForRetry() {
    if (_battleInFlight) return;
    _logTimer?.cancel();
    _rageBannerTimer?.cancel();
    _captchaRetryUsed = false;
    _rpcAttempted = false;
    setState(() {
      _result = null;
      _battleLog.clear();
      _logIndex = 0;
      _bossEnraged = false;
      _rageBannerActive = false;
    });
    _startCountdown();
  }

  void _triggerAtmosphericDecalForCombatLine(String line) {
    final String lower = line.toLowerCase();
    final bool isCritical = lower.contains('kritik') ||
        lower.contains('ezici') ||
        lower.contains('patlama');

    // Trigger 3D GLB monster combat flinch, rim hit-flash & trauma shake
    _monsterController.triggerHitReaction(isCritical: isCritical);

    if (isCritical || lower.contains('alev') || lower.contains('ateş')) {
      _atmosphereController.triggerScorchMark();
    } else if (lower.contains('kan') ||
        lower.contains('yaralandı') ||
        lower.contains('düştün') ||
        lower.contains('hasar') ||
        lower.contains('darbe')) {
      _atmosphereController.triggerBloodSplatter();
    } else if (lower.contains('sarsıldı') ||
        lower.contains('çatladı') ||
        lower.contains('yıkım') ||
        lower.contains('kaya') ||
        lower.contains('deprem')) {
      _atmosphereController.triggerCrackedFlagstones();
    } else {
      _atmosphereController.triggerSlashGouge();
    }
  }

  /// Hub ile aynı kapılar — deep-link /auto bypass engeli.
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
    final player = ref.read(playerProvider).profile;
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

    // The VS intro sequence drives timing; battle starts on its onComplete.
    setState(() {
      _phase = 'counting';
      _result = null;
      _battleLog.clear();
      _logIndex = 0;
    });
  }

  /// Randomized mid-combat flavor — fills the 7 s live battle report.
  List<String> _combatFlavorLines() {
    final List<String> pool = <String>[
      'Düşmanla göz göze geldin...',
      'İlk hamle senden — kılıç havada ıslık çalıyor!',
      'Düşman savurdu, son anda eğildin!',
      'Sert bir darbe aldın, dişini sıktın.',
      'Karşı saldırı! Darbe isabet etti!',
      'Düşman geriliyor, öfkeyle kükrüyor...',
      'Zayıf noktasını arıyorsun...',
      'Gölgeler arasında pozisyon alıyorsun.',
      'Son hamle için güç topluyorsun!',
    ];
    pool.shuffle(math.Random());
    return pool.take(8).toList();
  }

  static const int _kMinFightMs = 7000;

  bool get _battleLocked => _phase == 'counting' || _phase == 'fighting';

  void _processCombatHpStep(String line, int playerAtk, int playerDef) {
    final String lower = line.toLowerCase();
    final math.Random rng = math.Random();

    final bool isPlayerHit = lower.contains('ilk hamle') ||
        lower.contains('karşı saldırı') ||
        lower.contains('isabet etti') ||
        lower.contains('alt ettin') ||
        lower.contains('kritik') ||
        lower.contains('ezici') ||
        lower.contains('patlama') ||
        lower.contains('kılıç havada');

    final bool isEnemyHit = lower.contains('sert bir darbe') ||
        lower.contains('yaralandı') ||
        lower.contains('düştün') ||
        lower.contains('hasar') ||
        lower.contains('darbe');

    int nextBossHp = _bossCurrentHp;
    int nextPlayerHp = _playerCurrentHp;
    bool triggeredRageNow = false;

    if (isPlayerHit) {
      final bool isCrit = lower.contains('kritik') || lower.contains('ezici');
      final int dmg = isCrit
          ? (playerAtk * 2.2 + rng.nextInt(30)).round()
          : (playerAtk * 0.95 + rng.nextInt(20) + 15).round();
      // Keep boss above 10% until final RPC returns
      final int minFloor = (_bossMaxHp * 0.10).round();
      nextBossHp = math.max(minFloor, _bossCurrentHp - dmg);

      // Check Boss Rage threshold (<= 45% HP)
      if ((nextBossHp / _bossMaxHp) <= 0.45 && !_bossEnraged) {
        triggeredRageNow = true;
      }
    } else if (isEnemyHit) {
      final bool isCrit = lower.contains('düştün');
      final int baseEnemyAtk = (_zone * 18 + 22);
      final double rageMult = _bossEnraged ? 1.45 : 1.0;
      final int dmg = ((baseEnemyAtk * (isCrit ? 2.0 : 1.0) * rageMult) + rng.nextInt(15)).round();
      // Keep player above 15% until final RPC returns
      final int minFloor = (_playerMaxHp * 0.15).round();
      nextPlayerHp = math.max(minFloor, _playerCurrentHp - dmg);
    }

    if (triggeredRageNow) {
      _bossEnraged = true;
      _rageBannerActive = true;
      _rageBannerTimer?.cancel();
      _rageBannerTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) {
          setState(() => _rageBannerActive = false);
        }
      });
      _combatVfxController.cameraShake.triggerPreset(
        CameraShakePreset.heavyCrit,
        hitDirection: const Offset(0.0, 1.0),
        directionalWeight: 0.9,
      );
      _combatVfxController.triggerHaptic(HapticImpactLevel.critical);
      _monsterController.triggerHitReaction(isCritical: true, intensity: 1.6);
      _atmosphereController.triggerCrackedFlagstones();
    }

    setState(() {
      _bossCurrentHp = nextBossHp;
      _playerCurrentHp = nextPlayerHp;
    });
  }

  Future<void> _startBattle() async {
    if (_battleInFlight) return;
    _battleInFlight = true;

    unawaited(
      TutorialTriggers.onAnchorTap(ref, TutorialAnchorId.dungeonAttackBtn),
    );
    final int generation = ++_battleGeneration;
    final DateTime battleStart = DateTime.now();

    final PlayerProfile? curProfile = ref.read(playerProvider).profile;
    final int pMax = (curProfile?.maxHealth != null && curProfile!.maxHealth > 0)
        ? curProfile.maxHealth
        : ((curProfile?.level ?? 1) * 160 + 600);
    final int pCur = (curProfile?.health != null && curProfile!.health > 0)
        ? math.min(curProfile.health, pMax)
        : pMax;

    int powerReq = 0;
    for (final DungeonData d in ref.read(dungeonProvider).dungeons) {
      if (d.dungeonId == _dungeonId) {
        powerReq = d.powerRequirement ?? 0;
        break;
      }
    }
    final int bMax = powerReq > 0
        ? (powerReq * 2.2).round()
        : (_zone * 6500 + 4000);

    setState(() {
      _phase = 'fighting';
      _battleLog
        ..clear()
        ..addAll(zoneFlavorLines(_zone))
        ..addAll(_combatFlavorLines());
      _logIndex = 0;
      _playerMaxHp = pMax;
      _playerCurrentHp = pCur;
      _bossMaxHp = bMax;
      _bossCurrentHp = bMax;
      _bossEnraged = false;
      _rageBannerActive = false;
    });

    _logTimer = Timer.periodic(const Duration(milliseconds: 650), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_logIndex < _battleLog.length - 1) {
        setState(() => _logIndex++);
        if (_logIndex < _battleLog.length) {
          final String line = _battleLog[_logIndex];
          _triggerAtmosphericDecalForCombatLine(line);
          final player = ref.read(playerProvider).profile;
          final int playerAtk = player?.attack ?? 25;
          final int playerDef = player?.defense ?? 25;
          _combatVfxController.processCombatLine(
            line,
            playerAttack: playerAtk,
            playerDefense: playerDef,
          );
          _processCombatHpStep(line, playerAtk, playerDef);
        }
      }
    });

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
          _playerCurrentHp = math.max(1, _playerCurrentHp);
          _bossCurrentHp = 0;
          final player = ref.read(playerProvider).profile;
          if (parsed.isCritical) {
            _battleLog.add('Ezici bir vuruş!');
            _atmosphereController.triggerScorchMark();
            _combatVfxController.triggerFinishingBlow(
              isPlayerWinner: true,
              fatalDamage: ((player?.attack ?? 30) * 2.5).round(),
            );
          } else {
            _battleLog.add('Düşmanı alt ettin!');
            _atmosphereController.triggerSlashGouge();
            _combatVfxController.triggerFinishingBlow(
              isPlayerWinner: true,
              fatalDamage: ((player?.attack ?? 30) * 1.5).round(),
            );
          }
        } else if (parsed.hospitalized) {
          _playerCurrentHp = 0;
          _battleLog.add('Son vuruşta düştün...');
          _battleLog.add('Hastaneye kaldırılıyorsun.');
          _atmosphereController.triggerBloodSplatter();
          final player = ref.read(playerProvider).profile;
          _combatVfxController.triggerFinishingBlow(
            isPlayerWinner: false,
            fatalDamage: ((player?.defense ?? 20) * 2.2).round(),
          );
        } else {
          _playerCurrentHp = 0;
          _battleLog.add('Son vuruşta düştün...');
          _battleLog.add('Bu sefer şans senden yana değildi.');
          _atmosphereController.triggerBloodSplatter();
          final player = ref.read(playerProvider).profile;
          _combatVfxController.triggerFinishingBlow(
            isPlayerWinner: false,
            fatalDamage: ((player?.defense ?? 20) * 1.8).round(),
          );
        }

        setState(() {
          _result = parsed;
          _logIndex = _battleLog.length - 1;
          _phase = parsed.success ? 'success' : 'failure';
        });

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
          _playerCurrentHp = 0;
          _result = null;
          _phase = 'failure';
        });
      }
    } catch (e) {
      _logTimer?.cancel();
      _rageBannerTimer?.cancel();
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
    final player = ref.read(playerProvider).profile;
    if (player == null) return false;
    return _preflightBlockReason(player) == null;
  }

  // ===========================================================================
  // Theme helpers
  // ===========================================================================

  CaveCardTheme get _caveTheme =>
      CaveCardTheme.forDungeonNumber(parseDungeonNumber(_dungeonId)) ??
      CaveCardTheme.cyberCave;

  String get _characterAsset {
    final CharacterClass? cls = ref.read(playerProvider).profile?.characterClass;
    return switch (cls) {
      CharacterClass.shadow => 'assets/characters/golge.png',
      CharacterClass.alchemist => 'assets/characters/simyaci.png',
      _ => 'assets/characters/savasci.png',
    };
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    Future<void> logoutHandler() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    final CaveCardTheme theme = _caveTheme;
    final bool ambientFx = _phase == 'counting' || _phase == 'fighting';

    return PopScope(
      canPop: !_battleLocked,
      child: Scaffold(
      backgroundColor: BattlePalette.carbonVoid,
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.dungeon,
        onLogout: logoutHandler,
        navigationLocked: _battleLocked,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _BattleBackdrop(
            theme: theme,
            ambient: _ambient,
            embers: ambientFx,
            atmosphereController: _atmosphereController,
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _buildHeader(theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (Widget child, Animation<double> anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.96, end: 1).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<String>(_phase),
                        child: _buildPhaseContent(theme),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader(CaveCardTheme theme) {
    final profile = ref.watch(playerProvider).profile;
    final int energy = profile?.energy ?? 0;
    final int maxEnergy = profile?.maxEnergy ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: <Widget>[
          PressableScale(
            onTap: _battleLocked
                ? () => AppMessenger.show(context, 'Savaş bitene kadar çıkamazsın.')
                : () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BattlePalette.spaceNavy.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DungeonInsetText(
                  _dungeonName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'BÖLGE $_zone • ZİNDAN SAVAŞI',
                  style: TextStyle(
                    color: theme.accentGlow.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BattleChip(
            icon: Icons.bolt_rounded,
            label: 'ENERJİ',
            value: maxEnergy > 0 ? '$energy/$maxEnergy' : '$energy',
            color: BattlePalette.warningSolar,
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent(CaveCardTheme theme) {
    switch (_phase) {
      case 'counting':
        final PlayerProfile? profile = ref.read(playerProvider).profile;
        final String playerName =
            ((profile?.displayName ?? profile?.username) ?? 'SEN').trim();

        int? powerRequirement;
        for (final DungeonData d in ref.read(dungeonProvider).dungeons) {
          if (d.dungeonId == _dungeonId) {
            powerRequirement = d.powerRequirement;
            break;
          }
        }
        int? successPct;
        int? combatPower;
        if (profile != null &&
            powerRequirement != null &&
            powerRequirement > 0) {
          final equipped = ref.read(inventoryProvider).equippedItems.values;
          combatPower = resolveDungeonCombatPower(
            profile: profile,
            equippedItems: equipped,
          );
          successPct = computeDungeonSuccessPercent(
            profile: profile,
            dungeonPowerRequirement: powerRequirement,
            equippedItems: equipped,
          );
        }

        return _VsIntroView(
          theme: theme,
          characterAsset: _characterAsset,
          playerName: playerName.isEmpty ? 'SEN' : playerName,
          playerLevel: profile?.level ?? 1,
          playerPower: combatPower ?? profile?.power ?? 0,
          playerAttack: profile?.attack ?? 0,
          playerDefense: profile?.defense ?? 0,
          dungeonName: _dungeonName,
          zone: _zone,
          dungeonNumber: parseDungeonNumber(_dungeonId),
          powerRequirement: powerRequirement,
          successPct: successPct,
          onComplete: _startBattle,
        );
      case 'fighting':
        final PlayerProfile? prof = ref.read(playerProvider).profile;
        final String pName = ((prof?.displayName ?? prof?.username) ?? 'SEN').trim();
        final Aion2BossArtDefinition bossArt =
            Aion2BossIllustrationCatalog.resolveForZone(_zone);

        return _FightingView(
          theme: theme,
          ambient: _ambient,
          characterAsset: _characterAsset,
          logLines: _battleLog.take(_logIndex + 1).toList(),
          vfxController: _combatVfxController,
          zone: _zone,
          monsterController: _monsterController,
          playerName: pName.isEmpty ? 'SEN' : pName,
          playerHp: _playerCurrentHp,
          playerMaxHp: _playerMaxHp,
          bossName: bossArt.name,
          bossTitle: bossArt.title,
          bossHp: _bossCurrentHp,
          bossMaxHp: _bossMaxHp,
          isBossEnraged: _bossEnraged,
          isRageBannerActive: _rageBannerActive,
        );
      case 'success':
        return _buildSuccessPhase();
      case 'failure':
        return _buildFailurePhase(theme);
      case 'idle':
      default:
        return _IdleView(
          theme: theme,
          ambient: _ambient,
          dungeonName: _dungeonName,
          zone: _zone,
          energyCost: _energyCost,
          dungeonNumber: parseDungeonNumber(_dungeonId),
          characterAsset: _characterAsset,
          onAttack: () async {
            await TutorialTriggers.onAnchorTap(
              ref,
              TutorialAnchorId.dungeonAttackBtn,
            );
            _startCountdown();
          },
          onBack: () => context.pop(),
        );
    }
  }

  Widget _buildSuccessPhase() {
    final DungeonResult? result = _result;
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _VictoryView(theme: _caveTheme, ambient: _ambient, result: result),
        const SizedBox(height: 18),
        FadeSlideIn(
          delayMs: 250,
          child: BattleCtaButton(
            label: 'TEKRAR SALDIR',
            icon: Icons.replay_rounded,
            onTap: _canRetry() ? _resetForRetry : null,
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delayMs: 380,
          child: _GhostButton(
            label: 'Zindanlara Dön',
            icon: Icons.map_rounded,
            onTap: () => context.pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildFailurePhase(CaveCardTheme theme) {
    final DungeonResult? result = _result;
    final bool hospitalized = result?.hospitalized == true;
    final String duration = _formatDuration(result?.hospitalDurationSeconds ?? 0);
    final int dungeonNum = parseDungeonNumber(_dungeonId);
    final List<String> notices = hospitalized
        ? <String>['Hastaneye düştün', 'Tedavi süresi: $duration']
        : dungeonNum <= 3
            ? <String>['Başarısız', 'Tekrar dene.']
            : <String>['Yenildin', 'Bu sefer şanssızdın, tekrar dene.'];

    final int hospitalCount =
        ref.read(playerProvider).profile?.hospitalLifetimeCount ?? 0;
    final bool canFree = canFreeHospitalDischarge(hospitalCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DefeatView(
          ambient: _ambient,
          hospitalized: hospitalized,
          notices: notices,
        ),
        if (hospitalized && canFree) ...<Widget>[
          const SizedBox(height: 12),
          FadeSlideIn(
            delayMs: 200,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: BattlePalette.toxicNeon.withValues(alpha: 0.08),
                border: Border.all(
                    color: BattlePalette.toxicNeon.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'İlk 2 düşüşte ücretsiz taburcu hakkın var.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF86EFAC),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (hospitalized)
          FadeSlideIn(
            delayMs: 260,
            child: BattleCtaButton(
              label: 'HASTANEYE GİT',
              icon: Icons.local_hospital_rounded,
              colors: const <Color>[Color(0xFFE52E2E), Color(0xFF991B1B)],
              glowColor: BattlePalette.mysticRuby,
              foreground: Colors.white,
              onTap: () => context.go(AppRoutes.hospital),
            ),
          ),
        if (!hospitalized)
          FadeSlideIn(
            delayMs: 260,
            child: BattleCtaButton(
              label: 'TEKRAR SALDIR',
              icon: Icons.replay_rounded,
              colors: const <Color>[Color(0xFFE01E5A), Color(0xFF9F1239)],
              glowColor: BattlePalette.cyberFuchsia,
              foreground: Colors.white,
              onTap: _canRetry() ? _resetForRetry : null,
            ),
          ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delayMs: 380,
          child: _GhostButton(
            label: 'Zindanlara Dön',
            icon: Icons.map_rounded,
            onTap: () => context.pop(),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Backdrop — dungeon art hero + feather into Carbon Void + dots + embers.
// =============================================================================
class _BattleBackdrop extends StatelessWidget {
  const _BattleBackdrop({
    required this.theme,
    required this.ambient,
    required this.embers,
    required this.atmosphereController,
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final bool embers;
  final DungeonAtmosphereController atmosphereController;

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 2027 AAA Cinematic Atmosphere: 3D flagstone arena, flickering torches, soft shadows, ground decals, mist
        DungeonCinematicAtmosphere(
          controller: atmosphereController,
          theme: theme,
          showTorches: true,
          showArena3D: true,
          showMist: true,
          showDecals: true,
          showDynamicShadows: true,
        ),
        // Dungeon art fills the top half, feathered downward.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: screenHeight * 0.58,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: <double>[0, 0.45, 0.75, 1],
                colors: <Color>[
                  Color(0xB0FFFFFF),
                  Color(0x80FFFFFF),
                  Color(0x30FFFFFF),
                  Color(0x00FFFFFF),
                ],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              theme.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                  ColoredBox(color: theme.surfaceDeep.withValues(alpha: 0.5)),
            ),
          ),
        ),
        // Accent tint from the bottom to seat the content.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                BattlePalette.carbonVoid.withValues(alpha: 0.25),
                BattlePalette.carbonVoid.withValues(alpha: 0.85),
              ],
              stops: const <double>[0.25, 0.55, 0.95],
            ),
          ),
        ),
        // Dot mesh texture (tasarim rule: no flat backgrounds).
        const CustomPaint(painter: DotPatternPainter()),
        // Rising embers during combat phases.
        if (embers)
          AnimatedBuilder(
            animation: ambient,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                painter: EmberFieldPainter(
                  progress: ambient.value,
                  color: theme.accentGlow,
                ),
              );
            },
          ),
      ],
    );
  }
}

// =============================================================================
// Idle — hero intro: 3D abyssal boss / monster GLB preview vs character, stat chips, gold CTA.
// =============================================================================
class _IdleView extends StatefulWidget {
  const _IdleView({
    required this.theme,
    required this.ambient,
    required this.dungeonName,
    required this.zone,
    required this.energyCost,
    required this.dungeonNumber,
    required this.characterAsset,
    required this.onAttack,
    required this.onBack,
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final String dungeonName;
  final int zone;
  final int energyCost;
  final int dungeonNumber;
  final String characterAsset;
  final VoidCallback onAttack;
  final VoidCallback onBack;

  @override
  State<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends State<_IdleView> {
  bool _show3dMonster = true;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final dungeonName = widget.dungeonName;
    final zone = widget.zone;
    final dungeonNumber = widget.dungeonNumber;
    final energyCost = widget.energyCost;
    final onAttack = widget.onAttack;
    final onBack = widget.onBack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 6),
        // Toggle pill between 3D Monster / Abyssal Boss and Player Character
        Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: BattlePalette.spaceNavy.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.theme.accent.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _show3dMonster = true);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _show3dMonster
                          ? widget.theme.accent.withValues(alpha: 0.35)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: _show3dMonster
                          ? Border.all(color: widget.theme.accentGlow.withValues(alpha: 0.6))
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.pets_rounded,
                          size: 13,
                          color: _show3dMonster ? Colors.white : Colors.white60,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '3D Canavar',
                          style: TextStyle(
                            color: _show3dMonster ? Colors.white : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _show3dMonster = false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: !_show3dMonster
                          ? BattlePalette.toxicNeon.withValues(alpha: 0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: !_show3dMonster
                          ? Border.all(color: BattlePalette.toxicNeon.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.person_pin,
                          size: 13,
                          color: !_show3dMonster ? Colors.white : Colors.white60,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Kahraman',
                          style: TextStyle(
                            color: !_show3dMonster ? Colors.white : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 3D Monster Viewport or Breathing character
        FadeSlideIn(
          child: SizedBox(
            height: 250,
            child: _show3dMonster
                ? DungeonMonsterGlbViewport(
                    zone: widget.zone,
                    height: 250,
                    interactive: true,
                    showBadge: true,
                    showPedestal: true,
                    showAura: true,
                  )
                : AnimatedBuilder(
                    animation: widget.ambient,
                    builder: (BuildContext context, Widget? child) {
                      final double breathe =
                          math.sin(widget.ambient.value * 2 * math.pi) * 6;
                      return Transform.translate(
                        offset: Offset(0, breathe),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      widget.characterAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                          Image.asset(
                        'assets/renders/characters/Knight_beauty.png',
                        fit: BoxFit.contain,
                        height: 140,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/characters/savasci.png',
                          fit: BoxFit.contain,
                          height: 140,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delayMs: 120,
          child: GlassPanel(
            accent: theme.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'MEYDAN OKUMA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.accentGlow,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                DungeonInsetText(
                  dungeonName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    BattleChip(
                      icon: Icons.terrain_rounded,
                      label: 'BÖLGE',
                      value: '$zone',
                      color: theme.accent,
                    ),
                    BattleChip(
                      icon: Icons.castle_rounded,
                      label: 'ZİNDAN',
                      value: '#$dungeonNumber',
                      color: BattlePalette.cyberFuchsia,
                    ),
                    if (energyCost > 0)
                      BattleChip(
                        icon: Icons.bolt_rounded,
                        label: 'MALİYET',
                        value: '$energyCost',
                        color: BattlePalette.warningSolar,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Aion2BossPortraitCard(
                  boss: Aion2BossIllustrationCatalog.resolveForZone(widget.zone),
                  height: 110,
                  animationProgress: widget.ambient.value,
                  showLore: true,
                ),
                const SizedBox(height: 12),
                Text(
                  'Karanlığın derinlerinde düşman seni bekliyor. Hazır olduğunda saldır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BattlePalette.mutedTitanium,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                TutorialAnchorScope(
                  id: TutorialAnchorId.dungeonAttackBtn,
                  child: BattleCtaButton(
                    label: 'SALDIR',
                    icon: Icons.sports_martial_arts_rounded,
                    onTap: onAttack,
                  ),
                ),
                const SizedBox(height: 10),
                _GhostButton(
                  label: 'Geri Dön',
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// VS intro — cinematic pre-battle sequence:
// slam → stat duel → 3-2-1 countdown → SAVAŞ! burst → battle starts.
// =============================================================================
class _VsIntroView extends StatefulWidget {
  const _VsIntroView({
    required this.theme,
    required this.characterAsset,
    required this.playerName,
    required this.playerLevel,
    required this.playerPower,
    required this.playerAttack,
    required this.playerDefense,
    required this.dungeonName,
    required this.zone,
    required this.dungeonNumber,
    required this.powerRequirement,
    required this.successPct,
    required this.onComplete,
  });

  final CaveCardTheme theme;
  final String characterAsset;
  final String playerName;
  final int playerLevel;
  final int playerPower;
  final int playerAttack;
  final int playerDefense;
  final String dungeonName;
  final int zone;
  final int dungeonNumber;
  final int? powerRequirement;
  final int? successPct;
  final VoidCallback onComplete;

  @override
  State<_VsIntroView> createState() => _VsIntroViewState();
}

class _VsIntroViewState extends State<_VsIntroView>
    with SingleTickerProviderStateMixin {
  static const int _kTotalMs = 7200;
  static const int _kSlamMs = 1100;
  static const int _kStatsInMs = 1100;
  static const int _kCountStartMs = 2400;
  static const int _kCountStepMs = 1000;
  static const int _kBurstStartMs = 5400;

  late final AnimationController _seq;
  int _lastNumber = 0;
  bool _slamHapticDone = false;
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
    if (!_slamHapticDone && v >= _f(900)) {
      _slamHapticDone = true;
      HapticFeedback.mediumImpact();
    }
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
    _seq.animateTo(1.0,
        duration: const Duration(milliseconds: 260), curve: Curves.easeIn);
  }

  Color _numberColor(int n) => switch (n) {
        3 => BattlePalette.warningSolar,
        2 => BattlePalette.coralFlare,
        _ => BattlePalette.mysticRuby,
      };

  String _resolveBossPortrait(Aion2BossArtDefinition boss) {
    final String id = boss.bossId.toLowerCase();
    if (id.contains('kromede')) return 'assets/images/portraits/bosses/boss_kromede.png';
    if (id.contains('stormwing')) return 'assets/images/portraits/bosses/boss_stormwing.png';
    if (id.contains('tahabata')) return 'assets/images/portraits/bosses/boss_tahabata.png';
    if (id.contains('beritra')) return 'assets/images/portraits/bosses/boss_beritra.png';
    if (id.contains('ereshkigal')) return 'assets/images/portraits/bosses/boss_ereshkigal.png';
    if (id.contains('tiamat')) return 'assets/images/portraits/bosses/boss_tiamat.png';
    return switch (boss.zone) {
      1 => 'assets/images/portraits/bosses/boss_kromede.png',
      2 => 'assets/images/portraits/bosses/boss_stormwing.png',
      3 => 'assets/images/portraits/bosses/boss_tahabata.png',
      4 => 'assets/images/portraits/bosses/boss_beritra.png',
      5 => 'assets/images/portraits/bosses/boss_ereshkigal.png',
      _ => 'assets/images/portraits/bosses/boss_tiamat.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final CaveCardTheme theme = widget.theme;
    final Aion2BossArtDefinition bossArt =
        Aion2BossIllustrationCatalog.resolveForZone(widget.zone);

    return AnimatedBuilder(
      animation: _seq,
      builder: (BuildContext context, Widget? child) {
        final double v = _seq.value;

        final double slamT = Curves.elasticOut
            .transform(((v * _kTotalMs) / _kSlamMs).clamp(0.0, 1.0));
        final double slideT = Curves.easeOutCubic
            .transform(((v * _kTotalMs) / _kSlamMs).clamp(0.0, 1.0));
        final double shockT =
            ((v - _f(300)) / (_f(1700) - _f(300))).clamp(0.0, 1.0);
        final double statsT = Curves.easeOutCubic.transform(
            ((v - _f(_kStatsInMs)) / _f(900)).clamp(0.0, 1.0));

        final int? number = _numberAt(v);
        final bool inCountdown = number != null;
        final bool inBurst = v >= _f(_kBurstStartMs);

        final double burstT =
            ((v - _f(_kBurstStartMs)) / (1 - _f(_kBurstStartMs)))
                .clamp(0.0, 1.0);
        final double flashOpacity =
            inBurst ? math.sin((burstT * 1.6).clamp(0.0, 1.0) * math.pi) * 0.55 : 0.0;

        // Decaying screen shake on the SAVAŞ! hit.
        double shakeX = 0;
        double shakeY = 0;
        if (inBurst && burstT < 0.45) {
          final double amp = (1 - burstT / 0.45) * 7;
          shakeX = math.sin(burstT * 90) * amp;
          shakeY = math.cos(burstT * 70) * amp * 0.6;
        }

        return Stack(
          children: <Widget>[
            Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 6),
                  // ── Duel slam: portraits fly in from both edges.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Transform.translate(
                        offset: Offset(-300 * (1 - slideT), 0),
                        child: _DuelPortrait(
                          asset: widget.characterAsset,
                          borderColor: BattlePalette.toxicNeon,
                          label: 'SEN',
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        height: 130,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            CustomPaint(
                              size: const Size(130, 130),
                              painter: ShockwavePainter(
                                progress: shockT,
                                color: BattlePalette.cyberFuchsia,
                              ),
                            ),
                            Transform.scale(
                              scale: slamT,
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: <Color>[
                                      BattlePalette.cyberFuchsia,
                                      BattlePalette.liquidGold,
                                    ],
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: BattlePalette.cyberFuchsia
                                          .withValues(alpha: 0.6),
                                      blurRadius: 26,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'VS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(300 * (1 - slideT), 0),
                        child: _DuelPortrait(
                          asset: _resolveBossPortrait(bossArt),
                          borderColor: bossArt.goldFiligreeColor,
                          label: bossArt.name,
                          cover: true,
                          bossDef: bossArt,
                          animationProgress: v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: BattlePalette.spaceNavy.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: bossArt.goldFiligreeColor.withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: bossArt.glowColor.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(bossArt.tier.icon, size: 11, color: bossArt.goldFiligreeColor),
                          const SizedBox(width: 5),
                          Text(
                            '${bossArt.tier.label} • ${bossArt.title.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: bossArt.goldFiligreeColor,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Stat duel panel.
                  Opacity(
                    opacity: statsT,
                    child: Transform.translate(
                      offset: Offset(0, (1 - statsT) * 24),
                      child: _StatDuelPanel(
                        theme: theme,
                        playerName: widget.playerName,
                        playerLevel: widget.playerLevel,
                        playerPower: widget.playerPower,
                        playerAttack: widget.playerAttack,
                        playerDefense: widget.playerDefense,
                        dungeonName: widget.dungeonName,
                        zone: widget.zone,
                        dungeonNumber: widget.dungeonNumber,
                        powerRequirement: widget.powerRequirement,
                        successPct: widget.successPct,
                        fillT: statsT,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── Countdown / SAVAŞ! arena.
                  SizedBox(
                    height: 230,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        if (inCountdown)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SpeedLinesPainter(
                                progress: v * 6,
                                color: _numberColor(number),
                              ),
                            ),
                          ),
                        if (inCountdown) ...<Widget>[
                          CustomPaint(
                            size: const Size(190, 190),
                            painter: CountdownRingPainter(
                              rotation: v * 2 * math.pi * 8,
                              color: _numberColor(number),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 520),
                            switchInCurve: Curves.elasticOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder:
                                (Widget child, Animation<double> anim) {
                              return ScaleTransition(
                                scale: anim,
                                child:
                                    FadeTransition(opacity: anim, child: child),
                              );
                            },
                            child: Text(
                              '$number',
                              key: ValueKey<int>(number),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 104,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: _numberColor(number)
                                        .withValues(alpha: 0.85),
                                    blurRadius: 34,
                                  ),
                                  Shadow(
                                    color: BattlePalette.liquidGold
                                        .withValues(alpha: 0.3),
                                    blurRadius: 60,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (inBurst)
                          Transform.scale(
                            scale: Curves.elasticOut
                                .transform((burstT * 2.2).clamp(0.0, 1.0)),
                            child: Text(
                              'SAVAŞ!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 58,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 3,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: BattlePalette.cyberFuchsia
                                        .withValues(alpha: 0.9),
                                    blurRadius: 36,
                                  ),
                                  Shadow(
                                    color: BattlePalette.liquidGold
                                        .withValues(alpha: 0.5),
                                    blurRadius: 70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!inCountdown && !inBurst)
                          AnimatedBuilder(
                            animation: _seq,
                            builder: (BuildContext context, Widget? child) {
                              final double pulse = 0.5 +
                                  0.5 *
                                      math
                                          .sin(v * 2 * math.pi * 10)
                                          .abs();
                              return Opacity(
                                  opacity: statsT * pulse, child: child);
                            },
                            child: Text(
                              'HAZIRLAN',
                              style: TextStyle(
                                color: theme.accentGlow,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 7,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ── Skip.
                  if (!inBurst)
                    Center(
                      child: PressableScale(
                        onTap: _skip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: BattlePalette.spaceNavy
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Text(
                            'İNTROYU GEÇ ▸',
                            style: TextStyle(
                              color: BattlePalette.mutedTitanium,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Impact flash.
            if (flashOpacity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: <Color>[
                          const Color(0xFFFFF3D6)
                              .withValues(alpha: flashOpacity),
                          BattlePalette.liquidGold
                              .withValues(alpha: flashOpacity * 0.5),
                          Colors.transparent,
                        ],
                        stops: const <double>[0, 0.45, 1],
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

// =============================================================================
// Stat duel panel — player stats vs dungeon stats + success chance bar.
// =============================================================================
class _StatDuelPanel extends StatelessWidget {
  const _StatDuelPanel({
    required this.theme,
    required this.playerName,
    required this.playerLevel,
    required this.playerPower,
    required this.playerAttack,
    required this.playerDefense,
    required this.dungeonName,
    required this.zone,
    required this.dungeonNumber,
    required this.powerRequirement,
    required this.successPct,
    required this.fillT,
  });

  final CaveCardTheme theme;
  final String playerName;
  final int playerLevel;
  final int playerPower;
  final int playerAttack;
  final int playerDefense;
  final String dungeonName;
  final int zone;
  final int dungeonNumber;
  final int? powerRequirement;
  final int? successPct;

  /// 0..1 entry progress — drives the success bar fill.
  final double fillT;

  @override
  Widget build(BuildContext context) {
    final Color chanceColor = successPct != null
        ? theme.threatForSuccess(successPct!)
        : BattlePalette.mutedTitanium;

    return GlassPanel(
      accent: theme.accent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _StatSide(
                  title: playerName,
                  titleColor: BattlePalette.toxicNeon,
                  bigLabel: 'GÜÇ',
                  bigValue: '$playerPower',
                  bigColor: BattlePalette.liquidGold,
                  chips: <Widget>[
                    BattleChip(
                      icon: Icons.military_tech_rounded,
                      label: 'LV',
                      value: '$playerLevel',
                      color: BattlePalette.toxicNeon,
                    ),
                    BattleChip(
                      icon: Icons.gps_fixed_rounded,
                      label: 'ATK',
                      value: '$playerAttack',
                      color: BattlePalette.coralFlare,
                    ),
                    BattleChip(
                      icon: Icons.shield_rounded,
                      label: 'DEF',
                      value: '$playerDefense',
                      color: theme.accent,
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 96,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _StatSide(
                  title: dungeonName,
                  titleColor: BattlePalette.mysticRuby,
                  bigLabel: 'GEREKEN GÜÇ',
                  bigValue:
                      powerRequirement != null ? '$powerRequirement' : '???',
                  bigColor: BattlePalette.cyberFuchsia,
                  chips: <Widget>[
                    BattleChip(
                      icon: Icons.terrain_rounded,
                      label: 'BÖLGE',
                      value: '$zone',
                      color: theme.accent,
                    ),
                    BattleChip(
                      icon: Icons.castle_rounded,
                      label: 'ZİNDAN',
                      value: '#$dungeonNumber',
                      color: BattlePalette.cyberFuchsia,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (successPct != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'BAŞARI ŞANSI',
                  style: TextStyle(
                    color: BattlePalette.mutedTitanium,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '%$successPct',
                  style: TextStyle(
                    color: chanceColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 7,
                child: Stack(
                  children: <Widget>[
                    Container(color: Colors.white.withValues(alpha: 0.07)),
                    FractionallySizedBox(
                      widthFactor:
                          ((successPct! / 100) * fillT).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              chanceColor.withValues(alpha: 0.7),
                              chanceColor,
                            ],
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: chanceColor.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
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

class _StatSide extends StatelessWidget {
  const _StatSide({
    required this.title,
    required this.titleColor,
    required this.bigLabel,
    required this.bigValue,
    required this.bigColor,
    required this.chips,
  });

  final String title;
  final Color titleColor;
  final String bigLabel;
  final String bigValue;
  final Color bigColor;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: titleColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bigLabel,
          style: TextStyle(
            color: BattlePalette.mutedTitanium,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          bigValue,
          style: TextStyle(
            color: bigColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            shadows: <Shadow>[
              Shadow(color: bigColor.withValues(alpha: 0.45), blurRadius: 14),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: chips,
        ),
      ],
    );
  }
}

// =============================================================================
// Fighting — duel layout: hero vs dungeon, clash icon, live combat log.
// =============================================================================
class _FightingView extends StatelessWidget {
  const _FightingView({
    required this.theme,
    required this.ambient,
    required this.characterAsset,
    required this.logLines,
    required this.vfxController,
    required this.zone,
    this.monsterController,
    required this.playerName,
    required this.playerHp,
    required this.playerMaxHp,
    required this.bossName,
    required this.bossTitle,
    required this.bossHp,
    required this.bossMaxHp,
    required this.isBossEnraged,
    required this.isRageBannerActive,
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final String characterAsset;
  final List<String> logLines;
  final DungeonCombatVfxController vfxController;
  final int zone;
  final DungeonMonsterGlbController? monsterController;
  final String playerName;
  final int playerHp;
  final int playerMaxHp;
  final String bossName;
  final String bossTitle;
  final int bossHp;
  final int bossMaxHp;
  final bool isBossEnraged;
  final bool isRageBannerActive;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // 1. Subtle perimeter rage vignette when boss is enraged
        if (isBossEnraged)
          _BossRageScreenVignette(ambient: ambient),

        // 2. Hit-Stop micro-pause specular freeze-frame overlay
        _HitStopFreezeOverlay(vfxController: vfxController),

        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 8),

            // 3. DUAL COMBAT HEALTH HUD WITH IMPACT CATCHUP DRAINS
            FadeSlideIn(
              child: _DualCombatHealthHud(
                playerName: playerName,
                playerHp: playerHp,
                playerMaxHp: playerMaxHp,
                bossName: bossName,
                bossTitle: bossTitle,
                bossHp: bossHp,
                bossMaxHp: bossMaxHp,
                isBossEnraged: isBossEnraged,
                theme: theme,
              ),
            ),

            if (isRageBannerActive)
              const _BossRageAnnouncementBanner(),

            const SizedBox(height: 10),

            // 4. DUEL ARENA HOST: Character vs Boss with all 9 VFX modules
            FadeSlideIn(
              delayMs: 60,
              child: DungeonCombatVfxArenaHost(
                controller: vfxController,
                playerPortrait: _DuelPortrait(
                  asset: characterAsset,
                  borderColor: BattlePalette.toxicNeon,
                  label: playerName,
                ),
                enemyPortrait: _DuelPortrait(
                  asset: theme.assetPath,
                  borderColor: isBossEnraged
                      ? BattlePalette.coralFlare
                      : BattlePalette.mysticRuby,
                  label: bossName,
                  cover: true,
                  isEnraged: isBossEnraged,
                ),
                clashIcon: AnimatedBuilder(
                  animation: ambient,
                  builder: (BuildContext context, Widget? child) {
                    final double t = ambient.value * 2 * math.pi;
                    final double shake = math.sin(t * 14) * 2.4;
                    final double tilt = math.sin(t * 7) * 0.09;
                    return Transform.translate(
                      offset: Offset(shake, -shake.abs() * 0.4),
                      child: Transform.rotate(angle: tilt, child: child),
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isBossEnraged
                            ? const <Color>[
                                BattlePalette.mysticRuby,
                                BattlePalette.warningSolar,
                              ]
                            : const <Color>[
                                BattlePalette.cyberFuchsia,
                                Color(0xFF9F1239),
                              ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (isBossEnraged
                                  ? BattlePalette.mysticRuby
                                  : BattlePalette.cyberFuchsia)
                              .withValues(alpha: 0.6),
                          blurRadius: 26,
                        ),
                      ],
                    ),
                    child: Icon(
                      isBossEnraged
                          ? Icons.local_fire_department_rounded
                          : Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 5. 2027 Authentic Aion 2 Abyssal Monster & Boss 3D GLB Viewport with 2.5D Parallax Camera Shake
            FadeSlideIn(
              delayMs: 80,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListenableBuilder(
                  listenable: vfxController.cameraShake,
                  builder: (BuildContext context, Widget? child) {
                    final Offset shakeOffset =
                        vfxController.cameraShake.state.translation * 0.65;
                    return Transform.translate(
                      offset: shakeOffset,
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      if (isBossEnraged)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: ambient,
                            builder: (BuildContext context, Widget? child) {
                              final double pulse = 0.25 +
                                  0.15 *
                                      math
                                          .sin(ambient.value * 2 * math.pi * 4)
                                          .abs();
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: BattlePalette.mysticRuby
                                          .withValues(alpha: pulse),
                                      blurRadius: 50,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      DungeonMonsterGlbViewport(
                        zone: zone,
                        height: 220,
                        controller: monsterController,
                        interactive: true,
                        showBadge: true,
                        showPedestal: true,
                        showAura: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 6. Combat sweep bar.
            FadeSlideIn(
              delayMs: 140,
              child: AnimatedBuilder(
                animation: ambient,
                builder: (BuildContext context, Widget? child) {
                  return EnergySweepBar(progress: (ambient.value * 3) % 1.0);
                },
              ),
            ),

            const SizedBox(height: 16),

            // 7. Live combat log console.
            GlassPanel(
              accent: theme.accent,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.radio_button_checked_rounded,
                          size: 12, color: BattlePalette.mysticRuby),
                      const SizedBox(width: 6),
                      Text(
                        'SAVAŞ RAPORU — CANLI',
                        style: TextStyle(
                          color: BattlePalette.mutedTitanium,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...logLines.asMap().entries.map(
                    (MapEntry<int, String> entry) => FadeSlideIn(
                      key: ValueKey<String>('log_${entry.key}'),
                      offsetY: 12,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '▸ ',
                              style: TextStyle(
                                color: theme.accentGlow,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: entry.key == logLines.length - 1
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
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
          ],
        ),
      ],
    );
  }
}

class _DuelPortrait extends StatelessWidget {
  const _DuelPortrait({
    required this.asset,
    required this.borderColor,
    required this.label,
    this.cover = false,
    this.bossDef,
    this.animationProgress = 0.0,
    this.isEnraged = false,
  });

  final String asset;
  final Color borderColor;
  final String label;
  final bool cover;
  final Aion2BossArtDefinition? bossDef;
  final double animationProgress;
  final bool isEnraged;

  @override
  Widget build(BuildContext context) {
    final Color effectiveBorder = isEnraged ? BattlePalette.coralFlare : borderColor;

    return Column(
      children: <Widget>[
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: BattlePalette.spaceNavy,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isEnraged
                    ? BattlePalette.mysticRuby.withValues(alpha: 0.75)
                    : (bossDef?.glowColor ?? borderColor).withValues(alpha: 0.38),
                blurRadius: isEnraged ? 28 : 20,
                spreadRadius: isEnraged ? 2 : 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (bossDef != null)
                  CustomPaint(
                    painter: Aion2AbyssalIllustrationPainter(
                      boss: bossDef!,
                      animationProgress: animationProgress,
                      intensity: isEnraged ? 1.0 : 0.85,
                    ),
                  )
                else
                  ColoredBox(color: BattlePalette.spaceNavy),

                Opacity(
                  opacity: bossDef != null ? 0.35 : 1.0,
                  child: Image.asset(
                    asset,
                    fit: cover ? BoxFit.cover : BoxFit.contain,
                    alignment: cover ? Alignment.center : Alignment.topCenter,
                    errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                        Image.asset(
                          'assets/images/portraits/bosses/boss_tiamat.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.shield_rounded, color: effectiveBorder, size: 40),
                        ),
                  ),
                ),

                CustomPaint(
                  painter: Aion2GoldFiligreePainter(
                    primaryGold: effectiveBorder,
                    deepGold: const Color(0xFFB8860B),
                    highlightGold: Colors.white,
                    cornerSize: 18,
                    showCrest: bossDef != null,
                    showGems: true,
                  ),
                ),

                if (isEnraged)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: BattlePalette.mysticRuby,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: BattlePalette.warningSolar, width: 0.8),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: BattlePalette.mysticRuby.withValues(alpha: 0.8),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Text(
                        '🔥 ÖFKE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: BattlePalette.carbonVoid.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: effectiveBorder.withValues(alpha: 0.4), width: 0.8),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: effectiveBorder,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Combat Juice: Impact Health Bar with Delayed Ghost Drain & Segmented Notches
// =============================================================================

class _ImpactHealthBar extends StatefulWidget {
  const _ImpactHealthBar({
    required this.currentHp,
    required this.maxHp,
    required this.gradientColors,
    required this.impactColor,
    required this.height,
    this.isEnraged = false,
  });

  final int currentHp;
  final int maxHp;
  final List<Color> gradientColors;
  final Color impactColor;
  final double height;
  final bool isEnraged;

  @override
  State<_ImpactHealthBar> createState() => _ImpactHealthBarState();
}

class _ImpactHealthBarState extends State<_ImpactHealthBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _drainController;
  late Animation<double> _drainAnimation;
  double _displayedGhostHp = 0.0;
  Timer? _drainDelayTimer;
  bool _isFlashing = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _displayedGhostHp = widget.currentHp.toDouble();
    _drainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _drainAnimation = Tween<double>(
      begin: _displayedGhostHp,
      end: _displayedGhostHp,
    ).animate(CurvedAnimation(
      parent: _drainController,
      curve: Curves.easeOutCubic,
    ))
      ..addListener(() {
        setState(() {
          _displayedGhostHp = _drainAnimation.value;
        });
      });
  }

  @override
  void didUpdateWidget(_ImpactHealthBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentHp < oldWidget.currentHp) {
      // Damage taken!
      _drainDelayTimer?.cancel();
      _drainController.stop();

      final double currentGhost = math.max(
        _displayedGhostHp,
        oldWidget.currentHp.toDouble(),
      );
      _displayedGhostHp = currentGhost;

      // Trigger impact border flash
      _isFlashing = true;
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 160), () {
        if (mounted) setState(() => _isFlashing = false);
      });

      // Micro delay for impact freeze, then smoothly drain ghost bar down
      _drainDelayTimer = Timer(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        _drainAnimation = Tween<double>(
          begin: _displayedGhostHp,
          end: widget.currentHp.toDouble(),
        ).animate(CurvedAnimation(
          parent: _drainController,
          curve: Curves.easeOutCubic,
        ));
        _drainController.forward(from: 0.0);
      });
    } else if (widget.currentHp > oldWidget.currentHp) {
      _displayedGhostHp = widget.currentHp.toDouble();
    }
  }

  @override
  void dispose() {
    _drainDelayTimer?.cancel();
    _flashTimer?.cancel();
    _drainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double safeMax = math.max(1.0, widget.maxHp.toDouble());
    final double currentPct = (widget.currentHp / safeMax).clamp(0.0, 1.0);
    final double ghostPct = (_displayedGhostHp / safeMax).clamp(0.0, 1.0);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: BattlePalette.carbonVoid,
        borderRadius: BorderRadius.circular(widget.height / 2),
        border: Border.all(
          color: widget.isEnraged
              ? BattlePalette.mysticRuby
              : (_isFlashing
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.15)),
          width: widget.isEnraged ? 1.5 : 1.0,
        ),
        boxShadow: widget.isEnraged
            ? <BoxShadow>[
                BoxShadow(
                  color: BattlePalette.mysticRuby.withValues(alpha: 0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.height / 2),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. Ghost / Impact Catchup Drain Bar
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ghostPct,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.impactColor,
                ),
              ),
            ),

            // 2. Foreground Current HP Bar
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: currentPct, end: currentPct),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutQuad,
              builder: (BuildContext context, double animatedPct, Widget? child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animatedPct,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.gradientColors,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: widget.gradientColors.last.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 3. Segmented Tick Divider Notches (every 10%)
            const CustomPaint(
              painter: _HealthBarNotchesPainter(segments: 10),
            ),

            // 4. Gloss specular reflection
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.height * 0.45,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 5. Damage Impact Flash Overlay
            if (_isFlashing)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HealthBarNotchesPainter extends CustomPainter {
  const _HealthBarNotchesPainter({required this.segments});
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments <= 1) return;
    final Paint linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    for (int i = 1; i < segments; i++) {
      final double x = size.width * (i / segments);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthBarNotchesPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

// =============================================================================
// Dual Combat Health HUD
// =============================================================================

class _DualCombatHealthHud extends StatelessWidget {
  const _DualCombatHealthHud({
    required this.playerName,
    required this.playerHp,
    required this.playerMaxHp,
    required this.bossName,
    required this.bossTitle,
    required this.bossHp,
    required this.bossMaxHp,
    required this.isBossEnraged,
    required this.theme,
  });

  final String playerName;
  final int playerHp;
  final int playerMaxHp;
  final String bossName;
  final String bossTitle;
  final int bossHp;
  final int bossMaxHp;
  final bool isBossEnraged;
  final CaveCardTheme theme;

  String _formatHp(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final double playerPct = ((playerHp / math.max(1, playerMaxHp)) * 100).clamp(0, 100);
    final double bossPct = ((bossHp / math.max(1, bossMaxHp)) * 100).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BattlePalette.spaceNavy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBossEnraged
              ? BattlePalette.mysticRuby.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: isBossEnraged
            ? <BoxShadow>[
                BoxShadow(
                  color: BattlePalette.mysticRuby.withValues(alpha: 0.3),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // PLAYER HEALTH SECTION
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BattlePalette.toxicNeon,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Text(
                          '${_formatHp(playerHp)} / ${_formatHp(playerMaxHp)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ImpactHealthBar(
                      currentHp: playerHp,
                      maxHp: playerMaxHp,
                      gradientColors: const <Color>[
                        Color(0xFF10B981),
                        Color(0xFF06B6D4),
                      ],
                      impactColor: const Color(0xFFFDE68A),
                      height: 12,
                    ),
                  ],
                ),
              ),

              // VS DIVIDER / ENRAGE SKULL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: isBossEnraged
                    ? const Icon(
                        Icons.local_fire_department_rounded,
                        color: BattlePalette.mysticRuby,
                        size: 20,
                      )
                    : Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: BattlePalette.carbonVoid,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
              ),

              // BOSS HEALTH SECTION
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '%${bossPct.round()}',
                          style: TextStyle(
                            color: isBossEnraged
                                ? BattlePalette.warningSolar
                                : Colors.white.withValues(alpha: 0.8),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            bossName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isBossEnraged
                                  ? BattlePalette.coralFlare
                                  : BattlePalette.mysticRuby,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ImpactHealthBar(
                      currentHp: bossHp,
                      maxHp: bossMaxHp,
                      gradientColors: isBossEnraged
                          ? const <Color>[
                              Color(0xFFDC2626),
                              Color(0xFFF59E0B),
                            ]
                          : const <Color>[
                              Color(0xFF991B1B),
                              Color(0xFFE11D48),
                            ],
                      impactColor: const Color(0xFFFED7AA),
                      height: 12,
                      isEnraged: isBossEnraged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isBossEnraged) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: BattlePalette.mysticRuby.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: BattlePalette.mysticRuby.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 11,
                    color: BattlePalette.warningSolar,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'ÖFKE MODU — CANAVAR SALDIRILARI %45 GÜÇLENDİ!',
                    style: TextStyle(
                      color: BattlePalette.warningSolar,
                      fontSize: 8.5,
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
    );
  }
}

// =============================================================================
// Boss Rage Announcement Banner
// =============================================================================

class _BossRageAnnouncementBanner extends StatelessWidget {
  const _BossRageAnnouncementBanner();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (BuildContext context, double t, Widget? child) {
        return Transform.scale(
          scale: 0.8 + 0.2 * t,
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFF7F1D1D),
              Color(0xFFE11D48),
              Color(0xFF7F1D1D),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: BattlePalette.warningSolar,
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: BattlePalette.mysticRuby.withValues(alpha: 0.8),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              '⚠️ ÖFKE PATLAMASI! ⚠️',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Hit-Stop Micro-Pause Specular Freeze-Frame Overlay
// =============================================================================

class _HitStopFreezeOverlay extends StatelessWidget {
  const _HitStopFreezeOverlay({
    required this.vfxController,
  });

  final DungeonCombatVfxController vfxController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vfxController.hitStopManager,
      builder: (BuildContext context, Widget? child) {
        final bool isPaused = vfxController.hitStopManager.getTimeScale() < 0.95 ||
            vfxController.hitStopManager.activeCount > 0;
        if (!isPaused) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 2.5,
                ),
                gradient: RadialGradient(
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.15),
                  ],
                  stops: const <double>[0.0, 0.7, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Boss Rage Perimeter Screen Vignette
// =============================================================================

class _BossRageScreenVignette extends StatelessWidget {
  const _BossRageScreenVignette({
    required this.ambient,
  });

  final AnimationController ambient;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ambient,
      builder: (BuildContext context, Widget? child) {
        final double pulse = 0.12 + 0.10 * math.sin(ambient.value * 2 * math.pi * 3).abs();
        return Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.95,
                  colors: <Color>[
                    Colors.transparent,
                    BattlePalette.mysticRuby.withValues(alpha: pulse * 0.4),
                    BattlePalette.mysticRuby.withValues(alpha: pulse),
                  ],
                  stops: const <double>[0.6, 0.85, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Ghost button — quiet secondary action.
// =============================================================================
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: BattlePalette.spaceNavy.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Result emblem — glowing icon medallion with shockwave entry.
// =============================================================================
class _ResultEmblem extends StatelessWidget {
  const _ResultEmblem({
    this.icon,
    this.artworkAsset,
    required this.colors,
    required this.glowColor,
    required this.ambient,
  });

  final IconData? icon;
  final String? artworkAsset;
  final List<Color> colors;
  final Color glowColor;
  final AnimationController ambient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // One-shot shockwave on entry.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOut,
            builder: (BuildContext context, double t, Widget? child) {
              return CustomPaint(
                size: const Size(150, 150),
                painter: ShockwavePainter(progress: t, color: glowColor),
              );
            },
          ),
          // Elastic pop-in + breathing glow.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (BuildContext context, double t, Widget? child) {
              return Transform.scale(scale: t, child: child);
            },
            child: AnimatedBuilder(
              animation: ambient,
              builder: (BuildContext context, Widget? child) {
                final double pulse =
                    0.35 + 0.3 * math.sin(ambient.value * 2 * math.pi).abs();
                return Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: glowColor.withValues(alpha: pulse),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: artworkAsset != null
                  ? Image.asset(
                      artworkAsset!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        icon ?? Icons.star_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    )
                  : Icon(icon ?? Icons.star_rounded, color: Colors.white, size: 44),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Reward tile — count-up number with icon (asset-free victory rewards).
// =============================================================================
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 16,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double v, Widget? child) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$prefix${v.round()}',
                    style: TextStyle(
                      color: color,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: BattlePalette.mutedTitanium,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Victory — rays + confetti + trophy emblem + count-up rewards. No PNG.
// =============================================================================
class _VictoryView extends StatelessWidget {
  const _VictoryView({
    required this.theme,
    required this.ambient,
    required this.result,
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final DungeonResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 244,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: ambient,
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      painter: RadiantRaysPainter(
                        progress: ambient.value,
                        color: BattlePalette.liquidGold,
                        maxOpacity: result.isCritical || result.isFirstClear
                            ? 0.26
                            : 0.16,
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: ambient,
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      painter:
                          ConfettiFieldPainter(progress: ambient.value),
                    );
                  },
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _ResultEmblem(
                    icon: Icons.emoji_events_rounded,
                    artworkAsset: 'assets/renders/environment/Chest_gold_beauty.png',
                    colors: const <Color>[
                      Color(0xFFFFD700),
                      Color(0xFFB8860B),
                    ],
                    glowColor: BattlePalette.liquidGold,
                    ambient: ambient,
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (BuildContext context, double t, Widget? child) {
                      return Transform.scale(scale: t, child: child);
                    },
                    child: Text(
                      'ZAFER!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 4,
                        shadows: <Shadow>[
                          Shadow(
                            color: BattlePalette.liquidGold
                                .withValues(alpha: 0.85),
                            blurRadius: 30,
                          ),
                          Shadow(
                            color: BattlePalette.coralFlare
                                .withValues(alpha: 0.4),
                            blurRadius: 60,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
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
          onTap: () => context.push(AppRoutes.codex),
        ),
        FadeSlideIn(
          delayMs: 200,
          child: GlassPanel(
            accent: BattlePalette.liquidGold,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'SAVAŞ GANİMETİ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BattlePalette.mutedTitanium,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 12),
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
                        color: const Color(0xFF3B82F6),
                      ),
                    ],
                  ],
                ),
                DungeonResultBalanceNotes(
                  rewardMultiplier: result.rewardMultiplier,
                  tutorialWrapperLootCount: result.tutorialWrapperLootCount,
                  siegeBonusApplied: result.siegeBonus?.shouldShowOnResult ?? false,
                  xpBreakdown: result.xpBreakdown,
                ),
              ],
            ),
          ),
        ),
        if (result.itemDetails.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          FadeSlideIn(
            delayMs: 350,
            child: DungeonItemRevealList(items: result.itemDetails),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Defeat — crimson rays + broken-heart emblem + notice panel. No PNG.
// =============================================================================
class _DefeatView extends StatelessWidget {
  const _DefeatView({
    required this.ambient,
    required this.hospitalized,
    required this.notices,
  });

  final AnimationController ambient;
  final bool hospitalized;
  final List<String> notices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 232,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: ambient,
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      painter: RadiantRaysPainter(
                        progress: ambient.value,
                        color: BattlePalette.mysticRuby,
                        maxOpacity: 0.1,
                        rayCount: 12,
                      ),
                    );
                  },
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _ResultEmblem(
                    icon: hospitalized
                        ? Icons.local_hospital_rounded
                        : Icons.heart_broken_rounded,
                    artworkAsset: 'assets/renders/weapons/DamagedHelmet_beauty.png',
                    colors: const <Color>[
                      Color(0xFFE52E2E),
                      Color(0xFF7F1D1D),
                    ],
                    glowColor: BattlePalette.mysticRuby,
                    ambient: ambient,
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (BuildContext context, double t, Widget? child) {
                      return Transform.scale(scale: t, child: child);
                    },
                    child: Text(
                      hospitalized ? 'DÜŞTÜN!' : 'YENİLDİN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 4,
                        shadows: <Shadow>[
                          Shadow(
                            color: BattlePalette.mysticRuby
                                .withValues(alpha: 0.9),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        FadeSlideIn(
          delayMs: 180,
          child: GlassPanel(
            accent: BattlePalette.mysticRuby,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < notices.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                    child: Text(
                      notices[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: i == 0
                            ? const Color(0xFFFCA5A5)
                            : Colors.white.withValues(alpha: 0.65),
                        fontSize: i == 0 ? 14 : 12,
                        fontWeight:
                            i == 0 ? FontWeight.w800 : FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
