import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// -----------------------------------------------------------------------------
// Production AAA Combat VFX: Refraction & Distortion Shader Pipeline (R3)
// Compatible with Flutter RuntimeEffect, Impeller, and Skia Pipelines
// -----------------------------------------------------------------------------

/// Visual simulation modes for the refraction and distortion pipeline.
enum RefractionEffectMode {
  /// Radial shockwave blast expanding outward (ground impact, explosions).
  shockwave(0.0, 'Shockwave', 'Radial expanding shockwave blast'),

  /// Fast high-velocity critical hit impact with dual harmonics & intense dispersion.
  criticalHit(1.0, 'Critical Hit', 'Violent multi-harmonic critical strike blast'),

  /// Convective fluid turbulence & rising atmospheric heat shimmer.
  heatHaze(2.0, 'Heat Haze', 'Continuous rising heat convection turbulence'),

  /// Hexagonal/circular standing interference ripple for magical barriers.
  magicalShield(3.0, 'Magical Shield', 'Magical runic barrier impact ripples');

  const RefractionEffectMode(this.shaderValue, this.label, this.description);

  /// Numeric mode identifier passed to the GLSL fragment shader `uMode`.
  final double shaderValue;

  /// Human-readable label.
  final String label;

  /// Detailed mode description.
  final String description;
}

/// Immutable configuration data class for refraction distortion parameters.
class RefractionParams {
  const RefractionParams({
    this.center = const ui.Offset(0.5, 0.5),
    this.progress = 0.0,
    this.time = 0.0,
    this.maxRadius = 0.75,
    this.thickness = 0.08,
    this.refractionStrength = 0.05,
    this.chromaticAberration = 0.02,
    this.dampening = 2.5,
    this.frequency = 3.0,
    this.mode = RefractionEffectMode.shockwave,
    this.useNormalMap = false,
    this.tint = const ui.Color(0x00000000),
  });

  /// Specialized preset for physical / blunt explosive ground shockwaves.
  factory RefractionParams.shockwave({
    ui.Offset center = const ui.Offset(0.5, 0.5),
    double progress = 0.0,
    double time = 0.0,
    double maxRadius = 0.8,
    double thickness = 0.09,
    double refractionStrength = 0.055,
    double chromaticAberration = 0.018,
    double dampening = 2.2,
    double frequency = 3.0,
    ui.Color tint = const ui.Color(0x33FFFFFF),
    bool useNormalMap = false,
  }) {
    return RefractionParams(
      center: center,
      progress: progress,
      time: time,
      maxRadius: maxRadius,
      thickness: thickness,
      refractionStrength: refractionStrength,
      chromaticAberration: chromaticAberration,
      dampening: dampening,
      frequency: frequency,
      mode: RefractionEffectMode.shockwave,
      useNormalMap: useNormalMap,
      tint: tint,
    );
  }

  /// Specialized preset for lethal critical strike hit impacts with crimson/gold flare.
  factory RefractionParams.criticalHit({
    ui.Offset center = const ui.Offset(0.5, 0.5),
    double progress = 0.0,
    double time = 0.0,
    double maxRadius = 0.95,
    double thickness = 0.12,
    double refractionStrength = 0.085,
    double chromaticAberration = 0.045,
    double dampening = 3.2,
    double frequency = 4.5,
    ui.Color tint = const ui.Color(0x66FF3333),
    bool useNormalMap = false,
  }) {
    return RefractionParams(
      center: center,
      progress: progress,
      time: time,
      maxRadius: maxRadius,
      thickness: thickness,
      refractionStrength: refractionStrength,
      chromaticAberration: chromaticAberration,
      dampening: dampening,
      frequency: frequency,
      mode: RefractionEffectMode.criticalHit,
      useNormalMap: useNormalMap,
      tint: tint,
    );
  }

