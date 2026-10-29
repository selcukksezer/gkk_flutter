import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/assets/mesh_asset_registry.dart';
import 'mekan_design.dart';

/// Visual rendering shading mode for the 3D viewport canvas.
enum MekanShadingMode {
  /// Realistic PBR lit shading with Lambertian diffuse and specular highlights.
  lit,

  /// Arcane tactical holographic wireframe projection.
  wireframe,

  /// Luminous celestial energy emission with intense rim bloom.
  aetherGlow,
}

/// Cinematic camera bookmark positions for instant inspection angles.
enum MekanCameraBookmark {
  front,
  isometric,
  aerial,
  closeHero,
}

/// Preset regional location and dungeon environment descriptors.
class MekanLocationDescriptor {
  const MekanLocationDescriptor({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.typeKey,
    required this.modelPath,
    required this.fallbackModelPaths,
    required this.accentColor,
    required this.icon,
    required this.recommendedLevel,
    required this.dungeonName,
    required this.supportedDifficulties,
    required this.defaultAzimuth,
    required this.defaultElevation,
    required this.defaultZoom,
    required this.worldOffset,
    this.scenicBackdropPath = 'assets/images/backgrounds/elysea/bg_sanctum_citadel.png',
    this.tagline = 'KADİM MEKAN & GÖKSEL SİGİL',
    this.dungeonTier = 'T1 KADİM',
    this.bossName = 'Muhafız Lordu',
    this.elementalAttribute = 'AETHER',
  });

  final String id;
  final String name;
  final String subtitle;
  final String typeKey;
  final String modelPath;
  final List<String> fallbackModelPaths;
  final Color accentColor;
  final IconData icon;
  final int recommendedLevel;
  final String dungeonName;
  final List<String> supportedDifficulties;
  final double defaultAzimuth;
  final double defaultElevation;
  final double defaultZoom;
  final Offset worldOffset;

  /// High-fidelity scenic backdrop image mapped to this regional sector.
  final String scenicBackdropPath;

  /// Celestial or faction tagline banner.
  final String tagline;

  /// Expedition dungeon classification tier.
  final String dungeonTier;

  /// Dominant boss entity name awaiting within the dungeon depth.
  final String bossName;

  /// Elemental runic energy affinity.
  final String elementalAttribute;

