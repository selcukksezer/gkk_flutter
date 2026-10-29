import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

/// Configuration parameters for Scalable Screen Space Ambient Occlusion (SSAO).
class SsaoParams {
  const SsaoParams({
    this.radius = 0.5,
    this.bias = 0.025,
    this.intensity = 1.5,
    this.power = 2.0,
    this.sampleCount = 16,
    this.near = 0.1,
    this.far = 100.0,
  });

  /// View-space sampling radius around surface point.
  final double radius;

  /// Horizon angle bias to reject false occlusions and acne on flat surfaces.
  final double bias;

  /// Occlusion factor multiplier (higher = darker contact shadows).
  final double intensity;

  /// Contrast power exponent applied to final AO: AO^power.
  final double power;

  /// Number of hemisphere / Vogel spiral sample taps (typically 8, 16, 24, 32).
  final int sampleCount;

  /// Camera near clipping plane distance.
  final double near;

  /// Camera far clipping plane distance.
  final double far;

  SsaoParams copyWith({
    double? radius,
    double? bias,
    double? intensity,
    double? power,
    int? sampleCount,
    double? near,
    double? far,
  }) {
    return SsaoParams(
      radius: radius ?? this.radius,
      bias: bias ?? this.bias,
      intensity: intensity ?? this.intensity,
      power: power ?? this.power,
      sampleCount: sampleCount ?? this.sampleCount,
      near: near ?? this.near,
      far: far ?? this.far,
    );
  }

  /// Formats uniform floats in exact GLSL declaration order matching `ssao.frag`.
  /// Order: uResolution.x, uResolution.y, uRadius, uBias, uIntensity, uPower,
  /// uSampleCount, uNear, uFar (total 9 floats).
  List<double> toUniformList(double width, double height) {
    return <double>[
      width,
      height,
      radius,
      bias,
      intensity,
      power,
      sampleCount.toDouble(),
      near,
      far,
    ];
  }

  /// Formats uniform floats for a given [Size].
  List<double> toUniformListWithSize(Size size) =>
      toUniformList(size.width, size.height);

  /// Exports uniforms into a [Float32List] buffer matching `ssao.frag` layout.
  Float32List toFloat32List(double width, double height) {
    final Float32List buffer = Float32List(SsaoKernel.kUniformFloatCount);
    writeToFloatBuffer(buffer, width, height, 0);
    return buffer;
  }

  /// Writes uniform floats into [buffer] starting at [offset].
  void writeToFloatBuffer(
    Float32List buffer,
    double width,
    double height, [
    int offset = 0,
  ]) {
    buffer[offset + SsaoKernel.kUniformResolutionX] = width;
    buffer[offset + SsaoKernel.kUniformResolutionY] = height;
    buffer[offset + SsaoKernel.kUniformRadius] = radius;
    buffer[offset + SsaoKernel.kUniformBias] = bias;
    buffer[offset + SsaoKernel.kUniformIntensity] = intensity;
    buffer[offset + SsaoKernel.kUniformPower] = power;
    buffer[offset + SsaoKernel.kUniformSampleCount] = sampleCount.toDouble();
    buffer[offset + SsaoKernel.kUniformNear] = near;
    buffer[offset + SsaoKernel.kUniformFar] = far;
  }
}

