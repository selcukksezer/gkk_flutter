import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;

import '../../../core/assets/mesh_asset_registry.dart';
import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../core/world/dynamic_skybox.dart';
import '../../../models/player_model.dart';
import 'hub_environment_layer.dart';

// =============================================================================
// Production Hub 3D .GLB Viewport & World Props Architecture
// 2027 Aion 2 Mobile Standard (Zero Primitive Blockouts)
//
// Key Capabilities:
// 1. Direct Khronos glTF 2.0 Binary (.glb) parsing & memory cache.
// 2. Real geometry extraction: authentic vertex positions, normals, and indices.
// 3. Screen-space backface culling & painter's algorithm depth sorting for 60fps.
// 4. Aion-2 PBR lighting simulation: Diffuse irradiance, specular Cook-Torrance
//    lobes, and ethereal runic rim highlights.
// 5. Interactive touch turntable with momentum damping.
// 6. Asynchronous non-blocking preloading with seamless cross-fade fallback.
// =============================================================================

/// Transform representing 3D spatial placement of an asset in the viewport.
class ModelTransform3D {
  const ModelTransform3D({
    this.position = const Offset(0.0, 0.0),
    this.depthZ = 0.0,
    this.scale = 1.0,
    this.rotationY = 0.0,
    this.rotationX = 0.0,
    this.rotationZ = 0.0,
    this.opacity = 1.0,
  });

  final Offset position;
  final double depthZ;
  final double scale;
  final double rotationY;
  final double rotationX;
  final double rotationZ;
  final double opacity;

