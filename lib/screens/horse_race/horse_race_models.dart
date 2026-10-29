import 'dart:math' as math;

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

enum HorseRacePhase { betting, locked, racing, finished, unknown }

enum HorseRaceUiPhase { bettingBoard, live, result }

HorseRacePhase phaseFrom(String? raw) {
  switch (raw) {
    case 'betting':
      return HorseRacePhase.betting;
    case 'locked':
      return HorseRacePhase.locked;
    case 'racing':
      return HorseRacePhase.racing;
    case 'finished':
      return HorseRacePhase.finished;
    default:
      return HorseRacePhase.unknown;
  }
}

class HorseRaceSettings {
  const HorseRaceSettings({
    required this.goldMinBet,
    required this.goldMaxBet,
    required this.gemMinBet,
    required this.gemMaxBet,
    required this.goldMaxMultiplier,
    required this.gemMaxMultiplier,
    required this.bettingSeconds,
    required this.racingSeconds,
    required this.finishedSeconds,
  });

  final int goldMinBet;
  final int goldMaxBet;
  final int gemMinBet;
  final int gemMaxBet;
  final double goldMaxMultiplier;
  final double gemMaxMultiplier;
  final int bettingSeconds;
  final int racingSeconds;
  final int finishedSeconds;

  factory HorseRaceSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const HorseRaceSettings(
        goldMinBet: 10000,
        goldMaxBet: 5000000,
        gemMinBet: 1,
        gemMaxBet: 50,
        goldMaxMultiplier: 12,
        gemMaxMultiplier: 12,
        bettingSeconds: 90,
        racingSeconds: 8,
        finishedSeconds: 10,
      );
    }
    return HorseRaceSettings(
      goldMinBet: _asInt(map['gold_min_bet'], fallback: 10000),
      goldMaxBet: _asInt(map['gold_max_bet'], fallback: 5000000),
      gemMinBet: _asInt(map['gem_min_bet'], fallback: 1),
      gemMaxBet: _asInt(map['gem_max_bet'], fallback: 50),
      goldMaxMultiplier: _asDouble(map['gold_max_multiplier'], fallback: 12),
      gemMaxMultiplier: _asDouble(map['gem_max_multiplier'], fallback: 12),
      bettingSeconds: _asInt(map['betting_seconds'], fallback: 90),
      racingSeconds: _asInt(map['racing_seconds'], fallback: 8),
      finishedSeconds: _asInt(map['finished_seconds'], fallback: 10),
    );
  }
}

class HorseRaceEntry {
  const HorseRaceEntry({
    required this.horseId,
    required this.name,
    required this.emoji,
    required this.laneColor,
    required this.goldMultiplier,
    required this.gemMultiplier,
    required this.winChancePct,
    required this.sortOrder,
  });

  final String horseId;
  final String name;
  final String emoji;
  final String laneColor;
  final double goldMultiplier;
  final double gemMultiplier;
  final double winChancePct;
  final int sortOrder;

  factory HorseRaceEntry.fromMap(Map<String, dynamic> map) {
    return HorseRaceEntry(
      horseId: map['horse_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'At',
      emoji: map['emoji']?.toString() ?? '🐴',
      laneColor: map['lane_color']?.toString() ?? '#94A3B8',
      goldMultiplier: _asDouble(map['gold_multiplier'], fallback: 1),
      gemMultiplier: _asDouble(map['gem_multiplier'], fallback: 1),
      winChancePct: _asDouble(map['win_chance_pct']),
      sortOrder: _asInt(map['sort_order']),
    );
  }
}

class HorseRaceBet {
  const HorseRaceBet({
    required this.horseId,
    required this.currencyType,
    required this.betAmount,
    required this.multiplier,
    this.won,
    this.payoutAmount = 0,
  });

  final String horseId;
  final String currencyType;
  final int betAmount;
  final double multiplier;
  final bool? won;
  final double payoutAmount;

  factory HorseRaceBet.fromMap(Map<String, dynamic> map) {
    return HorseRaceBet(
      horseId: map['horse_id']?.toString() ?? '',
      currencyType: map['currency_type']?.toString() ?? 'gold',
      betAmount: _asInt(map['bet_amount']),
      multiplier: _asDouble(map['multiplier'], fallback: 1),
      won: map['won'] is bool ? map['won'] as bool : null,
      payoutAmount: _asDouble(map['payout_amount']),
    );
  }
}

class HorseRaceKeyframe {
  const HorseRaceKeyframe({
    required this.t,
    required this.positions,
    this.leaderId,
  });

  final double t;
  final Map<String, double> positions;
  final String? leaderId;

  factory HorseRaceKeyframe.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> raw = map['positions'] is Map
        ? Map<String, dynamic>.from(map['positions'] as Map)
        : <String, dynamic>{};
    return HorseRaceKeyframe(
      t: _asDouble(map['t']),
      leaderId: map['leader_id']?.toString(),
      positions: raw.map(
        (String k, dynamic v) => MapEntry<String, double>(k, _asDouble(v)),
      ),
    );
  }
}

