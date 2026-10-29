import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/engine/adaptive_quality_scaler.dart';

/// User-selectable graphics quality tiers for 2027 Aion-2 mobile engine.
enum GraphicsQualityTier {
  /// Battery-saver mode: 30 FPS cap, 0.50x resolution scale, fog off, shadows off.
  eco,

  /// Low-spec tier: 30 FPS cap, 0.75x resolution scale, low fog, minimal particles.
  low,

  /// Balanced tier: 60 FPS target, 1.00x resolution scale, medium fog & shadows.
  med,

  /// High-fidelity tier: 60 FPS target, 1.00x resolution scale, high fog, SSAO, bloom.
  high,

  /// 2027 AAA flagship standard: 120 FPS target, full volumetric god-rays, 4K shadow maps.
  ultra,

  /// Custom fine-tuned manual settings.
  custom;

  String get displayName => switch (this) {
        GraphicsQualityTier.eco => 'Eco',
        GraphicsQualityTier.low => 'Low',
        GraphicsQualityTier.med => 'Med',
        GraphicsQualityTier.high => 'High',
        GraphicsQualityTier.ultra => 'Ultra',
        GraphicsQualityTier.custom => 'Custom',
      };

  String get badgeDescription => switch (this) {
        GraphicsQualityTier.eco => 'Pil Tasarrufu Â· 30 FPS Â· Min IsÄ±nma',
        GraphicsQualityTier.low => 'DÃ¼ÅŸÃ¼k DonanÄ±m Â· 30 FPS AkÄ±cÄ±',
        GraphicsQualityTier.med => 'Dengeli Standart Â· 60 FPS',
        GraphicsQualityTier.high => 'YÃ¼ksek Kalite Â· 60 FPS Â· SSAO',
        GraphicsQualityTier.ultra => 'Aion-2 AAA Sinematik Â· 120 FPS',
        GraphicsQualityTier.custom => 'Ã–zel KullanÄ±cÄ± YapÄ±landÄ±rmasÄ±',
      };

  HardwareTier toHardwareTier() => switch (this) {
        GraphicsQualityTier.eco => HardwareTier.eco,
        GraphicsQualityTier.low => HardwareTier.low,
        GraphicsQualityTier.med => HardwareTier.mid,
        GraphicsQualityTier.high => HardwareTier.high,
        GraphicsQualityTier.ultra => HardwareTier.ultra,
        GraphicsQualityTier.custom => HardwareTier.mid,
      };

  static GraphicsQualityTier fromHardwareTier(HardwareTier tier) => switch (tier) {
        HardwareTier.eco => GraphicsQualityTier.eco,
        HardwareTier.low => GraphicsQualityTier.low,
        HardwareTier.mid => GraphicsQualityTier.med,
        HardwareTier.high => GraphicsQualityTier.high,
        HardwareTier.ultra => GraphicsQualityTier.ultra,
      };
}

/// Comprehensive, immutable snapshot of graphics configuration.
@immutable
class GraphicsConfigData {
  final GraphicsQualityTier tier;
  final double targetFps;
  final double resolutionScale;
  final bool shadowsEnabled;
  final int shadowResolution;
  final bool volumetricFogEnabled;
  final int volumetricFogSteps;
  final bool postProcessingEnabled;
  final bool ssaoEnabled;
  final bool bloomEnabled;
  final bool autoScalerEnabled;
  final int estimatedRamMb;
  final int estimatedVramMb;
  final DeviceHardwareProfile hardwareProfile;
  final QualitySettings qualitySettings;

  const GraphicsConfigData({
    required this.tier,
    required this.targetFps,
    required this.resolutionScale,
    required this.shadowsEnabled,
    required this.shadowResolution,
    required this.volumetricFogEnabled,
    required this.volumetricFogSteps,
    required this.postProcessingEnabled,
    required this.ssaoEnabled,
    required this.bloomEnabled,
    required this.autoScalerEnabled,
    required this.estimatedRamMb,
    required this.estimatedVramMb,
    required this.hardwareProfile,
    required this.qualitySettings,
  });

