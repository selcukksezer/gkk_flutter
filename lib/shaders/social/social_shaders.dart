library;

export 'theme/social_theme_tokens.dart';
export 'banner/celestial_banner_painter.dart';
export 'banner/celestial_banner_widget.dart';
export 'emblem/pulsing_emblem_painter.dart';
export 'emblem/pulsing_emblem_widget.dart';
export 'rewards/reward_types.dart';
export 'rewards/celestial_wings_painter.dart';
export 'rewards/daeva_chest_painter.dart';
export 'rewards/abyss_crystal_painter.dart';
export 'rewards/enchantment_stone_painter.dart';
export 'rewards/honor_insignia_painter.dart';
export 'rewards/social_reward_icon.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Asset paths for Aion 2 Mobile social runtime shaders.
abstract final class SocialShaderPaths {
  /// Canonical asset path for the Celestial Banner procedural energy shader.
  static const String celestialBanner = 'shaders/social/celestial_banner.frag';

  /// Alternative source asset path within lib/ for direct bundling.
  static const String celestialBannerAlt = 'lib/shaders/social/glsl/celestial_banner.frag';

  /// Canonical asset path for the Animated Emblem Aura & Radiance shader.
  static const String emblemAura = 'shaders/social/emblem_aura.frag';

  /// Alternative source asset path within lib/ for direct bundling.
  static const String emblemAuraAlt = 'lib/shaders/social/glsl/emblem_aura.frag';
}

/// Precise uniform indices and pack helper for `celestial_banner.frag`.
///
/// Declared GLSL layout:
/// - uniform vec2  uResolution;       (float indices 0, 1)
/// - uniform float uTime;             (float index 2)
/// - uniform float uProgress;         (float index 3)
/// - uniform float uEnergyIntensity;  (float index 4)
/// - uniform vec4  uPrimaryColor;     (float indices 5, 6, 7, 8)
/// - uniform vec4  uSecondaryColor;   (float indices 9, 10, 11, 12)
/// - uniform vec4  uGoldColor;        (float indices 13, 14, 15, 16)
/// Total float count: 17
abstract final class CelestialBannerUniforms {
  static const int indexResolution = 0;
  static const int indexTime = 2;
  static const int indexProgress = 3;
  static const int indexEnergyIntensity = 4;
  static const int indexPrimaryColor = 5;
  static const int indexSecondaryColor = 9;
  static const int indexGoldColor = 13;
  static const int floatCount = 17;

