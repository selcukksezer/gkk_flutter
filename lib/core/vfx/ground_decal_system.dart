import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

// =============================================================================
// 3D Math Fundamentals for OBB Ground Decal Projections
// =============================================================================

/// 3D Vector with double precision for world & local decal coordinates.
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  static const Vector3D zero = Vector3D(0.0, 0.0, 0.0);
  static const Vector3D one = Vector3D(1.0, 1.0, 1.0);
  static const Vector3D unitX = Vector3D(1.0, 0.0, 0.0);
  static const Vector3D unitY = Vector3D(0.0, 1.0, 0.0);
  static const Vector3D unitZ = Vector3D(0.0, 0.0, 1.0);
  static const Vector3D groundUp = Vector3D(0.0, 1.0, 0.0);
  static const Vector3D down = Vector3D(0.0, -1.0, 0.0);

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator -() => Vector3D(-x, -y, -z);
  Vector3D operator *(double s) => Vector3D(x * s, y * s, z * s);
  Vector3D operator /(double s) => Vector3D(x / s, y / s, z / s);

  double dot(Vector3D o) => x * o.x + y * o.y + z * o.z;

  Vector3D cross(Vector3D o) => Vector3D(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get lengthSquared => x * x + y * y + z * z;
  double get length => math.sqrt(lengthSquared);

  Vector3D get normalized {
    final l = length;
    if (l < 1e-9) return Vector3D.zero;
    return Vector3D(x / l, y / l, z / l);
  }

  double distanceTo(Vector3D o) => (this - o).length;

  Vector3D lerp(Vector3D target, double t) => Vector3D(
        x + (target.x - x) * t,
        y + (target.y - y) * t,
        z + (target.z - z) * t,
      );

  @override
  String toString() => 'Vector3D(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Unit Quaternion for 3D decal rotation and projector orientation.
class QuaternionD {
  final double x;
  final double y;
  final double z;
  final double w;

  const QuaternionD(this.x, this.y, this.z, this.w);

  static const QuaternionD identity = QuaternionD(0.0, 0.0, 0.0, 1.0);

  factory QuaternionD.fromAxisAngle(Vector3D axis, double radians) {
    final normAxis = axis.normalized;
    final half = radians * 0.5;
    final sinHalf = math.sin(half);
    return QuaternionD(
      normAxis.x * sinHalf,
      normAxis.y * sinHalf,
      normAxis.z * sinHalf,
      math.cos(half),
    );
  }

  /// Construct quaternion from Euler angles in radians (yaw [Y], pitch [X], roll [Z]).
  factory QuaternionD.fromEuler(double yaw, double pitch, double roll) {
    final cy = math.cos(yaw * 0.5);
    final sy = math.sin(yaw * 0.5);
    final cp = math.cos(pitch * 0.5);
    final sp = math.sin(pitch * 0.5);
    final cr = math.cos(roll * 0.5);
    final sr = math.sin(roll * 0.5);

    return QuaternionD(
      cy * sp * cr + sy * cp * sr,
      sy * cp * cr - cy * sp * sr,
      cy * cp * sr - sy * sp * cr,
      cy * cp * cr + sy * sp * sr,
    ).normalized;
  }

  /// Quaternion rotating from vector [from] to vector [to].
  factory QuaternionD.fromTo(Vector3D from, Vector3D to) {
    final v0 = from.normalized;
    final v1 = to.normalized;
    final dot = v0.dot(v1);

    if (dot >= 1.0 - 1e-6) {
      return QuaternionD.identity;
    }
    if (dot <= -1.0 + 1e-6) {
      // 180 degree rotation: pick an orthogonal axis
      var axis = Vector3D.unitX.cross(v0);
      if (axis.lengthSquared < 1e-6) {
        axis = Vector3D.unitY.cross(v0);
      }
      return QuaternionD.fromAxisAngle(axis.normalized, math.pi);
    }

    final cross = v0.cross(v1);
    final q = QuaternionD(cross.x, cross.y, cross.z, 1.0 + dot);
    return q.normalized;
  }

  double get lengthSquared => x * x + y * y + z * z + w * w;
  double get length => math.sqrt(lengthSquared);

  QuaternionD get normalized {
    final l = length;
    if (l < 1e-9) return QuaternionD.identity;
    return QuaternionD(x / l, y / l, z / l, w / l);
  }

  QuaternionD get conjugate => QuaternionD(-x, -y, -z, w);

  QuaternionD operator *(QuaternionD o) => QuaternionD(
        w * o.x + x * o.w + y * o.z - z * o.y,
        w * o.y - x * o.z + y * o.w + z * o.x,
        w * o.z + x * o.y - y * o.x + z * o.w,
        w * o.w - x * o.x - y * o.y - z * o.z,
      );

  /// Rotates a 3D vector by this quaternion: v' = q * (v, 0) * q^-1.
  Vector3D rotate(Vector3D v) {
    final qv = Vector3D(x, y, z);
    final uv = qv.cross(v);
    final uuv = qv.cross(uv);
    return v + (uv * (2.0 * w)) + (uuv * 2.0);
  }

  /// Inversely rotates a 3D vector (by conjugate).
  Vector3D unrotate(Vector3D v) => conjugate.rotate(v);

  /// Spherical linear interpolation.
  QuaternionD slerp(QuaternionD target, double t) {
    var cosHalfTheta = dot(target);
    var t2 = target;
    if (cosHalfTheta < 0.0) {
      t2 = QuaternionD(-target.x, -target.y, -target.z, -target.w);
      cosHalfTheta = -cosHalfTheta;
    }

    if (cosHalfTheta >= 1.0 - 1e-6) {
      return QuaternionD(
        x + (t2.x - x) * t,
        y + (t2.y - y) * t,
        z + (t2.z - z) * t,
        w + (t2.w - w) * t,
      ).normalized;
    }

    final halfTheta = math.acos(cosHalfTheta.clamp(-1.0, 1.0));
    final sinHalfTheta = math.sin(halfTheta);
    if (sinHalfTheta.abs() < 1e-6) {
      return this;
    }

    final ratioA = math.sin((1.0 - t) * halfTheta) / sinHalfTheta;
    final ratioB = math.sin(t * halfTheta) / sinHalfTheta;

    return QuaternionD(
      x * ratioA + t2.x * ratioB,
      y * ratioA + t2.y * ratioB,
      z * ratioA + t2.z * ratioB,
      w * ratioA + t2.w * ratioB,
    );
  }

  double dot(QuaternionD o) => x * o.x + y * o.y + z * o.z + w * o.w;

  Matrix4D toMatrix4() {
    final x2 = x + x;
    final y2 = y + y;
    final z2 = z + z;
    final xx = x * x2;
    final xy = x * y2;
    final xz = x * z2;
    final yy = y * y2;
    final yz = y * z2;
    final zz = z * z2;
    final wx = w * x2;
    final wy = w * y2;
    final wz = w * z2;

    return Matrix4D([
      1.0 - (yy + zz), xy + wz, xz - wy, 0.0,
      xy - wz, 1.0 - (xx + zz), yz + wx, 0.0,
      xz + wy, yz - wx, 1.0 - (xx + yy), 0.0,
      0.0, 0.0, 0.0, 1.0,
    ]);
  }
}

/// 4x4 Column-Major Matrix for Decal Transforms.
class Matrix4D {
  final List<double> m;

  Matrix4D([List<double>? values])
      : m = values != null && values.length == 16
            ? List<double>.from(values)
            : [
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
              ];

  static Matrix4D identity() => Matrix4D();

  factory Matrix4D.translation(Vector3D translation) {
    return Matrix4D([
      1.0, 0.0, 0.0, 0.0,
      0.0, 1.0, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      translation.x, translation.y, translation.z, 1.0,
    ]);
  }

  factory Matrix4D.scale(Vector3D scale) {
    return Matrix4D([
      scale.x, 0.0, 0.0, 0.0,
      0.0, scale.y, 0.0, 0.0,
      0.0, 0.0, scale.z, 0.0,
      0.0, 0.0, 0.0, 1.0,
    ]);
  }

  /// Construct transform matrix from translation, rotation quaternion, and scale.
  factory Matrix4D.compose(Vector3D translation, QuaternionD rotation, Vector3D scale) {
    final r = rotation.toMatrix4();
    final sx = scale.x;
    final sy = scale.y;
    final sz = scale.z;

    return Matrix4D([
      r.m[0] * sx, r.m[1] * sx, r.m[2] * sx, 0.0,
      r.m[4] * sy, r.m[5] * sy, r.m[6] * sy, 0.0,
      r.m[8] * sz, r.m[9] * sz, r.m[10] * sz, 0.0,
      translation.x, translation.y, translation.z, 1.0,
    ]);
  }

  Matrix4D operator *(Matrix4D b) {
    final res = List<double>.filled(16, 0.0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += m[k * 4 + j] * b.m[i * 4 + k];
        }
        res[i * 4 + j] = sum;
      }
    }
    return Matrix4D(res);
  }

  Vector3D transformPoint(Vector3D p) {
    final x = m[0] * p.x + m[4] * p.y + m[8] * p.z + m[12];
    final y = m[1] * p.x + m[5] * p.y + m[9] * p.z + m[13];
    final z = m[2] * p.x + m[6] * p.y + m[10] * p.z + m[14];
    final w = m[3] * p.x + m[7] * p.y + m[11] * p.z + m[15];
    if (w.abs() > 1e-9 && (w - 1.0).abs() > 1e-6) {
      return Vector3D(x / w, y / w, z / w);
    }
    return Vector3D(x, y, z);
  }

  Vector3D transformVector(Vector3D v) {
    final x = m[0] * v.x + m[4] * v.y + m[8] * v.z;
    final y = m[1] * v.x + m[5] * v.y + m[9] * v.z;
    final z = m[2] * v.x + m[6] * v.y + m[10] * v.z;
    return Vector3D(x, y, z);
  }

  /// Calculates inverse matrix (using standard adjugate/determinant).
  Matrix4D? inverse() {
    final a = m;
    final a00 = a[0], a01 = a[1], a02 = a[2], a03 = a[3];
    final a10 = a[4], a11 = a[5], a12 = a[6], a13 = a[7];
    final a20 = a[8], a21 = a[9], a22 = a[10], a23 = a[11];
    final a30 = a[12], a31 = a[13], a32 = a[14], a33 = a[15];

    final b00 = a00 * a11 - a01 * a10;
    final b01 = a00 * a12 - a02 * a10;
    final b02 = a00 * a13 - a03 * a10;
    final b03 = a01 * a12 - a02 * a11;
    final b04 = a01 * a13 - a03 * a11;
    final b05 = a02 * a13 - a03 * a12;
    final b06 = a20 * a31 - a21 * a30;
    final b07 = a20 * a32 - a22 * a30;
    final b08 = a20 * a33 - a23 * a30;
    final b09 = a21 * a32 - a22 * a31;
    final b10 = a21 * a33 - a23 * a31;
    final b11 = a22 * a33 - a23 * a32;

    final det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
    if (det.abs() < 1e-12) return null;

    final invDet = 1.0 / det;
    final inv = List<double>.filled(16, 0.0);

    inv[0] = (a11 * b11 - a12 * b10 + a13 * b09) * invDet;
    inv[1] = (-a01 * b11 + a02 * b10 - a03 * b09) * invDet;
    inv[2] = (a31 * b05 - a32 * b04 + a33 * b03) * invDet;
    inv[3] = (-a21 * b05 + a22 * b04 - a23 * b03) * invDet;
    inv[4] = (-a10 * b11 + a12 * b08 - a13 * b07) * invDet;
    inv[5] = (a00 * b11 - a02 * b08 + a03 * b07) * invDet;
    inv[6] = (-a30 * b05 + a32 * b02 - a33 * b01) * invDet;
    inv[7] = (a20 * b05 - a22 * b02 + a23 * b01) * invDet;
    inv[8] = (a10 * b10 - a11 * b08 + a13 * b06) * invDet;
    inv[9] = (-a00 * b10 + a01 * b08 - a03 * b06) * invDet;
    inv[10] = (a30 * b04 - a31 * b02 + a33 * b00) * invDet;
    inv[11] = (-a20 * b04 + a21 * b02 - a23 * b00) * invDet;
    inv[12] = (-a10 * b09 + a11 * b07 - a12 * b06) * invDet;
    inv[13] = (a00 * b09 - a01 * b07 + a02 * b06) * invDet;
    inv[14] = (-a30 * b03 + a31 * b01 - a32 * b00) * invDet;
    inv[15] = (a20 * b03 - a21 * b01 + a22 * b00) * invDet;

    return Matrix4D(inv);
  }

  Float32List toFloat32List() {
    final list = Float32List(16);
    for (int i = 0; i < 16; i++) {
      list[i] = m[i];
    }
    return list;
  }
}

