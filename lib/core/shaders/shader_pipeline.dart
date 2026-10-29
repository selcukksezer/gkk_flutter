// =============================================================================
// Central Shader Pipeline & Material Registry: Shader Pipeline Implementation
// 2027 Cinematic AAA Graphics Pipeline (R5 Standards)
// =============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'shader_registry.dart';

/// Execution and compilation status of a shader within the pipeline.
enum ShaderStatus {
  /// Shader has been registered but not yet loaded.
  unloaded,

  /// Asset bundle or SPIR-V compilation currently in progress.
  loading,

  /// Shader compiled successfully into FragmentProgram or vertex text cache.
  compiled,

  /// Pipeline state object (PSO) primed via offscreen warm-up draw.
  warmedUp,

  /// GPU compilation or asset loading threw an error.
  failed,

  /// Safe fallback shader is actively serving requests in place of this shader.
  fallbackActive,
}

/// Target interface for uniform binding operations (supports FragmentShader & BufferUniformTarget).
abstract class ShaderUniformTarget {
  void setFloat(int index, double value);
  void setImageSampler(int index, ui.Image image);
}

/// Adapter allowing uniform binding directly onto a Flutter [ui.FragmentShader].
class FragmentShaderTarget implements ShaderUniformTarget {
  const FragmentShaderTarget(this.shader);
  final ui.FragmentShader shader;

  @override
  void setFloat(int index, double value) => shader.setFloat(index, value);

  @override
  void setImageSampler(int index, ui.Image image) =>
      shader.setImageSampler(index, image);
}

/// In-memory uniform target storing float buffer and samplers for testing and verification.
class BufferUniformTarget implements ShaderUniformTarget {
  final Map<int, double> floats = <int, double>{};
  final Map<int, ui.Image> samplers = <int, ui.Image>{};

  @override
  void setFloat(int index, double value) {
    floats[index] = value;
  }

