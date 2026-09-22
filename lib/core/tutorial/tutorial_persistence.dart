import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';
import 'tutorial_track.dart';
import 'tutorial_track_registry.dart';

/// Local + optional server tutorial progress (v2 track-based).
///
/// Local prefs are **per auth user**. Shared-device / new-account must not
/// inherit another player's completed/skipped tutorial.
class TutorialPersistence {
  TutorialPersistence._();

  static const String _legacyPrefsKey = 'gkk_tutorial_state';

  static String? get currentAuthId {
    if (!SupabaseService.isInitialized) return null;
    return SupabaseService.client.auth.currentUser?.id;
  }

  static String? get _authId => currentAuthId;

  static String _prefsKeyFor(String authId) => 'gkk_tutorial_state_$authId';

  static bool _serverProgressIsFresh(
    Map<String, dynamic> server, {
    required bool tutorialCompleted,
  }) {
    if (tutorialCompleted) return false;
    if (server['skipped_all'] == true) return false;
    if (_stringSet(server['completed_tracks']).isNotEmpty) return false;
    final dynamic steps = server['steps'];
    if (steps is Map && steps.isNotEmpty) return false;
    if (_stringSet(server['completed_steps']).isNotEmpty) return false;
    return true;
  }

  static Future<TutorialProgressState> load() async {
    final String? authId = _authId;
    // Logged out — never seed coach from another account's device cache.
    if (authId == null) {
      return TutorialProgressState.initial();
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    TutorialProgressState local = TutorialProgressState.initial();
    final String scopedKey = _prefsKeyFor(authId);
    final String? scopedRaw = prefs.getString(scopedKey);
    if (scopedRaw != null) {
      try {
        local = TutorialProgressState.fromJson(
          Map<String, dynamic>.from(jsonDecode(scopedRaw) as Map),
        );
      } catch (_) {}
    }

    try {
      final dynamic row = await SupabaseService.client
          .from('users')
          .select('tutorial_progress, tutorial_completed')
          .eq('auth_id', authId)
          .maybeSingle();
      if (row is Map) {
        final Map<String, dynamic> serverProgress =
            row['tutorial_progress'] is Map
                ? Map<String, dynamic>.from(row['tutorial_progress'] as Map)
                : <String, dynamic>{};
        final bool tutorialCompleted = row['tutorial_completed'] == true;

        // New account (or wiped server): ignore device leftovers + legacy key.
        if (_serverProgressIsFresh(
          serverProgress,
          tutorialCompleted: tutorialCompleted,
        )) {
          final TutorialProgressState fresh = TutorialProgressState.initial();
          await _saveLocal(fresh, authId: authId);
          return fresh;
        }

        // One-time migrate legacy global key for returning users only.
        if (scopedRaw == null) {
          final String? legacyRaw = prefs.getString(_legacyPrefsKey);
          if (legacyRaw != null) {
            try {
              local = TutorialProgressState.fromJson(
                Map<String, dynamic>.from(jsonDecode(legacyRaw) as Map),
              );
            } catch (_) {}
          }
        }

        local = local.mergeServer(
          serverProgress,
          tutorialCompleted: tutorialCompleted,
        );
        await _saveLocal(local, authId: authId);
        await prefs.remove(_legacyPrefsKey);
      } else if (scopedRaw == null) {
        // No users row yet (race right after register) — stay fresh.
        await _saveLocal(local, authId: authId);
      }
    } catch (_) {
      // Offline: keep scoped local only (never legacy cross-account).
    }

    return local;
  }

  static Future<void> save(TutorialProgressState state) async {
    final String? authId = _authId;
    if (authId == null) return;
    await _saveLocal(state, authId: authId);
    await _syncServer(state);
  }

  /// Clears local + server tutorial progress (settings replay).
  static Future<void> hardReset() async {
    final TutorialProgressState cleared =
        TutorialProgressState.initial(hardReset: true);
    final String? authId = _authId;
    if (authId != null) {
      await _saveLocal(cleared, authId: authId);
    }
    if (SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentUser != null) {
      try {
        await SupabaseService.client.rpc('reset_tutorial_progress');
      } catch (_) {
        await _syncServer(cleared);
      }
    }
  }

  static Future<void> _saveLocal(
    TutorialProgressState state, {
    required String authId,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyFor(authId), jsonEncode(state.toJson()));
  }

  static Future<void> _syncServer(TutorialProgressState state) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }
    try {
      await SupabaseService.client.rpc(
        'sync_tutorial_progress',
        params: <String, dynamic>{'p_progress': state.toJson()},
      );
    } catch (_) {}
  }

  static Set<String> _stringSet(dynamic raw) {
    if (raw is List) {
      return raw.map((dynamic e) => e.toString()).toSet();
    }
    return <String>{};
  }
}

