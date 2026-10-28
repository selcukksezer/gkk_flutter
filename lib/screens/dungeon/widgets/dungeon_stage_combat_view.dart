import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/game_sfx_service.dart';
import '../../../core/services/gpu_shader_service.dart';
import '../../../core/services/graphics_quality_service.dart';
import '../../../models/player_model.dart';
import '../dungeon_battle_profiles.dart';
import 'dungeon_arena_vfx.dart';
import 'dungeon_mob_pack_rig.dart';

/// Phase modes rendered inside the live 2.5D full-screen dungeon world.
enum DungeonStagePhase {
  idle,
  counting,
  fighting,
  victory,
  defeat,
}

/// Player-triggered tactical combat action types during live dungeon battle.
enum DungeonTacticalActionType {
  quickSlash,
  perfectCrit,
  skill1,
  skill2,
  ultimate,
}

/// Reactive command dispatched from [DungeonBattleScreen] into [DungeonStageCombatView].
class DungeonTacticalCommand {
  const DungeonTacticalCommand({
    required this.seq,
    required this.type,
    required this.skillTitle,
    required this.damageMultiplier,
    required this.isCritical,
    required this.aoeAllMobs,
    required this.comboStreak,
  });

  final int seq;
  final DungeonTacticalActionType type;
  final String skillTitle;
  final double damageMultiplier;
  final bool isCritical;
  final bool aoeAllMobs;
  final int comboStreak;
}

({String grade, Color color}) resolveDungeonStyleRank(int streak) {
  if (streak >= 10) {
    return (grade: 'EFSANEVİ', color: const Color(0xFFF43F5E));
  }
  if (streak >= 7) {
    return (grade: 'SS', color: const Color(0xFFFBBF24));
  }
  if (streak >= 5) {
    return (grade: 'S', color: const Color(0xFFFB923C));
  }
  if (streak >= 3) {
    return (grade: 'A', color: const Color(0xFF38BDF8));
  }
  if (streak >= 2) {
    return (grade: 'B', color: const Color(0xFF4ADE80));
  }
  return (grade: 'C', color: const Color(0xFFE2E8F0));
}

class _PackCombatBeat {
  const _PackCombatBeat({
    required this.startT,
    required this.endT,
    required this.isHeroAttacking,
    required this.isCritical,
    required this.comboCount,
    required this.damageFactor,
  });

  final double startT;
  final double endT;
  final bool isHeroAttacking;
  final bool isCritical;
  final int comboCount;
  final double damageFactor;
}

/// 8-Beat Non-Stop Pack Brawl Timeline across the 7000ms combat window.
const List<_PackCombatBeat> _kPackBeats = <_PackCombatBeat>[
  // Beat 0: Vanguard charges, Hero sprints in & lands Opening Combo Slash
  _PackCombatBeat(
    startT: 0.01,
    endT: 0.13,
    isHeroAttacking: true,
    isCritical: false,
    comboCount: 1,
    damageFactor: 0.82,
  ),
  // Beat 1: Vanguard + Flanker launch synchronized 2-Mob Pincer Counter!
  _PackCombatBeat(
    startT: 0.13,
    endT: 0.25,
    isHeroAttacking: false,
    isCritical: false,
    comboCount: 1,
    damageFactor: 0.38,
  ),
  // Beat 2: Hero Whirlwind Critical Cleave — executes Vanguard #0 & splashes Flanker #1!
  _PackCombatBeat(
    startT: 0.25,
    endT: 0.38,
    isHeroAttacking: true,
    isCritical: true,
    comboCount: 2,
    damageFactor: 1.54,
  ),
  // Beat 3: Enraged Flanker & Raider blitz across the flagstones!
  _PackCombatBeat(
    startT: 0.38,
    endT: 0.50,
    isHeroAttacking: false,
    isCritical: false,
    comboCount: 2,
    damageFactor: 0.46,
  ),
  // Beat 4: Hero Shadow-Dash Twin Strike — executes Flanker #1 & wounds Guard!
  _PackCombatBeat(
    startT: 0.50,
    endT: 0.63,
    isHeroAttacking: true,
    isCritical: true,
    comboCount: 3,
    damageFactor: 1.68,
  ),
  // Beat 5: Pack Leader / Boss steps forward with heavy chamber-shaking crush!
  _PackCombatBeat(
    startT: 0.63,
    endT: 0.75,
    isHeroAttacking: false,
    isCritical: true,
    comboCount: 3,
    damageFactor: 0.62,
  ),
  // Beat 6: Hero sweeps down final Guard & breaches Pack Leader's armor!
  _PackCombatBeat(
    startT: 0.75,
    endT: 0.87,
    isHeroAttacking: true,
    isCritical: false,
    comboCount: 4,
    damageFactor: 1.28,
  ),
  // Beat 7: Ultimate 1v1 Center-Sanctum Climax Finale vs Pack Leader / Boss!
  _PackCombatBeat(
    startT: 0.87,
    endT: 0.995,
    isHeroAttacking: true,
    isCritical: true,
    comboCount: 5,
    damageFactor: 1.96,
  ),
];

class _EntityRuntimeState {
  const _EntityRuntimeState({
    required this.liveX,
    required this.liveGroundY,
    required this.strideIntensity,
    required this.attackSlashProgress,
    required this.hitRecoil,
    required this.specularFlash,
    required this.tiltRad,
    required this.scale,
    required this.hpRatio,
    required this.deathProgress,
    required this.afterimageAlpha,
    required this.zPriorityBoost,
  });

  final double liveX;
  final double liveGroundY;
  final double strideIntensity;
  final double attackSlashProgress;
  final double hitRecoil;
  final double specularFlash;
  final double tiltRad;
  final double scale;
  final double hpRatio;
  final double deathProgress;
  final double afterimageAlpha;
  final double zPriorityBoost;
}

/// Full-screen 2.5D dark-fantasy living dungeon chamber:
/// Hero in 60 FPS segmented skeletal combat stance (left) vs Multi-Mob Dungeon Pack
/// (3–5 prowling/charging monsters + Boss/Pack Leader on right), framed by volumetric
/// torchlight shafts, perspective sanctum flagstones, foreground dungeon pillars, and
/// non-stop multi-target melee/arcane choreography.
class DungeonStageCombatView extends StatefulWidget {
  const DungeonStageCombatView({
    super.key,
    required this.profile,
    required this.stagePhase,
    required this.ambient,
    required this.characterAsset,
    required this.characterClass,
    required this.playerName,
    required this.playerLevel,
    required this.playerPower,
    this.powerRequirement,
    this.fullscreen = false,
    this.height = 336,
    this.hudTopInset = 10,
    this.groundYFactor,
    this.overlayChild,
    this.tacticalCommand,
    this.onArenaStrikeTap,
  });

  final DungeonBattleProfile profile;
  final DungeonStagePhase stagePhase;
  final AnimationController ambient;
  final String characterAsset;
  final CharacterClass? characterClass;
  final String playerName;
  final int playerLevel;
  final int playerPower;
  final int? powerRequirement;

  /// When true, renders edge-to-edge full-screen (`100vw × 100vh`) with zero box border.
  final bool fullscreen;
  final double height;
  final double hudTopInset;
  final double? groundYFactor;

  /// Optional centered overlay inside the dungeon (e.g. VS countdown sigil).
  final Widget? overlayChild;

  /// Optional live player tactical command (tap strike / critical ring / class skill).
  final DungeonTacticalCommand? tacticalCommand;

  /// Callback fired when player taps the live 3D arena during `fighting`.
  final void Function(bool isSweetSpot)? onArenaStrikeTap;

  @override
  State<DungeonStageCombatView> createState() => _DungeonStageCombatViewState();
}

