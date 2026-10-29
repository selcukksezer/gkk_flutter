import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';

/// Test mock loader allowing precise simulation of successful and failing loads.
class MockShaderAssetLoader implements ShaderAssetLoader {
  MockShaderAssetLoader({
    this.failProgramPaths = const <String>{},
    this.failSourcePaths = const <String>{},
    this.sourceData = const <String, String>{},
  });

  final Set<String> failProgramPaths;
  final Set<String> failSourcePaths;
  final Map<String, String> sourceData;

  int programLoadAttempts = 0;
  int sourceLoadAttempts = 0;

  @override
  Future<ui.FragmentProgram> loadFragmentProgram(String assetPath) async {
    programLoadAttempts++;
    if (failProgramPaths.contains(assetPath)) {
      throw Exception('Simulated GPU driver compilation failure for $assetPath');
    }
    // In headless test runner, ui.FragmentProgram.fromAsset throws PlatformException / AssetNotFound
    return ui.FragmentProgram.fromAsset(assetPath);
  }

  @override
  Future<String> loadShaderSource(String assetPath) async {
    sourceLoadAttempts++;
    if (failSourcePaths.contains(assetPath)) {
      throw Exception('Simulated asset bundle missing for $assetPath');
    }
    return sourceData[assetPath] ??
        '// GLSL 460 Shader Source for $assetPath\nvoid main() {}';
  }
}

