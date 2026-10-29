import 'dart:math' as math;
import 'dart:typed_data';

/// The result of testing a bounding volume against the view frustum.
enum ContainmentResult {
  /// The volume is completely outside the frustum and can be culled.
  outside,

  /// The volume is completely inside all planes of the frustum.
  inside,

  /// The volume intersects one or more frustum clipping planes.
  intersects,
}

/// A normalized 3D plane equation: `A * x + B * y + C * z + D = 0`.
///
/// By convention, normals `(normalX, normalY, normalZ)` point INWARD toward
/// the interior of the frustum. Points with signed distance `> 0` are inside
/// the half-space.
class FrustumPlane {
  const FrustumPlane({
    required this.normalX,
    required this.normalY,
    required this.normalZ,
    required this.distance,
  });

  /// Creates a normalized plane from raw coefficients [a], [b], [c], [d].
  ///
  /// If [normalize] is true, normalizes so that `sqrt(a^2 + b^2 + c^2) == 1.0`.
  factory FrustumPlane.fromCoefficients(
    double a,
    double b,
    double c,
    double d, {
    bool normalize = true,
  }) {
    if (!normalize) {
      return FrustumPlane(
        normalX: a,
        normalY: b,
        normalZ: c,
        distance: d,
      );
    }

    final lengthSq = a * a + b * b + c * c;
    if (lengthSq > 1e-12) {
      final invLen = 1.0 / math.sqrt(lengthSq);
      return FrustumPlane(
        normalX: a * invLen,
        normalY: b * invLen,
        normalZ: c * invLen,
        distance: d * invLen,
      );
    }

    return FrustumPlane(
      normalX: a,
      normalY: b,
      normalZ: c,
      distance: d,
    );
  }

  /// Plane normal X component.
  final double normalX;

  /// Plane normal Y component.
  final double normalY;

  /// Plane normal Z component.
  final double normalZ;

  /// Plane distance constant D.
  final double distance;

  /// Computes the signed distance from this plane to point `(x, y, z)`.
  ///
  /// Returns `> 0` if in front of plane (inside frustum), `< 0` if behind (outside).
  @pragma('vm:prefer-inline')
  double distanceToPoint(double x, double y, double z) {
    return normalX * x + normalY * y + normalZ * z + distance;
  }

  @override
  String toString() =>
      'FrustumPlane(nx: ${normalX.toStringAsFixed(4)}, ny: ${normalY.toStringAsFixed(4)}, '
      'nz: ${normalZ.toStringAsFixed(4)}, d: ${distance.toStringAsFixed(4)})';
}

/// High-performance 6-plane View Frustum representation for visibility culling.
///
/// Planes are stored in normalized form with normals pointing inward.
/// Flat [planeBuffer] (24 floats: 6 planes * 4 coefficients) allows cache-friendly,
/// SIMD-compatible batch loops with zero allocations.
class Frustum {
  /// Index constants for the 6 planes in [planeBuffer].
  static const int planeLeft = 0;
  static const int planeRight = 1;
  static const int planeBottom = 2;
  static const int planeTop = 3;
  static const int planeNear = 4;
  static const int planeFar = 5;

  /// Internal flat buffer of 24 floats: `[nx, ny, nz, d]` for each of 6 planes.
  final Float32List planeBuffer;

  /// Creates a [Frustum] with an optional preallocated [planeBuffer].
  Frustum([Float32List? buffer]) : planeBuffer = buffer ?? Float32List(24);

