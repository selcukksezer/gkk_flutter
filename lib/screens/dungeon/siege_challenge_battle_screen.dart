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
import 'dungeon_battle_profiles.dart';
import 'widgets/dungeon_battle_effects.dart';
import 'widgets/dungeon_cave_theme.dart';
import 'widgets/dungeon_stage_combat_view.dart';
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

  late final AnimationController _ambient;

  SiegeChallengeBattleArgs get args => widget.args;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _invalidateBattle();
    _ambient.dispose();
    super.dispose();
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
      CharacterClass.shadow => 'assets/dungeon/hero_battle_shadow.png',
      CharacterClass.alchemist => 'assets/dungeon/hero_battle_alchemist.png',
      _ => 'assets/dungeon/hero_battle_warrior.png',
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
      '$name slot #${args.slotNumber} savunuyor...',
      'Kuşatma arenasında karşılaştınız!',
      'İlk hamle senden — saldırı başladı!',
      '$name geri adım attı, karşı vuruş geldi!',
      'Slot kontrolü için son hamle!',
      'Güç dalgası arena boyunca yayıldı...',
      'Kritik an — kader slotu belirleyecek!',
    ];
    pool.shuffle(math.Random());
    return pool.take(7).toList();
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

    setState(() {
      _phase = 'fighting';
      _battleLog
        ..clear()
        ..add('Kuşatma meydan okuması başladı.')
        ..addAll(_combatFlavorLines());
      _logIndex = 0;
    });

    _logTimer = Timer.periodic(const Duration(milliseconds: 650), (Timer timer) {
      if (!mounted || generation != _battleGeneration) {
        timer.cancel();
        return;
      }
      if (_logIndex < _battleLog.length - 1) {
        setState(() => _logIndex++);
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
      _battleLog.add(won ? 'Slot senin oldu!' : 'Rakip slotu korudu...');

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
            _SiegeBattleBackdrop(theme: theme, ambient: _ambient, embers: _battleLocked),
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
          dungeonId: args.dungeonId,
          zone: args.zone,
          slotNumber: args.slotNumber,
          playerAsset: _characterAsset,
          characterClass: profile?.characterClass,
          playerName: playerName.isEmpty ? 'SEN' : playerName,
          playerLevel: profile?.level ?? 1,
          playerPower: profile?.power ?? 0,
          opponentName: args.defenderName,
          opponentPower: args.defenderPower,
          logLines: _battleLog.take(_logIndex + 1).toList(),
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
        _SiegeDefeatView(ambient: _ambient, notices: notices),
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
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final bool embers;

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.sizeOf(context).height;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: BattlePalette.carbonVoid),
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
              errorBuilder: (_, _, _) => ColoredBox(color: theme.surfaceDeep),
            ),
          ),
        ),
        if (embers)
          AnimatedBuilder(
            animation: ambient,
            builder: (_, _) => CustomPaint(
              painter: EmberFieldPainter(
                progress: ambient.value,
                color: BattlePalette.cyberFuchsia,
              ),
            ),
          ),
        CustomPaint(painter: const DotPatternPainter()),
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
                  errorBuilder: (_, _, _) =>
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