  /// Specialized preset for continuous atmospheric heat convection and fire haze.
  factory RefractionParams.heatHaze({
    ui.Offset center = const ui.Offset(0.5, 0.5),
    double time = 0.0,
    double maxRadius = 0.7,
    double refractionStrength = 0.025,
    double chromaticAberration = 0.008,
    double frequency = 3.5,
    ui.Color tint = const ui.Color(0x18FF8822),
    bool useNormalMap = false,
  }) {
    return RefractionParams(
      center: center,
      progress: 0.5,
      time: time,
      maxRadius: maxRadius,
      thickness: 0.15,
      refractionStrength: refractionStrength,
      chromaticAberration: chromaticAberration,
      dampening: 0.0,
      frequency: frequency,
      mode: RefractionEffectMode.heatHaze,
      useNormalMap: useNormalMap,
      tint: tint,
    );
  }

  /// Specialized preset for magical shield impacts and arcane rune barriers.
  factory RefractionParams.magicalShield({
    ui.Offset center = const ui.Offset(0.5, 0.5),
    double progress = 0.0,
    double time = 0.0,
    double maxRadius = 0.85,
    double thickness = 0.10,
    double refractionStrength = 0.065,
    double chromaticAberration = 0.030,
    double dampening = 2.8,
    double frequency = 5.0,
    ui.Color tint = const ui.Color(0x5522E5FF),
    bool useNormalMap = false,
  }) {
    return RefractionParams(
      center: center,
      progress: progress,
      time: time,
      maxRadius: maxRadius,
      thickness: thickness,
      refractionStrength: refractionStrength,
      chromaticAberration: chromaticAberration,
      dampening: dampening,
      frequency: frequency,
      mode: RefractionEffectMode.magicalShield,
      useNormalMap: useNormalMap,
      tint: tint,
    );
  }

  /// Normalized origin center of the refraction [0.0..1.0] in UV coordinates.
  final ui.Offset center;

  /// Expansion lifecycle progress [0.0..1.0].
  final double progress;

  /// Continuous elapsed simulation time in seconds.
  final double time;

  /// Maximum radius reached at progress=1.0 relative to min screen dimension.
  final double maxRadius;

  /// Width / thickness of the shockwave refraction ring.
  final double thickness;

  /// Peak displacement amplitude for UV refraction.
  final double refractionStrength;

  /// Magnitude of radial chromatic dispersion separating RGB channels.
  final double chromaticAberration;

  /// Exponential decay dampening factor over time and distance.
  final double dampening;

  /// Ripple oscillation frequency across the wavefront.
  final double frequency;

  /// Visual effect mode.
  final RefractionEffectMode mode;

  /// Whether to blend with the normal-map sampler texture.
  final bool useNormalMap;

  /// Wavefront energy glow tint and alpha multiplier.
  final ui.Color tint;

  /// Creates a copy of [RefractionParams] with modified fields.
  RefractionParams copyWith({
    ui.Offset? center,
    double? progress,
    double? time,
    double? maxRadius,
    double? thickness,
    double? refractionStrength,
    double? chromaticAberration,
    double? dampening,
    double? frequency,
    RefractionEffectMode? mode,
    bool? useNormalMap,
    ui.Color? tint,
  }) {
    return RefractionParams(
      center: center ?? this.center,
      progress: progress ?? this.progress,
      time: time ?? this.time,
      maxRadius: maxRadius ?? this.maxRadius,
      thickness: thickness ?? this.thickness,
      refractionStrength: refractionStrength ?? this.refractionStrength,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      dampening: dampening ?? this.dampening,
      frequency: frequency ?? this.frequency,
      mode: mode ?? this.mode,
      useNormalMap: useNormalMap ?? this.useNormalMap,
      tint: tint ?? this.tint,
    );
  }