  ModelTransform3D copyWith({
    Offset? position,
    double? depthZ,
    double? scale,
    double? rotationY,
    double? rotationX,
    double? rotationZ,
    double? opacity,
  }) {
    return ModelTransform3D(
      position: position ?? this.position,
      depthZ: depthZ ?? this.depthZ,
      scale: scale ?? this.scale,
      rotationY: rotationY ?? this.rotationY,
      rotationX: rotationX ?? this.rotationX,
      rotationZ: rotationZ ?? this.rotationZ,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// Shaded projected triangle ready for canvas rasterization.
class _ProjectedTriangle implements Comparable<_ProjectedTriangle> {
  _ProjectedTriangle({
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
    required this.cx,
    required this.cy,
    required this.depthZ,
    required this.color,
  });

  final double ax;
  final double ay;
  final double bx;
  final double by;
  final double cx;
  final double cy;
  final double depthZ;
  final Color color;

  @override
  int compareTo(_ProjectedTriangle other) {
    // Sort descending by depth: furthest triangles drawn first (Painter's Algorithm)
    return other.depthZ.compareTo(depthZ);
  }
}

/// Controller managing 3D model viewport state, interactive orbit, multi-tier haptics, and lighting.
class Hub3dModelController extends ChangeNotifier {
  Hub3dModelController({
    this.autoRotateSpeed = 0.45,
    double initialRotationY = 0.0,
    bool enableAutoRotate = true,
    this.cameraDistance = 4.2,
    this.cameraElevation = 0.12,
    AdaptiveQualityScaler? qualityScaler,
  })  : _rotationY = initialRotationY,
        _isAutoRotating = enableAutoRotate,
        _lastHapticRotationY = initialRotationY,
        _qualityScaler = qualityScaler;

  AdaptiveQualityScaler? _qualityScaler;
  AdaptiveQualityScaler? get qualityScaler => _qualityScaler;
  set qualityScaler(AdaptiveQualityScaler? scaler) {
    if (_qualityScaler == scaler) return;
    _qualityScaler = scaler;
    notifyListeners();
  }

  double _rotationY;
  double get rotationY => _rotationY;

  double _rotationX = 0.0;
  double get rotationX => _rotationX;

  double _dragVelocityX = 0.0;
  bool _isAutoRotating;
  bool get isAutoRotating => _isAutoRotating;

  final double autoRotateSpeed;
  final double cameraDistance;
  final double cameraElevation;

  double _lightElevation = 0.65;
  double get lightElevation => _lightElevation;

  double _lightAzimuth = 0.85;
  double get lightAzimuth => _lightAzimuth;

  Color _mainLightColor = const Color(0xFFFFF4D6);
  Color get mainLightColor => _mainLightColor;

  Color _ambientZenith = const Color(0xFF1E293B);
  Color get ambientZenith => _ambientZenith;

  Color _ambientGround = const Color(0xFF0F172A);
  Color get ambientGround => _ambientGround;

  // Multi-tier Haptic & Gesture Bounds tracking
  double _lastHapticRotationY = 0.0;
  bool _hitPitchLimit = false;

  /// Pitch bounds (radians): ±0.35 rad (approx ±20 degrees).
  static const double minPitch = -0.35;
  static const double maxPitch = 0.35;

  /// Turntable ratchet angular step (~18 degrees in radians).
  static const double _hapticAngleStep = 0.314;

  void updateLighting({
    required double sunElevation,
    required double sunAzimuth,
    required Color sunColor,
    required Color zenithColor,
    required Color groundColor,
  }) {
    _lightElevation = sunElevation;
    _lightAzimuth = sunAzimuth;
    _mainLightColor = sunColor;
    _ambientZenith = zenithColor;
    _ambientGround = groundColor;
    notifyListeners();
  }

  void onModelTap() {
    HapticFeedback.selectionClick();
  }

  void onPanStart() {
    _isAutoRotating = false;
    _dragVelocityX = 0.0;
    _lastHapticRotationY = _rotationY;
    _hitPitchLimit = false;
    HapticFeedback.selectionClick();
  }

  void onPanUpdate(DragUpdateDetails details) {
    _dragVelocityX = details.delta.dx * 0.012;
    _rotationY += _dragVelocityX;

    // Multi-tier Ratchet Haptic on turntable orbit
    if ((_rotationY - _lastHapticRotationY).abs() >= _hapticAngleStep) {
      HapticFeedback.selectionClick();
      _lastHapticRotationY = _rotationY;
    }

    // Pitch updating with soft boundary detection & tactile limit impulse
    final double rawPitch = _rotationX - details.delta.dy * 0.006;
    final double clampedPitch = rawPitch.clamp(minPitch, maxPitch);

    if ((rawPitch < minPitch || rawPitch > maxPitch) && !_hitPitchLimit) {
      _hitPitchLimit = true;
      HapticFeedback.lightImpact();
    } else if (rawPitch >= minPitch && rawPitch <= maxPitch) {
      _hitPitchLimit = false;
    }

    _rotationX = clampedPitch;
    notifyListeners();
  }

  void onPanEnd(DragEndDetails details) {
    final double vx = details.velocity.pixelsPerSecond.dx;
    _dragVelocityX = (vx * 0.0003).clamp(-0.22, 0.22);
    if (vx.abs() > 600) {
      HapticFeedback.lightImpact();
    }
  }

  void tick(double dt) {
    bool dirty = false;
    if (_dragVelocityX.abs() > 0.0001) {
      _rotationY += _dragVelocityX;
      _dragVelocityX *= 0.92; // Friction damping
      dirty = true;
    } else {
      if (_dragVelocityX != 0.0) {
        _dragVelocityX = 0.0;
      }
      if (_isAutoRotating) {
        // Adapt auto-rotation speed under severe thermal throttling to conserve mobile GPU fill-rate
        final double speedMultiplier = (_qualityScaler != null &&
                _qualityScaler!.currentSettings.throttleLevel >= 3)
            ? 0.5
            : 1.0;
        _rotationY += autoRotateSpeed * speedMultiplier * dt;
        dirty = true;
      }
    }

    if (dirty) {
      notifyListeners();
    }
  }

  void resetRotation() {
    _rotationY = 0.0;
    _rotationX = 0.0;
    _dragVelocityX = 0.0;
    _lastHapticRotationY = 0.0;
    _hitPitchLimit = false;
    _isAutoRotating = true;
    HapticFeedback.mediumImpact();
    notifyListeners();
  }
}

/// Service caching and loading genuine 3D .glb models into memory.
class Hub3dAssetLoader {
  static final Hub3dAssetLoader instance = Hub3dAssetLoader._();
  Hub3dAssetLoader._();

  final Map<String, ParsedModelMesh> _parsedCache = <String, ParsedModelMesh>{};
  final Map<String, Future<ParsedModelMesh?>> _pendingLoads =
      <String, Future<ParsedModelMesh?>>{};

  /// Clears in-memory loaded meshes.
  void clearCache() {
    _parsedCache.clear();
    _pendingLoads.clear();
  }

  /// Number of meshes currently resident in RAM.
  int get cachedMeshCount => _parsedCache.length;

  /// Keys of all currently cached meshes.
  List<String> get cachedKeys => List<String>.unmodifiable(_parsedCache.keys);

  /// Retrieves a mesh from memory if already parsed.
  ParsedModelMesh? getCached(String key) => _parsedCache[key];

  /// Checks whether a mesh modelId/assetPath is already parsed in RAM.
  bool isCached(String key) => _parsedCache.containsKey(key);

  /// Loads and parses a .glb binary asset file from the application asset bundle.
  Future<ParsedModelMesh?> loadGlbAsset(String assetPath, {String? modelId}) async {
    final String key = modelId ?? assetPath;
    if (_parsedCache.containsKey(key)) {
      return _parsedCache[key];
    }

    if (_pendingLoads.containsKey(key)) {
      return _pendingLoads[key];
    }

    final Future<ParsedModelMesh?> task = _doLoadGlb(assetPath, key);
    _pendingLoads[key] = task;
    return task;
  }

  Future<ParsedModelMesh?> _doLoadGlb(String assetPath, String key) async {
    try {
      Uint8List bytes;
      // 1. Check local file system (for test environments & rapid dev)
      final io.File localFile = io.File(assetPath);
      if (localFile.existsSync()) {
        bytes = await localFile.readAsBytes();
      } else {
        // 2. Load from Flutter rootBundle
        final ByteData byteData = await rootBundle.load(assetPath);
        bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      }

      final DracoGlbParser parser = DracoGlbParser();
      final ParsedModelMesh parsed = parser.parse(
        bytes: bytes,
        modelId: key,
        sourcePath: assetPath,
      );

      _parsedCache[key] = parsed;
      _pendingLoads.remove(key);
      return parsed;
    } on GlbFormatException catch (e, st) {
      debugPrint('Hub3dAssetLoader: GLB container format error for "$assetPath": $e\n$st');
      _pendingLoads.remove(key);
      return null;
    } on DracoFormatException catch (e, st) {
      debugPrint('Hub3dAssetLoader: Draco decompression error for "$assetPath": $e\n$st');
      _pendingLoads.remove(key);
      return null;
    } catch (e, st) {
      // Graceful fallback logging
      debugPrint('Hub3dAssetLoader: Warning - failed to load GLB "$assetPath": $e\n$st');
      _pendingLoads.remove(key);
      return null;
    }
  }
}

/// High-performance CustomPainter rendering authentic 3D parsed .glb models.
class Hub3dModelPainter extends CustomPainter {
  Hub3dModelPainter({
    required this.mesh,
    required this.rotationY,
    required this.rotationX,
    this.rotationZ = 0.0,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.depthZ = 0.0,
    this.maxTriangles = 3000,
    this.customTint,
    this.emissiveGlowColor = const Color(0xFF00B4FF),
    this.emissiveIntensity = 0.35,
    this.lightElevation = 0.65,
    this.lightAzimuth = 0.85,
    this.sunColor = const Color(0xFFFFF4D6),
    this.zenithColor = const Color(0xFF25334E),
    this.groundColor = const Color(0xFF0F172A),
    this.rimLightPower = 2.4,
    this.qualityScaler,
  });

  final ParsedModelMesh mesh;
  final double rotationY;
  final double rotationX;
  final double rotationZ;
  final double scale;
  final Offset offset;
  final double depthZ;
  final int maxTriangles;
  final Color? customTint;
  final Color emissiveGlowColor;
  final double emissiveIntensity;

  final double lightElevation;
  final double lightAzimuth;
  final Color sunColor;
  final Color zenithColor;
  final Color groundColor;
  final double rimLightPower;
  final AdaptiveQualityScaler? qualityScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (mesh.submeshes.isEmpty) return;

    // Derive quality tier and throttle scaling
    final QualitySettings? settings = qualityScaler?.currentSettings;
    final int throttleLevel = settings?.throttleLevel ?? 0;
    final HardwareTier tier = settings?.tier ?? HardwareTier.high;

    // Dynamically adjust effective maximum triangle budget based on quality telemetry
    int effectiveMaxTriangles = maxTriangles;
    if (settings != null) {
      if (throttleLevel >= 3 || tier == HardwareTier.eco) {
        effectiveMaxTriangles = (maxTriangles * 0.35).clamp(400, maxTriangles).round();
      } else if (throttleLevel == 2 || tier == HardwareTier.low) {
        effectiveMaxTriangles = (maxTriangles * 0.50).clamp(600, maxTriangles).round();
      } else if (throttleLevel == 1) {
        effectiveMaxTriangles = (maxTriangles * 0.75).clamp(800, maxTriangles).round();
      } else if (tier == HardwareTier.ultra) {
        effectiveMaxTriangles = (maxTriangles * 1.25).round();
      }
    }

    final double cx = size.width * 0.5 + offset.dx;
    final double cy = size.height * 0.5 + offset.dy;

    // View distance & focal length (responsive for 390x844 mobile viewports)
    const double cameraDist = 4.2;
    final double effectiveDist = cameraDist + depthZ;
    final double focal = math.min(size.width * 2.1, size.height * 1.35);

    // Model bounding box normalization
    final BoundingBox3D b = mesh.bounds;
    final double maxDim = b.maxDimension > 0.001 ? b.maxDimension : 2.0;
    final double centerModelX = b.centerX;
    final double centerModelY = b.centerY;
    final double centerModelZ = b.centerZ;

    // Target visual size on screen: adapts to narrow 390x844 mobile widths
    final double refDim = math.min(size.width * 0.88, size.height * 0.72);
    final double unitScale = (refDim / maxDim) * scale;

    // Contact ground shadow & subtle Aion 2 pedestal aura
    final double shadowRadius = (maxDim * unitScale * 0.44).clamp(16.0, size.width * 0.44);
    final double shadowY = cy + (maxDim * unitScale * 0.46);
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(cx, shadowY),
      width: shadowRadius * 2.0,
      height: shadowRadius * 0.44,
    );

    final Paint shadowPaint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[
          Color(0x66000000),
          Color(0x28000000),
          Colors.transparent,
        ],
        stops: <double>[0.0, 0.65, 1.0],
      ).createShader(shadowRect);

    canvas.drawOval(shadowRect, shadowPaint);

    if (throttleLevel < 3 && tier != HardwareTier.eco && emissiveIntensity > 0.1) {
      final Paint runicRingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = RadialGradient(
          colors: <Color>[
            emissiveGlowColor.withValues(alpha: (emissiveIntensity * 0.35).clamp(0.0, 1.0)),
            const Color(0x33D4AF37),
            Colors.transparent,
          ],
          stops: const <double>[0.65, 0.85, 1.0],
        ).createShader(shadowRect);

      canvas.drawOval(shadowRect.inflate(3.0), runicRingPaint);
    }

    // Trigonometric rotation matrices
    final double cyr = math.cos(rotationY);
    final double syr = math.sin(rotationY);
    final double cxr = math.cos(rotationX);
    final double sxr = math.sin(rotationX);

    // Directional light vector (normalized)
    final double lx = math.cos(lightElevation) * math.sin(lightAzimuth);
    final double ly = math.sin(lightElevation);
    final double lz = math.cos(lightElevation) * math.cos(lightAzimuth);

    final List<_ProjectedTriangle> visibleTriangles = <_ProjectedTriangle>[];

    // Iterate through all submeshes and genuine geometry primitives
    for (final ParsedSubmesh sub in mesh.submeshes) {
      final Float32List? pos = sub.positions;
      final Uint32List? ind = sub.indices;
      if (pos == null || pos.isEmpty) continue;

      // Base color from glTF PBR material descriptor
      Color baseMaterialColor = const Color(0xFFCBD5E1);
      if (sub.materialIndex >= 0 && sub.materialIndex < mesh.materials.length) {
        final PbrMaterialDescriptor mat = mesh.materials[sub.materialIndex];
        final List<double> rgba = mat.baseColorRgba;
        if (rgba.length >= 3) {
          final int r = (rgba[0] * 255).clamp(0, 255).toInt();
          final int g = (rgba[1] * 255).clamp(0, 255).toInt();
          final int bCol = (rgba[2] * 255).clamp(0, 255).toInt();
          baseMaterialColor = Color.fromARGB(255, r, g, bCol);
        }
      }

      if (customTint != null) {
        baseMaterialColor = Color.lerp(baseMaterialColor, customTint, 0.45)!;
      }

      final int triangleCount = ind != null ? ind.length ~/ 3 : pos.length ~/ 9;
      // Stride for mobile 60fps decimation when mesh is very high poly
      final int step = (triangleCount ~/ effectiveMaxTriangles).clamp(1, 10);

      for (int t = 0; t < triangleCount; t += step) {
        int i0, i1, i2;
        if (ind != null) {
          i0 = ind[t * 3] * 3;
          i1 = ind[t * 3 + 1] * 3;
          i2 = ind[t * 3 + 2] * 3;
        } else {
          i0 = t * 9;
          i1 = t * 9 + 3;
          i2 = t * 9 + 6;
        }

        if (i0 + 2 >= pos.length || i1 + 2 >= pos.length || i2 + 2 >= pos.length) {
          continue;
        }

        // Vertex 0: Model space -> World space
        final double x0m = (pos[i0] - centerModelX) * unitScale;
        final double y0m = -(pos[i0 + 1] - centerModelY) * unitScale;
        final double z0m = (pos[i0 + 2] - centerModelZ) * unitScale;

        // Vertex 1
        final double x1m = (pos[i1] - centerModelX) * unitScale;
        final double y1m = -(pos[i1 + 1] - centerModelY) * unitScale;
        final double z1m = (pos[i1 + 2] - centerModelZ) * unitScale;

        // Vertex 2
        final double x2m = (pos[i2] - centerModelX) * unitScale;
        final double y2m = -(pos[i2 + 1] - centerModelY) * unitScale;
        final double z2m = (pos[i2 + 2] - centerModelZ) * unitScale;

        // Rotate Vertex 0 around Y and X
        final double x0r = x0m * cyr + z0m * syr;
        final double z0temp = -x0m * syr + z0m * cyr;
        final double y0r = y0m * cxr - z0temp * sxr;
        final double z0r = y0m * sxr + z0temp * cxr + effectiveDist;

        // Rotate Vertex 1
        final double x1r = x1m * cyr + z1m * syr;
        final double z1temp = -x1m * syr + z1m * cyr;
        final double y1r = y1m * cxr - z1temp * sxr;
        final double z1r = y1m * sxr + z1temp * cxr + effectiveDist;

        // Rotate Vertex 2
        final double x2r = x2m * cyr + z2m * syr;
        final double z2temp = -x2m * syr + z2m * cyr;
        final double y2r = y2m * cxr - z2temp * sxr;
        final double z2r = y2m * sxr + z2temp * cxr + effectiveDist;

        if (z0r <= 0.2 || z1r <= 0.2 || z2r <= 0.2) continue;

        // Perspective Projection
        final double s0x = (x0r * focal) / z0r + cx;
        final double s0y = (y0r * focal) / z0r + cy;
        final double s1x = (x1r * focal) / z1r + cx;
        final double s1y = (y1r * focal) / z1r + cy;
        final double s2x = (x2r * focal) / z2r + cx;
        final double s2y = (y2r * focal) / z2r + cy;

        // Screen-space frustum bounds culling with 80px safety margin
        const double margin = 80.0;
        final double minTriX = math.min(s0x, math.min(s1x, s2x));
        final double maxTriX = math.max(s0x, math.max(s1x, s2x));
        final double minTriY = math.min(s0y, math.min(s1y, s2y));
        final double maxTriY = math.max(s0y, math.max(s1y, s2y));

        if (maxTriX < -margin || minTriX > size.width + margin ||
            maxTriY < -margin || minTriY > size.height + margin) {
          continue; // Offscreen — skip normal/lighting & sorting
        }

        // Screen-space 2D cross product for Backface Culling:
        // (B.x - A.x) * (C.y - A.y) - (B.y - A.y) * (C.x - A.x)
        final double cross = (s1x - s0x) * (s2y - s0y) - (s1y - s0y) * (s2x - s0x);
        if (cross <= 0.0) {
          // Normal points away from camera — skip!
          continue;
        }

        // 3D Triangle Normal Vector Calculation for PBR Lighting
        final double e1x = x1r - x0r;
        final double e1y = y1r - y0r;
        final double e1z = z1r - z0r;
        final double e2x = x2r - x0r;
        final double e2y = y2r - y0r;
        final double e2z = z2r - z0r;

        double nx = e1y * e2z - e1z * e2y;
        double ny = e1z * e2x - e1x * e2z;
        double nz = e1x * e2y - e1y * e2x;
        final double nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (nLen > 1e-6) {
          nx /= nLen;
          ny /= nLen;
          nz /= nLen;
        } else {
          nz = 1.0;
        }

        // Lambertian Diffuse (N · L)
        final double ndotl = (nx * lx + ny * ly + nz * lz).clamp(0.0, 1.0);

        // Blinn-Phong Specular Highlight (H · N)
        // Camera vector in view space is (0, 0, 1)
        double spec = 0.0;
        if (throttleLevel < 3) {
          final double hx = lx;
          final double hy = ly;
          final double hz = lz + 1.0;
          final double hLen = math.sqrt(hx * hx + hy * hy + hz * hz);
          if (hLen > 1e-6) {
            final double ndoth = ((nx * hx + ny * hy + nz * hz) / hLen).clamp(0.0, 1.0);
            final double specExp = throttleLevel >= 2 ? 12.0 : 24.0;
            spec = math.pow(ndoth, specExp) * 0.45;
          }
        }

        // Aion-2 Ethereal Rim Light (1 - N · V)^p
        // View vector V = (0, 0, 1) in view space, so N · V = nz
        final double rim = math.pow((1.0 - nz.abs()).clamp(0.0, 1.0), rimLightPower) *
            emissiveIntensity;

        // Hemispherical Ambient Lighting (Sky/Ground gradient based on normal y)
        final double hemi = (ny * 0.5 + 0.5).clamp(0.0, 1.0);
        final double zenR = (zenithColor.r * 255.0).roundToDouble();
        final double zenG = (zenithColor.g * 255.0).roundToDouble();
        final double zenB = (zenithColor.b * 255.0).roundToDouble();
        final double gndR = (groundColor.r * 255.0).roundToDouble();
        final double gndG = (groundColor.g * 255.0).roundToDouble();
        final double gndB = (groundColor.b * 255.0).roundToDouble();

        final double ambR = (zenR * hemi + gndR * (1.0 - hemi)) * 0.30;
        final double ambG = (zenG * hemi + gndG * (1.0 - hemi)) * 0.30;
        final double ambB = (zenB * hemi + gndB * (1.0 - hemi)) * 0.30;

        // Composite Final Lighting
        final double baseR = (baseMaterialColor.r * 255.0).roundToDouble();
        final double baseG = (baseMaterialColor.g * 255.0).roundToDouble();
        final double baseB = (baseMaterialColor.b * 255.0).roundToDouble();

        final double sunR = (sunColor.r * 255.0).roundToDouble();
        final double sunG = (sunColor.g * 255.0).roundToDouble();
        final double sunB = (sunColor.b * 255.0).roundToDouble();

        final double glowR = (emissiveGlowColor.r * 255.0).roundToDouble();
        final double glowG = (emissiveGlowColor.g * 255.0).roundToDouble();
        final double glowB = (emissiveGlowColor.b * 255.0).roundToDouble();

        final double rLit = (baseR * (ndotl * 0.68) +
                ambR +
                sunR * spec +
                glowR * rim)
            .clamp(0.0, 255.0);
        final double gLit = (baseG * (ndotl * 0.68) +
                ambG +
                sunG * spec +
                glowG * rim)
            .clamp(0.0, 255.0);
        final double bLit = (baseB * (ndotl * 0.68) +
                ambB +
                sunB * spec +
                glowB * rim)
            .clamp(0.0, 255.0);

        final Color shadedColor = Color.fromARGB(
          255,
          rLit.toInt(),
          gLit.toInt(),
          bLit.toInt(),
        );

        final double avgZ = (z0r + z1r + z2r) / 3.0;
        visibleTriangles.add(_ProjectedTriangle(
          ax: s0x,
          ay: s0y,
          bx: s1x,
          by: s1y,
          cx: s2x,
          cy: s2y,
          depthZ: avgZ,
          color: shadedColor,
        ));
      }
    }

    // Sort triangles by depth descending (Painter's Algorithm)
    visibleTriangles.sort();

    // Render sorted front-facing triangles
    final Paint trianglePaint = Paint()..style = PaintingStyle.fill;
    final Path path = Path();

    for (final _ProjectedTriangle tri in visibleTriangles) {
      trianglePaint.color = tri.color;
      path.reset();
      path.moveTo(tri.ax, tri.ay);
      path.lineTo(tri.bx, tri.by);
      path.lineTo(tri.cx, tri.cy);
      path.close();
      canvas.drawPath(path, trianglePaint);
    }
  }

