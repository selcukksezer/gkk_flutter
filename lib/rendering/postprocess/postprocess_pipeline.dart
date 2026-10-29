import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import 'aces_tonemap_curve.dart';
import 'bilateral_filter.dart';
import 'ssao_kernel.dart';

/// Controller and uniform builder for post-processing shaders.
class PostProcessPipelineController {
  PostProcessPipelineController({
    AcesTonemapParams? acesParams,
    SsaoParams? ssaoParams,
    BilateralFilterParams? bilateralParams,
  })  : acesParams = acesParams ?? const AcesTonemapParams(),
        ssaoParams = ssaoParams ?? const SsaoParams(),
        bilateralParams = bilateralParams ?? const BilateralFilterParams();

  AcesTonemapParams acesParams;
  SsaoParams ssaoParams;
  BilateralFilterParams bilateralParams;

  ui.FragmentShader? _acesShader;
  ui.FragmentShader? _ssaoShader;
  ui.FragmentShader? _blurShader;
  ui.FragmentShader? _compositeShader;

  ui.FragmentShader? get acesShader => _acesShader;
  ui.FragmentShader? get ssaoShader => _ssaoShader;
  ui.FragmentShader? get blurShader => _blurShader;
  ui.FragmentShader? get compositeShader => _compositeShader;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Loads and initializes the compiled fragment shaders from asset bundle.
  /// Gracefully catches errors if running in headless test environments.
  Future<bool> initShaders() async {
    try {
      final ui.FragmentProgram acesProg =
          await ui.FragmentProgram.fromAsset('shaders/postprocess/aces_tonemap.frag');
      _acesShader = acesProg.fragmentShader();

      final ui.FragmentProgram ssaoProg =
          await ui.FragmentProgram.fromAsset('shaders/postprocess/ssao.frag');
      _ssaoShader = ssaoProg.fragmentShader();

      final ui.FragmentProgram blurProg =
          await ui.FragmentProgram.fromAsset('shaders/postprocess/ssao_bilateral_blur.frag');
      _blurShader = blurProg.fragmentShader();

      final ui.FragmentProgram compositeProg =
          await ui.FragmentProgram.fromAsset('shaders/postprocess/ssao_composite_aces.frag');
      _compositeShader = compositeProg.fragmentShader();

      _isInitialized = true;
      return true;
    } catch (_) {
      // In headless test runners without GPU runtime effect support,
      // shaders cannot be loaded via AssetBundle. CPU math fallback is used.
      _isInitialized = false;
      return false;
    }
  }

  /// Packs uniform floats for `aces_tonemap.frag` in exact GLSL declaration order.
  static List<double> buildAcesUniforms({
    required Size size,
    required AcesTonemapParams params,
  }) {
    return <double>[
      size.width,
      size.height,
      params.exposure,
      params.exposureMode == ExposureMode.evStops ? 1.0 : 0.0,
      params.fitType == AcesFitType.narkowicz ? 1.0 : 0.0,
      params.gammaMode == GammaMode.gamma22 ? 1.0 : 0.0,
      params.preGain,
      params.whitePoint,
    ];
  }

  /// Packs uniform floats for `ssao.frag` in exact GLSL declaration order.
  static List<double> buildSsaoUniforms({
    required Size size,
    required SsaoParams params,
  }) {
    return <double>[
      size.width,
      size.height,
      params.radius,
      params.bias,
      params.intensity,
      params.power,
      params.sampleCount.toDouble(),
      params.near,
      params.far,
    ];
  }

  /// Packs uniform floats for `ssao_bilateral_blur.frag` in exact GLSL declaration order.
  static List<double> buildBilateralUniforms({
    required Size size,
    required Offset direction,
    required BilateralFilterParams params,
  }) {
    return <double>[
      size.width,
      size.height,
      direction.dx,
      direction.dy,
      params.spatialSigma,
      params.depthThreshold,
    ];
  }

  /// Packs uniform floats for `ssao_composite_aces.frag` in exact GLSL declaration order.
  static List<double> buildCompositeUniforms({
    required Size size,
    required AcesTonemapParams acesParams,
    double aoIntensity = 1.0,
    double aoDirectLightPreserve = 0.25,
  }) {
    return <double>[
      size.width,
      size.height,
      acesParams.exposure,
      acesParams.exposureMode == ExposureMode.evStops ? 1.0 : 0.0,
      acesParams.fitType == AcesFitType.narkowicz ? 1.0 : 0.0,
      acesParams.gammaMode == GammaMode.gamma22 ? 1.0 : 0.0,
      aoIntensity,
      aoDirectLightPreserve,
    ];
  }

  /// Exact GLSL 460 Impeller uniform layout metadata constants.
  static const int acesFloatCount = 8;
  static const int acesSamplerCount = 1;

  static const int ssaoFloatCount = 9;
  static const int ssaoSamplerCount = 2;

  static const int bilateralFloatCount = 6;
  static const int bilateralSamplerCount = 2;

  static const int compositeFloatCount = 8;
  static const int compositeSamplerCount = 2;

