import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/logout_helper.dart';
import 'horse_race_live_view.dart';
import 'horse_race_provider.dart';
import 'horse_race_utils.dart';
import 'widgets/horse_bet_panel.dart';
import 'widgets/horse_race_design.dart';
import 'widgets/horse_result_overlay.dart';

/// Procedural particle model for hipodrom turf clippings & luminous dust motes.
class _TrackAtmosphereParticle {
  const _TrackAtmosphereParticle({
    required this.seedX,
    required this.seedY,
    required this.speed,
    required this.size,
    required this.isTurf,
    required this.swayFrequency,
    required this.colorIndex,
  });

  final double seedX;
  final double seedY;
  final double speed;
  final double size;
  final bool isTurf;
  final double swayFrequency;
  final int colorIndex;
}

/// 38 deterministic procedural particles representing turf clippings and rising golden dust motes.
final List<_TrackAtmosphereParticle> _kAtmosphereParticles =
    List<_TrackAtmosphereParticle>.generate(38, (int i) {
  final double rx = ((i * 37.17) % 100) / 100.0;
  final double ry = ((i * 61.43) % 100) / 100.0;
  final double spd = 0.35 + (((i * 19.3) % 100) / 100.0) * 0.75;
  final double sz = (i % 3 == 0) ? 3.6 : ((i % 2 == 0) ? 2.6 : 1.8);
  final bool turf = i % 2 == 0;
  final double freq = 1.0 + (((i * 43.1) % 100) / 100.0) * 2.2;
  return _TrackAtmosphereParticle(
    seedX: rx,
    seedY: ry,
    speed: spd,
    size: sz,
    isTurf: turf,
    swayFrequency: freq,
    colorIndex: i % 4,
  );
});

