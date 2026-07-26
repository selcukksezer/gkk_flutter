import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/utils/captcha_guard.dart';
import '../../core/utils/gold_format.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mekan_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../dungeon/widgets/dungeon_battle_effects.dart';
import '../reputation/widgets/reputation_gain_banner.dart';
import 'widgets/mekan_design.dart' hide PressableScale;

/// Args for [MekanArenaBattleScreen].
class MekanArenaBattleArgs {
  const MekanArenaBattleArgs({
    required this.mekanId,
    required this.opponent,
    required this.wager,
  });

  final String mekanId;
  final ArenaOpponent opponent;
  final int wager;
}

/// Bahisli arena — zindan gibi VS + canlı dövüş + sonuç.
class MekanArenaBattleScreen extends ConsumerStatefulWidget {
  const MekanArenaBattleScreen({super.key, required this.args});

  final MekanArenaBattleArgs args;

  static Future<bool?> open(
    BuildContext context, {
    required MekanArenaBattleArgs args,
  }) {
    return context.push<bool>(AppRoutes.mekanArenaBattle, extra: args);
  }

  @override
  ConsumerState<MekanArenaBattleScreen> createState() =>
      _MekanArenaBattleScreenState();
}

class _MekanArenaBattleScreenState extends ConsumerState<MekanArenaBattleScreen>
    with TickerProviderStateMixin {
  static const int _energyCost = 15;
  static const int _minFightMs = 7000;

  String _phase = 'counting';
  Map<String, dynamic>? _result;
  Timer? _logTimer;
  int _logIndex = 0;
  final List<String> _battleLog = <String>[];
  int _battleGeneration = 0;

  late final AnimationController _ambient;

  MekanArenaBattleArgs get args => widget.args;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
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

  void _exitWithError(String message) {
    _invalidateBattle();
    if (!mounted) return;
    AppMessenger.showError(context, message);
    if (!mounted) return;
    context.pop(false);
  }

  String get _characterAsset {
    final CharacterClass? cls = ref.read(playerProvider).profile?.characterClass;
    return switch (cls) {
      CharacterClass.shadow => 'assets/characters/golge.png',
      CharacterClass.alchemist => 'assets/characters/simyaci.png',
      _ => 'assets/characters/savasci.png',
    };
  }

  List<String> _combatFlavorLines() {
    final String name = args.opponent.username;
    final List<String> pool = <String>[
      '$name arena ortasında seni bekliyor...',
      'Bahis masası kilitlendi — ${formatCompactGold(args.wager)} altın!',
      'İlk hamle senden — yumruklar havada!',
      '$name savundu, karşı saldırı geldi!',
      'Kalabalık bağırıyor — basınç yükseliyor!',
      'Kritik an — kader bahsi belirleyecek!',
      'Son vuruş için güç topluyorsun...',
    ];
    pool.shuffle(math.Random());
    return pool.take(7).toList();
  }

  Future<void> _startBattle() async {
    final int generation = ++_battleGeneration;
    final DateTime battleStart = DateTime.now();

    final PlayerProfile? player = ref.read(playerProvider).profile;
    if (player == null) {
      _exitWithError('Oyuncu bilgisi yüklenemedi.');
      return;
    }
    if (player.energy < _energyCost) {
      _exitWithError('Enerji yetersiz ($_energyCost gerekli)');
      return;
    }
    if (player.gold < args.wager) {
      _exitWithError('Yetersiz altın.');
      return;
    }

    if (!mounted || generation != _battleGeneration) return;

    setState(() {
      _phase = 'fighting';
      _battleLog
        ..clear()
        ..add('Bahisli düello başladı!')
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
      final Map<String, dynamic> res =
          await ref.read(mekanRepositoryProvider).pvpBet(
                mekanId: args.mekanId,
                defenderId: args.opponent.authId,
                wager: args.wager,
                offerId: args.opponent.offerId,
              );

      if (!mounted || generation != _battleGeneration) {
        _logTimer?.cancel();
        return;
      }

      if (CaptchaGuard.isCaptchaRequired(res)) {
        _logTimer?.cancel();
        final bool solved = await CaptchaGuard.solve(context, 'arena');
        if (!mounted) return;
        if (solved) {
          unawaited(_startBattle());
        } else {
          context.pop(false);
        }
        return;
      }

      final int elapsed = DateTime.now().difference(battleStart).inMilliseconds;
      if (elapsed < _minFightMs) {
        await Future<void>.delayed(
          Duration(milliseconds: _minFightMs - elapsed),
        );
      }

      if (!mounted || generation != _battleGeneration) {
        _logTimer?.cancel();
        return;
      }

      await ref.read(playerProvider.notifier).loadProfile();

      if (!mounted || generation != _battleGeneration) {
        _logTimer?.cancel();
        return;
      }

      _logTimer?.cancel();
      final bool won = res['won'] == true;
      final bool hospital = res['hospitalized'] == true;
      _battleLog.add(
        won
            ? 'Rakibi yere serdin!'
            : hospital
                ? 'Son vuruşta düştün... hastaneye!'
                : 'Rakip seni alt etti...',
      );

      setState(() {
        _result = res;
        _logIndex = _battleLog.length - 1;
        _phase = won ? 'success' : 'failure';
      });
    } catch (e) {
      if (!mounted) return;
      if (CaptchaGuard.isCaptchaRequired(e)) {
        _logTimer?.cancel();
        final bool solved = await CaptchaGuard.solve(context, 'arena');
        if (solved && mounted) {
          unawaited(_startBattle());
        } else if (mounted) {
          context.pop(false);
        }
        return;
      }
      _exitWithError(
        userFacingErrorMessage(e, fallback: 'Düello başlatılamadı.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayerProfile? profile = ref.watch(playerProvider).profile;
    final String playerName =
        ((profile?.displayName ?? profile?.username) ?? 'SEN').trim();

    return PopScope(
      canPop: !_battleLocked,
      child: Scaffold(
        backgroundColor: BattlePalette.carbonVoid,
        extendBody: true,
        bottomNavigationBar: GameBottomBar(
          currentRoute: AppRoutes.mekans,
          onLogout: () async {
            await ref.read(authProvider.notifier).logout();
            ref.read(playerProvider.notifier).clear();
          },
          navigationLocked: _battleLocked,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _ArenaBattleBackdrop(ambient: _ambient, embers: _battleLocked),
            SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        child: KeyedSubtree(
                          key: ValueKey<String>(_phase),
                          child: _buildPhase(profile, playerName),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: <Widget>[
          PressableScale(
            onTap: _battleLocked
                ? () => AppMessenger.show(
                      context,
                      'Düello bitene kadar çıkamazsın.',
                    )
                : () => context.pop(false),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BattlePalette.spaceNavy.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'BAHİSLİ ARENA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'ALTIN YATIR · KAZAN VEYA KAYBET',
                  style: TextStyle(
                    color: BattlePalette.liquidGold,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          BattleChip(
            icon: Icons.paid_rounded,
            label: 'BAHİS',
            value: formatCompactGold(args.wager),
            color: BattlePalette.liquidGold,
          ),
        ],
      ),
    );
  }

  Widget _buildPhase(PlayerProfile? profile, String playerName) {
    switch (_phase) {
      case 'counting':
        return _ArenaVsIntroView(
          playerAsset: _characterAsset,
          playerName: playerName.isEmpty ? 'SEN' : playerName,
          playerLevel: profile?.level ?? 1,
          playerPower: profile?.power ?? 0,
          opponentName: args.opponent.username,
          opponentLevel: args.opponent.level,
          opponentPower: args.opponent.power,
          opponentRating: args.opponent.pvpRating,
          wager: args.wager,
          onComplete: _startBattle,
        );
      case 'fighting':
        return _ArenaFightingView(
          ambient: _ambient,
          playerAsset: _characterAsset,
          opponentName: args.opponent.username,
          logLines: _battleLog.take(_logIndex + 1).toList(),
        );
      case 'success':
        return _buildResultPhase(won: true);
      case 'failure':
        return _buildResultPhase(won: false);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildResultPhase({required bool won}) {
    final Map<String, dynamic>? res = _result;
    if (res == null) return const SizedBox.shrink();

    final int net = (res['net_win'] as num?)?.toInt() ?? 0;
    final int repDelta = (res['rep_change'] as num?)?.toInt() ?? 0;
    final bool hospital = res['hospitalized'] == true;
    final int nemesisGold = (res['nemesis_revenge_gold'] as num?)?.toInt() ?? 0;
    final bool nemesisGranted = res['nemesis_revenge_granted'] == true;
    final Color accent = won ? MekanPalette.neon : MekanPalette.ruby;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[MekanPalette.surfaceHi, MekanPalette.void_],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent, width: 1.6),
            boxShadow: <BoxShadow>[
              BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 26),
            ],
          ),
          child: Column(
            children: <Widget>[
              Icon(
                won
                    ? Icons.emoji_events_rounded
                    : Icons.sentiment_very_dissatisfied_rounded,
                color: accent,
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                won ? 'ZAFER!' : 'YENİLGİ',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${args.opponent.username} ile maç',
                style: const TextStyle(
                  fontSize: 13,
                  color: MekanPalette.textMid,
                ),
              ),
              const SizedBox(height: 16),
              if (won)
                Text(
                  '+${formatCompactGold(net)} altın',
                  style: const TextStyle(
                    color: AppColors.liquidGold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else
                const Text(
                  'Bahsi kaybettin',
                  style: TextStyle(
                    fontSize: 14,
                    color: MekanPalette.textMid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (won && nemesisGranted && nemesisGold > 0) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Nemesis intikam: +${formatCompactGold(nemesisGold)} g',
                  style: const TextStyle(
                    color: AppColors.liquidGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (repDelta != 0) ...<Widget>[
                const SizedBox(height: 10),
                ReputationGainBanner(
                  amount: repDelta.abs(),
                  label:
                      repDelta > 0 ? 'İtibar kazanıldı' : 'İtibar kaybedildi',
                ),
              ],
              if (hospital) ...<Widget>[
                const SizedBox(height: 12),
                const Text(
                  'Hastaneye kaldırıldın',
                  style: TextStyle(
                    color: MekanPalette.ruby,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (hospital)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BattleCtaButton(
              label: 'HASTANEYE GİT',
              icon: Icons.local_hospital_rounded,
              colors: const <Color>[Color(0xFFE01E5A), Color(0xFF9F1239)],
              glowColor: BattlePalette.cyberFuchsia,
              foreground: Colors.white,
              onTap: () {
                context.pop(true);
                context.go(AppRoutes.hospital);
              },
            ),
          ),
        BattleCtaButton(
          label: 'ARENAYA DÖN',
          icon: Icons.sports_mma_rounded,
          colors: won
              ? const <Color>[Color(0xFF22C55E), Color(0xFF15803D)]
              : const <Color>[Color(0xFFE01E5A), Color(0xFF9F1239)],
          glowColor: accent,
          foreground: Colors.white,
          onTap: () => context.pop(true),
        ),
      ],
    );
  }
}

class _ArenaBattleBackdrop extends StatelessWidget {
  const _ArenaBattleBackdrop({required this.ambient, required this.embers});

  final AnimationController ambient;
  final bool embers;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: BattlePalette.carbonVoid),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 1.1,
              colors: <Color>[
                MekanPalette.ruby.withValues(alpha: 0.22),
                BattlePalette.carbonVoid,
              ],
            ),
          ),
        ),
        if (embers)
          AnimatedBuilder(
            animation: ambient,
            builder: (_, __) => CustomPaint(
              painter: EmberFieldPainter(
                progress: ambient.value,
                color: MekanPalette.ruby,
              ),
            ),
          ),
        CustomPaint(painter: const DotPatternPainter()),
      ],
    );
  }
}

class _ArenaVsIntroView extends StatefulWidget {
  const _ArenaVsIntroView({
    required this.playerAsset,
    required this.playerName,
    required this.playerLevel,
    required this.playerPower,
    required this.opponentName,
    required this.opponentLevel,
    required this.opponentPower,
    required this.opponentRating,
    required this.wager,
    required this.onComplete,
  });

  final String playerAsset;
  final String playerName;
  final int playerLevel;
  final int playerPower;
  final String opponentName;
  final int opponentLevel;
  final int opponentPower;
  final int opponentRating;
  final int wager;
  final VoidCallback onComplete;

  @override
  State<_ArenaVsIntroView> createState() => _ArenaVsIntroViewState();
}

class _ArenaVsIntroViewState extends State<_ArenaVsIntroView>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = 5200;
  static const int _slamMs = 900;
  static const int _countStartMs = 1600;
  static const int _countStepMs = 900;
  static const int _burstStartMs = 4300;

  late final AnimationController _seq;
  int _lastNumber = 0;
  bool _completed = false;

  double _f(int ms) => ms / _totalMs;

  @override
  void initState() {
    super.initState();
    _seq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    )
      ..addListener(_onTick)
      ..addStatusListener(_onStatus)
      ..forward();
  }

  void _onStatus(AnimationStatus status) {
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
    final double start = _f(_countStartMs);
    final double end = _f(_burstStartMs);
    if (v < start || v >= end) return null;
    return (3 - ((v - start) / _f(_countStepMs)).floor()).clamp(1, 3);
  }

  @override
  void dispose() {
    _seq.removeStatusListener(_onStatus);
    _seq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _seq,
      builder: (BuildContext context, Widget? child) {
        final double v = _seq.value;
        final double slideT = Curves.easeOutCubic.transform(
          ((v * _totalMs) / _slamMs).clamp(0.0, 1.0),
        );
        final double slamT = Curves.elasticOut.transform(
          ((v * _totalMs) / _slamMs).clamp(0.0, 1.0),
        );
        final double shockT =
            ((v - _f(200)) / (_f(1400) - _f(200))).clamp(0.0, 1.0);
        final int? number = _numberAt(v);
        final bool inBurst = v >= _f(_burstStartMs);
        final double burstT =
            ((v - _f(_burstStartMs)) / (1 - _f(_burstStartMs))).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Transform.translate(
                  offset: Offset(-280 * (1 - slideT), 0),
                  child: _Portrait(
                    asset: widget.playerAsset,
                    border: BattlePalette.toxicNeon,
                    label: 'SEN',
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: ShockwavePainter(
                          progress: shockT,
                          color: MekanPalette.ruby,
                        ),
                      ),
                      Transform.scale(
                        scale: slamT,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: <Color>[
                                MekanPalette.ruby,
                                BattlePalette.liquidGold,
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: MekanPalette.ruby.withValues(alpha: 0.55),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'VS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
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
                  offset: Offset(280 * (1 - slideT), 0),
                  child: _Portrait(
                    name: widget.opponentName,
                    border: MekanPalette.ruby,
                    label: 'RAKİP',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Opacity(
              opacity: slideT.clamp(0.0, 1.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _StatCard(
                      title: widget.playerName,
                      subtitle: 'Sv ${widget.playerLevel}',
                      power: widget.playerPower,
                      accent: BattlePalette.toxicNeon,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: widget.opponentName,
                      subtitle:
                          'Sv ${widget.opponentLevel} · ${widget.opponentRating} puan',
                      power: widget.opponentPower,
                      accent: MekanPalette.ruby,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: slideT.clamp(0.0, 1.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: BattlePalette.spaceNavy.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: BattlePalette.liquidGold.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.paid_rounded,
                      color: BattlePalette.liquidGold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bahis: ${formatCompactGold(widget.wager)} altın',
                      style: const TextStyle(
                        color: BattlePalette.liquidGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 90,
              child: Center(
                child: number != null
                    ? Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: switch (number) {
                            3 => BattlePalette.warningSolar,
                            2 => BattlePalette.coralFlare,
                            _ => MekanPalette.ruby,
                          },
                          shadows: <Shadow>[
                            Shadow(
                              color: MekanPalette.ruby.withValues(alpha: 0.5),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      )
                    : inBurst
                        ? Opacity(
                            opacity: (1 - burstT).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 1 + burstT * 0.35,
                              child: const Text(
                                'DÖVÜŞ!',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    this.asset,
    this.name,
    required this.border,
    required this.label,
  });

  final String? asset;
  final String? name;
  final Color border;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2.5),
            boxShadow: <BoxShadow>[
              BoxShadow(color: border.withValues(alpha: 0.4), blurRadius: 16),
            ],
            color: BattlePalette.spaceNavy,
          ),
          clipBehavior: Clip.antiAlias,
          child: asset != null
              ? Image.asset(
                  asset!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    color: border,
                    size: 40,
                  ),
                )
              : Center(
                  child: Text(
                    (name ?? '?').isEmpty
                        ? '?'
                        : name!.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: border,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: border,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.power,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final int power;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BattlePalette.spaceNavy.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Güç $power',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaFightingView extends StatelessWidget {
  const _ArenaFightingView({
    required this.ambient,
    required this.playerAsset,
    required this.opponentName,
    required this.logLines,
  });

  final AnimationController ambient;
  final String playerAsset;
  final String opponentName;
  final List<String> logLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: ambient,
          builder: (_, __) {
            final double pulse =
                1 + math.sin(ambient.value * math.pi * 2) * 0.03;
            return Transform.scale(
              scale: pulse,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _Portrait(
                    asset: playerAsset,
                    border: BattlePalette.toxicNeon,
                    label: 'SEN',
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: MekanPalette.ruby.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: MekanPalette.ruby),
                    ),
                    child: const Text(
                      'CANLI',
                      style: TextStyle(
                        color: MekanPalette.ruby,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  _Portrait(
                    name: opponentName,
                    border: MekanPalette.ruby,
                    label: 'RAKİP',
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(minHeight: 220),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          decoration: BoxDecoration(
            color: BattlePalette.spaceNavy.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'SAVAŞ RAPORU',
                style: TextStyle(
                  color: MekanPalette.titanium,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < logLines.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    logLines[i],
                    style: TextStyle(
                      color: i == logLines.length - 1
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontWeight: i == logLines.length - 1
                          ? FontWeight.w800
                          : FontWeight.w600,
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