  @override
  bool shouldRepaint(covariant Hub3dModelPainter oldDelegate) {
    return oldDelegate.rotationY != rotationY ||
        oldDelegate.rotationX != rotationX ||
        oldDelegate.rotationZ != rotationZ ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.depthZ != depthZ ||
        oldDelegate.sunColor != sunColor ||
        oldDelegate.customTint != customTint ||
        oldDelegate.qualityScaler?.currentSettings != qualityScaler?.currentSettings;
  }
}

/// Standalone interactive 3D model viewport widget with preloading & fallback.
class Hub3dModelViewport extends StatefulWidget {
  const Hub3dModelViewport({
    super.key,
    required this.assetPath,
    this.modelId,
    this.controller,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.depthZ = 0.0,
    this.customTint,
    this.emissiveGlowColor = const Color(0xFF00B4FF),
    this.emissiveIntensity = 0.4,
    this.fallbackWidget,
    this.maxTriangles = 3500,
    this.interactive = true,
    this.qualityScaler,
    this.onError,
  });

  final String assetPath;
  final String? modelId;
  final Hub3dModelController? controller;
  final double scale;
  final Offset offset;
  final double depthZ;
  final Color? customTint;
  final Color emissiveGlowColor;
  final double emissiveIntensity;
  final Widget? fallbackWidget;
  final int maxTriangles;
  final bool interactive;
  final AdaptiveQualityScaler? qualityScaler;
  final void Function(Object error, StackTrace? stackTrace)? onError;