  /// Creates a [Frustum] from 6 explicit planes.
  factory Frustum.fromPlanes({
    required FrustumPlane left,
    required FrustumPlane right,
    required FrustumPlane bottom,
    required FrustumPlane top,
    required FrustumPlane near,
    required FrustumPlane far,
  }) {
    final frustum = Frustum();
    frustum._setPlane(planeLeft, left.normalX, left.normalY, left.normalZ, left.distance);
    frustum._setPlane(planeRight, right.normalX, right.normalY, right.normalZ, right.distance);
    frustum._setPlane(planeBottom, bottom.normalX, bottom.normalY, bottom.normalZ, bottom.distance);
    frustum._setPlane(planeTop, top.normalX, top.normalY, top.normalZ, top.distance);
    frustum._setPlane(planeNear, near.normalX, near.normalY, near.normalZ, near.distance);
    frustum._setPlane(planeFar, far.normalX, far.normalY, far.normalZ, far.distance);
    return frustum;
  }

  /// Extracts the 6 frustum planes from a 4x4 View-Projection matrix using the
  /// Gribb-Hartmann algorithm.
  ///
  /// Matrix elements are assumed to be in column-major order by default (standard
  /// OpenGL / Vulkan / Flutter Matrix4 layout). Set [isRowMajor] to true if passing
  /// row-major matrices.
  ///
  /// Set [zeroToOneClipSpace] to true for Vulkan / Metal / Direct3D clip space
  /// where near plane maps to z=0 instead of OpenGL's z=-1.
  factory Frustum.fromViewProjection(
    List<double> matrix, {
    bool isRowMajor = false,
    bool zeroToOneClipSpace = false,
  }) {
    final frustum = Frustum();
    frustum.extractFromMatrix(
      matrix,
      isRowMajor: isRowMajor,
      zeroToOneClipSpace: zeroToOneClipSpace,
    );
    return frustum;
  }

  /// Returns the [FrustumPlane] at the specified [planeIndex] (0..5).
  FrustumPlane getPlane(int planeIndex) {
    final offset = planeIndex * 4;
    return FrustumPlane(
      normalX: planeBuffer[offset],
      normalY: planeBuffer[offset + 1],
      normalZ: planeBuffer[offset + 2],
      distance: planeBuffer[offset + 3],
    );
  }

  FrustumPlane get leftPlane => getPlane(planeLeft);
  FrustumPlane get rightPlane => getPlane(planeRight);
  FrustumPlane get bottomPlane => getPlane(planeBottom);
  FrustumPlane get topPlane => getPlane(planeTop);
  FrustumPlane get nearPlane => getPlane(planeNear);
  FrustumPlane get farPlane => getPlane(planeFar);

  @pragma('vm:prefer-inline')
  void _setPlane(int planeIndex, double nx, double ny, double nz, double d) {
    final offset = planeIndex * 4;
    final lengthSq = nx * nx + ny * ny + nz * nz;
    if (lengthSq > 1e-12) {
      final invLen = 1.0 / math.sqrt(lengthSq);
      planeBuffer[offset] = nx * invLen;
      planeBuffer[offset + 1] = ny * invLen;
      planeBuffer[offset + 2] = nz * invLen;
      planeBuffer[offset + 3] = d * invLen;
    } else {
      planeBuffer[offset] = nx;
      planeBuffer[offset + 1] = ny;
      planeBuffer[offset + 2] = nz;
      planeBuffer[offset + 3] = d;
    }
  }