// =============================================================================
// Oriented Bounding Box (OBB) Decal Projector
// =============================================================================

/// Result of projecting a world-space point into a decal's OBB volume.
class DecalProjectionResult {
  /// Projected 2D texture UV coordinate in [0, 1]^2.
  final Offset uv;

  /// Depth coordinate in local decal space [-1, 1] (0 is center of projector).
  final double depth;

  /// Whether the point falls inside the 3D oriented bounding box.
  final bool isInside;

  /// Distance from decal projection center in local 2D UV space [0, 1].
  final double radialDistance;

  /// Smooth edge attenuation factor [0, 1] based on distance to OBB boundaries.
  final double edgeFalloff;

  /// Surface normal alignment factor [0, 1] (1.0 = facing directly, 0.0 = steep/glancing).
  final double angleAttenuation;

  const DecalProjectionResult({
    required this.uv,
    required this.depth,
    required this.isInside,
    required this.radialDistance,
    required this.edgeFalloff,
    required this.angleAttenuation,
  });

  /// True if the projection contributes visually to the surface.
  bool get hasContribution => isInside && edgeFalloff > 0.001 && angleAttenuation > 0.001;
}

/// Oriented Bounding Box (OBB) defining the 3D volume within which the decal
/// is projected onto geometry.
class OrientedBoundingBox {
  /// Center position in world space.
  final Vector3D center;

