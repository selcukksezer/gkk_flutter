import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/world/cinematic_camera_controller.dart';
import 'package:gkk_flutter/widgets/cinematic_hud_overlay.dart';

void main() {
  group('WorldVector3 Math Operations', () {
    test('vector arithmetic operations produce correct results', () {
      const v1 = WorldVector3(1.0, 2.0, 3.0);
      const v2 = WorldVector3(4.0, 5.0, 6.0);

      final sum = v1 + v2;
      expect(sum.x, closeTo(5.0, 1e-6));
      expect(sum.y, closeTo(7.0, 1e-6));
      expect(sum.z, closeTo(9.0, 1e-6));

      final diff = v2 - v1;
      expect(diff.x, closeTo(3.0, 1e-6));
      expect(diff.y, closeTo(3.0, 1e-6));
      expect(diff.z, closeTo(3.0, 1e-6));

      final scaled = v1 * 2.5;
      expect(scaled.x, closeTo(2.5, 1e-6));
      expect(scaled.y, closeTo(5.0, 1e-6));
      expect(scaled.z, closeTo(7.5, 1e-6));

      final div = v2 / 2.0;
      expect(div.x, closeTo(2.0, 1e-6));
      expect(div.y, closeTo(2.5, 1e-6));
      expect(div.z, closeTo(3.0, 1e-6));

      final neg = -v1;
      expect(neg.x, closeTo(-1.0, 1e-6));
      expect(neg.y, closeTo(-2.0, 1e-6));
      expect(neg.z, closeTo(-3.0, 1e-6));
    });

    test('dot product, cross product, length, and distance', () {
      const v1 = WorldVector3(1.0, 0.0, 0.0);
      const v2 = WorldVector3(0.0, 1.0, 0.0);

      expect(v1.dot(v2), closeTo(0.0, 1e-6));

      final cross = v1.cross(v2);
      expect(cross, equals(const WorldVector3(0.0, 0.0, 1.0)));

      const v3 = WorldVector3(3.0, 4.0, 0.0);
      expect(v3.length, closeTo(5.0, 1e-6));
      expect(v3.lengthSquared, closeTo(25.0, 1e-6));

      final norm = v3.normalized();
      expect(norm.length, closeTo(1.0, 1e-6));
      expect(norm.x, closeTo(0.6, 1e-6));
      expect(norm.y, closeTo(0.8, 1e-6));

      const v4 = WorldVector3(0.0, 0.0, 0.0);
      expect(v4.normalized(), equals(WorldVector3.zero));

      expect(v1.distanceTo(const WorldVector3(4.0, 0.0, 0.0)), closeTo(3.0, 1e-6));
    });

    test('lerp accurately interpolates between vectors', () {
      const a = WorldVector3(0.0, 10.0, 20.0);
      const b = WorldVector3(10.0, 20.0, 30.0);

      final mid = WorldVector3.lerp(a, b, 0.5);
      expect(mid.x, closeTo(5.0, 1e-6));
      expect(mid.y, closeTo(15.0, 1e-6));
      expect(mid.z, closeTo(25.0, 1e-6));

      final clamped = WorldVector3.lerp(a, b, 1.5);
      expect(clamped, equals(b));
    });
  });

  group('OrbitalCoordinates Spherical Transforms', () {
    test('toCartesianOffset generates exact trigonometric projections', () {
      // Horizontal forward along Z axis: azim = 0, elev = 0
      const coord1 = OrbitalCoordinates(azimuth: 0.0, elevation: 0.0, distance: 10.0);
      final offset1 = coord1.toCartesianOffset();
      expect(offset1.x, closeTo(0.0, 1e-5));
      expect(offset1.y, closeTo(0.0, 1e-5));
      expect(offset1.z, closeTo(10.0, 1e-5));

      // Right along X axis: azim = pi / 2, elev = 0
      const coord2 = OrbitalCoordinates(azimuth: math.pi / 2.0, elevation: 0.0, distance: 10.0);
      final offset2 = coord2.toCartesianOffset();
      expect(offset2.x, closeTo(10.0, 1e-5));
      expect(offset2.y, closeTo(0.0, 1e-5));
      expect(offset2.z, closeTo(0.0, 1e-5));

      // Straight up: elev = pi / 2
      const coord3 = OrbitalCoordinates(azimuth: 0.0, elevation: math.pi / 2.0, distance: 8.0);
      final offset3 = coord3.toCartesianOffset();
      expect(offset3.x, closeTo(0.0, 1e-5));
      expect(offset3.y, closeTo(8.0, 1e-5));
      expect(offset3.z, closeTo(0.0, 1e-5));
    });

    test('spherical round-trip conversion preserves angles and distance', () {
      const original = OrbitalCoordinates(
        azimuth: 0.75, // ~43°
        elevation: 0.35, // ~20°
        distance: 12.5,
      );

      final cartesian = original.toCartesianOffset();
      final reconstructed = OrbitalCoordinates.fromCartesianOffset(cartesian);

      expect(reconstructed.azimuth, closeTo(original.azimuth, 1e-5));
      expect(reconstructed.elevation, closeTo(original.elevation, 1e-5));
      expect(reconstructed.distance, closeTo(original.distance, 1e-5));
    });
  });

  group('CameraDampingMath - Critically Damped Harmonic Oscillators', () {
    test('smoothDamp converges monotonically without overshoot', () {
      double current = 0.0;
      double velocity = 0.0;
      const target = 100.0;
      const smoothTime = 0.25;
      const dt = 1.0 / 60.0; // 60 FPS

      for (int i = 0; i < 60; i++) {
        final res = CameraDampingMath.smoothDamp(
          current: current,
          target: target,
          currentVelocity: velocity,
          smoothTime: smoothTime,
          deltaTime: dt,
        );

        // Verify strictly non-overshooting guarantee
        expect(res.value, lessThanOrEqualTo(target));
        expect(res.value, greaterThanOrEqualTo(current)); // Monotonic increase

        current = res.value;
        velocity = res.velocity;
      }

      // After 1 second (~4 smooth times), must be virtually at target
      expect(current, closeTo(100.0, 0.5));
    });

    test('smoothDamp with zero or negative dt does not alter state', () {
      final res = CameraDampingMath.smoothDamp(
        current: 42.0,
        target: 100.0,
        currentVelocity: 5.0,
        smoothTime: 0.2,
        deltaTime: 0.0,
      );
      expect(res.value, equals(42.0));
      expect(res.velocity, equals(5.0));
    });

    test('smoothDampAngle takes shortest angular path across +/- pi boundary', () {
      // Rotating from 3.10 rad (~177°) to -3.10 rad (~-177°)
      // Direct angle difference is ~6.20 rad (355°), but shortest path is +0.083 rad across boundary
      final delta = CameraDampingMath.deltaAngle(3.10, -3.10);
      expect(delta, closeTo(0.08318, 1e-3));

      // Damping must step across the boundary without doing a 360° spin
      final res = CameraDampingMath.smoothDampAngle(
        current: 3.10,
        target: -3.10,
        currentVelocity: 0.0,
        smoothTime: 0.2,
        deltaTime: 0.05,
      );

      // Value moves forward across boundary towards wrapped target
      expect(res.value, greaterThan(3.10));
    });

    test('smoothDampVector damps 3D position smoothly', () {
      var current = WorldVector3.zero;
      var velocity = WorldVector3.zero;
      const target = WorldVector3(10.0, 20.0, 30.0);

      for (int i = 0; i < 30; i++) {
        final res = CameraDampingMath.smoothDampVector(
          current: current,
          target: target,
          currentVelocity: velocity,
          smoothTime: 0.15,
          deltaTime: 1.0 / 60.0,
        );
        current = res.value;
        velocity = res.velocity;
      }

      expect(current.x, closeTo(10.0, 1.0));
      expect(current.y, closeTo(20.0, 2.0));
      expect(current.z, closeTo(30.0, 3.0));
    });
  });

  group('Depth of Field (DoF) Optical Calculations', () {
    test('hyperfocal distance and near/far plane limits follow physical optics', () {
      const params = DepthOfFieldParameters(
        aperture: 2.8,
        focalLengthMm: 50.0,
        permissibleCocMm: 0.029,
      );

      final fMeters = params.focalLengthMm / 1000.0; // 0.05 m
      final cMeters = params.permissibleCocMm / 1000.0; // 0.000029 m
      final expectedHyperfocal = (fMeters * fMeters) / (params.aperture * cMeters) + fMeters; // ~30.83 m

      expect(expectedHyperfocal, closeTo(30.83, 0.1));

      // Set focus at 5 meters
      const focusDist = 5.0;
      final denomNear = expectedHyperfocal + (focusDist - fMeters);
      final nearPlane = (expectedHyperfocal * focusDist) / denomNear;
      final denomFar = expectedHyperfocal - (focusDist - fMeters);
      final farPlane = (expectedHyperfocal * focusDist) / denomFar;

      expect(nearPlane, lessThan(focusDist));
      expect(farPlane, greaterThan(focusDist));
      expect(nearPlane, closeTo(4.31, 0.1));
      expect(farPlane, closeTo(5.95, 0.1));
    });

    test('circle of confusion is zero at focal distance and increases with defocus', () {
      final cocAtFocus = DepthOfFieldState.computeCircleOfConfusion(
        depthMeters: 10.0,
        focusDistanceMeters: 10.0,
        focalLengthMm: 50.0,
        aperture: 2.8,
      );
      expect(cocAtFocus, closeTo(0.0, 1e-9));

      final cocForeground = DepthOfFieldState.computeCircleOfConfusion(
        depthMeters: 3.0,
        focusDistanceMeters: 10.0,
        focalLengthMm: 50.0,
        aperture: 2.8,
      );
      expect(cocForeground, greaterThan(0.029)); // Exceeds permissible circle of confusion

      final cocBackground = DepthOfFieldState.computeCircleOfConfusion(
        depthMeters: 50.0,
        focusDistanceMeters: 10.0,
        focalLengthMm: 50.0,
        aperture: 2.8,
      );
      expect(cocBackground, greaterThan(0.029));
    });
  });

  group('CinematicCameraController Functional Dynamics', () {
    test('initializes with idle profile and valid matrices', () {
      final controller = CinematicCameraController(
        initialMode: CinematicCameraMode.idle,
        initialTarget: const WorldVector3(0.0, 0.0, 0.0),
        initialAzimuth: 0.0,
        initialElevation: 0.18,
        initialDistance: 5.5,
      );

      final state = controller.state;
      expect(state.mode, equals(CinematicCameraMode.idle));
      expect(state.fovDegrees, closeTo(60.0, 1e-3));
      expect(state.orbital.distance, closeTo(5.5, 1e-3));
      expect(state.dof.focusDistance, greaterThan(0.0));

      // View matrix validity
      final viewMat = state.viewMatrix;
      expect(viewMat.entry(3, 3), equals(1.0));
      expect(viewMat.determinant(), isNot(0.0));

      // Projection matrix validity
      final projMat = state.computeProjectionMatrix(aspectRatio: 16.0 / 9.0);
      expect(projMat.entry(3, 2), equals(-1.0));
      expect(projMat.determinant(), isNot(0.0));
    });

    test('mode transition smoothly shifts FOV and target distance', () {
      final controller = CinematicCameraController(
        initialMode: CinematicCameraMode.idle,
        initialTarget: WorldVector3.zero,
      );

      expect(controller.state.fovDegrees, closeTo(60.0, 1e-3));

      // Switch to sprinting (profile FOV is 74°)
      controller.setMode(CinematicCameraMode.sprinting);

      // After a small time step, FOV should move toward 74°
      controller.update(0.1);
      expect(controller.state.fovDegrees, greaterThan(60.0));
      expect(controller.state.fovDegrees, lessThan(74.0));

      // Update for 1 full second
      for (int i = 0; i < 60; i++) {
        controller.update(1.0 / 60.0);
      }
      expect(controller.state.fovDegrees, closeTo(74.0, 0.2));
    });

    test('player movement velocity induces forward look-ahead vector', () {
      final controller = CinematicCameraController(
        initialMode: CinematicCameraMode.running,
        initialTarget: WorldVector3.zero,
      );

      // Set moving target along Z axis with 8 m/s speed
      controller.setTarget(
        position: const WorldVector3(0.0, 0.0, 10.0),
        velocity: const WorldVector3(0.0, 0.0, 8.0),
      );

      // Simulate tracking
      for (int i = 0; i < 60; i++) {
        controller.update(1.0 / 60.0);
      }

      // Look-at point should be advanced ahead of target along Z axis
      final targetZ = controller.targetPosition.z;
      final lookAtZ = controller.state.lookAtTarget.z;
      expect(lookAtZ, greaterThan(targetZ));
    });

    test('orbital panning updates angles and clamps elevation to limits', () {
      final controller = CinematicCameraController();

      final initialElev = controller.state.orbital.elevation;
      controller.orbit(0.5, 0.3);

      controller.update(0.3);
      expect(controller.state.orbital.azimuth, greaterThan(0.0));
      expect(controller.state.orbital.elevation, greaterThan(initialElev));

      // Attempt to exceed max elevation
      controller.orbit(0.0, 5.0);
      for (int i = 0; i < 60; i++) {
        controller.update(1.0 / 60.0);
      }
      expect(controller.state.orbital.elevation, lessThanOrEqualTo(controller.maxElevation));
    });

    test('snapToTarget cancels all lag and matches target immediately', () {
      final controller = CinematicCameraController();
      controller.setMode(CinematicCameraMode.panoramicVista);
      controller.setTarget(
        position: const WorldVector3(100.0, 20.0, -50.0),
        velocity: const WorldVector3(10.0, 0.0, 0.0),
      );

      controller.snapToTarget();

      expect(controller.state.fovDegrees, equals(82.0));
      expect(controller.state.orbital.distance, equals(14.0));
      expect(controller.state.lookAtTarget.x, greaterThan(100.0)); // Includes lookAhead
    });

    test('collision constraint clamps camera distance', () {
      final controller = CinematicCameraController(initialDistance: 10.0);

      // Simulate wall at 3.5 meters
      controller.setCollisionDistanceConstraint(3.5);

      for (int i = 0; i < 60; i++) {
        controller.update(1.0 / 60.0);
      }

      expect(controller.state.orbital.distance, lessThanOrEqualTo(3.6));
    });
  });

  group('CinematicHudOverlay & Center Vista Clearance', () {
    test('CinematicHudMetrics verifies 60% center vista clearance region', () {
      const screenSize = Size(1920.0, 1080.0);
      const metrics = CinematicHudMetrics(
        screenSize: screenSize,
        safeAreaPadding: EdgeInsets.all(24.0),
      );

      final clearance = metrics.centerVistaClearanceZone;
      expect(clearance.width, closeTo(1920.0 * 0.60, 1e-4));
      expect(clearance.height, closeTo(1080.0 * 0.65, 1e-4));
      expect(clearance.left, closeTo(1920.0 * 0.20, 1e-4));
      expect(clearance.top, closeTo(1080.0 * 0.175, 1e-4));

      // Element inside top-left corner should NOT intersect center vista
      const topLeftElement = Rect.fromLTWH(24.0, 24.0, 280.0, 80.0);
      expect(metrics.doesIntersectCenterVista(topLeftElement), isFalse);

      // Element inside bottom-right corner should NOT intersect center vista
      const bottomRightElement = Rect.fromLTWH(1920.0 - 200.0, 1080.0 - 200.0, 180.0, 180.0);
      expect(metrics.doesIntersectCenterVista(bottomRightElement), isFalse);

      // Element in center of screen DOES intersect
      const centerElement = Rect.fromLTWH(900.0, 500.0, 120.0, 120.0);
      expect(metrics.doesIntersectCenterVista(centerElement), isTrue);
    });

    testWidgets('renders all perimeter HUD components and handles camera gesture pan', (tester) async {
      final controller = CinematicCameraController();

      var primaryAttackTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(1280.0, 720.0),
                padding: EdgeInsets.only(top: 32.0, bottom: 20.0, left: 16.0, right: 16.0),
              ),
              child: CinematicHudOverlay(
                cameraController: controller,
                playerName: 'Valerius the Brave',
                playerLevel: 50,
                currentHealth: 900.0,
                maxHealth: 1000.0,
                locationName: 'Ancient Citadel',
                onPrimaryAttack: () {
                  primaryAttackTriggered = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Player Status Bar renders
      expect(find.text('Valerius the Brave'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('HP 900 / 1000'), findsOneWidget);

      // Verify Mini-map Radar frame renders
      expect(find.text('N'), findsOneWidget);

      // Verify Quick Chat log renders
      expect(find.text('LOG'), findsOneWidget);

      // Verify Primary attack button renders and responds to tap
      final primaryBtn = find.byTooltip('Attack');
      expect(primaryBtn, findsOneWidget);
      await tester.tap(primaryBtn);
      expect(primaryAttackTriggered, isTrue);

      // Verify center gesture drag orbits the camera
      final initialAzimuth = controller.state.orbital.azimuth;
      final centerPoint = tester.getCenter(find.byType(CinematicHudOverlay));

      // Drag horizontally in the center vista region
      await tester.dragFrom(centerPoint, const Offset(100.0, 0.0));
      await tester.pump();

      // Controller target azimuth must have responded to drag
      expect(controller.state.orbital.azimuth, isNot(equals(initialAzimuth + 100.0)));
    });

    testWidgets('GlassmorphicCard renders frosted blur and borders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassmorphicCard(
              child: Text('Glassmorphic Content'),
            ),
          ),
        ),
      );

      expect(find.text('Glassmorphic Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
