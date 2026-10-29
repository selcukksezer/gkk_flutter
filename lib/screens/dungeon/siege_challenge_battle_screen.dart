import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/gold_format.dart';
import '../../core/utils/power_formula.dart';
import '../../models/dungeon_siege_model.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dungeon_siege_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'widgets/dungeon_battle_effects.dart';
import 'widgets/dungeon_cave_theme.dart';
import 'widgets/dungeon_cinematic_atmosphere.dart';
import '../../core/vfx/directional_camera_shake.dart';
import 'widgets/dungeon_combat_vfx.dart';
import 'widgets/dungeon_monster_glb_viewport.dart';
import 'package:gkk_flutter/components/common/app_messenger.dart';

/// Route extra for [SiegeChallengeBattleScreen].
class SiegeChallengeBattleArgs {
  const SiegeChallengeBattleArgs({
    required this.slotId,
    required this.dungeonId,
    required this.dungeonName,
    required this.zone,
    required this.slotNumber,
    required this.defenderName,
    required this.defenderPower,
    this.defenderGuildName,
    required this.challengeGoldCost,
  });

  final String slotId;
  final String dungeonId;
  final String dungeonName;
  final int zone;
  final int slotNumber;
  final String defenderName;
  final int defenderPower;
  final String? defenderGuildName;
  final int challengeGoldCost;
}

class SiegeChallengeBattleScreen extends ConsumerStatefulWidget {
  const SiegeChallengeBattleScreen({super.key, required this.args});

  final SiegeChallengeBattleArgs args;

  static Future<void> open(
    BuildContext context, {
    required SiegeChallengeBattleArgs args,
  }) {
    return context.push<void>(AppRoutes.siegeChallengeBattle, extra: args);
  }

  @override
  ConsumerState<SiegeChallengeBattleScreen> createState() =>
      _SiegeChallengeBattleScreenState();
}

