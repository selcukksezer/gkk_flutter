import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';
import 'tutorial_track.dart';
import 'tutorial_track_registry.dart';

/// Local + optional server tutorial progress (v2 track-based).
class TutorialPersistence {
  TutorialPersistence._();

  static const String _prefsKey = 'gkk_tutorial_state';

  static Future<TutorialProgressState> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefsKey);
    TutorialProgressState state = TutorialProgressState.initial();
    if (raw != null) {
      try {
        state = TutorialProgressState.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {}
    }

    if (SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentUser != null) {
      try {
        final dynamic row = await SupabaseService.client
            .from('users')
            .select('tutorial_progress, tutorial_completed')
            .eq('auth_id', SupabaseService.client.auth.currentUser!.id)
            .maybeSingle();
        if (row is Map) {
          final Map<String, dynamic> serverProgress =
              row['tutorial_progress'] is Map
                  ? Map<String, dynamic>.from(row['tutorial_progress'] as Map)
                  : <String, dynamic>{};
          state = state.mergeServer(
            serverProgress,
            tutorialCompleted: row['tutorial_completed'] == true,
          );
          await _saveLocal(state);
        }
      } catch (_) {}
    }

    return state;
  }

  static Future<void> save(TutorialProgressState state) async {
    await _saveLocal(state);
    await _syncServer(state);
  }

  static Future<void> _saveLocal(TutorialProgressState state) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
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
}

class TutorialProgressState {
  const TutorialProgressState({
    required this.version,
    required this.completedTracks,
    required this.stepsByTrack,
    required this.skippedAll,
    this.coreCompletedAt,
  });

  factory TutorialProgressState.initial() => TutorialProgressState(
        version: TutorialTrackRegistry.version,
        completedTracks: <String>{},
        stepsByTrack: <String, Set<String>>{},
        skippedAll: false,
      );

  final int version;
  final Set<String> completedTracks;
  final Map<String, Set<String>> stepsByTrack;
  final bool skippedAll;
  final String? coreCompletedAt;

  Set<String> stepsForTrack(String trackId) =>
      stepsByTrack[trackId] ?? <String>{};

  bool isTrackComplete(String trackId) => completedTracks.contains(trackId);

  bool get coreCompleted =>
      TutorialTrackId.coreTracks.every(completedTracks.contains);

  TutorialProgressState mergeServer(
    Map<String, dynamic> server, {
    required bool tutorialCompleted,
  }) {
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
          if (matched.length >= track.steps.length) {
            mergedTracks.add(track.id);
          }
        }
      }
    }

    return TutorialProgressState(
      version: TutorialTrackRegistry.version,
      completedTracks: mergedTracks,
      stepsByTrack: mergedSteps,
      skippedAll: skippedAll || server['skipped_all'] == true || tutorialCompleted,
      coreCompletedAt: coreCompletedAt ?? server['core_completed_at']?.toString(),
    );
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
        'completed_steps': stepsByTrack.values
            .expand((Set<String> s) => s)
            .toList(growable: false),
      };

  factory TutorialProgressState.fromJson(Map<String, dynamic> json) {
    final Map<String, Set<String>> steps = <String, Set<String>>{};
    if (json['steps'] is Map) {
      for (final MapEntry<dynamic, dynamic> entry
          in (json['steps'] as Map).entries) {
        steps[entry.key.toString()] = _stringSet(entry.value);
      }
    }
    return TutorialProgressState(
      version:
          (json['tutorial_version'] as num?)?.toInt() ?? TutorialTrackRegistry.version,
      completedTracks: _stringSet(json['completed_tracks']),
      stepsByTrack: steps,
      skippedAll: json['skipped_all'] == true,
      coreCompletedAt: json['core_completed_at']?.toString(),
    );
  }

  static Set<String> _stringSet(dynamic raw) {
    if (raw is List) {
      return raw.map((dynamic e) => e.toString()).toSet();
    }
    return <String>{};
  }
}
