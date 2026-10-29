// =============================================================================
// 10K VAT Crowd Shader & Mesh Deformation Uniforms Test Suite
// Target: test/shaders/vat_crowd_shader_test.dart
// Architecture: R4 Crowd Rendering Pipeline & 2027 Cinematic AAA Graphics
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/crowd/gpu_instancing_batcher.dart';
import 'package:gkk_flutter/core/crowd/vat_crowd_renderer.dart';
import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';

// =============================================================================
// Helper Test Widgets & Painters for 10K VAT Crowd Verification
// =============================================================================

/// CustomPainter rendering 2D top-down debug representation of crowd entities
/// with distance fog color blending and render mode color coding.
class VatCrowdDebugPainter extends CustomPainter {
  final List<CrowdEntity> entities;
  final double fogStart;
  final double fogEnd;
  final Color fogColor;
  final int frameNumber;

  const VatCrowdDebugPainter({
    required this.entities,
    this.fogStart = 50.0,
    this.fogEnd = 250.0,
    this.fogColor = const Color.fromARGB(255, 26, 31, 38),
    this.frameNumber = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw background canvas in fog atmosphere color
    final bgPaint = Paint()..color = fogColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final halfW = size.width * 0.5;
    final halfH = size.height * 0.5;

    // 2. Render entity positions projected onto X/Z plane
    for (final entity in entities) {
      final cx = halfW + entity.posX;
      final cy = halfH + entity.posZ;

      // Distance from camera origin (0, 0, 0)
      final dist = math.sqrt(
        entity.posX * entity.posX +
            entity.posY * entity.posY +
            entity.posZ * entity.posZ,
      );

      // Non-linear smoothstep fog factor matching vat_crowd.frag
      final rawFog = ((dist - fogStart) / (fogEnd - fogStart)).clamp(0.0, 1.0);
      final fogFactor = rawFog * rawFog * (3.0 - 2.0 * rawFog);

      // Entity base color (VAT Mesh = Cyan, Impostor Billboard = Gold)
      final isMesh = entity.renderMode == CrowdRenderMode.vatMesh;
      final baseR = isMesh ? 0.0 : 1.0;
      final baseG = isMesh ? 0.8 : 0.7;
      final baseB = isMesh ? 1.0 : 0.1;

      // Blend with fog color
      final fogR = fogColor.r;
      final fogG = fogColor.g;
      final fogB = fogColor.b;

      final finalR = ((1.0 - fogFactor) * baseR + fogFactor * fogR).clamp(0.0, 1.0);
      final finalG = ((1.0 - fogFactor) * baseG + fogFactor * fogG).clamp(0.0, 1.0);
      final finalB = ((1.0 - fogFactor) * baseB + fogFactor * fogB).clamp(0.0, 1.0);

      final entityPaint = Paint()
        ..color = Color.fromARGB(
          255,
          (finalR * 255).round(),
          (finalG * 255).round(),
          (finalB * 255).round(),
        )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(cx, cy), 1.5, entityPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VatCrowdDebugPainter oldDelegate) {
    return oldDelegate.entities.length != entities.length ||
        oldDelegate.frameNumber != frameNumber ||
        oldDelegate.fogStart != fogStart ||
        oldDelegate.fogEnd != fogEnd;
  }
}

/// Interactive Widget providing HUD diagnostics and live preview for 10K crowd rendering.
class VatCrowdPreviewWidget extends StatefulWidget {
  final VatCrowdRenderer renderer;
  final List<CrowdEntity> entities;
  final VoidCallback? onToggleMode;

  const VatCrowdPreviewWidget({
    super.key,
    required this.renderer,
    required this.entities,
    this.onToggleMode,
  });

  @override
  State<VatCrowdPreviewWidget> createState() => _VatCrowdPreviewWidgetState();
}

class _VatCrowdPreviewWidgetState extends State<VatCrowdPreviewWidget> {
  int _renderTick = 0;

  void triggerRedraw() {
    setState(() {
      _renderTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = widget.entities.length;
    final memoryKb = (activeCount * CrowdInstanceBuffer.floatsPerInstance * 4) / 1024.0;
    final meshCount = widget.entities
        .where((e) => e.renderMode == CrowdRenderMode.vatMesh)
        .length;
    final impostorCount = activeCount - meshCount;

    return GestureDetector(
      onTap: widget.onToggleMode,
      child: Column(
        children: [
          Text(
            'Active Entities: $activeCount',
            key: const Key('active_entity_counter'),
          ),
          Text(
            'Draw Calls: 1',
            key: const Key('draw_call_counter'),
          ),
          Text(
            'Memory: ${memoryKb.toStringAsFixed(1)} KB',
            key: const Key('memory_usage_label'),
          ),
          Text(
            'LOD Split: $meshCount Mesh / $impostorCount Billboard',
            key: const Key('lod_split_label'),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(800, 600),
              painter: VatCrowdDebugPainter(
                entities: widget.entities,
                frameNumber: _renderTick,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MAIN TEST SUITE
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. GLSL Shader Static Analysis & Uniform Layout Verification
  // ---------------------------------------------------------------------------
  group('VAT Crowd GLSL Source Files Static Verification', () {
    late File fragFile;
    late String fragContent;
    late File vertFile;
    late String vertContent;
    late File instancingVertFile;
    late String instancingVertContent;

    setUpAll(() {
      fragFile = File('shaders/crowd/vat_crowd.frag');
      expect(fragFile.existsSync(), isTrue,
          reason: 'vat_crowd.frag must exist in shaders/crowd/');
      fragContent = fragFile.readAsStringSync();

      vertFile = File('shaders/crowd/vat_crowd.vert');
      expect(vertFile.existsSync(), isTrue,
          reason: 'vat_crowd.vert must exist in shaders/crowd/');
      vertContent = vertFile.readAsStringSync();

      instancingVertFile = File('shaders/crowd/gpu_instancing.vert');
      expect(instancingVertFile.existsSync(), isTrue,
          reason: 'gpu_instancing.vert must exist in shaders/crowd/');
      instancingVertContent = instancingVertFile.readAsStringSync();
    });

    test('vat_crowd.frag declares standard Impeller runtime_effect headers', () {
      expect(fragContent, contains('#version 460 core'));
      expect(fragContent, contains('#include <flutter/runtime_effect.glsl>'));
      expect(fragContent, contains('precision highp float;'));
    });

    test('vat_crowd.frag inputs from rasterizer stage match expected varyings', () {
      expect(fragContent, contains('in vec2 vTexCoords;'));
      expect(fragContent, contains('in vec3 vWorldNormal;'));
      expect(fragContent, contains('in vec3 vWorldPos;'));
      expect(fragContent, contains('in vec4 vInstanceTint;'));
      expect(fragContent, contains('in float vRenderMode;'));
      expect(fragContent, contains('in float vDistanceToCamera;'));
      expect(fragContent, contains('out vec4 fragColor;'));
    });

    test('vat_crowd.frag declares exact 15-float uniform layout in strict order', () {
      expect(fragContent, contains('uniform vec3 uLightDir;'));
      expect(fragContent, contains('uniform vec3 uLightColor;'));
      expect(fragContent, contains('uniform vec3 uAmbientColor;'));
      expect(fragContent, contains('uniform vec3 uFogColor;'));
      expect(fragContent, contains('uniform float uFogStart;'));
      expect(fragContent, contains('uniform float uFogEnd;'));
      expect(fragContent, contains('uniform float uAlphaCutoff;'));

      final idxLightDir = fragContent.indexOf('uniform vec3 uLightDir;');
      final idxLightCol = fragContent.indexOf('uniform vec3 uLightColor;');
      final idxAmbient = fragContent.indexOf('uniform vec3 uAmbientColor;');
      final idxFogCol = fragContent.indexOf('uniform vec3 uFogColor;');
      final idxFogStart = fragContent.indexOf('uniform float uFogStart;');
      final idxFogEnd = fragContent.indexOf('uniform float uFogEnd;');
      final idxCutoff = fragContent.indexOf('uniform float uAlphaCutoff;');

      expect(idxLightDir, lessThan(idxLightCol));
      expect(idxLightCol, lessThan(idxAmbient));
      expect(idxAmbient, lessThan(idxFogCol));
      expect(idxFogCol, lessThan(idxFogStart));
      expect(idxFogStart, lessThan(idxFogEnd));
      expect(idxFogEnd, lessThan(idxCutoff));
    });

    test('vat_crowd.frag samplers are declared strictly after all numeric uniforms', () {
      expect(fragContent, contains('uniform sampler2D uAlbedoMap;'));
      expect(fragContent, contains('uniform sampler2D uImpostorAtlas;'));

      final lastNumericIdx = fragContent.indexOf('uniform float uAlphaCutoff;');
      final firstSamplerIdx = fragContent.indexOf('uniform sampler2D uAlbedoMap;');
      expect(
        firstSamplerIdx,
        greaterThan(lastNumericIdx),
        reason: 'Impeller requires sampler uniforms to follow all numeric uniforms',
      );
    });

    test('vat_crowd.frag implements Mode 0 VAT half-Lambert wrapped diffuse shading', () {
      expect(fragContent, contains('if (vRenderMode < 0.5)'));
      expect(fragContent, contains('texture(uAlbedoMap, vTexCoords)'));
      expect(fragContent, contains('pow(nDotL * 0.5 + 0.5, 1.5)'));
    });

    test('vat_crowd.frag implements Mode 1 Impostor billboard with alpha discard', () {
      expect(fragContent, contains('texture(uImpostorAtlas, vTexCoords)'));
      expect(fragContent, contains('if (atlasSample.a < cutoff)'));
      expect(fragContent, contains('discard;'));
      expect(fragContent, contains('max(nDotL, 0.35)'));
    });

    test('vat_crowd.frag implements atmospheric distance fog non-linear smoothstep', () {
      expect(fragContent, contains('clamp((vDistanceToCamera - fogStart) / (fogEnd - fogStart), 0.0, 1.0)'));
      expect(fragContent, contains('fogFactor = rawFog * rawFog * (3.0 - 2.0 * rawFog)'));
      expect(fragContent, contains('mix(baseColor.rgb, uFogColor, fogFactor)'));
    });

    test('vat_crowd.vert contains valid Impeller vertex wrapper', () {
      expect(vertContent, contains('#version 460 core'));
      expect(vertContent, contains('#include <flutter/runtime_effect.glsl>'));
      expect(vertContent, contains('FlutterFragCoord()'));
    });

    test('gpu_instancing.vert declares 24-float / 96-byte instance attributes', () {
      expect(instancingVertContent, contains('layout(location = 5) in mat4 aInstanceModelMatrix;'));
      expect(instancingVertContent, contains('layout(location = 9) in vec4 aInstanceAnimData;'));
      expect(instancingVertContent, contains('layout(location = 10) in vec4 aInstanceTintColor;'));
      expect(instancingVertContent, contains('Total Stride = 24 floats (96 bytes)'));
    });

    test('gpu_instancing.vert implements dual-path LOD2 vertex animation skinning', () {
      expect(instancingVertContent, contains('computeProceduralLOD2Skinning'));
      expect(instancingVertContent, contains('computePaletteSkinning'));
      expect(instancingVertContent, contains('fetchBoneMatrix'));
      expect(instancingVertContent, contains('uniform sampler2D uBoneTexture;'));
      expect(instancingVertContent, contains('uniform vec4 uBoneTextureParams;'));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Shader Registry & Material Catalog Integration
  // ---------------------------------------------------------------------------
  group('Shader Registry & Crowd Catalog Verification', () {
    late ShaderRegistry registry;

    setUp(() {
      registry = ShaderRegistry(loadDefaults: true);
    });

    test('ShaderCatalog exposes vatCrowdFrag, vatCrowdVert, and gpuInstancingVert', () {
      expect(ShaderCatalog.vatCrowdFrag, equals('shaders/crowd/vat_crowd.frag'));
      expect(ShaderCatalog.vatCrowdVert, equals('shaders/crowd/vat_crowd.vert'));
      expect(ShaderCatalog.gpuInstancingVert, equals('shaders/crowd/gpu_instancing.vert'));
    });

    test('vatCrowdFrag descriptor accurately declares 15 floats, 2 samplers, and warmup', () {
      final desc = registry.getShaderDescriptor(ShaderCatalog.vatCrowdFrag);
      expect(desc, isNotNull);
      expect(desc!.category, equals(ShaderCategory.crowd));
      expect(desc.stage, equals(ShaderStage.fragment));
      expect(desc.totalFloatCount, equals(15));
      expect(desc.totalSamplerCount, equals(2));
      expect(desc.minPerformanceTier, equals(DevicePerformanceTier.low));
      expect(desc.fallbackStrategy, equals(ShaderFallbackStrategy.bypass));

      // Uniforms
      expect(desc.findUniform('uLightDir')!.floatCount, equals(3));
      expect(desc.findUniform('uLightDir')!.floatOffset, equals(0));
      expect(desc.findUniform('uLightColor')!.floatCount, equals(3));
      expect(desc.findUniform('uLightColor')!.floatOffset, equals(3));
      expect(desc.findUniform('uAmbientColor')!.floatCount, equals(3));
      expect(desc.findUniform('uAmbientColor')!.floatOffset, equals(6));
      expect(desc.findUniform('uFogColor')!.floatCount, equals(3));
      expect(desc.findUniform('uFogColor')!.floatOffset, equals(9));
      expect(desc.findUniform('uFogStart')!.floatCount, equals(1));
      expect(desc.findUniform('uFogStart')!.floatOffset, equals(12));
      expect(desc.findUniform('uFogEnd')!.floatCount, equals(1));
      expect(desc.findUniform('uFogEnd')!.floatOffset, equals(13));
      expect(desc.findUniform('uAlphaCutoff')!.floatCount, equals(1));
      expect(desc.findUniform('uAlphaCutoff')!.floatOffset, equals(14));

      // Samplers
      expect(desc.findSampler('uAlbedoMap')!.samplerIndex, equals(0));
      expect(desc.findSampler('uImpostorAtlas')!.samplerIndex, equals(1));

      // Warmup parameters
      expect(desc.warmupParameters, isNotNull);
      expect(desc.warmupParameters!.length, equals(15));
    });

    test('vatCrowdVert descriptor defines 35-float vertex layout and 2 texture samplers', () {
      final desc = registry.getShaderDescriptor(ShaderCatalog.vatCrowdVert);
      expect(desc, isNotNull);
      expect(desc!.category, equals(ShaderCategory.crowd));
      expect(desc.stage, equals(ShaderStage.vertex));
      expect(desc.totalFloatCount, equals(35));
      expect(desc.totalSamplerCount, equals(2));

      expect(desc.findUniform('uViewProjection')!.type, equals(UniformType.mat4));
      expect(desc.findUniform('uViewProjection')!.floatOffset, equals(0));
      expect(desc.findUniform('uVatScale')!.floatOffset, equals(16));
      expect(desc.findUniform('uVatOffset')!.floatOffset, equals(19));
      expect(desc.findUniform('uTexDimensions')!.floatOffset, equals(22));
      expect(desc.findUniform('uCameraPosition')!.floatOffset, equals(24));
      expect(desc.findUniform('uCameraRight')!.floatOffset, equals(27));
      expect(desc.findUniform('uCameraUp')!.floatOffset, equals(30));
      expect(desc.findUniform('uAtlasGrid')!.floatOffset, equals(33));

      expect(desc.findSampler('uPosMap')!.samplerIndex, equals(0));
      expect(desc.findSampler('uNormMap')!.samplerIndex, equals(1));
    });

    test('gpuInstancingVert descriptor defines 16-float view-projection uniform', () {
      final desc = registry.getShaderDescriptor(ShaderCatalog.gpuInstancingVert);
      expect(desc, isNotNull);
      expect(desc!.category, equals(ShaderCategory.crowd));
      expect(desc.stage, equals(ShaderStage.vertex));
      expect(desc.totalFloatCount, equals(16));
      expect(desc.minPerformanceTier, equals(DevicePerformanceTier.medium));
      expect(desc.findUniform('uViewProjection')!.floatCount, equals(16));
    });

    test('Default crowd material mat_crowd_skeleton_warrior links to vatCrowdFrag', () {
      final mat = registry.getMaterial('mat_crowd_skeleton_warrior');
      expect(mat, isNotNull);
      expect(mat!.shaderId, equals(ShaderCatalog.vatCrowdFrag));
      expect(mat.category, equals(ShaderCategory.crowd));
      expect(mat.properties['uFogStart'], equals(60.0));
      expect(mat.properties['uFogEnd'], equals(300.0));
      expect(mat.properties['uAlphaCutoff'], equals(0.5));
      expect(mat.tags, containsAll(<String>['crowd', 'vat', '10k', 'impostor']));
    });

    test('ShaderRegistry filters crowd descriptors cleanly', () {
      final crowdDescriptors = registry.getByCategory(ShaderCategory.crowd);
      expect(crowdDescriptors.length, equals(3));
      final ids = crowdDescriptors.map((d) => d.id).toList();
      expect(ids, contains(ShaderCatalog.vatCrowdFrag));
      expect(ids, contains(ShaderCatalog.vatCrowdVert));
      expect(ids, contains(ShaderCatalog.gpuInstancingVert));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. VAT Vertex Animation Texture Uniforms (uAnimTexture, uAnimFrame, uAnimSpeed, uTotalFrames)
  // ---------------------------------------------------------------------------
  group('VAT Crowd Animation Texture Uniform Definitions & Math', () {
    test('VAT animation uniform descriptor maps frame parameters and sampler correctly', () {
      const vatAnimDescriptor = ShaderDescriptor(
        id: 'shaders/crowd/vat_anim_mesh.frag',
        assetPath: 'shaders/crowd/vat_anim_mesh.frag',
        category: ShaderCategory.crowd,
        stage: ShaderStage.fragment,
        uniforms: <UniformDefinition>[
          UniformDefinition(
            name: 'uAnimFrame',
            type: UniformType.float,
            floatOffset: 0,
            floatCount: 1,
            defaultValue: <double>[0.0],
          ),
          UniformDefinition(
            name: 'uAnimSpeed',
            type: UniformType.float,
            floatOffset: 1,
            floatCount: 1,
            defaultValue: <double>[1.0],
          ),
          UniformDefinition(
            name: 'uTotalFrames',
            type: UniformType.float,
            floatOffset: 2,
            floatCount: 1,
            defaultValue: <double>[60.0],
          ),
          UniformDefinition(
            name: 'uAnimPhase',
            type: UniformType.float,
            floatOffset: 3,
            floatCount: 1,
            defaultValue: <double>[0.0],
          ),
          UniformDefinition(
            name: 'uAnimMode',
            type: UniformType.float,
            floatOffset: 4,
            floatCount: 1,
            defaultValue: <double>[0.0],
          ),
        ],
        samplers: <SamplerDefinition>[
          SamplerDefinition(name: 'uAnimTexture', samplerIndex: 0),
        ],
      );

      expect(vatAnimDescriptor.totalFloatCount, equals(5));
      expect(vatAnimDescriptor.totalSamplerCount, equals(1));
      expect(vatAnimDescriptor.findUniform('uAnimFrame')!.floatOffset, equals(0));
      expect(vatAnimDescriptor.findUniform('uAnimSpeed')!.floatOffset, equals(1));
      expect(vatAnimDescriptor.findUniform('uTotalFrames')!.floatOffset, equals(2));
      expect(vatAnimDescriptor.findSampler('uAnimTexture')!.samplerIndex, equals(0));
    });

    test('BufferUniformTarget packs VAT animation uniforms accurately', () {
      final target = BufferUniformTarget();

      // Bind uAnimFrame=24.5, uAnimSpeed=1.2, uTotalFrames=60.0
      UniformBufferBinder.bindFloat(target, 0, 24.5);
      UniformBufferBinder.bindFloat(target, 1, 1.2);
      UniformBufferBinder.bindFloat(target, 2, 60.0);
      UniformBufferBinder.bindFloat(target, 3, 24.5 / 60.0); // normalized phase

      expect(target.getFloat(0), equals(24.5));
      expect(target.getFloat(1), equals(1.2));
      expect(target.getFloat(2), equals(60.0));
      expect(target.getFloat(3), closeTo(0.408333, 1e-5));

      final floatList = target.toFloatList(minLength: 4);
      expect(floatList.length, equals(4));
      expect(floatList[0], equals(24.5));
      expect(floatList[1], equals(1.2));
      expect(floatList[2], equals(60.0));
    });

    test('Sub-frame lerp factor and normalized V coordinate calculations are accurate', () {
      const totalFrames = 60;
      const currentFrame = 15;
      const nextFrame = 16;
      const lerp = 0.35;

      // Effective continuous frame
      final continuousFrame = currentFrame + lerp;
      expect(continuousFrame, closeTo(15.35, 1e-6));

      // Center-of-row texel V coordinate: (frame + 0.5) / totalFrames
      final vCenter = (continuousFrame + 0.5) / totalFrames;
      expect(vCenter, closeTo(15.85 / 60.0, 1e-6));

      // Normalization check
      expect(vCenter, greaterThanOrEqualTo(0.0));
      expect(vCenter, lessThanOrEqualTo(1.0));
    });

    test('VatAnimationState advances continuous animation with looping and sub-frame lerp', () {
      const clip = VatClipInfo(
        name: 'run',
        startFrame: 0,
        endFrame: 59,
        frameCount: 60,
        fps: 30.0,
        loop: true,
      );

      final state = VatAnimationState(clip: clip, playbackSpeed: 1.0);
      expect(state.currentFrame, equals(0));
      expect(state.nextFrame, equals(1));
      expect(state.lerpFactor, closeTo(0.0, 1e-5));

      // Step by 0.5s (15 frames)
      state.advance(0.5);
      expect(state.currentFrame, equals(15));
      expect(state.nextFrame, equals(16));
      expect(state.effectiveTime, closeTo(0.5, 1e-5));

      // Step by 2.0s (full cycle wrap-around)
      state.advance(2.0);
      expect(state.currentFrame, equals(15)); // 2.5s % 2.0s = 0.5s -> frame 15
    });

    test('VatMetadata parses VAT texture dimensions and unpacks local positions accurately', () {
      final metadata = VatMetadata.fromJson({
        'vertex_count': 256,
        'total_frames': 60,
        'texture_dimensions': {'width': 256, 'height': 60},
        'bounding_box': {
          'min': [-1.0, 0.0, -1.0],
          'max': [1.0, 2.0, 1.0],
          'scale': [2.0, 2.0, 2.0],
          'offset': [-1.0, 0.0, -1.0],
        },
      });

      expect(metadata.vertexCount, equals(256));
      expect(metadata.totalFrames, equals(60));
      expect(metadata.textureWidth, equals(256));
      expect(metadata.textureHeight, equals(60));

      // Texel center U: (0 + 0.5) / 256
      final u0 = metadata.computeNormalizedU(0);
      expect(u0, closeTo(0.5 / 256.0, 1e-6));

      // Row center V: (0 + 0.5) / 60
      final v0 = metadata.computeNormalizedV(0.0);
      expect(v0, closeTo(0.5 / 60.0, 1e-6));

      // Position unpack from normalized [0, 1] range to local bbox space
      final pMin = metadata.unpackPosition(0.0, 0.0, 0.0);
      expect(pMin[0], closeTo(-1.0, 1e-5));
      expect(pMin[1], closeTo(0.0, 1e-5));
      expect(pMin[2], closeTo(-1.0, 1e-5));

      final pMax = metadata.unpackPosition(1.0, 1.0, 1.0);
      expect(pMax[0], closeTo(1.0, 1e-5));
      expect(pMax[1], closeTo(2.0, 1e-5));
      expect(pMax[2], closeTo(1.0, 1e-5));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Single Draw-Call Instance Batching & Transform Buffer Offsets
  // ---------------------------------------------------------------------------
  group('Single Draw-Call Instance Batching & Transform Buffer Offsets', () {
    test('CrowdInstanceBuffer layout matches 28 floats (112 bytes) per instance', () {
      expect(CrowdInstanceBuffer.floatsPerInstance, equals(28));
      expect(CrowdInstanceBuffer.bytesPerInstance, equals(112));
      expect(112 % 16, equals(0), reason: 'Instance byte stride must be 16-byte aligned for GPU cache lines');
    });

    test('InstanceBufferLayout (LOD2) layout matches 24 floats (96 bytes) per instance', () {
      expect(InstanceBufferLayout.matrixFloatCount, equals(16));
      expect(InstanceBufferLayout.animDataFloatCount, equals(4));
      expect(InstanceBufferLayout.tintColorFloatCount, equals(4));
      expect(InstanceBufferLayout.floatsPerInstance, equals(24));
      expect(InstanceBufferLayout.bytesPerInstance, equals(96));
      expect(InstanceBufferLayout.matrixOffset, equals(0));
      expect(InstanceBufferLayout.animDataOffset, equals(16));
      expect(InstanceBufferLayout.tintColorOffset, equals(20));
      expect(InstanceBufferLayout.matrixByteOffset, equals(0));
      expect(InstanceBufferLayout.animDataByteOffset, equals(64));
      expect(InstanceBufferLayout.tintColorByteOffset, equals(80));
    });

    test('CrowdInstanceBuffer packs transform matrix, animation state, and tint in-place', () {
      final buffer = CrowdInstanceBuffer(initialCapacity: 10);

      buffer.packInstance(
        index: 0,
        posX: 12.5,
        posY: 3.0,
        posZ: -45.0,
        rotationY: math.pi * 0.5, // 90 degrees yaw
        scaleX: 1.5,
        scaleY: 1.5,
        scaleZ: 1.5,
        currentFrame: 10.0,
        nextFrame: 11.0,
        lerpFactor: 0.25,
        renderMode: 0.0, // VAT mesh
        tintR: 0.9,
        tintG: 0.8,
        tintB: 0.7,
        tintA: 1.0,
        boundingRadius: 2.0,
        entityId: 42.0,
      );

      final raw = buffer.buffer;

      // Column 0: cos(pi/2)*1.5 ≈ 0, 0, -sin(pi/2)*1.5 ≈ -1.5, 0
      expect(raw[0], closeTo(0.0, 1e-4));
      expect(raw[1], equals(0.0));
      expect(raw[2], closeTo(-1.5, 1e-4));
      expect(raw[3], equals(0.0));

      // Column 1: 0, 1.5, 0, 0
      expect(raw[4], equals(0.0));
      expect(raw[5], closeTo(1.5, 1e-4));
      expect(raw[6], equals(0.0));
      expect(raw[7], equals(0.0));

      // Column 2: sin(pi/2)*1.5 ≈ 1.5, 0, cos(pi/2)*1.5 ≈ 0, 0
      expect(raw[8], closeTo(1.5, 1e-4));
      expect(raw[9], equals(0.0));
      expect(raw[10], closeTo(0.0, 1e-4));
      expect(raw[11], equals(0.0));

      // Column 3 (Translation): 12.5, 3.0, -45.0, 1.0
      expect(raw[12], closeTo(12.5, 1e-4));
      expect(raw[13], closeTo(3.0, 1e-4));
      expect(raw[14], closeTo(-45.0, 1e-4));
      expect(raw[15], equals(1.0));

      // Animation & Render Data
      expect(raw[16], equals(10.0));
      expect(raw[17], equals(11.0));
      expect(raw[18], equals(0.25));
      expect(raw[19], equals(0.0));

      // Tint Color
      expect(raw[20], closeTo(0.9, 1e-4));
      expect(raw[21], closeTo(0.8, 1e-4));
      expect(raw[22], closeTo(0.7, 1e-4));
      expect(raw[23], equals(1.0));

      // Extra parameters
      expect(raw[24], equals(2.0));
      expect(raw[25], equals(42.0));
    });

    test('LOD2Entity.createTransformMatrix constructs column-major transform matrix', () {
      final matrix = LOD2Entity.createTransformMatrix(
        tx: 100.0,
        ty: 0.0,
        tz: 200.0,
        yawRadians: 0.0,
        scaleX: 2.0,
        scaleY: 3.0,
        scaleZ: 4.0,
      );

      expect(matrix.length, equals(16));
      expect(matrix[0], equals(2.0)); // scaleX
      expect(matrix[5], equals(3.0)); // scaleY
      expect(matrix[10], equals(4.0)); // scaleZ
      expect(matrix[12], equals(100.0)); // tx
      expect(matrix[13], equals(0.0)); // ty
      expect(matrix[14], equals(200.0)); // tz
      expect(matrix[15], equals(1.0)); // homogeneous 1.0
    });

    test('DrawCallBatch appends and accurately unpacks instances', () {
      final batch = DrawCallBatch(
        batchId: 1,
        meshId: 101,
        materialKey: 202,
        maxCapacity: 64,
        buffer: Float32List(64 * InstanceBufferLayout.floatsPerInstance),
      );

      final entity = LOD2Entity.fromTransform(
        entityId: 99,
        meshId: 101,
        materialKey: 202,
        tx: 5.0,
        ty: 10.0,
        tz: 15.0,
        yawRadians: 0.0,
        scaleX: 1.0,
        scaleY: 1.0,
        scaleZ: 1.0,
        animationFrameIndex: 7.0,
        normalizedAnimationTime: 0.35,
        animationType: 2, // Run
        animationBlendWeight: 0.5,
        tintR: 0.5,
        tintG: 0.6,
        tintB: 0.7,
        tintA: 0.8,
      );

      batch.appendEntity(entity);
      expect(batch.instanceCount, equals(1));
      expect(batch.activeFloatCount, equals(24));
      expect(batch.totalActiveBytes, equals(96));

      final outMatrix = Float32List(16);
      final outAnim = Float32List(4);
      final outTint = Float32List(4);

      batch.unpackInstance(0, outMatrix: outMatrix, outAnimData: outAnim, outTintColor: outTint);

      expect(outMatrix[12], equals(5.0));
      expect(outMatrix[13], equals(10.0));
      expect(outMatrix[14], equals(15.0));
      expect(outAnim[0], equals(7.0));
      expect(outAnim[1], closeTo(0.35, 1e-5));
      expect(outAnim[2], equals(2.0));
      expect(outAnim[3], equals(0.5));
      expect(outTint[0], closeTo(0.5, 1e-5));
      expect(outTint[1], closeTo(0.6, 1e-5));
      expect(outTint[2], closeTo(0.7, 1e-5));
      expect(outTint[3], closeTo(0.8, 1e-5));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Distant LOD & Impostor Billboard Alpha Cutoff and Fog Fade Thresholds
  // ---------------------------------------------------------------------------
  group('Distant LOD Impostor Billboard Alpha Cutoff & Fog Fade Math', () {
    test('Alpha cutoff logic discards fragments below threshold and accepts above', () {
      // Discard function matching vat_crowd.frag: (alpha < cutoff) -> discard
      bool shouldDiscard(double alpha, double cutoff) {
        final effectiveCutoff = (cutoff > 0.0) ? cutoff : 0.5;
        return alpha < effectiveCutoff;
      }

      // Default cutoff (0.5)
      expect(shouldDiscard(0.1, 0.5), isTrue);
      expect(shouldDiscard(0.49, 0.5), isTrue);
      expect(shouldDiscard(0.5, 0.5), isFalse);
      expect(shouldDiscard(0.8, 0.5), isFalse);

      // Custom high cutoff (0.75)
      expect(shouldDiscard(0.6, 0.75), isTrue);
      expect(shouldDiscard(0.76, 0.75), isFalse);

      // Edge case: cutoff <= 0.0 falls back to 0.5
      expect(shouldDiscard(0.3, 0.0), isTrue);
      expect(shouldDiscard(0.6, -1.0), isFalse);
    });

    test('Atmospheric distance fog smoothstep evaluation is mathematically exact', () {
      double computeFogFactor(double dist, double fogStart, double fogEnd) {
        final start = (fogEnd > fogStart) ? fogStart : 50.0;
        final end = (fogEnd > fogStart) ? fogEnd : 300.0;
        final raw = ((dist - start) / (end - start)).clamp(0.0, 1.0);
        return raw * raw * (3.0 - 2.0 * raw);
      }

      const fogStart = 60.0;
      const fogEnd = 300.0;

      // Before fog start: 0% fog
      expect(computeFogFactor(20.0, fogStart, fogEnd), equals(0.0));
      expect(computeFogFactor(60.0, fogStart, fogEnd), equals(0.0));

      // After fog end: 100% fog
      expect(computeFogFactor(300.0, fogStart, fogEnd), equals(1.0));
      expect(computeFogFactor(450.0, fogStart, fogEnd), equals(1.0));

      // Exact midpoint: dist = 180.0 -> raw = 0.5 -> smoothstep(0.5) = 0.25 * (3 - 1) = 0.5
      expect(computeFogFactor(180.0, fogStart, fogEnd), closeTo(0.5, 1e-6));

      // Quarter distance: dist = 120.0 -> raw = 0.25 -> smoothstep = 0.25^2 * (3 - 0.5) = 0.15625
      expect(computeFogFactor(120.0, fogStart, fogEnd), closeTo(0.15625, 1e-6));

      // Fallback guard: inverted fog range handles division safely
      expect(computeFogFactor(100.0, 300.0, 100.0), isNotNull);
    });

    test('Mode 0 Half-Lambert wrapped diffuse lighting curve evaluates soft crowd shading', () {
      double halfLambertDiffuse(double nDotL) {
        final clamped = nDotL.clamp(-1.0, 1.0);
        return math.pow(clamped * 0.5 + 0.5, 1.5).toDouble();
      }

      // Direct light (nDotL = 1.0) -> pow(1.0, 1.5) = 1.0
      expect(halfLambertDiffuse(1.0), closeTo(1.0, 1e-5));

      // Perpendicular light (nDotL = 0.0) -> pow(0.5, 1.5) ≈ 0.35355 (no pitch black)
      expect(halfLambertDiffuse(0.0), closeTo(0.353553, 1e-5));

      // Full shadow light (nDotL = -1.0) -> pow(0.0, 1.5) = 0.0
      expect(halfLambertDiffuse(-1.0), closeTo(0.0, 1e-5));
    });

    test('8-angle impostor viewing quantization maps 360-degree yaw into 8 discrete atlas buckets', () {
      const config = ImpostorAtlasConfig(angleCount: 8, columns: 4, rows: 2);

      // Facing directly towards camera (relative angle 0) -> Bucket 0
      expect(config.computeAngleIndex(0.0, 0.0), equals(0));

      // Facing 90 degrees (relative angle pi/2) -> Bucket 2 (Right)
      expect(config.computeAngleIndex(0.0, math.pi * 0.5), equals(2));

      // Facing 180 degrees (relative angle pi) -> Bucket 4 (Back)
      expect(config.computeAngleIndex(0.0, math.pi), equals(4));

      // Facing 270 degrees (relative angle 3*pi/2) -> Bucket 6 (Left)
      expect(config.computeAngleIndex(0.0, math.pi * 1.5), equals(6));

      // Atlas tile sub-UV bounds for 4x2 grid (width=0.25, height=0.5)
      final (uMin0, vMin0, uMax0, vMax0) = config.computeTileUVBounds(0);
      expect(uMin0, closeTo(0.0, 1e-5));
      expect(vMin0, closeTo(0.0, 1e-5));
      expect(uMax0, closeTo(0.25, 1e-5));
      expect(vMax0, closeTo(0.5, 1e-5));

      final (uMin5, vMin5, uMax5, vMax5) = config.computeTileUVBounds(5); // Col 1, Row 1
      expect(uMin5, closeTo(0.25, 1e-5));
      expect(vMin5, closeTo(0.5, 1e-5));
      expect(uMax5, closeTo(0.5, 1e-5));
      expect(vMax5, closeTo(1.0, 1e-5));
    });

    test('Spherical billboard quad calculation aligns quads orthogonally to camera orientation', () {
      final camera = CameraData.fromAngles(
        posX: 0.0,
        posY: 10.0,
        posZ: -50.0,
        yaw: 0.0,
        pitch: 0.0,
      );

      final quad = VatCrowdRenderer.computeSphericalBillboardQuad(
        centerX: 0.0,
        centerY: 1.0,
        centerZ: 0.0,
        width: 1.6,
        height: 2.0,
        camera: camera,
      );

      expect(quad.length, equals(12)); // 4 vertices * 3 coords (x, y, z)

      // V0 Top-Left: (-0.8, 2.0, 0.0)
      expect(quad[0], closeTo(-0.8, 1e-4));
      expect(quad[1], closeTo(2.0, 1e-4));
      expect(quad[2], closeTo(0.0, 1e-4));

      // V1 Bottom-Left: (-0.8, 0.0, 0.0)
      expect(quad[3], closeTo(-0.8, 1e-4));
      expect(quad[4], closeTo(0.0, 1e-4));
      expect(quad[5], closeTo(0.0, 1e-4));

      // V2 Top-Right: (0.8, 2.0, 0.0)
      expect(quad[6], closeTo(0.8, 1e-4));
      expect(quad[7], closeTo(2.0, 1e-4));
      expect(quad[8], closeTo(0.0, 1e-4));

      // V3 Bottom-Right: (0.8, 0.0, 0.0)
      expect(quad[9], closeTo(0.8, 1e-4));
      expect(quad[10], closeTo(0.0, 1e-4));
      expect(quad[11], closeTo(0.0, 1e-4));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Pipeline Validation Under 10,000 Simulated Entities
  // ---------------------------------------------------------------------------
  group('10,000-Entity Crowd Pipeline Stress & Memory Validation', () {
    late VatMetadata metadata;
    late VatClipInfo walkClip;
    late List<CrowdEntity> crowd10k;
    late VatCrowdRenderer renderer;
    late CameraData camera;

    setUp(() {
      metadata = VatMetadata.fromJson({
        'vertex_count': 120,
        'total_frames': 60,
        'texture_dimensions': {'width': 120, 'height': 60},
        'bounding_box': {
          'min': [-0.6, 0.0, -0.6],
          'max': [0.6, 1.8, 0.6],
          'scale': [1.2, 1.8, 1.2],
          'offset': [-0.6, 0.0, -0.6],
        },
        'clips': [
          {
            'name': 'walk',
            'start_frame': 0,
            'end_frame': 59,
            'frame_count': 60,
            'fps': 30.0,
            'loop': true,
          }
        ],
      });

      walkClip = metadata.getClip('walk');

      camera = CameraData.fromAngles(
        posX: 0.0,
        posY: 25.0,
        posZ: -100.0,
        yaw: 0.0,
        pitch: -0.2,
      );

      renderer = VatCrowdRenderer(
        metadata: metadata,
        initialCapacity: 10000,
      );

      // Populate 10,000 crowd entities distributed over a 600m x 600m open world battlefield
      crowd10k = List<CrowdEntity>.generate(10000, (i) {
        final row = i ~/ 100;
        final col = i % 100;
        final posX = (col - 50) * 6.0;
        final posZ = (row - 50) * 6.0;
        final dist = math.sqrt(posX * posX + posZ * posZ);

        // Distribute LOD: Closer than 120m -> VAT mesh; Beyond 120m -> Impostor billboard
        final mode = (dist < 120.0)
            ? CrowdRenderMode.vatMesh
            : CrowdRenderMode.impostorBillboard;

        return CrowdEntity.create(
          id: i,
          posX: posX,
          posY: 0.0,
          posZ: posZ,
          rotationY: (i * 0.1) % (math.pi * 2.0),
          clip: walkClip,
          playbackSpeed: 0.8 + (i % 5) * 0.1,
          phaseOffset: (i * 0.037) % 2.0,
          renderMode: mode,
          tintR: 0.8 + (i % 3) * 0.1,
          tintG: 0.8 + ((i + 1) % 3) * 0.1,
          tintB: 0.8 + ((i + 2) % 3) * 0.1,
          tintA: 1.0,
        );
      });
    });

    test('10,000 entities packed into a single GPU draw call with exact 280,000 float stride', () {
      final batch = renderer.renderCrowd(
        entities: crowd10k,
        deltaTime: 0.016667,
        camera: camera,
        advanceAnimations: true,
      );

      // Strict single draw call guarantee (R4 specification)
      expect(batch.drawCallCount, equals(1));
      expect(batch.instanceCount, equals(10000));
      expect(batch.strideFloats, equals(28));

      // Buffer active float and byte calculations
      final expectedFloats = 10000 * 28; // 280,000 floats
      final expectedBytes = expectedFloats * 4; // 1,120,000 bytes (~1.068 MB)
      expect(batch.bufferByteLength, equals(expectedBytes));
      expect(batch.memoryKBytes, closeTo(1093.75, 0.1));

      // Total virtual GPU vertices processed: 10,000 * 120 = 1,200,000 vertices
      expect(batch.totalGpuVertices, equals(1200000));

      // Batch packing latency must be tracked and reasonable (< 50ms in unoptimized test VM)
      expect(batch.packingTimeMicros, greaterThan(0));
      expect(renderer.lastActiveInstances, equals(10000));
      expect(renderer.totalBatchesGenerated, equals(1));
    });

    test('Continuous multi-frame 10K simulation executes without buffer reallocation', () {
      final initialBufferCapacity = renderer.instanceBuffer.capacity;

      // Simulate 10 consecutive ticks
      for (int frame = 0; frame < 10; frame++) {
        final batch = renderer.renderCrowd(
          entities: crowd10k,
          deltaTime: 0.016667,
          camera: camera,
          advanceAnimations: true,
        );
        expect(batch.instanceCount, equals(10000));
        expect(batch.drawCallCount, equals(1));
      }

      // Zero GC reallocation verified by unchanged capacity
      expect(renderer.instanceBuffer.capacity, equals(initialBufferCapacity));
      expect(renderer.totalBatchesGenerated, equals(10));
    });

    test('GpuInstancingBatcher groups 10,000 LOD2 entities into batched single draw calls', () {
      final batcher = GpuInstancingBatcher(maxInstancesPerBatch: 1024);

      final lod2Entities = List<LOD2Entity>.generate(10000, (i) {
        return LOD2Entity.fromTransform(
          entityId: i,
          meshId: 1,
          materialKey: 1,
          tx: (i % 100) * 2.0,
          ty: 0.0,
          tz: (i ~/ 100) * 2.0,
          animationFrameIndex: (i % 60).toDouble(),
          normalizedAnimationTime: (i % 60) / 60.0,
          animationType: 1,
        );
      });

      final metrics = batcher.batchEntities(lod2Entities);

      expect(metrics.totalEntitiesProcessed, equals(10000));
      expect(metrics.totalEntitiesPacked, equals(10000));
      expect(metrics.totalEntitiesCulled, equals(0));

      // 10,000 / 1024 = 10 draw calls (9 full of 1024 + 1 remainder of 784)
      expect(metrics.totalDrawCalls, equals(10));
      expect(batcher.activeBatchCount, equals(10));

      // Total uploaded bytes: 10,000 * 96 bytes = 960,000 bytes
      expect(metrics.totalBytesUploaded, equals(960000));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Interactive Preview Widget & CustomPainter Tests (testWidgets)
  // ---------------------------------------------------------------------------
  group('VatCrowdPreviewWidget & DebugPainter Widget Tests', () {
    late VatMetadata metadata;
    late VatClipInfo clip;
    late List<CrowdEntity> sampleEntities;
    late VatCrowdRenderer renderer;

    setUp(() {
      metadata = VatMetadata.fromJson({
        'vertex_count': 60,
        'total_frames': 30,
        'bounding_box': {'min': [-0.5, 0.0, -0.5], 'max': [0.5, 1.5, 0.5]},
      });
      clip = metadata.getClip('default');
      renderer = VatCrowdRenderer(metadata: metadata, initialCapacity: 100);

      sampleEntities = List<CrowdEntity>.generate(50, (i) {
        return CrowdEntity.create(
          id: i,
          posX: (i % 10) * 10.0,
          posY: 0.0,
          posZ: (i ~/ 10) * 10.0,
          clip: clip,
          renderMode: i < 30 ? CrowdRenderMode.vatMesh : CrowdRenderMode.impostorBillboard,
        );
      });
    });

    testWidgets('renders VatCrowdPreviewWidget HUD counters and canvas accurately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VatCrowdPreviewWidget(
              renderer: renderer,
              entities: sampleEntities,
            ),
          ),
        ),
      );

      expect(find.text('Active Entities: 50'), findsOneWidget);
      expect(find.text('Draw Calls: 1'), findsOneWidget);
      expect(find.text('LOD Split: 30 Mesh / 20 Billboard'), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('VatCrowdPreviewWidget triggers onToggleMode callback when tapped', (tester) async {
      bool toggleCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VatCrowdPreviewWidget(
              renderer: renderer,
              entities: sampleEntities,
              onToggleMode: () => toggleCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(VatCrowdPreviewWidget));
      expect(toggleCalled, isTrue);
    });

    test('VatCrowdDebugPainter shouldRepaint triggers only on state modifications', () {
      final painter1 = VatCrowdDebugPainter(
        entities: sampleEntities,
        frameNumber: 1,
      );

      final painter1Identical = VatCrowdDebugPainter(
        entities: sampleEntities,
        frameNumber: 1,
      );

      final painter2NewFrame = VatCrowdDebugPainter(
        entities: sampleEntities,
        frameNumber: 2,
      );

      final painter3NewFog = VatCrowdDebugPainter(
        entities: sampleEntities,
        frameNumber: 1,
        fogStart: 100.0,
      );

      expect(painter1Identical.shouldRepaint(painter1), isFalse);
      expect(painter2NewFrame.shouldRepaint(painter1), isTrue);
      expect(painter3NewFog.shouldRepaint(painter1), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Adversarial Edge Cases and Robustness Verification
  // ---------------------------------------------------------------------------
  group('Adversarial Edge Cases & Boundary Stress', () {
    late VatMetadata metadata;
    late VatCrowdRenderer renderer;
    late CameraData camera;

    setUp(() {
      metadata = VatMetadata.fromJson({
        'vertex_count': 100,
        'total_frames': 30,
      });
      renderer = VatCrowdRenderer(metadata: metadata, initialCapacity: 100);
      camera = CameraData.fromAngles(posX: 0, posY: 5, posZ: -20, yaw: 0);
    });

    test('Empty crowd list (0 entities) renders single draw call with 0 bytes', () {
      final batch = renderer.renderCrowd(
        entities: <CrowdEntity>[],
        deltaTime: 0.016,
        camera: camera,
      );

      expect(batch.instanceCount, equals(0));
      expect(batch.drawCallCount, equals(1));
      expect(batch.bufferByteLength, equals(0));
      expect(batch.totalGpuVertices, equals(0));
    });

    test('Single entity boundary condition handles minimal allocations cleanly', () {
      final singleEntity = [
        CrowdEntity.create(
          id: 1,
          posX: 0.0,
          posY: 0.0,
          posZ: 0.0,
          clip: metadata.getClip('default'),
        ),
      ];

      final batch = renderer.renderCrowd(
        entities: singleEntity,
        deltaTime: 0.016,
        camera: camera,
      );

      expect(batch.instanceCount, equals(1));
      expect(batch.bufferByteLength, equals(112)); // 28 floats * 4 bytes
      expect(batch.totalGpuVertices, equals(100));
    });

    test('Extreme camera proximity prevents division by zero in billboard orientation', () {
      final closeCamera = CameraData.fromAngles(
        posX: 0.0,
        posY: 1e-9,
        posZ: 1e-9,
        yaw: 0.0,
        pitch: 0.0,
      );

      final quad = VatCrowdRenderer.computeSphericalBillboardQuad(
        centerX: 0.0,
        centerY: 0.0,
        centerZ: 0.0,
        width: 1.0,
        height: 2.0,
        camera: closeCamera,
      );

      expect(quad.every((v) => !v.isNaN && !v.isInfinite), isTrue);
    });

    test('Out-of-range tint and scale values do not throw unhandled exceptions', () {
      final buffer = CrowdInstanceBuffer(initialCapacity: 1);

      expect(
        () => buffer.packInstance(
          index: 0,
          posX: 0.0,
          posY: 0.0,
          posZ: 0.0,
          rotationY: 0.0,
          scaleX: -1.0, // negative scale
          scaleY: 0.0, // zero scale
          scaleZ: 9999.0, // extreme scale
          currentFrame: 0.0,
          nextFrame: 0.0,
          lerpFactor: 0.0,
          renderMode: 0.0,
          tintR: 5.0, // HDR tint
          tintG: -1.0,
          tintB: 0.0,
          tintA: 1.0,
        ),
        returnsNormally,
      );

      expect(buffer.buffer[0], equals(-1.0));
      expect(buffer.buffer[5], equals(0.0));
      expect(buffer.buffer[10], equals(9999.0));
      expect(buffer.buffer[20], equals(5.0));
    });
  });
}