  static const List<MekanLocationDescriptor> catalog = <MekanLocationDescriptor>[
    MekanLocationDescriptor(
      id: 'all',
      name: 'Sanctum Başkenti & Gece Meydanı',
      subtitle: 'Tüm mekanlar, tavernalar ve kadim zindan geçitleri',
      typeKey: 'all',
      modelPath: 'assets/models/environment/dungeon_warkarma.glb',
      fallbackModelPaths: <String>[
        'assets/models/props/GothicArch_Lancet_LOD0.glb',
        'assets/models/props/GothicArch_Lancet.glb',
        'assets/models/environment/crypt-large.glb',
      ],
      accentColor: MekanPalette.aqua,
      icon: Icons.public_rounded,
      recommendedLevel: 1,
      dungeonName: 'Sanctum Kadim Meydanı',
      supportedDifficulties: <String>['Normal', 'Heroic', 'Mythic'],
      defaultAzimuth: 0.35,
      defaultElevation: 0.22,
      defaultZoom: 1.0,
      worldOffset: Offset.zero,
      scenicBackdropPath: 'assets/images/backgrounds/elysea/bg_sanctum_citadel.png',
      tagline: 'KADİM BAŞKENT & ELYSİA IŞIĞI',
      dungeonTier: 'T1 BAŞKENT',
      bossName: 'Lord Kaisinel Muhafızı',
      elementalAttribute: 'GÖKSEL IŞIK',
    ),
    MekanLocationDescriptor(
      id: 'bar',
      name: 'Simyacı Taverna & İksir Barı',
      subtitle: 'Karanlık enerji iksirleri, canlı müzik ve gece hayatı',
      typeKey: 'bar',
      modelPath: 'assets/models/props/Brazier_IronEmbers_LOD0.glb',
      fallbackModelPaths: <String>[
        'assets/models/props/Brazier_IronEmbers.glb',
        'assets/models/environment/column-large.glb',
        'assets/models/props/Flagstones_CrackedTile_LOD0.glb',
      ],
      accentColor: MekanPalette.aqua,
      icon: Icons.local_bar_rounded,
      recommendedLevel: 15,
      dungeonName: 'Karanlık Mahzen Taverna Odası',
      supportedDifficulties: <String>['Normal', 'Heroic'],
      defaultAzimuth: 0.85,
      defaultElevation: 0.18,
      defaultZoom: 1.15,
      worldOffset: Offset(-1.8, 0.4),
      scenicBackdropPath: 'assets/images/backgrounds/asmodae/bg_pandaemonium_capital.png',
      tagline: 'ASMODİAN SİMYASI & GECE GÖLGESİ',
      dungeonTier: 'T2 MAHZEN',
      bossName: 'Simyacı Belial',
      elementalAttribute: 'KARA ATEŞ',
    ),
    MekanLocationDescriptor(
      id: 'kahvehane',
      name: 'Mistik Şifa & Detoks Ocağı',
      subtitle: 'Kadim arınma iksirleri, şifa ritüelleri ve strateji meclisi',
      typeKey: 'kahvehane',
      modelPath: 'assets/models/props/StoneAltar_Ritual_LOD0.glb',
      fallbackModelPaths: <String>[
        'assets/models/props/StoneAltar_Ritual.glb',
        'assets/models/environment/altar-stone.glb',
        'assets/models/environment/pillar-obelisk.glb',
      ],
      accentColor: MekanPalette.gold,
      icon: Icons.coffee_rounded,
      recommendedLevel: 20,
      dungeonName: 'Mistik Şifa Mağarası',
      supportedDifficulties: <String>['Normal', 'Heroic', 'Mythic'],
      defaultAzimuth: -0.65,
      defaultElevation: 0.25,
      defaultZoom: 1.1,
      worldOffset: Offset(1.6, -0.2),
      scenicBackdropPath: 'assets/images/backgrounds/elysea/bg_heiron_temple.png',
      tagline: 'MİSTİK ŞİFA & ARINMA TAPINAĞI',
      dungeonTier: 'T3 TAPINAK',
      bossName: 'Kadim Başrahip Aethel',
      elementalAttribute: 'ŞİFA RÜZGARI',
    ),
    MekanLocationDescriptor(
      id: 'dovus_kulubu',
      name: 'Yeraltı Dövüş Kulübü & Gladyatör Koloseumu',
      subtitle: 'Kanlı PvP düelloları, bahis turnuvaları ve şöhret basamakları',
      typeKey: 'dovus_kulubu',
      modelPath: 'assets/models/props/Gargoyle_DarkStone_LOD0.glb',
      fallbackModelPaths: <String>[
        'assets/models/props/Gargoyle_DarkStone.glb',
        'assets/models/props/Portcullis_HeavyIron_LOD0.glb',
        'assets/models/environment/Column_Broken.glb',
      ],
      accentColor: MekanPalette.ruby,
      icon: Icons.sports_mma_rounded,
      recommendedLevel: 30,
      dungeonName: 'Gladyatör Zindan Arenası',
      supportedDifficulties: <String>['Normal', 'Heroic', 'Mythic'],
      defaultAzimuth: 1.25,
      defaultElevation: 0.20,
      defaultZoom: 1.25,
      worldOffset: Offset(0.0, 1.8),
      scenicBackdropPath: 'assets/images/backgrounds/dungeons/bg_empyrean_arena.png',
      tagline: 'KANLI GLADYATÖR KOLOSEUMU',
      dungeonTier: 'T4 ARENA',
      bossName: 'Gladyatör Şampiyonu Vulkan',
      elementalAttribute: 'ÖFKE KIVILCIMI',
    ),
    MekanLocationDescriptor(
      id: 'luks_lounge',
      name: 'Sanctum VIP Göksel Lounge',
      subtitle: 'Aristokrat tüccarlar, elit iksir müzayedeleri ve prestij',
      typeKey: 'luks_lounge',
      modelPath: 'assets/models/props/GothicArch_Lancet_LOD0.glb',
      fallbackModelPaths: <String>[
        'assets/models/props/GothicArch_Lancet.glb',
        'assets/models/environment/crypt-large.glb',
        'assets/models/props/StoneAltar_Ritual_LOD0.glb',
      ],
      accentColor: MekanPalette.amethyst,
      icon: Icons.diamond_rounded,
      recommendedLevel: 45,
      dungeonName: 'Göksel Saray Hazine Odası',
      supportedDifficulties: <String>['Heroic', 'Mythic'],
      defaultAzimuth: -1.4,
      defaultElevation: 0.28,
      defaultZoom: 1.05,
      worldOffset: Offset(-1.2, -1.4),
      scenicBackdropPath: 'assets/images/backgrounds/asmodae/bg_beluslan_frozen_sea.png',
      tagline: 'GÖKSEL PRESTİJ & KUTUP AURORASI',
      dungeonTier: 'T5 HAZİNE',
      bossName: 'Hazine Muhafızı Ejder',
      elementalAttribute: 'BUZUL KRİSTALİ',
    ),
    MekanLocationDescriptor(
      id: 'yeralti',
      name: 'Abyss Kaçak Katakombu & Karaborsa',
      subtitle: 'Yasak iksirler, kaçak eşyalar ve ölümcül zindan baskınları',
      typeKey: 'yeralti',
      modelPath: 'assets/models/environment/dungeon_warkarma.glb',
      fallbackModelPaths: <String>[
        'assets/models/props/Portcullis_HeavyIron_LOD0.glb',
        'assets/models/props/Gargoyle_DarkStone_LOD0.glb',
        'assets/models/environment/Column_Broken.glb',
      ],
      accentColor: MekanPalette.neon,
      icon: Icons.nightlight_round,
      recommendedLevel: 60,
      dungeonName: 'Abyss Derin Katakomb Zindanı',
      supportedDifficulties: <String>['Heroic', 'Mythic'],
      defaultAzimuth: 0.05,
      defaultElevation: 0.16,
      defaultZoom: 1.2,
      worldOffset: Offset(1.9, 1.5),
      scenicBackdropPath: 'assets/images/backgrounds/dungeons/bg_abyss_core_warzone.png',
      tagline: 'ABYSS DERİNLİKLERİ & KARABORSA',
      dungeonTier: 'T6 DERİNLİK',
      bossName: 'Abyss Dehşeti Tiamat Gölgesi',
      elementalAttribute: 'KARA ENERJİ',
    ),
  ];

  static MekanLocationDescriptor forType(String? typeKey) {
    if (typeKey == null || typeKey == 'all') {
      return catalog.first;
    }
    for (final MekanLocationDescriptor loc in catalog) {
      if (loc.typeKey == typeKey || loc.id == typeKey) {
        return loc;
      }
    }
    return catalog.first;
  }
}

/// Controller managing camera orbit, focus transitions, shading mode, and mesh cache for [Mekan3DViewport].
class Mekan3DViewportController extends ChangeNotifier {
  Mekan3DViewportController({
    String initialLocationType = 'all',
    this.autoRotate = true,
  })  : _currentLocationType = initialLocationType,
        _activeDescriptor = MekanLocationDescriptor.forType(initialLocationType) {
    _yaw = _activeDescriptor.defaultAzimuth;
    _pitch = _activeDescriptor.defaultElevation;
    _zoom = _activeDescriptor.defaultZoom;
  }

  String _currentLocationType;
  String get currentLocationType => _currentLocationType;

  MekanLocationDescriptor _activeDescriptor;
  MekanLocationDescriptor get activeDescriptor => _activeDescriptor;

  String _selectedDifficulty = 'Normal';
  String get selectedDifficulty => _selectedDifficulty;

  double _yaw = 0.35;
  double get yaw => _yaw;

  double _pitch = 0.22;
  double get pitch => _pitch;

  double _zoom = 1.0;
  double get zoom => _zoom;

  bool autoRotate;
  bool _isInteracting = false;
  bool get isInteracting => _isInteracting;

  // Visual shading mode (Lit PBR, Arcane Wireframe, Celestial Aether Glow)
  MekanShadingMode _shadingMode = MekanShadingMode.lit;
  MekanShadingMode get shadingMode => _shadingMode;