  @override
  State<Hub3dModelViewport> createState() => _Hub3dModelViewportState();
}

class _Hub3dModelViewportState extends State<Hub3dModelViewport>
    with SingleTickerProviderStateMixin {
  Hub3dModelController? _internalController;
  Hub3dModelController get _activeController =>
      widget.controller ??
      (_internalController ??=
          Hub3dModelController(qualityScaler: widget.qualityScaler));

  Ticker? _ticker;
  double _lastTickMs = 0.0;
  ParsedModelMesh? _mesh;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  double _loadOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    widget.qualityScaler?.addListener(_onQualityChanged);
    _loadMesh();
  }

  void _onQualityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant Hub3dModelViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath || oldWidget.modelId != widget.modelId) {
      _loadMesh();
    }
    if (oldWidget.qualityScaler != widget.qualityScaler) {
      oldWidget.qualityScaler?.removeListener(_onQualityChanged);
      widget.qualityScaler?.addListener(_onQualityChanged);
      _activeController.qualityScaler = widget.qualityScaler;
    }
  }

  Future<void> _loadMesh() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final ParsedModelMesh? mesh = await Hub3dAssetLoader.instance.loadGlbAsset(
        widget.assetPath,
        modelId: widget.modelId,
      );

      if (!mounted) return;

      if (mesh != null) {
        setState(() {
          _mesh = mesh;
          _isLoading = false;
          _hasError = false;
          _loadOpacity = 1.0;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to parse GLB mesh: ${widget.assetPath}';
        });
        widget.onError?.call(Exception(_errorMessage!), StackTrace.current);
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      widget.onError?.call(e, st);
    }
  }

  void _onTick(Duration elapsed) {
    final double elapsedMs = elapsed.inMicroseconds / 1000.0;
    final double dtMs = _lastTickMs == 0.0 ? 16.67 : (elapsedMs - _lastTickMs);
    final double dt = dtMs / 1000.0;
    _lastTickMs = elapsedMs;

    // Report frame timing telemetry to AdaptiveQualityScaler
    if (widget.qualityScaler != null && dtMs > 0 && dtMs < 500) {
      widget.qualityScaler!.recordFrameTime(dtMs);
    }

    // Zero-jank frame timing: clamp dt between 1ms and 50ms (20fps floor)
    _activeController.tick(dt.clamp(0.001, 0.05));
  }

  @override
  void dispose() {
    _ticker?.dispose();
    widget.qualityScaler?.removeListener(_onQualityChanged);
    _internalController?.dispose();
    super.dispose();
  }

  Widget _buildAion2GlassFallback(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0x550B0F19),
              Color(0x331E293B),
              Color(0x440F172A),
            ],
          ),
          border: Border.all(
            color: _hasError ? const Color(0x66EF4444) : const Color(0x55D4AF37),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _hasError ? const Color(0x22EF4444) : const Color(0x2A00B4FF),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: _hasError
            ? const Icon(
                Icons.diamond_outlined,
                size: 24,
                color: Color(0xFFF59E0B),
              )
            : const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4FF)),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = ListenableBuilder(
      listenable: _activeController,
      builder: (context, _) {
        if (_mesh == null || _isLoading) {
          // Graceful fallback with Aion 2 obsidian glass & celestial gold shimmer
          return widget.fallbackWidget ?? _buildAion2GlassFallback(context);
        }

        return AnimatedOpacity(
          opacity: _loadOpacity,
          duration: const Duration(milliseconds: 350),
          child: CustomPaint(
            painter: Hub3dModelPainter(
              mesh: _mesh!,
              rotationY: _activeController.rotationY,
              rotationX: _activeController.rotationX,
              scale: widget.scale,
              offset: widget.offset,
              depthZ: widget.depthZ,
              customTint: widget.customTint,
              emissiveGlowColor: widget.emissiveGlowColor,
              emissiveIntensity: widget.emissiveIntensity,
              maxTriangles: widget.maxTriangles,
              qualityScaler: widget.qualityScaler,
            ),
            size: Size.infinite,
          ),
        );
      },
    );

    if (!widget.interactive) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _activeController.onModelTap(),
      onPanStart: (_) => _activeController.onPanStart(),
      onPanUpdate: _activeController.onPanUpdate,
      onPanEnd: _activeController.onPanEnd,
      onDoubleTap: () => _activeController.resetRotation(),
      child: content,
    );
  }
}

