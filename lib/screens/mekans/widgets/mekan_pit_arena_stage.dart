import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/game_sfx_service.dart';
import '../../../core/services/graphics_quality_service.dart';
import '../../../core/utils/gold_format.dart';
import '../../../models/moradon_models.dart';
import '../../home/moradon/character_skeletal_rig.dart';
import 'mekan_design.dart';

/// V15 Pack 3B: Torchlit 2.5D Underground Fight-Club Pit (`Mekan Kafes Arenası`).
///
/// Backed by `assets/v15/mekan_pit_arena_bg.jpg`, animated cheering crowd
/// silhouettes around the stone pit rim, roaring brazier embers, and live
/// 1v1 skeletal pit fighters (`paintSegmentedCharacterRig`).
class MekanPitArenaStage extends StatefulWidget {
  const MekanPitArenaStage({
    super.key = const Key('mekan_pit_arena_stage'),
    required this.playerName,
    required this.opponentName,
    this.wagerGold = 0,
    this.playerClassKey = 'savasci',
    this.exchangeStep = 0,
    this.height = 206,
    this.previewMode = false,
  });

  final String playerName;
  final String opponentName;
  final int wagerGold;
  final String playerClassKey;
  final int exchangeStep;
  final double height;
  final bool previewMode;

  @visibleForTesting
  static bool debugAnimateInTests = false;

  @override
  State<MekanPitArenaStage> createState() => _MekanPitArenaStageState();
}