  // Inertia velocities
  double _yawVelocity = 0.0;
  double _pitchVelocity = 0.0;

  // Animation interpolation state
  double _targetYaw = 0.35;
  double _targetPitch = 0.22;
  double _targetZoom = 1.0;
  bool _isTransitioning = false;

  // Lifecycle disposal safety guard
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Cycles between Lit 3D, Arcane Wireframe, and Aether Glow shading modes.
  void toggleShadingMode() {
    _shadingMode = switch (_shadingMode) {
      MekanShadingMode.lit => MekanShadingMode.wireframe,
      MekanShadingMode.wireframe => MekanShadingMode.aetherGlow,
      MekanShadingMode.aetherGlow => MekanShadingMode.lit,
    };
    notifyListeners();
  }

  /// Instantly transitions the camera to one of the cinematic tactical bookmarks.
  void setCameraBookmark(MekanCameraBookmark bookmark) {
    switch (bookmark) {
      case MekanCameraBookmark.front:
        _targetYaw = _activeDescriptor.defaultAzimuth;
        _targetPitch = _activeDescriptor.defaultElevation;
        _targetZoom = _activeDescriptor.defaultZoom;
      case MekanCameraBookmark.isometric:
        _targetYaw = _activeDescriptor.defaultAzimuth + (math.pi / 4);
        _targetPitch = 0.38;
        _targetZoom = _activeDescriptor.defaultZoom * 0.95;
      case MekanCameraBookmark.aerial:
        _targetYaw = _activeDescriptor.defaultAzimuth;
        _targetPitch = 0.60;
        _targetZoom = _activeDescriptor.defaultZoom * 0.85;
      case MekanCameraBookmark.closeHero:
        _targetYaw = _activeDescriptor.defaultAzimuth - 0.25;
        _targetPitch = 0.10;
        _targetZoom = _activeDescriptor.defaultZoom * 1.30;
    }
    _isTransitioning = true;
    _yawVelocity = 0.0;
    _pitchVelocity = 0.0;
    notifyListeners();
  }

  /// Azimuth angle in whole degrees [0 .. 359].
  int get compassAzimuthDegrees {
    final double deg = (_yaw * 180 / math.pi) % 360;
    return (deg < 0 ? deg + 360 : deg).round();
  }

  /// Compass direction string with heading (e.g. "K (0°)", "KD (45°)").
  String get compassDirectionLabel {
    final int deg = compassAzimuthDegrees;
    if (deg >= 337 || deg < 23) return 'K (${deg}°)';
    if (deg >= 23 && deg < 68) return 'KD (${deg}°)';
    if (deg >= 68 && deg < 113) return 'D (${deg}°)';
    if (deg >= 113 && deg < 158) return 'GD (${deg}°)';
    if (deg >= 158 && deg < 203) return 'G (${deg}°)';
    if (deg >= 203 && deg < 248) return 'GB (${deg}°)';
    if (deg >= 248 && deg < 293) return 'B (${deg}°)';
    return 'KB (${deg}°)';
  }

  void setInteracting(bool interacting) {
    _isInteracting = interacting;
    if (interacting) {
      _yawVelocity = 0.0;
      _pitchVelocity = 0.0;
      _isTransitioning = false;
    }
    notifyListeners();
  }

  void addOrbit(double deltaYaw, double deltaPitch) {
    _yaw += deltaYaw;
    _pitch = (_pitch + deltaPitch).clamp(-0.45, 0.65);
    _yawVelocity = deltaYaw * 0.75;
    _pitchVelocity = deltaPitch * 0.75;
    notifyListeners();
  }

  void setZoom(double newZoom) {
    _zoom = newZoom.clamp(0.65, 2.5);
    notifyListeners();
  }

  void setDifficulty(String difficulty) {
    if (_selectedDifficulty != difficulty) {
      _selectedDifficulty = difficulty;
      notifyListeners();
    }
  }

  /// Smoothly animates camera focus to a new location / dungeon.
  void focusOnLocation(String locationType) {
    final MekanLocationDescriptor desc = MekanLocationDescriptor.forType(locationType);
    _currentLocationType = locationType;
    _activeDescriptor = desc;
    _targetYaw = desc.defaultAzimuth;
    _targetPitch = desc.defaultElevation;
    _targetZoom = desc.defaultZoom;
    _isTransitioning = true;
    _yawVelocity = 0.0;
    _pitchVelocity = 0.0;
    notifyListeners();
  }

  void resetCamera() {
    _targetYaw = _activeDescriptor.defaultAzimuth;
    _targetPitch = _activeDescriptor.defaultElevation;
    _targetZoom = _activeDescriptor.defaultZoom;
    _isTransitioning = true;
    _yawVelocity = 0.0;
    _pitchVelocity = 0.0;
    notifyListeners();
  }

  /// Periodic update for damping and smooth focus transition.
  void tick(double dt) {
    if (_isDisposed) return;

    if (_isTransitioning) {
      final double lerpFactor = (dt * 5.0).clamp(0.01, 0.25);
      _yaw = _lerpAngle(_yaw, _targetYaw, lerpFactor);
      _pitch = ui.lerpDouble(_pitch, _targetPitch, lerpFactor) ?? _targetPitch;
      _zoom = ui.lerpDouble(_zoom, _targetZoom, lerpFactor) ?? _targetZoom;

      if ((_yaw - _targetYaw).abs() < 0.005 &&
          (_pitch - _targetPitch).abs() < 0.005 &&
          (_zoom - _targetZoom).abs() < 0.005) {
        _yaw = _targetYaw;
        _pitch = _targetPitch;
        _zoom = _targetZoom;
        _isTransitioning = false;
      }
      notifyListeners();
      return;
    }

    if (!_isInteracting) {
      // Apply momentum damping
      if (_yawVelocity.abs() > 0.0001 || _pitchVelocity.abs() > 0.0001) {
        _yaw += _yawVelocity;
        _pitch = (_pitch + _pitchVelocity).clamp(-0.45, 0.65);
        _yawVelocity *= 0.91;
        _pitchVelocity *= 0.91;
        notifyListeners();
      } else if (autoRotate) {
        // Slow idle turntable orbit
        _yaw += dt * 0.12;
        if (_yaw > math.pi * 2) _yaw -= math.pi * 2;
        notifyListeners();
      }
    }
  }