  /// Half-extents along the 3 local principal axes (halfWidth, halfHeight, halfDepth).
  final Vector3D halfExtents;

  /// Rotation orientation of the decal projector.
  final QuaternionD orientation;

  late final Vector3D axisX; // Right / Tangent
  late final Vector3D axisY; // Forward / Bitangent
  late final Vector3D axisZ; // Projector Normal / Depth (pointing towards surface)
  late final Matrix4D worldToLocalMatrix;
  late final Matrix4D localToWorldMatrix;

  OrientedBoundingBox({
    required this.center,
    required this.halfExtents,
    required this.orientation,
  }) {
    // Derive orthonormal axes from orientation quaternion
    axisX = orientation.rotate(Vector3D.unitX).normalized;
    axisY = orientation.rotate(Vector3D.unitY).normalized;
    axisZ = orientation.rotate(Vector3D.unitZ).normalized;

    localToWorldMatrix = Matrix4D.compose(center, orientation, halfExtents);
    worldToLocalMatrix = localToWorldMatrix.inverse() ?? Matrix4D.identity();
  }

  /// Full dimensions of the bounding box (width, height, depth).
  Vector3D get size => halfExtents * 2.0;

  /// Bounding sphere radius encompassing this OBB.
  double get boundingRadius => halfExtents.length;

  /// Fast point-in-OBB containment test.
  bool containsPoint(Vector3D worldPoint) {
    final d = worldPoint - center;
    final distLocalX = d.dot(axisX).abs();
    final distLocalY = d.dot(axisY).abs();
    final distLocalZ = d.dot(axisZ).abs();

    return distLocalX <= halfExtents.x &&
        distLocalY <= halfExtents.y &&
        distLocalZ <= halfExtents.z;
  }

  /// Projects a world space point into local OBB decal coordinates and computes
  /// UV mapping, local depth, boundary falloff, and surface normal alignment.
  DecalProjectionResult projectPoint({
    required Vector3D worldPoint,
    required Vector3D surfaceNormal,
    double angleCutoff = 0.35,
    double edgeSoftness = 0.15,
  }) {
    final d = worldPoint - center;
    final lx = d.dot(axisX);
    final ly = d.dot(axisY);
    final lz = d.dot(axisZ);

    final normX = lx / math.max(halfExtents.x, 1e-6);
    final normY = ly / math.max(halfExtents.y, 1e-6);
    final normZ = lz / math.max(halfExtents.z, 1e-6);

    final inside = normX.abs() <= 1.0 && normY.abs() <= 1.0 && normZ.abs() <= 1.0;

    // UV in [0, 1] range
    final u = (normX * 0.5) + 0.5;
    final v = (normY * 0.5) + 0.5;

    // Radial distance from local center in normalized XY space
    final radialDist = math.sqrt(normX * normX + normY * normY);

    // Box edge falloff calculation
    final maxBoxDist = math.max(normX.abs(), normY.abs());
    final softness = edgeSoftness.clamp(0.01, 0.5);
    final edgeFalloff = 1.0 - _smoothStep(1.0 - softness, 1.0, maxBoxDist);

    // Surface normal alignment:
    // Projector points along -axisZ or axisZ towards surface
    final nSurf = surfaceNormal.normalized;
    final nProj = axisZ.normalized;
    // Decal projector faces towards ground, so alignment is dot(nSurf, -nProj) or dot(nSurf, nProj)
    final normalDot = (nSurf.dot(-nProj)).abs(); // allow bidirectional or oriented projector
    final alignmentFactor = _smoothStep(angleCutoff - 0.08, angleCutoff + 0.08, normalDot);

    return DecalProjectionResult(
      uv: Offset(u.clamp(0.0, 1.0), v.clamp(0.0, 1.0)),
      depth: normZ.clamp(-1.0, 1.0),
      isInside: inside,
      radialDistance: radialDist,
      edgeFalloff: edgeFalloff.clamp(0.0, 1.0),
      angleAttenuation: alignmentFactor.clamp(0.0, 1.0),
    );
  }

