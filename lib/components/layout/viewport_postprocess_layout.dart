import 'package:flutter/widgets.dart';

import 'mobile_ssao_layer.dart';
import 'mobile_ssr_reflection_layer.dart';

// =============================================================================
// Unified Mobile Viewport Post-Processing Layout Architecture
// Combines Screen-Space Ambient Occlusion (SSAO) and Screen-Space Reflections (SSR)
// 2027 Aion 2 Mobile Standard — Tile-Based Deferred Rendering (TBDR) Optimized
// =============================================================================

/// Global performance tier mapping both SSAO and SSR to device capabilities.
enum MobilePostProcessTier {
  /// Disabled: Zero post-processing passes.
  off,

  /// Eco profile: Low-spec Android (3-4GB RAM).
  /// Single-pass contact shadow, planar SSR reflection, 60+ FPS guarantee.
  eco,

  /// Balanced profile: Standard mobile (6-8GB RAM).
  /// 8-tap SSAO + 8-step SSR, bilateral smoothing, Gerstner wave ripples.
  balanced,

  /// High profile: Performance phones (8-12GB RAM).
  /// 16-tap SSAO + 16-step SSR, crevice contact deepening, Voronoi droplets.
  high,

  /// Ultra profile: Flagship mobile (Aion 2 AAA Cinematic).
  /// 24-tap Vogel SSAO + 24-step raymarching SSR with binary refinement.
  ultra;

  /// Corresponding SSAO quality level.
  MobileSsaoQuality get ssaoQuality {
    switch (this) {
      case MobilePostProcessTier.off:
        return MobileSsaoQuality.off;
      case MobilePostProcessTier.eco:
        return MobileSsaoQuality.eco;
      case MobilePostProcessTier.balanced:
        return MobileSsaoQuality.medium;
      case MobilePostProcessTier.high:
        return MobileSsaoQuality.high;
      case MobilePostProcessTier.ultra:
        return MobileSsaoQuality.ultra;
    }
  }

  /// Corresponding SSR quality level.
  MobileSsrQuality get ssrQuality {
    switch (this) {
      case MobilePostProcessTier.off:
        return MobileSsrQuality.off;
      case MobilePostProcessTier.eco:
        return MobileSsrQuality.eco;
      case MobilePostProcessTier.balanced:
        return MobileSsrQuality.medium;
      case MobilePostProcessTier.high:
        return MobileSsrQuality.high;
      case MobilePostProcessTier.ultra:
        return MobileSsrQuality.ultra;
    }
  }

  /// Combined GPU frame time budget in milliseconds.
  double get totalFrameBudgetMs => ssaoQuality.frameBudgetMs + ssrQuality.frameBudgetMs;
}

/// Unified configuration for both SSAO contact shadows and SSR puddle reflections.
class ViewportPostProcessConfig {
  const ViewportPostProcessConfig({
    this.tier = MobilePostProcessTier.balanced,
    this.enableSsao = true,
    this.enableSsr = true,
    this.ssaoConfig = const MobileSsaoConfig(),
    this.ssrConfig = const MobileSsrConfig(),
  });

  /// Active global performance tier.
  final MobilePostProcessTier tier;

  /// Master switch for SSAO contact shadow layer.
  final bool enableSsao;

  /// Master switch for SSR puddle reflection layer.
  final bool enableSsr;

  /// Fine-grained SSAO parameters.
  final MobileSsaoConfig ssaoConfig;

  /// Fine-grained SSR parameters.
  final MobileSsrConfig ssrConfig;

  /// Preset: Balanced mobile standard (60 FPS default).
  factory ViewportPostProcessConfig.balanced() {
    return ViewportPostProcessConfig(
      tier: MobilePostProcessTier.balanced,
      enableSsao: true,
      enableSsr: true,
      ssaoConfig: MobileSsaoConfig.mobileBalanced(),
      ssrConfig: MobileSsrConfig.calmWaterPuddles(),
    );
  }

  /// Preset: Eco tier for budget Android hardware (3-4GB RAM).
  factory ViewportPostProcessConfig.eco() {
    return ViewportPostProcessConfig(
      tier: MobilePostProcessTier.eco,
      enableSsao: true,
      enableSsr: true,
      ssaoConfig: MobileSsaoConfig.ecoLowSpec(),
      ssrConfig: MobileSsrConfig.ecoLowSpec(),
    );
  }