  /// Extracts the 6 planes in-place into [planeBuffer] with ZERO heap allocations.
  ///
  /// Reusable every frame when the camera moves.
  void extractFromMatrix(
    List<double> matrix, {
    bool isRowMajor = false,
    bool zeroToOneClipSpace = false,
  }) {
    assert(matrix.length >= 16, 'Matrix must have at least 16 elements');

    double m0, m1, m2, m3;
    double m4, m5, m6, m7;
    double m8, m9, m10, m11;
    double m12, m13, m14, m15;

    if (isRowMajor) {
      // Row-major: row i is m[i*4 + j]
      m0 = matrix[0];
      m1 = matrix[1];
      m2 = matrix[2];
      m3 = matrix[3];
      m4 = matrix[4];
      m5 = matrix[5];
      m6 = matrix[6];
      m7 = matrix[7];
      m8 = matrix[8];
      m9 = matrix[9];
      m10 = matrix[10];
      m11 = matrix[11];
      m12 = matrix[12];
      m13 = matrix[13];
      m14 = matrix[14];
      m15 = matrix[15];
    } else {
      // Column-major: column j is matrix[j*4 + i]
      // Row 0: m0, m4, m8, m12
      // Row 1: m1, m5, m9, m13
      // Row 2: m2, m6, m10, m14
      // Row 3: m3, m7, m11, m15
      m0 = matrix[0];
      m1 = matrix[1];
      m2 = matrix[2];
      m3 = matrix[3];
      m4 = matrix[4];
      m5 = matrix[5];
      m6 = matrix[6];
      m7 = matrix[7];
      m8 = matrix[8];
      m9 = matrix[9];
      m10 = matrix[10];
      m11 = matrix[11];
      m12 = matrix[12];
      m13 = matrix[13];
      m14 = matrix[14];
      m15 = matrix[15];
    }

    // Row definitions for column-major matrix:
    // row 0: m0, m4, m8, m12
    // row 1: m1, m5, m9, m13
    // row 2: m2, m6, m10, m14
    // row 3: m3, m7, m11, m15
    final double r0x = isRowMajor ? m0 : m0;
    final double r0y = isRowMajor ? m1 : m4;
    final double r0z = isRowMajor ? m2 : m8;
    final double r0w = isRowMajor ? m3 : m12;

    final double r1x = isRowMajor ? m4 : m1;
    final double r1y = isRowMajor ? m5 : m5;
    final double r1z = isRowMajor ? m6 : m9;
    final double r1w = isRowMajor ? m7 : m13;

    final double r2x = isRowMajor ? m8 : m2;
    final double r2y = isRowMajor ? m9 : m6;
    final double r2z = isRowMajor ? m10 : m10;
    final double r2w = isRowMajor ? m11 : m14;

    final double r3x = isRowMajor ? m12 : m3;
    final double r3y = isRowMajor ? m13 : m7;
    final double r3z = isRowMajor ? m14 : m11;
    final double r3w = isRowMajor ? m15 : m15;

    // Left plane: row3 + row0
    _setPlane(
      planeLeft,
      r3x + r0x,
      r3y + r0y,
      r3z + r0z,
      r3w + r0w,
    );

    // Right plane: row3 - row0
    _setPlane(
      planeRight,
      r3x - r0x,
      r3y - r0y,
      r3z - r0z,
      r3w - r0w,
    );

    // Bottom plane: row3 + row1
    _setPlane(
      planeBottom,
      r3x + r1x,
      r3y + r1y,
      r3z + r1z,
      r3w + r1w,
    );

    // Top plane: row3 - row1
    _setPlane(
      planeTop,
      r3x - r1x,
      r3y - r1y,
      r3z - r1z,
      r3w - r1w,
    );

    // Near plane:
    // OpenGL [-1, 1]: row3 + row2
    // Vulkan/Metal/D3D [0, 1]: row2
    if (zeroToOneClipSpace) {
      _setPlane(
        planeNear,
        r2x,
        r2y,
        r2z,
        r2w,
      );
    } else {
      _setPlane(
        planeNear,
        r3x + r2x,
        r3y + r2y,
        r3z + r2z,
        r3w + r2w,
      );
    }

    // Far plane: row3 - row2
    _setPlane(
      planeFar,
      r3x - r2x,
      r3y - r2y,
      r3z - r2z,
      r3w - r2w,
    );
  }

  // =========================================================================
  // Individual Geometry Tests
  // =========================================================================

  /// Tests if a single point `(x, y, z)` lies within the frustum.
  @pragma('vm:prefer-inline')
  bool containsPoint(double x, double y, double z) {
    final b = planeBuffer;
    for (int i = 0; i < 24; i += 4) {
      if (b[i] * x + b[i + 1] * y + b[i + 2] * z + b[i + 3] < 0.0) {
        return false;
      }
    }
    return true;
  }