  /// Serializes uniforms into a list of 18 floats in exact GLSL declaration order.
  ///
  /// Index layout:
  ///   0..1:   uResolution (vec2)
  ///   2..3:   uCenter (vec2)
  ///   4:      uProgress (float)
  ///   5:      uTime (float)
  ///   6:      uMaxRadius (float)
  ///   7:      uThickness (float)
  ///   8:      uRefractionStrength (float)
  ///   9:      uChromaticAberration (float)
  ///   10:     uDampening (float)
  ///   11:     uFrequency (float)
  ///   12:     uMode (float)
  ///   13:     uUseNormalMap (float)
  ///   14..17: uTint (vec4: r, g, b, a in [0..1])
  List<double> toUniformList({required ui.Size size}) {
    return <double>[
      size.width,
      size.height,
      center.dx,
      center.dy,
      progress,
      time,
      maxRadius,
      thickness,
      refractionStrength,
      chromaticAberration,
      dampening,
      frequency,
      mode.shaderValue,
      useNormalMap ? 1.0 : 0.0,
      tint.r,
      tint.g,
      tint.b,
      tint.a,
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RefractionParams &&
        other.center == center &&
        other.progress == progress &&
        other.time == time &&
        other.maxRadius == maxRadius &&
        other.thickness == thickness &&
        other.refractionStrength == refractionStrength &&
        other.chromaticAberration == chromaticAberration &&
        other.dampening == dampening &&
        other.frequency == frequency &&
        other.mode == mode &&
        other.useNormalMap == useNormalMap &&
        other.tint == tint;
  }

  @override
  int get hashCode {
    return Object.hash(
      center,
      progress,
      time,
      maxRadius,
      thickness,
      refractionStrength,
      chromaticAberration,
      dampening,
      frequency,
      mode,
      useNormalMap,
      tint,
    );
  }

  @override
  String toString() {
    return 'RefractionParams(mode: ${mode.label}, progress: ${progress.toStringAsFixed(3)}, '
        'radius: ${maxRadius.toStringAsFixed(2)}, strength: ${refractionStrength.toStringAsFixed(3)})';
  }
}

/// Analytical mathematical model mirroring the GLSL shader equations.
///
/// Provides identical math logic on the CPU for headless unit testing,
/// physics trajectory calculations, and fallback rendering pipelines.
class RefractionMath {
  RefractionMath._();

  static const double _pi = math.pi;
  static const double _twoPi = math.pi * 2.0;

  /// Calculates the current expanding wavefront radius at the given progress.
  static double calculateCurrentRadius(RefractionParams params) {
    switch (params.mode) {
      case RefractionEffectMode.shockwave:
      case RefractionEffectMode.magicalShield:
        return params.maxRadius * params.progress;
      case RefractionEffectMode.criticalHit:
        return params.maxRadius * math.sqrt(params.progress.clamp(0.0, 1.0));
      case RefractionEffectMode.heatHaze:
        return params.maxRadius;
    }
  }

  /// Calculates the time-based exponential decay factor for the wavefront.
  static double calculateDecay(RefractionParams params) {
    if (params.mode == RefractionEffectMode.heatHaze) {
      return 1.0;
    }

    final double p = params.progress.clamp(0.0, 1.0);
    final double dampening = params.mode == RefractionEffectMode.criticalHit
        ? (params.dampening * 0.7)
        : params.dampening;

    return math.exp(-dampening * p) * (1.0 - p);
  }

  /// Calculates Hann window bell taper factor for a given offset from wavefront crest.
  static double calculateHannEnvelope({
    required double distToFront,
    required double thickness,
  }) {
    final double halfThick = math.max(thickness * 0.5, 0.0001);
    if (distToFront.abs() >= halfThick) {
      return 0.0;
    }
    final double x = distToFront / halfThick; // [-1.0 .. 1.0]
    return 0.5 * (1.0 + math.cos(x * _pi));
  }

  /// Determines whether a given UV coordinate is within the active refraction ring.
  static bool isWithinWavefront({
    required ui.Offset uv,
    required ui.Size size,
    required RefractionParams params,
  }) {
    final double minDim = math.min(size.width, size.height);
    final double aspectX = size.width / math.max(minDim, 1.0);
    final double aspectY = size.height / math.max(minDim, 1.0);

    final double dx = (uv.dx - params.center.dx) * aspectX;
    final double dy = (uv.dy - params.center.dy) * aspectY;
    final double dist = math.sqrt(dx * dx + dy * dy);

    if (params.mode == RefractionEffectMode.heatHaze) {
      return dist <= params.maxRadius;
    }

    final double currentRadius = calculateCurrentRadius(params);
    final double distToFront = dist - currentRadius;
    final double halfThick = math.max(params.thickness * 0.5, 0.0001);

    return distToFront.abs() < halfThick;
  }

