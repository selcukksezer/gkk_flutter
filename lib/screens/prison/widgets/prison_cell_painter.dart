import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Depth tier for floating dungeon dust motes.
enum DustMoteTier {
  /// Distant background motes: small, faint, slow drifting.
  background,

  /// Mid-depth motes: medium size and moderate opacity.
  midground,

  /// Foreground bokeh motes: large, luminous, with soft radial halo.
  foreground,
}

/// A preallocated dungeon dust mote with deterministic sinusoidal Brownian drift.
class PrisonDustMote {
  const PrisonDustMote({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.speedY,
    required this.amplitudeX,
    required this.frequencyX,
    required this.phaseX,
    required this.baseAlpha,
    required this.tier,
    this.flickerSpeed = 1.2,
    this.flickerPhase = 0.0,
  });

  final double baseX;
  final double baseY;
  final double radius;
  final double speedY;
  final double amplitudeX;
  final double frequencyX;
  final double phaseX;
  final double baseAlpha;
  final DustMoteTier tier;
  final double flickerSpeed;
  final double flickerPhase;

  /// Computes the mote's current 2D offset in screen coordinates at [timeSeconds].
  Offset computePosition(double timeSeconds, Size size) {
    // Continuous vertical upward drift wrapping around screen
    final double rawY = (baseY - timeSeconds * speedY) % 1.0;
    final double y = (rawY < 0.0 ? rawY + 1.0 : rawY) * size.height;

    // Organic horizontal sinusoidal sway
    final double sway = math.sin(timeSeconds * frequencyX + phaseX) * amplitudeX;
    final double x = (baseX + sway) * size.width;

    return Offset(x, y);
  }

  /// Computes the luminous opacity of the dust mote at [timeSeconds].
  double computeAlpha(double timeSeconds) {
    final double shimmer = 0.75 + 0.25 * math.sin(timeSeconds * flickerSpeed + flickerPhase);
    return (baseAlpha * shimmer).clamp(0.0, 1.0);
  }
}

/// Configuration for an individual vertical wrought-iron bar.
class PrisonIronBarConfig {
  const PrisonIronBarConfig({
    required this.xRatio,
    required this.barWidth,
    this.rimSheenPhase = 0.0,
    this.rivetYFractions = const <double>[0.12, 0.48, 0.88],
  });

  /// Normalized horizontal center position (0.0 to 1.0) across viewport.
  final double xRatio;

  /// Width in logical pixels of the heavy wrought-iron bar.
  final double barWidth;

  /// Phase offset for the dynamic metallic sheen wave running along the bar.
  final double rimSheenPhase;

  /// Normalized Y positions for heavy structural iron rivets/studs.
  final List<double> rivetYFractions;
}

/// Color theme & lighting parameters for the cold dungeon cell environment.
class PrisonCellTheme {
  const PrisonCellTheme({
    this.wallBaseDark = const Color(0xFF0A0E15),
    this.wallBaseMid = const Color(0xFF131923),
    this.stoneHighlight = const Color(0xFF263242),
    this.mortarGroove = const Color(0xFF040609),
    this.ironShadow = const Color(0xFF050709),
    this.ironBase = const Color(0xFF1B222C),
    this.ironHighlight = const Color(0xFF8FA3BD),
    this.ironSpecularBand = const Color(0xFFD6E3F2),
    this.torchRimWarm = const Color(0x38F59E0B),
    this.dungeonRimCold = const Color(0x4060A5FA),
    this.stoneRimWet = const Color(0x2893C5FD),
    this.vignetteDarkness = 0.82,
    this.brickRowHeight = 44.0,
    this.brickWidth = 88.0,
  });

  final Color wallBaseDark;
  final Color wallBaseMid;
  final Color stoneHighlight;
  final Color mortarGroove;
  final Color ironShadow;
  final Color ironBase;
  final Color ironHighlight;
  final Color ironSpecularBand;
  final Color torchRimWarm;
  final Color dungeonRimCold;
  final Color stoneRimWet;
  final double vignetteDarkness;
  final double brickRowHeight;
  final double brickWidth;