class _SiegeChallengeBattleScreenState extends ConsumerState<SiegeChallengeBattleScreen>
    with TickerProviderStateMixin {
  String _phase = 'counting';
  DungeonSiegeActionResult? _result;
  Timer? _logTimer;
  int _logIndex = 0;
  final List<String> _battleLog = <String>[];
  int _battleGeneration = 0;

  // Combat Health, Multi-Phase Boss State & Enrage Countdown
  int _bossMaxHp = 10000;
  int _bossCurrentHp = 10000;
  int _playerMaxHp = 10000;
  int _playerCurrentHp = 10000;
  int _enrageTotalSeconds = 80;
  int _enrageSecondsRemaining = 80;
  String? _heavyAttackAlert;
  double _screenShakePulseIntensity = 0.0;
  int _lastTriggeredPhase = 1;

  late final AnimationController _ambient;
  late final DungeonAtmosphereController _atmosphereController;
  late final DungeonCombatVfxController _combatVfxController;
  DateTime _lastVfxTick = DateTime.now();

  /// 2027 Authentic Aion 2 Abyssal Siege Guardian & Boss 3D GLB Controller.
  late final DungeonMonsterGlbController _monsterController;

  SiegeChallengeBattleArgs get args => widget.args;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    _atmosphereController = DungeonAtmosphereController();
    _combatVfxController = DungeonCombatVfxController(
      atmosphereController: _atmosphereController,
    );
    _monsterController = DungeonMonsterGlbController();
    _ambient.addListener(_onVfxTick);

    _bossMaxHp = math.max(3800, args.defenderPower * 14);
    _bossCurrentHp = _bossMaxHp;
  }

  void _onVfxTick() {
    final DateTime now = DateTime.now();
    final double dt = (now.difference(_lastVfxTick).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
    _lastVfxTick = now;
    _combatVfxController.update(dt);

    if (_screenShakePulseIntensity > 0.0) {
      setState(() {
        _screenShakePulseIntensity = math.max(0.0, _screenShakePulseIntensity - dt * 2.8);
      });
    }
  }

  int get _bossCurrentPhase => _calculatePhase(_bossCurrentHp, _bossMaxHp);

  static int _calculatePhase(int current, int max) {
    if (max <= 0) return 1;
    final double ratio = (current / max).clamp(0.0, 1.0);
    if (ratio > 0.66) return 1;
    if (ratio > 0.33) return 2;
    return 3;
  }

  @override
  void dispose() {
    _invalidateBattle();
    _ambient.removeListener(_onVfxTick);
    _ambient.dispose();
    _atmosphereController.dispose();
    _combatVfxController.dispose();
    _monsterController.dispose();
    super.dispose();
  }

  void _triggerAtmosphericDecal(String line) {
    final String lower = line.toLowerCase();
    final bool isCritical = lower.contains('kritik') ||
        lower.contains('ezici') ||
        lower.contains('patlama') ||
        lower.contains('dalga');

    // Trigger 3D GLB boss combat flinch, rim hit-flash & trauma shake
    _monsterController.triggerHitReaction(isCritical: isCritical);

    if (isCritical) {
      _atmosphereController.triggerScorchMark();
    } else if (lower.contains('kan') || lower.contains('hasar') || lower.contains('darbe') || lower.contains('vuruş')) {
      _atmosphereController.triggerBloodSplatter();
    } else if (lower.contains('sarsıldı') || lower.contains('korudu') || lower.contains('çatladı') || lower.contains('arena')) {
      _atmosphereController.triggerCrackedFlagstones();
    } else {
      _atmosphereController.triggerSlashGouge();
    }
  }

  bool get _battleLocked => _phase == 'counting' || _phase == 'fighting';

  void _invalidateBattle() {
    _battleGeneration++;
    _logTimer?.cancel();
    _logTimer = null;
  }

  void _exitBattleWithError(String message) {
    _invalidateBattle();
    if (!mounted) return;
    AppMessenger.showError(context, message);
    if (!mounted) return;
    context.pop();
  }

  CaveCardTheme get _theme =>
      CaveCardTheme.forDungeonNumber(parseDungeonNumber(args.dungeonId)) ??
      CaveCardTheme.cyberCave;

  String get _characterAsset {
    final CharacterClass? cls = ref.read(playerProvider).profile?.characterClass;
    return switch (cls) {
      CharacterClass.shadow => 'assets/characters/golge.png',
      CharacterClass.alchemist => 'assets/characters/simyaci.png',
      _ => 'assets/characters/savasci.png',
    };
  }

  int _estimateAttack(int power) => math.max(10, (power * 0.52).round());

  int _estimateDefense(int power) => math.max(10, (power * 0.48).round());

  int _duelPower(int attack, int defense, CharacterClass? cls) {
    double power = (attack + defense).toDouble();
    if (cls == CharacterClass.shadow) power *= 1.15;
    return power.round();
  }

  int? _winChancePct(PlayerProfile? player) {
    if (player == null) return null;
    final int att = _duelPower(player.attack, player.defense, player.characterClass);
    final int def = _estimateAttack(args.defenderPower) + _estimateDefense(args.defenderPower);
    if (att + def <= 0) return null;
    return ((att / (att + def)) * 100).round().clamp(1, 99);
  }

  List<String> _combatFlavorLines() {
    final String name = args.defenderName;
    final List<String> pool = <String>[
      'Kuşatma kapıları aralandı — $name slot #${args.slotNumber} merkezinde!',
      'İlk hamle senden — kılıcın parıldadı, hücum başladı!',
      '$name kadim kalkanını kaldırıp ezici bir darbe savurdu!',
      'Abis enerjisi dalgalandı — arena boyunca şok dalgası yayıldı!',
      'Kritik vuruş! Kılıcın muhafızın runik zırhını parçaladı!',
      '$name öfkeyle kükredi — gazap alevleri etrafa saçıldı!',
      'Kılıçlar havada çarpıştı — şiddetli bir kıvılcım patlaması!',
      'Karşı saldırı geldi — muhafızın hançeri sana sıyırıp geçti!',
      'Kuşatma arenasında kader anı — son darbe hazırlanıyor!',
    ];
    pool.shuffle(math.Random());
    return pool.take(8).toList();
  }

  void _processCombatTick(String line) {
    _triggerAtmosphericDecal(line);
    final PlayerProfile? player = ref.read(playerProvider).profile;
    _combatVfxController.processCombatLine(
      line,
      playerAttack: player?.attack ?? 25,
      playerDefense: player?.defense ?? 25,
    );

    final String lower = line.toLowerCase();
    final bool isHeavyBoss = lower.contains('ezici') ||
        lower.contains('kükredi') ||
        lower.contains('öfkeyle') ||
        lower.contains('darbe') ||
        lower.contains('karşı saldırı') ||
        lower.contains('sarstı') ||
        lower.contains('alevleri');
    final bool isPlayerHit = lower.contains('kritik') ||
        lower.contains('saldırı') ||
        lower.contains('kılıcın') ||
        lower.contains('parçaladı') ||
        lower.contains('hücum') ||
        lower.contains('hamle');

    if (isHeavyBoss) {
      final int dmg = math.max(
        140,
        (_playerMaxHp * (0.11 + math.Random().nextDouble() * 0.08)).round(),
      );
      _playerCurrentHp = math.max(1, _playerCurrentHp - dmg);
      _screenShakePulseIntensity = 1.0;
      _combatVfxController.cameraShake.triggerPreset(
        CameraShakePreset.explosiveShock,
        hitDirection: const Offset(-1.0, 0.2),
        directionalWeight: 0.9,
      );
      _combatVfxController.triggerHaptic(HapticImpactLevel.heavy);
      setState(() {
        _heavyAttackAlert = '⚠️ MUHAFIZ AĞIR GAZAP DARBESİ!';
      });
    } else if (isPlayerHit) {
      final bool isCrit = lower.contains('kritik') || lower.contains('parçaladı');
      final double mult = isCrit ? 0.17 : 0.11;
      final int dmg = math.max(
        160,
        (_bossMaxHp * (mult + math.Random().nextDouble() * 0.06)).round(),
      );
      _bossCurrentHp = math.max(1, _bossCurrentHp - dmg);
      _monsterController.triggerHitReaction(isCritical: isCrit, intensity: isCrit ? 1.6 : 1.0);

      final int newPhase = _calculatePhase(_bossCurrentHp, _bossMaxHp);
      if (newPhase > _lastTriggeredPhase) {
        _lastTriggeredPhase = newPhase;
        _screenShakePulseIntensity = 1.0;
        _combatVfxController.cameraShake.triggerPreset(
          CameraShakePreset.explosiveShock,
          hitDirection: const Offset(0.0, 1.0),
        );
        _combatVfxController.triggerHaptic(HapticImpactLevel.critical);
        _atmosphereController.triggerScorchMark();
        setState(() {
          if (newPhase == 2) {
            _heavyAttackAlert = '⚡ FAZ GEÇİŞİ: ABİS GAZABI AKTİF!';
          } else if (newPhase == 3) {
            _heavyAttackAlert = '🔥 FAZ 3: KUDURAN DEREBEYİ GAZABI!';
          }
        });
      }
    }
  }

  Future<void> _startBattle() async {
    final int generation = ++_battleGeneration;
    const int minFightMs = 7000;
    final DateTime battleStart = DateTime.now();

    final DungeonSiegeStatus siegeStatus = ref.read(dungeonSiegeProvider).status;
    if (siegeStatus.hasSlotInDungeon(args.dungeonId)) {
      _exitBattleWithError('Zaten slot tutuyorsun; başka slota meydan okuyamazsın.');
      return;
    }

    final int playerGold = ref.read(playerProvider).profile?.gold ?? 0;
    if (playerGold < args.challengeGoldCost) {
      _exitBattleWithError(
        'Yetersiz altın. Gerekli: ${formatCompactGold(args.challengeGoldCost)} · '
        'Bakiye: ${formatCompactGold(playerGold)}',
      );
      return;
    }

    if (!mounted || generation != _battleGeneration) return;

    final PlayerProfile? profile = ref.read(playerProvider).profile;
    final int playerPower = profile?.power ?? 100;

    setState(() {
      _phase = 'fighting';
      _battleLog
        ..clear()
        ..add('Kuşatma meydan okuması başladı.')
        ..addAll(_combatFlavorLines());
      _logIndex = 0;
      _playerMaxHp = math.max(3800, playerPower * 14);
      _playerCurrentHp = _playerMaxHp;
      _bossMaxHp = math.max(3800, args.defenderPower * 14);
      _bossCurrentHp = _bossMaxHp;
      _enrageTotalSeconds = 80;
      _enrageSecondsRemaining = 80;
      _heavyAttackAlert = null;
      _screenShakePulseIntensity = 0.0;
      _lastTriggeredPhase = 1;
    });

    _logTimer = Timer.periodic(const Duration(milliseconds: 680), (Timer timer) {
      if (!mounted || generation != _battleGeneration) {
        timer.cancel();
        return;
      }
      if (_logIndex < _battleLog.length - 1) {
        setState(() {
          _logIndex++;
          _enrageSecondsRemaining = math.max(0, _enrageSecondsRemaining - 7);
        });
        if (_logIndex < _battleLog.length) {
          final String line = _battleLog[_logIndex];
          _processCombatTick(line);
        }
      }
    });

    try {
      final dynamic raw = await SupabaseService.client.rpc(
        'challenge_siege_slot',
        params: <String, dynamic>{'p_slot_id': args.slotId},
      );

      if (!mounted || generation != _battleGeneration) {
        _logTimer?.cancel();
        return;
      }

      if (raw is! Map) {
        throw StateError('Geçersiz sunucu cevabı');
      }

      final DungeonSiegeActionResult parsed =
          DungeonSiegeActionResult.fromJson(Map<String, dynamic>.from(raw));

      if (!parsed.success) {
        _exitBattleWithError(
          userFacingErrorMessage(parsed.error ?? 'Meydan okuma başarısız.'),
        );
        return;
      }

      final int elapsed = DateTime.now().difference(battleStart).inMilliseconds;
      if (elapsed < minFightMs) {
        await Future<void>.delayed(Duration(milliseconds: minFightMs - elapsed));
      }

      if (!mounted || generation != _battleGeneration) {
        _logTimer?.cancel();
        return;
      }

      await ref.read(playerProvider.notifier).loadProfile();
      await ref
          .read(dungeonSiegeProvider.notifier)
          .loadStatus(dungeonId: args.dungeonId, silent: true);

      if (!mounted || generation != _battleGeneration) {
        _logTimer?.cancel();
        return;
      }

      _logTimer?.cancel();
      final bool won = parsed.youWon == true;
      _battleLog.add(
        won
            ? 'Slot senin oldu! Muhafız yere serildi.'
            : 'Rakip slotu korudu — muhafız seni püskürttü...',
      );
      final player = ref.read(playerProvider).profile;
      if (won) {
        _bossCurrentHp = 0;
        _screenShakePulseIntensity = 1.0;
        _atmosphereController.triggerSlashGouge();
        _atmosphereController.triggerScorchMark();
        _combatVfxController.triggerFinishingBlow(
          isPlayerWinner: true,
          fatalDamage: ((player?.attack ?? 30) * 2.2).round(),
        );
        _monsterController.triggerHitReaction(isCritical: true, intensity: 2.2);
      } else {
        _playerCurrentHp = 0;
        _screenShakePulseIntensity = 1.0;
        _atmosphereController.triggerBloodSplatter();
        _combatVfxController.triggerFinishingBlow(
          isPlayerWinner: false,
          fatalDamage: (_estimateAttack(args.defenderPower) * 2.2).round(),
        );
      }

      setState(() {
        _result = parsed;
        _logIndex = _battleLog.length - 1;
        _phase = won ? 'success' : 'failure';
      });
    } catch (e) {
      _exitBattleWithError(
        userFacingErrorMessage(e, fallback: 'Meydan okuma başarısız.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayerProfile? profile = ref.watch(playerProvider).profile;
    final String playerName =
        ((profile?.displayName ?? profile?.username) ?? 'SEN').trim();
    final CaveCardTheme theme = _theme;

    return PopScope(
      canPop: !_battleLocked,
      child: Scaffold(
        backgroundColor: BattlePalette.carbonVoid,
        extendBody: true,
        bottomNavigationBar: GameBottomBar(
          currentRoute: AppRoutes.dungeon,
          onLogout: () async {
            await ref.read(authProvider.notifier).logout();
            ref.read(playerProvider.notifier).clear();
          },
          navigationLocked: _battleLocked,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _SiegeBattleBackdrop(
              theme: theme,
              ambient: _ambient,
              embers: _battleLocked,
              atmosphereController: _atmosphereController,
            ),
            if (_screenShakePulseIntensity > 0.01)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.95,
                        colors: <Color>[
                          Colors.transparent,
                          BattlePalette.mysticRuby.withValues(
                            alpha: (_screenShakePulseIntensity * 0.32).clamp(0.0, 0.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                        child: KeyedSubtree(
                          key: ValueKey<String>(_phase),
                          child: _buildPhase(theme, profile, playerName),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: <Widget>[
          PressableScale(
            onTap: _battleLocked
                ? () => AppMessenger.show(context, 'Düello bitene kadar çıkamazsın.')
                : () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BattlePalette.spaceNavy.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DungeonInsetText(
                  args.dungeonName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'BÖLGE ${args.zone} • KUŞATMA SLOT SAVAŞI',
                  style: TextStyle(
                    color: theme.accentGlow.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          BattleChip(
            icon: Icons.paid_rounded,
            label: 'ÜCRET',
            value: formatCompactGold(args.challengeGoldCost),
            color: BattlePalette.liquidGold,
          ),
        ],
      ),
    );
  }

  Widget _buildPhase(CaveCardTheme theme, PlayerProfile? profile, String playerName) {
    switch (_phase) {
      case 'counting':
        return _SiegeVsIntroView(
          theme: theme,
          playerAsset: _characterAsset,
          playerName: playerName.isEmpty ? 'SEN' : playerName,
          playerLevel: profile?.level ?? 1,
          playerPower: profile?.power ?? 0,
          playerAttack: profile?.attack ?? 0,
          playerDefense: profile?.defense ?? 0,
          opponentName: args.defenderName,
          opponentPower: args.defenderPower,
          opponentAttack: _estimateAttack(args.defenderPower),
          opponentDefense: _estimateDefense(args.defenderPower),
          opponentGuild: args.defenderGuildName,
          slotNumber: args.slotNumber,
          winChancePct: _winChancePct(profile),
          onComplete: _startBattle,
        );
      case 'fighting':
        return _SiegeFightingView(
          theme: theme,
          ambient: _ambient,
          playerAsset: _characterAsset,
          playerName: playerName.isEmpty ? 'SEN' : playerName,
          playerClass: profile?.characterClass,
          playerLevel: profile?.level ?? 1,
          playerCurrentHp: _playerCurrentHp,
          playerMaxHp: _playerMaxHp,
          opponentName: args.defenderName,
          opponentPower: args.defenderPower,
          bossCurrentHp: _bossCurrentHp,
          bossMaxHp: _bossMaxHp,
          bossCurrentPhase: _bossCurrentPhase,
          enrageSecondsRemaining: _enrageSecondsRemaining,
          enrageTotalSeconds: _enrageTotalSeconds,
          isEnraged: _enrageSecondsRemaining <= 0,
          heavyAttackAlert: _heavyAttackAlert,
          logLines: _battleLog.take(_logIndex + 1).toList(),
          vfxController: _combatVfxController,
          zone: args.zone,
          slotNumber: args.slotNumber,
          monsterController: _monsterController,
        );
      case 'success':
        return _buildSuccessPhase(theme);
      case 'failure':
        return _buildFailurePhase(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSuccessPhase(CaveCardTheme theme) {
    final DungeonSiegeActionResult? result = _result;
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SiegeVictoryView(
          ambient: _ambient,
          result: result,
          defenderName: args.defenderName,
          slotNumber: args.slotNumber,
          dungeonName: args.dungeonName,
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delayMs: 260,
          child: BattleCtaButton(
            label: 'KUŞATMA PANELİNE DÖN',
            icon: Icons.shield_rounded,
            onTap: () => context.pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildFailurePhase(CaveCardTheme theme) {
    final DungeonSiegeActionResult? result = _result;
    final int banMin = result?.banMinutes ?? 0;
    final List<String> notices = <String>[
      'Kaybettin',
      if (banMin > 0) '$banMin dk kuşatma banı aldın.',
      'Altın harcandı: ${formatCompactGold(result?.goldSpent ?? args.challengeGoldCost)}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SiegeDefeatView(
          ambient: _ambient,
          notices: notices,
          defenderName: args.defenderName,
          slotNumber: args.slotNumber,
          phasesReached: _lastTriggeredPhase,
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delayMs: 260,
          child: BattleCtaButton(
            label: 'KUŞATMA PANELİNE DÖN',
            icon: Icons.shield_rounded,
            colors: const <Color>[Color(0xFFE01E5A), Color(0xFF9F1239)],
            glowColor: BattlePalette.cyberFuchsia,
            foreground: Colors.white,
            onTap: () => context.pop(),
          ),
        ),
      ],
    );
  }
}

class _SiegeBattleBackdrop extends StatelessWidget {
  const _SiegeBattleBackdrop({
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
    final double h = MediaQuery.sizeOf(context).height;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DungeonCinematicAtmosphere(
          controller: atmosphereController,
          theme: theme,
          showTorches: true,
          showArena3D: true,
          showMist: true,
          showDecals: true,
          showDynamicShadows: true,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: h * 0.58,
          child: ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: <double>[0, 0.45, 0.75, 1],
              colors: <Color>[
                Color(0xB0FFFFFF),
                Color(0x80FFFFFF),
                Color(0x30FFFFFF),
                Color(0x00FFFFFF),
              ],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              theme.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  ColoredBox(color: theme.surfaceDeep.withValues(alpha: 0.5)),
            ),
          ),
        ),
        if (embers)
          AnimatedBuilder(
            animation: ambient,
            builder: (_, __) => CustomPaint(
              painter: EmberFieldPainter(
                progress: ambient.value,
                color: BattlePalette.cyberFuchsia,
              ),
            ),
          ),
        const CustomPaint(painter: DotPatternPainter()),
      ],
    );
  }
}

class _SiegeVsIntroView extends StatefulWidget {
  const _SiegeVsIntroView({
    required this.theme,
    required this.playerAsset,
    required this.playerName,
    required this.playerLevel,
    required this.playerPower,
    required this.playerAttack,
    required this.playerDefense,
    required this.opponentName,
    required this.opponentPower,
    required this.opponentAttack,
    required this.opponentDefense,
    this.opponentGuild,
    required this.slotNumber,
    required this.winChancePct,
    required this.onComplete,
  });

  final CaveCardTheme theme;
  final String playerAsset;
  final String playerName;
  final int playerLevel;
  final int playerPower;
  final int playerAttack;
  final int playerDefense;
  final String opponentName;
  final int opponentPower;
  final int opponentAttack;
  final int opponentDefense;
  final String? opponentGuild;
  final int slotNumber;
  final int? winChancePct;
  final VoidCallback onComplete;

  @override
  State<_SiegeVsIntroView> createState() => _SiegeVsIntroViewState();
}

class _SiegeVsIntroViewState extends State<_SiegeVsIntroView> with SingleTickerProviderStateMixin {
  static const int _kTotalMs = 7200;
  static const int _kSlamMs = 1100;
  static const int _kStatsInMs = 1100;
  static const int _kCountStartMs = 2400;
  static const int _kCountStepMs = 1000;
  static const int _kBurstStartMs = 5400;

  late final AnimationController _seq;
  int _lastNumber = 0;
  bool _completed = false;

  double _f(int ms) => ms / _kTotalMs;

  @override
  void initState() {
    super.initState();
    _seq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTotalMs),
    )
      ..addListener(_onTick)
      ..addStatusListener(_onSequenceStatus)
      ..forward();
  }

  void _onSequenceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completed || !mounted) return;
    _completed = true;
    widget.onComplete();
  }

  void _onTick() {
    final int? n = _numberAt(_seq.value);
    if (n != null && n != _lastNumber) {
      _lastNumber = n;
      HapticFeedback.mediumImpact();
    }
  }

  int? _numberAt(double v) {
    final double start = _f(_kCountStartMs);
    final double end = _f(_kBurstStartMs);
    if (v < start || v >= end) return null;
    return (3 - ((v - start) / _f(_kCountStepMs)).floor()).clamp(1, 3);
  }

  @override
  void dispose() {
    _seq.removeStatusListener(_onSequenceStatus);
    _seq.dispose();
    super.dispose();
  }

  Color _numberColor(int n) => switch (n) {
        3 => BattlePalette.warningSolar,
        2 => BattlePalette.coralFlare,
        _ => BattlePalette.mysticRuby,
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _seq,
      builder: (BuildContext context, Widget? child) {
        final double v = _seq.value;
        final double slamT =
            Curves.elasticOut.transform(((v * _kTotalMs) / _kSlamMs).clamp(0.0, 1.0));
        final double slideT =
            Curves.easeOutCubic.transform(((v * _kTotalMs) / _kSlamMs).clamp(0.0, 1.0));
        final double shockT = ((v - _f(300)) / (_f(1700) - _f(300))).clamp(0.0, 1.0);
        final double statsT =
            Curves.easeOutCubic.transform(((v - _f(_kStatsInMs)) / _f(900)).clamp(0.0, 1.0));
        final int? number = _numberAt(v);
        final bool inCountdown = number != null;
        final bool inBurst = v >= _f(_kBurstStartMs);
        final double burstT = ((v - _f(_kBurstStartMs)) / (1 - _f(_kBurstStartMs))).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Transform.translate(
                  offset: Offset(-300 * (1 - slideT), 0),
                  child: _SiegeDuelPortrait(
                    asset: widget.playerAsset,
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
                              colors: <Color>[
                                BattlePalette.cyberFuchsia,
                                BattlePalette.liquidGold,
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: BattlePalette.cyberFuchsia.withValues(alpha: 0.6),
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
                  child: _SiegeDuelPortrait(
                    name: widget.opponentName,
                    borderColor: BattlePalette.mysticRuby,
                    label: 'RAKİP',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: statsT,
              child: Transform.translate(
                offset: Offset(0, (1 - statsT) * 24),
                child: _SiegeStatPanel(
                  theme: widget.theme,
                  playerName: widget.playerName,
                  playerLevel: widget.playerLevel,
                  playerPower: widget.playerPower,
                  playerAttack: widget.playerAttack,
                  playerDefense: widget.playerDefense,
                  opponentName: widget.opponentName,
                  opponentPower: widget.opponentPower,
                  opponentAttack: widget.opponentAttack,
                  opponentDefense: widget.opponentDefense,
                  opponentGuild: widget.opponentGuild,
                  slotNumber: widget.slotNumber,
                  winChancePct: widget.winChancePct,
                  fillT: statsT,
                ),
              ),
            ),
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (inCountdown) ...<Widget>[
                    CustomPaint(
                      size: const Size(190, 190),
                      painter: CountdownRingPainter(
                        rotation: v * 2 * math.pi * 8,
                        color: _numberColor(number),
                      ),
                    ),
                    Text(
                      '$number',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 104,
                        fontWeight: FontWeight.w900,
                        shadows: <Shadow>[
                          Shadow(color: _numberColor(number).withValues(alpha: 0.85), blurRadius: 34),
                        ],
                      ),
                    ),
                  ],
                  if (inBurst)
                    Transform.scale(
                      scale: Curves.elasticOut.transform((burstT * 2.2).clamp(0.0, 1.0)),
                      child: const Text(
                        'SAVAŞ!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 58,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SiegeStatPanel extends StatelessWidget {
  const _SiegeStatPanel({
    required this.theme,
    required this.playerName,
    required this.playerLevel,
    required this.playerPower,
    required this.playerAttack,
    required this.playerDefense,
    required this.opponentName,
    required this.opponentPower,
    required this.opponentAttack,
    required this.opponentDefense,
    this.opponentGuild,
    required this.slotNumber,
    required this.winChancePct,
    required this.fillT,
  });

  final CaveCardTheme theme;
  final String playerName;
  final int playerLevel;
  final int playerPower;
  final int playerAttack;
  final int playerDefense;
  final String opponentName;
  final int opponentPower;
  final int opponentAttack;
  final int opponentDefense;
  final String? opponentGuild;
  final int slotNumber;
  final int? winChancePct;
  final double fillT;

  @override
  Widget build(BuildContext context) {
    final Color chanceColor = winChancePct != null
        ? theme.threatForSuccess(winChancePct!)
        : BattlePalette.mutedTitanium;

    return GlassPanel(
      accent: theme.accent,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _SiegeStatSide(
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
                child: _SiegeStatSide(
                  title: opponentName,
                  titleColor: BattlePalette.mysticRuby,
                  bigLabel: 'GÜÇ',
                  bigValue: '$opponentPower',
                  bigColor: BattlePalette.cyberFuchsia,
                  chips: <Widget>[
                    BattleChip(
                      icon: Icons.grid_view_rounded,
                      label: 'SLOT',
                      value: '#$slotNumber',
                      color: BattlePalette.cyberFuchsia,
                    ),
                    BattleChip(
                      icon: Icons.gps_fixed_rounded,
                      label: 'ATK',
                      value: '$opponentAttack',
                      color: BattlePalette.coralFlare,
                    ),
                    BattleChip(
                      icon: Icons.shield_rounded,
                      label: 'DEF',
                      value: '$opponentDefense',
                      color: theme.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (opponentGuild != null && opponentGuild!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              opponentGuild!,
              style: TextStyle(
                color: BattlePalette.mutedTitanium.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (winChancePct != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'KAZANMA ŞANSI',
                  style: TextStyle(
                    color: BattlePalette.mutedTitanium,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '%$winChancePct',
                  style: TextStyle(color: chanceColor, fontSize: 13, fontWeight: FontWeight.w900),
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
                      widthFactor: ((winChancePct! / 100) * fillT).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[chanceColor.withValues(alpha: 0.7), chanceColor],
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

class _SiegeStatSide extends StatelessWidget {
  const _SiegeStatSide({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          bigLabel,
          style: const TextStyle(
            color: BattlePalette.mutedTitanium,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          bigValue,
          style: TextStyle(color: bigColor, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }
}

class _SiegeDuelPortrait extends StatelessWidget {
  const _SiegeDuelPortrait({
    this.asset,
    this.name,
    required this.borderColor,
    required this.label,
  });

  final String? asset;
  final String? name;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BattlePalette.spaceNavy,
            border: Border.all(color: borderColor.withValues(alpha: 0.8), width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(color: borderColor.withValues(alpha: 0.35), blurRadius: 20),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: asset != null
              ? Image.asset(
                  asset!,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.person_rounded, color: borderColor, size: 40),
                )
              : Center(
                  child: Text(
                    (name ?? '?').isNotEmpty ? name!.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(
                      color: borderColor,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: borderColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _BossMultiPhaseHealthGauge extends StatelessWidget {
  const _BossMultiPhaseHealthGauge({
    required this.bossName,
    required this.slotNumber,
    required this.currentHp,
    required this.maxHp,
    required this.currentPhase,
    required this.enrageSecondsRemaining,
    required this.enrageTotalSeconds,
    this.heavyAttackAlert,
    required this.theme,
  });

  final String bossName;
  final int slotNumber;
  final int currentHp;
  final int maxHp;
  final int currentPhase;
  final int enrageSecondsRemaining;
  final int enrageTotalSeconds;
  final String? heavyAttackAlert;
  final CaveCardTheme theme;

  @override
  Widget build(BuildContext context) {
    final double totalRatio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final int mins = enrageSecondsRemaining ~/ 60;
    final int secs = enrageSecondsRemaining % 60;
    final String timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final bool isEnraged = enrageSecondsRemaining <= 0;
    final bool isCriticalEnrage = enrageSecondsRemaining <= 25;

    final String phaseTitle = switch (currentPhase) {
      1 => 'KADİM SAVUNMA',
      2 => 'ABİS GAZABI',
      _ => 'KUDURAN DEREBEYİ',
    };

    final Color phaseColor = switch (currentPhase) {
      1 => const Color(0xFF38BDF8),
      2 => const Color(0xFFA855F7),
      _ => const Color(0xFFEF4444),
    };

    final List<Color> phaseGradient = switch (currentPhase) {
      1 => const <Color>[Color(0xFF0284C7), Color(0xFF38BDF8)],
      2 => const <Color>[Color(0xFF7E22CE), Color(0xFFC084FC)],
      _ => const <Color>[Color(0xFFB91C1C), Color(0xFFF97316)],
    };

    final double phaseRatio = switch (currentPhase) {
      1 => ((totalRatio - 0.66) / 0.34).clamp(0.0, 1.0),
      2 => ((totalRatio - 0.33) / 0.33).clamp(0.0, 1.0),
      _ => (totalRatio / 0.33).clamp(0.0, 1.0),
    };

    return GlassPanel(
      accent: isEnraged ? BattlePalette.mysticRuby : phaseColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: phaseColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: phaseColor.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            'SLOT #$slotNumber',
                            style: TextStyle(
                              color: phaseColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bossName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'KUŞATMA MUHAFIZI & SAVUNAN ŞAMPİYON',
                      style: TextStyle(
                        color: BattlePalette.mutedTitanium.withValues(alpha: 0.85),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isCriticalEnrage
                      ? BattlePalette.mysticRuby.withValues(alpha: 0.3)
                      : BattlePalette.spaceNavy.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCriticalEnrage
                        ? BattlePalette.mysticRuby
                        : BattlePalette.warningSolar.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: isCriticalEnrage
                      ? <BoxShadow>[
                          BoxShadow(
                            color: BattlePalette.mysticRuby.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isEnraged
                          ? Icons.local_fire_department_rounded
                          : (isCriticalEnrage
                              ? Icons.warning_amber_rounded
                              : Icons.timer_outlined),
                      size: 14,
                      color: isCriticalEnrage
                          ? BattlePalette.coralFlare
                          : BattlePalette.warningSolar,
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          isEnraged ? 'KUDURMA!' : 'GAZAP: $timeStr',
                          style: TextStyle(
                            color: isCriticalEnrage
                                ? const Color(0xFFFCA5A5)
                                : BattlePalette.warningSolar,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        SizedBox(
                          width: 48,
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: enrageTotalSeconds > 0
                                  ? (enrageSecondsRemaining / enrageTotalSeconds)
                                      .clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCriticalEnrage
                                    ? BattlePalette.mysticRuby
                                    : BattlePalette.liquidGold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'FAZ $currentPhase / 3',
                    style: TextStyle(
                      color: phaseColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '• $phaseTitle',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  for (int p = 1; p <= 3; p++)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: p == currentPhase
                              ? phaseColor
                              : (p < currentPhase
                                  ? phaseColor.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.1)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: p == currentPhase
                                ? Colors.white
                                : phaseColor.withValues(alpha: 0.4),
                            width: p == currentPhase ? 1.5 : 0.8,
                          ),
                          boxShadow: p == currentPhase
                              ? <BoxShadow>[
                                  BoxShadow(
                                    color: phaseColor.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$p',
                            style: TextStyle(
                              color: p == currentPhase ? Colors.black : Colors.white70,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: <Widget>[
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: phaseRatio, end: phaseRatio),
                builder: (BuildContext context, double lagVal, Widget? child) {
                  return FractionallySizedBox(
                    widthFactor: lagVal.clamp(0.0, 1.0),
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: BattlePalette.liquidGold.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
              FractionallySizedBox(
                widthFactor: phaseRatio.clamp(0.0, 1.0),
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: phaseGradient),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: phaseColor.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: <Widget>[
                    const Spacer(flex: 33),
                    Container(width: 1.5, color: Colors.black.withValues(alpha: 0.7)),
                    const Spacer(flex: 33),
                    Container(width: 1.5, color: Colors.black.withValues(alpha: 0.7)),
                    const Spacer(flex: 34),
                  ],
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '${formatCompactGold(currentHp)} / ${formatCompactGold(maxHp)} HP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                      Text(
                        '%${(totalRatio * 100).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (heavyAttackAlert != null) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF881337), Color(0xFF4C0519)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BattlePalette.mysticRuby, width: 1.2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: BattlePalette.mysticRuby.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.flash_on_rounded, size: 14, color: BattlePalette.liquidGold),
                  const SizedBox(width: 6),
                  Text(
                    heavyAttackAlert!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
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

class _PlayerCombatHealthBar extends StatelessWidget {
  const _PlayerCombatHealthBar({
    required this.playerAsset,
    required this.playerName,
    this.playerClass,
    required this.playerLevel,
    required this.currentHp,
    required this.maxHp,
  });

  final String playerAsset;
  final String playerName;
  final CharacterClass? playerClass;
  final int playerLevel;
  final int currentHp;
  final int maxHp;

  @override
  Widget build(BuildContext context) {
    final double ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BattlePalette.spaceNavy.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: BattlePalette.toxicNeon.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: BattlePalette.toxicNeon, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  playerAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person, size: 16, color: BattlePalette.toxicNeon),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Text(
                      playerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: BattlePalette.toxicNeon.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LV $playerLevel',
                        style: const TextStyle(
                          color: BattlePalette.toxicNeon,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatCompactGold(currentHp)} / ${formatCompactGold(maxHp)} HP',
                style: const TextStyle(
                  color: BattlePalette.toxicNeon,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: <Widget>[
                  Container(color: Colors.white.withValues(alpha: 0.08)),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: ratio, end: ratio),
                    builder: (BuildContext context, double lagVal, Widget? child) {
                      return FractionallySizedBox(
                        widthFactor: lagVal.clamp(0.0, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[Color(0xFF059669), BattlePalette.toxicNeon],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiegeFightingView extends StatelessWidget {
  const _SiegeFightingView({
    required this.theme,
    required this.ambient,
    required this.playerAsset,
    required this.playerName,
    this.playerClass,
    required this.playerLevel,
    required this.playerCurrentHp,
    required this.playerMaxHp,
    required this.opponentName,
    required this.opponentPower,
    required this.bossCurrentHp,
    required this.bossMaxHp,
    required this.bossCurrentPhase,
    required this.enrageSecondsRemaining,
    required this.enrageTotalSeconds,
    required this.isEnraged,
    this.heavyAttackAlert,
    required this.logLines,
    required this.vfxController,
    required this.zone,
    required this.slotNumber,
    required this.monsterController,
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final String playerAsset;
  final String playerName;
  final CharacterClass? playerClass;
  final int playerLevel;
  final int playerCurrentHp;
  final int playerMaxHp;
  final String opponentName;
  final int opponentPower;
  final int bossCurrentHp;
  final int bossMaxHp;
  final int bossCurrentPhase;
  final int enrageSecondsRemaining;
  final int enrageTotalSeconds;
  final bool isEnraged;
  final String? heavyAttackAlert;
  final List<String> logLines;
  final DungeonCombatVfxController vfxController;
  final int zone;
  final int slotNumber;
  final DungeonMonsterGlbController monsterController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 1. Multi-Phase Boss Health Gauge & Enrage Countdown HUD
        _BossMultiPhaseHealthGauge(
          bossName: opponentName,
          slotNumber: slotNumber,
          currentHp: bossCurrentHp,
          maxHp: bossMaxHp,
          currentPhase: bossCurrentPhase,
          enrageSecondsRemaining: enrageSecondsRemaining,
          enrageTotalSeconds: enrageTotalSeconds,
          heavyAttackAlert: heavyAttackAlert,
          theme: theme,
        ),
        const SizedBox(height: 12),

        // 2. 3D GLB Abyssal Boss Viewport (Summoning Pedestal + 360 Turntable + Hit Reactions)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: BattlePalette.carbonVoid.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.accent.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: DungeonMonsterGlbViewport(
              zone: zone,
              isSiege: true,
              isBossFloor: true,
              controller: monsterController,
              height: 200,
              showBadge: true,
              showPedestal: true,
              interactive: true,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Player Combat Health Bar
        _PlayerCombatHealthBar(
          playerAsset: playerAsset,
          playerName: playerName,
          playerClass: playerClass,
          playerLevel: playerLevel,
          currentHp: playerCurrentHp,
          maxHp: playerMaxHp,
        ),
        const SizedBox(height: 14),

        // 4. Combat VFX Arena Host (Directional camera shake host, knockback, ribbons, GPU sparks, bouncy numbers)
        FadeSlideIn(
          child: DungeonCombatVfxArenaHost(
            controller: vfxController,
            playerPortrait: _SiegeDuelPortrait(
              asset: playerAsset,
              borderColor: BattlePalette.toxicNeon,
              label: 'SEN',
            ),
            enemyPortrait: _SiegeDuelPortrait(
              name: opponentName,
              borderColor: BattlePalette.mysticRuby,
              label: 'MUHAFIZ',
            ),
            clashIcon: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[BattlePalette.cyberFuchsia, BattlePalette.liquidGold],
                ),
              ),
              child: const Center(
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 5. Energy Sweep Bar
        FadeSlideIn(
          delayMs: 150,
          child: AnimatedBuilder(
            animation: ambient,
            builder: (_, __) => EnergySweepBar(progress: (ambient.value * 3) % 1.0),
          ),
        ),
        const SizedBox(height: 14),

        // 6. Live Duel Log Panel
        GlassPanel(
          accent: theme.accent,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.stream_rounded, size: 14, color: theme.accent),
                  const SizedBox(width: 6),
                  Text(
                    'CANLI KUŞATMA DÜELLOSU',
                    style: TextStyle(
                      color: BattlePalette.mutedTitanium,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final String line in logLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '› ',
                        style: TextStyle(
                          color: line.contains('ezici') || line.contains('öfkeyle')
                              ? BattlePalette.mysticRuby
                              : (line.contains('kritik') || line.contains('parçaladı')
                                  ? BattlePalette.liquidGold
                                  : theme.accent),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: line.contains('kritik') || line.contains('ezici')
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SiegeVictoryView extends StatelessWidget {
  const _SiegeVictoryView({
    required this.ambient,
    required this.result,
    required this.defenderName,
    required this.slotNumber,
    this.dungeonName,
  });

  final AnimationController ambient;
  final DungeonSiegeActionResult result;
  final String defenderName;
  final int slotNumber;
  final String? dungeonName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedBuilder(
                animation: ambient,
                builder: (_, __) => CustomPaint(
                  size: Size.infinite,
                  painter: RadiantRaysPainter(
                    progress: ambient.value,
                    color: BattlePalette.liquidGold,
                    maxOpacity: 0.24,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: ambient,
                builder: (_, __) => CustomPaint(
                  size: Size.infinite,
                  painter: ConfettiFieldPainter(progress: ambient.value),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: <Color>[Color(0xFFFFE082), BattlePalette.liquidGold],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: BattlePalette.liquidGold.withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.black87, size: 44),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'KUŞATMA ZAFERİ!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SLOT #$slotNumber KONTROLÜ SENİN OLDU',
                    style: TextStyle(
                      color: BattlePalette.liquidGold.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        FadeSlideIn(
          delayMs: 180,
          child: GlassPanel(
            accent: BattlePalette.liquidGold,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  result.message ?? '$defenderName mağlup edildi, slot #$slotNumber feth edildi!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                if (result.holdBroken == true) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: BattlePalette.toxicNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BattlePalette.toxicNeon, width: 1),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.shield_outlined, size: 16, color: BattlePalette.toxicNeon),
                        SizedBox(width: 6),
                        Text(
                          '⚡ LONCA HOLD SAVUNMASI KIRILDI!',
                          style: TextStyle(
                            color: BattlePalette.toxicNeon,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else if (result.holdBreakProgress != null) ...<Widget>[
                  Text(
                    'Lonca Savunması Kırılma İlerlemesi: ${result.holdBreakProgress}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BattlePalette.toxicNeon,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _buildRewardBadge(
                      icon: Icons.paid_rounded,
                      label: 'HARCANAN',
                      value: formatCompactGold(result.goldSpent ?? 0),
                      color: BattlePalette.liquidGold,
                    ),
                    _buildRewardBadge(
                      icon: Icons.shield_rounded,
                      label: 'FETHEDİLEN',
                      value: 'SLOT #$slotNumber',
                      color: BattlePalette.toxicNeon,
                    ),
                    _buildRewardBadge(
                      icon: Icons.military_tech_rounded,
                      label: 'UNVAN',
                      value: 'KALE SAHİBİ',
                      color: const Color(0xFF38BDF8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildRewardBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: BattlePalette.mutedTitanium,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SiegeDefeatView extends StatelessWidget {
  const _SiegeDefeatView({
    required this.ambient,
    required this.notices,
    this.defenderName,
    this.slotNumber,
    this.phasesReached = 1,
  });

  final AnimationController ambient;
  final List<String> notices;
  final String? defenderName;
  final int? slotNumber;
  final int phasesReached;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedBuilder(
                animation: ambient,
                builder: (_, __) => CustomPaint(
                  size: Size.infinite,
                  painter: RadiantRaysPainter(
                    progress: ambient.value,
                    color: BattlePalette.mysticRuby,
                    maxOpacity: 0.15,
                    rayCount: 12,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BattlePalette.spaceNavy,
                      border: Border.all(color: BattlePalette.mysticRuby, width: 2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: BattlePalette.mysticRuby.withValues(alpha: 0.5),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.heart_broken_rounded,
                      color: BattlePalette.mysticRuby,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SAVUNMA AŞILAMADI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'KUŞATMA MUHAFIZI SLOTU KORUDU',
                    style: TextStyle(
                      color: BattlePalette.mysticRuby.withValues(alpha: 0.85),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        FadeSlideIn(
          delayMs: 180,
          child: GlassPanel(
            accent: BattlePalette.mysticRuby,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            : Colors.white.withValues(alpha: 0.75),
                        fontSize: i == 0 ? 14 : 12,
                        fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.tips_and_updates_rounded,
                          size: 16, color: BattlePalette.warningSolar),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'İpucu: Muhafızı Faz $phasesReached\'e kadar gerilettin. Karakterini güçlendirip tekrar dene.',
                          style: const TextStyle(
                            color: BattlePalette.mutedTitanium,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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
      ],
    );
  }
}