  @override
  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }

  /// Retrieves float value at [index].
  double? getFloat(int index) => floats[index];

  /// Total count of assigned float slots.
  int get floatCount => floats.length;

  /// Total count of assigned texture sampler units.
  int get samplerCount => samplers.length;

  /// Exports stored floats into a contiguous list.
  List<double> toFloatList({int minLength = 0}) {
    if (floats.isEmpty) return List<double>.filled(minLength, 0.0);
    int maxKey = floats.keys.fold(0, (int a, int b) => a > b ? a : b);
    final int count = math.max(minLength, maxKey + 1);
    final List<double> result = List<double>.filled(count, 0.0);
    for (final MapEntry<int, double> entry in floats.entries) {
      if (entry.key < count) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
}

/// 3D Vector for camera, lights, and spatial shader coordinates.
class ShaderVector3 {
  const ShaderVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const ShaderVector3 zero = ShaderVector3(0.0, 0.0, 0.0);
  static const ShaderVector3 unitX = ShaderVector3(1.0, 0.0, 0.0);
  static const ShaderVector3 unitY = ShaderVector3(0.0, 1.0, 0.0);
  static const ShaderVector3 unitZ = ShaderVector3(0.0, 0.0, 1.0);

  List<double> toList() => <double>[x, y, z];

  @override
  String toString() => 'ShaderVector3($x, $y, $z)';
}

/// Point light parameters formatted for uniform buffers.
class ShaderPointLight {
  const ShaderPointLight({
    required this.position,
    required this.color,
    required this.radius,
    required this.intensity,
  });

  final ShaderVector3 position;
  final ShaderVector3 color;
  final double radius;
  final double intensity;

  /// Packs into 8 contiguous floats: (x, y, z, radius, r, g, b, intensity).
  List<double> toFloats() => <double>[
        position.x,
        position.y,
        position.z,
        radius,
        color.x,
        color.y,
        color.z,
        intensity,
      ];
}

/// Camera vectors and projection matrices passed to shaders.
class CameraUniforms {
  const CameraUniforms({
    this.position = ShaderVector3.zero,
    this.forward = ShaderVector3.unitZ,
    this.right = ShaderVector3.unitX,
    this.up = ShaderVector3.unitY,
    this.viewProjectionMatrix,
  });

  final ShaderVector3 position;
  final ShaderVector3 forward;
  final ShaderVector3 right;
  final ShaderVector3 up;
  final Float32List? viewProjectionMatrix;
}

/// Directional, ambient, and local light state for illumination shaders.
class LightUniforms {
  const LightUniforms({
    this.primaryDirection = const ShaderVector3(0.577, 0.577, 0.577),
    this.primaryColor = const ShaderVector3(1.0, 0.95, 0.8),
    this.ambientColor = const ShaderVector3(0.15, 0.18, 0.22),
    this.pointLights = const <ShaderPointLight>[],
  });

  final ShaderVector3 primaryDirection;
  final ShaderVector3 primaryColor;
  final ShaderVector3 ambientColor;
  final List<ShaderPointLight> pointLights;
}

/// Standard global scene uniforms passed to world, postprocess, and vfx shaders.
class GlobalSceneUniforms {
  const GlobalSceneUniforms({
    required this.time,
    required this.resolution,
    this.deltaTime = 0.016667,
    this.camera = const CameraUniforms(),
    this.lights = const LightUniforms(),
  });

  final double time;
  final double deltaTime;
  final ui.Size resolution;
  final CameraUniforms camera;
  final LightUniforms lights;
}

/// High-level binder mapping scene data, vectors, lights, and textures into uniforms.
class UniformBufferBinder {
  /// Sets a single float at [index] on a uniform target.
  static void bindFloat(ShaderUniformTarget target, int index, double value) {
    target.setFloat(index, value);
  }

  /// Sets a sequence of floats starting at [startIndex].
  static void bindFloats(
    ShaderUniformTarget target,
    int startIndex,
    List<double> values,
  ) {
    for (int i = 0; i < values.length; i++) {
      target.setFloat(startIndex + i, values[i]);
    }
  }

  /// Sets 2-component vector (width, height or x, y) at [offset].
  static void bindVec2(ShaderUniformTarget target, int offset, double x, double y) {
    target.setFloat(offset, x);
    target.setFloat(offset + 1, y);
  }

  /// Sets 3-component vector at [offset].
  static void bindVec3(
    ShaderUniformTarget target,
    int offset,
    double x,
    double y,
    double z,
  ) {
    target.setFloat(offset, x);
    target.setFloat(offset + 1, y);
    target.setFloat(offset + 2, z);
  }

  /// Sets 4-component vector at [offset].
  static void bindVec4(
    ShaderUniformTarget target,
    int offset,
    double x,
    double y,
    double z,
    double w,
  ) {
    target.setFloat(offset, x);
    target.setFloat(offset + 1, y);
    target.setFloat(offset + 2, z);
    target.setFloat(offset + 3, w);
  }

  /// Sets RGBA color at [offset].
  static void bindColor(
    ShaderUniformTarget target,
    int offset,
    ui.Color color, {
    bool includeAlpha = true,
  }) {
    target.setFloat(offset, color.r);
    target.setFloat(offset + 1, color.g);
    target.setFloat(offset + 2, color.b);
    if (includeAlpha) {
      target.setFloat(offset + 3, color.a);
    }
  }

  /// Sets a 4x4 column-major matrix (16 floats) at [offset].
  static void bindMatrix4(
    ShaderUniformTarget target,
    int offset,
    List<double> matrix16,
  ) {
    assert(
      matrix16.length >= 16,
      'Matrix4 uniform requires at least 16 float elements',
    );
    for (int i = 0; i < 16; i++) {
      target.setFloat(offset + i, matrix16[i]);
    }
  }

  /// Sets a texture sampler at [samplerIndex].
  static void bindSampler(
    ShaderUniformTarget target,
    int samplerIndex,
    ui.Image image,
  ) {
    target.setImageSampler(samplerIndex, image);
  }

  /// Binds standard resolution and time uniforms.
  static void bindStandardTimeAndResolution(
    ShaderUniformTarget target, {
    required ui.Size resolution,
    required double time,
    int resolutionOffset = 0,
    int timeOffset = 2,
  }) {
    bindVec2(target, resolutionOffset, resolution.width, resolution.height);
    bindFloat(target, timeOffset, time);
  }

  /// Binds comprehensive scene data (resolution, time, camera, lights) into a uniform target.
  static void bindSceneUniforms(
    ShaderUniformTarget target,
    GlobalSceneUniforms scene, {
    int offset = 0,
    bool includeCamera = true,
    bool includeLights = true,
  }) {
    // 0..1: Resolution (2 floats)
    bindVec2(target, offset, scene.resolution.width, scene.resolution.height);
    // 2: Time (1 float)
    bindFloat(target, offset + 2, scene.time);
    // 3: Delta Time (1 float)
    bindFloat(target, offset + 3, scene.deltaTime);

    int currentOffset = offset + 4;

    if (includeCamera) {
      // Camera Position (3 floats)
      bindVec3(
        target,
        currentOffset,
        scene.camera.position.x,
        scene.camera.position.y,
        scene.camera.position.z,
      );
      currentOffset += 3;

      // Camera Forward (3 floats)
      bindVec3(
        target,
        currentOffset,
        scene.camera.forward.x,
        scene.camera.forward.y,
        scene.camera.forward.z,
      );
      currentOffset += 3;
    }

    if (includeLights) {
      // Primary light dir (3 floats)
      bindVec3(
        target,
        currentOffset,
        scene.lights.primaryDirection.x,
        scene.lights.primaryDirection.y,
        scene.lights.primaryDirection.z,
      );
      currentOffset += 3;

      // Primary light color (3 floats)
      bindVec3(
        target,
        currentOffset,
        scene.lights.primaryColor.x,
        scene.lights.primaryColor.y,
        scene.lights.primaryColor.z,
      );
      currentOffset += 3;

      // Ambient color (3 floats)
      bindVec3(
        target,
        currentOffset,
        scene.lights.ambientColor.x,
        scene.lights.ambientColor.y,
        scene.lights.ambientColor.z,
      );
      currentOffset += 3;
    }
  }

  /// Binds properties according to a [ShaderDescriptor] declaration.
  static void bindByDescriptor(
    ShaderUniformTarget target,
    ShaderDescriptor descriptor,
    Map<String, dynamic> uniformValues,
  ) {
    for (final UniformDefinition u in descriptor.uniforms) {
      final dynamic value = uniformValues[u.name];
      if (value == null) {
        // Fall back to default value if declared
        if (u.defaultValue.isNotEmpty) {
          bindFloats(target, u.floatOffset, u.defaultValue);
        }
        continue;
      }

      if (value is double) {
        bindFloat(target, u.floatOffset, value);
      } else if (value is int) {
        bindFloat(target, u.floatOffset, value.toDouble());
      } else if (value is List<double>) {
        bindFloats(target, u.floatOffset, value);
      } else if (value is ui.Size) {
        bindVec2(target, u.floatOffset, value.width, value.height);
      } else if (value is ShaderVector3) {
        bindVec3(target, u.floatOffset, value.x, value.y, value.z);
      } else if (value is ui.Color) {
        bindColor(target, u.floatOffset, value, includeAlpha: u.floatCount >= 4);
      }
    }
  }
}

/// Convenience extension on Flutter [ui.FragmentShader] for uniform binding.
extension FragmentShaderBindingExtension on ui.FragmentShader {
  /// Converts this shader into a [ShaderUniformTarget].
  FragmentShaderTarget asTarget() => FragmentShaderTarget(this);

  /// Binds a 2-component vector (x, y).
  void bindVec2(int offset, double x, double y) =>
      UniformBufferBinder.bindVec2(asTarget(), offset, x, y);

  /// Binds a 3-component vector (x, y, z).
  void bindVec3(int offset, double x, double y, double z) =>
      UniformBufferBinder.bindVec3(asTarget(), offset, x, y, z);

  /// Binds a 4-component vector (x, y, z, w).
  void bindVec4(int offset, double x, double y, double z, double w) =>
      UniformBufferBinder.bindVec4(asTarget(), offset, x, y, z, w);

  /// Binds a Color.
  void bindColor(int offset, ui.Color color, {bool includeAlpha = true}) =>
      UniformBufferBinder.bindColor(asTarget(), offset, color, includeAlpha: includeAlpha);

  /// Binds global scene uniforms.
  void bindSceneUniforms(GlobalSceneUniforms scene, {int offset = 0}) =>
      UniformBufferBinder.bindSceneUniforms(asTarget(), scene, offset: offset);

  /// Binds uniform map values by descriptor.
  void bindByDescriptor(ShaderDescriptor descriptor, Map<String, dynamic> values) =>
      UniformBufferBinder.bindByDescriptor(asTarget(), descriptor, values);
}

/// Abstract loader allowing decoupled asset loading for production and unit testing.
abstract class ShaderAssetLoader {
  /// Loads and compiles a fragment shader asset into a Flutter [ui.FragmentProgram].
  Future<ui.FragmentProgram> loadFragmentProgram(String assetPath);

  /// Loads raw shader source code (e.g. GLSL vertex shaders).
  Future<String> loadShaderSource(String assetPath);
}

/// Production implementation using Flutter's [ui.FragmentProgram] and [rootBundle].
class FlutterShaderAssetLoader implements ShaderAssetLoader {
  const FlutterShaderAssetLoader();

  @override
  Future<ui.FragmentProgram> loadFragmentProgram(String assetPath) {
    return ui.FragmentProgram.fromAsset(assetPath);
  }

  @override
  Future<String> loadShaderSource(String assetPath) {
    return rootBundle.loadString(assetPath);
  }
}

/// Represents a compiled and cached shader in the pipeline.
class CompiledShader {
  CompiledShader({
    required this.descriptor,
    this.program,
    this.sourceCode,
    this.status = ShaderStatus.unloaded,
    this.compilationTimeMs = 0.0,
    this.warmupTimeMs = 0.0,
    this.lastError,
    this.fallbackShader,
  });

  /// Associated shader descriptor.
  final ShaderDescriptor descriptor;

  /// Compiled runtime FragmentProgram (for fragment shaders).
  ui.FragmentProgram? program;

  /// Raw shader source code (for vertex/compute shaders).
  String? sourceCode;

  /// Current pipeline state.
  ShaderStatus status;

  /// Wall-clock time spent in GPU compilation.
  double compilationTimeMs;

  /// Wall-clock time spent during pipeline warm-up.
  double warmupTimeMs;

  /// Error message if compilation or loading failed.
  String? lastError;

  /// Reference to compiled fallback shader if active.
  CompiledShader? fallbackShader;

  /// Total number of FragmentShader instances requested from this program.
  int instanceCount = 0;

  /// Whether this shader is compiled or warmed up and ready for use.
  bool get isReady =>
      status == ShaderStatus.compiled ||
      status == ShaderStatus.warmedUp ||
      (status == ShaderStatus.fallbackActive &&
          fallbackShader != null &&
          fallbackShader!.isReady);

  /// Instantiates a new [ui.FragmentShader] runtime instance.
  /// If fallback is active, creates the fallback shader instead.
  ui.FragmentShader? createShader() {
    if (status == ShaderStatus.fallbackActive && fallbackShader != null) {
      return fallbackShader!.createShader();
    }
    if (program != null) {
      instanceCount++;
      return program!.fragmentShader();
    }
    return null;
  }

  @override
  String toString() =>
      'CompiledShader(${descriptor.id}, status: $status, instances: $instanceCount)';
}

/// Summary metrics of the shader pipeline.
class ShaderPipelineStats {
  const ShaderPipelineStats({
    required this.totalRegistered,
    required this.totalCompiled,
    required this.totalWarmedUp,
    required this.totalFailed,
    required this.totalFallbacksActive,
    required this.averageCompilationTimeMs,
    required this.totalWarmupTimeMs,
    required this.deviceTier,
  });

  final int totalRegistered;
  final int totalCompiled;
  final int totalWarmedUp;
  final int totalFailed;
  final int totalFallbacksActive;
  final double averageCompilationTimeMs;
  final double totalWarmupTimeMs;
  final DevicePerformanceTier deviceTier;

  /// Generates human-readable diagnostics report.
  String generateReport() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('=== GKK Central Shader Pipeline Diagnostics ===');
    sb.writeln('Device Performance Tier: $deviceTier');
    sb.writeln('Total Registered: $totalRegistered');
    sb.writeln('Successfully Compiled: $totalCompiled');
    sb.writeln('Warm-up Completed: $totalWarmedUp');
    sb.writeln('Compilation Failures: $totalFailed');
    sb.writeln('Active Fallbacks: $totalFallbacksActive');
    sb.writeln(
      'Avg Compilation Time: ${averageCompilationTimeMs.toStringAsFixed(2)} ms',
    );
    sb.writeln(
      'Total Warm-up Duration: ${totalWarmupTimeMs.toStringAsFixed(2)} ms',
    );
    return sb.toString();
  }
}