  /// Converts standard sRGB channel to linear RGB for photometrically accurate GLSL shading.
  static double sRgbToLinear(double c) {
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts a Flutter [Color] to a 4-float linear RGBA list.
  static List<double> colorToLinearFloats(Color color) {
    return <double>[
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
      color.a,
    ];
  }

  /// Packs uniform floats in the exact order expected by `celestial_banner.frag`.
  static List<double> buildUniforms({
    required Size size,
    required double time,
    required double progress,
    required double energyIntensity,
    required Color primaryColor,
    required Color secondaryColor,
    required Color goldColor,
    bool useLinearColors = true,
  }) {
    final List<double> primary = useLinearColors
        ? colorToLinearFloats(primaryColor)
        : <double>[primaryColor.r, primaryColor.g, primaryColor.b, primaryColor.a];
    final List<double> secondary = useLinearColors
        ? colorToLinearFloats(secondaryColor)
        : <double>[secondaryColor.r, secondaryColor.g, secondaryColor.b, secondaryColor.a];
    final List<double> gold = useLinearColors
        ? colorToLinearFloats(goldColor)
        : <double>[goldColor.r, goldColor.g, goldColor.b, goldColor.a];

    return <double>[
      size.width,          // 0: uResolution.x
      size.height,         // 1: uResolution.y
      time,                // 2: uTime
      progress,            // 3: uProgress
      energyIntensity,     // 4: uEnergyIntensity
      primary[0],          // 5: uPrimaryColor.r
      primary[1],          // 6: uPrimaryColor.g
      primary[2],          // 7: uPrimaryColor.b
      primary[3],          // 8: uPrimaryColor.a
      secondary[0],        // 9: uSecondaryColor.r
      secondary[1],        // 10: uSecondaryColor.g
      secondary[2],        // 11: uSecondaryColor.b
      secondary[3],        // 12: uSecondaryColor.a
      gold[0],             // 13: uGoldColor.r
      gold[1],             // 14: uGoldColor.g
      gold[2],             // 15: uGoldColor.b
      gold[3],             // 16: uGoldColor.a
    ];
  }

  /// Applies all uniforms to a [ui.FragmentShader] instance.
  static void apply(
    ui.FragmentShader shader, {
    required Size size,
    required double time,
    required double progress,
    required double energyIntensity,
    required Color primaryColor,
    required Color secondaryColor,
    required Color goldColor,
    bool useLinearColors = true,
  }) {
    final List<double> uniforms = buildUniforms(
      size: size,
      time: time,
      progress: progress,
      energyIntensity: energyIntensity,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      goldColor: goldColor,
      useLinearColors: useLinearColors,
    );
    for (int i = 0; i < uniforms.length; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
  }
}

/// Precise uniform indices and pack helper for `emblem_aura.frag`.
///
/// Declared GLSL layout:
/// - uniform vec2  uResolution;   (float indices 0, 1)
/// - uniform float uTime;         (float index 2)
/// - uniform float uProgress;     (float index 3)
/// - uniform vec4  uAuraColor;    (float indices 4, 5, 6, 7)
/// - uniform vec4  uCoreColor;    (float indices 8, 9, 10, 11)
/// - uniform float uPulseSpeed;   (float index 12)
/// - uniform float uAuraRadius;   (float index 13)
/// Total float count: 14
abstract final class EmblemAuraUniforms {
  static const int indexResolution = 0;
  static const int indexTime = 2;
  static const int indexProgress = 3;
  static const int indexAuraColor = 4;
  static const int indexCoreColor = 8;
  static const int indexPulseSpeed = 12;
  static const int indexAuraRadius = 13;
  static const int floatCount = 14;

  /// Converts standard sRGB channel to linear RGB for photometrically accurate GLSL shading.
  static double sRgbToLinear(double c) {
    return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts a Flutter [Color] to a 4-float linear RGBA list.
  static List<double> colorToLinearFloats(Color color) {
    return <double>[
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
      color.a,
    ];
  }

  /// Packs uniform floats in the exact order expected by `emblem_aura.frag`.
  static List<double> buildUniforms({
    required Size size,
    required double time,
    required double progress,
    required Color auraColor,
    required Color coreColor,
    required double pulseSpeed,
    required double auraRadius,
    bool useLinearColors = true,
  }) {
    final List<double> aura = useLinearColors
        ? colorToLinearFloats(auraColor)
        : <double>[auraColor.r, auraColor.g, auraColor.b, auraColor.a];
    final List<double> core = useLinearColors
        ? colorToLinearFloats(coreColor)
        : <double>[coreColor.r, coreColor.g, coreColor.b, coreColor.a];

    return <double>[
      size.width,       // 0: uResolution.x
      size.height,      // 1: uResolution.y
      time,             // 2: uTime
      progress,         // 3: uProgress
      aura[0],          // 4: uAuraColor.r
      aura[1],          // 5: uAuraColor.g
      aura[2],          // 6: uAuraColor.b
      aura[3],          // 7: uAuraColor.a
      core[0],          // 8: uCoreColor.r
      core[1],          // 9: uCoreColor.g
      core[2],          // 10: uCoreColor.b
      core[3],          // 11: uCoreColor.a
      pulseSpeed,       // 12: uPulseSpeed
      auraRadius,       // 13: uAuraRadius
    ];
  }

  /// Applies all uniforms to a [ui.FragmentShader] instance.
  static void apply(
    ui.FragmentShader shader, {
    required Size size,
    required double time,
    required double progress,
    required Color auraColor,
    required Color coreColor,
    required double pulseSpeed,
    required double auraRadius,
    bool useLinearColors = true,
  }) {
    final List<double> uniforms = buildUniforms(
      size: size,
      time: time,
      progress: progress,
      auraColor: auraColor,
      coreColor: coreColor,
      pulseSpeed: pulseSpeed,
      auraRadius: auraRadius,
      useLinearColors: useLinearColors,
    );
    for (int i = 0; i < uniforms.length; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
  }
}

/// Central caching and lifecycle manager for social fragment programs.
///
/// Guarantees seamless fallback to CPU custom painting in environments
/// lacking Impeller / RuntimeEffect GPU pipeline support (headless test runners,
/// legacy Skia fallback mode).
class SocialShaderCache {
  SocialShaderCache._internal();
  static final SocialShaderCache instance = SocialShaderCache._internal();
  factory SocialShaderCache() => instance;

  ui.FragmentProgram? _celestialBannerProgram;
  ui.FragmentProgram? _emblemAuraProgram;

  bool _initialized = false;
  bool _hasHardwareShaderSupport = true;
  Object? _lastError;

  bool get isInitialized => _initialized;
  bool get hasHardwareShaderSupport => _hasHardwareShaderSupport;
  Object? get lastError => _lastError;

  ui.FragmentProgram? get celestialBannerProgram => _celestialBannerProgram;
  ui.FragmentProgram? get emblemAuraProgram => _emblemAuraProgram;

  /// Loads and warms up all social runtime fragment programs.
  /// Gracefully catches errors if running in headless/CPU environments,
  /// preserving CPU custom painter fallback without throwing.
  Future<bool> init() async {
    if (_initialized && _hasHardwareShaderSupport) return true;

    bool bannerLoaded = false;
    bool auraLoaded = false;

    // Load celestial banner shader
    try {
      _celestialBannerProgram = await _loadProgramWithFallback(
        primaryPath: SocialShaderPaths.celestialBanner,
        fallbackPath: SocialShaderPaths.celestialBannerAlt,
      );
      bannerLoaded = _celestialBannerProgram != null;
    } catch (e) {
      _lastError = e;
      bannerLoaded = false;
    }

    // Load emblem aura shader
    try {
      _emblemAuraProgram = await _loadProgramWithFallback(
        primaryPath: SocialShaderPaths.emblemAura,
        fallbackPath: SocialShaderPaths.emblemAuraAlt,
      );
      auraLoaded = _emblemAuraProgram != null;
    } catch (e) {
      _lastError = e;
      auraLoaded = false;
    }

    _initialized = true;
    _hasHardwareShaderSupport = bannerLoaded || auraLoaded;
    return _hasHardwareShaderSupport;
  }

  Future<ui.FragmentProgram?> _loadProgramWithFallback({
    required String primaryPath,
    required String fallbackPath,
  }) async {
    try {
      return await ui.FragmentProgram.fromAsset(primaryPath);
    } catch (_) {
      try {
        return await ui.FragmentProgram.fromAsset(fallbackPath);
      } catch (e) {
        _lastError = e;
        return null;
      }
    }
  }

  /// Instantiates a new FragmentShader for celestial banner, or null if unavailable.
  ui.FragmentShader? createCelestialBannerShader() {
    return _celestialBannerProgram?.fragmentShader();
  }

  /// Instantiates a new FragmentShader for emblem aura, or null if unavailable.
  ui.FragmentShader? createEmblemAuraShader() {
    return _emblemAuraProgram?.fragmentShader();
  }

  /// Resets the shader cache (useful for hot reload and tests).
  void clear() {
    _celestialBannerProgram = null;
    _emblemAuraProgram = null;
    _initialized = false;
    _hasHardwareShaderSupport = true;
    _lastError = null;
  }
}
