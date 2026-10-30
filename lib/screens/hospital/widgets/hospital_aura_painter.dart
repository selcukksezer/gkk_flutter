import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Configuration for the celestial sanctuary healing aura and light ray system.
class SanctuaryAuraConfig {
  const SanctuaryAuraConfig({
    this.coreRadius = 28.0,
    this.outerRadius = 140.0,
    this.rayCount = 16,
    this.primaryColor = const Color(0xFF34D399),
    this.secondaryColor = const Color(0xFFFFB800),
    this.accentColor = const Color(0xFF06D0D8),
    this.bloomIntensity = 1.0,
    this.rayRotation = 0.0,
    this.pulseValue = 0.0,
    this.isHealingSurge = false,
    this.showAltarCross = true,
    this.centerOffset = Offset.zero,
    this.harmonicWaveCount = 3,
    this.moteCount = 12,
    this.showHarmonicWaves = true,
    this.showManaMotes = true,
    this.showSacredAstrolabe = true,
  });

  final double coreRadius;
  final double outerRadius;
  final int rayCount;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final double bloomIntensity;
  final double rayRotation;
  final double pulseValue;
  final bool isHealingSurge;
  final bool showAltarCross;
  final Offset centerOffset;
  final int harmonicWaveCount;
  final int moteCount;
  final bool showHarmonicWaves;
  final bool showManaMotes;
  final bool showSacredAstrolabe;

  SanctuaryAuraConfig copyWith({
    double? coreRadius,
    double? outerRadius,
    int? rayCount,
    Color? primaryColor,
    Color? secondaryColor,
    Color? accentColor,
    double? bloomIntensity,
    double? rayRotation,
    double? pulseValue,
    bool? isHealingSurge,
    bool? showAltarCross,
    Offset? centerOffset,
    int? harmonicWaveCount,
    int? moteCount,
    bool? showHarmonicWaves,
    bool? showManaMotes,
    bool? showSacredAstrolabe,
  }) {
    return SanctuaryAuraConfig(
      coreRadius: coreRadius ?? this.coreRadius,
      outerRadius: outerRadius ?? this.outerRadius,
      rayCount: rayCount ?? this.rayCount,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      bloomIntensity: bloomIntensity ?? this.bloomIntensity,
      rayRotation: rayRotation ?? this.rayRotation,
      pulseValue: pulseValue ?? this.pulseValue,
      isHealingSurge: isHealingSurge ?? this.isHealingSurge,
      showAltarCross: showAltarCross ?? this.showAltarCross,
      centerOffset: centerOffset ?? this.centerOffset,
      harmonicWaveCount: harmonicWaveCount ?? this.harmonicWaveCount,
      moteCount: moteCount ?? this.moteCount,
      showHarmonicWaves: showHarmonicWaves ?? this.showHarmonicWaves,
      showManaMotes: showManaMotes ?? this.showManaMotes,
      showSacredAstrolabe: showSacredAstrolabe ?? this.showSacredAstrolabe,
    );
  }
}

/// Static pool of cached Paint and Path objects to eliminate GC heap churn
/// during 60/120 FPS continuous aura animation loops.
class _HospitalAuraCache {
  _HospitalAuraCache._();

  static final Paint glowPaint = Paint()..isAntiAlias = true;
  static final Paint rayMajorPaint = Paint()..isAntiAlias = true;
  static final Paint rayMinorPaint = Paint()..isAntiAlias = true;
  static final Paint sweepPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint waveStrokePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint waveNodePaint = Paint()..isAntiAlias = true;
  static final Paint astrolabeRingPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint astrolabeLinePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint astrolabeNotchPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint astrolabePipPaint = Paint()..isAntiAlias = true;
  static final Paint moteHaloPaint = Paint()..isAntiAlias = true;
  static final Paint moteCorePaint = Paint()..isAntiAlias = true;
  static final Paint wideBloomPaint = Paint()..isAntiAlias = true;
  static final Paint coronaBloomPaint = Paint()..isAntiAlias = true;
  static final Paint hotspotPaint = Paint()..isAntiAlias = true;
  static final Paint crossBackPaint = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xCC05080E)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
  static final Paint crossFillPaint = Paint()..isAntiAlias = true;
  static final Paint crossBorderPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint crossSheenPaint = Paint()..isAntiAlias = true;
  static final Paint gemPaint = Paint()..isAntiAlias = true;
  static final Paint gemBorderPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  static final Paint sparklePaint = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.2);

  // Reusable Paths for zero-allocation geometry assembly
  static final Path majorRaysPath = Path();
  static final Path minorRaysPath = Path();
  static final Path crossPath = Path();
  static final Path starPath = Path();
}

