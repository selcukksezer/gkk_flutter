import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/vfx/ribbon_trail_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vector3D Math Tests', () {
    test('Vector3D basic arithmetic and equality', () {
      const v1 = Vector3D(1.0, 2.0, 3.0);
      const v2 = Vector3D(4.0, 5.0, 6.0);

      final sum = v1 + v2;
      expect(sum.x, closeTo(5.0, 1e-6));
      expect(sum.y, closeTo(7.0, 1e-6));
      expect(sum.z, closeTo(9.0, 1e-6));

      final diff = v2 - v1;
      expect(diff.x, closeTo(3.0, 1e-6));
      expect(diff.y, closeTo(3.0, 1e-6));
      expect(diff.z, closeTo(3.0, 1e-6));

      final scaled = v1 * 2.0;
      expect(scaled.x, closeTo(2.0, 1e-6));
      expect(scaled.y, closeTo(4.0, 1e-6));
      expect(scaled.z, closeTo(6.0, 1e-6));

      final divided = scaled / 2.0;
      expect(divided, equals(v1));
    });

    test('Vector3D dot, cross, length, normalized, distance', () {
      const vx = Vector3D(1.0, 0.0, 0.0);
      const vy = Vector3D(0.0, 1.0, 0.0);

      expect(vx.dot(vy), closeTo(0.0, 1e-6));

      final vz = vx.cross(vy);
      expect(vz.x, closeTo(0.0, 1e-6));
      expect(vz.y, closeTo(0.0, 1e-6));
      expect(vz.z, closeTo(1.0, 1e-6));

      const v = Vector3D(0.0, 3.0, 4.0);
      expect(v.lengthSquared, closeTo(25.0, 1e-6));
      expect(v.length, closeTo(5.0, 1e-6));

      final norm = v.normalized;
      expect(norm.length, closeTo(1.0, 1e-6));
      expect(norm.y, closeTo(0.6, 1e-6));
      expect(norm.z, closeTo(0.8, 1e-6));

      const p1 = Vector3D(0.0, 0.0, 0.0);
      const p2 = Vector3D(10.0, 0.0, 0.0);
      expect(p1.distanceTo(p2), closeTo(10.0, 1e-6));
      expect(p1.distanceSquaredTo(p2), closeTo(100.0, 1e-6));

      final mid = p1.lerp(p2, 0.5);
      expect(mid.x, closeTo(5.0, 1e-6));
      expect(mid.y, closeTo(0.0, 1e-6));
    });

    test('Vector3D fromOffset and toOffset conversion', () {
      const offset = Offset(12.5, 45.8);
      final v = Vector3D.fromOffset(offset, 7.2);
      expect(v.x, closeTo(12.5, 1e-6));
      expect(v.y, closeTo(45.8, 1e-6));
      expect(v.z, closeTo(7.2, 1e-6));

      final backToOffset = v.toOffset();
      expect(backToOffset.dx, closeTo(12.5, 1e-6));
      expect(backToOffset.dy, closeTo(45.8, 1e-6));
    });
  });

  group('CatmullRomSpline Arc Interpolation Tests', () {
    test('Endpoint interpolation: t=0 yields p1, t=1 yields p2', () {
      const p0 = Vector3D(0.0, 0.0, 0.0);
      const p1 = Vector3D(10.0, 5.0, 0.0);
      const p2 = Vector3D(20.0, 15.0, 0.0);
      const p3 = Vector3D(30.0, 10.0, 0.0);

      // Centripetal Catmull-Rom
      final evalStart = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 0.0, alpha: 0.5);
      expect(evalStart.x, closeTo(p1.x, 1e-5));
      expect(evalStart.y, closeTo(p1.y, 1e-5));

      final evalEnd = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 1.0, alpha: 0.5);
      expect(evalEnd.x, closeTo(p2.x, 1e-5));
      expect(evalEnd.y, closeTo(p2.y, 1e-5));

      // Uniform Catmull-Rom
      final evalStartUniform = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 0.0, alpha: 0.0);
      expect(evalStartUniform.x, closeTo(p1.x, 1e-5));
      expect(evalStartUniform.y, closeTo(p1.y, 1e-5));

      final evalEndUniform = RibbonCatmullRomSpline.evaluate3D(p0, p1, p2, p3, 1.0, alpha: 0.0);
      expect(evalEndUniform.x, closeTo(p2.x, 1e-5));
      expect(evalEndUniform.y, closeTo(p2.y, 1e-5));
    });

    test('2D RibbonCatmullRomSpline produces smooth arc trajectory', () {
      const p0 = Offset(0.0, 0.0);
      const p1 = Offset(50.0, 100.0);
      const p2 = Offset(100.0, 100.0);
      const p3 = Offset(150.0, 0.0);

      final mid = RibbonCatmullRomSpline.evaluate2D(p0, p1, p2, p3, 0.5);
      // Arc mid-point should be between p1 and p2 horizontally
      expect(mid.dx, inInclusiveRange(50.0, 100.0));
      // In swing arc, vertical height at mid is sustained
      expect(mid.dy, greaterThan(80.0));
    });
  });

  group('RibbonSample Construction Tests', () {
    test('from2D creates valid sample with automatic width and center', () {
      final sample = RibbonSample.from2D(
        tip: const Offset(100.0, 200.0),
        base: const Offset(100.0, 100.0),
        timestamp: 1.5,
      );

      expect(sample.width, closeTo(100.0, 1e-5));
      expect(sample.tip2D, equals(const Offset(100.0, 200.0)));
      expect(sample.base2D, equals(const Offset(100.0, 100.0)));
      expect(sample.center2D, equals(const Offset(100.0, 150.0)));
      expect(sample.timestamp, equals(1.5));
      expect(sample.opacity, equals(1.0));
    });

    test('from3D creates valid 3D sample', () {
      final sample = RibbonSample.from3D(
        tip: const Vector3D(10.0, 20.0, 30.0),
        base: const Vector3D(10.0, 10.0, 30.0),
        timestamp: 2.0,
        opacity: 0.8,
      );

      expect(sample.width, closeTo(10.0, 1e-5));
      expect(sample.center.y, closeTo(15.0, 1e-5));
      expect(sample.opacity, equals(0.8));
    });
  });

  group('RibbonTrailMeshGenerator & Buffer Integrity Tests', () {
    test('Returns empty mesh when fewer than 2 samples provided', () {
      const config = RibbonTrailConfig();
      final emptyResult = RibbonTrailMeshGenerator.generate(
        samples: [],
        currentTime: 1.0,
        config: config,
      );
      expect(emptyResult.isEmpty, isTrue);
      expect(emptyResult.vertexCount, equals(0));
      expect(emptyResult.triangleCount, equals(0));

      final singleSample = [
        RibbonSample.from2D(
          tip: const Offset(10.0, 20.0),
          base: const Offset(10.0, 10.0),
          timestamp: 1.0,
        ),
      ];
      final singleResult = RibbonTrailMeshGenerator.generate(
        samples: singleSample,
        currentTime: 1.0,
        config: config,
      );
      expect(singleResult.isEmpty, isTrue);
    });

    test('Generates valid quad strip mesh buffers from 2 samples', () {
      const config = RibbonTrailConfig(subdivisions: 4, lifetime: 0.5);
      final samples = [
        RibbonSample.from2D(
          tip: const Offset(0.0, 100.0),
          base: const Offset(0.0, 0.0),
          timestamp: 0.1,
        ),
        RibbonSample.from2D(
          tip: const Offset(100.0, 100.0),
          base: const Offset(100.0, 0.0),
          timestamp: 0.0,
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.1,
        config: config,
      );

      expect(mesh.isNotEmpty, isTrue);
      // 4 subdivisions + 1 = 5 slices -> 10 vertices
      expect(mesh.vertexCount, equals(10));
      // 4 quads -> 8 triangles
      expect(mesh.triangleCount, equals(8));

      // Buffer size validations
      expect(mesh.positions.length, equals(mesh.vertexCount * 2));
      expect(mesh.positions3D?.length, equals(mesh.vertexCount * 3));
      expect(mesh.texCoords.length, equals(mesh.vertexCount * 2));
      expect(mesh.colors.length, equals(mesh.vertexCount));
      expect(mesh.indices.length, equals(mesh.triangleCount * 3));

      // UV coordinates validation
      // First slice (u = 0.0)
      expect(mesh.texCoords[0], closeTo(0.0, 1e-5)); // u tip
      expect(mesh.texCoords[1], closeTo(0.0, 1e-5)); // v tip
      expect(mesh.texCoords[2], closeTo(0.0, 1e-5)); // u base
      expect(mesh.texCoords[3], closeTo(1.0, 1e-5)); // v base

      // Last slice (u = 1.0)
      final lastU = mesh.texCoords[(mesh.vertexCount - 1) * 2];
      final lastV = mesh.texCoords[(mesh.vertexCount - 1) * 2 + 1];
      expect(lastU, closeTo(1.0, 1e-5));
      expect(lastV, closeTo(1.0, 1e-5));

      // Triangle indices validation (indexed triangles)
      expect(mesh.indices[0], equals(0));
      expect(mesh.indices[1], equals(1));
      expect(mesh.indices[2], equals(2));
      expect(mesh.indices[3], equals(1));
      expect(mesh.indices[4], equals(3));
      expect(mesh.indices[5], equals(2));

      // Bounding box encompasses swing area
      expect(mesh.bounds.left, lessThanOrEqualTo(0.0));
      expect(mesh.bounds.right, greaterThanOrEqualTo(100.0));
    });

    test('Multi-sample swing arc Catmull-Rom generation', () {
      const config = RibbonTrailConfig(subdivisions: 4, lifetime: 1.0);
      // Simulate circular sword slash in 90 degree arc
      final samples = <RibbonSample>[];
      for (int i = 0; i < 5; i++) {
        final angle = (i / 4.0) * (math.pi / 2.0);
        final tip = Offset(math.cos(angle) * 150.0, math.sin(angle) * 150.0);
        final base = Offset(math.cos(angle) * 50.0, math.sin(angle) * 50.0);
        samples.add(RibbonSample.from2D(
          tip: tip,
          base: base,
          timestamp: 0.1 * (4 - i), // Newest at i=0
        ));
      }

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.4,
        config: config,
      );

      expect(mesh.isNotEmpty, isTrue);
      expect(mesh.vertexCount, greaterThan(16));
      expect(mesh.triangleCount, greaterThan(14));
      expect(mesh.bounds.width, greaterThanOrEqualTo(100.0));
      expect(mesh.bounds.height, greaterThanOrEqualTo(99.0));
    });

    test('Width tapering: head width is maximum, tail width tapers down', () {
      const config = RibbonTrailConfig(
        subdivisions: 8,
        startWidthMultiplier: 1.0,
        endWidthMultiplier: 0.0,
        lifetime: 1.0,
      );

      final samples = [
        RibbonSample.from2D(
          tip: const Offset(0.0, 100.0),
          base: const Offset(0.0, 0.0),
          timestamp: 0.2, // Head
        ),
        RibbonSample.from2D(
          tip: const Offset(100.0, 100.0),
          base: const Offset(100.0, 0.0),
          timestamp: 0.0, // Tail
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 0.2,
        config: config,
      );

      // Head slice width (distance between tip and base vertex)
      final headTipY = mesh.positions[1];
      final headBaseY = mesh.positions[3];
      final headWidth = (headTipY - headBaseY).abs();
      expect(headWidth, closeTo(100.0, 1e-4));

      // Tail slice width (at u = 1.0)
      final tailTipY = mesh.positions[(mesh.vertexCount - 2) * 2 + 1];
      final tailBaseY = mesh.positions[(mesh.vertexCount - 1) * 2 + 1];
      final tailWidth = (tailTipY - tailBaseY).abs();
      expect(tailWidth, closeTo(0.0, 1e-4));
    });

    test('Age attenuation & alpha decay: older segments lose alpha', () {
      const config = RibbonTrailConfig(
        subdivisions: 4,
        lifetime: 1.0,
        baseColor: Color(0xFFFFFFFF),
      );

      final samples = [
        RibbonSample.from2D(
          tip: const Offset(0.0, 50.0),
          base: const Offset(0.0, 0.0),
          timestamp: 1.0, // Age = 0.0s (brand new)
        ),
        RibbonSample.from2D(
          tip: const Offset(50.0, 50.0),
          base: const Offset(50.0, 0.0),
          timestamp: 0.2, // Age = 0.8s (nearly dead)
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 1.0,
        config: config,
      );

      final headColor = mesh.colors[0];
      final tailColor = mesh.colors[mesh.vertexCount - 1];

      final headAlpha = (headColor >> 24) & 0xFF;
      final tailAlpha = (tailColor >> 24) & 0xFF;

      expect(headAlpha, greaterThan(150));
      expect(tailAlpha, lessThan(headAlpha));
    });

    test('Expired samples (> lifetime) are pruned from mesh generation', () {
      const config = RibbonTrailConfig(lifetime: 0.5);
      final samples = [
        RibbonSample.from2D(
          tip: const Offset(0.0, 50.0),
          base: const Offset(0.0, 0.0),
          timestamp: 1.0, // Age 0.0 -> Active
        ),
        RibbonSample.from2D(
          tip: const Offset(50.0, 50.0),
          base: const Offset(50.0, 0.0),
          timestamp: 0.8, // Age 0.2 -> Active
        ),
        RibbonSample.from2D(
          tip: const Offset(100.0, 50.0),
          base: const Offset(100.0, 0.0),
          timestamp: 0.1, // Age 0.9 > 0.5 -> Expired!
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 1.0,
        config: config,
      );

      expect(mesh.isNotEmpty, isTrue);
      // Bounds should NOT include the expired sample at x=100
      expect(mesh.bounds.right, lessThan(80.0));
    });

    test('Native ui.Vertices creation from RibbonTrailMesh', () {
      const config = RibbonTrailConfig(subdivisions: 2);
      final samples = [
        RibbonSample.from2D(
          tip: const Offset(10.0, 20.0),
          base: const Offset(10.0, 0.0),
          timestamp: 1.0,
        ),
        RibbonSample.from2D(
          tip: const Offset(30.0, 20.0),
          base: const Offset(30.0, 0.0),
          timestamp: 0.9,
        ),
      ];

      final mesh = RibbonTrailMeshGenerator.generate(
        samples: samples,
        currentTime: 1.0,
        config: config,
      );

      final vertices = mesh.toVertices();
      expect(vertices, isNotNull);
    });
  });

  group('RibbonTrail Controller & Lifecycle Tests', () {
    test('Sample addition, distance filtering, and time updating', () {
      final trail = RibbonTrail(
        config: const RibbonTrailConfig(minSegmentDistance: 5.0, lifetime: 0.5),
      );

      expect(trail.isEmpty, isTrue);

      trail.addSample(
        tip: const Offset(0.0, 50.0),
        base: const Offset(0.0, 0.0),
        timestamp: 0.0,
      );
      expect(trail.sampleCount, equals(1));

      // Attempt to add sample with negligible distance (< 5.0 px) -> should be filtered
      trail.addSample(
        tip: const Offset(0.5, 50.0),
        base: const Offset(0.5, 0.0),
        timestamp: 0.05,
      );
      expect(trail.sampleCount, equals(1)); // Filtered!

      // Add significant sample (> 5.0 px)
      trail.addSample(
        tip: const Offset(20.0, 50.0),
        base: const Offset(20.0, 0.0),
        timestamp: 0.1,
      );
      expect(trail.sampleCount, equals(2));

      // Advance time beyond lifetime (0.5s)
      trail.update(0.7);
      expect(trail.isEmpty, isTrue); // Expired and pruned
    });

    test('3D Sample addition and clear()', () {
      final trail = RibbonTrail();
      trail.addSample3D(
        tip: const Vector3D(0.0, 10.0, 0.0),
        base: const Vector3D(0.0, 0.0, 0.0),
        timestamp: 0.0,
      );
      trail.addSample3D(
        tip: const Vector3D(10.0, 10.0, 5.0),
        base: const Vector3D(10.0, 0.0, 5.0),
        timestamp: 0.1,
      );
      expect(trail.sampleCount, equals(2));

      final mesh = trail.generateMesh();
      expect(mesh.isNotEmpty, isTrue);
      expect(mesh.positions3D, isNotNull);

      trail.clear();
      expect(trail.isEmpty, isTrue);
      expect(trail.generateMesh().isEmpty, isTrue);
    });
  });

  group('RibbonTrailPainter & Renderer Tests', () {
    testWidgets('RibbonTrailPainter paints without exceptions', (tester) async {
      final trail = RibbonTrail(
        config: const RibbonTrailConfig(
          subdivisions: 4,
          baseColor: Color(0xFF00E5FF),
          glowColor: Color(0xFFFFFFFF),
          glowIntensity: 3.0,
        ),
      );

      trail.addSample(
        tip: const Offset(10.0, 100.0),
        base: const Offset(10.0, 50.0),
        timestamp: 0.0,
      );
      trail.addSample(
        tip: const Offset(60.0, 120.0),
        base: const Offset(60.0, 70.0),
        timestamp: 0.1,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(200, 200),
            painter: RibbonTrailPainter(trail: trail),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('RibbonTrailPainter paints with texture without exceptions', (tester) async {
      final trail = RibbonTrail(
        config: const RibbonTrailConfig(
          subdivisions: 4,
          baseColor: Color(0xFFFF5500),
          textureMix: 0.5,
        ),
      );

      trail.addSample(
        tip: const Offset(20.0, 80.0),
        base: const Offset(20.0, 40.0),
        timestamp: 0.0,
      );
      trail.addSample(
        tip: const Offset(80.0, 100.0),
        base: const Offset(80.0, 60.0),
        timestamp: 0.1,
      );

      final texture = RibbonTrailRenderer.fallbackWhiteImage;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            size: const Size(200, 200),
            painter: RibbonTrailPainter(
              trail: trail,
              texture: texture,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('RibbonTrailRenderer Shader Sampler & Fallback Tests', () {
    test('fallbackWhiteImage generates and caches 1x1 solid white image', () {
      final image = RibbonTrailRenderer.fallbackWhiteImage;
      expect(image, isNotNull);
      expect(image!.width, equals(1));
      expect(image.height, equals(1));

      // Subsequent access returns cached instance
      final cachedImage = RibbonTrailRenderer.fallbackWhiteImage;
      expect(cachedImage, same(image));
    });

    test('initFallbackWhiteImage asynchronously initializes fallback image', () async {
      final image = await RibbonTrailRenderer.initFallbackWhiteImage();
      expect(image, isNotNull);
      expect(image!.width, equals(1));
      expect(image.height, equals(1));
    });

    test('fallbackWhiteImage setter allows injecting custom texture', () {
      final original = RibbonTrailRenderer.fallbackWhiteImage;
      try {
        RibbonTrailRenderer.fallbackWhiteImage = original;
        expect(RibbonTrailRenderer.fallbackWhiteImage, equals(original));
      } finally {
        RibbonTrailRenderer.fallbackWhiteImage = original;
      }
    });

    test('applyShaderUniforms binds fallbackWhiteImage to sampler 0 and sets uTextureMix to 0 when texture is null', () {
      final target = _TestShaderTarget();
      const config = RibbonTrailConfig(textureMix: 0.85);

      RibbonTrailRenderer.applyShaderUniforms(
        target,
        resolution: const Size(1920.0, 1080.0),
        bounds: const Rect.fromLTWH(0.0, 0.0, 100.0, 50.0),
        time: 2.5,
        config: config,
        texture: null,
      );

      // Uniform 0, 1: resolution
      expect(target.floats[0], equals(1920.0));
      expect(target.floats[1], equals(1080.0));
      // Uniform 2: time
      expect(target.floats[2], equals(2.5));
      // Uniform 21: uTextureMix must be 0.0 when texture is null
      expect(target.floats[21], equals(0.0));
      // Sampler 0: must bind fallbackWhiteImage to avoid missing sampler error
      expect(target.samplers[0], isNotNull);
      expect(target.samplers[0], equals(RibbonTrailRenderer.fallbackWhiteImage));
    });

    test('applyShaderUniforms binds provided texture to sampler 0 and sets uTextureMix to config value', () {
      final target = _TestShaderTarget();
      const config = RibbonTrailConfig(textureMix: 0.75);
      final customTexture = RibbonTrailRenderer.fallbackWhiteImage!;

      RibbonTrailRenderer.applyShaderUniforms(
        target,
        resolution: const Size(800.0, 600.0),
        bounds: const Rect.fromLTWH(10.0, 20.0, 200.0, 100.0),
        time: 1.2,
        config: config,
        texture: customTexture,
      );

      // Uniform 21: uTextureMix must match config.textureMix when texture is provided
      expect(target.floats[21], equals(0.75));
      // Sampler 0: must bind the provided texture
      expect(target.samplers[0], equals(customTexture));
    });

    test('renderTrail falls back cleanly to vertex colors when shader or texture is null', () {
      final trail = RibbonTrail();
      trail.addSample(
        tip: const Offset(10.0, 50.0),
        base: const Offset(10.0, 0.0),
        timestamp: 0.0,
      );
      trail.addSample(
        tip: const Offset(50.0, 50.0),
        base: const Offset(50.0, 0.0),
        timestamp: 0.1,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Renders with default paint / vertex colors without exceptions
      RibbonTrailRenderer.renderTrail(
        canvas,
        trail,
        shader: null,
        texture: null,
      );

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('renderTrail falls back cleanly when fallbackWhiteImage is cleared', () {
      final trail = RibbonTrail();
      trail.addSample(
        tip: const Offset(0.0, 30.0),
        base: const Offset(0.0, 0.0),
        timestamp: 0.0,
      );
      trail.addSample(
        tip: const Offset(40.0, 30.0),
        base: const Offset(40.0, 0.0),
        timestamp: 0.1,
      );

      final originalFallback = RibbonTrailRenderer.fallbackWhiteImage;
      try {
        RibbonTrailRenderer.fallbackWhiteImage = null;

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        // Even if fallbackWhiteImage is null, renderTrail must not throw
        RibbonTrailRenderer.renderTrail(
          canvas,
          trail,
          texture: null,
        );

        final picture = recorder.endRecording();
        expect(picture, isNotNull);
        picture.dispose();
      } finally {
        RibbonTrailRenderer.fallbackWhiteImage = originalFallback;
      }
    });
  });
}

/// In-memory uniform target capturing floats and samplers for testing shader bindings.
class _TestShaderTarget {
  final Map<int, double> floats = <int, double>{};
  final Map<int, ui.Image> samplers = <int, ui.Image>{};

  void setFloat(int index, double value) {
    floats[index] = value;
  }

  void setImageSampler(int index, ui.Image image) {
    samplers[index] = image;
  }
}

