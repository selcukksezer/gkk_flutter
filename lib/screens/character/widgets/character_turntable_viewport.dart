import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/assets/mesh_asset_registry.dart';
import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../core/engine/zero_jank_preloader.dart';
import '../../../models/player_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../settings/graphics_settings_service.dart';

/// Inspection mode for the 3D turntable viewport.
enum TurntableMode {
  character,
  weapon,
}

/// Studio lighting presets for the 3D Turntable Viewport.
enum TurntableLightingPreset {
  heroStudio,
  astralArcane,
  forgeInferno,
  shadowAbyss;

  String get displayName => switch (this) {
        TurntableLightingPreset.heroStudio => 'Stüdyo',
        TurntableLightingPreset.astralArcane => 'Arkana',
        TurntableLightingPreset.forgeInferno => 'Alev',
        TurntableLightingPreset.shadowAbyss => 'Gölge',
      };

  IconData get icon => switch (this) {
        TurntableLightingPreset.heroStudio => Icons.wb_sunny_rounded,
        TurntableLightingPreset.astralArcane => Icons.auto_awesome_rounded,
        TurntableLightingPreset.forgeInferno => Icons.local_fire_department_rounded,
        TurntableLightingPreset.shadowAbyss => Icons.nightlight_round,
      };

  math.Point<double> get lightVector2D => switch (this) {
        TurntableLightingPreset.heroStudio => const math.Point<double>(0.5, 0.75),
        TurntableLightingPreset.astralArcane => const math.Point<double>(-0.6, 0.7),
        TurntableLightingPreset.forgeInferno => const math.Point<double>(0.7, -0.3),
        TurntableLightingPreset.shadowAbyss => const math.Point<double>(0.0, 0.9),
      };

  double get lightZ => switch (this) {
        TurntableLightingPreset.heroStudio => 0.45,
        TurntableLightingPreset.astralArcane => 0.6,
        TurntableLightingPreset.forgeInferno => 0.4,
        TurntableLightingPreset.shadowAbyss => 0.3,
      };

  Color keyLightColor(Color classPrimary) => switch (this) {
        TurntableLightingPreset.heroStudio => AppColors.goldLight,
        TurntableLightingPreset.astralArcane => AppColors.accentCyan,
        TurntableLightingPreset.forgeInferno => AppColors.coralFlare,
        TurntableLightingPreset.shadowAbyss => AppColors.accentBlue,
      };

  Color rimLightColor(Color classSecondary) => switch (this) {
        TurntableLightingPreset.heroStudio => AppColors.liquidGold,
        TurntableLightingPreset.astralArcane => AppColors.accentPurple,
        TurntableLightingPreset.forgeInferno => AppColors.warningSolar,
        TurntableLightingPreset.shadowAbyss => AppColors.cyberFuchsia,
      };

  Color ambientColor(Color classPrimary) => switch (this) {
        TurntableLightingPreset.heroStudio => classPrimary,
        TurntableLightingPreset.astralArcane => AppColors.accentCyan,
        TurntableLightingPreset.forgeInferno => AppColors.coralFlare,
        TurntableLightingPreset.shadowAbyss => AppColors.spaceNavy,
      };
}

/// Interactive 3D Turntable Viewport with Aion 2 Mobile AAA standard:
/// - Smooth 360-degree horizontal rotation & pitch tilt with momentum damping
/// - Real 3D GLB mesh loader & software/canvas perspective rasterization
/// - Character and Weapon inspection modes with glowing runic highlights
/// - Studio lighting presets (Hero Studio, Astral Arcane, Forge Inferno, Shadow Abyss)
/// - Runic emission shaders & glowing arcane aura effects
/// - Two-finger pinch-to-zoom and double-tap orientation reset
/// - Graceful glowing runic silhouette with particle pedestal fallback
/// - 100% mobile touch controls with HapticFeedback
class CharacterTurntableViewport extends StatefulWidget {
  const CharacterTurntableViewport({
    super.key,
    required this.characterClass,
    this.equippedCount = 0,
    this.height,
    this.onTap,
    this.initialMode = TurntableMode.character,
    this.customGlbPath,
    this.weaponGlbPath,
    this.showControls = true,
    this.showModeToggle = true,
    this.enableRunicEmission = true,
    this.onModeChanged,
    this.controller,
    this.initialLightingPreset = TurntableLightingPreset.heroStudio,
    this.onLightingPresetChanged,
    this.initialAutoRotate = false,
    this.scaler,
    this.preloader,
  });

  // Strict camera angle and zoom bounds for AAA studio presentation
  static const double kMinPitch = -0.45; // ~ -25.8 degrees
  static const double kMaxPitch = 0.45;  // ~ +25.8 degrees
  static const double kMinZoom = 0.65;
  static const double kMaxZoom = 2.85;

  final CharacterClass? characterClass;
  final int equippedCount;
  final double? height;
  final VoidCallback? onTap;
  final TurntableMode initialMode;
  final String? customGlbPath;
  final String? weaponGlbPath;
  final bool showControls;
  final bool showModeToggle;
  final bool enableRunicEmission;
  final ValueChanged<TurntableMode>? onModeChanged;
  final AnimationController? controller;
  final TurntableLightingPreset initialLightingPreset;
  final ValueChanged<TurntableLightingPreset>? onLightingPresetChanged;
  final bool initialAutoRotate;
  final AdaptiveQualityScaler? scaler;
  final ZeroJankPreloader? preloader;

  @override
  State<CharacterTurntableViewport> createState() =>
      _CharacterTurntableViewportState();
}