  /// Calculates the 8 corner vertices of the OBB in world coordinates.
  List<Vector3D> getCorners() {
    final corners = <Vector3D>[];
    for (int sx in [-1, 1]) {
      for (int sy in [-1, 1]) {
        for (int sz in [-1, 1]) {
          final local = axisX * (halfExtents.x * sx) +
              axisY * (halfExtents.y * sy) +
              axisZ * (halfExtents.z * sz);
          corners.add(center + local);
        }
      }
    }
    return corners;
  }

  /// Intersects this OBB with a ground plane (defined by a point and plane normal).
  /// Returns the footprint polygon vertices on the plane.
  List<Vector3D> intersectGroundPlane({
    Vector3D planePoint = Vector3D.zero,
    Vector3D planeNormal = Vector3D.groundUp,
  }) {
    final corners = getCorners();
    final edgePairs = [
      [0, 1], [2, 3], [4, 5], [6, 7], // along Z
      [0, 2], [1, 3], [4, 6], [5, 7], // along Y
      [0, 4], [1, 5], [2, 6], [3, 7], // along X
    ];

    final intersections = <Vector3D>[];
    final normPlane = planeNormal.normalized;

    for (final pair in edgePairs) {
      final p1 = corners[pair[0]];
      final p2 = corners[pair[1]];

      final d1 = (p1 - planePoint).dot(normPlane);
      final d2 = (p2 - planePoint).dot(normPlane);

      // Check if edge crosses the plane
      if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) {
        final t = d1 / (d1 - d2);
        intersections.add(p1.lerp(p2, t));
      } else if (d1.abs() < 1e-6) {
        intersections.add(p1);
      }
    }

    return intersections;
  }

  static double _smoothStep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / math.max(edge1 - edge0, 1e-6)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }
}

// =============================================================================
// Decal Types & Specific Presets (R3)
// =============================================================================

/// Decal categories specified in Requirement R3.
enum DecalType {
  /// Burnt charred ground with pulsating ember rim and elevated soot roughness.
  scorchMark,

  /// Visceral crimson blood splatter with satellite micro-droplets and low wet roughness.
  bloodSplatter,

  /// Fractured stone/earth crevice network with deep cavity indent and dusty roughness.
  crackedEarth,

  /// Linear directional blade/weapon impact gouge with flank debris and friction spark heat.
  slashGouge,

  /// Custom texture-based decal with normal map overlay and tint modulation.
  custom,
}

/// Blending behavior mode for ground decal rendering.
enum DecalBlendMode {
  /// Standard alpha blend over surface.
  alphaBlend,

  /// Modulate / multiply decal albedo into surface (good for stains, scorched soot).
  modulate,

  /// Additive light emission (glowing embers, magical runes).
  additive,
}

/// Non-linear fade curves for decal opacity decay.
enum DecalFadeCurve {
  /// Linear fade from 1.0 to 0.0.
  linear,

  /// Smooth Hermite smoothstep fade.
  smoothStep,

  /// Quadratic acceleration fade (lingers longer, then vanishes rapidly).
  quadratic,

  /// Exponential decay.
  exponential,
}

/// Preset configuration parameters for each DecalType.
class DecalTypePreset {
  final DecalType type;
  final Vector3D defaultSize;
  final ui.Color defaultColor;
  final double defaultRoughness;
  final double defaultNormalStrength;
  final double defaultLifetime;
  final double defaultFadeDuration;
  final DecalBlendMode blendMode;

  const DecalTypePreset({
    required this.type,
    required this.defaultSize,
    required this.defaultColor,
    required this.defaultRoughness,
    required this.defaultNormalStrength,
    required this.defaultLifetime,
    required this.defaultFadeDuration,
    required this.blendMode,
  });

  static const DecalTypePreset scorchMark = DecalTypePreset(
    type: DecalType.scorchMark,
    defaultSize: Vector3D(2.5, 2.5, 1.0),
    defaultColor: ui.Color(0xFF1E1714),
    defaultRoughness: 0.94,
    defaultNormalStrength: 0.75,
    defaultLifetime: 12.0,
    defaultFadeDuration: 3.5,
    blendMode: DecalBlendMode.modulate,
  );

  static const DecalTypePreset bloodSplatter = DecalTypePreset(
    type: DecalType.bloodSplatter,
    defaultSize: Vector3D(1.8, 1.8, 0.8),
    defaultColor: ui.Color(0xFF6B0B14),
    defaultRoughness: 0.08,
    defaultNormalStrength: 0.60,
    defaultLifetime: 18.0,
    defaultFadeDuration: 5.0,
    blendMode: DecalBlendMode.alphaBlend,
  );

  static const DecalTypePreset crackedEarth = DecalTypePreset(
    type: DecalType.crackedEarth,
    defaultSize: Vector3D(3.2, 3.2, 1.2),
    defaultColor: ui.Color(0xFF2A231C),
    defaultRoughness: 0.88,
    defaultNormalStrength: 1.20,
    defaultLifetime: 25.0,
    defaultFadeDuration: 6.0,
    blendMode: DecalBlendMode.alphaBlend,
  );

  static const DecalTypePreset slashGouge = DecalTypePreset(
    type: DecalType.slashGouge,
    defaultSize: Vector3D(0.6, 2.8, 0.9),
    defaultColor: ui.Color(0xFF1F1C1A),
    defaultRoughness: 0.76,
    defaultNormalStrength: 1.10,
    defaultLifetime: 10.0,
    defaultFadeDuration: 3.0,
    blendMode: DecalBlendMode.alphaBlend,
  );

  static const DecalTypePreset custom = DecalTypePreset(
    type: DecalType.custom,
    defaultSize: Vector3D(2.0, 2.0, 1.0),
    defaultColor: ui.Color(0xFFFFFFFF),
    defaultRoughness: 0.50,
    defaultNormalStrength: 1.00,
    defaultLifetime: 15.0,
    defaultFadeDuration: 4.0,
    blendMode: DecalBlendMode.alphaBlend,
  );