/// Configuration settings for the central shader pipeline.
class ShaderPipelineConfig {
  const ShaderPipelineConfig({
    this.deviceTier = DevicePerformanceTier.high,
    this.enableWarmup = true,
    this.enableFallbacks = true,
    this.maxConcurrentLoads = 4,
    this.autoPreloadPostprocess = true,
  });

  /// Hardware performance tier.
  final DevicePerformanceTier deviceTier;

  /// Whether to perform offscreen PSO warm-up passes after compilation.
  final bool enableWarmup;

  /// Whether to route to fallbacks when compilation fails or tier is low.
  final bool enableFallbacks;

  /// Max concurrent asset loading operations.
  final int maxConcurrentLoads;

  /// Whether to automatically preload postprocess shaders on init.
  final bool autoPreloadPostprocess;
}

/// Central Shader Pipeline managing compilation, caching, warm-up, uniform binding, and fallbacks.
class ShaderPipeline {
  ShaderPipeline({
    ShaderRegistry? registry,
    ShaderAssetLoader? assetLoader,
    ShaderPipelineConfig? config,
  })  : registry = registry ?? ShaderRegistry(),
        assetLoader = assetLoader ?? const FlutterShaderAssetLoader(),
        config = config ?? const ShaderPipelineConfig();

  /// Central material and shader registry.
  final ShaderRegistry registry;