  /// High-speed boolean visibility check for a bounding sphere.
  ///
  /// Employs early rejection on the first plane that fails.
  /// Returns `true` if the sphere is inside or intersecting (i.e. visible).
  @pragma('vm:prefer-inline')
  bool isSphereVisible(double cx, double cy, double cz, double radius) {
    final b = planeBuffer;
    final negR = -radius;

    // Plane 0 (Left)
    if (b[0] * cx + b[1] * cy + b[2] * cz + b[3] < negR) return false;
    // Plane 1 (Right)
    if (b[4] * cx + b[5] * cy + b[6] * cz + b[7] < negR) return false;
    // Plane 2 (Bottom)
    if (b[8] * cx + b[9] * cy + b[10] * cz + b[11] < negR) return false;
    // Plane 3 (Top)
    if (b[12] * cx + b[13] * cy + b[14] * cz + b[15] < negR) return false;
    // Plane 4 (Near)
    if (b[16] * cx + b[17] * cy + b[18] * cz + b[19] < negR) return false;
    // Plane 5 (Far)
    if (b[20] * cx + b[21] * cy + b[22] * cz + b[23] < negR) return false;

    return true;
  }

  /// Full containment test for a bounding sphere.
  ///
  /// Distinguishes between completely inside, intersecting, or completely outside.
  ContainmentResult testSphere(double cx, double cy, double cz, double radius) {
    final b = planeBuffer;
    final negR = -radius;
    bool allInside = true;

    for (int i = 0; i < 24; i += 4) {
      final dist = b[i] * cx + b[i + 1] * cy + b[i + 2] * cz + b[i + 3];
      if (dist < negR) {
        return ContainmentResult.outside;
      }
      if (dist < radius) {
        allInside = false;
      }
    }

    return allInside ? ContainmentResult.inside : ContainmentResult.intersects;
  }

  /// High-speed boolean visibility check for an Axis-Aligned Bounding Box (AABB).
  ///
  /// Employs the positive vertex (p-vertex) early-rejection test.
  /// Returns `true` if the AABB is visible (inside or intersecting).
  @pragma('vm:prefer-inline')
  bool isAabbVisible(
    double minX,
    double minY,
    double minZ,
    double maxX,
    double maxY,
    double maxZ,
  ) {
    final b = planeBuffer;

    for (int i = 0; i < 24; i += 4) {
      final nx = b[i];
      final ny = b[i + 1];
      final nz = b[i + 2];
      final d = b[i + 3];

      // Positive vertex (furthest in direction of normal)
      final px = nx > 0.0 ? maxX : minX;
      final py = ny > 0.0 ? maxY : minY;
      final pz = nz > 0.0 ? maxZ : minZ;

      if (nx * px + ny * py + nz * pz + d < 0.0) {
        return false;
      }
    }

    return true;
  }

  /// Full containment test for an Axis-Aligned Bounding Box (AABB).
  ///
  /// Evaluates both p-vertex and n-vertex for precise containment classification.
  ContainmentResult testAabb(
    double minX,
    double minY,
    double minZ,
    double maxX,
    double maxY,
    double maxZ,
  ) {
    final b = planeBuffer;
    bool allInside = true;

    for (int i = 0; i < 24; i += 4) {
      final nx = b[i];
      final ny = b[i + 1];
      final nz = b[i + 2];
      final d = b[i + 3];

      final px = nx > 0.0 ? maxX : minX;
      final py = ny > 0.0 ? maxY : minY;
      final pz = nz > 0.0 ? maxZ : minZ;

      if (nx * px + ny * py + nz * pz + d < 0.0) {
        return ContainmentResult.outside;
      }

      final nxN = nx > 0.0 ? minX : maxX;
      final nyN = ny > 0.0 ? minY : maxY;
      final nzN = nz > 0.0 ? minZ : maxZ;

      if (nx * nxN + ny * nyN + nz * nzN + d < 0.0) {
        allInside = false;
      }
    }

    return allInside ? ContainmentResult.inside : ContainmentResult.intersects;
  }