class _DungeonStageCombatViewState extends State<DungeonStageCombatView>
    with TickerProviderStateMixin {
  static const List<String> _kPaintedVfxAssets = <String>[
    'assets/dungeon/stage_3d_runic_dais.png',
    'assets/dungeon/vfx_sword_cleave_fire.png',
    'assets/dungeon/vfx_shadow_twin_slash.png',
    'assets/dungeon/vfx_arcane_alchemist_blast.png',
    'assets/dungeon/vfx_monster_savage_claw.png',
    'assets/dungeon/vfx_impact_shockwave.png',
  ];

  /// Dedicated 60 FPS stride oscillator + monotonic clock so both Hero and all
  /// Pack Mobs walk, prowl, and sprint at silky 60Hz with ZERO wrap discontinuities!
  late final AnimationController _locomotionCtrl;
  final Stopwatch _stageClock = Stopwatch();
  int _lastClockMicros = 0;
  double _continuousTimeSec = 0.0;
  double _heroWalkPhase = 0.0;
  double _currentHeroStride = 0.56;
  final List<double> _mobWalkPhases = List<double>.filled(8, 0.0);
  final List<double> _currentMobStrides = List<double>.filled(8, 0.58);

  /// 7000ms multi-wave pack battle timeline controller.
  late final AnimationController _combatCtrl;

  /// 560ms reactive player tactical strike / skill animation controller.
  late final AnimationController _manualStrikeCtrl;
  DungeonTacticalCommand? _activeTacticalCmd;

  /// Pack 1: 650ms Boss Slow-Mo Kill Cam + Ember/Ash Dissolve controller,
  /// plus zero-RAM Hit-Stop freeze (`55ms`) on heavy critical & skill impacts.
  late final AnimationController _killCamCtrl;
  double _hitStopRemainingSec = 0.0;
  int _lastHitStopBeat = -1;

  String? _precachedDungeonId;

  @override
  void initState() {
    super.initState();
    _stageClock.start();
    _locomotionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_onLocomotionFrame);
    _combatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );
    _manualStrikeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _killCamCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    GraphicsQualityService.instance.addListener(_onGraphicsChanged);
    GpuShaderService.instance.warmUpIfEnabled();
    _syncPhaseAnimation();
  }

  void _onGraphicsChanged() {
    if (!mounted) return;
    _precachedDungeonId = null;
    _precacheStageAssets();
    GpuShaderService.instance.warmUpIfEnabled();
    _syncPhaseAnimation();
    setState(() {});
  }

  void _onLocomotionFrame() {
    final int nowUs = _stageClock.elapsedMicroseconds;
    final double dt = _lastClockMicros == 0
        ? 0.016
        : ((nowUs - _lastClockMicros) / 1000000.0).clamp(0.0, 0.050);
    _lastClockMicros = nowUs;

    // Pack 1 Hit-Stop: freeze character/mob locomotion for 48–60ms at peak crit/skill impact!
    if (_hitStopRemainingSec > 0.0) {
      _hitStopRemainingSec = math.max(0.0, _hitStopRemainingSec - dt);
      return;
    }

    // Slow-mo time dilation during Boss Kill Cam execution window
    final double timeScale = _killCamCtrl.isAnimating ? 0.32 : 1.0;
    final double scaledDt = dt * timeScale;
    _continuousTimeSec += scaledDt;

    const double baseAngularVel = 6.8; // ~1.08 full dual-step cycles/sec at rest, ~2.1 cycles/sec sprinting
    const double wrapMod = math.pi * 2000.0; // exact integer multiple of 2*pi -> zero snap!
    if (_currentHeroStride > 0.02) {
      final double heroVel =
          baseAngularVel * (0.52 + 0.82 * _currentHeroStride);
      _heroWalkPhase = (_heroWalkPhase + scaledDt * heroVel) % wrapMod;
    }

    final List<DungeonMobPackMember> pack = resolveDungeonMobPack(
      widget.profile,
      maxMembers: GraphicsQualityService.instance.profile.dungeonMaxPackMobs,
    );
    for (int i = 0; i < pack.length && i < _mobWalkPhases.length; i++) {
      final double st = _currentMobStrides[i];
      if (st > 0.02) {
        final double mobVel =
            baseAngularVel * pack[i].strideFreq * (0.50 + 0.80 * st);
        _mobWalkPhases[i] = (_mobWalkPhases[i] + scaledDt * mobVel) % wrapMod;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheStageAssets();
  }

  @override
  void didUpdateWidget(covariant DungeonStageCombatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.dungeonId != widget.profile.dungeonId) {
      _precacheStageAssets();
    }
    if (oldWidget.stagePhase != widget.stagePhase) {
      if (oldWidget.stagePhase == DungeonStagePhase.fighting &&
          widget.stagePhase == DungeonStagePhase.victory) {
        _hitStopRemainingSec = 0.062;
        _killCamCtrl.forward(from: 0.0);
        unawaited(GameSfxService.instance.play(GameSfx.legendaryDrop));
      } else if (widget.stagePhase == DungeonStagePhase.fighting) {
        _lastHitStopBeat = -1;
        _killCamCtrl.reset();
      }
      _syncPhaseAnimation();
    }
    if (widget.tacticalCommand != null &&
        widget.tacticalCommand!.seq != oldWidget.tacticalCommand?.seq) {
      _activeTacticalCmd = widget.tacticalCommand;
      if (widget.tacticalCommand!.isCritical ||
          widget.tacticalCommand!.type != DungeonTacticalActionType.quickSlash) {
        _hitStopRemainingSec = 0.054;
      }
      unawaited(
        GameSfxService.instance.play(
          widget.tacticalCommand!.isCritical
              ? GameSfx.criticalSlash
              : GameSfx.swordSlash,
        ),
      );
      _manualStrikeCtrl.forward(from: 0.0);
    }
  }

  void _precacheStageAssets() {
    if (_precachedDungeonId == widget.profile.dungeonId) return;
    _precachedDungeonId = widget.profile.dungeonId;

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    if (gfx.enablePaintedBattleVfxBitmaps) {
      for (final String assetPath in _kPaintedVfxAssets) {
        precacheImage(
          ResizeImage.resizeIfNeeded(420, null, AssetImage(assetPath)),
          context,
        );
      }
    }
    precacheImage(
      ResizeImage.resizeIfNeeded(
        gfx.dungeonSpriteCacheWidth,
        null,
        AssetImage(_combatHeroAsset),
      ),
      context,
    );
    final List<DungeonMobPackMember> pack = resolveDungeonMobPack(
      widget.profile,
      maxMembers: gfx.dungeonMaxPackMobs,
    );
    for (final DungeonMobPackMember mob in pack) {
      precacheImage(
        ResizeImage.resizeIfNeeded(
          gfx.dungeonSpriteCacheWidth,
          null,
          AssetImage(mob.spriteAsset),
        ),
        context,
      );
    }
  }

  void _syncPhaseAnimation() {
    final bool isLow = GraphicsQualityService.instance.profile.isLow;
    final bool activeCombat = widget.stagePhase == DungeonStagePhase.fighting ||
        widget.stagePhase == DungeonStagePhase.counting;
    if (isLow && !activeCombat) {
      _locomotionCtrl.stop();
    } else if (!_locomotionCtrl.isAnimating) {
      _locomotionCtrl.repeat();
    }
    if (widget.stagePhase == DungeonStagePhase.fighting) {
      _combatCtrl
        ..reset()
        ..forward();
    } else {
      _combatCtrl.stop();
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_onGraphicsChanged);
    _locomotionCtrl.dispose();
    _combatCtrl.dispose();
    _manualStrikeCtrl.dispose();
    _killCamCtrl.dispose();
    super.dispose();
  }

  /// Dynamic 3/4 right-facing combat-stance hero sprite matching player class.
  String get _combatHeroAsset => switch (widget.characterClass) {
        CharacterClass.shadow => 'assets/dungeon/hero_battle_shadow.png',
        CharacterClass.alchemist => 'assets/dungeon/hero_battle_alchemist.png',
        _ => 'assets/dungeon/hero_battle_warrior.png',
      };

  /// Smooth piecewise HP curve for each pack member across `fightT` (`0..1`).
  double _computeMobHpAt(
    int slot,
    int packLen,
    double fightT,
    DungeonStagePhase phase,
  ) {
    if (phase == DungeonStagePhase.victory) return 0.0;
    if (phase == DungeonStagePhase.defeat) {
      return slot == packLen - 1 ? 0.36 : 0.0;
    }
    if (phase != DungeonStagePhase.fighting) return 1.0;

    final int leaderSlot = packLen - 1;
    double seg(double t0, double t1, double v0, double v1) {
      if (fightT <= t0) return v0;
      if (fightT >= t1) return v1;
      final double u = Curves.easeOutCubic.transform(
        ((fightT - t0) / (t1 - t0)).clamp(0.0, 1.0),
      );
      return ui.lerpDouble(v0, v1, u)!;
    }

    if (slot == 0) {
      // Front Vanguard: hit in Beat 0 (1.0 -> 0.34), executed in Beat 2 (0.34 -> 0.0 at t=0.33)
      if (fightT < 0.25) return seg(0.05, 0.11, 1.0, 0.34);
      return seg(0.28, 0.33, 0.34, 0.0);
    }
    if (slot == 1 && slot != leaderSlot) {
      // Flanker #1: splashed in Beat 2 (1.0 -> 0.48), executed in Beat 4 (0.48 -> 0.0 at t=0.58)
      if (fightT < 0.50) return seg(0.29, 0.36, 1.0, 0.48);
      return seg(0.54, 0.58, 0.48, 0.0);
    }
    if (slot == 2 && slot != leaderSlot) {
      if (packLen == 5) {
        // Boss Akıncı #2: splashed in Beat 4 (1.0 -> 0.32), executed early Beat 6 (0.32 -> 0.0 at t=0.79)
        if (fightT < 0.75) return seg(0.54, 0.61, 1.0, 0.32);
        return seg(0.77, 0.80, 0.32, 0.0);
      }
      // Standard Guard #2: splashed in Beat 4 (1.0 -> 0.30), executed in Beat 6 (0.30 -> 0.0 at t=0.81)
      if (fightT < 0.75) return seg(0.55, 0.61, 1.0, 0.30);
      return seg(0.78, 0.82, 0.30, 0.0);
    }
    if (slot == 3 && slot != leaderSlot) {
      // Boss Elite Guard #3: wounded in Beat 4 (1.0 -> 0.52), executed in Beat 6 (0.52 -> 0.0 at t=0.82)
      if (fightT < 0.75) return seg(0.56, 0.62, 1.0, 0.52);
      return seg(0.78, 0.83, 0.52, 0.0);
    }

    // Pack Leader / Boss: takes splash in Beat 6 (1.0 -> 0.40), climax slash in Beat 7 (0.40 -> 0.06)
    if (fightT < 0.87) return seg(0.79, 0.85, 1.0, 0.40);
    return seg(0.90, 0.97, 0.40, 0.06);
  }

  /// Smooth Hero vitality curve across `fightT` (`0..1`).
  double _computeHeroHpAt(double fightT, DungeonStagePhase phase) {
    if (phase == DungeonStagePhase.victory) return 0.74;
    if (phase == DungeonStagePhase.defeat) return 0.0;
    if (phase != DungeonStagePhase.fighting) return 1.0;

    if (fightT < 0.16) return 1.0;
    if (fightT < 0.41) {
      final double u = ((fightT - 0.16) / 0.07).clamp(0.0, 1.0);
      return ui.lerpDouble(1.0, 0.88, Curves.easeOutCubic.transform(u))!;
    }
    if (fightT < 0.66) {
      final double u = ((fightT - 0.41) / 0.07).clamp(0.0, 1.0);
      return ui.lerpDouble(0.88, 0.75, Curves.easeOutCubic.transform(u))!;
    }
    final double u = ((fightT - 0.66) / 0.07).clamp(0.0, 1.0);
    return ui.lerpDouble(0.75, 0.58, Curves.easeOutCubic.transform(u))!;
  }

  /// Resolves which mob slots are primary & secondary participants for a given beat.
  (int primarySlot, int? secondarySlot) _resolveBeatSlots(
    int beatIndex,
    int packLen,
  ) {
    final int leader = packLen - 1;
    final int lastMinion = math.max(0, packLen - 2);
    return switch (beatIndex) {
      0 => (0, null),
      1 => (math.min(1, leader), 0),
      2 => (0, math.min(1, leader)),
      3 => (lastMinion, math.min(1, leader)),
      4 => (math.min(1, lastMinion), packLen > 3 ? 2 : leader),
      5 => (leader, packLen > 3 ? lastMinion : null),
      6 => (packLen >= 4 ? lastMinion : leader, leader),
      _ => (leader, null),
    };
  }

  /// Computes 4-stage martial dash trajectory (`0..1` beat progress).
  ({
    double lungeRatio,
    double slashProgress,
    double tiltRad,
    double scaleSurge,
    double afterimage,
  }) _computeAttackerMotion(double localT, {required bool isCritical}) {
    if (localT < 0.18) {
      final double u = Curves.easeOutCubic.transform(localT / 0.18);
      return (
        lungeRatio: -0.08 * u,
        slashProgress: 0.24 * u,
        tiltRad: -0.09 * u,
        scaleSurge: 1.0 - 0.03 * u,
        afterimage: 0.0,
      );
    }
    if (localT < 0.36) {
      final double u = Curves.easeInOutExpo.transform((localT - 0.18) / 0.18);
      final double peak = isCritical ? 1.11 : 1.06;
      return (
        lungeRatio: -0.08 + 1.08 * u,
        slashProgress: 0.24 + 0.42 * u,
        tiltRad: -0.09 + 0.25 * u,
        scaleSurge: 0.97 + (peak - 0.97) * u,
        afterimage: isCritical ? 0.38 * math.sin(u * math.pi) : 0.16 * u,
      );
    }
    if (localT < 0.58) {
      final double u = (localT - 0.36) / 0.22;
      final double peak = isCritical ? 1.11 : 1.06;
      return (
        lungeRatio: 1.0 + 0.04 * math.sin(u * math.pi),
        slashProgress: 0.66 + 0.24 * u,
        tiltRad: 0.16 - 0.05 * u,
        scaleSurge: peak - (peak - 1.02) * u,
        afterimage: isCritical ? 0.24 * (1.0 - u) : 0.0,
      );
    }
    final double u = Curves.easeInOutCubic.transform((localT - 0.58) / 0.42);
    return (
      lungeRatio: 1.0 * (1.0 - u),
      slashProgress: 0.90 + 0.10 * u,
      tiltRad: 0.11 * (1.0 - u),
      scaleSurge: 1.02 - 0.02 * u,
      afterimage: 0.0,
    );
  }

  /// Computes physical knockback, shudder, recoil & flash for a struck target.
  ({
    double knockX,
    double recoil,
    double flash,
    double tiltRad,
  }) _computeDefenderImpact(
    double localT, {
    required double pushDir,
    required bool isCritical,
  }) {
    if (localT < 0.28) {
      return (knockX: 0.0, recoil: 0.0, flash: 0.0, tiltRad: 0.0);
    }
    final double impT = ((localT - 0.28) / 0.72).clamp(0.0, 1.0);
    final double env =
        math.sin(math.pow(impT, 0.52) * math.pi).clamp(0.0, 1.0);
    final double shudder = impT < 0.26
        ? math.sin(impT * 92.0) * (isCritical ? 7.0 : 4.5) * (1.0 - impT / 0.26)
        : 0.0;
    final double knockDist = isCritical ? 30.0 : 19.0;
    final double flash = impT < 0.24
        ? math.sin((impT / 0.24) * math.pi).clamp(0.0, 1.0)
        : 0.0;
    return (
      knockX: pushDir * knockDist * env + shudder,
      recoil: env,
      flash: flash,
      tiltRad: pushDir * (isCritical ? 0.15 : 0.10) * env,
    );
  }

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final DungeonBattleProfile profile = widget.profile;
    final List<DungeonMobPackMember> pack = resolveDungeonMobPack(
      profile,
      maxMembers: gfx.dungeonMaxPackMobs,
    );

    final Widget stageBody = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final bool isCompactMobile = w < 620;
        final double defaultGroundFactor = widget.fullscreen
            ? (isCompactMobile ? 0.538 : 0.70)
            : 0.84;
        final double groundY =
            h * (widget.groundYFactor ?? defaultGroundFactor);

        // Frame Hero (left) & Multi-Mob Pack (right) cleanly inside mobile & desktop viewports
        final double arenaSpan = math.min(w, 880.0);
        final double baseHeroX =
            isCompactMobile ? w * 0.21 : (w * 0.5) - (arenaSpan * 0.27);
        final double baseEnemyX =
            isCompactMobile ? w * 0.75 : (w * 0.5) + (arenaSpan * 0.23);
        final double arenaGap = (baseEnemyX - baseHeroX).abs();

        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            widget.ambient,
            _locomotionCtrl,
            _combatCtrl,
            _manualStrikeCtrl,
            _killCamCtrl,
          ]),
          builder: (BuildContext context, _) {
            final double amb = widget.ambient.value;
            final double loco = _locomotionCtrl.value;
            final double locoRad = loco * math.pi * 2.0;
            final double fightT = _combatCtrl.value;

            final DungeonStagePhase phase = widget.stagePhase;
            final bool isFighting = phase == DungeonStagePhase.fighting;
            final bool isCounting = phase == DungeonStagePhase.counting;
            final bool isVictory = phase == DungeonStagePhase.victory;
            final bool isDefeat = phase == DungeonStagePhase.defeat;

            // Identify active beat during `fighting`
            int activeBeatIdx = -1;
            _PackCombatBeat? activeBeat;
            double beatLocalT = 0.0;
            if (isFighting) {
              for (int i = 0; i < _kPackBeats.length; i++) {
                final _PackCombatBeat b = _kPackBeats[i];
                if (fightT >= b.startT && fightT < b.endT) {
                  activeBeatIdx = i;
                  activeBeat = b;
                  beatLocalT =
                      ((fightT - b.startT) / (b.endT - b.startT)).clamp(0.0, 1.0);
                  break;
                }
              }
            }

            final (int primarySlot, int? secondarySlot) = activeBeatIdx >= 0
                ? _resolveBeatSlots(activeBeatIdx, pack.length)
                : (pack.length - 1, null);

            // Base heights
            final double fighterBaseH = widget.fullscreen
                ? (h * (isCompactMobile ? 0.242 : 0.295)).clamp(146.0, 290.0)
                : (h * 0.52).clamp(132.0, 215.0);

            // Compute individual Mob HP, Death Progress & weighted Pack HP
            final List<double> mobHps = List<double>.generate(
              pack.length,
              (int i) => _computeMobHpAt(i, pack.length, fightT, phase),
            );

            // Death disintegration window (`0.0 -> 1.0` right after HP reaches `0`)
            final List<double> mobDeathProgress = List<double>.generate(
              pack.length,
              (int i) {
                if (isVictory) return 1.0;
                if (mobHps[i] > 0.001) return 0.0;
                if (!isFighting) return 1.0;
                final double deathStart = switch (i) {
                  0 => 0.33,
                  1 => 0.58,
                  2 => pack.length == 5 ? 0.80 : 0.82,
                  3 => 0.83,
                  _ => 0.99,
                };
                return ((fightT - deathStart) / 0.12).clamp(0.01, 1.0);
              },
            );

            double totalWeightedHp = 0.0;
            double weightSum = 0.0;
            int aliveMobCount = 0;
            for (int i = 0; i < pack.length; i++) {
              totalWeightedHp += mobHps[i] * pack[i].hpWeight;
              weightSum += pack[i].hpWeight;
              if (mobHps[i] > 0.001) aliveMobCount++;
            }
            final double packHpRatio = weightSum > 0
                ? (totalWeightedHp / weightSum).clamp(0.0, 1.0)
                : 0.0;
            final double heroHpRatio = _computeHeroHpAt(fightT, phase);

            // Compute base formation X & Y for each pack member
            final List<double> mobHomeX = List<double>.generate(
              pack.length,
              (int i) {
                final DungeonMobPackMember m = pack[i];
                final double rawX = baseEnemyX + m.xSpreadFactor * arenaGap;
                return rawX.clamp(baseHeroX + 86.0, w - 42.0);
              },
            );
            final List<double> mobHomeY = List<double>.generate(
              pack.length,
              (int i) => groundY + pack[i].depthYOffset,
            );

            // --- Evaluate Hero 60 FPS Runtime State ---
            double heroX = baseHeroX;
            final double heroGroundY = groundY + 4.0;
            double heroStride = 0.55;
            double heroSlash = 0.0;
            double heroRecoil = 0.0;
            double heroFlash = 0.0;
            double heroTilt = 0.0;
            double heroScale = 1.0;
            double heroAfterimage = 0.0;
            double heroZBoost = 0.0;

            if (phase == DungeonStagePhase.idle || isCounting) {
              // Active 60 FPS combat footwork & readiness stalk!
              final double stalkWave = math.sin(_continuousTimeSec * 1.65);
              final double countAdvance = isCounting ? 20.0 : 0.0;
              heroX = baseHeroX + stalkWave * 16.0 + countAdvance;
              heroStride = isCounting ? 0.94 : 0.58;
              // Periodic practice flourish in idle so Hero feels eager for battle
              final double flourishWindow = (_continuousTimeSec * 0.22) % 1.0;
              if (!isCounting && flourishWindow > 0.76 && flourishWindow < 0.95) {
                heroSlash = ((flourishWindow - 0.76) / 0.19).clamp(0.0, 1.0);
              }
            } else if (isVictory) {
              heroX = baseHeroX + arenaGap * 0.22;
              heroStride = 0.24;
            } else if (isDefeat) {
              heroX = baseHeroX - 14.0;
              heroStride = 0.0;
              heroTilt = -0.22;
            }

            // --- Evaluate Every Pack Mob's 60 FPS Runtime State ---
            final List<_EntityRuntimeState> mobStates =
                List<_EntityRuntimeState>.generate(pack.length, (int i) {
              final DungeonMobPackMember m = pack[i];
              final double patrolAngle =
                  _continuousTimeSec * (1.35 * m.strideFreq) +
                      m.phaseSeed * math.pi * 2.0;
              final double prowlDx = (isFighting
                      ? math.sin(patrolAngle * 1.25) * 14.0
                      : math.sin(patrolAngle) * 20.0) -
                  (isCounting ? 18.0 : 0.0);
              final double prowlDy = math.cos(patrolAngle) * 4.5;

              double mx = mobHomeX[i] + prowlDx;
              double my = mobHomeY[i] + prowlDy;
              double mStride = isCounting
                  ? 0.96
                  : (isFighting ? 0.74 : (isVictory ? 0.0 : 0.58));
              double mSlash = 0.0;
              double mRecoil = 0.0;
              double mFlash = 0.0;
              double mTilt = 0.0;
              double mScale = 1.0;
              double mAfter = 0.0;
              double mZBoost = 0.0;

              // Occasional menacing claw/jaw snap during idle/counting
              final double snapWindow = ((amb * 3.0) + m.phaseSeed) % 1.0;
              if (!isFighting && !isVictory && snapWindow > 0.78 && snapWindow < 0.95) {
                mSlash = ((snapWindow - 0.78) / 0.17).clamp(0.0, 1.0) * 0.75;
              }

              // Active combat beat overrides!
              if (activeBeat != null && mobDeathProgress[i] < 0.99) {
                if (activeBeat.isHeroAttacking) {
                  if (i == primarySlot || i == secondarySlot) {
                    final bool isPrimary = i == primarySlot;
                    final impact = _computeDefenderImpact(
                      beatLocalT,
                      pushDir: 1.0,
                      isCritical: activeBeat.isCritical && isPrimary,
                    );
                    mx += impact.knockX * (isPrimary ? 1.0 : 0.72);
                    mRecoil = impact.recoil * (isPrimary ? 1.0 : 0.75);
                    mFlash = impact.flash;
                    mTilt = impact.tiltRad;
                    mStride = 0.35;
                  }
                } else {
                  // Monster Pack Attack Beat! Primary (+ optional Secondary Pincer Mob!) charges Hero!
                  if (i == primarySlot || (i == secondarySlot && mobHps[i] > 0.05)) {
                    final bool isPrimary = i == primarySlot;
                    final double delayT = isPrimary
                        ? beatLocalT
                        : ((beatLocalT - 0.06) / 0.94).clamp(0.0, 1.0);
                    final motion = _computeAttackerMotion(
                      delayT,
                      isCritical: activeBeat.isCritical && isPrimary,
                    );
                    final double strikeTargetX =
                        baseHeroX + (isPrimary ? 58.0 : 88.0);
                    mx = ui.lerpDouble(mx, strikeTargetX, motion.lungeRatio)!;
                    my = ui.lerpDouble(
                      my,
                      heroGroundY + (isPrimary ? 2.0 : -10.0),
                      motion.lungeRatio.clamp(0.0, 1.0),
                    )!;
                    mSlash = motion.slashProgress;
                    mTilt = -motion.tiltRad;
                    mScale = motion.scaleSurge;
                    mAfter = motion.afterimage;
                    mStride = 1.38; // Full 60 FPS charging sprint!
                    mZBoost = isPrimary ? 90.0 : 70.0;
                  }
                }
              }

              return _EntityRuntimeState(
                liveX: mx,
                liveGroundY: my,
                strideIntensity: mStride,
                attackSlashProgress: mSlash,
                hitRecoil: mRecoil,
                specularFlash: mFlash,
                tiltRad: mTilt,
                scale: mScale,
                hpRatio: mobHps[i],
                deathProgress: mobDeathProgress[i],
                afterimageAlpha: mAfter,
                zPriorityBoost: mZBoost,
              );
            });

            // Apply active combat beat kinematics to Hero + Camera!
            double camShakeX = 0.0;
            double camShakeY = 0.0;
            double camZoom = 0.0;
            double vfxProgress = 0.0;
            Offset vfxCenter = Offset(w * 0.5, groundY - fighterBaseH * 0.5);
            double vfxHeight = fighterBaseH;
            Offset? secondaryVfxCenter;

            int? popupDamage;
            int? secondaryPopupDamage;
            bool popupCrit = false;
            bool popupOnEnemy = true;
            double popupT = 0.0;
            Offset popupAnchor = Offset(baseEnemyX, groundY - fighterBaseH);
            Offset? secondaryPopupAnchor;

            if (activeBeat != null) {
              final int targetIdx = primarySlot.clamp(0, pack.length - 1);
              final _EntityRuntimeState primaryMobState = mobStates[targetIdx];
              final double targetSpriteH =
                  (fighterBaseH * pack[targetIdx].scale).clamp(118.0, h * 0.40);

              if (activeBeat.isHeroAttacking) {
                final motion = _computeAttackerMotion(
                  beatLocalT,
                  isCritical: activeBeat.isCritical,
                );
                final double strikeX = primaryMobState.liveX - 56.0;
                heroX = ui.lerpDouble(baseHeroX, strikeX, motion.lungeRatio)!;
                heroSlash = motion.slashProgress;
                heroTilt = motion.tiltRad;
                heroScale = motion.scaleSurge;
                heroAfterimage = motion.afterimage;
                heroStride = 1.38; // Full 60 FPS sprint during approach & vault!
                heroZBoost = 95.0;

                vfxCenter = Offset(
                  primaryMobState.liveX,
                  primaryMobState.liveGroundY - targetSpriteH * 0.48,
                );
                vfxHeight = targetSpriteH;
                popupAnchor = Offset(
                  primaryMobState.liveX,
                  math.max(
                    widget.hudTopInset + 56,
                    primaryMobState.liveGroundY - targetSpriteH * 1.06,
                  ),
                );

                if (secondarySlot != null &&
                    secondarySlot < pack.length &&
                    mobStates[secondarySlot].deathProgress < 0.85) {
                  final _EntityRuntimeState secState = mobStates[secondarySlot];
                  final double secH =
                      (fighterBaseH * pack[secondarySlot].scale)
                          .clamp(112.0, h * 0.36);
                  secondaryVfxCenter = Offset(
                    secState.liveX,
                    secState.liveGroundY - secH * 0.48,
                  );
                  secondaryPopupAnchor = Offset(
                    secState.liveX,
                    math.max(
                      widget.hudTopInset + 62,
                      secState.liveGroundY - secH * 1.04,
                    ),
                  );
                }
              } else {
                // Hero defends against Pack Pincer / Boss Crush!
                final impact = _computeDefenderImpact(
                  beatLocalT,
                  pushDir: -1.0,
                  isCritical: activeBeat.isCritical,
                );
                heroX = baseHeroX + impact.knockX;
                heroRecoil = impact.recoil;
                heroFlash = impact.flash;
                heroTilt = impact.tiltRad;
                heroStride = 0.42;

                vfxCenter = Offset(heroX, heroGroundY - fighterBaseH * 0.50);
                vfxHeight = fighterBaseH;
                popupAnchor = Offset(
                  heroX,
                  math.max(
                    widget.hudTopInset + 56,
                    heroGroundY - fighterBaseH * 1.06,
                  ),
                );
              }

              // Camera impact punch & dynamic dolly zoom
              if (beatLocalT >= 0.28) {
                if (activeBeat.isCritical && _lastHitStopBeat != activeBeatIdx) {
                  _lastHitStopBeat = activeBeatIdx;
                  _hitStopRemainingSec = 0.048;
                }
                final double impT = ((beatLocalT - 0.28) / 0.72).clamp(0.0, 1.0);
                final double decay = math.pow(1.0 - impT, 2.2).toDouble();
                final double amp = activeBeat.isCritical ? 9.0 : 5.0;
                final double dir = activeBeat.isHeroAttacking ? 1.0 : -1.0;
                camShakeX =
                    (dir * amp * 0.52 + math.sin(impT * 58.0) * amp) * decay;
                camShakeY = math.cos(impT * 44.0) * (amp * 0.50) * decay;
              }
              camZoom = math.sin(beatLocalT * math.pi).clamp(0.0, 1.0) *
                  (activeBeat.isCritical ? 0.048 : 0.026);

              if (beatLocalT >= 0.26 && beatLocalT <= 0.88) {
                vfxProgress = ((beatLocalT - 0.26) / 0.62).clamp(0.0, 1.0);
              }

              if (beatLocalT >= 0.28) {
                popupT = ((beatLocalT - 0.28) / 0.72).clamp(0.0, 1.0);
                popupCrit = activeBeat.isCritical;
                popupOnEnemy = activeBeat.isHeroAttacking;
                final int basePower = math.max(120, widget.playerPower);
                popupDamage =
                    (basePower * 0.28 * activeBeat.damageFactor).round();
                if (secondaryPopupAnchor != null && popupOnEnemy) {
                  secondaryPopupDamage = (popupDamage * 0.62).round();
                }
              }
            }

            // --- Reactive Player Tactical Strike / Skill Override Layer ---
            int firstAliveMobIdx = pack.length - 1;
            for (int i = 0; i < pack.length; i++) {
              if (mobStates[i].hpRatio > 0.005 &&
                  mobStates[i].deathProgress <= 0.02) {
                firstAliveMobIdx = i;
                break;
              }
            }
            final double ringPhase = (_continuousTimeSec * 0.78) % 1.0;
            final bool isRingSweetSpot =
                ringPhase >= 0.66 && ringPhase <= 0.96;

            final bool manualActive = _manualStrikeCtrl.isAnimating &&
                _activeTacticalCmd != null &&
                isFighting;
            double manualVfxProgress = 0.0;
            Offset manualVfxCenter =
                Offset(baseEnemyX, groundY - fighterBaseH * 0.5);
            double manualVfxHeight = fighterBaseH;
            int? manualPopupDamage;
            double manualPopupT = 0.0;
            Offset manualPopupAnchor =
                Offset(baseEnemyX, groundY - fighterBaseH);

            if (manualActive) {
              final DungeonTacticalCommand cmd = _activeTacticalCmd!;
              final double mT = _manualStrikeCtrl.value;
              final _EntityRuntimeState targetSt = mobStates[firstAliveMobIdx];
              final double tSpriteH =
                  (fighterBaseH * pack[firstAliveMobIdx].scale)
                      .clamp(118.0, h * 0.40);

              final mMotion = _computeAttackerMotion(
                mT,
                isCritical: cmd.isCritical,
              );
              final double mStrikeX = targetSt.liveX - 52.0;
              heroX = ui.lerpDouble(heroX, mStrikeX, mMotion.lungeRatio)!;
              heroSlash = math.max(heroSlash, mMotion.slashProgress);
              heroTilt = mMotion.tiltRad;
              heroScale = math.max(heroScale, mMotion.scaleSurge);
              heroAfterimage = math.max(heroAfterimage, mMotion.afterimage);
              heroStride = 1.45;
              heroZBoost = 115.0;

              for (int i = 0; i < mobStates.length; i++) {
                if (mobStates[i].deathProgress >= 0.95) continue;
                if (i == firstAliveMobIdx || cmd.aoeAllMobs) {
                  final double factor = i == firstAliveMobIdx ? 1.0 : 0.78;
                  final mImp = _computeDefenderImpact(
                    mT,
                    pushDir: 1.0,
                    isCritical: cmd.isCritical,
                  );
                  final _EntityRuntimeState prev = mobStates[i];
                  mobStates[i] = _EntityRuntimeState(
                    liveX: prev.liveX + mImp.knockX * factor,
                    liveGroundY: prev.liveGroundY,
                    strideIntensity: prev.strideIntensity,
                    attackSlashProgress: prev.attackSlashProgress,
                    hitRecoil: math.max(prev.hitRecoil, mImp.recoil * factor),
                    specularFlash: math.max(prev.specularFlash, mImp.flash),
                    tiltRad: prev.tiltRad + mImp.tiltRad * factor,
                    scale: prev.scale,
                    hpRatio: prev.hpRatio,
                    deathProgress: prev.deathProgress,
                    afterimageAlpha: prev.afterimageAlpha,
                    zPriorityBoost: prev.zPriorityBoost,
                  );
                }
              }

              if (mT >= 0.20) {
                final double impT = ((mT - 0.20) / 0.80).clamp(0.0, 1.0);
                final double decay = math.pow(1.0 - impT, 2.0).toDouble();
                final double amp = cmd.isCritical ? 11.0 : 6.5;
                camShakeX += (amp * 0.55 + math.sin(impT * 62.0) * amp) * decay;
                camShakeY += math.cos(impT * 48.0) * (amp * 0.45) * decay;
                camZoom += (cmd.isCritical ? 0.055 : 0.032) * decay;
                manualVfxProgress = impT;
                manualPopupT = impT;
                final int basePwr = math.max(120, widget.playerPower);
                manualPopupDamage =
                    (basePwr * 0.34 * cmd.damageMultiplier).round();
              }
              manualVfxCenter = Offset(
                mobStates[firstAliveMobIdx].liveX,
                mobStates[firstAliveMobIdx].liveGroundY - tSpriteH * 0.50,
              );
              manualVfxHeight = tSpriteH * (cmd.aoeAllMobs ? 1.28 : 1.05);
              manualPopupAnchor = Offset(
                mobStates[firstAliveMobIdx].liveX,
                math.max(
                  widget.hudTopInset + 54,
                  mobStates[firstAliveMobIdx].liveGroundY - tSpriteH * 1.12,
                ),
              );
            }

            _currentHeroStride = heroStride;
            for (int i = 0;
                i < mobStates.length && i < _currentMobStrides.length;
                i++) {
              _currentMobStrides[i] = mobStates[i].strideIntensity;
            }

            final _EntityRuntimeState heroState = _EntityRuntimeState(
              liveX: heroX,
              liveGroundY: heroGroundY,
              strideIntensity: heroStride,
              attackSlashProgress: heroSlash,
              hitRecoil: heroRecoil,
              specularFlash: heroFlash,
              tiltRad: heroTilt,
              scale: heroScale,
              hpRatio: heroHpRatio,
              deathProgress: 0.0,
              afterimageAlpha: heroAfterimage,
              zPriorityBoost: heroZBoost,
            );

            // Build depth-sorted fighter widgets (2.5D isometric Y-order + active attacker priority!)
            final List<(double sortKey, Widget widget)> depthSortedFighters =
                <(double, Widget)>[
              (
                heroState.liveGroundY + heroState.zPriorityBoost,
                _buildHeroFighter(
                  h: h,
                  fighterBaseH: fighterBaseH,
                  locoRad: locoRad,
                  amb: amb,
                  isDefeat: isDefeat,
                  state: heroState,
                  accentColor: profile.primaryColor,
                ),
              ),
            ];

            final List<DungeonPackShadowAnchor> packShadows =
                <DungeonPackShadowAnchor>[];
            final List<
                ({
                  DungeonMobPackMember member,
                  double hpRatio,
                  double x,
                  double bottomY,
                })> rawOverheadBars = <({
              DungeonMobPackMember member,
              double hpRatio,
              double x,
              double bottomY,
            })>[];

            for (int i = 0; i < pack.length; i++) {
              final DungeonMobPackMember mob = pack[i];
              final _EntityRuntimeState st = mobStates[i];
              if (st.deathProgress >= 1.0) continue;

              final double mobH = (fighterBaseH * mob.scale).clamp(
                114.0,
                widget.fullscreen ? h * 0.39 : h * 0.68,
              );
              final double hoverLift = mob.hover ? 10.0 : 0.0;

              packShadows.add(
                DungeonPackShadowAnchor(
                  x: st.liveX,
                  y: st.liveGroundY,
                  width: mobH * (mob.isLeader ? 0.72 : 0.58),
                  alpha: (1.0 - st.deathProgress).clamp(0.0, 1.0) *
                      (isVictory ? 0.0 : 1.0),
                  isLeader: mob.isLeader,
                ),
              );

              depthSortedFighters.add((
                st.liveGroundY + st.zPriorityBoost,
                _buildMobPackFighter(
                  profile: profile,
                  member: mob,
                  state: st,
                  h: h,
                  spriteH: mobH,
                  locoRad: locoRad,
                  amb: amb,
                  isVictory: isVictory,
                ),
              ));

              if (!isVictory &&
                  st.deathProgress <= 0.02 &&
                  st.hpRatio > 0.005 &&
                  widget.fullscreen) {
                rawOverheadBars.add((
                  member: mob,
                  hpRatio: st.hpRatio,
                  x: st.liveX,
                  bottomY: (h - st.liveGroundY) -
                      4.0 +
                      hoverLift +
                      mobH * st.scale +
                      4.0,
                ));
              }
            }

            // 2D anti-overlap pass so foreground mob nameplates never collide or clip
            final List<double> barXs = rawOverheadBars
                .map<double>(
                  (b) => b.x.clamp(48.0, math.max(48.0, w - 48.0)).toDouble(),
                )
                .toList();
            final List<double> barBottomYs =
                rawOverheadBars.map((b) => b.bottomY).toList();
            const double minBarSepX = 72.0;
            const double minBarSepY = 26.0;
            final double maxBarBottomY =
                math.max(120.0, h - widget.hudTopInset - 88.0);
            for (int pass = 0; pass < 3; pass++) {
              for (int i = 0; i < rawOverheadBars.length; i++) {
                for (int j = i + 1; j < rawOverheadBars.length; j++) {
                  final double dx = barXs[j] - barXs[i];
                  final double dy = barBottomYs[j] - barBottomYs[i];
                  if (dx.abs() < minBarSepX && dy.abs() < minBarSepY) {
                    final bool jIsLeader = rawOverheadBars[j].member.isLeader;
                    final bool iIsLeader = rawOverheadBars[i].member.isLeader;
                    final double lift = (minBarSepY - dy.abs()) + 2.0;
                    final double pushX = (minBarSepX - dx.abs()) * 0.28;
                    final double signX = dx >= 0 ? 1.0 : -1.0;
                    if (jIsLeader && !iIsLeader) {
                      barBottomYs[i] = barBottomYs[j] >= barBottomYs[i]
                          ? barBottomYs[i] - lift * 0.55
                          : barBottomYs[i] + lift;
                      barXs[i] -= signX * pushX;
                    } else if (iIsLeader && !jIsLeader) {
                      barBottomYs[j] = barBottomYs[i] >= barBottomYs[j]
                          ? barBottomYs[j] - lift * 0.55
                          : barBottomYs[j] + lift;
                      barXs[j] += signX * pushX;
                    } else if (barBottomYs[j] >= barBottomYs[i]) {
                      barBottomYs[j] += lift * 0.65;
                      barBottomYs[i] -= lift * 0.35;
                      barXs[j] += signX * pushX * 0.5;
                      barXs[i] -= signX * pushX * 0.5;
                    } else {
                      barBottomYs[i] += lift * 0.65;
                      barBottomYs[j] -= lift * 0.35;
                      barXs[j] += signX * pushX * 0.5;
                      barXs[i] -= signX * pushX * 0.5;
                    }
                    barXs[i] = barXs[i].clamp(48.0, math.max(48.0, w - 48.0));
                    barXs[j] = barXs[j].clamp(48.0, math.max(48.0, w - 48.0));
                    barBottomYs[i] = barBottomYs[i].clamp(90.0, maxBarBottomY);
                    barBottomYs[j] = barBottomYs[j].clamp(90.0, maxBarBottomY);
                  }
                }
              }
            }

            depthSortedFighters.sort(
              ((double, Widget) a, (double, Widget) b) =>
                  a.$1.compareTo(b.$1),
            );

            // Dynamic 3D multi-axis chamber camera rig
            final double actionFocusBias = isFighting
                ? ((heroState.liveX - w * 0.5) / math.max(1.0, w)) * 0.14
                : 0.0;
            final double camPanX =
                math.sin(amb * math.pi * 2) * 0.075 + actionFocusBias;
            final double torchFlicker =
                0.80 + 0.20 * math.sin(locoRad * 2.0 + amb * math.pi * 4);
            final double pillarW =
                (w * (isCompactMobile ? 0.14 : 0.15)).clamp(48.0, 190.0);

            final double daisW =
                math.min(w * (isCompactMobile ? 1.08 : 1.18), 1020.0);
            final double daisH = daisW * 0.42;
            final double daisCenterX = (baseHeroX + baseEnemyX) * 0.5;

            final double killCamT =
                _killCamCtrl.isAnimating ? _killCamCtrl.value : 0.0;
            if (killCamT > 0.0) {
              camZoom += math.sin(killCamT * math.pi) * 0.092;
            }
            double critEdgeFlash = 0.0;
            if (activeBeat != null &&
                activeBeat.isCritical &&
                beatLocalT >= 0.28 &&
                beatLocalT <= 0.56) {
              critEdgeFlash = math.max(
                critEdgeFlash,
                1.0 - ((beatLocalT - 0.28) / 0.28),
              );
            }
            if (manualActive &&
                _activeTacticalCmd!.isCritical &&
                manualVfxProgress > 0.0 &&
                manualVfxProgress < 0.45) {
              critEdgeFlash = math.max(
                critEdgeFlash,
                1.0 - (manualVfxProgress / 0.45),
              );
            }

            final double camPitch = 0.056 +
                math.cos(amb * math.pi * 2) * 0.010 -
                camZoom * 0.22;
            final double camYaw = -actionFocusBias * 0.16 +
                math.sin(amb * math.pi * 2) * 0.012;
            final Matrix4 stage3dMatrix = Matrix4.identity()
              ..setEntry(3, 2, 0.00072)
              ..rotateX(camPitch)
              ..rotateY(camYaw)
              ..multiply(
                Matrix4.diagonal3Values(
                  1.042 + camZoom * 0.35,
                  1.052 + camZoom * 0.35,
                  1.0,
                ),
              );

            final _EntityRuntimeState reticleMob = mobStates[firstAliveMobIdx];
            final double reticleMobH =
                (fighterBaseH * pack[firstAliveMobIdx].scale)
                    .clamp(118.0, h * 0.39);
            final Offset reticleCenter = Offset(
              reticleMob.liveX,
              reticleMob.liveGroundY - reticleMobH * 0.46,
            );

            final Widget innerWorldStack = Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: <Widget>[
                // 1. MULTI-PLANE PARALLAX DUNGEON CHAMBER BACKDROP
                Positioned(
                  left: gfx.enable3dPerspective ? -28 : 0,
                  right: gfx.enable3dPerspective ? -28 : 0,
                  top: gfx.enable3dPerspective ? -28 : 0,
                  bottom: gfx.enable3dPerspective ? -28 : 0,
                  child: Transform.scale(
                    scale: gfx.enable3dPerspective
                        ? (1.055 +
                            math.sin(amb * math.pi * 2) * 0.014 +
                            camZoom)
                        : (1.0 + camZoom * 0.5),
                    child: Image.asset(
                      profile.arenaAsset,
                      cacheWidth: gfx.dungeonArenaCacheWidth,
                      fit: BoxFit.cover,
                      alignment: Alignment(camPanX.clamp(-0.35, 0.35), 0.15),
                      filterQuality: gfx.filterQuality,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: profile.deepSurface),
                    ),
                  ),
                ),

                // 2. Volumetric Sanctum Glow + Atmospheric Depth Vignettes
                if (!gfx.isLow)
                  Positioned(
                    left: -24,
                    right: -24,
                    top: -24,
                    bottom: -24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(actionFocusBias * 1.5, -0.06),
                          radius: 0.94,
                          colors: <Color>[
                            profile.primaryColor
                                .withValues(alpha: 0.16 * torchFlicker),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.58),
                          ],
                          stops: const <double>[0.0, 0.56, 1.0],
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.70),
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.08),
                          profile.deepSurface.withValues(alpha: 0.84),
                        ],
                        stops: const <double>[0.0, 0.22, 0.66, 1.0],
                      ),
                    ),
                  ),
                ),

                // 3. Blender 5.0.1 Raytraced 3D Carved Obsidian Runic Dais (Medium+)!
                if (!gfx.isLow)
                  Positioned(
                    left: daisCenterX - daisW * 0.5,
                    top: groundY - daisH * 0.60,
                    width: daisW,
                    height: daisH,
                    child: IgnorePointer(
                      child: Image.asset(
                        'assets/dungeon/stage_3d_runic_dais.png',
                        cacheWidth: 640,
                        opacity: const AlwaysStoppedAnimation<double>(0.94),
                        fit: BoxFit.fill,
                        filterQuality: gfx.filterQuality,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                // 3b. 2.5D Chamber God-Rays, Floor Rune Pulse & All Pack Shadows
                Positioned.fill(
                  child: CustomPaint(
                    painter: DungeonChamberDepthPainter(
                      ambientProgress: amb,
                      locomotionProgress: loco,
                      primary: profile.primaryColor,
                      secondary: profile.secondaryColor,
                      isBoss: profile.isBoss,
                      heroX: heroState.liveX,
                      groundY: heroState.liveGroundY,
                      packShadows: packShadows,
                      combatIntensity: isFighting ? 1.0 : 0.35,
                    ),
                  ),
                ),

                // 4. Depth-Sorted 60 FPS Segmented Hero & Multi-Mob Pack!
                for (final (double _, Widget fighter) in depthSortedFighters)
                  fighter,

                // 4a. Foreground Un-Occluded, Un-Tilted Pack Nameplates & Mini HP Bars!
                for (int i = 0; i < rawOverheadBars.length; i++)
                  Positioned(
                    left: barXs[i] - 46.0,
                    bottom: barBottomYs[i],
                    width: 92.0,
                    child: IgnorePointer(
                      child: Center(
                        child: _MobOverheadMiniBar(
                          member: rawOverheadBars[i].member,
                          hpRatio: rawOverheadBars[i].hpRatio,
                          primary: profile.primaryColor,
                          secondary: profile.secondaryColor,
                        ),
                      ),
                    ),
                  ),

                // 4b. Interactive Converging Golden Critical Timing Reticle on Active Target!
                if (isFighting &&
                    widget.onArenaStrikeTap != null &&
                    reticleMob.deathProgress < 0.85)
                  Positioned(
                    left: reticleCenter.dx - 64,
                    top: reticleCenter.dy - 64,
                    width: 128,
                    height: 128,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CriticalTimingReticlePainter(
                          ringPhase: ringPhase,
                          isSweetSpot: isRingSweetSpot,
                          accentColor: profile.primaryColor,
                        ),
                      ),
                    ),
                  ),

                // 5. AAA Hand-Painted Combat Slash, Claw, Arcane Burst & AoE Splash VFX
                if (activeBeat != null && vfxProgress > 0.0) ...<Widget>[
                  _PaintedCombatVfxOverlay(
                    progress: vfxProgress,
                    isHeroAttacking: activeBeat.isHeroAttacking,
                    isCritical: activeBeat.isCritical,
                    heroClass: widget.characterClass,
                    monsterSlashType: profile.slashStyle,
                    primaryColor: profile.primaryColor,
                    secondaryColor: profile.secondaryColor,
                    targetCenter: vfxCenter,
                    targetHeight: vfxHeight,
                  ),
                  if (!gfx.isLow &&
                      secondaryVfxCenter != null &&
                      activeBeat.isHeroAttacking)
                    _PaintedCombatVfxOverlay(
                      progress: (vfxProgress * 1.08).clamp(0.0, 1.0),
                      isHeroAttacking: true,
                      isCritical: false,
                      heroClass: widget.characterClass,
                      monsterSlashType: profile.slashStyle,
                      primaryColor: profile.primaryColor,
                      secondaryColor: profile.secondaryColor,
                      targetCenter: secondaryVfxCenter,
                      targetHeight: vfxHeight * 0.78,
                    ),
                ],
                if (manualActive && manualVfxProgress > 0.0) ...<Widget>[
                  _PaintedCombatVfxOverlay(
                    progress: manualVfxProgress,
                    isHeroAttacking: true,
                    isCritical: _activeTacticalCmd!.isCritical,
                    heroClass: widget.characterClass,
                    monsterSlashType: profile.slashStyle,
                    primaryColor: const Color(0xFFFBBF24),
                    secondaryColor: profile.primaryColor,
                    targetCenter: manualVfxCenter,
                    targetHeight: manualVfxHeight,
                  ),
                  if (!gfx.isLow ||
                      _activeTacticalCmd!.type !=
                          DungeonTacticalActionType.quickSlash)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ClassSignatureSkillVfxPainter(
                            progress: manualVfxProgress,
                            heroClass: widget.characterClass,
                            actionType: _activeTacticalCmd!.type,
                            targetCenter: manualVfxCenter,
                            groundY: groundY,
                            isLowTier: gfx.isLow,
                          ),
                        ),
                      ),
                    ),
                ] else if (!gfx.isLow &&
                    activeBeat != null &&
                    activeBeat.isHeroAttacking &&
                    activeBeat.isCritical &&
                    vfxProgress > 0.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ClassSignatureSkillVfxPainter(
                          progress: vfxProgress,
                          heroClass: widget.characterClass,
                          actionType: activeBeatIdx == 7
                              ? DungeonTacticalActionType.ultimate
                              : DungeonTacticalActionType.skill1,
                          targetCenter: vfxCenter,
                          groundY: groundY,
                          isLowTier: false,
                        ),
                      ),
                    ),
                  ),

                // 5b. Boss Slow-Mo Kill Cam Ember/Ash Dissolve Burst!
                if (killCamT > 0.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _BossKillCamDissolvePainter(
                          progress: killCamT,
                          center: Offset(
                            baseEnemyX,
                            groundY - fighterBaseH * 0.52,
                          ),
                          primaryColor: profile.primaryColor,
                          isLowTier: gfx.isLow,
                        ),
                      ),
                    ),
                  ),

                // 6. Live Dungeon Atmospheric Weather & Embers + Optional GPU Heat Distortion Shader (High/Ultra)
                if (gfx.enableGpuShaders &&
                    (profile.isBoss ||
                        (profile.primaryColor.r * 255.0) > 165.0))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GpuHeatDistortionPainter(
                          timeSec: _continuousTimeSec,
                          intensity: isFighting ? 0.92 : 0.55,
                        ),
                      ),
                    ),
                  ),
                if (gfx.enableWeatherAndAtmosphere)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: DungeonWeatherPainter(
                          type: profile.weatherVfx,
                          progress: amb,
                          primary: profile.primaryColor,
                          secondary: profile.secondaryColor,
                          intensity: isFighting ? 0.98 : 0.80,
                        ),
                      ),
                    ),
                  ),
              ],
            );

            final Widget chamberStack = Transform.translate(
              offset: Offset(camShakeX, camShakeY),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // 1..6 WRAPPED IN TRUE 3D PERSPECTIVE CAMERA RIG WHEN ENABLED!
                  Positioned.fill(
                    child: gfx.enable3dPerspective
                        ? Transform(
                            alignment: const Alignment(0, 0.26),
                            transform: stage3dMatrix,
                            child: innerWorldStack,
                          )
                        : innerWorldStack,
                  ),

                  // 7. 2.5D FOREGROUND OCCLUSION: Clean Unmixed HD Parallax Dungeon Stone Pillars + Torch Bloom!
                  if (widget.fullscreen &&
                      gfx.enableForegroundOcclusion) ...<Widget>[
                    Positioned(
                      left: -pillarW * 0.28 - (camPanX * 56),
                      top: -14,
                      bottom: -14,
                      width: pillarW,
                      child: IgnorePointer(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.asset(
                              'assets/dungeon/fg_dungeon_left_pillar.png',
                              cacheWidth: 260,
                              opacity:
                                  const AlwaysStoppedAnimation<double>(0.92),
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight,
                              filterQuality: gfx.filterQuality,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                            Align(
                              alignment: const Alignment(0.45, -0.18),
                              child: Container(
                                width: pillarW * 0.85,
                                height: pillarW * 0.85,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: <Color>[
                                      const Color(0xFFFB923C).withValues(
                                        alpha: 0.22 * torchFlicker,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -pillarW * 0.28 + (camPanX * 56),
                      top: -14,
                      bottom: -14,
                      width: pillarW,
                      child: IgnorePointer(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.asset(
                              'assets/dungeon/fg_dungeon_right_pillar.png',
                              cacheWidth: 260,
                              opacity:
                                  const AlwaysStoppedAnimation<double>(0.92),
                              fit: BoxFit.cover,
                              alignment: Alignment.centerLeft,
                              filterQuality: gfx.filterQuality,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                            Align(
                              alignment: const Alignment(-0.45, -0.18),
                              child: Container(
                                width: pillarW * 0.85,
                                height: pillarW * 0.85,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: <Color>[
                                      const Color(0xFFFB923C).withValues(
                                        alpha: 0.22 * torchFlicker,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              stops: const <double>[0.0, 0.08, 0.92, 1.0],
                              colors: <Color>[
                                Colors.black.withValues(alpha: 0.52),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.52),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // 7b. Pack 1: Zero-RAM Chromatic Critical Impact Edge Flash (works on all tiers!)
                  if (critEdgeFlash > 0.02)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CritImpactEdgeFlashPainter(
                            intensity: critEdgeFlash,
                            accentColor: profile.primaryColor,
                          ),
                        ),
                      ),
                    ),

                  // 8. Multi-Target Metallic Damage Callouts + Live Tactical Skill Banner!
                  if (popupDamage != null)
                    _CombatDamageCallout(
                      damage: popupDamage,
                      isCritical: popupCrit,
                      onEnemy: popupOnEnemy,
                      comboCount:
                          popupOnEnemy ? (activeBeat?.comboCount ?? 1) : 1,
                      progress: popupT,
                      anchorX: popupAnchor.dx,
                      headTopY: popupAnchor.dy,
                      stageWidth: w,
                      accentColor: profile.primaryColor,
                    ),
                  if (secondaryPopupDamage != null &&
                      secondaryPopupAnchor != null)
                    _CombatDamageCallout(
                      damage: secondaryPopupDamage,
                      isCritical: false,
                      onEnemy: true,
                      comboCount: 1,
                      progress: (popupT * 1.06).clamp(0.0, 1.0),
                      anchorX: secondaryPopupAnchor.dx,
                      headTopY: secondaryPopupAnchor.dy,
                      stageWidth: w,
                      accentColor: profile.secondaryColor,
                    ),
                  if (manualActive &&
                      manualPopupDamage != null &&
                      _activeTacticalCmd != null)
                    _TacticalStrikeCallout(
                      command: _activeTacticalCmd!,
                      damage: manualPopupDamage,
                      progress: manualPopupT,
                      anchorX: manualPopupAnchor.dx,
                      headTopY: manualPopupAnchor.dy,
                      stageWidth: w,
                    ),

                  // 9. Top Stage Duel HUD: Hero Vitality vs Multi-Mob Pack & Boss Health Bar
                  Positioned(
                    top: widget.hudTopInset,
                    left: 12,
                    right: 12,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _StageDuelHudHeader(
                          profile: profile,
                          playerName: widget.playerName,
                          playerLevel: widget.playerLevel,
                          heroHp: heroHpRatio,
                          enemyHp: packHpRatio,
                          alivePackCount: aliveMobCount,
                          totalPackCount: pack.length,
                        ),
                      ),
                    ),
                  ),

                  // 10. Optional Centered Stage Overlay
                  if (widget.overlayChild != null)
                    Positioned.fill(
                      child: widget.overlayChild!,
                    ),
                ],
              ),
            );

            if (isFighting && widget.onArenaStrikeTap != null) {
              return GestureDetector(
                key: const Key('dungeon_arena_tap_target'),
                behavior: HitTestBehavior.translucent,
                onTap: () => widget.onArenaStrikeTap!(isRingSweetSpot),
                child: chamberStack,
              );
            }
            return chamberStack;
          },
        );
      },
    );

    if (widget.fullscreen) {
      return ColoredBox(
        color: profile.deepSurface,
        child: stageBody,
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: profile.deepSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: profile.primaryColor.withValues(
            alpha: profile.isBoss ? 0.72 : 0.48,
          ),
          width: profile.isBoss ? 1.8 : 1.3,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: stageBody,
    );
  }

  Widget _buildHeroFighter({
    required double h,
    required double fighterBaseH,
    required double locoRad,
    required double amb,
    required bool isDefeat,
    required _EntityRuntimeState state,
    required Color accentColor,
  }) {
    final Color classAura = switch (widget.characterClass) {
      CharacterClass.shadow => const Color(0xFFC084FC),
      CharacterClass.alchemist => const Color(0xFF34D399),
      _ => const Color(0xFFFB923C),
    };

    return Positioned(
      left: state.liveX - fighterBaseH * 0.50,
      bottom: (h - state.liveGroundY) - 4,
      width: fighterBaseH,
      height: fighterBaseH,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isDefeat ? 0.46 : 1.0,
          child: Transform.rotate(
            alignment: Alignment.bottomCenter,
            angle: state.tiltRad,
            child: Transform.scale(
              alignment: Alignment.bottomCenter,
              scale: state.scale,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  Positioned(
                    bottom: fighterBaseH * 0.10,
                    child: Container(
                      width: fighterBaseH * 0.82,
                      height: fighterBaseH * 0.82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            classAura.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DungeonSkeletalFighter(
                      assetPath: _combatHeroAsset,
                      fallbackAssetPath: widget.characterAsset,
                      facingRight: true,
                      walkPhase: _heroWalkPhase,
                      strideIntensity: state.strideIntensity,
                      idlePhase: amb,
                      attackSlashProgress: state.attackSlashProgress,
                      hitRecoil: state.hitRecoil,
                      specularFlash: state.specularFlash,
                      accentColor: classAura,
                      secondaryColor: accentColor,
                      warmHitBias: true,
                      afterimageAlpha: state.afterimageAlpha,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobPackFighter({
    required DungeonBattleProfile profile,
    required DungeonMobPackMember member,
    required _EntityRuntimeState state,
    required double h,
    required double spriteH,
    required double locoRad,
    required double amb,
    required bool isVictory,
  }) {
    final double continuousMobPhase =
        (member.slotIndex < _mobWalkPhases.length
                ? _mobWalkPhases[member.slotIndex]
                : locoRad) +
            member.phaseSeed * math.pi * 2.0;
    final double hoverLift = member.hover ? 10.0 : 0.0;
    final double boxW = spriteH * 1.08;

    return Positioned(
      left: state.liveX - boxW * 0.5,
      bottom: (h - state.liveGroundY) - 4 + hoverLift,
      width: boxW,
      height: spriteH,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 380),
          opacity: isVictory ? 0.0 : 1.0,
          child: Transform.rotate(
            alignment: Alignment.bottomCenter,
            angle: state.tiltRad,
            child: Transform.scale(
              alignment: Alignment.bottomCenter,
              scale: state.scale,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  // Menacing Pack / Boss backlight aura
                  Positioned(
                    bottom: spriteH * 0.08,
                    child: Container(
                      width: spriteH * (member.isLeader ? 1.02 : 0.76),
                      height: spriteH * (member.isLeader ? 1.02 : 0.76),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            profile.primaryColor.withValues(
                              alpha: member.isLeader
                                  ? (member.isBoss ? 0.30 : 0.20)
                                  : 0.11,
                            ),
                            profile.secondaryColor.withValues(
                              alpha: member.isLeader ? 0.08 : 0.03,
                            ),
                            Colors.transparent,
                          ],
                          stops: const <double>[0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // 60 FPS Segmented Monster Skeletal Rig
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: spriteH,
                    child: DungeonSkeletalFighter(
                      assetPath: member.spriteAsset,
                      facingRight: false,
                      walkPhase: continuousMobPhase,
                      strideIntensity: state.strideIntensity,
                      idlePhase: (amb + member.phaseSeed) % 1.0,
                      attackSlashProgress: state.attackSlashProgress,
                      hitRecoil: state.hitRecoil,
                      specularFlash: state.specularFlash,
                      accentColor: profile.primaryColor,
                      secondaryColor: profile.secondaryColor,
                      hover: member.hover,
                      tintColor: member.tintColor,
                      tintStrength: member.tintStrength,
                      deathProgress: state.deathProgress,
                      afterimageAlpha: state.afterimageAlpha,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobOverheadMiniBar extends StatelessWidget {
  const _MobOverheadMiniBar({
    required this.member,
    required this.hpRatio,
    required this.primary,
    required this.secondary,
  });

  final DungeonMobPackMember member;
  final double hpRatio;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final double barW = member.isLeader ? 58.0 : 42.0;
    final double barH = member.isLeader ? 5.5 : 4.2;
    final Color borderCol = member.isBoss
        ? const Color(0xFFFFD700)
        : (member.isLeader ? primary : Colors.white.withValues(alpha: 0.42));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xCC060911),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderCol.withValues(alpha: 0.72),
              width: 0.8,
            ),
          ),
          child: Text(
            member.roleLabel,
            style: TextStyle(
              color: member.isBoss
                  ? const Color(0xFFFFD700)
                  : (member.isLeader ? primary : Colors.white.withValues(alpha: 0.86)),
              fontSize: member.isLeader ? 7.5 : 6.8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: barW,
          height: barH,
          decoration: BoxDecoration(
            color: const Color(0xD905070E),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: borderCol.withValues(alpha: 0.68),
              width: 0.8,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: hpRatio.clamp(0.0, 1.0),
                heightFactor: 1.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: member.isBoss
                          ? const <Color>[Color(0xFFDC2626), Color(0xFFFFB800)]
                          : <Color>[primary, secondary],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Hand-Painted AAA Combat Slash, Claw, Arcane Burst & Spark Impact Overlay
// =============================================================================
class _PaintedCombatVfxOverlay extends StatelessWidget {
  const _PaintedCombatVfxOverlay({
    required this.progress,
    required this.isHeroAttacking,
    required this.isCritical,
    required this.heroClass,
    required this.monsterSlashType,
    required this.primaryColor,
    required this.secondaryColor,
    required this.targetCenter,
    required this.targetHeight,
  });

  final double progress;
  final bool isHeroAttacking;
  final bool isCritical;
  final CharacterClass? heroClass;
  final DungeonSlashType monsterSlashType;
  final Color primaryColor;
  final Color secondaryColor;
  final Offset targetCenter;
  final double targetHeight;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0);
    if (t <= 0.0 || t >= 1.0) return const SizedBox.shrink();

    final double slashAlpha = t < 0.12
        ? (t / 0.12)
        : math.pow(1.0 - ((t - 0.12) / 0.88), 1.45).toDouble();
    final double shockT = (t / 0.68).clamp(0.0, 1.0);
    final double shockAlpha = shockT < 0.14
        ? (shockT / 0.14)
        : math.pow(1.0 - ((shockT - 0.14) / 0.86), 1.75).toDouble();

    String mainAsset;
    bool flipX = false;
    double startAngle = 0.0;
    double endAngle = 0.0;
    Color lightGlowColor;
    ColorFilter? elementalRemix;

    if (isHeroAttacking) {
      switch (heroClass) {
        case CharacterClass.shadow:
          mainAsset = 'assets/dungeon/vfx_shadow_twin_slash.png';
          startAngle = -0.14;
          endAngle = 0.10;
          lightGlowColor = const Color(0xFF34D399);
        case CharacterClass.alchemist:
          mainAsset = 'assets/dungeon/vfx_arcane_alchemist_blast.png';
          startAngle = -0.18;
          endAngle = 0.28;
          lightGlowColor = const Color(0xFFF59E0B);
        case CharacterClass.warrior:
        case null:
          mainAsset = 'assets/dungeon/vfx_sword_cleave_fire.png';
          flipX = true;
          startAngle = -0.26;
          endAngle = 0.16;
          lightGlowColor =
              isCritical ? const Color(0xFFFFB800) : const Color(0xFFFB923C);
      }
    } else {
      lightGlowColor = primaryColor;
      switch (monsterSlashType) {
        case DungeonSlashType.savageClaw:
          mainAsset = 'assets/dungeon/vfx_monster_savage_claw.png';
          startAngle = 0.10;
          endAngle = -0.08;
        case DungeonSlashType.venomSplash:
          mainAsset = 'assets/dungeon/vfx_monster_savage_claw.png';
          startAngle = 0.12;
          endAngle = -0.10;
          elementalRemix =
              _buildElementalMatrix(const Color(0xFF84CC16), 0.72);
        case DungeonSlashType.heavyCleave:
          mainAsset = 'assets/dungeon/vfx_sword_cleave_fire.png';
          flipX = false;
          startAngle = 0.24;
          endAngle = -0.16;
        case DungeonSlashType.elementalBolt:
          mainAsset = 'assets/dungeon/vfx_arcane_alchemist_blast.png';
          startAngle = 0.20;
          endAngle = -0.24;
          elementalRemix = _buildElementalMatrix(primaryColor, 0.65);
        case DungeonSlashType.necroticScythe:
          mainAsset = 'assets/dungeon/vfx_sword_cleave_fire.png';
          flipX = false;
          startAngle = 0.34;
          endAngle = -0.12;
          elementalRemix = _buildElementalMatrix(primaryColor, 0.70);
        case DungeonSlashType.cosmicRift:
          mainAsset = 'assets/dungeon/vfx_shadow_twin_slash.png';
          startAngle = 0.16;
          endAngle = -0.14;
          elementalRemix = _buildElementalMatrix(primaryColor, 0.62);
      }
    }

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final double baseSize =
        (targetHeight * (isCritical ? 1.28 : 1.06)).clamp(165.0, 350.0);

    // Ultra-fast zero-bitmap vector slash arc + shock ring on Low tier!
    if (!gfx.enablePaintedBattleVfxBitmaps) {
      return Positioned(
        left: targetCenter.dx - baseSize * 0.55,
        top: targetCenter.dy - baseSize * 0.55,
        width: baseSize * 1.10,
        height: baseSize * 1.10,
        child: IgnorePointer(
          child: CustomPaint(
            painter: _FastVectorCombatSlashPainter(
              progress: t,
              color: lightGlowColor,
              secondaryColor: secondaryColor,
              flipX: !isHeroAttacking,
              isCritical: isCritical,
            ),
          ),
        ),
      );
    }

    final double sweepCurve = Curves.easeOutQuart.transform(t);
    final double liveScale = 0.74 + 0.42 * sweepCurve;
    final double liveAngle = startAngle + (endAngle - startAngle) * sweepCurve;
    final double shockScale = 0.46 +
        (isCritical ? 0.90 : 0.68) * Curves.easeOutCubic.transform(shockT);

    Widget slashSprite = Image.asset(
      mainAsset,
      cacheWidth: 384,
      opacity: AlwaysStoppedAnimation<double>(slashAlpha.clamp(0.0, 1.0)),
      fit: BoxFit.contain,
      filterQuality: gfx.filterQuality,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    if (elementalRemix != null) {
      slashSprite = ColorFiltered(
        colorFilter: elementalRemix,
        child: slashSprite,
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: targetCenter.dx - baseSize * 0.85,
              top: targetCenter.dy - baseSize * 0.85,
              width: baseSize * 1.70,
              height: baseSize * 1.70,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      Colors.white
                          .withValues(alpha: 0.24 * shockAlpha.clamp(0.0, 1.0)),
                      lightGlowColor
                          .withValues(alpha: 0.30 * slashAlpha.clamp(0.0, 1.0)),
                      Colors.transparent,
                    ],
                    stops: const <double>[0.0, 0.38, 1.0],
                  ),
                ),
              ),
            ),
            if (shockAlpha > 0.01)
              Positioned(
                left: targetCenter.dx - baseSize * 0.52,
                top: targetCenter.dy - baseSize * 0.52,
                width: baseSize * 1.04,
                height: baseSize * 1.04,
                child: Transform.scale(
                  scale: shockScale,
                  child: Image.asset(
                    'assets/dungeon/vfx_impact_shockwave.png',
                    cacheWidth: 320,
                    opacity:
                        AlwaysStoppedAnimation<double>(shockAlpha.clamp(0.0, 1.0)),
                    fit: BoxFit.contain,
                    filterQuality: gfx.filterQuality,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (slashAlpha > 0.01)
              Positioned(
                left: targetCenter.dx - baseSize * 0.5,
                top: targetCenter.dy - baseSize * 0.5,
                width: baseSize,
                height: baseSize,
                child: Transform.rotate(
                  angle: liveAngle,
                  child: Transform.scale(
                    scaleX: flipX ? -liveScale : liveScale,
                    scaleY: liveScale,
                    child: slashSprite,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  ColorFilter _buildElementalMatrix(Color target, double strength) {
    final double tr = (target.r * 255.0) / 255.0;
    final double tg = (target.g * 255.0) / 255.0;
    final double tb = (target.b * 255.0) / 255.0;
    final double keep = 1.0 - strength;
    return ColorFilter.matrix(<double>[
      keep + strength * tr * 1.15, strength * tr * 0.45, strength * tr * 0.15, 0, 0,
      strength * tg * 0.35, keep + strength * tg * 1.15, strength * tg * 0.20, 0, 0,
      strength * tb * 0.35, strength * tb * 0.45, keep + strength * tb * 1.15, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }
}

class _FastVectorCombatSlashPainter extends CustomPainter {
  const _FastVectorCombatSlashPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.flipX,
    required this.isCritical,
  });

  final double progress;
  final Color color;
  final Color secondaryColor;
  final bool flipX;
  final bool isCritical;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.clamp(0.0, 1.0);
    final double alpha = (1.0 - t).clamp(0.0, 1.0);
    if (alpha <= 0.02) return;

    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    final double radius = size.shortestSide * (0.24 + 0.24 * t);

    // Impact ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.65 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCritical ? 3.5 : 2.2,
    );

    // Sweeping crescent slash arc
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (flipX) {
      canvas.scale(-1.0, 1.0);
    }
    final Rect arcRect =
        Rect.fromCircle(center: Offset.zero, radius: size.shortestSide * 0.40);
    final double startAng = -1.25 + t * 0.65;
    canvas.drawArc(
      arcRect,
      startAng,
      1.75,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.88 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isCritical ? 7.0 : 5.0,
    );
    canvas.drawArc(
      arcRect.deflate(2.5),
      startAng + 0.12,
      1.45,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2,
    );
    if (isCritical) {
      canvas.drawArc(
        arcRect.inflate(6.0),
        startAng - 0.15,
        1.55,
        false,
        Paint()
          ..color = secondaryColor.withValues(alpha: 0.65 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.0,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FastVectorCombatSlashPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// =============================================================================
// Crisp Obsidian-Stroked Metallic Dark-Fantasy Damage & Combo Callout
// =============================================================================
class _CombatDamageCallout extends StatelessWidget {
  const _CombatDamageCallout({
    required this.damage,
    required this.isCritical,
    required this.onEnemy,
    required this.comboCount,
    required this.progress,
    required this.anchorX,
    required this.headTopY,
    required this.stageWidth,
    required this.accentColor,
  });

  final int damage;
  final bool isCritical;
  final bool onEnemy;
  final int comboCount;
  final double progress;
  final double anchorX;
  final double headTopY;
  final double stageWidth;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final double t = progress.clamp(0.0, 1.0);
    final double opacity =
        (1.0 - ((t - 0.68) / 0.32).clamp(0.0, 1.0)).clamp(0.0, 1.0);

    final double popScale = t < 0.16
        ? (0.85 + 0.58 * Curves.easeOutBack.transform(t / 0.16))
        : (1.43 -
            0.43 *
                Curves.easeOutCubic
                    .transform(((t - 0.16) / 0.30).clamp(0.0, 1.0)));

    final double floatY = Curves.easeOutCubic.transform(t) * 32.0;
    final String formatted = _formatThousands(damage);
    final List<Color> gradientColors = onEnemy
        ? (isCritical
            ? const <Color>[
                Color(0xFFFFFBEB),
                Color(0xFFFACC15),
                Color(0xFFEA580C),
              ]
            : const <Color>[
                Color(0xFFFFFFFF),
                Color(0xFFE2E8F0),
                Color(0xFF94A3B8),
              ])
        : const <Color>[
            Color(0xFFFFE4E6),
            Color(0xFFFB7185),
            Color(0xFFE11D48),
          ];

    final double fontSize = isCritical ? 27.0 : 21.0;
    final String? badgeLabel = isCritical
        ? (onEnemy
            ? (comboCount >= 2 ? '${comboCount}x KRİTİK KOMBO!' : 'KRİTİK DARBE!')
            : 'SÜRÜ DARBESİ!')
        : (onEnemy && comboCount >= 3 ? '${comboCount}x KOMBO!' : null);

    const double calloutWidth = 204.0;
    final double clampedLeft = (anchorX - calloutWidth * 0.5).clamp(
      10.0,
      math.max(10.0, stageWidth - calloutWidth - 10.0),
    );

    return Positioned(
      left: clampedLeft,
      top: headTopY - floatY,
      width: calloutWidth,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: popScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (badgeLabel != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD9070A12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (onEnemy
                                ? const Color(0xFFFACC15)
                                : const Color(0xFFFB7185))
                            .withValues(alpha: 0.78),
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: onEnemy
                            ? const Color(0xFFFDE047)
                            : const Color(0xFFFDA4AF),
                        fontSize: 9.0,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Text(
                        '-$formatted',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 4.5
                            ..strokeJoin = StrokeJoin.round
                            ..color = const Color(0xFF05070C),
                          shadows: <Shadow>[
                            const Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                            Shadow(
                              color: (onEnemy
                                      ? const Color(0xFFF59E0B)
                                      : accentColor)
                                  .withValues(alpha: 0.55),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                      ),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (Rect bounds) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradientColors,
                        ).createShader(bounds),
                        child: Text(
                          '-$formatted',
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.5,
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
    );
  }

  static String _formatThousands(int value) {
    final String s = value.abs().toString();
    if (s.length <= 3) return s;
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StageDuelHudHeader extends StatelessWidget {
  const _StageDuelHudHeader({
    required this.profile,
    required this.playerName,
    required this.playerLevel,
    required this.heroHp,
    required this.enemyHp,
    required this.alivePackCount,
    required this.totalPackCount,
  });

  final DungeonBattleProfile profile;
  final String playerName;
  final int playerLevel;
  final double heroHp;
  final double enemyHp;
  final int alivePackCount;
  final int totalPackCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _FighterBarCard(
            alignRight: false,
            name: playerName,
            subtitle: 'LV.$playerLevel KAHRAMAN',
            hpRatio: heroHp,
            barStart: const Color(0xFF059669),
            barEnd: const Color(0xFF34D399),
            borderColor: const Color(0xFF34D399),
            isBoss: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xD9070A12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (profile.isBoss
                        ? const Color(0xFFFFD700)
                        : profile.primaryColor)
                    .withValues(alpha: 0.68),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: profile.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  profile.isBoss ? 'BOSS' : 'SÜRÜ',
                  style: TextStyle(
                    color: profile.isBoss
                        ? const Color(0xFFFFD700)
                        : profile.primaryColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.9,
                  ),
                ),
                Text(
                  '$alivePackCount/$totalPackCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _FighterBarCard(
            alignRight: true,
            name: profile.enemyName,
            subtitle:
                'SÜRÜ $alivePackCount/$totalPackCount • ${profile.enemyElementLabel.trim()}',
            hpRatio: enemyHp,
            barStart: profile.isBoss
                ? const Color(0xFFDC2626)
                : profile.primaryColor,
            barEnd: profile.isBoss
                ? const Color(0xFFFFB800)
                : profile.secondaryColor,
            borderColor: profile.isBoss
                ? const Color(0xFFFFD700)
                : profile.primaryColor,
            isBoss: profile.isBoss,
          ),
        ),
      ],
    );
  }
}

class _FighterBarCard extends StatelessWidget {
  const _FighterBarCard({
    required this.alignRight,
    required this.name,
    required this.subtitle,
    required this.hpRatio,
    required this.barStart,
    required this.barEnd,
    required this.borderColor,
    required this.isBoss,
  });

  final bool alignRight;
  final String name;
  final String subtitle;
  final double hpRatio;
  final Color barStart;
  final Color barEnd;
  final Color borderColor;
  final bool isBoss;

  @override
  Widget build(BuildContext context) {
    final double clamped = hpRatio.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC070A12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withValues(alpha: isBoss ? 0.78 : 0.45),
          width: isBoss ? 1.4 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: <Widget>[
              if (isBoss && !alignRight) ...<Widget>[
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 12,
                  color: Color(0xFFFFD700),
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: alignRight ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (isBoss && alignRight) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 13,
                  color: Color(0xFFFFD700),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: borderColor.withValues(alpha: 0.92),
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: isBoss ? 8.5 : 7.0,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: clamped, end: clamped),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutQuart,
                builder: (BuildContext context, double ghostRatio, _) {
                  final double trail = math.max(clamped, ghostRatio);
                  return Stack(
                    alignment: alignRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    children: <Widget>[
                      Container(color: Colors.white.withValues(alpha: 0.12)),
                      FractionallySizedBox(
                        widthFactor: trail.clamp(0.0, 1.0),
                        heightFactor: 1.0,
                        child: const ColoredBox(color: Color(0xCCFEF08A)),
                      ),
                      FractionallySizedBox(
                        widthFactor: clamped,
                        heightFactor: 1.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[barStart, barEnd],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriticalTimingReticlePainter extends CustomPainter {
  const _CriticalTimingReticlePainter({
    required this.ringPhase,
    required this.isSweetSpot,
    required this.accentColor,
  });

  final double ringPhase;
  final bool isSweetSpot;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    const double targetRadius = 24.0;
    final double outerRadius = ui.lerpDouble(56.0, 18.0, ringPhase)!;
    final Color ringColor = isSweetSpot
        ? const Color(0xFFFFE566)
        : const Color(0xFFFBBF24);

    // Sweet-spot inner target ring
    canvas.drawCircle(
      center,
      targetRadius,
      Paint()
        ..color = (isSweetSpot
                ? const Color(0xFFFFE566)
                : const Color(0xFFFDE68A))
            .withValues(alpha: isSweetSpot ? 0.94 : 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSweetSpot ? 2.8 : 1.7,
    );

    if (isSweetSpot) {
      canvas.drawCircle(
        center,
        targetRadius + 4.0,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      );
    }

    // Converging outer timing ring
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = ringColor.withValues(alpha: isSweetSpot ? 0.95 : 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSweetSpot ? 3.0 : 2.0,
    );

    // 4 tactical crosshair ticks
    final Paint tickPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.78)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final double ang = i * (math.pi * 0.5) + math.pi * 0.25;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(ang) * (targetRadius - 5),
          center.dy + math.sin(ang) * (targetRadius - 5),
        ),
        Offset(
          center.dx + math.cos(ang) * (targetRadius + 5),
          center.dy + math.sin(ang) * (targetRadius + 5),
        ),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CriticalTimingReticlePainter oldDelegate) {
    return oldDelegate.ringPhase != ringPhase ||
        oldDelegate.isSweetSpot != isSweetSpot;
  }
}

class _TacticalStrikeCallout extends StatelessWidget {
  const _TacticalStrikeCallout({
    required this.command,
    required this.damage,
    required this.progress,
    required this.anchorX,
    required this.headTopY,
    required this.stageWidth,
  });

  final DungeonTacticalCommand command;
  final int damage;
  final double progress;
  final double anchorX;
  final double headTopY;
  final double stageWidth;

  @override
  Widget build(BuildContext context) {
    final double rise = Curves.easeOutCubic.transform(progress) * 48.0;
    final double opacity = progress < 0.72
        ? 1.0
        : ((1.0 - progress) / 0.28).clamp(0.0, 1.0);
    final double scale = progress < 0.18
        ? ui.lerpDouble(0.72, 1.24, progress / 0.18)!
        : ui.lerpDouble(1.24, 1.0, ((progress - 0.18) / 0.35).clamp(0.0, 1.0))!;
    final ({String grade, Color color}) rank =
        resolveDungeonStyleRank(command.comboStreak);

    const double calloutWidth = 220.0;
    final double clampedLeft = (anchorX - calloutWidth * 0.5).clamp(
      10.0,
      math.max(10.0, stageWidth - calloutWidth - 10.0),
    );

    return Positioned(
      left: clampedLeft,
      top: headTopY - rise - 26,
      width: calloutWidth,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEB070A14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: rank.color, width: 1.25),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: rank.color.withValues(alpha: 0.48),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    '${command.skillTitle} • ${rank.grade} x${command.comboStreak}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: rank.color,
                      fontSize: 9.8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  command.isCritical ? '-$damage!' : '-$damage',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: command.isCritical
                        ? const Color(0xFFFEF08A)
                        : Colors.white,
                    fontSize: command.isCritical ? 25 : 20,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.5,
                    shadows: const <Shadow>[
                      Shadow(color: Color(0xFFEA580C), blurRadius: 16),
                      Shadow(color: Colors.black, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pack 1: Class-signature procedural tactical skill VFX:
/// - `warrior`: Molten ground fissures + expanding golden-orange seismic shockwave
/// - `shadow`: Arena shadow-veil dim + twin neon-violet & white-hot X cross-slashes
/// - `alchemist`: Arcane flask shatter + bubbling emerald/amethyst floor pool
class _ClassSignatureSkillVfxPainter extends CustomPainter {
  const _ClassSignatureSkillVfxPainter({
    required this.progress,
    required this.heroClass,
    required this.actionType,
    required this.targetCenter,
    required this.groundY,
    required this.isLowTier,
  });

  final double progress;
  final CharacterClass? heroClass;
  final DungeonTacticalActionType actionType;
  final Offset targetCenter;
  final double groundY;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    final double p = progress.clamp(0.0, 1.0);
    final double fade = (1.0 - p).clamp(0.0, 1.0);
    if (fade <= 0.01) return;

    final double scaleMult =
        actionType == DungeonTacticalActionType.ultimate ? 1.32 : 1.0;

    switch (heroClass) {
      case CharacterClass.shadow:
        // Brief shadow-step chamber dim on first 35% of cast
        if (!isLowTier && p < 0.38) {
          final double dimA = (1.0 - p / 0.38) * 0.24;
          canvas.drawRect(
            Offset.zero & size,
            Paint()..color = const Color(0xFF090314).withValues(alpha: dimA),
          );
        }
        // Twin neon-violet & white-hot X execution slashes
        final double span = (68.0 + p * 74.0) * scaleMult;
        final Paint glowSlash = Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 10.0 * fade
          ..color = const Color(0xFFC06CFF).withValues(alpha: fade * 0.78);
        final Paint coreSlash = Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.2 * fade
          ..color = Colors.white.withValues(alpha: fade * 0.95);
        final Offset a1 = targetCenter + Offset(-span, -span * 0.78);
        final Offset a2 = targetCenter + Offset(span, span * 0.78);
        final Offset b1 = targetCenter + Offset(-span, span * 0.78);
        final Offset b2 = targetCenter + Offset(span, -span * 0.78);
        canvas.drawLine(a1, a2, glowSlash);
        canvas.drawLine(b1, b2, glowSlash);
        canvas.drawLine(a1, a2, coreSlash);
        canvas.drawLine(b1, b2, coreSlash);
        break;

      case CharacterClass.alchemist:
        // Bubbling emerald-amethyst alchemical pool on chamber floor + arcane ring
        final Offset floorPos = Offset(targetCenter.dx, groundY + 4.0);
        final Rect poolRect = Rect.fromCenter(
          center: floorPos,
          width: (110.0 + p * 120.0) * scaleMult,
          height: (30.0 + p * 34.0) * scaleMult,
        );
        canvas.drawOval(
          poolRect,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: <Color>[
                const Color(0xFF34D399).withValues(alpha: fade * 0.65),
                const Color(0xFFA855F7).withValues(alpha: fade * 0.38),
                Colors.transparent,
              ],
            ).createShader(poolRect),
        );
        canvas.drawOval(
          poolRect,
          Paint()
            ..blendMode = BlendMode.plus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * fade
            ..color = const Color(0xFF6EE7B7).withValues(alpha: fade * 0.85),
        );
        if (!isLowTier) {
          final Paint orbPaint = Paint()..blendMode = BlendMode.plus;
          for (int i = 0; i < 7; i++) {
            final double ang = i * 0.9 + p * 4.0;
            final double bx =
                floorPos.dx + math.cos(ang) * poolRect.width * 0.34;
            final double by = floorPos.dy - (p * 78.0) - (i % 3) * 14.0;
            orbPaint.color = (i.isEven
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFFD8B4FE))
                .withValues(alpha: fade * 0.82);
            canvas.drawCircle(Offset(bx, by), 4.2 * fade, orbPaint);
          }
        }
        break;

      case CharacterClass.warrior:
      case null:
        // Seismic shockwave ring + jagged molten fissure lines radiating on flagstones
        final Offset impactFloor = Offset(targetCenter.dx, groundY + 4.0);
        final Rect shockOval = Rect.fromCenter(
          center: impactFloor,
          width: (96.0 + p * 150.0) * scaleMult,
          height: (26.0 + p * 40.0) * scaleMult,
        );
        canvas.drawOval(
          shockOval,
          Paint()
            ..blendMode = BlendMode.plus
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.8 * fade
            ..color = const Color(0xFFFB923C).withValues(alpha: fade * 0.88),
        );
        final Paint crackGlow = Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.4 * fade
          ..color = const Color(0xFFFBBF24).withValues(alpha: fade * 0.85);
        final int crackCount = isLowTier ? 3 : 5;
        for (int i = 0; i < crackCount; i++) {
          final double baseAng = -0.55 + (i / (crackCount - 1)) * 1.10;
          final double len = (48.0 + p * 84.0) * scaleMult;
          final Offset mid = Offset(
            impactFloor.dx + math.cos(baseAng) * len * 0.52,
            impactFloor.dy + math.sin(baseAng) * len * 0.22 + (i.isEven ? -5 : 5),
          );
          final Offset tip = Offset(
            impactFloor.dx + math.cos(baseAng) * len,
            impactFloor.dy + math.sin(baseAng) * len * 0.34,
          );
          final Path fissure = Path()
            ..moveTo(impactFloor.dx, impactFloor.dy)
            ..lineTo(mid.dx, mid.dy)
            ..lineTo(tip.dx, tip.dy);
          canvas.drawPath(fissure, crackGlow);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ClassSignatureSkillVfxPainter oldDelegate) {
    return (oldDelegate.progress - progress).abs() > 0.005 ||
        oldDelegate.heroClass != heroClass ||
        oldDelegate.actionType != actionType;
  }
}

/// Pack 1: Boss Slow-Mo Kill Cam Execution Cross-Flare & Rising Ember/Ash Dissolve.
class _BossKillCamDissolvePainter extends CustomPainter {
  const _BossKillCamDissolvePainter({
    required this.progress,
    required this.center,
    required this.primaryColor,
    required this.isLowTier,
  });

  final double progress;
  final Offset center;
  final Color primaryColor;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    final double p = progress.clamp(0.0, 1.0);
    final double fade = (1.0 - p).clamp(0.0, 1.0);
    if (fade <= 0.01) return;

    // Expanding execution ring + horizontal slash flare
    final double ringR = 28.0 + p * 145.0;
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2 * fade
        ..color = const Color(0xFFFFD56B).withValues(alpha: fade * 0.85),
    );
    canvas.drawLine(
      Offset(center.dx - 130.0 * (0.4 + p), center.dy),
      Offset(center.dx + 130.0 * (0.4 + p), center.dy),
      Paint()
        ..blendMode = BlendMode.plus
        ..strokeWidth = 3.5 * fade
        ..color = Colors.white.withValues(alpha: fade * 0.90),
    );

    // Rising boss ash/ember shards
    final int emberCount = isLowTier ? 8 : 18;
    final Paint emberPaint = Paint()..blendMode = BlendMode.plus;
    for (int i = 0; i < emberCount; i++) {
      final double ang = (i / emberCount) * math.pi * 2.0 + p * 1.4;
      final double spread = (18.0 + (i % 5) * 16.0) * (0.35 + p * 1.15);
      final double lift = p * (55.0 + (i % 4) * 26.0);
      final Offset pos = Offset(
        center.dx + math.cos(ang) * spread,
        center.dy + math.sin(ang) * spread * 0.55 - lift,
      );
      emberPaint.color = (i.isEven ? const Color(0xFFFFAE42) : primaryColor)
          .withValues(alpha: fade * 0.88);
      canvas.drawCircle(pos, (i % 3 == 0 ? 3.4 : 2.2) * fade, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BossKillCamDissolvePainter oldDelegate) {
    return (oldDelegate.progress - progress).abs() > 0.005;
  }
}

/// Pack 1: Zero-RAM Chromatic Critical Edge Flash (4 crisp border gradients, 0 blur).
class _CritImpactEdgeFlashPainter extends CustomPainter {
  const _CritImpactEdgeFlashPainter({
    required this.intensity,
    required this.accentColor,
  });

  final double intensity;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double a = (intensity.clamp(0.0, 1.0) * 0.28);
    if (a <= 0.01 || size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          radius: 0.95,
          colors: <Color>[
            Colors.transparent,
            accentColor.withValues(alpha: a * 0.55),
            const Color(0xFFFFDF73).withValues(alpha: a),
          ],
          stops: const <double>[0.58, 0.85, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _CritImpactEdgeFlashPainter oldDelegate) {
    return (oldDelegate.intensity - intensity).abs() > 0.01;
  }
}

/// Pack 5: Real GLSL `shaders/gkk_heat_distortion.frag` thermal convection overlay
/// rendered on `High`/`Ultra` in Boss & Volcanic/Solar chambers.
class _GpuHeatDistortionPainter extends CustomPainter {
  const _GpuHeatDistortionPainter({
    required this.timeSec,
    required this.intensity,
  });

  final double timeSec;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ui.FragmentShader? shader =
        GpuShaderService.instance.createHeatDistortionShader(
      size: size,
      timeSec: timeSec,
      intensity: intensity,
    );
    if (shader == null) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GpuHeatDistortionPainter oldDelegate) {
    return (oldDelegate.timeSec - timeSec).abs() > 0.012 ||
        oldDelegate.intensity != intensity;
  }
}
