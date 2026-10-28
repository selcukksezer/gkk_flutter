import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/game_sfx_service.dart';
import '../../core/services/graphics_quality_service.dart';
import '../../models/inventory_model.dart';
import '../../models/moradon_models.dart';
import '../../models/player_model.dart';
import '../../providers/inventory_provider.dart';
import '../../screens/home/moradon/character_skeletal_rig.dart';
import '../../theme/app_colors.dart';

/// Live 1v1 2.5D Gladiator Colosseum Combat Stage powered by shared Moradon
/// character atlases and [paintSegmentedCharacterRig].
///
/// Used both in real multiplayer [PvpDuelBattleScreen] duels and in the
/// interactive [PvpColosseumHeroBanner] on [PvpScreen].
class PvpColosseumStage extends StatefulWidget {
  const PvpColosseumStage({
    super.key = const Key('pvp_colosseum_stage'),
    required this.leftName,
    required this.rightName,
    this.leftHp = 1.0,
    this.rightHp = 1.0,
    this.leftClassKey = 'golge',
    this.rightClassKey = 'savasci',
    this.leftEnhancement = 8,
    this.rightEnhancement = 8,
    this.exchangeSeq = 0,
    this.leftIsAttacker = false,
    this.isCritical = false,
    this.damageNumber,
    this.height = 208,
  });

  final String leftName;
  final String rightName;
  final double leftHp;
  final double rightHp;
  final String leftClassKey;
  final String rightClassKey;
  final int leftEnhancement;
  final int rightEnhancement;
  final int exchangeSeq;
  final bool leftIsAttacker;
  final bool isCritical;
  final int? damageNumber;
  final double height;

  @visibleForTesting
  static bool debugAnimateInTests = false;

  @override
  State<PvpColosseumStage> createState() => _PvpColosseumStageState();
}

