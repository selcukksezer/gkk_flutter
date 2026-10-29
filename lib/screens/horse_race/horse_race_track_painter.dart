import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Vertical track geometry — start bottom, finish top; lanes left→right.
///
/// [size] is the race viewport (below chrome HUD), not the full screen.
abstract final class HorseRaceTrackLayout {
  static const double leftRailFraction = 0.04;
  static const double rightRailFraction = 0.04;
  static const double trackStartY = 0.90;

  /// Finish sits near top of the inset viewport (chrome lives outside).
  static const double trackEndY = 0.10;
  static const double finishLineY = 0.10;

  static Rect trackRect(Size size) {
    final double left = size.width * leftRailFraction;
    final double right = size.width * rightRailFraction;
    return Rect.fromLTWH(
      left,
      0,
      size.width - left - right,
      size.height,
    );
  }

  static double laneCenterX(Size size, int laneIndex, int laneCount) {
    final Rect track = trackRect(size);
    final double laneWidth = track.width / math.max(laneCount, 1);
    return track.left + laneWidth * (laneIndex + 0.5);
  }

  static double laneWidth(Size size, int laneCount) {
    return trackRect(size).width / math.max(laneCount, 1);
  }

  /// Progress 0 = start (bottom), 1 = finish (top).
  static double horseY(Size size, double position) {
    final double startY = size.height * trackStartY;
    final double endY = size.height * trackEndY;
    return startY + (endY - startY) * position.clamp(0.0, 1.0);
  }

  static double horseSize(int laneCount) {
    if (laneCount <= 3) return 52;
    if (laneCount <= 5) return 44;
    return 38;
  }
}

/// 2027 Aion 2 Modern Vertical Track Painter.
///
/// Features:
/// - Atmospheric stadium lighting with volumetric god-ray cones
/// - Multi-layered turf gradient with manicured cross-cut mower stripes
/// - Hoof-worn earthen racing grooves down lane centers
/// - Rail ambient occlusion depth shading and illuminated curbs
/// - Dynamic flowing lane chevrons and glowing neon dividers
/// - Atmospheric track dust plumes and kicked-up turf motes
/// - Multi-tiered finish line luminous bloom with architectural beacons
class HorseRaceTrackPainter extends CustomPainter {
  HorseRaceTrackPainter({
    required this.laneCount,
    required this.laneColors,
    this.scrollOffset = 0,
    this.raceProgress = 0,
    this.gateOpen = false,
    this.finalStretch = false,
    this.showSpeedLines = false,
    this.horsePositions,
  });

  final int laneCount;
  final List<Color> laneColors;
  final double scrollOffset;
  final double raceProgress;
  final bool gateOpen;
  final bool finalStretch;
  final bool showSpeedLines;
  final List<double>? horsePositions;

  static const Color _carbon = AppColors.carbonVoid;
  static const Color _turfDeep = Color(0xFF0D2818);
  static const Color _turfDark = Color(0xFF143B22);
  static const Color _turfMid = Color(0xFF1D5230);
  static const Color _turfLight = Color(0xFF266D40);
  static const Color _turfLush = Color(0xFF2F854F);
  static const Color _dirt = Color(0xFF4A3324);
  static const Color _dirtDark = Color(0xFF2E2017);
  static const Color _dirtTread = Color(0xFF1E150F);

  Paint _paint({bool antiAlias = true}) => Paint()..isAntiAlias = antiAlias;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;

    // 1. Atmospheric sky & stadium lighting
    _drawSky(canvas, bounds, size);

    // 2. Track bed & multi-layered turf
    _drawTrack(canvas, size);

    // 3. Side rails, curbs & ambient occlusion
    _drawSideRails(canvas, size);

    // 4. Atmospheric track dust plumes & turf wear
    _drawTrackDustAndHoofPrints(canvas, size);

    // 5. Distance milestone gates
    _drawDistanceMarkers(canvas, size);

    // 6. Speed lines & wind streaks
    if (showSpeedLines) _drawSpeedLines(canvas, size);