/// CustomPainter rendering divine sanctuary healing aura, radial light rays,
/// celestial wave harmonics, multi-layer bloom glow, sacred astrolabe geometry,
/// floating mana motes, and the celestial altar cross emblem.
class HospitalAuraPainter extends CustomPainter {
  const HospitalAuraPainter({required this.config});

  final SanctuaryAuraConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(
      size.width * 0.5 + config.centerOffset.dx,
      size.height * 0.5 + config.centerOffset.dy,
    );

    final double effectiveOuterRadius = math.min(
      config.outerRadius,
      math.min(size.width, size.height) * 0.5,
    );

    final double surgeBoost = config.isHealingSurge ? 1.35 : 1.0;
    final double pulse = config.pulseValue;

    // 1. Ethereal multi-layered radiant glow
    _paintAtmosphericGlow(canvas, center, effectiveOuterRadius, surgeBoost, pulse);

    // 2. Celestial light rays with batched dual-pass draw calls
    _paintCelestialLightRays(
      canvas,
      center,
      config.coreRadius,
      effectiveOuterRadius,
      surgeBoost,
      pulse,
    );

    // 3. Celestial wave harmonics (expanding healing shockwave ripples)
    if (config.showHarmonicWaves) {
      _paintCelestialWaveHarmonics(
        canvas,
        center,
        config.coreRadius,
        effectiveOuterRadius,
        surgeBoost,
        pulse,
      );
    }

    // 4. Sacred astrolabe runic geometry & octagram chords
    if (config.showSacredAstrolabe) {
      _paintSacredAstrolabeGeometry(
        canvas,
        center,
        config.coreRadius,
        effectiveOuterRadius,
        surgeBoost,
        pulse,
      );
    }

    // 5. Floating astral mana motes & starlight sparks
    if (config.showManaMotes) {
      _paintCelestialManaMotes(
        canvas,
        center,
        config.coreRadius,
        effectiveOuterRadius,
        surgeBoost,
        pulse,
      );
    }

    // 6. Multi-tier bloom glow & celestial hotspot
    _paintBloomGlow(canvas, center, config.coreRadius, surgeBoost, pulse);