  static const PrisonCellTheme gothicCold = PrisonCellTheme();
}

/// High-performance CustomPainter rendering 3D iron bars, cold stone brick textures,
/// and floating dungeon dust motes with zero heap allocations during paint.
class PrisonCellPainter extends CustomPainter {
  PrisonCellPainter({
    required this.timeSeconds,
    this.theme = PrisonCellTheme.gothicCold,
    this.isInPrison = true,
    this.showBars = true,
    this.showDust = true,
    this.showBricks = true,
    this.barsOpacity = 1.0,
    this.dustMotes = defaultDustMotes,
    this.ironBars = defaultIronBars,
    this.freedomTransition = 0.0,
  });

  final double timeSeconds;
  final PrisonCellTheme theme;
  final bool isInPrison;
  final bool showBars;
  final bool showDust;
  final bool showBricks;
  final double barsOpacity;
  final List<PrisonDustMote> dustMotes;
  final List<PrisonIronBarConfig> ironBars;
  final double freedomTransition;

  // Cached paint objects to guarantee zero allocation per paint cycle
  static final Paint _paintFill = Paint()..style = PaintingStyle.fill;
  static final Paint _paintStroke = Paint()..style = PaintingStyle.stroke;

  /// Default pool of 36 preallocated dust motes distributed across 3 depth tiers.
  static const List<PrisonDustMote> defaultDustMotes = <PrisonDustMote>[
    // Foreground bokeh motes (large, luminous)
    PrisonDustMote(baseX: 0.18, baseY: 0.72, radius: 4.2, speedY: 0.038, amplitudeX: 0.045, frequencyX: 0.85, phaseX: 0.3, baseAlpha: 0.55, tier: DustMoteTier.foreground),
    PrisonDustMote(baseX: 0.52, baseY: 0.35, radius: 4.8, speedY: 0.042, amplitudeX: 0.050, frequencyX: 0.75, phaseX: 1.8, baseAlpha: 0.60, tier: DustMoteTier.foreground),
    PrisonDustMote(baseX: 0.82, baseY: 0.60, radius: 3.8, speedY: 0.035, amplitudeX: 0.040, frequencyX: 0.90, phaseX: 3.1, baseAlpha: 0.50, tier: DustMoteTier.foreground),
    PrisonDustMote(baseX: 0.32, baseY: 0.88, radius: 4.0, speedY: 0.040, amplitudeX: 0.042, frequencyX: 0.80, phaseX: 4.2, baseAlpha: 0.52, tier: DustMoteTier.foreground),

    // Midground motes (medium, clear)
    PrisonDustMote(baseX: 0.08, baseY: 0.15, radius: 2.4, speedY: 0.028, amplitudeX: 0.030, frequencyX: 1.10, phaseX: 0.6, baseAlpha: 0.45, tier: DustMoteTier.midground),
    PrisonDustMote(baseX: 0.25, baseY: 0.42, radius: 2.2, speedY: 0.032, amplitudeX: 0.035, frequencyX: 1.05, phaseX: 2.4, baseAlpha: 0.42, tier: DustMoteTier.midground),
    PrisonDustMote(baseX: 0.42, baseY: 0.18, radius: 2.6, speedY: 0.026, amplitudeX: 0.028, frequencyX: 0.95, phaseX: 1.2, baseAlpha: 0.48, tier: DustMoteTier.midground),
    PrisonDustMote(baseX: 0.65, baseY: 0.78, radius: 2.5, speedY: 0.030, amplitudeX: 0.032, frequencyX: 1.15, phaseX: 4.8, baseAlpha: 0.40, tier: DustMoteTier.midground),
    PrisonDustMote(baseX: 0.74, baseY: 0.25, radius: 2.1, speedY: 0.027, amplitudeX: 0.026, frequencyX: 1.20, phaseX: 3.6, baseAlpha: 0.44, tier: DustMoteTier.midground),
    PrisonDustMote(baseX: 0.91, baseY: 0.50, radius: 2.3, speedY: 0.031, amplitudeX: 0.033, frequencyX: 1.00, phaseX: 5.4, baseAlpha: 0.46, tier: DustMoteTier.midground),
    PrisonDustMote(baseX: 0.38, baseY: 0.62, radius: 2.4, speedY: 0.029, amplitudeX: 0.031, frequencyX: 1.08, phaseX: 2.9, baseAlpha: 0.43, tier: DustMoteTier.midground),
    PrisonDustMote(baseX: 0.58, baseY: 0.92, radius: 2.0, speedY: 0.033, amplitudeX: 0.029, frequencyX: 1.12, phaseX: 0.9, baseAlpha: 0.38, tier: DustMoteTier.midground),

    // Background motes (small, ambient depth specks)
    PrisonDustMote(baseX: 0.05, baseY: 0.30, radius: 1.3, speedY: 0.016, amplitudeX: 0.018, frequencyX: 1.30, phaseX: 0.1, baseAlpha: 0.28, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.14, baseY: 0.82, radius: 1.1, speedY: 0.018, amplitudeX: 0.016, frequencyX: 1.40, phaseX: 1.5, baseAlpha: 0.22, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.22, baseY: 0.55, radius: 1.4, speedY: 0.015, amplitudeX: 0.020, frequencyX: 1.25, phaseX: 2.7, baseAlpha: 0.30, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.30, baseY: 0.12, radius: 1.2, speedY: 0.019, amplitudeX: 0.017, frequencyX: 1.35, phaseX: 4.1, baseAlpha: 0.25, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.36, baseY: 0.70, radius: 1.5, speedY: 0.017, amplitudeX: 0.019, frequencyX: 1.20, phaseX: 5.2, baseAlpha: 0.32, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.46, baseY: 0.45, radius: 1.0, speedY: 0.020, amplitudeX: 0.015, frequencyX: 1.45, phaseX: 0.8, baseAlpha: 0.20, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.55, baseY: 0.20, radius: 1.3, speedY: 0.016, amplitudeX: 0.018, frequencyX: 1.28, phaseX: 2.1, baseAlpha: 0.26, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.62, baseY: 0.65, radius: 1.2, speedY: 0.018, amplitudeX: 0.016, frequencyX: 1.32, phaseX: 3.4, baseAlpha: 0.24, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.70, baseY: 0.10, radius: 1.4, speedY: 0.015, amplitudeX: 0.021, frequencyX: 1.22, phaseX: 4.7, baseAlpha: 0.29, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.78, baseY: 0.85, radius: 1.1, speedY: 0.019, amplitudeX: 0.015, frequencyX: 1.38, phaseX: 5.9, baseAlpha: 0.21, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.86, baseY: 0.38, radius: 1.3, speedY: 0.017, amplitudeX: 0.017, frequencyX: 1.26, phaseX: 1.1, baseAlpha: 0.27, tier: DustMoteTier.background),
    PrisonDustMote(baseX: 0.95, baseY: 0.75, radius: 1.2, speedY: 0.016, amplitudeX: 0.018, frequencyX: 1.34, phaseX: 2.5, baseAlpha: 0.23, tier: DustMoteTier.background),
  ];