  /// Computes the exact analytical UV displacement offset `(dx, dy)` at [uv].
  static ui.Offset calculateDisplacement({
    required ui.Offset uv,
    required ui.Size size,
    required RefractionParams params,
  }) {
    final double minDim = math.min(size.width, size.height);
    final double aspectX = size.width / math.max(minDim, 1.0);
    final double aspectY = size.height / math.max(minDim, 1.0);

    final double deltaX = (uv.dx - params.center.dx) * aspectX;
    final double deltaY = (uv.dy - params.center.dy) * aspectY;
    final double dist = math.sqrt(deltaX * deltaX + deltaY * deltaY);

    final double radDirX;
    final double radDirY;
    if (dist > 0.00001) {
      radDirX = (deltaX / dist) / aspectX;
      radDirY = (deltaY / dist) / aspectY;
    } else {
      radDirX = 0.0;
      radDirY = 1.0 / aspectY;
    }

    switch (params.mode) {
      case RefractionEffectMode.shockwave: {
        final double currentRadius = params.maxRadius * params.progress;
        final double distToFront = dist - currentRadius;
        final double halfThick = math.max(params.thickness * 0.5, 0.0001);

        if (distToFront.abs() >= halfThick) {
          return ui.Offset.zero;
        }

        final double x = distToFront / halfThick;
        final double envelope = 0.5 * (1.0 + math.cos(x * _pi));
        final double wave = -math.sin(x * _pi * math.max(params.frequency, 0.1));
        final double decay = calculateDecay(params);
        final double mag = wave * envelope * decay * params.refractionStrength;

        return ui.Offset(radDirX * mag, radDirY * mag);
      }

      case RefractionEffectMode.criticalHit: {
        final double currentRadius = params.maxRadius * math.sqrt(params.progress.clamp(0.0, 1.0));
        final double distToFront = dist - currentRadius;
        final double halfThick = math.max(params.thickness * 0.5, 0.0001);

        if (distToFront.abs() >= halfThick) {
          return ui.Offset.zero;
        }

        final double x = distToFront / halfThick;
        final double envelope = 0.5 * (1.0 + math.cos(x * _pi));
        final double wave1 = -math.sin(x * _pi * math.max(params.frequency, 0.1));
        final double wave2 = -0.4 * math.sin(x * _twoPi * math.max(params.frequency, 0.1));
        final double combined = wave1 + wave2;
        final double decay = calculateDecay(params);
        final double mag = combined * envelope * decay * params.refractionStrength;

        return ui.Offset(radDirX * mag, radDirY * mag);
      }

      case RefractionEffectMode.heatHaze: {
        final double hazeX = uv.dx * (math.max(params.frequency, 1.0) * 8.0);
        final double hazeY = uv.dy * (math.max(params.frequency, 1.0) * 8.0) - params.time * 2.5;

        final double w1 = math.sin(hazeX * 2.0 + math.sin(hazeY * 3.0 + params.time * 3.5));
        final double w2 = math.cos(hazeY * 2.5 + math.cos(hazeX * 3.5 - params.time * 2.8));
        final double w3 = math.sin((hazeX + hazeY) * 1.8 + params.time * 2.2);

        final double rawX = (w1 + w3 * 0.4) * 0.5;
        final double rawY = (w2 + w1 * 0.35) * 0.5;

        final double hazeRadius = math.max(params.maxRadius, 0.01);
        final double falloff = (1.0 - dist / hazeRadius).clamp(0.0, 1.0);
        final double smoothFalloff = falloff * falloff * (3.0 - 2.0 * falloff);

        final double mag = params.refractionStrength * smoothFalloff;
        return ui.Offset((rawX / aspectX) * mag, (rawY / aspectY) * mag);
      }

      case RefractionEffectMode.magicalShield: {
        final double currentRadius = params.maxRadius * params.progress;
        final double phase = (dist - currentRadius) / math.max(params.thickness, 0.001);
        final double ringWave = math.sin(phase * _pi * math.max(params.frequency, 0.1));

        final double spatialDecay = math.exp(-dist * 2.5 / math.max(params.maxRadius, 0.01));
        final double decay = calculateDecay(params);

        final double angle = math.atan2(deltaY, deltaX);
        final double hexMod = 1.0 + 0.18 * math.cos(angle * 6.0);

        final double mag = ringWave * spatialDecay * decay * hexMod * params.refractionStrength;
        return ui.Offset(radDirX * mag, radDirY * mag);
      }
    }
  }