  double _lerpAngle(double a, double b, double t) {
    final double diff = (b - a) % (math.pi * 2);
    final double shortest = ((2 * diff) % (math.pi * 2)) - diff;
    return a + shortest * t;
  }
}

/// Interactive 3D .glb Viewport for Locations, Dungeons, and Regions in Mekans screens.
/// Features:
/// - Real 3D .glb environment and dungeon models (zero primitive blockouts)
/// - Interactive touch camera orbit (drag yaw & pitch, pinch zoom, reset)
/// - Smooth focus camera interpolation when selecting different locations / dungeon types
/// - 3D POI pins projected to screen coordinates with depth scaling & tap handlers
/// - Location difficulty selector (Normal, Heroic, Mythic) & dungeon entry callback
/// - Runic ambient ground pedestal, volumetric atmospheric glow, and floating particle motes
class Mekan3DViewport extends StatefulWidget {
  const Mekan3DViewport({
    super.key,
    this.controller,
    this.selectedLocationType = 'all',
    this.height = 310,
    this.onLocationSelected,
    this.onEnterDungeon,
    this.onDifficultyChanged,
    this.showControls = true,
    this.showDungeonCard = true,
    this.showPoiPins = true,
  });

  final Mekan3DViewportController? controller;
  final String selectedLocationType;
  final double height;
  final ValueChanged<String>? onLocationSelected;
  final void Function(String locationId, String difficulty)? onEnterDungeon;
  final ValueChanged<String>? onDifficultyChanged;
  final bool showControls;
  final bool showDungeonCard;
  final bool showPoiPins;

  @override
  State<Mekan3DViewport> createState() => _Mekan3DViewportState();
}

