import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/shaders/shader_pipeline.dart';
import 'package:gkk_flutter/screens/crafting/widgets/crafting_forge_effects.dart';

// ============================================================================
// TEST DOUBLES FOR ISOLATED RUNTIME EFFECT UNIFORM VERIFICATION
// ============================================================================

/// In-memory fake uniform storage recording uniform float and sampler calls
/// to verify exact GLSL uniform layout order and values without requiring
/// a native Flutter engine FragmentShader handle (Dart 3 base class compliant).
class FakeFragmentShader implements ShaderUniformTarget {
  final Map<int, double> uniforms = <int, double>{};
  final Map<int, ui.Image> samplers = <int, ui.Image>{};
  bool disposed = false;

  @override
  void setFloat(int index, double value) {
    uniforms[index] = value;
  }

  @override
  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }

  void dispose() {
    disposed = true;
  }
}

/// In-memory fake [Canvas] capturing draw operations without requiring native
/// engine C++ handles.
class FakeCanvas extends Fake implements Canvas {
  final List<Rect> drawnRects = <Rect>[];
  final List<Path> drawnPaths = <Path>[];
  final List<(Offset, double)> drawnCircles = <(Offset, double)>[];
  final List<Paint> usedPaints = <Paint>[];
  Paint? lastPaint;

  @override
  void drawRect(Rect rect, Paint paint) {
    drawnRects.add(rect);
    usedPaints.add(paint);
    lastPaint = paint;
  }

