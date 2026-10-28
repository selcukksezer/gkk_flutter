import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../components/leaderboard/champions_3d_podium.dart';
import '../../../core/services/gpu_shader_service.dart';
import '../../../core/services/graphics_quality_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/inventory_model.dart';
import '../../../models/kingdom_market_blessing_model.dart';
import '../../../models/leaderboard_model.dart';
import '../../../models/moradon_models.dart';
import '../../../models/player_model.dart';
import '../../../models/retention_promos_model.dart';
import '../../../providers/daily_reward_provider.dart';
import '../../../providers/dungeon_siege_provider.dart';
import '../../../providers/graphics_quality_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/kingdom_market_blessing_provider.dart';
import '../../../providers/leaderboard_provider.dart';
import '../../../providers/moradon_hub_provider.dart';
import '../../../providers/retention_promos_provider.dart';
import '../../../routing/app_router.dart';
import '../widgets/character_inspect_sheet.dart';
import 'character_skeletal_rig.dart';
import 'moradon_v5_layers.dart';

class MoradonWorldView extends ConsumerStatefulWidget {
  final PlayerProfile profile;
  final InventoryState inventoryState;
  final int totalPower;

  const MoradonWorldView({
    super.key,
    required this.profile,
    required this.inventoryState,
    required this.totalPower,
  });

  @override
  ConsumerState<MoradonWorldView> createState() => _MoradonWorldViewState();
}