  /// Calculates separated sampling UVs for Red, Green, and Blue channels for chromatic dispersion.
  static ({ui.Offset red, ui.Offset green, ui.Offset blue}) calculateChromaticUvs({
    required ui.Offset uv,
    required ui.Size size,
    required RefractionParams params,
  }) {
    final ui.Offset displacement = calculateDisplacement(uv: uv, size: size, params: params);

    final double minDim = math.min(size.width, size.height);
    final double aspectX = size.width / math.max(minDim, 1.0);
    final double aspectY = size.height / math.max(minDim, 1.0);

    final double deltaX = (uv.dx - params.center.dx) * aspectX;
    final double deltaY = (uv.dy - params.center.dy) * aspectY;
    final double dist = math.sqrt(deltaX * deltaX + deltaY * deltaY);

    final double radDirX = dist > 0.00001 ? (deltaX / dist) / aspectX : 0.0;
    final double radDirY = dist > 0.00001 ? (deltaY / dist) / aspectY : 1.0 / aspectY;

    double chromaticMagnitude = params.chromaticAberration;
    if (params.mode == RefractionEffectMode.criticalHit) {
      chromaticMagnitude *= 2.5;
    }

    final double dispMag = math.sqrt(
      displacement.dx * aspectX * displacement.dx * aspectX +
          displacement.dy * aspectY * displacement.dy * aspectY,
    );
    final double offsetAmount =
        chromaticMagnitude * (dispMag / math.max(params.refractionStrength, 0.0001));

    final ui.Offset redOffset = ui.Offset(
      displacement.dx + radDirX * offsetAmount,
      displacement.dy + radDirY * offsetAmount,
    );
    final ui.Offset greenOffset = displacement;
    final ui.Offset blueOffset = ui.Offset(
      displacement.dx - radDirX * offsetAmount,
      displacement.dy - radDirY * offsetAmount,
    );

    ui.Offset clampUv(ui.Offset p) => ui.Offset(
          p.dx.clamp(0.0, 1.0),
          p.dy.clamp(0.0, 1.0),
        );

    return (
      red: clampUv(uv + redOffset),
      green: clampUv(uv + greenOffset),
      blue: clampUv(uv + blueOffset),
    );
  }
}

/// Controller managing refraction shader lifecycle, uniform serialization, and animation triggers.
class RefractionShaderController extends ChangeNotifier {
  RefractionShaderController({
    RefractionParams? initialParams,
    this.defaultDuration = const Duration(milliseconds: 600),
  }) : _params = initialParams ?? const RefractionParams();

  RefractionParams _params;
  RefractionParams get params => _params;

  final Duration defaultDuration;

  ui.FragmentShader? _shader;
  ui.FragmentShader? get fragmentShader => _shader;
  bool get isShaderLoaded => _shader != null;

  bool _isActive = false;
  bool get isActive => _isActive;

  double _elapsedTimeSeconds = 0.0;
  double get elapsedTimeSeconds => _elapsedTimeSeconds;

  double _durationSeconds = 0.6;
  bool _isContinuous = false;
  bool get isContinuous => _isContinuous;

  /// Loads the compiled fragment shader from asset bundle.
  /// Gracefully catches errors if running in headless test environments.
  Future<bool> initShader([
    String assetPath = 'shaders/vfx/shockwave_refraction.frag',
  ]) async {
    try {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(assetPath);
      _shader = program.fragmentShader();
      notifyListeners();
      return true;
    } catch (_) {
      // In headless unit test runners without GPU runtime effect support,
      // shaders cannot be loaded via AssetBundle. CPU math fallback is used.
      _shader = null;
      return false;
    }
  }

  /// Directly assigns a pre-created [ui.FragmentShader] (e.g. For mocks or tests).
  void setShader(ui.FragmentShader? shader) {
    _shader = shader;
    notifyListeners();
  }

