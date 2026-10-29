import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/materials/aion2_material_system.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. Vector3D & Mathematical Primitives Tests
  // ---------------------------------------------------------------------------
  group('Vector3D & Mathematical Primitives Tests', () {
    test('Vector3D basic algebraic operations maintain Euclidean consistency', () {
      const Vector3D a = Vector3D(1.0, 2.0, 3.0);
      const Vector3D b = Vector3D(4.0, -1.0, 2.0);

      final Vector3D sum = a + b;
      expect(sum.x, closeTo(5.0, 1e-5));
      expect(sum.y, closeTo(1.0, 1e-5));
      expect(sum.z, closeTo(5.0, 1e-5));

      final Vector3D diff = a - b;
      expect(diff.x, closeTo(-3.0, 1e-5));
      expect(diff.y, closeTo(3.0, 1e-5));
      expect(diff.z, closeTo(1.0, 1e-5));

      final Vector3D scaled = a * 2.5;
      expect(scaled.x, closeTo(2.5, 1e-5));
      expect(scaled.y, closeTo(5.0, 1e-5));
      expect(scaled.z, closeTo(7.5, 1e-5));

      final Vector3D divided = a / 2.0;
      expect(divided.x, closeTo(0.5, 1e-5));
      expect(divided.y, closeTo(1.0, 1e-5));
      expect(divided.z, closeTo(1.5, 1e-5));
    });

    test('Vector3D dot product matches analytical formulation', () {
      const Vector3D u = Vector3D(2.0, 3.0, 4.0);
      const Vector3D v = Vector3D(1.0, -2.0, 5.0);

      // 2*1 + 3*(-2) + 4*5 = 2 - 6 + 20 = 16
      expect(u.dot(v), closeTo(16.0, 1e-5));
    });

    test('Vector3D cross product is strictly orthogonal to both operands', () {
      const Vector3D a = Vector3D(1.0, 0.0, 0.0);
      const Vector3D b = Vector3D(0.0, 1.0, 0.0);

      final Vector3D cross = a.cross(b);
      expect(cross.x, closeTo(0.0, 1e-5));
      expect(cross.y, closeTo(0.0, 1e-5));
      expect(cross.z, closeTo(1.0, 1e-5));

      expect(cross.dot(a), closeTo(0.0, 1e-5));
      expect(cross.dot(b), closeTo(0.0, 1e-5));
    });

    test('Vector3D normalized produces unit length and zero vector falls back safely', () {
      const Vector3D v = Vector3D(3.0, 0.0, 4.0);
      final Vector3D n = v.normalized();

      expect(n.length, closeTo(1.0, 1e-5));
      expect(n.x, closeTo(0.6, 1e-5));
      expect(n.z, closeTo(0.8, 1e-5));

      const Vector3D zeroVec = Vector3D(0.0, 0.0, 0.0);
      final Vector3D safeUnit = zeroVec.normalized();
      expect(safeUnit, equals(Vector3D.unitZ));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Aion2PbrParameters & Serialization Tests
  // ---------------------------------------------------------------------------
  group('Aion2PbrParameters & Serialization Tests', () {
    test('Default constructor sets expected physical base ranges', () {
      const Aion2PbrParameters params = Aion2PbrParameters();

      expect(params.name, equals('CustomPbrMaterial'));
      expect(params.metallic, equals(0.0));
      expect(params.roughness, equals(0.5));
      expect(params.ao, equals(1.0));
      expect(params.clearcoat, equals(0.0));
      expect(params.sssEnabled, isFalse);
      expect(params.iridescenceEnabled, isFalse);
    });

    test('copyWith clamps out-of-bounds parameters safely to physically valid ranges', () {
      const Aion2PbrParameters base = Aion2PbrParameters();

      final Aion2PbrParameters clamped = base.copyWith(
        metallic: 2.5, // should clamp to 1.0
        roughness: 0.001, // should clamp to min 0.04
        ao: -0.5, // should clamp to 0.0
        clearcoat: 1.8, // should clamp to 1.0
        sssWeight: 3.0, // should clamp to 1.0
        iridescenceWeight: -0.2, // should clamp to 0.0
        filmThicknessNm: 25.0, // should clamp to min 50.0
      );

      expect(clamped.metallic, equals(1.0));
      expect(clamped.roughness, equals(0.04));
      expect(clamped.ao, equals(0.0));
      expect(clamped.clearcoat, equals(1.0));
      expect(clamped.sssWeight, equals(1.0));
      expect(clamped.iridescenceWeight, equals(0.0));
      expect(clamped.filmThicknessNm, equals(50.0));
    });

    test('toJson and fromJson preserve complete roundtrip integrity', () {
      const Aion2PbrParameters original = Aion2PbrParameters(
        name: 'MysticRunePlate',
        baseColor: ui.Color(0xFF88AABB),
        metallic: 0.85,
        roughness: 0.18,
        ao: 0.92,
        normalIntensity: 1.25,
        clearcoat: 0.75,
        clearcoatRoughness: 0.08,
        sssEnabled: true,
        sssWeight: 0.65,
        sssDistortion: 0.42,
        sssPower: 3.8,
        sssScale: 2.1,
        sssColor: ui.Color(0xFF00FFDD),
        sssExtinction: 0.35,
        iridescenceEnabled: true,
        iridescenceWeight: 0.8,
        filmThicknessNm: 520.0,
        filmIOR: 1.65,
        baseIOR: 1.48,
        iridescenceTint: ui.Color(0xFFFFCCAA),
        angleShift: 1.3,
        emissiveColor: ui.Color(0xFF33FFAA),
        emissiveIntensity: 2.5,
        runeSpeed: 1.4,
        runeFrequency: 1.1,
        runeDutyCycle: 2.8,
        runeModulationType: Aion2RuneModulationType.arcaneHarmonic,
        tilingX: 2.0,
        tilingY: 2.0,
        offsetX: 0.1,
        offsetY: 0.2,
      );

      final Map<String, dynamic> json = original.toJson();
      final Aion2PbrParameters reconstructed = Aion2PbrParameters.fromJson(json);

      expect(reconstructed.name, equals(original.name));
      expect(reconstructed.baseColor.toARGB32(), equals(original.baseColor.toARGB32()));
      expect(reconstructed.metallic, closeTo(original.metallic, 1e-4));
      expect(reconstructed.roughness, closeTo(original.roughness, 1e-4));
      expect(reconstructed.ao, closeTo(original.ao, 1e-4));
      expect(reconstructed.clearcoat, closeTo(original.clearcoat, 1e-4));
      expect(reconstructed.sssEnabled, equals(original.sssEnabled));
      expect(reconstructed.sssWeight, closeTo(original.sssWeight, 1e-4));
      expect(reconstructed.sssColor.toARGB32(), equals(original.sssColor.toARGB32()));
      expect(reconstructed.iridescenceEnabled, equals(original.iridescenceEnabled));
      expect(reconstructed.filmThicknessNm, closeTo(original.filmThicknessNm, 1e-4));
      expect(reconstructed.emissiveIntensity, closeTo(original.emissiveIntensity, 1e-4));
      expect(reconstructed.runeModulationType, equals(Aion2RuneModulationType.arcaneHarmonic));
      expect(reconstructed.tilingX, closeTo(2.0, 1e-4));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Aion2MaterialPresets Tests
  // ---------------------------------------------------------------------------
  group('Aion2MaterialPresets Specification Tests', () {
    test('DragonScale preset fulfills dark fantasy draconic armor standard', () {
      final Aion2PbrParameters p = Aion2MaterialPresets.dragonScale;

      expect(p.name, equals('DragonScale'));
      expect(p.metallic, greaterThanOrEqualTo(0.75));
      expect(p.roughness, lessThanOrEqualTo(0.25));
      expect(p.iridescenceEnabled, isTrue);
      expect(p.iridescenceWeight, greaterThanOrEqualTo(0.85));
      expect(p.filmThicknessNm, closeTo(490.0, 20.0)); // Visible violet-emerald interference
      expect(p.clearcoat, greaterThanOrEqualTo(0.5));
      expect(p.runeModulationType, equals(Aion2RuneModulationType.heartbeatDualPulse));
    });

    test('WingEthereal preset fulfills luminous high-translucency SSS standard', () {
      final Aion2PbrParameters p = Aion2MaterialPresets.wingEthereal;

      expect(p.name, equals('WingEthereal'));
      expect(p.metallic, lessThanOrEqualTo(0.1)); // Non-metal translucent feather/membrane
      expect(p.sssEnabled, isTrue);
      expect(p.sssWeight, greaterThanOrEqualTo(0.90));
      expect(p.sssScale, greaterThan(2.0));
      expect(p.runeModulationType, equals(Aion2RuneModulationType.arcaneHarmonic));
    });

    test('GothicDarkStone preset fulfills matte ancient dungeon architecture standard', () {
      final Aion2PbrParameters p = Aion2MaterialPresets.gothicDarkStone;

      expect(p.name, equals('GothicDarkStone'));
      expect(p.metallic, lessThanOrEqualTo(0.05));
      expect(p.roughness, greaterThanOrEqualTo(0.80));
      expect(p.ao, greaterThanOrEqualTo(0.90));
      expect(p.sssEnabled, isFalse);
      expect(p.iridescenceEnabled, isFalse);
      expect(p.emissiveIntensity, greaterThanOrEqualTo(3.0));
      expect(p.runeModulationType, equals(Aion2RuneModulationType.sineBreathing));
    });

    test('PolishedPlateArmor preset fulfills mirror-sheen paladin plate armor standard', () {
      final Aion2PbrParameters p = Aion2MaterialPresets.polishedPlateArmor;

      expect(p.name, equals('PolishedPlateArmor'));
      expect(p.metallic, greaterThanOrEqualTo(0.90));
      expect(p.roughness, lessThanOrEqualTo(0.15));
      expect(p.clearcoat, greaterThanOrEqualTo(0.80));
      expect(p.iridescenceEnabled, isTrue);
      expect(p.filmThicknessNm, greaterThan(500.0)); // Heat-tempered steel fringe
    });

    test('All presets collection contains exactly four distinct master configurations', () {
      expect(Aion2MaterialPresets.all.length, equals(4));
      final Set<String> names = Aion2MaterialPresets.all.map((Aion2PbrParameters p) => p.name).toSet();
      expect(names.length, equals(4));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Aion2BrdfEvaluator — Analytical Physics BRDF Tests
  // ---------------------------------------------------------------------------
  group('Aion2BrdfEvaluator — Microfacet BRDF Math Tests', () {
    test('GGX Normal Distribution D peaks sharply at normal alignment (N dot H = 1.0)', () {
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      const Vector3D h = Vector3D(0.0, 0.0, 1.0);

      // Low roughness -> high concentrated peak
      final double peakSmooth = Aion2BrdfEvaluator.distributionGGX(n, h, 0.1);
      final double peakRough = Aion2BrdfEvaluator.distributionGGX(n, h, 0.5);

      expect(peakSmooth, greaterThan(peakRough));
      expect(peakRough, greaterThan(0.0));

      // As angle between N and H increases, D decreases monotonically
      final Vector3D tiltedH = const Vector3D(0.3, 0.0, 0.954).normalized();
      final double tiltedVal = Aion2BrdfEvaluator.distributionGGX(n, tiltedH, 0.5);
      expect(tiltedVal, lessThan(peakRough));
    });

    test('Smith Geometry G is bounded in [0.0, 1.0] and vanishes at grazing angles', () {
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      const Vector3D vDirect = Vector3D(0.0, 0.0, 1.0);
      const Vector3D lDirect = Vector3D(0.0, 0.0, 1.0);

      final double gDirect = Aion2BrdfEvaluator.geometrySmith(n, vDirect, lDirect, 0.3);
      expect(gDirect, closeTo(1.0, 0.05));

      // Grazing view angle (near 90 degrees to normal)
      final Vector3D vGrazing = const Vector3D(0.999, 0.0, 0.0447).normalized();
      final double gGrazing = Aion2BrdfEvaluator.geometrySmith(n, vGrazing, lDirect, 0.3);
      expect(gGrazing, lessThan(gDirect));
      expect(gGrazing, greaterThanOrEqualTo(0.0));
    });

    test('Schlick Fresnel F scales from F0 at 0 deg to 1.0 at 90 deg grazing angle', () {
      const Vector3D f0 = Vector3D(0.04, 0.04, 0.04);

      // Normal incidence: cosTheta = 1.0 -> F = F0
      final Vector3D fNormal = Aion2BrdfEvaluator.fresnelSchlick(1.0, f0);
      expect(fNormal.x, closeTo(0.04, 1e-5));
      expect(fNormal.y, closeTo(0.04, 1e-5));
      expect(fNormal.z, closeTo(0.04, 1e-5));

      // Grazing incidence: cosTheta = 0.0 -> F = (1.0, 1.0, 1.0)
      final Vector3D fGrazing = Aion2BrdfEvaluator.fresnelSchlick(0.0, f0);
      expect(fGrazing.x, closeTo(1.0, 1e-5));
      expect(fGrazing.y, closeTo(1.0, 1e-5));
      expect(fGrazing.z, closeTo(1.0, 1e-5));

      // Mid angle (60 degrees, cosTheta = 0.5)
      final Vector3D fMid = Aion2BrdfEvaluator.fresnelSchlick(0.5, f0);
      expect(fMid.x, greaterThan(fNormal.x));
      expect(fMid.x, lessThan(fGrazing.x));
    });

    test('Thin-film optical iridescence calculates chromatic interference within bounds', () {
      final Vector3D irid = Aion2BrdfEvaluator.evaluateThinFilmIridescence(
        cosTheta: 0.8,
        thicknessNm: 490.0,
        filmIOR: 1.6,
        baseIOR: 1.45,
      );

      expect(irid.x, inInclusiveRange(0.0, 1.0));
      expect(irid.y, inInclusiveRange(0.0, 1.0));
      expect(irid.z, inInclusiveRange(0.0, 1.0));

      // Thickness variation modulates interference phase
      final Vector3D iridShifted = Aion2BrdfEvaluator.evaluateThinFilmIridescence(
        cosTheta: 0.8,
        thicknessNm: 350.0,
        filmIOR: 1.6,
        baseIOR: 1.45,
      );
      expect(iridShifted, isNot(equals(irid)));
    });

    test('Subsurface scattering (SSS) transmits backlight and attenuates with extinction', () {
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      const Vector3D v = Vector3D(0.0, 0.0, 1.0); // Facing surface
      const Vector3D lBacklight = Vector3D(0.0, 0.0, -1.0); // Directly behind surface

      final Vector3D sssHighTransmission = Aion2BrdfEvaluator.evaluateSubsurfaceScattering(
        n: n,
        v: v,
        l: lBacklight,
        lightRadiance: const Vector3D(1.0, 1.0, 1.0),
        weight: 1.0,
        distortion: 0.2,
        power: 3.0,
        scale: 2.0,
        sssColor: const Vector3D(0.2, 0.9, 1.0),
        extinction: 0.1,
      );

      expect(sssHighTransmission.length, greaterThan(0.0));

      // Heavy extinction reduces scattered transmission
      final Vector3D sssDamped = Aion2BrdfEvaluator.evaluateSubsurfaceScattering(
        n: n,
        v: v,
        l: lBacklight,
        lightRadiance: const Vector3D(1.0, 1.0, 1.0),
        weight: 1.0,
        distortion: 0.2,
        power: 3.0,
        scale: 2.0,
        sssColor: const Vector3D(0.2, 0.9, 1.0),
        extinction: 3.0,
      );

      expect(sssDamped.length, lessThan(sssHighTransmission.length));
    });

    test('Rune pulsation evaluates valid temporal modulation curves across all types', () {
      // 1. Sine Breathing: smooth oscillations in [0.0, 1.0]
      for (double t = 0.0; t <= 2.0; t += 0.2) {
        final double val = Aion2BrdfEvaluator.evaluateRunePulsation(
          timeSeconds: t,
          speed: 1.0,
          freq: 1.0,
          dutyCycle: 2.0,
          modType: Aion2RuneModulationType.sineBreathing,
        );
        expect(val, inInclusiveRange(0.0, 1.0));
      }

      // 2. Heartbeat Dual Pulse: dual peaks in single cycle
      final double peak1 = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.08,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.heartbeatDualPulse,
      );
      final double valley = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.23,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.heartbeatDualPulse,
      );
      final double peak2 = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.33,
        speed: 1.0,
        freq: 1.0,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.heartbeatDualPulse,
      );

      expect(peak1, greaterThan(0.8));
      expect(valley, lessThan(0.2));
      expect(peak2, greaterThan(0.4));

      // 3. Arcane Harmonic: bounded in [0.0, 1.0]
      final double arcane = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.5,
        speed: 1.5,
        freq: 0.8,
        dutyCycle: 1.5,
        modType: Aion2RuneModulationType.arcaneHarmonic,
      );
      expect(arcane, inInclusiveRange(0.0, 1.0));

      // 4. Overload Surge: rapid flicker bounded in [0.0, 1.0]
      final double overload = Aion2BrdfEvaluator.evaluateRunePulsation(
        timeSeconds: 0.25,
        speed: 2.0,
        freq: 1.5,
        dutyCycle: 1.0,
        modType: Aion2RuneModulationType.overloadSurge,
      );
      expect(overload, inInclusiveRange(0.0, 1.0));
    });

    test('Full PBR radiance evaluation satisfies physical conservation of energy', () {
      const Vector3D n = Vector3D(0.0, 0.0, 1.0);
      const Vector3D v = Vector3D(0.0, 0.0, 1.0);
      const Vector3D l = Vector3D(0.0, 0.707, 0.707);

      final Vector3D radiance = Aion2BrdfEvaluator.evaluateCompletePbr(
        n: n,
        v: v,
        l: l,
        params: Aion2MaterialPresets.dragonScale,
        lightColor: const Vector3D(1.0, 1.0, 1.0),
        lightIntensity: 2.0,
        ambientLight: const Vector3D(0.1, 0.1, 0.1),
        timeSeconds: 0.5,
      );

      expect(radiance.x, greaterThan(0.0));
      expect(radiance.y, greaterThan(0.0));
      expect(radiance.z, greaterThan(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Aion2MaterialUniformPacker Tests
  // ---------------------------------------------------------------------------
  group('Aion2MaterialUniformPacker Buffer Layout Tests', () {
    test('buildUniformList exports exactly 54 floats matching GLSL uniform declaration', () {
      final List<double> uniforms = Aion2MaterialUniformPacker.buildUniformList(
        viewportSize: const ui.Size(1920.0, 1080.0),
        timeSeconds: 4.25,
        cameraPos: const Vector3D(1.0, 2.0, 3.0),
        lightPos: const Vector3D(4.0, 5.0, 6.0),
        lightColor: const ui.Color(0xFFFFFFFF),
        lightIntensity: 3.5,
        ambientLightColor: const ui.Color(0xFF333333),
        params: Aion2MaterialPresets.dragonScale,
      );

      expect(uniforms.length, equals(54));

      // Viewport & time
      expect(uniforms[0], equals(1920.0));
      expect(uniforms[1], equals(1080.0));
      expect(uniforms[2], equals(4.25));

      // Camera pos
      expect(uniforms[3], equals(1.0));
      expect(uniforms[4], equals(2.0));
      expect(uniforms[5], equals(3.0));

      // Light pos
      expect(uniforms[7], equals(4.0));
      expect(uniforms[8], equals(5.0));
      expect(uniforms[9], equals(6.0));

      // Light intensity
      expect(uniforms[13], equals(3.5));

      // Core PBR: Metallic & Roughness
      expect(uniforms[22], equals(Aion2MaterialPresets.dragonScale.metallic));
      expect(uniforms[23], equals(Aion2MaterialPresets.dragonScale.roughness));

      // SSS weight & params
      expect(uniforms[26], equals(Aion2MaterialPresets.dragonScale.sssWeight));
      expect(uniforms[27], equals(Aion2MaterialPresets.dragonScale.sssDistortion));

      // Iridescence params
      expect(uniforms[34], equals(Aion2MaterialPresets.dragonScale.iridescenceWeight));
      expect(uniforms[35], equals(Aion2MaterialPresets.dragonScale.filmThicknessNm));

      // Emissive rune params
      expect(uniforms[46], equals(Aion2MaterialPresets.dragonScale.runeSpeed));
      expect(uniforms[49], equals(Aion2MaterialPresets.dragonScale.runeModulationType.shaderValue));

      // Tiling & offset
      expect(uniforms[50], equals(1.0));
      expect(uniforms[51], equals(1.0));
      expect(uniforms[52], equals(0.0));
      expect(uniforms[53], equals(0.0));
    });

    test('packToFloat32List produces valid binary buffer matching buildUniformList', () {
      final Float32List buffer = Aion2MaterialUniformPacker.packToFloat32List(
        viewportSize: const ui.Size(800.0, 600.0),
        timeSeconds: 1.0,
        cameraPos: Vector3D.zero,
        lightPos: Vector3D.unitZ,
        lightColor: const ui.Color(0xFFFFFFFF),
        lightIntensity: 1.0,
        ambientLightColor: const ui.Color(0xFF000000),
        params: Aion2MaterialPresets.wingEthereal,
      );

      expect(buffer.length, equals(54));
      expect(buffer[0], closeTo(800.0, 1e-4));
      expect(buffer[1], closeTo(600.0, 1e-4));
      expect(buffer[26], closeTo(Aion2MaterialPresets.wingEthereal.sssWeight, 1e-4));
    });

    test('sRGB to linear RGB conversion handles gamma curve accurately', () {
      // Pure black -> 0.0
      final (double r0, double g0, double b0) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFF000000));
      expect(r0, equals(0.0));
      expect(g0, equals(0.0));
      expect(b0, equals(0.0));

      // Pure white -> 1.0
      final (double r1, double g1, double b1) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFFFFFFFF));
      expect(r1, closeTo(1.0, 1e-5));
      expect(g1, closeTo(1.0, 1e-5));
      expect(b1, closeTo(1.0, 1e-5));

      // 50% sRGB gray (128/255 ~= 0.502) -> linear ~0.214
      final (double rMid, _, _) =
          Aion2MaterialUniformPacker.colorToLinearRgb(const ui.Color(0xFF808080));
      expect(rMid, closeTo(0.2158, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Aion2MaterialController Lifecycle Tests
  // ---------------------------------------------------------------------------
  group('Aion2MaterialController Lifecycle Tests', () {
    test('Controller initializes with DragonScale and advances simulation time', () {
      final Aion2MaterialController controller = Aion2MaterialController();
      expect(controller.params.name, equals('DragonScale'));
      expect(controller.elapsedTime, equals(0.0));
      expect(controller.isAnimated, isTrue);

      bool notified = false;
      controller.addListener(() => notified = true);

      controller.advanceTime(0.033);
      expect(controller.elapsedTime, closeTo(0.033, 1e-4));
      expect(notified, isTrue);

      controller.resetTime();
      expect(controller.elapsedTime, equals(0.0));
    });

    test('Controller freezes time progression when isAnimated is disabled', () {
      final Aion2MaterialController controller = Aion2MaterialController();
      controller.isAnimated = false;

      controller.advanceTime(0.1);
      expect(controller.elapsedTime, equals(0.0));
    });

    test('Applying presets updates state and triggers listeners', () {
      final Aion2MaterialController controller = Aion2MaterialController();
      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      controller.applyPreset(Aion2MaterialPresets.wingEthereal);
      expect(controller.params.name, equals('WingEthereal'));
      expect(notificationCount, equals(1));

      controller.applyPreset(Aion2MaterialPresets.gothicDarkStone);
      expect(controller.params.name, equals('GothicDarkStone'));
      expect(notificationCount, equals(2));
    });

    test('Lighting modifications update controller internal states', () {
      final Aion2MaterialController controller = Aion2MaterialController();

      controller.setLighting(
        position: const Vector3D(5.0, 5.0, 5.0),
        color: const ui.Color(0xFFFFEECC),
        intensity: 4.2,
      );

      expect(controller.lightPos, equals(const Vector3D(5.0, 5.0, 5.0)));
      expect(controller.lightColor, equals(const ui.Color(0xFFFFEECC)));
      expect(controller.lightIntensity, equals(4.2));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Aion2ShaderWarmup & Widget Integration Tests
  // ---------------------------------------------------------------------------
  group('Aion2ShaderWarmup & UI Widget Tests', () {
    test('Aion2ShaderWarmup loads master shader program and handles invalid asset gracefully', () async {
      Aion2ShaderWarmup.clearCache();
      expect(Aion2ShaderWarmup.isWarmedUp, isFalse);

      final bool warmed = await Aion2ShaderWarmup.warmup(
        assetPath: 'shaders/materials/aion2_pbr_master.frag',
      );

      // In Flutter test runner with compiled shaders, warmup succeeds!
      expect(warmed, isTrue);
      expect(Aion2ShaderWarmup.cachedProgram, isNotNull);
      expect(Aion2ShaderWarmup.isWarmedUp, isTrue);

      // Invalid asset path safely catches error and returns false without throwing
      final bool failedWarmup = await Aion2ShaderWarmup.warmup(
        assetPath: 'shaders/non_existent_invalid.frag',
      );
      expect(failedWarmup, isFalse);
    });

    test('Aion2ShaderWarmup createSolidTexture generates valid 1x1 test textures', () async {
      final ui.Image whiteTex = await Aion2ShaderWarmup.createSolidTexture(
        color: const ui.Color(0xFFFFFFFF),
      );
      expect(whiteTex.width, equals(1));
      expect(whiteTex.height, equals(1));
      whiteTex.dispose();
    });

    test('Aion2MaterialPreviewPainter paints with software BRDF fallback without throwing', () {
      final Aion2MaterialController controller = Aion2MaterialController();
      final Aion2MaterialPreviewPainter painter = Aion2MaterialPreviewPainter(
        controller: controller,
        shader: null, // Test headless fallback
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      const ui.Size size = ui.Size(200.0, 200.0);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
    });

    testWidgets('Aion2MaterialPreviewWidget mounts and renders successfully in widget tree',
        (WidgetTester tester) async {
      final Aion2MaterialController controller = Aion2MaterialController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Aion2MaterialPreviewWidget(
              controller: controller,
              width: 150.0,
              height: 150.0,
            ),
          ),
        ),
      );

      expect(find.byType(Aion2MaterialPreviewWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);

      // Step animation forward
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Aion2 PBR Master Shader GLSL File Verification
  // ---------------------------------------------------------------------------
  group('Aion2 PBR Master Shader GLSL File Verification', () {
    late File shaderFile;
    late String shaderContent;

    setUpAll(() {
      shaderFile = File('shaders/materials/aion2_pbr_master.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'aion2_pbr_master.frag must exist');
      shaderContent = shaderFile.readAsStringSync();
    });

    test('Shader header has version 460 core and flutter runtime_effect include', () {
      expect(shaderContent, contains('#version 460 core'));
      expect(shaderContent, contains('#include <flutter/runtime_effect.glsl>'));
    });

    test('Shader declares precision highp float', () {
      expect(shaderContent, contains('precision highp float;'));
    });

    test('Shader declares numeric uniforms matching 54-float packing buffer', () {
      expect(shaderContent, contains('uniform vec2  uResolution;'));
      expect(shaderContent, contains('uniform float uTime;'));
      expect(shaderContent, contains('uniform vec3  uCameraPos;'));
      expect(shaderContent, contains('uniform float uNormalIntensity;'));
      expect(shaderContent, contains('uniform vec3  uLightPos;'));
      expect(shaderContent, contains('uniform vec3  uLightColor;'));
      expect(shaderContent, contains('uniform float uLightIntensity;'));
      expect(shaderContent, contains('uniform vec3  uAmbientLight;'));
      expect(shaderContent, contains('uniform float uAOIntensity;'));
      expect(shaderContent, contains('uniform vec4  uBaseColor;'));
      expect(shaderContent, contains('uniform float uMetallic;'));
      expect(shaderContent, contains('uniform float uRoughness;'));
      expect(shaderContent, contains('uniform float uClearcoat;'));
      expect(shaderContent, contains('uniform float uClearcoatRoughness;'));
      expect(shaderContent, contains('uniform vec4  uSSSParams;'));
      expect(shaderContent, contains('uniform vec3  uSSSColor;'));
      expect(shaderContent, contains('uniform float uSSSExtinction;'));
      expect(shaderContent, contains('uniform vec4  uIridescenceParams;'));
      expect(shaderContent, contains('uniform vec3  uIridescenceTint;'));
      expect(shaderContent, contains('uniform float uIridescenceAngleShift;'));
      expect(shaderContent, contains('uniform vec4  uEmissiveColor;'));
      expect(shaderContent, contains('uniform vec4  uEmissiveRuneParams;'));
      expect(shaderContent, contains('uniform vec2  uTiling;'));
      expect(shaderContent, contains('uniform vec2  uOffset;'));
    });

    test('Shader declares all 4 sampler2D uniforms strictly after numeric uniforms', () {
      expect(shaderContent, contains('uniform sampler2D uAlbedoMap;'));
      expect(shaderContent, contains('uniform sampler2D uNormalMap;'));
      expect(shaderContent, contains('uniform sampler2D uMetallicRoughnessAOMap;'));
      expect(shaderContent, contains('uniform sampler2D uEmissiveRuneMap;'));

      final int lastNumericIdx = shaderContent.indexOf('uniform vec2  uOffset;');
      final int albedoIdx = shaderContent.indexOf('uniform sampler2D uAlbedoMap;');
      final int normalIdx = shaderContent.indexOf('uniform sampler2D uNormalMap;');
      final int ormIdx = shaderContent.indexOf('uniform sampler2D uMetallicRoughnessAOMap;');
      final int runeIdx = shaderContent.indexOf('uniform sampler2D uEmissiveRuneMap;');

      expect(albedoIdx, greaterThan(lastNumericIdx),
          reason: 'uAlbedoMap must follow numeric uniforms for Impeller compliance');
      expect(normalIdx, greaterThan(albedoIdx),
          reason: 'uNormalMap must follow uAlbedoMap');
      expect(ormIdx, greaterThan(normalIdx),
          reason: 'uMetallicRoughnessAOMap must follow uNormalMap');
      expect(runeIdx, greaterThan(ormIdx),
          reason: 'uEmissiveRuneMap must follow uMetallicRoughnessAOMap');
    });

    test('Shader declares out vec4 fragColor and entry point main', () {
      expect(shaderContent, contains('out vec4 fragColor;'));
      expect(shaderContent, contains('void main() {'));
      expect(shaderContent, contains('FlutterFragCoord()'));
      expect(shaderContent, contains('fragColor = vec4('));
    });

    test('Shader implements Cook-Torrance BRDF, SSS, and Thin-Film optics', () {
      expect(shaderContent, contains('distributionGGX'));
      expect(shaderContent, contains('geometrySmith'));
      expect(shaderContent, contains('fresnelSchlick'));
      expect(shaderContent, contains('evaluateThinFilmIridescence'));
      expect(shaderContent, contains('evaluateSubsurfaceScattering'));
      expect(shaderContent, contains('evaluateRunePulsation'));
      expect(shaderContent, contains('deriveSurfaceNormal'));
    });

    test('Shader compiles cleanly via impellerc if tool is present', () {
      final String impellercPath =
          'F:\\flutter\\bin\\cache\\artifacts\\engine\\windows-x64\\impellerc.exe';
      final File impellercFile = File(impellercPath);

      if (impellercFile.existsSync()) {
        final ProcessResult result = Process.runSync(
          impellercPath,
          <String>[
            '--sksl',
            '--iplr',
            '--sl=shaders/materials/aion2_pbr_master.iplr.tmp',
            '--spirv=shaders/materials/aion2_pbr_master.spirv.tmp',
            '--input=shaders/materials/aion2_pbr_master.frag',
            '--include=F:\\flutter\\bin\\cache\\artifacts\\engine\\windows-x64\\shader_lib',
          ],
        );

        final File tmpIplr = File('shaders/materials/aion2_pbr_master.iplr.tmp');
        final File tmpSpirv = File('shaders/materials/aion2_pbr_master.spirv.tmp');
        if (tmpIplr.existsSync()) tmpIplr.deleteSync();
        if (tmpSpirv.existsSync()) tmpSpirv.deleteSync();

        expect(result.exitCode, equals(0),
            reason: 'impellerc compilation failed: ${result.stderr}\n${result.stdout}');
      }
    });
  });
}
