import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/assets/mesh_asset_registry.dart';
import '../../../theme/app_colors.dart';
import 'facility_3d_model_resolver.dart';

// =============================================================================
// FACILITY 3D TURNTABLE VIEWPORT (2027 AION 2 MOBILE STANDARD)
// Real 3D .glb building inspection, smooth 360-degree rotation, pinch-zoom,
// concentric runic dais, atmospheric floating motes, and tier-based aura.
// =============================================================================

/// Shading visualization mode for the 3D facility viewport.
enum Facility3dShadingMode {
  pbrLit,
  wireframe,
  runicSilhouette,
}

/// Interactive 3D Viewport displaying high-fidelity facility buildings.
class Facility3dViewport extends StatefulWidget {
  const Facility3dViewport({
    super.key,
    required this.facilityType,
    this.level = 1,
    this.isProducing = false,
    this.height = 320,
    this.interactive = true,
    this.autoRotate = true,
    this.showControls = true,
    this.onTap,
  });

  /// Facility type string matching catalog keys.
  final String facilityType;

  /// Current facility tier level (1 to 10).
  final int level;

  /// Whether facility is actively running production.
  final bool isProducing;

  /// Viewport vertical height.
  final double height;

  /// Whether touch orbit and gestures are enabled.
  final bool interactive;

  /// Whether the model slowly auto-rotates when untouched.
  final bool autoRotate;

  /// Whether to display mobile HUD controls.
  final bool showControls;

  /// Optional tap callback on viewport.
  final VoidCallback? onTap;

  @override
  State<Facility3dViewport> createState() => _Facility3dViewportState();
}