    // 7. Celestial Gothic Altar Cross emblem
    if (config.showAltarCross) {
      _paintAltarCross(canvas, center, config.coreRadius, surgeBoost, pulse);
    }
  }

  void _paintAtmosphericGlow(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double surgeBoost,
    double pulse,
  ) {
    final double glowRadius = outerRadius * (1.08 + 0.22 * pulse) * surgeBoost;
    final double baseAlpha = (0.34 *
            config.bloomIntensity *
            (0.82 + 0.18 * pulse) *
            (config.isHealingSurge ? 1.45 : 1.0))
        .clamp(0.0, 1.0);

    // Ethereal multi-layered celestial radiant gradient
    _HospitalAuraCache.glowPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        center,
        glowRadius,
        <Color>[
          Colors.white.withValues(alpha: (0.42 * baseAlpha).clamp(0.0, 1.0)),
          config.accentColor.withValues(alpha: (0.80 * baseAlpha).clamp(0.0, 1.0)),
          config.primaryColor.withValues(alpha: (0.52 * baseAlpha).clamp(0.0, 1.0)),
          config.secondaryColor.withValues(alpha: (0.24 * baseAlpha).clamp(0.0, 1.0)),
          config.accentColor.withValues(alpha: (0.06 * baseAlpha).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        const <double>[0.0, 0.20, 0.45, 0.70, 0.88, 1.0],
      );

    canvas.drawCircle(center, glowRadius, _HospitalAuraCache.glowPaint);
  }

  void _paintCelestialLightRays(
    Canvas canvas,
    Offset center,
    double coreRadius,
    double outerRadius,
    double surgeBoost,
    double pulse,
  ) {
    final int count = config.rayCount;
    final double angleStep = (2 * math.pi) / count;
    final double rot = config.rayRotation;
    final double reach = outerRadius * (0.88 + 0.24 * pulse) * surgeBoost;

    // Reset reusable batched paths to avoid GC allocation in frame loop
    _HospitalAuraCache.majorRaysPath.reset();
    _HospitalAuraCache.minorRaysPath.reset();

    for (int i = 0; i < count; i++) {
      final double baseAngle = rot + i * angleStep;
      final bool isMajor = i % 2 == 0;
      final double halfWidth = isMajor ? (angleStep * 0.28) : (angleStep * 0.14);
      final double rayReach = isMajor ? reach : reach * 0.76;
      final double innerR = coreRadius * 0.55;

      final double x0 = center.dx + math.cos(baseAngle - halfWidth * 0.3) * innerR;
      final double y0 = center.dy + math.sin(baseAngle - halfWidth * 0.3) * innerR;

      final double x1 = center.dx + math.cos(baseAngle - halfWidth) * rayReach;
      final double y1 = center.dy + math.sin(baseAngle - halfWidth) * rayReach;

      final double xTip = center.dx + math.cos(baseAngle) * (rayReach * 1.06);
      final double yTip = center.dy + math.sin(baseAngle) * (rayReach * 1.06);

      final double x2 = center.dx + math.cos(baseAngle + halfWidth) * rayReach;
      final double y2 = center.dy + math.sin(baseAngle + halfWidth) * rayReach;

      final double x3 = center.dx + math.cos(baseAngle + halfWidth * 0.3) * innerR;
      final double y3 = center.dy + math.sin(baseAngle + halfWidth * 0.3) * innerR;

      final Path targetPath = isMajor
          ? _HospitalAuraCache.majorRaysPath
          : _HospitalAuraCache.minorRaysPath;

      targetPath.moveTo(x0, y0);
      targetPath.lineTo(x1, y1);
      targetPath.lineTo(xTip, yTip);
      targetPath.lineTo(x2, y2);
      targetPath.lineTo(x3, y3);
      targetPath.close();
    }

    final double majorAlpha = (0.36 *
            config.bloomIntensity *
            (0.78 + 0.22 * pulse) *
            (config.isHealingSurge ? 1.45 : 1.0))
        .clamp(0.0, 1.0);

    final double minorAlpha = (0.20 *
            config.bloomIntensity *
            (0.72 + 0.28 * pulse) *
            (config.isHealingSurge ? 1.45 : 1.0))
        .clamp(0.0, 1.0);

    // Draw batched major rays with single shader & draw call
    _HospitalAuraCache.rayMajorPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        center,
        reach * 1.06,
        <Color>[
          Colors.white.withValues(alpha: (majorAlpha * 0.90).clamp(0.0, 1.0)),
          config.primaryColor.withValues(alpha: (majorAlpha * 0.70).clamp(0.0, 1.0)),
          config.accentColor.withValues(alpha: (majorAlpha * 0.30).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        const <double>[0.05, 0.38, 0.76, 1.0],
      );
    canvas.drawPath(_HospitalAuraCache.majorRaysPath, _HospitalAuraCache.rayMajorPaint);

    // Draw batched minor rays with single shader & draw call
    _HospitalAuraCache.rayMinorPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        center,
        reach * 0.82,
        <Color>[
          Colors.white.withValues(alpha: (minorAlpha * 0.85).clamp(0.0, 1.0)),
          config.secondaryColor.withValues(alpha: (minorAlpha * 0.65).clamp(0.0, 1.0)),
          config.accentColor.withValues(alpha: (minorAlpha * 0.20).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        const <double>[0.05, 0.35, 0.75, 1.0],
      );
    canvas.drawPath(_HospitalAuraCache.minorRaysPath, _HospitalAuraCache.rayMinorPaint);

    // Counter-rotating celestial sweep ring
    final double revRot = -rot * 0.68;
    _HospitalAuraCache.sweepPaint
      ..strokeWidth = 1.2
      ..maskFilter = null
      ..shader = ui.Gradient.sweep(
        center,
        <Color>[
          config.secondaryColor.withValues(alpha: 0.0),
          config.secondaryColor.withValues(alpha: 0.30 * config.bloomIntensity),
          config.accentColor.withValues(alpha: 0.42 * config.bloomIntensity),
          config.primaryColor.withValues(alpha: 0.18 * config.bloomIntensity),
          config.secondaryColor.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
        TileMode.clamp,
        revRot,
        revRot + 2 * math.pi,
      );

    canvas.drawCircle(center, outerRadius * 0.64, _HospitalAuraCache.sweepPaint);
  }

  void _paintCelestialWaveHarmonics(
    Canvas canvas,
    Offset center,
    double coreRadius,
    double outerRadius,
    double surgeBoost,
    double pulse,
  ) {
    final int harmonics = config.harmonicWaveCount;
    if (harmonics <= 0) return;

    final double span = outerRadius - coreRadius;

    for (int k = 0; k < harmonics; k++) {
      final double phase = (k / harmonics);
      final double progress = (pulse * 0.85 + phase) % 1.0;
      final double rippleRadius = coreRadius + span * progress;

      // Bell curve wave envelope (fade in near core, peak at 35%, fade out at edge)
      final double waveEnvelope = math.sin(progress * math.pi);
      final double waveAlpha = (waveEnvelope *
              (1.0 - progress * 0.55) *
              0.48 *
              config.bloomIntensity *
              surgeBoost)
          .clamp(0.0, 1.0);

      _HospitalAuraCache.waveStrokePaint
        ..shader = null
        ..maskFilter = null
        ..strokeWidth = 1.0 + (1.0 - progress) * 1.6
        ..color = Color.lerp(
          config.accentColor,
          config.primaryColor,
          progress,
        )!
            .withValues(alpha: waveAlpha);

      canvas.drawCircle(center, rippleRadius, _HospitalAuraCache.waveStrokePaint);

      // Sacred harmonic nodes along wave crest when wave is mature
      if (progress > 0.15 && progress < 0.85) {
        final double nodeAlpha = (waveAlpha * 1.3).clamp(0.0, 1.0);
        _HospitalAuraCache.waveNodePaint
          ..shader = null
          ..maskFilter = null
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: nodeAlpha);

        const int nodeCount = 4;
        final double nodeAngleBase = config.rayRotation * 0.4 + k * (math.pi / 4);
        for (int n = 0; n < nodeCount; n++) {
          final double a = nodeAngleBase + n * (math.pi * 2 / nodeCount);
          final double nx = center.dx + math.cos(a) * rippleRadius;
          final double ny = center.dy + math.sin(a) * rippleRadius;
          canvas.drawCircle(Offset(nx, ny), 1.5, _HospitalAuraCache.waveNodePaint);
        }
      }
    }
  }

  void _paintSacredAstrolabeGeometry(
    Canvas canvas,
    Offset center,
    double coreRadius,
    double outerRadius,
    double surgeBoost,
    double pulse,
  ) {
    final double ringRadius1 = coreRadius * (1.46 + 0.08 * pulse);
    final double ringRadius2 = outerRadius * (0.50 + 0.04 * pulse);

    // Inner sacred rune ring with subtle luminous glow
    _HospitalAuraCache.astrolabeRingPaint
      ..shader = null
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0)
      ..color = config.accentColor.withValues(
        alpha: (0.58 * config.bloomIntensity * (0.8 + 0.2 * pulse)).clamp(0.0, 1.0),
      );
    canvas.drawCircle(center, ringRadius1, _HospitalAuraCache.astrolabeRingPaint);

    // Mid celestial orbit ring
    _HospitalAuraCache.astrolabeRingPaint
      ..maskFilter = null
      ..strokeWidth = 1.0
      ..color = config.secondaryColor.withValues(
        alpha: (0.38 * config.bloomIntensity).clamp(0.0, 1.0),
      );
    canvas.drawCircle(center, ringRadius2, _HospitalAuraCache.astrolabeRingPaint);

    // Sacred geometric octagram chords (interlocking star threads)
    final double rot = config.rayRotation * 0.5;
    const int octagramPoints = 8;
    final double step = (2 * math.pi) / octagramPoints;

    _HospitalAuraCache.astrolabeLinePaint
      ..shader = null
      ..maskFilter = null
      ..strokeWidth = 0.7
      ..color = config.secondaryColor.withValues(
        alpha: (0.24 * config.bloomIntensity * (0.8 + 0.2 * pulse)).clamp(0.0, 1.0),
      );

    for (int i = 0; i < octagramPoints; i++) {
      final double a1 = rot + i * step;
      final double a2 = rot + ((i + 3) % octagramPoints) * step;

      final Offset p1 = Offset(
        center.dx + math.cos(a1) * ringRadius2,
        center.dy + math.sin(a1) * ringRadius2,
      );
      final Offset p2 = Offset(
        center.dx + math.cos(a2) * ringRadius2,
        center.dy + math.sin(a2) * ringRadius2,
      );

      canvas.drawLine(p1, p2, _HospitalAuraCache.astrolabeLinePaint);
    }

    // Dial notches along outer ring
    _HospitalAuraCache.astrolabeNotchPaint
      ..shader = null
      ..maskFilter = null
      ..strokeWidth = 1.8
      ..color = Colors.white.withValues(
        alpha: (0.68 * config.bloomIntensity * (0.7 + 0.3 * pulse)).clamp(0.0, 1.0),
      );

    for (int i = 0; i < octagramPoints; i++) {
      final double a = rot + i * step;
      final bool major = i % 2 == 0;
      final double rIn = ringRadius2 - (major ? 5.5 : 3.0);
      final double rOut = ringRadius2 + (major ? 5.5 : 3.0);

      canvas.drawLine(
        Offset(center.dx + math.cos(a) * rIn, center.dy + math.sin(a) * rIn),
        Offset(center.dx + math.cos(a) * rOut, center.dy + math.sin(a) * rOut),
        _HospitalAuraCache.astrolabeNotchPaint,
      );
    }

    // Cardinal sacred diamonds on inner ring
    _HospitalAuraCache.astrolabePipPaint
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.fill
      ..color = config.accentColor.withValues(
        alpha: (0.85 * config.bloomIntensity).clamp(0.0, 1.0),
      );

    const int cardinalCount = 4;
    final double cardStep = (2 * math.pi) / cardinalCount;
    final double cardRot = -rot * 0.4;
    for (int c = 0; c < cardinalCount; c++) {
      final double a = cardRot + c * cardStep;
      final double px = center.dx + math.cos(a) * ringRadius1;
      final double py = center.dy + math.sin(a) * ringRadius1;

      _HospitalAuraCache.starPath.reset();
      _HospitalAuraCache.starPath.moveTo(px, py - 3.2);
      _HospitalAuraCache.starPath.lineTo(px + 2.2, py);
      _HospitalAuraCache.starPath.lineTo(px, py + 3.2);
      _HospitalAuraCache.starPath.lineTo(px - 2.2, py);
      _HospitalAuraCache.starPath.close();

      canvas.drawPath(_HospitalAuraCache.starPath, _HospitalAuraCache.astrolabePipPaint);
    }
  }

  void _paintCelestialManaMotes(
    Canvas canvas,
    Offset center,
    double coreRadius,
    double outerRadius,
    double surgeBoost,
    double pulse,
  ) {
    final int count = config.moteCount;
    if (count <= 0) return;

    final double rot = config.rayRotation;
    final double span = outerRadius - coreRadius * 1.35;

    for (int m = 0; m < count; m++) {
      final double orbitSpeed = 0.55 + (m % 4) * 0.18;
      final double angle = rot * orbitSpeed + m * (2 * math.pi / count);

      // Harmonic oscillation in distance
      final double harmonicDist =
          math.sin(pulse * 3.14159 + m * 1.61803) * 0.5 + 0.5;
      final double dist = coreRadius * 1.35 + span * (0.15 + 0.75 * harmonicDist);

      final double mx = center.dx + math.cos(angle) * dist;
      final double my = center.dy + math.sin(angle) * dist;
      final Offset mPos = Offset(mx, my);

      final double moteBlink = math.cos(pulse * 2.8 + m * 2.1) * 0.5 + 0.5;
      final double alpha = (moteBlink * 0.75 * config.bloomIntensity * surgeBoost)
          .clamp(0.0, 1.0);

      final double radius = 1.4 + 1.2 * moteBlink;

      // Soft starlight halo
      _HospitalAuraCache.moteHaloPaint
        ..shader = null
        ..maskFilter = null
        ..style = PaintingStyle.fill
        ..color = (m % 2 == 0 ? config.accentColor : config.secondaryColor)
            .withValues(alpha: (alpha * 0.45).clamp(0.0, 1.0));
      canvas.drawCircle(mPos, radius * 2.4, _HospitalAuraCache.moteHaloPaint);

      // Bright specular starlight core
      _HospitalAuraCache.moteCorePaint
        ..shader = null
        ..maskFilter = null
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: (alpha * 0.95).clamp(0.0, 1.0));
      canvas.drawCircle(mPos, radius, _HospitalAuraCache.moteCorePaint);
    }
  }

  void _paintBloomGlow(
    Canvas canvas,
    Offset center,
    double coreRadius,
    double surgeBoost,
    double pulse,
  ) {
    final double bloomR = coreRadius * (2.1 + 0.48 * pulse) * surgeBoost;

    // Wide atmospheric bloom
    _HospitalAuraCache.wideBloomPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        center,
        bloomR,
        <Color>[
          config.primaryColor.withValues(
            alpha: (0.48 * config.bloomIntensity * (0.8 + 0.2 * pulse)).clamp(0.0, 1.0),
          ),
          config.accentColor.withValues(
            alpha: (0.24 * config.bloomIntensity).clamp(0.0, 1.0),
          ),
          Colors.transparent,
        ],
        const <double>[0.0, 0.45, 1.0],
      );
    canvas.drawCircle(center, bloomR, _HospitalAuraCache.wideBloomPaint);

    // Intermediate corona
    final double coronaR = coreRadius * (1.35 + 0.25 * pulse);
    _HospitalAuraCache.coronaBloomPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        center,
        coronaR,
        <Color>[
          config.secondaryColor.withValues(
            alpha: (0.35 * config.bloomIntensity * (0.85 + 0.15 * pulse)).clamp(0.0, 1.0),
          ),
          config.accentColor.withValues(
            alpha: (0.18 * config.bloomIntensity).clamp(0.0, 1.0),
          ),
          Colors.transparent,
        ],
        const <double>[0.0, 0.50, 1.0],
      );
    canvas.drawCircle(center, coronaR, _HospitalAuraCache.coronaBloomPaint);

    // Core ultra-bright hotspot
    final double coreHotspotR = coreRadius * (0.82 + 0.16 * pulse);
    _HospitalAuraCache.hotspotPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        center,
        coreHotspotR,
        <Color>[
          Colors.white.withValues(alpha: 0.98),
          config.accentColor.withValues(alpha: 0.78),
          config.primaryColor.withValues(alpha: 0.22),
          Colors.transparent,
        ],
        const <double>[0.0, 0.35, 0.70, 1.0],
      );
    canvas.drawCircle(center, coreHotspotR, _HospitalAuraCache.hotspotPaint);
  }

  void _paintAltarCross(
    Canvas canvas,
    Offset center,
    double coreRadius,
    double surgeBoost,
    double pulse,
  ) {
    final double armLength = coreRadius * 0.94;
    final double armThickness = coreRadius * 0.32;
    final double flareOffset = coreRadius * 0.08;

    final double l = center.dx - armLength;
    final double r = center.dx + armLength;
    final double t = center.dy - armThickness * 0.5;
    final double b = center.dy + armThickness * 0.5;

    final double vt = center.dy - armLength * 1.15;
    final double vb = center.dy + armLength * 1.35;
    final double vl = center.dx - armThickness * 0.5;
    final double vr = center.dx + armThickness * 0.5;

    // Reset reusable cross path
    _HospitalAuraCache.crossPath.reset();
    _HospitalAuraCache.crossPath.moveTo(vl, t);
    _HospitalAuraCache.crossPath.lineTo(vl, vt + flareOffset);
    _HospitalAuraCache.crossPath.lineTo(center.dx, vt - flareOffset);
    _HospitalAuraCache.crossPath.lineTo(vr, vt + flareOffset);
    _HospitalAuraCache.crossPath.lineTo(vr, t);

    _HospitalAuraCache.crossPath.lineTo(r - flareOffset, t);
    _HospitalAuraCache.crossPath.lineTo(r + flareOffset, center.dy);
    _HospitalAuraCache.crossPath.lineTo(r - flareOffset, b);
    _HospitalAuraCache.crossPath.lineTo(vr, b);

    _HospitalAuraCache.crossPath.lineTo(vr, vb - flareOffset);
    _HospitalAuraCache.crossPath.lineTo(center.dx, vb + flareOffset);
    _HospitalAuraCache.crossPath.lineTo(vl, vb - flareOffset);
    _HospitalAuraCache.crossPath.lineTo(vl, b);

    _HospitalAuraCache.crossPath.lineTo(l + flareOffset, b);
    _HospitalAuraCache.crossPath.lineTo(l - flareOffset, center.dy);
    _HospitalAuraCache.crossPath.lineTo(l + flareOffset, t);
    _HospitalAuraCache.crossPath.close();

    // 1. Drop shadow with ambient occlusion blur
    canvas.drawPath(_HospitalAuraCache.crossPath, _HospitalAuraCache.crossBackPaint);

    // 2. High-depth multi-stop linear gradient fill
    _HospitalAuraCache.crossFillPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.linear(
        Offset(center.dx, vt),
        Offset(center.dx, vb),
        <Color>[
          const Color(0xFFE8FCF8),
          config.primaryColor,
          const Color(0xFF0F766E),
          const Color(0xFF042F2E),
        ],
        const <double>[0.0, 0.40, 0.80, 1.0],
      );
    canvas.drawPath(_HospitalAuraCache.crossPath, _HospitalAuraCache.crossFillPaint);

    // 3. Frosted glass upper sheen
    _HospitalAuraCache.crossSheenPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.linear(
        Offset(center.dx, vt),
        Offset(center.dx, center.dy),
        <Color>[
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 1.0],
      );
    canvas.drawPath(_HospitalAuraCache.crossPath, _HospitalAuraCache.crossSheenPaint);

    // 4. Luminous golden metallic bevel border
    _HospitalAuraCache.crossBorderPaint
      ..strokeWidth = 1.6
      ..maskFilter = null
      ..shader = ui.Gradient.linear(
        Offset(center.dx, vt),
        Offset(center.dx, vb),
        <Color>[
          Colors.white,
          config.secondaryColor,
          const Color(0xFFD97706),
        ],
        const <double>[0.0, 0.50, 1.0],
      );
    canvas.drawPath(_HospitalAuraCache.crossPath, _HospitalAuraCache.crossBorderPaint);

    // 5. Central faceted divine jewel
    final double gemRadius = armThickness * 0.56;
    _HospitalAuraCache.gemPaint
      ..style = PaintingStyle.fill
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        center,
        gemRadius,
        <Color>[
          Colors.white,
          config.secondaryColor,
          config.accentColor,
        ],
        const <double>[0.0, 0.45, 1.0],
      );
    canvas.drawCircle(center, gemRadius, _HospitalAuraCache.gemPaint);

    _HospitalAuraCache.gemBorderPaint
      ..strokeWidth = 1.2
      ..maskFilter = null
      ..color = Colors.white;
    canvas.drawCircle(center, gemRadius, _HospitalAuraCache.gemBorderPaint);

    // 6. Central 8-point specular starburst
    final double starRot = config.rayRotation * 0.8;
    final Paint starStrokePaint = _HospitalAuraCache.gemBorderPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: (0.75 + 0.25 * pulse).clamp(0.0, 1.0));

    final double starRay = gemRadius * 1.5;
    for (int s = 0; s < 4; s++) {
      final double sa = starRot + s * (math.pi / 4);
      final double dx = math.cos(sa) * starRay;
      final double dy = math.sin(sa) * starRay;
      canvas.drawLine(
        Offset(center.dx - dx, center.dy - dy),
        Offset(center.dx + dx, center.dy + dy),
        starStrokePaint,
      );
    }

    // 7. 4 corner diagonal starlight sparkles
    final double sparkleAlpha = (0.88 * (0.68 + 0.32 * pulse)).clamp(0.0, 1.0);
    _HospitalAuraCache.sparklePaint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: sparkleAlpha);

    final double dOffset = armLength * 0.72;
    canvas.drawCircle(Offset(center.dx - dOffset, center.dy - dOffset), 1.9, _HospitalAuraCache.sparklePaint);
    canvas.drawCircle(Offset(center.dx + dOffset, center.dy - dOffset), 1.9, _HospitalAuraCache.sparklePaint);
    canvas.drawCircle(Offset(center.dx - dOffset, center.dy + dOffset), 1.9, _HospitalAuraCache.sparklePaint);
    canvas.drawCircle(Offset(center.dx + dOffset, center.dy + dOffset), 1.9, _HospitalAuraCache.sparklePaint);
  }

  @override
  bool shouldRepaint(covariant HospitalAuraPainter oldDelegate) {
    final SanctuaryAuraConfig o = oldDelegate.config;
    final SanctuaryAuraConfig n = config;
    if (identical(o, n)) return false;
    return o.rayRotation != n.rayRotation ||
        o.pulseValue != n.pulseValue ||
        o.bloomIntensity != n.bloomIntensity ||
        o.isHealingSurge != n.isHealingSurge ||
        o.showAltarCross != n.showAltarCross ||
        o.primaryColor != n.primaryColor ||
        o.secondaryColor != n.secondaryColor ||
        o.accentColor != n.accentColor ||
        o.coreRadius != n.coreRadius ||
        o.outerRadius != n.outerRadius ||
        o.centerOffset != n.centerOffset ||
        o.rayCount != n.rayCount ||
        o.harmonicWaveCount != n.harmonicWaveCount ||
        o.moteCount != n.moteCount ||
        o.showHarmonicWaves != n.showHarmonicWaves ||
        o.showManaMotes != n.showManaMotes ||
        o.showSacredAstrolabe != n.showSacredAstrolabe;
  }
}