class _Mekan3DViewportState extends State<Mekan3DViewport>
    with SingleTickerProviderStateMixin {
  late final Mekan3DViewportController _controller;
  late final AnimationController _animController;

  double _baseZoom = 1.0;
  double _lastDetentAngle = 0.0;
  int _activeLoadRequestId = 0;
  bool _isStateDisposed = false;

  // Mesh loading and cache
  static final Map<String, ParsedModelMesh> _meshCache = <String, ParsedModelMesh>{};
  ParsedModelMesh? _currentMesh;
  bool _isLoadingMesh = false;
  String? _loadedModelPath;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        Mekan3DViewportController(initialLocationType: widget.selectedLocationType);
    _controller.addListener(_onControllerTick);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _animController.addListener(_onAnimationTick);

    _loadMeshForLocation(_controller.activeDescriptor);
  }

  @override
  void didUpdateWidget(covariant Mekan3DViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLocationType != oldWidget.selectedLocationType) {
      _controller.focusOnLocation(widget.selectedLocationType);
      _loadMeshForLocation(_controller.activeDescriptor);
    }
  }

  @override
  void dispose() {
    _isStateDisposed = true;
    _animController.removeListener(_onAnimationTick);
    _animController.dispose();
    if (widget.controller == null) {
      _controller.removeListener(_onControllerTick);
      _controller.dispose();
    } else {
      _controller.removeListener(_onControllerTick);
    }
    super.dispose();
  }

  void _onControllerTick() {
    if (mounted && !_isStateDisposed) setState(() {});
  }

  void _onAnimationTick() {
    if (!_isStateDisposed) {
      _controller.tick(0.016);
    }
  }

  Future<void> _loadMeshForLocation(MekanLocationDescriptor desc) async {
    final int loadId = ++_activeLoadRequestId;
    final String targetPath = desc.modelPath;
    if (_loadedModelPath == targetPath && _currentMesh != null) {
      return;
    }

    // Check memory cache first
    if (_meshCache.containsKey(targetPath)) {
      if (mounted && loadId == _activeLoadRequestId && !_isStateDisposed) {
        setState(() {
          _currentMesh = _meshCache[targetPath];
          _loadedModelPath = targetPath;
          _isLoadingMesh = false;
        });
      }
      return;
    }

    if (mounted && loadId == _activeLoadRequestId && !_isStateDisposed) {
      setState(() {
        _isLoadingMesh = true;
      });
    }

    ParsedModelMesh? parsed;

    // 1. Try reading primary target model from filesystem (hot reload / test environment)
    try {
      final io.File file = io.File(targetPath);
      if (file.existsSync()) {
        final Uint8List bytes = await file.readAsBytes();
        parsed = MeshAssetRegistry.instance.parser.parse(
          bytes: bytes,
          modelId: targetPath,
          sourcePath: targetPath,
        );
      }
    } catch (_) {}

    // 2. Try loading from Flutter asset bundle
    if (parsed == null) {
      try {
        final ByteData bd = await rootBundle.load(targetPath);
        final Uint8List bytes =
            bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
        parsed = MeshAssetRegistry.instance.parser.parse(
          bytes: bytes,
          modelId: targetPath,
          sourcePath: targetPath,
        );
      } catch (_) {}
    }

    // 3. Fallback candidates
    if (parsed == null) {
      for (final String candidate in desc.fallbackModelPaths) {
        try {
          final io.File file = io.File(candidate);
          if (file.existsSync()) {
            final Uint8List bytes = await file.readAsBytes();
            parsed = MeshAssetRegistry.instance.parser.parse(
              bytes: bytes,
              modelId: candidate,
              sourcePath: candidate,
            );
            break;
          }
        } catch (_) {}

        try {
          final ByteData bd = await rootBundle.load(candidate);
          final Uint8List bytes =
              bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
          parsed = MeshAssetRegistry.instance.parser.parse(
            bytes: bytes,
            modelId: candidate,
            sourcePath: candidate,
          );
          break;
        } catch (_) {}
      }
    }

    if (parsed != null) {
      _meshCache[targetPath] = parsed;
    }

    if (mounted && loadId == _activeLoadRequestId && !_isStateDisposed) {
      setState(() {
        _currentMesh = parsed;
        _loadedModelPath = targetPath;
        _isLoadingMesh = false;
      });
    }
  }

  // --------------------------------------------------------------------------
  // TOUCH GESTURE HANDLING
  // --------------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    _controller.setInteracting(true);
    _baseZoom = _controller.zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1) {
      final double deltaYaw = details.focalPointDelta.dx * 0.015;
      final double deltaPitch = -details.focalPointDelta.dy * 0.010;
      _controller.addOrbit(deltaYaw, deltaPitch);

      if ((_controller.yaw - _lastDetentAngle).abs() > (math.pi / 2)) {
        _lastDetentAngle = _controller.yaw;
        HapticFeedback.selectionClick();
      }
    }

    if (details.scale != 1.0 && details.scale.isFinite) {
      _controller.setZoom(_baseZoom * details.scale);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _controller.setInteracting(false);
  }

  void _onLocationPinTapped(MekanLocationDescriptor loc) {
    HapticFeedback.mediumImpact();
    _controller.focusOnLocation(loc.typeKey);
    _loadMeshForLocation(loc);
    widget.onLocationSelected?.call(loc.typeKey);
  }

  void _onEnterDungeonPressed() {
    HapticFeedback.heavyImpact();
    widget.onEnterDungeon?.call(
      _controller.activeDescriptor.id,
      _controller.selectedDifficulty,
    );
  }

  void _cycleCameraPreset() {
    HapticFeedback.selectionClick();
    final int nextPreset = ((_controller.compassAzimuthDegrees ~/ 90) + 1) % 4;
    final MekanCameraBookmark b = MekanCameraBookmark.values[nextPreset];
    _controller.setCameraBookmark(b);
  }

  @override
  Widget build(BuildContext context) {
    final MekanLocationDescriptor desc = _controller.activeDescriptor;
    final Color accent = desc.accentColor;

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MekanPalette.void_,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withValues(alpha: 0.50),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ── 0. Cinematic Scenic Vista Underlay Layer (Real Asset Wiring)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: _isLoadingMesh ? 0.38 : 0.20,
                child: Image.asset(
                  desc.scenicBackdropPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // ── 1. Interactive 3D Canvas Projection Viewport
          GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onDoubleTap: () {
              HapticFeedback.lightImpact();
              _controller.resetCamera();
            },
            child: CustomPaint(
              painter: _Mekan3DScenePainter(
                yaw: _controller.yaw,
                pitch: _controller.pitch,
                zoom: _controller.zoom,
                animValue: _animController.value,
                accentColor: accent,
                mesh: _currentMesh,
                descriptor: desc,
                isLoading: _isLoadingMesh,
                shadingMode: _controller.shadingMode,
              ),
              size: Size.infinite,
            ),
          ),

          // ── 2. Top Specular Highlight Edge Hairline
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            height: 1.2,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.transparent,
                    Color(0x75FFFFFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Top Navigation & Inspection Bar
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: _buildTopInspectionBar(desc, accent),
          ),

          // ── 4. Interactive Location POI Pins Overlay (World-to-Screen)
          if (widget.showPoiPins)
            ..._buildProjectedPoiPins(desc, accent),

          // ── 5. Bottom Dungeon & Expedition Action Card
          if (widget.showDungeonCard)
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: _buildBottomDungeonDock(desc, accent),
            ),

          // ── 6. Loading Indicator Overlay (Rich Aion-2 Astrolabe & Celestial Feedback)
          if (_isLoadingMesh)
            Positioned(
              top: 50,
              right: 14,
              child: _buildLoadingOverlay(accent),
            ),
        ],
      ),
    );
  }

  Widget _buildTopInspectionBar(MekanLocationDescriptor desc, Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: MekanPalette.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              // Location Icon & Name
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(desc.icon, size: 14, color: accent),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      desc.name.length > 22
                          ? '${desc.name.substring(0, 20)}...'
                          : desc.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MekanPalette.textHi,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      desc.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.85),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Viewport Controls & HUD
              if (widget.showControls) ...<Widget>[
                // Compass Azimuth Pill (Tap to cycle camera bookmarks)
                GestureDetector(
                  onTap: _cycleCameraPreset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: MekanPalette.surfaceHi.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.explore_rounded,
                          size: 11,
                          color: accent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _controller.compassDirectionLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Shading Mode Switcher (Lit PBR / Hologram Wireframe / Aether Glow)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _controller.toggleShadingMode();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: MekanPalette.surfaceHi.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _controller.shadingMode != MekanShadingMode.lit
                            ? accent.withValues(alpha: 0.75)
                            : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      switch (_controller.shadingMode) {
                        MekanShadingMode.lit => Icons.light_mode_rounded,
                        MekanShadingMode.wireframe => Icons.grid_3x3_rounded,
                        MekanShadingMode.aetherGlow => Icons.auto_awesome_rounded,
                      },
                      size: 13,
                      color: _controller.shadingMode != MekanShadingMode.lit
                          ? accent
                          : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 360° Auto-Rotate Toggle
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _controller.autoRotate = !_controller.autoRotate;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: MekanPalette.surfaceHi.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _controller.autoRotate
                            ? MekanPalette.neon.withValues(alpha: 0.7)
                            : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.rotate_right_rounded,
                          size: 12,
                          color: _controller.autoRotate
                              ? MekanPalette.neon
                              : Colors.white54,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _controller.autoRotate ? '360°' : 'DUR',
                          style: TextStyle(
                            color: _controller.autoRotate
                                ? MekanPalette.neon
                                : Colors.white60,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Camera Reset Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _controller.resetCamera();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: MekanPalette.surfaceHi.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(
                      Icons.restart_alt_rounded,
                      size: 13,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 14,
                height: 14,
                child: RotationTransition(
                  turns: _animController,
                  child: Image.asset(
                    'assets/images/aion2_ui/hud_minimap_compass_bezel.png',
                    width: 14,
                    height: 14,
                    errorBuilder: (_, _, _) => CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '3D Aether Yükleniyor...',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: accent.withValues(alpha: 0.95),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildProjectedPoiPins(MekanLocationDescriptor current, Color accent) {
    final List<Widget> pins = <Widget>[];
    const List<MekanLocationDescriptor> allLocs = MekanLocationDescriptor.catalog;

    for (final MekanLocationDescriptor loc in allLocs) {
      if (loc.id == 'all') continue;
      final bool isCurrent = loc.typeKey == current.typeKey;

      // Project world coordinate into screen space based on camera yaw & pitch
      final double wx = loc.worldOffset.dx;
      final double wy = loc.worldOffset.dy;
      final double angle = math.atan2(wy, wx) + _controller.yaw;
      final double dist = math.sqrt(wx * wx + wy * wy) * 48.0 * _controller.zoom;

      final double px = 180.0 + math.cos(angle) * dist;
      final double py = (widget.height * 0.52) +
          (math.sin(angle) * dist * math.sin(_controller.pitch + 0.5)) -
          (loc.recommendedLevel * 0.2);

      // Clamp to screen bounds safely
      if (px < 15 || px > 350 || py < 50 || py > widget.height - 75) continue;

      // Depth perception scale & alpha based on distance
      final double depthCos = math.cos(angle);
      final double depthScale = isCurrent ? 1.08 : (0.85 + (depthCos + 1.0) * 0.10);
      final double depthAlpha = isCurrent ? 1.0 : (0.75 + (depthCos + 1.0) * 0.12).clamp(0.4, 0.95);

      pins.add(
        Positioned(
          left: px - 24,
          top: py - 18,
          child: Transform.scale(
            scale: depthScale,
            child: Opacity(
              opacity: depthAlpha,
              child: GestureDetector(
                onTap: () => _onLocationPinTapped(loc),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? loc.accentColor.withValues(alpha: 0.92)
                        : MekanPalette.surfaceHi.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? Colors.white : loc.accentColor.withValues(alpha: 0.7),
                      width: isCurrent ? 1.6 : 1.0,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: loc.accentColor.withValues(alpha: isCurrent ? 0.65 : 0.25),
                        blurRadius: isCurrent ? 12 : 6,
                        spreadRadius: isCurrent ? 1 : 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        loc.icon,
                        size: 11,
                        color: isCurrent ? Colors.black : loc.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        loc.typeKey.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: isCurrent ? Colors.black : Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return pins;
  }

  Widget _buildBottomDungeonDock(MekanLocationDescriptor desc, Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: MekanPalette.surfaceHi.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black87,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              // Dungeon Title, Tier & Level
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.castle_rounded, size: 14, color: accent),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            desc.dungeonName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MekanPalette.textHi,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accent.withValues(alpha: 0.45), width: 0.8),
                          ),
                          child: Text(
                            desc.dungeonTier,
                            style: TextStyle(
                              color: accent,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Text(
                          'Önerilen: Lv ${desc.recommendedLevel}+',
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.9),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•  ${desc.bossName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MekanPalette.textMid,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Difficulty Selector Pills
              Row(
                mainAxisSize: MainAxisSize.min,
                children: desc.supportedDifficulties.map((String diff) {
                  final bool isSel = _controller.selectedDifficulty == diff;
                  final Color diffColor = switch (diff) {
                    'Normal' => MekanPalette.aqua,
                    'Heroic' => MekanPalette.gold,
                    'Mythic' => MekanPalette.ruby,
                    _ => Colors.white70,
                  };

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _controller.setDifficulty(diff);
                      widget.onDifficultyChanged?.call(diff);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isSel
                            ? diffColor.withValues(alpha: 0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? diffColor : Colors.white24,
                          width: isSel ? 1.2 : 0.8,
                        ),
                        boxShadow: isSel
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: diffColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        diff,
                        style: TextStyle(
                          color: isSel ? diffColor : Colors.white60,
                          fontSize: 9,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(width: 8),

              // Enter Expedition Action Button
              GestureDetector(
                onTap: _onEnterDungeonPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[accent, accent.withValues(alpha: 0.75)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'ZİNDAN',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 9,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM SCENE PAINTER: REAL 3D PROJECTION ENGINE & RUNIC AMBIANCE
// ============================================================================

class _Mekan3DScenePainter extends CustomPainter {
  _Mekan3DScenePainter({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.animValue,
    required this.accentColor,
    required this.mesh,
    required this.descriptor,
    required this.isLoading,
    this.shadingMode = MekanShadingMode.lit,
  });

  final double yaw;
  final double pitch;
  final double zoom;
  final double animValue;
  final Color accentColor;
  final ParsedModelMesh? mesh;
  final MekanLocationDescriptor descriptor;
  final bool isLoading;
  final MekanShadingMode shadingMode;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.50;

    // 1. Dark Atmospheric Fog & Celestial Skybox Radial Gradient
    _drawAtmosphericSky(canvas, size, cx, cy);

    // 2. 3D Floating Runic Dais / Altar Platform with Astrolabe Spokes
    _drawRunicAltarPedestal(canvas, cx, size.height * 0.78, size.width * 0.42);

    // 3. Volumetric Arcane God-Rays & Floating Arcane Motes
    _drawArcaneAtmosphere(canvas, size, cx, cy);

    // 4. Render Real 3D GLB Mesh (Perspective Projection & Lighting)
    if (mesh != null) {
      _drawProjected3dMesh(canvas, cx, cy);
    } else {
      _drawFallbackAtmosphere(canvas, cx, cy);
    }

    // 5. Tactical Aion-2 HUD Reticle Framing (Luminous Corner Brackets)
    _drawFramingReticles(canvas, size);

    // 6. Emissive Runic Boundary & Vignette
    _drawVignette(canvas, size);
  }

  void _drawAtmosphericSky(Canvas canvas, Size size, double cx, double cy) {
    final Paint bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy * 0.7),
        size.width * 0.85,
        <Color>[
          accentColor.withValues(alpha: 0.18),
          const Color(0xFF0F1524),
          MekanPalette.void_,
        ],
        <double>[0.0, 0.48, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  void _drawRunicAltarPedestal(Canvas canvas, double cx, double cy, double radius) {
    final double rot = animValue * 2 * math.pi;

    // Outer Runic Astrolabe Ring (Clockwise)
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accentColor.withValues(alpha: 0.50);

    final Path outerCircle = Path();
    outerCircle.addOval(Rect.fromCenter(
      center: Offset(cx, cy),
      width: radius * 2.1,
      height: radius * 0.72,
    ));
    canvas.drawPath(outerCircle, ringPaint);

    // Middle Celestial Ring with Tick Marks
    final Paint midRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = accentColor.withValues(alpha: 0.30);

    final Path midCircle = Path();
    midCircle.addOval(Rect.fromCenter(
      center: Offset(cx, cy),
      width: radius * 1.75,
      height: radius * 0.60,
    ));
    canvas.drawPath(midCircle, midRing);

    // Inner Concentric Sigil Ring (Counter-Clockwise)
    final Paint innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = MekanPalette.cyan.withValues(alpha: 0.45);

    final Path innerCircle = Path();
    innerCircle.addOval(Rect.fromCenter(
      center: Offset(cx, cy),
      width: radius * 1.35,
      height: radius * 0.46,
    ));
    canvas.drawPath(innerCircle, innerRing);

    // Center Core Altar Node Glow
    final Paint centerGlow = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        radius * 0.55,
        <Color>[
          accentColor.withValues(alpha: 0.28),
          Colors.transparent,
        ],
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: radius * 0.9,
        height: radius * 0.32,
      ),
      centerGlow,
    );

    // Radial Runic Rays / Celestial Astrolabe Spokes
    for (int i = 0; i < 8; i++) {
      final double ang = rot + (i * math.pi / 4);
      final double x0 = cx + math.cos(ang) * (radius * 0.68);
      final double y0 = cy + math.sin(ang) * (radius * 0.23);
      final double x1 = cx + math.cos(ang) * (radius * 1.05);
      final double y1 = cy + math.sin(ang) * (radius * 0.36);
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), ringPaint);

      // Cardinal Sigil Tick Nodes
      if (i % 2 == 0) {
        final Paint tickPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = (i == 0 ? MekanPalette.gold : accentColor).withValues(alpha: 0.85);
        canvas.drawCircle(Offset(x1, y1), 1.6, tickPaint);
      }
    }
  }

  void _drawArcaneAtmosphere(Canvas canvas, Size size, double cx, double cy) {
    final Paint particlePaint = Paint()..style = PaintingStyle.fill;
    final math.Random rnd = math.Random(42);

    for (int i = 0; i < 22; i++) {
      final double t = (animValue + rnd.nextDouble()) % 1.0;
      final double px = cx + (rnd.nextDouble() - 0.5) * size.width * 0.80 +
          (math.sin(t * math.pi * 2 + i) * 12.0);
      final double py = (size.height * 0.82) - (t * size.height * 0.68);
      final double pSize = 1.2 + rnd.nextDouble() * 2.4;
      final double alpha = (math.sin(t * math.pi) * 0.75).clamp(0.0, 1.0);

      particlePaint.color = (i % 3 == 0 ? MekanPalette.gold : accentColor)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), pSize, particlePaint);

      // Halo on larger particles
      if (pSize > 2.4) {
        final Paint halo = Paint()
          ..style = PaintingStyle.fill
          ..color = accentColor.withValues(alpha: alpha * 0.30);
        canvas.drawCircle(Offset(px, py), pSize * 2.2, halo);
      }
    }
  }

  void _drawProjected3dMesh(Canvas canvas, double cx, double cy) {
    final ParsedModelMesh m = mesh!;
    final BoundingBox3D bounds = m.bounds;
    final double maxDim = bounds.maxDimension > 0 ? bounds.maxDimension : 1.0;

    // Center and scale model to fit viewport comfortably
    final double modelScale = (140.0 / maxDim) * zoom;
    final double modelCenterX = bounds.centerX;
    final double modelCenterY = bounds.centerY;
    final double modelCenterZ = bounds.centerZ;

    // View rotation matrices
    final double cosY = math.cos(yaw);
    final double sinY = math.sin(yaw);
    final double cosP = math.cos(pitch);
    final double sinP = math.sin(pitch);

    // Directional sunlight vector (normalized)
    final double lx = 0.55;
    final double ly = 0.75;
    final double lz = -0.35;
    final double lLen = math.sqrt(lx * lx + ly * ly + lz * lz);
    final double nlx = lx / lLen;
    final double nly = ly / lLen;
    final double nlz = lz / lLen;

    // Half vector for Blinn-Phong specular highlight (view direction = 0, 0, 1)
    final double hx = nlx;
    final double hy = nly;
    final double hz = nlz + 1.0;
    final double hLen = math.sqrt(hx * hx + hy * hy + hz * hz);
    final double nhx = hx / (hLen > 1e-6 ? hLen : 1.0);
    final double nhy = hy / (hLen > 1e-6 ? hLen : 1.0);
    final double nhz = hz / (hLen > 1e-6 ? hLen : 1.0);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = accentColor.withValues(alpha: 0.35);

    // Camera field of view / focal distance
    const double fov = 340.0;
    const double camDist = 380.0;

    for (final ParsedSubmesh sub in m.submeshes) {
      final Float32List? pos = sub.positions;
      final Uint32List? ind = sub.indices;

      if (pos == null || pos.isEmpty) continue;

      final int vertexCount = sub.vertexCount;
      if (vertexCount <= 0) continue;

      // Project vertices to 2D screen space
      final List<Offset> projected = List<Offset>.filled(vertexCount, Offset.zero);
      final List<double> depths = List<double>.filled(vertexCount, 0.0);

      for (int i = 0; i < vertexCount; i++) {
        final int base = i * 3;
        final double x0 = (pos[base] - modelCenterX) * modelScale;
        final double y0 = -(pos[base + 1] - modelCenterY) * modelScale; // Flutter Y is down
        final double z0 = (pos[base + 2] - modelCenterZ) * modelScale;

        // Yaw rotation around Y axis
        final double x1 = x0 * cosY + z0 * sinY;
        final double z1 = -x0 * sinY + z0 * cosY;

        // Pitch rotation around X axis
        final double y2 = y0 * cosP - z1 * sinP;
        final double z2 = y0 * sinP + z1 * cosP;

        final double zProj = z2 + camDist;
        final double factor = fov / (zProj > 10.0 ? zProj : 10.0);

        projected[i] = Offset(cx + x1 * factor, cy + y2 * factor);
        depths[i] = zProj;
      }

      // Draw triangles with backface culling & shading
      if (ind != null && ind.length >= 3) {
        final int triCount = ind.length ~/ 3;
        // Limit max triangles drawn per submesh for mobile 60 FPS budget
        final int step = (triCount > 400) ? (triCount ~/ 400) : 1;

        for (int t = 0; t < triCount; t += step) {
          final int i0 = ind[t * 3];
          final int i1 = ind[t * 3 + 1];
          final int i2 = ind[t * 3 + 2];

          if (i0 >= vertexCount || i1 >= vertexCount || i2 >= vertexCount) continue;

          final Offset p0 = projected[i0];
          final Offset p1 = projected[i1];
          final Offset p2 = projected[i2];

          // 2D Cross product for backface culling
          final double cross =
              (p1.dx - p0.dx) * (p2.dy - p0.dy) - (p1.dy - p0.dy) * (p2.dx - p0.dx);

          // Calculate surface normal for shading
          final double ux = pos[i1 * 3] - pos[i0 * 3];
          final double uy = pos[i1 * 3 + 1] - pos[i0 * 3 + 1];
          final double uz = pos[i1 * 3 + 2] - pos[i0 * 3 + 2];

          final double vx = pos[i2 * 3] - pos[i0 * 3];
          final double vy = pos[i2 * 3 + 1] - pos[i0 * 3 + 1];
          final double vz = pos[i2 * 3 + 2] - pos[i0 * 3 + 2];

          double nx = uy * vz - uz * vy;
          double ny = uz * vx - ux * vz;
          double nz = ux * vy - uy * vx;
          final double nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
          if (nLen > 1e-6) {
            nx /= nLen;
            ny /= nLen;
            nz /= nLen;
          }

          final Path triPath = Path()
            ..moveTo(p0.dx, p0.dy)
            ..lineTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..close();

          // Apply selected Shading Mode
          if (shadingMode == MekanShadingMode.wireframe) {
            // Arcane Tactical Hologram Wireframe Mode
            edgePaint.color = accentColor.withValues(
              alpha: cross > 0 ? 0.85 : 0.35,
            );
            edgePaint.strokeWidth = 1.1;
            canvas.drawPath(triPath, edgePaint);
          } else if (shadingMode == MekanShadingMode.aetherGlow) {
            // Celestial Aether Glow Emission Mode
            final double ndotl = (nx * nlx + ny * nly + nz * nlz).clamp(0.0, 1.0);
            final Color aetherCol = Color.lerp(
                  accentColor,
                  MekanPalette.cyan,
                  ndotl,
                ) ??
                accentColor;
            fillPaint.color = aetherCol.withValues(
              alpha: cross > 0 ? 0.88 : 0.45,
            );
            canvas.drawPath(triPath, fillPaint);
            if (t % 2 == 0) {
              edgePaint.color = Colors.white.withValues(alpha: 0.30);
              canvas.drawPath(triPath, edgePaint);
            }
          } else {
            // Realistic Lit PBR Shading with Lambertian Diffuse + Blinn-Phong Specular
            final double ndotl = (nx * nlx + ny * nly + nz * nlz).clamp(0.0, 1.0);
            final double ndoth = (nx * nhx + ny * nhy + nz * nhz).clamp(0.0, 1.0);
            final double specular = math.pow(ndoth, 16.0).toDouble() * 0.40;
            final double lightIntensity = (0.25 + ndotl * 0.75 + specular).clamp(0.0, 1.0);

            final Color baseShade = Color.lerp(
                  const Color(0xFF131929),
                  accentColor,
                  lightIntensity * 0.85,
                ) ??
                accentColor;

            final Color finalColor = Color.lerp(
                  baseShade,
                  Colors.white,
                  specular,
                ) ??
                baseShade;

            fillPaint.color = finalColor.withValues(
              alpha: cross > 0 ? 0.94 : 0.65,
            );

            canvas.drawPath(triPath, fillPaint);
            if (step > 1 || t % 2 == 0) {
              edgePaint.color = accentColor.withValues(alpha: 0.30);
              canvas.drawPath(triPath, edgePaint);
            }
          }
        }
      } else {
        // Fallback vertex cluster / wireframe point mesh
        final Paint ptPaint = Paint()
          ..strokeWidth = 1.8
          ..color = accentColor.withValues(alpha: 0.85);

        for (int i = 0; i < vertexCount; i += 2) {
          canvas.drawCircle(projected[i], 1.2, ptPaint);
        }
      }
    }
  }

  void _drawFallbackAtmosphere(Canvas canvas, double cx, double cy) {
    // Elegant Gothic Arch Silhouette with glowing arcane runic runes
    final Paint archPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = accentColor.withValues(alpha: 0.85);

    final Path arch = Path();
    arch.moveTo(cx - 50, cy + 60);
    arch.lineTo(cx - 50, cy - 20);
    arch.quadraticBezierTo(cx - 50, cy - 70, cx, cy - 90);
    arch.quadraticBezierTo(cx + 50, cy - 70, cx + 50, cy - 20);
    arch.lineTo(cx + 50, cy + 60);

    canvas.drawPath(arch, archPaint);

    final Paint glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        Offset(cx, cy - 30),
        60,
        <Color>[
          accentColor.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(Offset(cx, cy - 30), 60, glowPaint);
  }

  void _drawFramingReticles(Canvas canvas, Size size) {
    final Paint reticlePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double arm = 14.0;
    const double inset = 6.0;

    // Top-Left
    canvas.drawLine(const Offset(inset, inset + arm), const Offset(inset, inset), reticlePaint);
    canvas.drawLine(const Offset(inset, inset), const Offset(inset + arm, inset), reticlePaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - inset - arm, inset), Offset(size.width - inset, inset), reticlePaint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + arm), reticlePaint);

    // Bottom-Left
    canvas.drawLine(Offset(inset, size.height - inset - arm), Offset(inset, size.height - inset), reticlePaint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + arm, size.height - inset), reticlePaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - inset - arm, size.height - inset), Offset(size.width - inset, size.height - inset), reticlePaint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - arm), reticlePaint);
  }

  void _drawVignette(Canvas canvas, Size size) {
    final Paint vignettePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.72,
        <Color>[
          Colors.transparent,
          Colors.black.withValues(alpha: 0.55),
        ],
        <double>[0.6, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _Mekan3DScenePainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.animValue != animValue ||
        oldDelegate.mesh != mesh ||
        oldDelegate.descriptor != descriptor ||
        oldDelegate.isLoading != isLoading ||
        oldDelegate.shadingMode != shadingMode;
  }
}