class _PvpColosseumStageState extends State<PvpColosseumStage>
    with TickerProviderStateMixin {
  Map<String, ui.Image> _atlases = const <String, ui.Image>{};
  AnimationController? _idleCtrl;
  late final AnimationController _clashCtrl;
  int _comboStage = 0;

  static bool get _isTestBinding {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _clashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    GraphicsQualityService.instance.addListener(_onGfxChanged);
    _loadAtlases();
    _syncIdle();
  }

  Future<void> _loadAtlases() async {
    final Map<String, ui.Image> map =
        await GraphicsQualityService.instance.loadSharedCharacterAtlases();
    if (mounted) {
      setState(() => _atlases = map);
    }
  }

  void _onGfxChanged() {
    _loadAtlases();
    _syncIdle();
    if (mounted) setState(() {});
  }

  void _syncIdle() {
    final bool shouldTick =
        !GraphicsQualityService.instance.profile.isLow &&
        (!_isTestBinding || PvpColosseumStage.debugAnimateInTests);
    if (shouldTick) {
      _idleCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      );
      if (!_idleCtrl!.isAnimating) {
        _idleCtrl!.repeat();
      }
    } else {
      _idleCtrl?.stop();
    }
  }

  @override
  void didUpdateWidget(covariant PvpColosseumStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exchangeSeq != oldWidget.exchangeSeq && widget.exchangeSeq > 0) {
      _comboStage = (_comboStage + 1) % 3;
      _clashCtrl.forward(from: 0.0);
      unawaited(
        GameSfxService.instance.play(
          widget.isCritical ? GameSfx.criticalSlash : GameSfx.swordSlash,
        ),
      );
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_onGfxChanged);
    _idleCtrl?.dispose();
    _clashCtrl.dispose();
    super.dispose();
  }

  MoradonWeaponVisual _weaponForClass(String classKey) => switch (classKey) {
        'golge' => MoradonWeaponVisual.twilightFang,
        'simyaci' => MoradonWeaponVisual.aetherStaff,
        _ => MoradonWeaponVisual.crimsonAxe,
      };

  Color _glowForFighter(int enh, Color fallback) {
    if (enh >= 10) return const Color(0xFFFF3860);
    if (enh >= 9) return const Color(0xFFFF9824);
    if (enh >= 8) return const Color(0xFF38E8FF);
    if (enh >= 7) return const Color(0xFF7CB8FF);
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final Listenable merged = Listenable.merge(<Listenable?>[
      _idleCtrl,
      _clashCtrl,
    ]);

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedBuilder(
          animation: merged,
          builder: (BuildContext context, _) {
            final double idleT = _idleCtrl?.value ?? 0.25;
            final bool clashing = _clashCtrl.isAnimating;
            final double rawT = clashing ? _clashCtrl.value : 0.0;
            // Pack 1 Hit-Stop hold during peak clash [0.30..0.41]
            final double cT = (clashing && rawT >= 0.30 && rawT <= 0.41)
                ? 0.34
                : rawT;

            final double lungeCurve = clashing
                ? math.sin(cT * math.pi).clamp(0.0, 1.0)
                : 0.0;
            final double shake = (clashing && cT >= 0.28)
                ? math.sin(cT * 52.0) *
                    (widget.isCritical ? 6.5 : 3.8) *
                    (1.0 - cT)
                : 0.0;

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double w = constraints.maxWidth;
                final double h = constraints.maxHeight;
                final double baseLeftX = w * 0.25;
                final double baseRightX = w * 0.75;
                final double span = baseRightX - baseLeftX;

                double leftX = baseLeftX;
                double rightX = baseRightX;
                double leftAtk = 0.0;
                double rightAtk = 0.0;
                double leftTilt = widget.leftHp <= 0.001 ? -0.36 : 0.0;
                double rightTilt = widget.rightHp <= 0.001 ? 0.36 : 0.0;

                if (clashing) {
                  if (widget.leftIsAttacker) {
                    leftX += span * 0.46 * lungeCurve;
                    rightX += 14.0 * lungeCurve;
                    leftAtk = cT;
                    rightTilt = 0.14 * lungeCurve;
                  } else {
                    rightX -= span * 0.46 * lungeCurve;
                    leftX -= 14.0 * lungeCurve;
                    rightAtk = cT;
                    leftTilt = -0.14 * lungeCurve;
                  }
                }

                final ui.Image? leftAtlas =
                    _atlases[widget.leftClassKey] ?? _atlases['golge'];
                final ui.Image? rightAtlas =
                    _atlases[widget.rightClassKey] ?? _atlases['savasci'];
                final Color leftGlow = _glowForFighter(
                  widget.leftEnhancement,
                  const Color(0xFFEF4444),
                );
                final Color rightGlow = _glowForFighter(
                  widget.rightEnhancement,
                  const Color(0xFF38BDF8),
                );

                final double fighterW = (h * 0.64).clamp(96.0, 146.0);
                final double fighterH = (h * 0.74).clamp(112.0, 168.0);
                final double groundBottom = h * 0.10;

                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      // 1. Dark-Gothic Obsidian Colosseum Backdrop & Torchlight Floor
                      CustomPaint(
                        painter: _ColosseumArenaPainter(
                          phase: idleT,
                          clashFlash: clashing && cT >= 0.26 && cT <= 0.58
                              ? (1.0 - (cT - 0.26) / 0.32)
                              : 0.0,
                          isCritical: widget.isCritical,
                          isLowTier: gfx.isLow,
                        ),
                      ),

                      // 2. Left Fighter (Challenger / Opponent)
                      Positioned(
                        left: leftX - fighterW * 0.5,
                        bottom: groundBottom,
                        width: fighterW,
                        height: fighterH,
                        child: Opacity(
                          opacity: widget.leftHp <= 0.001 ? 0.55 : 1.0,
                          child: Transform.rotate(
                            alignment: Alignment.bottomCenter,
                            angle: leftTilt,
                            child: leftAtlas != null
                                ? CustomPaint(
                                    painter: _ColosseumGladiatorPainter(
                                      atlas: leftAtlas,
                                      classKey: widget.leftClassKey,
                                      facingRight: true,
                                      idlePhase: idleT,
                                      glowColor: leftGlow,
                                      glowLevel: widget.leftEnhancement,
                                      weapon: _weaponForClass(
                                        widget.leftClassKey,
                                      ),
                                      attackProgress: leftAtk,
                                      comboStage: _comboStage,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    color: Colors.redAccent,
                                    size: 54,
                                  ),
                          ),
                        ),
                      ),

                      // 3. Right Fighter (Local Hero)
                      Positioned(
                        left: rightX - fighterW * 0.5,
                        bottom: groundBottom,
                        width: fighterW,
                        height: fighterH,
                        child: Opacity(
                          opacity: widget.rightHp <= 0.001 ? 0.55 : 1.0,
                          child: Transform.rotate(
                            alignment: Alignment.bottomCenter,
                            angle: rightTilt,
                            child: rightAtlas != null
                                ? CustomPaint(
                                    painter: _ColosseumGladiatorPainter(
                                      atlas: rightAtlas,
                                      classKey: widget.rightClassKey,
                                      facingRight: false,
                                      idlePhase: (idleT + 0.37) % 1.0,
                                      glowColor: rightGlow,
                                      glowLevel: widget.rightEnhancement,
                                      weapon: _weaponForClass(
                                        widget.rightClassKey,
                                      ),
                                      attackProgress: rightAtk,
                                      comboStage: _comboStage,
                                    ),
                                  )
                                : const Icon(
                                    Icons.shield_rounded,
                                    color: Colors.lightBlueAccent,
                                    size: 54,
                                  ),
                          ),
                        ),
                      ),

                      // 4. Weapon Clash Shockwave & Floating Damage Callout
                      if (clashing && cT >= 0.24)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ColosseumClashSparkPainter(
                                progress: ((cT - 0.24) / 0.76).clamp(0.0, 1.0),
                                center: Offset(
                                  widget.leftIsAttacker
                                      ? rightX - 18
                                      : leftX + 18,
                                  h - groundBottom - fighterH * 0.50,
                                ),
                                isCritical: widget.isCritical,
                              ),
                            ),
                          ),
                        ),

                      if (clashing &&
                          cT >= 0.24 &&
                          widget.damageNumber != null)
                        Positioned(
                          left: ((widget.leftIsAttacker ? rightX : leftX) - 60)
                              .clamp(8.0, math.max(8.0, w - 128.0)),
                          top: (h * 0.14 - cT * 18.0).clamp(6.0, h * 0.45),
                          width: 120,
                          child: IgnorePointer(
                            child: Text(
                              widget.isCritical
                                  ? '💥 -${widget.damageNumber}!'
                                  : '-${widget.damageNumber}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: widget.isCritical
                                    ? const Color(0xFFFEF08A)
                                    : Colors.white,
                                fontSize: widget.isCritical ? 19 : 15,
                                fontWeight: FontWeight.w900,
                                shadows: const <Shadow>[
                                  Shadow(color: Colors.black, blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 5. Overhead Compact Fighter Name + HP Bars
                      Positioned(
                        left: 10,
                        right: 10,
                        top: 8,
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: _MiniGladiatorHud(
                                name: widget.leftName,
                                hp: widget.leftHp,
                                color: const Color(0xFFEF4444),
                                alignRight: false,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.liquidGold.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              child: const Text(
                                '1v1',
                                style: TextStyle(
                                  color: AppColors.liquidGold,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _MiniGladiatorHud(
                                name: widget.rightName,
                                hp: widget.rightHp,
                                color: const Color(0xFF38BDF8),
                                alignRight: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Interactive 3D PvP Colosseum Showcase Banner mounted at the top of [PvpScreen].
class PvpColosseumHeroBanner extends ConsumerStatefulWidget {
  const PvpColosseumHeroBanner({
    super.key = const Key('pvp_colosseum_hero_banner'),
    required this.profile,
    required this.rivalName,
  });

  final PlayerProfile? profile;
  final String rivalName;

  @override
  ConsumerState<PvpColosseumHeroBanner> createState() =>
      _PvpColosseumHeroBannerState();
}

class _PvpColosseumHeroBannerState
    extends ConsumerState<PvpColosseumHeroBanner> {
  Timer? _sparTimer;
  int _exchangeSeq = 0;
  bool _leftIsAttacker = false;
  bool _isCritical = false;
  int? _dmg;
  double _leftHp = 1.0;
  double _rightHp = 1.0;

  @override
  void dispose() {
    _sparTimer?.cancel();
    super.dispose();
  }

  void _runExhibitionClash() {
    _sparTimer?.cancel();
    int step = 0;
    setState(() {
      _leftHp = 1.0;
      _rightHp = 1.0;
      _exchangeSeq++;
      _leftIsAttacker = false;
      _isCritical = true;
      _dmg = 420;
      _leftHp = 0.72;
    });
    _sparTimer = Timer.periodic(const Duration(milliseconds: 620), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      step++;
      if (step >= 4) {
        t.cancel();
        setState(() {
          _leftHp = 1.0;
          _rightHp = 1.0;
          _dmg = null;
        });
        return;
      }
      setState(() {
        _exchangeSeq++;
        _leftIsAttacker = step == 1;
        _isCritical = step >= 2;
        _dmg = step == 3 ? 685 : (step == 2 ? 510 : 290);
        if (_leftIsAttacker) {
          _rightHp = (_rightHp - 0.24).clamp(0.25, 1.0);
        } else {
          _leftHp = step == 3 ? 0.0 : (_leftHp - 0.36).clamp(0.08, 1.0);
        }
      });
    });
  }

  String _heroClassKey() => switch (widget.profile?.characterClass) {
        CharacterClass.shadow => 'golge',
        CharacterClass.alchemist => 'simyaci',
        _ => 'savasci',
      };

  @override
  Widget build(BuildContext context) {
    final Map<String, InventoryItem?> eq =
        ref.watch(inventoryProvider).equippedItems;
    int maxEnh = 0;
    for (final InventoryItem? i in eq.values) {
      if (i != null && i.enhancementLevel > maxEnh) {
        maxEnh = i.enhancementLevel;
      }
    }
    final String disp = widget.profile?.displayName ?? '';
    final String myName = disp.isNotEmpty
        ? disp
        : (widget.profile?.username ?? 'Kahraman');
    final String hClass = _heroClassKey();
    final String rClass = hClass == 'savasci' ? 'golge' : 'savasci';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0E1320),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.stadium_rounded,
                size: 16,
                color: AppColors.liquidGold,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MORADON 1v1 KOLEZYUM ARENASI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              InkWell(
                key: const Key('pvp_colosseum_spar_btn'),
                onTap: _runExhibitionClash,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.65),
                    ),
                  ),
                  child: const Text(
                    '⚔️ Gösteri Düellosu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PvpColosseumStage(
            height: 176,
            leftName: widget.rivalName,
            rightName: myName,
            leftHp: _leftHp,
            rightHp: _rightHp,
            leftClassKey: rClass,
            rightClassKey: hClass,
            leftEnhancement: math.max(7, maxEnh),
            rightEnhancement: math.max(7, maxEnh),
            exchangeSeq: _exchangeSeq,
            leftIsAttacker: _leftIsAttacker,
            isCritical: _isCritical,
            damageNumber: _dmg,
          ),
        ],
      ),
    );
  }
}

class _MiniGladiatorHud extends StatelessWidget {
  const _MiniGladiatorHud({
    required this.name,
    required this.hp,
    required this.color,
    required this.alignRight,
  });

  final String name;
  final double hp;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: hp.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColosseumArenaPainter extends CustomPainter {
  const _ColosseumArenaPainter({
    required this.phase,
    required this.clashFlash,
    required this.isCritical,
    required this.isLowTier,
  });

  final double phase;
  final double clashFlash;
  final bool isCritical;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    // Gothic crimson-obsidian sky & wall arch backdrop
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF1F0A14),
            Color(0xFF121828),
            Color(0xFF1C1624),
          ],
          stops: <double>[0.0, 0.58, 1.0],
        ).createShader(full),
    );

    // Background Colosseum stone arches
    final Paint archPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (int i = 0; i < 4; i++) {
      final double ax = size.width * (0.14 + i * 0.24);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(ax, size.height * 0.52),
          width: size.width * 0.18,
          height: size.height * 0.44,
        ),
        math.pi,
        math.pi,
        false,
        archPaint,
      );
    }

    // 2.5D Elliptical Arena Combat Ring
    final Rect sandRing = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.86),
      width: size.width * 0.88,
      height: size.height * 0.34,
    );
    canvas.drawOval(
      sandRing,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFF2D2235),
            const Color(0xFF141826),
          ],
        ).createShader(sandRing),
    );
    canvas.drawOval(
      sandRing,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.42),
    );

    // Twin arena braziers on flanks
    if (!isLowTier) {
      final double fl = 0.85 + 0.15 * math.sin(phase * math.pi * 4);
      for (final double xf in const <double>[0.10, 0.90]) {
        final Offset tPos = Offset(size.width * xf, size.height * 0.46);
        final Rect glow = Rect.fromCenter(center: tPos, width: 76, height: 76);
        canvas.drawOval(
          glow,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: <Color>[
                const Color(0xFFFB923C).withValues(alpha: 0.36 * fl),
                Colors.transparent,
              ],
            ).createShader(glow),
        );
      }
    }

    if (clashFlash > 0.01) {
      canvas.drawRect(
        full,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = (isCritical
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFEF4444))
              .withValues(alpha: clashFlash * 0.16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ColosseumArenaPainter oldDelegate) {
    return (oldDelegate.phase - phase).abs() > 0.01 ||
        (oldDelegate.clashFlash - clashFlash).abs() > 0.01;
  }
}