/// Custom painter rendering flying turf clippings and sparkling golden dust particles.
class _TurfAndDustPainter extends CustomPainter {
  const _TurfAndDustPainter({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  static const List<Color> _turfColors = <Color>[
    Color(0xFF2E7D32),
    Color(0xFF1B5E20),
    Color(0xFF388E3C),
    Color(0xFF43A047),
  ];

  static const List<Color> _dustColors = <Color>[
    Color(0xFFFFD64A),
    Color(0xFFF59E0B),
    Color(0xFFEAB308),
    Color(0xFFFFE082),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint paint = Paint()..isAntiAlias = true;

    for (final _TrackAtmosphereParticle p in _kAtmosphereParticles) {
      if (p.isTurf) {
        // Turf clipping drifting downward and swaying horizontally with the stadium wind
        final double y =
            ((p.seedY + progress * p.speed * 0.35) % 1.0) * size.height;
        final double sway =
            math.sin((progress * p.swayFrequency * 2 * math.pi) + (p.seedX * 10)) *
                14.0;
        final double x =
            ((p.seedX * size.width) + sway).clamp(0.0, size.width);

        final Color baseColor = _turfColors[p.colorIndex % _turfColors.length];
        paint.color = baseColor.withValues(
          alpha: (0.35 * intensity).clamp(0.0, 0.75),
        );
        paint.style = PaintingStyle.fill;

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.sin(progress * math.pi * 2 + p.seedY) * 0.6);
        final Rect blade = Rect.fromCenter(
          center: Offset.zero,
          width: p.size * 0.8,
          height: p.size * 2.2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(blade, const Radius.circular(1.5)),
          paint,
        );
        canvas.restore();
      } else {
        // Luminous golden dust mote floating upward from the stadium floor
        final double y =
            ((1.0 - ((p.seedY + progress * p.speed * 0.3) % 1.0))) *
                size.height;
        final double sway =
            math.cos((progress * p.swayFrequency * 2 * math.pi) + (p.seedY * 12)) *
                10.0;
        final double x =
            ((p.seedX * size.width) + sway).clamp(0.0, size.width);

        final double alpha = (0.2 +
                0.5 *
                    math.sin((progress * 4 * math.pi) + (p.seedX * 8)).abs()) *
            intensity;
        final Color dustColor = _dustColors[p.colorIndex % _dustColors.length];
        paint.color = dustColor.withValues(alpha: alpha.clamp(0.0, 0.85));
        paint.style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), p.size * 0.75, paint);

        // Soft atmospheric halo
        paint.color =
            dustColor.withValues(alpha: (alpha * 0.35).clamp(0.0, 0.4));
        canvas.drawCircle(Offset(x, y), p.size * 1.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TurfAndDustPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}

/// Volumetric stadium floodlights sweeping subtly across the dark void sky.
class _VolumetricFloodlightPainter extends CustomPainter {
  const _VolumetricFloodlightPainter({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint beamPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Left stadium floodlight beam
    final double leftAngle =
        0.35 + math.sin(progress * 2 * math.pi) * 0.08;
    final Path leftBeam = Path()
      ..moveTo(size.width * 0.05, -20)
      ..lineTo(size.width * (0.05 + leftAngle), size.height * 0.75)
      ..lineTo(size.width * (0.22 + leftAngle), size.height * 0.75)
      ..close();

    beamPaint.shader = ui.Gradient.linear(
      Offset(size.width * 0.05, -20),
      Offset(size.width * 0.25, size.height * 0.7),
      <Color>[
        HorseRaceDesign.gold.withValues(alpha: 0.12 * intensity),
        HorseRaceDesign.gold.withValues(alpha: 0.04 * intensity),
        Colors.transparent,
      ],
      <double>[0.0, 0.45, 1.0],
    );
    canvas.drawPath(leftBeam, beamPaint);

    // Right stadium floodlight beam
    final double rightAngle =
        -0.35 - math.sin(progress * 2 * math.pi + 1.2) * 0.08;
    final Path rightBeam = Path()
      ..moveTo(size.width * 0.95, -20)
      ..lineTo(size.width * (0.95 + rightAngle), size.height * 0.75)
      ..lineTo(size.width * (0.78 + rightAngle), size.height * 0.75)
      ..close();

    beamPaint.shader = ui.Gradient.linear(
      Offset(size.width * 0.95, -20),
      Offset(size.width * 0.75, size.height * 0.7),
      <Color>[
        HorseRaceDesign.cyan.withValues(alpha: 0.10 * intensity),
        HorseRaceDesign.cyan.withValues(alpha: 0.03 * intensity),
        Colors.transparent,
      ],
      <double>[0.0, 0.45, 1.0],
    );
    canvas.drawPath(rightBeam, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _VolumetricFloodlightPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}

/// AAA Living Hipodrom Track Backdrop featuring ambient stadium lighting,
/// volumetric light beams, dynamic turf/dust particles, and ground mist.
class _HorseRaceLivingTrackBackdrop extends StatelessWidget {
  const _HorseRaceLivingTrackBackdrop({
    required this.child,
    required this.atmosphereProgress,
    required this.intensity,
  });

  final Widget child;
  final double atmosphereProgress;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return GameScreenBackground(
      showAmbientGlow: true,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Dual ambient arena glow orbs
          Positioned(
            top: -90,
            right: -70,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      HorseRaceDesign.gold.withValues(alpha: 0.16 * intensity),
                      HorseRaceDesign.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -90,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      HorseRaceDesign.fuchsia.withValues(
                        alpha: 0.12 * intensity,
                      ),
                      HorseRaceDesign.fuchsia.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Volumetric stadium lighting
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _VolumetricFloodlightPainter(
                  progress: atmosphereProgress,
                  intensity: intensity,
                ),
              ),
            ),
          ),

          // Dynamic turf clippings & golden dust motion particles
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TurfAndDustPainter(
                  progress: atmosphereProgress,
                  intensity: intensity,
                ),
              ),
            ),
          ),

          // Ground mist haze gradient at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[
                      HorseRaceDesign.void_.withValues(alpha: 0.85),
                      HorseRaceDesign.void_.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          child,
        ],
      ),
    );
  }
}

/// AAA Glassmorphic Odds Display Header and Live Status Ticker Bar.
class _HorseRaceOddsHeaderBar extends StatelessWidget {
  const _HorseRaceOddsHeaderBar({
    required this.raceState,
    required this.selectedHorseId,
    required this.onSelectHorse,
    required this.pulseValue,
  });

  final HorseRaceState raceState;
  final String? selectedHorseId;
  final ValueChanged<HorseRaceEntry> onSelectHorse;
  final double pulseValue;

