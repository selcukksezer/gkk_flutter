import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Shared track geometry for painter + live horse overlays.
abstract final class HorseRaceTrackLayout {
  static const double grandstandFraction = 0.14;
  static const double railFraction = 0.06;
  static const double trackStartX = 0.07;
  static const double trackEndX = 0.88;
  static const double finishLineX = 0.88;

  static Rect trackRect(Size size) {
    final double top = size.height * grandstandFraction;
    final double bottom = size.height * railFraction;
    return Rect.fromLTWH(0, top, size.width, size.height - top - bottom);
  }

  static double laneCenterY(Size size, int laneIndex, int laneCount) {
    final Rect track = trackRect(size);
    final double laneHeight = track.height / math.max(laneCount, 1);
    return track.top + laneHeight * (laneIndex + 0.5);
  }

  static double laneHeight(Size size, int laneCount) {
    return trackRect(size).height / math.max(laneCount, 1);
  }

  static double horseX(Size size, double position) {
    final double span = trackEndX - trackStartX;
    return size.width * (trackStartX + position.clamp(0.0, 1.0) * span);
  }

  static double horseSize(int laneCount) {
    if (laneCount <= 3) return 54;
    if (laneCount <= 5) return 46;
    return 40;
  }
}

/// Premium hipodrom pisti — turf, grandstand, rails, start gate, finish.
class HorseRaceTrackPainter extends CustomPainter {
  HorseRaceTrackPainter({
    required this.laneCount,
    required this.laneColors,
    this.scrollOffset = 0,
    this.raceProgress = 0,
    this.gateOpen = false,
    this.finalStretch = false,
    this.showSpeedLines = false,
  });

  final int laneCount;
  final List<Color> laneColors;
  final double scrollOffset;
  final double raceProgress;
  final bool gateOpen;
  final bool finalStretch;
  final bool showSpeedLines;

  static const Color _carbon = AppColors.carbonVoid;
  static const Color _navy = AppColors.spaceNavy;
  static const Color _turfDark = Color(0xFF1A4D2E);
  static const Color _turfMid = Color(0xFF256B3A);
  static const Color _turfLight = Color(0xFF2E8448);
  static const Color _dirt = Color(0xFF5C4033);