  /// Preset: AAA Aion 2 flagship cinematic night atmosphere.
  factory ViewportPostProcessConfig.aion2CinematicNight() {
    return ViewportPostProcessConfig(
      tier: MobilePostProcessTier.ultra,
      enableSsao: true,
      enableSsr: true,
      ssaoConfig: MobileSsaoConfig.aion2Cinematic(),
      ssrConfig: MobileSsrConfig.aion2CinematicNight(),
    );
  }

  /// Preset: Dungeon and fortress interiors with deep crevices and damp stone.
  factory ViewportPostProcessConfig.dungeonInterior() {
    return ViewportPostProcessConfig(
      tier: MobilePostProcessTier.high,
      enableSsao: true,
      enableSsr: true,
      ssaoConfig: MobileSsaoConfig.dungeonCrevices(),
      ssrConfig: const MobileSsrConfig(
        quality: MobileSsrQuality.high,
        wetness: 0.70,
        rainIntensity: 0.0,
        puddleRoughness: 0.06,
        reflectivity: 0.95,
        puddlePlaneY: 0.64,
      ),
    );
  }

  /// Preset: Completely disabled post-processing.
  factory ViewportPostProcessConfig.off() {
    return const ViewportPostProcessConfig(
      tier: MobilePostProcessTier.off,
      enableSsao: false,
      enableSsr: false,
      ssaoConfig: MobileSsaoConfig(quality: MobileSsaoQuality.off, intensity: 0.0),
      ssrConfig: MobileSsrConfig(quality: MobileSsrQuality.off, wetness: 0.0),
    );
  }