  /// Factory preset constructor for each tier.
  factory GraphicsConfigData.presetForTier(
    GraphicsQualityTier tier, {
    DeviceHardwareProfile? profile,
  }) {
    final devProfile = profile ?? DeviceHardwareProfile.midSpecSnapdragon720();
    switch (tier) {
      case GraphicsQualityTier.eco:
        const quality = QualitySettings(
          tier: HardwareTier.eco,
          throttleLevel: 0,
          renderResolutionScale: 0.50,
          volumetricFogStepCount: 0,
          ssaoEnabled: false,
          ssaoBlurEnabled: false,
          maxActiveParticles: 200,
          shadowResolution: 0,
          shadowCascadeCount: 0,
          lodDistanceMultiplier: 0.4,
          bloomEnabled: false,
          crowdDensityCap: 300,
          targetFps: 30.0,
        );
        return GraphicsConfigData(
          tier: GraphicsQualityTier.eco,
          targetFps: 30.0,
          resolutionScale: 0.50,
          shadowsEnabled: false,
          shadowResolution: 0,
          volumetricFogEnabled: false,
          volumetricFogSteps: 0,
          postProcessingEnabled: false,
          ssaoEnabled: false,
          bloomEnabled: false,
          autoScalerEnabled: true,
          estimatedRamMb: 340,
          estimatedVramMb: 140,
          hardwareProfile: devProfile,
          qualitySettings: quality,
        );

      case GraphicsQualityTier.low:
        final quality = QualitySettings.forTier(HardwareTier.low).copyWith(
          renderResolutionScale: 0.75,
          volumetricFogStepCount: 4,
          shadowResolution: 0,
          targetFps: 30.0,
        );
        return GraphicsConfigData(
          tier: GraphicsQualityTier.low,
          targetFps: 30.0,
          resolutionScale: 0.75,
          shadowsEnabled: false,
          shadowResolution: 0,
          volumetricFogEnabled: true,
          volumetricFogSteps: 4,
          postProcessingEnabled: false,
          ssaoEnabled: false,
          bloomEnabled: false,
          autoScalerEnabled: true,
          estimatedRamMb: 520,
          estimatedVramMb: 240,
          hardwareProfile: devProfile,
          qualitySettings: quality,
        );

      case GraphicsQualityTier.med:
        final quality = QualitySettings.forTier(HardwareTier.mid);
        return GraphicsConfigData(
          tier: GraphicsQualityTier.med,
          targetFps: 60.0,
          resolutionScale: 1.0,
          shadowsEnabled: true,
          shadowResolution: 512,
          volumetricFogEnabled: true,
          volumetricFogSteps: 16,
          postProcessingEnabled: true,
          ssaoEnabled: true,
          bloomEnabled: true,
          autoScalerEnabled: true,
          estimatedRamMb: 880,
          estimatedVramMb: 480,
          hardwareProfile: devProfile,
          qualitySettings: quality,
        );

      case GraphicsQualityTier.high:
        final quality = QualitySettings.forTier(HardwareTier.high);
        return GraphicsConfigData(
          tier: GraphicsQualityTier.high,
          targetFps: 60.0,
          resolutionScale: 1.0,
          shadowsEnabled: true,
          shadowResolution: 1024,
          volumetricFogEnabled: true,
          volumetricFogSteps: 32,
          postProcessingEnabled: true,
          ssaoEnabled: true,
          bloomEnabled: true,
          autoScalerEnabled: true,
          estimatedRamMb: 1480,
          estimatedVramMb: 840,
          hardwareProfile: devProfile,
          qualitySettings: quality,
        );

      case GraphicsQualityTier.ultra:
        final quality = QualitySettings.forTier(HardwareTier.ultra).copyWith(
          targetFps: 120.0,
        );
        return GraphicsConfigData(
          tier: GraphicsQualityTier.ultra,
          targetFps: 120.0,
          resolutionScale: 1.0,
          shadowsEnabled: true,
          shadowResolution: 2048,
          volumetricFogEnabled: true,
          volumetricFogSteps: 64,
          postProcessingEnabled: true,
          ssaoEnabled: true,
          bloomEnabled: true,
          autoScalerEnabled: true,
          estimatedRamMb: 2650,
          estimatedVramMb: 1620,
          hardwareProfile: devProfile,
          qualitySettings: quality,
        );

      case GraphicsQualityTier.custom:
        return GraphicsConfigData.presetForTier(GraphicsQualityTier.med, profile: profile).copyWith(
          tier: GraphicsQualityTier.custom,
        );
    }
  }

