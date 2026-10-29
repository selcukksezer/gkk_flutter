import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/core/shaders/shader_registry.dart';
import 'package:gkk_flutter/core/vfx/ground_decal_system.dart';

// =============================================================================
// Architectural Contracts & Adapters
// =============================================================================

/// Alias for [OrientedBoundingBox] matching Studio Division V4-09 test contract.
typedef OrientedBoundingBox3D = OrientedBoundingBox;

/// Custom painter integrating [GroundDecalSystem] with GPU [ui.FragmentShader]
/// runtime effects and falling back smoothly to canvas primitives.
class GroundDecalShaderPainter extends CustomPainter {
  final GroundDecalSystem system;
  final ui.FragmentShader? shader;
  final ShaderUniformTarget? uniformTarget;
  final Offset cameraOffset;
  final double pixelsPerUnit;
  final double currentTime;
  final Vector3D? surfaceNormal;

  GroundDecalShaderPainter({
    required this.system,
    this.shader,
    this.uniformTarget,
    this.cameraOffset = Offset.zero,
    this.pixelsPerUnit = 24.0,
    this.currentTime = 0.0,
    this.surfaceNormal,
  });

  /// Binds all 26 decal uniform floats to a [ShaderUniformTarget] (such as
  /// [BufferUniformTarget] or [FragmentShaderTarget]) matching GLSL declaration
  /// order in `shaders/vfx/ground_decal.frag`.
  static void bindUniforms({
    required ShaderUniformTarget target,
    required DecalInstance decal,
    required Size resolution,
    required Offset groundViewportOrigin,
    required double currentTime,
    Vector3D? surfaceNormal,
  }) {
    final sNormal = surfaceNormal ?? Vector3D.groundUp;
    final pNormal = decal.obb.axisZ;

    // Convert world position (X, Z) to screen/render target coordinates
    final screenX = decal.position.x - groundViewportOrigin.dx;
    final screenY = decal.position.z - groundViewportOrigin.dy;

    // Decal rotation around projection axis (yaw)
    final yaw = math.atan2(decal.obb.axisY.x, decal.obb.axisY.z);

    // Decal type index: 0=scorch, 1=blood, 2=cracked, 3=slash, 4=custom
    final typeIndex = decal.type.index.toDouble();

    // 0, 1: uResolution
    target.setFloat(0, resolution.width);
    target.setFloat(1, resolution.height);

    // 2, 3: uDecalCenter
    target.setFloat(2, screenX);
    target.setFloat(3, screenY);

    // 4, 5: uDecalHalfSize (in pixels)
    target.setFloat(4, decal.halfExtents.x * 20.0);
    target.setFloat(5, decal.halfExtents.y * 20.0);

    // 6: uDecalRotation
    target.setFloat(6, yaw);

    // 7: uOpacity
    target.setFloat(7, decal.currentOpacity);

    // 8, 9, 10, 11: uAlbedoTint (RGBA)
    target.setFloat(8, decal.color.r);
    target.setFloat(9, decal.color.g);
    target.setFloat(10, decal.color.b);
    target.setFloat(11, decal.color.a);

    // 12: uNormalStrength
    target.setFloat(12, decal.normalStrength);

    // 13: uRoughnessMod
    target.setFloat(13, decal.roughness);

    // 14: uDecalType
    target.setFloat(14, typeIndex);

    // 15, 16, 17: uSurfaceNormal
    target.setFloat(15, sNormal.x);
    target.setFloat(16, sNormal.y);
    target.setFloat(17, sNormal.z);

    // 18, 19, 20: uProjectorNormal
    target.setFloat(18, pNormal.x);
    target.setFloat(19, pNormal.y);
    target.setFloat(20, pNormal.z);

    // 21: uAngleCutoff
    target.setFloat(21, decal.angleCutoff);

    // 22: uEdgeSoftness
    target.setFloat(22, decal.edgeSoftness);

    // 23: uTime
    target.setFloat(23, currentTime);

    // 24: uProceduralSeed
    target.setFloat(24, decal.proceduralSeed);

    // 25: uDepthClip
    target.setFloat(25, 1.0);
  }

  /// Builds a continuous Float32List containing all 26 uniform floats.
  static Float32List buildUniformBuffer({
    required DecalInstance decal,
    required Size resolution,
    required Offset groundViewportOrigin,
    required double currentTime,
    Vector3D? surfaceNormal,
  }) {
    final target = BufferUniformTarget();
    bindUniforms(
      target: target,
      decal: decal,
      resolution: resolution,
      groundViewportOrigin: groundViewportOrigin,
      currentTime: currentTime,
      surfaceNormal: surfaceNormal,
    );
    final floats = target.toFloatList(minLength: 26);
    return Float32List.fromList(floats);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (uniformTarget != null) {
      for (final decal in system.activeDecals) {
        if (decal.currentOpacity <= 0.001) continue;
        bindUniforms(
          target: uniformTarget!,
          decal: decal,
          resolution: size,
          groundViewportOrigin: cameraOffset,
          currentTime: currentTime,
          surfaceNormal: surfaceNormal,
        );
      }
    }

    if (shader != null) {
      final s = shader!;
      for (final decal in system.activeDecals) {
        if (decal.currentOpacity <= 0.001) continue;
        DecalShaderUniforms.bindToShader(
          shader: s,
          decal: decal,
          resolution: size,
          groundViewportOrigin: cameraOffset,
          currentTime: currentTime,
          surfaceNormal: surfaceNormal,
        );
        final paint = Paint()..shader = s;
        canvas.drawRect(Offset.zero & size, paint);
      }
    } else {
      final fallback = GroundDecalPainter(
        system: system,
        cameraOffset: cameraOffset,
        pixelsPerUnit: pixelsPerUnit,
      );
      fallback.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant GroundDecalShaderPainter oldDelegate) => true;
}

// =============================================================================
// Main Test Suite
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GLSL Shader File Verification (ground_decal.frag)', () {
    late File shaderFile;
    late String shaderCode;