  /// Asset loading interface.
  final ShaderAssetLoader assetLoader;

  /// Configuration and device tier parameters.
  final ShaderPipelineConfig config;

  final Map<String, CompiledShader> _compiledShaders =
      <String, CompiledShader>{};
  final Map<String, Completer<CompiledShader>> _pendingLoads =
      <String, Completer<CompiledShader>>{};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Total count of compiled and cached shaders.
  int get compiledCount => _compiledShaders.length;

  /// Device performance tier in use.
  DevicePerformanceTier get deviceTier => config.deviceTier;

  // ---------------------------------------------------------------------------
  // Lifecycle & Initialization
  // ---------------------------------------------------------------------------

  /// Initializes the pipeline and preloads critical shaders.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (config.autoPreloadPostprocess) {
      await preloadCategory(ShaderCategory.postprocess);
    }

    _isInitialized = true;
  }

  // ---------------------------------------------------------------------------
  // Shader Loading & Compilation
  // ---------------------------------------------------------------------------

  /// Asynchronously loads, compiles, and optionally warms up a shader by ID.
  Future<CompiledShader> loadShader(String shaderId) async {
    // 1. Check if already compiled or being loaded
    if (_compiledShaders.containsKey(shaderId)) {
      return _compiledShaders[shaderId]!;
    }

    if (_pendingLoads.containsKey(shaderId)) {
      return _pendingLoads[shaderId]!.future;
    }

    final Completer<CompiledShader> completer = Completer<CompiledShader>();
    _pendingLoads[shaderId] = completer;

    final ShaderDescriptor? descriptor = registry.getShaderDescriptor(shaderId);
    if (descriptor == null) {
      final CompiledShader notFoundShader = CompiledShader(
        descriptor: ShaderDescriptor(
          id: shaderId,
          assetPath: shaderId,
          category: ShaderCategory.postprocess,
          stage: ShaderStage.fragment,
        ),
        status: ShaderStatus.failed,
        lastError: 'Shader $shaderId not registered in ShaderRegistry',
      );
      _compiledShaders[shaderId] = notFoundShader;
      completer.complete(notFoundShader);
      _pendingLoads.remove(shaderId);
      return notFoundShader;
    }

    // 2. Check Device Performance Tier Constraint
    if (config.enableFallbacks &&
        !config.deviceTier.satisfies(descriptor.minPerformanceTier)) {
      final CompiledShader fallback = await _resolveTierFallback(descriptor);
      _compiledShaders[shaderId] = fallback;
      completer.complete(fallback);
      _pendingLoads.remove(shaderId);
      return fallback;
    }

    final Stopwatch stopwatch = Stopwatch()..start();
    final CompiledShader compiled = CompiledShader(
      descriptor: descriptor,
      status: ShaderStatus.loading,
    );

    try {
      if (descriptor.stage == ShaderStage.fragment) {
        final ui.FragmentProgram program =
            await assetLoader.loadFragmentProgram(descriptor.assetPath);
        stopwatch.stop();

        compiled.program = program;
        compiled.status = ShaderStatus.compiled;
        compiled.compilationTimeMs = stopwatch.elapsedMicroseconds / 1000.0;

        // Perform warm-up if enabled
        if (config.enableWarmup) {
          await warmUpShader(compiled);
        }
      } else {
        // Vertex or other source-based shader
        final String source =
            await assetLoader.loadShaderSource(descriptor.assetPath);
        stopwatch.stop();

        compiled.sourceCode = source;
        compiled.status = ShaderStatus.compiled;
        compiled.compilationTimeMs = stopwatch.elapsedMicroseconds / 1000.0;
      }

      _compiledShaders[shaderId] = compiled;
      completer.complete(compiled);
    } catch (e, stackTrace) {
      stopwatch.stop();
      compiled.status = ShaderStatus.failed;
      compiled.lastError = 'Compilation failed for $shaderId: $e\n$stackTrace';

      // 3. Fallback on Compilation Failure
      if (config.enableFallbacks) {
        final CompiledShader fallback = await _resolveCompilationFallback(
          compiled,
        );
        _compiledShaders[shaderId] = fallback;
        completer.complete(fallback);
      } else {
        _compiledShaders[shaderId] = compiled;
        completer.complete(compiled);
      }
    } finally {
      _pendingLoads.remove(shaderId);
    }

    return completer.future;
  }

  /// Preloads all shaders in a specific category concurrently.
  Future<List<CompiledShader>> preloadCategory(ShaderCategory category) async {
    final List<ShaderDescriptor> descriptors =
        registry.getDescriptorsByCategory(category);
    final List<Future<CompiledShader>> futures = descriptors
        .map((ShaderDescriptor d) => loadShader(d.id))
        .toList();
    return Future.wait(futures);
  }

  /// Preloads all registered shaders with an optional progress callback in [0.0, 1.0].
  Future<List<CompiledShader>> preloadAll({
    void Function(double progress)? onProgress,
  }) async {
    final List<ShaderDescriptor> all = registry.getAllDescriptors();
    final List<CompiledShader> results = <CompiledShader>[];
    int completed = 0;

    for (final ShaderDescriptor desc in all) {
      final CompiledShader loaded = await loadShader(desc.id);
      results.add(loaded);
      completed++;
      if (onProgress != null && all.isNotEmpty) {
        onProgress(completed / all.length);
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Warm-Up System
  // ---------------------------------------------------------------------------

  /// Primes the GPU pipeline state object (PSO) cache by executing a warm-up pass.
  Future<void> warmUpShader(CompiledShader compiled) async {
    if (compiled.program == null) return;

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final ui.FragmentShader shader = compiled.program!.fragmentShader();
      final ShaderDescriptor desc = compiled.descriptor;

      // 1. Bind warm-up uniform floats
      if (desc.warmupParameters != null && desc.warmupParameters!.isNotEmpty) {
        UniformBufferBinder.bindFloats(
          shader.asTarget(),
          0,
          desc.warmupParameters!,
        );
      } else {
        // Fallback: fill defaults from declared uniforms
        for (final UniformDefinition u in desc.uniforms) {
          if (u.defaultValue.isNotEmpty) {
            UniformBufferBinder.bindFloats(
              shader.asTarget(),
              u.floatOffset,
              u.defaultValue,
            );
          } else {
            for (int i = 0; i < u.floatCount; i++) {
              shader.setFloat(u.floatOffset + i, 1.0);
            }
          }
        }
      }

      // 2. Offscreen warm-up rasterization on PictureRecorder
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      final ui.Paint paint = ui.Paint()..shader = shader;
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), paint);
      final ui.Picture picture = recorder.endRecording();
      picture.dispose();

      stopwatch.stop();
      compiled.warmupTimeMs = stopwatch.elapsedMicroseconds / 1000.0;
      compiled.status = ShaderStatus.warmedUp;
    } catch (e) {
      stopwatch.stop();
      // Non-fatal: mark as compiled even if warm-up had warning
      compiled.status = ShaderStatus.compiled;
      compiled.lastError = 'Warm-up warning: $e';
    }
  }

  /// Warms up a uniform target using descriptor parameters for pipeline verification.
  void warmUpTarget(ShaderUniformTarget target, ShaderDescriptor descriptor) {
    if (descriptor.warmupParameters != null &&
        descriptor.warmupParameters!.isNotEmpty) {
      UniformBufferBinder.bindFloats(target, 0, descriptor.warmupParameters!);
    } else {
      for (final UniformDefinition u in descriptor.uniforms) {
        if (u.defaultValue.isNotEmpty) {
          UniformBufferBinder.bindFloats(target, u.floatOffset, u.defaultValue);
        } else {
          for (int i = 0; i < u.floatCount; i++) {
            target.setFloat(u.floatOffset + i, 1.0);
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Safe Fallback Resolution
  // ---------------------------------------------------------------------------

  /// Resolves fallback when device performance tier does not satisfy requirements.
  Future<CompiledShader> _resolveTierFallback(
    ShaderDescriptor descriptor,
  ) async {
    if (descriptor.fallbackId != null) {
      final CompiledShader fallbackCompiled =
          await loadShader(descriptor.fallbackId!);
      return CompiledShader(
        descriptor: descriptor,
        status: ShaderStatus.fallbackActive,
        fallbackShader: fallbackCompiled,
        lastError:
            'Downgraded due to device tier ($deviceTier < ${descriptor.minPerformanceTier})',
      );
    }

    return CompiledShader(
      descriptor: descriptor,
      status: ShaderStatus.fallbackActive,
      lastError:
          'Bypassed due to device tier ($deviceTier < ${descriptor.minPerformanceTier})',
    );
  }

  /// Resolves fallback when GPU compilation throws an exception.
  Future<CompiledShader> _resolveCompilationFallback(
    CompiledShader failedShader,
  ) async {
    final ShaderDescriptor descriptor = failedShader.descriptor;
    if (descriptor.fallbackId != null) {
      try {
        final CompiledShader fallbackCompiled =
            await loadShader(descriptor.fallbackId!);
        return CompiledShader(
          descriptor: descriptor,
          status: ShaderStatus.fallbackActive,
          fallbackShader: fallbackCompiled,
          lastError:
              'Compilation error; fell back to ${descriptor.fallbackId}: ${failedShader.lastError}',
        );
      } catch (e) {
        // Both failed
        return failedShader;
      }
    }

    return failedShader;
  }

  // ---------------------------------------------------------------------------
  // Shader Access & Instantiation
  // ---------------------------------------------------------------------------

  /// Obtains a new [ui.FragmentShader] instance for rendering, resolving fallbacks safely.
  ui.FragmentShader? getShader(String shaderId) {
    final CompiledShader? compiled = _compiledShaders[shaderId];
    if (compiled == null || !compiled.isReady) {
      return null;
    }
    return compiled.createShader();
  }

  /// Checks if a shader is loaded and ready for rendering.
  bool isShaderReady(String shaderId) {
    final CompiledShader? compiled = _compiledShaders[shaderId];
    return compiled != null && compiled.isReady;
  }

  /// Checks if a shader is currently running through a fallback.
  bool isFallbackActive(String shaderId) {
    final CompiledShader? compiled = _compiledShaders[shaderId];
    return compiled != null && compiled.status == ShaderStatus.fallbackActive;
  }

  /// Returns the cached [CompiledShader] object.
  CompiledShader? getCompiledShader(String shaderId) =>
      _compiledShaders[shaderId];

  // ---------------------------------------------------------------------------
  // Diagnostics & Telemetry
  // ---------------------------------------------------------------------------

  /// Calculates real-time pipeline performance and memory metrics.
  ShaderPipelineStats getPipelineStats() {
    int totalCompiled = 0;
    int totalWarmedUp = 0;
    int totalFailed = 0;
    int totalFallbacks = 0;
    double totalCompileTime = 0.0;
    double totalWarmupTime = 0.0;

    for (final CompiledShader s in _compiledShaders.values) {
      if (s.status == ShaderStatus.compiled || s.status == ShaderStatus.warmedUp) {
        totalCompiled++;
      }
      if (s.status == ShaderStatus.warmedUp) {
        totalWarmedUp++;
      }
      if (s.status == ShaderStatus.failed) {
        totalFailed++;
      }
      if (s.status == ShaderStatus.fallbackActive) {
        totalFallbacks++;
      }
      totalCompileTime += s.compilationTimeMs;
      totalWarmupTime += s.warmupTimeMs;
    }

    final double avgCompile = totalCompiled > 0
        ? totalCompileTime / totalCompiled
        : 0.0;

    return ShaderPipelineStats(
      totalRegistered: registry.shaderCount,
      totalCompiled: totalCompiled,
      totalWarmedUp: totalWarmedUp,
      totalFailed: totalFailed,
      totalFallbacksActive: totalFallbacks,
      averageCompilationTimeMs: avgCompile,
      totalWarmupTimeMs: totalWarmupTime,
      deviceTier: config.deviceTier,
    );
  }

  /// Cleans up and clears all shader instances and caches.
  void dispose() {
    _compiledShaders.clear();
    _pendingLoads.clear();
    _isInitialized = false;
  }
}