  /// Default 6 heavy vertical wrought-iron bars symmetrically distributed across screen.
  static const List<PrisonIronBarConfig> defaultIronBars = <PrisonIronBarConfig>[
    PrisonIronBarConfig(xRatio: 0.07, barWidth: 17.0, rimSheenPhase: 0.0),
    PrisonIronBarConfig(xRatio: 0.24, barWidth: 18.0, rimSheenPhase: 1.1),
    PrisonIronBarConfig(xRatio: 0.41, barWidth: 19.0, rimSheenPhase: 2.2),
    PrisonIronBarConfig(xRatio: 0.59, barWidth: 19.0, rimSheenPhase: 3.3),
    PrisonIronBarConfig(xRatio: 0.76, barWidth: 18.0, rimSheenPhase: 4.4),
    PrisonIronBarConfig(xRatio: 0.93, barWidth: 17.0, rimSheenPhase: 5.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if (isInPrison) {
      _paintDungeonCell(canvas, size);
    } else {
      _paintFreedomCourtyard(canvas, size);
    }
  }

  /// Paints the full immersive gothic dungeon cell: cold stone masonry, dust motes,
  /// and heavy 3D wrought iron bars.
  void _paintDungeonCell(Canvas canvas, Size size) {
    if (showBricks) {
      _paintColdStoneMasonry(canvas, size);
    }

    if (showDust) {
      _paintDustMotesByTier(canvas, size, DustMoteTier.background);
      _paintDustMotesByTier(canvas, size, DustMoteTier.midground);
    }

    if (showBars && barsOpacity > 0.001) {
      _paint3DIronBars(canvas, size);
    }

    if (showDust) {
      // Foreground bokeh motes rendered over bars for realistic depth separation
      _paintDustMotesByTier(canvas, size, DustMoteTier.foreground);
    }

    _paintVignetteAndAtmosphere(canvas, size);
  }

  /// Paints peaceful airy courtyard atmosphere when player is free.
  void _paintFreedomCourtyard(Canvas canvas, Size size) {
    // Serene sky gradient
    final Rect rect = Offset.zero & size;
    _paintFill.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFF0F172A),
        Color(0xFF0D1B2A),
        Color(0xFF0B132B),
      ],
    ).createShader(rect);
    canvas.drawRect(rect, _paintFill);

    // Golden rays of freedom
    _paintFreedomRays(canvas, size);

    // Serene celestial motes
    if (showDust) {
      for (final PrisonDustMote mote in dustMotes) {
        final Offset pos = mote.computePosition(timeSeconds, size);
        final double alpha = (mote.computeAlpha(timeSeconds) * 0.7).clamp(0.0, 1.0);
        _paintFill.shader = null;
        _paintFill.color = AppColors.gold.withValues(alpha: alpha);
        canvas.drawCircle(pos, mote.radius * 0.9, _paintFill);
      }
    }
  }

  /// Paints cold ashlar stone masonry with authentic 3D beveled mortar channels
  /// and damp granite specular rim highlights.
  void _paintColdStoneMasonry(Canvas canvas, Size size) {
    final double rowHeight = theme.brickRowHeight;
    final double brickWidth = theme.brickWidth;
    final int rows = (size.height / rowHeight).ceil() + 1;
    final int cols = (size.width / brickWidth).ceil() + 2;

    // Base deep dungeon stone fill
    _paintFill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        theme.wallBaseDark,
        theme.wallBaseMid,
        theme.wallBaseDark,
      ],
      stops: const <double>[0.0, 0.55, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _paintFill);

    // Stone brick rows with running bond / staggered offset
    for (int r = 0; r < rows; r++) {
      final double y = r * rowHeight;
      final double xOffset = (r % 2 == 0) ? 0.0 : -(brickWidth * 0.5);

      for (int c = -1; c < cols; c++) {
        final double x = c * brickWidth + xOffset;
        final Rect brickRect = Rect.fromLTWH(x + 1.5, y + 1.5, brickWidth - 3.0, rowHeight - 3.0);

        // Pseudorandom organic stone tone modulation
        final int seed = (r * 73856093 ^ (c + 10) * 19349663).abs();
        final double tone = (seed % 100) / 100.0;
        final Color brickColor = Color.lerp(
          theme.wallBaseMid,
          theme.stoneHighlight,
          tone * 0.22,
        )!;

        // Brick body
        _paintFill.shader = null;
        _paintFill.color = brickColor;
        canvas.drawRect(brickRect, _paintFill);

        // 3D Beveled Stone Relief: top & left edge highlight, bottom & right groove shadow
        _paintStroke.shader = null;
        _paintStroke.strokeWidth = 1.0;

        // Top-left relief highlight
        _paintStroke.color = theme.stoneHighlight.withValues(alpha: 0.35 + tone * 0.15);
        canvas.drawLine(brickRect.topLeft, brickRect.topRight, _paintStroke);
        canvas.drawLine(brickRect.topLeft, brickRect.bottomLeft, _paintStroke);

        // Bottom-right recessed shadow
        _paintStroke.color = theme.mortarGroove.withValues(alpha: 0.75);
        canvas.drawLine(brickRect.bottomLeft, brickRect.bottomRight, _paintStroke);
        canvas.drawLine(brickRect.topRight, brickRect.bottomRight, _paintStroke);

        // Subtle wet cold stone rim reflection fleck on selected blocks
        if (seed % 5 == 0) {
          final double fleckX = brickRect.left + (brickWidth * 0.25) + (seed % 17);
          final double fleckY = brickRect.top + 3.0;
          _paintFill.color = theme.stoneRimWet.withValues(alpha: 0.18 + tone * 0.12);
          canvas.drawCircle(Offset(fleckX, fleckY), 1.2, _paintFill);
        }
      }

      // Horizontal mortar line
      _paintStroke.color = theme.mortarGroove;
      _paintStroke.strokeWidth = 2.0;
      canvas.drawLine(Offset(0.0, y), Offset(size.width, y), _paintStroke);
    }

    // Vaulted dungeon ceiling shadow arch at top
    final Rect topArchRect = Rect.fromLTWH(0.0, 0.0, size.width, size.height * 0.28);
    _paintFill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        theme.ironShadow,
        theme.ironShadow.withValues(alpha: 0.65),
        Colors.transparent,
      ],
      stops: const <double>[0.0, 0.45, 1.0],
    ).createShader(topArchRect);
    canvas.drawRect(topArchRect, _paintFill);
  }

  /// Paints the heavy 3D wrought-iron bars with cylindrical specular lighting,
  /// crossbeams, rivet studs, drop shadows, and dynamic metallic rim sheen.
  void _paint3DIronBars(Canvas canvas, Size size) {
    final double effectiveOpacity = barsOpacity.clamp(0.0, 1.0);
    if (effectiveOpacity <= 0.0) return;

    // 1. Draw Cast Drop Shadows of bars onto the stone wall behind
    _paintBarDropShadows(canvas, size, effectiveOpacity);

    // 2. Draw Horizontal Crossbeams / dungeon wall mount girders
    _paintHorizontalCrossbeams(canvas, size, effectiveOpacity);

    // 3. Draw Heavy Vertical Wrought-Iron Bars with 3D Cylindrical Shader
    for (final PrisonIronBarConfig bar in ironBars) {
      final double centerX = bar.xRatio * size.width;
      final double halfWidth = bar.barWidth * 0.5;
      final Rect barRect = Rect.fromLTRB(centerX - halfWidth, 0.0, centerX + halfWidth, size.height);

      // Cylindrical normal mapping gradient:
      // Left deep shadow -> Body metal -> Sharp specular highlight stripe -> Base metal -> Right rim reflection
      _paintFill.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          theme.ironShadow.withValues(alpha: effectiveOpacity),
          theme.ironBase.withValues(alpha: effectiveOpacity),
          theme.ironHighlight.withValues(alpha: effectiveOpacity),
          theme.ironSpecularBand.withValues(alpha: effectiveOpacity * 0.95),
          theme.ironHighlight.withValues(alpha: effectiveOpacity),
          theme.ironBase.withValues(alpha: effectiveOpacity),
          theme.ironShadow.withValues(alpha: effectiveOpacity),
        ],
        stops: const <double>[0.0, 0.20, 0.38, 0.45, 0.58, 0.82, 1.0],
      ).createShader(barRect);
      canvas.drawRect(barRect, _paintFill);

      // Dynamic Metallic Rim Sheen Wave: an organic specular gleam sweeping vertically along the bar
      final double wavePhase = (timeSeconds * 1.3 - bar.rimSheenPhase) % (math.pi * 2.0);
      final double waveYCenter = (math.sin(wavePhase) * 0.5 + 0.5) * size.height;
      final Rect gleamRect = Rect.fromLTWH(
        centerX - halfWidth + 1.0,
        waveYCenter - 45.0,
        bar.barWidth - 2.0,
        90.0,
      );
      _paintFill.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.transparent,
          theme.ironSpecularBand.withValues(alpha: 0.35 * effectiveOpacity),
          Colors.transparent,
        ],
      ).createShader(gleamRect);
      canvas.drawRect(gleamRect, _paintFill);

      // Left rim warm torch reflection line
      _paintStroke.shader = null;
      _paintStroke.strokeWidth = 1.0;
      _paintStroke.color = theme.torchRimWarm.withValues(alpha: 0.35 * effectiveOpacity);
      canvas.drawLine(
        Offset(centerX - halfWidth + 0.5, 0.0),
        Offset(centerX - halfWidth + 0.5, size.height),
        _paintStroke,
      );

      // Right rim cool blue moonlight/dungeon reflection line
      _paintStroke.color = theme.dungeonRimCold.withValues(alpha: 0.40 * effectiveOpacity);
      canvas.drawLine(
        Offset(centerX + halfWidth - 0.5, 0.0),
        Offset(centerX + halfWidth - 0.5, size.height),
        _paintStroke,
      );

      // Heavy 3D Iron Rivets / Studs at key structural joints
      for (final double yFraction in bar.rivetYFractions) {
        _paint3DRivet(
          canvas,
          Offset(centerX, yFraction * size.height),
          bar.barWidth * 0.28,
          effectiveOpacity,
        );
      }
    }
  }

  /// Casts soft ambient occlusion shadows from the bars onto the stone wall behind.
  void _paintBarDropShadows(Canvas canvas, Size size, double opacity) {
    for (final PrisonIronBarConfig bar in ironBars) {
      final double centerX = bar.xRatio * size.width + 12.0; // 12px drop shadow offset
      final double halfWidth = bar.barWidth * 0.7;
      final Rect shadowRect = Rect.fromLTRB(centerX - halfWidth, 0.0, centerX + halfWidth, size.height);

      _paintFill.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Colors.transparent,
          theme.ironShadow.withValues(alpha: 0.55 * opacity),
          Colors.transparent,
        ],
      ).createShader(shadowRect);
      canvas.drawRect(shadowRect, _paintFill);
    }
  }

  /// Paints horizontal reinforced wrought iron crossbars / girders at upper & lower bounds.
  void _paintHorizontalCrossbeams(Canvas canvas, Size size, double opacity) {
    const double beamHeight = 22.0;
    final List<double> yPositions = <double>[size.height * 0.12, size.height * 0.88];

    for (final double yCenter in yPositions) {
      final Rect beamRect = Rect.fromLTWH(0.0, yCenter - beamHeight * 0.5, size.width, beamHeight);

      // Horizontal beam cylindrical shading
      _paintFill.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          theme.ironShadow.withValues(alpha: opacity),
          theme.ironBase.withValues(alpha: opacity),
          theme.ironHighlight.withValues(alpha: opacity),
          theme.ironSpecularBand.withValues(alpha: opacity * 0.85),
          theme.ironBase.withValues(alpha: opacity),
          theme.ironShadow.withValues(alpha: opacity),
        ],
        stops: const <double>[0.0, 0.22, 0.40, 0.48, 0.78, 1.0],
      ).createShader(beamRect);
      canvas.drawRect(beamRect, _paintFill);

      // Top edge bevel highlight
      _paintStroke.shader = null;
      _paintStroke.strokeWidth = 1.0;
      _paintStroke.color = theme.ironHighlight.withValues(alpha: 0.50 * opacity);
      canvas.drawLine(beamRect.topLeft, beamRect.topRight, _paintStroke);

      // Bottom edge bevel shadow
      _paintStroke.color = theme.ironShadow.withValues(alpha: 0.85 * opacity);
      canvas.drawLine(beamRect.bottomLeft, beamRect.bottomRight, _paintStroke);
    }
  }

  /// Paints a single 3D forged iron rivet / bolt head with spherical highlight and shadow.
  void _paint3DRivet(Canvas canvas, Offset center, double radius, double opacity) {
    // Drop shadow
    _paintFill.shader = null;
    _paintFill.color = theme.ironShadow.withValues(alpha: 0.65 * opacity);
    canvas.drawCircle(center + const Offset(1.5, 2.0), radius + 0.5, _paintFill);

    // Rivet metallic sphere gradient
    final Rect rivetRect = Rect.fromCircle(center: center, radius: radius);
    _paintFill.shader = RadialGradient(
      center: const Alignment(-0.35, -0.45),
      radius: 0.85,
      colors: <Color>[
        theme.ironSpecularBand.withValues(alpha: opacity),
        theme.ironHighlight.withValues(alpha: opacity),
        theme.ironBase.withValues(alpha: opacity),
        theme.ironShadow.withValues(alpha: opacity),
      ],
      stops: const <double>[0.0, 0.35, 0.75, 1.0],
    ).createShader(rivetRect);
    canvas.drawCircle(center, radius, _paintFill);

    // Outer rim highlight
    _paintStroke.shader = null;
    _paintStroke.strokeWidth = 0.8;
    _paintStroke.color = theme.ironSpecularBand.withValues(alpha: 0.40 * opacity);
    canvas.drawCircle(center, radius, _paintStroke);
  }

  /// Paints floating dungeon dust motes filtered by depth tier.
  void _paintDustMotesByTier(Canvas canvas, Size size, DustMoteTier tier) {
    for (final PrisonDustMote mote in dustMotes) {
      if (mote.tier != tier) continue;

      final Offset pos = mote.computePosition(timeSeconds, size);
      final double alpha = mote.computeAlpha(timeSeconds);
      if (alpha <= 0.01) continue;

      if (tier == DustMoteTier.foreground) {
        // Soft illuminated halo for foreground bokeh motes
        final double haloRadius = mote.radius * 2.8;
        final Rect haloRect = Rect.fromCircle(center: pos, radius: haloRadius);
        _paintFill.shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFDE68A).withValues(alpha: alpha * 0.65),
            const Color(0xFFF59E0B).withValues(alpha: alpha * 0.25),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(haloRect);
        canvas.drawCircle(pos, haloRadius, _paintFill);

        // Core bright nucleus
        _paintFill.shader = null;
        _paintFill.color = Colors.white.withValues(alpha: alpha * 0.85);
        canvas.drawCircle(pos, mote.radius * 0.7, _paintFill);
      } else if (tier == DustMoteTier.midground) {
        // Midground mote with amber tint
        _paintFill.shader = null;
        _paintFill.color = const Color(0xFFFDE68A).withValues(alpha: alpha * 0.60);
        canvas.drawCircle(pos, mote.radius, _paintFill);
      } else {
        // Subtle ambient depth speck
        _paintFill.shader = null;
        _paintFill.color = const Color(0xFF94A3B8).withValues(alpha: alpha * 0.35);
        canvas.drawCircle(pos, mote.radius, _paintFill);
      }
    }
  }

  /// Paints dramatic cinematic vignette and perimeter darkness.
  void _paintVignetteAndAtmosphere(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double maxDim = math.max(size.width, size.height);

    // Deep radial dungeon perimeter falloff
    _paintFill.shader = RadialGradient(
      center: Alignment.center,
      radius: 0.95,
      colors: <Color>[
        Colors.transparent,
        Colors.transparent,
        theme.ironShadow.withValues(alpha: 0.45 * theme.vignetteDarkness),
        theme.ironShadow.withValues(alpha: 0.85 * theme.vignetteDarkness),
      ],
      stops: const <double>[0.0, 0.50, 0.82, 1.0],
    ).createShader(Rect.fromCircle(center: rect.center, radius: maxDim * 0.65));
    canvas.drawRect(rect, _paintFill);

    // Bottom floor grounding shadow
    final Rect bottomGround = Rect.fromLTWH(0.0, size.height * 0.75, size.width, size.height * 0.25);
    _paintFill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Colors.transparent,
        theme.ironShadow.withValues(alpha: 0.75),
      ],
    ).createShader(bottomGround);
    canvas.drawRect(bottomGround, _paintFill);
  }

  /// Paints celebratory golden light rays radiating when player is set free.
  void _paintFreedomRays(Canvas canvas, Size size) {
    final Offset rayCenter = Offset(size.width * 0.5, size.height * 0.18);
    const int numRays = 12;
    const double step = (math.pi * 2.0) / numRays;

    _paintStroke.shader = null;
    _paintStroke.strokeWidth = 2.5;

    for (int i = 0; i < numRays; i++) {
      final double angle = i * step + (timeSeconds * 0.08);
      final double length = size.height * 0.95;
      final Offset end = rayCenter + Offset(math.cos(angle) * length, math.sin(angle) * length);

      final double rayAlpha = (0.08 + 0.04 * math.sin(timeSeconds * 1.5 + i)).clamp(0.0, 1.0);
      _paintStroke.color = AppColors.gold.withValues(alpha: rayAlpha);
      canvas.drawLine(rayCenter, end, _paintStroke);
    }
  }

  @override
  bool shouldRepaint(covariant PrisonCellPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.isInPrison != isInPrison ||
        oldDelegate.showBars != showBars ||
        oldDelegate.showDust != showDust ||
        oldDelegate.showBricks != showBricks ||
        oldDelegate.barsOpacity != barsOpacity ||
        oldDelegate.freedomTransition != freedomTransition;
  }
}

