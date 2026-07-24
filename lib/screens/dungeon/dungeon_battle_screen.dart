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
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import 'dungeon_item_utils.dart';
import 'widgets/codex_discovery_chip.dart';
import 'dungeon_result_widgets.dart';
import '../reputation/widgets/reputation_gain_banner.dart';
import 'widgets/dungeon_battle_effects.dart';
import 'widgets/dungeon_cave_theme.dart';
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

  /// Ambient loop: embers, sweep bar, ring rotation, breathing.
  late final AnimationController _ambient;

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
    _logTimer?.cancel();
    _ambient.dispose();
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
    _logTimer?.cancel();
    setState(() {
      _result = null;
      _battleLog.clear();
      _logIndex = 0;
    });
    _startCountdown();
  }

  void _startCountdown() {
    final player = ref.read(playerProvider).profile;
    if (player == null) {
      AppMessenger.showError(context, 'Oyuncu bilgisi yüklenemedi.');
      context.pop();
      return;
    }
    if (_energyCost > 0 && player.energy < _energyCost) {
      AppMessenger.show(context, 'Enerji yetersiz.');
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

  Future<void> _startBattle() async {
    final int generation = ++_battleGeneration;
    final DateTime battleStart = DateTime.now();
    setState(() {
      _phase = 'fighting';
      _battleLog
        ..clear()
        ..addAll(zoneFlavorLines(_zone))
        ..addAll(_combatFlavorLines());
      _logIndex = 0;
    });

    _logTimer = Timer.periodic(const Duration(milliseconds: 650), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_logIndex < _battleLog.length - 1) {
        setState(() => _logIndex++);
      }
    });

    try {
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
            unawaited(_startBattle());
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
            _battleLog.add('Ezici bir vuruş!');
          } else {
            _battleLog.add('Düşmanı alt ettin!');
          }
        } else if (parsed.hospitalized) {
          _battleLog.add('Son vuruşta düştün...');
          _battleLog.add('Hastaneye kaldırılıyorsun.');
        } else {
          _battleLog.add('Son vuruşta düştün...');
          _battleLog.add('Bu sefer şans senden yana değildi.');
        }

        setState(() {
          _result = parsed;
          _logIndex = _battleLog.length - 1;
          _phase = parsed.success ? 'success' : 'failure';
        });

        if (parsed.success) {
          unawaited(TutorialTriggers.onDungeonWin(ref));
        }

        if (parsed.inventoryFull) {
          unawaited(BankTutorial.maybeShowInventoryFullDialog(context, ref));
        }
      } else {
        setState(() {
          _result = null;
          _phase = 'failure';
        });
      }
    } catch (e) {
      _logTimer?.cancel();
      if (!mounted) return;
      AppMessenger.showError(
        context,
        userFacingErrorMessage(e, fallback: 'Savaş başlatılamadı.'),
      );
      context.pop();
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
    final player = ref.read(playerProvider).profile;
    if (player == null) return false;
    if (_energyCost <= 0) return true;
    return player.energy >= _energyCost;
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
          _BattleBackdrop(theme: theme, ambient: _ambient, embers: ambientFx),
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
        if (profile != null &&
            powerRequirement != null &&
            powerRequirement > 0) {
          successPct = (calculateDungeonSuccessRate(
                    playerTotalPower: profile.power,
                    dungeonPowerRequirement: powerRequirement,
                    playerLuck: profile.luck ?? 0,
                    reputation: profile.reputation ?? 0,
                    characterClass: profile.characterClass,
                  ) *
                  100)
              .round();
        }

        return _VsIntroView(
          theme: theme,
          characterAsset: _characterAsset,
          playerName: playerName.isEmpty ? 'SEN' : playerName,
          playerLevel: profile?.level ?? 1,
          playerPower: profile?.power ?? 0,
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
        return _FightingView(
          theme: theme,
          ambient: _ambient,
          characterAsset: _characterAsset,
          logLines: _battleLog.take(_logIndex + 1).toList(),
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
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final bool embers;

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: BattlePalette.carbonVoid),
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
                  ColoredBox(color: theme.surfaceDeep),
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
                BattlePalette.carbonVoid.withValues(alpha: 0.35),
                BattlePalette.carbonVoid,
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
// Idle — hero intro: character vs dungeon, stat chips, gold CTA.
// =============================================================================
class _IdleView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        // Breathing character over the dungeon art.
        FadeSlideIn(
          child: SizedBox(
            height: 250,
            child: AnimatedBuilder(
              animation: ambient,
              builder: (BuildContext context, Widget? child) {
                final double breathe =
                    math.sin(ambient.value * 2 * math.pi) * 6;
                return Transform.translate(
                  offset: Offset(0, breathe),
                  child: child,
                );
              },
              child: Image.asset(
                characterAsset,
                fit: BoxFit.contain,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    Icon(Icons.person_pin,
                        size: 140, color: theme.accentGlow),
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

  @override
  Widget build(BuildContext context) {
    final CaveCardTheme theme = widget.theme;

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
                          asset: theme.assetPath,
                          borderColor: BattlePalette.mysticRuby,
                          label: 'DÜŞMAN',
                          cover: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
  });

  final CaveCardTheme theme;
  final AnimationController ambient;
  final String characterAsset;
  final List<String> logLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 12),
        // Duel header: player portrait vs dungeon portrait.
        FadeSlideIn(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _DuelPortrait(
                asset: characterAsset,
                borderColor: BattlePalette.toxicNeon,
                label: 'SEN',
              ),
              // Shaking clash icon.
              AnimatedBuilder(
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          BattlePalette.cyberFuchsia,
                          Color(0xFF9F1239),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: BattlePalette.cyberFuchsia
                              .withValues(alpha: 0.55),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              _DuelPortrait(
                asset: theme.assetPath,
                borderColor: BattlePalette.mysticRuby,
                label: 'DÜŞMAN',
                cover: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // Combat sweep bar.
        FadeSlideIn(
          delayMs: 150,
          child: AnimatedBuilder(
            animation: ambient,
            builder: (BuildContext context, Widget? child) {
              return EnergySweepBar(progress: (ambient.value * 3) % 1.0);
            },
          ),
        ),
        const SizedBox(height: 18),
        // Live combat log console.
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
    );
  }
}

class _DuelPortrait extends StatelessWidget {
  const _DuelPortrait({
    required this.asset,
    required this.borderColor,
    required this.label,
    this.cover = false,
  });

  final String asset;
  final Color borderColor;
  final String label;
  final bool cover;

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
              BoxShadow(
                color: borderColor.withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            asset,
            fit: cover ? BoxFit.cover : BoxFit.contain,
            alignment: cover ? Alignment.center : Alignment.topCenter,
            errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                Icon(Icons.shield_rounded, color: borderColor, size: 40),
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
    required this.icon,
    required this.colors,
    required this.glowColor,
    required this.ambient,
  });

  final IconData icon;
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
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: glowColor.withValues(alpha: pulse),
                        blurRadius: 34,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Icon(icon, color: Colors.white, size: 44),
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
