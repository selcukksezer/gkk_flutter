import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/graphics_quality_service.dart';
import '../../../models/dungeon_model.dart';
import '../../../models/player_model.dart';
import '../dungeon_battle_profiles.dart';
import '../dungeon_zone_data.dart';
import 'dungeon_mob_pack_rig.dart';

/// Interactive 3D Perspective Live Zone Portal Diorama displayed at the top of [DungeonScreen].
/// Combines Blender-raytraced `stage_3d_runic_dais.png`, live 60 FPS Hero vs Boss skeletal
/// face-off, parallax skull-torch pillars, and a 1-tap Recommended Expedition launcher.
class DungeonZone3dDiorama extends StatefulWidget {
  const DungeonZone3dDiorama({
    super.key,
    required this.selectedZone,
    required this.dungeons,
    required this.recommendedDungeon,
    required this.recommendedSuccessPct,
    required this.canEnterRecommended,
    required this.clearedCount,
    required this.totalCount,
    required this.characterClass,
    required this.playerPower,
    required this.onQuickEnterRecommended,
  });

  final DungeonZone? selectedZone;
  final List<DungeonData> dungeons;
  final DungeonData? recommendedDungeon;
  final int? recommendedSuccessPct;
  final bool canEnterRecommended;
  final int clearedCount;
  final int totalCount;
  final CharacterClass? characterClass;
  final int playerPower;
  final VoidCallback? onQuickEnterRecommended;

  @override
  State<DungeonZone3dDiorama> createState() => _DungeonZone3dDioramaState();
}