  static DecalTypePreset forType(DecalType type) {
    switch (type) {
      case DecalType.scorchMark:
        return scorchMark;
      case DecalType.bloodSplatter:
        return bloodSplatter;
      case DecalType.crackedEarth:
        return crackedEarth;
      case DecalType.slashGouge:
        return slashGouge;
      case DecalType.custom:
        return custom;
    }
  }
}

// =============================================================================
// Decal Instance (Represents an individual active decal in the world)
// =============================================================================

/// Individual decal projection in world space.
class DecalInstance {
  int id;
  DecalType type;
  Vector3D position;
  QuaternionD orientation;
  Vector3D size;
  Vector3D halfExtents;
  ui.Color color;
  double baseOpacity;
  double currentOpacity;
  double roughness;
  double normalStrength;
  double metallic;
  double totalLifetime;
  double elapsedTime;
  double fadeDuration;
  DecalFadeCurve fadeCurve;
  DecalBlendMode blendMode;
  double angleCutoff;
  double edgeSoftness;
  double proceduralSeed;
  bool isActive;
  bool isExpired;
  late OrientedBoundingBox obb;

  DecalInstance({
    this.id = 0,
    this.type = DecalType.scorchMark,
    this.position = Vector3D.zero,
    this.orientation = QuaternionD.identity,
    Vector3D? size,
    this.color = const ui.Color(0xFFFFFFFF),
    this.baseOpacity = 1.0,
    this.currentOpacity = 1.0,
    this.roughness = 0.5,
    this.normalStrength = 1.0,
    this.metallic = 0.0,
    this.totalLifetime = 10.0,
    this.elapsedTime = 0.0,
    this.fadeDuration = 3.0,
    this.fadeCurve = DecalFadeCurve.smoothStep,
    this.blendMode = DecalBlendMode.alphaBlend,
    this.angleCutoff = 0.35,
    this.edgeSoftness = 0.15,
    this.proceduralSeed = 0.0,
    this.isActive = true,
    this.isExpired = false,
  }) : size = size ?? const Vector3D(2.0, 2.0, 1.0),
       halfExtents = (size ?? const Vector3D(2.0, 2.0, 1.0)) * 0.5 {
    _rebuildOBB();
  }

  void _rebuildOBB() {
    halfExtents = size * 0.5;
    obb = OrientedBoundingBox(
      center: position,
      halfExtents: halfExtents,
      orientation: orientation,
    );
  }

  /// Reset and re-initialize decal slot (used by object pool & ring buffer).
  void initialize({
    required int id,
    required DecalType type,
    required Vector3D position,
    required QuaternionD orientation,
    required Vector3D size,
    required ui.Color color,
    double baseOpacity = 1.0,
    double roughness = 0.5,
    double normalStrength = 1.0,
    double metallic = 0.0,
    double totalLifetime = 10.0,
    double fadeDuration = 3.0,
    DecalFadeCurve fadeCurve = DecalFadeCurve.smoothStep,
    DecalBlendMode blendMode = DecalBlendMode.alphaBlend,
    double angleCutoff = 0.35,
    double edgeSoftness = 0.15,
    double? proceduralSeed,
  }) {
    this.id = id;
    this.type = type;
    this.position = position;
    this.orientation = orientation;
    this.size = size;
    this.color = color;
    this.baseOpacity = baseOpacity.clamp(0.0, 1.0);
    currentOpacity = this.baseOpacity;
    this.roughness = roughness.clamp(0.0, 1.0);
    this.normalStrength = normalStrength;
    this.metallic = metallic.clamp(0.0, 1.0);
    this.totalLifetime = totalLifetime;
    elapsedTime = 0.0;
    this.fadeDuration = fadeDuration;
    this.fadeCurve = fadeCurve;
    this.blendMode = blendMode;
    this.angleCutoff = angleCutoff;
    this.edgeSoftness = edgeSoftness;
    this.proceduralSeed = proceduralSeed ?? math.Random().nextDouble() * 1000.0;
    isActive = true;
    isExpired = false;
    _rebuildOBB();
  }

  /// Advance decal simulation time and calculate opacity fade.
  void update(double dt) {
    if (!isActive || isExpired) return;

    elapsedTime += dt;

    // Check lifetime and fade
    if (totalLifetime > 0.0) {
      if (elapsedTime >= totalLifetime) {
        currentOpacity = 0.0;
        isExpired = true;
        isActive = false;
        return;
      }

      final fadeStartTime = math.max(0.0, totalLifetime - fadeDuration);
      if (elapsedTime >= fadeStartTime && fadeDuration > 0.0) {
        final fadeProgress = ((elapsedTime - fadeStartTime) / fadeDuration).clamp(0.0, 1.0);
        final fadeFactor = _evaluateFadeCurve(1.0 - fadeProgress, fadeCurve);
        currentOpacity = baseOpacity * fadeFactor;
      } else {
        currentOpacity = baseOpacity;
      }
    } else {
      // Infinite lifetime
      currentOpacity = baseOpacity;
    }
  }

  /// Remaining lifetime fraction [0.0, 1.0].
  double get remainingLifetimeRatio {
    if (totalLifetime <= 0.0) return 1.0;
    return ((totalLifetime - elapsedTime) / totalLifetime).clamp(0.0, 1.0);
  }

  /// Projects a world ground point onto this decal instance.
  DecalProjectionResult project(Vector3D worldPoint, Vector3D surfaceNormal) {
    return obb.projectPoint(
      worldPoint: worldPoint,
      surfaceNormal: surfaceNormal,
      angleCutoff: angleCutoff,
      edgeSoftness: edgeSoftness,
    );
  }

  static double _evaluateFadeCurve(double t, DecalFadeCurve curve) {
    final clamped = t.clamp(0.0, 1.0);
    switch (curve) {
      case DecalFadeCurve.linear:
        return clamped;
      case DecalFadeCurve.smoothStep:
        return clamped * clamped * (3.0 - 2.0 * clamped);
      case DecalFadeCurve.quadratic:
        return clamped * clamped;
      case DecalFadeCurve.exponential:
        return math.pow(clamped, 3.0).toDouble();
    }
  }
}

// =============================================================================
// Ring Buffer Decal Pool (Zero GC Allocations on Spawn)
// =============================================================================

