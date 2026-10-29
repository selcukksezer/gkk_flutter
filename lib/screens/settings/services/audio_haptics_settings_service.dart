import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/services/music_service.dart';

/// Haptic feedback intensity options for Aion-2 mobile game feel.
enum HapticIntensity {
  off,
  soft,
  medium,
  heavy;

  String get id => name;

  String get title => switch (this) {
    HapticIntensity.off => 'Off',
    HapticIntensity.soft => 'Soft',
    HapticIntensity.medium => 'Medium',
    HapticIntensity.heavy => 'Heavy',
  };

  String get description => switch (this) {
    HapticIntensity.off => 'No vibration feedback',
    HapticIntensity.soft => 'Subtle light ticks & taps',
    HapticIntensity.medium => 'Balanced combat & UI feedback',
    HapticIntensity.heavy => 'Deep, impactful vibrations',
  };

  static HapticIntensity fromString(String? raw) {
    if (raw == null) return HapticIntensity.medium;
    return HapticIntensity.values.firstWhere(
      (e) => e.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => HapticIntensity.medium,
    );
  }

  /// Trigger haptic pulse matching this intensity tier.
  Future<void> trigger() async {
    switch (this) {
      case HapticIntensity.off:
        return;
      case HapticIntensity.soft:
        await HapticFeedback.lightImpact();
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
      case HapticIntensity.heavy:
        await HapticFeedback.heavyImpact();
    }
  }
}

/// Audio and Haptics state representation.
class AudioHapticsState {
  const AudioHapticsState({
    required this.ready,
    required this.masterVolume,
    required this.bgmVolume,
    required this.sfxVolume,
    required this.voiceVolume,
    required this.ambientVolume,
    required this.muteAll,
    required this.hapticIntensity,
    required this.reduceMotion,
  });

  final bool ready;
  final double masterVolume;
  final double bgmVolume;
  final double sfxVolume;
  final double voiceVolume;
  final double ambientVolume;
  final bool muteAll;
  final HapticIntensity hapticIntensity;
  final bool reduceMotion;

  static const AudioHapticsState initial = AudioHapticsState(
    ready: false,
    masterVolume: 1.0,
    bgmVolume: 0.7,
    sfxVolume: 0.8,
    voiceVolume: 0.85,
    ambientVolume: 0.75,
    muteAll: false,
    hapticIntensity: HapticIntensity.medium,
    reduceMotion: false,
  );

  bool get isHapticEnabled => hapticIntensity != HapticIntensity.off;

  /// Effective volumes factoring in [muteAll] and [masterVolume].
  double get effectiveMaster => muteAll ? 0.0 : masterVolume;
  double get effectiveBgm =>
      muteAll ? 0.0 : (masterVolume * bgmVolume).clamp(0.0, 1.0);
  double get effectiveSfx =>
      muteAll ? 0.0 : (masterVolume * sfxVolume).clamp(0.0, 1.0);
  double get effectiveVoice =>
      muteAll ? 0.0 : (masterVolume * voiceVolume).clamp(0.0, 1.0);
  double get effectiveAmbient =>
      muteAll ? 0.0 : (masterVolume * ambientVolume).clamp(0.0, 1.0);

  AudioHapticsState copyWith({
    bool? ready,
    double? masterVolume,
    double? bgmVolume,
    double? sfxVolume,
    double? voiceVolume,
    double? ambientVolume,
    bool? muteAll,
    HapticIntensity? hapticIntensity,
    bool? reduceMotion,
  }) {
    return AudioHapticsState(
      ready: ready ?? this.ready,
      masterVolume: masterVolume ?? this.masterVolume,
      bgmVolume: bgmVolume ?? this.bgmVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      voiceVolume: voiceVolume ?? this.voiceVolume,
      ambientVolume: ambientVolume ?? this.ambientVolume,
      muteAll: muteAll ?? this.muteAll,
      hapticIntensity: hapticIntensity ?? this.hapticIntensity,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }
}

/// Service managing persistent Audio and Haptics settings.
class AudioHapticsSettingsService {
  AudioHapticsSettingsService._();