class _MoradonWorldViewState extends ConsumerState<MoradonWorldView>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _skyController;
  final Map<String, ui.Image> _charAtlases = <String, ui.Image>{};
  final Map<MoradonPetVisual, ui.Image> _petImages =
      <MoradonPetVisual, ui.Image>{};
  ui.Image? _merchantStallImage;
  bool _merchantStallLoading = false;
  List<MoradonPlayerPresence> _lastOverflowCrowdPlayers =
      const <MoradonPlayerPresence>[];
  int? _loadedAtlasTargetWidth = -999;
  bool _loadedPetsState = false;
  MoradonHubNotifier? _cachedNotifier;
  String? _hoveredNpcId;
  String? _hoveredPlayerId;
  final Set<LogicalKeyboardKey> _heldMoveKeys = <LogicalKeyboardKey>{};

  bool _isTextInputFocused() {
    final BuildContext? focusCtx = FocusManager.instance.primaryFocus?.context;
    if (focusCtx == null) return false;
    if (focusCtx.widget is EditableText) return true;
    return focusCtx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _syncKeyboardJoystick() {
    final MoradonHubNotifier? notifier = _cachedNotifier;
    if (notifier == null) return;
    double dx = 0.0;
    double dy = 0.0;
    if (_heldMoveKeys.contains(LogicalKeyboardKey.keyA) ||
        _heldMoveKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      dx -= 1.0;
    }
    if (_heldMoveKeys.contains(LogicalKeyboardKey.keyD) ||
        _heldMoveKeys.contains(LogicalKeyboardKey.arrowRight)) {
      dx += 1.0;
    }
    if (_heldMoveKeys.contains(LogicalKeyboardKey.keyW) ||
        _heldMoveKeys.contains(LogicalKeyboardKey.arrowUp)) {
      dy -= 1.0;
    }
    if (_heldMoveKeys.contains(LogicalKeyboardKey.keyS) ||
        _heldMoveKeys.contains(LogicalKeyboardKey.arrowDown)) {
      dy += 1.0;
    }
    final Offset raw = Offset(dx, dy);
    notifier.nudgeByJoystick(raw.distance > 1.0 ? raw / raw.distance : raw);
  }

  bool _onHardwareKeyEvent(KeyEvent event) {
    if (!mounted) return false;
    if (_isTextInputFocused()) {
      if (_heldMoveKeys.isNotEmpty) {
        _heldMoveKeys.clear();
        _cachedNotifier?.nudgeByJoystick(Offset.zero);
      }
      return false;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final bool isMoveKey = key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;

    if (isMoveKey) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (_heldMoveKeys.add(key)) {
          _syncKeyboardJoystick();
        }
      } else if (event is KeyUpEvent) {
        if (_heldMoveKeys.remove(key)) {
          _syncKeyboardJoystick();
        }
      }
      return true;
    }

    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.space) {
        _cachedNotifier?.triggerHeroAttack();
        return true;
      }
      if (key == LogicalKeyboardKey.keyE) {
        _cachedNotifier?.interactNearestNpc();
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKeyEvent);
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
      value: 0.25,
    );
    _skyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 24000),
    );
    _syncAnimationControllersForTier(gfx);
    unawaited(_syncSharedSprites(gfx));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(moradonHubProvider.notifier).setWorldViewActive(true);
        if (SupabaseService.isInitialized &&
            ref.read(leaderboardProvider).status == LeaderboardStatus.initial) {
          unawaited(
            ref
                .read(leaderboardProvider.notifier)
                .load(categoryIndex: 3, weekly: false),
          );
        }
      }
    });
  }

  void _syncAnimationControllersForTier(GraphicsProfile gfx) {
    if (gfx.isLow) {
      if (_ambientController.isAnimating) {
        _ambientController.stop();
        _ambientController.value = 0.25;
      }
      if (_skyController.isAnimating) {
        _skyController.stop();
      }
    } else {
      if (!_ambientController.isAnimating) {
        _ambientController.repeat();
      }
      if (gfx.enableWeatherAndAtmosphere) {
        if (!_skyController.isAnimating) {
          _skyController.repeat();
        }
      } else if (_skyController.isAnimating) {
        _skyController.stop();
      }
    }
  }

  Future<void> _syncSharedSprites(GraphicsProfile gfx) async {
    if (gfx.enableGpuShaders) {
      unawaited(GpuShaderService.instance.warmUpIfEnabled());
    }
    final int? targetW = gfx.charAtlasTargetWidth;
    if (_loadedAtlasTargetWidth != targetW || _charAtlases.isEmpty) {
      _loadedAtlasTargetWidth = targetW;
      final Map<String, ui.Image> shared =
          await GraphicsQualityService.instance.loadSharedCharacterAtlases();
      if (!mounted) return;
      if (shared.isNotEmpty) {
        setState(() {
          _charAtlases
            ..clear()
            ..addAll(shared);
        });
      }
    }

    if (_merchantStallImage == null && !_merchantStallLoading) {
      _merchantStallLoading = true;
      try {
        final ByteData raw =
            await rootBundle.load('assets/moradon/merchant_stall.png');
        final ui.Codec codec = await ui.instantiateImageCodec(
          raw.buffer.asUint8List(),
          targetWidth: 144,
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        if (mounted) {
          setState(() => _merchantStallImage = frame.image);
        }
      } catch (_) {
        // Test environment or missing asset fallback
      } finally {
        _merchantStallLoading = false;
      }
    }

    if (gfx.enableCompanionPets && (!_loadedPetsState || _petImages.isEmpty)) {
      _loadedPetsState = true;
      final Map<String, ui.Image> rawPets =
          await GraphicsQualityService.instance.loadSharedPetSprites();
      if (!mounted) return;
      setState(() {
        _petImages.clear();
        if (rawPets['solarPhoenix'] != null) {
          _petImages[MoradonPetVisual.solarPhoenix] = rawPets['solarPhoenix']!;
        }
        if (rawPets['shadowRaven'] != null) {
          _petImages[MoradonPetVisual.shadowRaven] = rawPets['shadowRaven']!;
        }
        if (rawPets['arcaneWisp'] != null) {
          _petImages[MoradonPetVisual.arcaneWisp] = rawPets['arcaneWisp']!;
        }
        if (rawPets['royalGriffin'] != null) {
          _petImages[MoradonPetVisual.royalGriffin] = rawPets['royalGriffin']!;
        }
      });
    } else if (!gfx.enableCompanionPets && _petImages.isNotEmpty) {
      _loadedPetsState = false;
      setState(_petImages.clear);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKeyEvent);
    _heldMoveKeys.clear();
    _cachedNotifier?.setWorldViewActive(false);
    _ambientController.dispose();
    _skyController.dispose();
    super.dispose();
  }

  String _resolveClassKey(String rawClass) {
    final String lower = rawClass.toLowerCase();
    if (lower.contains('golge') || lower.contains('shadow')) {
      return 'golge';
    }
    if (lower.contains('simyaci') || lower.contains('alchemist')) {
      return 'simyaci';
    }
    return 'savasci';
  }

  Color _resolveGlowColor(int glowLevel) {
    if (glowLevel >= 10) return const Color(0xFFEA580C); // +10 Cehennem Koru
    if (glowLevel == 9) return const Color(0xFFF59E0B); // +9 Hükümdar Altını
    if (glowLevel == 8) return const Color(0xFFD97706); // +8 Kehribar Çelik
    return const Color(0xFF93C5FD); // +7 Buzul Çeliği
  }

  int _resolveLocalGlowLevel() {
    int maxEnh = 0;
    for (final InventoryItem? item
        in widget.inventoryState.equippedItems.values) {
      if (item != null && item.enhancementLevel > maxEnh) {
        maxEnh = item.enhancementLevel;
      }
    }
    if (maxEnh >= 7) {
      return maxEnh.clamp(7, 10);
    }
    if (widget.totalPower >= 8000) return 10;
    if (widget.totalPower >= 4000) return 9;
    if (widget.totalPower >= 1500) return 8;
    return 7;
  }

  String? _resolveLandmarkLiveRibbon({
    required String npcId,
    required RetentionPromos promos,
    required bool canClaimDaily,
    required KingdomMarketBlessingStatus blessing,
    required MoradonAtmospherePhase atmosphere,
  }) {
    switch (npcId) {
      case 'monument_center':
        if (canClaimDaily) return '🎁 GÜNLÜK ÖDÜL HAZIR';
        if (blessing.active) return '👑 KRALLIK KUTSAMASI AKTİF';
        return null;
      case 'teleport_gate':
        if (atmosphere == MoradonAtmospherePhase.siegeStorm) {
          return '⚡ KUŞATMA SAATİ AKTİF';
        }
        if (atmosphere == MoradonAtmospherePhase.bloodMoon) {
          return '🩸 KANLI AY TUTULMASI';
        }
        return null;
      case 'grand_bazaar':
        if (promos.nightMarket.active ||
            atmosphere == MoradonAtmospherePhase.nightMarket) {
          return '🌙 GECE PAZARI AÇIK';
        }
        if (blessing.active) return '👑 PAZAR İNDİRİMİ AKTİF';
        return null;
      case 'guard_captain':
        if (promos.codex.claimableMilestones > 0) {
          return '📖 KODEX ÖDÜLÜ (${promos.codex.claimableMilestones})';
        }
        return null;
      case 'arena_clan':
        if (promos.nemesis.hasRival && !promos.nemesis.dismissed) {
          return '⚔️ NEMESIS RAKİP AKTİF';
        }
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile gfx = ref.watch(graphicsQualityProvider).profile;
    _syncAnimationControllersForTier(gfx);
    if (_loadedAtlasTargetWidth != gfx.charAtlasTargetWidth ||
        (gfx.enableCompanionPets != _loadedPetsState)) {
      unawaited(_syncSharedSprites(gfx));
    }

    final MoradonHubState hubState = ref.watch(moradonHubProvider);
    final MoradonHubNotifier notifier = ref.read(moradonHubProvider.notifier);
    _cachedNotifier = notifier;
    final LeaderboardState lbState = ref.watch(leaderboardProvider);
    final (String kingName, String kingPwrLabel) = _resolvePantheonSovereign(
      lbState: lbState,
      hubState: hubState,
    );
    final RetentionPromos promos = ref.watch(retentionPromosProvider).promos;
    final bool canClaimDaily =
        ref.watch(dailyRewardProvider).status?.canClaim ?? false;
    final KingdomMarketBlessingStatus blessing =
        ref.watch(kingdomMarketBlessingProvider);
    final bool siegeLive =
        ref.watch(dungeonSiegeProvider).status.siegeActive;
    final MoradonAtmospherePhase atmosphere = resolveLiveAtmospherePhase(
      choice: hubState.atmosphereChoice,
      nightMarketActive: promos.nightMarket.active,
      siegeLive: siegeLive,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewW = constraints.maxWidth;
        final double viewH = constraints.maxHeight;
        if (!hubState.responsiveZoomApplied && viewW > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) notifier.ensureResponsiveZoom(viewW);
          });
        }

        const double worldW = MoradonHubState.worldWidth;
        const double worldH = MoradonHubState.worldHeight;

        // Guarantee zero black void on ultrawide / 4K monitors while allowing full panoramic 0.42x zoom
        final double minZoom = math.max(
          MoradonHubState.minWorldZoom,
          math.max(viewW / worldW, viewH / worldH),
        );
        final double scale = math.max(hubState.zoom, minZoom);

        final double visibleWorldW = viewW / scale;
        final double visibleWorldH = viewH / scale;
        final double maxCamX = math.max(0.0, worldW - visibleWorldW);
        final double maxCamY = math.max(0.0, worldH - visibleWorldH);
        final double camX =
            (hubState.playerX - visibleWorldW / 2).clamp(0.0, maxCamX);
        final double vFocus = viewW < 680 ? 0.61 : 0.52;
        final double camY =
            (hubState.playerY - visibleWorldH * vFocus).clamp(0.0, maxCamY);

        // 10,000-CCU Camera Viewport Frustum (padded for tall 520px 2.5D gothic towers & spires)
        final Rect frustum = Rect.fromLTRB(
          camX - 420.0,
          camY - 460.0,
          camX + visibleWorldW + 420.0,
          camY + visibleWorldH + 620.0,
        );
        final int baseAvatarCap = viewW < 760
            ? MoradonHubState.mobileAvatarRenderCap
            : MoradonHubState.desktopAvatarRenderCap;
        final int avatarRenderCap =
            math.min(baseAvatarCap, gfx.moradonMaxAvatarRigs);

        final double atkProg = hubState.attackProgress;
        final MoradonStrikeFeedback? recentStrike = hubState.activeStrike;
        final double strikeAge = (recentStrike != null && !recentStrike.isExpired)
            ? recentStrike.ageSeconds(DateTime.now()).clamp(0.0, 1.0)
            : 1.0;
        // Pack 1 Hit-Stop & Directional Micro Camera Shake on Moradon Dummy Strikes!
        final bool inHitStop = strikeAge < 0.055;
        final double atkImpact = inHitStop
            ? 1.0
            : ((atkProg > 0.08 && atkProg < 0.52)
                  ? math.sin(((atkProg - 0.08) / 0.44) * math.pi)
                  : 0.0);
        final double punchDir = hubState.facingRight ? 1.0 : -1.0;
        double strikeShakeX = 0.0;
        double strikeShakeY = 0.0;
        if (strikeAge < 0.24) {
          final double decay = math.pow(1.0 - strikeAge / 0.24, 2.0).toDouble();
          final double amp = (recentStrike?.isCritical ?? false) ? 6.5 : 3.8;
          strikeShakeX =
              (punchDir * amp * 0.55 + math.sin(strikeAge * 72.0) * amp) *
              decay;
          strikeShakeY = math.cos(strikeAge * 54.0) * (amp * 0.42) * decay;
        }
        final Matrix4 camera3dMatrix = Matrix4.identity();
        if (hubState.is3dPerspective && gfx.enable3dPerspective) {
          if (!kIsWeb &&
              gfx.tier == GraphicsQualityTier.ultra &&
              hubState.remotePlayers.length <= 16) {
            camera3dMatrix
              ..setEntry(3, 2, 0.00028)
              ..rotateX(0.072 - atkImpact * 0.010)
              ..rotateY(punchDir * atkImpact * 0.006)
              ..multiply(
                Matrix4.diagonal3Values(
                  1.042 + atkImpact * 0.008,
                  1.064 + atkImpact * 0.008,
                  1.0,
                ),
              );
          } else {
            // Pure 2D affine isometric foreshortening: preserves 100% GPU quad batching on Web & 100+ CCU crowds!
            camera3dMatrix.multiply(
              Matrix4.diagonal3Values(
                1.016 + atkImpact * 0.008,
                0.972 + atkImpact * 0.008,
                1.0,
              ),
            );
          }
        }
        if (strikeShakeX != 0.0 || strikeShakeY != 0.0) {
          camera3dMatrix.setTranslationRaw(strikeShakeX, strikeShakeY, 0.0);
        }

        final Widget staticCourtyardFloor = Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // 0a. Instant Procedural Dark-Gothic Flagstone Courtyard Underlay
                  const CustomPaint(
                    painter: _GothicDungeonFlagstoneFallbackPainter(),
                  ),

                  // 0b. Seamless Tiled Dungeon Flagstone Texture Underlay (skipped on Low!)
                  if (!gfx.isLow)
                    Image.asset(
                      'assets/moradon/tile_dungeon_flagstone.png',
                      repeat: ImageRepeat.repeat,
                      scale: 0.72,
                      opacity: const AlwaysStoppedAnimation<double>(0.62),
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, _, _) => Image.network(
                        'assets/assets/moradon/tile_dungeon_flagstone.png',
                        repeat: ImageRepeat.repeat,
                        scale: 0.72,
                        opacity: const AlwaysStoppedAnimation<double>(0.62),
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),

                  // 1. Dark-Gothic Nocturnal Dungeon Citadel Courtyard (downsampled per tier!)
                  Image.asset(
                    'assets/moradon/citadel_dungeon_v9.jpg',
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    cacheWidth: gfx.moradonMapCacheWidth,
                    filterQuality: gfx.filterQuality,
                    errorBuilder: (
                      BuildContext ctx,
                      Object err,
                      StackTrace? st,
                    ) {
                      return Image.network(
                        'assets/assets/moradon/citadel_dungeon_v9.jpg',
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        cacheWidth: gfx.moradonMapCacheWidth,
                        filterQuality: gfx.filterQuality,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      );
                    },
                  ),

                  // 1b. Sunken Dark-Obsidian & Molten-Bronze Dungeon Sparring Rune Pit
                  Positioned(
                    left: 3200 - 250,
                    top: 2635 - 155,
                    width: 500,
                    height: 310,
                    child: Image.asset(
                      'assets/moradon/plaza_dungeon_rune_pit.png',
                      fit: BoxFit.fill,
                      cacheWidth: gfx.isLow ? 260 : 520,
                      opacity: const AlwaysStoppedAnimation<double>(0.94),
                      filterQuality: gfx.filterQuality,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return Listener(
          onPointerSignal: (PointerSignalEvent event) {
            if (event is PointerScrollEvent) {
              final double delta = event.scrollDelta.dy < 0 ? 0.08 : -0.08;
              notifier.setZoom(
                (scale + delta).clamp(minZoom, MoradonHubState.maxWorldZoom),
              );
            }
          },
          child: ClipRect(
            child: ColoredBox(
              color: const Color(0xFF070A12),
              child: Transform(
                alignment: Alignment.center,
                transform: camera3dMatrix,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails details) {
                    final double worldX = camX + details.localPosition.dx / scale;
                    final double worldY = camY + details.localPosition.dy / scale;

                    // O(K) spatial hit-test for GPU-batched overflow crowd players (#39..#500+):
                    // tapping any crowd sprite promotes it into the selected target HUD!
                    if (_lastOverflowCrowdPlayers.isNotEmpty) {
                      final double zoomComp =
                          (0.72 / hubState.zoom).clamp(1.0, 2.02);
                      final double hitHalfW = 42.0 * zoomComp;
                      final double hitTopH = 122.0 * zoomComp;
                      MoradonPlayerPresence? hitCrowd;
                      double bestScore = double.infinity;
                      for (final MoradonPlayerPresence cp
                          in _lastOverflowCrowdPlayers) {
                        final double dx = (worldX - cp.x).abs();
                        if (dx > hitHalfW) continue;
                        if (worldY > cp.y + 10.0 ||
                            worldY < cp.y - hitTopH) {
                          continue;
                        }
                        final double dy = (worldY - (cp.y - hitTopH * 0.45)).abs();
                        final double score = dx * dx + dy * dy;
                        if (score < bestScore) {
                          bestScore = score;
                          hitCrowd = cp;
                        }
                      }
                      if (hitCrowd != null) {
                        notifier.selectRemotePlayer(hitCrowd);
                        return;
                      }
                    }

                    notifier.moveToWorldPoint(worldX, worldY);
                  },
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        left: -camX * scale,
                        top: -camY * scale,
                        width: worldW * scale,
                        height: worldH * scale,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: worldW,
                            height: worldH,
                            child: AnimatedBuilder(
                              animation: Listenable.merge(<Listenable>[
                                _ambientController,
                                _skyController,
                              ]),
                              child: staticCourtyardFloor,
                              builder: (
                                BuildContext context,
                                Widget? cachedFloor,
                              ) {
                                final double phase = _ambientController.value;
                                final double skyPhase = _skyController.value;

                                // Y-sorted depth list with 10K-CCU Frustum Culling + Nearest-K Crowd LOD!
                                final List<_DepthEntity> entities =
                                    <_DepthEntity>[];

                                for (int i = 0; i < kMoradonNpcs.length; i++) {
                                  final MoradonNpcDefinition npc =
                                      kMoradonNpcs[i];
                                  final Rect npcFrustum =
                                      npc.isArchitecturalZone
                                          ? frustum.inflate(560.0)
                                          : frustum;
                                  if (!npcFrustum.contains(Offset(npc.x, npc.y))) {
                                    continue;
                                  }
                                  entities.add(
                                    _DepthEntity(
                                      yDepth: npc.y,
                                      child: _buildNpcEntity(
                                        npc: npc,
                                        index: i,
                                        phase: phase,
                                        hubState: hubState,
                                        notifier: notifier,
                                        liveRibbon: _resolveLandmarkLiveRibbon(
                                          npcId: npc.id,
                                          promos: promos,
                                          canClaimDaily: canClaimDaily,
                                          blessing: blessing,
                                          atmosphere: atmosphere,
                                        ),
                                        sovereignUsername: kingName,
                                        sovereignPowerLabel: kingPwrLabel,
                                      ),
                                    ),
                                  );
                                }

                                // Interactive Royal Training Dummies (Sparring & Combo Targets)
                                for (final MoradonTrainingDummy dummy
                                    in kMoradonTrainingDummies) {
                                  if (!frustum.contains(Offset(dummy.x, dummy.y))) {
                                    continue;
                                  }
                                  entities.add(
                                    _DepthEntity(
                                      yDepth: dummy.y,
                                      child: _buildTrainingDummyEntity(
                                        dummy: dummy,
                                        hubState: hubState,
                                        notifier: notifier,
                                        phase: phase,
                                      ),
                                    ),
                                  );
                                }

                                // 2.5D Blender-Rendered Foreground Architectural Occlusion Props
                                if (gfx.enableForegroundOcclusion) {
                                  for (final MoradonOcclusionProp occ
                                      in kCitadelOcclusionProps) {
                                    if (!frustum.contains(Offset(occ.x, occ.y))) {
                                      continue;
                                    }
                                    entities.add(
                                      _DepthEntity(
                                        yDepth: occ.y,
                                        child: _buildOcclusionPropEntity(occ),
                                      ),
                                    );
                                  }
                                }

                                // Tavern & Royal Hippodrome Thoroughbred Racehorses
                                for (final MoradonRacehorseProp steed
                                    in kTavernRacehorses) {
                                  if (!frustum.contains(Offset(steed.x, steed.y))) {
                                    continue;
                                  }
                                  entities.add(
                                    _DepthEntity(
                                      yDepth: steed.y,
                                      child: MoradonRacehorseEntity(
                                        steed: steed,
                                        phase: phase,
                                        onTap: () =>
                                            context.push(AppRoutes.horseRace),
                                      ),
                                    ),
                                  );
                                }

                                // Patrolling Royal Citadel Halberdiers
                                if (gfx.moradonEnablePatrolGuards) {
                                  for (final MoradonPatrolGuard guard
                                      in hubState.patrolGuards) {
                                    if (!frustum.contains(Offset(guard.x, guard.y))) {
                                      continue;
                                    }
                                    entities.add(
                                      _DepthEntity(
                                        yDepth: guard.y,
                                        child: _buildPatrolGuardEntity(
                                          guard,
                                          hubState,
                                          phase,
                                          skyPhase,
                                        ),
                                      ),
                                    );
                                  }
                                }

                                // Y-Sorted Dark-Gothic Gargoyle Fire Braziers framing Fountain Steps & Avenue
                                if (gfx.moradonEnableBraziers) {
                                  const List<Offset> royalBrazierCoords =
                                      <Offset>[
                                    Offset(2910, 2445),
                                    Offset(3490, 2445),
                                    Offset(2890, 2910),
                                    Offset(3510, 2910),
                                  ];
                                  for (int bi = 0;
                                      bi < royalBrazierCoords.length;
                                      bi++) {
                                    final Offset bPos = royalBrazierCoords[bi];
                                    if (!frustum.contains(bPos)) continue;
                                    entities.add(
                                      _DepthEntity(
                                        yDepth: bPos.dy,
                                        child: _buildRoyal3dBrazierEntity(
                                          bPos,
                                          phase,
                                          bi,
                                        ),
                                      ),
                                    );
                                  }
                                }

                                // Spatial Hash Grid Query + Nearest-K Crowd LOD for 10,000+ CCU scalability
                                final List<MoradonPlayerPresence> inFrustum;
                                if (hubState.remotePlayers.length <= 64) {
                                  inFrustum = <MoradonPlayerPresence>[
                                    for (final MoradonPlayerPresence rp
                                        in hubState.remotePlayers.values)
                                      if (frustum.contains(Offset(rp.x, rp.y)))
                                        rp,
                                  ];
                                } else {
                                  final MoradonSpatialGrid<MoradonPlayerPresence>
                                      spatialGrid =
                                      MoradonSpatialGrid<MoradonPlayerPresence>(
                                    worldWidth: worldW,
                                    worldHeight: worldH,
                                    cellSize: 400.0,
                                  );
                                  for (final MoradonPlayerPresence rp
                                      in hubState.remotePlayers.values) {
                                    spatialGrid.insert(rp.x, rp.y, rp);
                                  }
                                  inFrustum = spatialGrid
                                      .queryRect(frustum)
                                      .where(
                                        (MoradonPlayerPresence rp) =>
                                            frustum.contains(Offset(rp.x, rp.y)),
                                      )
                                      .toList();
                                }

                                List<MoradonPlayerPresence> fullRigPlayers =
                                    inFrustum;
                                List<MoradonPlayerPresence> lodCrestPlayers =
                                    const <MoradonPlayerPresence>[];
                                if (inFrustum.length > avatarRenderCap) {
                                  final String? myGuild =
                                      widget.profile.guildName;
                                  final String? selId =
                                      hubState.selectedRemoteUserId;
                                  inFrustum.sort(
                                    (
                                      MoradonPlayerPresence a,
                                      MoradonPlayerPresence b,
                                    ) {
                                      final int aSel =
                                          a.userId == selId ? 0 : 1;
                                      final int bSel =
                                          b.userId == selId ? 0 : 1;
                                      if (aSel != bSel) {
                                        return aSel.compareTo(bSel);
                                      }
                                      final int aGuild = (myGuild != null &&
                                              myGuild.isNotEmpty &&
                                              a.guildName == myGuild)
                                          ? 0
                                          : 1;
                                      final int bGuild = (myGuild != null &&
                                              myGuild.isNotEmpty &&
                                              b.guildName == myGuild)
                                          ? 0
                                          : 1;
                                      if (aGuild != bGuild) {
                                        return aGuild.compareTo(bGuild);
                                      }
                                      final double da = (a.x - hubState.playerX) *
                                              (a.x - hubState.playerX) +
                                          (a.y - hubState.playerY) *
                                              (a.y - hubState.playerY);
                                      final double db = (b.x - hubState.playerX) *
                                              (b.x - hubState.playerX) +
                                          (b.y - hubState.playerY) *
                                              (b.y - hubState.playerY);
                                      return da.compareTo(db);
                                    },
                                  );
                                  fullRigPlayers =
                                      inFrustum.sublist(0, avatarRenderCap);
                                  lodCrestPlayers =
                                      inFrustum.sublist(avatarRenderCap)
                                        ..sort(
                                          (
                                            MoradonPlayerPresence a,
                                            MoradonPlayerPresence b,
                                          ) =>
                                              a.y.compareTo(b.y),
                                        );
                                }
                                _lastOverflowCrowdPlayers = lodCrestPlayers;

                                for (final MoradonPlayerPresence rp
                                    in fullRigPlayers) {
                                  entities.add(
                                    _DepthEntity(
                                      yDepth: rp.y,
                                      child: _buildRemotePlayerEntity(
                                        rp,
                                        hubState,
                                        notifier,
                                        phase,
                                        skyPhase,
                                      ),
                                    ),
                                  );
                                }

                                entities.add(
                                  _DepthEntity(
                                    yDepth: hubState.playerY,
                                    child: _buildLocalPlayerEntity(
                                      hubState,
                                      phase,
                                      skyPhase,
                                      gfx,
                                    ),
                                  ),
                                );

                                if (hubState.worldBoss.isActive &&
                                    frustum.contains(
                                      Offset(
                                        hubState.worldBoss.x,
                                        hubState.worldBoss.y,
                                      ),
                                    )) {
                                  entities.add(
                                    _DepthEntity(
                                      yDepth: hubState.worldBoss.y,
                                      child: _buildWorldBossEntity(
                                        boss: hubState.worldBoss,
                                        hubState: hubState,
                                        notifier: notifier,
                                        phase: phase,
                                        gfx: gfx,
                                      ),
                                    ),
                                  );
                                }

                                entities.sort(
                                  (_DepthEntity a, _DepthEntity b) =>
                                      a.yDepth.compareTo(b.yDepth),
                                );

                                final double crowdZoomComp =
                                    (0.72 / hubState.zoom).clamp(1.0, 2.02);

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: <Widget>[
                                    cachedFloor!,

                                    // 2. Frustum-Culled Live Architectural VFX
                                    if (gfx.enableArchitecturalVfx)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter:
                                                CitadelArchitecturalVfxPainter(
                                              phase: phase,
                                              skyPhase: skyPhase,
                                              frustum: frustum,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // 2b. Single-Pass GPU Sprite-Atlas Batch Renderer for 100-500+ Overflow Crowd Players
                                    if (lodCrestPlayers.isNotEmpty)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _MoradonCrowdLodPainter(
                                              overflowPlayers: lodCrestPlayers,
                                              charAtlases: _charAtlases,
                                              merchantStallImage:
                                                  _merchantStallImage,
                                              zoomComp: crowdZoomComp,
                                              phase: phase,
                                              filterQuality: gfx.filterQuality,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // 3. Isometric Click-to-Move Arcane Breadcrumb Path & Dual Target Ripples
                                    if (hubState.moveRingPosition != null)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _MovePathPainter(
                                              from: Offset(
                                                hubState.playerX,
                                                hubState.playerY,
                                              ),
                                              to: hubState.moveRingPosition!,
                                              phase: phase,
                                              isMoving: hubState.isMoving,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // 4. Y-Sorted Isometric Landmarks, Steeds, Patrol Guards, Dummies, Merchants & Players
                                    for (final _DepthEntity e in entities)
                                      e.child,

                                    // 4b. Live Floating RPG Strike Damage & Combo Style Rank Callouts
                                    if (hubState.activeStrike != null &&
                                        !hubState.activeStrike!.isExpired)
                                      _buildMoradonStrikeCallout(
                                        hubState.activeStrike!,
                                        hubState.zoom,
                                      ),

                                    // 5. Sky-Piercing +9/+10 Forge & Legendary Crate Celebration Pillar
                                    if (hubState.activeCelebration != null &&
                                        !hubState.activeCelebration!.isExpired)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter:
                                                MoradonCelebrationPillarPainter(
                                              event:
                                                  hubState.activeCelebration!,
                                              phase: phase,
                                              frustum: frustum,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // 6. Frustum-Culled Volumetric Atmosphere, Mist & Forge Sparks
                                    if (gfx.enableWeatherAndAtmosphere)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _CitadelAtmospherePainter(
                                              phase: phase,
                                              skyPhase: skyPhase,
                                              frustum: frustum,
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
                      ),

                      // 7. Viewport Screen-Space Weather Overlay (96% fewer pixels than 6400x3600 world!)
                      if (gfx.enableWeatherAndAtmosphere &&
                          atmosphere != MoradonAtmospherePhase.twilight)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: Listenable.merge(<Listenable>[
                                _ambientController,
                                _skyController,
                              ]),
                              builder: (BuildContext context, Widget? _) {
                                return CustomPaint(
                                  painter: MoradonDynamicWeatherPainter(
                                    atmosphere: atmosphere,
                                    phase: _ambientController.value,
                                    skyPhase: _skyController.value,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrainingDummyEntity({
    required MoradonTrainingDummy dummy,
    required MoradonHubState hubState,
    required MoradonHubNotifier notifier,
    required double phase,
  }) {
    final MoradonStrikeFeedback? strike = hubState.activeStrike;
    final bool isHit =
        strike != null && !strike.isExpired && strike.hitDummyId == dummy.id;
    final double ageSec =
        isHit ? strike.ageSeconds(DateTime.now()).clamp(0.0, 1.0) : 1.0;
    final double recoilDecay =
        isHit ? math.pow(1.0 - ageSec, 2.2).toDouble() : 0.0;
    final double pushDir = hubState.playerX <= dummy.x ? 1.0 : -1.0;
    final double pendulumTilt =
        isHit ? math.sin(ageSec * 28.0) * 0.24 * recoilDecay * pushDir : 0.0;
    final double hitFlash =
        isHit && ageSec < 0.26 ? (1.0 - ageSec / 0.26).clamp(0.0, 1.0) : 0.0;

    final double zoomComp = (0.72 / hubState.zoom).clamp(1.0, 1.52);
    final Widget dummyImage = Image.asset(
      (dummy.id == 'dummy_plaza_east' || dummy.id == 'dummy_colosseum')
          ? 'assets/moradon/prop_dungeon_dummy_boss.png'
          : 'assets/moradon/prop_dungeon_dummy_iron.png',
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    return Positioned(
      key: Key('moradon_dummy_${dummy.id}'),
      left: dummy.x - 95,
      bottom: MoradonHubState.worldHeight - dummy.y,
      width: 190,
      child: Transform.scale(
        scale: zoomComp,
        alignment: Alignment.bottomCenter,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              HapticFeedback.mediumImpact();
              notifier.interactWithTrainingDummy(dummy);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RepaintBoundary(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xDD0B1120),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: dummy.accentColor.withValues(alpha: 0.72),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.gps_fixed_rounded,
                              size: 10.5,
                              color: dummy.accentColor,
                            ),
                            const SizedBox(width: 3.5),
                            Flexible(
                              child: Text(
                                dummy.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFEF08A),
                                  fontSize: 9.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const _KoOutlinedText(
                        text: 'Vurmak için Dokun • Saldır',
                        fontSize: 8.6,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                RepaintBoundary(
                  child: Transform.rotate(
                    alignment: Alignment.bottomCenter,
                    angle: pendulumTilt,
                    child: SizedBox(
                      width: 120,
                      height: 144,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          // Ground contact shadow + reactive runic shockwave ring
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _RoyalTrainingDummyImpactPainter(
                                accentColor: dummy.accentColor,
                                hitFlash: hitFlash,
                                recoilDecay: recoilDecay,
                                phase: isHit ? phase : 0.25,
                              ),
                            ),
                          ),
                          // Keep dark-iron & stone dummy crisp (no milk-grey srcATop wash!)
                          Positioned(
                            bottom: 8,
                            width: 108,
                            height: 134,
                            child: dummyImage,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoyal3dBrazierEntity(Offset pos, double phase, int seedIndex) {
    return Positioned(
      left: pos.dx - 78,
      bottom: MoradonHubState.worldHeight - pos.dy - 10,
      width: 156,
      height: 192,
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: <Widget>[
              // Warm ground pool + shadow
              Positioned(
                bottom: 2,
                child: Container(
                  width: 142,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: RadialGradient(
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.78),
                        const Color(0xFFFB923C).withValues(alpha: 0.24),
                        Colors.transparent,
                      ],
                      stops: const <double>[0.0, 0.56, 1.0],
                    ),
                  ),
                ),
              ),
              // Dark-Gothic Gargoyle Wrought-Iron Dungeon Fire Brazier
              Positioned(
                bottom: 6,
                width: 136,
                height: 176,
                child: Image.asset(
                  'assets/moradon/prop_dungeon_brazier_gothic.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              // Warm firelight bloom around flame crown
              Positioned(
                top: -4,
                child: Container(
                  width: 114,
                  height: 114,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        const Color(0xFFFEF08A).withValues(alpha: 0.28),
                        const Color(0xFFF97316).withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                      stops: const <double>[0.0, 0.48, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoradonStrikeCallout(MoradonStrikeFeedback strike, double zoom) {
    final double age = strike.ageSeconds(DateTime.now()).clamp(0.0, 1.15);
    final double normT = (age / 1.15).clamp(0.0, 1.0);
    final double zoomComp = (0.72 / zoom).clamp(1.0, 1.65);
    final double riseY = Curves.easeOutCubic.transform(normT) * 62.0 * zoomComp;
    final double alpha = normT < 0.72
        ? 1.0
        : ((1.0 - normT) / 0.28).clamp(0.0, 1.0);
    final double popScale = (normT < 0.16
            ? ui.lerpDouble(0.68, strike.isCritical ? 1.22 : 1.06, normT / 0.16)!
            : ui.lerpDouble(
                strike.isCritical ? 1.22 : 1.06,
                1.0,
                ((normT - 0.16) / 0.34).clamp(0.0, 1.0),
              )!) *
        zoomComp;
    final ({String grade, Color color}) rank =
        resolveMoradonStyleRank(strike.comboStreak);
    final String formattedDmg = formatCharacterPower(strike.damage);

    return Positioned(
      left: strike.worldX - 130,
      top: strike.worldY - riseY,
      width: 260,
      child: IgnorePointer(
        child: Opacity(
          opacity: alpha,
          child: Transform.scale(
            scale: popScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (strike.comboStreak >= 2)
                  Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE6090D18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: rank.color, width: 1.2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: rank.color.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.whatshot_rounded,
                          size: 11,
                          color: rank.color,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${rank.grade} STİL • KOMBO x${strike.comboStreak}',
                          style: TextStyle(
                            color: rank.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  strike.isCritical
                      ? '⚡ $formattedDmg KRİTİK!'
                      : formattedDmg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: strike.isCritical
                        ? const Color(0xFFFEF08A)
                        : Colors.white,
                    fontSize: strike.isCritical ? 21 : 17,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    shadows: <Shadow>[
                      Shadow(
                        color: strike.isCritical
                            ? const Color(0xFFF97316)
                            : const Color(0xFF38BDF8),
                        blurRadius: 14,
                      ),
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 6,
                        offset: Offset(0, 2),
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

  Widget _buildOcclusionPropEntity(MoradonOcclusionProp occ) {
    final bool isLargeStronghold = occ.width >= 300.0;

    return Positioned(
      left: occ.x - occ.width / 2,
      bottom: MoradonHubState.worldHeight - occ.y,
      width: occ.width,
      height: occ.height,
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                bottom: isLargeStronghold ? -12 : 0,
                child: Container(
                  width: occ.width * (isLargeStronghold ? 1.06 : 1.18),
                  height: isLargeStronghold ? 112 : 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: RadialGradient(
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.86),
                        (occ.lightColor ?? Colors.amber).withValues(
                          alpha: isLargeStronghold ? 0.22 : 0.16,
                        ),
                        Colors.transparent,
                      ],
                      stops: const <double>[0.0, 0.62, 1.0],
                    ),
                  ),
                ),
              ),
              Image.asset(
                occ.assetPath,
                width: occ.width,
                height: occ.height,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.medium,
                errorBuilder: (BuildContext ctx, Object err, StackTrace? st) {
                  return Image.network(
                    'assets/${occ.assetPath}',
                    width: occ.width,
                    height: occ.height,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  );
                },
              ),
              if (occ.lightColor != null && occ.lightOffset != null)
                Positioned(
                  left: occ.width / 2 +
                      occ.lightOffset!.dx -
                      (isLargeStronghold ? 72 : 36),
                  bottom: -occ.lightOffset!.dy - (isLargeStronghold ? 72 : 36),
                  width: isLargeStronghold ? 144 : 72,
                  height: isLargeStronghold ? 144 : 72,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          occ.lightColor!.withValues(
                            alpha: isLargeStronghold ? 0.28 : 0.38,
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
    );
  }

  Widget _buildNpcEntity({
    required MoradonNpcDefinition npc,
    required int index,
    required double phase,
    required MoradonHubState hubState,
    required MoradonHubNotifier notifier,
    required String? liveRibbon,
    required String sovereignUsername,
    required String sovereignPowerLabel,
  }) {
    final double pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
    final bool isTargeted = hubState.pendingNpcId == npc.id ||
        hubState.activeNpcDialog?.id == npc.id;
    final bool isHovered = _hoveredNpcId == npc.id;
    final bool highlighted = isTargeted || isHovered;
    final double spriteH = npc.spriteHeight ?? npc.spriteSize;
    final double boxW = math.max(npc.spriteSize + 130.0, 230.0);

    final double npcZoomComp = npc.isArchitecturalZone
        ? (0.64 / hubState.zoom).clamp(1.0, 1.55)
        : (0.72 / hubState.zoom).clamp(1.0, 2.02);

    // World-locked 2.5D architectural monument (Pantheon): 1:1 world scale
    // so it matches citadel_dungeon_v9.jpg sub-pixel while still Y-sorting
    // players walking behind (y < 2130) vs in front (y >= 2130).
    if (npc.isArchitecturalZone && npc.assetPath.isNotEmpty) {
      return Positioned(
        left: npc.x - npc.spriteSize / 2,
        bottom: MoradonHubState.worldHeight - 2420.0,
        width: npc.spriteSize,
        height: spriteH,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            if (_hoveredNpcId != npc.id) {
              setState(() => _hoveredNpcId = npc.id);
            }
          },
          onExit: (_) {
            if (_hoveredNpcId == npc.id) {
              setState(() => _hoveredNpcId = null);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => notifier.interactWithNpc(npc),
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: <Widget>[
                if (highlighted)
                  Positioned(
                    bottom: 18,
                    child: CustomPaint(
                      size: Size(npc.spriteSize * 0.90, 150),
                      painter: _WaypointRingPainter(
                        pulse: pulse,
                        color: npc.accentColor,
                      ),
                    ),
                  ),
                RepaintBoundary(
                  child: Image.asset(
                    npc.assetPath,
                    width: npc.spriteSize,
                    height: spriteH,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    errorBuilder:
                        (BuildContext ctx, Object err, StackTrace? st) {
                      return Image.network(
                        'assets/${npc.assetPath}',
                        width: npc.spriteSize,
                        height: spriteH,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
                if (npc.id == 'monument_center')
                  Positioned(
                    top: 382,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Transform.scale(
                        scale: npcZoomComp,
                        alignment: Alignment.bottomCenter,
                        child: PantheonSovereignStatue(
                          kingUsername: sovereignUsername,
                          kingPowerLabel: sovereignPowerLabel,
                          atlas: _charAtlases['savasci'],
                          phase: 0.25,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 505,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.scale(
                      scale: npcZoomComp,
                      alignment: Alignment.bottomCenter,
                      child: RepaintBoundary(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (liveRibbon != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      const Color(0xF00B1120),
                                      npc.accentColor.withValues(alpha: 0.34),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        npc.accentColor.withValues(alpha: 0.85),
                                    width: 1.1,
                                  ),
                                ),
                                child: Text(
                                  liveRibbon,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFEF9C3),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            _HeraldicCrestDiamond(
                              emoji: npc.badgeEmoji,
                              accentColor: npc.accentColor,
                              highlighted: highlighted,
                            ),
                            const SizedBox(height: 4),
                            _KoOutlinedText(
                              text: '<${npc.title}>',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: npc.accentColor,
                            ),
                            const SizedBox(height: 1),
                            _KoOutlinedText(
                              text: '[${npc.name}]',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: highlighted
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFFFEF08A),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: npc.x - boxW / 2,
      bottom: MoradonHubState.worldHeight - npc.y,
      width: boxW,
      child: Transform.scale(
        scale: npcZoomComp,
        alignment: Alignment.bottomCenter,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            if (_hoveredNpcId != npc.id) {
              setState(() => _hoveredNpcId = npc.id);
            }
          },
          onExit: (_) {
            if (_hoveredNpcId == npc.id) {
              setState(() => _hoveredNpcId = null);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => notifier.interactWithNpc(npc),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RepaintBoundary(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (liveRibbon != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                const Color(0xF00B1120),
                                npc.accentColor.withValues(alpha: 0.34),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: npc.accentColor.withValues(alpha: 0.85),
                              width: 1.1,
                            ),
                          ),
                          child: Text(
                            liveRibbon,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFEF9C3),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      _HeraldicCrestDiamond(
                        emoji: npc.badgeEmoji,
                        accentColor: npc.accentColor,
                        highlighted: highlighted,
                      ),
                      const SizedBox(height: 4),
                      _KoOutlinedText(
                        text: '<${npc.title}>',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: npc.accentColor,
                      ),
                      const SizedBox(height: 1),
                      _KoOutlinedText(
                        text: '[${npc.name}]',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: highlighted
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFFFEF08A),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                if (npc.isArchitecturalZone)
                  SizedBox(
                    width: npc.spriteSize,
                    height: spriteH,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        RepaintBoundary(
                          child: Container(
                            width: npc.spriteSize * 1.04,
                            height: 118,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: RadialGradient(
                                colors: <Color>[
                                  if (npc.assetPath.isNotEmpty)
                                    Colors.black.withValues(alpha: 0.86)
                                  else
                                    npc.accentColor.withValues(
                                      alpha: highlighted ? 0.22 : 0.07,
                                    ),
                                  npc.accentColor.withValues(
                                    alpha: highlighted
                                        ? (npc.assetPath.isNotEmpty
                                            ? 0.42
                                            : 0.14)
                                        : (npc.assetPath.isNotEmpty
                                            ? 0.24
                                            : 0.02),
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const <double>[0.0, 0.62, 1.0],
                              ),
                            ),
                          ),
                        ),
                        if (highlighted)
                          Positioned(
                            bottom: 6,
                            child: CustomPaint(
                              size: Size(npc.spriteSize * 0.82, 92),
                              painter: _WaypointRingPainter(
                                pulse: pulse,
                                color: npc.accentColor,
                              ),
                            ),
                          ),
                        if (npc.assetPath.isNotEmpty)
                          RepaintBoundary(
                            child: Image.asset(
                              npc.assetPath,
                              width: npc.spriteSize,
                              height: spriteH,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              filterQuality: FilterQuality.medium,
                              errorBuilder:
                                  (BuildContext ctx, Object err, StackTrace? st) {
                                return Image.network(
                                  'assets/${npc.assetPath}',
                                  width: npc.spriteSize,
                                  height: spriteH,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: npc.spriteSize + 24,
                    height: spriteH + 6,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        if (highlighted)
                          Positioned(
                            bottom: 3,
                            child: CustomPaint(
                              size: const Size(76, 26),
                              painter: _WaypointRingPainter(
                                pulse: pulse,
                                color: npc.accentColor,
                              ),
                            ),
                          ),
                        RepaintBoundary(
                          child: SizedBox(
                            width: npc.spriteSize + 24,
                            height: spriteH + 6,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: <Widget>[
                                Positioned(
                                  bottom: 1,
                                  child: Container(
                                    width: 72,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: RadialGradient(
                                        colors: <Color>[
                                          Colors.black.withValues(alpha: 0.82),
                                          npc.accentColor.withValues(
                                            alpha: highlighted ? 0.45 : 0.21,
                                          ),
                                          Colors.transparent,
                                        ],
                                        stops: const <double>[0.0, 0.62, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                Transform.flip(
                                  flipX: !npc.facingRight,
                                  child: Image.asset(
                                    npc.assetPath,
                                    width: npc.spriteSize,
                                    height: spriteH,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.bottomCenter,
                                    filterQuality: FilterQuality.medium,
                                    errorBuilder: (
                                      BuildContext ctx,
                                      Object err,
                                      StackTrace? st,
                                    ) {
                                      return Image.network(
                                        'assets/${npc.assetPath}',
                                        width: npc.spriteSize,
                                        height: spriteH,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                        filterQuality: FilterQuality.medium,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      );
                                    },
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
          ),
        ),
      ),
    );
  }

  Widget _buildRemotePlayerEntity(
    MoradonPlayerPresence p,
    MoradonHubState hubState,
    MoradonHubNotifier notifier,
    double phase,
    double skyPhase,
  ) {
    final MoradonChatBubble? bubble = hubState.chatBubbles[p.userId];
    final bool showBubble = bubble != null && !bubble.isExpired;
    final bool isSelected = hubState.selectedRemoteUserId == p.userId;
    final bool isHovered = _hoveredPlayerId == p.userId;
    final bool moving =
        !p.isMerchant &&
        ((p.targetX - p.x).abs() > 2.0 || (p.targetY - p.y).abs() > 2.0);
    final Color glowColor = _resolveGlowColor(p.weaponGlowLevel);
    final String classKey = _resolveClassKey(p.characterClass);

    final double zoomComp = (0.72 / hubState.zoom).clamp(1.0, 1.72);

    return Positioned(
      key: ValueKey<String>('moradon_remote_avatar_${p.userId}'),
      left: p.x - 118,
      bottom: MoradonHubState.worldHeight - p.y,
      width: 236,
      child: Transform.scale(
        scale: zoomComp,
        alignment: Alignment.bottomCenter,
        child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (_hoveredPlayerId != p.userId) {
            setState(() => _hoveredPlayerId = p.userId);
          }
        },
        onExit: (_) {
          if (_hoveredPlayerId == p.userId) {
            setState(() => _hoveredPlayerId = null);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => notifier.selectRemotePlayer(p),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              RepaintBoundary(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (showBubble) _buildSpeechBubble(bubble.message),
                    if (p.isMerchant)
                      _buildMerchantBanner(
                        p.merchantTitle ?? '${p.username} Pazar Tezgahı',
                      ),
                    if (p.cosmeticTitle != null && p.cosmeticTitle!.isNotEmpty)
                      _KoOutlinedText(
                        text: '«${p.cosmeticTitle}»',
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD8B4FE),
                      ),
                    if (p.guildName != null && p.guildName!.isNotEmpty)
                      _KoOutlinedText(
                        text: '<${p.guildName}>',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF86EFAC),
                      ),
                    _KoOutlinedText(
                      text: 'Lv.${p.level} ${p.username}',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? const Color(0xFF4ADE80)
                          : (isHovered
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFFF8FAFC)),
                    ),
                    CharacterNameplatePowerBadge(
                      power: p.totalPower,
                      isHighlighted: isSelected || isHovered,
                    ),
                    const SizedBox(height: 3),
                    _buildMiniHpStrip(
                      isLocal: false,
                      isSelected: isSelected || isHovered,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              if (p.isMerchant)
                _buildMerchantStallSprite(
                  glowColor: glowColor,
                  highlighted: isSelected || isHovered,
                )
              else
                _buildCharacterAvatar(
                  classKey: classKey,
                  facingRight: p.facingRight,
                  facingBack: p.facingBack,
                  isMoving: moving,
                  walkPhase: p.walkPhase,
                  idlePhase: (phase + p.userId.hashCode * 0.13) % 1.0,
                  orbitPhase: (skyPhase * 6.0 + p.userId.hashCode * 0.19) % 1.0,
                  glowLevel: p.weaponGlowLevel,
                  glowColor: glowColor,
                  weaponVisual: p.weaponVisual,
                  petVisual: GraphicsQualityService
                          .instance.profile.enableRemoteCompanionPets
                      ? p.petVisual
                      : MoradonPetVisual.none,
                  isLocal: false,
                  isSelected: isSelected,
                  isHovered: isHovered,
                  attackProgress: p.attackProgress,
                  comboStage: p.comboStage,
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPatrolGuardEntity(
    MoradonPatrolGuard g,
    MoradonHubState hubState,
    double phase,
    double skyPhase,
  ) {
    final MoradonChatBubble? bubble = hubState.chatBubbles[g.id];
    final bool showBubble = bubble != null && !bubble.isExpired;
    final double guardZoomComp = (0.72 / hubState.zoom).clamp(1.0, 1.68);
    return Positioned(
      left: g.x - 110,
      bottom: MoradonHubState.worldHeight - g.y,
      width: 220,
      child: Transform.scale(
        scale: guardZoomComp,
        alignment: Alignment.bottomCenter,
        child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            showCharacterInspectModal(
              context: context,
              seed: InspectedCharacterData.fromPatrolGuard(g),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              RepaintBoundary(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (showBubble) _buildSpeechBubble(bubble.message),
                    _KoOutlinedText(
                      text: '<${g.title}>',
                      fontSize: 9.8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF93C5FD),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.shield_rounded,
                          size: 11,
                          color: Color(0xFF93C5FD),
                        ),
                        const SizedBox(width: 3),
                        _KoOutlinedText(
                          text: g.name,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ],
                    ),
                    CharacterNameplatePowerBadge(power: g.totalPower),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              _buildCharacterAvatar(
                classKey: 'savasci',
                facingRight: g.facingRight,
                facingBack: g.facingBack,
                isMoving: true,
                walkPhase: g.walkPhase,
                idlePhase: phase,
                orbitPhase: (skyPhase * 4.0) % 1.0,
                glowLevel: 7,
                glowColor: const Color(0xFF60A5FA),
                weaponVisual: MoradonWeaponVisual.imperialHalberd,
                petVisual: MoradonPetVisual.none,
                isLocal: false,
                isSelected: false,
                isHovered: false,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildLocalPlayerEntity(
    MoradonHubState hubState,
    double phase,
    double skyPhase,
    GraphicsProfile gfx,
  ) {
    final PlayerProfile me = widget.profile;
    final MoradonChatBubble? bubble = hubState.chatBubbles[me.id] ??
        hubState.chatBubbles['local_player'];
    final bool showBubble = bubble != null && !bubble.isExpired;
    final MoradonEmoteBubble? emote = hubState.activeEmote;
    final bool showEmote = emote != null && !emote.isExpired;
    final int glowLvl = _resolveLocalGlowLevel();
    final Color glowColor = _resolveGlowColor(glowLvl);
    final String classKey =
        _resolveClassKey(me.characterClass?.name ?? 'savasci');
    final (MoradonWeaponVisual weaponVis, String _) = resolveEquippedWeaponSpec(
      inventoryState: widget.inventoryState,
      classKey: classKey,
      glowLevel: glowLvl,
    );
    final MoradonPetVisual petVis = resolveHeroPetVisual(
      classKey: classKey,
      totalPower: widget.totalPower,
      level: me.level,
    );

    final double zoomComp = (0.72 / hubState.zoom).clamp(1.0, 1.72);
    final double localHpRatio = me.maxHealth > 0
        ? (me.health / me.maxHealth).clamp(0.05, 1.0)
        : 1.0;

    return Positioned(
      left: hubState.playerX - 122,
      bottom: MoradonHubState.worldHeight - hubState.playerY,
      width: 244,
      child: Transform.scale(
        scale: zoomComp,
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showEmote) _buildEmoteCrestBubble(emote, phase),
            RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (showBubble) _buildSpeechBubble(bubble.message),
                  if (hubState.isMerchant)
                    _buildMerchantBanner(
                      hubState.merchantTitle ?? '${me.username} Pazar Tezgahı',
                    ),
                  if (hubState.mountedSteed.isMounted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEB090E1C),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: hubState.mountedSteed.accentColor
                              .withValues(alpha: 0.82),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        '🐎 ${hubState.mountedSteed.labelTr} • +%34 Hız',
                        style: TextStyle(
                          color: hubState.mountedSteed.accentColor,
                          fontSize: 9.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  if (me.cosmeticTitle != null && me.cosmeticTitle!.isNotEmpty)
                    _KoOutlinedText(
                      text: '«${me.cosmeticTitle}»',
                      fontSize: 10.2,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFDE68A),
                    ),
                  if (me.guildName != null && me.guildName!.isNotEmpty)
                    _KoOutlinedText(
                      text: '<${me.guildName}>',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF86EFAC),
                    ),
                  _KoOutlinedText(
                    text: '★ Lv.${me.level} ${me.username}',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFDE047),
                  ),
                  CharacterNameplatePowerBadge(
                    power: widget.totalPower,
                    isLocal: true,
                  ),
                  const SizedBox(height: 3),
                  _buildMiniHpStrip(
                    isLocal: true,
                    isSelected: false,
                    hpRatio: localHpRatio,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            if (hubState.isMerchant)
              _buildMerchantStallSprite(
                glowColor: glowColor,
                highlighted: true,
              )
            else if (hubState.mountedSteed.isMounted)
              _buildMountedCharacterAvatar(
                mount: hubState.mountedSteed,
                gfx: gfx,
                facingRight: hubState.facingRight,
                isMoving: hubState.isMoving,
                walkPhase: hubState.walkPhase,
                idlePhase: phase,
                riderAvatar: _buildCharacterAvatar(
                  classKey: classKey,
                  facingRight: hubState.facingRight,
                  facingBack: hubState.facingBack,
                  isMoving: false,
                  walkPhase: hubState.walkPhase,
                  idlePhase: phase,
                  orbitPhase: (skyPhase * 6.0) % 1.0,
                  glowLevel: glowLvl,
                  glowColor: glowColor,
                  weaponVisual: weaponVis,
                  petVisual:
                      GraphicsQualityService.instance.profile.enableCompanionPets
                          ? petVis
                          : MoradonPetVisual.none,
                  isLocal: true,
                  isSelected: false,
                  isHovered: false,
                  attackProgress: hubState.attackProgress,
                  comboStage: hubState.comboStage,
                ),
              )
            else
              _buildCharacterAvatar(
                classKey: classKey,
                facingRight: hubState.facingRight,
                facingBack: hubState.facingBack,
                isMoving: hubState.isMoving,
                walkPhase: hubState.walkPhase,
                idlePhase: phase,
                orbitPhase: (skyPhase * 6.0) % 1.0,
                glowLevel: glowLvl,
                glowColor: glowColor,
                weaponVisual: weaponVis,
                petVisual:
                    GraphicsQualityService.instance.profile.enableCompanionPets
                        ? petVis
                        : MoradonPetVisual.none,
                isLocal: true,
                isSelected: false,
                isHovered: false,
                attackProgress: hubState.attackProgress,
                comboStage: hubState.comboStage,
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMiniHpStrip({
    required bool isLocal,
    required bool isSelected,
    double hpRatio = 1.0,
  }) {
    final double clampedRatio = hpRatio.clamp(0.05, 1.0);
    return Container(
      width: isLocal ? 50 : 44,
      height: 5.0,
      decoration: BoxDecoration(
        color: const Color(0xDD090D16),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isLocal
              ? const Color(0xFFFBBF24).withValues(alpha: 0.85)
              : (isSelected
                  ? const Color(0xFF4ADE80)
                  : Colors.black.withValues(alpha: 0.88)),
          width: 0.8,
        ),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: clampedRatio,
        heightFactor: 1.0,
        child: DecoratedBox(
          key: isLocal ? const Key('moradon_local_hp_fill') : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: isLocal
                  ? const <Color>[Color(0xFFDC2626), Color(0xFFF87171)]
                  : const <Color>[Color(0xFFB91C1C), Color(0xFFEF4444)],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildMerchantStallSprite({
    required Color glowColor,
    required bool highlighted,
  }) {
    return RepaintBoundary(
      child: SizedBox(
        width: 118,
        height: 112,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            Positioned(
              bottom: 3,
              child: Container(
                width: 96,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.78),
                      glowColor.withValues(alpha: highlighted ? 0.30 : 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Image.asset(
              'assets/moradon/merchant_stall.png',
              width: 108,
              height: 108,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Image.network(
                'assets/assets/moradon/merchant_stall.png',
                width: 108,
                height: 108,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterAvatar({
    required String classKey,
    required bool facingRight,
    required bool facingBack,
    required bool isMoving,
    required double walkPhase,
    required double idlePhase,
    required double orbitPhase,
    required int glowLevel,
    required Color glowColor,
    required MoradonWeaponVisual weaponVisual,
    required MoradonPetVisual petVisual,
    required bool isLocal,
    required bool isSelected,
    required bool isHovered,
    double attackProgress = 0.0,
    int comboStage = 0,
  }) {
    final Size boxSize = isLocal ? const Size(116, 140) : const Size(106, 128);
    final ui.Image? atlas = _charAtlases[classKey];

    return SizedBox(
      width: boxSize.width,
      height: boxSize.height,
      child: atlas == null
          ? const SizedBox.expand()
          : CustomPaint(
              size: boxSize,
              painter: _MoradonCharacterAtlasPainter(
                atlas: atlas,
                classKey: classKey,
                petImages: _petImages,
                facingRight: facingRight,
                facingBack: facingBack,
                isMoving: isMoving,
                walkPhase: walkPhase,
                idlePhase: idlePhase,
                orbitPhase: orbitPhase,
                glowLevel: glowLevel,
                glowColor: glowColor,
                weaponVisual: weaponVisual,
                petVisual: petVisual,
                isLocal: isLocal,
                isSelected: isSelected,
                isHovered: isHovered,
                attackProgress: attackProgress,
                comboStage: comboStage,
              ),
            ),
    );
  }

  (String, String) _resolvePantheonSovereign({
    required LeaderboardState lbState,
    required MoradonHubState hubState,
  }) {
    if (lbState.entries.isNotEmpty) {
      final LeaderboardEntry top = lbState.entries.first;
      final String icon = lbState.categoryIndex < leaderboardCategories.length
          ? leaderboardCategories[lbState.categoryIndex].icon
          : '⚔️';
      return (
        top.username,
        '$icon ${LeaderboardValueFormatter.compact(top.value)}',
      );
    }
    String bestName = widget.profile.username;
    int bestPower = widget.totalPower;
    for (final MoradonPlayerPresence rp in hubState.remotePlayers.values) {
      if (rp.isAmbientBot) continue;
      if (rp.totalPower > bestPower) {
        bestPower = rp.totalPower;
        bestName = rp.username;
      }
    }
    return (bestName, '⚔️ ${LeaderboardValueFormatter.compact(bestPower)}');
  }

  Widget _buildEmoteCrestBubble(MoradonEmoteBubble emote, double phase) {
    final double bobY = math.sin(phase * math.pi * 4) * 3.0;
    return Transform.translate(
      offset: Offset(0, bobY),
      child: Container(
        key: const Key('moradon_active_emote_bubble'),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              const Color(0xF5111827),
              emote.accentColor.withValues(alpha: 0.36),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: emote.accentColor, width: 1.3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: emote.accentColor.withValues(alpha: 0.48),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(emote.emoji, style: const TextStyle(fontSize: 13.5)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                emote.labelTr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFEF9C3),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMountedCharacterAvatar({
    required MoradonMountVisual mount,
    required GraphicsProfile gfx,
    required bool facingRight,
    required bool isMoving,
    required double walkPhase,
    required double idlePhase,
    required Widget riderAvatar,
  }) {
    final double gallopBob = isMoving
        ? math.sin(walkPhase * 1.45) * 4.5
        : math.sin(idlePhase * math.pi * 2) * 1.8;
    final double gallopTilt =
        isMoving ? math.cos(walkPhase * 1.45) * 0.055 : 0.0;
    final ImageProvider<Object> steedImg = ResizeImage.resizeIfNeeded(
      gfx.isLow ? 160 : 280,
      null,
      AssetImage(mount.assetPath),
    );

    return SizedBox(
      key: const Key('moradon_mounted_steed_avatar'),
      width: 158,
      height: 162,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            bottom: 2,
            child: Container(
              width: 132,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.84),
                    mount.accentColor.withValues(alpha: isMoving ? 0.44 : 0.24),
                    Colors.transparent,
                  ],
                  stops: const <double>[0.0, 0.62, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 34 - gallopBob * 0.65,
            child: Transform.scale(
              scale: 0.86,
              alignment: Alignment.bottomCenter,
              child: riderAvatar,
            ),
          ),
          Positioned(
            bottom: 0,
            child: Transform.translate(
              offset: Offset(0, -gallopBob.abs() * 0.8),
              child: Transform.rotate(
                angle: gallopTilt * (facingRight ? 1.0 : -1.0),
                alignment: Alignment.bottomCenter,
                child: Transform.flip(
                  flipX: !facingRight,
                  child: Image(
                    image: steedImg,
                    width: 138,
                    height: 108,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: gfx.filterQuality,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldBossEntity({
    required MoradonWorldBossState boss,
    required MoradonHubState hubState,
    required MoradonHubNotifier notifier,
    required double phase,
    required GraphicsProfile gfx,
  }) {
    final MoradonStrikeFeedback? strike = hubState.activeStrike;
    final bool isHit = strike != null &&
        !strike.isExpired &&
        strike.hitDummyId == 'world_boss_tyrant';
    final double ageSec =
        isHit ? strike.ageSeconds(DateTime.now()).clamp(0.0, 1.0) : 1.0;
    final double recoilDecay =
        isHit ? math.pow(1.0 - ageSec, 2.2).toDouble() : 0.0;
    final double pushDir = hubState.playerX <= boss.x ? 1.0 : -1.0;
    final double bossTilt =
        isHit ? math.sin(ageSec * 24.0) * 0.14 * recoilDecay * pushDir : 0.0;
    final double breathScale =
        boss.isDefeated ? 0.82 : (1.0 + math.sin(phase * math.pi * 2) * 0.025);
    final double zoomComp = (0.70 / hubState.zoom).clamp(1.0, 1.58);
    final ImageProvider<Object> bossProvider = ResizeImage.resizeIfNeeded(
      gfx.isLow ? 320 : 640,
      null,
      const AssetImage('assets/v15/world_boss_tyrant.png'),
    );

    return Positioned(
      key: const Key('moradon_world_boss_entity'),
      left: boss.x - 165,
      bottom: MoradonHubState.worldHeight - boss.y,
      width: 330,
      child: Transform.scale(
        scale: zoomComp,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: notifier.interactWithWorldBoss,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xF21B0609), Color(0xF2090D18)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: boss.isDefeated
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFEF4444),
                    width: 1.35,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (boss.isDefeated
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFEF4444))
                          .withValues(alpha: 0.45),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      boss.isDefeated
                          ? '🏆 BASKIN ZAFERİ! GANİMET DAĞITILDI'
                          : '👹 MEYDAN BOSS • ${boss.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: boss.isDefeated
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFEF08A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 195,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24, width: 0.7),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: boss.hpRatio,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              colors: <Color>[
                                Color(0xFFDC2626),
                                Color(0xFFF97316),
                                Color(0xFFFBBF24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      boss.isDefeated
                          ? 'MVP: ${boss.mvpUsername} • Hasarın: ${LeaderboardValueFormatter.compact(boss.myContribution)}'
                          : 'CAN ${(boss.hpRatio * 100).toStringAsFixed(0)}% • Dokun / SALDIR ile Vur!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 9.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Transform.rotate(
                alignment: Alignment.bottomCenter,
                angle: bossTilt,
                child: Transform.scale(
                  scaleY: breathScale,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 248,
                    height: 238,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 224,
                            height: 68,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: (boss.isDefeated
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: 0.58),
                                width: 1.4,
                              ),
                              gradient: RadialGradient(
                                colors: <Color>[
                                  Colors.black.withValues(alpha: 0.88),
                                  (boss.isDefeated
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFFDC2626))
                                      .withValues(alpha: 0.42),
                                  Colors.transparent,
                                ],
                                stops: const <double>[0.0, 0.68, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: boss.isDefeated ? 0.42 : 1.0,
                          child: Image(
                            image: bossProvider,
                            width: 236,
                            height: 232,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            filterQuality: gfx.filterQuality,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.shrink(),
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
      ),
    );
  }

  Widget _buildMerchantBanner(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xEE3B1504), Color(0xEE78350F)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.1),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.storefront_rounded,
            size: 12,
            color: Color(0xFFFDE047),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFEF9C3),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xF00F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF94A3B8).withValues(alpha: 0.65),
          width: 1.0,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        message,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Sculpted floating heraldic diamond emblem hovering above each capital landmark.
class _HeraldicCrestDiamond extends StatelessWidget {
  final String emoji;
  final Color accentColor;
  final bool highlighted;

  const _HeraldicCrestDiamond({
    required this.emoji,
    required this.accentColor,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xF20D1322),
                    accentColor.withValues(alpha: highlighted ? 0.42 : 0.22),
                  ],
                ),
                borderRadius: BorderRadius.circular(4.5),
                border: Border.all(
                  color: highlighted
                      ? Colors.white
                      : accentColor.withValues(alpha: 0.85),
                  width: highlighted ? 1.4 : 1.1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accentColor.withValues(
                      alpha: highlighted ? 0.55 : 0.28,
                    ),
                    blurRadius: highlighted ? 10 : 6,
                  ),
                ],
              ),
            ),
          ),
          Text(
            emoji,
            style: const TextStyle(fontSize: 12.5, height: 1.0),
          ),
        ],
      ),
    );
  }
}

/// Frameless outlined overhead RPG nameplate text (zero Gaussian blur -> 4x faster glyph rasterization!).
class _KoOutlinedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  const _KoOutlinedText({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: 0.2,
        height: 1.15,
        shadows: const <Shadow>[
          Shadow(color: Colors.black, offset: Offset(-1.0, 1.0)),
          Shadow(color: Colors.black, offset: Offset(1.0, 1.3)),
        ],
      ),
    );
  }
}

class _WaypointRingPainter extends CustomPainter {
  final double pulse;
  final Color color;

  const _WaypointRingPainter({
    required this.pulse,
    this.color = const Color(0xFF38BDF8),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect outer = Offset.zero & size;
    final Paint ring = Paint()
      ..color = color.withValues(alpha: (0.88 - pulse * 0.35).clamp(0.28, 0.92))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(outer.deflate(2), ring);

    final Paint inner = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawOval(outer.deflate(8), inner);
  }

  @override
  bool shouldRepaint(covariant _WaypointRingPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.color != color;
}

/// Isometric Click-to-Move Arcane Breadcrumb Path & Dual Expanding Target Ripples.
class _MovePathPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final double phase;
  final bool isMoving;

  const _MovePathPainter({
    required this.from,
    required this.to,
    required this.phase,
    required this.isMoving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dual expanding isometric ripples at destination
    for (int r = 0; r < 2; r++) {
      final double t = (phase * 2.0 + r * 0.5) % 1.0;
      final Rect rippleRect = Rect.fromCenter(
        center: to,
        width: 24.0 + t * 56.0,
        height: 12.0 + t * 28.0,
      );
      canvas.drawOval(
        rippleRect,
        Paint()
          ..color = const Color(0xFF38BDF8)
              .withValues(alpha: (1.0 - t) * 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 - t * 1.1,
      );
    }

    // Center anchor diamond on target stone
    canvas.drawOval(
      Rect.fromCenter(center: to, width: 16, height: 8),
      Paint()
        ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.78)
        ..style = PaintingStyle.fill,
    );

    if (!isMoving) return;

    // 2. Glowing isometric rune-dot trail from hero boots to target
    final Offset delta = to - from;
    final double dist = delta.distance;
    if (dist < 24.0) return;

    final int steps = (dist / 28.0).clamp(2, 26).round();
    final double flow = (phase * 3.0) % 1.0;
    final Paint dotPaint = Paint()..blendMode = BlendMode.plus;

    for (int i = 1; i < steps; i++) {
      final double frac = i / steps;
      final Offset pt = from + delta * frac;
      final double wave =
          0.5 + 0.5 * math.cos((frac * 4.0 - flow) * math.pi * 2);
      final double alpha = (0.18 + wave * 0.44) * (0.4 + 0.6 * frac);
      dotPaint.color = const Color(0xFF7DD3FC).withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: pt,
          width: 6.5 + wave * 2.5,
          height: 3.4 + wave * 1.4,
        ),
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MovePathPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.phase != phase ||
      oldDelegate.isMoving != isMoving;
}

/// Foreground AAA Atmospheric Layer (Strictly Frustum-Culled to Active Viewport!):
/// - Diagonal Twilight Volumetric God-Rays
/// - Drifting Low-Lying Courtyard Mist
/// - Flying Citadel Ravens with Wing-Beats
/// - Anvil Hammer-Strike Spark Bursts, Portal Swirls & Monument Crystal Dust
class _CitadelAtmospherePainter extends CustomPainter {
  final double phase;
  final double skyPhase;
  final Rect? frustum;

  const _CitadelAtmospherePainter({
    required this.phase,
    required this.skyPhase,
    this.frustum,
  });

  bool _visiblePt(Offset pt, [double pad = 200.0]) {
    final Rect? f = frustum;
    if (f == null) return true;
    return pt.dx >= f.left - pad &&
        pt.dx <= f.right + pad &&
        pt.dy >= f.top - pad &&
        pt.dy <= f.bottom + pad;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect? f = frustum;

    // 1. Diagonal Volumetric Twilight / Moonlight God-Rays (frustum-culled!)
    const List<(double x, double width, Color tint)> shafts =
        <(double, double, Color)>[
      (980.0, 380.0, Color(0xFF93C5FD)),
      (2480.0, 480.0, Color(0xFFFDE68A)),
      (3420.0, 420.0, Color(0xFF7DD3FC)),
      (4720.0, 390.0, Color(0xFFC4B5FD)),
    ];
    for (int i = 0; i < shafts.length; i++) {
      final (double sx, double sw, Color tint) = shafts[i];
      final Rect bounds = Rect.fromLTWH(sx, 0, sw + 980.0, 2900.0);
      if (f != null && !bounds.overlaps(f)) continue;
      final double breathe =
          0.5 + 0.5 * math.sin(skyPhase * math.pi * 4 + i * 1.4);
      final double alpha = 0.030 + breathe * 0.024;
      final Path ray = Path()
        ..moveTo(sx, 0)
        ..lineTo(sx + sw, 0)
        ..lineTo(sx + sw + 980.0, 2900.0)
        ..lineTo(sx + 760.0, 2900.0)
        ..close();
      canvas.drawPath(
        ray,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              tint.withValues(alpha: alpha),
              tint.withValues(alpha: alpha * 0.45),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.52, 1.0],
          ).createShader(bounds),
      );
    }

    // 2. Drifting Low-Lying Courtyard Mist Banks (frustum-culled!)
    const List<(double baseY, double rx, double ry, double speed)> mistSpecs =
        <(double, double, double, double)>[
      (1180.0, 720.0, 180.0, 1.0),
      (1960.0, 820.0, 210.0, -1.0),
      (2680.0, 860.0, 220.0, 1.0),
      (3180.0, 760.0, 195.0, -1.0),
    ];
    for (int i = 0; i < mistSpecs.length; i++) {
      final (double my, double rx, double ry, double dir) = mistSpecs[i];
      if (f != null && (my + ry < f.top || my - ry > f.bottom)) continue;
      final double rawT = (skyPhase * dir + i * 0.27) % 1.0;
      final double mx = -600.0 + rawT * (size.width + 1200.0);
      final Rect mistRect = Rect.fromCenter(
        center: Offset(mx, my),
        width: rx * 2,
        height: ry * 2,
      );
      if (f != null && !mistRect.overlaps(f)) continue;
      canvas.drawOval(
        mistRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFF94A3B8).withValues(alpha: 0.062),
              const Color(0xFF64748B).withValues(alpha: 0.026),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.58, 1.0],
          ).createShader(mistRect),
      );
    }

    final Paint additive = Paint()..blendMode = BlendMode.plus;

    // 3. Great Forge Anvil Hammer-Strike Spark Bursts (1140, 1865)
    if (_visiblePt(const Offset(1140, 1865), 160.0)) {
      final double strikeT = (phase * 2.0) % 1.0;
      if (strikeT < 0.42) {
        final double bt = strikeT / 0.42;
        for (int s = 0; s < 10; s++) {
          final double angle = -math.pi * 0.88 + (s / 9.0) * math.pi * 0.76;
          final double speed = 56.0 + (s % 4) * 18.0;
          final double sx = 1140.0 + math.cos(angle) * speed * bt;
          final double sy =
              1865.0 + math.sin(angle) * speed * bt + 68.0 * bt * bt;
          additive.color = const Color(0xFFFEF08A)
              .withValues(alpha: (1.0 - bt) * 0.92);
          canvas.drawCircle(Offset(sx, sy), 2.2 * (1.0 - bt * 0.4), additive);
        }
      }
    }

    // 4. Northern Rift Portal Astral Vortex Motes (3205, 515)
    if (_visiblePt(const Offset(3205, 515), 150.0)) {
      for (int i = 0; i < 12; i++) {
        final double angle = phase * math.pi * 2 + (i * math.pi * 2 / 12.0);
        final double rx = 64.0 + (i % 3) * 18.0;
        final double ry = 72.0 + (i % 2) * 14.0;
        final double x = 3205.0 + math.cos(angle) * rx;
        final double y = 515.0 + math.sin(angle) * ry;
        additive.color = const Color(0xFF7DD3FC).withValues(alpha: 0.68);
        canvas.drawCircle(Offset(x, y), 2.3, additive);
      }
    }

    // 5. Central Sovereign Fountain Basin Shimmer & Honor Motes (3200, 2070)
    if (_visiblePt(const Offset(3200, 2070), 260.0)) {
      for (int i = 0; i < 12; i++) {
        final double t = (phase + i / 12.0) % 1.0;
        final double angle = i * 0.9 + phase * math.pi * 2;
        final double x = 3200.0 + math.cos(angle) * (110.0 + (i % 3) * 34.0);
        final double y = 2040.0 - t * 240.0;
        final Color moteColor = i % 3 == 0
            ? const Color(0xFFFDE047)
            : const Color(0xFFBAE6FD);
        additive.color = moteColor.withValues(alpha: (1.0 - t) * 0.62);
        canvas.drawCircle(Offset(x, y), 2.0, additive);
      }
    }

    // 6. Ambient Twilight Fireflies (only inside camera frustum!)
    for (int i = 0; i < 24; i++) {
      final double fx = 680.0 + ((i * 499) % 5040);
      final double fy = 880.0 + ((i * 353) % 2180);
      if (!_visiblePt(Offset(fx, fy), 60.0)) continue;
      final double driftX = math.sin(skyPhase * math.pi * 4 + i) * 32.0;
      final double driftY = math.cos(skyPhase * math.pi * 4 + i * 1.7) * 18.0;
      final double blink =
          (0.5 + 0.5 * math.sin(phase * math.pi * 2 + i * 0.85))
              .clamp(0.0, 1.0);
      additive.color = const Color(0xFFFDE68A).withValues(alpha: blink * 0.42);
      canvas.drawCircle(Offset(fx + driftX, fy + driftY), 2.0, additive);
    }

    // 7. Animated Citadel Ravens Gliding High Across the Mega-Courtyard
    final Paint ravenPaint = Paint()
      ..color = const Color(0xD8090D16)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    for (int r = 0; r < 4; r++) {
      final double rt = (skyPhase + r * 0.24) % 1.0;
      final double rx = -180.0 + rt * (size.width + 360.0);
      final double ry =
          540.0 + r * 360.0 + math.sin(rt * math.pi * 3 + r) * 75.0;
      if (!_visiblePt(Offset(rx, ry), 120.0)) continue;
      final double flap =
          math.sin((phase * 3.0 + r * 0.37) * math.pi * 2) * 8.0;
      final Path wing = Path()
        ..moveTo(rx - 14.0, ry - flap)
        ..quadraticBezierTo(rx - 6.3, ry - 5.0 - flap * 0.4, rx, ry)
        ..quadraticBezierTo(rx + 6.3, ry - 5.0 - flap * 0.4, rx + 14.0, ry - flap);
      canvas.drawPath(wing, ravenPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CitadelAtmospherePainter oldDelegate) =>
      oldDelegate.frustum != frustum ||
      (oldDelegate.phase - phase).abs() > 0.016 ||
      (oldDelegate.skyPhase - skyPhase).abs() > 0.004;
}

/// Zero-Widget GPU Sprite-Atlas Crowd Batch Renderer for Overflow Players (#39 .. #500+):
/// Renders hundreds of real animated 9-frame Knights, Assassins, Alchemists & Merchant Stalls
/// in ONE single GPU pass (< 0.8ms for 500 players!) with zero Widget/Layout/GC overhead.
class _MoradonCrowdLodPainter extends CustomPainter {
  final List<MoradonPlayerPresence> overflowPlayers;
  final Map<String, ui.Image> charAtlases;
  final ui.Image? merchantStallImage;
  final double zoomComp;
  final double phase;
  final FilterQuality filterQuality;

  const _MoradonCrowdLodPainter({
    required this.overflowPlayers,
    required this.charAtlases,
    required this.merchantStallImage,
    required this.zoomComp,
    required this.phase,
    required this.filterQuality,
  });

  static String _classKeyOf(String rawClass) {
    final String lower = rawClass.toLowerCase();
    if (lower.contains('golge') || lower.contains('shadow')) return 'golge';
    if (lower.contains('simyaci') || lower.contains('alchemist')) {
      return 'simyaci';
    }
    return 'savasci';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint shadowPaint = Paint()..color = const Color(0x70000000);
    final Paint imgPaint = Paint()..filterQuality = filterQuality;
    final Paint barBgPaint = Paint()..color = const Color(0xCC090D16);
    final Paint barFillPaint = Paint();
    final Paint fallbackPaint = Paint()..style = PaintingStyle.fill;
    const double twoPi = math.pi * 2.0;
    const List<int> frontWalkCols = <int>[1, 2, 3, 4];
    const List<int> backWalkCols = <int>[5, 6, 7, 8];

    final double charW = 94.0 * zoomComp;
    final double charH = 114.0 * zoomComp;
    final double stallSize = 96.0 * zoomComp;
    final ui.Image? stallImg = merchantStallImage;
    final Rect? stallSrc = stallImg != null
        ? Rect.fromLTWH(
            0,
            0,
            stallImg.width.toDouble(),
            stallImg.height.toDouble(),
          )
        : null;

    for (int i = 0; i < overflowPlayers.length; i++) {
      final MoradonPlayerPresence p = overflowPlayers[i];
      final double px = p.x;
      final double py = p.y;

      // 1. Crisp isometric contact shadow (zero RadialGradient shader allocation!)
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(px, py - 4.0 * zoomComp),
          width: 48.0 * zoomComp,
          height: 15.0 * zoomComp,
        ),
        shadowPaint,
      );

      if (p.isMerchant) {
        if (stallImg != null && stallSrc != null) {
          canvas.drawImageRect(
            stallImg,
            stallSrc,
            Rect.fromLTWH(
              px - stallSize * 0.5,
              py - stallSize,
              stallSize,
              stallSize,
            ),
            imgPaint,
          );
        } else {
          fallbackPaint.color = const Color(0xFFB45309);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(px, py - 28.0 * zoomComp),
                width: 42.0 * zoomComp,
                height: 32.0 * zoomComp,
              ),
              const Radius.circular(6),
            ),
            fallbackPaint,
          );
        }
        // Compact overhead amber merchant indicator strip
        final Rect mBar = Rect.fromCenter(
          center: Offset(px, py - stallSize - 6.0 * zoomComp),
          width: 44.0 * zoomComp,
          height: 4.5 * zoomComp,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(mBar, const Radius.circular(2)),
          barBgPaint,
        );
        barFillPaint.color = const Color(0xFFFBBF24);
        canvas.drawRRect(
          RRect.fromRectAndRadius(mBar.deflate(0.8), const Radius.circular(1.5)),
          barFillPaint,
        );
        continue;
      }

      final ui.Image? atlas = charAtlases[_classKeyOf(p.characterClass)];
      final bool moving =
          (p.targetX - px).abs() > 2.0 || (p.targetY - py).abs() > 2.0;

      if (atlas != null) {
        final double cellW = atlas.width / 9.0;
        final double cellH = atlas.height.toDouble();
        int col;
        double bobY = 0.0;
        if (moving) {
          final double normW = ((p.walkPhase % twoPi) + twoPi) % twoPi;
          final List<int> seq = p.facingBack ? backWalkCols : frontWalkCols;
          col = seq[((normW / twoPi) * 4.0).floor() % 4];
          bobY = -math.sin(normW).abs() * 2.8 * zoomComp;
        } else {
          col = p.facingBack ? 6 : 0;
        }
        final Rect src = Rect.fromLTWH(
          col * cellW + 1.5,
          1.0,
          math.max(1.0, cellW - 3.0),
          math.max(1.0, cellH - 2.0),
        );

        if (p.facingRight) {
          canvas.drawImageRect(
            atlas,
            src,
            Rect.fromLTWH(
              px - charW * 0.5,
              py - charH + bobY,
              charW,
              charH,
            ),
            imgPaint,
          );
        } else {
          canvas.save();
          canvas.translate(px, py + bobY);
          canvas.scale(-1.0, 1.0);
          canvas.drawImageRect(
            atlas,
            src,
            Rect.fromLTWH(-charW * 0.5, -charH, charW, charH),
            imgPaint,
          );
          canvas.restore();
        }
      } else {
        // Pre-decode fallback silhouette (e.g. headless widget tests)
        fallbackPaint.color = const Color(0xFF1E293B);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(px, py - 28.0 * zoomComp),
              width: 22.0 * zoomComp,
              height: 38.0 * zoomComp,
            ),
            const Radius.circular(7),
          ),
          fallbackPaint,
        );
      }

      // Crisp overhead MMO crimson HP strip (zero text layout!)
      final Rect hpRect = Rect.fromCenter(
        center: Offset(px, py - charH - 4.0 * zoomComp),
        width: 34.0 * zoomComp,
        height: 4.0 * zoomComp,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(hpRect, const Radius.circular(2)),
        barBgPaint,
      );
      barFillPaint.color = const Color(0xFFEF4444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(hpRect.deflate(0.7), const Radius.circular(1.5)),
        barFillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MoradonCrowdLodPainter oldDelegate) =>
      oldDelegate.overflowPlayers.length != overflowPlayers.length ||
      oldDelegate.charAtlases.length != charAtlases.length ||
      oldDelegate.merchantStallImage != merchantStallImage ||
      oldDelegate.zoomComp != zoomComp ||
      (oldDelegate.phase - phase).abs() > 0.025;
}

/// GPU 9-frame Isometric Character Sprite-Atlas Renderer:
/// Local hero uses 60Hz connected skeletal mesh; remote players & guards use single-quad hardware blit!
class _MoradonCharacterAtlasPainter extends CustomPainter {
  final ui.Image atlas;
  final String classKey;
  final Map<MoradonPetVisual, ui.Image> petImages;
  final bool facingRight;
  final bool facingBack;
  final bool isMoving;
  final double walkPhase;
  final double idlePhase;
  final double orbitPhase;
  final int glowLevel;
  final Color glowColor;
  final MoradonWeaponVisual weaponVisual;
  final MoradonPetVisual petVisual;
  final bool isLocal;
  final bool isSelected;
  final bool isHovered;
  final double attackProgress;
  final int comboStage;

  const _MoradonCharacterAtlasPainter({
    required this.atlas,
    required this.classKey,
    required this.petImages,
    required this.facingRight,
    required this.facingBack,
    required this.isMoving,
    required this.walkPhase,
    required this.idlePhase,
    required this.orbitPhase,
    required this.glowLevel,
    required this.glowColor,
    this.weaponVisual = MoradonWeaponVisual.none,
    this.petVisual = MoradonPetVisual.none,
    required this.isLocal,
    required this.isSelected,
    required this.isHovered,
    this.attackProgress = 0.0,
    this.comboStage = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2.0;
    final double groundY = size.height - 6.0;

    // 1. Ground Contact Shadow (RadialGradient for local hero; zero-shader fast oval for crowd!)
    final double strideSpread =
        isMoving ? (0.92 + 0.16 * math.sin(walkPhase).abs()) : 1.0;
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(cx, groundY),
      width: (isLocal ? 68.0 : 56.0) * strideSpread,
      height: isLocal ? 22.0 : 18.0,
    );
    if (isLocal) {
      canvas.drawOval(
        shadowRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.black.withValues(alpha: 0.82),
              Colors.black.withValues(alpha: 0.36),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.58, 1.0],
          ).createShader(shadowRect),
      );
    } else {
      canvas.drawOval(
        shadowRect,
        Paint()..color = const Color(0x72000000),
      );
    }

    // 2. Clean Selection / Hover Target Indicator (only when targeting a remote player)
    if (isSelected || isHovered) {
      final Color ringColor =
          isSelected ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8);
      final Rect ringRect = Rect.fromCenter(
        center: Offset(cx, groundY),
        width: 56.0,
        height: 18.0,
      );
      canvas.drawOval(
        ringRect,
        Paint()
          ..color = ringColor.withValues(alpha: isSelected ? 0.55 : 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;

    // 3. Trailing Cobblestone Footstep Dust Puffs while running (local hero only!)
    if (isLocal && !gfx.isLow && isMoving) {
      final double trailDirX = facingRight ? -1.0 : 1.0;
      final double trailDirY = facingBack ? 1.0 : -0.45;
      final Paint dustPaint = Paint()..style = PaintingStyle.fill;
      for (int i = 0; i < 3; i++) {
        final double age = ((walkPhase / math.pi) + i * 0.33) % 1.0;
        final double dx = cx + trailDirX * (10.0 + age * 22.0);
        final double dy = groundY + trailDirY * (age * 8.0) - age * 5.0;
        final double radius = 2.5 + age * 4.2;
        dustPaint.color =
            const Color(0xFFD6C7B2).withValues(alpha: (1.0 - age) * 0.28);
        canvas.drawCircle(Offset(dx, dy), radius, dustPaint);
      }
    }

    // 4. Subtle Dark-Fantasy Ambient Backlight behind Local Hero Silhouette
    if (isLocal && !gfx.isLow && glowLevel >= 8) {
      final double pulse = 0.5 + 0.5 * math.sin(idlePhase * math.pi * 2);
      final Rect auraRect = Rect.fromCenter(
        center: Offset(cx, size.height * 0.54),
        width: 58.0,
        height: 76.0,
      );
      canvas.drawOval(
        auraRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: <Color>[
              glowColor.withValues(alpha: 0.14 + pulse * 0.03),
              Colors.transparent,
            ],
          ).createShader(auraRect),
      );
    }

    // 5. Character Locomotion & Combat Rig (full mesh on local hero; single-quad hardware blit on remote crowd!)
    paintSegmentedCharacterRig(
      canvas: canvas,
      size: size,
      atlas: atlas,
      classKey: classKey,
      facingRight: facingRight,
      facingBack: facingBack,
      isMoving: isMoving,
      walkPhase: walkPhase,
      idlePhase: idlePhase,
      glowColor: glowColor,
      glowLevel: glowLevel,
      weaponVisual: weaponVisual,
      attackProgress: attackProgress,
      comboStage: comboStage,
      fastSpriteQuad: !isLocal,
    );

    // 6. Optional Companion Pet (only when explicitly equipped)
    if (petVisual != MoradonPetVisual.none && gfx.enableCompanionPets) {
      drawIsometricCompanionPet(
        canvas: canvas,
        size: size,
        pet: petVisual,
        petImages: petImages,
        facingRight: facingRight,
        idlePhase: idlePhase,
        orbitPhase: orbitPhase,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MoradonCharacterAtlasPainter oldDelegate) {
    if (oldDelegate.atlas != atlas ||
        oldDelegate.classKey != classKey ||
        oldDelegate.facingRight != facingRight ||
        oldDelegate.facingBack != facingBack ||
        oldDelegate.isMoving != isMoving ||
        oldDelegate.glowLevel != glowLevel ||
        oldDelegate.weaponVisual != weaponVisual ||
        oldDelegate.petVisual != petVisual ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isHovered != isHovered ||
        oldDelegate.comboStage != comboStage ||
        (oldDelegate.attackProgress - attackProgress).abs() > 0.005) {
      return true;
    }
    if (isMoving) {
      return (oldDelegate.walkPhase - walkPhase).abs() > 0.015;
    }
    // Stationary remote players only repaint subtly (~6 Hz) instead of 60 Hz!
    final double idleThreshold = isLocal ? 0.012 : 0.065;
    return (oldDelegate.idlePhase - idlePhase).abs() > idleThreshold;
  }
}

class _DepthEntity {
  final double yDepth;
  final Widget child;

  const _DepthEntity({required this.yDepth, required this.child});
}

class _RoyalTrainingDummyImpactPainter extends CustomPainter {
  final Color accentColor;
  final double hitFlash;
  final double recoilDecay;
  final double phase;

  const _RoyalTrainingDummyImpactPainter({
    required this.accentColor,
    required this.hitFlash,
    required this.recoilDecay,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;
    final double pedestalBaseY = size.height - 15.0;

    // 1. Dark feathered ground contact shadow directly beneath the stone pedestal
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(cx, pedestalBaseY),
      width: 90,
      height: 28,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.black.withValues(alpha: 0.86),
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.58, 1.0],
        ).createShader(shadowRect),
    );

    // 2. Reactive shockwave ring & metallic sparks ONLY during an active strike!
    if (hitFlash > 0.01 || recoilDecay > 0.03) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, pedestalBaseY),
          width: 78 + (1.0 - recoilDecay) * 28.0,
          height: 22 + (1.0 - recoilDecay) * 9.0,
        ),
        Paint()
          ..color = accentColor.withValues(
            alpha: (recoilDecay * 0.72).clamp(0.0, 0.85),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 + hitFlash * 1.4,
      );

      final Paint sparkPaint = Paint()
        ..color = const Color(0xFFFEF08A).withValues(alpha: recoilDecay)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 8; i++) {
        final double ang = (i / 8.0) * math.pi * 2 + 0.35;
        final double r0 = 14.0 + (1.0 - recoilDecay) * 32.0;
        final double r1 = r0 + 10.0 * recoilDecay;
        canvas.drawLine(
          Offset(cx + math.cos(ang) * r0, 58 + math.sin(ang) * r0 * 0.72),
          Offset(cx + math.cos(ang) * r1, 58 + math.sin(ang) * r1 * 0.72),
          sparkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoyalTrainingDummyImpactPainter oldDelegate) {
    return (oldDelegate.hitFlash - hitFlash).abs() > 0.01 ||
        (oldDelegate.recoilDecay - recoilDecay).abs() > 0.01 ||
        oldDelegate.accentColor != accentColor;
  }
}

class _GothicDungeonFlagstoneFallbackPainter extends CustomPainter {
  const _GothicDungeonFlagstoneFallbackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.0, 0.08),
          radius: 0.78,
          colors: <Color>[
            Color(0xFF232938),
            Color(0xFF171C28),
            Color(0xFF0E121B),
          ],
          stops: <double>[0.0, 0.56, 1.0],
        ).createShader(full),
    );

    // Cobbled grand cross-avenues & octagonal Pantheon plaza stone rings
    final Paint avenuePaint = Paint()
      ..color = const Color(0xFF2B3346).withValues(alpha: 0.68)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.60),
        width: size.width * 0.88,
        height: 360,
      ),
      avenuePaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.56),
        width: 440,
        height: size.height * 0.82,
      ),
      avenuePaint,
    );

    final Offset plazaCenter = Offset(3200, 2260);
    canvas.drawOval(
      Rect.fromCenter(center: plazaCenter, width: 1480, height: 920),
      Paint()..color = const Color(0xFF2A3142),
    );
    canvas.drawOval(
      Rect.fromCenter(center: plazaCenter, width: 1480, height: 920),
      Paint()
        ..color = const Color(0xFFD97706).withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0,
    );

    // Carved flagstone mortar seams across world floor
    final Paint seamPaint = Paint()
      ..color = const Color(0xFF090C13).withValues(alpha: 0.52)
      ..strokeWidth = 2.0;
    const double stepY = 96.0;
    const double stepX = 164.0;
    int row = 0;
    for (double y = 0; y <= size.height; y += stepY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), seamPaint);
      final double xOffset = (row.isOdd) ? stepX * 0.5 : 0.0;
      for (double x = xOffset; x <= size.width; x += stepX) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(size.height, y + stepY)),
          seamPaint,
        );
      }
      row++;
    }

    // Warm torchlight stone pools at major districts
    const List<Offset> torchPools = <Offset>[
      Offset(3200, 2240),
      Offset(3200, 2660),
      Offset(1560, 2120),
      Offset(4820, 2120),
      Offset(1620, 1180),
      Offset(4780, 1180),
      Offset(1580, 2940),
      Offset(4820, 2940),
    ];
    for (final Offset pool in torchPools) {
      final Rect r = Rect.fromCenter(center: pool, width: 820, height: 520);
      canvas.drawOval(
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFEA580C).withValues(alpha: 0.16),
              const Color(0xFFF59E0B).withValues(alpha: 0.06),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.55, 1.0],
          ).createShader(r),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _GothicDungeonFlagstoneFallbackPainter oldDelegate,
  ) =>
      false;
}