/// Fixed-capacity ring buffer pool ensuring a strict max decal cap with
/// constant-time circular replacement.
class DecalRingBuffer {
  final int capacity;
  final List<DecalInstance> _buffer;
  int _head = 0;
  int _activeCount = 0;
  int _totalSpawnedCount = 0;
  int _totalEvictionCount = 0;

  DecalRingBuffer({this.capacity = 128})
      : _buffer = List<DecalInstance>.generate(
          capacity,
          (index) => DecalInstance(id: index, isActive: false, isExpired: true),
          growable: false,
        );

  int get activeCount => _activeCount;
  int get totalSpawned => _totalSpawnedCount;
  int get totalEvictions => _totalEvictionCount;

  /// Retrieves the next available decal slot. If the buffer is full,
  /// the oldest active decal at the ring buffer head is evicted and recycled.
  DecalInstance allocateNext() {
    final slot = _buffer[_head];

    // If slot was active, this is an eviction of the oldest decal
    if (slot.isActive && !slot.isExpired) {
      _totalEvictionCount++;
    } else {
      _activeCount = math.min(_activeCount + 1, capacity);
    }

    _head = (_head + 1) % capacity;
    _totalSpawnedCount++;
    return slot;
  }

  /// All currently active decals.
  Iterable<DecalInstance> get activeDecals sync* {
    for (int i = 0; i < capacity; i++) {
      final decal = _buffer[i];
      if (decal.isActive && !decal.isExpired) {
        yield decal;
      }
    }
  }

  /// Advance simulation time for all active decals.
  void updateAll(double dt) {
    int liveCount = 0;
    for (int i = 0; i < capacity; i++) {
      final decal = _buffer[i];
      if (decal.isActive) {
        decal.update(dt);
        if (decal.isActive && !decal.isExpired) {
          liveCount++;
        }
      }
    }
    _activeCount = liveCount;
  }

  /// Clear all decals in the buffer.
  void clear() {
    for (int i = 0; i < capacity; i++) {
      _buffer[i].isActive = false;
      _buffer[i].isExpired = true;
    }
    _head = 0;
    _activeCount = 0;
  }

  /// Direct read-only index access for tests and internal inspections.
  DecalInstance operator [](int index) => _buffer[index];
}

// =============================================================================
// Ground Decal Projection System (Manager)
// =============================================================================

/// Central production manager for dynamic ground decal projections.
/// Supports oriented bounding boxes (OBB), normal alignment, opacity fade timelines,
/// and maximum decal capacity with ring buffer replacement.
class GroundDecalSystem {
  final DecalRingBuffer _ringBuffer;
  int _nextDecalId = 1;

  /// Default projection vector towards the ground (negative Y axis in 3D).
  final Vector3D defaultGroundNormal;

  GroundDecalSystem({
    int maxDecals = 128,
    this.defaultGroundNormal = Vector3D.groundUp,
  }) : _ringBuffer = DecalRingBuffer(capacity: maxDecals);

  int get maxCapacity => _ringBuffer.capacity;
  int get activeDecalCount => _ringBuffer.activeCount;
  int get totalSpawnedDecals => _ringBuffer.totalSpawned;
  int get totalEvictions => _ringBuffer.totalEvictions;
  Iterable<DecalInstance> get activeDecals => _ringBuffer.activeDecals;

  /// Construct default ground orientation (projecting down along -defaultGroundNormal)
  /// with an optional yaw rotation in radians around the surface normal.
  QuaternionD groundOrientation({double yaw = 0.0}) {
    final baseOrient = QuaternionD.fromTo(Vector3D.unitZ, -defaultGroundNormal);
    if (yaw.abs() > 1e-6) {
      final yawRot = QuaternionD.fromAxisAngle(defaultGroundNormal, yaw);
      return (yawRot * baseOrient).normalized;
    }
    return baseOrient;
  }

  /// Spawns a fully customized ground decal.
  DecalInstance spawnDecal({
    required DecalType type,
    required Vector3D position,
    QuaternionD? orientation,
    Vector3D? size,
    ui.Color? color,
    double? baseOpacity,
    double? roughness,
    double? normalStrength,
    double? metallic,
    double? lifetime,
    double? fadeDuration,
    DecalFadeCurve fadeCurve = DecalFadeCurve.smoothStep,
    DecalBlendMode? blendMode,
    double angleCutoff = 0.35,
    double edgeSoftness = 0.15,
    double? proceduralSeed,
  }) {
    final preset = DecalTypePreset.forType(type);
    final decal = _ringBuffer.allocateNext();

    decal.initialize(
      id: _nextDecalId++,
      type: type,
      position: position,
      orientation: orientation ?? groundOrientation(),
      size: size ?? preset.defaultSize,
      color: color ?? preset.defaultColor,
      baseOpacity: baseOpacity ?? 1.0,
      roughness: roughness ?? preset.defaultRoughness,
      normalStrength: normalStrength ?? preset.defaultNormalStrength,
      metallic: metallic ?? 0.0,
      totalLifetime: lifetime ?? preset.defaultLifetime,
      fadeDuration: fadeDuration ?? preset.defaultFadeDuration,
      fadeCurve: fadeCurve,
      blendMode: blendMode ?? preset.blendMode,
      angleCutoff: angleCutoff,
      edgeSoftness: edgeSoftness,
      proceduralSeed: proceduralSeed,
    );

    return decal;
  }

  /// Convenience method: Spawns a scorch mark decal (R3).
  DecalInstance spawnScorchMark({
    required Vector3D position,
    double radius = 2.0,
    double depth = 1.0,
    double yawRotation = 0.0,
    ui.Color? color,
    double? lifetime,
    double? fadeDuration,
  }) {
    return spawnDecal(
      type: DecalType.scorchMark,
      position: position,
      orientation: groundOrientation(yaw: yawRotation),
      size: Vector3D(radius * 2.0, radius * 2.0, depth),
      color: color,
      lifetime: lifetime,
      fadeDuration: fadeDuration,
    );
  }