  @override
  void drawPath(Path path, Paint paint) {
    drawnPaths.add(path);
    usedPaints.add(paint);
    lastPaint = paint;
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    drawnCircles.add((c, radius));
    usedPaints.add(paint);
    lastPaint = paint;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ==========================================================================
  // 1. GLSL SHADER SOURCE CODE SPECIFICATION VERIFICATION
  // ==========================================================================
  group('Forge Fire Shader GLSL Source Code Specification', () {
    late File shaderFile;
    late String shaderCode;

    setUpAll(() {
      shaderFile = File('shaders/vfx/forge_fire.frag');
      expect(shaderFile.existsSync(), isTrue,
          reason: 'shaders/vfx/forge_fire.frag must exist in repository');
      shaderCode = shaderFile.readAsStringSync();
    });

    test('Shader header specifies core 460 version and runtime effect include', () {
      expect(shaderCode, contains('#version 460 core'));
      expect(shaderCode, contains('#include <flutter/runtime_effect.glsl>'));
      expect(shaderCode, contains('out vec4 fragColor;'));
    });

    test('Shader uniform declarations match exact 18-float Dart wrapper layout', () {
      // 0..1: uResolution (vec2 = 2 floats)
      expect(shaderCode, contains('uniform vec2 uResolution;'));
      // 2: uTime (float = 1 float)
      expect(shaderCode, contains('uniform float uTime;'));
      // 3: uHeatIntensity (float = 1 float)
      expect(shaderCode, contains('uniform float uHeatIntensity;'));
      // 4..7: uCoreColor (vec4 = 4 floats)
      expect(shaderCode, contains('uniform vec4 uCoreColor;'));
      // 8..11: uFlameColor (vec4 = 4 floats)
      expect(shaderCode, contains('uniform vec4 uFlameColor;'));
      // 12..15: uEmberColor (vec4 = 4 floats)
      expect(shaderCode, contains('uniform vec4 uEmberColor;'));
      // 16: uTurbulence (float = 1 float)
      expect(shaderCode, contains('uniform float uTurbulence;'));
      // 17: uHeightFactor (float = 1 float)
      expect(shaderCode, contains('uniform float uHeightFactor;'));

      // Validate declaration ordering
      final int idxRes = shaderCode.indexOf('uniform vec2 uResolution;');
      final int idxTime = shaderCode.indexOf('uniform float uTime;');
      final int idxHeat = shaderCode.indexOf('uniform float uHeatIntensity;');
      final int idxCore = shaderCode.indexOf('uniform vec4 uCoreColor;');
      final int idxFlame = shaderCode.indexOf('uniform vec4 uFlameColor;');
      final int idxEmber = shaderCode.indexOf('uniform vec4 uEmberColor;');
      final int idxTurb = shaderCode.indexOf('uniform float uTurbulence;');
      final int idxHeight = shaderCode.indexOf('uniform float uHeightFactor;');

      expect(idxRes, lessThan(idxTime));
      expect(idxTime, lessThan(idxHeat));
      expect(idxHeat, lessThan(idxCore));
      expect(idxCore, lessThan(idxFlame));
      expect(idxFlame, lessThan(idxEmber));
      expect(idxEmber, lessThan(idxTurb));
      expect(idxTurb, lessThan(idxHeight));
    });

    test('Shader integrates TBDR performance early-out and tile discard guards', () {
      expect(shaderCode, contains('discard;'));
      expect(shaderCode, contains('FlutterFragCoord()'));
      expect(shaderCode, contains('mod(p, 289.0)'));
      expect(shaderCode, contains('fastNoise'));
      expect(shaderCode, contains('flameFbm'));
    });

    test('Shader implements 3-tier blackbody temperature grading and premultiplied alpha', () {
      expect(shaderCode, contains('coreThreshold'));
      expect(shaderCode, contains('midThreshold'));
      expect(shaderCode, contains('fragColor = vec4(col.rgb * alpha, alpha);'));
    });
  });

  // ==========================================================================
  // 2. CRAFTING FORGE EFFECTS CONTROLLER SPECIFICATIONS
  // ==========================================================================
  group('CraftingForgeEffectsController — Thermal Curve & State Transitions', () {
    test('Default constructor sets expected simmer baseline and temperature', () {
      final CraftingForgeEffectsController controller = CraftingForgeEffectsController();

      expect(controller.currentHeat, closeTo(0.28, 1e-4));
      expect(controller.targetHeat, closeTo(0.28, 1e-4));
      expect(controller.phase, equals(ForgeHeatPhase.simmer));
      expect(controller.isCrafting, isFalse);
      expect(controller.activeQueueCount, equals(0));
      expect(controller.timeSeconds, equals(0.0));

      // Formula: 800 + 0.28 * 1050 = 800 + 294 = 1094°C
      expect(controller.temperatureCelsius, equals(1094));
      expect(controller.statusLabel, equals('KOR ATEŞİ · BEKLEMEDE'));
    });

    test('Temperature formula accurately maps heat interval [0.0, 1.0] to [800°C, 1850°C]', () {
      final CraftingForgeEffectsController controller = CraftingForgeEffectsController();

      controller.setHeat(0.0);
      expect(controller.temperatureCelsius, equals(800));

      controller.setHeat(0.28);
      expect(controller.temperatureCelsius, equals(1094));

      controller.setHeat(0.45);
      expect(controller.temperatureCelsius, equals(1273)); // 800 + 472.5 = 1273

      controller.setHeat(0.58);
      expect(controller.temperatureCelsius, equals(1409)); // 800 + 609 = 1409

      controller.setHeat(0.85);
      expect(controller.temperatureCelsius, equals(1693)); // 800 + 892.5 = 1693

      controller.setHeat(1.0);
      expect(controller.temperatureCelsius, equals(1850));
    });

    test('Initial heat value is strictly clamped to [0.0, 1.0]', () {
      final CraftingForgeEffectsController subZero =
          CraftingForgeEffectsController(initialHeat: -0.5);
      expect(subZero.currentHeat, equals(0.0));
      expect(subZero.targetHeat, equals(0.0));

      final CraftingForgeEffectsController overMax =
          CraftingForgeEffectsController(initialHeat: 1.5);
      expect(overMax.currentHeat, equals(1.0));
      expect(overMax.targetHeat, equals(1.0));
    });

    test('Phase transitions strictly obey heat boundaries: simmer -> stoking -> roaring', () {
      final CraftingForgeEffectsController controller =
          CraftingForgeEffectsController(initialHeat: 0.1);

      // Simmer boundary (< 0.45)
      controller.setHeat(0.449);
      controller.update(0.0);
      expect(controller.phase, equals(ForgeHeatPhase.simmer));

      // Stoking boundary (0.45 .. 0.85)
      controller.setHeat(0.45);
      controller.update(0.0);
      expect(controller.phase, equals(ForgeHeatPhase.stoking));

      controller.setHeat(0.849);
      controller.update(0.0);
      expect(controller.phase, equals(ForgeHeatPhase.stoking));

      // Roaring boundary (>= 0.85)
      controller.setHeat(0.85);
      controller.update(0.0);
      expect(controller.phase, equals(ForgeHeatPhase.roaring));

      controller.setHeat(1.0);
      controller.update(0.0);
      expect(controller.phase, equals(ForgeHeatPhase.roaring));
    });

    test('Thermodynamics lerp speed heats up faster (4.5x) than it cools down (2.0x)', () {
      // 1. Heating scenario
      final CraftingForgeEffectsController heating =
          CraftingForgeEffectsController(initialHeat: 0.2);
      heating.setCraftingActive(true); // target becomes roaringTarget = 0.95
      heating.update(0.1); // dt = 0.1, lerpSpeed = 4.5 -> factor = 0.45
      // Expected heat: 0.2 + (0.95 - 0.2) * 0.45 = 0.2 + 0.3375 = 0.5375
      expect(heating.currentHeat, closeTo(0.5375, 1e-4));

      // 2. Cooling scenario
      final CraftingForgeEffectsController cooling =
          CraftingForgeEffectsController(initialHeat: 0.95);
      cooling.setHeat(0.95);
      cooling.setCraftingActive(false); // target drops to autoSimmerTarget = 0.28
      cooling.update(0.1); // dt = 0.1, lerpSpeed = 2.0 -> factor = 0.20
      // Expected heat: 0.95 + (0.28 - 0.95) * 0.20 = 0.95 - 0.134 = 0.816
      expect(cooling.currentHeat, closeTo(0.816, 1e-4));
    });

    test('Status label reflects correct text for all operational states', () {
      final CraftingForgeEffectsController controller = CraftingForgeEffectsController();

      // Simmer
      controller.setHeat(0.2);
      controller.update(0.0);
      expect(controller.statusLabel, equals('KOR ATEŞİ · BEKLEMEDE'));

      // Stoking
      controller.setHeat(0.6);
      controller.update(0.0);
      expect(controller.statusLabel, equals('OCAK ISINIYOR · HAZIRLIK'));

      // Roaring
      controller.setHeat(0.9);
      controller.update(0.0);
      expect(controller.statusLabel, equals('KÖRÜKLER AKTİF · DÖVÜLÜYOR'));

      // Surge
      controller.stokeBellows();
      expect(controller.statusLabel, equals('ÇEKİÇ DARBESİ · AKKOR'));

      // Active crafting overrides label to active forging
      controller.setHeat(0.2);
      controller.setCraftingActive(true);
      expect(controller.statusLabel, equals('KÖRÜKLER AKTİF · DÖVÜLÜYOR'));
    });

    test('Queue count updates scale target heat proportionally up to roaring cap', () {
      final CraftingForgeEffectsController controller = CraftingForgeEffectsController();

      // Queue 1: 0.58 + 0.1 = 0.68
      controller.updateQueueCount(1);
      expect(controller.targetHeat, closeTo(0.68, 1e-4));

      // Queue 3: 0.58 + 0.3 = 0.88
      controller.updateQueueCount(3);
      expect(controller.targetHeat, closeTo(0.88, 1e-4));

      // Queue 8: clamped to roaringTarget (0.95)
      controller.updateQueueCount(8);
      expect(controller.targetHeat, equals(controller.roaringTarget));

      // Empty queue resets target to autoSimmerTarget (0.28)
      controller.updateQueueCount(0);
      expect(controller.targetHeat, equals(controller.autoSimmerTarget));
    });

    test('Stoking bellows and trigger surge set phase to surge and notify listeners', () {
      final CraftingForgeEffectsController controller =
          CraftingForgeEffectsController(initialHeat: 0.3);
      int notificationCount = 0;
      controller.addListener(() => notificationCount++);

      controller.stokeBellows(boost: 0.4);
      expect(controller.targetHeat, closeTo(0.7, 1e-4));
      expect(controller.phase, equals(ForgeHeatPhase.surge));
      expect(notificationCount, equals(1));

      controller.triggerSurge();
      expect(controller.targetHeat, equals(1.0));
      expect(controller.phase, equals(ForgeHeatPhase.surge));
      expect(notificationCount, equals(2));
    });

    test('Time accumulation increases monotonically with positive update dt', () {
      final CraftingForgeEffectsController controller = CraftingForgeEffectsController();
      expect(controller.timeSeconds, equals(0.0));

      controller.update(0.016);
      expect(controller.timeSeconds, closeTo(0.016, 1e-5));

      controller.update(0.034);
      expect(controller.timeSeconds, closeTo(0.050, 1e-5));
    });
  });

  // ==========================================================================
  // 3. FORGE FIRE SHADER PAINTER UNIFORM BINDING & MEMORY ALIGNMENT
  // ==========================================================================
  group('ForgeFireShaderPainter — 18-Float Uniform Binding Alignment', () {
    test('Painter accurately maps all 18 uniforms to FragmentShader float slots', () {
      final FakeFragmentShader fakeShader = FakeFragmentShader();
      final FakeCanvas fakeCanvas = FakeCanvas();
      const Size viewportSize = Size(1080.0, 720.0);
      const double testTime = 12.345;
      const double testHeat = 0.82;

      const Color customCore = Color(0xFFFFFFEE);
      const Color customFlame = Color(0xFFFF7A00);
      const Color customEmber = Color(0xFFCC1100);

      final ForgeFireShaderPainter painter = ForgeFireShaderPainter(
        uniformTarget: fakeShader,
        heatIntensity: testHeat,
        timeSeconds: testTime,
        coreWhite: customCore,
        flameOrange: customFlame,
        emberCrimson: customEmber,
      );

      painter.paint(fakeCanvas, viewportSize);

      // Verify uniform slots:
      // 0..1: uResolution
      expect(fakeShader.uniforms[0], equals(1080.0), reason: 'uResolution.x');
      expect(fakeShader.uniforms[1], equals(720.0), reason: 'uResolution.y');

      // 2: uTime
      expect(fakeShader.uniforms[2], equals(testTime), reason: 'uTime');

      // 3: uHeatIntensity
      expect(fakeShader.uniforms[3], equals(testHeat), reason: 'uHeatIntensity');

      // 4..7: uCoreColor (RGBA)
      expect(fakeShader.uniforms[4], closeTo((customCore.r * 255.0) / 255.0, 1e-4),
          reason: 'uCoreColor.r');
      expect(fakeShader.uniforms[5], closeTo((customCore.g * 255.0) / 255.0, 1e-4),
          reason: 'uCoreColor.g');
      expect(fakeShader.uniforms[6], closeTo((customCore.b * 255.0) / 255.0, 1e-4),
          reason: 'uCoreColor.b');
      expect(fakeShader.uniforms[7], closeTo(customCore.a, 1e-4), reason: 'uCoreColor.a');

      // 8..11: uFlameColor (RGBA)
      expect(fakeShader.uniforms[8], closeTo((customFlame.r * 255.0) / 255.0, 1e-4),
          reason: 'uFlameColor.r');
      expect(fakeShader.uniforms[9], closeTo((customFlame.g * 255.0) / 255.0, 1e-4),
          reason: 'uFlameColor.g');
      expect(fakeShader.uniforms[10], closeTo((customFlame.b * 255.0) / 255.0, 1e-4),
          reason: 'uFlameColor.b');
      expect(fakeShader.uniforms[11], closeTo(customFlame.a, 1e-4), reason: 'uFlameColor.a');

      // 12..15: uEmberColor (RGBA)
      expect(fakeShader.uniforms[12], closeTo((customEmber.r * 255.0) / 255.0, 1e-4),
          reason: 'uEmberColor.r');
      expect(fakeShader.uniforms[13], closeTo((customEmber.g * 255.0) / 255.0, 1e-4),
          reason: 'uEmberColor.g');
      expect(fakeShader.uniforms[14], closeTo((customEmber.b * 255.0) / 255.0, 1e-4),
          reason: 'uEmberColor.b');
      expect(fakeShader.uniforms[15], closeTo(customEmber.a, 1e-4), reason: 'uEmberColor.a');

      // 16: uTurbulence = 1.0 + heatIntensity * 0.5
      expect(fakeShader.uniforms[16], closeTo(1.0 + testHeat * 0.5, 1e-4),
          reason: 'uTurbulence dynamic scaling');

      // 17: uHeightFactor = 1.0
      expect(fakeShader.uniforms[17], equals(1.0), reason: 'uHeightFactor');

      // Verify canvas draw call bounds and painter execution
      expect(fakeCanvas.drawnRects.length, equals(1));
      expect(fakeCanvas.drawnRects.first, equals(Offset.zero & viewportSize));
      expect(fakeCanvas.lastPaint, isNotNull);
    });

    test('Turbulence uniform scales dynamically across simmer, stoking, and roaring', () {
      final FakeFragmentShader fakeShader = FakeFragmentShader();
      final FakeCanvas fakeCanvas = FakeCanvas();
      const Size size = Size(400, 400);

      void bind(double heat) {
        ForgeFireShaderPainter(
          uniformTarget: fakeShader,
          heatIntensity: heat,
          timeSeconds: 1.0,
        ).paint(fakeCanvas, size);
      }

      bind(0.0);
      expect(fakeShader.uniforms[16], equals(1.0)); // 1.0 + 0.0 * 0.5

      bind(0.5);
      expect(fakeShader.uniforms[16], equals(1.25)); // 1.0 + 0.5 * 0.5

      bind(1.0);
      expect(fakeShader.uniforms[16], equals(1.5)); // 1.0 + 1.0 * 0.5
    });

    test('When shader is null and uniformTarget is null, painter cleanly delegates to procedural flame painter', () {
      final FakeCanvas fakeCanvas = FakeCanvas();
      final ForgeFireShaderPainter fallbackPainter = ForgeFireShaderPainter(
        shader: null,
        uniformTarget: null,
        heatIntensity: 0.65,
        timeSeconds: 2.5,
      );

      // Should execute procedural fallback without any uncaught exception
      fallbackPainter.paint(fakeCanvas, const Size(500, 300));

      // Procedural painter issues 1 hearth rect draw + 3 flame layer path draws
      expect(fakeCanvas.drawnRects.length, equals(1), reason: 'Hearth coal bed glow rect');
      expect(fakeCanvas.drawnPaths.length, equals(3), reason: '3-tier flame tongues (crimson, orange, core)');
    });
  });

  // ==========================================================================
  // 3.1 FORGE FIRE SHADER UNIFORM BUFFER SPECIFICATIONS
  // ==========================================================================
  group('ForgeFireShaderUniformBuffer — 18-Float Packing & Uniform Target Integration', () {
    test('toFloat32List packs all 18 uniforms in exact GLSL declaration order', () {
      const Size size = Size(800.0, 600.0);
      const double time = 5.25;
      const double heat = 0.75;
      const Color core = Color(0xFFFFFDE7);
      const Color flame = Color(0xFFFF6D00);
      const Color ember = Color(0xFFD50000);

      const ForgeFireShaderUniformBuffer buffer = ForgeFireShaderUniformBuffer(
        resolution: size,
        timeSeconds: time,
        heatIntensity: heat,
        coreColor: core,
        flameColor: flame,
        emberColor: ember,
      );

      final Float32List packed = buffer.toFloat32List();
      expect(packed.length, equals(18));

      // 0..1: uResolution
      expect(packed[0], equals(800.0));
      expect(packed[1], equals(600.0));

      // 2: uTime
      expect(packed[2], equals(5.25));

      // 3: uHeatIntensity
      expect(packed[3], equals(0.75));

      // 4..7: uCoreColor
      expect(packed[4], closeTo((core.r * 255.0) / 255.0, 1e-4));
      expect(packed[5], closeTo((core.g * 255.0) / 255.0, 1e-4));
      expect(packed[6], closeTo((core.b * 255.0) / 255.0, 1e-4));
      expect(packed[7], closeTo(core.a, 1e-4));

      // 8..11: uFlameColor
      expect(packed[8], closeTo((flame.r * 255.0) / 255.0, 1e-4));
      expect(packed[9], closeTo((flame.g * 255.0) / 255.0, 1e-4));
      expect(packed[10], closeTo((flame.b * 255.0) / 255.0, 1e-4));
      expect(packed[11], closeTo(flame.a, 1e-4));

      // 12..15: uEmberColor
      expect(packed[12], closeTo((ember.r * 255.0) / 255.0, 1e-4));
      expect(packed[13], closeTo((ember.g * 255.0) / 255.0, 1e-4));
      expect(packed[14], closeTo((ember.b * 255.0) / 255.0, 1e-4));
      expect(packed[15], closeTo(ember.a, 1e-4));

      // 16: uTurbulence = 1.0 + 0.75 * 0.5 = 1.375
      expect(packed[16], closeTo(1.375, 1e-4));

      // 17: uHeightFactor
      expect(packed[17], equals(1.0));
    });

    test('applyTo binds accurately to BufferUniformTarget', () {
      final BufferUniformTarget target = BufferUniformTarget();
      const ForgeFireShaderUniformBuffer buffer = ForgeFireShaderUniformBuffer(
        resolution: Size(1920.0, 1080.0),
        timeSeconds: 42.0,
        heatIntensity: 0.9,
      );

      buffer.applyTo(target);

      expect(target.getFloat(0), equals(1920.0));
      expect(target.getFloat(1), equals(1080.0));
      expect(target.getFloat(2), equals(42.0));
      expect(target.getFloat(3), equals(0.9));
      expect(target.getFloat(16), closeTo(1.0 + 0.9 * 0.5, 1e-4));
      expect(target.getFloat(17), equals(1.0));
    });

    test('Custom turbulence override is honored over auto-calculated factor', () {
      const ForgeFireShaderUniformBuffer custom = ForgeFireShaderUniformBuffer(
        resolution: Size(100, 100),
        timeSeconds: 1.0,
        heatIntensity: 0.5,
        turbulence: 2.75,
      );

      expect(custom.effectiveTurbulence, equals(2.75));
      final Float32List packed = custom.toFloat32List();
      expect(packed[16], equals(2.75));
    });
  });

  // ==========================================================================
  // 4. PROCEDURAL FLAME FALLBACK PAINTER RENDERING VERIFICATION
  // ==========================================================================
  group('ForgeFireProceduralPainter — Pure Dart Procedural Fallback Engine', () {
    test('Procedural painter executes completely on native PictureRecorder canvas', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final ForgeFireProceduralPainter procedural = ForgeFireProceduralPainter(
        heatIntensity: 0.72,
        timeSeconds: 4.8,
      );

      procedural.paint(canvas, const Size(320, 240));
      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('Hearth coal bed rect covers bottom half of the drawing area', () {
      final FakeCanvas fakeCanvas = FakeCanvas();
      const Size size = Size(600, 400);
      final ForgeFireProceduralPainter procedural = ForgeFireProceduralPainter(
        heatIntensity: 0.5,
        timeSeconds: 1.0,
      );

      procedural.paint(fakeCanvas, size);

      expect(fakeCanvas.drawnRects.length, equals(1));
      final Rect hearth = fakeCanvas.drawnRects.first;
      expect(hearth.left, equals(0.0));
      expect(hearth.top, closeTo(400 * 0.45, 1e-4));
      expect(hearth.width, equals(600.0));
      expect(hearth.height, closeTo(400 * 0.55, 1e-4));
    });

    test('Generates 3 distinct flame paths for outer, mid, and inner core layers', () {
      final FakeCanvas fakeCanvas = FakeCanvas();
      const Size size = Size(400, 300);
      final ForgeFireProceduralPainter procedural = ForgeFireProceduralPainter(
        heatIntensity: 0.85,
        timeSeconds: 3.14,
      );

      procedural.paint(fakeCanvas, size);
      expect(fakeCanvas.drawnPaths.length, equals(3));

      for (final Path path in fakeCanvas.drawnPaths) {
        final Rect bounds = path.getBounds();
        expect(bounds.width, greaterThan(0.0));
        expect(bounds.height, greaterThan(0.0));
        expect(bounds.bottom, lessThanOrEqualTo(300.0));
      }
    });

    test('Clamps negative and excessive heat inputs without arithmetic explosion', () {
      final FakeCanvas fakeCanvas = FakeCanvas();
      const Size size = Size(200, 200);

      final ForgeFireProceduralPainter subZero = ForgeFireProceduralPainter(
        heatIntensity: -1.0,
        timeSeconds: 0.0,
      );
      expect(() => subZero.paint(fakeCanvas, size), returnsNormally);

      final ForgeFireProceduralPainter superHot = ForgeFireProceduralPainter(
        heatIntensity: 5.0,
        timeSeconds: 100.0,
      );
      expect(() => superHot.paint(fakeCanvas, size), returnsNormally);
    });
  });

  // ==========================================================================
  // 5. CUSTOM PAINTER SHOULD REPAINT & DELTA CACHING CONTRACTS
  // ==========================================================================
  group('CustomPainter shouldRepaint & Delta Caching Contracts', () {
    test('ForgeFireShaderPainter shouldRepaint triggers only on relevant state deltas', () {
      final FakeFragmentShader s1 = FakeFragmentShader();
      final FakeFragmentShader s2 = FakeFragmentShader();

      final ForgeFireShaderPainter base = ForgeFireShaderPainter(
        uniformTarget: s1,
        heatIntensity: 0.5,
        timeSeconds: 1.0,
      );

      // Identical delegate -> false
      final ForgeFireShaderPainter same = ForgeFireShaderPainter(
        uniformTarget: s1,
        heatIntensity: 0.5,
        timeSeconds: 1.0,
      );
      expect(base.shouldRepaint(same), isFalse);

      // Uniform target reference delta -> true
      final ForgeFireShaderPainter diffShader = ForgeFireShaderPainter(
        uniformTarget: s2,
        heatIntensity: 0.5,
        timeSeconds: 1.0,
      );
      expect(base.shouldRepaint(diffShader), isTrue);

      // Heat delta -> true
      final ForgeFireShaderPainter diffHeat = ForgeFireShaderPainter(
        uniformTarget: s1,
        heatIntensity: 0.6,
        timeSeconds: 1.0,
      );
      expect(base.shouldRepaint(diffHeat), isTrue);

      // Time delta -> true
      final ForgeFireShaderPainter diffTime = ForgeFireShaderPainter(
        uniformTarget: s1,
        heatIntensity: 0.5,
        timeSeconds: 1.1,
      );
      expect(base.shouldRepaint(diffTime), isTrue);
    });

    test('ForgeFireProceduralPainter shouldRepaint triggers on heat, time, or color delta', () {
      final ForgeFireProceduralPainter base = ForgeFireProceduralPainter(
        heatIntensity: 0.4,
        timeSeconds: 2.0,
        primaryGold: const Color(0xFFFFB300),
      );

      final ForgeFireProceduralPainter same = ForgeFireProceduralPainter(
        heatIntensity: 0.4,
        timeSeconds: 2.0,
        primaryGold: const Color(0xFFFFB300),
      );
      expect(base.shouldRepaint(same), isFalse);

      final ForgeFireProceduralPainter diffHeat = ForgeFireProceduralPainter(
        heatIntensity: 0.45,
        timeSeconds: 2.0,
        primaryGold: const Color(0xFFFFB300),
      );
      expect(base.shouldRepaint(diffHeat), isTrue);

      final ForgeFireProceduralPainter diffTime = ForgeFireProceduralPainter(
        heatIntensity: 0.4,
        timeSeconds: 2.05,
        primaryGold: const Color(0xFFFFB300),
      );
      expect(base.shouldRepaint(diffTime), isTrue);

      final ForgeFireProceduralPainter diffColor = ForgeFireProceduralPainter(
        heatIntensity: 0.4,
        timeSeconds: 2.0,
        primaryGold: const Color(0xFFFF0000),
      );
      expect(base.shouldRepaint(diffColor), isTrue);
    });

    test('CraftingEmberPainter shouldRepaint always returns true for continuous particle physics', () {
      final CraftingEmberPainter p1 = CraftingEmberPainter(
        particles: <ForgeEmber>[],
        heatIntensity: 0.3,
      );
      final CraftingEmberPainter p2 = CraftingEmberPainter(
        particles: <ForgeEmber>[],
        heatIntensity: 0.3,
      );

      expect(p1.shouldRepaint(p2), isTrue);
    });
  });

  // ==========================================================================
  // 6. EMBER PARTICLE POOL & EMBER PAINTER SPECIFICATIONS
  // ==========================================================================
  group('CraftingEmberParticleSystem & Ember Painter Specifications', () {
    test('Particle system initializes with requested particle count and zero nulls', () {
      final CraftingEmberParticleSystem system =
          CraftingEmberParticleSystem(maxParticles: 32, seed: 42);

      expect(system.particles.length, equals(32));
      for (final ForgeEmber ember in system.particles) {
        expect(ember.x, inInclusiveRange(-0.1, 1.1));
        expect(ember.y, inInclusiveRange(0.0, 1.05));
        expect(ember.size, greaterThan(0.0));
        expect(ember.maxAge, greaterThan(0.0));
      }
    });

    test('Thermal lift scales vertical velocity with higher heat intensity', () {
      final CraftingEmberParticleSystem systemLow =
          CraftingEmberParticleSystem(maxParticles: 10, seed: 100);
      final CraftingEmberParticleSystem systemHigh =
          CraftingEmberParticleSystem(maxParticles: 10, seed: 100);

      // Low heat (0.1) vs roaring heat (1.0)
      systemLow.update(0.1, 0.1);
      systemHigh.update(0.1, 1.0);

      // Average y of high heat system should be higher due to thermalLift = 1.0 + heat * 1.6
      final double avgYLow =
          systemLow.particles.map((e) => e.y).reduce((a, b) => a + b) / 10;
      final double avgYHigh =
          systemHigh.particles.map((e) => e.y).reduce((a, b) => a + b) / 10;

      expect(avgYHigh, greaterThan(avgYLow));
    });

    test('Particles that exceed top bounds (y > 1.05) or life are automatically recycled', () {
      final CraftingEmberParticleSystem system =
          CraftingEmberParticleSystem(maxParticles: 8, seed: 777);

      // Force particles to end of life
      for (final ForgeEmber p in system.particles) {
        p.age = p.maxAge + 1.0;
        p.y = 1.2;
      }

      system.update(0.016, 0.5);

      // Recycled particles should have age 0.0 and be near base
      for (final ForgeEmber p in system.particles) {
        expect(p.isDead, isFalse);
        expect(p.y, lessThan(0.3));
      }
    });

    test('spawnBurst injects burst particles with isBurst set to true', () {
      final CraftingEmberParticleSystem system =
          CraftingEmberParticleSystem(maxParticles: 20, seed: 99);

      // Advance particles so normalizedLife > 0.4
      for (final ForgeEmber p in system.particles) {
        p.age = p.maxAge * 0.6;
      }

      system.spawnBurst(count: 6);

      final int burstCount = system.particles.where((e) => e.isBurst).length;
      expect(burstCount, greaterThanOrEqualTo(1));
    });

    test('CraftingEmberPainter draws circles and outer glows for prominent particles', () {
      final FakeCanvas fakeCanvas = FakeCanvas();
      final List<ForgeEmber> testParticles = <ForgeEmber>[
        ForgeEmber(
          x: 0.5,
          y: 0.5,
          vx: 0.0,
          vy: 0.5,
          size: 3.5, // > 2.2 -> triggers glow circle
          maxAge: 2.0,
          age: 0.3,
          driftPhase: 0.0,
          driftFrequency: 1.0,
          driftAmplitude: 0.05,
          colorShift: 0.2,
          isBurst: false,
        ),
        ForgeEmber(
          x: 0.3,
          y: 0.7,
          vx: 0.0,
          vy: 0.5,
          size: 1.5, // <= 2.2 -> body circle only
          maxAge: 2.0,
          age: 1.5,
          driftPhase: 0.0,
          driftFrequency: 1.0,
          driftAmplitude: 0.05,
          colorShift: 0.2,
          isBurst: false,
        ),
      ];

      final CraftingEmberPainter painter = CraftingEmberPainter(
        particles: testParticles,
        heatIntensity: 0.7,
      );

      painter.paint(fakeCanvas, const Size(400, 400));

      // First particle draws 2 circles (glow + body), second draws 1 (body) -> total 3
      expect(fakeCanvas.drawnCircles.length, equals(3));
    });

    test('CraftingEmberPainter handles empty particle lists gracefully', () {
      final FakeCanvas fakeCanvas = FakeCanvas();
      final CraftingEmberPainter emptyPainter = CraftingEmberPainter(
        particles: <ForgeEmber>[],
        heatIntensity: 0.5,
      );

      emptyPainter.paint(fakeCanvas, const Size(200, 200));
      expect(fakeCanvas.drawnCircles, isEmpty);
    });
  });

  // ==========================================================================
  // 7. CRAFTING FORGE VFX WIDGETS INTEGRATION TESTS
  // ==========================================================================
  group('Crafting Forge VFX Widgets Integration Tests', () {
    testWidgets('CraftingForgeAtmosphere mounts and runs ticker animation', (tester) async {
      final CraftingForgeEffectsController controller = CraftingForgeEffectsController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftingForgeAtmosphere(
              controller: controller,
              particleCount: 16,
              showFireShader: false, // forces procedural fallback in widget test
              width: 300,
              height: 200,
            ),
          ),
        ),
      );

      expect(find.byType(CraftingForgeAtmosphere), findsOneWidget);
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));

      // Advance frames
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.timeSeconds, greaterThan(0.0));