class _SiegeFightingView extends StatefulWidget {
  const _SiegeFightingView({
    required this.theme,
    required this.ambient,
    required this.dungeonId,
    required this.zone,
    required this.slotNumber,
    required this.playerAsset,
    required this.characterClass,
    required this.playerName,
    required this.playerLevel,
    required this.playerPower,
    required this.opponentName,
    required this.opponentPower,
    required this.logLines,
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final String dungeonId;
  final int zone;
  final int slotNumber;
  final String playerAsset;
  final CharacterClass? characterClass;
  final String playerName;
  final int playerLevel;
  final int playerPower;
  final String opponentName;
  final int opponentPower;
  final List<String> logLines;

  @override
  State<_SiegeFightingView> createState() => _SiegeFightingViewState();
}

class _SiegeFightingViewState extends State<_SiegeFightingView> {
  DungeonTacticalCommand? _tacticalCommand;
  int _seq = 0;
  int _combo = 0;

  void _onArenaTap(bool isSweetSpot) {
    if (isSweetSpot) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _combo += isSweetSpot ? 2 : 1;
      _tacticalCommand = DungeonTacticalCommand(
        seq: ++_seq,
        type: isSweetSpot
            ? DungeonTacticalActionType.perfectCrit
            : DungeonTacticalActionType.quickSlash,
        skillTitle: isSweetSpot ? '⚡ KUŞATMA KRİTİĞİ' : '⚔️ KUŞATMA DARBESİ',
        damageMultiplier: isSweetSpot ? 1.88 : 1.16,
        isCritical: isSweetSpot,
        aoeAllMobs: isSweetSpot,
        comboStreak: _combo,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final DungeonBattleProfile battleProfile =
        DungeonBattleProfile.forDungeonId(
      widget.dungeonId,
      fallbackZone: widget.zone,
    );
    final ({String grade, Color color}) rank = resolveDungeonStyleRank(_combo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FadeSlideIn(
          child: DungeonStageCombatView(
            profile: battleProfile,
            stagePhase: DungeonStagePhase.fighting,
            ambient: widget.ambient,
            characterAsset: widget.playerAsset,
            characterClass: widget.characterClass,
            playerName: widget.playerName,
            playerLevel: widget.playerLevel,
            playerPower: widget.playerPower,
            powerRequirement: widget.opponentPower,
            height: 286,
            tacticalCommand: _tacticalCommand,
            onArenaStrikeTap: _onArenaTap,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                '⚔️ SLOT #${widget.slotNumber} • RAKİP: ${widget.opponentName.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFDE68A),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            if (_combo >= 1)
              Text(
                '🔥 STİL ${rank.grade} • x$_combo',
                style: TextStyle(
                  color: rank.color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delayMs: 150,
          child: AnimatedBuilder(
            animation: widget.ambient,
            builder: (_, _) =>
                EnergySweepBar(progress: (widget.ambient.value * 3) % 1.0),
          ),
        ),
        const SizedBox(height: 14),
        GlassPanel(
          accent: widget.theme.accent,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'CANLI KUŞATMA DÜELLOSU',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BattlePalette.mutedTitanium,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 12),
              for (final String line in widget.logLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '› $line',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      height: 1.35,
                    ),
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
  });

  final AnimationController ambient;
  final DungeonSiegeActionResult result;
  final String defenderName;
  final int slotNumber;

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
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: RadiantRaysPainter(
                    progress: ambient.value,
                    color: BattlePalette.liquidGold,
                    maxOpacity: 0.22,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: ambient,
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: ConfettiFieldPainter(progress: ambient.value),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.emoji_events_rounded, color: BattlePalette.liquidGold, size: 72),
                  const SizedBox(height: 8),
                  const Text(
                    'ZAFER!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 4,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Text(
                  result.message ?? '$defenderName slot #$slotNumber sende!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                if (result.holdBroken == true) ...<Widget>[
                  const SizedBox(height: 8),
                  const Text(
                    'Lonca hold kırıldı!',
                    style: TextStyle(color: BattlePalette.toxicNeon, fontWeight: FontWeight.w800),
                  ),
                ] else if (result.holdBreakProgress != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Hold kırılma: ${result.holdBreakProgress}',
                    style: const TextStyle(color: BattlePalette.toxicNeon, fontWeight: FontWeight.w700),
                  ),
                ],
                if (result.goldSpent != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Harcanan altın: ${formatCompactGold(result.goldSpent!)}',
                    style: TextStyle(color: BattlePalette.mutedTitanium.withValues(alpha: 0.9)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SiegeDefeatView extends StatelessWidget {
  const _SiegeDefeatView({required this.ambient, required this.notices});

  final AnimationController ambient;
  final List<String> notices;

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
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: RadiantRaysPainter(
                    progress: ambient.value,
                    color: BattlePalette.mysticRuby,
                    maxOpacity: 0.12,
                    rayCount: 12,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.heart_broken_rounded, color: BattlePalette.mysticRuby, size: 72),
                  const SizedBox(height: 8),
                  const Text(
                    'YENİLDİN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 4,
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
                        color: i == 0 ? const Color(0xFFFCA5A5) : Colors.white.withValues(alpha: 0.65),
                        fontSize: i == 0 ? 14 : 12,
                        fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
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