  GraphicsConfigData copyWith({
    GraphicsQualityTier? tier,
    double? targetFps,
    double? resolutionScale,
    bool? shadowsEnabled,
    int? shadowResolution,
    bool? volumetricFogEnabled,
    int? volumetricFogSteps,
    bool? postProcessingEnabled,
    bool? ssaoEnabled,
    bool? bloomEnabled,
    bool? autoScalerEnabled,
    int? estimatedRamMb,
    int? estimatedVramMb,
    DeviceHardwareProfile? hardwareProfile,
    QualitySettings? qualitySettings,
  }) {
    return GraphicsConfigData(
      tier: tier ?? this.tier,
      targetFps: targetFps ?? this.targetFps,
      resolutionScale: resolutionScale ?? this.resolutionScale,
      shadowsEnabled: shadowsEnabled ?? this.shadowsEnabled,
      shadowResolution: shadowResolution ?? this.shadowResolution,
      volumetricFogEnabled: volumetricFogEnabled ?? this.volumetricFogEnabled,
      volumetricFogSteps: volumetricFogSteps ?? this.volumetricFogSteps,
      postProcessingEnabled: postProcessingEnabled ?? this.postProcessingEnabled,
      ssaoEnabled: ssaoEnabled ?? this.ssaoEnabled,
      bloomEnabled: bloomEnabled ?? this.bloomEnabled,
      autoScalerEnabled: autoScalerEnabled ?? this.autoScalerEnabled,
      estimatedRamMb: estimatedRamMb ?? this.estimatedRamMb,
      estimatedVramMb: estimatedVramMb ?? this.estimatedVramMb,
      hardwareProfile: hardwareProfile ?? this.hardwareProfile,
      qualitySettings: qualitySettings ?? this.qualitySettings,
    );
  }

  static (int ramMb, int vramMb) computeEstimatedFootprint({
    required double resolutionScale,
    required int shadowResolution,
    required int fogSteps,
    required bool ssaoEnabled,
    required bool bloomEnabled,
    required int maxParticles,
    required int crowdCap,
  }) {
    double baseRam = 250.0;
    double baseVram = 90.0;

    final double resMultiplier = math.pow(resolutionScale, 2.0).toDouble();
    final double hdrColorBuffersVram = 32.0 * resMultiplier;
    final double depthStencilVram = 16.0 * resMultiplier;

    double postVram = 0.0;
    if (ssaoEnabled) postVram += 24.0 * resMultiplier;
    if (bloomEnabled) postVram += 18.0 * resMultiplier;

    double shadowVram = 0.0;
    if (shadowResolution > 0) {
      shadowVram = (math.pow(shadowResolution, 2.0) * 4.0 / (1024.0 * 1024.0)) * 2.5;
    }

    double fogVram = (fogSteps * 128 * 64 * 4.0) / (1024.0 * 1024.0);
    double particleVram = (maxParticles * 64.0) / (1024.0 * 1024.0);
    double crowdRam = (crowdCap * 180.0) / 1024.0;
    double crowdVram = (crowdCap * 90.0) / 1024.0;

    final int finalRam = (baseRam + (crowdRam * 1.5) + (maxParticles * 0.08) + (fogSteps * 2.5)).round();
    final int finalVram = (baseVram + hdrColorBuffersVram + depthStencilVram + postVram + shadowVram + fogVram + particleVram + crowdVram).round();

    return (finalRam, finalVram);
  }
}