  static final AudioHapticsSettingsService instance =
      AudioHapticsSettingsService._();

  static const String keyMasterVolume = 'audio_master_volume';
  static const String keyBgmVolume = 'music_volume';
  static const String keySfxVolume = 'sfx_volume';
  static const String keyVoiceVolume = 'audio_voice_volume';
  static const String keyAmbientVolume = 'audio_ambient_volume';
  static const String keyMuteAll = 'music_muted';
  static const String keyHapticIntensity = 'haptic_intensity';
  static const String keyHapticEnabled = 'haptic_enabled';
  static const String keyReduceMotion = 'reduce_motion';

  bool _loaded = false;
  AudioHapticsState _state = AudioHapticsState.initial;

  bool get isLoaded => _loaded;
  AudioHapticsState get state => _state;

  /// Load persisted audio and haptic configuration.
  Future<AudioHapticsState> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final double master =
        (prefs.getDouble(keyMasterVolume) ?? 1.0).clamp(0.0, 1.0);
    final double bgm = (prefs.getDouble(keyBgmVolume) ?? 0.7).clamp(0.0, 1.0);
    final double sfx = (prefs.getDouble(keySfxVolume) ?? 0.8).clamp(0.0, 1.0);
    final double voice =
        (prefs.getDouble(keyVoiceVolume) ?? 0.85).clamp(0.0, 1.0);
    final double ambient =
        (prefs.getDouble(keyAmbientVolume) ?? 0.75).clamp(0.0, 1.0);
    final bool mute = prefs.getBool(keyMuteAll) ?? false;
    final bool reduceMotion = prefs.getBool(keyReduceMotion) ?? false;

    // Resolve haptic intensity
    final bool legacyHapticOn = prefs.getBool(keyHapticEnabled) ?? true;
    final String? rawIntensity = prefs.getString(keyHapticIntensity);
    HapticIntensity intensity;
    if (rawIntensity != null) {
      intensity = HapticIntensity.fromString(rawIntensity);
    } else {
      intensity = legacyHapticOn ? HapticIntensity.medium : HapticIntensity.off;
    }

    _state = AudioHapticsState(
      ready: true,
      masterVolume: master,
      bgmVolume: bgm,
      sfxVolume: sfx,
      voiceVolume: voice,
      ambientVolume: ambient,
      muteAll: mute,
      hapticIntensity: intensity,
      reduceMotion: reduceMotion,
    );
    _loaded = true;

    // Sync downstream services
    await _syncDownstreamServices();
    return _state;
  }