  /// Convenience method: Spawns a blood splatter decal with directional splatter (R3).
  DecalInstance spawnBloodSplatter({
    required Vector3D position,
    Vector3D? impactVelocity,
    double radius = 1.5,
    double depth = 0.8,
    ui.Color? color,
    double? lifetime,
    double? fadeDuration,
  }) {
    double yaw = 0.0;
    if (impactVelocity != null && impactVelocity.lengthSquared > 1e-6) {
      yaw = math.atan2(impactVelocity.x, impactVelocity.z);
    } else {
      yaw = math.Random().nextDouble() * math.pi * 2.0;
    }

    return spawnDecal(
      type: DecalType.bloodSplatter,
      position: position,
      orientation: groundOrientation(yaw: yaw),
      size: Vector3D(radius * 2.0, radius * 2.0, depth),
      color: color,
      lifetime: lifetime,
      fadeDuration: fadeDuration,
    );
  }

  /// Convenience method: Spawns cracked earth / cracked stone fissures (R3).
  DecalInstance spawnCrackedEarth({
    required Vector3D position,
    double radius = 3.0,
    double depth = 1.2,
    double yawRotation = 0.0,
    ui.Color? color,
    double? lifetime,
    double? fadeDuration,
  }) {
    return spawnDecal(
      type: DecalType.crackedEarth,
      position: position,
      orientation: groundOrientation(yaw: yawRotation),
      size: Vector3D(radius * 2.0, radius * 2.0, depth),
      color: color,
      lifetime: lifetime,
      fadeDuration: fadeDuration,
    );
  }

  /// Convenience method: Spawns a directional slash impact gouge (R3).
  DecalInstance spawnSlashGouge({
    required Vector3D position,
    required Vector3D strikeDirection,
    double length = 2.8,
    double width = 0.6,
    double depth = 0.9,
    ui.Color? color,
    double? lifetime,
    double? fadeDuration,
  }) {
    final normDir = strikeDirection.normalized;
    final yaw = math.atan2(normDir.x, normDir.z);

    return spawnDecal(
      type: DecalType.slashGouge,
      position: position,
      orientation: groundOrientation(yaw: yaw),
      size: Vector3D(width, length, depth),
      color: color,
      lifetime: lifetime,
      fadeDuration: fadeDuration,
    );
  }

  /// Advance simulation time by [dt] seconds.
  void update(double dt) {
    _ringBuffer.updateAll(dt);
  }

  /// Clears all active decals.
  void clearAll() {
    _ringBuffer.clear();
  }

  /// Query all active decals influencing a specific ground point.
  List<DecalProjectionResult> queryPoint(Vector3D worldPoint, [Vector3D? surfaceNormal]) {
    final normal = surfaceNormal ?? defaultGroundNormal;
    final results = <DecalProjectionResult>[];

    for (final decal in _ringBuffer.activeDecals) {
      final res = decal.project(worldPoint, normal);
      if (res.hasContribution) {
        results.add(res);
      }
    }

    return results;
  }

  /// Spatial query for active decals overlapping a 2D bounding box on the ground.
  List<DecalInstance> queryBounds2D(Rect groundBounds) {
    final overlapping = <DecalInstance>[];
    for (final decal in _ringBuffer.activeDecals) {
      final r = decal.obb.boundingRadius;
      final decalBounds = Rect.fromCircle(
        center: Offset(decal.position.x, decal.position.z),
        radius: r,
      );
      if (groundBounds.overlaps(decalBounds)) {
        overlapping.add(decal);
      }
    }
    return overlapping;
  }

  /// Generate a flat batch descriptor for GPU shader uniforms and rendering.
  GroundDecalBatch generateRenderBatch({
    required Vector3D cameraPosition,
    double maxDistance = 50.0,
  }) {
    final batchItems = <DecalBatchItem>[];

    for (final decal in _ringBuffer.activeDecals) {
      final dist = decal.position.distanceTo(cameraPosition);
      if (dist <= maxDistance + decal.obb.boundingRadius) {
        batchItems.add(DecalBatchItem(
          decal: decal,
          distanceToCamera: dist,
        ));
      }
    }

    // Sort front-to-back or back-to-front depending on blend mode
    batchItems.sort((a, b) => b.distanceToCamera.compareTo(a.distanceToCamera));

    return GroundDecalBatch(items: batchItems);
  }
}

// =============================================================================
// GPU Batch & Shader Uniform Mapping
// =============================================================================

/// Decal batch item ready for shader rendering.
class DecalBatchItem {
  final DecalInstance decal;
  final double distanceToCamera;

  const DecalBatchItem({
    required this.decal,
    required this.distanceToCamera,
  });
}

/// Collection of decals batched for GPU draw calls.
class GroundDecalBatch {
  final List<DecalBatchItem> items;

  const GroundDecalBatch({required this.items});

  int get count => items.length;
}

