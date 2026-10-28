import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/game_sfx_service.dart';
import '../../../core/services/graphics_quality_service.dart';
import '../../home/moradon/character_skeletal_rig.dart';
import '../../../models/moradon_models.dart';
import 'guild_war_design.dart';

/// Live 2.5D `3v3` Castle Gate Breach Stage for [GuildWarAttackScreen].
///
/// Renders 3 attacking guild champions on the left charging against 3 defending
/// fortress wardens at the iron gatehouse on `assets/v15/castle_gate_siege_bg.jpg`,
/// reusing [GraphicsQualityService.loadSharedCharacterAtlases] (`0` extra atlas VRAM).
class CastleSiegeClashStage extends StatefulWidget {
  const CastleSiegeClashStage({
    super.key = const Key('castle_siege_clash_stage'),
    required this.territoryName,
    required this.attackerGuildName,
    required this.defenderGuildName,
    required this.winChancePct,
    this.isAttacking = false,
  });

  final String territoryName;
  final String attackerGuildName;
  final String defenderGuildName;
  final double winChancePct;
  final bool isAttacking;

  @visibleForTesting
  static bool debugAnimateInTests = false;

  @override
  State<CastleSiegeClashStage> createState() => _CastleSiegeClashStageState();
}

class _CastleSiegeClashStageState extends State<CastleSiegeClashStage>
    with TickerProviderStateMixin {
  AnimationController? _ambientCtrl;
  late final AnimationController _ramCtrl;
  Map<String, ui.Image>? _atlases;

  static bool get _isTestBinding {
    if (CastleSiegeClashStage.debugAnimateInTests) return false;
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _ramCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
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
    final bool shouldLoop =
        !_isTestBinding && !GraphicsQualityService.instance.profile.isLow;
    if (shouldLoop) {
      _ambientCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      );
      if (!_ambientCtrl!.isAnimating) {
        _ambientCtrl!.repeat();
      }
    } else {
      _ambientCtrl?.stop();
    }
  }

  @override
  void didUpdateWidget(covariant CastleSiegeClashStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAttacking && !oldWidget.isAttacking) {
      _triggerRamCharge();
    }
  }

  void _triggerRamCharge() {
    unawaited(GameSfxService.instance.play(GameSfx.siegeHorn));
    _ramCtrl.forward(from: 0.0);
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_syncTicker);
    _ambientCtrl?.dispose();
    _ramCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final int bgCacheW = gfx.isLow ? 640 : 1280;
    final Listenable merged = Listenable.merge(<Listenable?>[
      _ambientCtrl,
      _ramCtrl,
    ]);

    return Container(
      height: 218,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: WarPalette.gold.withValues(alpha: 0.48),
          width: 1.3,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: WarPalette.ruby.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: AnimatedBuilder(
          animation: merged,
          builder: (BuildContext context, _) {
            final double ambT = _ambientCtrl?.value ?? 0.35;
            final double ramT = _ramCtrl.isAnimating ? _ramCtrl.value : 0.0;
            final double shakeX = (ramT > 0.25 && ramT < 0.75)
                ? math.sin(ramT * 48.0) * 5.0 * (1.0 - ramT)
                : 0.0;

            return Transform.translate(
              offset: Offset(shakeX, 0),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image(
                    image: ResizeImage.resizeIfNeeded(
                      bgCacheW,
                      null,
                      const AssetImage('assets/v15/castle_gate_siege_bg.jpg'),
                    ),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFF15192B), Color(0xFF281219)],
                        ),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Color(0x88070B14),
                          Color(0x18070B14),
                          Color(0xB8070B14),
                        ],
                      ),
                    ),
                  ),
                  CustomPaint(
                    key: const ValueKey<String>('castle_siege_3v3_paint'),
                    painter: _CastleSiege3v3Painter(
                      atlases: _atlases,
                      ambientPhase: ambT,
                      ramProgress: ramT,
                      isLowTier: gfx.isLow,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '🏰 3v3 KALE KUŞATMASI • ${widget.territoryName.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: WarPalette.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '⚔ ${widget.attackerGuildName}  vs  🛡 ${widget.defenderGuildName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('siege_ram_preview_btn'),
                            borderRadius: BorderRadius.circular(999),
                            onTap: _triggerRamCharge,
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: const Color(0xCC3B0D18),
                                border: Border.all(
                                  color: WarPalette.coral.withValues(alpha: 0.7),
                                ),
                              ),
                              child: const Text(
                                '🔥 Hücum Önizle',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.58),
                            border: Border.all(
                              color: WarPalette.gold.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            'Fetih Şansı: %${widget.winChancePct.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: WarPalette.gold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Koçbaşı & Mancınık Hazır',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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

class _CastleSiege3v3Painter extends CustomPainter {
  const _CastleSiege3v3Painter({
    required this.atlases,
    required this.ambientPhase,
    required this.ramProgress,
    required this.isLowTier,
  });

  final Map<String, ui.Image>? atlases;
  final double ambientPhase;
  final double ramProgress;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 2 || h <= 2) return;

    final double charge = ramProgress > 0
        ? math.sin(ramProgress * math.pi).clamp(0.0, 1.0)
        : 0.0;

    // 1. Fiery catapult trajectories arcing toward the fortress gate on right
    if (!isLowTier || ramProgress > 0) {
      final int bolts = isLowTier ? 1 : 2;
      for (int i = 0; i < bolts; i++) {
        final double t = ((ambientPhase * 1.4 + ramProgress + i * 0.48) % 1.0);
        final Offset p0 = Offset(w * 0.06, h * 0.28 + i * 14);
        final Offset p1 = Offset(w * 0.46, h * 0.04);
        final Offset p2 = Offset(w * 0.80, h * 0.54);
        final double u = 1.0 - t;
        final Offset pos = Offset(
          u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
          u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
        );
        canvas.drawCircle(
          pos,
          6.5,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = const Color(0xFFFF6B2B).withValues(alpha: 0.72),
        );
        canvas.drawCircle(
          pos,
          2.8,
          Paint()..color = const Color(0xFFFEF08A),
        );
      }
    }

    // 2. Gate impact shockwave when ram strikes
    if (charge > 0.35) {
      final double imp = ((charge - 0.35) / 0.65).clamp(0.0, 1.0);
      final Rect gateRing = Rect.fromCenter(
        center: Offset(w * 0.56, h * 0.72),
        width: 44 + imp * 130,
        height: 18 + imp * 42,
      );
      canvas.drawOval(
        gateRing,
        Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 * (1.0 - imp * 0.5)
          ..color = const Color(0xFFFF9824).withValues(alpha: 0.85),
      );
    }

    // 3. Render 3v3 Fighters (or stylized silhouettes before atlases finish loading)
    const List<(String, double, double, int, MoradonWeaponVisual)> attackers =
        <(String, double, double, int, MoradonWeaponVisual)>[
      ('simyaci', 0.14, 0.78, 8, MoradonWeaponVisual.aetherStaff),
      ('golge', 0.24, 0.84, 10, MoradonWeaponVisual.twilightFang),
      ('savasci', 0.35, 0.80, 9, MoradonWeaponVisual.imperialHalberd),
    ];
    const List<(String, double, double, int, MoradonWeaponVisual)> defenders =
        <(String, double, double, int, MoradonWeaponVisual)>[
      ('simyaci', 0.84, 0.77, 8, MoradonWeaponVisual.aetherStaff),
      ('golge', 0.74, 0.84, 9, MoradonWeaponVisual.illusionSabre),
      ('savasci', 0.64, 0.80, 10, MoradonWeaponVisual.crimsonAxe),
    ];

    void drawSquad(
      List<(String, double, double, int, MoradonWeaponVisual)> squad, {
      required bool facingRight,
    }) {
      for (int i = 0; i < squad.length; i++) {
        final (String cls, double fx, double fy, int enh, MoradonWeaponVisual wpn) =
            squad[i];
        final double shiftX = facingRight
            ? charge * (w * 0.11)
            : -charge * (w * 0.06);
        final double cx = w * fx + shiftX;
        final double footY = h * fy;
        final double rigW = 68.0;
        final double rigH = 86.0;
        final ui.Image? atlas = atlases?[cls];
        if (atlas != null) {
          canvas.save();
          canvas.translate(cx - rigW * 0.5, footY - rigH);
          paintSegmentedCharacterRig(
            canvas: canvas,
            size: Size(rigW, rigH),
            atlas: atlas,
            classKey: cls,
            facingRight: facingRight,
            facingBack: false,
            isMoving: charge > 0.05,
            walkPhase: (ambientPhase * math.pi * 4.0) + i,
            idlePhase: (ambientPhase + i * 0.23) % 1.0,
            glowColor: facingRight
                ? const Color(0xFFFBBF24)
                : const Color(0xFFEF4444),
            glowLevel: isLowTier ? 7 : enh,
            weaponVisual: wpn,
            attackProgress: charge > 0.15 ? ((ramProgress * 1.6) % 1.0) : 0.0,
            comboStage: i % 3,
          );
          canvas.restore();
        } else {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cx, footY - 4),
              width: 28,
              height: 9,
            ),
            Paint()
              ..color = (facingRight ? WarPalette.gold : WarPalette.ruby)
                  .withValues(alpha: 0.45),
          );
        }
      }
    }

    drawSquad(attackers, facingRight: true);
    drawSquad(defenders, facingRight: false);
  }

  @override
  bool shouldRepaint(covariant _CastleSiege3v3Painter oldDelegate) {
    return oldDelegate.atlases != atlases ||
        (oldDelegate.ambientPhase - ambientPhase).abs() > 0.008 ||
        (oldDelegate.ramProgress - ramProgress).abs() > 0.008;
  }
}
