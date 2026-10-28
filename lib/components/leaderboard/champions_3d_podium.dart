import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/services/game_sfx_service.dart';
import '../../core/services/graphics_quality_service.dart';
import '../../models/leaderboard_model.dart';
import '../../models/moradon_models.dart';
import '../../screens/home/moradon/character_skeletal_rig.dart';
import '../../theme/app_colors.dart';

/// V15 Pack 2: Live 3D Champions Hall Podium (`#1 / #2 / #3`) for [LeaderboardScreen].
///
/// Renders the top 1–3 server champions standing on 2.5D marble/gold pedestals
/// with dark-fantasy forge ember heat & class weapons via shared Moradon
/// character atlases (`0` extra texture allocations). Tap any champion to trigger
/// a victory combo salute!
class Champions3dPodium extends StatefulWidget {
  const Champions3dPodium({
    super.key = const Key('champions_3d_podium'),
    required this.entries,
    required this.categoryKey,
    this.dimmed = false,
  });

  final List<LeaderboardEntry> entries;
  final String categoryKey;
  final bool dimmed;

  @visibleForTesting
  static bool debugAnimateInTests = false;

  @override
  State<Champions3dPodium> createState() => _Champions3dPodiumState();
}

class _Champions3dPodiumState extends State<Champions3dPodium>
    with TickerProviderStateMixin {
  AnimationController? _idleCtrl;
  late final AnimationController _saluteCtrl;
  int _salutingRank = 1;
  Map<String, ui.Image>? _atlases;

  static bool get _isTestBinding {
    if (Champions3dPodium.debugAnimateInTests) return false;
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _saluteCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
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
      _idleCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      );
      if (!_idleCtrl!.isAnimating) {
        _idleCtrl!.repeat();
      }
    } else {
      _idleCtrl?.stop();
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_syncTicker);
    _idleCtrl?.dispose();
    _saluteCtrl.dispose();
    super.dispose();
  }

  String _classForEntry(LeaderboardEntry e, int slot) {
    final int hash = e.username.codeUnits.fold<int>(slot, (int a, int b) => a + b);
    return switch (hash % 3) {
      1 => 'golge',
      2 => 'simyaci',
      _ => 'savasci',
    };
  }

  void _salute(int rank) {
    setState(() => _salutingRank = rank);
    unawaited(GameSfxService.instance.play(GameSfx.legendaryDrop));
    _saluteCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final LeaderboardEntry first = widget.entries[0];
    final LeaderboardEntry? second =
        widget.entries.length > 1 ? widget.entries[1] : null;
    final LeaderboardEntry? third =
        widget.entries.length > 2 ? widget.entries[2] : null;
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final Listenable merged = Listenable.merge(<Listenable?>[
      _idleCtrl,
      _saluteCtrl,
    ]);

    return Opacity(
      opacity: widget.dimmed ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF151C2F),
              Color(0xFF0A0F1C),
            ],
          ),
          border: Border.all(
            color: AppColors.liquidGold.withValues(alpha: 0.48),
            width: 1.3,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.liquidGold.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: merged,
          builder: (BuildContext context, _) {
            final double idlePhase = _idleCtrl?.value ?? 0.25;
            final double saluteT =
                _saluteCtrl.isAnimating ? _saluteCtrl.value : 0.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text(
                      '👑 CANLI 3D ŞAMPİYONLAR PODYUMU',
                      style: TextStyle(
                        color: AppColors.liquidGold,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Selamlamak için dokun',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 224,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        flex: 10,
                        child: second != null
                            ? _PodiumChampionSlot(
                                key: const Key('podium_slot_2'),
                                entry: second,
                                displayRank: 2,
                                categoryKey: widget.categoryKey,
                                pedestalHeight: 54,
                                rigSize: const Size(82, 102),
                                accent: const Color(0xFFCBD5E1),
                                glowLevel: gfx.isLow ? 7 : 9,
                                classKey: _classForEntry(second, 2),
                                atlas: _atlases?[_classForEntry(second, 2)],
                                idlePhase: (idlePhase + 0.33) % 1.0,
                                attackProgress:
                                    _salutingRank == 2 ? saluteT : 0.0,
                                onTap: () => _salute(2),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 12,
                        child: _PodiumChampionSlot(
                          key: const Key('podium_slot_1'),
                          entry: first,
                          displayRank: 1,
                          categoryKey: widget.categoryKey,
                          pedestalHeight: 74,
                          rigSize: const Size(98, 120),
                          accent: const Color(0xFFFBBF24),
                          glowLevel: gfx.isLow ? 8 : 10,
                          classKey: _classForEntry(first, 1),
                          atlas: _atlases?[_classForEntry(first, 1)],
                          idlePhase: idlePhase,
                          attackProgress: _salutingRank == 1 ? saluteT : 0.0,
                          onTap: () => _salute(1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 10,
                        child: third != null
                            ? _PodiumChampionSlot(
                                key: const Key('podium_slot_3'),
                                entry: third,
                                displayRank: 3,
                                categoryKey: widget.categoryKey,
                                pedestalHeight: 48,
                                rigSize: const Size(78, 94),
                                accent: const Color(0xFFD97706),
                                glowLevel: gfx.isLow ? 7 : 8,
                                classKey: _classForEntry(third, 3),
                                atlas: _atlases?[_classForEntry(third, 3)],
                                idlePhase: (idlePhase + 0.66) % 1.0,
                                attackProgress:
                                    _salutingRank == 3 ? saluteT : 0.0,
                                onTap: () => _salute(3),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PodiumChampionSlot extends StatelessWidget {
  const _PodiumChampionSlot({
    super.key,
    required this.entry,
    required this.displayRank,
    required this.categoryKey,
    required this.pedestalHeight,
    required this.rigSize,
    required this.accent,
    required this.glowLevel,
    required this.classKey,
    required this.atlas,
    required this.idlePhase,
    required this.attackProgress,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final int displayRank;
  final String categoryKey;
  final double pedestalHeight;
  final Size rigSize;
  final Color accent;
  final int glowLevel;
  final String classKey;
  final ui.Image? atlas;
  final double idlePhase;
  final double attackProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isFirst = displayRank == 1;
    final String medal = switch (displayRank) {
      1 => '👑 #1',
      2 => '🥈 #2',
      _ => '🥉 #3',
    };

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          if (isFirst)
            Positioned(
              top: 0,
              bottom: pedestalHeight,
              width: rigSize.width * 0.85,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[
                        accent.withValues(alpha: 0.26),
                        accent.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              SizedBox(
                width: rigSize.width,
                height: rigSize.height,
                child: CustomPaint(
                  painter: _SingleChampionRigPainter(
                    atlas: atlas,
                    classKey: classKey,
                    accent: accent,
                    glowLevel: glowLevel,
                    idlePhase: idlePhase,
                    attackProgress: attackProgress,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                height: pedestalHeight,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                    bottom: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      accent.withValues(alpha: isFirst ? 0.34 : 0.22),
                      const Color(0xFF0E1526),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: isFirst ? 0.88 : 0.55),
                    width: isFirst ? 1.5 : 1.1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '$medal ${entry.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isFirst ? const Color(0xFFFEF08A) : Colors.white,
                        fontSize: isFirst ? 11.2 : 10.0,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      LeaderboardValueFormatter.format(
                        entry.value,
                        categoryKey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 9.5,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SingleChampionRigPainter extends CustomPainter {
  const _SingleChampionRigPainter({
    required this.atlas,
    required this.classKey,
    required this.accent,
    required this.glowLevel,
    required this.idlePhase,
    required this.attackProgress,
    this.fastSpriteQuad = false,
  });

  final ui.Image? atlas;
  final String classKey;
  final Color accent;
  final int glowLevel;
  final double idlePhase;
  final double attackProgress;
  final bool fastSpriteQuad;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? img = atlas;
    if (img == null) {
      // Fallback royal silhouette while shared atlas decodes
      final Offset c = Offset(size.width * 0.5, size.height * 0.58);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height - 6),
          width: size.width * 0.56,
          height: 12,
        ),
        Paint()..color = accent.withValues(alpha: 0.45),
      );
      canvas.drawCircle(
        c.translate(0, -18),
        11,
        Paint()..color = accent.withValues(alpha: 0.55),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.translate(0, 8), width: 28, height: 36),
          const Radius.circular(8),
        ),
        Paint()..color = accent.withValues(alpha: 0.38),
      );
      return;
    }

    paintSegmentedCharacterRig(
      canvas: canvas,
      size: size,
      atlas: img,
      classKey: classKey,
      facingRight: true,
      facingBack: false,
      isMoving: false,
      walkPhase: 0.0,
      idlePhase: idlePhase,
      glowColor: accent,
      glowLevel: glowLevel,
      weaponVisual: switch (classKey) {
        'golge' => MoradonWeaponVisual.twilightFang,
        'simyaci' => MoradonWeaponVisual.aetherStaff,
        _ => MoradonWeaponVisual.imperialHalberd,
      },
      attackProgress: attackProgress,
      comboStage: 2,
      fastSpriteQuad: fastSpriteQuad,
    );
  }

  @override
  bool shouldRepaint(covariant _SingleChampionRigPainter oldDelegate) {
    return oldDelegate.atlas != atlas ||
        oldDelegate.classKey != classKey ||
        oldDelegate.fastSpriteQuad != fastSpriteQuad ||
        (oldDelegate.idlePhase - idlePhase).abs() > 0.008 ||
        (oldDelegate.attackProgress - attackProgress).abs() > 0.008;
  }
}

/// Golden Holographic `#1 Server Sovereign` Statue projected atop Moradon's
/// Central Pantheon Monument!
class PantheonSovereignStatue extends StatelessWidget {
  const PantheonSovereignStatue({
    super.key = const Key('pantheon_sovereign_statue'),
    required this.kingUsername,
    required this.kingPowerLabel,
    required this.atlas,
    required this.phase,
    this.classKey = 'savasci',
  });

  final String kingUsername;
  final String kingPowerLabel;
  final ui.Image? atlas;
  final double phase;
  final String classKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xEE1E1305), Color(0xEE422806)],
                ),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.92),
                  width: 1.2,
                ),
              ),
              child: Text(
                '👑 #1 HÜKÜMDAR • $kingUsername ($kingPowerLabel)',
                style: const TextStyle(
                  color: Color(0xFFFEF08A),
                  fontSize: 10.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.55, 0.45, 0.12, 0, 28,
                0.42, 0.38, 0.08, 0, 18,
                0.12, 0.10, 0.05, 0, 0,
                0, 0, 0, 0.90, 0,
              ]),
              child: SizedBox(
                width: 112,
                height: 136,
                child: CustomPaint(
                  painter: _SingleChampionRigPainter(
                    atlas: atlas,
                    classKey: classKey,
                    accent: const Color(0xFFFBBF24),
                    glowLevel: 9,
                    idlePhase: 0.25,
                    attackProgress: 0.0,
                    fastSpriteQuad: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