/// 3D Vector for view-space position and normal calculations.
class Vector3D {
  const Vector3D(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get length => math.sqrt(x * x + y * y + z * z);

  Vector3D normalized() {
    final double l = length;
    if (l < 0.000001) return const Vector3D(0.0, 0.0, 1.0);
    return Vector3D(x / l, y / l, z / l);
  }

  double dot(Vector3D other) => x * other.x + y * other.y + z * other.z;

  Vector3D cross(Vector3D other) {
    return Vector3D(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator *(double s) => Vector3D(x * s, y * s, z * s);
  Vector3D operator -() => Vector3D(-x, -y, -z);
}

/// Vogel spiral distribution generator and SSAO mathematical helpers.
class SsaoKernel {
  const SsaoKernel._();

  // ---------------------------------------------------------------------------
  // Shader Uniform Buffer Layout & Offsets (matching ssao.frag)
  // Total 9 Floats (Indices 0..8) + 2 Samplers (Units 0..1).
  // Strictly declared before samplers for Impeller runtime effect compliance.
  // ---------------------------------------------------------------------------

  /// Float 0: Viewport width in physical pixels.
  static const int kUniformResolutionX = 0;

  /// Float 1: Viewport height in physical pixels.
  static const int kUniformResolutionY = 1;

  /// Float 2: View-space sampling radius around surface point.
  static const int kUniformRadius = 2;

  /// Float 3: Horizon angle bias to reject self-occlusion / acne.
  static const int kUniformBias = 3;

  /// Float 4: Occlusion factor multiplier.
  static const int kUniformIntensity = 4;

  /// Float 5: Occlusion contrast power exponent.
  static const int kUniformPower = 5;

  /// Float 6: Active sample count (max 32).
  static const int kUniformSampleCount = 6;

  /// Float 7: Camera near clipping plane distance.
  static const int kUniformNear = 7;

  /// Float 8: Camera far clipping plane distance.
  static const int kUniformFar = 8;

  /// Total count of numeric uniform floats for `ssao.frag` (9 floats).
  static const int kUniformFloatCount = 9;

  /// Sampler Unit 0: Normalized depth buffer texture.
  static const int kSamplerDepthIndex = 0;

  /// Sampler Unit 1: View-space or tangent normal map texture.
  static const int kSamplerNormalIndex = 1;

  /// Total count of texture samplers for `ssao.frag` (2 samplers).
  static const int kSamplerCount = 2;

  /// Default noise tile dimension (4x4 tile = 16 rotation vectors).
  static const int kDefaultNoiseTileSize = 4;

  /// Golden angle in radians: pi * (3 - sqrt(5)).
  static const double goldenAngle = 2.399963229728653;

  /// Packs uniform floats for `ssao.frag` in exact GLSL declaration order.
  static List<double> buildUniformList(
    double width,
    double height,
    SsaoParams params,
  ) {
    return params.toUniformList(width, height);
  }

  /// Builds a [Float32List] buffer with 9 floats matching `ssao.frag`.
  static Float32List buildUniformBuffer(
    double width,
    double height,
    SsaoParams params,
  ) {
    return params.toFloat32List(width, height);
  }

  /// Generates a 2D Vogel spiral sample distribution on a unit disk.
  /// Each sample has radius sqrt((i + 0.5) / N) and angle i * goldenAngle.
  /// Ordered monotonically by ascending radius.
  static List<Offset> generateVogelSpiralKernel(int sampleCount) {
    final int count = math.max(1, sampleCount);
    final List<Offset> samples = <Offset>[];

    for (int i = 0; i < count; ++i) {
      final double r = math.sqrt((i + 0.5) / count.toDouble());
      final double theta = i * goldenAngle;
      final double x = r * math.cos(theta);
      final double y = r * math.sin(theta);
      samples.add(Offset(x, y));
    }

    return samples;
  }

  /// Packs 2D Vogel spiral sample taps into a [Float32List] buffer.
  /// If [padVec4] is true, pads each sample to vec4 (x, y, 0.0, 0.0)
  /// matching GPU uniform block 16-byte alignment (std140).
  static Float32List packVogelSpiralKernel(
    int sampleCount, {
    bool padVec4 = false,
  }) {
    final List<Offset> samples = generateVogelSpiralKernel(sampleCount);
    final int stride = padVec4 ? 4 : 2;
    final Float32List buffer = Float32List(samples.length * stride);

    int idx = 0;
    for (final Offset tap in samples) {
      buffer[idx++] = tap.dx;
      buffer[idx++] = tap.dy;
      if (padVec4) {
        buffer[idx++] = 0.0;
        buffer[idx++] = 0.0;
      }
    }
    return buffer;
  }

  /// Generates a 3D tangent-space hemisphere sample distribution.
  ///
  /// Vectors lie strictly in the upper hemisphere (+Z >= [minZ]) and are
  /// scaled by an accelerated quadratic falloff:
  ///   falloff = 0.1 + 0.9 * (scale * scale)
  /// where scale = (i + 1) / N.
  ///
  /// Vectors are ordered monotonically by ascending distance from origin,
  /// clustering samples close to the surface contact point to capture fine
  /// contact occlusions while maintaining wide hemisphere coverage.
  static List<Vector3D> generateHemisphereKernel(
    int sampleCount, {
    double minZ = 0.1,
  }) {
    final int count = math.max(1, sampleCount);
    final List<Vector3D> kernel = <Vector3D>[];

    for (int i = 0; i < count; ++i) {
      final double r = math.sqrt((i + 0.5) / count.toDouble());
      final double theta = i * goldenAngle;
      final double x = r * math.cos(theta);
      final double y = r * math.sin(theta);
      final double zRaw = math.sqrt(math.max(0.0, 1.0 - r * r));
      final double z = zRaw < minZ ? minZ : zRaw;

      final Vector3D unitVec = Vector3D(x, y, z).normalized();

      // Quadratic falloff clustering samples near surface origin
      final double scale = (i + 1.0) / count.toDouble();
      final double falloff = 0.1 + 0.9 * (scale * scale);

      kernel.add(unitVec * falloff);
    }

    return kernel;
  }

  /// Packs 3D hemisphere sample vectors into a [Float32List] buffer.
  /// If [padVec4] is true, pads each vector to vec4 (x, y, z, 0.0)
  /// matching GPU uniform block 16-byte alignment (std140).
  static Float32List packHemisphereKernel(
    int sampleCount, {
    bool padVec4 = false,
    double minZ = 0.1,
  }) {
    final List<Vector3D> kernel =
        generateHemisphereKernel(sampleCount, minZ: minZ);
    final int stride = padVec4 ? 4 : 3;
    final Float32List buffer = Float32List(kernel.length * stride);

    int idx = 0;
    for (final Vector3D vec in kernel) {
      buffer[idx++] = vec.x;
      buffer[idx++] = vec.y;
      buffer[idx++] = vec.z;
      if (padVec4) {
        buffer[idx++] = 0.0;
      }
    }
    return buffer;
  }

  /// Generates 2D rotation vectors for a spatial dither noise tile.
  ///
  /// Vectors lie on the unit circle in the XY plane: (cos(phi), sin(phi), 0.0).
  /// Generates [width] x [height] samples (default 4x4 = 16 rotation samples).
  static List<Vector3D> generateNoiseVectors({
    int width = kDefaultNoiseTileSize,
    int height = kDefaultNoiseTileSize,
  }) {
    final List<Vector3D> noise = <Vector3D>[];
    for (int y = 0; y < height; ++y) {
      for (int x = 0; x < width; ++x) {
        final double angle = hash12(x.toDouble(), y.toDouble()) * 2.0 * math.pi;
        noise.add(Vector3D(math.cos(angle), math.sin(angle), 0.0));
      }
    }
    return noise;
  }

  /// Packs noise tile rotation vectors into a [Float32List] buffer.
  /// If [padVec4] is true, outputs (cos, sin, 0.0, 1.0) per texel.
  static Float32List generateNoiseTileFloatBuffer({
    int width = kDefaultNoiseTileSize,
    int height = kDefaultNoiseTileSize,
    bool padVec4 = false,
  }) {
    final List<Vector3D> noise =
        generateNoiseVectors(width: width, height: height);
    final int stride = padVec4 ? 4 : 2;
    final Float32List buffer = Float32List(noise.length * stride);

    int idx = 0;
    for (final Vector3D v in noise) {
      buffer[idx++] = v.x;
      buffer[idx++] = v.y;
      if (padVec4) {
        buffer[idx++] = 0.0;
        buffer[idx++] = 1.0;
      }
    }
    return buffer;
  }

  /// Generates an 8-bit RGBA byte buffer for uploading a 4x4 noise texture to GPU.
  /// R = (cos * 0.5 + 0.5) * 255
  /// G = (sin * 0.5 + 0.5) * 255
  /// B = 128 (z = 0.0 encoded in [0..1] range)
  /// A = 255 (alpha = 1.0)
  static Uint8List generateNoiseTileRgbaBytes({
    int width = kDefaultNoiseTileSize,
    int height = kDefaultNoiseTileSize,
  }) {
    final List<Vector3D> noise =
        generateNoiseVectors(width: width, height: height);
    final Uint8List bytes = Uint8List(noise.length * 4);

    int idx = 0;
    for (final Vector3D v in noise) {
      bytes[idx++] = ((v.x * 0.5 + 0.5) * 255.0).round().clamp(0, 255);
      bytes[idx++] = ((v.y * 0.5 + 0.5) * 255.0).round().clamp(0, 255);
      bytes[idx++] = 128;
      bytes[idx++] = 255;
    }
    return bytes;
  }

  /// Pseudo-random 2D hash identical to the GLSL shader hash12 function.
  static double hash12(double x, double y) {
    // fract(vec3(p.xyx) * 0.1031)
    double p3x = (x * 0.1031) % 1.0;
    if (p3x < 0) p3x += 1.0;
    double p3y = (y * 0.1031) % 1.0;
    if (p3y < 0) p3y += 1.0;
    double p3z = (x * 0.1031) % 1.0;
    if (p3z < 0) p3z += 1.0;

    // p3 += dot(p3, p3.yzx + 33.33)
    final double dotVal =
        p3x * (p3y + 33.33) + p3y * (p3z + 33.33) + p3z * (p3x + 33.33);
    p3x += dotVal;
    p3y += dotVal;
    p3z += dotVal;

    final double result = ((p3x + p3y) * p3z) % 1.0;
    return (result < 0) ? (result + 1.0) : result;
  }

  /// Converts non-linear normalized depth buffer value [0, 1] to linear view depth.
  static double linearizeDepth(double depth, double near, double far) {
    if (depth >= 1.0) return far;
    if (depth <= 0.0) return near;
    return (near * far) / (far - depth * (far - near) + 0.000001);
  }

  /// Reconstructs view-space position from UV and linear view depth.
  static Vector3D reconstructViewPos(
    double u,
    double v,
    double linearZ,
    double aspectRatio,
  ) {
    final double ndcX = u * 2.0 - 1.0;
    final double ndcY = v * 2.0 - 1.0;
    return Vector3D(ndcX * aspectRatio * linearZ, ndcY * linearZ, linearZ);
  }

  /// Evaluates horizon-based ambient occlusion between surface position and sample tap.
  static double evaluateHorizonOcclusion({
    required Vector3D centerPos,
    required Vector3D centerNormal,
    required Vector3D samplePos,
    required double radius,
    required double bias,
  }) {
    final Vector3D diff = samplePos - centerPos;
    final double dist = diff.length;

    if (dist < 0.0001) return 0.0;

    // Cosine of angle between normal and difference vector
    final double nDotV = centerNormal.dot(diff) / dist;

    // Horizon factor: sample is occluded if it lies in the surface normal hemisphere
    final double horizonFactor = math.max(0.0, nDotV - bias);

    // Range attenuation: smoothstep falloff when sample is further than radius
    final double x = (radius - dist) / radius;
    final double clampedX = x.clamp(0.0, 1.0);
    final double rangeCheck = clampedX * clampedX * (3.0 - 2.0 * clampedX);

    return horizonFactor * rangeCheck;
  }

  /// Calculates complete Screen-Space Ambient Occlusion factor for a pixel on CPU.
  static double computePixelAo({
    required double u,
    required double v,
    required double pixelX,
    required double pixelY,
    required double centerDepthRaw,
    required double Function(double sampleU, double sampleV) depthSampler,
    required double aspectRatio,
    SsaoParams params = const SsaoParams(),
  }) {
    final double centerZ = linearizeDepth(centerDepthRaw, params.near, params.far);
    if (centerDepthRaw >= 0.9999 || centerZ >= params.far * 0.99) {
      return 1.0; // Skybox / far background has no occlusion
    }

    final Vector3D centerPos = reconstructViewPos(u, v, centerZ, aspectRatio);

    // Reconstruct surface normal from depth cross derivatives
    const double eps = 0.002;
    final double zLeft = linearizeDepth(depthSampler(u - eps, v), params.near, params.far);
    final double zRight = linearizeDepth(depthSampler(u + eps, v), params.near, params.far);
    final double zDown = linearizeDepth(depthSampler(u, v - eps), params.near, params.far);
    final double zUp = linearizeDepth(depthSampler(u, v + eps), params.near, params.far);

    final Vector3D pLeft = reconstructViewPos(u - eps, v, zLeft, aspectRatio);
    final Vector3D pRight = reconstructViewPos(u + eps, v, zRight, aspectRatio);
    final Vector3D pDown = reconstructViewPos(u, v - eps, zDown, aspectRatio);
    final Vector3D pUp = reconstructViewPos(u, v + eps, zUp, aspectRatio);

    // Adaptive discontinuity-aware difference matching ssao.frag: pick closer neighbor to avoid silhouette halo bleeding
    final Vector3D dx = ((zRight - centerZ).abs() < (zLeft - centerZ).abs())
        ? (pRight - centerPos)
        : (centerPos - pLeft);
    final Vector3D dy = ((zUp - centerZ).abs() < (zDown - centerZ).abs())
        ? (pUp - centerPos)
        : (centerPos - pDown);

    final Vector3D crossD = dx.cross(dy);
    Vector3D normal = (crossD.length > 0.000001)
        ? crossD.normalized()
        : const Vector3D(0.0, 0.0, -1.0);
    if (normal.z > 0.0) normal = -normal;

    // Per-pixel random rotation angle from hash
    final double randomAngle = hash12(pixelX, pixelY) * 2.0 * math.pi;
    final double cosRot = math.cos(randomAngle);
    final double sinRot = math.sin(randomAngle);

    final List<Offset> spiralSamples = generateVogelSpiralKernel(params.sampleCount);

    final double screenRadius =
        (params.radius / math.max(centerZ, 0.1)) * 0.1;
    final double clampedRadius = screenRadius.clamp(0.002, 0.2);

    double occlusionSum = 0.0;
    double weightSum = 0.0;

    for (final Offset tap in spiralSamples) {
      // Rotate tap
      final double rotX = tap.dx * cosRot - tap.dy * sinRot;
      final double rotY = tap.dx * sinRot + tap.dy * cosRot;

      final double sampleU = (u + rotX * clampedRadius).clamp(0.001, 0.999);
      final double sampleV = (v + rotY * clampedRadius * aspectRatio).clamp(0.001, 0.999);

      final double sampleRawDepth = depthSampler(sampleU, sampleV);
      final double sampleZ = linearizeDepth(sampleRawDepth, params.near, params.far);
      final Vector3D samplePos = reconstructViewPos(sampleU, sampleV, sampleZ, aspectRatio);

      final double occ = evaluateHorizonOcclusion(
        centerPos: centerPos,
        centerNormal: normal,
        samplePos: samplePos,
        radius: params.radius,
        bias: params.bias,
      );

      occlusionSum += occ;
      weightSum += 1.0;
    }

    if (weightSum <= 0.0) return 1.0;

    final double avgOcclusion = (occlusionSum / weightSum) * params.intensity;
    final double ao = (1.0 - avgOcclusion).clamp(0.0, 1.0);
    return math.pow(ao, params.power).toDouble();
  }
}
