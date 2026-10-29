import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Configuration and state for a gothic dungeon torch.
class PrisonTorchConfig {
  const PrisonTorchConfig({
    required this.xFraction,
    required this.yFraction,
    this.baseRadius = 280.0,
    this.phaseShift = 0.0,
    this.isFacingRight = true,
    this.flameColor = const Color(0xFFFF9800),
    this.glowIntensity = 1.0,
    this.castShadows = true,
  });

  /// Horizontal position fraction (0.0 to 1.0) across viewport.
  final double xFraction;

  /// Vertical position fraction (0.0 to 1.0) across viewport.
  final double yFraction;

  /// Effective maximum radial light illumination radius.
  final double baseRadius;

  /// Phase shift for unsynchronized organic flickering between torches.
  final double phaseShift;

  /// Whether the torch mount faces rightward (into the room) or leftward.
  final bool isFacingRight;

  /// Dominant flame chroma tint.
  final Color flameColor;

  /// Multiplier for radiant light intensity.
  final double glowIntensity;

  /// Whether this torch casts projected bar shadows onto stone walls.
  final bool castShadows;
}

/// Configuration for prison fortress guard watchtower searchlight simulation.
class PrisonSearchlightConfig {
  const PrisonSearchlightConfig({
    this.xFraction = 0.50,
    this.yFraction = -0.05,
    this.baseAngle = math.pi * 0.5,
    this.sweepArc = 0.72,
    this.sweepPeriod = 7.0,
    this.beamLengthFraction = 1.35,
    this.beamSpreadAngle = 0.36,
    this.color = const Color(0x3880D8FF),
    this.isAlert = false,
    this.spotRadius = 90.0,
  });

  /// Horizontal emitter origin fraction.
  final double xFraction;

  /// Vertical emitter origin fraction (typically above or at ceiling top edge).
  final double yFraction;

  /// Central aiming angle in radians (pi/2 = straight down).
  final double baseAngle;

  /// Maximum angular sweep range in radians.
  final double sweepArc;

  /// Seconds for a full round-trip sweep cycle.
  final double sweepPeriod;

  /// Length of the light beam relative to diagonal viewport size.
  final double beamLengthFraction;

  /// Angular cone width in radians.
  final double beamSpreadAngle;

  /// Ethereal beam color (e.g. cold moonlight cyan or alarm crimson).
  final Color color;

  /// Whether searchlight is in rapid nervous jitter / prison break alarm mode.
  final bool isAlert;

  /// Radius of illuminated footprint ellipse where beam meets stone floor.
  final double spotRadius;
}

/// Configuration for cathedral/dungeon high transom window volumetric god-rays.
class PrisonGodRayConfig {
  const PrisonGodRayConfig({
    required this.originFraction,
    required this.rayAngle,
    this.rayWidth = 150.0,
    this.rayLength = 720.0,
    this.color = const Color(0x1870A5FF),
  });

  /// Emitter origin fraction across viewport.
  final Offset originFraction;

  /// Direction angle in radians.
  final double rayAngle;

  /// Transverse width of light beam.
  final double rayWidth;

  /// Penetration length of light shaft.
  final double rayLength;

  /// Color and opacity of the atmospheric haze shaft.
  final Color color;
}

/// A damp or wet stone patch on the floor/wall that catches specular torchlight glints.
class PrisonWetStonePatch {
  const PrisonWetStonePatch({
    required this.xFraction,
    required this.yFraction,
    required this.radiusX,
    required this.radiusY,
    this.rotation = 0.0,
    this.shimmerPhase = 0.0,
  });

  final double xFraction;
  final double yFraction;
  final double radiusX;
  final double radiusY;
  final double rotation;
  final double shimmerPhase;
}

/// An active rising ember spark emitted from torch flames.
class TorchEmber {
  TorchEmber({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.lifespan,
    required this.swayPhase,
  }) : age = 0.0;

  double x;
  double y;
  final double vx;
  final double vy;
  final double size;
  final double lifespan;
  double age;
  final double swayPhase;

  bool get isDead => age >= lifespan;
  double get progress => (age / lifespan).clamp(0.0, 1.0);
}

