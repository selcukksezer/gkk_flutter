import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'horse_race_provider.dart';
import 'horse_race_track_painter.dart';

Color _parseColor(String raw, {Color fallback = AppColors.accentBlue}) {
  final String hex = raw.replaceAll('#', '');
  if (hex.length == 6) {
    final int? value = int.tryParse('FF$hex', radix: 16);
    if (value != null) return Color(value);
  }
  return fallback;
}

class HorseRaceLiveView extends StatefulWidget {
  const HorseRaceLiveView({
    super.key,
    required this.horses,
    required this.raceScript,
    required this.winnerHorseId,
    required this.onFinished,
    this.myBet,
  });

  final List<HorseRaceEntry> horses;
  final HorseRaceScript raceScript;
  final String? winnerHorseId;
  final VoidCallback onFinished;
  final HorseRaceBet? myBet;

  @override
  State<HorseRaceLiveView> createState() => _HorseRaceLiveViewState();
}

class _HorseRaceLiveViewState extends State<HorseRaceLiveView>
    with SingleTickerProviderStateMixin {
  static const double _trackStart = 0.04;
  static const double _trackEnd = 0.90;

  late final AnimationController _controller;
  late final Animation<double> _raceAnim;
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _raceStarted = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.raceScript.durationMs),
    );
    _raceAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);

    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _finished = true);
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) widget.onFinished();
        });
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        timer.cancel();
        setState(() {
          _countdown = 0;
          _raceStarted = true;
        });
        _controller.forward();
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String? _leaderId(double progress) {
    String? leader;
    double best = -1;
    for (final HorseRaceEntry horse in widget.horses) {
      final double pos = widget.raceScript.positionAt(horse.horseId, progress);
      if (pos > best) {
        best = pos;
        leader = horse.horseId;
      }
    }
    return leader;
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> laneColors = widget.horses
        .map((HorseRaceEntry h) => _parseColor(h.laneColor))
        .toList(growable: false);
    final String? myHorseId = widget.myBet?.horseId;
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    return Material(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: _raceAnim,
        builder: (BuildContext context, Widget? child) {
          final double progress = _raceStarted ? _raceAnim.value : 0;
          final String? leaderId = _raceStarted ? _leaderId(progress) : null;
          final double scroll = progress * 280;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(
                painter: HorseRaceTrackPainter(
                  laneCount: widget.horses.length,
                  laneColors: laneColors,
                  scrollOffset: scroll,
                  raceProgress: progress,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8, safe.top + 44, 8, safe.bottom + 12),
                child: Column(
                  children: List<Widget>.generate(widget.horses.length, (int index) {
                    final HorseRaceEntry horse = widget.horses[index];
                    final Color lane = _parseColor(horse.laneColor);
                    final double pos = widget.raceScript.positionAt(horse.horseId, progress);
                    final bool isLeader = leaderId == horse.horseId;
                    final bool isMine = myHorseId == horse.horseId;
                    final bool isWinner =
                        _finished && widget.winnerHorseId == horse.horseId;

                    return Expanded(
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final double trackWidth = constraints.maxWidth;
                          final double horseX =
                              trackWidth * (_trackStart + pos * (_trackEnd - _trackStart)) - 16;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 2,
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 18,
                                      height: 18,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: lane.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: lane,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        horse.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: lane,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (isLeader && _raceStarted)
                                      _badge('Lider', AppColors.gold),
                                    if (isMine)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: _badge('Sen', AppColors.accentBlue),
                                      ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 6,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    value: pos.clamp(0.0, 1.0),
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(lane),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: horseX.clamp(0, trackWidth - 34),
                                top: 22,
                                child: AnimatedScale(
                                  scale: isWinner ? 1.2 : (isLeader ? 1.08 : 1.0),
                                  duration: const Duration(milliseconds: 200),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(alpha: 0.55),
                                      border: Border.all(
                                        color: isWinner
                                            ? AppColors.gold
                                            : isLeader
                                            ? AppColors.gold.withValues(alpha: 0.7)
                                            : lane,
                                        width: isWinner ? 2.5 : 1.5,
                                      ),
                                      boxShadow: isLeader || isWinner
                                          ? <BoxShadow>[
                                              BoxShadow(
                                                color: AppColors.gold.withValues(alpha: 0.35),
                                                blurRadius: 14,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(horse.emoji, style: const TextStyle(fontSize: 18)),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  }),
                ),
              ),
              if (!_raceStarted)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  alignment: Alignment.center,
                  child: Text(
                    _countdown > 0 ? '$_countdown' : 'BASLA',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              Positioned(
                top: safe.top + 8,
                left: 12,
                right: 12,
                child: _topHud(progress),
              ),
              if (_finished)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: <Color>[
                            AppColors.gold.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _topHud(double progress) {
    final int pct = (progress * 100).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.black.withValues(alpha: 0.45),
          child: Row(
            children: <Widget>[
              const Icon(Icons.sports_score_rounded, color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Canli Yaris',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (_raceStarted)
                Text(
                  '%$pct',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800),
      ),
    );
  }
}
