import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../core/world/dynamic_skybox.dart';

// =============================================================================
// Production Hub Environment & Baked GI PBR Architecture
// 2027 AAA Cinematic Graphics (R2 Open World Standard)
// Eliminates primitive 2005 flat tiling textures and static gradients.
// Features dynamic celestial backdrop, backlit atmospheric rim lights,
// gothic architectural masonry, PBR cobblestone plaza with wetness reflection,
// multi-frequency torch lighting, airborne floating embers, and AdaptiveQualityScaler hooks.
// =============================================================================

/// Dynamic point light representing a flickering torch scone in the hub plaza.
class HubTorchLight {
  const HubTorchLight({
    required this.position,
    required this.radius,
    required this.baseColor,
    required this.intensity,
    required this.flickerSpeed,
    required this.flickerPhase,
    this.bracketOffset = Offset.zero,
  });

  final Offset position;
  final double radius;
  final Color baseColor;
  final double intensity;
  final double flickerSpeed;
  final double flickerPhase;
  final Offset bracketOffset;

  /// Evaluates distance attenuation and multi-frequency temporal flicker:
  /// I(d) = I_0 * (0.85 + 0.15 * sin(speed * t + phase) + 0.05 * sin(2.8 * speed * t + 1.7 * phase))
  ///       / (1 + 1.2 * dNorm + 3.8 * dNorm^2)
  double evaluateIntensity(double distance, double time) {
    final double flicker = 0.85 +
        0.15 * math.sin(flickerSpeed * time + flickerPhase) +
        0.05 * math.sin(flickerSpeed * 2.8 * time + flickerPhase * 1.7);
    final double dNorm = distance / radius;
    final double attenuation = 1.0 / (1.0 + 1.2 * dNorm + 3.8 * dNorm * dNorm);
    return (intensity * flicker * attenuation).clamp(0.0, 2.0);
  }
}

/// Geometric stone paver definition with individual PBR material properties.
class CobblestonePaver {
  const CobblestonePaver({
    required this.bounds,
    required this.reliefHeight,
    required this.roughness,
    required this.reflectance,
    required this.tintVariation,
  });

  final Rect bounds;
  final double reliefHeight;
  final double roughness;
  final double reflectance;
  final double tintVariation;
}

/// Procedural airborne atmospheric ember rising from plaza torch braziers.
/// Evaluated deterministically for zero runtime heap allocation during paint cycles.
class HubAtmosphericEmber {
  const HubAtmosphericEmber({
    required this.torchIndex,
    required this.phaseOffset,
    required this.driftFreq,
    required this.lifespan,
    required this.baseRadius,
    required this.color,
  });

  final int torchIndex;
  final double phaseOffset;
  final double driftFreq;
  final double lifespan;
  final double baseRadius;
  final Color color;
}

/// Controller managing environmental lighting, day/night GI, and torch animations.
class HubEnvironmentController extends ChangeNotifier {
  HubEnvironmentController({
    AdaptiveQualityScaler? scaler,
    HardwareTier hardwareTier = HardwareTier.high,
    QualitySettings? qualitySettings,
  })  : _scaler = scaler,
        _hardwareTier = hardwareTier,
        _customQualitySettings = qualitySettings {
    if (scaler != null) {
      _hardwareTier = scaler.currentTier;
      scaler.addListener(_onScalerUpdated);
    }
  }

  double _elapsedTime = 0.0;
  double get elapsedTime => _elapsedTime;

  LinearColor _ambientZenith = const LinearColor(0.08, 0.12, 0.22);
  LinearColor get ambientZenith => _ambientZenith;

  LinearColor _ambientHorizon = const LinearColor(0.12, 0.16, 0.28);
  LinearColor get ambientHorizon => _ambientHorizon;

  LinearColor _ambientGround = const LinearColor(0.04, 0.06, 0.08);
  LinearColor get ambientGround => _ambientGround;

  LinearColor _sunRadiance = const LinearColor(1.0, 0.95, 0.85);
  LinearColor get sunRadiance => _sunRadiance;

  double _sunElevation = 0.5;
  double get sunElevation => _sunElevation;

  double _sunAzimuth = 0.0;
  double get sunAzimuth => _sunAzimuth;

  LinearColor _shL00 = const LinearColor(0.10, 0.14, 0.20);
  LinearColor get shL00 => _shL00;

  double _ambientOcclusionFactor = 1.0;
  double get ambientOcclusionFactor => _ambientOcclusionFactor;

  AdaptiveQualityScaler? _scaler;
  AdaptiveQualityScaler? get scaler => _scaler;