/// A smooth 60fps animated atmosphere widget providing cold stone masonry,
/// floating dungeon dust motes, and 3D wrought iron bars.
class PrisonCellAtmosphere extends StatefulWidget {
  const PrisonCellAtmosphere({
    super.key,
    this.isInPrison = true,
    this.showBars = true,
    this.showDust = true,
    this.showBricks = true,
    this.barsForeground = false,
    this.barsOpacity = 0.85,
    this.theme = PrisonCellTheme.gothicCold,
    this.child,
  });

  /// Whether the player is currently imprisoned or free.
  final bool isInPrison;

  /// Whether to render the 3D wrought iron bars.
  final bool showBars;

  /// Whether to simulate and render floating dust motes.
  final bool showDust;

  /// Whether to render the procedural cold stone masonry wall.
  final bool showBricks;

  /// When true, renders ONLY the foreground iron bars and bokeh dust motes
  /// (designed to be stacked over UI content with [IgnorePointer]).
  final bool barsForeground;

  /// Global opacity multiplier for the iron bars (0.0 to 1.0).
  final double barsOpacity;

  /// Theme styling for the dungeon cell.
  final PrisonCellTheme theme;

  /// Optional child rendered within or on top of the atmosphere.
  final Widget? child;

  @override
  State<PrisonCellAtmosphere> createState() => _PrisonCellAtmosphereState();
}