/// Helper for binding decal uniforms to a Flutter [ui.FragmentShader] matching
/// `shaders/vfx/ground_decal.frag`.
class DecalShaderUniforms {
  /// Binds a decal's properties to a Flutter FragmentShader using exact uniform offsets.
  static void bindToShader({
    required ui.FragmentShader shader,
    required DecalInstance decal,
    required Size resolution,
    required Offset groundViewportOrigin,
    required double currentTime,
    Vector3D? surfaceNormal,
  }) {
    final sNormal = surfaceNormal ?? Vector3D.groundUp;
    final pNormal = decal.obb.axisZ;

    // Convert world position (X, Z) to 2D screen/render target pixels
    final screenX = (decal.position.x - groundViewportOrigin.dx);
    final screenY = (decal.position.z - groundViewportOrigin.dy);

    // Decal rotation around projection axis (yaw)
    final yaw = math.atan2(decal.obb.axisY.x, decal.obb.axisY.z);

    // Decal type index: 0=scorch, 1=blood, 2=cracked, 3=slash, 4=custom
    final typeIndex = decal.type.index.toDouble();

    // 0, 1: uResolution
    shader.setFloat(0, resolution.width);
    shader.setFloat(1, resolution.height);

    // 2, 3: uDecalCenter
    shader.setFloat(2, screenX);
    shader.setFloat(3, screenY);

    // 4, 5: uDecalHalfSize (in pixels)
    shader.setFloat(4, decal.halfExtents.x * 20.0); // pixels per unit scale
    shader.setFloat(5, decal.halfExtents.y * 20.0);

    // 6: uDecalRotation
    shader.setFloat(6, yaw);

    // 7: uOpacity
    shader.setFloat(7, decal.currentOpacity);

    // 8, 9, 10, 11: uAlbedoTint (RGBA normalized [0, 1])
    shader.setFloat(8, decal.color.r);
    shader.setFloat(9, decal.color.g);
    shader.setFloat(10, decal.color.b);
    shader.setFloat(11, decal.color.a);

    // 12: uNormalStrength
    shader.setFloat(12, decal.normalStrength);

    // 13: uRoughnessMod
    shader.setFloat(13, decal.roughness);

    // 14: uDecalType
    shader.setFloat(14, typeIndex);

    // 15, 16, 17: uSurfaceNormal
    shader.setFloat(15, sNormal.x);
    shader.setFloat(16, sNormal.y);
    shader.setFloat(17, sNormal.z);

    // 18, 19, 20: uProjectorNormal
    shader.setFloat(18, pNormal.x);
    shader.setFloat(19, pNormal.y);
    shader.setFloat(20, pNormal.z);

    // 21: uAngleCutoff
    shader.setFloat(21, decal.angleCutoff);

    // 22: uEdgeSoftness
    shader.setFloat(22, decal.edgeSoftness);

    // 23: uTime
    shader.setFloat(23, currentTime);

    // 24: uProceduralSeed
    shader.setFloat(24, decal.proceduralSeed);

    // 25: uDepthClip
    shader.setFloat(25, 1.0);
  }
}

// =============================================================================
// Ground Decal Custom Painter (Flutter Canvas Fallback & Visualization)
// =============================================================================

/// Canvas painter for rendering ground decals in Flutter views (top-down or isometric).
class GroundDecalPainter extends CustomPainter {
  final GroundDecalSystem system;
  final Offset cameraOffset;
  final double pixelsPerUnit;

  GroundDecalPainter({
    required this.system,
    this.cameraOffset = Offset.zero,
    this.pixelsPerUnit = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerOffset = Offset(size.width * 0.5, size.height * 0.5);

    for (final decal in system.activeDecals) {
      if (decal.currentOpacity <= 0.001) continue;

      final screenPos = Offset(
        centerOffset.dx + (decal.position.x - cameraOffset.dx) * pixelsPerUnit,
        centerOffset.dy + (decal.position.z - cameraOffset.dy) * pixelsPerUnit,
      );

      final radiusX = decal.halfExtents.x * pixelsPerUnit;
      final radiusY = decal.halfExtents.y * pixelsPerUnit;

      canvas.save();
      canvas.translate(screenPos.dx, screenPos.dy);

      // Decal yaw rotation
      final yaw = math.atan2(decal.obb.axisY.x, decal.obb.axisY.z);
      canvas.rotate(yaw);

      _paintDecal(canvas, decal, radiusX, radiusY);
      canvas.restore();
    }
  }

  void _paintDecal(Canvas canvas, DecalInstance decal, double rx, double ry) {
    final effectiveAlpha = (decal.color.a * decal.currentOpacity).clamp(0.0, 1.0);

    switch (decal.type) {
      case DecalType.scorchMark:
        // Charred center + burnt edge
        final paintSoot = Paint()
          ..color = decal.color.withValues(alpha: effectiveAlpha * 0.85)
          ..style = PaintingStyle.fill;
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2.0, height: ry * 2.0), paintSoot);

        // Ember ring
        final paintEmber = Paint()
          ..color = const ui.Color(0xFFFF6B1A).withValues(alpha: effectiveAlpha * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 1.6, height: ry * 1.6), paintEmber);
        break;

      case DecalType.bloodSplatter:
        // Crimson pool + splatter drops
        final paintBlood = Paint()
          ..color = decal.color.withValues(alpha: effectiveAlpha * 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 1.8, height: ry * 1.8), paintBlood);

        // Satellites
        final paintDrop = Paint()
          ..color = decal.color.withValues(alpha: effectiveAlpha * 0.75)
          ..style = PaintingStyle.fill;
        for (int i = 0; i < 6; i++) {
          final angle = (i * math.pi) / 3.0 + decal.proceduralSeed;
          final dist = rx * (1.2 + 0.3 * math.sin(i * 1.7));
          final dropPos = Offset(math.cos(angle) * dist, math.sin(angle) * dist);
          canvas.drawCircle(dropPos, rx * 0.18, paintDrop);
        }
        break;

      case DecalType.crackedEarth:
        // Fissure lines radiating outward
        final paintCrack = Paint()
          ..color = decal.color.withValues(alpha: effectiveAlpha * 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        for (int i = 0; i < 5; i++) {
          final angle = (i * math.pi * 2.0) / 5.0 + (decal.proceduralSeed % 1.0);
          final path = Path()..moveTo(0, 0);
          final midDist = rx * 0.5;
          final endDist = rx * 0.95;
          final midAngle = angle + 0.2 * math.sin(i * 2.0);
          path.lineTo(math.cos(midAngle) * midDist, math.sin(midAngle) * midDist);
          path.lineTo(math.cos(angle) * endDist, math.sin(angle) * endDist);
          canvas.drawPath(path, paintCrack);
        }
        break;

      case DecalType.slashGouge:
        // Elongated linear trench
        final paintGouge = Paint()
          ..color = decal.color.withValues(alpha: effectiveAlpha * 0.9)
          ..style = PaintingStyle.fill;
        final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2.0, height: ry * 2.0);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rx)), paintGouge);

        // Inner strike highlight
        final paintHighlight = Paint()
          ..color = const ui.Color(0xFFFFAA33).withValues(alpha: effectiveAlpha * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(0, -ry * 0.6), Offset(0, ry * 0.6), paintHighlight);
        break;

      case DecalType.custom:
        final paintCustom = Paint()
          ..color = decal.color.withValues(alpha: effectiveAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: rx * 2.0, height: ry * 2.0), paintCustom);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant GroundDecalPainter oldDelegate) => true;
}