/// Service managing graphics configuration and direct integration with [AdaptiveQualityScaler].
class GraphicsSettingsService extends ChangeNotifier {
  static const String keyTier = 'graphics_tier';
  static const String keyFps = 'graphics_target_fps';
  static const String keyResolutionScale = 'graphics_res_scale';
  static const String keyShadows = 'graphics_shadows';
  static const String keyShadowRes = 'graphics_shadow_res';
  static const String keyFog = 'graphics_volumetric_fog';
  static const String keyFogSteps = 'graphics_fog_steps';
  static const String keyPostProcessing = 'graphics_post_processing';
  static const String keySsao = 'graphics_ssao';
  static const String keyBloom = 'graphics_bloom';
  static const String keyAutoScaler = 'graphics_auto_scaler';

  static GraphicsSettingsService? _instance;
  static GraphicsSettingsService get instance => _instance ??= GraphicsSettingsService._internal();

  final AdaptiveQualityScaler scaler;
  late GraphicsConfigData _config;
  bool _isLoaded = false;
  StreamSubscription<QualitySettings>? _scalerSubscription;

  GraphicsSettingsService._internal({AdaptiveQualityScaler? scalerOverride})
      : scaler = scalerOverride ?? AdaptiveQualityScaler() {
    _config = GraphicsConfigData.presetForTier(
      GraphicsQualityTier.fromHardwareTier(scaler.currentTier),
      profile: scaler.hardwareProfile,
    );
    _listenToScaler();
  }

  factory GraphicsSettingsService.createForTesting({AdaptiveQualityScaler? scaler}) {
    return GraphicsSettingsService._internal(scalerOverride: scaler);
  }

  bool get isLoaded => _isLoaded;
  GraphicsConfigData get config => _config;

  void _listenToScaler() {
    _scalerSubscription = scaler.onSettingsChanged.listen((newSettings) {
      final (ram, vram) = GraphicsConfigData.computeEstimatedFootprint(
        resolutionScale: newSettings.renderResolutionScale,
        shadowResolution: newSettings.shadowResolution,
        fogSteps: newSettings.volumetricFogStepCount,
        ssaoEnabled: newSettings.ssaoEnabled,
        bloomEnabled: newSettings.bloomEnabled,
        maxParticles: newSettings.maxActiveParticles,
        crowdCap: newSettings.crowdDensityCap,
      );

      _config = _config.copyWith(
        resolutionScale: newSettings.renderResolutionScale,
        volumetricFogSteps: newSettings.volumetricFogStepCount,
        shadowResolution: newSettings.shadowResolution,
        ssaoEnabled: newSettings.ssaoEnabled,
        bloomEnabled: newSettings.bloomEnabled,
        estimatedRamMb: ram,
        estimatedVramMb: vram,
        qualitySettings: newSettings,
      );
      notifyListeners();
    });
  }

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? tierName = prefs.getString(keyTier);
    final double? fps = prefs.getDouble(keyFps);
    final double? resScale = prefs.getDouble(keyResolutionScale);
    final bool? shadows = prefs.getBool(keyShadows);
    final int? shadowRes = prefs.getInt(keyShadowRes);
    final bool? fog = prefs.getBool(keyFog);
    final int? fogSteps = prefs.getInt(keyFogSteps);
    final bool? post = prefs.getBool(keyPostProcessing);
    final bool? ssao = prefs.getBool(keySsao);
    final bool? bloom = prefs.getBool(keyBloom);
    final bool? autoScaler = prefs.getBool(keyAutoScaler);

    GraphicsQualityTier selectedTier = GraphicsQualityTier.med;
    if (tierName != null) {
      selectedTier = GraphicsQualityTier.values.firstWhere(
        (t) => t.name == tierName,
        orElse: () => GraphicsQualityTier.med,
      );
    } else {
      selectedTier = GraphicsQualityTier.fromHardwareTier(scaler.hardwareProfile.autoDetectTier());
    }

    final preset = GraphicsConfigData.presetForTier(
      selectedTier,
      profile: scaler.hardwareProfile,
    );