class _CharacterTurntableViewportState extends State<CharacterTurntableViewport>
    with SingleTickerProviderStateMixin {
  late final AnimationController _internalAnimController;
  AnimationController get _animController =>
      widget.controller ?? _internalAnimController;

  AdaptiveQualityScaler get _scaler =>
      widget.scaler ?? GraphicsSettingsService.instance.scaler;
  ZeroJankPreloader get _preloader =>
      widget.preloader ?? ZeroJankPreloader.instance;

  // Viewport mode state
  late TurntableMode _currentMode;
  late bool _runesActive;
  late TurntableLightingPreset _currentLightingPreset;
  late bool _autoRotateActive;
  late HardwareTier _lastTier;

  // Animation frame timing and adaptive quality throttling
  final Stopwatch _frameStopwatch = Stopwatch()..start();
  int _lastTickTimestampMs = 0;

  // Turntable orientation and camera state
  double _yaw = 0.0;
  double _pitch = 0.0;
  double _zoom = 1.0;
  double _baseZoom = 1.0;
  double _lastDetentAngle = 0.0;

  // Momentum velocity
  double _yawVelocity = 0.0;
  double _pitchVelocity = 0.0;

  // Interaction tracking
  bool _isInteracting = false;

  // Assets and 3D mesh state
  ui.Image? _characterImage;
  String? _loadedImagePath;

  ParsedModelMesh? _characterMesh;
  ParsedModelMesh? _weaponMesh;
  bool _isLoadingMesh = false;
  String? _activeModelPath;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _runesActive = widget.enableRunicEmission;
    _currentLightingPreset = widget.initialLightingPreset;
    _autoRotateActive = widget.initialAutoRotate;
    _lastTier = _scaler.currentTier;

    _scaler.addListener(_onScalerChanged);

    _internalAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _animController.addListener(_onAnimationTick);

    _prewarmCharacterAssets();
    _loadClassImage();
    _loadActive3dMesh();
  }

  @override
  void didUpdateWidget(covariant CharacterTurntableViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaler != widget.scaler) {
      (oldWidget.scaler ?? GraphicsSettingsService.instance.scaler)
          .removeListener(_onScalerChanged);
      _scaler.addListener(_onScalerChanged);
    }
    if (oldWidget.characterClass != widget.characterClass) {
      _loadClassImage();
      _prewarmCharacterAssets();
      _loadActive3dMesh();
    }
    if (oldWidget.customGlbPath != widget.customGlbPath ||
        oldWidget.weaponGlbPath != widget.weaponGlbPath) {
      _loadActive3dMesh();
    }
  }

  @override
  void dispose() {
    _scaler.removeListener(_onScalerChanged);
    _animController.removeListener(_onAnimationTick);
    _internalAnimController.dispose();
    super.dispose();
  }

  void _onScalerChanged() {
    if (!mounted) return;
    final HardwareTier tier = _scaler.currentTier;
    if (tier != _lastTier) {
      _lastTier = tier;
      _loadActive3dMesh();
    }
    setState(() {});
  }

  void _onAnimationTick() {
    final int nowMs = _frameStopwatch.elapsedMilliseconds;
    final int elapsedSinceLast = nowMs - _lastTickTimestampMs;

    final HardwareTier tier = _scaler.currentTier;
    final bool isEcoOrLow =
        tier == HardwareTier.eco || tier == HardwareTier.low;

    // Eco / Low tiers (<=2GB RAM): clamp rotation animation to 30 FPS (<33ms throttle gate)
    if (isEcoOrLow && elapsedSinceLast < 33) {
      return;
    }

    _lastTickTimestampMs = nowMs;

    // Report frame pacing telemetry to adaptive quality scaler
    if (elapsedSinceLast > 0) {
      _scaler.recordFrameTime(elapsedSinceLast.toDouble());
    }

    if (!_isInteracting) {
      // 1. Inertia momentum damping when released after drag/flick
      if (_yawVelocity.abs() > 0.0001 || _pitchVelocity.abs() > 0.0001) {
        setState(() {
          _yaw += _yawVelocity;
          _pitch = (_pitch + _pitchVelocity).clamp(
            CharacterTurntableViewport.kMinPitch,
            CharacterTurntableViewport.kMaxPitch,
          );
          _yawVelocity *= 0.93; // Smooth AAA friction damping
          _pitchVelocity *= 0.93;
        });
      } else if (_autoRotateActive) {
        // 2. Smooth studio continuous turntable orbit
        final double speedMultiplier = isEcoOrLow ? 2.0 : 1.0;
        setState(() {
          _yaw += 0.008 * speedMultiplier;
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // MODEL & ASSET RESOLUTION PIPELINE
  // --------------------------------------------------------------------------

  String _imageAssetForClass(CharacterClass? cClass) {
    return switch (cClass) {
      CharacterClass.warrior => 'assets/characters/savasci.png',
      CharacterClass.alchemist => 'assets/characters/simyaci.png',
      CharacterClass.shadow => 'assets/characters/golge.png',
      null => 'assets/characters/savasci.png',
    };
  }

  String _characterGlbForClass(CharacterClass? cClass) {
    if (widget.customGlbPath != null && widget.customGlbPath!.isNotEmpty) {
      return widget.customGlbPath!;
    }
    final HardwareTier tier = _scaler.currentTier;
    final bool isEcoOrLow =
        tier == HardwareTier.eco || tier == HardwareTier.low;
    final bool isUltra = tier == HardwareTier.ultra;

    if (isEcoOrLow) {
      // Eco / Low tiers (<=2GB RAM): use LOD1 character mesh
      return switch (cClass) {
        CharacterClass.warrior =>
          'assets/models/characters/KnightCharacter_LOD1.glb',
        CharacterClass.alchemist => 'assets/models/characters/Mage_LOD1.glb',
        CharacterClass.shadow =>
          'assets/models/characters/Barbarian_LOD1.glb',
        null => 'assets/models/characters/KnightCharacter_LOD1.glb',
      };
    } else if (isUltra) {
      // Ultra tier: LOD0 4K PBR character model
      return switch (cClass) {
        CharacterClass.warrior =>
          'assets/models/characters/KnightCharacter_LOD0.glb',
        CharacterClass.alchemist => 'assets/models/characters/Mage_LOD0.glb',
        CharacterClass.shadow =>
          'assets/models/characters/Barbarian_LOD0.glb',
        null => 'assets/models/characters/KnightCharacter_LOD0.glb',
      };
    } else {
      // Mid / High tiers
      return switch (cClass) {
        CharacterClass.warrior =>
          'assets/models/characters/KnightCharacter.glb',
        CharacterClass.alchemist => 'assets/models/characters/Mage.glb',
        CharacterClass.shadow => 'assets/models/characters/Barbarian.glb',
        null => 'assets/models/characters/KnightCharacter.glb',
      };
    }
  }

  String _weaponGlbForClass(CharacterClass? cClass) {
    if (widget.weaponGlbPath != null && widget.weaponGlbPath!.isNotEmpty) {
      return widget.weaponGlbPath!;
    }
    final HardwareTier tier = _scaler.currentTier;
    final bool isEcoOrLow =
        tier == HardwareTier.eco || tier == HardwareTier.low;
    final bool isUltra = tier == HardwareTier.ultra;

    if (isEcoOrLow) {
      return switch (cClass) {
        CharacterClass.warrior => 'assets/models/weapons/Sword_LOD1.glb',
        CharacterClass.alchemist => 'assets/models/weapons/Bow_Golden.glb',
        CharacterClass.shadow => 'assets/models/weapons/Dagger.glb',
        null => 'assets/models/weapons/Sword_LOD1.glb',
      };
    } else if (isUltra) {
      return switch (cClass) {
        CharacterClass.warrior => 'assets/models/weapons/Sword_LOD0.glb',
        CharacterClass.alchemist => 'assets/models/weapons/Bow_Golden.glb',
        CharacterClass.shadow => 'assets/models/weapons/Dagger.glb',
        null => 'assets/models/weapons/Sword_LOD0.glb',
      };
    } else {
      return switch (cClass) {
        CharacterClass.warrior => 'assets/models/weapons/Sword_Golden.glb',
        CharacterClass.alchemist => 'assets/models/weapons/Bow_Golden.glb',
        CharacterClass.shadow => 'assets/models/weapons/Dagger.glb',
        null => 'assets/models/weapons/Sword_Golden.glb',
      };
    }
  }

  void _prewarmCharacterAssets() {
    final ZeroJankPreloader preloader = _preloader;

    // 1. Pre-warm character mesh with PreloadPriority.nearbyLod0 (<2ms budget)
    final String charMeshPath = _characterGlbForClass(widget.characterClass);
    preloader.preloadGlbMesh<ParsedModelMesh?>(
      id: charMeshPath,
      priority: PreloadPriority.nearbyLod0,
      loader: (PreloadExecutionContext ctx) =>
          _parseGlbMeshProgressively(charMeshPath, ctx: ctx),
      targetCache: CacheTarget.vram,
      estimatedSizeBytes: 4 * 1024 * 1024,
    ).catchError((Object _) => null);

    // 2. Pre-warm weapon mesh with PreloadPriority.nearbyLod0 (<2ms budget)
    final String weaponMeshPath = _weaponGlbForClass(widget.characterClass);
    preloader.preloadGlbMesh<ParsedModelMesh?>(
      id: weaponMeshPath,
      priority: PreloadPriority.nearbyLod0,
      loader: (PreloadExecutionContext ctx) =>
          _parseGlbMeshProgressively(weaponMeshPath, ctx: ctx),
      targetCache: CacheTarget.vram,
      estimatedSizeBytes: 2 * 1024 * 1024,
    ).catchError((Object _) => null);

    // 3. Pre-warm 2D class portrait image
    final String imagePath = _imageAssetForClass(widget.characterClass);
    preloader.preloadAtomic<void>(
      id: imagePath,
      priority: PreloadPriority.nearbyLod0,
      loader: () async {
        await _loadClassImage();
      },
      targetCache: CacheTarget.ram,
      estimatedSizeBytes: 512 * 1024,
    ).catchError((Object _) => null);
  }

  Future<void> _loadClassImage() async {
    final String path = _imageAssetForClass(widget.characterClass);
    if (_loadedImagePath == path && _characterImage != null) return;
    _loadedImagePath = path;

    try {
      final ImageProvider provider = AssetImage(path);
      final ImageStream stream = provider.resolve(ImageConfiguration.empty);
      stream.addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          if (mounted) {
            setState(() {
              _characterImage = info.image;
            });
          }
        }, onError: (Object err, StackTrace? stack) {
          // Graceful fallback to procedural canvas rendering
        }),
      );
    } catch (_) {
      // Graceful fallback
    }
  }

  Future<void> _loadActive3dMesh() async {
    final String targetPath = _currentMode == TurntableMode.character
        ? _characterGlbForClass(widget.characterClass)
        : _weaponGlbForClass(widget.characterClass);

    if (_activeModelPath == targetPath &&
        (_currentMode == TurntableMode.character ? _characterMesh != null : _weaponMesh != null)) {
      return;
    }

    _activeModelPath = targetPath;
    if (mounted) {
      setState(() {
        _isLoadingMesh = true;
      });
    }

    ParsedModelMesh? parsed;

    // 1. Check if already warm in ZeroJank VRAM cache
    final dynamic cached = _preloader.getCached(targetPath, CacheTarget.vram);
    if (cached is ParsedModelMesh) {
      parsed = cached;
    } else {
      try {
        // 2. Preload progressively via ZeroJankPreloader with PreloadPriority.nearbyLod0 (<2ms budget)
        parsed = await _preloader.preloadGlbMesh<ParsedModelMesh?>(
          id: targetPath,
          priority: PreloadPriority.nearbyLod0,
          loader: (PreloadExecutionContext ctx) =>
              _parseGlbMeshProgressively(targetPath, ctx: ctx),
          targetCache: CacheTarget.vram,
          estimatedSizeBytes: 4 * 1024 * 1024,
        );
      } catch (_) {
        parsed = await _tryFallbackMeshCandidates(targetPath);
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingMesh = false;
        if (_currentMode == TurntableMode.character) {
          _characterMesh = parsed;
        } else {
          _weaponMesh = parsed;
        }
      });
    }
  }

  Future<ParsedModelMesh?> _parseGlbMeshProgressively(
    String targetPath, {
    PreloadExecutionContext? ctx,
  }) async {
    ParsedModelMesh? parsed;

    if (ctx != null && ctx.shouldYield()) {
      await ctx.yieldControl();
    }

    try {
      // 1. Try reading from filesystem directly (works in CLI / test / desktop)
      final io.File file = io.File(targetPath);
      if (file.existsSync()) {
        final Uint8List bytes = await file.readAsBytes();
        if (ctx != null && ctx.shouldYield()) {
          await ctx.yieldControl();
        }
        parsed = MeshAssetRegistry.instance.parser.parse(
          bytes: bytes,
          modelId: targetPath,
          sourcePath: targetPath,
        );
      }
    } catch (_) {
      // Fall through to asset bundle
    }

    if (parsed == null) {
      try {
        // 2. Try loading from Flutter asset bundle
        final ByteData bd = await rootBundle.load(targetPath);
        final Uint8List bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
        if (ctx != null && ctx.shouldYield()) {
          await ctx.yieldControl();
        }
        parsed = MeshAssetRegistry.instance.parser.parse(
          bytes: bytes,
          modelId: targetPath,
          sourcePath: targetPath,
        );
      } catch (_) {
        // 3. Fallback to alternative weapon/character models if specific variant missing
        parsed = await _tryFallbackMeshCandidates(targetPath);
      }
    }

    return parsed;
  }

  Future<ParsedModelMesh?> _tryFallbackMeshCandidates(String failedPath) async {
    final List<String> candidates = _currentMode == TurntableMode.character
        ? <String>[
            'assets/models/characters/KnightCharacter.glb',
            'assets/models/characters/KnightCharacter_LOD0.glb',
            'assets/models/characters/KnightCharacter_LOD1.glb',
            'assets/models/characters/Knight.glb',
            'assets/models/characters/Soldier.glb',
            'assets/models/characters/warrior_LOD0.glb',
          ]
        : <String>[
            'assets/models/weapons/Sword_Golden.glb',
            'assets/models/weapons/Sword_LOD0.glb',
            'assets/models/weapons/Sword_LOD1.glb',
            'assets/models/weapons/Claymore.glb',
            'assets/models/weapons/Sword_Big.glb',
            'assets/models/weapons/Axe_Double.glb',
            'assets/models/aion2/aion2_dark_fantasy_sword_LOD0.glb',
          ];

    for (final String path in candidates) {
      if (path == failedPath) continue;
      try {
        final io.File file = io.File(path);
        if (file.existsSync()) {
          final Uint8List bytes = await file.readAsBytes();
          return MeshAssetRegistry.instance.parser.parse(
            bytes: bytes,
            modelId: path,
            sourcePath: path,
          );
        }
      } catch (_) {}

      try {
        final ByteData bd = await rootBundle.load(path);
        final Uint8List bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
        return MeshAssetRegistry.instance.parser.parse(
          bytes: bytes,
          modelId: path,
          sourcePath: path,
        );
      } catch (_) {}
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // TOUCH GESTURE HANDLERS (ORBIT & PINCH-ZOOM)
  // --------------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    _preloader.onTouchStart();
    setState(() {
      _isInteracting = true;
      _baseZoom = _zoom;
      _yawVelocity = 0.0;
      _pitchVelocity = 0.0;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Single-finger drag: Orbit turntable
      if (details.pointerCount == 1) {
        final double deltaYaw = details.focalPointDelta.dx * 0.016;
        final double deltaPitch = -details.focalPointDelta.dy * 0.011;

        _yaw += deltaYaw;
        _pitch = (_pitch + deltaPitch).clamp(
          CharacterTurntableViewport.kMinPitch,
          CharacterTurntableViewport.kMaxPitch,
        );

        // Track velocity for momentum release (weighted smoothing)
        _yawVelocity = deltaYaw * 0.85;
        _pitchVelocity = deltaPitch * 0.85;

        // Subtle haptic detent on cardinal 90-degree crossings
        if ((_yaw - _lastDetentAngle).abs() > (math.pi / 2)) {
          _lastDetentAngle = _yaw;
          HapticFeedback.selectionClick();
        }
      }

      // Two-finger pinch: Zoom in / out
      if (details.scale != 1.0) {
        _zoom = (_baseZoom * details.scale).clamp(
          CharacterTurntableViewport.kMinZoom,
          CharacterTurntableViewport.kMaxZoom,
        );
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _preloader.onTouchEnd();
    setState(() {
      _isInteracting = false;
    });
  }

  void _resetOrientation() {
    HapticFeedback.lightImpact();
    setState(() {
      _yaw = 0.0;
      _pitch = 0.0;
      _zoom = 1.0;
      _yawVelocity = 0.0;
      _pitchVelocity = 0.0;
    });
  }

  void _toggleAutoRotate() {
    HapticFeedback.selectionClick();
    setState(() {
      _autoRotateActive = !_autoRotateActive;
    });
  }

  void _cycleLightingPreset() {
    HapticFeedback.selectionClick();
    setState(() {
      final int nextIndex =
          (_currentLightingPreset.index + 1) % TurntableLightingPreset.values.length;
      _currentLightingPreset = TurntableLightingPreset.values[nextIndex];
    });
    widget.onLightingPresetChanged?.call(_currentLightingPreset);
  }

  void _toggleInspectionMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentMode = _currentMode == TurntableMode.character
          ? TurntableMode.weapon
          : TurntableMode.character;
      // In weapon mode, tilt slightly for dynamic presentation
      if (_currentMode == TurntableMode.weapon) {
        _pitch = 0.12;
      } else {
        _pitch = 0.0;
      }
    });
    widget.onModeChanged?.call(_currentMode);
    _loadActive3dMesh();
  }

  void _toggleRunicEmission() {
    HapticFeedback.selectionClick();
    setState(() {
      _runesActive = !_runesActive;
    });
  }

  // --------------------------------------------------------------------------
  // BUILD METHOD
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final double viewportHeight = widget.height ?? 380;
    final ParsedModelMesh? activeMesh =
        _currentMode == TurntableMode.character ? _characterMesh : _weaponMesh;

    final HardwareTier currentTier = _scaler.currentTier;
    final bool isEcoOrLow =
        currentTier == HardwareTier.eco || currentTier == HardwareTier.low;
    final bool isUltra = currentTier == HardwareTier.ultra;

    return Semantics(
      label: _currentMode == TurntableMode.character
          ? '3D Karakter Vitrini'
          : '3D Silah Teftiş Vitrini',
      child: SizedBox(
        height: viewportHeight,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Turntable touch surface with Pinch & Drag wrapped in ZeroJankTouchScope
            ZeroJankTouchScope(
              preloader: _preloader,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                onDoubleTap: _resetOrientation,
                onTap: widget.onTap,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (BuildContext ctx, Widget? child) {
                    // Subtle auto-breathing and idle auto-pan when untouched
                    final double idleYaw = _isInteracting
                        ? _yaw
                        : _yaw + math.sin(_animController.value * 2 * math.pi) * 0.06;
                    final double idlePitch = _isInteracting
                        ? _pitch
                        : _pitch + math.cos(_animController.value * 2 * math.pi) * 0.015;

                    return CustomPaint(
                      size: Size(double.infinity, viewportHeight),
                      painter: _Aion2CharacterPainter(
                        yaw: idleYaw,
                        pitch: idlePitch,
                        zoom: _zoom,
                        animValue: _animController.value,
                        mode: _currentMode,
                        runesActive: _runesActive,
                        lightingPreset: _currentLightingPreset,
                        characterClass: widget.characterClass,
                        characterImage: _characterImage,
                        parsedMesh: activeMesh,
                        isLoadingMesh: _isLoadingMesh,
                        equippedCount: widget.equippedCount,
                        enableSecondaryRimLight: !isEcoOrLow,
                        enableDynamicShadowPedestal: isUltra,
                        hardwareTier: currentTier,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Top Control Bar (Thumb-friendly mobile layout)
            if (widget.showControls)
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // Left: Mode Switcher (Character vs Weapon)
                    if (widget.showModeToggle)
                      _buildModeToggleChip(),

                    const Spacer(),

                    // Right: Lighting Preset, Runic Glow Toggle, 360 Badge, Reset Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildLightingPresetButton(),
                        const SizedBox(width: AppSpacing.xs),
                        _buildRuneGlowButton(),
                        const SizedBox(width: AppSpacing.xs),
                        _build360Badge(),
                        const SizedBox(width: AppSpacing.xs),
                        _buildResetButton(),
                      ],
                    ),
                  ],
                ),
              ),

            // 3D Scene Loading Matrix Overlay Pill
            if (_isLoadingMesh)
              Positioned(
                top: 50,
                child: _buildMeshLoadingPill(),
              ),

            // Fallback Vector Projection Badge (when 3D GLB is unsupported/loading fallback)
            if (!_isLoadingMesh && activeMesh == null)
              Positioned(
                top: 50,
                child: _buildFallbackIllustrationBadge(),
              ),

            // Weapon Mode Info Pill (Bottom overlay in weapon mode)
            if (_currentMode == TurntableMode.weapon)
              Positioned(
                bottom: 34,
                child: _buildWeaponModeInfoBadge(),
              ),

            // Bottom Drag & Pinch Hint (Fades during interaction)
            if (!_isInteracting)
              Positioned(
                bottom: AppSpacing.sm,
                child: _buildInteractionHintBadge(),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // UI CONTROL WIDGETS
  // --------------------------------------------------------------------------

  Widget _buildModeToggleChip() {
    final bool isChar = _currentMode == TurntableMode.character;
    return GestureDetector(
      onTap: _toggleInspectionMode,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.spaceNavy.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: isChar
                ? AppColors.liquidGold.withValues(alpha: 0.5)
                : AppColors.accentCyan.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (isChar ? AppColors.liquidGold : AppColors.accentCyan)
                  .withValues(alpha: 0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isChar ? Icons.person_rounded : Icons.colorize_rounded,
              size: 14,
              color: isChar ? AppColors.liquidGold : AppColors.accentCyan,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              isChar ? 'Karakter Vitrini' : 'Silah Teftişi',
              style: AppTextStyles.label.copyWith(
                color: isChar ? AppColors.liquidGold : AppColors.accentCyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.swap_horiz_rounded,
              size: 13,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightingPresetButton() {
    final Color highlight =
        _currentLightingPreset.keyLightColor(AppColors.liquidGold);
    return GestureDetector(
      onTap: _cycleLightingPreset,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.spaceNavy.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: highlight.withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: highlight.withValues(alpha: 0.15),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _currentLightingPreset.icon,
              size: 13,
              color: highlight,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _currentLightingPreset.displayName,
              style: AppTextStyles.micro.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuneGlowButton() {
    return GestureDetector(
      onTap: _toggleRunicEmission,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.spaceNavy.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: _runesActive
                ? AppColors.accentCyan.withValues(alpha: 0.5)
                : AppColors.borderBright.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_awesome,
              size: 13,
              color: _runesActive ? AppColors.accentCyan : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _runesActive ? 'Rün: Açık' : 'Rün: Kapalı',
              style: AppTextStyles.micro.copyWith(
                color: _runesActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build360Badge() {
    return GestureDetector(
      onTap: _toggleAutoRotate,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 1,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.spaceNavy.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: _autoRotateActive
                ? AppColors.liquidGold
                : AppColors.liquidGold.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: _autoRotateActive
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.threesixty, size: 14, color: AppColors.liquidGold),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '360°',
              style: AppTextStyles.label.copyWith(
                color: AppColors.liquidGold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            if (_autoRotateActive) ...<Widget>[
              const SizedBox(width: 3),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.liquidGold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return IconButton(
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.spaceNavy.withValues(alpha: 0.75),
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.borderBright.withValues(alpha: 0.25)),
      ),
      tooltip: 'Açıyı Sıfırla',
      onPressed: _resetOrientation,
      icon: const Icon(Icons.refresh_rounded),
    );
  }

  Widget _buildMeshLoadingPill() {
    final HardwareTier tier = _scaler.currentTier;
    final String lodLabel = tier == HardwareTier.ultra
        ? 'LOD0 4K'
        : (tier == HardwareTier.eco || tier == HardwareTier.low)
            ? 'LOD1 (30 FPS)'
            : 'LOD0';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.spaceNavy.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.liquidGold,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '3D Sahne ($lodLabel)...',
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIllustrationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: AppColors.borderBright.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.layers_outlined,
            size: 10,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Vektörel Projeksiyon Fallback',
            style: AppTextStyles.micro.copyWith(
              fontSize: 9,
              color: AppColors.textTertiary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeaponModeInfoBadge() {
    final String weaponTitle = switch (widget.characterClass) {
      CharacterClass.warrior => 'Efsanevi Altın Kılıç',
      CharacterClass.alchemist => 'Kraliyet Yay & Asası',
      CharacterClass.shadow => 'Karanlık Gölge Hançeri',
      null => 'Efsanevi Kılıç',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkObsidian.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.shield_outlined, size: 12, color: AppColors.liquidGold),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            weaponTitle,
            style: AppTextStyles.label.copyWith(
              color: AppColors.liquidGold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs + 2,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Text(
              'Rün Yuvası [2/2]',
              style: AppTextStyles.micro.copyWith(
                color: AppColors.accentCyan,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionHintBadge() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgDeep.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.borderBright.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.touch_app_rounded,
              size: 13,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              'Çevirmek için kaydır · Yakınlaştırmak için sıkıştır',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER: 3D DAIS, RUNIC EMISSION & 3D MESH PROJECTION
// ============================================================================

class _Aion2CharacterPainter extends CustomPainter {
  _Aion2CharacterPainter({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.animValue,
    required this.mode,
    required this.runesActive,
    required this.lightingPreset,
    required this.characterClass,
    required this.characterImage,
    required this.parsedMesh,
    required this.isLoadingMesh,
    required this.equippedCount,
    this.enableSecondaryRimLight = true,
    this.enableDynamicShadowPedestal = false,
    this.hardwareTier = HardwareTier.mid,
  });

  final double yaw;
  final double pitch;
  final double zoom;
  final double animValue;
  final TurntableMode mode;
  final bool runesActive;
  final TurntableLightingPreset lightingPreset;
  final CharacterClass? characterClass;
  final ui.Image? characterImage;
  final ParsedModelMesh? parsedMesh;
  final bool isLoadingMesh;
  final int equippedCount;
  final bool enableSecondaryRimLight;
  final bool enableDynamicShadowPedestal;
  final HardwareTier hardwareTier;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.52;

    // 1. Atmospheric backdrop lighting & volumetric celestial godray
    _drawAtmosphericLight(canvas, size, cx, cy);

    // 2. 3D Floating Runic Dais / Turntable Platform
    _drawRunicPlatform(canvas, cx, size.height * 0.84, size.width * 0.38);

    // 2b. Arcane Summoning Matrix if loading 3D mesh scene
    if (isLoadingMesh) {
      _drawArcaneSummoningMatrix(canvas, cx, size.height * 0.84, size.width * 0.36);
    }

    // 3. Ethereal Wings (Only in character mode)
    if (mode == TurntableMode.character) {
      _drawEtherealWings(canvas, cx, cy - 20, size.width * 0.44);
    } else {
      // Weapon Mode: Concentric Arcane Spell Focus Ring
      _drawWeaponArcaneSpellCircle(canvas, cx, cy - 10, size.width * 0.32);
    }

    // 4. Render 3D Model Mesh or High-Fidelity Runic Silhouette Fallback
    _drawModelContent(canvas, size, cx, cy);

    // 5. Emissive Socket Connection Constellations
    if (mode == TurntableMode.character) {
      _drawSocketConstellations(canvas, cx, cy, size);
    } else {
      _drawWeaponSocketHighlights(canvas, cx, cy, size);
    }
  }

  // --------------------------------------------------------------------------
  // ATMOSPHERIC LIGHTING & GODRAYS
  // --------------------------------------------------------------------------

  void _drawAtmosphericLight(Canvas canvas, Size size, double cx, double cy) {
    final Color primaryGlow = _getClassPrimaryColor();
    final Color ambient = lightingPreset.ambientColor(primaryGlow);
    final Color keyLight = lightingPreset.keyLightColor(primaryGlow);

    final Paint godrayPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy - 40),
        size.height * 0.7,
        <Color>[
          keyLight.withValues(alpha: 0.22),
          ambient.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        <double>[0.0, 0.48, 1.0],
      );

    canvas.drawRect(Offset.zero & size, godrayPaint);
  }

  // --------------------------------------------------------------------------
  // ARCANE SUMMONING MATRIX (3D SCENE LOADING ANIMATION)
  // --------------------------------------------------------------------------

  void _drawArcaneSummoningMatrix(
    Canvas canvas,
    double cx,
    double cy,
    double radiusX,
  ) {
    final double spin = animValue * 2 * math.pi;
    final double radiusY = radiusX * 0.32;
    final Color accent = lightingPreset.keyLightColor(_getClassPrimaryColor());

    canvas.save();
    canvas.translate(cx, cy);

    // Outer rotating rune oval ring
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = accent.withValues(alpha: 0.85);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radiusX * 1.5, height: radiusY * 1.5),
      ringPaint,
    );

    // Inner counter-rotating oval ring
    final Paint innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppColors.textPrimary.withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radiusX * 1.1, height: radiusY * 1.1),
      innerRingPaint,
    );

    // Geometric summoning star lines
    const int points = 6;
    final Path starPath = Path();
    for (int i = 0; i < points; i++) {
      final double a = spin + (i * 2 * math.pi / points);
      final double r = (i % 2 == 0) ? radiusX * 0.75 : radiusX * 0.38;
      final double px = math.cos(a) * r;
      final double py = math.sin(a) * (r * 0.32);
      if (i == 0) {
        starPath.moveTo(px, py);
      } else {
        starPath.lineTo(px, py);
      }
    }
    starPath.close();

    final Paint starPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: 0.65);
    canvas.drawPath(starPath, starPaint);

    // Ascending vertical summoning beam
    final double pulse = 0.5 + 0.5 * math.sin(animValue * 4 * math.pi);
    final Paint beamPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(0, -180),
        <Color>[
          accent.withValues(alpha: 0.45 * pulse),
          accent.withValues(alpha: 0.15 * pulse),
          Colors.transparent,
        ],
        <double>[0.0, 0.45, 1.0],
      );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -90), width: radiusX * 0.6, height: 180),
      beamPaint,
    );

    canvas.restore();
  }

  // --------------------------------------------------------------------------
  // RUNIC PEDESTAL DAIS
  // --------------------------------------------------------------------------

  void _drawRunicPlatform(Canvas canvas, double cx, double cy, double radiusX) {
    final double radiusY = radiusX * 0.32;
    final Color accent = _getClassPrimaryColor();

    final Rect platformRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: radiusX * 2,
      height: radiusY * 2,
    );

    // Ultra tier: Dynamic directional shadow & specular pedestal caustics
    if (enableDynamicShadowPedestal) {
      final double lightX = lightingPreset.lightVector2D.x;
      final double lightY = lightingPreset.lightVector2D.y;
      final double shadowDist = 20.0 * zoom;
      final double shadowCenterX = cx - (lightX * shadowDist);
      final double shadowCenterY = cy + 4.0 - (lightY * shadowDist * 0.28);

      // 1. Soft Penumbra directional shadow
      final Rect penumbraRect = Rect.fromCenter(
        center: Offset(shadowCenterX, shadowCenterY),
        width: radiusX * 1.15,
        height: radiusY * 0.85,
      );
      final Paint penumbraPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawOval(penumbraRect, penumbraPaint);

      // 2. Deep Umbra contact shadow under dais center
      final Rect umbraRect = Rect.fromCenter(
        center: Offset(cx - (lightX * 6.0), cy - 2.0),
        width: radiusX * 0.65,
        height: radiusY * 0.45,
      );
      final Paint umbraPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawOval(umbraRect, umbraPaint);

      // 3. Dynamic specular caustic flare reacting to studio light angle
      final double specAngle = math.atan2(lightY, lightX) + (yaw * 0.3);
      final double causticX = cx + math.cos(specAngle) * radiusX * 0.92;
      final double causticY = cy + math.sin(specAngle) * radiusY * 0.92;
      final Paint causticPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(causticX, causticY),
          radiusX * 0.35,
          <Color>[
            Colors.white.withValues(alpha: 0.65),
            lightingPreset.keyLightColor(accent).withValues(alpha: 0.35),
            Colors.transparent,
          ],
          <double>[0.0, 0.4, 1.0],
        );
      canvas.drawCircle(Offset(causticX, causticY), radiusX * 0.35, causticPaint);
    }

    // Platform glow fill
    final Paint fillPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        radiusX,
        <Color>[
          accent.withValues(alpha: 0.32),
          accent.withValues(alpha: 0.07),
          Colors.transparent,
        ],
        <double>[0.0, 0.72, 1.0],
      );
    canvas.drawOval(platformRect, fillPaint);

    // Outer Concentric Runic Rim
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = accent.withValues(alpha: 0.75);
    canvas.drawOval(platformRect, ringPaint);

    // Inner Concentric Ring
    final Rect innerRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: radiusX * 1.45,
      height: radiusY * 1.45,
    );
    final Paint innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawOval(innerRect, innerRingPaint);

    // Rotating Runic Notches on Platform Rim
    final int notchCount = 18;
    for (int i = 0; i < notchCount; i++) {
      final double angle = (i * 2 * math.pi / notchCount) + yaw;
      final double nx = cx + math.cos(angle) * radiusX;
      final double ny = cy + math.sin(angle) * radiusY;

      // Depth attenuation
      final double depthAlpha = (math.sin(angle) + 1.2) / 2.2;

      final Paint notchPaint = Paint()
        ..color = (i % 3 == 0 ? Colors.white : accent).withValues(
          alpha: (0.3 + depthAlpha * 0.7).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(nx, ny), i % 3 == 0 ? 2.6 : 1.5, notchPaint);
    }

    // Upward Ascending Particle Embers from Dais
    _drawDaisParticleSparks(canvas, cx, cy, radiusX, radiusY, accent);
  }

  void _drawDaisParticleSparks(
    Canvas canvas,
    double cx,
    double cy,
    double rx,
    double ry,
    Color color,
  ) {
    const int sparkCount = 10;
    for (int i = 0; i < sparkCount; i++) {
      final double progress = ((i / sparkCount) + (animValue * 1.2)) % 1.0;
      final double angle = (i * 1.7) + (animValue * math.pi);
      final double sparkX = cx + math.cos(angle) * rx * 0.75;
      final double sparkY = cy + math.sin(angle) * ry * 0.75 - (progress * 70.0);
      final double alpha = math.sin(progress * math.pi).clamp(0.0, 1.0) * 0.85;

      final Paint sparkPaint = Paint()
        ..color = (i % 2 == 0 ? Colors.white : color).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(sparkX, sparkY), 1.8 * (1.0 - progress * 0.4), sparkPaint);
    }
  }

  // --------------------------------------------------------------------------
  // ETHEREAL WINGS (AION 2 SIGNATURE)
  // --------------------------------------------------------------------------

  void _drawEtherealWings(Canvas canvas, double cx, double cy, double wingSpan) {
    final double pulse = math.sin(animValue * 2 * math.pi) * 8.0;
    final double wingAngle = (yaw * 0.22).clamp(-0.35, 0.35);
    final Color wingColor = _getClassPrimaryColor();
    final Color tipColor = _getClassSecondaryColor();

    canvas.save();
    canvas.translate(cx, cy);

    // Left Wing
    _drawWingFeathers(
      canvas,
      wingSpan + pulse,
      isLeft: true,
      wingAngle: wingAngle,
      coreColor: wingColor,
      tipColor: tipColor,
    );

    // Right Wing
    _drawWingFeathers(
      canvas,
      wingSpan + pulse,
      isLeft: false,
      wingAngle: -wingAngle,
      coreColor: wingColor,
      tipColor: tipColor,
    );

    // Floating Celestial Feather Motes
    _drawWingMotes(canvas, wingSpan, wingColor);

    canvas.restore();
  }

  void _drawWingFeathers(
    Canvas canvas,
    double span, {
    required bool isLeft,
    required double wingAngle,
    required Color coreColor,
    required Color tipColor,
  }) {
    final double dir = isLeft ? -1.0 : 1.0;

    for (int layer = 0; layer < 3; layer++) {
      final double layerScale = 1.0 - (layer * 0.22);
      final double layerAlpha = (0.55 - layer * 0.12).clamp(0.0, 1.0);

      final Path wingPath = Path();
      wingPath.moveTo(0, 0);

      final double tipX = dir * span * layerScale * (1.0 + wingAngle * dir);
      final double tipY = -span * 0.68 * layerScale + (layer * 18);
      final double ctrlX = dir * span * 0.45 * layerScale;
      final double ctrlY = -span * 0.75 * layerScale;

      wingPath.cubicTo(ctrlX, ctrlY, tipX * 0.75, tipY * 0.9, tipX, tipY);

      final double returnCtrlX = dir * span * 0.55 * layerScale;
      final double returnCtrlY = -span * 0.15 * layerScale + (layer * 15);
      wingPath.cubicTo(returnCtrlX, returnCtrlY, dir * 25, 20, 0, 0);
      wingPath.close();

      final Paint wingPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(tipX, tipY),
          <Color>[
            coreColor.withValues(alpha: layerAlpha),
            tipColor.withValues(alpha: layerAlpha * 0.75),
            Colors.white.withValues(alpha: 0.1),
          ],
          <double>[0.0, 0.65, 1.0],
        )
        ..style = PaintingStyle.fill;

      final Paint edgePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(tipX, tipY),
          <Color>[
            Colors.white.withValues(alpha: 0.8),
            coreColor.withValues(alpha: 0.6),
            Colors.transparent,
          ],
          <double>[0.0, 0.6, 1.0],
        );

      canvas.drawPath(wingPath, wingPaint);
      canvas.drawPath(wingPath, edgePaint);
    }
  }

  void _drawWingMotes(Canvas canvas, double span, Color color) {
    const int moteCount = 12;
    for (int i = 0; i < moteCount; i++) {
      final double seed = (i / moteCount + animValue) % 1.0;
      final double mx = (math.sin(seed * 6.28 + i) * span * 0.9);
      final double my = -span * 0.7 + (seed * span * 0.8);
      final double alpha = math.sin(seed * math.pi).clamp(0.0, 1.0) * 0.8;

      final Paint motePaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      canvas.drawCircle(Offset(mx, my), 2.2 * (1.0 - seed * 0.5), motePaint);
    }
  }

  // --------------------------------------------------------------------------
  // WEAPON MODE: CONCENTRIC ARCANE SPELL FOCUS CIRCLE
  // --------------------------------------------------------------------------

  void _drawWeaponArcaneSpellCircle(
    Canvas canvas,
    double cx,
    double cy,
    double radius,
  ) {
    final Color primary = _getClassPrimaryColor();
    final double rotAngle = (animValue * 2 * math.pi) + (yaw * 0.5);

    canvas.save();
    canvas.translate(cx, cy);

    // Glowing outer spell ring
    final Paint circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = primary.withValues(alpha: 0.65);
    canvas.drawCircle(Offset.zero, radius, circlePaint);

    // Inner dashed arcane ring
    final Paint innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(Offset.zero, radius * 0.78, innerPaint);

    // Rotating Runic Points
    const int runePoints = 8;
    for (int i = 0; i < runePoints; i++) {
      final double ang = rotAngle + (i * 2 * math.pi / runePoints);
      final double rx = math.cos(ang) * radius;
      final double ry = math.sin(ang) * radius;

      final Paint runePaint = Paint()
        ..color = (i % 2 == 0 ? Colors.white : primary).withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
      canvas.drawCircle(Offset(rx, ry), i % 2 == 0 ? 3.0 : 1.8, runePaint);

      // Radial spoke lines
      final Paint spokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = primary.withValues(alpha: 0.25);
      canvas.drawLine(
        Offset(rx * 0.78, ry * 0.78),
        Offset(rx, ry),
        spokePaint,
      );
    }

    canvas.restore();
  }

  // --------------------------------------------------------------------------
  // 3D MODEL MESH OR GRACEFUL RUNIC SILHOUETTE RENDERER
  // --------------------------------------------------------------------------

  void _drawModelContent(Canvas canvas, Size size, double cx, double cy) {
    canvas.save();
    canvas.translate(cx, cy);

    final double cosYaw = math.cos(yaw);
    final double sinYaw = math.sin(yaw);

    // Check if we have real uncompressed vertex buffers in parsedMesh
    bool renderedMesh = false;
    if (parsedMesh != null && parsedMesh!.submeshes.isNotEmpty) {
      renderedMesh = _tryRender3dSubmeshes(canvas, size, cosYaw, sinYaw);
    }

    // If 3D mesh vertex rendering was not applicable (Draco compressed or no CPU buffers),
    // render the high-fidelity Glowing Runic Silhouette with Particle Pedestal
    if (!renderedMesh) {
      if (mode == TurntableMode.character) {
        if (characterImage != null) {
          _drawCharacterSpriteWithIridescence(canvas, cosYaw, sinYaw);
        } else {
          _drawProceduralCharacterRunicSilhouette(canvas, cosYaw, sinYaw);
        }
      } else {
        _drawProceduralWeaponRunicSilhouette(canvas, cosYaw, sinYaw);
      }
    }

    canvas.restore();
  }

  bool _tryRender3dSubmeshes(
    Canvas canvas,
    Size size,
    double cosYaw,
    double sinYaw,
  ) {
    // Check if any submesh has positions and indices
    final ParsedSubmesh prim = parsedMesh!.submeshes.firstWhere(
      (ParsedSubmesh s) => s.positions != null && s.indices != null,
      orElse: () => const ParsedSubmesh(
        name: '',
        vertexCount: 0,
        indexCount: 0,
        bounds: BoundingBox3D(minX: 0, minY: 0, minZ: 0, maxX: 0, maxY: 0, maxZ: 0),
      ),
    );

    if (prim.positions == null || prim.indices == null) {
      return false;
    }

    final Float32List pos = prim.positions!;
    final Uint32List ind = prim.indices!;
    final BoundingBox3D bounds = parsedMesh!.bounds;

    final double maxDim = bounds.maxDimension > 0.001 ? bounds.maxDimension : 1.0;
    final double targetHeight = size.height * 0.58 * zoom;
    final double scale = targetHeight / maxDim;

    final double bCenterX = bounds.centerX;
    final double bCenterY = bounds.centerY;
    final double bCenterZ = bounds.centerZ;

    // Camera setup
    const double cameraZ = 3.8;
    final double fov = size.height * 0.72;

    final double cosP = math.cos(pitch);
    final double sinP = math.sin(pitch);

    // In weapon mode, apply a heroic dynamic presentation tilt (Z-axis roll)
    final double roll = mode == TurntableMode.weapon ? 0.38 : 0.0;
    final double cosR = math.cos(roll);
    final double sinR = math.sin(roll);

    // Light direction vector from lighting preset
    final double lx = lightingPreset.lightVector2D.x;
    final double ly = lightingPreset.lightVector2D.y;
    final double lz = lightingPreset.lightZ;
    final double lLen = math.sqrt(lx * lx + ly * ly + lz * lz);
    final double nLx = lx / lLen;
    final double nLy = ly / lLen;
    final double nLz = lz / lLen;

    final Color primaryColor = _getClassPrimaryColor();
    final Color keyColor = lightingPreset.keyLightColor(primaryColor);
    final Color rimColor = enableSecondaryRimLight
        ? lightingPreset.rimLightColor(_getClassSecondaryColor())
        : Colors.transparent;

    // Collect triangles for depth sorting
    final int triCount = ind.length ~/ 3;
    final List<_ProjectedTriangle> triangles = <_ProjectedTriangle>[];

    for (int t = 0; t < triCount; t++) {
      final int i0 = ind[t * 3];
      final int i1 = ind[t * 3 + 1];
      final int i2 = ind[t * 3 + 2];

      if ((i0 * 3 + 2) >= pos.length ||
          (i1 * 3 + 2) >= pos.length ||
          (i2 * 3 + 2) >= pos.length) {
        continue;
      }

      // Vertex 0
      final double x0 = (pos[i0 * 3] - bCenterX) * scale;
      final double y0 = (pos[i0 * 3 + 1] - bCenterY) * scale;
      final double z0 = (pos[i0 * 3 + 2] - bCenterZ) * scale;

      // Vertex 1
      final double x1 = (pos[i1 * 3] - bCenterX) * scale;
      final double y1 = (pos[i1 * 3 + 1] - bCenterY) * scale;
      final double z1 = (pos[i1 * 3 + 2] - bCenterZ) * scale;

      // Vertex 2
      final double x2 = (pos[i2 * 3] - bCenterX) * scale;
      final double y2 = (pos[i2 * 3 + 1] - bCenterY) * scale;
      final double z2 = (pos[i2 * 3 + 2] - bCenterZ) * scale;

      // 3D Transform: Roll (Z) -> Pitch (X) -> Yaw (Y)
      final Offset p0 = _projectPoint(x0, y0, z0, cosR, sinR, cosP, sinP, cosYaw, sinYaw, cameraZ, fov);
      final Offset p1 = _projectPoint(x1, y1, z1, cosR, sinR, cosP, sinP, cosYaw, sinYaw, cameraZ, fov);
      final Offset p2 = _projectPoint(x2, y2, z2, cosR, sinR, cosP, sinP, cosYaw, sinYaw, cameraZ, fov);

      // Backface culling in screen space (signed triangle area)
      final double crossZ = (p1.dx - p0.dx) * (p2.dy - p0.dy) - (p1.dy - p0.dy) * (p2.dx - p0.dx);
      if (crossZ <= 0) continue;

      // Face normal for lighting
      final double v1x = x1 - x0;
      final double v1y = y1 - y0;
      final double v1z = z1 - z0;
      final double v2x = x2 - x0;
      final double v2y = y2 - y0;
      final double v2z = z2 - z0;

      final double nx = v1y * v2z - v1z * v2y;
      final double ny = v1z * v2x - v1x * v2z;
      final double nz = v1x * v2y - v1y * v2x;
      final double nMag = math.sqrt(nx * nx + ny * ny + nz * nz);

      double diffuse = 0.4;
      if (nMag > 0.0001) {
        final double dotL = (nx / nMag) * nLx + (ny / nMag) * nLy + (nz / nMag) * nLz;
        diffuse = (dotL.clamp(0.0, 1.0) * 0.6) + 0.35;
      }

      final double avgZ = (z0 + z1 + z2) / 3.0;

      triangles.add(_ProjectedTriangle(
        p0: p0,
        p1: p1,
        p2: p2,
        depth: avgZ,
        diffuse: diffuse,
      ));
    }

    // Depth sort far-to-near (Painter's algorithm)
    triangles.sort((a, b) => a.depth.compareTo(b.depth));

    // Render sorted triangles
    for (final _ProjectedTriangle tri in triangles) {
      final Path triPath = Path()
        ..moveTo(tri.p0.dx, tri.p0.dy)
        ..lineTo(tri.p1.dx, tri.p1.dy)
        ..lineTo(tri.p2.dx, tri.p2.dy)
        ..close();

      final Color triColor = Color.lerp(
        AppColors.spaceNavy,
        keyColor,
        tri.diffuse * (runesActive ? 0.9 : 0.6),
      )!;

      final Paint triPaint = Paint()
        ..color = triColor
        ..style = PaintingStyle.fill;

      canvas.drawPath(triPath, triPaint);

      // Edge wireframe highlight for runic mesh definition (secondary rim light calculation)
      if (runesActive && enableSecondaryRimLight) {
        final Paint wirePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = rimColor.withValues(alpha: (tri.diffuse * 0.4).clamp(0.0, 0.8));
        canvas.drawPath(triPath, wirePaint);
      }
    }

    return triangles.isNotEmpty;
  }

  Offset _projectPoint(
    double x,
    double y,
    double z,
    double cosR,
    double sinR,
    double cosP,
    double sinP,
    double cosY,
    double sinY,
    double cameraZ,
    double fov,
  ) {
    // Roll (Z)
    final double xR = x * cosR - y * sinR;
    final double yR = x * sinR + y * cosR;
    final double zR = z;

    // Pitch (X)
    final double xP = xR;
    final double yP = yR * cosP - zR * sinP;
    final double zP = yR * sinP + zR * cosP;

    // Yaw (Y)
    final double xY = xP * cosY + zP * sinY;
    final double yY = yP;
    final double zY = -xP * sinY + zP * cosY;

    // Perspective projection
    final double dist = zY + cameraZ;
    final double safeDist = dist > 0.1 ? dist : 0.1;
    final double px = (xY / safeDist) * fov;
    final double py = -(yY / safeDist) * fov;

    return Offset(px, py);
  }

  // --------------------------------------------------------------------------
  // HIGH-FIDELITY SPRITE WITH IRIDESCENT ARMOR SHEEN FALLBACK
  // --------------------------------------------------------------------------

  void _drawCharacterSpriteWithIridescence(
    Canvas canvas,
    double cosYaw,
    double sinYaw,
  ) {
    canvas.save();
    // Y-axis perspective scale
    canvas.scale(cosYaw.abs().clamp(0.18, 1.0) * (cosYaw >= 0 ? 1.0 : -1.0), 1.0);
    canvas.translate(0, pitch * 30.0);

    final double modelWidth = 200.0 * zoom;
    final double modelHeight = 270.0 * zoom;

    final Rect destRect = Rect.fromCenter(
      center: const Offset(0, -20),
      width: modelWidth,
      height: modelHeight,
    );

    final Rect srcRect = Rect.fromLTWH(
      0,
      0,
      characterImage!.width.toDouble(),
      characterImage!.height.toDouble(),
    );

    canvas.drawImageRect(characterImage!, srcRect, destRect, Paint());

    // Iridescent Armor Sheen Overlay
    _drawIridescentArmorSheen(canvas, destRect, sinYaw, cosYaw);

    canvas.restore();
  }

  void _drawIridescentArmorSheen(
    Canvas canvas,
    Rect bounds,
    double sinYaw,
    double cosYaw,
  ) {
    final double sweep = (sinYaw + math.sin(animValue * 2 * math.pi) * 0.4).clamp(-1.0, 1.0);
    final double highlightX = bounds.center.dx + (sweep * bounds.width * 0.4);

    if (enableSecondaryRimLight) {
      final Paint sheenPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(highlightX - 45, bounds.top),
          Offset(highlightX + 45, bounds.bottom),
          <Color>[
            Colors.transparent,
            lightingPreset.keyLightColor(AppColors.accentCyan).withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.45),
            lightingPreset.rimLightColor(AppColors.liquidGold).withValues(alpha: 0.28),
            Colors.transparent,
          ],
          <double>[0.0, 0.35, 0.5, 0.65, 1.0],
        )
        ..blendMode = BlendMode.screen;

      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.deflate(14), const Radius.circular(20)),
        sheenPaint,
      );

      // Fresnel Rim Lighting on Silhouette Edges
      final double rimIntensity = (1.0 - cosYaw.abs()).clamp(0.0, 1.0);
      if (rimIntensity > 0.1) {
        final Paint rimPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = lightingPreset.rimLightColor(_getClassPrimaryColor()).withValues(alpha: rimIntensity * 0.68)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);

        canvas.drawRRect(
          RRect.fromRectAndRadius(bounds.deflate(12), const Radius.circular(16)),
          rimPaint,
        );
      }
    } else {
      // Eco / Low tiers (<=2GB RAM): bypass secondary rim light calculation and Fresnel blur pass
      final Paint sheenPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(highlightX - 30, bounds.top),
          Offset(highlightX + 30, bounds.bottom),
          <Color>[
            Colors.transparent,
            Colors.white.withValues(alpha: 0.30),
            Colors.transparent,
          ],
          <double>[0.0, 0.5, 1.0],
        )
        ..blendMode = BlendMode.screen;

      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.deflate(14), const Radius.circular(20)),
        sheenPaint,
      );
    }
  }

  // --------------------------------------------------------------------------
  // PROCEDURAL RUNIC SILHOUETTE (CHARACTER & WEAPON FALLBACKS)
  // --------------------------------------------------------------------------

  void _drawProceduralCharacterRunicSilhouette(
    Canvas canvas,
    double cosYaw,
    double sinYaw,
  ) {
    canvas.save();
    canvas.scale(cosYaw.abs().clamp(0.2, 1.0), 1.0);

    final double width = 200.0 * zoom;
    final double height = 270.0 * zoom;
    final Color primary = _getClassPrimaryColor();

    // Torso armor plate
    final RRect torso = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -10), width: width * 0.6, height: height * 0.5),
      const Radius.circular(16),
    );

    final Paint torsoPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, -height * 0.3),
        Offset(0, height * 0.2),
        <Color>[AppColors.darkObsidian, AppColors.spaceNavy, Colors.black],
        <double>[0.0, 0.5, 1.0],
      );
    canvas.drawRRect(torso, torsoPaint);

    // Golden Armor Trim
    final Paint trimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = primary.withValues(alpha: runesActive ? 0.85 : 0.4);
    canvas.drawRRect(torso, trimPaint);

    // Helmet / Crest
    final Rect headRect = Rect.fromCenter(
      center: Offset(0, -height * 0.38),
      width: width * 0.34,
      height: height * 0.24,
    );
    canvas.drawOval(headRect, torsoPaint);
    canvas.drawOval(headRect, trimPaint);

    // Glowing Visor / Rune Core
    final Paint visorPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(sinYaw * 12, -height * 0.38), width: 34, height: 6),
        const Radius.circular(3),
      ),
      visorPaint,
    );

    // Iridescent Sheen
    _drawIridescentArmorSheen(
      canvas,
      Rect.fromCenter(center: const Offset(0, -20), width: width, height: height),
      sinYaw,
      cosYaw,
    );

    canvas.restore();
  }

  void _drawProceduralWeaponRunicSilhouette(
    Canvas canvas,
    double cosYaw,
    double sinYaw,
  ) {
    canvas.save();

    // Dynamic presentation tilt (diagonal 35 degrees) + yaw spin
    canvas.rotate(0.45);
    canvas.scale(cosYaw.abs().clamp(0.25, 1.0), 1.0);

    final double bladeLen = 220.0 * zoom;
    final double bladeWidth = 32.0 * zoom;
    final Color primary = _getClassPrimaryColor();

    // Blade Steel Body
    final Path bladePath = Path();
    bladePath.moveTo(0, -bladeLen * 0.55); // Tip
    bladePath.lineTo(bladeWidth * 0.5, -bladeLen * 0.4);
    bladePath.lineTo(bladeWidth * 0.45, bladeLen * 0.15);
    bladePath.lineTo(-bladeWidth * 0.45, bladeLen * 0.15);
    bladePath.lineTo(-bladeWidth * 0.5, -bladeLen * 0.4);
    bladePath.close();

    final Paint bladePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, -bladeLen * 0.55),
        Offset(0, bladeLen * 0.15),
        <Color>[
          Colors.white,
          AppColors.spaceNavy,
          AppColors.darkObsidian,
        ],
        <double>[0.0, 0.4, 1.0],
      );
    canvas.drawPath(bladePath, bladePaint);

    // Glowing Runic Fuller / Center Groove
    final Paint fullerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = runesActive ? 2.2 : 1.2
      ..color = runesActive ? primary : Colors.white54
      ..maskFilter = runesActive ? const MaskFilter.blur(BlurStyle.solid, 3.0) : null;
    canvas.drawLine(
      Offset(0, -bladeLen * 0.48),
      Offset(0, bladeLen * 0.1),
      fullerPaint,
    );

    // Crossguard
    final RRect guard = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, bladeLen * 0.16),
        width: bladeWidth * 2.2,
        height: 12 * zoom,
      ),
      const Radius.circular(4),
    );
    final Paint guardPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.fill;
    canvas.drawRRect(guard, guardPaint);

    // Grip & Pommel
    final RRect grip = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, bladeLen * 0.28),
        width: 10 * zoom,
        height: bladeLen * 0.2,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(grip, Paint()..color = AppColors.darkObsidian);

    final Paint pommelPaint = Paint()..color = primary;
    canvas.drawCircle(Offset(0, bladeLen * 0.39), 8 * zoom, pommelPaint);

    // Runic Etched Glyphs along Blade
    if (runesActive) {
      _drawBladeRunes(canvas, bladeLen, primary);
    }

    canvas.restore();
  }

  void _drawBladeRunes(Canvas canvas, double bladeLen, Color color) {
    const int runeCount = 5;
    for (int i = 0; i < runeCount; i++) {
      final double ry = -bladeLen * 0.4 + (i * (bladeLen * 0.1));
      final double pulse = math.sin((animValue * 6.28) + (i * 0.8)) * 0.3 + 0.7;

      final Paint glyphPaint = Paint()
        ..color = Colors.white.withValues(alpha: pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);

      canvas.drawCircle(Offset(0, ry), 2.4, glyphPaint);
    }
  }

  // --------------------------------------------------------------------------
  // SOCKET CONSTELLATION OVERLAYS
  // --------------------------------------------------------------------------

  void _drawSocketConstellations(Canvas canvas, double cx, double cy, Size size) {
    final double pulse = math.sin(animValue * 2 * math.pi) * 0.2 + 0.8;
    final Color glowColor = _getClassPrimaryColor().withValues(alpha: 0.28 * pulse);

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = glowColor;

    // Left chest to left gear dock
    canvas.drawLine(Offset(cx - 30, cy - 30), Offset(cx - size.width * 0.36, cy - 60), linePaint);
    // Right hand to right weapon dock
    canvas.drawLine(Offset(cx + 35, cy), Offset(cx + size.width * 0.36, cy - 20), linePaint);
  }

  void _drawWeaponSocketHighlights(Canvas canvas, double cx, double cy, Size size) {
    final double pulse = math.sin(animValue * 3.14) * 0.3 + 0.7;
    final Color accent = _getClassPrimaryColor();

    // Floating socket node markers around weapon
    final List<Offset> socketNodes = <Offset>[
      Offset(cx - 35, cy - 80), // Blade tip socket
      Offset(cx + 10, cy + 10), // Guard rune socket
      Offset(cx + 45, cy + 85), // Pommel core socket
    ];

    for (int i = 0; i < socketNodes.length; i++) {
      final Offset node = socketNodes[i];

      final Paint ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.8 * pulse);
      canvas.drawCircle(node, 7.0, ringPaint);

      final Paint corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * pulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node, 2.8, corePaint);
    }
  }

  // --------------------------------------------------------------------------
  // COLOR PALETTES PER CLASS
  // --------------------------------------------------------------------------

  Color _getClassPrimaryColor() {
    return switch (characterClass) {
      CharacterClass.warrior => AppColors.liquidGold,
      CharacterClass.alchemist => AppColors.toxicNeon,
      CharacterClass.shadow => AppColors.cyberFuchsia,
      null => AppColors.liquidGold,
    };
  }

  Color _getClassSecondaryColor() {
    return switch (characterClass) {
      CharacterClass.warrior => AppColors.warningSolar,
      CharacterClass.alchemist => AppColors.accentCyan,
      CharacterClass.shadow => AppColors.accentPurple,
      null => AppColors.warningSolar,
    };
  }

  @override
  bool shouldRepaint(covariant _Aion2CharacterPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.animValue != animValue ||
        oldDelegate.mode != mode ||
        oldDelegate.runesActive != runesActive ||
        oldDelegate.lightingPreset != lightingPreset ||
        oldDelegate.characterClass != characterClass ||
        oldDelegate.characterImage != characterImage ||
        oldDelegate.parsedMesh != parsedMesh ||
        oldDelegate.isLoadingMesh != isLoadingMesh ||
        oldDelegate.equippedCount != equippedCount ||
        oldDelegate.enableSecondaryRimLight != enableSecondaryRimLight ||
        oldDelegate.enableDynamicShadowPedestal != enableDynamicShadowPedestal ||
        oldDelegate.hardwareTier != hardwareTier;
  }
}

class _ProjectedTriangle {
  final Offset p0;
  final Offset p1;
  final Offset p2;
  final double depth;
  final double diffuse;

  const _ProjectedTriangle({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.depth,
    required this.diffuse,
  });
}