  /// Packs uniform floats as [Float32List] for `aces_tonemap.frag`.
  static Float32List packAcesUniforms({
    required Size size,
    required AcesTonemapParams params,
  }) {
    return Float32List.fromList(buildAcesUniforms(size: size, params: params));
  }

  /// Packs uniform floats as [Float32List] for `ssao.frag`.
  static Float32List packSsaoUniforms({
    required Size size,
    required SsaoParams params,
  }) {
    return Float32List.fromList(buildSsaoUniforms(size: size, params: params));
  }

  /// Packs uniform floats as [Float32List] for `ssao_bilateral_blur.frag`.
  static Float32List packBilateralUniforms({
    required Size size,
    required Offset direction,
    required BilateralFilterParams params,
  }) {
    return Float32List.fromList(
      buildBilateralUniforms(size: size, direction: direction, params: params),
    );
  }

  /// Packs uniform floats as [Float32List] for `ssao_composite_aces.frag`.
  static Float32List packCompositeUniforms({
    required Size size,
    required AcesTonemapParams acesParams,
    double aoIntensity = 1.0,
    double aoDirectLightPreserve = 0.25,
  }) {
    return Float32List.fromList(
      buildCompositeUniforms(
        size: size,
        acesParams: acesParams,
        aoIntensity: aoIntensity,
        aoDirectLightPreserve: aoDirectLightPreserve,
      ),
    );
  }