    setUpAll(() {
      shaderFile = File('shaders/vfx/ground_decal.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'shaders/vfx/ground_decal.frag must exist');
      shaderCode = shaderFile.readAsStringSync();
    });

    test('Shader header has version 460 core and flutter runtime_effect include', () {
      expect(shaderCode, contains('#version 460 core'));
      expect(shaderCode, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderCode, contains('precision highp float;'));
    });

    test('Shader declares all 26 numeric uniform floats strictly before samplers', () {
      expect(shaderCode, contains('uniform vec2 uResolution;')); // [0..1]
      expect(shaderCode, contains('uniform vec2 uDecalCenter;')); // [2..3]
      expect(shaderCode, contains('uniform vec2 uDecalHalfSize;')); // [4..5]
      expect(shaderCode, contains('uniform float uDecalRotation;')); // [6]
      expect(shaderCode, contains('uniform float uOpacity;')); // [7]
      expect(shaderCode, contains('uniform vec4 uAlbedoTint;')); // [8..11]
      expect(shaderCode, contains('uniform float uNormalStrength;')); // [12]
      expect(shaderCode, contains('uniform float uRoughnessMod;')); // [13]
      expect(shaderCode, contains('uniform float uDecalType;')); // [14]
      expect(shaderCode, contains('uniform vec3 uSurfaceNormal;')); // [15..17]
      expect(shaderCode, contains('uniform vec3 uProjectorNormal;')); // [18..20]
      expect(shaderCode, contains('uniform float uAngleCutoff;')); // [21]
      expect(shaderCode, contains('uniform float uEdgeSoftness;')); // [22]
      expect(shaderCode, contains('uniform float uTime;')); // [23]
      expect(shaderCode, contains('uniform float uProceduralSeed;')); // [24]
      expect(shaderCode, contains('uniform float uDepthClip;')); // [25]
    });

    test('Shader declares samplers strictly after all numeric uniforms', () {
      expect(shaderCode, contains('uniform sampler2D uGroundTexture;'));
      expect(shaderCode, contains('uniform sampler2D uDecalTexture;'));
      expect(shaderCode, contains('uniform sampler2D uNormalTexture;'));

      final int lastNumericIdx = shaderCode.indexOf('uniform float uDepthClip;');
      final int firstSamplerIdx = shaderCode.indexOf('uniform sampler2D uGroundTexture;');
      expect(firstSamplerIdx, greaterThan(lastNumericIdx),
          reason: 'Impeller requires sampler uniforms to follow numeric uniforms');
    });

    test('Shader implements mathematical projection and procedural generation algorithms', () {
      expect(shaderCode, contains('vec3 safeNormalize('));
      expect(shaderCode, contains('float hash21('));
      expect(shaderCode, contains('vec2 hash22('));
      expect(shaderCode, contains('float valueNoise('));
      expect(shaderCode, contains('float fbm('));
      expect(shaderCode, contains('vec3 voronoi('));
      expect(shaderCode, contains('vec3 blendRNM('));
      expect(shaderCode, contains('vec2 projectFragToDecalLocal('));
      expect(shaderCode, contains('vec3 reconstructWorldPosition('));
      expect(shaderCode, contains('evaluateScorchMark('));
      expect(shaderCode, contains('evaluateBloodSplatter('));
      expect(shaderCode, contains('evaluateCrackedEarth('));
      expect(shaderCode, contains('evaluateSlashGouge('));
      expect(shaderCode, contains('out vec4 fragColor;'));
    });

    test('Impeller offline compilation succeeds when impellerc is available', () {
      const String impellercPath =
          'F:\\flutter\\bin\\cache\\artifacts\\engine\\windows-x64\\impellerc.exe';
      final File tool = File(impellercPath);

      if (tool.existsSync()) {
        final ProcessResult result = Process.runSync(
          impellercPath,
          <String>[
            '--sksl',
            '--iplr',
            '--sl=shaders/vfx/ground_decal.iplr.tmp',
            '--spirv=shaders/vfx/ground_decal.spirv.tmp',
            '--input=shaders/vfx/ground_decal.frag',
            '--include=F:\\flutter\\bin\\cache\\artifacts\\engine\\windows-x64\\shader_lib',
          ],
        );

        final File tmpIplr = File('shaders/vfx/ground_decal.iplr.tmp');
        final File tmpSpirv = File('shaders/vfx/ground_decal.spirv.tmp');
        if (tmpIplr.existsSync()) tmpIplr.deleteSync();
        if (tmpSpirv.existsSync()) tmpSpirv.deleteSync();

        expect(result.exitCode, equals(0),
            reason: 'impellerc compilation error: ${result.stderr}');
      }
    });
  });

  group('Shader Registry Ground Decal Catalog Definition', () {
    late ShaderRegistry registry;

    setUp(() {
      registry = ShaderRegistry(loadDefaults: true);
    });

    test('ShaderCatalog.groundDecal descriptor matches 26 floats and 3 samplers', () {
      final ShaderDescriptor? desc =
          registry.getShaderDescriptor(ShaderCatalog.groundDecal);
      expect(desc, isNotNull);
      expect(desc!.category, equals(ShaderCategory.vfx));
      expect(desc.stage, equals(ShaderStage.fragment));
      expect(desc.totalFloatCount, equals(26));
      expect(desc.totalSamplerCount, equals(3));

      // Check all uniform offsets
      expect(desc.findUniform('uResolution')!.floatOffset, equals(0));
      expect(desc.findUniform('uDecalCenter')!.floatOffset, equals(2));
      expect(desc.findUniform('uDecalHalfSize')!.floatOffset, equals(4));
      expect(desc.findUniform('uDecalRotation')!.floatOffset, equals(6));
      expect(desc.findUniform('uOpacity')!.floatOffset, equals(7));
      expect(desc.findUniform('uAlbedoTint')!.floatOffset, equals(8));
      expect(desc.findUniform('uNormalStrength')!.floatOffset, equals(12));
      expect(desc.findUniform('uRoughnessMod')!.floatOffset, equals(13));
      expect(desc.findUniform('uDecalType')!.floatOffset, equals(14));
      expect(desc.findUniform('uSurfaceNormal')!.floatOffset, equals(15));
      expect(desc.findUniform('uProjectorNormal')!.floatOffset, equals(18));
      expect(desc.findUniform('uAngleCutoff')!.floatOffset, equals(21));
      expect(desc.findUniform('uEdgeSoftness')!.floatOffset, equals(22));
      expect(desc.findUniform('uTime')!.floatOffset, equals(23));
      expect(desc.findUniform('uProceduralSeed')!.floatOffset, equals(24));
      expect(desc.findUniform('uDepthClip')!.floatOffset, equals(25));

      // Check samplers
      expect(desc.findSampler('uGroundTexture')!.samplerIndex, equals(0));
      expect(desc.findSampler('uDecalTexture')!.samplerIndex, equals(1));
      expect(desc.findSampler('uNormalTexture')!.samplerIndex, equals(2));
    });

    test('Warmup parameters populate exactly 26 floats matching GPU driver expectations', () {
      final ShaderDescriptor desc =
          registry.getShaderDescriptor(ShaderCatalog.groundDecal)!;
      expect(desc.warmupParameters, isNotNull);
      expect(desc.warmupParameters!.length, equals(26));

      final target = BufferUniformTarget();
      final pipeline = ShaderPipeline(registry: registry);
      pipeline.warmUpTarget(target, desc);

      expect(target.getFloat(0), equals(1.0)); // resolution.width
      expect(target.getFloat(1), equals(1.0)); // resolution.height
      expect(target.getFloat(4), equals(50.0)); // halfSize.x
      expect(target.getFloat(5), equals(50.0)); // halfSize.y
      expect(target.getFloat(7), equals(1.0)); // opacity
      expect(target.getFloat(21), equals(0.5)); // angleCutoff
      expect(target.getFloat(25), equals(1.0)); // depthClip
    });
  });

  group('GroundDecalShaderPainter Uniform Binding Tests', () {
    test('bindUniforms maps every individual uniform float correctly', () {
      final target = BufferUniformTarget();
      final decal = DecalInstance(
        type: DecalType.bloodSplatter,
        position: const Vector3D(100.0, 0.0, 200.0),
        size: const Vector3D(6.0, 8.0, 2.0), // halfExtents: (3.0, 4.0, 1.0)
        color: const ui.Color(0xFF881122),
        baseOpacity: 0.85,
        roughness: 0.12,
        normalStrength: 1.45,
        angleCutoff: 0.42,
        edgeSoftness: 0.18,
        proceduralSeed: 123.456,
      );

      const resolution = Size(1920.0, 1080.0);
      const viewportOrigin = Offset(50.0, 80.0);
      const currentTime = 7.5;
      const surfaceNormal = Vector3D(0.0, 1.0, 0.0);

      GroundDecalShaderPainter.bindUniforms(
        target: target,
        decal: decal,
        resolution: resolution,
        groundViewportOrigin: viewportOrigin,
        currentTime: currentTime,
        surfaceNormal: surfaceNormal,
      );

      // uResolution [0..1]
      expect(target.getFloat(0), equals(1920.0));
      expect(target.getFloat(1), equals(1080.0));

      // uDecalCenter [2..3]: (100 - 50, 200 - 80) = (50.0, 120.0)
      expect(target.getFloat(2), equals(50.0));
      expect(target.getFloat(3), equals(120.0));

      // uDecalHalfSize [4..5]: (3.0 * 20, 4.0 * 20) = (60.0, 80.0)
      expect(target.getFloat(4), equals(60.0));
      expect(target.getFloat(5), equals(80.0));

      // uDecalRotation [6]
      final expectedYaw = math.atan2(decal.obb.axisY.x, decal.obb.axisY.z);
      expect(target.getFloat(6), closeTo(expectedYaw, 1e-5));

      // uOpacity [7]
      expect(target.getFloat(7), closeTo(0.85, 1e-5));

      // uAlbedoTint [8..11]
      expect(target.getFloat(8), closeTo(decal.color.r, 1e-4));
      expect(target.getFloat(9), closeTo(decal.color.g, 1e-4));
      expect(target.getFloat(10), closeTo(decal.color.b, 1e-4));
      expect(target.getFloat(11), closeTo(decal.color.a, 1e-4));

      // uNormalStrength [12]
      expect(target.getFloat(12), equals(1.45));

      // uRoughnessMod [13]
      expect(target.getFloat(13), equals(0.12));

      // uDecalType [14]: bloodSplatter = 1.0
      expect(target.getFloat(14), equals(1.0));

      // uSurfaceNormal [15..17]
      expect(target.getFloat(15), equals(0.0));
      expect(target.getFloat(16), equals(1.0));
      expect(target.getFloat(17), equals(0.0));

      // uProjectorNormal [18..20] from decal.obb.axisZ
      expect(target.getFloat(18), closeTo(decal.obb.axisZ.x, 1e-5));
      expect(target.getFloat(19), closeTo(decal.obb.axisZ.y, 1e-5));
      expect(target.getFloat(20), closeTo(decal.obb.axisZ.z, 1e-5));

      // uAngleCutoff [21]
      expect(target.getFloat(21), equals(0.42));

      // uEdgeSoftness [22]
      expect(target.getFloat(22), equals(0.18));

      // uTime [23]
      expect(target.getFloat(23), equals(7.5));

      // uProceduralSeed [24]
      expect(target.getFloat(24), equals(123.456));

      // uDepthClip [25]
      expect(target.getFloat(25), equals(1.0));
    });

    test('buildUniformBuffer returns exactly 26 contiguous floats for all DecalTypes', () {
      final system = GroundDecalSystem(maxDecals: 8);

      final scorch = system.spawnScorchMark(position: const Vector3D(10, 0, 10));
      final blood = system.spawnBloodSplatter(position: const Vector3D(20, 0, 20));
      final cracked = system.spawnCrackedEarth(position: const Vector3D(30, 0, 30));
      final slash = system.spawnSlashGouge(
        position: const Vector3D(40, 0, 40),
        strikeDirection: const Vector3D(1, 0, 0),
      );

      final types = [scorch, blood, cracked, slash];
      final expectedTypeIndices = [0.0, 1.0, 2.0, 3.0];

      for (int i = 0; i < types.length; i++) {
        final buffer = GroundDecalShaderPainter.buildUniformBuffer(
          decal: types[i],
          resolution: const Size(800.0, 600.0),
          groundViewportOrigin: Offset.zero,
          currentTime: 1.0,
        );

        expect(buffer.length, equals(26));
        expect(buffer[0], equals(800.0));
        expect(buffer[1], equals(600.0));
        expect(buffer[14], equals(expectedTypeIndices[i]),
            reason: 'uDecalType mismatch for ${types[i].type}');
        expect(buffer[25], equals(1.0)); // uDepthClip
      }
    });
  });

  group('OBB Projection Maths & Surface Normal Angle Cutoff', () {
    test('OrientedBoundingBox3D alias operates identically to OrientedBoundingBox', () {
      final obb = OrientedBoundingBox3D(
        center: const Vector3D(10.0, 5.0, 15.0),
        halfExtents: const Vector3D(2.0, 3.0, 4.0),
        orientation: QuaternionD.identity,
      );

      expect(obb.center.x, equals(10.0));
      expect(obb.size.x, equals(4.0));
      expect(obb.size.y, equals(6.0));
      expect(obb.size.z, equals(8.0));
      expect(obb.boundingRadius, closeTo(math.sqrt(4 + 9 + 16), 1e-5));
    });

    test('2D Screen-to-OBB local projection formula parity with GLSL projectFragToDecalLocal', () {
      // Local coordinate formula: P_local = S^-1 * R(-theta) * (P_frag - C_center)
      const center = Offset(500.0, 400.0);
      const halfSize = Offset(100.0, 50.0);
      const rotation = math.pi / 4.0; // 45 deg

      Offset projectFragToDecalLocal(Offset fragCoord, Offset c, Offset hs, double rot) {
        final offset = fragCoord - c;
        final cosR = math.cos(-rot);
        final sinR = math.sin(-rot);
        final rotOffset = Offset(
          offset.dx * cosR - offset.dy * sinR,
          offset.dx * sinR + offset.dy * cosR,
        );
        return Offset(
          rotOffset.dx / math.max(hs.dx, 1.0),
          rotOffset.dy / math.max(hs.dy, 1.0),
        );
      }

      // 1. Center fragment maps exactly to (0.0, 0.0)
      final centerLocal = projectFragToDecalLocal(center, center, halfSize, rotation);
      expect(centerLocal.dx, closeTo(0.0, 1e-5));
      expect(centerLocal.dy, closeTo(0.0, 1e-5));

      // 2. Fragment along unrotated X axis offset by (100 * cos(45), 100 * sin(45))
      final rotatedOffset = Offset(100.0 * math.cos(rotation), 100.0 * math.sin(rotation));
      final edgeFrag = center + rotatedOffset;
      final edgeLocal = projectFragToDecalLocal(edgeFrag, center, halfSize, rotation);
      expect(edgeLocal.dx, closeTo(1.0, 1e-5));
      expect(edgeLocal.dy, closeTo(0.0, 1e-5));
    });

    test('OBB point containment and depth normalization', () {
      final obb = OrientedBoundingBox3D(
        center: const Vector3D(0.0, 0.0, 0.0),
        halfExtents: const Vector3D(5.0, 2.0, 5.0),
        orientation: QuaternionD.identity,
      );

      // Point inside
      final insideRes = obb.projectPoint(
        worldPoint: const Vector3D(2.5, 0.0, 2.5),
        surfaceNormal: Vector3D.groundUp,
      );
      expect(insideRes.isInside, isTrue);
      expect(insideRes.uv.dx, closeTo(0.75, 1e-5)); // (2.5/5.0 * 0.5) + 0.5
      expect(insideRes.uv.dy, closeTo(0.5, 1e-5));
      expect(insideRes.depth, closeTo(0.5, 1e-5)); // Z=2.5 / 5.0

      // Point outside
      final outsideRes = obb.projectPoint(
        worldPoint: const Vector3D(10.0, 0.0, 0.0),
        surfaceNormal: Vector3D.groundUp,
      );
      expect(outsideRes.isInside, isFalse);
    });

    test('Surface normal alignment angle cutoff smoothly attenuates glancing surfaces', () {
      final obb = OrientedBoundingBox3D(
        center: const Vector3D(0.0, 10.0, 0.0),
        halfExtents: const Vector3D(5.0, 5.0, 10.0),
        // Projector pointing down along -Y
        orientation: QuaternionD.fromAxisAngle(Vector3D.unitX, math.pi * 0.5),
      );

      // 1. Directly facing ground (0, 1, 0): full contribution
      final direct = obb.projectPoint(
        worldPoint: Vector3D.zero,
        surfaceNormal: const Vector3D(0.0, 1.0, 0.0),
        angleCutoff: 0.35,
      );
      expect(direct.angleAttenuation, closeTo(1.0, 1e-2));
      expect(direct.hasContribution, isTrue);

      // 2. 45-degree slope (cos(45) = 0.707 > 0.35): strong contribution
      final slope45 = obb.projectPoint(
        worldPoint: Vector3D.zero,
        surfaceNormal: const Vector3D(0.707, 0.707, 0.0),
        angleCutoff: 0.35,
      );
      expect(slope45.angleAttenuation, greaterThan(0.9));

      // 3. Steep wall (normal = 1, 0, 0 perpendicular to projector): zero contribution
      final wall = obb.projectPoint(
        worldPoint: Vector3D.zero,
        surfaceNormal: const Vector3D(1.0, 0.0, 0.0),
        angleCutoff: 0.35,
      );
      expect(wall.angleAttenuation, closeTo(0.0, 1e-2));
      expect(wall.hasContribution, isFalse);
    });

    test('Edge softness produces smooth Hermite boundary decay', () {
      final obb = OrientedBoundingBox3D(
        center: Vector3D.zero,
        halfExtents: const Vector3D(10.0, 10.0, 10.0),
        orientation: QuaternionD.identity,
      );

      // Center: 1.0 falloff
      final pCenter = obb.projectPoint(
        worldPoint: Vector3D.zero,
        surfaceNormal: Vector3D.groundUp,
        edgeSoftness: 0.2,
      );
      expect(pCenter.edgeFalloff, equals(1.0));

      // Halfway towards border (normX = 0.5 < 1.0 - 0.2): still 1.0
      final pMid = obb.projectPoint(
        worldPoint: const Vector3D(5.0, 0.0, 0.0),
        surfaceNormal: Vector3D.groundUp,
        edgeSoftness: 0.2,
      );
      expect(pMid.edgeFalloff, equals(1.0));

      // In softness margin (normX = 0.9 in [0.8 .. 1.0])
      final pSoft = obb.projectPoint(
        worldPoint: const Vector3D(9.0, 0.0, 0.0),
        surfaceNormal: Vector3D.groundUp,
        edgeSoftness: 0.2,
      );
      expect(pSoft.edgeFalloff, greaterThan(0.0));
      expect(pSoft.edgeFalloff, lessThan(1.0));

      // Beyond boundary (normX >= 1.0)
      final pEdge = obb.projectPoint(
        worldPoint: const Vector3D(10.0, 0.0, 0.0),
        surfaceNormal: Vector3D.groundUp,
        edgeSoftness: 0.2,
      );
      expect(pEdge.edgeFalloff, closeTo(0.0, 1e-4));
    });
  });

  group('DecalRingBuffer Circular Eviction & Zero-Allocation Recycling', () {
    test('DecalRingBuffer maintains strict capacity cap and circular FIFO replacement', () {
      const int cap = 5;
      final pool = DecalRingBuffer(capacity: cap);

      expect(pool.capacity, equals(5));
      expect(pool.activeCount, equals(0));
      expect(pool.totalSpawned, equals(0));
      expect(pool.totalEvictions, equals(0));

      final allocated = <DecalInstance>[];
      for (int i = 0; i < cap; i++) {
        final d = pool.allocateNext()
          ..initialize(
            id: i,
            type: DecalType.scorchMark,
            position: Vector3D(i.toDouble(), 0, 0),
            orientation: QuaternionD.identity,
            size: Vector3D.one,
            color: const ui.Color(0xFF000000),
          );
        allocated.add(d);
      }

      expect(pool.activeCount, equals(5));
      expect(pool.totalSpawned, equals(5));
      expect(pool.totalEvictions, equals(0));

      // 6th allocation evicts slot 0 (allocated[0])
      final d6 = pool.allocateNext();
      expect(pool.totalEvictions, equals(1));
      expect(identical(d6, allocated[0]), isTrue,
          reason: 'Zero-allocation ring buffer must reuse the exact memory instance');

      d6.initialize(
        id: 6,
        type: DecalType.bloodSplatter,
        position: const Vector3D(6, 0, 0),
        orientation: QuaternionD.identity,
        size: Vector3D.one,
        color: const ui.Color(0xFF000000),
      );

      // 7th allocation evicts slot 1 (allocated[1])
      final d7 = pool.allocateNext();
      expect(pool.totalEvictions, equals(2));
      expect(identical(d7, allocated[1]), isTrue);

      expect(pool.activeCount, equals(5)); // Remains strictly capped at 5
      expect(pool.totalSpawned, equals(7));
    });

    test('Zero dynamic allocations during repeated high-frequency spawn cycles', () {
      final pool = DecalRingBuffer(capacity: 16);

      // Simulate 500 rapid combat events
      for (int i = 0; i < 500; i++) {
        final d = pool.allocateNext();
        d.initialize(
          id: i,
          type: DecalType.values[i % DecalType.values.length],
          position: Vector3D(i.toDouble(), 0, 0),
          orientation: QuaternionD.identity,
          size: Vector3D.one,
          color: const ui.Color(0xFFFFFFFF),
        );
      }

      expect(pool.activeCount, equals(16));
      expect(pool.totalSpawned, equals(500));
      expect(pool.totalEvictions, equals(500 - 16));
    });

    test('updateAll decrements activeCount when decals naturally expire', () {
      final pool = DecalRingBuffer(capacity: 4);

      final d0 = pool.allocateNext()..initialize(
        id: 0,
        type: DecalType.scorchMark,
        position: Vector3D.zero,
        orientation: QuaternionD.identity,
        size: Vector3D.one,
        color: const ui.Color(0xFF000000),
        totalLifetime: 2.0,
      );

      pool.allocateNext().initialize(
        id: 1,
        type: DecalType.bloodSplatter,
        position: Vector3D.zero,
        orientation: QuaternionD.identity,
        size: Vector3D.one,
        color: const ui.Color(0xFF000000),
        totalLifetime: 10.0,
      );

      expect(pool.activeCount, equals(2));

      // Advance by 3 seconds: d0 expires (lifetime 2.0 < 3.0), d1 remains active
      pool.updateAll(3.0);
      expect(d0.isExpired, isTrue);
      expect(d0.isActive, isFalse);
      expect(pool.activeCount, equals(1));
    });
  });

  group('Fade Curve Decay Math & Opacity Timelines', () {
    test('Linear fade curve scales directly with remaining time ratio', () {
      final decal = DecalInstance(
        totalLifetime: 10.0,
        fadeDuration: 4.0, // fades from t=6 to t=10
        fadeCurve: DecalFadeCurve.linear,
        baseOpacity: 1.0,
      );

      // At t = 6.0 (fade starts)
      decal.update(6.0);
      expect(decal.currentOpacity, closeTo(1.0, 1e-6));

      // At t = 8.0 (50% through fade window)
      decal.update(2.0);
      expect(decal.currentOpacity, closeTo(0.5, 1e-6));

      // At t = 9.0 (75% through fade window, 25% remaining)
      decal.update(1.0);
      expect(decal.currentOpacity, closeTo(0.25, 1e-6));

      // At t = 10.0 (lifetime ended)
      decal.update(1.0);
      expect(decal.currentOpacity, equals(0.0));
      expect(decal.isExpired, isTrue);
    });

    test('Ease-In / Quadratic fade curve satisfies t^2 decay', () {
      final decal = DecalInstance(
        totalLifetime: 4.0,
        fadeDuration: 4.0,
        fadeCurve: DecalFadeCurve.quadratic,
        baseOpacity: 1.0,
      );

      // After 2.0s: remaining progress = (4 - 2) / 4 = 0.5.
      // Quadratic: (0.5)^2 = 0.25
      decal.update(2.0);
      expect(decal.currentOpacity, closeTo(0.25, 1e-6));

      // After another 1.0s (total 3.0s): remaining progress = 0.25.
      // Quadratic: (0.25)^2 = 0.0625
      decal.update(1.0);
      expect(decal.currentOpacity, closeTo(0.0625, 1e-6));
    });

    test('Ease-Out / SmoothStep fade curve satisfies Hermite cubic decay', () {
      final decal = DecalInstance(
        totalLifetime: 10.0,
        fadeDuration: 10.0,
        fadeCurve: DecalFadeCurve.smoothStep,
        baseOpacity: 1.0,
      );

      // At 50% remaining (t = 5.0s elapsed):
      // Smoothstep(0.5) = 0.5 * 0.5 * (3 - 2 * 0.5) = 0.25 * 2 = 0.5
      decal.update(5.0);
      expect(decal.currentOpacity, closeTo(0.5, 1e-6));

      // At 75% remaining (t = 2.5s remaining from beginning = t=2.5s elapsed):
      final decal2 = DecalInstance(
        totalLifetime: 10.0,
        fadeDuration: 10.0,
        fadeCurve: DecalFadeCurve.smoothStep,
        baseOpacity: 1.0,
      );
      decal2.update(2.5); // remaining = 0.75
      const double expectedSmooth = 0.75 * 0.75 * (3.0 - 2.0 * 0.75); // 0.84375
      expect(decal2.currentOpacity, closeTo(expectedSmooth, 1e-6));
    });

    test('Exponential fade curve satisfies cubic t^3 decay', () {
      final decal = DecalInstance(
        totalLifetime: 8.0,
        fadeDuration: 8.0,
        fadeCurve: DecalFadeCurve.exponential,
        baseOpacity: 1.0,
      );

      // At t = 4.0s elapsed (50% remaining = 0.5):
      // Exponential: (0.5)^3 = 0.125
      decal.update(4.0);
      expect(decal.currentOpacity, closeTo(0.125, 1e-6));
    });

    test('Step / instant cutoff keeps base opacity until final expiration', () {
      final decal = DecalInstance(
        totalLifetime: 5.0,
        fadeDuration: 0.0, // step transition at expiration
        baseOpacity: 0.9,
      );

      decal.update(4.99);
      expect(decal.currentOpacity, closeTo(0.9, 1e-6));
      expect(decal.isExpired, isFalse);

      decal.update(0.02); // t = 5.01 > 5.0
      expect(decal.currentOpacity, equals(0.0));
      expect(decal.isExpired, isTrue);
    });

    test('Infinite lifetime decal never decays or expires', () {
      final decal = DecalInstance(
        totalLifetime: 0.0, // infinite
        baseOpacity: 0.75,
      );

      decal.update(10000.0);
      expect(decal.currentOpacity, closeTo(0.75, 1e-6));
      expect(decal.isExpired, isFalse);
      expect(decal.remainingLifetimeRatio, equals(1.0));
    });
  });

  group('Decal Normal Blending & Relief Shading Parity', () {
    // Krzysztof Barré-Brisebois & Stephen Hill RNM Normal Blend:
    Vector3D blendRNM(Vector3D nBase, Vector3D nDecal) {
      final t = nBase + const Vector3D(0.0, 0.0, 1.00001);
      final u = Vector3D(-nDecal.x, -nDecal.y, nDecal.z);
      final r = t * t.dot(u) - u * t.z;
      return r.normalized;
    }

    test('RNM blend of flat surface normal with flat decal normal yields flat normal', () {
      const nBase = Vector3D(0.0, 0.0, 1.0);
      const nDecal = Vector3D(0.0, 0.0, 1.0);

      final blended = blendRNM(nBase, nDecal);
      expect(blended.x, closeTo(0.0, 1e-4));
      expect(blended.y, closeTo(0.0, 1e-4));
      expect(blended.z, closeTo(1.0, 1e-4));
      expect(blended.length, closeTo(1.0, 1e-4));
    });

    test('Perturbed decal normal deflects blended tangent normal smoothly', () {
      const nBase = Vector3D(0.0, 0.0, 1.0);
      final nDecal = const Vector3D(0.4, 0.0, 1.0).normalized;

      final blended = blendRNM(nBase, nDecal);
      expect(blended.x, greaterThan(0.0));
      expect(blended.length, closeTo(1.0, 1e-4));
    });

    test('Relief lighting matches GLSL micro-surface shading clamp formula', () {
      // Formula: clamp(dot(blendedNormal, -nProj) * 0.5 + 0.5, 0.45, 1.0)
      double computeRelief(Vector3D blendedNormal, Vector3D nProj) {
        final dotVal = blendedNormal.dot(-nProj);
        return (dotVal * 0.5 + 0.5).clamp(0.45, 1.0);
      }

      // Aligned normals
      const normal = Vector3D(0.0, 0.0, 1.0);
      const proj = Vector3D(0.0, 0.0, -1.0);
      expect(computeRelief(normal, proj), closeTo(1.0, 1e-4));

      // Perpendicular normals
      const perpProj = Vector3D(1.0, 0.0, 0.0);
      expect(computeRelief(normal, perpProj), closeTo(0.5, 1e-4));
    });
  });

  group('Widget & CustomPainter Integration Tests', () {
    late GroundDecalSystem system;

    setUp(() {
      system = GroundDecalSystem(maxDecals: 16);
      system.spawnScorchMark(position: const Vector3D(0, 0, 0), radius: 2.0);
      system.spawnBloodSplatter(position: const Vector3D(5, 0, 5), radius: 1.5);
      system.spawnCrackedEarth(position: const Vector3D(-5, 0, 5), radius: 3.0);
      system.spawnSlashGouge(
        position: const Vector3D(0, 0, -5),
        strikeDirection: const Vector3D(1, 0, 1),
      );
    });

    testWidgets('GroundDecalShaderPainter renders in CustomPaint hierarchy without errors',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomPaint(
                size: const Size(600, 600),
                painter: GroundDecalShaderPainter(
                  system: system,
                  currentTime: 1.5,
                  pixelsPerUnit: 20.0,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('GroundDecalPainter paints all 4 distinct decal presets cleanly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 400),
              painter: GroundDecalPainter(
                system: system,
                cameraOffset: const Offset(0, 0),
                pixelsPerUnit: 16.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
        'GroundDecalShaderPainter populates ShaderUniformTarget during CustomPaint hierarchy paint',
        (tester) async {
      final target = BufferUniformTarget();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomPaint(
                size: const Size(800, 600),
                painter: GroundDecalShaderPainter(
                  system: system,
                  uniformTarget: target,
                  currentTime: 2.0,
                  pixelsPerUnit: 20.0,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump(const Duration(milliseconds: 100));

      expect(target.floatCount, greaterThanOrEqualTo(26));
      expect(target.getFloat(0), equals(800.0));
      expect(target.getFloat(1), equals(600.0));
      expect(target.getFloat(23), equals(2.0));
      expect(target.getFloat(25), equals(1.0));
    });

    test('GroundDecalShaderPainter shouldRepaint returns true', () {
      final p1 = GroundDecalShaderPainter(system: system, currentTime: 0.1);
      final p2 = GroundDecalShaderPainter(system: system, currentTime: 0.2);

      expect(p1.shouldRepaint(p2), isTrue);
    });
  });

  group('Adversarial & Boundary Stress Conditions', () {
    test('Zero-size decal is handled safely without division by zero', () {
      final obb = OrientedBoundingBox3D(
        center: Vector3D.zero,
        halfExtents: Vector3D.zero,
        orientation: QuaternionD.identity,
      );

      final res = obb.projectPoint(
        worldPoint: Vector3D.zero,
        surfaceNormal: Vector3D.groundUp,
      );

      expect(res.uv.dx.isFinite, isTrue);
      expect(res.uv.dy.isFinite, isTrue);
      expect(res.depth.isFinite, isTrue);
    });

    test('Extreme angle cutoff boundaries (0.01 and 0.99) do not produce NaN', () {
      final obb = OrientedBoundingBox3D(
        center: Vector3D.zero,
        halfExtents: Vector3D.one,
        orientation: QuaternionD.identity,
      );

      final resMin = obb.projectPoint(
        worldPoint: Vector3D.zero,
        surfaceNormal: Vector3D.groundUp,
        angleCutoff: 0.01,
      );
      expect(resMin.angleAttenuation.isFinite, isTrue);

      final resMax = obb.projectPoint(
        worldPoint: Vector3D.zero,
        surfaceNormal: Vector3D.groundUp,
        angleCutoff: 0.99,
      );
      expect(resMax.angleAttenuation.isFinite, isTrue);
    });

    test('DecalRingBuffer handles massive spawn churn and maintains integrity', () {
      final pool = DecalRingBuffer(capacity: 10);
      for (int i = 0; i < 2000; i++) {
        final d = pool.allocateNext();
        d.initialize(
          id: i,
          type: DecalType.slashGouge,
          position: Vector3D(i.toDouble(), 0, 0),
          orientation: QuaternionD.identity,
          size: Vector3D.one,
          color: const ui.Color(0xFFFFFFFF),
        );
      }

      expect(pool.activeCount, equals(10));
      expect(pool.totalSpawned, equals(2000));
      expect(pool.totalEvictions, equals(1990));
      expect(pool.activeDecals.length, equals(10));

      pool.clear();
      expect(pool.activeCount, equals(0));
      expect(pool.activeDecals.isEmpty, isTrue);
    });
  });

  group('GPU Decal Batching & Distance Culling (GroundDecalBatch)', () {
    late GroundDecalSystem batchSystem;

    setUp(() {
      batchSystem = GroundDecalSystem(maxDecals: 32);
    });

    test('generateRenderBatch collects active decals within maxDistance radius', () {
      final d1 = batchSystem.spawnScorchMark(position: const Vector3D(0, 0, 10), radius: 2.0);
      final d2 = batchSystem.spawnBloodSplatter(position: const Vector3D(20, 0, 20), radius: 1.5);
      final d3 = batchSystem.spawnCrackedEarth(position: const Vector3D(0, 0, 45), radius: 2.0);
      batchSystem.spawnScorchMark(position: const Vector3D(0, 0, 100), radius: 2.0);
      batchSystem.spawnBloodSplatter(position: const Vector3D(200, 0, 200), radius: 1.5);

      final GroundDecalBatch batch = batchSystem.generateRenderBatch(
        cameraPosition: Vector3D.zero,
        maxDistance: 50.0,
      );

      expect(batch.count, equals(3));
      expect(batch.items.length, equals(3));

      expect(batch.items[0].distanceToCamera, greaterThanOrEqualTo(batch.items[1].distanceToCamera));
      expect(batch.items[1].distanceToCamera, greaterThanOrEqualTo(batch.items[2].distanceToCamera));

      final batchDecals = batch.items.map((item) => item.decal).toList();
      expect(batchDecals, contains(d1));
      expect(batchDecals, contains(d2));
      expect(batchDecals, contains(d3));
    });

    test('generateRenderBatch accounts for OBB bounding radius in culling envelope', () {
      final onBorder = batchSystem.spawnCrackedEarth(
        position: const Vector3D(0, 0, 52.0),
        radius: 3.0,
      );

      batchSystem.spawnCrackedEarth(
        position: const Vector3D(0, 0, 75.0),
        radius: 3.0,
      );

      final batch = batchSystem.generateRenderBatch(
        cameraPosition: Vector3D.zero,
        maxDistance: 50.0,
      );

      expect(batch.count, equals(1));
      expect(batch.items.first.decal, equals(onBorder));
    });

    test('generateRenderBatch returns empty batch when all decals are expired', () {
      batchSystem.spawnScorchMark(
        position: const Vector3D(0, 0, 10),
        lifetime: 1.0,
        fadeDuration: 0.5,
      );

      batchSystem.update(2.0);

      final batch = batchSystem.generateRenderBatch(
        cameraPosition: Vector3D.zero,
        maxDistance: 50.0,
      );

      expect(batch.count, equals(0));
      expect(batch.items.isEmpty, isTrue);
    });
  });

  group('Dart 3 FragmentShader & Uniform Buffer Architecture Compliance', () {
    test('BufferUniformTarget implements ShaderUniformTarget without implementing base class FragmentShader', () {
      final ShaderUniformTarget target = BufferUniformTarget();
      expect(target, isA<ShaderUniformTarget>());
      expect(target, isA<BufferUniformTarget>());

      target.setFloat(0, 1920.0);
      target.setFloat(1, 1080.0);
      target.setFloat(25, 1.0);

      final bufferTarget = target as BufferUniformTarget;
      expect(bufferTarget.getFloat(0), equals(1920.0));
      expect(bufferTarget.getFloat(1), equals(1080.0));
      expect(bufferTarget.getFloat(25), equals(1.0));
      expect(bufferTarget.floatCount, equals(3));

      final floatList = bufferTarget.toFloatList(minLength: 26);
      expect(floatList.length, equals(26));
      expect(floatList[0], equals(1920.0));
      expect(floatList[1], equals(1080.0));
      expect(floatList[25], equals(1.0));
      expect(floatList[2], equals(0.0));
    });

    test('Decal uniform mapping strictly adheres to 26 floats without mock FragmentShader', () {
      final target = BufferUniformTarget();
      final decal = DecalInstance(
        type: DecalType.slashGouge,
        position: const Vector3D(15.0, 0.0, 30.0),
        size: const Vector3D(2.0, 4.0, 1.0),
        color: const ui.Color(0xFFFFAA00),
        baseOpacity: 0.95,
        roughness: 0.7,
        normalStrength: 1.3,
        angleCutoff: 0.5,
        edgeSoftness: 0.2,
        proceduralSeed: 99.0,
      );

      GroundDecalShaderPainter.bindUniforms(
        target: target,
        decal: decal,
        resolution: const Size(1280.0, 720.0),
        groundViewportOrigin: const Offset(5.0, 10.0),
        currentTime: 3.5,
        surfaceNormal: Vector3D.groundUp,
      );

      final list = target.toFloatList(minLength: 26);
      expect(list.length, equals(26));
      expect(list[0], equals(1280.0));
      expect(list[1], equals(720.0));
      expect(list[2], equals(10.0));
      expect(list[3], equals(20.0));
      expect(list[4], equals(20.0));
      expect(list[5], equals(40.0));
      expect(list[7], closeTo(0.95, 1e-5));
      expect(list[12], equals(1.3));
      expect(list[13], equals(0.7));
      expect(list[14], equals(3.0));
      expect(list[21], equals(0.5));
      expect(list[22], equals(0.2));
      expect(list[23], equals(3.5));
      expect(list[24], equals(99.0));
      expect(list[25], equals(1.0));
    });
  });
}