class _MekanPitArenaStageState extends State<MekanPitArenaStage>
    with TickerProviderStateMixin {
  AnimationController? _crowdCtrl;
  late final AnimationController _brawlCtrl;
  Map<String, ui.Image>? _atlases;

  static bool get _isTestBinding {
    if (MekanPitArenaStage.debugAnimateInTests) return false;
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _brawlCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    GraphicsQualityService.instance.addListener(_syncTicker);
    _syncTicker();
    _loadAtlases();
  }

  Future<void> _loadAtlases() async {
    if (_isTestBinding) return;
    try {
      final Map<String, ui.Image> loaded =
          await GraphicsQualityService.instance.loadSharedCharacterAtlases();
      if (mounted) {
        setState(() => _atlases = loaded);
      }
    } catch (_) {}
  }

  void _syncTicker() {
    final bool animate =
        !_isTestBinding && !GraphicsQualityService.instance.profile.isLow;
    if (animate) {
      _crowdCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      );
      if (!_crowdCtrl!.isAnimating) {
        _crowdCtrl!.repeat();
      }
    } else {
      _crowdCtrl?.stop();
    }
  }

  @override
  void didUpdateWidget(covariant MekanPitArenaStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exchangeStep != oldWidget.exchangeStep &&
        widget.exchangeStep > 0) {
      unawaited(
        GameSfxService.instance.play(
          widget.exchangeStep.isEven
              ? GameSfx.criticalSlash
              : GameSfx.swordSlash,
        ),
      );
      _brawlCtrl.forward(from: 0.0);
    }
  }

  void _sparOnce() {
    unawaited(GameSfxService.instance.play(GameSfx.criticalSlash));
    _brawlCtrl.forward(from: 0.0);
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_syncTicker);
    _crowdCtrl?.dispose();
    _brawlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final int cacheW = gfx.isLow ? 640 : 1280;
    final Listenable merged = Listenable.merge(<Listenable?>[
      _crowdCtrl,
      _brawlCtrl,
    ]);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: MekanPalette.gold.withValues(alpha: 0.45),
          width: 1.3,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: MekanPalette.ruby.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: AnimatedBuilder(
          animation: merged,
          builder: (BuildContext context, _) {
            final double ambT = _crowdCtrl?.value ?? 0.3;
            final double hitT = _brawlCtrl.isAnimating ? _brawlCtrl.value : 0.0;
            final double shake = (hitT > 0.25 && hitT < 0.72)
                ? math.sin(hitT * 52.0) * 4.5 * (1.0 - hitT)
                : 0.0;

            return Transform.translate(
              offset: Offset(shake, 0),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image(
                    image: ResizeImage.resizeIfNeeded(
                      cacheW,
                      null,
                      const AssetImage('assets/v15/mekan_pit_arena_bg.jpg'),
                    ),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFF141118), Color(0xFF241217)],
                        ),
                      ),
                    ),
                  ),
                  CustomPaint(
                    key: const ValueKey<String>('mekan_pit_brawl_paint'),
                    painter: _MekanPitPainter(
                      atlases: _atlases,
                      playerClassKey: widget.playerClassKey,
                      crowdPhase: ambT,
                      brawlProgress: hitT,
                      attackerIsLeft: widget.exchangeStep.isEven,
                      isLowTier: gfx.isLow,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: MekanPalette.ruby.withValues(alpha: 0.75),
                            ),
                          ),
                          child: Text(
                            '⛓ YERALTI KAFES ARENASI • ${widget.playerName} vs ${widget.opponentName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (widget.wagerGold > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: MekanPalette.gold.withValues(alpha: 0.75),
                              ),
                            ),
                            child: Text(
                              '🪙 ${formatCompactGold(widget.wagerGold)}',
                              style: const TextStyle(
                                color: MekanPalette.gold,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        else if (widget.previewMode)
                          GestureDetector(
                            key: const Key('mekan_pit_spar_btn'),
                            onTap: _sparOnce,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xCC3B0D18),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: MekanPalette.ruby),
                              ),
                              child: const Text(
                                '🥊 Kafes Gösterisi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MekanPitPainter extends CustomPainter {
  const _MekanPitPainter({
    required this.atlases,
    required this.playerClassKey,
    required this.crowdPhase,
    required this.brawlProgress,
    required this.attackerIsLeft,
    required this.isLowTier,
  });

  final Map<String, ui.Image>? atlases;
  final String playerClassKey;
  final double crowdPhase;
  final double brawlProgress;
  final bool attackerIsLeft;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 2 || h <= 2) return;

    // 1. Cheering underground crowd silhouettes bobbing around upper pit rim
    if (!isLowTier) {
      final Paint crowdPaint = Paint()
        ..color = const Color(0xFF07060A).withValues(alpha: 0.72);
      for (int i = 0; i < 11; i++) {
        final double frac = 0.16 + (i / 10.0) * 0.68;
        final double cheerY =
            math.sin(crowdPhase * math.pi * 4.0 + i * 1.3) * 3.5;
        final Offset head = Offset(w * frac, h * 0.34 + cheerY);
        canvas.drawCircle(head, 5.5, crowdPaint);
      }
    }

    // 2. Pit fighters lunging & clashing in the sunken rune ring
    final double lunge = brawlProgress > 0
        ? math.sin(brawlProgress * math.pi).clamp(0.0, 1.0)
        : 0.0;
    final double leftX = w * 0.35 + (attackerIsLeft ? lunge * w * 0.11 : 0.0);
    final double rightX = w * 0.65 - (!attackerIsLeft ? lunge * w * 0.11 : 0.0);
    final double footY = h * 0.84;
    const Size rigSz = Size(78, 96);

    void drawFighter({
      required double cx,
      required String cls,
      required bool facingRight,
      required bool attacking,
      required Color glow,
    }) {
      final ui.Image? img = atlases?[cls];
      if (img != null) {
        canvas.save();
        canvas.translate(cx - rigSz.width * 0.5, footY - rigSz.height);
        paintSegmentedCharacterRig(
          canvas: canvas,
          size: rigSz,
          atlas: img,
          classKey: cls,
          facingRight: facingRight,
          facingBack: false,
          isMoving: lunge > 0.05,
          walkPhase: crowdPhase * math.pi * 4.0,
          idlePhase: crowdPhase,
          glowColor: glow,
          glowLevel: isLowTier ? 7 : 9,
          weaponVisual: cls == 'golge'
              ? MoradonWeaponVisual.twilightFang
              : MoradonWeaponVisual.crimsonAxe,
          attackProgress: attacking ? brawlProgress : 0.0,
          comboStage: 1,
        );
        canvas.restore();
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, footY - 4), width: 32, height: 10),
          Paint()..color = glow.withValues(alpha: 0.5),
        );
      }
    }

    drawFighter(
      cx: leftX,
      cls: playerClassKey,
      facingRight: true,
      attacking: attackerIsLeft && brawlProgress > 0,
      glow: const Color(0xFF4ADE80),
    );
    drawFighter(
      cx: rightX,
      cls: playerClassKey == 'golge' ? 'savasci' : 'golge',
      facingRight: false,
      attacking: !attackerIsLeft && brawlProgress > 0,
      glow: const Color(0xFFF43F5E),
    );

    if (lunge > 0.35) {
      final Offset sparkPos = Offset(w * 0.5, h * 0.62);
      canvas.drawCircle(
        sparkPos,
        14.0 * lunge,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0xFFFBBF24).withValues(alpha: 0.78),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MekanPitPainter oldDelegate) {
    return oldDelegate.atlases != atlases ||
        (oldDelegate.crowdPhase - crowdPhase).abs() > 0.008 ||
        (oldDelegate.brawlProgress - brawlProgress).abs() > 0.008;
  }
}