class _ColosseumGladiatorPainter extends CustomPainter {
  const _ColosseumGladiatorPainter({
    required this.atlas,
    required this.classKey,
    required this.facingRight,
    required this.idlePhase,
    required this.glowColor,
    required this.glowLevel,
    required this.weapon,
    required this.attackProgress,
    required this.comboStage,
  });

  final ui.Image atlas;
  final String classKey;
  final bool facingRight;
  final double idlePhase;
  final Color glowColor;
  final int glowLevel;
  final MoradonWeaponVisual weapon;
  final double attackProgress;
  final int comboStage;

  @override
  void paint(Canvas canvas, Size size) {
    paintSegmentedCharacterRig(
      canvas: canvas,
      size: size,
      atlas: atlas,
      classKey: classKey,
      facingRight: facingRight,
      facingBack: false,
      isMoving: false,
      walkPhase: 0.0,
      idlePhase: idlePhase,
      glowColor: glowColor,
      glowLevel: glowLevel,
      weaponVisual: weapon,
      attackProgress: attackProgress,
      comboStage: comboStage,
    );
  }

  @override
  bool shouldRepaint(covariant _ColosseumGladiatorPainter oldDelegate) {
    return (oldDelegate.idlePhase - idlePhase).abs() > 0.005 ||
        (oldDelegate.attackProgress - attackProgress).abs() > 0.005 ||
        oldDelegate.atlas != atlas ||
        oldDelegate.glowLevel != glowLevel;
  }
}