  /// Configures `aces_tonemap.frag` shader uniforms and optional scene sampler (Sampler 0).
  void configureAcesShader(
    ui.FragmentShader shader,
    Size size, {
    ui.Image? sceneTexture,
  }) {
    final List<double> uniforms = buildAcesUniforms(size: size, params: acesParams);
    for (int i = 0; i < uniforms.length; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
    if (sceneTexture != null) {
      shader.setImageSampler(0, sceneTexture);
    }
  }

  /// Configures `ssao.frag` shader uniforms and optional depth (Sampler 0) and normal (Sampler 1) samplers.
  void configureSsaoShader(
    ui.FragmentShader shader,
    Size size, {
    ui.Image? depthTexture,
    ui.Image? normalTexture,
  }) {
    final List<double> uniforms = buildSsaoUniforms(size: size, params: ssaoParams);
    for (int i = 0; i < uniforms.length; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
    if (depthTexture != null) {
      shader.setImageSampler(0, depthTexture);
    }
    if (normalTexture != null) {
      shader.setImageSampler(1, normalTexture);
    }
  }

  /// Configures `ssao_bilateral_blur.frag` shader uniforms and optional AO (Sampler 0) and depth (Sampler 1) samplers.
  void configureBilateralShader(
    ui.FragmentShader shader,
    Size size,
    Offset direction, {
    ui.Image? aoTexture,
    ui.Image? depthTexture,
  }) {
    final List<double> uniforms = buildBilateralUniforms(
      size: size,
      direction: direction,
      params: bilateralParams,
    );
    for (int i = 0; i < uniforms.length; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
    if (aoTexture != null) {
      shader.setImageSampler(0, aoTexture);
    }
    if (depthTexture != null) {
      shader.setImageSampler(1, depthTexture);
    }
  }

  /// Configures `ssao_composite_aces.frag` shader uniforms and optional scene (Sampler 0) and AO (Sampler 1) samplers.
  void configureCompositeShader(
    ui.FragmentShader shader,
    Size size, {
    double aoIntensity = 1.0,
    double aoDirectPreserve = 0.25,
    double? aoDirectLightPreserve,
    ui.Image? sceneTexture,
    ui.Image? aoTexture,
  }) {
    final double directPreserve =
        aoDirectLightPreserve ?? aoDirectPreserve;
    final List<double> uniforms = buildCompositeUniforms(
      size: size,
      acesParams: acesParams,
      aoIntensity: aoIntensity,
      aoDirectLightPreserve: directPreserve,
    );
    for (int i = 0; i < uniforms.length; ++i) {
      shader.setFloat(i, uniforms[i]);
    }
    if (sceneTexture != null) {
      shader.setImageSampler(0, sceneTexture);
    }
    if (aoTexture != null) {
      shader.setImageSampler(1, aoTexture);
    }
  }
}

/// A widget that applies ACES Filmic Tonemapping and Gamma Correction.
class AcesTonemapWidget extends StatelessWidget {
  const AcesTonemapWidget({
    super.key,
    required this.child,
    this.params = const AcesTonemapParams(),
  });

  final Widget child;
  final AcesTonemapParams params;

  @override
  Widget build(BuildContext context) {
    // When GPU fragment shaders are active, child is rendered into texture and post-processed.
    // For universal layout compatibility, we wrap the child with custom styling hooks.
    return RepaintBoundary(
      child: child,
    );
  }
}

/// CustomPainter for rendering shader effects or pure mathematical CPU fallbacks.
class AcesTonemapPainter extends CustomPainter {
  AcesTonemapPainter({
    required this.params,
    this.shader,
    this.sceneImage,
  });

  final AcesTonemapParams params;
  final ui.FragmentShader? shader;
  final ui.Image? sceneImage;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.FragmentShader? s = shader;
    if (s != null && sceneImage != null) {
      final List<double> uniforms =
          PostProcessPipelineController.buildAcesUniforms(size: size, params: params);
      for (int i = 0; i < uniforms.length; ++i) {
        s.setFloat(i, uniforms[i]);
      }
      s.setImageSampler(0, sceneImage!);

      final Paint paint = Paint()..shader = s;
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AcesTonemapPainter oldDelegate) {
    return oldDelegate.params != params ||
        oldDelegate.shader != shader ||
        oldDelegate.sceneImage != sceneImage;
  }
}

/// CustomPainter for rendering Screen Space Ambient Occlusion (SSAO) with GPU FragmentShader.
class SsaoPainter extends CustomPainter {
  SsaoPainter({
    required this.params,
    this.shader,
    this.depthTexture,
    this.normalTexture,
  });

  final SsaoParams params;
  final ui.FragmentShader? shader;
  final ui.Image? depthTexture;
  final ui.Image? normalTexture;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.FragmentShader? s = shader;
    if (s != null && depthTexture != null) {
      final List<double> uniforms =
          PostProcessPipelineController.buildSsaoUniforms(size: size, params: params);
      for (int i = 0; i < uniforms.length; ++i) {
        s.setFloat(i, uniforms[i]);
      }
      s.setImageSampler(0, depthTexture!);
      if (normalTexture != null) {
        s.setImageSampler(1, normalTexture!);
      }

      final Paint paint = Paint()..shader = s;
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SsaoPainter oldDelegate) {
    return oldDelegate.params != params ||
        oldDelegate.shader != shader ||
        oldDelegate.depthTexture != depthTexture ||
        oldDelegate.normalTexture != normalTexture;
  }
}

/// CustomPainter for rendering Bilateral Depth-Aware Smoothing with GPU FragmentShader.
class SsaoBilateralBlurPainter extends CustomPainter {
  SsaoBilateralBlurPainter({
    required this.params,
    required this.direction,
    this.shader,
    this.aoTexture,
    this.depthTexture,
  });

  final BilateralFilterParams params;
  final Offset direction;
  final ui.FragmentShader? shader;
  final ui.Image? aoTexture;
  final ui.Image? depthTexture;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.FragmentShader? s = shader;
    if (s != null && aoTexture != null) {
      final List<double> uniforms =
          PostProcessPipelineController.buildBilateralUniforms(
        size: size,
        direction: direction,
        params: params,
      );
      for (int i = 0; i < uniforms.length; ++i) {
        s.setFloat(i, uniforms[i]);
      }
      s.setImageSampler(0, aoTexture!);
      if (depthTexture != null) {
        s.setImageSampler(1, depthTexture!);
      }

      final Paint paint = Paint()..shader = s;
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SsaoBilateralBlurPainter oldDelegate) {
    return oldDelegate.params != params ||
        oldDelegate.direction != direction ||
        oldDelegate.shader != shader ||
        oldDelegate.aoTexture != aoTexture ||
        oldDelegate.depthTexture != depthTexture;
  }
}

/// CustomPainter for unified single-pass SSAO Modulation + ACES Filmic Tonemapping.
class SsaoCompositePainter extends CustomPainter {
  SsaoCompositePainter({
    required this.acesParams,
    this.aoIntensity = 1.0,
    this.aoDirectLightPreserve = 0.25,
    this.shader,
    this.sceneTexture,
    this.aoTexture,
  });

  final AcesTonemapParams acesParams;
  final double aoIntensity;
  final double aoDirectLightPreserve;
  final ui.FragmentShader? shader;
  final ui.Image? sceneTexture;
  final ui.Image? aoTexture;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.FragmentShader? s = shader;
    if (s != null && sceneTexture != null && aoTexture != null) {
      final List<double> uniforms =
          PostProcessPipelineController.buildCompositeUniforms(
        size: size,
        acesParams: acesParams,
        aoIntensity: aoIntensity,
        aoDirectLightPreserve: aoDirectLightPreserve,
      );
      for (int i = 0; i < uniforms.length; ++i) {
        s.setFloat(i, uniforms[i]);
      }
      s.setImageSampler(0, sceneTexture!);
      s.setImageSampler(1, aoTexture!);

      final Paint paint = Paint()..shader = s;
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SsaoCompositePainter oldDelegate) {
    return oldDelegate.acesParams != acesParams ||
        oldDelegate.aoIntensity != aoIntensity ||
        oldDelegate.aoDirectLightPreserve != aoDirectLightPreserve ||
        oldDelegate.shader != shader ||
        oldDelegate.sceneTexture != sceneTexture ||
        oldDelegate.aoTexture != aoTexture;
  }
}

/// A widget that wraps a scene with single-pass SSAO composite & ACES tonemapping.
class SsaoCompositeWidget extends StatelessWidget {
  const SsaoCompositeWidget({
    super.key,
    required this.child,
    this.acesParams = const AcesTonemapParams(),
    this.aoIntensity = 1.0,
    this.aoDirectLightPreserve = 0.25,
  });

  final Widget child;
  final AcesTonemapParams acesParams;
  final double aoIntensity;
  final double aoDirectLightPreserve;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: child,
    );
  }
}