class HorseRaceScript {
  const HorseRaceScript({
    required this.durationMs,
    required this.finishOrder,
    required this.winnerId,
    required this.keyframes,
  });

  final int durationMs;
  final List<String> finishOrder;
  final String winnerId;
  final List<HorseRaceKeyframe> keyframes;

  factory HorseRaceScript.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const HorseRaceScript(
        durationMs: 8000,
        finishOrder: <String>[],
        winnerId: '',
        keyframes: <HorseRaceKeyframe>[],
      );
    }

    final List<String> finish = <String>[];
    if (map['finish_order'] is List) {
      for (final dynamic item in map['finish_order'] as List<dynamic>) {
        finish.add(item.toString());
      }
    }

    final List<HorseRaceKeyframe> frames = <HorseRaceKeyframe>[];
    if (map['keyframes'] is List) {
      for (final dynamic item in map['keyframes'] as List<dynamic>) {
        if (item is Map) {
          frames.add(HorseRaceKeyframe.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return HorseRaceScript(
      durationMs: _asInt(map['duration_ms'], fallback: 8000),
      finishOrder: finish,
      winnerId: map['winner_id']?.toString() ?? '',
      keyframes: frames,
    );
  }

  double positionAt(String horseId, double progress) {
    final double raw = _rawPositionAt(horseId, progress);
    if (winnerId.isEmpty || progress < 0.82) return raw;

    // Final stretch: winner always uniquely ahead (old scripts tie at 1.0).
    final double surge = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
    final double winnerFloor = 0.70 + surge * 0.30;
    if (horseId == winnerId) {
      return raw > winnerFloor ? raw.clamp(0.0, 1.0) : winnerFloor;
    }
    return (raw < winnerFloor - 0.04 ? raw : winnerFloor - 0.04)
        .clamp(0.0, 0.96);
  }

  double _rawPositionAt(String horseId, double progress) {
    if (keyframes.isEmpty) return progress;
    HorseRaceKeyframe? prev;
    HorseRaceKeyframe? next;
    for (final HorseRaceKeyframe frame in keyframes) {
      if (frame.t <= progress) prev = frame;
      if (frame.t >= progress) {
        next = frame;
        break;
      }
    }
    prev ??= keyframes.first;
    next ??= keyframes.last;
    if (prev.t == next.t) {
      return prev.positions[horseId] ?? 0;
    }
    final double local = (progress - prev.t) / (next.t - prev.t);
    final double a = prev.positions[horseId] ?? 0;
    final double b = next.positions[horseId] ?? 0;
    return a + (b - a) * local.clamp(0.0, 1.0);
  }

  /// Instantaneous normalized speed of [horseId] at [progress] (1.0 = average race pace).
  double velocityAt(
    String horseId,
    double progress, {
    double sampleDelta = 0.02,
  }) {
    final double p0 = (progress - sampleDelta * 0.5).clamp(0.0, 1.0);
    final double p1 = (progress + sampleDelta * 0.5).clamp(0.0, 1.0);
    final double dt = p1 - p0;
    if (dt <= 0.0001) return 1.0;
    final double y0 = positionAt(horseId, p0);
    final double y1 = positionAt(horseId, p1);
    return math.max((y1 - y0) / dt, 0.0);
  }

  /// Instantaneous acceleration of [horseId] at [progress].
  double accelerationAt(
    String horseId,
    double progress, {
    double sampleDelta = 0.03,
  }) {
    final double vPrev = velocityAt(
      horseId,
      (progress - sampleDelta).clamp(0.0, 1.0),
    );
    final double vNext = velocityAt(
      horseId,
      (progress + sampleDelta).clamp(0.0, 1.0),
    );
    return (vNext - vPrev) / (sampleDelta * 2);
  }

  /// Whether [horseId] is actively performing a high-velocity sprint at [progress].
  bool isSprinting(
    String horseId,
    double progress, {
    double speedThreshold = 1.15,
  }) {
    return velocityAt(horseId, progress) >= speedThreshold;
  }

  /// Normalized camera shake intensity (0.0 to 1.0) derived from race climax progress.
  double climaxCameraShake(double progress) {
    if (progress < 0.75) return 0.0;
    final double surge = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);
    return math.pow(surge, 1.8).toDouble();
  }

  /// Climax camera surge scale multiplier (1.0 to 1.045) on final sprint stretch.
  double climaxSurgeScale(double progress) {
    if (progress < 0.78) return 1.0;
    final double surge = ((progress - 0.78) / 0.22).clamp(0.0, 1.0);
    return 1.0 + 0.045 * math.sin(surge * math.pi * 0.5);
  }
}

class HorseRaceRecentWinner {
  const HorseRaceRecentWinner({
    required this.roundId,
    required this.winnerHorseId,
    required this.winnerName,
    required this.winnerEmoji,
  });

  final String roundId;
  final String winnerHorseId;
  final String winnerName;
  final String winnerEmoji;

  factory HorseRaceRecentWinner.fromMap(Map<String, dynamic> map) {
    return HorseRaceRecentWinner(
      roundId: map['round_id']?.toString() ?? '',
      winnerHorseId: map['winner_horse_id']?.toString() ?? '',
      winnerName: map['winner_name']?.toString() ?? '',
      winnerEmoji: map['winner_emoji']?.toString() ?? '🐴',
    );
  }
}

class HorseRaceRound {
  const HorseRaceRound({
    required this.id,
    required this.phase,
    required this.secondsLeft,
    required this.winnerHorseId,
    required this.raceScript,
  });

  final String id;
  final HorseRacePhase phase;
  final int secondsLeft;
  final String? winnerHorseId;
  final HorseRaceScript raceScript;

  factory HorseRaceRound.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const HorseRaceRound(
        id: '',
        phase: HorseRacePhase.unknown,
        secondsLeft: 0,
        winnerHorseId: null,
        raceScript: HorseRaceScript(
          durationMs: 8000,
          finishOrder: <String>[],
          winnerId: '',
          keyframes: <HorseRaceKeyframe>[],
        ),
      );
    }
    final Map<String, dynamic> scriptMap = map['race_script'] is Map
        ? Map<String, dynamic>.from(map['race_script'] as Map)
        : <String, dynamic>{};
    return HorseRaceRound(
      id: map['id']?.toString() ?? '',
      phase: phaseFrom(map['status']?.toString()),
      secondsLeft: _asInt(map['seconds_left']),
      winnerHorseId: map['winner_horse_id']?.toString(),
      raceScript: HorseRaceScript.fromMap(scriptMap),
    );
  }
}