  // =========================================================================
  // High-Performance Batch Culling (< 1ms for 10,000 entities)
  // =========================================================================

  /// Culls 10,000+ bounding spheres using flat Float32List positions and a uniform [radius].
  ///
  /// [positions]: Flat array containing entity coordinates `[x0, y0, z0, x1, y1, z1, ...]`.
  /// [stride]: Floats per entity (default 3 for `[x, y, z]`).
  /// [offset]: Starting float offset in [positions].
  /// [count]: Number of entities to process (-1 = automatically derived from buffer length).
  /// [outVisibleIndices]: Preallocated buffer where visible entity indices are written.
  ///
  /// Returns the count of visible entities written into [outVisibleIndices].
  /// Operates with ZERO heap allocations.
  int cullSpheres({
    required Float32List positions,
    required double radius,
    required Uint32List outVisibleIndices,
    int count = -1,
    int stride = 3,
    int offset = 0,
  }) {
    final entityCount = count >= 0 ? count : (positions.length - offset) ~/ stride;
    if (entityCount <= 0) return 0;

    final b = planeBuffer;
    final negR = -radius;

    // Cache plane coefficients in local CPU registers for maximum execution speed
    final p0x = b[0], p0y = b[1], p0z = b[2], p0d = b[3];
    final p1x = b[4], p1y = b[5], p1z = b[6], p1d = b[7];
    final p2x = b[8], p2y = b[9], p2z = b[10], p2d = b[11];
    final p3x = b[12], p3y = b[13], p3z = b[14], p3d = b[15];
    final p4x = b[16], p4y = b[17], p4z = b[18], p4d = b[19];
    final p5x = b[20], p5y = b[21], p5z = b[22], p5d = b[23];

    int visibleCount = 0;
    int posIdx = offset;

    for (int i = 0; i < entityCount; i++) {
      final x = positions[posIdx];
      final y = positions[posIdx + 1];
      final z = positions[posIdx + 2];
      posIdx += stride;

      // Aggressive early rejection on each clipping plane
      if (p0x * x + p0y * y + p0z * z + p0d < negR) continue;
      if (p1x * x + p1y * y + p1z * z + p1d < negR) continue;
      if (p2x * x + p2y * y + p2z * z + p2d < negR) continue;
      if (p3x * x + p3y * y + p3z * z + p3d < negR) continue;
      if (p4x * x + p4y * y + p4z * z + p4d < negR) continue;
      if (p5x * x + p5y * y + p5z * z + p5d < negR) continue;

      outVisibleIndices[visibleCount++] = i;
    }

    return visibleCount;
  }

  /// Culls spheres with individual radii from a flat interleaved buffer `[x, y, z, r, ...]`.
  ///
  /// [stride]: Defaults to 4 `[x, y, z, radius]`.
  int cullSpheresWithRadii({
    required Float32List positionsAndRadii,
    required Uint32List outVisibleIndices,
    int count = -1,
    int stride = 4,
    int offset = 0,
  }) {
    final entityCount =
        count >= 0 ? count : (positionsAndRadii.length - offset) ~/ stride;
    if (entityCount <= 0) return 0;

    final b = planeBuffer;
    final p0x = b[0], p0y = b[1], p0z = b[2], p0d = b[3];
    final p1x = b[4], p1y = b[5], p1z = b[6], p1d = b[7];
    final p2x = b[8], p2y = b[9], p2z = b[10], p2d = b[11];
    final p3x = b[12], p3y = b[13], p3z = b[14], p3d = b[15];
    final p4x = b[16], p4y = b[17], p4z = b[18], p4d = b[19];
    final p5x = b[20], p5y = b[21], p5z = b[22], p5d = b[23];

    int visibleCount = 0;
    int idx = offset;

    for (int i = 0; i < entityCount; i++) {
      final x = positionsAndRadii[idx];
      final y = positionsAndRadii[idx + 1];
      final z = positionsAndRadii[idx + 2];
      final negR = -positionsAndRadii[idx + 3];
      idx += stride;

      if (p0x * x + p0y * y + p0z * z + p0d < negR) continue;
      if (p1x * x + p1y * y + p1z * z + p1d < negR) continue;
      if (p2x * x + p2y * y + p2z * z + p2d < negR) continue;
      if (p3x * x + p3y * y + p3z * z + p3d < negR) continue;
      if (p4x * x + p4y * y + p4z * z + p4d < negR) continue;
      if (p5x * x + p5y * y + p5z * z + p5d < negR) continue;

      outVisibleIndices[visibleCount++] = i;
    }

    return visibleCount;
  }