    final double effectiveFps = fps ?? preset.targetFps;
    final double effectiveRes = resScale ?? preset.resolutionScale;
    final bool effectiveShadows = shadows ?? preset.shadowsEnabled;
    final int effectiveShadowRes = shadowRes ?? preset.shadowResolution;
    final bool effectiveFog = fog ?? preset.volumetricFogEnabled;
    final int effectiveFogSteps = fogSteps ?? preset.volumetricFogSteps;
    final bool effectivePost = post ?? preset.postProcessingEnabled;
    final bool effectiveSsao = ssao ?? preset.ssaoEnabled;
    final bool effectiveBloom = bloom ?? preset.bloomEnabled;
    final bool effectiveAutoScaler = autoScaler ?? preset.autoScalerEnabled;

    final (ram, vram) = GraphicsConfigData.computeEstimatedFootprint(
      resolutionScale: effectiveRes,
      shadowResolution: effectiveShadows ? effectiveShadowRes : 0,
      fogSteps: effectiveFog ? effectiveFogSteps : 0,
      ssaoEnabled: effectivePost && effectiveSsao,
      bloomEnabled: effectivePost && effectiveBloom,
      maxParticles: preset.qualitySettings.maxActiveParticles,
      crowdCap: preset.qualitySettings.crowdDensityCap,
    );

    final quality = preset.qualitySettings.copyWith(
      targetFps: effectiveFps,
      renderResolutionScale: effectiveRes,
      shadowResolution: effectiveShadows ? effectiveShadowRes : 0,
      volumetricFogStepCount: effectiveFog ? effectiveFogSteps : 0,
      ssaoEnabled: effectivePost && effectiveSsao,
      bloomEnabled: effectivePost && effectiveBloom,
    );

    _config = GraphicsConfigData(
      tier: selectedTier,
      targetFps: effectiveFps,
      resolutionScale: effectiveRes,
      shadowsEnabled: effectiveShadows,
      shadowResolution: effectiveShadowRes,
      volumetricFogEnabled: effectiveFog,
      volumetricFogSteps: effectiveFogSteps,
      postProcessingEnabled: effectivePost,
      ssaoEnabled: effectiveSsao,
      bloomEnabled: effectiveBloom,
      autoScalerEnabled: effectiveAutoScaler,
      estimatedRamMb: ram,
      estimatedVramMb: vram,
      hardwareProfile: scaler.hardwareProfile,
      qualitySettings: quality,
    );

    scaler.setHardwareTier(selectedTier.toHardwareTier());
    scaler.setRenderResolutionScale(effectiveRes);
    scaler.setAutoScaling(effectiveAutoScaler);

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setTier(GraphicsQualityTier tier) async {
    final preset = GraphicsConfigData.presetForTier(
      tier,
      profile: scaler.hardwareProfile,
    );

    _config = preset;
    scaler.setHardwareTier(tier.toHardwareTier());
    scaler.setRenderResolutionScale(preset.resolutionScale);
    scaler.setAutoScaling(preset.autoScalerEnabled);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTier, tier.name);
    await prefs.setDouble(keyFps, preset.targetFps);
    await prefs.setDouble(keyResolutionScale, preset.resolutionScale);
    await prefs.setBool(keyShadows, preset.shadowsEnabled);
    await prefs.setInt(keyShadowRes, preset.shadowResolution);
    await prefs.setBool(keyFog, preset.volumetricFogEnabled);
    await prefs.setInt(keyFogSteps, preset.volumetricFogSteps);
    await prefs.setBool(keyPostProcessing, preset.postProcessingEnabled);
    await prefs.setBool(keySsao, preset.ssaoEnabled);
    await prefs.setBool(keyBloom, preset.bloomEnabled);
    await prefs.setBool(keyAutoScaler, preset.autoScalerEnabled);