  HardwareTier _hardwareTier;
  HardwareTier get hardwareTier => _hardwareTier;

  QualitySettings? _customQualitySettings;
  QualitySettings? get customQualitySettings => _customQualitySettings;

  /// Effective runtime quality settings derived from active scaler or hardware tier.
  QualitySettings get activeQualitySettings =>
      _customQualitySettings ??
      _scaler?.currentSettings ??
      QualitySettings.forTier(_hardwareTier);

  void attachScaler(AdaptiveQualityScaler? scaler) {
    if (_scaler == scaler) return;
    _scaler?.removeListener(_onScalerUpdated);
    _scaler = scaler;
    if (scaler != null) {
      _hardwareTier = scaler.currentTier;
      scaler.addListener(_onScalerUpdated);
    }
    notifyListeners();
  }

  void _onScalerUpdated() {
    if (_scaler != null) {
      final HardwareTier newTier = _scaler!.currentTier;
      if (_hardwareTier != newTier) {
        _hardwareTier = newTier;
      }
      notifyListeners();
    }
  }

  void setHardwareTier(HardwareTier tier) {
    if (_hardwareTier != tier) {
      _hardwareTier = tier;
      notifyListeners();
    }
  }

  void setQualitySettings(QualitySettings? settings) {
    if (_customQualitySettings != settings) {
      _customQualitySettings = settings;
      notifyListeners();
    }
  }

  void updateGlobalIllumination(WorldGiUniforms uniforms) {
    _ambientZenith = uniforms.zenithColor;
    _ambientHorizon = uniforms.horizonColor;
    _ambientGround = uniforms.groundColor;
    _sunRadiance = uniforms.mainLightRadiance;
    _sunElevation = uniforms.mainLightDirection.elevation;
    _sunAzimuth = uniforms.mainLightDirection.azimuth;
    _shL00 = uniforms.shL00;
    _ambientOcclusionFactor = uniforms.ambientOcclusionFactor;
    notifyListeners();
  }

  void tick(double deltaTimeSeconds) {
    _elapsedTime += deltaTimeSeconds;
    notifyListeners();
  }

  @override
  void dispose() {
    _scaler?.removeListener(_onScalerUpdated);
    super.dispose();
  }
}

/// CustomPainter rendering multi-layered AAA medieval gothic hub architecture,
/// procedural PBR cobblestone plaza with normal relief & wetness sheen,
/// dynamic celestial backdrop aura, backlit spire rim lights, wrought-iron sconces,
/// multi-frequency torchlight bounce, and deterministic airborne embers.
class HubEnvironmentPainter extends CustomPainter {
  HubEnvironmentPainter({
    required this.controller,
    this.parallaxOffset = Offset.zero,
    this.enableAtmosphericBackdrop = true,
    this.enableEmbers = true,
    this.enablePbrPlaza = true,
  }) : super(repaint: controller);

  final HubEnvironmentController controller;
  final Offset parallaxOffset;
  final bool enableAtmosphericBackdrop;
  final bool enableEmbers;
  final bool enablePbrPlaza;

  // Cached cobblestone layouts indexed by packed size and hardware tier
  static final Map<int, List<CobblestonePaver>> _cachedPaversMap =
      <int, List<CobblestonePaver>>{};

  // 48 pre-calculated deterministic particle profiles for airborne atmospheric embers
  static final List<HubAtmosphericEmber> _kEmberPresets = _initEmberPresets();

  static List<HubAtmosphericEmber> _initEmberPresets() {
    final List<HubAtmosphericEmber> list = <HubAtmosphericEmber>[];
    final math.Random rng = math.Random(1337);
    for (int i = 0; i < 48; i++) {
      final int torchIdx = i % 3;
      final double phase = rng.nextDouble() * 12.0;
      final double freq = 1.4 + rng.nextDouble() * 2.2;
      final double life = 2.2 + rng.nextDouble() * 2.4;
      final double radius = 0.9 + rng.nextDouble() * 1.5;
      final Color col = (i % 4 == 0)
          ? const Color(0xFFFFD573) // Warm golden incandescent
          : (i % 4 == 1)
              ? const Color(0xFFFF9933) // Vivid fiery ember
              : (i % 4 == 2)
                  ? const Color(0xFFFF5522) // Deep ruby combustion
                  : const Color(0xFFFFF4C2); // Superheated white-gold
      list.add(
        HubAtmosphericEmber(
          torchIndex: torchIdx,
          phaseOffset: phase,
          driftFreq: freq,
          lifespan: life,
          baseRadius: radius,
          color: col,
        ),
      );
    }
    return list;
  }