    // 7. Mechanical start gate
    _drawStartGate(canvas, size);

    // 8. Volumetric luminous finish line & pylons
    _drawFinishLine(canvas, size);

    // 9. Final stretch intensity banner
    if (finalStretch) _drawFinalStretchBanner(canvas, size);
  }

  void _drawSky(Canvas canvas, Rect bounds, Size size) {
    // Cinematic deep night sky with celestial purple/blue horizon
    final Paint sky = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF0F1A30),
          const Color(0xFF1D1B2E),
          const Color(0xFF181513),
          _carbon,
        ],
        stops: const <double>[0.0, 0.28, 0.65, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, sky);

    // Stadium arena glow & volumetric light haze
    final Paint stadiumGlow = _paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.08),
        size.width * 0.85,
        <Color>[
          AppColors.liquidGold.withValues(alpha: 0.22),
          AppColors.cyberFuchsia.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        <double>[0.0, 0.45, 1.0],
      );
    canvas.drawRect(bounds, stadiumGlow);

    // Volumetric floodlight cones from left and right stadium pylons
    _drawVolumetricFloodlightCone(
      canvas,
      apex: Offset(size.width * 0.02, size.height * 0.04),
      targetCenter: Offset(size.width * 0.45, size.height * 0.35),
      spread: 60,
      color: AppColors.liquidGold.withValues(alpha: 0.07),
    );
    _drawVolumetricFloodlightCone(
      canvas,
      apex: Offset(size.width * 0.98, size.height * 0.04),
      targetCenter: Offset(size.width * 0.55, size.height * 0.35),
      spread: 60,
      color: AppColors.accentCyan.withValues(alpha: 0.06),
    );
  }

  void _drawVolumetricFloodlightCone(
    Canvas canvas, {
    required Offset apex,
    required Offset targetCenter,
    required double spread,
    required Color color,
  }) {
    final Path cone = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(targetCenter.dx - spread, targetCenter.dy)
      ..lineTo(targetCenter.dx + spread, targetCenter.dy)
      ..close();

    final Paint conePaint = _paint()
      ..shader = ui.Gradient.linear(
        apex,
        targetCenter,
        <Color>[color, color.withValues(alpha: 0.0)],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawPath(cone, conePaint);
  }

  void _drawSideRails(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);

    // Outer gravel/dirt shoulders with earthen gradient
    final Paint leftShoulder = _paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          _dirtDark,
          _dirt.withValues(alpha: 0.95),
          _dirtDark.withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, track.left, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, track.left, size.height), leftShoulder);

    final Paint rightShoulder = _paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          _dirtDark.withValues(alpha: 0.8),
          _dirt.withValues(alpha: 0.95),
          _dirtDark,
        ],
      ).createShader(
        Rect.fromLTWH(track.right, 0, size.width - track.right, size.height),
      );
    canvas.drawRect(
      Rect.fromLTWH(track.right, 0, size.width - track.right, size.height),
      rightShoulder,
    );

    // 3D Ambient Occlusion inner rail shadow cast onto the turf
    final Paint leftInnerShadow = _paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.48),
          Colors.black.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(track.left, 0, 16, size.height));
    canvas.drawRect(
      Rect.fromLTWH(track.left, 0, 16, size.height),
      leftInnerShadow,
    );

    final Paint rightInnerShadow = _paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.48),
          Colors.black.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(track.right - 16, 0, 16, size.height));
    canvas.drawRect(
      Rect.fromLTWH(track.right - 16, 0, 16, size.height),
      rightInnerShadow,
    );

    // Modern illuminated curb rails with bevel highlight
    final Paint railCurbLeft = _paint()
      ..color = const Color(0xFF2C3240)
      ..strokeWidth = 3.0;
    final Paint railCurbRight = _paint()
      ..color = const Color(0xFF2C3240)
      ..strokeWidth = 3.0;
    canvas.drawLine(
      Offset(track.left, 0),
      Offset(track.left, size.height),
      railCurbLeft,
    );
    canvas.drawLine(
      Offset(track.right, 0),
      Offset(track.right, size.height),
      railCurbRight,
    );

    // Reflective neon cat's-eye LED studs spaced along the rail
    final Paint ledStud = _paint()..style = PaintingStyle.fill;
    final double studOffset = (-scrollOffset * 0.8) % 36;
    for (double y = studOffset - 36; y < size.height + 36; y += 36) {
      if (y < 0 || y > size.height) continue;
      ledStud.color = AppColors.liquidGold.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(track.left - 1, y), 2.0, ledStud);
      ledStud.color = AppColors.accentCyan.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(track.right + 1, y), 2.0, ledStud);
    }

    // Fence posts with metallic depth caps
    final Paint fencePost = _paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.6;
    final Paint fencePostShadow = _paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 2.0;

    for (double y = 0; y < size.height; y += 22) {
      // Left fence posts
      canvas.drawLine(
        Offset(track.left - 8, y + 1.5),
        Offset(track.left, y + 1.5),
        fencePostShadow,
      );
      canvas.drawLine(
        Offset(track.left - 8, y),
        Offset(track.left, y),
        fencePost,
      );

      // Right fence posts
      canvas.drawLine(
        Offset(track.right, y + 1.5),
        Offset(track.right + 8, y + 1.5),
        fencePostShadow,
      );
      canvas.drawLine(
        Offset(track.right, y),
        Offset(track.right + 8, y),
        fencePost,
      );
    }
  }

  void _drawTrack(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double laneW = HorseRaceTrackLayout.laneWidth(size, laneCount);

    // 1. Realistic vertical perspective turf gradient (horizon depth to camera foreground)
    final Paint turfBase = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[_turfDeep, _turfDark, _turfMid, _turfLight, _turfLush],
        stops: const <double>[0.0, 0.25, 0.55, 0.82, 1.0],
      ).createShader(track);
    canvas.drawRect(track, turfBase);

    // 2. Manicured cross-cut lawn mower stripes (championship stadium turf pattern)
    final Paint mowerStripeLight = _paint()
      ..color = Colors.white.withValues(alpha: 0.045);
    final double stripeH = 32.0;
    final double mowerScroll = (-scrollOffset * 0.9) % (stripeH * 2);
    for (double y = mowerScroll - stripeH * 2;
        y < track.height + stripeH;
        y += stripeH * 2) {
      canvas.drawRect(
        Rect.fromLTWH(track.left, track.top + y, track.width, stripeH),
        mowerStripeLight,
      );
    }

    // 3. Dynamic stadium light specular glint scrolling with camera
    final double glintY = (scrollOffset * 1.2) % (track.height * 1.5) - 80;
    final Paint grassSpecular = _paint()
      ..shader = ui.Gradient.linear(
        Offset(track.left, track.top + glintY),
        Offset(track.right, track.top + glintY + 90),
        <Color>[
          Colors.transparent,
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        <double>[0.0, 0.5, 1.0],
      );
    canvas.drawRect(track, grassSpecular);

    // 4. Per-lane rendering: wear groove, silk highlights, dynamic flow chevrons, and lane numbers
    for (int i = 0; i < laneCount; i++) {
      final double left = track.left + i * laneW;
      final Color laneColor = i < laneColors.length
          ? laneColors[i]
          : AppColors.mutedTitanium;
      final Rect laneRect = Rect.fromLTWH(left, track.top, laneW, track.height);

      // Alternating subtle lane shade
      if (i.isOdd) {
        final Paint alt = _paint()
          ..color = Colors.black.withValues(alpha: 0.05);
        canvas.drawRect(laneRect, alt);
      }

      // Worn central hoof channel (earthen groove where horses run the most)
      final double grooveW = laneW * 0.42;
      final double grooveX = left + (laneW - grooveW) * 0.5;
      final Paint groove = _paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            _dirtTread.withValues(alpha: 0.0),
            _dirtTread.withValues(alpha: 0.18),
            _dirtTread.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromLTWH(grooveX, track.top, grooveW, track.height),
        );
      canvas.drawRect(
        Rect.fromLTWH(grooveX, track.top, grooveW, track.height),
        groove,
      );

      // Silk aura gradient along the lane
      final Paint silk = _paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            laneColor.withValues(alpha: 0.08),
            laneColor.withValues(alpha: 0.16),
            laneColor.withValues(alpha: 0.05),
          ],
        ).createShader(laneRect);
      canvas.drawRect(laneRect, silk);

      // Dynamic flow chevrons along the lane center
      _drawLaneFlowChevrons(canvas, left, laneW, track.height, laneColor);

      // Lane divider: bevel depth + luminous dashed line
      if (i > 0) {
        // Sunken channel shadow
        final Paint dividerShadow = _paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..strokeWidth = 2.0;
        canvas.drawLine(
          Offset(left - 0.5, track.top),
          Offset(left - 0.5, track.bottom),
          dividerShadow,
        );

        // Luminous dashed boundary
        final Paint divider = _paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..strokeWidth = 1.0;
        const double dashLen = 14.0;
        const double gapLen = 10.0;
        final double dashStart = (-scrollOffset * 0.9) % (dashLen + gapLen);
        for (double dy = dashStart - (dashLen + gapLen);
            dy < track.height;
            dy += dashLen + gapLen) {
          final double y1 = (track.top + dy).clamp(track.top, track.bottom);
          final double y2 = (track.top + dy + dashLen).clamp(
            track.top,
            track.bottom,
          );
          if (y2 > y1) {
            canvas.drawLine(Offset(left, y1), Offset(left, y2), divider);
          }
        }
      }

      // Dynamic 3D lane badge at start line
      _drawModernLaneNumber(canvas, i, left, laneW, laneColor, size);
    }
  }

  void _drawLaneFlowChevrons(
    Canvas canvas,
    double left,
    double laneW,
    double trackH,
    Color laneColor,
  ) {
    final double centerX = left + laneW * 0.5;
    const double chevronGap = 88.0;
    final double offset = (-scrollOffset * 1.1) % chevronGap;
    final Paint chevronPaint = _paint()
      ..color = laneColor.withValues(
        alpha: finalStretch ? 0.22 : (raceProgress > 0 ? 0.12 : 0.06),
      )
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (double y = offset - chevronGap; y < trackH + chevronGap; y += chevronGap) {
      if (y < 20 || y > trackH - 20) continue;
      final Path chevron = Path()
        ..moveTo(centerX - 8, y + 5)
        ..lineTo(centerX, y)
        ..lineTo(centerX + 8, y + 5);
      canvas.drawPath(chevron, chevronPaint);
    }
  }

  void _drawModernLaneNumber(
    Canvas canvas,
    int index,
    double left,
    double laneW,
    Color laneColor,
    Size size,
  ) {
    final double badgeY = size.height * HorseRaceTrackLayout.trackStartY + 8;
    const double badgeW = 26.0;
    const double badgeH = 26.0;
    final Rect badge = Rect.fromLTWH(
      left + laneW * 0.5 - badgeW * 0.5,
      badgeY,
      badgeW,
      badgeH,
    );

    // Drop shadow
    final Paint shadow = _paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        badge.shift(const Offset(0, 2)),
        const Radius.circular(7),
      ),
      shadow,
    );

    // Glowing halo
    final Paint halo = _paint()
      ..color = laneColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(7)),
      halo,
    );

    // Glassmorphic / metallic frame
    final Paint bg = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          laneColor,
          laneColor.withValues(alpha: 0.8),
          const Color(0xFF161A22),
        ],
      ).createShader(badge);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(7)),
      bg,
    );

    // Metallic beveled border
    final Paint border = _paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.85),
          laneColor.withValues(alpha: 0.5),
        ],
      ).createShader(badge);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(7)),
      border,
    );

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: Colors.white,
          shadows: <ui.Shadow>[
            ui.Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      )
      ..addText('${index + 1}');
    final ui.Paragraph paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: badge.width));
    canvas.drawParagraph(paragraph, Offset(badge.left, badge.top + 4));
  }

  void _drawTrackDustAndHoofPrints(Canvas canvas, Size size) {
    if (!gateOpen && raceProgress <= 0) return;

    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double laneW = HorseRaceTrackLayout.laneWidth(size, laneCount);
    final List<double> progresses =
        horsePositions ??
        List<double>.generate(
          laneCount,
          (int i) => (raceProgress * (0.85 + (i % 3) * 0.08)).clamp(0.0, 1.0),
        );

    final Paint hoofPrintPaint = _paint()
      ..color = _dirtTread.withValues(alpha: 0.28)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final Paint dustPuffPaint = _paint()..style = PaintingStyle.fill;
    final Paint turfClodPaint = _paint()
      ..color = const Color(0xFF1F1610)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < laneCount; i++) {
      final double p = i < progresses.length ? progresses[i] : raceProgress;
      if (p <= 0.01) continue;

      final double centerX = track.left + laneW * (i + 0.5);
      final double horseY = HorseRaceTrackLayout.horseY(size, p);

      // 1. Hoof depression prints trailing along the lane
      final int printsCount = (p * 14).round().clamp(1, 14);
      final double startY = size.height * HorseRaceTrackLayout.trackStartY;
      for (int k = 0; k < printsCount; k++) {
        final double printFraction = (k / 14.0) * p;
        final double printY = startY +
            (size.height * HorseRaceTrackLayout.trackEndY - startY) *
                printFraction;
        final double drift = math.sin((k * 3.7) + i) * (laneW * 0.12);

        // Horseshoe mark
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(centerX + drift, printY),
            width: 7,
            height: 9,
          ),
          0.2,
          math.pi - 0.4,
          false,
          hoofPrintPaint,
        );
      }

      // 2. Multi-layered expanding atmospheric dust plumes behind horse hooves
      for (int puff = 0; puff < 5; puff++) {
        final double lag = (puff + 1) * 9.0;
        final double puffY = horseY + lag;
        final double expansion = 8.0 + puff * 5.5;
        final double alpha = (0.22 - puff * 0.04).clamp(0.03, 0.25);
        final double driftX = math.sin(puff * 2.1 + i) * 6.0;

        dustPuffPaint.shader = ui.Gradient.radial(
          Offset(centerX + driftX, puffY),
          expansion,
          <Color>[
            const Color(0xFFC4A482).withValues(alpha: alpha * 1.2),
            const Color(0xFF8B6B4E).withValues(alpha: alpha * 0.6),
            Colors.transparent,
          ],
          <double>[0.0, 0.45, 1.0],
        );

        canvas.drawCircle(Offset(centerX + driftX, puffY), expansion, dustPuffPaint);
      }

      // 3. High-velocity kicked turf clods & soil debris
      final math.Random rng = math.Random(i * 100 + (p * 60).floor());
      for (int c = 0; c < 4; c++) {
        final double clodX = centerX + (rng.nextDouble() - 0.5) * laneW * 0.45;
        final double clodY = horseY + 12 + rng.nextDouble() * 22;
        final double radius = 1.0 + rng.nextDouble() * 1.8;
        canvas.drawCircle(Offset(clodX, clodY), radius, turfClodPaint);
      }
    }
  }

  void _drawDistanceMarkers(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final List<int> distances = <int>[1000, 800, 600, 400, 200, 100, 50];
    final double startY = size.height * HorseRaceTrackLayout.trackStartY;
    final double endY = size.height * HorseRaceTrackLayout.trackEndY;
    final double span = startY - endY;

    final Paint laserLine = _paint()
      ..strokeWidth = 1.5
      ..blendMode = BlendMode.screen;

    for (int i = 0; i < distances.length; i++) {
      final double distM = distances[i].toDouble();
      final double frac = (1200 - distM) / 1200.0;
      final double y = startY - span * frac;
      if (y < endY + 18 || y > startY - 14) continue;

      final bool isMajor = distances[i] % 400 == 0 || distances[i] == 100;
      final Color markerColor = isMajor ? AppColors.liquidGold : AppColors.accentCyan;

      // Holographic laser beam across the track
      laserLine.shader = ui.Gradient.linear(
        Offset(track.left, y),
        Offset(track.right, y),
        <Color>[
          markerColor.withValues(alpha: 0.1),
          markerColor.withValues(alpha: isMajor ? 0.65 : 0.45),
          markerColor.withValues(alpha: 0.1),
        ],
        <double>[0.0, 0.5, 1.0],
      );
      canvas.drawLine(Offset(track.left, y), Offset(track.right, y), laserLine);

      // Glowing LED rail plaque
      final Rect leftPlaque = Rect.fromLTWH(track.left - 2, y - 8, 38, 16);
      final Paint plaqueBg = _paint()
        ..color = const Color(0xFF141923).withValues(alpha: 0.88);
      canvas.drawRRect(
        RRect.fromRectAndRadius(leftPlaque, const Radius.circular(4)),
        plaqueBg,
      );

      final Paint plaqueBorder = _paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = markerColor.withValues(alpha: 0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(leftPlaque, const Radius.circular(4)),
        plaqueBorder,
      );

      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      )
        ..pushStyle(ui.TextStyle(color: markerColor))
        ..addText('${distances[i]}m');
      final ui.Paragraph p = builder.build()
        ..layout(ui.ParagraphConstraints(width: leftPlaque.width));
      canvas.drawParagraph(p, Offset(leftPlaque.left, leftPlaque.top + 2));
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final Paint line = _paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final math.Random rng = math.Random(19);

    for (int i = 0; i < 36; i++) {
      final double x = track.left + rng.nextDouble() * track.width;
      final double len = 35 + rng.nextDouble() * 85;
      final double y =
          (rng.nextDouble() * size.height + scrollOffset * 1.6) % size.height;
      final Color tint = i.isEven ? Colors.white : AppColors.liquidGold;
      line.color = tint.withValues(alpha: 0.05 + rng.nextDouble() * 0.11);
      canvas.drawLine(Offset(x, y), Offset(x + 1.2, y - len), line);
    }
  }

  void _drawStartGate(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double gateY = size.height * HorseRaceTrackLayout.trackStartY;
    const int bars = 5;
    const double barH = 5.0;
    const double gap = 4.0;

    for (int i = 0; i < bars; i++) {
      final double y = gateY + gap + i * (barH + gap);
      final double openOffset = gateOpen ? track.width * 0.46 : 0;
      final Paint bar = _paint()
        ..color = Color.lerp(
          AppColors.mysticRuby,
          AppColors.mysticRuby.withValues(alpha: 0.12),
          gateOpen ? 1.0 : 0.0,
        )!
        ..strokeWidth = barH
        ..strokeCap = StrokeCap.round;

      // Left gate wing
      canvas.drawLine(
        Offset(track.left + openOffset, y),
        Offset(track.left + (track.width * 0.5) - (gateOpen ? openOffset : 0), y),
        bar,
      );
      // Right gate wing
      canvas.drawLine(
        Offset(track.right - openOffset, y),
        Offset(track.right - (track.width * 0.5) + (gateOpen ? openOffset : 0), y),
        bar,
      );
    }

    // Mechanical gate posts & start banner
    final Paint post = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[const Color(0xFF6B7280), const Color(0xFF1F2937)],
      ).createShader(Rect.fromLTWH(track.left - 4, gateY, 8, 48));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(track.left - 4, gateY, 8, 48),
        const Radius.circular(2),
      ),
      post,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(track.right - 4, gateY, 8, 48),
        const Radius.circular(2),
      ),
      post,
    );

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          letterSpacing: 1.5,
        ),
      )
      ..addText('START KAPISI');
    final ui.Paragraph p = builder.build()
      ..layout(ui.ParagraphConstraints(width: track.width));
    canvas.drawParagraph(p, Offset(track.left, gateY + 36));
  }

  void _drawFinishLine(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double finishY = size.height * HorseRaceTrackLayout.finishLineY;
    const double lineHeight = 24.0;
    const int checkerCols = 18;
    final double colWidth = track.width / checkerCols;

    // 1. Multi-tier volumetric luminous bloom (intensifies as race finishes)
    final double bloomAlpha = (0.35 + raceProgress * 0.55).clamp(0.0, 1.0);
    final Paint wideGlow = _paint()
      ..shader = ui.Gradient.radial(
        Offset(track.center.dx, finishY),
        track.width * 0.65,
        <Color>[
          AppColors.liquidGold.withValues(alpha: bloomAlpha * 0.65),
          AppColors.cyberFuchsia.withValues(alpha: bloomAlpha * 0.25),
          Colors.transparent,
        ],
        <double>[0.0, 0.45, 1.0],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawRect(
      Rect.fromLTWH(
        track.left - 20,
        finishY - lineHeight * 2.5,
        track.width + 40,
        lineHeight * 5.0,
      ),
      wideGlow,
    );

    // 2. High-energy golden laser wire across finish line
    final Paint laserBeam = _paint()
      ..shader = ui.Gradient.linear(
        Offset(track.left, finishY),
        Offset(track.right, finishY),
        <Color>[
          AppColors.liquidGold.withValues(alpha: 0.2),
          AppColors.liquidGold,
          Colors.white,
          AppColors.liquidGold,
          AppColors.liquidGold.withValues(alpha: 0.2),
        ],
        <double>[0.0, 0.25, 0.5, 0.75, 1.0],
      )
      ..strokeWidth = 3.0
      ..blendMode = BlendMode.plus;
    canvas.drawLine(
      Offset(track.left, finishY),
      Offset(track.right, finishY),
      laserBeam,
    );

    // 3. Checkered finish tape with metallic gold & carbon squares
    final RRect clip = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        track.left,
        finishY - lineHeight * 0.5,
        track.width,
        lineHeight,
      ),
      const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(clip);

    for (int col = 0; col < checkerCols; col++) {
      for (int row = 0; row < 2; row++) {
        final bool light = (row + col) % 2 == 0;
        final Paint checker = _paint()
          ..color = light
              ? AppColors.liquidGold
              : const Color(0xFF11141A);
        canvas.drawRect(
          Rect.fromLTWH(
            track.left + col * colWidth,
            finishY - lineHeight * 0.5 + row * (lineHeight * 0.5),
            colWidth + 0.5,
            lineHeight * 0.5 + 0.5,
          ),
          checker,
        );
      }
    }
    canvas.restore();

    // Metallic gold border
    final Paint outline = _paint()
      ..color = AppColors.liquidGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(clip, outline);

    // 4. Architectural finish beacons & upward lens flare pylons
    _drawFinishPylon(canvas, Offset(track.left, finishY), isLeft: true);
    _drawFinishPylon(canvas, Offset(track.right, finishY), isLeft: false);

    // 5. Floating holographic "FİNİŞ" banner
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: AppColors.liquidGold,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.0,
          shadows: <ui.Shadow>[
            ui.Shadow(
              color: AppColors.liquidGold.withValues(alpha: 0.8),
              blurRadius: 12,
            ),
            ui.Shadow(
              color: Colors.black,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      )
      ..addText('✦ F İ N İ Ş ✦');
    final ui.Paragraph p = builder.build()
      ..layout(ui.ParagraphConstraints(width: track.width));
    canvas.drawParagraph(
      p,
      Offset(track.left, finishY - lineHeight * 0.5 - 24),
    );

    // 6. Radiant golden particulate sparkles near finish
    final math.Random rng = math.Random(42);
    final Paint sparkPaint = _paint()..style = PaintingStyle.fill;
    for (int s = 0; s < 16; s++) {
      final double sx = track.left + rng.nextDouble() * track.width;
      final double sy = finishY - 30 + rng.nextDouble() * 60;
      final double sRad = 1.0 + rng.nextDouble() * 2.2;
      sparkPaint.color = AppColors.liquidGold.withValues(
        alpha: 0.3 + rng.nextDouble() * 0.5,
      );
      canvas.drawCircle(Offset(sx, sy), sRad, sparkPaint);
    }
  }

  void _drawFinishPylon(Canvas canvas, Offset pos, {required bool isLeft}) {
    final double dir = isLeft ? -1 : 1;
    final Rect pylonRect = Rect.fromLTWH(
      isLeft ? pos.dx - 10 : pos.dx + 2,
      pos.dy - 32,
      8,
      48,
    );

    // 3D Obelisk pillar
    final Paint pylonPaint = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          AppColors.liquidGold,
          const Color(0xFF8B6B14),
          const Color(0xFF1E242E),
        ],
      ).createShader(pylonRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pylonRect, const Radius.circular(3)),
      pylonPaint,
    );

    // Beacon lens flare light beam shooting upward
    final Path beaconBeam = Path()
      ..moveTo(pylonRect.center.dx, pylonRect.top)
      ..lineTo(pylonRect.center.dx - 12 * dir, pylonRect.top - 60)
      ..lineTo(pylonRect.center.dx + 12 * dir, pylonRect.top - 60)
      ..close();

    final Paint beamPaint = _paint()
      ..shader = ui.Gradient.linear(
        Offset(pylonRect.center.dx, pylonRect.top),
        Offset(pylonRect.center.dx, pylonRect.top - 60),
        <Color>[
          AppColors.liquidGold.withValues(alpha: 0.55),
          Colors.transparent,
        ],
      )
      ..blendMode = BlendMode.screen;
    canvas.drawPath(beaconBeam, beamPaint);

    // Glowing crystal tip
    final Paint tipGlow = _paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(pylonRect.center.dx, pylonRect.top), 3.0, tipGlow);
  }

  void _drawFinalStretchBanner(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double finishY = size.height * HorseRaceTrackLayout.finishLineY;
    final double bannerHeight = size.height * 0.38;

    // Glowing fiery aura over final stretch
    final Paint fieryBand = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          AppColors.mysticRuby.withValues(alpha: 0.28),
          AppColors.mysticRuby.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(track.left, finishY, track.width, bannerHeight),
      );
    canvas.drawRect(
      Rect.fromLTWH(track.left, finishY, track.width, bannerHeight),
      fieryBand,
    );

    // Luminous warning chevron side strips
    final Paint sideChevron = _paint()
      ..color = AppColors.mysticRuby.withValues(alpha: 0.6)
      ..strokeWidth = 2.0;
    for (double y = finishY + 10; y < finishY + bannerHeight - 10; y += 24) {
      canvas.drawLine(
        Offset(track.left + 2, y),
        Offset(track.left + 8, y + 6),
        sideChevron,
      );
      canvas.drawLine(
        Offset(track.right - 2, y),
        Offset(track.right - 8, y + 6),
        sideChevron,
      );
    }

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          letterSpacing: 2.0,
          shadows: <ui.Shadow>[
            ui.Shadow(
              color: AppColors.mysticRuby,
              blurRadius: 14,
            ),
          ],
        ),
      )
      ..addText('⚡ S O N   D Ü Z L Ü K ⚡');
    final ui.Paragraph p = builder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    canvas.drawParagraph(p, Offset(0, finishY + 28));
  }

  @override
  bool shouldRepaint(covariant HorseRaceTrackPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.laneCount != laneCount ||
        oldDelegate.raceProgress != raceProgress ||
        oldDelegate.laneColors != laneColors ||
        oldDelegate.gateOpen != gateOpen ||
        oldDelegate.finalStretch != finalStretch ||
        oldDelegate.showSpeedLines != showSpeedLines ||
        oldDelegate.horsePositions != horsePositions;
  }
}