/// Standalone animated widget rendering the divine sanctuary healing aura.
/// Automatically handles continuous celestial rotation and breathing pulse.
class HospitalAuraWidget extends StatefulWidget {
  const HospitalAuraWidget({
    super.key,
    this.size,
    this.width,
    this.height,
    this.isHealing = false,
    this.showAltarCross = true,
    this.intensity = 1.0,
    this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.harmonicWaveCount = 3,
    this.moteCount = 12,
    this.showHarmonicWaves = true,
    this.showManaMotes = true,
    this.showSacredAstrolabe = true,
    this.child,
  });

  final double? size;
  final double? width;
  final double? height;
  final bool isHealing;
  final bool showAltarCross;
  final double intensity;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? accentColor;
  final int harmonicWaveCount;
  final int moteCount;
  final bool showHarmonicWaves;
  final bool showManaMotes;
  final bool showSacredAstrolabe;
  final Widget? child;

  @override
  State<HospitalAuraWidget> createState() => _HospitalAuraWidgetState();
}

class _HospitalAuraWidgetState extends State<HospitalAuraWidget>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant HospitalAuraWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHealing != oldWidget.isHealing) {
      if (widget.isHealing) {
        _pulseController.duration = const Duration(milliseconds: 1400);
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.duration = const Duration(milliseconds: 3200);
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double w = widget.size ?? widget.width ?? 260.0;
    final double h = widget.size ?? widget.height ?? 260.0;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_rotationController, _pulseAnimation]),
      builder: (BuildContext context, Widget? child) {
        final double pulse = _pulseAnimation.value;
        final double rotation = _rotationController.value * 2 * math.pi;

        final SanctuaryAuraConfig config = SanctuaryAuraConfig(
          coreRadius: math.min(w, h) * 0.16,
          outerRadius: math.min(w, h) * 0.48,
          primaryColor: widget.primaryColor ?? AppColors.accentTeal,
          secondaryColor: widget.secondaryColor ?? AppColors.liquidGold,
          accentColor: widget.accentColor ?? AppColors.accentCyan,
          bloomIntensity: widget.intensity * (widget.isHealing ? 1.4 : 1.0),
          rayRotation: rotation,
          pulseValue: pulse,
          isHealingSurge: widget.isHealing,
          showAltarCross: widget.showAltarCross,
          harmonicWaveCount: widget.harmonicWaveCount,
          moteCount: widget.moteCount,
          showHarmonicWaves: widget.showHarmonicWaves,
          showManaMotes: widget.showManaMotes,
          showSacredAstrolabe: widget.showSacredAstrolabe,
        );

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(w, h),
                  painter: HospitalAuraPainter(config: config),
                ),
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Ambient full-bleed or card-level backdrop for the hospital sanctuary screen.
class HospitalSanctuaryBackdrop extends StatelessWidget {
  const HospitalSanctuaryBackdrop({
    super.key,
    this.isHealing = false,
    this.topOffset = -40.0,
    this.auraSize = 360.0,
  });