  /// Culls AABBs from a flat buffer `[minX, minY, minZ, maxX, maxY, maxZ, ...]`.
  ///
  /// [stride]: Defaults to 6.
  int cullAabbs({
    required Float32List aabbMinMax,
    required Uint32List outVisibleIndices,
    int count = -1,
    int stride = 6,
    int offset = 0,
  }) {
    final entityCount =
        count >= 0 ? count : (aabbMinMax.length - offset) ~/ stride;
    if (entityCount <= 0) return 0;

    final b = planeBuffer;
    int visibleCount = 0;
    int idx = offset;

    for (int i = 0; i < entityCount; i++) {
      final minX = aabbMinMax[idx];
      final minY = aabbMinMax[idx + 1];
      final minZ = aabbMinMax[idx + 2];
      final maxX = aabbMinMax[idx + 3];
      final maxY = aabbMinMax[idx + 4];
      final maxZ = aabbMinMax[idx + 5];
      idx += stride;

      bool visible = true;
      for (int p = 0; p < 24; p += 4) {
        final nx = b[p];
        final ny = b[p + 1];
        final nz = b[p + 2];
        final d = b[p + 3];

        final px = nx > 0.0 ? maxX : minX;
        final py = ny > 0.0 ? maxY : minY;
        final pz = nz > 0.0 ? maxZ : minZ;

        if (nx * px + ny * py + nz * pz + d < 0.0) {
          visible = false;
          break;
        }
      }

      if (visible) {
        outVisibleIndices[visibleCount++] = i;
      }
    }

    return visibleCount;
  }

  /// Culls entities from a 4x4 transform matrix buffer.
  ///
  /// [matrixStride]: Typically 16 floats per entity.
  /// [positionOffset]: Offset within each matrix for position (12 for column-major translation).
  int cullTransforms({
    required Float32List transforms,
    required double radius,
    required Uint32List outVisibleIndices,
    int count = -1,
    int matrixStride = 16,
    int positionOffset = 12,
  }) {
    return cullSpheres(
      positions: transforms,
      radius: radius,
      outVisibleIndices: outVisibleIndices,
      count: count,
      stride: matrixStride,
      offset: positionOffset,
    );
  }