class TutorialProgressState {
  const TutorialProgressState({
    required this.version,
    required this.completedTracks,
    required this.stepsByTrack,
    required this.skippedAll,
    this.coreCompletedAt,
    this.flags = const <String>{},
    this.hardReset = false,
  });

  factory TutorialProgressState.initial({bool hardReset = false}) =>
      TutorialProgressState(
        version: TutorialTrackRegistry.version,
        completedTracks: <String>{},
        stepsByTrack: <String, Set<String>>{},
        skippedAll: false,
        hardReset: hardReset,
      );

  /// Progress flags (bank full prompt, etc.) — avoids dual SharedPreferences.
  static const String flagBankFullPrompted = 'bank_full_prompted';
  static const String flagBankDepositCoachShown = 'bank_deposit_coach_shown';

  final int version;
  final Set<String> completedTracks;
  final Map<String, Set<String>> stepsByTrack;
  final bool skippedAll;
  final String? coreCompletedAt;
  final Set<String> flags;
  final bool hardReset;

  bool get coreCompleted =>
      TutorialTrackId.coreTracks.every(completedTracks.contains);

  bool isTrackComplete(String trackId) => completedTracks.contains(trackId);

  Set<String> stepsForTrack(String trackId) =>
      stepsByTrack[trackId] ?? const <String>{};

  bool hasFlag(String flag) => flags.contains(flag);

  TutorialProgressState clearHardResetFlag() {
    if (!hardReset) return this;
    return TutorialProgressState(
      version: version,
      completedTracks: completedTracks,
      stepsByTrack: stepsByTrack,
      skippedAll: skippedAll,
      coreCompletedAt: coreCompletedAt,
      flags: flags,
      hardReset: false,
    );
  }

  TutorialProgressState withFlag(String flag) {
    if (flags.contains(flag)) return this;
    return TutorialProgressState(
      version: version,
      completedTracks: completedTracks,
      stepsByTrack: stepsByTrack,
      skippedAll: skippedAll,
      coreCompletedAt: coreCompletedAt,
      flags: <String>{...flags, flag},
      hardReset: hardReset,
    );
  }

  TutorialProgressState mergeServer(
    Map<String, dynamic> server, {
    required bool tutorialCompleted,
  }) {
    if (hardReset) {
      // Settings replay — never keep prior completed_tracks/steps under the flag.
      return TutorialProgressState.initial(hardReset: true);
    }

    final bool serverHardReset = server['hard_reset'] == true;
    if (serverHardReset && completedTracks.isEmpty && !skippedAll) {
      return TutorialProgressState(
        version: TutorialTrackRegistry.version,
        completedTracks: _stringSet(server['completed_tracks']),
        stepsByTrack: _stepsMapFromServer(server['steps']),
        skippedAll: server['skipped_all'] == true,
        coreCompletedAt: server['core_completed_at']?.toString(),
        flags: _stringSet(server['flags']),
        hardReset: false,
      );
    }

    final Set<String> mergedTracks = <String>{
      ...completedTracks,
      ..._stringSet(server['completed_tracks']),
    };
    final Map<String, Set<String>> mergedSteps =
        Map<String, Set<String>>.from(stepsByTrack);
    final dynamic stepsRaw = server['steps'];
    if (stepsRaw is Map) {
      for (final MapEntry<dynamic, dynamic> entry in stepsRaw.entries) {
        mergedSteps[entry.key.toString()] = <String>{
          ...?mergedSteps[entry.key.toString()],
          ..._stringSet(entry.value),
        };
      }
    }
    // v1 flat completed_steps migration
    final Set<String> legacy = _stringSet(server['completed_steps']);
    if (legacy.isNotEmpty) {
      for (final TutorialTrack track in TutorialTrackRegistry.tracks) {
        final Set<String> matched = track.steps
            .where((step) => legacy.contains(step.id))
            .map((step) => step.id)
            .toSet();
        if (matched.isNotEmpty) {
          mergedSteps[track.id] = <String>{
            ...?mergedSteps[track.id],
            ...matched,
          };
          final Set<String> allForTrack = <String>{
            ...?mergedSteps[track.id],
          };
          final bool allRequiredDone = track.steps.every(
            (TutorialStepV2 s) =>
                TutorialTrackRegistry.isHomeLiveOnlyStep(s.id) ||
                allForTrack.contains(s.id),
          );
          if (allRequiredDone) {
            mergedTracks.add(track.id);
          }
        }
      }
    }

    return TutorialProgressState(
      version: TutorialTrackRegistry.version,
      completedTracks: mergedTracks,
      stepsByTrack: mergedSteps,
      skippedAll: skippedAll ||
          server['skipped_all'] == true ||
          (tutorialCompleted && mergedTracks.isEmpty && stepsByTrack.isEmpty),
      coreCompletedAt: coreCompletedAt ?? server['core_completed_at']?.toString(),
      flags: <String>{...flags, ..._stringSet(server['flags'])},
      hardReset: false,
    );
  }