  Paint _paint({bool antiAlias = true}) => Paint()..isAntiAlias = antiAlias;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    _drawSky(canvas, bounds, size);
    _drawGrandstand(canvas, size);
    _drawTrack(canvas, size);
    _drawRails(canvas, size);
    _drawDistanceMarkers(canvas, size);
    if (showSpeedLines) _drawSpeedLines(canvas, size);
    _drawStartGate(canvas, size);
    _drawFinishLine(canvas, size);
    if (finalStretch) _drawFinalStretchBanner(canvas, size);
  }

  void _drawSky(Canvas canvas, Rect bounds, Size size) {
    final Paint sky = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF1A2744),
          const Color(0xFF2A1F12).withValues(alpha: 0.85),
          _carbon,
        ],
        stops: const <double>[0.0, 0.35, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, sky);

    final Paint sunset = _paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.75, size.height * 0.08),
        size.width * 0.55,
        <Color>[
          AppColors.liquidGold.withValues(alpha: 0.18),
          AppColors.cyberFuchsia.withValues(alpha: 0.04),
          Colors.transparent,
        ],
      );
    canvas.drawRect(bounds, sunset);
  }

  void _drawGrandstand(Canvas canvas, Size size) {
    final double h = size.height * HorseRaceTrackLayout.grandstandFraction;
    final Path stand = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, h * 0.55)
      ..lineTo(size.width * 0.92, h)
      ..lineTo(size.width * 0.08, h)
      ..lineTo(0, h * 0.55)
      ..close();

    final Paint standPaint = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          _navy.withValues(alpha: 0.98),
          _carbon.withValues(alpha: 0.94),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, h));
    canvas.drawPath(stand, standPaint);

    final Paint railTop = _paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, h), Offset(size.width, h), railTop);

    final Paint crowd = _paint()..strokeWidth = 2;
    final math.Random rng = math.Random(42);
    for (int i = 0; i < 120; i++) {
      final double x = rng.nextDouble() * size.width;
      final double y = h * 0.15 + rng.nextDouble() * h * 0.55;
      crowd.color = <Color>[
        AppColors.liquidGold,
        AppColors.accentCyan,
        AppColors.cyberFuchsia,
        Colors.white,
      ][i % 4].withValues(alpha: 0.25 + rng.nextDouble() * 0.35);
      canvas.drawCircle(Offset(x, y), 1.2 + rng.nextDouble(), crowd);
    }
  }

  void _drawTrack(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double laneH = HorseRaceTrackLayout.laneHeight(size, laneCount);

    final Paint turfBase = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[_turfLight, _turfMid, _turfDark],
      ).createShader(track);
    canvas.drawRect(track, turfBase);

    for (int i = 0; i < laneCount; i++) {
      final double top = track.top + i * laneH;
      final Color laneColor = i < laneColors.length
          ? laneColors[i]
          : AppColors.mutedTitanium;
      final Rect laneRect = Rect.fromLTWH(track.left, top, track.width, laneH);

      if (i.isOdd) {
        final Paint alt = _paint()
          ..color = Colors.black.withValues(alpha: 0.06);
        canvas.drawRect(laneRect, alt);
      }

      final Paint silk = _paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            laneColor.withValues(alpha: 0.04),
            laneColor.withValues(alpha: 0.14),
            laneColor.withValues(alpha: 0.04),
          ],
        ).createShader(laneRect);
      canvas.drawRect(laneRect, silk);

      final Paint stripePaint = _paint()
        ..color = Colors.white.withValues(alpha: 0.045);
      for (double x = -scrollOffset % 56; x < track.width; x += 56) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(track.left + x, top + 6, 26, laneH - 12),
            const Radius.circular(2),
          ),
          stripePaint,
        );
      }

      if (i > 0) {
        final Paint divider = _paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..strokeWidth = 1;
        canvas.drawLine(
          Offset(track.left, top),
          Offset(track.right, top),
          divider,
        );
      }

      _drawLaneNumber(canvas, i, top, laneH, laneColor);
    }

    final Paint innerRail = _paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(track.left + 4, track.top + 2),
      Offset(track.left + 4, track.bottom - 2),
      innerRail,
    );
  }

  void _drawLaneNumber(
    Canvas canvas,
    int index,
    double top,
    double laneH,
    Color laneColor,
  ) {
    final Rect badge = Rect.fromLTWH(8, top + laneH * 0.5 - 11, 22, 22);
    final Paint bg = _paint()..color = laneColor.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(5)),
      bg,
    );
    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText('${index + 1}');
    final ui.Paragraph paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: badge.width));
    canvas.drawParagraph(
      paragraph,
      Offset(badge.left, badge.top + 4),
    );
  }

  void _drawRails(Canvas canvas, Size size) {
    final double railTop =
        size.height - size.height * HorseRaceTrackLayout.railFraction;
    final Rect railRect = Rect.fromLTWH(0, railTop, size.width, size.height - railTop);

    final Paint dirt = _paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[_dirt.withValues(alpha: 0.9), _carbon],
      ).createShader(railRect);
    canvas.drawRect(railRect, dirt);

    final Paint fence = _paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, railTop), Offset(x, railTop + 14), fence);
    }
    canvas.drawLine(Offset(0, railTop), Offset(size.width, railTop), fence);
  }

  void _drawDistanceMarkers(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final List<int> distances = <int>[200, 400, 600, 800];
    final Paint postPaint = _paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2;

    for (int i = 0; i < distances.length; i++) {
      final double baseX = track.right * (0.25 + i * 0.18);
      final double x = baseX - (scrollOffset * 0.35) % (track.width * 0.5);
      if (x < track.left + 30 || x > track.right - 20) continue;

      canvas.drawLine(
        Offset(x, track.top + 4),
        Offset(x, track.bottom - 4),
        postPaint,
      );

      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: 9, fontWeight: FontWeight.w800),
      )
        ..pushStyle(ui.TextStyle(color: Colors.white.withValues(alpha: 0.7)))
        ..addText('${distances[i]}m');
      final ui.Paragraph p = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 40));
      canvas.drawParagraph(p, Offset(x - 12, track.top - 14));
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final Paint line = _paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final math.Random rng = math.Random(7);
    for (int i = 0; i < 28; i++) {
      final double y = track.top + rng.nextDouble() * track.height;
      final double len = 30 + rng.nextDouble() * 70;
      final double x = (rng.nextDouble() * size.width - scrollOffset * 1.4) %
          size.width;
      line.color = Colors.white.withValues(
        alpha: 0.04 + rng.nextDouble() * 0.08,
      );
      canvas.drawLine(Offset(x, y), Offset(x + len, y - 2), line);
    }
  }

  void _drawStartGate(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double gateX = size.width * HorseRaceTrackLayout.trackStartX;
    const int bars = 5;
    final double barW = 5;
    final double gap = (8 - bars * barW) / (bars + 1);

    for (int i = 0; i < bars; i++) {
      final double x = gateX - 14 + gap + i * (barW + gap);
      final double openOffset = gateOpen ? -track.height * 0.35 : 0;
      final Paint bar = _paint()
        ..color = Color.lerp(
          AppColors.mysticRuby,
          AppColors.mysticRuby.withValues(alpha: 0.15),
          gateOpen ? 1.0 : 0.0,
        )!
        ..strokeWidth = barW
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, track.top + openOffset),
        Offset(x, track.bottom + openOffset),
        bar,
      );
    }

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 8, fontWeight: FontWeight.w900),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white.withValues(alpha: 0.65)))
      ..addText('START');
    final ui.Paragraph p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 40));
    canvas.drawParagraph(p, Offset(gateX - 22, track.top - 12));
  }

  void _drawFinishLine(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double finishX = size.width * HorseRaceTrackLayout.finishLineX;
    const double lineWidth = 18.0;
    const int checkerRows = 14;
    final double rowHeight = track.height / checkerRows;

    final RRect clip = RRect.fromRectAndRadius(
      Rect.fromLTWH(finishX - lineWidth / 2, track.top, lineWidth, track.height),
      const Radius.circular(2),
    );
    canvas.save();
    canvas.clipRRect(clip);

    for (int row = 0; row < checkerRows; row++) {
      for (int col = 0; col < 2; col++) {
        final bool light = (row + col) % 2 == 0;
        final Paint checker = _paint()
          ..color = (light ? AppColors.liquidGold : _carbon).withValues(
            alpha: 0.25 + raceProgress * 0.35,
          );
        canvas.drawRect(
          Rect.fromLTWH(
            finishX - lineWidth / 2 + col * (lineWidth / 2),
            track.top + row * rowHeight,
            lineWidth / 2,
            rowHeight + 0.5,
          ),
          checker,
        );
      }
    }
    canvas.restore();

    final Paint glow = _paint()
      ..shader = ui.Gradient.linear(
        Offset(finishX, track.top),
        Offset(finishX, track.bottom),
        <Color>[
          AppColors.liquidGold.withValues(alpha: 0.0),
          AppColors.liquidGold.withValues(
            alpha: 0.18 + raceProgress * 0.42,
          ),
          AppColors.liquidGold.withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.5, 1.0],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawRect(
      Rect.fromLTWH(
        finishX - lineWidth * 1.4,
        track.top,
        lineWidth * 2.8,
        track.height,
      ),
      glow,
    );

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 10, fontWeight: FontWeight.w900),
    )
      ..pushStyle(ui.TextStyle(color: AppColors.liquidGold.withValues(alpha: 0.9)))
      ..addText('FİNİŞ');
    final ui.Paragraph p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 50));
    canvas.drawParagraph(p, Offset(finishX - 16, track.top - 14));
  }

  void _drawFinalStretchBanner(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final Paint band = _paint()
      ..color = AppColors.mysticRuby.withValues(alpha: 0.22);
    canvas.drawRect(
      Rect.fromLTWH(track.left, track.top, track.width, track.height),
      band,
    );

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 13, fontWeight: FontWeight.w900),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white.withValues(alpha: 0.55)))
      ..addText('SON DÜZLÜK');
    final ui.Paragraph p = builder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    canvas.drawParagraph(
      p,
      Offset(size.width * 0.5 - 42, track.top + track.height * 0.5 - 8),
    );
  }

  @override
  bool shouldRepaint(covariant HorseRaceTrackPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.laneCount != laneCount ||
        oldDelegate.raceProgress != raceProgress ||
        oldDelegate.laneColors != laneColors ||
        oldDelegate.gateOpen != gateOpen ||
        oldDelegate.finalStretch != finalStretch ||
        oldDelegate.showSpeedLines != showSpeedLines;
  }
}