/// Airborne dungeon dust mote that illuminates when swept by searchlight beam.
class SearchlightDustMote {
  SearchlightDustMote({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.baseAlpha,
    required this.phase,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double size;
  final double baseAlpha;
  final double phase;
}

/// Primary widget that renders AAA Aion-2 gothic dungeon lighting:
/// dynamic multi-harmonic torchlight, watchtower searchlight sweep with Rayleigh
/// dust scattering, volumetric window god-rays, wet stone specular glints,
/// dynamic bar cast shadows, and claustrophobic ambient occlusion vignettes.
class PrisonLighting extends StatefulWidget {
  const PrisonLighting({
    super.key,
    required this.child,
    this.enabled = true,
    this.showWall = true,
    this.showTorches = true,
    this.showEmbers = true,
    this.showSearchlight = true,
    this.showGodRays = true,
    this.showWetStoneReflections = true,
    this.showBarShadows = true,
    this.ambientDarkness = 0.88,
    this.torches = defaultTorches,
    this.searchlight = defaultSearchlight,
    this.godRays = defaultGodRays,
    this.wetStonePatches = defaultWetStonePatches,
  });

  /// The child content (e.g. prison status cards and action buttons).
  final Widget child;

  /// Whether active torch flickering animations are running.
  final bool enabled;

  /// Whether procedural ashlar masonry stone blocks are painted in the background.
  final bool showWall;

  /// Whether physical wall sconces and flames are rendered on the perimeter.
  final bool showTorches;

  /// Whether rising ember motes are emitted from the torches.
  final bool showEmbers;

  /// Whether guard watchtower searchlight cone sweeps across the room.
  final bool showSearchlight;

  /// Whether volumetric god-rays pierce through high dungeon window apertures.
  final bool showGodRays;

  /// Whether damp stone patches reflect torchlight with specular shimmer.
  final bool showWetStoneReflections;

  /// Whether cell bars project dynamic cast shadows across stone surfaces.
  final bool showBarShadows;

  /// Ambient darkness baseline (0.0 = bright, 1.0 = pitch black dungeon).
  final double ambientDarkness;

  /// Position and properties of torches.
  final List<PrisonTorchConfig> torches;

  /// Configuration for guard watchtower searchlight sweep.
  final PrisonSearchlightConfig searchlight;

  /// Volumetric light shafts from high windows.
  final List<PrisonGodRayConfig> godRays;

  /// Wet stone floor and wall patches.
  final List<PrisonWetStonePatch> wetStonePatches;

  /// Default dual torch placement: upper left and upper right stone pilasters.
  static const List<PrisonTorchConfig> defaultTorches = <PrisonTorchConfig>[
    PrisonTorchConfig(
      xFraction: 0.10,
      yFraction: 0.22,
      baseRadius: 320.0,
      phaseShift: 0.0,
      isFacingRight: true,
    ),
    PrisonTorchConfig(
      xFraction: 0.90,
      yFraction: 0.24,
      baseRadius: 320.0,
      phaseShift: 2.39,
      isFacingRight: false,
    ),
  ];

  /// Default guard searchlight placed at top center sweeping downward.
  static const PrisonSearchlightConfig defaultSearchlight = PrisonSearchlightConfig(
    xFraction: 0.50,
    yFraction: -0.06,
    baseAngle: math.pi * 0.5,
    sweepArc: 0.76,
    sweepPeriod: 7.2,
    beamLengthFraction: 1.35,
    beamSpreadAngle: 0.35,
    color: Color(0x367CD8FF),
    isAlert: false,
    spotRadius: 96.0,
  );

  /// Default cathedral window god-rays slanting into gloomy dungeon depths.
  static const List<PrisonGodRayConfig> defaultGodRays = <PrisonGodRayConfig>[
    PrisonGodRayConfig(
      originFraction: Offset(0.88, -0.04),
      rayAngle: 2.12,
      rayWidth: 165.0,
      rayLength: 750.0,
      color: Color(0x1A6BB5FF),
    ),
    PrisonGodRayConfig(
      originFraction: Offset(0.15, -0.05),
      rayAngle: 1.15,
      rayWidth: 120.0,
      rayLength: 550.0,
      color: Color(0x125298E6),
    ),
  ];

  /// Default wet stone patches catching specular reflections.
  static const List<PrisonWetStonePatch> defaultWetStonePatches = <PrisonWetStonePatch>[
    PrisonWetStonePatch(
      xFraction: 0.30,
      yFraction: 0.74,
      radiusX: 38.0,
      radiusY: 14.0,
      rotation: -0.15,
      shimmerPhase: 0.2,
    ),
    PrisonWetStonePatch(
      xFraction: 0.68,
      yFraction: 0.82,
      radiusX: 46.0,
      radiusY: 16.0,
      rotation: 0.22,
      shimmerPhase: 1.8,
    ),
    PrisonWetStonePatch(
      xFraction: 0.18,
      yFraction: 0.58,
      radiusX: 24.0,
      radiusY: 9.0,
      rotation: 0.08,
      shimmerPhase: 3.1,
    ),
  ];

  @override
  State<PrisonLighting> createState() => _PrisonLightingState();
}

class _PrisonLightingState extends State<PrisonLighting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final math.Random _random = math.Random(1337);
  final List<TorchEmber> _embers = <TorchEmber>[];
  final List<SearchlightDustMote> _searchlightMotes = <SearchlightDustMote>[];
  double _lastElapsed = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _initSearchlightMotes();

    if (widget.enabled) {
      _animController.repeat();
    }

    _animController.addListener(_onTick);
  }