  static Map<String, Set<String>> _stepsMapFromServer(dynamic stepsRaw) {
    final Map<String, Set<String>> steps = <String, Set<String>>{};
    if (stepsRaw is Map) {
      for (final MapEntry<dynamic, dynamic> entry in stepsRaw.entries) {
        steps[entry.key.toString()] = _stringSet(entry.value);
      }
    }
    return steps;
  }

  TutorialProgressState completeStep({
    required String trackId,
    required String stepId,
  }) {
    final Map<String, Set<String>> nextSteps =
        Map<String, Set<String>>.from(stepsByTrack);
    nextSteps[trackId] = <String>{...?nextSteps[trackId], stepId};
    return TutorialProgressState(
      version: version,
      completedTracks: completedTracks,
      stepsByTrack: nextSteps,
      skippedAll: skippedAll,
      coreCompletedAt: coreCompletedAt,
      flags: flags,
      hardReset: false,
    );
  }

  TutorialProgressState uncompleteStep({
    required String trackId,
    required String stepId,
  }) {
    final Set<String> current = stepsByTrack[trackId] ?? <String>{};
    if (!current.contains(stepId)) return this;
    final Map<String, Set<String>> nextSteps =
        Map<String, Set<String>>.from(stepsByTrack);
    nextSteps[trackId] = <String>{...current}..remove(stepId);
    final Set<String> nextTracks = <String>{...completedTracks}..remove(trackId);
    return TutorialProgressState(
      version: version,
      completedTracks: nextTracks,
      stepsByTrack: nextSteps,
      skippedAll: skippedAll,
      coreCompletedAt: coreCompletedAt,
      flags: flags,
      hardReset: false,
    );
  }

  TutorialProgressState completeTrack(String trackId) {
    final Set<String> nextTracks = <String>{...completedTracks, trackId};
    final bool coreDone = TutorialTrackId.coreTracks.every(nextTracks.contains);
    return TutorialProgressState(
      version: version,
      completedTracks: nextTracks,
      stepsByTrack: stepsByTrack,
      skippedAll: skippedAll,
      coreCompletedAt: coreDone && coreCompletedAt == null
          ? DateTime.now().toUtc().toIso8601String()
          : coreCompletedAt,
      flags: flags,
      hardReset: false,
    );
  }

  TutorialProgressState skipAll() {
    return TutorialProgressState(
      version: version,
      completedTracks: TutorialTrackRegistry.tracks
          .map((TutorialTrack t) => t.id)
          .toSet(),
      stepsByTrack: stepsByTrack,
      skippedAll: true,
      coreCompletedAt: coreCompletedAt ?? DateTime.now().toUtc().toIso8601String(),
      flags: flags,
      hardReset: false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tutorial_version': version,
        'completed_tracks': completedTracks.toList(),
        'steps': stepsByTrack.map(
          (String key, Set<String> value) =>
              MapEntry<String, dynamic>(key, value.toList()),
        ),
        'skipped_all': skippedAll,
        'core_completed': coreCompleted,
        if (coreCompletedAt != null) 'core_completed_at': coreCompletedAt,
        'flags': flags.toList(),
        if (hardReset) 'hard_reset': true,
        'completed_steps': stepsByTrack.values
            .expand((Set<String> s) => s)
            .toList(growable: false),
      };

  factory TutorialProgressState.fromJson(Map<String, dynamic> json) {
    final Map<String, Set<String>> steps = _stepsMapFromServer(json['steps']);
    return TutorialProgressState(
      version:
          (json['tutorial_version'] as num?)?.toInt() ?? TutorialTrackRegistry.version,
      completedTracks: _stringSet(json['completed_tracks']),
      stepsByTrack: steps,
      skippedAll: json['skipped_all'] == true,
      coreCompletedAt: json['core_completed_at']?.toString(),
      flags: _stringSet(json['flags']),
      hardReset: json['hard_reset'] == true,
    );
  }

  static Set<String> _stringSet(dynamic raw) {
    if (raw is List) {
      return raw.map((dynamic e) => e.toString()).toSet();
    }
    return <String>{};
  }
}