      controller.dispose();
    });

    testWidgets('CraftingForgeHeroCard displays metrics and stokes bellows on tap',
        (tester) async {
      final CraftingForgeEffectsController controller =
          CraftingForgeEffectsController(initialHeat: 0.3);
      bool stokeCallbackFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CraftingForgeHeroCard(
              controller: controller,
              onStoke: () => stokeCallbackFired = true,
            ),
          ),
        ),
      );

      // Title & temperature inspection
      expect(find.text('DEMİRCİ OCAĞI'), findsOneWidget);
      expect(find.text('${controller.temperatureCelsius}°C'), findsOneWidget);
      expect(find.text('KOR ATEŞİ · BEKLEMEDE'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Tap Körükle action
      expect(find.text('Körükle'), findsOneWidget);
      await tester.tap(find.text('Körükle'));
      await tester.pump();

      expect(stokeCallbackFired, isTrue);
      expect(controller.phase, equals(ForgeHeatPhase.surge));
      expect(find.text('ÇEKİÇ DARBESİ · AKKOR'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('CraftingPreviewForgeBackdrop renders procedural flame backdrop', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CraftingPreviewForgeBackdrop(
                isCrafting: false,
                height: 120,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CraftingPreviewForgeBackdrop), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('ForgeEmbersOverlay renders non-obstructive child overlay', (tester) async {
      bool childTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeEmbersOverlay(
              particleCount: 12,
              heatIntensity: 0.5,
              child: GestureDetector(
                onTap: () => childTapped = true,
                child: const Text('Interactive Chamber'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Interactive Chamber'), findsOneWidget);
      expect(find.byType(IgnorePointer), findsOneWidget);

      await tester.tap(find.text('Interactive Chamber'));
      expect(childTapped, isTrue);

      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ForgeAnvilHeader displays queue, recipe count, and view toggle button',
        (tester) async {
      bool viewToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeAnvilHeader(
              recipeCount: 24,
              queueCount: 3,
              queueMax: 6,
              isCarouselMode: true,
              onToggleViewMode: () => viewToggled = true,
            ),
          ),
        ),
      );

      expect(find.text('DEMİRCİ OCAĞI'), findsOneWidget);
      expect(find.text('Kuyruk: 3/6 dövülüyor'), findsOneWidget);
      expect(find.text('Izgara'), findsOneWidget);

      await tester.tap(find.text('Izgara'));
      expect(viewToggled, isTrue);

      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('MoltenProgressBar clamps progress within valid bounds and pulses',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MoltenProgressBar(progress: 0.75, height: 8),
            ),
          ),
        ),
      );

      expect(find.byType(MoltenProgressBar), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsOneWidget);

      final FractionallySizedBox box =
          tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(box.widthFactor, equals(0.75));

      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