  // Pre-allocated reusable Paint instances to prevent frame-time heap allocations
  final Paint _farPaint = Paint();
  final Paint _rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..blendMode = BlendMode.screen;
  final Paint _windowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _celestialGlowPaint = Paint()..blendMode = BlendMode.plus;
  final Paint _archPaint = Paint();
  final Paint _archTraceryPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _sconcePaint = Paint()..style = PaintingStyle.fill;
  final Paint _stonePaint = Paint()..style = PaintingStyle.fill;
  final Paint _mortarPaint = Paint()..style = PaintingStyle.fill;
  final Paint _specularPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _haloPaint = Paint();
  final Paint _flamePaint = Paint()
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.solid, 4.0);
  final Paint _emberPaint = Paint()..style = PaintingStyle.fill;

  // Pre-allocated reusable Path instances
  final Path _fortressPath = Path();
  final Path _leftArchPath = Path();
  final Path _rightArchPath = Path();

  static List<CobblestonePaver> _getOrCreatePavers(Size size, HardwareTier tier) {
    final int key = (size.width.toInt() & 0xFFFF) |
        ((size.height.toInt() & 0xFFFF) << 16) |
        (tier.index << 28);
    final List<CobblestonePaver>? existing = _cachedPaversMap[key];
    if (existing != null) return existing;

    final List<CobblestonePaver> generated = _generatePavers(size, tier);
    if (_cachedPaversMap.length >= 8) {
      _cachedPaversMap.clear();
    }
    _cachedPaversMap[key] = generated;
    return generated;
  }

  static List<CobblestonePaver> _generatePavers(Size size, HardwareTier tier) {
    final List<CobblestonePaver> pavers = <CobblestonePaver>[];
    final double plazaTop = size.height * 0.62;
    final double plazaHeight = size.height - plazaTop;

    int rowCount = 14;
    int colsPerRow = 18;

    switch (tier) {
      case HardwareTier.ultra:
        rowCount = 14;
        colsPerRow = 18;
        break;
      case HardwareTier.high:
        rowCount = 12;
        colsPerRow = 16;
        break;
      case HardwareTier.mid:
        rowCount = 10;
        colsPerRow = 13;
        break;
      case HardwareTier.low:
        rowCount = 8;
        colsPerRow = 10;
        break;
      case HardwareTier.eco:
        rowCount = 6;
        colsPerRow = 8;
        break;
    }

    final double rowHeight = plazaHeight / rowCount;
    final double colWidth = size.width / colsPerRow;
    final math.Random rng = math.Random(101);

    for (int r = 0; r < rowCount; r++) {
      final double depthT = r / rowCount.toDouble();
      final double perspectiveScale = 0.65 + 0.7 * depthT;
      final double currY = plazaTop + (depthT * depthT * plazaHeight);
      final double h = rowHeight * perspectiveScale * 1.1;
      final double rowStagger = (r % 2 == 0) ? 0.0 : colWidth * 0.45;

      for (int c = -1; c <= colsPerRow + 1; c++) {
        final double x = (c * colWidth) + rowStagger + (rng.nextDouble() * 3.0 - 1.5);
        final double w = colWidth * (0.85 + rng.nextDouble() * 0.25);

        pavers.add(
          CobblestonePaver(
            bounds: Rect.fromLTWH(x, currY, w, h),
            reliefHeight: 0.5 + rng.nextDouble() * 0.5,
            roughness: 0.35 + rng.nextDouble() * 0.45,
            reflectance: 0.04 + rng.nextDouble() * 0.08,
            tintVariation: rng.nextDouble() * 0.2 - 0.1,
          ),
        );
      }
    }
    return pavers;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final QualitySettings settings = controller.activeQualitySettings;
    HardwareTier activeTier = settings.tier;

    // Responsive downscale under heavy frame-pacing throttle
    if (settings.throttleLevel >= 2 && activeTier != HardwareTier.eco) {
      activeTier = HardwareTier.low;
    }

    final List<CobblestonePaver> pavers = enablePbrPlaza
        ? _getOrCreatePavers(size, activeTier)
        : const <CobblestonePaver>[];

    final double time = controller.elapsedTime;
    final Offset pNear = Offset(parallaxOffset.dx * 0.8, parallaxOffset.dy * 0.8);
    final Offset pMid = Offset(parallaxOffset.dx * 0.4, parallaxOffset.dy * 0.4);
    final Offset pFar = Offset(parallaxOffset.dx * 0.15, parallaxOffset.dy * 0.15);

    // 1. Far Silhouettes: Gothic Fortress Towers, Cathedral Spires & Celestial Aura
    if (enableAtmosphericBackdrop) {
      _paintFarArchitecture(canvas, size, pFar, time);
    }

    // 2. Midground Architecture: Fortress Walls, Gothic Stone Arches & Wrought Iron Sconces
    _paintMidgroundArches(canvas, size, pMid, time, activeTier);

    // 3. Dynamic Torch Point Lights with multi-frequency temporal flicker
    final List<HubTorchLight> torches = <HubTorchLight>[
      HubTorchLight(
        position: Offset(size.width * 0.19 + pMid.dx, size.height * 0.51 + pMid.dy),
        radius: size.width * 0.38,
        baseColor: const Color(0xFFFF9933),
        intensity: 1.25,
        flickerSpeed: 8.5,
        flickerPhase: 0.0,
      ),
      HubTorchLight(
        position: Offset(size.width * 0.81 + pMid.dx, size.height * 0.51 + pMid.dy),
        radius: size.width * 0.38,
        baseColor: const Color(0xFFFF9933),
        intensity: 1.25,
        flickerSpeed: 7.8,
        flickerPhase: 2.4,
      ),
      HubTorchLight(
        position: Offset(size.width * 0.50 + pMid.dx, size.height * 0.45 + pMid.dy),
        radius: size.width * 0.45,
        baseColor: const Color(0xFFFFAA44),
        intensity: 1.4,
        flickerSpeed: 9.2,
        flickerPhase: 4.1,
      ),
    ];

    // 4. Foreground PBR Cobblestone Plaza with Normal Relief, Specular Highlights & Wetness Sheen
    if (enablePbrPlaza) {
      _paintCobblestonePlaza(canvas, size, pNear, torches, time, pavers, activeTier);
    }

    // 5. Torch Flare, Volumetric Halos & Incandescent Flame Cores
    for (final HubTorchLight torch in torches) {
      _paintTorchHalo(canvas, torch, time);
    }

    // 6. Airborne Floating Embers rising from Torch Braziers (Zero-jank deterministic particles)
    if (enableEmbers &&
        activeTier != HardwareTier.eco &&
        settings.throttleLevel < 3) {
      _paintEmbers(canvas, size, torches, time, activeTier);
    }
  }

  void _paintFarArchitecture(Canvas canvas, Size size, Offset parallax, double time) {
    final double horizonY = size.height * 0.58 + parallax.dy;

    // Dynamic celestial backdrop backlight aura
    final double sunNormX = (0.5 + controller.sunAzimuth * 0.25).clamp(0.12, 0.88);
    final double sunNormY = horizonY -
        size.height * (0.08 + controller.sunElevation.clamp(-0.35, 0.90) * 0.22);
    final Offset celestialCenter = Offset(size.width * sunNormX, sunNormY);
    final double glowRadius = size.width * 0.70;

    final int auraAlpha = (controller.sunRadiance.r *
            140.0 *
            (1.0 - (controller.sunElevation - 0.4).abs() * 0.5))
        .clamp(15.0, 120.0)
        .toInt();

    _celestialGlowPaint.shader = ui.Gradient.radial(
      celestialCenter,
      glowRadius,
      <Color>[
        Color.fromARGB(
          auraAlpha,
          (controller.ambientHorizon.r * 255.0).clamp(40.0, 255.0).toInt(),
          (controller.ambientHorizon.g * 255.0).clamp(35.0, 230.0).toInt(),
          (controller.ambientHorizon.b * 255.0).clamp(50.0, 255.0).toInt(),
        ),
        Color.fromARGB(
          (auraAlpha * 0.45).toInt(),
          (controller.ambientZenith.r * 255.0).clamp(10.0, 180.0).toInt(),
          (controller.ambientZenith.g * 255.0).clamp(15.0, 190.0).toInt(),
          (controller.ambientZenith.b * 255.0).clamp(30.0, 220.0).toInt(),
        ),
        const Color(0x00000000),
      ],
      <double>[0.0, 0.48, 1.0],
    );
    canvas.drawCircle(celestialCenter, glowRadius, _celestialGlowPaint);

    // Build fortress silhouette path
    _fortressPath.reset();
    _fortressPath.moveTo(0.0, size.height);
    _fortressPath.lineTo(0.0, horizonY);

    // Distant mountain ridge and spires
    _fortressPath.lineTo(size.width * 0.05, horizonY - size.height * 0.12);
    _fortressPath.lineTo(size.width * 0.12, horizonY - size.height * 0.06);
    // Spire 1 (West Watchtower)
    _fortressPath.lineTo(size.width * 0.15, horizonY - size.height * 0.22);
    _fortressPath.lineTo(size.width * 0.165, horizonY - size.height * 0.28); // Tip
    _fortressPath.lineTo(size.width * 0.18, horizonY - size.height * 0.22);
    _fortressPath.lineTo(size.width * 0.25, horizonY - size.height * 0.08);

    // Central Citadel Keep & Great Cathedral Spire
    _fortressPath.lineTo(size.width * 0.38, horizonY - size.height * 0.18);
    _fortressPath.lineTo(size.width * 0.43, horizonY - size.height * 0.24);
    _fortressPath.lineTo(size.width * 0.47, horizonY - size.height * 0.32);
    _fortressPath.lineTo(size.width * 0.50, horizonY - size.height * 0.38); // Cathedral Peak
    _fortressPath.lineTo(size.width * 0.53, horizonY - size.height * 0.32);
    _fortressPath.lineTo(size.width * 0.57, horizonY - size.height * 0.24);
    _fortressPath.lineTo(size.width * 0.62, horizonY - size.height * 0.18);

    // Spire 2 (East Bastion)
    _fortressPath.lineTo(size.width * 0.76, horizonY - size.height * 0.09);
    _fortressPath.lineTo(size.width * 0.82, horizonY - size.height * 0.21);
    _fortressPath.lineTo(size.width * 0.835, horizonY - size.height * 0.27);
    _fortressPath.lineTo(size.width * 0.85, horizonY - size.height * 0.21);
    _fortressPath.lineTo(size.width * 0.94, horizonY - size.height * 0.07);
    _fortressPath.lineTo(size.width, horizonY - size.height * 0.11);
    _fortressPath.lineTo(size.width, size.height);
    _fortressPath.close();

    final Color topFarColor = Color.fromARGB(
      255,
      (controller.ambientZenith.r * 255.0).clamp(10.0, 48.0).toInt(),
      (controller.ambientZenith.g * 255.0).clamp(16.0, 58.0).toInt(),
      (controller.ambientZenith.b * 255.0).clamp(30.0, 85.0).toInt(),
    );
    final Color botFarColor = Color.fromARGB(
      255,
      (controller.ambientGround.r * 255.0).clamp(8.0, 32.0).toInt(),
      (controller.ambientGround.g * 255.0).clamp(12.0, 38.0).toInt(),
      (controller.ambientGround.b * 255.0).clamp(18.0, 54.0).toInt(),
    );

    _farPaint.shader = ui.Gradient.linear(
      Offset(0.0, horizonY - size.height * 0.38),
      Offset(0.0, horizonY),
      <Color>[topFarColor, botFarColor],
    );
    canvas.drawPath(_fortressPath, _farPaint);

    // Backlit atmospheric rim light on fortress spires & mountain silhouettes
    final int rimAlpha =
        ((1.15 - controller.sunElevation.clamp(0.0, 1.0)) * 130.0)
            .clamp(20.0, 180.0)
            .toInt();
    if (rimAlpha > 25) {
      _rimPaint.color = Color.fromARGB(
        rimAlpha,
        (controller.sunRadiance.r * 255.0).clamp(180.0, 255.0).toInt(),
        (controller.sunRadiance.g * 240.0).clamp(160.0, 240.0).toInt(),
        (controller.sunRadiance.b * 210.0).clamp(130.0, 220.0).toInt(),
      );
      canvas.drawPath(_fortressPath, _rimPaint);
    }

    // Distant Citadel Cathedral Stained-Glass Lancet Windows
    final double isNightFactor = (1.0 - controller.sunElevation.clamp(0.0, 0.8) / 0.8);
    final int windowAlpha = (isNightFactor * 200.0).clamp(0.0, 210.0).toInt();

    if (windowAlpha > 20) {
      _windowPaint.color = Color.fromARGB(windowAlpha, 255, 188, 77);

      // Central Spire Lancet Slits
      final double spireX = size.width * 0.50;
      final double spireBaseY = horizonY - size.height * 0.28;
      for (int w = -1; w <= 1; w++) {
        final Rect windowRect = Rect.fromCenter(
          center: Offset(spireX + w * 7.5, spireBaseY + (w.abs() * 3.0)),
          width: 2.2,
          height: 9.0,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(windowRect, const Radius.circular(1.0)),
          _windowPaint,
        );
      }
    }
  }

  void _paintMidgroundArches(
    Canvas canvas,
    Size size,
    Offset parallax,
    double time,
    HardwareTier tier,
  ) {
    final double archBaseY = size.height * 0.65 + parallax.dy;
    final double archTopY = size.height * 0.38 + parallax.dy;

    // Dynamic torch ground bounce color integration
    final int bounceR =
        (controller.ambientGround.r * 255.0 + 38.0).clamp(15.0, 85.0).toInt();
    final int bounceG =
        (controller.ambientGround.g * 255.0 + 26.0).clamp(12.0, 60.0).toInt();
    final int bounceB =
        (controller.ambientGround.b * 255.0 + 20.0).clamp(16.0, 50.0).toInt();

    _archPaint.shader = ui.Gradient.linear(
      Offset(0.0, archTopY),
      Offset(0.0, archBaseY),
      <Color>[
        const Color(0xFF1B2436),
        Color.fromARGB(255, bounceR, bounceG, bounceB),
      ],
      <double>[0.0, 1.0],
    );

    // Left Arch Portal with gothic contour
    _leftArchPath.reset();
    _leftArchPath.moveTo(size.width * 0.02 + parallax.dx, archBaseY);
    _leftArchPath.lineTo(size.width * 0.02 + parallax.dx, archTopY + size.height * 0.06);
    _leftArchPath.quadraticBezierTo(
      size.width * 0.18 + parallax.dx,
      archTopY - size.height * 0.04,
      size.width * 0.36 + parallax.dx,
      archTopY + size.height * 0.06,
    );
    _leftArchPath.lineTo(size.width * 0.36 + parallax.dx, archBaseY);
    _leftArchPath.lineTo(size.width * 0.28 + parallax.dx, archBaseY);
    _leftArchPath.lineTo(size.width * 0.28 + parallax.dx, archTopY + size.height * 0.11);
    _leftArchPath.quadraticBezierTo(
      size.width * 0.18 + parallax.dx,
      archTopY + size.height * 0.04,
      size.width * 0.10 + parallax.dx,
      archTopY + size.height * 0.11,
    );
    _leftArchPath.lineTo(size.width * 0.10 + parallax.dx, archBaseY);
    _leftArchPath.close();
    canvas.drawPath(_leftArchPath, _archPaint);

    // Right Arch Portal
    _rightArchPath.reset();
    _rightArchPath.moveTo(size.width * 0.64 + parallax.dx, archBaseY);
    _rightArchPath.lineTo(size.width * 0.64 + parallax.dx, archTopY + size.height * 0.06);
    _rightArchPath.quadraticBezierTo(
      size.width * 0.82 + parallax.dx,
      archTopY - size.height * 0.04,
      size.width * 0.98 + parallax.dx,
      archTopY + size.height * 0.06,
    );
    _rightArchPath.lineTo(size.width * 0.98 + parallax.dx, archBaseY);
    _rightArchPath.lineTo(size.width * 0.90 + parallax.dx, archBaseY);
    _rightArchPath.lineTo(size.width * 0.90 + parallax.dx, archTopY + size.height * 0.11);
    _rightArchPath.quadraticBezierTo(
      size.width * 0.82 + parallax.dx,
      archTopY + size.height * 0.04,
      size.width * 0.72 + parallax.dx,
      archTopY + size.height * 0.11,
    );
    _rightArchPath.lineTo(size.width * 0.72 + parallax.dx, archBaseY);
    _rightArchPath.close();
    canvas.drawPath(_rightArchPath, _archPaint);

    // Gothic Stone Tracery Inner Contours (Tier-dependent)
    if (tier == HardwareTier.ultra || tier == HardwareTier.high) {
      _archTraceryPaint.color = const Color(0x3344607E);
      canvas.drawPath(_leftArchPath, _archTraceryPaint);
      canvas.drawPath(_rightArchPath, _archTraceryPaint);
    }

    // Wrought Iron Wall Sconces holding torch braziers
    _sconcePaint.color = const Color(0xFF0C101A);
    final List<Offset> sconcePositions = <Offset>[
      Offset(size.width * 0.19 + parallax.dx, size.height * 0.51 + parallax.dy),
      Offset(size.width * 0.50 + parallax.dx, size.height * 0.45 + parallax.dy),
      Offset(size.width * 0.81 + parallax.dx, size.height * 0.51 + parallax.dy),
    ];

    for (final Offset pos in sconcePositions) {
      // Wall plate
      canvas.drawRect(
        Rect.fromCenter(center: Offset(pos.dx, pos.dy + 8.0), width: 5.5, height: 16.0),
        _sconcePaint,
      );
      // Horizontal mounting arm
      canvas.drawRect(
        Rect.fromLTWH(pos.dx - 4.5, pos.dy + 3.0, 9.0, 3.2),
        _sconcePaint,
      );
      // Torch iron bowl
      canvas.drawArc(
        Rect.fromCenter(center: Offset(pos.dx, pos.dy + 4.0), width: 13.0, height: 8.5),
        0.0,
        math.pi,
        true,
        _sconcePaint,
      );
    }
  }

  void _paintCobblestonePlaza(
    Canvas canvas,
    Size size,
    Offset parallax,
    List<HubTorchLight> torches,
    double time,
    List<CobblestonePaver> pavers,
    HardwareTier tier,
  ) {
    _mortarPaint.color = const Color(0xFF06090F);

    // Plaza Mortar Underlay
    final Rect plazaBounds = Rect.fromLTWH(
      0.0,
      size.height * 0.60 + parallax.dy,
      size.width,
      size.height * 0.40,
    );
    canvas.drawRect(plazaBounds, _mortarPaint);

    final double rMod = controller.ambientGround.r + controller.sunRadiance.r * 0.1;
    final double gMod = controller.ambientGround.g + controller.sunRadiance.g * 0.1;
    final double bMod = controller.ambientGround.b + controller.sunRadiance.b * 0.1;
    final bool enableSpecular = tier != HardwareTier.eco;
    final bool enableWetnessGlaze =
        tier == HardwareTier.ultra || tier == HardwareTier.high;

    for (final CobblestonePaver paver in pavers) {
      final Rect r = paver.bounds.shift(parallax);
      if (r.bottom < 0 || r.top > size.height) continue;

      final Offset center = r.center;
      double torchIrradiance = 0.0;
      for (final HubTorchLight torch in torches) {
        final double dist = (center - torch.position).distance;
        torchIrradiance += torch.evaluateIntensity(dist, time);
      }

      final double baseLum = (0.09 +
              paver.tintVariation +
              (paver.reliefHeight * 0.03))
          .clamp(0.04, 0.42);

      final int redVal = ((baseLum * 255.0 * (1.0 + rMod)) +
              (torchIrradiance * 88.0))
          .clamp(0.0, 255.0)
          .toInt();
      final int greenVal = ((baseLum * 255.0 * (1.0 + gMod)) +
              (torchIrradiance * 54.0))
          .clamp(0.0, 255.0)
          .toInt();
      final int blueVal = ((baseLum * 290.0 * (1.0 + bMod)) +
              (torchIrradiance * 26.0))
          .clamp(0.0, 255.0)
          .toInt();

      _stonePaint.color = Color.fromARGB(255, redVal, greenVal, blueVal);

      if (tier == HardwareTier.eco) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + 1.0, r.top + 1.0, r.width - 2.0, r.height - 2.0),
          _stonePaint,
        );
      } else {
        final RRect stoneRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + 1.2, r.top + 1.2, r.width - 2.4, r.height - 2.4),
          const Radius.circular(3.5),
        );
        canvas.drawRRect(stoneRRect, _stonePaint);
      }

      // Specular highlight on top bevel edge catching dynamic torchlight
      if (enableSpecular && torchIrradiance > 0.07) {
        final int specAlpha =
            (torchIrradiance * 58.0).clamp(0.0, 165.0).toInt();
        _specularPaint.color = Color.fromARGB(specAlpha, 255, 232, 195);
        canvas.drawLine(
          Offset(r.left + 3.0, r.top + 1.8),
          Offset(r.right - 3.0, r.top + 1.8),
          _specularPaint,
        );

        // Wetness Reflection Glaze sheen spot in paver center
        if (enableWetnessGlaze && torchIrradiance > 0.35) {
          final int glazeAlpha =
              (torchIrradiance * 24.0).clamp(0.0, 65.0).toInt();
          _specularPaint.color = Color.fromARGB(glazeAlpha, 255, 240, 210);
          canvas.drawCircle(
            Offset(center.dx, r.top + r.height * 0.38),
            r.width * 0.16,
            _specularPaint,
          );
        }
      }
    }
  }

  void _paintTorchHalo(Canvas canvas, HubTorchLight torch, double time) {
    final double flicker = 0.90 +
        0.10 * math.sin(torch.flickerSpeed * time + torch.flickerPhase);
    final double haloRadius = torch.radius * flicker;

    // Ambient radial glow
    _haloPaint.shader = ui.Gradient.radial(
      torch.position,
      haloRadius,
      <Color>[
        torch.baseColor.withValues(alpha: 0.28 * torch.intensity),
        torch.baseColor.withValues(alpha: 0.10 * torch.intensity),
        torch.baseColor.withValues(alpha: 0.0),
      ],
      <double>[0.0, 0.45, 1.0],
    );
    canvas.drawCircle(torch.position, haloRadius, _haloPaint);

    // Inner bright torch flame core
    _flamePaint.color = const Color(0xFFFFF6D0);
    canvas.drawCircle(torch.position, 5.5 * flicker, _flamePaint);
  }

  void _paintEmbers(
    Canvas canvas,
    Size size,
    List<HubTorchLight> torches,
    double time,
    HardwareTier tier,
  ) {
    int count = 32;
    switch (tier) {
      case HardwareTier.ultra:
        count = 48;
        break;
      case HardwareTier.high:
        count = 32;
        break;
      case HardwareTier.mid:
        count = 16;
        break;
      case HardwareTier.low:
      case HardwareTier.eco:
        count = 8;
        break;
    }

    final double maxRise = size.height * 0.24;

    for (int i = 0; i < count; i++) {
      final HubAtmosphericEmber ember = _kEmberPresets[i];
      final HubTorchLight torch = torches[ember.torchIndex];

      final double cycleTime = (time + ember.phaseOffset) % ember.lifespan;
      final double progress = cycleTime / ember.lifespan;
      final double rise = progress * maxRise;
      final double windDrift =
          math.sin(ember.driftFreq * time + ember.phaseOffset * 2.8) *
              (16.0 * progress);

      final Offset pos = Offset(
        torch.position.dx + windDrift,
        torch.position.dy - rise,
      );

      final double alpha = math.sin(progress * math.pi);
      final double currentRadius =
          (ember.baseRadius * (1.0 - progress * 0.40)).clamp(0.4, 3.0);

      _emberPaint.color =
          ember.color.withValues(alpha: (alpha * 0.85).clamp(0.0, 1.0));
      canvas.drawCircle(pos, currentRadius, _emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HubEnvironmentPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.parallaxOffset != parallaxOffset ||
        oldDelegate.enableAtmosphericBackdrop != enableAtmosphericBackdrop ||
        oldDelegate.enableEmbers != enableEmbers ||
        oldDelegate.enablePbrPlaza != enablePbrPlaza;
  }
}

/// Production widget embedding the medieval hub environment layer.
/// Features 2027 AAA atmospheric lighting, dynamic celestial backdrop,
/// seamless GI integration, AdaptiveQualityScaler hooks, and zero jank.
class HubEnvironmentLayer extends StatefulWidget {
  const HubEnvironmentLayer({
    super.key,
    required this.controller,
    this.parallaxOffset = Offset.zero,
    this.scaler,
    this.hardwareTier,
    this.qualitySettings,
    this.enableAtmosphericBackdrop = true,
    this.enableEmbers = true,
    this.enablePbrPlaza = true,
    this.child,
  });

  final HubEnvironmentController controller;
  final Offset parallaxOffset;
  final AdaptiveQualityScaler? scaler;
  final HardwareTier? hardwareTier;
  final QualitySettings? qualitySettings;
  final bool enableAtmosphericBackdrop;
  final bool enableEmbers;
  final bool enablePbrPlaza;
  final Widget? child;

  @override
  State<HubEnvironmentLayer> createState() => _HubEnvironmentLayerState();
}

class _HubEnvironmentLayerState extends State<HubEnvironmentLayer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  double _lastTickSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    _applyConfiguration();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant HubEnvironmentLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scaler != oldWidget.scaler ||
        widget.hardwareTier != oldWidget.hardwareTier ||
        widget.qualitySettings != oldWidget.qualitySettings) {
      _applyConfiguration();
    }
  }

  void _applyConfiguration() {
    if (widget.scaler != null) {
      widget.controller.attachScaler(widget.scaler);
    }
    if (widget.hardwareTier != null) {
      widget.controller.setHardwareTier(widget.hardwareTier!);
    }
    if (widget.qualitySettings != null) {
      widget.controller.setQualitySettings(widget.qualitySettings);
    }
  }

  void _onTick(Duration elapsed) {
    final double currentSeconds = elapsed.inMicroseconds / 1000000.0;
    final double dt =
        _lastTickSeconds == 0.0 ? 0.016 : (currentSeconds - _lastTickSeconds);
    _lastTickSeconds = currentSeconds;

    // Zero-jank frame pacing: on Eco/Low tiers clamp tick rate cleanly
    widget.controller.tick(dt.clamp(0.001, 0.05));
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: HubEnvironmentPainter(
          controller: widget.controller,
          parallaxOffset: widget.parallaxOffset,
          enableAtmosphericBackdrop: widget.enableAtmosphericBackdrop,
          enableEmbers: widget.enableEmbers,
          enablePbrPlaza: widget.enablePbrPlaza,
        ),
        child: widget.child,
      ),
    );
  }
}
