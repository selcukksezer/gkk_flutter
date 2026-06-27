import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/supabase_service.dart';

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

HorseRacePhase _phaseFrom(String? raw) {
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
      phase: _phaseFrom(map['status']?.toString()),
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
  });

  final bool loading;
  final String? error;
  final HorseRaceSettings settings;
  final HorseRaceRound round;
  final List<HorseRaceEntry> horses;
  final HorseRaceBet? myBet;
  final List<HorseRaceRecentWinner> recentWinners;

  HorseRaceState copyWith({
    bool? loading,
    String? error,
    HorseRaceSettings? settings,
    HorseRaceRound? round,
    List<HorseRaceEntry>? horses,
    HorseRaceBet? myBet,
    List<HorseRaceRecentWinner>? recentWinners,
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
    );
  }
}

class HorseRaceNotifier extends Notifier<HorseRaceState> {
  Timer? _pollTimer;

  @override
  HorseRaceState build() {
    ref.onDispose(_stopPolling);
    Future<void>.microtask(refresh);
    _startPolling();
    return const HorseRaceState();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => refresh(silent: true));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, error: null);
    }
    try {
      final dynamic raw = await SupabaseService.client.rpc('get_horse_race_state');
      final Map<String, dynamic> data = raw is Map<String, dynamic>
          ? raw
          : Map<String, dynamic>.from(raw as Map);

      if (data['success'] != true) {
        state = state.copyWith(
          loading: false,
          error: data['message']?.toString() ?? 'Yukleme hatasi',
        );
        return;
      }

      final List<HorseRaceEntry> horses = <HorseRaceEntry>[];
      if (data['horses'] is List) {
        for (final dynamic row in data['horses'] as List<dynamic>) {
          if (row is Map) {
            horses.add(HorseRaceEntry.fromMap(Map<String, dynamic>.from(row)));
          }
        }
      }

      final List<HorseRaceRecentWinner> recent = <HorseRaceRecentWinner>[];
      if (data['recent_winners'] is List) {
        for (final dynamic row in data['recent_winners'] as List<dynamic>) {
          if (row is Map) {
            recent.add(HorseRaceRecentWinner.fromMap(Map<String, dynamic>.from(row)));
          }
        }
      }

      HorseRaceBet? myBet;
      final dynamic betRaw = data['my_bet'];
      if (betRaw is Map) {
        myBet = HorseRaceBet.fromMap(Map<String, dynamic>.from(betRaw));
      } else if (betRaw == null) {
        myBet = null;
      }

      state = HorseRaceState(
        loading: false,
        settings: HorseRaceSettings.fromMap(
          data['settings'] is Map ? Map<String, dynamic>.from(data['settings'] as Map) : null,
        ),
        round: HorseRaceRound.fromMap(
          data['round'] is Map ? Map<String, dynamic>.from(data['round'] as Map) : null,
        ),
        horses: horses,
        myBet: myBet,
        recentWinners: recent,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>> placeBet({
    required String roundId,
    required String horseId,
    required String currency,
    required int amount,
  }) async {
    final dynamic raw = await SupabaseService.client.rpc(
      'place_horse_race_bet',
      params: <String, dynamic>{
        'p_round_id': roundId,
        'p_horse_id': horseId,
        'p_currency_type': currency,
        'p_bet_amount': amount,
      },
    );
    final Map<String, dynamic> data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    if (data['success'] == true) {
      await refresh(silent: true);
    }
    return data;
  }
}

final horseRaceProvider = NotifierProvider<HorseRaceNotifier, HorseRaceState>(
  HorseRaceNotifier.new,
);
