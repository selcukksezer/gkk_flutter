import 'dart:math' as math;
import 'dart:ui' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/rendering/postprocess/aces_tonemap_curve.dart';
import 'package:gkk_flutter/rendering/postprocess/bilateral_filter.dart';
import 'package:gkk_flutter/rendering/postprocess/postprocess_pipeline.dart';
import 'package:gkk_flutter/rendering/postprocess/ssao_kernel.dart';

void main() {
  group('SSAO & Bilateral Blur Pipeline Tests', () {
    test('Vogel spiral sample distribution stays inside unit circle with center density', () {
      const int sampleCount = 24;
      final List<Offset> samples = SsaoKernel.generateVogelSpiralKernel(sampleCount);

      expect(samples.length, equals(sampleCount));

      double prevR = -1.0;
      for (int i = 0; i < sampleCount; ++i) {
        final Offset tap = samples[i];
        final double distSq = tap.dx * tap.dx + tap.dy * tap.dy;
        final double r = math.sqrt(distSq);

        // Every sample must lie within the unit disk
        expect(r, lessThanOrEqualTo(1.0));

        // Radii must strictly increase according to sqrt((i + 0.5) / N)
        expect(r, greaterThan(prevR));
        prevR = r;
      }

      // First sample should be close to center, last sample close to outer rim
      expect(samples.first.dx.abs(), lessThan(0.3));
      expect(samples.first.dy.abs(), lessThan(0.3));
      final double outerR = math.sqrt(
        samples.last.dx * samples.last.dx + samples.last.dy * samples.last.dy,
      );
      expect(outerR, greaterThan(0.95));
    });

    test('linearizeDepth correctly converts non-linear buffer depth to view distance', () {
      const double near = 0.1;
      const double far = 100.0;

      // Depth = 0.0 -> near plane
      expect(SsaoKernel.linearizeDepth(0.0, near, far), closeTo(near, 0.001));

      // Depth = 1.0 -> far plane
      expect(SsaoKernel.linearizeDepth(1.0, near, far), closeTo(far, 0.001));

      // Monotonically increasing view distance
      double prevZ = 0.0;
      for (double d = 0.0; d <= 1.0; d += 0.1) {
        final double z = SsaoKernel.linearizeDepth(d, near, far);
        expect(z, greaterThanOrEqualTo(prevZ));
        prevZ = z;
      }
    });

    test('3D Vector operations behave correctly', () {
      const Vector3D v1 = Vector3D(1.0, 0.0, 0.0);
      const Vector3D v2 = Vector3D(0.0, 1.0, 0.0);

      // Dot product of orthogonal vectors is 0
      expect(v1.dot(v2), closeTo(0.0, 0.0001));

      // Cross product of X and Y is Z
      final Vector3D cross = v1.cross(v2);
      expect(cross.x, closeTo(0.0, 0.0001));
      expect(cross.y, closeTo(0.0, 0.0001));
      expect(cross.z, closeTo(1.0, 0.0001));

      // Normalization
      const Vector3D vLong = Vector3D(3.0, 4.0, 0.0);
      expect(vLong.length, closeTo(5.0, 0.0001));
      final Vector3D norm = vLong.normalized();
      expect(norm.length, closeTo(1.0, 0.0001));
      expect(norm.x, closeTo(0.6, 0.0001));
      expect(norm.y, closeTo(0.8, 0.0001));
    });

    test('Horizon occlusion calculates occlusion for occluders and rejects false positives', () {
      const Vector3D centerPos = Vector3D(0.0, 0.0, 5.0);
      const Vector3D normal = Vector3D(0.0, 0.0, -1.0); // Surface facing toward camera (-Z)

      // 1. Occluder point placed in front of surface (closer to camera than the surface plane)
      const Vector3D occluderInFront = Vector3D(0.1, 0.1, 4.8);
      final double occ1 = SsaoKernel.evaluateHorizonOcclusion(
        centerPos: centerPos,
        centerNormal: normal,
        samplePos: occluderInFront,
        radius: 0.5,
        bias: 0.025,
      );
      expect(occ1, greaterThan(0.0));

      // 2. Sample point lying on or behind the surface plane is rejected by bias
      const Vector3D behindPlane = Vector3D(0.1, 0.1, 5.2);
      final double occ2 = SsaoKernel.evaluateHorizonOcclusion(
        centerPos: centerPos,
        centerNormal: normal,
        samplePos: behindPlane,
        radius: 0.5,
        bias: 0.025,
      );
      expect(occ2, equals(0.0));

      // 3. Occluder outside radius is attenuated to zero
      const Vector3D outsideRadius = Vector3D(0.0, 0.0, 4.0); // dist = 1.0 > radius 0.5
      final double occ3 = SsaoKernel.evaluateHorizonOcclusion(
        centerPos: centerPos,
        centerNormal: normal,
        samplePos: outsideRadius,
        radius: 0.5,
        bias: 0.025,
      );
      expect(occ3, equals(0.0));
    });

    test('SSAO correctly produces higher occlusion on concave corner than flat plane', () {
      const SsaoParams params = SsaoParams(
        radius: 0.5,
        bias: 0.02,
        intensity: 1.5,
        power: 1.0,
        sampleCount: 16,
      );

      // Flat surface depth map: depth is constant across the entire region
      final double flatAo = SsaoKernel.computePixelAo(
        u: 0.5,
        v: 0.5,
        pixelX: 100.0,
        pixelY: 100.0,
        centerDepthRaw: 0.05,
        depthSampler: (double su, double sv) => 0.05,
        aspectRatio: 1.0,
        params: params,
      );

      // Concave corner depth map: neighbor on one side has geometry protruding forward (smaller depth)
      final double cornerAo = SsaoKernel.computePixelAo(
        u: 0.5,
        v: 0.5,
        pixelX: 100.0,
        pixelY: 100.0,
        centerDepthRaw: 0.05,
        depthSampler: (double su, double sv) => (su > 0.5) ? 0.03 : 0.05,
        aspectRatio: 1.0,
        params: params,
      );

      // Flat surface has high visibility (AO close to 1.0)
      expect(flatAo, greaterThan(0.9));

      // Concave corner has darker ambient occlusion (lower AO value)
      expect(cornerAo, lessThan(flatAo));
    });

    test('Bilateral depth-aware filter preserves sharp depth edges while smoothing noise', () {
      const BilateralFilterParams params = BilateralFilterParams(
        spatialSigma: 2.0,
        depthThreshold: 0.05,
        kernelRadius: 3,
      );

      // 1. Spatial Gaussian weights decrease smoothly
      final double w0 = BilateralFilter.computeSpatialWeight(0.0, 2.0);
      final double w1 = BilateralFilter.computeSpatialWeight(1.0, 2.0);
      final double w2 = BilateralFilter.computeSpatialWeight(2.0, 2.0);
      expect(w0, closeTo(1.0, 0.0001));
      expect(w1, lessThan(w0));
      expect(w2, lessThan(w1));

      // 2. Depth discontinuity weights drop rapidly
      final double wDepthSmall = BilateralFilter.computeDepthWeight(0.01, 0.05);
      final double wDepthEdge = BilateralFilter.computeDepthWeight(0.20, 0.05);
      expect(wDepthSmall, greaterThan(0.9));
      expect(wDepthEdge, lessThan(0.001)); // Discontinuity rejected!

      // 3. Edge Preservation Scenario:
      // Left side is foreground character at depth = 1.0 with dark occlusion (AO = 0.2)
      // Right side is background wall at depth = 5.0 with light occlusion (AO = 1.0)
      // We filter a pixel on the foreground right at the boundary (tapCoord = 0)
      final double filteredForegroundEdge = BilateralFilter.filter1D(
        centerCoord: 0,
        centerAo: 0.2,
        centerDepth: 1.0,
        aoSampler: (int coord) => (coord < 1) ? 0.2 : 1.0,
        depthSampler: (int coord) => (coord < 1) ? 1.0 : 5.0,
        params: params,
      );

      // The filtered foreground pixel must stay dark near 0.2, NOT bleed the 1.0 background wall!
      expect(filteredForegroundEdge, closeTo(0.2, 0.01));

      // 4. Smooth continuous surface with high-frequency noise:
      // Center has noisy spike (0.2), neighbors are 0.6, all at same depth = 2.0
      final double filteredNoisySpike = BilateralFilter.filter1D(
        centerCoord: 0,
        centerAo: 0.2,
        centerDepth: 2.0,
        aoSampler: (int coord) => (coord == 0) ? 0.2 : 0.6,
        depthSampler: (int coord) => 2.0,
        params: params,
      );

      // Noise is smoothed out toward neighbor average
      expect(filteredNoisySpike, greaterThan(0.4));
    });

    test('Controller builds uniform arrays matching SSAO, Blur, and Composite shaders', () {
      const Size viewport = Size(1280.0, 720.0);

      // SSAO Uniforms
      const SsaoParams ssaoParams = SsaoParams(
        radius: 0.75,
        bias: 0.03,
        intensity: 2.0,
        power: 1.8,
        sampleCount: 20,
        near: 0.2,
        far: 150.0,
      );
      final List<double> ssaoUniforms = PostProcessPipelineController.buildSsaoUniforms(
        size: viewport,
        params: ssaoParams,
      );
      expect(ssaoUniforms.length, equals(9));
      expect(ssaoUniforms[0], equals(1280.0));
      expect(ssaoUniforms[1], equals(720.0));
      expect(ssaoUniforms[2], equals(0.75));
      expect(ssaoUniforms[3], equals(0.03));
      expect(ssaoUniforms[4], equals(2.0));
      expect(ssaoUniforms[5], equals(1.8));
      expect(ssaoUniforms[6], equals(20.0));
      expect(ssaoUniforms[7], equals(0.2));
      expect(ssaoUniforms[8], equals(150.0));

      // Bilateral Blur Uniforms
      const BilateralFilterParams blurParams = BilateralFilterParams(
        spatialSigma: 3.0,
        depthThreshold: 0.12,
      );
      final List<double> blurUniforms = PostProcessPipelineController.buildBilateralUniforms(
        size: viewport,
        direction: const Offset(1.0, 0.0),
        params: blurParams,
      );
      expect(blurUniforms.length, equals(6));
      expect(blurUniforms[0], equals(1280.0));
      expect(blurUniforms[1], equals(720.0));
      expect(blurUniforms[2], equals(1.0)); // dx
      expect(blurUniforms[3], equals(0.0)); // dy
      expect(blurUniforms[4], equals(3.0)); // spatialSigma
      expect(blurUniforms[5], equals(0.12)); // depthThreshold

      // Composite Uniforms
      const AcesTonemapParams acesParams = AcesTonemapParams(
        exposure: 0.8,
        exposureMode: ExposureMode.evStops,
        fitType: AcesFitType.stephenHill,
      );
      final List<double> compUniforms = PostProcessPipelineController.buildCompositeUniforms(
        size: viewport,
        acesParams: acesParams,
        aoIntensity: 1.25,
        aoDirectLightPreserve: 0.3,
      );
      expect(compUniforms.length, equals(8));
      expect(compUniforms[0], equals(1280.0));
      expect(compUniforms[1], equals(720.0));
      expect(compUniforms[2], equals(0.8));
      expect(compUniforms[3], equals(1.0)); // evStops
      expect(compUniforms[4], equals(0.0)); // stephenHill
      expect(compUniforms[5], equals(0.0)); // accurateSrgb
      expect(compUniforms[6], equals(1.25)); // aoIntensity
      expect(compUniforms[7], equals(0.3)); // aoDirectLightPreserve
    });
  });
}