  @override
  Widget build(BuildContext context) {
    final HorseRacePhase phase = raceState.round.phase;
    final int left = raceState.round.secondsLeft;

    final Color statusColor = switch (phase) {
      HorseRacePhase.betting => HorseRaceDesign.neon,
      HorseRacePhase.locked => HorseRaceDesign.ruby,
      HorseRacePhase.racing => HorseRaceDesign.gold,
      HorseRacePhase.finished => HorseRaceDesign.cyan,
      HorseRacePhase.unknown => HorseRaceDesign.titanium,
    };

    final String statusText = switch (phase) {
      HorseRacePhase.betting => 'BAHİSLER AÇIK',
      HorseRacePhase.locked => 'KAPILAR KAPANIYOR',
      HorseRacePhase.racing => 'CANLI YARIŞTA',
      HorseRacePhase.finished => 'FİNİŞ GEÇİLDİ',
      HorseRacePhase.unknown => 'HAZIRLANIYOR',
    };

    final String timerText = switch (phase) {
      HorseRacePhase.betting ||
      HorseRacePhase.finished => formatHorseCountdown(left),
      HorseRacePhase.locked => 'Start',
      HorseRacePhase.racing => 'CANLI',
      HorseRacePhase.unknown => '--:--',
    };

    final String roundBadge = raceState.round.id.isNotEmpty
        ? 'TUR #${raceState.round.id.length > 5 ? raceState.round.id.substring(raceState.round.id.length - 5).toUpperCase() : raceState.round.id.toUpperCase()}'
        : 'TUR #---';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HorseRaceDesign.gold.withValues(alpha: 0.28),
          width: 1.1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            HorseRaceDesign.navy.withValues(alpha: 0.92),
            HorseRaceDesign.void_.withValues(alpha: 0.96),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12 * pulseValue),
            blurRadius: 18,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Top status row
                Row(
                  children: <Widget>[
                    // Hippodrome badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: HorseRaceDesign.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: HorseRaceDesign.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.sports_score_rounded,
                            size: 13,
                            color: HorseRaceDesign.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            roundBadge,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: HorseRaceDesign.gold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Phase label with pulsing beacon dot
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: statusColor,
                                  blurRadius: 6 * pulseValue,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusText,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Countdown timer
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: HorseRaceDesign.obsidian.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timerText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (raceState.horses.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  // Odds Ticker Strip
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: raceState.horses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final HorseRaceEntry horse = raceState.horses[index];
                        final bool isSelected =
                            selectedHorseId == horse.horseId;
                        final Color lane = parseHorseLaneColor(
                          horse.laneColor,
                          horseId: horse.horseId,
                        );

                        return HorseRacePressable(
                          onTap: () => onSelectHorse(horse),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected
                                  ? lane.withValues(alpha: 0.25)
                                  : HorseRaceDesign.obsidian.withValues(
                                      alpha: 0.6,
                                    ),
                              border: Border.all(
                                color: isSelected
                                    ? HorseRaceDesign.gold
                                    : lane.withValues(alpha: 0.35),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: HorseRaceDesign.gold.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                // Lane number circle
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: lane.withValues(alpha: 0.25),
                                    border: Border.all(
                                      color: lane.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: lane,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  horse.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      horse.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'x${horse.goldMultiplier.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: HorseRaceDesign.gold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (horse.winChancePct > 0) ...<Widget>[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '%${horse.winChancePct.round()}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: HorseRaceDesign.titanium,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating live betting triggers and live race quick-access HUD dock.
class _HorseRaceLiveBetTriggerDock extends StatelessWidget {
  const _HorseRaceLiveBetTriggerDock({
    required this.raceState,
    required this.selectedHorse,
    required this.onEnterLiveRace,
    required this.onClearSelection,
  });

  final HorseRaceState raceState;
  final HorseRaceEntry? selectedHorse;
  final VoidCallback onEnterLiveRace;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final HorseRacePhase phase = raceState.round.phase;
    final bool isRacing = phase == HorseRacePhase.racing;
    final HorseRaceBet? myBet = raceState.myBet;

    // If racing, show prominent live race jump trigger
    if (isRacing) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: HorseRaceDesign.ruby.withValues(alpha: 0.6),
            width: 1.4,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              HorseRaceDesign.ruby.withValues(alpha: 0.28),
              HorseRaceDesign.navy.withValues(alpha: 0.95),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: HorseRaceDesign.ruby.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HorseRaceDesign.ruby.withValues(alpha: 0.25),
                border: Border.all(
                  color: HorseRaceDesign.ruby.withValues(alpha: 0.6),
                ),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: HorseRaceDesign.ruby,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'YARIŞ DEVAM EDİYOR!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Hipodromda canlı heyecan sürüyor.',
                    style: TextStyle(
                      fontSize: 10,
                      color: HorseRaceDesign.titanium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: HorseRaceDesign.goldGradient,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: HorseRaceDesign.gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onEnterLiveRace,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: HorseRaceDesign.void_,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'CANLI İZLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: HorseRaceDesign.void_,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // If a horse was tapped in the odds ticker and bet not placed yet
    if (selectedHorse != null && myBet == null && phase == HorseRacePhase.betting) {
      final Color lane = parseHorseLaneColor(
        selectedHorse!.laneColor,
        horseId: selectedHorse!.horseId,
      );
      final double mult = selectedHorse!.goldMultiplier;
      final int sampleBet = 50000;
      final int samplePayout = (sampleBet * mult).round();

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: HorseRaceDesign.gold.withValues(alpha: 0.55),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              lane.withValues(alpha: 0.22),
              HorseRaceDesign.navy.withValues(alpha: 0.94),
              HorseRaceDesign.void_.withValues(alpha: 0.98),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: HorseRaceDesign.gold.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Text(
              selectedHorse!.emoji,
              style: const TextStyle(fontSize: 26),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          selectedHorse!.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HorseRaceDesign.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'x${mult.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: HorseRaceDesign.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Örnek ${compactHorseAmount(sampleBet)} ile ~${compactHorseAmount(samplePayout)} Altın',
                    style: const TextStyle(
                      fontSize: 10,
                      color: HorseRaceDesign.titanium,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: HorseRaceDesign.titanium,
              ),
              onPressed: onClearSelection,
            ),
          ],
        ),
      );
    }

    // Otherwise no floating bar needed
    return const SizedBox.shrink();
  }
}

/// 2027 Aion 2 Mobile Glassmorphism Horse Race Screen
/// Main arena screen hosting the betting board, live race simulator,
/// animated turf and dust visuals, volumetric stadium lighting,
/// odds ticker header, and celebratory victory overlay.
class HorseRaceScreen extends ConsumerStatefulWidget {
  const HorseRaceScreen({super.key});

  @override
  ConsumerState<HorseRaceScreen> createState() => _HorseRaceScreenState();
}

class _HorseRaceScreenState extends ConsumerState<HorseRaceScreen>
    with TickerProviderStateMixin {
  late final AnimationController _atmosphereController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  String? _selectedOddsHorseId;
  bool _forceShowLive = false;
  HorseRacePhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _atmosphereController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      TutorialTriggers.onRouteEnter(ref, AppRoutes.horseRace);
    });
  }

  @override
  void dispose() {
    _atmosphereController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _checkPhaseTransition(HorseRacePhase currentPhase) {
    if (_lastPhase != null && _lastPhase != currentPhase) {
      if (currentPhase == HorseRacePhase.racing) {
        HapticFeedback.heavyImpact();
      } else if (currentPhase == HorseRacePhase.locked) {
        HapticFeedback.mediumImpact();
      } else if (currentPhase == HorseRacePhase.finished) {
        HapticFeedback.mediumImpact();
      }
    }
    _lastPhase = currentPhase;
  }

  void _onOddsHorseSelected(HorseRaceEntry horse) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedOddsHorseId == horse.horseId) {
        _selectedOddsHorseId = null;
      } else {
        _selectedOddsHorseId = horse.horseId;
      }
    });
  }

  void _enterLiveRace() {
    HapticFeedback.mediumImpact();
    setState(() => _forceShowLive = true);
  }

  Future<void> _confirmExitLiveRace() async {
    HapticFeedback.lightImpact();
    final bool? leave = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (BuildContext context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: HorseRaceDesign.gold.withValues(alpha: 0.45),
                    width: 1.3,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      HorseRaceDesign.navy.withValues(alpha: 0.95),
                      HorseRaceDesign.void_.withValues(alpha: 0.98),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: HorseRaceDesign.gold.withValues(alpha: 0.2),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HorseRaceDesign.gold.withValues(alpha: 0.15),
                        border: Border.all(
                          color: HorseRaceDesign.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.sports_motorsports_rounded,
                        color: HorseRaceDesign.gold,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Canlı Yarışı Bırak?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Yarış arka planda simüle edilmeye devam eder. Dilediğin an bahis ekranına dönebilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop(false);
                            },
                            child: const Text(
                              'İptal',
                              style: TextStyle(
                                color: HorseRaceDesign.titanium,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: HorseRaceDesign.goldGradient,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: HorseRaceDesign.gold.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.of(context).pop(true);
                              },
                              child: const Text(
                                'Bırak',
                                style: TextStyle(
                                  color: HorseRaceDesign.void_,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (leave == true && mounted) {
      setState(() => _forceShowLive = false);
      ref.read(horseRaceProvider.notifier).dismissLiveRace();
    }
  }

  Widget _buildResponsiveLayout({required Widget child}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        if (maxWidth > 720) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          );
        }
        return child;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final HorseRaceState raceState = ref.watch(horseRaceProvider);
    _checkPhaseTransition(raceState.round.phase);

    final bool isBetting =
        raceState.round.phase == HorseRacePhase.betting &&
        raceState.myBet == null;
    final bool showLive =
        raceState.uiPhase == HorseRaceUiPhase.live ||
        (_forceShowLive && raceState.round.phase == HorseRacePhase.racing);
    final bool showResult = raceState.uiPhase == HorseRaceUiPhase.result;

    final double bottomClearance = gameBottomBarClearance(context);

    // Selected horse lookup
    HorseRaceEntry? selectedHorse;
    if (_selectedOddsHorseId != null) {
      for (final HorseRaceEntry h in raceState.horses) {
        if (h.horseId == _selectedOddsHorseId) {
          selectedHorse = h;
          break;
        }
      }
    }

    final double intensity =
        (raceState.round.phase == HorseRacePhase.racing ||
                raceState.round.phase == HorseRacePhase.locked)
            ? 1.0
            : 0.65;

    return Scaffold(
      backgroundColor: HorseRaceDesign.void_,
      appBar: showLive
          ? null
          : GameTopBar(
              title: context.l10n.at_yarisi,
              onLogout: () async => performLogout(ref),
            ),
      extendBody: !showLive,
      bottomNavigationBar: (raceState.isImmersiveUi || showLive)
          ? null
          : GameBottomBar(
              currentRoute: AppRoutes.horseRace,
              onLogout: () async => performLogout(ref),
            ),
      body: showLive
          ? HorseRaceLiveView(
              horses: raceState.horses,
              raceScript: raceState.round.raceScript,
              winnerHorseId: raceState.round.winnerHorseId,
              myBet: raceState.myBet,
              onRequestExit: _confirmExitLiveRace,
              onFinished: () {
                setState(() => _forceShowLive = false);
                ref.read(horseRaceProvider.notifier).showResultOverlay();
                ref.read(playerProvider.notifier).loadProfile();
              },
            )
          : AnimatedBuilder(
              animation: _atmosphereController,
              builder: (BuildContext context, Widget? _) {
                return _HorseRaceLivingTrackBackdrop(
                  atmosphereProgress: _atmosphereController.value,
                  intensity: intensity,
                  child: _buildResponsiveLayout(
                    child: Stack(
                      children: <Widget>[
                        // Main content or loading / error
                        if (raceState.loading && raceState.horses.isEmpty)
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: HorseRaceDesign.gold.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                    color: HorseRaceDesign.navy.withValues(
                                      alpha: 0.85,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: HorseRaceDesign.gold.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.8,
                                          color: HorseRaceDesign.gold,
                                        ),
                                      ),
                                      SizedBox(height: 14),
                                      Text(
                                        'Hipodrom Yükleniyor…',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (raceState.error != null &&
                            raceState.horses.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 12,
                                    sigmaY: 12,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: HorseRaceDesign.ruby.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                      color: HorseRaceDesign.navy.withValues(
                                        alpha: 0.88,
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color:
                                              HorseRaceDesign.ruby.withValues(
                                            alpha: 0.18,
                                          ),
                                          blurRadius: 22,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: HorseRaceDesign.ruby,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          raceState.error!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        HorseRaceGoldButton(
                                          label: 'Tekrar Dene',
                                          icon: Icons.refresh_rounded,
                                          expand: false,
                                          onPressed: () {
                                            HapticFeedback.selectionClick();
                                            ref
                                                .read(
                                                  horseRaceProvider.notifier,
                                                )
                                                .refresh();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: <Widget>[
                              // Top Odds Display Header
                              _HorseRaceOddsHeaderBar(
                                raceState: raceState,
                                selectedHorseId: _selectedOddsHorseId,
                                onSelectHorse: _onOddsHorseSelected,
                                pulseValue: _pulseAnim.value,
                              ),

                              // Betting panel
                              Expanded(
                                child: HorseBetPanel(
                                  raceState: raceState,
                                  isBetting: isBetting,
                                  bettingRoundId:
                                      raceState.activeBettingRoundId,
                                ),
                              ),
                            ],
                          ),

                        // Floating Live Bet Trigger HUD
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: bottomClearance + 8,
                          child: _HorseRaceLiveBetTriggerDock(
                            raceState: raceState,
                            selectedHorse: selectedHorse,
                            onEnterLiveRace: _enterLiveRace,
                            onClearSelection: () =>
                                setState(() => _selectedOddsHorseId = null),
                          ),
                        ),

                        // Result victory overlay
                        if (showResult)
                          HorseResultOverlay(
                            onDismiss: () => ref
                                .read(horseRaceProvider.notifier)
                                .dismissResultOverlay(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