class _PrisonCellAtmosphereState extends State<PrisonCellAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double timeSeconds = _controller.value * 60.0;

          final CustomPaint customPaint = CustomPaint(
            painter: PrisonCellPainter(
              timeSeconds: timeSeconds,
              theme: widget.theme,
              isInPrison: widget.isInPrison,
              showBars: widget.showBars,
              showDust: widget.showDust,
              showBricks: widget.barsForeground ? false : widget.showBricks,
              barsOpacity: widget.barsOpacity,
            ),
            child: widget.child,
          );

          return customPaint;
        },
      ),
    );
  }
}

/// A dedicated foreground overlay widget rendering ONLY the 3D wrought iron bars
/// and foreground illuminated bokeh dust motes, wrapped in [IgnorePointer] so all
/// underlying UI remains 100% interactive.
class PrisonForegroundBarsOverlay extends StatelessWidget {
  const PrisonForegroundBarsOverlay({
    super.key,
    this.isInPrison = true,
    this.barsOpacity = 0.55,
    this.theme = PrisonCellTheme.gothicCold,
  });

  final bool isInPrison;
  final double barsOpacity;
  final PrisonCellTheme theme;

  @override
  Widget build(BuildContext context) {
    if (!isInPrison || barsOpacity <= 0.0) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: PrisonCellAtmosphere(
        isInPrison: isInPrison,
        showBars: true,
        showDust: true,
        showBricks: false,
        barsForeground: true,
        barsOpacity: barsOpacity,
        theme: theme,
      ),
    );
  }
}