  ViewportPostProcessConfig copyWith({
    MobilePostProcessTier? tier,
    bool? enableSsao,
    bool? enableSsr,
    MobileSsaoConfig? ssaoConfig,
    MobileSsrConfig? ssrConfig,
  }) {
    return ViewportPostProcessConfig(
      tier: tier ?? this.tier,
      enableSsao: enableSsao ?? this.enableSsao,
      enableSsr: enableSsr ?? this.enableSsr,
      ssaoConfig: ssaoConfig ?? this.ssaoConfig,
      ssrConfig: ssrConfig ?? this.ssrConfig,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewportPostProcessConfig &&
          tier == other.tier &&
          enableSsao == other.enableSsao &&
          enableSsr == other.enableSsr &&
          ssaoConfig == other.ssaoConfig &&
          ssrConfig == other.ssrConfig;

  @override
  int get hashCode => Object.hash(
        tier,
        enableSsao,
        enableSsr,
        ssaoConfig,
        ssrConfig,
      );
}

// -----------------------------------------------------------------------------
// Unified Controller
// -----------------------------------------------------------------------------

/// Controller managing both SSAO and SSR configurations and quality tiers synchronously.
class ViewportPostProcessController extends ChangeNotifier {
  ViewportPostProcessController({
    ViewportPostProcessConfig config = const ViewportPostProcessConfig(),
  })  : _config = config,
        _ssaoController = MobileSsaoController(
          config: config.ssaoConfig.copyWith(
            quality: config.enableSsao ? config.tier.ssaoQuality : MobileSsaoQuality.off,
          ),
        ),
        _ssrController = MobileSsrController(
          config: config.ssrConfig.copyWith(
            quality: config.enableSsr ? config.tier.ssrQuality : MobileSsrQuality.off,
          ),
        );

  ViewportPostProcessConfig _config;
  final MobileSsaoController _ssaoController;
  final MobileSsrController _ssrController;
  bool _disposed = false;

  /// Current visual configuration.
  ViewportPostProcessConfig get config => _config;

  /// Internal SSAO controller.
  MobileSsaoController get ssaoController => _ssaoController;

  /// Internal SSR controller.
  MobileSsrController get ssrController => _ssrController;

  /// Current global performance tier.
  MobilePostProcessTier get tier => _config.tier;

  /// Updates global performance tier across all passes.
  void setTier(MobilePostProcessTier newTier) {
    if (_disposed || _config.tier == newTier) return;
    _config = _config.copyWith(tier: newTier);

    _ssaoController.setQuality(
      _config.enableSsao ? newTier.ssaoQuality : MobileSsaoQuality.off,
    );
    _ssrController.setQuality(
      _config.enableSsr ? newTier.ssrQuality : MobileSsrQuality.off,
    );
    notifyListeners();
  }

  /// Toggles SSAO layer on or off.
  void setEnableSsao(bool enabled) {
    if (_disposed || _config.enableSsao == enabled) return;
    _config = _config.copyWith(enableSsao: enabled);
    _ssaoController.setQuality(
      enabled ? _config.tier.ssaoQuality : MobileSsaoQuality.off,
    );
    notifyListeners();
  }

  /// Toggles SSR layer on or off.
  void setEnableSsr(bool enabled) {
    if (_disposed || _config.enableSsr == enabled) return;
    _config = _config.copyWith(enableSsr: enabled);
    _ssrController.setQuality(
      enabled ? _config.tier.ssrQuality : MobileSsrQuality.off,
    );
    notifyListeners();
  }

  /// Modulates weather rain intensity across SSR and SSAO.
  void setRainIntensity(double intensity) {
    if (_disposed) return;
    _ssrController.setRainIntensity(intensity);
    notifyListeners();
  }

  /// Modulates terrain ground wetness [0.0 - 1.0].
  void setWetness(double wetness) {
    if (_disposed) return;
    _ssrController.setWetness(wetness);
    notifyListeners();
  }

  /// Updates terrain/water plane Y level.
  void setGroundPlaneY(double planeY) {
    if (_disposed) return;
    _ssaoController.setGroundContactHeight(planeY);
    _ssrController.setPuddlePlaneY(planeY);
    notifyListeners();
  }

  /// Updates full configuration.
  void updateConfig(ViewportPostProcessConfig newConfig) {
    if (_disposed || _config == newConfig) return;
    _config = newConfig;
    _ssaoController.updateConfig(
      newConfig.ssaoConfig.copyWith(
        quality: newConfig.enableSsao ? newConfig.tier.ssaoQuality : MobileSsaoQuality.off,
      ),
    );
    _ssrController.updateConfig(
      newConfig.ssrConfig.copyWith(
        quality: newConfig.enableSsr ? newConfig.tier.ssrQuality : MobileSsrQuality.off,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ssaoController.dispose();
    _ssrController.dispose();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// Modular Unified Viewport Post-Process Layout Widget
// -----------------------------------------------------------------------------

/// Modular widget wrapper providing both Screen-Space Ambient Occlusion (SSAO)
/// and Screen-Space Reflections (SSR) puddle reflections over any screen viewport.
///
/// Designed for 2027 AAA mobile rendering with zero dropped frames via
/// adaptive quality tiers ([MobilePostProcessTier.eco] to [MobilePostProcessTier.ultra]).
class ViewportPostProcessLayout extends StatefulWidget {
  const ViewportPostProcessLayout({
    super.key,
    required this.child,
    this.controller,
    this.config = const ViewportPostProcessConfig(),
    this.customContactPath,
    this.customPuddlePath,
    this.autoAnimate = true,
  });

  /// The underlying viewport content (3D model, map canvas, hub world).
  final Widget child;

  /// Optional external controller. If omitted, an internal controller is managed.
  final ViewportPostProcessController? controller;

  /// Initial configuration used when [controller] is omitted.
  final ViewportPostProcessConfig config;

  /// Optional custom path for contact shadow footings.
  final Path? customContactPath;

  /// Optional custom path for puddle basins.
  final Path? customPuddlePath;

  /// Whether wave ripples animate automatically.
  final bool autoAnimate;

  @override
  State<ViewportPostProcessLayout> createState() => _ViewportPostProcessLayoutState();
}

class _ViewportPostProcessLayoutState extends State<ViewportPostProcessLayout> {
  late ViewportPostProcessController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = ViewportPostProcessController(config: widget.config);
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(covariant ViewportPostProcessLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && widget.controller != _controller) {
      if (_ownsController) {
        _controller.dispose();
        _ownsController = false;
      }
      _controller = widget.controller!;
    } else if (widget.controller == null && _ownsController) {
      if (widget.config != oldWidget.config) {
        _controller.updateConfig(widget.config);
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Zero-overhead fast path: if tier is off or both passes disabled, pass child directly
    if (_controller.tier == MobilePostProcessTier.off ||
        (!_controller.config.enableSsao && !_controller.config.enableSsr)) {
      return widget.child;
    }

    Widget content = widget.child;

    // 1. Wet ground & puddle SSR reflections (placed on ground terrain)
    if (_controller.config.enableSsr) {
      content = MobileSsrViewport(
        controller: _controller.ssrController,
        customPuddlePath: widget.customPuddlePath,
        autoAnimate: widget.autoAnimate,
        child: content,
      );
    }

    // 2. SSAO Contact shadows & crevice deepening (placed on top of terrain/footings)
    if (_controller.config.enableSsao) {
      content = MobileSsaoViewport(
        controller: _controller.ssaoController,
        customContactPath: widget.customContactPath,
        child: content,
      );
    }

    return content;
  }
}
