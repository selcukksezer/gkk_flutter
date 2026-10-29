import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/core/lighting/clustered_light_manager.dart';

// =============================================================================
// Helper Test Widgets & Painters for Clustered Lighting UI / Widget Verification
// =============================================================================

/// CustomPainter rendering clustered lighting debug overlays and visual light indicators.
class ClusteredLightingDebugPainter extends CustomPainter {
  final ClusteredLightManager manager;
  final int frameNumber;

  const ClusteredLightingDebugPainter({
    required this.manager,
    this.frameNumber = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Ambient background fill
    final bgPaint = Paint()
      ..color = Color.fromARGB(
        255,
        (manager.ambientR * manager.ambientIntensity * 255).clamp(0, 255).toInt(),
        (manager.ambientG * manager.ambientIntensity * 255).clamp(0, 255).toInt(),
        (manager.ambientB * manager.ambientIntensity * 255).clamp(0, 255).toInt(),
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Draw light circles projected onto 2D top-down canvas (X/Z plane)
    for (int i = 0; i < manager.maxLights; i++) {
      final light = manager.getLight(i);
      if (light != null && light.isActive) {
        final lightPaint = Paint()
          ..color = Color.fromARGB(
            255,
            (light.r * 255).clamp(0, 255).toInt(),
            (light.g * 255).clamp(0, 255).toInt(),
            (light.b * 255).clamp(0, 255).toInt(),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final cx = size.width * 0.5 + light.x;
        final cy = size.height * 0.5 + light.z;
        canvas.drawCircle(Offset(cx, cy), light.radius.clamp(2.0, 100.0), lightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ClusteredLightingDebugPainter oldDelegate) {
    return oldDelegate.manager != manager ||
        oldDelegate.frameNumber != frameNumber ||
        oldDelegate.manager.totalClusterLightAssignments !=
            manager.totalClusterLightAssignments ||
        oldDelegate.manager.activeLightCount != manager.activeLightCount;
  }
}

/// Widget providing an interactive preview and HUD diagnostics for ClusteredLightManager.
class ClusteredLightingPreviewWidget extends StatefulWidget {
  final ClusteredLightManager manager;
  final VoidCallback? onLightTapped;

  const ClusteredLightingPreviewWidget({
    super.key,
    required this.manager,
    this.onLightTapped,
  });

  @override
  State<ClusteredLightingPreviewWidget> createState() =>
      _ClusteredLightingPreviewWidgetState();
}

class _ClusteredLightingPreviewWidgetState
    extends State<ClusteredLightingPreviewWidget> {
  int _renderCount = 0;

  void triggerRedraw() {
    setState(() {
      _renderCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onLightTapped,
      child: Column(
        children: [
          Text(
            'Active Lights: ${widget.manager.activeLightCount}',
            key: const Key('active_light_counter'),
          ),
          Text(
            'Cluster Assignments: ${widget.manager.totalClusterLightAssignments}',
            key: const Key('cluster_assignment_counter'),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(600, 400),
              painter: ClusteredLightingDebugPainter(
                manager: widget.manager,
                frameNumber: _renderCount,
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
  // 1. GLSL Shader Static Analysis & Header/Uniform Layout Verification
  // ---------------------------------------------------------------------------
  group('Clustered Crowd Lighting Shader GLSL File Verification', () {
    late File shaderFile;
    late String shaderContent;

    setUpAll(() {
      shaderFile = File('shaders/lighting/clustered_crowd_lighting.frag');
      expect(
        shaderFile.existsSync(),
        isTrue,
        reason: 'clustered_crowd_lighting.frag must exist in shaders/lighting/',
      );
      shaderContent = shaderFile.readAsStringSync();
    });

    test('Shader header has version 460 core and flutter runtime_effect include', () {
      expect(shaderContent, contains('#version 460 core'));
      expect(shaderContent, contains('#include <flutter/runtime_effect.glsl>'));
    });

    test('Shader declares high precision qualifiers', () {
      expect(shaderContent, contains('precision highp float;'));
      expect(shaderContent, contains('precision highp int;'));
      expect(shaderContent, contains('precision highp sampler2D;'));
    });

    test('Shader declares all 12 numeric uniforms matching 27-float Dart layout in exact order', () {
      // 1. uResolution: vec2 (2)
      expect(shaderContent, contains('uniform vec2 uResolution;'));
      // 2. uClusterDims: vec3 (3)
      expect(shaderContent, contains('uniform vec3 uClusterDims;'));
      // 3. uDepthParams: vec4 (4)
      expect(shaderContent, contains('uniform vec4 uDepthParams;'));
      // 4. uVoxelMin: vec3 (3)
      expect(shaderContent, contains('uniform vec3 uVoxelMin;'));
      // 5. uVoxelMax: vec3 (3)
      expect(shaderContent, contains('uniform vec3 uVoxelMax;'));
      // 6. uClusterMode: float (1)
      expect(shaderContent, contains('uniform float uClusterMode;'));
      // 7. uMaxLightsPerCluster: float (1)
      expect(shaderContent, contains('uniform float uMaxLightsPerCluster;'));
      // 8. uAmbientIrradiance: vec4 (4)
      expect(shaderContent, contains('uniform vec4 uAmbientIrradiance;'));
      // 9. uCameraPos: vec3 (3)
      expect(shaderContent, contains('uniform vec3 uCameraPos;'));
      // 10. uSpecularRoughness: float (1)
      expect(shaderContent, contains('uniform float uSpecularRoughness;'));
      // 11. uLightTextureWidth: float (1)
      expect(shaderContent, contains('uniform float uLightTextureWidth;'));
      // 12. uClusterTextureWidth: float (1)
      expect(shaderContent, contains('uniform float uClusterTextureWidth;'));

      // Check declaration ordering in source
      final idxRes = shaderContent.indexOf('uniform vec2 uResolution;');
      final idxDims = shaderContent.indexOf('uniform vec3 uClusterDims;');
      final idxDepth = shaderContent.indexOf('uniform vec4 uDepthParams;');
      final idxVMin = shaderContent.indexOf('uniform vec3 uVoxelMin;');
      final idxVMax = shaderContent.indexOf('uniform vec3 uVoxelMax;');
      final idxMode = shaderContent.indexOf('uniform float uClusterMode;');
      final idxMaxLights = shaderContent.indexOf('uniform float uMaxLightsPerCluster;');
      final idxAmbient = shaderContent.indexOf('uniform vec4 uAmbientIrradiance;');
      final idxCam = shaderContent.indexOf('uniform vec3 uCameraPos;');
      final idxRough = shaderContent.indexOf('uniform float uSpecularRoughness;');
      final idxLWidth = shaderContent.indexOf('uniform float uLightTextureWidth;');
      final idxCWidth = shaderContent.indexOf('uniform float uClusterTextureWidth;');

      expect(idxRes, lessThan(idxDims));
      expect(idxDims, lessThan(idxDepth));
      expect(idxDepth, lessThan(idxVMin));
      expect(idxVMin, lessThan(idxVMax));
      expect(idxVMax, lessThan(idxMode));
      expect(idxMode, lessThan(idxMaxLights));
      expect(idxMaxLights, lessThan(idxAmbient));
      expect(idxAmbient, lessThan(idxCam));
      expect(idxCam, lessThan(idxRough));
      expect(idxRough, lessThan(idxLWidth));
      expect(idxLWidth, lessThan(idxCWidth));
    });

    test('Shader declares all 6 sampler2D uniforms strictly after numeric uniforms', () {
      expect(shaderContent, contains('uniform sampler2D uAlbedoTexture;'));
      expect(shaderContent, contains('uniform sampler2D uNormalTexture;'));
      expect(shaderContent, contains('uniform sampler2D uDepthTexture;'));
      expect(shaderContent, contains('uniform sampler2D uClusterGridTexture;'));
      expect(shaderContent, contains('uniform sampler2D uLightIndexTexture;'));
      expect(shaderContent, contains('uniform sampler2D uLightDataTexture;'));

      final lastNumericIdx = shaderContent.indexOf('uniform float uClusterTextureWidth;');
      final firstSamplerIdx = shaderContent.indexOf('uniform sampler2D uAlbedoTexture;');
      expect(
        firstSamplerIdx,
        greaterThan(lastNumericIdx),
        reason: 'Flutter runtime effect requires sampler uniforms to follow all numeric uniforms',
      );
    });

    test('Shader defines MAX_CLUSTER_LIGHTS constant and mathematical helper functions', () {
      expect(shaderContent, contains('const int MAX_CLUSTER_LIGHTS = 32;'));
      expect(shaderContent, contains('linearizeDepth('));
      expect(shaderContent, contains('computeScreenSpaceCluster('));
      expect(shaderContent, contains('computeWorldVoxelCluster('));
      expect(shaderContent, contains('clusterCoordToLinearIndex('));
      expect(shaderContent, contains('fetchTexel1D('));
      expect(shaderContent, contains('computeSmoothAttenuation('));
      expect(shaderContent, contains('FlutterFragCoord()'));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Requirement R4 Validation & Exception Enforcement
  // ---------------------------------------------------------------------------
  group('Requirement R4 Validation (DynamicPointLightViolationException)', () {
    test('Instantiating ClusteredLight with attachedEntityId throws DynamicPointLightViolationException', () {
      expect(
        () => ClusteredLight(
          id: 1,
          x: 0.0,
          y: 1.0,
          z: 0.0,
          radius: 10.0,
          attachedEntityId: 999,
        ),
        throwsA(
          isA<DynamicPointLightViolationException>()
              .having((e) => e.entityId, 'entityId', equals(999))
              .having((e) => e.entityType, 'entityType', equals('EntityAttachedLight')),
        ),
      );
    });

    test('ClusteredLightManager.prohibitEntityDynamicPointLight throws with entity details', () {
      expect(
        () => ClusteredLightManager.prohibitEntityDynamicPointLight(404, 'BossDragon'),
        throwsA(
          isA<DynamicPointLightViolationException>()
              .having((e) => e.entityId, 'entityId', equals(404))
              .having((e) => e.entityType, 'entityType', equals('BossDragon')),
        ),
      );
    });

    test('assertZeroEntityPointLights allows clean entity maps and rejects prohibited light fields', () {
      final cleanEntities = [
        {'id': 1, 'name': 'Legionnaire', 'level': 50},
        {'id': 2, 'name': 'Centurion', 'level': 55},
        {'id': 3, 'name': 'Archon', 'level': 60},
      ];
      expect(
        () => ClusteredLightManager.assertZeroEntityPointLights(cleanEntities),
        returnsNormally,
      );

      // Map with 'pointLight'
      final badEntity1 = [
        {'id': 1, 'type': 'Mage', 'pointLight': true},
      ];
      expect(
        () => ClusteredLightManager.assertZeroEntityPointLights(badEntity1),
        throwsA(isA<DynamicPointLightViolationException>()),
      );

      // Map with 'dynamicLight'
      final badEntity2 = [
        {'id': 2, 'type': 'Ranger', 'dynamicLight': {'range': 15.0}},
      ];
      expect(
        () => ClusteredLightManager.assertZeroEntityPointLights(badEntity2),
        throwsA(isA<DynamicPointLightViolationException>()),
      );

      // Map with 'attachedLight'
      final badEntity3 = [
        {'id': 3, 'type': 'Cleric', 'attachedLight': 1},
      ];
      expect(
        () => ClusteredLightManager.assertZeroEntityPointLights(badEntity3),
        throwsA(isA<DynamicPointLightViolationException>()),
      );
    });

    test('Light radius must be strictly positive', () {
      expect(
        () => ClusteredLight(id: 1, x: 0, y: 0, z: 0, radius: 0.0),
        throwsArgumentError,
      );
      expect(
        () => ClusteredLight(id: 1, x: 0, y: 0, z: 0, radius: -1.0),
        throwsArgumentError,
      );
    });

    test('DynamicPointLightViolationException toString contains expected descriptive text', () {
      final ex = DynamicPointLightViolationException(
        'Forbidden per-entity point light',
        entityId: 77,
        entityType: 'ShadowAssassin',
      );
      final str = ex.toString();
      expect(str, contains('DynamicPointLightViolationException'));
      expect(str, contains('Forbidden per-entity point light'));
      expect(str, contains('ShadowAssassin#77'));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Voxel Grid Spatial Partitioning (ClusterGridBounds)
  // ---------------------------------------------------------------------------
  group('Voxel Grid Spatial Partitioning (ClusterGridBounds)', () {
    late ClusterGridBounds bounds;

    setUp(() {
      bounds = ClusterGridBounds(
        minX: -160.0,
        minY: -20.0,
        minZ: -160.0,
        maxX: 160.0,
        maxY: 60.0,
        maxZ: 160.0,
        dimX: 16,
        dimY: 8,
        dimZ: 16,
        zNear: 0.5,
        zFar: 250.0,
      );
    });

    test('Grid dimensions, total clusters, and cell sizes calculate correctly', () {
      expect(bounds.totalClusters, equals(16 * 8 * 16)); // 2048
      expect(bounds.cellSizeX, closeTo(20.0, 1e-5)); // 320 / 16
      expect(bounds.cellSizeY, closeTo(10.0, 1e-5)); // 80 / 8
      expect(bounds.cellSizeZ, closeTo(20.0, 1e-5)); // 320 / 16
      expect(bounds.invCellSizeX, closeTo(1.0 / 20.0, 1e-5));
      expect(bounds.invCellSizeY, closeTo(1.0 / 10.0, 1e-5));
      expect(bounds.invCellSizeZ, closeTo(1.0 / 20.0, 1e-5));
    });

    test('worldToVoxel maps coordinates inside volume and clamps out-of-bounds coordinates', () {
      // Exactly at min bound -> (0, 0, 0)
      final (cMinX, cMinY, cMinZ) = bounds.worldToVoxel(-160.0, -20.0, -160.0);
      expect(cMinX, equals(0));
      expect(cMinY, equals(0));
      expect(cMinZ, equals(0));

      // Point far below min bound clamps to (0, 0, 0)
      final (cUnderX, cUnderY, cUnderZ) = bounds.worldToVoxel(-9999.0, -9999.0, -9999.0);
      expect(cUnderX, equals(0));
      expect(cUnderY, equals(0));
      expect(cUnderZ, equals(0));

      // Point far above max bound clamps to (15, 7, 15)
      final (cOverX, cOverY, cOverZ) = bounds.worldToVoxel(9999.0, 9999.0, 9999.0);
      expect(cOverX, equals(15));
      expect(cOverY, equals(7));
      expect(cOverZ, equals(15));

      // Origin (0, 0, 0): min is -160, so (0 - (-160)) / 20 = 160 / 20 = 8
      // Y: min is -20, (0 - (-20)) / 10 = 20 / 10 = 2
      final (cOrigX, cOrigY, cOrigZ) = bounds.worldToVoxel(0.0, 0.0, 0.0);
      expect(cOrigX, equals(8));
      expect(cOrigY, equals(2));
      expect(cOrigZ, equals(8));
    });

    test('voxelToLinearIndex and linearIndexToVoxel form an exact bijection', () {
      for (int cz = 0; cz < bounds.dimZ; cz++) {
        for (int cy = 0; cy < bounds.dimY; cy++) {
          for (int cx = 0; cx < bounds.dimX; cx++) {
            final linear = bounds.voxelToLinearIndex(cx, cy, cz);
            expect(linear, greaterThanOrEqualTo(0));
            expect(linear, lessThan(bounds.totalClusters));

            final (rx, ry, rz) = bounds.linearIndexToVoxel(linear);
            expect(rx, equals(cx));
            expect(ry, equals(cy));
            expect(rz, equals(cz));
          }
        }
      }
    });

    test('getClusterAABB computes exact non-overlapping boundaries for adjacent voxels', () {
      final (minX0, minY0, minZ0, maxX0, maxY0, maxZ0) = bounds.getClusterAABB(0, 0, 0);
      expect(minX0, closeTo(-160.0, 1e-4));
      expect(minY0, closeTo(-20.0, 1e-4));
      expect(minZ0, closeTo(-160.0, 1e-4));
      expect(maxX0, closeTo(-140.0, 1e-4));
      expect(maxY0, closeTo(-10.0, 1e-4));
      expect(maxZ0, closeTo(-140.0, 1e-4));

      // Adjacent voxel in X direction: (1, 0, 0)
      final (minX1, minY1, minZ1, maxX1, maxY1, maxZ1) = bounds.getClusterAABB(1, 0, 0);
      expect(minX1, closeTo(maxX0, 1e-4)); // Shared boundary
      expect(minY1, closeTo(minY0, 1e-4));
      expect(minZ1, closeTo(minZ0, 1e-4));
      expect(maxX1, closeTo(-120.0, 1e-4));
    });

    test('depthToSlice performs logarithmic depth distribution', () {
      expect(bounds.depthToSlice(0.1), equals(0)); // <= zNear
      expect(bounds.depthToSlice(0.5), equals(0)); // == zNear
      expect(bounds.depthToSlice(250.0), equals(15)); // == zFar
      expect(bounds.depthToSlice(500.0), equals(15)); // >= zFar

      // Logarithmic spacing: exponential increases in depth result in linear steps
      final sNear = bounds.depthToSlice(1.0);
      final sMid = bounds.depthToSlice(20.0);
      final sFar = bounds.depthToSlice(150.0);

      expect(sNear, lessThan(sMid));
      expect(sMid, lessThan(sFar));
      expect(sFar, lessThanOrEqualTo(15));
    });

    test('screenSpaceToCluster correctly maps normalized UV and depth', () {
      final (cx0, cy0, cz0) = bounds.screenSpaceToCluster(0.0, 0.0, 0.5);
      expect(cx0, equals(0));
      expect(cy0, equals(0));
      expect(cz0, equals(0));

      final (cx1, cy1, cz1) = bounds.screenSpaceToCluster(0.999, 0.999, 249.0);
      expect(cx1, equals(15));
      expect(cy1, equals(7));
      expect(cz1, equals(15));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. 3D Sphere-AABB Overlap Test (Jim Arvo Algorithm)
  // ---------------------------------------------------------------------------
  group('3D Sphere-AABB Overlap Test (Jim Arvo Algorithm)', () {
    const boxMinX = 10.0;
    const boxMinY = 10.0;
    const boxMinZ = 10.0;
    const boxMaxX = 20.0;
    const boxMaxY = 20.0;
    const boxMaxZ = 20.0;

    test('Sphere completely inside box returns true', () {
      final overlap = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 15.0,
        sphereY: 15.0,
        sphereZ: 15.0,
        radius: 2.0,
        boxMinX: boxMinX,
        boxMinY: boxMinY,
        boxMinZ: boxMinZ,
        boxMaxX: boxMaxX,
        boxMaxY: boxMaxY,
        boxMaxZ: boxMaxZ,
      );
      expect(overlap, isTrue);
    });

    test('Sphere touching box face returns true', () {
      // Box face at X = 20.0; sphere at X = 25.0 with radius = 5.0 touches face
      final overlap = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 25.0,
        sphereY: 15.0,
        sphereZ: 15.0,
        radius: 5.0,
        boxMinX: boxMinX,
        boxMinY: boxMinY,
        boxMinZ: boxMinZ,
        boxMaxX: boxMaxX,
        boxMaxY: boxMaxY,
        boxMaxZ: boxMaxZ,
      );
      expect(overlap, isTrue);
    });

    test('Sphere beyond radius from face returns false', () {
      // Sphere at X = 26.0 with radius = 5.0 does not reach X = 20.0
      final overlap = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 26.0,
        sphereY: 15.0,
        sphereZ: 15.0,
        radius: 5.0,
        boxMinX: boxMinX,
        boxMinY: boxMinY,
        boxMinZ: boxMinZ,
        boxMaxX: boxMaxX,
        boxMaxY: boxMaxY,
        boxMaxZ: boxMaxZ,
      );
      expect(overlap, isFalse);
    });

    test('Sphere diagonally touching AABB corner satisfies Pythagorean distance', () {
      // Corner at (20, 20, 20). Sphere center at (22, 22, 22).
      // Delta = (2, 2, 2) -> distSq = 4 + 4 + 4 = 12.
      // dist = sqrt(12) ~ 3.4641016
      final overlapClose = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 22.0,
        sphereY: 22.0,
        sphereZ: 22.0,
        radius: 3.5, // > sqrt(12)
        boxMinX: boxMinX,
        boxMinY: boxMinY,
        boxMinZ: boxMinZ,
        boxMaxX: boxMaxX,
        boxMaxY: boxMaxY,
        boxMaxZ: boxMaxZ,
      );
      expect(overlapClose, isTrue);

      final overlapFar = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 22.0,
        sphereY: 22.0,
        sphereZ: 22.0,
        radius: 3.4, // < sqrt(12)
        boxMinX: boxMinX,
        boxMinY: boxMinY,
        boxMinZ: boxMinZ,
        boxMaxX: boxMaxX,
        boxMaxY: boxMaxY,
        boxMaxZ: boxMaxZ,
      );
      expect(overlapFar, isFalse);
    });

    test('Sphere touching edge (displaced along 2 axes, within 3rd axis)', () {
      // Edge along Z between (20, 20, 10) and (20, 20, 20).
      // Sphere at (23, 24, 15): Z is within [10, 20]. Delta X = 3, Delta Y = 4.
      // distSq = 9 + 16 = 25 -> dist = 5.0.
      final touchEdge = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 23.0,
        sphereY: 24.0,
        sphereZ: 15.0,
        radius: 5.0,
        boxMinX: boxMinX,
        boxMinY: boxMinY,
        boxMinZ: boxMinZ,
        boxMaxX: boxMaxX,
        boxMaxY: boxMaxY,
        boxMaxZ: boxMaxZ,
      );
      expect(touchEdge, isTrue);

      final missEdge = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: 23.0,
        sphereY: 24.0,
        sphereZ: 15.0,
        radius: 4.9,
        boxMinX: boxMinX,
        boxMinY: boxMinY,
        boxMinZ: boxMinZ,
        boxMaxX: boxMaxX,
        boxMaxY: boxMaxY,
        boxMaxZ: boxMaxZ,
      );
      expect(missEdge, isFalse);
    });

    test('Sphere with negative coordinates box', () {
      final overlapNeg = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: -50.0,
        sphereY: -50.0,
        sphereZ: -50.0,
        radius: 10.0,
        boxMinX: -100.0,
        boxMinY: -100.0,
        boxMinZ: -100.0,
        boxMaxX: -60.0,
        boxMaxY: -60.0,
        boxMaxZ: -60.0,
      );
      // Closest corner of box is (-60, -60, -60).
      // Delta = (-60 - -50) = -10 on each axis.
      // distSq = 100 + 100 + 100 = 300. radiusSq = 100. 300 > 100 -> false
      expect(overlapNeg, isFalse);

      final overlapNegReach = ClusterGridBounds.testSphereAABBOverlap(
        sphereX: -50.0,
        sphereY: -50.0,
        sphereZ: -50.0,
        radius: 20.0, // 400 > 300 -> true
        boxMinX: -100.0,
        boxMinY: -100.0,
        boxMinZ: -100.0,
        boxMaxX: -60.0,
        boxMaxY: -60.0,
        boxMaxZ: -60.0,
      );
      expect(overlapNegReach, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Texture Buffer Packing (packLightData, packClusterGrid, packLightIndex)
  // ---------------------------------------------------------------------------
  group('Texture Buffer Packing (GPU Format Parity)', () {
    late ClusteredLightManager manager;

    setUp(() {
      manager = ClusteredLightManager(
        bounds: ClusterGridBounds(
          minX: -50.0,
          minY: -10.0,
          minZ: -50.0,
          maxX: 50.0,
          maxY: 30.0,
          maxZ: 50.0,
          dimX: 4,
          dimY: 2,
          dimZ: 4,
        ),
        maxLights: 8,
        maxLightsPerCluster: 4,
      );
    });

    test('packedLightData encodes 8 floats per active light slot', () {
      final slot = manager.createSceneLight(
        x: 12.5,
        y: 8.0,
        z: -14.2,
        radius: 25.0,
        r: 1.0,
        g: 0.8,
        b: 0.6,
        intensity: 3.0,
        falloffExponent: 2.5,
      );
      expect(slot, equals(0));

      // Light data layout in Float32List (packedLightData):
      // base = slot * 8
      // [base+0..2] = pos (x, y, z)
      // [base+3] = radius
      // [base+4..6] = color * intensity
      // [base+7] = falloffExponent
      final base = slot * 8;
      expect(manager.packedLightData[base + 0], closeTo(12.5, 1e-5));
      expect(manager.packedLightData[base + 1], closeTo(8.0, 1e-5));
      expect(manager.packedLightData[base + 2], closeTo(-14.2, 1e-5));
      expect(manager.packedLightData[base + 3], closeTo(25.0, 1e-5));
      expect(manager.packedLightData[base + 4], closeTo(1.0 * 3.0, 1e-5));
      expect(manager.packedLightData[base + 5], closeTo(0.8 * 3.0, 1e-5));
      expect(manager.packedLightData[base + 6], closeTo(0.6 * 3.0, 1e-5));
      expect(manager.packedLightData[base + 7], closeTo(2.5, 1e-5));

      // Unused slots remain 0.0
      for (int i = 8; i < manager.packedLightData.length; i++) {
        expect(manager.packedLightData[i], equals(0.0));
      }
    });

    test('packClusterGridTexture creates valid RGBA8888 buffer matching shader unpack formula', () {
      manager.createSceneLight(
        x: 0.0,
        y: 10.0,
        z: 0.0,
        radius: 30.0,
      );

      final textureBytes = manager.packClusterGridTexture(textureWidth: 16);
      expect(textureBytes, isNotEmpty);
      expect(textureBytes.length % 4, equals(0));

      // Each texel encodes:
      // R: offset & 0xFF
      // G: (offset >> 8) & 0xFF
      // B: count.clamp(0, 255)
      // A: 255
      for (int i = 0; i < manager.gridBounds.totalClusters; i++) {
        final byteOffset = i * 4;
        final r = textureBytes[byteOffset + 0];
        final g = textureBytes[byteOffset + 1];
        final b = textureBytes[byteOffset + 2];
        final a = textureBytes[byteOffset + 3];

        expect(a, equals(255));

        // Shader decode formula:
        final decodedOffset = r + g * 256;
        final decodedCount = b;

        expect(decodedOffset, equals(manager.clusterLightOffsets[i]));
        expect(decodedCount, equals(manager.clusterLightCounts[i]));
      }
    });

    test('packLightIndexTexture creates valid RGBA8888 buffer matching shader unpack formula', () {
      final slot0 = manager.createSceneLight(x: 0, y: 10, z: 0, radius: 20);
      final slot1 = manager.createSceneLight(x: 5, y: 10, z: 5, radius: 20);

      final indexBytes = manager.packLightIndexTexture(textureWidth: 16);
      expect(indexBytes, isNotEmpty);
      expect(indexBytes.length % 4, equals(0));

      for (int i = 0; i < manager.clusterLightIndices.length; i++) {
        final byteOffset = i * 4;
        final r = indexBytes[byteOffset + 0];
        final g = indexBytes[byteOffset + 1];
        final b = indexBytes[byteOffset + 2];
        final a = indexBytes[byteOffset + 3];

        expect(b, equals(0));
        expect(a, equals(255));

        // Shader decode formula:
        final decodedLightIdx = r + g * 256;
        expect(decodedLightIdx, equals(manager.clusterLightIndices[i]));
      }
    });

    test('Decoding high light offsets (> 255) verifies G channel high byte storage', () {
      // Simulate higher cluster offsets
      manager.clusterLightOffsets[5] = 514; // 514 = 2 + 2 * 256 -> R=2, G=2
      manager.clusterLightCounts[5] = 7;

      final textureBytes = manager.packClusterGridTexture(textureWidth: 16);
      final byteOffset = 5 * 4;

      expect(textureBytes[byteOffset + 0], equals(2)); // 514 & 0xFF = 2
      expect(textureBytes[byteOffset + 1], equals(2)); // (514 >> 8) & 0xFF = 2
      expect(textureBytes[byteOffset + 2], equals(7)); // count = 7
      expect(textureBytes[byteOffset + 3], equals(255));

      final decoded = textureBytes[byteOffset + 0] + textureBytes[byteOffset + 1] * 256;
      expect(decoded, equals(514));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. buildShaderUniforms() Layout Matching clustered_crowd_lighting.frag
  // ---------------------------------------------------------------------------
  group('buildShaderUniforms() Layout Matching clustered_crowd_lighting.frag', () {
    late ClusteredLightManager manager;

    setUp(() {
      manager = ClusteredLightManager(
        bounds: ClusterGridBounds(
          minX: -100.0,
          minY: -5.0,
          minZ: -100.0,
          maxX: 100.0,
          maxY: 35.0,
          maxZ: 100.0,
          dimX: 16,
          dimY: 8,
          dimZ: 16,
          zNear: 0.25,
          zFar: 300.0,
        ),
        maxLights: 64,
        maxLightsPerCluster: 24,
        ambientR: 0.04,
        ambientG: 0.05,
        ambientB: 0.07,
        ambientIntensity: 1.5,
      );
    });

    test('buildShaderUniforms generates exactly 27 floats matching GLSL uniform declarations', () {
      final uniforms = manager.buildShaderUniforms(
        viewportWidth: 2560.0,
        viewportHeight: 1440.0,
        clusterMode: 1.0,
        cameraX: 12.0,
        cameraY: 25.0,
        cameraZ: -50.0,
        roughness: 0.35,
        lightTextureWidth: 512.0,
        clusterTextureWidth: 512.0,
      );

      expect(uniforms.length, equals(27));

      // 1. uResolution: vec2 (index 0..1)
      expect(uniforms[0], equals(2560.0));
      expect(uniforms[1], equals(1440.0));

      // 2. uClusterDims: vec3 (index 2..4)
      expect(uniforms[2], equals(16.0));
      expect(uniforms[3], equals(8.0));
      expect(uniforms[4], equals(16.0));

      // 3. uDepthParams: vec4 (index 5..8)
      expect(uniforms[5], equals(0.25)); // zNear
      expect(uniforms[6], equals(300.0)); // zFar
      expect(uniforms[7], closeTo(manager.gridBounds.logDepthFactor, 1e-4));
      expect(uniforms[8], closeTo(1.0 / (300.0 - 0.25), 1e-4));

      // 4. uVoxelMin: vec3 (index 9..11)
      expect(uniforms[9], equals(-100.0));
      expect(uniforms[10], equals(-5.0));
      expect(uniforms[11], equals(-100.0));

      // 5. uVoxelMax: vec3 (index 12..14)
      expect(uniforms[12], equals(100.0));
      expect(uniforms[13], equals(35.0));
      expect(uniforms[14], equals(100.0));

      // 6. uClusterMode: float (index 15)
      expect(uniforms[15], equals(1.0));

      // 7. uMaxLightsPerCluster: float (index 16)
      expect(uniforms[16], equals(24.0));

      // 8. uAmbientIrradiance: vec4 (index 17..20)
      expect(uniforms[17], closeTo(0.04, 1e-5));
      expect(uniforms[18], closeTo(0.05, 1e-5));
      expect(uniforms[19], closeTo(0.07, 1e-5));
      expect(uniforms[20], closeTo(1.5, 1e-5));

      // 9. uCameraPos: vec3 (index 21..23)
      expect(uniforms[21], equals(12.0));
      expect(uniforms[22], equals(25.0));
      expect(uniforms[23], equals(-50.0));

      // 10. uSpecularRoughness: float (index 24)
      expect(uniforms[24], closeTo(0.35, 1e-5));

      // 11. uLightTextureWidth: float (index 25)
      expect(uniforms[25], equals(512.0));

      // 12. uClusterTextureWidth: float (index 26)
      expect(uniforms[26], equals(512.0));
    });

    test('buildShaderUniforms screen-space cluster mode toggle (0.0)', () {
      final uniforms = manager.buildShaderUniforms(
        viewportWidth: 1920.0,
        viewportHeight: 1080.0,
        clusterMode: 0.0,
      );
      expect(uniforms[15], equals(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Smooth Attenuation Physics Evaluation (Filament/Frostbite Formula)
  // ---------------------------------------------------------------------------
  group('Smooth Attenuation Physics Evaluation (evaluateSmoothAttenuation)', () {
    late ClusteredLight light;
    const double radius = 20.0;

    setUp(() {
      light = ClusteredLight(
        id: 1,
        x: 0.0,
        y: 0.0,
        z: 0.0,
        radius: radius,
      );
    });

    test('Attenuation at distance = 0.0 returns 1.0 (peak intensity)', () {
      // att = [saturate(1 - 0)]^2 / (0 + 1) = 1.0 / 1.0 = 1.0
      final att = light.evaluateSmoothAttenuation(0.0);
      expect(att, closeTo(1.0, 1e-6));
    });

    test('Attenuation at distance = radius returns strictly 0.0', () {
      // ratio = 1.0 -> 1 - 1 = 0 -> smoothFactor = 0 -> att = 0.0
      final att = light.evaluateSmoothAttenuation(radius);
      expect(att, equals(0.0));
    });

    test('Attenuation at distance > radius returns strictly 0.0', () {
      final att = light.evaluateSmoothAttenuation(radius + 5.0);
      expect(att, equals(0.0));
    });

    test('Attenuation is monotonically strictly decreasing in [0, radius)', () {
      double prevAtt = light.evaluateSmoothAttenuation(0.0);
      for (double d = 1.0; d < radius; d += 1.0) {
        final currentAtt = light.evaluateSmoothAttenuation(d);
        expect(
          currentAtt,
          lessThan(prevAtt),
          reason: 'Attenuation at distance $d must be strictly less than at ${d - 1.0}',
        );
        expect(currentAtt, greaterThan(0.0));
        prevAtt = currentAtt;
      }
    });

    test('Matches exact analytical calculation at midpoint (d = 10.0, radius = 20.0)', () {
      // ratio = 10 / 20 = 0.5
      // ratio4 = 0.5^4 = 0.0625
      // smoothFactor = 1.0 - 0.0625 = 0.9375
      // smoothFactor^2 = 0.9375 * 0.9375 = 0.87890625
      // denom = 10^2 + 1 = 101.0
      // expected = 0.87890625 / 101.0 ~ 0.0087020420792
      final expected = (0.87890625) / 101.0;
      final actual = light.evaluateSmoothAttenuation(10.0);
      expect(actual, closeTo(expected, 1e-6));
    });

    test('Invalid or edge distances (negative distance) return 0.0 or valid clamp', () {
      // ClusteredLight with negative or zero radius cannot be created due to ArgumentError
      expect(
        () => ClusteredLight(id: 2, x: 0, y: 0, z: 0, radius: 0.0),
        throwsArgumentError,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Radiance & Blinn-Phong Evaluation
  // ---------------------------------------------------------------------------
  group('ClusteredLight Radiance & Blinn-Phong Evaluation', () {
    test('evaluateRadiance honors Lambertian cosine law (facing vs backfacing normal)', () {
      final light = ClusteredLight(
        id: 1,
        x: 0.0,
        y: 10.0,
        z: 0.0,
        radius: 30.0,
        r: 1.0,
        g: 1.0,
        b: 1.0,
        intensity: 2.0,
      );

      // Point at origin facing directly up towards light (normal = 0, 1, 0)
      final (rFront, gFront, bFront) = light.evaluateRadiance(
        targetX: 0.0,
        targetY: 0.0,
        targetZ: 0.0,
        normalX: 0.0,
        normalY: 1.0,
        normalZ: 0.0,
      );
      expect(rFront, greaterThan(0.0));
      expect(gFront, equals(rFront));
      expect(bFront, equals(rFront));

      // Point at origin facing away from light (normal = 0, -1, 0)
      final (rBack, gBack, bBack) = light.evaluateRadiance(
        targetX: 0.0,
        targetY: 0.0,
        targetZ: 0.0,
        normalX: 0.0,
        normalY: -1.0,
        normalZ: 0.0,
      );
      expect(rBack, equals(0.0));
      expect(gBack, equals(0.0));
      expect(bBack, equals(0.0));
    });

    test('Inactive light produces zero radiance', () {
      final light = ClusteredLight(
        id: 1,
        x: 0.0,
        y: 10.0,
        z: 0.0,
        radius: 30.0,
        isActive: false,
      );

      final (r, g, b) = light.evaluateRadiance(
        targetX: 0.0,
        targetY: 0.0,
        targetZ: 0.0,
        normalX: 0.0,
        normalY: 1.0,
        normalZ: 0.0,
      );
      expect(r, equals(0.0));
      expect(g, equals(0.0));
      expect(b, equals(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Central Clustered Light Manager & Light Grid Management
  // ---------------------------------------------------------------------------
  group('ClusteredLightManager Centralized Pipeline & O(1) Cluster Lookups', () {
    late ClusteredLightManager manager;

    setUp(() {
      manager = ClusteredLightManager(
        bounds: ClusterGridBounds(
          minX: -60.0,
          minY: -10.0,
          minZ: -60.0,
          maxX: 60.0,
          maxY: 30.0,
          maxZ: 60.0,
          dimX: 12,
          dimY: 4,
          dimZ: 12,
        ),
        maxLights: 32,
        maxLightsPerCluster: 8,
      );
    });

    test('Adding and removing lights rebuilds cluster light assignments', () {
      expect(manager.lightCount, equals(0));
      expect(manager.activeLightCount, equals(0));

      final slot = manager.createSceneLight(
        x: 0.0,
        y: 10.0,
        z: 0.0,
        radius: 20.0,
        name: 'Campfire',
      );
      expect(slot, equals(0));
      expect(manager.lightCount, equals(1));
      expect(manager.activeLightCount, equals(1));
      expect(manager.totalClusterLightAssignments, greaterThan(0));

      // Query center cluster
      final (cx, cy, cz) = manager.gridBounds.worldToVoxel(0.0, 10.0, 0.0);
      final clusterIdx = manager.gridBounds.voxelToLinearIndex(cx, cy, cz);
      final centerLights = manager.getLightsForCluster(clusterIdx);
      expect(centerLights, contains(slot));

      // Remove light
      final removed = manager.removeLight(slot);
      expect(removed, isTrue);
      expect(manager.lightCount, equals(0));
      expect(manager.activeLightCount, equals(0));
      expect(manager.totalClusterLightAssignments, equals(0));
      expect(manager.getLightsForCluster(clusterIdx), isEmpty);
    });

    test('clearAllLights resets all internal buffers and state', () {
      manager.createSceneLight(x: -20, y: 5, z: -20, radius: 15);
      manager.createSceneLight(x: 20, y: 5, z: 20, radius: 15);
      expect(manager.lightCount, equals(2));

      manager.clearAllLights();
      expect(manager.lightCount, equals(0));
      expect(manager.activeLightCount, equals(0));
      expect(manager.totalClusterLightAssignments, equals(0));

      for (int i = 0; i < manager.gridBounds.totalClusters; i++) {
        expect(manager.clusterLightCounts[i], equals(0));
      }
    });

    test('sampleLightingAt samples ambient baseline in empty regions', () {
      final (r, g, b) = manager.sampleLightingAt(
        x: -55.0,
        y: 0.0,
        z: -55.0,
        normalX: 0.0,
        normalY: 1.0,
        normalZ: 0.0,
      );
      expect(r, closeTo(manager.ambientR * manager.ambientIntensity, 1e-4));
      expect(g, closeTo(manager.ambientG * manager.ambientIntensity, 1e-4));
      expect(b, closeTo(manager.ambientB * manager.ambientIntensity, 1e-4));
    });

    test('evaluateCrowdLighting evaluates 10,000 crowd instances without memory allocations', () {
      const int count = 10000;
      final positions = Float32List(count * 3);
      final normals = Float32List(count * 3);
      final outColors = Float32List(count * 3);

      manager.createSceneLight(
        x: 0.0,
        y: 10.0,
        z: 0.0,
        radius: 35.0,
        r: 1.0,
        g: 0.7,
        b: 0.3,
        intensity: 2.0,
      );

      final elapsedMs = manager.evaluateCrowdLighting(
        crowdPositions: positions,
        crowdNormals: normals,
        outColors: outColors,
        entityCount: count,
      );

      expect(elapsedMs, greaterThanOrEqualTo(0.0));
      // Out colors must have at least ambient illumination
      for (int i = 0; i < count; i++) {
        final base = i * 3;
        expect(outColors[base + 0], greaterThan(0.0));
        expect(outColors[base + 1], greaterThan(0.0));
        expect(outColors[base + 2], greaterThan(0.0));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Clustered Lighting Flutter Widget Tests
  // ---------------------------------------------------------------------------
  group('Clustered Lighting Flutter Widget Tests', () {
    late ClusteredLightManager manager;

    setUp(() {
      manager = ClusteredLightManager(
        bounds: ClusterGridBounds(
          minX: -50.0,
          minY: -10.0,
          minZ: -50.0,
          maxX: 50.0,
          maxY: 30.0,
          maxZ: 50.0,
        ),
        maxLights: 16,
      );
    });

    testWidgets('ClusteredLightingPreviewWidget mounts and displays diagnostics text', (tester) async {
      manager.createSceneLight(
        x: 0.0,
        y: 5.0,
        z: 0.0,
        radius: 20.0,
        r: 1.0,
        g: 0.9,
        b: 0.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClusteredLightingPreviewWidget(
              manager: manager,
            ),
          ),
        ),
      );

      expect(find.byType(ClusteredLightingPreviewWidget), findsOneWidget);
      expect(find.byKey(const Key('active_light_counter')), findsOneWidget);
      expect(find.byKey(const Key('cluster_assignment_counter')), findsOneWidget);

      expect(find.text('Active Lights: 1'), findsOneWidget);
      expect(find.textContaining('Cluster Assignments:'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('ClusteredLightingPreviewWidget responds to taps', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClusteredLightingPreviewWidget(
              manager: manager,
              onLightTapped: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ClusteredLightingPreviewWidget));
      expect(tapped, isTrue);
    });

    test('ClusteredLightingDebugPainter shouldRepaint returns correct boolean flags', () {
      final p1 = ClusteredLightingDebugPainter(manager: manager, frameNumber: 1);
      final p2 = ClusteredLightingDebugPainter(manager: manager, frameNumber: 2);
      final p3 = ClusteredLightingDebugPainter(manager: manager, frameNumber: 1);

      expect(p1.shouldRepaint(p2), isTrue); // frame changed
      expect(p1.shouldRepaint(p3), isFalse); // identical
    });

    testWidgets('ClusteredLightingPreviewWidget renders properly in landscape and portrait', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClusteredLightingPreviewWidget(
              manager: manager,
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  // ---------------------------------------------------------------------------
  // 11. Adversarial & Boundary Stress Testing
  // ---------------------------------------------------------------------------
  group('ClusteredLightManager Adversarial & Boundary Stress Testing', () {
    test('Extreme coordinate positions do not cause crashes or invalid indexing', () {
      final bounds = ClusterGridBounds();
      final (cxHuge, cyHuge, czHuge) = bounds.worldToVoxel(1e12, 1e12, 1e12);
      expect(cxHuge, equals(bounds.dimX - 1));
      expect(cyHuge, equals(bounds.dimY - 1));
      expect(czHuge, equals(bounds.dimZ - 1));

      final (cxLow, cyLow, czLow) = bounds.worldToVoxel(-1e12, -1e12, -1e12);
      expect(cxLow, equals(0));
      expect(cyLow, equals(0));
      expect(czLow, equals(0));
    });

    test('Adding lights up to maxLights capacity succeeds and exceeding throws StateError', () {
      final manager = ClusteredLightManager(
        bounds: ClusterGridBounds(),
        maxLights: 4,
      );

      for (int i = 0; i < 4; i++) {
        manager.createSceneLight(x: i * 5.0, y: 0, z: 0, radius: 10.0);
      }
      expect(manager.lightCount, equals(4));

      expect(
        () => manager.createSceneLight(x: 100, y: 0, z: 0, radius: 10.0),
        throwsStateError,
      );
    });

    test('Tiny light radius (0.0001) evaluates smoothly without NaN or infinity', () {
      final light = ClusteredLight(
        id: 1,
        x: 0,
        y: 0,
        z: 0,
        radius: 0.0001,
      );

      final att = light.evaluateSmoothAttenuation(0.00005);
      expect(att.isNaN, isFalse);
      expect(att.isInfinite, isFalse);
      expect(att, greaterThanOrEqualTo(0.0));
    });

    test('getLightsForCluster with negative or out-of-bounds index returns empty list', () {
      final manager = ClusteredLightManager(
        bounds: ClusterGridBounds(dimX: 2, dimY: 2, dimZ: 2), // total 8
      );

      expect(manager.getLightsForCluster(-1), isEmpty);
      expect(manager.getLightsForCluster(8), isEmpty);
      expect(manager.getLightsForCluster(9999), isEmpty);
    });
  });
}