class _ColosseumClashSparkPainter extends CustomPainter {
  const _ColosseumClashSparkPainter({
    required this.progress,
    required this.center,
    required this.isCritical,
  });

  final double progress;
  final Offset center;
  final bool isCritical;

  @override
  void paint(Canvas canvas, Size size) {
    final double fade = (1.0 - progress).clamp(0.0, 1.0);
    if (fade <= 0.01) return;

    final Color col =
        isCritical ? const Color(0xFFFEF08A) : const Color(0xFFFB923C);
    canvas.drawCircle(
      center,
      14.0 + progress * (isCritical ? 54.0 : 36.0),
      Paint()
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * fade
        ..color = col.withValues(alpha: fade * 0.88),
    );
    final Paint sp = Paint()..blendMode = BlendMode.plus;
    for (int i = 0; i < 8; i++) {
      final double ang = (i / 8.0) * math.pi * 2.0;
      final double dist = 8.0 + progress * (isCritical ? 48.0 : 32.0);
      sp.color = col.withValues(alpha: fade * 0.9);
      canvas.drawCircle(
        center + Offset(math.cos(ang) * dist, math.sin(ang) * dist),
        2.2 * fade,
        sp,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ColosseumClashSparkPainter oldDelegate) {
    return (oldDelegate.progress - progress).abs() > 0.005;
  }
}