  final bool isHealing;
  final double topOffset;
  final double auraSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 1. High-fidelity celestial sanctuary temple artwork
          Positioned.fill(
            child: Image.asset(
              'assets/images/backgrounds/elysea/bg_heiron_temple.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.bgDeep),
            ),
          ),
          // 2. Atmospheric vignette & darkening gradient for crystal-clear HUD legibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.bgDeep.withValues(alpha: 0.50),
                    AppColors.bgDeep.withValues(alpha: 0.75),
                    AppColors.bgDeep.withValues(alpha: 0.94),
                  ],
                  stops: const <double>[0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          // 3. Central divine aura rays
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: Center(
              child: HospitalAuraWidget(
                size: auraSize,
                isHealing: isHealing,
                showAltarCross: false,
                intensity: 0.85,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ornate glassmorphic Sanctuary Altar header card displaying the central altar cross,
/// animated divine aura rays, and sanctuary status badge.
class HospitalAltarHeader extends StatelessWidget {
  const HospitalAltarHeader({
    super.key,
    required this.inHospital,
    this.isHealing = false,
    this.remainingCountdown,
    this.energyRatio,
  });

  final bool inHospital;
  final bool isHealing;
  final String? remainingCountdown;
  final String? energyRatio;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = inHospital
        ? AppColors.accentTeal
        : AppColors.toxicNeon;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: isHealing ? 0.65 : 0.32),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor.withValues(alpha: isHealing ? 0.28 : 0.12),
            blurRadius: isHealing ? 24 : 16,
            offset: const Offset(0, 6),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.bgCard.withValues(alpha: 0.92),
            AppColors.bgSurface.withValues(alpha: 0.86),
            const Color(0xFF0F231F).withValues(alpha: 0.82),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Stack(
          children: <Widget>[
            Positioned(
              top: -24,
              right: -24,
              child: HospitalAuraWidget(
                size: 160,
                isHealing: isHealing,
                showAltarCross: false,
                intensity: 0.7,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  HospitalAuraWidget(
                    size: 88,
                    isHealing: isHealing,
                    showAltarCross: true,
                    intensity: 1.15,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                inHospital ? 'SANCTUARY' : 'BLESSED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (energyRatio != null)
                              Text(
                                energyRatio!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          inHospital
                              ? 'Kutsal Şifa Mabedi'
                              : 'İlahi Koruma Altındasın',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          inHospital
                              ? (isHealing
                                  ? '✨ İlahi şifa enerjisi akıyor...'
                                  : 'Işık ve hayat gücü aurası seni onarıyor.')
                              : 'Tüm yaraların sarıldı, hayat gücün dorukta.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: isHealing
                                ? AppColors.accentCyan
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (inHospital && remainingCountdown != null) ...<Widget>[
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 13,
                                color: accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Kalan İyileşme: $remainingCountdown',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