class _Facility3dViewportState extends State<Facility3dViewport>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  // Turntable rotation angles in radians
  double _yaw = 0.0;
  double _pitch = 0.08;
  double _zoom = 1.0;
  double _baseZoom = 1.0;

  // Inertial velocity
  double _yawVelocity = 0.0;
  double _pitchVelocity = 0.0;
  bool _isInteracting = false;
  double _lastDetentAngle = 0.0;

  // Visual modes
  Facility3dShadingMode _shadingMode = Facility3dShadingMode.pbrLit;
  bool _autoRotateActive = true;
  int _previewLevelOffset = 0;

  // Model state
  ParsedModelMesh? _parsedMesh;
  bool _isLoadingMesh = false;
  String? _loadedFacilityType;

  @override
  void initState() {
    super.initState();
    _autoRotateActive = widget.autoRotate;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _animController.addListener(_onAnimationTick);
    _loadMeshForFacility();
  }

  @override
  void didUpdateWidget(covariant Facility3dViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facilityType != widget.facilityType) {
      _loadMeshForFacility();
    }
  }

  @override
  void dispose() {
    _animController.removeListener(_onAnimationTick);
    _animController.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    if (!mounted) return;

    // Inertial deceleration when finger released
    if (!_isInteracting && (_yawVelocity.abs() > 0.0001 || _pitchVelocity.abs() > 0.0001)) {
      setState(() {
        _yaw += _yawVelocity;
        _pitch = (_pitch + _pitchVelocity).clamp(-0.35, 0.45);
        _yawVelocity *= 0.90;
        _pitchVelocity *= 0.90;
      });
    }
  }

  Future<void> _loadMeshForFacility() async {
    final String targetType = widget.facilityType;
    if (_loadedFacilityType == targetType && _parsedMesh != null) return;

    _loadedFacilityType = targetType;
    if (mounted) {
      setState(() {
        _isLoadingMesh = true;
      });
    }

    final Facility3dStructureSpec spec = Facility3dCatalog.getSpec(targetType);
    final ParsedModelMesh? mesh =
        await FacilityModelMeshLoader.instance.loadFacilityMesh(spec);

    if (mounted && _loadedFacilityType == targetType) {
      setState(() {
        _isLoadingMesh = false;
        _parsedMesh = mesh;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // TOUCH GESTURES (ORBIT & PINCH-ZOOM)
  // ---------------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.interactive) return;
    setState(() {
      _isInteracting = true;
      _baseZoom = _zoom;
      _yawVelocity = 0.0;
      _pitchVelocity = 0.0;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.interactive) return;
    setState(() {
      // Rotation delta
      final double deltaX = details.focalPointDelta.dx * 0.015;
      final double deltaY = details.focalPointDelta.dy * 0.010;

      _yaw += deltaX;
      _pitch = (_pitch - deltaY).clamp(-0.35, 0.45);

      _yawVelocity = deltaX * 0.75;
      _pitchVelocity = -deltaY * 0.75;

      // Pinch zoom
      if (details.scale != 1.0) {
        _zoom = (_baseZoom * details.scale).clamp(0.65, 2.2);
      }

      // Detent haptic vibration every 90 degrees
      if ((_yaw - _lastDetentAngle).abs() > (math.pi / 2)) {
        _lastDetentAngle = _yaw;
        HapticFeedback.selectionClick();
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!widget.interactive) return;
    setState(() {
      _isInteracting = false;
    });
  }

  void _resetCamera() {
    HapticFeedback.lightImpact();
    setState(() {
      _yaw = 0.0;
      _pitch = 0.08;
      _zoom = 1.0;
      _yawVelocity = 0.0;
      _pitchVelocity = 0.0;
    });
  }

  void _toggleAutoRotate() {
    HapticFeedback.selectionClick();
    setState(() {
      _autoRotateActive = !_autoRotateActive;
    });
  }

  void _cycleShadingMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _shadingMode = switch (_shadingMode) {
        Facility3dShadingMode.pbrLit => Facility3dShadingMode.wireframe,
        Facility3dShadingMode.wireframe => Facility3dShadingMode.runicSilhouette,
        Facility3dShadingMode.runicSilhouette => Facility3dShadingMode.pbrLit,
      };
    });
  }

  void _cyclePreviewLevel() {
    HapticFeedback.selectionClick();
    setState(() {
      // Toggle between actual level and simulated max tier visual preview
      _previewLevelOffset = _previewLevelOffset == 0 ? 5 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Facility3dStructureSpec spec = Facility3dCatalog.getSpec(widget.facilityType);
    final int effectiveLevel = (widget.level + _previewLevelOffset).clamp(1, 10);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.carbonVoid.withValues(alpha: 0.95),
            AppColors.spaceNavy.withValues(alpha: 0.90),
            AppColors.carbonVoid,
          ],
        ),
        border: Border.all(
          color: spec.accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: spec.accentColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // 3D Canvas with touch gestures
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onDoubleTap: _resetCamera,
              onTap: widget.onTap,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (BuildContext ctx, Widget? child) {
                  // Auto-rotation idle loop
                  final double idleYaw = (_autoRotateActive && !_isInteracting)
                      ? _yaw + (_animController.value * 2 * math.pi)
                      : _yaw;

                  final double idlePitch = _isInteracting
                      ? _pitch
                      : _pitch + math.sin(_animController.value * 2 * math.pi) * 0.012;

                  return CustomPaint(
                    size: Size(double.infinity, widget.height),
                    painter: _Facility3dPainter(
                      spec: spec,
                      level: effectiveLevel,
                      isProducing: widget.isProducing,
                      yaw: idleYaw,
                      pitch: idlePitch,
                      zoom: _zoom,
                      animValue: _animController.value,
                      shadingMode: _shadingMode,
                      parsedMesh: _parsedMesh,
                      isLoading: _isLoadingMesh,
                    ),
                  );
                },
              ),
            ),

            // Top Header: Structure Title & Badges
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.darkObsidian.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: spec.accentColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          spec.runicGlyph,
                          style: TextStyle(
                            fontSize: 14,
                            color: spec.emissiveColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          spec.structureTitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: spec.accentColor.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: spec.accentColor.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Lv.$effectiveLevel${_previewLevelOffset > 0 ? " (Önizleme)" : ""}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: spec.emissiveColor,
                      ),
                    ),
                  ),
                  if (widget.isProducing) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.toxicNeon.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.toxicNeon.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const Text(
                        '● ÜRETİMDE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: AppColors.toxicNeon,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Bottom Controls Bar (if enabled)
            if (widget.showControls)
              Positioned(
                bottom: 8,
                left: 10,
                right: 10,
                child: Row(
                  children: <Widget>[
                    // 3D Model Info Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.darkObsidian.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.mutedTitanium.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.view_in_ar,
                            size: 12,
                            color: spec.accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _parsedMesh != null
                                ? 'PBR 3D .GLB • ${_parsedMesh!.totalTriangles} Poligon'
                                : (_isLoadingMesh ? 'Yükleniyor...' : 'CC0 3D Model'),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedTitanium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Shading Mode Button
                    _ControlButton(
                      icon: _shadingMode == Facility3dShadingMode.pbrLit
                          ? Icons.light_mode
                          : (_shadingMode == Facility3dShadingMode.wireframe
                              ? Icons.grid_3x3
                              : Icons.auto_awesome),
                      tooltip: 'Gölgelendirme',
                      accentColor: spec.accentColor,
                      onTap: _cycleShadingMode,
                    ),
                    const SizedBox(width: 6),

                    // Level Preview Boost Button
                    _ControlButton(
                      icon: Icons.upgrade,
                      tooltip: 'Kademe Önizleme',
                      isActive: _previewLevelOffset > 0,
                      accentColor: spec.emissiveColor,
                      onTap: _cyclePreviewLevel,
                    ),
                    const SizedBox(width: 6),

                    // Auto-Rotate Button
                    _ControlButton(
                      icon: _autoRotateActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      tooltip: 'Döndürme',
                      isActive: _autoRotateActive,
                      accentColor: spec.accentColor,
                      onTap: _toggleAutoRotate,
                    ),
                    const SizedBox(width: 6),

                    // Reset Camera Button
                    _ControlButton(
                      icon: Icons.restart_alt,
                      tooltip: 'Sıfırla',
                      accentColor: spec.accentColor,
                      onTap: _resetCamera,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.accentColor,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive
                ? accentColor.withValues(alpha: 0.25)
                : AppColors.darkObsidian.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? accentColor
                  : AppColors.mutedTitanium.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 15,
            color: isActive ? accentColor : AppColors.mutedTitanium,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 3D REAL-TIME RASTERIZER & AION-2 DAIS PAINTER
// =============================================================================

class _Facility3dPainter extends CustomPainter {
  _Facility3dPainter({
    required this.spec,
    required this.level,
    required this.isProducing,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.animValue,
    required this.shadingMode,
    required this.parsedMesh,
    required this.isLoading,
  });

  final Facility3dStructureSpec spec;
  final int level;
  final bool isProducing;
  final double yaw;
  final double pitch;
  final double zoom;
  final double animValue;
  final Facility3dShadingMode shadingMode;
  final ParsedModelMesh? parsedMesh;
  final bool isLoading;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.58);

    // 1. Draw Runic Pedestal Dais with Perspective Foreshortening
    _paintRunicPedestalDais(canvas, size, center);

    // 2. Draw Floating Atmospheric Embers / Motes
    _paintAtmosphericMotes(canvas, size, center);

    // 3. Render 3D .GLB Model Geometry
    bool renderedGeometry = false;
    if (parsedMesh != null && parsedMesh!.submeshes.isNotEmpty) {
      renderedGeometry = _render3dMesh(canvas, size, center);
    }

    // 4. Fallback: If 3D mesh is loading or CPU buffers are deferred,
    // draw high-fidelity stylized runic architectural silhouette on the dais
    if (!renderedGeometry) {
      _paintRunicArchitecturalSilhouette(canvas, size, center);
    }

    // 5. Draw Production Pulse Ripple & Bloom Flare
    if (isProducing) {
      _paintProductionEnergyRipple(canvas, size, center);
    }
  }

  void _paintRunicPedestalDais(Canvas canvas, Size size, Offset center) {
    final double radius = size.width * 0.36 * zoom;
    final double daisY = center.dy + (size.height * 0.22);
    final Rect daisRect = Rect.fromCenter(
      center: Offset(center.dx, daisY),
      width: radius * 2.0,
      height: radius * 0.52,
    );

    // Dais Stone Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawOval(daisRect.translate(0, 8), shadowPaint);

    // Outer Runic Base Ring
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = spec.accentColor.withValues(alpha: 0.55);
    canvas.drawOval(daisRect, ringPaint);

    // Inner Concentric Energy Ring
    final Rect innerRect = Rect.fromCenter(
      center: Offset(center.dx, daisY),
      width: radius * 1.5,
      height: radius * 0.38,
    );
    final Paint innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = spec.emissiveColor.withValues(alpha: 0.70);
    canvas.drawOval(innerRect, innerPaint);

    // Additional Runic Rings for Higher Tiers / Levels
    if (level >= 4) {
      final Rect tierRingRect = Rect.fromCenter(
        center: Offset(center.dx, daisY),
        width: radius * 1.05,
        height: radius * 0.26,
      );
      final Paint tierPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = spec.emissiveColor.withValues(alpha: 0.85);
      canvas.drawOval(tierRingRect, tierPaint);
    }

    // Rotating Ancient Norse Runes along the perimeter
    const List<String> runes = <String>[
      'ᚠ', 'ᚢ', 'ᚦ', 'ᚨ', 'ᚱ', 'ᚲ', 'ᚷ', 'ᚹ', 'ᚺ', 'ᚾ', 'ᛁ', 'ᛃ'
    ];
    final double baseAngle = animValue * 2 * math.pi;

    for (int i = 0; i < runes.length; i++) {
      final double angle = baseAngle + (i * (2 * math.pi / runes.length));
      final double rx = center.dx + math.cos(angle) * (radius * 0.88);
      final double ry = daisY + math.sin(angle) * (radius * 0.22);

      // Depth alpha modulation
      final double depthAlpha = (math.sin(angle) + 1.2) / 2.2;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: runes[i],
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: spec.emissiveColor.withValues(alpha: (0.4 + 0.5 * depthAlpha).clamp(0.1, 1.0)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(rx - tp.width * 0.5, ry - tp.height * 0.5));
    }
  }

  void _paintAtmosphericMotes(Canvas canvas, Size size, Offset center) {
    final int moteCount = 14 + (level * 2);
    final Paint motePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < moteCount; i++) {
      final double seed = (i * 0.173 + animValue) % 1.0;
      final double angle = i * 2.399; // Golden angle
      final double radius = (size.width * 0.28) * math.sqrt((i + 1) / moteCount);

      final double px = center.dx + math.cos(angle + animValue * 0.5) * radius;
      final double py = (center.dy + size.height * 0.20) - (seed * size.height * 0.55);
      final double sizeMote = (1.2 + math.sin(seed * math.pi) * 1.8).clamp(0.5, 3.5);
      final double alpha = math.sin(seed * math.pi) * 0.75;

      motePaint.color = (i.isEven ? spec.emissiveColor : spec.accentColor)
          .withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(px, py), sizeMote, motePaint);
    }
  }

  bool _render3dMesh(Canvas canvas, Size size, Offset center) {
    final ParsedSubmesh prim = parsedMesh!.submeshes.firstWhere(
      (ParsedSubmesh s) => s.positions != null && s.indices != null,
      orElse: () => const ParsedSubmesh(
        name: '',
        vertexCount: 0,
        indexCount: 0,
        bounds: BoundingBox3D(minX: 0, minY: 0, minZ: 0, maxX: 0, maxY: 0, maxZ: 0),
      ),
    );

    if (prim.positions == null || prim.indices == null) {
      return false;
    }

    final Float32List pos = prim.positions!;
    final Uint32List ind = prim.indices!;
    final BoundingBox3D bounds = parsedMesh!.bounds;

    final double maxDim = bounds.maxDimension > 0.001 ? bounds.maxDimension : 1.0;
    final double targetHeight = size.height * 0.55 * zoom * spec.modelScale;
    final double scale = targetHeight / maxDim;

    final double bCenterX = bounds.centerX;
    final double bCenterY = bounds.centerY + (spec.verticalOffset * maxDim);
    final double bCenterZ = bounds.centerZ;

    // Camera setup
    const double cameraZ = 4.2;
    final double fov = size.height * 0.75;

    final double cosP = math.cos(pitch);
    final double sinP = math.sin(pitch);
    final double cosY = math.cos(yaw);
    final double sinY = math.sin(yaw);

    // Directional light vector (upper-front right)
    const double lx = 0.55;
    const double ly = 0.80;
    const double lz = 0.45;
    final double lLen = math.sqrt(lx * lx + ly * ly + lz * lz);
    final double nLx = lx / lLen;
    final double nLy = ly / lLen;
    final double nLz = lz / lLen;

    // Collect & depth sort visible triangles
    final int triCount = ind.length ~/ 3;
    final List<_ProjectedFacilityTriangle> triangles = <_ProjectedFacilityTriangle>[];

    for (int t = 0; t < triCount; t++) {
      final int i0 = ind[t * 3];
      final int i1 = ind[t * 3 + 1];
      final int i2 = ind[t * 3 + 2];

      if ((i0 * 3 + 2) >= pos.length ||
          (i1 * 3 + 2) >= pos.length ||
          (i2 * 3 + 2) >= pos.length) {
        continue;
      }

      // Vertices in scaled local space
      final double x0 = (pos[i0 * 3] - bCenterX) * scale;
      final double y0 = (pos[i0 * 3 + 1] - bCenterY) * scale;
      final double z0 = (pos[i0 * 3 + 2] - bCenterZ) * scale;

      final double x1 = (pos[i1 * 3] - bCenterX) * scale;
      final double y1 = (pos[i1 * 3 + 1] - bCenterY) * scale;
      final double z1 = (pos[i1 * 3 + 2] - bCenterZ) * scale;

      final double x2 = (pos[i2 * 3] - bCenterX) * scale;
      final double y2 = (pos[i2 * 3 + 1] - bCenterY) * scale;
      final double z2 = (pos[i2 * 3 + 2] - bCenterZ) * scale;

      // Project 3D points
      final _ProjectedPoint pt0 = _project(x0, y0, z0, cosP, sinP, cosY, sinY, cameraZ, fov, center);
      final _ProjectedPoint pt1 = _project(x1, y1, z1, cosP, sinP, cosY, sinY, cameraZ, fov, center);
      final _ProjectedPoint pt2 = _project(x2, y2, z2, cosP, sinP, cosY, sinY, cameraZ, fov, center);

      // Backface culling
      final double crossZ = (pt1.offset.dx - pt0.offset.dx) * (pt2.offset.dy - pt0.offset.dy) -
          (pt1.offset.dy - pt0.offset.dy) * (pt2.offset.dx - pt0.offset.dx);
      if (crossZ <= 0) continue;

      // Surface normal & lighting
      final double v1x = x1 - x0;
      final double v1y = y1 - y0;
      final double v1z = z1 - z0;
      final double v2x = x2 - x0;
      final double v2y = y2 - y0;
      final double v2z = z2 - z0;

      final double nx = v1y * v2z - v1z * v2y;
      final double ny = v1z * v2x - v1x * v2z;
      final double nz = v1x * v2y - v1y * v2x;
      final double nMag = math.sqrt(nx * nx + ny * ny + nz * nz);

      double diffuse = 0.40;
      if (nMag > 0.0001) {
        // Rotate normal by Yaw & Pitch
        final double rNx = nx / nMag;
        final double rNy = ny / nMag;
        final double rNz = nz / nMag;

        final double rotX = rNx * cosY - rNz * sinY;
        final double rotZ = rNx * sinY + rNz * cosY;
        final double rotY = rNy * cosP - rotZ * sinP;
        final double finalZ = rNy * sinP + rotZ * cosP;

        final double dot = (rotX * nLx + rotY * nLy + finalZ * nLz);
        diffuse = (0.28 + math.max(0.0, dot) * 0.72).clamp(0.2, 1.0);
      }

      final double avgZ = (pt0.z + pt1.z + pt2.z) / 3.0;
      triangles.add(
        _ProjectedFacilityTriangle(
          p0: pt0.offset,
          p1: pt1.offset,
          p2: pt2.offset,
          depthZ: avgZ,
          diffuse: diffuse,
        ),
      );
    }

    // Depth sort (painter's algorithm)
    triangles.sort((_ProjectedFacilityTriangle a, _ProjectedFacilityTriangle b) =>
        b.depthZ.compareTo(a.depthZ));

    // Render triangles according to shading mode
    final Paint facePaint = Paint()..style = PaintingStyle.fill;
    final Paint edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = spec.emissiveColor.withValues(alpha: 0.65);

    for (final _ProjectedFacilityTriangle tri in triangles) {
      final Path path = Path()
        ..moveTo(tri.p0.dx, tri.p0.dy)
        ..lineTo(tri.p1.dx, tri.p1.dy)
        ..lineTo(tri.p2.dx, tri.p2.dy)
        ..close();

      if (shadingMode == Facility3dShadingMode.wireframe) {
        canvas.drawPath(path, edgePaint);
      } else {
        // PBR lit shading with tier accent tint
        final Color litColor = _calculateLitColor(tri.diffuse);
        facePaint.color = litColor;
        canvas.drawPath(path, facePaint);

        // Subtle specular edge highlight
        if (tri.diffuse > 0.75) {
          final Paint highlightPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = spec.emissiveColor.withValues(alpha: (tri.diffuse - 0.70) * 0.8);
          canvas.drawPath(path, highlightPaint);
        }
      }
    }

    return triangles.isNotEmpty;
  }

  _ProjectedPoint _project(
    double x,
    double y,
    double z,
    double cosP,
    double sinP,
    double cosY,
    double sinY,
    double cameraZ,
    double fov,
    Offset center,
  ) {
    // 1. Yaw rotation (Y-axis)
    final double x1 = x * cosY - z * sinY;
    final double z1 = x * sinY + z * cosY;

    // 2. Pitch rotation (X-axis)
    final double y2 = y * cosP - z1 * sinP;
    final double z2 = y * sinP + z1 * cosP;

    // 3. Perspective projection
    final double depth = cameraZ + (z2 * 0.0035);
    final double safeDepth = depth > 0.1 ? depth : 0.1;
    final double projX = center.dx + (x1 / safeDepth) * (fov / 280);
    final double projY = center.dy - (y2 / safeDepth) * (fov / 280);

    return _ProjectedPoint(Offset(projX, projY), z2);
  }

  Color _calculateLitColor(double diffuse) {
    final HSLColor base = HSLColor.fromColor(spec.accentColor);
    final double lightness = (base.lightness * (0.45 + diffuse * 0.55)).clamp(0.08, 0.95);
    final double saturation = (base.saturation * (0.75 + diffuse * 0.25)).clamp(0.2, 1.0);
    return base.withLightness(lightness).withSaturation(saturation).toColor();
  }

  void _paintRunicArchitecturalSilhouette(Canvas canvas, Size size, Offset center) {
    // High-fidelity architectural silhouette with glowing runic glyph
    final double radius = size.width * 0.24 * zoom;
    final Rect emblemRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 10),
      width: radius * 1.8,
      height: radius * 1.8,
    );

    // Glowing aura backing
    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          spec.emissiveColor.withValues(alpha: 0.35),
          spec.accentColor.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(emblemRect);
    canvas.drawCircle(Offset(center.dx, center.dy - 10), radius * 1.1, auraPaint);

    // Central ancient runic glyph
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: spec.runicGlyph,
        style: TextStyle(
          fontSize: radius * 0.85,
          color: spec.emissiveColor,
          shadows: <Shadow>[
            Shadow(
              color: spec.emissiveColor.withValues(alpha: 0.8),
              blurRadius: 18,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(center.dx - tp.width * 0.5, center.dy - 10 - tp.height * 0.5),
    );
  }

  void _paintProductionEnergyRipple(Canvas canvas, Size size, Offset center) {
    final double ripplePhase = (animValue * 3.0) % 1.0;
    final double radius = (size.width * 0.20 + (ripplePhase * size.width * 0.22)) * zoom;
    final double daisY = center.dy + (size.height * 0.22);

    final Rect rippleRect = Rect.fromCenter(
      center: Offset(center.dx, daisY),
      width: radius * 2.0,
      height: radius * 0.52,
    );

    final Paint ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * (1.0 - ripplePhase)
      ..color = AppColors.toxicNeon.withValues(alpha: (1.0 - ripplePhase) * 0.85);

    canvas.drawOval(rippleRect, ripplePaint);
  }

  @override
  bool shouldRepaint(covariant _Facility3dPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.animValue != animValue ||
        oldDelegate.shadingMode != shadingMode ||
        oldDelegate.parsedMesh != parsedMesh ||
        oldDelegate.isLoading != isLoading ||
        oldDelegate.isProducing != isProducing ||
        oldDelegate.level != level;
  }
}

class _ProjectedPoint {
  const _ProjectedPoint(this.offset, this.z);
  final Offset offset;
  final double z;
}

class _ProjectedFacilityTriangle {
  const _ProjectedFacilityTriangle({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.depthZ,
    required this.diffuse,
  });

  final Offset p0;
  final Offset p1;
  final Offset p2;
  final double depthZ;
  final double diffuse;
}