  /// Triggers a physical blast shockwave expansion.
  void triggerShockwave({
    ui.Offset center = const ui.Offset(0.5, 0.5),
    double maxRadius = 0.8,
    double thickness = 0.09,
    double strength = 0.055,
    double chromaticAberration = 0.02,
    double dampening = 2.2,
    Duration? duration,
    ui.Color tint = const ui.Color(0x33FFFFFF),
  }) {
    _params = RefractionParams.shockwave(
      center: center,
      progress: 0.0,
      time: 0.0,
      maxRadius: maxRadius,
      thickness: thickness,
      refractionStrength: strength,
      chromaticAberration: chromaticAberration,
      dampening: dampening,
      tint: tint,
    );

    _startAnimation(duration ?? defaultDuration, isContinuous: false);
  }

  /// Triggers a punchy critical hit impact blast with violent dual-harmonic dispersion.
  void triggerCriticalHit({
    ui.Offset center = const ui.Offset(0.5, 0.5),
    double maxRadius = 0.95,
    double strength = 0.085,
    double chromaticAberration = 0.045,
    Duration? duration,
    ui.Color tint = const ui.Color(0x66FF3333),
  }) {
    _params = RefractionParams.criticalHit(
      center: center,
      progress: 0.0,
      time: 0.0,
      maxRadius: maxRadius,
      refractionStrength: strength,
      chromaticAberration: chromaticAberration,
      tint: tint,
    );

    _startAnimation(duration ?? const Duration(milliseconds: 450), isContinuous: false);
  }

  /// Triggers a magical barrier shield impact with runic interference ripples.
  void triggerMagicalShield({
    ui.Offset center = const ui.Offset(0.5, 0.5),
    double maxRadius = 0.85,
    double strength = 0.065,
    Duration? duration,
    ui.Color tint = const ui.Color(0x5522E5FF),
  }) {
    _params = RefractionParams.magicalShield(
      center: center,
      progress: 0.0,
      time: 0.0,
      maxRadius: maxRadius,
      refractionStrength: strength,
      tint: tint,
    );

    _startAnimation(duration ?? const Duration(milliseconds: 700), isContinuous: false);
  }

  /// Activates continuous heat haze convection distortion.
  void startContinuousHeatHaze({
    ui.Offset center = const ui.Offset(0.5, 0.5),
    double maxRadius = 0.75,
    double strength = 0.03,
    ui.Color tint = const ui.Color(0x18FF8822),
  }) {
    _params = RefractionParams.heatHaze(
      center: center,
      maxRadius: maxRadius,
      refractionStrength: strength,
      tint: tint,
    );

    _isActive = true;
    _isContinuous = true;
    _elapsedTimeSeconds = 0.0;
    notifyListeners();
  }

  /// Stops any currently active continuous or transient distortion.
  void stop() {
    _isActive = false;
    _isContinuous = false;
    _params = _params.copyWith(progress: 0.0);
    notifyListeners();
  }

  void _startAnimation(Duration duration, {required bool isContinuous}) {
    _isActive = true;
    _isContinuous = isContinuous;
    _elapsedTimeSeconds = 0.0;
    _durationSeconds = math.max(duration.inMicroseconds / 1000000.0, 0.01);
    _params = _params.copyWith(progress: 0.0, time: 0.0);
    notifyListeners();
  }

  /// Advances animation time by [dtSeconds] and updates progress/time uniforms.
  void update(double dtSeconds) {
    if (!_isActive) return;

    _elapsedTimeSeconds += dtSeconds;

    if (_isContinuous) {
      _params = _params.copyWith(time: _elapsedTimeSeconds);
      notifyListeners();
      return;
    }

    final double progress = (_elapsedTimeSeconds / _durationSeconds).clamp(0.0, 1.0);
    _params = _params.copyWith(progress: progress, time: _elapsedTimeSeconds);

    if (progress >= 1.0) {
      _isActive = false;
      _params = _params.copyWith(progress: 1.0);
    }

    notifyListeners();
  }

  /// Builds the 18 uniform values for `shaders/vfx/shockwave_refraction.frag`.
  List<double> buildUniformList(ui.Size size) {
    return _params.toUniformList(size: size);
  }