class _DungeonZone3dDioramaState extends State<DungeonZone3dDiorama>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loopCtrl;
  Offset _dragTilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
      value: 0.12,
    );
    GraphicsQualityService.instance.addListener(_onGraphicsChanged);
    _syncTickerWithGraphics();
  }

  void _onGraphicsChanged() {
    if (!mounted) return;
    _syncTickerWithGraphics();
    setState(() {});
  }

  void _syncTickerWithGraphics() {
    final bool live =
        GraphicsQualityService.instance.profile.enableLive3dHubDiorama;
    if (live && !_loopCtrl.isAnimating) {
      _loopCtrl.repeat();
    } else if (!live && _loopCtrl.isAnimating) {
      _loopCtrl.stop();
      _loopCtrl.value = 0.12;
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_onGraphicsChanged);
    _loopCtrl.dispose();
    super.dispose();
  }

  String get _heroAsset => switch (widget.characterClass) {
        CharacterClass.shadow => 'assets/dungeon/hero_battle_shadow.png',
        CharacterClass.alchemist => 'assets/dungeon/hero_battle_alchemist.png',
        _ => 'assets/dungeon/hero_battle_warrior.png',
      };

  @override
  Widget build(BuildContext context) {
    final DungeonData? target = widget.recommendedDungeon ??
        (widget.dungeons.isNotEmpty ? widget.dungeons.first : null);
    if (target == null) return const SizedBox.shrink();

    final DungeonBattleProfile profile = DungeonBattleProfile.forDungeonId(
      target.dungeonId,
      fallbackZone: widget.selectedZone?.number ?? 1,
    );
    final Color accent = widget.selectedZone?.color ?? profile.primaryColor;
    final bool compactPhone = MediaQuery.sizeOf(context).width < 430;
    final double cardHeight = compactPhone ? 148.0 : 168.0;
    final int chance = widget.recommendedSuccessPct ?? 75;
    final Color chanceColor = chance >= 75
        ? const Color(0xFF4ADE80)
        : (chance >= 45 ? const Color(0xFFFBBF24) : const Color(0xFFF87171));

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final bool liveDiorama = gfx.enableLive3dHubDiorama;

    return GestureDetector(
      key: const Key('dungeon_zone_3d_diorama'),
      onPanUpdate: liveDiorama
          ? (DragUpdateDetails d) {
              setState(() {
                _dragTilt = Offset(
                  (_dragTilt.dx + d.delta.dx * 0.004).clamp(-0.18, 0.18),
                  (_dragTilt.dy - d.delta.dy * 0.004).clamp(-0.14, 0.14),
                );
              });
            }
          : null,
      onPanEnd:
          liveDiorama ? (_) => setState(() => _dragTilt = Offset.zero) : null,
      onPanCancel:
          liveDiorama ? () => setState(() => _dragTilt = Offset.zero) : null,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _loopCtrl,
          builder: (BuildContext context, _) {
            final double t = _loopCtrl.value;
            final double rad = t * math.pi * 2.0;
            final double autoYaw =
                liveDiorama ? (math.sin(rad) * 0.036 + _dragTilt.dx) : 0.0;
            final double autoPitch = liveDiorama
                ? (0.055 + math.cos(rad) * 0.018 + _dragTilt.dy)
                : 0.0;

            final Matrix4 tiltMatrix = Matrix4.identity();
            if (liveDiorama && gfx.enable3dPerspective) {
              tiltMatrix
                ..setEntry(3, 2, 0.0011)
                ..rotateX(autoPitch)
                ..rotateY(autoYaw);
            }

            final Widget innerCard = Container(
              height: cardHeight,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: profile.deepSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accent.withValues(alpha: 0.72),
                  width: 1.35,
                ),
                boxShadow: gfx.enableHeavyShadows
                    ? <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.24),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                        const BoxShadow(
                          color: Colors.black87,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // 1. Parallax 3D Chamber Backdrop (downsampled per tier!)
                  Positioned(
                    left: liveDiorama ? (-18 - autoYaw * 48) : 0,
                    right: liveDiorama ? (-18 + autoYaw * 48) : 0,
                    top: liveDiorama ? (-14 - autoPitch * 30) : 0,
                    bottom: liveDiorama ? (-14 + autoPitch * 30) : 0,
                    child: Image.asset(
                      profile.arenaAsset,
                      fit: BoxFit.cover,
                      cacheWidth: gfx.dungeonArenaCacheWidth,
                      filterQuality: gfx.filterQuality,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: profile.deepSurface),
                    ),
                  ),

                  // 2. Dark-Gothic Carved Obsidian & Glowing Rune Dais (skipped on Low!)
                  if (liveDiorama)
                    Positioned(
                      right: -28 - autoYaw * 36,
                      bottom: -18,
                      width: compactPhone ? 256 : 306,
                      height: compactPhone ? 132 : 154,
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/dungeon/stage_3d_runic_dais.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          cacheWidth: 420,
                          filterQuality: gfx.filterQuality,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                  // 3. Live 60 FPS Hero & Boss Face-Off (or crisp static boss cutout on Low!)
                  if (liveDiorama) ...<Widget>[
                    Positioned(
                      right: compactPhone ? 96 : 124,
                      bottom: 14,
                      width: compactPhone ? 74 : 88,
                      height: compactPhone ? 82 : 96,
                      child: IgnorePointer(
                        child: DungeonSkeletalFighter(
                          assetPath: _heroAsset,
                          facingRight: true,
                          walkPhase: rad * 2.0,
                          strideIntensity: 0.62,
                          idlePhase: t,
                          attackSlashProgress:
                              (t > 0.68 && t < 0.88) ? (t - 0.68) / 0.20 : 0.0,
                          hitRecoil: 0.0,
                          specularFlash: 0.0,
                          accentColor: const Color(0xFFFB923C),
                          secondaryColor: accent,
                        ),
                      ),
                    ),
                    Positioned(
                      right: compactPhone ? 16 : 26,
                      bottom: 14,
                      width: compactPhone ? 94 : 112,
                      height: compactPhone ? 104 : 122,
                      child: IgnorePointer(
                        child: DungeonSkeletalFighter(
                          assetPath: profile.enemySpriteAsset,
                          facingRight: false,
                          walkPhase: rad * 2.0 + 1.2,
                          strideIntensity: 0.58,
                          idlePhase: (t + 0.35) % 1.0,
                          attackSlashProgress:
                              (t > 0.22 && t < 0.40) ? (t - 0.22) / 0.18 : 0.0,
                          hitRecoil: (t > 0.72 && t < 0.88)
                              ? math.sin(((t - 0.72) / 0.16) * math.pi) * 0.6
                              : 0.0,
                          specularFlash:
                              (t > 0.73 && t < 0.80) ? 0.55 : 0.0,
                          accentColor: accent,
                          secondaryColor: profile.secondaryColor,
                          hover: profile.enemyHover,
                        ),
                      ),
                    ),
                  ] else
                    Positioned(
                      right: compactPhone ? 10 : 20,
                      bottom: 8,
                      width: compactPhone ? 106 : 124,
                      height: compactPhone ? 114 : 132,
                      child: IgnorePointer(
                        child: Image.asset(
                          profile.enemySpriteAsset,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          cacheWidth: 220,
                          filterQuality: gfx.filterQuality,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                  // 4. Clean Unmixed 2.5D Foreground Skull-Torch Pillar (High/Ultra only, zero saveLayer!)
                  if (gfx.enableForegroundOcclusion)
                    Positioned(
                      right: -18 + autoYaw * 55,
                      top: -8,
                      bottom: -8,
                      width: 68,
                      child: IgnorePointer(
                        child: Image.asset(
                          'assets/dungeon/fg_dungeon_right_pillar.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.centerLeft,
                          cacheWidth: 160,
                          opacity: const AlwaysStoppedAnimation<double>(0.86),
                          filterQuality: gfx.filterQuality,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                  // 5. Left-Side Readability Scrim
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const <double>[0.0, 0.52, 0.82, 1.0],
                          colors: <Color>[
                            const Color(0xF2060913),
                            const Color(0xCC080D1A),
                            const Color(0x44080D1A),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 6. Left Tactical Briefing + 1-Tap Quick Expedition CTA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        // Top badges row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.75),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.threed_rotation_rounded,
                                    size: 11,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.selectedZone != null
                                        ? '3D BÖLGE ${widget.selectedZone!.number} SAHNESİ'
                                        : '3D CANLI ZİNDAN PORTALI',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 8.8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xCC0F172A),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 11,
                                    color: Color(0xFFFBBF24),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.clearedCount}/${widget.totalCount} Fetih',
                                    style: const TextStyle(
                                      color: Color(0xFFFEF08A),
                                      fontSize: 8.8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Recommended Dungeon Title & Boss Subtitle
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: compactPhone ? 215 : 290,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'ÖNERİLEN HEDEF • %$chance ZAFER',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: chanceColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                target.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      '${profile.enemyName} • ',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.78),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 13,
                                    color: Color(0xFFFBBF24),
                                  ),
                                  Text(
                                    '${target.energyCost} Enerji',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.88),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 1-Tap Quick Expedition CTA
                        GestureDetector(
                          key: const Key('dungeon_diorama_quick_enter_btn'),
                          onTap: widget.canEnterRecommended &&
                                  widget.onQuickEnterRecommended != null
                              ? () {
                                  HapticFeedback.mediumImpact();
                                  widget.onQuickEnterRecommended!();
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: widget.canEnterRecommended
                                  ? LinearGradient(
                                      colors: <Color>[
                                        accent,
                                        profile.secondaryColor,
                                      ],
                                    )
                                  : null,
                              color: widget.canEnterRecommended
                                  ? null
                                  : const Color(0xAA1E293B),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: widget.canEnterRecommended
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.42),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  widget.canEnterRecommended
                                      ? Icons.bolt_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 14,
                                  color: widget.canEnterRecommended
                                      ? const Color(0xFF070A12)
                                      : Colors.white60,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.canEnterRecommended
                                      ? 'HIZLI SEFER BAŞLAT'
                                      : 'KİLİTLİ / ENERJİ YOK',
                                  style: TextStyle(
                                    color: widget.canEnterRecommended
                                        ? const Color(0xFF070A12)
                                        : Colors.white60,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
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
                ],
              ),
            );

            if (!liveDiorama || !gfx.enable3dPerspective) {
              return innerCard;
            }
            return Transform(
              alignment: Alignment.center,
              transform: tiltMatrix,
              child: innerCard,
            );
          },
        ),
      ),
    );
  }
}
