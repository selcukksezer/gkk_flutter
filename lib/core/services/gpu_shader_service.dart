import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'graphics_quality_service.dart';

/// Lazy runtime GLSL [ui.FragmentProgram] manager gated by [GraphicsProfile.enableGpuShaders].
///
/// - On `Low` and `Medium` tiers, zero shader programs are loaded or instantiated.
/// - On `High` and `Ultra` tiers, shaders compile once on first request and reuse
///   cached [ui.FragmentProgram] instances across frames.
/// - Gracefully returns `null` in headless unit tests or unsupported backends.
class GpuShaderService extends ChangeNotifier {
  GpuShaderService._();

  static final GpuShaderService instance = GpuShaderService._();

  static const String waterCausticsAsset = 'shaders/gkk_water_caustics.frag';
  static const String heatDistortionAsset = 'shaders/gkk_heat_distortion.frag';

  ui.FragmentProgram? _waterProgram;
  ui.FragmentProgram? _heatProgram;
  bool _waterAttempted = false;
  bool _heatAttempted = false;

  bool get isWaterShaderReady => _waterProgram != null;
  bool get isHeatShaderReady => _heatProgram != null;

  /// Requests background compilation of enabled GPU shaders when on `High`/`Ultra`.
  Future<void> warmUpIfEnabled() async {
    if (!GraphicsQualityService.instance.profile.enableGpuShaders) return;
    await Future.wait<void>(<Future<void>>[
      _ensureWaterLoaded(),
      _ensureHeatLoaded(),
    ]);
  }

  Future<void> _ensureWaterLoaded() async {
    if (_waterAttempted || _waterProgram != null) return;
    _waterAttempted = true;
    try {
      _waterProgram = await ui.FragmentProgram.fromAsset(waterCausticsAsset);
      notifyListeners();
    } catch (_) {
      _waterProgram = null;
    }
  }

  Future<void> _ensureHeatLoaded() async {
    if (_heatAttempted || _heatProgram != null) return;
    _heatAttempted = true;
    try {
      _heatProgram = await ui.FragmentProgram.fromAsset(heatDistortionAsset);
      notifyListeners();
    } catch (_) {
      _heatProgram = null;
    }
  }

  /// Creates configured [ui.FragmentShader] for Moradon Pantheon fountain water caustics,
  /// or returns `null` when shaders are disabled / still warming up.
  ui.FragmentShader? createWaterCausticsShader({
    required ui.Size size,
    required double timeSec,
    double intensity = 1.0,
    double originX = 0.0,
    double originY = 0.0,
  }) {
    if (!GraphicsQualityService.instance.profile.enableGpuShaders) return null;
    if (_waterProgram == null) {
      if (!_waterAttempted) {
        _ensureWaterLoaded();
      }
      return null;
    }
    try {
      // Note: FlutterFragCoord() uses canvas-local coordinates when canvas is translated!
      // Callers should canvas.save() -> canvas.translate(rect.left, rect.top) -> draw at Offset.zero
      // so uv = FlutterFragCoord().xy / uSize maps [0..1] cleanly across the target rect!
      final ui.FragmentShader shader = _waterProgram!.fragmentShader();
      shader.setFloat(0, size.width <= 0 ? 1.0 : size.width);
      shader.setFloat(1, size.height <= 0 ? 1.0 : size.height);
      shader.setFloat(2, timeSec);
      shader.setFloat(3, intensity);
      return shader;
    } catch (_) {
      return null;
    }
  }

  /// Creates configured [ui.FragmentShader] for volcanic/solar dungeon & Blood Moon heat shimmer.
  ui.FragmentShader? createHeatDistortionShader({
    required ui.Size size,
    required double timeSec,
    double intensity = 1.0,
  }) {
    if (!GraphicsQualityService.instance.profile.enableGpuShaders) return null;
    if (_heatProgram == null) {
      if (!_heatAttempted) {
        _ensureHeatLoaded();
      }
      return null;
    }
    try {
      final ui.FragmentShader shader = _heatProgram!.fragmentShader();
      shader.setFloat(0, size.width <= 0 ? 1.0 : size.width);
      shader.setFloat(1, size.height <= 0 ? 1.0 : size.height);
      shader.setFloat(2, timeSec);
      shader.setFloat(3, intensity);
      return shader;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _waterProgram = null;
    _heatProgram = null;
    _waterAttempted = false;
    _heatAttempted = false;
  }
}