  Future<void> setMasterVolume(double volume) async {
    final double clamped = volume.clamp(0.0, 1.0);
    _state = _state.copyWith(masterVolume: clamped);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyMasterVolume, clamped);
    await _syncDownstreamServices();
  }

  Future<void> setBgmVolume(double volume) async {
    final double clamped = volume.clamp(0.0, 1.0);
    _state = _state.copyWith(bgmVolume: clamped);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyBgmVolume, clamped);
    await _syncDownstreamServices();
  }

  Future<void> setSfxVolume(double volume) async {
    final double clamped = volume.clamp(0.0, 1.0);
    _state = _state.copyWith(sfxVolume: clamped);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keySfxVolume, clamped);
    await _syncDownstreamServices();
  }

  Future<void> setVoiceVolume(double volume) async {
    final double clamped = volume.clamp(0.0, 1.0);
    _state = _state.copyWith(voiceVolume: clamped);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyVoiceVolume, clamped);
  }

  Future<void> setAmbientVolume(double volume) async {
    final double clamped = volume.clamp(0.0, 1.0);
    _state = _state.copyWith(ambientVolume: clamped);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyAmbientVolume, clamped);
  }

  Future<void> setMuteAll(bool muted) async {
    _state = _state.copyWith(muteAll: muted);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMuteAll, muted);
    await _syncDownstreamServices();
  }

  Future<void> setHapticIntensity(HapticIntensity intensity) async {
    _state = _state.copyWith(hapticIntensity: intensity);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyHapticIntensity, intensity.name);
    await prefs.setBool(keyHapticEnabled, intensity != HapticIntensity.off);

    try {
      await AppSettingsService.instance
          .setHapticEnabled(intensity != HapticIntensity.off);
    } catch (_) {}

    await intensity.trigger();
  }

  Future<void> setReduceMotion(bool reduce) async {
    _state = _state.copyWith(reduceMotion: reduce);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyReduceMotion, reduce);
    try {
      await AppSettingsService.instance.setReduceMotion(reduce);
    } catch (_) {}
  }

  Future<void> resetToDefaults() async {
    await setMasterVolume(1.0);
    await setBgmVolume(0.7);
    await setSfxVolume(0.8);
    await setVoiceVolume(0.85);
    await setAmbientVolume(0.75);
    await setMuteAll(false);
    await setHapticIntensity(HapticIntensity.medium);
    await setReduceMotion(false);
  }

  Future<void> testHapticPulse() async {
    await _state.hapticIntensity.trigger();
  }

  Future<void> _syncDownstreamServices() async {
    try {
      await MusicService.instance.setMuted(_state.muteAll);
      await MusicService.instance.setVolume(_state.effectiveBgm);
    } catch (_) {}

    try {
      await AppSettingsService.instance.setSfxVolume(_state.effectiveSfx);
      await AppSettingsService.instance
          .setHapticEnabled(_state.isHapticEnabled);
    } catch (_) {}
  }
}

/// Riverpod Notifier for Audio and Haptics settings.
class AudioHapticsNotifier extends Notifier<AudioHapticsState> {
  @override
  AudioHapticsState build() {
    Future<void>.microtask(reload);
    return AudioHapticsSettingsService.instance.isLoaded
        ? AudioHapticsSettingsService.instance.state
        : AudioHapticsState.initial;
  }

  Future<void> reload() async {
    final s = await AudioHapticsSettingsService.instance.load();
    state = s;
  }

  Future<void> setMasterVolume(double value) async {
    state = state.copyWith(masterVolume: value);
    await AudioHapticsSettingsService.instance.setMasterVolume(value);
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> setBgmVolume(double value) async {
    state = state.copyWith(bgmVolume: value);
    await AudioHapticsSettingsService.instance.setBgmVolume(value);
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> setSfxVolume(double value) async {
    state = state.copyWith(sfxVolume: value);
    await AudioHapticsSettingsService.instance.setSfxVolume(value);
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> setVoiceVolume(double value) async {
    state = state.copyWith(voiceVolume: value);
    await AudioHapticsSettingsService.instance.setVoiceVolume(value);
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> setAmbientVolume(double value) async {
    state = state.copyWith(ambientVolume: value);
    await AudioHapticsSettingsService.instance.setAmbientVolume(value);
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> setMuteAll(bool muted) async {
    state = state.copyWith(muteAll: muted);
    await AudioHapticsSettingsService.instance.setMuteAll(muted);
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> setHapticIntensity(HapticIntensity intensity) async {
    state = state.copyWith(hapticIntensity: intensity);
    await AudioHapticsSettingsService.instance.setHapticIntensity(intensity);
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> setReduceMotion(bool reduce) async {
    state = state.copyWith(reduceMotion: reduce);
    await AudioHapticsSettingsService.instance.setReduceMotion(reduce);
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> resetToDefaults() async {
    await AudioHapticsSettingsService.instance.resetToDefaults();
    state = AudioHapticsSettingsService.instance.state;
  }

  Future<void> testHapticPulse() async {
    await AudioHapticsSettingsService.instance.testHapticPulse();
  }
}

final audioHapticsSettingsProvider =
    NotifierProvider<AudioHapticsNotifier, AudioHapticsState>(
  AudioHapticsNotifier.new,
);