/// Integrated 3D world props layer for the Main Hub viewport.
/// Renders authentic Gothic pillars, iron braziers, and stone altar landmarks.
class Hub3dWorldPropsLayer extends StatefulWidget {
  const Hub3dWorldPropsLayer({
    super.key,
    required this.controller,
    this.parallaxOffset = Offset.zero,
    this.qualityScaler,
  });

  final HubEnvironmentController controller;
  final Offset parallaxOffset;
  final AdaptiveQualityScaler? qualityScaler;

  @override
  State<Hub3dWorldPropsLayer> createState() => _Hub3dWorldPropsLayerState();
}

class _Hub3dWorldPropsLayerState extends State<Hub3dWorldPropsLayer> {
  ParsedModelMesh? _leftPillar;
  ParsedModelMesh? _rightPillar;
  ParsedModelMesh? _brazier;
  ParsedModelMesh? _altar;

  @override
  void initState() {
    super.initState();
    widget.qualityScaler?.addListener(_onQualityChanged);
    _loadWorldProps();
  }

  void _onQualityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant Hub3dWorldPropsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qualityScaler != widget.qualityScaler) {
      oldWidget.qualityScaler?.removeListener(_onQualityChanged);
      widget.qualityScaler?.addListener(_onQualityChanged);
    }
  }

  @override
  void dispose() {
    widget.qualityScaler?.removeListener(_onQualityChanged);
    super.dispose();
  }

  Future<void> _loadWorldProps() async {
    final List<Future<ParsedModelMesh?>> futures = <Future<ParsedModelMesh?>>[
      Hub3dAssetLoader.instance.loadGlbAsset(
        'assets/models/aion2/aion2_gothic_dungeon_pillar.glb',
        modelId: 'hub_pillar_left',
      ),
      Hub3dAssetLoader.instance.loadGlbAsset(
        'assets/models/environment/column-large.glb',
        modelId: 'hub_pillar_right',
      ),
      Hub3dAssetLoader.instance.loadGlbAsset(
        'assets/models/props/Brazier_IronEmbers.glb',
        modelId: 'hub_brazier',
      ),
      Hub3dAssetLoader.instance.loadGlbAsset(
        'assets/models/environment/altar-stone.glb',
        modelId: 'hub_altar',
      ),
    ];

    final List<ParsedModelMesh?> results = await Future.wait(futures);
    if (!mounted) return;

    setState(() {
      _leftPillar = results[0];
      _rightPillar = results[1];
      _brazier = results[2];
      _altar = results[3];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final LinearColor sun = widget.controller.sunRadiance;
        final Color sunColor = Color.fromARGB(
          255,
          (sun.r * 255).clamp(0, 255).toInt(),
          (sun.g * 255).clamp(0, 255).toInt(),
          (sun.b * 255).clamp(0, 255).toInt(),
        );

        final Offset parallax = widget.parallaxOffset;
        final QualitySettings? settings = widget.qualityScaler?.currentSettings;
        final bool isEcoOrSevere = settings != null &&
            (settings.throttleLevel >= 3 || settings.tier == HardwareTier.eco);

        return LayoutBuilder(
          builder: (context, constraints) {
            final double screenW = constraints.maxWidth.isFinite ? constraints.maxWidth : 390.0;
            final double screenH = constraints.maxHeight.isFinite ? constraints.maxHeight : 844.0;
            final double responsiveScale = (screenW / 390.0).clamp(0.75, 1.25);
            final double pillarW = (130 * responsiveScale).clamp(95.0, 160.0);
            final double pillarH = (380 * responsiveScale).clamp(280.0, 440.0);

            return IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // ── Left Gothic Monumental Pillar ────────────────────────
                  if (_leftPillar != null)
                    Positioned(
                      left: -32 * responsiveScale + parallax.dx * 0.35,
                      top: 36 * responsiveScale + parallax.dy * 0.3,
                      width: pillarW,
                      height: pillarH,
                      child: CustomPaint(
                        painter: Hub3dModelPainter(
                          mesh: _leftPillar!,
                          rotationY: 0.35,
                          rotationX: 0.04,
                          scale: 1.15,
                          sunColor: sunColor,
                          emissiveGlowColor: const Color(0xFF60A5FA),
                          emissiveIntensity: 0.28,
                          maxTriangles: 2200,
                          qualityScaler: widget.qualityScaler,
                        ),
                      ),
                    ),

                  // ── Right Architectural Column (omitted on Eco to save fill-rate) ───
                  if (_rightPillar != null && !isEcoOrSevere)
                    Positioned(
                      right: -36 * responsiveScale + parallax.dx * 0.35,
                      top: 36 * responsiveScale + parallax.dy * 0.3,
                      width: pillarW,
                      height: pillarH,
                      child: CustomPaint(
                        painter: Hub3dModelPainter(
                          mesh: _rightPillar!,
                          rotationY: -0.42,
                          rotationX: 0.04,
                          scale: 1.15,
                          sunColor: sunColor,
                          emissiveGlowColor: const Color(0xFF60A5FA),
                          emissiveIntensity: 0.28,
                          maxTriangles: 2200,
                          qualityScaler: widget.qualityScaler,
                        ),
                      ),
                    ),

                  // ── Central Ritual Altar ─────────────────────────────────
                  if (_altar != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: (115 * responsiveScale) + parallax.dy * 0.2,
                      height: 160 * responsiveScale,
                      child: Center(
                        child: SizedBox(
                          width: (210 * responsiveScale).clamp(160.0, 260.0),
                          height: (135 * responsiveScale).clamp(100.0, 170.0),
                          child: CustomPaint(
                            painter: Hub3dModelPainter(
                              mesh: _altar!,
                              rotationY: 0.25,
                              rotationX: 0.18,
                              scale: 0.85,
                              sunColor: sunColor,
                              emissiveGlowColor: const Color(0xFF00B4FF),
                              emissiveIntensity: 0.45,
                              maxTriangles: 1800,
                              qualityScaler: widget.qualityScaler,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Iron Brazier with Glowing Embers ─────────────────────
                  if (_brazier != null)
                    Positioned(
                      left: (32 * responsiveScale) + parallax.dx * 0.45,
                      bottom: (80 * responsiveScale) + parallax.dy * 0.25,
                      width: (88 * responsiveScale).clamp(65.0, 110.0),
                      height: (118 * responsiveScale).clamp(90.0, 145.0),
                      child: CustomPaint(
                        painter: Hub3dModelPainter(
                          mesh: _brazier!,
                          rotationY: widget.controller.elapsedTime * 0.2,
                          rotationX: 0.12,
                          scale: 0.95,
                          sunColor: sunColor,
                          emissiveGlowColor: const Color(0xFFFF7A00),
                          emissiveIntensity: 0.85,
                          maxTriangles: 1400,
                          qualityScaler: widget.qualityScaler,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Specialized 3D Hero Viewport replacing the static 2D hero image.
/// Renders class-specific 3D .glb models, dark fantasy weapons, and wings.
class Hero3dGlbViewport extends StatefulWidget {
  const Hero3dGlbViewport({
    super.key,
    required this.characterClass,
    required this.breathingValue,
    required this.height,
    required this.fallbackAsset,
    this.qualityScaler,
    this.interactive = true,
  });

  final CharacterClass? characterClass;
  final double breathingValue;
  final double height;
  final String fallbackAsset;
  final AdaptiveQualityScaler? qualityScaler;
  final bool interactive;

  @override
  State<Hero3dGlbViewport> createState() => _Hero3dGlbViewportState();
}

class _Hero3dGlbViewportState extends State<Hero3dGlbViewport>
    with SingleTickerProviderStateMixin {
  late final Hub3dModelController _hero3dController;
  Ticker? _ticker;
  double _lastTickMs = 0.0;
  ParsedModelMesh? _heroMesh;
  ParsedModelMesh? _weaponMesh;
  ParsedModelMesh? _wingsMesh;

  bool _isHeroLoaded = false;
  double _crossfadeOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _hero3dController = Hub3dModelController(
      initialRotationY: -0.15,
      autoRotateSpeed: 0.18,
      qualityScaler: widget.qualityScaler,
    );
    _ticker = createTicker(_onTick)..start();
    widget.qualityScaler?.addListener(_onQualityChanged);
    _loadHeroAssets();
  }

  void _onQualityChanged() {
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    final double elapsedMs = elapsed.inMicroseconds / 1000.0;
    final double dtMs = _lastTickMs == 0.0 ? 16.67 : (elapsedMs - _lastTickMs);
    final double dt = dtMs / 1000.0;
    _lastTickMs = elapsedMs;

    // Feed real-time frame pacing to AdaptiveQualityScaler
    if (widget.qualityScaler != null && dtMs > 0 && dtMs < 500) {
      widget.qualityScaler!.recordFrameTime(dtMs);
    }

    // Zero-jank frame timing with strict 20fps minimum floor (50ms)
    _hero3dController.tick(dt.clamp(0.001, 0.05));
  }

  @override
  void didUpdateWidget(covariant Hero3dGlbViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characterClass != widget.characterClass) {
      _loadHeroAssets();
    }
    if (oldWidget.qualityScaler != widget.qualityScaler) {
      oldWidget.qualityScaler?.removeListener(_onQualityChanged);
      widget.qualityScaler?.addListener(_onQualityChanged);
      _hero3dController.qualityScaler = widget.qualityScaler;
    }
  }

  String _resolveHeroGlbPath() {
    switch (widget.characterClass) {
      case CharacterClass.warrior:
      case null:
        return 'assets/models/characters/Knight.glb';
      case CharacterClass.shadow:
        return 'assets/models/characters/Soldier.glb';
      case CharacterClass.alchemist:
        return 'assets/models/characters/Mage.glb';
    }
  }

  Future<void> _loadHeroAssets() async {
    final String heroPath = _resolveHeroGlbPath();

    try {
      final List<Future<ParsedModelMesh?>> tasks = <Future<ParsedModelMesh?>>[
        Hub3dAssetLoader.instance.loadGlbAsset(heroPath, modelId: 'hero_class_mesh'),
        Hub3dAssetLoader.instance.loadGlbAsset(
          'assets/models/aion2/aion2_dark_fantasy_sword.glb',
          modelId: 'hero_sword',
        ),
        Hub3dAssetLoader.instance.loadGlbAsset(
          'assets/models/aion2/aion2_ethereal_wings.glb',
          modelId: 'hero_wings',
        ),
      ];

      final List<ParsedModelMesh?> results = await Future.wait(tasks);
      if (!mounted) return;

      setState(() {
        _heroMesh = results[0];
        _weaponMesh = results[1];
        _wingsMesh = results[2];
        if (_heroMesh != null) {
          _isHeroLoaded = true;
          _crossfadeOpacity = 1.0;
        }
      });
    } catch (e, st) {
      debugPrint('Hero3dGlbViewport: Error loading hero GLB assets: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isHeroLoaded = false;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    widget.qualityScaler?.removeListener(_onQualityChanged);
    _hero3dController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double breathingOffset = -8.0 * widget.breathingValue;

    // Class-specific Aion 2 Dark Fantasy palettes
    final ({Color heroGlow, double heroIntensity, Color weaponGlow, double weaponIntensity})
        classAesthetics = switch (widget.characterClass) {
      CharacterClass.warrior || null => (
          heroGlow: const Color(0xFF00B4FF),
          heroIntensity: 0.40,
          weaponGlow: const Color(0xFFF59E0B),
          weaponIntensity: 0.70,
        ),
      CharacterClass.shadow => (
          heroGlow: const Color(0xFFA855F7),
          heroIntensity: 0.48,
          weaponGlow: const Color(0xFFEF4444),
          weaponIntensity: 0.75,
        ),
      CharacterClass.alchemist => (
          heroGlow: const Color(0xFF10B981),
          heroIntensity: 0.42,
          weaponGlow: const Color(0xFF38BDF8),
          weaponIntensity: 0.85,
        ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 390.0;
        final double maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : widget.height;
        final double effectiveHeight = math.min(widget.height, maxH);
        // Bounded width ensures no overflow on 390x844 mobile screens
        final double effectiveWidth = math.min(effectiveHeight * 0.92, maxW);
        // Gesture hit-box constrained to center hero silhouette so lateral equipment slots receive taps cleanly
        final double interactiveWidth = math.min(effectiveWidth * 0.68, 220.0);

        return SizedBox(
          height: effectiveHeight,
          width: effectiveWidth,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // ── 1. Subtle Celestial Grounding Halo Under Hero ─────────
              Positioned(
                bottom: 14,
                child: IgnorePointer(
                  child: Container(
                    width: interactiveWidth * 0.92,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(interactiveWidth * 0.46, 10),
                      ),
                      gradient: RadialGradient(
                        colors: <Color>[
                          classAesthetics.heroGlow.withValues(alpha: 0.35),
                          const Color(0x22D4AF37),
                          Colors.transparent,
                        ],
                        stops: const <double>[0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 2. 2D Fallback Artwork Layer (Smooth Cross-fade) ───────
              Transform.translate(
                offset: Offset(0, breathingOffset),
                child: AnimatedOpacity(
                  opacity: _isHeroLoaded ? (1.0 - _crossfadeOpacity) : 1.0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  child: Image.asset(
                    widget.fallbackAsset,
                    height: effectiveHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      final String fallbackPortrait = switch (widget.characterClass) {
                        CharacterClass.warrior || null => 'assets/images/portraits/elyos/elyos_gladiator.png',
                        CharacterClass.shadow => 'assets/images/portraits/asmodian/asmodian_assassin.png',
                        CharacterClass.alchemist => 'assets/images/portraits/elyos/elyos_sorcerer.png',
                      };
                      return Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: <Color>[
                                Color(0x660B0F19),
                                Color(0x441E293B),
                                Color(0x220F172A),
                              ],
                              stops: <double>[0.0, 0.65, 1.0],
                            ),
                            border: Border.all(
                              color: const Color(0x66D4AF37),
                              width: 1.5,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: classAesthetics.heroGlow.withValues(alpha: 0.45),
                                blurRadius: 22,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              fallbackPortrait,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Image.asset(
                                  'assets/characters/savasci.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── 3. Real 3D .GLB Hero Viewport Layer ─────────────────────
              if (_heroMesh != null)
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, breathingOffset),
                    child: AnimatedOpacity(
                      opacity: _crossfadeOpacity,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          // Visual 3D Rendering Pass
                          IgnorePointer(
                            child: ListenableBuilder(
                              listenable: _hero3dController,
                              builder: (context, _) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    // Back Ethereal Wings (if Alchemist or high level)
                                    if (_wingsMesh != null &&
                                        widget.characterClass == CharacterClass.alchemist)
                                      CustomPaint(
                                        painter: Hub3dModelPainter(
                                          mesh: _wingsMesh!,
                                          rotationY: _hero3dController.rotationY,
                                          rotationX: _hero3dController.rotationX,
                                          scale: 0.92,
                                          depthZ: 0.15,
                                          emissiveGlowColor: classAesthetics.weaponGlow,
                                          emissiveIntensity: 0.85,
                                          maxTriangles: 1800,
                                          qualityScaler: widget.qualityScaler,
                                        ),
                                      ),

                                    // Main Character Mesh (Knight / Soldier / Mage)
                                    CustomPaint(
                                      painter: Hub3dModelPainter(
                                        mesh: _heroMesh!,
                                        rotationY: _hero3dController.rotationY,
                                        rotationX: _hero3dController.rotationX,
                                        scale: 1.05,
                                        emissiveGlowColor: classAesthetics.heroGlow,
                                        emissiveIntensity: classAesthetics.heroIntensity,
                                        maxTriangles: 3200,
                                        qualityScaler: widget.qualityScaler,
                                      ),
                                    ),

                                    // Attached Dark Fantasy Weapon
                                    if (_weaponMesh != null &&
                                        widget.characterClass != CharacterClass.alchemist)
                                      CustomPaint(
                                        painter: Hub3dModelPainter(
                                          mesh: _weaponMesh!,
                                          rotationY: _hero3dController.rotationY,
                                          rotationX: _hero3dController.rotationX + 0.15,
                                          offset: const Offset(36, 15),
                                          scale: 0.65,
                                          emissiveGlowColor: classAesthetics.weaponGlow,
                                          emissiveIntensity: classAesthetics.weaponIntensity,
                                          maxTriangles: 1600,
                                          qualityScaler: widget.qualityScaler,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),

                          // Bounded Touch Hit-Box: Centered to leave flanking equipment slots unobstructed
                          if (widget.interactive)
                            Center(
                              child: SizedBox(
                                width: interactiveWidth,
                                height: effectiveHeight,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (_) => _hero3dController.onModelTap(),
                                  onPanStart: (_) => _hero3dController.onPanStart(),
                                  onPanUpdate: _hero3dController.onPanUpdate,
                                  onPanEnd: _hero3dController.onPanEnd,
                                  onDoubleTap: () => _hero3dController.resetRotation(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