  void _initSearchlightMotes() {
    _searchlightMotes.clear();
    for (int i = 0; i < 20; i++) {
      _searchlightMotes.add(
        SearchlightDustMote(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          vx: (_random.nextDouble() - 0.5) * 0.018,
          vy: -0.012 - _random.nextDouble() * 0.018,
          size: 1.2 + _random.nextDouble() * 2.2,
          baseAlpha: 0.25 + _random.nextDouble() * 0.45,
          phase: _random.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(PrisonLighting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        if (!_animController.isAnimating) {
          _animController.repeat();
        }
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.removeListener(_onTick);
    _animController.dispose();
    super.dispose();
  }

  void _onTick() {
    final double elapsed = _animController.value * 10.0;
    double dt = elapsed - _lastElapsed;
    if (dt < 0) {
      dt += 10.0;
    }
    _lastElapsed = elapsed;

    if (dt <= 0 || dt > 0.1) {
      dt = 0.016;
    }

    // 1. Update existing torch embers
    if (widget.showEmbers) {
      for (int i = _embers.length - 1; i >= 0; i--) {
        final TorchEmber e = _embers[i];
        e.age += dt;
        if (e.isDead) {
          _embers.removeAt(i);
          continue;
        }
        e.y += e.vy * dt;
        e.x += (e.vx + math.sin(e.age * 8.0 + e.swayPhase) * 14.0) * dt;
      }

      // Spawn new embers if under capacity (capped at 24 for high mobile frame-rates)
      if (_embers.length < 24 && widget.torches.isNotEmpty) {
        for (int i = 0; i < widget.torches.length; i++) {
          if (_random.nextDouble() < 0.35) {
            final PrisonTorchConfig t = widget.torches[i];
            _embers.add(
              TorchEmber(
                x: t.xFraction,
                y: t.yFraction,
                vx: (_random.nextDouble() - 0.5) * 0.04,
                vy: -0.06 - _random.nextDouble() * 0.08,
                size: 1.5 + _random.nextDouble() * 2.5,
                lifespan: 0.9 + _random.nextDouble() * 1.3,
                swayPhase: _random.nextDouble() * math.pi * 2,
              ),
            );
          }
        }
      }
    }

    // 2. Update searchlight dust motes
    if (widget.showSearchlight && _searchlightMotes.isNotEmpty) {
      for (int i = 0; i < _searchlightMotes.length; i++) {
        final SearchlightDustMote m = _searchlightMotes[i];
        m.y += m.vy * dt;
        m.x += (m.vx + math.sin(elapsed * 1.2 + m.phase) * 0.008) * dt;

        // Wrap across boundaries
        if (m.y < 0.0) {
          m.y = 1.0;
          m.x = _random.nextDouble();
        } else if (m.y > 1.0) {
          m.y = 0.0;
        }
        if (m.x < 0.0) {
          m.x = 1.0;
        } else if (m.x > 1.0) {
          m.x = 0.0;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Layer 1: Stone wall masonry & dynamic radial torchlight & wet stone glints
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (BuildContext ctx, _) {
              return CustomPaint(
                painter: PrisonDungeonWallPainter(
                  progress: _animController.value,
                  torches: widget.torches,
                  ambientDarkness: widget.ambientDarkness,
                  showWall: widget.showWall,
                  showWetStoneReflections: widget.showWetStoneReflections,
                  wetStonePatches: widget.wetStonePatches,
                  enabled: widget.enabled,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),

        // Layer 2: Volumetric God-Rays from high barred transom windows
        if (widget.showGodRays && widget.godRays.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (BuildContext ctx, _) {
                    return CustomPaint(
                      painter: PrisonGodRayPainter(
                        progress: _animController.value,
                        godRays: widget.godRays,
                        enabled: widget.enabled,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),

        // Layer 3: Dynamic bar cast shadow projections
        if (widget.showBarShadows)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (BuildContext ctx, _) {
                    return CustomPaint(
                      painter: PrisonShadowCastingPainter(
                        progress: _animController.value,
                        torches: widget.torches,
                        searchlight: widget.searchlight,
                        showSearchlight: widget.showSearchlight,
                        enabled: widget.enabled,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),

        // Layer 4: Watchtower guard searchlight simulation & dust scattering
        if (widget.showSearchlight)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (BuildContext ctx, _) {
                    return CustomPaint(
                      painter: PrisonSearchlightPainter(
                        progress: _animController.value,
                        config: widget.searchlight,
                        dustMotes: _searchlightMotes,
                        enabled: widget.enabled,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),

        // Layer 5: Main interactive UI content
        widget.child,

        // Layer 6: Physical torch fixtures (sconces & flickering multi-layer flames)
        if (widget.showTorches)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (BuildContext ctx, _) {
                    return CustomPaint(
                      painter: PrisonTorchFixturePainter(
                        progress: _animController.value,
                        torches: widget.torches,
                        embers: widget.showEmbers ? _embers : const <TorchEmber>[],
                        enabled: widget.enabled,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
          ),

        // Layer 7: Cinematic Ambient Occlusion Vignette (dungeon arches & abyss shadows)
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (BuildContext ctx, _) {
                  return CustomPaint(
                    painter: PrisonAmbientOcclusionPainter(
                      progress: _animController.value,
                      darkness: widget.ambientDarkness,
                      enabled: widget.enabled,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Computes multi-harmonic torch flicker factor at a given time and phase.
abstract final class PrisonTorchLightingMath {
  static double computeFlicker({
    required double timeSec,
    required double phase,
  }) {
    final double f1 = math.sin(timeSec * 8.2 + phase) * 0.08;
    final double f2 = math.sin(timeSec * 19.4 + phase * 1.6) * 0.05;
    final double f3 = math.sin(timeSec * 37.1 + phase * 0.8) * 0.035;
    final double flare = math.max(0.0, math.sin(timeSec * 2.2 + phase * 2.1) - 0.72) * 0.30;
    final double dip = math.max(0.0, -math.sin(timeSec * 1.5 + phase * 1.3) - 0.85) * 0.22;

    return (1.0 + f1 + f2 + f3 + flare - dip).clamp(0.72, 1.35);
  }

  static Offset computeFlameOffset({
    required double timeSec,
    required double phase,
  }) {
    final double dx = math.sin(timeSec * 16.3 + phase) * 2.2 +
        math.cos(timeSec * 31.7) * 1.1;
    final double dy = math.cos(timeSec * 14.8 + phase) * 2.5 +
        math.sin(timeSec * 23.1) * 1.2;
    return Offset(dx, dy);
  }

  /// Computes guard watchtower searchlight sweeping angle in radians.
  static double computeSearchlightAngle({
    required double timeSec,
    required double baseAngle,
    required double sweepArc,
    required double sweepPeriod,
    bool isAlert = false,
  }) {
    final double normalized = (timeSec % sweepPeriod) / sweepPeriod;
    // Harmonic pendulum sweep with smooth deceleration near limits
    final double harmonic = math.sin(normalized * math.pi * 2.0);
    final double baseSweep = baseAngle + harmonic * (sweepArc * 0.5);

    if (!isAlert) return baseSweep;

    // Rapid alert jitter and tremor during prison break state
    final double jitter = math.sin(timeSec * 26.0) * 0.04 +
        math.cos(timeSec * 43.0) * 0.02;
    return baseSweep + jitter;
  }

  /// Draft wind gusts through cell dungeon corridors.
  static double computeDraftWind({required double timeSec}) {
    return math.sin(timeSec * 0.8) * 0.5 + math.sin(timeSec * 2.4) * 0.2;
  }
}

/// Custom painter for gothic dungeon ashlar stone walls, mortar seams,
/// wet stone specular reflections, and dynamic radial torchlight casting off the stone blocks.
class PrisonDungeonWallPainter extends CustomPainter {
  PrisonDungeonWallPainter({
    required this.progress,
    required this.torches,
    required this.ambientDarkness,
    this.showWall = true,
    this.showWetStoneReflections = true,
    this.wetStonePatches = const <PrisonWetStonePatch>[],
    required this.enabled,
  });

  final double progress;
  final List<PrisonTorchConfig> torches;
  final double ambientDarkness;
  final bool showWall;
  final bool showWetStoneReflections;
  final List<PrisonWetStonePatch> wetStonePatches;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double timeSec = progress * 10.0;

    // 1. Deepest gothic dungeon slate base
    final Rect fullRect = Offset.zero & size;
    final Paint bgPaint = Paint()
      ..color = const Color(0xFF080C14); // Deep obsidian dungeon tone
    canvas.drawRect(fullRect, bgPaint);

    // 2. Procedural ashlar masonry stone blocks
    if (showWall) {
      _paintStoneMasonry(canvas, size);
    }

    // 3. Dynamic radial torchlight casting off the stone walls
    final Paint radialPaint = Paint()..blendMode = BlendMode.screen;

    for (int i = 0; i < torches.length; i++) {
      final PrisonTorchConfig t = torches[i];
      final double flicker = enabled
          ? PrisonTorchLightingMath.computeFlicker(
              timeSec: timeSec,
              phase: t.phaseShift,
            )
          : 1.0;

      final Offset flameJitter = enabled
          ? PrisonTorchLightingMath.computeFlameOffset(
              timeSec: timeSec,
              phase: t.phaseShift,
            )
          : Offset.zero;

      final Offset center = Offset(
        t.xFraction * size.width + flameJitter.dx,
        t.yFraction * size.height + flameJitter.dy,
      );

      final double radius = t.baseRadius * flicker * t.glowIntensity;

      // Multi-stop radial lighting gradient:
      // Intense fiery core -> warm molten amber -> dark crimson -> transparent stone shadow.
      radialPaint.shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: <Color>[
          Color.fromRGBO(255, 224, 130, (0.44 * flicker).clamp(0.0, 1.0)),
          Color.fromRGBO(255, 143, 0, (0.30 * flicker).clamp(0.0, 1.0)),
          Color.fromRGBO(230, 81, 0, (0.18 * flicker).clamp(0.0, 1.0)),
          Color.fromRGBO(141, 32, 5, (0.07 * flicker).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.24, 0.54, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, radialPaint);

      // Subtle warm horizontal wash casting off the damp stone wall
      final Rect wallWashRect = Rect.fromCenter(
        center: center,
        width: radius * 1.6,
        height: radius * 0.9,
      );
      final Paint washPaint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: <Color>[
            Color.fromRGBO(255, 167, 38, (0.14 * flicker).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
        ).createShader(wallWashRect);
      canvas.drawOval(wallWashRect, washPaint);
    }

    // 4. Wet stone specular glints reflecting torchlight
    if (showWetStoneReflections && wetStonePatches.isNotEmpty) {
      _paintWetStoneReflections(canvas, size, timeSec);
    }
  }

  void _paintWetStoneReflections(Canvas canvas, Size size, double timeSec) {
    final Paint wetStonePaint = Paint()..blendMode = BlendMode.screen;

    for (int i = 0; i < wetStonePatches.length; i++) {
      final PrisonWetStonePatch patch = wetStonePatches[i];
      final Offset patchCenter = Offset(
        patch.xFraction * size.width,
        patch.yFraction * size.height,
      );

      // Find illumination from closest torch
      double torchFactor = 0.0;
      for (final PrisonTorchConfig t in torches) {
        final Offset torchPos = Offset(t.xFraction * size.width, t.yFraction * size.height);
        final double dist = (patchCenter - torchPos).distance;
        if (dist < t.baseRadius * 1.8) {
          final double f = (1.0 - dist / (t.baseRadius * 1.8)).clamp(0.0, 1.0);
          torchFactor = math.max(torchFactor, f);
        }
      }

      if (torchFactor <= 0.05) continue;

      final double shimmer = enabled
          ? math.sin(timeSec * 3.5 + patch.shimmerPhase) * 0.15 + 0.85
          : 1.0;

      final Rect patchRect = Rect.fromCenter(
        center: patchCenter,
        width: patch.radiusX * 2.0,
        height: patch.radiusY * 2.0,
      );

      canvas.save();
      canvas.translate(patchCenter.dx, patchCenter.dy);
      canvas.rotate(patch.rotation);
      canvas.translate(-patchCenter.dx, -patchCenter.dy);

      wetStonePaint.shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: <Color>[
          Color.fromRGBO(255, 236, 179, (0.35 * torchFactor * shimmer).clamp(0.0, 0.8)),
          Color.fromRGBO(255, 160, 0, (0.18 * torchFactor * shimmer).clamp(0.0, 0.5)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(patchRect);

      canvas.drawOval(patchRect, wetStonePaint);
      canvas.restore();
    }
  }

  void _paintStoneMasonry(Canvas canvas, Size size) {
    const double blockHeight = 52.0;
    const double blockWidth = 110.0;
    final int rows = (size.height / blockHeight).ceil() + 1;
    final int cols = (size.width / blockWidth).ceil() + 2;

    final Paint mortarPaint = Paint()
      ..color = const Color(0xFF05070C)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint blockEdgeHighlight = Paint()
      ..color = const Color(0x184A5B80)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final Paint subtleBlockShade = Paint()..style = PaintingStyle.fill;
    final Paint seepagePaint = Paint()
      ..color = const Color(0x28020408)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (int r = 0; r < rows; r++) {
      final double y = r * blockHeight;
      final double rowOffset = (r % 2 == 1) ? -(blockWidth * 0.5) : 0.0;

      // Horizontal mortar line
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        mortarPaint,
      );

      for (int c = 0; c < cols; c++) {
        final double x = c * blockWidth + rowOffset;
        final Rect blockRect = Rect.fromLTWH(x, y, blockWidth, blockHeight);

        // Pseudorandom stone tint variation based on coordinate hash
        final int hash = (r * 31 + c * 17) & 0x7FFFFFFF;
        final double tintFactor = (hash % 100) / 100.0;

        if (tintFactor > 0.45) {
          subtleBlockShade.color = Color.fromRGBO(
            18 + (tintFactor * 10).toInt(),
            24 + (tintFactor * 12).toInt(),
            36 + (tintFactor * 14).toInt(),
            0.28,
          );
          canvas.drawRect(blockRect, subtleBlockShade);
        }

        // Damp water seepage run along occasional mortar seams
        if (hash % 7 == 0) {
          canvas.drawLine(
            Offset(x + blockWidth * 0.5, y),
            Offset(x + blockWidth * 0.5, y + blockHeight * 0.75),
            seepagePaint,
          );
        }

        // Top subtle chisel highlight for stone relief
        canvas.drawLine(
          Offset(x + 2, y + 1.5),
          Offset(x + blockWidth - 2, y + 1.5),
          blockEdgeHighlight,
        );

        // Vertical mortar line
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + blockHeight),
          mortarPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PrisonDungeonWallPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.torches != torches ||
        oldDelegate.ambientDarkness != ambientDarkness ||
        oldDelegate.showWall != showWall ||
        oldDelegate.showWetStoneReflections != showWetStoneReflections ||
        oldDelegate.wetStonePatches != wetStonePatches ||
        oldDelegate.enabled != enabled;
  }
}

/// Volumetric God-Rays Painter for high dungeon transom window light shafts.
class PrisonGodRayPainter extends CustomPainter {
  PrisonGodRayPainter({
    required this.progress,
    required this.godRays,
    required this.enabled,
  });

  final double progress;
  final List<PrisonGodRayConfig> godRays;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || godRays.isEmpty) return;
    final double timeSec = progress * 10.0;

    final Paint rayPaint = Paint()..blendMode = BlendMode.screen;

    for (int i = 0; i < godRays.length; i++) {
      final PrisonGodRayConfig ray = godRays[i];
      final double originX = ray.originFraction.dx * size.width;
      final double originY = ray.originFraction.dy * size.height;
      final Offset origin = Offset(originX, originY);

      // Subtle atmospheric pulsation of dusty air
      final double pulse = enabled
          ? 1.0 + math.sin(timeSec * 1.8 + i * 1.5) * 0.12
          : 1.0;

      final double currentWidth = ray.rayWidth * pulse;
      final double currentLength = ray.rayLength;
      final double angle = ray.rayAngle;

      final double dirX = math.cos(angle);
      final double dirY = math.sin(angle);
      final double normX = -dirY;
      final double normY = dirX;

      final Offset topL = origin + Offset(normX * currentWidth * 0.1, normY * currentWidth * 0.1);
      final Offset topR = origin - Offset(normX * currentWidth * 0.1, normY * currentWidth * 0.1);
      final Offset botR = origin +
          Offset(dirX * currentLength, dirY * currentLength) -
          Offset(normX * currentWidth * 0.5, normY * currentWidth * 0.5);
      final Offset botL = origin +
          Offset(dirX * currentLength, dirY * currentLength) +
          Offset(normX * currentWidth * 0.5, normY * currentWidth * 0.5);

      final Path rayPath = Path()
        ..moveTo(topL.dx, topL.dy)
        ..lineTo(topR.dx, topR.dy)
        ..lineTo(botR.dx, botR.dy)
        ..lineTo(botL.dx, botL.dy)
        ..close();

      final Color baseColor = ray.color;
      rayPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          baseColor.withValues(alpha: (baseColor.a * 1.2 * pulse).clamp(0.0, 1.0)),
          baseColor.withValues(alpha: (baseColor.a * 0.6 * pulse).clamp(0.0, 1.0)),
          baseColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(rayPath.getBounds());

      canvas.drawPath(rayPath, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PrisonGodRayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.godRays != godRays ||
        oldDelegate.enabled != enabled;
  }
}

/// Dynamic bar shadow casting painter.
/// Skews cell bar shadows based on torch positions and searchlight sweep angle.
class PrisonShadowCastingPainter extends CustomPainter {
  PrisonShadowCastingPainter({
    required this.progress,
    required this.torches,
    required this.searchlight,
    required this.showSearchlight,
    required this.enabled,
  });

  final double progress;
  final List<PrisonTorchConfig> torches;
  final PrisonSearchlightConfig searchlight;
  final bool showSearchlight;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final double timeSec = progress * 10.0;

    // 1. Dynamic cell bar cast shadows from torches onto the rear stone wall
    _paintTorchBarShadows(canvas, size, timeSec);

    // 2. Moving sweep shadows cast by the guard watchtower searchlight
    if (showSearchlight) {
      _paintSearchlightBarShadows(canvas, size, timeSec);
    }
  }

  void _paintTorchBarShadows(Canvas canvas, Size size, double timeSec) {
    const int barCount = 6;
    final double barSpacing = size.width / (barCount + 1);

    final Paint shadowPaint = Paint()
      ..color = const Color(0x32030508)
      ..style = PaintingStyle.fill;

    for (int t = 0; t < torches.length; t++) {
      final PrisonTorchConfig torch = torches[t];
      if (!torch.castShadows) continue;

      final double torchX = torch.xFraction * size.width;
      final double flicker = enabled
          ? PrisonTorchLightingMath.computeFlicker(timeSec: timeSec, phase: torch.phaseShift)
          : 1.0;

      for (int i = 1; i <= barCount; i++) {
        final double barCenter = i * barSpacing;
        final double distFromTorch = barCenter - torchX;
        final double skew = (distFromTorch / size.width) * 45.0 * flicker;

        final Path barShadow = Path()
          ..moveTo(barCenter - 5.0, 0)
          ..lineTo(barCenter + 5.0, 0)
          ..lineTo(barCenter + 5.0 + skew, size.height)
          ..lineTo(barCenter - 5.0 + skew, size.height)
          ..close();

        canvas.drawPath(barShadow, shadowPaint);
      }
    }
  }

  void _paintSearchlightBarShadows(Canvas canvas, Size size, double timeSec) {
    final double currentAngle = PrisonTorchLightingMath.computeSearchlightAngle(
      timeSec: timeSec,
      baseAngle: searchlight.baseAngle,
      sweepArc: searchlight.sweepArc,
      sweepPeriod: searchlight.sweepPeriod,
      isAlert: searchlight.isAlert,
    );

    // Beam sweep angle relative to vertical (pi/2)
    final double angleDelta = currentAngle - (math.pi * 0.5);
    final double dynamicSkew = math.tan(angleDelta) * size.height * 0.35;

    final Paint sweepShadowPaint = Paint()
      ..color = const Color(0x28020406)
      ..style = PaintingStyle.fill;

    const int barCount = 7;
    final double barSpacing = size.width / (barCount + 1);

    for (int i = 1; i <= barCount; i++) {
      final double barX = i * barSpacing;
      final Path barPath = Path()
        ..moveTo(barX - 7.0, 0)
        ..lineTo(barX + 7.0, 0)
        ..lineTo(barX + 7.0 + dynamicSkew, size.height)
        ..lineTo(barX - 7.0 + dynamicSkew, size.height)
        ..close();

      canvas.drawPath(barPath, sweepShadowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PrisonShadowCastingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.torches != torches ||
        oldDelegate.searchlight != searchlight ||
        oldDelegate.showSearchlight != showSearchlight ||
        oldDelegate.enabled != enabled;
  }
}

/// Watchtower guard searchlight simulation painter.
/// Sweeps across the dungeon in a realistic harmonic pendulum/patrol arc,
/// rendering volumetric light cone, illuminated floor footprint ellipse,
/// emitter aperture glow, and Rayleigh scattering dust motes.
class PrisonSearchlightPainter extends CustomPainter {
  PrisonSearchlightPainter({
    required this.progress,
    required this.config,
    required this.dustMotes,
    required this.enabled,
  });

  final double progress;
  final PrisonSearchlightConfig config;
  final List<SearchlightDustMote> dustMotes;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final double timeSec = progress * 10.0;

    final double currentAngle = PrisonTorchLightingMath.computeSearchlightAngle(
      timeSec: timeSec,
      baseAngle: config.baseAngle,
      sweepArc: config.sweepArc,
      sweepPeriod: config.sweepPeriod,
      isAlert: config.isAlert,
    );

    final double originX = config.xFraction * size.width;
    final double originY = config.yFraction * size.height;
    final Offset origin = Offset(originX, originY);

    final double diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final double beamLength = diagonal * config.beamLengthFraction;
    final double halfSpread = config.beamSpreadAngle * 0.5;

    final double leftAngle = currentAngle - halfSpread;
    final double rightAngle = currentAngle + halfSpread;

    final Offset leftPt = origin + Offset(math.cos(leftAngle) * beamLength, math.sin(leftAngle) * beamLength);
    final Offset rightPt = origin + Offset(math.cos(rightAngle) * beamLength, math.sin(rightAngle) * beamLength);

    // 1. Volumetric Spotlight Beam Cone
    final Path conePath = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(leftPt.dx, leftPt.dy)
      ..lineTo(rightPt.dx, rightPt.dy)
      ..close();

    final Color beamColor = config.color;
    final Paint conePaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          beamColor.withValues(alpha: (beamColor.a * 1.5).clamp(0.0, 1.0)),
          beamColor.withValues(alpha: (beamColor.a * 0.65).clamp(0.0, 1.0)),
          beamColor.withValues(alpha: (beamColor.a * 0.15).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.28, 0.75, 1.0],
      ).createShader(conePath.getBounds());

    canvas.drawPath(conePath, conePaint);

    // 2. Central Intense Beam Shaft Core
    final double coreHalfSpread = halfSpread * 0.35;
    final Offset coreLeft = origin +
        Offset(math.cos(currentAngle - coreHalfSpread) * beamLength * 0.8,
            math.sin(currentAngle - coreHalfSpread) * beamLength * 0.8);
    final Offset coreRight = origin +
        Offset(math.cos(currentAngle + coreHalfSpread) * beamLength * 0.8,
            math.sin(currentAngle + coreHalfSpread) * beamLength * 0.8);
    final Path corePath = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(coreLeft.dx, coreLeft.dy)
      ..lineTo(coreRight.dx, coreRight.dy)
      ..close();

    final Paint corePaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.32),
          beamColor.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.40, 1.0],
      ).createShader(corePath.getBounds());

    canvas.drawPath(corePath, corePaint);

    // 3. Illuminated Floor Footprint Ellipse where beam hits ground
    final double floorY = size.height * 0.88;
    final double floorDist = (floorY - originY) / math.sin(currentAngle).abs().clamp(0.2, 1.0);
    final Offset spotCenter = origin +
        Offset(math.cos(currentAngle) * floorDist, math.sin(currentAngle) * floorDist);

    if (spotCenter.dy >= 0 && spotCenter.dy <= size.height * 1.2) {
      final Rect spotRect = Rect.fromCenter(
        center: spotCenter,
        width: config.spotRadius * 2.2,
        height: config.spotRadius * 0.9,
      );

      final Paint floorSpotPaint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: <Color>[
            beamColor.withValues(alpha: 0.45),
            beamColor.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(spotRect);

      canvas.drawOval(spotRect, floorSpotPaint);
    }

    // 4. Emitter Aperture Glow at top origin
    final Paint emitterPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.85),
          beamColor.withValues(alpha: 0.4),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: origin, radius: 28.0));

    canvas.drawCircle(origin, 28.0, emitterPaint);

    // 5. Airborne Dust Rayleigh Scattering in the beam
    _paintIlluminatedDust(canvas, size, origin, currentAngle, halfSpread, beamLength, beamColor);
  }

  void _paintIlluminatedDust(
    Canvas canvas,
    Size size,
    Offset origin,
    double beamAngle,
    double halfSpread,
    double beamLength,
    Color beamColor,
  ) {
    if (dustMotes.isEmpty) return;

    final Paint motePaint = Paint()..blendMode = BlendMode.plus;

    for (int i = 0; i < dustMotes.length; i++) {
      final SearchlightDustMote m = dustMotes[i];
      final double mx = m.x * size.width;
      final double my = m.y * size.height;
      final Offset mPos = Offset(mx, my);

      final Offset delta = mPos - origin;
      final double dist = delta.distance;
      if (dist > beamLength || dist < 10.0) continue;

      final double angleToMote = math.atan2(delta.dy, delta.dx);
      // Angular difference accounting for wrap
      double angleDiff = (angleToMote - beamAngle).abs();
      if (angleDiff > math.pi) {
        angleDiff = (math.pi * 2) - angleDiff;
      }

      if (angleDiff <= halfSpread) {
        final double angleFactor = 1.0 - (angleDiff / halfSpread);
        final double distFactor = (1.0 - (dist / beamLength)).clamp(0.0, 1.0);
        final double illumination = angleFactor * distFactor;

        final double alpha = (m.baseAlpha * 1.5 * illumination).clamp(0.0, 0.95);
        motePaint.color = Color.lerp(
          beamColor,
          Colors.white,
          illumination * 0.6,
        )!.withValues(alpha: alpha);

        final double moteRadius = m.size * (1.0 + illumination * 0.8);
        canvas.drawCircle(mPos, moteRadius, motePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PrisonSearchlightPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.config != config ||
        oldDelegate.dustMotes != dustMotes ||
        oldDelegate.enabled != enabled;
  }
}

/// Custom painter for physical iron torch wall sconces, flame tongues,
/// and rising ember sparks.
class PrisonTorchFixturePainter extends CustomPainter {
  PrisonTorchFixturePainter({
    required this.progress,
    required this.torches,
    required this.embers,
    required this.enabled,
  });

  final double progress;
  final List<PrisonTorchConfig> torches;
  final List<TorchEmber> embers;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double timeSec = progress * 10.0;

    for (int i = 0; i < torches.length; i++) {
      final PrisonTorchConfig t = torches[i];
      final double px = t.xFraction * size.width;
      final double py = t.yFraction * size.height;

      _paintSconceBracket(canvas, Offset(px, py), t.isFacingRight);

      final double flicker = enabled
          ? PrisonTorchLightingMath.computeFlicker(
              timeSec: timeSec,
              phase: t.phaseShift,
            )
          : 1.0;

      final Offset flameJitter = enabled
          ? PrisonTorchLightingMath.computeFlameOffset(
              timeSec: timeSec,
              phase: t.phaseShift,
            )
          : Offset.zero;

      _paintTorchFlame(
        canvas,
        Offset(px + flameJitter.dx, py + flameJitter.dy - 16.0),
        flicker,
        timeSec + t.phaseShift,
        t.flameColor,
      );
    }

    // Paint rising ember sparks
    _paintEmbers(canvas, size);
  }

  void _paintSconceBracket(Canvas canvas, Offset base, bool isFacingRight) {
    final double dir = isFacingRight ? 1.0 : -1.0;

    final Paint ironPaint = Paint()
      ..color = const Color(0xFF161B26)
      ..style = PaintingStyle.fill;

    // Luminous metallic rim highlight
    final Paint ironHighlight = Paint()
      ..color = const Color(0xFF4C5D78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final Paint woodTorchPaint = Paint()
      ..color = const Color(0xFF281A10)
      ..style = PaintingStyle.fill;

    // 1. Wall mounting plate (diamond backplate with bevel)
    final Path platePath = Path()
      ..moveTo(base.dx - 14 * dir, base.dy - 20)
      ..lineTo(base.dx - 6 * dir, base.dy - 32)
      ..lineTo(base.dx + 2 * dir, base.dy - 20)
      ..lineTo(base.dx - 6 * dir, base.dy - 8)
      ..close();
    canvas.drawPath(platePath, ironPaint);
    canvas.drawPath(platePath, ironHighlight);

    // Wall rivets with metallic specular dots
    final Paint rivetPaint = Paint()..color = const Color(0xFF56698A);
    final Paint rivetGlint = Paint()..color = const Color(0xFF8BA5CC);
    canvas.drawCircle(Offset(base.dx - 6 * dir, base.dy - 28), 1.9, rivetPaint);
    canvas.drawCircle(Offset(base.dx - 6.5 * dir, base.dy - 28.5), 0.7, rivetGlint);
    canvas.drawCircle(Offset(base.dx - 6 * dir, base.dy - 12), 1.9, rivetPaint);
    canvas.drawCircle(Offset(base.dx - 6.5 * dir, base.dy - 12.5), 0.7, rivetGlint);

    // 2. Curved wrought-iron support arm with bevel
    final Path armPath = Path()
      ..moveTo(base.dx - 6 * dir, base.dy - 20)
      ..cubicTo(
        base.dx + 12 * dir,
        base.dy - 18,
        base.dx + 22 * dir,
        base.dy - 8,
        base.dx + 18 * dir,
        base.dy + 8,
      )
      ..lineTo(base.dx + 15 * dir, base.dy + 8)
      ..cubicTo(
        base.dx + 18 * dir,
        base.dy - 6,
        base.dx + 10 * dir,
        base.dy - 15,
        base.dx - 6 * dir,
        base.dy - 17,
      )
      ..close();
    canvas.drawPath(armPath, ironPaint);
    canvas.drawPath(armPath, ironHighlight);

    // 3. Wooden torch pole tilted slightly
    final Path polePath = Path()
      ..moveTo(base.dx - 2 * dir, base.dy - 4)
      ..lineTo(base.dx + 4 * dir, base.dy - 28)
      ..lineTo(base.dx + 12 * dir, base.dy - 26)
      ..lineTo(base.dx + 6 * dir, base.dy - 2)
      ..close();
    canvas.drawPath(polePath, woodTorchPaint);

    // Wood grain detail streak
    final Paint grainPaint = Paint()
      ..color = const Color(0xFF382518)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(base.dx + 3 * dir, base.dy - 20),
      Offset(base.dx + 6 * dir, base.dy - 8),
      grainPaint,
    );

    // Iron ring securing the torch with luminous specular top
    final Paint bandPaint = Paint()
      ..color = const Color(0xFF222B3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    canvas.drawLine(
      Offset(base.dx + 1 * dir, base.dy - 16),
      Offset(base.dx + 9 * dir, base.dy - 14),
      bandPaint,
    );

    final Paint bandGlintPaint = Paint()
      ..color = const Color(0xFF6B7E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(base.dx + 2 * dir, base.dy - 17),
      Offset(base.dx + 8 * dir, base.dy - 15),
      bandGlintPaint,
    );

    // 4. Torch head wrap (combustible linen soaked in pitch)
    final Rect wrapRect = Rect.fromCenter(
      center: Offset(base.dx + 6 * dir, base.dy - 30),
      width: 14.0,
      height: 12.0,
    );
    final Paint wrapPaint = Paint()..color = const Color(0xFF1E1511);
    canvas.drawRRect(
      RRect.fromRectAndRadius(wrapRect, const Radius.circular(3)),
      wrapPaint,
    );

    // Cross-hatching texture on linen wrap
    final Paint wrapStitch = Paint()
      ..color = const Color(0xFF34231B)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(wrapRect.left + 2, wrapRect.top + 2),
      Offset(wrapRect.right - 2, wrapRect.bottom - 2),
      wrapStitch,
    );
    canvas.drawLine(
      Offset(wrapRect.left + 2, wrapRect.bottom - 2),
      Offset(wrapRect.right - 2, wrapRect.top + 2),
      wrapStitch,
    );
  }

  void _paintTorchFlame(
    Canvas canvas,
    Offset origin,
    double flicker,
    double phaseTime,
    Color flameChroma,
  ) {
    final double flameHeight = (38.0 * flicker).clamp(24.0, 56.0);
    final double flameWidth = (20.0 * (0.85 + (flicker - 1.0) * 0.5)).clamp(14.0, 30.0);
    final double tipSway = math.sin(phaseTime * 6.0) * 4.2;

    // 0. Hot air thermal glow aura
    final Paint auraPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: <Color>[
          flameChroma.withValues(alpha: (0.28 * flicker).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: origin - const Offset(0, 16.0), radius: flameHeight * 1.1));
    canvas.drawCircle(origin - const Offset(0, 16.0), flameHeight * 1.1, auraPaint);

    // 1. Outer Flame Halo (Warm Amber / Red)
    final Path outerFlame = Path()
      ..moveTo(origin.dx - flameWidth * 0.5, origin.dy)
      ..cubicTo(
        origin.dx - flameWidth * 0.65,
        origin.dy - flameHeight * 0.45,
        origin.dx - flameWidth * 0.35 + tipSway,
        origin.dy - flameHeight * 0.75,
        origin.dx + tipSway,
        origin.dy - flameHeight,
      )
      ..cubicTo(
        origin.dx + flameWidth * 0.35 + tipSway,
        origin.dy - flameHeight * 0.75,
        origin.dx + flameWidth * 0.65,
        origin.dy - flameHeight * 0.45,
        origin.dx + flameWidth * 0.5,
        origin.dy,
      )
      ..close();

    final Paint outerFlamePaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          const Color(0xFFD84315),
          flameChroma,
          const Color(0xFFFFB74D).withValues(alpha: 0.85),
        ],
      ).createShader(Rect.fromLTWH(
        origin.dx - flameWidth,
        origin.dy - flameHeight,
        flameWidth * 2,
        flameHeight,
      ));
    canvas.drawPath(outerFlame, outerFlamePaint);

    // Secondary tongue offset for organic realism
    final double secondaryTip = math.sin(phaseTime * 8.4 + 1.2) * 2.8;
    final Path secondTongue = Path()
      ..moveTo(origin.dx - flameWidth * 0.3, origin.dy - 4.0)
      ..cubicTo(
        origin.dx - flameWidth * 0.4,
        origin.dy - flameHeight * 0.4,
        origin.dx + secondaryTip,
        origin.dy - flameHeight * 0.7,
        origin.dx + secondaryTip * 0.8,
        origin.dy - flameHeight * 0.85,
      )
      ..cubicTo(
        origin.dx + flameWidth * 0.3,
        origin.dy - flameHeight * 0.5,
        origin.dx + flameWidth * 0.25,
        origin.dy - flameHeight * 0.2,
        origin.dx + flameWidth * 0.2,
        origin.dy - 4.0,
      )
      ..close();
    final Paint secondTonguePaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Color(0xFFFFA000),
          Color(0xFFFFD54F),
        ],
      ).createShader(Rect.fromLTWH(
        origin.dx - flameWidth,
        origin.dy - flameHeight,
        flameWidth * 2,
        flameHeight,
      ));
    canvas.drawPath(secondTongue, secondTonguePaint);

    // 2. Inner Flame Core (Intense Gold / Yellow)
    final double innerWidth = flameWidth * 0.55;
    final double innerHeight = flameHeight * 0.65;
    final Path innerFlame = Path()
      ..moveTo(origin.dx - innerWidth * 0.5, origin.dy)
      ..cubicTo(
        origin.dx - innerWidth * 0.6,
        origin.dy - innerHeight * 0.4,
        origin.dx + tipSway * 0.6,
        origin.dy - innerHeight * 0.7,
        origin.dx + tipSway * 0.5,
        origin.dy - innerHeight,
      )
      ..cubicTo(
        origin.dx + innerWidth * 0.6,
        origin.dy - innerHeight * 0.4,
        origin.dx + innerWidth * 0.5,
        origin.dy - innerHeight * 0.2,
        origin.dx + innerWidth * 0.5,
        origin.dy,
      )
      ..close();

    final Paint innerFlamePaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Color(0xFFFFEA00),
          Color(0xFFFFF9C4),
        ],
      ).createShader(Rect.fromLTWH(
        origin.dx - innerWidth,
        origin.dy - innerHeight,
        innerWidth * 2,
        innerHeight,
      ));
    canvas.drawPath(innerFlame, innerFlamePaint);

    // 3. White-hot ignition center at base
    final Paint hotCorePaint = Paint()
      ..blendMode = BlendMode.plus
      ..color = Colors.white.withValues(alpha: 0.90);
    canvas.drawCircle(Offset(origin.dx, origin.dy - 4.0), 3.4, hotCorePaint);
  }

  void _paintEmbers(Canvas canvas, Size size) {
    if (embers.isEmpty) return;

    final Paint emberPaint = Paint()..blendMode = BlendMode.plus;

    for (int i = 0; i < embers.length; i++) {
      final TorchEmber e = embers[i];
      final double ex = e.x * size.width;
      final double ey = e.y * size.height;
      final double p = e.progress;

      // Color transition: White -> Gold -> Bright Orange -> Deep Red -> 0
      final Color color;
      if (p < 0.25) {
        color = Color.lerp(Colors.white, const Color(0xFFFFD54F), p / 0.25)!;
      } else if (p < 0.65) {
        color = Color.lerp(
          const Color(0xFFFFD54F),
          const Color(0xFFFF5722),
          (p - 0.25) / 0.40,
        )!;
      } else {
        color = Color.lerp(
          const Color(0xFFFF5722),
          const Color(0xFFB71C1C).withValues(alpha: 0.0),
          (p - 0.65) / 0.35,
        )!;
      }

      final double currentSize = e.size * (1.0 - p * 0.6);
      emberPaint.color = color;
      canvas.drawCircle(Offset(ex, ey), currentSize, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PrisonTorchFixturePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.torches != torches ||
        oldDelegate.embers != embers ||
        oldDelegate.enabled != enabled;
  }
}

/// Ambient Occlusion Vignette painter.
/// Creates dark gothic depth with arched ceiling shadows, floor abyss gradient,
/// and perimeter claustrophobic vignette.
class PrisonAmbientOcclusionPainter extends CustomPainter {
  PrisonAmbientOcclusionPainter({
    required this.progress,
    required this.darkness,
    required this.enabled,
  });

  final double progress;
  final double darkness;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;
    final double timeSec = progress * 10.0;
    final double breathe = enabled ? math.sin(timeSec * 2.0) * 0.03 : 0.0;
    final double effectiveDarkness = (darkness + breathe).clamp(0.65, 0.98);

    // 1. Radial Vignette from screen center outward to edges
    final Paint vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: <Color>[
          Colors.transparent,
          Color.fromRGBO(5, 7, 12, effectiveDarkness * 0.35),
          Color.fromRGBO(4, 6, 10, effectiveDarkness * 0.72),
          Color.fromRGBO(3, 4, 8, effectiveDarkness * 0.94),
        ],
        stops: const <double>[0.0, 0.52, 0.82, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignettePaint);

    // 2. Top Gothic Arched Ceiling Shadow (deep downward gradient)
    final double ceilingHeight = (size.height * 0.22).clamp(80.0, 180.0);
    final Rect ceilingRect = Rect.fromLTWH(0, 0, size.width, ceilingHeight);
    final Paint ceilingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(4, 5, 9, effectiveDarkness),
          Color.fromRGBO(6, 8, 14, effectiveDarkness * 0.75),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(ceilingRect);
    canvas.drawRect(ceilingRect, ceilingPaint);

    // 3. Bottom Dungeon Abyss Shadow (deep upward gradient for bottom bar depth)
    final double abyssHeight = (size.height * 0.24).clamp(90.0, 200.0);
    final Rect abyssRect = Rect.fromLTWH(
      0,
      size.height - abyssHeight,
      size.width,
      abyssHeight,
    );
    final Paint abyssPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Color.fromRGBO(3, 4, 7, effectiveDarkness * 0.96),
          Color.fromRGBO(5, 7, 11, effectiveDarkness * 0.65),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.60, 1.0],
      ).createShader(abyssRect);
    canvas.drawRect(abyssRect, abyssPaint);
  }

  @override
  bool shouldRepaint(covariant PrisonAmbientOcclusionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.darkness != darkness ||
        oldDelegate.enabled != enabled;
  }
}

/// Glassmorphic container adhering to the frosted glass design system.
/// Features high blur, luminous border, translucent obsidian background,
/// and subtle rim depth.
class PrisonGlassmorphicCard extends StatelessWidget {
  const PrisonGlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurSigma = 12.0,
    this.borderColor = const Color(0x38FFB74D),
    this.backgroundColor = const Color(0xBF0E1524),
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color borderColor;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor,
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16.0,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.12),
                  blurRadius: 10.0,
                  spreadRadius: 1.0,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
