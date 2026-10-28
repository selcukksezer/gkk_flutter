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

/// Vertical hipodrom — turf lanes, start gate bottom, finish top.
class HorseRaceTrackPainter extends CustomPainter {
  HorseRaceTrackPainter({
    required this.laneCount,
    required this.laneColors,
    this.scrollOffset = 0,
    this.raceProgress = 0,
    this.gateOpen = false,
    this.finalStretch = false,
    this.showSpeedLines = false,
    this.hasPaintedBackdrop = true,
  });

  final int laneCount;
  final List<Color> laneColors;
  final double scrollOffset;
  final double raceProgress;
  final bool gateOpen;
  final bool finalStretch;
  final bool showSpeedLines;
  final bool hasPaintedBackdrop;

  static const Color _carbon = AppColors.carbonVoid;
  static const Color _turfDark = Color(0xFF1A4D2E);
  static const Color _turfMid = Color(0xFF256B3A);
  static const Color _turfLight = Color(0xFF2E8448);
  static const Color _dirt = Color(0xFF5C4033);

  Paint _paint({bool antiAlias = true}) => Paint()..isAntiAlias = antiAlias;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    if (!hasPaintedBackdrop) {
      _drawSky(canvas, bounds, size);
      _drawSideRails(canvas, size);
    }
    _drawTrack(canvas, size);
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
        Offset(size.width * 0.5, size.height * 0.06),
        size.width * 0.7,
        <Color>[
          AppColors.liquidGold.withValues(alpha: 0.16),
          AppColors.cyberFuchsia.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        <double>[0.0, 0.45, 1.0],
      );
    canvas.drawRect(bounds, sunset);
  }

  void _drawSideRails(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final Paint dirt = _paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[_dirt.withValues(alpha: 0.95), _carbon],
      ).createShader(Rect.fromLTWH(0, 0, track.left, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, track.left, size.height), dirt);
    canvas.drawRect(
      Rect.fromLTWH(track.right, 0, size.width - track.right, size.height),
      dirt,
    );

    final Paint fence = _paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(track.left, y), Offset(track.left + 10, y), fence);
      canvas.drawLine(
        Offset(track.right - 10, y),
        Offset(track.right, y),
        fence,
      );
    }
    canvas.drawLine(
      Offset(track.left, 0),
      Offset(track.left, size.height),
      fence,
    );
    canvas.drawLine(
      Offset(track.right, 0),
      Offset(track.right, size.height),
      fence,
    );
  }

  void _drawTrack(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double laneW = HorseRaceTrackLayout.laneWidth(size, laneCount);

    if (!hasPaintedBackdrop) {
      final Paint turfBase = _paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[_turfLight, _turfMid, _turfDark],
        ).createShader(track);
      canvas.drawRect(track, turfBase);
    } else {
      canvas.drawRect(
        track,
        _paint()..color = Colors.black.withValues(alpha: 0.14),
      );
    }

    for (int i = 0; i < laneCount; i++) {
      final double left = track.left + i * laneW;
      final Color laneColor = i < laneColors.length
          ? laneColors[i]
          : AppColors.mutedTitanium;
      final Rect laneRect = Rect.fromLTWH(left, track.top, laneW, track.height);

      if (i.isOdd) {
        final Paint alt = _paint()
          ..color = Colors.black.withValues(alpha: 0.06);
        canvas.drawRect(laneRect, alt);
      }

      final Paint silk = _paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            laneColor.withValues(alpha: 0.04),
            laneColor.withValues(alpha: 0.14),
            laneColor.withValues(alpha: 0.04),
          ],
        ).createShader(laneRect);
      canvas.drawRect(laneRect, silk);

      final Paint stripePaint = _paint()
        ..color = Colors.white.withValues(alpha: 0.045);
      for (double y = -scrollOffset % 56; y < track.height; y += 56) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 6, track.top + y, laneW - 12, 26),
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
          Offset(left, track.top),
          Offset(left, track.bottom),
          divider,
        );
      }

      _drawLaneNumber(canvas, i, left, laneW, laneColor, size);
    }
  }

  void _drawLaneNumber(
    Canvas canvas,
    int index,
    double left,
    double laneW,
    Color laneColor,
    Size size,
  ) {
    final double badgeY = size.height * HorseRaceTrackLayout.trackStartY + 8;
    final Rect badge = Rect.fromLTWH(
      left + laneW * 0.5 - 11,
      badgeY,
      22,
      22,
    );
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

  void _drawDistanceMarkers(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final List<int> distances = <int>[200, 400, 600, 800];
    final Paint postPaint = _paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 2;
    final double startY = size.height * HorseRaceTrackLayout.trackStartY;
    final double endY = size.height * HorseRaceTrackLayout.trackEndY;
    final double span = startY - endY;

    for (int i = 0; i < distances.length; i++) {
      final double frac = 0.2 + i * 0.18;
      final double y =
          startY - span * frac - (scrollOffset * 0.2) % (span * 0.3);
      if (y < endY + 24 || y > startY - 20) continue;

      canvas.drawLine(
        Offset(track.left + 4, y),
        Offset(track.right - 4, y),
        postPaint,
      );

      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(fontSize: 9, fontWeight: FontWeight.w800),
      )
        ..pushStyle(ui.TextStyle(color: Colors.white.withValues(alpha: 0.7)))
        ..addText('${distances[i]}m');
      final ui.Paragraph p = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 40));
      canvas.drawParagraph(p, Offset(track.left + 6, y - 12));
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final Paint line = _paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final math.Random rng = math.Random(7);
    for (int i = 0; i < 28; i++) {
      final double x = track.left + rng.nextDouble() * track.width;
      final double len = 30 + rng.nextDouble() * 70;
      final double y =
          (rng.nextDouble() * size.height + scrollOffset * 1.4) % size.height;
      line.color = Colors.white.withValues(
        alpha: 0.04 + rng.nextDouble() * 0.08,
      );
      canvas.drawLine(Offset(x, y), Offset(x + 2, y - len), line);
    }
  }

  void _drawStartGate(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double gateY = size.height * HorseRaceTrackLayout.trackStartY;
    const int bars = 5;
    const double barH = 5;
    final double gap = 4.0;

    for (int i = 0; i < bars; i++) {
      final double y = gateY + gap + i * (barH + gap);
      final double openOffset = gateOpen ? track.width * 0.45 : 0;
      final Paint bar = _paint()
        ..color = Color.lerp(
          AppColors.mysticRuby,
          AppColors.mysticRuby.withValues(alpha: 0.15),
          gateOpen ? 1.0 : 0.0,
        )!
        ..strokeWidth = barH
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(track.left + openOffset, y),
        Offset(track.right - openOffset, y),
        bar,
      );
    }

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 9, fontWeight: FontWeight.w900),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white.withValues(alpha: 0.75)))
      ..addText('START');
    final ui.Paragraph p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 50));
    canvas.drawParagraph(
      p,
      Offset(track.left + track.width * 0.5 - 18, gateY + 28),
    );
  }

  void _drawFinishLine(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double finishY = size.height * HorseRaceTrackLayout.finishLineY;
    const double lineHeight = 22.0;
    const int checkerCols = 16;
    final double colWidth = track.width / checkerCols;

    // Strong glow behind the line so it reads clearly on mobile.
    final Paint glow = _paint()
      ..shader = ui.Gradient.linear(
        Offset(track.left, finishY),
        Offset(track.right, finishY),
        <Color>[
          AppColors.liquidGold.withValues(alpha: 0.0),
          AppColors.liquidGold.withValues(
            alpha: 0.35 + raceProgress * 0.45,
          ),
          AppColors.liquidGold.withValues(alpha: 0.0),
        ],
        <double>[0.0, 0.5, 1.0],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawRect(
      Rect.fromLTWH(
        track.left,
        finishY - lineHeight * 1.6,
        track.width,
        lineHeight * 3.2,
      ),
      glow,
    );

    final RRect clip = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        track.left,
        finishY - lineHeight / 2,
        track.width,
        lineHeight,
      ),
      const Radius.circular(3),
    );
    canvas.save();
    canvas.clipRRect(clip);

    for (int col = 0; col < checkerCols; col++) {
      for (int row = 0; row < 2; row++) {
        final bool light = (row + col) % 2 == 0;
        final Paint checker = _paint()
          ..color = light ? AppColors.liquidGold : Colors.white;
        canvas.drawRect(
          Rect.fromLTWH(
            track.left + col * colWidth,
            finishY - lineHeight / 2 + row * (lineHeight / 2),
            colWidth + 0.5,
            lineHeight / 2 + 0.5,
          ),
          checker,
        );
      }
    }
    canvas.restore();

    // Bold outline
    final Paint outline = _paint()
      ..color = AppColors.liquidGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(clip, outline);

    // FINISH posts
    final Paint post = _paint()..color = AppColors.liquidGold;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(track.left - 4, finishY - 28, 8, 40),
        const Radius.circular(2),
      ),
      post,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(track.right - 4, finishY - 28, 8, 40),
        const Radius.circular(2),
      ),
      post,
    );

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: AppColors.liquidGold,
          fontWeight: FontWeight.w900,
        ),
      )
      ..addText('FİNİŞ');
    final ui.Paragraph p = builder.build()
      ..layout(ui.ParagraphConstraints(width: track.width));
    canvas.drawParagraph(p, Offset(track.left, finishY - lineHeight / 2 - 20));
  }

  void _drawFinalStretchBanner(Canvas canvas, Size size) {
    final Rect track = HorseRaceTrackLayout.trackRect(size);
    final double finishY = size.height * HorseRaceTrackLayout.finishLineY;
    final Paint band = _paint()
      ..color = AppColors.mysticRuby.withValues(alpha: 0.18);
    canvas.drawRect(
      Rect.fromLTWH(track.left, finishY, track.width, size.height * 0.35),
      band,
    );

    final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: 12, fontWeight: FontWeight.w900),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white.withValues(alpha: 0.55)))
      ..addText('SON DÜZLÜK');
    final ui.Paragraph p = builder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    canvas.drawParagraph(
      p,
      Offset(size.width * 0.5 - 42, finishY + 28),
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