  /// Returns uniform values as a contiguous [Float32List] buffer.
  Float32List toUniformFloat32List(ui.Size size) {
    final List<double> uniforms = buildUniformList(size);
    final Float32List buffer = Float32List(uniforms.length);
    for (int i = 0; i < uniforms.length; i++) {
      buffer[i] = uniforms[i];
    }
    return buffer;
  }

  /// Configures the provided [ui.FragmentShader] with the packed uniforms.
  void applyUniforms(ui.FragmentShader shader, ui.Size size) {
    final List<double> uniforms = buildUniformList(size);
    for (int i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }
  }

  /// Pre-warms the GPU rasterization pipeline offscreen with this shader.
  void warmUp(ui.Canvas canvas, ui.Size size) {
    final ui.FragmentShader? s = _shader;
    if (s != null) {
      applyUniforms(s, size);
      final ui.Paint paint = ui.Paint()..shader = s;
      canvas.drawRect(ui.Offset.zero & size, paint);
    } else {
      // Standalone warm-up path to prime the canvas rasterizer
      final ui.Paint fallbackPaint = ui.Paint()
        ..color = const ui.Color(0x00000000)
        ..style = ui.PaintingStyle.fill;
      canvas.drawRect(ui.Offset.zero & size, fallbackPaint);
    }
  }
}

/// Standalone [ShaderWarmUp] integration for Flutter's `PaintingBinding`.
///
/// Pre-warms the refraction shader pipeline offscreen to eliminate first-hit
/// frame drops during high-intensity dungeon combat encounters.
class RefractionShaderWarmUp extends ShaderWarmUp {
  const RefractionShaderWarmUp({
    this.controller,
    this.warmUpSize = const ui.Size(128.0, 128.0),
  });

  /// Optional active controller providing the compiled shader.
  final RefractionShaderController? controller;

  /// Render target dimensions for the warm-up canvas draw call.
  final ui.Size warmUpSize;

  @override
  Future<void> warmUpOnCanvas(ui.Canvas canvas) async {
    final RefractionShaderController? ctrl = controller;
    if (ctrl != null && ctrl.isShaderLoaded) {
      ctrl.warmUp(canvas, warmUpSize);
    } else {
      final ui.Paint paint = ui.Paint()
        ..color = const ui.Color(0xFF000000)
        ..blendMode = ui.BlendMode.srcOver;
      canvas.drawRect(ui.Offset.zero & warmUpSize, paint);
    }
  }
}

/// Custom painter rendering the refraction and shockwave distortion effect.
///
/// Uses [ui.FragmentShader] and samplers when available, with a high-fidelity
/// software simulation fallback for headless test runners and legacy devices.
class RefractionEffectPainter extends CustomPainter {
  RefractionEffectPainter({
    required this.controller,
    this.shader,
    this.sceneTexture,
    this.normalMapTexture,
  }) : super(repaint: controller);

  final RefractionShaderController controller;
  final ui.FragmentShader? shader;
  final ui.Image? sceneTexture;
  final ui.Image? normalMapTexture;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (!controller.isActive && controller.params.progress <= 0.0) {
      // If idle, pass through background if available
      if (sceneTexture != null) {
        canvas.drawImageRect(
          sceneTexture!,
          ui.Rect.fromLTWH(0, 0, sceneTexture!.width.toDouble(), sceneTexture!.height.toDouble()),
          ui.Offset.zero & size,
          ui.Paint(),
        );
      }
      return;
    }

    final ui.FragmentShader? activeShader = shader ?? controller.fragmentShader;

    if (activeShader != null && sceneTexture != null) {
      // GPU Fragment Shader Path
      controller.applyUniforms(activeShader, size);
      activeShader.setImageSampler(0, sceneTexture!);

      if (normalMapTexture != null) {
        activeShader.setImageSampler(1, normalMapTexture!);
      }

      final ui.Paint paint = ui.Paint()..shader = activeShader;
      canvas.drawRect(ui.Offset.zero & size, paint);
    } else {
      // Software / Headless Fallback Path
      if (sceneTexture != null) {
        canvas.drawImageRect(
          sceneTexture!,
          ui.Rect.fromLTWH(0, 0, sceneTexture!.width.toDouble(), sceneTexture!.height.toDouble()),
          ui.Offset.zero & size,
          ui.Paint(),
        );
      }

      _paintSoftwareFallback(canvas, size);
    }
  }