    notifyListeners();
  }

  Future<void> setTargetFps(double fps) async {
    final updatedQuality = _config.qualitySettings.copyWith(targetFps: fps);
    _config = _config.copyWith(
      targetFps: fps,
      tier: _inferTierIfMatching(fps: fps),
      qualitySettings: updatedQuality,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyFps, fps);
    await prefs.setString(keyTier, _config.tier.name);
    notifyListeners();
  }

  Future<void> setResolutionScale(double scale) async {
    final clamped = scale.clamp(AdaptiveQualityScaler.minResolutionScale, AdaptiveQualityScaler.maxResolutionScale);
    scaler.setRenderResolutionScale(clamped);

    final (ram, vram) = GraphicsConfigData.computeEstimatedFootprint(
      resolutionScale: clamped,
      shadowResolution: _config.shadowsEnabled ? _config.shadowResolution : 0,
      fogSteps: _config.volumetricFogEnabled ? _config.volumetricFogSteps : 0,
      ssaoEnabled: _config.postProcessingEnabled && _config.ssaoEnabled,
      bloomEnabled: _config.postProcessingEnabled && _config.bloomEnabled,
      maxParticles: _config.qualitySettings.maxActiveParticles,
      crowdCap: _config.qualitySettings.crowdDensityCap,
    );

    final updatedQuality = _config.qualitySettings.copyWith(renderResolutionScale: clamped);
    _config = _config.copyWith(
      resolutionScale: clamped,
      tier: _inferTierIfMatching(resolutionScale: clamped),
      estimatedRamMb: ram,
      estimatedVramMb: vram,
      qualitySettings: updatedQuality,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyResolutionScale, clamped);
    await prefs.setString(keyTier, _config.tier.name);
    notifyListeners();
  }

  Future<void> setShadowsEnabled(bool enabled) async {
    final int res = enabled ? (_config.shadowResolution > 0 ? _config.shadowResolution : 512) : 0;
    final (ram, vram) = GraphicsConfigData.computeEstimatedFootprint(
      resolutionScale: _config.resolutionScale,
      shadowResolution: res,
      fogSteps: _config.volumetricFogEnabled ? _config.volumetricFogSteps : 0,
      ssaoEnabled: _config.postProcessingEnabled && _config.ssaoEnabled,
      bloomEnabled: _config.postProcessingEnabled && _config.bloomEnabled,
      maxParticles: _config.qualitySettings.maxActiveParticles,
      crowdCap: _config.qualitySettings.crowdDensityCap,
    );

    final updatedQuality = _config.qualitySettings.copyWith(shadowResolution: res);
    _config = _config.copyWith(
      shadowsEnabled: enabled,
      shadowResolution: res > 0 ? res : _config.shadowResolution,
      tier: _inferTierIfMatching(shadows: enabled),
      estimatedRamMb: ram,
      estimatedVramMb: vram,
      qualitySettings: updatedQuality,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyShadows, enabled);
    await prefs.setString(keyTier, _config.tier.name);
    notifyListeners();
  }

  Future<void> setVolumetricFogEnabled(bool enabled) async {
    final int steps = enabled ? (_config.volumetricFogSteps > 0 ? _config.volumetricFogSteps : 16) : 0;
    final (ram, vram) = GraphicsConfigData.computeEstimatedFootprint(
      resolutionScale: _config.resolutionScale,
      shadowResolution: _config.shadowsEnabled ? _config.shadowResolution : 0,
      fogSteps: steps,
      ssaoEnabled: _config.postProcessingEnabled && _config.ssaoEnabled,
      bloomEnabled: _config.postProcessingEnabled && _config.bloomEnabled,
      maxParticles: _config.qualitySettings.maxActiveParticles,
      crowdCap: _config.qualitySettings.crowdDensityCap,
    );

    final updatedQuality = _config.qualitySettings.copyWith(volumetricFogStepCount: steps);
    _config = _config.copyWith(
      volumetricFogEnabled: enabled,
      volumetricFogSteps: steps > 0 ? steps : _config.volumetricFogSteps,
      tier: _inferTierIfMatching(fog: enabled),
      estimatedRamMb: ram,
      estimatedVramMb: vram,
      qualitySettings: updatedQuality,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFog, enabled);
    await prefs.setString(keyTier, _config.tier.name);
    notifyListeners();
  }

  Future<void> setPostProcessingEnabled(bool enabled) async {
    final bool effectiveSsao = enabled && _config.ssaoEnabled;
    final bool effectiveBloom = enabled && _config.bloomEnabled;

    final (ram, vram) = GraphicsConfigData.computeEstimatedFootprint(
      resolutionScale: _config.resolutionScale,
      shadowResolution: _config.shadowsEnabled ? _config.shadowResolution : 0,
      fogSteps: _config.volumetricFogEnabled ? _config.volumetricFogSteps : 0,
      ssaoEnabled: effectiveSsao,
      bloomEnabled: effectiveBloom,
      maxParticles: _config.qualitySettings.maxActiveParticles,
      crowdCap: _config.qualitySettings.crowdDensityCap,
    );

    final updatedQuality = _config.qualitySettings.copyWith(
      ssaoEnabled: effectiveSsao,
      bloomEnabled: effectiveBloom,
    );
    _config = _config.copyWith(
      postProcessingEnabled: enabled,
      tier: _inferTierIfMatching(post: enabled),
      estimatedRamMb: ram,
      estimatedVramMb: vram,
      qualitySettings: updatedQuality,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPostProcessing, enabled);
    await prefs.setString(keyTier, _config.tier.name);
    notifyListeners();
  }

  Future<void> setSsaoEnabled(bool enabled) async {
    final bool effectiveSsao = _config.postProcessingEnabled && enabled;
    final (ram, vram) = GraphicsConfigData.computeEstimatedFootprint(
      resolutionScale: _config.resolutionScale,
      shadowResolution: _config.shadowsEnabled ? _config.shadowResolution : 0,
      fogSteps: _config.volumetricFogEnabled ? _config.volumetricFogSteps : 0,
      ssaoEnabled: effectiveSsao,
      bloomEnabled: _config.postProcessingEnabled && _config.bloomEnabled,
      maxParticles: _config.qualitySettings.maxActiveParticles,
      crowdCap: _config.qualitySettings.crowdDensityCap,
    );

    final updatedQuality = _config.qualitySettings.copyWith(ssaoEnabled: effectiveSsao);
    _config = _config.copyWith(
      ssaoEnabled: enabled,
      tier: GraphicsQualityTier.custom,
      estimatedRamMb: ram,
      estimatedVramMb: vram,
      qualitySettings: updatedQuality,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySsao, enabled);
    await prefs.setString(keyTier, _config.tier.name);
    notifyListeners();
  }

  Future<void> setBloomEnabled(bool enabled) async {
    final bool effectiveBloom = _config.postProcessingEnabled && enabled;
    final (ram, vram) = GraphicsConfigData.computeEstimatedFootprint(
      resolutionScale: _config.resolutionScale,
      shadowResolution: _config.shadowsEnabled ? _config.shadowResolution : 0,
      fogSteps: _config.volumetricFogEnabled ? _config.volumetricFogSteps : 0,
      ssaoEnabled: _config.postProcessingEnabled && _config.ssaoEnabled,
      bloomEnabled: effectiveBloom,
      maxParticles: _config.qualitySettings.maxActiveParticles,
      crowdCap: _config.qualitySettings.crowdDensityCap,
    );

    final updatedQuality = _config.qualitySettings.copyWith(bloomEnabled: effectiveBloom);
    _config = _config.copyWith(
      bloomEnabled: enabled,
      tier: GraphicsQualityTier.custom,
      estimatedRamMb: ram,
      estimatedVramMb: vram,
      qualitySettings: updatedQuality,
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyBloom, enabled);
    await prefs.setString(keyTier, _config.tier.name);
    notifyListeners();
  }

  Future<void> setAutoScalerEnabled(bool enabled) async {
    scaler.setAutoScaling(enabled);
    _config = _config.copyWith(autoScalerEnabled: enabled);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAutoScaler, enabled);
    notifyListeners();
  }

  Future<void> resetToRecommended() async {
    final autoTier = GraphicsQualityTier.fromHardwareTier(scaler.hardwareProfile.autoDetectTier());
    await setTier(autoTier);
  }

  GraphicsQualityTier _inferTierIfMatching({
    double? fps,
    double? resolutionScale,
    bool? shadows,
    bool? fog,
    bool? post,
  }) {
    return GraphicsQualityTier.custom;
  }

  @override
  void dispose() {
    _scalerSubscription?.cancel();
    super.dispose();
  }
}

