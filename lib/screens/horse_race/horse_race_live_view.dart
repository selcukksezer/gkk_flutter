import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'horse_race_provider.dart';
import 'horse_race_utils.dart';
import 'horse_race_track_painter.dart';
import 'widgets/horse_race_design.dart';

class HorseRaceLiveView extends StatefulWidget {
  const HorseRaceLiveView({
    super.key,
    required this.horses,
    required this.raceScript,
    required this.winnerHorseId,
    required this.onFinished,
    this.myBet,
    this.onRequestExit,
  });

  final List<HorseRaceEntry> horses;
  final HorseRaceScript raceScript;
  final String? winnerHorseId;
  final VoidCallback onFinished;
  final HorseRaceBet? myBet;
  final VoidCallback? onRequestExit;

  @override
  State<HorseRaceLiveView> createState() => _HorseRaceLiveViewState();
}

class _HorseRaceLiveViewState extends State<HorseRaceLiveView>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final AnimationController _tickerController;
  late final Animation<double> _pulseAnim;
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _raceStarted = false;
  bool _finished = false;
  bool _standingsExpanded = false;

  /// Prefer script winner — matches live positions + result overlay.
  String? get _effectiveWinnerId {
    if (widget.raceScript.winnerId.isNotEmpty) {
      return widget.raceScript.winnerId;
    }
    return widget.winnerHorseId;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.raceScript.durationMs),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    // Linear: keyframe `t` maps 1:1 (curve → leader ≠ server winner).
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _finished = true);
        Future<void>.delayed(const Duration(milliseconds: 1400), () {
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
    _pulseController.dispose();
    _tickerController.dispose();
    super.dispose();
  }

  String _commentaryFor(double progress, String? leaderId) {
    if (_finished) return _winnerCommentary();
    if (!_raceStarted) {
      return _countdown > 0
          ? 'Start $_countdown... hazır ol!'
          : 'Atlar start kapısında bekliyor...';
    }
    if (progress >= 0.78) return 'SON DÜZLÜK — nefes kesen final!';
    if (leaderId != null && progress > 0.12) {
      final HorseRaceEntry? leader = _horseById(leaderId);
      if (leader != null) {
        return '${leader.name} önde — mücadele devam ediyor!';
      }
    }
    if (progress >= 0.45) return 'Orta mesafe — tempolar yükseliyor!';
    return 'Kapılar açıldı — yarış başladı!';
  }

  String _winnerCommentary() {
    final HorseRaceEntry? winner = _horseById(_effectiveWinnerId);
    if (winner == null) return 'Yarış bitti!';
    return 'Finiş! Kazanan: ${winner.name} ${winner.emoji}';
  }

  String? _leaderId(double progress) {
    if (_finished || progress >= 0.98) return _effectiveWinnerId;
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

  List<HorseRaceEntry> _rankedHorses(double progress) {
    final List<HorseRaceEntry> ranked =
        List<HorseRaceEntry>.from(widget.horses);
    ranked.sort(
      (HorseRaceEntry a, HorseRaceEntry b) => widget.raceScript
          .positionAt(b.horseId, progress)
          .compareTo(widget.raceScript.positionAt(a.horseId, progress)),
    );
    final String? winnerId = _effectiveWinnerId;
    if ((_finished || progress >= 0.98) && winnerId != null) {
      ranked.sort((HorseRaceEntry a, HorseRaceEntry b) {
        if (a.horseId == winnerId) return -1;
        if (b.horseId == winnerId) return 1;
        return widget.raceScript
            .positionAt(b.horseId, progress)
            .compareTo(widget.raceScript.positionAt(a.horseId, progress));
      });
    }
    return ranked;
  }

  HorseRaceEntry? _horseById(String? id) {
    if (id == null) return null;
    for (final HorseRaceEntry horse in widget.horses) {
      if (horse.horseId == id) return horse;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> laneColors = widget.horses
        .map(
          (HorseRaceEntry h) =>
              parseHorseLaneColor(h.laneColor, horseId: h.horseId),
        )
        .toList(growable: false);
    final String? myHorseId = widget.myBet?.horseId;
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    return Material(
      color: HorseRaceDesign.void_,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _controller,
          _pulseAnim,
          _tickerController,
        ]),
        builder: (BuildContext context, Widget? child) {
          final double progress = _raceStarted ? _controller.value : 0;
          final String? leaderId = _raceStarted ? _leaderId(progress) : null;
          final String commentary = _commentaryFor(progress, leaderId);
          final double scroll = progress * 420;
          final bool finalStretch = progress >= 0.78 && !_finished;
          final List<HorseRaceEntry> ranked = _rankedHorses(progress);
          final String? effectiveWinner = _effectiveWinnerId;

          // A: chrome outside race viewport → track/horses never under HUD.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: safe.top + 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 8, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _BroadcastHud(
                        progress: progress,
                        raceStarted: _raceStarted,
                        finished: _finished,
                        durationMs: widget.raceScript.durationMs,
                        horseCount: widget.horses.length,
                        betChip: widget.myBet == null
                            ? null
                            : _MyBetHudChip(
                                bet: widget.myBet!,
                                horse: _horseById(widget.myBet!.horseId),
                                rank: _rankOf(myHorseId, ranked),
                                raceStarted: _raceStarted,
                              ),
                      ),
                    ),
                    if (widget.onRequestExit != null) ...<Widget>[
                      const SizedBox(width: 6),
                      HorseRacePressable(
                        onTap: widget.onRequestExit,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HorseRaceDesign.navy.withValues(alpha: 0.9),
                            border: Border.all(
                              color: HorseRaceDesign.fuchsia.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      painter: HorseRaceTrackPainter(
                        laneCount: widget.horses.length,
                        laneColors: laneColors,
                        scrollOffset: scroll,
                        raceProgress: progress,
                        gateOpen: _raceStarted,
                        finalStretch: finalStretch,
                        showSpeedLines: _raceStarted && progress > 0.08,
                      ),
                    ),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                        final Size size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final double horseSize = HorseRaceTrackLayout.horseSize(
                          widget.horses.length,
                        );

                        return Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            for (int i = 0; i < widget.horses.length; i++)
                              _TrackHorseSprite(
                                horse: widget.horses[i],
                                index: i,
                                laneCount: widget.horses.length,
                                progress: progress,
                                raceStarted: _raceStarted,
                                finished: _finished,
                                isLeader:
                                    leaderId == widget.horses[i].horseId,
                                isMine: myHorseId == widget.horses[i].horseId,
                                isWinner: _finished &&
                                    effectiveWinner ==
                                        widget.horses[i].horseId,
                                raceScript: widget.raceScript,
                                size: size,
                                horseSize: horseSize,
                                bobPhase: progress * 24 + i,
                              ),
                          ],
                        );
                      },
                    ),
                    // D: peek top-3 by default; tap → full list.
                    Positioned(
                      top: 6,
                      right: 8,
                      width: _standingsExpanded ? 148 : 118,
                      child: _LiveStandingsBoard(
                        ranked: ranked,
                        raceStarted: _raceStarted,
                        myHorseId: myHorseId,
                        finished: _finished,
                        winnerHorseId: effectiveWinner,
                        expanded: _standingsExpanded,
                        onToggle: () {
                          setState(
                            () => _standingsExpanded = !_standingsExpanded,
                          );
                        },
                      ),
                    ),
                    if (!_raceStarted)
                      Positioned.fill(
                        child: _StartingGateOverlay(
                          countdown: _countdown,
                          pulse: _pulseAnim.value,
                          horseCount: widget.horses.length,
                        ),
                      ),
                    if (_finished)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.0, -0.55),
                                radius: 1.1,
                                colors: <Color>[
                                  HorseRaceDesign.gold.withValues(alpha: 0.28),
                                  HorseRaceDesign.fuchsia.withValues(
                                    alpha: 0.08,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const <double>[0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10, 6, 10, safe.bottom + 10),
                child: _CommentaryTicker(
                  text: commentary,
                  pulse: _pulseAnim.value,
                  active: _raceStarted && !_finished,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int? _rankOf(String? horseId, List<HorseRaceEntry> ranked) {
    if (horseId == null) return null;
    for (int i = 0; i < ranked.length; i++) {
      if (ranked[i].horseId == horseId) return i + 1;
    }
    return null;
  }
}

class _TrackHorseSprite extends StatelessWidget {
  const _TrackHorseSprite({
    required this.horse,
    required this.index,
    required this.laneCount,
    required this.progress,
    required this.raceStarted,
    required this.finished,
    required this.isLeader,
    required this.isMine,
    required this.isWinner,
    required this.raceScript,
    required this.size,
    required this.horseSize,
    required this.bobPhase,
  });

  final HorseRaceEntry horse;
  final int index;
  final int laneCount;
  final double progress;
  final bool raceStarted;
  final bool finished;
  final bool isLeader;
  final bool isMine;
  final bool isWinner;
  final HorseRaceScript raceScript;
  final Size size;
  final double horseSize;
  final double bobPhase;

  @override
  Widget build(BuildContext context) {
    final Color silk = parseHorseLaneColor(
      horse.laneColor,
      horseId: horse.horseId,
    );
    final double pos = raceScript.positionAt(horse.horseId, progress);
    final double centerX = HorseRaceTrackLayout.laneCenterX(
      size,
      index,
      laneCount,
    );
    final double y = HorseRaceTrackLayout.horseY(size, pos) - horseSize * 0.55;
    final double bob = raceStarted && !finished
        ? math.sin(bobPhase * math.pi * 2) * 2.5
        : 0;
    final Color accent = isWinner
        ? HorseRaceDesign.gold
        : isLeader
        ? HorseRaceDesign.gold
        : silk;

    return Positioned(
      left: (centerX - horseSize * 0.5).clamp(4.0, size.width - horseSize - 4),
      top: y.clamp(4.0, size.height - horseSize - 4) + bob,
      child: AnimatedScale(
        scale: isWinner ? 1.28 : (isLeader ? 1.12 : 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.elasticOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isLeader && raceStarted)
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: HorseRaceDesign.gold.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LİDER',
                  style: TextStyle(
                    color: HorseRaceDesign.void_,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (raceStarted && !finished)
                  Positioned(
                    left: horseSize * 0.3,
                    top: horseSize * 0.55,
                    child: _DustPuff(size: horseSize * 0.35),
                  ),
                Container(
                  width: horseSize,
                  height: horseSize * 0.82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        silk,
                        silk.withValues(alpha: 0.65),
                        silk.withValues(alpha: 0.85),
                      ],
                    ),
                    border: Border.all(
                      color: accent,
                      width: isWinner ? 2.5 : (isMine ? 2 : 1.4),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(
                          alpha: isLeader || isWinner ? 0.55 : 0.22,
                        ),
                        blurRadius: isLeader ? 16 : 8,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: silk.withValues(alpha: 0.95),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          horse.emoji,
                          style: TextStyle(fontSize: horseSize * 0.42),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMine)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HorseRaceDesign.cyan,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        size: 9,
                        color: HorseRaceDesign.void_,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
              constraints: BoxConstraints(maxWidth: horseSize + 8),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: HorseRaceDesign.void_.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                horse.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DustPuff extends StatelessWidget {
  const _DustPuff({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (int i) {
        return Container(
          width: size * (0.35 + i * 0.12),
          height: size * (0.35 + i * 0.12),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12 - i * 0.03),
          ),
        );
      }),
    );
  }
}

/// B: single-row broadcast chrome (+ optional bet chip).
class _BroadcastHud extends StatelessWidget {
  const _BroadcastHud({
    required this.progress,
    required this.raceStarted,
    required this.finished,
    required this.durationMs,
    required this.horseCount,
    this.betChip,
  });

  final double progress;
  final bool raceStarted;
  final bool finished;
  final int durationMs;
  final int horseCount;
  final Widget? betChip;

  @override
  Widget build(BuildContext context) {
    final int pct = (progress * 100).clamp(0, 100).round();
    final int elapsedSec = raceStarted
        ? ((progress * durationMs) / 1000).round()
        : 0;
    final String clock =
        '${(elapsedSec ~/ 60).toString().padLeft(2, '0')}:${(elapsedSec % 60).toString().padLeft(2, '0')}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: HorseRaceDesign.gold.withValues(alpha: 0.4),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                HorseRaceDesign.navy.withValues(alpha: 0.94),
                HorseRaceDesign.void_.withValues(alpha: 0.97),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _LiveBadge(active: raceStarted && !finished),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      '1200m',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HorseRaceDesign.titanium,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: raceStarted ? progress.clamp(0.0, 1.0) : null,
                        backgroundColor: HorseRaceDesign.obsidian.withValues(
                          alpha: 0.85,
                        ),
                        color: finished
                            ? HorseRaceDesign.neon
                            : HorseRaceDesign.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    raceStarted ? clock : '--:--',
                    style: TextStyle(
                      color: finished
                          ? HorseRaceDesign.neon
                          : HorseRaceDesign.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    raceStarted ? '%$pct' : '$horseCount',
                    style: const TextStyle(
                      color: HorseRaceDesign.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (betChip != null) ...<Widget>[
                const SizedBox(height: 4),
                betChip!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? HorseRaceDesign.ruby.withValues(alpha: 0.22)
            : HorseRaceDesign.obsidian.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? HorseRaceDesign.ruby.withValues(alpha: 0.7)
              : HorseRaceDesign.titanium.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (active)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: HorseRaceDesign.ruby,
              ),
            ),
          Text(
            active ? 'CANLI' : 'HAZIR',
            style: TextStyle(
              color: active ? HorseRaceDesign.ruby : HorseRaceDesign.titanium,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// D: collapsed = top-3 peek; tap toggles full standings.
class _LiveStandingsBoard extends StatelessWidget {
  const _LiveStandingsBoard({
    required this.ranked,
    required this.raceStarted,
    required this.finished,
    required this.expanded,
    required this.onToggle,
    this.myHorseId,
    this.winnerHorseId,
  });

  final List<HorseRaceEntry> ranked;
  final bool raceStarted;
  final bool finished;
  final bool expanded;
  final VoidCallback onToggle;
  final String? myHorseId;
  final String? winnerHorseId;

  @override
  Widget build(BuildContext context) {
    final int peekCount = expanded ? ranked.length : math.min(3, ranked.length);
    final int hidden = ranked.length - peekCount;

    final Widget list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'SIRALAMA',
                style: TextStyle(
                  color: HorseRaceDesign.cyan,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Icon(
              expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 14,
              color: HorseRaceDesign.cyan,
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (int i = 0; i < peekCount; i++)
          _StandingRow(
            rank: i + 1,
            horse: ranked[i],
            isMine: ranked[i].horseId == myHorseId,
            isLeader: i == 0 && raceStarted,
            isWinner: finished && ranked[i].horseId == winnerHorseId,
            dimmed: !raceStarted,
          ),
        if (!expanded && hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+$hidden · dokun',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HorseRaceDesign.titanium.withValues(alpha: 0.85),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    return HorseRacePressable(
      onTap: onToggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: HorseRaceNeonPanel(
            accent: HorseRaceDesign.cyan,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            radius: 12,
            child: expanded
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                    child: SingleChildScrollView(child: list),
                  )
                : list,
          ),
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.horse,
    required this.isMine,
    required this.isLeader,
    required this.isWinner,
    required this.dimmed,
  });

  final int rank;
  final HorseRaceEntry horse;
  final bool isMine;
  final bool isLeader;
  final bool isWinner;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final Color accent = isWinner
        ? HorseRaceDesign.gold
        : isLeader
        ? HorseRaceDesign.gold
        : isMine
        ? HorseRaceDesign.cyan
        : HorseRaceDesign.titanium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 14,
            child: Text(
              '$rank',
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            horse.emoji,
            style: TextStyle(
              fontSize: 12,
              color: dimmed
                  ? HorseRaceDesign.titanium.withValues(alpha: 0.5)
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              horse.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dimmed
                    ? HorseRaceDesign.titanium.withValues(alpha: 0.55)
                    : AppColors.textPrimary,
                fontSize: 9,
                fontWeight: isMine ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          if (isMine)
            Icon(Icons.star_rounded, size: 10, color: accent),
        ],
      ),
    );
  }
}

class _CommentaryTicker extends StatelessWidget {
  const _CommentaryTicker({
    required this.text,
    required this.pulse,
    required this.active,
  });

  final String text;
  final double pulse;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: HorseRaceDesign.navy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? HorseRaceDesign.gold.withValues(alpha: 0.35)
                  : HorseRaceDesign.titanium.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.mic_rounded,
                size: 14,
                color: active
                    ? HorseRaceDesign.gold
                    : HorseRaceDesign.titanium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: Text(
                    text,
                    key: ValueKey<String>(text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? AppColors.textPrimary
                          : HorseRaceDesign.titanium,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (active)
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: HorseRaceDesign.ruby,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartingGateOverlay extends StatelessWidget {
  const _StartingGateOverlay({
    required this.countdown,
    required this.pulse,
    required this.horseCount,
  });

  final int countdown;
  final double pulse;
  final int horseCount;

  @override
  Widget build(BuildContext context) {
    final String label = countdown > 0 ? '$countdown' : 'GO!';
    final Color accent = countdown > 0
        ? HorseRaceDesign.gold
        : HorseRaceDesign.neon;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Container(
        color: HorseRaceDesign.void_.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: pulse,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              HorseRaceNeonPanel(
                accent: accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                radius: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'START KAPISI',
                      style: TextStyle(
                        color: HorseRaceDesign.titanium,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: accent,
                        fontSize: countdown > 0 ? 76 : 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: <Shadow>[
                          Shadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$horseCount at start pozisyonunda',
                      style: const TextStyle(
                        color: HorseRaceDesign.titanium,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

/// Compact bet chip inside slim HUD (replaces left BAHİS KUPONU overlay).
class _MyBetHudChip extends StatelessWidget {
  const _MyBetHudChip({
    required this.bet,
    this.horse,
    this.rank,
    required this.raceStarted,
  });

  final HorseRaceBet bet;
  final HorseRaceEntry? horse;
  final int? rank;
  final bool raceStarted;

  @override
  Widget build(BuildContext context) {
    final Color accent = bet.currencyType == 'gems'
        ? HorseRaceDesign.cyan
        : HorseRaceDesign.gold;
    final String amount = bet.currencyType == 'gems'
        ? formatHorseGems(bet.betAmount)
        : compactHorseAmount(bet.betAmount);
    final String rankLabel =
        raceStarted && rank != null ? ' · $rank.' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.star_rounded, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(horse?.emoji ?? '🐴', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              horse?.name ?? bet.horseId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$amount$rankLabel',
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