  void _paintSoftwareFallback(ui.Canvas canvas, ui.Size size) {
    final RefractionParams p = controller.params;
    final double decay = RefractionMath.calculateDecay(p);
    if (decay <= 0.001) return;

    final double minDim = math.min(size.width, size.height);
    final double radius = RefractionMath.calculateCurrentRadius(p) * minDim;
    final double thickness = math.max(p.thickness * minDim, 2.0);

    final ui.Offset centerPx = ui.Offset(p.center.dx * size.width, p.center.dy * size.height);

    // Shockwave wavefront ring
    final ui.Color ringColor = p.tint.a > 0
        ? p.tint.withValues(alpha: (p.tint.a * decay).clamp(0.0, 1.0))
        : ui.Color.fromRGBO(255, 255, 255, (0.35 * decay).clamp(0.0, 1.0));

    final ui.Paint ringPaint = ui.Paint()
      ..color = ringColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = thickness
      ..blendMode = ui.BlendMode.screen;

    canvas.drawCircle(centerPx, radius, ringPaint);

    // Critical hit core impact flare
    if (p.mode == RefractionEffectMode.criticalHit && p.progress < 0.4) {
      final double flashAlpha = ((1.0 - p.progress / 0.4) * 0.7).clamp(0.0, 1.0);
      final ui.Paint flashPaint = ui.Paint()
        ..color = ui.Color.fromRGBO(255, 245, 220, flashAlpha)
        ..style = ui.PaintingStyle.fill
        ..blendMode = ui.BlendMode.plus;
      canvas.drawCircle(centerPx, radius * 0.35, flashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RefractionEffectPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.shader != shader ||
        oldDelegate.sceneTexture != sceneTexture ||
        oldDelegate.normalMapTexture != normalMapTexture;
  }
}

/// Helper utility for generating neutral fallback normal textures.
class RefractionTextureHelper {
  RefractionTextureHelper._();

  static ui.Image? _cachedNeutralNormal;

  /// Creates a cached 2x2 flat neutral normal map `[128, 128, 255, 255]`.
  static Future<ui.Image> getNeutralNormalTexture() async {
    if (_cachedNeutralNormal != null) {
      return _cachedNeutralNormal!;
    }

    final Completer<ui.Image> completer = Completer<ui.Image>();
    const int width = 2;
    const int height = 2;
    final Uint8List pixels = Uint8List(width * height * 4);

    for (int i = 0; i < pixels.length; i += 4) {
      pixels[i] = 128; // Tangent X = 0.0
      pixels[i + 1] = 128; // Tangent Y = 0.0
      pixels[i + 2] = 255; // Tangent Z = +1.0
      pixels[i + 3] = 255; // Alpha = 1.0
    }

    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        _cachedNeutralNormal = image;
        completer.complete(image);
      },
    );

    return completer.future;
  }
}

/// Production widget wrapping any content with the Refraction & Shockwave VFX pipeline.
class RefractionEffectWidget extends StatefulWidget {
  const RefractionEffectWidget({
    super.key,
    required this.child,
    required this.controller,
    this.shaderAssetPath = 'shaders/vfx/shockwave_refraction.frag',
    this.normalMapTexture,
  });

  final Widget child;
  final RefractionShaderController controller;
  final String shaderAssetPath;
  final ui.Image? normalMapTexture;

  @override
  State<RefractionEffectWidget> createState() => _RefractionEffectWidgetState();
}

class _RefractionEffectWidgetState extends State<RefractionEffectWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.initShader(widget.shaderAssetPath);
    widget.controller.addListener(_onControllerChanged);

    _ticker = createTicker(_onTick);
    if (widget.controller.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _onControllerChanged() {
    if (widget.controller.isActive && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!widget.controller.isActive && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    if (!widget.controller.isActive) {
      _ticker.stop();
      return;
    }

    final double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (dt > 0.0) {
      widget.controller.update(dt);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          foregroundPainter: RefractionEffectPainter(
            controller: widget.controller,
            shader: widget.controller.fragmentShader,
            normalMapTexture: widget.normalMapTexture,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