  /// Populates a 0/1 visibility mask in [outVisibilityMask] for direct GPU buffer upload.
  ///
  /// 1 = visible, 0 = culled.
  int cullSphereMask({
    required Float32List positions,
    required double radius,
    required Uint8List outVisibilityMask,
    int count = -1,
    int stride = 3,
    int offset = 0,
  }) {
    final entityCount = count >= 0 ? count : (positions.length - offset) ~/ stride;
    if (entityCount <= 0) return 0;

    final b = planeBuffer;
    final negR = -radius;

    final p0x = b[0], p0y = b[1], p0z = b[2], p0d = b[3];
    final p1x = b[4], p1y = b[5], p1z = b[6], p1d = b[7];
    final p2x = b[8], p2y = b[9], p2z = b[10], p2d = b[11];
    final p3x = b[12], p3y = b[13], p3z = b[14], p3d = b[15];
    final p4x = b[16], p4y = b[17], p4z = b[18], p4d = b[19];
    final p5x = b[20], p5y = b[21], p5z = b[22], p5d = b[23];

    int visibleCount = 0;
    int posIdx = offset;

    for (int i = 0; i < entityCount; i++) {
      final x = positions[posIdx];
      final y = positions[posIdx + 1];
      final z = positions[posIdx + 2];
      posIdx += stride;

      if (p0x * x + p0y * y + p0z * z + p0d < negR ||
          p1x * x + p1y * y + p1z * z + p1d < negR ||
          p2x * x + p2y * y + p2z * z + p2d < negR ||
          p3x * x + p3y * y + p3z * z + p3d < negR ||
          p4x * x + p4y * y + p4z * z + p4d < negR ||
          p5x * x + p5y * y + p5z * z + p5d < negR) {
        outVisibilityMask[i] = 0;
      } else {
        outVisibilityMask[i] = 1;
        visibleCount++;
      }
    }

    return visibleCount;
  }

  /// Culls only the candidate entities returned from Spatial Hash Grid queries.
  int cullIndexedSpheres({
    required Float32List positions,
    required List<int> candidateIndices,
    required double radius,
    required Uint32List outVisibleIndices,
    int stride = 3,
    int offset = 0,
  }) {
    final b = planeBuffer;
    final negR = -radius;

    final p0x = b[0], p0y = b[1], p0z = b[2], p0d = b[3];
    final p1x = b[4], p1y = b[5], p1z = b[6], p1d = b[7];
    final p2x = b[8], p2y = b[9], p2z = b[10], p2d = b[11];
    final p3x = b[12], p3y = b[13], p3z = b[14], p3d = b[15];
    final p4x = b[16], p4y = b[17], p4z = b[18], p4d = b[19];
    final p5x = b[20], p5y = b[21], p5z = b[22], p5d = b[23];

    int visibleCount = 0;

    for (int i = 0; i < candidateIndices.length; i++) {
      final idx = candidateIndices[i];
      final posIdx = offset + idx * stride;
      final x = positions[posIdx];
      final y = positions[posIdx + 1];
      final z = positions[posIdx + 2];

      if (p0x * x + p0y * y + p0z * z + p0d < negR) continue;
      if (p1x * x + p1y * y + p1z * z + p1d < negR) continue;
      if (p2x * x + p2y * y + p2z * z + p2d < negR) continue;
      if (p3x * x + p3y * y + p3z * z + p3d < negR) continue;
      if (p4x * x + p4y * y + p4z * z + p4d < negR) continue;
      if (p5x * x + p5y * y + p5z * z + p5d < negR) continue;

      outVisibleIndices[visibleCount++] = idx;
    }

    return visibleCount;
  }
}

/// Helper utilities for 4x4 matrix calculations and camera setup.
class FrustumMatrixUtils {
  const FrustumMatrixUtils._();

  /// Computes a standard 4x4 column-major perspective projection matrix.
  ///
  /// [fovYRadians]: Vertical Field of View in radians.
  /// [aspectRatio]: Width / Height.
  /// [near]: Near clipping plane distance (> 0).
  /// [far]: Far clipping plane distance (> near).
  /// [zeroToOne]: If true, near maps to z=0 (Vulkan/Metal); if false, near maps to z=-1 (OpenGL).
  static Float32List createPerspective({
    required double fovYRadians,
    required double aspectRatio,
    required double near,
    required double far,
    bool zeroToOne = false,
  }) {
    final m = Float32List(16);
    final f = 1.0 / math.tan(fovYRadians * 0.5);
    final rangeInv = 1.0 / (near - far);

    m[0] = f / aspectRatio;
    m[5] = f;

    if (zeroToOne) {
      m[10] = far * rangeInv;
      m[11] = -1.0;
      m[14] = near * far * rangeInv;
    } else {
      m[10] = (far + near) * rangeInv;
      m[11] = -1.0;
      m[14] = (2.0 * far * near) * rangeInv;
    }

    return m;
  }

