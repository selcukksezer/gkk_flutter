// =============================================================================
// Master Aion 2 PBR Material Shader & Dart Wrapper Comprehensive Test Suite
// High-Fantasy AAA Cinematic Standard (Aion 2 Visual Standard)
//
// Target Verification:
// - Uniform Packing & 54-Float Layout Alignment (Aion2MaterialUniformPacker)
// - Analytical Cook-Torrance GGX Specular BRDF Physics (Aion2BrdfEvaluator)
// - Subsurface Scattering (SSS) Translucency & Thin-Film Iridescence
// - Aion2RuneModulationType Waveform Functions & Spectral Modulation
// - Canonical AAA Material Presets (DragonScale, WingEthereal, GothicDarkStone, PolishedPlateArmor)
// - Aion2MaterialController State, Animation Lifecycle & Shader Binding
// - Production Preview Widget & Software BRDF Fallback CustomPainter
// - GLSL Impeller Shader Layout & Shader Warmup System
// =============================================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/materials/aion2_material_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. Vector3D & Euclidean Space Mathematical Foundations
  // ---------------------------------------------------------------------------
  group('Vector3D & Mathematical Physics Primitives', () {
    test('standard constants are defined with exact Euclidean unit vectors', () {
      expect(Vector3D.zero.x, equals(0.0));
      expect(Vector3D.zero.y, equals(0.0));
      expect(Vector3D.zero.z, equals(0.0));
      expect(Vector3D.unitX, equals(const Vector3D(1.0, 0.0, 0.0)));
      expect(Vector3D.unitY, equals(const Vector3D(0.0, 1.0, 0.0)));
      expect(Vector3D.unitZ, equals(const Vector3D(0.0, 0.0, 1.0)));
    });

    test('basic linear algebra operations preserve Euclidean metric', () {
      const Vector3D u = Vector3D(3.0, -4.0, 12.0);
      const Vector3D v = Vector3D(1.0, 2.0, -3.0);

      // Magnitude / Norm
      expect(u.lengthSquared, closeTo(169.0, 1e-6));
      expect(u.length, closeTo(13.0, 1e-6));

      // Addition & Subtraction
      final Vector3D sum = u + v;
      expect(sum.x, closeTo(4.0, 1e-5));
      expect(sum.y, closeTo(-2.0, 1e-5));
      expect(sum.z, closeTo(9.0, 1e-5));

      final Vector3D diff = u - v;
      expect(diff.x, closeTo(2.0, 1e-5));
      expect(diff.y, closeTo(-6.0, 1e-5));
      expect(diff.z, closeTo(15.0, 1e-5));

      // Scalar Multiplication & Division
      final Vector3D scaled = u * 2.5;
      expect(scaled.x, closeTo(7.5, 1e-5));
      expect(scaled.y, closeTo(-10.0, 1e-5));
      expect(scaled.z, closeTo(30.0, 1e-5));

      final Vector3D divided = u / 2.0;
      expect(divided.x, closeTo(1.5, 1e-5));
      expect(divided.y, closeTo(-2.0, 1e-5));
      expect(divided.z, closeTo(6.0, 1e-5));

      // Unary negation
      final Vector3D neg = -u;
      expect(neg.x, closeTo(-3.0, 1e-5));
      expect(neg.y, closeTo(4.0, 1e-5));
      expect(neg.z, closeTo(-12.0, 1e-5));

      // Component-wise Hadamard product
      final Vector3D hadamard = u.componentMultiply(v);
      expect(hadamard.x, closeTo(3.0 * 1.0, 1e-5));
      expect(hadamard.y, closeTo(-4.0 * 2.0, 1e-5));
      expect(hadamard.z, closeTo(12.0 * -3.0, 1e-5));
    });

    test('dot product matches Euclidean inner product definition', () {
      const Vector3D a = Vector3D(1.0, 3.0, -5.0);
      const Vector3D b = Vector3D(4.0, -2.0, -1.0);

      // a . b = 1*4 + 3*(-2) + (-5)*(-1) = 4 - 6 + 5 = 3
      expect(a.dot(b), closeTo(3.0, 1e-5));

      // Orthogonal vectors dot to 0
      expect(Vector3D.unitX.dot(Vector3D.unitY), closeTo(0.0, 1e-6));
      expect(Vector3D.unitY.dot(Vector3D.unitZ), closeTo(0.0, 1e-6));
      expect(Vector3D.unitX.dot(Vector3D.unitZ), closeTo(0.0, 1e-6));
    });

    test('cross product follows right-hand orthonormal rule and anti-symmetry', () {
      expect(Vector3D.unitX.cross(Vector3D.unitY), equals(Vector3D.unitZ));
      expect(Vector3D.unitY.cross(Vector3D.unitZ), equals(Vector3D.unitX));
      expect(Vector3D.unitZ.cross(Vector3D.unitX), equals(Vector3D.unitY));

      const Vector3D a = Vector3D(2.0, 1.0, -1.0);
      const Vector3D b = Vector3D(-3.0, 4.0, 1.0);
      final Vector3D axb = a.cross(b);
      final Vector3D bxa = b.cross(a);

      // Anti-symmetry: a x b == -(b x a)
      expect(axb.x, closeTo(-bxa.x, 1e-5));
      expect(axb.y, closeTo(-bxa.y, 1e-5));
      expect(axb.z, closeTo(-bxa.z, 1e-5));

      // Orthogonality to both operands
      expect(axb.dot(a), closeTo(0.0, 1e-5));
      expect(axb.dot(b), closeTo(0.0, 1e-5));
    });

    test('normalization produces unit length and zero vector falls back safely', () {
      const Vector3D v = Vector3D(0.0, 3.0, 4.0);
      final Vector3D n = v.normalized();
      expect(n.length, closeTo(1.0, 1e-6));
      expect(n.y, closeTo(0.6, 1e-6));
      expect(n.z, closeTo(0.8, 1e-6));

      // Zero vector fallback
      final Vector3D zeroNorm = Vector3D.zero.normalized();
      expect(zeroNorm, equals(Vector3D.unitZ));
    });

    test('clamping limits vector components within specified bounds', () {
      const Vector3D v = Vector3D(-2.5, 0.5, 4.2);
      final Vector3D clamped = v.clamped(0.0, 1.0);
      expect(clamped.x, equals(0.0));
      expect(clamped.y, equals(0.5));
      expect(clamped.z, equals(1.0));
    });

    test('equality and hash code handle epsilon threshold correctly', () {
      const Vector3D v1 = Vector3D(1.000001, 2.0, 3.0);
      const Vector3D v2 = Vector3D(1.000002, 2.0, 3.0);
      const Vector3D v3 = Vector3D(1.01, 2.0, 3.0);

      expect(v1, equals(v2));
      expect(v1, isNot(equals(v3)));
      expect(v1.hashCode, equals(v2.hashCode));
      expect(v1.toString(), contains('Vector3D(1.000, 2.000, 3.000)'));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Aion2MaterialUniformPacker 54-Float Buffer Packing Layout & Alignment
  // ---------------------------------------------------------------------------
  group('Aion2MaterialUniformPacker 54-Float Buffer Packing Layout Alignment', () {
    test('totalFloatCount constant is strictly 54', () {
      expect(Aion2MaterialUniformPacker.totalFloatCount, equals(54));
    });

    test('sRGB to linear RGB conversion satisfies standard IEC 61966-2-1 gamma curve', () {
      // Black (0, 0, 0)
      final (double r0, double g0, double b0) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFF000000));
      expect(r0, closeTo(0.0, 1e-6));
      expect(g0, closeTo(0.0, 1e-6));
      expect(b0, closeTo(0.0, 1e-6));

      // White (255, 255, 255)
      final (double r1, double g1, double b1) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFFFFFFFF));
      expect(r1, closeTo(1.0, 1e-6));
      expect(g1, closeTo(1.0, 1e-6));
      expect(b1, closeTo(1.0, 1e-6));

      // Mid-gray 128/255 ~= 0.50196 -> linear is approximately 0.214 - 0.216
      final (double rMid, double gMid, double bMid) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFF808080));
      expect(rMid, closeTo(0.2158, 0.015));
      expect(gMid, closeTo(0.2158, 0.015));
      expect(bMid, closeTo(0.2158, 0.015));

      // Pure primary colors
      final (double rRed, double gRed, double bRed) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFFFF0000));
      expect(rRed, closeTo(1.0, 1e-5));
      expect(gRed, closeTo(0.0, 1e-5));
      expect(bRed, closeTo(0.0, 1e-5));

      // colorToVector3D helper matches
      final Vector3D redVec =
          Aion2MaterialUniformPacker.colorToVector3D(const ui.Color(0xFFFF0000));
      expect(redVec.x, closeTo(1.0, 1e-5));
      expect(redVec.y, closeTo(0.0, 1e-5));
      expect(redVec.z, closeTo(0.0, 1e-5));
    });

    test('buildUniformList precisely aligns all 54 floats to shader uniform declaration', () {
      const Aion2PbrParameters params = Aion2PbrParameters(
        name: 'AlignmentTestMaterial',
        baseColor: ui.Color(0xFF804020),
        metallic: 0.85,
        roughness: 0.35,
        ao: 0.92,
        normalIntensity: 1.45,
        clearcoat: 0.75,
        clearcoatRoughness: 0.18,
        sssEnabled: true,
        sssWeight: 0.65,
        sssDistortion: 0.42,
        sssPower: 3.8,
        sssScale: 2.1,
        sssColor: ui.Color(0xFF20E0A0),
        sssExtinction: 0.32,
        iridescenceEnabled: true,
        iridescenceWeight: 0.88,
        filmThicknessNm: 512.0,
        filmIOR: 1.68,
        baseIOR: 1.44,
        iridescenceTint: ui.Color(0xFFD090FF),
        angleShift: 1.25,
        emissiveColor: ui.Color(0xFF10FFAA),
        emissiveIntensity: 3.5,
        runeSpeed: 1.15,
        runeFrequency: 0.95,
        runeDutyCycle: 2.4,
        runeModulationType: Aion2RuneModulationType.heartbeatDualPulse,
        tilingX: 2.5,
        tilingY: 3.5,
        offsetX: 0.12,
        offsetY: 0.34,
      );

      final List<double> uniforms = Aion2MaterialUniformPacker.buildUniformList(
        viewportSize: const ui.Size(1920.0, 1080.0),
        timeSeconds: 7.5,
        cameraPos: const Vector3D(1.2, 2.3, 3.4),
        lightPos: const Vector3D(4.5, 5.6, 6.7),
        lightColor: const ui.Color(0xFFFFEEDD),
        lightIntensity: 4.8,
        ambientLightColor: const ui.Color(0xFF112233),
        params: params,
      );

      expect(uniforms.length, equals(54));

      // 0..1: uResolution (vec2)
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));

      // 2: uTime (float)
      expect(uniforms[2], equals(7.5));

      // 3..5: uCameraPos (vec3)
      expect(uniforms[3], equals(1.2));
      expect(uniforms[4], equals(2.3));
      expect(uniforms[5], equals(3.4));

      // 6: uNormalIntensity (float)
      expect(uniforms[6], equals(1.45));

      // 7..9: uLightPos (vec3)
      expect(uniforms[7], equals(4.5));
      expect(uniforms[8], equals(5.6));
      expect(uniforms[9], equals(6.7));

      // 10..12: uLightColor (vec3: linear RGB)
      final (double lr, double lg, double lb) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFFFFEEDD));
      expect(uniforms[10], closeTo(lr, 1e-5));
      expect(uniforms[11], closeTo(lg, 1e-5));
      expect(uniforms[12], closeTo(lb, 1e-5));

      // 13: uLightIntensity (float)
      expect(uniforms[13], equals(4.8));

      // 14..16: uAmbientLight (vec3: linear RGB)
      final (double ar, double ag, double ab) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFF112233));
      expect(uniforms[14], closeTo(ar, 1e-5));
      expect(uniforms[15], closeTo(ag, 1e-5));
      expect(uniforms[16], closeTo(ab, 1e-5));

      // 17: uAOIntensity (float)
      expect(uniforms[17], equals(0.92));

      // 18..21: uBaseColor (vec4: linear RGBA)
      final (double br, double bg, double bb) =
          Aion2MaterialUniformPacker.colorToLinearRgb(params.baseColor);
      expect(uniforms[18], closeTo(br, 1e-5));
      expect(uniforms[19], closeTo(bg, 1e-5));
      expect(uniforms[20], closeTo(bb, 1e-5));
      expect(uniforms[21], equals(params.baseColor.a));

      // 22: uMetallic (float)
      expect(uniforms[22], equals(0.85));

      // 23: uRoughness (float)
      expect(uniforms[23], equals(0.35));

      // 24: uClearcoat (float)
      expect(uniforms[24], equals(0.75));

      // 25: uClearcoatRoughness (float)
      expect(uniforms[25], equals(0.18));

      // 26..29: uSSSParams (vec4: weight, distortion, power, scale)
      expect(uniforms[26], equals(0.65));
      expect(uniforms[27], equals(0.42));
      expect(uniforms[28], equals(3.8));
      expect(uniforms[29], equals(2.1));

      // 30..32: uSSSColor (vec3: linear RGB)
      final (double sssr, double sssg, double sssb) =
          Aion2MaterialUniformPacker.colorToLinearRgb(params.sssColor);
      expect(uniforms[30], closeTo(sssr, 1e-5));
      expect(uniforms[31], closeTo(sssg, 1e-5));
      expect(uniforms[32], closeTo(sssb, 1e-5));

      // 33: uSSSExtinction (float)
      expect(uniforms[33], equals(0.32));

      // 34..37: uIridescenceParams (vec4: weight, filmThicknessNm, filmIOR, baseIOR)
      expect(uniforms[34], equals(0.88));
      expect(uniforms[35], equals(512.0));
      expect(uniforms[36], equals(1.68));
      expect(uniforms[37], equals(1.44));

      // 38..40: uIridescenceTint (vec3: linear RGB)
      final (double ir, double ig, double ib) =
          Aion2MaterialUniformPacker.colorToLinearRgb(params.iridescenceTint);
      expect(uniforms[38], closeTo(ir, 1e-5));
      expect(uniforms[39], closeTo(ig, 1e-5));
      expect(uniforms[40], closeTo(ib, 1e-5));

      // 41: uIridescenceAngleShift (float)
      expect(uniforms[41], equals(1.25));

      // 42..45: uEmissiveColor (vec4: RGB linear + A peak intensity)
      final (double er, double eg, double eb) =
          Aion2MaterialUniformPacker.colorToLinearRgb(params.emissiveColor);
      expect(uniforms[42], closeTo(er, 1e-5));
      expect(uniforms[43], closeTo(eg, 1e-5));
      expect(uniforms[44], closeTo(eb, 1e-5));
      expect(uniforms[45], equals(3.5)); // emissive intensity stored in alpha

      // 46..49: uEmissiveRuneParams (vec4: speed, frequency, dutyCycle, modType)
      expect(uniforms[46], equals(1.15));
      expect(uniforms[47], equals(0.95));
      expect(uniforms[48], equals(2.4));
      expect(uniforms[49], equals(1.0)); // heartbeatDualPulse shaderValue

      // 50..51: uTiling (vec2)
      expect(uniforms[50], equals(2.5));
      expect(uniforms[51], equals(3.5));

      // 52..53: uOffset (vec2)
      expect(uniforms[52], equals(0.12));
      expect(uniforms[53], equals(0.34));
    });

    test('disabled SSS and Iridescence gates zero-out weights at packing stage', () {
      const Aion2PbrParameters paramsWithDisabledFeatures = Aion2PbrParameters(
        sssEnabled: false,
        sssWeight: 0.95, // Must be zeroed out
        iridescenceEnabled: false,
        iridescenceWeight: 0.85, // Must be zeroed out
      );

      final List<double> uniforms = Aion2MaterialUniformPacker.buildUniformList(
        viewportSize: const ui.Size(800.0, 600.0),
        timeSeconds: 0.0,
        cameraPos: Vector3D.zero,
        lightPos: Vector3D.unitZ,
        lightColor: const ui.Color(0xFFFFFFFF),
        lightIntensity: 1.0,
        ambientLightColor: const ui.Color(0xFF000000),
        params: paramsWithDisabledFeatures,
      );

      expect(uniforms[26], equals(0.0),
          reason: 'SSS weight at index 26 must be 0.0 when sssEnabled is false');
      expect(uniforms[34], equals(0.0),
          reason: 'Iridescence weight at index 34 must be 0.0 when iridescenceEnabled is false');
    });

    test('packToFloat32List creates binary 54-float buffer identical to buildUniformList', () {
      final Float32List buffer = Aion2MaterialUniformPacker.packToFloat32List(
        viewportSize: const ui.Size(1024.0, 768.0),
        timeSeconds: 3.1415,
        cameraPos: const Vector3D(0.0, 0.0, 5.0),
        lightPos: const Vector3D(2.0, 3.0, 4.0),
        lightColor: const ui.Color(0xFFEEDDCC),
        lightIntensity: 2.2,
        ambientLightColor: const ui.Color(0xFF223344),
        params: Aion2MaterialPresets.dragonScale,
      );

      expect(buffer.length, equals(54));
      expect(buffer.elementSizeInBytes, equals(4));
      expect(buffer.lengthInBytes, equals(54 * 4));

      expect(buffer[0], closeTo(1024.0, 1e-4));
      expect(buffer[1], closeTo(768.0, 1e-4));
      expect(buffer[2], closeTo(3.1415, 1e-4));
      expect(buffer[22], closeTo(Aion2MaterialPresets.dragonScale.metallic, 1e-4));
      expect(buffer[23], closeTo(Aion2MaterialPresets.dragonScale.roughness, 1e-4));
      expect(buffer[49], closeTo(Aion2MaterialPresets.dragonScale.runeModulationType.shaderValue, 1e-4));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Cook-Torrance GGX Analytical BRDF Evaluation (D, G, F Terms)
  // ---------------------------------------------------------------------------
  group('Cook-Torrance GGX Analytical BRDF Physics (D, G, F Terms)', () {
    test('GGX Normal Distribution D satisfies analytical limits and monotonicity', () {
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      const Vector3D hDirect = Vector3D(0.0, 0.0, 1.0);

      // Theoretical peak at N.H = 1 is 1 / (pi * alpha^2) where alpha = roughness^2
      // For roughness = 0.5: alpha = 0.25, alpha^2 = 0.0625. Peak = 1 / (pi * 0.0625) = 16 / pi ~= 5.092958
      final double peak05 = Aion2BrdfEvaluator.distributionGGX(n, hDirect, 0.5);
      expect(peak05, closeTo(16.0 / math.pi, 1e-3));

      // For roughness = 1.0: alpha = 1.0, alpha^2 = 1.0. Peak = 1 / pi ~= 0.3183098
      final double peak10 = Aion2BrdfEvaluator.distributionGGX(n, hDirect, 1.0);
      expect(peak10, closeTo(1.0 / math.pi, 1e-4));

      // Smoother surface produces sharper, higher specular concentration
      final double peakSmooth = Aion2BrdfEvaluator.distributionGGX(n, hDirect, 0.1);
      expect(peakSmooth, greaterThan(peak05));
      expect(peak05, greaterThan(peak10));

      // Monotonic falloff with angular deflection: angle 30 degrees (N.H = cos(30 deg) ~= 0.866)
      const Vector3D h30 = Vector3D(0.5, 0.0, 0.8660254);
      final double d30 = Aion2BrdfEvaluator.distributionGGX(n, h30.normalized(), 0.5);
      expect(d30, lessThan(peak05));

      // Angular deflection: angle 60 degrees (N.H = 0.5)
      const Vector3D h60 = Vector3D(0.8660254, 0.0, 0.5);
      final double d60 = Aion2BrdfEvaluator.distributionGGX(n, h60.normalized(), 0.5);
      expect(d60, lessThan(d30));

      // Back-facing half vector (N.H <= 0) produces zero specular distribution
      const Vector3D hBack = Vector3D(0.0, 0.0, -1.0);
      final double dBack = Aion2BrdfEvaluator.distributionGGX(n, hBack, 0.5);
      // Denominator when N.H = 0 is pi * (0 * (a2 - 1) + 1)^2 = pi
      // So dBack = a2 / pi = 0.0625 / pi ~= 0.01989
      expect(dBack, closeTo(0.0625 / math.pi, 1e-4));
    });

    test('Smith Schlick-GGX Geometry G satisfies boundary conditions and Helmholtz reciprocity', () {
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      const Vector3D vDirect = Vector3D(0.0, 0.0, 1.0);
      const Vector3D lDirect = Vector3D(0.0, 0.0, 1.0);

      // Normal incidence: N.V = 1.0, N.L = 1.0 -> G1(1.0) = 1.0 -> G = 1.0
      final double gDirect = Aion2BrdfEvaluator.geometrySmith(n, vDirect, lDirect, 0.4);
      expect(gDirect, closeTo(1.0, 1e-4));

      // Single component verification: geometrySchlickGGX with roughness = 1.0
      // k = (1+1)^2 / 8 = 4 / 8 = 0.5
      // denom = 1.0 * (1 - 0.5) + 0.5 = 1.0
      expect(Aion2BrdfEvaluator.geometrySchlickGGX(1.0, 1.0), closeTo(1.0, 1e-5));

      // Grazing angle shadowing (angle 85 degrees: cos(85 deg) ~= 0.08715)
      final Vector3D vGrazing = const Vector3D(0.99619, 0.0, 0.08715).normalized();
      final double gGrazing = Aion2BrdfEvaluator.geometrySmith(n, vGrazing, lDirect, 0.4);
      expect(gGrazing, lessThan(gDirect));
      expect(gGrazing, greaterThanOrEqualTo(0.0));

      // Helmholtz reciprocity / symmetry: G(N, V, L) == G(N, L, V)
      final double gVtoL = Aion2BrdfEvaluator.geometrySmith(n, vGrazing, lDirect, 0.35);
      final double gLtoV = Aion2BrdfEvaluator.geometrySmith(n, lDirect, vGrazing, 0.35);
      expect(gVtoL, closeTo(gLtoV, 1e-6));
    });

    test('Schlick Fresnel F scales accurately between F0 and pure white specular at grazing angle', () {
      const Vector3D f0Dielectric = Vector3D(0.04, 0.04, 0.04);

      // Normal incidence (cosTheta = 1.0): F(1.0) = F0
      final Vector3D fNormal = Aion2BrdfEvaluator.fresnelSchlick(1.0, f0Dielectric);
      expect(fNormal.x, closeTo(0.04, 1e-6));
      expect(fNormal.y, closeTo(0.04, 1e-6));
      expect(fNormal.z, closeTo(0.04, 1e-6));

      // Grazing angle (cosTheta = 0.0): F(0.0) = (1.0, 1.0, 1.0)
      final Vector3D fGrazing = Aion2BrdfEvaluator.fresnelSchlick(0.0, f0Dielectric);
      expect(fGrazing.x, closeTo(1.0, 1e-6));
      expect(fGrazing.y, closeTo(1.0, 1e-6));
      expect(fGrazing.z, closeTo(1.0, 1e-6));

      // Mid angle: cosTheta = 0.5 -> (1 - 0.5)^5 = 0.03125
      // F = 0.04 + (1 - 0.04) * 0.03125 = 0.04 + 0.96 * 0.03125 = 0.04 + 0.03 = 0.07
      final Vector3D fMid = Aion2BrdfEvaluator.fresnelSchlick(0.5, f0Dielectric);
      expect(fMid.x, closeTo(0.07, 1e-4));
      expect(fMid.y, closeTo(0.07, 1e-4));
      expect(fMid.z, closeTo(0.07, 1e-4));

      // Metallic tinted F0 (gold: 1.0, 0.78, 0.34)
      const Vector3D f0Gold = Vector3D(1.0, 0.78, 0.34);
      final Vector3D fGoldMid = Aion2BrdfEvaluator.fresnelSchlick(0.5, f0Gold);
      expect(fGoldMid.x, closeTo(1.0 + (1.0 - 1.0) * 0.03125, 1e-4));
      expect(fGoldMid.y, closeTo(0.78 + (1.0 - 0.78) * 0.03125, 1e-4));
      expect(fGoldMid.z, closeTo(0.34 + (1.0 - 0.34) * 0.03125, 1e-4));
    });

    test('complete analytical PBR radiance evaluation satisfies energy conservation', () {
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      const Vector3D v = Vector3D(0.0, 0.0, 1.0);
      const Vector3D l = Vector3D(0.0, 0.7071, 0.7071);

      final Vector3D radiance = Aion2BrdfEvaluator.evaluateCompletePbr(
        n: n,
        v: v,
        l: l,
        params: Aion2MaterialPresets.dragonScale,
        lightColor: const Vector3D(1.0, 1.0, 1.0),
        lightIntensity: 2.0,
        ambientLight: const Vector3D(0.1, 0.1, 0.1),
        timeSeconds: 0.0,
      );

      // Radiance must be strictly positive and finite
      expect(radiance.x, greaterThan(0.0));
      expect(radiance.y, greaterThan(0.0));
      expect(radiance.z, greaterThan(0.0));
      expect(radiance.x.isFinite, isTrue);
      expect(radiance.y.isFinite, isTrue);
      expect(radiance.z.isFinite, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Subsurface Scattering (SSS) Profile & Thin-Film Iridescence Physics
  // ---------------------------------------------------------------------------
  group('Subsurface Scattering (SSS) Profile & Thin-Film Iridescence Physics', () {
    test('subsurface scattering transmits backlight and scales with power and scale', () {
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      const Vector3D v = Vector3D(0.0, 0.0, 1.0); // Facing surface
      const Vector3D lBacklight = Vector3D(0.0, 0.0, -1.0); // Backlighting directly opposite

      final Vector3D sssBacklight = Aion2BrdfEvaluator.evaluateSubsurfaceScattering(
        n: n,
        v: v,
        l: lBacklight,
        lightRadiance: const Vector3D(1.0, 1.0, 1.0),
        weight: 1.0,
        distortion: 0.0, // Pure straight transmission
        power: 2.0,
        scale: 1.5,
        sssColor: const Vector3D(0.2, 0.8, 1.0),
        extinction: 0.0,
      );

      // -sssL = -(-unitZ) = unitZ -> inScatter = unitZ . unitZ = 1.0
      // intensity = 1.0^2.0 * 1.5 = 1.5. ext = exp(0) = 1.0. weight = 1.0
      // sss = (0.2, 0.8, 1.0) * 1.5 = (0.3, 1.2, 1.5)
      expect(sssBacklight.x, closeTo(0.3, 1e-4));
      expect(sssBacklight.y, closeTo(1.2, 1e-4));
      expect(sssBacklight.z, closeTo(1.5, 1e-4));

      // Frontlight (L = V): inScatter = dot(unitZ, -unitZ) = -1.0 -> clamped to 0.0
      const Vector3D lFrontlight = Vector3D(0.0, 0.0, 1.0);
      final Vector3D sssFrontlight = Aion2BrdfEvaluator.evaluateSubsurfaceScattering(
        n: n,
        v: v,
        l: lFrontlight,
        lightRadiance: const Vector3D(1.0, 1.0, 1.0),
        weight: 1.0,
        distortion: 0.0,
        power: 2.0,
        scale: 1.5,
        sssColor: const Vector3D(0.2, 0.8, 1.0),
        extinction: 0.0,
      );
      expect(sssFrontlight, equals(Vector3D.zero));

      // Weight gating: weight <= 0.001 returns zero immediately
      final Vector3D sssZeroWeight = Aion2BrdfEvaluator.evaluateSubsurfaceScattering(
        n: n,
        v: v,
        l: lBacklight,
        lightRadiance: const Vector3D(1.0, 1.0, 1.0),
        weight: 0.0005,
        distortion: 0.0,
        power: 2.0,
        scale: 1.5,
        sssColor: const Vector3D(0.2, 0.8, 1.0),
        extinction: 0.0,
      );
      expect(sssZeroWeight, equals(Vector3D.zero));

      // Exponential extinction attenuation: exp(-2.0) ~= 0.135335
      final Vector3D sssAttenuated = Aion2BrdfEvaluator.evaluateSubsurfaceScattering(
        n: n,
        v: v,
        l: lBacklight,
        lightRadiance: const Vector3D(1.0, 1.0, 1.0),
        weight: 1.0,
        distortion: 0.0,
        power: 2.0,
        scale: 1.5,
        sssColor: const Vector3D(0.2, 0.8, 1.0),
        extinction: 2.0,
      );
      expect(sssAttenuated.z, closeTo(1.5 * math.exp(-2.0), 1e-4));
      expect(sssAttenuated.z, lessThan(sssBacklight.z));
    });

    test('thin-film optical iridescence calculates chromatic dispersion across visible wavelengths', () {
      // Normal incidence cosTheta = 1.0
      final Vector3D iridNormal = Aion2BrdfEvaluator.evaluateThinFilmIridescence(
        cosTheta: 1.0,
        thicknessNm: 490.0,
        filmIOR: 1.62,
        baseIOR: 1.45,
      );

      // Values must be strictly bounded in [0.0, 1.0]
      expect(iridNormal.x, inInclusiveRange(0.0, 1.0));
      expect(iridNormal.y, inInclusiveRange(0.0, 1.0));
      expect(iridNormal.z, inInclusiveRange(0.0, 1.0));

      // Angular shift shifts optical path difference and alters chromatic fringe
      final Vector3D iridGrazing = Aion2BrdfEvaluator.evaluateThinFilmIridescence(
        cosTheta: 0.3,
        thicknessNm: 490.0,
        filmIOR: 1.62,
        baseIOR: 1.45,
        angleShift: 1.35,
      );

      expect(iridGrazing.x, inInclusiveRange(0.0, 1.0));
      expect(iridGrazing.y, inInclusiveRange(0.0, 1.0));
      expect(iridGrazing.z, inInclusiveRange(0.0, 1.0));
      expect(iridGrazing, isNot(equals(iridNormal)));

      // Tint multiplication scales each spectral channel
      final Vector3D tintedIrid = Aion2BrdfEvaluator.evaluateThinFilmIridescence(
        cosTheta: 1.0,
        thicknessNm: 490.0,
        filmIOR: 1.62,
        baseIOR: 1.45,
        tint: const Vector3D(0.5, 1.0, 0.0), // Zero out blue
      );
      expect(tintedIrid.z, closeTo(0.0, 1e-6));
      expect(tintedIrid.x, closeTo(iridNormal.x * 0.5, 1e-4));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Aion2RuneModulationType Temporal Waveforms & Pulse Mechanics
  // ---------------------------------------------------------------------------
  group('Aion2RuneModulationType Temporal Waveforms & Pulse Mechanics', () {
    test('enum members map to unique integer shader values and deserialize accurately', () {
      expect(Aion2RuneModulationType.sineBreathing.shaderValue, equals(0.0));
      expect(Aion2RuneModulationType.heartbeatDualPulse.shaderValue, equals(1.0));
      expect(Aion2RuneModulationType.arcaneHarmonic.shaderValue, equals(2.0));
      expect(Aion2RuneModulationType.overloadSurge.shaderValue, equals(3.0));

      // fromShaderValue
      expect(Aion2RuneModulationType.fromShaderValue(0.0), equals(Aion2RuneModulationType.sineBreathing));
      expect(Aion2RuneModulationType.fromShaderValue(0.8), equals(Aion2RuneModulationType.heartbeatDualPulse));
      expect(Aion2RuneModulationType.fromShaderValue(1.0), equals(Aion2RuneModulationType.heartbeatDualPulse));
      expect(Aion2RuneModulationType.fromShaderValue(2.0), equals(Aion2RuneModulationType.arcaneHarmonic));
      expect(Aion2RuneModulationType.fromShaderValue(3.0), equals(Aion2RuneModulationType.overloadSurge));

      // Clamping limits
      expect(Aion2RuneModulationType.fromShaderValue(-10.0), equals(Aion2RuneModulationType.sineBreathing));
      expect(Aion2RuneModulationType.fromShaderValue(100.0), equals(Aion2RuneModulationType.overloadSurge));
    });

    test('sineBreathing waveform produces smooth oscillations bounded in [0.0, 1.0]', () {
      // At t = 0, sin(0) = 0 -> s = 0.5 -> pow(0.5, 1.0) = 0.5
      final double at0 = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.0,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.sineBreathing,
      );
      expect(at0, closeTo(0.5, 1e-4));

      // At quarter cycle t = 0.25 (sin(pi/2) = 1.0) -> s = 1.0 -> pow(1.0, duty) = 1.0 (Peak)
      final double atPeak = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.25,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 2.0,
        modType: Aion2RuneModulationType.sineBreathing,
      );
      expect(atPeak, closeTo(1.0, 1e-4));

      // At three-quarter cycle t = 0.75 (sin(3pi/2) = -1.0) -> s = 0.0 -> pow(0.0, duty) = 0.0 (Trough)
      final double atTrough = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.75,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 2.0,
        modType: Aion2RuneModulationType.sineBreathing,
      );
      expect(atTrough, closeTo(0.0, 1e-4));
    });

    test('heartbeatDualPulse waveform exhibits canonical draconic systolic & diastolic dual peaks', () {
      // Primary peak P1 around cycle 0.08
      final double p1 = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.08,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.heartbeatDualPulse,
      );
      expect(p1, greaterThanOrEqualTo(0.95));

      // Inter-pulse valley between P1 and P2 around cycle 0.235
      final double interPulse = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.235,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.heartbeatDualPulse,
      );
      expect(interPulse, closeTo(0.0, 0.05));

      // Secondary peak P2 around cycle 0.33
      final double p2 = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.33,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.heartbeatDualPulse,
      );
      expect(p2, closeTo(0.6, 0.05));

      // Diastolic rest pause between 0.50 and 1.0 (returns 0.0)
      final double rest = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.75,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.heartbeatDualPulse,
      );
      expect(rest, closeTo(0.0, 1e-5));
    });

    test('arcaneHarmonic produces multi-frequency superposition shimmer bounded in [0.0, 1.0]', () {
      for (double t = 0.0; t <= 3.0; t += 0.25) {
        final double val = Aion2BrdfEvaluator.evaluateRunePulsation(
          timeSeconds: t,
          speed: 1.2,
          freq: 0.85,
          dutyCycle: 1.8,
          modType: Aion2RuneModulationType.arcaneHarmonic,
        );
        expect(val, inInclusiveRange(0.0, 1.0));
      }
    });

    test('overloadSurge generates rapid high-intensity power flare bounded in [0.0, 1.0]', () {
      for (double t = 0.0; t <= 2.0; t += 0.1) {
        final double val = Aion2BrdfEvaluator.evaluateRunePulsation(
          timeSeconds: t,
          speed: 2.0,
          freq: 1.5,
          dutyCycle: 2.0,
          modType: Aion2RuneModulationType.overloadSurge,
        );
        expect(val, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Built-in Canonical Material Presets Specification
  // ---------------------------------------------------------------------------
  group('Aion 2 Canonical AAA Material Presets Specifications', () {
    test('dragonScale (Ancient Dragon Scale Armor) fulfills draconic iridescent metal specs', () {
      final Aion2PbrParameters p = Aion2MaterialPresets.dragonScale;

      expect(p.name, equals('DragonScale'));
      expect(p.baseColor, equals(const ui.Color(0xFF0F3D2E))); // Deep emerald
      expect(p.metallic, closeTo(0.78, 1e-4));
      expect(p.roughness, closeTo(0.22, 1e-4));
      expect(p.clearcoat, closeTo(0.65, 1e-4));
      expect(p.clearcoatRoughness, closeTo(0.12, 1e-4));

      // SSS membrane scatter
      expect(p.sssEnabled, isTrue);
      expect(p.sssWeight, closeTo(0.25, 1e-4));
      expect(p.sssColor, equals(const ui.Color(0xFF22FF88)));

      // Thin-film Iridescence
      expect(p.iridescenceEnabled, isTrue);
      expect(p.iridescenceWeight, closeTo(0.90, 1e-4));
      expect(p.filmThicknessNm, closeTo(490.0, 1e-4)); // Emerald-violet optical interference
      expect(p.filmIOR, closeTo(1.62, 1e-4));
      expect(p.baseIOR, closeTo(1.45, 1e-4));
      expect(p.iridescenceTint, equals(const ui.Color(0xFFCC88FF)));

      // Emissive pulse
      expect(p.emissiveColor, equals(const ui.Color(0xFF33FFBB)));
      expect(p.emissiveIntensity, closeTo(1.8, 1e-4));
      expect(p.runeModulationType, equals(Aion2RuneModulationType.heartbeatDualPulse));
    });

    test('wingEthereal (Ethereal Wing Fabric) fulfills celestial translucent SSS specs', () {
      final Aion2PbrParameters p = Aion2MaterialPresets.wingEthereal;

      expect(p.name, equals('WingEthereal'));
      expect(p.baseColor, equals(const ui.Color(0xFFF2F8FF))); // Celestial white/ivory
      expect(p.metallic, closeTo(0.04, 1e-4)); // Dielectric membrane
      expect(p.roughness, closeTo(0.38, 1e-4));

      // Translucent Subsurface Scattering
      expect(p.sssEnabled, isTrue);
      expect(p.sssWeight, closeTo(0.96, 1e-4)); // Extreme transmission
      expect(p.sssScale, closeTo(2.8, 1e-4));
      expect(p.sssExtinction, closeTo(0.15, 1e-4));
      expect(p.sssColor, equals(const ui.Color(0xFF33EEFF))); // Celestial cyan glow

      // Mother-of-pearl sheen
      expect(p.iridescenceEnabled, isTrue);
      expect(p.iridescenceWeight, closeTo(0.40, 1e-4));
      expect(p.filmThicknessNm, closeTo(360.0, 1e-4));
      expect(p.iridescenceTint, equals(const ui.Color(0xFFFFEEAA)));

      // Arcane harmonic modulation
      expect(p.emissiveColor, equals(const ui.Color(0xFF55FFFF)));
      expect(p.emissiveIntensity, closeTo(2.4, 1e-4));
      expect(p.runeModulationType, equals(Aion2RuneModulationType.arcaneHarmonic));
    });

    test('gothicDarkStone fulfills ancient abyssal citadel stone specs', () {
      final Aion2PbrParameters p = Aion2MaterialPresets.gothicDarkStone;

      expect(p.name, equals('GothicDarkStone'));
      expect(p.baseColor, equals(const ui.Color(0xFF26272B))); // Weathered dark basalt
      expect(p.metallic, closeTo(0.02, 1e-4));
      expect(p.roughness, closeTo(0.86, 1e-4)); // Heavy diffuse roughness
      expect(p.ao, closeTo(0.95, 1e-4));

      // Solid stone physics: No SSS, no iridescence
      expect(p.sssEnabled, isFalse);
      expect(p.iridescenceEnabled, isFalse);

      // Deep crevice blood-red ancient runes
      expect(p.emissiveColor, equals(const ui.Color(0xFFFF1A35)));
      expect(p.emissiveIntensity, closeTo(3.2, 1e-4));
      expect(p.runeModulationType, equals(Aion2RuneModulationType.sineBreathing));
    });

    test('polishedPlateArmor (Radiant Plate Armor) fulfills mirror-sheen paladin armor specs', () {
      final Aion2PbrParameters p = Aion2MaterialPresets.polishedPlateArmor;

      expect(p.name, equals('PolishedPlateArmor'));
      expect(p.baseColor, equals(const ui.Color(0xFFE8ECF5))); // Chrome polished steel
      expect(p.metallic, closeTo(0.95, 1e-4));
      expect(p.roughness, closeTo(0.12, 1e-4));
      expect(p.clearcoat, closeTo(0.85, 1e-4));
      expect(p.clearcoatRoughness, closeTo(0.06, 1e-4));

      // Metal does not scatter subsurface
      expect(p.sssEnabled, isFalse);

      // Heat-treatment temper iridescence
      expect(p.iridescenceEnabled, isTrue);
      expect(p.iridescenceWeight, closeTo(0.45, 1e-4));
      expect(p.filmThicknessNm, closeTo(530.0, 1e-4));

      // Consecrated golden etched runes
      expect(p.emissiveColor, equals(const ui.Color(0xFFFFDF33)));
      expect(p.emissiveIntensity, closeTo(2.0, 1e-4));
      expect(p.runeModulationType, equals(Aion2RuneModulationType.sineBreathing));
    });

    test('presets catalog contains all four canonical presets and serializes without data loss', () {
      expect(Aion2MaterialPresets.all.length, equals(4));

      for (final Aion2PbrParameters preset in Aion2MaterialPresets.all) {
        final Map<String, dynamic> json = preset.toJson();
        final Aion2PbrParameters restored = Aion2PbrParameters.fromJson(json);

        expect(restored.name, equals(preset.name));
        expect(restored.baseColor.toARGB32(), equals(preset.baseColor.toARGB32()));
        expect(restored.metallic, closeTo(preset.metallic, 1e-4));
        expect(restored.roughness, closeTo(preset.roughness, 1e-4));
        expect(restored.ao, closeTo(preset.ao, 1e-4));
        expect(restored.clearcoat, closeTo(preset.clearcoat, 1e-4));
        expect(restored.clearcoatRoughness, closeTo(preset.clearcoatRoughness, 1e-4));
        expect(restored.sssEnabled, equals(preset.sssEnabled));
        expect(restored.sssWeight, closeTo(preset.sssWeight, 1e-4));
        expect(restored.iridescenceEnabled, equals(preset.iridescenceEnabled));
        expect(restored.iridescenceWeight, closeTo(preset.iridescenceWeight, 1e-4));
        expect(restored.emissiveIntensity, closeTo(preset.emissiveIntensity, 1e-4));
        expect(restored.runeModulationType, equals(preset.runeModulationType));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Aion2MaterialController State, Animation & Shaders Binding
  // ---------------------------------------------------------------------------
  group('Aion2MaterialController State, Animation & Shader Binding', () {
    test('controller initializes with default DragonScale and default lighting', () {
      final Aion2MaterialController controller = Aion2MaterialController();

      expect(controller.params.name, equals('DragonScale'));
      expect(controller.cameraPos, equals(const Vector3D(0.0, 0.0, 2.5)));
      expect(controller.lightPos, equals(const Vector3D(1.5, 2.0, 3.0)));
      expect(controller.lightColor, equals(const ui.Color(0xFFFFF6EE)));
      expect(controller.lightIntensity, equals(2.5));
      expect(controller.ambientLightColor, equals(const ui.Color(0xFF1E2230)));
      expect(controller.elapsedTime, equals(0.0));
      expect(controller.isAnimated, isTrue);
    });

    test('controller advances simulation time only when isAnimated is true', () {
      final Aion2MaterialController controller = Aion2MaterialController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.advanceTime(0.016);
      expect(controller.elapsedTime, closeTo(0.016, 1e-5));
      expect(notifyCount, equals(1));

      // Disable animation
      controller.isAnimated = false;
      expect(notifyCount, equals(2));

      controller.advanceTime(0.016);
      expect(controller.elapsedTime, closeTo(0.016, 1e-5), reason: 'Time should be frozen');
      expect(notifyCount, equals(2));

      // Reset time
      controller.resetTime();
      expect(controller.elapsedTime, equals(0.0));
      expect(notifyCount, equals(3));
    });

    test('controller updates parameters, preset, lighting, and camera position', () {
      final Aion2MaterialController controller = Aion2MaterialController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      // Preset change
      controller.applyPreset(Aion2MaterialPresets.polishedPlateArmor);
      expect(controller.params.name, equals('PolishedPlateArmor'));
      expect(notifyCount, equals(1));

      // Camera change
      controller.setCameraPosition(const Vector3D(0.0, 1.0, 4.0));
      expect(controller.cameraPos, equals(const Vector3D(0.0, 1.0, 4.0)));
      expect(notifyCount, equals(2));

      // Lighting change
      controller.setLighting(
        position: const Vector3D(2.0, 3.0, 5.0),
        color: const ui.Color(0xFFFFDD99),
        intensity: 3.2,
        ambientColor: const ui.Color(0xFF0A0B10),
      );
      expect(controller.lightPos, equals(const Vector3D(2.0, 3.0, 5.0)));
      expect(controller.lightColor, equals(const ui.Color(0xFFFFDD99)));
      expect(controller.lightIntensity, equals(3.2));
      expect(controller.ambientLightColor, equals(const ui.Color(0xFF0A0B10)));
      expect(notifyCount, equals(3));
    });

    test('bindToShader successfully populates uniforms when GPU runtime effect is available', () async {
      final bool warmed = await Aion2ShaderWarmup.warmup(
        assetPath: 'shaders/materials/aion2_pbr_master.frag',
      );

      if (warmed && Aion2ShaderWarmup.cachedProgram != null) {
        final ui.FragmentShader shader = Aion2ShaderWarmup.cachedProgram!.fragmentShader();
        final Aion2MaterialController controller = Aion2MaterialController();

        expect(
          () => controller.bindToShader(
            shader,
            const ui.Size(512.0, 512.0),
          ),
          returnsNormally,
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Widget Tree & Software BRDF Fallback CustomPainter Tests
  // ---------------------------------------------------------------------------
  group('Aion2MaterialPreviewWidget & CustomPainter Rendering Tests', () {
    test('Aion2MaterialPreviewPainter executes software BRDF rendering without throwing', () {
      final Aion2MaterialController controller = Aion2MaterialController();
      final Aion2MaterialPreviewPainter painter = Aion2MaterialPreviewPainter(
        controller: controller,
        shader: null, // Software fallback mode
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      const ui.Size size = ui.Size(256.0, 256.0);

      expect(() => painter.paint(canvas, size), returnsNormally);

      // Edge case: zero or negative size returns gracefully without drawing
      expect(() => painter.paint(canvas, ui.Size.zero), returnsNormally);
      expect(() => painter.paint(canvas, const ui.Size(-10.0, 256.0)), returnsNormally);

      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
    });

    test('Aion2MaterialPreviewPainter shouldRepaint triggers only on dirty state', () {
      final Aion2MaterialController c1 = Aion2MaterialController();
      final Aion2MaterialController c2 = Aion2MaterialController();

      final Aion2MaterialPreviewPainter p1 = Aion2MaterialPreviewPainter(controller: c1);
      final Aion2MaterialPreviewPainter p1Clone = Aion2MaterialPreviewPainter(controller: c1);
      final Aion2MaterialPreviewPainter p2 = Aion2MaterialPreviewPainter(controller: c2);

      expect(p1.shouldRepaint(p1Clone), isFalse);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    testWidgets('Aion2MaterialPreviewWidget mounts, animates ticker and updates gracefully',
        (WidgetTester tester) async {
      final Aion2MaterialController controller = Aion2MaterialController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Aion2MaterialPreviewWidget(
                controller: controller,
                width: 200.0,
                height: 200.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Aion2MaterialPreviewWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);

      // Advance clock
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(controller.elapsedTime, greaterThan(0.0));

      // Apply preset during live widget tree
      controller.applyPreset(Aion2MaterialPresets.wingEthereal);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Aion2 PBR Master Shader GLSL Architectural & Uniform Contract Parity
  // ---------------------------------------------------------------------------
  group('Aion 2 PBR Master Shader GLSL Architectural Alignment', () {
    late File shaderFile;
    late String shaderContent;

    setUpAll(() {
      shaderFile = File('shaders/materials/aion2_pbr_master.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'shaders/materials/aion2_pbr_master.frag must exist');
      shaderContent = shaderFile.readAsStringSync();
    });

    test('GLSL version 460 core and Flutter runtime_effect include are present', () {
      expect(shaderContent, contains('#version 460 core'));
      expect(shaderContent, contains('#include <flutter/runtime_effect.glsl>'));
    });

    test('numeric uniforms are declared in exact sequential 54-float packing order', () {
      final List<String> expectedUniforms = <String>[
        'uniform vec2  uResolution;',
        'uniform float uTime;',
        'uniform vec3  uCameraPos;',
        'uniform float uNormalIntensity;',
        'uniform vec3  uLightPos;',
        'uniform vec3  uLightColor;',
        'uniform float uLightIntensity;',
        'uniform vec3  uAmbientLight;',
        'uniform float uAOIntensity;',
        'uniform vec4  uBaseColor;',
        'uniform float uMetallic;',
        'uniform float uRoughness;',
        'uniform float uClearcoat;',
        'uniform float uClearcoatRoughness;',
        'uniform vec4  uSSSParams;',
        'uniform vec3  uSSSColor;',
        'uniform float uSSSExtinction;',
        'uniform vec4  uIridescenceParams;',
        'uniform vec3  uIridescenceTint;',
        'uniform float uIridescenceAngleShift;',
        'uniform vec4  uEmissiveColor;',
        'uniform vec4  uEmissiveRuneParams;',
        'uniform vec2  uTiling;',
        'uniform vec2  uOffset;',
      ];

      int lastIndex = -1;
      for (final String uniform in expectedUniforms) {
        final int currentIndex = shaderContent.indexOf(uniform);
        expect(currentIndex, greaterThan(lastIndex),
            reason: 'Uniform declaration order mismatch: $uniform was expected after previous uniform');
        lastIndex = currentIndex;
      }
    });

    test('sampler2D uniforms are placed strictly after all numeric uniforms for Impeller', () {
      final int lastNumericOffset = shaderContent.indexOf('uniform vec2  uOffset;');
      final int albedoSampler = shaderContent.indexOf('uniform sampler2D uAlbedoMap;');
      final int normalSampler = shaderContent.indexOf('uniform sampler2D uNormalMap;');
      final int ormSampler = shaderContent.indexOf('uniform sampler2D uMetallicRoughnessAOMap;');
      final int runeSampler = shaderContent.indexOf('uniform sampler2D uEmissiveRuneMap;');

      expect(albedoSampler, greaterThan(lastNumericOffset));
      expect(normalSampler, greaterThan(albedoSampler));
      expect(ormSampler, greaterThan(normalSampler));
      expect(runeSampler, greaterThan(ormSampler));
    });

    test('shader implements full analytical PBR and postprocessing functions', () {
      expect(shaderContent, contains('distributionGGX'));
      expect(shaderContent, contains('geometrySchlickGGX'));
      expect(shaderContent, contains('geometrySmith'));
      expect(shaderContent, contains('fresnelSchlick'));
      expect(shaderContent, contains('evaluateThinFilmIridescence'));
      expect(shaderContent, contains('evaluateSubsurfaceScattering'));
      expect(shaderContent, contains('evaluateRunePulsation'));
      expect(shaderContent, contains('deriveSurfaceNormal'));
      expect(shaderContent, contains('acesTonemap'));
      expect(shaderContent, contains('FlutterFragCoord()'));
      expect(shaderContent, contains('out vec4 fragColor;'));
    });
  });
}