class HorseRaceState {
  const HorseRaceState({
    this.loading = true,
    this.error,
    this.settings = const HorseRaceSettings(
      goldMinBet: 10000,
      goldMaxBet: 5000000,
      gemMinBet: 1,
      gemMaxBet: 50,
      goldMaxMultiplier: 12,
      gemMaxMultiplier: 12,
      bettingSeconds: 90,
      racingSeconds: 8,
      finishedSeconds: 10,
    ),
    this.round = const HorseRaceRound(
      id: '',
      phase: HorseRacePhase.unknown,
      secondsLeft: 0,
      winnerHorseId: null,
      raceScript: HorseRaceScript(
        durationMs: 8000,
        finishOrder: <String>[],
        winnerId: '',
        keyframes: <HorseRaceKeyframe>[],
      ),
    ),
    this.horses = const <HorseRaceEntry>[],
    this.myBet,
    this.recentWinners = const <HorseRaceRecentWinner>[],
    HorseRaceUiPhase uiPhase = HorseRaceUiPhase.bettingBoard,
    this.activeBettingRoundId,
    this.lastAutoLiveRoundId,
    this.dismissedResultRoundId,
  }) : _uiPhase = uiPhase;

  final bool loading;
  final String? error;
  final HorseRaceSettings settings;
  final HorseRaceRound round;
  final List<HorseRaceEntry> horses;
  final HorseRaceBet? myBet;
  final List<HorseRaceRecentWinner> recentWinners;
  final HorseRaceUiPhase? _uiPhase;
  final String? activeBettingRoundId;
  final String? lastAutoLiveRoundId;
  final String? dismissedResultRoundId;

  /// Hot-reload safe — stale state may have null [_uiPhase].
  HorseRaceUiPhase get uiPhase => _uiPhase ?? HorseRaceUiPhase.bettingBoard;

  bool get isImmersiveUi =>
      uiPhase == HorseRaceUiPhase.live || uiPhase == HorseRaceUiPhase.result;

  HorseRaceState copyWith({
    bool? loading,
    String? error,
    HorseRaceSettings? settings,
    HorseRaceRound? round,
    List<HorseRaceEntry>? horses,
    HorseRaceBet? myBet,
    List<HorseRaceRecentWinner>? recentWinners,
    HorseRaceUiPhase? uiPhase,
    String? activeBettingRoundId,
    String? lastAutoLiveRoundId,
    String? dismissedResultRoundId,
    bool clearMyBet = false,
  }) {
    return HorseRaceState(
      loading: loading ?? this.loading,
      error: error,
      settings: settings ?? this.settings,
      round: round ?? this.round,
      horses: horses ?? this.horses,
      myBet: clearMyBet ? null : (myBet ?? this.myBet),
      recentWinners: recentWinners ?? this.recentWinners,
      uiPhase: uiPhase ?? this.uiPhase,
      activeBettingRoundId: activeBettingRoundId ?? this.activeBettingRoundId,
      lastAutoLiveRoundId: lastAutoLiveRoundId ?? this.lastAutoLiveRoundId,
      dismissedResultRoundId: dismissedResultRoundId ?? this.dismissedResultRoundId,
    );
  }
}