  /// Computes a 4x4 column-major orthographic projection matrix.
  static Float32List createOrthographic({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
    bool zeroToOne = false,
  }) {
    final m = Float32List(16);
    final invW = 1.0 / (right - left);
    final invH = 1.0 / (top - bottom);
    final invD = 1.0 / (far - near);

    m[0] = 2.0 * invW;
    m[5] = 2.0 * invH;
    m[12] = -(right + left) * invW;
    m[13] = -(top + bottom) * invH;

    if (zeroToOne) {
      m[10] = -invD;
      m[14] = -near * invD;
      m[15] = 1.0;
    } else {
      m[10] = -2.0 * invD;
      m[14] = -(far + near) * invD;
      m[15] = 1.0;
    }

    return m;
  }

  /// Computes a 4x4 column-major LookAt view matrix.
  static Float32List createLookAt({
    required double eyeX,
    required double eyeY,
    required double eyeZ,
    required double targetX,
    required double targetY,
    required double targetZ,
    double upX = 0.0,
    double upY = 1.0,
    double upZ = 0.0,
  }) {
    // Forward = normalize(eye - target)
    double fx = eyeX - targetX;
    double fy = eyeY - targetY;
    double fz = eyeZ - targetZ;
    final fLen = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (fLen > 1e-12) {
      final invF = 1.0 / fLen;
      fx *= invF;
      fy *= invF;
      fz *= invF;
    }

    // Right = normalize(up x forward)
    double rx = upY * fz - upZ * fy;
    double ry = upZ * fx - upX * fz;
    double rz = upX * fy - upY * fx;
    final rLen = math.sqrt(rx * rx + ry * ry + rz * rz);
    if (rLen > 1e-12) {
      final invR = 1.0 / rLen;
      rx *= invR;
      ry *= invR;
      rz *= invR;
    }

    // Up = forward x right
    final ux = fy * rz - fz * ry;
    final uy = fz * rx - fx * rz;
    final uz = fx * ry - fy * rx;

    final m = Float32List(16);
    // Column 0
    m[0] = rx;
    m[1] = ux;
    m[2] = fx;
    m[3] = 0.0;

    // Column 1
    m[4] = ry;
    m[5] = uy;
    m[6] = fy;
    m[7] = 0.0;

    // Column 2
    m[8] = rz;
    m[9] = uz;
    m[10] = fz;
    m[11] = 0.0;

    // Column 3
    m[12] = -(rx * eyeX + ry * eyeY + rz * eyeZ);
    m[13] = -(ux * eyeX + uy * eyeY + uz * eyeZ);
    m[14] = -(fx * eyeX + fy * eyeY + fz * eyeZ);
    m[15] = 1.0;

    return m;
  }

  /// Multiplies two 4x4 column-major matrices: `result = a * b`.
  static Float32List multiply(List<double> a, List<double> b, [Float32List? out]) {
    final result = out ?? Float32List(16);

    for (int col = 0; col < 4; col++) {
      final b0 = b[col * 4];
      final b1 = b[col * 4 + 1];
      final b2 = b[col * 4 + 2];
      final b3 = b[col * 4 + 3];

      result[col * 4] = a[0] * b0 + a[4] * b1 + a[8] * b2 + a[12] * b3;
      result[col * 4 + 1] = a[1] * b0 + a[5] * b1 + a[9] * b2 + a[13] * b3;
      result[col * 4 + 2] = a[2] * b0 + a[6] * b1 + a[10] * b2 + a[14] * b3;
      result[col * 4 + 3] = a[3] * b0 + a[7] * b1 + a[11] * b2 + a[15] * b3;
    }

    return result;
  }
}