void main() {
  group('Shader Pipeline & Uniform Target Tests', () {
    test('BufferUniformTarget stores floats and queries accurately', () {
      final BufferUniformTarget target = BufferUniformTarget();
      target.setFloat(0, 1920.0);
      target.setFloat(1, 1080.0);
      target.setFloat(2, 0.016);

      expect(target.floats[0], equals(1920.0));
      expect(target.floats[1], equals(1080.0));
      expect(target.floats[2], equals(0.016));
      expect(target.floats.length, equals(3));
    });

    test('ShaderRegistry initializes with default AAA shader catalog', () {
      final ShaderRegistry registry = ShaderRegistry(loadDefaults: true);
      expect(registry.shaderCount, greaterThan(10));
      expect(registry.descriptors.length, greaterThan(10));

      final ShaderDescriptor? acesDesc = registry.getShader('aces_tonemap') ??
          registry.getShaderDescriptor(ShaderCatalog.acesTonemap);
      expect(acesDesc, isNotNull);
      expect(acesDesc!.category, equals(ShaderCategory.postprocess));
      expect(acesDesc.assetPath, contains('aces_tonemap.frag'));

      final ShaderDescriptor? ssaoDesc = registry.getShader('ssao') ??
          registry.getShaderDescriptor(ShaderCatalog.ssao);
      expect(ssaoDesc, isNotNull);
      expect(ssaoDesc!.category, equals(ShaderCategory.postprocess));

      final ShaderDescriptor? crowdDesc = registry.getShader('vat_crowd') ??
          registry.getShaderDescriptor(ShaderCatalog.vatCrowdFrag);
      expect(crowdDesc, isNotNull);
      expect(crowdDesc!.category, equals(ShaderCategory.crowd));
    });

    test('ShaderRegistry filters shaders by category and device tier', () {
      final ShaderRegistry registry = ShaderRegistry(loadDefaults: true);

      final List<ShaderDescriptor> postShaders =
          registry.getByCategory(ShaderCategory.postprocess);
      expect(postShaders, isNotEmpty);
      expect(
        postShaders.every((ShaderDescriptor s) => s.category == ShaderCategory.postprocess),
        isTrue,
      );

      final List<ShaderDescriptor> vfxShaders =
          registry.getByCategory(ShaderCategory.vfx);
      expect(vfxShaders, isNotEmpty);
      expect(
        vfxShaders.every((ShaderDescriptor s) => s.category == ShaderCategory.vfx),
        isTrue,
      );
    });
  });

  group('Shader Registry Detailed Specifications', () {
    late ShaderRegistry registry;

    setUp(() {
      registry = ShaderRegistry(loadDefaults: true);
    });

    test('Default registry initializes all 16 built-in shaders across 5 categories', () {
      expect(registry.shaderCount, equals(16));

      final List<ShaderDescriptor> postprocess =
          registry.getDescriptorsByCategory(ShaderCategory.postprocess);
      final List<ShaderDescriptor> lighting =
          registry.getDescriptorsByCategory(ShaderCategory.lighting);
      final List<ShaderDescriptor> vfx =
          registry.getDescriptorsByCategory(ShaderCategory.vfx);
      final List<ShaderDescriptor> crowd =
          registry.getDescriptorsByCategory(ShaderCategory.crowd);
      final List<ShaderDescriptor> world =
          registry.getDescriptorsByCategory(ShaderCategory.world);

      expect(postprocess.length, equals(4)); // aces, ssao, blur, composite
      expect(lighting.length, equals(1)); // dungeon_lighting
      expect(vfx.length, equals(5)); // particles, decal, trail, rim flash, shockwave
      expect(crowd.length, equals(3)); // vat frag, vat vert, instancing vert
      expect(world.length, equals(3)); // wind, puddle, fog
    });

    test('Shader descriptors define accurate uniform offsets, counts, and samplers', () {
      // 1. ACES Tonemap
      final ShaderDescriptor? aces =
          registry.getShaderDescriptor(ShaderCatalog.acesTonemap);
      expect(aces, isNotNull);
      expect(aces!.category, equals(ShaderCategory.postprocess));
      expect(aces.stage, equals(ShaderStage.fragment));
      expect(aces.totalFloatCount, equals(8));
      expect(aces.totalSamplerCount, equals(1));
      expect(aces.findUniform('uResolution'), isNotNull);
      expect(aces.findUniform('uExposure')!.floatOffset, equals(2));
      expect(aces.findSampler('uSceneTexture')!.samplerIndex, equals(0));

      // 2. SSAO
      final ShaderDescriptor? ssao =
          registry.getShaderDescriptor(ShaderCatalog.ssao);
      expect(ssao, isNotNull);
      expect(ssao!.totalFloatCount, equals(9));
      expect(ssao.totalSamplerCount, equals(2));
      expect(ssao.findSampler('uDepthTexture')!.samplerIndex, equals(0));
      expect(ssao.findSampler('uNormalTexture')!.samplerIndex, equals(1));

      // 3. GPU Particles
      final ShaderDescriptor? particles =
          registry.getShaderDescriptor(ShaderCatalog.gpuParticles);
      expect(particles, isNotNull);
      expect(particles!.totalFloatCount, equals(24));
      expect(particles.findUniform('uBounds')!.floatCount, equals(4));
      expect(particles.findUniform('uBounds')!.floatOffset, equals(3));

      // 4. Ground Decal
      final ShaderDescriptor? decal =
          registry.getShaderDescriptor(ShaderCatalog.groundDecal);
      expect(decal, isNotNull);
      expect(decal!.totalFloatCount, equals(26));
      expect(decal.totalSamplerCount, equals(3));
      expect(decal.findSampler('uGroundTexture'), isNotNull);
      expect(decal.findSampler('uDecalTexture'), isNotNull);
      expect(decal.findSampler('uNormalTexture'), isNotNull);

      // 5. Crowd VAT Vertex
      final ShaderDescriptor? vatVert =
          registry.getShaderDescriptor(ShaderCatalog.vatCrowdVert);
      expect(vatVert, isNotNull);
      expect(vatVert!.stage, equals(ShaderStage.vertex));
      expect(vatVert.findUniform('uViewProjection')!.type, equals(UniformType.mat4));
      expect(vatVert.findUniform('uViewProjection')!.floatCount, equals(16));
    });

    test('Dynamic shader registration and unregistration operates correctly', () {
      const ShaderDescriptor custom = ShaderDescriptor(
        id: 'custom/bloom_threshold',
        assetPath: 'shaders/postprocess/bloom_threshold.frag',
        category: ShaderCategory.postprocess,
        stage: ShaderStage.fragment,
        uniforms: <UniformDefinition>[
          UniformDefinition(
            name: 'uThreshold',
            type: UniformType.float,
            floatOffset: 0,
            floatCount: 1,
            defaultValue: <double>[0.8],
          ),
        ],
      );

      registry.registerShader(custom);
      expect(registry.containsShader('custom/bloom_threshold'), isTrue);
      expect(registry.getShaderDescriptor('custom/bloom_threshold'), equals(custom));
      expect(registry.shaderCount, equals(17));

      final bool removed = registry.unregisterShader('custom/bloom_threshold');
      expect(removed, isTrue);
      expect(registry.containsShader('custom/bloom_threshold'), isFalse);
      expect(registry.shaderCount, equals(16));
    });

    test('Material registry indexes default AAA dark fantasy materials', () {
      expect(registry.materialCount, greaterThanOrEqualTo(8));

      final MaterialDescriptor? acesMat =
          registry.getMaterial('mat_postprocess_aces');
      expect(acesMat, isNotNull);
      expect(acesMat!.shaderId, equals(ShaderCatalog.acesTonemap));
      expect(acesMat.properties['uExposure'], equals(1.0));

      final MaterialDescriptor? trailMat =
          registry.getMaterial('mat_sword_blade_trail');
      expect(trailMat, isNotNull);
      expect(trailMat!.category, equals(ShaderCategory.vfx));
      expect(trailMat.isTransparent, isTrue);

      final List<MaterialDescriptor> vfxMats =
          registry.getMaterialsByCategory(ShaderCategory.vfx);
      expect(vfxMats.length, greaterThanOrEqualTo(4));

      final List<MaterialDescriptor> crowdMats =
          registry.getMaterialsByShaderId(ShaderCatalog.vatCrowdFrag);
      expect(crowdMats.isNotEmpty, isTrue);
      expect(crowdMats.first.materialId, equals('mat_crowd_skeleton_warrior'));
    });

    test('Material cloning with copyWith overrides properties cleanly', () {
      final MaterialDescriptor? base =
          registry.getMaterial('mat_sword_blade_trail');
      expect(base, isNotNull);

      final MaterialDescriptor boosted = base!.copyWith(
        materialId: 'mat_sword_blade_trail_legendary',
        properties: <String, double>{
          ...base.properties,
          'uGlowIntensity': 10.0,
        },
      );

      expect(boosted.materialId, equals('mat_sword_blade_trail_legendary'));
      expect(boosted.properties['uGlowIntensity'], equals(10.0));
      expect(boosted.shaderId, equals(base.shaderId));
      expect(boosted.isTransparent, equals(base.isTransparent));
    });
  });

  group('UniformBufferBinder Tests', () {
    late BufferUniformTarget target;

    setUp(() {
      target = BufferUniformTarget();
    });

    test('Basic numeric uniform binding sets exact indices', () {
      UniformBufferBinder.bindFloat(target, 0, 1.25);
      UniformBufferBinder.bindFloats(target, 1, <double>[2.0, 3.0, 4.0]);
      UniformBufferBinder.bindVec2(target, 4, 1920.0, 1080.0);
      UniformBufferBinder.bindVec3(target, 6, 0.5, 1.0, 1.5);
      UniformBufferBinder.bindVec4(target, 9, 0.1, 0.2, 0.3, 0.4);

      expect(target.getFloat(0), closeTo(1.25, 1e-6));
      expect(target.getFloat(1), closeTo(2.0, 1e-6));
      expect(target.getFloat(2), closeTo(3.0, 1e-6));
      expect(target.getFloat(3), closeTo(4.0, 1e-6));
      expect(target.getFloat(4), closeTo(1920.0, 1e-6));
      expect(target.getFloat(5), closeTo(1080.0, 1e-6));
      expect(target.getFloat(6), closeTo(0.5, 1e-6));
      expect(target.getFloat(7), closeTo(1.0, 1e-6));
      expect(target.getFloat(8), closeTo(1.5, 1e-6));
      expect(target.getFloat(9), closeTo(0.1, 1e-6));
      expect(target.getFloat(10), closeTo(0.2, 1e-6));
      expect(target.getFloat(11), closeTo(0.3, 1e-6));
      expect(target.getFloat(12), closeTo(0.4, 1e-6));
    });

    test('Color binding with and without alpha', () {
      const ui.Color col = ui.Color(0xFF336699);
      UniformBufferBinder.bindColor(target, 0, col, includeAlpha: true);
      expect(target.getFloat(0), closeTo(col.r, 1e-4));
      expect(target.getFloat(1), closeTo(col.g, 1e-4));
      expect(target.getFloat(2), closeTo(col.b, 1e-4));
      expect(target.getFloat(3), closeTo(col.a, 1e-4));

      UniformBufferBinder.bindColor(target, 4, col, includeAlpha: false);
      expect(target.getFloat(4), closeTo(col.r, 1e-4));
      expect(target.getFloat(5), closeTo(col.g, 1e-4));
      expect(target.getFloat(6), closeTo(col.b, 1e-4));
      expect(target.getFloat(7), isNull);
    });

    test('Matrix4 uniform binding writes 16 consecutive floats', () {
      final List<double> identityMat = <double>[
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
      ];
      UniformBufferBinder.bindMatrix4(target, 10, identityMat);

      for (int i = 0; i < 16; i++) {
        expect(target.getFloat(10 + i), equals(identityMat[i]));
      }
    });

    test('bindSceneUniforms writes complete camera, light, and resolution data', () {
      const GlobalSceneUniforms scene = GlobalSceneUniforms(
        time: 15.5,
        deltaTime: 0.016,
        resolution: ui.Size(1280.0, 720.0),
        camera: CameraUniforms(
          position: ShaderVector3(10.0, 20.0, 30.0),
          forward: ShaderVector3(0.0, 0.0, 1.0),
        ),
        lights: LightUniforms(
          primaryDirection: ShaderVector3(0.707, 0.707, 0.0),
          primaryColor: ShaderVector3(1.0, 0.9, 0.8),
          ambientColor: ShaderVector3(0.1, 0.1, 0.2),
        ),
      );

      UniformBufferBinder.bindSceneUniforms(target, scene, offset: 0);

      // Resolution & Time
      expect(target.getFloat(0), equals(1280.0));
      expect(target.getFloat(1), equals(720.0));
      expect(target.getFloat(2), equals(15.5));
      expect(target.getFloat(3), equals(0.016));

      // Camera Position (offset 4..6)
      expect(target.getFloat(4), equals(10.0));
      expect(target.getFloat(5), equals(20.0));
      expect(target.getFloat(6), equals(30.0));

      // Camera Forward (offset 7..9)
      expect(target.getFloat(7), equals(0.0));
      expect(target.getFloat(8), equals(0.0));
      expect(target.getFloat(9), equals(1.0));

      // Light Primary Direction (offset 10..12)
      expect(target.getFloat(10), closeTo(0.707, 1e-4));
      expect(target.getFloat(11), closeTo(0.707, 1e-4));
      expect(target.getFloat(12), equals(0.0));

      // Light Primary Color (offset 13..15)
      expect(target.getFloat(13), equals(1.0));
      expect(target.getFloat(14), equals(0.9));
      expect(target.getFloat(15), equals(0.8));

      // Light Ambient Color (offset 16..18)
      expect(target.getFloat(16), equals(0.1));
      expect(target.getFloat(17), equals(0.1));
      expect(target.getFloat(18), equals(0.2));
    });

    test('bindByDescriptor maps values to declared GLSL uniform offsets', () {
      final ShaderRegistry reg = ShaderRegistry(loadDefaults: true);
      final ShaderDescriptor acesDesc =
          reg.getShaderDescriptor(ShaderCatalog.acesTonemap)!;

      final Map<String, dynamic> params = <String, dynamic>{
        'uResolution': const ui.Size(2560.0, 1440.0),
        'uExposure': 1.85,
        'uExposureMode': 1.0,
        'uFitType': 1.0,
        'uGammaMode': 0.0,
        'uPreGain': 1.2,
        'uWhitePoint': 0.95,
      };

      UniformBufferBinder.bindByDescriptor(target, acesDesc, params);

      expect(target.getFloat(0), equals(2560.0));
      expect(target.getFloat(1), equals(1440.0));
      expect(target.getFloat(2), equals(1.85));
      expect(target.getFloat(3), equals(1.0));
      expect(target.getFloat(4), equals(1.0));
      expect(target.getFloat(5), equals(0.0));
      expect(target.getFloat(6), equals(1.2));
      expect(target.getFloat(7), equals(0.95));

      final List<double> floatList = target.toFloatList(minLength: 8);
      expect(floatList.length, equals(8));
      expect(floatList[2], equals(1.85));
    });

    test('bindByDescriptor falls back to default values for missing params', () {
      final ShaderRegistry reg = ShaderRegistry(loadDefaults: true);
      final ShaderDescriptor acesDesc =
          reg.getShaderDescriptor(ShaderCatalog.acesTonemap)!;

      // Provide only uExposure; rest should fill from default descriptor values
      UniformBufferBinder.bindByDescriptor(target, acesDesc, <String, dynamic>{
        'uExposure': 2.5,
      });

      expect(target.getFloat(0), equals(1920.0)); // default resolution width
      expect(target.getFloat(1), equals(1080.0)); // default resolution height
      expect(target.getFloat(2), equals(2.5)); // overridden
      expect(target.getFloat(3), equals(0.0)); // default exposureMode
      expect(target.getFloat(6), equals(1.0)); // default preGain
    });
  });

  group('ShaderPipeline Pipeline & Fallback Tests', () {
    test('Pipeline loads and caches vertex shader text source', () async {
      final MockShaderAssetLoader loader = MockShaderAssetLoader(
        sourceData: <String, String>{
          'shaders/crowd/vat_crowd.vert': '// Custom VAT Crowd Vertex Shader v1.0',
        },
      );

      final ShaderPipeline pipeline = ShaderPipeline(
        assetLoader: loader,
        config: const ShaderPipelineConfig(enableWarmup: false),
      );

      final CompiledShader compiled =
          await pipeline.loadShader(ShaderCatalog.vatCrowdVert);

      expect(compiled.status, equals(ShaderStatus.compiled));
      expect(compiled.sourceCode, contains('Custom VAT Crowd Vertex Shader'));
      expect(pipeline.compiledCount, equals(1));

      // Second load returns cached shader without calling loader again
      final CompiledShader cached =
          await pipeline.loadShader(ShaderCatalog.vatCrowdVert);
      expect(identical(compiled, cached), isTrue);
      expect(loader.sourceLoadAttempts, equals(1));
    });

    test('Safe fallback activates when GPU program compilation throws an exception', () async {
      // Simulate GPU compilation failure on ssaoCompositeAces; it specifies fallbackId acesTonemap
      final MockShaderAssetLoader loader = MockShaderAssetLoader(
        failProgramPaths: <String>{
          ShaderCatalog.ssaoCompositeAces,
          ShaderCatalog.acesTonemap,
        },
      );

      final ShaderPipeline pipeline = ShaderPipeline(
        assetLoader: loader,
        config: const ShaderPipelineConfig(enableFallbacks: true, enableWarmup: false),
      );

      final CompiledShader shader =
          await pipeline.loadShader(ShaderCatalog.ssaoCompositeAces);

      // Status should be fallbackActive or failed with lastError logged, NOT uncaught exception
      expect(
        shader.status == ShaderStatus.fallbackActive ||
            shader.status == ShaderStatus.failed,
        isTrue,
      );
      expect(shader.lastError, isNotNull);
      expect(shader.lastError, contains('Compilation'));
    });

    test('Device tier downgrade routes shaders to fallback when hardware tier is low', () async {
      final MockShaderAssetLoader loader = MockShaderAssetLoader();

      // Configure pipeline on ultraLow tier
      final ShaderPipeline pipeline = ShaderPipeline(
        assetLoader: loader,
        config: const ShaderPipelineConfig(
          deviceTier: DevicePerformanceTier.ultraLow,
          enableFallbacks: true,
          enableWarmup: false,
        ),
      );

      // SSAO requires DevicePerformanceTier.medium
      final CompiledShader ssaoShader =
          await pipeline.loadShader(ShaderCatalog.ssao);

      expect(ssaoShader.status, equals(ShaderStatus.fallbackActive));
      expect(pipeline.isFallbackActive(ShaderCatalog.ssao), isTrue);
      expect(ssaoShader.lastError, contains('Downgraded due to device tier'));
    });

    test('Warm-up system primes target with declared warmup parameters', () {
      final ShaderRegistry registry = ShaderRegistry(loadDefaults: true);
      final ShaderPipeline pipeline = ShaderPipeline(registry: registry);

      final ShaderDescriptor acesDesc =
          registry.getShaderDescriptor(ShaderCatalog.acesTonemap)!;
      final BufferUniformTarget target = BufferUniformTarget();

      pipeline.warmUpTarget(target, acesDesc);

      // Warmup parameters for aces are: [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0]
      expect(target.getFloat(0), equals(1.0));
      expect(target.getFloat(1), equals(1.0));
      expect(target.getFloat(2), equals(1.0));
      expect(target.getFloat(7), equals(1.0));
    });

    test('Pipeline stats report records accurate counts and diagnostics', () async {
      final MockShaderAssetLoader loader = MockShaderAssetLoader(
        sourceData: <String, String>{
          ShaderCatalog.gpuInstancingVert: 'void main() {}',
          ShaderCatalog.vatCrowdVert: 'void main() {}',
        },
      );

      final ShaderPipeline pipeline = ShaderPipeline(
        assetLoader: loader,
        config: const ShaderPipelineConfig(
          deviceTier: DevicePerformanceTier.high,
          enableWarmup: false,
        ),
      );

      await pipeline.loadShader(ShaderCatalog.gpuInstancingVert);
      await pipeline.loadShader(ShaderCatalog.vatCrowdVert);

      final ShaderPipelineStats stats = pipeline.getPipelineStats();

      expect(stats.totalRegistered, equals(16));
      expect(stats.totalCompiled, equals(2));
      expect(stats.deviceTier, equals(DevicePerformanceTier.high));

      final String report = stats.generateReport();
      expect(report, contains('GKK Central Shader Pipeline Diagnostics'));
      expect(report, contains('Successfully Compiled: 2'));
    });

    test('Pipeline clean disposal clears all caches', () async {
      final MockShaderAssetLoader loader = MockShaderAssetLoader(
        sourceData: <String, String>{
          ShaderCatalog.gpuInstancingVert: 'void main() {}',
        },
      );

      final ShaderPipeline pipeline = ShaderPipeline(
        assetLoader: loader,
        config: const ShaderPipelineConfig(enableWarmup: false),
      );

      await pipeline.loadShader(ShaderCatalog.gpuInstancingVert);
      expect(pipeline.compiledCount, equals(1));

      pipeline.dispose();
      expect(pipeline.compiledCount, equals(0));
      expect(pipeline.isInitialized, isFalse);
    });
  });
}
